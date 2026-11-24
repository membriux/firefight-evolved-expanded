# 26 — Audit round 1: the INSTALL path, the mod package, and the installer

Adversarial, hostile-code-review audit of what the user is about to run on his own
gaming PC. Date: 2026-11-23.

**Target environment** (not reproducible here — there is no Windows on this machine):

- MCC at `I:\SteamLibrary\steamapps\common\Halo The Master Chief Collection` (not `C:`).
- Steam Workshop item 3453792163, "Halo Reach: Evolved Public Beta", 7.3 GB, already installed.
- `haloreach\maps\ff_unearthed.map` is the author's 870 MB modified map, **not stock**.
- The author's `Firefight Evolved.bin` is already in `haloreach\game_variants\`.
- MCC dashboard shows a "Modded Missions" / "Modded Variants" menu.

**Standing caveat.** Nothing in this package has been executed. There is no Windows and
no PowerShell interpreter on this machine (`pwsh` and `powershell` both absent), so
neither `install.ps1` nor `uninstall.ps1` has ever been parsed, let alone run. Every
verdict below comes from reading the code path character by character plus a structural
lint (brace/paren/bracket balance, no PowerShell-7-only syntax). **A clean static review
is not a passing test run.** Treat first execution as the real test.

---

## 0. Independent re-verification of the install mechanism

Our own `15-workshop-publishing.md:384` called the manifest mechanism
"community-reported … **UNVERIFIED**, not in official docs". That caveat can now be
retired. The mechanism was re-verified from external sources, deliberately ignoring our
own notes and our own repo.

**Primary source found: 343 Industries' own December 2022 MCC update announcement**
(halowaypoint.com/news/halo-mcc-december-2022-update). It states:

- "there is a ModManifest.txt file which MCC will read in EAC-bypass to find mods on
  your computer"
- "Each line in this file relates to a directory"
- "Inside each of those directories MCC will then enumerate all immediate
  subdirectories looking for a ModInfo.json"

That is first-party confirmation of the file, the per-line-is-a-root format, and the
one-level scan depth. Four further independent implementations agree, which is the fourth
source the audit brief asked for and then some:

| Source | What it confirms |
|---|---|
| 343 Waypoint, Dec 2022 | the file, the format, one-level scan, **EAC-off requirement** |
| Microsoft Learn — Excession mod tool docs | "not below the 1st level … the tool will not find them" |
| Nexus Vortex `game-masterchiefcollection/src/common.ts` | exact path `…\LocalLow\MCC\Config\ModManifest.txt` |
| Foundry `cache_builder.py:305` | same path; writes root, mod lives one level in |
| Kalo `MccMod.cs` | same path; "MCC tells mods apart by ModGuid" |
| Vortex issue #13745 attachment | a **real working** `ModManifest.txt`, hex-dumped |
| TagTool `ModInfo.cs` / `FirefightMapInfo.cs` | the real manifest schema |

Verdict on each claim our notes made:

