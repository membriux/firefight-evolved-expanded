# 18 — First end-to-end build attempt: Beachhead (`ff50_park`), macOS

**Date:** 2026-11-22
**Target:** `~/Desktop/ff50_park.map` (Beachhead), Halo: Reach MCC
**Working copy:** `~/Desktop/build/ff50_park.map`
**Outcome: NO modified `.map` was produced. The build is blocked, and the blocker is content, not tooling.**

> **SUPERSEDED TARGET (2026-11-23).** The project retargeted from Beachhead to Holdout
> (`ff70_holdout`), which has six dormant `sur_fireteam_01..06` squads and so needs no new squad
> objects. See `research/19-holdout-retarget.md` for the retarget, the confirmed `char`->`unit`
> repoint at `char+0x20`, the resolution of the header-layout conflict, and the new blocker:
> Blamite rejects any cache produced by `reach_write.grow_tag_area()`. Everything below about the
> Beachhead cache, the checksum model and the `reach_write.py` offset-mask bug still stands.

---

## 0. Verdict in one paragraph

Beachhead contains **no Marine and no ODST `char` tag**, and no human AI character of any
kind. Neither do any of the other seven stock Reach MCC Firefight caches on this machine. The
scenario also lacks every one of the ~26 script objects (squads, squad groups, trigger volumes,
objective tasks, object names) that `fe_reinforcements.hsc` and `ff50_park.hsc` reference, and
Blamite's compiler can only *reference* script objects, never create them. A purchasable
Marine/ODST reinforcement system therefore cannot be built on this map with the current macOS
toolchain, and the deliverable `~/Desktop/build/ff50_park.map` has deliberately been left
**byte-identical to the original**.

Two things did go better than expected, and they are worth banking: the cache reader/writer pair
now has its **first real-file proof** (round-trip byte-identical on 164 MB, checksum model
confirmed exactly, tag-area growth and tag relocation verified), and the HaloScript compile driver
**does produce real bytecode against this real cache** when the script only references objects that
actually exist.

---

## 1. Safety and provenance

* The original was copied once with `cp -n`, then the original was made read-only
  (`chmod a-w ~/Desktop/ff50_park.map`). No write of any kind ever targeted it.
* SHA-256 of both files, before and after the whole session:
  `9bccad85d9c601928138111c4711c4e93fcfb1886b07144be3f9c910c0637a40`
* `~/Desktop/ff_unearthed.map` was never opened, read, or written by this work.
* The one mechanism test that did produce a modified cache wrote to `/tmp`, was verified, and was
  then deleted. Nothing unverified was left on the Desktop.

---

## 2. Step 1 — Parse the copy

`tools/map/parse_map.py` reads the real file correctly. Confirmed values:

| Field | Value |
|---|---|
| magic at 0x0 | `daeh` (little-endian `head`) |
| engine version (0x4) | 13 |
| build string (0xA0) | `Jun 21 2023 15:35:31` |
| engine (via `Engines.xml`) | Halo: Reach MCC **Update 13** → header layout `mcc-u8+`, layouts `ReachMCC/LayoutsU13` |
| internal name (0xC0) | `ff50_park` |
| scenario path (0xE0) | `levels\firefight\ff50_park\ff50_park` |
| file size | 0xA434000 (172,179,456 B), header field agrees with disk |
| header checksum (0x360) | 0x09B9439A |
| virtual base (0x2E0) | 0x1C8860000 |
| index header address (0x2E8) | 0x1CA4037FC → file 0x44C87FC, magic `tags` verified |
| tag data area | file 0x2925000, size 0x77A0000 (119.6 MiB) |
| pointer expansion | `virtual = (stored << 2) + 0x50000000` |
| tag groups / tags | 235 / 14,034 (1 null, 14,030 named) |
| string ids | 70,659 |

The four interop sections tile the file exactly, which is the strongest confirmation that the
`file offset = section vaddr + offset mask (mod 2^32)` rule in `research/07` is right:

