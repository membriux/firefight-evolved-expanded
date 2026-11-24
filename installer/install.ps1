# =====================================================================================
#  install.ps1 - Firefight Reinforcements installer for Halo: MCC on Windows
#
#  Launched by INSTALL.bat. Needs no administrator rights, writes no registry keys,
#  and deletes nothing that was already on the machine.
#
#  Default mode registers the mod with MCC's mod manifest. The -DirectCopy switch
#  instead overwrites the stock .map caches in the game folder, which is the older
#  mechanism this project's notes describe; it always takes a backup first and always
#  asks before overwriting.
#
#  NOTHING IN THIS PACKAGE HAS BEEN RUN IN RETAIL MCC. Read INSTALL.txt first.
# =====================================================================================
[CmdletBinding()]
param(
    # Where the mod folders are copied to. Under LOCALAPPDATA so no admin rights are needed.
    [string] $InstallRoot = (Join-Path $env:LOCALAPPDATA 'HaloFirefightMods'),
    # Set this to skip the Steam library search, e.g. -MccPath 'I:\SteamLibrary\steamapps\common\Halo The Master Chief Collection'
    [string] $MccPath = '',
    # Overwrite the stock .map files in the game folder instead of using the manifest.
    [switch] $DirectCopy
)

$ErrorActionPreference = 'Stop'
$script:PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ModFolders  = @('Firefight-Reinforcements', 'Firefight-Reinforcements-Safe')
$script:ManifestDir = Join-Path $env:USERPROFILE 'AppData\LocalLow\MCC\Config'
$script:Manifest    = Join-Path $script:ManifestDir 'ModManifest.txt'
# The receipt is written OUTSIDE the install root as well as inside it, so that
# UNINSTALL.bat can still find it after the install root has been deleted, and so a
# second install run cannot lose the record of what the first run created.
$script:ReceiptOuter = Join-Path $env:LOCALAPPDATA 'ffee-install-receipt.json'
$script:StateFile    = Join-Path $InstallRoot '.ffee-install-receipt.json'
# Filled in by Capture-Preflight before anything on disk is modified.
$script:Pre = @{}

function Say    { param($m) Write-Host $m }
function Step   { param($m) Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }
function Note   { param($m) Write-Host "   $m" }
function Path_  { param($m) Write-Host "   path: $m" -ForegroundColor DarkGray }
function Good   { param($m) Write-Host "   PASS  $m" -ForegroundColor Green }
function Bad    { param($m) Write-Host "   FAIL  $m" -ForegroundColor Red }

function Stop-Loudly {
    param([string] $What, [string] $Why, [string] $WhatToDo)
    Write-Host ''
    Write-Host '-----------------------------------------------------------------' -ForegroundColor Red
    Write-Host "STOPPED: $What" -ForegroundColor Red
    Write-Host "Reason : $Why"
    if ($WhatToDo) { Write-Host "Do this: $WhatToDo" }
    Write-Host 'Nothing further has been changed.' -ForegroundColor Red
    Write-Host '-----------------------------------------------------------------' -ForegroundColor Red
    exit 1
}

function Get-Sha256 {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant() }
    catch { return $null }
}

