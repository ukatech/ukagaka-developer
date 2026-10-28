<#
.SYNOPSIS
    Sends one SHIORI request to the ghost's SHIORI dll with tamacs.exe, without SSP (YAYA, SATORI or KAWARI).
.DESCRIPTION
    A front for the SHIORI that the skill supports: it finds out whether the ghost runs on YAYA, SATORI or KAWARI
    (the shiori key of ghost/master/descript.txt, or the dll in ghost/master) and runs
    scripts/shiori/<yaya|satori|kawari>/shiori.ps1 with the same arguments. The options differ between them; see the
    help of those scripts (Get-Help scripts/shiori/yaya/shiori.ps1, Get-Help scripts/shiori/satori/shiori.ps1,
    Get-Help scripts/shiori/kawari/shiori.ps1) and
    references/commands.md. -GhostRoot <folder> names the ghost root when the current folder is not inside it.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori.ps1
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
Initialize-DevkitConsole -Arguments $args
$target = Resolve-DevkitShioriScript 'shiori' 'shiori'
if (-not $target.Path) { exit $target.Code }
& $target.Path @args
exit $LASTEXITCODE
