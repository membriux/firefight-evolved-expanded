# 22 — The purchase system on Waterfront and Outpost

**Date:** 2026-11-23
**Targets:** `ff30_waterfront` (Waterfront) and `ff60_airview` (Outpost), Halo: Reach MCC Update 13
**Inputs:** `~/Desktop/Halo-Firefight/staged-maps/ff30_waterfront.stage2.map` and
`ff60_airview.stage2.map` (research/20), opened read-only
**Deliverables:** `~/Desktop/Halo-Firefight/ready-to-install/ff30_waterfront.FINAL.map` and
`ff60_airview.FINAL.map`
**Reference replicated:** `src/hsc/ff70_holdout.hsc` + `src/hsc/fe_reinforcements.hsc` (Holdout)

**Verdict: both maps took the shop. Both load in Blamite, both re-parse with zero warnings,
and both byte-diffs are fully accounted for.** Neither has been run in MCC, because MCC has no
macOS build.

---

## 0. Headline

| | Waterfront | Outpost |
|---|---|---|
| shop anchors | `health_pack0..5` — six placed `health_station` device_controls, placement flags `0x00000000` | `health_pack0..5` — same |
| distinct script objects referenced | **16, every one stock** | **16, every one stock** |
| new script objects created | **0** | **0** |
| fireteam slots used | `sur_fireteam_01`, `_02` (troopers), `_03`, `_04` (Spartans); `_05`, `_06` left free | identical |
| kiosk radius | 1.45 wu | **1.10 wu** |
| compile | **OK** — 403 scripts, 225 globals, 16,728 expressions | **OK** — 386 scripts, 217 globals, 16,303 expressions |
| bytecode written | **yes**, via Blamite `SaveScripts` | **yes** |
| re-parse | 14,181 tags / 235 groups / 14,177 named / 57,107 sids / **0 warnings** | 14,547 / 235 / 14,542 / 66,682 / **0 warnings** |
| checksum stored == computed | `0x10C7C358` | `0x05B1E6A8` |
| byte-diff unexplained | **0 clusters, 0 runs** | **0 clusters, 0 runs** |
| Blamite | **LOAD: OK**, 12 language packs, 100,061 strings | **LOAD: OK**, 12 language packs, 100,261 strings |
| size | 192,610,304 (stage-2 + 0x10000) | 173,092,864 (stage-2 + 0x10000) |
| sha256 | `fe04fa98d180ed75645044c71c9dc5a7a23aa8ecaff0ee6e75d9cb7b75cea4ad` | `01df9ae5e46f27ec7b8c8121e2da6ca15eb104fe57d7bad4e0c7ae54d4894a73` |
| blocker | none | none |

The two maps are reported separately throughout. Nothing below is averaged.

---

## 1. What was reused from Holdout, and what had to change

Everything structural was reused: proximity purchases instead of trigger volumes, repurposed
fireteam squads, the author's prices, the negative `campaign_metagame_award_points` charged to the
real buyer, weighted palette-choice loadouts, the dormant-kiosk-woken-at-startup idiom, the
fail-closed Blamite gate on every write.

Five things genuinely had to change, and each is a finding rather than a preference.

### 1.1 The ally bodies are fireteam squads on both maps, not borrowed drop squads

Holdout's trooper tier borrows `sq_sur_drop_01..04` and flies them in on Bungie's own pod
sequence, because at the time those were the only squads in Holdout with a populated cell.
That is not portable. **Outpost ships no drop-pod infrastructure at all** — no `sq_sur_drop_*`
squads, no `dm_drop_*` machines, no pod rails, no drop-pod spawner, and no `g_sur_drop_spawn` /
`g_sur_drop_limit` globals anywhere in its 347-script decompile. Waterfront does have five drop
squads and five `dm_drop_*` machines, but its own stock script owns them.

Both maps instead use `sur_fireteam_01..04`, which research/20 already gave 4-actor cells on `_01`
and `_02`. This project added the spawn points those squads never had, plus cells on `_03` and
`_04`. The consequences are all good:

* one delivery path for both maps and both tiers, so the library is shared;
* every ally lives in `gr_survival_fireteams`, so the cap, the task refresh, the cleanup and the
  reparent all act on one group — unlike Holdout, where the trooper squads sit in
  `gr_survival_cov_drop_pod` and are therefore **not** counted by that map's own
  `fe_allies_alive`, which reads `ai_living_count "gr_survival_fireteams"`. That is a latent
  defect in the shipped Holdout artifact, found while porting, and it is flagged here for
  whoever owns that map rather than fixed.
* **no stock-script edit is needed on either map.** Holdout needs
  `ff70_holdout_stock_hooks.hsc` to switch Bungie's drop-pod event off; these two need nothing,
  because stock declares and binds `ai_sur_fireteam_squad0..5` and then never places, wakes or
  cleans them up. All twelve references in each decompile are the six declarations plus the six
  `set`s, checked by reading the text.
* no ally can spawn outside the arena, which was the bug Holdout had to write a pod sequence
  around.

The cost: troopers walk out of the respawn zone instead of arriving by pod. That is less
spectacular than Holdout's delivery, and it is stated rather than hidden.

### 1.2 There is no vehicle tier, and the reason is per map

Holdout sells air support by flipping `sq_sur_banshee_01/02` to team `human`.

