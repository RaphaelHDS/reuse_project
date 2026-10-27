// =====================================================================
// banco.dart
// Cuida da conexão com o banco de dados MySQL/MariaDB.
// O resto da API só chama Banco.consultar(...) e Banco.executar(...).
// =====================================================================

import 'package:mysql_client/mysql_client.dart';

import 'config.dart';

class Banco {
  /// "Pool" = um grupo de conexões reaproveitadas (mais rápido que abrir
  /// uma conexão nova a cada pedido).
  static MySQLConnectionPool? _pool;

  /// Conecta no banco. É chamado uma vez, quando a API liga.
  ///
  /// O MySQL 8 exige conexão segura (TLS). Já o MySQL do XAMPP (MariaDB)
  /// normalmente não tem TLS. Por isso tentamos primeiro a conexão segura
  /// e, se o servidor disser que não suporta SSL, tentamos a normal.
  static Future<void> conectar() async {
    bool seguro = true;
    try {
      await _testarConexao(seguro: true);
    } catch (erro) {
      final mensagem = erro.toString().toLowerCase();
      if (mensagem.contains('ssl')) {
        seguro = false;
        await _testarConexao(seguro: false);
      } else {
        rethrow; // outro problema (senha errada, banco não existe...)
      }
    }

    _pool = MySQLConnectionPool(
      host: Config.bancoHost,
      port: Config.bancoPorta,
      userName: Config.bancoUsuario,
      password: Config.bancoSenha,
      databaseName: Config.bancoNome,
      maxConnections: 5,
      secure: seguro,
      collation: 'utf8mb4_general_ci', // aceita acentos e emojis
    );
  }

  /// Abre uma conexão só para testar se está tudo certo, e fecha.
  static Future<void> _testarConexao({required bool seguro}) async {
    final conexao = await MySQLConnection.createConnection(
      host: Config.bancoHost,
      port: Config.bancoPorta,
      userName: Config.bancoUsuario,
      password: Config.bancoSenha,
      databaseName: Config.bancoNome,
      secure: seguro,
    );
    await conexao.connect(timeoutMs: 5000);
    await conexao.execute('SELECT 1');
    await conexao.close();
  }

  static MySQLConnectionPool get _conexoes {
    final pool = _pool;
    if (pool == null) {
      throw StateError('Banco não conectado. Chame Banco.conectar() antes.');
    }
    return pool;
  }

  /// Faz um SELECT e devolve a lista de linhas.
  /// Cada linha é um Map: {'nome_da_coluna': 'valor em texto'}.
  ///
  /// Os valores vão em [parametros] e aparecem no SQL como :nome.
  /// Exemplo:
  ///   Banco.consultar('SELECT * FROM usuarios WHERE id = :id', {'id': 1});
  /// Isso evita "SQL Injection" (o pacote trata os valores com segurança).
  static Future<List<Map<String, String?>>> consultar(
    String sql, [
    Map<String, dynamic>? parametros,
  ]) async {
    final resultado = await _conexoes.execute(sql, parametros);
    return resultado.rows.map((linha) => linha.assoc()).toList();
  }

  /// Igual ao consultar, mas devolve só a primeira linha (ou null).
  static Future<Map<String, String?>?> consultarUm(
    String sql, [
    Map<String, dynamic>? parametros,
  ]) async {
    final linhas = await consultar(sql, parametros);
    return linhas.isEmpty ? null : linhas.first;
  }

  /// Executa INSERT, UPDATE ou DELETE.
  /// Devolve o ID gerado (no caso de INSERT) ou 0.
  static Future<int> executar(
    String sql, [
    Map<String, dynamic>? parametros,
  ]) async {
    final resultado = await _conexoes.execute(sql, parametros);
    return resultado.lastInsertID.toInt();
  }
}
