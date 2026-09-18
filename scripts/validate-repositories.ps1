$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$raw = (Get-Content (Join-Path $root 'repositories.json') -Raw).Trim()
if (-not $raw.StartsWith('[')) { throw 'repositories.json 必須是 URL 陣列' }
$seen = @{}
foreach ($url in ($raw | ConvertFrom-Json)) {
    if ($url -isnot [string] -or $url -notmatch '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "來源格式錯誤：$url" }
    $key = $url.ToLowerInvariant()
    if ($seen.ContainsKey($key)) { throw "來源重複：$url" }
    $seen[$key] = $true
}
Write-Host '收錄清單檢查通過'