| # | section | vaddr | mask | file offset | size | ends at |
|---|---|---|---|---|---|---|
| — | header | — | — | 0x0 | 0xA000 | 0xA000 |
| 0 | debug | 0x0B409000 | 0xF4C01000 | 0xA000 | 0x373000 | 0x37D000 |
| 1 | resource | 0x00000000 | 0x0037D000 | 0x37D000 | 0x25A8000 | 0x2925000 |
| 2 | tag | 0x03CE9000 | 0xFEC3C000 | 0x2925000 | 0x77A0000 | 0xA0C5000 |
| 3 | localization | 0x0397A000 | 0x0674B000 | 0xA0C5000 | 0x36F000 | 0xA434000 = EOF |

Note the layout: on this map the **debug section (string-id and tag-name tables) sits *before* the
tag area**, and the localization section sits after it. `reach_write.py` assumed the opposite; see
§7.

### 2a. One non-reproducing parse failure, recorded for honesty

The very first invocation failed with:

```
MALFORMED CACHE FILE
tag data area offset 0x102925000 is outside the file (0xA434000 bytes)
```

0x102925000 is `0x03CE9000 + 0xFEC3C000` **without** the 32-bit truncation that
`reach_cache.py:919-920` applies. The source on disk has the truncation and every subsequent run
(CPython 3.11.13 and 3.13/3.15, with and without `-I`) parses the file correctly. The most likely
cause is a stale `tools/map/__pycache__/reach_cache.cpython-315.pyc` compiled from an earlier
revision, which was overwritten later in the session. **Mitigation, and this should be standard
before any authoritative run:**

```bash
find "~/Desktop/Firefight Evolved Expanded" -name __pycache__ -prune -exec rm -rf {} +
```

---

## 3. Step 2 — Inventory: the blocker, measured

### 3.1 Characters — the hard blocker

`ff50_park` has **60 `char` tags and 13 `bipd` tags. Not one is human.**

* `bipd`: grunt, brute, elite_ai, elite, hunter, jackal, brute_chieftain, null, spartans,
  monitor_editor, hologram_jackal, hologram_spartan, hologram_elite.
* `char`: 18 generic/stimulus definitions plus grunt, brute, elite, jackal, skirmisher, hunter and
  null variants. No `marine`, no `odst`, no `trooper`, and no `char` for the `spartans` biped
  (the player biped ships without an AI character definition, so it cannot be squadded either).
* `character palette` in the scenario: 26 entries, **all Covenant**.

This is not specific to Beachhead. Every stock Firefight cache on this machine was scanned
(`build/logs/chars.txt`), all on build `Jun 21 2023 15:35:31`:

| map | tags | `char` | `bipd` | marine/ODST `char` | marine/ODST `bipd` |
|---|---|---|---|---|---|
| ff10_prototype | 14,650 | 61 | 14 | none | none |
| ff20_courtyard | 13,879 | 62 | 14 | none | none |
| ff30_waterfront | 14,181 | 60 | 13 | none | none |
| ff45_corvette | 13,146 | 61 | 14 | none | none |
| **ff50_park** | **14,034** | **60** | **13** | **none** | **none** |
| ff60_airview | 14,547 | 61 | 14 | none | none |
| ff60_icecave | 13,189 | 61 | 14 | none | none |
| ff70_holdout | 13,291 | 61 | 14 | none | none |

**Consequence for the project plan:** retargeting to Installation 04 will not help. Installation 04
is another Firefight cache and stock Reach Firefight has no allied AI anywhere, so it is near
certain to be missing the same tags. Retargeting should not be attempted until someone has
confirmed a marine `char` in the candidate cache — a two-minute check with `scan_chars.py`.

### 3.2 Squads — what exists, and what is dormant

29 squads, 10 squad groups, every squad on `team = default`:

* `sq_sur_wave_01`…`08`, `sq_sur_remaining`, `sq_ff_bonus` — wave squads, 0–8 designer cells.
* `sq_sur_phantom_01`…`04`, `sq_sur_bonus_phantom` — 1 cell, 1 spawn point each.
* `sq_sur_wraith_01/02` (template `sq_camp_wraith`), `sq_sur_ghost_01/02` (template
  `sq_camp_ghost_1`) — 1 designer + 1 templated cell each.
