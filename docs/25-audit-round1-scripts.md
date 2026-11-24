# 25 — Adversarial script audit, round 1

Target: the nine shipped maps in `ready-to-install/` (the `MOD-PACKAGE/` copies are byte-identical
by MD5, verified, so they are not audited separately).

| shipped file | MD5 | in MOD-PACKAGE as |
|---|---|---|
| `ff10_prototype.FINAL.map` | `87a3c0fb…` | `Firefight-Reinforcements/maps/ff10_prototype.map` |
| `ff20_courtyard.FINAL.map` | `44875c0e…` | `…/ff20_courtyard.map` |
| `ff30_waterfront.FINAL.map` | `99cc8d6e…` | `…/ff30_waterfront.map` |
| `ff50_park.FINAL.map` | `ccbc3682…` | `…/ff50_park.map` |
| `ff60_airview.FINAL.map` | `b38aadf4…` | `…/ff60_airview.map` |
| `ff60_icecave.FINAL.map` | `78f49504…` | `…/ff60_icecave.map` |
| `ff70_holdout.FINAL.map` | `455f1d0c…` | `…/ff70_holdout.map` |
| `ff_unearthed.marines6.map` | `94851196…` | `Firefight-Reinforcements/maps/ff_unearthed.map` |
| `ff_unearthed.tuned.map` | `5e9e9479…` | `Firefight-Reinforcements-Safe/maps/ff_unearthed.map` |

## 0. Method, and why each result can be trusted

Build strings were read out of each cache header before anything else: the seven retail maps are
`Jun 21 2023 15:35:31` (MCC Update 13); both Unearthed variants and the author's own map are
`Jul 16 2023 16:12:13`. `decompile.py` was then run with **all four** MCC opcode tables and
`--auto-table`. `reachmcc_u13.xml` scored **100.00 %** of fixed-arity calls on every one of the
nineteen caches decompiled (seven mods, seven stocks, three Unearthed, one corvette control), with
0 opcodes missing from the table; the next-best table scored 69-71 %. No function name in this audit
is a guess.

Everything below is derived from one of four independent readers, never from `project/research/`:

1. `tools/hsc/decompile.py` for the script/global/expression tables.
2. A fresh script-reference walker (`opcode` field of every `script_reference` expression resolved
   against the script table, plus declared-vs-supplied arity) — covers defect class 9.
3. A fresh `scnr` tag reader walking `research/_raw/reach-defs/scenario.json` layouts for object
   names, controls/machines/equipment placements, squad groups and their `parent`, squads and their
   `team`/`flags`/`parent`/`spawn points`/cells, cell choice-block pointers, AI objectives and
   tasks, player starting locations, and kill/safe trigger volumes.
4. Bungie's own shipped scripts in the matching stock cache, and the author's
   `maps-stock/ff_unearthed.map`, as the oracles.

**Oracle discipline.** Every pattern this mod uses was checked against either Bungie's shipped
Firefight script or the author's playtested map before being accepted or rejected. Three of the
project's standing beliefs did not survive that check (section 6).

**Calibration.** The spawn-point containment test was validated against a known bad case before
being trusted: Holdout's stock `sq_sur_drop_01..04` spawn points at `(425.8, 105.9-108.4, 2.2)` are
correctly reported **outside** `safe_zone_soft`, while all 16 Holdout player starting locations are
reported inside it and in no kill volume. On every one of the seven maps the test reports 16/16
player starts inside the safe zone and 0/16 in a kill volume, so a "pass" from it means something.

---

## 1. Severity summary

| severity | count | where |
|---|---|---|
| BLOCKER | 1 global + 3 on two maps | win purchase (all 7); Waterfront + Outpost ally delivery |
| RISK | 2 global + 5 map-specific | Longsword/stock-resupply collision; unguarded kiosk object; Courtyard/Glacier isolated spawns; Waterfront secondary weapon; Unearthed `marines6` split spawn |
| COSMETIC | 8 global + a handful | dead globals and dead scripts, timing polish, wrong comments |

| map | verdict |
|---|---|
| Overlook `ff10_prototype` | **PASS with BLOCKER-G1** (win purchase) |
| Courtyard `ff20_courtyard` | **PASS with BLOCKER-G1** + 1 RISK |
| Waterfront `ff30_waterfront` | **FAIL — 3 BLOCKERS** + BLOCKER-G1 |
| Beachhead `ff50_park` | **PASS with BLOCKER-G1** |
| Outpost `ff60_airview` | **FAIL — 3 BLOCKERS** + BLOCKER-G1 |
| Glacier `ff60_icecave` | **PASS with BLOCKER-G1** + 1 RISK |
| Holdout `ff70_holdout` | **PASS with BLOCKER-G1** — cleanest of the seven |
| Unearthed `marines6` | **PASS** + 1 RISK |
| Unearthed `tuned` | **PASS** |

---

## 2. Cross-map findings (all seven rebuilt maps)

### BLOCKER-G1 — the 10,000-point win purchase uses a campaign call, not Firefight's end path

`fe_mission_won`, present on all seven maps, is:

```
(set g_fe_won true)
[(fe_blip beacon)]
(sleep 30)
(ai_kill_no_statistics "gr_survival_all")
(sleep 60)
(game_won)
```

Evidence that `(game_won)` is the wrong call:

* **Bungie's own Firefight never uses it to end a match.** Every stock end condition —
  `survival_mode_end_condition_lives`, `…_generators`, `…_time`, `…_complete` — ends with
  `event_survival_*_win_*` + `submit_incident "survival_mm_game_complete"` +
  `(set b_survival_game_end_condition true)`. `survival_end_game` then waits on that boolean,
  `sleep_forever`s the whole survival machine, and calls `(mp_round_end_with_winning_team none)`.
  That is the end-the-match path.
* `(game_won)` appears **exactly once** in each stock Firefight cache, as the entire body of a
  leftover campaign script `end_mission`, which nothing in Firefight calls.
* **The author does not use it.** His `buy_mac` ends with `(wake you_win)`, and `you_win` ends with
  the three Bungie calls above. He has played his map; `game_won` is not in that path.

Likely runtime behaviour: the player pays the entire designed win price, the arena is wiped by
`ai_kill_no_statistics "gr_survival_all"`, and the match does not end. Because `g_fe_won` latches
`true` before the call, the purchase can never be retried, and the kiosk silently no-ops for the
rest of the session. Even in the best case where `game_won` does terminate something, the mod never
calls `survival_spartans_increment_score` or `submit_incident`, so the score and the medal/incident
record would be wrong.

`game_won` is a live opcode (`0x442`, void, 0 args, not `null="true"`) in the U13 table, so it will
execute — "it is in the table" was the whole justification recorded in `fe_shop_lib.hsc` §15, and
being in the table is not evidence about what it does inside a survival game.

Fix shape (author-attested): replace `(game_won)` with
`(survival_spartans_increment_score)`, `(event_survival_spartans_win_normal)`,
`(submit_incident "survival_mm_game_complete")`, `(set b_survival_game_end_condition true)` — all
four are declared in every one of the seven caches.

