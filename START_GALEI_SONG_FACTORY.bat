@echo off
setlocal
cd /d %~dp0
if not exist .venv (
  echo Galei setup has not been run yet.
  powershell -ExecutionPolicy Bypass -File galei\setup_galei_windows.ps1
  if errorlevel 1 pause & exit /b 1
)
start "ACE-Step API" cmd /k "cd /d %~dp0 && uv run acestep-api"
timeout /t 5 /nobreak >nul
start "Galei Song Factory" cmd /k "cd /d %~dp0 && uv run python galei\factory_server.py"
timeout /t 2 /nobreak >nul
start http://127.0.0.1:8765