* **Waterfront** does ship those squads, but its own `survival_banshee_spawn` already does
  `(ai_place "sq_sur_banshee_01")` `(ai_place "sq_sur_banshee_02")`. A purchase that also placed
  them would be a second `ai_place` on a possibly-occupied squad, which is unproven behaviour.
  Holdout's version avoids that by not calling `ai_place` at all — which means the purchase does
  nothing unless a Banshee happens to be alive already.
* **Outpost** has no Banshee squad. Its only vehicle squads are `sq_sur_ghost_01/02`, and stock
  does not `ai_place` those either: it loads them into a Phantom
  (`f_load_phantom_cargo v_sur_phantom_01 "single" "sq_sur_ghost_01" none`).

So that station sells **ammo** on both maps, which is one of the author's own rungs
(`buy_ammo1` = 500) and is fully verified: `ammo_crate0`/`ammo_crate1` exist on both maps as
`ammo_box` equipment with placement flags `0x00000101`, and both maps' own stock scripts create
them with `(object_create_anew obj_ammo_crate0)`.

### 1.3 The kiosk radius is NOT 2.5, and this is the most important correction in the file

Two stations cross-trigger whenever the distance between them is less than twice the radius,
because then one standing position is inside both discs and both dormant kiosk scripts fire on
the same dwell. All fifteen pairwise distances were measured from each map's own control block:

| map | closest pair | distance | maximum safe radius | radius used |
|---|---|---|---|---|
| Waterfront | `health_pack2`–`health_pack3` | 3.038 wu | < 1.519 | **1.45** |
| Outpost | `health_pack2`–`health_pack4` | 2.334 wu | < 1.167 | **1.10** |

`k_fe_kiosk_radius` is declared at 1.10 in the shared library — the tighter of the two, so a map
that forgot to set it would be over-strict rather than wrong — and each map's startup script sets
its own value.

**The same arithmetic applied to Holdout's own documented coordinates puts `health_pack4` and
`health_pack5` 2.36 wu apart against a 2.5 radius.** If those numbers are right, the shipped
Holdout artifact can fire its 500-point BANK and its 10,000-point WIN purchase from one standing
position. That was derived from the coordinate table in `src/hsc/ff70_holdout.hsc` rather than
from that map's bytes, so it should be re-measured by whoever owns Holdout; nothing in this task
touched that map.

The price of a tight radius is that the buyer must stand **on** the pad rather than near it. That
is the right way to spend the error budget: a shop that needs precise footing is a nuisance, a
shop that silently charges 10,000 for a 500-point deposit is a broken game.

### 1.4 Station assignment follows the geometry

Because the margin is thin, the expensive purchases were put on the best-separated pads.

| pad | Waterfront | Outpost |
|---|---|---|
| `health_pack0` | TROOPERS 500 | TROOPERS 500 |
| `health_pack1` | SPARTANS 1000, set ≥ 1 | SPARTANS 1000, set ≥ 1 |
| `health_pack2` | BANK 500 | BANK 500 |
| `health_pack3` | AMMO RESUPPLY 500 | **MAC STRIKE / WIN 10000**, set ≥ 1 |
| `health_pack4` | LONGSWORD PASS 3000, set ≥ 1 | AMMO RESUPPLY 500 |
| `health_pack5` | MAC STRIKE / WIN 10000, set ≥ 1 | LONGSWORD PASS 3000, set ≥ 1 |

On Waterfront the widest-separated pair in the base is `health_pack4`–`health_pack5` at 3.95 wu,
so the 3,000 and the 10,000 purchases go there and the closest pair holds the two 500s. On Outpost
`health_pack3` is the only station more than 10 wu clear of every other (its nearest neighbour is
10.63 away), so the win purchase goes there and the 2.33-wu pair holds the two 500s.

### 1.5 The Longsword pass survived the port; the air tier did not

`dm_longsword_01` is a real `longsword` device_machine on both maps, placement flag bit0 set, and
**both maps' own stock scripts drive it with the same five calls and the same position-track name
`"ff10"`** (`object_create`, `device_set_position_track "dm_longsword_01" "ff10" 0`,
`device_animate_position`, then `object_destroy`). The track name was read out of each map's own
decompile before use, not inherited from Holdout.

---

## 2. The verified object manifest

Sixteen script objects per map, every one stock, nothing authored. Read out of each map's own
`scnr` tag by `build/logs/wo_survey.py` and then proved by the compiler, which aborts on the first
unresolvable reference.

| kind | names | Waterfront | Outpost |
|---|---|---|---|
| `object_name` | `health_pack0..5` | controls, flags `0x0` | controls, flags `0x0` |
| `object_name` | `dm_longsword_01` | machines, flags `0x1` | machines, flags `0x1` |
| `object_name` | `ammo_crate0`, `ammo_crate1` | equipment, flags `0x101` | equipment, flags `0x101` |
| `ai_squad` | `sur_fireteam_01..04` | squads[14..17] | squads[14..17] |
| `ai_squad_group` | `gr_survival_fireteams` | groups[6] | groups[9] |
| `ai_squad_group` | `gr_survival_waves` | groups[5] | groups[5] |
| `ai_squad_group` | `gr_survival_all` | groups[0] | groups[0] |

Three further names are `string_id` arguments rather than script-object references, and all three
were still confirmed present before use: `obj_fireteams` and its single task `fireteams`
(objective[1] on both maps), and the device position track `"ff10"`.

Three `snd!` tag paths, confirmed present in each map's own tag table:

| path | Waterfront | Outpost |
|---|---|---|
| `sound\game_sfx\ui\transition_beeps` | tag 8768 | tag 9438 |
| `sound\game_sfx\multiplayer\flag_failure` | tag 4446 | tag 4620 |
| `sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus` | tag 10054 | tag 10220 |

