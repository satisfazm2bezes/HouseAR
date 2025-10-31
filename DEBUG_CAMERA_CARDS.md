# Debug: Câmera com Zoom & Cards Invisíveis

## O que foi feito:

### Cards de UI:
1. ✅ `_startStatusPolling()` movido para `initState()` - inicia imediatamente
2. ✅ Logs adicionados em Flutter (`print`) e Kotlin (`Log.d`)
3. ✅ Container do status overlay mudado de gradient para cor sólida (preto 85%)
4. ✅ Labels de cards quando `_status == null`: "AGUARDANDO" e "---"

### Status Polling:
1. ✅ `session?.update()` adicionado em `getVPSStatus()`
2. ✅ Logs detalhados no Kotlin: earthState, trackingState, accuracy
3. ✅ MainActivity redireciona `getStatus` para `ArGeospatialView`

### Câmera Zoom:
1. ✅ Rotação obtida via `getActivity(context).windowManager.defaultDisplay.rotation`
2. ✅ Log detalhado mostrando rotation (0°/90°/180°/270°)
3. ✅ `setDisplayGeometry(rotation, width, height)` chamado corretamente

## Como verificar:

### 1. Verificar Cards Aparecem:
- Abrir app → verificar se há **3 cards** em baixo com fundo preto
- Se não vês cards:
  - Ver logs Flutter: `flutter logs | grep "Status atualizado"`
  - Ver logs Android: `adb logcat | grep "ArGeospatialView"`

### 2. Verificar Status Polling:
```bash
# Filtrar logs Flutter
flutter logs | grep "📊 Status"

# Deve mostrar a cada 1 segundo:
📊 Status atualizado: ENABLED, TRACKING, 2.3m
```

### 3. Verificar Rotação da Câmera:
```bash
# Ver log de rotação
adb logcat | grep "Surface changed"

# Deve mostrar algo como:
📐 Surface changed: 1080x2400, rotation=0 (PORTRAIT (0°))
# ou para landscape:
📐 Surface changed: 2400x1080, rotation=1 (LANDSCAPE (90°))
```

### 4. Verificar Earth Status:
```bash
# Ver status completo
adb logcat | grep "📍 Status"

# Deve mostrar:
📍 Status: earthState=ENABLED, trackingState=TRACKING, accuracy=2.3m
```

## Possíveis problemas:

### Cards não aparecem:
- **Causa 1**: `_status` é null porque `getStatus()` falha
  - Verificar: Log "❌ Erro polling" no Flutter
  - Solução: Ver exception no log
  
- **Causa 2**: ArGeospatialView não foi criado
  - Verificar: Log "🎬 ArGeospatialView criado" no Android
  - Solução: Ver se AndroidView está sendo instanciado

- **Causa 3**: Container overlay fora do ecrã
  - Verificar: No DevTools, ver se Positioned(bottom: 0) está visível
  - Solução: Ajustar SafeArea

### Precisão 999.0:
- **Causa**: `session?.earth` é null
  - Verificar: Log "⚠️ Earth é null" no Android
  - Solução: ARCore session não inicializou → ver erro de permissão/API key

### Câmera com zoom:
- **Causa 1**: Rotação errada
  - Verificar: Log mostra rotation=0 quando device está em landscape
  - Solução: Forçar orientação no AndroidManifest.xml

- **Causa 2**: `transformCoordinates2d` não ajusta UV corretamente
  - Verificar: BackgroundRenderer está a desenhar?
  - Solução: Ver se há erro de shader compilation

- **Causa 3**: Aspect ratio da viewport errado
  - Verificar: Log "Surface changed" mostra width/height invertidos
  - Solução: Ajustar glViewport

## Próximos passos:

1. Conectar device Android
2. Executar `flutter run`
3. Copiar **TODOS os logs** (Flutter + Android)
4. Enviar logs para análise

## Comandos úteis:

```bash
# Ver logs combinados
flutter logs & adb logcat -s ArGeospatialView:D BackgroundRenderer:D CubeRenderer:D

# Ver apenas erros
adb logcat *:E | grep -i "ar\|geospatial"

# Limpar logcat antes de testar
adb logcat -c
```
