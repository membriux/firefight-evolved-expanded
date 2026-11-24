# 27 — Fix round 2: the win purchase, the Longsword and the proximity guard

Scope: the three findings of `25-audit-round1-scripts.md` that apply to all seven rebuilt maps —
**BLOCKER-G1** (the 10,000-point win purchase used a campaign call, not Firefight's end path),
**RISK-G2** (the Longsword strike could permanently deadlock the stock weapon-resupply loop) and
**RISK-G3** (`objects_distance_to_object` returns a negative value for an absent object, and a
negative value passes a `< radius` test) — plus the `g_fe_won` latch that made a failed win
unrecoverable.

Out of scope, deliberately: the Waterfront and Outpost **ally-slot** blockers (audit class 4). Those
are a separate workstream and its edits to `src/hsc/fe_reinforcements_wo.hsc` landed while this round
was building; its builds then superseded this round's for those two maps and were re-verified here
to carry all three of these fixes as well. See §7.1.

Maps rebuilt: `ff10_prototype`, `ff20_courtyard`, `ff30_waterfront`, `ff50_park`, `ff60_airview`,
`ff60_icecave`, `ff70_holdout`. `ff_unearthed.marines6.map` and `ff_unearthed.tuned.map` were **not
touched** — their MD5s and mtimes are unchanged (`94851196…` / `5e9e9479…`, 2026-11-23 01:03 and
01:05), as is the author's read-only `maps-stock/ff_unearthed.map`.

---

## 1. What was wrong, and what the two oracles actually say

`fe_mission_won` ended with `(game_won)`. `game_won` is a live opcode (`0x442`, void, 0 args, not
`null="true"`) in `reachmcc_u13.xml`, and "it is in the table" was the whole justification on record.
Being in the table says nothing about what it does inside a survival game.

**Oracle 1 — Bungie, read out of each target map's own decompiled script table.** Every stock end
condition raises a boolean and lets one script end the match:

```
(script dormant void survival_mode_end_condition_complete     ; the "players finished it" case
  (sleep_until (and (> (survival_mode_get_set_count) 0)
                    (>= s_survival_wave_complete_count (survival_mode_get_set_count))) 10)
  (sleep 30)
  (survival_spartans_increment_score)
  (event_survival_spartans_win_normal)
  (submit_incident "survival_mm_game_complete")
  (set b_survival_game_end_condition true))
```

and

```
(script dormant void survival_end_game
  (wake survival_mode_end_condition_lives) … (wake survival_mode_end_condition_complete)
  (sleep_until b_survival_game_end_condition 1)
  … (sleep_forever survival_mode) … (sound_looping_stop m_final_wave)
  (sleep 30) (sleep 90)
  (mp_round_end_with_winning_team none))
```

`survival_end_game` is woken **once**, unconditionally, by `survival_mode` at startup
(`(wake survival_end_game)`, one call site in each of the seven caches), and then parks on that
`sleep_until`. Raising `b_survival_game_end_condition` is the documented way into it, and it does the
`sleep_forever` sweep of the whole survival machine before ending the round — something a direct
`mp_round_end_with_winning_team` from our own script could not do.

`(game_won)` appears exactly **once** in each of the seven caches, as the entire body of a leftover
campaign script `end_mission`, which nothing in Firefight calls. Confirmed by reading the decompile:

```
(script static void end_mission
  (game_won)
)
```

**Oracle 2 — the author, read out of `maps-stock/ff_unearthed.map` for this round.** That file was
decompiled here (base-va `0x199C27000`, scnr offset `0x306D9FC8`, `reachmcc_u13.xml`, expand magic
`0x50000000`; 16,195 lines). His `buy_mac` charges 10,000, destroys the terminal, creates
`sc_cannon_cruiser_target`, then:

```
          (wake you_win)
          (sleep_forever)
```

and `you_win` ends:

```
  (sleep 90)
  (event_survival_spartans_win_normal)
  (submit_incident "survival_mm_game_complete")
  (set b_survival_game_end_condition true)
)
```

`game_won` is nowhere in that path. His `you_lose` is the mirror image with
`event_survival_elites_win_normal`.

### The claim that blocked this in round 1 was a namespace confusion

`fe_shop_lib.hsc` §15, `fe_shop_ctgl.hsc` §13 and `fe_reinforcements*.hsc` all carried a note saying
`survival_spartans_increment_score` and `event_survival_spartans_win_normal` "are NOT in the U13
table (research/18 section 5)". That is true and irrelevant: they are not **engine opcodes**, they
are **scenario scripts**. Grepping `reachmcc_u13.xml` for them returns nothing; grepping each map's
own script table returns both. All four comments have been corrected in place.

### Verified present, per map, before use

Read from each map's own decompiled script table (the same text that is fed back to the compiler as
the stock half of the compile unit), not from any earlier research note:

