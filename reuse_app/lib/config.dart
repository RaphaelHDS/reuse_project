// =====================================================================
// config.dart
// Endereço padrão da API. Você NÃO precisa mudar nada aqui: dá para
// trocar o endereço pelo próprio app (tela de login > "Servidor").
// =====================================================================

import 'package:flutter/foundation.dart';

class Config {
  /// Endereço usado na primeira vez que o app abre.
  static String urlPadrao() {
    // No Chrome, a API está no mesmo computador
    if (kIsWeb) return 'http://localhost:8080';

    // No emulador Android, o "computador" é o endereço 10.0.2.2.
    // No celular de verdade, troque pelo IP mostrado no terminal da API.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// Contas de teste criadas pelo reuse_banco.sql (aparecem no login).
  static const contasDeTeste = {
    'Ana (artesã)': 'ana@reuse.com',
    'Marcenaria': 'marcenaria@reuse.com',
    'Escola': 'escola@reuse.com',
  };
  static const senhaDeTeste = '123456';
}
