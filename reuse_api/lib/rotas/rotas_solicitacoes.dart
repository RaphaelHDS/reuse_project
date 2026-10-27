// =====================================================================
// rotas_solicitacoes.dart
// Pedidos de retirada e o chat interno entre as partes.
//
//   POST /solicitacoes                    -> pedir a retirada de um material
//   GET  /solicitacoes                    -> meus pedidos (recebidos e enviados)
//   GET  /solicitacoes/<id>               -> um pedido
//   PUT  /solicitacoes/<id>/aceitar       -> dono aceita (anúncio fica "reservado")
//   PUT  /solicitacoes/<id>/recusar       -> dono recusa
//   PUT  /solicitacoes/<id>/concluir      -> dono confirma retirada ("retirado")
//   PUT  /solicitacoes/<id>/cancelar      -> qualquer uma das partes cancela
//   GET  /solicitacoes/<id>/mensagens     -> mensagens do chat
//   POST /solicitacoes/<id>/mensagens     -> envia mensagem no chat
// =====================================================================

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../banco.dart';
import '../utilidades.dart';

/// SELECT base: pedido + anúncio + quem pediu + dono do anúncio.
const _selectSolicitacao = '''
SELECT s.id, s.anuncio_id, s.solicitante_id, s.mensagem, s.finalidade,
       s.status, s.criado_em, s.atualizado_em,
       a.titulo, a.tipo_material, a.foto_url, a.status AS anuncio_status,
       a.usuario_id AS dono_id, a.quantidade, a.unidade, a.peso_estimado_kg,
       sol.nome AS solicitante_nome, sol.telefone AS solicitante_telefone,
       dono.nome AS dono_nome, dono.telefone AS dono_telefone,
       (SELECT COUNT(*) FROM mensagens m WHERE m.solicitacao_id = s.id) AS total_mensagens
FROM solicitacoes s
JOIN anuncios a ON a.id = s.anuncio_id
JOIN usuarios sol ON sol.id = s.solicitante_id
JOIN usuarios dono ON dono.id = a.usuario_id
''';

