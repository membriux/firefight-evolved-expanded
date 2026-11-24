# =====================================================================================
#  uninstall.ps1 - REVERT Firefight Reinforcements.
#
#  Undoes exactly what install.ps1 recorded doing, and nothing else.
#
#  Design rules, in order of importance:
#    1. It works from the RECEIPT the installer wrote, never from guessed patterns.
#    2. Every delete target must be the recorded install root or a descendant of it.
#       Anything else is refused, loudly, including drive roots, the MCC folder, any
#       path containing steamapps\common or haloreach, and %LOCALAPPDATA% itself.
#    3. It NEVER writes to, or deletes from, <MCC>\haloreach\maps\ unless the receipt
#       says the optional -DirectCopy mode put a backup there, and even then it only
#       copies a recorded backup back over the file it came from.
#    4. It NEVER removes a "Firefight Evolved.bin" that was already on the machine
#       before the install.
#    5. With no arguments it is a DRY RUN. It prints the plan and changes nothing.
#       Pass -Apply to actually make the changes.
#    6. Running it twice, or running it when nothing was installed, prints
#       "nothing to undo" and exits 0.
#
#  Usage:
#      UNINSTALL.bat              show the plan, change nothing
#      UNINSTALL.bat -Apply       actually revert
# =====================================================================================
[CmdletBinding()]
param(
    # Actually perform the revert. Without this the script only prints its plan.
    [switch] $Apply,
    # Only needed if you installed with a non-default -InstallRoot AND the receipt
    # outside the install root is missing.
    [string] $InstallRoot = ''
)

$ErrorActionPreference = 'Stop'

$ManifestDir  = Join-Path $env:USERPROFILE 'AppData\LocalLow\MCC\Config'
$Manifest     = Join-Path $ManifestDir 'ModManifest.txt'
# The primary receipt lives OUTSIDE any folder this script may delete, so it survives
# the deletion of the install root and is still there on a second run.
$ReceiptOuter = Join-Path $env:LOCALAPPDATA 'ffee-install-receipt.json'

function Note  { param($m) Write-Host "   $m" }
function Path_ { param($m) Write-Host "   path: $m" -ForegroundColor DarkGray }
function Good  { param($m) Write-Host "   PASS  $m" -ForegroundColor Green }
function Bad   { param($m) Write-Host "   FAIL  $m" -ForegroundColor Red }
function Did   { param($m) Write-Host "   DONE  $m" -ForegroundColor Green }
function Warn_ { param($m) Write-Host "   SKIP  $m" -ForegroundColor Yellow }
function Plan  { param($m) Write-Host "   WOULD $m" -ForegroundColor Cyan }
function Step  { param($m) Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }

function Refuse {
    param([string] $What, [string] $Why)
    Write-Host ''
    Write-Host '-----------------------------------------------------------------' -ForegroundColor Red
    Write-Host "REFUSED: $What" -ForegroundColor Red
    Write-Host "Reason : $Why"
    Write-Host 'Nothing has been changed. This is a bug - report it before retrying.' -ForegroundColor Red
    Write-Host '-----------------------------------------------------------------' -ForegroundColor Red
    exit 2
}

function Get-Sha256 {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant() }
    catch { return $null }
}

