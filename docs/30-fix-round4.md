# 30 — Round-4 fix pass: the four items round 3 said should not ship

Date: 2026-11-23. Brief: fix exactly the four items in `research/29` §9 items 1, 2, 3 and 5
(`fe_valid`), leave RISK-R3 (the leaked Longsword) alone, and do not touch
`ff_unearthed.tuned.map`.

Everything below is measured. Where a claim rests on an inference, it says so.

---

## 0. What changed, in one table

| # | fix | maps | kind of edit | verified by reading back the shipped bytes? |
|---|---|---|---|---|
| 1 | Courtyard ally spawn points moved to the map's own player starting locations | `ff20_courtyard` | tag: 6 × 12-byte `position` | **yes** |
| 2 | win kiosk tests the latch and the end condition **before** `fe_transact` | all 7 `ff` maps | script | **yes** |
| 3 | `fe_valid` requires health strictly > 0 | all 7 `ff` maps | script | **yes** |
| 4 | Unearthed `marines6`: the two stray marine spawn points moved into the cluster | `ff_unearthed.marines6` | tag: 2 × 12-byte `position` | **yes** |

Not done, deliberately: RISK-R3 (leaked Longsword — out of scope, and the round-2 trade is
right), Glacier's 28.86 wu point and the Spartan-tier points on Waterfront / Outpost / Overlook /
Beachhead (`research/29` §9 item 4, "optional"; see §6 below for the measured state of each),
`ff_unearthed.tuned.map` (untouched; md5 still `5e9e9479815b12cdab4bc604e1fa0ccf`).

---

## 1. Lineage, and why this round did not grow a single file

`research/29` §5.6 and `build/r2/README-COORDINATION.txt` both warn that a second script write
onto an already-written `FINAL` grows the cache (round 2 grew the five Agent-A maps by
0x60000–0x70000) and that Waterfront and Outpost must be rebuilt from
`build/r2/lin/<map>.tagfix.map` or their trooper squads regress from 4 spawn points to 2.

Round 4 therefore writes onto the **same bases round 2 wrote onto**, so it is the second write
onto each base and not the third:

| map | base | md5 of base | = round-1 published md5 in `research/29` §0.1 |
|---|---|---|---|
| `ff10_prototype` | `build/rad/out/ff10_prototype.FINAL.map` | `87a3c0fb…` | yes |
| `ff20_courtyard` | `build/rad/out/ff20_courtyard.FINAL.map` | `44875c0e…` | yes |
| `ff50_park` | `build/rad/out/ff50_park.FINAL.map` | `ccbc3682…` | yes |
| `ff60_icecave` | `build/rad/out/ff60_icecave.FINAL.map` | `78f49504…` | yes |
| `ff70_holdout` | `build/hold2/out/ff70_holdout.FINAL.map` | `455f1d0c…` | yes |
| `ff30_waterfront` | `build/r2/lin/ff30_waterfront.tagfix.map` | `cbb40e64…` | **mandatory base** |
| `ff60_airview` | `build/r2/lin/ff60_airview.tagfix.map` | `4d170534…` | **mandatory base** |

Before any write, `build/r4/r4_tagcmp.py` compared each base's **tag** state with the published
map's: every squad (name, flags, team, parent, zone, objective, wave filter, every cell's
name/count/major, every spawn point's position and cell index), the squad-group table, the player
starting locations, and every machine/control/equipment/crate placement. **All seven bases report
`TAG STATE IDENTICAL`**, which is the evidence that round 2 was script-only on the five and that
the two `r2/lin` bases really do carry the round-2 tag fix.

Result: every one of the seven rebuilt caches is **byte-for-byte the same size as the file it
replaces** (delta +0 on all seven). Both tag edits are in-place and also change no size.

`build/r4/build_r4.sh` hard-codes those bases and refuses to run if one is missing, which is the
first time the hazard in `research/29` §9 item 6 is encoded in the build rather than only in prose.

---

## 2. FIX 1 — Courtyard's ally spawn points

### 2.1 The defect, re-measured from the shipped round-3 cache

| squad | bodies | spawn points | positions |
|---|---|---|---|
| `sur_fireteam_01` | 4 | 4 | two good, **plus both bad** |
| `sur_fireteam_02` | 4 | 4 | two good, **plus both bad** |
| `sur_fireteam_03` | 2 | 2 | the two good ones |
| `sur_fireteam_04` | 2 | 2 | **only the two bad ones** |

