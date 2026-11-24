# 28 — Round-2 fix: the three ally-slot blockers on Waterfront and Outpost

Scope: `ff30_waterfront` and `ff60_airview` only, and within those two maps only the **ally-slot**
defects. The end-of-match path (`fe_mission_won`, BLOCKER-G1), the Longsword strike (RISK-G2) and the
`objects_distance_to_object` negative guard (RISK-G3) were a different agent's work in the same
session and are **not** this task's; they are present in the shipped artifacts because both agents'
edits to `src/hsc/fe_reinforcements_wo.hsc` were on disk when the compile ran (§8).

Inputs read before anything was written: `research/25-audit-round1-scripts.md` (the audit that found
these), `research/22-shops-waterfront-outpost.md` (how these two maps were built), and the five
passing maps' sources — `src/hsc/ff10_prototype.hsc`, `ff20_courtyard.hsc`, `ff50_park.hsc`,
`ff60_icecave.hsc`, `ff70_holdout.hsc` plus their libraries `fe_shop_lib.hsc` and `fe_shop_ctgl.hsc`.
**`fe_shop_ctgl.hsc` — the Courtyard / Glacier / Holdout library, Holdout being the map the audit
judged cleanest of the seven — is the pattern every script change below copies.**

---

## 0. Deliverables

| path | md5 | size | checksum stored == computed |
|---|---|---|---|
| `ready-to-install/ff30_waterfront.FINAL.map` | `f6a66e7941d6b121a157385267f31872` | 192,610,304 | `0x4FFEEFCE` == `0x4FFEEFCE` |
| `ready-to-install/ff60_airview.FINAL.map` | `1d39b192283b0382f262eb200759a8af` | 173,092,864 | `0x5CE91FB5` == `0x5CE91FB5` |

Both were also copied over `ready-to-install/MOD-PACKAGE/Firefight-Reinforcements/maps/<map>.map`
and md5-verified identical there, because that directory is what `INSTALL.BAT` actually installs and
leaving it on the pre-fix build would have shipped the blockers.

**Both files are the same size as the builds they replace.** The tag stage is same-size by
construction and the script stage was written onto a cache whose script table was still stock, so it
fit the same slack the first round's write did. (A second `write` onto an already-written FINAL
grows the cache by `0x70000`; that was tried, measured and discarded — see §7.)

---

## 1. What was wrong, restated from the artifacts rather than from the audit

Each of the three was re-measured in the shipped caches before being fixed, by decompiling them
(`tools/hsc/decompile.py`, `reachmcc_u13.xml`) and by reading the `scnr` squad block
(`build/r2/r2_inspect.py`, a fresh reader written for this task).

**WF-1 / OP-1 — `fe_has_room` was budget-only.** Read back out of both caches:
`(>= (fe_slots_free) k_fe_squad_size)` and nothing else. The five passing maps all add a
squad-emptiness term. The budget term alone cannot tell you a squad is reusable: with two 4-body
squads, `k_fe_actor_limit` 12 and `k_fe_squad_size` 4, both squads full gives
`fe_slots_free` = 12 − 8 = 4, which satisfies `>= 4`. The gate passed, 500 was charged, and
`ai_place` ran on a squad with four living members. The map can field at most 8 troopers, so the
third purchase could never deliver.

**WF-2 / OP-2 — delivery rotated blindly.** `fe_deliver_squad` selected on `g_fe_rotor`, a
two-step positional cycle, and never asked which squad was empty. The Spartan path had the mirror
failure: `fe_has_spartan_room` enforced the 4-body sub-cap but not emptiness, so with
`sur_fireteam_03` alive (2) and `sur_fireteam_04` wiped (0), `2 + 2 <= 4` passed and the rotor
re-placed the **living** squad while the empty one went unused.

**WF-3 / OP-3 — fewer spawn points than bodies.** Read from the `scnr`: `sur_fireteam_01` and
`sur_fireteam_02` each carry one cell with `normal diff count` = 4 and a `spawn points` block of
**2**. Every passing map gives a count-4 cell four points, and the Unearthed `marines6` build grew
`marine_rein`'s count and its point list together.

Also addressed, both from the same audit:

* **Waterfront's four ally cells shared one `initial secondary weapon` block** holding weapon
  palette `[12]` `plasma_rifle`, so every purchased human ally carried a Covenant weapon and any
  per-squad tweak would have edited all four.