Router rotasSolicitacoes() {
  final rotas = Router();

  // -------------------------------------------------------------------
  // PEDIR RETIRADA
  // -------------------------------------------------------------------
  rotas.post('/', (Request request) async {
    final usuarioId = await usuarioLogado(request);
    final dados = await lerJson(request);
    final anuncioId = campoNumero(dados, 'anuncio_id')?.toInt();
    if (anuncioId == null) throw ErroApi(400, 'Anúncio não informado.');

    final anuncio = await Banco.consultarUm(
        'SELECT id, usuario_id, titulo, status FROM anuncios WHERE id = :id',
        {'id': anuncioId});
    if (anuncio == null) throw ErroApi(404, 'Anúncio não encontrado.');

    final donoId = paraInt(anuncio['usuario_id'])!;
    if (donoId == usuarioId) {
      throw ErroApi(400, 'Você não pode pedir o seu próprio material.');
    }
    if (anuncio['status'] != 'disponivel') {
      throw ErroApi(400, 'Este material não está mais disponível.');
    }

    final jaPediu = await Banco.consultarUm(
      'SELECT id FROM solicitacoes WHERE anuncio_id = :anuncio '
      "AND solicitante_id = :usuario AND status IN ('pendente', 'aceita')",
      {'anuncio': anuncioId, 'usuario': usuarioId},
    );
    if (jaPediu != null) {
      throw ErroApi(400, 'Você já tem um pedido em aberto para este material.');
    }

    final mensagem = campoTexto(dados, 'mensagem', maximo: 500);
    final novoId = await Banco.executar(
      'INSERT INTO solicitacoes (anuncio_id, solicitante_id, mensagem, finalidade) '
      'VALUES (:anuncio, :usuario, :mensagem, :finalidade)',
      {
        'anuncio': anuncioId,
        'usuario': usuarioId,
        'mensagem': mensagem,
        'finalidade': campoTexto(dados, 'finalidade', maximo: 150),
      },
    );

    // A mensagem do pedido também vira a primeira mensagem do chat
    if (mensagem != null) {
      await Banco.executar(
        'INSERT INTO mensagens (solicitacao_id, remetente_id, texto) '
        'VALUES (:solicitacao, :usuario, :texto)',
        {'solicitacao': novoId, 'usuario': usuarioId, 'texto': mensagem},
      );
    }

    final nomeSolicitante = await _nomeUsuario(usuarioId);
    await notificar(donoId, 'Nova solicitação',
        '$nomeSolicitante quer retirar "${anuncio['titulo']}".');

    return respostaJson(await _buscarSolicitacao(novoId), status: 201);
  });

  // -------------------------------------------------------------------
  // LISTAR MEUS PEDIDOS
  // -------------------------------------------------------------------
  rotas.get('/', (Request request) async {
    final usuarioId = await usuarioLogado(request);

    final recebidas = await Banco.consultar(
      '$_selectSolicitacao WHERE a.usuario_id = :usuario ORDER BY s.atualizado_em DESC',
      {'usuario': usuarioId},
    );
    final enviadas = await Banco.consultar(
      '$_selectSolicitacao WHERE s.solicitante_id = :usuario ORDER BY s.atualizado_em DESC',
      {'usuario': usuarioId},
    );

    return respostaJson({
      'recebidas': recebidas.map(_solicitacaoParaJson).toList(),
      'enviadas': enviadas.map(_solicitacaoParaJson).toList(),
    });
  });

  // -------------------------------------------------------------------
  // UM PEDIDO
  // -------------------------------------------------------------------
  rotas.get('/<id|[0-9]+>', (Request request, String id) async {
    final usuarioId = await usuarioLogado(request);
    final pedido = await _buscarSolicitacao(int.parse(id));
    _conferirParticipante(pedido, usuarioId);
    return respostaJson(pedido);
  });

  // -------------------------------------------------------------------
  // AÇÕES: aceitar, recusar, concluir, cancelar
  // -------------------------------------------------------------------
  rotas.put('/<id|[0-9]+>/<acao>', (Request request, String id, String acao) async {
    final usuarioId = await usuarioLogado(request);
    final pedido = await _buscarSolicitacao(int.parse(id));
    _conferirParticipante(pedido, usuarioId);

    final pedidoId = pedido['id'] as int;
    final anuncioId = pedido['anuncio_id'] as int;
    final donoId = (pedido['dono'] as Map)['id'] as int;
    final solicitanteId = (pedido['solicitante'] as Map)['id'] as int;
    final titulo = (pedido['anuncio'] as Map)['titulo'];
    final pesoKg = (pedido['anuncio'] as Map)['peso_estimado_kg'];
    final status = pedido['status'];
    final souDono = usuarioId == donoId;

    switch (acao) {
      case 'aceitar':
        if (!souDono) throw ErroApi(403, 'Só o anunciante pode aceitar.');
        if (status != 'pendente') throw ErroApi(400, 'Este pedido não está pendente.');
        if ((pedido['anuncio'] as Map)['status'] != 'disponivel') {
          throw ErroApi(400, 'O material já está reservado ou retirado.');
        }
        await _mudarStatus(pedidoId, 'aceita');
        await _mudarStatusAnuncio(anuncioId, 'reservado');
        await notificar(solicitanteId, 'Pedido aceito',
            'Seu pedido de "$titulo" foi aceito! Combine a retirada pelo chat.');

        // Os outros pedidos pendentes deste anúncio são recusados
        final outros = await Banco.consultar(
          'SELECT id, solicitante_id FROM solicitacoes '
          "WHERE anuncio_id = :anuncio AND id <> :id AND status = 'pendente'",
          {'anuncio': anuncioId, 'id': pedidoId},
        );
        for (final outro in outros) {
          await _mudarStatus(paraInt(outro['id'])!, 'recusada');
          await notificar(paraInt(outro['solicitante_id'])!, 'Material reservado',
              '"$titulo" foi reservado para outra pessoa.');
        }
        break;

      case 'recusar':
        if (!souDono) throw ErroApi(403, 'Só o anunciante pode recusar.');
        if (status != 'pendente') throw ErroApi(400, 'Este pedido não está pendente.');
        await _mudarStatus(pedidoId, 'recusada');
        await notificar(solicitanteId, 'Pedido recusado',
            'Seu pedido de "$titulo" foi recusado.');
        break;

      case 'concluir':
        if (!souDono) {
          throw ErroApi(403, 'Só o anunciante pode confirmar a retirada.');
        }
        if (status != 'aceita') {
          throw ErroApi(400, 'Aceite o pedido antes de concluir a retirada.');
        }
        await _mudarStatus(pedidoId, 'concluida');
        await _mudarStatusAnuncio(anuncioId, 'retirado');
        await notificar(solicitanteId, 'Retirada concluída',
            'Retirada de "$titulo" concluída! Juntos evitamos ${formatarNumero(pesoKg as num?)} kg de resíduos.');
        break;

      case 'cancelar':
        if (status != 'pendente' && status != 'aceita') {
          throw ErroApi(400, 'Este pedido não pode mais ser cancelado.');
        }
        await _mudarStatus(pedidoId, 'cancelada');
        if (status == 'aceita') {
          // Estava reservado: volta a ficar disponível
          await _mudarStatusAnuncio(anuncioId, 'disponivel');
        }
        final outraParte = souDono ? solicitanteId : donoId;
        await notificar(outraParte, 'Pedido cancelado',
            'O pedido de "$titulo" foi cancelado.');
        break;

      default:
        throw ErroApi(404, 'Ação desconhecida: $acao');
    }

    return respostaJson(await _buscarSolicitacao(pedidoId));
  });

  // -------------------------------------------------------------------
  // CHAT: listar mensagens
  // -------------------------------------------------------------------
  rotas.get('/<id|[0-9]+>/mensagens', (Request request, String id) async {
    final usuarioId = await usuarioLogado(request);
    final pedido = await _buscarSolicitacao(int.parse(id));
    _conferirParticipante(pedido, usuarioId);

    final linhas = await Banco.consultar(
      'SELECT m.id, m.remetente_id, m.texto, m.criado_em, u.nome AS remetente_nome '
      'FROM mensagens m JOIN usuarios u ON u.id = m.remetente_id '
      'WHERE m.solicitacao_id = :id ORDER BY m.id ASC',
      {'id': int.parse(id)},
    );
    return respostaJson(linhas
        .map((m) => {
              'id': paraInt(m['id']),
              'remetente_id': paraInt(m['remetente_id']),
              'remetente_nome': m['remetente_nome'],
              'texto': m['texto'],
              'criado_em': paraDataIso(m['criado_em']),
            })
        .toList());
  });

  // -------------------------------------------------------------------
  // CHAT: enviar mensagem
  // -------------------------------------------------------------------
  rotas.post('/<id|[0-9]+>/mensagens', (Request request, String id) async {
    final usuarioId = await usuarioLogado(request);
    final pedido = await _buscarSolicitacao(int.parse(id));
    _conferirParticipante(pedido, usuarioId);

    final dados = await lerJson(request);
    final texto = campoTexto(dados, 'texto',
        obrigatorio: true, nomeAmigavel: 'mensagem', maximo: 1000)!;

    await Banco.executar(
      'INSERT INTO mensagens (solicitacao_id, remetente_id, texto) '
      'VALUES (:solicitacao, :usuario, :texto)',
      {'solicitacao': int.parse(id), 'usuario': usuarioId, 'texto': texto},
    );
    return respostaJson({'ok': true}, status: 201);
  });

  return rotas;
}

