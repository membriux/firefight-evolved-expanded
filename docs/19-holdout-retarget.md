# 19 — Holdout retarget: what was built, and the new blocker

**Date:** 2026-11-23
**Target:** `~/Desktop/ff70_holdout.map` (Holdout), Halo: Reach MCC Update 13
**Working copy:** `~/Desktop/build/ff70_holdout.map` (byte-identical to the original)
**Verified artifact:** `~/Desktop/build/ff70_holdout.spartanally.map`

Supersedes the target choice in `research/18-first-build-attempt.md`. Everything in 18 about the
Beachhead cache, the checksum model and the `reach_write.py` mask bug still stands.

---

## 0. Headline

The two findings that prompted the retarget are **both confirmed**, with one offset correction. A
same-size `char`→`unit` repoint was applied to Holdout and verified by two independent readers, so
a human-bodied ally character now exists in a real cache. Cells were then successfully added to two
dormant squads — and that is where a **new, hard blocker** appeared:

> **Any cache produced by `reach_write.grow_tag_area()` — in either `"end"` or `"beginning"` mode —
> is accepted by our own parser with zero warnings and a valid checksum, and is then *rejected* by
> Blamite, the reference implementation, with
> `InvalidOperationException: Segment size is too large`.**

Our parser's approval is therefore **not sufficient evidence that a grown cache is well formed**.
The grown maps were deleted rather than shipped. The only write primitive currently validated by
both readers is same-size patching through `tools/patch/patch_map.py`.

> **FIXED 2026-11-23 — see §4 "RESOLVED".** The overrun was the tag data segment against
> language 0's locale index table: growth moved the localization section's *virtual address*
> instead of its *offset mask*, so the locale pointers still resolved to pre-growth offsets.
> Growth now passes Blamite in both modes, and `CacheWriter.save()` refuses to publish any cache
> Blamite will not load.

---

## 1. The header-layout conflict: resolved empirically, and it was inverted

The reported conflict was that Blamite's `LayoutsU13` places masks and sections "+0x20" from
`reach_cache.py`'s `mcc-u8+`. That is not what the files say.

| source | offset masks | sections | checksum | virtual base | index header | build string |
|---|---|---|---|---|---|---|
| `reach_cache.py` variant `mcc-u8+` | **0x4CC** | **0x4DC** | 0x360 | 0x2E0 | 0x2E8 | 0xA0 |
| Blamite `ReachMCC/LayoutsU13` | **0x4CC** | **0x4DC** | 0x360 | 0x2E0 | 0x2E8 | 0xA0 |
| Blamite `ReachMCC/LayoutsU10` | 0x4CC | 0x4DC | 0x360 | 0x2E0 | 0x2E8 | 0xA0 |
| Blamite `ReachMCC/LayoutsU8` | 0x4AC | 0x4BC | 0x360 | 0x2E0 | 0x2E8 | 0xA0 |
| Blamite `ReachMCC/Layouts` (U0) | 0x4B4 | 0x4C4 | 0x2D0 | 0x2F8 | 0x10 | 0x120 |

`LayoutsU13` and `mcc-u8+` **agree exactly**. The −0x20 difference belongs to `LayoutsU8`, a
different build. Nobody is wrong about U13.

Settled against the real Holdout file (0x925E000 bytes). Only the 0x4CC/0x4DC reading makes the four
interop sections tile the file, with the last section ending precisely at EOF:

```
U13/U10  masks 0x4CC sect 0x4DC  -> tiles_file_exactly = True
   sect0 debug        vaddr 0x0A22E000 size 0x030E000 mask 0xF5DDC000 -> file 0x000A000..0x0318000
   sect1 resource     vaddr 0x00000000 size 0x1CE6000 mask 0x00318000 -> file 0x0318000..0x1FFE000
   sect2 tag          vaddr 0x033BE000 size 0x6EF0000 mask 0xFEC40000 -> file 0x1FFE000..0x8EEE000
   sect3 localization vaddr 0x0304E000 size 0x0370000 mask 0x05EA0000 -> file 0x8EEE000..0x925E000 = EOF

U8       masks 0x4AC sect 0x4BC  -> tiles_file_exactly = False   (sections land past 0x1_00000000)
U0       masks 0x4B4 sect 0x4C4  -> tiles_file_exactly = False
```