### RISK-G2 — the Longsword strike can permanently deadlock the stock weapon-resupply loop

`fe_deliver_strike` / `fe_ct_deliver_strike` / `fe_ho_deliver_strike` (Overlook, Courtyard,
Waterfront, Beachhead, Outpost, Holdout — Glacier has no strike station) drive `dm_longsword_01`
and end with `(object_destroy "dm_longsword_01")` seven seconds after starting a ten-second
animation.

Stock `survival_resupply_pod_spawn` drives the **same** device and then blocks on

```
(sleep_until (>= (device_get_position "dm_longsword_01") 0.4) 1)
```

before waking the weapon-drop pods. If a strike purchase lands inside that window, our
`object_destroy` removes the device the stock loop is polling, the condition can never become true,
and `survival_resupply_pod_spawn` — an infinite `sleep_until (begin … false)` loop — never
completes another cycle. Result: **no further weapon or grenade drops for the rest of the match.**
Our `device_set_position_track … 0` can also reset the track under the stock animation, but that
path self-heals because our animation then passes 0.4; only the destroy is unrecoverable.

### RISK-G3 — `fe_near` guards the player but never the kiosk

```
(script static boolean fe_near (unit who, object kiosk)
  (and (fe_valid who) (< (objects_distance_to_object who kiosk) k_fe_kiosk_radius)))
```

`objects_distance_to_object` returns a negative value when the object list is empty or the object is
absent, and `(< -1 radius)` is **true**. `fe_valid` covers the player side. Nothing covers the
kiosk. If an anchor is ever absent or destroyed, that station reports every player as "near",
regardless of where they actually are, and `fe_anyone_at`/`fe_buyer_at` fire once per
`k_fe_cooldown` (150 ticks) for anyone with the money. Bungie's own
`survival_health_pack_highlight` — the pattern this library cites as its precedent — tests
`(< (object_get_health pack) 0)` **and** `(< (object_get_health subject) 0)`.

Exposure is highest where anchors are `device_machine` doors: Holdout (3 of 6), Courtyard (2 of 6).
All anchors were verified present in the `scnr` with their expected placement flags, so this is a
latent hazard rather than a live one.

### COSMETIC, all seven maps

* `fe_retire_allies` is declared and **never called** (0 call sites on every map). Purchased allies
  are never retired at round or set end; the cap is the only governor. Intended or not, the script
  is dead.
* `g_fe_open` is written once by the startup script and **never read** (2 textual occurrences =
  declaration + the one `set`). The kiosks are gated by `wake`, not by this flag.
* `fe_gate_round` is declared and never called; every gate is on `survival_mode_set_get`.
* `g_fe_buys` / `g_fe_spartan_buys` are incremented and never read.
* Dead price/gate globals: `k_fe_cost_air` + `k_fe_gate_air` + `g_fe_air_rotor` on Courtyard,
  Glacier and Holdout (no air station on any of them); `k_fe_cost_strike` + `k_fe_gate_strike` on
  Glacier (no strike station).
* `fe_report` on Waterfront and Outpost is `(if g_fe_debug (print "fe: report"))` — an empty stub,
  and `print` is `null="true"` in U13 so it would not even print.
* The strike destroys the Longsword mid-flyby: stock waits for `device_get_position >= 0.4` of the
  ten-second animation before doing anything; ours does `(sleep 90)` → kill → `(sleep 120)` →
  destroy, i.e. 7 s total.
* `fe_shop_lib.hsc` §5 comment: "Argument order matches Bungie's own call
  `(objects_distance_to_object pack subject)`: first argument is object_list, second is object" —
  and then passes the **player** first and the kiosk second, i.e. the opposite of the call it cites.
  Harmless (the metric is symmetric for a one-element list) but the comment documents the wrong
  thing.
* Kiosk separation was measured from `scnr` placement positions. Three Holdout and two Courtyard
  anchors are doors; if a door's object origin translates while animating, the measured separation
  holds only in the closed state. Not verified either way.
* Six dormant kiosk threads each evaluate an eight-slot, sixteen-script-call predicate every five
  ticks. No stock map does anything that cheap-but-frequent on six threads; no evidence of a budget
  problem, noted only as a load characteristic.

### Patterns that were suspected and came back clean

* **`(sleep_until (begin … false))` as an infinite loop, with `sleep`s nested inside the
  condition.** Bungie uses this 33-39 times per stock Firefight cache (75 times in Unearthed),
  including a `sleep_until` nested inside another one's condition. The idiom is attested, not an
  experiment.
* **`ai_place` → `(sleep 1)` → `ai_set_team`.** This is verbatim Bungie: `survival_wave_spawn` does
  `(ai_place_wave …)` / `(sleep 1)` / `(survival_mode_set_bedlam_teams)`, and that script is a chain
  of `ai_set_team` calls. `fe_squad_commit_placed` has exactly the same ordering.
* **Allies carrying `team = default` in tag data.** Every squad in six of the seven stock caches is
  `default` (Glacier is 15 `default` / 9 `covenant`); Bungie assigns teams at runtime. The task
  brief's premise — that `default` is itself the defect — is wrong. See section 6.8.
* **Prices.** On the seven rebuilt maps every price exists in exactly **one** constant node (a
  `(global long k_fe_cost_*)`) and is passed as a parameter to `fe_transact` → `fe_buyer_at` /
  `fe_charge_at`. Desync is structurally impossible. Class 6 verified by reading every kiosk's call
  in the decompiled bytecode: no literal price appears anywhere in any `fe_*` script.
* **Charging the buyer.** `fe_buyer_at` is an `or` over slots 0-7 and `fe_charge_at` is a `cond`
  over the identical predicates in the identical order, so the charged slot is the slot that
  satisfied the test. `player0` appears nowhere. Class 7 clean on all seven.
* **Object-name resolution in the compiled bytecode.** Every string argument naming a kiosk, ammo
  crate or the Longsword was resolved against the map's own `object names` block through the
  expression's stored value: **100 % correct on all seven maps**, including the `#`-prefixed door
  names (`#_m70_door_small_03` → index 63 → `#_m70_door_small_03`, etc.). The leading `#` survives
  compilation.
* **Opcode arity.** `ai_set_task` 3, `ai_survival_cleanup` 3, `sound_impulse_start` 3,
  `device_animate_position` 6, `chud_track_object` 2, `ai_get_object` 1, `objects_distance_to_object`
  2, `human_player_in_game_get` 1 — every call site matches the U13 declaration.
* **Squad flags.** All sixteen ally squads across the seven maps carry `0x100` =
  `no wave spawn`, so the Firefight wave spawner can never fill an ally handle with Covenant.
  Glacier's `sur_fireteam_06` carries `0x40` = `fireteam absorber` and is correctly left untouched.
* **Cell ranks.** `major upgrade` 3 = `none` on the trooper cells and 4 = `all` on the Spartan
  cells, per `major_upgrade_enum` = `[normal, few, many, none, all]`. Matches the design note.

---

## 3. Defect-class matrix

Each cell is an independent measurement on that map, not an inference from a neighbour.