| map | `b_survival_game_end_condition` | `survival_end_game` | `(wake survival_end_game)` | `survival_spartans_increment_score` | `event_survival_spartans_win_normal` |
|---|---|---|---|---|---|
| Overlook `ff10_prototype` | global, L131 | dormant, L2135 | 1 | static void, 0-arg, L2257 | static void, 0-arg, L2755 |
| Courtyard `ff20_courtyard` | global, L131 | dormant, L2132 | 1 | L2254 | L2752 |
| Waterfront `ff30_waterfront` | global, L131 | dormant, L2136 | 1 | L2258 | L2756 |
| Beachhead `ff50_park` | global, L132 | dormant, L2376 | 1 | L2498 | L2996 |
| Outpost `ff60_airview` | global, L131 | dormant, L2128 | 1 | L2250 | L2748 |
| Glacier `ff60_icecave` | global, L131 | dormant, L2125 | 1 | L2247 | L2745 |
| Holdout `ff70_holdout` | global, L131 | dormant, L2135 | 1 | L2257 | L2755 |

Nothing was substituted on any map and no map needed an equivalent: the author's pattern is
reproducible verbatim on all seven. `submit_incident` is opcode `0x6E8`, argc 1, in the U13 table,
and `"survival_mm_game_complete"` is a string **both stock end conditions already pass**, so the
scnr string table did not grow by a single byte on any map.

---

## 2. The three fixes, as shipped

### 2.1 BLOCKER-G1 — the end path

`fe_mission_won` now ends with Bungie's own four-call win sequence, in Bungie's order. The author's
three calls are the last three of those four; `survival_spartans_increment_score` is kept because it
is in Bungie's win case and the audit noted that without it the end-of-match score and the medal /
incident record would be wrong. It is a 0-arg scenario script present in all seven caches.

Shipped shape (library form; the Courtyard/Glacier/Holdout and Waterfront/Outpost forms are the same
with the pre-existing `fe_blip` / `fe_unblip` beacon pair, placed before the end condition is raised
so a kiosk is never left blipped):

```
(script static void fe_mission_won
    (if (and (not g_fe_won) (not b_survival_game_end_condition))
        (begin
            (set g_fe_won true)
            (sleep 30)
            (ai_kill_no_statistics "gr_survival_all")
            (sleep 60)
            (survival_spartans_increment_score)
            (event_survival_spartans_win_normal)
            (submit_incident "survival_mm_game_complete")
            (set b_survival_game_end_condition true)
            (sleep 1800)
            (set g_fe_won false)
        )
    )
)
```

### 2.2 The `g_fe_won` latch is no longer permanent

Two changes, both visible above:

* the entry test gained `(not b_survival_game_end_condition)`, so the sequence cannot start while an
  end condition is already pending — including one raised by a stock condition;
* the latch is cleared 1800 ticks (60 s) after the end condition is raised. If the match ended there
  is nothing left to observe it. If it did **not** end, the station is live again and the player can
  retry. There is no exploit in re-opening it: the charge is taken at the kiosk by `fe_transact`
  before `fe_mission_won` is ever called, so a retry costs another 10,000.

The per-map `(set g_fe_won false)` in each startup script is untouched; it still resets the latch at
map load. What is new is recovery **within** a session.

### 2.3 RISK-G2 — the Longsword. Chosen fix: stop destroying the device.

The collision, read out of each map's own stock script:

```
(script dormant void survival_resupply_pod_spawn
  … (object_create "dm_longsword_01") … (object_create_folder_anew "cr_grenades") (sleep 1)
  (device_set_position_track "dm_longsword_01" "ff10" 0)
  (device_animate_position "dm_longsword_01" 1 10 3 3 false)
  (sleep_until (>= (device_get_position "dm_longsword_01") 0.4) 1)      ← blocks here
  … (wake resupply_target_0N) … (wake resupply_pod_0N) …
  (sleep 120) (object_destroy "dm_longsword_01") false))
```

That whole body is the condition of an infinite `(sleep_until (begin … false))`. An
`object_destroy` landing inside the `sleep_until` window removes the device the loop is polling, the
condition can never become true, and the loop never completes another cycle: **no further weapon or
grenade drops for the rest of the match.**