**Use 0x4CC / 0x4DC for U13.** One genuine latent bug remains: `reach_cache.py` maps *every* build
from Flight 4 (Aug 2021) onward to the single `mcc-u8+` variant, so a real **Update 8** cache
(`Sep 13 2021 09:49:52`) would be read with U13 offsets and mis-parsed. Holdout and all eight stock
Firefight maps are U13, so this does not affect the current work, but the variant table should be
split before anyone opens a U8/U9 cache.

---

## 2. Finding 1 — Holdout's dormant squads: confirmed

| claim | result |
|---|---|
| six clean, empty `sur_fireteam_01..06` squads | **confirmed** — squad indices 16-20 and 30. Each: 0 designer cells, 0 templated cells, 0 spawn formations, 0 spawn points, flags 0x100, `team = default`, `initial objective = 1` (`obj_fireteams`) |
| already bound to `ai_sur_fireteam_squad0..5` | **confirmed** — the stock script declares `(global ai ai_sur_fireteam_squad0 none)` … `squad5`, and binds them: `(set ai_sur_fireteam_squad0 "sur_fireteam_01")` … `(set ai_sur_fireteam_squad1 "sur_fireteam_02")` |
| 37 free palette slots | **confirmed** — `character_palette_block` max count is 64, Holdout uses 27 |
| all 8 wave squads authored | **confirmed** — `sq_sur_wave_01..08`, 1 designer cell each, 2 spawn formations each |
| most free script datums | not independently re-measured; Holdout's scnr has 377 scripts / 205 globals / 20,164 expressions |

Holdout's full scenario: 31 squads, 10 squad groups, 27 character-palette entries, 81 object names,
24 trigger volumes, 2 AI objectives, 1 zone, 8 point sets, 377 scripts, 205 globals.

**One correction that matters for the design.** `gr_survival_fireteams` (group 9), the parent of all
six fireteam squads, is **not** a root group: its parent is group 1 `gr_survival_waves`, whose parent
is group 0 `gr_survival_all`. `research/14`'s design requires the ally group to sit outside
`gr_survival_all` so allies never enter the wave count. Fixing that is a 2-byte same-size write to
the group's `parent` field (`squad_groups_block + 0x20`, `short_block_index`, 1 → −1), verified
working here before the artifact was discarded with the rest of the grown chain.

---

## 3. Finding 2 — the `char`→`unit` repoint: confirmed, with the offset explained

The reported "`char`→`unit` datum sits at `char+0x20`" is **right**, and here is why, from the real
MCC tag definitions:

* `character_struct_definition` has `tag_reference 'unit'` at field offset **0x014** (allowed group
  `unit`). `'parent character'` is at 0x004; `'creature'` at 0x024.
* A Reach `tag_reference` is 16 bytes with the **datum index at +0xC** (Blamite `tag reference`
  layout).
* Therefore the 4-byte datum to repoint is at `char + 0x14 + 0xC` = **`char + 0x20`**, and the group
  magic at `char + 0x14` already reads `bipd`, so no group change is needed.

Verified by reading every non-stimulus `char` in Holdout: each one with a unit resolves to a
sensible biped (`grunt` → `objects\characters\grunt\grunt`, `hunter` → `…\hunter\hunter`, and so
on), and chars that inherit show `0xFFFFFFFF`.

### Picking the victim

Holdout's 27-entry character palette was cross-referenced against every cell in all 31 squads.
Exactly **one** palette entry is referenced by no cell at all:

```
[25] objects\characters\null\ai\null_cov_default      used_by = (nothing)
[26] objects\characters\null\ai\null_cov_flying       used_by = sq_sur_banshee_01/02 (the pilots)
```

So `null_cov_default` (char tag index 8107) is the only safe sacrifice — repointing it cannot change
any existing enemy, because nothing spawns it. (`null_cov_flying` must be left alone; it flies the
banshees.)

### The patch, applied and verified

```
char[8107] objects\characters\null\ai\null_cov_default
  unit tag_reference at file 0x73AA688+0x14, datum at file 0x73AA6A8
  before: bipd ... datum 0x86931FAC -> bipd objects\characters\null\null
  after : bipd ... datum 0x8DC525EC -> bipd objects\characters\spartans\spartans   (tag 9708)
```

