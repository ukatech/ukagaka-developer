<#
.SYNOPSIS
    Runs the checks that the ghost defines for itself (.github/ghost-checks.json).
.DESCRIPTION
    A ghost can have rules that the skill cannot know (how a talk is written, which words are not used, and so on).
    The ghost lists the commands that check them in .github/ghost-checks.json:

        { "checks": [ { "name": "half", "command": "python -X utf8 work/check/check-half.py" } ] }

    Every check has a "name" (unique) and a "command" (one PowerShell command line; it runs in the ghost root).
    "ci": false leaves a check out of GitHub Actions. "description" is shown in the list.
    A command is a program of the ghost, so it is not run on a PC just because it is there:
      - on GitHub Actions (GITHUB_ACTIONS=true) the commands run
      - anywhere else they only run with -AllowCustom; without it the commands are listed and the exit code is 3
    -Ci only makes the failures annotations; it does not allow anything.
    The commands get the environment variables DEVKIT_GHOST_ROOT (the ghost root) and DEVKIT_CI=1 (with -Ci).
    A command reports with its exit code: 0 = OK, 3 = could not check (skipped), anything else = failed.
    It runs in Windows PowerShell 5.1 on a PC and in pwsh on GitHub Actions, so write it to work in both.
    Without .github/ghost-checks.json nothing is done (exit code 0). A file that cannot be read (not JSON, a check without
    a name or a command, two checks with the same name) is a failure.
    Exit codes: 0 = all passed (or no checks), 1 = a check failed or the file is wrong,
    3 = the commands were not run (no -AllowCustom), or a check could not check (skipped).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-custom.ps1 -AllowCustom
#>
[CmdletBinding()]
param(
    # Emit GitHub Actions annotations for failures.
    [switch]$Ci,
    # Run the commands of the ghost on this PC (read .github/ghost-checks.json first).
    [switch]$AllowCustom,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
Initialize-DevkitConsole

$manifestRelative = '.github/ghost-checks.json'
$manifestPath = Join-Path $DevkitRoot $manifestRelative
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Write-Host "custom checks: none ($manifestRelative does not exist)"
    exit 0
}

function Write-CustomError([string]$Message) {
    Write-Host "custom checks: FAILED - $Message"
    if ($Ci) { Write-Host "::error file=$manifestRelative,title=custom checks::$Message" }
}

# --- read the list --------------------------------------------------------------------------
try {
    $json = [IO.File]::ReadAllText($manifestPath, (New-Object System.Text.UTF8Encoding($false))) | ConvertFrom-Json
} catch {
    Write-CustomError "$manifestRelative is not valid JSON ($($_.Exception.Message))"
    exit 1
}
if (-not $json -or -not ($json.PSObject.Properties.Name -contains 'checks')) {
    Write-CustomError "$manifestRelative has no ""checks"" list"
    exit 1
}
$checks = @($json.checks | Where-Object { $null -ne $_ })
$names = @{}
foreach ($check in $checks) {
    $props = @($check.PSObject.Properties.Name)
    $name = if ($props -contains 'name') { [string]$check.name } else { '' }
    $command = if ($props -contains 'command') { [string]$check.command } else { '' }
    if (-not $name.Trim()) { Write-CustomError 'a check has no "name"'; exit 1 }
    if (-not $command.Trim()) { Write-CustomError "the check ""$name"" has no ""command"""; exit 1 }
    if ($names.ContainsKey($name)) { Write-CustomError "two checks are named ""$name"""; exit 1 }
    $names[$name] = $true
    if (($props -contains 'ci') -and $check.ci -isnot [bool]) { Write-CustomError "the ""ci"" of the check ""$name"" is not true or false"; exit 1 }
}
if ($checks.Count -eq 0) {
    Write-Host 'custom checks: none (the list is empty)'
    exit 0
}

function Test-CheckForCi($Check) {
    return (-not (@($Check.PSObject.Properties.Name) -contains 'ci') -or $Check.ci)
}

# --- may the commands run here? ---------------------------------------------------------------
$onActions = ($env:GITHUB_ACTIONS -eq 'true')
if (-not $onActions -and -not $AllowCustom) {
    Write-Host "custom checks: $($checks.Count) defined in $manifestRelative, NOT run (they are programs of the ghost)."
    foreach ($check in $checks) {
        Write-Host "  $($check.name): $($check.command)"
    }
    Write-Host 'Read the commands, and if they are safe to run on this PC, add -AllowCustom.'
    exit 3
}

# --- run ------------------------------------------------------------------------------------
$powershell = (Get-Process -Id $PID).Path
$failed = @()
$skipped = @()
$savedRoot = $env:DEVKIT_GHOST_ROOT
$savedCi = $env:DEVKIT_CI
$env:DEVKIT_GHOST_ROOT = $DevkitRoot
if ($Ci) { $env:DEVKIT_CI = '1' } else { Remove-Item Env:DEVKIT_CI -ErrorAction SilentlyContinue }
Push-Location -LiteralPath $DevkitRoot
try {
    foreach ($check in $checks) {
        $name = [string]$check.name
        Write-Host ''
        Write-Host "---- custom: $name ----"
        if ($onActions -and -not (Test-CheckForCi $check)) {
            Write-Host 'skipped on GitHub Actions ("ci": false)'
            continue
        }
        if (@($check.PSObject.Properties.Name) -contains 'description') { Write-Host ([string]$check.description) }
        # The command is passed encoded, so that quotes in it survive the command line of Windows PowerShell 5.1.
        # Its exit code decides: a native program's code, 1 for a command that failed or does not exist.
        $script = "$($check.command)`r`n`$devkitOk = `$?`r`nif (`$null -ne `$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }`r`nif (-not `$devkitOk) { exit 1 }`r`nexit 0"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
        $ErrorActionPreference = 'Continue'
        & $powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($code -eq 3) {
            $skipped += $name
        } elseif ($code -ne 0) {
            $failed += $name
            if ($Ci) { Write-Host "::error title=custom check::$name failed (exit code $code)" }
        }
    }
} finally {
    Pop-Location
    $env:DEVKIT_GHOST_ROOT = $savedRoot
    $env:DEVKIT_CI = $savedCi
}

Write-Host ''
if ($skipped.Count -gt 0) { Write-Host "custom checks skipped (could not check): $($skipped -join ', ')" }
if ($failed.Count -gt 0) {
    Write-Host "custom checks FAILED: $($failed -join ', ')"
    exit 1
}
if ($skipped.Count -gt 0) { exit 3 }
Write-Host 'custom checks passed'
exit 0
