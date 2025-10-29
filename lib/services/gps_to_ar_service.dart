import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector;

/// Serviço para converter coordenadas GPS em posições AR
class GpsToArService {
  /// Raio da Terra em metros
  static const double earthRadius = 6371000.0;

  /// Calcula a distância entre duas coordenadas GPS (em metros)
  /// usando a fórmula de Haversine
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Calcula o bearing (direção) de um ponto para outro (em graus)
  /// 0° = Norte, 90° = Leste, 180° = Sul, 270° = Oeste
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    final bearingRad = math.atan2(y, x);
    final bearingDeg = _toDegrees(bearingRad);

    return (bearingDeg + 360) % 360; // Normalizar para 0-360
  }

  /// Converte coordenadas GPS para posição AR relativa COM CORREÇÃO DE BÚSSOLA
  ///
  /// [userLat] Latitude do usuário
  /// [userLon] Longitude do usuário
  /// [userAltitude] Altitude do usuário em relação ao nível do mar (metros)
  /// [deviceHeading] Direção da BÚSSOLA do dispositivo (0-360, 0=Norte)
  /// [targetLat] Latitude do alvo (casa)
  /// [targetLon] Longitude do alvo
  /// [targetAltitude] Altitude do modelo em relação ao nível do mar (metros)
  ///
  /// Retorna Vector3 com posição relativa em metros (x, y, z)
  /// CORRIGIDO pela orientação real do dispositivo via bússola
  static vector.Vector3 gpsToArPosition(
    double userLat,
    double userLon,
    double userAltitude,
    double deviceHeading,
    double targetLat,
    double targetLon,
    double targetAltitude,
  ) {
    // 1. Calcular bearing geográfico (direção do Norte para o alvo)
    final targetBearing = calculateBearing(
      userLat,
      userLon,
      targetLat,
      targetLon,
    );

    // 2. Calcular distância horizontal
    final distance = calculateDistance(userLat, userLon, targetLat, targetLon);

    // 3. Calcular bearing RELATIVO à orientação atual do dispositivo
    // Se dispositivo aponta para 45° e alvo está a 90°, bearing relativo = 45°
    final relativeBearing = (targetBearing - deviceHeading + 360) % 360;
    final relativeBearingRad = _toRadians(relativeBearing);

    // 4. Converter para coordenadas cartesianas AR
    // No ARCore: X = direita, Y = cima, Z = para trás (câmera olha para -Z)
    final x = distance * math.sin(relativeBearingRad);
    final z =
        -distance *
        math.cos(relativeBearingRad); // -Z porque ARCore olha para -Z

    // 5. Diferença de altitude real (nível do mar)
    final y = targetAltitude - userAltitude;

    return vector.Vector3(x, y, z);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
  static double _toDegrees(double radians) => radians * 180.0 / math.pi;
}
