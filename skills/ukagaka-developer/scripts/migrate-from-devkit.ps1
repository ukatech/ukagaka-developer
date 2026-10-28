<#
.SYNOPSIS
    Removes the old AI development kit (tools/, docs/agents/, AGENTS.md and so on, from konnoyayame and
    POST_and_KOMAINU) from a ghost folder, so that the ukagaka-developer skill can take over.
.DESCRIPTION
    The old kit copied its own scripts and instructions into the ghost. It recorded the files it owns in
    tools/devkit.json and, for each of them, the hash of the version it installed in tools/devkit.lock.json. This script
    uses both to tell the files that the author never touched from the ones that were changed.

    Without -Apply it only prints the plan (a dry run). With -Apply:
      - Every file that is going to be deleted or changed is first copied to a backup folder outside the ghost
        (<home>/backups/<ghost folder>-<time>/), together with migration-report.txt. tools/bin/ (compiled programs) is
        not backed up.
      - Kit files that are unchanged since the kit installed them are deleted.
      - Kit files that the author changed (or that have no entry in the lock) are kept and listed. -Force deletes them
        too (they are backed up).
      - AGENTS.md and CLAUDE.md are replaced by short stubs that point to GHOST.md and the skill (templates/), when they
        are unchanged. GHOST.md is never touched.
      - .github/workflows/auto_check.yml, when unchanged, is replaced by the workflow of the skill (templates/github/).
      - .claude/settings.json, when changed by the author, is edited instead of deleted: the SessionStart hook of the
        old kit and the permissions for tools/*.ps1 are removed.
      - .narignore: the line "include:tools/devkit.narignore" is replaced by the block of development files.
      - tools/local.json: the SSP path is copied to local.json of the home folder when that has none.
      - Files of the author's own that happen to be in tools/ or docs/ are kept.
    Not touched, only reported: other workflows that call tools/*.ps1 (auto_release.yml, auto_release_devkit.yaml),
    leftover *.devkit-new / *.yaya-dic-new files.
    A folder that has DEVKIT-MAINTAINING.md is the repository that distributes the old kit; the script refuses to
    work in it unless -AllowKitSource is given. With it, DEVKIT-MAINTAINING.md and docs/devkit-maintaining/ (the notes
    for maintaining the kit, which are not in the kit's file list) are removed too.
    Exit codes: 0 = done or nothing to do, 1 = failed, 2 = done, but something has to be handled by hand.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/migrate-from-devkit.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/migrate-from-devkit.ps1 -Apply
#>
[CmdletBinding()]
param(
    # Do it. Without this switch, only the plan is printed.
    [switch]$Apply,
    # Also delete kit files that were changed or have no entry in the lock (they are backed up).
    [switch]$Force,
    # Work in the repository that distributes the old kit (it has DEVKIT-MAINTAINING.md), and remove the maintenance notes too.
    [switch]$AllowKitSource,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/ignore.ps1')
. (Join-Path $PSScriptRoot 'lib/legacy-devkit.ps1')
. (Join-Path $PSScriptRoot 'lib/ghost-files.ps1')
Initialize-DevkitConsole

$root = $DevkitRoot
$manifestPath = Join-Path $root $DevkitManifestName
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Write-Host "migrate-from-devkit: nothing to do - $DevkitManifestName was not found, so this folder has no old development kit."
    $conflictsOnly = @(Get-DevkitConflictFiles $root)
    if ($conflictsOnly.Count -gt 0) { Write-Host "note: unmerged files are left: $($conflictsOnly -join ', ')" }
    exit 0
}
if ((Test-Path -LiteralPath (Join-Path $root 'DEVKIT-MAINTAINING.md')) -and -not $AllowKitSource) {
    Write-Host 'migrate-from-devkit: STOPPED - DEVKIT-MAINTAINING.md is in this folder, so it is the repository that distributes the old kit.'
    Write-Host 'Migrating it removes the kit from it (and from what it distributes). Only do that when the repository retires the kit; then run again with -AllowKitSource.'
    exit 1
}

$manifest = Read-DevkitManifest $root
$lock = Read-DevkitLock $root
$kitFiles = Get-DevkitKitFiles $root $manifest
$shioriId = Get-DevkitShiori
$workflowPath = '.github/workflows/auto_check.yml'
$settingsPath = '.claude/settings.json'
$stubPaths = @('AGENTS.md', 'CLAUDE.md')

# --- plan ------------------------------------------------------------------------------
# Each entry: Path, Action (delete | stub | workflow | settings | keep), State (pristine | modified | unlocked), Note.
$plan = New-Object System.Collections.Generic.List[object]
foreach ($path in $kitFiles) {
    $full = Join-Path $root $path
    $lockHash = $null
    if ($lock.Files.ContainsKey($path)) { $lockHash = $lock.Files[$path] }
    $state = 'unlocked'
    if ($lockHash) { $state = if ((Get-DevkitFileHash $full) -eq $lockHash) { 'pristine' } else { 'modified' } }
    $ownedByKit = $state -eq 'pristine'
    $action = 'delete'
    if ($stubPaths -contains $path) { $action = 'stub' }
    elseif ($path -eq $workflowPath) { $action = 'workflow' }
    elseif ($path -eq $settingsPath -and $state -eq 'modified' -and -not $Force) { $action = 'settings' }
    # Changed files are kept, except settings.json, which is edited, and anything with -Force.
    if (-not $ownedByKit -and -not $Force -and $action -ne 'settings') {
        $note = if ($state -eq 'modified') { 'changed since the kit installed it' } else { 'not in the lock: the kit did not install it, or the lock is missing' }
        $plan.Add([pscustomobject]@{ Path = $path; Action = 'keep'; State = $state; Note = $note })
        continue
    }
    $plan.Add([pscustomobject]@{ Path = $path; Action = $action; State = $state; Note = '' })
}
# Compiled programs and the lock of the old kit: not in the file list, but removed with it.
$extraDelete = New-Object System.Collections.Generic.List[string]
$lockFile = Join-Path $root $DevkitLockName
if (Test-Path -LiteralPath $lockFile -PathType Leaf) { $extraDelete.Add($DevkitLockName) }
$binDir = Join-Path $root 'tools/bin'
$binFiles = @()
if (Test-Path -LiteralPath $binDir -PathType Container) {
    $binFiles = @(Get-ChildItem -LiteralPath $binDir -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') })
}
$localJson = Join-Path $root 'tools/local.json'
$hasLocalJson = Test-Path -LiteralPath $localJson -PathType Leaf
if ($hasLocalJson) { $extraDelete.Add('tools/local.json') }
if ($AllowKitSource) {
    if (Test-Path -LiteralPath (Join-Path $root 'DEVKIT-MAINTAINING.md') -PathType Leaf) { $extraDelete.Add('DEVKIT-MAINTAINING.md') }
    $notesDir = Join-Path $root 'docs/devkit-maintaining'
    if (Test-Path -LiteralPath $notesDir -PathType Container) {
        foreach ($note in @(Get-ChildItem -LiteralPath $notesDir -Recurse -File -Force)) { $extraDelete.Add($note.FullName.Substring($root.Length + 1).Replace('\', '/')) }
    }
}
foreach ($exe in @(Get-ChildItem -LiteralPath (Join-Path $root 'tools') -File -Filter '*.exe' -ErrorAction SilentlyContinue)) {
    $extraDelete.Add('tools/' + $exe.Name)
}

# Other files in the ghost that still call the old scripts.
$staleWorkflows = New-Object System.Collections.Generic.List[string]
$workflowDir = Join-Path $root '.github/workflows'
if (Test-Path -LiteralPath $workflowDir -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $workflowDir -File -ErrorAction SilentlyContinue)) {
        $relative = '.github/workflows/' + $file.Name
        if ($relative -eq $workflowPath -and ($plan | Where-Object { $_.Path -eq $workflowPath -and $_.Action -eq 'workflow' })) { continue }
        $text = [IO.File]::ReadAllText($file.FullName, $DevkitUtf8)
        if ($text -match '(?m)tools/[A-Za-z0-9_.-]+\.ps1' -or $file.Name -match 'devkit') { $staleWorkflows.Add($relative) }
    }
}
$leftovers = @(Get-DevkitConflictFiles $root)
# receiver.bat / receiver.ps1 of the SATORI sample ghost open the log window of the old kit's tools/lib.
$staleReceivers = New-Object System.Collections.Generic.List[string]
foreach ($name in @('receiver.ps1', 'receiver.bat')) {
    $receiver = Join-Path $root "ghost/master/$name"
    if ((Test-Path -LiteralPath $receiver -PathType Leaf) -and ([IO.File]::ReadAllText($receiver, $DevkitUtf8) -match 'tools[\/]lib')) { $staleReceivers.Add("ghost/master/$name") }
}
$narignorePath = Join-Path $root '.narignore'
$narignoreChange = $false
if (Test-Path -LiteralPath $narignorePath -PathType Leaf) {
    $narText = [IO.File]::ReadAllText($narignorePath, $DevkitUtf8)
    $narignoreChange = $narText.Contains($DevkitLegacyNarignoreInclude) -or -not (Test-DevkitNarignoreHasDevBlock $narText)
}

# --- print the plan ----------------------------------------------------------------------
function Write-Group([string]$Title, $Items, [scriptblock]$Format) {
    $list = @($Items | Where-Object { $null -ne $_ })
    if ($list.Count -eq 0) { return }
    Write-Host ''
    Write-Host "$Title ($($list.Count))"
    foreach ($item in $list) { Write-Host ('  ' + (& $Format $item)) }
}
Write-Host "migrate-from-devkit: $root"
Write-Host "old kit : $(if ($lock.Exists) { "lock records $($lock.Files.Count) files (source $($lock.Source), ref $($lock.Ref))" } else { 'no lock file: every file counts as changed' })"
Write-Host "mode    : $(if ($Apply) { 'APPLY' } else { 'dry run (nothing is changed; add -Apply)' })$(if ($Force) { ', -Force' })"
$toDelete = @($plan | Where-Object { $_.Action -eq 'delete' })
Write-Group 'delete (unchanged kit files)' ($toDelete | Where-Object { $_.State -eq 'pristine' }) { param($i) $i.Path }
Write-Group 'delete (changed or unlocked, because of -Force; backed up)' ($toDelete | Where-Object { $_.State -ne 'pristine' }) { param($i) "$($i.Path)  [$($i.State)]" }
Write-Group 'replace with a short stub' ($plan | Where-Object { $_.Action -eq 'stub' }) { param($i) "$($i.Path)  [$($i.State)]" }
Write-Group 'replace with the workflow of the skill' ($plan | Where-Object { $_.Action -eq 'workflow' }) { param($i) $i.Path }
Write-Group 'edit (remove the hook and permissions of the old kit)' ($plan | Where-Object { $_.Action -eq 'settings' }) { param($i) $i.Path }
Write-Group 'delete (compiled programs, settings and lock of the old kit)' @($extraDelete) { param($i) $i }
if ($binFiles.Count -gt 0) { Write-Host "  tools/bin/ ($($binFiles.Count) compiled files; not backed up)" }
if ($narignoreChange) { Write-Host ''; Write-Host '.narignore: the line include:tools/devkit.narignore is replaced by (or the file gets) the block of development files' }
if ($hasLocalJson) { Write-Host "tools/local.json: the SSP path is copied to local.json in the home folder ($DevkitHome)" }
$kept = @($plan | Where-Object { $_.Action -eq 'keep' })
Write-Group 'kept by hand (merge or delete them yourself)' $kept { param($i) "$($i.Path)  - $($i.Note)" }
Write-Group 'workflows that still call tools/*.ps1 or build the old kit (not changed; see references/workflows/ci.md)' @($staleWorkflows) { param($i) $i }
Write-Group 'log receiver files that need the old kit (not changed; use scripts/log-window.ps1 instead)' @($staleReceivers) { param($i) $i }
Write-Group 'leftover files of old kit updates (not changed)' @($leftovers) { param($i) $i }
Write-Host ''

if (-not $Apply) {
    Write-Host 'migrate-from-devkit: dry run, nothing was changed. Run again with -Apply to do it (a backup is written first).'
    if ($kept.Count -gt 0 -or $staleWorkflows.Count -gt 0 -or $staleReceivers.Count -gt 0 -or $leftovers.Count -gt 0) { exit 2 }
    exit 0
}

# --- apply -------------------------------------------------------------------------------
if (-not $shioriId) {
    Write-Host "migrate-from-devkit: FAILED - this ghost has no SHIORI that the skill supports ($DevkitShioriSupported); the stubs cannot be chosen."
    exit 1
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ghostName = Split-Path $root -Leaf
$backupDir = Join-Path (Join-Path $DevkitHome 'backups') "$ghostName-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

function Copy-ToBackup([string]$RelativePath) {
    $source = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { return }
    $destination = Join-Path $backupDir $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
}
function Write-DevkitJson([string]$Path, $Object) {
    $json = ConvertTo-Json -InputObject $Object -Depth 20
    # ConvertTo-Json of Windows PowerShell 5.1 escapes some characters as \u00XX; they mean the same.
    [IO.File]::WriteAllText($Path, ($json -replace "`r`n", "`n") + "`n", $DevkitUtf8)
}

# Returns the text of the settings without the old kit's hook and permissions, or $null when nothing is to be removed.
# $IsEmpty is set when nothing but "$schema" is left.
function Get-CleanedSettings([string]$FullPath, [ref]$IsEmpty) {
    $settings = [IO.File]::ReadAllText($FullPath, $DevkitUtf8) | ConvertFrom-Json
    $changed = $false
    if ($settings.PSObject.Properties.Name -contains 'permissions' -and $settings.permissions -and ($settings.permissions.PSObject.Properties.Name -contains 'allow')) {
        $allow = @($settings.permissions.allow)
        $kept = @($allow | Where-Object { -not ([string]$_ -match 'tools/' -and [string]$_ -match '\.ps1') })
        if ($kept.Count -ne $allow.Count) {
            $changed = $true
            if ($kept.Count -gt 0) { $settings.permissions.allow = $kept } else { $settings.permissions.PSObject.Properties.Remove('allow') }
        }
    }
    if ($settings.PSObject.Properties.Name -contains 'hooks' -and $settings.hooks -and ($settings.hooks.PSObject.Properties.Name -contains 'SessionStart')) {
        $matchers = @()
        foreach ($entry in @($settings.hooks.SessionStart)) {
            $inner = @($entry.hooks | Where-Object { (ConvertTo-Json -InputObject $_ -Depth 10) -notmatch 'tools/hooks/session-start\.ps1' })
            if ($inner.Count -ne @($entry.hooks).Count) { $changed = $true }
            if ($inner.Count -gt 0) { $entry.hooks = $inner; $matchers += $entry }
        }
        if ($changed) {
            if ($matchers.Count -gt 0) { $settings.hooks.SessionStart = $matchers } else { $settings.hooks.PSObject.Properties.Remove('SessionStart') }
            if (@($settings.hooks.PSObject.Properties).Count -eq 0) { $settings.PSObject.Properties.Remove('hooks') }
        }
    }
    if (-not $changed) { return $null }
    if ($settings.PSObject.Properties.Name -contains 'permissions' -and $settings.permissions -and @($settings.permissions.PSObject.Properties).Count -eq 0) {
        $settings.PSObject.Properties.Remove('permissions')
    }
    $rest = @($settings.PSObject.Properties | Where-Object { $_.Name -ne '$schema' })
    $IsEmpty.Value = ($rest.Count -eq 0)
    return (ConvertTo-Json -InputObject $settings -Depth 20)
}

$report = New-Object System.Collections.Generic.List[string]
$report.Add("ukagaka-developer migrate-from-devkit  $stamp")
$report.Add("ghost : $root")
$report.Add("backup: $backupDir")
$report.Add('')
$manual = 0

# 1. back up everything that is going to change
foreach ($item in $plan) { if ($item.Action -ne 'keep') { Copy-ToBackup $item.Path } }
foreach ($path in $extraDelete) { Copy-ToBackup $path }
if ($narignoreChange) { Copy-ToBackup '.narignore' }

# 2. stubs and workflow
foreach ($item in ($plan | Where-Object { $_.Action -eq 'stub' })) {
    $stub = Read-DevkitTemplate $item.Path
    Write-DevkitTextFile (Join-Path $root $item.Path) $stub
    $report.Add("stub      $($item.Path)")
}
foreach ($item in ($plan | Where-Object { $_.Action -eq 'workflow' })) {
    Write-DevkitTextFile (Join-Path $root $item.Path) (Read-DevkitTemplate 'github/auto_check.yml')
    $report.Add("workflow  $($item.Path)")
}

# 3. settings.json
foreach ($item in ($plan | Where-Object { $_.Action -eq 'settings' })) {
    $full = Join-Path $root $item.Path
    $isEmpty = $false
    $cleaned = Get-CleanedSettings $full ([ref]$isEmpty)
    if ($null -eq $cleaned) {
        $report.Add("kept      $($item.Path) (changed by the author, and nothing of the old kit was found in it)")
    } elseif ($isEmpty) {
        Remove-Item -LiteralPath $full -Force
        $report.Add("deleted   $($item.Path) (only the old kit's entries were in it)")
    } else {
        [IO.File]::WriteAllText($full, ($cleaned -replace "`r`n", "`n") + "`n", $DevkitUtf8)
        $report.Add("edited    $($item.Path) (the hook and permissions of the old kit removed)")
    }
}

# 4. delete
foreach ($item in ($plan | Where-Object { $_.Action -eq 'delete' })) {
    Remove-Item -LiteralPath (Join-Path $root $item.Path) -Force
    $report.Add("deleted   $($item.Path)")
}
foreach ($path in $extraDelete) {
    $full = Join-Path $root $path
    if (Test-Path -LiteralPath $full -PathType Leaf) { Remove-Item -LiteralPath $full -Force; $report.Add("deleted   $path") }
}
if (Test-Path -LiteralPath $binDir -PathType Container) {
    Remove-Item -LiteralPath $binDir -Recurse -Force
    $report.Add('deleted   tools/bin/')
}

# 5. SSP path of tools/local.json
if ($hasLocalJson) {
    $backupLocal = Join-Path $backupDir 'tools/local.json'
    $homeLocal = Join-Path $DevkitHome 'local.json'
    if (-not (Test-Path -LiteralPath $homeLocal) -and (Test-Path -LiteralPath $backupLocal)) {
        try {
            $old = [IO.File]::ReadAllText($backupLocal, $DevkitUtf8) | ConvertFrom-Json
            if ($old.sspPath) {
                New-Item -ItemType Directory -Force -Path $DevkitHome | Out-Null
                Write-DevkitJson $homeLocal ([pscustomobject]@{ sspPath = [string]$old.sspPath })
                $report.Add("moved     the SSP path of tools/local.json to $homeLocal")
            }
        } catch {
            $report.Add("warning   tools/local.json could not be read; set the SSP path again (see references/commands.md)")
            $manual++
        }
    } else {
        $report.Add('note      local.json already exists in the home folder; the SSP path of tools/local.json was not copied')
    }
}

# 6. .narignore
if ($narignoreChange) {
    $legacyRules = ''
    $legacyRulesPath = Join-Path $backupDir 'tools/devkit.narignore'
    if (Test-Path -LiteralPath $legacyRulesPath -PathType Leaf) { $legacyRules = [IO.File]::ReadAllText($legacyRulesPath, $DevkitUtf8) }
    Write-DevkitTextFile $narignorePath (Add-DevkitNarignoreDevBlock ([IO.File]::ReadAllText($narignorePath, $DevkitUtf8)) $legacyRules)
    $report.Add('updated   .narignore (block of development files)')
}

# 7. empty folders
foreach ($folder in @('docs/devkit-maintaining', 'tools/lib', 'tools/hooks', 'tools/devkit/seed', 'tools/devkit', 'tools', 'docs/agents/workflows', 'docs/agents', 'docs', '.claude/agents', '.claude')) {
    $full = Join-Path $root $folder
    if ((Test-Path -LiteralPath $full -PathType Container) -and -not (Get-ChildItem -LiteralPath $full -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $full -Force
        $report.Add("removed   $folder/ (empty)")
    }
}

# 8. what is left for the author
$report.Add('')
foreach ($item in $kept) { $report.Add("KEPT      $($item.Path)  - $($item.Note)"); $manual++ }
foreach ($path in $staleWorkflows) { $report.Add("STALE     $path  - calls tools/*.ps1 or builds the old kit (references/workflows/ci.md)"); $manual++ }
foreach ($path in $staleReceivers) { $report.Add("STALE     $path  - opens the log window of the old kit; delete receiver.ps1, receiver.bat and receiver.txt, and use scripts/log-window.ps1"); $manual++ }
foreach ($path in $leftovers) { $report.Add("LEFTOVER  $path"); $manual++ }
if (@($plan | Where-Object { $_.Action -in @('settings', 'delete') -and $_.Path -eq $settingsPath }).Count -gt 0) {
    $report.Add('NOTE      the permissions that .claude/settings.json gave to tools/*.ps1 are gone. The skill allows its read-only scripts only for the turn that uses it; see the section about permission prompts in README.md to allow them for good.')
}
$reportPath = Join-Path $backupDir 'migration-report.txt'
[IO.File]::WriteAllText($reportPath, (($report -join "`n") + "`n"), $DevkitUtf8)

foreach ($line in $report) { Write-Host $line }
Write-Host ''
Write-Host "migrate-from-devkit: done. Backup and report: $backupDir"
Write-Host 'Next: run scripts/doctor.ps1, then scripts/check.ps1, and review the changes (git status) before committing.'
if ($manual -gt 0) {
    Write-Host "migrate-from-devkit: $manual item(s) are left for you (KEPT / STALE / LEFTOVER above); see references/workflows/migrate-from-devkit.md."
    exit 2
}
exit 0
