$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$env:Path = "$BinDir;$env:Path"

Push-Location $ProjectRoot
try {
  helm lint .\charts\voting-app
  helm template voting .\charts\voting-app --namespace voting | Out-Null
  terraform -chdir="$ProjectRoot\infra\onprem-k3d" fmt -check
  terraform -chdir="$ProjectRoot\infra\onprem-k3d" init -backend=false
  terraform -chdir="$ProjectRoot\infra\onprem-k3d" validate
}
finally {
  Pop-Location
}