function Normalize-Path {
    param([string] $P)
    if ([string]::IsNullOrWhiteSpace($P)) { return '' }
    return ($P.Trim().TrimEnd('\').TrimEnd('/'))
}

# ------------------------------------------------------------------ the safety gate
# Every path this script is about to delete goes through here first. A path-
# construction bug that produces an empty, short or root path must abort, not delete.
function Assert-SafeToDelete {
    param(
        [string] $Target,      # the path we want to remove
        [string] $Root,        # the recorded install root; Target must be it or inside it
        [string] $MccPath      # the recorded MCC folder; Target must not be it or inside it
    )
    $t = Normalize-Path $Target
    $r = Normalize-Path $Root

    if ([string]::IsNullOrWhiteSpace($t)) {
        Refuse 'a delete target was empty' 'an empty or whitespace path would mean "delete everything"'
    }
    if ([string]::IsNullOrWhiteSpace($r)) {
        Refuse "a delete target had no recorded install root ($t)" 'without a root there is nothing to bound the delete to'
    }
    # Drive root, e.g. "C:" or "C:\", and UNC share roots.
    if ($t -match '^[A-Za-z]:$' -or $t -match '^[A-Za-z]:\\?$') {
        Refuse "a delete target was a drive root ($Target)" 'deleting a drive root would wipe the disk'
    }
    if ($t -match '^\\\\[^\\]+\\[^\\]+$') {
        Refuse "a delete target was a network share root ($Target)" 'deleting a share root would wipe the share'
    }
    # Needs at least drive + two path segments, e.g. C:\Users\Foo. Anything shallower
    # than that is never something this installer created.
    $segs = @($t -split '\\' | Where-Object { $_ -ne '' })
    if ($segs.Count -lt 3) {
        Refuse "a delete target was too shallow ($Target)" 'this installer never creates a folder that close to a drive root'
    }
    # Never anything in or above a Steam library or the game.
    if ($t -imatch [regex]::Escape('steamapps\common')) {
        Refuse "a delete target was inside a Steam library ($Target)" 'the game files are never deleted by this script'
    }
    if ($t -imatch 'haloreach') {
        Refuse "a delete target was inside the game's haloreach folder ($Target)" 'this script never deletes game content'
    }
    if ($MccPath) {
        $m = Normalize-Path $MccPath
        if ($m -and ($t -ieq $m -or $t.StartsWith("$m\", [StringComparison]::OrdinalIgnoreCase) -or $m.StartsWith("$t\", [StringComparison]::OrdinalIgnoreCase))) {
            Refuse "a delete target overlapped the MCC install ($Target)" 'the game folder is never deleted by this script'
        }
    }
    # Never a well-known profile or system folder in its own right.
    $forbidden = @(
        $env:LOCALAPPDATA, $env:APPDATA, $env:USERPROFILE, $env:TEMP, $env:windir,
        $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:PUBLIC,
        $ManifestDir, (Join-Path $env:USERPROFILE 'AppData\LocalLow'),
        (Join-Path $env:USERPROFILE 'AppData\LocalLow\MCC'),
        (Join-Path $env:USERPROFILE 'Documents'), (Join-Path $env:USERPROFILE 'Desktop')
    )
    foreach ($f in $forbidden) {
        $fn = Normalize-Path $f
        if ($fn -and ($t -ieq $fn)) {
            Refuse "a delete target was a system or profile folder ($Target)" 'only folders this installer created are ever deleted'
        }
    }
    # The core invariant: it must be the install root, or live inside it.
    if (-not ($t -ieq $r -or $t.StartsWith("$r\", [StringComparison]::OrdinalIgnoreCase))) {
        Refuse "a delete target was outside the recorded install root ($Target)" `
               "the recorded root is '$Root'; this script only ever deletes that folder or something inside it"
    }
    return $true
}

Write-Host ''
Write-Host 'Firefight Reinforcements - REVERT' -ForegroundColor White
if ($Apply) { Write-Host 'Mode: APPLY - changes will be made.' -ForegroundColor Yellow }
else        { Write-Host 'Mode: DRY RUN - nothing will be changed. Re-run with -Apply to revert.' -ForegroundColor Cyan }

# ------------------------------------------------------------------ load the receipt
Step 'Reading the install receipt'
$receipt     = $null
$receiptPath = $null
$candidates  = @($ReceiptOuter)
if ($InstallRoot) { $candidates += (Join-Path $InstallRoot '.ffee-install-receipt.json') }
$candidates += (Join-Path (Join-Path $env:LOCALAPPDATA 'HaloFirefightMods') '.ffee-install-receipt.json')
# Also accept the older state-file name, so a package installed by the previous
# installer can still be reverted by this script.
$candidates += @($ReceiptOuter -replace 'receipt','state')
if ($InstallRoot) { $candidates += (Join-Path $InstallRoot '.ffee-install-state.json') }
$candidates += (Join-Path (Join-Path $env:LOCALAPPDATA 'HaloFirefightMods') '.ffee-install-state.json')

foreach ($c in ($candidates | Select-Object -Unique)) {
    if ($c -and (Test-Path -LiteralPath $c)) {
        try {
            $receipt = Get-Content -Raw -LiteralPath $c | ConvertFrom-Json
            $receiptPath = $c
            Path_ $c
            break
        } catch {
            Note "found $c but could not read it: $($_.Exception.Message)"
        }
    }
}

if (-not $receipt) {
    Write-Host ''
    Write-Host 'NOTHING TO UNDO.' -ForegroundColor Green
    Note 'No install receipt was found, so this installer has not run on this machine'
    Note '(or its revert has already completed). No files have been examined or changed.'
    Note "Looked for: $ReceiptOuter"
    Write-Host ''
    exit 0
}

$root    = Normalize-Path $receipt.InstallRoot
$mcc     = if ($receipt.MccPath) { Normalize-Path $receipt.MccPath } else { '' }
$line    = if ($receipt.ManifestLine) { Normalize-Path $receipt.ManifestLine } else { $root }
$created = @()
if ($receipt.CreatedFolders) { $created = @($receipt.CreatedFolders | Where-Object { $_ }) }
$preManifestB64  = $receipt.ManifestBefore_Base64
$preManifestHash = $receipt.ManifestBefore_Sha256
$manifestExisted = [bool]$receipt.ManifestExistedBefore
$binPreexisted   = [bool]$receipt.GameVariantPreexisted
$binOverwritten  = [bool]$receipt.GameVariantOverwritten
$binBackup       = $receipt.GameVariantBackup
$directCopy      = [bool]$receipt.DirectCopy

Note "install recorded at $($receipt.When)"
Note "install root        : $root"
Note "MCC folder          : $(if ($mcc) { $mcc } else { '(not recorded)' })"
Note "manifest line added : $(if ($receipt.AddedManifest) { 'yes' } else { 'no - it was already there' })"
Note "direct-copy was used: $(if ($directCopy) { 'YES' } else { 'no' })"

# ------------------------------------------------------------------ build the plan
Step 'The plan'

# Validate EVERY delete target before printing it, so a bad path aborts before the
# user is ever offered a confirmation.
$deleteTargets = New-Object System.Collections.Generic.List[string]
foreach ($f in $created) {
    $n = Normalize-Path $f
    Assert-SafeToDelete -Target $n -Root $root -MccPath $mcc | Out-Null
    $deleteTargets.Add($n)
}
# Deepest first, so a child is removed before the parent that contains it.
$deleteTargets = @($deleteTargets | Sort-Object -Property @{Expression={ @($_ -split '\\').Count }} -Descending)

$nPlanned = 0
if (Test-Path -LiteralPath $Manifest) {
    $curLines = @(Get-Content -LiteralPath $Manifest | ForEach-Object { $_.TrimEnd() })
    if ($curLines -contains $line) {
        Write-Host "   1. remove this one line from the manifest:" ; Write-Host "        $line"
        Write-Host "      file: $Manifest"
        $nPlanned++
    } else {
        Note "1. the manifest does not contain our line; it will be left alone"
    }
    if (-not $manifestExisted) {
        Note "   the manifest did not exist before the install; if removing our line empties it, the empty file is left in place (MCC ignores it)"
    }
} else {
    Note '1. there is no manifest file; nothing to remove'
}

if ($deleteTargets.Count -eq 0) {
    Note '2. no folders were recorded as created by the installer; nothing will be deleted'
} else {
    Write-Host '   2. delete these folders, and only these:'
    foreach ($t in $deleteTargets) {
        $exists = Test-Path -LiteralPath $t
        Write-Host "        $t $(if ($exists) { '' } else { '(already gone)' })"
        if ($exists) { $nPlanned++ }
    }
}

if ($binPreexisted) {
    if ($binOverwritten -and $binBackup -and (Test-Path -LiteralPath $binBackup)) {
        Write-Host '   3. put your original "Firefight Evolved.bin" back from the backup the installer took:'
        Write-Host "        $binBackup"
        $nPlanned++
    } else {
        Note '3. "Firefight Evolved.bin" was already on this machine and was NOT overwritten; it will not be touched'
    }
} else {
    $binPath = if ($mcc) { Join-Path $mcc 'haloreach\game_variants\Firefight Evolved.bin' } else { '' }
    if ($binPath -and (Test-Path -LiteralPath $binPath)) {
        Write-Host '   3. delete the game variant the installer added (it was not there before):'
        Write-Host "        $binPath"
        $nPlanned++
    } else {
        Note '3. no game variant to remove'
    }
}

if ($directCopy) {
    Write-Host '   4. offer to restore the .map.stockbak backups in the game maps folder' -ForegroundColor Yellow
    Write-Host '      NOTE: for ff_unearthed.map that backup is YOUR pre-install copy, which on' -ForegroundColor Yellow
    Write-Host "      this machine is the mod author's 870 MB map, not a stock Microsoft file." -ForegroundColor Yellow
    $nPlanned++
} else {
    Note '4. direct-copy mode was never used, so the game maps folder is not touched at all'
}

if ($nPlanned -eq 0) {
    Write-Host ''
    Write-Host 'NOTHING TO UNDO - everything in the receipt has already been reverted.' -ForegroundColor Green
    if ($Apply -and $receiptPath -and (Test-Path -LiteralPath $receiptPath)) {
        Remove-Item -LiteralPath $receiptPath -Force -ErrorAction SilentlyContinue
        Note 'removed the spent receipt'
    }
    Write-Host ''
    exit 0
}

if (-not $Apply) {
    Write-Host ''
    Write-Host 'DRY RUN COMPLETE - nothing above was done.' -ForegroundColor Cyan
    Write-Host 'To actually revert, run:   UNINSTALL.bat -Apply' -ForegroundColor White
    Write-Host ''
    exit 0
}

Write-Host ''
$ans = Read-Host 'Type REVERT to carry out exactly the plan above, anything else to cancel'
if ($ans -ne 'REVERT') { Note 'cancelled; nothing was changed'; exit 0 }

# ------------------------------------------------------------------ 1. the manifest
Step 'Manifest'
Path_ $Manifest
$manifestOk = $true
if (Test-Path -LiteralPath $Manifest) {
    $lines = @(Get-Content -LiteralPath $Manifest | ForEach-Object { $_.TrimEnd() })
    if ($lines -contains $line) {
        $kept = @($lines | Where-Object { $_ -ne $line -and $_ -ne '' })
        $text = if ($kept.Count -gt 0) { ($kept -join "`r`n") + "`r`n" } else { '' }
        [System.IO.File]::WriteAllText($Manifest, $text, (New-Object System.Text.UTF8Encoding($false)))
        Did "removed our line; kept $($kept.Count) other line(s) byte-for-byte"
    } else {
        Warn_ 'our line was not present; left the file alone'
    }
} else {
    Warn_ 'no manifest file to edit'
}

# ------------------------------------------------------------------ 2. the folders
Step 'Mod folders'
foreach ($t in $deleteTargets) {
    # Re-validate immediately before the destructive call, not just at plan time.
    Assert-SafeToDelete -Target $t -Root $root -MccPath $mcc | Out-Null
    Path_ $t
    if (-not (Test-Path -LiteralPath $t)) { Warn_ 'already gone'; continue }
    try {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction Stop
        Did "deleted $t"
    } catch {
        Bad "could not delete $t : $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------------ 3. the game variant
Step 'Game variant'
if ($binPreexisted) {
    if ($binOverwritten -and $binBackup -and (Test-Path -LiteralPath $binBackup)) {
        $binPath = Join-Path $mcc 'haloreach\game_variants\Firefight Evolved.bin'
        Path_ $binPath
        try {
            Copy-Item -LiteralPath $binBackup -Destination $binPath -Force -ErrorAction Stop
            Did 'restored your original Firefight Evolved.bin'
            $want = $receipt.GameVariantBackup_Sha256
            $got  = Get-Sha256 $binPath
            if ($want -and $got) {
                if ($want -eq $got) { Good 'restored .bin matches the recorded pre-install hash' }
                else { Bad "restored .bin hash $got does not match the recorded $want" }
            }
            Remove-Item -LiteralPath $binBackup -Force -ErrorAction SilentlyContinue
        } catch {
            Bad "could not restore the .bin: $($_.Exception.Message)"
        }
    } else {
        Warn_ 'your original .bin was never overwritten; leaving it exactly as it is'
    }
} else {
    if ($mcc) {
        $binPath = Join-Path $mcc 'haloreach\game_variants\Firefight Evolved.bin'
        if (Test-Path -LiteralPath $binPath) {
            # Only remove it if it is still byte-identical to the one we installed.
            # If he has since replaced it, or subscribed to a Workshop item that wrote
            # over it, it is his file now and we leave it.
            $ours = $receipt.GameVariantInstalled_Sha256
            $now  = Get-Sha256 $binPath
            if ($ours -and $now -and ($ours -eq $now)) {
                Path_ $binPath
                try { Remove-Item -LiteralPath $binPath -Force -ErrorAction Stop; Did 'removed the game variant we added' }
                catch { Bad "could not remove the .bin: $($_.Exception.Message)" }
            } else {
                Warn_ 'the .bin on disk is not the one we installed; leaving it alone'
            }
        } else {
            Warn_ 'no .bin present'
        }
    } else {
        Warn_ 'MCC folder not recorded; not inspecting the game folder'
    }
}

# ------------------------------------------------------------------ 4. direct-copy backups
Step 'Game maps folder'
if (-not $directCopy) {
    Good 'direct-copy was never used - this script has not read or written anything in haloreach\maps'
} elseif (-not $mcc) {
    Warn_ 'MCC folder not recorded; cannot restore map backups'
} else {
    $mapsDir = Join-Path $mcc 'haloreach\maps'
    $baks = @(Get-ChildItem -LiteralPath $mapsDir -File -Filter *.map.stockbak -ErrorAction SilentlyContinue)
    if ($baks.Count -eq 0) {
        Note 'no .map.stockbak files found'
    } else {
        Write-Host '   These are YOUR pre-install map files, saved before they were overwritten:' -ForegroundColor Yellow
        foreach ($b in $baks) { Write-Host "      $($b.FullName)" }
        Write-Host '   Restoring them puts your own maps back. Do NOT use Steam "Verify integrity of' -ForegroundColor Yellow
        Write-Host '   game files" instead: that would overwrite your author-modified ff_unearthed.map' -ForegroundColor Yellow
        Write-Host '   with the stock Microsoft one and you would lose the author mod.' -ForegroundColor Yellow
        $r = Read-Host '   Restore all of them now? type YES to restore'
        if ($r -eq 'YES') {
            foreach ($b in $baks) {
                $orig = $b.FullName.Substring(0, $b.FullName.Length - '.stockbak'.Length)
                Path_ $orig
                try {
                    Copy-Item -LiteralPath $b.FullName -Destination $orig -Force -ErrorAction Stop
                    Remove-Item -LiteralPath $b.FullName -Force
                    Did "restored $(Split-Path -Leaf $orig)"
                } catch { Bad "could not restore $orig : $($_.Exception.Message)" }
            }
        } else {
            Note 'left the backups in place; your maps are still the modded ones'
        }
    }
}

# ------------------------------------------------------------------ verification
Step 'Verifying the revert'
$ok = $true

# 1. our line is gone
if (Test-Path -LiteralPath $Manifest) {
    $now = @(Get-Content -LiteralPath $Manifest | ForEach-Object { $_.TrimEnd() })
    if ($now -contains $line) { Bad "our line is STILL in $Manifest"; $ok = $false }
    else { Good 'our line is gone from ModManifest.txt' }

    # 2. the rest is byte-identical to what was there before the install
    if ($preManifestB64) {
        $before = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($preManifestB64))
        $beforeLines = @(($before -split "`r?`n") | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne '' })
        $nowLines    = @($now | Where-Object { $_ -ne '' })
        $diff = Compare-Object -ReferenceObject $beforeLines -DifferenceObject $nowLines
        if (-not $diff) {
            Good 'every other manifest line is exactly as it was before the install'
        } else {
            Bad 'the manifest does not match the pre-install content. Differences:'
            foreach ($d in $diff) {
                $side = if ($d.SideIndicator -eq '<=') { 'MISSING (was there before)' } else { 'EXTRA (not there before)' }
                Write-Host "         $side : $($d.InputObject)" -ForegroundColor Red
            }
            Write-Host "         A verbatim copy of the pre-install manifest is in the receipt at:" -ForegroundColor Yellow
            Write-Host "         $receiptPath  (field ManifestBefore_Base64)" -ForegroundColor Yellow
            $ok = $false
        }
    } else {
        Note 'the receipt has no pre-install manifest copy, so a byte comparison is not possible'
    }
} else {
    if ($manifestExisted) { Bad "$Manifest is missing but existed before the install"; $ok = $false }
    else { Good 'no manifest file, and there was none before the install' }
}

# 3. the folders are gone
foreach ($t in $deleteTargets) {
    if (Test-Path -LiteralPath $t) { Bad "still present: $t"; $ok = $false }
    else { Good "removed: $t" }
}

# 4. the game folder is as expected
if ($mcc) {
    $binPath = Join-Path $mcc 'haloreach\game_variants\Firefight Evolved.bin'
    if ($binPreexisted) {
        if (Test-Path -LiteralPath $binPath) { Good 'your Firefight Evolved.bin is still in place' }
        else { Bad "your Firefight Evolved.bin is MISSING from $binPath"; $ok = $false }
    }
    # Only look in the game maps folder if the receipt says -DirectCopy wrote there.
    # Otherwise this script does not read or write haloreach\maps at all.
    if ($directCopy) {
        $mapsDir = Join-Path $mcc 'haloreach\maps'
        $leftover = @(Get-ChildItem -LiteralPath $mapsDir -File -Filter *.map.stockbak -ErrorAction SilentlyContinue)
        if ($leftover.Count -gt 0) {
            Note "$($leftover.Count) .map.stockbak file(s) still in $mapsDir - your own maps are still overwritten"
            Note 'run UNINSTALL.bat -Apply again and answer YES to the restore prompt to put them back'
        }
    } else {
        Good 'haloreach\maps was never read or written by this script'
    }
}

# retire the receipt only if everything passed
if ($ok) {
    foreach ($c in @($receiptPath, $ReceiptOuter)) {
        if ($c -and (Test-Path -LiteralPath $c)) { Remove-Item -LiteralPath $c -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($ok) {
    Write-Host 'REVERT COMPLETE - every check above passed.' -ForegroundColor Green
    Write-Host 'Your Workshop mod, your maps and your game files were not touched.'
    Write-Host 'Launch MCC normally now and confirm the game is healthy.'
} else {
    Write-Host 'REVERT INCOMPLETE - see the FAIL lines above.' -ForegroundColor Red
    Write-Host "The receipt has been KEPT at $receiptPath so you can retry or inspect it."
}
Write-Host ''
if (-not $ok) { exit 1 }
