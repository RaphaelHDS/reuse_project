// =====================================================================
// anuncio.dart
// Modelo de um anúncio de material.
// =====================================================================

import 'package:latlong2/latlong.dart';

import '../util/formatar.dart';

/// Resumo de quem anunciou (vem junto com o anúncio).
class Anunciante {
  final int id;
  final String nome;
  final String tipo;
  final String? telefone;
  final String? cidade;

  Anunciante({
    required this.id,
    required this.nome,
    required this.tipo,
    this.telefone,
    this.cidade,
  });

  factory Anunciante.fromJson(Map<String, dynamic> json) => Anunciante(
        id: json['id'] as int,
        nome: json['nome'] as String? ?? '',
        tipo: json['tipo'] as String? ?? 'pessoa',
        telefone: json['telefone'] as String?,
        cidade: json['cidade'] as String?,
      );
}

class Anuncio {
  final int id;
  final int usuarioId;
  final String titulo;
  final String tipoMaterial;
  final String? descricao;
  final double quantidade;
  final String unidade;
  final double pesoEstimadoKg;
  final String estadoConservacao;
  final String? fotoUrl;
  final String? endereco;
  final double? latitude;
  final double? longitude;
  final String status; // disponivel | reservado | retirado
  final DateTime? criadoEm;
  final int pedidosPendentes;
  final Anunciante anunciante;
  final double? distanciaKm; // só vem quando o app manda a localização

  /// Se EU já pedi este material: {id, status}. Senão, null.
  final int? minhaSolicitacaoId;
  final String? minhaSolicitacaoStatus;

  Anuncio({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.tipoMaterial,
    this.descricao,
    required this.quantidade,
    required this.unidade,
    required this.pesoEstimadoKg,
    required this.estadoConservacao,
    this.fotoUrl,
    this.endereco,
    this.latitude,
    this.longitude,
    required this.status,
    this.criadoEm,
    this.pedidosPendentes = 0,
    required this.anunciante,
    this.distanciaKm,
    this.minhaSolicitacaoId,
    this.minhaSolicitacaoStatus,
  });

  /// Posição no mapa (ou null se o anúncio não tiver local).
  LatLng? get posicao => (latitude != null && longitude != null)
      ? LatLng(latitude!, longitude!)
      : null;

  /// Ex.: "30 kg" ou "12 unidades"
  String get quantidadeTexto => '${formatarNumero(quantidade)} $unidade';

  bool get disponivel => status == 'disponivel';

  /// Tenho um pedido "vivo" (pendente ou aceito) para este anúncio?
  bool get tenhoPedidoAberto =>
      minhaSolicitacaoStatus == 'pendente' || minhaSolicitacaoStatus == 'aceita';

  factory Anuncio.fromJson(Map<String, dynamic> json) {
    final minha = json['minha_solicitacao'] as Map<String, dynamic>?;
    final data = json['criado_em'] as String?;
    return Anuncio(
      id: json['id'] as int,
      usuarioId: json['usuario_id'] as int,
      titulo: json['titulo'] as String? ?? '',
      tipoMaterial: json['tipo_material'] as String? ?? 'Outros',
      descricao: json['descricao'] as String?,
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0,
      unidade: json['unidade'] as String? ?? 'kg',
      pesoEstimadoKg: (json['peso_estimado_kg'] as num?)?.toDouble() ?? 0,
      estadoConservacao: json['estado_conservacao'] as String? ?? 'bom',
      fotoUrl: json['foto_url'] as String?,
      endereco: json['endereco'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'disponivel',
      criadoEm: data == null ? null : DateTime.tryParse(data),
      pedidosPendentes: json['pedidos_pendentes'] as int? ?? 0,
      anunciante: Anunciante.fromJson(json['anunciante'] as Map<String, dynamic>),
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      minhaSolicitacaoId: minha?['id'] as int?,
      minhaSolicitacaoStatus: minha?['status'] as String?,
    );
  }
}
