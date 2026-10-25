# Helpers for the files that the skill puts into a ghost folder (templates/): GHOST.md, .narignore, AGENTS.md and so on.
# Dot-source after common.ps1:   . (Join-Path $PSScriptRoot 'lib/ghost-files.ps1')
# Keep every .ps1 file ASCII-only and compatible with Windows PowerShell 5.1.

$DevkitTemplatesDir = Join-Path $DevkitSkillDir 'templates'
# The line that starts the block of development files in .narignore (templates/narignore.dev).
$DevkitNarignoreDevMarker = '# files for developing the ghost with ukagaka-developer'
$DevkitLegacyNarignoreInclude = 'include:tools/devkit.narignore'

function Read-DevkitTemplate([string]$RelativePath) {
    $path = Join-Path $DevkitTemplatesDir $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "template not found: $path" }
    return ([IO.File]::ReadAllText($path, $DevkitUtf8) -replace "`r`n", "`n")
}

function Write-DevkitTextFile([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, $DevkitUtf8)
}

# The block of development files for .narignore, without the blank line that starts it in the template.
function Get-DevkitNarignoreDevBlock {
    return ((Read-DevkitTemplate 'narignore.dev').TrimStart("`n"))
}

# Tells whether a .narignore text already has the block of development files.
function Test-DevkitNarignoreHasDevBlock([string]$Text) {
    return $Text.Contains($DevkitNarignoreDevMarker)
}

# Returns a .narignore text with the development block: the line "include:tools/devkit.narignore" of the old
# development kit is replaced by the block; without that line, the block is appended. A text that has the block
# is returned as it is.
# -LegacyKitRules is the text of the old kit's tools/devkit.narignore: its rules that still matter (for YAYA, the files of
# the yaya-dic repository that the nar leaves out, and *.yaya-dic-new) are carried over under a comment.
function Add-DevkitNarignoreDevBlock([string]$Text, [string]$LegacyKitRules = '') {
    $text = $Text -replace "`r`n", "`n"
    if (Test-DevkitNarignoreHasDevBlock $text) { return $text }
    $text = $text.Replace('Used by SSP and tools/build-nar.ps1.', 'Used by SSP and by build-nar.ps1 of ukagaka-developer.')
    $block = Get-DevkitNarignoreDevBlock
    $lines = New-Object System.Collections.Generic.List[string]
    $replaced = $false
    foreach ($line in $text.Split("`n")) {
        # The comment that the old kit wrote above its include line.
        if ($line.StartsWith('# development kit (tools/devkit.narignore')) { continue }
        if ($line.Trim() -eq $DevkitLegacyNarignoreInclude) {
            if (-not $replaced) { foreach ($blockLine in $block.TrimEnd("`n").Split("`n")) { $lines.Add($blockLine) } }
            $replaced = $true
            continue
        }
        $lines.Add($line)
    }
    $result = $lines -join "`n"
    if ($replaced -and $LegacyKitRules) {
        $carried = New-Object System.Collections.Generic.List[string]
        $skipPattern = '^(/?tools/|/?build/|/\.claude/settings\.local\.json|\*\.devkit-new|/ghost/master/devkit-balloon)'
        foreach ($rule in ($LegacyKitRules -replace "`r`n", "`n").Split("`n")) {
            $trimmed = $rule.Trim()
            if (-not $trimmed -or $trimmed.StartsWith('#') -or $trimmed -match $skipPattern) { continue }
            if ($lines -contains $rule -or $lines -contains $trimmed) { continue }
            $carried.Add($trimmed)
        }
        if ($carried.Count -gt 0) {
            $result = $result.TrimEnd("`n") + "`n`n# carried over from tools/devkit.narignore of the old development kit`n" + ($carried -join "`n")
        }
    }
    if (-not $replaced) { $result = $result.TrimEnd("`n") + "`n`n" + $block }
    if (-not $result.EndsWith("`n")) { $result += "`n" }
    return $result
}

# The starter files of a ghost: destination (relative to the ghost root) and the way to make its text.
# Returns objects with Path and Text. Only for the files that do not exist when -OnlyMissing is given.
function Get-DevkitStarterFiles([string]$ShioriId, [string]$Root, [switch]$OnlyMissing) {
    $files = @(
        [pscustomobject]@{ Path = 'GHOST.md'; Text = (Read-DevkitTemplate "$ShioriId/GHOST.md") },
        [pscustomobject]@{ Path = 'AGENTS.md'; Text = (Read-DevkitTemplate 'AGENTS.md') },
        [pscustomobject]@{ Path = 'CLAUDE.md'; Text = (Read-DevkitTemplate 'CLAUDE.md') },
        [pscustomobject]@{ Path = '.narignore'; Text = ((Read-DevkitTemplate "$ShioriId/narignore").TrimEnd("`n") + "`n`n" + (Get-DevkitNarignoreDevBlock)) },
        [pscustomobject]@{ Path = '.updateignore'; Text = (Read-DevkitTemplate 'updateignore') },
        [pscustomobject]@{ Path = '.gitattributes'; Text = (Read-DevkitTemplate "$ShioriId/gitattributes") },
        [pscustomobject]@{ Path = '.editorconfig'; Text = (Read-DevkitTemplate "$ShioriId/editorconfig") }
    )
    if ($OnlyMissing) { return @($files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Root $_.Path)) }) }
    return $files
}
