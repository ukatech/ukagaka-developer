# Helpers for YAYA (yaya.dll): the system dictionary (yaya-dic), tamacs.exe, and the doctor and setup steps.
# Dot-source after common.ps1:   . (Join-Path $PSScriptRoot 'lib.ps1')
# Keep every .ps1 file ASCII-only and compatible with Windows PowerShell 5.1.

# Folders of the system dictionary (yaya-dic), relative to ghost/master, in the order they are looked for.
# Most ghosts keep it in dic/system; some keep it in system.
$DevkitSystemDicDirs = @('dic/system', 'system')

# Runs tamacs.exe on the yaya.dll in $GhostDir (a full path: YAYA looks for yaya.txt in the folder of the dll).
# Call Get-DevkitTamacs first to tell the user when it is not available. YAYA saves yaya_variable.cfg when it
# unloads, so the file is put back afterwards (or removed when there was none) and running the ghost this way
# leaves nothing behind.
function Invoke-DevkitTamacs {
    param(
        [string]$GhostDir,
        [string[]]$Arguments = @(),
        [string]$InputText,
        [string[]]$UnsetEnvironment = @(),
        [int]$TimeoutSeconds = 120
    )
    $tamacs = Get-DevkitTamacs
    if (-not $tamacs.Path) { throw $tamacs.Error }
    $processArgs = @{
        FilePath         = $tamacs.Path
        Arguments        = @(Join-Path $GhostDir 'yaya.dll') + @($Arguments)
        WorkingDirectory = $GhostDir
        UnsetEnvironment = $UnsetEnvironment
        TimeoutSeconds   = $TimeoutSeconds
    }
    if ($PSBoundParameters.ContainsKey('InputText')) { $processArgs['InputText'] = $InputText }

    $variableFile = Join-Path $GhostDir 'yaya_variable.cfg'
    $variableBackup = $null
    if (Test-Path -LiteralPath $variableFile) {
        $variableBackup = [IO.Path]::GetTempFileName()
        Copy-Item -LiteralPath $variableFile -Destination $variableBackup -Force
    }
    try {
        return (Invoke-DevkitProcess @processArgs)
    } finally {
        if ($variableBackup) {
            Copy-Item -LiteralPath $variableBackup -Destination $variableFile -Force
            Remove-Item -LiteralPath $variableBackup -Force
        } elseif (Test-Path -LiteralPath $variableFile) {
            Remove-Item -LiteralPath $variableFile -Force
        }
    }
}

# Returns the system dictionary folder (for example 'dic/system', relative to ghost/master) that contains
# .dic files, or $null when none of $DevkitSystemDicDirs does (such as an empty git submodule).
function Get-DevkitSystemDicDir([string]$GhostDir) {
    if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
    foreach ($dir in $DevkitSystemDicDirs) {
        $full = Join-Path $GhostDir $dir
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { continue }
        if (Get-ChildItem -LiteralPath $full -Recurse -File -Filter '*.dic' -ErrorAction SilentlyContinue | Select-Object -First 1) { return $dir }
    }
    return $null
}

# Tells whether a folder holds the current layout of yaya-dic (yaya_base/shiori3.dic, since June 2022).
function Test-DevkitYayaDicLayout([string]$Folder) {
    return (Test-Path -LiteralPath (Join-Path $Folder 'yaya_base/shiori3.dic') -PathType Leaf)
}

# File names of the system dictionary in older layouts: yaya-dic before June 2022 kept yaya_*.dic in one folder
# (yaya_config.dic only for a day), and older templates kept the settings dictionary as ghost/master/yaya_config.txt.
$DevkitOldSystemDicNames = @('yaya_shiori3.dic', 'yaya_optional.dic', 'yaya_compatible.dic', 'yaya_config.dic', 'yaya_config.txt')