| # | class | OV | CT | WF | BH | OP | GL | HO | UE-m6 | UE-t |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | wave-clear deadlock | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | `ai_survival_cleanup` eats allies | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3 | ungated `ai_erase` / half-applied hook | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 4 | cap not enforced | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| 5 | overlapping kiosks | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | n/a | n/a |
| 6 | price node desync | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 7 | charging the wrong player | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 8 | spawn outside the arena | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠ | ✅ |
| 9 | culled scripts | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 10 | shared choice blocks | ✅ | ✅ | ⚠ | ✅ | ⚠ | ✅ | ✅ | ✅ | ✅ |
| 11 | expression-count gap | benign — section 5 | | | | | | | | |

### Class 1 — wave-clear deadlock: clean on all nine, by two independent reads

`survival_wave_living_count` was read out of each mod cache's own bytecode. It is byte-identical to
stock on all seven:

```
(+ (ai_living_count "gr_survival_all") (ai_living_count "gr_survival_remaining")
   (max 0 (- (ai_living_count ai_sur_phantom_01) s_sur_dropship_crew_count)) … ×4)
```

Squad-group parentage read from the `scnr`:

| map | `gr_survival_fireteams` stock parent | shipped parent | `gr_survival_waves` parent |
|---|---|---|---|
| Overlook | `gr_survival_waves` | **ROOT** | `gr_survival_all` |
| Courtyard | `gr_survival_waves` | **ROOT** | `gr_survival_all` |
| Waterfront | `gr_survival_waves` | **ROOT** | `gr_survival_all` |
| Beachhead | `gr_survival_waves` | **ROOT** | `gr_survival_all` |
| Outpost | `gr_survival_waves` | **ROOT** | `gr_survival_all` |
| Glacier | **`gr_survival_extras`** | **ROOT** | `gr_survival_all` |
| Holdout | `gr_survival_waves` | **ROOT** | `gr_survival_all` |

The ally group is a genuine root on every map (parent index out of range = ROOT, ancestry chain
length 1). Nothing re-parents it at runtime: a full-cache grep found no `ai_*` call that can change
group parentage, and the only runtime group writes are `ai_reset_objective` / `ai_set_task` /
`ai_survival_cleanup` / `ai_living_count`, none of which re-parent.

For Unearthed, the author's own ally group `gr_survival_marines` is **ROOT** with
`gr_survival_marines_followers` as its child; neither variant changes that.

### Class 2 — `ai_survival_cleanup` on paid allies: clean on all seven

Every `ai_survival_cleanup` call site in every shipped cache, read from bytecode:

```
(ai_survival_cleanup "gr_survival_all"       true  true)
(ai_survival_cleanup "gr_survival_remaining" true  true)
(ai_survival_cleanup "gr_survival_extras"    true  true)
(ai_survival_cleanup "gr_survival_all"       false false)
(ai_survival_cleanup "gr_survival_remaining" false false)
(ai_survival_cleanup "gr_survival_extras"    false false)
(ai_survival_cleanup "gr_survival_fireteams" true  true)   ← ours, in fe_retire_allies, never called
```

The ally group is not a descendant of `all`, `remaining` or `extras` on any map, so the stock
per-wave sweep cannot reach it. **Glacier is the map this would have killed** — its ally group
shipped under `gr_survival_extras` — and the reparent was applied.

### Class 3 — ungated `ai_erase`, half-applied hooks: clean on all seven

* No map uses a drop squad for allies. All seven use empty fireteam handles
  (`sur_fireteam_01..04`, or `sq_elite_fireteam_01..04` on Beachhead).
* The stock `(ai_erase "sq_sur_drop_0N")` block and the closing `(set g_sur_drop_spawn true)` are
  present and unmodified on every map, and now touch nothing the player paid for.
* **No `fe_*_stock_hooks` script exists in any shipped cache.** `src/hsc/ff70_holdout_stock_hooks.hsc`
  (which sets `g_sur_drop_spawn false` / `g_sur_drop_limit 0`) was correctly abandoned when Holdout
  moved to the fireteam pattern. The hook is therefore not half-applied — it is absent, which is the
  right state.
* Decisive proof there is no leftover: a full script-table diff of every shipped map against its
  stock counterpart found **zero stock scripts removed, zero stock globals removed, zero stock
  globals changed, and zero stock script bodies changed** on all seven, with the single exception of
  the `player_count` shim (class 9). The diff against Bungie's text is empty.

### Class 4 — cap enforcement: **FAILS on Waterfront and Outpost**

The shared cap is `fe_allies_alive` = `(ai_living_count "gr_survival_fireteams")`, and every ally
squad was confirmed by tag read to be a direct member of that group on all seven maps — including
Beachhead's differently-named `sq_elite_fireteam_01..04`. So `k_fe_actor_limit` does bind the total.

The failure is in the *per-squad* half. Five maps gate a purchase on a squad actually being empty:

```
; Overlook / Beachhead
(script static boolean fe_has_room
  (and (>= (fe_slots_free) k_fe_squad_size)
       (or (= (ai_living_count "sur_fireteam_01") 0) (= (ai_living_count "sur_fireteam_02") 0))))
; Courtyard / Glacier / Holdout
(script static boolean fe_has_room
  (and (>= (fe_slots_free) k_fe_squad_size) (fe_trooper_slot_free)))
```

Waterfront and Outpost do not:

```
(script static boolean fe_has_room
  (>= (fe_slots_free) k_fe_squad_size))
```

and they deliver by blind positional rotation instead of by emptiness:

```
(script static void fe_deliver_squad
  (cond ((= g_fe_rotor 0) (fe_squad_commit_placed "sur_fireteam_01"))
        (true             (fe_squad_commit_placed "sur_fireteam_02")))
  (set g_fe_rotor (+ g_fe_rotor 1))
  (if (>= g_fe_rotor 2) (set g_fe_rotor 0))
  (set g_fe_buys (+ g_fe_buys 1)))
```

Traced: two trooper squads of four, `k_fe_actor_limit` 12, `k_fe_squad_size` 4.
Buy 1 → `sur_fireteam_01` placed, 4 alive, rotor 1. Buy 2 → `sur_fireteam_02` placed, 8 alive,
rotor 0. Buy 3 → `fe_slots_free` = 12 − 8 = 4 ≥ 4, **gate passes**, 500 is charged, rotor 0 →
`(ai_place "sur_fireteam_01")` on a squad that still has four living members. The map can field at
most 8 troopers, so the third purchase can never deliver.

The Spartan path fails differently: `fe_has_spartan_room` enforces the 4-body sub-cap but not
emptiness, so with `sur_fireteam_03` alive (2) and `sur_fireteam_04` wiped (0),
`fe_spartans_alive` = 2, `2 + 2 ≤ 4` passes, and rotor 0 re-places the **living** squad 03 while the
empty squad 04 goes unused.

Either way the buyer is charged and gets nothing (or, if `ai_place` on a live squad stacks actors,
gets more bodies than the cap allows). This is the only defect class where the five careful maps and
the two careless maps diverge, and it is exactly the shape the brief warned about.

