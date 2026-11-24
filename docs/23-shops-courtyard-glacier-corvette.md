# 23 — The purchase system on Courtyard, Glacier and Corvette

**Date:** 2026-11-23
**Reference replicated:** `ff70_holdout.FINAL.map` (research/19 + `src/hsc/ff70_holdout.hsc` + `src/hsc/fe_reinforcements.hsc`)
**Sources:** `~/Desktop/Halo-Firefight/staged-maps/ff20_courtyard.stage2.map`, `ff60_icecave.stage2.map`, `ff45_corvette.stage2.map`

**Verdict, per map, not averaged:**

| map | name | shipped | Blamite | re-parse | byte-diff | blocker |
|---|---|---|---|---|---|---|
| `ff20_courtyard` | Courtyard | **YES** — `ready-to-install/ff20_courtyard.FINAL.map` | LOAD: OK, 12 packs / 100,261 strings | 13,879 tags / 235 groups / 13,879 named / 52,715 sids, **0 warnings** | 0 unexplained runs | none; air support deliberately not sold (section 7) |
| `ff60_icecave` | Glacier | **YES** — `ready-to-install/ff60_icecave.FINAL.map` | LOAD: OK, 12 packs / 100,261 strings | 13,189 / 235 / 13,189 / 65,842, **0 warnings** | 0 unexplained runs | none; no air, no strike, no vehicle, and the exposed win terminal is unreachable (section 8) |
| `ff45_corvette` | Corvette | **NO — not attempted past analysis** | — | — | — | the map places **zero** `firefight_respawn_zone` markers, so there is no attested walkable coordinate to put an ally spawn point on (section 9) |

Nothing in this document has been run in retail MCC. Blamite loading a cache proves the container
and the tag graph are well formed and that the script table it wrote reads back; it does not prove
the game spawns these squads or that an ally Spartan behaves.

---

## 1. What was built, in one picture

Both shipped maps went through the same four stages. Stage 1 and 2 were already done by research/20.

```
maps-stock/<map>.map                       stock, read-only, never opened by this task
  -> staged-maps/<map>.stage2.map          research/20: char->unit repoint + 2 fireteam cells
  -> build/stage3/out/<map>.shop.map       tools/patch/shop_build.py   TAG DATA  (Blamite-gated)
  -> build/stage3/out/<map>.FINAL.map      tools/compile hsc-compile --write   SCRIPTS
  -> ready-to-install/<map>.FINAL.map      byte-identical copy of the above
```

Two intermediate artifacts exist purely as controls and are not shipped:
`build/stage3/out/<map>.rt.map` is the same cache with the map's **own unmodified** script text
recompiled into it (section 6.2), and `build/stage3/out/<map>.*.bak` are the compiler's own backups.

---

## 2. Reuse, measured

Holdout's original design needed 54 script objects and 53 of them did not exist. The Holdout rewrite
collapsed that to 20, all stock. These two ports reference fewer still, and **zero new script
objects**, because the ally delivery no longer needs drop-pod markers:

| | Courtyard | Glacier | Holdout (reference) |
|---|---|---|---|
| `object_name` | 9 | 7 | 7 |
| `ai_squad` | 4 | 4 | 6 |
| `ai_squad_group` | 3 | 2 | 1 |
| `string_id` task args | 2 | 2 | 2 |
| `snd!` tag paths | 3 | 3 | 3 |
| device track name | 1 (`ff10`) | 0 | 1 |
| **total named stock things** | **22** | **18** | **20** |
| **new script objects** | **0** | **0** | **0** |

Courtyard's named objects: `health_pack0`, `health_pack1`, `health_pack2`, `health_pack4`,
`#_door_interior_large_logo_03`, `#_door_interior_large_logo_04`, `ammo_crate0`, `ammo_crate1`,
`dm_longsword_01`; squads `sur_fireteam_01..04`; groups `gr_survival_fireteams`,
`gr_survival_waves`, `gr_survival_all`.

Glacier's: `health_pack0`, `health_pack1`, `health_pack2`, `health_pack4`, `health_pack5`,
`ammo_crate0`, `ammo_crate1`; squads `sur_fireteam_01..04`; groups `gr_survival_fireteams`,
`gr_survival_all`.

---

## 3. Every name was proved against the map, and the negative control proves the proof

This toolchain does not merely *warn* about a script object the scenario lacks — it **fails the
compile**. The negative control is `build/stage3/negctl.hsc`, three deliberately fake names compiled
against Courtyard's own cache:

```
[compile] FAILED at negctl.hsc:4:14 near ""sq_fe_does_not_exist_xyz""
[compile] Failed to process the expression "sq_fe_does_not_exist_xyz". A "ai" expression was expected.
RESULT: 1 of 1 file(s) did not compile.
```

A second, weaker control found a real mistake rather than confirming a guess: the first Glacier probe
named `"central_base_door"`, read off a 30-character-truncated report column. It failed to compile.
The real object name is `central_base_door_m60_unsc_doo` — Bungie's own name is truncated in the tag.
That name is **not** used in the shipped file, but the episode is the evidence that compiling is a
real check and not a rubber stamp.

Positive controls `build/stage3/probe_ct.hsc` and `probe_gl.hsc` name every object, squad, group and
device the shipped files use, including both quoted `#_`-prefixed door machines, and both compile
clean against their own cache. The shipped files then compile clean as part of the full unit
(section 6).

---

## 4. The tag edits, per map

`tools/patch/shop_build.py <map-key> <in> <out>` does all of them in one writer pass, allocates one
0x10000 page with `reach_write.grow_tag_area(mode="end")`, and publishes only if
`hsc-compile --load-only` accepts the result. The manifest of what it wrote is saved beside the
output as `<out>.shopbuild.json`.

