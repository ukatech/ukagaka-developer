<#
.SYNOPSIS
    Checks this repository: PowerShell syntax, ASCII-only scripts, the paths that the documents point to, the parts of
    each SHIORI, and the plugin files.
.DESCRIPTION
    Run it before pushing (docs/maintaining/MAINTAINING.md). It also runs on GitHub Actions (.github/workflows/check.yml).
    Exit codes: 0 = all checks passed, 1 = a check failed.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tests/check-repo.ps1
#>
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$skill = Join-Path $repo 'skills/ukagaka-developer'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$errors = New-Object System.Collections.Generic.List[string]
function Fail([string]$Message) { $errors.Add($Message); Write-Host "[FAIL] $Message" }
function Relative([string]$Path) { return $Path.Substring($repo.Length + 1).Replace('\', '/') }

# --- scripts: syntax and ASCII -------------------------------------------------------------
$codeFiles = @(Get-ChildItem -LiteralPath $skill -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.cs') })
$codeFiles += @(Get-ChildItem -LiteralPath (Join-Path $repo 'tests') -File -Filter '*.ps1')
foreach ($file in $codeFiles) {
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { Fail "$(Relative $file.FullName): has a BOM" }
    $line = 1
    foreach ($b in $bytes) {
        if ($b -gt 127) { Fail "$(Relative $file.FullName): non-ASCII byte near line $line"; break }
        if ($b -eq 10) { $line++ }
    }
    if ($file.Extension -eq '.ps1') {
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        foreach ($e in @($parseErrors)) { Fail "$(Relative $file.FullName):$($e.Extent.StartLineNumber): $($e.Message)" }
    }
}
Write-Host "checked $($codeFiles.Count) script/source files"

# --- old kit paths in the scripts ----------------------------------------------------------
$legacyAllowed = @('scripts/lib/legacy-devkit.ps1', 'scripts/migrate-from-devkit.ps1', 'scripts/doctor.ps1', 'scripts/lib/common.ps1', 'scripts/lib/ghost-files.ps1', 'scripts/build-nar.ps1', 'scripts/init-ghost.ps1')
foreach ($file in ($codeFiles | Where-Object { $_.Extension -eq '.ps1' -and $_.FullName -like '*skills*' })) {
    $relative = (Relative $file.FullName).Replace('skills/ukagaka-developer/', '')
    if ($legacyAllowed -contains $relative) { continue }
    $text = [IO.File]::ReadAllText($file.FullName, $utf8)
    if ($text -match '(?m)\btools/[A-Za-z]') { Fail "${relative}: mentions tools/ (the old kit); only the migration may" }
    if ($text -match 'docs/agents') { Fail "${relative}: mentions docs/agents (the old kit)" }
}

# --- SKILL.md --------------------------------------------------------------------------------
$skillMd = Join-Path $skill 'SKILL.md'
$skillText = [IO.File]::ReadAllText($skillMd, $utf8)
$skillLines = $skillText -split "`n"
if ($skillLines.Count -gt 500) { Fail "SKILL.md has $($skillLines.Count) lines (500 or less)" }
if ($skillText -notmatch '(?s)\A---\r?\nname: ukagaka-developer\r?\ndescription: .+?\r?\n(allowed-tools:.*?)?---') { Fail 'SKILL.md: the front matter is not "name" then "description"' }
foreach ($m in [regex]::Matches($skillText, '\$\{CLAUDE_SKILL_DIR\}/(scripts/[A-Za-z0-9_./-]+?\.ps1)')) {
    if (-not (Test-Path -LiteralPath (Join-Path $skill $m.Groups[1].Value))) { Fail "SKILL.md allowed-tools: $($m.Groups[1].Value) does not exist" }
}

# --- paths that the documents point to ------------------------------------------------------
$docs = @(Get-ChildItem -LiteralPath $skill -Recurse -File -Filter '*.md')
$docs += Get-Item -LiteralPath (Join-Path $repo 'README.md')
$docs += @(Get-ChildItem -LiteralPath (Join-Path $repo 'agents') -File -Filter '*.md')
$checked = 0
foreach ($doc in $docs) {
    $text = [IO.File]::ReadAllText($doc.FullName, $utf8)
    foreach ($m in [regex]::Matches($text, '`((?:references|scripts|templates)/[A-Za-z0-9_./<>|*-]+)`')) {
        $path = $m.Groups[1].Value
        if ($path -match '[<>|*]') { continue }
        if ($path.EndsWith('/')) { $path = $path.TrimEnd('/') }
        $checked++
        if (-not (Test-Path -LiteralPath (Join-Path $skill $path))) { Fail "$(Relative $doc.FullName): points to $path, which does not exist" }
    }
}
Write-Host "checked $checked document paths"

# --- the parts of each SHIORI ---------------------------------------------------------------
$shioriIds = @(Get-ChildItem -LiteralPath (Join-Path $skill 'scripts/shiori') -Directory | ForEach-Object { $_.Name })
foreach ($id in $shioriIds) {
    foreach ($name in @('lib.ps1', 'check-dic.ps1', 'shiori.ps1', 'update.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $skill "scripts/shiori/$id/$name"))) { Fail "scripts/shiori/$id/$name is missing" }
    }
    foreach ($name in @('dictionary.md', 'check.md', 'commands.md', 'update.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $skill "references/$id/$name"))) { Fail "references/$id/$name is missing" }
    }
    foreach ($name in @('GHOST.md', 'narignore', 'gitattributes', 'editorconfig')) {
        if (-not (Test-Path -LiteralPath (Join-Path $skill "templates/$id/$name"))) { Fail "templates/$id/$name is missing" }
    }
    $lib = [IO.File]::ReadAllText((Join-Path $skill "scripts/shiori/$id/lib.ps1"), $utf8)
    foreach ($fn in @('Invoke-DevkitTamacs', 'Add-DevkitShioriDoctorItems', 'Invoke-DevkitShioriSetup', '$DevkitTamacsPurpose')) {
        if (-not $lib.Contains($fn)) { Fail "scripts/shiori/$id/lib.ps1 does not define $fn" }
    }
    $common = [IO.File]::ReadAllText((Join-Path $skill 'scripts/lib/common.ps1'), $utf8)
    if ($common -notmatch "Id = '$id'") { Fail "$id is not in `$DevkitShioriTable of scripts/lib/common.ps1" }
}
foreach ($name in @('AGENTS.md', 'CLAUDE.md', 'updateignore', 'narignore.dev', 'github/auto_check.yml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $skill "templates/$name"))) { Fail "templates/$name is missing" }
}
$narDev = [IO.File]::ReadAllText((Join-Path $skill 'templates/narignore.dev'), $utf8)
if (-not $narDev.Contains('# files for developing the ghost with ukagaka-developer')) { Fail 'templates/narignore.dev lost the marker line that scripts/lib/ghost-files.ps1 looks for' }

# --- plugin files ---------------------------------------------------------------------------
foreach ($name in @('.claude-plugin/plugin.json', '.claude-plugin/marketplace.json', '.mcp.json')) {
    $path = Join-Path $repo $name
    try {
        $json = [IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
    } catch {
        Fail "${name}: not valid JSON ($($_.Exception.Message))"
        continue
    }
    # No version: Claude Code then follows the commit, so every push reaches the users (docs/maintaining/MAINTAINING.md).
    if ($json.PSObject.Properties.Name -contains 'version') { Fail "${name}: has a version; leave it out so that updates follow the commits" }
    if ($name -like '*marketplace.json') {
        foreach ($plugin in @($json.plugins)) {
            if ($plugin.PSObject.Properties.Name -contains 'version') { Fail "${name}: the plugin entry has a version" }
        }
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $repo 'agents/ukagaka-researcher.md'))) { Fail 'agents/ukagaka-researcher.md is missing' }

# --- official URLs that moved ---------------------------------------------------------------
$ExpectedUrls = @('https://ukatech.shillest.net/satori-docs/', 'https://ukatech.shillest.net/kawari-docs/')
foreach ($url in $ExpectedUrls) {
    if (-not $skillText.Contains($url)) { Fail "SKILL.md does not mention $url" }
}
# The Japanese word for "redirected" (U+8EE2 U+9001); this file is ASCII only.
$redirectWord = [string][char]0x8EE2 + [char]0x9001
foreach ($doc in $docs) {
    $text = [IO.File]::ReadAllText($doc.FullName, $utf8)
    if ($text -match 'ukatech\.github\.io/satori-docs' -and -not $text.Contains($redirectWord)) {
        Fail "$(Relative $doc.FullName): uses the old satori-docs address (ukatech.github.io); it moved to ukatech.shillest.net"
    }
}

Write-Host ''
if ($errors.Count -gt 0) {
    Write-Host "check-repo: FAILED ($($errors.Count) problem(s))"
    exit 1
}
Write-Host 'check-repo: OK'
exit 0
