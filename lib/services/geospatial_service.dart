import 'package:flutter/services.dart';

/// Serviço para comunicação com ARCore Geospatial API (Android nativo)
///
/// Este serviço usa MethodChannel para chamar código Kotlin que:
/// 1. Inicializa ARCore Session com Geospatial Mode
/// 2. Verifica disponibilidade VPS na localização atual
/// 3. Cria Earth Anchors em coordenadas GPS (lat/lon/alt)
/// 4. Retorna pose (position + rotation) do anchor para Flutter
class GeospatialService {
  static const MethodChannel _channel = MethodChannel('com.housear/geospatial');

  /// Inicializa ARCore Geospatial Session
  ///
  /// Retorna true se:
  /// - Dispositivo suporta ARCore
  /// - Google Play Services está atualizado
  /// - Geospatial API está disponível
  ///
  /// **Importante**: Requer Google Maps API Key configurada no AndroidManifest.xml
  static Future<bool> initializeGeospatial() async {
    try {
      final result = await _channel.invokeMethod<bool>('initializeGeospatial');
      return result ?? false;
    } catch (e) {
      print('❌ Erro ao inicializar Geospatial: $e');
      return false;
    }
  }

  /// Verifica disponibilidade de VPS (Visual Positioning System) na localização atual
  ///
  /// VPS é necessário para alta precisão geoespacial.
  /// Nem todas as localizações têm cobertura VPS.
  ///
  /// Retorna mapa com:
  /// - 'available': bool (VPS disponível?)
  /// - 'latitude': double (lat atual do dispositivo)
  /// - 'longitude': double (lon atual do dispositivo)
  /// - 'altitude': double (alt atual do dispositivo)
  /// - 'accuracy': double (precisão horizontal em metros)
  static Future<Map<String, dynamic>> checkVPSAvailability() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'checkVPSAvailability',
      );
      if (result == null) {
        return {
          'available': false,
          'latitude': 0.0,
          'longitude': 0.0,
          'altitude': 0.0,
          'accuracy': 999.0,
        };
      }

      return {
        'available': result['available'] as bool? ?? false,
        'latitude': result['latitude'] as double? ?? 0.0,
        'longitude': result['longitude'] as double? ?? 0.0,
        'altitude': result['altitude'] as double? ?? 0.0,
        'accuracy': result['accuracy'] as double? ?? 999.0,
      };
    } catch (e) {
      print('❌ Erro ao verificar VPS: $e');
      return {
        'available': false,
        'latitude': 0.0,
        'longitude': 0.0,
        'altitude': 0.0,
        'accuracy': 999.0,
      };
    }
  }

  /// Cria Earth Anchor em coordenadas GPS
  ///
  /// Parâmetros:
  /// - latitude: Latitude em graus decimais
  /// - longitude: Longitude em graus decimais
  /// - altitude: Altitude em metros (WGS84)
  /// - rotationDegrees: Rotação em graus (0-360, eixo Y)
  ///
  /// Retorna mapa com:
  /// - 'success': bool (anchor criado?)
  /// - 'anchorId': String (ID do anchor no ARCore)
  /// - 'positionX': double (posição X local em metros)
  /// - 'positionY': double (posição Y local em metros)
  /// - 'positionZ': double (posição Z local em metros)
  /// - 'rotationX': double (quaternion X)
  /// - 'rotationY': double (quaternion Y)
  /// - 'rotationZ': double (quaternion Z)
  /// - 'rotationW': double (quaternion W)
  ///
  /// **Nota**: Posição é relativa à origem local da ARCore Session.
  /// ARCore Geospatial converte GPS->local automaticamente.
  static Future<Map<String, dynamic>> createEarthAnchor({
    required double latitude,
    required double longitude,
    required double altitude,
    double rotationDegrees = 0.0,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Map<Object?, Object?>>('createEarthAnchor', {
            'latitude': latitude,
            'longitude': longitude,
            'altitude': altitude,
            'rotationDegrees': rotationDegrees,
          });

      if (result == null) {
        return {'success': false};
      }

      return {
        'success': result['success'] as bool? ?? false,
        'anchorId': result['anchorId'] as String? ?? '',
        'positionX': result['positionX'] as double? ?? 0.0,
        'positionY': result['positionY'] as double? ?? 0.0,
        'positionZ': result['positionZ'] as double? ?? 0.0,
        'rotationX': result['rotationX'] as double? ?? 0.0,
        'rotationY': result['rotationY'] as double? ?? 0.0,
        'rotationZ': result['rotationZ'] as double? ?? 0.0,
        'rotationW': result['rotationW'] as double? ?? 1.0,
      };
    } catch (e) {
      print('❌ Erro ao criar Earth Anchor: $e');
      return {'success': false};
    }
  }

  /// Remove anchor existente
  static Future<bool> removeEarthAnchor(String anchorId) async {
    try {
      final result = await _channel.invokeMethod<bool>('removeEarthAnchor', {
        'anchorId': anchorId,
      });
      return result ?? false;
    } catch (e) {
      print('❌ Erro ao remover Earth Anchor: $e');
      return false;
    }
  }

  /// Atualiza pose de anchor existente (útil para animações ou correções)
  static Future<Map<String, dynamic>> getAnchorPose(String anchorId) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getAnchorPose',
        {'anchorId': anchorId},
      );

      if (result == null) {
        return {'success': false};
      }

      return {
        'success': result['success'] as bool? ?? false,
        'positionX': result['positionX'] as double? ?? 0.0,
        'positionY': result['positionY'] as double? ?? 0.0,
        'positionZ': result['positionZ'] as double? ?? 0.0,
        'rotationX': result['rotationX'] as double? ?? 0.0,
        'rotationY': result['rotationY'] as double? ?? 0.0,
        'rotationZ': result['rotationZ'] as double? ?? 0.0,
        'rotationW': result['rotationW'] as double? ?? 1.0,
      };
    } catch (e) {
      print('❌ Erro ao obter pose do anchor: $e');
      return {'success': false};
    }
  }
}
