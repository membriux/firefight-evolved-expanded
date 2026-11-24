# 17 — Stock map teardown: eight real Halo: Reach MCC Firefight caches

First contact between our tooling and real `.map` bytes. Everything in this document
was read out of the shipped caches; nothing here is inferred from scripts unless the
sentence says so. The eight source files were opened read-only and never written.

| | |
|---|---|
| Sources | `~/Desktop/ff10_prototype.map`, `ff20_courtyard`, `ff30_waterfront`, `ff45_corvette`, `ff50_park`, `ff60_airview`, `ff60_icecave`, `ff70_holdout` |
| Artifacts | `extracted/<mapname>/` (header, tag tables, tag blobs, string tables, squad inventory, decompiled scripts) |
| Tools used | `tools/map/parse_map.py` + `reach_cache.py`, `tools/hsc/decompile.py`, `tools/map/dump_squads.py`, and two new helpers added by this task (`tools/map/squad_inventory.py`, `tools/map/sid_table_for_scripts.py`) |
| Not touched | `~/Desktop/ff_unearthed.map`, and the pre-existing top-level `extracted/*.json` / `extracted/tags/` / `extracted/hsc/` artifacts, which belong to the Unearthed work |

---

## 1. Parser validation against real bytes

### 1.1 Three real defects, all found and fixed

The parser did **not** work on the first real map. It failed on `ff10_prototype.map`
with exit code 2 and the message:

```
MALFORMED CACHE FILE
tag data area offset 0x103249000 is outside the file (0xB5C9000 bytes)
```

**Defect 1 — missing 32-bit truncation on the interop section mask
(`reach_cache.py`, `_read_header`, formerly line 915; same arithmetic also at line 841
inside `_score_variant`).** This was a hard parse failure: no map could be opened.

The tag-data file offset is `section[SECTION_TAG].virtual_address + offset_mask`. In a
real cache the mask is a **32-bit wrapping delta and is usually negative**. For
`ff10_prototype`:

| section | stored vaddr | size | mask | file offset (mask applied mod 2^32) |
|---|---|---|---|---|
| 0 debug | `0x0CD1E000` | `0x00383000` | `0xF32EC000` | `0x0000A000` |
| 1 resource | `0x00000000` | `0x02EBC000` | `0x0038D000` | `0x0038D000` |
| 2 tag | `0x04D8E000` | `0x08010000` | `0xFE4BB000` | `0x03249000` |
| 3 localization | `0x04A1E000` | `0x00370000` | `0x0683B000` | `0x0B259000` |

The four results are exactly contiguous from the end of the `0xA000` header to EOF
(`0xA000 + 0x383000 = 0x38D000`, … , `0xB259000 + 0x370000 = 0xB5C9000` = file size),
which is independent proof the mask semantics are right. Python's unbounded integers
meant `0x4D8E000 + 0xFE4BB000` produced `0x103249000` instead of `0x03249000`. Fixed by
masking with `0xFFFFFFFF` in both places, plus the same fix in `debug_to_offset()`
(line 970) where the debug-section mask is added to string/file-table pointers.

**Defect 2 — `cache_build_date_high` / `_low` are swapped in the `mcc-u8+` layout
(`reach_cache.py`, `V_MCC_U8` fields, offsets `0x50` / `0x54`).** Not fatal; it made
`build_date` silently report `-` on every map. The real header stores a little-endian
FILETIME, so `0x50` is the **low** dword and `0x54` the **high** dword. With the fields
the right way round the dates decode cleanly (see §1.3) and match the build string.
Only the `mcc-u8+` layout was changed — we have no real 2019/U3 cache to check those
against, so they were left alone.

**Defect 3 — the `scnr` script-table plausibility gate rejects real data
(`tools/hsc/decompile.py`, `header_plausible`, formerly line 459).** Not a parser bug
but it blocked step 5 entirely: the `reachmcc_u13` layout read a perfectly good header
(359 scripts, 197 globals, 19261 expression datums) and was then thrown out with
`only 54/65 sampled expression types are known`. Cause: the shipped cache keeps the
whole `hs_syntax_datum` array, and **about a fifth of it is unallocated and filled with
the engine's `0xBA` free-datum pattern** (`ff10_prototype`: 3899 of 19261 nodes). Those
records are not expressions. The gate now skips any datum whose bytes `2..0x18` are all
`0xBA`; with them excluded the remaining sample is 100% known types.

After the three fixes the synthetic suite still passes **195 assertions, 0 failures**.
Note that the suite did *not* catch defects 2 or 3 and could not catch defect 1, because
its synthetic headers use zero or small positive offset masks, a symmetric build-date
value, and fully-populated script arrays. Real caches use none of those.

### 1.2 Per-map parse result

All eight parse cleanly after the fix: exit 0, `tags` index magic verified, footer magic
present, **zero parser warnings on all eight**.

