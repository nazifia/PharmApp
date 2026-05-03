@echo off
setlocal enabledelayedexpansion

:: Get local IPv4 (first non-loopback)
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set "RAW=%%a"
    set "RAW=!RAW: =!"
    if not "!RAW!"=="127.0.0.1" (
        if not defined LOCAL_IP set "LOCAL_IP=!RAW!"
    )
)

if not defined LOCAL_IP (
    echo ERROR: Could not detect local IP. Check network connection.
    pause
    exit /b 1
)

set "PORT=8000"
set "SERVER_URL=http://%LOCAL_IP%:%PORT%/api"

echo ============================================
echo   PharmApp LAN Server
echo ============================================
echo   Local IP  : %LOCAL_IP%
echo   Server URL: %SERVER_URL%
echo ============================================
echo.
echo   On each device, EITHER:
echo   [A] Settings ^> Network ^> Auto-discover  (tap once)
echo   [B] Settings ^> Network ^> Server URL
echo       Enter: %SERVER_URL%
echo.
echo   Press Ctrl+C to stop server
echo ============================================
echo.

call venv\Scripts\activate.bat

:: Start mDNS broadcaster in minimised background window
start "PharmApp-mDNS" /min python mdns_broadcast.py %PORT%

:: Start Django (blocks until Ctrl+C)
python manage.py runserver 0.0.0.0:%PORT%

endlocal
