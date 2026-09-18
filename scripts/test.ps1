$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    & ./scripts/validate-repositories.ps1
    Push-Location installer
    try {
        go test ./...
        if ($LASTEXITCODE -ne 0) { throw 'Go 測試失敗' }
        go vet ./...
        if ($LASTEXITCODE -ne 0) { throw 'Go 靜態檢查失敗' }
    } finally { Pop-Location }
} finally { Pop-Location }