### 4.1 The ally group becomes a root group — needed on BOTH maps, for two different reasons

One 2-byte same-size write, `squad_groups_block + 0x20` (`short_block_index`):

| map | group | before | after | file offset | why |
|---|---|---|---|---|---|
| Courtyard | `[6] gr_survival_fireteams` | `5` (`gr_survival_waves`) | `-1` | `0x5864988` | chain reaches `gr_survival_all`, which stock `survival_wave_living_count` counts |
| Glacier | `[9] gr_survival_fireteams` | `1` (`gr_survival_extras`) | `-1` | `0x52DB930` | **per-wave cleanup**, see below |

`-1` is attested in both maps: each ships 5 root groups (`gr_survival_all`, `gr_survival_extras`,
`gr_survival_bonus`, `gr_survival_remaining`, `gr_survival_phantoms`).

Courtyard's offset `0x5864988` is exactly the selector research/20 section 1 recorded, re-derived
here from the published stage-2 cache by an independent reader.

**Research/20 was wrong about Glacier, and this is the correction.** Research/20 concluded Glacier
needs no reparent because its `gr_survival_fireteams` hangs off `gr_survival_extras`, which is a root,
so the chain never reaches `gr_survival_all`. That is true, and it is about the wave *count* only.
Glacier's stock `survival_wave_end_conditions` runs

```
(ai_survival_cleanup "gr_survival_extras" true true)
```

at the end of **every wave** (`extracted/ff60_icecave/scripts/ff60_icecave.hsc:622`, and again
non-destructively at `:681`), and `ai_survival_cleanup` on a group reaches its children. Left as
shipped, every ally the player bought is deleted at the next wave boundary and the shop is worthless.
So Glacier needs the identical 2-byte write, for a completely unrelated reason. Verified by reading
the decompile, not inferred from the other maps.

### 4.2 The trooper tier: spawn points, and a weapon fix that could not be done in place

`sur_fireteam_01` and `sur_fireteam_02` arrive from stage 2 with one 4-actor cell each, already
pointed at the repointed Spartan-bodied character palette slot `[24]`, and with **0 spawn points** —
which means `ai_place` on them spawns nothing. The build gives each 4 spawn points and corrects the
cell.

**A real trap, found and avoided.** Stage 2 cloned its cells from a stock squad and left the clone's
`initial weapon` and `initial secondary weapon` **block pointers** aimed at the template's own choice
blobs, so those blobs are shared with live stock squads:

| map | shared blob | also used by |
|---|---|---|
| Courtyard | `0x5865AE4` | `sq_sur_drop_01`'s `initial weapon` **and `sq_sur_drop_02`'s *character* choice** |
| Courtyard | `0x5865AF4` | `sq_sur_drop_01`'s and `sq_sur_drop_04`'s `initial secondary weapon` |
| Glacier | `0x52DC944` | `sq_sur_wraith_01`'s and `sq_sur_wraith_02`'s `initial weapon` |

Writing a human rifle index into those offsets would have re-armed Bungie's Covenant drop squads and
both Wraith crews, and in Courtyard's case would have overwritten a *character* index with a *weapon*
index. The first build of this task did exactly that; it was caught because the second trooper squad
reported its "before" weapon as the value the first squad's write had just placed. The fix is to emit
fresh 16-byte choices in the grown page and repoint the cell's block field — the same primitive the
Spartan tier uses. The builder now refuses to touch a shared blob at all.

| map | squad | `major upgrade` | primary weapon | secondary weapon | spawn points |
|---|---|---|---|---|---|
| Courtyard | `sur_fireteam_01`, `_02` | 3 → 3 (`none`) | `[8]` concussion_rifle → `[7]` dmr | `[12]` plasma_rifle → `[4]` magnum | 4 each |
| Glacier | `sur_fireteam_01`, `_02` | 0 → 3 (`none`) | `[12]` plasma_rifle → `[7]` dmr | none in the cell; left empty | 4 each |

Every palette index is validated at build time against that map's own weapon palette by tag path, and
the build refuses if an index does not resolve to the expected tag. Courtyard's palette has 23
entries, Glacier's 21.

### 4.3 The Spartan tier: a fresh cell plus spawn points

`sur_fireteam_03` and `sur_fireteam_04` are completely free on both maps (0 designer cells, 0
templated cells, 0 spawn points) and both already carry `obj_fireteams` as their initial objective.
Each receives one cell: 2 actors, `major upgrade` 4 (`all`), `vehicle type` -1, one character choice
at palette slot `[24]`, a weighted weapon pool, a weighted ability pool, and 2 spawn points.

Randomisation is free: `weapon_palette_choice_block` and `equipment_palette_choice_block` hold up to
8 entries with a `chance` weight at `+0x0E` and the engine rolls per actor per spawn. No
`random_range`, no script branch.

| | Courtyard (open courtyard) | Glacier (cave interior) |
|---|---|---|
| weapon pool | `[14]` sniper_rifle, `[18]` rocket_launcher, `[19]` spartan_laser, `[9]` grenade_launcher, `[21]` plasma_turret | `[13]` shotgun, `[18]` rocket_launcher, `[19]` spartan_laser, `[9]` grenade_launcher |
| ability pool | `[1]` drop_shield, `[2]` sprint, `[3]` jet_pack, `[4]` active_camouflage | `[2]` drop_shield, `[3]` sprint, `[4]` active_camouflage |

Glacier's pool is deliberately close-quarters and deliberately has no jet pack: the map is
underground with no air support, and its 21-entry weapon palette has no detached plasma turret, so
Courtyard's fifth slot does not exist there. The human machinegun turret is **not** available as a
carried weapon on either map — `objects\vehicles\human\turrets\machinegun\machinegun` is vehicle
palette `[1]`, a `vehi`, so a biped cannot hold it and a cell's `initial weapon` cannot name it.

