# 29 — Adversarial script audit, round 3 (final)

Target: the nine shipped maps in `ready-to-install/`, plus the `MOD-PACKAGE/` copies.

Everything below was read out of the shipped bytes. `project/src/hsc/` and `project/research/` were
read for context only and are never the evidence for a claim. Where a prior document and the
artifact disagree, the artifact wins and the disagreement is recorded.

---

## 0. Provenance and method

### 0.1 The artifacts audited

| shipped file | MD5 | round-1 MD5 | changed? |
|---|---|---|---|
| `ff10_prototype.FINAL.map` | `d24bec31f11b9cffdb3fd80371e36548` | `87a3c0fb…` | yes |
| `ff20_courtyard.FINAL.map` | `78e4b73926503b88a70b0b7517850ee4` | `44875c0e…` | yes |
| `ff30_waterfront.FINAL.map` | `f6a66e7941d6b121a157385267f31872` | `99cc8d6e…` | yes |
| `ff50_park.FINAL.map` | `2598b14ed411f5c7e465aa380ba84549` | `ccbc3682…` | yes |
| `ff60_airview.FINAL.map` | `1d39b192283b0382f262eb200759a8af` | `b38aadf4…` | yes |
| `ff60_icecave.FINAL.map` | `a69e3c41247d6c0f348aaf50255fda15` | `78f49504…` | yes |
| `ff70_holdout.FINAL.map` | `f440cd3990112d70f034c92cd4b28c04` | `455f1d0c…` | yes |
| `ff_unearthed.marines6.map` | `9485119638a4600f5aa5c0785cb8a88b` | `94851196…` | **no** |
| `ff_unearthed.tuned.map` | `5e9e9479815b12cdab4bc604e1fa0ccf` | `5e9e9479…` | **no** |

All nine `MOD-PACKAGE/` copies are byte-identical by MD5 to the loose files, re-verified this round,
so the pack is audited once:

```
d24bec31…  MOD-PACKAGE/Firefight-Reinforcements/maps/ff10_prototype.map
78e4b739…  …/ff20_courtyard.map
f6a66e79…  …/ff30_waterfront.map
2598b14e…  …/ff50_park.map
1d39b192…  …/ff60_airview.map
a69e3c41…  …/ff60_icecave.map
f440cd39…  …/ff70_holdout.map
94851196…  …/ff_unearthed.map
5e9e9479…  Firefight-Reinforcements-Safe/maps/ff_unearthed.map
```

Both Unearthed variants are **unchanged since round 1**. Every round-1 finding on them therefore
stands as written, and no round-2 fix can have reached them. The other seven were all rebuilt.

### 0.2 Readers used

Five independent readers, built this round under `project/build/r3/`:

1. `r3_decomp.sh` → `tools/hsc/decompile.py`, `--variant reachmcc_u13`, `--table reachmcc_u13.xml`,
   per-map `--base-va` / `--scnr-offset` derived from each cache's own header. **0 unknown opcodes
   and 0 `<!UNKNOWN…!>` markers on all nine**, so the `reachmcc_u13` table identification from
   round 1 holds.
2. `r3_check.py` — a raw script-table reader (script refs, declared-vs-supplied arity, parameter
   types, dangling `next`/`value` datums, dangling global initialisers and script roots, duplicate
   names).
3. `r3_squads.py` / `r3_tag.py` — a fresh `scnr` reader driven by Bungie's own
   `research/_raw/reach-defs/scenario.json` layouts through `defwalk`: squad groups and parents,
   squads and their flags/team/zone/objective/wave-placement-filter, cells, spawn points, trigger
   volumes, player starting locations, and a calibrated containment test.
4. `r3_cells.py` / `r3_celldiff.py` — cell choice-block reader that records each block's **address**,
   so sharing (aliasing) between squads is visible, plus a full squad-by-squad diff of every shipped
   map against its stock twin.
5. `r3_kiosk.py` — kiosk anchor separation from the `controls` / `machines` / `equipment` / `crates`
   placements, against the radius each map's startup script actually installs.

Oracles: each map's own stock cache in `maps-stock/` (decompiled fresh this round into
`build/r3/stock/`), and the author's untouched `maps-stock/ff_unearthed.map`.

### 0.3 Calibration

The containment test reports **16/16 player starting locations inside `safe_zone_soft` and 0/16
inside any kill polygon on every one of the seven retail maps**, so a "pass" from it means
something. It reports 0/16 on Unearthed, so **no containment claim is made for Unearthed** — same
limitation as round 1.

The kiosk separation reader reproduces round 1 to three decimal places on all seven maps
(Overlook 1.965, Courtyard 2.432, Waterfront 3.039, Beachhead 3.055, Outpost 2.336, Glacier 3.425,
Holdout 4.639), from a reader written independently. Two independent measurements agree.

### 0.4 What this audit still cannot do

* **Nothing here has run in MCC.** Every claim is a statement about bytes.
* **Walkability is still not measured.** The structure BSP collision was not read. A point can be
  inside `safe_zone_soft`, outside every kill volume, and still be on a ledge or inside geometry.
  Section 7 assesses the outliers on the best available evidence and says so.
* **The header checksum could not be independently verified.** The XOR reproduction in
  `tools/map/reach_write.py` (`checksum_of(data, header_size)`) does not match the stored field on
  the **stock** caches either, across every plausible `header_size` from 0x800 to 0x8000. The method
  is wrong, not the maps, so this test returns no signal in either direction. One weak positive:
  `ff_unearthed.tuned.map`'s stored checksum is `0xB35A145E` against stock's `0xB35A145C` — the
  writer did update the field.
* **Blamite gating was not re-run.** It is Windows-only. Round 2's `LOAD: OK` results are taken on
  trust; they are the one link in the chain this audit does not re-forge.

---

## 1. Severity summary

| severity | count | where |
|---|---|---|
| **BLOCKER** | **0** | — |
| RISK | 3 new global + 4 map-specific carried over | charge-then-no-op win; corpse buyer; leaked Longsword; Courtyard ×2, Glacier, Unearthed-m6 spawn placement |
| COSMETIC | 11 global + a handful | dead scripts and globals, bank asymmetry, partial-squad lockout, reader artifacts |

| map | round 1 | round 3 |
|---|---|---|
| Overlook `ff10_prototype` | PASS with BLOCKER-G1 | **PASS** |
| Courtyard `ff20_courtyard` | PASS with BLOCKER-G1 + 1 RISK | **PASS**, 1 RISK (the one I would fix) |
| Waterfront `ff30_waterfront` | **FAIL — 3 BLOCKERS** + G1 | **PASS** |
| Beachhead `ff50_park` | PASS with BLOCKER-G1 | **PASS** |
| Outpost `ff60_airview` | **FAIL — 3 BLOCKERS** + G1 | **PASS** |
| Glacier `ff60_icecave` | PASS with BLOCKER-G1 + 1 RISK | **PASS**, 1 RISK |
| Holdout `ff70_holdout` | PASS with BLOCKER-G1 | **PASS** |
| Unearthed `marines6` | PASS + 1 RISK | **PASS**, 1 RISK (unchanged file) |
| Unearthed `tuned` | PASS | **PASS** (unchanged file) |

**No map is worse than it was before the fixes.** The three new global RISKs are each strictly
smaller than the defect they replaced. Said plainly: round 2 did what it claimed, on every map, and
the claims hold up against the bytes.

---

## 2. PRIORITY 1 — the crossed lineage: Waterfront and Outpost

Two agents edited these two maps. Agent A fixed the global win-purchase blocker on all seven maps;
Agent B then rebuilt Waterfront and Outpost from a different base to fix the ally-slot defects.
Agent B stated its artifacts carry Agent A's edits but that it did not verify them. That is the
claim this section tests.

### 2.1 Per fix, per map, present or absent

Every cell below is an independent read of the shipped cache, not an inference from a neighbour and
not from either fix report.

| # | fix | source | `ff30_waterfront` | `ff60_airview` |
|---|---|---|---|---|
| 1 | win-purchase end-of-match chain, four calls, correct order | Agent A | **PRESENT** | **PRESENT** |
| 2 | `(game_won)` absent from every `fe_*` script | Agent A | **PRESENT** | **PRESENT** |
| 3 | `g_fe_won` latch guard, and the latch can clear | Agent A | **PRESENT** | **PRESENT** |
| 4 | Longsword: `object_destroy` removed from the strike | Agent A | **PRESENT** | **PRESENT** |
| 5 | proximity `-1` guard in `fe_near` | Agent A | **PRESENT** | **PRESENT** |
| 6 | squad-emptiness test in `fe_has_room` | Agent B | **PRESENT** | **PRESENT** |
| 7 | squad-emptiness test in `fe_has_spartan_room` | Agent B | **PRESENT** | **PRESENT** |
| 8 | occupancy-based delivery, not blind rotation | Agent B | **PRESENT** | **PRESENT** |
| 9 | 4 spawn points per 4-body trooper squad | Agent B | **PRESENT** (4/4) | **PRESENT** (4/4) |
| 10 | ally secondary weapon is not a Covenant weapon | Agent B | **PRESENT** (`magnum`) | n/a (no secondary) |
| 11 | ally↔ally primary-weapon block unshared | Agent B | **PRESENT** | **PRESENT** |

**VERDICT: both fix sets are present and coherent on both maps.** No edit was overwritten, no edit
is half-applied, and the two sets do not interfere: they touch disjoint scripts
(`fe_near` / `fe_mission_won` / `fe_*_deliver_strike` against
`fe_squad_empty` / `fe_*_slot_free` / `fe_has_*_room` / `fe_deliver_*`), and the shipped text of
each is identical to the corresponding text on the maps that received only one of the two sets.

### 2.2 The evidence, fix by fix

**Fixes 1–3, the end path.** Shipped `ff30_waterfront`, `fe_mission_won` at line 6494 of the
round-3 decompile:

```
(script static void fe_mission_won (object kiosk)
  (if (and (not g_fe_won) (not b_survival_game_end_condition))
    (begin
      (set g_fe_won true)
      (fe_blip kiosk)
      (sleep 30)
      (ai_kill_no_statistics "gr_survival_all")
      (sleep 60)
      (fe_unblip kiosk)
      (survival_spartans_increment_score)
      (event_survival_spartans_win_normal)
      (submit_incident "survival_mm_game_complete")
      (set b_survival_game_end_condition true)
      (sleep 1800)
      (set g_fe_won false))))
```

`ff60_airview` is byte-for-byte the same text. `(game_won)` occurs exactly once in each of the two
caches and the enclosing script is Bungie's leftover campaign `end_mission` (`ff30_waterfront` line
3909, `ff60_airview` line 3901), whose entire body is `(game_won)` and which nothing in Firefight
calls. Full detail in section 3.

**Fix 4, the Longsword.** Shipped `fe_deliver_strike`, identical on both maps:

