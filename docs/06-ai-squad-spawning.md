# 06 — Friendly AI squad spawning in Halo: Reach Firefight (MCC)

Research date: 2026-11-20. Every API claim below is followed by a citation (file + line, URL, or
bytes read from the reference files in `../reference/`). Items I could not verify are explicitly
labelled **UNPROVEN**.

---

## 0. The decisive answer

**Purchasable friendly Marine/ODST squads in Firefight CANNOT be done from a game-variant script.
It requires a modified `.map` file. Confidence: very high (~98%).**

The reason is blunter than "Megalo lacks an AI opcode": **a Halo: Reach Firefight game variant
contains no Megalo script at all.** Megalo script data (triggers/conditions/actions/string table)
exists only in the `megalogamengine` engine variant — i.e. ordinary Multiplayer gametypes. Firefight
variants use a different engine type whose payload is a flat settings struct (waves, squad-type
indices, skulls, traits, lives, generators).

Four independent confirmations:

1. **The reference mod's own bytes.** `../reference/Firefight Evolved.bin` parsed with
   `@blamnetwork/blf` (Reach-MCC build `v_untracked_25_08_16_1352`) yields:
   - `m_game_engine: 4` → `e_game_engine_type::survival`
     (enum: `none=0, sandbox=1, megalogamengine=2, campaign=3, survival=4` —
     `Blam-Network/blf`, `blf_lib/src/blam/haloreach_mcc/v_untracked_25_08_16_1352/game/game_variant.rs` L1482-1490)
   - Only `m_survival_variant` is populated; no Megalo variant, no triggers, no actions.
   - `name: "FIREFIGHT EVOLVED"`,
     `description: "Used with Halo: Reach Evolved Firefight. Use your Firefight Score to purchase bonuses."`
     ← the gametype itself says it is a companion to the map mod.
   - `variant_length: 963` bytes of variant data; created 2023-10-07 by XUID 2533274869542212.
   - A raw ASCII/bit-shift scan of the whole `mpvr` chunk (20,520 bytes) finds exactly two readable
     strings: `Red Team`, `Blue Team`. No "ODST", no "Marine", no purchase labels. There is no
     Megalo string table to hold them.
2. **`c_game_engine_survival_variant` has no script member** — `game_engine_survival.rs` L22-49
   (fields: flags, set count, bonus lives, traits, 3 custom skulls, 3 round properties, bonus round).
3. **ReachVariantTool's Firefight variant class has no script member** —
   `DavidJCobb/ReachVariantEditor`, `native/src/ReachVariantTool/game_variants/types/firefight.h`
   L8-81. RVT's Firefight editor likewise has no Script window; its page list is metadata, settings,
   lives, respawn, traits, rounds, bonus wave, skulls, teams, loadouts
   (`docs/working - help docs/editor/main_window_ff/index.xml`).
4. **Firefight's logic lives in the map's HaloScript, not in the variant.** RVT's own Firefight docs:
   "This value is exposed to the HaloScript code that powers Firefight
   (`survival_mode_get_bonus_target`)" (`editor/main_window_ff/scenario.xml`). The stock Reach
   Firefight engine script is a 114 KB `.hsc` file shipped per-map plus one global
   (`data/globals/global_firefight.hsc`, copied to `_raw/hsc/global_firefight.hsc`).

**Corollary:** the Steam Workshop item (3453792163) is "Halo Reach: Evolved Public Beta",
**file_size = 7,333,964,512 bytes (7.3 GB)** (Steam `GetPublishedFileDetails`, saved in
`_raw/api1.json`), tagged `HaloReach / Campaign / Firefight`. Its description instructs users to
*additionally* download the `.bin` gametypes and drop them in
`steamapps\common\Halo The Master Chief Collection\haloreach\game_variants`. A 7.3 GB payload is
replaced `.map` files and tags. The reinforcements, auto turret, Falcon gunner, Scorpion, MAC strike
and Sentinel hack all live in those maps.

### What this means for the deliverable

- A pack of compilable scripts **can** deliver: Firefight variant settings (waves, enemy squad
  types, skulls, traits, lives) — that is what `.bin` files are.
- Purchasable AI reinforcements require the **Halo Reach Editing Kit (HR-EK)** pipeline: edit the
  scenario's squads / squad groups / AI data in Foundation + Sapien, write `.hsc`, recompile the
  map with Tool. There is no script-only path.
- There *is* one script↔map bridge (`hs_function_call`, §2) but it is **Multiplayer-engine only**,
  so it does not help a Firefight variant. It is the right answer if you are willing to rebuild the
  mode as a Megalo multiplayer gametype on a modded map.

---

## 1. Mechanism: which of the four candidate paths is real

