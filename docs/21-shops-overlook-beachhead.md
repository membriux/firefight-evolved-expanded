# 21 — The purchase system on Overlook and Beachhead

**Date:** 2026-11-23
**Reference replicated:** `ready-to-install/ff70_holdout.FINAL.map` (research/19, research/20, `build/logs/fe_compile_FINAL.log`)
**Inputs:** `staged-maps/ff10_prototype.stage2.map`, `staged-maps/ff50_park.stage2.map`
**Outputs:** `ready-to-install/ff10_prototype.FINAL.map`, `ready-to-install/ff50_park.FINAL.map`
**Verdict: both maps shipped. Both passed the Blamite gate twice (tag write, then bytecode write), both re-parse with zero warnings, both have a self-consistent checksum and a fully classified byte-diff.**

Results are stated per map throughout. Nothing in this document is averaged across the two.

---

## 1. Headline table

| | **Overlook** `ff10_prototype` | **Beachhead** `ff50_park` |
|---|---|---|
| stock script objects referenced | **16**, all stock (9 `object_name`, 4 `ai_squad`, 3 `ai_squad_group`) | **16**, all stock (same split) |
| new script objects created | **0** | **0** |
| shop proximity anchors | `health_pack0..5` — six `health_station` device_controls, scnr `controls[0..5]`, placement flags `0x00000000` | `health_pack0..5` — same block, same tag, same flags |
| fireteam slots used | troopers `sur_fireteam_01`, `_02`; Spartans `sur_fireteam_03`, `_04`; `_05`/`_06` left free | troopers `sq_elite_fireteam_01`, `_02`; Spartans `sq_elite_fireteam_03`, `_04`; `_05`/`_06` left free |
| reparent patch applied | **yes**, `@0x58DD648:i16 = 7 → -1` | **yes**, `@0x4F3C11C:i16 = 5 → -1` |
| compiled | **yes** — 397 scripts, 222 globals, 16,635 expressions, 19 tag refs | **yes** — 415 scripts, 222 globals, 17,175 expressions, 18 tag refs |
| bytecode written | **yes** (`hsc-compile --write`, log `build/logs/ovbh_ff10_prototype_FINAL.log`) | **yes** (log `build/logs/ovbh_ff50_park_FINAL.log`) |
| Blamite verdict, tag write | **LOAD: OK** | **LOAD: OK** |
| Blamite verdict, published file | **LOAD: OK**, 12 packs / 100,261 strings | **LOAD: OK**, 12 packs / 100,061 strings |
| re-parse warnings | **0** (14,650 tags / 235 groups / 14,645 named / 71,326 sids) | **0** (14,034 tags / 235 groups / 14,030 named / 70,697 sids) |
| checksum stored == computed | **yes**, `0xA460F086` | **yes**, `0x81B296F1` |
| byte-diff unexplained runs | **0** | **0** |
| final size | 190,615,552 stock → 190,681,088 stage-2 → **190,746,624** | 172,179,456 stock → 172,244,992 stage-2 → **172,314,624** |
| sha256 | `b7f9b365e3dfe74a97659948e2b0d96559d439246402a548b28073b71f5ac6d5` | `5369491602f3572f08b828ef923a3a99cfcaa90d4b9a82baf350f45660aa8c32` |
| blocked by | nothing | nothing |

**Install:** copy to `…\haloreach\maps\` renamed to exactly `ff10_prototype.map` / `ff50_park.map`, launch with
*Play Halo: MCC Anti-Cheat Disabled*, gametype FIREFIGHT EVOLVED. Neither map has run in retail MCC.

---

## 2. What was read before anything was written

Every fact below came out of that map's own `scnr` tag through `build/ovbh/survey_ovbh.py`
(a map-agnostic census: object names, every placement block with its palette tag, placement
flags and world position, squads with cells / spawn points / parent / objective, squad groups
with their full parent chain, the four palettes, and the AI objectives with their task
names, follow modes and squad-group filters).

### 2.1 The anchors, and the three candidate sets that were rejected

Research/19 §5 suggested `sc_hack_*`, `sc_resupply_*`, `generator_switch*`, `ammo_crate0/1` and
`health_pack0..5`. On these two maps most of that list is unusable, and the reason is in the bytes:

| candidate | Overlook | Beachhead | usable? |
|---|---|---|---|
| `health_pack0..5` | flags `0x0`, at (142–149, 49–58, 0.41/−1.41) — inside the base | flags `0x0`, at (−174…−190, 43–61, −33…−37) — inside the base | **yes** |
| `sc_resupply_01..09` | flags `0x1`, prop farm at (124–127, 35–39, −1.5) | flags `0x1`, prop farm at (−99…−109, −6…10, −7.9) | no |
| `hack_laser` / `hack_rocket` / `hack_sniper` / `hack_target` (Overlook), `sc_hack_*` (Beachhead) | flags `0x1`, same prop farm | flags `0x1`, same prop farm | no |
| `sc_target_01..03` | flags `0x1`, same prop farm | flags `0x1`, same prop farm | no |
| `generator_switch0..2` and the `_cool` / `_disabled` variants | flags `0x1` | flags `0x1` | no |
| `ammo_crate0/1` | flags `0x101` | flags `0x101` | not as an anchor (used as the *goods*) |

Placement flag bit 0 is "not automatically", so a flag-`0x1` object does not exist until a script
creates it — and on both maps the whole `sc_*` / `hack_*` set also sits 20 world units (Overlook)
or 80 world units (Beachhead) away from the player base, where no player can stand. This is the
same trap research/19 §5 recorded on Holdout, re-confirmed independently on each of these two maps
rather than carried over.

The health stations are not merely present, they are Bungie's own proximity objects: each map's
stock `survival_health_pack_highlight` tests exactly these six with
`(objects_distance_to_object pack subject)` against a radius of 3 (Overlook decompile L2831,
Beachhead L3072). The shop uses the same call on the same objects at a radius of 2.5.

**Stated plainly: these are the map's health stations. Standing at one to buy is standing at one to
heal, and the two uses are not separated.** Overlook has no other always-present interactive object
inside the base at all — unlike Holdout, which could fall back on ten `#_m70_door_*` machines — so
Overlook's shop is **six** stations, not Holdout's seven. Beachhead *does* have nine more
always-placed device machines in the arena (`dm_resupply_01..09`, flags `0x0`), so a seventh station
is physically possible there; it was not taken, because their palette tag is `invis_resupply_capsule`
and an invisible kiosk is one a player cannot find. Both maps therefore ship the same six stations,
which also keeps the two experiences comparable.