| map | name | parsed | build string | header layout | tags | groups | checksum |
|---|---|---|---|---|---|---|---|
| ff10_prototype | Overlook | yes | `Jun 21 2023 15:35:31` | `mcc-u8+` | 14650 | 235 | `0x5C342DC5` |
| ff20_courtyard | Courtyard | yes | `Jun 21 2023 15:35:31` | `mcc-u8+` | 13879 | 235 | `0xFAF20BAF` |
| ff30_waterfront | Waterfront | yes | `Jun 21 2023 15:35:31` | `mcc-u8+` | 14181 | 235 | `0xE147B736` |
| ff45_corvette | Corvette | yes | `Jun 21 2023 15:35:31` | `mcc-u8+` | 13146 | 235 | `0x069A0EDA` |
| ff50_park | Beachhead | yes | `Jun 21 2023 15:35:31` | `mcc-u8+` | 14034 | 235 | `0x09B9439A` |
| ff60_airview | Outpost | yes | `Jun 21 2023 15:35:31` | `mcc-u8+` | 14547 | 235 | `0x85291A30` |
| ff60_icecave | Glacier | yes | `Jun 21 2023 15:35:31` | `mcc-u8+` | 13189 | 235 | `0x42E0A954` |
| ff70_holdout | Holdout | yes | `Jun 21 2023 15:35:31` | `mcc-u8+` | 13291 | 235 | `0x3CF70B92` |

The build string resolves through our flattened `Engines.xml` table to
**Halo: Reach MCC Update 13**, engine version 13, little-endian, header size `0xA000`,
pointer expansion `virtual = (stored << 2) + 0x50000000`.

Supporting header fields:

| map | cache type | internal name | tag-data file offset | tag-data size | virtual base | stringIDs | null tags |
|---|---|---|---|---|---|---|---|
| ff10_prototype | campaign/single player | `ff10_prototype` | `0x3249000` | `0x8010000` | `0x1C7FF0000` | 71288 | 2 |
| ff20_courtyard | campaign/single player | `ff20_courtyard` | `0x32DA000` | `0x7870000` | `0x1C8790000` | 52675 | 1 |
| ff30_waterfront | campaign/single player | `ff30_waterfront` | `0x3971000` | `0x7AB0000` | `0x1C8550000` | 57069 | 1 |
| ff45_corvette | campaign/single player | `ff45_corvette` | `0x2B6F000` | `0x6710000` | `0x1C98F0000` | 62116 | 1 |
| ff50_park | campaign/single player | `ff50_park` | `0x2925000` | `0x77A0000` | `0x1C8860000` | 70659 | 1 |
| ff60_airview | campaign/single player | `ff60_airview` | `0x2163000` | `0x8020000` | `0x1C7FE0000` | 66644 | 2 |
| ff60_icecave | campaign/single player | `ff60_icecave` | `0x2C43000` | `0x6D90000` | `0x1C9270000` | 65804 | 1 |
| ff70_holdout | campaign/single player | `ff70_holdout` | `0x1FFE000` | `0x6EF0000` | `0x1C9110000` | 65672 | 1 |

Scenario paths are all of the form `levels\firefight\<name>\<name>`. Every map reports
the same seven global tags (`draw`, `gpix`, `matg`, `play`, `scnr`, `ugh!`, `zone`) and
17 stringID namespaces resolved from the cache's own namespace table. The one or two
null tag-table entries per map are the normal Reach pattern for tags that live in a
shared cache rather than in the level.

### 1.3 Are these stock?

Yes, and the evidence is tight. Cache build dates, decoded after fixing defect 2:

| map | cache build date (UTC) |
|---|---|
| ff70_holdout | 2023-06-22T01:20:51.46 |
| ff45_corvette | 2023-06-22T01:20:56.35 |
| ff60_icecave | 2023-06-22T01:20:57.43 |
| ff20_courtyard | 2023-06-22T01:21:03.74 |
| ff50_park | 2023-06-22T01:21:05.04 |
| ff30_waterfront | 2023-06-22T01:21:08.84 |
| ff60_airview | 2023-06-22T01:21:10.43 |
| ff10_prototype | 2023-06-22T01:21:11.30 |

All eight were built inside a **twenty-second window** on the same machine, which is
what a single retail packaging pass looks like and is not something a modder reproduces.
Further stock indicators: identical build strings; identical tag-group table (235 groups)
in all eight; the exact same 159 `sqtm`, 32 `wave`, 1 `scnr`, 1 `smdt`, 1 `msit`, 1 `mulg`,
1 `matg` counts in every map; sections laid out contiguously with no slack; header file
size matching the real file size on all eight (no stale size, which mod tools routinely
leave behind).

**On the size difference versus Unearthed.** These eight are 153–193 MB on disk
(`0x925E000` for `ff70_holdout` up to `0xB790000` for `ff30_waterfront`; the 146–184 MB
figures in the task brief are the same files counted in MiB) against Unearthed's 870 MB. Nothing about the eight looks
non-stock on that account — their tag-data areas are 103–128 MB and their tag counts
13.1k–14.7k, all mutually consistent. The eight are *single* Firefight levels. A ~5×
larger cache is the signature of a map that has absorbed shared/campaign content or
many imported tag trees, i.e. the oddity is on Unearthed's side, not here. That is
consistent with Unearthed's `scnr` carrying a `dw4\…` character palette plus imported
`objects\characters\kf_ai\marine\…` characters, which these eight do not have.

### 1.4 Known parser limitation surfaced by real data

