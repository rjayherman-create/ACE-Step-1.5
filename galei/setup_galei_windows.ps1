$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
Write-Host '=== Galei Ivrit Jr Local Song Factory Setup ===' -ForegroundColor Cyan

function Has-Cmd($name) { return $null -ne (Get-Command $name -ErrorAction SilentlyContinue) }

$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name)
$gpuName = 'No NVIDIA GPU detected'
$vramGB = 0
if (Has-Cmd 'nvidia-smi') {
  try {
    $gpuName = (& nvidia-smi --query-gpu=name --format=csv,noheader | Select-Object -First 1).Trim()
    $vramMB = [int]((& nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | Select-Object -First 1).Trim())
    $vramGB = [math]::Round($vramMB / 1024, 1)
  } catch {}
}
$freeGB = [math]::Round((Get-PSDrive -Name (Get-Location).Path.Substring(0,1)).Free / 1GB, 1)

Write-Host "CPU: $cpu"
Write-Host "RAM: $ramGB GB"
Write-Host "GPU: $gpuName"
Write-Host "VRAM: $vramGB GB"
Write-Host "Free disk: $freeGB GB"

$profile = 'cpu-safe'
$lm = ''
$extra = @()
if ($vramGB -ge 12) { $profile='quality'; $lm='acestep-5Hz-lm-1.7B' }
elseif ($vramGB -ge 8) { $profile='balanced'; $lm='acestep-5Hz-lm-0.6B' }
elseif ($vramGB -ge 6) {
  $profile='light'
  $lm='acestep-5Hz-lm-0.6B'
  $extra += 'ACESTEP_OFFLOAD_TO_CPU=true'
}
elseif ($vramGB -gt 0) {
  $profile='low-vram'
  $lm=''
  $extra += 'ACESTEP_OFFLOAD_TO_CPU=true'
  $extra += 'ACESTEP_OFFLOAD_DIT_TO_CPU=true'
  $extra += 'ACESTEP_DTYPE=float32'
  $extra += 'ACESTEP_INIT_LLM=false'
}

Write-Host "Selected profile: $profile" -ForegroundColor Green
if ($freeGB -lt 20) { Write-Warning 'Less than 20 GB free disk. Model downloads may fail.' }
if ($ramGB -lt 16) { Write-Warning 'Less than 16 GB RAM detected. Generation may be slow; close other large apps.' }

if (-not (Has-Cmd 'git')) { throw 'Git is required. Install Git for Windows, then run this again.' }
if (-not (Has-Cmd 'uv')) {
  Write-Host 'Installing uv...'
  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}

Write-Host 'Installing ACE-Step dependencies...'
uv sync

$envLines = @(
  'ACESTEP_CONFIG_PATH=acestep-v15-turbo',
  'PORT=7860',
  'API_PORT=8001',
  'LANGUAGE=en'
)
if ($lm) { $envLines += "ACESTEP_LM_MODEL_PATH=$lm" }
$envLines += $extra
$envLines | Set-Content -Path '.env' -Encoding UTF8

$spec = [ordered]@{ cpu=$cpu; ramGB=$ramGB; gpu=$gpuName; vramGB=$vramGB; freeDiskGB=$freeGB; profile=$profile; installedAt=(Get-Date).ToString('s') }
$spec | ConvertTo-Json | Set-Content -Path 'galei\computer-profile.json' -Encoding UTF8

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host 'Next: double-click START_GALEI_SONG_FACTORY.bat'