```bash
python3 tools/patch/patch_map.py ~/Desktop/build/ff70_holdout.map \
  --set '@0x73AA6A8:u32=0x8DC525EC' --allow-unmapped --apply \
  --out ~/Desktop/build/ff70_holdout.spartanally.map
```

`patch_map.py` reported, and an independent re-read confirmed:

* byte diff is **2 runs**: the 4 intended bytes plus the 4 header checksum bytes. File length
  unchanged at 153,477,120.
* re-parse: 13,291 tags, 235 groups, 13,287 named, 65,672 string ids, **0 warnings**
* checksum self-consistent under a second, independent XOR implementation
  (`stored = computed = 0x37A131D2`)
* **Blamite loads it and compiles a probe script against it successfully** — the decisive
  cross-check
* reversible from `ff70_holdout.spartanally.map.patch.json`

**This artifact is verified but inert.** Nothing references palette entry 25, so in game it changes
nothing. It proves the mechanism; it is not a feature.

---

## 4. The structural edit that worked, and then did not

Cells were added to `sur_fireteam_01` and `sur_fireteam_02` — 4 actors each, cap 8, matching
`research/14`'s `marine_rein` shape. Method, with no squad creation anywhere:

1. `sq_sur_drop_01`'s designer cell (108 bytes, `normal diff count = 4`, one character-type entry)
   was used verbatim as a template, so every spawn-condition, weapon and patrol field keeps a
   stock-valid value.
2. `grow_tag_area()` allocated one 0x10000 page inside the tag area.
3. Per squad: a 16-byte `character_palette_choice_block` entry with `character type = 25`, then the
   108-byte cell with its `character type` block pointing at that entry.
4. Each squad's `designer.cells` was set to `count = 1` and a contracted pointer to its new cell.

Our parser's verdict on the result was clean:

```
REPARSE: tags=13291 groups=235 named=13287 sids=65672 warnings=[]
checksum verify: (933310930, 933310930, True)
char[8107] -> objects\characters\spartans\spartans
palette[25] <- sur_fireteam_01.D0(n=4,chance=1); sur_fireteam_02.D0(n=4,chance=1)
```

An incidental proof that the writes landed exactly where intended: the grown file's checksum is
*identical* to its parent's. That is not a bug. The two squads received byte-identical cell and
choice blobs, so every XOR term cancels except four pointers, and
`(0x72C00000 ^ 0x72C00020) ^ (0x72C00004 ^ 0x72C00024) = 0x20 ^ 0x20 = 0`.

### Then Blamite refused to load it

```
FATAL: InvalidOperationException: Segment size is too large
   at Blamite.IO.FileSegmenter.RecalculateActualSizes(InternalSegment startSegment)   FileSegmenter.cs:342
   at Blamite.IO.FileSegmenter.DefineSegment(...)                                     FileSegmenter.cs:146
   at Blamite.IO.FileSegmenterExtensions.WrapSegment(...)                             FileSegmenterExtensions.cs:19
   at Blamite.Blam.ThirdGen.Localization.ThirdGenLanguage.Load(...)                   ThirdGenLanguage.cs:64
   at Blamite.Blam.ThirdGen.Localization.ThirdGenLanguageGlobals.LoadLanguages(...)
   at Blamite.Blam.ThirdGen.ThirdGenCacheFile.LoadLanguageGlobals(IReader reader)     ThirdGenCacheFile.cs:371
   at Blamite.Blam.ThirdGen.ThirdGenCacheFile.Load(IReader reader)                    ThirdGenCacheFile.cs:279
```

Load test across the chain, each with the same trivial probe script:

| map | our parser | Blamite |
|---|---|---|
| `ff70_holdout.map` (pristine copy) | OK, 0 warnings | **loads, probe compiles** |
| `ff70_holdout.spartanally.map` (same-size, 4 bytes) | OK, 0 warnings | **loads, probe compiles** |
| grown, `mode="end"` | OK, 0 warnings | **FATAL: Segment size is too large** |
| grown, `mode="beginning"` | OK, 0 warnings | **FATAL: Segment size is too large** |