Of the three options in the brief — stop destroying, pick a different object, restore the position
afterwards — **the first was taken.** Reasons, in order:

1. *Pick a different object* is not available. The strike is the Longsword flyby; there is no second
   longsword in any of the six scenarios, and inventing one would be a new script object, which the
   constraints forbid.
2. *Restore the position afterwards* means writing to the device **after** our animation finishes.
   That write can itself land inside a stock `sleep_until` window and re-create the exact deadlock
   being removed — `device_set_position_track … 0` puts the position back below `0.4`. It trades a
   known hazard for a smaller instance of the same hazard.
3. *Stop destroying* removes the only unrecoverable interaction and adds no new window. What remains
   is our opening `device_set_position_track "dm_longsword_01" "ff10" 0`, which can reset the track
   under a stock animation — but our own `device_animate_position … 1 10 3 3 false` immediately
   drives the position to 1, past `0.4`, and holds it there through `(sleep 90)` + `(sleep 120)` =
   210 ticks while stock polls at 1-tick granularity. That path self-heals; the audit says so too.
   Stock calls `object_create` **and** `device_set_position_track` on this machine at the head of
   every one of its own cycles and destroys the device itself at the end of each, so it needs nothing
   of ours to persist.

Cost of the fix: cosmetic only. Between our pass and the next stock resupply the longsword sits at
the end of its flight path instead of being removed.

Applied to all six maps that sell a strike — `fe_deliver_strike` in `fe_shop_lib.hsc` (Overlook,
Beachhead) and in `fe_reinforcements_wo.hsc` (Waterfront, Outpost), `fe_ct_deliver_strike` in
`ff20_courtyard.hsc`, `fe_ho_deliver_strike` in `ff70_holdout.hsc`. Glacier sells no strike and has
**zero** references to `dm_longsword_01` in its cache; it needed nothing and got nothing.

### 2.4 RISK-G3 — the `-1` proximity hole

`objects_distance_to_object` returns a negative value when the object list is empty or the object is
absent, and `(< -1 radius)` is true, so an absent or destroyed anchor reported **every** player as
standing on it. `fe_valid` covered the player; nothing covered the kiosk.

```
(script static boolean fe_near (unit who, object kiosk)
    (and
        (fe_valid who)
        (>= (objects_distance_to_object who kiosk) 0)
        (< (objects_distance_to_object who kiosk) k_fe_kiosk_radius)
    )
)
```

`fe_near` is the **only** proximity test in the mod: `objects_distance_to_object` appears in exactly
one script in each library (`grep` over `src/hsc/*.hsc` — every other occurrence is a comment), and
every station reaches the player through `fe_near` → `fe_anyone_at` / `fe_buyer_at` / `fe_charge_at`.
Guarding `fe_near` therefore guards every proximity test on every map.

Why the distance term and **not** a health test on the kiosk: Bungie's
`survival_health_pack_highlight` tests `(< (object_get_health pack) 0)` because its anchors are
`equipment`. Five of our anchors are `device_machine` doors (three on Holdout, two on Courtyard), and
there is no evidence here about what `object_get_health` returns for a door with no damage model. A
health guard that reads negative on a healthy door would silently disable five working stations. The
`(>= … 0)` term addresses the defect exactly — a present object cannot be at a negative distance —
and cannot disable anything that works today. `and` short-circuits, so the second distance call only
runs once the first has proved the object is present.

### 2.5 Also corrected: `src/hsc/fe_reinforcements.hsc`

That file is **not compiled into any shipped map** (Holdout is built from `fe_shop_ctgl.hsc` +
`ff70_holdout.hsc`), but it carried the same `(game_won)`, the same unguarded `fe_near` and the same
Longsword destroy. All three are fixed there too, so it cannot reintroduce the blocker if anyone
builds from it again. It was not compiled or shipped in this round.

---

## 3. How each map was built

The compile unit for each map is **exactly** the unit its shipped build used, taken from that
build's own write log, with only `src/hsc/*` changed. Nothing was rebuilt from stock: each map's
rebuild starts from a copy of the **shipped** `ready-to-install/<map>.FINAL.map`, so every tag-level
edit from earlier rounds (squad reparenting, shop tags, the Waterfront/Outpost choice-block unshare,
the Holdout retarget) is carried through untouched. Only the `scnr` script tables are rewritten.

