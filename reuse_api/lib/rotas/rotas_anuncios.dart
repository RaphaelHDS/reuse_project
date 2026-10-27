// =====================================================================
// rotas_anuncios.dart
// Tudo sobre os anúncios de materiais.
//
//   GET    /anuncios               -> lista (feed e mapa), com filtros
//   GET    /anuncios/meus          -> anúncios de quem está logado
//   GET    /anuncios/<id>          -> detalhe de um anúncio
//   POST   /anuncios               -> cria anúncio (com foto opcional)
//   PUT    /anuncios/<id>          -> edita anúncio (só o dono)
//   DELETE /anuncios/<id>          -> exclui anúncio (só o dono)
//   PUT    /anuncios/<id>/status   -> muda status (só o dono)
//
// Filtros do GET /anuncios (todos opcionais):
//   ?tipo=Madeira  ?busca=palete  ?status=todos
//   ?lat=-23.52&lng=-46.18&raio_km=5   (distância a partir de um ponto)
// =====================================================================

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../banco.dart';
import '../config.dart';
import '../utilidades.dart';

/// Listas de valores aceitos (o app usa exatamente os mesmos textos).
const tiposMaterial = [
  'Madeira',
  'Tecido',
  'Metal',
  'Plástico',
  'Papel e papelão',
  'Vidro',
  'Embalagens',
  'Outros',
];
const unidadesAceitas = ['kg', 'unidades', 'metros', 'm²', 'litros'];
const estadosConservacao = ['novo', 'bom', 'regular', 'desgastado'];
const statusAnuncio = ['disponivel', 'reservado', 'retirado'];

/// SELECT base: dados do anúncio + dados de quem anunciou.
const _selectAnuncio = '''
SELECT a.id, a.usuario_id, a.titulo, a.tipo_material, a.descricao,
       a.quantidade, a.unidade, a.peso_estimado_kg, a.estado_conservacao,
       a.foto_url, a.endereco, a.latitude, a.longitude, a.status, a.criado_em,
       u.nome AS anunciante_nome, u.tipo AS anunciante_tipo,
       u.telefone AS anunciante_telefone, u.cidade AS anunciante_cidade,
       (SELECT COUNT(*) FROM solicitacoes s
         WHERE s.anuncio_id = a.id AND s.status = 'pendente') AS pedidos_pendentes
FROM anuncios a
JOIN usuarios u ON u.id = a.usuario_id
''';