Both growth modes fail, so the insertion point is not the issue.

### The invariant Blamite enforces

From `FileSegmenter.RecalculateActualSizes`:

```csharp
segments[i].ActualSize = segments[i + 1].Offset - segments[i].Offset;
if (segments[i].ActualSize < segments[i].Size)
    throw new InvalidOperationException("Segment size is too large");
```

Every declared segment must fit in the distance to the next segment's offset. Two isolating probes,
each a single same-size header field change on an otherwise-loadable file, both trip it:

* tag section size + `virtual size` raised by 0x10000 with the **file length unchanged** → throws.
  Correct of Blamite: the tag segment would overrun the localization segment.
* localization section vaddr raised by 0x10000 alone, file length unchanged → throws. Also correct:
  the locale segment would overrun EOF.

In a properly grown file both changes are present *and* the file is 0x10000 longer, which ought to
satisfy the rule — and it still throws. So there is a residual off-by-something in what
`grow_tag_area` writes, most likely in the interaction between the section table, `virtual size`,
and the six partition entries (`_adjust_partitions`). Pinning it down needs a Blamite-side dump of
the constructed segment table; adding that to `tools/compile/Program.cs` is the natural next task
and should be short.

**Until then, treat `grow_tag_area` as unsafe and do not ship anything it produces.**

### RESOLVED, 2026-11-23

The guess above ("partitions / virtual size") was wrong. The Blamite-side segment dump
(`hsc-compile --load-only`, `BLAMITE_SEGMENT_DUMP=1`) named the pair immediately: segment 3,
the **tag data segment**, declared `virtual size` 0x6F00000 at file 0x1FFE000 while segment 9,
**language 0's locale index table**, still resolved to file 0x8EEE000 — 0x6EF0000 away, short by
exactly the growth.

Cause: Blamite resolves a pointer into an interop section as `pointer - section.vaddr +
(section.vaddr + mask)` = **`pointer + mask`** (`BasedPointerConverter.PointerToOffset`), so the
vaddr cancels. `grow_tag_area` restored the `file offset = vaddr + mask` identity for the
localization section by **bumping its vaddr** and keeping the mask, which left every locale
pointer in `matg` resolving to the *pre-growth* offsets while the data had moved forward.

Fix: in `reach_write.grow_tag_area` step 4, a section that moves in the file keeps its virtual
address and adds the delta to its **mask**. No pointer anywhere has to be rewritten. The header
byte-diff of a grown cache now shows the localization *mask* at 0x4DA changing and the
localization *vaddr* at 0x4F6 unchanged — the inverse of the broken output.

Both growth modes now load in Blamite, resolve all 12 language packs and 100,261 locale strings
identically to the original, and compile a probe script. `CacheWriter.save()` writes through a
temporary file and only publishes it after `hsc-compile --load-only` accepts it, so the gate this
section asked for is mandatory rather than advisory.

---

## 5. `fe-objects.txt` versus what Holdout actually has

All 54 entries were checked against the live cache. **1 satisfied, 53 missing.**

| kind | missing | repurposable? |
|---|---|---|
| `trigger_volume` | 26 | **No.** Holdout's 24 volumes are 2 garbage collectors, 1 soft safe zone and 21 kill volumes. A kill volume cannot be a purchase kiosk, and a new one needs a world-space box authored against the BSP. |
| `object_name` | 10 | **No.** `dm_fe_pod_01`, `sc_fe_pelican`, `sc_fe_turret_01`, `sc_fe_ghost` … name placed objects that do not exist in this map. |
| `ai_squad` | 10 | **Mostly yes.** The 5 `sq_fe_*` map onto `sur_fireteam_01..06`. The 4 stock `sq_sur_ghost_*`/`sq_sur_wraith_*` references must be rewritten to Holdout's `sq_sur_banshee_01/02` and `sq_sur_sniper_01..04`. `sq_fe_odst/driver` cannot — the fireteam squads have 0 spawn points. |
| `ai_objective` | 3 | **Partly.** `obj_fireteams` exists with 1 task; the design wants 3 roles. More tasks need growth *and* zone/area bindings. |
| `ai_squad_group` | 2 | **One.** `gr_unsc_reinforcements` → `gr_survival_fireteams` reparented to root. There is no second spare group for `gr_unsc_followers`. |
| `starting_profile` | 2 | **N/A.** This definition set has no starting-profiles block. Ally weapons must come from the cell's `initial weapon` block out of the 23-entry weapon palette instead. |

