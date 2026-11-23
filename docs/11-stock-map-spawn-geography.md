# Stock Firefight Map Spawn and AI Geography

Mined from Bungie's own shipped HaloScript for Halo: Reach Firefight. This document replaces lore-and-layout guesswork with what the engine actually references.

---

## 0. Provenance and honesty legend

### 0.1 What is on disk

All files live in `research/_raw/hsc/`.

| File | Lines | Map | Source |
|---|---|---|---|
| `global_firefight.hsc` | 3413 | shared | MCC Oct 24 2019 source |
| `ff20_courtyard.hsc` + `_fragments` | 1267 + 21 | Courtyard | same |
| `ff50_park_main.hsc` + `_fragments` | 1579 + 45 | **Beachhead** | same |
| `ff10_prototype.hsc` + `_fragments` | 1414 + 21 | **Overlook** | same |
| `ff60_airview.hsc` + `_fragments` | 1365 + 21 | **Outpost** | same |
| `ff70_holdout.hsc` + `_fragments` | 1667 + 30 | **Holdout** | same |
| `ff60_icecave.hsc` + `_fragments` | 1111 + 45 | **Glacier** | same |
| `ff30_waterfront.hsc` + `_fragments` | 1354 + 33 | **Waterfront** | same |
| `ff45_corvette_main.hsc` + `_fragments` | 583 + 15 | Corvette | same |
| `ff_unearthed_mission.hsc` + `_fragments` | 1666 + 48 | Unearthed | same |
| `cex_ff_halo_main.hsc` + `_fragments` | 1355 + 54 | Installation 04 | same |
| `ksiedge_variant/Firefight Tag List.xml` | — | authoring checklist | KSIEdge/HaloReachScripts |
| `ksiedge_variant/AI Objectives.hsc` | — | `obj_survival` task tree notes | same |
| `nervy_variant/global_firefight.hsc` | 3443 | shared, later revision | NervyDestroyer/Halo-MCC-Scripts |
| `omaha_release_11860/` | ~4500–5600 each | all 10 maps | Assembly decompiles, globals inlined |

**We now have per-map shipped scripts for all six target maps.** Nothing in the six dossiers below is invented from map layout guides. Where a fact is not in a script, it is labelled.

### 0.2 Confirmed map-name to scenario-tag mapping

| Display name | Scenario tag | Script filename |
|---|---|---|
| Beachhead | `ff50_park` | `ff50_park_main.hsc` |
| Overlook | `ff10_prototype` | `ff10_prototype.hsc` |
| Outpost | `ff60_airview` | `ff60_airview.hsc` |
| Holdout | `ff70_holdout` | `ff70_holdout.hsc` |
| Glacier | `ff60_icecave` | `ff60_icecave.hsc` |
| Waterfront | `ff30_waterfront` | `ff30_waterfront.hsc` |
| Courtyard | `ff20_courtyard` | `ff20_courtyard.hsc` |
| Corvette | `ff45_corvette` | `ff45_corvette_main.hsc` |
| Unearthed | `ff_unearthed` | `ff_unearthed_mission.hsc` |
| Installation 04 | `cex_ff_halo` | `cex_ff_halo_main.hsc` |

Confirmed twice: Halopedia's `HREK\tags\levels\firefight\...` paths, and `XboxChaos/Assembly`'s `MapNames.xaml.cs` (`MapEntry("ff50_park", "Beachhead", "7060", Survival)`). Note that earlier internal guesses of `ff10_prototype` for Beachhead and `ff_installation04` for Installation 04 were both wrong.

### 0.3 Verification labels used below

* **[SCRIPT]** — a shipped script for that specific map names this object. The name is correct; the map definitely has it.
* **[CONV]** — the name appears in every other Firefight map's script, or is a `global_firefight.hsc` default, so the object is almost certainly present under that name even where the map's own script never mentions it. Not directly proven for that map.
* **[TAG]** — the name is proven, but all geometry (position, facing, areas, bounds, character types) lives in the `.scenario` tag, which is **not public in any of the three repositories searched**. We know the object exists and what it is called. We do not know where it is.
* **[INFER]** — reasoning from script structure, not a direct reference. Treat as a hypothesis to test in Sapien.
* **[GAP]** — our design assumes infrastructure for which no script evidence exists.

### 0.4 The hard limit on this research

**No scenario tag dumps exist publicly.** Not in `Gamecheat13/RawGames`, not in `NervyDestroyer/Halo-MCC-Scripts`, not in `KSIEdge/HaloReachScripts`. Those repos hold `.hsc`, `.bin` and `.jpg` only. Therefore:

> This document gives you the **correct names and the correct wiring**. It cannot give you a single coordinate. Every position below is described relative to a named object whose actual location must be read out of the scenario tag in Sapien (HREK) or with Assembly/Reclaimer against the MCC map file.

That is the honest boundary. A script that references the right names will compile and hook into real map data; a script that invents names will silently do nothing.

---

## 1. The shared engine contract (`global_firefight.hsc`)

### 1.1 Globals a per-map script is expected to fill

Declared at the top of `global_firefight.hsc` with defaults, then overwritten by each map's `startup` script:

| Global | Line | Default | Meaning |
|---|---|---|---|
| `ai_sur_wave_spawns` | 17 | `none` | **Squad group that supplies wave spawn geometry.** Every map sets this to `gr_survival_waves`. |
| `ai_sur_remaining` | 20 | `none` | Squad that stragglers are migrated into. Every map sets `sq_sur_remaining`. |
| `ai_sur_fireteam_squad0`–`5` | 23–28 | `none` | "The squads into which fireteam members are absorbed." See §4. |
| `ai_obj_survival` | 31 | `none` | The Covenant AI objective. Every map sets `obj_survival` (Corvette uses `ff_objective`). |
| `s_sur_wave_squad_count` | 34 | `4` | How many squads from the group a wave fills. **All six target maps set 6.** |
| `ai_sur_bonus_wave` | 37 | `none` | Set to `sq_ff_bonus` on every map. |
| `obj_sur_generator0`–`2` | 40–42 | `generator0`–`2` | Generator device machines. |
| `obj_sur_generator_switch0`–`2` | 43–45 | `generator_switch0`–`2` | |
| `obj_sur_generator_switch_cool0`–`2` | 46–48 | `generator_switch_cool0`–`2` | |
| `obj_sur_generator_switch_dis0`–`2` | 49–51 | `generator_switch_disabled0`–`2` | |
| `obj_ammo_crate0`, `obj_ammo_crate1` | 54–55 | `ammo_crate0`, `ammo_crate1` | **Already default-wired.** See §1.6. |
| `k_sur_wave_per_round_limit` | 75 | `5` | 5 waves per round. |
| `k_sur_round_per_set_limit` | 76 | `3` | 3 rounds per set. |
| `k_sur_wave_timer` | 79 | `180` | Inter-wave delay in ticks. Per-map: Courtyard 150, Overlook 150, Waterfront 150, Glacier 90, Holdout 240, Beachhead 0, Outpost 0. |
| `s_sur_dropship_crew_count` | 94 | `2` | Crew subtracted from Phantom living counts. |
| `v_sur_phantom_01`–`04`, `v_sur_bonus_phantom` | 97–101 | `NONE` | Vehicle handles, filled at runtime. |
| `ai_sur_phantom_01`–`04`, `ai_sur_bonus_phantom` | 104–108 | `NONE` | Set to `sq_sur_phantom_01`–`04` and `sq_sur_bonus_phantom` on every map. |
| `s_sur_drop_side_01`–`04` | 111–114 | `"dual"` | Which Phantom bay doors unload. Per-map values differ; see dossiers. |

### 1.2 How a wave is assigned a spawn location — the single most important mechanic

`survival_wave_spawn` (L564–661) does this:

```
(if (wave_dropship_enabled)
    (ai_place_wave_in_limbo (survival_mode_get_wave_squad) ai_sur_wave_spawns s_sur_wave_squad_count)
    (ai_place_wave          (survival_mode_get_wave_squad) ai_sur_wave_spawns s_sur_wave_squad_count)
)
```

`hsdoc_hr.txt` L1298–1310 documents the opcode as:

> `(<void> ai_place_wave <long> <ai> <short>)` — Places the given number of squads from the specified wave name into squads defined as part of the given squad group

So:

1. **The wave template** (chosen by the game variant via `survival_mode_get_wave_squad`) supplies *what spawns* — the character types, ranks and weapons.
2. **The squad group `gr_survival_waves`** supplies *where it spawns* — the engine picks `s_sur_wave_squad_count` (6) member squads of that group and fills each with the wave template's contents.
3. **The script never names a location.** There is no `spawn_point` argument anywhere in the wave path.

Consequences for us:

* Every spawn position in stock Firefight comes from squad membership in `gr_survival_waves` in the scenario tag. The number of spawn locations a map has is the number of squads in that group — conventionally `sq_sur_wave_01` … `sq_sur_wave_08` per the authoring checklist [CONV].
* With 8 squads in the group and 6 drawn per wave, each wave uses a random-ish 6 of 8 locations. That is the whole of Reach's wave spawn variety.
* **To add a spawn location, you add a squad to `gr_survival_waves` in the tag. No script change is needed.** To add a *friendly* spawn location you must add a squad that is *not* in that group.
* `ai_place_wave_in_limbo` is used when dropships are on: squads are created inert and then handed to a Phantom. The squad's own spawn point is then irrelevant — the Phantom's flight path determines arrival. With dropships off, the squad's tag spawn point is used directly.

### 1.3 Wave end — `survival_wave_living_count` (L665–674)

```
(script static short survival_wave_living_count
    (+
        (ai_living_count gr_survival_all)
        (ai_living_count gr_survival_remaining)
        (max 0 (- (ai_living_count ai_sur_phantom_01) s_sur_dropship_crew_count))
        (max 0 (- (ai_living_count ai_sur_phantom_02) s_sur_dropship_crew_count))
        (max 0 (- (ai_living_count ai_sur_phantom_03) s_sur_dropship_crew_count))
        (max 0 (- (ai_living_count ai_sur_phantom_04) s_sur_dropship_crew_count))
    )
)
```

**This is the rule that governs whether friendly squads break the game.** `survival_wave_end_conditions` (L676–761) blocks on this count reaching 0 (final wave), `k_sur_ai_final_limit` (wave 4), or `k_sur_ai_rand_limit` (all other waves).

Per the authoring checklist, the group hierarchy is:

```
gr_survival_all
├── gr_survival_waves      (contains sq_sur_wave_01..08)
└── gr_survival_bonus      (contains sq_ff_bonus)
gr_survival_remaining      (contains sq_sur_remaining)
gr_survival_phantoms       (contains sq_sur_phantom_01..04, sq_sur_bonus_phantom)
gr_survival_extras
├── gr_survival_cov_drop_pod  (sq_sur_drop_01..05)
├── gr_survival_snipers       → gr_survival_sniper_01, _02
├── gr_survival_ghosts        → gr_survival_ghost_01, _02
├── gr_survival_banshees      → gr_survival_banshee_01, _02
├── gr_survival_wraiths       → gr_survival_wraith_01, _02
└── gr_survival_marines       → gr_survival_marines_followers, _defenders
```

**Rules a friendly squad must obey:**

1. **Never a member of `gr_survival_all`, `gr_survival_waves`, `gr_survival_bonus` or `gr_survival_remaining`.** Any of these makes the squad count toward `survival_wave_living_count`, so the wave never ends while your marines are alive. This is the single fatal mistake.
2. **`gr_survival_extras` is safer but still not free.** It is *not* in `survival_wave_living_count`, so it does not stall waves. But:
   * `survival_wave_end_conditions` calls `(ai_survival_cleanup gr_survival_extras TRUE TRUE)` at the start and `(... FALSE FALSE)` at the end of every wave. Per `hsdoc_hr.txt` L5153 that activates "cure isolation death" and deletes inactive actors. Friendly squads in `gr_survival_extras` will be culled when separated from the fight.
   * On **Courtyard, Overlook and Waterfront**, `survival_drop_spawn` blocks on `(<= (ai_living_count gr_survival_extras) 0)` before spawning Covenant drop pods, both before (L501/529/556 depending on map) and after the spawn burst. **Living friendly marines inside `gr_survival_extras` would permanently suppress Covenant drop pods on those three maps.**
   * On **Outpost, Holdout and Waterfront**, `survival_sniper_spawn` blocks on `(< (ai_living_count gr_survival_snipers) g_sur_sniper_limit)` — so only `gr_survival_snipers` membership matters there, not the parent.
3. **The correct answer is a brand-new top-level squad group** — e.g. `gr_unsc_reinforcements` — that is a child of nothing. This is what our `src/hsc` scripts already assume, and it is right. It must be created in the scenario tag.

