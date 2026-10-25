<#
.SYNOPSIS
    Updates the SHIORI of the ghost: yaya.dll and the system dictionary (YAYA), or satori.dll (SATORI).
.DESCRIPTION
    A front for the two SHIORI that the skill supports: it finds out whether the ghost runs on YAYA or SATORI
    (the shiori key of ghost/master/descript.txt, or the dll in ghost/master) and runs
    scripts/shiori/<yaya|satori>/update.ps1 with the same arguments. The options differ between the two; see the help
    of those scripts (Get-Help scripts/shiori/yaya/update.ps1, Get-Help scripts/shiori/satori/update.ps1) and
    references/commands.md. -GhostRoot <folder> names the ghost root when the current folder is not inside it.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
Initialize-DevkitConsole -Arguments $args
$target = Resolve-DevkitShioriScript 'update' 'update-shiori'
if (-not $target.Path) { exit $target.Code }
& $target.Path @args
exit $LASTEXITCODE