| Claim | Verdict |
|---|---|
| `%USERPROFILE%\AppData\LocalLow\MCC\Config\ModManifest.txt` | **CONFIRMED**, 5 sources |
| one mod-**root** path per line (not the mod folder itself) | **CONFIRMED**, incl. a real working file |
| CRLF | **CONFIRMED** as what every known-good writer produces |
| MCC scans one level in for `ModInfo.json` | **CONFIRMED** by 343 + Microsoft |
| mod folder may live anywhere on disk | **CONFIRMED** ("a directory somewhere on your computer") |
| `MaxAppVersion` of `9.9999.9` is valid | **CONFIRMED** — published Workshop mod 2898979550 uses exactly `{9,9999,9}` |
| "the `MaxAppVersion 0.0.0` fix" | **resolved and moot.** Our files carry `{9,9999,9}`. `0.0.0` was never shown to be broken either — Foundry and Kalo both ship `{0,0,0}` |
| UTF-8 BOM / LF-only tolerance | **UNVERIFIED.** No source either way. Our installer writes CRLF with no BOM, matching the one known-good file byte-for-byte, so this is moot in practice |
| spaces in the root path, >260-char paths | **UNVERIFIED.** No reports found. Our default path is short and space-free |
| Workshop and local mods use different registration | **CONFIRMED** — Workshop is `steamapps\workshop\content\976730\<id>\`, local is only via `ModManifest.txt`. They do not share a registry |
| mechanism changed in some later MCC build | **no evidence of any change** since it shipped (~1.3065). Only additive schema drift: `GameModContents.HasController` appears in later tools |

**The one genuinely new and load-bearing fact our notes did not record:** mods are
enumerated **only** under the EAC-disabled launch. 343's wording is "will read in
EAC-bypass". The ordinary Play button loads no local mods at all, however perfect the
files are. This was already in `WHERE-THINGS-ARE.txt` and the installer's closing
instructions as a "do this" step, but not as a *hard precondition*; `INSTALL.txt` now
states it as one.

**Still unconfirmed, and it is the thing the whole install is betting on:** every
confirmed source describes shipping *new* maps. Nothing found says MCC will load a
**replaced built-in Firefight cache** (same scenario path as a stock map) through this
path. That is an untested hypothesis, not a verified mechanism. It is the single most
likely reason for "install succeeded, nothing appears".

### Does our package implement the confirmed mechanism correctly?

Yes. This was checked against the hex-dumped real-world working file:

- manifest line = `$InstallRoot.TrimEnd('\')` → no trailing backslash ✓
- written as `($out -join "`r`n") + "`r`n"` with `UTF8Encoding($false)` → CRLF, **no BOM** ✓
- mod folders sit at `<root>\Firefight-Reinforcements\ModInfo.json` → exactly one level in ✓
- default root `%LOCALAPPDATA%\HaloFirefightMods` → short, no spaces, no admin needed ✓

---

## 1. BLOCKERS

### B1 — Re-running the installer silently destroys the uninstaller's ability to clean up
*(installer, pre-fix; FIXED)*

`Copy-ModFolders` only adds a path to `$created` when `Test-Path` said it did not exist:

```
$existed = Test-Path $dst
...
if (-not $existed) { $created.Add($dst) }
```

Run 1 records `[root, root\Firefight-Reinforcements, root\…-Safe]`. **Run 2 records
`[]`**, because everything now exists — and the state file is then overwritten with that
empty list. `uninstall.ps1` reads it and takes the "nothing to delete" branch:

```
if (-not $targets -or $targets.Count -eq 0) {
    Warn_ 'no record of folders created by the installer; deleting nothing'
```

Result: 2.8 GB stranded in `%LOCALAPPDATA%` forever, and the uninstaller reports success
while deleting nothing. Re-running an installer is an utterly normal thing to do (the
first run can stop at the `.bin` prompt, or on a copy error), so this is not an edge case.

**Fix:** the receipt now stores the **union** of this run's and all prior runs'
`CreatedFolders`, and is written to `%LOCALAPPDATA%\ffee-install-receipt.json` — outside
the folder being deleted — so it survives both the delete and a second install.

### B2 — The manifest `.bak` gets poisoned on a second run, so "restore the backup" restores our own line
*(installer, pre-fix; FIXED)*

`Register-Manifest` copied the live manifest over `.bak` **unconditionally, before**
checking whether our line was already present:

```
Copy-Item -LiteralPath $script:Manifest -Destination $bak -Force   # always
...
if ($existing -contains $line) { ...; return $false }               # too late
```

So run 2 writes a `.bak` that already contains our line. The old uninstaller then offered
"A pre-install backup of the manifest exists. Restore it?" — and restoring it **puts our
line back** while printing `DONE restored the backup`. Rollback silently fails and
reports success. This also defeated any byte-comparison against the "before" state.

**Fix:** `.bak` is taken once and never overwritten, *and* the pre-install manifest is
now stored verbatim in the receipt as base64 plus a SHA-256, so the revert can compare
byte-for-byte rather than trusting a clobberable file.

### B3 — `INSTALL.txt` told him to run Steam "Verify integrity of game files", which would destroy his author-modded Unearthed
*(docs, pre-fix; FIXED)*

Old text, under "The game crashes on load":

> Uninstall with UNINSTALL.bat, then use Steam's "Verify integrity of game files" to put
> the stock caches back.

and in section 4:

> "Verify integrity of game files" in Steam also puts the originals back.

His `haloreach\maps\ff_unearthed.map` is the **author's 870 MB modified map**. Steam does
not have that file. Verification would see a mismatch and overwrite it with the stock
map, destroying the author's Unearthed and breaking the 7.3 GB Workshop install he cares
about — to fix a problem that, in the default manifest mode, *cannot involve that file at
all*, because the installer never writes to `haloreach\maps\`.

This is the worst defect found: destructive, confidently worded, and aimed squarely at
the one irreplaceable file on his disk.

**Independently corroborated:** `maps-stock/ff_unearthed.map` was grepped and contains
the string `Evolved` 12 times. The directory labelled "Untouched stock .map sources" is
holding the **author's** map, not a stock one. So the project's own notion of "stock
Unearthed" is wrong, which is exactly how this advice got written.

**Fix:** every "Verify integrity" instruction removed and replaced with an explicit
do-not, stating why. `-DirectCopy`'s section now warns that for `ff_unearthed.map` the
`.stockbak` is his author-modded map and the only copy of it he will have.

### B4 — The revert script had no guard on what it deletes
*(uninstaller, pre-fix; FIXED)*

The old delete loop fed JSON straight into a recursive force-delete with **zero
validation**:

```
foreach ($f in ($targets | Sort-Object -Property Length -Descending)) {
    ...
    Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction Stop
```

No check that `$f` is non-empty, not a drive root, not inside `steamapps\common`, not the
MCC folder, not `%LOCALAPPDATA%` itself, and not outside the install root.

**Honesty on severity.** I tried to construct a reachable catastrophe from the
installer's own writes and **could not**: `$created` only ever receives paths that
`Test-Path` just reported absent, which excludes pre-existing folders like the drive
root, the MCC directory and `steamapps\common`. A trailing-backslash or `D:\`-style
`-InstallRoot` was traced through and stays safe for the same reason. So this is a
**latent** defect, not a demonstrated live exploit: an unvalidated
`Remove-Item -Recurse -Force` whose only protection is an invariant maintained somewhere
else entirely, in a script that has never been executed, against a hand-edited JSON file.
One future edit to `Copy-ModFolders` turns it into a disaster. It is listed as a BLOCKER
because the audit brief requires these guards and because nothing should be one typo away
from deleting a Steam library.

**Fix:** `Assert-SafeToDelete` now gates every target, at plan time *and* again
immediately before each delete, refusing: empty/whitespace, drive roots (`C:`, `C:\`),
UNC share roots, anything with fewer than 3 path segments, anything matching
`steamapps\common` or `haloreach`, anything equal to or overlapping the recorded MCC
path, the well-known profile/system folders (`%LOCALAPPDATA%`, `%APPDATA%`,
`%USERPROFILE%`, `%TEMP%`, `%windir%`, Program Files, ProgramData, Public, the MCC config
dir, Documents, Desktop), and — the core invariant — **anything that is not the recorded
install root or a descendant of it**. A refusal aborts with exit code 2 and changes
nothing.

### B5 — Both mod folders declare the same Unearthed `MapGuid` and the same scenario, and both are registered at once
*(package; documented, not auto-fixable)*

Measured, not assumed:

```
Firefight-Reinforcements/firefight/ff_unearthed.json       MapGuid=ee9b58f1-2eed-4f91-9198-6a94e6ffe9e4
Firefight-Reinforcements-Safe/firefight/ff_unearthed.json  MapGuid=ee9b58f1-2eed-4f91-9198-6a94e6ffe9e4
```

Both also carry `ScenarioFile = levels\dlc\ff_unearthed\ff_unearthed`. The two `ModGuid`s
*do* differ (`ba767591…` vs `1b8f01a3…`), which is what Kalo says MCC uses to tell mods
apart, so the two **mods** are distinct. But one manifest line registers the shared root,
so MCC enumerates **both** folders every launch, and both then claim one map GUID and one
scenario path with different 870 MB caches behind them.

`INSTALL.txt` justified the two folders with "only one of them can be installed this way
at a time" — true for `-DirectCopy`, and **false for the manifest mode that is now the
default**. The "Safe" fallback is not a fallback if it is always loaded alongside the
thing it is meant to replace.

No external source documents what MCC does with a duplicate `MapGuid` across two live
mods (**UNVERIFIED** — no reports found). Plausible outcomes: one entry shown, the wrong
cache loaded, or a load error.

**Fix:** not auto-fixable without regenerating a GUID and rebuilding, which is out of
scope for this audit round. `INSTALL.txt` now tells him to delete the
`Firefight-Reinforcements-Safe` folder to get exactly one Unearthed, and that the two
folders are an either/or, not a both. **Recommended before next build:** give the Safe
build its own `MapGuid`, or ship the two as separate downloads.

---

## 2. RISKS

### R1 — The installer could destroy his `Firefight Evolved.bin` with no backup *(FIXED)*
Old `Copy-GameVariant` prompted before overwriting but **took no backup**, and the
uninstaller only ever restored `.map.stockbak` files — never a `.bin`. One `YES` and the
author's gametype was gone, while the uninstaller still printed "Nothing that was on this
machine before the install has been deleted."

**Materially mitigated by measurement:** our `.bin` is **byte-identical** to the author's.
Both are 21,753 bytes, SHA-1 `6f6c7760a53f…`, matching `mod-original-bin/Firefight
Evolved.bin`. So today the overwrite is a no-op. **But** his on-disk copy came from a
7.3 GB Workshop item that may have been updated since our copy was taken, so identity on
*his* machine is **not verified**.

**Fix:** the installer now hashes both, and if they match it skips the file entirely and
says so — no prompt, no risk. If they differ it shows both hashes, copies his to
`Firefight Evolved.bin.ffee-bak` *before* overwriting, records the backup path and hash
in the receipt, and the revert restores it and verifies the hash. It also now says that
declining is the safe answer and the mod still works either way.

### R2 — 2.8 GB lands on `C:` by default, and 1.74 GB of it is a duplicate
`$InstallRoot` defaults to `%LOCALAPPDATA%`, i.e. `C:`. His MCC is on `I:`, which is
usually a sign `C:` is the small drive. `ff_unearthed.map` (870 MB) is shipped **twice**,
once per mod folder — 1.74 GB of the 2.85 GB payload is one duplicated file.

`Assert-Space` does check the target drive and stops loudly, and derives the drive letter
from the string rather than `Resolve-Path` (correct — the folder may not exist yet), so
this fails safe rather than filling the disk. Transient worst case is ~7.6 GB: the
1.94 GiB zip + 2.85 GiB extracted + 2.85 GiB copied.

**Mitigation:** `-InstallRoot I:\HaloFirefightMods` keeps it on the roomy drive. The
confirmed mechanism explicitly allows any location.

### R3 — `libraryfolders.vdf` regex also matches Steam's app-ID table
`'"(?:path|\d+)"\s+"([^"]+)"'` matches the `"apps"` block too, e.g.
`"976730" "81998029293"`, yielding `81998029293` as a candidate "path". Harmless in
practice — `Join-Path` makes it relative, `Test-Path` fails, it is dropped — but it is
luck, not design. The real multi-library format was checked: the `"0"` / `"1"` section
keys sit on their own line with `{` on the next, so they do not match, and
`.Replace('\\','\')` correctly un-escapes VDF paths. Both old and new layouts parse.
Low severity, left as-is.

### R4 — Drive probing can hit not-ready removable drives
`Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }` then
`Test-Path` on each. An empty optical drive or a disconnected mapped network drive
reports a non-null `Free` and can make `Test-Path` emit an error or stall. With
`$ErrorActionPreference = 'Stop'` set globally, an error here would abort the installer
before anything was written — annoying, not dangerous, and it fails *before* the first
write. Left as-is; `-MccPath` bypasses the search entirely.

### R5 — `Find-Mcc` only checks for a `haloreach` subfolder
It never confirms `MCC-Win64-Shipping.exe` or `haloreach\maps` exists, so a stale or
partially-uninstalled folder would be accepted. Low impact: the worst case is the `.bin`
being copied somewhere useless.

---

## 3. What is actually correct — verified, not assumed

Measured facts, each from a command run against the real files:

- **Every `.map` hash-matches its loose `.FINAL.map` build.** All 9 (7 small maps +
  both Unearthed variants) SHA-256 identical. `Firefight-Reinforcements/maps/ff_unearthed.map`
  == `ff_unearthed.marines6.map`; the Safe folder's == `ff_unearthed.tuned.map`. No
  truncation or corruption in packaging.
- **Every `ScenarioFile` matches the scenario path inside the `.map` header**, read out of
  the `daeh` (version 13) header directly. e.g. header
  `levels\firefight\ff70_holdout\ff70_holdout` == the JSON. Unearthed is
  `levels\dlc\ff_unearthed\ff_unearthed` in both header and JSON.
- **All 10 JSON files parse.** No trailing commas, no syntax errors.
- **`ModInfo.json` matches TagTool's real `ModInfo.cs` schema**, including the nested-object
  shape the audit brief doubted: `ModIdentifier.ModGuid`, `ModVersion/Min/MaxAppVersion` as
  `{Major,Minor,Patch}` **integers**, `Engine: "HaloReach"` (a valid enum member),
  `Title.Neutral`, `Description.Neutral`, `InheritSharedFiles: "FromMCC"` (valid),
  `ModContents`, `GameModContents.FirefightMaps[]`. No stray `Name`/`Author`/`GUID`/`Type`
  fields. `MaxAppVersion {9,9999,9}` matches a published Workshop mod exactly.
- **Scenario JSONs match `FirefightMapInfo.cs`:** `MapGuid`, `ScenarioFile`, `Title.Neutral`,
  `Description.Neutral`, `Images.{Large,Thumbnail,LoadingScreen,TopDown}`, `Flags`,
  `InsertionPoints`, `MapDefaultPrimaryWeapon`. Empty `InsertionPoints` is **correct** —
  the docs say Reach Firefight needs none (only ODST does).
- **All 20 image paths referenced by the JSONs exist.** All 10 `FirefightMaps` entries
  resolve to a real file.
- **Title and description limits respected.** Longest title 27 chars (limit 31), longest
  description 119 (limit 127). TagTool truncates with a warning rather than hiding the map,
  so there was headroom anyway — but nothing is over.
- **All GUIDs well-formed**, 10 distinct values, 9 unique + the one intentional-looking
  duplicate in B5.
- **Zip is clean.** `unzip -t` passes all CRCs. 48 entries, exactly the `MOD-PACKAGE` tree.
  **No `__MACOSX`, no `.DS_Store`, no `._*` AppleDouble, no resource forks.** 2,077,973,161
  bytes compressed (1.935 GiB, matching "1.94 GiB") from 3,056,169,188 uncompressed. Entry
  sizes match on-disk sizes exactly.
- **`.bat` files are genuine CRLF DOS batch text** (verified by hexdump: `40 65 63 68 6f
  20 6f 66 66 0d 0a`). The `.ps1` files are LF-only, which PowerShell handles fine.
- **No admin rights required anywhere.** Writes go to `%LOCALAPPDATA%`,
  `%USERPROFILE%\AppData\LocalLow`, and `<MCC>\haloreach\game_variants` (user-writable in
  a Steam library). No registry writes; the registry is read-only, in a `try/catch`.
- **Execution policy is handled correctly:** `powershell -NoProfile -ExecutionPolicy Bypass
  -File "%~dp0install.ps1" %*`. `-NoProfile` avoids a hostile user profile, `Bypass` is
  process-scoped so the machine's policy is untouched, `%~dp0` is quoted so a path with
  spaces survives, and `%*` forwards arguments.
- **The default install path has no spaces and is far short of `MAX_PATH`.** Deepest
  entry is about 90 characters.

### Conflict with his existing Workshop install

- **Separate registration, no shared index.** Workshop mods live in
  `steamapps\workshop\content\976730\<id>\` and are found by Steam subscription; local mods
  are found only via `ModManifest.txt`. Our install adds **one line** to a text file and
  writes nothing into the Workshop tree. **CONFIRMED** by Reclaimer's `MapScanner.cs` and
  343's announcement.
- **Our maps cannot shadow his base maps, because in default mode we never write to
  `haloreach\maps\`.** Traced in code: `Copy-MapsDirect` is reachable *only* via the
  explicit `-DirectCopy` switch, which `INSTALL.bat` does not pass on a double-click. His
  870 MB author-modded `ff_unearthed.map` is not read, written, or backed up.
- **Save corruption:** no mechanism found by which registering a local mod could corrupt a
  Workshop install or a save. Firefight has no campaign save state to corrupt, and nothing
  is written into the Workshop folder. Note the Safe build sets no `DisableSavedFilms`
  flag, so saved films from modded sessions may be unplayable later — cosmetic.
- **The `.bin` gametype does not conflict.** Ours is byte-identical to his (R1), so the
  gametype exists exactly once regardless of what he answers.
- **Scenario-path collision with the Workshop item is the real unknown.** Our Unearthed
  declares `levels\dlc\ff_unearthed\ff_unearthed`, the same scenario the author's mod uses.
  What MCC does with two installed mods claiming one scenario is **UNVERIFIED — no reports
  found anywhere**. I could not determine the author's `MapGuid`s: they are not in our
  research notes (only the Steam HTML is cached) and his Workshop folder is not on this
  machine. So I **cannot rule out** a GUID collision between our Unearthed and his.
  Worst realistic case is a menu oddity or a failed load, not data loss, because nothing
  is overwritten — and the revert undoes the registration in one step.

---

## 4. Rollback

**Verdict: safe, and now a first-class deliverable.** `uninstall.ps1` was rewritten
rather than patched. Against the seven requirements:

1. **Pre-flight capture — added.** `Capture-Preflight` runs *before any write* and records
   the manifest's existence, its **full verbatim content as base64**, its SHA-256, whether
   a `.bin` pre-existed and its SHA-256. An "incomplete" receipt is written immediately, so
   a crash mid-install still leaves something to revert from. The receipt lives at
   `%LOCALAPPDATA%\ffee-install-receipt.json` — **outside** any folder the revert deletes —
   with a second copy inside the install root.
2. **Surgical.** Removes only its own manifest line; deletes only recorded
   `CreatedFolders`; restores the `.bin` only if it recorded overwriting one; removes the
   `.bin` only if it recorded adding it *and* the on-disk hash still matches what we
   installed. It does not read or write `haloreach\maps\` at all unless the receipt says
   `-DirectCopy` ran — **verified by reading the code path: there is no other reference to
   `$mapsDir`.**
3. **Idempotent.** No receipt → prints `NOTHING TO UNDO`, exits 0, touches nothing.
   Nothing left to do → prints `NOTHING TO UNDO`, exits 0. Already-deleted folders print
   `SKIP already gone`. The receipt is retired only after verification passes.
4. **Verifies after reverting.** Re-reads the manifest, confirms our line is gone, and
   `Compare-Object`s the remainder against the base64 pre-install copy, printing each
   differing line as `MISSING` or `EXTRA`. Confirms each folder is gone, confirms his
   `.bin` is still present, warns about leftover `.stockbak` files. Prints PASS/FAIL per
   item and exits 1 on any FAIL, keeping the receipt for a retry.
5. **Prints before acting; dry run is the default.** Bare `UNINSTALL.bat` prints the full
   plan and changes nothing. `-Apply` plus typing `REVERT` is required. Every path is
   printed before deletion.
6. **Catastrophic cases guarded.** See B4 for the full refusal list.
7. **Documented.** `INSTALL.txt` now leads "IF SOMETHING GOES WRONG" with the revert, gives
   the exact commands, states it does not touch his Workshop mod or his maps, and adds the
   "IF THE GAME WILL NOT START" sequence: revert → launch MCC **normally** to confirm the
   game is healthy → report.

**Can he get back to exactly his current state?** Yes, by construction, because in default
mode the installer only ever does three things: create folders under `%LOCALAPPDATA%`, add
one line to a text file, and *possibly* touch one 21 KB `.bin` (now hash-skipped, and
backed up if it ever isn't). Each is individually and verifiably reversible. The
irreplaceable things — his 7.3 GB Workshop item and his 870 MB author-modded Unearthed —
are never written to by any code path that a double-click can reach.

**The residual risk is not the revert, it is `-DirectCopy`.** That is the only mode that
writes to `haloreach\maps\`, and for `ff_unearthed.map` the `.stockbak` it leaves behind
becomes the sole copy of his author-modded map. It now carries an explicit warning. He
should not use it, and does not need to.

---

## 5. Changes made by this audit

Originals preserved in `project/research/_preaudit-scripts/` (moved out of
`MOD-PACKAGE/` so a rebuilt zip stays clean).

| File | Change |
|---|---|
| `uninstall.ps1` | **rewritten.** Receipt-driven, dry-run default, `Assert-SafeToDelete` gate, post-revert verification, `.bin` restore, idempotent |
| `UNINSTALL.bat` | rewritten; forwards `%*`, documents dry-run vs `-Apply`, propagates exit code (CRLF) |
| `install.ps1` | added `Get-Sha256`, `Capture-Preflight`, `Write-Receipt`; receipt stored outside the install root; `CreatedFolders` unioned across runs; `.bak` no longer clobbered; `.bin` hash-compared, skipped when identical, backed up when not; closing banner documents the revert |
| `INSTALL.txt` | revert promoted to first troubleshooting step; "if the game will not start" sequence added; **all "Verify integrity of game files" advice removed** and replaced with a do-not; `-DirectCopy` warning about the author's map; B5 two-folder collision documented; mechanism section updated to the confirmed 343 sourcing + the EAC precondition |

**The zip is now stale.** `~/Desktop/Halo-Firefight-INSTALL.zip` still contains the
pre-audit scripts. **Rebuild it before uploading**, or the fixes above do not reach his PC.

## 6. Recommended before the next build

1. Give the Safe Unearthed its own `MapGuid`, or ship the two variants separately (B5).
2. Drop the duplicated 870 MB `ff_unearthed.map` — ~1.74 GB of the download is one file
   shipped twice.
3. Default `-InstallRoot` to the drive MCC is on, or prompt for it (R2).
4. Rename `maps-stock/` — it is holding the author's Unearthed, not a stock one, and that
   mislabel is what produced B3.
5. Tighten the `libraryfolders.vdf` parse to the `"path"` key only (R3).
6. Get `install.ps1` and `uninstall.ps1` through `powershell -Command { ... }` or at least
   `[System.Management.Automation.PSParser]::Tokenize` on a real Windows box before he runs
   them. Neither has ever been parsed.