### 2.1 Why the health stations and nothing else — re-derived per map

The candidate list from research/19 was checked against each map's own placement flags and world
positions rather than carried over.

| candidate | Waterfront | Outpost |
|---|---|---|
| `sc_hack_*`, `sc_resupply_01..09` | flags `0x1` (script-created) and sitting in an off-map prop farm around (−20, 244, 58), ~25 wu from the base at (8, 222, 45) and 13 wu above it | flags `0x1`, prop farm around (−98, −53, 17), ~80 wu from the Deck at (−130, −130, 13) |
| `generator_switch0..2` | flags `0x1` | flags `0x1` |
| `dm_resupply_01..09`, `dm_target_01..03` | flags `0x1` | flags **`0x0`** — auto-placed on this map, but they are `invis_resupply_capsule` markers, i.e. invisible, and the nearest is 14.6 wu off the Deck |
| `ammo_crate0/1` | flags `0x101` | flags `0x101` |
| doors | none in the object-name table | `#_door_interior_large_logo_02..04` exist, and the quoted-`#` lexer trick is proven, but all three are tram-tunnel doors well away from the Deck |
| `health_pack0..5` | **flags `0x0`, inside the base** | **flags `0x0`, on the Deck** |

Outpost's auto-placed `dm_resupply_*` is a genuine per-map difference from Waterfront and from
Holdout, and it was the one thing that might have given a seventh anchor. It was rejected because
an invisible kiosk is worse than a shared one.

**The cost of using the health stations, stated plainly:** these six objects are the maps' health
stations. Standing at one to buy is standing at one to heal, and the two uses are not separated.
Holdout could in principle move its stations onto ten always-placed `#_m70_door_*` machines;
neither of these maps has an equivalent, so on these two the overlap cannot be reduced.

### 2.2 Negative control

Required, and run against both caches. Three fake names, one per object kind, each in its own
one-script file (`build/wo/negctl/`):

| file | reference | result against both maps |
|---|---|---|
| `neg_objectname.hsc` | `(object_create_anew "fe_bogus_kiosk_zzz")` | `Failed to process the expression "fe_bogus_kiosk_zzz". A "object_name" expression was expected.` |
| `neg_squad.hsc` | `(ai_place "sur_fireteam_99")` | `Failed to process the expression "sur_fireteam_99". A "ai" expression was expected.` |
| `neg_group.hsc` | `(ai_living_count "gr_bogus_group_zzz")` | `Failed to process the expression "gr_bogus_group_zzz". A "ai" expression was expected.` |

All six runs failed to compile. The compiler aborts on the first unresolved reference, so the fact
that the full shop unit compiles clean against each cache is positive evidence for every name in
it, not just an absence of complaints.

A second, incidental control: `fe_reinforcements_wo.hsc` section 16 quotes
`sq_sur_banshee_01` and `sq_sur_ghost_01` inside comments. Outpost has no Banshee squad and
Waterfront has no Ghost squad, yet both units compile — which confirms comment text is inert and
that the manifest above is the real reference set.

---

## 3. The tag edits, per map

Three stages per map. Every stage that grows the file goes through
`reach_write.CacheWriter.save()`, which publishes nothing Blamite will not load; every same-size
stage goes through `tools/patch/patch_map.py` and is re-gated afterwards.

### 3.1 Stage A — the ally tiers (`build/logs/wo_build_tags.py`, one 0x10000 page)

| | Waterfront | Outpost |
|---|---|---|
| character palette slot repointed to `spartans\spartans` | `[23]` (verified on input) | `[24]` (verified on input) |
| equipment palette | 4 → 5 entries, `jet_pack` appended as `[4]`, cloned from `[0]` sprint | 4 → 5, `jet_pack` as `[4]`, cloned from `[1]` sprint |
| `sur_fireteam_01`, `_02` | stage-2 cell untouched (4 actors, major `none`), **2 spawn points added each** | same |
| `sur_fireteam_03`, `_04` | new cell: 2 actors, major `all`, 1 character choice, 5 weapon choices, 4 equipment choices, 2 spawn points | same |
| cell template | `sur_fireteam_01`'s own stage-2 cell (108 B, vehicle −1) | same |
| spawn-point template | `sq_sur_drop_01`'s point, vehicle forced to −1 (this map has no ground-level on-foot point to copy; its only vehicle −1 points are the four sniper-tower ones, in structure bsp 2) | `sq_sur_sniper_01`'s point — already on foot, already bsp 0 |
| `structure bsp` written | 0 — the value 27 of this map's 31 stock spawn points carry | 0 — the value all 11 of this map's stock spawn points carry |
| allocation | 0x10000 granted for 0x748 asked, at file `0xB431000` | 0x10000 for 0x748, at file `0xA193000` |

**`sur_fireteam_05` and `_06` were left untouched on both maps** and still read 0 cells /
0 templated cells / 0 spawn points, so an ODST tier remains possible.

Neither map's equipment palette needed the `active_camouflage` append Holdout required: **both
already ship camo in the palette.** What both lack is the jet pack, whose `eqip` tag is in both
tag tables (Waterfront 7879, Outpost 8778) but in neither scenario palette — so the append
mechanism Holdout proved on camo was used on the jet pack instead.

### 3.2 Stage B — same-size patches