```
(script static void fe_deliver_strike
  (object_create "dm_longsword_01")
  (device_set_position_track "dm_longsword_01" "ff10" 0)
  (device_animate_position "dm_longsword_01" 1 10 3 3 false)
  (sleep 90)
  (ai_kill_no_statistics "gr_survival_waves")
  (sleep 120))
```

The terminal `(object_destroy "dm_longsword_01")` is gone. Every remaining occurrence of that call
in either cache is inside Bungie's own `survival_resupply_pod_spawn`. See RISK-R3 for what the
removal costs.

**Fix 5, the proximity guard.** Both maps:

```
(script static boolean fe_near (unit who, object kiosk)
  (and (fe_valid who)
       (>= (objects_distance_to_object who kiosk) 0)
       (< (objects_distance_to_object who kiosk) k_fe_kiosk_radius)))
```

Textually identical to the `fe_near` on all five other maps — one variant across seven caches.

**Fixes 6–8, the ally-slot logic.** Shipped Waterfront and Outpost:

```
(script static boolean fe_squad_empty (ai squad) (<= (ai_living_count squad) 0))
(script static boolean fe_trooper_slot_free
  (or (fe_squad_empty "sur_fireteam_01") (fe_squad_empty "sur_fireteam_02")))
(script static boolean fe_has_room
  (and (>= (fe_slots_free) k_fe_squad_size) (fe_trooper_slot_free)))
(script static boolean fe_spartan_slot_free
  (or (fe_squad_empty "sur_fireteam_03") (fe_squad_empty "sur_fireteam_04")))
(script static boolean fe_has_spartan_room
  (and (>= (fe_slots_free) k_fe_spartan_size)
       (and (<= (+ (fe_spartans_alive) k_fe_spartan_size) k_fe_spartan_limit)
            (fe_spartan_slot_free))))
```

and delivery is a three-clause `cond` with an explicit refusal arm:

```
(script static void fe_deliver_squad
  (cond ((fe_squad_empty "sur_fireteam_01")
          (begin (fe_squad_commit_placed "sur_fireteam_01") (set g_fe_buys (+ g_fe_buys 1))))
        ((fe_squad_empty "sur_fireteam_02")
          (begin (fe_squad_commit_placed "sur_fireteam_02") (set g_fe_buys (+ g_fe_buys 1))))
        (true (if g_fe_debug (print "fe: refused, both trooper squads occupied")))))
```

`g_fe_buys` is now incremented **inside** the arm that actually places, so the counter cannot lie.
`fe_deliver_spartans` has the same shape. `g_fe_rotor` and `g_fe_spartan_rotor` appear in these two
caches exactly twice each — the declaration and one `set` in the startup script — and are read
nowhere. The blind rotor is gone, not merely bypassed.

Round 1's traced failure is now closed: with 8 troopers alive, `fe_slots_free` = 4 ≥ 4 still passes
the budget term, but `fe_trooper_slot_free` is false, `fe_has_room` is false, and
`fe_kiosk_reinforce` calls `(fe_deny "health_pack0")` **before** `fe_transact` is reached. No charge.

**Fix 9, the spawn points.** Read from each shipped `scnr`:

| map | squad | cell count | spawn points | nearest player start per point |
|---|---|---|---|---|
| Waterfront | `sur_fireteam_01` | 4 | **4** | 0.77, 5.98, **0.00**, **0.00** |
| Waterfront | `sur_fireteam_02` | 4 | **4** | 0.87, 14.42, **0.00**, **0.00** |
| Waterfront | `sur_fireteam_03` | 2 | 2 | 13.53, 15.82 |
| Waterfront | `sur_fireteam_04` | 2 | 2 | 5.98, 14.42 |
| Outpost | `sur_fireteam_01` | 4 | **4** | 0.44, 15.74, **0.00**, **0.00** |
| Outpost | `sur_fireteam_02` | 4 | **4** | 4.96, 0.69, **0.00**, **0.00** |
| Outpost | `sur_fireteam_03` | 2 | 2 | 0.64, 0.44 |
| Outpost | `sur_fireteam_04` | 2 | 2 | 15.74, 4.96 |

Round 1's BLOCKER WF-3 / OP-3 was "count 4, two spawn points". Both trooper squads on both maps now
carry four. Every one of the sixteen points is inside that map's `safe_zone_soft` and inside no kill
polygon. The four **added** points have `nearest_start = 0.00`, i.e. they are exactly Bungie's own
player starting locations — the strongest walkability evidence obtainable without a BSP read, and a
genuine improvement over round 1's hand-authored coordinates.

**Fixes 10–11, the loadouts and the aliasing.** Resolved through each map's own weapon, character and
equipment palettes:

| map | squad | character | primary | secondary | equipment |
|---|---|---|---|---|---|
| Waterfront | `_01` | `null_cov_default` | `dmr` | **`magnum`** | — |
| Waterfront | `_02` | `null_cov_default` | `dmr` | **`magnum`** | — |
| Waterfront | `_03`/`_04` | `null_cov_default` | `sniper_rifle, rocket_launcher, spartan_laser, plasma_turret, grenade_launcher` | `magnum` | `sprint, active_camouflage, drop_shield, jet_pack` |
| Outpost | `_01`/`_02` | `null_cov_default` | `dmr`×5 + `assault_rifle`×1 | — | — |
| Outpost | `_03`/`_04` | `null_cov_default` | same five as Waterfront | — | `sprint, active_camouflage, drop_shield, jet_pack` |

The round-1 RISK — "a Covenant plasma rifle on all four Waterfront ally squads" — is **gone**;
the secondary is a human `magnum`. And the choice-block **address** report finds **no ally squad
sharing any choice block with any other squad** on either map. Every shared block in either cache is
stock↔stock (`sq_sur_phantom_01..04` + `sq_sur_bonus_phantom`, `sq_sur_drop_*` pairs,
`sq_sur_banshee_01/02`, `sq_sur_sniper_01..04`) and matches the stock twin exactly. The round-1
ally↔ally primary aliasing on both maps is closed.

### 2.3 Residual items on these two maps, all carried over, none new

1. **Cross-squad spawn-point reuse remains.** Waterfront's `sur_fireteam_04` reuses `_01`'s and
   `_02`'s second points `(9.053, 227.516, 46.651)` and `(20.944, 224.123, 44.917)`; Outpost's `_03`
   reuses `_01`'s first point and `_04` reuses `_01`'s second and `_02`'s first. With both squads
   alive, two actors can be assigned one position. The engine should nudge them apart. COSMETIC.
2. **Waterfront `sur_fireteam_03`** keeps the 13.53 and 15.82 wu isolated Spartan points, and
   **Outpost** keeps `(-117.594, -140.785, 13.690)` at 15.74 wu. In-arena, no kill volume. The
   player-start treatment was applied to the trooper tier and not the Spartan tier. RISK, low.
3. **Outpost's ally task follow radius is still 8.0** where every other map is 3.0.
4. **Outpost's kiosk headroom is still the thinnest in the pack** at +0.068 wu (section 6, class 5).
5. **`fe_report` is still a dead debug stub** on both, and `print` is `null="true"` in U13 so it
   could not print even if reached.
6. **`g_fe_rotor` / `g_fe_spartan_rotor` are now dead** but still declared and still set by startup.

---

## 3. PRIORITY 2 — is G1 genuinely fixed, on all seven?

**Yes.** Traced as a hostile reader, from the kiosk thread to `mp_round_end_with_winning_team`.

### 3.1 The chain exists and is reachable

`fe_kiosk_win` is a `dormant` script woken by each map's startup script. The purchase path, read from
the shipped bytecode (Waterfront shown; the other six differ only in the anchor name and whether
`fe_mission_won` takes a beacon parameter):

```
(script dormant void fe_kiosk_win
  (sleep_until
    (begin
      (fe_wait_at "health_pack5")
      (if (fe_gate_set k_fe_gate_win)
          (if (fe_transact "health_pack5" k_fe_cost_win)
              (fe_mission_won "health_pack5"))
          (fe_deny "health_pack5"))
      (sleep k_fe_cooldown)
      false)))
```

`fe_mission_won` → the four calls → `(set b_survival_game_end_condition true)`.

`survival_end_game` is Bungie's, unmodified, and is **woken by the stock main startup script** (one
`(wake survival_end_game)` call site, in the startup block alongside `survival_lives_announcement`
and `survival_award_achievement`). Nothing in any of the seven caches `sleep_forever`s it — the
string `survival_end_game` occurs exactly twice in each cache: the declaration and the wake. Its body
is stock:

```
(script dormant void survival_end_game
  (wake survival_mode_end_condition_lives) … (wake survival_mode_end_condition_complete)
  (sleep_until b_survival_game_end_condition 1)
  …
  (sleep_forever survival_mode) …
  (sleep 30) (sleep 90)
  (mp_round_end_with_winning_team none))
```

So the flag we set is the flag the stock end-of-match machine is already blocked on, and it ends the
match ~120 ticks (4 s) later. **Stock `survival_end_game` is the thing that ends the match**, as
required.

### 3.2 All four elements exist, with correct arity, in all seven caches

| element | kind | declared where | arity | per-map result |
|---|---|---|---|---|
| `survival_spartans_increment_score` | **map script**, `static void` | script table | 0 params | declared in 7/7 |
| `event_survival_spartans_win_normal` | **map script**, `static void` | script table | 0 params | declared in 7/7 |
| `submit_incident` | engine function | U13 table | 1 × `string_id` | 1 arg supplied, 7/7 |
| `b_survival_game_end_condition` | **stock global**, `boolean` | global table | — | present in 7/7 |

Neither of the first two is an engine opcode — they are Bungie's own scripts, which is why
`fe_shop_lib.hsc`'s original note that they were "not in the table" was a namespace confusion rather
than a fact. Declaration line numbers in the round-3 decompiles:

| map | `survival_spartans_increment_score` | `event_survival_spartans_win_normal` | `survival_end_game` |
|---|---|---|---|
| Overlook | 2282 | 2780 | 2160 |
| Courtyard | 2286 | 2784 | 2164 |
| Waterfront | 2289 | 2787 | 2167 |
| Beachhead | 2523 | 3021 | 2401 |
| Outpost | 2281 | 2779 | 2159 |
| Glacier | 2279 | 2777 | 2157 |
| Holdout | 2289 | 2787 | 2167 |

The broader arity sweep (section 6, class 9) found **0 arity mismatches over 5,100+ script
references across all nine caches**, and **0 parameter-type mismatches on every `fe_*` call site**.
`submit_incident`'s single argument is `string_id` in the U13 table and a `string_id`-typed
expression (`value_type` 11) at the call site.

### 3.3 The `submit_incident` string actually compiled right

