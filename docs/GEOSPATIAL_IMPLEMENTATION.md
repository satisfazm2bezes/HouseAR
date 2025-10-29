# Implementação ARCore Geospatial API - Guia Completo

## ✅ O que já está implementado

### 1. **MethodChannel Flutter** (`lib/services/geospatial_service.dart`)
- ✅ `initializeGeospatial()` - Inicializa ARCore Geospatial Session
- ✅ `checkVPSAvailability()` - Verifica VPS e retorna posição atual
- ✅ `createEarthAnchor()` - Cria anchor em coordenadas GPS
- ✅ `removeEarthAnchor()` - Remove anchor
- ✅ `getAnchorPose()` - Obtém pose atualizado

### 2. **Módulo Nativo Android** (`android/app/src/main/kotlin/.../GeospatialManager.kt`)
- ✅ Inicialização de ARCore Session com `Config.GeospatialMode.ENABLED`
- ✅ Verificação de VPS (tracking state e accuracy)
- ✅ Criação de Earth Anchors com `earth.createAnchor(lat, lon, alt, quaternion)`
- ✅ Retorno de pose (position + rotation quaternion) para Flutter
- ✅ Gestão de lifecycle (dispose)

### 3. **Integração MainActivity** (`android/app/src/main/kotlin/.../MainActivity.kt`)
- ✅ `GeospatialManager` registrado no `configureFlutterEngine`
- ✅ Cleanup no `onDestroy()`

### 4. **Dependências Android** (`android/app/build.gradle.kts`)
- ✅ ARCore SDK 1.45.0 adicionado

### 5. **AndroidManifest** (`android/app/src/main/AndroidManifest.xml`)
- ✅ Meta-data `com.google.ar.core` = required
- ✅ Meta-data `com.google.android.geo.API_KEY` configurado (placeholder)

---

## 🔧 Passos para completar a implementação

### PASSO 1: Obter Google Maps API Key (5 minutos)

1. Aceder https://console.cloud.google.com
2. Criar novo projeto (ou usar existente): "HouseAR"
3. Navegar: **APIs & Services** → **Library**
4. Procurar e habilitar **"ARCore API"** (GRATUITO!)
5. Navegar: **APIs & Services** → **Credentials**
6. Clicar **"Create Credentials"** → **"API Key"**
7. Copiar a chave gerada
8. (Opcional) Restringir chave:
   - Clicar no nome da chave
   - **Application restrictions**: Android apps
   - Adicionar package name: `com.housear.house_ar`
   - Salvar

9. **Editar `android/app/src/main/AndroidManifest.xml`:**
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="SUA_CHAVE_AQUI" />  <!-- ← Substituir -->
   ```

### PASSO 2: Recriar `lib/screens/ar_house_screen.dart`

Criar ficheiro com código:

```dart
import 'dart:convert';
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
import '../providers/ar_providers.dart';
import '../models/house_model_config.dart';
import '../services/geospatial_service.dart';

class ARHouseScreen extends ConsumerStatefulWidget {
  const ARHouseScreen({super.key});

  @override
  ConsumerState<ARHouseScreen> createState() => _ARHouseScreenState();
}

