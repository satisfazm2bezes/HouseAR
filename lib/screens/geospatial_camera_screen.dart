import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/house_model_config.dart';
import '../widgets/ar_geospatial_camera_view.dart';
// import 'ar_house_screen.dart'; // REMOVIDO - usava ar_flutter_plugin_2

/// Tela AR com preview de câmera
class GeospatialCameraScreen extends ConsumerStatefulWidget {
  const GeospatialCameraScreen({super.key});

  @override
  ConsumerState<GeospatialCameraScreen> createState() =>
      _GeospatialCameraScreenState();
}

class _GeospatialCameraScreenState
    extends ConsumerState<GeospatialCameraScreen> {
  String _statusMessage = 'Inicializando câmera AR...';
  final _arController = ArGeospatialController();
  Timer? _statusTimer;
  HouseModelConfig? _config;
  bool _modelPlaced = false;
  bool _hasCameraPermission = false;
  bool _indoorAlertShown = false; // NOVO: Mostrar alerta indoor apenas uma vez
  int _nativeFailureCount = 0;
  int _vpsNotTrackingSeconds = 0;
  // key to force recreation of the platform view if native layer misbehaves
  Key _arViewKey = UniqueKey();

  // Status VPS detalhado
  String _earthState = 'UNKNOWN';
  String _trackingState = 'UNKNOWN';
  double _horizontalAccuracy = 999.0;
  bool _vpsActive = false;

  // Logger visual
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _loggerExpanded = true;
  int _totalCameras = 0;
  int _currentCameraIndex = 0;

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.add('[$timestamp] $message');
      if (_logs.length > 50) {
        _logs.removeAt(0); // Manter apenas últimas 50 linhas
      }
    });
    // Auto-scroll para o fim
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _addLog('🚀 Iniciando app...');
    _requestCameraPermissionAndLoad();
  }

  Future<void> _requestCameraPermissionAndLoad() async {
    // Camera permission
    final camStatus = await Permission.camera.status;
    if (!camStatus.isGranted) {
      final res = await Permission.camera.request();
      if (!res.isGranted) {
        setState(() {
          _statusMessage = 'Permissão de câmera negada. AR não será iniciado.';
          _hasCameraPermission = false;
        });
        return;
      }
    }

    // Location permission (required by ARCore Geospatial mode)
    final locStatus = await Permission.location.status;
    if (!locStatus.isGranted) {
      final resLoc = await Permission.location.request();
      if (!resLoc.isGranted) {
        setState(() {
          _statusMessage =
              'Permissão de localização necessária para VPS (Geospatial).';
          _hasCameraPermission = false;
        });
        return;
      }
    }

    setState(() => _hasCameraPermission = true);
    await _loadConfig();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCameraInfo() async {
    // Esperar um pouco para a câmera inicializar
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      final cameraInfo = await _arController.getCameraInfo();
      if (cameraInfo != null && mounted) {
        if (cameraInfo.containsKey('error')) {
          _addLog('⚠️ Câmera: ${cameraInfo['error']}');
        } else {
          final total = cameraInfo['totalCameras'] ?? 0;
          final index = cameraInfo['selectedIndex'] ?? 0;
          final id = cameraInfo['cameraId'] ?? 'N/A';
          final fps = cameraInfo['fps'] ?? 'N/A';
          final width = cameraInfo['imageWidth'] ?? 0;
          final height = cameraInfo['imageHeight'] ?? 0;

          setState(() {
            _totalCameras = total;
            _currentCameraIndex = index;
          });

          _addLog('📷 Câmeras disponíveis: $total');
          _addLog('📷 Selecionada: #$index (ID: $id)');
          _addLog('📷 FPS: $fps, Res: ${width}x$height');
        }
      }
    } catch (e) {
      _addLog('❌ Erro ao obter info câmera: $e');
    }
  }

  Future<void> _switchCamera(int index) async {
    _addLog('🔄 Trocando para câmera #$index...');
    await _arController.selectCamera(index);

    // RECRIAR a view AR completamente
    setState(() {
      _arViewKey = UniqueKey(); // Força recriação do AndroidView
      _currentCameraIndex = index;
    });

    _addLog('🔄 View AR recriada com câmera #$index');

    // Aguardar um pouco e obter nova info
    await Future.delayed(const Duration(milliseconds: 2000));
    await _getCameraInfo();
  }

  Future<void> _loadConfig() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/house_config.json',
      );
      _config = HouseModelConfig.fromJson(jsonDecode(jsonString));
      final coords = _config!.gpsCoordinates;
      _addLog(
        '✅ Config: ${coords?[0]}, ${coords?[1]}, alt=${_config!.altitude}m',
      );
      setState(() {
        _statusMessage = 'Configuração carregada. Aguardando VPS...';
      });

      // Obter info de câmera
      _getCameraInfo();

      // Começar polling de status
      _startStatusPolling();
    } catch (e) {
      _addLog('❌ Erro ao carregar config: $e');
      setState(() {
        _statusMessage = 'Erro ao carregar config: $e';
      });
    }
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final status = await _arController.getVPSStatus();

        if (status != null && mounted) {
          _nativeFailureCount = 0; // reset failures when we get a result
          final tracking = status['tracking'] as bool? ?? false;
          final accuracy = status['horizontalAccuracy'] as double? ?? 999.0;
          final earthState = status['earthState'] as String? ?? 'UNKNOWN';
          final trackingState = status['trackingState'] as String? ?? 'UNKNOWN';

          _addLog(
            '� VPS: earth=$earthState, track=$trackingState, acc=${accuracy.toStringAsFixed(1)}m',
          );

          setState(() {
            _vpsActive = tracking;
            _earthState = earthState;
            _trackingState = trackingState;
            _horizontalAccuracy = accuracy;

            if (tracking) {
              _statusMessage = 'VPS ATIVO';
              _vpsNotTrackingSeconds = 0;
            } else {
              _statusMessage = 'Aguardando VPS...';
              // increment local counter (each tick = 2s)
              _vpsNotTrackingSeconds += 2;
            }
          });
        } else {
          // result is null: count as a native failure
          _nativeFailureCount++;
        }
      } catch (e) {
        // If platform channel throws, increment failure count and show message
        _nativeFailureCount++;
        if (mounted) {
          setState(() {
            _statusMessage =
                'Erro nativo ao obter status VPS: $e\n\nTente reiniciar o AR.';
          });
        }
      }

      // If we've seen multiple consecutive native failures, surface a restart UI
      if (_nativeFailureCount >= 3 && mounted) {
        setState(() {
          _statusMessage =
              'Erro contínuo na camada nativa ($_nativeFailureCount falhas).\nToque em Reiniciar AR.';
        });
      }

      // If VPS not tracking for some time, switch to GPS-only fallback
      const int fallbackThresholdSeconds = 20; // 20s without VPS
      if (_vpsNotTrackingSeconds >= fallbackThresholdSeconds && mounted) {
        setState(() {
          _statusMessage = 'VPS indisponível — reiniciando sessão AR...';
        });

        // Restart AR session instead of fallback to GPS-only
        _restartAR();
      }
    });
  }

  void _restartAR() {
    // Stop polling, recreate platform view and restart polling
    _statusTimer?.cancel();
    _nativeFailureCount = 0;
    _modelPlaced = false;
    setState(() {
      // Changing the key forces AndroidView to be recreated
      _arViewKey = UniqueKey();
      _statusMessage = 'Reiniciando AR...';
    });

    // small delay to allow platform view to recreate
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startStatusPolling();
    });
  }

  bool _canPlaceModel() {
    // Pode colocar modelo se:
    // 1. VPS está ativo (tracking)
    // 2. Earth está habilitado
    // 3. Precisão < 10.0m (para testes - VPS típico em exterior)
    return _vpsActive &&
        _earthState == 'ENABLED' &&
        _trackingState == 'TRACKING' &&
        _horizontalAccuracy < 10.0;
  }

  Future<void> _placeModel() async {
    if (_config?.gpsCoordinates == null) return;

    final coords = _config!.gpsCoordinates!;
    _addLog(
      '🎯 Colocando modelo em: ${coords[0]}, ${coords[1]}, alt=${_config!.altitude}m',
    );

    await _arController.placeModel(coords[0], coords[1], _config!.altitude);

    _addLog(
      '✅ Modelo colocado! (precisão: ${_horizontalAccuracy.toStringAsFixed(1)}m)',
    );
    setState(() {
      _modelPlaced = true;
    });
  }

  // NOVO: Mostrar alerta quando problema indoor detectado
  void _showIndoorAlert(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.orangeAccent, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.home, color: Colors.orangeAccent, size: 28),
              SizedBox(width: 12),
              Text(
                'Problema Indoor Detectado',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.info_outline, color: Colors.blueAccent),
              label: const Text(
                'Entendi',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.outdoor_grill, color: Colors.white),
              label: const Text(
                'Vou Sair',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade700,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _addLog('📍 Usuário vai tentar outdoor');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Preview da câmera AR (fullscreen) — somente quando a permissão de câmera for concedida
          if (_hasCameraPermission)
            ArGeospatialCameraView(key: _arViewKey, controller: _arController)
          else
            // Mostrar mensagem quando não há permissão
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _requestCameraPermissionAndLoad,
                      child: const Text('Conceder permissão de câmera'),
                    ),
                  ],
                ),
              ),
            ),

          // Status overlay com 3 cards
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mensagem de status principal
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão para colocar modelo
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _canPlaceModel() && !_modelPlaced
                          ? _placeModel
                          : null,
                      icon: Icon(
                        _modelPlaced
                            ? Icons.check_circle
                            : Icons.add_location_alt,
                      ),
                      label: Text(
                        _modelPlaced
                            ? 'Modelo Colocado!'
                            : _canPlaceModel()
                            ? 'Colocar Modelo (±${_horizontalAccuracy.toStringAsFixed(1)}m)'
                            : _horizontalAccuracy < 999.0
                            ? 'Precisão: ${_horizontalAccuracy.toStringAsFixed(1)}m (aguarde <10m)'
                            : 'Aguardando VPS...',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _modelPlaced
                            ? Colors.greenAccent.shade700
                            : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3 cards: Earth, Tracking, Precisão
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusCard(
                          label: 'Earth',
                          value: _earthState,
                          isOk: _earthState == 'ENABLED',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusCard(
                          label: 'Tracking',
                          value: _trackingState,
                          isOk: _trackingState == 'TRACKING',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusCard(
                          label: 'Precisão',
                          value: '${_horizontalAccuracy.toStringAsFixed(1)}m',
                          isOk: _horizontalAccuracy < 10.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Reiniciar AR button when native failures detected
          if (_nativeFailureCount >= 3)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                ),
                onPressed: _restartAR,
                child: const Text('Reiniciar AR'),
              ),
            ),

          // Logger visual - canto superior esquerdo
          Positioned(
            top: 60,
            left: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 300,
              height: _loggerExpanded ? 400 : 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header com botão expand/collapse
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _loggerExpanded = !_loggerExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.vertical(
                          top: const Radius.circular(8),
                          bottom: _loggerExpanded
                              ? Radius.zero
                              : const Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.terminal,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Debug Logger',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _loggerExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Logs com scroll (apenas quando expandido)
                  if (_loggerExpanded)
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Botões para trocar câmera
                  if (_loggerExpanded && _totalCameras > 1)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        border: Border(
                          top: BorderSide(
                            color: Colors.greenAccent.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Câmera:',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...List.generate(_totalCameras, (index) {
                            final isSelected = index == _currentCameraIndex;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ElevatedButton(
                                onPressed: () => _switchCamera(index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? Colors.greenAccent
                                      : Colors.grey.shade700,
                                  foregroundColor: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  minimumSize: const Size(40, 32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: Text(
                                  '#$index',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String label,
    required String value,
    required bool isOk,
  }) {
    Color borderColor;
    Color iconColor;
    IconData icon;

    if (value == 'UNKNOWN' || value == '999.0m') {
      // Ainda não inicializado - cinzento
      borderColor = Colors.grey;
      iconColor = Colors.grey;
      icon = Icons.help_outline;
    } else if (isOk) {
      // OK - verde
      borderColor = Colors.greenAccent;
      iconColor = Colors.greenAccent;
      icon = Icons.check_circle;
    } else {
      // Erro - vermelho
      borderColor = Colors.redAccent;
      iconColor = Colors.redAccent;
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