Router rotasAnuncios() {
  final rotas = Router();

  // -------------------------------------------------------------------
  // LISTAR (feed e mapa)
  // -------------------------------------------------------------------
  rotas.get('/', (Request request) async {
    await usuarioLogado(request);
    final filtros = request.url.queryParameters;

    final condicoes = <String>[];
    final parametros = <String, dynamic>{};

    // Status: por padrão mostra só os disponíveis
    final status = filtros['status'] ?? 'disponivel';
    if (status != 'todos') {
      condicoes.add('a.status = :status');
      parametros['status'] = status;
    }

    // Tipo de material
    final tipo = filtros['tipo'];
    if (tipo != null && tipo.isNotEmpty) {
      condicoes.add('a.tipo_material = :tipo');
      parametros['tipo'] = tipo;
    }

    // Busca por texto no título ou na descrição
    final busca = filtros['busca']?.trim();
    if (busca != null && busca.isNotEmpty) {
      condicoes.add('(a.titulo LIKE :busca OR a.descricao LIKE :busca)');
      parametros['busca'] = '%$busca%';
    }

    var sql = _selectAnuncio;
    if (condicoes.isNotEmpty) sql += ' WHERE ${condicoes.join(' AND ')}';
    sql += ' ORDER BY a.criado_em DESC LIMIT 300';

    final linhas = await Banco.consultar(sql, parametros);
    var anuncios = linhas.map(anuncioParaJson).toList();

    // Distância: se o app mandou a localização, calculamos aqui no Dart
    final lat = double.tryParse(filtros['lat'] ?? '');
    final lng = double.tryParse(filtros['lng'] ?? '');
    final raio = double.tryParse(filtros['raio_km'] ?? '');
    if (lat != null && lng != null) {
      for (final anuncio in anuncios) {
        final aLat = anuncio['latitude'] as double?;
        final aLng = anuncio['longitude'] as double?;
        if (aLat != null && aLng != null) {
          anuncio['distancia_km'] = arredondar(distanciaKm(lat, lng, aLat, aLng));
        }
      }
      if (raio != null && raio > 0) {
        anuncios = anuncios.where((a) {
          final d = a['distancia_km'] as double?;
          return d != null && d <= raio;
        }).toList();
      }
      // Mais perto primeiro (quem não tem local vai para o fim)
      anuncios.sort((a, b) {
        final da = (a['distancia_km'] as double?) ?? 999999;
        final db = (b['distancia_km'] as double?) ?? 999999;
        return da.compareTo(db);
      });
    }

    return respostaJson(anuncios);
  });

  // -------------------------------------------------------------------
  // MEUS ANÚNCIOS
  // -------------------------------------------------------------------
  rotas.get('/meus', (Request request) async {
    final usuarioId = await usuarioLogado(request);
    final linhas = await Banco.consultar(
      '$_selectAnuncio WHERE a.usuario_id = :usuario ORDER BY a.criado_em DESC',
      {'usuario': usuarioId},
    );
    return respostaJson(linhas.map(anuncioParaJson).toList());
  });

  // -------------------------------------------------------------------
  // DETALHE
  // -------------------------------------------------------------------
  rotas.get('/<id|[0-9]+>', (Request request, String id) async {
    final usuarioId = await usuarioLogado(request);
    final linha = await Banco.consultarUm(
        '$_selectAnuncio WHERE a.id = :id', {'id': int.parse(id)});
    if (linha == null) throw ErroApi(404, 'Anúncio não encontrado.');

    final anuncio = anuncioParaJson(linha);

    // Se quem está vendo já pediu este material, mandamos o pedido junto
    final meuPedido = await Banco.consultarUm(
      'SELECT id, status FROM solicitacoes '
      'WHERE anuncio_id = :anuncio AND solicitante_id = :usuario '
      'ORDER BY id DESC LIMIT 1',
      {'anuncio': int.parse(id), 'usuario': usuarioId},
    );
    anuncio['minha_solicitacao'] = meuPedido == null
        ? null
        : {'id': paraInt(meuPedido['id']), 'status': meuPedido['status']};

    return respostaJson(anuncio);
  });

  // -------------------------------------------------------------------
  // CRIAR
  // -------------------------------------------------------------------
  rotas.post('/', (Request request) async {
    final usuarioId = await usuarioLogado(request);
    final dados = await lerJson(request);
    final campos = _validarCampos(dados);

    final novoId = await Banco.executar(
      'INSERT INTO anuncios (usuario_id, titulo, tipo_material, descricao, '
      'quantidade, unidade, peso_estimado_kg, estado_conservacao, endereco, '
      'latitude, longitude) VALUES (:usuario, :titulo, :tipo, :descricao, '
      ':quantidade, :unidade, :peso, :estado, :endereco, :latitude, :longitude)',
      {...campos, 'usuario': usuarioId},
    );

    // A foto é salva depois, porque o nome do arquivo usa o ID do anúncio
    final fotoUrl = await _salvarFoto(dados['foto_base64'] as String?, novoId);
    if (fotoUrl != null) {
      await Banco.executar('UPDATE anuncios SET foto_url = :foto WHERE id = :id',
          {'foto': fotoUrl, 'id': novoId});
    }

    final linha =
        await Banco.consultarUm('$_selectAnuncio WHERE a.id = :id', {'id': novoId});
    return respostaJson(anuncioParaJson(linha!), status: 201);
  });

  // -------------------------------------------------------------------
  // EDITAR
  // -------------------------------------------------------------------
  rotas.put('/<id|[0-9]+>', (Request request, String id) async {
    final usuarioId = await usuarioLogado(request);
    final anuncioId = int.parse(id);
    final atual = await _anuncioDoDono(anuncioId, usuarioId);
    final dados = await lerJson(request);
    final campos = _validarCampos(dados);

    await Banco.executar(
      'UPDATE anuncios SET titulo = :titulo, tipo_material = :tipo, '
      'descricao = :descricao, quantidade = :quantidade, unidade = :unidade, '
      'peso_estimado_kg = :peso, estado_conservacao = :estado, '
      'endereco = :endereco, latitude = :latitude, longitude = :longitude '
      'WHERE id = :id',
      {...campos, 'id': anuncioId},
    );

    // Foto nova? Troca. Pediu para remover? Remove.
    final fotoNova = await _salvarFoto(dados['foto_base64'] as String?, anuncioId);
    if (fotoNova != null || dados['remover_foto'] == true) {
      await _apagarFoto(atual['foto_url']);
      await Banco.executar('UPDATE anuncios SET foto_url = :foto WHERE id = :id',
          {'foto': fotoNova, 'id': anuncioId});
    }

    final linha = await Banco.consultarUm(
        '$_selectAnuncio WHERE a.id = :id', {'id': anuncioId});
    return respostaJson(anuncioParaJson(linha!));
  });

  // -------------------------------------------------------------------
  // EXCLUIR
  // -------------------------------------------------------------------
  rotas.delete('/<id|[0-9]+>', (Request request, String id) async {
    final usuarioId = await usuarioLogado(request);
    final anuncioId = int.parse(id);
    final atual = await _anuncioDoDono(anuncioId, usuarioId);

    // Avisa quem tinha pedido em aberto
    final pedidos = await Banco.consultar(
      'SELECT solicitante_id FROM solicitacoes '
      "WHERE anuncio_id = :id AND status IN ('pendente', 'aceita')",
      {'id': anuncioId},
    );
    for (final pedido in pedidos) {
      await notificar(paraInt(pedido['solicitante_id'])!, 'Anúncio removido',
          'O anúncio "${atual['titulo']}" foi removido pelo anunciante.');
    }

    await Banco.executar('DELETE FROM anuncios WHERE id = :id', {'id': anuncioId});
    await _apagarFoto(atual['foto_url']);
    return respostaJson({'ok': true});
  });

  // -------------------------------------------------------------------
  // MUDAR STATUS MANUALMENTE (disponível / reservado / retirado)
  // -------------------------------------------------------------------
  rotas.put('/<id|[0-9]+>/status', (Request request, String id) async {
    final usuarioId = await usuarioLogado(request);
    final anuncioId = int.parse(id);
    final atual = await _anuncioDoDono(anuncioId, usuarioId);
    final dados = await lerJson(request);
    final novoStatus = campoTexto(dados, 'status', obrigatorio: true)!;
    if (!statusAnuncio.contains(novoStatus)) {
      throw ErroApi(400, 'Status inválido.');
    }

    await Banco.executar('UPDATE anuncios SET status = :status WHERE id = :id',
        {'status': novoStatus, 'id': anuncioId});

    // Mantém os pedidos coerentes com o novo status
    final aceito = await Banco.consultarUm(
      "SELECT id, solicitante_id FROM solicitacoes WHERE anuncio_id = :id AND status = 'aceita'",
      {'id': anuncioId},
    );
    if (aceito != null) {
      final solicitante = paraInt(aceito['solicitante_id'])!;
      if (novoStatus == 'retirado') {
        await Banco.executar(
            "UPDATE solicitacoes SET status = 'concluida' WHERE id = :id",
            {'id': paraInt(aceito['id'])});
        await notificar(solicitante, 'Retirada concluída',
            'A retirada de "${atual['titulo']}" foi marcada como concluída. Obrigado por reaproveitar!');
      } else if (novoStatus == 'disponivel') {
        await Banco.executar(
            "UPDATE solicitacoes SET status = 'cancelada' WHERE id = :id",
            {'id': paraInt(aceito['id'])});
        await notificar(solicitante, 'Reserva cancelada',
            'A reserva de "${atual['titulo']}" foi cancelada pelo anunciante.');
      }
    }

    final linha = await Banco.consultarUm(
        '$_selectAnuncio WHERE a.id = :id', {'id': anuncioId});
    return respostaJson(anuncioParaJson(linha!));
  });

  return rotas;
}

