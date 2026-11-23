# MegaloEdit + Megalo Toolchain for Halo: Reach Firefight (MCC)

Research doc. Date: 2026-11-20. Every syntax claim carries a citation. Where a
fact could not be verified, it is labelled **NOT VERIFIED** rather than guessed.

---

## 0. Read this first: the premise needs correcting

The brief asked for "the official toolchain for authoring Halo: Reach Firefight
game variants, well enough that we can write new gametype scripts from scratch."
Research says that goal, as stated, is not achievable, and the reason is
structural rather than a tooling gap. Three findings drive the whole plan:

**Finding 1 — A Halo: Reach Firefight game variant contains no script at all.**
Reach game variants carry an engine type: `none, forge, multiplayer, campaign,
firefight`. Only the `multiplayer` type holds Megalo bytecode. The Firefight
variant type is a flat settings struct: wave limit, lives, generator count,
scenario flags, player/wave traits, three custom skulls, three rounds, and a
bonus wave. It has no triggers, no Forge labels, and no map permissions.
Source: `GameVariantDataFirefight` in
[`game_variants/types/firefight.h`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/types/firefight.h),
versus `mapPermissions` / Forge labels / triggers in
[`types/multiplayer.h`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/types/multiplayer.h).
Confirmed independently by MegaloEdit's `engine_data category` enum, whose 31
legal values are all multiplayer categories (`ctf`, `slayer`, … `pre_game_warm_up`)
with no firefight or survival entry:
[enums/engine-categories.md](https://github.com/craftycodie/MegaloEvolved/blob/main/packages/docs/language/enums/engine-categories.md).

**Finding 2 — Megalo cannot spawn AI. There is no AI-squad action.** This was
checked two independent ways and both agree:

- ReachVariantEditor's reverse-engineered opcode table defines 93 base actions
  plus a handful of MCC backports, and 16 named conditions. None spawns,
  controls, or sets the allegiance of an AI actor. Full table:
  [`components/megalo/actions.cpp`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/components/megalo/actions.cpp)
  and
  [`conditions.cpp`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/components/megalo/conditions.cpp).
- MegaloEdit's own documented action set is 112 actions. A keyword sweep for
  `squad`, `ai_`, `character`, `allegiance`, `marine`, `odst`, `grunt`, `wave`
  across the entire language reference returns no AI action. Listing:
  [`packages/docs/language/actions/`](https://github.com/craftycodie/MegaloEvolved/tree/main/packages/docs/language/actions).

AI spawning in Reach is **HaloScript** (`.hsc`, compiled into the map's
scenario tag), not Megalo. See §5.

**Finding 3 — Firefight wave logic lives in the map, not the variant.** The
variant only picks *which squad type* each wave uses, from a fixed 32-entry
enum. The spawning itself is map-side. ReachVariantEditor, documenting observed
behaviour: "the squads will spawn in a map-specific manner (typically just
appearing out in the open, though Corvette spawns them behind locked doors
instead)" and "If a wave failed to spawn any enemies, whether because the
selected enemy squad type was None or because the selected enemy squad type is
**not supported on the current map**, then the wave will end after roughly seven
to nine seconds."
Source: [`docs/working - help docs/concepts/firefight.xml`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/docs/working%20-%20help%20docs/concepts/firefight.xml).

### What this means for the project

There are three distinct build paths. Pick deliberately; they have very
different cost and very different ceilings.

| Path | Tool | Can spawn AI? | Ceiling | Windows needed? |
|---|---|---|---|---|
| **A. Firefight variant** (settings only) | ReachVariantEditor (RVT), GUI | Only by choosing from the 32 stock squad types, on maps that support them | Retunes stock Firefight: waves, squads, skulls, traits, lives, score targets. No new logic. | No — RVT is Windows, but see §1 for the Wine note |
| **B. Multiplayer Megalo variant that imitates Firefight** | MegaloEdit (official) or RVT | **No.** Forge objects and player-controlled Elites only | Real scripting: score economy, purchase menus, HUD, waves-as-timers, Forge-label spawning of weapons/vehicles. This is how "Endure" works (§9) | Yes, to compile and to run |
| **C. Map mod: edit the scenario's HaloScript** | HREK (`tool`, Sapien, Guerilla) | **Yes** — `ai_place`, `ai_place_wave`, `ai_set_team`, `ai_allegiance` | Everything. New AI squads, Marines/ODSTs on the player's side, Firefight on non-Firefight maps | Yes, hard requirement |

"Firefight Evolved" / "Halo Reach: Evolved" — the reference mod in the brief —
is a 7.3 GB Steam Workshop item, i.e. it ships modified map files. That is
Path C, with a Path B gametype `.bin` alongside it. See §9.

---

## 1. Platform reality: macOS vs Windows

The user is on macOS. Every tool in this toolchain is Windows-only.

**Steam app 1695793, "Halo: Reach Mod Tools - MCC"**: `type: Tool`,
`oslist: windows`, `installdir: HREK`, parent app `976730` (MCC).
Source: Steam app metadata via <https://api.steamcmd.net/v1/info/1695793>.
MegaloEdit is launch option 3 of that app:
`"description": "Launch MegaloEdit", "executable": "MegaloEdit.exe"`.

Prerequisite, per c20: "you _do_ need to own Halo Reach on Steam"
(<https://c20.reclaimers.net/hr/hr-ek/>). HREK released September 2022.

### Step-by-step: what needs Windows

| Step | Needs Windows? | Notes |
|---|---|---|
| Write `.txt` Megalo source | **No** | Plain text. Any editor. This is the bulk of the authoring work. |
| Syntax-check / lint source | No | `@blamnetwork/megalo` (npm) parses Megalo on macOS. See §2.5. |
| Compile `.txt` → `.mglo` | **Yes** (official path) | `MegaloEdit.exe --cli --compile`. A cross-platform unofficial compiler exists; see §2.5. |
| Convert `.mglo` → `.bin` | **Yes** | `tool megalo-convert-variant-files`. `tool.exe` is HREK. |
| Edit a Firefight variant's settings | **Yes** | ReachVariantEditor is a Windows Qt app. |
| Edit a map's HaloScript (Path C) | **Yes** | Sapien / Guerilla / `tool`, all HREK, all Windows. |
| **Run and test in MCC** | **Yes** | MCC has no macOS build. Non-negotiable. |

**macOS verdict.** You can do all source authoring on the Mac. You cannot
compile officially, cannot touch maps, and cannot test. Options:

1. A Windows machine or VM (Parallels/UTM on Apple Silicon runs Windows on ARM;
   MCC under it is **NOT VERIFIED** and GPU passthrough is the likely blocker).
2. A cloud Windows box with a GPU for the compile-and-test loop.
3. Bootcamp is not available on Apple Silicon.

No report was found of MegaloEdit running under Wine, Proton, or CrossOver —
**NOT VERIFIED** either way. c20 documents Wine only for the much older HEK and
Sapien (<https://c20.reclaimers.net/general/mod-tools/>).

**Honest recommendation:** treat the Mac as the authoring and version-control
host, and budget a Windows box as a project dependency, not an optimisation.

---

## 2. MegaloEdit

### 2.1 Install

1. Own Halo: Reach on Steam (MCC, app `976730`).
2. In Steam, Library → the **Tools** section → "Halo: Reach Mod Tools - MCC"
   (app `1695793`). Install.
3. c20: "Once the tools are done downloading you can find them in your library
   in the 'tools' section", then "Manage > Browse local files" and "Run the
   `<game> (Extract).bat` file" (<https://c20.reclaimers.net/general/mod-tools/>).
4. MegaloEdit lands in the HREK root. Default:
   `C:\Program Files (x86)\Steam\steamapps\common\HREK\MegaloEdit.exe`.
   (Steam's `steamapps\common\<installdir>` convention with `installdir: HREK`;
   this exact default path is also what MegaloEvolved's test harness assumes —
   `packages/megalo/tests/integration/hrek-compare/helpers.ts`.)

MegaloEdit also ships with the H2A MP Mod Tools (app `1695790`, `H2AMPEK`) and
the Halo 4 Mod Tools (app `1695792`, `H4EK`). It is **not** in the H3 or ODST
tools. Same Steam metadata source.

### 2.2 File formats

| Thing | Extension | Notes |
|---|---|---|
| Script source | **`.txt`** | Not `.megalo`. "Megalo scripts are plain-text files (`.txt`)" — [syntax.md](https://github.com/craftycodie/MegaloEvolved/blob/main/packages/docs/language/syntax.md). Often UTF-16 LE with BOM in stock HREK sources. |
| Stock Bungie sources | `.txt` | `HREK\data\multiplayer\megalo\` — e.g. `3nvasion.txt`, `ctf.txt`, `slayer.txt`, `territories.txt`, `headhunter.txt`, `stockpile.txt`. These are the single best reference corpus. |
| Compiled variant, raw | **`.mglo`** | A raw variant bitstream, no BLF wrapper. RVT's file dialog calls it "Raw Compiled Megalo File (*.mglo)" (`editor_state.cpp`). Default output dir `HREK\maps\megalo`. |
| Loadable game variant | **`.bin`** | A BLF document. |

**`.bin` internal chunk order** (from RVT `game_variants/base.cpp`):
`_blf` (must be first) → optional `athr` → `chdr` → `mpvr` (or `gvar` for
matchmaking variants) → `_eof`.

The `*_gametype.bin` naming convention mentioned in the brief is **NOT
VERIFIED**; MCC appears to accept any `.bin` filename in the right folder.

### 2.3 Compile path

Two stages. Both Windows.

**Stage 1 — source to `.mglo`.** c20's HREK changelog (July 2023): "MegaloEdit …
Can now take command line args to compile a script or directory."
The invocation, as used by MegaloEvolved's parity test which shells out to the
real executable:

```bat
REM run with the working directory set to the HREK root
MegaloEdit.exe --cli --compile <source.txt> <output.mglo>
```

**Gotcha, and it matters for any build script:** "MegaloEdit exits 0 even when it
fails to compile." Judge success by whether the output file was written and its
mtime changed, never by exit code. Source: comment in MegaloEvolved's
`hrek-compare` integration test.

Whether `--compile-directory` or other flags exist is **NOT VERIFIED**.
The exact GUI menu item name for compiling is **NOT VERIFIED**. The GUI does
have input/output directory settings under **File → Settings**, and a Help menu
whose reference lists are loaded from `data/multiplayer/megalo/object_lists/`.

**Stage 2 — `.mglo` to `.bin`.** c20's HR `tool` page: "Converts mglo files
built with MegaloEdit and converts them to bin files that can be used in MCC."

```bat
tool megalo-convert-variant-files "maps\megalo" "maps\game_variants"
```

Source: <https://c20.reclaimers.net/hr/hr-ek/hr-tool/>.

### 2.4 Where the `.bin` must go

Three locations, different behaviours. All from RVT's
`native/src/ReachVariantTool/README.txt`.

```
# Appears as a BUILT-IN variant, available to everyone in the lobby
...\steamapps\common\Halo The Master Chief Collection\haloreach\game_variants\

# Matchmaking variants (gvar chunk)
...\steamapps\common\Halo The Master Chief Collection\haloreach\hopper_game_variants\

# User-saved variants ("My Variants")
%APPDATA%\..\LocalLow\MCC\LocalFiles\<YOUR_XUID_HERE>\HaloReach\GameType\
```

The Workshop author of Halo Reach: Evolved gives the same instruction for his
gametypes: "Place the bin files in `steamapps\common\Halo The Master Chief
Collection\haloreach\game_variants`". A commenter confirms a file placed there
shows up as "built-in".

**Critical iteration-loop gotcha**, from the same README: "MCC only checks what
game variants you have saved once, when you click through the title screen …
you'll have to fully close and restart MCC." Budget a full MCC restart per
test cycle.

MegaloEvolved writes a hot-reload file to
`%USERPROFILE%\AppData\LocalLow\MCC\Temporary\HaloReach\HotReload\.mglo`
(`packages/ide/src-tauri/src/lib.rs`). That MCC actually reads this path is
**NOT VERIFIED** independently.

### 2.5 Official documentation: there is none

This is a real finding, not a search failure.

- <https://halo.github.io/> → 404.
- c20 has no MegaloEdit page (`/hr/hr-ek/megaloedit/` → 404). It carries only
  changelog lines and the `tool` command.
- `blam-network.github.io/megalo/language/`, which c20 links, → 404.
- MegaloEvolved's own docs intro: "Little documentation has accompanied that
  tooling."
- A search for MegaloEdit tutorials returns nothing on-topic. Every Megalo
  tutorial that exists targets RVT, not MegaloEdit — e.g. COZI TIME, "Reach
  Variant Tool Megalo Tutorial" <https://www.youtube.com/watch?v=tDKyZFrURww>.

**The best available MegaloEdit language reference is therefore third-party:**
[`craftycodie/MegaloEvolved`](https://github.com/craftycodie/MegaloEvolved),
`packages/docs/language/` — 112 action pages, 22 element pages, 19 enum pages,
plus `compiler-settings.md` and `megalo-headaches.md` (known MegaloEdit bugs).
It was produced by reverse-engineering MegaloEdit and `ManagedMegalo.dll`, and
its examples are quoted from stock HREK sources. **No license is stated** on
that repo — check before vendoring any of it.

MegaloEvolved also ships a cross-platform Megalo parser/compiler
(`@blamnetwork/megalo`, npm) that runs on macOS, Linux, Windows and in a
browser, and emits the same `.mglo`. Useful for a Mac-side lint/CI step. Its
byte-for-byte parity with MegaloEdit is asserted by its own test suite but was
**not independently verified here**.

### 2.6 MegaloEdit vs ReachVariantEditor: two different languages

These compile to the same bytecode but the source languages are **not**
interchangeable. RVT's own docs say so plainly: "The RVT dialect of Megalo is
loosely inspired by Lua syntax … It is **not compatible** with the 'true'
Megalo language used in MegaloEdit."
([`docs/.../script/syntax.xml`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/docs/working%20-%20help%20docs/script/syntax.xml))

Same logic, both dialects:

```megalo
; MegaloEdit (official). Verb-first, statement-keyword prefixed, `end`-closed.
trigger player
	condition player_died current_player enemy
	temporary player killer none
	action player_death_get_killing_player current_player killer
	action set killer.score add 1
end
```

```lua
-- ReachVariantEditor (unofficial). Lua-flavoured, infix, `--` comments.
for each player do
	if current_player.team == team[0] then
		current_player.score += 1
	end
end
```

Pick one dialect and commit. **This document specifies MegaloEdit syntax**,
since the brief asked for the official tool. If the team would rather have
Lua-ish syntax, better docs and a GUI, RVT is the pragmatic alternative — but
its output is still a multiplayer variant, so Finding 2 applies identically.

---

## 3. The Megalo language as MegaloEdit accepts it

Unless noted, every claim in this section comes from MegaloEvolved's language
reference, which is quoted from stock HREK scripts:
<https://github.com/craftycodie/MegaloEvolved/tree/main/packages/docs/language>.

### 3.1 File structure

A source file is a top-to-bottom sequence of **elements**. No order is required,
but shipped scripts follow this convention ([syntax.md](https://github.com/craftycodie/MegaloEvolved/blob/main/packages/docs/language/syntax.md)):

1. `include` directives, optionally a `base` declaration
2. `string_table` / string includes
3. `engine_data`, `teams`, `map_permissions`
4. `map_object` labels
5. `game_options`, `constants`
6. `variables`
7. `hud_widgets`, loadouts, statistics
8. `trigger` blocks

Element model: **block elements** open with a keyword and close with `end`;
**field elements** are single indented lines inside a block; **leaf elements**
like `include` stand alone at top level. The legal children of a block are
always determined by its parent.

Lexical rules:

- Comments are `;` to end of line. Line comments only; there is no block comment.
- Indentation is tabs by convention and is **cosmetic** — structure comes from
  keywords and `end`, not whitespace.
- Identifiers: alphanumerics and underscores, must not start with a digit, and
  must be **unique across one shared namespace** spanning variables, constants,
  triggers, game options and other named elements.
- String escapes: `\n` `\r` `\t` `\"` `\\`. Any other `\x` passes the backslash
  through literally.

### 3.2 Declarations

```megalo
include "strings/slayer_strings.txt"       ; merge another source file
localized_include "strings/english/x.txt"  ; like include, but skippable if missing
base "ctf.mglo"                            ; inherit a COMPILED parent variant
```

`include` resolves each path once; a repeat include of the same path is skipped
(paths tracked case-insensitively). A missing plain `include` is a hard error; a
missing `localized_include` is only a warning in lenient mode, and MegaloEdit
always uses lenient mode. No shipped HREK script uses `localized_include` —
Bungie used wrapper files plus plain `include`.

`base` inherits a compiled variant rather than merging text. **`trigger`,
`map_object` and `hud_widgets` are full-script-only — they cannot be added in a
base-derived script.**

```megalo
engine_data
	name slayer_title              ; string_table symbol
	description slayer_description ; string_table symbol
	icon k_engine_icon_slayer
	category slayer                ; see the 31-value engine-categories enum
end
```

`category` is quirky: the parser looks up the **prefixed** symbol
(`engine_category_` + your token), then lowers the short name to an enum index.
Write `category slayer`, and define `engine_category_slayer "Slayer"` in the
string table.

### 3.3 Triggers

```
trigger <kind> [<name>]
	[interval <seconds>]
	[conditions, actions, temporaries]
end
```

`name` is optional and unique script-wide; omit it for an anonymous trigger.

**Trigger kinds** — the kind sets the implicit context variable and the cadence:

| Kind | Context var | Runs |
|---|---|---|
| `general` | — | once per tick, globally |
| `player` | `current_player` | once per player per tick |
| `random_player` | `current_player` | once per tick, one random player |
| `team` | `current_team` | once per team per tick |
| `object` | `current_object` | once per object per tick |
| `initialization` | — | once when the variant loads |
| `local_initialization` | — | once per machine at load |
| `host_migration` | — | after host migration |
| `double_migration` | — | after a double host migration |
| `object_death` | `current_object` | when a bound object is destroyed |
| `local` | — | local-only scope |
| `pregame` | — | during the lobby / pre-game phase |

**Object-filter triggers:** use a `map_object` label name as the kind, and the
trigger runs once per matching object with `current_object` bound:

```megalo
map_object invasion_respawn_phase_1
	label "inv_res_p1"
end

trigger invasion_respawn_phase_1
	action set_respawn_filter current_object no_one
	action object_set_invincibility current_object true
end
```

**`interval`** throttles a trigger: `interval 5` runs it once every 5 seconds
instead of every tick.

**Execution model.** Triggers run in source order, on the same tick. Within a
trigger, conditions and actions evaluate strictly top to bottom; a **false
condition halts the trigger**, skipping all remaining conditions *and* actions.
Actions may appear before conditions, and actions that already ran are not
undone. Inside an `action for_each` block a false condition instead **skips the
current iteration**, like `continue`.

On incident-driven logic: the brief asked about "incident-driven triggers."
There is **no incident trigger kind**. Incidents are *outbound* only — a script
*submits* an incident to make the engine play an announcement or award a medal,
via `submit_incident` / `submit_incident_with_custom_value`. Scripts react to
game events through conditions instead (`player_died`, `timer_expired`,
`object_in_area`, …) and through the `object_death` trigger kind. The incident
list is ~470 entries, 1-based, from
[`object_lists/incidents.txt`](https://github.com/Blam-Network/megalo/blob/main/src/object_lists/incidents.txt).

### 3.4 Conditions

```
condition [not] <name> [arg1] [arg2] ... [or]
```

- `not` negates.
- `or` suffixes a condition line to OR it with the next. `or` must be
  immediately followed by another `condition`; anything else is a compile error.
- Separate condition lines are an implicit **AND**.

Comparison via the `if` condition, with both spellings accepted:

| Operator | Alias |
|---|---|
| `equal_to` | `==` |
| `not equal_to` | `!=` |
| `less_than` | `<` |
| `greater_than` | `>` |
| `less_than_or_equal_to` | `<=` |
| `greater_than_or_equal_to` | `>=` |

```megalo
condition if score_to_win_round != 0
condition if current_player.is_leader equal_to true
condition not if current_player.score == 0

condition player_died current_player enemy      ; killer types: environment,
                                                ; suicide, enemy, betrayal,
                                                ; quit_game, any
condition timer_expired round_timer
condition object_in_area current_player current_object
condition object_out_of_bounds current_team.flag
condition team_is_active current_team
condition object_is_type current_object "area"
```

**Capacity:** at most **512 conditions** and **1024 actions** across the whole
script.

### 3.5 Variables and scopes

```megalo
variables global
	local player killing_player none
	local number special_death_type 0
end

variables player
	local number is_leader 0
	networked timer game_start_vo 5
	networked number heard_game_start 0
	networked object body none
end

variables team
	networked object goal none
	networked timer vehicle_refresh 30
end

variables object
	networked timer lifetime 1
end
```

Each entry is `<network-state> <type> <name> <initial>`; the **scope lives on
the `variables` line itself**.

| Axis | Values |
|---|---|
| Scope | `global`, `player`, `team`, `object` |
| Network state | `local`, `networked`, `networked_high` |
| Type | `number`, `timer`, `object`, `team`, `player` |

- `local` is **not** synchronised, and is **reset to its initial value at the
  start of every tick** to prevent misuse. This trips people up constantly.
- `networked` syncs, at a bandwidth cost. `networked_high` syncs with priority.
- **Timers are always networked; `local timer` is a compile-time error.**
- Megalo is type-safe; a type mismatch in an argument is a compile error.
- Access per-instance values with dot notation: `current_player.is_leader`,
  `current_team.goal`, `current_object.lifetime`.

Built-in members not declared in a `variables` block include `.score` (player,
number), `.team` (player/object, team), `.rating` (player, number), `.body`
(player, object), `.user_data` (object, number).

```megalo
constants
	number k_special_death_type_headshot 5
	number k_cross_map_distance 400
end
```

Constants are compile-time and consume no variable storage. Prefer them over
globals for magic numbers; variable slots are scarce and capped per Megalo
version.

**Temporaries** are declared inside an action scope (a trigger body, a
`for_each` block, or a `begin` block) and live only for that scope:

```megalo
trigger player
	condition player_died current_player enemy
	temporary player killer none
	action player_death_get_killing_player current_player killer
	action set killer.score add 1
end
```

`temporary` is **not allowed inside `pregame` triggers**. On MCC Reach,
temporaries may spill into unused global slots when overflow is enabled.

### 3.6 Iteration

```megalo
action for_each player
	condition if current_player.team equal_to attackers
	action set current_player.fireteam set_to 0
end
```

Targets: `player`, `team`, `object`, `general` (runs once, no iteration), or a
`<map_object label>` to iterate only matching objects. `for_each` nests:

```megalo
action for_each invasion_objective
	temporary object buy_zone current_object
	action for_each player
		condition object_in_area current_player current_object
		action set total_in_area add 1
	end
end
```

### 3.7 Timers

Declare as a `timer`-typed variable in any scope, then drive the rate:

```megalo
action timer_set_rate this_territory.capture_timer -1   ; count up
action timer_set_rate buy_zone_timer 1                  ; count down to zero
action timer_reset my_timer
condition timer_expired current_player.game_start_vo
```

`timer_set_rate`: `0` pauses, `-1` counts up, `1` counts down; larger magnitude
counts faster. Only these rates and their negatives are representable, and
anything else is rounded at compile time: `0, 0.1, 0.25, 0.5, 0.75, 1, 1.25,
1.5, 1.75, 2, 3, 4, 5, 10`.

### 3.8 String table and localisation

```megalo
string_table english
	slayer_title "Slayer"
	slayer_description "Score points by killing players on the opposing team."
end
```

- Languages accepted: `english`, `japanese`, `german`, `french`, `spanish`,
  `mexican_spanish`, `italian`, `korean`, `traditional_chinese`,
  `simplified_chinese`, `portuguese`, `polish`.
- Reference strings elsewhere **by bare symbol**, not by quoted text:
  `engine_data name slayer_title`, `action hud_post_message everyone none
  invasion_title_spartan`.
- Only symbols actually referenced are written into the compiled variant.
  Unreferenced symbols are dropped and do not count against limits.
- **Limits: 112 string entries, 19,456 bytes of string data** across all
  languages.
- A symbol may appear only once per `string_table` block, and redefinition
  across blocks for the same language is a compile error, not an override:
  `String table for language english already has a string for token foo defined`.
- Convention: a language-agnostic wrapper file that `include`s one file per
  language, each opening `string_table <language>`.

**Inline literals** are accepted by some operands
(`action hud_post_message everyone none "CTF"`). The compiler stuffs the text
into the variant's string table at compile time, so **inline literals cannot be
localised**. Fine for development; use symbols for anything shipping. Strict
compiler settings forbid literals where a symbol is expected.

**Format placeholders.** Dynamic-string operands accept `%n %p %t %o %s`, with
matching reference operands following the string:

```megalo
action player_set_objective current_player "+%n" score_to_win_round
```

### 3.9 HUD widgets

```megalo
hud_widgets
	proximity_warning high_center
	arming_warning    low_center
	game_state_widget top_left
	rating_widget     top_left
end
```

First token is a name you choose; second is an anchor position. Documented
positions: `top_left`, `top_right`, `top_center`, `bottom_center`, `high_left`,
`high_right`, `high_center`, `low_center`, `low_left`.

**Limit: 4 HUD widgets per script.** This is the single tightest constraint on
any purchase-menu design (§6).

Drive them at runtime with `hud_widget_set_text`, `hud_widget_set_value`,
`hud_widget_set_meter`, `hud_widget_set_icon`, `hud_widget_set_visibility`.

```megalo
action hud_widget_set_text must_be_home_widget hud_must_be_home
```

### 3.10 Forge labels and map objects

```megalo
map_object slayer_stuff
	label "slayer"
end

map_object health_packs
	type "health_station"
end

map_object flag_spawn_point
	label "ctf_flag_spawn"
	team each
end

map_object invasion_objective
	label "inv_objective"
	min 1
end

map_object phase_markers
	label "phase_marker"
	user_data 2
end
```

Every filter needs exactly one primary binding:

- **`label`** — matches any map object carrying that Forge label **string**
- **`type`** — matches an object type from the object lists

Optional narrowing criteria: `team` (a team designator — `none`, `defenders`,
`attackers`, `third_party`, …, `neutral` — or `each` for every team),
`user_data` (signed integer equality against the Forge user-data field), and
`min` (require at least N matches; default `0`).

Note `user_data` on a `map_object` is a **filter**, distinct from the runtime
`current_object.user_data` variable.

**Limit: 16 map object filters per script.**

This string-matching is exactly why variants are map-agnostic (§8).

---

## 4. The Firefight surface

### 4.1 Match structure

Reach Firefight nests four levels, and the vocabulary collides confusingly with
multiplayer's. All of this section is from RVT's
[`concepts/firefight.xml`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/docs/working%20-%20help%20docs/concepts/firefight.xml)
and the header comments in
[`components/firefight_round.h`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/components/firefight_round.h).

```
Turn  = arbitrary number of Sets   (multiplayer's "round" is Firefight's "turn")
Set   = 3 Rounds + 1 optional Bonus Wave
Round = 5 Waves  = 1 Initial + 3 Main + 1 Boss
Wave  = 6 squads of one squad type spawned at once
```

So one Round spawns 30 squads. The HUD reads:

```
 ♀│● ● ○  01     <- rightmost number = current Set; circles = Round
  ├──^──────
 8│■ ■ ■ ■ □     <- squares = Wave; left number = lives remaining
```

Flow details that constrain any design:

- Weapon Drops, if enabled, occur at the **start of each round**. Spartans also
  get extra lives at the start of each round after the first.
- On a new wave, **dead players' respawn timers are reset**, then the engine
  picks one squad type for that wave. With dropships enabled, six squads of that
  type arrive by dropship; otherwise they spawn map-specifically.
- Every wave except the last in a round ends when **all but three** enemies are
  dead. The last wave in a round ends when **all** are dead, and the final five
  survivors get waypoints (not shown until they land from dropships).
- An empty wave (squad type `none`, or a type **unsupported on this map**) ends
  after roughly **7–9 seconds**.
- With dropships enabled, wave end is always delayed until the dropships have
  fully exited.
- Completing a Boss Wave awards **one extra life per Spartan**, respawns all
  dead players, fully restores living players' shields, and awards the Hero
  medal if applicable.
- The **Bonus Wave** is special: it does not end when its enemies die. It ends
  only when its duration elapses, or when all Spartans are simultaneously dead
  — the latter **even if the Iron Skull is off**. With dropships on, they stay
  and keep delivering enemies until it ends. Everything spawned by the bonus
  wave dies instantly when it ends (map-hazard spawns excepted). The bonus wave
  **cannot be triggered early**.
- Sudden Death appears to activate if any generators remain online, with an
  extra check on whether they are locked; generators seem unlockable while
  Sudden Death is active.

### 4.2 The Firefight settings block

The complete variant payload, from
[`types/firefight.h`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/types/firefight.h):

```cpp
ReachUGCHeader              variantHeader;
cobb::bitbool               isBuiltIn;
ReachCustomGameOptions      options;
bitnumber<5>                scenarioFlags;
bitnumber<3>                mccExtensionVersion;
bitnumber<8>                waveLimit;
bitnumber<15>               bonusTarget;          // points; always 10000?
bitnumber<15>               eliteKillBonus;
bitnumber<7,signed>         startingLivesSpartan;
bitnumber<7,signed>         startingLivesElite;
bitnumber<7,signed>         maxSpartanExtraLives;
bitnumber<2>                generatorCount;
ReachPlayerTraits           baseTraitsSpartan;
ReachPlayerTraits           baseTraitsElite;
ReachFirefightWaveTraits    baseTraitsWave;
ReachFirefightCustomSkull   customSkulls[3];      // red, yellow, blue
ReachCGRespawnOptions       eliteRespawnOptions;
ReachFirefightRound         rounds[3];
bitnumber<12>               bonusWaveDuration;    // seconds
skull_list_t                bonusWaveSkulls;
ReachFirefightWave          bonusWave;
bytenumber<uint8_t>         mccExtensionFlags;
```

`scenarioFlags` bits: `hazards_enabled 0x01`, `all_generators_must_survive
0x02`, `random_generator_spawns 0x04`, `weapon_drops_enabled 0x08`,
`ammo_crates_enabled 0x10`.

`waveLimit` presets: `no_limit 0`, `one_wave 1`, `one_round 5`, `two_rounds 10`,
`one_set 16` (15 waves + bonus), `two_sets 32`, `three_sets 48`, `four_sets 64`,
`five_sets 80`, `ten_sets 160`.

`mccExtensionFlags`: `network_test_1 = 0b00000001`. This is the MCC-added
"Waves" option that can wholly disable enemy spawning. Note the comment on
`mccExtensionVersion`: "values >= 2 skip loading all FF data as of 7/14/2023."

Per-round and per-wave structure:

```cpp
class ReachFirefightRound {
	skull_list_t       skulls;       // 18-bit mask, per round
	ReachFirefightWave waveInitial;  // wave 1 of 5
	ReachFirefightWave waveMain;     // waves 2-4
	ReachFirefightWave waveBoss;     // wave 5
};

class ReachFirefightWave {
	bitbool      usesDropship;
	bitbool      orderedSquads;
	bitnumber<4> squadCount;   // squads actually defined; rest ignored.
	                           // below-normal counts may not be honored
	squad_type_t squads[12];   // 8-bit firefight_squad each
};
```

Skulls can be set **per round**; dropships and squad lists are set **per wave
type** (initial / main / boss), not per individual wave.

Non-obvious squad-cycling behaviour, from the header comment: a wave type may
define more squads than it has uses, because **each Set cycles the starting
index**. "In Set 1, Round 1 will use: Initial Wave squad 0; Main Wave squads 0,
1, and 2; and Boss Wave squad 0. In Set 2, Round 1 will use: Initial Wave squad
1; Main Wave squads 1, 2, and 3; and Boss Wave squad 1." So a 5-squad main-wave
list gives genuine variety across sets.

Skull enum (`firefight_skull`): `iron, black_eye, tough_luck, catch_, fog,
famine, thunderstorm, tilt, mythic, assassin, blind, cowbell` ("superman"
internally), `grunt_birthday_party, iwhbyd, red, yellow, blue`.

### 4.3 The squad type enum — this is your entire AI palette

`reach::firefight_squad` from
[`firefight_round.h`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/components/firefight_round.h).
The comment is load-bearing: "These correspond to the Waves list in the SMDT
(Survival Mode Globals) tag." The variant stores an index; the *meaning* lives
in the map's tags.

| # | Name | Composition |
|---:|---|---|
| -1 | `none` | nothing (assumed) |
| 0 | `brutes` | Brutes only |
| 1 | `brute_kill_team` | Brutes led by a chieftain |
| 2 | `brute_patrol` | Brutes + Grunts |
| 3 | `brute_infantry` | Brutes + Jackals |
| 4 | `brute_tactical` | Brutes + Skirmishers |
| 5 | `brute_chieftains` | Brute chieftains only |
| 6 | `elites` | Elites only |
| 7 | `elite_patrol` | Elites + Grunts |
| 8 | `elite_infantry` | Elites + Jackals |
| 9 | `elite_airborne` | Elites with jetpacks |
| 10 | `elite_tactical` | Elites + Skirmishers |
| 11 | `elite_spec_ops` | Elite spec-ops only |
| 12 | `engineers` | a single Engineer (**not in UI**) |
| 13 | `elite_generals` | one Elite General per spawn point |
| 14 | `grunts` | four Grunts per spawn point |
| 15 | `hunter_kill_team` | Hunters + Elites + Grunts |
| 16 | `hunter_patrol` | Hunters + Grunts |
| 17 | `hunter_strike_team` | Hunters + Elites led by a general |
| 18 | `jackal_patrol` | Jackals + Grunts |
| 19 | `elite_strike_team` | Elites led by a general |
| 20 | `skirmisher_patrol` | Skirmishers + Grunts |
| 21 | `hunters` | one Hunter per spawn point |
| 22 | `jackal_snipers` | Jackals with Needle/Focus Rifles |
| 23 | `jackals` | Jackals only |
| 24 | `hunter_infantry` | Hunters + Jackals |
| 25 | `guta` | a single Guta ("Mule" internally); **not in UI**, only on supported maps "and none seem to" |
| 26 | `skirmishers` | Skirmishers only |
| 27 | `hunter_tactical` | Hunters + Skirmishers |
| 28 | `skirmisher_infantry` | Skirmishers + Jackals |
| 29 | `heretics` | Elites with human weapons, varying by difficulty |
| 30 | `heretic_snipers` | Elites with human sniper rifles |
| 31 | `heretic_heavy` | Elites with human explosives |

**Answering the brief's question about available AI character types directly:**
every selectable squad type is **Covenant**. There is **no Marine, ODST, or
Spartan squad type** in a Firefight variant. Friendly AI appears in exactly one
place in stock Reach Firefight — the ODSTs on Installation 04, which Halopedia
calls "the first and — to date — only Firefight map to contain friendly AI"
(<https://www.halopedia.org/Reach:Installation_04>). Those are baked into that
map's scenario. **Marines fighting on the player's side requires Path C.**

Also note the brief's "squad size limits": the per-wave array is 12 slots with a
4-bit `squadCount`, and the engine spawns **6 squads per wave** of the chosen
type. The number of *actors* per squad is map/tag-side, not variant-side — e.g.
`grunts` is "four Grunts per spawn point", `hunters` is "one Hunter per spawn
point."

### 4.4 Spawn locations

Firefight AI spawn points are **map-baked**, not Forge-label-driven. The variant
has no mechanism to reference a spawn location. RVT, on observed behaviour:
squads "spawn in a map-specific manner (typically just appearing out in the
open, though Corvette spawns them behind locked doors instead)." Dropship
delivery is a per-wave boolean; the dropship paths themselves are map data.

A squad type can be **unsupported on a given map**, in which case the wave
simply produces nothing and ends in 7–9 seconds. Test every squad type on every
target map.

### 4.5 Reading and modifying SCORE

Three different mechanisms, and which one you get depends on your path.

**In a Firefight variant (Path A)** there is no script, so score is engine-side.
The variant exposes only the targets: `bonusTarget` (a point quantity, "always
10000?") and `eliteKillBonus`. RVT notes `bonusTarget` is "exposed to the
HaloScript code that powers Firefight (`survival_mode_get_bonus_target`)"
([`main_window_ff/scenario.xml`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/docs/working%20-%20help%20docs/editor/main_window_ff/scenario.xml)).

**In HaloScript (Path C)**, from c20's Reach HSC function data
([`src/data/hsc/hr/functions.yml`](https://github.com/Sigmmma/c20/blob/master/src/data/hsc/hr/functions.yml)):

```hsc
(<void> survival_increment_human_score <player>)  ; "Increments the player's score by one."
(<void> survival_increment_elite_score <player>)
(<long> survival_mode_get_bonus_target)           ; reads bonusTarget from the variant
(<void> survival_mode_bonus_multiplier_set <...>)
(<long> survival_mode_set_multiplier_get)
```

Note `survival_increment_human_score` increments by exactly one, with no
quantity argument. Awarding N points means calling it N times or going through
the multiplier functions.

**In a multiplayer Megalo variant (Path B)**, score is a first-class scriptable
value — `set_score` plus the `.score` member:

```megalo
action set_score add kill_points player killing_player   ; HREK slayer_RPG.txt
action set_score add 1 team current_team                  ; HREK stockpile.txt
action set current_player.score add 1
condition if current_player.score >= k_cost_warthog
```

`set_score` takes a math operation, a numeric value or variable reference, and a
team-or-player target. "A team's total score will be the sum of the score
assigned to its players and to the team using this action."

**This is the key asymmetry for the purchase-menu feature in §6:** a spendable
score economy is easy in Path B and hard in Path A.

---

## 5. Spawning and controlling AI: the honest answer

### 5.1 Megalo cannot do it

Stated plainly because an invented API would poison every script written after
it: **there is no Megalo action that spawns an AI squad, sets an AI character
type, or sets AI allegiance.** Not in Reach, not in Reach's MCC build.

Evidence, two independent reverse-engineering efforts agreeing:

1. RVT's opcode table — 93 base actions + MCC backports, 16 named conditions.
   The complete MCC-extension action list is: *Run Inline Nested Trigger*,
   *Call HaloScript Function*, *Get Button Press Duration*, *Toggle Vehicle
   Spawning for Team/Player*, *Set Respawn Vehicle for Player/Team*, and
   *Set Hidden*. No AI actions.
   [`actions.cpp`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/components/megalo/actions.cpp)
2. MegaloEdit's documented 112 actions — a keyword sweep for `squad`, `ai_`,
   `character`, `allegiance`, `marine`, `odst`, `grunt`, `wave` finds nothing.
   [`language/actions/`](https://github.com/craftycodie/MegaloEvolved/tree/main/packages/docs/language/actions)

Corroborating: `faris0064/VSCode-ReachVariantTool`'s syntax grammar lists ~150
functions and ~160 object types, with no AI or squad entries; the only bipeds
are `spartan`, `elite`, `monitor`.

The closest Megalo gets is `create_object`, which spawns **inanimate** bipeds.
RVT's own wording for the weapon actions is explicit: "Give a weapon to any
biped, be it a player or an **inanimate script-spawned** Spartan, Elite, or
Monitor." A `create_object`-spawned Elite is a prop. It has no AI.

```megalo
action create_object "flag" set current_team.flag at current_team.goal never_garbage offset 0 0 3
```

`create_object` parameters: type, result variable, basis object, Forge label
filter, flags (`never_garbage`, `suppress_effect`, `absolute_rotation`), offset,
name. Caveat from the docs: an object created inside another object or outside
the game boundary gets repositioned; use `object_attach` then `object_detach`,
or `create_tunnel`, to force exact placement.

### 5.2 What actually spawns AI: HaloScript

AI spawning is HaloScript in the map's scenario. Reach exposes **1,992** HSC
functions, of which **175** are `ai_*` and **54** are `survival_*`. Signatures
below are verbatim from c20's Reach HSC data
([`src/data/hsc/hr/functions.yml`](https://github.com/Sigmmma/c20/blob/master/src/data/hsc/hr/functions.yml)).

**Spawning:**

```hsc
(<void> ai_place <ai>)                       ; places the specified squad on the map
(<void> ai_place <ai> <short>)               ; places N members of the specified squad
(<void> ai_place_wave <long> <ai>)           ; places the specified wave name into squads
                                             ;   defined as part of the given squad group
(<void> ai_place_wave <long> <ai> <short>)   ; ... N squads from that wave name
(<void> ai_place_in_vehicle <ai> <ai>)       ; squad (arg1) into vehicles of vehicle-squad (arg2)
(<void> ai_place_in_limbo <ai>)              ; place on map in limbo
(<void> ai_place_in_limbo <ai> <short>)
(<void> ai_place_cue <...>)
(<short> ai_spawn_count <ai>)                ; actors spawned in the given squad or squad group
```

The `<ai>` type is a **reference to a squad, squad group, or actor defined in
the scenario tag**. It is not a character-type string. You cannot pass "Marine"
to `ai_place`; you place a squad that a designer already defined in Sapien, and
*that squad* specifies its character, count, and spawn points. This is the
single most important correction to the brief's model of how spawning works.

**Allegiance and team — how you make Marines fight for the player:**

```hsc
(<void> ai_set_team <ai> <team>)             ; makes an encounter change to a new team
(<void> ai_allegiance <team> <team>)         ; creates an allegiance between two teams
(<void> ai_allegiance_remove <team> <team>)
(<void> ai_allegiance_break <...>)
(<boolean> ai_allegiance_broken <...>)
(<void> ai_object_set_team <object> <team>)  ; flag an object as owned by a certain team
(<void> ai_prefer_target_team <ai> <team>)   ; the given ai will prefer the indicated team
(<void> ai_prefer_target_ai <...>)
(<void> ai_set_targeting_group <...>)
```

**Player fireteams — Marines that follow you:**

```hsc
(<void> ai_player_add_fireteam_squad <unit> <ai>)   ; adds the squad to the player's fire team
(<void> ai_player_remove_fireteam_squad <unit> <ai>)
(<void> ai_player_set_fireteam_max <...>)
(<void> ai_player_set_fireteam_max_squad_absorb_distance <...>)
(<boolean> ai_is_in_fireteam <...>)
```

**Lifecycle and queries:**

```hsc
(<short> ai_living_count <ai>)
(<short> ai_body_count <ai>)
(<void> ai_erase <ai>)
(<void> ai_erase_all)
(<void> ai_kill <ai>)
(<void> ai_resurrect <...>)
(<void> ai_renew <...>)
(<ai> ai_get_squad <ai>)
(<unit> ai_get_unit <...>)
(<void> ai_set_task <...>)
(<void> ai_set_objective <...>)
(<void> ai_survival_cleanup)
(<void> ai_braindead <...>)
(<void> ai_magically_see_object <...>)
```

**Firefight's own HaloScript layer** — this is what the stock Firefight maps run:

```hsc
(<void> survival_mode_begin_new_wave)
(<void> survival_mode_begin_new_set)
(<void> survival_mode_end_wave)
(<void> survival_mode_end_set)
(<long>  survival_mode_get_wave_squad)              ; "the name of the squad template
                                                     ;  for the current wave"
(<short> survival_mode_wave_get)
(<short> survival_mode_round_get)
(<short> survival_mode_waves_per_round)
(<short> survival_mode_rounds_per_set)
(<boolean> survival_mode_current_wave_is_initial)
(<boolean> survival_mode_current_wave_is_boss)
(<boolean> survival_mode_current_wave_is_bonus)
(<boolean> survival_mode_current_wave_is_last_in_set)
(<boolean> survival_mode_current_wave_uses_dropship)
(<void>  survival_mode_lives_set <team> <long>)
(<long>  survival_mode_lives_get <...>)
(<long>  survival_mode_get_bonus_target)
(<void>  survival_increment_human_score <player>)
(<void>  survival_mode_award_hero_medal <...>)
(<void>  survival_mode_weapon_drops_enable <...>)
(<void>  survival_mode_ammo_crates_enable <...>)
(<void>  survival_mode_generator_defend_all <...>)
(<void>  survival_mode_sudden_death <...>)
```

The shape of the stock design is now clear: the variant's wave settings feed
`survival_mode_get_wave_squad`, the map script reads it and calls the
appropriate `ai_place_wave` against its own scenario-defined squad groups.

### 5.3 The bridge: `hs_function_call` (MCC only)

This is the one seam between Megalo and AI, and it is narrow but real.

```megalo
action hs_function_call kill_player
```

```hsc
; This block is HaloScript, not Megalo
(script dormant void kill_player
    (unit_kill (unit (list_get (players) 0)))
)
```

Requirements, from MegaloEvolved's
[`actions/hs-function-call.md`](https://github.com/craftycodie/MegaloEvolved/blob/main/packages/docs/language/actions/hs-function-call.md):
"Calls a dormant HaloScript function that matches the argument's name (Reach MCC
only). The function name needs to be in `strings.txt` to compile **and** in the
`megalo_string_id_table` tag to function properly."

RVT's account agrees and adds the tag name: "MCC-exclusive: Call HaloScript
functions made available by the current map; intended for mods that rely on
map-and-Megalo pairs… Maps can make HaloScript functions available by writing
the function names into the `msit` tag." Added mid-July 2023, and it "will
likely fail to load on Xbox 360 builds."
([`script/api/ns_game.xml`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/docs/working%20-%20help%20docs/script/api/ns_game.xml))

Also relevant: `(<void> sandbox_load_label_strings <string>)` — "loads the label
strings from the given .mglo file. Only useable in the forge lobby."

**Constraints on the bridge, and they are serious:**

- It takes **no arguments and returns nothing**. The only datum passed is
  *which* function to call. Parameterised calls need one dormant HS function per
  distinct parameter value.
- The function must be **dormant** and pre-declared in the map.
- It is **map-specific by construction** — this is the one Megalo action that
  destroys a variant's map-agnosticism (§8).
- Sync is unreliable: "It is unlikely that HaloScript will always sync properly,
  so it is recommended to put this in a local trigger."

So the realistic architecture for an ambitious Firefight mod is a
**map-and-Megalo pair**: HREK-authored HaloScript holding the squad definitions
and the `ai_place` calls, exposed as dormant functions via `msit`, driven by a
Megalo multiplayer variant that owns the score economy, HUD and purchase menu.
That is Path B + Path C together, and it matches the scale of the 7.3 GB
Workshop item.

---

## 6. Building an in-match purchase menu

All of this is Path B (multiplayer Megalo variant). The parts exist; the
constraints are tight.

### 6.1 Do not use the requisition system

Megalo has a requisition API that looks perfect and is not:

```megalo
action player_adjust_money current_player add 5
action player_enable_purchases current_player dead all true
action player_set_requisition_palette current_player <palette>
```

MegaloEvolved's note on both money actions: "part of the Requisition System that
was **scrapped before Halo: Reach's release**. While much of the requisition
functionality remains in the game to this day, the requisition menu is long
gone, rendering this action **effectively useless** outside of early pre-release
builds." RVT concurs on the palette action: "This functionality is **not used**
in Halo: Reach."

So: track currency in a `player`-scoped number variable, or reuse `.score`.

### 6.2 Reading input

Two viable triggers, with a clear recommendation.

**Option A — held button, MCC only.** The only true button-input action:

```megalo
action get_button_time current_player jump button_hold_ms
```

Buttons (`e_scriptable_game_buttons`): `jump 0`, `grenade 1`, `switch_weapon 2`,
`context_primary 3`, `melee_attack 4`, `equipment 5`, `throw_grenade 6`,
`fire_primary 7`, `crouch 8`, `scope_zoom 9`, `night_vision 10`,
`fire_secondary 11`, `fire_tertiary 12`, `vehicle_trick 13`.

**Warning, and this is a design-risk flag, not a nitpick.** RVT's description:
"A **host-only** action to retrieve how long (in milliseconds) a player has held
a given button down. **Intended for debugging purposes only; future MCC updates
may change how this functions.**" Host-only means it will not read correctly for
non-host clients. Do not build a core mechanic on it.

**Option B — zone-and-dwell, the proven pattern.** No input action needed:
a player stands in a labelled Forge zone, a timer counts, the purchase fires.
Entirely networked-safe, works for all clients, and it is what shipping
community gametypes actually do.

```megalo
condition object_in_area current_player current_object
```

**Recommendation: Option B for anything that matters.** Use Option A only as
host-side convenience, if at all.

### 6.3 The shape of a purchase

1. A `map_object` filter picks out buy zones by Forge label, with `user_data`
   distinguishing which item each zone sells.
2. A player-scoped timer counts dwell time in the zone.
3. A condition checks `current_player.score >= cost`.
4. `set_score` (or a currency variable) subtracts the cost.
5. `create_object` spawns the purchase at the zone.
6. `hud_widget_set_text` / `hud_post_message` gives feedback.

Remember the two hard limits: **4 HUD widgets** and **16 map_object filters**.
A multi-item shop therefore encodes item identity in `user_data` or in object
geometry rather than in a separate label per item — exactly what "Endure" does
(§6.4).

### 6.4 A real, public, working example: "Endure"

This is the best public prior art found, and it is worth studying before writing
anything. "Endure" by Cantaloupe0 is a Megalo multiplayer gametype that
recreates Firefight for PvP in custom games. Docs: <https://pastebin.com/raw/bkN5XAuD>.
Nexus page: <https://www.nexusmods.com/halothemasterchiefcollection/mods/685>.

Its techniques, quoted from the author's own documentation:

**A scratch-space anchor object.** "Your map must have at least one hill marker
with the gametype label `controller` on it. *Don't place this object in a kill
zone or out of bounds!* This is where the gametype will store some objects it
needs to reference later." A standard Megalo idiom — a known object to hang
state off.

**Wave-gated object reveal.** Label `wave_req` on "a weapon, vehicle or any
object you want to make appear during a specific wave." Spawn sequence selects
the wave; team selects who sees the waypoint. Caveat noted by the author:
"`wave_req` cannot make teleporters or kill zones activate for a specific wave.
This is because `wave_req` just hides objects."

**Squad spawn points via labelled weapons.** Label `ff_squad` on "a weapon you
want a squad to spawn with. The squad will spawn at the weapons location. The
rotation of the weapon will determine where the squad is facing." Spawn sequence
1–32 selects the squad composition (`1 = 4 elite minors` … `32 = 1 elite
general`), and "using one of these values but negative will give the squad
active camo traits."

**Encoding extra parameters in object geometry.** This is the clever part, and
it is a direct workaround for Megalo's scarcity of per-object data: "I use the
objects boundary to allow the gametype to understand what wave squads are for.
Simply set the boundary to cylinder, with a radius of 0.1. Now the bottom length
of the boundary will control what wave the squad is for. For example, 0.1 is
wave 1 and 0.2 is wave 2." The **top** boundary length then selects a vehicle or
turret add-on (`0.3 = ghost`, `1.1 = scorpion`, `1.9 = nose gun falcon`, …).
Team designator controls spawn ordering: "RED = FIRST, NEUTRAL = LAST."

**Honesty note on Endure:** its "elites" are **player-controlled**, not AI. It
is explicitly PvP — "This gametype attempts to recreate firefight but for PVP in
custom games." The `ff_squad` label positions where *player* Elites spawn and
which trait tier they get. It is therefore proof of the *economy and
wave-structure* techniques, and simultaneously more evidence that Megalo has no
AI. Whether its elites are AI was flagged as unverified by research and is now
resolved: they are players.

Source is not published — only the compiled `.bin` and this prose
documentation.

---

## 7. Halo: Reach Firefight maps in MCC

Reach Firefight has **exactly 10 native maps**, all present in MCC.

Halopedia: "In the initial launch of ''Reach'', the game supported eight maps…
Two original maps were later added in the game's downloadable content, with all
maps included in the port of ''Halo: Reach'' included in ''Halo: The Master
Chief Collection''." (<https://www.halopedia.org/index.php?title=Reach:Firefight&action=raw>)

Independently corroborated by RVT's map-ID table, which marks exactly these ten
as Firefight entries
([`ui/script_editor/page_map_perms.cpp`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/ui/script_editor/page_map_perms.cpp)).

### Native Firefight maps — valid targets

| Map | Origin | Dev name | Map ID |
|---|---|---|---|
| Overlook | Base game | `ff10_prototype` | 7000 |
| Courtyard | Base game | `ff20_courtyard` | 7020 |
| Outpost | Base game | `ff60_airview` | 7030 |
| Waterfront | Base game | `ff30_waterfront` | 7040 |
| Beachhead | Base game | `ff50_park` | 7060 |
| Holdout | Base game | `ff70_holdout` | 7080 |
| Corvette | Base game | `ff45_corvette` | 7110 |
| Glacier | Base game | `ff60_icecave` | 7130 |
| Unearthed | Defiant Map Pack | `ff_unearthed` | 7500 |
| Installation 04 | Anniversary Map Pack | `cex_ff_halo` | 10080 |

- Unearthed: "a Firefight map in Halo: Reach released as a part of the Defiant
  Map Pack" (<https://www.halopedia.org/Reach:Unearthed>).
- Installation 04: "a Firefight map included in the Anniversary Map Pack"; its
  ODSTs make it "the first and — to date — only Firefight map to contain
  friendly AI" (<https://www.halopedia.org/Reach:Installation_04>).

### Not Firefight maps — refuted candidates from the brief

| Map | Reality |
|---|---|
| **Breakneck** | Anniversary **multiplayer** map, `cex_headlong`, listed gametype Big Team Slayer. ID 10050. <https://www.halopedia.org/Reach:Breakneck> |
| **Highlands** | Defiant **multiplayer** map, `trainingpreserve`, CTF and BTB. ID 1510. <https://www.halopedia.org/Reach:Highlands> |
| Condemned | Defiant, multiplayer only. ID 1500. |
| Anchor 9, Breakpoint, Tempest | Noble Map Pack, "three new **multiplayer** maps". IDs 2001, 2002, 2004. |
| Battle Canyon, Penance, High Noon, Ridgeline, Solitary | Anniversary, "six remastered **multiplayer** maps". IDs 10010–10070. |
| Hemorrhage | A **map variant of Forge World**, so it carries Forge World's ID 3006. |
| **Rally Point** | Not a Reach map at all — it is a **Halo 3: ODST** Firefight map. |
| **Quarry** | Not a Reach map — a **Halo 4** Spartan Ops map, `ff87_chopperbowl`. |

So of the brief's candidate list: Beachhead, Corvette, Courtyard, Glacier,
Holdout, Outpost, Overlook, Waterfront, Unearthed and Installation 04 are
valid. **Breakneck and Highlands are not** — they are multiplayer maps and
cannot host a Firefight variant without a map mod.

All three DLC packs are in MCC: Noble "included in the release of Halo: Reach as
part of Halo: The Master Chief Collection"; Defiant "All Defiant Map Pack
content is included"; Anniversary "All Anniversary pack content is included."

### Firefight on a multiplayer map requires a map mod

No variant setting achieves this. Every working example found ships modified map
files built with HREK:

- Steam Workshop "Anchor 9 Firefight" <https://steamcommunity.com/sharedfiles/filedetails/?id=2991845160>
- "deadkiva7's Halo: Reach Firefight (Map Pack)" — Breakpoint, Highlands,
  Ridgeline, Spire, Tempest <https://steamcommunity.com/sharedfiles/filedetails/?id=3434207298>
- Nexus "Breakneck firefight" (2159), "Firefight on Forge World" (2129),
  "Tempest firefight" (2177) <https://www.nexusmods.com/halothemasterchiefcollection/mods/2159>

Also note stock MCC offers **no Forge on Firefight maps** — the "Firefight
Reforged" mod exists precisely to "use forge mode on Halo Reach firefight maps"
and needs HREK (<https://www.nexusmods.com/halothemasterchiefcollection/mods/2905>).
This kills any plan to author Forge-label AI spawns on a Firefight map from
inside stock MCC.

---

## 8. Is a variant map-agnostic? Precisely

**Short answer: yes for both kinds, but for different reasons, and with one
MCC-only exception that breaks it.**

### 8.1 Gametypes and map variants are separate files

- A **gametype** is a BLF file with an `mpvr` block (`gvar` for matchmaking),
  carrying an engine type of `none, forge, multiplayer, campaign, firefight`
  (RVT `game_variants/base.cpp`).
- A **map variant** is an `mvar` file. It stores the base map ID
  (`o.mapID = stream.readBits(32, false); // the ID of the map we're built on`),
  its own Forge label string table, and a `forgeLabelIndex` per object
  ([`map_variant_mvar.js`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/html/src/raw/map_variant_mvar.js)).

So "new map" means a new **`.mvar`**, and "new gametype" means a new **`.bin`**.
They are independent and shipped separately.

### 8.2 Multiplayer Megalo variants: map-agnostic by design

A Megalo script never names a map. It finds objects by **Forge label string**,
which is why one script runs anywhere:

- RVT: "Name: The name to use for a Forge label; the label matches all objects
  with this label assigned."
- RVT `for.xml`: "The label can be specified as a string literal containing the
  label's name, or as an integer constant denoting the index of the Forge label
  in the game variant's Forge label list."
- MegaloEdit: `map_object … label "slayer"` means "match any map object with
  this Forge label string."

A gametype only narrows its map compatibility through three **optional** opt-in
mechanisms:

1. **Map permissions** — a numeric list of up to 32 map IDs used as an allow- or
   deny-list (`only_these_maps = 0, never_these_maps = 1`,
   [`components/map_permissions.h`](https://github.com/DavidJCobb/ReachVariantEditor/blob/master/native/src/ReachVariantTool/game_variants/components/map_permissions.h)).
   RVT: "The usual setup is to use a blacklist that doesn't actually have any
   maps checked" — i.e. stock gametypes ship unrestricted.
2. **Required object types** — "Halo: Reach will not allow players to play this
   game variant on any base map that does not define that object", e.g. the
   Covenant Bomb, which only exists on Breakpoint.
3. **Forge label minimum count** — "Map Must Have At Least: The minimum number
   of labeled objects that must exist on the map in order for this game variant
   to be considered compatible." This is the `min` field on `map_object`.

A clean worked example of a deliberately map-agnostic gametype: Cobb's
Minesweeper — "Setup requires the placement of seven objects in Forge. The first
should be a Hill Marker with the Forge label `MINESWEEP_BOARD`"
(<https://github.com/DavidJCobb/halo-reach-content/blob/master/README.md>).

**The one exception that breaks map-agnosticism: `game.hs_function_call`.** It
calls a function that must exist in *that map's* `msit` tag. Any script using it
is bound to its paired map. See §5.3.

*Open discrepancy, flagged:* MegaloEvolved's `map-permissions.md` describes the
block as "Controls which Forge objects can be placed on which maps," which
conflicts with RVT's map allow/deny-list reading. RVT's account matches the
struct. Treat MegaloEvolved's wording as probably wrong here, and verify before
relying on it.

### 8.3 Firefight variants: map-agnostic, but only across the 10 native maps

A Firefight variant has **no map permissions, no Forge labels, and no script**,
so it carries nothing map-specific. It is portable across all 10 native
Firefight maps. But its *results* vary per map, because it only selects squad
**indices** into the map's SMDT tag, and a squad type "not supported on the
current map" yields an empty 7–9 second wave (§4.4).

Confirmed in the field by a Firefight variant pack built with RVT: "These modes
can be used on any map (though Alliance Firefight will only work as intended on
Installation 04)" — Alliance mode depends on that map's unique friendly ODSTs
(<https://www.nexusmods.com/halothemasterchiefcollection/mods/521>).

**On a non-Firefight map:** stock MCC does not offer non-Firefight maps in the
Firefight lobby, and every community example adds map files instead (§7). What
happens if a Firefight variant were forced onto a multiplayer map — crash, empty
waves, or refusal to load — was **not tested** and is **NOT VERIFIED**. RVT
notes the reverse direction is also gated: "With modded MAPINFOs, a person can
host Custom Games on Campaign and Firefight maps," implying stock MCC blocks it.

### 8.4 The project-planning consequence

| Goal | What you ship |
|---|---|
| New Firefight tuning on existing maps | **One** `.bin` Firefight variant, reused on all 10 maps |
| New Megalo gametype on existing maps | **One** `.bin` multiplayer variant + one `.mvar` per map with the required labels |
| Firefight on a new/multiplayer map | **A modified map file** (HREK), per map. Not a variant problem at all |
| Marines/ODSTs on the player's side | **A modified map file** per map, with HaloScript squads. Optionally `msit` + Megalo pair |

So "new maps" means new **Forge map variants** for Path B, and new **map mods**
for anything involving AI. It does not mean new variant files.

---

## 9. Existing open-source Megalo scripts

**No public Megalo script drives real Firefight AI.** That follows from §5.1 —
it is not possible. Every open repo is a multiplayer gametype, and every
Firefight variant on Nexus or Steam ships as a compiled `.bin` with no source.

**None of these repos states a license** unless noted. Check before adapting.

| Repo | License | Dialect | Contents |
|---|---|---|---|
| [petfelt/RVT-scripts](https://github.com/petfelt/RVT-scripts) | none stated | RVT (`.vb`) | 9 gametypes: ability-slayer, bomb-zombies, castle-wars-rolls, depth-chargers, frozen-throne, halo-moba (77 KB), hostage-rescue, the-glitch, whack-a-mole |
| [DavidJCobb/halo-reach-content](https://github.com/DavidJCobb/halo-reach-content) | none stated | RVT (`.lua`) | `minesweeper.lua` + 2 `.mvar`, `race_plus.lua`, `halo chess.lua`, `boundary_break.lua`, 2 proof-of-concept scripts. Best-documented single example |
| [jackbrookes/halo-reach-custom-gametypes](https://github.com/jackbrookes/halo-reach-custom-gametypes) | none stated | RVT (`.lua`) | **21 official gametypes, decompiled and commented** (credited to DavidJCobb), plus gun game and a monitor boss fight |
| [craftycodie/MegaloEvolved](https://github.com/craftycodie/MegaloEvolved) | none stated | **MegaloEdit** | The language reference this doc leans on, plus a cross-platform compiler and IDE |
| [faris0064/VSCode-ReachVariantTool](https://github.com/faris0064/VSCode-ReachVariantTool) | **GPL-3.0** | RVT | VSCode grammar. `syntaxes/rvt.tmLanguage.json` is a de-facto keyword inventory: ~150 functions, ~160 object types |
| [faris0064/Frontlines-Gametype](https://github.com/faris0064/Frontlines-Gametype) | none stated | RVT (`.rvt`) | 6 Frontlines variants |
| [BenjaminCot/Halo-Reach-Hot-Pursuit](https://github.com/BenjaminCot/Halo-Reach-Hot-Pursuit) | none stated | RVT (`.lua`) | `hpcode.lua` + `.bin` + many `.mvar` — a good example of shipping a gametype with per-map variants |
| [NateRFrost/Forge-Race](https://github.com/NateRFrost/Forge-Race) | none stated | RVT | `Forge Race Source.rvt` |
| [Pix3lPirat3/halo-megalo-snippets](https://github.com/Pix3lPirat3/halo-megalo-snippets) | none stated | RVT | `reach/golf_ball_player.lua` |
| [Sopitive/highlightjs-rvt-script](https://github.com/Sopitive/highlightjs-rvt-script) | **MIT** | n/a | highlight.js grammar for RVT |
| [Sopitive/MapVariantEditor](https://github.com/Sopitive/MapVariantEditor) | not checked | n/a | Map variant viewer/editor |
| [PaleLebouf/OmahaScript](https://github.com/PaleLebouf/OmahaScript) | none stated | n/a | Megalo docs |

Repos that are README-only, with no scripts: `Pfoiffee/HaloGametypes-Megalo`,
`Kobalent/hr_juggernaut_silent_shadow` (GPL-3.0).
`KabutoVI/covenant-command` (MIT) is Halo 3 / Project Reclaimer — out of scope.

**Structural pattern in `petfelt/RVT-scripts`** (worth copying regardless of
dialect): (1) `declare global/player/object.<type>[n] with network priority
low|local`; (2) top-level `for each object with label "..."` and `for each
player` blocks; (3) `on object death: do` / `on local: do` handlers. Labels used
include `ffa_only`, `team_only`, `Hostage_Select`, `Falcon_Plus`, `HM_Tower`,
`HM_Shop`, `WAM_Mole`, `dc_checkpoint`, plus a reusable helper set
(`attach_base`, `attachment`, `scale`, `spawner`, `object_by_index`). No AI or
Firefight references anywhere.

### The single most valuable corpus

**`HREK\data\multiplayer\megalo\`** — Bungie's own shipped sources, in real
MegaloEdit syntax: `3nvasion.txt`, `ctf.txt`, `slayer.txt`, `territories.txt`,
`headhunter.txt`, `stockpile.txt`, `slayer_RPG.txt`, plus a `simple/` directory
of minimal examples and a `broken/` directory of pre-release experiments
(`dmiller_sve.txt`, `1Flag_Boneyard.txt`) that are the only place the
requisition actions appear. Read these first. They are the ground truth that
MegaloEvolved's docs were derived from, and they are on disk as soon as HREK is
installed.

### Nexus Firefight variants (compiled only, no source)

- [ReachVariantTool itself, mod 192](https://www.nexusmods.com/halothemasterchiefcollection/mods/192) — ships "Official gametype source scripts: All official gametypes decompiled into script code, with variable names, comments, and other documentation added." High value.
- [Endure, mod 685](https://www.nexusmods.com/halothemasterchiefcollection/mods/685) — the PvP pseudo-Firefight dissected in §6.4.
- Panicfight (490), Schism Firefight (521), Elite Firefight (2815) — Firefight variants built with RVT, compiled only.

### The reference mod: Workshop 3453792163

**Correction to the brief:** item `3453792163` is not titled "Firefight
Evolved". Its real title is **"Halo Reach: Evolved Public Beta"** by The
Vengeful 'Vadam. Tags: Engine HaloReach; Campaign, Firefight. **7.334 GB**.
Posted 2025-03-28, last updated 2026-03-15. 21 change notes, 263 comments.
<https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163>

Description: the first four campaign missions plus Firefight on Installation 04,
Unearthed and Corvette. Firefight has "an ingame currency system using your
Firefight score" to buy weapon crates, base upgrades, armor abilities and win
conditions. Known issues include "Generator Defense and Firefight VS are
currently not supported."

"Firefight Evolved" is a **separate gametype `.bin`** the author distributes
off-Steam: "YOU'RE GOING TO WANT MY FIREFIGHT EVOLVED GAMETYPES", via OneDrive
or his gamertag file share. The OneDrive link returned 401/404, so the `.bin`
could not be inspected and **its engine type is unknown**.

Change notes mention "gametype objective features", a banking system
("deposits 200 points"), a mystery box and buyable rounds.

**Which tools the author used is never stated** in the description, the 21
change notes, or his comments — **NOT VERIFIED**. But the 7.3 GB payload and the
Campaign+Firefight tags mean it necessarily ships modified map files, i.e.
Path C, with a gametype alongside. That is the architecture to assume when
planning to match its feature set.

---

## 10. Annotated example skeleton

MegaloEdit syntax. This compiles as a **multiplayer** variant (Path B) — the
only kind that can hold a script. It implements a wave-timer loop, a score
economy, a dwell-based purchase zone, and HUD feedback: the Path B pattern in
full.

Verify against the stock HREK sources before trusting any line; it is assembled
from documented syntax, not copied from a known-compiling script.

```megalo
; ============================================================================
;  firefight_evolved_expanded.txt
;  A Firefight-flavoured MULTIPLAYER Megalo variant.
;
;  WHAT THIS CAN DO:  score economy, wave timing, purchase zones, HUD, Forge
;                     label spawning of weapons/vehicles/props.
;  WHAT IT CANNOT DO: spawn AI. Megalo has no AI action (see section 5).
;                     Real AI needs HaloScript in a modified map (HREK).
;
;  Compile (Windows, HREK root as cwd):
;    MegaloEdit.exe --cli --compile firefight_evolved_expanded.txt out.mglo
;    tool megalo-convert-variant-files "maps\megalo" "maps\game_variants"
;  Then copy the .bin to:
;    ...\Halo The Master Chief Collection\haloreach\game_variants\
;  and FULLY RESTART MCC (it only scans variants once, at the title screen).
; ============================================================================


; ---------------------------------------------------------------------------
; 1. STRINGS.  Symbols, not inline literals, so text stays localizable.
;    Limits: 112 entries, 19456 bytes across all languages.
;    Unreferenced symbols are dropped at compile time and cost nothing.
; ---------------------------------------------------------------------------
string_table english
	ff_title              "Firefight Evolved"
	ff_description        "Survive the waves. Spend your score. Stay alive."
	engine_category_slayer "Slayer"

	hud_credits_label     "CREDITS: %n"
	hud_wave_label        "WAVE %n"
	msg_wave_incoming     "Wave incoming!"
	msg_purchase_ok       "Purchased."
	msg_purchase_poor     "Not enough credits."
end


; ---------------------------------------------------------------------------
; 2. ENGINE DATA.  Name/description/icon/category in the gametype browser.
;    NOTE: `category` has no firefight/survival value - all 31 legal values
;    are multiplayer categories. Write the bare short name (`slayer`), and
;    define the PREFIXED symbol (`engine_category_slayer`) in string_table.
; ---------------------------------------------------------------------------
engine_data
	name        ff_title
	description ff_description
	icon        k_engine_icon_slayer
	category    slayer
end


; ---------------------------------------------------------------------------
; 3. CONSTANTS.  Compile-time, zero variable-slot cost. Prefer these over
;    globals for every magic number; variable slots are capped and scarce.
; ---------------------------------------------------------------------------
constants
	number k_wave_length_seconds  60
	number k_wave_reward          100
	number k_cost_weapon          150
	number k_cost_vehicle         400

	; user_data values that distinguish one buy zone from another, so a
	; multi-item shop costs ONE map_object filter instead of one per item.
	number k_zone_weapon          1
	number k_zone_vehicle         2

	; seconds a player must stand in a zone before the purchase fires
	number k_dwell_required       3
end


; ---------------------------------------------------------------------------
; 4. MAP OBJECT FILTERS (Forge labels).  THIS is what makes the variant
;    map-agnostic: matching is by label STRING, so any .mvar that defines
;    these labels will work. Limit: 16 filters.
;
;    Forge setup this script requires:
;      1x Hill Marker, label "fe_controller"  <- state anchor, keep it OUT of
;                                                kill zones and in bounds
;      Nx any object,  label "fe_buy_zone"    <- user_data selects the item
; ---------------------------------------------------------------------------
map_object fe_controller
	label "fe_controller"
	min   1                      ; refuse to run on a map without the anchor
end

map_object fe_buy_zone
	label "fe_buy_zone"
end


; ---------------------------------------------------------------------------
; 5. HUD WIDGETS.  HARD LIMIT: 4 per script. Spend them deliberately.
; ---------------------------------------------------------------------------
hud_widgets
	w_credits top_right
	w_wave    top_center
end


; ---------------------------------------------------------------------------
; 6. VARIABLES.
;    Scope lives on the `variables` line. Each entry is:
;        <network-state> <type> <name> <initial>
;
;    network state: local | networked | networked_high
;      - `local` is NOT synced AND is RESET TO ITS INITIAL VALUE EVERY TICK.
;        Only ever use it as scratch inside a single tick.
;      - timers are ALWAYS networked; `local timer` is a compile error.
; ---------------------------------------------------------------------------
variables global
	networked number wave_index      0
	networked timer  wave_timer      60    ; set from k_wave_length_seconds at init
	networked object controller_obj  none
end

variables player
	networked number credits         0
	networked timer  dwell_timer     3
	networked number dwell_zone      0     ; which zone the dwell applies to
end


; ---------------------------------------------------------------------------
; 7. INITIALIZATION.  Runs once when the variant loads.
; ---------------------------------------------------------------------------
trigger initialization
	; Cache the controller anchor so later triggers can hang state off it.
	action for_each fe_controller
		action set controller_obj set_to current_object
	end

	action set wave_index set_to 0
	action timer_set_rate wave_timer 1          ; 1 = count down to zero
	action hud_widget_set_text w_wave hud_wave_label wave_index
end


; ---------------------------------------------------------------------------
; 8. WAVE CLOCK.  A `general` trigger runs once per tick, globally.
;    When the wave timer expires: advance, pay everyone, re-arm, announce.
; ---------------------------------------------------------------------------
trigger general
	condition timer_expired wave_timer

	action set wave_index add 1
	action timer_reset wave_timer
	action timer_set_rate wave_timer 1

	action for_each player
		action set current_player.credits add k_wave_reward
	end

	action hud_widget_set_text w_wave hud_wave_label wave_index
	action hud_post_message everyone none msg_wave_incoming
end


; ---------------------------------------------------------------------------
; 9. PER-PLAYER HUD.  `player` kind runs once per player per tick, with
;    current_player bound.
; ---------------------------------------------------------------------------
trigger player
	action hud_widget_set_text w_credits hud_credits_label current_player.credits
end


; ---------------------------------------------------------------------------
; 10. SCORE ECONOMY.  Reward kills into the spendable credit pool.
;     A FALSE CONDITION HALTS THE WHOLE TRIGGER - remaining conditions AND
;     actions are skipped. That is why each rule gets its own trigger.
; ---------------------------------------------------------------------------
trigger player
	condition player_died current_player enemy
	temporary player killer none
	action player_death_get_killing_player current_player killer
	action set killer.credits add 10
	action set_score add 1 player killer
end


; ---------------------------------------------------------------------------
; 11. PURCHASE ZONES.  Dwell-based, NOT button-based.
;
;     Why not buttons: the only input action, get_button_time, is documented
;     as "a HOST-ONLY action ... intended for debugging purposes only; future
;     MCC updates may change how this functions." It will not read correctly
;     for non-host clients. Dwell is networked-safe and works for everyone.
;
;     Pattern: iterate zones, iterate players, test containment, count dwell,
;     check funds, deduct, spawn, notify.
; ---------------------------------------------------------------------------
trigger fe_buy_zone                  ; a map_object label used as a trigger kind
	                                 ; -> runs once per matching object,
	                                 ;    current_object bound to the zone
	temporary object zone current_object

	action for_each player
		; A false condition inside for_each SKIPS THIS ITERATION (like
		; `continue`), rather than halting the whole trigger.
		condition object_in_area current_player zone

		; Count down the dwell timer while the player stands in the zone.
		action timer_set_rate current_player.dwell_timer 1
		condition timer_expired current_player.dwell_timer

		; ---- WEAPON ZONE ----
		action begin
			condition if zone.user_data == k_zone_weapon
			condition if current_player.credits >= k_cost_weapon
			action set current_player.credits subtract k_cost_weapon
			action create_object "assault_rifle" set none at zone never_garbage offset 0 0 1
			action hud_post_message player current_player msg_purchase_ok
			action timer_reset current_player.dwell_timer
		end

		; ---- VEHICLE ZONE ----
		action begin
			condition if zone.user_data == k_zone_vehicle
			condition if current_player.credits >= k_cost_vehicle
			action set current_player.credits subtract k_cost_vehicle
			action create_object "warthog" set none at zone never_garbage offset 0 0 1
			action hud_post_message player current_player msg_purchase_ok
			action timer_reset current_player.dwell_timer
		end
	end
end


; ---------------------------------------------------------------------------
; 12. HOST MIGRATION.  Re-cache anything that was holding an object reference;
;     object refs do not reliably survive a migration.
; ---------------------------------------------------------------------------
trigger host_migration
	action for_each fe_controller
		action set controller_obj set_to current_object
	end
end


; ---------------------------------------------------------------------------
; 13. THE AI BRIDGE - commented out ON PURPOSE.
;
;     hs_function_call is the ONLY seam between Megalo and AI. To use it:
;       a) Author the squads and an `ai_place` call in the MAP's HaloScript
;          (HREK / Sapien), as a DORMANT function:
;
;            (script dormant void fe_spawn_marines
;              (ai_place fe_marine_squad)
;              (ai_set_team fe_marine_squad player_team)
;            )
;
;       b) Register the function name in the map's megalo_string_id_table
;          (`msit`) tag, and put the name in strings.txt so this compiles.
;       c) Call it from here.
;
;     COSTS:
;       - Takes NO arguments and returns NOTHING. One dormant HS function per
;         distinct parameter value.
;       - Binds this variant to that ONE map. It is the single feature that
;         destroys map-agnosticism.
;       - MCC only; "will likely fail to load on Xbox 360 builds".
;       - Sync is unreliable - docs recommend a `local` trigger.
;
; trigger local
;	condition if wave_index == 3
;	action hs_function_call fe_spawn_marines
; end
; ---------------------------------------------------------------------------
```

---

## 11. Syntax cheat-sheet (MegaloEdit)

```megalo
; comment to end of line            (line comments only; no block comment)
```

### Top-level elements

```megalo
include "path.txt"                  ; merge source; resolved once; missing = error
localized_include "path.txt"        ; same, but missing = warning (lenient mode)
base "parent.mglo"                  ; inherit a COMPILED variant

string_table english ... end        ; 112 entries / 19456 bytes max
engine_data ... end                 ; name, description, icon, category
teams ... end
map_permissions ... end
map_object <name> ... end           ; max 16
game_options ... end                ; option / override / player_traits / lock / hide
constants ... end
variables <scope> ... end
hud_widgets ... end                 ; MAX 4
loadout_palette / loadout ... end
game_stats ... end
player_rating ... end
requisition_palette ... end         ; vestigial; the req menu was cut from Reach
trigger <kind> [name] ... end
```

Full-script-only (cannot be added to a base-derived script): `trigger`,
`map_object`, `hud_widgets`.

### Trigger kinds

```
general  player  random_player  team  object
initialization  local_initialization
host_migration  double_migration
object_death  local  pregame
<map_object label>                  ; once per matching object
```

### Inside a trigger (action scope)

```megalo
interval <seconds>                  ; throttle; default is every tick
condition [not] <name> <args> [or]
action <name> <args>
temporary <type> <name> <initial>   ; NOT allowed in pregame triggers
begin ... end                       ; explicit sub-block = if/elseif branching
action for_each <player|team|object|general|label> ... end
```

Semantics: separate conditions = AND; trailing `or` = OR with the next
condition; false condition **halts the trigger**; false condition inside
`for_each` **skips that iteration**.

Capacity: **512 conditions, 1024 actions** script-wide.

### Comparison operators

```
equal_to ==    not equal_to !=    less_than <    greater_than >
less_than_or_equal_to <=          greater_than_or_equal_to >=
```

### Math operations (for `set`, `set_score`, `player_adjust_money`)

```
set_to  =   add   subtract   multiply   divide   modulo
```

### Variables

```megalo
variables global | player | team | object
	local | networked | networked_high
	number | timer | object | team | player
	<name> <initial>
end
```

Gotchas: `local` is unsynced **and reset every tick**. `local timer` is a
compile error. Identifiers share one namespace across variables, constants,
triggers and options.

### Built-in members

```
.score  .team  .rating  .body  .user_data
```

### Context variables

```
current_player   current_team   current_object
killing_player (via player_death_get_killing_player)
```

### Team designators

```
none  defenders  attackers  third_party  fourth_party  ...  neutral  each
```

### Common conditions

```megalo
condition if <a> <op> <b>
condition player_died <player> <environment|suicide|enemy|betrayal|quit_game|any>
condition timer_expired <timer>
condition object_in_area <object> <area>
condition object_out_of_bounds <object>
condition object_is_type <object> "<type>"
condition team_is_active <team>
```

### Common actions by family

```megalo
; flow
action for_each <target> ... end
action begin ... end
action end_round

; variables & score
action set <var> <op> <value>
action set_score <op> <value> <player|team> <target>
action random <...>

; objects
action create_object "<type>" set <var> at <basis> [never_garbage]
                     [suppress_effect] [absolute_rotation] [offset x y z]
action create_tunnel <...>                  ; bypasses repositioning
action delete_object <object>
action object_attach <...> / object_detach <...>
action object_adjust_health / object_adjust_shield
action object_adjust_maximum_health / object_adjust_maximum_shield
action object_set_invincibility <object> <bool>
action object_set_never_garbage <...>
action object_set_scale / object_set_orientation / object_face_object
action object_get_distance / object_get_health / object_get_velocity
action hide_object <...>                    ; MCC
action get_random_object <...>
action get_player_holding_object <object> <result>

; players
action apply_player_traits <player> <traits>
action give_weapon / biped_give_weapon / biped_drop_weapon
action player_pick_up_weapon / weapon_set_pickup_priority
action player_set_unit <...>
action player_death_get_killing_player <player> <result>
action player_death_get_damage_type / player_death_get_special_type
action player_get_weapon / player_get_vehicle / player_get_equipment
action player_get_place / player_get_killing_spree_count
action player_get_target_object
action player_set_objective / player_set_objective_allegiance[_icon]
action player_set_fireteam_index / player_set_fireteam_tier
action player_set_coop_spawning / team_set_coop_spawning
action set_loadout / set_loadout_palette

; respawn
action player_set_primary_respawn_object / team_set_primary_respawn_object
action set_respawn_filter / set_fireteam_respawn_filter / set_pickup_filter
action respawn_zone_enable
action set_player_respawn_vehicle / set_team_respawn_vehicle     ; MCC
action player_set_vehicle_spawning / team_set_vehicle_spawning   ; MCC

; HUD, navpoints, boundaries
action hud_widget_set_text / _value / _meter / _icon / _visibility
action hud_post_message <everyone|team|player> <target> <string>
action navpoint_set_visible / _icon / _priority / _text / _timer / _visible_range
action set_boundary / boundary_set_visible / boundary_set_player_color
action set_progress_bar

; timers
action timer_set_rate <timer> <rate>        ; 0 pause, -1 up, 1 down
action timer_reset <timer>

; audio & events
action play_sound <...>
action submit_incident <incident> <cause> <affected>
action submit_incident_with_custom_value <incident> <cause> <affected> <value>

; MCC only
action hs_function_call <dormant_hs_function_name>
action get_button_time <player> <button> <result_ms>    ; HOST-ONLY, debug-only

; vestigial (requisition system cut before release - do not build on these)
action player_adjust_money / player_enable_purchases
action player_set_requisition_palette

; debug
action print_variable / break_into_debugger / debugging_enable_tracing
action debug_force_force_player_view_count / saved_film_insert_marker
action game_grief_record_custom_penalty
```

### Scriptable buttons (`get_button_time`, MCC, host-only)

```
jump 0  grenade 1  switch_weapon 2  context_primary 3  melee_attack 4
equipment 5  throw_grenade 6  fire_primary 7  crouch 8  scope_zoom 9
night_vision 10  fire_secondary 11  fire_tertiary 12  vehicle_trick 13
```

### Timer rates (anything else is rounded at compile time)

```
0  0.1  0.25  0.5  0.75  1  1.25  1.5  1.75  2  3  4  5  10   (and negatives)
```

### Hard limits

| Thing | Limit |
|---|---|
| HUD widgets | **4** |
| `map_object` filters | **16** |
| Conditions | **512** |
| Actions | **1024** |
| String entries | **112** |
| String data | **19,456 bytes** |
| Map permission entries | 32 map IDs |
| Variable slots | per Megalo version; see the version pages |

### HaloScript AI quick reference (Path C only, needs HREK)

```hsc
(ai_place <squad>)                      (ai_place <squad> <count>)
(ai_place_wave <wave_name> <squad_group>)
(ai_place_in_vehicle <squad> <vehicle_squad>)
(ai_set_team <squad> <team>)            (ai_allegiance <team> <team>)
(ai_object_set_team <object> <team>)    (ai_prefer_target_team <squad> <team>)
(ai_player_add_fireteam_squad <unit> <squad>)
(ai_living_count <squad>)               (ai_spawn_count <squad>)
(ai_erase <squad>)                      (ai_kill <squad>)
(survival_mode_get_wave_squad)          (survival_mode_begin_new_wave)
(survival_increment_human_score <player>)
(survival_mode_get_bonus_target)        (survival_mode_lives_set <team> <n>)
```

`<squad>` / `<ai>` is a **reference to a squad defined in the scenario tag**,
never a character-type string.

---

## 12. Sources

**Primary / near-primary**

- Steam app metadata, app 1695793 "Halo: Reach Mod Tools - MCC" — <https://api.steamcmd.net/v1/info/1695793>
- c20 (Reclaimers Library) — mod tools: <https://c20.reclaimers.net/general/mod-tools/> · HREK: <https://c20.reclaimers.net/hr/hr-ek/> · HR `tool`: <https://c20.reclaimers.net/hr/hr-ek/hr-tool/>
- c20 Reach HaloScript function data (1,992 functions) — <https://github.com/Sigmmma/c20/blob/master/src/data/hsc/hr/functions.yml>
- Halopedia — Reach:Firefight, Reach:Unearthed, Reach:Installation_04, Reach:Breakneck, Reach:Highlands, Noble/Defiant/Anniversary Map Pack pages
- Halo Waypoint, MCC July 2023 update (join-in-progress, 4→8 players, "a new game variant option to Reach Firefight which disables enemy waves") — <https://www.halowaypoint.com/news/halo-mcc-july-2023-update>
- Steam Workshop 3453792163, "Halo Reach: Evolved Public Beta" — <https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163>

**Reverse-engineered, third-party, high quality**

- `DavidJCobb/ReachVariantEditor` — <https://github.com/DavidJCobb/ReachVariantEditor>
  - `game_variants/components/megalo/actions.cpp`, `conditions.cpp` — the opcode tables
  - `game_variants/components/firefight_round.h` — wave/round structs, `firefight_squad` and `firefight_skull` enums
  - `game_variants/types/firefight.h`, `types/multiplayer.h` — variant payloads
  - `game_variants/base.cpp` — BLF chunk order
  - `game_variants/components/map_permissions.h`
  - `ui/script_editor/page_map_perms.cpp` — map IDs
  - `html/src/raw/map_variant_mvar.js` — `.mvar` format
  - `docs/working - help docs/concepts/firefight.xml` — the authoritative Firefight behaviour write-up
  - `docs/working - help docs/script/syntax.xml` — "not compatible with the 'true' Megalo language used in MegaloEdit"
  - `docs/working - help docs/script/api/ns_game.xml` — `hs_function_call` and the `msit` tag
  - `docs/working - help docs/editor/script_window/{map-permissions,forge-labels,required-object-types}.xml`
  - `docs/working - help docs/editor/main_window_ff/scenario.xml`
  - `native/src/ReachVariantTool/README.txt` — MCC variant install paths
- `craftycodie/MegaloEvolved` — <https://github.com/craftycodie/MegaloEvolved> — `packages/docs/language/` is the de-facto MegaloEdit language reference (112 actions, 22 elements, 19 enums, `compiler-settings.md`, `megalo-headaches.md`)
- `Blam-Network/megalo` object lists (incidents, loadout palettes, HUD icons) — <https://github.com/Blam-Network/megalo/tree/main/src/object_lists>
- `faris0064/VSCode-ReachVariantTool` (GPL-3.0) — `syntaxes/rvt.tmLanguage.json`, a keyword inventory
- Cantaloupe0, "Endure" gametype documentation — <https://pastebin.com/raw/bkN5XAuD>

---

## 13. Open questions / NOT VERIFIED

Carried forward honestly. None of these is load-bearing for the §0 conclusions,
but several matter for execution.

**Tooling**

1. No official 343 / Halo Studios MegaloEdit documentation or syntax reference exists, as far as could be determined.
2. The exact GUI menu item that compiles in MegaloEdit.
3. Whether MegaloEdit has `--compile-directory` or other CLI flags beyond `--cli --compile`.
4. Whether MegaloEdit can emit a **Firefight**-engine variant. All evidence says no (the `engine_data category` enum has no firefight value; the Firefight variant type holds no script), but this was not tested directly.
5. What MCC's "survival/firefight flags" Megalo additions actually are.
6. Whether MCC really reads `...\LocalLow\MCC\Temporary\HaloReach\HotReload\.mglo`.
7. Any report of MegaloEdit under Wine / Proton / CrossOver.
8. Whether `@blamnetwork/megalo` is byte-for-byte compatible with MegaloEdit in practice.
9. The `*_gametype.bin` naming convention from the brief.
10. That the HREK sample scripts quoted here are byte-exact — no HREK install was available to diff against.

**Behaviour**

11. What actually happens if a Firefight variant is forced onto a multiplayer map: crash, empty waves, or refusal to load.
12. How the Firefight lobby builds its map list, and whether it filters by map type.
13. The MegaloEvolved vs RVT discrepancy over what `map_permissions` controls. RVT's reading matches the struct; prefer it.
14. Whether `hs_function_call` on a modded map can reliably trigger AI spawns in a networked game. The docs' own sync warning suggests testing this early — it is a plan-level risk.

**The reference mod**

15. Which tools the Halo Reach: Evolved author used — never stated anywhere.
16. Whether the "Firefight Evolved" `.bin` is a Megalo multiplayer variant or a Firefight-engine variant. The OneDrive link was dead (401/404).

**Licensing**

17. `petfelt/RVT-scripts`, `DavidJCobb/halo-reach-content`, `jackbrookes/halo-reach-custom-gametypes` and `craftycodie/MegaloEvolved` state **no license**. Resolve before adapting any of their code.