* **`sur_fireteam_01` and `_02` shared one `initial weapon` block on both maps** (ally↔ally).

---

## 2. The script fixes — `src/hsc/fe_reinforcements_wo.hsc`

sha256 after the edit: `b8c6343b6608d690482d8acd9140303624adfcd4d62cc323b8e24bdc24d143f8`.
(`src/hsc/ff30_waterfront.hsc` `2410fe44…`, `src/hsc/ff60_airview.hsc` `e77342b6…` — comment-only
changes, recording that selection is now by occupancy.)

Three scripts added, four rewritten. Script count 403 → **406** on Waterfront and 386 → **389** on
Outpost; **global count unchanged** (225 / 217), so no new global was introduced.

| script | before | after |
|---|---|---|
| `fe_squad_empty (ai squad)` | — **new** | `(<= (ai_living_count squad) 0)` |
| `fe_trooper_slot_free` | — **new** | `or` over `fe_squad_empty` of `sur_fireteam_01` / `_02` |
| `fe_spartan_slot_free` | — **new** | `or` over `fe_squad_empty` of `sur_fireteam_03` / `_04` |
| `fe_has_room` | budget only | `and` budget `fe_trooper_slot_free` |
| `fe_has_spartan_room` | budget + sub-cap | budget + sub-cap + `fe_spartan_slot_free` |
| `fe_deliver_squad` | `cond` on `g_fe_rotor` | `cond` on per-squad emptiness, no fallback placement |
| `fe_deliver_spartans` | `cond` on `g_fe_spartan_rotor` | same shape, squads 03 / 04 |

All three new scripts are textually the `fe_shop_ctgl.hsc` versions, which already shipped on three
maps and passed the round-1 audit.

**Why "refuse the sale" needed no new wiring.** Both per-map kiosk files already test the gate
before the transaction and deny on failure — read back out of the shipped bytecode:

* trooper station: `(if (fe_has_room) (if (fe_transact "health_pack0" k_fe_cost_squad) (fe_deliver_squad)) (fe_deny "health_pack0"))`
* Spartan station: the same shape around `fe_has_spartan_room` with `(fe_deny "health_pack1")`.

So putting emptiness inside `fe_has_room` / `fe_has_spartan_room` is exactly "refuse the sale and
tell the player": `fe_deny` plays `sound\game_sfx\multiplayer\flag_failure` at the kiosk and no
`fe_charge_at` runs. **Nothing is deducted on a refusal**, because `fe_transact` is never reached.

**The delivery scripts are now belt-and-braces.** Each has an explicit `(true …)` clause that places
**nothing** and only debug-prints, so even if a guard were bypassed the worst case is a no-op rather
than `ai_place` on a live squad. The purchase counters `g_fe_buys` / `g_fe_spartan_buys` moved
*inside* the placing clauses, which also closes the COSMETIC finding audit 25 raised against
Overlook's fallback-less `cond` (the counter could lie).

**`g_fe_rotor` and `g_fe_spartan_rotor` are left declared and left set by each map's startup.** They
are now dead — exactly like `k_fe_cost_air` / `k_fe_gate_air` on Courtyard, Glacier and Holdout.
Removing a global from a published table is a larger change than leaving one unread, and the audit
already classes dead globals as cosmetic. Confirmed by decompiling the shipped artifact:
`g_fe_rotor` has exactly **2** textual occurrences, the declaration and the one startup `set`, and
appears nowhere in any delivery path.

---

## 3. The tag fixes — `build/r2/r2_tagfix.py`

Nothing grows. Every fresh blob is written into the still-zeroed tail of the `0x10000` page each map
was already granted in research/22 stage A (Waterfront file `0x0B431000`, Outpost `0x0A193000`). The
script asserts the destination range is all zero before writing, and asserts the output size equals
the input size. It publishes through `reach_write.CacheWriter.save()`, which refuses to write
anything Blamite will not load.

| map | last non-zero byte in the page | fresh blobs start | bytes used | free after |
|---|---|---|---|---|
| Waterfront | `0x0B43171E` | `0x0B431800` | 1,088 | ~58 KB |
| Outpost | `0x0A19371E` | `0x0A193800` | 1,056 | ~58 KB |

### 3.1 WF-3 / OP-3 — four spawn points per four-actor trooper cell

