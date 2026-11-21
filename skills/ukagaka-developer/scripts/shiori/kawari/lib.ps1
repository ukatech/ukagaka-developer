# Helpers for KAWARI (shiori.dll of KAWARI Phase 9): version, mode, kosui.exe (kosui --check), a temporary copy of
# ghost/master to run shiori.dll in, the diagnostics of KAWARI, the dictionary files, and the doctor and setup steps.
# Dot-source after common.ps1:   . (Join-Path $PSScriptRoot 'lib.ps1')
# Keep every .ps1 file ASCII-only and compatible with Windows PowerShell 5.1.
#
# Two engines are used:
# - kosui.exe --check (KAWARI Phase 9.2.0 or later, downloaded by setup.ps1 into the home folder) loads the
#   dictionaries in its safe mode: no file is written, no SAORI is loaded, nothing is sent to SSP. check-dic.ps1 and
#   lint.ps1 use it. It is the latest KAWARI, not the shiori.dll of the ghost.
# - tamacs.exe --no-loghandler runs the shiori.dll of the ghost (shiori.ps1). shiori.dll has no Set_loghandler, so the
#   temporary copy of ghost/master gets a few lines at the start and the end of kawarirc.kis that write the
#   diagnostics of KAWARI to log files (logfile, loglevel), which are read afterwards. KAWARI writes save files and
#   whatever the dictionaries write into the ghost folder, so shiori.dll never runs in the real ghost/master.
#
# Two modes: a ghost of Phase 8 and later has kawarirc.kis ('kawari9'). A ghost of Phase 7 has kawari.ini and no
# kawarirc.kis ('kawari7'): shiori.dll of Phase 9.3.0 or later runs it as it is (the 7 compatible mode), and so does
# kosui.exe when it is given kawari.ini. A ghost of the second kind gets two dictionaries of its own in the temporary
# copy (dict lines at the start and the end of kawari.ini) instead of the zones in kawarirc.kis.

# The Phase that the scripts support. Phase 8 ghosts can use shiori.dll of Phase 9 as it is (update-shiori.ps1).
$DevkitKawariMinimumVersion = New-Object System.Version(9, 0, 0)
# The first version that the scripts use for a Phase 7 ghost (kawari.ini without kawarirc.kis), which shiori.dll and
# kosui.exe run as it is in their 7 compatible mode. 9.3.0 introduced it but answered SHIORI/2.x only, which tamacs.exe
# does not send; 9.3.1 added SHIORI/3.0. 9.3.3 is the one to recommend: it passes the Reference to the resources.
$DevkitKawari7MinimumVersion = New-Object System.Version(9, 3, 1)
# Name of the tool in scripts/tools.json.
$DevkitKosuiToolName = 'kosui'
# Names of the files that the temporary copy writes its logs to (relative to ghost/master).
$DevkitKawariLoadLog = 'devkit-kawari-load.log'
$DevkitKawariRunLog = 'devkit-kawari-run.log'
# Names of the dictionaries that the temporary copy of a Phase 7 ghost gets (dict lines in kawari.ini).
$DevkitKawariHeadDict = 'devkit-kawari-head.txt'
$DevkitKawariTailDict = 'devkit-kawari-tail.txt'
# Request ID that the -Eval hook of the temporary copy answers. A Phase 7 ghost sends an ID with a capital letter to
# event.<ID> and an ID in small letters to resource.<ID>, so its ID has one.
$DevkitKawariEvalId = 'devkit.eval'
$DevkitKawari7EvalId = 'devkit.Eval'

# --- mode -------------------------------------------------------------------------------------------------------------

# 'kawari7' for a ghost of Phase 7 (kawari.ini and no kawarirc.kis), otherwise 'kawari9'.
function Get-DevkitKawariMode([string]$GhostDir) {
    if (Test-Path -LiteralPath (Join-Path $GhostDir 'kawarirc.kis') -PathType Leaf) { return 'kawari9' }
    if (Test-Path -LiteralPath (Join-Path $GhostDir 'kawari.ini') -PathType Leaf) { return 'kawari7' }
    return 'kawari9'
}

# The file that KAWARI reads first: kawarirc.kis, or kawari.ini for a ghost of Phase 7.
function Get-DevkitKawariRcName([string]$GhostDir) {
    if ((Get-DevkitKawariMode $GhostDir) -eq 'kawari7') { return 'kawari.ini' }
    return 'kawarirc.kis'
}