| map | selector | field | before → after |
|---|---|---|---|
| Waterfront | `@0x5F00808:i16` | `gr_survival_fireteams`.`parent` | 5 → −1 (**root**) |
| Waterfront | `@0x5F01908:i16` | trooper cell `initial weapon`[0] | 11 `plasma_repeater` → 7 `dmr` |
| Outpost | `@0x47AB3E4:i16` | `gr_survival_fireteams`.`parent` | 5 → −1 (**root**) |
| Outpost | `@0x47CA010:i16` | `obj_fireteams`/`fireteams` `follow` | 0 → 1 (player) |
| Outpost | `@0x47CA014:f32` | same task, `follow radius` | 0.0 → 8.0 |
| Outpost | `@0x47CA018:f32` | same task, `follow Z clamp` | 0.0 → 1.0 |
| Outpost | `@0x47CA03E:i16` | same task, `squad group filter` | −1 → 9 (`gr_survival_fireteams`) |
| Outpost | `@0x47AC720:i16` | trooper cell `initial weapon`[0] | 8 `needle_rifle` → 6 `dmr` |
| Outpost | `@0x47AC730:i16` | trooper cell `initial weapon`[1] | 20 `focus_rifle` → 0 `assault_rifle` |

**The reparent is load-bearing on both maps and nothing in the scripts compensates for it.**
Stock `survival_wave_living_count` counts `(ai_living_count "gr_survival_all")`, and in stock both
maps chain `gr_survival_fireteams` → `gr_survival_waves` → `gr_survival_all`. Without the
reparent, purchased allies enter the wave count and the round never ends. Both selectors match
the ones research/20 recorded, re-read here from the live caches rather than copied.

**Outpost's `obj_fireteams` task ships as a stub and Waterfront's does not.** Read from the tags:
Waterfront's `fireteams` task is already `follow = 1`, radius 3.0, Z clamp 1.0, filter 6
(`gr_survival_fireteams`) — Bungie left a working "allies follow the player" task in that map.
Outpost's is `follow = 0`, radius 0.0, Z clamp 0.0, filter −1. Without the four writes above the
Outpost allies spawn and fight but never follow. Every value written is attested in Outpost's own
objectives: `sniper_01`, `remaining`, `hero_follow`, `main_follow` and `bonus_follow` all carry
`follow = 1`, radius 8, Z clamp 1. The radius is therefore 8 on Outpost and 3 on Waterfront, each
map using its own attested number; on a platform as crowded as the Deck the looser leash is also
the kinder one.

**The trooper weapons needed fixing and this was found by reading the published cells back.** The
stage-2 trooper cells were cloned from each map's own Covenant squad cells so that every unset
field kept a stock-valid value — which also inherited the template's `initial weapon` choices.
Re-reading showed Spartan-bodied allies holding a plasma repeater (Waterfront) and a needle rifle
plus a focus rifle (Outpost). Each choice's `weapon type` is a `short_block_index` at `+0x0C` of a
16-byte entry, so repointing it is a 2-byte same-size write, and every replacement index was read
out of that map's own weapon palette.

