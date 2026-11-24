# 20 — Stage-2 replication across the seven remaining stock maps

**Date:** 2026-11-23
**Reference deliverable replicated:** `~/Desktop/build/ff70_holdout.stage2.map` (research/19)
**Outputs:** `~/Desktop/build/<map>.stage2.map`, seven files
**Verdict: 7 of 7 passed the Blamite gate and all eight verification checks.**

This document replicates, without redesign, the edit proven on Holdout in research/19:
a same-size `char`→`unit` repoint of an unused character-palette entry onto the Spartan
biped, plus one added 4-actor designer cell on each of two dormant fireteam squads,
written through `reach_write.CacheWriter.save()` with the mandatory fail-closed Blamite
gate.

Nothing about `reach_write.grow_tag_area()`, the offset-mask rule or the gate was
changed. The source maps were opened read-only and are byte-identical afterwards;
`~/Desktop/ff_unearthed.map` was never opened, and
`~/Desktop/build/ff70_holdout.stage2.map` was never written.

---

## 1. Headline table

| map | name | unused `char` entry used | biped repointed | fireteam squads filled | real parent group | reparent patch needed | cells added | Blamite | all checks |
|---|---|---|---|---|---|---|---|---|---|
| `ff10_prototype` | Overlook | `[25]` `null\ai\null_cov_default` (tag 9656) | `spartans\spartans` (tag 11064) | `sur_fireteam_01`, `_02` | `gr_survival_fireteams` → `gr_survival_waves` → `gr_survival_all` | **yes** `@0x58DD648:i16=-1` | 2 × 1 cell × 4 actors | **PASS** | 8/8 |
| `ff20_courtyard` | Courtyard | `[24]` `null_cov_default` (tag 8775) | `spartans\spartans` (tag 10176) | `sur_fireteam_01`, `_02` | `gr_survival_fireteams` → `gr_survival_waves` → `gr_survival_all` | **yes** `@0x5864988:i16=-1` | 2 × 1 cell × 4 actors | **PASS** | 8/8 |
| `ff30_waterfront` | Waterfront | `[23]` `null_cov_default` (tag 8743) | `spartans\spartans` (tag 10519) | `sur_fireteam_01`, `_02` | `gr_survival_fireteams` → `gr_survival_waves` → `gr_survival_all` | **yes** `@0x5F00808:i16=-1` | 2 × 1 cell × 4 actors | **PASS** | 8/8 |
| `ff50_park` | Beachhead | `[21]` `null_cov_default` (tag 8762) | `spartans\spartans` (tag 10194) | `sq_elite_fireteam_01`, `_02` | `gr_survival_fireteams` → `gr_survival_waves` → `gr_survival_all` | **yes** `@0x4F3C11C:i16=-1` | 2 × 1 cell × 4 actors | **PASS** | 8/8 |
| `ff60_airview` | Outpost | `[24]` `null_cov_default` (tag 9413) | `spartans\spartans` (tag 10685) | `sur_fireteam_01`, `_02` | `gr_survival_fireteams` → `gr_survival_waves` → `gr_survival_all` | **yes** `@0x47AB3E4:i16=-1` | 2 × 1 cell × 4 actors | **PASS** | 8/8 |
| `ff60_icecave` | Glacier | `[24]` `null_cov_default` (tag 8515) | `spartans\spartans` (tag 9680) | `sur_fireteam_01`, `_02` | `gr_survival_fireteams` → `gr_survival_extras` (**root**) | **no — already clear** | 2 × 1 cell × 4 actors | **PASS** | 8/8 |
| `ff45_corvette` | Corvette | `[24]` `null_cov_default` (tag 8176) | `spartans\spartans` (tag 9722) | `ff_elite_fireteam0`, `1` | *(no group)* squads are members of `gr_wave_spawns` → `gr_survival_all` | **yes, per squad** `@0x4FB233E:i16=-1` and `@0x4FB23AA:i16=-1` | 2 × 1 cell × 4 actors | **PASS** | 8/8 |

Every map ships `objects\characters\spartans\spartans`; the biped tag index was read out
of each map's own tag table before the repoint, never assumed.

**The reparent patches are recorded here, not applied.** The published `.stage2.map`
files have exactly the scope of the proven Holdout artifact: the 4-byte unit repoint plus
the two squad cell fields. Each reparent selector above was read out of the **published**
stage-2 cache, so it applies directly to the deliverable with
`tools/patch/patch_map.py --set ... --apply`.

---

