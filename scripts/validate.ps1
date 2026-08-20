$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$env:Path = "$BinDir;$env:Path"

Push-Location $ProjectRoot
try {
  helm lint .\charts\voting-app
  helm template voting .\charts\voting-app --namespace voting `
    -f .\charts\voting-app\values.yaml | Out-Null
  helm template voting .\charts\voting-app --namespace voting `
    -f .\charts\voting-app\values-gke.yaml `
    --set-string vote.image.tag=abcdef1 `
    --set-string result.image.tag=abcdef1 `
    --set-string worker.image.tag=abcdef1 `
    --set-string vote.ingress.host=vote.192.0.2.1.nip.io `
    --set-string result.ingress.host=result.192.0.2.1.nip.io | Out-Null
  terraform -chdir="$ProjectRoot\infra\onprem-k3d" fmt -check
  terraform -chdir="$ProjectRoot\infra\onprem-k3d" init -backend=false
  terraform -chdir="$ProjectRoot\infra\onprem-k3d" validate
  terraform -chdir="$ProjectRoot\infra\gke" fmt -check
  terraform -chdir="$ProjectRoot\infra\gke" init -backend=false
  terraform -chdir="$ProjectRoot\infra\gke" validate
  $PythonVenv = Join-Path $ProjectRoot ".local\python-venv"
  python -m venv $PythonVenv
  $VenvPython = Join-Path $PythonVenv "Scripts\python.exe"
  & $VenvPython -m pip install -r "$ProjectRoot\vote\requirements.txt"
  & $VenvPython -m py_compile "$ProjectRoot\vote\app.py"
  $env:PYTHONPATH = "$ProjectRoot\vote"
  & $VenvPython -m unittest discover -s "$ProjectRoot\vote\tests" -p "test_*.py"
  ruby "$ProjectRoot\scripts\compare-portability.rb"
  Push-Location "$ProjectRoot\result"
  try {
    npm ci --ignore-scripts
    npm test
    npm audit --omit=dev
  }
  finally {
    Pop-Location
  }
}
finally {
  Pop-Location
}
