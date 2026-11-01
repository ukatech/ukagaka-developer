<#
.SYNOPSIS
    Runs check-dic, check-shell and lint in order (and the checks of the ghost itself, when it defines some).
.DESCRIPTION
    check-dic and lint go to the ghost's SHIORI (YAYA, SATORI or KAWARI). The lint of SATORI is ShioriLint (satori.dll
    Mc206-1 or later); with an older satori.dll the step is skipped. KAWARI uses kosui.exe for both (setup.ps1).
    A ghost that has .github/ghost-checks.json gets a fourth step, check-custom, which here only lists its commands
    (they are programs of the ghost); run them with scripts/check-custom.ps1 -AllowCustom after reading them.
    A ghost without that file runs the same steps as before.
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
if ($shioriId) { . (Join-Path (Get-DevkitShioriDir $shioriId) 'lib.ps1') }
$steps = New-Object System.Collections.Generic.List[string]
$steps.Add('check-dic')
if (-not $SkipShell) { $steps.Add('check-shell') }
if (-not $SkipLint) { $steps.Add('lint') }
if (Test-Path -LiteralPath (Join-Path $DevkitRoot '.github/ghost-checks.json') -PathType Leaf) { $steps.Add('check-custom') }

$powershell = (Get-Process -Id $PID).Path
$failed = @()
$skipped = @()
$ErrorActionPreference = 'Continue'
foreach ($step in $steps) {
    Write-Host ''
    Write-Host "==== $step ===="
    $stepArgs = @('-GhostRoot', $DevkitRoot)
    if ($Run -and $step -eq 'check-dic' -and $DevkitCheckDicRunArgument) { $stepArgs += $DevkitCheckDicRunArgument }
    & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "$step.ps1") @stepArgs
    $code = $LASTEXITCODE
    if ($code -eq 3) { $skipped += $step } elseif ($code -ne 0) { $failed += $step }
}

Write-Host ''
Write-Host '==== summary ===='
$skippedTools = @($skipped | Where-Object { $_ -ne 'check-custom' })
if ($skippedTools.Count -gt 0) { Write-Host "skipped (tool not available): $($skippedTools -join ', ')" }
if ($skipped -contains 'check-custom') { Write-Host 'skipped (not run on purpose): check-custom - the commands of the ghost were listed; read them, then run scripts/check-custom.ps1 -AllowCustom' }
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')"
    exit 1
}
if ($RequireAll -and $skipped.Count -gt 0) { exit 1 }
Write-Host 'all checks passed'
exit 0
