// =====================================================================
// tela_escolher_local.dart
// Mapa em tela cheia: toque para marcar o local de retirada.
// Devolve a posição (LatLng) para a tela que abriu.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../servicos/localizacao.dart';
import '../tema.dart';

class TelaEscolherLocal extends StatefulWidget {
  final LatLng? inicial;
  const TelaEscolherLocal({super.key, this.inicial});

  @override
  State<TelaEscolherLocal> createState() => _TelaEscolherLocalState();
}

class _TelaEscolherLocalState extends State<TelaEscolherLocal> {
  final _controleMapa = MapController();
  LatLng? _escolhido;

  @override
  void initState() {
    super.initState();
    _escolhido = widget.inicial;
  }

  Future<void> _irParaMinhaLocalizacao() async {
    final local = await Localizacao.obter();
    if (local == null || !mounted) return;
    setState(() => _escolhido = local);
    _controleMapa.move(local, 16);
  }

  @override
  Widget build(BuildContext context) {
    final centro = widget.inicial ?? Localizacao.ultima ?? Localizacao.padrao;

    return Scaffold(
      appBar: AppBar(title: const Text('Local de retirada')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controleMapa,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 15,
              // Ao tocar no mapa, marca o ponto
              onTap: (_, ponto) => setState(() => _escolhido = ponto),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'br.umc.reuse',
              ),
              if (_escolhido != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _escolhido!,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter, // a ponta do pino no ponto
                    child: const Icon(Icons.location_pin,
                        color: Cores.vermelho, size: 48),
                  ),
                ]),
              const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors')),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, color: Cores.verde),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_escolhido == null
                          ? 'Toque no mapa para marcar onde o material será retirado.'
                          : 'Ponto marcado! Toque em outro lugar para mudar.'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 24,
            child: FloatingActionButton.small(
              heroTag: 'local_atual',
              backgroundColor: Colors.white,
              tooltip: 'Minha localização',
              onPressed: _irParaMinhaLocalizacao,
              child: const Icon(Icons.my_location, color: Cores.azul),
            ),
          ),
        ],
      ),
      floatingActionButton: _escolhido == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'confirmar_local',
              onPressed: () => Navigator.pop(context, _escolhido),
              icon: const Icon(Icons.check),
              label: const Text('Confirmar local'),
            ),
    );
  }
}