Note that Bungie's own authoring checklist puts `gr_survival_marines` under `gr_survival_extras`. That works on Installation 04 because `cex_ff_halo` places its marines once at startup and never gates anything on the extras count in a way that conflicts. Do not copy that parenting onto the three drop-pod maps.

### 1.4 Allegiance (L238–241)

```
(script dormant survival_mode
    (wake survival_human_player_has_spawned)
    (ai_allegiance human player)
    (ai_allegiance player human)
    (ai_allegiance covenant covenant_player)
    (ai_allegiance covenant_player covenant)
    ...
```

Both directions of `human`↔`player` are already set by the global script, and **every one of the six maps repeats the human/player pair in its own `startup` block** before `survival_mode` is even woken (Beachhead L116–117, Overlook L31–32, Outpost L25–26, Holdout L114–115, Glacier L12–13, Waterfront L30–31, Courtyard L29–30). Two maps also have the `covenant`/`prophet` pair present but commented out (Courtyard L31–32).

**Implication:** a squad on team `human` is already friendly to the player on every stock Firefight map, with no script work. `(ai_set_team squad human)` is sufficient, and `hsdoc_hr.txt` L1460 confirms the opcode. Our `fe_squad_arrive` doing exactly this is correct.

### 1.5 Score (L1077–1086)

```
(script static long survival_total_score
    (+ (campaign_metagame_get_player_score (player_human 0))
       ... through (player_human 5) ))
```

Six human slots only; elites contribute nothing. `survival_score_attack` (L1089–1103) compares this against `survival_mode_score_silver` / `_gold` / `_onyx` and submits incidents. There is **no "spend score" opcode** — `campaign_metagame_get_player_score` is a getter. A purchase economy must therefore track spend in its own globals and compare against `survival_total_score`, which is exactly what `fe_score_available` / `fe_charge` in `src/hsc/fe_reinforcements.hsc` already do. Confirmed correct approach.

`survival_mode_bonus_living_count` (L1066–1072) is a separate counter for the bonus round, summing `ai_sur_wave_spawns` + `ai_sur_bonus_wave` + `ai_sur_bonus_phantom`. Friendly squads must stay out of those three as well.

### 1.6 The ammo crates — the best existing anchor for a purchase terminal

```
(global object_name obj_ammo_crate0 ammo_crate0)   ; L54
(global object_name obj_ammo_crate1 ammo_crate1)   ; L55

(script dormant survival_ammo_crate_create          ; L3177
    (if (survival_mode_ammo_crates_enable)
        (begin (object_create_anew obj_ammo_crate0)
               (object_create_anew obj_ammo_crate1))))

(script dormant survival_ammo_crate_waypoint        ; L3187
    ... (chud_track_object_with_priority obj_ammo_crate0 13) ...)
```

Key facts:

* The globals **default** to the object names `ammo_crate0` and `ammo_crate1`, so no map needs to set them. Only Corvette sets them explicitly (`ff45_corvette_main.hsc` L57–58), redundantly. **Every Firefight map is expected to carry scenery named `ammo_crate0` and `ammo_crate1`** [CONV]. The authoring checklist lists them under folder `eq_ammo_crates` with tag `ammo_box`.
* They are already HUD-trackable with `chud_track_object_with_priority ... 13`.
* Bungie placed them where players actually hold ground, because their entire purpose is to be reachable mid-wave.

**Therefore: `ammo_crate0` is the single best-evidenced "player stronghold" marker on every one of the six maps, and the natural anchor for a fixed purchase terminal.** You do not need to invent a position — you need to read the position of `ammo_crate0` out of the tag, and put the terminal and the friendly-squad arrival point beside it.

### 1.7 Dropship arrival

`survival_dropship_spawner` (globals) calls `f_survival_dropship_spawner` on `ai_sur_phantom_01`–`04` in a `begin_random` (or paired `begin_random` when `b_sur_phantoms_semi_random` is true). `survival_dropship_loader` fills them. Then `(set b_phantom_move_out TRUE)` releases them.

The flight path is **entirely in the per-map command script**, which follows a fixed shape (Courtyard `cs_sur_phantom_01`, L188–224):

```
(set v_sur_phantom_01 (ai_vehicle_get_from_starting_location sq_sur_phantom_01/phantom))
(object_cannot_die v_sur_phantom_01 TRUE)
(cs_enable_pathfinding_failsafe TRUE)
(cs_ignore_obstacles TRUE)
(cs_fly_by ps_sur_phantom_01/p0)
(cs_vehicle_boost TRUE)
(cs_fly_by ps_sur_phantom_01/p1)
(cs_fly_by ps_sur_phantom_01/p2)
(cs_vehicle_boost FALSE)
(cs_fly_to_and_face ps_sur_phantom_01/p3 ps_sur_phantom_01/face 1)
(sleep 15)
(wake phantom_01_blip)
(f_unload_phantom v_sur_phantom_01 "dual")
(sleep 15)
; reverse back out through p2, p1, p0
(cs_fly_by ps_sur_phantom_01/erase 10)
(ai_erase ai_current_squad)
```

So a dropship arrival point is a **point set** `ps_sur_phantom_NN` with named points `p0`, `p1`, `p2`, `p3`, `face`, `erase`. `p3` is the hover/unload position; `face` is the look-at target; `erase` is where the squad is deleted. Phantom squads are `gr_survival_phantoms` and are made invulnerable, so they are set dressing. The `f_unload_phantom` helper lives in `global_phantom.hsc` L124 and takes a side string of `"dual"`, `"left"` or `"right"`.

**All six target maps have exactly four `ps_sur_phantom_01`–`04` plus `ps_sur_bonus_phantom`** [SCRIPT]. That is four fixed air arrival corridors per map, already authored with full flight paths. A friendly Pelican would need a **new** point set; `ps_sur_pelican` exists only on Installation 04.

### 1.8 Drop pods — verified at `ff20_courtyard.hsc` L461–545, and expanded

The previous agent's note about L511–545 is correct and this is the full picture.

Controller (`survival_drop_spawn`, L466–508):

```
(cond ((<= (game_coop_player_count) 4) (set g_sur_drop_limit 1))
      ((>= (game_coop_player_count) 5) (set g_sur_drop_limit 2)))
(sleep (* 30 60 2))                        ; 2 minutes before the first pod
(sleep_until (begin
    (sleep (* 30 180 1))                   ; 3 minutes between attempts
    (sleep_until (and (<= (ai_living_count gr_survival_waves) 10)
                      (<= (ai_living_count gr_survival_extras) 0)
                      (= (survival_mode_current_wave_is_boss) FALSE)
                      (= (survival_mode_current_wave_is_initial) FALSE)))
    (ai_erase sq_sur_drop_01) ... (ai_erase sq_sur_drop_04)
    (begin_random_count g_sur_drop_limit
        (if g_sur_drop_spawn (wake drop_pod_01)) ... (wake drop_pod_04))
    (sleep_until (<= (ai_living_count gr_survival_extras) 0))
    (set g_sur_drop_count 0) (set g_sur_drop_spawn TRUE)
  FALSE))
```

The pod itself (`drop_pod_01`, L511–538) — this is the exact sequence to copy for an ODST pod:

```
(script continuous drop_pod_01
    (sleep_forever)                                  ; parked until woken
    (sleep (random_range 5 15))
    (object_create dm_drop_01)                       ; device machine = the pod shell
    (ai_place sq_sur_drop_01)                        ; squad spawns at its tag spawn point
    (sleep 1)
    (set v_sur_drop_01 (ai_vehicle_get_from_spawn_point sq_sur_drop_01/driver))
    (sleep 1)
    (objects_attach dm_drop_01 "" v_sur_drop_01 "")  ; shell riveted to the squad's vehicle
    (sleep 1)
    (device_set_position dm_drop_01 1)               ; animate the pod rail 0 -> 1
    (sleep_until (>= (device_get_position dm_drop_01) 0.85) 1)
    (wake drop_blip_01)
    (unit_open v_sur_drop_01)
    (sleep 30)
    (vehicle_unload v_sur_drop_01 "")                ; kick the AI out
    (sleep_until (>= (device_get_position dm_drop_01) 0.98) 1)
    (effect_new_on_object_marker fx\fx_library\pod_impacts\default\pod_impact_default_large.effect dm_drop_01 "fx_impact")
    (sleep_until (>= (device_get_position dm_drop_01) 1) 1)
    (objects_detach dm_drop_01 v_sur_drop_01)
    (object_destroy dm_drop_01)
    (set g_sur_drop_count (+ g_sur_drop_count 1))
    (if (>= g_sur_drop_count g_sur_drop_limit) (set g_sur_drop_spawn FALSE)))
```

**Critically: the landing position is not in the script.** It is the spawn point of `sq_sur_drop_NN/driver`. `dm_drop_NN` is an *invisible rail* (checklist tag `invis_cov_squad_drop_pod`, folder `dm_droprails`) whose animation carries the shell down to meet the squad's own spawn point. So:

> **A drop pod lands wherever the squad's tag spawn point is. To add a pod landing site you add a `dm_drop_NN` device machine and a matching squad spawn point in the tag. You cannot relocate a pod from script.**

Drop pod inventory per map is therefore a hard constraint, and it varies a lot — see §5.

A test harness is provided at the bottom of every pod-equipped map (Courtyard L1253–1260): `(script static void test_squad_drop ... (ai_erase sq_sur_drop_01) (sleep 30) (wake drop_pod_01))`. Use that shape for in-engine iteration.

### 1.9 Weapon / resupply drops — the other reusable delivery

`survival_resupply_pod_spawn` (Courtyard L669–734) waits on `(survival_mode_should_drop_weapon)`, destroys the previous `sc_resupply_01`–`09` and `sc_target_01`–`03`, then:

```
(object_create dm_longsword_01)
(object_create_folder_anew cr_grenades)
(device_set_position_track dm_longsword_01 "ff10" 0)
(device_animate_position dm_longsword_01 1 10.0 3 3 FALSE)
(sleep_until (>= (device_get_position dm_longsword_01) 0.4) 1)
(begin_random_count 1 (wake resupply_target_01) (wake resupply_target_02) (wake resupply_target_03))
(begin_random_count g_sur_resupply_limit (wake resupply_pod_01) ... (wake resupply_pod_09))
(sleep 120)
(object_destroy dm_longsword_01)
```

Each `resupply_pod_NN` (L889–912) mirrors the drop-pod shape with scenery instead of a squad:

```
(object_create dm_resupply_01)
(begin_random_count 1 (object_create_variant sc_resupply_01 "laser")
                      (object_create_variant sc_resupply_01 "rocket")
                      (object_create_variant sc_resupply_01 "sniper"))
(objects_attach dm_resupply_01 "" sc_resupply_01 "")
(device_set_position dm_resupply_01 1)
... small pod_impact effect ...
(objects_detach ...) (object_destroy dm_resupply_01)
(object_damage_damage_section sc_resupply_01 "panel" 100)   ; pops the capsule open
(wake resupply_waypoint_01)
```

and the waypoint thread blips it until the weapon is taken:

```
(f_blip_object sc_resupply_01 blip_ordnance)
(sleep_until (not (resupply_pod_test_weapon sc_resupply_01)) 5)
(f_unblip_object sc_resupply_01)
```

with `resupply_pod_test_weapon` (L659–665) checking markers `"gun_high"`, `"gun_mid"`, `"gun_lower"`.

`sc_target_NN` is the Target Locator variant, gated by `(airstrike_weapons_exist)` and `(airstrike_set_launches 2)`.

**This is the mechanism to clone for any purchased-item delivery that is an object rather than a squad.** Nine `sc_resupply_*` positions per map (except Glacier) is nine pre-authored, player-reachable, Bungie-vetted delivery points.

### 1.10 Kill volumes and the spawn rooms

```
(script dormant sur_kill_vol_disable                 ; woken from startup
    (kill_volume_disable kill_sur_room_01) ... kill_sur_room_08)
(script static void survival_kill_volumes_on  ...)   ; stub-overridden from globals L763
(script static void survival_kill_volumes_off ...)
```

All six maps define `kill_sur_room_01`–`08` [SCRIPT]. `survival_wave_end_conditions` calls `survival_kill_volumes_on` once fewer than 7 enemies remain, to flush stragglers still loitering in the spawn rooms, then `_off` at the end of the wave.

**This is a per-map map of where enemies spawn.** Eight kill volumes, one per spawn room, on every map. They are the engine's own statement of "this is a Covenant arrival area" — i.e. precisely the eight places a friendly squad must *not* go. Reading their bounds out of the tag gives you the enemy approach lanes for free.

### 1.11 Garbage collection

`survival_garbage_collector` is woken each wave; globals reference `tv_sur_garbage_all` and `tv_sur_garbage_weapon` (the `add_recycling_volume tv_sur_garbage_all 30 10` call is commented out at L572). Two recycling trigger volumes per map [CONV]. Friendly squads should not be parked inside them.

