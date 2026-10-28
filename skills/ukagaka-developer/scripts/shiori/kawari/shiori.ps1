<#
.SYNOPSIS
    Sends one SHIORI request to the ghost's shiori.dll (KAWARI Phase 9) with tamacs.exe, without SSP.
.DESCRIPTION
    tamacs.exe loads the dictionaries, sends the request, prints the response and unloads KAWARI
    (tamacs -r --no-loghandler). SSP does not need to be running, and nothing appears on the desktop.

    Every call runs in a temporary copy of ghost/master that is deleted afterwards, so the real folder is not
    touched (KAWARI and the dictionaries write save files and logs into it). The copy has the save files that the
    real folder holds. Each call loads the ghost from scratch: no OnBoot or other event is sent before the request.
    The code runs in the real dictionaries with the real shiori.dll, though: code that calls SAORI (a SAORI that
    changes the screen and so on) really does so. Unlike scripts/check-dic.ps1 (kosui --check), this is not a
    safe mode.

    shiori.dll of KAWARI has no Set_loghandler, so kawarirc.kis of the temporary copy gets a =kis zone at its start
    and one at its end that set logfile and loglevel (error warning, and decl with -Decl); the log files are read
    afterwards and the diagnostics are shown after the response, with the call chain. The zone at the end wins over
    the logfile / loglevel lines of the ghost. Line numbers of kawarirc.kis are those of the real file.

    -Eval evaluates KAWARI text as if it were a word of a dictionary: ${entry}, $(command ...), $[ expression ],
    and text around them. It is one line (line breaks become spaces). It goes to the shiori.dll as a request with
    the ID devkit.eval: the temporary copy wraps System.Callback.OnGET so that this ID returns
    $(eval <the text>) and every other ID goes to the original System.Callback.OnGET. The result is the text that
    KAWARI makes (bytes 1 and 2, which urllist and some resources use, are shown as <01> and <02>).

    -Event sends "GET SHIORI/3.0" (NOTIFY with -Notify) with ID and References, as SSP does for an event or a
    resource. Sender is SSP, SecurityLevel is local and Charset is UTF-8 (KAWARI answers in the charset of the
    request). -Header adds or replaces headers. KAWARI gives the request to System.Callback.OnGET (OnNOTIFY), and
    the dictionaries decide what to do with the ID (event.<ID>, reply.<ID>, a bare <ID> and so on; GHOST.md).

    -Request sends the given text as it is. tamacs.exe turns the line breaks into CRLF and adds the blank line.

    Exit codes: 0 = OK, 1 = failed (shiori.dll could not be loaded, no or an error response), 2 = KAWARI logged an
    error or a warning while handling the request (the response may be incomplete), 3 = tamacs.exe could not be
    built, or shiori.dll is not KAWARI Phase 9 (update it: references/kawari/update.md).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori.ps1 -Event OnBoot
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori.ps1 -Event OnMouseDoubleClick -Reference '0,0,0,0,Head'
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori.ps1 -Eval '$[ 1 + 2 ] ${sentence}'
#>
[CmdletBinding(DefaultParameterSetName = 'Eval')]
param(
    # KAWARI text to evaluate, as a word of a dictionary.
    [Parameter(ParameterSetName = 'Eval', Mandatory = $true, Position = 0)]
    [string]$Eval,

    # SHIORI event or resource ID.
    [Parameter(ParameterSetName = 'Event', Mandatory = $true)]
    [Alias('Event')]
    [string]$EventName,

    # Event references. Commas separate Reference0, Reference1, ...
    [Parameter(ParameterSetName = 'Event')]
    [string[]]$Reference,

    # Send NOTIFY instead of GET.
    [Parameter(ParameterSetName = 'Event')]
    [switch]$Notify,

    # Headers to add or replace, as 'Name: value'.
    [Parameter(ParameterSetName = 'Event')]
    [string[]]$Header,

    # Raw SHIORI request: the request line and the headers.
    [Parameter(ParameterSetName = 'Request', Mandatory = $true)]
    [string]$Request,

    # Also report reads of empty entries (K-W0003; loglevel decl).
    [switch]$Decl,
    # Folder that contains shiori.dll (default: ghost/master).
    [string]$GhostDir,
    # Also print the raw response.
    [switch]$ShowLog,
    [int]$TimeoutSeconds = 60,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib.ps1')
Initialize-DevkitConsole

if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
$GhostDir = (Resolve-DevkitFullPath $GhostDir).TrimEnd('\', '/')
$dll = Join-Path $GhostDir 'shiori.dll'
if (-not (Test-Path -LiteralPath $dll) -or -not (Test-Path -LiteralPath (Join-Path $GhostDir 'kawarirc.kis'))) {
    Write-Host "shiori: FAILED - shiori.dll or kawarirc.kis was not found in $GhostDir"
    exit 1
}
$version = Get-DevkitKawariVersion $dll
if (-not $version.Phase9) {
    Write-Host "shiori: SKIPPED - shiori.dll is $($version.Text); the skill supports KAWARI Phase 9 (Phase 8 dictionaries run on it unchanged). Update it after the author agrees: references/kawari/update.md"
    exit 3
}
$tamacs = Get-DevkitTamacs
if (-not $tamacs.Path) {
    Write-Host "shiori: SKIPPED - $($tamacs.Error)"
    exit 3
}

$mode = $PSCmdlet.ParameterSetName
$baseHeaders = @('Charset: UTF-8', 'Sender: SSP', 'SecurityLevel: local')
switch ($mode) {
    'Eval' {
        $text = ($Eval -split "\r\n|\r|\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) -join ' '
        if ($text -eq '') {
            Write-Host 'shiori: -Eval is empty'
            exit 1
        }
        $requestText = (@('GET SHIORI/3.0') + $baseHeaders + @("ID: $DevkitKawariEvalId", "Reference0: $text")) -join "`n"
    }
    'Event' {
        $headers = New-Object System.Collections.Generic.List[string]
        if ($Notify) { $headers.Add('NOTIFY SHIORI/3.0') } else { $headers.Add('GET SHIORI/3.0') }
        foreach ($h in $baseHeaders) { $headers.Add($h) }
        $headers.Add('ID: ' + $EventName)
        $references = @($Reference | Where-Object { $null -ne $_ } | ForEach-Object { $_ -split ',' })
        for ($i = 0; $i -lt $references.Count; $i++) { $headers.Add("Reference${i}: " + $references[$i]) }
        foreach ($extra in @($Header | Where-Object { $_ })) {
            if ($extra -notmatch '^([^:\s]+):') {
                Write-Host "shiori: -Header must be 'Name: value': $extra"
                exit 1
            }
            $prefix = $matches[1] + ':'
            $index = -1
            for ($i = 1; $i -lt $headers.Count; $i++) {
                if ($headers[$i].StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $index = $i; break }
            }
            if ($index -ge 0) { $headers[$index] = $extra } else { $headers.Add($extra) }
        }
        foreach ($line in $headers) {
            if ($line -match "[\r\n]") {
                Write-Host 'shiori: values must be a single line'
                exit 1
            }
        }
        $requestText = $headers -join "`n"
    }
    'Request' {
        $requestText = $Request
        if ($requestText.Trim() -eq '') {
            Write-Host 'shiori: -Request is empty'
            exit 1
        }
    }
}

$level = @('error', 'warning')
if ($Decl) { $level += 'decl' }
$result = Invoke-DevkitTamacs -GhostDir $GhostDir -InputText $requestText -LogLevel $level -EvalHook:($mode -eq 'Eval') -TimeoutSeconds $TimeoutSeconds

function Format-ShioriText([string]$Text) {
    return $Text.Replace([string][char]1, '<01>').Replace([string][char]2, '<02>')
}

$response = Format-ShioriText $result.Response
$failure = $null
if ($ShowLog -and $response.Trim() -ne '') {
    Write-Host '---- response ----'
    Write-Host $response.TrimEnd()
    Write-Host '------------------'
}
if ($response.Trim() -ne '') {
    if ($mode -eq 'Eval') {
        if ($response -match '^SHIORI/\d\.\d\s+200' -and $response -match '(?m)^Value: ?(.*)$') {
            Write-Host $matches[1]
        } elseif ($response -match '^SHIORI/\d\.\d\s+204') {
            Write-Host '(no output: 204 No Content)'
        } else {
            Write-Host $response.TrimEnd()
            $failure = "-Eval was not answered with a Value ($(($response -split "`n")[0].Trim()))"
        }
    } elseif (-not $ShowLog) {
        Write-Host $response.TrimEnd()
    }
    if ($response -match '^SHIORI/\d\.\d\s+(\d{3})' -and [int]$matches[1] -ge 400) {
        $failure = "error response ($($response.Split("`n")[0].Trim()))"
    }
}

if ($result.LoadDiagnostics.Count -gt 0) {
    Write-Host 'shiori: messages while loading the dictionaries (scripts/check-dic.ps1 reports them too):'
    [void](Write-DevkitKawariDiagnostics $result.LoadDiagnostics 'KAWARI')
}
if ($result.RunDiagnostics.Count -gt 0) {
    Write-Host 'shiori: messages while handling the request:'
    [void](Write-DevkitKawariDiagnostics $result.RunDiagnostics 'KAWARI')
}

if ($result.TimedOut) {
    Write-Host "shiori: FAILED - tamacs.exe did not finish within $TimeoutSeconds seconds (an endless loop?)"
    exit 1
}
if ($response.Trim() -eq '') {
    Write-Host "shiori: FAILED - tamacs.exe printed no response (exit code $($result.ExitCode)): $($result.Error)"
    exit 1
}
if ($result.ExitCode -ne 0) {
    Write-Host "shiori: FAILED (tamacs.exe exit code $($result.ExitCode)): $($result.Error)"
    exit 1
}
if ($failure) {
    Write-Host "shiori: FAILED - $failure"
    exit 1
}
if ($result.RunDiagnostics.Count -gt 0) {
    Write-Host 'shiori: KAWARI logged errors or warnings while handling the request (see above).'
    exit 2
}
exit 0