## 2. Usable fireteam count and parent group, per map

Read from `extracted/<map>/` offsets re-derived against the live cache, not inferred from
scripts. "Clean" means zero designer and zero templated cells, and a parent group that is
not the wave group.

| map | fireteam handles | clean/usable | parent group(s) of those handles |
|---|---|---|---|
| `ff10_prototype` | 6 | **6** | `gr_survival_fireteams` |
| `ff20_courtyard` | 6 | **6** | `gr_survival_fireteams` |
| `ff30_waterfront` | 6 | **6** | `gr_survival_fireteams` |
| `ff50_park` | 6 | **6** | `gr_survival_fireteams` |
| `ff60_airview` | 6 | **6** | `gr_survival_fireteams` |
| `ff60_icecave` | 6 | **5** | `gr_survival_fireteams` (01–05), `gr_survival_waves` (06) |
| `ff45_corvette` | 6 | **0** | `gr_wave_spawns` (all six) |

### 2.1 Glacier's trap, confirmed in the bytes

`sur_fireteam_06` is squad index 23. Its parent is group 5 `gr_survival_waves`, its flags
are `0x40` (*fireteam absorber*) rather than the `0x100` (*no wave spawn*) its five
siblings carry, it has 2 spawn formations, and it has one live designer cell. That cell
is not merely similar to the wave-01 cell, it **is** the same blob: both squads point at
cell offset `0x52DBAB4`, whose eight character choices are palette `[0, 1, -1, -1, 2, 3,
-1, -1]` = `brute`, `brute_captain`, `brute_chieftain_armor`, `brute_chieftain_weapon`.

So Glacier has **5** usable fireteams, not 6, and slot 5 of the startup binding
(`ai_sur_fireteam_squad5` → `sur_fireteam_06`) points at a live Brute wave squad. The
build used `sur_fireteam_01` and `_02`, both clean, and did not touch `_06`.

### 2.2 Holdout's parent-chain problem is present on five of the seven

Research/19 found that Holdout's `gr_survival_fireteams` is a child of
`gr_survival_waves`, itself a child of `gr_survival_all`, which would stop the waves ever
ending once friendlies live in that group. Each of the seven maps was checked for the same
problem by walking the group table's `parent` field (`squad_groups_block + 0x20`,
`short_block_index`) to a root.

* **Five maps have it**: Overlook, Courtyard, Waterfront, Beachhead, Outpost all show
  `gr_survival_fireteams` → `gr_survival_waves` → `gr_survival_all`. The fix is the same
  2-byte same-size write Holdout needs: set the group's own `parent` to `-1`.
* **Glacier does not have it.** Its `gr_survival_fireteams` (group 9) is parented to
  group 1 `gr_survival_extras`, which is itself a root. The chain never reaches
  `gr_survival_all`, so no reparent is required. This is the one genuinely good piece of
  news in the set and it was found by reading the tag, not assumed from the other maps.
* **Corvette has it in a different shape.** Corvette has no `gr_survival_fireteams` at
  all — only 5 groups, and all six `ff_elite_fireteam0…5` handles are *member squads* of
  `gr_wave_spawns`, whose parent is `gr_survival_all`. There is no spare group to
  reparent, so the equivalent same-size fix is per squad: set the squad's own `parent`
  (`squads_block + 0x26`, `short_block_index`) to `-1`. That leaves the squad parentless,
  which is already a shipped state in this very map — Corvette ships 8 parentless squads
  (`ff_phantom0…3`, `ff_phantom_bonus`, `test_fork`, `test_load`, `test_load2`) — and it
  removes the squad from the group `ai_place_wave` fills. Both target squads are empty in
  stock, so nothing authored is lost.

---

## 3. The cell template, and the one place this differs from Holdout

Holdout used `sq_sur_drop_01`'s designer cell verbatim as the byte template: 4 actors,
exactly one character-type entry, and **vehicle type `-1`**. Copying a real in-map cell is
what keeps every spawn-condition, weapon, equipment and patrol field at a stock-valid
value, so that method was kept.

The complication is that `sq_sur_drop_01`'s cell is **not** vehicle-free on most maps.
Holdout and Beachhead ship it with vehicle `-1`; Overlook ships it with vehicle 5,
Courtyard with 2, Waterfront with 1 — a Covenant drop pod. Copying those verbatim would
have spawned the allies inside a drop pod. Two maps have no drop squads at all.

So the template is selected per map, and exactly two fields are overwritten **in the copy
only**:

| map | template cell | `normal diff count` | `vehicle type` |
|---|---|---|---|
| `ff10_prototype` | `sq_sur_drop_01` `@0x58DEBFC` | 4 → 4 (unchanged) | 5 → **-1** |
| `ff20_courtyard` | `sq_sur_drop_01` `@0x5865B04` | 4 → 4 (unchanged) | 2 → **-1** |
| `ff30_waterfront` | `sq_sur_drop_01` `@0x5F0191C` | 4 → 4 (unchanged) | 1 → **-1** |
| `ff50_park` | `sq_sur_drop_01` `@0x4F3D894` | 4 → 4 (unchanged) | -1 → -1 (unchanged) |
| `ff60_airview` | `sq_sur_sniper_01` `@0x47AC754` | 1 → **4** | -1 → -1 (unchanged) |
| `ff60_icecave` | `sq_sur_wraith_01` `@0x52DC954` | 2 → **4** | 5 → **-1** |
| `ff45_corvette` | `ff_startup_grunts` `@0x4FB1E74` | 2 → **4** | -1 → -1 (unchanged) |

Both written values are attested stock **in the same map**: a `normal diff count` of 4
appears on the drop cells of the four maps that have drop squads (Overlook, Courtyard,
Waterfront, Beachhead), and `vehicle type = -1` appears on every map's wave cells. No field is given a value this project invented. `vehicle variant`
(a `string_id` at cell `+0x48`) is zeroed with the vehicle, and the character-palette
choice's `chance` is set to 1.

Field offsets are the ones research/17 derived from `scenario.json` and this task
re-confirmed from `tagdefs`: `cell_block` (0x6C) `normal diff count` 0x10, `character
type` block 0x14, `vehicle type` 0x46, `vehicle variant` 0x48;
`character_palette_choice_block` (0x10) `character type` 0x0C, `chance` 0x0E;
`squads_block` (0x6C) `parent` 0x26, `designer` 0x54; `squad_groups_block` (0x28)
`parent` 0x20.

---

## 4. The repoint, per map

The 4-byte datum repointed is at `char + 0x14 + 0xC` = `char + 0x20`, exactly as
research/19 established: `character_struct_definition` holds `tag_reference 'unit'` at
field offset 0x14, and a Reach `tag_reference` carries its datum index at `+0xC`.

One correction to research/19's wording, found while asserting on it: the group magic at
`char + 0x14` is stored **little-endian**, so it reads `dpib`, not `bipd`. The build
refuses to write unless it sees one of the two, and it saw `dpib` on all seven. No group
change is needed either way.

| map | char tag | unit datum file offset | before | after |
|---|---|---|---|---|
| `ff10_prototype` | 9656 | `0x9974364` | `0x8DDB25B9` → `null\null` | `0x94632B38` → `spartans\spartans` |
| `ff20_courtyard` | 8775 | `0x9147B64` | `0x89862248` → `null\null` | `0x8FF127C0` → `spartans\spartans` |
| `ff30_waterfront` | 8743 | `0x967F3BC` | `0x89432228` → `null\null` | `0x914C2917` → `spartans\spartans` |
| `ff50_park` | 8762 | `0x7FE99C0` | `0x89E2223B` → `null\null` | `0x906727D2` → `spartans\spartans` |
| `ff60_airview` | 9413 | `0x81CF0BC` | `0x8D0124C6` → `null\null` | `0x92E829BD` → `spartans\spartans` |
| `ff60_icecave` | 8515 | `0x844FDE4` | `0x88BD2144` → `null\null` | `0x8E0425D0` → `spartans\spartans` |
| `ff45_corvette` | 8176 | `0x7CAD970` | `0x87171FF1` → `null\null` | `0x8E1825FA` → `spartans\spartans` |

### 4.1 Choosing the victim entry

Every map's full character palette was cross-referenced against every designer and
templated cell in every squad, and only entries referenced by **no** cell were considered.
`objects\characters\null\ai\null_cov_default` is unreferenced on all seven, so the same
victim as Holdout was available everywhere, which keeps the seven maps uniform.

Other unreferenced entries exist and were deliberately left alone, because several are
not safe:

* `null_cov_flying` is unreferenced on Overlook, Beachhead, Outpost, Glacier and
  Corvette, but on Courtyard and Waterfront it flies the banshees. It is excluded by
  policy rather than by map, to keep one rule.