The two bad positions were `(-92.596, 57.432, 18.400)` at 22.06 wu from the nearest player start
and `(-92.531, 58.622, 15.755)` at 23.26 wu — 2.6 wu of vertical separation across 1.2 wu of
horizontal, which is a storey, not a slope. `sur_fireteam_04` is the 1,000-point Spartan squad, so
every Spartan purchase put both bodies there with no dilution and no fallback point. Each of the
four squads owns a **private** spawn point block (addresses `0x0ABBA070 / 0x0ABBA280 /
0x0ABBA57C / 0x0ABBA780`, confirmed unshared), so the fix had to be applied per squad.

### 2.2 Identifying the Elite cluster, and excluding it

Courtyard has 16 player starting locations. Their `flags` field splits them exactly:

* `flags = 1` — indices 0, 1, 2, 3, 4, 5, 12, 13 — the human base cluster,
  X −101…−105, Y 33.6…37.3, Z 17.76.
* `flags = 2` — indices 6, 7, 8, 9, 10, 11, 14, 15 — the Firefight-Versus **Elite** cluster,
  X −59…−67, Y 41…43, Z ≈ 13.

That split reproduces, from a field rather than by eye, exactly the index sets `build/r2/r2_tagfix.py`
called "the ELITE cluster" on Waterfront and Outpost (6-11/14/15 there too). `r4_ct_spawnfix.py`
asserts both index sets before it writes and uses only `flags = 1` starts.

### 2.3 The six new positions

| squad | point | new position | from | wu to nearest station | safe zone | kill volumes |
|---|---|---|---|---|---|---|
| `sur_fireteam_01` | 2 | `(-104.845, 37.338, 17.762)` | start[2] | 4.98 | `safe_zone_soft_01` | none |
| `sur_fireteam_01` | 3 | `(-104.751, 33.617, 17.762)` | start[3] | 4.47 | `safe_zone_soft_01` | none |
| `sur_fireteam_02` | 2 | `(-101.472, 33.853, 17.768)` | start[12] | 1.45 | `safe_zone_soft_01` | none |
| `sur_fireteam_02` | 3 | `(-101.011, 37.052, 17.755)` | start[13] | 1.47 | `safe_zone_soft_01` | none |
| `sur_fireteam_04` | 0 | `(-102.288, 37.125, 17.762)` | start[4] | 2.54 | `safe_zone_soft_01` | none |
| `sur_fireteam_04` | 1 | `(-102.416, 33.873, 17.762)` | start[5] | 2.27 | `safe_zone_soft_01` | none |

Six distinct starts, so no squad gets a duplicated position. The containment test is calibrated on
this map (16/16 starts inside `safe_zone_soft_01`, 0/16 in any of its 62 `kill*` volumes), and the
polygon test is run on each new point individually by the fix script, as an assertion, before the
write.

"Near the kiosks" is measured against the six anchors the startup script actually installs
(`health_pack0/1/4/2` and the two `#_door_interior_large_logo_03/_04` machines). The installed
radius is 1.10 wu, and the closest new point is 1.45 wu from a station — outside it. That does not
matter either way: `fe_anyone_at` / `fe_buyer_at` poll `human_player_in_game_get 0…7` only, so an
AI ally standing on a station cannot trigger or be charged by it. Checked, not assumed.

### 2.4 What was written

56 bytes changed in 19 runs: the header checksum, and the six 12-byte `position` fields.
`build/r4/r4_regioncheck.py` reports **0 unexplained bytes**. No block was allocated, no count or
pointer changed, and the file size is unchanged.

---

## 3. FIX 2 — the win kiosk validates before it charges

### 3.1 The whole shop was checked, not just the win kiosk

Every `fe_transact` call site on every one of the seven maps, read out of the round-3 decompiles:

| station | precondition | before or after the charge? |
|---|---|---|
| troopers | `fe_has_room` | before |
| Spartans | `fe_gate_set` + `fe_has_spartan_room` | before |
| ammo | none | n/a |
| Longsword | `fe_gate_set` | before |
| bank | `fe_buyer_at` inside `fe_bank_use` | before (it *is* the affordability test) |
| **win** | `fe_gate_set` before; **`g_fe_won` and `b_survival_game_end_condition` after** | **after — the defect** |

