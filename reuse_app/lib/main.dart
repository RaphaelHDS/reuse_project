// =====================================================================
// main.dart  -  PONTO DE PARTIDA DO APP
// O Flutter começa a rodar pela função main() abaixo.
// =====================================================================

import 'package:flutter/material.dart';

import 'servicos/api.dart';
import 'servicos/sessao.dart';
import 'tema.dart';
import 'telas/tela_carregando.dart';
import 'telas/tela_login.dart';

/// Chave do "navegador" do app. Com ela conseguimos trocar de tela de
/// qualquer lugar (por exemplo, voltar para o login se a sessão expirar).
final navegador = GlobalKey<NavigatorState>();

void main() {
  // Se a API disser que o login expirou (erro 401), volta para o login.
  Api.aoExpirarSessao = () async {
    await Sessao.sair();
    navegador.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaLogin()),
      (_) => false,
    );
  };

  runApp(const ReUseApp());
}

class ReUseApp extends StatelessWidget {
  const ReUseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReUse',
      debugShowCheckedModeBanner: false, // tira a faixa "DEBUG"
      theme: criarTema(),
      navigatorKey: navegador,
      // Primeira tela: confere se já existe login salvo
      home: const TelaCarregando(),
    );
  }
}