Each trooper squad gets a fresh 4-entry `spawn points` block: **its own two existing points copied
byte for byte**, plus two new points **cloned from that squad's own point 0 with only `position`
(offset `0x14`) changed**. Cloning rather than synthesising means `cell`, `reference frame`,
`structure bsp`, `vehicle type` (−1, on foot), `flags`, facing, seat and every other field keep a
value that already loads in this map.

The two new positions per squad are the **exact coordinates of that map's own player starting
locations**, chosen from the player-base cluster and never from the Elite cluster. The audit's one
unanswered question about class 8 was walkability — it could not read the BSP collision — so the
brief's preference was to copy Bungie-authored on-foot points rather than invent coordinates. A
player starting location is the strongest such point available: it is where the engine stands a
Spartan up on foot at round start.

| map | squad | kept (respawn-zone positions, unchanged) | added (player start index → position) |
|---|---|---|---|
| Waterfront | `sur_fireteam_01` | `(6.330, 221.514, 45.150)`, `(9.053, 227.516, 46.651)` | **0** → `(5.452, 220.682, 44.527)`; **2** → `(5.318, 223.352, 44.527)` |
| Waterfront | `sur_fireteam_02` | `(13.886, 210.813, 44.311)`, `(20.944, 224.123, 44.917)` | **3** → `(12.871, 210.548, 43.680)`; **5** → `(15.143, 210.984, 43.680)` |
| Outpost | `sur_fireteam_01` | `(-129.024, -129.972, 13.501)`, `(-117.594, -140.785, 13.690)` | **12** → `(-128.151, -128.905, 13.067)`; **13** → `(-131.673, -132.329, 14.503)` |
| Outpost | `sur_fireteam_02` | `(-139.386, -118.037, 12.803)`, `(-133.285, -131.560, 12.350)` | **3** → `(-145.054, -120.945, 14.244)`; **4** → `(-143.713, -120.671, 12.365)` |

**Which cluster is which was derived, not assumed.** Waterfront's 16 player starts fall into two
groups near the kiosks — `0/1/2/13` at `(5–6.5, 220–223, 44.5)`, which is the `health_pack0..3` pad,
and `3/4/5/12` at `(12.9–15.1, 210–211.5, 43.7)`, the `health_pack4/5` end — plus eight at
`(43–53, 229–236, 41–42)`. That third group is the **Elite** set: `elite_respawn_01` is placed at
`(55.868, 230.276, 42.830)`, inside it. Outpost splits the same way: Spartan starts `0/1/2/12/13`
and `3/4/5`, Elite starts `6/7/8/14` and `9/10/11/15`, confirmed by `elite_respawn_03`
`(-97.238, -115.616, 16.392)` and `elite_respawn_04` `(-111.476, -108.201, 15.911)` sitting in them.
Only Spartan-cluster starts were used.

The Spartan squads `sur_fireteam_03` / `_04` keep two points against a two-actor cell, which already
matched, and are untouched.

### 3.2 Waterfront's secondary weapon — repointed, never written through

The lesson the brief restates is this project's own: writing into a **shared** choice block is how an
earlier pass armed Waterfront's stock drop squad with a DMR, and `build/audit/unshare_fix.py` had to
restore it from the stock cache. So this pass **repoints**.

Each of the four Waterfront ally cells now owns a 1-entry `initial secondary weapon` block of its
own, allocated fresh, holding **Waterfront's own weapon palette `[4]` =
`objects\weapons\pistol\magnum\magnum`** — a human sidearm, read out of that map's palette, not
carried over from another map.

| cell | new blob | index |
|---|---|---|
| `sur_fireteam_01` | `0x0B431C00` | `[4]` magnum |
| `sur_fireteam_02` | `0x0B431C10` | `[4]` magnum |
| `sur_fireteam_03` | `0x0B431C20` | `[4]` magnum |
| `sur_fireteam_04` | `0x0B431C30` | `[4]` magnum |

The old shared blob at `0x0B431710` is **left byte-untouched** and is now unreferenced. That is
deliberate: it was itself a private ally copy made by `unshare_fix.py` (no stock squad pointed at
it — verified before the write, and `r2_tagfix.py` refuses to run if any sharer is a stock squad), so
there is nothing to restore, and zeroing it would be a write with no purpose.

**Outpost's ally cells carry no `initial secondary weapon` block at all** — count 0, read from the
cache — and were left that way, which is what the other five maps do. The alternative considered for
Waterfront was to drop the block to count 0 for symmetry; the magnum was chosen because it keeps a
feature the map already had while removing the thing the audit actually objected to, and it is a
2-byte palette index inside a private blob.

