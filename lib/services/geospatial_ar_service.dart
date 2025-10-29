import 'package:flutter/services.dart';

/// Serviço Flutter para ARCore Geospatial API nativo
///
/// Permite colocar modelos 3D em coordenadas GPS exatas com precisão VPS (1-5m).
///
/// REUTILIZÁVEL: Pode ser facilmente portado para outros projetos Flutter.
class GeospatialARService {
  static const MethodChannel _channel = MethodChannel('house_ar/geospatial');

  /// Inicializa ARCore Geospatial API
  ///
  /// Retorna posição GPS atual quando VPS estiver pronto
  static Future<Map<String, dynamic>> initialize() async {
    try {
      final result = await _channel.invokeMethod('initialize');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw GeospatialException(e.code, e.message ?? 'Unknown error');
    }
  }

  /// Adiciona objeto 3D em coordenadas GPS específicas
  ///
  /// - [id]: Identificador único do objeto
  /// - [latitude]: Latitude GPS
  /// - [longitude]: Longitude GPS
  /// - [altitude]: Altitude em metros
  /// - [modelUri]: Caminho do modelo (assets/... ou http://...)
  /// - [rotation]: Rotação em graus (0-360)
  /// - [scale]: Escala do modelo (1.0 = tamanho original)
  static Future<Map<String, dynamic>> addObject({
    required String id,
    required double latitude,
    required double longitude,
    required double altitude,
    required String modelUri,
    double rotation = 0.0,
    double scale = 1.0,
  }) async {
    try {
      final result = await _channel.invokeMethod('addObject', {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'modelUri': modelUri,
        'rotation': rotation,
        'scale': scale,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw GeospatialException(e.code, e.message ?? 'Unknown error');
    }
  }

  /// Remove objeto por ID
  static Future<void> removeObject(String id) async {
    try {
      await _channel.invokeMethod('removeObject', {'id': id});
    } on PlatformException catch (e) {
      throw GeospatialException(e.code, e.message ?? 'Unknown error');
    }
  }

  /// Obtém status atual do VPS/Geospatial
  ///
  /// Retorna:
  /// - available: VPS está ativo?
  /// - trackingState: Estado do tracking
  /// - latitude/longitude/altitude: Posição atual
  /// - horizontalAccuracy: Precisão horizontal em metros
  /// - objectCount: Número de objetos ativos
  static Future<GeospatialStatus> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      return GeospatialStatus.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw GeospatialException(e.code, e.message ?? 'Unknown error');
    }
  }

  /// Limpa recursos
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {
      // Ignore dispose errors
    }
  }
}

/// Status do sistema Geospatial
class GeospatialStatus {
  final bool available;
  final String trackingState;
  final String earthState;
  final double latitude;
  final double longitude;
  final double altitude;
  final double horizontalAccuracy;
  final double verticalAccuracy;
  final double heading;
  final double headingAccuracy;
  final int objectCount;

  GeospatialStatus({
    required this.available,
    required this.trackingState,
    required this.earthState,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.horizontalAccuracy,
    required this.verticalAccuracy,
    required this.heading,
    required this.headingAccuracy,
    required this.objectCount,
  });

  factory GeospatialStatus.fromMap(Map<String, dynamic> map) {
    return GeospatialStatus(
      available: map['available'] ?? false,
      trackingState: map['trackingState'] ?? 'UNKNOWN',
      earthState: map['earthState'] ?? 'UNKNOWN',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      altitude: (map['altitude'] ?? 0.0).toDouble(),
      horizontalAccuracy: (map['horizontalAccuracy'] ?? 999.0).toDouble(),
      verticalAccuracy: (map['verticalAccuracy'] ?? 999.0).toDouble(),
      heading: (map['heading'] ?? 0.0).toDouble(),
      headingAccuracy: (map['headingAccuracy'] ?? 999.0).toDouble(),
      objectCount: map['objectCount'] ?? 0,
    );
  }

  /// VPS está pronto para uso?
  bool get isReady => available && trackingState == 'TRACKING';

  /// Precisão é boa? (<5m = VPS ativo, >10m = GPS apenas)
  bool get hasVPSPrecision => horizontalAccuracy < 5.0;

  @override
  String toString() {
    return 'GeospatialStatus(available: $available, tracking: $trackingState, '
        'pos: $latitude,$longitude,${altitude}m, accuracy: ${horizontalAccuracy}m, '
        'objects: $objectCount)';
  }
}

/// Exceção do sistema Geospatial
class GeospatialException implements Exception {
  final String code;
  final String message;

  GeospatialException(this.code, this.message);

  @override
  String toString() => 'GeospatialException[$code]: $message';
}
