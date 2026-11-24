# Firefight Evolved Expanded

Buy Marines, ODSTs and Spartans in Halo: Reach Firefight (MCC). Eight maps.

HaloScript source + tools to tear apart and rebuild Reach map caches, **from macOS**.

Inspired by [Halo Reach: Evolved](https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163)
by The Vengeful 'Vadam, who did it first on Installation 04, Unearthed and Corvette.

**Status: built, audited 4 rounds, never run in retail MCC.** Read [KNOWN-ISSUES.txt](KNOWN-ISSUES.txt).

---

## The one fact that shapes everything

**A Firefight game variant cannot spawn friendly AI.**

Variants are engine type 4 (survival). No script block. Megalo has no AI-spawn action. The
Firefight squad palette is all Covenant. Confirmed four ways, including the original author's
changelog, where prices ship in *map* updates only.

So this is a **map mod**. The logic lives in a modified `.map`.

---

## What you get

| Buy | Cost | Size |
|---|---|---|
| Troopers | 500 | 4-6 |
| Spartans | 1,000 | 2, random heavy loadout |
| Win purchase | 10,000 | ends the match |

Ally cap 12, Spartan sub-cap 4. Prices are the author's own, post-playtest.

Spartans roll a random weapon and ability per spawn — sniper, rockets, Spartan laser, plasma
turret, grenade launcher; sprint, jet pack, drop shield, active camo. Zero script work: the
cell's `weapon_palette_choice_block` takes 8 weighted entries and the engine rolls.

**Maps:** Overlook, Courtyard, Waterfront, Beachhead, Outpost, Glacier, Holdout, Unearthed.
**Not Corvette** — it places no walkable ally spawn marker.

---

## Build a map, start to finish

Everything below runs on macOS. No Windows needed until you play.

### 1. Get the maps

Copy stock caches off a Windows MCC install: `...\haloreach\maps\*.map`. 146-193 MB each.

### 2. Tear one down

```bash
python3 tools/map/parse_map.py <map.map> --extract
python3 tools/hsc/decompile.py <scnr.meta> --table <build>.xml --out out.hsc
```

PC MCC Reach maps are **not compressed**. Stock maps ship no `hsc*` source — decompile.

### 3. Know what you cannot do

The compiler **cannot add script objects**. No new squads, object names, trigger volumes or
objectives. So:

- **Repurpose** the map's own empty `sur_fireteam_01..06` squads for allies.
- **Proximity, not trigger volumes.** `objects_distance_to_object` against stock objects. The
  six `health_pack0..5` stations are the shop on every map — Bungie's own pattern.
- **No marine `char` tag exists in any stock map.** Repoint an unused palette entry's `unit`
  datum (`char+0x14`, datum `+0xC`) to `objects\characters\spartans\spartans`, which every map
  ships. Allies are Spartan-bodied. 4 bytes, no growth.

Holdout needed 54 objects. Rewritten this way: 20, all stock.

### 4. Compile and write

```bash
cd tools/compile && ./build.sh          # macOS HaloScript compiler
python3 tools/map/reach_write.py <map> --blamite-gate
```

**`--blamite-gate` is not optional.** It writes to a temp file, loads it through Blamite, and
publishes only on success. Our own parser passed four caches Blamite rejected. Fail-closed.

### 5. Install

Run `installer/INSTALL.bat` on Windows. It finds MCC via Steam's `libraryfolders.vdf`, copies to
`%LOCALAPPDATA%`, and registers one line in:

```
%USERPROFILE%\AppData\LocalLow\MCC\Config\ModManifest.txt
```

One mod-root path per line, CRLF, MCC scans one level in for `ModInfo.json`. Confirmed by 343's
own Dec-2022 Waypoint post plus four implementations.

Launch **Play Halo: MCC Anti-Cheat Disabled**. Mods only enumerate there.

`installer/UNINSTALL.bat` reverts. Dry-run by default, receipt-driven, guarded against deleting
anything it did not create.

---

## Traps, each one cost us a rebuild

**Allies must sit OUTSIDE `gr_survival_all` / `_waves` / `_remaining` / `_extras`.** Otherwise
`survival_wave_living_count` never hits zero and **waves never end**. Also `ai_survival_cleanup`
runs on `_extras` every wave and would delete what you bought.

**Choice blocks are shared with stock squads.** Writing an ally weapon in place re-armed every
Covenant sniper on Outpost with human rifles. **Repoint, never overwrite.**

**Never call `(game_won)`.** Bungie's Firefight sets `b_survival_game_end_condition` and lets
`survival_end_game` finish. `(game_won)` wipes `gr_survival_all` and the match never ends.

**`objects_distance_to_object` returns -1 for a missing object** — which passes a `< radius`
test. Guard for negatives.

**Kiosk radius must be under half the anchor spacing**, or one standing position fires two
purchases. Measure per map: 0.90 to 1.45, not a constant.

**Prices live in 2+ constant nodes** (comparison and deduction; 16 on Unearthed, one pair per
player slot). Patch one and the player buys free or pays double.

**Validate before charging.** Our win kiosk deducted 10,000 before testing preconditions.