### 3.3 ally↔ally `initial weapon` sharing, both maps

`sur_fireteam_01` and `_02` shared one blob (`0x0B431700` / `0x0A193700`). Each now has a private
copy with **identical contents** — Waterfront `[7]` `dmr`, Outpost `[6]` `dmr` + `[0]`
`assault_rifle`. No loadout changed; the point is that a future per-squad weapon edit can no longer
reach the other squad. `r2_tagfix.py` asserts no stock squad shares the blob before copying.

---

## 4. Verification

Everything below was produced by re-opening a written file, never by trusting a writer's report.

### 4.1 Blamite, the mandated gate

`tools/map/reach_write.py --blamite-gate` was run on every artifact, and `CacheWriter.save()` gates
internally as well, so each file passed twice:

| artifact | verdict |
|---|---|
| `build/r2/lin/<map>.tagfix.map` (both) | **LOAD: OK** (gated inside `save()`) |
| `build/r2/out/<map>.FINAL.map` (both) | **LOAD: OK**, Waterfront 12 packs / 100,061 strings, Outpost 12 / 100,261 |
| `ready-to-install/<map>.FINAL.map` (both) | **LOAD: OK** |
| `MOD-PACKAGE/.../<map>.map` (both) | **LOAD: OK** |

### 4.2 Re-parse and checksum

`build/logs/wo_verify.py` re-opens the published file from scratch:

| map | tags | groups | named | string ids | warnings | size |
|---|---|---|---|---|---|---|
| Waterfront | 14,181 | 235 | 14,177 | **57,110** | **0** | 192,610,304 |
| Outpost | 14,547 | 235 | 14,542 | **66,685** | **0** | 173,092,864 |

Tag, group and named counts are identical to research/22 §4.1 and to audit 25. The string-id count
rises by exactly **3** over the round-1 FINALs (57,107 → 57,110 and 66,682 → 66,685) — one per new
script, which is how Blamite registers script names. `build/logs/cks.py` recomputes the header
checksum by an independent XOR: **stored == computed on both**.

### 4.3 Compile

| map | parse errors | expressions | scripts | globals | tag refs | string bytes | lint |
|---|---|---|---|---|---|---|---|
| Waterfront | **0** | 16,801 | **406** | 225 | 20 | 25,506 | 187 |
| Outpost | **0** | 16,376 | **389** | 217 | 18 | 25,034 | 170 |

Every lint finding is `print` marked `null="true"` in the U13 table, nearly all of them in Bungie's
own stock text; the seven in our files are all behind `(if g_fe_debug …)`. Two script-object
references come back unresolved on both maps, `ai_current_actor` and `ai_current_squad`, both from
Bungie's own stock text — the same two the Holdout and round-1 Waterfront/Outpost writes shipped
with, i.e. reference behaviour rather than a new defect.

### 4.4 Byte diff, decomposed by stage — 0 unexplained

The diff was split so each stage could be classified by a tool that knows that stage.

**Stage A, tag edits only** (`<map>.unshare.map` → `<map>.tagfix.map`). `build/logs/wo_bytediff.py`
reports these runs as unexplained, correctly: it was never taught these fields.
`build/r2/r2_regioncheck.py` supplies the missing classifier and derives every intended region from
the child's **own tag data** plus the writer's report, not from a reading of the diff:

| map | runs | changed bytes | intended regions | unexplained |
|---|---|---|---|---|
| Waterfront | 87 | 354 | header checksum; 2 × squad `spawn points` block field; 2 × cell `initial weapon` block field; 4 × cell `initial secondary weapon` block field; the 1,088-byte fresh-blob extent | **0** |
| Outpost | 67 | 388 | header checksum; 2 × squad `spawn points` block field; 2 × cell `initial weapon` block field; the 1,056-byte fresh-blob extent | **0** |

**Stage B, script write only** (`<map>.tagfix.map` → `<map>.FINAL.map`). `wo_bytediff.py` reproduces
the seven-cluster pattern research/22 §4.3 documented, with **0 unexplained** on both maps:
cache header; string-id index table; string-id data blob; `matg globals` locale pointers; the scnr
`globals` + `hs syntax datums` + `references` span (493,692 B Waterfront, 480,452 B Outpost); the
scnr `scripts` block data (22,019 B / 21,259 B); and the seven scnr script block fields (234 B).
The `matg` check is the one that had to be proved rather than named, and it still passes the strict
form: **24 changed dwords, a single delta** — `−13,000,704` on Waterfront and `−48,238,592` on
Outpost, the same two numbers research/22 recorded. More than one delta would have been reported as
unexplained.

