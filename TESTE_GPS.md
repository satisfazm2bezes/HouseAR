# 🧪 Como Testar o Posicionamento GPS

## ⚡ Setup Rápido

### 1. Configure as Coordenadas

Edite `assets/house_config.json`:

```json
{
  "modelUri": "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Binary/Duck.glb",
  "nodeType": "webGLB",
  "gpsCoordinates": [38.7223, -9.1393],  // ← SUAS COORDENADAS AQUI
  "scale": 50,
  "rotationDegrees": 0.0,
  "altitude": 100,  // ← ALTITUDE EM METROS (nível do mar)
  "name": "Objeto Teste"
}
```

### 2. Obtenha Coordenadas GPS

**Opção A: Google Maps**
1. Abra [Google Maps](https://maps.google.com)
2. Clique com botão direito no local desejado
3. Clique "Copiar coordenadas" (ex: `38.7223, -9.1393`)

**Opção B: Próximo de Você (Teste Rápido)**
1. Abra Google Maps no telefone
2. Clique no ponto azul (sua localização)
3. Copie as coordenadas mostradas
4. Some **0.001** à latitude (≈111 metros ao Norte)

Exemplo:
```
Sua posição: 38.7223, -9.1393
Alvo de teste: 38.7233, -9.1393  (111m ao Norte)
```

### 3. Execute no Dispositivo

```bash
flutter run -d SEU_DISPOSITIVO
```

## 📋 Passo a Passo do Teste

### Ao Abrir o App:

1. **⚠️ IMPORTANTE**: Segure o telefone na horizontal
2. **🧭 Aponte para NORTE** antes do modelo carregar
   - Use Google Maps para ver onde é Norte
   - A seta azul indica sua direção
3. **⏱️ Aguarde 2 segundos**: O modelo será colocado automaticamente

### O que Deve Acontecer:

✅ **Mensagem verde aparece**:
```
Objeto Teste colocado!
📍 Distância: 111.2m
🧭 Direção: Norte (0°)
⬆️ Altitude: 100.0m (+20.0m vs você)
```

✅ **Logs no terminal** (exemplo):
```
📍 POSIÇÃO USUÁRIO:
  Lat: 38.7223
  Lon: -9.1393
  Alt: 80.0m

🏠 POSIÇÃO ALVO (config):
  Lat: 38.7233
  Lon: -9.1393
  Alt: 100m

📐 CÁLCULOS:
  Distância horizontal: 111.20m
  Bearing (direção): 0.0° (Norte)
  Diferença altitude: +20.0m

🎯 POSIÇÃO AR (X, Y, Z):
  X: 0.00m (Leste-Oeste)
  Y: 20.00m (acima de você)
  Z: -111.20m (ao Norte, -Z = frente)
```

### Se o Objeto Não Aparecer Visível:

1. **Está muito longe?**
   - Reduza a distância nas coordenadas GPS
   - Teste com 50-100m primeiro

2. **Altitude muito diferente?**
   - Ajuste `altitude` no config
   - Tente altitude similar à sua (veja no Google Maps)

3. **Escala muito pequena/grande?**
   - Ajuste `scale` no config
   - Tente valores entre 10-100

4. **Não apontou para Norte?**
   - Feche e reabra o app
   - Aponte EXATAMENTE para Norte desta vez

## 🎯 Testes Recomendados

### Teste 1: Objeto ao Norte (111m)
```json
{
  "gpsCoordinates": [SUA_LAT + 0.001, SUA_LON],
  "altitude": SUA_ALT + 10,
  "scale": 50
}
```
**Resultado esperado**: Objeto 111m ao Norte, 10m acima

### Teste 2: Objeto a Leste (111m)
```json
{
  "gpsCoordinates": [SUA_LAT, SUA_LON + 0.001],
  "altitude": SUA_ALT,
  "scale": 50
}
```
**Resultado esperado**: Objeto 111m a Leste (direita)

### Teste 3: Objeto Próximo (25m ao Nordeste)
```json
{
  "gpsCoordinates": [SUA_LAT + 0.00022, SUA_LON + 0.00022],
  "altitude": SUA_ALT + 5,
  "scale": 20
}
```
**Resultado esperado**: Objeto 25m ao Nordeste, 5m acima

## ❓ Troubleshooting

| Problema | Solução |
|----------|---------|
| "Permission denied" | Aceite permissões de GPS no Android |
| Objeto não aparece | Verifique logs, aumente `scale`, reduza distância |
| Direção errada | Certifique-se que apontou para Norte ao iniciar |
| Altitude errada | GPS vertical é impreciso, use altitude conhecida |
| App crasha | Verifique modelo GLB é válido (use Duck.glb para teste) |

## 📊 Verificar Precisão

Compare a mensagem do app com cálculos manuais:

1. **Distância**: Use [Calculadora de Distância GPS](https://www.movable-type.co.uk/scripts/latlong.html)
2. **Bearing**: Mesma calculadora mostra direção
3. **Altitude**: Google Earth (versão desktop) mostra altitude de qualquer ponto

Se os valores do app coincidirem com a calculadora, o posicionamento está correto! 🎉