| Path | Verdict |
|---|---|
| (a) A Megalo action that spawns an AI/squad with a character parameter | **Does not exist.** The complete Reach Megalo action table is 107 entries (`actions.cpp`, opcodes 0-106 in `DavidJCobb/ReachVariantEditor/native/src/ReachVariantTool/game_variants/components/megalo/actions.cpp`). The MCC additions are opcodes 99-106 only: `Run Inline Nested Trigger`, `hs_function_call`, `get_button_press_duration`, `set_vehicle_spawning_enabled` (team/player), `set_respawn_vehicle` (player/team), `set_hidden`. Nothing AI-related. |
| (b) Megalo creating an object from a Forge-placed "AI spawner" | **Not real.** Megalo `place_at_me`/object creation can spawn bipeds (Spartan/Elite/Monitor) — `actions.cpp` L452 notes "Once a Megalo-spawned Spartan biped is assigned to a player…" — but a Megalo-spawned biped has no AI brain; it is inert until a *player* is forced into it. No Forge object type is an AI squad spawner. |
| (c) Squads pre-placed in a modified `.map`, script toggling activation | **This is the real mechanism**, and it is the one stock Firefight itself uses. Squads live in the scenario tag; HaloScript places/activates them (`ai_place`, `ai_place_wave`, `ai_place_in_limbo` + `ai_exit_limbo`). |
| (d) Retargeting Firefight's own wave spawner to allied AI | **Map-side only, and inadvisable.** The variant stores only *indices* into map-baked wave templates (`m_squads: StaticArray<u8,12>` per wave, `game_engine_survival.rs` L166-171). The spawner call is `(ai_place_wave (survival_mode_get_wave_squad) ai_sur_wave_spawns s_sur_wave_squad_count)` — `global_firefight.hsc` L588-592. You would have to edit those wave templates in the map, and the wave-end logic counts everything in `gr_survival_all` / `gr_survival_remaining` (L665-674), so allied AI placed through that path would prevent waves from ever ending. Use a separate squad group instead. |

### The actual spawn API (HaloScript, in the map)

All signatures and descriptions quoted from the official engine dump
`Sigmmma/c20`, `src/data/hs_docs/hr/hs_doc.txt` (copied to `_raw/hsc/hsdoc_hr.txt`); line numbers
are that file's.

```
(<void> ai_place <ai>)                         ; L1277  "places the specified squad on the map."
(<void> ai_place <ai> <short>)                 ; L1280  "places the given number of members of the specified squad."
(<void> ai_place_in_limbo <ai>)                ; L1283  "places the specified squad on the map in limbo."
(<void> ai_place_in_limbo <ai> <short>)        ; L1286
(<void> ai_place_in_vehicle <ai> <ai>)         ; L1289  squad (1st) into the vehicles of a vehicle squad (2nd)
(<void> ai_place_wave <long> <ai>)             ; L1298  "Places the specified wave name into squads defined as part of the given squad group"
(<void> ai_place_wave <long> <ai> <short>)     ; L1301
(<void> ai_place_wave_in_limbo <long> <ai>)    ; L1304
(<void> ai_exit_limbo <ai>)                    ; L1448  "remove the given AI from limbo"
(<void> ai_erase <ai>)                         ; squad despawn
(<void> ai_erase_all)
(<void> ai_erase_inactive <ai> <short>)        ; L5150
(<void> ai_survival_cleanup <ai> <boolean> <boolean>) ; L5153 "Activate cure isolation death ... optionally delete inactive actors"
(<void> ai_renew <ai>)                         ; L1439 refresh health + grenades
(<short> ai_living_count <ai>)                 ; living members of squad / squad group
(<object_list> ai_actors <ai>)                 ; the actual unit objects
(<ai> ai_index_from_spawn_formation <ai> <string_id>) ; L1319
(<ai> ai_squad_group_get_squad <ai> <short>)
(<short> ai_squad_group_get_squad_count <ai>)
```

The `<ai>` type is a *scenario reference*: a squad name, a squad group name, or
`squad_name/starting_location_name` (stock example: `sq_sur_drop_01/driver`,
`ff20_courtyard.hsc` L518).

Parameters you set in the **scenario tag**, not from script (Gen3 `scnr` squad block, from
`Sigmmma/reclaimer`, `reclaimer/h3/defs/scnr.py` — Reach's block is the same family; verify exact
field names in Foundation):

- `squad`: `name`, `flags` (`blind`, `deaf`, `braindead`, `initially_placed`,
  `units_not_enterable_by_player`), **`team`**, `parent_squad_group_index`, `parent_zone`,
  `trigger_index`, `objective_index`, and a reflexive of cells (`base_squad`) — `scnr.py` L2555-2574.
- each cell: `character_type`, **`initial_primary_weapon`**, **`initial_secondary_weapon`**,
  `grenade_type`, `equipment`, `vehicle`, `vehicle_variant`, `command_script_name`,
  `initial_state`, and `starting_locations` — `scnr.py` L2530-2552.
- `team` enum values: `default, player, human, covenant, flood, sentinel, heretic, prophet, guilty`
  (`reclaimer/h3/enums.py` L191-208). Reach adds more; stock Reach Firefight script uses
  `player`, `human`, `covenant`, `covenant_player`, `brute`, `mule`
  (`global_firefight.hsc` L238-241, L991-995).

---

## 2. The only Megalo→map bridge: `hs_function_call` (Multiplayer engine only)

If you rebuild the mode as a **Megalo multiplayer variant on a modded map**, this is how script
reaches AI:

- Megalo action **opcode 100**, `game.hs_function_call(<function ID>)`.
  Argument type: `variant-string-id` (one argument, nothing else).
  Source: `actions.cpp` L1056-1065; docs:
  `docs/working - help docs/script/api/ns_game.xml`, `<method name="hs_function_call" id="100">`.
- RVT docs, verbatim: *"This function was added to the Halo: The Master Chief Collection build of
  Halo: Reach in mid-July 2023, being backported from Halo 4's Megalo engine. Gametypes that use
  this function will likely fail to load on Xbox 360 builds… This function allows you to invoke
  HaloScript functions defined and made available to Megalo on the current map. Maps can make
  HaloScript functions available by writing the function names into the `msit` tag."*
- `msit` = `megalo_string_id_table` (`Sigmmma/c20`, `src/content/hr/tags/megalo_string_id_table/readme.md`,
  `about: 'tag:hr/megalo_string_id_table'`).
- Officially confirmed by 343's own Reach-EK changelog (July 2023): *"Backported the following
  Megalo actions from H4: `hs_function_call`, `get_button_time`, `team_set_vehicle_spawning`,
  `player_set_vehicle_spawning`, `set_player_respawn_vehicle`, `set_team_respawn_vehicle`,
  `hide_object`."* — `Sigmmma/c20`, `src/content/hr/hr-ek/readme.md`.
- MegaloEdit-side usage (from `craftycodie/MegaloEvolved`,
  `packages/docs/language/actions/hs-function-call.md`): *"Calls a dormant HaloScript function that
  matches the argument's name (Reach MCC only). The function name needs to be in `strings.txt` to
  compile and in the `megalo_string_id_table` tag to function properly."* Plus the caution: *"It is
  unlikely that HaloScript will always sync properly, so it is recommended to put this in a local
  trigger."*

Worked pair (both halves required):

```hsc
; ---- in the MAP, e.g. data/levels/.../scripts/xxx_megalo_hooks.hsc
(script dormant void buy_marine_squad
  (ai_place sq_buy_marines_01)
)
```

```megalo
-- ---- in the MULTIPLAYER gametype script (MegaloEdit)
action hs_function_call buy_marine_squad
```

and `buy_marine_squad` must appear in the map's `megalo_string_id_table` (`msit`) tag.

**This does not work for a Firefight variant** (no Megalo in survival variants, §0). For Firefight,
put the purchase logic itself in HaloScript (§7).

---

## 3. Teams and allegiance — how marines fight *for* the player

Stock Firefight already allies the `human` AI team to the players. From the stock engine script,
`global_firefight.hsc`, inside `(script dormant survival_mode` (≈L232):

```hsc
; Set allegiances
(ai_allegiance human player)            ; L238
(ai_allegiance player human)            ; L239
(ai_allegiance covenant covenant_player); L240
(ai_allegiance covenant_player covenant); L241
```

So: **give your Marine/ODST squad `team = human` in the scenario and it is already friendly to the
Spartan team and hostile to `covenant`** — no extra script needed. (`ai_allegiance` is one-way per
call, hence the two calls per pair; `hsdoc_hr.txt` L1391 "creates an allegiance between two teams".)

Other team controls:

| Function | hsdoc line | Use |
|---|---|---|
| `(ai_set_team <ai> <team>)` | L1460 "makes an encounter change to a new team" | flip a live squad's team (this is the Sentinel-hack primitive) |
| `(ai_object_set_team <object> <team>)` | L1559 "flag an object as being owned by a certain team" | used by stock FF on generators: `(ai_object_set_team obj_sur_generator0 player)` — `global_firefight.hsc` L1728 |
| `(ai_allegiance_remove <team> <team>)` / `(ai_allegiance_break <team> <team>)` | — | revoke an alliance (expiry of a timed hack) |
| `(mp_ai_allegiance <team> <mp_team>)` | L4706 "causes an allegiance to be formed between an AI squad team and a multiplayer team" | AI vs. *multiplayer* teams (red/blue). Real Bungie usage: `(mp_ai_allegiance sentinel mp_team_red)` in `digsite/h3` `data/digsite/levels/multi/shaft/scripts/shaft_main.hsc` L20-24 |
| `(ai_prefer_target_team <ai> <team>)`, `(ai_set_targeting_group <ai> <short>)`, `(ai_disregard <object_list> <boolean>)` | — | fine-tune who they shoot |
| `(ai_magically_see <ai> <ai>)` | L1364 | make the new squad instantly aware of the current wave so they engage immediately |

---

## 4. Practical limits

**Hard engine actor-pool constant: not publicly documented for Reach. UNPROVEN.** I found no
published value (searched `ChimpsAtSea/Reach` RE project, TagTool, Blam-Network, c20 — the only
`MAXIMUM_ACTORS` constants on GitHub are Halo 1 decompilations, which do not transfer). Do not quote
a number. What *is* documented:

- **Firefight spawns 6 squads per wave, always.** `(global short k_sur_squad_per_wave_limit 6)`
  (`global_firefight.hsc` L63), and per-map `(set s_sur_wave_squad_count 6)`
  (`ff20_courtyard.hsc` L100). RVT: *"The game engine will always spawn only six squads (all of the
  same type) on the map per wave"* (`editor/main_window_ff/round.xml`). Squad size is baked in the
  map's wave templates (Grunt squads = 4 members, Hunter/Chieftain squads = 1, etc.), so a wave is
  roughly 6-24 actors.
- **Dropships cap at 2** concurrently: `(global short k_phantom_spawn_limit 2)`
  (`global_firefight.hsc` L120).
- **Hazard drop pods cap at 1-2 by player count** — Bungie's own throttle, worth copying:
  ```hsc
  (cond ((<= (game_coop_player_count) 4) (set g_sur_drop_limit 1))
        ((>= (game_coop_player_count) 5) (set g_sur_drop_limit 2)))
  ```
  (`ff20_courtyard.hsc` L466-472).
- **Over-budget behaviour:** the engine does not error; extra actors simply fail to spawn or are
  culled. Stock FF actively culls: `(ai_survival_cleanup gr_survival_all TRUE TRUE)` for the
  three survival squad groups (`global_firefight.hsc` L680-682 and L748-750) plus
  `(ai_erase_inactive …)`. `(ai_lod_full_detail_actors <short>)` limits how many actors get full-detail
  LOD, which is the main CPU cost.
- **Is the budget shared with the Covenant wave budget?** The *script* budget is not shared as long
  as you keep friendly squads out of the survival squad groups. Wave-end is computed as:
  ```hsc
  (script static short survival_wave_living_count            ; L665
    (+ (ai_living_count gr_survival_all)
       (ai_living_count gr_survival_remaining)
       (max 0 (- (ai_living_count ai_sur_phantom_01) s_sur_dropship_crew_count))
       …))                                                   ; L665-674
  (script static void survival_wave_end_conditions           ; L676
    (sleep_until (< (survival_wave_living_count) 7)) …)
  ```
  → Friendly squads **must** live in their own squad group (e.g. `gr_unsc_reinforcements`), never in
  `gr_survival_all` / `gr_survival_waves` / `gr_survival_remaining`, or every wave will hang waiting
  for your own marines to die. The *engine's* actor pool is of course shared, so expect enemy spawn
  failures if you flood the map — budget friendly AI conservatively (recommendation: ≤2 squads /
  ~8 actors alive at a time, with a timed `ai_erase`), and verify in-game.

Unrelated but worth knowing if you also write Megalo: Megalo's scripted-object data pool is **512
objects (256 on Xbox 360)**, silently failing past that
(`docs/working - help docs/script/scripted-object-count-limit.xml`).

---

## 5. Loadout control (DMR / rocket launcher / shotgun)

Three real mechanisms, in order of preference:

1. **Scenario squad cells** — `initial_primary_weapon`, `initial_secondary_weapon`, `grenade_type`,
   `equipment` per cell (`scnr.py` L2530-2552). This is how you make "marine squad with DMRs" vs.
   "marine squad with rocket launchers": author one squad per loadout and `ai_place` the one the
   player bought. Most reliable; no runtime scripting.
2. **`(unit_add_equipment <unit> <starting_profile> <boolean> <boolean>)`** — hsdoc L1097:
   *"adds/resets the unit's health, shield, and inventory (weapons and grenades) to the named
   profile. resets if third parameter is true, adds if false. weapons will be marked as garbage if
   fourth parameter is true."* Works on any unit, so you can re-arm a spawned marine at runtime from
   a `starting_profile` defined in the map's globals. Apply over the squad's units via `ai_actors`.
3. **`(mantini_set_spawn_point_weapons <ai> <string> <string>)`** — hsdoc L998; also
   `mantini_set_spawn_point_vehicle`, `mantini_set_spawn_point_variants`,
   `mantini_create_runtime_squad`, `mantini_add_cell_to_runtime_squad`,
   `mantini_set_squad_team`, `mantini_set_squad_cell_spawn_count` (hsdoc L980-1006). These are
   Bungie's runtime squad-authoring helpers and they take string names. They look like exactly the
   "build a squad from script" API — **but they are dev/editor-era functions and I could not find a
   single shipped script that uses them. Treat as UNPROVEN until tested in Standalone/Sapien.**
   If they work in retail MCC they would allow runtime-defined squads (still inside the map, still
   not from a gametype).

### ODSTs arriving by drop pod — stock Reach already does this

`ff20_courtyard.hsc` L511-545 is Bungie's drop-pod arrival, verbatim (it drops Covenant; swap the
squad and the pod device for the UNSC/HEV equivalents):