`estimate_sizes()` derives a tag's size from the next tag's virtual address. Real caches
**deduplicate identical tag data**, so several tag-table entries share one address. Three
`char` tags per map therefore get an estimated size of 0 and are skipped by `--extract`:
on `ff10_prototype` those are `brute\ai\stimuli\brute_berserk`,
`elite\ai\stimuli\elite_berserk` (both at `0x1CDECB814`, shared with
`grunt\ai\stimuli\grunt_kamikaze`) and `grunt\ai\stimuli\grunt_aggressive` (at
`0x1CE502C3C`, shared with `jackal\ai\stimuli\skirmisher_aggressive`). This is not a
parse error and it loses no data — the bytes are extracted under the other entry's name —
but a future fix should resolve duplicate addresses to the same blob instead of reporting
zero size. Extraction otherwise reports **0 errors** on all eight maps.

---

## 2. Extracted artifacts

`extracted/<mapname>/` for each of the eight contains:

* `header.json` — full parsed header, sections, masks, partitions, index header, counts, diagnostics.
* `tags.tsv` / `tags.json` — the complete tag list (13 146–14 650 rows) with group, path, virtual address, file offset and estimated size.
* `tag_groups.tsv` — all 235 group codes with parents and names.
* `tag_names.txt` — the tag-name (file) table.
* `stringids.txt` — the stringID table (52 675–71 288 entries).
* `tags/` — raw tag blobs plus a JSON sidecar carrying the pointer math for each, for the groups `scnr`, `smdt`, `sqtm`, `wave`, `msit`, `char`, `weap`, `vehi`, `bipd`, `mulg`, `matg`. This includes the single `scnr` (`0x86C` bytes on every map) and the single `smdt` Survival Mode Globals (`0x1C0`–`0x1FC` bytes).
* `squad_inventory.json` — §4 of this document, machine-readable.
* `scnr_squads.json` — the earlier `dump_squads.py` form, kept for cross-checking.
* `scripts/<map>.hsc`, `scripts/<map>.scripts.json`, `scripts/stringids_for_scripts.json` — §5.
* `parse_report.txt`, `manifest.json`.

### 2.1 No map ships HaloScript source

**Stated loudly, because the task asked: none of the eight maps contains an `hsc*` tag.
There is no `scenario_hs_source_file` in any of them, and no tag group whose code begins
`hsc` appears in any of the eight 235-group tables.** Source text was stripped at
packaging. Decompilation is the only route, and §5 shows it works.

Tag-group census for the groups we care about, identical in structure across all eight:

| map | scnr | smdt | sqtm | wave | msit | char | bipd | mulg | matg | weap | vehi | **hsc\*** | ai\*\* |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ff10_prototype | 1 | 1 | 159 | 32 | 1 | 61 | 14 | 1 | 1 | 42 | 15 | **0** | 0 |
| ff20_courtyard | 1 | 1 | 159 | 32 | 1 | 62 | 14 | 1 | 1 | 39 | 11 | **0** | 0 |
| ff30_waterfront | 1 | 1 | 159 | 32 | 1 | 60 | 13 | 1 | 1 | 37 | 8 | **0** | 0 |
| ff45_corvette | 1 | 1 | 159 | 32 | 1 | 61 | 14 | 1 | 1 | 38 | 10 | **0** | 0 |
| ff50_park | 1 | 1 | 159 | 32 | 1 | 60 | 13 | 1 | 1 | 42 | 16 | **0** | 0 |
| ff60_airview | 1 | 1 | 159 | 32 | 1 | 61 | 14 | 1 | 1 | 44 | 19 | **0** | 0 |
| ff60_icecave | 1 | 1 | 159 | 32 | 1 | 61 | 14 | 1 | 1 | 40 | 12 | **0** | 0 |
| ff70_holdout | 1 | 1 | 159 | 32 | 1 | 61 | 14 | 1 | 1 | 39 | 9 | **0** | 0 |

---

## 3. THE DECISIVE QUESTION — the Marine `char` tag

### 3.1 Answer

**No. Not one of the eight maps contains a `char` tag for a Marine, an ODST, or any
other UNSC / human biped. All 60–62 `char` tags per map are Covenant, generic, or null
characters.**

| map | name | `char` tags | Marine `char`? | ODST `char`? | any UNSC/human `char`? |
|---|---|---|---|---|---|
| ff10_prototype | Overlook | 61 | **NO** | **NO** | **NO** |
| ff20_courtyard | Courtyard | 62 | **NO** | **NO** | **NO** |
| ff30_waterfront | Waterfront | 60 | **NO** | **NO** | **NO** |
| ff45_corvette | Corvette | 61 | **NO** | **NO** | **NO** |
| ff50_park | Beachhead | 60 | **NO** | **NO** | **NO** |
| ff60_airview | Outpost | 61 | **NO** | **NO** | **NO** |
| ff60_icecave | Glacier | 61 | **NO** | **NO** | **NO** |
| ff70_holdout | Holdout | 61 | **NO** | **NO** | **NO** |

Across all eight maps there are exactly **62 distinct `char` tag paths**, and the union
is entirely:

* `ai\generic`, `ai\generic_turret`, and 16 `ai\stimuli\generic_*` stimulus characters;
* `objects\characters\brute\ai\*` (4 characters + 3 stimuli);
* `objects\characters\elite\ai\*` (7 characters + 6 stimuli);
* `objects\characters\engineer\ai\engineer`;
* `objects\characters\grunt\ai\*` (5 characters + 3 stimuli);
* `objects\characters\hunter\ai\hunter`;
* `objects\characters\jackal\ai\*` (8 characters, jackal + skirmisher, + 4 stimuli);
* `objects\characters\null\ai\null_cov_default`, `null_cov_flying`.