### Class 5 — kiosk overlap: clean on all seven, independently measured

Anchor positions were read from the `scnr` `controls` and `machines` blocks of each shipped map. The
minimum pairwise 3-D separation of each map's *own* station set, and the largest radius that cannot
reach two stations from one standing position (`min / 2`):

| map | min separation | pair | max safe radius | shipped radius | margin |
|---|---|---|---|---|---|
| Overlook | **1.965** | `health_pack0` ↔ `health_pack4` | 0.983 | **0.90** | 8.4 % |
| Courtyard | **2.432** | `health_pack4` ↔ `#_door_interior_large_logo_03` | 1.216 | **1.10** | 9.5 % |
| Waterfront | **3.039** | `health_pack3` ↔ `health_pack2` | 1.519 | **1.45** | 4.8 % |
| Beachhead | **3.055** | `health_pack0` ↔ `health_pack4` | 1.527 | **1.45** | 5.3 % |
| Outpost | **2.336** | `health_pack4` ↔ `health_pack2` | 1.168 | **1.10** | 5.8 % |
| Glacier | **3.425** | `health_pack4` ↔ `health_pack5` | 1.713 | **1.45** | 15.4 % |
| Holdout | **4.639** | `#_m70_door_small_05` ↔ `health_pack2` | 2.319 | **1.45** | 37.5 % |

Every shipped radius is below its map's limit. The compiled value was read out of each map's own
startup script, not from source:

| map | declared default | `(set k_fe_kiosk_radius …)` in startup |
|---|---|---|
| Overlook | 2.5 | **0.9** |
| Courtyard | 2.5 | **1.1** |
| Waterfront | 1.1 | **1.45** |
| Beachhead | 2.5 | **1.45** |
| Outpost | 1.1 | **1.1** |
| Glacier | 2.5 | **1.45** |
| Holdout | 2.5 | **1.45** |

Five of seven ship the library default of 2.5 as the declared value and rely on the startup script
to overwrite it. The overwrite is the first statement after `(sleep 30)` and precedes every `wake`,
so no kiosk can ever observe 2.5 — verified by reading the compiled statement order. Waterfront's
declared default (1.1) and Outpost's (1.1) are harmless either way. Thin absolute margins worth
noting: Outpost has only **0.068 world units** of headroom, Overlook 0.083, Waterfront 0.069.

### Class 6 — price node desync: clean on all nine

Seven rebuilt maps: one node per price, parameter-passed. Verified by reading every kiosk's
`fe_transact` argument in the compiled bytecode — all are `k_fe_cost_*` global references, no
literals.

Unearthed (16 nodes per price, one pair per player slot) — every price, both variants and the
author's map, extracted from bytecode:

| script | affordability nodes | deduction nodes |
|---|---|---|
| `buy_hologram` / `buy_evade` | 8 × 200 | 8 × −200 |
| `buy_speedboost` / `buy_powerfist` | 8 × 300 | 8 × −300 |
| `buy_power` | 8 × 350 | 8 × −350 |
| `buy_dropshield` / `buy_jetpack` | 8 × 400 | 8 × −400 |
| `buy_marines` / `buy_ammo1` / `buy_overshield` / `buy_camo` / `deposit` | 8 × 500 | 8 × −500 |
| `buy_turret1` / `buy_turret2` | 8 × 750 | 8 × −750 |
| `buy_mysterybox` | 8 × 950 | 8 × −950 |
| `buy_hog` / `buy_ammo2` | 8 × 1000 | 8 × −1000 |
| `buy_hogup` | 8 × 2000 | 8 × −2000 |
| `buy_tank` / `buy_turret3` | 8 × 3500 | 8 × −3500 |
| `buy_mac` | 8 × 10000 | 8 × −10000 |
| `withdraw` | (none, by design) | 8 × **+500** |

All 21 priced scripts agree across all 16 nodes, and are identical to the author's. `withdraw`
correctly has no affordability clause and a positive award — the same asymmetry our `fe_credit_at`
has.

### Class 8 — spawn points inside the arena: clean on all seven, calibrated

Every ally spawn point on every map is **inside** that map's `safe_zone_soft` sector polygon and
**inside no kill-volume polygon**. The test reports 16/16 player starting locations inside the safe
zone and 0/16 in a kill volume on every map, and correctly rejects Holdout's stock out-of-base drop
pods, so both the positive and the negative direction are calibrated.

A weaker signal worth recording: **no ally spawn point on any map equals any Bungie-authored point.**
The nearest Bungie reference is always a player starting location, never a stock squad spawn point,
and the offsets are:

| map | nearest-player-start distance per ally spawn point |
|---|---|
| Overlook | 1.47, 2.59, 5.15, 5.70, **15.01** |
| Courtyard | 0.85, 9.03, **22.06**, **23.26** |
| Waterfront | 0.77, 0.87, 5.98, 13.53, 14.42, 15.82 |
| Beachhead | 1.13, 6.58, 8.74, 10.18, 13.07 |
| Outpost | 0.44, 0.64, 0.69, 4.96, **15.75** |
| Glacier | 0.63, 7.96, 9.00, **28.86** |
| Holdout | 1.34, 2.37, 2.80, 3.47 |

Holdout is the only map whose ally spawns are all tight to the respawn cluster. The outliers are
in-arena (verified) but are not "on the player respawn zones", which is what the source comments
claim — see section 6.5. **This audit cannot test walkability**: the structure BSP collision was not
read, so a point can be inside the playable volume and still be on a ledge, inside geometry, or
unreachable by pathfinding. Those seven outliers are the places to look first if an ally fails to
appear in play.

### Class 9 — culled scripts: clean on all nine, and the premise was wrong

Every `script_reference` expression in all nine shipped caches (plus the author's map and all seven
stocks) was resolved: target index in range, and declared parameter count equal to supplied argument
count.

| cache | script refs | out of range | arity mismatches |
|---|---|---|---|
| Overlook | 645 | 0 | 0 |
| Courtyard | 654 | 0 | 0 |
| Waterfront | 645 | 0 | 0 |
| Beachhead | 644 | 0 | 0 |
| Outpost | 644 | 0 | 0 |
| Glacier | 626 | 0 | 0 |
| Holdout | 654 | 0 | 0 |
| Unearthed ×3 | 616 | 0 | 0 |

The only name disagreement is `player_count`, and it is a **reader artifact, not a defect**:

* In **stock** Holdout the three `(player_count)` call sites target script index **157**, which is a
  real `(script static short …)` whose body is `(list_count (players))`. Bungie declares it. Our
  `sid_table_for_scripts.py` cannot resolve its stringID and mis-renders the name as
  `prop_firefight_difficulty_highest_official_score`.
* The identical artifact appears in the **author's untouched** Unearthed map, at index 149. A map
  nobody in this project has ever written to.
* In the five shipped maps that carry the shim (Courtyard, Waterfront, Outpost, Glacier, Holdout) the
  three call sites target index **0**, the injected script, whose body is
  `(list_count (players_human))`. Resolution is self-consistent; nothing dangles.