This is the one argument that could be silently wrong — a `string_id` whose hash does not match
Bungie's would submit a bogus incident and nothing would complain. Raw expression values for every
`survival_mm_game_complete` node in the shipped Waterfront:

```
idx=5269   value=88c10000  value_type=11   <- stock, survival_mode_end_condition_time
idx=5300   value=88c10000  value_type=11   <- stock, survival_mode_end_condition_complete
idx=16494  value=88c10000  value_type=11   <- OURS, fe_mission_won
```

Identical. The same test on every map resolves each of `survival_mm_game_complete`, `ff10`,
`obj_fireteams` and `fireteams` to **exactly one `string_id`-typed value per cache**, so our call
sites and Bungie's agree everywhere:

| map | `survival_mm_game_complete` | `ff10` | `obj_fireteams` | `fireteams` |
|---|---|---|---|---|
| Overlook | `99f90000` | `c03a0000` | `1f090000` | `20090000` |
| Waterfront | `88c10000` | `bb310000` | `d5080000` | `d6080000` |
| Outpost | `6de70000` | `c6380000` | `fb080000` | `fc080000` |
| Holdout | `f2e30000` | `05330000` | `0e090000` | `0f090000` |

### 3.4 The global reference points at the real stock global

`b_survival_game_end_condition` is referenced 8 times in each cache (1 declaration + 7 reads/writes,
one of the reads and one of the writes being ours). Every reference carries the correct global-table
index in its value field:

| map | table index of the global | index in every reference |
|---|---|---|
| Overlook / Courtyard / Waterfront / Outpost / Glacier / Holdout | 123 | `0x7B` = 123 |
| Beachhead | 124 | `0x7C` = 124 |

No duplicate global names in any of the nine caches, so there is no second
`b_survival_game_end_condition` our read could have bound to.

### 3.5 `(game_won)` no longer appears in our scripts

`(game_won)` occurs **exactly once** in each of the seven caches, and in every case the enclosing
script is Bungie's leftover campaign `end_mission`, whose whole body is that one call:

| map | line | enclosing script |
|---|---|---|
| Overlook | 3903 | `(script static void end_mission` @3902 |
| Courtyard | 3907 | `end_mission` @3906 |
| Waterfront | 3910 | `end_mission` @3909 |
| Beachhead | 3903 | `end_mission` @3902 |
| Outpost | 3902 | `end_mission` @3901 |
| Glacier | 3900 | `end_mission` @3899 |
| Holdout | 3910 | `end_mission` @3909 |

Nothing in Firefight calls `end_mission`, and its body is byte-identical to stock (section 6,
class 3). **No `fe_*` script on any map contains `(game_won)`.**

### 3.6 The `g_fe_won` latch can genuinely clear

Three separate mechanisms:

1. `fe_mission_won` ends `(sleep 1800)` → `(set g_fe_won false)` — the latch self-clears 60 s after
   the purchase, on all seven maps, inside the same thread.
2. Each map's startup script sets `(set g_fe_won false)` before any `wake`.
3. The global's declared initialiser is `false`.

`fe_kiosk_win` is a single thread, so while it is inside `fe_mission_won` (30 + 60 + 1800 ticks) it
cannot re-enter, and `g_fe_won` therefore never blocks a *second* purchase from the same kiosk — the
`b_survival_game_end_condition` term does that. The permanent-latch failure mode from round 1 (pay,
latch, no-op forever) is structurally gone.

### 3.7 The pattern is Bungie's own

Our four calls are, in order, the success branch of Bungie's `survival_mode_end_condition_time`:

```
; stock
(survival_spartans_increment_score)
(event_survival_spartans_win_gen)
(submit_incident "survival_mm_game_complete")
(set b_survival_game_end_condition true)
```

and `survival_mode_end_condition_complete` uses the `_win_normal` event we use. Both are attested
Bungie sequences. `survival_spartans_increment_score`'s body is six
`(survival_increment_human_score (human_player_in_game_get N))` calls; `event_survival_spartans_win_normal`
submits `"sur_gen_unsc_win"` for `player` and `"sur_cla_cov_fail"` for `covenant_player`. Calling
both from our thread does exactly what Bungie's end condition does.

`fe_mission_won` is a `static` script containing `sleep`s, called from a thread. That is attested:
**100 of stock Waterfront's own static scripts contain a `sleep` or `sleep_until`**, including
`survival_wave_loop` and `survival_wave_spawn`.

### 3.8 Hostile question: is there any path where the player pays and the match does not end?

Enumerated:

| path | charged? | match ends? | verdict |
|---|---|---|---|
| Normal: gate met, affordable, no end condition pending | yes | **yes**, via `survival_end_game` | correct |
| Gate not met (`survival_mode_set_get` < 1) | **no** — `fe_deny` fires before `fe_transact` | n/a | correct |
| Cannot afford | **no** — `fe_buyer_at` is false, `fe_transact` returns false without charging | n/a | correct |
| Second press inside the 1890-tick window | **no** — the single `fe_kiosk_win` thread is inside `fe_mission_won` | already ending | correct |
| `b_survival_game_end_condition` already true (stock end condition fired first: lives out, time out, all sets complete, or the bonus round) | **YES, 10,000** | yes, but for the stock reason | **RISK-R1** |
| `survival_end_game` never reached its `sleep_until` | — | — | impossible: it is woken at startup and never slept forever |

**RISK-R1 — charge-then-no-op on the win kiosk. New this round, all seven maps.**
`fe_kiosk_win` calls `fe_transact` (which charges) **before** `fe_mission_won` evaluates its guard.
If `b_survival_game_end_condition` is already `true`, the 10,000 is deducted and the body is skipped
in silence. This is reachable: it is exactly the state during the bonus round and during the few
seconds after any stock end condition fires. The match ends anyway, so the practical cost is a
10,000-point hole in the final scoreboard rather than a softlock — but it is a silent
pay-for-nothing, which is the defect class round 1 was built to catch, and the guard is on the wrong
side of the charge. Fix shape: hoist the test into the kiosk —
`(if (and (fe_gate_set k_fe_gate_win) (not g_fe_won) (not b_survival_game_end_condition)) (if (fe_transact …) …) (fe_deny …))`
— and keep the guard inside `fe_mission_won` as a belt-and-braces.

One cosmetic ordering note, not a risk: `fe_mission_won` kills `gr_survival_all` 30 ticks in and sets
the flag 60 ticks after that. In those 60 ticks the arena is empty, so stock `survival_wave_loop` may
advance and `survival_wave_spawn` may place a fresh wave for ~2 s before the match ends. Setting the
flag before the kill, or shortening the gap, would avoid it. `gr_survival_fireteams` is ROOT on every
map and is therefore **not** a descendant of `gr_survival_all`, so the kill does not touch the allies
the player paid for.

---

## 4. PRIORITY 3 — the round-1 defect checklist, re-run on all nine

Each cell is an independent measurement on that map.

| # | class | OV | CT | WF | BH | OP | GL | HO | UE-m6 | UE-t |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | wave-clear deadlock via ally group parenting | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| 2 | `ai_survival_cleanup` eats allies | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| 3 | ungated `ai_erase` / half-applied hook | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| 4 | cap enforcement | PASS | PASS | **PASS** (was FAIL) | PASS | **PASS** (was FAIL) | PASS | PASS | PASS | PASS |
| 5 | kiosk radius vs anchor spacing | PASS | PASS | PASS | PASS | PASS | PASS | PASS | n/a | n/a |
| 6 | price-node agreement | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| 7 | charging the actual buyer | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| 8 | spawn in safe zone, outside every kill volume | PASS | PASS | PASS | PASS | PASS | PASS | PASS | n/t | n/t |
| 9 | calls to non-existent scripts | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| 10 | shared choice blocks touching a stock squad | PASS | PASS | **PASS** | PASS | **PASS** | PASS | PASS | PASS | PASS |

`n/t` = not testable; the containment reader does not calibrate on Unearthed (0/16 player starts in
`safe_zone_soft`), exactly as in round 1, so no claim is made.

### Class 1 — wave-clear deadlock: PASS on all nine

Squad-group parentage read from each shipped `scnr`:

| map | `gr_survival_fireteams` index | parent | ancestry |
|---|---|---|---|
| Overlook | 8 | `-1` | **ROOT** |
| Courtyard | 6 | `-1` | **ROOT** |
| Waterfront | 6 | `-1` | **ROOT** |
| Beachhead | 6 | `-1` | **ROOT** |
| Outpost | 9 | `-1` | **ROOT** |
| Glacier | 9 | `-1` | **ROOT** |
| Holdout | 9 | `-1` | **ROOT** |

Glacier's reparent out of `gr_survival_extras` is still in place — that is the one map this defect
would have killed. On both Unearthed variants `gr_survival_marines` is ROOT with
`gr_survival_marines_followers` as its child, and `gr_survival_fireteams` is left at its stock parent
`gr_survival_waves` — harmless, because those four handles carry **zero cells and zero spawn points**
on Unearthed and the author's scripts never touch them.

The decisive secondary evidence: **0 stock script bodies changed** on any map (class 3), so
`survival_wave_living_count` is byte-identical to Bungie's on all seven, and nothing at runtime can
reparent a group — `ai_reset_objective`, `ai_set_task`, `ai_survival_cleanup` and `ai_living_count`
are the only group-taking calls in any cache and none of them reparents.

### Class 2 — `ai_survival_cleanup` on paid allies: PASS on all nine

Every call site in every shipped cache, enumerated:

```
(ai_survival_cleanup "gr_survival_all"       true  true)
(ai_survival_cleanup "gr_survival_remaining" true  true)
(ai_survival_cleanup "gr_survival_extras"    true  true)
(ai_survival_cleanup "gr_survival_all"       false false)
(ai_survival_cleanup "gr_survival_remaining" false false)
(ai_survival_cleanup "gr_survival_extras"    false false)
(ai_survival_cleanup "gr_survival_fireteams" true  true)   <- ours, in fe_retire_allies
```

Identical set on all seven. Both Unearthed variants have the first six and **not** the seventh (no
`fe_*` scripts at all). `fe_retire_allies` has **0 call sites** on every map, verified by resolving
every `script_reference` expression, so the one call that could reach the ally group never runs. And
the ally group is ROOT, so the stock per-wave sweep over `all` / `remaining` / `extras` cannot reach
it even if it did.

### Class 3 — ungated `ai_erase`, half-applied hooks: PASS on all nine

The decisive test is a name-keyed body diff of every shipped cache against its stock twin:

