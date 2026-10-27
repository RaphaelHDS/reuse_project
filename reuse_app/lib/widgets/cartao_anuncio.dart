// =====================================================================
// cartao_anuncio.dart
// O "card" de um anúncio na lista (feed e meus anúncios).
// =====================================================================

import 'package:flutter/material.dart';

import '../modelos/anuncio.dart';
import '../tema.dart';
import '../util/formatar.dart';
import 'comuns.dart';

class CartaoAnuncio extends StatelessWidget {
  final Anuncio anuncio;
  final VoidCallback aoTocar;
  final bool mostrarPedidos; // usado em "Meus anúncios"

  const CartaoAnuncio({
    super.key,
    required this.anuncio,
    required this.aoTocar,
    this.mostrarPedidos = false,
  });

  @override
  Widget build(BuildContext context) {
    final cinza = TextStyle(color: Colors.grey.shade600, fontSize: 13);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FotoAnuncio(
                fotoUrl: anuncio.fotoUrl,
                tipoMaterial: anuncio.tipoMaterial,
                largura: 96,
                altura: 96,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anuncio.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15.5),
                    ),
                    const SizedBox(height: 4),
                    EtiquetaMaterial(anuncio.tipoMaterial),
                    const SizedBox(height: 4),
                    Text(
                      '${anuncio.quantidadeTexto}  •  ~${formatarKg(anuncio.pesoEstimadoKg)}',
                      style: cinza,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!anuncio.disponivel)
                          SeloStatus(statusAnuncio(anuncio.status), pequeno: true),
                        if (mostrarPedidos && anuncio.pedidosPendentes > 0)
                          SeloStatus(
                            InfoStatus(
                              '${anuncio.pedidosPendentes} pedido(s)',
                              Cores.laranja,
                              Icons.notifications_active,
                            ),
                            pequeno: true,
                          ),
                        if (anuncio.distanciaKm != null)
                          _info(Icons.near_me, formatarDistancia(anuncio.distanciaKm), cinza)
                        else if (anuncio.anunciante.cidade != null)
                          _info(Icons.place, anuncio.anunciante.cidade!, cinza),
                        _info(Icons.schedule, tempoAtras(anuncio.criadoEm), cinza),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icone, String texto, TextStyle estilo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: estilo.color),
        const SizedBox(width: 3),
        Text(texto, style: estilo),
      ],
    );
  }
}
