# Build dist/: per addon a zip (with version.txt), icon (.png) and README (.md),
# plus manifest.json and ArcheRageAddonInstaller.exe.
# Used by GitHub Actions and can be run locally (Windows PowerShell 5.1 or pwsh).
#
# Credentials are entered by users in the app, never passed to the build.
param(
    [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $root 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$dist = Join-Path $root 'dist'
$stage = Join-Path $root 'dist-stage'

foreach ($dir in @($dist, $stage)) {
    $resolved = [IO.Path]::GetFullPath($dir)
    if ($resolved -notin @([IO.Path]::GetFullPath((Join-Path $root 'dist')), [IO.Path]::GetFullPath((Join-Path $root 'dist-stage')))) { throw 'Invalid build output path' }
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    New-Item -ItemType Directory $dir | Out-Null
}

try {
    foreach ($addon in $manifest.addons) {
        $src = Join-Path $root "addons\$($addon.name)"
        if (-not (Test-Path $src)) { throw "Addon folder not found: $src" }

        $staged = Join-Path $stage $addon.name
        Copy-Item $src $staged -Recurse
        Set-Content (Join-Path $staged 'version.txt') $addon.version -Encoding Ascii -NoNewline

        $zip = Join-Path $dist "$($addon.name).zip"
        # Add entries one by one so paths always use '/' (Windows PowerShell 5.1 would write '\')
        $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in Get-ChildItem $staged -Recurse -File) {
                $entry = $addon.name + '/' + $file.FullName.Substring($staged.Length + 1).Replace('\', '/')
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        }
        finally {
            $archive.Dispose()
        }

        # Icon and description are published separately so the installer can show them before installing
        $icon = Join-Path $root "meta\$($addon.name)\icon.png"
        if (Test-Path $icon) { Copy-Item $icon (Join-Path $dist "$($addon.name).png") }
        $readme = Join-Path $src 'README.md'
        if (Test-Path $readme) { Copy-Item $readme (Join-Path $dist "$($addon.name).md") }

        Write-Host "Packed $($addon.name) $($addon.version)"
    }

    Copy-Item (Join-Path $root 'manifest.json') $dist

    if (-not $SkipInstaller) {
        $version = $manifest.installer.version

        $installer = Join-Path $root 'installer'
        # Keep the exe's file version in sync with manifest.json
        $wailsJson = Join-Path $installer 'wails.json'
        $wails = Get-Content $wailsJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $wails.info.productVersion = $version
        [IO.File]::WriteAllText($wailsJson, ($wails | ConvertTo-Json -Depth 10) + "`n", (New-Object Text.UTF8Encoding $false))

        Push-Location $installer
        try {
            wails build -clean -trimpath -webview2 download `
                -ldflags "-X main.version=$version"
            if ($LASTEXITCODE -ne 0) { throw 'wails build failed' }
        }
        finally {
            Pop-Location
        }
        Copy-Item (Join-Path $installer 'build\bin\ArcheRageAddonInstaller.exe') $dist
        Write-Host "Built ArcheRageAddonInstaller $version"
    }
}
finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}

Get-ChildItem $dist | Format-Table Name, Length