**Cumulative**, published-build-before → published-build-after: 7,634 runs in 10 clusters on
Waterfront and 7,588 in 10 on Outpost — the seven of stage B plus the three of stage A, size delta
**0**.

### 4.5 Containment, with a calibrated reader

`build/r2/r2_contain.py` reads every `scnr` trigger volume with its full field set (type,
forward/up frame, position, extents, z sink, `sector points` polygon, runtime sector bounds) and
tests points against the map's `scenario safe zone triggers` and `scenario kill triggers` index
lists. It uses the **polygon** test throughout, which audit 25 established is the trustworthy one
(bounding boxes give false positives on these two maps in particular).

It is calibrated in both directions on every run, and it reproduces the audit's own number:

| map | safe-zone volume | kill volumes | player starts inside safe zone and in no kill volume | absurd control |
|---|---|---|---|---|
| Waterfront | `safe_zone_soft_01`, 22 sector points, z `[40.725 .. 52.185]` | 20 | **16/16** | outside |
| Outpost | `safe_zone_soft`, 30 sector points, z `[9.337 .. 27.235]` | 25 | **16/16** | outside |

An early version of this reader scored 0/16 because it assumed a 12-byte sector point; the block is
20 bytes (`real_point_3d position` + `real_euler_angles_2d normal`). That failure is recorded here
because it is why the calibration step exists.

Result for the points that matter: **all four new spawn points and all six pre-existing Waterfront
ally points, and all four new plus five pre-existing Outpost ally points, are inside
`safe_zone_soft` and inside no kill volume.** For the four new ones per map this is doubly
established, since they *are* player starting locations and the calibration run tests exactly those.

### 4.6 Read the artifact back — the honesty check

`build/r2/r2_readback.sh` decompiles a **built cache's own script table** (`decompile.py`,
`--variant reachmcc_u13`, this map's own string-id table from
`tools/map/sid_table_for_scripts.py`) and prints the purchase path. Run on
`ready-to-install/<map>.FINAL.map`, i.e. the file that ships, not on an intermediate:

* 12/12 wanted scripts present on both maps, none missing.
* `fe_has_room` reads `(and (>= (fe_slots_free) k_fe_squad_size) (fe_trooper_slot_free))`.
* `fe_has_spartan_room` reads budget `and` (sub-cap `and` `fe_spartan_slot_free`).
* `fe_squad_empty` reads `(<= (ai_living_count squad) 0)`.
* `fe_deliver_squad` / `fe_deliver_spartans` read as a three-clause `cond` on
  `(fe_squad_empty "sur_fireteam_0N")` with the counter inside each placing clause and a `(true …)`
  clause that places nothing.
* `fe_kiosk_reinforce` / `fe_kiosk_spartan` still test the gate before `fe_transact` and still
  `fe_deny` on failure.
* `g_fe_rotor` occurs twice: its declaration and the startup `set`. It is in no delivery path.
* The per-map kiosk radius survived: Waterfront's startup still `(set k_fe_kiosk_radius 1.45)`
  against its 3.039 minimum separation, Outpost's still `1.1` against 2.336.

**No stock script changed.** `build/r2/r2_scriptdiff.py` diffs script bodies name by name between
two decompiles produced by the same printer. Against each map's own stock decompile
(`extracted/<map>/scripts/<map>.hsc`):

| map | scripts lost | scripts added | stock bodies differing |
|---|---|---|---|
| Waterfront | **0** | 42 (41 `fe_*` + the `player_count` shim) | **1** |
| Outpost | **0** | 42 | **1** |

The one difference is the known reader artifact audit 25 §class 9 documented: the injected
`player_count` shim's body is `(list_count (players_human))` where stock is `(list_count (players))`,
and its name mis-resolves through the string-id table. In Firefight every player is on the human
team, so the two return the same count. It is identical to what the round-1 build shipped.

And against the **previously published** build of each map, the whole script-level delta is this
task's:

