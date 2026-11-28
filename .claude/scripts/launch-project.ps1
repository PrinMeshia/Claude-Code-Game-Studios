# Windows entrypoint for the shared CCGS project launcher.
# Prefer Git for Windows explicitly; never accidentally invoke the WSL bash shim.
# Runtime logic remains centralized in launch-project.sh.
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

$candidates = [System.Collections.Generic.List[string]]::new()

# Derive Git's installation root from git.exe when available.
$gitCommand = Get-Command 'git.exe' -ErrorAction SilentlyContinue
if ($gitCommand -and $gitCommand.Source) {
    $gitDir = Split-Path -Parent $gitCommand.Source
    if ((Split-Path -Leaf $gitDir) -ieq 'cmd') {
        $gitRoot = Split-Path -Parent $gitDir
        $candidates.Add((Join-Path $gitRoot 'bin\bash.exe'))
        $candidates.Add((Join-Path $gitRoot 'usr\bin\bash.exe'))
    }
}

$knownRoots = @(
    (Join-Path $env:ProgramFiles 'Git'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Git'),
    (Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Git')
) | Where-Object { $_ }

foreach ($gitRoot in $knownRoots) {
    $candidates.Add((Join-Path $gitRoot 'bin\bash.exe'))
    $candidates.Add((Join-Path $gitRoot 'usr\bin\bash.exe'))
}

# PATH is only a fallback; verify the runtime identity before using it.
$pathBashes = Get-Command 'bash.exe' -All -ErrorAction SilentlyContinue
foreach ($pathBash in $pathBashes) {
    if ($pathBash -and $pathBash.Source) {
        $candidates.Add($pathBash.Source)
    }
}

$bashPath = $null
$seen = @{}
foreach ($candidate in $candidates) {
    if (-not $candidate -or $seen.ContainsKey($candidate)) { continue }
    $seen[$candidate] = $true
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }

    # Git Bash reports MINGW*/MSYS*; WSL reports Linux and is rejected.
    try {
        $runtime = (& $candidate -lc 'uname -s' 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $runtime -match '^(MINGW|MSYS|CYGWIN)') {
            $bashPath = $candidate
            break
        }
    } catch {
        # Continue searching; an unusable bash must not block other candidates.
    }
}

if (-not $bashPath) {
    Write-Error 'Git Bash was not found. Install Git for Windows (not WSL) or add its installation to PATH. WSL is not required.'
    exit 127
}

# Preserve argument boundaries (including paths and values containing spaces).
& $bashPath $launcher @LauncherArgs
$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) { $exitCode = 0 }
exit $exitCode
