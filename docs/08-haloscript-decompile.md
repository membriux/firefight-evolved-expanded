# 08 — Can compiled HaloScript be recovered from a Reach `.map`?

Research date: 2026-11-21. Target: `cex_ff_halo.map` (Installation 04 Firefight) from Steam
Workshop item 3453792163, not yet on disk. Built against the format spec; validated only against
a synthetic fixture (see §6). Every structural claim carries a confidence marker.

---

## 0. The decisive answer

**YES. Reach HaloScript decompiles to near-source-quality s-expressions. Confidence: high (~90%).**

Reach scenario tags do not store script text (`ScnrScriptFile.Text` in Assembly returns `null` with
the comment "Not stored in scenario scripts :("). They store a **script-node expression tree** plus
a **byte-blob string table**. That tree is not an optimised bytecode — it is a direct serialisation
of the parsed s-expressions, one node per token, with the original *source line number* on every
node. Consequently a decompiler recovers substantially more than a C decompiler ever could.

| Thing | Recoverable? | Why |
|---|---|---|
| Function names | **Yes**, exactly | Node carries a 16-bit opcode into the engine's function table; the table's names are known (§4). |
| Call arguments and nesting | **Yes**, exactly | The tree *is* the nesting. No flattening, no register allocation. |
| Control flow (`if`, `cond`, `begin`, `and`/`or`, `sleep_until`) | **Yes** | These are ordinary nodes, not jumps. `cond` is lowered to nested line-0 `if` nodes and is re-foldable (confidence: medium-high — Assembly does exactly this and it is the one place its decompiler has heuristics). |
| Literals (numbers, booleans, reals, enums like `player0`/`human`) | **Yes**, exactly | Stored as a 4-byte value plus a value-type opcode; enum names come from the engine type table. |
| Quoted scenario references (squad names, trigger volumes, cutscene flags, `string_id`s) | **Yes**, as text | Stored as offsets into the script string table, which keeps the original spelling. |
| **Global variable names** | **Yes**, exactly | `script global element` stores a 0x20-byte ASCIIZ name in the tag. |
| **Script parameter names** | **Yes**, exactly | `script parameter element` stores a 0x20-byte ASCIIZ name. |
| **Script names** | Yes, but indirectly | In Reach the `script element` stores a *stringID*, not text (§2). Resolving it needs the map's global stringID table. Called scripts are also named in the string table at the call site, so most names appear twice. |
| Comments | **No** | Discarded by the compiler. Irrecoverable. |
| Original whitespace / line breaks / file split | **No** — but line numbers survive | Every node has `source line`; the per-file split (`global_firefight.hsc` vs `ff20_courtyard.hsc`) is lost because all scripts land in one scenario tag. |
| Dead/stripped code | **No** | Compiler-removed branches are gone; some scripts are emitted with root index `-1` when stripped on error. |
| Author's `(set ...)` of a global vs. a compiler temp | Mostly yes | Compiler-generated `begin` wrappers and branch scripts are marked `source line == 0` / named `a_to_b`, so they can be filtered out. |

**Net: the author's actual implementation is recoverable as working, readable, re-compilable
HaloScript, minus comments and file organisation.** That is good enough to answer every open
question in `src/hsc/`.

### The one thing that can silently ruin it

**Opcodes shift between MCC builds.** Comparing Assembly's own tables for Reach MCC, 1,566 of 1,882
opcodes carry a *different function name* in `ReachMCC_U0_Scripting.xml` than in
`ReachMCC_U13_Scripting.xml`. Measured directly:

| Function | U0 / U11 / U12 opcode | U13 opcode |
|---|---|---|
| `campaign_metagame_award_points` | `0x24E` | `0x24C` |
| `ai_place` (1 arg) | `0x1AA` | `0x1A8` |

Using the wrong table does not fail loudly — it produces a *confident, plausible, completely wrong*
decompilation. Demonstrated with our own fixture: the correct table yields

```
(campaign_metagame_award_points player0 -1500)
```

and the U0 table yields, from the identical bytes,

```
(ai_play_line_on_point_set player0 -1500)
```

**So: read the map header's build string first and pick the matching table.** Build string →
table mapping (from Assembly `Formats/Engines.xml`, confidence: high):

