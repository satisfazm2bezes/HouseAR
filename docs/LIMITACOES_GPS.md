# Posicionamento GPS no ARCore

## ✅ Solução Implementada (Coordenadas Geográficas Absolutas)

O app usa um sistema de **coordenadas geográficas absolutas** para posicionar objetos 3D:

### Como funciona:

1. **Converte GPS para metros**:
   - 1° latitude ≈ 111,320 metros (constante)
   - 1° longitude ≈ 111,320 × cos(latitude) metros
   
2. **Calcula deslocamento relativo**:
   - X = Diferença de longitude em metros (Leste-Oeste)
   - Y = Diferença de altitude em metros (acima/abaixo)
   - Z = Diferença de latitude em metros (Norte-Sul)

3. **Coloca objeto no ARCore**:
   - Posição absoluta baseada nas coordenadas GPS
   - **REQUER**: Câmera apontando para Norte ao iniciar

### 📱 Como Usar Corretamente:

1. **Antes de abrir o app**:
   - Abra Google Maps ou app de navegação
   - Identifique qual direção é **Norte** ⬆️

2. **Ao abrir o HouseAR**:
   - **APONTE A CÂMERA PARA NORTE** 🧭
   - Mantenha o telefone na horizontal
   - Aguarde 2 segundos

3. **App posiciona automaticamente**:
   - Lê coordenadas do `house_config.json`
   - Calcula posição relativa
   - Coloca modelo na direção/distância corretas

4. **Verifique a mensagem**:
   ```
   Casa colocada!
   📍 Distância: 50.1m
   🧭 Direção: Sudoeste (240°)
   ⬆️ Altitude: 85.0m (+35.0m vs você)
   ```

### 🎯 Precisão Esperada:

| Aspecto | Precisão |
|---------|----------|
| Distância horizontal | ±5-10m (GPS padrão) |
| Direção | ±15° (se apontar bem para Norte) |
| Altitude | ±10-20m (GPS vertical menos preciso) |

### ⚠️ Limitações:

1. **Depende da orientação inicial**:
   - Se não apontar para Norte, o objeto aparecerá rodado
   - Erro de 45° na orientação = objeto aparece 45° rodado

2. **GPS não é perfeito**:
   - Precisão típica: 5-10 metros
   - Edifícios/árvores degradam sinal
   - Melhor ao ar livre com céu limpo

3. **Altitude GPS imprecisa**:
   - Erro vertical pode chegar a 20m
   - Melhor usar altitude conhecida (mapas topográficos)

## 🚀 Solução Profissional (Futura)

Para posicionamento GPS **preciso e automático**, seria necessário usar:

### ARCore Geospatial API

Google lançou a **Geospatial API** que permite AR com coordenadas GPS reais usando:
- Google Street View 3D mapping
- Visual Positioning Service (VPS)
- Requer Google Maps API key

**Implementação:**
```dart
// Exemplo (requer ar_flutter_plugin com suporte a Geospatial)
ARGeospatialController.enable(
  googleMapsApiKey: 'YOUR_API_KEY'
);

// Colocar objeto em lat/lon/alt reais
ARGeospatialAnchor(
  latitude: 38.7582,
  longitude: -9.2724,
  altitude: 85.0,
);
```

**Limitações da Geospatial API:**
- ❌ Requer Google Maps API key (paga após quota grátis)
- ❌ Funciona apenas em áreas mapeadas pelo Google Street View
- ❌ Requer conexão à internet
- ❌ Suporte limitado no `ar_flutter_plugin_2`

## 📊 Precisão Atual vs Ideal

| Aspecto | Solução Atual | Com Geospatial API |
|---------|---------------|---------------------|
| Distância | ✅ Precisa (GPS) | ✅ Precisa |
| Direção | ⚠️ Aproximada (assume Norte) | ✅ Precisa (VPS) |
| Altitude | ✅ Precisa (GPS) | ✅ Precisa |
| Facilidade | ✅ Sem setup | ❌ Requer API key |
| Offline | ✅ Funciona | ❌ Requer internet |

## 🎯 Recomendação

Para **protótipo/MVP**: Use a solução atual e instrua os utilizadores a apontar para Norte.

Para **produção profissional**: Implemente ARCore Geospatial API com Google Maps Platform.

## 🔗 Links Úteis

- [ARCore Geospatial API](https://developers.google.com/ar/develop/geospatial)
- [Google Maps Platform Pricing](https://mapsplatform.google.com/pricing/)
- [Visual Positioning Service (VPS)](https://developers.google.com/ar/develop/geospatial/vps)