### 4.4 The equipment palette had to grow

A cell's `initial equipment` is a `short_block_index` into the **scenario** equipment palette, so an
`eqip` tag merely existing in the tag table is not enough. Both maps ship a tiny palette, so the block
was copied into the grown page with extra entries cloned from the existing `drop_shield` entry and
their datum swapped. Appending never shifts an existing index, so the placed `ammo_box` equipment
objects are untouched.

| map | palette | appended |
|---|---|---|
| Courtyard | 2 → 5 (`ammo_box`, `drop_shield`) | `sprint`, `jet_pack`, `active_camouflage` |
| Glacier | 3 → 5 (`ammo_box`, `frag_grenade`, `drop_shield`) | `sprint`, `active_camouflage` |

All four `eqip` tags were confirmed present in both maps' tag tables before use. The ability pool is
resolved **by tag path, not by index**, so a palette shipped in a different order cannot silently
shift the pool.

### 4.5 Every spawn-point coordinate is a coordinate the map already uses

No coordinate was invented. Each spawn point is placed at the position of a placed
`objects\multi\firefight\firefight_respawn_zone` scenery object — the markers the engine itself
spawns players on, so the ground is known walkable and known inside the arena. Courtyard places 10 of
them, Glacier 8.

| map | squad | marker positions |
|---|---|---|
| Courtyard | `sur_fireteam_01`, `_02` | `spartan_respawn_01` (-104.63, 35.48, 18.28), `spartan_respawn_05` (-92.13, 35.47, 18.18), `spartan_respawn_03` (-92.60, 57.43, 18.40), `elite_respawn_04` (-92.53, 58.62, 15.76) |
| Courtyard | `sur_fireteam_03` | `spartan_respawn_01`, `spartan_respawn_05` |
| Courtyard | `sur_fireteam_04` | `spartan_respawn_03`, `elite_respawn_04` |
| Glacier | `sur_fireteam_01`, `_02` | `spartan_respawn_01` (-101.50, 259.23, -102.69), `spartan_respawn_02` (-105.57, 274.80, -103.44), `spartan_respawn_03` (-94.22, 267.54, -102.69), `spartan_respawn_04` (-72.15, 260.84, -104.49) |
| Glacier | `sur_fireteam_03` | `spartan_respawn_01`, `spartan_respawn_03` |
| Glacier | `sur_fireteam_04` | `spartan_respawn_02`, `spartan_respawn_03` |

All four Courtyard markers are in the rear base cluster beside the shop, and all are inside trigger
volume `safe_zone_soft_01` (bounds x[-106.9,-54.0] y[-6.1,68.7] z[12.7,23.7]). On Glacier,
`spartan_respawn_01/_02/_03` are inside `tv_wraith` and `spartan_respawn_04` is not — it is the fourth
trooper point because `tv_wraith` contains only three markers; it is still a placed respawn zone, so
still walkable in-arena floor.

Reusing one marker position across two squads is deliberate and is attested in stock: Glacier's
`sq_sur_wraith_01` ships its `driver` and `gunner` spawn points at the identical position
(-164.99, 294.71, -115.37), and Corvette's four Phantom squads share two `gunner` positions.

Each spawn point is written with `character type`, `initial weapon`, `initial secondary weapon`,
`initial equipment` and `vehicle type` all `-1`, so the actor takes its character and its randomised
loadout from the cell and arrives **on foot** whatever the byte template was.

### 4.6 `sur_fireteam_05` and `sur_fireteam_06`

`sur_fireteam_05` is left free on both maps.

`sur_fireteam_06` is never written and never named in any shipped script, on either map. The builder
prints its state as a standing check:

```
Courtyard  sur_fireteam_06 is squad 26, parent 6, flags 0x100   (a normal sibling, still unused)
Glacier    sur_fireteam_06 is squad 23, parent 5, flags 0x40    (a live Brute wave squad)
```

Glacier's is the trap research/20 found and this task re-confirmed: it is parented to
`gr_survival_waves`, not to the fireteam group; its flags are `0x40` rather than its siblings'
`0x100`; it has 2 spawn formations; and its one designer cell is at `0x52DBAB4`, which is the **same
blob** `sq_sur_wave_01` points at — eight character choices resolving to `brute`, `brute_captain`,
`brute_chieftain_armor`, `brute_chieftain_weapon`. Glacier therefore has **five** usable fireteam
handles, not six. This build uses four of them.

### 4.7 The deliberate departure from the Holdout reference, and why

Holdout used `sq_sur_drop_01..04` as the ally bodies because they were the only squads with a cell
*and* spawn points. These ports use the fireteam squads with authored spawn points instead. The
delivery primitive is not new — it is exactly what `tools/patch/holdout_fe_spartans.py` already did
and proved for Holdout's own Spartan tier. What changes is which squads carry the cheap tier, and it
buys three things:

1. **It avoids a collision the Holdout build shipped with.** Stock `survival_drop_spawn` runs
   `(ai_erase "sq_sur_drop_01")` … `("sq_sur_drop_04")` on every cycle before it re-spawns them
   (Holdout decompile L5486-5489; Courtyard decompile L5125-5128). Those erases are **not** gated on
   `g_sur_drop_spawn` or `g_sur_drop_limit`, so the two global writes in
   `ff70_holdout_stock_hooks.hsc` do not stop them. On Holdout that can silently delete allies the
   player paid for. Neither port can hit it.
2. **The stock Covenant drop pods keep working.** Courtyard's pod event is left entirely alone and
   still delivers enemies as Bungie intended.
3. **The diff against Bungie's script text is empty.** There is no `*_stock_hooks.hsc` for either
   map. The whole change is additive.

