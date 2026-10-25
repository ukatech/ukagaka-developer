<#
.SYNOPSIS
    Looks for undefined / unused variables and functions (YAYA only).
.DESCRIPTION
    A front for the two SHIORI that the skill supports: it finds out whether the ghost runs on YAYA or SATORI
    (the shiori key of ghost/master/descript.txt, or the dll in ghost/master) and runs
    scripts/shiori/<yaya|satori>/lint.ps1 with the same arguments. The options differ between the two; see the help
    of those scripts (Get-Help scripts/shiori/yaya/lint.ps1, Get-Help scripts/shiori/satori/lint.ps1) and
    references/commands.md. -GhostRoot <folder> names the ghost root when the current folder is not inside it.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
Initialize-DevkitConsole -Arguments $args
$target = Resolve-DevkitShioriScript 'lint' 'lint'
if (-not $target.Path) { exit $target.Code }
& $target.Path @args
exit $LASTEXITCODE