Driver: `project/build/fix2/build_fix2.sh` (`dry` then `write`), which runs
`tools/compile/bin/Release/net8.0/hsc-compile.dll` with `--unit` and
`--xml tools/hsc/tables/reachmcc_u13.xml`. The driver's own build-match guard reported
`xml sha256 given=42beb6b51d5ee195 expected=42beb6b51d5ee195 / OK (byte-identical to the table this
build requires)` on every run.

| map | stock half of the unit | library | per-map file |
|---|---|---|---|
| `ff10_prototype` | `build/ovbh/unit/ff10_prototype.stock.hsc` | `fe_shop_lib.hsc` | `ff10_prototype.hsc` |
| `ff20_courtyard` | `build/stage3/unit/fe_culled_shims.hsc` + `…/ff20_courtyard.stock.hsc` | `fe_shop_ctgl.hsc` | `ff20_courtyard.hsc` |
| `ff30_waterfront` | `build/wo/fe_culled_shims.hsc` + `build/wo/ff30_waterfront/stock_unescaped.hsc` | `fe_reinforcements_wo.hsc` | `ff30_waterfront.hsc` |
| `ff50_park` | `build/ovbh/unit/ff50_park.stock.hsc` | `fe_shop_lib.hsc` | `ff50_park.hsc` |
| `ff60_airview` | `build/wo/fe_culled_shims.hsc` + `build/wo/ff60_airview/stock_unescaped.hsc` | `fe_reinforcements_wo.hsc` | `ff60_airview.hsc` |
| `ff60_icecave` | `build/stage3/unit/fe_culled_shims.hsc` + `…/ff60_icecave.stock.hsc` | `fe_shop_ctgl.hsc` | `ff60_icecave.hsc` |
| `ff70_holdout` | `build/holdout/unit/fe_culled_shims.hsc` + `…/stock_unescaped.hsc` | `fe_shop_ctgl.hsc` | `ff70_holdout.hsc` |

### Stock scripts hooked, per map

The same two on all seven, and nothing else: the stock global
**`b_survival_game_end_condition`** (written) and the stock scenario scripts
**`survival_spartans_increment_score`** and **`event_survival_spartans_win_normal`** (called).
`survival_end_game` is **not** called or woken by us — it is already awake and waiting on that
global, which is the whole point. Zero stock script bodies, declarations, globals or object names
were added, removed or changed on any map (§5).

---

## 4. Build results

Script and global counts are **identical** to the shipped builds on every map, and so is every lint
count, i.e. no new unimplemented-opcode finding was introduced. Expression counts grew by the edits
only.

| map | expressions (shipped → rebuilt) | scripts | globals | lint findings (shipped → rebuilt) | string bytes |
|---|---|---|---|---|---|
| `ff10_prototype` | 16639 → **16664** (+25) | 397 = 397 | 222 = 222 | 188 = 188 | 25013, unchanged |
| `ff20_courtyard` | 16220 → **16245** (+25) | 398 = 398 | 222 = 222 | 181 = 181 | 24706, unchanged |
| `ff30_waterfront` | 16728 → **16753** (+25) | 403 = 403 | 225 = 225 | 185 = 185 | 25365, unchanged |
| `ff50_park` | 17179 → **17204** (+25) | 415 = 415 | 222 = 222 | 180 = 180 | 26807, unchanged |
| `ff60_airview` | 16303 → **16328** (+25) | 386 = 386 | 217 = 217 | 168 = 168 | 24893, unchanged |
| `ff60_icecave` | 14865 → **14893** (+28) | 374 = 374 | 215 = 215 | 144 = 144 | 23216, unchanged |
| `ff70_holdout` | 17446 → **17471** (+25) | 418 = 418 | 233 = 233 | 192 = 192 | 26888, unchanged |

Glacier's +28 against everyone else's +25 is the three expressions the other six give back by
dropping `(object_destroy "dm_longsword_01")` from their strike; Glacier has no strike.

**Zero new script objects.** The compiler's own object resolution reports the same
`2 distinct script-object reference(s); 2 unresolved` on every map, before and after — both of them
the stock pseudo-objects `ai_current_actor` and `ai_current_squad`. No new object name, squad, squad
group or objective is referenced anywhere.

---

## 5. Verification

Every number below was produced by reading the **output**, not by trusting that the edit applied.

### 5.1 Publication gate — `build/audit/verify_final.py`, run on the installed files

Re-parse with the project reader (0 warnings), header checksum stored == computed (XOR of every
uint32 from `0xA000`), and a fail-closed Blamite `--load-only`.

