// =====================================================================
// api.dart
// TODA a conversa do app com a API (back-end em Dart) fica aqui.
// As telas só chamam, por exemplo: await Api.listarAnuncios();
//
// Como funciona: o app manda um pedido HTTP (GET, POST, PUT, DELETE)
// para o endereço da API, e ela responde com dados em JSON.
// =====================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../modelos/anuncio.dart';
import '../modelos/outros_modelos.dart';
import '../modelos/solicitacao.dart';
import '../modelos/usuario.dart';

/// Erro com uma mensagem pronta para mostrar ao usuário.
class ApiException implements Exception {
  final String mensagem;
  final int? status;
  ApiException(this.mensagem, {this.status});

  @override
  String toString() => mensagem;
}

class Api {
  /// Endereço da API, ex.: http://localhost:8080
  static String urlBase = Config.urlPadrao();

  /// "Chave" do login. É enviada em todo pedido.
  static String? token;

  /// O que fazer quando a API disser que o login expirou (definido no main).
  static Future<void> Function()? aoExpirarSessao;

  static const _tempoLimite = Duration(seconds: 20);

  // -------------------------------------------------------------------
  // FUNÇÃO CENTRAL: envia o pedido e trata a resposta/erros
  // -------------------------------------------------------------------
  static Future<dynamic> _enviar(
    String metodo,
    String caminho, {
    Object? corpo,
    Map<String, String>? filtros,
  }) async {
    var uri = Uri.parse('$urlBase$caminho');
    if (filtros != null && filtros.isNotEmpty) {
      uri = uri.replace(queryParameters: filtros);
    }

    final cabecalhos = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final json = corpo == null ? null : jsonEncode(corpo);

    http.Response resposta;
    try {
      final Future<http.Response> pedido;
      switch (metodo) {
        case 'POST':
          pedido = http.post(uri, headers: cabecalhos, body: json);
        case 'PUT':
          pedido = http.put(uri, headers: cabecalhos, body: json);
        case 'DELETE':
          pedido = http.delete(uri, headers: cabecalhos);
        default:
          pedido = http.get(uri, headers: cabecalhos);
      }
      resposta = await pedido.timeout(_tempoLimite);
    } on TimeoutException {
      throw ApiException(
          'O servidor demorou demais para responder. Confira se a API está ligada.');
    } catch (_) {
      throw ApiException(
          'Não consegui falar com o servidor ($urlBase).\n'
          'Confira se a API está ligada e se o endereço do servidor está certo.');
    }

    // Lê a resposta como texto UTF-8 (para os acentos ficarem certos)
    final texto = utf8.decode(resposta.bodyBytes);
    dynamic dados;
    try {
      dados = texto.isEmpty ? null : jsonDecode(texto);
    } catch (_) {
      dados = null;
    }

    if (resposta.statusCode >= 400) {
      final mensagem = (dados is Map && dados['erro'] != null)
          ? dados['erro'].toString()
          : 'Erro ${resposta.statusCode} no servidor.';

      // 401 = não autorizado (login vencido). Volta para a tela de login.
      if (resposta.statusCode == 401 && token != null && !caminho.contains('/login')) {
        await aoExpirarSessao?.call();
      }
      throw ApiException(mensagem, status: resposta.statusCode);
    }
    return dados;
  }

  /// Monta o endereço completo de uma foto. Ex.: "/uploads/a.jpg" ->
  /// "http://localhost:8080/uploads/a.jpg"
  static String? urlFoto(String? caminho) {
    if (caminho == null || caminho.isEmpty) return null;
    if (caminho.startsWith('http')) return caminho;
    return '$urlBase$caminho';
  }