The win kiosk was the only charge-then-validate path in the shop. Confirmed from the other end too:
`campaign_metagame_award_points` appears 22 times per cache — 8 in `fe_charge_at`, 8 in
`fe_credit_at`, and 6 in Bungie's own `test_award_*` debug scripts — so every deduction in the mod
goes through `fe_charge_at`, which is only reachable from `fe_transact` and from `fe_bank_use`'s
deposit arm, both of which test `fe_buyer_at` first.

### 3.2 The edit

In each map's own `fe_kiosk_win`, one line:

* was: `(if (fe_gate_set k_fe_gate_win) …)`
* now: `(if (and (fe_gate_set k_fe_gate_win) (not g_fe_won) (not b_survival_game_end_condition)) …)`

`and` short-circuits and already takes three arguments elsewhere in this dialect (`fe_near`). Both
globals already existed and were already referenced by `fe_mission_won` in the same compile unit,
so **no script object was added**: script count and global count are unchanged on every map, and
only the expression count moves, by exactly +8 per map. The guard inside `fe_mission_won` is kept
as belt and braces, which the read-back confirms on all seven.

The `(fe_deny …)` else-arm was already there, so a refusal now plays the deny sound and costs
nothing — the same behaviour the other five stations already had.

---

## 4. FIX 3 — `fe_valid` no longer accepts a corpse

Was `(>= (object_get_health who) 0)`, which is an **existence** test: `object_get_health` returns
a negative value for an absent player slot, so health exactly 0 — dead, not yet despawned —
satisfied it.

The replacement predicate was taken from stock rather than invented. Both
`f_blip_object_until_dead` and `f_blip_ai_until_dead` are present in **all seven** stock caches and
both define death as `(<= (object_get_health …) 0)`:

```
(script static void f_blip_object_until_dead (object obj)
  (chud_track_object obj true)
  (sleep_until (<= (object_get_health obj) 0))
  (chud_track_object obj false))
```

`f_blip_ai_until_dead` does the same on `(ai_get_object char)`, i.e. on a unit, which is exactly
`fe_valid`'s parameter type. If 0 is the dead side, alive is `> 0`. `fe_valid` is now
`(> (object_get_health who) 0)`, changed in all three compiled libraries
(`fe_shop_lib.hsc`, `fe_shop_ctgl.hsc`, `fe_reinforcements_wo.hsc`).

`src/hsc/fe_reinforcements.hsc` still carries the old `>= 0`. It is **in no compile unit** — the
Waterfront/Outpost pair use `fe_reinforcements_wo.hsc` — so it is dead source and was left alone
rather than edited blind. Anyone reviving it must apply this change first.

---

## 5. FIX 4 — Unearthed `marines6`: relocate, and why relocating was the better option

`research/29` §9 item 3 offered two options: relocate the two stray points, or demote `marines6`
and advertise `tuned` as the default. **Relocated.** The reasons, in order:

1. The edit is tiny and fully gated: two 12-byte `position` overwrites inside a block `marines6`
   itself allocated, no size change, Blamite-gated, 25 bytes changed in total with 0 unexplained.
2. Demoting `marines6` would ship the *feature* off by default. `tuned` is safe because it changes
   less, not because it plays better; six marines is the thing the build exists to deliver.
3. The coordinates needed are already in the cache. Nothing had to be invented.

### 5.1 Choosing the coordinates

A 30 wu sweep of every squad spawn point in the cache finds only six positions near the
`marine_rein` cluster (centroid `(46.70, 38.16, -3.81)` of its four original points):

| source | position | wu from centroid | used? |
|---|---|---|---|
| `marine_rein[0..3]` | the cluster itself | 0.59–1.41 | kept, untouched |
| `sq_sur_bob[1]` | `(47.905, 38.372, -3.836)` | 1.22 | **yes → point 4** |
| `scorpion[0]` | `(46.562, 36.149, -4.035)` | 2.07 | **rejected** |

`scorpion[0]` was rejected because it sits inside the ODST drop-pod cluster: `pod_player7` is at
`(46.834, 35.419, -4.136)` and `pod_player6`/`pod_player8` are 2.7–4.0 wu from the centroid at the
same Z, so a body placed there could land inside pod collision. `sq_sur_bob` is a placed one-actor
squad (`(ai_place "sq_sur_bob")` at line 6361 of the decompile) with four spawn points, of which
`[1]` is the one in this cluster, and its Z sits inside the cluster's own Z range.

