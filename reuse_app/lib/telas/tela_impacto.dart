// =====================================================================
// tela_impacto.dart
// Painel de impacto: quantos kg de resíduos a plataforma e o usuário
// já evitaram, e quais materiais foram mais reaproveitados.
// (Conta o peso dos anúncios com status "Retirado".)
// =====================================================================

import 'package:flutter/material.dart';

import '../modelos/outros_modelos.dart';
import '../servicos/api.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/comuns.dart';

class TelaImpacto extends StatefulWidget {
  const TelaImpacto({super.key});

  @override
  State<TelaImpacto> createState() => _TelaImpactoState();
}

class _TelaImpactoState extends State<TelaImpacto> {
  Impacto? _impacto;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final impacto = await Api.impacto();
      if (mounted) setState(() => _impacto = impacto);
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel de impacto')),
      body: _erro != null
          ? ErroCarregamento(erro: _erro!, aoTentarDeNovo: _carregar)
          : _impacto == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: LarguraMaxima(child: _conteudo(_impacto!)),
                ),
    );
  }

  Widget _conteudo(Impacto impacto) {
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Destaque: total da plataforma ----
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Cores.verde, Cores.verdeEscuro],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.eco, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Toda a comunidade ReUse',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 10),
              Text(formatarKg(impacto.kgEvitados),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800)),
              const Text('de resíduos que deixaram de virar lixo',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _mini(Icons.task_alt, '${impacto.materiaisRetirados} materiais reaproveitados'),
                  _mini(Icons.inventory_2, '${impacto.anunciosDisponiveis} disponíveis agora'),
                  _mini(Icons.groups, '${impacto.usuarios} participantes'),
                ],
              ),
            ],
          ),
        ),

        // ---- Meu impacto ----
        const SizedBox(height: 20),
        Text('Seu impacto', style: titulo),
        const SizedBox(height: 8),
        Row(
          children: [
            _cartaoNumero('Você doou', formatarKg(impacto.kgDoados),
                '${impacto.doacoes} doação(ões)', Icons.upload, Cores.verde),
            const SizedBox(width: 10),
            _cartaoNumero('Você reaproveitou', formatarKg(impacto.kgRecebidos),
                '${impacto.recebimentos} retirada(s)', Icons.download, Cores.azul),
          ],
        ),

        // ---- Por tipo de material (barras) ----
        const SizedBox(height: 20),
        Text('Reaproveitado por tipo de material', style: titulo),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: impacto.porTipo.isEmpty
                ? const Text('Ainda não há retiradas concluídas.')
                : Column(children: _barras(impacto.porTipo)),
          ),
        ),

        // ---- ODS 12 ----
        const SizedBox(height: 20),
        Card(
          color: Cores.verdeClaro,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBF8B2E), // cor oficial do ODS 12
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('ODS\n12',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Consumo e produção responsáveis.\n'
                    'Meta 12.5: reduzir substancialmente a geração de resíduos '
                    'por meio da prevenção, redução, reciclagem e reuso. '
                    'Cada material retirado pelo ReUse ajuda nessa meta!',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _mini(IconData icone, String texto) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(color: Colors.white)),
        ],
      );

  Widget _cartaoNumero(
      String rotulo, String valor, String detalhe, IconData icone, Color cor) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: cor),
              const SizedBox(height: 6),
              Text(rotulo, style: TextStyle(color: Colors.grey.shade700)),
              Text(valor,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: cor)),
              Text(detalhe,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  /// Uma barra horizontal para cada material (maior = mais kg).
  List<Widget> _barras(List<ImpactoPorTipo> porTipo) {
    final maior = porTipo.map((t) => t.kg).fold<double>(0, (a, b) => a > b ? a : b);
    return [
      for (final item in porTipo)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(tipoPorNome(item.tipo).icone,
                  color: tipoPorNome(item.tipo).cor, size: 20),
              const SizedBox(width: 8),
              SizedBox(width: 110, child: Text(item.tipo)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maior == 0 ? 0 : item.kg / maior,
                    minHeight: 14,
                    color: tipoPorNome(item.tipo).cor,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: Text(formatarKg(item.kg),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
    ];
  }
}
