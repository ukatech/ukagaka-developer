<#
.SYNOPSIS
    Builds the files to publish on a web site (GitHub Pages): the nar, the network update files and the files they list.
.DESCRIPTION
    This is what the "homeurl" of a ghost points to. It works in a git working copy (on GitHub Actions too) and does not
    need SSP. The files are the ones that git tracks (submodules included), so nothing untracked is shipped. Then:
      - the nar          = the tracked files that .narignore does not exclude (made by build-nar.ps1 -Builtin)
      - the update files = the tracked files that .updateignore does not exclude (a .updateignore that starts with
                           "include:.narignore" follows the nar and may re-include files, such as delete.txt)
    and the layout under -OutDir is:
      <directory of install.txt>.nar   the archive
      updates2.dau, updates.txt        the network update list (path, MD5, size, date; UTF-8)
      delete.txt, ghost/..., shell/... the files in the list, at the same relative paths
      <balloon>/updates2.dau, updates.txt and the balloon files
                                       one set for each balloon that install.txt bundles (balloon.directory); the balloon
                                       is not in the update files of the ghost (put its folder into .updateignore), and its
                                       descript.txt has its own "homeurl"
      .ukagaka/                        the metainfo folder (the tracked files of .ukagaka/, as they are; keep it out of the
                                       nar and the update files with .narignore)
      index.html, .nojekyll            a plain page that links to the files ($IntroDir replaces it, see below)
    The introduction page of the ghost (the folder -IntroDir, "site" by default; put it into .narignore) is copied over
    the output, so its index.html replaces the plain one.
    updates2.dau and updates.txt of the repository itself (a root-level pair kept for users of an older homeurl) are not
    part of the output: .narignore excludes them. The output never goes into the folder of the ghost; the default is
    build/site, which the development block of .narignore excludes.
    Rule syntax: that of SSP (gitignore syntax and "include:<file>", see references/workflows/build-nar.md).
    Exit codes: 0 = done, 1 = failed.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-site.ps1 -ListOnly
.EXAMPLE
    pwsh ./scripts/build-site.ps1 -OutDir build/site
#>
[CmdletBinding()]
param(
    # Output folder (default: build/site in the ghost root). It is emptied first.
    [string]$OutDir,
    # Introduction page: this folder (relative to the ghost root) is copied over the output when it exists.
    [string]$IntroDir = 'site',
    # Name of the nar (default: <directory in install.txt>.nar).
    [string]$NarName,
    # Print the files of each list and write nothing.
    [switch]$ListOnly,
    # Write only the network update files (updates2.dau, updates.txt) and copies, of exactly these tracked files (paths
    # relative to the ghost root), and nothing else: this is how the frozen files for an old homeurl are made
    # (references/workflows/pages.md). -NamePrefix removes a folder from the names in the list (for a balloon).
    [string[]]$OnlyUpdateFiles,
    [string]$NamePrefix,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/ignore.ps1')
Initialize-DevkitConsole

$root = $DevkitRoot
$installTxt = Join-Path $root 'install.txt'
if (-not (Test-Path -LiteralPath $installTxt -PathType Leaf)) {
    Write-Host 'build-site: FAILED - install.txt was not found in the ghost root'
    exit 1
}
$git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $git -or -not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
    Write-Host 'build-site: FAILED - this needs a git working copy (the files that git tracks are the ones that are published)'
    exit 1
}
if (-not $NarName) {
    $directory = Get-DevkitDescriptValue $installTxt 'directory'
    if (-not $directory) { $directory = 'ghost' }
    $NarName = $directory + '.nar'
}
if (-not $OutDir) { $OutDir = Join-Path $root 'build/site' }
$OutDir = Resolve-DevkitFullPath $OutDir