| map | stock scripts removed | stock globals removed | stock globals changed | **stock bodies changed** | scripts added | globals added |
|---|---|---|---|---|---|---|
| Overlook | 0 | 0 | 0 | **0** | 38 | 25 |
| Courtyard | 0 | 0 | 0 | **1** (`player_count` shim) | 41 | 28 |
| Waterfront | 0 | 0 | 0 | **1** (shim) | 42 | 27 |
| Beachhead | 0 | 0 | 0 | **0** | 38 | 25 |
| Outpost | 0 | 0 | 0 | **1** (shim) | 42 | 27 |
| Glacier | 0 | 0 | 0 | **1** (shim) | 39 | 28 |
| Holdout | 0 | 0 | 0 | **1** (shim) | 41 | 28 |
| UE `marines6` | 0 | 0 | 0 | **1** (`infantry_limit`) | 0 | 0 |
| UE `tuned` | 0 | 0 | 0 | **1** (`infantry_limit`) | 0 | 0 |

Every `ai_erase` in every cache is therefore inside an unmodified Bungie body: 18 sites on Overlook
and Waterfront, 17 on Courtyard, 16 on Beachhead and Holdout, 12 on Outpost and Glacier, 26 on
Unearthed. `g_sur_drop_spawn` / `g_sur_drop_limit` occur 12/9, 10/8, 12/9, 10/8, 0/0, 0/0, 10/8 and
12/9 respectively — Outpost and Glacier have no drop-pod machinery at all — and **no
`fe_*_stock_hooks` script exists in any shipped cache**, which is the correct state after the port to
fireteam handles.

### Class 4 — cap enforcement: PASS on all nine, the two failures closed

`fe_allies_alive` = `(ai_living_count "gr_survival_fireteams")` on all seven, and every ally squad is
a direct member of that group — including Beachhead's differently-named `sq_elite_fireteam_01..04`.
Cell counts per map are 4/4/2/2 and `k_fe_actor_limit` is 12, so the sum of all four squads is
exactly the cap. Constant values, read from each cache's global table (identical on all seven except
the per-map extras):

```
k_fe_cost_squad 500   k_fe_cost_spartan 1000  k_fe_cost_ammo 500
k_fe_cost_strike 3000 k_fe_bank_step 500      k_fe_cost_win 10000
k_fe_actor_limit 12   k_fe_spartan_limit 4    k_fe_squad_size 4   k_fe_spartan_size 2
k_fe_dwell 8          k_fe_cooldown 150
k_fe_gate_spartan 1   k_fe_gate_strike 1      k_fe_gate_win 1
```

Per-squad emptiness is now gated everywhere. Three equivalent shapes, each explained by that map's
squad names:

* Overlook / Beachhead — inline: `(or (= (ai_living_count "…_01") 0) (= (ai_living_count "…_02") 0))`
* Courtyard / Glacier / Holdout — `(fe_trooper_slot_free)` over `fe_squad_empty`
* Waterfront / Outpost — `(fe_trooper_slot_free)` over `fe_squad_empty` (Agent B's rewrite)

Traced to exhaustion, cap 12, squads 4/4/2/2:

* 0 alive → trooper buy passes, squad 01 placed, 4 alive.
* 4 alive → passes, squad 02 placed, 8 alive.
* 8 alive → budget term `12-8 = 4 ≥ 4` still passes, **`fe_trooper_slot_free` is false**, deny, no
  charge. (This is the round-1 Waterfront/Outpost failure, now closed.)
* 8 troopers → Spartan buy: `4 ≥ 2` ✓, `0+2 ≤ 4` ✓, squad 03 empty ✓ → 10 alive.
* 10 alive → `2 ≥ 2` ✓, `2+2 ≤ 4` ✓, squad 04 empty ✓ → 12 alive, cap exact.
* 12 alive → both Spartan squads occupied → `fe_spartan_slot_free` false → deny. Trooper kiosk:
  `12-12 = 0 < 4` → deny.

The `(true (fe_squad_commit_placed "…_02"))` fallback on Courtyard, Glacier and Holdout is safe
because `fe_has_room` guarantees one of the two is empty and no `sleep` intervenes between the gate
and the delivery (`fe_transact` → `fe_charge_at` → `fe_ok` are all sleepless).

Unearthed cap coherence is unchanged from round 1 and still exact: `marines6` 6 + 6 = 12 against
`infantry_limit` 12; `tuned` 6 + 4 = 10 against 12.

### Class 5 — kiosk radius vs measured anchor spacing: PASS on all seven

Anchor sets taken from each map's own `fe_wait_at` arguments, positions from its own `scnr`
placements, radius from the `(set k_fe_kiosk_radius …)` the startup script actually executes:

| map | stations resolved | min separation | binding pair | max safe radius | shipped radius | margin | headroom |
|---|---|---|---|---|---|---|---|
| Overlook | 6/6 | 1.965 | `health_pack0` ↔ `health_pack4` | 0.983 | **0.90** | 8.4 % | +0.083 wu |
| Courtyard | 6/6 | 2.432 | `health_pack4` ↔ `#_door_interior_large_logo_03` | 1.216 | **1.10** | 9.6 % | +0.116 wu |
| Waterfront | 6/6 | 3.039 | `health_pack3` ↔ `health_pack2` | 1.519 | **1.45** | 4.6 % | +0.069 wu |
| Beachhead | 6/6 | 3.055 | `health_pack0` ↔ `health_pack4` | 1.527 | **1.45** | 5.1 % | +0.077 wu |
| Outpost | 6/6 | 2.336 | `health_pack4` ↔ `health_pack2` | 1.168 | **1.10** | 5.8 % | **+0.068 wu** |
| Glacier | 5/5 | 3.425 | `health_pack4` ↔ `health_pack5` | 1.713 | **1.45** | 15.3 % | +0.263 wu |
| Holdout | 6/6 | 4.639 | `#_m70_door_small_05` ↔ `health_pack2` | 2.319 | **1.45** | 37.5 % | +0.869 wu |

Every anchor named by every kiosk resolves to a real placement (`missing=[]` on all seven), including
the five `#`-prefixed door machines. Five maps declare the library default 2.5 and rely on the
startup overwrite; on all seven the `(set k_fe_kiosk_radius …)` is the **first** statement after
`(sleep 30)` and precedes every `wake`, verified by reading the compiled statement order, so no kiosk
can ever observe 2.5. Thin absolute headroom on Outpost, Waterfront and Overlook, unchanged from
round 1.

`INSTALL.txt` documents 1.45 / 1.10 / 1.45 / 0.90 / 1.45 / 1.45 / 1.10 for Holdout / Courtyard /
Glacier / Overlook / Beachhead / Waterfront / Outpost — all seven match the shipped bytes. Its
"1.967 world units" for Overlook's binding pair is 1.965 as measured; irrelevant to play.

### Class 6 — price-node agreement: PASS on all nine

On the seven rebuilt maps every price exists in exactly **one** constant node — a `(global long
k_fe_cost_*)` — and is passed as a parameter to `fe_transact` → `fe_buyer_at` / `fe_charge_at`. Every
`fe_transact` argument in every kiosk is a global reference; **no literal price appears in any `fe_*`
script on any map**. Desync is structurally impossible, not merely absent.

Both Unearthed variants are byte-unchanged since round 1, so the 16-node-per-price verification in
audit 25 class 6 stands: all 21 priced scripts agree across all 16 nodes and are identical to the
author's, and `withdraw` keeps its correct asymmetry (no affordability clause, positive award).

### Class 7 — charging the actual buyer: PASS on all nine

`fe_buyer_at` is an `or` over slots 0-7 of
`(and (fe_near (human_player_in_game_get N) kiosk) (>= (fe_score (human_player_in_game_get N)) cost))`,
and `fe_charge_at` is a `cond` over the **identical predicates in the identical order**, each arm
charging the same slot it tested. Both are textually identical across all seven caches — one variant,
not seven. `player0` appears nowhere in any `fe_*` script. `fe_credit_at` is the same shape with the
affordability term dropped, as the bank requires.

### Class 8 — spawn points in the safe zone, outside every kill volume: PASS on all seven

Every ally spawn point on all seven maps is inside that map's `safe_zone_soft` sector polygon and
inside **no** kill polygon. Counted mechanically: **0 points with `safe=NONE` and 0 points with any
kill-volume hit**, across 7 maps × 12 points. Calibration on each map: 16/16 player starts inside the
safe zone, 0/16 in a kill volume.

Cell counts and spawn-point counts now agree on every squad on every map:

| map | `01` | `02` | `03` | `04` |
|---|---|---|---|---|
| Overlook | 4 cells / 4 pts | 4 / 4 | 2 / 2 | 2 / 2 |
| Courtyard | 4 / 4 | 4 / 4 | 2 / 2 | 2 / 2 |
| **Waterfront** | **4 / 4** | **4 / 4** | 2 / 2 | 2 / 2 |
| Beachhead | 4 / 4 | 4 / 4 | 2 / 2 | 2 / 2 |
| **Outpost** | **4 / 4** | **4 / 4** | 2 / 2 | 2 / 2 |
| Glacier | 4 / 4 | 4 / 4 | 2 / 2 | 2 / 2 |
| Holdout | 4 / 4 | 4 / 4 | 2 / 2 | 2 / 2 |

The geometric outliers are unchanged and are assessed in section 7.

### Class 9 — calls to non-existent scripts: PASS on all nine

Every `script_reference` expression in all nine caches resolved against the script table, with
declared parameter count compared to supplied argument count:

| cache | script refs | out of range | arity mismatches | param-type mismatches on `fe_*` |
|---|---|---|---|---|
| Overlook | 647 | 0 | 0 | 0 |
| Courtyard | 656 | 0 | 0 | 0 |
| Waterfront | 657 | 0 | 0 | 0 |
| Beachhead | 646 | 0 | 0 | 0 |
| Outpost | 656 | 0 | 0 | 0 |
| Glacier | 628 | 0 | 0 | 0 |
| Holdout | 656 | 0 | 0 | 0 |
| UE `marines6` | 616 | 0 | 0 | n/a |
| UE `tuned` | 616 | 0 | 0 | n/a |

Also 0 dangling `next` pointers, 0 dangling group `value` pointers, 0 globals whose initialiser
points outside the expression table, 0 scripts whose root points outside it, 0 duplicate script
names and 0 duplicate global names, on all nine.

The `player_count` naming artifact is unchanged and is still a **reader** artifact. On the five
shimmed maps (Courtyard, Waterfront, Outpost, Glacier, Holdout) script index **0** is the injected
shim, body `(list_count (players_human))`, and Bungie's original survives at index **158** with body
`(list_count (players))`. Overlook and Beachhead carry no shim: index 157 is Bungie's original,
`(list_count (players))`, and their stock-vs-mod body diff is empty. The per-map stringID table
resolves the shim's name as `prop_firefight_difficulty_highest_official_score` and the original's as
`assist_5x` (Holdout: unresolvable `<!sid:0x00080336!>`) — different mis-renderings from round 1's,
same underlying structure, nothing dangles.

### Class 10 — shared choice blocks: PASS on all nine, and the ally↔ally aliasing is gone

Full squad-level diff of each shipped map against its stock twin, covering `flags`, `team`, group
parent, `initial zone`, `initial objective`, `wave placement filter`, the spawn-point list, cell
count, `major upgrade`, and the **resolved contents of all four choice blocks**:

| map | squads shipped / stock | added | removed | **squads differing from stock** |
|---|---|---|---|---|
| Overlook | 28 / 28 | 0 | 0 | 4 — `sur_fireteam_01..04` |
| Courtyard | 27 / 27 | 0 | 0 | 4 — `sur_fireteam_01..04` |
| Waterfront | 32 / 32 | 0 | 0 | 4 — `sur_fireteam_01..04` |
| Beachhead | 29 / 29 | 0 | 0 | 4 — `sq_elite_fireteam_01..04` |
| Outpost | 27 / 27 | 0 | 0 | 4 — `sur_fireteam_01..04` |
| Glacier | 24 / 24 | 0 | 0 | 4 — `sur_fireteam_01..04` |
| Holdout | 31 / 31 | 0 | 0 | 4 — `sur_fireteam_01..04` |
| UE `marines6` | 48 / 48 | 0 | 0 | 2 — `marine_rein`, `sq_sur_ini_odsts` |
| UE `tuned` | 48 / 48 | 0 | 0 | 1 — `sq_sur_ini_odsts` |

**Exactly the ally squads changed, on every map. No stock squad's weapons, characters, equipment,
team, group, zone, objective, wave filter or spawn points differ from Bungie's.**

The choice-block **address** report finds every shared block in every cache to be stock↔stock, and
every one of them matches that map's stock twin: the `sq_sur_phantom_01..04` + `sq_sur_bonus_phantom`
character block, the `sq_sur_drop_*` and `sq_sur_wraith_*` and `sq_sur_ghost_*` and
`sq_sur_banshee_*` pairs, the `sq_sur_sniper_01..04` character and weapon blocks on Waterfront and
Outpost, and Glacier's `sq_sur_wave_01` ↔ `sur_fireteam_06` character block (the untouched absorber
squad). **No ally squad on any map shares a choice block with any other squad** — the round-1
Waterfront and Outpost ally↔ally primary aliasing is closed, and the Waterfront ally↔ally secondary
sharing is closed with it.