* `sq_sur_drop_01`…`04` — 1 cell, count 4, 4 spawn points each.
* **`sq_elite_fireteam_01`…`06` — 0 cells, 0 spawn points, flags 0x100. These are the six dormant
  squads `research/16` was looking for.**
* Squad groups: `gr_survival_all`, `_extras`, `_bonus`, `_remaining`, `_phantoms`, `_waves`,
  `_fireteams`, `_wraith_01`, `_wraith_02`, `_ghost`. No UNSC group.

So a dormant squad to repurpose **does exist** — six of them. Repurposing is cheap for the two
easy parts (rename via string id, flip `team` to a human team: both same-size patches that
`patch_map.py` can do) and impossible for the third: a cell has to name a character out of the
character palette, and the palette holds only Covenant characters. Adding cells also means growing
the `scnr` tag, which is now proven to work (§6), but there is nothing human to point them at.

### 3.3 The rest of the scenario, versus what the scripts need

| namespace | present in cache | referenced by our scripts but absent |
|---|---|---|
| squads (29) | `sq_sur_*`, `sq_elite_fireteam_*`, `sq_ff_bonus` | `sq_fe_garrison`, `sq_fe_marines`, `sq_fe_odst`, `sq_fe_gunner`, `sq_fe_sniper_01`, and the spawn point `sq_fe_odst/driver` |
| squad groups (10) | `gr_survival_*` | `gr_unsc_reinforcements`, `gr_unsc_followers` |
| ai objectives (2) | `obj_survival` (37 tasks), `obj_fireteams` (1 task) | `obj_marines` and its tasks `gate_marines`, `gate_marines_defenders`, `gate_marines_followers` |
| trigger volumes (47) | `tv_sur_garbage_all`, `tv_wraith_01/02`, `tv_null`, `safe_zone_soft`, `kill_*` | all 11 `tv_fe_*`: `tv_fe_board`, `tv_fe_roof`, `tv_fe_bank_in`, `tv_fe_bank_out`, `tv_fe_buy_marines`, `tv_fe_buy_odst`, `tv_fe_buy_turret`, `tv_fe_buy_turret_up`, `tv_fe_buy_ghost`, `tv_fe_buy_strike`, `tv_fe_buy_dustoff` |
| object names (163) | `generator0..2`, `generator_switch0..2` (+`_cool`/`_disabled`), `ammo_crate0/1`, `health_pack0..5`, `sc_resupply_01..09`, `sc_hack_*`, `dm_*`, `fx_*` | `dm_fe_pod_01`, `sc_fe_ghost`, `sc_fe_pelican`, `sc_fe_turret_01` |
| point sets (7) | **`ps_gen` (3 points)**, `ps_wraith` (4), `ps_sur_phantom_01..04`, `ps_sur_bonus_phantom` | `ps_sur_pelican`, `ps_banshee_*` |
| zones (1) | `zn_survival` — 128 areas, 1,756 firing positions; areas are auto-named `areas_N` / `vehicle_areas_N` | — |
| scripts / globals | 377 scripts, 197 globals | — |

Two premise corrections for `research/05` and `research/11`:

* **`ps_gen` is real** and so is the generator infrastructure — but the generators are *object
  names* `generator0..2` / `generator_switch0..2`, **not** `gen0`/`gen1`/`gen2`. Our scripts use the
  short form; stock binds the long form to globals
  (`(global device_name obj_sur_generator0 "generator0")`). Our references will not resolve as
  written.
* The "full 12-friendly actor cap" claim could not be verified from the cache. There is no friendly
  squad, no friendly character and no UNSC squad group in `ff50_park`, so whatever supports 12
  friendly actors is not visible in the scenario tag.

**Total new script objects the design needs: ~26.** `tools/compile/bin/.../hsc-compile --help` states
the constraint plainly, and it is correct: *"Blamite's compiler can only REFERENCE script objects,
never add them, so this manifest is a to-do list for Sapien/Foundation, not a substitute for one."*

