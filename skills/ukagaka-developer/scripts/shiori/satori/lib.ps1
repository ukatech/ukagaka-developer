# Helpers for SATORI (satori.dll): version, a temporary copy of ghost/master to run it in, tamacs.exe, log analysis,
# and the doctor and setup steps.
# Dot-source after common.ps1:   . (Join-Path $PSScriptRoot 'lib.ps1')
# Keep every .ps1 file ASCII-only and compatible with Windows PowerShell 5.1.
# Japanese text (log patterns, the lines that switch the debug mode on) is in satori.json next to this file.
#
# Why a temporary copy: SATORI writes satori_savedata.txt / satori_savebackup.txt into the ghost folder every time it
# is unloaded, and the debug ID ShioriEcho works only when the dictionaries set the debug mode on (in the initialization sentence of
# satori_conf.txt). So tamacs.exe never runs in the real ghost/master; it runs in a copy that is deleted afterwards,
# and the debug lines are added to the copy only.

$DevkitSatoriDataPath = Join-Path $PSScriptRoot 'satori.json'
$script:DevkitSatoriDataCache = $null
$script:DevkitSatoriPatternCache = $null

function Get-DevkitSatoriData {
    if (-not $script:DevkitSatoriDataCache) {
        $script:DevkitSatoriDataCache = [IO.File]::ReadAllText($DevkitSatoriDataPath, $DevkitUtf8) | ConvertFrom-Json
    }
    return $script:DevkitSatoriDataCache
}

# --- version ----------------------------------------------------------------------------------------------------------