The cost: troopers walk in instead of riding a pod. On Glacier that was never a choice — the map has
no `sq_sur_drop_*` squads, no `dm_drop_*` machines and no `dm_longsword_01` at all. On Courtyard it is
a real loss of spectacle, chosen for the reason above.

---

## 5. The shop boards

Prices, the cap, the charging mechanism, the proximity input and the gating are the author's numbers
unchanged from the Holdout build: troopers 500 for 4, Spartans **1,000 for 2**, ammo 500, bank 500 a
press, Longsword 3,000, win 10,000 gated on `(>= (survival_mode_set_get) 1)`, `k_fe_actor_limit = 12`
with a Spartan sub-cap of 4, and a NEGATIVE `campaign_metagame_award_points` charged to the actual
buyer via a `cond` over the eight `human_player_in_game_get` slots.

On these two maps 12 is also exactly what the tag data can reach: two trooper squads of 4 plus two
Spartan squads of 2 is 12 bodies and not one more, so the cap and the cells agree instead of one
silently binding the other.

### 5.1 Courtyard — six stations

| station | anchor | position | price | gate |
|---|---|---|---|---|
| TROOPERS, 4 bodies | `health_pack0` | (-100.34, 33.09, 18.27) | 500 | always |
| SPARTANS, 2 bodies | `health_pack1` | (-99.92, 37.90, 18.27) | 1,000 | set ≥ 1 |
| BANK | `health_pack4` | (-96.70, 34.32, 18.27) | 500 | always |
| AMMO RESUPPLY | `#_door_interior_large_logo_03` | (-98.75, 35.50, 17.70) | 500 | always |
| LONGSWORD PASS | `#_door_interior_large_logo_04` | (-91.86, 35.50, 16.50) | 3,000 | set ≥ 1 |
| **MAC STRIKE / WIN** | `health_pack2` | (-74.60, 33.50, 18.27) | 10,000 | set ≥ 1 |

The win terminal is **deliberately exposed**: `health_pack2` is in the forward cluster at x -74.6,
about 25 world units from the rear base cluster at x -97..-100 where everything else is sold. That
reproduces the author's own design — he exiles Unearthed's MAC Cannon terminal to the Crane so the
climax is a run through the barrage (research/10 section 3.2) — using an object Courtyard already
places.

`health_pack5` is left as a pure heal station, because the four rear kiosks already crowd a
4-world-unit square.

**`health_pack3` is rejected on evidence.** Its position (-74.60, 37.50, 18.27) falls inside the
runtime sector bounds of trigger volume `kill_soft_03` (x[-75.4,-68.5] y[36.5,52.6] z[16.3,30.7]).
That test is an axis-aligned over-approximation of a 22-point volume, so it may be a false positive —
but a soft kill volume starts a "return to the battlefield" countdown, and a dwell-based purchase
inside one is a shop that kills the buyer. Not worth the coin flip when a spare station exists.

The two `#_`-prefixed door machines are usable because a leading `#` survives the HaloScript lexer
when quoted. That was proved on Holdout and re-proved here against Courtyard's own cache.

### 5.2 Glacier — five stations, all inside `tv_wraith`

| station | anchor | position | price | gate |
|---|---|---|---|---|
| TROOPERS, 4 bodies | `health_pack0` | (-94.68, 272.45, -102.87) | 500 | always |
| SPARTANS, 2 bodies | `health_pack1` | (-104.93, 273.77, -103.27) | 1,000 | set ≥ 1 |
| AMMO RESUPPLY | `health_pack2` | (-92.64, 266.81, -102.85) | 500 | always |
| BANK | `health_pack4` | (-98.86, 261.46, -102.63) | 500 | always |
| **DEMOLITION CHARGES / WIN** | `health_pack5` | (-97.76, 258.22, -102.63) | 10,000 | set ≥ 1 |

`health_pack3` (-102.73, 260.33, -102.64) is left as a pure heal station.

**All six of Glacier's health stations fall inside `tv_wraith`**, whose runtime sector bounds read
x[-128.6,-83.5] y[241.0,275.6] z[-104.4,-100.3] out of the tag. `tv_wraith` is the map's own scripted
shelter and Bungie labelled it: `obj_swrait_0_1` and `obj_swrait_0_2`, the entry conditions on the
`wraith01_lock` / `wraith02_lock` tasks, both return
`(not (volume_test_players "tv_wraith"))` (`ff60_icecave.hsc:5490` and `:5494`), so the Wraiths stop
shelling while a player is inside it. The design wished for the shop to sit there (research/05 section
5.5) and it turns out to be free — the stations Bungie already placed are already in there.

The win price is the author's MAC rung, 10,000, rather than the design-era 8,000, so all three ported
maps share one win price and the ladder stays his.

---

## 6. Compilation and the script write

Unit order, four files, one compile unit:

```
build/stage3/unit/fe_culled_shims.hsc     restores the culled `player_count` script
build/stage3/unit/<map>.stock.hsc         the map's own full decompile, `\\` collapsed to `\`
src/hsc/fe_shop_ctgl.hsc                  the map-neutral purchase library
src/hsc/<map>.hsc                         the kiosks and the startup script
```

**The culled-script shim is needed on all three maps, including Corvette.** Each map's shipped
bytecode calls `player_count`, which is neither a function in `ReachMCC_U13_Scripting.xml` nor one of
the scenario's declared scripts; its name survives only as a string id. Courtyard calls it at
`:352`, Glacier at `:345`, Corvette at `:601` and `:2004`. Without a declaration Blamite cannot
rebuild the table at all, so the map's *own* script would not recompile. The shim is Holdout's,
unchanged: `(script static short player_count (list_count (players_human)))`.

The decompiler emits `\\` inside quoted tag paths, which Blamite reads literally. 102 pairs were
collapsed on Courtyard, 38 on Glacier.

