$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$env:Path = "$BinDir;$env:Path"

function Invoke-Checked {
  param([scriptblock]$Command)
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "Validation command failed: $Command" }
}

Push-Location $ProjectRoot
try {
  Invoke-Checked { helm lint .\charts\voting-app --set-string postgres.password=static-test-not-a-credential }
  helm template voting .\charts\voting-app --namespace voting `
    -f .\charts\voting-app\values.yaml --set-string postgres.password=static-test-not-a-credential | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Local Helm rendering failed" }
  helm template voting .\charts\voting-app --namespace voting `
    -f .\charts\voting-app\values-gke.yaml `
    --set-string vote.image.tag=abcdef1 `
    --set-string result.image.tag=abcdef1 `
    --set-string worker.image.tag=abcdef1 `
    --set-string vote.ingress.host=vote.192.0.2.1.nip.io `
    --set-string result.ingress.host=result.192.0.2.1.nip.io `
    --set-string postgres.password=static-test-not-a-credential | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "GKE Helm rendering failed" }
  Invoke-Checked { terraform -chdir="$ProjectRoot\infra\onprem-k3d" fmt -check }
  Invoke-Checked { terraform -chdir="$ProjectRoot\infra\onprem-k3d" init -backend=false }
  Invoke-Checked { terraform -chdir="$ProjectRoot\infra\onprem-k3d" validate }
  Invoke-Checked { terraform -chdir="$ProjectRoot\infra\gke" fmt -check }
  Invoke-Checked { terraform -chdir="$ProjectRoot\infra\gke" init -backend=false }
  Invoke-Checked { terraform -chdir="$ProjectRoot\infra\gke" validate }
  $PythonVenv = Join-Path $ProjectRoot ".local\python-venv"
  Invoke-Checked { python -m venv $PythonVenv }
  $VenvPython = Join-Path $PythonVenv "Scripts\python.exe"
  Invoke-Checked { & $VenvPython -m pip install -r "$ProjectRoot\vote\requirements.txt" }
  Invoke-Checked { & $VenvPython -m py_compile "$ProjectRoot\vote\app.py" }
  $env:PYTHONPATH = "$ProjectRoot\vote"
  Invoke-Checked { & $VenvPython -m unittest discover -s "$ProjectRoot\vote\tests" -p "test_*.py" }
  Invoke-Checked { ruby "$ProjectRoot\scripts\tests\test_portability.rb" }
  Invoke-Checked { & $VenvPython -m unittest discover -s "$ProjectRoot\scripts\tests" -p "test_*.py" }
  $ComparisonOutput = Join-Path ([IO.Path]::GetTempPath()) ("voting-matrix-" + [guid]::NewGuid())
  Invoke-Checked { ruby "$ProjectRoot\scripts\compare-portability.rb" --output $ComparisonOutput }
  Push-Location "$ProjectRoot\result"
  try {
    Invoke-Checked { npm ci --ignore-scripts }
    Invoke-Checked { npm test }
    Invoke-Checked { npm audit --omit=dev }
  }
  finally {
    Pop-Location
  }
}
finally {
  Pop-Location
}
