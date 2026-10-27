// =====================================================================
// rotas_impacto.dart
// Painel de impacto: quantos kg de resíduos foram evitados.
// Conta como "evitado" o peso dos anúncios com status "retirado".
//
//   GET /impacto  -> números da plataforma, do usuário e por material
// =====================================================================

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../banco.dart';
import '../utilidades.dart';

Router rotasImpacto() {
  final rotas = Router();

  rotas.get('/', (Request request) async {
    final usuarioId = await usuarioLogado(request);

    // ---- Plataforma inteira ----
    final geral = await Banco.consultarUm(
      'SELECT COALESCE(SUM(peso_estimado_kg), 0) AS kg, COUNT(*) AS total '
      "FROM anuncios WHERE status = 'retirado'",
    );
    final disponiveis = await Banco.consultarUm(
        "SELECT COUNT(*) AS total FROM anuncios WHERE status = 'disponivel'");
    final usuarios =
        await Banco.consultarUm('SELECT COUNT(*) AS total FROM usuarios');

    // ---- Por tipo de material ----
    final porTipo = await Banco.consultar(
      'SELECT tipo_material, SUM(peso_estimado_kg) AS kg, COUNT(*) AS total '
      "FROM anuncios WHERE status = 'retirado' "
      'GROUP BY tipo_material ORDER BY kg DESC',
    );

    // ---- Do usuário logado ----
    // Doado = materiais que EU anunciei e foram retirados
    final doado = await Banco.consultarUm(
      'SELECT COALESCE(SUM(peso_estimado_kg), 0) AS kg, COUNT(*) AS total '
      "FROM anuncios WHERE status = 'retirado' AND usuario_id = :usuario",
      {'usuario': usuarioId},
    );
    // Recebido = materiais que EU retirei (pedido concluído)
    final recebido = await Banco.consultarUm(
      'SELECT COALESCE(SUM(a.peso_estimado_kg), 0) AS kg, COUNT(*) AS total '
      'FROM solicitacoes s JOIN anuncios a ON a.id = s.anuncio_id '
      "WHERE s.status = 'concluida' AND s.solicitante_id = :usuario",
      {'usuario': usuarioId},
    );
    final meusAtivos = await Banco.consultarUm(
      'SELECT COUNT(*) AS total FROM anuncios '
      "WHERE status <> 'retirado' AND usuario_id = :usuario",
      {'usuario': usuarioId},
    );

    return respostaJson({
      'plataforma': {
        'kg_evitados': paraDouble(geral?['kg']) ?? 0,
        'materiais_retirados': paraInt(geral?['total']) ?? 0,
        'anuncios_disponiveis': paraInt(disponiveis?['total']) ?? 0,
        'usuarios': paraInt(usuarios?['total']) ?? 0,
      },
      'meu': {
        'kg_doados': paraDouble(doado?['kg']) ?? 0,
        'doacoes': paraInt(doado?['total']) ?? 0,
        'kg_recebidos': paraDouble(recebido?['kg']) ?? 0,
        'recebimentos': paraInt(recebido?['total']) ?? 0,
        'anuncios_ativos': paraInt(meusAtivos?['total']) ?? 0,
      },
      'por_tipo': porTipo
          .map((t) => {
                'tipo': t['tipo_material'],
                'kg': paraDouble(t['kg']) ?? 0,
                'quantidade': paraInt(t['total']) ?? 0,
              })
          .toList(),
    });
  });

  return rotas;
}
