import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Widget SIMPLES para mostrar AR com modelos em coordenadas GPS
class SimpleGeospatialScreen extends StatefulWidget {
  const SimpleGeospatialScreen({Key? key}) : super(key: key);

  @override
  State<SimpleGeospatialScreen> createState() => _SimpleGeospatialScreenState();
}

class _SimpleGeospatialScreenState extends State<SimpleGeospatialScreen> {
  MethodChannel? _viewChannel;

  String _status = 'Inicializando...';
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _altitude = 0.0;
  double _horizontalAccuracy = 999.0;
  double _verticalAccuracy = 999.0;
  int _modelsPlaced = 0;
  bool _permissionsGranted = false;
  bool _modelsLoaded = false; // Modelos carregados do JSON
  bool _modelsRendered = false; // Modelos já renderizados na cena

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final locationStatus = await Permission.location.request();

    setState(() {
      _permissionsGranted = cameraStatus.isGranted && locationStatus.isGranted;
      if (!_permissionsGranted) {
        _status = 'Permissões negadas';
      }
    });

    if (!_permissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permissões de câmera e GPS são necessárias'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ARCore View (ocupa toda a tela)
          if (Platform.isAndroid && _permissionsGranted)
            AndroidView(
              viewType: 'simple_geospatial_view',
              onPlatformViewCreated: _onPlatformViewCreated,
            )
          else if (Platform.isAndroid && !_permissionsGranted)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 64, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'Aguardando permissões...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Câmera e GPS necessários',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Text(
                'iOS não suportado ainda',
                style: TextStyle(color: Colors.white),
              ),
            ),

          // Indicador de câmera ativa (já que AndroidView não mostra preview no Flutter)
          if (_permissionsGranted && _status != 'Inicializando...')
            Positioned(
              top: 50,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.videocam, color: Colors.white, size: 20),
              ),
            ),

          // Status overlay (canto superior esquerdo)
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VPS: $_status',
                    style: TextStyle(
                      color: _status == 'TRACKING'
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Lat: ${_latitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'Lon: ${_longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'Alt: ${_altitude.toStringAsFixed(1)}m',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Precisão: H:${_horizontalAccuracy.toStringAsFixed(1)}m V:${_verticalAccuracy.toStringAsFixed(1)}m',
                    style: TextStyle(
                      color: _horizontalAccuracy < 10
                          ? Colors.green
                          : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Modelos: $_modelsPlaced',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Botões inferiores
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botão para colocar modelos (só ativo quando VPS ready)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canPlaceModels() && !_modelsRendered
                        ? _placeModels
                        : null,
                    icon: Icon(
                      _modelsRendered
                          ? Icons.check_circle
                          : Icons.add_location_alt,
                    ),
                    label: Text(
                      _modelsRendered
                          ? 'Modelos Colocados!'
                          : _canPlaceModels()
                          ? 'Colocar Modelos (${_horizontalAccuracy.toStringAsFixed(1)}m)'
                          : _horizontalAccuracy < 999.0
                          ? 'Aguarde <10m (${_horizontalAccuracy.toStringAsFixed(1)}m)'
                          : 'Aguardando VPS...',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _modelsRendered
                          ? Colors.green
                          : Colors.blueAccent,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Botão para recarregar configuração
                FloatingActionButton(
                  onPressed: _loadModels,
                  child: Icon(Icons.refresh),
                  backgroundColor: Colors.orange,
                  mini: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    print('✅ SimpleGeospatialView criado com ID: $id');

    // Criar MethodChannel para este view específico
    _viewChannel = MethodChannel('simple_geospatial_view_$id');

    // Escutar callbacks do Kotlin
    _viewChannel!.setMethodCallHandler(_handleMethodCall);

    // Carregar modelos automaticamente
    Future.delayed(Duration(seconds: 1), () {
      _loadModels();
    });
  }

  Future<void> _loadModels() async {
    try {
      // Ler house_config.json
      final jsonString = await rootBundle.loadString(
        'assets/house_config.json',
      );
      final config = json.decode(jsonString);

      // Converter para array se for objeto único
      List<Map<String, dynamic>> modelsArray;
      if (config is List) {
        modelsArray = config.cast<Map<String, dynamic>>();
      } else if (config is Map) {
        modelsArray = [config.cast<String, dynamic>()];
      } else {
        throw Exception('Formato JSON inválido');
      }

      print('📦 Carregando ${modelsArray.length} modelo(s)...');

      // Enviar para Kotlin
      final result = await _viewChannel?.invokeMethod('loadModels', {
        'json': json.encode(modelsArray),
      });

      print('✅ Modelos carregados: $result');

      setState(() {
        _modelsLoaded = true;
        _modelsRendered = false; // Reset para permitir novo placement
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${modelsArray.length} modelo(s) carregado(s) - aguarde VPS <10m',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Erro ao carregar modelos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Verifica se pode colocar modelos: VPS TRACKING + accuracy <10m
  bool _canPlaceModels() {
    return _status == 'TRACKING' &&
        _horizontalAccuracy < 10.0 &&
        _modelsLoaded &&
        !_modelsRendered;
  }

  /// Coloca modelos 3D nas coordenadas GPS
  Future<void> _placeModels() async {
    try {
      print('🎯 Colocando modelos 3D...');

      final result = await _viewChannel?.invokeMethod('placeModels');

      print('✅ Modelos colocados: $result');

      setState(() {
        _modelsRendered = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Modelos 3D colocados nas coordenadas GPS!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Erro ao colocar modelos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVpsStatusChanged':
        setState(() {
          _status = call.arguments['status'] ?? 'UNKNOWN';
          _latitude = call.arguments['latitude'] ?? 0.0;
          _longitude = call.arguments['longitude'] ?? 0.0;
          _altitude = call.arguments['altitude'] ?? 0.0;
          _horizontalAccuracy = call.arguments['horizontalAccuracy'] ?? 999.0;
          _verticalAccuracy = call.arguments['verticalAccuracy'] ?? 999.0;
        });
        print('📡 VPS Status: $_status @ ($_latitude, $_longitude)');
        break;

      case 'onModelPlaced':
        setState(() {
          _modelsPlaced++;
        });
        final model = call.arguments['model'] ?? '';
        print('✅ Modelo colocado: $model');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Modelo colocado: $model'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        break;
    }
  }

  @override
  void dispose() {
    _viewChannel = null;
    super.dispose();
  }
}
