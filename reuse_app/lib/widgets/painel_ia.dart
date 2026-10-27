// =====================================================================
// painel_ia.dart
// Mostra o resultado da IA (janela que sobe de baixo da tela) e o
// cartão de "Ideias de reutilização" usado no detalhe do anúncio.
// =====================================================================

import 'package:flutter/material.dart';

import '../ia/assistente_ia.dart';
import '../tema.dart';

/// Abre o resultado da análise. Devolve o tipo escolhido pelo usuário
/// (a sugestão ou uma alternativa), ou null se ele fechar a janela.
Future<String?> mostrarResultadoIA(BuildContext context, ResultadoIA resultado) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final tipo = tipoPorNome(resultado.tipo);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, rolagem) => ListView(
          controller: rolagem,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Cores.verde),
                const SizedBox(width: 8),
                Text('Análise da IA',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),

            // Material identificado + confiança
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tipo.cor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: tipo.cor,
                    child: Icon(tipo.icone, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Material identificado'),
                        Text(tipo.nome,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: resultado.confianca / 100,
                            minHeight: 8,
                            color: tipo.cor,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Confiança: ${resultado.confianca}%'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (resultado.alternativas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Não é isso? Toque em outra opção:'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final alternativa in resultado.alternativas)
                    ActionChip(
                      avatar: Icon(tipoPorNome(alternativa).icone, size: 18),
                      label: Text(alternativa),
                      onPressed: () => Navigator.pop(context, alternativa),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 8),
            IdeiasReutilizacao(info: resultado.info),

            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, resultado.tipo),
              icon: const Icon(Icons.check),
              label: const Text('Usar esta sugestão'),
            ),
            const SizedBox(height: 10),
            Text(
              'IA simulada (protótipo): analisa as cores da foto, sem internet. '
              'Confira o tipo de material antes de publicar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    },
  );
}

/// Cartão com ideias de reutilização e possíveis interessados.
class IdeiasReutilizacao extends StatelessWidget {
  final ConhecimentoMaterial info;
  const IdeiasReutilizacao({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    Widget lista(IconData icone, List<String> itens) => Column(
          children: [
            for (final item in itens)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icone, size: 18, color: Cores.verde),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        );

    final titulo = Theme.of(context)
        .textTheme
        .titleSmall
        ?.copyWith(fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Ideias de reutilização', style: titulo),
        const SizedBox(height: 4),
        lista(Icons.lightbulb_outline, info.reutilizacoes),
        const SizedBox(height: 12),
        Text('Quem pode se interessar', style: titulo),
        const SizedBox(height: 4),
        lista(Icons.groups_outlined, info.destinatarios),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Cores.verdeClaro,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tips_and_updates, color: Cores.verde, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Dica: ${info.dica}')),
            ],
          ),
        ),
      ],
    );
  }
}