# --- the tracked files and the two lists ---------------------------------------------------------
$listed = Invoke-DevkitProcess -FilePath $git.Source -Arguments @('-C', $root, 'ls-files', '-z', '--recurse-submodules') -TimeoutSeconds 120
if ($listed.ExitCode -ne 0) {
    Write-Host "build-site: FAILED - git ls-files failed: $($listed.StdErr)"
    exit 1
}
$files = New-Object System.Collections.Generic.List[string]
foreach ($path in $listed.StdOut.Split([char]0)) {
    if ($path -and (Test-Path -LiteralPath (Join-Path $root $path) -PathType Leaf)) { $files.Add($path) }
}
$files = @($files | Sort-Object -Unique)
if ($files.Count -eq 0) {
    Write-Host 'build-site: FAILED - git tracks no files here'
    exit 1
}

# The update files: copy each file into $DestDir at the path it has in the list, and describe it (path, MD5, size, date).
# As SSP does, the first record also says the charset of the list. $Items: objects with Source (path relative to the
# ghost root) and Name (path in the list).
$separator = [string][char]1
function Write-UpdateSet([string]$DestDir, $Items) {
    $dau = New-Object System.Text.StringBuilder
    $txt = New-Object System.Text.StringBuilder
    [void]$txt.Append("charset,UTF-8`r`n")
    $first = $true
    foreach ($item in $Items) {
        $source = Join-Path $root $item.Source
        $target = Join-Path $DestDir $item.Name
        $targetDir = Split-Path $target -Parent
        if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        Copy-Item -LiteralPath $source -Destination $target -Force
        $info = Get-Item -LiteralPath $source
        $md5 = (Get-FileHash -LiteralPath $source -Algorithm MD5).Hash.ToLowerInvariant()
        $date = $info.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ss')
        $record = $item.Name + $separator + $md5 + $separator + 'size=' + $info.Length + $separator + 'date=' + $date + $separator
        if ($first) { $record += 'charset=UTF-8' + $separator; $first = $false }
        $record += "`r`n"
        [void]$dau.Append($record)
        [void]$txt.Append('file,' + $record)
    }
    [IO.File]::WriteAllText((Join-Path $DestDir 'updates2.dau'), $dau.ToString(), $DevkitUtf8)
    [IO.File]::WriteAllText((Join-Path $DestDir 'updates.txt'), $txt.ToString(), $DevkitUtf8)
}

# Only the update files of the given files (frozen files for an old homeurl).
if ($OnlyUpdateFiles) {
    $items = @()
    # powershell -File passes a comma-separated list as one string, so commas are split here.
    foreach ($name in @($OnlyUpdateFiles | ForEach-Object { $_ -split ',' } | Where-Object { $_.Trim() -ne '' })) {
        $name = $name.Trim()
        $relative = $name.Replace([string][char]92, '/').TrimStart('/')
        if ($files -notcontains $relative) {
            Write-Host "build-site: FAILED - $relative is not a file that git tracks"
            exit 1
        }
        $listName = $relative
        if ($NamePrefix) {
            $prefix = $NamePrefix.Replace([string][char]92, '/').Trim('/') + '/'
            if (-not $relative.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                Write-Host "build-site: FAILED - $relative is not under -NamePrefix $NamePrefix"
                exit 1
            }
            $listName = $relative.Substring($prefix.Length)
        }
        $items += [pscustomobject]@{ Source = $relative; Name = $listName }
    }
    if (Test-Path -LiteralPath $OutDir) { Remove-Item -LiteralPath $OutDir -Recurse -Force }
    New-Item -ItemType Directory -Path $OutDir | Out-Null
    Write-UpdateSet $OutDir $items
    Write-Host ("build-site: wrote updates2.dau and updates.txt of {0} files in {1}" -f $items.Count, $OutDir)
    exit 0
}

$narMatcher = New-DevkitIgnoreMatcher (Read-DevkitIgnoreRules $root '.narignore')
$updMatcher = New-DevkitIgnoreMatcher (Read-DevkitIgnoreRules $root '.updateignore')
$noRules = New-DevkitIgnoreMatcher (New-Object System.Collections.Generic.List[object])