---

## 4. Step 3 — Approach decision

| option | verdict |
|---|---|
| **Repurpose a dormant squad** (`sq_elite_fireteam_01..06`) | **Rejected.** Rename and team flip are trivial same-size patches, and cells can now be added by growing the tag. But a cell must name a character from the palette, and no human character exists in the cache to name. The result would be allied *Covenant*, not Marines. |
| **Grow the tag to add squads/trigger volumes/objectives** | **Mechanically possible, functionally insufficient.** §6 proves growth and relocation work on the real file. It does not solve the missing `char`, and hand-authoring 11 trigger volumes plus an objective's task list means inventing world-space geometry with no editor to place it in. |
| **Declare it blocked on macOS** | **Chosen.** Honest, and the blocker is now measured rather than asserted. |

---

## 5. Step 4 — Compile against the real cache

Driver state: already built by the other agent, `hsc-compile.dll`, Blamite from
`Jestzer/Assembly-CrossPlatform` at `/tmp/acp_test/Assembly-CrossPlatform`, `net8.0` on
`macOS/Arm64 clr 11.0.0`. The XML guard passed — `tools/hsc/tables/reachmcc_u13.xml` is
byte-identical (`42beb6b51d5ee195…`) to the `ReachMCC_U13_Scripting.xml` that `Engines.xml` assigns
to this build. 1,812 function names, 1,716 globals, 89 value types.

### Run 1 — `build/logs/compile1.log`, exit 1

```
context      : cache scnr (ff50_park.hsc)
             : 495 script objects in 14 blocks
size: 113904 bytes, 1784 lines
[dialect] 31 script declaration header(s) rewritten
[parse] 0 syntax error(s)
[parse] top level: 64 script declaration(s), 48 global declaration(s)
[lint] 36 static finding(s)
          25  unimplemented
           6  unknown-function
           5  tagref-not-a-path
[objects] 24 distinct script-object reference(s); 19 unresolved against the current context
[compile] FAILED at fe_reinforcements.hsc:498:33 near "sfx_blip"
[compile] Failed to process the expression "sfx_blip". A "sound" expression was expected.
RESULT: 1 of 2 file(s) did not compile.
```

Lint detail worth keeping:

* 25 × `unimplemented: "print" is marked unimplemented in this build's scripting XML; the engine will not run it`
  — stock Firefight scripts are full of `print` too, so this is cosmetic, not a defect. All 25 sit
  behind `(if g_fe_debug …)`.
* 6 × `unknown-function` on `survival_refresh_sleep` (lines 787, 799),
  `survival_spartans_increment_score` (1123), `event_survival_spartans_win_normal` (1124),
  `survival_elites_increment_score` (1130), `event_survival_elites_win_normal` (1131) —
  *"not in this build's scripting XML and not declared in this file"*. These are the Megalo/engine
  hooks the design assumed; they do not exist in the U13 opcode table under those names and need
  re-grepping from shipped scripts.
* 5 × `tagref-not-a-path` on `sfx_blip` — fixed, see below.

### The one unambiguous script bug, fixed

`sfx_blip` is not a built-in. Stock declares it as a script **global of type `sound`** holding a
real tag path, identically in all ten shipped Firefight scripts
(`research/_raw/hsc/omaha_release_11860/ff50_park.hsc:160` and nine siblings):

```
(global sound sfx_blip "sound\game_sfx\ui\transition_beeps")
```

That tag is present in this cache as `snd!` index 8789
`sound\game_sfx\ui\transition_beeps`. The declaration was added to
`src/hsc/fe_reinforcements.hsc` §3 with the citation. All 5 `tagref-not-a-path` findings cleared.

**Not fixed, flagged instead:** the same bare `sfx_blip` appears in `ff10_prototype.hsc`,
`ff30_waterfront.hsc`, `ff60_airview.hsc`, `ff60_icecave.hsc` and `ff70_holdout.hsc`. Those are
other maps' scenario scripts and another agent may own them; they will compile once they are
unitised with `fe_reinforcements.hsc`, which now carries the declaration.