### The script functions that make most of this avoidable

Checked directly against `reachmcc_u13.xml`:

| function | opcode | signature | use |
|---|---|---|---|
| `objects_distance_to_object` | 0x0B2 | `(object_list, object) -> real` | **replaces a purchase trigger volume with a proximity test to an object that already exists** |
| `volume_test_objects` | 0x045 | `(trigger_volume, object_list) -> boolean` | what the current design uses; needs the 26 new volumes |
| `ai_set_team` | 0x1E4 | `(ai, team) -> void` | flip a squad to a friendly team **at runtime — no tag patch needed** |
| `ai_allegiance` | 0x1CD | `(team, team) -> void` | make the ally team friendly to the players |
| `ai_living_count` | 0x1E8 | `(ai) -> short` | the cap check. **Note the argument is `ai`, not a string** — `research/14`'s `ai_living_count "gr_survival_marines"` is the decompiler quoting a squad-group reference, which compiles to a datum index. The group's *name* is irrelevant at runtime, so no rename is required. |
| `campaign_metagame_award_points` | 0x24C | `(player, long) -> void` | score deduct with a negative value, charged to the buyer |
| `ai_place`, `ai_place_in_limbo` | 0x1A7, 0x1A9 | `(ai) -> void` | placement |
| `survival_wave_living_count` | — | **not a function** | it is one of the map's 377 stock *scripts*; referencing it is fine, and `research/14` is right that it should be left stock |

Holdout already has up to 20 usable interaction points for proximity purchases:
`sc_hack_laser`, `sc_hack_rocket`, `sc_hack_sniper`, `sc_hack_target`, `sc_resupply_01..09`,
`ammo_crate0/1`, `health_pack0..5`, and the player-operated `generator_switch0..2` device machines.

**Rewriting purchases as distance tests or device activations against those names removes all 26
missing trigger volumes and most of the 10 missing object names.** That is the single largest
reduction available, and it needs no tag growth at all.

---

## 6. The script write path

`SaveScripts` was not exercised, because the prerequisite is not yet met. Blamite rebuilds the
*whole* script table from the text it is handed, so a real write must supply Holdout's complete
script, not a fragment.

* The checked-in decompiles are **not** complete: `research/_raw/hsc/ff70_holdout.hsc` has 71
  scripts / 31 globals and `global_firefight.hsc` has 145 / 134 — 216 and 165 against the cache's
  **377 and 205**. Writing from them would delete 161 scripts.
* `tools/hsc/decompile.py` **does** produce the complete table from the real cache once it is given
  addressing and a string-id table: **377 scripts, 205 globals, 20,164 expressions, and exactly one
  unresolved marker** (`<!SID:0x00080336!>`) in 186 KB of output.

```bash
# base-va = 0 - meta_offset + virtual_base ;  scnr-va from the parser
python3 tools/hsc/decompile.py ~/Desktop/build/ff70_holdout.map \
  --variant reachmcc_u13 --table tools/hsc/tables/reachmcc_u13.xml \
  --base-va 0x1C7112000 --scnr-va 0x1CB94A03C \
  --stringids build/holdout/stringids.json \
  --out build/holdout/ff70_holdout_decompiled.hsc
```

The stock round-trip compile could not be attempted on the grown map because Blamite would not load
it; it should be re-run against `ff70_holdout.spartanally.map`, which Blamite does load. That test —
**does Holdout's own decompiled script recompile unchanged?** — is the gate for every script write
and is now one command away.

---

## 7. Reproducible sequence

