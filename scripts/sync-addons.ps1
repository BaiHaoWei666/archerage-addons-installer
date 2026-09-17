# Copy the addons listed in manifest.json from the game Addon folder into addons/.
# Mirrors each folder (files deleted in the game folder are deleted here too).
param(
    [string]$AddonDir = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'ArcheRage\Addon')
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $root 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($addon in $manifest.addons) {
    $src = Join-Path $AddonDir $addon.name
    $dst = Join-Path $root "addons\$($addon.name)"
    if (-not (Test-Path $src)) { throw "Addon folder not found: $src" }

    robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NP /XF .luarc.jsonc version.txt *.rar | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $($addon.name) (exit $LASTEXITCODE)" }
    Write-Host "Synced $($addon.name)"
}
$global:LASTEXITCODE = 0