* Beachhead additionally has `brute_captain`, `brute_chieftain_weapon` and
  `skirmisher_major` unreferenced; Courtyard has `elite_general` and `elite_pilot`;
  Waterfront and Outpost have `brute_captain`. These are real enemy characters and
  repointing one would be a visible change to a shipped tag if anything ever referenced
  it.
* Corvette's palette entry `[23]` is unreferenced but **null** (no tag), so it has no
  `char` to repoint; the build skips null entries.

---

## 5. Verification, per output

Every output was verified by an independent re-read, not by the writer's own report.
Eight checks per map, all seven green on all eight.

| map | re-parse | warnings | checksum stored == computed | byte-diff | size | locale packs/strings, output vs source | Blamite |
|---|---|---|---|---|---|---|---|
| `ff10_prototype` | 14650 tags / 235 groups / 14645 named / 71288 sids | **0** | `0x458C2344` | 13 runs, 0 unexplained | 190,615,552 → 190,681,088 (+0x10000) | 12 / **100261 == 100261** | **LOAD: OK** |
| `ff20_courtyard` | 13879 / 235 / 13875 / 52675 | **0** | `0xFC850E27` | 13 runs, 0 unexplained | 183,214,080 → 183,279,616 | 12 / **100261 == 100261** | **LOAD: OK** |
| `ff30_waterfront` | 14181 / 235 / 14177 / 57069 | **0** | `0xF948BC09` | 13 runs, 0 unexplained | 192,479,232 → 192,544,768 | 12 / **100061 == 100061** | **LOAD: OK** |
| `ff50_park` | 14034 / 235 / 14030 / 70659 | **0** | `0x103C4673` | 13 runs, 0 unexplained | 172,179,456 → 172,244,992 | 12 / **100061 == 100061** | **LOAD: OK** |
| `ff60_airview` | 14547 / 235 / 14542 / 66644 | **0** | `0x9AC0174B` | 13 runs, 0 unexplained | 172,961,792 → 173,027,328 | 12 / **100261 == 100261** | **LOAD: OK** |
| `ff60_icecave` | 13189 / 235 / 13185 / 65804 | **0** | `0x4459ADC0` | 13 runs, 0 unexplained | 164,900,864 → 164,966,400 | 12 / **100261 == 100261** | **LOAD: OK** |
| `ff45_corvette` | 13146 / 235 / 13142 / 62116 | **0** | `0x0F9534D1` | 13 runs, 0 unexplained | 157,216,768 → 157,282,304 | 12 / **100261 == 100261** | **LOAD: OK** |

Tag counts and stringID counts match research/17's independently-measured per-map table
on all seven, which is a second confirmation that the growth disturbed no table.

Locale counts come from Blamite itself (`hsc-compile --load-only` prints
`locales : N language pack(s), M string(s)`), run once on the source and once on the
output of each map, so the comparison is against the real reference implementation rather
than our own reader. Waterfront and Beachhead genuinely ship 100,061 strings where the
other five ship 100,261; in each case the output matches **its own** source exactly.

### 5.1 What the byte-diff actually contains

All thirteen differing runs per map are accounted for. Six lie in the 0xA000 header:

| header offset | field |
|---|---|
| `0x008` | `file_size` (+0x10000) |
| `0x014` | `virtual_size` (+0x10000) |
| `0x358` | partition 5 size (partitions table at 0x300, six 16-byte entries) — `_adjust_partitions` |
| `0x360` | `checksum` |
| `0x4D8` | localization section **offset mask** (+0x10000) — the research/19 fix; its vaddr at `0x4F4` is deliberately unchanged |
| `0x4F0` | tag section **size** (+0x10000) |

Seven lie outside the header and every one falls entirely inside an intended 4-byte field:
the `char` unit datum, and for each of the two target squads its `designer.cells` count
(`squad + 0x54`) and cell pointer (`squad + 0x58`). The verifier classifies a run as
explained only if the run is wholly contained in one of those fields, so a stray byte
adjacent to a field would still be reported.

The 0x10000 inserted page is compared separately rather than skipped: it contains between
37 and 49 non-zero bytes per map — the two 16-byte choice entries and two 108-byte cells —
and is otherwise zero.

### 5.2 The cells, re-read from the published file

For every map, both target squads re-read as `designer cells = 1`, that cell as
`normal diff count = 4`, `vehicle type = -1`, and exactly one character-type entry
pointing at the repointed palette slot. The repointed `char` re-resolves to
`objects\characters\spartans\spartans`.

---

## 6. Source integrity

