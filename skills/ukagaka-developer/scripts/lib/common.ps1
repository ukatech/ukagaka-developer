# Shared helpers for the scripts of the ukagaka-developer skill.
# Dot-source it from a script in scripts/:   . (Join-Path $PSScriptRoot 'lib/common.ps1')
# From a script in scripts/shiori/<name>/:   . (Join-Path $PSScriptRoot '../../lib/common.ps1')
# Keep every .ps1 file of the skill ASCII-only and compatible with Windows PowerShell 5.1.
#
# Where things are:
#   skill folder   the folder that holds SKILL.md (scripts/ is its subfolder). Read-only: a plugin update replaces it.
#   ghost root     the folder that holds ghost/master/descript.txt: the ghost that is being developed.
#   home folder    where the scripts keep what they build or download (compiled tools, local.json).
#                  UKADEV_HOME, or %LOCALAPPDATA%\ukagaka-developer.

# pwsh 7 puts its own module folders at the head of PSModulePath. It drops them again when it starts
# powershell.exe directly, but not when another program is in between (an agent started from a pwsh
# terminal that runs the scripts from its shell tool, or cmd.exe). Windows PowerShell 5.1 then loads
# the pwsh build of Microsoft.PowerShell.Utility, which it cannot use, and Get-FileHash and the like
# are not found. Drop those folders before any module is loaded.
if ($PSVersionTable.PSEdition -eq 'Desktop' -and $env:PSModulePath) {
    $env:PSModulePath = (@($env:PSModulePath -split ';') | Where-Object {
        $_ -and $_ -notmatch '\\PowerShell\\([0-9][^\\]*\\)?Modules\\?$'
    }) -join ';'
}