* Overlook and Beachhead carry **no shim** — their call sites still target index 157, and their
  stock-vs-mod body diff is empty. The shim was only injected where the round trip needed it.

One cosmetic consequence: on the five shimmed maps Bungie's original script survives at its old
index as two expressions of dead code, and the shim's body uses `players_human` where stock used
`players`. In Firefight every player is on the human team, so the two return the same count.

### Class 10 — shared choice blocks: clean on all nine against stock; two ally↔ally aliases remain

The decisive test is a full cell-level tag diff of each shipped map against its stock counterpart,
covering `team`, `flags`, group parent, initial objective/task, spawn-point list, cell count,
`major upgrade`, and the resolved contents of all four choice blocks (character, primary weapon,
secondary weapon, equipment).

**Result: on every one of the seven maps, exactly four squads changed — the four ally squads — and
nothing else.** No stock squad's weapons, characters, equipment, team, group or spawn points differ
from Bungie's. The Waterfront/Outpost regression where ally weapon edits had re-armed stock snipers
and a drop squad is **fixed and stays fixed**.

Two ally↔ally aliases do remain, both benign but worth knowing:

* **Waterfront**: `sur_fireteam_01` and `sur_fireteam_02` share one primary-weapon choice block
  (both `dmr`), and all four ally cells share one secondary-weapon block (`plasma_rifle`).
* **Outpost**: `sur_fireteam_01` and `sur_fireteam_02` share one primary-weapon choice block
  (`dmr` weight 5, `assault_rifle` weight 1).

On Overlook and Beachhead the two trooper squads deliberately carry *different* primaries (`dmr` vs
`assault_rifle`) from separate blocks, which is what the design note describes. The shared blocks
mean a future per-squad weapon tweak on Waterfront or Outpost would silently edit both squads. And
the Waterfront secondary is a **Covenant plasma rifle on all four ally squads** — no other map
assigns a secondary at all.

The resolved ally loadouts, for the record:

| map | troopers 01 / 02 | Spartans 03 / 04 |
|---|---|---|
| Overlook | `dmr` / `assault_rifle` | `sniper_rifle, rocket_launcher, spartan_laser, plasma_turret, grenade_launcher` |
| Courtyard | `dmr` / `dmr` | same five |
| Waterfront | `dmr` / `dmr` (+ `plasma_rifle` secondary ×4) | same five |
| Beachhead | `dmr` / `assault_rifle` | `sniper_rifle, rocket_launcher, spartan_laser, grenade_launcher` |
| Outpost | `dmr`×5 + `assault_rifle`×1 / same | same five |
| Glacier | `dmr` / `dmr` | `shotgun, rocket_launcher, spartan_laser, grenade_launcher` |
| Holdout | `dmr` / `dmr` | same five |

All sixteen ally cells use character palette entry `objects\characters\null\ai\null_cov_default`,
as designed.

---

## 4. Per-map detail

### Overlook — `ff10_prototype` — PASS with BLOCKER-G1

Six stations on `health_pack0..5`, all `controls` with placement flags `0x00000000`. Radius 0.90
against a 1.965 minimum separation. Ally group `gr_survival_fireteams` reparented from
`gr_survival_waves` to ROOT; `sur_fireteam_01..04` are its members, `05`/`06` left empty.
Cells 4/4/2/2 with 4/4/2/2 spawn points — correctly matched. `obj_fireteams` task `fireteams`,
`follow = player`, radius 3.0, squad-group filter `gr_survival_fireteams`.

* COSMETIC: `fe_deliver_squad` is a two-clause `cond` with no `(true …)` fallback. Unreachable
  because `fe_has_room` guarantees one squad is empty, but `g_fe_buys` is incremented
  unconditionally afterwards, so if the guard were ever bypassed the counter would lie.
* RISK (minor): ally spawn point `(156.707, 44.285, 0.43)` is 15.0 wu from the nearest respawn.
  In-arena, walkability unverified.

### Courtyard — `ff20_courtyard` — PASS with BLOCKER-G1, 1 RISK

Six stations: `health_pack0/1/4/2` plus the door machines `#_door_interior_large_logo_03` (ammo) and
`_04` (strike). Both door names resolve correctly in the compiled bytecode. Radius 1.10 against a
2.432 minimum — the binding pair is a health station against a door.
`fe_squad_empty` / `fe_trooper_slot_free` / `fe_spartan_slot_free` all present; cap logic correct.
`fe_mission_won` takes a beacon parameter and blips the kiosk.

* **RISK**: two of the four ally spawn points are at `(-92.596, 57.432, 18.4)` and
  `(-92.531, 58.622, 15.755)` — 22-23 wu from the respawn cluster and on a **different storey**
  (2.6 wu of vertical separation across 1.2 wu of horizontal). `sur_fireteam_04` (Spartans) uses
  *only* those two points, so a 1,000-point Spartan purchase puts both bodies up there, away from
  the shop and the player. In-arena (verified inside `safe_zone_soft_01`), but this is the most
  likely place on this map for an ally to appear somewhere useless.
* COSMETIC: `k_fe_cost_air` 1000 / `k_fe_gate_air` 2 / `g_fe_air_rotor` declared and set; no air
  station exists. Banshees are stock-owned on this map, correctly left alone.

### Waterfront — `ff30_waterfront` — FAIL, 3 BLOCKERS

Six stations on `health_pack0..5`, radius 1.45 against 3.039. Group reparent correct, ally squads in
group, spawn points in-arena, no stock script touched, prices single-node, buyer charged correctly.
Then:

* **BLOCKER WF-1** — `fe_has_room` is budget-only, no squad-emptiness term. Class 4 above.
* **BLOCKER WF-2** — `fe_deliver_squad` / `fe_deliver_spartans` rotate on `g_fe_rotor` /
  `g_fe_spartan_rotor` without consulting which squad is actually empty. Class 4 above. Combined
  with WF-1, the third and every subsequent trooper purchase charges 500 and `ai_place`s a live
  squad.
* **BLOCKER WF-3** — `sur_fireteam_01` and `sur_fireteam_02` declare `normal diff count = 4` but
  carry only **2 spawn points each**. Every other map in the pack gives a count-4 cell four points
  (Overlook 4/4, Courtyard 4/4, Beachhead 4/4, Glacier 4/4, Holdout 4/4), and the Unearthed
  `marines6` build raised both the count and the point list together when it went from 4 to 6. A
  500-point trooper purchase here has half the placement sites it needs.
* RISK — all four ally cells share one secondary-weapon choice block containing `plasma_rifle`.
  Purchased human allies carry a Covenant weapon; no other map sets a secondary at all.
* RISK — `sur_fireteam_01` and `_02` share one primary-weapon block, so they are identical
  (`dmr`/`dmr`) where Overlook and Beachhead deliberately differ.
* COSMETIC — `fe_report` is a dead debug stub.

### Beachhead — `ff50_park` — PASS with BLOCKER-G1

