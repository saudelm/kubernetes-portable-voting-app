$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$env:Path = "$BinDir;$env:Path"

kubectl get pods -n traefik -o wide
kubectl get pods -n voting -o wide
kubectl get pods -n monitoring -o wide