### 2.2 The six stations, identical on both maps

| anchor | tier | price | gate |
|---|---|---|---|
| `health_pack0` | TROOPERS, 4 bodies | 500 | always |
| `health_pack1` | SPARTANS, 2 bodies | 1,000 | set ≥ 1 |
| `health_pack2` | AMMO RESUPPLY | 500 | always |
| `health_pack3` | LONGSWORD PASS | 3,000 | set ≥ 1 |
| `health_pack4` | BANK | 500 a press | always |
| `health_pack5` | MAC STRIKE / WIN | 10,000 | set ≥ 1 |

`k_fe_actor_limit = 12`, Spartan sub-cap `k_fe_spartan_limit = 4`, troopers 500 a squad,
Spartans 1,000 for two, win 10,000 — the author's numbers, as instructed. Score is charged with a
**negative `campaign_metagame_award_points` against the buyer**, identified by
`human_player_in_game_get N` over all eight slots; `player0` is never used for the charge.

One deviation from the brief, stated rather than hidden: the brief said "troopers 500 for 6". **The
squad delivered is four bodies, not six, on both maps.** The cell that spawns it is the stage-2 cell,
whose `normal diff count` is 4 because it was copied from that map's own `sq_sur_drop_01`. Six would
need two more actors than the cell declares and two more spawn points; 4 is the value attested in the
map, so 4 is what shipped, at the author's 500. 2 trooper squads × 4 + 2 Spartan squads × 2 = 12,
which is exactly `k_fe_actor_limit`, so the cap binds at the moment the last handle fills.

### 2.3 No air-support tier on either map

Holdout's air tier flipped `sq_sur_banshee_01/02` to team `human`. **Neither of these maps ships a
banshee squad.** What they do ship:

* **Overlook**: `sq_sur_wraith_01/02` only, spawn points at (316.9–322.0, 105.9–115.2, 40.9–41.5) —
  a staging area ~180 world units from the base and 40 units above it. A bare `ai_place` would stand
  an allied Wraith up outside the playable space. Dropped.
* **Beachhead**: `sq_sur_ghost_01/02` and `sq_sur_wraith_01/02`, spawn points at
  (−125.6…−131.5, 58.8–63.3, −19.9…−20.3) — *inside* the arena, because that is where this map's
  stock Covenant vehicles enter. An allied Ghost tier is genuinely possible here. It was not shipped:
  it would be the only feature one of these two maps had and the other did not, and it depends on a
  vehicle pathing 60 world units into the base under a follow task, which has never been observed.

The station that would have carried air support carries the Longsword pass on both maps instead.

---

## 3. The ally bodies: a deliberate departure from Holdout, away from a bug

Holdout put its trooper tier in `sq_sur_drop_01..04` because those were the only Holdout squads with
both a populated cell and spawn points, and it flew them in with the map's own drop-pod sequence.
On these two maps that choice is actively wrong, and the stock script says why:

```
; ff10_prototype.hsc L5140-5144, ff50_park.hsc L5511-5514  (survival_drop_pod_manager)
(ai_erase "sq_sur_drop_01") … (ai_erase "sq_sur_drop_05")   ; Overlook; _04 on Beachhead
…
(set g_sur_drop_count 0)
(set g_sur_drop_spawn true)
```

Allies living in those squads would be **deleted at every round transition**, and the stock enemy pod
event would **switch itself back on** after the two-line hook turned it off. Holdout's
`ff70_holdout_stock_hooks.hsc` has the same exposure; it is a latent flaw in the reference, not
something introduced here.

