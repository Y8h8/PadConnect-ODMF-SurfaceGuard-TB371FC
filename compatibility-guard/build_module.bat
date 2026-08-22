@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"

echo Pulling the stock ODMF file from the connected tablet...
adb get-state 1>nul 2>nul
if errorlevel 1 (
  echo ERROR: No ADB device detected.
  pause
  exit /b 1
)

adb pull /system_ext/framework/oplusex/com.oplus.odmf/odmf.jar stock_odmf.jar
if errorlevel 1 (
  echo ERROR: Failed to pull stock odmf.jar.
  pause
  exit /b 1
)

python build_module.py stock_odmf.jar
if errorlevel 1 (
  echo ERROR: Build failed. Read the message above.
  pause
  exit /b 1
)

echo.
echo Build finished. The installable ZIP is in the dist folder.
pause
