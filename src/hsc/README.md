# Firefight Evolved Expanded — map-side HaloScript pack

Purchasable Marine and ODST reinforcements for Halo: Reach Firefight, plus turrets, a Ghost,
one-shot airstrikes and a win purchase, across six stock map scenarios.

Every identifier in this pack is either grepped out of a shipped Bungie Firefight script
(`research/_raw/hsc/`), or is explicitly marked `[NEW]` as content you must author in Sapien, or is
marked `[G]` as an unproven use of a real function. There are no plausible-looking inventions left.

## 0. What this is and why it has to be a map mod

A Halo: Reach Firefight **game variant contains no Megalo script at all** — the variant payload is a
flat settings struct (waves, squad-type indices, skulls, traits, lives). That is established in
`research/02-mpvr-megalo-format.md` and `research/06-ai-squad-spawning.md` §0, byte-verified against
the two reference `.bin` files. So all AI logic lives in HaloScript compiled into a modified `.map`
with the **Halo Reach Editing Kit** (HR-EK: Foundation, Sapien, Standalone, Tool). HR-EK is Windows
only and free on Steam. There is no macOS path for map building.

### Files in this folder

Files and startup scripts are named for the **scenario tag**, not the menu map name, because the tag
name is what the engine, the `.map` and Bungie's own scripts use. `(script startup ff50_park ...)`,
never `beachhead`.

| File | Tag name | Map name | Win condition |
|---|---|---|---|
| `fe_reinforcements.hsc` | — | — | Reusable core. Compiled **first**. |
| `ff50_park.hsc` | `ff50_park` | Beachhead | Pelican dust-off + 120 s roof hold |
| `ff10_prototype.hsc` | `ff10_prototype` | Overlook | Relay uplink + 150 s hold |
| `ff60_airview.hsc` | `ff60_airview` | Outpost | Firing solution + 3 Phantoms in 90 s (60 s if repaired) |
| `ff70_holdout.hsc` | `ff70_holdout` | Holdout | Launch clearance + 120 s helipad hold |
| `ff60_icecave.hsc` | `ff60_icecave` | Glacier | Demolition charges + 180 s survival |
| `ff30_waterfront.hsc` | `ff30_waterfront` | Waterfront | Station scram + 120 s pump hold |

Bungie's own scripts for these maps are on disk for cross-checking: `ff50_park_main.hsc`,
`ff10_prototype.hsc`, `ff60_airview.hsc`, `ff70_holdout.hsc`, `ff60_icecave.hsc`,
`ff30_waterfront.hsc`, plus `ff20_courtyard.hsc` as the dissected template, `global_firefight.hsc`
(the shared engine contract), `cex_ff_halo_main.hsc` (Installation 04 — the friendly-Marine
reference) and `hsdoc_hr.txt` (the 9,054-line function dump).

Marines (**500**) and ODSTs (**750**) are the two cheapest entries on all six boards and are always
re-buyable, as required by the economy in `research/05-map-scenario-designs.md` §4. Those are the
author's own post-playtest prices against a **measured** income of ~2,000-2,500 points a round, so a
squad is affordable every round and usually twice. The win purchase is **8,000** (≈ 4 rounds) behind a
round-5 gate. All prices are named globals at the top of `fe_reinforcements.hsc`, so retuning the
whole pack is one edit per line — and they can be changed live from the Sapien/Standalone console,
e.g. `(set k_fe_cost_marines 400)`. **Read §2j before changing any of them.**

### Startup-script collision — read before you compile anything

Each stock map script already declares a startup script with the tag name, e.g.
`(script startup ff50_park ...)` at `ff50_park_main.hsc` L109. A scenario cannot hold two startup
scripts with the same name. Each file in this pack carries a `PASTE MARKER: START OF FE ADDITIONS`
block of about ten lines. **Preferred: delete our `(script startup ...)` declaration and paste the
marked body just before the stock startup's closing paren.** The alternative — removing the stock
declaration and keeping ours — means you must also copy the whole stock configuration block
(allegiances, zone set, phantom squads and unload sides, `gr_survival_waves`, the twelve generator
objects, `k_sur_wave_timer`, the `survival_*` wakes) into it, or the map will not run Firefight.
Each per-map header gives the exact stock line range to copy for that map.

## 1. The rule that breaks everything if you get it wrong

Firefight decides a wave has ended by counting what is alive in its own squad groups:

```
(script static short survival_wave_living_count            ; global_firefight.hsc L665-674
  (+ (ai_living_count gr_survival_all)
     (ai_living_count gr_survival_remaining)
     ... dropship crews ...))
```

Your friendly squads **must** sit in their own squad group, `gr_unsc_reinforcements`, and that group
must be a child of **nothing**. If a Marine is inside `gr_survival_all`, `gr_survival_waves`,
`gr_survival_bonus` or `gr_survival_remaining`, `survival_wave_living_count` never drops and **waves
stop ending**.

### 1a. THE TRAP: do not park friendlies in `gr_survival_extras`

Bungie's own Firefight authoring checklist parents friendly marines as
`gr_survival_marines → gr_survival_extras`. **Do not copy that.** `gr_survival_extras` is not in
`survival_wave_living_count`, so it will not stall waves — but:

* On **Overlook, Waterfront and Courtyard** the Covenant drop-pod spawner waits for that group to
  reach zero, twice per burst:

  | Map | Pre-spawn gate | Post-burst gate |
  |---|---|---|
  | `ff10_prototype.hsc` | L507 | L529 |
  | `ff30_waterfront.hsc` | L534 | L556 |
  | `ff20_courtyard.hsc` | L481 | L501 |

  All three wake that spawner from their startup. **A single living friendly marine parented under
  `gr_survival_extras` therefore suppresses Covenant drop pods for the rest of the match**, silently,
  with no error. Waterfront has five pod sites; Overlook has five. This is the worst failure mode in
  the pack and it looks like nothing is wrong.
* `gr_survival_extras` is culled every wave: `survival_wave_end_conditions` calls
  `(ai_survival_cleanup gr_survival_extras TRUE TRUE)`, which per `hsdoc_hr.txt` L5153 enables "cure
  isolation death" and deletes inactive actors. Friendlies in it get garbage-collected as soon as
  they are separated from the fight.
* Two more groups to stay out of: `gr_survival_snipers` gates `survival_sniper_spawn` on
  **Outpost** (L748), **Holdout** (L784) and **Waterfront** (L495); `ai_sur_bonus_wave` /
  `ai_sur_bonus_phantom` feed `survival_mode_bonus_living_count` (globals L1066-1072).

Every per-map file repeats this warning at its parenting site. The hazard squads this pack places
(`sq_sur_wraith_01`, `sq_sur_ghost_01` and friends) are **stock squads already parented by Bungie** —
do not reparent them.

## 2. Scenario content to author in Sapien

These are **scenario tag** fields, not script. Character type, initial primary weapon and vehicle are
per-cell squad fields (`research/06` §1, Gen3 `scnr` squad block); nothing in HaloScript can set them
at placement time. Create one squad per loadout rather than re-arming at runtime.

### 2a. Squad-level fields

| Field | `sq_fe_garrison` (free) | `sq_fe_marines` (bought) | `sq_fe_odst` (bought) |
|---|---|---|---|
| name | `sq_fe_garrison` | `sq_fe_marines` | `sq_fe_odst` |
| team | `human` | `human` | `human` |
| parent squad group | `gr_unsc_reinforcements` | `gr_unsc_reinforcements` | `gr_unsc_followers` |
| parent zone | the zone containing your stronghold | same | same |
| objective index | the index of `obj_marines` (see §2d) | same | same |
| **number of cells** | **6** | **8** | **8** |
| flags: `initially placed` | **off** (script places it on round start) | **off** (script places it on purchase) | **off** |
| flags: `units not enterable by player` | on | on | on |
| flags: blind / deaf / braindead | off | off | off |

`sq_fe_garrison` is new in this revision. It is the **free** 6-man squad that arrives at match start
and is topped back up to 6 at the start of every round. It has to be a separate scenario squad from the
bought ones for one reason only: **cell capacity is a tag field and no script can change it**, so a
6-man free squad and an 8-man bought squad cannot share a squad. It is also the one friendly squad that
must never be retired by `k_fe_squad_lifetime`, which is the second reason to keep it distinct.

Note the deliberate absence of `_sur_` from these names. `_sur_` marks membership of the survival
squad-group tree, which is the one thing a friendly squad must stay out of. `fe_` is our namespace.

### 2b0. The exact Sapien field to type the squad size into, and the values

**This is the one piece of this feature that is not script, and nothing works until you enter it.**

Squad size is a **count of cells in the scenario tag's squad block**. The engine's own name for the
per-cell field is visible in the Mantini authoring API in the official function dump:

```
(<boolean> mantini_set_squad_cell_spawn_count <string> <long> <long>)    hsdoc_hr.txt L1727
; "Set cell spawn count. Arg: <squad name> <cell index> <spawn count>"
```

So in Foundation / Sapien: open the scenario, go to the **`squads`** block, select the squad, open its
**`cells`** block, and the per-cell field is **`spawn count`**. Enter:

| Squad | Cells to create | `spawn count` per cell | Resulting capacity | Who places it |
|---|---|---|---|---|
| `sq_fe_garrison` | **6** | **1** | **6** | `fe_garrison_watch`, free, round start |
| `sq_fe_marines` | **8** | **1** | **8** | `*_buy_marines`, 500 points |
| `sq_fe_odst` | **8** | **1** | **8** | `*_buy_odst`, 750 points |
| `sq_fe_sniper_01` (Waterfront) | 2 | 1 | 2 | `wf_buy_snipers`, 1,000 points |
| `sq_fe_gunner` | 1 | 1 | 1 | turret purchase |

**Use one cell per body with `spawn count` 1 — do not use one cell with `spawn count` 6 or 8.** Both
give the same head count, but only the per-cell form lets you give each body its own
`initial primary weapon` and its own `starting location`, which is how §2b and §2c below are built and
the only way to get one rocket launcher in a squad of eight rather than eight of them.

Two things are deliberately **not** scriptable here, so do not go looking for a function:

- `mantini_*` is Sapien's in-editor AI authoring tool. No shipped script calls any `mantini_` function.
  It is cited above **for the field name only**; do not try to resize a squad from script in a retail
  build. **[G]**
- The script asks for a size with `k_fe_free_squad_size` (6) and `k_fe_buy_squad_size` (8), and the
  two-argument `(ai_place <ai> <short>)` form trims the ask to whatever the concurrent cap has left
  (`hsdoc_hr.txt` L1280, *"places the given number of members of the specified squad"*). The ask can
  never exceed the capacity you type in above. If you author 4 cells and ask for 8, you get 4.

### 2b1. The concurrent-alive cap, and the per-map values

The spec is "8 purchasable every wave". A Reach Firefight round is **5 waves** —
`k_sur_wave_per_round_limit 5`, `global_firefight.hsc` L75 — so granted literally that is 40 bought
friendlies per round on top of the free 6, which is more actors than stock Firefight ever puts on these
maps for both sides combined. The engine does not error on that; enemies just silently stop arriving,
and because wave end is `(sleep_until (< (survival_wave_living_count) 7))`
(`global_firefight.hsc` L678) a wave whose squads never spawned also never clears on schedule.

So the **purchase is available every wave, and the living total is capped**. Deaths and expiry free
slots on the same tick, because the slot count is computed from `(ai_living_count ai_fe_group)` every
time it is read and never from a purchase counter. Full reasoning, with citations and the explicit
"derived, not an engine constant" label, is in `fe_reinforcements.hsc` §2.1–2.4.

| Map | Script | Free garrison | Concurrent cap | Why not the default 12 |
|---|---|---|---|---|
| Beachhead | `ff50_park.hsc` | 6 | **12** | — three authored `ps_gen/genN` anchors to spread over |
| Overlook | `ff10_prototype.hsc` | 6 | **12** | — open valley, no interior chokepoint |
| Waterfront | `ff30_waterfront.hsc` | 6 | **10** | densest hostile geometry of the six: 5 pods + 4 Phantom lanes + 4 snipers + 2 Banshees |
| Glacier | `ff60_icecave.hsc` | 6 | **8** | underground, one sheltered volume (`tv_wraith`), jagged ground, 180 s final hold with two Wraiths |
| Holdout | `ff70_holdout.hsc` | 4 | **8** | ramps and multi-level: the only map where Bungie authored `cs_enable_pathfinding_failsafe TRUE` |
| Outpost | `ff60_airview.hsc` | 4 | **6** | the Deck is one small platform; `research/05` §5.3 says cap at 4 and deny a roof turret |

Consequence to expect in play: 6 free + 8 bought = 14, which is above every cap in the table. **A
purchase made while the garrison is at full strength delivers a partial squad**, and the full 8 lands
once the garrison has taken casualties — seconds, under contact. That is the intended loop. On Outpost
the full 8 never lands at all, by design.

### 2b. `sq_fe_garrison` cells — the free 6-man squad

Six cells, `spawn count` 1 each. Deliberately the plainest loadout in the pack: this squad is free and
arrives every round, so it must not out-gun the one the player pays for.

| Cell | Character type | Initial primary weapon | Initial secondary | Grenades | Vehicle | Starting location |
|---|---|---|---|---|---|---|
| 0 (leader) | Marine (`characters\marine\marine.character` [G]) | DMR (`objects\weapons\rifle\dmr\dmr.weapon` [G]) | Magnum [G] | frag ×2 | — | `fe_garrison_sp_0` |
| 1 | Marine | Assault Rifle (`...\assault_rifle\assault_rifle.weapon` [G]) | — | frag ×2 | — | `fe_garrison_sp_1` |
| 2 | Marine | Assault Rifle | — | frag ×1 | — | `fe_garrison_sp_2` |
| 3 | Marine | Assault Rifle | — | frag ×1 | — | `fe_garrison_sp_3` |
| 4 | Marine | DMR [G] | — | frag ×1 | — | `fe_garrison_sp_4` |
| 5 | Marine | Shotgun (`...\shotgun\shotgun.weapon` [G]) | — | frag ×1 | — | `fe_garrison_sp_5` |

No heavy weapon anywhere in this squad, and no `driver` point — the garrison always walks on, on every
map, including the three that deliver bought ODSTs by pod.

### 2b2. `sq_fe_marines` cells — the bought 8-man Marine squad, 500 points

Eight cells, `spawn count` 1 each. Cells 6 and 7 are the two the cap most often refuses, so put the
least important loadouts there: a partial placement fills from cell 0 upward.

| Cell | Character type | Initial primary weapon | Initial secondary | Grenades | Vehicle | Starting location |
|---|---|---|---|---|---|---|
| 0 (leader) | Marine (`characters\marine\marine.character` [G]) | DMR (`objects\weapons\rifle\dmr\dmr.weapon` [G]) | Magnum [G] | frag ×2 | — | `fe_marine_sp_0` |
| 1 | Marine | Assault Rifle (`...\assault_rifle\assault_rifle.weapon` [G]) | — | frag ×2 | — | `fe_marine_sp_1` |
| 2 | Marine | Assault Rifle | — | frag ×1 | — | `fe_marine_sp_2` |
| 3 | Marine | Shotgun (`...\shotgun\shotgun.weapon` [G]) | — | frag ×1 | — | `fe_marine_sp_3` |
| 4 | Marine | DMR [G] | — | frag ×1 | — | `fe_marine_sp_4` |
| 5 | Marine | Assault Rifle | — | frag ×1 | — | `fe_marine_sp_5` |
| 6 | Marine | Assault Rifle | — | — | — | `fe_marine_sp_6` |
| 7 | Marine | Shotgun [G] | — | — | — | `fe_marine_sp_7` |

**[G] on the fill order.** `(ai_place <ai> <short>)` is documented as placing "the given number of
members" (`hsdoc_hr.txt` L1280) but which members is not stated, and no shipped script uses the
two-argument form. Cell 0 upward is the obvious reading, not a proven one. Do not put anything the
squad cannot function without in cells 6-7 until you have watched a 4-body purchase arrive.

### 2c. `sq_fe_odst` cells — the bought 8-man ODST squad, 750 points, one heavy weapon

Eight cells, `spawn count` 1 each. **Still only one rocket launcher**, in cell 3, for the reason in the
notes below — eight cells is eight bodies, not eight heavies.

| Cell | Character type | Initial primary weapon | Initial secondary | Grenades | Vehicle | Starting location |
|---|---|---|---|---|---|---|
| 0 (leader) | ODST (`characters\marine_odst\marine_odst.character` [G]) | DMR [G] | Magnum [G] | frag ×2 | HEV pod [G] (pod maps only) | `sq_fe_odst/driver` |
| 1 | ODST | Shotgun [G] | — | frag ×2 | HEV pod | `fe_odst_sp_1` |
| 2 | ODST | Sniper Rifle (`...\sniper_rifle\sniper_rifle.weapon` [G]) | — | frag ×1 | HEV pod | `fe_odst_sp_2` |
| 3 (the heavy) | ODST | Rocket Launcher (`...\rocket_launcher\rocket_launcher.weapon` [G]) | — | — | HEV pod | `fe_odst_sp_3` |
| 4 | ODST | DMR [G] | Magnum [G] | frag ×1 | HEV pod | `fe_odst_sp_4` |
| 5 | ODST | Assault Rifle [G] | — | frag ×1 | HEV pod | `fe_odst_sp_5` |
| 6 | ODST | Assault Rifle [G] | — | — | HEV pod | `fe_odst_sp_6` |
| 7 | ODST | Shotgun [G] | — | — | HEV pod | `fe_odst_sp_7` |

**One pod, eight men — the pod maps need a decision here.** Beachhead, Overlook and Holdout deliver
these ODSTs through a single `dm_fe_pod_01` rail, and how many of the eight actually ride down is the
HEV pod vehicle tag's seat count, which this project has never verified (the existence of a UNSC/HEV
pod tag in the stock Reach tag set is already **[G]** in `fe_reinforcements.hsc` §10). If the pod seats
fewer than eight, the surplus are placed at `sq_fe_odst`'s tag spawn point and do not ride. Two honest
fixes, pick one in Sapien: author a second rail `dm_fe_pod_02` **[NEW]** and call `fe_pod_sequence`
twice, or switch that map's ODSTs to the walk-in delivery Outpost and Glacier already use, which needs
no pod at all. The warning is repeated at each pod call site in the three map scripts.

