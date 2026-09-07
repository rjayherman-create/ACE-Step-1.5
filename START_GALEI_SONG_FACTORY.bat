@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d %~dp0

if not exist .venv (
  echo Galei setup has not been run yet.
  powershell -NoProfile -ExecutionPolicy Bypass -File galei\setup_galei_windows.ps1
  if errorlevel 1 pause & exit /b 1
)

if not exist galei\logs mkdir galei\logs

REM Exact safe settings for the detected GTX 1650 / 4 GB Tier 1 machine.
set ACESTEP_INIT_LLM=false
set ACESTEP_NO_INIT=false
set ACESTEP_CONFIG_PATH=acestep-v15-turbo
set MAX_CUDA_VRAM=4
set CHECK_UPDATE=false

echo ==========================================================
echo Galei Ivrit Jr - GTX 1650 4 GB Safe Profile
echo ==========================================================
echo LM: OFF
echo Model: ACE-Step 1.5 Turbo
echo Batch: 1
echo VRAM tier: 4 GB / Tier 1
echo.

echo Starting ACE-Step music engine and loading the model...
start "ACE-Step API" cmd /k "cd /d %~dp0 && set ACESTEP_INIT_LLM=false && set ACESTEP_NO_INIT=false && set ACESTEP_CONFIG_PATH=acestep-v15-turbo && set MAX_CUDA_VRAM=4 && set CHECK_UPDATE=false && call start_api_server.bat"

echo Waiting for ACE-Step model/API to become ready...
set READY=0
for /L %%I in (1,1,180) do (
  powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 http://127.0.0.1:8001/health; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>nul
  if !ERRORLEVEL! EQU 0 (
    set READY=1
    goto :ApiReady
  )
  if %%I EQU 1 echo First model load can take several minutes on a 4 GB GPU.
  timeout /t 2 /nobreak >nul
)

:ApiReady
if "%READY%"=="0" (
  echo.
  echo ==========================================================
  echo ACE-STEP MODEL/API DID NOT BECOME READY
  echo ==========================================================
  echo.
  echo Leave the ACE-Step API window open and send its final lines.
  echo.
  pause
  exit /b 1
)

echo ACE-Step model/API is ready.
echo Starting Galei Song Factory...
start "Galei Song Factory" cmd /k "cd /d %~dp0 && uv run --no-sync python galei\factory_server.py"

for /L %%I in (1,1,30) do (
  powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 http://127.0.0.1:8765/api/status; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>nul
  if !ERRORLEVEL! EQU 0 goto :FactoryReady
  timeout /t 1 /nobreak >nul
)

:FactoryReady
start "" http://127.0.0.1:8765
