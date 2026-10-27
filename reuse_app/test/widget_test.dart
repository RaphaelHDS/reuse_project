// Testes automáticos simples. Para rodar: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuse_app/ia/assistente_ia.dart';

void main() {
  test('A base da IA tem ideias para todos os tipos de material', () {
    for (final tipo in AssistenteIA.base.keys) {
      final info = AssistenteIA.infoDoTipo(tipo);
      expect(info.reutilizacoes, isNotEmpty);
      expect(info.destinatarios, isNotEmpty);
    }
  });

  test('Estimativa de peso usa a quantidade e a unidade', () {
    expect(AssistenteIA.estimarPeso('Madeira', 10, 'kg'), 10);
    expect(AssistenteIA.estimarPeso('Plástico', 100, 'unidades'), greaterThan(0));
  });
}