### 6.1 Results

| | Courtyard | Glacier |
|---|---|---|
| stock decompile | 357 scripts / 194 globals | 335 / 187 |
| with shim | 358 | 336 |
| **full unit compiled** | **398 scripts / 222 globals / 16,216 expressions** | **374 / 215 / 14,861** |
| tag references | 18 | 16 |
| script string bytes | 24,706 | 23,216 |
| syntax errors | 0 | 0 |
| lint findings | 181, **all** `print` (`null="true"`) plus one stock `ai_squad_enumerate_immigrants` | 144, same two kinds |
| unresolved script objects | 2 | 2 |

The two unresolved objects are `ai_current_actor` and `ai_current_squad`, Bungie's implicit iterator
names, first used in each map's own stock text. The proven Holdout build reported exactly the same
two. Every `print` in the shipped files is behind `(if g_fe_debug ...)`.

### 6.2 The stock round-trip control

The question research/19 section 6 called "the gate for every script write" — *does the map's own
decompiled script recompile?* — was answered before anything of ours was added:

| map | stock-only compile |
|---|---|
| Courtyard | OK, 14,949 expressions / 358 scripts / 194 globals, 0 syntax errors |
| Glacier | OK, 13,656 expressions / 336 scripts / 187 globals, 0 syntax errors |

Both were then also **written** into a copy of the cache (`<map>.rt.map`) so the byte-diff of a
content-free write could be measured. That control is what makes the real write's diff interpretable;
see section 7.2.

The recompiled expression count is lower than the decompiler's reported count (Courtyard 18,821 →
14,949; Glacier 17,415 → 13,656). Holdout showed the same characteristic (20,164 → 17,383) and was
shipped on that basis. It is a property of the round trip, not of our content, and it is identical in
the stock-only control.

### 6.3 The bytecode reads back

The decisive end-to-end check: the written map was decompiled again from its own bytecode.

| map | decompiled from the FINAL map | `fe_` scripts recovered | unresolved markers |
|---|---|---|---|
| Courtyard | 222 globals, **398 scripts**, 16,216 expressions | **40 / 40** | 0 (the only `<!` is the header comment) |
| Glacier | 215 globals, **374 scripts**, 14,861 expressions | **38 / 38** | 0 |

Parameter lists, types, object names and named constants all survive; `fe_kiosk_win` and
`fe_courtyard_startup` round-trip character for character. Full output in
`build/stage3/<map>.FINAL.decomp.hsc`.

---

## 7. Verification, per output, by an independent reader

Every number below comes from a fresh parse of the published file, not from the writer's own report.

### 7.1 The tag stage (`build/logs/shop_verify.py`)

| check | Courtyard | Glacier |
|---|---|---|
| re-parse, source | 13,879 tags / 235 groups / 13,879 named / 52,675 sids, **0 warnings** | 13,189 / 235 / 13,189 / 65,804, **0 warnings** |
| re-parse, output | identical counts, **0 warnings** | identical counts, **0 warnings** |
| checksum stored == computed | `0x49C55822` ✓ | `0x8E92D407` ✓ |
| size | 183,279,616 → 183,345,152 (+0x10000) | 164,966,400 → 165,031,936 (+0x10000) |
| inserted page content | 696 non-zero bytes, rest zero | 672 non-zero bytes, rest zero |
| differing runs outside the page | 31, **0 unexplained** | 31, **0 unexplained** |
| character palette → unit map | unchanged, 28 slots | unchanged, 26 slots |
| placed objects | unchanged, 134 named | unchanged, 105 named |
| ai objectives | unchanged | unchanged |
| squads changed | only `sur_fireteam_01..04` | only `sur_fireteam_01..04` |

Six of the 31 runs are the 0xA000 header (`file_size`, `virtual_size`, partition 5 size, checksum,
the localization **offset mask** at 0x4D8 — the research/19 fix — and the tag section size). The
other 25 each fall wholly inside a field the build intended to write: the group `parent`, four squads'
`spawn points` and `designer` block fields, four cells' weapon block fields, and the equipment
palette block field. A stray byte adjacent to any of those would still be reported.

### 7.2 The script stage (`build/logs/shop_scriptdiff2.py`)

A script write legitimately rebuilds the whole script table, so a run-level diff is unreadable and a
positional diff is meaningless once a page is inserted. The tool therefore (a) locates the single
inserted page by sliding-window alignment and diffs the two halves **in alignment**, and (b) requires
every differing run to fall inside the cache header, the debug section, the `matg` body, or the convex
hull of the scenario's own script tables in either layout.

| | Courtyard | Glacier |
|---|---|---|
| size | 183,345,152 → 183,345,152 (**unchanged**) | 165,031,936 → 165,036,032 (+0x1000) |
| inserted page | none | 0x1000 at src offset `0x26BE70`, inside the debug section; everything after is byte-identical, shifted |
| byte-identical tail | 83 MB | 71 MB |
| differing runs | 75,036 | 68,528 |
| **unexplained** | **0** | **0** |
| re-parse | 0 warnings, checksum `0x591A9B37` self-consistent | 0 warnings, checksum `0xE665BFE8` self-consistent |