The only path that matches a human/UNSC word search is
`objects\characters\elite\ai\elite_pilot` (Courtyard only), which is a Covenant Elite
pilot, not a UNSC character. Note also that there is **no `null_human_default` or
`null_human_flying`** in any of the eight — Unearthed has those, these do not.

**Consequence, stated as the task framed it: a map with no Marine `char` tag cannot
spawn a Marine, no matter what any script says. Marines must be *added* to all eight
maps; none of them can be unlocked by scripting alone.**

### 3.2 But a human-shaped ally is reachable with a four-byte, same-size edit

This is the single most useful thing the tag data gave up, so it belongs next to the
"no" above.

The `char` tag definition (`research/_raw/reach-defs/character.json`,
`character_struct_definition`, walked size `0x270` matching the declared size) puts a
`unit` tag reference at **`char + 0x14`**, whose tag datum sits at **`char + 0x20`**.
Verified against real bytes: `objects\characters\grunt\ai\grunt` has group `bipd` and
datum `0x8A9122AC` at `+0x20`, resolving to tag `objects\characters\grunt\grunt`; the
same holds for `elite` → `elite_ai\elite_ai` and `hunter` → `hunter\hunter`.

And the biped palette already ships a human body on **all eight maps**:

| map | human-shaped `bipd` | tag index | datum |
|---|---|---|---|
| ff10_prototype | `objects\characters\spartans\spartans` | 11064 | `0x94632B38` |
| ff20_courtyard | same | 10176 | `0x8FF127C0` |
| ff30_waterfront | same | 10519 | `0x914C2917` |
| ff45_corvette | same | 9722 | `0x8E1825FA` |
| ff50_park | same | 10194 | `0x906727D2` |
| ff60_airview | same | 10685 | `0x92E829BD` |
| ff60_icecave | same | 9680 | `0x8E0425D0` |
| ff70_holdout | same | 9708 | `0x8DC525EC` |

Every map's `bipd` list is the same 13–14 entries: `brute`, `brute_chieftain`, `elite`,
`elite_ai`, `grunt`, `hologram_elite`, `hologram_jackal`, `hologram_spartan`, `hunter`,
`jackal`, `monitor_editor`, `null`, `spartans` — plus `engineer` on all but
`ff30_waterfront` and `ff50_park`, which have 13 bipeds instead of 14.

So repointing one low-value existing `char` tag's `unit` datum at the `spartans` biped is
a **4-byte in-place patch with zero size change and zero new tags** — no tag-area growth,
no index rebuild. That yields a human-bodied, player-allied AI unit driven by an existing
character's AI parameters. It is *not* a real Marine: no Marine render model, animation
graph or dialogue ships in these caches, so a genuine Marine still requires importing a
`char` plus its `hlmt`/`mode`/`jmad`/`coll`/`phmo`/`udlg` tree. The cheap path and the
faithful path are different jobs, and the cheap path is available on all eight equally.

Character `char` tag sizes, for budgeting an import: smallest 624 bytes
(`ai\generic`), median ≈ 880 bytes, largest 36 428 bytes (`ai\generic_turret`);
the real combat characters sit at 7–8 KB (`elite_ultra` 8008 bytes,
`grunt_ultra` 7912 bytes).

---

## 4. Squad inventory, read from the `scnr` tag

Offsets used here were **derived, not guessed**: `defwalk.Defs.layout()` walks
`research/_raw/reach-defs/scenario.json` and the walked size of every struct used below
equals its declared size. `scenario_struct_definition` (0x858) gives vehicle palette
`0x138`, squad groups `0x38C`, squads `0x398`, character palette `0x3EC`, script string
data `0x41C`, scripts `0x430`, globals `0x43C`, hs syntax datums `0x504`.
`squads_block_struct` (0x6C): name `0x00`, flags `0x20`, team `0x24`, parent `0x26`,
wave placement filter `0x48`, template `0x4C`, designer cells `0x54`, templated cells
`0x60`. `cell_block_struct` (0x6C): name `0x00`, normal-difficulty count `0x10`,
character-type block `0x14`, vehicle `0x46`, variant `0x48`, placement script `0x4C`.
`character_palette_choice_block_struct` (0x10): palette index `0x0C`, chance `0x0E`.
This independently confirms the offsets `tools/map/dump_squads.py` had hardcoded — all
of them were already correct.

### 4.1 Headline table

| map | name | squads | squad groups | cells | empty squads | fireteam squads | **clean** fireteam squads | char palette used / 64 | free palette slots |
|---|---|---|---|---|---|---|---|---|---|
| ff10_prototype | Overlook | 28 | 10 | 18 | 12 | 6 | **6** | 27 | 37 |
| ff20_courtyard | Courtyard | 27 | 9 | 18 | 11 | 6 | **6** | 28 | 36 |
| ff30_waterfront | Waterfront | 32 | 12 | 22 | 12 | 6 | **6** | 26 | 38 |
| ff45_corvette | Corvette | 35 | 5 | 24 | 23 | 6 | **0** | 30 | 34 |
| ff50_park | Beachhead | 29 | 10 | 21 | 12 | 6 | **6** | 26 | 38 |
| ff60_airview | Outpost | 27 | 10 | 29 | 12 | 6 | **6** | 27 | 37 |
| ff60_icecave | Glacier | 24 | 10 | 17 | 10 | 6 | **5** | 26 | 38 |
| ff70_holdout | Holdout | 31 | 10 | 26 | 7 | 6 | **6** | 27 | 37 |

