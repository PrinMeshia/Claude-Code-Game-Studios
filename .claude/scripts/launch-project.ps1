# Windows entrypoint for the shared CCGS project launcher.
# Requires Git for Windows (Git Bash). The runtime logic remains centralized
# in launch-project.sh so Windows and Unix use identical safety checks.
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $LauncherArgs
)

$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'launch-project.sh'

if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    Write-Error "CCGS launcher not found: $launcher"
    exit 2
}

$bashCommand = Get-Command 'bash.exe' -ErrorAction SilentlyContinue
if (-not $bashCommand) {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:ProgramFiles 'Git\usr\bin\bash.exe'),
        (Join-Path $env:ProgramFiles 'Git\mingw64\bin\bash.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }

    if ($candidates.Count -gt 0) {
        $bashPath = $candidates[0]
    } else {
        Write-Error 'Git Bash is required. Install Git for Windows and ensure bash.exe is on PATH.'
        exit 127
    }
} else {
    $bashPath = $bashCommand.Source
}

# Preserve argument boundaries (including paths and values containing spaces).
& $bashPath $launcher @LauncherArgs
$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) { $exitCode = 0 }
exit $exitCode
