// =====================================================================
// localizacao.dart
// Pega a localização do aparelho (GPS no celular, ou a do navegador).
// Se o usuário não deixar, o app continua funcionando sem distância.
// =====================================================================

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class Localizacao {
  /// Centro de Mogi das Cruzes (usado quando não temos a localização).
  static const padrao = LatLng(-23.5225, -46.1880);

  /// Última localização encontrada (fica guardada para as outras telas).
  static LatLng? ultima;

  /// Tenta descobrir onde o aparelho está. Devolve null se não conseguir.
  static Future<LatLng?> obter() async {
    try {
      // 1) O GPS / localização está ligado?
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      // 2) O usuário deu permissão? Se não, pede.
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        return null;
      }

      // 3) Pega a posição atual (espera no máximo 15 segundos)
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      ultima = LatLng(posicao.latitude, posicao.longitude);
      return ultima;
    } catch (_) {
      return null;
    }
  }
}
