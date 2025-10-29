#!/usr/bin/env pwsh
# Script para testar app HouseAR com logs completos

Write-Host "🔍 TESTANDO APP HOUSEAR..." -ForegroundColor Cyan

# 1. Verificar dispositivos
Write-Host "`n📱 Dispositivos conectados:" -ForegroundColor Yellow
flutter devices

# 2. Obter device ID
$devices = flutter devices --machine | ConvertFrom-Json
$androidDevice = $devices | Where-Object { $_.platform -eq 'android' } | Select-Object -First 1

if (-not $androidDevice) {
    Write-Host "❌ Nenhum dispositivo Android conectado!" -ForegroundColor Red
    Write-Host "   Conecta o telemóvel via USB e ativa USB Debugging" -ForegroundColor Yellow
    exit 1
}

$deviceId = $androidDevice.id
$deviceName = $androidDevice.name
Write-Host "✅ Usando: $deviceName ($deviceId)" -ForegroundColor Green

# 3. Uninstall app antiga (limpar)
Write-Host "`n🧹 Removendo app antiga..." -ForegroundColor Yellow
flutter install -d $deviceId --uninstall-only 2>$null

# 4. Build e install
Write-Host "`n🔨 Building APK..." -ForegroundColor Yellow
flutter build apk --debug

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build falhou!" -ForegroundColor Red
    exit 1
}

# 5. Install
Write-Host "`n📦 Instalando no dispositivo..." -ForegroundColor Yellow
flutter install -d $deviceId

# 6. Launch com logs
Write-Host "`n🚀 Lançando app e capturando logs..." -ForegroundColor Yellow
Write-Host "   (pressiona Ctrl+C para parar)`n" -ForegroundColor Gray

# Criar arquivo de log
$logFile = "app_test_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Run e capturar TUDO
flutter run -d $deviceId --verbose 2>&1 | Tee-Object -FilePath $logFile

Write-Host "`n📝 Logs salvos em: $logFile" -ForegroundColor Green