  /// Testa se existe uma API do ReUse no endereço informado.
  static Future<bool> testarConexao(String url) async {
    try {
      final resposta = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      return resposta.statusCode == 200 && resposta.body.contains('ReUse');
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------
  // USUÁRIOS
  // -------------------------------------------------------------------

  /// Login. Devolve o token e o usuário.
  static Future<({String token, Usuario usuario})> login(
      String email, String senha) async {
    final dados = await _enviar('POST', '/usuarios/login',
        corpo: {'email': email, 'senha': senha});
    return (
      token: dados['token'] as String,
      usuario: Usuario.fromJson(dados['usuario'] as Map<String, dynamic>),
    );
  }

  static Future<({String token, Usuario usuario})> cadastrar(
      Map<String, dynamic> campos) async {
    final dados = await _enviar('POST', '/usuarios/cadastro', corpo: campos);
    return (
      token: dados['token'] as String,
      usuario: Usuario.fromJson(dados['usuario'] as Map<String, dynamic>),
    );
  }

  static Future<void> logout() async {
    try {
      await _enviar('POST', '/usuarios/logout');
    } catch (_) {
      // se o servidor estiver desligado, sai mesmo assim
    }
  }

  /// Passo 1 da recuperação: devolve o código (modo demonstração).
  static Future<String?> recuperarSenha(String email) async {
    final dados = await _enviar('POST', '/usuarios/recuperar-senha',
        corpo: {'email': email});
    return dados['codigo_demonstracao'] as String?;
  }

  /// Passo 2 da recuperação: troca a senha usando o código.
  static Future<void> redefinirSenha(
      String email, String codigo, String novaSenha) async {
    await _enviar('POST', '/usuarios/redefinir-senha', corpo: {
      'email': email,
      'codigo': codigo,
      'nova_senha': novaSenha,
    });
  }

  static Future<Usuario> meuPerfil() async {
    final dados = await _enviar('GET', '/usuarios/me');
    return Usuario.fromJson(dados as Map<String, dynamic>);
  }

  static Future<Usuario> atualizarPerfil(Map<String, dynamic> campos) async {
    final dados = await _enviar('PUT', '/usuarios/me', corpo: campos);
    return Usuario.fromJson(dados as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------
  // ANÚNCIOS
  // -------------------------------------------------------------------

  /// Lista anúncios com filtros opcionais.
  static Future<List<Anuncio>> listarAnuncios({
    String? tipo,
    String? busca,
    double? latitude,
    double? longitude,
    double? raioKm,
  }) async {
    // Só manda os filtros que foram escolhidos
    final filtros = <String, String>{};
    if (tipo != null) filtros['tipo'] = tipo;
    if (busca != null && busca.trim().isNotEmpty) filtros['busca'] = busca.trim();
    if (latitude != null) filtros['lat'] = latitude.toString();
    if (longitude != null) filtros['lng'] = longitude.toString();
    if (raioKm != null) filtros['raio_km'] = raioKm.toString();
    final dados = await _enviar('GET', '/anuncios', filtros: filtros);
    return _listaDeAnuncios(dados);
  }

  static Future<List<Anuncio>> meusAnuncios() async {
    final dados = await _enviar('GET', '/anuncios/meus');
    return _listaDeAnuncios(dados);
  }

  static Future<Anuncio> buscarAnuncio(int id) async {
    final dados = await _enviar('GET', '/anuncios/$id');
    return Anuncio.fromJson(dados as Map<String, dynamic>);
  }

  /// Cria um anúncio. A foto (se tiver) vai em "foto_base64".
  static Future<Anuncio> criarAnuncio(Map<String, dynamic> campos) async {
    final dados = await _enviar('POST', '/anuncios', corpo: campos);
    return Anuncio.fromJson(dados as Map<String, dynamic>);
  }

  static Future<Anuncio> editarAnuncio(int id, Map<String, dynamic> campos) async {
    final dados = await _enviar('PUT', '/anuncios/$id', corpo: campos);
    return Anuncio.fromJson(dados as Map<String, dynamic>);
  }

  static Future<void> excluirAnuncio(int id) async {
    await _enviar('DELETE', '/anuncios/$id');
  }

  static Future<Anuncio> mudarStatusAnuncio(int id, String status) async {
    final dados =
        await _enviar('PUT', '/anuncios/$id/status', corpo: {'status': status});
    return Anuncio.fromJson(dados as Map<String, dynamic>);
  }

  static List<Anuncio> _listaDeAnuncios(dynamic dados) => (dados as List<dynamic>)
      .map((item) => Anuncio.fromJson(item as Map<String, dynamic>))
      .toList();

  // -------------------------------------------------------------------
  // PEDIDOS DE RETIRADA (SOLICITAÇÕES) E CHAT
  // -------------------------------------------------------------------

  static Future<Solicitacao> solicitarRetirada({
    required int anuncioId,
    String? mensagem,
    String? finalidade,
  }) async {
    final dados = await _enviar('POST', '/solicitacoes', corpo: {
      'anuncio_id': anuncioId,
      'mensagem': mensagem,
      'finalidade': finalidade,
    });
    return Solicitacao.fromJson(dados as Map<String, dynamic>);
  }

  /// Pedidos que eu RECEBI (nos meus anúncios) e que eu ENVIEI.
  static Future<({List<Solicitacao> recebidas, List<Solicitacao> enviadas})>
      listarSolicitacoes() async {
    final dados = await _enviar('GET', '/solicitacoes') as Map<String, dynamic>;
    List<Solicitacao> converter(dynamic lista) => (lista as List<dynamic>)
        .map((s) => Solicitacao.fromJson(s as Map<String, dynamic>))
        .toList();
    return (
      recebidas: converter(dados['recebidas']),
      enviadas: converter(dados['enviadas']),
    );
  }

  static Future<Solicitacao> buscarSolicitacao(int id) async {
    final dados = await _enviar('GET', '/solicitacoes/$id');
    return Solicitacao.fromJson(dados as Map<String, dynamic>);
  }

  /// acao = 'aceitar' | 'recusar' | 'concluir' | 'cancelar'
  static Future<Solicitacao> acaoSolicitacao(int id, String acao) async {
    final dados = await _enviar('PUT', '/solicitacoes/$id/$acao');
    return Solicitacao.fromJson(dados as Map<String, dynamic>);
  }

  static Future<List<Mensagem>> listarMensagens(int solicitacaoId) async {
    final dados = await _enviar('GET', '/solicitacoes/$solicitacaoId/mensagens');
    return (dados as List<dynamic>)
        .map((m) => Mensagem.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  static Future<void> enviarMensagem(int solicitacaoId, String texto) async {
    await _enviar('POST', '/solicitacoes/$solicitacaoId/mensagens',
        corpo: {'texto': texto});
  }

  // -------------------------------------------------------------------
  // NOTIFICAÇÕES E IMPACTO
  // -------------------------------------------------------------------

  static Future<({int naoLidas, List<Notificacao> itens})> notificacoes() async {
    final dados = await _enviar('GET', '/notificacoes') as Map<String, dynamic>;
    return (
      naoLidas: dados['nao_lidas'] as int? ?? 0,
      itens: (dados['itens'] as List<dynamic>)
          .map((n) => Notificacao.fromJson(n as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<void> marcarNotificacoesLidas() async {
    await _enviar('PUT', '/notificacoes/lidas');
  }

  static Future<Impacto> impacto() async {
    final dados = await _enviar('GET', '/impacto');
    return Impacto.fromJson(dados as Map<String, dynamic>);
  }
}