```hsc
(script continuous drop_pod_01
  (sleep_forever)
  (sleep (random_range 5 15))
  (object_create dm_drop_01)                                   ; the pod (a device/machine)
  (ai_place sq_sur_drop_01)                                    ; the squad, placed in its pod seats
  (sleep 1)
  (set v_sur_drop_01 (ai_vehicle_get_from_spawn_point sq_sur_drop_01/driver))
  (sleep 1)
  (objects_attach dm_drop_01 "" v_sur_drop_01 "")              ; attach pod geometry to the vehicle
  (sleep 1)
  (device_set_position dm_drop_01 1)                           ; animate the pod down
  (sleep_until (>= (device_get_position dm_drop_01) 0.85) 1)
  (wake drop_blip_01)
  (unit_open v_sur_drop_01)                                    ; pop the hatch
  (sleep 30)
  (vehicle_unload v_sur_drop_01 "")                            ; kick the AI out
  (sleep_until (>= (device_get_position dm_drop_01) 0.98) 1)
  (effect_new_on_object_marker fx\fx_library\pod_impacts\default\pod_impact_default_large.effect dm_drop_01 "fx_impact")
  (sleep_until (>= (device_get_position dm_drop_01) 1) 1)
  (sleep 1)
  (objects_detach dm_drop_01 v_sur_drop_01)
  (object_destroy dm_drop_01)
)
```