### Run 2 — `build/logs/compile2.log`, exit 1

```
[parse] 0 syntax error(s)
[parse] top level: 64 script declaration(s), 49 global declaration(s)
[lint] 31 static finding(s)
[objects] 24 distinct script-object reference(s); 19 unresolved against the current context
[compile] FAILED at fe_reinforcements.hsc:773:24 near "obj_marines/gate_marines"
[compile] Failed to process the expression "obj_marines/gate_marines". A "ai" expression was expected.
RESULT: 1 of 2 file(s) did not compile.
```

This is the wall. The next 25 defects behind it are the same defect: a script object that does not
exist in the scenario.

### Proof that the toolchain itself is sound

Two four-line probes compiled against the real cache (`build/logs/probe.hsc`, `probe_ok.hsc`):

```
### probe.hsc      (set probe_squad sq_fe_marines)
[compile] FAILED at probe.hsc:3:21 near "sq_fe_marines"
[compile] Failed to process the expression "sq_fe_marines". A "ai" expression was expected.

### probe_ok.hsc   (set probe_squad sq_sur_wave_01)
[compile] OK in 0.006s - BYTECODE PRODUCED: 7 expressions, 1 scripts, 1 globals,
          0 tag references, 42 string bytes
```

So the compile driver **does** produce bytecode against this real 164 MB cache. The only thing
stopping the real build is that the objects are missing.

### Driver defect found: `[objects]` undercounts

Both probes report `[objects] 0 distinct script-object reference(s); 0 unresolved`, yet one of them
fails on an unresolved squad. The driver's static object scanner does not walk the arguments of
`set`, so `ff50_park.hsc:162-165` — `(set ai_fe_garrison sq_fe_garrison)`, `(set ai_fe_marines
sq_fe_marines)`, `(set ai_fe_odst sq_fe_odst)`, `(set ai_fe_gunner sq_fe_gunner)` — are never
checked. **The real count of missing script objects is 19 + those 4 + the 2 missing squad groups
= at least 25, not 19.** Worth fixing in `tools/compile/Program.cs` so the to-do list the driver
prints is complete.

---

## 6. Step 5 — Write path: first real-file proof

Nothing was committed to a deliverable map, but three write-path claims were tested against the
real file for the first time.

**1. Checksum model — confirmed exactly.** `research/13`'s claim holds byte for byte: the header
int32 at 0x360 equals the XOR of every little-endian uint32 from 0xA000 to EOF.

```
start 0x00800 -> 0xF355B96E  no
start 0x01000 -> 0xF355B96E  no
start 0x02000 -> 0xF355B96E  no
start 0x04000 -> 0xF355B96E  no
start 0x0A000 -> 0x09B9439A  MATCH (header value 0x09B9439A)
```

**2. Round-trip gate — byte-identical on 164 MB.** `CacheWriter.reencode_all()` re-encoded every
field the reader parses back over the original bytes and the result was identical, same length, and
the checksum verified (`163136410 == 163136410`). This is the gate that `reach_write.py`'s own
STATUS block said had never been run against a real map.

**3. Tag-area growth and tag relocation — work, after one fix.** `relocate_tag(scnr, …,
mode="end")` grew the tag area by 0x10000, moved the `scnr` tag to virtual 0x1D0000000 /
file 0xA0C5000, zeroed the vacated space, repointed the tag table entry, re-adjusted partitions and
recomputed the checksum. Re-parsing the 172,244,992-byte result:

```
REPARSE OK: tags=14034 groups=235
checksum verify: (931023215, 931023215, True)
squads count 29   first squad name 'sq_sur_wave_01'
tag name sample: objects\characters\grunt\ai\grunt
named tags 14030 (unchanged)   string ids 70659 (unchanged)   warnings: []
```

Header byte-diff against the original is **9 bytes in exactly 6 fields**, all of which must change:
`file size` (0xA), `virtual size` (0x16), partition 5 size (0x35A), `checksum` (0x360-0x363), tag
section size (0x4F2), localization section vaddr (0x4F6). Nothing unintended moved. The test cache
was then deleted.

