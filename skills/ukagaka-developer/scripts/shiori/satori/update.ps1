<#
.SYNOPSIS
    Updates SATORI: ghost/master/satori.dll and satorite.exe (and saori/ssu.dll where a ghost still has one), and verifies them with check-dic.
.DESCRIPTION
    The files come from satori.zip of https://github.com/ukatech/satoriya-shiori/releases (or -Tag). Releases are
    named McXYY-Z (for example Mc201-5): X = 1 is the ACP build (Shift_JIS dictionaries; Mc1XX), X = 2 is the Unicode
    build (UTF-8 dictionaries; Mc2XX). A release is taken from the build of the current satori.dll (-Variant takes the
    other one): the highest version, pre-releases included (-StableOnly leaves them out). With no satori.dll, the
    Unicode build is used.
    Only files that the ghost already has are replaced: satori.dll (a ghost without it needs -Force), satorite.exe and
    saori/ssu.dll (the current satori.dll has ssu built in, so ghosts usually have no ssu.dll and it is not added).
    The version of each file (the "phase McXYY-Z" string inside satori.dll and satorite.exe; the file version of
    ssu.dll) is shown before and after. A release that is older than the current file is not installed, unless -Tag,
    -Variant or -Force is given.
    Switching between the ACP and the Unicode build changes how dictionaries are read: a Unicode build reads
    UTF-8 (BOM-less too) or Shift_JIS dictionaries, an ACP build depends on the system code page. Check charset in
    descript.txt afterwards.
    The dictionaries are checked with scripts/check-dic.ps1 after the files are replaced; when the check fails, the
    old files are put back. Close the ghost in SSP first: a loaded satori.dll cannot be replaced.
    -DryRun (or -WhatIf) downloads the release and shows what would change, and changes nothing.
    Exit codes: 0 = updated / already up to date / dry run, 1 = failed.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1 -DryRun
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1 -Tag Mc201-5
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1 -Variant Acp -StableOnly -DryRun
#>
[CmdletBinding()]
param(
    # Release tag of ukatech/satoriya-shiori (default: the newest release of the build of the current satori.dll).
    [string]$Tag,
    # Build to take: Unicode (Mc2XX) or Acp (Mc1XX). Default: the build of the current satori.dll, else Unicode.
    [ValidateSet('Unicode', 'Acp')]
    [string]$Variant,
    # Leave pre-releases out.
    [switch]$StableOnly,
    # Folder that contains satori.dll (default: ghost/master).
    [string]$GhostDir,
    # Use this satori.zip instead of downloading one (the release is then not looked up).
    [string]$ZipPath,
    [Alias('WhatIf')]
    [switch]$DryRun,
    # Replace files even when they are the same or older, and add satori.dll when the ghost has none.
    [switch]$Force,
    # Do not run check-dic after replacing the files.
    [switch]$SkipCheck,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib.ps1')
. (Join-Path $PSScriptRoot '../../lib/update-common.ps1')
Initialize-DevkitConsole

if ($Tag -and $Variant) {
    Write-Host 'update-satori: FAILED - -Tag already chooses the release; do not give -Variant with it'
    exit 1
}
if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
$GhostDir = (Resolve-DevkitFullPath $GhostDir).TrimEnd('\', '/')
$dll = Join-Path $GhostDir 'satori.dll'
$repository = 'ukatech/satoriya-shiori'

# Files of the release (relative to ghost/master) and whether a ghost that lacks them gets them.
$parts = @(
    [pscustomobject]@{ Path = 'satori.dll'; Zip = 'satori.dll'; Optional = $false },
    [pscustomobject]@{ Path = 'satorite.exe'; Zip = 'satorite.exe'; Optional = $true },
    [pscustomobject]@{ Path = 'saori/ssu.dll'; Zip = 'saori/ssu.dll'; Optional = $true }
)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# Version of a release tag such as Mc201-5 (or Mc172-1A): a [version] of (XYY, Z) and the build, or $null.
function Get-SatoriTagInfo([string]$TagName) {
    if ($TagName -match '^Mc(\d)(\d{2})-(\d+)') {
        return [pscustomobject]@{ Number = (New-Object System.Version(([int]($matches[1] + $matches[2])), [int]$matches[3])); Variant = $(if ([int]$matches[1] -ge 2) { 'Unicode' } else { 'ACP' }) }
    }
    return $null
}

function Get-ReleaseLabel($Release) {
    return "$($Release.tag_name)$(if ($Release.prerelease) { ' (pre-release)' })"
}

$exitCode = 0
$work = New-DevkitWorkDir 'satori-update'
try {
    $hasOld = Test-Path -LiteralPath $dll
    $oldVersion = if ($hasOld) { Get-DevkitSatoriVersion $dll } else { $null }
    Write-Host "current : $(if ($oldVersion) { $oldVersion.Text } else { '(no satori.dll)' })"
    if ($oldVersion -and $oldVersion.Variant -eq 'ACP' -and $Variant -ine 'Unicode') {
        Write-Host 'update-satori: NOTICE - only the Unicode build (Mc2XX) is still updated; the ACP build (Mc1XX) is not. Updating to the Unicode build is strongly recommended: -Variant Unicode (the dictionaries and the save data work as they are, but the save data cannot go back to the ACP build, so back them up first)'
    }
    if (-not $hasOld -and -not $Force) {
        Write-Host "update-satori: FAILED - satori.dll was not found in $GhostDir (-Force adds it)"
        exit 1
    }

    # --- the release ---------------------------------------------------------------------------
    $release = $null
    $zipPath = $null
    if ($ZipPath) {
        $zipPath = (Resolve-DevkitFullPath $ZipPath)
        if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw "-ZipPath was not found: $zipPath" }
        Write-Host "release : (local file) $zipPath"
    } else {
        $api = "https://api.github.com/repos/$repository"
        if ($Tag) {
            $release = Invoke-DevkitGitHubApi ($api + '/releases/tags/' + [uri]::EscapeDataString($Tag))
        } else {
            $wanted = if ($Variant) { $Variant } elseif ($oldVersion -and $oldVersion.Variant -ne 'unknown') { $oldVersion.Variant } else { 'Unicode' }
            $wanted = if ($wanted -ieq 'Acp') { 'ACP' } else { $wanted }
            $candidates = New-Object System.Collections.Generic.List[object]
            # foreach unrolls the JSON array (Windows PowerShell 5.1 returns it as one object).
            foreach ($item in (Invoke-DevkitGitHubApi ($api + '/releases?per_page=100'))) {
                if ($item.draft -or -not @($item.assets | Where-Object { $_.name -eq 'satori.zip' }).Count) { continue }
                if ($StableOnly -and $item.prerelease) { continue }
                $info = Get-SatoriTagInfo ([string]$item.tag_name)
                if (-not $info -or $info.Variant -ne $wanted) { continue }
                $candidates.Add([pscustomobject]@{ Release = $item; Number = $info.Number; Published = [datetime]$item.published_at })
            }
            $chosen = @($candidates | Sort-Object -Property @{ Expression = 'Number'; Descending = $true }, @{ Expression = 'Published'; Descending = $true }) | Select-Object -First 1
            if (-not $chosen) { throw "no $wanted release of $repository has satori.zip$(if ($StableOnly) { ' (-StableOnly leaves pre-releases out)' })" }
            $release = $chosen.Release
            Write-Host "build   : $wanted$(if ($Variant) { ' (given by -Variant)' } else { ' (that of the current satori.dll)' })"
        }
        $asset = @($release.assets | Where-Object { $_.name -eq 'satori.zip' }) | Select-Object -First 1
        if (-not $asset) { throw "satori.zip was not found in release $($release.tag_name)" }
        Write-Host "release : $(Get-ReleaseLabel $release)"
        Write-Host "notes   : $($release.html_url)"
        $zipPath = Join-Path $work 'satori.zip'
        Save-DevkitReleaseAsset $asset $zipPath
    }

    # --- unpack and compare ------------------------------------------------------------------
    $unpacked = Join-Path $work 'unpacked'
    New-Item -ItemType Directory -Path $unpacked | Out-Null
    $zipFiles = @{}
    foreach ($part in $parts) { $zipFiles[$part.Zip] = Join-Path $unpacked $part.Path.Replace('/', '\') }
    [void](Expand-DevkitZipFile $zipPath $zipFiles)
    $newDll = Join-Path $unpacked 'satori.dll'
    if (-not (Test-Path -LiteralPath $newDll)) { throw 'satori.dll is not in satori.zip' }
    $newVersion = Get-DevkitSatoriVersion $newDll
    Write-Host "new     : $($newVersion.Text)"

    # A build switch or an older release is not taken silently.
    $skipAll = $false
    if ($oldVersion -and $oldVersion.Number -and $newVersion.Number) {
        if ($oldVersion.Variant -ne $newVersion.Variant) {
            Write-Host "update-satori: note - this switches from the $($oldVersion.Variant) build to the $($newVersion.Variant) build; check charset in descript.txt and the dictionaries afterwards"
        } elseif ($newVersion.Number -lt $oldVersion.Number -and -not $Tag -and -not $Variant -and -not $Force) {
            Write-Host 'update-satori: the release is older than the current satori.dll, so nothing was changed. -Tag or -Force installs it'
            $skipAll = $true
        }
    }

    $plan = New-Object System.Collections.Generic.List[object]
    foreach ($part in $parts) {
        $new = Join-Path $unpacked $part.Path.Replace('/', '\')
        $old = Join-Path $GhostDir $part.Path.Replace('/', '\')
        if (-not (Test-Path -LiteralPath $new)) { continue }
        $exists = Test-Path -LiteralPath $old
        if (-not $exists -and $part.Optional) { continue }
        if (-not $exists -and -not $Force) { continue }
        $oldText = if ($exists) { (Get-DevkitSatoriVersion $old).Tag } else { '(none)' }
        $newText = (Get-DevkitSatoriVersion $new).Tag
        $same = $exists -and ((Get-FileHash -LiteralPath $old -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $new -Algorithm SHA256).Hash)
        $action = if ($same -and -not $Force) { 'same' } else { 'replace' }
        $plan.Add([pscustomobject]@{ Part = $part; New = $new; Old = $old; Exists = $exists; Action = $action; OldText = $oldText; NewText = $newText })
        Write-Host ('  {0,-8} ghost/master/{1}  {2} -> {3}' -f $action, $part.Path, $oldText, $newText)
    }
    $todo = @($plan | Where-Object { $_.Action -eq 'replace' })

    if ($skipAll -or $todo.Count -eq 0) {
        if (-not $skipAll) { Write-Host 'update-satori: SATORI is already up to date' }
    } elseif ($DryRun) {
        Write-Host 'update-satori: dry run, nothing changed'
    } else {
        # --- apply -------------------------------------------------------------------------
        $check = if ($SkipCheck) { $null } else { { param($Dir) Invoke-DevkitDictionaryCheck 'satori' $Dir } }
        $install = Install-DevkitFiles -Items $todo -WorkDir $work -Check $check -CheckArgument $GhostDir
        if ($install.Status -eq 'copy-failed') {
            Write-Host "update-satori: could not replace ghost/master/$($install.Failed.Part.Path) ($($install.Error)). If SSP is running this ghost, close the ghost and retry."
        } elseif ($install.Status -eq 'check-failed') {
            Write-Host 'update-satori: the dictionary check failed with the new files; putting the old ones back'
        } elseif ($install.CheckCode -eq 3) {
            Write-Host 'update-satori: WARNING - the dictionaries could not be checked (tamacs.exe), so the new files were not verified'
        }
        if ($install.Status -ne 'replaced') {
            Write-Host 'update-satori: restored the previous files'
            $exitCode = 1
        } else {
            foreach ($item in $todo) {
                Write-Host "update-satori: updated ghost/master/$($item.Part.Path) $($item.OldText) -> $((Get-DevkitSatoriVersion $item.Old).Tag)"
            }
        }
    }
} catch {
    Write-Host "update-satori: FAILED - $($_.Exception.Message)"
    $exitCode = 1
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit $exitCode
