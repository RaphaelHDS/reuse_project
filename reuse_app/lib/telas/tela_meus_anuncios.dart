// =====================================================================
// tela_meus_anuncios.dart
// Lista dos anúncios que EU publiquei (com status e pedidos).
// Toque em um anúncio para editar, excluir ou mudar o status.
// =====================================================================

import 'package:flutter/material.dart';

import '../modelos/anuncio.dart';
import '../servicos/api.dart';
import '../widgets/cartao_anuncio.dart';
import '../widgets/comuns.dart';
import 'tela_detalhe_anuncio.dart';
import 'tela_form_anuncio.dart';

class TelaMeusAnuncios extends StatefulWidget {
  const TelaMeusAnuncios({super.key});

  @override
  State<TelaMeusAnuncios> createState() => _TelaMeusAnunciosState();
}

class _TelaMeusAnunciosState extends State<TelaMeusAnuncios> {
  List<Anuncio>? _anuncios;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final lista = await Api.meusAnuncios();
      if (mounted) setState(() => _anuncios = lista);
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    }
  }

  Future<void> _novo() async {
    final publicou = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const TelaFormAnuncio()));
    if (publicou == true) {
      if (mounted) mostrarMensagem(context, 'Anúncio publicado!');
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (_erro != null) {
      corpo = ErroCarregamento(erro: _erro!, aoTentarDeNovo: _carregar);
    } else if (_anuncios == null) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_anuncios!.isEmpty) {
      corpo = EstadoVazio(
        icone: Icons.inventory_2_outlined,
        titulo: 'Você ainda não anunciou nada',
        texto: 'Tem material sobrando? Anuncie e evite que ele vire lixo!',
        textoBotao: 'Criar anúncio',
        aoTocarBotao: _novo,
      );
    } else {
      corpo = RefreshIndicator(
        onRefresh: _carregar,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: _anuncios!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => CartaoAnuncio(
            anuncio: _anuncios![i],
            mostrarPedidos: true,
            aoTocar: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TelaDetalheAnuncio(anuncioId: _anuncios![i].id)),
              );
              _carregar();
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meus anúncios')),
      body: LarguraMaxima(child: corpo),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novo,
        icon: const Icon(Icons.add),
        label: const Text('Novo anúncio'),
      ),
    );
  }
}
