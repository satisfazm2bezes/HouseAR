#!/usr/bin/env pwsh
# DIAGNÓSTICO COMPLETO DA APP

param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  DIAGNÓSTICO APP HOUSEAR GEOSPATIAL    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

# 1. CHECK: Dispositivos
Write-Host "📱 [1/6] Verificando dispositivos..." -ForegroundColor Yellow
$devicesJson = flutter devices --machine 2>$null | Out-String
try {
    $devices = $devicesJson | ConvertFrom-Json
    $androidDevices = $devices | Where-Object { $_.platform -eq 'android' -and $_.emulator -eq $false }
    
    if ($androidDevices.Count -eq 0) {
        Write-Host "❌ NENHUM DISPOSITIVO ANDROID FÍSICO CONECTADO!" -ForegroundColor Red
        Write-Host "`n💡 SOLUÇÃO:" -ForegroundColor Yellow
        Write-Host "   1. Conecta o telemóvel via USB" -ForegroundColor White
        Write-Host "   2. Ativa 'USB Debugging' nas Developer Options" -ForegroundColor White
        Write-Host "   3. Aceita o prompt 'Allow USB debugging' no telemóvel" -ForegroundColor White
        Write-Host "   4. Corre este script novamente`n" -ForegroundColor White
        exit 1
    }
    
    $device = $androidDevices[0]
    $deviceId = $device.id
    $deviceName = $device.name
    Write-Host "✅ Dispositivo encontrado: $deviceName" -ForegroundColor Green
    Write-Host "   ID: $deviceId`n" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Erro ao ler dispositivos" -ForegroundColor Red
    exit 1
}

# 2. CHECK: Permissões AndroidManifest
Write-Host "🔐 [2/6] Verificando permissões no AndroidManifest..." -ForegroundColor Yellow
$manifestPath = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw
    $permissions = @(
        @{Name="CAMERA"; Required=$true},
        @{Name="ACCESS_FINE_LOCATION"; Required=$true},
        @{Name="ACCESS_COARSE_LOCATION"; Required=$true}
    )
    
    $allOk = $true
    foreach ($perm in $permissions) {
        if ($manifest -match "android.permission.$($perm.Name)") {
            Write-Host "   ✅ $($perm.Name)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $($perm.Name) FALTA!" -ForegroundColor Red
            $allOk = $false
        }
    }
    
    if (-not $allOk) {
        Write-Host "`n❌ Permissões em falta no AndroidManifest.xml!" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
} else {
    Write-Host "❌ AndroidManifest.xml não encontrado!" -ForegroundColor Red
    exit 1
}

# 3. CHECK/BUILD: APK
if (-not $SkipBuild) {
    Write-Host "🔨 [3/6] Building APK (pode demorar 1-2 min)..." -ForegroundColor Yellow
    
    $buildOutput = flutter build apk --debug 2>&1 | Out-String
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Build SUCCESS`n" -ForegroundColor Green
    } else {
        Write-Host "❌ BUILD FALHOU!" -ForegroundColor Red
        Write-Host "`nOutput:" -ForegroundColor Yellow
        Write-Host $buildOutput
        exit 1
    }
} else {
    Write-Host "⏭️  [3/6] Skipping build (usar APK existente)`n" -ForegroundColor Gray
}

# 4. INSTALL: App
Write-Host "📦 [4/6] Instalando app no dispositivo..." -ForegroundColor Yellow

# Uninstall primeiro (limpar)
flutter install -d $deviceId --uninstall-only 2>$null | Out-Null

# Install fresh
$installOutput = flutter install -d $deviceId 2>&1 | Out-String

if ($installOutput -match "Installing.*app.*apk" -or $LASTEXITCODE -eq 0) {
    Write-Host "✅ App instalada com sucesso`n" -ForegroundColor Green
} else {
    Write-Host "❌ Instalação falhou!" -ForegroundColor Red
    Write-Host $installOutput
    exit 1
}

# 5. LOGS: Setup monitoring
Write-Host "📝 [5/6] Preparando captura de logs..." -ForegroundColor Yellow

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "diagnostic_$timestamp.log"