$DevkitLibDir = $PSScriptRoot
$DevkitScriptsDir = [IO.Path]::GetFullPath((Join-Path $DevkitLibDir '..')).TrimEnd('\', '/')
$DevkitSkillDir = [IO.Path]::GetFullPath((Join-Path $DevkitScriptsDir '..')).TrimEnd('\', '/')
$DevkitUtf8 = New-Object System.Text.UTF8Encoding($false)
# SSP version that the scripts are written for. They assume it and do not branch on the version of SSP;
# only doctor.ps1 checks it and reports older versions.
$DevkitSspRecommendedVersion = New-Object System.Version(2, 9, 8)
# The ghost root. Set by Initialize-DevkitConsole.
$DevkitRoot = $null
# First line of a GHOST.md that has not been written yet (templates/GHOST.md).
$DevkitGhostTemplateMarker = '<!-- devkit:ghost-template -->'

# Resolves a possibly relative path against the PowerShell location (not the process directory).
function Resolve-DevkitFullPath([string]$Path) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

# --- home folder (compiled tools, settings) -----------------------------------------------

function Get-DevkitHome {
    if ($env:UKADEV_HOME) { return (Resolve-DevkitFullPath $env:UKADEV_HOME).TrimEnd('\', '/') }
    if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA 'ukagaka-developer') }
    return (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ukagaka-developer')
}
$DevkitHome = Get-DevkitHome
$DevkitBinDir = Join-Path $DevkitHome 'bin'

# --- ghost root ---------------------------------------------------------------------------

# Tells whether a folder is the root of a ghost (it holds ghost/master/descript.txt).
function Test-DevkitGhostRoot([string]$Path) {
    return ([bool]$Path -and (Test-Path -LiteralPath (Join-Path $Path 'ghost/master/descript.txt') -PathType Leaf))
}

# Finds the ghost root: the explicit path, UKADEV_GHOST_ROOT, or the current folder and its parents.
# Returns $null when there is none.
function Find-DevkitGhostRoot([string]$Explicit) {
    if ($Explicit) {
        $full = (Resolve-DevkitFullPath $Explicit).TrimEnd('\', '/')
        if (Test-DevkitGhostRoot $full) { return $full }
        return $null
    }
    if ($env:UKADEV_GHOST_ROOT) {
        $full = (Resolve-DevkitFullPath $env:UKADEV_GHOST_ROOT).TrimEnd('\', '/')
        if (Test-DevkitGhostRoot $full) { return $full }
    }
    $dir = (Get-Location).ProviderPath
    while ($dir) {
        if (Test-DevkitGhostRoot $dir) { return $dir.TrimEnd('\', '/') }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

# Returns the value that follows -Name in an argument array ($args of a dispatcher script), or $null.
function Get-DevkitArgValue($ArgumentList, [string]$Name) {
    $items = @($ArgumentList)
    for ($i = 0; $i -lt $items.Count; $i++) {
        $text = [string]$items[$i]
        if ($text -ieq "-$Name" -and $i + 1 -lt $items.Count) { return [string]$items[$i + 1] }
        if ($text -like "-${Name}:*") { return $text.Substring($Name.Length + 2) }
    }
    return $null
}

# Prepares the console and sets $DevkitRoot (the ghost root).
# Scripts that take -GhostRoot declare [string]$GhostRoot; it is read from the calling script's scope. Dispatcher
# scripts, which have no parameters of their own, pass -Arguments $args instead. -NoGhost is for scripts that work
# without a ghost (the skill updater, the migration of an old kit that finds its own folder).
function Initialize-DevkitConsole {
    param([switch]$NoGhost, $Arguments)
    try { [Console]::OutputEncoding = $DevkitUtf8 } catch { }
    try { $global:OutputEncoding = $DevkitUtf8 } catch { }
    if ($NoGhost) { return }
    $explicit = $null
    if ($Arguments) { $explicit = Get-DevkitArgValue $Arguments 'GhostRoot' }
    if (-not $explicit -and (Test-Path variable:GhostRoot)) { $explicit = [string]$GhostRoot }
    $root = Find-DevkitGhostRoot $explicit
    if (-not $root) {
        if ($explicit) {
            Write-Host "ghost root: $explicit has no ghost/master/descript.txt"
        } else {
            Write-Host 'ghost root: the current folder is not inside a ghost (no ghost/master/descript.txt in it or its parents).'
        }
        Write-Host 'Run the script from the ghost root folder (the one that contains ghost/ and shell/), or pass -GhostRoot <folder>, or set UKADEV_GHOST_ROOT.'
        exit 1
    }
    $script:DevkitRoot = $root
}

# --- SHIORI (YAYA, SATORI) ----------------------------------------------------------------

# Names of the SHIORI that the skill supports: folder under scripts/shiori/ -> dll name and display name.
$DevkitShioriTable = @(
    [pscustomobject]@{ Id = 'yaya'; Dll = 'yaya.dll'; Name = 'YAYA' },
    [pscustomobject]@{ Id = 'satori'; Dll = 'satori.dll'; Name = 'SATORI' }
)

# Returns the id of the SHIORI of a ghost ('yaya' or 'satori'), or $null when it is neither. It follows the shiori key
# of descript.txt, then the dll that exists in ghost/master.
function Get-DevkitShiori([string]$GhostDir) {
    if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
    $key = Get-DevkitDescriptValue (Join-Path $GhostDir 'descript.txt') 'shiori'
    if ($key) {
        foreach ($entry in $DevkitShioriTable) {
            if ($key -like "*$($entry.Id)*") { return $entry.Id }
        }
    }
    foreach ($entry in $DevkitShioriTable) {
        if (Test-Path -LiteralPath (Join-Path $GhostDir $entry.Dll) -PathType Leaf) { return $entry.Id }
    }
    return $null
}

# Returns the entry of $DevkitShioriTable for an id.
function Get-DevkitShioriInfo([string]$Id) {
    return ($DevkitShioriTable | Where-Object { $_.Id -eq $Id } | Select-Object -First 1)
}

# Returns the folder that holds the scripts of a SHIORI.
function Get-DevkitShioriDir([string]$Id) {
    return (Join-Path (Join-Path $DevkitScriptsDir 'shiori') $Id)
}

# The helpers of a SHIORI are in scripts/shiori/<id>/lib.ps1. A function cannot dot-source them into its caller, so a
# script does it itself:  . (Join-Path (Get-DevkitShioriDir $id) 'lib.ps1')

# Finds scripts/shiori/<id>/<Name>.ps1 for the ghost's SHIORI. Returns Path (or $null) and Code (the exit code to use
# when there is no script). Used by the scripts that exist for both SHIORI (check-dic.ps1, shiori.ps1, lint.ps1,
# update-shiori.ps1). They then run it with "& $target.Path @args" themselves: only $args keeps the options such as -Run
# as parameters when it is splatted.
function Resolve-DevkitShioriScript([string]$Name, [string]$Label = $Name) {
    $id = Get-DevkitShiori
    if (-not $id) {
        Write-Host "${Label}: FAILED - this ghost has neither ghost/master/yaya.dll nor ghost/master/satori.dll (and descript.txt has no shiori key for them). Only YAYA and SATORI are supported."
        return [pscustomobject]@{ Path = $null; Code = 1 }
    }
    $script = Join-Path (Get-DevkitShioriDir $id) "$Name.ps1"
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
        Write-Host "${Label}: not available for $((Get-DevkitShioriInfo $id).Name)"
        return [pscustomobject]@{ Path = $null; Code = 3 }
    }
    return [pscustomobject]@{ Path = $script; Code = 0 }
}

# --- tools that are downloaded or built ---------------------------------------------------

function Get-DevkitToolManifest {
    $path = Join-Path $DevkitScriptsDir 'tools.json'
    return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-DevkitToolPath([string]$Name) {
    $entry = (Get-DevkitToolManifest).$Name
    if ($null -eq $entry) { throw "Unknown tool: $Name" }
    return (Join-Path $DevkitBinDir $entry.exe)
}

# Tells whether an installed tool is recent enough for the skill: $null when it is not installed, $false when it is out
# of date, $true otherwise (also when that cannot be told). Works offline.
# - Tools that follow the latest release (version "latest"): the file version must be minimumVersion or later.
# - Pinned tools (version, url, sha256): the file must match the pinned SHA256, which changes when a skill update
#   raises the version. Only single-file tools (type exe) can be compared.
function Test-DevkitToolCurrent([string]$Name) {
    $entry = (Get-DevkitToolManifest).$Name
    if ($null -eq $entry) { throw "Unknown tool: $Name" }
    $path = Join-Path $DevkitBinDir $entry.exe
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    if ($entry.version -eq 'latest') {
        $version = Get-DevkitFileVersion $path
        if (-not $version -or -not $entry.minimumVersion) { return $true }
        return ($version -ge [version]$entry.minimumVersion)
    }
    if ($entry.type -ne 'exe') { return $true }
    return ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $entry.sha256)
}

# Returns the file version of a program (for example 1.0.3.25), or $null when it has none.
function Get-DevkitFileVersion([string]$Path) {
    try {
        $info = (Get-Item -LiteralPath $Path).VersionInfo
        if ($info.FileMajorPart -gt 0 -or $info.FileMinorPart -gt 0) {
            return (New-Object System.Version($info.FileMajorPart, $info.FileMinorPart, $info.FileBuildPart, $info.FilePrivatePart))
        }
    } catch { }
    return $null
}

# GET request to the GitHub REST API (JSON). GITHUB_TOKEN is used when it is set, which avoids the rate limit of
# anonymous requests on GitHub Actions; when the token is refused, the request is sent without it.
function Invoke-DevkitGitHubApi([string]$Uri) {
    $headers = @{ 'User-Agent' = 'ukagaka-developer'; 'Accept' = 'application/vnd.github+json' }
    if ($env:GITHUB_TOKEN) {
        $withToken = $headers.Clone()
        $withToken['Authorization'] = 'Bearer ' + $env:GITHUB_TOKEN
        try { return (Invoke-RestMethod -UseBasicParsing -Uri $Uri -Headers $withToken) } catch { }
    }
    return (Invoke-RestMethod -UseBasicParsing -Uri $Uri -Headers $headers)
}

# Looks up an asset in the latest release of a GitHub repository. Returns Tag, Url and Sha256 (from the digest that
# GitHub publishes for each asset; $null when there is none).
function Get-DevkitLatestReleaseAsset([string]$Repository, [string]$AssetName) {
    if ($Repository -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') { throw "invalid repository: $Repository" }
    $release = Invoke-DevkitGitHubApi "https://api.github.com/repos/$Repository/releases/latest"
    $asset = @($release.assets | Where-Object { $_.name -eq $AssetName }) | Select-Object -First 1
    if (-not $asset) { throw "$AssetName was not found in the latest release ($($release.tag_name)) of $Repository" }
    $sha256 = $null
    if ([string]$asset.digest -match '^sha256:([0-9a-fA-F]{64})$') { $sha256 = $matches[1].ToUpperInvariant() }
    return [pscustomobject]@{ Tag = [string]$release.tag_name; Url = [string]$asset.browser_download_url; Sha256 = $sha256 }
}

# Returns csc.exe of the .NET Framework 4 (part of Windows), or $null when there is none.
function Get-DevkitCscPath {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not $env:windir) { return $null }
    foreach ($framework in @('Framework', 'Framework64')) {
        $csc = Join-Path $env:windir "Microsoft.NET\$framework\v4.0.30319\csc.exe"
        if (Test-Path -LiteralPath $csc -PathType Leaf) { return $csc }
    }
    return $null
}

# Returns the path that the exe built from scripts/lib/<Name>.cs has for the current source:
# <home>/bin/<Name>-<hash of the source>.exe.
function Get-DevkitCsToolExpectedPath([string]$Name) {
    $source = Join-Path $DevkitLibDir "$Name.cs"
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([IO.File]::ReadAllBytes($source))
    } finally {
        $sha.Dispose()
    }
    $hash = -join ($bytes[0..7] | ForEach-Object { $_.ToString('x2') })
    return (Join-Path $DevkitBinDir "$Name-$hash.exe")
}

# Builds <Name>.exe from scripts/lib/<Name>.cs when the current source has not been built yet, with csc.exe of the
# .NET Framework and the given options (/target:..., /platform:..., /reference:...). Returns Path (the exe, or
# $null) and Error (why it is not available). The exes built from older sources are removed.
function Get-DevkitCsTool([string]$Name, [string[]]$Options) {
    $exe = Get-DevkitCsToolExpectedPath $Name
    if (Test-Path -LiteralPath $exe -PathType Leaf) { return [pscustomobject]@{ Path = $exe; Error = $null } }
    $csc = Get-DevkitCscPath
    if (-not $csc) {
        return [pscustomobject]@{ Path = $null; Error = "$Name.exe cannot be built: csc.exe of the .NET Framework 4 was not found (it is part of Windows; see doctor.ps1)" }
    }
    New-Item -ItemType Directory -Force -Path $DevkitBinDir | Out-Null
    $temp = Join-Path $DevkitBinDir ("$Name-build-" + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        $arguments = @('/nologo') + $Options + @('/optimize+', "/out:$temp", (Join-Path $DevkitLibDir "$Name.cs"))
        $result = Invoke-DevkitProcess -FilePath $csc -Arguments $arguments -TimeoutSeconds 120
        if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $temp)) {
            return [pscustomobject]@{ Path = $null; Error = "$Name.exe could not be built: " + ($result.StdOut + $result.StdErr).Trim() }
        }
        # Another process may have built it at the same time.
        if (-not (Test-Path -LiteralPath $exe)) {
            try { Move-Item -LiteralPath $temp -Destination $exe } catch { if (-not (Test-Path -LiteralPath $exe)) { throw } }
        }
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
    # An exe that is running cannot be removed; it stays until the next build.
    Get-ChildItem -LiteralPath $DevkitBinDir -Filter "$Name-*.exe" -File | Where-Object { $_.FullName -ne $exe } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Path = $exe; Error = $null }
}

# Returns the path that tamacs.exe (built from scripts/lib/tamacs.cs) has for the current source.
function Get-DevkitTamacsExpectedPath {
    return (Get-DevkitCsToolExpectedPath 'tamacs')
}

# Builds tamacs.exe from scripts/lib/tamacs.cs as a 32-bit console exe (yaya.dll and satori.dll are 32-bit).
function Get-DevkitTamacs {
    return (Get-DevkitCsTool 'tamacs' @('/target:exe', '/platform:x86'))
}

# Builds tamacsw.exe from scripts/lib/tamacsw.cs: the window that receives the log of the SHIORI running in SSP.
# It loads no dll, so it is built for any CPU.
function Get-DevkitTamacsw {
    return (Get-DevkitCsTool 'tamacsw' @('/target:winexe', '/platform:anycpu', '/reference:System.Windows.Forms.dll', '/reference:System.Drawing.dll'))
}

# --- local settings -----------------------------------------------------------------------

# Reads <home>/local.json (for example {"sspPath": "C:\\ssp\\ssp.exe"}); $null when there is none.
function Get-DevkitLocalConfig {
    $path = Join-Path $DevkitHome 'local.json'
    if (Test-Path -LiteralPath $path) {
        return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    return $null
}

# Reads "key,value" from descript.txt / install.txt style files (UTF-8).
function Get-DevkitDescriptValue([string]$Path, [string]$Key) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    foreach ($line in [IO.File]::ReadAllLines($Path, $DevkitUtf8)) {
        $idx = $line.IndexOf(',')
        if ($idx -gt 0 -and $line.Substring(0, $idx).Trim() -eq $Key) {
            return $line.Substring($idx + 1).Trim()
        }
    }
    return $null
}

function Get-SspPathFromNarAssociation {
    try {
        $progId = $null
        foreach ($key in @('HKCU:\Software\Classes\.nar', 'Registry::HKEY_CLASSES_ROOT\.nar')) {
            if (Test-Path -LiteralPath $key) {
                $progId = (Get-ItemProperty -LiteralPath $key).'(default)'
                if ($progId) { break }
            }
        }
        if (-not $progId) { return $null }
        $commandKey = "Registry::HKEY_CLASSES_ROOT\$progId\shell\open\command"
        if (-not (Test-Path -LiteralPath $commandKey)) { return $null }
        $command = (Get-ItemProperty -LiteralPath $commandKey).'(default)'
        if ($command -match '^\s*"([^"]+)"') { return $matches[1] }
        if ($command -match '^\s*(\S+)') { return $matches[1] }
    } catch { }
    return $null
}

# Finds ssp.exe. Order: explicit argument, SSP_PATH, <home>/local.json, the local.json of an old development kit
# (tools/local.json in the ghost root), the SSP that this ghost is installed in (<ssp>/ghost/<name>/), then the .nar
# file association.
function Resolve-SspPath([string]$Explicit) {
    $candidates = New-Object System.Collections.Generic.List[object]
    if ($Explicit) { $candidates.Add(@('-SspPath argument', $Explicit, $true)) }
    if ($env:SSP_PATH) { $candidates.Add(@('SSP_PATH environment variable', $env:SSP_PATH, $true)) }
    $local = Get-DevkitLocalConfig
    if ($local -and ($local.PSObject.Properties.Name -contains 'sspPath') -and $local.sspPath) {
        $candidates.Add(@('local.json in the ukagaka-developer home folder', [string]$local.sspPath, $true))
    }
    if ($DevkitRoot) {
        $legacy = Join-Path $DevkitRoot 'tools/local.json'
        if (Test-Path -LiteralPath $legacy -PathType Leaf) {
            try {
                $old = [IO.File]::ReadAllText($legacy, $DevkitUtf8) | ConvertFrom-Json
                if ($old.sspPath) { $candidates.Add(@('tools/local.json of the old development kit', [string]$old.sspPath, $false)) }
            } catch { }
        }
        $ghostsDir = Split-Path $DevkitRoot -Parent
        if ($ghostsDir -and (Split-Path $ghostsDir -Leaf) -eq 'ghost') {
            $candidates.Add(@('installed ghost folder', (Join-Path (Split-Path $ghostsDir -Parent) 'ssp.exe'), $false))
        }
    }
    $associated = Get-SspPathFromNarAssociation
    if ($associated) { $candidates.Add(@('.nar file association', $associated, $false)) }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate[1] -PathType Leaf) {
            return [pscustomobject]@{ Path = (Resolve-Path -LiteralPath $candidate[1]).Path; Source = $candidate[0] }
        }
        if ($candidate[2]) { Write-Warning "ssp.exe from $($candidate[0]) does not exist: $($candidate[1])" }
    }
    return $null
}

# Returns the version of ssp.exe as major.minor.build (for example 2.9.5), or $null when it cannot be read.
function Get-DevkitSspVersion([string]$Path) {
    try {
        $info = (Get-Item -LiteralPath $Path).VersionInfo
        if ($info.FileMajorPart -gt 0) { return (New-Object System.Version($info.FileMajorPart, $info.FileMinorPart, $info.FileBuildPart)) }
    } catch { }
    return $null
}

# Formats an SSP version the way SSP names its releases, with a two-digit build number (2.9.1 -> "2.9.01").
function Format-DevkitSspVersion([System.Version]$Version) {
    return ('{0}.{1}.{2:D2}' -f $Version.Major, $Version.Minor, $Version.Build)
}

# SHA256 of a file with CRLF normalized to LF, so that a checkout with other line endings still matches.
# Files that contain a NUL byte are hashed as they are.
function Get-DevkitFileHash([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ([Array]::IndexOf($bytes, [byte]0) -lt 0 -and [Array]::IndexOf($bytes, [byte]13) -ge 0) {
        $stream = New-Object System.IO.MemoryStream($bytes.Length)
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            if ($bytes[$i] -eq 13 -and $i + 1 -lt $bytes.Length -and $bytes[$i + 1] -eq 10) { continue }
            $stream.WriteByte($bytes[$i])
        }
        $bytes = $stream.ToArray()
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

# --- processes and text -------------------------------------------------------------------

# Quotes arguments for ProcessStartInfo.Arguments (MSVCRT rules).
function ConvertTo-DevkitArgumentString([string[]]$Arguments) {
    $parts = foreach ($arg in $Arguments) {
        if ($null -eq $arg) { continue }
        if ($arg -eq '' -or $arg -match '[\s"]') {
            $escaped = [regex]::Replace($arg, '(\\*)"', { param($m) ($m.Groups[1].Value * 2) + '\"' })
            $escaped = [regex]::Replace($escaped, '(\\+)$', { param($m) $m.Groups[1].Value * 2 })
            '"' + $escaped + '"'
        } else {
            $arg
        }
    }
    return ($parts -join ' ')
}

# Runs a program and captures stdout/stderr as UTF-8 text.
function Invoke-DevkitProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 120,
        # Text for the standard input, written as UTF-8 without BOM; the input is closed afterwards.
        [string]$InputText,
        # Environment variables that the program does not inherit.
        [string[]]$UnsetEnvironment = @()
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ConvertTo-DevkitArgumentString $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $PSBoundParameters.ContainsKey('InputText')
    $psi.StandardOutputEncoding = $DevkitUtf8
    $psi.StandardErrorEncoding = $DevkitUtf8
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    foreach ($name in $UnsetEnvironment) {
        if ($psi.EnvironmentVariables.ContainsKey($name)) { $psi.EnvironmentVariables.Remove($name) }
    }

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if ($psi.RedirectStandardInput) {
        # Write the bytes to the base stream: the StreamWriter of .NET Framework may add a BOM when it is closed.
        $bytes = $DevkitUtf8.GetBytes([string]$InputText)
        $stdin = $process.StandardInput.BaseStream
        try {
            $stdin.Write($bytes, 0, $bytes.Length)
            $stdin.Flush()
        } catch {
            # The program exited without reading the input; its output tells why.
        } finally {
            try { $stdin.Close() } catch { }
        }
    }
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill() } catch { }
        $process.WaitForExit()
    }
    $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
    return [pscustomobject]@{
        ExitCode = $exitCode
        StdOut   = $stdoutTask.Result
        StdErr   = $stderrTask.Result
        TimedOut = $timedOut
    }
}

# Rewrites absolute paths under $Base into root-relative paths with forward slashes.
# SSP adds places such as "shell\master\surfaces.txt:Line=12" to SERIKO messages (absolute with
# --offline-dump, relative to the ghost folder otherwise); their backslashes are turned into slashes as well.
function ConvertTo-DevkitRelativeText([string]$Text, [string]$Base = $DevkitRoot) {
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $pattern = '(?i)' + [regex]::Escape($Base.TrimEnd('\', '/')) + '[\\/]([^\s(),"]*)'
    $Text = [regex]::Replace($Text, $pattern, { param($m) $m.Groups[1].Value.Replace('\', '/') })
    return [regex]::Replace($Text, '[^\s(),"]+(?=:Line=\d)', { param($m) $m.Value.Replace('\', '/') })
}
