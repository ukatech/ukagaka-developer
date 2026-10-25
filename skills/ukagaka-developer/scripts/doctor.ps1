<#
.SYNOPSIS
    Checks the development environment and tells what is missing and how to get it.
.DESCRIPTION
    Read-only: nothing is installed or changed.
    Each item has a level: required (the checks cannot run without it), recommended, or optional.
    The items of the ghost's SHIORI (YAYA or SATORI) come from scripts/shiori/<name>/lib.ps1.
    Exit codes: 0 = all required items are ready, 1 = a required item is missing.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1 -Json
#>
[CmdletBinding()]
param(
    # Print the result as JSON (for agents).
    [switch]$Json,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/ignore.ps1')
. (Join-Path $PSScriptRoot 'lib/legacy-devkit.ps1')
Initialize-DevkitConsole

$items = New-Object System.Collections.Generic.List[object]
function Add-DoctorItem {
    param([string]$Id, [string]$Name, [string]$Level, [bool]$Ok, [string]$Purpose, [string]$Detail, [string]$Fix)
    $items.Add([pscustomobject]@{ id = $Id; name = $Name; level = $Level; ok = $Ok; purpose = $Purpose; detail = $Detail; fix = $Fix })
}

$ps = 'powershell -NoProfile -ExecutionPolicy Bypass -File'
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$isGitWorkingCopy = Test-Path -LiteralPath (Join-Path $DevkitRoot '.git')
$shioriId = Get-DevkitShiori
$shioriName = if ($shioriId) { (Get-DevkitShioriInfo $shioriId).Name } else { 'SHIORI' }
$tamacsPurpose = 'Loads the SHIORI dll without SSP: dictionary check, shiori.ps1'

# --- Windows ---------------------------------------------------------------------------
$isWindowsOs = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
Add-DoctorItem -Id 'windows' -Name 'Windows' -Level 'required' -Ok $isWindowsOs `
    -Purpose 'SSP, YAYA, SATORI and tamacs.exe run only on Windows' `
    -Detail ([Environment]::OSVersion.VersionString) `
    -Fix 'Use a Windows PC.'

# --- Windows PowerShell (runs the scripts of the skill) -------------------------------------
$windowsPowerShell = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
Add-DoctorItem -Id 'powershell' -Name 'Windows PowerShell' -Level 'required' -Ok ([bool]$windowsPowerShell) `
    -Purpose 'Runs the scripts of the skill' `
    -Detail $(if ($windowsPowerShell) { "PowerShell $($PSVersionTable.PSVersion) is running; powershell.exe found" } else { 'powershell.exe was not found' }) `
    -Fix 'Windows PowerShell is part of Windows. Check that it has not been removed or blocked.'

# --- ghost files (and the system dictionary of YAYA) ------------------------------------
if ($shioriId) {
    . (Join-Path (Get-DevkitShioriDir $shioriId) 'lib.ps1')
    Add-DevkitShioriDoctorItems -Ps $ps -IsGitWorkingCopy $isGitWorkingCopy
    $tamacsPurpose = $DevkitTamacsPurpose
} else {
    Add-DoctorItem -Id 'ghost' -Name 'ghost files' -Level 'required' -Ok $false `
        -Purpose 'The ghost itself, and a SHIORI that the skill supports (YAYA or SATORI)' `
        -Detail 'neither ghost/master/yaya.dll nor ghost/master/satori.dll was found, and descript.txt has no shiori key for them' `
        -Fix 'Work in the ghost root folder (the one that contains ghost/ and shell/). Other SHIORI are not supported yet.'
}

# --- GHOST.md --------------------------------------------------------------------------
$ghostProfile = Join-Path $DevkitRoot 'GHOST.md'
$profileState = 'ok'
if (-not (Test-Path -LiteralPath $ghostProfile -PathType Leaf)) {
    $profileState = 'missing'
} elseif ([IO.File]::ReadAllText($ghostProfile, $DevkitUtf8).Contains($DevkitGhostTemplateMarker)) {
    $profileState = 'template'
}
Add-DoctorItem -Id 'ghost-profile' -Name 'GHOST.md' -Level 'recommended' -Ok ($profileState -eq 'ok') `
    -Purpose 'Ghost-specific notes that agents read before working: characters, surfaces, license, dictionary files' `
    -Detail $(if ($profileState -eq 'ok') { 'filled in' } elseif ($profileState -eq 'template') { 'still the blank template' } else { 'missing' }) `
    -Fix $(if ($profileState -eq 'missing') { "Run: $ps scripts/init-ghost.ps1 (it creates GHOST.md and the other starter files), then fill GHOST.md in from the dictionaries and the shell (references/workflows/setup.md)." } else { 'Fill it in from the dictionaries and the shell, confirm it with the author, then remove the devkit:ghost-template marker line (references/workflows/setup.md).' })

# --- the old development kit ------------------------------------------------------------
$legacyManifest = Join-Path $DevkitRoot $DevkitManifestName
$legacyKit = Test-Path -LiteralPath $legacyManifest -PathType Leaf
$conflicts = @(Get-DevkitConflictFiles $DevkitRoot)
$legacyDetail = 'none'
if ($legacyKit) { $legacyDetail = 'the old AI development kit (tools/devkit.json) is still in this folder' }
if ($conflicts.Count -gt 0) { $legacyDetail += '; unmerged files: ' + ($conflicts -join ', ') }
Add-DoctorItem -Id 'legacy-devkit' -Name 'old development kit' -Level 'recommended' -Ok (-not $legacyKit -and $conflicts.Count -eq 0) `
    -Purpose 'The old kit copied tools/, AGENTS.md and docs/agents/ into the ghost; the skill replaces it, and both would give the agent two sets of instructions' `
    -Detail $legacyDetail `
    -Fix "Run: $ps scripts/migrate-from-devkit.ps1 (a dry run; it changes nothing), then follow references/workflows/migrate-from-devkit.md."

# --- tamacs.exe (built from scripts/lib/tamacs.cs on first use; doctor does not build it) ---
$tamacsExe = Get-DevkitTamacsExpectedPath
$tamacsBuilt = Test-Path -LiteralPath $tamacsExe -PathType Leaf
$csc = Get-DevkitCscPath
Add-DoctorItem -Id 'tamacs' -Name 'tamacs.exe' -Level 'required' -Ok ($tamacsBuilt -or [bool]$csc) `
    -Purpose $tamacsPurpose `
    -Detail $(if ($tamacsBuilt) { "built in $DevkitBinDir" } elseif ($csc) { "built from scripts/lib/tamacs.cs on first use with $csc, into $DevkitBinDir" } else { 'not built, and csc.exe of the .NET Framework 4 was not found' }) `
    -Fix 'csc.exe comes with the .NET Framework 4.8, which is part of Windows. Turn it on in "Turn Windows features on or off" if it has been turned off.'

# --- SSP -------------------------------------------------------------------------------
$ssp = Resolve-SspPath
$sspOk = [bool]$ssp
$sspFix = 'Get SSP from https://ssp.shillest.net/ . If it is already installed, ask where ssp.exe is and write it to local.json in ' + $DevkitHome + ' as {"sspPath": "C:\\path\\to\\ssp.exe"} (or set SSP_PATH).'
$sspDetail = 'not found'
if ($ssp) {
    $sspVersion = Get-DevkitSspVersion $ssp.Path
    $sspDetail = "$($ssp.Path) $(if ($sspVersion) { Format-DevkitSspVersion $sspVersion } else { '(version unknown)' }) (found via $($ssp.Source))"
    $sspRecommended = Format-DevkitSspVersion $DevkitSspRecommendedVersion
    if ($sspVersion -and $sspVersion -lt $DevkitSspRecommendedVersion) {
        $sspOk = $false
        $sspDetail += "; older than $sspRecommended"
        $sspFix = "Update SSP to $sspRecommended or later (https://ssp.shillest.net/ , or the network update of SSP itself). The scripts of the skill are written for it, and may fail or miss problems with older versions."
    }
} else {
    $local = Get-DevkitLocalConfig
    if ($env:SSP_PATH -or ($local -and ($local.PSObject.Properties.Name -contains 'sspPath'))) {
        $sspDetail = 'not found; the path in SSP_PATH or local.json does not exist'
    }
}
Add-DoctorItem -Id 'ssp' -Name "SSP $(Format-DevkitSspVersion $DevkitSspRecommendedVersion)+" -Level 'recommended' -Ok $sspOk `
    -Purpose 'Shell check (check-shell.ps1), running the ghost (run-ssp.ps1), trying talks (sstp.ps1) and reading its logs (ssp-log.ps1), building the nar and network update files (build-nar.ps1)' `
    -Detail $sspDetail `
    -Fix $sspFix

# --- git -------------------------------------------------------------------------------
$git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$gitDetail = 'not found'
if ($git) { $gitDetail = (Invoke-DevkitProcess -FilePath $git.Source -Arguments @('--version') -TimeoutSeconds 30).StdOut.Trim() }
Add-DoctorItem -Id 'git' -Name 'Git' -Level 'recommended' -Ok ([bool]$git) `
    -Purpose 'Version history, GitHub (checks and automatic releases), and the system dictionary submodule of a YAYA ghost in a git clone' `
    -Detail $gitDetail `
    -Fix $(if ($hasWinget) { 'After the user agrees, run: winget install --id Git.Git -e (then restart the terminal)' } else { 'Download from https://git-scm.com/download/win' })

# --- output ----------------------------------------------------------------------------
$missingRequired = @($items | Where-Object { $_.level -eq 'required' -and -not $_.ok })
$ready = $missingRequired.Count -eq 0
if ($Json) {
    Write-Output ([pscustomobject]@{ ready = $ready; root = $DevkitRoot; shiori = $shioriId; home = $DevkitHome; gitWorkingCopy = $isGitWorkingCopy; winget = $hasWinget; items = $items.ToArray() } | ConvertTo-Json -Depth 4)
} else {
    Write-Host "ghost   : $DevkitRoot ($shioriName)"
    Write-Host "home    : $DevkitHome (compiled tools and local.json)"
    foreach ($item in $items) {
        $mark = if ($item.ok) { '[ok]     ' } elseif ($item.level -eq 'required') { '[MISSING]' } else { '[missing]' }
        Write-Host ('{0} {1} ({2}): {3}' -f $mark, $item.name, $item.level, $item.detail)
        if (-not $item.ok) {
            Write-Host "          purpose: $($item.purpose)"
            Write-Host "          fix    : $($item.fix)"
        }
    }
    if ($ready) {
        Write-Host 'doctor: all required items are ready'
    } else {
        Write-Host "doctor: missing required item(s): $(($missingRequired | ForEach-Object { $_.name }) -join ', ')"
    }
}
if ($ready) { exit 0 }
exit 1
