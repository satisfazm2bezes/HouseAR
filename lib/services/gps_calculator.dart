import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:geolocator/geolocator.dart';

/// Calcula posição local AR baseada em GPS sem VPS
/// Usa projeção plana simples para distâncias curtas (<1km)
class GPSCalculator {
  /// Raio da Terra em metros
  static const double earthRadius = 6371000.0;

  /// Converte coordenadas GPS (lat/lon/alt) para posição local XYZ
  /// relativa à posição atual do device
  ///
  /// Returns: Vector3(x, y, z) onde:
  /// - x: Este-Oeste (positivo = Este)
  /// - y: Altitude
  /// - z: Norte-Sul (negativo = Norte, pois ARCore usa Z negativo para frente)
  static Future<vector.Vector3> gpsToLocalPosition({
    required double targetLat,
    required double targetLon,
    required double targetAlt,
  }) async {
    // Obter posição atual do device
    final currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    return gpsToLocalPositionFrom(
      currentLat: currentPosition.latitude,
      currentLon: currentPosition.longitude,
      currentAlt: currentPosition.altitude,
      targetLat: targetLat,
      targetLon: targetLon,
      targetAlt: targetAlt,
    );
  }

  /// Converte GPS para posição local a partir de uma posição de referência
  static vector.Vector3 gpsToLocalPositionFrom({
    required double currentLat,
    required double currentLon,
    required double currentAlt,
    required double targetLat,
    required double targetLon,
    required double targetAlt,
  }) {
    // Diferenças em radianos
    final dLat = _toRadians(targetLat - currentLat);
    final dLon = _toRadians(targetLon - currentLon);

    // Latitude média para correção de longitude
    final avgLat = _toRadians((currentLat + targetLat) / 2);

    // Calcular distâncias em metros (projeção plana)
    // Para distâncias < 1km, isto é suficientemente preciso
    final deltaX = dLon * earthRadius * cos(avgLat); // Este-Oeste
    final deltaZ =
        -dLat *
        earthRadius; // Norte-Sul (negativo porque ARCore usa -Z como frente)
    final deltaY = targetAlt - currentAlt; // Altitude

    debugPrint(
      '🧭 [GPS] Posição atual: $currentLat, $currentLon, ${currentAlt}m',
    );
    debugPrint('🎯 [GPS] Alvo: $targetLat, $targetLon, ${targetAlt}m');
    debugPrint(
      '📏 [GPS] Delta: X=${deltaX.toStringAsFixed(1)}m, Y=${deltaY.toStringAsFixed(1)}m, Z=${deltaZ.toStringAsFixed(1)}m',
    );
    debugPrint(
      '📐 [GPS] Distância horizontal: ${sqrt(deltaX * deltaX + deltaZ * deltaZ).toStringAsFixed(1)}m',
    );

    return vector.Vector3(deltaX, deltaY, deltaZ);
  }

  /// Calcula distância entre dois pontos GPS (fórmula de Haversine)
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calcula bearing (direção em graus) de lat1/lon1 para lat2/lon2
  static double calculateBearing({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final y = sin(dLon) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x);
    return (_toDegrees(bearing) + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;
  static double _toDegrees(double radians) => radians * 180.0 / pi;
}
