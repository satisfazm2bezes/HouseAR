import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controller para ArGeospatialCameraView
class ArGeospatialController {
  MethodChannel? _channel;

  void _setChannel(MethodChannel channel) {
    _channel = channel;
  }

  /// Coloca modelo 3D em coordenadas GPS
  Future<void> placeModel(double lat, double lon, double alt) async {
    await _channel?.invokeMethod('placeModel', {
      'latitude': lat,
      'longitude': lon,
      'altitude': alt,
    });
  }

  /// Obtém status do VPS
  Future<Map<String, dynamic>?> getVPSStatus() async {
    final result = await _channel?.invokeMethod('getVPSStatus');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  /// Obtém informações de câmera selecionada
  Future<Map<String, dynamic>?> getCameraInfo() async {
    final result = await _channel?.invokeMethod('getCameraInfo');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  /// Seleciona câmera por índice (0, 1, 2...)
  Future<void> selectCamera(int index) async {
    await _channel?.invokeMethod('selectCamera', {'index': index});
  }
}

/// Widget que mostra preview da câmera AR com Geospatial
class ArGeospatialCameraView extends StatefulWidget {
  final ArGeospatialController? controller;

  /// Use a key to force recreate the underlying platform view when needed
  const ArGeospatialCameraView({super.key, this.controller});

  @override
  State<ArGeospatialCameraView> createState() => _ArGeospatialCameraViewState();
}

class _ArGeospatialCameraViewState extends State<ArGeospatialCameraView> {
  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'ar_geospatial_view',
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('house_ar/geospatial_view_$viewId');
    widget.controller?._setChannel(channel);
  }
}