So "ODSTs arrive by drop pod" = a pod device + a squad whose cells have `vehicle` = the pod +
`ai_place` + `vehicle_unload`. All map-side. (RVT also notes stock FF Hazards include "Drop Pods
filled with Brutes… Grunts… or Elite Ultras" — `editor/main_window_ff/scenario.xml`.)

---

## 6. Steering behaviour

| Goal | API | Notes |
|---|---|---|
| Follow the player | `(ai_player_add_fireteam_squad <unit> <ai>)` (hsdoc L1847 "Adds the given squad to the given player's fire team"), `(ai_player_set_fireteam_max <unit> <short>)`, `(ai_player_set_fireteam_max_squad_absorb_distance <unit> <real>)`, `(ai_set_fireteam_absorber <ai> <boolean>)`, `(ai_set_fireteam_fallback_squad <unit> <ai>)`, `(ai_player_remove_fireteam_squad …)`, `(ai_is_in_fireteam <ai>)` | **Firefight already wires this up** for Elite players: `global_firefight.hsc` L2715-2751 (6 players × 5 calls). Copy that block for Spartans with your reinforcement squads. This is the single best "bodyguard squad" mechanism. |
| Hold / defend a position | Scenario **tasks + objectives**, driven by `(ai_set_objective <ai> <string_id>)` (hsdoc L1508 "Sets the squad's current objective"), `(ai_set_task <ai> <string_id> <string_id>)` L1505, `(ai_set_task_condition …)`, `(ai_task_status <ai>)`, `(ai_reset_objective <ai>)` (stock: `(ai_reset_objective ai_obj_survival)`, `global_firefight.hsc` L586) | The task/objective tree itself is **baked in the scenario AI data** (zones/areas/firing positions). Script only selects among them. |
| Explicit movement orders | Command scripts: `(cs_run_command_script <ai> <ai_command_script>)` L1871, `cs_queue_command_script`, `cs_stack_command_script`, then inside the command script `cs_go_to`, `cs_go_to_and_posture`, `cs_move_towards`, `cs_fly_to`, `cs_abort_on_damage/alert/combat_status`, `cs_use_equipment` | Command scripts are authored in the map (`.hsc` `(script command_script …)`), referenced by name from the squad cell (`command_script_name`) or at runtime. |
| Man a vehicle seat / turret | `(ai_vehicle_enter <ai> <unit> <unit_seat_mapping>)` L1613 ("in the substring-specified seats (e.g. passenger for pelican)"), `(ai_vehicle_enter_immediate …)`, `(ai_vehicle_exit …)`, `(ai_enter_squad_vehicles <ai>)`, `(ai_place_in_vehicle <ai> <ai>)` L1289, `(vehicle_load_magic <object> <unit_seat_mapping> <object_list>)` L1025 ("makes a list of units… magically get into a vehicle… empty string matches all seats"), `(ai_get_turret_ai <ai> <short>)`, `(ai_vehicle_reserve_seat <vehicle> <unit_seat_mapping> <boolean>)` | `ai_vehicle_reserve_seat` is how you keep the Falcon's gunner seat free for the player. |
| Combat tuning | `(ai_set_blind/_deaf …)`, `(ai_braindead …)`, `(ai_cannot_die <ai> <boolean>)`, `(ai_disposable …)`, `(ai_suppress_combat …)`, `(ai_set_combat_status <ai> <short>)`, `(ai_renew <ai>)`, `(ai_force_active <ai> <boolean>)`, `(ai_allow_dormant <ai> <boolean>)` | `ai_cannot_die` + `ai_renew` make a purchased squad feel premium without being immortal to script. |

---

## 7. Worked, copy-pasteable example (HaloScript, in the modded map)

Economy note: Firefight score is readable/awardable from HS —
`(survival_increment_human_score <player>)` (hsdoc), `survival_mode_get_bonus_target`,
`survival_mode_lives_get/set`, plus the generic `(player_get_score)` family. Spend-tracking below
uses a plain global; wire the trigger to whatever purchase UI you build (device/switch object,
`chud_` message, etc.).

```hsc
; =====================================================================================
;  UNSC reinforcements — purchasable friendly squads
;  Scenario prerequisites (author these in Foundation/Sapien, they are NOT scriptable):
;    squad group : gr_unsc_reinforcements        <- NOT inside gr_survival_all / _waves / _remaining
;    squad       : sq_marines_dmr        team=human  cells: character=<marine>, initial_primary_weapon=<DMR>
;    squad       : sq_marines_rocket     team=human  cells: character=<marine>, initial_primary_weapon=<rocket launcher>
;    squad       : sq_odst_shotgun       team=human  cells: character=<ODST>,   initial_primary_weapon=<shotgun>,
;                                                     vehicle=<HEV drop pod>, seat_type=<pod seat>
;    starting locations for each squad, inside a zone with firing positions
;    device/machine: dm_odst_pod_01  (the drop pod animation)
;    objective/task tree entry: obj_defend_base (for the hold-position variant)
; =====================================================================================

(global short g_unsc_squads_alive 0)
(global short g_unsc_squad_limit  2)      ; keep the actor budget sane; see section 4
(global ai    ai_unsc_group gr_unsc_reinforcements)

; ---------- shared helper: stand a squad up, make it useful, bill it ----------------
(script static void (f_unsc_reinforce_common (ai squad) (unit buyer))
  (sleep 1)
  ; friendly: team=human is already allied to `player` by global_firefight.hsc L238-241.
  ; belt-and-braces if you changed teams at runtime:
  (ai_set_team squad human)
  ; make them engage the live wave immediately instead of idling
  (ai_magically_see squad gr_survival_all)
  ; full health/grenades on arrival
  (ai_renew squad)
  ; follow the buyer (same mechanism stock FF uses for Elite players, L2715-2751)
  (ai_set_fireteam_absorber squad 1)
  (ai_player_add_fireteam_squad buyer squad)
  (ai_player_set_fireteam_max buyer 4)
  (ai_player_set_fireteam_max_squad_absorb_distance buyer 3.0)
  (set g_unsc_squads_alive (+ g_unsc_squads_alive 1))
)

; ---------- 1) MARINE SQUAD (walk-on, DMRs) ----------------------------------------
(script static void (f_buy_marines_dmr (unit buyer))
  (if (< g_unsc_squads_alive g_unsc_squad_limit)
    (begin
      (ai_place sq_marines_dmr)                 ; hsdoc L1277
      (f_unsc_reinforce_common sq_marines_dmr buyer)
      ; optional: hold a position instead of following —
      ;   (ai_player_remove_fireteam_squad buyer sq_marines_dmr)
      ;   (ai_set_objective sq_marines_dmr obj_defend_base)     ; hsdoc L1508
      (wake unsc_marines_dmr_expiry)
    )
  )
)

; timed expiry so the actor budget recovers (one round ~= 5 waves)
(script dormant unsc_marines_dmr_expiry
  (sleep_until (or (<= (ai_living_count sq_marines_dmr) 0)
                   (survival_mode_current_wave_is_boss)) 30)
  (ai_erase sq_marines_dmr)                    ; despawn survivors
  (set g_unsc_squads_alive (max 0 (- g_unsc_squads_alive 1)))
)

; ---------- 2) ODST SQUAD, ARRIVES BY DROP POD -------------------------------------
;  Structure copied from Bungie's stock Firefight hazard pods: ff20_courtyard.hsc L511-545
(script static void (f_buy_odst_pod (unit buyer))
  (if (< g_unsc_squads_alive g_unsc_squad_limit)
    (begin
      (object_create dm_odst_pod_01)                                   ; the pod
      (ai_place sq_odst_shotgun)                                       ; ODSTs spawn inside it
      (sleep 1)
      (set v_odst_pod_01 (ai_vehicle_get_from_spawn_point sq_odst_shotgun/driver))
      (sleep 1)
      (objects_attach dm_odst_pod_01 "" v_odst_pod_01 "")
      (sleep 1)
      (device_set_position dm_odst_pod_01 1)                           ; drop it
      (sleep_until (>= (device_get_position dm_odst_pod_01) 0.85) 1)
      (unit_open v_odst_pod_01)                                        ; hatch
      (sleep 15)
      (vehicle_unload v_odst_pod_01 "")                                ; deploy
      (sleep_until (>= (device_get_position dm_odst_pod_01) 0.98) 1)
      (effect_new_on_object_marker fx\fx_library\pod_impacts\default\pod_impact_default_large.effect dm_odst_pod_01 "fx_impact")
      (sleep_until (>= (device_get_position dm_odst_pod_01) 1) 1)
      (sleep 1)
      (objects_detach dm_odst_pod_01 v_odst_pod_01)
      (object_destroy dm_odst_pod_01)
      (f_unsc_reinforce_common sq_odst_shotgun buyer)
    )
  )
)

; ---------- 3) re-arm individual units at runtime (loadout swap) -------------------
;  There is NO plural units_add_equipment in Reach. Only the single-unit form exists:
;    (unit_add_equipment <unit> <starting_profile> <boolean> <boolean>)   ; hsdoc L1097
;  HaloScript has no loops, so unroll over the squad's actors:
(script static void (f_arm_squad_rockets (ai squad))
  (if (> (list_count (ai_actors squad)) 0)
    (unit_add_equipment (unit (list_get (ai_actors squad) 0)) sp_marine_rocket TRUE FALSE))
  (if (> (list_count (ai_actors squad)) 1)
    (unit_add_equipment (unit (list_get (ai_actors squad) 1)) sp_marine_rocket TRUE FALSE))
  (if (> (list_count (ai_actors squad)) 2)
    (unit_add_equipment (unit (list_get (ai_actors squad) 2)) sp_marine_rocket TRUE FALSE))
  (if (> (list_count (ai_actors squad)) 3)
    (unit_add_equipment (unit (list_get (ai_actors squad) 3)) sp_marine_rocket TRUE FALSE))
)
```

Notes on that snippet: `(list_get <object_list> <short>)` is hsdoc L234, `(list_count …)` L237.
Verified absent from Reach's function table: `units_add_equipment` (the plural forms that *do*
exist are `units_set_maximum_vitality` L1016 and `units_set_current_vitality` L1022, used by stock
FF at `ff20_courtyard.hsc` L443-444). HaloScript has no looping constructs by design
(c20, `hr/engine/scripting`), hence the unrolled `if`s. Prefer method 1 (one squad per loadout,
authored in the scenario) and this whole script becomes unnecessary.