Ally squad tag state against stock, every squad, all seven maps:

```
flags = 0x100 (no wave spawn)  == stock 0x100     on 01..06 (Glacier _06 is 0x40, absorber, == stock)
wave placement filter = 0      == stock 0
initial objective     = 1      == stock 1          (= obj_fireteams)
team                  = default== stock default
```

So the Firefight wave spawner can never fill an ally handle with Covenant, and the allies carry the
right initial objective at tag level as well as being assigned it at runtime.

The resolved ally loadouts as shipped:

| map | troopers 01 / 02 | secondary | Spartans 03 / 04 | equipment |
|---|---|---|---|---|
| Overlook | `dmr` / `assault_rifle` | — | `sniper_rifle, rocket_launcher, spartan_laser, plasma_turret, grenade_launcher` | `drop_shield, sprint, jet_pack, active_camouflage` |
| Courtyard | `dmr` / `dmr` | `magnum` ×2 | same five | same four |
| Waterfront | `dmr` / `dmr` | **`magnum`** ×4 | same five | same four |
| Beachhead | `dmr` / `assault_rifle` | — | `sniper_rifle, rocket_launcher, spartan_laser, grenade_launcher` | same four |
| Outpost | `dmr`×5 + `assault_rifle`×1 (both) | — | same five | same four |
| Glacier | `dmr` / `dmr` | — | `shotgun, rocket_launcher, spartan_laser, grenade_launcher` | `drop_shield, sprint, active_camouflage` |
| Holdout | `dmr` / `dmr` | — | same five | same four |

All sixteen ally cells use character palette entry `null_cov_default`, and `major upgrade` is 3
(`none`) on the trooper cells and 4 (`all`) on the Spartan cells, as designed.

**Correction to round 1.** Audit 25 stated "no other map assigns a secondary at all" besides
Waterfront. **Courtyard's two trooper cells carry a `magnum` secondary** in the shipped build. Either
round 1 missed it or round 2 added it; either way it is a human sidearm from Courtyard's own weapon
palette, in a private block shared with no other squad, and benign. Recorded so the next reader is
not surprised.

### Additional checks in this class

`obj_fireteams` and its task `fireteams` exist in every shipped cache, with the squad-group filter
pointing at that map's own `gr_survival_fireteams` index:

| map | objective | task | follow | follow radius | squad group filter | group index |
|---|---|---|---|---|---|---|
| Overlook | `obj_fireteams` (1) | `fireteams` | player | 3.0 | 8 | 8 ✓ |
| Courtyard | `obj_fireteams` (1) | `fireteams` | player | 3.0 | 6 | 6 ✓ |
| Waterfront | `obj_fireteams` (1) | `fireteams` | player | 3.0 | 6 | 6 ✓ |
| Beachhead | `obj_fireteams` (1) | `fireteams` | player | 3.0 | 6 | 6 ✓ |
| Outpost | `obj_fireteams` (1) | `fireteams` | player | **8.0** | 9 | 9 ✓ |
| Glacier | `obj_fireteams` (1) | `fireteams` | player | 3.0 | 9 | 9 ✓ |
| Holdout | `obj_fireteams` (1) | `fireteams` | player | 3.0 | 9 | 9 ✓ |

The three `sfx_fe_*` sound globals resolve to real tag paths in every cache, with a per-map datum:
`sound\game_sfx\ui\transition_beeps`, `sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus`,
`sound\game_sfx\multiplayer\flag_failure`. None is null.

---

## 5. PRIORITY 4 — new regressions from the fixes

### 5.1 Stock script bodies

**0 stock script bodies changed on any of the nine maps**, with the two known and intended
exceptions: the `player_count` shim on five maps, and `infantry_limit` on the two Unearthed variants
(the `8 → 12` cap edit, which predates this round and is unchanged). 0 stock scripts removed,
0 stock globals removed, 0 stock globals changed, on all nine. The seven maps' diffs against Bungie's
text are otherwise empty.

### 5.2 Arity and references

0 arity mismatches, 0 out-of-range script references, 0 parameter-type mismatches on `fe_*` call
sites, over 5,768 script references across the nine caches (section 4, class 9). The two scripts
whose signature changed this round (`fe_mission_won` gained an `(object beacon)` / `(object kiosk)`
parameter on five maps and has none on Overlook and Beachhead) are called with the matching arity at
every site:

| map | `fe_mission_won` signature | `fe_kiosk_win` call |
|---|---|---|
| Overlook | no params | `(fe_mission_won)` |
| Beachhead | no params | `(fe_mission_won)` |
| Courtyard | `(object beacon)` | `(fe_mission_won "health_pack2")` |
| Glacier | `(object beacon)` | `(fe_mission_won "health_pack5")` |
| Holdout | `(object beacon)` | `(fe_mission_won "health_pack2")` |
| Waterfront | `(object kiosk)` | `(fe_mission_won "health_pack5")` |
| Outpost | `(object kiosk)` | `(fe_mission_won "health_pack3")` |

### 5.3 Unresolved references and the expression graph

0 unresolved script references, 0 dangling expression `next` or `value` datums, 0 dangling global
initialisers, 0 dangling script roots, 0 unknown opcodes, 0 unknown expression types, on all nine.

Expression-table sizes, round 1 → round 3:

| map | scripts | globals | exprs r1 | exprs r3 | delta | explained by |
|---|---|---|---|---|---|---|
| Overlook | 397 | 222 | 16,639 | 16,664 | **+25** | G1 + G2 + G3 |
| Courtyard | 398 | 222 | 16,220 | 16,245 | **+25** | G1 + G2 + G3 |
| Waterfront | 406 | 225 | 16,728 | 16,801 | **+73** | G1 + G2 + G3 **+ ally-slot rewrite** |
| Beachhead | 415 | 222 | 17,179 | 17,204 | **+25** | G1 + G2 + G3 |
| Outpost | 389 | 217 | 16,303 | 16,376 | **+73** | G1 + G2 + G3 **+ ally-slot rewrite** |
| Glacier | 374 | 215 | 14,865 | 14,893 | **+28** | G1 + G3 (no strike on this map) |
| Holdout | 418 | 233 | 17,446 | 17,471 | **+25** | G1 + G2 + G3 |
| UE ×2 | 485 | 277 | 52,711 | 52,711 | **0** | files unchanged |

The +25 is almost exactly constant across the five single-fix maps, +73 on the two that also got the
ally-slot rewrite, and +28 on Glacier where the Longsword fix has nothing to apply to. Holdout's
script and global counts are **identical** to round 1 (418 / 233), which is right: the G1 fix
replaces one call with four and adds no scripts or globals. Nothing here is unexplained.

### 5.4 StringID table consistency

Append-only on every map, with **0 stock entries whose index moved**:

| map | stock sids | shipped sids | added | stock indices changed |
|---|---|---|---|---|
| Overlook | 71,288 | 71,326 | +38 | **0** |
| Courtyard | 52,675 | 52,715 | +40 | **0** |
| Waterfront | 57,069 | 57,110 | +41 | **0** |
| Beachhead | 70,659 | 70,697 | +38 | **0** |
| Outpost | 66,644 | 66,685 | +41 | **0** |
| Glacier | 65,804 | 65,842 | +38 | **0** |
| Holdout | 65,672 | 65,713 | +41 | **0** |
| UE ×2 | 49,514 | 49,514 | +0 | **0** |

The added count equals the added script count on every map except the four where the shim reuses an
existing stringID (38 scripts / +38, 41 / +40, 42 / +41, 38 / +38, 42 / +41, 39 / +38, 41 / +41).
Globals carry inline names and consume no stringIDs, which is why 25-28 added globals add nothing to
these totals.

### 5.5 The +0x70000 lineage split, and whether it left a stale pointer

The two agents used different write strategies, and the shipped caches show it plainly:

| map | file delta | `meta_offset` delta | `meta_size` delta | `virtual_base` delta | `scnr` offset delta | lineage |
|---|---|---|---|---|---|---|
| Overlook | +589,824 | 0 | **+589,824** | **−458,752** | +458,752 | A (grown) |
| Courtyard | +524,288 | 0 | **+524,288** | **−393,216** | +393,216 | A (grown) |
| Beachhead | +593,920 | +4,096 | **+589,824** | **−458,752** | +462,848 | A (grown) |
| Glacier | +528,384 | +4,096 | **+524,288** | **−393,216** | +397,312 | A (grown) |
| Holdout | +593,920 | +4,096 | **+589,824** | **−458,752** | +462,848 | A (grown) |
| **Waterfront** | +131,072 | 0 | +131,072 | **0** | **0** | B (rebuilt lineage) |
| **Outpost** | +131,072 | 0 | +131,072 | **0** | **0** | B (rebuilt lineage) |

