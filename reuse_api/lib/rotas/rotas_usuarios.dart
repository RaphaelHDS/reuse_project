// =====================================================================
// rotas_usuarios.dart
// Cadastro, login, logout, recuperação de senha e perfil.
//
//   POST /usuarios/cadastro          -> cria conta (pessoa ou empresa)
//   POST /usuarios/login             -> entra com e-mail e senha
//   POST /usuarios/logout            -> sai (apaga o token)
//   POST /usuarios/recuperar-senha   -> gera código de 6 dígitos
//   POST /usuarios/redefinir-senha   -> troca a senha usando o código
//   GET  /usuarios/me                -> dados de quem está logado
//   PUT  /usuarios/me                -> atualiza o perfil
// =====================================================================

import 'package:mysql_client/exception.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../banco.dart';
import '../utilidades.dart';

Router rotasUsuarios() {
  final rotas = Router();

  // -------------------------------------------------------------------
  // CADASTRO
  // -------------------------------------------------------------------
  rotas.post('/cadastro', (Request request) async {
    final dados = await lerJson(request);

    final tipo = campoTexto(dados, 'tipo') ?? 'pessoa';
    if (tipo != 'pessoa' && tipo != 'empresa') {
      throw ErroApi(400, 'Tipo de conta inválido.');
    }
    final nome = campoTexto(dados, 'nome', obrigatorio: true, maximo: 120)!;
    final email = campoTexto(dados, 'email',
            obrigatorio: true, nomeAmigavel: 'e-mail', maximo: 120)!
        .toLowerCase();
    final senha = campoTexto(dados, 'senha', obrigatorio: true)!;
    final telefone = _soNumeros(campoTexto(dados, 'telefone', maximo: 20));
    final cidade = campoTexto(dados, 'cidade', maximo: 80);

    if (!email.contains('@') || !email.contains('.')) {
      throw ErroApi(400, 'Digite um e-mail válido.');
    }
    if (senha.length < 6) {
      throw ErroApi(400, 'A senha precisa ter pelo menos 6 caracteres.');
    }

    final sal = gerarSal();
    int novoId;
    try {
      novoId = await Banco.executar(
        'INSERT INTO usuarios (tipo, nome, email, telefone, cidade, senha_salt, senha_hash) '
        'VALUES (:tipo, :nome, :email, :telefone, :cidade, :sal, :hash)',
        {
          'tipo': tipo,
          'nome': nome,
          'email': email,
          'telefone': telefone,
          'cidade': cidade,
          'sal': sal,
          'hash': hashSenha(sal, senha),
        },
      );
    } on MySQLServerException catch (e) {
      // 1062 = registro duplicado (e-mail já existe)
      if (e.errorCode == 1062) {
        throw ErroApi(409, 'Já existe uma conta com este e-mail.');
      }
      rethrow;
    }

    // Se for empresa, guarda os dados extras na tabela "empresas"
    if (tipo == 'empresa') {
      await Banco.executar(
        'INSERT INTO empresas (usuario_id, cnpj, ramo_atividade) '
        'VALUES (:id, :cnpj, :ramo)',
        {
          'id': novoId,
          'cnpj': campoTexto(dados, 'cnpj', maximo: 18),
          'ramo': campoTexto(dados, 'ramo_atividade', maximo: 100),
        },
      );
    }

    final token = await _criarSessao(novoId);
    return respostaJson({
      'token': token,
      'usuario': await buscarUsuario(novoId),
    }, status: 201);
  });

  // -------------------------------------------------------------------
  // LOGIN
  // -------------------------------------------------------------------
  rotas.post('/login', (Request request) async {
    final dados = await lerJson(request);
    final email = (campoTexto(dados, 'email',
                obrigatorio: true, nomeAmigavel: 'e-mail') ??
            '')
        .toLowerCase();
    final senha = campoTexto(dados, 'senha', obrigatorio: true)!;

    final usuario = await Banco.consultarUm(
      'SELECT id, senha_salt, senha_hash FROM usuarios WHERE email = :email',
      {'email': email},
    );
    // Mesma mensagem para e-mail ou senha errados (mais seguro)
    if (usuario == null ||
        hashSenha(usuario['senha_salt']!, senha) != usuario['senha_hash']) {
      throw ErroApi(401, 'E-mail ou senha incorretos.');
    }

    final id = paraInt(usuario['id'])!;
    final token = await _criarSessao(id);
    return respostaJson({'token': token, 'usuario': await buscarUsuario(id)});
  });

  // -------------------------------------------------------------------
  // LOGOUT
  // -------------------------------------------------------------------
  rotas.post('/logout', (Request request) async {
    final cabecalho = request.headers['authorization'] ?? '';
    if (cabecalho.startsWith('Bearer ')) {
      await Banco.executar('DELETE FROM sessoes WHERE token = :token',
          {'token': cabecalho.substring(7)});
    }
    return respostaJson({'ok': true});
  });

  // -------------------------------------------------------------------
  // RECUPERAR SENHA (passo 1: gerar código)
  // Num sistema real o código iria por e-mail. Aqui, para o projeto
  // acadêmico, ele aparece no terminal da API e volta na resposta
  // (campo "codigo_demonstracao") para facilitar o teste.
  // -------------------------------------------------------------------
  rotas.post('/recuperar-senha', (Request request) async {
    final dados = await lerJson(request);
    final email = campoTexto(dados, 'email',
            obrigatorio: true, nomeAmigavel: 'e-mail')!
        .toLowerCase();

    final usuario = await Banco.consultarUm(
        'SELECT id FROM usuarios WHERE email = :email', {'email': email});
    if (usuario == null) {
      throw ErroApi(404, 'Não encontramos uma conta com este e-mail.');
    }

    final codigo = gerarCodigo6();
    await Banco.executar(
      'INSERT INTO recuperacoes_senha (usuario_id, codigo, expira_em) '
      'VALUES (:usuario, :codigo, NOW() + INTERVAL 15 MINUTE)',
      {'usuario': paraInt(usuario['id']), 'codigo': codigo},
    );

    print('');
    print('>>> [SIMULAÇÃO DE E-MAIL] Código de recuperação para $email: $codigo');
    print('');

    return respostaJson({
      'mensagem': 'Código enviado! (vale por 15 minutos)',
      'codigo_demonstracao': codigo,
    });
  });

  // -------------------------------------------------------------------
  // REDEFINIR SENHA (passo 2: usar o código)
  // -------------------------------------------------------------------
  rotas.post('/redefinir-senha', (Request request) async {
    final dados = await lerJson(request);
    final email = campoTexto(dados, 'email',
            obrigatorio: true, nomeAmigavel: 'e-mail')!
        .toLowerCase();
    final codigo = campoTexto(dados, 'codigo',
        obrigatorio: true, nomeAmigavel: 'código')!;
    final novaSenha = campoTexto(dados, 'nova_senha',
        obrigatorio: true, nomeAmigavel: 'nova senha')!;

    if (novaSenha.length < 6) {
      throw ErroApi(400, 'A senha precisa ter pelo menos 6 caracteres.');
    }

    final pedido = await Banco.consultarUm(
      'SELECT r.id, r.usuario_id FROM recuperacoes_senha r '
      'JOIN usuarios u ON u.id = r.usuario_id '
      'WHERE u.email = :email AND r.codigo = :codigo '
      'AND r.usado = 0 AND r.expira_em > NOW() '
      'ORDER BY r.id DESC LIMIT 1',
      {'email': email, 'codigo': codigo},
    );
    if (pedido == null) {
      throw ErroApi(400, 'Código inválido ou vencido. Peça um novo código.');
    }

    final usuarioId = paraInt(pedido['usuario_id'])!;
    final sal = gerarSal();
    await Banco.executar(
      'UPDATE usuarios SET senha_salt = :sal, senha_hash = :hash WHERE id = :id',
      {'sal': sal, 'hash': hashSenha(sal, novaSenha), 'id': usuarioId},
    );
    await Banco.executar('UPDATE recuperacoes_senha SET usado = 1 WHERE id = :id',
        {'id': paraInt(pedido['id'])});
    // Por segurança, desloga de todos os aparelhos
    await Banco.executar(
        'DELETE FROM sessoes WHERE usuario_id = :id', {'id': usuarioId});

    return respostaJson({'mensagem': 'Senha alterada! Faça login com a nova senha.'});
  });

  // -------------------------------------------------------------------
  // MEU PERFIL
  // -------------------------------------------------------------------
  rotas.get('/me', (Request request) async {
    final id = await usuarioLogado(request);
    return respostaJson(await buscarUsuario(id));
  });

  rotas.put('/me', (Request request) async {
    final id = await usuarioLogado(request);
    final dados = await lerJson(request);

    await Banco.executar(
      'UPDATE usuarios SET nome = :nome, telefone = :telefone, cidade = :cidade '
      'WHERE id = :id',
      {
        'nome': campoTexto(dados, 'nome', obrigatorio: true, maximo: 120),
        'telefone': _soNumeros(campoTexto(dados, 'telefone', maximo: 20)),
        'cidade': campoTexto(dados, 'cidade', maximo: 80),
        'id': id,
      },
    );

    // Atualiza os dados de empresa (se a conta for de empresa)
    await Banco.executar(
      'UPDATE empresas SET cnpj = :cnpj, ramo_atividade = :ramo '
      'WHERE usuario_id = :id',
      {
        'cnpj': campoTexto(dados, 'cnpj', maximo: 18),
        'ramo': campoTexto(dados, 'ramo_atividade', maximo: 100),
        'id': id,
      },
    );

    return respostaJson(await buscarUsuario(id));
  });

  return rotas;
}

