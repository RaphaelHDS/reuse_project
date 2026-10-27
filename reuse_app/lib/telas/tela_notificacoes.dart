// =====================================================================
// tela_notificacoes.dart
// Avisos do sininho: novas solicitações, pedido aceito, retirada
// concluída etc. Ao abrir esta tela, os avisos são marcados como lidos.
// =====================================================================

import 'package:flutter/material.dart';

import '../modelos/outros_modelos.dart';
import '../servicos/api.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/comuns.dart';

class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  List<Notificacao>? _itens;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final resultado = await Api.notificacoes();
      if (mounted) setState(() => _itens = resultado.itens);
      // Marca como lidas (o sininho zera)
      if (resultado.naoLidas > 0) await Api.marcarNotificacoesLidas();
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    }
  }

  /// Escolhe um ícone conforme o título do aviso.
  IconData _icone(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('solicitação')) return Icons.volunteer_activism;
    if (t.contains('aceito')) return Icons.thumb_up;
    if (t.contains('concluída')) return Icons.task_alt;
    if (t.contains('recusado') || t.contains('cancel')) return Icons.block;
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (_erro != null) {
      corpo = ErroCarregamento(erro: _erro!, aoTentarDeNovo: _carregar);
    } else if (_itens == null) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_itens!.isEmpty) {
      corpo = const EstadoVazio(
          icone: Icons.notifications_none, titulo: 'Nenhum aviso por enquanto');
    } else {
      corpo = RefreshIndicator(
        onRefresh: _carregar,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _itens!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final n = _itens![i];
            return Card(
              color: n.lida ? Colors.white : Cores.verdeClaro,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(_icone(n.titulo), color: Cores.verde),
                ),
                title: Text(n.titulo,
                    style: TextStyle(
                        fontWeight: n.lida ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(n.texto),
                trailing: Text(tempoAtras(n.criadoEm),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: LarguraMaxima(child: corpo),
    );
  }
}