# ---------------------------------------------------------------- preflight receipt
# Records the exact pre-install state of everything this script may modify, BEFORE it
# modifies any of it, and merges in anything a previous run recorded so that re-running
# the installer can never erase the record the uninstaller depends on.
function Capture-Preflight {
    param([string] $Root, [string] $Mcc)
    Step 'Recording the pre-install state'

    $prior = $null
    foreach ($c in @($script:ReceiptOuter, (Join-Path $Root '.ffee-install-receipt.json'), (Join-Path $Root '.ffee-install-state.json'))) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            try { $prior = Get-Content -Raw -LiteralPath $c | ConvertFrom-Json; Note "found an earlier receipt at $c"; break } catch { }
        }
    }

    $manifestExisted = Test-Path -LiteralPath $script:Manifest
    $b64 = $null; $hash = $null
    if ($manifestExisted) {
        $bytes = [System.IO.File]::ReadAllBytes($script:Manifest)
        $b64   = [System.Convert]::ToBase64String($bytes)
        $hash  = Get-Sha256 $script:Manifest
        Note "ModManifest.txt exists, $($bytes.Length) bytes; a verbatim copy is kept in the receipt"
    } else {
        Note 'ModManifest.txt does not exist yet'
    }
    # If an earlier run already captured a pre-install manifest, that one is the true
    # "before" state. Never overwrite it with a manifest we have already edited.
    if ($prior -and $prior.ManifestBefore_Base64) {
        $b64             = $prior.ManifestBefore_Base64
        $hash            = $prior.ManifestBefore_Sha256
        $manifestExisted = [bool]$prior.ManifestExistedBefore
        Note 'kept the ORIGINAL pre-install manifest copy from the earlier receipt'
    }

    $binPath = Join-Path $Mcc 'haloreach\game_variants\Firefight Evolved.bin'
    $binPre  = Test-Path -LiteralPath $binPath
    $binHash = if ($binPre) { Get-Sha256 $binPath } else { $null }
    if ($prior -and ($null -ne $prior.GameVariantPreexisted)) {
        $binPre  = [bool]$prior.GameVariantPreexisted
        if ($prior.GameVariantPreexisted_Sha256) { $binHash = $prior.GameVariantPreexisted_Sha256 }
        Note 'kept the earlier receipt''s record of whether your .bin pre-existed'
    }
    if ($binPre) {
        $shown = if ($binHash) { $binHash.Substring(0, 16) + '...' } else { 'unreadable' }
        Note "your Firefight Evolved.bin is already present (sha256 $shown)"
    }
    else { Note 'no Firefight Evolved.bin in the game folder yet' }

    $script:Pre = @{
        Prior                       = $prior
        ManifestExistedBefore       = $manifestExisted
        ManifestBefore_Base64       = $b64
        ManifestBefore_Sha256       = $hash
        GameVariantPreexisted       = $binPre
        GameVariantPreexisted_Sha256 = $binHash
    }
    Good 'pre-install state recorded'
}

function Write-Receipt {
    param([hashtable] $Data)
    $json = $Data | ConvertTo-Json -Depth 5
    foreach ($p in @($script:ReceiptOuter, $script:StateFile)) {
        try {
            $dir = Split-Path -Parent $p
            if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            [System.IO.File]::WriteAllText($p, $json, (New-Object System.Text.UTF8Encoding($false)))
        } catch { Note "could not write the receipt to $p : $($_.Exception.Message)" }
    }
}

# ---------------------------------------------------------------- Steam / MCC lookup
function Get-SteamRoot {
    # The registry is the normal place to find Steam, but this script does not write
    # the registry and only reads it; if the read fails the common paths are probed.
    $candidates = @()
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        try {
            $v = (Get-ItemProperty -Path $key -ErrorAction Stop).SteamPath
            if ($v) { $candidates += $v.Replace('/', '\') }
        } catch { }
    }
    $candidates += @("${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam", 'C:\Steam')
    foreach ($c in $candidates) {
        if ($c -and (Test-Path (Join-Path $c 'steamapps'))) { return $c }
    }
    return $null
}

function Get-SteamLibraries {
    param([string] $SteamRoot)
    $libs = New-Object System.Collections.Generic.List[string]
    if ($SteamRoot) { $libs.Add((Join-Path $SteamRoot 'steamapps')) }
    foreach ($vdfName in @('libraryfolders.vdf', 'LibraryFolders.vdf')) {
        $vdf = if ($SteamRoot) { Join-Path (Join-Path $SteamRoot 'steamapps') $vdfName } else { $null }
        if ($vdf -and (Test-Path $vdf)) {
            Path_ $vdf
            # Both the old ("1" "D:\\Games") and new ("path" "D:\\Games") shapes.
            foreach ($m in [regex]::Matches((Get-Content -Raw $vdf), '"(?:path|\d+)"\s+"([^"]+)"')) {
                $p = $m.Groups[1].Value.Replace('\\', '\')
                $sa = Join-Path $p 'steamapps'
                if (Test-Path $sa) { $libs.Add($sa) }
            }
        }
    }
    # Any fixed drive is worth a look: his library is on I:, not C:.
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null })) {
        foreach ($guess in @('SteamLibrary\steamapps', 'Steam\steamapps', 'Games\SteamLibrary\steamapps')) {
            $sa = Join-Path $d.Root $guess
            if (Test-Path $sa) { $libs.Add($sa) }
        }
    }
    return ($libs | Select-Object -Unique)
}

