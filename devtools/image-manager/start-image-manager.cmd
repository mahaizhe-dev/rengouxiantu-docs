@echo off
setlocal
cd /d "%~dp0..\.."

where node >nul 2>nul
if errorlevel 1 (
  echo [Image Manager] Node.js was not found in PATH.
  echo Install Node.js or add node.exe to PATH, then run this file again.
  pause
  exit /b 1
)

start "Image Manager Server" /min cmd /c "node devtools\image-manager\server.mjs"

echo [Image Manager] Starting...
timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:4317/"
endlocal