| map | scripts lost | added | bodies differing |
|---|---|---|---|
| Waterfront | 0 | `fe_squad_empty`, `fe_trooper_slot_free`, `fe_spartan_slot_free` | `fe_has_room`, `fe_has_spartan_room`, `fe_deliver_squad`, `fe_deliver_spartans` |
| Outpost | 0 | the same three | the same four |

### 4.7 Tag state re-read from the published bytes

`wo_verify.py` and `build/r2/r2_inspect.py` on the published files:

| map | squad | cell actors | major | spawn points | all `veh` / `bsp` |
|---|---|---|---|---|---|
| Waterfront | `sur_fireteam_01` / `_02` | 4 | 3 `none` | **4** / **4** | −1 / 0 |
| Waterfront | `sur_fireteam_03` / `_04` | 2 | 4 `all` | 2 / 2 | −1 / 0 |
| Outpost | `sur_fireteam_01` / `_02` | 4 | 3 `none` | **4** / **4** | −1 / 0 |
| Outpost | `sur_fireteam_03` / `_04` | 2 | 4 `all` | 2 / 2 | −1 / 0 |

Unchanged and re-confirmed: `gr_survival_fireteams` is a **root** group on both (parent −1, index 6
and 9); char palette `[23]` / `[24]` still resolves to `objects\characters\spartans\spartans`; both
equipment palettes still hold five entries ending in `jet_pack`; Waterfront's
`obj_fireteams`/`fireteams` is still `follow = 1`, radius 3.0, Z clamp 1.0, filter 6 and Outpost's
`follow = 1`, radius 8.0, Z clamp 1.0, filter 9; `sur_fireteam_05` and `_06` are still 0 cells /
0 spawn points, so the ODST tier is still available.

**No ally cell on either map now points into a block referenced by any other squad.** The blob-share
index in `r2_inspect.py` walks every squad's designer and templated cells and all four choice-block
fields plus the spawn-point and cell blobs. Shared blobs still reported on each map are **stock↔stock
only** — Waterfront's phantoms, drop squads, banshees and snipers; Outpost's phantoms, ghosts and
snipers — which is Bungie's own authoring and was deliberately not touched. Count of shared blobs
with any `sur_fireteam_*` on either side: **0, on both maps.**

---

## 5. Constraints, each one checked

| constraint | result |
|---|---|
| zero new script objects | 2 distinct script-object references in the compile unit, both Bungie's own (`ai_current_actor`, `ai_current_squad`), same as every previous write. Every object, squad, group, objective and task named by the new code (`sur_fireteam_01..04`, `gr_survival_fireteams`, `obj_fireteams`/`fireteams`, `health_pack0..5`) already existed in that map's `scnr`; the three new scripts name only squads already named by the old ones. |
| verify every reference against that map's own tag data | weapon palette `[4]` magnum, `[7]`/`[6]` dmr, `[0]` assault_rifle read out of each map's own `weapon palette`; all added spawn coordinates read out of each map's own `player starting locations`; cluster membership cross-checked against each map's own `elite_respawn_*` scenery. |
| `reach_write.py --blamite-gate` on every write | §4.1 — six artifacts, all **LOAD: OK**, each gated twice. |
| nothing ships that fails the gate | `CacheWriter.save()` writes to a temp file, gates it, and raises without publishing on reject. Nothing was published that had not passed. |
| re-parse 0 warnings | §4.2 — 0 on both. |
| checksum stored == computed | §4.2 — both, by an independent XOR. |
| byte-diff with nothing unexplained | §4.4 — stage A 0 unexplained via `r2_regioncheck.py`, stage B 0 unexplained via `wo_bytediff.py`, including the strict single-delta `matg` check. |
| read-only sources | `maps-stock/*.map` opened read-only by `unshare_fix.py` only, never written; `staged-maps/` not touched this round; all work on copies under `build/r2/`. |

---

## 6. What is still open

1. **Nothing here has run in MCC.** Blamite loading a cache proves the container and tag graph are
   well formed. It does not prove the engine places four actors on four points, that a magnum
   secondary appears, or that an ally walks out of a player spawn.
2. **Walkability is still inference, not measurement.** The BSP collision was not read. The claim is
   that a player starting location is a position Bungie stands a Spartan up on, which is the best
   available evidence and better than the respawn-zone scenery positions the first build used — but
   it is not a collision query.
