// =====================================================================
// tela_pedidos.dart  (aba "Pedidos")
// Duas listas:
//   RECEBIDOS = pedidos que outras pessoas fizeram nos MEUS anúncios
//   ENVIADOS  = pedidos que EU fiz nos anúncios dos outros
// Daqui dá para aceitar, recusar, confirmar a retirada, cancelar e
// abrir a conversa (chat).
// =====================================================================

import 'package:flutter/material.dart';

import '../modelos/solicitacao.dart';
import '../servicos/api.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/comuns.dart';
import 'tela_chat.dart';

class TelaPedidos extends StatefulWidget {
  const TelaPedidos({super.key});

  @override
  State<TelaPedidos> createState() => _TelaPedidosState();
}

class _TelaPedidosState extends State<TelaPedidos> {
  List<Solicitacao>? _recebidas;
  List<Solicitacao>? _enviadas;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final resultado = await Api.listarSolicitacoes();
      if (mounted) {
        setState(() {
          _recebidas = resultado.recebidas;
          _enviadas = resultado.enviadas;
        });
      }
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    }
  }

  /// Executa uma ação (aceitar, recusar, concluir, cancelar).
  Future<void> _acao(Solicitacao pedido, String acao) async {
    const perguntas = {
      'aceitar': ('Aceitar pedido?', 'O material ficará RESERVADO para esta pessoa. Os outros pedidos serão recusados.'),
      'recusar': ('Recusar pedido?', 'A pessoa será avisada.'),
      'concluir': ('Confirmar retirada?', 'O material será marcado como RETIRADO e entrará no painel de impacto.'),
      'cancelar': ('Cancelar pedido?', 'Se o material estava reservado, ele volta a ficar disponível.'),
    };
    final pergunta = perguntas[acao]!;
    final certeza = await confirmar(context,
        titulo: pergunta.$1,
        texto: pergunta.$2,
        perigoso: acao == 'recusar' || acao == 'cancelar');
    if (!certeza) return;

    try {
      await Api.acaoSolicitacao(pedido.id, acao);
      if (!mounted) return;
      const mensagens = {
        'aceitar': 'Pedido aceito! Combine a retirada pelo chat.',
        'recusar': 'Pedido recusado.',
        'concluir': 'Retirada concluída! Obrigado por reaproveitar.',
        'cancelar': 'Pedido cancelado.',
      };
      mostrarMensagem(context, mensagens[acao]!);
      _carregar();
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    }
  }

  Future<void> _abrirChat(Solicitacao pedido) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaChat(solicitacaoId: pedido.id)),
    );
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_erro != null) {
      return ErroCarregamento(erro: _erro!, aoTentarDeNovo: _carregar);
    }
    if (_recebidas == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final abertosRecebidos = _recebidas!.where((p) => p.emAberto).length;

    return DefaultTabController(
      length: 2,
      child: LarguraMaxima(
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: 'Recebidos ($abertosRecebidos)'),
                Tab(text: 'Enviados (${_enviadas!.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _lista(_recebidas!, recebidos: true),
                  _lista(_enviadas!, recebidos: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(List<Solicitacao> pedidos, {required bool recebidos}) {
    if (pedidos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          children: [
            SizedBox(
              height: 400,
              child: EstadoVazio(
                icone: recebidos ? Icons.inbox : Icons.outbox,
                titulo: recebidos
                    ? 'Ninguém pediu seus materiais ainda'
                    : 'Você ainda não pediu nenhum material',
                texto: recebidos
                    ? 'Quando alguém pedir, o pedido aparece aqui.'
                    : 'Encontre materiais na aba Explorar.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: pedidos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _cartao(pedidos[i], recebidos),
      ),
    );
  }

  Widget _cartao(Solicitacao pedido, bool recebido) {
    final pessoa = recebido ? pedido.solicitante : pedido.dono;
    final cinza = TextStyle(color: Colors.grey.shade700);

    // Botões que fazem sentido para cada situação
    final botoes = <Widget>[];
    if (recebido && pedido.status == 'pendente') {
      botoes.addAll([
        TextButton(
            onPressed: () => _acao(pedido, 'recusar'),
            child: const Text('Recusar')),
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
            onPressed: () => _acao(pedido, 'aceitar'),
            child: const Text('Aceitar')),
      ]);
    } else if (recebido && pedido.status == 'aceita') {
      botoes.addAll([
        TextButton(
            onPressed: () => _acao(pedido, 'cancelar'),
            child: const Text('Cancelar')),
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
            onPressed: () => _acao(pedido, 'concluir'),
            child: const Text('Confirmar retirada')),
      ]);
    } else if (!recebido && pedido.emAberto) {
      botoes.add(TextButton(
          onPressed: () => _acao(pedido, 'cancelar'),
          child: const Text('Cancelar pedido')));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FotoAnuncio(
                  fotoUrl: pedido.anuncio.fotoUrl,
                  tipoMaterial: pedido.anuncio.tipoMaterial,
                  largura: 64,
                  altura: 64,
                  tamanhoIcone: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pedido.anuncio.titulo,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                          recebido
                              ? 'Pedido por ${pessoa.nome}'
                              : 'Anunciado por ${pessoa.nome}',
                          style: cinza),
                      Text(tempoAtras(pedido.atualizadoEm ?? pedido.criadoEm),
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                SeloStatus(statusPedido(pedido.status), pequeno: true),
              ],
            ),
            if ((pedido.finalidade ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 18, color: Cores.verde),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Destino: ${pedido.finalidade}')),
                ],
              ),
            ],
            const Divider(height: 20),
            // Wrap = se não couber numa linha (celular pequeno), quebra
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _abrirChat(pedido),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('Conversar (${pedido.totalMensagens})'),
                ),
                if (botoes.isNotEmpty)
                  Wrap(spacing: 6, children: botoes),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