---

## 7. Real defect fixed in `tools/map/reach_write.py`

The first growth attempt reparsed, passed its checksum, and still **silently destroyed all 14,034
tag names**:

```
tag name table: 14034 of 14034 entries had offsets outside the 791664-byte data blob
string id table: 15363 of 70659 entries had offsets outside the 2473833-byte data blob
```

**Root cause.** `CacheWriter.area_offset()` computed a section's file offset as
`vaddr + mask` without the 32-bit truncation the reader applies. On a real MCC cache the mask is a
wrapping delta and usually "negative": the debug section is `0x0B409000 + 0xF4C01000 =
0x1_0000A000`, i.e. file 0xA000. Untruncated, every section looked as if it lived past
0x1_00000000 and therefore after the insertion point, so `grow_tag_area(mode="end")` shifted the
debug section's vaddr and all five debug-relative header table offsets by 0x10000 — while the
debug data, which really sits *before* the tag area on this map, had not moved. The module's own
docstring states the wrong assumption: *"on a real Reach map that is the debug section"*. On
`ff50_park` the section after the tag area is localization, not debug.

The synthetic fixtures never caught this because they use zero masks, where `vaddr == file offset`
and the truncation is a no-op.

**Fix** — four truncations plus one semantic correction:

* `area_offset()` → `& 0xFFFFFFFF` (with the ff50_park numbers recorded in the docstring)
* `old_table_offsets[name]` → `& 0xFFFFFFFF`
* `put_section(i, (new_area_offsets[i] - self.masks[i]) & 0xFFFFFFFF, …)`
* `put_header(name, (new_off - self.masks[SECTION_DEBUG]) & 0xFFFFFFFF)`
* `tag_buffer_offset` now writes `sections[tag].vaddr`, not `vaddr + mask`. The header field holds
  the tag section's **virtual** address (0x03CE9000 here), not its file offset (0x2925000); the two
  coincide only on zero-mask caches, which is again why the fixtures passed.

**Regression check:** `reach_write.py --self-test` → *387 assertions, 0 failures*;
`parse_map.py --self-test` → *195 passed, 0 failed*. Then the real-file growth test, re-run, gave
the clean result in §6.

Note: `tools/map/test_reach_write.py` and `test_parse_map.py` cannot be run under bare `pytest` —
they are variant-parametrised and error with `fixture 'variant' not found`. Use the `--self-test`
entry points.

---

## 8. Reproducible command sequence

```bash
PROJ="$HOME/Desktop/Firefight Evolved Expanded"
cd "$PROJ"

# 0. clear stale bytecode (see §2a)
find . -name __pycache__ -prune -exec rm -rf {} +

# 1. protect the original, make the working copy
chmod a-w ~/Desktop/ff50_park.map
mkdir -p ~/Desktop/build
cp -n ~/Desktop/ff50_park.map ~/Desktop/build/ff50_park.map
shasum -a 256 ~/Desktop/ff50_park.map ~/Desktop/build/ff50_park.map   # must match

# 2. parse / inventory
python3 tools/map/parse_map.py ~/Desktop/build/ff50_park.map --no-list

# 3. the blocker check, on any candidate map (prints marine char/bipd hits)
python3 build/logs/scan_chars.py

# 4. parser + writer self-tests
python3 tools/map/parse_map.py --self-test
( cd tools/map && python3 reach_write.py --self-test )

# 5. writer real-file gates: round-trip, then growth + relocation + reparse
python3 build/logs/roundtrip.py   | grep -v '^reencode_all ->'
python3 build/logs/growtest.py
python3 build/logs/verify_grow.py
rm -f /tmp/fe_scan/grow_mechanism_test.map

# 6. HaloScript dry run against the real cache (writes nothing)
cd tools/compile
export DOTNET_ROLL_FORWARD=LatestMajor DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
export BLAMITE_FORMATS="$PWD/bin/Release/net8.0/Formats"
dotnet bin/Release/net8.0/hsc-compile.dll \
  --formats "$BLAMITE_FORMATS" --unit \
  --hsc ../../src/hsc/fe_reinforcements.hsc \
  --hsc ../../src/hsc/ff50_park.hsc \
  --xml ../hsc/tables/reachmcc_u13.xml \
  --map ~/Desktop/build/ff50_park.map

# 7. the two probes that isolate "toolchain broken" from "object missing"
dotnet bin/Release/net8.0/hsc-compile.dll --formats "$BLAMITE_FORMATS" \
  --hsc ../../build/logs/probe.hsc    --xml ../hsc/tables/reachmcc_u13.xml \
  --map ~/Desktop/build/ff50_park.map          # fails: sq_fe_marines absent
dotnet bin/Release/net8.0/hsc-compile.dll --formats "$BLAMITE_FORMATS" \
  --hsc ../../build/logs/probe_ok.hsc --xml ../hsc/tables/reachmcc_u13.xml \
  --map ~/Desktop/build/ff50_park.map          # OK: bytecode produced
```