```
ff10_prototype.FINAL.map    191205376 B  tags=14650  warnings=0  cksum=OK  blamite=OK
ff20_courtyard.FINAL.map    183738368 B  tags=13879  warnings=0  cksum=OK  blamite=OK
ff30_waterfront.FINAL.map   193069056 B  tags=14181  warnings=0  cksum=OK  blamite=OK
ff50_park.FINAL.map         172773376 B  tags=14034  warnings=0  cksum=OK  blamite=OK
ff60_airview.FINAL.map      173486080 B  tags=14547  warnings=0  cksum=OK  blamite=OK
ff60_icecave.FINAL.map      165429248 B  tags=13189  warnings=0  cksum=OK  blamite=OK
ff70_holdout.FINAL.map      154071040 B  tags=13291  warnings=0  cksum=OK  blamite=OK
ff_unearthed.marines6.map   912592896 B  tags=17983  warnings=0  cksum=OK  blamite=OK
ff_unearthed.tuned.map      912527360 B  tags=17983  warnings=0  cksum=OK  blamite=OK
VERDICT: ALL PASS
```

### 5.2 The mandated gate — `tools/map/reach_write.py --blamite-gate --verify-checksum`

Run separately on all seven. Every one:

```
blamite gate      PASS - Blamite loads this cache
stored checksum   0x…
computed checksum 0x…        (equal)
```

| map | stored == computed |
|---|---|
| `ff10_prototype` | `0x3C2DAB93` |
| `ff20_courtyard` | `0xC4E58796` |
| `ff30_waterfront` | `0xB4BE3391` |
| `ff50_park` | `0x18045AAA` |
| `ff60_airview` | `0x93CA880C` |
| `ff60_icecave` | `0xD90688BB` |
| `ff70_holdout` | `0xAB77644E` |

Note: `reach_write.py` must be run **without** `python3 -I`, or `import reach_cache` fails. Use
`PYTHONPATH=tools/map`.

### 5.3 Read the end-of-match path back out of the bytecode

`build/fix2/decomp_verify.sh` decompiles each built cache's own `scnr` with `reachmcc_u13.xml` and a
per-map stringID table and prints the touched scripts. Overlook, verbatim from
`build/fix2/decomp/ff10_prototype.decomp.hsc`:

```
(script static void fe_mission_won
  (if
    (and
      (not g_fe_won)
      (not b_survival_game_end_condition)
    )
    (begin
      (set g_fe_won true)
      (sleep 30)
      (ai_kill_no_statistics "gr_survival_all")
      (sleep 60)
      (survival_spartans_increment_score)
      (event_survival_spartans_win_normal)
      (submit_incident "survival_mm_game_complete")
      (set b_survival_game_end_condition true)
      (sleep 1800)
      (set g_fe_won false)
    )
  )
)
```

The same read was done on all seven; the Courtyard / Glacier / Holdout and Waterfront / Outpost
forms carry the `(object beacon)` / `(object kiosk)` parameter and the `fe_blip` / `fe_unblip` pair,
and are otherwise identical. `fe_near` reads back guarded on all seven, and the strike reads back
with no `object_destroy` on all six that have one.

Occurrence counts in each rebuilt cache's own decompile:

| map | `(game_won)` | `b_survival_…end_condition` | `event_…win_normal` | `submit_incident "…game_complete"` | `…increment_score` | `object_destroy "dm_longsword_01"` |
|---|---|---|---|---|---|---|
| `ff10_prototype` | 1 | 9 | 4 | 3 | 4 | 2 |
| `ff20_courtyard` | 1 | 9 | 4 | 3 | 4 | 1 |
| `ff30_waterfront` | 1 | 9 | 4 | 3 | 4 | 1 |
| `ff50_park` | 1 | 9 | 4 | 3 | 4 | 1 |
| `ff60_airview` | 1 | 9 | 4 | 3 | 4 | 1 |
| `ff60_icecave` | 1 | 9 | 4 | 3 | 4 | 0 |
| `ff70_holdout` | 1 | 9 | 4 | 3 | 4 | 1 |

Reading those columns: `(game_won)` = 1 is the dead stock campaign `end_mission` body and nothing
else — the preceding lines in every decompile are `(script static void end_mission`. The end-condition
global goes from 8 occurrences to 9 (declaration + 4 stock writes + 1 stock read in
`survival_mode_add_human_lives` + 1 stock `sleep_until` + **our write and our read**). The win event
and the score script go from 3 to 4 (declaration + 2 stock call sites + ours). The incident string
goes from 2 to 3. `object_destroy "dm_longsword_01"` drops to the stock sites only: 2 on Overlook
(`survival_resupply_pod_spawn` and the stock resupply event), 1 on the others, 0 on Glacier, which
never had the device.