"Clean" means: zero cells, and parented to `gr_survival_fireteams` rather than to any
group whose living count gates the wave end.

Fixed block ceilings from the definitions, which is the real currency when adding
content: squads max 256 per map, squad groups max 130, **character palette max 64**,
cells max 10 per squad, character choices max 8 per cell, `hs_scripts` max 2048,
`hs_globals` max 512, `hs_syntax_datum` max 64512.

### 4.2 Squad groups and membership

Asterisked squads have zero cells.

**ff10_prototype (Overlook)** — groups `gr_survival_all`, `gr_survival_extras`,
`gr_survival_bonus`, `gr_survival_remaining`, `gr_wraith_01`, `gr_wraith_02`,
`gr_survival_phantoms`, `gr_survival_waves`, `gr_survival_fireteams`, `gr_cov_drop_pod`.

* `gr_survival_waves` (8): `sq_sur_wave_01`…`04`, `sq_sur_wave_05*`…`08*`
* `gr_survival_fireteams` (6): `sur_fireteam_01*`…`06*`
* `gr_survival_phantoms` (5): `sq_sur_phantom_01`…`04`, `sq_sur_bonus_phantom` (1 Grunt crew cell each, vehicle `phantom`)
* `gr_cov_drop_pod` (5): `sq_sur_drop_01`…`05` (4 Grunt-heavy or Brute, vehicle `cov_squad_drop_pod`)
* `gr_wraith_01` / `gr_wraith_02` (1 each): `sq_sur_wraith_01` / `_02`, template `sq_camp_wraith`, 2 Elite crew
* `gr_survival_bonus` (1): `sq_ff_bonus*`; `gr_survival_remaining` (1): `sq_sur_remaining*`
* `gr_survival_all` and `gr_survival_extras` exist as groups but have **no member squads**

**ff20_courtyard (Courtyard)** — as Overlook but drop pods are in
`gr_survival_cov_squad_pod` (4), plus `gr_survival_banshees` (2:
`sq_sur_banshee_01`, `_02`), no wraiths. `gr_survival_waves` has 5 of 8 populated.

**ff30_waterfront (Waterfront)** — 12 groups: waves (8, 4 populated), fireteams (6, all
empty), phantoms (5), `gr_survival_cov_drop_pod` (5), `gr_survival_banshees` (2),
`gr_survival_snipers` (2: `sq_sur_sniper_03`, `_04`), `gr_survival_sniper_01` (1),
`gr_survival_sniper_02` (1), bonus (1, empty), remaining (1, empty).

**ff45_corvette (Corvette)** — the outlier. Only 5 groups and a completely different
naming scheme: `gr_survival_extras` (3: `ff_wraith0`, `ff_engineers`,
`ff_startup_grunts`), **`gr_wave_spawns` (22)**, `gr_wave_spawns_bonus` (1: `ff_bonus*`),
`gr_survival_remaining` (1: `ff_remaining*`), and **8 squads with no parent group at all**
(`ff_phantom0`…`3`, `ff_phantom_bonus`, `test_fork`, `test_load`, `test_load2`). The 22
members of `gr_wave_spawns` are `ff_inf_bottom_left0/1`, `ff_inf_bottom_right0/1`,
`ff_inf_top_left0/1`, `ff_inf_top_right0/1`, `ff_inf_top_center0`,
`ff_inf_bottom_center0`, **`ff_elite_fireteam0`…`5`**, and `ff_inf_flying0`…`5`. Only
`ff_inf_bottom_left0` has cells; the other 21 are empty. The six `ff_inf_flying*` squads
are the only squads in any of the eight maps with a non-default **wave placement filter**
(`Flying Infantry`).

**ff50_park (Beachhead)** — waves (8, 4 populated), **`gr_survival_fireteams` (6:
`sq_elite_fireteam_01*`…`06*`)**, phantoms (5), `gr_survival_extras` (4:
`sq_sur_drop_01`…`04`), `gr_survival_wraith_01`/`_02` (1 each), `gr_survival_ghost` (2),
bonus (1, empty), remaining (1, empty).

**ff60_airview (Outpost)** — waves (8, 4 populated), fireteams (6, all empty), phantoms
(5), `gr_survival_ghost_01`/`_02` (1 each), `gr_survival_snipers` (4), bonus (1, empty),
remaining (1, empty). Highest total cell count of the eight (29).

**ff60_icecave (Glacier)** — waves (**9**), `gr_survival_fireteams` (**5**), phantoms (5),
`gr_wraith_01`/`_02` (1 each), `gr_survival_ghost` (1), bonus (1, empty), remaining (1,
empty). The only map with squads on a non-`default` AI team: `sq_sur_phantom_01`…`04`,
`sq_sur_bonus_phantom`, `sq_sur_wraith_01`, `_02`, `sq_ff_bonus` and `sq_sur_ghost_01`
are all on team **`covenant`** (9 of 24 squads).

