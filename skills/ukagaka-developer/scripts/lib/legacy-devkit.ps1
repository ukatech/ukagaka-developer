# Readers for the old AI development kit (tools/devkit.json, tools/devkit.lock.json), used by migrate-from-devkit.ps1
# and doctor.ps1 to find and remove it. Dot-source after common.ps1 and ignore.ps1.
# tools/devkit.json listed the kit-owned files ("files" minus "exclude", gitignore-style globs) and the
# seed files ("seed": destination -> source in the kit), which were created only when they were missing.
# tools/devkit.lock.json recorded the upstream hash of each kit file at the last update.

$DevkitManifestName = 'tools/devkit.json'
$DevkitLockName = 'tools/devkit.lock.json'
$DevkitConflictSuffix = '.devkit-new'

function Read-DevkitManifest([string]$Root) {
    $path = Join-Path $Root $DevkitManifestName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$DevkitManifestName was not found in $Root" }
    return ([IO.File]::ReadAllText($path, $DevkitUtf8) | ConvertFrom-Json)
}

function New-DevkitGlobRegex([string]$Glob) {
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    $body = ConvertFrom-DevkitIgnoreGlob $Glob.TrimStart('/')
    return (New-Object System.Text.RegularExpressions.Regex(('^' + $body + '$'), $options))
}

# Returns the root-relative paths (ordinal order) of the kit-owned files that exist under $Root.
function Get-DevkitKitFiles([string]$Root, $Manifest) {
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $excludes = @($Manifest.exclude | Where-Object { $_ } | ForEach-Object { New-DevkitGlobRegex $_ })
    $found = @{}
    foreach ($glob in @($Manifest.files)) {
        $regex = New-DevkitGlobRegex $glob
        # Only walk the folder before the first segment that has a wildcard.
        $segments = $glob.TrimStart('/').Split('/')
        $literal = New-Object System.Collections.Generic.List[string]
        foreach ($segment in $segments) {
            if ($segment -match '[\*\?\[]') { break }
            $literal.Add($segment)
        }
        $basePath = if ($literal.Count -eq 0) { $rootPath } else { Join-Path $rootPath ($literal -join '/') }
        $candidates = @()
        if ($literal.Count -eq $segments.Count) {
            if (Test-Path -LiteralPath $basePath -PathType Leaf) { $candidates = @(Get-Item -LiteralPath $basePath -Force) }
        } elseif (Test-Path -LiteralPath $basePath -PathType Container) {
            $candidates = @(Get-ChildItem -LiteralPath $basePath -Recurse -File -Force)
        }
        foreach ($item in $candidates) {
            $relative = $item.FullName.Substring($rootPath.Length + 1).Replace('\', '/')
            if (-not $regex.IsMatch($relative)) { continue }
            $excluded = $false
            foreach ($exclude in $excludes) {
                if ($exclude.IsMatch($relative)) { $excluded = $true; break }
            }
            if (-not $excluded) { $found[$relative] = $true }
        }
    }
    [string[]]$paths = @($found.Keys)
    [Array]::Sort($paths, [StringComparer]::Ordinal)
    return , $paths
}

function Read-DevkitLock([string]$Root) {
    $lock = [pscustomobject]@{ Exists = $false; Source = ''; Ref = ''; Files = @{} }
    $path = Join-Path $Root $DevkitLockName
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $json = [IO.File]::ReadAllText($path, $DevkitUtf8) | ConvertFrom-Json
        $lock.Exists = $true
        if ($json.source) { $lock.Source = [string]$json.source }
        if ($json.ref) { $lock.Ref = [string]$json.ref }
        if ($json.files) {
            foreach ($property in $json.files.PSObject.Properties) { $lock.Files[$property.Name] = [string]$property.Value }
        }
    }
    return $lock
}

# Lists the <file>.devkit-new files left by an update (root-relative paths). Wrap the call in @().
function Get-DevkitConflictFiles([string]$Root) {
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $pattern = '*' + $DevkitConflictSuffix
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($item in @(Get-ChildItem -LiteralPath $rootPath -File -Force -ErrorAction SilentlyContinue)) { $items.Add($item) }
    foreach ($folder in @('.claude', '.github', 'docs', 'tools')) {
        $path = Join-Path $rootPath $folder
        if (Test-Path -LiteralPath $path -PathType Container) {
            foreach ($item in @(Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue)) { $items.Add($item) }
        }
    }
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($item in $items) {
        if ($item.Name -like $pattern) { $result.Add($item.FullName.Substring($rootPath.Length + 1).Replace('\', '/')) }
    }
    return $result.ToArray()
}
