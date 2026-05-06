param(
  [string]$ClusterName = "portable-voting",
  [switch]$SkipImport
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$env:Path = "$BinDir;$env:Path"

Push-Location $ProjectRoot
try {
  docker build -t voting-vote:local .\vote
  if ($LASTEXITCODE -ne 0) { throw "Failed to build voting-vote:local" }
  docker build -t voting-result:local .\result
  if ($LASTEXITCODE -ne 0) { throw "Failed to build voting-result:local" }
  docker build -t voting-worker:local .\worker
  if ($LASTEXITCODE -ne 0) { throw "Failed to build voting-worker:local" }

  if (-not $SkipImport) {
    $existingClusters = & k3d cluster list --no-headers 2>$null
    $exists = $false
    foreach ($line in $existingClusters) {
      if ($line -match "^\s*$([regex]::Escape($ClusterName))\s") {
        $exists = $true
      }
    }

    if ($exists) {
      k3d image import voting-vote:local voting-result:local voting-worker:local --cluster $ClusterName
      if ($LASTEXITCODE -ne 0) { throw "Failed to import local images into k3d cluster '$ClusterName'" }
    } else {
      Write-Host "Cluster '$ClusterName' does not exist yet. Images were built but not imported."
    }
  }
}
finally {
  Pop-Location
}