The alternative was already sitting in both caches. Both maps ship **six empty fireteam handles**
(`sur_fireteam_01..06` / `sq_elite_fireteam_01..06`), all parented to `gr_survival_fireteams`, all
already carrying `obj_fireteams` as their initial objective, whose single task `fireteams` Bungie had
already filtered to the fireteams group with `follow = player` and follow radius 3.0 — and **no stock
script on either map references any of the six**. The stage-2 build had already given handles 01 and
02 a 4-actor cell each. The only thing they lacked was spawn points, which is exactly what
`tools/patch/holdout_fe_spartans.py` already proved can be authored.

So on these two maps **both** tiers live in the fireteam handles and spawn on foot inside the base:

| | Overlook | Beachhead |
|---|---|---|
| troopers | `sur_fireteam_01` (4 actors, major `none`, DMR), `sur_fireteam_02` (4 actors, major `none`, assault rifle) | `sq_elite_fireteam_01` (4, `none`, DMR), `sq_elite_fireteam_02` (4, `none`, assault rifle) |
| Spartans | `sur_fireteam_03`, `sur_fireteam_04` (2 actors each, major `all`) | `sq_elite_fireteam_03`, `sq_elite_fireteam_04` (2 actors each, major `all`) |
| free | `_05`, `_06` | `_05`, `_06` |

Consequences, all of them improvements over the reference:

1. **No stock script is edited at all.** There is no `*_stock_hooks.hsc` for either map. Holdout
   needed two lines; these need none. The stock drop-pod event stays stock and keeps dropping
   enemies, which is what it is for.
2. No drop-pod ride, so no `ai_vehicle_get_from_spawn_point` / `objects_attach` /
   `device_set_position` sequence and none of its failure modes.
3. `(ai_living_count "gr_survival_fireteams")` is the exact ally count with no correction term,
   because after the reparent that group contains the six fireteam handles and nothing else.
4. The round-robin rotor Holdout used is replaced by a **per-squad emptiness test**
   (`(= (ai_living_count "<squad>") 0)`), which is what actually prevents re-placing a squad that
   still has living members. A shared-budget check alone would permit it: with 4 troopers and 4
   Spartans alive the budget still shows 4 free slots.

### 3.1 Spawn positions: the map's own player respawn zones

Spawn points were cloned from that map's own `sq_sur_drop_01` spawn point (124 bytes, `place on` all
zeros, `reference frame` −1, `structure bsp` 0 — nothing drop-pod-specific except `vehicle type` and
`seat type`, both neutralised to −1 / 0) and positioned on the auto-placed `spartan_respawn_*`
`firefight_respawn_zone` scenery, read out of the cache at build time. That ground is known walkable
and known inside the base because the game spawns players on it, and it is the precedent Holdout's
Spartan tier set.

| | zones available | troopers 01 / 02 | Spartans 03 / 04 |
|---|---|---|---|
| Overlook | 5 (`spartan_respawn_01..05`) | 01,02,03,04 / 05,04,01,03 | 01,03 / 02,05 |
| Beachhead | 6 (`spartan_respawn_01..06`) | 01,02,03,04 / 05,04,01,03 | 01,03 / 02,05 |

The two trooper squads draw from the same small set of zones and share some of them. They cannot
spawn in the same tick — each purchase is gated by the per-station 5-second cooldown and by the
squad-empty test — and by the time the second squad lands the first is following the player. This is
the one place the design accepts an overlap rather than inventing a coordinate.

### 3.2 A trap in the staged input, found and avoided

The stage-2 cells on handles 01 and 02 were copied from `sq_sur_drop_01`'s cell, and the copy still
**shared that cell's `initial weapon` choice blob with the live enemy squad**:

```
Overlook   sur_fireteam_01.D0      weap@0x58DEBEC    <-- same address
           sur_fireteam_02.D0      weap@0x58DEBEC
           sq_sur_drop_01.D0       weap@0x58DEBEC    (enemy, 4 grunt_heavy)
Beachhead  sq_elite_fireteam_01.D0 weap@0x4F3D884
           sq_elite_fireteam_02.D0 weap@0x4F3D884
           sq_sur_drop_01.D0       weap@0x4F3D884    (enemy, 4 grunt_heavy)
```

Rewriting that blob in place to arm the allies would have re-armed an enemy squad. New weapon-choice
entries were allocated in the grown page and the two ally cells repointed at them instead; the stock
cell is untouched. Without this check the troopers would have carried a flak cannon and
`sq_sur_drop_01`'s grunts would have carried a DMR.

### 3.3 The ally character, re-asserted per map

`objects\characters\null\ai\null_cov_default` with its `unit` `tag_reference` datum repointed to
`objects\characters\spartans\spartans`, as staged. Both maps were re-checked with
`build/ovbh/verify_victim.py`, which walks **every designer AND templated cell of every squad**:

| | palette slot | char tag | unit datum file offset | referenced by any stock cell? |
|---|---|---|---|---|
| Overlook | `[25]` | 9656 | `0x9974364` | **no** — only by `sur_fireteam_01.D0` and `_02.D0`, i.e. stage-2's own cells |
| Beachhead | `[21]` | 8762 | `0x7FE99C0` | **no** — only by `sq_elite_fireteam_01.D0` and `_02.D0` |

So the repoint cannot change any shipped enemy on either map. The allies are Spartan-bodied and
silent, because a null character has no dialogue; the cheap tier is called TROOPERS, not Marines.

---

## 4. The reparent, and why it is not optional

Both maps ship the chain research/20 recorded, and it was re-walked from the group table of the
**staged input**, not taken from the note:

```
Overlook   [8] gr_survival_fireteams  parent = 7  ->  gr_survival_waves  ->  gr_survival_all
Beachhead  [6] gr_survival_fireteams  parent = 5  ->  gr_survival_waves  ->  gr_survival_all
```

Both maps' stock `survival_wave_living_count` reads `(ai_living_count "gr_survival_all")`. Left as
shipped, every purchased ally is counted as a live enemy, the wave never reports clear and the round
never ends. The fix is the same 2-byte same-size write on each map, applied inside the tag build so
it is covered by the same Blamite gate:

| map | selector | before | after |
|---|---|---|---|
| Overlook | `@0x58DD648:i16` | `7` | `-1` |
| Beachhead | `@0x4F3C11C:i16` | `5` | `-1` |

Both offsets match the selectors research/20 §1 recorded against the published stage-2 caches. Both
re-read as `-1` from the finished `.FINAL.map` after the bytecode write. Nothing in the script
compensates for this write; without it the map hangs between waves.

Two downstream behaviours depend on it, and both were checked: `fe_deliver_strike` kills
`gr_survival_waves` and `fe_mission_won` kills `gr_survival_all` — after the reparent neither group
contains the allies, so a Longsword pass cannot kill the player's own troopers and the win does not
wipe them before the match ends.

---

## 5. The Spartan loadout: zero script work, and the palettes really do differ

`weapon_palette_choice_block` and `equipment_palette_choice_block` hold up to 8 weighted entries each
and the engine rolls per actor per spawn. Every index below was resolved **by tag path against that
map's own palette** at build time, and anything the map does not ship was dropped with a printed note
rather than substituted.

### 5.1 Weapons

