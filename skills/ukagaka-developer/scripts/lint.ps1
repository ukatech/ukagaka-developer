<#
.SYNOPSIS
    Checks the dictionaries without running them: YAYA looks for undefined / unused variables and functions, SATORI
    runs ShioriLint (wrong jump targets, wrong variable assignment lines, names that nothing defines, and so on),
    KAWARI runs the static check of kosui --check (entries and commands that nothing defines, unquoted regex parts).
.DESCRIPTION
    A front for the SHIORI that the skill supports: it finds out whether the ghost runs on YAYA, SATORI or KAWARI
    (the shiori key of ghost/master/descript.txt, or the dll in ghost/master) and runs
    scripts/shiori/<yaya|satori|kawari>/lint.ps1 with the same arguments. The options differ between them; see the
    help of those scripts (Get-Help scripts/shiori/yaya/lint.ps1, Get-Help scripts/shiori/satori/lint.ps1,
    Get-Help scripts/shiori/kawari/lint.ps1) and
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
