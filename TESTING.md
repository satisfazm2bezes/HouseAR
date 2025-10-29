# 🔧 COMO TESTAR A APP HOUSEAR

## ⚡ Quick Start

1. **Conecta o telemóvel via USB**
2. **Ativa USB Debugging** (Settings → Developer Options)
3. **Corre o script de diagnóstico**:

```powershell
.\diagnose.ps1
```

O script vai:
- ✅ Verificar dispositivos conectados
- ✅ Validar permissões do AndroidManifest
- ✅ Build APK (1-2 min)
- ✅ Instalar no telemóvel
- ✅ Lançar app com logs completos
- ✅ Analisar erros automaticamente

---

## 📱 O QUE ESPERAR

### ✅ SUCESSO = Verás:
1. **App abre** (pode estar com ecrã preto - NORMAL!)
2. **Overlay com status VPS** aparece em cima
3. **Logs mostram**:
   ```
   ✅ ArGeospatialView criado
   ✅ GLSurfaceView inicializado  
   ✅ ARCore Session criada
   ```

### ❌ ERRO = Verás:
- App crasha imediatamente
- Mensagem de permissões
- Erro nos logs (script mostra automaticamente)

---

## 🔍 ERROS CONHECIDOS & SOLUÇÕES

### ❌ "AR_ERROR_MISSING_GL_CONTEXT"
**Causa**: ARCore precisa de OpenGL context  
**Fix**: ✅ JÁ CORRIGIDO (usamos GLSurfaceView agora)

### ❌ "type '_Map<Object?, Object?>' is not a subtype"
**Causa**: Type cast error no Dart  
**Fix**: ✅ JÁ CORRIGIDO (usamos Map.from() agora)

### ❌ "camera permission not granted"
**Causa**: Permissão CAMERA não concedida  
**Fix**: Abre app, aceita permissão, fecha e abre de novo

### ⚠️ "Unable to acquire a buffer"
**Causa**: Warning normal do ImageReader  
**Fix**: Ignorar (não é crítico)

---

## 🐛 SE CRASHAR

1. **Lê o log gerado**: `diagnostic_YYYYMMDD_HHMMSS.log`
2. **Procura por**:
   - `FATAL EXCEPTION` = crash
   - `AndroidRuntime` = erro runtime
   - Stack trace com `at com.housear...`

3. **Copia o stack trace completo** e cola no chat

---

## 📝 ESTADO ATUAL DO CÓDIGO

### ✅ O QUE ESTÁ IMPLEMENTADO:
- **Native Kotlin PlatformView** (ArGeospatialView.kt)
- **GLSurfaceView** com OpenGL Renderer
- **ARCore Geospatial Session** configurada
- **MethodChannel** para comunicação Dart ↔ Kotlin
- **VPS Status polling** (getVPSStatus cada 2s)
- **Widget Flutter** (GeospatialCameraScreen)

### ❌ O QUE FALTA:
- **Camera rendering visual** (ecrã vai estar PRETO mas sem erro)
- **3D model rendering** (anchor cria mas não aparece)
- **VPS precisa de boa visibilidade** (outdoor funciona melhor)

---

## 🎯 PRÓXIMOS PASSOS

Se a app **NÃO crashar** mas o ecrã ficar **PRETO**:
- ✅ **É ESPERADO!** (ainda não renderizamos a textura da câmera)
- ✅ **Verifica se o overlay de status aparece**
- ✅ **Se aparecer = SUCESSO!** GL Context funciona!

Se **crashar**:
- ❌ Lê o log e procura stack trace
- ❌ Cola aqui para debug

---

## 🚀 COMANDOS ÚTEIS

### Build apenas (sem instalar):
```powershell
flutter build apk --debug
```

### Instalar APK existente (skip build):
```powershell
.\diagnose.ps1 -SkipBuild
```

### Ver apenas logs (app já instalada):
```powershell
flutter attach -d <DEVICE_ID>
```

### Limpar tudo:
```powershell
flutter clean
```

---

## 📊 ESTRUTURA DOS FICHEIROS IMPORTANTES

```
android/app/src/main/kotlin/com/housear/house_ar/
├── ArGeospatialView.kt          ← PlatformView com GLSurfaceView
├── ArGeospatialViewFactory.kt   ← Factory para criar view
└── MainActivity.kt               ← Regista PlatformView

lib/
├── screens/
│   └── geospatial_camera_screen.dart  ← Tela principal AR
└── widgets/
    └── ar_geospatial_camera_view.dart ← Widget PlatformView
```

---

**BOA SORTE! 🍀**