One structural note found while doing it: **`sur_fireteam_01` and `sur_fireteam_02` share a single
cell blob** on both maps — the stage-2 build pointed both squads at the same offset — so one write
fixes both. Sharing a cell between squads is a shipped Bungie pattern (research/20 §2.1 records
Glacier's `sur_fireteam_06` and wave-01 sharing one), and it passed the gate here.

### 3.3 Stage C — the script write

Compile unit, in order, identical in shape for both maps:

```
build/wo/fe_culled_shims.hsc              the culled `player_count` script
build/wo/<map>/stock_unescaped.hsc        the map's own decompile, backslashes collapsed
src/hsc/fe_reinforcements_wo.hsc          the shared purchase library
src/hsc/<map>.hsc                         the six kiosks, the ally refresh, the startup
```

Both known script traps from the brief were hit, and both on both maps.

1. **`print` is `null="true"`.** Every `print` in the new code is behind `(if g_fe_debug ...)`.
   The lint reports 180 (Waterfront) and 163 (Outpost) `unimplemented` findings, nearly all of
   them `print` calls in Bungie's own stock text, which are left exactly as shipped.
2. **The decompiler emits `\\` in tag paths.** Waterfront had 106 doubled backslashes and Outpost
   86. Left alone, the first one kills the compile:
   `Failed to process the expression "firefight\\firefight_music\\firefight_music01". A
   "looping_sound" expression was expected.` `build/logs/wo_prep_stock.py` collapses them, using
   exactly the transform `build/holdout/unit/stock_unescaped.hsc` was produced with — asserted
   byte-for-byte against that file before being relied on.
3. **The culled script.** Both maps' bytecode calls `player_count`, which is neither an opcode in
   `ReachMCC_U13_Scripting.xml` nor one of the scenario's own declared scripts. Three call sites
   each, all `(> (player_count) 0)` — Waterfront lines 356 / 3457 / 4836, Outpost 348 / 3449 /
   4830. Without a declaration Blamite cannot rebuild the table at all. The shim restores it as
   `(list_count (players_human))`.

**The stock round trip was run first, before any new script was written**, because it is the gate
on everything: *does the map's own decompiled script recompile?*

| map | stock round trip | result |
|---|---|---|
| Waterfront | shim + 364-script decompile | **OK** — 365 scripts, 198 globals, 15,446 expressions |
| Outpost | shim + 347-script decompile | **OK** — 348 scripts, 190 globals, 15,021 expressions |

Then the full unit:

| map | scripts | globals | expressions | tag refs | string bytes |
|---|---|---|---|---|---|
| Waterfront | 365 → **403** (+38) | 198 → **225** (+27) | **16,728** | 20 | 25,365 |
| Outpost | 348 → **386** (+38) | 190 → **217** (+27) | **16,303** | 18 | 24,893 |

Two script-object references are reported unresolved on both maps, `ai_current_actor` and
`ai_current_squad`, both from Bungie's own stock text. The Holdout write shipped with the same two
unresolved, so this is the reference behaviour rather than a new defect.

After the write, a trivial probe script was compiled against each published cache — the
reload test — and both succeeded, reporting 330 (Waterfront) and 364 (Outpost) script objects in
14 blocks. That proves the rebuilt script table is readable by the same implementation that wrote
it.

---

## 4. Verification

Everything below was produced by re-opening the published file, not by trusting the writer.

### 4.1 Parse and checksum, at every stage

| map | stage | tags | groups | named | string ids | warnings | size | checksum |
|---|---|---|---|---|---|---|---|---|
| Waterfront | stage2 (input) | 14181 | 235 | 14177 | 57069 | 0 | 192,544,768 | `0xF948BC09` |
| Waterfront | + ally tiers | 14181 | 235 | 14177 | 57069 | 0 | 192,610,304 | `0x38E12657` |
| Waterfront | + same-size patches | 14181 | 235 | 14177 | 57069 | 0 | 192,610,304 | `0x38E1D9A1` |
| Waterfront | **FINAL** | **14181** | **235** | **14177** | **57107** | **0** | **192,610,304** | **`0x10C7C358`** |
| Outpost | stage2 (input) | 14547 | 235 | 14542 | 66644 | 0 | 173,027,328 | `0x9AC0174B` |
| Outpost | + ally tiers | 14547 | 235 | 14542 | 66644 | 0 | 173,092,864 | `0x58A78A3C` |
| Outpost | + same-size patches | 14547 | 235 | 14542 | 66644 | 0 | 173,092,864 | `0xD9D175DD` |
| Outpost | **FINAL** | **14547** | **235** | **14542** | **66682** | **0** | **173,092,864** | **`0x05B1E6A8`** |

Tag, group and named-tag counts are identical at every stage and match research/20's
independently-measured stage-2 figures exactly. Every `stored` checksum equals a second,
independent XOR recomputation (`build/logs/cks.py`).

The string-id count rises by exactly 38 on both maps at the script write — one per new script
(403 − 365 = 38, 386 − 348 = 38). Blamite registers script names as string ids.

### 4.2 Byte diff — the growth stage

`build/logs/wo_growthdiff.py` compares shift-aware: the parent's tail against the child's tail
displaced by the inserted page, because otherwise every byte after the insertion point reads as
different and the comparison says nothing.

Both maps: **26 differing runs before the page, 0 after it, 0 unexplained.**

Six runs are in the header, and they are precisely the six fields research/20 documented:

| header offset | field |
|---|---|
| `0x008` | `file_size` (+0x10000) |
| `0x014` | `virtual_size` (+0x10000) |
| `0x358` | partition 5 size |
| `0x360` | checksum |
| `0x4D8` | localization section **offset mask** (+0x10000) — the research/19 fix; the vaddr at `0x4F4` is deliberately unchanged |
| `0x4F0` | tag section size (+0x10000) |

The other twenty lie wholly inside an intended block field: the scenario's `equipment palette`
block field, and for each of the four ally squads its `designer` and `spawn points` block fields.
A run that strayed one byte outside a declared field would still be reported.

The inserted 0x10000 page is compared separately rather than skipped: 452 non-zero bytes on
Waterfront and 491 on Outpost, everything else zero.

### 4.3 Byte diff — the script write

`build/logs/wo_bytediff.py` clusters the runs and maps each cluster onto a named region.
Both maps: **7 clusters, 0 unexplained.**

| cluster | Waterfront | Outpost | region |
|---|---|---|---|
| 1 | `0x11`–`0x4F8`, 43 bytes | `0x11`–`0x4F8`, 44 bytes | cache header: checksum, the four interop masks and vaddrs, and the debug-table addresses |
| 2 | `0x41BB4`, 38 runs, 114 bytes | `0x4B150`, 38 runs, 114 bytes | the 38 new string-id **index** entries |
| 3 | `0x1F55F3`, 507 bytes | `0x270A4E`, 500 bytes | the appended string-id **data**, `string_table_size` +0x220 |
| 4 | `0x5D2AE99`, 24 dwords | `0x45DA089`, 24 dwords | `matg globals\globals` locale pointers |
| 5 | 493,692-byte span | 480,452-byte span | scnr `script string data` blob, `hs syntax datums`, `references`, `globals` |
| 6 | 22,019-byte span | 21,259-byte span | scnr `scripts` block data |
| 7 | 234-byte span | 234-byte span | the seven scnr script block fields themselves |

Cluster 4 is the one that needed proving rather than naming. Blamite recomputes the interop
sections' virtual addresses when it saves and rewrites the globals tag's locale pointers to match,
so the classifier does not merely accept any change inside `matg`: it checks that **every** changed
dword is an address shifted by **one** delta. Waterfront: 24 dwords, single delta −13,000,704.
Outpost: 24 dwords, single delta −48,238,592. More than one delta would be reported as
unexplained and would fail the run. The rebase is consistent with everything else: Blamite reloads
both caches, both resolve 12 language packs with the same string counts as their own stage-2
sources (100,061 and 100,261 — Waterfront genuinely ships fewer), and both checksums verify.

### 4.4 The ally tiers, re-read from the published bytes

| map | squad | cells | actors | major | vehicle | char | weapon choices | ability choices | spawn points |
|---|---|---|---|---|---|---|---|---|---|
| Waterfront | `sur_fireteam_01` | 1 | 4 | 3 `none` | −1 | `[23]` | `[7]` dmr | — | 2 |
| Waterfront | `sur_fireteam_02` | 1 | 4 | 3 `none` | −1 | `[23]` | `[7]` dmr | — | 2 |
| Waterfront | `sur_fireteam_03` | 1 | 2 | 4 `all` | −1 | `[23]` | `[14, 18, 19, 21, 9]` | `[0, 1, 3, 4]` | 2 |
| Waterfront | `sur_fireteam_04` | 1 | 2 | 4 `all` | −1 | `[23]` | `[14, 18, 19, 21, 9]` | `[0, 1, 3, 4]` | 2 |
| Outpost | `sur_fireteam_01` | 1 | 4 | 3 `none` | −1 | `[24]` | `[6, 0]` dmr / assault rifle | — | 2 |
| Outpost | `sur_fireteam_02` | 1 | 4 | 3 `none` | −1 | `[24]` | `[6, 0]` | — | 2 |
| Outpost | `sur_fireteam_03` | 1 | 2 | 4 `all` | −1 | `[24]` | `[12, 16, 17, 21, 7]` | `[1, 0, 3, 4]` | 2 |
| Outpost | `sur_fireteam_04` | 1 | 2 | 4 `all` | −1 | `[24]` | `[12, 16, 17, 21, 7]` | `[1, 0, 3, 4]` | 2 |

`gr_survival_fireteams` re-reads as a **root** group on both (parent −1, index 6 and 9). The
repointed `char` re-resolves to `objects\characters\spartans\spartans` on both. Both equipment
palettes re-read with five entries ending in `jet_pack`. Outpost's `obj_fireteams`/`fireteams`
re-reads as `follow = 1`, radius 8.0, Z clamp 1.0, filter 9; Waterfront's as `follow = 1`,
radius 3.0, Z clamp 1.0, filter 6.

### 4.5 Blamite

| map | artifact | verdict |
|---|---|---|
| Waterfront | `build/wo/*.shoptags.map` | **LOAD: OK** (gated inside `CacheWriter.save()`) |
| Waterfront | `build/wo/*.loadout.map` | **LOAD: OK** |
| Waterfront | `ready-to-install/ff30_waterfront.FINAL.map` | **LOAD: OK**, 12 packs, 100,061 strings, probe compiles |
| Outpost | `build/wo/*.shoptags.map` | **LOAD: OK** |
| Outpost | `build/wo/*.loadout.map` | **LOAD: OK** |
| Outpost | `ready-to-install/ff60_airview.FINAL.map` | **LOAD: OK**, 12 packs, 100,261 strings, probe compiles |

---

## 5. The weapon and ability pools, per map — and why they are not Holdout's

`weapon_palette_choice_block` and `equipment_palette_choice_block` each hold up to 8 weighted
entries and the engine rolls per actor per spawn, so randomised Spartan loadouts cost no script at
all. The indices are `short_block_index` values into the **scenario's** palette, and the two
scenario palettes are not in the same order, so Holdout's numbers are wrong on both maps.

| pool entry | Waterfront index | Outpost index |
|---|---|---|
| `sniper_rifle` | 14 | 12 |
| `rocket_launcher` | 18 | 16 |
| `spartan_laser` | 19 | 17 |
| `plasma_turret` (detached, carryable) | 21 | 21 |
| `grenade_launcher` | 9 | 7 |

| ability | Waterfront index | Outpost index |
|---|---|---|
| `sprint` | 0 | 1 |
| `active_camouflage` | 1 | 0 |
| `drop_shield` | 3 | 3 |
| `jet_pack` | 4 (appended) | 4 (appended) |

**The human machinegun turret trap, confirmed per map.** Outpost ships
`objects\vehicles\human\turrets\machinegun\machinegun` as **vehicle** palette `[0]` — it is a
`vehi`, so a biped cannot hold it and a cell's `initial weapon` cannot name it. Waterfront does
not ship it at all. Weapon palette `[21]` on both maps is the detached Covenant plasma turret,
which is a `weap` and is carryable, and that is what the pool uses.

Palette entry `[2]` on both maps is `objects\gear\human\military\ammo_box\ammo_box`, a gear pickup
rather than an armour ability, and it is deliberately excluded. Neither map ships `armor_lockup`,
so Holdout's "an ally that locks down stops shooting" exclusion does not arise here.

---

## 6. Tuning, and the two per-map warnings the user asked for anyway

`k_fe_actor_limit` is **12**, as asked, on both maps. The author's own playtested figure was 8.

* **Waterfront is the densest hostile geometry of the seven-map set and our earlier per-map
  analysis wanted its cap at 10.** Expect queueing around the base ramps and the water edge with
  a full ally field.
* **Outpost's Deck is one small platform and the earlier analysis wanted its cap at 6.** This is
  implemented at 12 as asked, and the congestion should be expected rather than treated as a bug:
  twelve allies plus the players plus the Covenant wave on a platform that holds five of the six
  kiosks within a 6-wu ball will visibly jam, and the shop sits in the middle of it. Research/06
  derives an engine ceiling of roughly 34 concurrent actors for both sides together, and the
  friendly budget comes out of the same pool as the Covenant spawner, so 12 friendlies will also
  show up as thinner enemy waves.

Both are one line in `src/hsc/fe_reinforcements_wo.hsc`. The Spartan sub-cap is 4, so 12 total
means at most 4 Spartans plus 8 troopers, or 12 troopers, or any mix.

Prices, all the author's (research/14 §6.2) except where noted: troopers 500 for 4 bodies,
Spartans **1,000 for 2**, ammo 500, Longsword 3,000 (his heavy rung is 3,500; 3,000 here because
the pass is one-shot rather than a persistent asset), bank 500 a press, win 10,000. Gates:
Spartans and the Longsword on set ≥ 1, the win on set ≥ 1 — the author's own
`(>= (survival_mode_set_get) 1)`.

---

## 7. What is NOT done, and what could still be wrong

1. **Neither map has been run in MCC.** Blamite loading a cache proves the container and tag graph
   are well formed. It does not prove the engine spawns these squads, that an ally Spartan
   behaves, that a dwell on a 1.10-wu disc is comfortable to hit, or that the price prompts read
   correctly — the on-screen price text is frozen by the `matg` SHA-1 and will show stock numbers.
2. **Two spawn points per squad against a four-actor trooper cell.** Fewer spawn points than
   actors is a shipped configuration in these very maps (Outpost's `sq_sur_sniper_01..04` each
   carry two one-actor cells against a single spawn point), but what the engine does with the
   surplus actors has not been observed. If troopers arrive two at a time instead of four, the fix
   is two more spawn points per squad and another growth pass.
3. **Spawn-zone reuse.** Four squads need eight spawn points and Waterfront has six placed
   respawn zones, Outpost five, so some positions are shared between squads. Two actors assigned
   to one position should be nudged apart by the engine — it does this for players at these very
   zones — but it has not been observed here.
4. **The allies are Spartan-bodied, not Marines or ODSTs.** No stock Firefight cache contains a
   Marine or ODST `char` tag. The cheap tier is called TROOPERS for that reason. A null character
   has no dialogue, so they are silent.
5. **`sur_fireteam_05` and `_06` are free on both maps** and an ODST tier is the obvious next
   addition.
6. **No vehicle tier on either map** (§1.2). This is the one Holdout feature that did not port.
7. **The ammo station replaced the vehicle station rather than being added** — seven things worth
   selling, six always-present anchors, and no seventh anchor exists on Waterfront at all.
8. **Two Holdout defects were found while porting and left alone**, because that map is not this
   task's: its trooper squads are not in the group its own cap check counts (§1.1), and its kiosk
   radius looks large enough for two stations to cross-trigger (§1.3).

---

## 8. Source integrity

| path | state |
|---|---|
| `staged-maps/ff30_waterfront.stage2.map` | opened read-only; unchanged, mtime still `Nov 23 00:54`, sha256 `3e020286438bdd6f750cb97a6279aad157132de9319d2bcd3a337cdde6fec192` |
| `staged-maps/ff60_airview.stage2.map` | opened read-only; unchanged, mtime still `Nov 23 00:54`, sha256 `526e12745032038beac272a89f38f779fbd3d4531a3132f1e086f5a9bde27b81` |
| `maps-stock/ff30_waterfront.map`, `maps-stock/ff60_airview.map` | **never opened** by this task; mtimes still `Nov 22 23:35` |
| every other map in `staged-maps/`, `maps-stock/`, `ready-to-install/` | not read and not written by this task |
| `src/hsc/fe_reinforcements.hsc`, `src/hsc/ff70_holdout.hsc`, `src/hsc/ff70_holdout_stock_hooks.hsc` | **unchanged.** The Holdout library is Holdout's; this task added a sibling rather than editing it |

One discrepancy worth recording: the brief states the `maps-stock/` sources are mode `0444`.
`ff30_waterfront.map` and `ff60_airview.map` are in fact `0644`, as are four of the others; only
`ff50_park.map`, `ff70_holdout.map` and `ff_unearthed.map` are `0444`. Research/20 §6 recorded the
same thing and suggested tightening them. They were left as received rather than changed, because
a permission change to shared source files during parallel work is a worse surprise than the
report.

Two files in `build/logs/` were created by another agent's parallel work during this task
(`shop_survey.py` was overwritten under us). Everything this task created is namespaced `wo_` for
that reason; nothing of another agent's was edited.

---

## 9. Reproducible sequence

```bash
PROJ="$HOME/Desktop/Halo-Firefight/project"; cd "$PROJ"
MAPS="ff30_waterfront ff60_airview"

# read-only survey: object names + flags + positions, palettes, squads, groups, tasks
python3 build/logs/wo_survey.py ~/Desktop/Halo-Firefight/staged-maps/ff30_waterfront.stage2.map \
                                ~/Desktop/Halo-Firefight/staged-maps/ff60_airview.stage2.map \
                                --outdir=build/wo
python3 build/logs/wo_task_probe.py  ~/Desktop/Halo-Firefight/staged-maps/ff60_airview.stage2.map
python3 build/logs/wo_task_attest.py ~/Desktop/Halo-Firefight/staged-maps/ff60_airview.stage2.map

# the map's own scripts, prepared for recompilation
python3 build/logs/wo_prep_stock.py $MAPS

# GATE ON EVERYTHING: does the map's own decompile recompile?
for m in $MAPS; do
  ./build/logs/wo_compile.sh unit ~/Desktop/Halo-Firefight/staged-maps/$m.stage2.map \
      build/wo/fe_culled_shims.hsc build/wo/$m/stock_unescaped.hsc
done

# negative controls - these MUST fail
for f in neg_objectname neg_squad neg_group; do
  ./build/logs/wo_compile.sh unit ~/Desktop/Halo-Firefight/staged-maps/ff30_waterfront.stage2.map \
      build/wo/negctl/$f.hsc
done

# stage A: the ally tiers (grows one page; gated on Blamite inside save())
for m in $MAPS; do python3 build/logs/wo_build_tags.py $m; done

# stage B: same-size patches, then re-gate
python3 tools/patch/patch_map.py build/wo/ff30_waterfront.shoptags.map \
  --set '@0x5F00808:i16=-1' --allow-unmapped --apply \
  --out build/wo/ff30_waterfront.shoptags.reparent.map
python3 tools/patch/patch_map.py build/wo/ff60_airview.shoptags.map \
  --set '@0x47AB3E4:i16=-1' --set '@0x47CA010:i16=1' --set '@0x47CA014:f32=8.0' \
  --set '@0x47CA018:f32=1.0' --set '@0x47CA03E:i16=9' --allow-unmapped --apply \
  --out build/wo/ff60_airview.shoptags.reparent.map
python3 build/logs/wo_trooper_weapons.py ff30_waterfront    # prints the selectors
python3 tools/patch/patch_map.py build/wo/ff30_waterfront.shoptags.reparent.map \
  --set '@0x5F01908:i16=7' --allow-unmapped --apply --out build/wo/ff30_waterfront.loadout.map
python3 tools/patch/patch_map.py build/wo/ff60_airview.shoptags.reparent.map \
  --set '@0x47AC720:i16=6' --set '@0x47AC730:i16=0' --allow-unmapped --apply \
  --out build/wo/ff60_airview.loadout.map
for m in $MAPS; do ./build/logs/wo_compile.sh gate build/wo/$m.loadout.map; done

# stage C: the script write
for m in $MAPS; do
  cp build/wo/$m.loadout.map build/wo/$m.FINAL.map
  ./build/logs/wo_compile.sh write build/wo/$m.FINAL.map \
     build/wo/fe_culled_shims.hsc build/wo/$m/stock_unescaped.hsc \
     src/hsc/fe_reinforcements_wo.hsc src/hsc/$m.hsc
  ./build/logs/wo_compile.sh gate build/wo/$m.FINAL.map
  ./build/logs/wo_compile.sh unit build/wo/$m.FINAL.map build/logs/probe_ok.hsc   # reload test
done

# verify, independently of the writer
for m in $MAPS; do
  python3 build/logs/wo_growthdiff.py $m ~/Desktop/Halo-Firefight/staged-maps/$m.stage2.map \
      build/wo/$m.shoptags.map
  python3 build/logs/wo_bytediff.py   $m build/wo/$m.loadout.map build/wo/$m.FINAL.map
  python3 build/logs/wo_verify.py     $m build/wo/$m.loadout.map build/wo/$m.FINAL.map
done
python3 build/logs/cks.py build/wo/ff30_waterfront.FINAL.map build/wo/ff60_airview.FINAL.map

# publish, then gate the published copy
cp build/wo/ff30_waterfront.FINAL.map ~/Desktop/Halo-Firefight/ready-to-install/
cp build/wo/ff60_airview.FINAL.map    ~/Desktop/Halo-Firefight/ready-to-install/
for m in $MAPS; do ./build/logs/wo_compile.sh gate ~/Desktop/Halo-Firefight/ready-to-install/$m.FINAL.map; done
```

---

## 10. Files

| path | what |
|---|---|
| `ready-to-install/ff30_waterfront.FINAL.map` | **deliverable.** Rename to `ff30_waterfront.map` on the PC |
| `ready-to-install/ff60_airview.FINAL.map` | **deliverable.** Rename to `ff60_airview.map` on the PC |
| `src/hsc/fe_reinforcements_wo.hsc` | the shared purchase library for these two maps |
| `src/hsc/ff30_waterfront.hsc` | Waterfront's six kiosks, ally refresh and startup (rewritten; the previous 557-line version referenced 53 objects this map does not have) |
| `src/hsc/ff60_airview.hsc` | Outpost's equivalent (rewritten from 554 lines, same reason) |
| `build/wo/fe_culled_shims.hsc` | the `player_count` shim both maps need |
| `build/wo/<map>/stock_unescaped.hsc` | each map's own decompile with doubled backslashes collapsed |
| `build/logs/wo_survey.py` | read-only scenario survey: names, flags, positions, palettes, squads, groups, tasks |
| `build/logs/wo_task_probe.py`, `wo_task_attest.py` | the `obj_fireteams` task, field by field, and the values its own map attests |
| `build/logs/wo_prep_stock.py` | the backslash collapse and the culled-script report |
| `build/logs/wo_build_tags.py` | stage A: spawn points, Spartan cells, jet-pack palette append |
| `build/logs/wo_trooper_weapons.py` | prints the trooper-weapon selectors for stage B |
| `build/logs/wo_compile.sh` | one wrapper for every compile and every Blamite gate |
| `build/logs/wo_growthdiff.py` | shift-aware byte diff for the growth stage |
| `build/logs/wo_bytediff.py` | clustered byte diff for the script write, with the `matg` uniform-delta check |
| `build/logs/wo_verify.py` | independent re-read of a published artifact |
| `build/wo/negctl/*.hsc` | the three negative controls |
| `build/wo/*.shoptags.json`, `build/wo/verify/*` | per-stage build and verification records |
| `build/wo/logs/*.log` | every compile log behind the numbers above |
