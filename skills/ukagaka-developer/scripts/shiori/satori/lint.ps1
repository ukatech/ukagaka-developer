<#
.SYNOPSIS
    Checks the dictionaries without running them, with ShioriLint of SATORI (Mc206-1 or later).
.DESCRIPTION
    tamacs.exe loads satori.dll and sends the request "ID: ShioriLint" (SecurityLevel: local). SATORI reads the loaded
    dictionaries the way it reads them when it runs, but runs nothing, and answers with the problems it found in the
    ErrorLevel / ErrorDescription headers (byte 1 separates the items). SSP is not needed. The check runs in a
    temporary copy of ghost/master, so the real folder is not touched.

    Each finding is printed as "ghost/master/dic.txt(12) : error: message", the shape of a compiler message, which
    editors and CI can read. The path is relative to the ghost root; the line is the line in the file.
      error   - wrong for certain: a jump target that cannot work, a variable assignment line without a tab or an
                equal sign, a calculation that cannot be done, a wrong number of arguments for a built-in function, an
                unclosed full-width bracket and so on.
      warning - probably wrong: a bracketed name that nothing defines, a word group and a sentence with the same name, a
                jump target that differs only in spaces / width / case from an existing sentence, and so on.
      notice  - may be on purpose (an optional hook that a template defines, a symbol shown as text). Counted, and
                shown only with -Notice.
    A last "info" item says how many findings were left out when there were too many.

    Findings that are not wrong for sure are not errors, so a ghost may have warnings and still pass. See
    references/satori/check.md for how to read them. Manual: https://ukatech.shillest.net/satori-docs/shiori/lint/

    Exit codes: 0 = no error (and no warning with -Strict), 1 = an error was found (a warning with -Strict), or the
    check could not be done (no answer, an error response), 3 = not available (tamacs.exe could not be built, or
    satori.dll is older than Mc206-1 and has no ShioriLint).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1 -Notice
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint.ps1 -Strict -Ci
#>
[CmdletBinding()]
param(
    # Folder that contains satori.dll (default: ghost/master).
    [string]$GhostDir,
    # Treat warnings as failures.
    [switch]$Strict,
    # Also print the notices (they are only counted otherwise).
    [switch]$Notice,
    # Emit GitHub Actions annotations.
    [switch]$Ci,
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
$dll = Join-Path $GhostDir 'satori.dll'
if (-not (Test-Path -LiteralPath $dll)) {
    Write-Host "lint: FAILED - satori.dll was not found in $GhostDir"
    exit 1
}

$tamacs = Get-DevkitTamacs
if (-not $tamacs.Path) {
    Write-Host "lint: SKIPPED - $($tamacs.Error)"
    exit 3
}

# An older SATORI does not know the ID: it expands "ShioriLint" as a name and answers 200 or 204 either way, which cannot be
# told from "no problems". So the version decides.
$version = Get-DevkitSatoriVersion $dll
$minimum = New-Object System.Version(206, 1)
if ($version.Number -and $version.Number -lt $minimum) {
    Write-Host "lint: SKIPPED - satori.dll $($version.Text) has no ShioriLint (SATORI Mc206-1 or later). Update SATORI: references/satori/update.md"
    exit 3
}

# Paths in the messages are relative to ghost/master; show them relative to the ghost root.
$prefix = ''
$rootWithSeparator = $DevkitRoot + [IO.Path]::DirectorySeparatorChar
if ($GhostDir.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
    $prefix = $GhostDir.Substring($rootWithSeparator.Length).Replace('\', '/') + '/'
}

$requestText = "GET SHIORI/3.0`nCharset: UTF-8`nSender: SSP`nSecurityLevel: local`nID: ShioriLint"
$result = Invoke-DevkitTamacs -GhostDir $GhostDir -Arguments @('-r') -InputText $requestText -TimeoutSeconds $TimeoutSeconds
if ($result.TimedOut) {
    Write-Host "lint: FAILED - tamacs.exe did not finish within $TimeoutSeconds seconds"
    exit 1
}
if ($result.ExitCode -eq 3) {
    Write-Host 'lint: SKIPPED - satori.dll has no Set_loghandler, which tamacs.exe needs (SATORI Mc201-10 or later). Update SATORI: references/satori/update.md'
    exit 3
}

$response = $result.Response
$status = ''
if ($response -match '^SHIORI/\d\.\d\s+(\d{3})') { $status = $matches[1] }
if ($status -eq '') {
    Write-Host "lint: FAILED - tamacs.exe printed no response (exit code $($result.ExitCode)); is satori.dll loadable? Run scripts/check-dic.ps1 -ShowLog."
    exit 1
}
if ($status -eq '204') {
    Write-Host 'lint: SKIPPED - satori.dll did not answer ShioriLint (SATORI Mc206-1 or later has it). Update SATORI: references/satori/update.md'
    exit 3
}
if ($status -ne '200') {
    Write-Host "lint: FAILED - error response ($(($response -split "`n")[0].Trim()))"
    exit 1
}

$levels = @()
$descriptions = @()
if ($response -match '(?m)^ErrorLevel: ?(.*)$') { $levels = @($matches[1].TrimEnd("`r") -split [char]1) }
if ($response -match '(?m)^ErrorDescription: ?(.*)$') { $descriptions = @($matches[1].TrimEnd("`r") -split [char]1) }

# The response also carries the ordinary error notices of SATORI (a dictionary that does not load, and so on), which
# have no "file(line)" and may be critical; they count as errors. Their paths are those of the temporary copy.
$base = Split-Path (Split-Path $GhostDir -Parent) -Parent
$counts = @{ error = 0; warning = 0; notice = 0; info = 0 }
for ($i = 0; $i -lt $descriptions.Count; $i++) {
    $level = if ($i -lt $levels.Count) { $levels[$i].Trim() } else { 'error' }
    $class = switch ($level) { 'warning' { 'warning' } 'notice' { 'notice' } 'info' { 'info' } default { 'error' } }
    $text = $descriptions[$i]
    $path = ''
    $line = 0
    $message = $text
    if ($text -match '^(.+?)\((\d+)\) : (?:error|warning|notice): (.*)$') {
        $path = $prefix + $matches[1]
        $line = [int]$matches[2]
        $message = $matches[3]
    } else {
        $message = ConvertTo-DevkitGhostText $text $result.Sandbox $GhostDir $base
    }
    $counts[$class]++

    $show = ($class -ne 'notice') -or $Notice
    if ($show) {
        if ($path) { Write-Host "${path}($line) : ${level}: $message" } else { Write-Host "lint: ${level}: $message" }
    }
    if ($Ci -and $show -and $class -ne 'info') {
        $place = if ($path) { "file=$path,line=$line," } else { '' }
        $annotation = ($message -replace '[\r\n%]+', ' ')
        Write-Host "::$class ${place}title=SATORI ShioriLint::$annotation"
    }
}

$summary = "$($counts['error']) errors, $($counts['warning']) warnings, $($counts['notice']) notices"
if ($counts['notice'] -gt 0 -and -not $Notice) { $summary += ' (not shown; -Notice shows them)' }
if ($counts['error'] -gt 0 -or ($Strict -and $counts['warning'] -gt 0)) {
    Write-Host "lint: FAILED ($summary). Fix the findings above; references/satori/check.md explains each finding."
    exit 1
}
Write-Host "lint: OK ($summary)"
exit 0
