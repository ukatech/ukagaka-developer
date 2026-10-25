<#
.SYNOPSIS
    Opens the log receiver window (tamacsw.exe): it shows the log of SATORI while the ghost runs in SSP.
.DESCRIPTION
    The window receives the log that SATORI sends (Mc201-10 or later) to a window of the class TamaWndClass, the same
    mechanism as tama, the log tool of YAYA, so it cannot be open together with tama. Open it BEFORE the ghost starts:
    SATORI looks for the window once, when it first writes a log after loading. When the ghost is already running,
    restart it (or switch to another ghost and back).
    tamacsw.exe is built from scripts/lib/tamacsw.cs with csc.exe of the .NET Framework on first use, into the bin folder
    of the home folder (no download). It replaces receiver.bat / receiver.ps1 of the old development kit.
    Window keys: Esc clears the log, F5 pauses and resumes, Ctrl+S saves the log. Red is an error, orange a warning.
    Exit codes: 0 = the window was opened, 1 = it could not be built or started.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/log-window.ps1
#>
[CmdletBinding()]
param(
    # Ghost root folder: the one that holds ghost/ and shell/ (default: found from the current folder upwards).
    [string]$GhostRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
Initialize-DevkitConsole

$tool = Get-DevkitTamacsw
if (-not $tool.Path) {
    Write-Host "log-window: FAILED - $($tool.Error)"
    exit 1
}
$arguments = @()
$name = Get-DevkitDescriptValue (Join-Path $DevkitRoot 'ghost/master/descript.txt') 'name'
if ($name) { $arguments = @('-t', ('"' + $name.Replace('"', '') + '"')) }
$workDir = Join-Path $DevkitRoot 'ghost/master'
if ($arguments.Count -gt 0) {
    Start-Process -FilePath $tool.Path -ArgumentList $arguments -WorkingDirectory $workDir
} else {
    Start-Process -FilePath $tool.Path -WorkingDirectory $workDir
}
Write-Host "log-window: opened $($tool.Path). Start (or restart) the ghost now."
exit 0