| file | state |
|---|---|
| `~/Desktop/ff10_prototype.map` … `ff60_icecave.map`, `ff45_corvette.map` | opened read-only; sha256 recorded before and after each build and **identical** in all seven cases; mtimes unchanged |
| `~/Desktop/ff50_park.map`, `~/Desktop/ff70_holdout.map`, `~/Desktop/ff_unearthed.map` | still mode `0444`; permissions not altered |
| `~/Desktop/ff_unearthed.map` | **never opened** |
| `~/Desktop/build/ff70_holdout.stage2.map` | **not written**; mtime predates this task |

Of the seven targets only `ff50_park` arrived as `0444`. The other six
(`ff10_prototype`, `ff20_courtyard`, `ff30_waterfront`, `ff60_airview`, `ff60_icecave`,
`ff45_corvette`) are mode `0644` as received and were left that way; they are protected by
the read-only open path and the recorded hashes, not by permissions. Tightening them to
`0444` would be a reasonable follow-up.

---

## 7. Assertion suites

Re-run on the tooling as it stands after this task, unchanged by it:

| suite | result |
|---|---|
| `tools/map/test_parse_map.py` | **234 passed, 0 failed** |
| `tools/map/test_reach_write.py` | **560 assertions, 0 failures** |
| `tools/patch/test_patch_map.py` | **472 assertions passed, 0 failed** |
| total | **1,266 assertions, 0 failures** |

Both writer suites print their own standing caveat that they are synthetic-only and prove
nothing about a real cache. That is exactly why the Blamite gate, not the suite, is the
publishing condition.

---

## 8. Reproducible sequence

```bash
PROJ="$HOME/Desktop/Firefight Evolved Expanded"; cd "$PROJ"
MAPS="ff10_prototype ff20_courtyard ff30_waterfront ff50_park ff60_airview ff60_icecave ff45_corvette"

# read-only survey: unused char palette entries, Spartan biped, squads, group parent chains
for m in $MAPS; do python3 build/logs/stage2_survey.py ~/Desktop/$m.map > build/stage2/$m.survey.json; done
for m in $MAPS; do python3 build/logs/stage2_cells.py ~/Desktop/$m.map; done   # template candidates

# build; CacheWriter.save() publishes only if `hsc-compile --load-only` accepts the cache
for m in $MAPS; do python3 build/logs/stage2_build.py $m > build/stage2/$m.build.json; done

# verify each output independently of the writer
for m in $MAPS; do python3 build/logs/stage2_verify.py $m > build/stage2/$m.verify.json; done

# the recorded reparent patches, read out of the published stage2 caches
python3 build/logs/stage2_reparent_plan.py > build/stage2/reparent_plan.json

# assertion suites
python3 tools/map/test_parse_map.py; python3 tools/map/test_reach_write.py; python3 tools/patch/test_patch_map.py
```

Note that the suites are plain scripts with their own assertion counters, not pytest
tests. `python3 -m pytest tools -q` collects them and reports 18 errors on missing
`variant` fixtures; that is a collection artifact, not a failure. Run them directly.

---

## 9. What is still not done

1. **The reparent patches are recorded, not applied** (section 1). Five maps plus
   Corvette need theirs before friendlies can live in those squads without stalling the
   wave-end check. Each is a same-size `patch_map.py --set` away, and each should be
   re-gated through Blamite after application.
2. **These artifacts are structurally verified, not play-tested.** Blamite loading a
   cache proves the container and tag graph are well formed. It does not prove MCC spawns
   these squads, nor that an ally Spartan behaves. No map in this set has been run in the
   game.
3. **The allies are Spartan-bodied, not Marines or ODSTs** — the accepted workaround, not
   a change of plan. No stock map has a Marine or ODST `char` tag.
4. **Team and allegiance are untouched.** All fourteen filled squads are still
   `team = default`. Research/19 section 5 recommends doing this at runtime with
   `ai_set_team` / `ai_allegiance` rather than patching squad `team` fields, and that is
   still the cheaper path.
5. **Only 2 of the available fireteam squads are filled per map**, matching the Holdout
   reference. Overlook, Courtyard, Waterfront, Beachhead and Outpost have 6 clean handles,
   Glacier 5; the remaining ones are untouched and available.
6. **Corvette is staged but remains the worst target.** Its two filled squads sit inside
   `gr_wave_spawns` until the per-squad reparent is applied, and its fireteam handles were
   never meant to be friendly. It passed every check, but it should be the last map
   anyone relies on.
