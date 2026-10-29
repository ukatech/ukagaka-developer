<#
.SYNOPSIS
    Checks the KAWARI dictionaries without running their words: the static check (lint) of kosui --check.
.DESCRIPTION
    kosui.exe (KAWARI Phase 9.2.0 or later; scripts/setup.ps1 downloads it) loads the dictionaries in its safe mode
    and then walks every word and =kis zone, also those that only an event would run, and reports:
      K-W2001  a reference to an entry that is defined nowhere (${name}, $name[0], get / size and so on)
      K-W2002  a command name that is neither a built-in command nor a defined function (a misspelled command,
               $([ ... ]) of Phase 7, an else left alone after ");")
      K-W2003  an unquoted ( ) in the arguments of regex_* (KAWARI removes the brackets: write "(a)")
      K-W2004  an unquoted ${N} in the replacement of regex_replace
    Names that are put together at run time (${a.${b}}) are not checked; a name that only a literal prefix shows
    (launch_a_${n}) counts as defined by that prefix. A finding that is not a mistake can be silenced with a comment
    line right above the line (KAWARI comments are whole lines that start with #):
        # lint:disable-next-line=K-W2001, K-W2003
    The errors and warnings of loading are reported by scripts/check-dic.ps1, not here.
    Exit codes: 0 = OK (findings are warnings; with -Strict they fail), 1 = findings with -Strict, or kosui.exe could
    not check the dictionaries, 3 = not checked (kosui.exe is not installed or too old).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1
#>
[CmdletBinding()]
param(
    # Folder that contains kawarirc.kis (default: ghost/master).
    [string]$GhostDir,
    # Fail when there are findings.
    [switch]$Strict,
    # Emit GitHub Actions annotations.
    [switch]$Ci,
    [int]$TimeoutSeconds = 120,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib.ps1')
Initialize-DevkitConsole

$ghost = Resolve-DevkitShioriGhostDir 'lint' $GhostDir 'kawarirc.kis'
if (-not $ghost.Ok) { exit $ghost.Code }
$GhostDir = $ghost.GhostDir
$kosui = Get-DevkitShioriTool 'lint' 'kosui'
if (-not $kosui.Path) { exit 3 }

$result = Invoke-DevkitKosuiCheck -GhostDir $GhostDir -TimeoutSeconds $TimeoutSeconds
if ($result.TimedOut) {
    Write-Host "lint: FAILED - kosui.exe timed out after $TimeoutSeconds seconds (an endless loop in a =kis zone?)"
    exit 1
}
if ($result.ExitCode -eq 3 -or -not $result.Parsed) {
    Write-Host "lint: FAILED - kosui.exe could not check the dictionaries (exit code $($result.ExitCode)): $($result.Raw.Trim())"
    exit 1
}
$findings = @($result.Diagnostics | Where-Object { Test-DevkitKawariLintCode $_.Code } | Sort-Object File, Line)
[void](Write-DevkitKawariDiagnostics $findings 'KAWARI lint' -Ci:$Ci)
$others = @($result.Diagnostics).Count - $findings.Count
$note = if ($others -gt 0) { "; $others error(s)/warning(s) of loading, see scripts/check-dic.ps1" } else { '' }
if ($Strict -and $findings.Count -gt 0) {
    Write-Host "lint: FAILED ($($findings.Count) finding(s)$note)"
    exit 1
}
Write-Host "lint: OK ($($findings.Count) finding(s)$note)"
exit 0
