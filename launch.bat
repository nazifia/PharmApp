@echo off
echo Starting PharmApp backend...
start "PharmApp Backend" cmd /k "cd /d C:\Users\Dell\Desktop\MY_PRODUCTS\PharmApp\backend && start_lan.bat"

timeout /t 3 /nobreak >nul

echo Starting Flutter app...
cd /d C:\Users\Dell\Desktop\MY_PRODUCTS\PharmApp\pharmapp
flutter run
