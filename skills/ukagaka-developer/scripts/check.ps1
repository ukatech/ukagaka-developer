<#
.SYNOPSIS
    Runs check-dic, check-shell and (YAYA only) lint in order.
.DESCRIPTION
    check-dic and lint go to the ghost's SHIORI (YAYA or SATORI). SATORI has no lint step.
    Exit codes: 0 = all passed (steps whose tool is missing are reported as skipped),
    1 = a step failed, or a step was skipped while -RequireAll is given.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipShell,
    [switch]$SkipLint,
    [switch]$RequireAll,
    # SATORI only: also run every sentence with a plain name (check-dic -Run).
    [switch]$Run,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
Initialize-DevkitConsole

$shioriId = Get-DevkitShiori
$steps = New-Object System.Collections.Generic.List[string]
$steps.Add('check-dic')
if (-not $SkipShell) { $steps.Add('check-shell') }
if (-not $SkipLint -and $shioriId -eq 'yaya') { $steps.Add('lint') }

$powershell = (Get-Process -Id $PID).Path
$failed = @()
$skipped = @()
$ErrorActionPreference = 'Continue'
foreach ($step in $steps) {
    Write-Host ''
    Write-Host "==== $step ===="
    $stepArgs = @('-GhostRoot', $DevkitRoot)
    if ($Run -and $step -eq 'check-dic' -and $shioriId -eq 'satori') { $stepArgs += '-Run' }
    & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "$step.ps1") @stepArgs
    $code = $LASTEXITCODE
    if ($code -eq 3) { $skipped += $step } elseif ($code -ne 0) { $failed += $step }
}

Write-Host ''
Write-Host '==== summary ===='
if ($skipped.Count -gt 0) { Write-Host "skipped (tool not available): $($skipped -join ', ')" }
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')"
    exit 1
}
if ($RequireAll -and $skipped.Count -gt 0) { exit 1 }
Write-Host 'all checks passed'
exit 0