That leaves one clean authored coordinate for two points, so **point 5 duplicates
`marine_rein[2]`** rather than interpolating a new one. Coincident spawn positions are shipped tag
data, not an invention:

* stock `ff60_icecave`: `sq_sur_wraith_01` and `sq_sur_wraith_02` each carry two **byte-identical**
  spawn points.
* this cache's own `warthog` squad carries two points 2.5 × 10⁻¹⁰ wu apart.

A sweep of all 281 squads in the eight stock caches found those three. `r4_ue_spawnfix.py` asserts
the precedent against the cache in front of it before writing.

### 5.2 What cannot be claimed for Unearthed

The containment reader does **not** calibrate on this map: 0 of its 16 player starting locations
register inside `safe_zone_soft`, and neither do the four **original** `marine_rein` points that
four marines have always spawned on successfully. So no safe-zone or kill-volume claim is made for
Unearthed, in either direction — same limitation as rounds 1 and 3. The evidence here is
provenance (every coordinate is a spawn position the map itself authors) and proximity (all six
points now lie within a 2.3 wu footprint at the same Z, where four bodies already work).

Result: `marine_rein` still declares 6 bodies and 6 spawn points, the two ~95 wu outliers are
gone, and the maximum separation between any two of its six points is 2.30 wu.

---

## 6. The ally spawn points this round did **not** move

Measured on the round-4 caches, against each map's own player starting locations. All are inside
the map's safe zone and in none of its kill volumes.

| map | wu out | ΔZ vs siblings | used by | dilution |
|---|---|---|---|---|
| Glacier | **28.86** | −1.8 | `01`/`02`, 1 of 4 each | 3 of 4 troopers arrive correctly |
| Waterfront | 15.82 and 13.53 | +1.2 / −0.9 | `03` (Spartans), **both of 2** | **none** |
| Waterfront | 14.42 | small | `02` 1 of 4; `04` (Spartans) 1 of 2 | partial |
| Outpost | 15.74 | +0.2 | `01` 1 of 4; `04` (Spartans) 1 of 2 | partial |
| Overlook | 15.00 | small | `02` 1 of 4; `04` (Spartans) 1 of 2 | partial |
| Beachhead | 13.07 | small | `sq_elite_fireteam_01`/`02`, 1 of 4 each | 3 of 4 arrive correctly |

None of these carries the different-storey signature — 2.6 wu of drop across 1.2 wu of ground —
that justified the risk of another write on Courtyard. The one worth naming is **Waterfront's
`sur_fireteam_03`**: both of its only two points are 13.5–15.8 wu out, so that Spartan purchase has
no nearer point to fall back on. It is the most likely remaining "my allies arrived in the wrong
place" report, and it is recorded in `KNOWN-ISSUES.txt` item 4.

---

## 7. Verification, and exactly which claims rest on reading shipped bytes

### 7.1 Per artifact, on the files in `ready-to-install/MOD-PACKAGE`

All nine shipped caches:

* **Blamite gate: PASS.** Re-run on this machine (`dotnet` + `hsc-compile --load-only`), on the
  package copies, not on the build outputs. `research/29` §0.4 recorded the gate as un-runnable
  here; that is not the case — it runs, it takes about a second, and all nine load.
* **stored header checksum == recomputed, on all nine.** `research/29` §8.5 recorded this as
  irreproducible. Also not the case: `reach_write.py --verify-checksum` matches on all nine shipped
  files **and on all nine stock caches**, so the XOR-after-header algorithm is confirmed, the method
  is right, and §8.5 should be read as superseded.
* **re-parse: 0 warnings**, fresh `ReachCacheFile` parse of each file.
* **size delta vs the file it replaces: +0** on all nine.

### 7.2 Script read-back, from the shipped bytecode

`build/r4/r4_shipcheck.py` decompiles each shipped `ff` map's own script table (variant
`reachmcc_u13`, per-map `--base-va` / `--scnr-offset` from that cache's header) and asserts, per
map: 0 `<!UNKNOWN…!>` markers; `fe_valid` contains `(> (object_get_health who) 0)` and no longer
contains `(>= … 0)`; `fe_kiosk_win` contains the three-term `and`; that term's text position
precedes `fe_transact`; `fe_mission_won` still holds its own guard; and for every other kiosk, that
its precondition, if it has one, precedes its charge. 127 assertions, all pass.

