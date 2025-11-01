# 📱 WiFi Debugging - Desenvolvimento sem cabo USB

## Conectar dispositivo Android via WiFi

### 1. Preparar o telemóvel

1. Abre **Definições** → **Opções de Programador**
2. Ativa **Depuração USB** (se ainda não estiver ativo)
3. Ativa **Depuração sem fios** (Wireless debugging)
4. Toca em **Emparelhar dispositivo com código de emparelhamento**
5. Anota o **IP e porta** que aparecem (ex: `192.168.68.100:39767`)

### 2. Conectar no PC

No PowerShell/CMD:

```powershell
# Conectar ao dispositivo via WiFi
D:\flutter\Android\sdk\platform-tools\adb.exe connect [IP:PORTA]

# Exemplo:
D:\flutter\Android\sdk\platform-tools\adb.exe connect 192.168.68.100:39767
```

### 3. Verificar conexão

```powershell
# Ver dispositivos conectados
D:\flutter\Android\sdk\platform-tools\adb.exe devices

# Deves ver algo como:
# 192.168.68.100:39767    device
```

### 4. Executar a app

Agora podes desligar o cabo USB! A app vai instalar via WiFi:

```powershell
# Executar em modo release
flutter run --release

# OU build e instalar
flutter build apk --release
flutter install
```

## 🔧 Troubleshooting

### Dispositivo offline

Se aparecer `offline`:

```powershell
# Reiniciar servidor ADB
D:\flutter\Android\sdk\platform-tools\adb.exe kill-server
D:\flutter\Android\sdk\platform-tools\adb.exe start-server

# Reconectar
D:\flutter\Android\sdk\platform-tools\adb.exe connect [IP:PORTA]
```

### Porta muda frequentemente

A porta WiFi muda cada vez que reativas "Depuração sem fios". **Anota sempre a porta nova!**

### USB desconecta durante build

Se o cabo USB desconectar durante `flutter run`:

1. Usa WiFi debugging (instruções acima)
2. OU instala manualmente depois:
   ```powershell
   D:\flutter\Android\sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-release.apk
   ```

## ✅ Vantagens WiFi Debugging

- 📱 Podes mover o telemóvel livremente (essencial para AR!)
- 🔌 Não tens problemas com cabo a desconectar
- ⚡ Instalação mais rápida após primeira conexão
- 🏃‍♂️ Perfeito para testar AR outdoor

## 📝 Alias útil (opcional)

Adiciona ao teu perfil PowerShell (`$PROFILE`):

```powershell
function adb { D:\flutter\Android\sdk\platform-tools\adb.exe $args }
```

Depois podes usar simplesmente:

```powershell
adb connect 192.168.68.100:39767
adb devices
```
