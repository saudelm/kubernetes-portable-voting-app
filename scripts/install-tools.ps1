param(
  [string]$HelmVersion = "4.2.3",
  [string]$TerraformVersion = "1.15.8",
  [string]$K3dVersion = "5.9.0",
  [string]$GhVersion = "2.96.0"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $ProjectRoot ".local\bin"
$TmpDir = Join-Path $ProjectRoot ".local\tmp"

New-Item -ItemType Directory -Force $BinDir, $TmpDir | Out-Null

function Download-File {
  param(
    [string]$Uri,
    [string]$OutFile
  )

  Write-Host "Downloading $Uri"
  Invoke-WebRequest -Uri $Uri -OutFile $OutFile
}

$helmZip = Join-Path $TmpDir "helm.zip"
$helmExtract = Join-Path $TmpDir "helm"
Download-File "https://get.helm.sh/helm-v$HelmVersion-windows-amd64.zip" $helmZip
Expand-Archive -Path $helmZip -DestinationPath $helmExtract -Force
Copy-Item (Join-Path $helmExtract "windows-amd64\helm.exe") (Join-Path $BinDir "helm.exe") -Force

$terraformZip = Join-Path $TmpDir "terraform.zip"
$terraformExtract = Join-Path $TmpDir "terraform"
Download-File "https://releases.hashicorp.com/terraform/$TerraformVersion/terraform_${TerraformVersion}_windows_amd64.zip" $terraformZip
Expand-Archive -Path $terraformZip -DestinationPath $terraformExtract -Force
Copy-Item (Join-Path $terraformExtract "terraform.exe") (Join-Path $BinDir "terraform.exe") -Force

$k3dExe = Join-Path $BinDir "k3d.exe"
Download-File "https://github.com/k3d-io/k3d/releases/download/v$K3dVersion/k3d-windows-amd64.exe" $k3dExe

$ghZip = Join-Path $TmpDir "gh.zip"
$ghExtract = Join-Path $TmpDir "gh"
Download-File "https://github.com/cli/cli/releases/download/v$GhVersion/gh_${GhVersion}_windows_amd64.zip" $ghZip
Expand-Archive -Path $ghZip -DestinationPath $ghExtract -Force
$ghExe = Get-ChildItem -Path $ghExtract -Recurse -Filter gh.exe | Select-Object -First 1
if (-not $ghExe) {
  throw "gh.exe was not found in the extracted archive."
}
Copy-Item $ghExe.FullName (Join-Path $BinDir "gh.exe") -Force

Write-Host ""
Write-Host "Installed portable tools into $BinDir"
& (Join-Path $BinDir "helm.exe") version --short
& (Join-Path $BinDir "terraform.exe") version
& (Join-Path $BinDir "k3d.exe") version
& (Join-Path $BinDir "gh.exe") --version
