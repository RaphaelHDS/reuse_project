// =====================================================================
// outros_modelos.dart
// Modelos menores: mensagem do chat, notificação e painel de impacto.
// =====================================================================

DateTime? _data(dynamic texto) =>
    texto is String ? DateTime.tryParse(texto) : null;

double _numero(dynamic valor) => (valor as num?)?.toDouble() ?? 0;

/// Uma mensagem do chat.
class Mensagem {
  final int id;
  final int remetenteId;
  final String remetenteNome;
  final String texto;
  final DateTime? criadoEm;

  Mensagem({
    required this.id,
    required this.remetenteId,
    required this.remetenteNome,
    required this.texto,
    this.criadoEm,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) => Mensagem(
        id: json['id'] as int,
        remetenteId: json['remetente_id'] as int,
        remetenteNome: json['remetente_nome'] as String? ?? '',
        texto: json['texto'] as String? ?? '',
        criadoEm: _data(json['criado_em']),
      );
}

/// Um aviso do sininho.
class Notificacao {
  final int id;
  final String titulo;
  final String texto;
  final bool lida;
  final DateTime? criadoEm;

  Notificacao({
    required this.id,
    required this.titulo,
    required this.texto,
    required this.lida,
    this.criadoEm,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) => Notificacao(
        id: json['id'] as int,
        titulo: json['titulo'] as String? ?? '',
        texto: json['texto'] as String? ?? '',
        lida: json['lida'] as bool? ?? false,
        criadoEm: _data(json['criado_em']),
      );
}

/// Quantos kg foram reaproveitados de um tipo de material.
class ImpactoPorTipo {
  final String tipo;
  final double kg;
  final int quantidade;
  ImpactoPorTipo(this.tipo, this.kg, this.quantidade);
}

/// Números do painel de impacto.
class Impacto {
  // Plataforma inteira
  final double kgEvitados;
  final int materiaisRetirados;
  final int anunciosDisponiveis;
  final int usuarios;
  // Usuário logado
  final double kgDoados;
  final int doacoes;
  final double kgRecebidos;
  final int recebimentos;
  final int anunciosAtivos;
  // Por tipo
  final List<ImpactoPorTipo> porTipo;

  Impacto({
    required this.kgEvitados,
    required this.materiaisRetirados,
    required this.anunciosDisponiveis,
    required this.usuarios,
    required this.kgDoados,
    required this.doacoes,
    required this.kgRecebidos,
    required this.recebimentos,
    required this.anunciosAtivos,
    required this.porTipo,
  });

  factory Impacto.fromJson(Map<String, dynamic> json) {
    final p = json['plataforma'] as Map<String, dynamic>;
    final m = json['meu'] as Map<String, dynamic>;
    final tipos = json['por_tipo'] as List<dynamic>;
    return Impacto(
      kgEvitados: _numero(p['kg_evitados']),
      materiaisRetirados: p['materiais_retirados'] as int? ?? 0,
      anunciosDisponiveis: p['anuncios_disponiveis'] as int? ?? 0,
      usuarios: p['usuarios'] as int? ?? 0,
      kgDoados: _numero(m['kg_doados']),
      doacoes: m['doacoes'] as int? ?? 0,
      kgRecebidos: _numero(m['kg_recebidos']),
      recebimentos: m['recebimentos'] as int? ?? 0,
      anunciosAtivos: m['anuncios_ativos'] as int? ?? 0,
      porTipo: tipos
          .map((t) => ImpactoPorTipo(
                t['tipo'] as String? ?? 'Outros',
                _numero(t['kg']),
                t['quantidade'] as int? ?? 0,
              ))
          .toList(),
    );
  }
}
