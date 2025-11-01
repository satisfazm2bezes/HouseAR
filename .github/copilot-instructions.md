# HouseAR Project - AI Coding Agent Instructions

## Project Overview
Flutter-based AR application for visualizing 3D house models in real-world terrain using ARCore (Android) and ARKit (iOS). The app allows users to place, rotate, and scale architectural models on physical surfaces through their mobile device camera.

## Technology Stack
- **Framework**: Flutter 3.19+
- **AR Plugin**: `ar_flutter_plugin_2` (v0.0.3+) - Modern successor using Sceneview instead of Sceneform
- **AR Library (Android)**: `io.github.sceneview:arsceneview:2.2.1` - SceneView library for ARCore rendering
- **State Management**: `flutter_riverpod` (v2.0+) - Reactive state management with providers
- **3D Format**: glTF 2.0 (.glb/.gltf files)
- **Math Library**: `vector_math` for 3D transformations

> **State Management**: Always use Riverpod for state management. Wrap app with `ProviderScope`, use `ConsumerWidget` or `ConsumerStatefulWidget` for reactive UI.
> **Reference Plugin**: Use https://github.com/hlefe/ar_flutter_plugin_2 as primary reference for ARSceneView integration, lifecycle management, and best practices.

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

### Reference Implementation: ar_flutter_plugin_2
**Repository**: https://github.com/hlefe/ar_flutter_plugin_2

Este plugin é a **referência principal** para implementação ARCore/ARSceneView no projeto. Seguir padrões deste plugin:

#### ARSceneView Initialization (Android)
```kotlin
// android/src/main/kotlin/.../ArView.kt
class ArView(
    context: Context,
    private val activity: Activity,
    private val lifecycle: Lifecycle,  // CRUCIAL: Lifecycle do FlutterActivity
    messenger: BinaryMessenger,
    id: Int
) : PlatformView {
    
    private var sceneView: ARSceneView
    
    init {
        // ARSceneView COM lifecycle (essencial para session funcionar)
        sceneView = ARSceneView(
            context = context,
            sharedLifecycle = lifecycle,  // Passado do FlutterActivity
            sessionConfiguration = { session, config ->
                config.apply {
                    // Configurar geospatialMode, depthMode, etc
                    geospatialMode = Config.GeospatialMode.ENABLED
                    planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                }
            }
        )
        
        rootLayout.addView(sceneView)
        
        // onFrame callback para processar frames AR
        sceneView.onFrame = { frameTime ->
            sceneView.session?.update()?.let { frame ->
                // Processar frame, Earth tracking, etc
            }
        }
    }
}
```

#### Factory Pattern com Lifecycle
```kotlin
// android/src/main/kotlin/.../ArViewFactory.kt
class ArViewFactory(
    private val messenger: BinaryMessenger,
    private val activity: Activity,
    private val lifecycle: Lifecycle  // Receber lifecycle do plugin
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ArView(context, activity, lifecycle, messenger, viewId)
    }
}
```

#### Plugin Registration
```kotlin
// android/src/main/kotlin/.../ArFlutterPlugin.kt
class ArFlutterPlugin: FlutterPlugin, ActivityAware {
    private var activity: Activity? = null
    private var lifecycle: Lifecycle? = null
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        lifecycle = (activity as LifecycleOwner).lifecycle  // Obter lifecycle
        
        // Registrar factory COM lifecycle
        flutterPluginBinding?.platformViewRegistry?.registerViewFactory(
            "ar_flutter_plugin_2",
            ArViewFactory(
                messenger = flutterBinding.binaryMessenger,
                activity = activity!!,
                lifecycle = lifecycle!!  // Passar lifecycle
            )
        )
    }
}
```

#### Model Loading com ARSceneView
```kotlin
// Carregar modelo 3D usando ARSceneView modelLoader
private suspend fun buildModelNode(nodeData: Map<String, Any>): ModelNode? {
    val modelUri = nodeData["uri"] as String
    
    val modelInstance = sceneView.modelLoader.createModelInstance(modelUri)
    
    return ModelNode(
        modelInstance = modelInstance,
        scaleToUnits = (nodeData["scale"] as? Double)?.toFloat() ?: 1.0f
    ).apply {
        // Configurar position, rotation conforme nodeData
    }
}

// Adicionar à cena com anchor
val anchorNode = AnchorNode(sceneView.engine, anchor)
anchorNode.addChildNode(modelNode)
sceneView.addChildNode(anchorNode)
```

#### Geospatial API Pattern
```kotlin
// No onFrame callback
sceneView.session?.let { session ->
    val frame = session.update()
    val earth = session.earth
    
    if (earth?.trackingState == TrackingState.TRACKING) {
        val pose = earth.cameraGeospatialPose
        
        // Verificar accuracy
        if (pose.horizontalAccuracy < 10.0) {
            // VPS pronto - criar terrain anchors
            val anchor = earth.createAnchor(
                latitude, longitude, altitude,
                0f, 0f, 0f, 1f  // Quaternion
            )
        }
    }
}
```

#### MethodChannel Pattern
```kotlin
// Configurar 3 channels como no plugin de referência
private val sessionChannel = MethodChannel(messenger, "arsession_$id")
private val objectChannel = MethodChannel(messenger, "arobjects_$id")
private val anchorChannel = MethodChannel(messenger, "aranchors_$id")

// Handler para cada channel
sessionChannel.setMethodCallHandler { call, result ->
    when (call.method) {
        "init" -> handleInit(call, result)
        "getCameraPose" -> handleGetCameraPose(result)
        "snapshot" -> handleSnapshot(result)
        else -> result.notImplemented()
    }
}
```

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
