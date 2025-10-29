import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/house_model_config.dart';
import '../widgets/ar_geospatial_camera_view.dart';

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

  @override
  void initState() {
    super.initState();
    _loadConfig();
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
      final status = await _arController.getVPSStatus();

      if (status != null && mounted) {
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
          } else {
            _statusMessage =
                '⏳ Aguardando VPS...\n\n'
                '💡 Aponte para edifícios distantes\n'
                '💡 Gire lentamente 360°';
          }
        });
      }
    });
  }

  Future<void> _placeModel() async {
    if (_config?.gpsCoordinates == null) return;

    final coords = _config!.gpsCoordinates!;
    await _arController.placeModel(coords[0], coords[1], _config!.altitude);

    setState(() {
      _modelPlaced = true;
      _statusMessage = '${_statusMessage}\n\n⚓ Modelo colocado!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Preview da câmera AR (fullscreen)
          ArGeospatialCameraView(controller: _arController),

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