3. **Cross-squad spawn-point reuse remains**, as research/22 §7.3 recorded: Waterfront's
   `sur_fireteam_04` reuses `_01`'s and `_02`'s second points, Outpost's `_03`/`_04` reuse `_01`'s
   and `_02`'s. Two actors assigned to one position should be nudged apart by the engine. Out of
   scope this round; the trooper squads' four points are now four distinct positions each.
4. **The isolated ally spawn points the audit flagged are unchanged**: Waterfront's
   `(-7.742, 226.672, 45.748)` and `(-4.103, 208.114, 43.592)` on `sur_fireteam_03` are 13.5 and
   15.8 wu from the nearest player start, and Outpost's `(-117.594, -140.785, 13.690)` is 15.8 wu.
   They are in-arena and in no kill volume. Moving them is a placement-quality change, not a blocker,
   and would need the same player-start treatment applied to the Spartan tier.
5. **`g_fe_rotor` / `g_fe_spartan_rotor` are now dead globals**, still set by each startup. Cosmetic,
   consistent with the dead air-tier globals on three other maps.
6. **`fe_report` is still a dead debug stub** and `fe_retire_allies` is still never called, on both
   maps. Both are audit-25 cosmetics and neither is an ally-slot defect.
7. **Outpost's ally follow radius is still 8.0** against 3.0 everywhere else, and its kiosk
   separation headroom is still the thinnest in the pack at 0.068 wu. Both are attested from that
   map's own tag data and neither was in scope.
8. **The on-screen price text is still frozen** by the `matg` SHA-1, as it has been since the first
   build.

---

## 7. Two things that were tried and rejected

**Writing the new script table onto the already-written FINAL.** The first attempt used the published
`FINAL` as the base for both the tag fix and the script write. It produced a cache Blamite loads, but
**192,610,304 → 193,069,056 bytes**: the second write's table no longer fits the slack the first
write left, so Blamite grew the file by `0x70000` and orphaned the old table. It was discarded in
favour of rebuilding the documented lineage —
`loadout → unshare_fix → r2_tagfix → one script write` — which lands on exactly the shipped size and
leaves one script table in the file. This is recorded because the parallel end-of-match work took the
other route, and its artifacts are `+0x70000` for that reason.

**Dropping Waterfront's secondary block to count 0** for symmetry with the other six maps. Rejected
in favour of the private magnum block: it removes the Covenant weapon, which is what the audit
objected to, without removing a feature the map had.

---

## 8. Concurrency, and what that means for the next person

`src/hsc/fe_reinforcements_wo.hsc` was edited by **two agents at once** on 2026-11-23: this task's
ally-slot work and a parallel task's end-of-match (`fe_mission_won`, BLOCKER-G1), Longsword
(RISK-G2) and proximity-guard (RISK-G3) work. The two edit disjoint scripts and neither overwrote the
other, but the consequence matters:

* **The artifacts published here carry both sets of edits**, because both were on disk when the
  compile ran. Decompiling the shipped Waterfront confirms `fe_mission_won` ends with
  `survival_spartans_increment_score` / `event_survival_spartans_win_normal` /
  `submit_incident "survival_mm_game_complete"` / `(set b_survival_game_end_condition true)` — not
  `(game_won)` — and that `fe_near` carries the `(>= (objects_distance_to_object …) 0)` guard. That
  work is not this task's and is not attested here; it is simply present.
* **The tag-level WF-3 / OP-3 fix is not reproducible by recompiling scripts.** Any later rebuild of
  these two maps must use `build/r2/lin/<map>.tagfix.map` as its base, or it will silently ship four
  bodies against two spawn points again. `build/r2/README-COORDINATION.txt` says so at the build
  tool's own level, with the commands.

---

## 9. Reproducible sequence

