param([string]$FlutterRoot = 'C:\flutter')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterExecutable = Join-Path $FlutterRoot 'bin\flutter.bat'
$dartExecutable = Join-Path $FlutterRoot 'bin\dart.bat'
function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Validation failed: $Executable $Arguments" }
}
Push-Location (Join-Path $repoRoot 'apps\mobile')
try {
    Invoke-Checked $flutterExecutable @('pub', 'get')
    Invoke-Checked $flutterExecutable @('analyze')
    Invoke-Checked $flutterExecutable @('test')
} finally { Pop-Location }
Push-Location (Join-Path $repoRoot 'packages\data_access')
try {
    Invoke-Checked $dartExecutable @('pub', 'get')
    Invoke-Checked $dartExecutable @('test')
} finally { Pop-Location }
Push-Location (Join-Path $PSScriptRoot 'sql-tests')
try {
    Invoke-Checked 'npm.cmd' @('ci')
    Invoke-Checked 'npm.cmd' @('test')
} finally { Pop-Location }
