<#
.SYNOPSIS
    Creates the starter files of a ghost that are missing: GHOST.md, AGENTS.md, CLAUDE.md, .narignore, .updateignore,
    .gitattributes and .editorconfig (from templates/ of the skill).
.DESCRIPTION
    Files that already exist are never changed. The templates depend on the SHIORI of the ghost (YAYA, SATORI or
    KAWARI).
    GHOST.md is created as a blank template (it starts with a marker line); fill it in from the dictionaries and the
    shell (references/workflows/setup.md), then remove the marker.
    -NarignoreDevBlock adds the block of development files (GHOST.md, AGENTS.md, .claude/, .agents/, build/ and so on)
    to an existing .narignore that does not have it, so that they are not shipped in the nar. It also replaces the
    "include:tools/devkit.narignore" line that the old development kit wrote.
    -Workflow also creates .github/workflows/auto_check.yml (the dictionary check on GitHub Actions) when it is missing.
    -DryRun only prints what would be done.
    Exit codes: 0 = done (or nothing to do), 1 = failed.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/init-ghost.ps1 -DryRun
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/init-ghost.ps1 -NarignoreDevBlock -Workflow
#>
[CmdletBinding()]
param(
    [switch]$NarignoreDevBlock,
    [switch]$Workflow,
    [switch]$DryRun,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/ghost-files.ps1')
Initialize-DevkitConsole

$shioriId = Get-DevkitShiori
if (-not $shioriId) {
    Write-Host "init-ghost: FAILED - this ghost has no SHIORI that the skill supports. Supported: $DevkitShioriSupported."
    exit 1
}
$mode = if ($DryRun) { 'would create' } else { 'created' }

foreach ($file in (Get-DevkitStarterFiles $shioriId $DevkitRoot -OnlyMissing)) {
    if (-not $DryRun) { Write-DevkitTextFile (Join-Path $DevkitRoot $file.Path) $file.Text }
    Write-Host "[$mode] $($file.Path)"
}
if ($Workflow) {
    $workflowPath = Join-Path $DevkitRoot '.github/workflows/auto_check.yml'
    if (Test-Path -LiteralPath $workflowPath) {
        Write-Host '[exists] .github/workflows/auto_check.yml'
    } else {
        if (-not $DryRun) { Write-DevkitTextFile $workflowPath (Read-DevkitTemplate 'github/auto_check.yml') }
        Write-Host "[$mode] .github/workflows/auto_check.yml"
    }
}

$narignorePath = Join-Path $DevkitRoot '.narignore'
if ($NarignoreDevBlock -and (Test-Path -LiteralPath $narignorePath)) {
    $current = [IO.File]::ReadAllText($narignorePath, $DevkitUtf8)
    if (Test-DevkitNarignoreHasDevBlock $current) {
        Write-Host '[ok] .narignore already has the block of development files'
    } else {
        if (-not $DryRun) { Write-DevkitTextFile $narignorePath (Add-DevkitNarignoreDevBlock $current) }
        Write-Host "[$(if ($DryRun) { 'would update' } else { 'updated' })] .narignore (development block added)"
    }
} elseif (Test-Path -LiteralPath $narignorePath) {
    $current = [IO.File]::ReadAllText($narignorePath, $DevkitUtf8)
    if (-not (Test-DevkitNarignoreHasDevBlock $current)) {
        Write-Host '[note] .narignore has no block of development files (GHOST.md, AGENTS.md, .claude/, .agents/ would be shipped in the nar). Run with -NarignoreDevBlock to add it.'
    }
}
exit 0