---

## 8. The companion purchases (how each is really built)

| Purchase | Mechanism | Citation |
|---|---|---|
| **Auto turret** | A `machinegun`/`shade` vehicle object placed via `object_create` (or a scenario object `object_create_anew`) + a 1-cell AI squad put in the gunner seat with `(ai_place_in_vehicle <squad> <vehicle squad>)` or `(vehicle_load_magic <turret> "" (ai_actors sq_gunner))`; set its team with `ai_object_set_team`/squad `team=human`. Targeting knobs: `ai_object_set_targeting_bias`, `ai_object_set_targeting_ranges`, `ai_object_enable_targeting_from_vehicle`. | hsdoc L1025, L1289, L1559, L1562-1566 region (`ai_object_*`) |
| **Falcon gunner ride** | Falcon spawned as a scenario/created object; AI pilot squad via `ai_place_in_vehicle`; player gets the gunner seat — reserve it with `(ai_vehicle_reserve_seat <vehicle> <seat> TRUE)` so AI won't take it, and drive the flight path with a command script (`cs_fly_to`, `cs_fly_to_and_face`, `cs_attach_to_spline`). | hsdoc L1613-1617, `ai_vehicle_reserve_seat`, `cs_fly_*` L1152-1202 |
| **Scorpion / rocket Warthog → Gauss upgrade** | Plain object spawning — `(object_create <object_name>)` (hsdoc L291) / `(object_create_anew …)` (L300) of pre-placed scenario objects; the "upgrade" is destroying one and creating the other variant, `(object_create_variant <object_name> <string_id>)` (L294). No AI needed. | hsdoc L291, L294, L300 |
| **MAC cannon strike** | No AI: a scripted effect + area damage. `(effect_new_at_ai_point <effect> <point_reference>)` (hsdoc L252), `effect_new_on_object_marker`, `(damage_objects_effect <damage> <object_list>)` (L276), plus `survival_mode_*` for the win condition. Reach also has an `airstrike` tag (`Sigmmma/c20`, `src/content/hr/tags/airstrike/readme.md`), the engine's scripted-bombardment tag. | hsdoc L252, L276; c20 `hr/tags/airstrike` |
| **Sentinel hack (temporary)** | `(ai_set_team <sentinel squad> human)` or `(ai_allegiance sentinel player)` + `(ai_allegiance player sentinel)`, reverted with `ai_allegiance_remove`/`ai_allegiance_break` after a timer. In multiplayer the canonical call is `(mp_ai_allegiance sentinel mp_team_red)` — Bungie's own usage in the H3 digsite map `shaft`. | hsdoc L1460, L1391-1397, L4706; `digsite/h3` `shaft_main.hsc` L20-24 |

Installation 04's Sentinels in the mod are consistent with this: the description says the Sentinels
are placed on the map and can be hacked "to be on your side for a round" — i.e. a team/allegiance
flip on an already-placed squad, which is exactly what `ai_set_team` / `mp_ai_allegiance` do.

---

## 9. Real working examples (links, all verified fetchable)

1. **Stock Reach Firefight engine script — the single most valuable reference.**
   `data/globals/global_firefight.hsc` (114,213 bytes) from a leaked MCC Reach tag/data set:
   https://github.com/Gamecheat13/RawGames/tree/main/Halo%20Reach/Windows%20-%20MCC%20Oct%2024%202019/data/globals
   Local copy: `_raw/hsc/global_firefight.hsc`. Contains the allegiance setup (L238-241), the wave
   spawner (L588-592), limbo/dropship loading (L1380-1480), wave-end accounting (L665-690), and the
   complete fireteam-follow block (L2715-2751).
2. **Stock Reach Firefight map script with drop pods and per-map config** —
   `data/levels/firefight/ff20_courtyard/scripts/ff20_courtyard.hsc` (same repo). Local copy:
   `_raw/hsc/ff20_courtyard.hsc`. Pod scripts L460-660; FF init L88-155.
