# What scripts/shiori/<id>/update.ps1 of every SHIORI share: a work folder, the download of a release, the files of a zip,
# and replacing files with a check that puts the old ones back. Dot-sourced by those scripts after lib/common.ps1.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Makes a temporary folder named devkit-<Name>-<guid> and returns its path. The caller deletes it.
function New-DevkitWorkDir([string]$Name) {
    $work = Join-Path ([IO.Path]::GetTempPath()) ("devkit-$Name-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    return $work
}

# Runs check-dic.ps1 of the SHIORI $Shiori ('yaya', 'satori' or 'kawari') on the ghost and returns its exit code
# (1 = errors, 3 = not checked: tamacs.exe or kosui.exe is not available). Its output is shown.
function Invoke-DevkitDictionaryCheck([string]$Shiori, [string]$GhostDir) {
    $powershell = (Get-Process -Id $PID).Path
    $ErrorActionPreference = 'Continue'
    & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Get-DevkitShioriDir $Shiori) 'check-dic.ps1') -GhostDir $GhostDir -GhostRoot $DevkitRoot | Out-Host
    return $LASTEXITCODE
}

# Downloads an asset of a GitHub release ($Asset is an element of release.assets) to $Path. When GitHub publishes a
# SHA256 digest for the asset, the download is checked against it and a mismatch throws.
function Save-DevkitReleaseAsset($Asset, [string]$Path) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri $Asset.browser_download_url -OutFile $Path
    if ([string]$Asset.digest -match '^sha256:([0-9a-fA-F]{64})$') {
        $expected = $matches[1].ToUpperInvariant()
        $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        if ($hash -ne $expected) { throw "SHA256 of $($Asset.name) does not match the release (expected $expected, got $hash)" }
    }
}

# Extracts files from a zip. $Files maps the name of a file in the zip (with or without folders in front of it; case
# does not matter) to the path to write it to, whose folder is made. When the zip has several files of that name, the
# last one is written. Returns the names that were found.
function Expand-DevkitZipFile([string]$ZipPath, [hashtable]$Files) {
    $found = New-Object System.Collections.Generic.List[string]
    $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            foreach ($wanted in $Files.Keys) {
                if ($name -ieq $wanted -or $name.EndsWith('/' + $wanted, [StringComparison]::OrdinalIgnoreCase)) {
                    $target = $Files[$wanted]
                    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
                    if (-not $found.Contains($wanted)) { $found.Add($wanted) }
                }
            }
        }
    } finally {
        $zip.Dispose()
    }
    return , $found.ToArray()
}

# Replaces files of the ghost with new ones, runs the dictionary check, and puts the old files back (a file that did not
# exist is deleted) when a file could not be replaced or the check found errors. $Items: objects with Old (the path in
# the ghost), New (the path of the new file) and Exists (whether Old exists now). $Check: a scriptblock that returns the
# exit code of the check and gets $CheckArgument as its arguments (not a closure: GetNewClosure fails in a script that
# has parameters with validation attributes), or $null for no check. Returns Status ('replaced', 'copy-failed' or
# 'check-failed'), Failed (the item that could not be copied, or $null), Error (its message) and CheckCode (the exit
# code of the check, or $null). The files are restored before it returns; the caller writes the messages.
function Install-DevkitFiles {
    param([object[]]$Items, [string]$WorkDir, [scriptblock]$Check, [object[]]$CheckArgument = @())
    $done = New-Object System.Collections.Generic.List[object]
    $result = [pscustomobject]@{ Status = 'replaced'; Failed = $null; Error = $null; CheckCode = $null }
    foreach ($item in $Items) {
        $backup = Join-Path $WorkDir ("old-$($done.Count)-" + (Split-Path $item.Old -Leaf))
        try {
            if ($item.Exists) { Copy-Item -LiteralPath $item.Old -Destination $backup -Force }
            New-Item -ItemType Directory -Force -Path (Split-Path $item.Old -Parent) | Out-Null
            Copy-Item -LiteralPath $item.New -Destination $item.Old -Force
            $done.Add([pscustomobject]@{ Item = $item; Backup = $backup })
        } catch {
            $result.Status = 'copy-failed'
            $result.Failed = $item
            $result.Error = $_.Exception.Message
            break
        }
    }
    if ($result.Status -eq 'replaced' -and $Check) {
        $result.CheckCode = & $Check @CheckArgument
        if ($result.CheckCode -eq 1) { $result.Status = 'check-failed' }
    }
    if ($result.Status -ne 'replaced') {
        foreach ($entry in $done) {
            if ($entry.Item.Exists) { Copy-Item -LiteralPath $entry.Backup -Destination $entry.Item.Old -Force }
            else { Remove-Item -LiteralPath $entry.Item.Old -Force -ErrorAction SilentlyContinue }
        }
    }
    return $result
}