This matches `research/28` §7 exactly: writing a second script table onto an already-written `FINAL`
grows the file and orphans the old table, which is why Agent A's five are `+0x70000`-class; Agent B
rebuilt `loadout → unshare → tagfix → one script write` and landed on the original size with
`virtual_base` and the `scnr` offset untouched.

**No stale pointer was found, in either lineage.** The evidence:

1. **0 tags outside the meta window** and **0 parse warnings** on all seven, from
   `reach_cache`'s own validator.
2. Every table the `scnr` header points at resolves and decodes completely: 0 unknown opcodes,
   0 dangling datums, every object name / squad / group / cell / choice block / spawn point /
   trigger volume / palette entry / objective / task resolving to a sensible value. A stale base
   would have produced garbage in the stock squads, and the stock-squad diff is empty on every map.
3. **The orphan hypothesis was tested directly and cleared.** Each shipped cache contains **two**
   copies of the global-name strings (`k_fe_kiosk_radius`, `g_fe_won`, `k_fe_actor_limit`), which
   looks exactly like an orphaned table. It is not: **every stock cache also contains two copies**
   of `b_survival_game_end_condition` inside its meta area (stock Waterfront at `0x5d85863` and
   `0x5f155c4`; stock Holdout at `0x43ec5d7` and `0x45617b0`). The duplication is Bungie's own
   layout, present before anyone touched these files. And the `hs_globals` pointer in the `scnr`
   header resolves to the *later* copy in both the stock and the shipped cache of each map, i.e. to
   the live table in the same relative position:

   | cache | `global_count` | live `hs_globals` block |
   |---|---|---|
   | stock Waterfront | 198 | `0x5f1428c` |
   | ship Waterfront | 225 | `0x5dec868` |
   | stock Holdout | 205 | `0x4560478` |
   | ship Holdout | 233 | `0x44c8860` |

4. `b_survival_game_end_condition` is referenced by index `0x7B`/`0x7C` in every reference in every
   cache, matching that cache's own global-table index (section 3.4). If a stale base or an orphaned
   table were in play, the index our new read carries and the index the live table uses would
   diverge, and the latch would bind to the wrong global. They agree on all seven.

**One standing build hazard, carried over from `research/28` §8 and re-confirmed here**: Waterfront's
and Outpost's spawn-point fix is a **tag** edit, not reproducible by recompiling scripts. Anything
that rebuilds those two maps from `src/hsc/` alone will silently ship four bodies against two spawn
points again. `src/hsc/fe_reinforcements_wo.hsc` is in sync with the shipped scripts (spot-checked:
the `>= 0` guard, `fe_squad_empty`, the occupancy `cond`, the four-call end chain and the absent
`game_won` are all present in the source), so a script-only rebuild would get the scripts right and
the tags wrong — the worst shape of failure. The base to use is `build/r2/lin/<map>.tagfix.map`.

### 5.6 Three new RISKs introduced by the fixes

**RISK-R1 — charge-then-no-op on the win kiosk. All seven maps.** Fully described in section 3.8. The
latch guard sits inside `fe_mission_won`, after `fe_transact` has already charged 10,000. Reachable
whenever `b_survival_game_end_condition` is already true, which includes the whole bonus round.
Impact: a 10,000-point hole in the scoreboard on a match that was ending anyway. Strictly smaller
than the round-1 blocker it replaced, but it is the same defect *class* and it is new.

**RISK-R2 — a corpse can shop. All seven maps.** `fe_valid` is
`(>= (object_get_health who) 0)`. Bungie's cited precedent, `survival_health_pack_highlight`, tests
`(< (object_get_health subject) 0)` for *absence*, so health exactly 0 — a player dead but not yet
despawned — satisfies `fe_valid`. Combined with the new `(>= distance 0)` term, which only closes the
*kiosk* side of the hole, a body lying inside a station's radius can still satisfy `fe_buyer_at`,
and `fe_charge_at` will deduct from it, once per 150-tick cooldown. Low probability, bounded cost,
and it predates this round in substance — but the round-2 fix explicitly revisited `fe_near` and left
`fe_valid` as it was, so it is worth recording here rather than losing it. Fix shape: `(> … 0)`.

**RISK-R3 — the Longsword is now leaked instead of destroyed. Six of seven maps (not Glacier).**
Round 2's fix for RISK-G2 was to delete the terminal `(object_destroy "dm_longsword_01")` outright.
That does close the deadlock — and the deadlock was the unrecoverable half, so this is the right
trade — but it leaves two loose ends:

* Our strike creates the device and never destroys it. On the five maps where `dm_longsword_01` has
  placement flags `0x1` (script-created) the Longsword parks at track position 1 and stays in the
  world until Bungie's next `survival_resupply_pod_spawn` cycle re-animates and destroys it. That
  interval is unbounded — the stock loop waits on `survival_mode_should_drop_weapon`. A Longsword
  model hanging over the arena is a visual artifact, not a functional one. On Beachhead the device is
  placed from map load (`0x00000000`) and stock does the same create/animate/destroy dance, so the
  situation there is Bungie's own.
* The reverse collision now exists: stock's own `(sleep 120)` → `(object_destroy "dm_longsword_01")`
  can fire inside our 10-second animation and cut the flyby short. Our thread does **not** poll the
  device (`(sleep 90)` → `ai_kill_no_statistics` → `(sleep 120)`), so there is no deadlock and the
  kill still lands. Visual only.
* The self-healing direction is confirmed: our `(device_set_position_track … 0)` can reset the track
  under a stock animation that is blocked on `(sleep_until (>= (device_get_position …) 0.4) 1)`, but
  our `(device_animate_position … 1 10 …)` then drives it past 0.4 in ~4 s, so the stock loop
  resumes. The unrecoverable case is gone.

`INSTALL.txt` already describes this as "a visual glitch" for Courtyard and Holdout, which is now the
accurate description. A guarded destroy — only if our own animation completed and the stock cycle is
not mid-flight — would close the leak, but it is not a ship stopper.

### 5.7 COSMETIC inventory, all seven maps unless noted

Dead code, verified by resolving every `script_reference` and counting textual occurrences:

* `fe_retire_allies` — declared, **0 call sites**, all seven.
* `fe_gate_round` — declared, **0 call sites**, all seven. Every gate is on `survival_mode_set_get`.
* `fe_ov_troopers_alive` (Overlook) / `fe_bh_troopers_alive` (Beachhead) — declared, 0 call sites.
* `fe_report` — Waterfront and Outpost only, body `(if g_fe_debug (print "fe: report"))`, 0 call
  sites, and `print` is `null="true"` in U13 anyway.
* `g_fe_open` — declaration + one `set` in startup, **never read**, all seven.
* `g_fe_buys` / `g_fe_spartan_buys` — incremented, never read, all seven.
* `g_fe_rotor` / `g_fe_spartan_rotor` — Waterfront and Outpost, declaration + one `set` in startup,
  never read. **New this round**: they were live before the occupancy rewrite.
* `g_fe_air_rotor` — Courtyard, Glacier, Holdout: declaration + one `set`, never read.
* `k_fe_cost_air` + `k_fe_gate_air` — Courtyard, Glacier, Holdout: declaration only, never
  mentioned again. No air station exists on any of them (stock owns the Banshees, correctly).
* `k_fe_cost_strike` + `k_fe_gate_strike` — Glacier: declaration only. No strike station and no
  `fe_*_deliver_strike` script, which matches the design and `INSTALL.txt`.

Behavioural warts, none new, none a defect:

* **`fe_bank_use` is deposit-first.** `(cond ((fe_buyer_at kiosk 500) deposit) ((>= g_fe_bank 500)
  withdraw) (true deny))`. A solvent player standing at the bank is drained 500 every 150 ticks and
  can never deliberately withdraw while solvent; withdrawal only happens once you are broke. That is
  what the code says and probably what was intended, but it is worth a line in the install notes.
* **Partial squads lock out reinforcement.** With one survivor in each trooper squad,
  `fe_trooper_slot_free` is false and the trooper kiosk denies, even though 10 of 12 ally slots are
  free. The emptiness gate is per-squad by design; the consequence is that you must let a squad wipe
  completely before you can top up.
* **Overlook and Beachhead `fe_deliver_squad` / `fe_deliver_spartans`** are two-clause `cond`s with
  no `(true …)` arm, and increment `g_fe_buys` **outside** the `cond`. Unreachable because
  `fe_has_room` guarantees one squad is empty, but if the guard were ever bypassed the counter would
  lie. Waterfront and Outpost now do this correctly; the other five do not.
* **`sfx_fe_buy` is `…\exit_experience\winning_bonus`** — the match-win sting plays on every
  purchase, including a 500-point ammo crate.
* **No key press.** `fe_wait_at` is `(sleep_until (fe_anyone_at kiosk) 5)` + `(sleep k_fe_dwell)`
  with `k_fe_dwell` = 8 ticks, so walking onto a health station spends your points if you can afford
  the tier and a slot is free. Documented in `INSTALL.txt`; recorded here because it is easy to read
  as a bug in play.
* **Six dormant kiosk threads** each evaluate an eight-slot, sixteen-script-call predicate every five
  ticks. No stock map does anything this cheap-but-frequent on six threads. No evidence of a budget
  problem; a load characteristic only.
* **The `player_count` shim** sits at script index 0 on five maps with Bungie's original surviving at
  index 158 as two expressions of dead code, and the shim uses `players_human` where stock used
  `players`. In Firefight every player is on the human team, so the counts agree.
* **`fe_shop_lib.hsc` §5's comment** still documents the opposite of its own
  `objects_distance_to_object` argument order. Harmless (the metric is symmetric for a one-element
  list), source-only, not shipped.

---

## 6. Per-map detail

### Overlook — `ff10_prototype` — PASS

397 scripts / 222 globals / 16,664 expressions. Six stations on `health_pack0..5`, all `controls`,
placement flags `0x00000000`. Radius **0.90** against a 1.965 minimum (+0.083 wu headroom — second
thinnest in the pack). Ally group 8, ROOT. Cells 4/4/2/2 with 4/4/2/2 spawn points.
`fe_has_room` / `fe_has_spartan_room` test emptiness inline. `fe_mission_won` takes no parameter and
does not blip (no beacon on this map).

* G1, G2, G3 all present. `(game_won)` only in stock `end_mission` @3902. `object_destroy
  "dm_longsword_01"` survives only in stock `survival_resupply_pod_spawn` @5422 and stock
  `test_longsword_drop` @6024 — this is the only map with two stock sites, and both are Bungie's.
* RISK-R1, R2, R3 as per section 5.6.
* RISK (minor, unchanged): ally spawn point `(156.707, 44.285, 0.43)` is 15.01 wu from the nearest
  player respawn, one of four points on squads 01/02. In-arena, walkability unverified. See §7.