function Find-Mcc {
    Step 'Locating Halo: The Master Chief Collection'
    if ($MccPath) {
        Path_ $MccPath
        if (Test-Path (Join-Path $MccPath 'haloreach')) { Good "MCC given on the command line"; return $MccPath }
        Stop-Loudly 'the -MccPath you passed is not an MCC install' `
                    "no 'haloreach' folder under $MccPath" `
                    'pass the folder that CONTAINS haloreach, e.g. ...\steamapps\common\Halo The Master Chief Collection'
    }
    $steam = Get-SteamRoot
    if ($steam) { Note "Steam: $steam" } else { Note 'Steam root not found in the registry; probing drives instead.' }
    foreach ($sa in (Get-SteamLibraries $steam)) {
        $mcc = Join-Path $sa 'common\Halo The Master Chief Collection'
        if (Test-Path (Join-Path $mcc 'haloreach')) { Good "found $mcc"; return $mcc }
    }
    Write-Host ''
    Write-Host 'Could not find MCC automatically.' -ForegroundColor Yellow
    Write-Host 'Type the full path to the folder that contains "haloreach", for example:'
    Write-Host '   I:\SteamLibrary\steamapps\common\Halo The Master Chief Collection'
    $typed = Read-Host 'MCC folder'
    if (-not $typed) { Stop-Loudly 'no MCC path given' 'the prompt was left empty' 'run INSTALL.bat again and type the path' }
    $typed = $typed.Trim('"').Trim()
    if (-not (Test-Path (Join-Path $typed 'haloreach'))) {
        Stop-Loudly 'that path is not an MCC install' "no 'haloreach' folder under $typed" `
                    'check the path in Steam: right-click MCC, Manage, Browse local files'
    }
    Good "using $typed"
    return $typed
}

# ---------------------------------------------------------------- preflight
function Get-FolderSize {
    param([string] $Path)
    (Get-ChildItem -LiteralPath $Path -Recurse -File | Measure-Object -Sum Length).Sum
}

function Assert-Space {
    param([string] $TargetPath, [long] $Needed, [string] $What)
    # Derive the drive letter from the string, not from Resolve-Path: the target
    # folder may not exist yet, and resolving a missing path would throw.
    $letter = ''
    if ($TargetPath -match '^([A-Za-z]):') { $letter = $Matches[1] }
    if (-not $letter) { Note "could not tell which drive $TargetPath is on; skipping the space check"; return }
    $drive = "${letter}:"
    try {
        $free = (Get-PSDrive -Name $letter -ErrorAction Stop).Free
    } catch { Note "could not read free space on $drive; continuing"; return }
    if ($null -eq $free) { Note "free space on $drive is not reported; continuing"; return }
    $needGiB = [math]::Round($Needed / 1GB, 2)
    $freeGiB = [math]::Round($free / 1GB, 2)
    Note "$What needs $needGiB GiB; drive $drive has $freeGiB GiB free"
    if ($free -lt ($Needed + 200MB)) {
        Stop-Loudly 'not enough free disk space' `
                    "$What needs about $needGiB GiB plus headroom, but $drive has only $freeGiB GiB free" `
                    "free up space on $drive, or re-run with -InstallRoot pointing at a roomier drive"
    }
}

# ---------------------------------------------------------------- copy the mod folders
function Copy-ModFolders {
    param([string] $Root)
    Step 'Copying the mod folders'
    Path_ $Root
    $total = 0L
    foreach ($f in $script:ModFolders) {
        $src = Join-Path $script:PackageRoot $f
        if (-not (Test-Path $src)) {
            Stop-Loudly 'the package is incomplete' "folder '$f' is missing from $script:PackageRoot" `
                        'unzip the whole archive again, keeping the folder structure'
        }
        $total += Get-FolderSize $src
    }
    Assert-Space -TargetPath $Root -Needed $total -What 'the mod folders'

    $created = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path $Root)) {
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        $created.Add($Root)
        Note "created $Root"
    } else {
        Note "$Root already exists; it will not be deleted by UNINSTALL.bat"
    }
    foreach ($f in $script:ModFolders) {
        $src = Join-Path $script:PackageRoot $f
        $dst = Join-Path $Root $f
        Path_ $dst
        $existed = Test-Path $dst
        try {
            # Copy the CONTENTS into an explicit destination. Copy-Item -Recurse at a
            # folder that already exists would otherwise nest it one level deeper.
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
            Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force -ErrorAction Stop
        } catch {
            Stop-Loudly 'a file copy failed' $_.Exception.Message `
                        'check free space and that no antivirus is locking the folder, then re-run INSTALL.bat'
        }
        if (-not $existed) { $created.Add($dst) }
        Good "copied $f"
    }
    return $created
}

# ---------------------------------------------------------------- the mod manifest
function Register-Manifest {
    param([string] $Root)
    Step 'Registering the mod with MCC'
    Path_ $script:Manifest
    $line = $Root.TrimEnd('\')
    if (-not (Test-Path $script:ManifestDir)) {
        New-Item -ItemType Directory -Path $script:ManifestDir -Force | Out-Null
        Note "created $script:ManifestDir"
    }
    $existing = @()
    if (Test-Path $script:Manifest) {
        $bak = "$script:Manifest.bak"
        Path_ $bak
        # Take the .bak ONCE, and never again. On a second install run the live manifest
        # already contains our line, so copying over the .bak would turn the "pre-install
        # backup" into a post-install one and make a later restore put our line back.
        if (Test-Path -LiteralPath $bak) {
            Note 'a pre-install backup already exists; keeping it untouched (it is the real "before")'
        } else {
            Copy-Item -LiteralPath $script:Manifest -Destination $bak -Force
            Note 'backed the manifest up before touching it'
        }
        $existing = @(Get-Content -LiteralPath $script:Manifest | ForEach-Object { $_.TrimEnd() })
    } else {
        Note 'no manifest yet; creating one'
    }
    if ($existing -contains $line) {
        Good "already registered, not added twice: $line"
        return $false
    }
    $out = @($existing | Where-Object { $_ -ne '' }) + $line
    # MCC's manifest is a CRLF file, one mod-root path per line.
    [System.IO.File]::WriteAllText($script:Manifest,
        (($out -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    Good "added one line: $line"
    return $true
}

# ---------------------------------------------------------------- the game variant
function Copy-GameVariant {
    param([string] $Mcc)
    Step 'Copying the Firefight Evolved game variant'
    $dstDir = Join-Path $Mcc 'haloreach\game_variants'
    Path_ $dstDir
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        Note "created $dstDir"
    }
    $src = Join-Path $script:PackageRoot 'Firefight-Reinforcements\haloreach\game_variants\Firefight Evolved.bin'
    if (-not (Test-Path $src)) {
        Stop-Loudly 'the package is incomplete' "missing $src" 'unzip the whole archive again'
    }
    $dst = Join-Path $dstDir 'Firefight Evolved.bin'
    Path_ $dst
    $script:BinOverwritten = $false
    $script:BinBackup      = $null
    $script:BinBackupHash  = $null
    if (Test-Path $dst) {
        $hSrc = Get-Sha256 $src
        $hDst = Get-Sha256 $dst
        if ($hSrc -and $hDst -and ($hSrc -eq $hDst)) {
            # This is the normal case on this machine: our .bin is byte-identical to the
            # author's. Nothing to do, and nothing to put at risk.
            Good 'the .bin already there is byte-identical to ours; left it completely alone'
            return $false
        }
        Write-Host '   A DIFFERENT "Firefight Evolved.bin" is already there.' -ForegroundColor Yellow
        Write-Host "      yours : sha256 $hDst" -ForegroundColor Yellow
        Write-Host "      ours  : sha256 $hSrc" -ForegroundColor Yellow
        Write-Host '   That file is probably the mod author''s. If you overwrite it, a COPY OF YOURS' -ForegroundColor Yellow
        Write-Host '   is saved first as "Firefight Evolved.bin.ffee-bak" and UNINSTALL.bat puts it back.' -ForegroundColor Yellow
        Write-Host '   If you are unsure, answer anything but YES: keeping yours is the safe choice and' -ForegroundColor Yellow
        Write-Host '   the mod still works, because the gametype only has to exist once.' -ForegroundColor Yellow
        $ans = Read-Host '   Overwrite it? type YES to overwrite, anything else to keep yours'
        if ($ans -ne 'YES') { Note 'kept the existing file'; return $false }
        $bak = "$dst.ffee-bak"
        if (-not (Test-Path -LiteralPath $bak)) {
            try {
                Copy-Item -LiteralPath $dst -Destination $bak -Force -ErrorAction Stop
                Note "saved your original as $bak"
            } catch {
                Stop-Loudly 'could not back up your existing game variant' $_.Exception.Message `
                            'nothing was overwritten; free up space or close MCC and re-run'
            }
        } else {
            Note "a backup of your original already exists at $bak; keeping it"
        }
        $script:BinBackup     = $bak
        $script:BinBackupHash = Get-Sha256 $bak
        $script:BinOverwritten = $true
    }
    try { Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop }
    catch { Stop-Loudly 'could not copy the game variant' $_.Exception.Message 'close MCC and re-run INSTALL.bat' }
    Good 'game variant in place'
    return $true
}

