param(
    [string]$PythonExecutable = "python"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$testEnvironment = Join-Path ([System.IO.Path]::GetTempPath()) ("archerage-tests-" + [guid]::NewGuid().ToString("N"))

# 任一步驟失敗即中止，讓本機與 workflow 取得相同結果。
function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "測試命令失敗：$Executable（結束碼 $LASTEXITCODE）" }
}

Push-Location $repoRoot
try {
    # 隔離 Lua 執行環境，不改動使用者的 Python 套件。
    Invoke-Checked $PythonExecutable @("-m", "venv", $testEnvironment)
    $testPython = Join-Path $testEnvironment "Scripts/python.exe"
    Invoke-Checked $testPython @("-m", "pip", "install", "--disable-pip-version-check", "-r", "scripts/test-requirements.txt")
    Invoke-Checked $testPython @("-X", "utf8", "scripts/test-lua.py")

    Push-Location "installer"
    try {
        Invoke-Checked "go" @("test", "./...")
        Invoke-Checked "go" @("vet", "./...")
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
    # 僅清除此腳本建立的暫存環境。
    $resolvedEnvironment = [System.IO.Path]::GetFullPath($testEnvironment)
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolvedEnvironment.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedEnvironment) -like "archerage-tests-*" -and
        (Test-Path -LiteralPath $resolvedEnvironment)) {
        Remove-Item -LiteralPath $resolvedEnvironment -Recurse -Force
    }
}