Where the change lands, in both maps: `hs syntax datums` (the expression table, 24 bytes per entry —
**not** 20; 18,821 × 24 exactly tiles Courtyard's old table), `script string data`, `scripts`,
`globals`, `references`, the script-table hull, the debug section's tag-name and string-id tables, 13
bytes in the scenario tag body (the script-table count and pointer fields), and the cache header.

Two findings worth recording:

* **The `matg` language-pack table is rewritten, and that is correct.** 24 runs on each map sit inside
  `matg` (`globals\globals`) at relative offsets `+0x21/+0x25`, `+0x71/+0x75`, … stride 0x50 — twelve
  0x50-byte records each holding an unchanged string **count** and a string-data **offset** that
  dropped by exactly 49,792 bytes. Those are the 12 language packs. The localization data moved, so
  Blamite's writer fixed the 12 offsets up. `hsc-compile --load-only` then re-resolves all 12 packs
  and all 100,261 locale strings on the output, which is what proves the fix-up is right rather than
  merely present.
* **The churn is `SaveScripts`', not ours.** The stock round-trip control (writing Bungie's own
  unmodified text back) produces the same region set with run counts within a few percent — Courtyard
  77,263 runs vs our 75,036, Glacier 70,647 vs 68,528 — and also reports **0 unexplained**. Every
  region the real write touches is a region a content-free write touches too.

### 7.3 The script write changed no tag data