* COSMETIC: two-clause `cond` with unconditional counter; `fe_ov_troopers_alive` dead.

### Courtyard — `ff20_courtyard` — PASS, 1 RISK (the one I would fix before shipping)

398 / 222 / 16,245. Six stations: `health_pack0/1/4/2` plus the door machines
`#_door_interior_large_logo_03` (ammo) and `_04` (strike); both door names resolve correctly in the
compiled bytecode and both placements were found. Radius **1.10** against 2.432 (+0.116 wu). Ally
group 6, ROOT. `fe_squad_empty` family present, cap logic correct, cells 4/4/2/2 with 4/4/2/2 points.
`fe_mission_won (object beacon)` blips the kiosk.

* G1, G2, G3 present. `fe_ct_deliver_strike` carries the Longsword fix.
* **RISK — the worst spawn placement in the pack, unchanged.** Two of this map's four ally spawn
  points are `(-92.596, 57.432, 18.4)` at 22.06 wu and `(-92.531, 58.622, 15.755)` at 23.26 wu from
  the respawn cluster, and they are on a **different storey** — 2.6 wu of vertical separation across
  1.2 wu of horizontal. `sur_fireteam_04`, the 1,000-point Spartan squad, uses **only those two
  points**, so both Spartans land up there, away from the shop and the player, every single time.
  Squads 01 and 02 also list them, so two of four troopers go there too. Round 2 applied the
  player-start treatment to Waterfront's and Outpost's trooper squads and did not apply it here.
  See §7.
* COSMETIC: `k_fe_cost_air` 1000 / `k_fe_gate_air` 2 / `g_fe_air_rotor` dead (Banshees are
  stock-owned, correctly left alone). Trooper cells carry a `magnum` secondary, in a private block —
  see the correction at the end of §4 class 10.

### Waterfront — `ff30_waterfront` — PASS (was FAIL with 3 BLOCKERS)

406 / 225 / 16,801. Six stations on `health_pack0..5` (`0` troopers, `1` Spartans, `3` ammo,
`4` strike, `2` bank, `5` win). Radius **1.45** against 3.039 (+0.069 wu). Ally group 6, ROOT.

* All three round-1 BLOCKERS are closed: `fe_has_room` now has the emptiness term, delivery is a
  three-clause occupancy `cond` with an explicit refusal arm, and both trooper squads carry 4 spawn
  points against their count of 4.
* Both round-1 RISKs are closed: the ally secondary is a human `magnum`, not a Covenant
  `plasma_rifle`, and squads 01 and 02 no longer share a primary-weapon choice block.