// ---------------------------------------------------------------------
// Funções de apoio
// ---------------------------------------------------------------------

/// Cria um token de login novo para o usuário e devolve ele.
Future<String> _criarSessao(int usuarioId) async {
  final token = gerarToken();
  await Banco.executar(
    'INSERT INTO sessoes (token, usuario_id) VALUES (:token, :usuario)',
    {'token': token, 'usuario': usuarioId},
  );
  return token;
}

/// Deixa só os números do telefone: "(11) 98888-0001" -> "11988880001".
String? _soNumeros(String? texto) {
  if (texto == null) return null;
  final numeros = texto.replaceAll(RegExp(r'[^0-9]'), '');
  return numeros.isEmpty ? null : numeros;
}

/// Busca os dados públicos de um usuário (sem senha!) já em formato JSON.
Future<Map<String, dynamic>> buscarUsuario(int id) async {
  final linha = await Banco.consultarUm(
    'SELECT u.id, u.tipo, u.nome, u.email, u.telefone, u.cidade, u.criado_em, '
    'e.cnpj, e.ramo_atividade '
    'FROM usuarios u LEFT JOIN empresas e ON e.usuario_id = u.id '
    'WHERE u.id = :id',
    {'id': id},
  );
  if (linha == null) throw ErroApi(404, 'Usuário não encontrado.');
  return {
    'id': paraInt(linha['id']),
    'tipo': linha['tipo'],
    'nome': linha['nome'],
    'email': linha['email'],
    'telefone': linha['telefone'],
    'cidade': linha['cidade'],
    'cnpj': linha['cnpj'],
    'ramo_atividade': linha['ramo_atividade'],
    'criado_em': paraDataIso(linha['criado_em']),
  };
}