# The request ID of the -Eval hook.
function Get-DevkitKawariEvalId([string]$GhostDir) {
    if ((Get-DevkitKawariMode $GhostDir) -eq 'kawari7') { return $DevkitKawari7EvalId }
    return $DevkitKawariEvalId
}

# --- version ----------------------------------------------------------------------------------------------------------

# Reads the version of a shiori.dll / kosui.exe of KAWARI. Returns $null when the file does not exist.
# Phase 9 has a version resource (9.2.0.0); older ones have none (and are often packed with UPX), so the
# "KAWARI.kdt/8.2.8" string inside the file is tried, which only an unpacked file has.
# Number: a [version] (major, minor, build) or $null; Phase9: whether it is Phase 9 or later; Compat7: whether it is 9.3.1
# or later, which the scripts use for a ghost of Phase 7.
function Get-DevkitKawariVersion([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $number = $null
    $fileVersion = Get-DevkitFileVersion $Path
    if ($fileVersion -and $fileVersion.Major -ge 8) {
        $number = New-Object System.Version($fileVersion.Major, $fileVersion.Minor, $fileVersion.Build)
    } else {
        $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($Path))
        if ($text -match 'KAWARI\.(?:kdt|kpcg)/(\d+)\.(\d+)\.(\d+)') {
            $number = New-Object System.Version([int]$matches[1], [int]$matches[2], [int]$matches[3])
        }
    }
    $phase9 = [bool]$number -and $number -ge $DevkitKawariMinimumVersion
    $compat7 = [bool]$number -and $number -ge $DevkitKawari7MinimumVersion
    $label = if ($number) { "Phase $number" } else { 'older than Phase 9 (no version resource)' }
    return [pscustomobject]@{ Path = $Path; Number = $number; Phase9 = $phase9; Compat7 = $compat7; Text = $label }
}

# --- kosui.exe ----------------------------------------------------------------------------------------------------------

# Returns Path (kosui.exe, or $null) and Error (why it is not available). kosui.exe is not downloaded here: that is
# done by setup.ps1, after the user agrees.
function Get-DevkitKosui {
    $path = Get-DevkitToolPath $DevkitKosuiToolName
    $current = Test-DevkitToolCurrent $DevkitKosuiToolName
    if ($null -eq $current) {
        return [pscustomobject]@{ Path = $null; Error = "kosui.exe (KAWARI) is not installed: run scripts/setup.ps1 (it downloads the latest release of ukatech/kawari into $DevkitBinDir)" }
    }
    if (-not $current) {
        $minimum = (Get-DevkitToolManifest).$DevkitKosuiToolName.minimumVersion
        return [pscustomobject]@{ Path = $null; Error = "kosui.exe in $DevkitBinDir is older than $minimum and has no --check: run scripts/setup.ps1 -Tool kosui -Force" }
    }
    return [pscustomobject]@{ Path = $path; Error = $null }
}

# Runs "kosui --check --format json" in $GhostDir on kawarirc.kis (kawari.ini of a Phase 7 ghost, which needs kosui.exe
# 9.3.1 or later: an older one reads it as a dictionary and finds nothing) and returns ExitCode (0 = nothing, 1 = warnings
# only, 2 = errors, 3 = could not run), TimedOut, Diagnostics (see ConvertFrom-DevkitKawariJson) and Raw (the output).
# The safe mode of kosui writes no file, so it runs in the real folder. =kis is really run, so an endless loop in the
# dictionaries makes it time out. Arguments go to kosui after --check (for example --no-lint, --decl).
function Invoke-DevkitKosuiCheck {
    param([string]$GhostDir, [string[]]$Arguments = @(), [int]$TimeoutSeconds = 120)
    $kosui = Get-DevkitKosui
    if (-not $kosui.Path) { throw $kosui.Error }
    if ((Get-DevkitKawariMode $GhostDir) -eq 'kawari7') {
        $kosuiVersion = Get-DevkitKawariVersion $kosui.Path
        if (-not ($kosuiVersion -and $kosuiVersion.Compat7)) {
            throw "kosui.exe $($kosuiVersion.Text) does not read kawari.ini (a Phase 7 ghost needs 9.3.1 or later): run scripts/setup.ps1 -Tool kosui -Force"
        }
    }
    $all = @('--check', '--format', 'json') + @($Arguments) + @(Get-DevkitKawariRcName $GhostDir)
    $result = Invoke-DevkitProcess -FilePath $kosui.Path -Arguments $all -WorkingDirectory $GhostDir -TimeoutSeconds $TimeoutSeconds
    $diagnostics = @()
    $parsed = $false
    if (-not $result.TimedOut) {
        try {
            $diagnostics = @(ConvertFrom-DevkitKawariJson $result.StdOut $GhostDir)
            $parsed = $true
        } catch { }
    }
    return [pscustomobject]@{
        ExitCode    = $result.ExitCode
        TimedOut    = $result.TimedOut
        Parsed      = $parsed
        Diagnostics = $diagnostics
        Raw         = ($result.StdOut + $result.StdErr)
    }
}

