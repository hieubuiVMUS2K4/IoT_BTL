# Test IoT System Health Check
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   IoT SYSTEM HEALTH CHECK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Test HiveMQ Cloud
Write-Host "1. Testing HiveMQ Cloud..." -ForegroundColor Yellow
$hivemqUrl = "5013cd33cc4841a0b2537c65d64aa6e7.s1.eu.hivemq.cloud"
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.ReceiveTimeout = 3000
    $tcpClient.Connect($hivemqUrl, 8883)
    if ($tcpClient.Connected) {
        Write-Host "   OK - HiveMQ Cloud ONLINE" -ForegroundColor Green
        $tcpClient.Close()
    }
} catch {
    Write-Host "   FAIL - Cannot connect to HiveMQ" -ForegroundColor Red
}

# 2. Test Render.com
Write-Host ""
Write-Host "2. Testing Render.com Server..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://iot-btl-9tr7.onrender.com" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "   OK - Render Server ONLINE" -ForegroundColor Green
    }
} catch {
    Write-Host "   WARN - Render may be sleeping (wake up takes 30s)" -ForegroundColor Yellow
}

# 3. Test Local Server
Write-Host ""
Write-Host "3. Testing Local Server..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 2 -UseBasicParsing
    Write-Host "   OK - Local Server RUNNING" -ForegroundColor Green
} catch {
    Write-Host "   WARN - Local server not running" -ForegroundColor Yellow
    Write-Host "   Run: node NodeJS_Server/server_mqtt.js" -ForegroundColor Gray
}

# 4. Check Flutter
Write-Host ""
Write-Host "4. Checking Flutter..." -ForegroundColor Yellow
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "   OK - Flutter installed" -ForegroundColor Green
} else {
    Write-Host "   FAIL - Flutter not found" -ForegroundColor Red
}

# 5. Check Android SDK
Write-Host ""
Write-Host "5. Checking Android SDK..." -ForegroundColor Yellow
if (Test-Path "C:\Android\cmdline-tools") {
    Write-Host "   OK - Android SDK installed" -ForegroundColor Green
} else {
    Write-Host "   WARN - Android SDK not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run Local Server:" -ForegroundColor White
Write-Host "  cd NodeJS_Server; node server_mqtt.js" -ForegroundColor Gray
Write-Host ""
Write-Host "Run Flutter App:" -ForegroundColor White
Write-Host "  cd FlutterApp; flutter run -d windows" -ForegroundColor Gray
Write-Host ""
Write-Host "Build APK:" -ForegroundColor White
Write-Host "  cd FlutterApp; flutter build apk --release" -ForegroundColor Gray
Write-Host ""
