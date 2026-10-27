// =====================================================================
// server.dart  -  PONTO DE PARTIDA DA API
// Para ligar a API, no terminal (dentro da pasta reuse_api):
//     dart run bin/server.dart
//
// O que este arquivo faz:
//   1. Conecta no banco de dados
//   2. Junta todas as rotas (usuarios, anuncios, solicitacoes...)
//   3. Liga o servidor na porta 8080 e mostra o endereço para o app
// =====================================================================

import 'dart:io';

import 'package:reuse_api/banco.dart';
import 'package:reuse_api/config.dart';
import 'package:reuse_api/rotas/rotas_anuncios.dart';
import 'package:reuse_api/rotas/rotas_impacto.dart';
import 'package:reuse_api/rotas/rotas_notificacoes.dart';
import 'package:reuse_api/rotas/rotas_solicitacoes.dart';
import 'package:reuse_api/rotas/rotas_usuarios.dart';
import 'package:reuse_api/utilidades.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

Future<void> main() async {
  print('');
  print('==============================================');
  print('  ReUse API - ligando...');
  print('==============================================');

  // Confere se o terminal está aberto na pasta certa
  if (!File('pubspec.yaml').existsSync()) {
    print('[ATENÇÃO] Rode este comando de dentro da pasta "reuse_api".');
  }

  // ---------------------------------------------------------------
  // 1) Banco de dados
  // ---------------------------------------------------------------
  try {
    await Banco.conectar();
    print('[OK] Conectado ao banco "${Config.bancoNome}" '
        'em ${Config.bancoHost}:${Config.bancoPorta}');
  } catch (erro) {
    print('');
    print('[ERRO] Não consegui conectar no banco de dados.');
    print('       Detalhe: $erro');
    print('');
    print('  Confira:');
    print('  1) O XAMPP está aberto e o MySQL está ligado (botão Start, fica verde)?');
    print('  2) Você importou o arquivo reuse_banco.sql no phpMyAdmin?');
    print('     (ele cria o banco "reuse_db" e o usuário "reuse_app")');
    print('  3) A porta do MySQL é ${Config.bancoPorta}? (veja no XAMPP, coluna "Port(s)")');
    print('');
    exit(1);
  }

  // ---------------------------------------------------------------
  // 2) Rotas (cada endereço da API e quem responde por ele)
  // ---------------------------------------------------------------
  final app = Router();

  // Rota de teste: abra http://localhost:8080 no navegador
  app.get('/', (Request request) {
    return respostaJson({
      'app': 'ReUse API',
      'status': 'funcionando',
      'hora': DateTime.now().toIso8601String(),
    });
  });

  app.mount('/usuarios', rotasUsuarios().call);
  app.mount('/anuncios', rotasAnuncios().call);
  app.mount('/solicitacoes', rotasSolicitacoes().call);
  app.mount('/notificacoes', rotasNotificacoes().call);
  app.mount('/impacto', rotasImpacto().call);

  // Fotos dos anúncios: GET /uploads/nome_do_arquivo.jpg
  app.get('/uploads/<arquivo>', _entregarFoto);

  // ---------------------------------------------------------------
  // 3) "Middlewares": coisas que rodam em TODO pedido
  //    - logRequests: mostra cada pedido no terminal
  //    - _liberarCors: deixa o app no Chrome acessar a API
  //    - _tratarErros: transforma erros em mensagens JSON amigáveis
  // ---------------------------------------------------------------
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_liberarCors())
      .addMiddleware(_tratarErros())
      .addHandler(app.call);

  // anyIPv4 = aceita conexões do próprio PC e de outros aparelhos da rede
  final servidor = await shelf_io.serve(
      handler, InternetAddress.anyIPv4, Config.portaServidor);

  print('[OK] Servidor rodando!');
  print('');
  print('  No computador (Chrome):  http://localhost:${servidor.port}');
  for (final ip in await _ipsDaRede()) {
    print('  No celular (mesmo Wi-Fi): http://$ip:${servidor.port}');
  }
  print('');
  print('  Deixe esta janela aberta enquanto usa o app.');
  print('  Para desligar a API: clique aqui e aperte Ctrl + C');
  print('==============================================');
}

// ---------------------------------------------------------------------
// Entrega o arquivo de uma foto da pasta "uploads"
// ---------------------------------------------------------------------
Response _entregarFoto(Request request, String arquivo) {
  // Segurança: não deixa acessar arquivos fora da pasta
  if (arquivo.contains('..') || arquivo.contains('/') || arquivo.contains('\\')) {
    return Response.forbidden('Acesso negado');
  }
  final file = File('${Config.pastaFotos}/$arquivo');
  if (!file.existsSync()) return Response.notFound('Foto não encontrada');

  final extensao = arquivo.split('.').last.toLowerCase();
  const tipos = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
  };
  return Response.ok(
    file.readAsBytesSync(),
    headers: {
      'content-type': tipos[extensao] ?? 'application/octet-stream',
      'cache-control': 'public, max-age=86400',
    },
  );
}

// ---------------------------------------------------------------------
// CORS: o navegador só deixa o app (rodando no Chrome) falar com a API
// se a API responder com estes cabeçalhos.
// ---------------------------------------------------------------------
Middleware _liberarCors() {
  const cabecalhos = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };
  return (Handler proximo) {
    return (Request request) async {
      // O Chrome manda um pedido "OPTIONS" antes, só para perguntar se pode
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: cabecalhos);
      }
      final resposta = await proximo(request);
      return resposta.change(headers: cabecalhos);
    };
  };
}

// ---------------------------------------------------------------------
// Tratamento de erros: se algo der errado em uma rota, a API não cai.
// Ela responde {"erro": "mensagem"} e o app mostra essa mensagem.
// ---------------------------------------------------------------------
Middleware _tratarErros() {
  return (Handler proximo) {
    return (Request request) async {
      try {
        return await proximo(request);
      } on ErroApi catch (erro) {
        return respostaErro(erro.status, erro.mensagem);
      } catch (erro, pilha) {
        print('[ERRO INESPERADO] $erro');
        print(pilha);
        return respostaErro(500, 'Erro interno no servidor: $erro');
      }
    };
  };
}

/// Lista os IPs deste computador na rede (para usar no celular).
Future<List<String>> _ipsDaRede() async {
  try {
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [
      for (final interface in interfaces)
        for (final endereco in interface.addresses)
          if (!endereco.isLoopback) endereco.address,
    ];
  } catch (_) {
    return [];
  }
}
