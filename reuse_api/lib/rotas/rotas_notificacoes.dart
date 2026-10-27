// =====================================================================
// rotas_notificacoes.dart
// Avisos do sininho.
//
//   GET /notificacoes          -> últimos avisos + quantos não foram lidos
//   PUT /notificacoes/lidas    -> marca todos como lidos
// =====================================================================

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../banco.dart';
import '../utilidades.dart';

Router rotasNotificacoes() {
  final rotas = Router();

  rotas.get('/', (Request request) async {
    final usuarioId = await usuarioLogado(request);

    final linhas = await Banco.consultar(
      'SELECT id, titulo, texto, lida, criado_em FROM notificacoes '
      'WHERE usuario_id = :usuario ORDER BY id DESC LIMIT 50',
      {'usuario': usuarioId},
    );
    final naoLidas = await Banco.consultarUm(
      'SELECT COUNT(*) AS total FROM notificacoes '
      'WHERE usuario_id = :usuario AND lida = 0',
      {'usuario': usuarioId},
    );

    return respostaJson({
      'nao_lidas': paraInt(naoLidas?['total']) ?? 0,
      'itens': linhas
          .map((n) => {
                'id': paraInt(n['id']),
                'titulo': n['titulo'],
                'texto': n['texto'],
                'lida': n['lida'] == '1',
                'criado_em': paraDataIso(n['criado_em']),
              })
          .toList(),
    });
  });

  rotas.put('/lidas', (Request request) async {
    final usuarioId = await usuarioLogado(request);
    await Banco.executar(
        'UPDATE notificacoes SET lida = 1 WHERE usuario_id = :usuario',
        {'usuario': usuarioId});
    return respostaJson({'ok': true});
  });

  return rotas;
}
