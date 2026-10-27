// =====================================================================
// formatar.dart
// Funções para mostrar números e datas do jeito brasileiro.
// =====================================================================

/// 30.0 -> "30"   |   2.5 -> "2,5"   |   1234.5 -> "1.234,5"
String formatarNumero(double? valor) {
  if (valor == null) return '0';
  final inteiro = valor == valor.roundToDouble();
  final texto = inteiro ? valor.toInt().toString() : valor.toStringAsFixed(1);
  final partes = texto.split('.');
  // coloca ponto a cada 3 dígitos: 1234 -> 1.234
  final milhar = partes[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return partes.length > 1 ? '$milhar,${partes[1]}' : milhar;
}

/// 2.5 -> "2,5 kg"
String formatarKg(double? valor) => '${formatarNumero(valor)} kg';

/// 0.35 -> "350 m"   |   2.4 -> "2,4 km"
String formatarDistancia(double? km) {
  if (km == null) return '';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${formatarNumero(double.parse(km.toStringAsFixed(1)))} km';
}

/// "há 5 min", "há 2 h", "há 3 dias" ou a data "12/10".
String tempoAtras(DateTime? data) {
  if (data == null) return '';
  final diferenca = DateTime.now().difference(data);
  if (diferenca.inMinutes < 1) return 'agora';
  if (diferenca.inMinutes < 60) return 'há ${diferenca.inMinutes} min';
  if (diferenca.inHours < 24) return 'há ${diferenca.inHours} h';
  if (diferenca.inDays == 1) return 'ontem';
  if (diferenca.inDays < 7) return 'há ${diferenca.inDays} dias';
  return formatarData(data);
}

/// 05/10
String formatarData(DateTime data) =>
    '${_dois(data.day)}/${_dois(data.month)}';

/// 14:05
String formatarHora(DateTime? data) =>
    data == null ? '' : '${_dois(data.hour)}:${_dois(data.minute)}';

String _dois(int n) => n.toString().padLeft(2, '0');

/// Converte texto digitado ("2,5") em número (2.5).
double? lerNumero(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));
