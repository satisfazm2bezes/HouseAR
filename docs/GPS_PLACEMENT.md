# Colocação Automática de Modelos com GPS

## 📍 Como funciona

Em vez de tocar na tela para colocar o modelo, você pode configurar **coordenadas GPS exatas** onde a casa deve aparecer. O app calcula automaticamente a posição relativa ao usuário.

## 🗺️ Configuração do Modelo

### Opção 1: Arquivo JSON

Crie um arquivo `house_config.json` com as coordenadas:

```json
{
  "modelUri": "https://exemplo.com/models/casa.glb",
  "nodeType": "webGLB",
  "gpsCoordinates": [38.736946, -9.142685],
  "scale": 1.5,
  "rotationDegrees": 45.0,
  "altitude": 0.0,
  "name": "Minha Casa"
}
```

**Campos:**
- `modelUri`: URL do arquivo GLB/GLTF
- `gpsCoordinates`: `[latitude, longitude]` onde a casa deve aparecer
- `scale`: Tamanho do modelo (1.0 = tamanho original)
- `rotationDegrees`: Rotação em graus (0-360, 0=Norte)
- `altitude`: **Altitude absoluta em relação ao nível do mar** (metros)
  - Exemplo: Se a casa está a 100m de altitude e você a 50m, o modelo aparecerá 50m acima de você
  - Use Google Earth ou mapas topográficos para obter altitude precisa

### Opção 2: Código direto

```dart
final config = HouseModelConfig(
  modelUri: 'https://exemplo.com/models/casa.glb',
  nodeType: 'webGLB',
  gpsCoordinates: [38.736946, -9.142685], // Lat, Lon
  scale: 1.5,
  rotationDegrees: 45.0,
  altitude: 0.0,
  name: 'Minha Casa',
);
```

## 🧭 Como obter as coordenadas GPS

### Método 1: Google Maps
1. Abra [Google Maps](https://maps.google.com)
2. Clique com botão direito no local exato
3. Clique "Copiar coordenadas"
4. Cole no formato: `[latitude, longitude]`

Exemplo: `38.736946, -9.142685` vira `[38.736946, -9.142685]`

### Método 2: GPS do celular
1. Use o app GPS do dispositivo
2. Vá até o local físico onde quer a casa
3. Anote latitude e longitude

### Método 3: Arquivo KML/KMZ
Se você tem um arquivo `.kml` ou `.kmz` do Google Earth:
```xml
<coordinates>-9.142685,38.736946,0</coordinates>
```
**Atenção:** KML usa lon,lat (invertido!) → converter para `[38.736946, -9.142685]`

## 🔧 Como usar no código

### 1. Carregar configuração do JSON

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

Future<HouseModelConfig> loadHouseConfig() async {
  final jsonString = await rootBundle.loadString('assets/house_config.json');
  final json = jsonDecode(jsonString);
  return HouseModelConfig.fromJson(json);
}
```

### 2. Usar coordenadas GPS para colocar modelo

```dart
// Obter localização atual do usuário
final userPosition = await Geolocator.getCurrentPosition();

// Configuração do modelo
final config = await loadHouseConfig();

if (config.gpsCoordinates != null) {
  // Calcular posição AR relativa
  final arPosition = GpsToArService.gpsToArPosition(
    userPosition.latitude,
    userPosition.longitude,
    userHeading, // Direção da bússola (0-360)
    config.gpsCoordinates![0], // Latitude alvo
    config.gpsCoordinates![1], // Longitude alvo
    config.altitude,
  );

  // Criar ARNode na posição calculada
  final node = ARNode(
    type: NodeType.webGLB,
    uri: config.modelUri,
    scale: Vector3.all(config.scale),
    position: arPosition,
    rotation: Vector4(0, 1, 0, config.rotationDegrees * pi / 180),
  );
  
  await arObjectManager.addNode(node);
}
```

## 📐 Distância e Precisão

- **GPS típico**: ±5-10 metros de precisão
- **GPS com DGPS**: ±1-3 metros
- **Recomendado**: Use para objetos a mais de 10 metros de distância
- **Para precisão máxima**: Combine GPS + detecção de planos AR

## 🎯 Casos de Uso

### 1. Visualizar casa em terreno
```json
{
  "gpsCoordinates": [38.736946, -9.142685],
  "modelUri": "https://exemplo.com/casa-projeto.glb",
  "scale": 1.0,
  "name": "Casa no Lote 42"
}
```

### 2. Tour de arquitetura urbana
```json
{
  "gpsCoordinates": [38.7223, -9.1393],
  "modelUri": "https://exemplo.com/edificio-historico.glb",
  "scale": 2.0,
  "rotationDegrees": 180,
  "name": "Torre de Belém Reconstruída"
}
```

### 3. Múltiplas casas (array de configs)
```json
[
  {
    "gpsCoordinates": [38.736, -9.142],
    "modelUri": "https://exemplo.com/casa1.glb",
    "name": "Casa A"
  },
  {
    "gpsCoordinates": [38.737, -9.143],
    "modelUri": "https://exemplo.com/casa2.glb",
    "name": "Casa B"
  }
]
```

## ⚠️ Limitações

1. **Requer permissão de localização** no Android/iOS
2. **Funciona melhor em áreas abertas** (GPS precisa de céu visível)
3. **Não funciona em ambientes fechados** (use modo manual com tap)
4. **Precisão limitada** para objetos muito próximos (<10m)

## 🔄 Modo Híbrido (Recomendado)

Combine GPS + tap manual:

1. **GPS**: Coloca casa aproximadamente na localização
2. **Gestos AR**: Usuário ajusta posição final com pinch/drag
3. **Salvar ajuste**: Grava offset para próxima vez

```dart
// Posição inicial via GPS
final gpsPosition = GpsToArService.gpsToArPosition(...);

// Usuário ajusta manualmente
final finalPosition = gpsPosition + userAdjustmentOffset;

// Salvar offset para próxima visita
await saveUserAdjustment(config.name, userAdjustmentOffset);
```

## 📚 Próximos passos

1. Implementar `GPSPlacementScreen` para modo GPS automático
2. Adicionar bússola para orientação correta
3. Cache de coordenadas visitadas
4. UI para alternar entre modo manual e GPS
