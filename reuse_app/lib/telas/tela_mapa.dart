// =====================================================================
// tela_mapa.dart  (aba "Mapa")
// Mostra os anúncios disponíveis no mapa. Cada material tem um
// marcador colorido. Toque no marcador para ver um resumo.
// O mapa é do OpenStreetMap (gratuito, sem chave).
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../modelos/anuncio.dart';
import '../servicos/api.dart';
import '../servicos/localizacao.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/comuns.dart';
import 'tela_detalhe_anuncio.dart';
import 'tela_feed.dart' show opcoesDistancia, textoDistancia;

class TelaMapa extends StatefulWidget {
  const TelaMapa({super.key});

  @override
  State<TelaMapa> createState() => _TelaMapaState();
}

class _TelaMapaState extends State<TelaMapa> {
  final _controleMapa = MapController();
  List<Anuncio> _anuncios = [];
  LatLng? _local = Localizacao.ultima;
  String? _tipo;
  double _raioKm = 0; // 0 = qualquer distância
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    if (_local == null) _pegarLocalizacao();
  }

  Future<void> _pegarLocalizacao() async {
    final local = await Localizacao.obter();
    if (!mounted || local == null) return;
    setState(() => _local = local);
    _controleMapa.move(local, 14);
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await Api.listarAnuncios(
        tipo: _tipo,
        latitude: _local?.latitude,
        longitude: _local?.longitude,
        raioKm: (_local == null || _raioKm == 0) ? null : _raioKm,
      );
      if (mounted) setState(() => _anuncios = lista);
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Janela de resumo quando toca em um marcador.
  void _mostrarResumo(Anuncio anuncio) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (contextoJanela) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FotoAnuncio(
                  fotoUrl: anuncio.fotoUrl,
                  tipoMaterial: anuncio.tipoMaterial,
                  largura: 80,
                  altura: 80,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(anuncio.titulo,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      EtiquetaMaterial(anuncio.tipoMaterial),
                      const SizedBox(height: 4),
                      Text([
                        anuncio.quantidadeTexto,
                        if (anuncio.distanciaKm != null)
                          formatarDistancia(anuncio.distanciaKm),
                      ].join('  •  ')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                Navigator.pop(contextoJanela);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TelaDetalheAnuncio(anuncioId: anuncio.id)),
                );
                _carregar();
              },
              child: const Text('Ver anúncio'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centro = _local ?? Localizacao.padrao;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controleMapa,
          options: MapOptions(initialCenter: centro, initialZoom: 13),
          children: [
            // Camada 1: as "imagens" do mapa (ruas, bairros...)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'br.umc.reuse',
            ),
            // Camada 2: círculo do filtro de distância
            if (_local != null && _raioKm > 0)
              CircleLayer(circles: [
                CircleMarker(
                  point: _local!,
                  radius: _raioKm * 1000, // em metros
                  useRadiusInMeter: true,
                  color: Cores.verde.withValues(alpha: 0.08),
                  borderColor: Cores.verde,
                  borderStrokeWidth: 1.5,
                ),
              ]),
            // Camada 3: marcadores dos anúncios e da minha posição
            MarkerLayer(
              markers: [
                for (final anuncio in _anuncios)
                  if (anuncio.posicao != null)
                    Marker(
                      point: anuncio.posicao!,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _mostrarResumo(anuncio),
                        child: _marcador(anuncio.tipoMaterial),
                      ),
                    ),
                if (_local != null)
                  Marker(
                    point: _local!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Cores.azul,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(blurRadius: 4, color: Colors.black26)
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Crédito obrigatório do OpenStreetMap
            const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors')),
          ],
        ),

        // Filtros por cima do mapa
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (_local != null) _botaoDistancia(),
                for (final tipo in tiposMaterial)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      backgroundColor: Colors.white,
                      avatar: Icon(tipo.icone, size: 18, color: tipo.cor),
                      label: Text(tipo.nome),
                      selected: _tipo == tipo.nome,
                      onSelected: (_) {
                        setState(() => _tipo = _tipo == tipo.nome ? null : tipo.nome);
                        _carregar();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (_carregando)
          const Positioned(
              top: 60, left: 0, right: 0, child: Center(child: CircularProgressIndicator())),

        // Botão "minha localização"
        Positioned(
          left: 12,
          bottom: 24,
          child: FloatingActionButton.small(
            heroTag: 'minha_localizacao',
            tooltip: 'Minha localização',
            backgroundColor: Colors.white,
            onPressed: () {
              if (_local != null) {
                _controleMapa.move(_local!, 14);
              } else {
                _pegarLocalizacao();
              }
            },
            child: const Icon(Icons.my_location, color: Cores.azul),
          ),
        ),
      ],
    );
  }

  /// Bolinha colorida com o ícone do material.
  Widget _marcador(String tipoMaterial) {
    final tipo = tipoPorNome(tipoMaterial);
    return Container(
      decoration: BoxDecoration(
        color: tipo.cor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
      ),
      child: Icon(tipo.icone, color: Colors.white, size: 22),
    );
  }

  /// Botão do filtro de distância (abre um menu com as opções).
  Widget _botaoDistancia() {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: PopupMenuButton<double>(
        tooltip: 'Distância',
        onSelected: (km) {
          setState(() => _raioKm = km);
          _carregar();
        },
        itemBuilder: (_) => [
          for (final km in opcoesDistancia)
            PopupMenuItem(
              value: km,
              child: Text(textoDistancia(km)),
            ),
        ],
        child: Chip(
          backgroundColor: Colors.white,
          avatar: const Icon(Icons.near_me, size: 18, color: Cores.verde),
          label: Text(_raioKm == 0 ? 'Distância' : 'Até ${formatarNumero(_raioKm)} km'),
        ),
      ),
    );
  }
}