| Build string | Engine | Scripting table | scnr layout |
|---|---|---|---|
| `Oct 24 2019 15:56:32` … `Oct 12 2022 01:55:01` | MCC launch … Update 12 | `ReachMCC_U0`/`U11`/`U12` | `reachmcc` |
| `Jun 21 2023 15:35:31` and later | Update 13+ | `ReachMCC_U13` | `reachmcc_u13` (header offsets shifted by −0x20) |
| `Jun 24 2019 00:36:03` | MCC Flight 1 | `ReachMCC_U0` | `reachmcc` (expand magic `0x10000000`) |
| 360 retail | Reach | `Reach_Scripting` | `reach360`, big-endian |

Secondary safety net: `decompile.py --auto-table` ranks candidate tables by how well each call's
*actual* argument count matches the table's declared arity. Reach gives every overload its own
opcode (`ai_place`/1 = `0x1A7`, `ai_place`/2 = `0x1A8`), so arity is a strong fingerprint. On the
fixture the right table scored 100%, the wrong ones 25%.

---

## 1. Existing tools — read this before using ours

**Assembly / Blamite (github.com/XboxChaos/Assembly, GPLv3) already solves this properly.** It has
a complete script viewer, decompiler *and* recompiler for Halo 2/3/ODST/Reach/Halo 4 cache files:

- `src/Blamite/Blam/Scripting/ScnrScriptFile.cs` — reads the scnr script tables
- `src/Blamite/Blam/Scripting/BlamScriptDecompiler.cs` — the tree walk and printer
- `src/Blamite/Blam/Scripting/Compiler/ScriptCompiler.cs` — compiles edited `.hsc` back in
- `src/Blamite/Formats/ReachMCC/ReachMCC_U*_Scripting.xml` — the opcode tables (by Lord Zedd)

**If you have a Windows box, use Assembly, not our tool.** Open the map, open the `scnr` tag,
Script Editor → decompile. It resolves stringIDs from the cache automatically (so script
declaration names come out right), it handles every MCC build, it is maintained, and it can put
edits back. Our tool cannot recompile and will never be as complete.

The reason `tools/hsc/decompile.py` exists: **Assembly is Windows-only** —
`src/Assembly/Assembly.csproj` is `WinExe`, WPF, `TargetFrameworkVersion v4.8`. It does not run on
this macOS machine, with or without Mono. Options, in order of preference:

1. Run Assembly in a Windows VM / on a Windows machine. Best outcome.
2. Use `tools/hsc/decompile.py` (below). Good enough to read the author's logic.
3. TagTool (github.com/TheGuardians/TagTool) has `Scripting/ScriptDecompiler.cs` and runs on
   .NET Core, but ships script definitions for **Halo 3 / ODST / Halo Online only** —
   `TagTool/Scripting/Definitions/` has no Reach table. Not usable here without porting one.

Searched and found nothing else: no standalone Reach `.hsc` decompiler exists on GitHub (queries
for *halo hsc decompiler*, *blam script decompiler*, *haloscript* return only source-script
collections and a VS Code syntax plugin). Reclaimer (Gravemind2401) is a model/asset extractor, not
a script tool. So: Assembly, TagTool-for-H3, or ours.

---

## 2. The script data structures in `scnr`

All offsets below are from Assembly's layout definitions
(`src/Blamite/Formats/<engine>/Layouts*/<engine>_Layouts_Scenario.xml`). Confidence: **high** —
these are the definitions a working, widely used editor/recompiler ships with. They are not
independently verified by us against a real map yet.

### 2.1 Header fields inside the scnr tag

Five tag blocks, each a (count, address) pair. Reach-family offsets:

| Field | Reach 360 | MCC launch–U12 | MCC U13+ |
|---|---|---|---|
| script string table size | 0x430 | 0x43C | 0x41C |
| script string table address | 0x43C | 0x448 | 0x428 |
| number of scripts | 0x444 | 0x450 | 0x430 |
| script table address | 0x448 | 0x454 | 0x434 |
| number of script globals | 0x450 | 0x45C | 0x43C |
| script global table address | 0x454 | 0x460 | 0x440 |
| number of script expressions | 0x518 | 0x524 | 0x504 |
| script expression table address | 0x51C | 0x528 | 0x508 |
| number of script tag references | 0x45C | 0x468 | 0x448 |
| script tag refs table address | 0x460 | 0x46C | 0x44C |