* G1, G2, G3 present (Agent A's set, verified independently of Agent A).
* RISK (carried over): `sur_fireteam_03` keeps isolated Spartan points at 13.53 and 15.82 wu.
* COSMETIC: `fe_report` dead; `g_fe_rotor` / `g_fe_spartan_rotor` now dead; cross-squad spawn-point
  reuse between `_04` and `_01`/`_02`.

### Beachhead — `ff50_park` — PASS

415 / 222 / 17,204. The one map whose ally handles are `sq_elite_fireteam_01..06`. Confirmed by tag
read that `01..04` are direct members of `gr_survival_fireteams` (group 6, ROOT), so `fe_allies_alive`
counts them and the cap binds. Radius **1.45** against 3.055 (+0.077 wu). Cells 4/4/2/2 with 4/4/2/2
points. `initial zone` is `-1` here where other maps have `0`; stock ships it that way. Cell names are
`grunt_heavy`, copied from a donor cell — a label only; characters are `null_cov_default` and loadouts
are human.

* G1, G2, G3 present. `fe_mission_won` takes no parameter.
* `dm_longsword_01` has placement flags `0x00000000` on this map — it exists from map load. Stock
  Beachhead does the same `object_create` → track → animate → wait → `object_destroy`, so our
  no-longer-destroying strike simply leaves Bungie's own device in place until Bungie's own loop
  recycles it. RISK-R3 is at its mildest here.
* COSMETIC: two-clause `cond` with unconditional counter; `fe_bh_troopers_alive` dead.
* Checked and cleared again: one ally spawn point `(-165.753, 49.646, -34.4)` falls inside
  `kill_soft_11`'s bounding box but **outside its polygon**. With 0/16 Beachhead player starts inside
  any kill polygon, the polygon test is the trustworthy one and this point is clear.

### Outpost — `ff60_airview` — PASS (was FAIL with 3 BLOCKERS)

389 / 217 / 16,376. Six stations on `health_pack0..5` (`0` troopers, `1` Spartans, `4` ammo,
`5` strike, `2` bank, `3` win). Radius **1.10** against 2.336 — **+0.068 wu, still the thinnest
headroom in the pack.** Ally group 9, ROOT.

* All three round-1 BLOCKERS closed, identically to Waterfront. Both trooper squads: count 4, four
  spawn points, two of them exactly on player starting locations.
* Round-1 RISK closed: `sur_fireteam_01` / `_02` no longer share a primary-weapon choice block.
* G1, G2, G3 present.
* Ally cell name is `normal_1_jackal_sniper`, copied from a donor cell. **Checked specifically
  because Agent B rebuilt this map from a different base**: the resolved character choice is
  `null_cov_default` and the primaries are `dmr`×5 + `assault_rifle`×1, so the jackal-sniper label is
  a label and nothing inherited the donor's loadout. The four `sq_sur_sniper_*` stock squads keep
  their own shared blocks, byte-identical to stock.
* COSMETIC (unchanged): the `obj_fireteams` task's follow radius is **8.0** against 3.0 on every
  other map; allies will trail considerably further behind the player here. `fe_report` dead;
  `g_fe_rotor` / `g_fe_spartan_rotor` now dead.
* Minor, cleared again: one ally spawn point sits in `kill_soft_frontfield01`'s bounding box but
  outside its polygon; 6/16 of this map's own player starts also fall in kill bounding boxes, so the
  box test is meaningless here and the polygon test is clean.

### Glacier — `ff60_icecave` — PASS, 1 RISK

374 / 215 / 14,893. **Five** stations, not six: `health_pack0` troopers, `1` Spartans, `2` ammo,
`4` bank, `5` win. `health_pack3` is deliberately left as a pure heal station. No strike kiosk and no
`fe_*_deliver_strike` script, matching `src/hsc/ff60_icecave.hsc` and `INSTALL.txt` — intentional, not
a build loss. `object_destroy "dm_longsword_01"` occurs **0 times** in this cache; the map has no
Longsword machine at all. Consequence: Glacier is the only map exempt from both RISK-G2 and RISK-R3.
Radius **1.45** against 3.425 (+0.263 wu). Ally group 9, ROOT — **the reparent out of
`gr_survival_extras` is still in place, and this is the map that would have killed.** Cells 4/4/2/2
with 4/4/2/2 points. Spartan loadout correctly uses `shotgun` instead of `sniper_rifle` for close
quarters.

* G1 and G3 present.
* **RISK (unchanged)**: ally spawn point `(-72.151, 260.836, -104.489)` is **28.86 wu** from the
  nearest player respawn — the most isolated ally spawn in the pack — and 1.8 wu lower than its three
  siblings. Inside `safe_zone_soft`, in no kill polygon. `sur_fireteam_01` and `_02` each list it as
  one of four points, so at most one trooper in four goes there. See §7.
* COSMETIC: `k_fe_cost_strike` 3000, `k_fe_gate_strike` 1, `k_fe_cost_air` 1000, `k_fe_gate_air` 2
  and `g_fe_air_rotor` all declared and never read.
* COSMETIC: `sur_fireteam_06` carries flags `0x40` (`fireteam absorber`) and shares a character
  choice block with stock `sq_sur_wave_01`; both are stock state, correctly untouched.

### Holdout — `ff70_holdout` — PASS; still the cleanest of the seven

418 / 233 / 17,471 — script and global counts **identical to round 1**, which is the right outcome
for a fix that replaces one call with four. Six stations: `health_pack0` troopers, `health_pack5`
Spartans, `#_m70_door_small_05` bank, `#_m70_door_ff_02` ammo, `#_m70_door_small_03` strike,
`health_pack2` win. All six names resolve and all six placements were found.

* **Best separation in the pack**: 4.639 wu against a 1.45 radius, +0.869 wu headroom, 37.5 % margin.
* **Best spawn placement in the pack**: all four ally spawn points within 3.5 wu of a player respawn,
  all inside the safe zone, no outliers.
* **Diff against Bungie's script text is empty** apart from the shim. No `fe_holdout_stock_hooks`, no
  `g_sur_drop_spawn` / `g_sur_drop_limit` writes of our own, stock `survival_drop_spawn` and
  `survival_drop_pod_manager` byte-identical to stock. The drop-squad-era hooks are fully gone, not
  half-applied.
* G1, G2, G3 present. `fe_ho_deliver_strike` carries the Longsword fix.
* Three of six anchors are device machine doors → the most exposed map to the residual half of
  RISK-G3: the `(>= distance 0)` guard covers an absent or destroyed anchor, but if a door's object
  origin translates while animating, the measured 4.639 separation holds only in the closed state.
  Not verified either way; the 37.5 % margin is the largest in the pack, so this is the map best able
  to absorb it.
* COSMETIC: `k_fe_cost_air` / `k_fe_gate_air` / `g_fe_air_rotor` dead; `player_count` shim at index 0
  with Bungie's original at index 158.

### Unearthed `marines6` — PASS, 1 RISK — **file byte-unchanged since round 1**

485 / 277 / 52,711. Script table identical to the author's shipped, playtested map except the two
constant nodes in `infantry_limit` (`8 → 12`). No round-2 fix reached this file and none was needed:
it contains no `fe_*` script, no `(game_won)`, no Longsword kiosk and no `fe_near`.

Cap coherence re-verified: `gr_survival_marines` (ROOT) holds `sq_sur_ini_odsts`;
`gr_survival_marines_followers` (its child) holds `marine_rein`. `ai_living_count` on a group is
recursive, so the cap counts both: 6 + 6 = 12 against a cap of 12 — exact. Both squads: count 6 with
6 spawn points. `marine_rein` carries `team = 1` (player) in tag data with no `ai_set_team`, the
author's own route. The four stock `sur_fireteam_01..04` handles are present with **zero cells and
zero spawn points** and are never touched, so their stock parentage under `gr_survival_waves` is
irrelevant.

* **RISK (unchanged)**: `marine_rein`'s two *added* spawn points are `(47.407, -56.076, 8.532)` and
  `(50.224, -56.195, 8.511)`, copied verbatim from `sq_sur_ini_odsts`. The squad's original four are
  at `(45.8-47.7, 37.5-38.8, -3.7..-3.9)`. The new pair is **~95 wu away in Y and ~12 wu higher**, at
  the initial ODST spawn rather than the pelican drop. Two of six purchased marines will materialise
  across the map from the other four, every purchase. The location is legitimate — the author spawns
  ODSTs there at map start — so this is a placement bug, not an out-of-bounds bug. See §7.
* Preserved author bug, not ours: at exactly the cap both `infantry_limit` branches are true
  (`>= 12` and `<= 12`). Neutralised by the `marines_bought_first_time` latch, which is the real
  limiter in the author's design. He shipped the same overlap at 8.
* The containment reader does not calibrate on this scenario (0/16 player starts inside
  `safe_zone_soft`), so **no containment claim is made**. Its spawn points are the author's, in a map
  that has been played.

### Unearthed `tuned` — PASS — **file byte-unchanged since round 1**

485 / 277 / 52,711, scripts identical to `marines6`. The only tag change against the author is
`sq_sur_ini_odsts` count 4 → 6 (it already had 6 spawn points, so consistent); `marine_rein` is left
at 4 bodies / 4 spawn points, all four in the original cluster. **The `marines6` split-spawn RISK
does not apply to this build.** Maximum marines = 6 + 4 = 10 against a cap of 12, so `infantry_limit`
can never trip; the one-shot latch governs, as in the author's build. This is the conservative
variant and the one shipped in `Firefight-Reinforcements-Safe`.

---

## 7. The seven geometric outliers — strand risk, and which I would move

Round 1 flagged seven ally spawn points as geometric outliers and proved containment from trigger
volumes without reading walkability from the BSP. That is still the state: **this audit has not read
the structure BSP collision either.** What follows is a judgement from the evidence that is
available, and it is labelled as such.

The evidence that *is* available, ranked by strength:

1. **The point is a Bungie player starting location.** Strongest: Bungie stands a Spartan up there
   at match start, so it is floor, it is reachable, and it is not inside geometry.
2. **The point is tight to the respawn cluster** (< ~10 wu) and at the same Z as its siblings.
   Strong: it is on the same surface the respawn cluster sits on.
3. **The point is inside `safe_zone_soft` and in no kill polygon.** Necessary but weak: it rules out
   out-of-bounds, not a ledge, a rooftop, or a pathfinding island.
4. **The point is far from the cluster *and* at a different Z from its siblings.** Actively
   suspicious: a vertical offset across a short horizontal distance is the signature of a different
   storey, and a different storey is where an ally gets stuck.

| # | point | map | used by | distance | ΔZ vs siblings | evidence tier | strand risk | move? |
|---|---|---|---|---|---|---|---|---|
| 1 | `(156.707, 44.285, 0.43)` | Overlook | `01`/`02`, 1 of 4 points | 15.01 | small | 3 | **low** — 1 body in 4, same surface | no |
| 2 | `(-92.596, 57.432, 18.4)` | Courtyard | `01`/`02` 1 of 4, **`04` 1 of 2** | 22.06 | +0.1 vs sibling, **−2.6 vs point 3** | 4 | **high** | **YES** |
| 3 | `(-92.531, 58.622, 15.755)` | Courtyard | `01`/`02` 1 of 4, **`04` 1 of 2** | 23.26 | **−2.4 to −2.6** | 4 | **high** | **YES** |
| 4 | `(-72.151, 260.836, -104.489)` | Glacier | `01`/`02` only, 1 of 4 | 28.86 | −1.8 | 4 | **medium** | yes, cheap |
| 5 | `(-7.742, 226.672, 45.748)` | Waterfront | `03` (Spartans), 1 of 2 | 13.53 | +1.2 | 3 | medium | optional |
| 6 | `(-4.103, 208.114, 43.592)` | Waterfront | `03` (Spartans), 1 of 2 | 15.82 | −0.9 | 3 | medium | optional |
| 7 | `(-117.594, -140.785, 13.690)` | Outpost | `01` 1 of 4, **`04` 1 of 2** | 15.74 | +0.2 | 3 | medium | optional |

**The two I would move before shipping: Courtyard's pair (#2 and #3).** They are the only outliers
that tick tier 4 *and* are the **sole** spawn points of a squad. `sur_fireteam_04` is the
1,000-point Spartan purchase, it has exactly two spawn points, and both of them are 22-23 wu out on
what the coordinates say is a different storey — 2.6 wu of vertical separation across 1.2 wu of
horizontal is a floor above, a catwalk, or a roof, not a slope. Every Spartan purchase on Courtyard
puts both bodies up there. There is no "1 of 4" dilution and no fallback point. If anything in this
pack produces a "where did my 1,000 points go", it is this.

The fix is the one that already worked on Waterfront and Outpost: repoint those two to Courtyard's
own player starting locations, which that map has 16 of and which carry tier-1 evidence. It is a tag
edit of two `position` fields, the same shape `build/r2/r2_tagfix.py` already performs, and it needs
the `build/r2/lin`-style lineage discipline so the script table is not rewritten in the process.

**Glacier's #4 I would also move**, as a cheap second: 28.86 wu is the largest isolation in the pack
and the −1.8 wu drop is the second-clearest different-storey signature. But it is one point in four
on two trooper squads, so at most one trooper in four goes there and the other three arrive
correctly. It degrades gracefully; Courtyard's does not.

**Waterfront's #5/#6 and Outpost's #7** are the Spartan-tier points the round-2 work did not get to.
They are 13-16 wu out with sub-1.3 wu vertical offsets — far, but not storey-far. I would apply the
player-start treatment to the Spartan tier on both maps in the same pass as Courtyard, because the
tooling and the evidence base are already set up for it, but I would not hold a ship for them.

**Overlook's #1** I would leave. 15 wu with no vertical signature, one of four points.

**Unearthed `marines6`'s pair** is a different animal and is not a strand risk at all: both points
are tier-1 (the author's own initial ODST spawn, where he stands six ODSTs up at map start), so the
two marines will appear, stand up and walk. The defect is that they appear **~95 wu from the other
four**, which breaks the squad into two groups and wastes two of six bodies for however long it takes
them to path across the map. **I would move them**, to two more positions in the `marine_rein`
cluster at `Y ≈ 37.5-38.8`. Until then, `ff_unearthed.tuned.map` — which leaves `marine_rein`
untouched at 4/4 and does not have this defect — is the Unearthed build I would put in front of a
player. That is also what `Firefight-Reinforcements-Safe` already contains, so the pack is shipping
the right fallback; it is just not shipping it as the default.

---

## 8. Corrections to earlier documents

**8.1 `research/25` (audit round 1) class 10 says "no other map assigns a secondary at all" besides
Waterfront.** Courtyard's two trooper cells carry a `magnum` secondary in the shipped build, in a
private choice block shared with no other squad. Benign; recorded so it is not read as a regression
later.

**8.2 `research/25` class 8 records Overlook's binding kiosk pair at 1.965 and `INSTALL.txt` records
1.967.** 1.965 is what two independent readers measure. Irrelevant to play; noted for consistency.

**8.3 `research/28` §7 says the parallel end-of-match artifacts are "`+0x70000`".** Measured, the
five Agent-A maps grew `meta_size` by 0x80000 (Courtyard, Glacier) or 0x90000 (Overlook, Beachhead,
Holdout) and shifted `virtual_base` down by 0x60000 or 0x70000. The characterisation is right in kind
and approximate in magnitude. It does not change the conclusion: no stale pointer resulted
(§5.5).

**8.4 The duplicate `hs_globals` name strings are not an orphan from the double write.** Every stock
cache has the same duplication. Anyone who finds two copies of `k_fe_kiosk_radius` in a shipped map
and concludes the first write was orphaned will be wrong; check the stock twin first. §5.5.

**8.5 The header-checksum verification recorded in `research/27` §5.2 and `research/28` §4.2 could
not be reproduced here**, because `checksum_of(data, header_size)` does not match the stored field on
the **stock** caches either, at any plausible header size. Those sections may be right — they used
the writer's own round-trip rather than an independent reproduction — but this audit returns no
signal on them in either direction, and the Blamite gate behind them is Windows-only and was not
re-run. This is the one claim in the chain that remains single-sourced.

---

## 9. What should not ship as-is

Nothing in the nine is a BLOCKER, and nothing is worse than it was before the fixes. In priority
order, what I would change before this goes in front of a player:

1. **Courtyard's two Spartan spawn points.** The 1,000-point purchase reliably delivers both bodies
   22-23 wu away on a different storey. Tag edit, two `position` fields, same shape as the fix that
   already worked on Waterfront and Outpost. §7.
2. **Hoist the win-kiosk latch test above `fe_transact`** on all seven maps, so the 10,000 cannot be
   charged when `b_survival_game_end_condition` is already true. One-line script change.
   RISK-R1, §3.8.
3. **Ship `tuned` as the default Unearthed build, or move `marine_rein`'s two added spawn points.**
   `marines6` splits two of six purchased marines ~95 wu from the other four on every purchase.
   `tuned` does not have the defect and is already in the pack as the "(Safe)" fallback. §7.
4. **Glacier's 28.86 wu point**, and the Spartan-tier points on Waterfront and Outpost, in the same
   pass as item 1 if that pass happens. Optional. §7.
5. **Tighten `fe_valid` to `(> … 0)`** (RISK-R2) and **add a guarded Longsword destroy** (RISK-R3) if
   another script pass happens anyway. Neither justifies a pass of its own.
6. **Write the build hazard into the build tooling, not just the research doc.** Waterfront's and
   Outpost's spawn-point fix is a tag edit and is not reproducible from `src/hsc/`. Any future
   rebuild must start from `build/r2/lin/<map>.tagfix.map` or it will silently ship four bodies
   against two spawn points. `build/r2/README-COORDINATION.txt` says so; nothing enforces it.

And the standing caveat, unchanged from round 1 and round 2 and worth repeating because it is the
largest remaining unknown: **none of these nine files has ever been loaded by retail MCC.** Every
verdict in this document is a verdict about bytes.

---

## 10. Artefacts

All under `project/build/r3/`, all read-only against the shipped maps:

```
r3_decomp.sh        per-cache decompile driver (u13 table, per-map addressing)
r3_raw.py           raw script/global/expression reader, independent of the emitter
r3_check.py         script refs, arity, parameter types, dangling datums, duplicate names
r3_bodydiff.py      name-keyed script-body and global diff, shipped vs stock
r3_squads.py        scnr reader: groups, squads, cells, spawn points, volumes, starts
r3_tag.py           squad/containment report with per-map calibration
r3_cells.py         cell choice-block reader with block addresses
r3_celldiff.py      full squad diff vs stock + choice-block aliasing report
r3_kiosk.py         anchor placements and kiosk separation vs installed radius
extract.py          script-body extractor for the decompiled .hsc
out/*.hsc           round-3 decompiles of the nine shipped caches
out/*.sids.json     per-map stringID tables
out/*.tables.json   decoded script/global/call tables
stock/*.hsc         round-3 decompiles of the eight stock caches used as oracles
```
