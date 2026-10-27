// =====================================================================
// whatsapp.dart
// Abre uma conversa no WhatsApp com mensagem pronta.
// Usa o link oficial https://wa.me/55NUMERO?text=MENSAGEM
// =====================================================================

import 'package:url_launcher/url_launcher.dart';

/// Devolve true se conseguiu abrir o WhatsApp (ou o site dele).
Future<bool> abrirWhatsApp(String telefone, String mensagem) async {
  var numero = telefone.replaceAll(RegExp(r'[^0-9]'), '');
  if (numero.isEmpty) return false;

  // Número brasileiro sem o código do país (DDD + número) -> coloca 55
  if (numero.length == 10 || numero.length == 11) numero = '55$numero';

  final link = Uri.parse(
      'https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}');
  try {
    return await launchUrl(link, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
