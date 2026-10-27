// =====================================================================
// tela_detalhe_anuncio.dart
// Tudo sobre um anúncio: foto, dados, local no mapa, quem anunciou,
// ideias de reutilização (IA) e os botões de ação:
//   - Interessado: "Solicitar retirada", WhatsApp, abrir conversa
//   - Dono: editar, excluir e mudar o status
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../ia/assistente_ia.dart';
import '../modelos/anuncio.dart';
import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../servicos/whatsapp.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/comuns.dart';
import '../widgets/painel_ia.dart';
import 'tela_chat.dart';
import 'tela_form_anuncio.dart';

class TelaDetalheAnuncio extends StatefulWidget {
  final int anuncioId;
  const TelaDetalheAnuncio({super.key, required this.anuncioId});

  @override
  State<TelaDetalheAnuncio> createState() => _TelaDetalheAnuncioState();
}

class _TelaDetalheAnuncioState extends State<TelaDetalheAnuncio> {
  Anuncio? _anuncio;
  Object? _erro;
  bool _ocupado = false; // true enquanto um botão está trabalhando

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final anuncio = await Api.buscarAnuncio(widget.anuncioId);
      if (mounted) setState(() => _anuncio = anuncio);
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    }
  }

  bool get _souDono => _anuncio?.usuarioId == Sessao.meuId;

  // ------------------------------------------------------------------
  // AÇÕES
  // ------------------------------------------------------------------

  /// Abre a janela para pedir a retirada do material.
  Future<void> _solicitarRetirada() async {
    final anuncio = _anuncio!;
    final finalidade = TextEditingController();
    final mensagem = TextEditingController(
        text: 'Olá! Tenho interesse em "${anuncio.titulo}". Quando posso retirar?');

    final enviar = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Solicitar retirada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: finalidade,
                decoration: const InputDecoration(
                  labelText: 'O que você vai fazer com o material?',
                  hintText: 'Ex.: artesanato, horta na escola...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mensagem,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Mensagem para o anunciante'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(contextoDialogo, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.pop(contextoDialogo, true),
              child: const Text('Enviar pedido')),
        ],
      ),
    );
    if (enviar != true) return;

    setState(() => _ocupado = true);
    try {
      await Api.solicitarRetirada(
        anuncioId: anuncio.id,
        finalidade: finalidade.text.trim(),
        mensagem: mensagem.text.trim(),
      );
      if (mounted) {
        mostrarMensagem(context,
            'Pedido enviado! Acompanhe na aba Pedidos ou pela conversa.');
      }
      await _carregar();
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrirWhatsApp() async {
    final anuncio = _anuncio!;
    final ok = await abrirWhatsApp(
      anuncio.anunciante.telefone ?? '',
      'Olá, ${anuncio.anunciante.nome}! Vi seu anúncio "${anuncio.titulo}" no ReUse e tenho interesse.',
    );
    if (!ok && mounted) {
      mostrarMensagem(context, 'Não foi possível abrir o WhatsApp.', erro: true);
    }
  }

  Future<void> _editar() async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TelaFormAnuncio(anuncio: _anuncio)),
    );
    if (salvou == true) {
      if (mounted) mostrarMensagem(context, 'Anúncio atualizado!');
      _carregar();
    }
  }

  Future<void> _excluir() async {
    final certeza = await confirmar(
      context,
      titulo: 'Excluir anúncio?',
      texto: 'Essa ação não pode ser desfeita.',
      textoSim: 'Excluir',
      perigoso: true,
    );
    if (!certeza) return;
    try {
      await Api.excluirAnuncio(_anuncio!.id);
      if (!mounted) return;
      mostrarMensagem(context, 'Anúncio excluído.');
      Navigator.pop(context);
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    }
  }

  Future<void> _mudarStatus(String status) async {
    setState(() => _ocupado = true);
    try {
      final atualizado = await Api.mudarStatusAnuncio(_anuncio!.id, status);
      if (mounted) {
        setState(() => _anuncio = atualizado);
        mostrarMensagem(context, 'Status: ${statusAnuncio(status).texto}');
      }
      await _carregar();
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // ------------------------------------------------------------------
  // TELA
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final anuncio = _anuncio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anúncio'),
        actions: [
          if (anuncio != null && _souDono) ...[
            IconButton(
                tooltip: 'Editar', onPressed: _editar, icon: const Icon(Icons.edit)),
            IconButton(
                tooltip: 'Excluir',
                onPressed: _excluir,
                icon: const Icon(Icons.delete_outline)),
          ],
        ],
      ),
      body: _erro != null
          ? ErroCarregamento(erro: _erro!, aoTentarDeNovo: _carregar)
          : anuncio == null
              ? const Center(child: CircularProgressIndicator())
              : _conteudo(anuncio),
      bottomNavigationBar: anuncio == null ? null : _barraDeAcoes(anuncio),
    );
  }

  Widget _conteudo(Anuncio anuncio) {
    final info = AssistenteIA.infoDoTipo(anuncio.tipoMaterial);

    return LarguraMaxima(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FotoAnuncio(
            fotoUrl: anuncio.fotoUrl,
            tipoMaterial: anuncio.tipoMaterial,
            altura: 240,
            largura: double.infinity,
            raio: 18,
            tamanhoIcone: 80,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SeloStatus(statusAnuncio(anuncio.status)),
              const SizedBox(width: 10),
              EtiquetaMaterial(anuncio.tipoMaterial),
              const Spacer(),
              Text(tempoAtras(anuncio.criadoEm),
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(anuncio.titulo,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Números principais
          Row(
            children: [
              _caixaInfo(Icons.inventory, 'Quantidade', anuncio.quantidadeTexto),
              const SizedBox(width: 8),
              _caixaInfo(Icons.scale, 'Peso estimado', formatarKg(anuncio.pesoEstimadoKg)),
              const SizedBox(width: 8),
              _caixaInfo(Icons.star_half, 'Estado',
                  estadosConservacao[anuncio.estadoConservacao] ?? '-'),
            ],
          ),

          if ((anuncio.descricao ?? '').isNotEmpty) ...[
            const TituloSecao('Descrição'),
            Text(anuncio.descricao!, style: const TextStyle(fontSize: 15, height: 1.4)),
          ],

          // Local de retirada
          const TituloSecao('Local de retirada'),
          if (anuncio.endereco != null)
            Row(
              children: [
                const Icon(Icons.place, color: Cores.vermelho, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(anuncio.endereco!)),
              ],
            ),
          if (anuncio.distanciaKm != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('A ${formatarDistancia(anuncio.distanciaKm)} de você',
                  style: TextStyle(color: Colors.grey.shade700)),
            ),
          if (anuncio.posicao != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: anuncio.posicao!,
                    initialZoom: 15,
                    // mapa "parado" (só para mostrar o ponto)
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'br.umc.reuse',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: anuncio.posicao!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_pin,
                            color: Cores.vermelho, size: 40),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],

          // Quem anunciou
          const TituloSecao('Anunciado por'),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Cores.verdeClaro,
                child: Icon(
                  anuncio.anunciante.tipo == 'empresa' ? Icons.store : Icons.person,
                  color: Cores.verde,
                ),
              ),
              title: Text(anuncio.anunciante.nome),
              subtitle: Text([
                anuncio.anunciante.tipo == 'empresa' ? 'Empresa' : 'Pessoa',
                if (anuncio.anunciante.cidade != null) anuncio.anunciante.cidade!,
              ].join(' • ')),
            ),
          ),

          // Diferencial: ideias da IA
          const TituloSecao('Como reaproveitar (sugestões da IA)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: IdeiasReutilizacao(info: info),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _caixaInfo(IconData icone, String rotulo, String valor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icone, color: Cores.verde, size: 20),
            const SizedBox(height: 4),
            Text(valor,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(rotulo,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  /// Botões fixos na parte de baixo da tela.
  Widget _barraDeAcoes(Anuncio anuncio) {
    List<Widget> botoes;

    if (_souDono) {
      // ---- Visão do DONO: mudar o status ----
      botoes = [
        Expanded(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'disponivel', label: Text('Disponível')),
              ButtonSegment(value: 'reservado', label: Text('Reservado')),
              ButtonSegment(value: 'retirado', label: Text('Retirado')),
            ],
            selected: {anuncio.status},
            showSelectedIcon: false,
            onSelectionChanged:
                _ocupado ? null : (escolha) => _mudarStatus(escolha.first),
          ),
        ),
      ];
    } else {
      // ---- Visão de quem quer o material ----
      final temTelefone = (anuncio.anunciante.telefone ?? '').isNotEmpty;
      final Widget principal;
      if (anuncio.tenhoPedidoAberto) {
        principal = FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    TelaChat(solicitacaoId: anuncio.minhaSolicitacaoId!)),
          ),
          icon: const Icon(Icons.chat),
          label: Text(anuncio.minhaSolicitacaoStatus == 'aceita'
              ? 'Pedido aceito - conversar'
              : 'Pedido enviado - conversar'),
        );
      } else if (anuncio.disponivel) {
        principal = FilledButton.icon(
          onPressed: _ocupado ? null : _solicitarRetirada,
          icon: const Icon(Icons.volunteer_activism),
          label: const Text('Solicitar retirada'),
        );
      } else {
        principal = FilledButton(
          onPressed: null,
          child: Text('Material ${statusAnuncio(anuncio.status).texto.toLowerCase()}'),
        );
      }

      botoes = [
        Expanded(child: principal),
        if (temTelefone) ...[
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _abrirWhatsApp,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('WhatsApp'),
          ),
        ],
      ];
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_souDono && anuncio.pedidosPendentes > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${anuncio.pedidosPendentes} pedido(s) esperando resposta na aba Pedidos',
                  style: const TextStyle(color: Cores.laranja, fontWeight: FontWeight.w600),
                ),
              ),
            Row(children: botoes),
          ],
        ),
      ),
    );
  }
}
