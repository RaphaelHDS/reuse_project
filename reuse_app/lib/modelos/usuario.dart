// =====================================================================
// usuario.dart
// "Modelo" = a forma de um dado dentro do app. Aqui: um usuário.
// fromJson transforma o JSON que vem da API em um objeto Dart.
// =====================================================================

class Usuario {
  final int id;
  final String tipo; // 'pessoa' ou 'empresa'
  final String nome;
  final String email;
  final String? telefone;
  final String? cidade;
  final String? cnpj;
  final String? ramoAtividade;

  Usuario({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.email,
    this.telefone,
    this.cidade,
    this.cnpj,
    this.ramoAtividade,
  });

  bool get ehEmpresa => tipo == 'empresa';

  /// Primeira letra do nome (para o "avatar").
  String get inicial => nome.isEmpty ? '?' : nome[0].toUpperCase();

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      tipo: json['tipo'] as String? ?? 'pessoa',
      nome: json['nome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      telefone: json['telefone'] as String?,
      cidade: json['cidade'] as String?,
      cnpj: json['cnpj'] as String?,
      ramoAtividade: json['ramo_atividade'] as String?,
    );
  }

  /// O caminho contrário: objeto -> JSON (usado para salvar no aparelho).
  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'nome': nome,
        'email': email,
        'telefone': telefone,
        'cidade': cidade,
        'cnpj': cnpj,
        'ramo_atividade': ramoAtividade,
      };
}