**ff70_holdout (Holdout)** — the most finished map: **all 8** `gr_survival_waves` squads
have cells, `sq_ff_bonus` has cells, plus phantoms (5), `gr_survival_extras` (4 drop
squads), `gr_survival_banshee_01`/`_02` (1 each), `gr_survival_snipers` (4), fireteams
(6, all empty), remaining (1, empty). Only 7 empty squads in total, and 6 of those are
the fireteams.

### 4.3 Where the tag disagrees with what the scripts implied (research/11)

Confirmed by the tag:

* **`s_sur_wave_squad_count` is declared `4` and set to `6` at startup on all eight maps**, not just the six previously studied (research/11 §4, line 80).
* `gr_survival_waves` does hold eight squads named `sq_sur_wave_01`…`08` on seven of the eight maps (research/11 line 118), and adding a spawn location really is a tag-only change.
* A squad on team `human` is friendly with no script work: every map's startup script contains `(ai_allegiance human player)` and `(ai_allegiance player human)` (research/11 §, line 182). Confirmed in the decompiled text of all eight.
* Six script globals `ai_sur_fireteam_squad0`…`5` exist and are bound at startup (research/11 line 78).

Disagreements and traps the tag exposes:

1. **Glacier has five usable fireteam squads, not six.** research/11 line 516 says the fireteam squads are `sur_fireteam_01`–`06` on five maps and `sq_elite_fireteam_01`–`06` on Beachhead. On `ff60_icecave` the tag parents **`sur_fireteam_06` to `gr_survival_waves`**, not to `gr_survival_fireteams`, flags it **`fireteam absorber`** (not `no wave spawn` like its five siblings), and gives it a live cell with four Brute character choices. The startup script nevertheless still runs `(set ai_sur_fireteam_squad5 "sur_fireteam_06")`. **On Glacier, fireteam slot 5 points at a live enemy wave squad.** Filling it with friendlies would both put them in the wave-counting group and collide with Bungie's own Brute spawn.
2. **Corvette's fireteam squads are all enemy wave-spawn squads.** `ff_elite_fireteam0`…`5` are members of **`gr_wave_spawns`**, the group `ai_place_wave` fills. research/11 rule 1 (line 159) says a friendly squad must never be a member of the wave group; on Corvette all six pre-wired fireteam handles already are. Corvette has **zero** clean fireteam handles despite having the most empty squads (23).
3. **Corvette's group names are not `gr_survival_*`.** It uses `gr_wave_spawns` and `gr_wave_spawns_bonus`. Any script or tooling that matches on `gr_survival_waves` / `gr_survival_bonus` will silently miss on Corvette. research/11's naming conventions table (§, line 502) does not cover this.
4. **Corvette carries leftover development squads.** `test_fork`, `test_load`, `test_load2` are parentless, cell-bearing squads with no counterpart on any other map. `ff_startup_grunts` sits in `gr_survival_extras`.
5. **`gr_survival_all` and `gr_survival_extras` have no member squads on Overlook, Courtyard, Waterfront, Outpost or Glacier.** research/11 line 162 warns that friendly marines inside `gr_survival_extras` would permanently suppress Covenant drop pods on Courtyard, Overlook and Waterfront. The warning is still correct as advice, but the tag shows the group is *currently empty* on those three maps, so the risk is one we would introduce, not one already present. `gr_survival_extras` is populated only on Corvette (3), Beachhead (4) and Holdout (4) — and on Beachhead and Holdout its members are the drop-pod squads.
6. **Wave squads 05–08 are mostly empty in the tag.** Overlook, Waterfront, Beachhead and Outpost populate only 4 of 8; Courtyard and Glacier 5; Holdout all 8. This is not a contradiction — `ai_place_wave` fills the group's squads from the wave template at runtime, so the tag cells in a wave squad are a template slot rather than the live roster — but it does mean "number of populated wave squads" is not the number of spawn locations, and research/11's "random-ish 6 of 8 locations" (line 119) is about group membership, which is 8 everywhere except Glacier's 9.
7. **Squad flags only ever take three values in these eight maps**: `fireteam absorber` (the wave squads, `sq_sur_remaining`, and `sq_ff_bonus` on four maps), `no wave spawn` (the fireteam squads), and `units not enterable by player` (phantom and banshee squads). There is no flag that marks a squad friendly.
8. **Every squad is on AI team `default` except on Glacier**, where nine are on `covenant`. The team field is therefore not what makes stock Firefight enemies hostile — the allegiance calls in the startup script are.

---

## 5. Script decompilation

### 5.1 Validation — passed

`--probe` identified `reachmcc_u13` as the only self-consistent `scnr` layout, which is
the correct answer for a `Jun 21 2023 15:35:31` build, and the layout offsets it uses
(`0x41C`/`0x428`/`0x430`/`0x434`/`0x43C`/`0x440`/`0x504`/`0x508`) match the ones derived
independently from `scenario.json` in §4. The opcode table used is
`tools/hsc/tables/reachmcc_u13.xml`, already present from a previous `--fetch-tables`
run; `campaign_metagame_award_points` is `0x24C` in that table, which is the U13 value.

Addressing used: blob = the whole `.map`, `--base-va = virtual_base - tag_data_offset`,
`--scnr-offset = <scnr tag file offset>`, `--expand-magic 0x50000000`.

