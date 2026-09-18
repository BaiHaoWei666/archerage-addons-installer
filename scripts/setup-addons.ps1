$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'validate-repositories.ps1')
$addonRoot = Join-Path $root 'addons'
New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null
foreach ($url in (Get-Content (Join-Path $root 'repositories.json') -Raw | ConvertFrom-Json)) {
    $name = ($url -split '/')[-1]
    $target = Join-Path $addonRoot $name
    if (Test-Path -LiteralPath $target) {
        Write-Host "保留既有開發目錄：$target"
        continue
    }
    git clone $url $target
    if ($LASTEXITCODE -ne 0) { throw "Clone 失敗：$url" }
}
