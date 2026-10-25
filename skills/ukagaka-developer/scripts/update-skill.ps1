<#
.SYNOPSIS
    Updates a copy-installed ukagaka-developer skill (the folder that holds SKILL.md) to the latest version on GitHub.
.DESCRIPTION
    For skills installed by copying the folder (Codex, Antigravity and so on: .agents/skills/ukagaka-developer/).
    A Claude Code plugin updates with "claude plugin update ukagaka-developer" instead; this script refuses to touch a
    folder inside the plugin cache of Claude Code.

    It downloads https://github.com/ukatech/ukagaka-developer (the latest commit of the default branch, or -Ref), takes
    skills/ukagaka-developer from it, and replaces the folder of the installed skill with it. The old folder is kept
    next to it as <folder>.old-<time> until the new one is in place, then deleted. The commit that was installed is
    written to .installed-from in the skill folder, so that a later run can tell that it is already up to date.
    Nothing in the ghost folder is touched. The settings and compiled programs in the home folder are kept.
    -Source takes a local folder (the repository, or its skills/ukagaka-developer) or a .zip instead of GitHub.
    -DryRun only says what would happen.
    Exit codes: 0 = updated / already up to date / dry run, 1 = failed.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-skill.ps1 -DryRun
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-skill.ps1
#>
[CmdletBinding()]
param(
    # The installed skill folder to update (default: the folder that holds this script's SKILL.md).
    [string]$Target,
    # Tag, branch or commit of ukagaka-developer (default: the default branch).
    [string]$Ref,
    # A local folder or .zip to take the new version from, instead of GitHub.
    [string]$Source,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
Initialize-DevkitConsole -NoGhost
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$repository = 'ukatech/ukagaka-developer'
if (-not $Target) { $Target = $DevkitSkillDir }
$Target = (Resolve-DevkitFullPath $Target).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $Target 'SKILL.md') -PathType Leaf)) {
    Write-Host "update-skill: FAILED - $Target does not hold SKILL.md"
    exit 1
}
if ($Target -match '[\\/]plugins[\\/](cache|marketplaces)[\\/]') {
    Write-Host "update-skill: STOPPED - $Target is inside the plugin cache of Claude Code. Update the plugin instead: claude plugin update ukagaka-developer"
    exit 1
}

$installedFile = Join-Path $Target '.installed-from'
$installed = ''
if (Test-Path -LiteralPath $installedFile) { $installed = ([IO.File]::ReadAllText($installedFile, $DevkitUtf8)).Trim() }

$work = Join-Path ([IO.Path]::GetTempPath()) ('ukadev-update-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
    # --- get the new version ----------------------------------------------------------
    $newCommit = ''
    $extracted = Join-Path $work 'x'
    if ($Source) {
        $Source = (Resolve-DevkitFullPath $Source).TrimEnd('\', '/')
        if (Test-Path -LiteralPath $Source -PathType Container) {
            $extracted = $Source
        } elseif (Test-Path -LiteralPath $Source -PathType Leaf) {
            [IO.Compression.ZipFile]::ExtractToDirectory($Source, $extracted)
        } else {
            throw "-Source was not found: $Source"
        }
        $newCommit = 'local:' + $Source
    } else {
        $refName = $Ref
        if (-not $refName) { $refName = [string](Invoke-DevkitGitHubApi "https://api.github.com/repos/$repository").default_branch }
        $commit = Invoke-DevkitGitHubApi "https://api.github.com/repos/$repository/commits/$refName"
        $newCommit = [string]$commit.sha
        Write-Host "latest  : $refName @ $($newCommit.Substring(0, 12)) ($([string]$commit.commit.committer.date))"
        Write-Host "installed: $(if ($installed) { $installed.Substring(0, [Math]::Min(12, $installed.Length)) } else { '(unknown: not installed by this script)' })"
        if ($installed -eq $newCommit) {
            Write-Host 'update-skill: already up to date'
            exit 0
        }
        if ($DryRun) {
            Write-Host "update-skill: dry run, nothing changed. Would replace $Target"
            exit 0
        }
        $zip = Join-Path $work 'src.zip'
        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$repository/archive/$newCommit.zip" -OutFile $zip
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $extracted)
    }
    # The folder with SKILL.md: skills/ukagaka-developer of the repository (one top folder in an archive), or the folder itself.
    $newSkill = $null
    foreach ($candidate in @($extracted) + @(Get-ChildItem -LiteralPath $extracted -Directory | ForEach-Object { $_.FullName })) {
        foreach ($sub in @('skills/ukagaka-developer', '.')) {
            $path = [IO.Path]::GetFullPath((Join-Path $candidate $sub))
            if (Test-Path -LiteralPath (Join-Path $path 'SKILL.md') -PathType Leaf) { $newSkill = $path; break }
        }
        if ($newSkill) { break }
    }
    if (-not $newSkill) { throw 'SKILL.md was not found in the downloaded version' }
    if ($DryRun) {
        Write-Host "update-skill: dry run, nothing changed. Would replace $Target with $newSkill"
        exit 0
    }

    # --- replace ----------------------------------------------------------------------
    $old = "$Target.old-" + (Get-Date -Format 'yyyyMMddHHmmss')
    Move-Item -LiteralPath $Target -Destination $old
    try {
        New-Item -ItemType Directory -Force -Path $Target | Out-Null
        Copy-Item -Path (Join-Path $newSkill '*') -Destination $Target -Recurse -Force
        [IO.File]::WriteAllText((Join-Path $Target '.installed-from'), $newCommit + "`n", $DevkitUtf8)
    } catch {
        # Put the old folder back.
        if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction SilentlyContinue }
        Move-Item -LiteralPath $old -Destination $Target
        throw
    }
    try { Remove-Item -LiteralPath $old -Recurse -Force } catch { Write-Host "note: the old folder could not be removed: $old" }
    Write-Host "update-skill: updated $Target ($newCommit). Restart the agent so that it reads the new SKILL.md."
    exit 0
} catch {
    Write-Host "update-skill: FAILED - $($_.Exception.Message)"
    exit 1
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
