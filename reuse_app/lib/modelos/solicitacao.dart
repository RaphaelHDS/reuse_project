// =====================================================================
// solicitacao.dart
// Modelo de um pedido de retirada (e quem participa dele).
// =====================================================================

/// Uma pessoa envolvida no pedido (quem pediu ou o dono do anúncio).
class Participante {
  final int id;
  final String nome;
  final String? telefone;

  Participante({required this.id, required this.nome, this.telefone});

  factory Participante.fromJson(Map<String, dynamic> json) => Participante(
        id: json['id'] as int,
        nome: json['nome'] as String? ?? '',
        telefone: json['telefone'] as String?,
      );
}

/// Resumo do anúncio que foi pedido.
class AnuncioDoPedido {
  final int id;
  final String titulo;
  final String tipoMaterial;
  final String? fotoUrl;
  final String status;
  final double pesoEstimadoKg;

  AnuncioDoPedido({
    required this.id,
    required this.titulo,
    required this.tipoMaterial,
    this.fotoUrl,
    required this.status,
    required this.pesoEstimadoKg,
  });

  factory AnuncioDoPedido.fromJson(Map<String, dynamic> json) => AnuncioDoPedido(
        id: json['id'] as int,
        titulo: json['titulo'] as String? ?? '',
        tipoMaterial: json['tipo_material'] as String? ?? 'Outros',
        fotoUrl: json['foto_url'] as String?,
        status: json['status'] as String? ?? 'disponivel',
        pesoEstimadoKg: (json['peso_estimado_kg'] as num?)?.toDouble() ?? 0,
      );
}

class Solicitacao {
  final int id;
  final String status; // pendente | aceita | recusada | concluida | cancelada
  final String? mensagem;
  final String? finalidade; // o "destino do material"
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;
  final int totalMensagens;
  final AnuncioDoPedido anuncio;
  final Participante solicitante;
  final Participante dono;

  Solicitacao({
    required this.id,
    required this.status,
    this.mensagem,
    this.finalidade,
    this.criadoEm,
    this.atualizadoEm,
    required this.totalMensagens,
    required this.anuncio,
    required this.solicitante,
    required this.dono,
  });

  /// O pedido ainda está "vivo"?
  bool get emAberto => status == 'pendente' || status == 'aceita';

  /// A outra pessoa da conversa (se eu sou o dono, é quem pediu, e vice-versa).
  Participante outraParte(int meuId) => meuId == dono.id ? solicitante : dono;

  factory Solicitacao.fromJson(Map<String, dynamic> json) {
    DateTime? data(String campo) {
      final texto = json[campo] as String?;
      return texto == null ? null : DateTime.tryParse(texto);
    }

    return Solicitacao(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'pendente',
      mensagem: json['mensagem'] as String?,
      finalidade: json['finalidade'] as String?,
      criadoEm: data('criado_em'),
      atualizadoEm: data('atualizado_em'),
      totalMensagens: json['total_mensagens'] as int? ?? 0,
      anuncio: AnuncioDoPedido.fromJson(json['anuncio'] as Map<String, dynamic>),
      solicitante:
          Participante.fromJson(json['solicitante'] as Map<String, dynamic>),
      dono: Participante.fromJson(json['dono'] as Map<String, dynamic>),
    );
  }
}