# ---------------------------------------------------------------- optional direct copy
function Copy-MapsDirect {
    param([string] $Mcc)
    Step 'DIRECT COPY: overwriting the stock .map caches'
    $mapsDir = Join-Path $Mcc 'haloreach\maps'
    Path_ $mapsDir
    if (-not (Test-Path $mapsDir)) {
        Stop-Loudly 'the game maps folder is missing' "no $mapsDir" 'verify the MCC install in Steam'
    }
    $src = Join-Path $script:PackageRoot 'Firefight-Reinforcements\maps'
    $files = Get-ChildItem -LiteralPath $src -File -Filter *.map
    Write-Host ''
    Write-Host 'This will replace these stock game files:' -ForegroundColor Yellow
    foreach ($f in $files) { Write-Host "   $(Join-Path $mapsDir $f.Name)" }
    Write-Host 'A copy of each original will be saved next to it with a .stockbak extension.' -ForegroundColor Yellow
    Write-Host 'Verifying the game files in Steam undoes all of it.' -ForegroundColor Yellow
    $ans = Read-Host 'Type REPLACE to go ahead, anything else to cancel'
    if ($ans -ne 'REPLACE') { Note 'cancelled; nothing was changed'; return }
    Assert-Space -TargetPath $mapsDir -Needed ((Get-FolderSize $src) * 2) -What 'the maps plus their backups'
    foreach ($f in $files) {
        $dst = Join-Path $mapsDir $f.Name
        $bak = "$dst.stockbak"
        if ((Test-Path $dst) -and -not (Test-Path $bak)) {
            Path_ $bak
            Copy-Item -LiteralPath $dst -Destination $bak -Force
            Note "backed up $($f.Name)"
        }
        Path_ $dst
        try { Copy-Item -LiteralPath $f.FullName -Destination $dst -Force -ErrorAction Stop }
        catch { Stop-Loudly "could not write $($f.Name)" $_.Exception.Message 'close MCC and re-run' }
        Good "replaced $($f.Name)"
    }
    Note 'Unearthed was installed from the six-Marine variant. To use the safe one instead, copy'
    Note "Firefight-Reinforcements-Safe\maps\ff_unearthed.map over $mapsDir\ff_unearthed.map yourself."
}