// ---------------------------------------------------------------------
// Funções de apoio
// ---------------------------------------------------------------------

Future<Map<String, dynamic>> _buscarSolicitacao(int id) async {
  final linha =
      await Banco.consultarUm('$_selectSolicitacao WHERE s.id = :id', {'id': id});
  if (linha == null) throw ErroApi(404, 'Pedido não encontrado.');
  return _solicitacaoParaJson(linha);
}

/// Só o dono do anúncio e quem pediu podem ver/mexer no pedido.
void _conferirParticipante(Map<String, dynamic> pedido, int usuarioId) {
  final donoId = (pedido['dono'] as Map)['id'];
  final solicitanteId = (pedido['solicitante'] as Map)['id'];
  if (usuarioId != donoId && usuarioId != solicitanteId) {
    throw ErroApi(403, 'Você não participa deste pedido.');
  }
}

Future<void> _mudarStatus(int solicitacaoId, String status) async {
  await Banco.executar('UPDATE solicitacoes SET status = :status WHERE id = :id',
      {'status': status, 'id': solicitacaoId});
}

Future<void> _mudarStatusAnuncio(int anuncioId, String status) async {
  await Banco.executar('UPDATE anuncios SET status = :status WHERE id = :id',
      {'status': status, 'id': anuncioId});
}

Future<String> _nomeUsuario(int id) async {
  final linha =
      await Banco.consultarUm('SELECT nome FROM usuarios WHERE id = :id', {'id': id});
  return linha?['nome'] ?? 'Alguém';
}

Map<String, dynamic> _solicitacaoParaJson(Map<String, String?> linha) {
  return {
    'id': paraInt(linha['id']),
    'anuncio_id': paraInt(linha['anuncio_id']),
    'status': linha['status'],
    'mensagem': linha['mensagem'],
    'finalidade': linha['finalidade'],
    'criado_em': paraDataIso(linha['criado_em']),
    'atualizado_em': paraDataIso(linha['atualizado_em']),
    'total_mensagens': paraInt(linha['total_mensagens']) ?? 0,
    'anuncio': {
      'id': paraInt(linha['anuncio_id']),
      'titulo': linha['titulo'],
      'tipo_material': linha['tipo_material'],
      'foto_url': linha['foto_url'],
      'status': linha['anuncio_status'],
      'quantidade': paraDouble(linha['quantidade']),
      'unidade': linha['unidade'],
      'peso_estimado_kg': paraDouble(linha['peso_estimado_kg']),
    },
    'solicitante': {
      'id': paraInt(linha['solicitante_id']),
      'nome': linha['solicitante_nome'],
      'telefone': linha['solicitante_telefone'],
    },
    'dono': {
      'id': paraInt(linha['dono_id']),
      'nome': linha['dono_nome'],
      'telefone': linha['dono_telefone'],
    },
  };
}
