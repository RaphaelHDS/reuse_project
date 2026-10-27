// =====================================================================
// sessao.dart
// Guarda quem está logado e o endereço do servidor, no próprio aparelho
// (com o pacote shared_preferences). Assim o usuário não precisa fazer
// login toda vez que abre o app.
// =====================================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../modelos/usuario.dart';
import 'api.dart';

class Sessao {
  static const _chaveToken = 'token';
  static const _chaveUsuario = 'usuario';
  static const _chaveUrl = 'url_api';

  /// Usuário logado (null se ninguém estiver logado).
  static Usuario? usuario;

  static bool get logado => Api.token != null && usuario != null;

  /// ID de quem está logado (0 se ninguém).
  static int get meuId => usuario?.id ?? 0;

  /// Lê o que estava salvo no aparelho. Chamado quando o app abre.
  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    Api.urlBase = prefs.getString(_chaveUrl) ?? Config.urlPadrao();
    Api.token = prefs.getString(_chaveToken);
    final textoUsuario = prefs.getString(_chaveUsuario);
    if (textoUsuario != null) {
      try {
        usuario = Usuario.fromJson(jsonDecode(textoUsuario) as Map<String, dynamic>);
      } catch (_) {
        usuario = null;
      }
    }
  }

  /// Salva o login (depois de entrar ou criar conta).
  static Future<void> salvarLogin(String token, Usuario novoUsuario) async {
    Api.token = token;
    await atualizarUsuario(novoUsuario);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveToken, token);
  }

  /// Atualiza os dados do usuário salvos (ex.: depois de editar o perfil).
  static Future<void> atualizarUsuario(Usuario novoUsuario) async {
    usuario = novoUsuario;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveUsuario, jsonEncode(novoUsuario.toJson()));
  }

  /// Sai da conta.
  static Future<void> sair() async {
    Api.token = null;
    usuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveToken);
    await prefs.remove(_chaveUsuario);
  }

  /// Muda o endereço do servidor (API).
  static Future<void> salvarUrl(String url) async {
    // tira a barra do final: "http://x:8080/" -> "http://x:8080"
    var limpa = url.trim();
    while (limpa.endsWith('/')) {
      limpa = limpa.substring(0, limpa.length - 1);
    }
    if (!limpa.startsWith('http')) limpa = 'http://$limpa';
    Api.urlBase = limpa;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveUrl, limpa);
  }
}
