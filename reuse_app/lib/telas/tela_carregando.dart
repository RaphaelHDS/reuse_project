// =====================================================================
// tela_carregando.dart
// Primeira tela: mostra o logo enquanto confere se já existe login salvo.
// Se existir -> vai para a tela principal. Se não -> vai para o login.
// =====================================================================

import 'package:flutter/material.dart';

import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../tema.dart';
import 'tela_login.dart';
import 'tela_principal.dart';

class TelaCarregando extends StatefulWidget {
  const TelaCarregando({super.key});

  @override
  State<TelaCarregando> createState() => _TelaCarregandoState();
}

class _TelaCarregandoState extends State<TelaCarregando> {
  @override
  void initState() {
    super.initState();
    _decidirTela();
  }

  Future<void> _decidirTela() async {
    await Sessao.carregar();
    Widget proxima = const TelaLogin();

    if (Sessao.logado) {
      proxima = const TelaPrincipal();
      try {
        // Atualiza os dados do usuário (e confere se o login ainda vale)
        await Sessao.atualizarUsuario(await Api.meuPerfil());
      } on ApiException catch (erro) {
        if (erro.status == 401) proxima = const TelaLogin();
        // Outros erros (ex.: servidor desligado): segue com os dados salvos
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => proxima),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Cores.verde,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoReUse(tamanho: 96, claro: true),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Logo do app: ícone de reciclagem + nome "ReUse".
class LogoReUse extends StatelessWidget {
  final double tamanho;
  final bool claro; // true = branco (para fundo verde)

  const LogoReUse({super.key, this.tamanho = 72, this.claro = false});

  @override
  Widget build(BuildContext context) {
    final cor = claro ? Colors.white : Cores.verde;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tamanho,
          height: tamanho,
          decoration: BoxDecoration(
            color: claro ? Colors.white.withValues(alpha: 0.18) : Cores.verdeClaro,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.recycling, color: cor, size: tamanho * 0.6),
        ),
        const SizedBox(height: 10),
        Text(
          'ReUse',
          style: TextStyle(
            color: cor,
            fontSize: tamanho * 0.42,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
