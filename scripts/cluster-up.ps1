param(
  [string]$ClusterName = "portable-voting"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$env:Path = "$BinDir;$env:Path"

docker info | Out-Null

$existingClusters = & k3d cluster list --no-headers 2>$null
$exists = $false
foreach ($line in $existingClusters) {
  if ($line -match "^\s*$([regex]::Escape($ClusterName))\s") {
    $exists = $true
  }
}

if ($exists) {
  Write-Host "k3d cluster '$ClusterName' already exists."
} else {
  k3d cluster create $ClusterName `
    --servers 1 `
    --agents 2 `
    --k3s-arg "--disable=traefik@server:*" `
    --port "8080:80@loadbalancer" `
    --port "8443:443@loadbalancer" `
    --wait
}

kubectl config use-context "k3d-$ClusterName"
kubectl get nodes -o wide
