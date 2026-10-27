// =====================================================================
// tela_principal.dart
// A "casca" do app depois do login: barra de abas embaixo
// (Explorar, Mapa, Pedidos, Perfil), sininho de avisos e botão Anunciar.
// =====================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../widgets/comuns.dart';
import 'tela_feed.dart';
import 'tela_form_anuncio.dart';
import 'tela_mapa.dart';
import 'tela_notificacoes.dart';
import 'tela_pedidos.dart';
import 'tela_perfil.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _aba = 0; // qual aba está aberta
  int _versao = 0; // muda quando precisamos recarregar as abas
  int _naoLidas = 0; // número no sininho
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _atualizarSininho();
    // A cada 30 segundos, confere se chegou aviso novo
    _relogio = Timer.periodic(
        const Duration(seconds: 30), (_) => _atualizarSininho());
  }

  @override
  void dispose() {
    _relogio?.cancel(); // para o relógio quando a tela fecha
    super.dispose();
  }

  Future<void> _atualizarSininho() async {
    try {
      final resultado = await Api.notificacoes();
      if (mounted) setState(() => _naoLidas = resultado.naoLidas);
    } catch (_) {
      // sem conexão: tenta de novo daqui a pouco
    }
  }

  Future<void> _abrirNovoAnuncio() async {
    final publicou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TelaFormAnuncio()),
    );
    if (publicou == true && mounted) {
      mostrarMensagem(context, 'Anúncio publicado! Obrigado por reaproveitar.');
      setState(() => _versao++); // recarrega o feed
    }
  }

  Future<void> _abrirNotificacoes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TelaNotificacoes()),
    );
    _atualizarSininho();
  }

  @override
  Widget build(BuildContext context) {
    // As 4 abas. A "key" com _versao força recarregar quando necessário.
    final abas = [
      TelaFeed(key: ValueKey('feed$_versao')),
      TelaMapa(key: ValueKey('mapa$_versao')),
      TelaPedidos(key: ValueKey('pedidos$_versao')),
      TelaPerfil(key: ValueKey('perfil$_versao')),
    ];
    const titulos = ['Explorar materiais', 'Mapa', 'Pedidos de retirada', 'Meu perfil'];
    final primeiroNome = (Sessao.usuario?.nome ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulos[_aba], style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_aba == 0 && primeiroNome.isNotEmpty)
              Text('Olá, $primeiroNome!',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Avisos',
            onPressed: _abrirNotificacoes,
            icon: Badge(
              isLabelVisible: _naoLidas > 0,
              label: Text('$_naoLidas'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: abas[_aba],
      // Botão "Anunciar" aparece nas abas Explorar e Mapa
      floatingActionButton: _aba <= 1
          ? FloatingActionButton.extended(
              onPressed: _abrirNovoAnuncio,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Anunciar'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (indice) {
          setState(() => _aba = indice);
          _atualizarSininho();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explorar'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Mapa'),
          NavigationDestination(
              icon: Icon(Icons.swap_horiz),
              selectedIcon: Icon(Icons.swap_horizontal_circle),
              label: 'Pedidos'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}
