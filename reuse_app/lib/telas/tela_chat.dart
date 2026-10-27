// =====================================================================
// tela_chat.dart
// Chat interno entre quem anunciou e quem pediu o material.
// As mensagens são atualizadas a cada 5 segundos.
// =====================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../modelos/outros_modelos.dart';
import '../modelos/solicitacao.dart';
import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../servicos/whatsapp.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/comuns.dart';

class TelaChat extends StatefulWidget {
  final int solicitacaoId;
  const TelaChat({super.key, required this.solicitacaoId});

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> {
  Solicitacao? _pedido;
  List<Mensagem> _mensagens = [];
  Object? _erro;
  final _texto = TextEditingController();
  final _rolagem = ScrollController();
  Timer? _relogio;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
    // Busca mensagens novas a cada 5 segundos
    _relogio = Timer.periodic(
        const Duration(seconds: 5), (_) => _carregarMensagens());
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _texto.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregarTudo() async {
    try {
      final pedido = await Api.buscarSolicitacao(widget.solicitacaoId);
      if (mounted) setState(() => _pedido = pedido);
      await _carregarMensagens();
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    }
  }

  Future<void> _carregarMensagens() async {
    try {
      final lista = await Api.listarMensagens(widget.solicitacaoId);
      if (!mounted) return;
      final chegouNova = lista.length != _mensagens.length;
      setState(() => _mensagens = lista);
      if (chegouNova) _rolarParaOFim();
    } catch (_) {
      // sem conexão: tenta de novo na próxima volta do relógio
    }
  }

  void _rolarParaOFim() {
    // Espera a lista ser desenhada e então rola até a última mensagem
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rolagem.hasClients) {
        _rolagem.animateTo(
          _rolagem.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      await Api.enviarMensagem(widget.solicitacaoId, texto);
      _texto.clear();
      await _carregarMensagens();
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _pedido;
    final outra = pedido?.outraParte(Sessao.meuId);
    final telefone = outra?.telefone ?? '';

    return Scaffold(
      appBar: AppBar(
        title: pedido == null
            ? const Text('Conversa')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(outra!.nome, style: const TextStyle(fontSize: 17)),
                  Text(pedido.anuncio.titulo,
                      style:
                          TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                ],
              ),
        actions: [
          if (telefone.isNotEmpty)
            IconButton(
              tooltip: 'Abrir no WhatsApp',
              icon: const Icon(Icons.chat, color: Cores.verde),
              onPressed: () => abrirWhatsApp(telefone,
                  'Olá! Sobre o material "${pedido!.anuncio.titulo}" do ReUse...'),
            ),
        ],
      ),
      body: _erro != null
          ? ErroCarregamento(erro: _erro!, aoTentarDeNovo: _carregarTudo)
          : pedido == null
              ? const Center(child: CircularProgressIndicator())
              : LarguraMaxima(
                  child: Column(
                    children: [
                      // Faixa com a situação do pedido
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        color: Colors.white,
                        child: Row(
                          children: [
                            SeloStatus(statusPedido(pedido.status), pequeno: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (pedido.finalidade ?? '').isEmpty
                                    ? ''
                                    : 'Destino: ${pedido.finalidade}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: _listaMensagens()),
                      _campoMensagem(),
                    ],
                  ),
                ),
    );
  }

  Widget _listaMensagens() {
    if (_mensagens.isEmpty) {
      return const EstadoVazio(
        icone: Icons.forum_outlined,
        titulo: 'Nenhuma mensagem ainda',
        texto: 'Combine aqui o dia e o horário da retirada.',
      );
    }
    return ListView.builder(
      controller: _rolagem,
      padding: const EdgeInsets.all(12),
      itemCount: _mensagens.length,
      itemBuilder: (context, i) {
        final m = _mensagens[i];
        final minha = m.remetenteId == Sessao.meuId;
        return Align(
          alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.75),
            decoration: BoxDecoration(
              color: minha ? Cores.verde : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(minha ? 16 : 4),
                bottomRight: Radius.circular(minha ? 4 : 16),
              ),
              border: minha ? null : Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment:
                  minha ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(m.texto,
                    style: TextStyle(
                        color: minha ? Colors.white : Colors.black87,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(formatarHora(m.criadoEm),
                    style: TextStyle(
                        fontSize: 11,
                        color: minha ? Colors.white70 : Colors.grey.shade500)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _campoMensagem() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _texto,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviar(),
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escreva uma mensagem...',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _enviando ? null : _enviar,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
