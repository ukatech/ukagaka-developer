<#
.SYNOPSIS
    Loads the ghost's KAWARI dictionaries with kosui --check (safe mode) and reports the errors and warnings.
.DESCRIPTION
    Exit codes: 0 = OK (warnings do not fail the check unless -Strict is given), 1 = errors found, 3 = not checked
    (kosui.exe is not installed or too old: run scripts/setup.ps1).
    kosui.exe comes from the latest release of ukatech/kawari (scripts/tools.json, downloaded by setup.ps1 into the
    home folder). It reads ghost/master/kawarirc.kis, and every dictionary that it loads, in its safe mode: no file is
    written (save, textsave, logfile and so on succeed without writing), no SAORI is loaded (callsaori returns an
    empty result) and nothing is sent to SSP. The =kis zones are really run, so an endless loop in them makes the
    check time out. It runs in the real ghost/master.
    What it reports (KAWARI Phase 9.2 diagnostics, "file(line): error K-E0013: message" with the call chain):
      - syntax errors: unclosed brackets and quotes, a KIS statement written outside =kis, and so on (K-E00xx)
      - errors and warnings that the =kis zones cause when they run: an undefined command (K-E0028), a write to a
        protected entry (K-E0030), a file that cannot be loaded (K-E0035), wrong number of arguments (K-W1001/1002)
      - blank definitions (K-W0001/0002)
    The static check (K-W2xxx: entries and commands that nothing defines) is left to scripts/lint.ps1.
    -Event runs events after loading (still in the safe mode), as SSP would send them with GET: the ID is put in
    System.Request.ID (References with -Reference) and System.Callback.OnGET is evaluated, so the runtime errors of
    those events are reported too. Their talk is not shown; use scripts/shiori.ps1 for that.
    kosui.exe is the latest KAWARI, not the shiori.dll of the ghost: a command that is newer than that shiori.dll
    passes this check and fails in SSP (scripts/doctor.ps1 compares the two).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-dic.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-dic.ps1 -Event OnBoot,OnClose -Decl
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    # Folder that contains kawarirc.kis (default: ghost/master).
    [string]$GhostDir,
    # Events to run after loading (GET with this ID). Several are run one after another.
    [string[]]$Event,
    # References for -Event, separated by commas (Reference0, Reference1, ...). The same for every event.
    [string]$Reference,
    # Also report reads of empty entries (K-W0003; loglevel decl). Often noisy: entries that are set later are empty.
    [switch]$Decl,
    # Treat warnings as failures.
    [switch]$Strict,
    # Emit GitHub Actions annotations.
    [switch]$Ci,
    # Also print what kosui.exe printed.
    [switch]$ShowLog,
    [int]$TimeoutSeconds = 120,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib.ps1')
Initialize-DevkitConsole

if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
$GhostDir = (Resolve-DevkitFullPath $GhostDir).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $GhostDir 'kawarirc.kis'))) {
    Write-Host "check-dic: FAILED - kawarirc.kis was not found in $GhostDir"
    exit 1
}

$kosui = Get-DevkitKosui
if (-not $kosui.Path) {
    Write-Host "check-dic: SKIPPED - $($kosui.Error)"
    exit 3
}
$dllVersion = Get-DevkitKawariVersion (Join-Path $GhostDir 'shiori.dll')
$kosuiVersion = Get-DevkitKawariVersion $kosui.Path
Write-Host "check-dic: kosui.exe $($kosuiVersion.Text) (the ghost's shiori.dll: $(if ($dllVersion) { $dllVersion.Text } else { 'none' }))"

$kosuiArgs = @('--no-lint')
if ($Decl) { $kosuiArgs += '--decl' }
foreach ($id in @($Event | ForEach-Object { $_ -split ',' } | Where-Object { $_.Trim() -ne '' })) {
    # As SSP does, the request entries are cleared first and the request type is put in System.Request.
    $script = '$(cleartree System.Request)$(cleartree System.Response)$(setstr System.Request GET)$(setstr System.Request.ID ' + $id.Trim() + ')'
    if ($Reference) {
        $refs = @($Reference -split ',')
        for ($i = 0; $i -lt $refs.Count; $i++) { $script += '$(setstr System.Request.Reference' + $i + ' "' + $refs[$i].Replace('"', '') + '")' }
    }
    $script += '$(get System.Callback.OnGET)'
    $kosuiArgs += @('--eval', $script)
}
# kosui reads its arguments in the ANSI code page, so only ASCII is passed safely.
foreach ($arg in $kosuiArgs) {
    if ($arg -match '[^\x00-\x7F]') {
        Write-Host 'check-dic: FAILED - -Event and -Reference must be ASCII (kosui reads its arguments in the ANSI code page)'
        exit 1
    }
}

$result = Invoke-DevkitKosuiCheck -GhostDir $GhostDir -Arguments $kosuiArgs -TimeoutSeconds $TimeoutSeconds
if ($ShowLog) {
    Write-Host '---- kosui --check ----'
    Write-Host $result.Raw
    Write-Host '-----------------------'
}
if ($result.TimedOut) {
    Write-Host "check-dic: FAILED - kosui.exe timed out after $TimeoutSeconds seconds (an endless loop in a =kis zone?)"
    exit 1
}
if ($result.ExitCode -eq 3 -or -not $result.Parsed) {
    Write-Host "check-dic: FAILED - kosui.exe could not check the dictionaries (exit code $($result.ExitCode)): $($result.Raw.Trim())"
    exit 1
}

$diagnostics = @($result.Diagnostics | Where-Object { -not (Test-DevkitKawariLintCode $_.Code) })
$errors = Write-DevkitKawariDiagnostics $diagnostics 'KAWARI dictionary check' -Ci:$Ci
$warnings = @($diagnostics | Where-Object { $_.Level -eq 'warning' }).Count
$summary = $(if ($Event) { "events run: $(@($Event | ForEach-Object { $_ -split ',' } | Where-Object { $_.Trim() -ne '' }).Count), " }) + "errors: $errors, warnings: $warnings"
if ($errors -gt 0 -or ($Strict -and $warnings -gt 0)) {
    Write-Host "check-dic: FAILED ($summary). Fix the problems above, the first one first: one unclosed bracket makes the lines after it fail too."
    exit 1
}
Write-Host "check-dic: OK ($summary)"
exit 0
