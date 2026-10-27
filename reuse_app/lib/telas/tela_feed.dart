// =====================================================================
// tela_feed.dart  (aba "Explorar")
// Lista de materiais disponíveis, com:
//   - busca por texto
//   - filtro por tipo de material
//   - filtro por distância (usa a localização do aparelho)
//   - puxar a lista para baixo para atualizar
// =====================================================================

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../modelos/anuncio.dart';
import '../servicos/api.dart';
import '../servicos/localizacao.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/cartao_anuncio.dart';
import '../widgets/comuns.dart';
import 'tela_detalhe_anuncio.dart';
import 'tela_impacto.dart';

/// Opções do filtro de distância em km (0 = qualquer distância).
const opcoesDistancia = <double>[0, 1, 5, 10, 25, 50];

/// Texto de cada opção de distância.
String textoDistancia(double km) =>
    km == 0 ? 'Qualquer distância' : 'Até ${formatarNumero(km)} km';

class TelaFeed extends StatefulWidget {
  const TelaFeed({super.key});

  @override
  State<TelaFeed> createState() => _TelaFeedState();
}

class _TelaFeedState extends State<TelaFeed> {
  List<Anuncio>? _anuncios;
  Object? _erro;
  bool _carregando = false;

  // Filtros
  final _busca = TextEditingController();
  String? _tipo; // null = todos
  double _raioKm = 0; // 0 = qualquer distância

  // Localização
  LatLng? _local = Localizacao.ultima;
  bool _buscandoLocal = false;

  // Banner do impacto
  double? _kgEvitados;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarImpacto();
    if (_local == null) _pegarLocalizacao();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await Api.listarAnuncios(
        tipo: _tipo,
        busca: _busca.text,
        latitude: _local?.latitude,
        longitude: _local?.longitude,
        raioKm: (_local == null || _raioKm == 0) ? null : _raioKm,
      );
      if (mounted) setState(() => _anuncios = lista);
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarImpacto() async {
    try {
      final impacto = await Api.impacto();
      if (mounted) setState(() => _kgEvitados = impacto.kgEvitados);
    } catch (_) {
      // o banner é só um enfeite: se falhar, não mostra
    }
  }

  Future<void> _pegarLocalizacao() async {
    setState(() => _buscandoLocal = true);
    final local = await Localizacao.obter();
    if (!mounted) return;
    setState(() {
      _local = local;
      _buscandoLocal = false;
    });
    if (local != null) {
      _carregar(); // recarrega já com as distâncias
    } else {
      mostrarMensagem(context,
          'Não consegui pegar sua localização. Verifique se ela está ligada e permitida.');
    }
  }

  Future<void> _abrirAnuncio(Anuncio anuncio) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TelaDetalheAnuncio(anuncioId: anuncio.id)),
    );
    _carregar(); // pode ter mudado algo (ex.: pedido feito)
  }

  @override
  Widget build(BuildContext context) {
    return LarguraMaxima(
      child: RefreshIndicator(
        onRefresh: _carregar,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _bannerImpacto()),
            SliverToBoxAdapter(child: _campoBusca()),
            SliverToBoxAdapter(child: _filtroTipos()),
            SliverToBoxAdapter(child: _filtroDistancia()),
            ..._conteudo(),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  // ---------------- Partes da tela ----------------

  Widget _bannerImpacto() {
    if (_kgEvitados == null) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Cores.verde,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TelaImpacto())),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.white, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      children: [
                        const TextSpan(text: 'A comunidade já evitou\n'),
                        TextSpan(
                          text: formatarKg(_kgEvitados),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' de resíduos'),
                      ],
                    ),
                  ),
                ),
                const Text('Ver painel',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _busca,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _carregar(),
        decoration: InputDecoration(
          hintText: 'Buscar: palete, retalho, garrafa...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _busca.clear();
              _carregar();
            },
          ),
        ),
      ),
    );
  }

  Widget _filtroTipos() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: _tipo == null,
              onSelected: (_) {
                setState(() => _tipo = null);
                _carregar();
              },
            ),
          ),
          for (final tipo in tiposMaterial)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
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
    );
  }

  Widget _filtroDistancia() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.near_me,
              size: 18, color: _local != null ? Cores.verde : Colors.grey),
          const SizedBox(width: 6),
          if (_local != null) ...[
            DropdownButton<double>(
              value: _raioKm,
              underline: const SizedBox(),
              items: [
                for (final km in opcoesDistancia)
                  DropdownMenuItem(value: km, child: Text(textoDistancia(km))),
              ],
              onChanged: (km) {
                setState(() => _raioKm = km ?? 0);
                _carregar();
              },
            ),
          ] else
            Expanded(
              child: Text(
                _buscandoLocal
                    ? 'Buscando sua localização...'
                    : 'Localização desligada (sem filtro de distância)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          if (_local == null && !_buscandoLocal)
            TextButton(
                onPressed: _pegarLocalizacao, child: const Text('Ativar')),
        ],
      ),
    );
  }

  List<Widget> _conteudo() {
    if (_anuncios == null && _carregando) {
      return const [
        SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator())),
      ];
    }
    if (_erro != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErroCarregamento(erro: _erro!, aoTentarDeNovo: _carregar),
        ),
      ];
    }
    final lista = _anuncios ?? [];
    if (lista.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EstadoVazio(
            icone: Icons.search_off,
            titulo: 'Nenhum material encontrado',
            texto: 'Tente outro filtro ou aumente a distância.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => CartaoAnuncio(
            anuncio: lista[i],
            aoTocar: () => _abrirAnuncio(lista[i]),
          ),
        ),
      ),
    ];
  }
}