# Git metadata and profile folders are always excluded, as SSP does.
function Test-Excluded($Matcher, [string]$RelativePath) {
    $segments = $RelativePath.Split('/')
    if ($segments -contains '.git') { return $true }
    if ($segments.Count -ge 2 -and ($segments[0..($segments.Count - 2)] -contains 'profile')) { return $true }
    return (Test-DevkitIgnored $Matcher $RelativePath)
}

$narFiles = @($files | Where-Object { -not (Test-Excluded $narMatcher $_) })
$updFiles = @($files | Where-Object { -not (Test-Excluded $updMatcher $_) })
if ($narFiles -notcontains 'install.txt') {
    Write-Host 'build-site: FAILED - install.txt is not in the nar (.narignore excludes it)'
    exit 1
}
if ($updFiles -notcontains 'delete.txt') { Write-Host 'build-site: note - delete.txt is not in the update files' }

# Balloons that the nar bundles: "balloon.directory,NAME" in install.txt is the name after installation, and
# "balloon.source.directory,DIR" (default: NAME) is the folder in the archive. Each gets its own update files, published
# in the folder NAME of the site, so that the descript.txt of the balloon can point its "homeurl" there.
$balloons = @()
$installLines = [IO.File]::ReadAllLines($installTxt, $DevkitUtf8)
foreach ($line in $installLines) {
    if ($line -notmatch '^\s*(balloon\d*)\.directory\s*,\s*(.+?)\s*$') { continue }
    $key = $Matches[1]
    $name = $Matches[2]
    $source = $name
    foreach ($other in $installLines) {
        if ($other -match ('^\s*' + [regex]::Escape($key) + '\.source\.directory\s*,\s*(.+?)\s*$')) { $source = $Matches[1] }
    }
    $source = $source.Replace('\', '/').Trim('/')
    # updates2.dau and updates.txt in the folder of the balloon belong to an older homeurl, not to the balloon.
    $balloonFiles = @($files | Where-Object {
            $_.StartsWith($source + '/', [StringComparison]::OrdinalIgnoreCase) -and
            (@('updates2.dau', 'updates.txt') -notcontains $_.Substring($source.Length + 1)) -and
            -not (Test-Excluded $noRules $_)
        })
    if ($balloonFiles.Count -eq 0) {
        Write-Host "build-site: note - the balloon folder has no tracked files: $source"
        continue
    }
    $inGhostList = @($updFiles | Where-Object { $_.StartsWith($source + '/', [StringComparison]::OrdinalIgnoreCase) })
    if ($inGhostList.Count -gt 0) {
        Write-Host "build-site: FAILED - the update files of the ghost contain the balloon folder $source (add it to .updateignore)"
        exit 1
    }
    $balloons += [pscustomobject]@{ Name = $name; Source = $source; Files = $balloonFiles }
}

Write-Host ("tracked files : {0}" -f $files.Count)
Write-Host ("nar           : {0} included, {1} excluded (.narignore)" -f $narFiles.Count, ($files.Count - $narFiles.Count))
Write-Host ("update files  : {0} included, {1} excluded (.updateignore)" -f $updFiles.Count, ($files.Count - $updFiles.Count))
foreach ($b in $balloons) { Write-Host ("balloon {0} : {1} files (own update files)" -f $b.Name, $b.Files.Count) }

if ($ListOnly) {
    foreach ($b in $balloons) {
        Write-Host ("== balloon {0} ==" -f $b.Name)
        $b.Files | ForEach-Object { '  ' + $_.Substring($b.Source.Length + 1) }
    }
    Write-Host '== nar =='
    $narFiles | ForEach-Object { '  ' + $_ }
    Write-Host '== update files =='
    $updFiles | ForEach-Object { '  ' + $_ }
    Write-Host '== only in the nar =='
    $narFiles | Where-Object { $updFiles -notcontains $_ } | ForEach-Object { '  ' + $_ }
    Write-Host '== only in the update files =='
    $updFiles | Where-Object { $narFiles -notcontains $_ } | ForEach-Object { '  ' + $_ }
    exit 0
}

# --- output --------------------------------------------------------------------------------------
if ($OutDir.TrimEnd('\', '/') -ieq $root -or $root.StartsWith($OutDir.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Host 'build-site: FAILED - -OutDir must not be the ghost root or a folder that contains it (it is emptied first)'
    exit 1
}
if ($OutDir.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    $rel = $OutDir.Substring($root.Length + 1).Replace('\', '/')
    if (-not (Test-Excluded $narMatcher ($rel + '/x')) -or -not (Test-Excluded $updMatcher ($rel + '/x'))) {
        Write-Host "build-site: note - $rel is inside the ghost folder and .narignore / .updateignore do not exclude it"
    }
}
if (Test-Path -LiteralPath $OutDir) { Remove-Item -LiteralPath $OutDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutDir | Out-Null

# The nar: build-nar.ps1 does it (the same files as the nar of the releases).
$narPath = Join-Path $OutDir $NarName
$powershell = (Get-Process -Id $PID).Path
& $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build-nar.ps1') -Builtin -OutFile $narPath -GhostRoot $root
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $narPath -PathType Leaf)) {
    Write-Host 'build-site: FAILED - build-nar.ps1 could not write the nar'
    exit 1
}

Write-UpdateSet $OutDir @($updFiles | ForEach-Object { [pscustomobject]@{ Source = $_; Name = $_ } })
Write-Host ("build-site: wrote updates2.dau and updates.txt ({0} files)" -f $updFiles.Count)
foreach ($b in $balloons) {
    $prefixLength = $b.Source.Length + 1
    Write-UpdateSet (Join-Path $OutDir $b.Name) @($b.Files | ForEach-Object { [pscustomobject]@{ Source = $_; Name = $_.Substring($prefixLength) } })
    Write-Host ("build-site: wrote {0}/updates2.dau and updates.txt ({1} files)" -f $b.Name, $b.Files.Count)
}

# GitHub Pages must not run Jekyll (it would hide files and folders whose names start with "_" or ".").
[IO.File]::WriteAllText((Join-Path $OutDir '.nojekyll'), '', $DevkitUtf8)
$links = "<p><a href=""$NarName"">$NarName</a></p>`n<p>Files for network update: <a href=""updates2.dau"">updates2.dau</a></p>`n"
foreach ($b in $balloons) {
    $links += "<p>Balloon $($b.Name), files for network update: <a href=""$($b.Name)/updates2.dau"">$($b.Name)/updates2.dau</a></p>`n"
}
[IO.File]::WriteAllText((Join-Path $OutDir 'index.html'), "<!doctype html>`n<meta charset=""utf-8"">`n<title>$NarName</title>`n$links", $DevkitUtf8)

# The metainfo folder is published as it is, next to the update files. Its name starts with ".", so .nojekyll is needed,
# and actions/upload-pages-artifact has to be v3 (v4 leaves out hidden files).
$metainfoFiles = @($files | Where-Object { $_.StartsWith('.ukagaka/', [StringComparison]::Ordinal) })
foreach ($relative in $metainfoFiles) {
    $target = Join-Path $OutDir $relative
    $targetDir = Split-Path $target -Parent
    if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target -Force
}
if ($metainfoFiles.Count -gt 0) { Write-Host ("build-site: copied the metainfo folder .ukagaka ({0} files)" -f $metainfoFiles.Count) }

# The introduction page replaces the plain index.html and adds its images.
$intro = Join-Path $root $IntroDir
if ($IntroDir -and (Test-Path -LiteralPath $intro -PathType Container)) {
    Copy-Item -Path (Join-Path $intro '*') -Destination $OutDir -Recurse -Force
    Write-Host "build-site: copied the introduction page $IntroDir"
}
Write-Host "build-site: done - $OutDir"
exit 0