class _ARHouseScreenState extends ConsumerState<ARHouseScreen> {
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
        title: const Text('HouseAR - Geospatial'),
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
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isModelPlaced ? Icons.check_circle : Icons.gps_fixed,
                      color: isModelPlaced ? Colors.green : Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isModelPlaced
                          ? '🌍 Modelo posicionado com ARCore Geospatial!'
                          : 'Aguarde... Inicializando ARCore Geospatial API',
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
                                '📍 ${data['lat']}, ${data['lon']}',
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
                        return const CircularProgressIndicator();
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
  ) {
    print('🎬 AR View criada!');

    ref.read(arSessionManagerProvider.notifier).state = arSessionManager;
    ref.read(arObjectManagerProvider.notifier).state = arObjectManager;
    ref.read(arAnchorManagerProvider.notifier).state = arAnchorManager;

    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: false,
    );
    arObjectManager.onInitialize();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _placeModelWithGeospatial();
    });
  }

  Future<void> _placeModelWithGeospatial() async {
    print('🌍 Iniciando ARCore Geospatial API');
    
    try {
      final jsonString = await rootBundle.loadString('assets/house_config.json');
      final config = HouseModelConfig.fromJson(jsonDecode(jsonString));

      if (config.gpsCoordinates == null) {
        throw Exception('GPS coordinates não configuradas');
      }

      final initialized = await GeospatialService.initializeGeospatial();
      if (!initialized) throw Exception('Geospatial init falhou');

      final vpsInfo = await GeospatialService.checkVPSAvailability();
      print('VPS disponível: ${vpsInfo['available']}');

      if (vpsInfo['available'] != true) {
        await Future.delayed(const Duration(seconds: 3));
        final retry = await GeospatialService.checkVPSAvailability();
        if (retry['available'] != true) {
          throw Exception('VPS não disponível');
        }
      }

      final anchor = await GeospatialService.createEarthAnchor(
        latitude: config.gpsCoordinates![0],
        longitude: config.gpsCoordinates![1],
        altitude: config.altitude,
        rotationDegrees: config.rotationDegrees,
      );

      if (anchor['success'] != true) throw Exception('Anchor criação falhou');

      final position = vector.Vector3(
        anchor['positionX'] as double,
        anchor['positionY'] as double,
        anchor['positionZ'] as double,
      );

      final quaternion = vector.Quaternion(
        anchor['rotationX'] as double,
        anchor['rotationY'] as double,
        anchor['rotationZ'] as double,
        anchor['rotationW'] as double,
      );

      final transform = vector.Matrix4.compose(
        position,
        quaternion,
        vector.Vector3.all(config.scale),
      );

      final node = ARNode(
        type: config.nodeType == 'webGLB' ? NodeType.webGLB : NodeType.localGLTF2,
        uri: config.modelUri,
        transformation: transform,
      );

      final result = await ref.read(arObjectManagerProvider)?.addNode(node);
      
      if (result == true) {
        ref.read(houseNodeProvider.notifier).state = node;
        ref.read(isModelPlacedProvider.notifier).state = true;
        print('✅ Modelo colocado com Geospatial!');
      }

    } catch (e) {
      print('❌ Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadGpsInfo() async {
    try {
      final json = await rootBundle.loadString('assets/house_config.json');
      final config = HouseModelConfig.fromJson(jsonDecode(json));
      return {
        'lat': config.gpsCoordinates?[0].toStringAsFixed(6) ?? 'N/A',
        'lon': config.gpsCoordinates?[1].toStringAsFixed(6) ?? 'N/A',
        'alt': config.altitude.toStringAsFixed(1),
      };
    } catch (e) {
      return {'lat': 'Erro', 'lon': '', 'alt': '0'};
    }
  }

  Future<void> _resetModel() async {
    final node = ref.read(houseNodeProvider);
    if (node != null) {
      await ref.read(arObjectManagerProvider)?.removeNode(node);
      ref.read(houseNodeProvider.notifier).state = null;
      ref.read(isModelPlacedProvider.notifier).state = false;
    }
  }
}
```

### PASSO 3: Executar no dispositivo

```powershell
flutter clean
flutter pub get
flutter run
```

---

## 📊 O que acontece no runtime

1. **App inicia** → `_onARViewCreated()` chamado
2. **Após 5s** → `_placeModelWithGeospatial()` executado
3. **Geospatial init** → Kotlin cria ARCore Session com ENABLED mode
4. **VPS check** → Verifica se localização tem cobertura VPS
5. **Earth Anchor** → Kotlin chama `earth.createAnchor(38.758, -9.272, 170, quat)`
6. **Pose retornado** → Position (X,Y,Z) e Quaternion (X,Y,Z,W) via MethodChannel
7. **ARNode criado** → Flutter usa transformation matrix com pose
8. **Modelo aparece** → No local GPS REAL configurado!

---

## 🌍 Cobertura VPS em Portugal

✅ **Lisboa**: Cobertura completa  
✅ **Porto**: Cobertura completa  
⚠️ **Zonas rurais**: Limitado (fallback para GPS normal)

Verificar cobertura: https://developers.google.com/ar/data/geospatial-api-coverage

---

## 🐛 Troubleshooting

### Erro: "ARCore não instalado"
- Dispositivo precisa de ARCore instalado da Play Store
- Verificar em Settings → Apps → "Google Play Services for AR"

### Erro: "VPS não disponível"
- Localização pode não ter cobertura VPS
- Tentar em Lisboa ou Porto (centro cidade)
- Aguardar 10-20 segundos para tracking estabilizar

### Erro: "API_KEY inválida"
- Verificar se chave está correta no AndroidManifest.xml
- Verificar se "ARCore API" está habilitada no Google Cloud Console

### Objeto não aparece
- Verificar logs: posição (X,Y,Z) deve ser não-zero
- Se X=Y=Z=0, anchor não foi criado corretamente
- Aumentar delay de 5s para 10s se tracking for lento

---

## 💰 Custos

✅ **TOTALMENTE GRATUITO**
- ARCore Geospatial API: $0
- Sem limites de requisições
- Sem necessidade de billing ativado

---

## 📝 Próximos passos (opcional)

1. **Persistir anchors** - Salvar anchor IDs para reload
2. **UI melhorada** - Mostrar accuracy e VPS status em tempo real
3. **Múltiplos modelos** - Lista de casas com GPS diferentes
4. **Fallback automático** - Se VPS falhar, usar cálculo manual (código antigo)