### 1.12 The `obj_survival` AI objective task tree

Reconstructed from `ksiedge_variant/AI Objectives.hsc` plus the `_fragments` files. Each task carries a **squad group filter**, which is the mechanism that routes a given squad to a given task:

| Task | Squad group filter | Behaviour |
|---|---|---|
| `hold_task` | `gr_survival_all` | run (alert). The default assignment for dropship-unloaded squads (`survival_set_hold_task`, globals L1403/L1467). |
| `remaining` | `gr_survival_remaining` | **follow: player front, radius 10, Z clamp 1** |
| `main_wave_gate` | `gr_survival_waves` | gate, inhibit vehicles |
| `hero_follow_gate` → `hero_follow` | (leader filter) | follow: player front, radius 10; exhaustion script `survival_hero_refresh_follow` |
| `follow_gate` → `main_follow` | — | follow: player front, radius 10; exhaustion script `survival_refresh_follow` |
| `generator_gate` → `gen0`/`gen1`/`gen2` | — | conditioned on `b_sur_generatorN_alive`; player front radius 5 |
| `gen0_boost`/`gen1_boost`/`gen2_boost` | — | only when `game_coop_player_count >= 3` |
| `bonus_gate` → `bonus_follow` | `gr_survival_bonus` | follow: player front |
| `extras_gate` | `gr_survival_extras` | gate |
| `extras_backup` | `gr_survival_snipers` | walk (idle) |
| `wraith_gate` → `wraith_01`/`wraith_02` | `gr_survival_wraiths` / `_wraith_01` | command script `cs_abort` / `cs_wraith_shoot` |
| `ghost_gate` → `ghosts` | `gr_survival_ghosts` | aggressive |
| `sniper_01`/`sniper_02` | `gr_survival_sniper_01`/`_02` | defensive |

Caveat: this file is KSIEdge's authoring notes, taken from one reference scenario. The task *names* are independently confirmed by the per-map `_fragments` files; the group filters and movement flags are [CONV] for the six targets.

**Two conclusions that change our design:**

1. **`obj_survival/hold_task` cannot be used for friendly squads.** Its squad group filter is `gr_survival_all` — the exact group a friendly squad must stay out of. A friendly squad given this task matches no task and will idle. `src/hsc/fe_reinforcements.hsc` `fe_squad_hold` currently calls `(ai_set_task squad objective task)` with `obj_survival`; that must change. More generally, **every task in `obj_survival` is filtered to a `gr_survival_*` group**, so a friendly squad in `gr_unsc_reinforcements` will match nothing in that objective at all.
2. **Task-based following is the real follow mechanism, and it is alive.** `follow: player front / follow radius 10 / follow Z clamp 1` is a *task property in the scenario tag*, not a fireteam call. It is what makes the Covenant chase players in every wave of every stock map. So friendly squads can be made to follow players — but it requires a **new AI objective with a follow task**, authored in the tag, not a script function.

---

## 2. Full structure of a per-map Firefight script, using `ff20_courtyard.hsc` as the template

1267 lines, 34 script declarations, 20 globals. The structure is near-identical on all ten maps.

### 2.1 File order