Addresses are **cache virtual addresses**, and on MCC they are *compressed*:
`real = (stored << 2) + expandMagic`, with `expandMagic` = `0x50000000` for Reach MCC retail and
`0x10000000` for Flight 1 (`ThirdGenPointerExpander`, `Formats/Engines.xml`). Confidence: high.

> **Requirement for the `tools/map/` parser:** these tables live in the shared **meta / tag-data
> area**, not necessarily inside the scnr tag's own byte range. A scnr-only dump will probably not
> contain the expression table. Dump the whole meta area (or whole map) and record: the meta area's
> base virtual address and file offset, the scnr tag's virtual address, the build string, and the
> **global stringID table** (needed for script declaration names).

### 2.2 `script expression element` — 0x18 bytes, the node table

| Offset | Type | Field |
|---|---|---|
| 0x0 | u16 | datum index salt |
| 0x2 | u16 | **opcode** |
| 0x4 | i16 | value type (return type) |
| 0x6 | i16 | **expression type** |
| 0x8 | u32 | next expression (datum index; `0xFFFFFFFF` = end) |
| 0xC | u32 | string table offset |
| 0x10 | u32 | **value** (4 raw bytes) |
| 0x14 | i16 | **source line** |
| 0x16 | u16 | padding |

A **datum index** is `(salt << 16) | index`; only the low 16 bits index the table. `0xFFFFFFFF` is
null. Siblings are a singly linked list through `next`; parents point at their first child through
`value`. So the whole program is one flat array traversed as a tree.

`expression type` (low byte; Halo 4 ORs in a high nibble):

| Value | Meaning |
|---|---|
| 8 | **group** — a call. `value` = datum of the first child. Child 0 is the callee's `function_name` node; children 1..n are the arguments. |
| 9 | **expression** — a literal. If `value_type` is `function_name` (type opcode 0x02) this node only names its parent and renders as nothing. |
| 10 | **script reference** — a call to a script in this map. Name comes from the child `function_name` node's string. |
| 13 | **globals reference** — reads a global; name comes from the node's string. |
| 29 | **parameter reference** — reads a script parameter; name comes from the node's string. |

Two compiler artefacts, both keyed on `source line == 0`:
- a line-0 `if` group is a **`cond` clause**, to be re-folded into `(cond (t body) ...)`;
- any other line-0 group is a **compiler-inserted `begin`**, to be spliced in without parentheses.

Also, scripts named `a_to_b` where both `a` and `b` are real scripts are compiler-generated branch
stubs and should be hidden. (All of this mirrors Assembly; confidence: medium-high.)

### 2.3 `script element` — 0x18 bytes, the script entry table

| Offset | Type | Field |
|---|---|---|
| 0x0 | u32 | name **stringID** (Reach) / 0x20-byte ASCIIZ name (Halo 3) |
| 0x4 | i16 | execution type |
| 0x6 | i16 | return type (value-type opcode) |
| 0x8 | u32 | first/root expression (datum index) |
| 0xC | i32 | number of parameters |
| 0x10 | u32 | address of parameter list |
| 0x14 | u32 | unknown |

Execution types (`<scriptTypes>`, confidence: high):
`0 = startup`, `1 = dormant`, `2 = continuous`, `3 = static`, `4 = command_script`, `5 = stub`.

`script parameter element` — 0x24 bytes: ASCIIZ name at 0x0 (0x20 bytes), i16 type at 0x20.
Parameter blocks are shared/deduplicated between identical signatures.

### 2.4 `script global element` — 0x28 bytes, global declarations

| Offset | Type | Field |
|---|---|---|
| 0x0 | char[0x20] | name (ASCIIZ) — **the author's own identifier, verbatim** |
| 0x20 | i16 | type (value-type opcode) |
| 0x22 | u16 | unknown |
| 0x24 | u32 | initialiser expression (datum index) |

Engine-provided globals (1,716 of them in U13, e.g. `enable_melee_action`) are *not* in this block;
a `globals reference` to one carries the engine global's opcode and, usually, its name in the string
table.

### 2.5 Script string table