**Spawn points: one per body.** A count-4 cell with 2 points is broken. Copy coordinates from the
map's own player starting locations; never invent them.

**Growth:** a section that moves keeps its virtual address and adds the delta to its **offset
mask**. Blamite resolves interop pointers as `pointer + mask`, so bumping the vaddr desyncs
every locale pointer.

---

## Facts worth not rediscovering

- Only integrity field is a header checksum, XOR of uint32s past `0xA000`. **MCC ships maps with
  it zeroed and does not enforce it.** No signature check observed.
- Tag sizes are **not stored**. Extents are the gap to the next tag. No free list — grow by
  relocating.
- `campaign_metagame_award_points <player> <long>` takes a **signed** long. Pass negative to
  charge. Charge the actual buyer, not `player0`.
- Opcode tables shift between MCC builds — 1,566 of 1,882 names differ U0 vs U13. Read the build
  string, match the table, or output is confidently wrong.
- 10 native Firefight maps. Breakneck and Highlands are multiplayer-only. No Forge on Firefight.
- **Installation 04 is the only stock map with friendly AI** — easiest starting point.
- On-screen prices are frozen. Locale strings are SHA-1-covered in `matg`, so a patched price
  shows the old number.
- Dead ends: TagTool throws `NotImplementedException` on Gen3 and deletes Reach scripts. Invader
  is Halo CE only. GitHub Actions cannot work — the Steam depot is ownership-gated. No open
  reimplementation of `tool build-cache-file` exists for any Gen3 game.

---

## Tools

Python 3 stdlib only, except the C# compiler driver.

| Tool | Does | Proven |
|---|---|---|
| `tools/map/reach_cache.py` | `.map` parse, 4 header variants | 234 assertions |
| `tools/map/reach_write.py` | `.map` write, growth, Blamite gate | 560 assertions |
| `tools/patch/patch_map.py` | same-size field patch, reversible | 472 assertions |
| `tools/compile/` | HaloScript → bytecode on macOS | writes real caches |
| `tools/hsc/decompile.py` | script-node → `.hsc` | 100% call agreement |
| `tools/blf.py` | game-variant `.bin` read/write | byte-identical round-trip |
| `tools/mpvr.py` | Firefight settings + wave table | byte-identical round-trip |

Opcode tables are GPL (from Assembly) and not bundled: `decompile.py --fetch-tables`.

**Use [Assembly](https://github.com/XboxChaos/Assembly) instead if you have Windows** — it
decompiles *and* recompiles. These tools exist because it is a WPF app. The cross-platform fork
[Jestzer/Assembly-CrossPlatform](https://github.com/Jestzer/Assembly-CrossPlatform) builds on
arm64 macOS and is what `tools/compile/` drives.

---

## What four audit rounds found

After the maps were twice declared finished:

1. **`(game_won)` softlock on all 7 maps** — pay 10,000, match never ends, purchase latches off.
2. **Waterfront + Outpost failed outright** — no squad-emptiness test, blind rotation charging for
   nothing, 4-body squads with 2 spawn points.
3. **Stock Covenant snipers re-armed with human rifles** on Outpost, via a shared choice block.
4. **Kiosk overlap on five maps**, not one.
5. **Install docs told the user to run Steam "Verify integrity"** — would have destroyed his
   author-modded 870 MB Unearthed.
6. **Uninstaller fed JSON into `Remove-Item -Recurse -Force`** with no path validation.
7. **Duplicate MapGuids**, so the safe fallback variant was not selectable.

Round 4 closed four more, all found by re-reading the shipped bytes rather than the source
([docs/30-fix-round4.md](docs/30-fix-round4.md)):

8. **Courtyard delivered both Spartans on a different storey**, 22-23wu from the kiosk. All six ally
   spawn positions replaced with Courtyard's own player starting locations.
9. **The 10,000 win purchase charged before validating.** Buy during the bonus round and you paid
   and got nothing. The kiosk now tests its preconditions first, on all 7 maps.
10. **A player at exactly 0 health could buy.** `fe_valid` is now `(> health 0)` — Bungie's own
    boundary, taken from `f_blip_object_until_dead`.
11. **Unearthed split 2 of 6 Marines ~95wu out.** Moved; all six now span 2.30wu.

The expression-count gap that looked alarming was benign: stock carries ~3,900 expression records
unreachable from any root; the rebuild carries none, and the *reachable* count rises.

Lesson: our own parser is not a sufficient oracle. Blamite as a fail-closed gate, plus reading
the shipped bytecode back, caught what review did not.

---

## Credits

Design, prices, scenario grammar: **The Vengeful 'Vadam**
([Halo Reach: Evolved](https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163)).

Formats: [ReachVariantEditor](https://github.com/DavidJCobb/ReachVariantEditor) ·
[Assembly](https://github.com/XboxChaos/Assembly) · [Reclaimers](https://c20.reclaimers.net) ·
[TagTool](https://github.com/TheGuardians-CI/TagTool).

No map, tag or script from the original mod or from Bungie is redistributed here. Keep it free —
Microsoft's Game Content Usage Rules are noncommercial.