Notes you need before typing:

- The **spawn-point name on cell 0 must be `driver`** on the three maps that deliver the ODSTs by pod
  (Beachhead, Overlook, Holdout), because the pod scripts resolve the pod vehicle with
  `(ai_vehicle_get_from_spawn_point sq_fe_odst/driver)` — the literal form stock uses
  (`ff20_courtyard.hsc` L518).
- On **Outpost, Glacier and Waterfront** the ODSTs walk in, so the cells need **no vehicle** and no
  `driver` point. See §2f.
- Every tag path above is marked **[G]**: the exact Reach tag paths are not in any source used for
  this pack. Browse `characters\` and `objects\weapons\` in Foundation's explorer and paste the real
  paths. The *fields* are verified; only the paths are guesses.
- Two more one-cell squads: `sq_fe_gunner` (crews a bought turret), and on Waterfront
  `sq_fe_sniper_01` (2 ODST cells with sniper rifles). `sq_fe_pilot` is **gone** — the Falcon it flew
  was removed.
- Keep heavy weapons rare. The source mod's own players report allied heavies missing constantly
  (`research/05` §6 item 1), which is why only cell 3 carries one.

### 2d. `obj_marines` — the AI objective you must build, and the only way friendlies can move

**This is the single largest piece of tag work in the pack, and nothing else works without it.**

Every task in the stock `obj_survival` carries a squad-group filter naming a `gr_survival_*` group,
and `hold_task`'s filter is `gr_survival_all` specifically — the one group a friendly squad must
never join. A squad in `gr_unsc_reinforcements` given `obj_survival/hold_task` **matches no task and
stands still.** The previous version of this pack did exactly that.

The fix is to copy Installation 04, the one shipped Firefight map with working friendly Marines. Its
`cex_ff_halo_main.hsc` carries a **separate objective, `obj_marines`**, with refresh scripts at
L220-242:

```
(script static void refresh_gate_marines            (sleep 5) (ai_reset_objective obj_marines/gate_marines))
(script static void refresh_gate_marines_followers  (sleep 5) (ai_reset_objective obj_marines/gate_marines_followers))
(script static void refresh_gate_marines_defenders  (sleep 5) (ai_reset_objective obj_marines/gate_marines_defenders))
```

and the matching task conditions in `cex_ff_halo_fragments.hsc`, which is the compiled form of what
you type into Sapien:

```
(script static boolean obj_mplaye_3_15  (> (game_coop_player_count) 1))
(script static boolean obj_mplaye_3_16  (> (game_coop_player_count) 2))
(script static boolean obj_mplaye_3_17  (> (game_coop_player_count) 3))
(script static boolean obj_mdefen_3_2   (volume_test_objects tv_north_deck (ai_actors gr_survival_waves)))
(script static boolean obj_mdefen_3_3   (volume_test_objects tv_west_deck  (ai_actors gr_survival_waves)))
(script static boolean obj_mdefen_3_4   (volume_test_objects tv_east_deck  (ai_actors gr_survival_waves)))
(script static boolean obj_mdefen_3_5   (volume_test_objects tv_south_deck (ai_actors gr_survival_waves)))
```

The `3` is the objective index — `obj_marines` is objective 3 in that scenario. So the followers
scale one slot per player, and the defenders reposition to whichever approach the live wave is
actually on.

**Build this in each of the six scenario tags, Objectives view:**

| Task | Type | Squad group filter | Properties | Condition |
|---|---|---|---|---|
| `gate_marines` | gate (root) | `gr_unsc_reinforcements` | — | always |
| `gate_marines_followers` | child of `gate_marines` | `gr_unsc_followers` | **follow: player front**, **follow radius: 10**, **follow Z clamp: 1**, flags: magic player sight, inhibit groups: cover + vehicles, exhaustion script: `fe_refresh_gate_marines_followers` | slot 1 always; slots 2/3/4 gated `(> (game_coop_player_count) 1/2/3)` |
| `gate_marines_defenders` | child of `gate_marines` | `gr_unsc_reinforcements` | one child task per approach, area at a named point (see the table in §2e), exhaustion script: `fe_refresh_gate_marines_defenders` | `(volume_test_objects <your approach volume> (ai_actors gr_survival_waves))` |

`follow: player front / follow radius: 10 / follow Z clamp: 1` is **the real follow mechanism in
Reach**. It is a *task property set in Sapien*, not a script call — it is what makes every Covenant
wave on every stock map chase the player, via the `remaining`, `hero_follow`, `main_follow` and
`bonus_follow` tasks. Script only re-arms it, with `ai_reset_objective` after a sleep:

```
(script static void survival_refresh_follow         ; ff50_park_main.hsc L213-216
    (survival_refresh_sleep)
    (ai_reset_objective obj_survival/main_follow))
```

`fe_reinforcements.hsc` reproduces that shape against `obj_marines`. The fireteam API
(`ai_player_add_fireteam_squad` and friends) that the previous version used is **deleted**: the
shipped block that calls it is commented out at `global_firefight.hsc` L2710-2752 with Bungie's own
note `;tysongr - 53954: Adios, fireteams`, its companion `survival_elite_fireteams` (L2792-2817) is
dead too, and in any case it was the **elite player's** escort, never marines. It survives only as a
commented dead reference in §9 of the library.

`obj_survival` is left completely alone. Do not add tasks to it.

### 2e. Positions: use the named tag objects, never a coordinate

**No coordinate for anything on any of these maps exists in any public source.** Every position
lives in the scenario tag and must be read or set in Sapien or Assembly. So the table below names the
*tag object* to attach to.

| Map | Best friendly / defender anchor | Terminal anchor | Evidence |
|---|---|---|---|
| Beachhead `ff50_park` | **`ps_gen/gen0`, `/gen1`, `/gen2`** | `ammo_crate0`, or `generator_switch0` | `ff50_park_main.hsc` L238-256 authors the point set *and* `cs_gen0`-`cs_gen2` with `cs_enable_pathfinding_failsafe TRUE`, so AI pathing there is proven [V] |
| Holdout `ff70_holdout` | **`ps_gen/gen0`, `/gen1`, `/gen2`** | `ammo_crate0`, or `generator_switch0` (sits at `ps_gen/gen0`, proven reachable *and* interactive) | `ff70_holdout.hsc` L251-270, same pattern [V] |
| Glacier `ff60_icecave` | **inside `tv_wraith`** | `ammo_crate0` cross-checked against `tv_wraith`, or `sc_weapon_01`-`03` | `ff60_icecave_fragments.hsc` L1-5: `(not (volume_test_players tv_wraith))` is the condition on `obj_survival/wraith01` and `/wraith02` — i.e. **the Wraiths stop shelling when players are inside it**. The only verified safe zone in the pack [V] |
| Overlook `ff10_prototype` | new `ps_fe_hold` beside `ammo_crate0` | `ammo_crate0` | no `ps_gen`, no `ps_wraith`, **no trigger volumes at all** [V] |
| Outpost `ff60_airview` | new `ps_fe_hold` beside `ammo_crate0` and `sc_bfg_default` | `ammo_crate0`, or one of `sc_resupply_01`-`09` | `sc_bfg_default` is the live AA gun, made invulnerable at `ff60_airview.hsc` L19 — permanent mission furniture, so the ground around it is the de facto stronghold [V] |
| Waterfront `ff30_waterfront` | new `ps_fe_hold` **inside buildings** | `ammo_crate0` | no `ps_gen`, no `ps_wraith`, no `ps_banshee`; its only two volumes are `tv_cliff_fall_left`/`_right`, which guard the enemy snipers against falling and mark the map's lethal drops [V] |

`ammo_crate0` and `ammo_crate1` are the best-evidenced player-stronghold markers on every Firefight
map, because the globals **default** to those object names and no per-map script has to set them:

```
(global object_name obj_ammo_crate0 ammo_crate0)        ; global_firefight.hsc L54
(global object_name obj_ammo_crate1 ammo_crate1)        ; global_firefight.hsc L55
... (object_create_anew obj_ammo_crate0) ...            ; L3177-3191
    (chud_track_object_with_priority obj_ammo_crate0 13); L3192
