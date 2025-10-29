# Script para monitorizar logs ARCore Geospatial de forma limpa
# Uso: .\watch_logs.ps1

$adb = "D:\flutter\Android\sdk\platform-tools\adb.exe"

Write-Host "🧹 Limpando logs antigos..." -ForegroundColor Yellow
& $adb logcat -c

Write-Host "📱 Monitorizando logs ARCore Geospatial (Ctrl+C para parar)..." -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Filtrar APENAS logs relevantes: Flutter + GeospatialManager + ARCore críticos
& $adb logcat -s `
    "flutter:V" `
    "GeospatialManager:V" `
    "ARCore-Session:I" `
    "ARCore-Earth:I" |
    Where-Object {
        $_ -match "🚀|📡|🌍|📍|✅|❌|⏳|⚠️|🔄|🎯|🔗|VPS|Geospatial|INIT|Earth|Session|GPS"
    } |
    ForEach-Object {
        # Colorir por tipo de mensagem
        if ($_ -match "✅|disponível!") {
            Write-Host $_ -ForegroundColor Green
        } elseif ($_ -match "❌|ERROR|Exception|falhou") {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match "⚠️|WARNING|indisponível") {
            Write-Host $_ -ForegroundColor Yellow
        } elseif ($_ -match "📍|GPS|lat=|lon=") {
            Write-Host $_ -ForegroundColor Cyan
        } else {
            Write-Host $_
        }
    }
