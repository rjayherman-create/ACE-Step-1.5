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
set "ACESTEP_INIT_LLM=false"
set "ACESTEP_NO_INIT=false"
set "ACESTEP_CONFIG_PATH=acestep-v15-turbo"
set "ACESTEP_DTYPE=float32"
set "ACESTEP_OFFLOAD_TO_CPU=true"
set "ACESTEP_OFFLOAD_DIT_TO_CPU=true"
set "MAX_CUDA_VRAM=4"
set "CHECK_UPDATE=false"

REM Repair the local .env so Tier 1 settings persist across launches.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='.env'; $wanted=@{'ACESTEP_CONFIG_PATH'='acestep-v15-turbo';'ACESTEP_DTYPE'='float32';'ACESTEP_OFFLOAD_TO_CPU'='true';'ACESTEP_OFFLOAD_DIT_TO_CPU'='true';'ACESTEP_INIT_LLM'='false'}; $lines=@(); if(Test-Path $p){$lines=Get-Content $p}; foreach($k in $wanted.Keys){$lines=$lines | Where-Object {$_ -notmatch ('^'+[regex]::Escape($k)+'=')}}; foreach($k in $wanted.Keys){$lines += ($k+'='+$wanted[$k])}; $lines | Set-Content -Encoding UTF8 $p"

echo ==========================================================
echo Galei Ivrit Jr - GTX 1650 4 GB Stability Profile
echo ==========================================================
echo LM: OFF
echo Model: ACE-Step 1.5 Turbo
echo Dtype: FLOAT32
echo CPU offload: ON
echo DiT offload: ON
echo Batch: 1
echo VRAM tier: 4 GB / Tier 1
echo.

echo Starting ACE-Step music engine and loading the model...
start "ACE-Step API" cmd /k "cd /d %~dp0 && set ^"ACESTEP_INIT_LLM=false^" && set ^"ACESTEP_NO_INIT=false^" && set ^"ACESTEP_CONFIG_PATH=acestep-v15-turbo^" && set ^"ACESTEP_DTYPE=float32^" && set ^"ACESTEP_OFFLOAD_TO_CPU=true^" && set ^"ACESTEP_OFFLOAD_DIT_TO_CPU=true^" && set ^"MAX_CUDA_VRAM=4^" && set ^"CHECK_UPDATE=false^" && call start_api_server.bat"

echo Waiting for ACE-Step model/API to become ready...
set READY=0
for /L %%I in (1,1,180) do (
  powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 http://127.0.0.1:8001/openapi.json; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>nul
  if !ERRORLEVEL! EQU 0 (
    set READY=1
    goto :ApiReady
  )
  if %%I EQU 1 echo First model load can take several minutes on this 4 GB profile.
  timeout /t 2 /nobreak >nul
)

:ApiReady
if "%READY%"=="0" (
  echo.
  echo ==========================================================
  echo ACE-STEP MODEL/API DID NOT BECOME READY
  echo ==========================================================
  echo Leave the ACE-Step API window open and send its final lines.
  echo.
  pause
  exit /b 1
)

echo ACE-Step model/API is ready.
echo Starting Galei Song Factory...
start "Galei Song Factory" cmd /k "cd /d %~dp0 && uv run --no-sync python galei\factory_server.py"

set FACTORYREADY=0
for /L %%I in (1,1,60) do (
  powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 http://127.0.0.1:8765/api/status; if($r.StatusCode -eq 200){exit 0}else{exit 1} } catch { exit 1 }" >nul 2>nul
  if !ERRORLEVEL! EQU 0 (
    set FACTORYREADY=1
    goto :FactoryReady
  )
  timeout /t 1 /nobreak >nul
)

:FactoryReady
if "%FACTORYREADY%"=="0" (
  echo Galei UI server did not start. Check the Galei Song Factory window.
  pause
  exit /b 1
)

echo Opening Galei Ivrit Jr Song Factory...
start "" http://127.0.0.1:8765
exit /b 0