```bash
PROJ="$HOME/Desktop/Firefight Evolved Expanded"; cd "$PROJ"
find . -name __pycache__ -prune -exec rm -rf {} +

chmod a-w ~/Desktop/ff70_holdout.map
cp -n ~/Desktop/ff70_holdout.map ~/Desktop/build/ff70_holdout.map
shasum -a 256 ~/Desktop/ff70_holdout.map ~/Desktop/build/ff70_holdout.map

python3 build/logs/inv_holdout.py          # scenario block census
python3 build/logs/squads_holdout.py       # 31 squads + 10 groups, parents and cells
python3 build/logs/charunit.py             # char -> unit for every character
python3 build/logs/palette_use2.py ~/Desktop/build/ff70_holdout.map   # finds the unused palette slot
python3 build/logs/objcheck.py             # fe-objects.txt vs the cache
python3 build/logs/repoint_plan.py         # prints the exact --set selector

python3 tools/patch/patch_map.py ~/Desktop/build/ff70_holdout.map \
  --set '@0x73AA6A8:u32=0x8DC525EC' --allow-unmapped --apply \
  --out ~/Desktop/build/ff70_holdout.spartanally.map
python3 build/logs/verify_repoint.py
python3 build/logs/cks.py ~/Desktop/build/ff70_holdout.spartanally.map

# cross-check with the reference implementation - do this for EVERY output
cd tools/compile
export DOTNET_ROLL_FORWARD=LatestMajor DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
export BLAMITE_FORMATS="$PWD/bin/Release/net8.0/Formats"
dotnet bin/Release/net8.0/hsc-compile.dll --formats "$BLAMITE_FORMATS" \
  --hsc ../../build/logs/probe_ok.hsc --xml ../hsc/tables/reachmcc_u13.xml \
  --map ~/Desktop/build/ff70_holdout.spartanally.map

# reproduces the rejected growth, for whoever debugs the segment table
cd "$PROJ" && python3 build/logs/addcell.py        # mode="end"
python3 build/logs/addcell_begin.py                # mode="beginning"
```

---

## 8. Next steps, in order of leverage

1. **Add a segment-table dump to `tools/compile/Program.cs`** and run it on a grown cache. Blamite's
   rule is known exactly; one dump should show which declared size overruns which neighbour, and
   that unblocks every structural edit. Everything else is waiting on this.
2. **Make Blamite a mandatory gate.** Our parser passed all four files; Blamite passed two. Any
   writer output must load in Blamite before it is called verified, let alone shipped.
3. **Re-run the stock script round-trip** on `ff70_holdout.spartanally.map`. If Holdout's own
   decompiled 377 scripts do not recompile, no script write is possible and the project needs to
   know now.
4. **Rewrite purchases as proximity/device tests** against `sc_hack_*`, `sc_resupply_*`,
   `ammo_crate*`, `health_pack*` and `generator_switch*`. Removes 26 trigger volumes and most of the
   10 object names from the critical path.
5. **Move team and allegiance into the script** via `ai_set_team` / `ai_allegiance` rather than
   patching squad `team` fields. Fewer tag writes, same result.
6. **Split the `mcc-u8+` variant** in `reach_cache.py` into U8/U9 (masks 0x4AC) and U10+/U13
   (masks 0x4CC) before anyone opens a non-U13 cache.

---

## 9. Files and integrity

| path | state |
|---|---|
| `~/Desktop/ff70_holdout.map` | source, now `chmod a-w`, sha256 `c0b8a30f0a1cdc6f…` unchanged |
| `~/Desktop/build/ff70_holdout.map` | working copy, byte-identical to the source |
| `~/Desktop/build/ff70_holdout.spartanally.map` | **verified** by our parser *and* Blamite. Same-size `char`→`unit` repoint only. Functionally inert until a cell references palette entry 25. |
| `~/Desktop/build/ff70_holdout.spartanally.map.patch.json` | revert manifest |
| `~/Desktop/build/ff50_park.map` | Beachhead working copy from `research/18`, byte-identical to its source |
| grown maps (`stage2`, `stage3`, `begin`) | **deleted.** Blamite rejects them; reproducible from `build/logs/addcell*.py`. |
| `build/holdout/ff70_holdout_decompiled.hsc` | complete 377-script / 205-global decompile, 1 unresolved marker |
| `build/holdout/stringids.json` | 60,924 resolved string ids, needed by the decompiler |
| `build/logs/` | every script and log behind the numbers above |

`~/Desktop/ff50_park.map` and `~/Desktop/ff_unearthed.map` were not written to. `ff_unearthed.map`
was never opened.
