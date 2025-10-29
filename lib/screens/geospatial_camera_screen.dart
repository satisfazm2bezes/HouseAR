import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/house_model_config.dart';
import '../widgets/ar_geospatial_camera_view.dart';
import 'ar_house_screen.dart';

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
  int _nativeFailureCount = 0;
  int _vpsNotTrackingSeconds = 0;
  // key to force recreation of the platform view if native layer misbehaves
  Key _arViewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/house_config.json',
      );
      _config = HouseModelConfig.fromJson(jsonDecode(jsonString));
      setState(() {
        _statusMessage = 'Configuração carregada. Aguardando VPS...';
      });

      // Começar polling de status
      _startStatusPolling();
    } catch (e) {
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
          final lat = status['latitude'] as double? ?? 0.0;
          final lon = status['longitude'] as double? ?? 0.0;
          final accuracy = status['accuracy'] as double? ?? 999.0;

          setState(() {
            if (tracking) {
              _statusMessage =
                  '✅ VPS ATIVO\n📍 ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}\n📏 ±${accuracy.toStringAsFixed(1)}m';

              // Colocar modelo automaticamente quando VPS ativar
              if (!_modelPlaced && _config?.gpsCoordinates != null) {
                _placeModel();
              }
              _vpsNotTrackingSeconds = 0;
            } else {
              _statusMessage =
                  '⏳ Aguardando VPS...\n\n'
                  '💡 Aponte para edifícios distantes\n'
                  '💡 Gire lentamente 360°';
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
          _statusMessage =
              'VPS indisponível — a mudar para modo GPS puro (fallback)...';
        });

        // Navigate to GPS-only AR screen (replaces current screen)
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ARHouseScreen()),
        );
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

  Future<void> _placeModel() async {
    if (_config?.gpsCoordinates == null) return;

    final coords = _config!.gpsCoordinates!;
    await _arController.placeModel(coords[0], coords[1], _config!.altitude);

    setState(() {
      _modelPlaced = true;
      _statusMessage = '$_statusMessage\n\n⚓ Modelo colocado!';
    });
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

          // Status overlay
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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

          // Botão de fechar
          Positioned(
            top: 60,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
