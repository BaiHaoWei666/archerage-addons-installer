param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json).installer.version
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$wails = Get-Content (Join-Path $root 'installer/wails.json') -Raw | ConvertFrom-Json
if ($wails.info.productVersion -ne $version) { throw 'manifest 與 wails.json 版本不一致' }
Push-Location (Join-Path $root 'installer')
try {
    wails build -clean -trimpath -webview2 download -ldflags "-X main.version=$version"
    if ($LASTEXITCODE -ne 0) { throw '安裝器建置失敗' }
    Copy-Item 'build/bin/ArcheRageAddonInstaller.exe' $dist -Force
} finally { Pop-Location }
Write-Host "已建置安裝器 $version"
