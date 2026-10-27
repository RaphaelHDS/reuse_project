// =====================================================================
// config.dart
// Configurações da API. Se o seu banco tiver outra senha ou outra porta,
// é AQUI que você muda.
// =====================================================================

class Config {
  /// Porta em que a API vai rodar. O app acessa http://SEU_IP:8080
  static const int portaServidor = 8080;

  /// Endereço do banco. "127.0.0.1" = o próprio computador.
  static const String bancoHost = '127.0.0.1';

  /// Porta do MySQL. O padrão do XAMPP é 3306.
  static const int bancoPorta = 3306;

  /// Usuário do MySQL. Este usuário é criado pelo arquivo reuse_banco.sql
  /// (não usamos o "root" de propósito: é mais seguro).
  static const String bancoUsuario = 'reuse_app';

  /// Senha do usuário acima (também definida no reuse_banco.sql).
  static const String bancoSenha = 'ReUse@2026';

  /// Nome do banco criado pelo arquivo reuse_banco.sql
  static const String bancoNome = 'reuse_db';

  /// Pasta onde as fotos dos anúncios são salvas.
  static const String pastaFotos = 'uploads';

  /// Tamanho máximo de uma foto (5 MB).
  static const int tamanhoMaximoFoto = 5 * 1024 * 1024;
}