Round-2's work was re-counted in the same read-back and is intact on every map: `(game_won)` occurs
once per cache (inside Bungie's unreferenced `end_mission`), the proximity `>= 0` guard is present,
`object_destroy "dm_longsword_01"` survives only at Bungie's own sites, and `fe_squad_empty` is
present where round 2 put it.

### 7.3 Tag read-back, from the shipped `scnr`

Same script: Courtyard's four ally squads have at least as many spawn points as bodies, none of
their points is either of the two removed positions, every point is inside `safe_zone_soft_01` and
in no kill volume, and both of `sur_fireteam_04`'s points are at distance 0.000 from a player
starting location. Unearthed's `marine_rein` has 6 bodies and 6 points, neither outlier remains,
and the six points span 2.30 wu. `Firefight-Reinforcements-Safe/maps/ff_unearthed.map` is asserted
to still be md5 `5e9e9479815b12cdab4bc604e1fa0ccf`.

### 7.4 Byte-level accounting

* Script writes, published → round-4, all seven maps: `build/logs/wo_bytediff.py` reports
  **0 unexplained clusters** on each. The clusters are the header checksum, the `hs syntax datums`
  array, a few bytes in the `scripts` array, and the `hs syntax datums` count field. The `matg`
  locale-pointer check reports 0 changed dwords, i.e. no section rebase happened.
* Tag writes: `build/r4/r4_regioncheck.py` reports **0 unexplained bytes** on both — 56 changed
  bytes on Courtyard, 25 on Unearthed, all inside the header checksum or an intended `position`.

### 7.5 What is still not verified, and never was

* **Nothing has run in retail MCC.** Unchanged, and still the largest unknown in the project.
* **Walkability is still not measured.** The structure BSP collision was not read. A point can be a
  Bungie player start and the BSP was still never queried. This is an inference, a strong one.
* **No containment claim for Unearthed**, as in §5.2.
* `build/r4/r4_ct_spawnfix.py` takes the Courtyard station *names* from the round-3 decompile
  (`build/r3/out/ff20_courtyard.hsc`) rather than from the cache it is writing. That affects only
  the informational "wu to nearest station" column; the station set is unchanged by this round, and
  the positions come from the cache.

---

## 8. Artefacts

```
project/build/r4/
  build_r4.sh              the round-4 compile/write driver, with the bases hard-coded
  r4_inspect.py            player starting locations with all fields, spawn point blob addresses
  r4_tagcmp.py             tag-state equality between two caches (the lineage proof)
  r4_ct_spawnfix.py        Courtyard: 6 position fields, Blamite-gated
  r4_ue_spawnfix.py        Unearthed marines6: 2 position fields, Blamite-gated
  r4_verify.py             per-artifact battery against build/r4/out
  r4_shipcheck.py          the same checks against ready-to-install/MOD-PACKAGE
  r4_regioncheck.py        byte accounting for the two tag writes
  r4_bytediff.py           fix2/bytediff.py with the TagEntry field names it needs today
  out/                     the eight rebuilt caches + the two writer JSON reports
  readback/, shipback/     decompiles of the build outputs and of the shipped copies
  logs/                    compile, verify, shipcheck and byte-diff logs
_superseded/round3-published/   exactly what shipped before this pass, for diffing
```

Published md5s after this round:

```
1906f41a5eb1c76cd1b5d09ca44bb64d  ff10_prototype
a6c81dfa21215451cb14431ad4e2b80a  ff20_courtyard
824b6626692efc307836631e5a471114  ff30_waterfront
545ee71f154d6c72b8ed4dc9ccde0ba5  ff50_park
aeb8a8c058711af76b0a7a6ebe13b7cc  ff60_airview
619d3eb16397cc674f89e9a166b04238  ff60_icecave
06c855eb97bc90f3d167680e13e6d953  ff70_holdout
ab663d082774bbcc380e19ab73089563  ff_unearthed.marines6
5e9e9479815b12cdab4bc604e1fa0ccf  ff_unearthed.tuned        (unchanged)
```