```

They are already HUD-trackable at priority 13, which `fe_blip_terminal` reuses. Their presence is
convention-verified; their **positions are tag data** — read them before you build an economy on
them. The design doc's "both ammo crates are inside the barn [V]" on Overlook is **not** script
verifiable.

**Avoid on every map:** `kill_sur_room_01`-`kill_sur_room_08`, the eight Covenant spawn rooms, which
`survival_wave_end_conditions` flushes with `survival_kill_volumes_on` once fewer than 7 enemies
remain. Also `ps_wraith/p0`-`p3` on Beachhead and Glacier (the Wraith's four bombardment targets,
i.e. the open ground), `ps_banshee_01`/`_02` on Holdout (strafing lanes), the sniper squad positions
on Outpost, Holdout and Waterfront, and every `sq_sur_drop_NN` spawn point (Covenant pod lanes).

### 2f. Delivery mechanism per map, and the two that changed

A drop pod **lands wherever the squad's tag spawn point is**. `dm_drop_NN` is only an invisible
animated rail (checklist tag `invis_cov_squad_drop_pod`, folder `dm_droprails`) that carries the
shell down to meet it. **You cannot relocate a pod from script.** So "the pattern exists" means the
script shape is proven on that map, not that a friendly landing site is free.

| Map | Pod infrastructure in the stock script | ODST delivery in this pack |
|---|---|---|
| Beachhead `ff50_park` | `dm_drop_01`-`04`, `sq_sur_drop_01`-`04` [V] | **pod** + new `dm_fe_pod_01` rail and `sq_fe_odst/driver` point beside `ammo_crate0` |
| Overlook `ff10_prototype` | `dm_drop_01`-`05`, `sq_sur_drop_01`-`05` [V] | **pod**, same caveat |
| Holdout `ff70_holdout` | `dm_drop_01`-`04`, `sq_sur_drop_01`-`04` [V] | **pod**, landing near `ps_gen/gen0` |
| Waterfront `ff30_waterfront` | `dm_drop_01`-`05`, `sq_sur_drop_01`-`05` [V] | **walk-in** (pod documented as an alternative) |
| **Outpost `ff60_airview`** | **none at all** — no `dm_drop_*`, no `sq_sur_drop_*`, no `v_sur_drop_*`, no `survival_drop_spawn` [V] | **changed to walk-in** |
| **Glacier `ff60_icecave`** | **none at all**, plus no `dm_longsword_01`, no `dm_resupply_*`, no `sc_target_*` — the only FF map with zero air-delivered objects [V] | **walk-in** (already was) |

**Outpost's pod purchase was the worst claim in the previous version** — it was sold as "the engine
already ships drop-pod hazards [V]", a citation that is true of Firefight in general and false of
this map. It is now a walk-in: a bare `(ai_place ai_fe_odst)` at a new tag spawn point beside
`ammo_crate0`. Walk-in was chosen over a Pelican arrival because a Pelican is *more* new content, not
less: the only UNSC flight path in shipped Reach Firefight is `ps_sur_pelican` on `cex_ff_halo`, with
`sq_sur_pelican` and `cs_ff_halo_pelican`, and none of the six target maps references any UNSC
aircraft at all. Walk-in needs one opcode that already works everywhere — `ai_place`,
`hsdoc_hr.txt` L1277 — plus one new spawn point.

Honest note on walk-ins: there is **no "arrives from off-map" mechanism** in any shipped Firefight
script. A squad appears at its tag spawn point. Put the spawn point out of sight and let the follow
task bring them in; do not expect an entrance animation.

### 2g. Generator loss conditions — valid on two maps only

`generator0`-`generator2` are fixed device machines at fixed tag positions on every map. They cannot
be moved, re-dressed or chosen per scenario — only counted (`s_sur_generator_count`) and ordered
(`b_sur_generator_order_random`). More decisively: **only Beachhead and Holdout have the `ps_gen`
point set and the `obj_survival/gen0`-`gen2` AI tasks that route Covenant to the generators.**

| Map | `ps_gen` | `cs_gen0`-`cs_gen2` | `obj_survival/gen0`-`gen2` | Generator loss condition |
|---|---|---|---|---|
| Beachhead `ff50_park` | yes | yes | yes + `gen0_boost`-`gen2_boost` | **KEPT** — Generator Count 2, lose all |
| Holdout `ff70_holdout` | yes | yes | yes + boosts | available, but scenario uses Count 0 |
| Overlook `ff10_prototype` | no | no | no | **REMOVED** |
| Outpost `ff60_airview` | no | no | no | **REMOVED** |
| Glacier `ff60_icecave` | no | no | no | **REMOVED** |
| Waterfront `ff30_waterfront` | no | no | no | **REMOVED** |

On the four maps without routing, the Covenant have only the generic `generator` task and no approach
points: a generator loss condition fires on damage that no enemy is being sent to deliver. Those four
scenarios now lose on life exhaustion (stock `survival_mode_end_condition_lives`) plus the wave-16
backstop. All twelve generator objects are still assigned by the stock startups — that is Bungie's
boilerplate and is left alone.

### 2h. Vehicle purchases — re-justified from scratch

The old justification was "Wraith terrain verified". It was wrong. Beachhead's and Glacier's Wraiths
are `sq_sur_wraith_01`/`_02` driven by `(cs_shoot_point ps_wraith/p0-p3)` inside `cs_wraith_shoot`
(`ff50_park_main.hsc` L747-776, `ff60_icecave.hsc` L180-192) — a **stationary bombardment command
script** that parks them on four fixed points. It proves the Wraith sits still and shells. It proves
nothing about drivable ground, and a Wraith hovers. Overlook is worse: it names
`sq_sur_wraith_01`/`_02` but has **no `ps_wraith` at all**, so its Wraiths have no authored movement
whatsoever.

**The replacement rule: sell only a vehicle chassis that the map's own stock hazard set already
spawns and moves there.**

| Map | Ghost squad in the stock script | Vehicle sold |
|---|---|---|
| Beachhead `ff50_park` | `sq_sur_ghost_01`, `sq_sur_ghost_02` [V] | Ghost, 1,000, round 2 gate |
| Outpost `ff60_airview` | `sq_sur_ghost_01`, `sq_sur_ghost_02` [V] | Ghost, 1,000, round 2 gate |
| Glacier `ff60_icecave` | `sq_sur_ghost_01` [V] | Ghost, 1,000, round 2 gate |
| Overlook `ff10_prototype` | none | **none** |
| Holdout `ff70_holdout` | none | **none** (was already none) |
| Waterfront `ff30_waterfront` | none | **none** |

Removed: Rocket Warthog and Gauss upgrade (Beachhead, Overlook, Glacier), Scorpion (Overlook,
Glacier), Mongoose/light vehicle (Waterfront), Falcon gunner ride (Beachhead, Holdout). The globals
`k_fe_cost_vehicle_upgrade`, `k_fe_cost_heavy_vehicle` and `k_fe_cost_air_ride` are gone with them.
`[G]` remains on the Ghost: the evidence covers the Covenant squad's own spawn point, not yours.
Place `sc_fe_ghost` beside `ammo_crate0` (inside `tv_wraith` on Glacier) and drive it before pricing.

### 2i. Trigger volumes and objects to place

- `tv_fe_board` — arms the purchase board on first entry (the mission trigger).
- `tv_fe_buy_*` — **one small trigger volume per catalogue entry**, all side by side at the terminal.
  This is what makes the board a menu instead of "cheapest first".
- `tv_fe_bank_in`, `tv_fe_bank_out` — the two bank kiosks, 500 a press, also at the terminal, on the
  route players already walk (see §2j rule 4).
- `tv_fe_buy_<win item>` — **the one exception: this volume does NOT go at the terminal.** It goes at
  the map's exposed named anchor, outside the defensible area (see §2j rule 5 for the per-map list).
- `tv_fe_<hold area>` — the win-condition hold volume.
- `dm_fe_pod_01` — ODST pod rail, on Beachhead, Overlook and Holdout only.
- `sc_fe_*` — turret, Ghost, Pelican/shuttle, all with **"initially placed" off** so script can
  `object_create_anew` them on purchase.

**Overlook, Outpost and Holdout ship with no trigger volumes at all**, and Courtyard has none either.
Beachhead has `tv_wraith_01`/`_02`/`tv_null`, Glacier has `tv_wraith`/`tv_null`, Waterfront has
`tv_cliff_fall_left`/`_right`. Everything else is new, and **every new volume must be postprocessed**
— `volume_test_players` explicitly requires it (`hsdoc_hr.txt` L216-217) — which happens when the
scenario is saved and rebuilt. Save before testing.

### 2j. Economy rationale — read this before you change a price

Every price in the pack lives in one block, section 1 of `fe_reinforcements.hsc`. Retuning the whole
pack is a one-line edit per item, and you can do it live from the Sapien / Standalone console with
`(set k_fe_cost_marines 400)`. Before you touch it, know where the numbers came from.

**1. The income figure is measured, not estimated.** `research/10-author-design-system.md` §1.3 OCR'd
the live score counter out of a complete 21-minute solo playthrough of the mod we are emulating:
581 points at 1:18, 1,239 at 4:40, 3,891 at 8:00, 5,282 at 11:42, ~8,200 at 14:29, 18,365 at 20:34.
That is **≈ 900 points per minute**, and at 2.5–3 minutes a round:

> **one round ≈ 2,000–2,500 points · one set (3 rounds + bonus) ≈ 7,000–8,500 points**

Treat 900/min as the right order of magnitude, not a constant — that run was solo, on his launch
build, with score settings we cannot see. But it replaces the old 4,000–5,000-a-round **estimate**
that `research/05` §4.1 used to carry, which was read off the stock Score Attack achievement and was
roughly **twice** the truth. Every price in the first version of this pack was 3–6× too expensive.

**2. The tier ratios are his, and they are the part to copy.**

| Rung | Share of a round's income | Cost | What lives there |
|---|---|---|---|
| Impulse / repeatable | under ⅓ | 250–750 | **Marines 500, ODSTs 750**, machinegun turret 750, bank press 500 |
| Standard | about ½ | 1,000 | map state, Ghost, turret upgrade, specialist ally team |
| Set purchase | about 1 round | 2,000–2,500 | AA battery, repair a map objective |
| Heavy | about 1.5 rounds | 3,000–3,500 | one-shot strike / barrage |
| **Win purchase** | **about 4 rounds** | **8,000** (6,000 fortify-first) | extraction, firing solution, uplink, charges |
| Punitive | a whole set | 6,000 | **nothing in this pack.** He used it once, for the AA Shade. |

**2a. The 8-man squad did NOT get a price rise, and that was a decision, not an oversight.** The
bought squads went from 4 cells to 8, so the obvious move is to double 500 and 750. It is wrong three
times over:

- **Eight cells does not mean eight bodies.** The concurrent cap (§2b1) is the throttle now, not the
  price. A purchase made while the free garrison is at strength delivers a partial squad, and on
  Outpost the full 8 never lands at all. What the player is actually buying is *the right to refill the
  cap*, and that did not get twice as valuable when the cell count doubled.
- **The free garrison already absorbed the generosity.** Six Marines a round now arrive for nothing.
  Charging more for the paid squad on top of that taxes the player twice for the same change.
- **500 and 750 are the only two `[AUTHOR]` prices on the board**, and they are his numbers *after* he
  corrected them downward in the first 24 hours (rule 3 below). Against the measured ~2,000–2,500 a
  round, 500 is one wave's income — exactly the "impulse / repeatable" rung a thing you buy every wave
  belongs on. Doubling it would put a per-wave purchase on the "standard" rung and re-create the
  failure he patched out.

If play proves eight bodies for 500 is too strong, the first lever is the cap and the second is
`k_fe_buy_cooldown`. Price is the third.

**3. START CHEAP. Only raise a price if play proves that item overpowered.** This is not a preference,
it is the single loudest lesson in the author's change notes. Within **24 hours** of release he cut
nine prices by 50–75%, and every one moved down: ODSTs 2,000→750, Sentinel Hack 3,000→1,000, Falcon
4,000→3,000, Scorpion 5,000→2,500, Gauss 3,000→2,000, Warthog 1,500→1,000, Marines 1,000→500, Base
Power 750→350, Overshield and Active Camo 750→500. An overpriced economy is the failure mode he
actually hit: players never reached the interesting purchases. In two years he raised exactly two
things, and both raises came with a mechanical change rather than standing alone — the Scorpion
2,500→3,500 *plus* a co-axial buff and a per-round respawn, and the AA Shade 3,000→6,000 *plus* an
overheat, because a fixed emplacement that can hit everything on the map was the most overpowered
purchase he shipped. **So: if something feels too strong, fix the thing, then price it. Do not raise
the ladder.** The one item in this pack to watch for exactly that is Holdout's anti-air battery.

**4. Marines and ODSTs are always the two cheapest entries on every board, and always re-buyable.**
500 and 750 — a fifth and a third of a round's income — so a squad is affordable every round and
usually twice. Non-negotiable; it is what the pack is for. The author arrived at the same rule from
the other end: three separate change notes make the ally switch respawn whenever the player runs out
of allies, because a one-shot ally purchase is a trap when allies die fast. `fe_try_buy_squad` already
enforces "one slot per scenario squad, free when the last one is dead", which is that rule in script.

**5. Gates, banners, bank, exposed win terminal — the four structural borrowings.**

- **Round gates, not price, are his real pacing tool.** Price decides what you can afford; the gate
  stops a lucky early round breaking the curve. His: Warthog and Gauss upgrade at Round 2, Scorpion
  and Auto Turret at Round 3. Ours: `k_fe_gate_upgrade`/`k_fe_gate_vehicle` = 2,
  `k_fe_gate_heavy` = 3, `k_fe_win_round_gate` = 5, all absolute round indices via `fe_round_index`.
- **Every gate gets a HUD banner at the round boundary.** His verbatim: "The Warthog and Gauss upgrade
  are now available!" His 0.1.6 note says why they had to exist: "HUD messages for important events …
  are now implemented to make objectives more clear ingame." An unannounced gate reads as a bug. Each
  scenario file carries a `*_gates` script that fires one banner per gate, once.
- **The bank: two kiosks, 500 a press, deposit and withdraw** (`fe_bank_deposit` /
  `fe_bank_withdraw`, library §6a). His, shipped one day after launch, STATED reason: "This should
  help achieving win conditions in co-op easier"; step moved 200→500 three weeks later because 200
  needed too many presses. Banked points are deducted from the live score, so they cannot be spent by
  accident and the 8,000 win purchase becomes a plan. Site the kiosks where players already walk — his
  are "next to the health pack" on I04 and "near the base power switch" on Unearthed. **`g_fe_bank`
  must not be reset at a set boundary**; every other purchase global should be.
- **The win-purchase terminal goes OUTSIDE the defensible area.** On Unearthed he exiles the MAC
  Cannon to the Crane, and the run to it under the cruiser's barrage *is* the climax. Named tag
  objects only, no invented coordinates; positions are [TAG], so read them in Sapien and keep each
  volume clear of pod landing footprints:

| Map | Win purchase | Exposed anchor |
|---|---|---|
| Beachhead `ff50_park` | Pelican dust-off | `ps_wraith/p2` — the Wraith's own bombardment point, outside `tv_wraith_01`/`_02` |
| Overlook `ff10_prototype` | Relay uplink | `sq_sur_drop_05` — the far bank, across the only crossing |
| Outpost `ff60_airview` | Tyrant firing solution | `sc_bfg_destroyed` — the wrecked AA gun, invulnerable, far flank |
| Holdout `ff70_holdout` | Launch clearance | `sq_sur_drop_04` — right-hand drop zone, under the `ps_banshee_02` lane |
| Glacier `ff60_icecave` | Demolition charges | `ps_wraith/p1` — shelled ground, explicitly outside the sheltered `tv_wraith` |
| Waterfront `ff30_waterfront` | Station scram | `sq_sur_drop_03` — the basins, clear of `tv_cliff_fall_left`/`_right` |

**6. Honesty rule on the numbers.** In the price comments, `[AUTHOR]`/`[A]` means a price he actually
shipped after his own playtest corrections. `[DERIVED]`/`[D]` means he never priced that item and we
placed it on his rung — the auto/one-shot strike, the turret upgrade, the specialist ally team and
**every win purchase** are all derived, because Installation 04's Evac Pelican, Unearthed's MAC Cannon
and the Corvette bridge doors are recorded as **UNKNOWN** in `research/10` §1.1. Do not quote a
derived number as his. The win purchase is derived from his *gate* rather than his price: he gated the
MAC Cannon to where his own score curve crosses ~8,000.

**7. If our measured income differs from his, change the constants block, not the design.** Re-measure
one round on Normal and one on Legendary, solo and 4-player, in our build. Prices are flat across
difficulties on purpose — difficulty changes income, and the round gates absorb the difference.

## 3. Naming conventions this pack obeys

| Prefix | Tag type | Real examples grepped from shipped scripts |
|---|---|---|
| `sq_` | AI squad | `sq_sur_phantom_01`, `sq_sur_drop_03`, `sq_sur_wraith_02`, `sq_sur_ghost_01`, `sq_sur_banshee_02`, `sq_sur_sniper_04`, `sq_ff_bonus`, `sq_marines_01` |
| `gr_` | AI squad group | `gr_survival_all`, `gr_survival_waves`, `gr_survival_extras`, `gr_survival_snipers`, `gr_survival_remaining` |
| `ps_` | script-data point set | `ps_sur_phantom_01`, `ps_gen`, `ps_wraith`, `ps_banshee_01`, `ps_sur_pelican` |
| `tv_` | trigger volume | `tv_wraith`, `tv_wraith_01`, `tv_cliff_fall_left`, `tv_null`, `tv_north_deck` |
| `kill_` | kill volume | `kill_sur_room_01`-`08` |
| `dm_` | device machine | `dm_drop_01`, `dm_resupply_09`, `dm_target_03`, `dm_longsword_01` |
| `sc_` | scenery | `sc_resupply_01`, `sc_target_01`, `sc_weapon_03`, `sc_poa`, `sc_bfg_default`, `sc_bfg_destroyed` |
| `cr_` | crate folder | `cr_grenades`, `cr_sandbox_items` |
| `obj_` | AI objective | `obj_survival`, `obj_marines` |
| `cs_` | command script | `cs_sur_phantom_01`, `cs_gen0`, `cs_wraith_shoot`, `cs_banshee_01`, `cs_ff_halo_pelican` |

Survival-tree objects carry the **`_sur_` infix** and **zero-padded two-digit** numbers. The previous
version of this pack invented map-letter prefixes (`sq_bh_wraith_01`, `sq_ho_banshee_01`,
`sq_op_ghost_01`, `sq_wf_snipers`) that exist nowhere and would have been guaranteed compile errors.

**Unprefixed, single-digit, 0-based exceptions that are real and must be spelled exactly:**
`generator0`-`generator2`, `generator_switch0`-`2`, `generator_switch_cool0`-`2`,
`generator_switch_disabled0`-`2`, `ammo_crate0`/`ammo_crate1`, `health_pack0`-`5`,
`spartan_01`-`06` (respawn zones).

**One more real quirk:** the dead fireteam squads are `sur_fireteam_01`-`06` on five of the six maps
but `sq_elite_fireteam_01`-`06` on Beachhead. All six maps still assign them in their startup and
nothing consumes them. They are six inert squad definitions per map with existing spawn geometry — a
tempting shortcut for friendly squads, *but* per the authoring checklist they sit in
`gr_survival_fireteams → gr_survival_waves → gr_survival_all`, so they must be reparented or waves
never end, and as elite-player escorts they are presumably Covenant characters. Verify both in Sapien
before relying on it.

## 4. Build steps

You have not used HR-EK before, so do these in order and stop at the first one that fails.

1. **Install HR-EK.** Steam → search "Halo Reach Editing Kit" → install. Free, Windows only. Launch
   it once so it finishes setting itself up.
2. **Learn the four programs.** `bin\tools` holds them:
   - **Foundation** — the tag editor. Opens and edits tag *fields*. No object placement.
   - **Sapien** — the scenario editor. Places objects, squads, trigger volumes, zones, **objectives
     and tasks**; also where scripts get compiled and errors get reported.
   - **Standalone** — a playable build with tag reloading and a HaloScript console. This is where you
     test, not in MCC.
   - **Tool** — the command-line compiler; it turns a scenario into a `.map`.
3. **Copy the scripts in.** Put the two `.hsc` files for one map into that map's script folder under
   HR-EK's `data` tree:
   `HREK\data\levels\firefight\ff50_park\scripts\`
   Each map needs `fe_reinforcements.hsc` **plus** its own file. Do not put all six map files into
   one map.
4. **Open the scenario in Sapien.** `File > Open` →
   `HREK\tags\levels\firefight\ff50_park\ff50_park.scenario`. Expect a long first load.
5. **Build the scenario content from §2.** In order, because each step depends on the last:
   1. squad groups `gr_unsc_reinforcements` (child of nothing) and `gr_unsc_followers`;
   2. squads `sq_fe_garrison` (**6 cells**), `sq_fe_marines` (**8 cells**), `sq_fe_odst`
      (**8 cells**), `sq_fe_gunner` (+ `sq_fe_sniper_01` on Waterfront) with
      their cells and starting locations;
   3. the point set for defender positions — `ps_gen` already exists on Beachhead and Holdout, so
      reuse it; author `ps_fe_hold` on the other four;
   4. **the `obj_marines` objective and its three tasks (§2d)** — nothing moves without this;
   5. the trigger volumes, which must be postprocessed (save and rebuild);
   6. the `sc_fe_*` objects and `dm_fe_*` devices with "initially placed" off.
6. **Register the scripts and fix the order.** The scenario tag has a block listing its HaloScript
   source files. Open `ff50_park.scenario` in **Foundation**, find that block, and make sure
   `fe_reinforcements` is listed **before** `ff50_park`. A per-map file calls library scripts, so the
   library must compile first.
   - Resolve the startup-script collision now — see "Startup-script collision" in §0.
7. **Compile the scripts.** Sapien compiles the scenario's scripts when it loads them, and prints
   every error with a line number in its output window. At runtime, the console command
   `script_recompile` recompiles without reloading the map. Open the console with the `~` key.
   Fix compile errors top-down: a single unbalanced parenthesis invalidates everything after it.
   A reference to a missing object is a **compile error**, which is good. A valid name in the wrong
   squad group is a **silent logic failure**, which is the dangerous case — hence §1 and §1a.
8. **Test in Standalone, not MCC.** Launch Standalone, load the scenario, and use the console:
   - `(set g_fe_debug TRUE)` — turns on `print` tracing for every purchase decision.
   - `(fe_report)` — prints gross score and friendly actors alive.
   - `(fe_report_tasks)` — prints the living count matched to each `obj_marines` task. **If this
     reads 0 after a purchase, your objective or its squad-group filters are wrong.**
   - `(fe_board_open)` — skip the mission trigger.
   - `(test_fe_marines)` / `(test_fe_odst)` — per-map test harnesses, shaped after Bungie's own
     `test_squad_drop` (`ff20_courtyard.hsc` L1253-1260). They open the board, zero the price and buy.
   - `F6` erases all spawned actors; `F1`/`F2` select actors and encounters.
9. **Verify the two rules.** In Standalone:
   - buy a squad mid-wave and confirm the wave still ends → if not, your squad group is parented
     wrong (§1);
   - on Overlook or Waterfront, buy a squad, keep it alive, and confirm Covenant **drop pods still
     arrive** → if they stop, your friendlies are in `gr_survival_extras` (§1a).
10. **Build the map.** Open a command prompt in `HREK\` and run:
    ```
    tool build-cache-file "levels\firefight\ff50_park\ff50_park" pc
    ```
    The verb and argument order are from the official HR-EK Tool documentation
    (`build-cache-file <scenario> <platform> ...`). Output lands in `HREK\maps\ff50_park.map`.
11. **Install the map.** Back up the original first, then copy your `ff50_park.map` over
    `steamapps\common\Halo The Master Chief Collection\haloreach\maps\ff50_park.map`.
    **[unverified]** The exact maps folder and whether MCC needs mod support enabled or
    anti-cheat disabled for a replaced stock map are not confirmed by any source used for this pack.
    Keep the backup.
12. **Pair it with the gametype.** Copy `build/Firefight Evolved Expanded.bin` into
    `steamapps\common\Halo The Master Chief Collection\haloreach\game_variants\`. That path is the
    one the source mod's own Workshop description instructs users to use (`research/06` §0). In-game:
    Customs → Firefight → load the variant, then the modded map.
13. **Repeat 3-11 for the other five maps**, swapping the scenario path: `ff10_prototype`,
    `ff60_airview`, `ff70_holdout`, `ff60_icecave`, `ff30_waterfront`.

### Gametype settings each scenario expects

| Map | Generators | Fail condition | Other |
|---|---|---|---|
| Beachhead `ff50_park` | **2** (the only map where it routes, see §2g) | lose all | hazards on, weapon drops on |
| Overlook `ff10_prototype` | 0 | — | hazards on (drop pods) |
| Outpost `ff60_airview` | 0 | — | hazards on |
| Holdout `ff70_holdout` | 0 (2 is legitimate here if you want it, §2g) | — | hazards on (Banshees live, snipers woken by script) |
| Glacier `ff60_icecave` | 0 | — | hazards on |
| Waterfront `ff30_waterfront` | 0 | — | hazards on (snipers live, Banshees woken by script) |

Hazards matter: every optional hazard in stock Firefight sits behind
`(survival_mode_scenario_extras_enable)`, documented at `hsdoc_hr.txt` L3576 as "Get the survival
mode scenario hazards enabled property from the game variant". That is the one game-variant switch
that already controls scripted extras, including the Covenant drop pods on four of the six maps.

All six assume a 16-wave limit (one set, then a second set) because every lose backstop fires at
`s_survival_wave_complete_count >= 16`. Change `k_fe_wave_backstop` if you change the wave limit.

## 5. Changing how buying works

The board uses **trigger volume + action key**: stand in the item's volume and press the action/reload
key. `volume_test_players` and `player_action_test_action` are both real Reach functions, but no
shipped Firefight script polls `player_action_test_*`, and the action key is also Reload — so
reloading at a terminal buys.

Two alternatives, in order of evidence:

1. **A player-usable `device_machine` switch per item**, polled with `(device_get_position ...)` and
   reset with `(device_set_position ... 0)`. That is exactly how stock Firefight drives its generator
   switches (`global_firefight.hsc` L1807-1930 arms them with `device_set_power`; L1934-1975 polls
   `device_get_position`). More tag work, no script redesign — the buy scripts stay identical.
2. **On Beachhead and Holdout only: repurpose `generator_switch0`-`2`.** They are real device
   controls that sit at `ps_gen/gen0`-`gen2`, so they are proven reachable *and* proven interactive,
   and on Holdout they are co-located with the defensible positions. The catch is Generator Defense:
   Beachhead keeps it on, so the switches are spoken for there; Holdout runs Generator Count 0, so
   they are free.

Nothing in shipped Firefight is a walk-up interactable except the generator switches. `ammo_crate0`
and `ammo_crate1` are the best *positions* but they are equipment, not switches.

## 6. Changelog — every fix in this revision

| # | Defect | Fix |
|---|---|---|
| 1 | **Invented squad names.** `sq_bh_wraith_01`/`_02`, `sq_bh_ghost_01`, `sq_ov_wraith_01`/`_02`, `sq_op_ghost_01`/`_02`, `sq_ho_banshee_01`/`_02`, `sq_gl_wraith_01`/`_02`, `sq_gl_ghost_01`, `sq_wf_snipers`, `sq_wf_jackal_snipers` — 15 identifiers that exist in no script or tag, plus a truncated `ai_sur_phantom_` in `outpost.hsc`. | Replaced with the real `_sur_`-infixed names grepped per map: `sq_sur_wraith_01`/`_02`, `sq_sur_ghost_01`/`_02`, `sq_sur_banshee_01`/`_02`, `sq_sur_sniper_01`-`_04` / `gr_survival_snipers`. The friendly sniper squad became `sq_fe_sniper_01` (zero-padded, `fe_` namespace, no `_sur_`). `holdout.hsc`'s internal inconsistency (both `sq_ho_banshee_01` and `sq_sur_banshee_01` in one file) is gone. |
| 2 | **Invented object names.** `sc_op_cannon_live` / `sc_op_cannon_wreck` duplicated objects that already exist. | Replaced with the real `sc_bfg_default` and `sc_bfg_destroyed` (`ff60_airview.hsc` L19-20). All remaining `sc_fe_*`, `dm_fe_*`, `tv_fe_*` objects are renamed into one consistent `fe_` namespace and each is marked `[NEW]` at its declaration site, so nothing reads as if it already exists. |
| 3 | **Wrong script names.** Files were `beachhead.hsc`, `overlook.hsc`, … and startup scripts were `fe_beachhead_init`, `fe_overlook_init`, … — friendly map names with no engine referent. | Files renamed to `ff50_park.hsc`, `ff10_prototype.hsc`, `ff60_airview.hsc`, `ff70_holdout.hsc`, `ff60_icecave.hsc`, `ff30_waterfront.hsc`. Startup scripts renamed to the tag name, matching `(script startup ff20_courtyard ...)`. Each header carries the tag-name → map-name mapping, and a collision warning plus paste markers, because the stock script already owns that startup name. |
| 4 | **Follow-the-player built on the fireteam API**, which is commented out in shipped Reach (`;tysongr - 53954: Adios, fireteams`, `global_firefight.hsc` L2710-2752) and was the *elite player's* fireteam, never marines. | Deleted, kept only as a commented dead reference. Replaced with the real mechanism: a **task property in the scenario tag** — `follow: player front / radius 10 / Z clamp 1` — on a new `obj_marines/gate_marines_followers` task, re-armed from script with `ai_reset_objective`. Pattern and task names copied verbatim from Installation 04 (`cex_ff_halo_main.hsc` L220-242, `cex_ff_halo_fragments.hsc`), including per-player follower slots and `volume_test_objects`-driven directional defender tasks. Documented as buildable Sapien steps in §2d. |
| 5 | **`fe_squad_hold` could never work.** It called `(ai_set_task squad obj_survival hold_task)`; `hold_task`'s squad-group filter is `gr_survival_all`, so a friendly squad matched no task and idled. | Rewritten as `(ai_set_objective squad obj_marines)` + `(ai_set_task squad obj_marines gate_marines_defenders)`. Objective and task are now hardcoded rather than passed as `string_id` parameters, which also removes the old unverified reliance on `string_id` as a script parameter type. |
| 6 | **The `gr_survival_extras` trap was undocumented.** | Documented loudly in §1a with the exact gate lines on all three affected maps, and repeated as a `*** PARENTING WARNING ***` block at every parenting site in all six per-map files and in the library header. Added the `gr_survival_snipers` and bonus-group traps. Added a Standalone verification step (build step 9). |
| 7 | **Outpost sold a drop-pod ODST delivery on a map with zero pod infrastructure.** | **Changed to a walk-in `ai_place`.** Chosen over a Pelican because a Pelican is more new content, not less — `ps_sur_pelican`/`sq_sur_pelican`/`cs_ff_halo_pelican` exist only on `cex_ff_halo` and no target map references any UNSC aircraft. Reasoning recorded in the file header and §2f. |
| 8 | **Glacier's delivery needed confirming.** | Kept as walk-in and strengthened: the arrival point, the defender task areas and the terminal are all now anchored **inside `tv_wraith`**, the one script-backed shelter volume in the pack. |
| 9 | **Generator loss conditions on four maps with no generator AI routing.** | Removed on Overlook, Outpost, Glacier and Waterfront; those scenarios now lose on life exhaustion plus the wave-16 backstop. Kept on Beachhead, which has `ps_gen`, `cs_gen0`-`cs_gen2` and the `obj_survival/gen0`-`gen2` tasks. Noted as a legitimate option on Holdout, which has the same routing. Evidence table in §2g. |
| 10 | **Vehicle sales justified by "Wraith terrain verified".** | Justification deleted — those Wraiths are stationary `cs_shoot_point` bombardment and prove nothing about drivable ground. Replaced with the rule "sell only a chassis the map's own hazard set already spawns and moves", which removes 5 purchases across 4 maps and keeps 3 Ghosts on the 3 maps with a Ghost squad. Table in §2h. `k_fe_cost_vehicle_upgrade`, `k_fe_cost_heavy_vehicle`, `k_fe_cost_air_ride` deleted. |
| 11 | **Score deduction used a soft ledger** on the claim that Reach cannot subtract score. | Claim was wrong. `(<void> campaign_metagame_award_points <player> <long>)` takes a **signed** long and Bungie calls it with `+500` through `+30000` (`global_firefight.hsc` L3382-3397), so `fe_charge` now passes a negative. `g_fe_spent`, `fe_score_available`'s subtraction, `k_fe_hard_deduct` and `fe_deduct_hard` are all deleted. The HUD score now visibly drops. |
| 12 | **Duplicate hazard spawners.** Our escalation hand-placed Banshees on Holdout and snipers on Waterfront. | Both removed: `ff70_holdout.hsc` L204 already wakes `survival_banshee_spawn` (which places `sq_sur_banshee_01`/`_02` itself at L677-678), and `ff30_waterfront.hsc` L151 already wakes `survival_sniper_spawn`. Replaced with one-line wakes of each map's *dormant* hazard instead — `survival_sniper_spawn` on Holdout (wake commented out at L205) and `survival_banshee_spawn` on Waterfront (L150). Entirely stock content, no hand-placing that could race a gate. |
| 13 | **Non-existent "stock hardware" upgrades.** Outpost's roof-turret upgrade and Holdout's central-turret upgrade both claimed to upgrade existing map objects. Neither map names any turret object. | Both entries deleted rather than quietly converted into extra new turrets. |
| 14 | **Navpoint priority was a guess (`1`).** | Changed to `13`, the value stock uses on the ammo crates (`global_firefight.hsc` L3192). Added `fe_blip_terminal` using the stock `obj_ammo_crate0` global. |
| 15 | **Glacier's win fired a pod-impact effect on a turret using the marker `"fx_impact"`**, which belongs to a drop-pod rail. | Deleted. The win works without it. |
| 16 | **No way to tell whether the objective was wired up.** | Added `fe_report_tasks`, which prints `ai_task_count` for all three `obj_marines` tasks, plus per-map `test_fe_marines` / `test_fe_odst` harnesses shaped after Bungie's `test_squad_drop`. |
| 17 | **Every price was 3-6× too expensive**, because the ladder was pitched off an unverified 4,000-5,000-points-a-round estimate and a second-hand 30,000 win price. | Rebuilt on the author's real post-playtest prices against his **measured** ~2,000-2,500 a round (`research/10` §1.3): Marines 1,500→**500**, ODSTs 3,000→**750**, turret 4,000→**750**, map state 2,000→**1,000**, turret upgrade 3,000→**1,000**, Ghost 6,000→**1,000**, strike 18,000→**3,000**, set-tier items 5,000/8,000→**2,000**, win 30,000→**8,000** (6,000 fortify-first). Rationale, tier ratios and the start-cheap rule are in §2j. New globals `k_fe_cost_set_item`, `k_fe_cost_squad_special`, `k_fe_cost_win_discount`, `k_fe_bank_step`; the last literal prices left in the per-map files (2,500 / 5,000 / 8,000 / 20,000 / 25,000) are gone. |
| 18 | **No round gates and no unlock announcements**, so price was the only pacing tool and a lucky round could break the curve. | Adopted his gate pattern: `k_fe_gate_upgrade`/`k_fe_gate_vehicle` = round 2, `k_fe_gate_heavy` = round 3, `k_fe_win_round_gate` = round 5, tested with the new `fe_round_index` / `fe_gate_open`. Each scenario gained a `*_gates` script that fires one HUD banner per gate on the round boundary, which is what his 0.1.6 note added for the same reason. |
| 19 | **No bank**, so points saved toward the win were indistinguishable from points about to be spent, and in co-op nobody individually reaches the win price. | Added his banking system: two kiosks, `fe_bank_deposit` / `fe_bank_withdraw`, 500 a press, 1-second kiosk cooldown, balance in `g_fe_bank` held outside the live score. Volumes `tv_fe_bank_in` / `tv_fe_bank_out` on all six maps, sited on the route players already walk. `g_fe_bank` is the one global that must survive a set teardown. |
| 20 | **The win terminal sat at the player's stronghold**, which `research/05` §6 item 4 explicitly recommended — before his real placement was recovered. | Reversed. The win terminal now goes at a named exposed anchor per map, outside the defensible area, copying the Unearthed MAC-Cannon-on-the-Crane decision: `ps_wraith/p2` (Beachhead), `sq_sur_drop_05` (Overlook), `sc_bfg_destroyed` (Outpost), `sq_sur_drop_04` (Holdout), `ps_wraith/p1` outside `tv_wraith` (Glacier), `sq_sur_drop_03` (Waterfront). All named tag objects; no coordinates invented. Table in §2j rule 5. |

## 7. Honesty: what is still not verified

Everything below is a line that could not be backed by a shipped Bungie script or HR-EK
documentation. Each is also tagged `[G]` in the file itself.

### Most likely to break first

1. **`obj_marines` on these six maps.** The pattern is fully verified on Installation 04 — a separate
   objective, per-player follower slots, directional defender tasks, air delivery. It is verified
   **nowhere else**. `obj_marines`, `sq_marines_01`, `sq_marines_02`, `sq_marines_player_followers`,
   `sq_sur_pelican`, `ps_sur_pelican` and the four `tv_*_deck` volumes appear **only** in
   `cex_ff_halo`. Every one of them is new content on all six target maps. The exact Sapien field
   names and layout for a follow task's `follow radius` / `follow Z clamp` / `inhibit groups` are
   reconstructed from the shipped objective tree and KSIEdge's authoring notes, not from a schema.
   Build it on one map, verify with `(fe_report_tasks)`, then clone the objective to the other five.
2. **Negative `campaign_metagame_award_points`.** The function is real, the second argument is a
   signed `<long>`, and Bungie calls it with positives. **No shipped script passes a negative.**
   Verify the sign in Standalone before you ship. Note also that charging game slot 0 only means one
   player's displayed score carries the whole bill and can go negative.
3. **`(player0)`.** It is the accessor Bungie pairs with `campaign_metagame_award_points`
   (`global_firefight.hsc` L3382) so it is verified by use, but it does not appear in
   `hsdoc_hr.txt`. The documented alternative is `(human_player_in_game_get 0)` (L186) — swap if it
   will not compile.
4. **Multiple `(script startup ...)` per scenario.** Each file declares one and the stock script
   already declares one with the same name. Resolve per §0 before compiling.

### Also unverified

5. **Reading score per game slot.** `campaign_metagame_get_player_score` and
   `human_player_in_game_get` are both verified individually, and stock sums scores the same way —
   but stock pairs the score read with `(player_human N)`, which indexes **living** players. The
   combination used here (game-slot indexing, which does not wobble when a player dies) is ours.
6. **`player_action_test_*` as a purchase input.** Real functions, no shipped Firefight usage. §5.
7. **Player feedback.** `fe_notify` uses `hud_set_training_text` / `hud_show_training_text`: real
   functions, no shipped Firefight usage, and each `<string_id>` must resolve to a real string in the
   map's string tags. The verified alternative is the incident system stock Firefight uses for every
   announcement (`submit_incident`, `global_firefight.hsc` L2957-3140), which needs a new incident
   entry per message. The cheapest working feedback is the stock blip sound, already wired.
8. **Crewing a turret.** `vehicle_load_magic` is real and `cex_ff_halo_main.hsc` L865-868 uses it to
   load a Warthog into a Pelican, so the opcode works on a real object — but no shipped script crews
   a turret with it. `ai_place_in_vehicle` is the documented alternative and needs a vehicle squad
   authored in the scenario. Worst case, ship the turret unmanned.
9. **All object variant names** — `"rocket"` turret, `"repaired"` Tyrant cannon. `object_create_variant`
   itself is verified and stock uses it with `"laser"`, `"rocket"`, `"sniper"`
   (`ff20_courtyard.hsc` L747-757); the specific variant strings on *your* tags are not. On Outpost
   specifically, both BFG objects are made invulnerable at startup, i.e. Bungie treats them as
   non-interactive set dressing, so a `"repaired"` variant may not exist at all — delete the repair
   entry if so.
10. **The UNSC/HEV drop pod.** Reach ships Covenant hazard pods. A UNSC pod tag may not exist in the
    stock tag set. If it does not, use the walk-in delivery on all six maps.
11. **Destructible Phantoms (Outpost's win).** Stock Firefight explicitly makes dropships unkillable:
    `(object_cannot_die v_sur_phantom_01 TRUE)` at `ff60_airview.hsc` L162, and the same for `_02`
    (L327), `_03` (L465), `_04` (L566) and `v_sur_bonus_phantom` (L680). `ff60_airview.hsc` in this
    pack clears that flag first, which is not verified behaviour, and the source mod reports scripted
    ship guns flinging co-op players out of the seat. A safe all-verified fallback win —
    `op_firing_hold`, a 90 s hold at the gun — is in the file; switch the `wake` if the kill count
    does not work.
12. **Pelican / shuttle flight.** `sc_fe_pelican` (Beachhead) and `sc_fe_shuttle` (Holdout) are new
    objects with new flight paths. The *pattern* is verified — `cs_ff_halo_pelican`,
    `cex_ff_halo_main.hsc` L851-912, with the point set `ps_sur_pelican` (`run_01`-`run_05`,
    `face_01`, `erase`) and `(vehicle_unload ... "pelican_lc")` — but that point set exists on no
    other map. Cut these rather than ship them broken; both are win-sequence dressing, and the win is
    the volume hold.
13. **Ghost clearance from a new spawn position.** The three Ghost purchases are evidenced by the
    map's own `sq_sur_ghost_*` squads, which is real — but that covers the Covenant squad's own tag
    spawn point, not yours. Drive each one out before pricing it.
14. **AA targeting bias** (Holdout's anti-air battery). `ai_object_set_targeting_bias` is used by
    stock on generators and `ai_prefer_target_team` is documented, but "a turret that prioritises
    Banshees" is not a thing either function promises. If it does not steer, reprice it as a second
    plain turret.
15. **`(if <cond> 1 0)` returning a number** (Outpost's Phantom counter). Stock proves an `if`
    expression can return a boolean; a short is untested. Fallback is `op_firing_hold`.
16. **`starting_profile` as a script parameter type** (`fe_arm_squad`). Valid HaloScript type in
    function signatures; not used as a script *parameter* type by any shipped script.
17. **Waterfront's Banshees.** `sq_sur_banshee_01`/`_02` and `survival_banshee_spawn` are real and the
    wake is only commented out, but Waterfront has **no `ps_banshee_*` point sets**, unlike Holdout.
    Where they fly is not authored. Bungie shipped that spawner dormant and this may be why.
18. **Overlook's Wraiths.** Real squads, but no `ps_wraith` and no `obj_survival` wraith tasks, so
    once placed they fall through to that map's minimal task set and will probably just follow
    players. The design's "the Wraith crosses to the yard" is unsupported.
19. **Every position in this pack.** No coordinate for anything on any of these maps exists in any
    public source. `ammo_crate0`/`ammo_crate1` presence is convention-verified from the global
    defaults but their **positions are tag data**. `ps_gen`'s and `tv_wraith`'s existence is script
    verified; their geometry is not. Export them from Sapien or Assembly first — that single step
    turns most of this document from named objects into real places.
20. **The real friendly-AI ceiling.** There is no published Reach actor-pool constant — `research/06`
    §4 searched for one and found none, so no number is quoted anywhere in this pack. What is
    documented: 6 enemy squads per wave, 2 dropships, 1-2 drop pods by player count. The budget is
    shared with the enemy spawner, and over budget the engine does not error — enemies silently fail
    to spawn. Hence `k_fe_actor_limit` 8 (4 on Outpost, 6 on Holdout). Raise it only after watching a
    boss wave with a full friendly roster and counting the enemies that actually arrive.
21. **MCC install path and mod loading for a replaced stock map** (build step 11).
22. **Per-unit Reach Firefight point values.** Partly resolved, and the resolution moved every price
    in this pack. The ladder is no longer calibrated on the old 30,000 Corvette figure (withdrawn —
    `research/10` §1.1 records every win purchase he shipped as UNKNOWN) or on the derived
    4,000-8,000 a round (withdrawn — it was an estimate off a stock achievement). It is calibrated on
    the OCR measurement of the mod itself: **≈ 900 points/minute, 2,000-2,500 a round**
    (`research/10` §1.3, `research/05` §4.1, and §2j here). Still unverified: the per-unit values
    themselves, and whether *our* build earns at the same rate. Measure one round on Normal and one on
    Legendary, solo and 4-player. They are all one-line globals for exactly this reason.
23. **Scoring integrity.** Any *player-advantageous* trait or skull switches Firefight scoring to
    1 point per minute, which would silently destroy this entire currency (`research/05` §1.5). Never
    sell a player buff. Sell units, hardware and map state — which is all this catalogue does — and
    re-measure income after every gametype tuning pass.
24. **Reparenting `sur_fireteam_01`-`06` / `sq_elite_fireteam_01`-`06`** as friendly squads. The names
    are script-verified on all six maps; their group parentage is convention-level and their character
    type is an inference. Verify both in Sapien before relying on the shortcut (§3).
