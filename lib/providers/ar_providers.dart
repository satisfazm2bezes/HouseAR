import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider para gerenciar a sessão AR
final arSessionManagerProvider = StateProvider<ARSessionManager?>(
  (ref) => null,
);

/// Provider para gerenciar objetos AR
final arObjectManagerProvider = StateProvider<ARObjectManager?>((ref) => null);

/// Provider para gerenciar âncoras AR
final arAnchorManagerProvider = StateProvider<ARAnchorManager?>((ref) => null);

/// Provider para o nó da casa (modelo 3D)
final houseNodeProvider = StateProvider<ARNode?>((ref) => null);

/// Provider para verificar se o modelo foi colocado
final isModelPlacedProvider = StateProvider<bool>((ref) => false);