Stock-name validation, with script names resolved through a per-map stringID table
(`tools/map/sid_table_for_scripts.py`):

| map | lines | scripts | globals | `survival_mode_begin_new_wave` | `ai_place_wave` | `survival_total_score` | unresolved script names | `UNKNOWN` markers |
|---|---|---|---|---|---|---|---|---|
| ff10_prototype | 6077 | 359 | 197 | 17 | 5 | 8 | 0 | **0** |
| ff20_courtyard | 5966 | 357 | 194 | 17 | 5 | 8 | 0 | **0** |
| ff30_waterfront | 6110 | 364 | 198 | 17 | 5 | 8 | 0 | **0** |
| ff45_corvette | 5290 | 325 | 177 | 17 | 5 | 8 | 0 | **0** |
| ff50_park | 6317 | 377 | 197 | 17 | 5 | 8 | 0 | **0** |
| ff60_airview | 5990 | 347 | 190 | 17 | 5 | 8 | 0 | **0** |
| ff60_icecave | 5564 | 335 | 187 | 17 | 5 | 8 | 0 | **0** |
| ff70_holdout | 6425 | 377 | 205 | 17 | 5 | 8 | 0 | **0** |

All three required stock names appear in all eight. `campaign_metagame_award_points`
and `survival_mode_lives_set` also appear. **Zero** `<!UNKNOWN-FUNCTION!>` or
`<!UNKNOWN-TYPE!>` markers were emitted on any map, and all 325–377 script names
resolved to stock-looking identifiers (`survival_wave_loop`, `survival_wave_spawn`,
`survival_garbage_collector`, `survival_bonus_wave_test`, `survival_mode`,
`survival_ai_limit`, `survival_round_timer`, …). The opcode table is correct and the
output is trustworthy within the limits of a decompiler (names and structure are
reliable; original formatting, comments and macro structure are gone).

### 5.2 The fireteam plumbing is already written

This is the most actionable thing in the scripts. Every map declares six AI globals and
binds them in its startup script:

```
(global ai ai_sur_fireteam_squad0 none)   ; … through ai_sur_fireteam_squad5
...
(script startup void <startup>
  (ai_allegiance human player)
  (ai_allegiance player human)
  ...
  (set ai_sur_fireteam_squad0 "sur_fireteam_01")   ; … through sur_fireteam_06
```

Bindings per map:

| map | fireteam globals bound to |
|---|---|
| ff10_prototype, ff20_courtyard, ff30_waterfront, ff60_airview, ff60_icecave, ff70_holdout | `sur_fireteam_01` … `sur_fireteam_06` |
| ff50_park | `sq_elite_fireteam_01` … `sq_elite_fireteam_06` |
| ff45_corvette | `ff_elite_fireteam0` … `ff_elite_fireteam5` |

Those squads are the zero-cell squads from §4. So the chain
*global → squad handle → empty squad in a non-counting group* already exists in stock
data on six of the eight maps. Filling a cell with a human-bodied character and setting
the squad's team to `human` is the shortest path to an ally, with the allegiance already
established by the startup script.

Caveat from §4.3: on Glacier slot 5 resolves to an enemy wave squad, and on Corvette all
six resolve into `gr_wave_spawns`.

---

## 6. Ranking: cheapest map to add purchasable Marines

### 6.1 What "space in the tag area" actually measures

Measured honestly: **the usable slack inside the tag-data area is zero on all eight
maps.** The four interop sections are exactly contiguous from `0xA000` to EOF, and the
last tag's data runs to the end of the tag section on every map. Growing any tag means
rebuilding the cache, equally on all eight. "Tag-area space" is therefore *not* a
differentiator; the real headroom is in the fixed-maximum blocks and the pre-allocated
script-node array:

| map | free char-palette slots (of 64) | free squad slots (of 256) | free script slots (of 2048) | script datums used / allocated | **free `0xBA` script datums** | script string table bytes |
|---|---|---|---|---|---|---|
| ff10_prototype | 37 | 228 | 1689 | 15362 / 19261 | 3899 | 28328 |
| ff20_courtyard | 36 | 229 | 1691 | 14943 / 18821 | 3878 | 27878 |
| ff30_waterfront | 38 | 224 | 1684 | 15440 / 19373 | 3933 | 28637 |
| ff45_corvette | 34 | 221 | 1723 | 12968 / 16627 | 3659 | 25394 |
| ff50_park | 38 | 227 | 1671 | 15902 / 19888 | 3986 | 30121 |
| ff60_airview | 37 | 229 | 1701 | 15015 / 18841 | 3826 | 28168 |
| ff60_icecave | 38 | 232 | 1713 | 13650 / 17415 | 3765 | 26521 |
| ff70_holdout | 37 | 225 | 1671 | 16169 / 20164 | 3995 | 30065 |

### 6.2 Ranking

Criteria, in the order they matter: (a) clean pre-wired empty squads in a group that does
not gate the wave end; (b) free character-palette slots; (c) free script datums and
script slots, i.e. how much new script can be added without resizing the node array;
(d) how much other Firefight infrastructure is already authored, so adding allies is the
only new work; (e) traps.

Every map scores identically on the one thing that matters most — **none has a Marine
`char` tag, and all eight have the `spartans` biped plus 34–38 free character-palette
slots** — so the ranking is about the surrounding plumbing.

