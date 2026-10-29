<#
.SYNOPSIS
    Updates KAWARI: ghost/master/shiori.dll, and verifies it.
.DESCRIPTION
    shiori.dll comes from kawari-X.Y.Z.zip of https://github.com/ukatech/kawari/releases: the latest release, or -Tag
    (for example v9.2.0). Only shiori.dll is replaced; the zip has no dictionaries. kosui.exe (the dictionary check)
    is updated by scripts/setup.ps1, not here.
    The version of the current and the new shiori.dll is shown (the file version; Phase 8.2.8 and older have none). A
    release that is older than the current file is not installed, unless -Tag or -Force is given.
    Phase 8 to Phase 9: the dictionaries run unchanged, but shiori.dll of Phase 9 writes save files (save, savecrypt)
    in UTF-8 with a BOM, which Phase 8.2.9 and older cannot read. Going back to Phase 8 after the ghost has saved
    breaks its saved data, so the save files are worth a backup before the first run.
    Before the file is replaced, the new shiori.dll is loaded in an empty temporary folder (a kawarirc.kis that defines
    nothing, so no dictionary code and no SAORI of the ghost runs) and asked for the "version" resource; when it does
    not answer, nothing is changed. After the file is replaced, the dictionaries are checked with
    scripts/check-dic.ps1 to show their state; that check runs on kosui.exe (the latest KAWARI), not on the new
    shiori.dll, so it does not decide the update. Close the ghost in SSP first: a loaded shiori.dll cannot be replaced.
    -DryRun (or -WhatIf) downloads the release and shows what would change, and changes nothing.
    Exit codes: 0 = updated / already up to date / dry run, 1 = failed.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1 -DryRun
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-shiori.ps1 -Tag v9.2.0
#>
[CmdletBinding()]
param(
    # Release tag of ukatech/kawari (default: the latest release).
    [string]$Tag,
    # Folder that contains shiori.dll (default: ghost/master).
    [string]$GhostDir,
    # Use this kawari-X.Y.Z.zip instead of downloading one (the release is then not looked up).
    [string]$ZipPath,
    [Alias('WhatIf')]
    [switch]$DryRun,
    # Replace the file even when it is the same or older.
    [switch]$Force,
    # Do not try the new shiori.dll before replacing it, nor check the dictionaries after.
    [switch]$SkipCheck,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib.ps1')
. (Join-Path $PSScriptRoot '../../lib/update-common.ps1')
Initialize-DevkitConsole

if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
$GhostDir = (Resolve-DevkitFullPath $GhostDir).TrimEnd('\', '/')
$dll = Join-Path $GhostDir 'shiori.dll'
$repository = 'ukatech/kawari'

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# Loads a shiori.dll in an empty folder (with a kawarirc.kis that defines nothing, so no code of the ghost runs: no
# =kis zone, no SAORI) and asks for the "version" resource, which KAWARI answers by itself. Returns $true when it
# answered.
function Test-NewShiori([string]$Dll) {
    $tamacs = Get-DevkitTamacs
    if (-not $tamacs.Path) {
        Write-Host "update-kawari: WARNING - the new shiori.dll could not be tried: $($tamacs.Error)"
        return $true
    }
    $probe = Join-Path $work 'probe'
    New-Item -ItemType Directory -Force -Path $probe | Out-Null
    Copy-Item -LiteralPath $Dll -Destination (Join-Path $probe 'shiori.dll') -Force
    [IO.File]::WriteAllText((Join-Path $probe 'kawarirc.kis'), "# probe of update-shiori.ps1`n", $DevkitUtf8)
    $request = New-DevkitShioriRequest -Id 'version'
    $run = Invoke-DevkitProcess -FilePath $tamacs.Path -Arguments @((Join-Path $probe 'shiori.dll'), '-r', '--no-loghandler') `
        -WorkingDirectory $probe -InputText $request -UnsetEnvironment @('GITHUB_ACTIONS') -TimeoutSeconds 60
    if ($run.TimedOut -or $run.ExitCode -ne 0 -or $run.StdOut -notmatch '^SHIORI/3\.0 200[^\n]*\r?\n(?:.*\r?\n)*?Value: ?(\S+)') {
        Write-Host "update-kawari: the new shiori.dll did not answer a request (tamacs.exe exit code $($run.ExitCode)): $($run.StdErr.Trim())"
        return $false
    }
    Write-Host "update-kawari: the new shiori.dll loads and answers (version $($matches[1]))"
    return $true
}

$exitCode = 0
$work = New-DevkitWorkDir 'kawari-update'
try {
    if (-not (Test-Path -LiteralPath $dll)) {
        Write-Host "update-kawari: FAILED - shiori.dll was not found in $GhostDir"
        exit 1
    }
    $oldVersion = Get-DevkitKawariVersion $dll
    Write-Host "current : shiori.dll $($oldVersion.Text)"

    # --- the release ---------------------------------------------------------------------------
    if ($ZipPath) {
        $zipPath = (Resolve-DevkitFullPath $ZipPath)
        if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw "-ZipPath was not found: $zipPath" }
        Write-Host "release : (local file) $zipPath"
    } else {
        $api = "https://api.github.com/repos/$repository/releases"
        $release = if ($Tag) { Invoke-DevkitGitHubApi ($api + '/tags/' + [uri]::EscapeDataString($Tag)) } else { Invoke-DevkitGitHubApi ($api + '/latest') }
        $asset = @($release.assets | Where-Object { $_.name -like 'kawari-*.zip' }) | Select-Object -First 1
        if (-not $asset) { throw "no kawari-*.zip in release $($release.tag_name)" }
        Write-Host "release : $($release.tag_name)$(if ($release.prerelease) { ' (pre-release)' })"
        Write-Host "notes   : $($release.html_url)"
        $zipPath = Join-Path $work $asset.name
        Save-DevkitReleaseAsset $asset $zipPath
    }

    # --- unpack and compare ------------------------------------------------------------------
    $newDll = Join-Path $work 'shiori.dll'
    if ((Expand-DevkitZipFile $zipPath @{ 'shiori.dll' = $newDll }).Count -eq 0) { throw 'shiori.dll is not in the zip' }
    $newVersion = Get-DevkitKawariVersion $newDll
    Write-Host "new     : shiori.dll $($newVersion.Text)"
    if (-not $newVersion.Phase9) { throw "the shiori.dll of this release is $($newVersion.Text); the skill supports Phase 9" }

    $same = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $newDll -Algorithm SHA256).Hash
    $older = $oldVersion.Number -and $newVersion.Number -lt $oldVersion.Number
    if ($same -and -not $Force) {
        Write-Host 'update-kawari: shiori.dll is already up to date'
    } elseif ($older -and -not $Tag -and -not $Force) {
        Write-Host 'update-kawari: the release is older than the current shiori.dll, so nothing was changed. -Tag or -Force installs it'
    } else {
        if (-not $oldVersion.Phase9) {
            Write-Host 'update-kawari: note - Phase 9 writes save files (save, savecrypt) in UTF-8 with a BOM, which Phase 8.2.9 and older cannot read; back the save files up if the ghost may go back to Phase 8'
        }
        Write-Host ('  replace  ghost/master/shiori.dll  {0} -> {1}' -f $oldVersion.Text, $newVersion.Text)
        if ($DryRun) {
            Write-Host 'update-kawari: dry run, nothing changed'
        } elseif (-not $SkipCheck -and -not (Test-NewShiori $newDll)) {
            Write-Host 'update-kawari: FAILED - the new shiori.dll does not work here; nothing was changed'
            $exitCode = 1
        } else {
            try {
                Copy-Item -LiteralPath $newDll -Destination $dll -Force
            } catch {
                throw "could not replace ghost/master/shiori.dll ($($_.Exception.Message)). If SSP is running this ghost, close the ghost and retry."
            }
            Write-Host "update-kawari: updated ghost/master/shiori.dll $($oldVersion.Text) -> $((Get-DevkitKawariVersion $dll).Text)"
            if (-not $SkipCheck) {
                # kosui.exe is the latest KAWARI, so this does not depend on the dll; it shows the state of the
                # dictionaries after the update (errors here were there before the update as well).
                $checkCode = Invoke-DevkitDictionaryCheck 'kawari' $GhostDir
                if ($checkCode -eq 1) { Write-Host 'update-kawari: the dictionaries have errors (see above); they are not caused by the new shiori.dll, which kosui.exe does not use' }
                if ($checkCode -eq 3) { Write-Host 'update-kawari: the dictionaries were not checked (kosui.exe is not installed: scripts/setup.ps1)' }
            }
        }
    }
} catch {
    Write-Host "update-kawari: FAILED - $($_.Exception.Message)"
    $exitCode = 1
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit $exitCode