3. **Stock Reach Corvette Firefight script** — `ff45_corvette/scripts/ff45_corvette_main.hsc`
   (same repo). Local copy: `_raw/hsc/ff45_corvette_main.hsc`. Relevant because the mod ships a
   Corvette variant.
4. **Official Reach HaloScript function dump with descriptions** (what I cited throughout):
   https://github.com/Sigmmma/c20/blob/master/src/data/hs_docs/hr/hs_doc.txt
   Local copy: `_raw/hsc/hsdoc_hr.txt`. Community-maintained markdown mirror:
   https://github.com/Burnt-o/HaloCheckpointManager/blob/master/HaloScript%20Docs/HaloReach.md
5. **Bungie multiplayer map that puts AI on a player team** (the sentinel-hack pattern):
   https://github.com/digsite/h3/blob/master/data/digsite/levels/multi/shaft/scripts/shaft_main.hsc
6. **Megalo reference / opcode tables**: https://github.com/DavidJCobb/ReachVariantEditor
   (`native/src/ReachVariantTool/game_variants/components/megalo/actions.cpp`,
   `docs/working - help docs/script/api/ns_game.xml`).
   Rendered docs mirror: https://github.com/Sopitive/MegaloDocs
7. **Modern cross-platform Megalo toolchain (TypeScript, runs on macOS)**:
   https://github.com/craftycodie/MegaloEvolved — compiler, decompiler, LSP, VS Code extension;
   docs include `hs_function_call`. Package name in-repo is `@megacrow/megalo` (the published
   `@blamnetwork/megalo` was not installable from the public registry on 2026-11-20).
8. **BLF/variant parser used for the byte-level proof in §0**: `@blamnetwork/blf` v1.2.0-alpha.5
   (https://github.com/Blam-Network/blf). Working invocation (CJS entry; the ESM entry has a broken
   directory import):
   ```js
   const blf = require("@blamnetwork/blf/dist-cjs/index.js");
   const v = require("@blamnetwork/blf/dist-cjs/versions/haloreach_mcc/v_untracked_25_08_16_1352.js");
   const mpvr = new v.s_blf_chunk_game_variant();
   blf.find_chunk(new Uint8Array(require("fs").readFileSync(file)), mpvr, "big");
   console.log(mpvr.game_variant.m_game_engine); // 4 = survival
   ```
9. **Official Reach Editing Kit notes** (confirms the July-2023 Megalo backports and MegaloEdit CLI):
   https://github.com/Sigmmma/c20/blob/master/src/content/hr/hr-ek/readme.md
   Reach HaloScript basics: https://c20.reclaimers.net/hr/engine/scripting/

**Not found:** no public Megalo script, `.mglo` sample, or GitHub repo that spawns friendly AI from a
gametype — consistent with it being impossible. Firefight Evolved / Halo Reach: Evolved is not
open-source; its `.map` files are only distributed inside the 7.3 GB Workshop item.

---

## 10. Reference-file facts (for the project record)

Both `../reference/*.bin` are 21,753 bytes with identical chunk layout:
`_blf` (48 B, v1) → `chdr` (704 B, v10) → `mpvr` (20,520 B, v54) → `_eof` (17 B) → `_fsm` (464 B).

| | Firefight Evolved.bin | Firefight Corvette Evolved.bin |
|---|---|---|
| engine | `survival` (4) | `survival` (4) |
| name | `FIREFIGHT EVOLVED` | `FIREFIGHT CORVETTE EVOLVED` |
| description | "Used with Halo: Reach Evolved Firefight. Use your Firefight Score to purchase bonuses." | (same family) |
| variant payload | 963 B | ~963 B |
| flags | hazards ✔, weapon drops ✔, ammo crates ✔, all-generators ✘, random generators ✘ | — |
| lives | shared team 8, elite 0, max 21 | — |
| generators | 0 (generator defense off) | — |
| rounds | R1 skulls 4, R2 skulls 12, R3 skulls 14; initial waves squad-type `19,19,19`; main waves e.g. `8,21,9,3,25`; boss waves e.g. `20,2,20`; bonus wave 90 s, `15,15,15` | — |
| megalo | **absent** | **absent** |

---

## 11. Recommendation

1. Deliver the **Firefight variant `.bin` layer** as scripts/config (waves, squad types, skulls,
   traits, lives). That is genuinely script-only and compiles with RVT/MegaloEvolved tooling.
2. For purchasable reinforcements, scope a **HR-EK map-mod pipeline**: per map, add a
   `gr_unsc_reinforcements` squad group + marine/ODST squads (`team = human`) + starting locations +
   pod devices, and a `.hsc` implementing the purchase economy on top of `survival_mode_*`. §7 is
   the template. Expect Foundation/Sapien/Tool on Windows; there is no macOS path for map building.
3. If the user will accept a non-Firefight engine, the **Megalo multiplayer variant + modded map +
   `game.hs_function_call`** architecture gives a far nicer scripting experience (real UI, real
   economy, per-player state) and still needs the map mod for the AI half.