Raw logs for every step are archived in `build/logs/`.

---

## 9. What has to change for this to work

In descending order of leverage.

1. **Get a cache that actually contains a marine `char`.** No Firefight map has one. Reach
   *campaign* caches do (`objects\characters\marine\ai\marine*`), and none are on this machine.
   Until a cache with a human character is in hand, every downstream step is moot. Check any
   candidate with `build/logs/scan_chars.py` before spending time on it.
2. **Accept that the scenario edit needs an editor, not a compiler.** Even with marines available,
   ~25 new script objects are required — squads with cells, two squad groups, eleven trigger volumes
   with real world-space geometry, an objective with three tasks, four object names, one squad spawn
   point. Blamite cannot create any of them, and trigger volumes and spawn points need spatial
   authoring. That is Foundation or Sapien on Windows. **This is the single most likely thing to
   make the project work.**
3. **If the goal is a shipped macOS-only mod, change the feature.** A purchasable *allied Covenant*
   squad is reachable today: rename a dormant `sq_elite_fireteam_0N`, flip its `team` field, and add
   cells pointing at the Covenant characters already in the palette. Rename and team flip are
   same-size patches; cells now need only the proven tag-growth path. It is not Marines, but it is
   buildable and verifiable on this machine.
4. **Re-ground the six `unknown-function` engine hooks.** `survival_refresh_sleep`,
   `survival_*_increment_score` and `event_survival_*_win_normal` are not in the U13 opcode table
   under those names. They need re-grepping from the shipped scripts before any write.
5. **Fix `[objects]` in `tools/compile/Program.cs`** to walk `set` arguments, so the driver's
   to-do list is complete rather than 6 short.
6. **Correct the generator references** in `src/hsc/ff50_park.hsc`: the object names are
   `generator0..2` / `generator_switch0..2`, not `gen0..gen2`. `ps_gen` and `ps_wraith` are correct;
   `ps_sur_pelican` and the `ps_banshee_*` set do not exist.

---

## 10. Files changed by this attempt

| file | change |
|---|---|
| `src/hsc/fe_reinforcements.hsc` | added the stock `(global sound sfx_blip "sound\game_sfx\ui\transition_beeps")` declaration with its citation. Clears all 5 `tagref-not-a-path` findings. |
| `tools/map/reach_write.py` | 32-bit truncation in `area_offset()`, `old_table_offsets`, `put_section()` and the debug-table write-back; `tag_buffer_offset` now stores the tag section's virtual address. Fixes silent destruction of the tag-name and string-id tables on any map whose offset masks are non-zero. 387 + 195 self-test assertions still pass. |
| `build/logs/` | new: raw logs and the five scripts used, so every number above can be re-derived. |
| `~/Desktop/build/ff50_park.map` | created as the working copy. **Byte-identical to the original; no modification was committed.** |

Nothing was written to `~/Desktop/ff50_park.map` (now read-only) or to `~/Desktop/ff_unearthed.map`.
