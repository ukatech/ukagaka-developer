<#
.SYNOPSIS
    Sends one SHIORI request to the ghost's satori.dll with tamacs.exe, without SSP.
.DESCRIPTION
    tamacs.exe loads the dictionaries, sends the request, prints the response and unloads SATORI (tamacs -r).
    SSP does not need to be running, and nothing appears on the desktop.

    Every call runs in a temporary copy of ghost/master that is deleted afterwards, so the real folder is not
    touched (SATORI writes satori_savedata.txt and satori_savebackup.txt when it unloads). The copy has the
    variables that the real satori_savedata.txt holds. Each call loads the ghost from scratch: no OnBoot or other
    event is sent before the request. The code runs in the real dictionaries, though: code that calls SAORI
    (a SAORI that changes the screen and so on) or runs programs really does so.

    -Eval expands SATORI text with ShioriEcho, SATORI's own debug ID. Each line of the text is one line of a
    sentence body (Reference0, Reference1, ...), handled like a line in a dictionary: an expression in full-width
    brackets such as the calc function, the name of a word group / sentence / variable in full-width brackets, a
    variable assignment line, a jump line, and so on. A sentence with a plain name is called by writing its name
    in the brackets; arguments go through the call function. Random talks (sentences without a name) are run by
    -Event OnTalk. The result is the sakura script that SATORI makes from the lines (dangerous tags such as
    \![raise are neutralized). ShioriEcho works only when the debug mode is on and SecurityLevel is local: this
    script adds the debug mode line to the initialization sentence of satori_conf.txt in the temporary copy only
    (the text is in scripts/shiori/satori/satori.json). Examples: references/commands.md.

    -Plain (with -Eval or -Event) turns off the automatic waits and line breaks so that the script is easy to read,
    and shows each choice as \q[label,ID]. SATORI adds byte 1, the label, byte 1 and a number to the ID of a choice;
    without -Plain the byte is shown as <01>.

    -Event sends "GET SHIORI/3.0" (NOTIFY with -Notify) with ID and References, as SSP does for an event or a
    resource. Sender is SSP, SecurityLevel is local and Charset is UTF-8 (SATORI answers in the charset of the
    request). An ID that does not start with On is expanded as a name: a sentence, word group, variable or built-in
    name. -Header adds or replaces headers.

    -Request sends the given text as it is. tamacs.exe turns the line breaks into CRLF and adds the blank line.

    The SATORI messages that this request caused are shown after the response: [error] such as a call with
    arguments to a name that does not exist, a calculation that failed or a wrong number of arguments, [warning]
    such as a name that was not found, and [note] such as a jump to a missing sentence. Messages from loading are
    shown too (see scripts/check-dic.ps1). They come from scripts/shiori/satori/satori.json and the SATORI log; -ShowLog prints the
    whole log.
    Exit codes: 0 = OK, 1 = failed (satori.dll could not be loaded, the dictionaries have load errors, no or an
    error response), 2 = SATORI logged an error or a warning while handling the request (the response may be
    incomplete), 3 = tamacs.exe could not be built or satori.dll has no Set_loghandler (older than Mc201-10).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori.ps1 -Event OnBoot
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori.ps1 -Event OnMouseDoubleClick -Reference '0,0,0,0,Head'
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori.ps1 -Event version
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori.ps1 -Eval (calc expression in full-width brackets) -Plain
#>
[CmdletBinding(DefaultParameterSetName = 'Eval')]
param(
    # SATORI text to expand with ShioriEcho. Each line becomes Reference0, Reference1, ...
    [Parameter(ParameterSetName = 'Eval', Mandatory = $true, Position = 0)]
    [string]$Eval,

    # -Eval and -Event: turn off the automatic waits and line breaks in the temporary copy.
    [Parameter(ParameterSetName = 'Eval')]
    [Parameter(ParameterSetName = 'Event')]
    [switch]$Plain,

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

    # Folder that contains satori.dll (default: ghost/master).
    [string]$GhostDir,
    # Also print the whole SATORI log (load, request and unload).
    [switch]$ShowLog,
    [int]$TimeoutSeconds = 60,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib.ps1')
Initialize-DevkitConsole

$ghost = Resolve-DevkitShioriGhostDir 'shiori' $GhostDir 'satori.dll'
if (-not $ghost.Ok) { exit $ghost.Code }
$GhostDir = $ghost.GhostDir
$tamacs = Get-DevkitShioriTool 'shiori'
if (-not $tamacs.Path) { exit 3 }

$mode = $PSCmdlet.ParameterSetName
switch ($mode) {
    'Eval' {
        $lines = @($Eval -split "\r\n|\r|\n" | Where-Object { $_.Trim() -ne '' })
        if ($lines.Count -eq 0) {
            Write-Host 'shiori: -Eval is empty'
            exit 1
        }
        $requestText = New-DevkitShioriRequest -Id 'ShioriEcho' -Reference $lines
        if ($null -eq $requestText) { exit 1 }
    }
    'Event' {
        $requestText = New-DevkitShioriRequest -Id $EventName -Reference $Reference -Header $Header -Notify:$Notify -SplitReference
        if ($null -eq $requestText) { exit 1 }
    }
    'Request' {
        $requestText = $Request
        if ($requestText.Trim() -eq '') {
            Write-Host 'shiori: -Request is empty'
            exit 1
        }
    }
}

$result = Invoke-DevkitTamacs -GhostDir $GhostDir -Arguments @('-r') -InputText $requestText -EnableDebug:($mode -eq 'Eval') -Plain:$Plain -TimeoutSeconds $TimeoutSeconds

# Paths in the output are shown relative to the ghost root (the folder with ghost/ and shell/).
$base = $ghost.Base

$diagnostics = @(Get-DevkitSatoriDiagnostics -Log $result.Log -Sandbox $result.Sandbox -GhostDir $GhostDir -Base $base -IncludeNotes)
$loadMessages = @($diagnostics | Where-Object { $_.Phase -eq 'load' })
$requestMessages = @($diagnostics | Where-Object { $_.Phase -ne 'load' })
$loadErrors = @($loadMessages | Where-Object { $_.Level -eq 'error' }).Count

# SATORI rewrites \q[label,ID] to \q[label,ID<byte 1>label<byte 1>number] (it reads the label and the number back
# in OnChoiceSelect). Byte 1 does not show in a terminal, so -Plain drops the added part and the other modes show
# the byte as <01>.
function Format-ShioriText([string]$Text) {
    if ($Plain) { return [regex]::Replace($Text, '\x01[^\x01\]]*\x01\d+', '') }
    return $Text.Replace([string][char]1, '<01>')
}

$response = Format-ShioriText $result.Response
$exitCode = 0
$failure = $null
if ($response.Trim() -ne '') {
    if ($mode -eq 'Eval') {
        if ($response -match '^SHIORI/\d\.\d\s+200' -and $response -match '(?m)^Value: ?(.*)$') {
            $value = $matches[1]
            Write-Host $value
            if ($value.Contains(([string][char]0x30C7 + [char]0x30D0 + [char]0x30C3 + [char]0x30B0 + [char]0x30E2 + [char]0x30FC + [char]0x30C9))) {
                $failure = 'ShioriEcho answered that the debug mode is off; a dictionary may switch it off after satori_conf.txt'
            }
        } elseif ($response -match '^SHIORI/\d\.\d\s+204') {
            Write-Host '(no output: 204 No Content)'
        } else {
            Write-Host $response.TrimEnd()
            $failure = "-Eval was not answered with a Value ($(($response -split "`n")[0].Trim()))"
        }
    } else {
        Write-Host $response.TrimEnd()
        if ($response -match '^SHIORI/\d\.\d\s+(\d{3})' -and [int]$matches[1] -ge 400) {
            $failure = "error response ($($response.Split("`n")[0].Trim()))"
        }
    }
}

if ($ShowLog) {
    Write-Host '---- SATORI log ----'
    foreach ($line in ($result.Log -split "`n")) { Write-Host (ConvertTo-DevkitGhostText $line $result.Sandbox $GhostDir $base) }
    Write-Host '--------------------'
}
if ($loadMessages.Count -gt 0) {
    Write-Host 'shiori: messages while loading the dictionaries:'
    [void](Write-DevkitSatoriDiagnostics $loadMessages 'SATORI' -Indent '  ')
}
if ($requestMessages.Count -gt 0) {
    Write-Host 'shiori: messages while handling the request:'
    [void](Write-DevkitSatoriDiagnostics $requestMessages 'SATORI' -Indent '  ')
}

if ($result.TimedOut) {
    Write-Host "shiori: FAILED - tamacs.exe did not finish within $TimeoutSeconds seconds"
    exit 1
}
if ($result.ExitCode -eq 3) {
    Write-Host 'shiori: SKIPPED - satori.dll has no Set_loghandler, which tamacs.exe needs (SATORI Mc201-10 or later). Update SATORI: references/satori/update.md'
    exit 3
}
if ($response.Trim() -eq '') {
    Write-Host "shiori: FAILED - tamacs.exe printed no response (exit code $($result.ExitCode)); is satori.dll loadable? Use -ShowLog."
    exit 1
}
if ($loadErrors -gt 0) {
    Write-Host 'shiori: FAILED - the dictionaries have load errors. Fix them first (scripts/check-dic.ps1).'
    exit 1
}
if ($result.ExitCode -ne 0 -and $result.ExitCode -ne 2) {
    Write-Host "shiori: FAILED (tamacs.exe exit code $($result.ExitCode))"
    exit 1
}
if ($failure) {
    Write-Host "shiori: FAILED - $failure"
    exit 1
}
# A NOTIFY about something that has no sentence is normal, so its "not found" warnings do not count.
$counted = @($requestMessages | Where-Object { $_.Level -eq 'error' -or ($_.Level -eq 'warning' -and -not $Notify) })
if ($counted.Count -gt 0) {
    Write-Host 'shiori: SATORI logged errors or warnings while handling the request (see above).'
    $exitCode = 2
}
exit $exitCode
