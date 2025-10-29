// FICHEIRO COMPLETO GPS PURO - COPIA ISTO TODO
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:geolocator/geolocator.dart';
import '../providers/ar_providers.dart';
import '../models/house_model_config.dart';
import '../services/gps_calculator.dart';

class ARHouseScreen extends ConsumerStatefulWidget {
  const ARHouseScreen({super.key});

  @override
  ConsumerState<ARHouseScreen> createState() => _ARHouseScreenState();
}

class _ARHouseScreenState extends ConsumerState<ARHouseScreen> {
  String _statusMessage = 'Aguarde... Obtendo GPS...';

  @override
  void dispose() {
    ref.read(arSessionManagerProvider)?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isModelPlaced = ref.watch(isModelPlacedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HouseAR - GPS Puro'),
        backgroundColor: Colors.black87,
        actions: [
          if (isModelPlaced)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetModel,
              tooltip: 'Resetar',
            ),
        ],
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isModelPlaced ? Icons.check_circle : Icons.gps_fixed,
                      color: isModelPlaced
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _loadGpsInfo(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final data = snapshot.data!;
                          return Column(
                            children: [
                              Text(
                                '${data['lat']}, ${data['lon']}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Altitude: ${data['alt']}m',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) async {
    debugPrint('🎥 AR View criada!');

    ref.read(arSessionManagerProvider.notifier).state = arSessionManager;
    ref.read(arObjectManagerProvider.notifier).state = arObjectManager;
    ref.read(arAnchorManagerProvider.notifier).state = arAnchorManager;

    await arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: false,
    );

    // Tentativa defensiva de inicializar o ARObjectManager — alguns dispositivos/plugins
    // podem registrar canais de plataforma de forma assíncrona. Vamos tentar algumas
    // vezes antes de falhar para reduzir MissingPluginException intermitente.
    const maxInitAttempts = 4;
    var initAttempt = 0;
    var initOk = false;
    while (initAttempt < maxInitAttempts && !initOk) {
      try {
        initAttempt++;
        await arObjectManager.onInitialize();
        initOk = true;
      } catch (e, st) {
        debugPrint(
          '⚠️ arObjectManager.onInitialize falhou (tentativa $initAttempt): $e\n$st',
        );
        // Se for MissingPluginException, aguarda e tenta novamente
        if (e is MissingPluginException) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        // Para outros erros, não tentamos indefinidamente — relança para ser tratado acima
        rethrow;
      }
    }

    if (!initOk) {
      debugPrint(
        '❌ Falha ao inicializar ARObjectManager depois de $maxInitAttempts tentativas.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Falha ao inicializar gerenciador AR (MissingPlugin) — veja logs',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } else {
      debugPrint('✅ AR managers inicializados!');
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _placeModelWithGPS();
    });
  }

  Future<void> _placeModelWithGPS() async {
    debugPrint('🚀 GPS PURO ativado (SEM ARCore Geospatial API)');

    try {
      setState(() {
        _statusMessage = 'Carregando configuração GPS...';
      });

      final jsonString = await rootBundle.loadString(
        'assets/house_config.json',
      );
      final config = HouseModelConfig.fromJson(jsonDecode(jsonString));

      if (config.gpsCoordinates == null) {
        throw Exception('GPS coordinates nao configuradas');
      }

      debugPrint(
        '🎯 Alvo GPS: ${config.gpsCoordinates![0]}, ${config.gpsCoordinates![1]}, ${config.altitude}m',
      );

      setState(() {
        _statusMessage = 'Verificando permissões GPS...';
      });

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          throw Exception('Permissao GPS negada');
        }
      }

      setState(() {
        _statusMessage = 'Obtendo sua posição GPS...';
      });

      debugPrint('📡 Aguardando GPS...');
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      debugPrint(
        '📍 Você está em: ${currentPosition.latitude}, ${currentPosition.longitude}, ${currentPosition.altitude}m',
      );
      debugPrint('🎯 Precisão GPS: ${currentPosition.accuracy}m');

      setState(() {
        _statusMessage = 'Calculando posição local...';
      });

      final localPosition = GPSCalculator.gpsToLocalPositionFrom(
        currentLat: currentPosition.latitude,
        currentLon: currentPosition.longitude,
        currentAlt: currentPosition.altitude,
        targetLat: config.gpsCoordinates![0],
        targetLon: config.gpsCoordinates![1],
        targetAlt: config.altitude,
      );

      final distance = GPSCalculator.calculateDistance(
        lat1: currentPosition.latitude,
        lon1: currentPosition.longitude,
        lat2: config.gpsCoordinates![0],
        lon2: config.gpsCoordinates![1],
      );

      debugPrint('📏 Distância: ${distance.toStringAsFixed(1)}m');
      debugPrint(
        '📐 Posição AR: X=${localPosition.x.toStringAsFixed(1)}, Y=${localPosition.y.toStringAsFixed(1)}, Z=${localPosition.z.toStringAsFixed(1)}',
      );

      setState(() {
        _statusMessage = 'Criando objeto a ${distance.toStringAsFixed(0)}m...';
      });

      final rotationY = config.rotationDegrees * (pi / 180.0);
      final quaternion = vector.Quaternion.axisAngle(
        vector.Vector3(0, 1, 0),
        rotationY,
      );
      final transform = vector.Matrix4.compose(
        localPosition,
        quaternion,
        vector.Vector3.all(config.scale),
      );

      final node = ARNode(
        type: config.modelUri.startsWith('http')
            ? NodeType.webGLB
            : NodeType.localGLTF2,
        uri: config.modelUri,
        transformation: transform,
      );

      setState(() {
        _statusMessage = 'Adicionando modelo 3D...';
      });

      debugPrint('🎨 Adicionando à cena AR...');
      bool? result;
      // Adiciona tentativa/retry para MissingPluginException no momento de adicionar nó (comum em casos de
      // registro de plugins não disponível imediatamente).
      const maxAddAttempts = 4;
      var addAttempt = 0;
      while (addAttempt < maxAddAttempts) {
        try {
          addAttempt++;
          result = await ref.read(arObjectManagerProvider)?.addNode(node);
          break;
        } catch (e, st) {
          debugPrint('⚠️ addNode falhou (tentativa $addAttempt): $e\n$st');
          if (e is MissingPluginException) {
            await Future.delayed(const Duration(milliseconds: 600));
            continue;
          }
          rethrow;
        }
      }

      if (result == true) {
        debugPrint('🎉 SUCESSO! Modelo colocado com GPS puro!');
        ref.read(houseNodeProvider.notifier).state = node;
        ref.read(isModelPlacedProvider.notifier).state = true;
        setState(() {
          _statusMessage =
              'Modelo a ${distance.toStringAsFixed(0)}m (precisão ~${currentPosition.accuracy.toStringAsFixed(0)}m)';
        });
      } else {
        throw Exception(
          'addNode retornou false ou não foi possível inicializar o canal nativo',
        );
      }
    } catch (e) {
      debugPrint('❌ Erro: $e');
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

  Future<Map<String, dynamic>> _loadGpsInfo() async {
    try {
      final json = await rootBundle.loadString('assets/house_config.json');
      final config = HouseModelConfig.fromJson(jsonDecode(json));
      return {
        'lat': config.gpsCoordinates![0].toStringAsFixed(6),
        'lon': config.gpsCoordinates![1].toStringAsFixed(6),
        'alt': config.altitude.toStringAsFixed(1),
      };
    } catch (e) {
      return {'lat': 'N/A', 'lon': 'N/A', 'alt': '0'};
    }
  }

  Future<void> _resetModel() async {
    final node = ref.read(houseNodeProvider);
    if (node != null) {
      await ref.read(arObjectManagerProvider)?.removeNode(node);
      ref.read(houseNodeProvider.notifier).state = null;
      ref.read(isModelPlacedProvider.notifier).state = false;
      setState(() {
        _statusMessage = 'Aguarde... Obtendo GPS...';
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _placeModelWithGPS();
      });
    }
  }
}