The full scenario survey was taken before and after the script write and compared with absolute
offsets stripped (Glacier's scnr body moves by 0x1000):

```
ff20_courtyard   offset-independent tag data identical: True
ff60_icecave     offset-independent tag data identical: True
```

object names, placed objects, squad groups, squads, cells, objectives, trigger volumes, all palettes
and the whole character-palette → unit mapping: unchanged.

### 7.4 The Blamite gate, on the delivered files

Run against `ready-to-install/*.FINAL.map`, not against a build copy:

```
ff20_courtyard   locales: 12 language pack(s), 100261 string(s)   LOAD: OK
ff60_icecave     locales: 12 language pack(s), 100261 string(s)   LOAD: OK
```

Both match their own `.stage2.map` source exactly (12 packs, 100,261 strings).

| file | sha256 | size |
|---|---|---|
| `ready-to-install/ff20_courtyard.FINAL.map` | `f54755dbdacfc07b1e2830429ee384a125b6de2cb0d2c90e24bcff19c6b5ebbb` | 183,345,152 |
| `ready-to-install/ff60_icecave.FINAL.map` | `019847d37b9ff06ca8aa3da4aa4ac85c02bffb3ecaaff1d0a73ba496da558cb2` | 165,036,032 |

### 7.5 Source integrity

| file | state |
|---|---|
| `staged-maps/ff20_courtyard.stage2.map` | sha256 `0ab7d4cf7998de06…` before and after, **identical** |
| `staged-maps/ff60_icecave.stage2.map` | sha256 `157f9b96c7c3a423…` before and after, **identical** |
| `staged-maps/ff45_corvette.stage2.map` | opened read-only for the survey only; not written |
| `maps-stock/*.map` | **never opened by this task** |

The `maps-stock/` files are mode `0644`, not `0444` as the task described. They were not opened and
their sizes are unchanged; tightening them to `0444` remains a reasonable follow-up, as research/20
section 6 already noted for the staged copies.

---

## 8. What these two maps do NOT sell, and why not

Stated as missing features rather than shipped broken.

**Courtyard: no air support.** `sq_sur_banshee_01` and `_02` are the only Courtyard squads with a
vehicle cell (vehicle palette `[6]`, banshee) and Holdout sold exactly these as an allied Banshee.
Courtyard's stock script owns them: `survival_banshee_spawn` (decompile L5061-5078) runs
`(begin_random_count 1 (ai_place "sq_sur_banshee_01") (ai_place "sq_sur_banshee_02"))` every 2-3
minutes, gated on `(<= (ai_task_count "obj_survival/extras_gate") 0)`, and `banshee_emp_kill` keeps
acting on them afterwards. A purchased ally would be re-placed as an enemy by that event, or would
block it. Disabling the event means editing Bungie's text, which this port does not do.

**Courtyard: the Longsword pass ships with a known risk.** `dm_longsword_01` is `machines[16]` with
placement flag bit0 set, and stock Courtyard creates it the same way for its weapon-resupply event
(decompile L5371-5398, including the same `device_set_position_track "dm_longsword_01" "ff10"`). If a
purchase lands inside that event's own ~10-second animation window the two fight over one device and
the result is a visual glitch. Holdout shipped the identical arrangement; this is parity, not a
discovery.

**Glacier: no air support, no orbital pass, no drop pods, no vehicle.** The cache agrees with the
script. Glacier has **zero** references to `dm_longsword` in 5,564 lines of its own decompile, no
`sq_sur_drop_*` squads, no `dm_drop_*` machines, no `dm_resupply_*`/`sc_resupply_*`, no `dm_target_*`.
Its only drivable-chassis squad is `sq_sur_ghost_01`, and stock owns it too: L4946 runs
`(f_load_phantom_cargo v_sur_phantom_01 "single" "sq_sur_ghost_01" none)` — a Phantom delivers that
Ghost as an **enemy** — and L4944 polls its health. Both Wraith squads are driven by stock command
scripts. Glacier's five-station board is a property of the map, not an omission.

Also on Glacier, `sc_weapon_01`, `sc_weapon_02` and `sc_weapon_03` — the three static weapon holders
the task suggested as anchors — are **not** usable: all three carry placement flags `0x00000001`, so
they do not exist until the stock `weapon_drop_control` script creates them. The same is true of
`sc_hack_sniper`. This is the same finding the Holdout rewrite made about `sc_hack_*`,
`sc_resupply_*` and `generator_switch*`, and it holds here: on both ported maps the only
always-present named interactive objects are the health stations and, on Courtyard, the three
`#_door_interior_large_logo_*` machines.

**Glacier: the exposed win terminal is not reachable with zero new objects.** The design wanted the
charges rigged out on the Wraith's ground at one of the `ps_wraith` bombardment points
(research/05 section 5.5, research/10 section 3.2). Glacier's only always-present named interactive
objects are six health stations and two doors (`central_base_door_m60_unsc_doo`, `rear_base_door`),
and **all eight are inside `tv_wraith`**. `ps_wraith/p0..p3` are point-set points, not objects, and
`objects_distance_to_object` cannot take one. So Glacier's win is bought in shelter, and the run
through the barrage is the one piece of the Glacier design this port does not deliver. Courtyard's
forward cluster does deliver it (section 5.1).

---

## 9. Corvette — not attempted past analysis, and what it would take

Corvette was explicitly optional. The analysis below is read out of `ff45_corvette.stage2.map` and is
complete enough to resume from without redoing it.

### 9.1 What the bytes say

* **No `gr_survival_fireteams`, and no spare group.** Corvette has 5 squad groups:
  `gr_survival_all` (root), `gr_survival_extras` (root), `gr_wave_spawns` (parent 0),
  `gr_wave_spawns_bonus` (parent 0), `gr_survival_remaining` (root).
* **All six `ff_elite_fireteam0..5` are member squads of `gr_wave_spawns`**, squad indices 10-14 and
  33, flags `0x100`, initial objective 1.
* The stage-2 cells landed on `ff_elite_fireteam0` and `ff_elite_fireteam1`; `2`, `3`, `4` and `5`
  are free (0 designer cells, 0 templated cells, 0 spawn points).
* **The per-squad parent write is attested.** Corvette ships 8 parentless squads — `ff_phantom0..3`,
  `ff_phantom_bonus`, `test_fork`, `test_load`, `test_load2` — so `-1` in `squads_block + 0x26` is a
  shipped state in this very map.
* **Good news the earlier analysis did not have:** Corvette's `ff_fireteam_objective` (objective 1)
  has one task, `follow`, whose **`Squad group filter` is -1**, i.e. unfiltered. Making the fireteam
  squads parentless therefore does **not** break the follow task. That was the thing most likely to
  go wrong and it does not.
* Corvette does place all six `health_pack0..5` with placement flags `0x00000000`, at
  (±6.97, -64.90/-68.11, ≈0.60) and (±2.05, -69.37, ≈0.59), plus `ammo_crate0/1` at
  (±0.34, -69.62, ≈0.00) with flags `0x00000101`. The kiosk layer is not the problem.

### 9.2 The blocker

**Corvette places zero `firefight_respawn_zone` objects.** The tag is in its scenery palette, but no
scenery object references it. Every ally spawn-point coordinate on Courtyard and Glacier came from
such a marker, which is what made those coordinates attested walkable floor rather than invented.

Corvette's only attested on-foot ground coordinates are:

| source | positions | note |
|---|---|---|
| `ff_startup_grunts` spawn points | (9.15, -52.93, 2.20), (10.54, -52.97, 2.20) | seat 0, vehicle -1, i.e. genuinely on foot |
| `ff_engineers` spawn points | (0.27, -45.48, 13.71), (-1.22, -47.03, 13.71), (0.50, -47.66, 13.71) | engineers fly; z 13.71 is probably mid-air, so **not** proven walkable |

Two usable coordinates, for the twelve spawn points a 4+4+2+2 ally field needs, on a different deck
(y ≈ -53, z 2.2) from the shop (y ≈ -65..-69, z 0.6), with no way to check that an ally can path from
one to the other without running the game. That is the "an ally that will not place" condition, and
it is where this stops.

### 9.3 What would be required to revisit it

1. A source of attested walkable coordinates inside Corvette's arena. Three candidates, in order of
   cost: read the Firefight respawn points out of the scenario's **player starting locations** or
   `scenario_spawn_data` block (never inspected); accept `ff_startup_grunts`' two positions with
   heavy reuse and a reduced board of one trooper squad and one Spartan squad (6 bodies, cap 6); or
   open the map in Sapien on Windows and place the markers, which leaves the zero-new-objects rule.
2. A per-squad reparent instead of a per-group one: `squads_block + 0x26` → `-1` for each ally squad.
   Two writes for a two-squad tier, four for a 4-squad field. Attested, and `ff_fireteam_objective`
   survives it (section 9.1).
3. A rewrite of four library scripts that currently read the ally group by name: `fe_allies_alive`,
   `fe_retire_allies`, and the per-map `*_ally_refresh`'s `ai_reset_objective` / `ai_set_task` calls
   would each have to be summed or issued per squad, because with the squads parentless there is no
   group to count or task. All four are mechanical; none is novel.
4. The task names differ: Corvette's objective is `ff_fireteam_objective` with task `follow`, not
   `obj_fireteams` / `fireteams`. Two string literals.
5. The same equipment-palette growth and the same shared-choice-blob trap (section 4.2) apply.
   Corvette's stage-2 cell template was `ff_startup_grunts`, so its cells' weapon block pointers will
   be shared with that live stock squad.

There is also a reason not to hurry: Corvette is the one Firefight map the original author already
covered with his own Corvette variant, so the user has something to play there regardless.

---

## 10. Files

| path | what |
|---|---|
| `ready-to-install/ff20_courtyard.FINAL.map` | **shipped.** Rename to `ff20_courtyard.map` on the PC. |
| `ready-to-install/ff60_icecave.FINAL.map` | **shipped.** Rename to `ff60_icecave.map` on the PC. |
| `src/hsc/fe_shop_ctgl.hsc` | the map-neutral purchase library for these two maps |
| `src/hsc/ff20_courtyard.hsc` | Courtyard's six kiosks and startup |
| `src/hsc/ff60_icecave.hsc` | Glacier's five kiosks and startup |
| `src/hsc/attic/ff60_icecave.design-era.hsc` | the previous Glacier file, written against the 54-object design. Its map analysis is still correct and is cited above; its object list is not, and it cannot compile against this cache. |
| `tools/patch/shop_build.py` | the map-parameterised tag builder, Blamite-gated |
| `build/logs/shop_survey.py` | map-agnostic scenario survey (replaces `placecheck.py` + `squads_holdout.py` + `palette_use2.py`) |
| `build/logs/shop_digest.py`, `shop_q.py` | human-readable views over a survey |
| `build/logs/shop_verify.py` | independent verification of a tag-stage output |
| `build/logs/shop_scriptdiff2.py` | shift-aware, block-attributed diff of a script write |
| `build/logs/shop_regiondiff.py` | coarse region diff, used while diagnosing the above |
| `build/stage3/unit/*.stock.hsc` | each map's own decompile with `\\` collapsed |
| `build/stage3/unit/fe_culled_shims.hsc` | the `player_count` shim (Holdout's, unchanged) |
| `build/stage3/negctl.hsc`, `probe_ct.hsc`, `probe_gl.hsc` | the negative and positive controls |
| `build/stage3/*.survey.json` | the survey each decision was read from, for all four maps |
| `build/stage3/*.tagverify.txt`, `*.scriptdiff.txt`, `*.compile_*.txt`, `*.roundtrip.txt` | every log behind the numbers above |
| `build/stage3/*.FINAL.decomp.hsc` | the written bytecode, decompiled back |
| `build/stage3/out/` | build intermediates: `.shop.map`, `.rt.map`, `.FINAL.map`, `.bak`, manifests |

### Reproducible sequence

```bash
P="$HOME/Desktop/Halo-Firefight/project"; cd "$P"
S="$HOME/Desktop/Halo-Firefight/staged-maps"
export DOTNET_ROLL_FORWARD=LatestMajor DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
export BLAMITE_FORMATS="$P/tools/compile/bin/Release/net8.0/Formats"
HSC="dotnet $P/tools/compile/bin/Release/net8.0/hsc-compile.dll"
XML="$P/tools/hsc/tables/reachmcc_u13.xml"

for m in ff20_courtyard ff60_icecave ff45_corvette; do
  python3 build/logs/shop_survey.py $S/$m.stage2.map --json build/stage3/$m.survey.json
  python3 build/logs/shop_digest.py build/stage3/$m.survey.json           # all sections
done

# the unit inputs: collapse the decompiler's escaped backslashes
for m in ff20_courtyard ff60_icecave; do
  python3 - "$m" <<'PY'
import sys; m=sys.argv[1]
s=open('extracted/%s/scripts/%s.hsc'%(m,m)).read().replace('\\\\','\\')
open('build/stage3/unit/%s.stock.hsc'%m,'w').write(s)
PY
done
cp build/holdout/unit/fe_culled_shims.hsc build/stage3/unit/

# controls
$HSC --unit --hsc build/stage3/negctl.hsc  --xml $XML --map $S/ff20_courtyard.stage2.map  # MUST FAIL
$HSC --unit --hsc build/stage3/probe_ct.hsc --xml $XML --map $S/ff20_courtyard.stage2.map  # MUST PASS
$HSC --unit --hsc build/stage3/probe_gl.hsc --xml $XML --map $S/ff60_icecave.stage2.map    # MUST PASS

# tag stage, then verify it independently
for m in ff20_courtyard ff60_icecave; do
  python3 tools/patch/shop_build.py $m $S/$m.stage2.map build/stage3/out/$m.shop.map
  python3 build/logs/shop_verify.py $S/$m.stage2.map build/stage3/out/$m.shop.map
done

# stock round-trip control, then the real write
for m in ff20_courtyard ff60_icecave; do
  cp build/stage3/out/$m.shop.map build/stage3/out/$m.rt.map
  $HSC --unit --hsc build/stage3/unit/fe_culled_shims.hsc \
              --hsc build/stage3/unit/$m.stock.hsc \
              --xml $XML --map build/stage3/out/$m.rt.map --write
  cp build/stage3/out/$m.shop.map build/stage3/out/$m.FINAL.map
  $HSC --unit --hsc build/stage3/unit/fe_culled_shims.hsc \
              --hsc build/stage3/unit/$m.stock.hsc \
              --hsc src/hsc/fe_shop_ctgl.hsc \
              --hsc src/hsc/$m.hsc \
              --xml $XML --map build/stage3/out/$m.FINAL.map --write
  python3 build/logs/shop_scriptdiff2.py build/stage3/out/$m.shop.map build/stage3/out/$m.rt.map
  python3 build/logs/shop_scriptdiff2.py build/stage3/out/$m.shop.map build/stage3/out/$m.FINAL.map
  $HSC --load-only --map build/stage3/out/$m.FINAL.map
done
```

---

## 11. What is still not done

1. **Neither map has been play-tested.** Nothing here has run in retail MCC.
2. **`ai_place` on a squad with authored spawn points is structurally sound and behaviourally
   unproven.** It is the same primitive Holdout's Spartan tier used, so these two maps are no more
   speculative than the shipped Holdout build — but neither is proven.
3. **Team and allegiance are set at runtime, not in the tag.** All four ally squads still read
   `team = default`; `fe_squad_commit` issues `ai_set_team squad human` and both `ai_allegiance`
   directions. research/19 section 5 recommends exactly this, and both maps already declare the
   allegiance in their own stock initialisation.
4. **The on-screen price text is still frozen.** The prompts are `matg` strings protected by a
   SHA-1, so a terminal may show a stock number even though the real cost is the one in section 5.
   Unchanged from the Holdout build.
5. **`sur_fireteam_05` is unused on both maps.** An ODST or heavy tier could use it, at the cost of
   one more cell, two more spawn points and a higher `k_fe_actor_limit`.
6. **Courtyard's `health_pack3` rejection rests on an axis-aligned bounding-box test** against
   `kill_soft_03`'s 22-point volume. A point-in-polygon test would settle whether the station is
   actually usable; the conservative choice was made instead.
7. **Corvette is unshipped**, for the reason in section 9.2.