# ---------------------------------------------------------------- verification
function Verify-Install {
    param([string] $Root, [string] $Mcc, [bool] $Direct)
    Step 'Verifying what is actually on disk'
    $ok = $true
    foreach ($f in $script:ModFolders) {
        foreach ($rel in @('ModInfo.json', 'maps', 'firefight', 'images')) {
            $p = Join-Path (Join-Path $Root $f) $rel
            if (Test-Path $p) { Good "$f\$rel" } else { Bad "$f\$rel is missing"; $ok = $false }
        }
        $n = (Get-ChildItem -LiteralPath (Join-Path (Join-Path $Root $f) 'maps') -File -Filter *.map -ErrorAction SilentlyContinue).Count
        if ($n -gt 0) { Good "$f has $n .map file(s)" } else { Bad "$f has no .map files"; $ok = $false }
    }
    if (Test-Path $script:Manifest) {
        $has = (Get-Content -LiteralPath $script:Manifest | ForEach-Object { $_.TrimEnd() }) -contains $Root.TrimEnd('\')
        if ($has) { Good 'the mod root is listed in ModManifest.txt exactly once per line' }
        else { Bad 'ModManifest.txt does not list the mod root'; $ok = $false }
    } else { Bad 'ModManifest.txt was not created'; $ok = $false }
    $bin = Join-Path $Mcc 'haloreach\game_variants\Firefight Evolved.bin'
    if (Test-Path $bin) { Good 'Firefight Evolved.bin is in the game variants folder' }
    else { Bad "missing $bin"; $ok = $false }
    if ($Direct) {
        $mapsDir = Join-Path $Mcc 'haloreach\maps'
        foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $script:PackageRoot 'Firefight-Reinforcements\maps') -File -Filter *.map)) {
            $dst = Join-Path $mapsDir $f.Name
            if ((Test-Path $dst) -and ((Get-Item $dst).Length -eq $f.Length)) { Good "game file $($f.Name) matches" }
            else { Bad "game file $($f.Name) is not the modded one"; $ok = $false }
        }
    }
    return $ok
}