| wanted (Holdout's pool) | Overlook index | Beachhead index |
|---|---|---|
| `sniper_rifle` | 8 | 8 |
| `rocket_launcher` | 11 | 12 |
| `spartan_laser` | 12 | 13 |
| detached `plasma_turret` (`weap`) | 15 | **absent — dropped** |
| `grenade_launcher` | 19 | 21 |
| pool size | **5** | **4** |

Beachhead's weapon palette has 22 entries like Overlook's but in a different order, and its slot
`[16]` is a **null tag** (`0xFFFFFFFF`). The detached Covenant plasma turret is not in it at all, so
Beachhead's Spartans have a four-weapon pool. `plasma_launcher` *is* in Beachhead's palette (index 11)
and was deliberately not added: Holdout had it too (index 20) and excluded it, and matching the
reference pool mattered more than filling the slot.

The human machinegun turret remains unavailable to both: `objects\vehicles\human\turrets\machinegun\machinegun`
is a `vehi`, not a `weap`, so a biped cannot hold it and a cell's `initial weapon` cannot name it.

### 5.2 Abilities, and a palette append wider than Holdout's

Both maps ship an equipment palette of only **two** entries — `[0] ammo_box`, `[1] drop_shield` —
while `sprint`, `jet_pack` and `active_camouflage` are present in each map's **tag table** but not in
the scenario palette. `initial equipment` is a `short_block_index` into that palette, so the tag
existing is not enough. Three entries were cloned from the `drop_shield` entry with their datums
swapped, exactly the mechanism `holdout_fe_spartans.py` used for camo:

| | before | after | appended |
|---|---|---|---|
| Overlook | 2 | **5** | `[2] sprint` (datum `0x822D1B0D`), `[3] jet_pack` (`0x899A21D3`), `[4] active_camouflage` (`0x89FC2223`) |
| Beachhead | 2 | **5** | `[2] sprint` (`0xFEE9183A`), `[3] jet_pack` (`0x87A72045`), `[4] active_camouflage` (`0x88062092`) |

Ability pool on both maps: `[1] drop_shield`, `[2] sprint`, `[3] jet_pack`, `[4] active_camouflage` —
the same four Holdout ended up with. `evade` and `armor_lockup` are in both tag tables and both were
left out, following Holdout: four abilities is already a wide pool, and an ally that locks down
mid-fight stops shooting.

**This is the single largest structural step beyond the reference** — Holdout grew its palette by one
entry, these grow by three. It is verified structurally (Blamite loads it, the palette re-reads with
all five entries pointing at real `eqip` tags, the cells' equipment choices re-read as `[1,2,3,4]`)
and it is **not** verified in game, because nothing here has run in retail MCC.

`major upgrade` is 4 (`all`) on the Spartan cells and the stock 3 (`none`) on the trooper cells. That
is the whole durability difference and it costs no tag beyond the field.

---

## 6. The script half

### 6.1 Files

| file | role |
|---|---|
| `src/hsc/fe_shop_lib.hsc` | **new.** The map-agnostic purchase library: prices, tuning, sounds, state, `fe_valid`/`fe_near`, the eight-slot buyer identification and charge, feedback, the budget off the root group, the set/round gates, `fe_transact`/`fe_wait_at`, the bank, the ammo delivery, the Longsword pass, and the win. |
| `src/hsc/ff10_prototype.hsc` | **rewritten in place** (the pre-rewrite version named ~50 objects this map does not have). Overlook's four squad handles, the six kiosks, the housekeeping loop and the startup script. |
| `src/hsc/ff50_park.hsc` | **rewritten in place.** The same for Beachhead. |
| `src/hsc/fe_reinforcements.hsc` | **untouched.** It is Holdout's library and every delivery script in it names a Holdout object; other maps are being ported against it in parallel. `fe_shop_lib.hsc` exists so that file did not have to be edited. |

Unit order for the write, per map: `<map>.stock.hsc` → `fe_shop_lib.hsc` → `<map>.hsc`.

### 6.2 The culled script, and why the Holdout shim was the wrong fix here

Both maps have Holdout's `player_count` problem: the shipped bytecode calls `player_count`
(3 call sites on each map) and the recompile fails with *"Tried to find opcode named 'player_count'
but could not. It may actually be a culled script if this is an unmodified map."*

Holdout's answer was `build/holdout/unit/fe_culled_shims.hsc`, which **adds** a new script named
`player_count` implemented as `(list_count (players_human))`. That was tried here first and the
resulting table was inspected entry by entry. It showed what is actually going on:

* The script is **not** culled from the table. It is entry 157 of each map's 359/377-entry script
  table, with stringID `0x00080336`.
* `reach_cache.resolve_sid` cannot resolve that namespace. On Holdout `decompile.py` emitted the raw
  marker `<!SID:0x00080336!>`; on these two maps it resolves to the wrong name,
  `prop_firefight_difficulty_highest_official_score`.
* Its real body is in the decompile and is Bungie's own: `(script static short <name> (list_count (players)))`.

So the correct fix is a **rename, not a shim**: `build/ovbh/decomp_ovbh.sh` renames that one
declaration to `player_count` after collapsing the backslashes, guarded by four assertions (the
mis-resolved name occurs exactly once, it is that `static short` declaration, something does call
`(player_count)`, and there are exactly three such call sites). The result keeps the stock table at
exactly 359 / 377 scripts, keeps Bungie's `(list_count (players))` body, and adds no duplicate. The
shim file was deleted from this build.

The same fix should be considered for Holdout: its published `.FINAL.map` carries both the shim
(`player_count` → `list_count (players_human)`) and the still-mis-named original.

Also worth recording: `player0..player3` are real **stock scripts** on both maps
(`(script static unit player0 (player_get 0))`), which is why they appear in the decompiled text even
though `player0` is not an opcode in the U13 table. The shop does not use them.

### 6.3 Other known traps, handled

* **`\\` in tag paths.** `decomp_ovbh.sh` collapses the decompiler's doubled backslashes before the
  compile (Overlook 179,223 → 179,081 bytes; Beachhead 185,681 → 185,543). Blamite takes `\\`
  literally, so every tag path in a global or call would otherwise be wrong.
* **`print` is `null="true"` in MCC.** Every `print` the shop adds is behind `(if g_fe_debug …)`.
  The 180–188 `unimplemented` lint findings per compile are all stock `print`/
  `ai_squad_enumerate_immigrants` call sites in Bungie's own text.
* **A bare `ai_place` spawning outside the arena.** Checked per squad; this is exactly why both tiers
  were given authored in-base spawn points and why the vehicle tier was dropped (§2.3, §3.1).
* **Name collisions.** Everything added is prefixed `fe_` / `k_fe_` / `g_fe_` / `sfx_fe_`, and
  neither map's 197 stock globals nor their 359 / 377 stock scripts use any of those prefixes. The
  one stock global the shop would have shadowed, `sfx_blip`, is declared `sfx_fe_blip` instead.
  Verified after the write: the 38 added scripts and 25 added globals are *all* `fe_`-prefixed and
  every stock stringID and global name survived.
* **Sound tags.** `transition_beeps`, `flag_failure` and `omaha_ui\…\winning_bonus` were confirmed
  as `snd!` in each map's own tag table (Overlook 9680 / 5115 / 10599, Beachhead 8789 / 4399 / 9729).
* **The Longsword track name.** `(device_set_position_track "dm_longsword_01" "ff10" 0)` and
  `(device_animate_position … 1 10 3 3 false)` are copied call for call from each map's own stock
  resupply event (Overlook L5437-5438, Beachhead L5765-5766), so `"ff10"` is attested per map.

### 6.4 Negative controls — four of them, all rejecting

The brief asked for one. Four were run, because the compiler's `[objects]` section reports some
unresolved references non-fatally (`ai_current_actor`, `ai_current_squad`, both stock on both maps,
both also unresolved in Holdout's own successful build) and it was worth establishing that a bad
*name* is fatal rather than merely listed.

| control | result |
|---|---|
| `"gr_survival_fireteams"` → `"gr_fe_imaginary_group"` | **FAILED** at `fe_shop_lib_negative.hsc:258:21` — *Failed to process the expression "gr_fe_imaginary_group". A "ai" expression was expected.* |
| `"health_pack2"` → `"health_pack_definitely_not_real"` | **FAILED** at `ff10_negative_objname.hsc:162:24` — *… A "object" expression was expected.* |
| `"sur_fireteam_04"` → `"sur_fireteam_99_does_not_exist"` | **FAILED** at `ff10_negative_squad.hsc:70:60` — *… A "ai" expression was expected.* |
| **cross-map:** Overlook's wiring compiled against Beachhead's cache, and Beachhead's against Overlook's | **both FAILED** on the very first squad reference (`"sur_fireteam_01"` / `"sq_elite_fireteam_01"`) |

The cross-map control is the strongest of the four: it shows resolution is against *this* cache's
scenario and not a shared name list, so every surviving name in each map's file is an object that map
actually has.

### 6.5 Compile results

| | Overlook | Beachhead |
|---|---|---|
| stock round-trip alone (after the rename) | **OK** — 359 scripts, 197 globals, 15,362 expressions | **OK** — 377 scripts, 197 globals, 15,902 expressions |
| full unit, dry run | **OK** — 397 / 222 / 16,635 | **OK** — 415 / 222 / 17,175 |
| full unit, `--write` | **OK, bytecode written** | **OK, bytecode written** |
| syntax errors | 0 | 0 |
| unresolved script objects | 2, both stock (`ai_current_actor`, `ai_current_squad`) | 2, both stock |
| dialect rewrites needed | 0 | 0 |

For comparison, Holdout's reference build was 423 scripts / 235 globals / 17,889 expressions. These
are smaller because Holdout's stock table is larger (377 vs 359) and Holdout added the shim plus the
stock-hooks file that these two maps do not need.

A standing characteristic of the toolchain, not a defect of this build: the recompiled expression
count is ~15% below the decompiled count (Overlook 19,261 decompiled → 16,635 compiled; Beachhead
19,888 → 17,175). Holdout showed the same gap (20,164 → 17,889). It reflects how `decompile.py`
counts nodes versus how Blamite emits them, and the round-trip compiles cleanly either way.

---

## 7. Verification, per output, independent of every writer

### 7.1 Tag write (`stage2` → `.shop`) — `build/ovbh/verify_shop.py`, 11 checks each

| check | Overlook | Beachhead |
|---|---|---|
| re-parse, zero warnings | ✅ 14,650 / 235 / 14,645 / 71,288 sids | ✅ 14,034 / 235 / 14,030 / 70,659 sids |
| stored checksum == computed | ✅ `0x80730502` | ✅ `0xA868F089` |
| ally char resolves to `spartans\spartans` | ✅ | ✅ |
| `gr_survival_fireteams` reads as root | ✅ | ✅ |
| equipment palette grew to 5 with the appended tags | ✅ | ✅ |
| trooper squads exactly as asked (4 actors, major 3, veh −1, char slot, weapon pool, 4 on-foot spawn points) | ✅ | ✅ |
| Spartan squads exactly as asked (2 actors, major 4, veh −1, weapon pool, ability pool, 2 on-foot spawn points) | ✅ | ✅ |
| size grew by exactly the granted page | ✅ +0x10000 | ✅ +0x10000 |
| byte-diff: intended runs only | ✅ 29 runs, **0 unexplained** | ✅ 29 runs, **0 unexplained** |
| Blamite loads the output | ✅ | ✅ |
| Blamite locale packs/strings identical to the input | ✅ 12 / 100,261 | ✅ 12 / 100,061 |

The inserted 0x10000 page is compared separately rather than skipped: **679 non-zero bytes** on
Overlook and **579** on Beachhead — the relocated 5-entry equipment palette, the choice entries, two
Spartan cells and twelve spawn points — and zero elsewhere. The 13 header runs are the ones
research/20 §5.1 enumerated (`file_size`, `virtual_size`, partition 5 size, `checksum`, the
localization **offset mask**, the tag section size); every other run lies wholly inside one of the
nine in-place block fields the build manifest records.

### 7.2 Bytecode write (`.shop` → `.FINAL`) — `build/ovbh/verify_final.py`, 12 checks each

| check | Overlook | Beachhead |
|---|---|---|
| re-parse, zero warnings | ✅ 14,650 / 235 / 14,645 / 71,326 sids | ✅ 14,034 / 235 / 14,030 / 70,697 sids |
| stored checksum == computed | ✅ `0xA460F086` | ✅ `0x81B296F1` |
| every stock script stringID survived | ✅ 359 → 397 | ✅ 377 → 415 |
| every stock global name survived | ✅ 197 → 222 | ✅ 197 → 222 |
| all 20 probed shop scripts present | ✅ | ✅ |
| all 14 probed shop globals present | ✅ | ✅ |
| **only** `fe_`-prefixed names added | ✅ 38 scripts + 25 globals | ✅ 38 scripts + 25 globals |
| script count delta is exactly 38 | ✅ | ✅ |
| byte-diff fully classified | ✅ **0 unexplained** of 76,854 runs | ✅ **0 unexplained** of 288,838 runs |
| Blamite loads the output | ✅ | ✅ |
| locale packs/strings identical to the input | ✅ 12 / 100,261 | ✅ 12 / 100,061 |
| tag data re-read unchanged after the write | ✅ 7/7 (`build/ovbh/recheck_tags_final.py`) | ✅ 7/7 |

Script-table checks compare **raw stringIDs**, not reader-resolved names, precisely because
`resolve_sid` cannot handle namespace-8 values (§6.2); a name-based check reports a false failure on a
cache that is in fact correct.

Byte-diff classification by region:

| region | Overlook runs | Beachhead runs |
|---|---|---|
| cache header | 13 | 16 |
| debug/strings section (stringID table + the 38 new names) | 75 | 209,627 |
| tag data area (rebuilt script tables, string and expression data) | 76,759 | 79,195 |
| `scnr` tag body (script/global/expression block fields) | 7 | 0 (inside the shifted region) |
| **unexplained** | **0** | **0** |

**Beachhead's file grew by 0x1000 during the bytecode write and Overlook's did not.** Blamite had to
lengthen Beachhead's debug/strings section to fit the new script names. That is not improvised
tolerance: the verifier *asserts* the two header facts that locate the insert — the FINAL cache's tag
area starts exactly `delta` later than the input's (`0x2925000` → `0x2926000`) and the debug section's
declared size grew by exactly `delta` — and refuses to classify anything if either is false. The tail
is then compared against itself rather than against shifted data. Holdout's own published `.FINAL.map`
grew by the same 0x1000 for the same reason, so this is the reference behaviour. Beachhead's much
larger run count in the strings section is the string blob moving inside that section, not content
appearing from nowhere; its locale packs and string count are byte-for-byte what its input had.

### 7.3 Source integrity

| path | state |
|---|---|
| `maps-stock/ff10_prototype.map` | **never opened.** mtime unchanged (Nov 22 23:35), sha256 `8dfc3ecbb888374f…` |
| `maps-stock/ff50_park.map` | **never opened.** Still mode `0444`, mtime unchanged, sha256 `9bccad85d9c60192…` |
| `staged-maps/ff10_prototype.stage2.map` | opened read-only. Unchanged: sha256 `8d71f733707310de…`, mtime Nov 23 00:46 |
| `staged-maps/ff50_park.stage2.map` | opened read-only. Unchanged: sha256 `fe0525d46c70459e…`, mtime Nov 23 00:54 |
| the other six maps in `staged-maps/` and `ready-to-install/` | not touched by this task |
| `src/hsc/fe_reinforcements.hsc`, `src/hsc/ff70_holdout*.hsc` | not modified |

Assertion suites, re-run on the tooling as it stands: `test_parse_map.py` **234 passed, 0 failed**;
`test_reach_write.py` **560 assertions, 0 failures**; `test_patch_map.py` **472 assertions, 0 failed** —
**1,266 assertions, 0 failures**, matching research/20 §7. Both writer suites print their own caveat
that they are synthetic-only, which is why the Blamite gate and not the suite is the publishing
condition.

---

## 8. Reproducible sequence

```bash
PROJ="$HOME/Desktop/Halo-Firefight/project"; cd "$PROJ"
S="$HOME/Desktop/Halo-Firefight/staged-maps"
export PROJ

# read-only survey, then the per-map decisions it feeds
for m in ff10_prototype ff50_park; do
  python3 -I build/ovbh/survey_ovbh.py $S/$m.stage2.map build/ovbh/$m.survey.json
  python3 -I build/ovbh/report_ovbh.py build/ovbh/$m.survey.json all
done
python3 -I build/ovbh/anchors_ovbh.py build/ovbh/ff10.survey.json 12   # anchor candidates in the base box
python3 -I build/ovbh/verify_victim.py $S/ff10_prototype.stage2.map 25 # the ally char, incl. templated cells
python3 -I build/ovbh/verify_victim.py $S/ff50_park.stage2.map 21
python3 -I build/ovbh/cellptrs.py $S/ff10_prototype.stage2.map        # finds the shared weapon blob
python3 -I build/ovbh/spdump.py $S/ff10_prototype.stage2.map sq_sur_drop_01   # the spawn-point template

# tag build; CacheWriter.save() publishes only if `hsc-compile --load-only` accepts the cache
python3 -I build/ovbh/build_shop_tags.py $S/ff10_prototype.stage2.map \
        build/ovbh/out/ff10_prototype.shop.map build/ovbh/out/ff10.tagmanifest.json
python3 -I build/ovbh/build_shop_tags.py $S/ff50_park.stage2.map \
        build/ovbh/out/ff50_park.shop.map build/ovbh/out/ff50.tagmanifest.json
python3 -I build/ovbh/verify_shop.py build/ovbh/out/ff10.tagmanifest.json build/ovbh/out/ff10.tagverify.json
python3 -I build/ovbh/verify_shop.py build/ovbh/out/ff50.tagmanifest.json build/ovbh/out/ff50.tagverify.json

# decompile each map's complete script table, collapse "\\", rename the mis-named player_count
./build/ovbh/decomp_ovbh.sh build/ovbh/out/ff10_prototype.shop.map ff10_prototype build/ovbh/unit
./build/ovbh/decomp_ovbh.sh build/ovbh/out/ff50_park.shop.map     ff50_park      build/ovbh/unit

# compile + write, then verify independently
cd tools/compile
export DOTNET_ROLL_FORWARD=LatestMajor DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
export BLAMITE_FORMATS="$PWD/bin/Release/net8.0/Formats"
for m in ff10_prototype ff50_park; do
  cp ../../build/ovbh/out/$m.shop.map ../../build/ovbh/out/$m.FINAL.map
  dotnet bin/Release/net8.0/hsc-compile.dll --formats "$BLAMITE_FORMATS" --unit --write \
    --hsc ../../build/ovbh/unit/$m.stock.hsc \
    --hsc ../../src/hsc/fe_shop_lib.hsc \
    --hsc ../../src/hsc/$m.hsc \
    --xml ../hsc/tables/reachmcc_u13.xml --map ../../build/ovbh/out/$m.FINAL.map
done
cd "$PROJ"
for p in ff10:ff10_prototype ff50:ff50_park; do k=${p%%:*}; m=${p##*:}
  python3 -I build/ovbh/verify_final.py build/ovbh/out/$m.shop.map build/ovbh/out/$m.FINAL.map \
          build/ovbh/out/$k.finalverify.json
  python3 -I build/ovbh/recheck_tags_final.py build/ovbh/out/$k.tagmanifest.json build/ovbh/out/$m.FINAL.map
done

# negative controls (all four must FAIL)
# see §6.4; scripts in build/ovbh/negctl/

cp build/ovbh/out/ff10_prototype.FINAL.map ../ready-to-install/
cp build/ovbh/out/ff50_park.FINAL.map      ../ready-to-install/
python3 -I tools/map/test_parse_map.py; python3 -I tools/map/test_reach_write.py
python3 -I tools/patch/test_patch_map.py
```

All scripts written by this task live in `build/ovbh/` rather than `build/logs/`, deliberately: other
maps were being ported in parallel and `build/logs/shop_survey.py` was overwritten by a sibling build
mid-run. Nothing in `build/ovbh/` is shared.

---

## 9. What is still not done, and what could bite

1. **Nothing here has run in retail MCC.** Blamite loading a cache proves the container and the tag
   graph are well formed, and the compile proves every name resolves. Neither proves the engine
   spawns these squads, that an ally Spartan behaves, that `health_pack` proximity reads the way a
   player expects, or that an appended equipment palette entry rolls. This is the same standing
   limitation as Holdout.
2. **The six kiosks are the six health stations.** Buying and healing happen at the same objects.
   Overlook has no alternative at all; Beachhead has nine invisible ones. If the overlap plays badly,
   Beachhead can move stations onto `dm_resupply_01..09` with no other design change, and Overlook
   cannot.
3. **No air or vehicle tier.** Beachhead could have an allied Ghost (§2.3); Overlook cannot without
   authored in-arena spawn points for `sq_sur_wraith_01/02`.
4. **The equipment palette grew from 2 to 5 entries on both maps.** Three cloned entries against
   Holdout's one. Structurally verified, not play-tested. If an ally spawns with no ability, this is
   the first thing to suspect, and the fix is to cut the pool back to `[1] drop_shield`.
5. **Trooper squads share spawn-zone coordinates** (§3.1). Mitigated by the cooldown and the
   squad-empty test, not eliminated.
6. **Four of six fireteam handles are used per map.** `_05` and `_06` are clean and free on both, and
   there is enough grown-page slack to give them a tier — but `k_fe_actor_limit` is already fully
   subscribed at 12, so a fifth or sixth squad needs the cap raised first.
7. **Troopers are four bodies, not six** (§2.2). Raising it needs two more actors than the stage-2
   cell declares and two more spawn points per squad.
8. **Holdout should take the `player_count` rename** (§6.2). Its published build carries a shim
   script alongside a still-mis-named original, with a body that is not Bungie's.
9. **Team and allegiance are set at runtime**, by `ai_set_team` / `ai_allegiance` in
   `fe_squad_commit`, not by patching squad `team` fields — all eight ally-capable squads are still
   `team = default` in the tag, as research/19 §5 recommended.