```bash
PROJ="$HOME/Desktop/Halo-Firefight/project"; cd "$PROJ"
RI="$HOME/Desktop/Halo-Firefight/ready-to-install"
MAPS="ff30_waterfront ff60_airview"

# read-only survey of the shipped artifact: squads, cells, every choice-block
# pointer and who else points at it, spawn points, player starts, palettes
for m in $MAPS; do python3 build/r2/r2_inspect.py $RI/$m.FINAL.map --json build/r2/$m.json; done

# calibrate the containment reader on each map's own 16 player starts, then test
# the candidate coordinates
for m in $MAPS; do python3 build/r2/r2_contain.py $RI/$m.FINAL.map <x,y,z ...>; done

# rebuild the documented lineage: loadout -> unshare -> tag fix -> ONE script write
mkdir -p build/r2/lin build/r2/out
for m in $MAPS; do
  cp build/wo/$m.loadout.map build/r2/lin/$m.base.map
  python3 build/audit/unshare_fix.py $m $HOME/Desktop/Halo-Firefight/maps-stock/$m.map \
      build/r2/lin/$m.base.map build/r2/lin/$m.unshare.map
  python3 build/r2/r2_tagfix.py $m build/r2/lin/$m.unshare.map build/r2/lin/$m.tagfix.map
  cp build/r2/lin/$m.tagfix.map build/r2/out/$m.FINAL.map
  ./build/logs/wo_compile.sh write build/r2/out/$m.FINAL.map \
      build/wo/fe_culled_shims.hsc build/wo/$m/stock_unescaped.hsc \
      src/hsc/fe_reinforcements_wo.hsc src/hsc/$m.hsc
  ./build/logs/wo_compile.sh gate build/r2/out/$m.FINAL.map
done

# verify, independently of every writer
for m in $MAPS; do
  python3 build/r2/r2_regioncheck.py build/r2/lin/$m.unshare.map build/r2/lin/$m.tagfix.map \
      build/r2/lin/$m.tagfix.map.r2tagfix.json          # stage A, 0 unexplained
  python3 build/logs/wo_bytediff.py $m build/r2/lin/$m.tagfix.map build/r2/out/$m.FINAL.map
  python3 build/logs/wo_verify.py   $m $RI/$m.FINAL.map build/r2/out/$m.FINAL.map
done
python3 build/logs/cks.py build/r2/out/*.FINAL.map

# publish both copies, then gate what was published, then read it back
for m in $MAPS; do
  cp build/r2/out/$m.FINAL.map $RI/$m.FINAL.map
  cp build/r2/out/$m.FINAL.map $RI/MOD-PACKAGE/Firefight-Reinforcements/maps/$m.map
  python3 tools/map/reach_write.py --blamite-gate $RI/$m.FINAL.map
  python3 tools/map/reach_write.py --blamite-gate $RI/MOD-PACKAGE/Firefight-Reinforcements/maps/$m.map
  ./build/r2/r2_readback.sh $RI/$m.FINAL.map pub_$m build/r2/readback
  python3 build/r2/r2_scriptdiff.py extracted/$m/scripts/$m.hsc build/r2/readback/pub_$m.decomp.hsc
done
```

---

## 10. Files

| path | what |
|---|---|
| `ready-to-install/ff30_waterfront.FINAL.map` | **deliverable**; also copied to `MOD-PACKAGE/Firefight-Reinforcements/maps/ff30_waterfront.map` |
| `ready-to-install/ff60_airview.FINAL.map` | **deliverable**; also copied to `…/maps/ff60_airview.map` |
| `src/hsc/fe_reinforcements_wo.hsc` | WF-1/2 and OP-1/2: three new scripts, four rewritten (shared file — see §8) |
| `src/hsc/ff30_waterfront.hsc`, `src/hsc/ff60_airview.hsc` | comment-only: station 1 now documents occupancy selection |
| `build/r2/r2_inspect.py` | read-only `scnr` reader: squads, cells, every choice-block pointer + its sharers, spawn points, player starts, palettes, trigger volumes |
| `build/r2/r2_contain.py` | sector/box containment test for safe-zone and kill volumes, self-calibrating on the map's own player starts |
| `build/r2/r2_tagfix.py` | WF-3/OP-3 spawn points, the private secondary blocks, the ally↔ally weapon unshare; same-size, Blamite-gated |
| `build/r2/r2_regioncheck.py` | proves every byte the tag stage changed lies in an intended field |
| `build/r2/r2_readback.sh` | decompiles a built cache and prints the purchase path back out of its own bytecode |
| `build/r2/r2_scriptdiff.py` | per-script body diff between two decompiles |
| `build/r2/README-COORDINATION.txt` | **the base-map warning for anyone who rebuilds these two maps** |
| `build/r2/lin/<map>.tagfix.map` | tag state fixed, script table still stock+shim: the correct base for a future script write |
| `build/r2/out/<map>.FINAL.map` | what was published, byte-identical by md5 |
| `build/r2/<map>.verify.json`, `build/r2/*.log`, `build/r2/readback/*` | every number above, with the logs behind it |