// ---------------------------------------------------------------------
// Funções de apoio
// ---------------------------------------------------------------------

/// Transforma uma linha do banco (tudo texto) em JSON com os tipos certos.
Map<String, dynamic> anuncioParaJson(Map<String, String?> linha) {
  return {
    'id': paraInt(linha['id']),
    'usuario_id': paraInt(linha['usuario_id']),
    'titulo': linha['titulo'],
    'tipo_material': linha['tipo_material'],
    'descricao': linha['descricao'],
    'quantidade': paraDouble(linha['quantidade']),
    'unidade': linha['unidade'],
    'peso_estimado_kg': paraDouble(linha['peso_estimado_kg']),
    'estado_conservacao': linha['estado_conservacao'],
    'foto_url': linha['foto_url'],
    'endereco': linha['endereco'],
    'latitude': paraDouble(linha['latitude']),
    'longitude': paraDouble(linha['longitude']),
    'status': linha['status'],
    'criado_em': paraDataIso(linha['criado_em']),
    'pedidos_pendentes': paraInt(linha['pedidos_pendentes']) ?? 0,
    'anunciante': {
      'id': paraInt(linha['usuario_id']),
      'nome': linha['anunciante_nome'],
      'tipo': linha['anunciante_tipo'],
      'telefone': linha['anunciante_telefone'],
      'cidade': linha['anunciante_cidade'],
    },
  };
}