### 5.4 Script-table diff: shipped cache vs rebuilt cache

`build/fix2/scriptdiff.sh` decompiles both caches and diffs the two script tables. The complete diff
for `ff10_prototype`, excluding the header comment line that carries the expression count:

```
 (script static boolean fe_near (unit who, object kiosk)
   (and
     (fe_valid who)
+    (>= (objects_distance_to_object who kiosk) 0)
     (< (objects_distance_to_object who kiosk) k_fe_kiosk_radius)
   )
 )
@@
   (sleep 90)
   (ai_kill_no_statistics "gr_survival_waves")
   (sleep 120)
-  (object_destroy "dm_longsword_01")
 )
 (script static void fe_mission_won
   (if
-    (not g_fe_won)
+    (and
+      (not g_fe_won)
+      (not b_survival_game_end_condition)
+    )
     (begin
       (set g_fe_won true)
       (sleep 30)
       (ai_kill_no_statistics "gr_survival_all")
       (sleep 60)
-      (game_won)
+      (survival_spartans_increment_score)
+      (event_survival_spartans_win_normal)
+      (submit_incident "survival_mm_game_complete")
+      (set b_survival_game_end_condition true)
+      (sleep 1800)
+      (set g_fe_won false)
     )
   )
 )
```

All seven diffs are this and nothing else (45-53 lines each, Glacier shorter by the strike hunk).
**Zero** stock scripts, stock globals, stock script bodies or script signatures changed on any map;
no script was added or removed; no parameter name or type changed anywhere. Per-map diffs are in
`build/fix2/decomp/<map>.scriptdiff.txt`.

### 5.5 Byte-level diff: shipped cache vs rebuilt cache

A naive byte diff proves nothing here and the first attempt at one was misleading: it reported 16.6
million differing runs. The reason is Blamite's `MetaAllocator`. It grows the tag-data area by
inserting a fresh page at the **front** of it — the tag section's virtual addresses do not change,
the header's `virtual_base_address` drops by the growth, and therefore every tag's **file offset**
moves up by exactly that growth. Compared at equal file offsets the whole ~128 MB area "differs"
while being the same bytes in a new place.

`build/fix2/structdiff.py` compares like with like. All seven:

* **header fields that differ:** `checksum`, `file_size`, `virtual_base_address`, `virtual_size`,
  the `tag` section size, the `locale` offset mask, and partition 0's address and size. Every one is
  a mechanical consequence of the growth — e.g. Overlook: `virtual_base_address`
  `0x1C7FF0000 → 0x1C7F80000` (−0x70000), `virtual_size` `0x8030000 → 0x80A0000` (+0x70000),
  partition 0 `0x1C7FF0000/0x80000 → 0x1C7F80000/0xF0000` (start −0x70000, size +0x70000, end
  unchanged), `locale` mask `0x83BD000 → 0x842D000` (+0x70000). No other header field differs.
* **tag table:** count unchanged, 0 tags added, 0 removed, **0 virtual addresses moved**, 0
  estimated sizes changed.
* **`0xA000` .. start of tag data:** byte-identical.
* **tag-data area, compared at the constant shift:** byte-identical once the `scnr` body and the old
  and new script / global / expression / string tables and per-script parameter blocks are excluded.
  Masked share: 0.36 % – 0.41 % of the area (460 656 – 533 568 bytes), all of it `scnr` script data.
* **the fresh page:** occupied by the new expression table; the remainder is **all zero**.
* **after the tag-data area:** byte-identical, i.e. moved, not rewritten.

| map | file growth | fresh page occupant | remainder | tail | verdict |
|---|---|---|---|---|---|
| `ff10_prototype` | +0x70000 | expr table `0x3249000..0x32AAA40` | 58816 B zero | identical | nothing unexplained |
| `ff20_courtyard` | +0x60000 | expr table `0x32DA000..0x33392F8` | 3336 B zero | identical | nothing unexplained |
| `ff30_waterfront` | +0x70000 | expr table `0x3971000..0x39D3298` | 56680 B zero | identical | nothing unexplained |
| `ff50_park` | +0x70000 | expr table `0x2926000..0x298ACE0` | 45856 B zero | identical | nothing unexplained |
| `ff60_airview` | +0x60000 | expr table `0x2163000..0x21C2AC0` + param blocks | 12 B zero | identical | nothing unexplained |
| `ff60_icecave` | +0x60000 | expr table `0x2C44000..0x2C9B438` | 35784 B zero | identical | nothing unexplained |
| `ff70_holdout` | +0x70000 | expr table `0x1FFF000..0x20655E8` | 39448 B zero | identical | nothing unexplained |

