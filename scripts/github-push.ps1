param(
  [string]$Repo = "saudelm/kubernetes-portable-voting-app",
  [string]$Message = "Add portable on-prem Kubernetes deployment"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$env:Path = "$BinDir;$env:Path"

Push-Location $ProjectRoot
try {
  gh auth status
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run '.\.local\bin\gh.exe auth login' first."
  }

  $origin = git remote get-url origin 2>$null
  if ($LASTEXITCODE -ne 0) {
    git remote add origin "https://github.com/$Repo.git"
  } elseif ($origin -ne "https://github.com/$Repo.git") {
    git remote set-url origin "https://github.com/$Repo.git"
  }

  gh repo view $Repo | Out-Null
  if ($LASTEXITCODE -ne 0) {
    gh repo create $Repo --private
  }

  $status = git status --porcelain
  if ($status) {
    git add .
    git commit -m $Message
  } else {
    Write-Host "No local changes to commit."
  }

  git push -u origin main
}
finally {
  Pop-Location
}