# Reads the version of satori.dll / satorite.exe / ssu.dll. Returns $null when the file does not exist.
# Tag: "Mc201-5" (from the "phase McXYY-Z" string inside satori.dll and satorite.exe, otherwise from the file version
# "X, XYY, Z, 1"). Variant: Unicode (Mc2XX) or ACP (Mc1XX). Number: a [version] (XYY, Z) for comparing.
function Get-DevkitSatoriVersion([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $tag = $null
    $bytes = [IO.File]::ReadAllBytes($Path)
    foreach ($text in @([Text.Encoding]::Unicode.GetString($bytes, 0, $bytes.Length - ($bytes.Length % 2)),
                        $(if ($bytes.Length -gt 2) { [Text.Encoding]::Unicode.GetString($bytes, 1, ($bytes.Length - 1) - (($bytes.Length - 1) % 2)) } else { '' }),
                        [Text.Encoding]::GetEncoding(28591).GetString($bytes))) {
        if ($text -match 'phase (Mc\d{3}-\d+)') { $tag = $matches[1]; break }
    }
    $fileVersion = Get-DevkitFileVersion $Path
    if (-not $tag -and $fileVersion) { $tag = 'Mc{0}-{1}' -f $fileVersion.Minor, $fileVersion.Build }
    if (-not $tag) {
        return [pscustomobject]@{ Path = $Path; Tag = '(unknown)'; Variant = 'unknown'; Number = $null; Text = '(version unknown)' }
    }
    $null = $tag -match '^Mc(\d)(\d{2})-(\d+)$'
    $series = [int]$matches[1]
    $variant = if ($series -ge 2) { 'Unicode' } else { 'ACP' }
    return [pscustomobject]@{
        Path    = $Path
        Tag     = $tag
        Variant = $variant
        Number  = New-Object System.Version(([int]($matches[1] + $matches[2])), [int]$matches[3])
        Text    = "phase $tag ($variant build)"
    }
}

# Tells whether a satori.dll exports Set_loghandler (since Mc201-10), through which tamacs.exe receives the log.
# The export table holds the name as ASCII text that ends with a NUL character.
function Test-DevkitSatoriLogHandler([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($Path))
    return $text.Contains("Set_loghandler`0")
}

# --- reading and writing text files whose encoding is UTF-8 or Shift_JIS ---------------------------------------------

function Read-DevkitTextFileAuto([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $start = if ($bom) { 3 } else { 0 }
    try {
        $strict = New-Object System.Text.UTF8Encoding($false, $true)
        $text = $strict.GetString($bytes, $start, $bytes.Length - $start)
        $encoding = New-Object System.Text.UTF8Encoding($bom)
    } catch {
        $encoding = [Text.Encoding]::GetEncoding(932)
        $text = $encoding.GetString($bytes)
    }
    return [pscustomobject]@{ Text = $text; Encoding = $encoding }
}

# Adds $Lines at the end of the initialization sentence of a satori_conf.txt (a new sentence is added when there is none), so
# that they win over what the sentence sets earlier. The file keeps its encoding and line breaks.
function Add-DevkitSatoriInitLines([string]$ConfPath, [string[]]$Lines) {
    $data = Get-DevkitSatoriData
    $heading = [string]$data.initSentence
    if (-not (Test-Path -LiteralPath $ConfPath -PathType Leaf)) {
        [IO.File]::WriteAllText($ConfPath, ((@($heading) + $Lines) -join "`n") + "`n", $DevkitUtf8)
        return
    }
    $file = Read-DevkitTextFileAuto $ConfPath
    $newline = if ($file.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $all = New-Object System.Collections.Generic.List[string]
    $all.AddRange([string[]]@($file.Text -split "\r?\n"))
    $at = -1
    for ($i = 0; $i -lt $all.Count; $i++) {
        if ($all[$i].TrimEnd() -eq $heading) { $at = $i; break }
    }
    if ($at -lt 0) {
        if ($all.Count -gt 0 -and $all[$all.Count - 1] -eq '') { $all.RemoveAt($all.Count - 1) }
        $all.Add('')
        $all.Add($heading)
        $all.AddRange($Lines)
        $all.Add('')
    } else {
        # The sentence runs until the next line that starts with a full-width asterisk or at sign (or the end of the file).
        $mark1 = $heading.Substring(0, 1)
        $mark2 = [string][char]0xFF20
        $end = $all.Count
        for ($i = $at + 1; $i -lt $all.Count; $i++) {
            if ($all[$i].StartsWith($mark1) -or $all[$i].StartsWith($mark2)) { $end = $i; break }
        }
        $insert = $at + 1
        for ($i = $end - 1; $i -gt $at; $i--) {
            if ($all[$i].Trim() -ne '') { $insert = $i + 1; break }
        }
        $all.InsertRange($insert, $Lines)
    }
    Write-DevkitTextFileAuto $ConfPath ($all -join $newline) $file.Encoding
}

# Writes text in the encoding that Read-DevkitTextFileAuto returned (with its BOM, if any).
function Write-DevkitTextFileAuto([string]$Path, [string]$Text, [Text.Encoding]$Encoding) {
    $body = $Encoding.GetBytes($Text)
    $preamble = $Encoding.GetPreamble()
    $out = New-Object byte[] ($preamble.Length + $body.Length)
    [Array]::Copy($preamble, 0, $out, 0, $preamble.Length)
    [Array]::Copy($body, 0, $out, $preamble.Length, $body.Length)
    [IO.File]::WriteAllBytes($Path, $out)
}

# --- temporary copy of ghost/master ---------------------------------------------------------------------------------

# Copies ghost/master to a temporary folder and returns the copy: [pscustomobject] Root (delete this), Dir (the copy).
# EnableDebug adds the lines that switch the debug mode on (needed by ShioriEcho); Plain also turns off the automatic
# waits and line breaks so that the script is easy to read.
function New-DevkitSatoriSandbox {
    param([string]$GhostDir, [switch]$EnableDebug, [switch]$Plain)
    $root = Join-Path ([IO.Path]::GetTempPath()) ('devkit-satori-' + [guid]::NewGuid().ToString('N'))
    $dir = Join-Path $root (Split-Path $GhostDir -Leaf)
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    try {
        foreach ($item in @(Get-ChildItem -LiteralPath $GhostDir -Force)) {
            if ($item.Name -eq '.git' -or ($item.PSIsContainer -and $item.Name -eq 'profile')) { continue }
            Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $dir $item.Name) -Recurse -Force
        }
        $lines = @()
        $data = Get-DevkitSatoriData
        if ($EnableDebug) { $lines += @($data.debugLines) }
        if ($Plain) { $lines += @($data.plainLines) }
        if ($lines.Count -gt 0) { Add-DevkitSatoriInitLines (Join-Path $dir 'satori_conf.txt') $lines }
    } catch {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
    return [pscustomobject]@{ Root = $root; Dir = $dir }
}

# --- tamacs.exe -----------------------------------------------------------------------------------------------------

# Runs tamacs.exe on the satori.dll of a temporary copy of $GhostDir (see the top of this file), then deletes the copy.
# Call Get-DevkitTamacs first to tell the user when it is not available.
# tamacs.exe takes the full path of the dll. Without -r in $Arguments it only loads and unloads SATORI; with -r it
# also sends the request in $InputText and prints the response. Exit code 3: satori.dll has no Set_loghandler.
# Returns ExitCode, TimedOut, Response (the SHIORI response with -r), Log (everything SATORI logged; [ERROR] lines
# that tamacs.exe adds are included), and Sandbox (the path that appears in the log instead of $GhostDir).
function Invoke-DevkitTamacs {
    param(
        [string]$GhostDir,
        [string[]]$Arguments = @(),
        [string]$InputText,
        [switch]$EnableDebug,
        [switch]$Plain,
        [int]$TimeoutSeconds = 120
    )
    $tamacs = Get-DevkitTamacs
    if (-not $tamacs.Path) { throw $tamacs.Error }
    $sandbox = New-DevkitSatoriSandbox -GhostDir $GhostDir -EnableDebug:$EnableDebug -Plain:$Plain
    try {
        $processArgs = @{
            FilePath         = $tamacs.Path
            Arguments        = @(Join-Path $sandbox.Dir 'satori.dll') + @($Arguments)
            WorkingDirectory = $sandbox.Dir
            # On GitHub Actions tamacs.exe switches to its --ci output by itself; the plain log is read here.
            UnsetEnvironment = @('GITHUB_ACTIONS')
            TimeoutSeconds   = $TimeoutSeconds
        }
        if ($PSBoundParameters.ContainsKey('InputText')) { $processArgs['InputText'] = $InputText }
        $result = Invoke-DevkitProcess @processArgs
    } finally {
        Remove-Item -LiteralPath $sandbox.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
    $isRequest = $Arguments -contains '-r'
    # With -r, stdout is the response and stderr the log. Without it, stdout is the log and stderr has the [ERROR] lines.
    if ($isRequest) {
        $response = $result.StdOut -replace "\r\n", "`n"
        $log = $result.StdErr
    } else {
        $response = ''
        $log = $result.StdOut + "`n" + $result.StdErr
    }
    return [pscustomobject]@{
        ExitCode = $result.ExitCode
        TimedOut = $result.TimedOut
        Response = $response
        Log      = ($log -replace "\r\n", "`n")
        Sandbox  = $sandbox.Dir
    }
}

# Shows a log line the way the ghost sees it: the temporary copy becomes ghost/master (relative to the ghost root).
function ConvertTo-DevkitGhostText([string]$Text, [string]$Sandbox, [string]$GhostDir, [string]$Base) {
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    if ($Sandbox) {
        $Text = [regex]::Replace($Text, '(?i)' + [regex]::Escape($Sandbox), { param($m) $GhostDir }.GetNewClosure())
    }
    return (ConvertTo-DevkitRelativeText $Text -Base $Base)
}

# --- log analysis ---------------------------------------------------------------------------------------------------

function Get-DevkitSatoriPatterns {
    if (-not $script:DevkitSatoriPatternCache) {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($p in @((Get-DevkitSatoriData).patterns)) {
            $list.Add([pscustomobject]@{ Level = [string]$p.level; Regex = (New-Object System.Text.RegularExpressions.Regex([string]$p.regex)); Hint = [string]$p.hint; Extract = ($p.extract -eq $true) })
        }
        $script:DevkitSatoriPatternCache = $list.ToArray()
    }
    return $script:DevkitSatoriPatternCache
}

# Finds the problems in a SATORI log (the text that tamacs.exe prints). Returns objects with
#   Level (error / warning / note; notes only with -IncludeNotes), Message, Hint, In (the sentence that was being run, when known), File (a dictionary path
#   that the message is about, when the log names one), Phase (load / operation / after).
# SATORI writes plain lines to its log and sends only some of its errors as [ERROR] lines through tamacs.exe, so both
# are read: the [ERROR] / [FATAL] / [WARN] lines, and the plain lines that match scripts/shiori/satori/satori.json.
function Get-DevkitSatoriDiagnostics {
    param([string]$Log, [string]$Sandbox, [string]$GhostDir, [string]$Base, [switch]$IncludeNotes)
    $data = Get-DevkitSatoriData
    $artifact = [string]$data.flushMarkArtifact
    $patterns = Get-DevkitSatoriPatterns
    $sentenceMark = ([string]$data.initSentence).Substring(0, 1)
    $lines = @($Log -split "\r?\n")
    $found = New-Object System.Collections.Generic.List[object]
    $phase = 'load'
    $inDicFolder = $false
    $dicCount = 0
    $lastFile = ''

    function Add-Found([string]$Level, [string]$Text, [string]$Hint, [string]$In, [string]$File, [string]$Phase) {
        $found.Add([pscustomobject]@{
                Level   = $Level
                Message = (ConvertTo-DevkitGhostText $Text.Trim() $Sandbox $GhostDir $Base)
                Hint    = $Hint
                In      = $In
                File    = $File
                Phase   = $Phase
            })
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -eq '--- Request ---') { $phase = 'request'; continue }
        if ($line -eq '--- Operation ---') { $phase = 'operation'; continue }
        if ($line -eq '--- Response ---') { $phase = 'after'; continue }

        if ($line -match '^\[(FATAL|ERROR|WARN|NOTE)\]\s?(.*)$') {
            $level = $matches[1]
            $rest = $matches[2]
            if ($level -eq 'NOTE') { continue }
            $kind = if ($level -eq 'WARN') { 'warning' } else { 'error' }
            foreach ($part in @($rest -split [regex]::Escape($artifact))) {
                if ($part.Trim() -eq '') { continue }
                $shown = ConvertTo-DevkitGhostText $part $Sandbox $GhostDir $Base
                $file = $lastFile
                if ($shown -match '^(ghost/[^\s]+\.(txt|sat))$') { $lastFile = $matches[1]; $file = $lastFile }
                Add-Found $kind $part '' '' $file $phase
            }
            continue
        }
        if ($line -match '^\[tamacs\]') {
            Add-Found 'error' $line '' '' '' $phase
            continue
        }

        # The dictionaries are read between "LoadDicFolder(" and "ok."; none read means SATORI has nothing to say.
        if ($line -match '^LoadDicFolder\(') { $inDicFolder = $true; $dicCount = 0; continue }
        if ($inDicFolder) {
            if ($line -match '^\s+loading ') { $dicCount++ }
            elseif ($line -eq 'ok.') {
                $inDicFolder = $false
                if ($dicCount -eq 0) { Add-Found 'error' 'no dictionary file (dic*.txt) was loaded' 'SATORI reads dic*.txt next to satori.dll' '' '' 'load' }
            }
        }

        # The request and the response are echoed in the log; what they hold is not a message of SATORI.
        if ($phase -eq 'request' -or $line.StartsWith('Value=')) { continue }
        # "return: <script>" repeats what the lines above it already said; only patterns that read the text of the
        # script itself look at it.
        $isReturn = $line.TrimStart().StartsWith('return:')
        foreach ($pattern in $patterns) {
            if ($isReturn -and -not $pattern.Extract) { continue }
            if (-not $pattern.Regex.IsMatch($line)) { continue }
            # The sentence that was running: the nearest earlier line that starts with the sentence mark at a smaller indent.
            $where = ''
            if ($phase -ne 'load') {
                $indent = $line.Length - $line.TrimStart().Length
                $limit = [Math]::Max(0, $i - 3000)
                for ($j = $i - 1; $j -ge $limit; $j--) {
                    $candidate = $lines[$j]
                    $trimmed = $candidate.TrimStart()
                    if ($trimmed.Length -eq 0) { continue }
                    if (($candidate.Length - $trimmed.Length) -lt $indent -and $trimmed.StartsWith($sentenceMark)) { $where = $trimmed; break }
                }
            }
            $text = if ($pattern.Extract) { $pattern.Regex.Match($line).Value -replace '\\_w\[\d+\]', '' } else { $line }
            if ($text.Length -gt 300) { $text = $text.Substring(0, 300) + '...' }
            if ($pattern.Level -ne 'note' -or $IncludeNotes) { Add-Found $pattern.Level $text $pattern.Hint $where '' $phase }
            break
        }
    }

    # The same message many times (a loop) is shown once.
    $seen = @{}
    $unique = New-Object System.Collections.Generic.List[object]
    foreach ($item in $found) {
        $key = $item.Level + '|' + $item.Message
        if ($seen.ContainsKey($key)) { $seen[$key].Count++; continue }
        $item | Add-Member -NotePropertyName Count -NotePropertyValue 1
        $seen[$key] = $item
        $unique.Add($item)
    }
    return $unique.ToArray()
}

# Prints diagnostics as "[error] message" lines (and GitHub Actions annotations with -Ci). Returns the error count.
function Write-DevkitSatoriDiagnostics {
    param([object[]]$Diagnostics, [string]$Title, [switch]$Ci, [string]$Indent = '')
    $errors = 0
    $hinted = @{}
    foreach ($d in $Diagnostics) {
        if ($d.Level -eq 'error') { $errors++ }
        $text = $d.Message
        if ($d.Count -gt 1) { $text += " (x$($d.Count))" }
        if ($d.In) { $text += "  [in $($d.In)]" }
        Write-Host "$Indent[$($d.Level)] $text"
        if ($d.Hint -and -not $hinted.ContainsKey($d.Hint)) {
            $hinted[$d.Hint] = $true
            Write-Host "$Indent        hint: $($d.Hint)"
        }
        if ($Ci) {
            $place = if ($d.File) { "file=$($d.File)," } else { '' }
            $annotation = ($d.Message -replace '[\r\n%]+', ' ')
            Write-Host "::$($d.Level) ${place}title=$Title::$annotation"
        }
    }
    return $errors
}

# Names of the sentences (asterisk + name) in the dictionaries of $GhostDir that can be run by name: dic*.txt next to
# satori.dll, names without a condition, argument separator or parenthesis. Wrap the call in @().
# A sentence right below a comment line (full-width number sign) that contains "check-dic: no-run" is left out:
# one that only makes sense in its event (a timer, an input box), so running it by name gives warnings that mean
# nothing. -Skipped returns the names that were left out that way instead.
function Get-DevkitSatoriTalkNames([string]$GhostDir, [switch]$Skipped) {
    $mark = ([string](Get-DevkitSatoriData).initSentence).Substring(0, 1)
    $comment = [string][char]0xFF03
    $names = New-Object System.Collections.Generic.List[string]
    $conditional = @{}
    $noRun = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $GhostDir -File -Filter 'dic*.txt' | Sort-Object Name)) {
        $pendingNoRun = $false
        foreach ($line in ((Read-DevkitTextFileAuto $file.FullName).Text -split "\r?\n")) {
            if ($line.StartsWith($comment)) {
                if ($line -match 'check-dic:\s*no-run') { $pendingNoRun = $true }
                continue
            }
            if (-not $line.StartsWith($mark)) { $pendingNoRun = $false; continue }
            $body = $line.Substring(1)
            $tab = $body.IndexOf("`t")
            if ($tab -ge 0) {
                # name<TAB>condition: the name may also be defined without a condition elsewhere.
                $conditional[$body.Substring(0, $tab).Trim()] = $true
                $pendingNoRun = $false
                continue
            }
            $name = $body.Trim()
            if ($pendingNoRun) { $noRun[$name] = $true }
            $pendingNoRun = $false
            if ($name -eq '' -or $name -match '[\s\u3000,\u3001\uFF0C\uFF08\uFF09()]') { continue }
            $names.Add($name)
        }
    }
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($name in ($names | Sort-Object -Unique)) {
        if ($conditional.ContainsKey($name)) { continue }
        if ($noRun.ContainsKey($name) -ne [bool]$Skipped) { continue }
        $result.Add($name)
    }
    return $result.ToArray()
}

# --- doctor and setup ---------------------------------------------------------------------

# What the doctor tells tamacs.exe is used for.
$DevkitTamacsPurpose = 'Loads satori.dll without SSP: dictionary check (check-dic.ps1 and the check after each edit), shiori.ps1'

# Adds the SATORI items to the doctor (Add-DoctorItem is defined by doctor.ps1).
function Add-DevkitShioriDoctorItems([string]$Ps, [bool]$IsGitWorkingCopy) {
    $ghostMaster = Join-Path $DevkitRoot 'ghost/master'
    $dll = Join-Path $ghostMaster 'satori.dll'
    $dictionaryCount = 0
    if (Test-Path -LiteralPath $ghostMaster -PathType Container) {
        $dictionaryCount = @(Get-ChildItem -LiteralPath $ghostMaster -File -Filter 'dic*.txt' -ErrorAction SilentlyContinue).Count
    }
    $ghostOk = (Test-Path -LiteralPath $dll) -and $dictionaryCount -gt 0
    $satoriVersion = Get-DevkitSatoriVersion $dll
    Add-DoctorItem -Id 'ghost' -Name 'ghost files (SATORI)' -Level 'required' -Ok $ghostOk `
        -Purpose 'The ghost itself' `
        -Detail $(if ($ghostOk) { "satori.dll $($satoriVersion.Text), $dictionaryCount dictionaries (dic*.txt)" } elseif (-not (Test-Path -LiteralPath $dll)) { 'ghost/master/satori.dll is missing' } else { 'no ghost/master/dic*.txt' }) `
        -Fix 'Work in the ghost root folder (the one that contains ghost/ and shell/).'

    # A ghost whose descript.txt says UTF-8 needs the Unicode build of SATORI (Mc2XX); the ACP build (Mc1XX) reads
    # dictionaries in the system code page. The Unicode build reads UTF-8 and Shift_JIS dictionaries.
    $charset = Get-DevkitDescriptValue (Join-Path $ghostMaster 'descript.txt') 'charset'
    $charsetOk = -not ($satoriVersion -and $satoriVersion.Variant -eq 'ACP' -and $charset -match '^(?i:utf-?8)$')
    Add-DoctorItem -Id 'satori-build' -Name 'SATORI build' -Level 'recommended' -Ok $charsetOk `
        -Purpose 'Dictionaries and descript.txt are UTF-8, which the Unicode build of SATORI (Mc2XX) reads' `
        -Detail $(if ($satoriVersion) { "$($satoriVersion.Text); charset in descript.txt: $(if ($charset) { $charset } else { '(none)' })" } else { 'satori.dll not found' }) `
        -Fix "Run: $Ps scripts/update-shiori.ps1 -Variant Unicode (see references/satori/update.md)"

    # tamacs.exe receives the SATORI log through Set_loghandler, which satori.dll exports since Mc201-10.
    $logHandlerOk = (-not (Test-Path -LiteralPath $dll)) -or (Test-DevkitSatoriLogHandler $dll)
    Add-DoctorItem -Id 'satori-loghandler' -Name 'SATORI Mc201-10+' -Level 'required' -Ok $logHandlerOk `
        -Purpose 'tamacs.exe reads the SATORI log through Set_loghandler: dictionary check (check-dic.ps1 and the check after each edit), shiori.ps1' `
        -Detail $(if (-not (Test-Path -LiteralPath $dll)) { 'satori.dll not found (see ghost files)' } elseif ($logHandlerOk) { 'satori.dll has Set_loghandler' } else { "$($satoriVersion.Text) has no Set_loghandler" }) `
        -Fix "Run: $Ps scripts/update-shiori.ps1 (see references/satori/update.md)"
}

# The setup step of SATORI: nothing to prepare besides tamacs.exe. Returns the number of failed steps.
function Invoke-DevkitShioriSetup {
    return 0
}
