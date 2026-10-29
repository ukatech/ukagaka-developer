# What the scripts of every SHIORI (scripts/shiori/<id>/shiori.ps1, check-dic.ps1, lint.ps1) share: the start of a
# script and the SHIORI request. Dot-sourced by common.ps1, so a script has these after ". lib/common.ps1".

# The headers that the scripts send as SSP does, in UTF-8. YAYA reads the charset it answers in from yaya.txt instead.
$DevkitShioriBaseHeaders = @('Charset: UTF-8', 'Sender: SSP', 'SecurityLevel: local')

# The start of a script of a SHIORI: finds the folder of the SHIORI (default: ghost/master) and checks that the files in
# $Required are there. Returns Ok (and Code, the exit code to use, when not), GhostDir (full path), Base (the ghost
# root of that folder: paths in the output are shown relative to it) and Prefix (the path of GhostDir relative to the
# ghost root of this run, with a trailing slash, or ''). Writes "<Label>: FAILED - ..." when a file is missing.
function Resolve-DevkitShioriGhostDir {
    param([string]$Label, [string]$GhostDir, [string[]]$Required)
    if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
    $GhostDir = (Resolve-DevkitFullPath $GhostDir).TrimEnd('\', '/')
    $prefix = ''
    $rootWithSeparator = $DevkitRoot + [IO.Path]::DirectorySeparatorChar
    if ($GhostDir.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
        $prefix = $GhostDir.Substring($rootWithSeparator.Length).Replace('\', '/') + '/'
    }
    $result = [pscustomobject]@{ Ok = $true; Code = 0; GhostDir = $GhostDir; Base = (Split-Path (Split-Path $GhostDir -Parent) -Parent); Prefix = $prefix }
    foreach ($name in $Required) {
        if (-not (Test-Path -LiteralPath (Join-Path $GhostDir $name))) {
            Write-Host "${Label}: FAILED - $($Required -join ' or ') was not found in $GhostDir"
            $result.Ok = $false
            $result.Code = 1
            break
        }
    }
    return $result
}

# Finds the program that loads the SHIORI: tamacs.exe (built on the first run) or, for KAWARI, kosui.exe. Returns what
# Get-DevkitTamacs / Get-DevkitKosui return; without a Path the script exits with 3 (not checked). Writes
# "<Label>: SKIPPED - ..." then.
function Get-DevkitShioriTool {
    param([string]$Label, [ValidateSet('tamacs', 'kosui')][string]$Kind = 'tamacs')
    $tool = if ($Kind -eq 'kosui') { Get-DevkitKosui } else { Get-DevkitTamacs }
    if (-not $tool.Path) { Write-Host "${Label}: SKIPPED - $($tool.Error)" }
    return $tool
}

# Builds the text of a SHIORI request: the request line (GET, or NOTIFY with -Notify), the headers of -BaseHeader, ID,
# Reference0, Reference1, ... and then -Header ('Name: value'), which replaces a header of the same name or is added.
# -SplitReference takes commas in -Reference as separators (-Event -Reference '0,0,0,0,Head'). Lines are joined with
# LF; tamacs.exe turns them into CRLF and adds the blank line. Returns $null after writing "<Label>: ..." when a
# header is not 'Name: value' or a value has a line break.
function New-DevkitShioriRequest {
    param(
        [string]$Id,
        [string[]]$Reference,
        [string[]]$BaseHeader = $DevkitShioriBaseHeaders,
        [string[]]$Header,
        [switch]$Notify,
        [switch]$SplitReference,
        [string]$Label = 'shiori'
    )
    $headers = New-Object System.Collections.Generic.List[string]
    if ($Notify) { $headers.Add('NOTIFY SHIORI/3.0') } else { $headers.Add('GET SHIORI/3.0') }
    foreach ($line in $BaseHeader) { $headers.Add($line) }
    $headers.Add('ID: ' + $Id)
    $references = @($Reference | Where-Object { $null -ne $_ })
    if ($SplitReference) { $references = @($references | ForEach-Object { $_ -split ',' }) }
    for ($i = 0; $i -lt $references.Count; $i++) { $headers.Add("Reference${i}: " + $references[$i]) }
    foreach ($extra in @($Header | Where-Object { $_ })) {
        if ($extra -notmatch '^([^:\s]+):') {
            Write-Host "${Label}: -Header must be 'Name: value': $extra"
            return $null
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
            Write-Host "${Label}: values must be a single line"
            return $null
        }
    }
    return ($headers -join "`n")
}