The one map whose ally handles are named differently: `sq_elite_fireteam_01..06`, not
`sur_fireteam_*`. Confirmed by tag read that `01..04` are direct members of `gr_survival_fireteams`
(group index 6), which is ROOT, so `fe_allies_alive` counts them and the cap binds. This was the
obvious place for a class-4 miss and it is clean. Squad `initial zone` is `-1` here where other maps
have `0`; harmless, the stock handles ship that way.

Radius 1.45 against 3.055. Cells 4/4/2/2 with 4/4/2/2 spawn points. Cell names are `grunt_heavy`
(copied from a donor cell) — a label only; the character choice is `null_cov_default` and the
loadouts are human.

* Note, checked and cleared: `dm_longsword_01` has placement flags `0x00000000` on this map — it
  exists from map load, unlike the other six where it is `0x1` (script-created). `fe_deliver_strike`
  ends with `(object_destroy "dm_longsword_01")`, which on this map destroys a permanently placed
  object. **Stock Beachhead does exactly the same** (`object_create` → track → animate → wait →
  `object_destroy`), so this is Bungie's own handling and not a defect. RISK-G2 still applies.
* COSMETIC: `fe_deliver_squad` two-clause `cond` with no fallback, as Overlook.
* Minor: one ally spawn point `(-165.753, 49.646, -34.4)` falls inside the *bounding box* of
  `kill_soft_11` but **outside its polygon**; with 0/16 Beachhead player starts inside any kill
  polygon, the polygon test is the trustworthy one and this point is clear.

### Outpost — `ff60_airview` — FAIL, 3 BLOCKERS

Six stations on `health_pack0..5` (`0` troopers, `1` Spartans, `4` ammo, `5` strike, `2` bank,
`3` win). Radius 1.10 against a 2.336 minimum — **0.068 world units of headroom, the thinnest in the
pack.**

* **BLOCKER OP-1 / OP-2 / OP-3** — identical to WF-1/2/3. `fe_has_room` is budget-only; delivery
  rotates blindly on `g_fe_rotor` / `g_fe_spartan_rotor`; `sur_fireteam_01` and `_02` declare count 4
  with only 2 spawn points.
* RISK — `sur_fireteam_01` / `_02` share one primary-weapon block.
* COSMETIC — the `obj_fireteams` task `fireteams` on this map has **follow radius 8.0**; every other
  map has 3.0. Allies will trail considerably further behind the player here.
* COSMETIC — `fe_report` dead stub.
* Minor, cleared: one ally spawn point sits in `kill_soft_frontfield01`'s bounding box but outside
  its polygon; 6/16 of this map's own player starts also fall in kill bounding boxes, so the box test
  is meaningless here and the polygon test is clean.

### Glacier — `ff60_icecave` — PASS with BLOCKER-G1, 1 RISK

**Five** stations, not six: `health_pack0` troopers, `1` Spartans, `2` ammo, `4` bank, `5` win.
`health_pack3` is deliberately left as a pure heal station. There is no strike kiosk and no
`fe_deliver_strike` script, which matches `src/hsc/ff60_icecave.hsc` exactly — intentional, not a
build loss. Consequence: Glacier is the only map **exempt from RISK-G2**.

Radius 1.45 against a 3.425 minimum. `fe_squad_empty` family present, cap logic correct, cells
4/4/2/2 with 4/4/2/2 spawn points, Spartan loadout correctly uses `shotgun` instead of
`sniper_rifle` for this map's close quarters.

* **This is the map the reparent saved.** Its `gr_survival_fireteams` shipped under
  `gr_survival_extras` — the one group stock sweeps with `ai_survival_cleanup … true true` every
  wave — and the build moved it to ROOT. `src/hsc/ff60_icecave.hsc` asserts the opposite in a comment
  (section 6.4).
* **RISK**: ally spawn point `(-72.151, 260.836, -104.489)` is **28.9 wu** from the nearest player
  respawn, the most isolated ally spawn in the entire pack, and 1.8 wu lower than its three siblings.
  Inside `safe_zone_soft` and in no kill polygon, so in-arena, but it is the highest-probability
  "where did my trooper go" location in the mod. `sur_fireteam_01` and `_02` both list it.
* COSMETIC: `k_fe_cost_strike` 3000, `k_fe_gate_strike` 1, `k_fe_cost_air` 1000, `k_fe_gate_air` 2
  and `g_fe_air_rotor` are all declared and never read.
* COSMETIC: `sur_fireteam_06` carries flags `0x40` (`fireteam absorber`) and a live Brute wave cell;
  correctly untouched, exactly as the source note says.

### Holdout — `ff70_holdout` — PASS with BLOCKER-G1; cleanest of the seven

Six stations: `health_pack0` troopers, `health_pack5` Spartans, `#_m70_door_small_05` bank,
`#_m70_door_ff_02` ammo, `#_m70_door_small_03` strike, `health_pack2` win. All six names resolve
correctly in bytecode.

* **Best separation in the pack**: 4.639 wu minimum against a 1.45 radius — 37 % margin. The old
  1.333-wu `health_pack3` / `#_m70_door_ff_02` pairing is gone.
* **Best spawn placement in the pack**: all four ally spawn points within 3.5 wu of a player
  respawn, all inside the safe zone.
* **Diff against Bungie's script text is empty.** No `fe_holdout_stock_hooks`, no
  `g_sur_drop_spawn` / `g_sur_drop_limit` writes, stock `survival_drop_spawn` and
  `survival_drop_pod_manager` byte-identical to stock. The drop-squad-era hooks are fully gone, not
  half-applied. The port to fireteams removed the need for them, exactly as the source claims.
* `fe_squad_empty` family present, cap logic correct, cells 4/4/2/2 with 4/4/2/2 spawn points.
* Three of six anchors are doors → most exposed map to RISK-G3.
* COSMETIC: `k_fe_cost_air` / `k_fe_gate_air` / `g_fe_air_rotor` dead (no air tier; stock owns the
  banshees, correctly).
* COSMETIC: the injected `player_count` shim sits at script index 0 and Bungie's original survives
  at its old index as dead code.

### Unearthed `marines6` — PASS, 1 RISK

The script table is **identical to the author's shipped, playtested map** except two constant nodes:
the marine cap `8 → 12` in `infantry_limit`. 485 scripts, 277 globals, 52,711 expressions, all
matching the author byte for byte otherwise. Nothing in this variant is our own logic, so every
author-attested pattern applies unchanged.

Cap coherence, traced: `gr_survival_marines` (ROOT) contains `sq_sur_ini_odsts`;
`gr_survival_marines_followers` (its child) contains `marine_rein`. `ai_living_count` on a group is
recursive, so the cap counts both. Author: 4 + 4 = 8, cap 8 — exact. `marines6`: 6 + 6 = 12, cap 12
— **exact**. The edit is coherent.

Tag changes versus the author, both squads, full diff: `sq_sur_ini_odsts` count 4 → 6 (it already had
6 spawn points, so consistent) and `marine_rein` count 4 → 6 **with its spawn-point list grown 4 → 6**
— the right way to do it, and the thing Waterfront and Outpost failed to do.

