# HouseAR Project - AI Coding Agent Instructions

## Project Overview
Flutter-based AR application for visualizing 3D house models in real-world terrain using ARCore (Android) and ARKit (iOS). The app allows users to place, rotate, and scale architectural models on physical surfaces through their mobile device camera.

## Technology Stack
- **Framework**: Flutter 3.19+
- **AR Plugin**: `ar_flutter_plugin_2` (v0.0.3+) - Modern successor using Sceneview instead of Sceneform
- **State Management**: `flutter_riverpod` (v2.0+) - Reactive state management with providers
- **3D Format**: glTF 2.0 (.glb/.gltf files)
- **Math Library**: `vector_math` for 3D transformations

> **Critical**: Use `ar_flutter_plugin_2`, NOT the old `ar_flutter_plugin` (discontinued). The new version supports animated models and latest ARCore.
> **State Management**: Always use Riverpod for state management. Wrap app with `ProviderScope`, use `ConsumerWidget` or `ConsumerStatefulWidget` for reactive UI.

## Project Architecture

### Core Components
1. **`lib/main.dart`**: App entry point with MaterialApp setup using dark theme
2. **`lib/screens/ar_house_screen.dart`**: Main AR view with session/object managers
3. **`assets/models/house.gltf`**: 3D model (dummy red cube included for testing)

### AR Session Flow
```
ARView created → setupSession() → Enable plane detection → 
Load .glb model → Create ARNode → Add to ARObjectManager → 
User taps screen → Position model at detected surface
```

### Key Classes & Managers
- `ARSessionManager`: Handles AR session lifecycle and plane detection
- `ARObjectManager`: Manages 3D nodes in AR space
- `ARAnchorManager`: Places and tracks AR anchors (currently unused but available)
- `ARNode`: Represents 3D objects with `type: NodeType.localGLTF2`, scale, position, rotation

## Development Workflows

### Initial Setup
```bash
flutter create ar_casa
cd ar_casa
# Add dependencies to pubspec.yaml
flutter pub get
```

### Model Requirements
- Export from Blender/SketchUp/Revit as glTF 2.0 (.glb)
- Use **+Y Up** transform convention
- Include materials and textures in export
- Place in `assets/models/` and declare in `pubspec.yaml` under `flutter: assets:`

### Running on Device
- **Android**: Requires ARCore-compatible device (Android 7.0+)
- **iOS**: Requires ARKit support (iOS 11+)
- Use `flutter run` with physical device connected (AR doesn't work on emulators)

## Coding Conventions

### State Management with Riverpod
Use Riverpod providers for all app state:
```dart
// Define providers
final arSessionProvider = StateProvider<ARSessionManager?>((ref) => null);
final modelPlacedProvider = StateProvider<bool>((ref) => false);

// In widgets, use ConsumerWidget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaced = ref.watch(modelPlacedProvider);
    return Text(isPlaced ? 'Placed' : 'Not placed');
  }
}

// Update state
ref.read(modelPlacedProvider.notifier).state = true;
```

### AR Node Creation Pattern
```dart
ARNode(
  type: NodeType.localGLTF2,
  uri: "assets/models/house.gltf",
  scale: Vector3(0.3, 0.3, 0.3),      // Adjust based on model size
  position: Vector3(0.0, 0.0, -1.5),   // 1.5m in front of camera
)
```

### Session Lifecycle
Always dispose AR managers in `dispose()` to prevent memory leaks:
```dart
@override
void dispose() {
  arSessionManager?.dispose();
  super.dispose();
}
```

## Future Integration Points (Documented but Not Implemented)
- **GPS-based placement** (✅ Documented in `docs/GPS_PLACEMENT.md`) - Automatic model placement using GPS coordinates
- Sun simulation for realistic shadows
- Material swapping UI (paints, roofs, windows)
- Save/load AR anchor positions
- Miniature mode for tabletop viewing

## Language & Documentation
- **Primary Language**: Portuguese (PT)
- UI strings, comments, and variable names use Portuguese terminology
- README written in Portuguese for local market

## When Making Changes
- Keep code structure simple - this is an MVP/educational project
- Maintain dark theme styling (`ThemeData.dark()`)
- Test AR features only on physical devices with ARCore/ARKit
- Vector3 positions use meters (real-world scale)
- Default model placement is 2 meters in front of user at startup
 
## Regras obrigatórias para agentes de IA (debug)
- O agente de IA responsável por editar o código DEVE executar um debug completo antes de finalizar qualquer PR/edição que altere código: executar em sequência `flutter pub get`, `flutter analyze`, `flutter test` e, quando aplicável para AR, `flutter run` em dispositivo físico.
- Corrija todos os erros do analisador e falhas de teste até que `flutter analyze` retorne "No issues found" e `flutter test` passe, ou documente claramente quaisquer limitações que impeçam resolução (por exemplo, hardware físico necessário).
- Registre no commit ou na descrição do PR quais comandos foram executados e o resultado (analyzer/testes), e inclua notas breves sobre validações manuais (ex.: validação AR em dispositivo X).