| Lines | Section |
|---|---|
| 1–3 | Banner comment: `; ====== M20 COURTYARD FIREFIGHT SCIRPTS ===` (Bungie's typo, present on every map) |
| 4–21 | Map globals: `s_round`, `g_timer_var`, `b_sur_resupply_waypoint_01`–`09`, `v_sur_drop_01`–`04` |
| 24–155 | **`(script startup ff20_courtyard ...)`** — the whole configuration surface |
| 157–180 | Secondary scripts: `survival_refresh_follow`, `survival_generator`, `survival_hero_refresh_follow`, `survival_set_hold_task` |
| 182–414 | Phantom command scripts `cs_sur_phantom_01`–`04`, `cs_sur_bonus_phantom`, each with a `phantom_NN_blip` continuous |
| 417–457 | Banshee hazard: `survival_banshee_spawn`, `banshee_emp_kill` |
| 459–652 | Covenant drop pods: 4 globals, `survival_drop_spawn`, `drop_pod_01`–`04`, `drop_blip_01`–`04` |
| 654–1210 | Weapon drops: `g_sur_resupply_limit`, `resupply_pod_test_weapon`, `survival_resupply_pod_spawn`, `resupply_target_01`–`03` + waypoints, `resupply_pod_01`–`09` + waypoints |
| 1212–1247 | Kill volumes: `sur_kill_vol_disable`, `survival_kill_volumes_on`, `survival_kill_volumes_off` |
| 1250–1267 | Test scripts: `test_squad_drop`, plus trailing commented notes |

### 2.2 The `startup` script in full, annotated

```
(script startup ff20_courtyard
    ;(game_force_survival_immediate)                       ; debug, left commented
    (ai_allegiance human player)                           ; L29  — friendlies work out of the box
    (ai_allegiance player human)                           ; L30
;   (ai_allegiance covenant prophet)                       ; L31  commented
;   (ai_allegiance prophet covenant)                       ; L32  commented
    (if (> (player_count) 0) (cinematic_snap_to_black))    ; L36
    (sleep 5)
    (switch_zone_set set_firefight)                        ; L40  — the only zone set name used, all maps
    (wake sur_kill_vol_disable)                            ; L42
    ; FIRETEAM SETUP
    (set ai_sur_fireteam_squad0 sur_fireteam_01)           ; L46-51 — see §4
    ... through sur_fireteam_06
    (set ai_sur_bonus_wave sq_ff_bonus)                    ; L54
    (set ai_sur_bonus_phantom sq_sur_bonus_phantom)        ; L57
    (set ai_obj_survival obj_survival)                     ; L64
    ;(object_create_folder cr_sandbox_items)               ; L68  commented — cover crates
    (set ai_sur_phantom_01 sq_sur_phantom_01)              ; L76-79
    ... through _04
    (set s_sur_drop_side_01 "dual")                        ; L82-85
    ... through _04
    ;(set b_sur_dropship_r1_initial TRUE) ... etc          ; L86-94 all commented
    (set ai_sur_wave_spawns gr_survival_waves)             ; L97  — THE spawn group
    (set s_sur_wave_squad_count 6)                         ; L100
    ;(set s_sur_generator_count 0)                         ; L103 commented
    ;(set b_sur_generator_defend_all true)                 ; L106 commented
    ;(set b_sur_generator_order_random false)              ; L109 commented
    (set obj_sur_generator0 generator0)                    ; L112-123 all 12 generator objects
    ...
    (set ai_sur_remaining sq_sur_remaining)                ; L127
    (set k_sur_wave_timer 150)                             ; L130
    (set ai_sur_bonus_phantom sq_sur_bonus_phantom)        ; L137 (duplicate of L57)
    (wake survival_mode)                                   ; L143 — hand off to globals
    (if (survival_mode_scenario_extras_enable)             ; L144
        (begin
            ;(wake survival_banshee_spawn)                 ; L146 commented on Courtyard
            (sleep 1)
            (wake survival_drop_spawn)))                   ; L148
    (wake survival_resupply_pod_spawn)                     ; L151
    ;(wake survival_kill_player)                           ; L152 commented
    (sleep 5))
```

Note the hazard gate: **all optional hazards are behind `(survival_mode_scenario_extras_enable)`**, which `hsdoc_hr.txt` L3576 documents as "Get the survival mode scenario hazards enabled property from the game variant". That is the hook a purchase system should reuse — it is the one game-variant switch that already controls scripted extras.

### 2.3 Complete object inventory referenced by `ff20_courtyard.hsc`

**Squads:** `sq_sur_phantom_01`–`04`, `sq_sur_bonus_phantom`, `sq_sur_banshee_01`, `sq_sur_banshee_02`, `sq_sur_drop_01`–`04`, `sq_sur_remaining`, `sq_ff_bonus`, `sur_fireteam_01`–`06`

**Squad groups:** `gr_survival_waves`, `gr_survival_extras`

**Point sets:** `ps_sur_phantom_01`–`04` (points `p0`–`p3`, `face`, `erase`), `ps_sur_bonus_phantom`

**Device machines:** `dm_drop_01`–`04`, `dm_resupply_01`–`09`, `dm_target_01`–`03`, `dm_longsword_01`, `generator0`–`2`

**Device controls:** `generator_switch0`–`2`, `generator_switch_cool0`–`2`, `generator_switch_disabled0`–`2`

**Scenery:** `sc_resupply_01`–`09`, `sc_target_01`–`03`

**Crate folders:** `cr_grenades`, `cr_sandbox_items` (referenced, creation commented out)

**Kill volumes:** `kill_sur_room_01`–`08`

**Trigger volumes:** none in the main script; none in `_fragments` either. Courtyard is the only one of the seven with no trigger volumes at all.

**Objective:** `obj_survival`, tasks `hold_task`, `main_follow`, `hero_follow`, `remaining`, `generator`, `extras_gate`

**Zone set:** `set_firefight`

**Squad starting locations / spawn points used by name:** `sq_sur_phantom_NN/phantom`, `sq_sur_banshee_NN/driver`, `sq_sur_drop_NN/driver`

---

## 3. Naming and reference conventions a new script must follow

### 3.1 Prefix table

| Prefix | Tag type | Sapien folder | Examples |
|---|---|---|---|
| `sq_` | AI squad | per-encounter | `sq_sur_phantom_01`, `sq_sur_drop_03`, `sq_sur_wave_05`, `sq_ff_bonus`, `sq_marines_01` |
| `gr_` | AI squad group | — | `gr_survival_all`, `gr_survival_waves`, `gr_survival_extras` |
| `ps_` | script-data point set | Script data → Point sets | `ps_sur_phantom_01`, `ps_gen`, `ps_wraith`, `ps_banshee_01`, `ps_sur_pelican` |
| `tv_` | trigger volume | Trigger Volumes | `tv_wraith_01`, `tv_cliff_fall_left`, `tv_sur_garbage_all`, `tv_null` |
| `kill_` | kill volume | — | `kill_sur_room_01`–`08` |
| `dm_` | device machine | `dm_droppods`, `dm_droprails`, `dm_generators`, `dm_longsword` | `dm_drop_01`, `dm_resupply_01`, `dm_target_01`, `dm_longsword_01` |
| `dc_` | device control | `dc_survival`, `dc_generator_switches` | `generator_switch0`, `health_pack0` |
| `sc_` | scenery | `sc_resupply_pods`, `sc_survival`, `sc_respawn_zone`, `sc_camera_objects`, `sc_pathfinding_helpers` | `sc_resupply_01`, `sc_target_01`, `sc_weapon_01`, `sc_poa`, `spartan_01` |
| `cr_` | crate | `cr_grenades`, `cr_survival`, `cr_easteregg` | `cr_grenades`, `cr_sandbox_items` |
| `eq_` | equipment | `eq_survival`, `eq_ammo_crates` | `ammo_crate0`, `ammo_crate1` |
| `obj_` | AI objective | Objectives | `obj_survival`, `obj_marines`, `obj_fireteams` |
| `v_`, `ai_`, `b_`, `s_`, `k_`, `g_` | script globals (vehicle / ai / boolean / short / constant / general) | — | `v_sur_phantom_01`, `ai_sur_wave_spawns`, `b_sur_bonus_round_running`, `s_sur_wave_squad_count`, `k_sur_wave_timer`, `g_sur_drop_limit` |
| `cs_` | command script | — | `cs_sur_phantom_01`, `cs_gen0`, `cs_wraith_shoot` |
| `zn_`, `set_` | zone / zone set | Zones | `zn_survival`, `set_firefight` |

Note the exceptions, which are real and must be matched exactly: generator devices and switches are **unprefixed** (`generator0`, not `dm_generator0`); ammo crates are **unprefixed** (`ammo_crate0`); respawn zones are `spartan_01`–`06` / `elite_01`–`06`; health packs are `health_pack0`–`5`; fireteam squads are `sur_fireteam_01`–`06` on five maps but `sq_elite_fireteam_01`–`06` on Beachhead.

### 3.2 Numbering

* Two-digit, 1-based, zero-padded for squads, point sets, pods, kill volumes: `_01`, `_02`, … `_09`.
* **Single-digit, 0-based** for generators, generator switches, ammo crates, health packs, respawn zones, and `obj_survival/gen0`–`gen2`: `generator0`, `ammo_crate0`, `health_pack0`, `gen0`.
* Point set sub-points use bare short names: `p0`, `p1`, `p2`, `p3`, `face`, `erase`, `gen0`, `gen1`, `gen2`, `run_01`–`run_05`, `face_01`.
* Squad spawn points are referenced as `<squad>/<point>`: `sq_sur_phantom_01/phantom`, `sq_sur_drop_01/driver`, `sq_sur_sniper_01/sniper_01`, `sq_sur_banshee_01/driver`, `sq_sur_pelican/driver`.

### 3.3 Reference syntax a script must use

| Purpose | Call | Source |
|---|---|---|
| Get a vehicle from a squad's *starting location* (pre-placed, e.g. Phantom) | `(ai_vehicle_get_from_starting_location sq_sur_phantom_01/phantom)` | Courtyard L189 |
| Get a vehicle from a squad's *spawn point* (runtime-placed, e.g. drop pod) | `(ai_vehicle_get_from_spawn_point sq_sur_drop_01/driver)` | Courtyard L518 |
| Get an object for a named squad member | `(ai_get_object sq_sur_sniper_01/sniper_01)` | Waterfront fragments |
| Place a whole squad | `(ai_place sq_sur_drop_01)` | Courtyard L516 |
| Place a wave template into a group | `(ai_place_wave <index> gr_survival_waves 6)` | globals L591 |
| Count living | `(ai_living_count gr_survival_waves)` | everywhere |
| Move survivors to another squad | `(ai_migrate_persistent gr_survival_all ai_sur_remaining)` | globals L630 |
| Assign a task | `(ai_set_task <squad> <objective> <task>)` | Courtyard L179 |
| Reset an objective (re-evaluate tasks) | `(ai_reset_objective obj_survival/main_follow)` | Courtyard L162 |
| Test players in a volume | `(volume_test_players tv_wraith_01)` | Beachhead fragments |
| Test specific objects in a volume | `(volume_test_objects tv_north_deck (ai_actors gr_survival_waves))` | Installation 04 fragments |
| Create scenery/device/crate | `(object_create dm_drop_01)`, `(object_create_anew ammo_crate0)`, `(object_create_variant sc_resupply_01 "rocket")`, `(object_create_folder_anew cr_grenades)` | Courtyard |
| HUD blip | `(f_blip_object sc_resupply_01 blip_ordnance)` / `(f_unblip_object ...)` / `(f_blip_ai gr_survival_all blip_hostile)` / `(chud_track_object_with_priority obj_ammo_crate0 13)` | Courtyard, globals |
| Dropship callout | `(f_survival_callout_dropship v_sur_drop_01)` | Courtyard L543 |

### 3.4 Rules for authoring a new per-map script

1. **Name the startup script after the scenario tag**: `(script startup ff50_park ...)`. Beachhead's is `ff50_park`, not `beachhead`. Our `src/hsc/beachhead.hsc` etc. must follow suit or the names will not line up with the tag the script is compiled into.
2. **Do not duplicate the global allegiance calls** unless you need them before `survival_mode` is woken — but every stock map does duplicate them, so copying that is safe and idiomatic.
3. **Reference only names that exist in the tag.** HaloScript will not compile a reference to a missing object, so a wrong name is a build error — which is good. But a *valid* name in the wrong squad group is a silent logic failure, which is the dangerous case.
4. **Any new friendly infrastructure needs tag work**: a squad group outside the survival tree, squads inside it, spawn points for those squads, and a new AI objective with at least a follow task and a hold task filtered to that group.
5. **Put new `continuous` scripts behind `(sleep_forever)`** and `wake` them, exactly as the pod and resupply scripts do. That is Bungie's idiom for a one-shot sequence that can be re-fired.

---

## 4. Fireteam-follow in shipped Reach: confirmed disabled, but not the end of the story

### 4.1 The finding, verbatim

`global_firefight.hsc` L2710–2753:

```
(script dormant survival_elite_manager
    ; Any elites alive?
    (sleep_until (> (players_elite_living_count) 0))
    (if debug (print "starting elite scripts"))

    ;tysongr - 53954: Adios, fireteams
;*  ; Initial setup
    (ai_set_fireteam_absorber ai_sur_fireteam_squad0 1)
    (ai_player_add_fireteam_squad (player_elite 0) ai_sur_fireteam_squad0)
    (ai_player_set_fireteam_max (player_elite 0) 2)
    (ai_player_set_fireteam_max_squad_absorb_distance (player_elite 0) 3.0)
    (ai_set_fireteam_fallback_squad (player_elite 0) ai_sur_remaining)
    ... repeated for elite slots 1 through 5 ...
*;
)
```

**Confirmed: yes, fireteam-follow is genuinely disabled in shipped Reach Firefight**, commented out as a `;* ... *;` block with Bungie's own note crediting `tysongr` and bug `53954`. The companion script `survival_elite_fireteams` (L2792–2817) is likewise dead: its only caller, `(wake survival_elite_fireteams)` at L576 inside `survival_wave_spawn`, is commented out, and the script itself carries the same "Adios, fireteams" marker at L2792.

### 4.2 Three qualifications that matter for bought marines

**(a) It was never about marines.** This is the *elite* manager. Every call targets `(player_elite N)`. In Versus Firefight, elite-team players were going to get Covenant AI escorts absorbed from `sur_fireteam_01`–`06`. There is **no fireteam wiring for `player_human` or spartans anywhere in `global_firefight.hsc`**, commented out or otherwise. So the comment does not prove that spartan fireteams were tried and abandoned; it proves the elite feature was cut.

**(b) The engine opcodes are all still present.** `hsdoc_hr.txt` lists them live:

```
L1847  (<void> ai_player_add_fireteam_squad <unit> <ai>)
L1850  (<void> ai_player_remove_fireteam_squad <unit> <ai>)
L1853  (<void> ai_player_set_fireteam_max <unit> <short>)
L1856  (<void> ai_player_set_fireteam_no_max <unit>)
L1859  (<void> ai_player_set_fireteam_max_squad_absorb_distance <unit> <real>)
L1862  (<void> ai_set_fireteam_absorber <ai> <boolean>)
L1865  (<void> ai_set_fireteam_fallback_squad <unit> <ai>)
L1868  (<boolean> ai_is_in_fireteam <ai>)
L8611  (<boolean> player_can_issue_fireteam_directive)
L8613  (<real> g_fireteam_target_selection_preference_bonus)
L8615  (<real> ai_fireteam_hold_distance)
L8617  (<boolean> ai_fireteam_protect_leader)
L411   (<void> object_set_as_fireteam_target <object> <boolean>)
```

The first argument is a `<unit>`, so `(player_human 0)` is a legal target. `global_firefight.hsc` L1211 also still calls `(not (ai_is_in_fireteam squad))` in live, uncommented code, so the system is at least partly functional at runtime. **Our `fe_squad_follow` using `ai_player_add_fireteam_squad` on the buyer unit is therefore not calling into dead code — but it is calling into code Bungie shipped unused and untested.** Treat it as unverified until tested in engine.

**(c) There is a second, fully-shipped follow mechanism, and it is the one to use.** Task-based following. Per `AI Objectives.hsc`, the `remaining`, `hero_follow`, `main_follow` and `bonus_follow` tasks all carry:

```
flags: magic player sight
inhibit groups: cover, vehicles
movement: run (alert)
follow: player front
follow radius: 10
follow Z clamp: 1
exhaustion script: survival_refresh_follow
```

This is how every Covenant wave in every stock map chases the player, so it is proven on all six target maps. It is a **task property set in Sapien**, re-armed from script by `(ai_reset_objective obj_survival/main_follow)` after a sleep (`survival_refresh_follow`, Courtyard L160–163).

**So: bought marines can follow the player, and the reliable route is a new AI objective (e.g. `obj_unsc`) containing a `follow` task filtered to `gr_unsc_reinforcements`, plus a refresh script that calls `ai_reset_objective` on a timer.** The fireteam API is a possible shortcut, not the primary plan.

### 4.3 The dead fireteam squads are still a gift

Every one of the six target maps still assigns six fireteam squads in its `startup`, even though the consumer is commented out:

| Map | Squads assigned | Script lines |
|---|---|---|
| Beachhead | `sq_elite_fireteam_01`–`06` | L127–132 |
| Overlook | `sur_fireteam_01`–`06` | L48–53 |
| Outpost | `sur_fireteam_01`–`06` | L41–46 |
| Holdout | `sur_fireteam_01`–`06` | L127–132 |
| Glacier | `sur_fireteam_01`–`06` | L32–37 |
| Waterfront | `sur_fireteam_01`–`06` | L47–52 |
| Courtyard | `sur_fireteam_01`–`06` | L46–51 |

These are the **only reference to those squads in the entire shipped script set** — they are assigned and never used.

Per the authoring checklist, `sq_elite_fireteam_01`–`06` sit in `gr_survival_fireteams`, which is a child of `gr_survival_waves` and therefore of `gr_survival_all`. **That means they count toward `survival_wave_living_count`**, so they cannot be used as friendly squads without being reparented in the tag. Also, as escorts for *elite* players they are presumably Covenant characters.

What they are genuinely good for: **six pre-existing, currently-inert squad definitions per map that already have spawn geometry and are already named in the script.** Reparenting them out of `gr_survival_waves` into a new `gr_unsc_reinforcements`, and swapping their character to Marine/ODST, is far less tag work than authoring six new squads — and it guarantees their spawn points are somewhere Bungie thought a squad could usefully stand. Verify their group membership and character in Sapien before relying on this. **[INFER on character, [CONV] on group parentage, [SCRIPT] on the names.]**

### 4.4 The actual shipped proof that friendly squads work: Installation 04

`cex_ff_halo_main.hsc` is the one stock Firefight map that ships friendly Marines, and it is the single best template we have.

**Startup (L125–133):**

```
(if (survival_mode_scenario_extras_enable)
    (begin
        (ai_place sq_marines_01)
        (ai_place sq_marines_02)
        (ai_place sq_gs343)))
(ai_vehicle_reserve_seat warthog01 "warthog_d" TRUE)
```

**A separate AI objective, `obj_marines`**, with these tasks (confirmed by `ai_reset_objective` calls at L220–242 and by the `_fragments` file, where objective index 3 is `obj_marines`):

| Task | Refresh script | Fragment condition |
|---|---|---|
| `gate_marines` | `refresh_gate_marines` | — |
| `gate_marines_followers` | `refresh_gate_marines_followers` | `obj_mplaye_3_15/16/17`: `(> (game_coop_player_count) 1/2/3)` — one follower slot per player |
| `gate_marines_defenders` | `refresh_gate_marines_defenders` | `obj_mdefen_3_2..5`: `(volume_test_objects tv_north_deck (ai_actors gr_survival_waves))` and the same for `tv_west_deck`, `tv_east_deck`, `tv_south_deck` |
| `gate_north_overlook` | `refresh_gate_marines_north_overlook` | — |
| `gate_south_overlook` | `refresh_gate_marines_south_overlook` | — |

That defender condition is the design we want: **the marines reposition to whichever approach the live wave is actually on**, tested by `volume_test_objects` against `gr_survival_waves`. Four directional trigger volumes, four defender tasks.

**Pelican delivery (L838–912):**

```
(script static void ff_halo_respawn_warthog
    (if (= (vehicle_test_seat warthog01 "") FALSE)
        (begin (object_destroy warthog01) (ai_place sq_sur_pelican))))

(script command_script cs_ff_halo_pelican
    (set v_sur_pelican (ai_vehicle_get_from_starting_location sq_sur_pelican/driver))
    (object_cannot_die v_sur_pelican TRUE)
    (ai_place sq_marines_player_followers)
    (unit_enter_vehicle_immediate sq_marines_player_followers warthog01 "warthog_g")
    (cs_fly_by ps_sur_pelican/run_01)
    (cs_fly_by ps_sur_pelican/run_02)
    (cs_fly_by ps_sur_pelican/run_03)
    (cs_fly_to_and_face ps_sur_pelican/run_04 ps_sur_pelican/face_01 1)
    (wake pelican_blip)
    (vehicle_unload (ai_vehicle_get ai_current_actor) "pelican_lc")
    (cs_fly_by ps_sur_pelican/run_05)
    (cs_fly_by ps_sur_pelican/erase 10))
```

Note: Installation 04's Pelican primarily delivers a **Warthog**, with `sq_marines_player_followers` riding in the gunner seat. It is a vehicle respawn dressed as a reinforcement drop. The flight path is a dedicated point set `ps_sur_pelican` with `run_01`–`run_05`, `face_01`, `erase` — structurally identical to a Phantom path, and **present on no other map**.

**What this proves and what it does not.** It proves the full pattern works in shipped Reach: a separate friendly objective, directional defender tasks, per-player follower slots, and air delivery. It does **not** prove any of that exists on our six maps. `obj_marines`, `sq_marines_01`, `sq_marines_02`, `sq_marines_player_followers`, `sq_sur_pelican`, `ps_sur_pelican` and the four `tv_*_deck` volumes appear **only** in `cex_ff_halo`. Every one of them is new content on Beachhead, Overlook, Outpost, Holdout, Glacier and Waterfront.

---

## 5. Per-map comparison table

Everything below is **[SCRIPT]** — read directly from each map's own shipped `.hsc`.

| Feature | Beachhead `ff50_park` | Overlook `ff10_prototype` | Outpost `ff60_airview` | Holdout `ff70_holdout` | Glacier `ff60_icecave` | Waterfront `ff30_waterfront` | Courtyard `ff20_courtyard` |
|---|---|---|---|---|---|---|---|
| Lines (main) | 1579 | 1414 | 1365 | 1667 | 1111 | 1354 | 1267 |
| Scripts / globals | 68 / 24 | 60 / 23 | 46 / 16 | 71 / 32 | 30 / 13 | 59 / 24 | 34 / 20 |
| Phantom point sets | 4 + bonus | 4 + bonus | 4 + bonus | 4 + bonus | 4 + bonus | 4 + bonus | 4 + bonus |
| Phantom unload sides | right, right, left, left | right, left, dual, dual | dual, right, left, right | dual, left, dual, dual | dual ×4 | dual, right, right, left | dual ×4 |
| `k_sur_wave_timer` | 0 | 150 | 0 | 240 | 90 | 150 | 150 |
| **Covenant drop pods** | **4** (`dm_drop_01`–`04`, `sq_sur_drop_01`–`04`) | **5** (`_01`–`05`) | **none** | **4** (`_01`–`04`) | **none** | **5** (`_01`–`05`) | 4 (`_01`–`04`) |
| Resupply pods `sc_resupply_*` | 9 | 9 | 9 | 9 | **0** | 9 | 9 |
| Target Locator pods `sc_target_*` | 3 | 3 | 3 | 3 | **0** | 3 | 3 |
| `dm_longsword_01` | yes | yes | yes | yes | **no** | yes | yes |
| Static weapon scenery | — | — | — | — | **`sc_weapon_01`–`03`, folder `sc_weapons`** | — | — |
| Wraith hazard | `sq_sur_wraith_01`, `_02`, `ps_wraith` | `sq_sur_wraith_01`, `_02` | — | — | `sq_sur_wraith_01`, `_02`, `ps_wraith` | — | — |
| Ghost hazard | `sq_sur_ghost_01`, `_02` | — | `sq_sur_ghost_01`, `_02` | — | `sq_sur_ghost_01` | — | — |
| Banshee hazard | — | — | — | `sq_sur_banshee_01`, `_02`, `ps_banshee_01`, `_02` | — | `sq_sur_banshee_01`, `_02` | `sq_sur_banshee_01`, `_02` (spawner commented out) |
| Sniper hazard | — | — | `sq_sur_sniper_01`–`04`, `gr_survival_snipers` | `sq_sur_sniper_01`–`04`, `gr_survival_snipers` | — | `sq_sur_sniper_01`–`04`, `gr_survival_snipers` | — |
| `gr_survival_extras` referenced | no | **yes** | no | no | no | **yes** | **yes** |
| `ps_gen` (generator approach points) | **yes** (`gen0`–`gen2`) | no | no | **yes** (`gen0`–`gen2`) | no | no | no |
| `obj_survival/gen0`–`gen2` AI tasks | **yes** | no | no | **yes** | no | no | no |
| `cs_gen0`/`cs_gen1`/`cs_gen2` command scripts | **yes** | no | no | **yes** | no | no | no |
| Trigger volumes | `tv_wraith_01`, `tv_wraith_02`, `tv_null` | **none** | **none** | **none** | `tv_wraith`, `tv_null` | `tv_cliff_fall_left`, `tv_cliff_fall_right` | **none** |
| Kill volumes | `kill_sur_room_01`–`08` | same | same | same | same | same | same |
| Fireteam squads | `sq_elite_fireteam_01`–`06` | `sur_fireteam_01`–`06` | `sur_fireteam_01`–`06` | `sur_fireteam_01`–`06` | `sur_fireteam_01`–`06` | `sur_fireteam_01`–`06` | `sur_fireteam_01`–`06` |
| `cr_sandbox_items` | no | yes | no | yes | yes | yes | yes |
| Map-unique scenery | — | — | `sc_bfg_default`, `sc_bfg_destroyed` (made invulnerable at L19–20) | `sc_poa` (animated, `any:thruster`) | `sc_weapon_01`–`03` | — | — |
| Extra `obj_survival` tasks | `additional_follow`, `extras_backup`, `extras_follow`, `gen0`–`2` | — | — | `banshee_01`, `banshee_02`, `extras_backup`, `extras_follow`, `extras_gate`, `main_wave_gate`, `gen0`–`2` | `wraith01`, `wraith02`, `wraith02_advance` | `extras_gate` | `extras_gate` |

Universal on all seven: `sq_sur_phantom_01`–`04`, `sq_sur_bonus_phantom`, `sq_sur_remaining`, `sq_ff_bonus`, `gr_survival_waves`, `s_sur_wave_squad_count 6`, all 12 generator objects, `kill_sur_room_01`–`08`, `switch_zone_set set_firefight`, `obj_survival` with `hold_task`/`main_follow`/`hero_follow`/`remaining`/`generator`, `cr_grenades`, and the human/player allegiance pair.

---

## 6. BEACHHEAD — `ff50_park` placement dossier

**Script evidence: strong.** `ff50_park_main.hsc`, 1579 lines, 68 scripts, 24 globals. `ff50_park_fragments.hsc`, 45 lines.

### 6.1 What the map actually defines

| Category | Objects | Label |
|---|---|---|
| Air arrival | `ps_sur_phantom_01`–`04` (`p0`–`p3`, `face`, `erase`), `ps_sur_bonus_phantom`; squads `sq_sur_phantom_01`–`04`, `sq_sur_bonus_phantom`; unload sides right/right/left/left | [SCRIPT] names, [TAG] geometry |
| Wave spawns | `gr_survival_waves`, 6 squads drawn per wave | [SCRIPT] |
| Drop pods | `dm_drop_01`–`04` + `sq_sur_drop_01`–`04` (`/driver`) | [SCRIPT] |
| Weapon drops | `dm_resupply_01`–`09` + `sc_resupply_01`–`09`; `dm_target_01`–`03` + `sc_target_01`–`03`; `dm_longsword_01` | [SCRIPT] |
| Generators | `generator0`–`2` + 9 switch devices; **`ps_gen/gen0`, `/gen1`, `/gen2`**; command scripts `cs_gen0`–`cs_gen2`; AI tasks `obj_survival/gen0`–`gen2` and `gen0_boost`–`gen2_boost` (gated on `game_coop_player_count >= 3`) | [SCRIPT] |
| Vehicle hazards | `sq_sur_wraith_01`, `sq_sur_wraith_02` with `ps_wraith/p0`–`p3` (`cs_shoot_point`); `sq_sur_ghost_01`, `sq_sur_ghost_02` loaded by Phantom | [SCRIPT] |
| Trigger volumes | `tv_wraith_01`, `tv_wraith_02` (fragments: `volume_test_players`), `tv_null` (main L783: `sleep_until (volume_test_players tv_null)` — a deliberate never-true wait) | [SCRIPT] |
| Kill volumes | `kill_sur_room_01`–`08` | [SCRIPT] |
| Fireteams | `sq_elite_fireteam_01`–`06` — note the `sq_` prefix, unique to this map | [SCRIPT] |
| Ammo crates | `ammo_crate0`, `ammo_crate1` | [CONV] |
| Extra follow tasks | `obj_survival/additional_follow` (fragment `obj_saddit_0_28`: `(>= (game_coop_player_count) 4)`), `extras_follow`, `extras_backup` | [SCRIPT] |

### 6.2 Friendly squad placement

**Best option — reparent `sq_elite_fireteam_01`–`06`.** Six squad definitions with existing spawn geometry, currently assigned-and-unused. They are in `gr_survival_fireteams` → `gr_survival_waves` → `gr_survival_all` [CONV], so they **must** be reparented to a new `gr_unsc_reinforcements` or waves will never end. Verify character and parentage in Sapien.

**Second option — new squads anchored on `ammo_crate0` / `ammo_crate1`.** Read their positions from the tag; they mark where players hold.

**Avoid:** anything inside `kill_sur_room_01`–`08` (the eight enemy spawn rooms), and the `ps_wraith` firing-point arcs (`p0`–`p3`) which are the Wraith's bombardment targets — i.e. the ground the player is being shelled on.

**Defender anchors with real evidence:** `ps_gen/gen0`, `/gen1`, `/gen2`. Beachhead is one of only two target maps with a dedicated generator approach point set *and* per-generator AI tasks. Those three points are, by construction, defensible ground adjacent to objectives. A friendly squad sent to `ps_gen/genN` via a `cs_go_to` command script (copying `cs_gen0`, L238–243) is the single best-evidenced friendly placement available on any of the six maps.

**Follow behaviour:** copy the Installation 04 pattern. Beachhead already has `additional_follow` gated on 4+ players, which shows Bungie scaling follower counts by player count here.

### 6.3 Drop pod landing

Four existing Covenant pod sites: `sq_sur_drop_01`–`04` spawn points, with rails `dm_drop_01`–`04`. **Reuse for a friendly ODST pod is possible but requires tag work** — a new `dm_drop_05` rail and a new friendly squad spawn point. Copying `drop_pod_01` (the Courtyard/Beachhead shape is identical) and pointing it at a new squad is a ~25-line script change plus two tag objects.

Honest caveat: the four Covenant pod sites are, by definition, sited in enemy approach lanes. Do not land friendly ODSTs on them. Place the new pod spawn point beside `ammo_crate0`.

### 6.4 Purchase terminal

`ammo_crate0` [CONV] is the strongest anchor: player-reachable by design, already `chud_track_object_with_priority`-able. A second terminal at `ammo_crate1` gives coverage if the two crates are far apart.

Alternative with map-specific evidence: `generator_switch0` is a device control (`invisible_switch_gen`) that the player already interacts with in Generator Defense. The interaction pattern is proven; repurposing one as a purchase switch avoids inventing an interaction. But it collides with Generator Defense if that mode is on, and the design wants generators on here.

---

## 7. OVERLOOK — `ff10_prototype` placement dossier

**Script evidence: strong.** `ff10_prototype.hsc`, 1414 lines, 60 scripts, 23 globals. Banner reads `; ====== M10 PROTOTYPE FIREFIGHT SCIRPTS ===`. `ff10_prototype_fragments.hsc`, 21 lines.

### 7.1 What the map actually defines

| Category | Objects | Label |
|---|---|---|
| Air arrival | `ps_sur_phantom_01`–`04`, `ps_sur_bonus_phantom`; unload sides right/left/dual/dual | [SCRIPT] |
| Wave spawns | `gr_survival_waves`, 6 per wave | [SCRIPT] |
| Drop pods | **5** — `dm_drop_01`–`05`, `sq_sur_drop_01`–`05`, `v_sur_drop_01`–`05`. Joint most of any target map. | [SCRIPT] |
| Weapon drops | full set: 9 resupply, 3 target, `dm_longsword_01`, `cr_grenades` | [SCRIPT] |
| Generators | all 12 objects assigned, but **no `ps_gen`, no `cs_genN`, no `obj_survival/genN` tasks** | [SCRIPT] |
| Vehicle hazards | `sq_sur_wraith_01`, `sq_sur_wraith_02` — **no `ps_wraith` point set** | [SCRIPT] |
| `gr_survival_extras` | referenced at L507, L529 as the drop-pod gate | [SCRIPT] |
| Trigger volumes | **none at all**, in main or fragments | [SCRIPT] |
| Kill volumes | `kill_sur_room_01`–`08` | [SCRIPT] |
| Fireteams | `sur_fireteam_01`–`06` | [SCRIPT] |
| Cover crates | `cr_sandbox_items` | [SCRIPT] |
| Ammo crates | `ammo_crate0`, `ammo_crate1` | [CONV] |
| `obj_survival` tasks | `generator`, `hero_follow`, `main_follow`, `remaining` only — the minimal set | [SCRIPT] |

### 7.2 Friendly squad placement

Overlook has the **least friendly-relevant geography of the three wraith maps**: no `ps_gen`, no `ps_wraith`, no trigger volumes at all. The only defensible-position evidence is `ammo_crate0`/`ammo_crate1` and the eight kill volumes telling you where *not* to go.

**Recommendation:** anchor new friendly squads on `ammo_crate0` and `ammo_crate1`, and reparent `sur_fireteam_01`–`06` if their spawn points turn out to be usefully placed. Since there is no `ps_gen`, you must author a new point set (`ps_unsc_hold` or similar) for defender positions — there is no existing one to borrow.

**Note on the design's barn claim:** the design doc says "Both ammo crates are inside the barn **[V]**". The script cannot confirm or deny that — `ammo_crate0`/`ammo_crate1` are not even mentioned in `ff10_prototype.hsc`, because the globals already default to those names. The claim is plausible and consistent with Bungie's practice of putting crates in the player stronghold, but it is **[TAG]**, not script-verified. Read the positions out of the tag before building economy around them.

### 7.3 Drop pod landing

Five sites, the most of any target map, with `sq_sur_drop_01`–`05` and `dm_drop_01`–`05`. Good news for an ODST-pod purchase: the `drop_pod_NN` script shape is already duplicated five times here, so a sixth copy is low-risk. Still needs a new rail and squad spawn point in the tag for a friendly landing site, because the five existing ones are enemy lanes.

### 7.4 Purchase terminal

`ammo_crate0` [CONV]. Overlook has no `ps_gen` and no trigger volumes, so there is no second candidate with script evidence. The design's "radio in the upper barn room" interaction is **[GAP]** — no such named object appears in the script.

---

## 8. OUTPOST — `ff60_airview` placement dossier

**Script evidence: strong.** `ff60_airview.hsc`, 1365 lines, 46 scripts, 16 globals. `ff60_airview_fragments.hsc`, 21 lines.

### 8.1 What the map actually defines

| Category | Objects | Label |
|---|---|---|
| Air arrival | `ps_sur_phantom_01`–`04`, `ps_sur_bonus_phantom`; unload sides dual/right/left/right | [SCRIPT] |
| Wave spawns | `gr_survival_waves`, 6 per wave | [SCRIPT] |
| **Drop pods** | **NONE.** No `dm_drop_*`, no `sq_sur_drop_*`, no `v_sur_drop_*`, no `survival_drop_spawn`. | [SCRIPT] |
| Weapon drops | full set: `dm_resupply_01`–`09`, `sc_resupply_01`–`09`, `dm_target_01`–`03`, `sc_target_01`–`03`, `dm_longsword_01` | [SCRIPT] |
| Generators | all 12 assigned; **no `ps_gen`, no `cs_genN`, no per-generator tasks** | [SCRIPT] |
| Sniper hazard | `sq_sur_sniper_01`–`04`, group `gr_survival_snipers`, `survival_sniper_spawn` gated on `(< (ai_living_count gr_survival_snipers) g_sur_sniper_limit)` at L748 | [SCRIPT] |
| Ghost hazard | `sq_sur_ghost_01`, `sq_sur_ghost_02`, loaded by Phantom | [SCRIPT] |
| Map-unique scenery | `sc_bfg_default`, `sc_bfg_destroyed` — both `(object_cannot_take_damage ...)` at L19–20. The two "Tyrant" AA guns, one intact and one wrecked. | [SCRIPT] |
| Trigger volumes | **none** | [SCRIPT] |
| Kill volumes | `kill_sur_room_01`–`08` | [SCRIPT] |
| Fireteams | `sur_fireteam_01`–`06` | [SCRIPT] |
| Ammo crates | `ammo_crate0`, `ammo_crate1` | [CONV] |
| `k_sur_wave_timer` | **0** — fastest wave cadence, tied with Beachhead | [SCRIPT] |
| `obj_survival` tasks | `generator`, `hero_follow`, `main_follow`, `remaining` | [SCRIPT] |

Outpost is the **leanest of the six**: 46 scripts, 16 globals, no pods, no trigger volumes, no point sets beyond the Phantoms.

### 8.2 Friendly squad placement

No `ps_gen`, no trigger volumes, no drop pods. The only anchors are `ammo_crate0`/`ammo_crate1` [CONV] and the eight kill volumes.

One genuinely useful map-specific object: **`sc_bfg_default`** is the live AA gun and is explicitly made invulnerable — Bungie treating it as permanent mission furniture. It is the map's focal point, so the ground immediately around it is the de facto stronghold, and a friendly squad anchored there is defensible both tactically and fictionally. Position is **[TAG]**.

**Avoid:** the sniper squad positions. `sq_sur_sniper_01`–`04` have named members (`/sniper_01`, `/sniper_02` by analogy with Waterfront) sited for overwatch; those are the dominant firing positions and they are enemy-owned.

### 8.3 Drop pod landing

**Outpost has no drop-pod infrastructure whatsoever.** No rails, no pod squads, no spawner script. An ODST-pod delivery on Outpost is **100% new content**: a new `dm_drop_01` device machine with the `invis_cov_squad_drop_pod` tag (or a UNSC equivalent), a new squad spawn point, a new `drop_pod_01` continuous script, and the `pod_impact_default_large.effect` reference. Entirely doable — the Courtyard script is a complete recipe — but it is not reuse.

### 8.4 Purchase terminal

`ammo_crate0` [CONV]. Secondary idea with script evidence: the map has nine `sc_resupply_*` positions, all proven player-reachable and already blip-able with `f_blip_object ... blip_ordnance`. One of those could host a terminal with no new geometry. `sc_bfg_default` is the strongest fiction-fit but its approach is **[TAG]**.

---

## 9. HOLDOUT — `ff70_holdout` placement dossier

**Script evidence: strongest of the six.** `ff70_holdout.hsc`, 1667 lines, 71 scripts, 32 globals — the largest Firefight script Bungie shipped. `ff70_holdout_fragments.hsc`, 30 lines.

### 9.1 What the map actually defines

| Category | Objects | Label |
|---|---|---|
| Air arrival | `ps_sur_phantom_01`–`04`, `ps_sur_bonus_phantom`; unload sides dual/left/dual/dual | [SCRIPT] |
| Wave spawns | `gr_survival_waves`, 6 per wave | [SCRIPT] |
| Drop pods | 4 — `dm_drop_01`–`04`, `sq_sur_drop_01`–`04` | [SCRIPT] |
| Weapon drops | full set, 9 + 3 + longsword | [SCRIPT] |
| Generators | all 12, **plus `ps_gen/gen0`–`gen2`**, `cs_gen0`–`cs_gen2` (L255–270), and AI tasks `obj_survival/gen0`–`gen2` + `gen0_boost`–`gen2_boost` | [SCRIPT] |
| Banshee hazard | `sq_sur_banshee_01`, `sq_sur_banshee_02`, with **`ps_banshee_01/p0`–`p2` and `ps_banshee_02/p0`–`p3`** flight paths (L717–742); AI tasks `obj_survival/banshee_01`, `banshee_02` | [SCRIPT] |
| Sniper hazard | `sq_sur_sniper_01`–`04`, `gr_survival_snipers`, spawner gate at L784 | [SCRIPT] |
| Map-unique scenery | **`sc_poa`** — the *Pillar of Autumn*, animated via `(scenery_animation_start sc_poa objects\vehicles\human\unsc_fleet\unsc_halcyon_class_cruiser_poa\... any:thruster)` at L245 | [SCRIPT] |
| Trigger volumes | **none** | [SCRIPT] |
| Kill volumes | `kill_sur_room_01`–`08` (note: `kill_volume_enable` never appears in this file — only disable) | [SCRIPT] |
| Fireteams | `sur_fireteam_01`–`06` | [SCRIPT] |
| Cover crates | `cr_sandbox_items` | [SCRIPT] |
| Ammo crates | `ammo_crate0`, `ammo_crate1` | [CONV] |
| `k_sur_wave_timer` | **240** — the slowest cadence of all seven maps | [SCRIPT] |
| `obj_survival` tasks | the richest set: `banshee_01`, `banshee_02`, `extras_backup`, `extras_follow`, `extras_gate`, `generator`, `hero_follow`, `main_follow`, `main_wave_gate`, `remaining`, `gen0`–`gen2` | [SCRIPT] |

### 9.2 Friendly squad placement

**Holdout is the best-equipped of the six for friendly AI, and the evidence is specific.**

* **`ps_gen/gen0`, `/gen1`, `/gen2`** with ready-made `cs_gen0`–`cs_gen2` command scripts (`cs_enable_pathfinding_failsafe TRUE`, `cs_enable_targeting TRUE`, `cs_enable_looking TRUE`, `cs_go_to ps_gen/genN`). Three authored defensible positions, three authored command scripts. A friendly squad can be sent to any of them with a four-line copy of `cs_gen0`. This is the lowest-risk friendly placement available anywhere in the six maps.
* `obj_survival` has `main_wave_gate` and `extras_gate` explicitly, which means the objective tree here is fully fleshed out — a sibling `obj_unsc` objective will sit naturally alongside it.
* `sur_fireteam_01`–`06` available for reparenting.

**Avoid:** the `ps_banshee_01`/`ps_banshee_02` flight corridors (strafing lanes), the four sniper positions, the eight kill volumes.

**The design-doc warning about ramps and multi-level pathing is well founded** and the script agrees in spirit: Holdout is the only target map where Bungie bothered to author `cs_enable_pathfinding_failsafe TRUE` into ground command scripts (`cs_genN`). Use `ps_gen/genN` precisely because Bungie already proved AI can path there.

### 9.3 Drop pod landing

Four existing Covenant sites (`sq_sur_drop_01`–`04`, `dm_drop_01`–`04`). Same constraint as elsewhere: they are enemy lanes. A friendly pod needs a new rail plus spawn point, but `ps_gen/genN` tells you three safe-ish locations to put it near, which no other map except Beachhead offers.

### 9.4 Purchase terminal

`ammo_crate0` [CONV] is the default answer. Holdout additionally has the strongest *fiction* anchor in `sc_poa` — but `sc_poa` is distant animated set dressing (a cruiser on a launch pad), almost certainly not walk-up-able. Do not build an interaction on it.

Best Holdout-specific option: one of `generator_switch0`–`2`, which sit at `ps_gen/gen0`–`gen2` — proven reachable, proven interactive, and co-located with the defensible positions where friendly squads should stand. If Generator Defense is off for this scenario (the design uses a timer-based loss, not generators), the switches are free to repurpose.

---

## 10. GLACIER — `ff60_icecave` placement dossier

**Script evidence: strong but the map is sparse.** `ff60_icecave.hsc`, 1111 lines, 30 scripts, 13 globals — the smallest Firefight script Bungie shipped. Banner reads `; ====== M60 ICE CAVE ===`. `ff60_icecave_fragments.hsc`, 45 lines.

### 10.1 What the map actually defines

| Category | Objects | Label |
|---|---|---|
| Air arrival | `ps_sur_phantom_01`–`04`, `ps_sur_bonus_phantom`; unload sides dual ×4 | [SCRIPT] |
| Wave spawns | `gr_survival_waves`, 6 per wave | [SCRIPT] |
| **Drop pods** | **NONE.** No `dm_drop_*`, no `sq_sur_drop_*`, no spawner. | [SCRIPT] |
| **Weapon drop pods** | **NONE.** No `dm_resupply_*`, no `sc_resupply_*`, no `dm_target_*`, no `sc_target_*`, no `dm_longsword_01`, no `survival_resupply_pod_spawn`. | [SCRIPT] |
| Static weapons instead | **`sc_weapon_01`, `sc_weapon_02`, `sc_weapon_03`**, folder `sc_weapons`, created with `(object_create_folder_anew sc_weapons)` at L1057, blipped with `f_blip_object sc_weapon_0N blip_ordnance` and tested with the same `resupply_pod_test_weapon` marker check | [SCRIPT] |
| Generators | all 12 assigned; **no `ps_gen`, no `cs_genN`, no per-generator tasks** | [SCRIPT] |
| Wraith hazard | `sq_sur_wraith_01`, `sq_sur_wraith_02`, **`ps_wraith/p0`–`p3`** (`cs_shoot_point`, L180–192); AI tasks `obj_survival/wraith01`, `wraith02`, `wraith02_advance` | [SCRIPT] |
| Ghost hazard | `sq_sur_ghost_01` (one only) | [SCRIPT] |
| Trigger volumes | **`tv_wraith`** (fragments: `(not (volume_test_players tv_wraith))` gating the Wraith's shoot task), **`tv_null`** (L204, a never-true wait) | [SCRIPT] |
| Kill volumes | `kill_sur_room_01`–`08` | [SCRIPT] |
| Fireteams | `sur_fireteam_01`–`06` | [SCRIPT] |
| Cover crates | `cr_sandbox_items`, `cr_grenades` | [SCRIPT] |
| Ammo crates | `ammo_crate0`, `ammo_crate1` | [CONV] |
| `k_sur_wave_timer` | 90 | [SCRIPT] |
| Phantom wave booleans | `b_phantomw_01_1`–`b_phantomw_04_2` used in fragment conditions | [SCRIPT] |

### 10.2 Friendly squad placement

Glacier has **two trigger volumes and one point set beyond the Phantoms** — more trigger-volume evidence than Overlook, Outpost, Holdout or Courtyard, but no `ps_gen`.

`tv_wraith` is the most useful single object: the fragment condition is `(not (volume_test_players tv_wraith))` gating `wraith01`/`wraith02` shoot tasks, i.e. **the Wraith stops shelling when players are inside `tv_wraith`**. That makes `tv_wraith` a Bungie-authored statement of "this volume is sheltered from the Wraith". It is the closest thing to a verified safe zone on any of the six maps.

> **Recommended: anchor Glacier's friendly squads inside `tv_wraith`.** Read its bounds from the tag. This is script-backed, not inferred.

`sc_weapon_01`–`03` are static weapon holders — permanent, player-reachable, blipped. Three more [SCRIPT]-named reachable positions.

**Avoid:** `ps_wraith/p0`–`p3` (the Wraith's four firing points — the open ground), the eight kill volumes.

### 10.3 Drop pod landing

**None possible without new content, and the design already says so.** Glacier has no pod rails, no pod squads, and crucially no `dm_longsword_01` — Bungie made a deliberate decision that nothing arrives from above on this map. The design doc's "no pod/Pelican delivery is possible underground" is **confirmed by the script**: it is the only one of the ten FF maps with zero air-delivered objects. Friendly arrival must be a ground `ai_place` at a sheltered spawn point.

### 10.4 Purchase terminal

`ammo_crate0` [CONV], ideally cross-checked against `tv_wraith` so the terminal is inside the sheltered volume. Secondary: one of `sc_weapon_01`–`03`, which are already created as a folder and already blipped — the cheapest possible retrofit, since the blip machinery exists.

Note Glacier is the **only** target map where the weapon-drop purchase pattern (§1.9) cannot be cloned, because none of `dm_resupply_*` / `sc_resupply_*` exists. Any "buy a weapon" purchase on Glacier must use the `sc_weapons` folder pattern instead (`object_create_folder_anew`), which is a different and simpler mechanism.

---

## 11. WATERFRONT — `ff30_waterfront` placement dossier

**Script evidence: strong.** `ff30_waterfront.hsc`, 1354 lines, 59 scripts, 24 globals. Banner reads `; ====== M30 WATERFRONT ===`. `ff30_waterfront_fragments.hsc`, 33 lines.

### 11.1 What the map actually defines

| Category | Objects | Label |
|---|---|---|
| Air arrival | `ps_sur_phantom_01`–`04`, `ps_sur_bonus_phantom`; unload sides dual/right/right/left | [SCRIPT] |
| Wave spawns | `gr_survival_waves`, 6 per wave | [SCRIPT] |
| Drop pods | **5** — `dm_drop_01`–`05`, `sq_sur_drop_01`–`05`, `v_sur_drop_01`–`05`. Joint most of any target map. | [SCRIPT] |
| Weapon drops | full set, 9 + 3 + longsword | [SCRIPT] |
| Generators | all 12 assigned; **no `ps_gen`, no `cs_genN`, no per-generator tasks** | [SCRIPT] |
| Banshee hazard | `sq_sur_banshee_01`, `sq_sur_banshee_02` — **no `ps_banshee_*` point sets** (unlike Holdout) | [SCRIPT] |
| Sniper hazard | `sq_sur_sniper_01`–`04`, `gr_survival_snipers`, with `(ai_force_full_lod gr_survival_snipers)` at L493 and the spawner gate at L495 | [SCRIPT] |
| Trigger volumes | **`tv_cliff_fall_left`, `tv_cliff_fall_right`** — fragments test `(volume_test_object tv_cliff_fall_left (ai_get_object sq_sur_sniper_01/sniper_01))` and the same for `sniper_02`. These are fall-off-the-cliff guards for the sniper squads, not player volumes. | [SCRIPT] |
| `gr_survival_extras` | drop-pod gate at L534, L556 | [SCRIPT] |
| Kill volumes | `kill_sur_room_01`–`08` | [SCRIPT] |
| Fireteams | `sur_fireteam_01`–`06` | [SCRIPT] |
| Cover crates | `cr_sandbox_items`, `cr_grenades` | [SCRIPT] |
| Ammo crates | `ammo_crate0`, `ammo_crate1` | [CONV] |
| `k_sur_wave_timer` | 150 | [SCRIPT] |
| `obj_survival` tasks | `extras_gate`, `generator`, `hero_follow`, `main_follow`, `remaining` | [SCRIPT] |

Note the named sniper members: `sq_sur_sniper_01/sniper_01` and `sq_sur_sniper_02/sniper_02`. Waterfront is the only target map where the script names individual squad members, which confirms the `<squad>/<member>` reference form for the whole set.

### 11.2 Friendly squad placement

No `ps_gen`, no `ps_banshee`, and the only two trigger volumes are cliff-fall guards for enemy snipers — not player shelter. So Waterfront, like Overlook and Outpost, offers **`ammo_crate0`/`ammo_crate1` plus the eight kill volumes and nothing else** as script-backed geography.

`tv_cliff_fall_left` / `tv_cliff_fall_right` are still useful negatively: they tell you where the map's lethal drops are. Do not put a friendly squad, a pod landing or a terminal near either.

**Recommendation:** new squads anchored on `ammo_crate0`/`ammo_crate1`; reparent `sur_fireteam_01`–`06` if their spawn points prove useful; author a new `ps_unsc_hold` point set for defender positions.

The design's observation that the ring geometry puts friendlies under fire from all sides is consistent with the script: **five drop-pod sites plus four Phantom corridors is the densest arrival geometry of any target map** (Overlook also has five pods but Waterfront adds snipers and banshees on top). This is the map where the "friendly squads must sit behind the player's line" requirement is hardest to satisfy, because there is no behind.

### 11.3 Drop pod landing

Five existing Covenant sites. Script shape duplicated five times already, so a sixth copy is routine. New rail and squad spawn point still required for a friendly site, and on this map more than any other you must verify it is not in one of the 360° approach basins.

### 11.4 Purchase terminal

`ammo_crate0` [CONV]. No map-specific alternative with script evidence; the generator switches exist but Waterfront has no `ps_gen`, so their reachability is unproven here in a way it is not on Beachhead and Holdout.

---

## 12. COURTYARD — `ff20_courtyard` reference dossier

Not a target map, but it is our fully-dissected template and the comparison baseline.

| Category | Objects |
|---|---|
| Air arrival | `ps_sur_phantom_01`–`04` (`p0`–`p3`, `face`, `erase`), `ps_sur_bonus_phantom`; unload sides dual ×4 |
| Wave spawns | `gr_survival_waves`, 6 per wave |
| Drop pods | 4 — `dm_drop_01`–`04`, `sq_sur_drop_01`–`04` |
| Weapon drops | 9 resupply + 3 target + `dm_longsword_01` + `cr_grenades` |
| Generators | all 12; no `ps_gen`, no per-generator tasks |
| Banshee hazard | `sq_sur_banshee_01`, `_02` present with `banshee_emp_kill`, but **`(wake survival_banshee_spawn)` is commented out at L146** — the hazard is authored and shipped dormant |
| Trigger volumes | none |
| Kill volumes | `kill_sur_room_01`–`08` |
| Fireteams | `sur_fireteam_01`–`06` |
| Ammo crates | `ammo_crate0`, `ammo_crate1` [CONV] |
| `obj_survival` tasks | `extras_gate`, `generator`, `hero_follow`, `main_follow`, `remaining` |

Courtyard's own design note in the appendix of `05-map-scenario-designs.md` — "seal both **map-built enemy spawn rooms** [V] as purchasable map state" — is the one place our designs correctly anticipated real engine geography. The map has **eight** such rooms (`kill_sur_room_01`–`08`), not two, and they are kill volumes rather than sealable doors, so the implementation would be `kill_volume_enable` rather than a device. But the instinct was right.

---

## 13. Cross-check: `research/05-map-scenario-designs.md` against engine reality

The design doc contains **zero engine identifiers** — no `sq_`, `gr_`, `ps_`, `tv_`, `dm_`, `sc_` or `obj_` names anywhere in its 541 lines. That is not a criticism of its design content, but it means nothing in it was previously checkable against a script. Here is the check.

### 13.1 Mismatches that invalidate a stated purchase

| # | Where | Design claim | Engine reality | Severity |
|---|---|---|---|---|
| 1 | §5.3 Outpost, purchase catalogue | "**ODST squad** (4, 1 rocket) — 3,000 — **Drop pods** onto Base Front — the engine already ships drop-pod hazards **[V, S4]**" | `ff60_airview.hsc` has **no `dm_drop_*`, no `sq_sur_drop_*`, no `v_sur_drop_*` and no `survival_drop_spawn` script**. Outpost ships zero drop-pod infrastructure. The `[V]` citation is true of Firefight in general and false of this map. | **Highest.** A stated delivery mechanism does not exist on the map it is sold on. |
| 2 | §5.3 Outpost, technical risks | "Drop-pod hazard waves on the Deck roof" (round 5 note) | Same as above — Outpost has no pod hazard at all. | High |
| 3 | §5.5 Glacier, purchase catalogue | "Rocket Warthog — 7,000", "**Scorpion** — 12,000" justified by "Wraith terrain verified **[V]**" | Glacier's Wraiths are `sq_sur_wraith_01`/`_02` driven by `cs_shoot_point ps_wraith/p0`–`p3` — a **stationary bombardment command script**, not a patrol. The Wraith is scripted to sit and shell four fixed points. It proves nothing about drivable ground. | High — the whole vehicle-terrain argument for Glacier rests on a misread. |
| 4 | §5.1 Beachhead, technical risks | Same Wraith-terrain reasoning for the Rocket Warthog | Beachhead's Wraiths are also `cs_shoot_point ps_wraith/p0`–`p3`. Same correction. | High |
| 5 | §5.2 Overlook | "**Wraith hazard** crosses to the yard — the 'armour on the bridge' beat" | Overlook has `sq_sur_wraith_01`/`_02` but **no `ps_wraith` point set at all**, so no authored firing points and no authored movement. Whatever the Wraith does on Overlook, the script does not direct it. "Crosses to the yard" is unsupported. | Medium-high |
| 6 | §5.6 Waterfront | "**Banshee hazard** owns the sky over the pads" — and §5.4 Holdout likewise | Holdout has real Banshee flight paths (`ps_banshee_01/p0`–`p2`, `ps_banshee_02/p0`–`p3`). **Waterfront has `sq_sur_banshee_01`/`_02` but no `ps_banshee_*` point sets.** Waterfront's Banshees have no authored path. | Medium |
| 7 | §5.2 Overlook | "**LOSE.** Generator Count 1 (the uplink generator in the barn's lower floor)" — and similarly Beachhead §5.1 ("two generators on the Stage"), Glacier §5.5 ("Generator Count 2 dressed as survey power units"), Waterfront §5.6 ("Generator Count 3 dressed as pump controllers, spread across the ring") | `generator0`–`2` are **fixed device machines at fixed tag positions on every map**. They cannot be moved, re-dressed, or chosen per scenario — only counted (`s_sur_generator_count`) and ordered (`b_sur_generator_order_random`). Worse: **only Beachhead and Holdout have `ps_gen` and the `obj_survival/gen0`–`gen2` AI tasks** that route Covenant to the generators. On Overlook, Outpost, Glacier, Waterfront and Courtyard the enemy has only the generic `generator` task, so generator-defence AI routing is **not authored**. | **High.** Four of six scenarios build their loss condition on generator placement they cannot control and AI routing that only two maps have. |
| 8 | §5.1 Beachhead | "a Covenant corvette overflight that drops the first Phantom on the Lake side and locks the access road" | Phantom arrival is fixed: four `ps_sur_phantom_NN` paths with unload sides hard-coded right/right/left/left. Which one fires first is `begin_random` in `survival_dropship_spawner`. **You cannot choose "the Lake side" for wave 1 from script** without new point sets. | Medium |
| 9 | §5.1 Beachhead, §5.4 Holdout | "Falcon gunner ride, 60 s — 11,000 … **[V, S8]**" / "Helipads make air delivery native to the map **[V]**" | No map of the six references any UNSC aircraft. The only Pelican flight path in shipped Reach Firefight is `ps_sur_pelican` on `cex_ff_halo` **only**. A Falcon ride needs a new point set, a new command script and a new squad on every map that sells it. | Medium (already flagged `[U]` in the design, but the scope is bigger than stated) |
| 10 | §5.6 Waterfront | "**ODST squad** … Arrives over the **covered bridge** … **no air delivery needed**" | There is no ground-arrival mechanism in any shipped Firefight script — only `ai_place` at a tag spawn point, Phantom unload, and pod rails. A walk-in-from-off-map arrival is new content (a spawn point near a map edge plus a `cs_go_to` to a new point set). | Medium |
| 11 | §5.2 Overlook | "Interacting with the **radio in the upper barn room** **[V]** starts the uplink" | No object named anything like a radio appears in `ff10_prototype.hsc`. The only player-interactable devices referenced are `generator_switch0`–`2`. | Medium |
| 12 | §5.3 Outpost | "**Marine squad** (3) — Spawns inside the base, first floor **by the health packs**" | `health_pack0`–`5` are in the authoring checklist [CONV] but are **never referenced by any per-map script**, so their existence and positions on Outpost are [TAG] at best. | Low-medium |
| 13 | §5.1 Beachhead | "Both ammo crates are inside the barn **[V]**" (actually stated for Overlook §5.2) | `ammo_crate0`/`ammo_crate1` are global defaults, referenced by **no** per-map script except Corvette. Their presence is [CONV], their positions [TAG]. Not `[V]`. | Low-medium — but important, because four scenarios put the economic centre on them. |
| 14 | §5.5 Glacier | "a **Spartan Laser** in a weapon holder below the rocks, plus **Sniper Rifle and Rocket Launcher racks** **[V]**" | This is the one map claim the script *supports*: `sc_weapon_01`, `sc_weapon_02`, `sc_weapon_03` in folder `sc_weapons`, created with `object_create_folder_anew` and blipped. **Three** static weapon positions, matching the three weapons described. Good call. | — (confirmed) |
| 15 | §5.5 Glacier | "no Target Locator, no sky … Any purchase involving a Pelican, Falcon, drop pod or orbital strike is invalid **[V, S5]**" | **Confirmed by script.** Glacier is the only FF map with no `dm_longsword_01`, no `dm_target_*`, no `sc_target_*`, no `dm_resupply_*` and no pod rails. | — (confirmed) |
| 16 | §6.1 cross-cutting | "Stock Installation 04's four beam-tower ODSTs have no pathfinding directions and stand still, while the Pelican-delivered reinforcement squad is correctly scripted to follow players **[V, S5]**" | **Substantially confirmed and better than stated.** `cex_ff_halo_main.hsc` has a whole separate objective `obj_marines` with five tasks including `gate_marines_followers` gated per player count and `gate_marines_defenders` driven by `volume_test_objects tv_<dir>_deck (ai_actors gr_survival_waves)`. The followers are `sq_marines_player_followers`; the static ones are `sq_marines_01`/`sq_marines_02`. Copy this. | — (confirmed, upgrade) |

### 13.2 Mismatches of kind, not of detail

**17. Every scenario assumes friendly squads can be given a position and a follow order from script. None of the six maps can do that today.** Every task in `obj_survival` is filtered to a `gr_survival_*` squad group (§1.12), so a friendly squad outside that tree matches no task and will stand still. Friendly AI on these six maps requires a **new AI objective in the scenario tag** — the `obj_marines` pattern from Installation 04 — before any script can position or move them. This is the single largest piece of unscoped work implied by the designs.

**18. "Spawns at the Mezzanine / in the storeroom / in the House / inside the base" has no engine referent on any of the six maps.** There is no named friendly spawn point anywhere. Each of those six phrases is a new squad plus a new spawn point in the tag. The designs read as though a spawn location can be chosen in script; it cannot.

**19. The purchase-terminal / "purchase board" concept has no engine referent either.** Nothing in shipped Firefight is a walk-up interactable except `generator_switch0`–`2`. `ammo_crate0`/`ammo_crate1` are the best *positions* but they are equipment, not switches. A terminal is either a repurposed generator switch (two maps have proven-reachable ones) or new content.

**20. §6.2's "friendly AI ≤ 6 alive" working rule interacts badly with `gr_survival_extras`.** If friendly squads are parented under `gr_survival_extras` as Bungie's own checklist suggests, then on **Courtyard, Overlook and Waterfront** living friendlies permanently block Covenant drop pods, because `survival_drop_spawn` waits for `(<= (ai_living_count gr_survival_extras) 0)` both before and after each spawn burst. Those are three of the four pod-equipped target maps. Parent friendlies outside the survival tree entirely.

**21. §6.6 "all six designs use maps with dedicated enemy drop zones away from the player stronghold"** is now checkable and is partly wrong. The eight `kill_sur_room_01`–`08` volumes on every map are the spawn rooms, and `survival_wave_end_conditions` flushes them with `survival_kill_volumes_on` once fewer than 7 enemies remain — which is Bungie admitting enemies get stuck in them. Whether they are "away from the stronghold" is [TAG] on all six maps and cannot be asserted from the script. Waterfront in particular has five pod sites plus four Phantom corridors, the densest arrival geometry of the six.

### 13.3 What the designs got right

* The map-name to scenario-tag mapping in §2.2 is correct for all seven maps listed.
* 6 squads per wave (§6.2, "~24 enemies") matches `s_sur_wave_squad_count 6` on all six maps exactly.
* 5 waves per round, 3 rounds per set matches `k_sur_wave_per_round_limit 5` / `k_sur_round_per_set_limit 3`.
* Glacier's "no sky" constraint is fully confirmed.
* Glacier's three static weapon racks are confirmed (`sc_weapon_01`–`03`).
* The Installation 04 follower-vs-static-ODST contrast is confirmed and is richer than the design knew.
* Courtyard's "map-built enemy spawn rooms" is confirmed in kind (eight of them, as kill volumes).
* The decision to gate win purchases by round rather than timer sits well with the engine, since `survival_mode_wave_get` and `survival_mode_get_set_count` are both readable (globals L653–654).

---

## 14. Required corrections to `src/hsc/`

Our scripts are better-grounded than the design doc — `fe_reinforcements.hsc` already cites `global_firefight.hsc` L665–674 and the "Adios, fireteams" comment, and already insists on a squad group outside the survival tree. Four corrections remain.

### 14.1 Invented names that must be replaced with real ones

Our per-map scripts rename stock hazard squads with map-letter prefixes. Those squads exist under `sq_sur_*` names; our names do not exist and will fail to compile against the real tag.

| Our name | File | Real stock name | Map |
|---|---|---|---|
| `sq_bh_wraith_01`, `sq_bh_wraith_02` | `beachhead.hsc` | `sq_sur_wraith_01`, `sq_sur_wraith_02` | Beachhead [SCRIPT] |
| `sq_bh_ghost_01` | `beachhead.hsc` | `sq_sur_ghost_01` (and `_02` exists) | Beachhead [SCRIPT] |
| `sq_ov_wraith_01`, `sq_ov_wraith_02` | `overlook.hsc` | `sq_sur_wraith_01`, `sq_sur_wraith_02` | Overlook [SCRIPT] |
| `sq_op_ghost_01`, `sq_op_ghost_02` | `outpost.hsc` | `sq_sur_ghost_01`, `sq_sur_ghost_02` | Outpost [SCRIPT] |
| `sq_ho_banshee_01`, `sq_ho_banshee_02` | `holdout.hsc` | `sq_sur_banshee_01`, `sq_sur_banshee_02` | Holdout [SCRIPT] |
| `sq_gl_wraith_01`, `sq_gl_wraith_02`, `sq_gl_ghost_01` | `glacier.hsc` | `sq_sur_wraith_01`, `sq_sur_wraith_02`, `sq_sur_ghost_01` | Glacier [SCRIPT] |
| `sq_wf_snipers`, `sq_wf_jackal_snipers` | `waterfront.hsc` | `sq_sur_sniper_01`–`04`, group `gr_survival_snipers` | Waterfront [SCRIPT] |
| `ai_sur_phantom_` (truncated) | `outpost.hsc` | `ai_sur_phantom_01`–`04` | all |

`holdout.hsc` already references `sq_sur_banshee_01` in one place alongside its invented `sq_ho_banshee_01` — so that file is internally inconsistent.

### 14.2 Startup script names

Our files are `beachhead.hsc`, `overlook.hsc`, etc. The startup script inside each must be named for the scenario tag, matching Bungie's convention (`(script startup ff20_courtyard ...)`):

`ff50_park`, `ff10_prototype`, `ff60_airview`, `ff70_holdout`, `ff60_icecave`, `ff30_waterfront`.

Our init scripts are currently `fe_beachhead_init`, `fe_overlook_init`, etc. Keep those as helper scripts if you like, but the `startup` entry point must carry the tag name.

### 14.3 `fe_squad_hold` cannot use `obj_survival`

```
(script static void (fe_squad_hold (ai squad) (string_id objective) (string_id task))
    (ai_set_task squad objective task))
```

The opcode is right (`hsdoc_hr.txt` L1505). The arguments as used by the per-map scripts are not: every task in `obj_survival` carries a squad group filter naming a `gr_survival_*` group (§1.12), and `hold_task`'s filter is `gr_survival_all` specifically — the one group a friendly squad must never join. A friendly squad in `gr_unsc_reinforcements` given `obj_survival/hold_task` matches no task and idles.

**Fix:** author a new objective `obj_unsc` (or `obj_marines`, to match Bungie) in each scenario tag, with at least:
* a `hold` task filtered to `gr_unsc_reinforcements`, and
* a `follow` task filtered to `gr_unsc_reinforcements_followers` with `follow: player front`, `follow radius: 10`, `follow Z clamp: 1`, `flags: magic player sight`, `inhibit groups: cover, vehicles`, and an exhaustion script.

Then `fe_squad_hold` passes `obj_unsc hold`, and a new `fe_squad_refresh_follow` calls `(ai_reset_objective obj_unsc/follow)` after a sleep, exactly as `survival_refresh_follow` does.

### 14.4 `fe_squad_follow` is a reasonable second mechanism, not the primary one

```
(script static void (fe_squad_follow (ai squad) (unit buyer))
    (ai_set_fireteam_absorber squad 1)
    (ai_player_add_fireteam_squad buyer squad)
    (ai_player_set_fireteam_max buyer 4)
    (ai_player_set_fireteam_max_squad_absorb_distance buyer 3.0))
```

All four opcodes exist (§4.2) and `<unit>` is the right first-argument type, so this compiles and may work. But it is the system Bungie shipped unused. **Keep it behind a debug flag and make the task-based follow of §14.3 the primary path.** Note also that `ai_player_set_fireteam_max_squad_absorb_distance 3.0` is Bungie's own value from the commented-out block and is probably far too small (3 world units) for a bought squad that should trail a player across a map.

### 14.5 `gr_survival_extras` references in our per-map scripts

All six of our per-map scripts reference `gr_survival_extras`. That group is only script-referenced on Overlook, Waterfront and Courtyard. On Beachhead, Outpost, Holdout and Glacier its existence is [CONV] (from the authoring checklist, where it is a top-level group) but unproven. More importantly, per §1.3 and §13.2 item 20, our friendly squads must not be members of it, and our scripts should not be *waiting* on its living count either — on three of the maps that counter is what gates Covenant drop pods.

### 14.6 Objects our scripts invent that must be created in the tag

Every one of these is new content, not a reference to existing map data. Listed so nobody assumes they already exist:

`gr_unsc_reinforcements`; `sq_fe_marines`, `sq_fe_odst`, `sq_fe_gunner`, `sq_fe_pilot`; `dm_fe_pod_01`; all `tv_<map>_board` / `tv_<map>_buy_*` purchase volumes; all `sc_<map>_*` purchase scenery (`sc_bh_pelican`, `sc_bh_falcon`, `sc_bh_warthog`, `sc_bh_turret_01`, `sc_ov_scorpion`, `sc_op_cannon_live`, `sc_op_cannon_wreck`, `sc_ho_shuttle`, `sc_ho_aa_battery`, `sc_gl_scorpion`, `sc_wf_light`, and the rest); `dm_ov_barricade`, `dm_wf_ramp_01`, `dm_wf_ramp_02`; and the `obj_unsc` objective of §14.3.

Exception worth noting: `sc_op_cannon_live` / `sc_op_cannon_wreck` in `outpost.hsc` duplicate objects that **already exist** as `sc_bfg_default` and `sc_bfg_destroyed` [SCRIPT]. Use the stock names.

---

## 15. Recommended next steps

1. **Open the six scenario tags in Sapien (HREK) or Assembly and export three things per map:** the positions of `ammo_crate0`/`ammo_crate1`; the bounds of `kill_sur_room_01`–`08`; and the membership and character of `gr_survival_waves`, `gr_survival_extras` and `sur_fireteam_01`–`06` (`sq_elite_fireteam_01`–`06` on Beachhead). Those three exports turn every [TAG] label in this document into a coordinate.
2. **Also export `ps_gen` on Beachhead and Holdout, and `tv_wraith` on Glacier.** Those are the only three script-backed "safe-ish ground" markers across the six maps.
3. **Author `obj_unsc` once, as a template, and paste it into all six tags.** Mirror `obj_marines` from `cex_ff_halo`: a gate, a follower task with `follow: player front`, a defender task per approach, and per-player-count conditions.
4. **Fix the invented squad names in `src/hsc/` (§14.1) before anything else**, because they are the cheapest fix and they are currently guaranteed build failures.
5. **Re-cost the Outpost and Glacier scenarios**, which both sell a drop-pod ODST delivery on maps with no pod infrastructure, and re-examine the generator loss conditions on Overlook, Glacier and Waterfront, which have no generator AI routing.