* **RISK**: the two *added* `marine_rein` spawn points are `(47.407, -56.076, 8.532)` and
  `(50.224, -56.195, 8.511)` — copied verbatim from `sq_sur_ini_odsts`. The squad's original four
  points are at `(45.8-47.7, 37.5-38.8, -3.7..-3.9)`. The new pair is ~95 wu away in Y and ~12 wu
  higher, at the **initial ODST spawn**, not the pelican drop. Two of six purchased marines will
  materialise across the map from the other four. The location is legitimate (the author spawns ODSTs
  there at map start), so this is a placement bug, not an out-of-bounds bug.
* Preserved author bug, not ours: at exactly the cap both `infantry_limit` branches are true
  (`>= 12` and `<= 12`). Neutralised by the `marines_bought_first_time` latch, which is the real
  limiter in the author's design — `buy_marines` destroys its own kiosk and only
  `marine_resupply` restores it once the whole group is wiped. The author shipped the same overlap
  at 8.
* The safe-zone containment test does **not** calibrate on Unearthed (0/16 player starts inside
  `safe_zone_soft`, because this scenario's geometry and insertion points differ), so no containment
  claim is made for this map. Its spawn points are the author's, in a map that has been played.

### Unearthed `tuned` — PASS

Scripts identical to `marines6` (and therefore to the author except the cap). The only tag change
versus the author is `sq_sur_ini_odsts` count 4 → 6; `marine_rein` is left untouched at 4 bodies /
4 spawn points, so the `marines6` split-spawn risk does **not** apply here.

Maximum marines = 6 + 4 = 10 against a cap of 12, so `infantry_limit` can never trip. Harmless: the
one-shot latch governs, as in the author's build. This is the more conservative of the two Unearthed
variants and the one shipped in `Firefight-Reinforcements-Safe`.

---

## 5. The expression-count gap — BENIGN, and now explained with numbers

This was the highest-value unexplained item. It is explained.

Three independent measurements settle it.

**(a) Nothing was lost at script or global granularity.** A full name-keyed diff of every stock
cache against its shipped counterpart:

| map | stock scripts missing | stock globals missing | stock globals changed | stock bodies changed |
|---|---|---|---|---|
| Overlook | 0 | 0 | 0 | 0 |
| Courtyard | 0 | 0 | 0 | 1 (`player_count` shim) |
| Waterfront | 0 | 0 | 0 | 1 (shim) |
| Beachhead | 0 | 0 | 0 | 0 |
| Outpost | 0 | 0 | 0 | 1 (shim) |
| Glacier | 0 | 0 | 0 | 1 (shim) |
| Holdout | 0 | 0 | 0 | 1 (shim) |

Every one of Bungie's 335-377 script bodies is textually identical, token for token, after the round
trip. No stock logic is missing.

**(b) The gap is Bungie's compiler slack, and the rebuild packs it out.** Walking the expression
graph from every script root and every global initialiser:

| cache | total `hs_syntax_datum` | reachable | **unreachable** |
|---|---|---|---|
| stock Overlook | 19,261 | 15,362 | **3,899** |
| mod Overlook | 16,639 | 16,639 | **0** |
| stock Courtyard | 18,821 | 14,943 | **3,878** |
| mod Courtyard | 16,220 | 16,220 | **0** |
| stock Waterfront | 19,373 | 15,440 | **3,933** |
| mod Waterfront | 16,728 | 16,728 | **0** |
| stock Beachhead | 19,888 | 15,902 | **3,986** |
| mod Beachhead | 17,179 | 17,179 | **0** |
| stock Outpost | 18,841 | 15,015 | **3,826** |
| mod Outpost | 16,303 | 16,303 | **0** |
| stock Glacier | 17,415 | 13,650 | **3,765** |
| mod Glacier | 14,865 | 14,865 | **0** |
| stock Holdout | 20,164 | 16,169 | **3,995** |
| mod Holdout | 17,446 | 17,446 | **0** |

Bungie's shipped tables carry 3,765-3,995 expression records that **no script and no global can
ever reach**. The recompiler emits a packed table with zero. Reachable expressions — the only ones
that can execute — **increase** on every map: Holdout 16,169 → 17,446 (+1,277), Overlook
15,362 → 16,639 (+1,277), Beachhead 15,902 → 17,179 (+1,277), Courtyard +1,277, Waterfront +1,288,
Outpost +1,288, Glacier +1,215. That increment is the shop library, and it is almost exactly
constant across maps — as it should be, since the library is almost the same on each.

**(c) A control that was never recompiled keeps its slack.** `ff_unearthed` was tag-edited only, its
script table never round-tripped: author 52,711 total / 47,937 reachable / **4,774 unreachable**, and
both shipped variants are 52,711 / 47,937 / 4,774 — identical. That independently proves the
unreachable records are a property of Bungie's compiler output and that recompilation, not our edit,
is what removes them.

**Verdict: benign.** The gap is dead-slot removal plus shop addition, in the right proportions, on
every map. The stated figure of 17,889 for Holdout belongs to a superseded build; the map actually
shipping is 418 scripts / 233 globals / 17,446 expressions.

---

## 6. Where `project/research/` and `src/hsc/` are wrong

Eight documented beliefs did not survive independent checking. Three of them matter.

**6.1 `research/14` §6.5 stops one call short of the author's win condition, and that omission is
the direct cause of BLOCKER-G1.** The doc records: "`buy_mac` succeeding blips
`sc_cannon_cruiser_target` to all eight players and calls `(wake you_win)`. The 10,000-point MAC
strike *is* the win condition." It never traces `you_win`. `you_win` ends with
`(event_survival_spartans_win_normal)`, `(submit_incident "survival_mm_game_complete")`,
`(set b_survival_game_end_condition true)` — the three calls that actually end a Firefight match.
Because the teardown never wrote them down, `fe_shop_lib.hsc` §15 reached for `(game_won)` and
justified it with "it IS in the U13 table", which is a statement about the opcode table and not
about Firefight.

**6.2 `research/21` §6 explains the expression gap with a hand-wave that is not the explanation.**
It says the gap "reflects how `decompile.py` counts nodes versus how Blamite emits them, and the
round-trip compiles cleanly either way", and calls it "a standing characteristic of the toolchain".
The measured cause is specific: Bungie ships 3,765-3,995 unreachable expression records per map and
the recompiler emits zero, while reachable expressions rise by ~1,250. Section 5. `decompile.py`
counts correctly; there was nothing to excuse.

**6.3 The class-9 premise is wrong.** "Holdout's own bytecode called `player_count`, which was
neither an opcode nor a declared script." Stock Holdout declares it at script index **157**, and all
three call sites target that index. The same unresolvable-stringID artifact appears in the author's
untouched Unearthed map at index 149. `build/ovbh/decomp_ovbh.sh`'s comment is closer — it calls it a
rename of "the ONE script our reader mis-names" — but the `player_count` script was never culled and
never missing. The shim is harmless but was not strictly necessary.

**6.4 `src/hsc/ff60_icecave.hsc` is wrong about Glacier needing no reparent.** The comment reads:
"Research/20 concluded Glacier needs no reparent because its `gr_survival_fireteams` (squad group 9)
…". Stock Glacier parents that group to **`gr_survival_extras`**, the one group stock sweeps with
`ai_survival_cleanup "gr_survival_extras" true true` on every wave end. The reparent was required.
The shipped map has it, so the build is right and the comment is wrong.

**6.5 The ally spawn points were not "authored on that map's `spartan_respawn_*` player respawn
zones".** `src/hsc/ff10_prototype.hsc`, `ff50_park.hsc` and the shared library all state this. **No
ally spawn point on any of the seven maps equals any Bungie-authored point** — not a player starting
location, not a stock squad spawn point. The nearest player respawn is 0.44 to 28.86 wu away
(table in class 8). They are hand-authored coordinates in the neighbourhood of the respawn cluster.
All are inside the playable volume, which is the thing that matters, but the provenance claim
overstates the evidence and hides the seven outliers.

**6.6 `research/21` describes a build that is not what shipped.** It reports Holdout's reference
build as 423 scripts / 235 globals / 17,889 expressions. `ready-to-install/ff70_holdout.FINAL.map` is
**418 / 233 / 17,446**, and contains no `fe_holdout_stock_hooks`. The doc predates the fireteam port.

**6.7 `fe_shop_lib.hsc` §5 documents the opposite of its own code.** The comment claims the
`objects_distance_to_object` argument order matches Bungie's `(objects_distance_to_object pack
subject)` with "first argument is object_list"; the code passes the player first and the kiosk
second. Functionally harmless, since the metric is symmetric for a one-element list.

**6.8 The audit brief's own premise about teams is wrong, and the maps are right.** The brief asks
that "allies must actually be on the player's team, not `default`". Every ally squad on all seven
maps carries `team = default` in tag data — and so does **every squad in six of the seven stock
caches**, including all of Bungie's Covenant wave squads. Bungie assigns teams at runtime, and
`survival_wave_spawn` does it in precisely the order `fe_squad_commit_placed` uses:
`(ai_place_wave …)` → `(sleep 1)` → `ai_set_team`. `ai_allegiance human player` and
`ai_allegiance player human` are declared in all seven caches, so `(ai_set_team squad human)` puts
allies on a team allied to the player and hostile to the Covenant. The author took the other valid
route and set `team = player` (enum 1) in tag data on all five of his purchasable squads
(`scorpion`, `warthog`, `marine_rein`, `marine_pelican`, `sq_turret`) with no `ai_set_team` at all.
Both work; this is not a defect. There is a one-tick window after `ai_place` during which new allies
are on `default`, which is the Covenant's effective team in non-bedlam Firefight — 33 ms, and
Bungie's own wave spawner has the identical window.

---

## 7. Round and set gating, and whether the win is affordable

The gates, read from the shipped bytecode, are `(>= (survival_mode_set_get) k_fe_gate_*)` with
`k_fe_gate_spartan` = `k_fe_gate_strike` = `k_fe_gate_win` = **1** on all seven maps.

**This is the author's gate, verbatim.** His `buy_mac` is unlocked by
`(sleep_until (>= (survival_mode_set_get) 1) 1)`, and he has a second unlock path on
`(and (>= (survival_mode_set_get) 1) (>= (survival_mode_round_get) 2) (survival_mode_current_wave_is_boss))`.
Whatever the exact index base, the gate is reachable in a match he has played, so the Spartan,
strike and win tiers will unlock at the same moment his MAC does.

Indexing, for the record, is not fully pinned and the two counters may differ.
`survival_mode_round_get` is **0-based**: stock `survival_wave_loop` exits a set on
`(and (>= (survival_mode_round_get) 2) (>= (survival_mode_wave_get) 4))` with
`k_sur_round_per_set_limit` = 3 and `k_sur_wave_per_round_limit` = 5, so indices 2 and 4 are the
last round and the last wave. `survival_mode_set_get` is used by stock only as
`(> (survival_mode_set_get) 1)` to gate `survival_respawn_crates` on an initial wave, which reads
more naturally as 1-based; `research/14` also reads `>= 1` as "set 2". Not resolved here, and it does
not need to be, because the gate is author-attested either way.

Affordability, at the stated 2,000-2,500 score per round and 3 rounds per set:

* Set 1 is troopers (500) and ammo (500) only — about 6,000-7,500 earned.
* The win costs 10,000 of **one player's** `campaign_metagame_get_player_score`, not the team's.
  Solo, that is reachable one to two rounds into set 2, i.e. round 4-5 of the match, with the
  Spartan tier (1,000) and one strike (3,000) still affordable along the way.
* The bank (`g_fe_bank`, 500 a press, shared, either player can withdraw what the other deposited)
  lets a pair pool into one wallet, so in co-op the win lands roughly a round earlier.

So the win is affordable within the designed number of rounds. **The problem is not the price — it
is that paying it probably does not end the match** (BLOCKER-G1). That ordering matters for any
retune: do not lower `k_fe_cost_win` to "make the win reachable" before fixing the end-of-match call.

One economic note that is working as designed and may still surprise: the strike kills
`gr_survival_waves` with `ai_kill_no_statistics`, which awards no points. A 3,000-point strike
therefore costs the player the ~2,000 of wave score they would otherwise have earned — a net loss of
about 5,000 for the convenience. That is a deliberate trap, not a bug, but it is worth knowing before
tuning.

---

## 8. What a second round should test, in priority order

1. Replace `(game_won)` with the four-call Bungie sequence on all seven maps. Nothing else in the
   mod is as likely to disappoint a player.
2. Give Waterfront and Outpost the `fe_squad_empty` / `fe_trooper_slot_free` /
   `fe_spartan_slot_free` family the other five maps use, and delete the `g_fe_rotor` /
   `g_fe_spartan_rotor` rotation.
3. Add two spawn points to Waterfront's and Outpost's `sur_fireteam_01` and `_02` so the point count
   matches the cell count of 4, as the Unearthed `marines6` build did correctly.
4. Give `fe_near` a kiosk-side validity guard, matching Bungie's
   `survival_health_pack_highlight`: `(and (>= (object_get_health kiosk) 0) …)`.
5. Drop the `(object_destroy "dm_longsword_01")` from the strike deliveries, or gate the strike on
   the stock resupply event not running.
6. Repoint Unearthed `marines6`'s two added `marine_rein` spawn points from the ODST start
   `(47-50, -56, 8.5)` to the pelican drop area `(45-48, 37-39, -3.8)`.
7. Walk the seven outlier ally spawn points in game — Glacier `(-72.151, 260.836, -104.489)` first,
   then Courtyard's two upper-storey points, then Outpost `(-117.594, -140.785, 13.69)` and Overlook
   `(156.707, 44.285, 0.43)`. Containment is proven; walkability is not, and this audit cannot prove
   it without reading the structure BSP.
8. Decide whether `fe_retire_allies` should be called at set end or deleted, and delete the rest of
   the dead surface: `g_fe_open`, `fe_gate_round`, `g_fe_buys`, `g_fe_spartan_buys`, `fe_report`, and
   the air/strike globals on the maps with no such station.
