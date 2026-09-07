@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d %~dp0

if not exist .venv (
  echo Galei setup has not been run yet.
  powershell -NoProfile -ExecutionPolicy Bypass -File galei\setup_galei_windows.ps1
  if errorlevel 1 pause & exit /b 1
)

if not exist galei\logs mkdir galei\logs

echo Starting ACE-Step music engine...
start "ACE-Step API" cmd /k "cd /d %~dp0 && call start_api_server.bat"

echo Waiting for ACE-Step API to become ready...
set READY=0
for /L %%I in (1,1,120) do (
  powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 http://127.0.0.1:8001/health; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>nul
  if !ERRORLEVEL! EQU 0 (
    set READY=1
    goto :ApiReady
  )
  if %%I EQU 1 echo ACE-Step can take several minutes on first launch while models initialize.
  timeout /t 2 /nobreak >nul
)

:ApiReady
if "%READY%"=="0" (
  echo.
  echo ==========================================================
  echo ACE-STEP DID NOT START
  echo ==========================================================
  echo.
  echo The ACE-Step API window should contain the actual error.
  echo Please leave that window open and send a screenshot of it.
  echo.
  echo You can also test the API manually by opening:
  echo http://127.0.0.1:8001/health
  echo.
  pause
  exit /b 1
)

echo ACE-Step API is ready.
echo Starting Galei Song Factory...
start "Galei Song Factory" cmd /k "cd /d %~dp0 && uv run --no-sync python galei\factory_server.py"

for /L %%I in (1,1,30) do (
  powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 http://127.0.0.1:8765/api/status; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>nul
  if !ERRORLEVEL! EQU 0 goto :FactoryReady
  timeout /t 1 /nobreak >nul
)

:FactoryReady
start "" http://127.0.0.1:8765