# --- diagnostics ----------------------------------------------------------------------------------------------------------

# Turns the path of a diagnostic into one relative to the ghost root with forward slashes: kosui gives the files that
# kawarirc.kis loads as absolute paths and kawarirc.kis itself as a relative one; the temporary copy is mapped back to
# the real ghost/master ($Sandbox).
function ConvertTo-DevkitKawariPath([string]$File, [string]$GhostDir, [string]$Sandbox) {
    if (-not $File -or $File -eq '-') { return '' }
    $full = $File
    if (-not [IO.Path]::IsPathRooted($full)) { $full = Join-Path $(if ($Sandbox) { $Sandbox } else { $GhostDir }) $full }
    if ($Sandbox) {
        $prefix = $Sandbox.TrimEnd('\', '/') + '\'
        if ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $full = Join-Path $GhostDir $full.Substring($prefix.Length) }
    }
    $base = (Split-Path (Split-Path $GhostDir -Parent) -Parent).TrimEnd('\', '/') + '\'
    $full = [IO.Path]::GetFullPath($full)
    if ($full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { return $full.Substring($base.Length).Replace('\', '/') }
    return $full.Replace('\', '/')
}

# Makes a diagnostic object: Level (error / warning), Code (K-E0028), File (relative to the ghost root, or ''),
# Line (0 when unknown), Message, Chain (the "in ${entry} at file(line)" lines, paths made relative).
function New-DevkitKawariDiagnostic([string]$Level, [string]$Code, [string]$File, $Line, [string]$Message, [string[]]$Chain) {
    $lineNumber = 0
    [void][int]::TryParse([string]$Line, [ref]$lineNumber)
    return [pscustomobject]@{ Level = $Level; Code = $Code; File = $File; Line = $lineNumber; Message = $Message; Chain = @($Chain) }
}

# Reads the JSON of "kosui --check --format json": {"diagnostics":[{"severity","code","file","line","message","chain"}],...}
function ConvertFrom-DevkitKawariJson([string]$Json, [string]$GhostDir) {
    $data = $Json | ConvertFrom-Json
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($d in @($data.diagnostics)) {
        if ($null -eq $d) { continue }
        $chain = @(@($d.chain) | Where-Object { $_ } | ForEach-Object { ConvertTo-DevkitKawariChain ([string]$_) $GhostDir '' })
        $level = if ([string]$d.severity -eq 'warning') { 'warning' } else { 'error' }
        $list.Add((New-DevkitKawariDiagnostic $level ([string]$d.code) (ConvertTo-DevkitKawariPath ([string]$d.file) $GhostDir '') $d.line ([string]$d.message) $chain))
    }
    return $list.ToArray()
}

# Makes the paths in a chain line ("in ${entry} at C:\...\dic.kis(12)") relative.
function ConvertTo-DevkitKawariChain([string]$Text, [string]$GhostDir, [string]$Sandbox) {
    $Text = $Text.Trim()
    $m = [regex]::Match($Text, '^(.* at )(.+)\(([0-9]+|-)\)$')
    if (-not $m.Success) { return $Text }
    return $m.Groups[1].Value + (ConvertTo-DevkitKawariPath $m.Groups[2].Value $GhostDir $Sandbox) + '(' + $m.Groups[3].Value + ')'
}

# Reads a log file that KAWARI wrote with logfile (UTF-8): "file(line): error K-E0028: message", or without the
# place, followed by indented "in ..." lines. Other lines (info) are left out.
function ConvertFrom-DevkitKawariLog([string]$Text, [string]$GhostDir, [string]$Sandbox) {
    $list = New-Object System.Collections.Generic.List[object]
    $current = $null
    $chain = $null
    foreach ($line in @($Text -split "\r?\n")) {
        $m = [regex]::Match($line, '^(?:(?<file>.+?)\((?<line>[0-9]+|-)\): )?(?<level>error|warning) (?<code>K-[EW][0-9]+): (?<message>.*)$')
        if ($m.Success) {
            if ($current) { $list.Add((New-DevkitKawariDiagnostic $current.Level $current.Code $current.File $current.Line $current.Message $chain.ToArray())) }
            $current = [pscustomobject]@{
                Level   = $m.Groups['level'].Value
                Code    = $m.Groups['code'].Value
                File    = (ConvertTo-DevkitKawariPath $m.Groups['file'].Value $GhostDir $Sandbox)
                Line    = $m.Groups['line'].Value
                Message = $m.Groups['message'].Value
            }
            $chain = New-Object System.Collections.Generic.List[string]
            continue
        }
        if ($current -and $line -match '^\s+(in |\.\.\. )') { $chain.Add((ConvertTo-DevkitKawariChain $line $GhostDir $Sandbox)); continue }
    }
    if ($current) { $list.Add((New-DevkitKawariDiagnostic $current.Level $current.Code $current.File $current.Line $current.Message $chain.ToArray())) }
    return $list.ToArray()
}

# Prints diagnostics as "ghost/master/dic.kis(12): error K-E0028: message" followed by up to $ChainLines lines of
# the call chain (and GitHub Actions annotations with -Ci). Returns the error count.
function Write-DevkitKawariDiagnostics {
    param([object[]]$Diagnostics, [string]$Title, [switch]$Ci, [int]$ChainLines = 3)
    $errors = 0
    foreach ($d in $Diagnostics) {
        if ($d.Level -eq 'error') { $errors++ }
        $place = if ($d.File) { "$($d.File)($(if ($d.Line) { $d.Line } else { '-' })): " } else { '' }
        Write-Host "$place$($d.Level) $($d.Code): $($d.Message)"
        $shown = 0
        foreach ($c in @($d.Chain)) {
            if ($shown -ge $ChainLines) { Write-Host "    ... $(@($d.Chain).Count - $shown) more"; break }
            Write-Host "    $c"
            $shown++
        }
        if ($Ci) {
            $location = ''
            if ($d.File) { $location = "file=$($d.File)," + $(if ($d.Line) { "line=$($d.Line)," } else { '' }) }
            $annotation = ("$($d.Code): $($d.Message)" -replace '[\r\n%]+', ' ')
            Write-Host "::$($d.Level) ${location}title=$Title::$annotation"
        }
    }
    return $errors
}

# Codes of the static check (lint) of kosui --check: K-W2001 and up.
function Test-DevkitKawariLintCode([string]$Code) {
    return ($Code -match '^K-W2[0-9]{3}$')
}

# --- text files whose encoding is UTF-8 or Shift_JIS ---------------------------------------------------------------

# Reads a text file the way KAWARI reads a dictionary: UTF-8 when it has a BOM or is valid UTF-8 as a whole,
# otherwise Shift_JIS (CP932). Returns Text, Encoding ('UTF-8', 'UTF-8 BOM', 'Shift_JIS' or 'ASCII') and Bytes.
function Read-DevkitKawariText([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($bom) {
        return [pscustomobject]@{ Text = $DevkitUtf8.GetString($bytes, 3, $bytes.Length - 3); Encoding = 'UTF-8 BOM'; Bytes = $bytes }
    }
    $ascii = $true
    foreach ($b in $bytes) { if ($b -ge 0x80) { $ascii = $false; break } }
    if ($ascii) { return [pscustomobject]@{ Text = [Text.Encoding]::ASCII.GetString($bytes); Encoding = 'ASCII'; Bytes = $bytes } }
    try {
        $strict = New-Object System.Text.UTF8Encoding($false, $true)
        return [pscustomobject]@{ Text = $strict.GetString($bytes); Encoding = 'UTF-8'; Bytes = $bytes }
    } catch {
        return [pscustomobject]@{ Text = [Text.Encoding]::GetEncoding(932).GetString($bytes); Encoding = 'Shift_JIS'; Bytes = $bytes }
    }
}

# Returns the dictionary files of the ghost (full paths): kawarirc.kis, the other *.kis files in ghost/master, and
# the files that they load with a literal name ("load name" in a =kis zone or $(load name)), followed recursively.
# Names that are built at run time (${...}) cannot be followed. Files that do not exist (save files written at run
# time, for example) are left out. Wrap the call in @().
function Get-DevkitKawariDictionaryFiles([string]$GhostDir) {
    $found = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $queue = New-Object System.Collections.Generic.Queue[string]
    $queue.Enqueue((Join-Path $GhostDir 'kawarirc.kis'))
    foreach ($kis in @(Get-ChildItem -LiteralPath $GhostDir -File -Filter '*.kis' -ErrorAction SilentlyContinue | Sort-Object Name)) { $queue.Enqueue($kis.FullName) }
    while ($queue.Count -gt 0) {
        $path = [IO.Path]::GetFullPath($queue.Dequeue())
        if ($seen.ContainsKey($path.ToLowerInvariant())) { continue }
        $seen[$path.ToLowerInvariant()] = $true
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $found.Add($path)
        # Comment lines (the first character that is not a space is #) are left out.
        $text = ((Read-DevkitKawariText $path).Text -split "\r?\n" | Where-Object { -not $_.TrimStart().StartsWith('#') }) -join "`n"
        foreach ($m in [regex]::Matches($text, '(?m)(?:^|[\s;(])load\s+"?([^\s;"$(){}]+)"?')) {
            $name = $m.Groups[1].Value
            if ($name -match '[\\/]\.\.[\\/]' -or $name.StartsWith('..')) { continue }
            $queue.Enqueue((Join-Path $GhostDir $name.Replace('/', '\')))
        }
    }
    return $found.ToArray()
}

# --- temporary copy of ghost/master ---------------------------------------------------------------------------------

# Copies ghost/master to a temporary folder and returns Root (delete this) and Dir (the copy). kawarirc.kis of the
# copy gets a =kis zone at the start that writes the log of loading to $DevkitKawariLoadLog, and one at the end that
# writes the log of the request to $DevkitKawariRunLog (the end wins over the logfile / loglevel of the ghost).
# -EvalHook also wraps System.Callback.OnGET so that a request with the ID $DevkitKawariEvalId returns
# $(eval ${System.Request.Reference0}); other requests get $(get devkit.OnGET), which evaluates every word of the
# original entry in order and joins them, as KAWARI does with a callback entry. The lines are ASCII, so the encoding of kawarirc.kis does not change
# (they are put after a BOM).
# A ghost of Phase 7 (kawari.ini) gets the same zones in two dictionaries of their own, read first and last through dict
# lines that are added to kawari.ini; -EvalHook adds event.devkit.Eval (the ID $DevkitKawari7EvalId) to the last one.
function New-DevkitKawariSandbox {
    param([string]$GhostDir, [string[]]$LogLevel = @('error', 'warning'), [switch]$EvalHook)
    $root = Join-Path ([IO.Path]::GetTempPath()) ('devkit-kawari-' + [guid]::NewGuid().ToString('N'))
    $dir = Join-Path $root (Split-Path $GhostDir -Leaf)
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    try {
        foreach ($item in @(Get-ChildItem -LiteralPath $GhostDir -Force)) {
            if ($item.Name -eq '.git' -or ($item.PSIsContainer -and $item.Name -eq 'profile')) { continue }
            Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $dir $item.Name) -Recurse -Force
        }
        $mode = Get-DevkitKawariMode $GhostDir
        $rc = Join-Path $dir $(if ($mode -eq 'kawari7') { 'kawari.ini' } else { 'kawarirc.kis' })
        $bytes = [IO.File]::ReadAllBytes($rc)
        $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $start = if ($bom) { 3 } else { 0 }
        $crlf = ([Text.Encoding]::GetEncoding(28591).GetString($bytes)).Contains("`r`n")
        $nl = if ($crlf) { "`r`n" } else { "`n" }
        $level = $LogLevel -join ' '
        $head = @('=kis', "logfile $DevkitKawariLoadLog;", "loglevel $level;", '=end', '') -join $nl
        $tail = @('', '=kis', "logfile $DevkitKawariRunLog;", "loglevel $level;")
        if ($mode -eq 'kawari7') {
            # Not a hook on System.Callback.OnGET (a Phase 7 ghost has none): an event entry of its own.
            if ($EvalHook) { $tail += @('=end', ('event.' + $DevkitKawari7EvalId + ' : $(eval ${system.Reference0})')) } else { $tail += @('=end') }
        } elseif ($EvalHook) {
            $tail += @('copy System.Callback.OnGET devkit.OnGET;', 'clear System.Callback.OnGET;', '=end',
                ('System.Callback.OnGET : $(if $[ ${System.Request.ID} == "' + $DevkitKawariEvalId + '" ] $(eval ${System.Request.Reference0}) else $(get devkit.OnGET))'))
        } else {
            $tail += @('=end')
        }
        $tailText = ($tail -join $nl) + $nl
        $headBytes = [Text.Encoding]::ASCII.GetBytes($head)
        $tailBytes = [Text.Encoding]::ASCII.GetBytes($tailText)
        if ($mode -eq 'kawari7') {
            # The dictionaries are ASCII files of their own; kawari.ini gets a dict line first and last (it reads the dict
            # lines after the whole file, in the order they are written).
            [IO.File]::WriteAllBytes((Join-Path $dir $DevkitKawariHeadDict), $headBytes)
            [IO.File]::WriteAllBytes((Join-Path $dir $DevkitKawariTailDict), $tailBytes)
            $headBytes = [Text.Encoding]::ASCII.GetBytes("dict : $DevkitKawariHeadDict$nl")
            $tailBytes = [Text.Encoding]::ASCII.GetBytes("dict : $DevkitKawariTailDict$nl")
        }
        $out = New-Object System.IO.MemoryStream
        $out.Write($bytes, 0, $start)
        $out.Write($headBytes, 0, $headBytes.Length)
        $out.Write($bytes, $start, $bytes.Length - $start)
        $lastIsNewline = $bytes.Length -gt $start -and ($bytes[$bytes.Length - 1] -eq 10)
        if (-not $lastIsNewline) { $nlBytes = [Text.Encoding]::ASCII.GetBytes($nl); $out.Write($nlBytes, 0, $nlBytes.Length) }
        $out.Write($tailBytes, 0, $tailBytes.Length)
        [IO.File]::WriteAllBytes($rc, $out.ToArray())
    } catch {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
    # The head adds lines before the first line of kawarirc.kis: diagnostics in it are moved back by this many lines.
    # Lines after HeadLines + RcLines are those of the tail zone (the -Eval hook).
    # A Phase 7 ghost has no line to move: the zones are in files of their own.
    $rcLines = 1
    for ($i = $start; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -eq 10) { $rcLines++ } }
    $headLines = if ($mode -eq 'kawari7') { 0 } else { ([regex]::Matches($head, "`n")).Count }
    return [pscustomobject]@{ Root = $root; Dir = $dir; Mode = $mode; HeadLines = $headLines; RcLines = $rcLines }
}

# Sends one SHIORI request to the shiori.dll of a temporary copy of $GhostDir with tamacs.exe --no-loghandler, and
# deletes the copy. Returns ExitCode, TimedOut, Response, Error (what tamacs.exe printed on stderr),
# LoadDiagnostics and RunDiagnostics (read from the log files of the copy).
function Invoke-DevkitTamacs {
    param([string]$GhostDir, [string]$InputText, [string[]]$LogLevel = @('error', 'warning'), [switch]$EvalHook, [int]$TimeoutSeconds = 60)
    $tamacs = Get-DevkitTamacs
    if (-not $tamacs.Path) { throw $tamacs.Error }
    $sandbox = New-DevkitKawariSandbox -GhostDir $GhostDir -LogLevel $LogLevel -EvalHook:$EvalHook
    try {
        $result = Invoke-DevkitProcess -FilePath $tamacs.Path -Arguments @((Join-Path $sandbox.Dir 'shiori.dll'), '-r', '--no-loghandler') `
            -WorkingDirectory $sandbox.Dir -InputText $InputText -UnsetEnvironment @('GITHUB_ACTIONS') -TimeoutSeconds $TimeoutSeconds
        $logs = @{}
        foreach ($name in @($DevkitKawariLoadLog, $DevkitKawariRunLog)) {
            $path = Join-Path $sandbox.Dir $name
            $logs[$name] = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path, $DevkitUtf8) } else { '' }
        }
        $load = @(ConvertFrom-DevkitKawariLog $logs[$DevkitKawariLoadLog] $GhostDir $sandbox.Dir)
        $run = @(ConvertFrom-DevkitKawariLog $logs[$DevkitKawariRunLog] $GhostDir $sandbox.Dir)
        # Line numbers of kawarirc.kis are those of the copy, which has the head zone in front.
        $rcFile = ConvertTo-DevkitKawariPath (Join-Path $GhostDir 'kawarirc.kis') $GhostDir ''
        $shift = $sandbox.HeadLines
        foreach ($d in $(if ($shift -gt 0) { @($load) + @($run) } else { @() })) {
            if ($d.File -eq $rcFile -and $d.Line -gt $shift + $sandbox.RcLines) { $d.File = ''; $d.Line = 0 }
            elseif ($d.File -eq $rcFile -and $d.Line -gt $shift) { $d.Line -= $shift }
            $chain = New-Object System.Collections.Generic.List[string]
            foreach ($c in @($d.Chain)) {
                $m = [regex]::Match($c, '^(.* at )(.+)\(([0-9]+)\)$')
                if ($m.Success -and $m.Groups[2].Value -eq $rcFile -and [int]$m.Groups[3].Value -gt $shift + $sandbox.RcLines) {
                    $c = 'in <-Eval of scripts/shiori.ps1>'
                } elseif ($m.Success -and $m.Groups[2].Value -eq $rcFile -and [int]$m.Groups[3].Value -gt $shift) {
                    $c = $m.Groups[1].Value + $rcFile + '(' + ([int]$m.Groups[3].Value - $shift) + ')'
                }
                $chain.Add($c)
            }
            $d.Chain = $chain.ToArray()
        }
    } finally {
        Remove-Item -LiteralPath $sandbox.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
    return [pscustomobject]@{
        ExitCode        = $result.ExitCode
        TimedOut        = $result.TimedOut
        Response        = ($result.StdOut -replace "\r\n", "`n")
        Error           = $result.StdErr.Trim()
        LoadDiagnostics = $load
        RunDiagnostics  = $run
    }
}

# --- build-nar and check ------------------------------------------------------------------

# Tells why the nar of this ghost would not load, from the list of the files it will hold (paths relative to the ghost
# root). Returns $null when it looks fine. Used by build-nar.ps1.
function Get-DevkitShioriNarProblem([string[]]$Included) {
    if ($Included -notcontains 'ghost/master/shiori.dll') { return 'ghost/master/shiori.dll is missing or excluded (KAWARI would not load in the nar)' }
    if (($Included -notcontains 'ghost/master/kawarirc.kis') -and ($Included -notcontains 'ghost/master/kawari.ini')) {
        return 'ghost/master/kawarirc.kis (or kawari.ini of a Phase 7 ghost) is missing or excluded (KAWARI would not load in the nar)'
    }
    return $null
}

# --- doctor and setup ---------------------------------------------------------------------

# What the doctor tells tamacs.exe is used for.
$DevkitTamacsPurpose = 'Loads the shiori.dll of KAWARI without SSP: shiori.ps1 (the dictionary check uses kosui.exe)'

# Adds the KAWARI items to the doctor (Add-DoctorItem is defined by doctor.ps1).
function Add-DevkitShioriDoctorItems([string]$Ps, [bool]$IsGitWorkingCopy) {
    $ghostMaster = Join-Path $DevkitRoot 'ghost/master'
    $dll = Join-Path $ghostMaster 'shiori.dll'
    $mode = Get-DevkitKawariMode $ghostMaster
    $seven = ($mode -eq 'kawari7')
    $rcName = Get-DevkitKawariRcName $ghostMaster
    $rc = Join-Path $ghostMaster $rcName
    $ghostOk = (Test-Path -LiteralPath $dll) -and (Test-Path -LiteralPath $rc)
    $version = Get-DevkitKawariVersion $dll
    Add-DoctorItem -Id 'ghost' -Name 'ghost files (KAWARI)' -Level 'required' -Ok $ghostOk `
        -Purpose 'The ghost itself' `
        -Detail $(if ($ghostOk) { "shiori.dll $($version.Text), $rcName$(if ($seven) { ' (a Phase 7 ghost: shiori.dll of Phase 9.3.1 or later runs it in the 7 compatible mode)' })" } elseif (-not (Test-Path -LiteralPath $dll)) { 'ghost/master/shiori.dll is missing' } else { "ghost/master/$rcName is missing" }) `
        -Fix 'Work in the ghost root folder (the one that contains ghost/ and shell/).'

    # A Phase 7 ghost needs 9.3.1 or later; one of Phase 8 and later needs 9.0.0 or later.
    $phaseOk = [bool]$version -and $(if ($seven) { $version.Compat7 } else { $version.Phase9 })
    Add-DoctorItem -Id 'kawari-phase9' -Name 'KAWARI Phase 9' -Level 'required' -Ok $phaseOk `
        -Purpose $(if ($seven) { 'A Phase 7 ghost (kawari.ini, no kawarirc.kis) runs on shiori.dll of KAWARI Phase 9.3.1 or later, in its 7 compatible mode' } else { 'The scripts of the skill support shiori.dll of KAWARI Phase 9 (Phase 8 dictionaries run on it unchanged)' }) `
        -Detail $(if (-not $version) { 'shiori.dll not found (see ghost files)' } else { "shiori.dll $($version.Text)" }) `
        -Fix "After the user agrees, run: $Ps scripts/update-shiori.ps1 (see references/kawari/update.md)"

    $kosui = Get-DevkitKosui
    $kosuiVersion = if ($kosui.Path) { Get-DevkitKawariVersion $kosui.Path } else { $null }
    $kosuiOk = [bool]$kosui.Path -and (-not $seven -or $kosuiVersion.Compat7)
    Add-DoctorItem -Id 'kosui' -Name $(if ($seven) { 'kosui.exe (KAWARI 9.3.1+)' } else { 'kosui.exe (KAWARI 9.2+)' }) -Level 'required' -Ok $kosuiOk `
        -Purpose 'kosui --check loads the dictionaries in its safe mode: dictionary check (check-dic.ps1 and the check after each edit), lint.ps1' `
        -Detail $(if (-not $kosui.Path) { $kosui.Error } elseif ($kosuiOk) { "$($kosuiVersion.Text) in $(Split-Path $kosui.Path -Parent)" } else { "$($kosuiVersion.Text) does not read kawari.ini (the 7 compatible mode needs 9.3.1 or later)" }) `
        -Fix "After the user agrees, run: $Ps scripts/setup.ps1$(if ($seven -and $kosui.Path) { ' -Tool kosui -Force' }) (it downloads the latest release of https://github.com/ukatech/kawari into the home folder)"

    # The check runs on kosui, which is the latest KAWARI: a command that is newer than the shiori.dll of the ghost
    # passes the check and fails in SSP.
    $sameOk = -not ($phaseOk -and $kosuiVersion -and $kosuiVersion.Number -and $version.Number -lt $kosuiVersion.Number)
    Add-DoctorItem -Id 'kawari-current' -Name 'KAWARI up to date' -Level 'recommended' -Ok $sameOk `
        -Purpose 'The dictionary check runs on kosui.exe; a shiori.dll older than it may lack commands that the check accepts' `
        -Detail $(if ($version -and $kosuiVersion) { "shiori.dll $($version.Text), kosui.exe $($kosuiVersion.Text)" } else { 'not compared' }) `
        -Fix "After the user agrees, run: $Ps scripts/update-shiori.ps1 (see references/kawari/update.md)"

    # Shift_JIS dictionaries cannot be edited by tools that read and write UTF-8 without breaking them. A Phase 7 ghost
    # reads the encoding that locale of kawari.ini gives (a BOM wins), which this check does not follow.
    $sjis = @()
    if ((-not $seven) -and (Test-Path -LiteralPath $rc)) {
        $base = (Resolve-DevkitFullPath $DevkitRoot).TrimEnd('\', '/') + '\'
        foreach ($file in @(Get-DevkitKawariDictionaryFiles $ghostMaster)) {
            if ((Read-DevkitKawariText $file).Encoding -eq 'Shift_JIS') { $sjis += $file.Substring($base.Length).Replace('\', '/') }
        }
    }
    Add-DoctorItem -Id 'kawari-encoding' -Name 'UTF-8 dictionaries' -Level 'recommended' -Ok ($sjis.Count -eq 0) `
        -Purpose 'Dictionaries in UTF-8 can be read and edited by agents; Shift_JIS ones are broken by tools that write UTF-8' `
        -Detail $(if ($seven) { 'not checked: a Phase 7 ghost reads its dictionaries in the encoding of locale in kawari.ini (references/kawari/dictionary.md)' } elseif ($sjis.Count -eq 0) { 'no Shift_JIS dictionary' } else { "Shift_JIS: $($sjis -join ', ')" }) `
        -Fix "After the user agrees, run: $Ps scripts/shiori/kawari/convert-utf8.ps1 (a dry run; -Apply converts them to UTF-8 without BOM, see references/kawari/dictionary.md)"
}

# The setup step of KAWARI: nothing besides kosui.exe, which setup.ps1 downloads from scripts/tools.json.
# Returns the number of failed steps.
function Invoke-DevkitShioriSetup {
    return 0
}