/// Confere os campos enviados pelo app e devolve prontos para o SQL.
Map<String, dynamic> _validarCampos(Map<String, dynamic> dados) {
  final titulo = campoTexto(dados, 'titulo',
      obrigatorio: true, nomeAmigavel: 'título', maximo: 120)!;
  final tipo = campoTexto(dados, 'tipo_material',
      obrigatorio: true, nomeAmigavel: 'tipo de material')!;
  if (!tiposMaterial.contains(tipo)) {
    throw ErroApi(400, 'Tipo de material inválido.');
  }

  final quantidade = campoNumero(dados, 'quantidade') ?? 0;
  if (quantidade <= 0) throw ErroApi(400, 'Informe uma quantidade maior que zero.');

  final unidade = campoTexto(dados, 'unidade') ?? 'kg';
  if (!unidadesAceitas.contains(unidade)) {
    throw ErroApi(400, 'Unidade inválida.');
  }

  final peso = campoNumero(dados, 'peso_estimado_kg') ?? 0;
  if (peso < 0) throw ErroApi(400, 'O peso não pode ser negativo.');

  final estado = campoTexto(dados, 'estado_conservacao') ?? 'bom';
  if (!estadosConservacao.contains(estado)) {
    throw ErroApi(400, 'Estado de conservação inválido.');
  }

  return {
    'titulo': titulo,
    'tipo': tipo,
    'descricao': campoTexto(dados, 'descricao', maximo: 2000),
    'quantidade': quantidade,
    'unidade': unidade,
    'peso': peso,
    'estado': estado,
    'endereco': campoTexto(dados, 'endereco', maximo: 200),
    'latitude': campoNumero(dados, 'latitude'),
    'longitude': campoNumero(dados, 'longitude'),
  };
}

/// Busca o anúncio e confere se ele pertence ao usuário logado.
Future<Map<String, String?>> _anuncioDoDono(int anuncioId, int usuarioId) async {
  final linha = await Banco.consultarUm(
      'SELECT id, usuario_id, titulo, foto_url FROM anuncios WHERE id = :id',
      {'id': anuncioId});
  if (linha == null) throw ErroApi(404, 'Anúncio não encontrado.');
  if (paraInt(linha['usuario_id']) != usuarioId) {
    throw ErroApi(403, 'Só quem criou o anúncio pode alterá-lo.');
  }
  return linha;
}

/// Salva a foto (enviada em Base64 pelo app) na pasta "uploads".
/// Devolve o endereço da foto, ex.: "/uploads/anuncio_5_1729700000000.jpg"
Future<String?> _salvarFoto(String? fotoBase64, int anuncioId) async {
  if (fotoBase64 == null || fotoBase64.isEmpty) return null;

  // Alguns navegadores mandam "data:image/jpeg;base64,AAAA..." -> tiramos o começo
  final somenteDados =
      fotoBase64.contains(',') ? fotoBase64.split(',').last : fotoBase64;

  List<int> bytes;
  try {
    bytes = base64Decode(somenteDados);
  } catch (_) {
    throw ErroApi(400, 'Não foi possível ler a foto enviada.');
  }
  if (bytes.length > Config.tamanhoMaximoFoto) {
    throw ErroApi(400, 'A foto é muito grande (máximo 5 MB).');
  }

  final pasta = Directory(Config.pastaFotos);
  if (!pasta.existsSync()) pasta.createSync(recursive: true);

  final nomeArquivo =
      'anuncio_${anuncioId}_${DateTime.now().millisecondsSinceEpoch}.${_extensao(bytes)}';
  await File('${pasta.path}/$nomeArquivo').writeAsBytes(bytes);
  return '/uploads/$nomeArquivo';
}

/// Descobre o tipo da imagem pelos primeiros bytes do arquivo.
String _extensao(List<int> bytes) {
  if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
  if (bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49) return 'gif';
  if (bytes.length > 11 && bytes[8] == 0x57 && bytes[9] == 0x45) return 'webp';
  return 'jpg';
}

/// Apaga o arquivo da foto antiga (se existir).
Future<void> _apagarFoto(String? fotoUrl) async {
  if (fotoUrl == null || !fotoUrl.startsWith('/uploads/')) return;
  final arquivo = File('${Config.pastaFotos}/${fotoUrl.substring(9)}');
  if (arquivo.existsSync()) await arquivo.delete();
}