# ---------------------------------------------------------------- main
Write-Host ''
Write-Host 'Firefight Reinforcements - installer' -ForegroundColor White
Write-Host 'Nothing in this package has ever been run in retail MCC. Read INSTALL.txt.' -ForegroundColor Yellow
Path_ $script:PackageRoot

$mcc = Find-Mcc

# Record everything we might change BEFORE changing any of it. The receipt is written
# immediately, so even a crash halfway through leaves the uninstaller something to work
# from.
Capture-Preflight -Root $InstallRoot -Mcc $mcc
Write-Receipt @{
    InstallRoot                  = $InstallRoot
    MccPath                      = $mcc
    ManifestLine                 = $InstallRoot.TrimEnd('\')
    CreatedFolders               = @()
    Incomplete                   = $true
    ManifestExistedBefore        = $script:Pre.ManifestExistedBefore
    ManifestBefore_Base64        = $script:Pre.ManifestBefore_Base64
    ManifestBefore_Sha256        = $script:Pre.ManifestBefore_Sha256
    GameVariantPreexisted        = $script:Pre.GameVariantPreexisted
    GameVariantPreexisted_Sha256 = $script:Pre.GameVariantPreexisted_Sha256
    DirectCopy                   = $DirectCopy.IsPresent
    When                         = (Get-Date).ToString('s')
}

$created = Copy-ModFolders -Root $InstallRoot
$added = Register-Manifest -Root $InstallRoot
Copy-GameVariant -Mcc $mcc | Out-Null
if ($DirectCopy) { Copy-MapsDirect -Mcc $mcc }

# The final receipt, so UNINSTALL.bat removes only what was actually created.
# CreatedFolders is the UNION of this run and every earlier run: on a second install
# nothing new is created, and forgetting the first run's folders would leave the
# uninstaller with nothing to delete.
$priorCreated = @()
if ($script:Pre.Prior -and $script:Pre.Prior.CreatedFolders) {
    $priorCreated = @($script:Pre.Prior.CreatedFolders | Where-Object { $_ })
}
$allCreated = @(@($priorCreated) + @($created) | Where-Object { $_ } | Select-Object -Unique)

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
Write-Receipt @{
    InstallRoot                  = $InstallRoot
    MccPath                      = $mcc
    ManifestLine                 = $InstallRoot.TrimEnd('\')
    CreatedFolders               = $allCreated
    Incomplete                   = $false
    AddedManifest                = $added
    ManifestExistedBefore        = $script:Pre.ManifestExistedBefore
    ManifestBefore_Base64        = $script:Pre.ManifestBefore_Base64
    ManifestBefore_Sha256        = $script:Pre.ManifestBefore_Sha256
    GameVariantPreexisted        = $script:Pre.GameVariantPreexisted
    GameVariantPreexisted_Sha256 = $script:Pre.GameVariantPreexisted_Sha256
    GameVariantOverwritten       = [bool]$script:BinOverwritten
    GameVariantBackup            = $script:BinBackup
    GameVariantBackup_Sha256     = $script:BinBackupHash
    GameVariantInstalled_Sha256  = (Get-Sha256 (Join-Path $script:PackageRoot 'Firefight-Reinforcements\haloreach\game_variants\Firefight Evolved.bin'))
    DirectCopy                   = $DirectCopy.IsPresent
    When                         = (Get-Date).ToString('s')
}
Note "revert receipt: $script:ReceiptOuter"

$ok = Verify-Install -Root $InstallRoot -Mcc $mcc -Direct:$DirectCopy.IsPresent

Write-Host ''
if ($ok) {
    Write-Host 'INSTALL COMPLETE - every check above passed.' -ForegroundColor Green
} else {
    Write-Host 'INSTALL INCOMPLETE - see the FAIL lines above. Fix those before playing.' -ForegroundColor Red
}
Write-Host ''
Write-Host 'IF ANYTHING GOES WRONG, THIS UNDOES IT:' -ForegroundColor White
Write-Host '  UNINSTALL.bat            shows what it would undo, changes nothing'
Write-Host '  UNINSTALL.bat -Apply     actually undoes it, then verifies'
Write-Host '  It does NOT touch your Workshop mod, your maps, or your game files.'
Write-Host '  Do NOT use Steam "Verify integrity of game files" to undo this: it would' -ForegroundColor Yellow
Write-Host '  overwrite your author-modified ff_unearthed.map with the stock one.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'THREE THINGS ONLY YOU CAN DO:' -ForegroundColor White
Write-Host '  1. Launch the game with "Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)".'
Write-Host '     In Steam, right-click MCC, Play, and pick that entry. The normal Play button will not load mods.'
Write-Host '  2. Choose the gametype FIREFIGHT EVOLVED. Without it the shop scripts never start.'
Write-Host '  3. Find the shop. On Unearthed, walk to the author''s terminals in Facility Interior and HOLD E.'
Write-Host '     On every other map, just walk up to a health station - there is no key press, and the'
Write-Host '     distance you need to be inside differs per map. INSTALL.txt lists it map by map.'
Write-Host ''
if (-not $ok) { exit 1 }
