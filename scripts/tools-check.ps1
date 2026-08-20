$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$env:Path = "$BinDir;$env:Path"
$failures = 0

function Test-Tool {
  param(
    [string]$Name,
    [string[]]$Arguments
  )

  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host "[missing] $Name"
    $script:failures += 1
    return
  }

  Write-Host "[ok] $Name -> $($cmd.Source)"
  & $Name @Arguments
  if ($LASTEXITCODE -ne 0) {
    $script:failures += 1
  }
}

Test-Tool -Name git -Arguments @("--version")
Test-Tool -Name kubectl -Arguments @("version", "--client=true")
Test-Tool -Name helm -Arguments @("version", "--short")
Test-Tool -Name terraform -Arguments @("version")
Test-Tool -Name k3d -Arguments @("version")
Test-Tool -Name gh -Arguments @("--version")
Test-Tool -Name docker -Arguments @("version")
Test-Tool -Name python -Arguments @("--version")
Test-Tool -Name ruby -Arguments @("--version")
Test-Tool -Name node -Arguments @("--version")
Test-Tool -Name npm -Arguments @("--version")

if (Get-Command gcloud -ErrorAction SilentlyContinue) {
  Write-Host "[ok] gcloud -> $((Get-Command gcloud).Source)"
  gcloud version
} else {
  Write-Host "[optional] gcloud is required only for the GKE experiment."
}

Write-Host ""
Write-Host "Checking Docker daemon..."
docker info | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host "[error] Docker Desktop is installed, but the Docker daemon is not reachable. Start Docker Desktop and rerun this script."
  $failures += 1
} else {
  Write-Host "[ok] Docker daemon is reachable."
}

if ($failures -gt 0) {
  Write-Host ""
  Write-Host "Tool check failed with $failures issue(s). Run scripts\install-tools.ps1 if portable tools are missing."
  exit 1
}

Write-Host ""
Write-Host "All required tools are ready."