Write-Host "✅ Logs serão salvos em: $logFile`n" -ForegroundColor Green

# 6. RUN: Launch app
Write-Host "🚀 [6/6] LANÇANDO APP..." -ForegroundColor Yellow
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  APP A CORRER - MONITORIZAR SAÍDA ABAIXO              ║" -ForegroundColor Cyan
Write-Host "║  Pressiona 'q' para sair ou Ctrl+C para terminar      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# CRITICAL: Procurar por erros específicos
Write-Host "🔍 A PROCURAR:" -ForegroundColor Yellow
Write-Host "   • ArGeospatialView logs (Kotlin)" -ForegroundColor Gray
Write-Host "   • AR_ERROR_MISSING_GL_CONTEXT" -ForegroundColor Gray
Write-Host "   • Type cast exceptions" -ForegroundColor Gray
Write-Host "   • VPS status updates" -ForegroundColor Gray
Write-Host "   • Crashes / Fatal exceptions`n" -ForegroundColor Gray

# Launch com full verbose
flutter run -d $deviceId --verbose 2>&1 | Tee-Object -FilePath $logFile

# ANÁLISE FINAL
Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  ANÁLISE DE LOGS                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

if (Test-Path $logFile) {
    $logContent = Get-Content $logFile -Raw
    
    # Procurar por erros críticos
    $criticalErrors = @(
        @{Pattern="AR_ERROR_MISSING_GL_CONTEXT"; Message="❌ Erro GL Context (ARCore precisa GLSurfaceView)"},
        @{Pattern="type.*is not a subtype of type.*Map"; Message="❌ Type cast error (Map serialization)"},
        @{Pattern="camera permission.*not granted"; Message="❌ Permissão CAMERA negada"},
        @{Pattern="FATAL EXCEPTION"; Message="❌ CRASH - Exception fatal"},
        @{Pattern="AndroidRuntime.*FATAL"; Message="❌ CRASH - Runtime fatal"},
        @{Pattern="Unable to acquire a buffer"; Message="⚠️  Warning: ImageReader buffer issue"}
    )
    
    $foundErrors = $false
    foreach ($error in $criticalErrors) {
        if ($logContent -match $error.Pattern) {
            Write-Host $error.Message -ForegroundColor Red
            $foundErrors = $true
            
            # Mostrar contexto
            $matches = Select-String -Path $logFile -Pattern $error.Pattern -Context 2,2 | Select-Object -First 3
            foreach ($match in $matches) {
                Write-Host "   Linha $($match.LineNumber):" -ForegroundColor Gray
                Write-Host "   $($match.Line)`n" -ForegroundColor DarkRed
            }
        }
    }
    
    # Procurar por SUCCESS indicators
    if ($logContent -match "ArGeospatialView criado") {
        Write-Host "✅ PlatformView criado com sucesso" -ForegroundColor Green
    }
    
    if ($logContent -match "Surface criada|onSurfaceCreated") {
        Write-Host "✅ GLSurfaceView inicializado" -ForegroundColor Green
    }
    
    if ($logContent -match "ARCore.*Geospatial inicializado") {
        Write-Host "✅ ARCore Session criada" -ForegroundColor Green
    }
    
    if (-not $foundErrors) {
        Write-Host "`n✅ NENHUM ERRO CRÍTICO ENCONTRADO!" -ForegroundColor Green
        Write-Host "   Se a app crashou, verifica:" -ForegroundColor Yellow
        Write-Host "   1. Logs completos em: $logFile" -ForegroundColor White
        Write-Host "   2. Se o ecrã ficou preto = normal (sem camera rendering ainda)" -ForegroundColor White
        Write-Host "   3. Se apareceu overlay com status = funcionando!`n" -ForegroundColor White
    }
    
    Write-Host "`n📄 Log completo salvo em: $logFile" -ForegroundColor Cyan
    
} else {
    Write-Host "❌ Ficheiro de log não foi criado!" -ForegroundColor Red
}

Write-Host "`n✅ DIAGNÓSTICO COMPLETO!`n" -ForegroundColor Green
