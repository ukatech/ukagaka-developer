<#
.SYNOPSIS
    Converts the Shift_JIS dictionaries of a KAWARI ghost to UTF-8 without BOM (a dry run unless -Apply is given).
.DESCRIPTION
    KAWARI Phase 9 reads a dictionary as UTF-8 when it has a BOM or is valid UTF-8 as a whole, and as Shift_JIS
    otherwise. Agents and most editors read and write UTF-8, and a UTF-8 line added to a Shift_JIS file makes the
    whole file invalid as UTF-8, so KAWARI reads all of it as Shift_JIS and the new line is garbled. Converting the
    dictionaries once, with the author's consent, avoids that.
    - The files: kawarirc.kis, the other *.kis files in ghost/master, and the files that they load with a literal
      name, followed recursively (as scripts/doctor.ps1 finds them), or the files given by -Path. Only Shift_JIS ones
      are converted; UTF-8 and ASCII ones are left as they are.
    - The text and the line breaks are kept; only the encoding changes. No BOM is added: encrypted lines
      (!KAWA0000 / !KAWA0001) are decoded as Shift_JIS in a file without a BOM and as UTF-8 in one with a BOM, so
      they keep working only without one.
    - A file that does not come back unchanged from Shift_JIS through UTF-8 (bytes that are not valid Shift_JIS)
      is not converted and is reported.
    - Phase 8.2.x does not read UTF-8 dictionaries, so the ghost needs shiori.dll of Phase 9 (it refuses otherwise,
      unless -Force is given).
    - Files that the dictionaries read with textload / textload_charset are not dictionaries and are not looked for;
      how those commands read them is up to the commands.
    -Apply converts the files; the old ones are first copied to backups/ in the home folder.
    Exit codes: 0 = converted / nothing to convert / dry run, 1 = failed.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori/kawari/convert-utf8.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/shiori/kawari/convert-utf8.ps1 -Apply
#>
[CmdletBinding()]
param(
    # Files to convert, relative to ghost/master or absolute (default: the dictionaries of the ghost).
    [string[]]$Path,
    # Convert the files (without it, only the plan is shown).
    [switch]$Apply,
    # Convert even when shiori.dll is not Phase 9.
    [switch]$Force,
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib.ps1')
Initialize-DevkitConsole

$ghostDir = Join-Path $DevkitRoot 'ghost/master'
$version = Get-DevkitKawariVersion (Join-Path $ghostDir 'shiori.dll')
if (-not ($version -and $version.Phase9) -and -not $Force) {
    Write-Host "convert-utf8: FAILED - shiori.dll is $(if ($version) { $version.Text } else { 'missing' }); Phase 8.2.x reads dictionaries only as Shift_JIS. Update it first (references/kawari/update.md), or give -Force."
    exit 1
}

$files = if ($Path) {
    @($Path | ForEach-Object { if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $ghostDir $_ } })
} else {
    @(Get-DevkitKawariDictionaryFiles $ghostDir)
}
$base = (Resolve-DevkitFullPath $DevkitRoot).TrimEnd('\', '/') + '\'
$sjis = [Text.Encoding]::GetEncoding(932, [Text.EncoderFallback]::ExceptionFallback, [Text.DecoderFallback]::ExceptionFallback)
$plan = New-Object System.Collections.Generic.List[object]
$problems = 0
foreach ($file in $files) {
    $full = [IO.Path]::GetFullPath($file)
    $shown = if ($full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { $full.Substring($base.Length).Replace('\', '/') } else { $full }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Write-Host "  missing  $shown"
        $problems++
        continue
    }
    $read = Read-DevkitKawariText $full
    if ($read.Encoding -ne 'Shift_JIS') {
        Write-Host ('  keep     {0} ({1})' -f $shown, $read.Encoding)
        continue
    }
    try {
        $text = $sjis.GetString($read.Bytes)
        $back = $sjis.GetBytes($text)
        if ([Convert]::ToBase64String($back) -ne [Convert]::ToBase64String($read.Bytes)) { throw 'the bytes do not come back' }
    } catch {
        Write-Host "  SKIP     $shown (not valid Shift_JIS: $($_.Exception.Message)); convert it by hand"
        $problems++
        continue
    }
    $plan.Add([pscustomobject]@{ Full = $full; Shown = $shown; Text = $text })
    Write-Host "  convert  $shown (Shift_JIS -> UTF-8)"
}

if ($plan.Count -eq 0) {
    Write-Host 'convert-utf8: nothing to convert'
    exit $(if ($problems -gt 0) { 1 } else { 0 })
}
if (-not $Apply) {
    Write-Host "convert-utf8: dry run, nothing changed ($($plan.Count) file(s) to convert). -Apply converts them."
    exit $(if ($problems -gt 0) { 1 } else { 0 })
}

$backupDir = Join-Path (Join-Path $DevkitHome 'backups') ('kawari-utf8-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($item in $plan) {
    $target = Join-Path $backupDir ($item.Shown -replace '[:]', '_')
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath $item.Full -Destination $target -Force
    [IO.File]::WriteAllBytes($item.Full, $DevkitUtf8.GetBytes($item.Text))
}
Write-Host "convert-utf8: converted $($plan.Count) file(s); the old files are in $backupDir"
Write-Host 'convert-utf8: run scripts/check-dic.ps1 next.'
exit $(if ($problems -gt 0) { 1 } else { 0 })