A flat blob of NUL-terminated Windows-1252 strings; `string table offset` on a node indexes into it.
Holds squad names, trigger volume names, `string_id` spellings, callee names and global names at
reference sites. Only valid when `offset < string table size`.

### 2.6 Value types

89 entries in U13 (`<valueTypes>`), each with an opcode, a byte size (0/1/2/4) and a `quoted` flag.
Notables: `0x02 function_name`, `0x03 passthrough`, `0x04 void`, `0x05 boolean(1)`, `0x06 real(4)`,
`0x07 short(2)`, `0x08 long(4)`, `0x09 string(4, quoted)`, `0x0B string_id(4, quoted)`,
`0x0A script(2)`, `0x13 ai(4, quoted)`, `0x1B player(4, enum player0..)`. Enumerated types carry
their member names, which is how `player0` / `human` / `red` come back as words rather than numbers.

Two decoding subtleties (both from Assembly, confidence: high):
- If a literal node's `opcode != 0xFFFF`, the opcode is the **actual** value type (a compiler cast);
  use it in preference to `value_type`.
- On big-endian (360) maps the value is left-aligned in the 4 bytes: shift right by `32 - size*8`.
  On little-endian (MCC) take the low bytes.

---

## 3. The tool

`tools/hsc/decompile.py` — a clean-room Python implementation of the walk above. No Assembly code
is copied; the opcode tables are **read at runtime** from Assembly's XML and are deliberately not
committed (GPLv3 — see `tools/hsc/tables/.gitignore`).

```bash
# one-time: pull the opcode tables (GPLv3 data, gitignored)
python3 tools/hsc/decompile.py --fetch-tables tools/hsc/tables

# the real invocation, once tools/map/ has dumped the meta area
python3 tools/hsc/decompile.py extracted/cex_ff_halo.meta \
    --table tools/hsc/tables/reachmcc_u13.xml \
    --base-va 0x50000000 --scnr-va <scnr tag VA> \
    --stringids extracted/cex_ff_halo.stringids.json \
    --out research/_raw/hsc/cex_ff_halo.decompiled.hsc --report
```

Other modes:

| Flag | Purpose |
|---|---|
| `--probe` | try every known scnr layout and report which ones give a self-consistent header. Use first, when the addressing is unknown. |
| `--auto-table` (with several `--table`) | rank tables by call-arity agreement; warns loudly below 95%. |
| `--report` | call-site report grouped by the §5 watchlist (score read/write, `ai_place`, allegiance, input, HUD, win/lose). |
| `--json` | machine-readable dump of scripts/globals/calls, for diffing against our `src/hsc/`. |
| `--variant`, `--expand-magic`, `--no-expand`, `--big-endian` | override autodetection; `--no-expand --big-endian` for 360 maps. |
| `--annotate` | append expression indices as comments, for cross-checking against Assembly. |
| `--selftest` | emitter + struct round-trip test, no map needed. |

Degradation rules — the tool **never guesses and never goes silent**:

```
(<!UNKNOWN-FUNCTION opcode=0x1A8!> player0 -1500)
<!UNKNOWN-TYPE value_type=0x5C opcode=0xFFFF raw=0x00000003!>
<!UNKNOWN-EXPR-TYPE 0x11 idx=8831 opcode=0x0 value=0x00000000!>
<!SID:0x00001234!>            ; script name whose stringID we could not resolve
<!MISSING-STRING offset=0x3F1 type=ai!>
<!ENUM-OUT-OF-RANGE type=team index=19!>
; <!COND-SHAPE-UNEXPECTED at expr 912 - emitted as a raw if group!>
```

Unknown opcodes and expression types are also counted and summarised on stderr at the end.

---

## 4. Where the opcode table comes from

Not invented. Two independent sources that agree:

1. **`research/_raw/hsc/hsdoc_hr.txt`** — the engine's own `hs_doc` dump (via `Sigmmma/c20`),
   9,054 lines of `(<returntype> name <args>)` plus one-line descriptions. It is emitted in the
   engine's function-table order (it starts `begin, begin_random, begin_count, begin_random_count,
   if, cond, set, and, or, +, -, *, /, %, min, max, =, !=, >, <` — the classic Blam table order),
   but it carries **no explicit opcode numbers** and contains no-longer-present entries, so it
   cannot be used as an index→opcode table directly. It *is* ground truth for **names, arities,
   return types and semantics**.
2. **Assembly's `ReachMCC_U*_Scripting.xml` / `Reach_Scripting.xml`** — explicit
   `opcode → name/returnType/args` for 1,882 functions, 89 value types, 6 script types and 1,716
   engine globals, per MCC build. This is what the tool loads.

Cross-validation performed: every function our fixture uses
(`campaign_metagame_get_player_score`, `campaign_metagame_award_points`, `ai_place`,
`chud_post_message`, `>=`, `begin`, `if`) appears in `hsdoc_hr.txt` with the same return type and
arity as the U13 XML, and the first two appear in Bungie's own shipped source
(`research/_raw/hsc/global_firefight.hsc` L1079-1084 and L3382-3391). Spot-checked the signature
groups in §5 the same way. Confidence that the U13 table is correct *for a U13-era map*: high.

Validation plan for the real map (do this before trusting any output): decompile and grep for calls
that must appear in any Firefight scenario — `survival_mode_begin_new_wave`, `ai_place_wave`,
`survival_mode_get_wave_squad`, `chud_bonus_round_show_timer`. If those names come out of the
author's map, the table is right. If instead you get unrelated names in those positions, the table
is wrong — try another `--table`.

---

## 5. Checklist: what to extract from the real map, in order

Run `--report` first; it buckets every call site by these groups. Then read the named scripts.

1. **The score deduct — top priority.** We could not find a "subtract score" function and fell back
   to a soft ledger. The table says the author almost certainly did *not* need one:
   `campaign_metagame_award_points <player> <long>` (U13 `0x24C`, hsdoc L1772 "award bonus metagame
   points to a player") takes a **signed long**, and Bungie calls it with positive constants
   (`(campaign_metagame_award_points (player0) 500)`, `global_firefight.hsc` L3382). **Hypothesis
   (confidence: medium-high, unproven): the author passes a negative value.** Look for
   `campaign_metagame_award_points` with a negative literal. If it is absent, look instead at
   `survival_mode_lives_set`, `survival_mode_bonus_multiplier_set`, or a purely script-side ledger
   global like ours. Either answer settles the question.
2. **The score read.** Expect `campaign_metagame_get_player_score` per player (Bungie sums players
   0–5 in `survival_total_score`). Check whether the author sums `player_human N` or
   `human_player_in_game_get N`, and whether purchases are charged to one player or the team.
3. **The purchase input mechanism.** Grep the report's "player input" bucket:
   `player_action_test_action` (0x375), `_accept` (0x376), `_cancel` (0x377), `_melee` (0x374),
   `_vision_trigger` (0x36C), `_lookstick_forward/backward` (0x3A9/0x3AA), and
   `player_action_test_reset`. Alternatives to rule in/out: a **trigger volume**
   (`volume_test_players`) acting as a shop pad, a **device/terminal** (`device_*`,
   `object_set_*`), or a dialog built with `cui_*`. Record the exact poll loop (`sleep`/`sleep_until`
   period) and the debounce.
4. **`ai_place` calls and their squad references.** Which overload (`0x1A7` 1-arg vs `0x1A8`
   2-arg), which squad/squad-group strings (quoted, so they come out verbatim), whether limbo is
   used (`ai_place_in_limbo` + `ai_exit_limbo`), and whether squads are per-purchase or recycled.
   These strings are the names the author added to the scenario tag — they tell us exactly what to
   author in Sapien.
5. **Allegiance / team setup.** `ai_allegiance <team> <team>` (0x1CD), `ai_allegiance_remove`
   (0x1CE), `ai_set_team <ai> <team>` (0x1E4), `object_set_allegiance <object> <team>` (0x06E),
   `mp_ai_allegiance`/`mp_allegiance` (0x61D/0x61E). Note *when* they run — startup script vs after
   each place — and whether anything is done so bought Marines do not count toward wave-clear.
6. **Wave-accounting interaction.** Does the author's squad group sit outside
   `gr_survival_all` / `gr_survival_remaining`? Look at `ai_living_count`,
   `survival_mode_end_wave`, `ai_survival_cleanup` (0x6B5) around the purchased squads. This is the
   thing most likely to break a naive implementation, and the real map is the proof.
7. **HUD / notification.** `chud_post_message <player> <string_id>` (0x514),
   `chud_post_medal` (0x515), `chud_show_screen_training`/`hud_set_training_text` (0x4E2),
   `objectives_*` (0x57F-0x58F), `submit_incident*` (0x6E8-0x6EF), `print`. Capture the actual
   `string_id`s — they tell us which strings need adding to the map's unicode tables, which is a
   real build-pipeline cost.
8. **Win / lose conditions.** `game_won` (0x442), `game_lost <boolean>` (0x443), plus
   `survival_mode_end_set`/`end_wave`/`begin_new_set`, `survival_mode_sudden_death`, and the
   purchase that ends the round if there is one.
9. **Cooldowns, limits and economics.** Every `(global long ...)` / `(global short ...)` comes out
   with the author's own names and initial values — the full price list, actor caps and cooldowns
   for free. Diff them against our guesses in `src/hsc/fe_reinforcements.hsc` L50-106.
10. **Everything else the mod advertises** (auto turret, Falcon gunner, Scorpion, MAC strike,
    Sentinel hack) — the same scripts are in there. Harvest them while you are in the file.

---

## 6. What this changes about our inferred implementation (`src/hsc/`)

Our version is a defensible reconstruction, but it guesses in six places the real scripts would
settle outright:

| Our choice (`src/hsc/`) | The question the real map answers |
|---|---|
| Soft ledger: `g_fe_spent` global subtracted from the gross score; `k_fe_hard_deduct` off by default (`fe_reinforcements.hsc` L99-157) | Does the author actually deduct with a negative `campaign_metagame_award_points`? If yes, delete the ledger — the HUD score then matches the spendable score, which is almost certainly what the user likes about the mod. **Highest-value question.** |
| Sum `campaign_metagame_get_player_score` over `human_player_in_game_get 0..5` (L123-130) | Per-player wallets or a shared team pot? Charged to the buyer or to player0? |
| `player_action_test_action` poll in a continuous script, with a 450-tick cooldown (`beachhead.hsc` L86-103) | What is the real input? Our own note admits no shipped Firefight script polls `player_action_test_*` and that the action key is also Reload. A trigger-volume shop pad or an accept-button menu would be a different (probably better) design. |
| `ai_set_team squad human` + relying on scenario-side `ai_allegiance` (L231-244) | Is runtime allegiance needed at all, or is it all baked into the scenario's squads? Our comment calls this "belt and braces" — i.e. we do not know. |
| Hard-coded prices, `k_fe_actor_limit 8`, `k_fe_squad_limit 2`, `k_fe_squad_lifetime 9000` (L50-81) | The author's real numbers, verbatim, from the globals block. Also whether squads expire on a timer at all. |
| `print` for feedback, `chud_track_object_with_priority` for waypoints (L337, L408-410) | What the player actually sees: `chud_post_message` with real `string_id`s, medals, or objectives text. Our note already flags `chud_track_object_with_priority` as unused by any shipped script. |

Also worth diffing: whether the author uses `ai_place_in_limbo` + `ai_exit_limbo` (cheaper, avoids
spawn pop-in) rather than our plain `ai_place`, and how they keep purchased allies out of the
wave-clear count.

---

## 7. Validation status — be honest about this

- `--selftest` passes: the tree walk, the printer and the struct packing round-trip through our own
  writer (`tools/hsc/make_fixture.py`), using **real U13 opcodes**. A hand-built fixture encoding
  a plausible purchase script decompiles back to exactly its source form, including `-1500` as a
  signed long and `"sq_fe_marines"` as a quoted `ai` reference.
- `--auto-table` discriminates correctly on that fixture (100% vs 25%).
- **Not validated against a real map.** Our reader has never seen a byte of real `scnr`. The layout
  offsets are Assembly's, and Assembly round-trips real maps, so the risk is in *our*
  transcription, not in the spec. First run against `cex_ff_halo.map` should be sanity-checked by
  confirming that known stock Firefight function names appear (§4).
- Known gaps, by design: no recompiler, no `hsdt`-style separate script-tag support (Halo 4), no
  Halo 4 high-nibble expression types beyond masking them off, `cond` re-folding is heuristic, and
  script declaration names need an external stringID table.
