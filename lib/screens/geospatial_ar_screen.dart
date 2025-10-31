import 'dart:convert';
import 'dart:io';
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
  HouseModelConfig? _config;

  @override
  void initState() {
    super.initState();
    _initialize();
    // Iniciar polling de status imediatamente
    _startStatusPolling();
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
              '(±${accuracy.toStringAsFixed(1)}m)\n\n'
              'Aguarde precisão < 1m para colocar modelo...';
        });
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
    bool modelPlaced = false;

    Future.doWhile(() async {
      if (!mounted) return false;

      try {
        final status = await GeospatialARService.getStatus();
        if (mounted) {
          setState(() {
            _status = status;
          });
          print(
            '📊 Status atualizado: ${status.earthState}, ${status.trackingState}, ${status.horizontalAccuracy}m',
          );

          // Colocar modelo automaticamente quando precisão < 1m
          if (!modelPlaced &&
              status.earthState == 'ENABLED' &&
              status.trackingState == 'TRACKING' &&
              status.horizontalAccuracy < 1.0) {
            modelPlaced = true;
            print(
              '✅ Precisão boa (${status.horizontalAccuracy.toStringAsFixed(2)}m) - colocando modelo!',
            );
            _placeModel();
          }
        }
      } catch (e) {
        print('❌ Erro polling: $e');
      }

      await Future.delayed(const Duration(seconds: 1));
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
          // Camera AR View
          if (Platform.isAndroid)
            AndroidView(
              viewType: 'ar_geospatial_view',
              onPlatformViewCreated: (_) {
                debugPrint('ArGeospatialView criada');
              },
            )
          else
            Center(
              child: Text(
                'ARCore Geospatial apenas disponível em Android',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),

          // Status overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
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
                  const SizedBox(height: 12),

                  // Check indicators: Earth, Tracking, Precision
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildCheckCard(
                          label: 'Earth',
                          ok: (_status?.earthState ?? 'UNKNOWN') == 'ENABLED',
                          detail: _status?.earthState ?? 'AGUARDANDO',
                          hint: _status == null
                              ? 'Inicializando...'
                              : (_status!.earthState == 'ENABLED'
                                    ? 'OK'
                                    : 'Verifique API key'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCheckCard(
                          label: 'Tracking',
                          ok:
                              (_status?.trackingState ?? 'UNKNOWN') ==
                              'TRACKING',
                          detail: _status?.trackingState ?? 'AGUARDANDO',
                          hint: _status == null
                              ? 'Inicializando...'
                              : (_status!.trackingState == 'TRACKING'
                                    ? 'VPS ativo'
                                    : 'Gire 360°'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCheckCard(
                          label: 'Precisão',
                          ok:
                              (_status?.horizontalAccuracy ?? double.infinity) <
                              5.0,
                          detail: _status != null
                              ? '${_status!.horizontalAccuracy.toStringAsFixed(1)}m'
                              : '---',
                          hint: _status == null
                              ? 'Inicializando...'
                              : (_status!.horizontalAccuracy < 5.0
                                    ? 'Boa'
                                    : 'Aguarde'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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

  Widget _buildCheckCard({
    required String label,
    required bool ok,
    required String detail,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok ? Colors.greenAccent : Colors.orangeAccent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.error_outline,
                color: ok ? Colors.greenAccent : Colors.orangeAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
