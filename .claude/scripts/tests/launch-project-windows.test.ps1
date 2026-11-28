# Contract test for the Windows launcher entrypoints.
$ErrorActionPreference = 'Stop'
$scriptsDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$entrypoint = Join-Path $scriptsDir 'launch-project.ps1'
$cmdEntrypoint = Join-Path $scriptsDir 'launch-project.cmd'

if (-not (Test-Path -LiteralPath $entrypoint -PathType Leaf)) {
    throw "Missing PowerShell entrypoint: $entrypoint"
}
if (-not (Test-Path -LiteralPath $cmdEntrypoint -PathType Leaf)) {
    throw "Missing CMD entrypoint: $cmdEntrypoint"
}

$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $entrypoint,
    [ref] $tokens,
    [ref] $parseErrors
) | Out-Null
if ($parseErrors) {
    $parseErrors | Format-List | Out-String | Write-Error
    exit 1
}

$bash = Get-Command 'bash.exe' -ErrorAction SilentlyContinue
if (-not $bash) {
    throw 'Windows CI requires Git Bash to exercise the PowerShell wrapper.'
}

& $entrypoint -LauncherArgs @('--help')
if ($LASTEXITCODE -ne 0) {
    throw "PowerShell launcher help smoke test failed with exit code $LASTEXITCODE"
}

Write-Host 'Windows launcher entrypoint contracts passed.'