# Returns the files under ghost/master (relative, '/'-separated) that have an old system dictionary file name.
# The ghost may keep them in ghost/master itself, in system/, or anywhere else. Wrap the call in @().
function Find-DevkitOldSystemDicFiles([string]$GhostDir) {
    if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
    $root = [IO.Path]::GetFullPath($GhostDir).TrimEnd('\', '/')
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($item in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        if ($DevkitOldSystemDicNames -notcontains $item.Name.ToLowerInvariant()) { continue }
        $relative = $item.FullName.Substring($root.Length + 1).Replace('\', '/')
        if ($relative -match '(^|/)\.git/') { continue }
        $result.Add($relative)
    }
    [string[]]$paths = $result.ToArray()
    [Array]::Sort($paths, [StringComparer]::OrdinalIgnoreCase)
    return $paths
}

# Tells whether a '/'-separated path is inside a system dictionary folder.
# Prefix: what the path starts with before those folders ('' for paths relative to ghost/master).
function Test-DevkitSystemDicPath([string]$Path, [string]$Prefix = '') {
    foreach ($dir in $DevkitSystemDicDirs) {
        if ($Path.StartsWith("$Prefix$dir/", [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

# --- doctor and setup ---------------------------------------------------------------------

# What the doctor tells tamacs.exe is used for.
$DevkitTamacsPurpose = 'Loads yaya.dll without SSP: dictionary check (check-dic.ps1 and the check after each edit), shiori.ps1, lint.ps1'

# Adds the YAYA items to the doctor (Add-DoctorItem is defined by doctor.ps1).
function Add-DevkitShioriDoctorItems([string]$Ps, [bool]$IsGitWorkingCopy) {
    $dll = Join-Path $DevkitRoot 'ghost/master/yaya.dll'
    $ghostOk = (Test-Path -LiteralPath $dll) -and (Test-Path -LiteralPath (Join-Path $DevkitRoot 'ghost/master/yaya.txt'))
    Add-DoctorItem -Id 'ghost' -Name 'ghost files (YAYA)' -Level 'required' -Ok $ghostOk `
        -Purpose 'The ghost itself' `
        -Detail $(if ($ghostOk) { "yaya.dll $((Get-Item -LiteralPath $dll).VersionInfo.FileVersion)" } else { 'ghost/master/yaya.dll or ghost/master/yaya.txt is missing' }) `
        -Fix 'Work in the ghost root folder (the one that contains ghost/ and shell/).'

    $systemDir = Get-DevkitSystemDicDir
    $systemOk = [bool]$systemDir
    $systemDetail = 'no .dic files in ' + (($DevkitSystemDicDirs | ForEach-Object { "ghost/master/$_" }) -join ' or ')
    if ($systemDir) {
        $systemDetail = "ghost/master/$systemDir"
        if (-not (Test-DevkitYayaDicLayout (Join-Path (Join-Path $DevkitRoot 'ghost/master') $systemDir))) {
            $systemDetail += ' (an older layout than yaya-dic; scripts/update-shiori.ps1 cannot update it until it is reorganized as in references/yaya/update.md)'
        }
    } else {
        # Older ghosts may keep the system dictionary elsewhere, such as directly in ghost/master. The ghost still works.
        $oldSystemDic = @(Find-DevkitOldSystemDicFiles | Where-Object { $_ -match '(^|/)yaya_shiori3\.dic$' })
        if ($oldSystemDic.Count -gt 0) {
            $systemOk = $true
            $systemDetail = "an older layout: $($oldSystemDic -join ', ') (scripts/update-shiori.ps1 cannot update it until it is reorganized as in references/yaya/update.md)"
        }
    }
    Add-DoctorItem -Id 'system-dic' -Name 'system dictionary' -Level 'required' -Ok $systemOk `
        -Purpose 'YAYA system dictionary (yaya-dic)' `
        -Detail $systemDetail `
        -Fix $(if ($IsGitWorkingCopy) { "Run: $Ps scripts/setup.ps1 (it runs git submodule update --init)" } else { 'The folder is incomplete. Download the nar again from the Releases page.' })
}

# The setup step of YAYA: in a git clone, fetches the system dictionary submodule when it is empty.
# Returns the number of failed steps.
function Invoke-DevkitShioriSetup {
    $failed = 0
    $systemDicNames = ($DevkitSystemDicDirs | ForEach-Object { "ghost/master/$_" }) -join ' or '
    if (-not (Get-DevkitSystemDicDir) -and (Test-Path -LiteralPath (Join-Path $DevkitRoot '.git'))) {
        $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($git) {
            Write-Host '[submodule] git submodule update --init --recursive'
            $result = Invoke-DevkitProcess -FilePath $git.Source -Arguments @('-C', $DevkitRoot, 'submodule', 'update', '--init', '--recursive') -TimeoutSeconds 300
            $systemDir = Get-DevkitSystemDicDir
            if ($result.ExitCode -ne 0) {
                $failed++
                Write-Host "[error] submodule: $(($result.StdErr + $result.StdOut).Trim())"
            } elseif ($systemDir) {
                Write-Host "[ok] ghost/master/$systemDir"
            } else {
                Write-Host "[warn] submodules were fetched, but $systemDicNames still has no .dic files"
            }
        } else {
            $failed++
            Write-Host "[error] Git is needed to fetch the system dictionary ($systemDicNames) (see scripts/doctor.ps1)"
        }
    }
    return $failed
}
