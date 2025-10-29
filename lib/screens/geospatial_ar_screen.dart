import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/house_model_config.dart';
import '../services/geospatial_ar_service.dart';

/// Tela AR com Geospatial API nativo
///
/// Coloca modelo 3D em coordenadas GPS EXATAS usando VPS (precisão 1-5m)
class GeospatialARScreen extends ConsumerStatefulWidget {
  const GeospatialARScreen({super.key});

  @override
  ConsumerState<GeospatialARScreen> createState() => _GeospatialARScreenState();
}

class _GeospatialARScreenState extends ConsumerState<GeospatialARScreen> {
  String _statusMessage = 'Inicializando ARCore Geospatial...';
  GeospatialStatus? _status;
  bool _isModelPlaced = false;
  HouseModelConfig? _config;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    GeospatialARService.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Ensure camera permission is granted before initializing Geospatial AR
    final cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      final req = await Permission.camera.request();
      if (!req.isGranted) {
        setState(() {
          _statusMessage = 'Permissão de câmera necessária para AR.';
        });
        // Stop initialization if camera not granted
        return;
      }
    }
    try {
      // Carregar configuração
      final jsonString = await rootBundle.loadString(
        'assets/house_config.json',
      );
      _config = HouseModelConfig.fromJson(jsonDecode(jsonString));

      if (_config!.gpsCoordinates == null) {
        throw Exception(
          'GPS coordinates não configuradas em house_config.json',
        );
      }

      setState(() {
        _statusMessage =
            '⏳ Inicializando VPS (pode demorar até 2 min)...\n\n'
            '💡 DICAS:\n'
            '• Aponte para edifícios distantes\n'
            '• Gire lentamente 360°\n'
            '• Evite céu vazio ou paredes lisas';
      });

      // Inicializar Geospatial
      final initResult = await GeospatialARService.initialize();

      if (initResult['success'] == true) {
        final lat = initResult['latitude'];
        final lon = initResult['longitude'];
        final accuracy = initResult['accuracy'];

        setState(() {
          _statusMessage =
              'VPS ativo! Posição: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)} '
              '(±${accuracy.toStringAsFixed(1)}m)';
        });

        // Aguardar 2s para estabilizar
        await Future.delayed(const Duration(seconds: 2));

        // Colocar modelo
        await _placeModel();

        // Iniciar polling de status
        _startStatusPolling();
      }
    } on GeospatialException catch (e) {
      // Tratar erros específicos de Geospatial
      setState(() {
        if (e.code == 'PERMISSION_REQUIRED') {
          _statusMessage =
              '⚠️ ${e.message}\n\nAbra as configurações do app e conceda as permissões.';
        } else if (e.code == 'TIMEOUT') {
          _statusMessage = '⏱️ ${e.message}';
        } else {
          _statusMessage = 'Erro ${e.code}: ${e.message}';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: e.code == 'PERMISSION_REQUIRED'
                ? Colors.orange
                : e.code == 'TIMEOUT'
                ? Colors.deepOrange
                : Colors.red,
            duration: e.code == 'TIMEOUT'
                ? const Duration(seconds: 12)
                : const Duration(seconds: 8),
            action: e.code == 'PERMISSION_REQUIRED'
                ? SnackBarAction(
                    label: 'TENTAR NOVAMENTE',
                    textColor: Colors.white,
                    onPressed: () {
                      setState(() {
                        _statusMessage = 'Reiniciando...';
                      });
                      Future.delayed(
                        const Duration(milliseconds: 500),
                        _initialize,
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _placeModel() async {
    if (_config == null || _config!.gpsCoordinates == null) return;

    try {
      setState(() {
        _statusMessage = 'Criando Earth Anchor...';
      });

      final result = await GeospatialARService.addObject(
        id: 'house_model',
        latitude: _config!.gpsCoordinates![0],
        longitude: _config!.gpsCoordinates![1],
        altitude: _config!.altitude,
        modelUri: _config!.modelUri,
        rotation: _config!.rotationDegrees,
        scale: _config!.scale,
      );

      if (result['success'] == true) {
        setState(() {
          _isModelPlaced = true;
          _statusMessage =
              'Modelo colocado em GPS exato! '
              '(${_config!.gpsCoordinates![0].toStringAsFixed(6)}, '
              '${_config!.gpsCoordinates![1].toStringAsFixed(6)})';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro ao colocar modelo: $e';
      });
    }
  }

  void _startStatusPolling() {
    Future.doWhile(() async {
      if (!mounted) return false;

      try {
        final status = await GeospatialARService.getStatus();
        setState(() {
          _status = status;
        });
      } catch (e) {
        // Ignore polling errors
      }

      await Future.delayed(const Duration(seconds: 2));
      return mounted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ARCore Geospatial - VPS Nativo'),
        backgroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          // Camera feed seria renderizado aqui via PlatformView
          // Por agora mostramos apenas status
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isModelPlaced ? Icons.check_circle : Icons.satellite_alt,
                  color: _isModelPlaced
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  _isModelPlaced ? 'Modelo Colocado!' : 'Aguarde...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Status overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withAlpha((0.9 * 255).toInt()),
                    Colors.black.withAlpha((0.0 * 255).toInt()),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      'Tracking',
                      _status!.trackingState,
                      _status!.trackingState == 'TRACKING'
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                    _buildStatusRow(
                      'Earth',
                      _status!.earthState,
                      _status!.earthState == 'ENABLED'
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                    _buildStatusRow(
                      'Precisão',
                      '${_status!.horizontalAccuracy.toStringAsFixed(1)}m',
                      _status!.hasVPSPrecision
                          ? Colors.greenAccent
                          : Colors.yellowAccent,
                    ),
                    _buildStatusRow(
                      'Posição',
                      '${_status!.latitude.toStringAsFixed(6)}, ${_status!.longitude.toStringAsFixed(6)}',
                      Colors.white70,
                    ),
                    _buildStatusRow(
                      'Objetos',
                      '${_status!.objectCount}',
                      Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