**One finding worth recording.** Before the parameter blocks were accounted for, 1822 bytes in a
`0x24`-strided pattern just past the script string table still differed — old `force_load`,
`load_squad`, `spawned_phantom`, `dropship`, `index` against new `player_num`, `string_hud`,
`button_press`, `string_start`, `reference`. `0x24` is `STRIDE_PARAM`: those are the per-script
**parameter records**, a child block of each script element, which Blamite allocates in its own
order when it rebuilds the table. The reordering is semantically inert and that is *proved*, not
assumed: `decompile.py` reads every parameter through its owning script's `param_count` / `param_addr`
and prints it in the declaration line, and §5.4 shows no declaration changed on any map. The
reordering is why a rebuilt cache can never be byte-identical to its predecessor even where the
script text is identical.

### 5.6 Installed artefacts

`ready-to-install/<map>.FINAL.map` and
`ready-to-install/MOD-PACKAGE/Firefight-Reinforcements/maps/<map>.map` are byte-identical to the
build output (MD5 three-way match). The pre-fix files are kept at
`project/build/fix2/preinstall-backup/<map>.FINAL.preG1fix.map`.

| map | MD5 before (audit 25) | MD5 after |
|---|---|---|
| `ff10_prototype` | `87a3c0fbe3aa55373b5c355b84759a5d` | `d24bec31f11b9cffdb3fd80371e36548` |
| `ff20_courtyard` | `44875c0e0e28fdcad5a14a0063c03c9a` | `78e4b73926503b88a70b0b7517850ee4` |
| `ff30_waterfront` | `99cc8d6e6f7efe2f326803bbff6d1715` | `f6a66e7941d6b121a157385267f31872` — superseded, see §7.1 (this round's own build was `d3bdf308e69f958aa6f5e905fbe8323d`) |
| `ff50_park` | `ccbc36829a0cd077c11b58c7b26d055d` | `2598b14ed411f5c7e465aa380ba84549` |
| `ff60_airview` | `b38aadf424b620a96198044d57e3c470` | `1d39b192283b0382f262eb200759a8af` — superseded, see §7.1 (this round's own build was `67279959eb63c1a08217eb849627c625`) |
| `ff60_icecave` | `78f495044332e490b7cc846eef8aad95` | `a69e3c41247d6c0f348aaf50255fda15` |
| `ff70_holdout` | `455f1d0c2bb8b963fafab4d69550d470` | `f440cd3990112d70f034c92cd4b28c04` |
| `ff_unearthed.marines6` | `94851196…` | **unchanged** |
| `ff_unearthed.tuned` | `5e9e9479…` | **unchanged** |

No installer file carries a hard-coded hash of the seven maps: `MOD-PACKAGE/install.ps1` computes
SHA-256 at runtime, and the only hashes in `READ-ME-FIRST.txt` are the two Unearthed builds', which
did not change.

---

## 6. Per-map summary

| map | G1 fixed | verified in own bytecode | Longsword | `-1` guard | notes |
|---|---|---|---|---|---|
| Overlook `ff10_prototype` | yes | yes | destroy removed (`fe_deliver_strike`) | yes | author pattern reproduced exactly |
| Courtyard `ff20_courtyard` | yes | yes | destroy removed (`fe_ct_deliver_strike`) | yes | 2 of 6 anchors are doors — the guard matters most here and on Holdout |
| Waterfront `ff30_waterfront` | yes | yes | destroy removed (`fe_deliver_strike`) | yes | shipped cache is the ally-slot workstream's, which carries all three of these fixes too — verified from the installed bytes, §7.1 |
| Beachhead `ff50_park` | yes | yes | destroy removed (`fe_deliver_strike`) | yes | — |
| Outpost `ff60_airview` | yes | yes | destroy removed (`fe_deliver_strike`) | yes | shipped cache is the ally-slot workstream's, which carries all three of these fixes too — verified from the installed bytes, §7.1 |
| Glacier `ff60_icecave` | yes | yes | n/a — no strike, 0 references to the device | yes | — |
| Holdout `ff70_holdout` | yes | yes | destroy removed (`fe_ho_deliver_strike`) | yes | 3 of 6 anchors are doors |

Nothing in this round could not be fixed. No map's end-condition machinery differed enough to force
an approximation: `b_survival_game_end_condition`, `survival_end_game`,
`survival_spartans_increment_score` and `event_survival_spartans_win_normal` are present and
identically shaped in all seven caches.

---

## 7. Open items

1. **Waterfront and Outpost: reconciled, nothing lost. CLOSED.** While this round was compiling, the
   ally-slot workstream rewrote `fe_has_room`, `fe_spartan_slot_free`, `fe_has_spartan_room` and
   `fe_deliver_squad` and added `fe_squad_empty` / `fe_trooper_slot_free` in the shared
   `src/hsc/fe_reinforcements_wo.hsc` (mtime 15:47:57, after this round's 15:45 compile of those two
   maps). This round installed its own builds at 15:58; that workstream then installed its builds at
   15:59:02 over the same two names.

   Those installed files were decompiled here afterwards, from the installed bytes, to find out what
   actually survived. **They carry all three of this round's fixes and the ally-slot fix as well:**
   `fe_mission_won` has the four-call end path, the `(not b_survival_game_end_condition)` entry test
   and the `(sleep 1800)` / `(set g_fe_won false)` latch release; `fe_near` has the `(>= … 0)` guard;
   `fe_deliver_strike` has no `object_destroy`; and `fe_has_room` is
   `(and (>= (fe_slots_free) k_fe_squad_size) (fe_trooper_slot_free))` with `fe_deliver_squad` now a
   `cond` over `fe_squad_empty` with a `(true …)` refusal branch instead of the `g_fe_rotor` cycle
   (`g_fe_rotor` down to 2 textual occurrences = declaration + the startup `set`, i.e. dead). The
   occurrence counts in both are identical to the five maps in §5.3. Both pass §5.1 unchanged
   (`warnings=0 cksum=OK blamite=OK`). The superseding builds are the ones to keep.

   This round's own two caches are retained at `project/build/fix2/out/ff30_waterfront.FINAL.map`
   and `…/ff60_airview.FINAL.map` as a fallback that has G1 but not the ally-slot fix. Rule for any
   future rebuild of these two: build from `src/hsc` as it is **now**, which carries both sets of
   edits. Anything built from `fe_reinforcements_wo.hsc` as it was before 15:42 would silently drop
   G1 — do not ship such a build.
2. **`~/Desktop/Halo-Firefight-INSTALL.zip` is stale.** It was packed at 14:53 from the pre-fix maps.
   `ready-to-install/MOD-PACKAGE/` is current; the zip needs re-packing before it goes to the PC.
3. **Nothing here has run in retail MCC.** Every claim in §5 is static: the compiler, Blamite as the
   reference cache reader, the project's own reader and a decompile of the output. The end path is
   now the one Bungie's own code and the author's playtested map both use, which is the strongest
   available evidence short of running it, and it is still not a playtest.
4. Untouched audit-25 items, by design: the dead `fe_retire_allies` / `g_fe_open` / `fe_gate_round` /
   `g_fe_buys` reads, the dead price globals, the `fe_report` stub, the comment in `fe_shop_lib.hsc`
   §5 about `objects_distance_to_object` argument order (now superseded by the new comment above
   `fe_near`), Courtyard's and Glacier's isolated spawns, and the six-dormant-thread load
   characteristic.

## 8. Artefacts

```
project/build/fix2/build_fix2.sh                 the build driver (dry | write)
project/build/fix2/decomp_verify.sh              decompile a built cache and print the touched scripts
project/build/fix2/scriptdiff.sh                 decompile shipped + rebuilt and diff the script tables
project/build/fix2/structdiff.py                 shift-aware structural + byte diff of two caches
project/build/fix2/logs/<map>.dry.log             dry-run compile report
project/build/fix2/logs/<map>.write.log           write compile report
project/build/fix2/out/<map>.FINAL.map            build output (== installed, by MD5)
project/build/fix2/out/<map>.FINAL.map.bak        the pre-write copy Blamite takes
project/build/fix2/preinstall-backup/             the pre-fix shipped maps
project/build/fix2/decomp/<map>.decomp.hsc        rebuilt cache, decompiled
project/build/fix2/decomp/<map>.SHIPPED.decomp.hsc  shipped cache, decompiled
project/build/fix2/decomp/<map>.scriptdiff.txt    the two, diffed
project/build/fix2/decomp/<map>.verify.txt        the touched scripts, read back
project/build/fix2/decomp/unearthed.decompiled.hsc  the author's map, decompiled for this round
project/build/fix2/verify/<map>.structdiff.txt    structural + byte diff
```
