/// Configuração de um modelo 3D de casa com localização GPS
class HouseModelConfig {
  /// URL ou caminho do arquivo glTF/GLB
  final String modelUri;

  /// Tipo: 'webGLB', 'localGLTF2', etc.
  final String nodeType;

  /// Coordenadas GPS [latitude, longitude]
  /// Exemplo: [38.7223, -9.1393] para Lisboa
  final List<double>? gpsCoordinates;

  /// Escala do modelo (padrão: 1.0)
  final double scale;

  /// Rotação em graus (0-360)
  final double rotationDegrees;

  /// Altitude em metros relativa ao chão
  final double altitude;

  /// Nome/descrição do modelo
  final String name;

  const HouseModelConfig({
    required this.modelUri,
    required this.nodeType,
    this.gpsCoordinates,
    this.scale = 1.0,
    this.rotationDegrees = 0.0,
    this.altitude = 0.0,
    this.name = 'Casa',
  });

  /// Factory para criar configuração a partir de JSON
  /// Útil para carregar de arquivo ou API
  factory HouseModelConfig.fromJson(Map<String, dynamic> json) {
    return HouseModelConfig(
      modelUri: json['modelUri'] as String,
      nodeType: json['nodeType'] as String? ?? 'webGLB',
      gpsCoordinates: json['gpsCoordinates'] != null
          ? List<double>.from(json['gpsCoordinates'] as List)
          : null,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      name: json['name'] as String? ?? 'Casa',
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'modelUri': modelUri,
      'nodeType': nodeType,
      'gpsCoordinates': gpsCoordinates,
      'scale': scale,
      'rotationDegrees': rotationDegrees,
      'altitude': altitude,
      'name': name,
    };
  }

  /// Exemplo de configuração
  static const example = HouseModelConfig(
    modelUri:
        'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Binary/Duck.glb',
    nodeType: 'webGLB',
    gpsCoordinates: [38.7223, -9.1393], // Lisboa
    scale: 0.2,
    rotationDegrees: 45.0,
    altitude: 0.0,
    name: 'Casa Exemplo',
  );
}
