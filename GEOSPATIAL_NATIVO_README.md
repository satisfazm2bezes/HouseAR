# HouseAR - Geospatial AR Nativo

**Implementação nativa reutilizável** de ARCore Geospatial API para colocar modelos 3D em coordenadas GPS EXATAS.

## 🎯 Funcionalidades

- ✅ **Precisão VPS**: 1-5 metros (vs 10-20m do GPS normal)
- ✅ **Sem calibração manual**: Não precisa apontar para norte
- ✅ **Múltiplos objetos**: Suporta array de modelos em diferentes GPS
- ✅ **Reutilizável**: Código pode ser portado para outros projetos facilmente
- ✅ **Android + iOS**: Arquitetura preparada para ambas plataformas

## 📱 Como Usar

### 1. Configure GPS do modelo

Edite `assets/house_config.json`:

```json
{
  "modelUri": "https://modelviewer.dev/shared-assets/models/glTF-Sample-Assets/Models/Duck/glTF-Binary/Duck.glb",
  "gpsCoordinates": [38.758253, -9.272492],
  "altitude": 170.0,
  "rotationDegrees": 0.0,
  "scale": 1.0
}
```

### 2. Execute o app

```bash
flutter run
```

### 3. Aguarde VPS inicializar

- App mostra "Inicializando VPS..."
- ARCore precisa de 5-30 segundos para conectar ao VPS
- Quando pronto: "VPS ativo! Posição: ..."
- Modelo é colocado automaticamente

## 🔧 API Nativa (Kotlin)

### Inicializar Geospatial

```dart
final result = await GeospatialARService.initialize();
// Retorna: { success: true, latitude, longitude, altitude, accuracy }
```

### Adicionar Objeto

```dart
await GeospatialARService.addObject(
  id: 'my_object',
  latitude: 38.758253,
  longitude: -9.272492,
  altitude: 170.0,
  modelUri: 'assets/models/house.glb',
  rotation: 45.0,  // graus
  scale: 1.5,
);
```

### Remover Objeto

```dart
await GeospatialARService.removeObject('my_object');
```

### Verificar Status VPS

```dart
final status = await GeospatialARService.getStatus();
print(status.available);  // VPS está ativo?
print(status.horizontalAccuracy);  // Precisão em metros
print(status.hasVPSPrecision);  // <5m = VPS, >10m = GPS apenas
```

## 📂 Estrutura do Código

### Android (Kotlin Nativo)

```
android/app/src/main/kotlin/com/housear/house_ar/
├── MainActivity.kt              # MethodChannel setup
└── GeospatialARManager.kt       # ARCore Geospatial logic
```

**GeospatialARManager** - Manager reutilizável:
- `initialize()`: Cria Session com Geospatial ENABLED
- `addObject()`: Cria Earth Anchor em GPS
- `removeObject()`: Remove anchor por ID
- `getStatus()`: Retorna tracking state + posição

### Flutter (Dart)

```
lib/
├── services/
│   └── geospatial_ar_service.dart  # MethodChannel wrapper
└── screens/
    └── geospatial_ar_screen.dart   # UI example
```

## 🚀 Portar para Outro Projeto

### 1. Copiar código nativo

```bash
# Android
cp -r android/app/src/main/kotlin/com/housear/house_ar/*.kt novo_projeto/android/app/src/main/kotlin/

# iOS (TODO - implementar em Swift)
```

### 2. Copiar serviço Flutter

```bash
cp lib/services/geospatial_ar_service.dart novo_projeto/lib/services/
```

### 3. Atualizar package name

Em `GeospatialARManager.kt` e `MainActivity.kt`:
```kotlin
package com.seuprojeto.novoapp  // Alterar isto
```

### 4. Adicionar dependências

`android/app/build.gradle.kts`:
```kotlin
dependencies {
    implementation("com.google.ar:core:1.45.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

### 5. Configurar API Key

`android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="SUA_API_KEY_AQUI"/>
```

## 🔑 Google Cloud Setup

1. Aceda https://console.cloud.google.com/
2. Crie novo projeto ou use existente
3. Ative APIs:
   - ✅ ARCore API
   - ✅ Maps SDK for Android
4. Crie API Key (Credentials → Create credentials → API key)
5. Adicione ao AndroidManifest.xml (ver acima)

## 📊 Precisão Esperada

| Condição | Precisão | Tempo Init |
|----------|----------|------------|
| **VPS Ativo** | 1-5m | 5-30s |
| GPS apenas | 10-20m | <5s |
| Sem sinal | Não funciona | - |

**VPS requer**:
- ✅ Local aberto (exteriores ou grandes interiores)
- ✅ Boa visibilidade (céu/horizonte)
- ✅ GPS ativo
- ✅ Internet (para baixar mapa VPS)

## 🛠️ Troubleshooting

### "Earth state: ERROR_RESOURCE_EXHAUSTED"
- **Problema**: Quota da API excedida
- **Solução**: Verificar Google Cloud Console → Quotas

### "Earth tracking: PAUSED"  (não muda para TRACKING)
- **Problema**: VPS não consegue localizar
- **Soluções**:
  1. Mover device lentamente (pan câmera)
  2. Ir para local mais aberto
  3. Aguardar até 30s
  4. Verificar cobertura VPS: https://developers.google.com/ar/data/geospatial

### Modelo não aparece
- Verificar path do .glb está correto
- Escala pode estar muito pequena (aumentar `scale`)
- GPS coordenadas corretas? (usar Google Maps para confirmar)

## 📄 Licença

Este código é parte do projeto HouseAR mas pode ser reutilizado livremente.

---

**Criado por**: [Tu] usando ARCore Geospatial API  
**Data**: Outubro 2025  
**Tecnologias**: Flutter + Kotlin + ARCore 1.45.0