1. **`ff70_holdout` (Holdout) — best target.** 6 clean empty fireteam squads already bound to `ai_sur_fireteam_squad0`…`5`; the **most free script datums of the eight (3995)** and the second-largest script string table; and it is the most completely authored map — all 8 wave squads and the bonus squad have cells, so nothing about enemy spawning needs touching. Only 7 empty squads in total and 6 of them are exactly the handles we want. `gr_survival_extras` is populated (the 4 drop squads), so keep friendlies out of it.
2. **`ff50_park` (Beachhead).** 6 clean fireteam squads (`sq_elite_fireteam_01`…`06`), joint-best free palette slots (38), 3986 free script datums, largest script string table (30121 bytes). Costs: the non-standard fireteam squad names, and `gr_survival_extras` holds the 4 drop squads.
3. **`ff10_prototype` (Overlook).** 6 clean fireteam squads with the canonical `sur_fireteam_01`…`06` names, 37 free palette slots, 3899 free datums, and both `gr_survival_all` and `gr_survival_extras` are *empty*, so the drop-pod suppression hazard from research/11 does not exist until we create it. Largest tag-data area of the eight after Outpost.
4. **`ff60_airview` (Outpost).** 6 clean fireteam squads, canonical names, 37 free palette slots, 3826 free datums, `gr_survival_extras` empty. Slightly busier scenario (4 sniper squads, 2 ghosts) and the highest live cell count (29), so more existing behaviour to avoid disturbing.
5. **`ff30_waterfront` (Waterfront).** 6 clean fireteam squads, joint-best 38 free palette slots, 3933 free datums, `gr_survival_extras` empty. Ranked below Outpost only because it has the most squad groups (12, including three separate sniper groups), i.e. the most moving parts to understand.
6. **`ff20_courtyard` (Courtyard).** 6 clean fireteam squads, but the **fewest free palette slots after Corvette (36)** and the fewest free script datums of the six maps with clean handles (3878). `gr_survival_extras` empty. Its stringID table is also by far the smallest of the eight (52675 against 57069–71288), which is a curiosity worth checking rather than a measured constraint.
7. **`ff60_icecave` (Glacier).** Only **5** clean fireteam squads; `sur_fireteam_06` is a live enemy wave squad that the startup script still binds to fireteam slot 5, so slot 5 is actively dangerous. Also the only map with squads on team `covenant`, so team handling differs here. 38 free palette slots and 3765 free datums are fine, but the trap drops it to seventh.
8. **`ff45_corvette` (Corvette) — worst target.** **Zero** clean fireteam squads: all six `ff_elite_fireteam0`…`5` are members of `gr_wave_spawns`, so every pre-wired handle violates the "never in the wave group" rule. Group names are `gr_wave_spawns` / `gr_wave_spawns_bonus` rather than `gr_survival_*`, so shared tooling and scripts need a special case. Fewest free palette slots (34) and fewest free script datums (3659). It does have 8 parentless squads and 23 empty squads, which is genuine room — but using them means authoring a new squad group and a new AI objective from scratch, which is exactly the expensive path.

### 6.3 Work that is unavoidable on every map

* Import or author a Marine/ODST `char` tag plus its unit tree, or accept the 4-byte `spartans`-biped repoint described in §3.2 as a stand-in.
* Add the character to the scenario's character palette (34–38 free slots everywhere).
* Fill a cell on a clean empty squad and put that squad on AI team `human` (allegiance is already set up in every startup script).
* Per research/11, do not parent friendly squads to `gr_survival_all`, `gr_survival_waves`, `gr_survival_bonus`, `gr_survival_remaining` or `gr_survival_extras`; the existing `gr_survival_fireteams` group satisfies this on six maps.
* AI tasks: every task in `obj_survival` is filtered to a `gr_survival_*` group, so a friendly squad still needs a new objective with a follow task authored in the tag. That is unchanged by this teardown.

---

## 7. Changes made to our tooling by this task

| file | change |
|---|---|
| `tools/map/reach_cache.py` | 32-bit truncation on the interop-section offset mask, in `_score_variant` (tag-section probe), `_read_header` (`meta_offset`) and `debug_to_offset`. Without it no real map parses. |
| `tools/map/reach_cache.py` | `V_MCC_U8`: `cache_build_date_low` is at `0x50` and `cache_build_date_high` at `0x54`, not the other way round. |
| `tools/hsc/decompile.py` | `header_plausible` now skips `hs_syntax_datum` records filled with the engine's `0xBA` free pattern before scoring expression types. Without it the correct `reachmcc_u13` layout is rejected on every real map. |
| `tools/map/squad_inventory.py` | New. Squad / squad-group / character-palette / cell inventory with flags, teams, wave placement filters and per-choice chances, using offsets derived from `scenario.json`. |
| `tools/map/sid_table_for_scripts.py` | New. Emits the `{stringID: name}` JSON that `decompile.py --stringids` needs in order to name scripts, since the script table stores full stringID values rather than plain indices. |

`python3 tools/map/parse_map.py --self-test` still reports **195 passed, 0 failed** after
these changes. It did not catch any of the three defects, so it should grow cases for a
negative offset mask, a swapped-order build date, and a partly-`0xBA` script node array.
