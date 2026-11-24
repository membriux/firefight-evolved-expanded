# `tools/compile` — a macOS HaloScript compile driver

Compiles a `.hsc` text file into a Halo: Reach MCC cache's `scnr` script tables, on
macOS, with no Windows and no Halo Reach Editing Kit. It is a thin command-line driver
over **Blamite**, the library inside Assembly, taken from the cross-platform fork that
targets `net8.0`.

The pipeline is the one Assembly's own script editor runs
(`src/Assembly/.../Editors/ScriptEditor.xaml.cs:406-440`):

    lexer -> HS_Gen1Parser.hsc() -> scriptFile.LoadContext -> new ScriptCompiler(...)
          -> ParseTreeWalker.Walk -> compiler.Result() -> SaveScripts

## Status, stated precisely

| Stage | State |
|---|---|
| Driver builds on macOS arm64 | **Proven.** `0 Error(s)`, .NET 8 target under the Homebrew .NET 11 SDK. |
| Engine database, build-string match, opcode table load | **Proven.** 1812 function names, 1716 globals, 89 value types for MCC Update 13. |
| Lexer + parser on our real scripts | **Proven.** 0 syntax errors on all seven `src/hsc/*.hsc` after dialect normalisation. |
| `ScriptCompiler` walk producing bytecode | **Proven** on a clean script: `28 expressions, 2 scripts, 1 globals, 0 tag references, 53 string bytes`. |
| `ScriptCompiler` walk on our scripts | **Reached, and it rejects them.** See the defect list below. |
| `SaveScripts` writing into a cache | **NOT proven.** No usable cache was available — see "The cache problem". |

So: the compiler front end and the compiler itself run here natively. The write-back
leg has never been executed, because it needs a cache with a readable `scnr` tag and
this machine has none that may be touched.

## Prerequisites

1. **.NET SDK.** Installed with Homebrew: `brew install dotnet` (this machine has
   `11.0.100`). The projects target `net8.0`; `build.sh` exports
   `DOTNET_ROLL_FORWARD=LatestMajor` so the 11 SDK runs them. Installing the 8.0
   runtime instead also works.
2. **The Blamite source.** `build.sh` clones it for you if it is missing:

       git clone --depth 1 -b dev \
         https://github.com/Jestzer/Assembly-CrossPlatform.git \
         tools/compile/.external/Assembly-CrossPlatform

   Override the location with `ACP_DIR=/path/to/checkout`. GPL-3.0; it is a dependency,
   not vendored into this repo.
3. **Python 3** only for `make_test_cache.py`, which builds a synthetic cache fixture.

Nothing else was installed on this machine for this work.

## Commands

One command does restore, build and run:

    cd tools/compile

    # driver usage
    ./build.sh --help

    # just build
    ./build.sh --build-only

    # dry run (the default) against a build string, no map needed
    ./build.sh --hsc ../../src/hsc/fe_reinforcements.hsc \
               --xml ../hsc/tables/reachmcc_u13.xml \
               --build "Jun 21 2023 15:35:31"

    # dry run against a cache, with the script objects declared
    ./build.sh --unit \
               --hsc ../../src/hsc/fe_reinforcements.hsc \
               --hsc ../../src/hsc/ff10_prototype.hsc \
               --xml ../hsc/tables/reachmcc_u13.xml \
               --map /path/to/target.map \
               --objects fe-objects.txt \
               --report /tmp/report.txt

    # commit (never the default; takes a .bak first)
    ./build.sh --unit --hsc ... --xml ... --map /path/to/target.map --write

    # synthetic cache fixture for testing the driver
    python3 make_test_cache.py /tmp/synth_u13.map --build "Jun 21 2023 15:35:31"

`--dry-run` is the default and is what you get if you say nothing. `--write` is the only
way to modify a map. Before writing it copies the target to `<map>.bak` and refuses if a
`.bak` already exists (`--overwrite-backup` to override). It also refuses unless every
input compiled, and refuses several `--hsc` files without `--unit`, because the compiler
rebuilds the whole script table from scratch and writing files in turn would leave only
the last one in the map.

## Where the scripting definition XMLs come from

They are Blamite's, under `<checkout>/src/Blamite/Formats/ReachMCC/`:
`ReachMCC_U0_Scripting.xml`, `..._U11_...`, `..._U12_...`, `..._U13_...`.
`Formats/Engines.xml` maps each MCC build string to one of them, through an `inherits`
chain — e.g. build `Jun 21 2023 15:35:31` is "Halo: Reach MCC Update 13", which names
`ReachMCC_U13_Scripting.xml`; build `Aug 11 2021 15:50:30` is "Flight 4", which inherits
"Update 3" and so gets `ReachMCC_U0_Scripting.xml`.

This repo's `tools/hsc/tables/*.xml` are **byte-identical copies** of four of them
(verified by SHA-256), kept so `tools/hsc/decompile.py` can work offline.

### The build-match guard

A scripting XML from the wrong MCC update produces bytecode that is wrong and looks
fine: 1566 of 1882 function names differ between the U0 and U13 tables, and
`campaign_metagame_award_points` is opcode `0x24E` on U0 but `0x24C` on U13. So the
driver:

1. reads the cache's build string (or takes `--build`),
2. resolves, from `Engines.xml`, which scripting XML that build is *defined* to use,
3. SHA-256s that file and the `--xml` you passed, and
4. **refuses to run, exit code 3**, if they differ.

`--allow-xml-mismatch` overrides it and says so loudly in the report. Do not use it.

## Failure modes actually hit, and the fix for each

1. **`Formats\**\*` path flattening.** `Blamite.csproj` copies the `Formats` tree with a
   Windows separator and no `<Link>`, so on macOS the whole tree is flattened into the
   output directory and `Formats/MapInfo/Engines.xml` lands on top of the real
   `Formats/Engines.xml`. The layout loader then dies with *"A(n) engine element is
   missing the required build attribute"*.
   **Fix:** `build.sh` patches the dependency's csproj in place, idempotently, to
   `Include="Formats/**/*" Link="Formats/%(RecursiveDir)%(Filename)%(Extension)"`.

2. **.NET 11 SDK vs `net8.0` projects.** `build.sh` exports
   `DOTNET_ROLL_FORWARD=LatestMajor`.

3. **`Engines.xml` database paths are relative to the process working directory.**
   Blamite's `XMLSettingsGroupLoader` opens `path` attributes with no base directory.
   **Fix:** the driver makes every command-line path absolute first, then
   `Directory.SetCurrentDirectory` to the directory that holds `Formats`.

4. **`CS0436`: Blamite declares its own `Half`, colliding with `System.Half`.**
   Suppressed in `HscCompile.csproj`. Blamite itself emits 159 warnings; none are
   platform problems.

5. **Antlr4.Runtime.Standard version must match Blamite's (4.8.0).** A different major
   version gives you parse-tree context types the compiler's listener does not accept.

6. **`The segment size is not aligned to the given alignment`** when opening a cache.
   Blamite's `FileSegmenter` requires the tag-data segment (header `virtual size`) to be
   a multiple of `tagSegmentAlignment`, default `0x10000`, and segments to be `0x1000`
   aligned. `make_test_cache.py` pads and fixes up `file_size` plus the checksum.

7. **MCC Update 13 moved two header arrays.** Blamite's
   `Formats/ReachMCC/LayoutsU13/..._Core.xml` puts `offset masks` at `0x4CC` and
   `sections` at `0x4DC`, where `LayoutsU8` has `0x4AC`/`0x4BC`.
   **This repo's `tools/map/reach_cache.py` maps every U8..U13 build onto its single
   `mcc-u8+` variant, i.e. onto the old offsets.** One of the two is wrong about real
   U13 caches, and a wrong `sections` array misplaces everything. `make_test_cache.py`
   mirrors both arrays to the U13 offsets so its fixture is readable by both tools, and
   this discrepancy is left as an open item for `tools/map`.

8. **`NullReferenceException` in `ScriptCompiler.GetTagrefExpression`** with no `--map`.
   The compiler dereferences `_cacheFile.Tags` and `_cacheFile.StringIDs`, so a map-less
   run cannot get past the first tag reference. The driver detects this and says so
   rather than blaming the script.

9. **zsh does not word-split unquoted `$vars`.** `./build.sh $args` passes one argument.
   Use an array or write the flags out.

## The cache problem

The only real Reach cache on this machine is off limits (another process owns it), so
testing used `make_test_cache.py`, which reuses the fixture builder behind
`tools/map/test_parse_map.py`. Blamite opens that fixture, matches the build string,
selects the layouts and reads the internal map name `cex_ff_halo` — but reports
`tags=0 groups=0` and a null `StringIDs`, because the fixture's tag index is not written
to the layout Blamite reads. Consequences:

* the scripting context is empty, so `--objects` is needed to resolve script objects;
* every tag reference fails;
* the first `string_id` argument throws inside `CreateSIDExpression`;
* `SaveScripts` cannot be exercised at all, since there is no `scnr` script file.

Making the fixture Blamite-readable means authoring a Blamite-shaped tag index and a
full scenario — effectively writing a cache builder. Out of scope here; the honest
position is that the write leg is untested.

## Can this compile scripts that reference script objects which do not exist in the cache?

**No. Flatly no, and this is the real boundary between macOS and Sapien.**

`ScriptCompiler` only ever *looks up* a script object. The lookup path is
`ScriptCompilerUtility.TryGetObjectFromContext` -> `ScriptingContextCollection`, and that
collection is built, read-only, by `ScriptingContextGenerator.GenerateContext`, which
reads the `scnr` (and `mdlg`) tag through the engine's `scnr_script_context` layout.
There is no "add" anywhere in that path. `Compiler/ScriptObjectCreation.cs` sounds like
the exception and is not: it builds `Script` objects, i.e. HaloScript functions, not
scenario objects. A reference the context cannot resolve is a hard
`CompilerException`: *"Failed to process the expression "X". A "Y" expression was
expected."*

So, before any of our scripts can compile against a real map, the following must
**already exist in that map's `scnr`**. The list is exactly the tag blocks in
`Formats/ReachMCC/Layouts/ReachMCC_Layouts_Scripting.xml`:

    zone_set, object_name, device_group, starting_profile, trigger_volume,
    ai_squad_group, ai_squad (+ child blocks ai_group_location, ai_single_location),
    scripting_data/point_set (+ point_set_point), cutscene_flag,
    cutscene_camera_point, cutscene_title, unit_seat_mapping, folder,
    ai_objective (+ child block ai_role), designer_zone, cinematic_lightprobe

and separately, every **tag** a script references (sounds, effects, vehicles, ...) must
be in the cache's tag index and must be named by its full path.

For this pack specifically, `fe-objects.txt` is the full list our scripts need: 2 new
squad groups, 5 new squads (plus a cell), 1 new AI objective with 3 roles, 26 new
trigger volumes, 10 named objects and 2 starting profiles. None of that can be created
by this driver. Two routes exist:

* **Sapien / Foundation on Windows** — author them, rebuild the cache. Supported.
* **Grow the `scnr` tag blocks directly** with `tools/map/reach_write.py`, whose
  `grow_tag_area` / `relocate_tag` already implement the same arithmetic as Blamite's
  `MetaAllocator`. This is the macOS-only path and it is unproven for `scnr` blocks.

The shortcut `research/11` identified still stands and is the cheapest answer: six inert
`sur_fireteam_01..06` squads already exist in every Firefight map with spawn geometry,
so *repurposing* them is same-size field patching and needs no new squads at all.

## Prioritised defect list for `src/hsc/`

From 0 syntax errors, 46 unique static findings and the compiler's own first rejection,
across all seven files, against the MCC Update 13 table.

### P0 — blocks the compiler today

1. **15 sites: `sfx_blip` used where a `sound` tag reference is expected.** LOGGED, not
   fixed. `fe_reinforcements.hsc:498,517,1025` and two sites in each of the six per-map
   files. The compiler needs the sound tag's full path out of the cache's file-name
   table (group `snd!`), optionally suffixed `.sound` — not a short placeholder name.
   Which stock sound to point at is a content decision and the path can only be read
   out of the real cache, so this is a judgement call. This is the first error the
   compiler reports on every one of the six per-map units.

2. **6 sites: calls into scripts that live in the map's own script table, not ours.**
   LOGGED. `survival_refresh_sleep` (787, 799), `survival_spartans_increment_score`
   (1123), `event_survival_spartans_win_normal` (1124),
   `survival_elites_increment_score` (1130), `event_survival_elites_win_normal` (1131).
   All six are `(script static ...)` definitions in Bungie's `global_firefight.hsc`.
   Blamite rebuilds the **entire** script table from the text it is handed, so these
   resolve only if the compile unit is the map's complete script — the map's full
   decompiled text with ours appended — not our library alone. This is a workflow
   constraint, not a typo; `--unit` exists for it. Nothing to change in `src/hsc`.

3. **`(player0)` does not exist.** FIXED, 2 sites
   (`fe_reinforcements.hsc:432,439` as it was). *"Tried to find opcode named 'player0'
   but could not."* It is absent from both the U13 table and `hsdoc_hr.txt`, although
   `global_firefight.hsc:3382-3397` calls it. Replaced with
   `(human_player_in_game_get 0)`, which returns `player` — exactly the first argument
   type `campaign_metagame_award_points` declares — and which the file's own header
   already named as the documented alternative. A note recording the verdict was added
   above `fe_charge`.

### P1 — compiles, but will not do what the comment says

4. **25 sites: `print` is a null function in Reach MCC.** LOGGED. The U13 table carries
   `<function opcode="0x028" name="print" ... null="true">`, which Blamite loads as
   `Implemented = false`. It compiles and the engine does nothing. Every
   `(if g_fe_debug (print "fe: ..."))` line is dead weight in a retail build. Removing
   them, or swapping in a visible channel, is a design decision — logged.

### P2 — dialect, a decision rather than a defect

5. **`src/hsc` is written in the Bungie/HEK source dialect, which Blamite cannot
   parse.** Handled in the driver, `src/hsc` unchanged. Two incompatible forms:

   | | HEK / Sapien, and all of `research/_raw/hsc` | Blamite `HS_Gen1` |
   |---|---|---|
   | return type | optional (`(script continuous foo`) | mandatory (`(script continuous void foo`) |
   | name + params | `(script static void (foo (long c) (ai s))` | `(script static void foo (long c, ai s)` |

   Grammar line 7 is the authority:
   `scriptDeclaration : LP SCRIPT SCRIPTTYPE VALUETYPE scriptID scriptParameters? expression+ RP`,
   and `BlamScriptDecompiler.cs:217-233` emits the second form. 69 declaration headers
   across the seven files need rewriting: 24 in `fe_reinforcements.hsc`, then 8, 8, 7,
   8, 7 and 7 in `ff10_prototype`, `ff30_waterfront`, `ff50_park`, `ff60_airview`,
   `ff60_icecave` and `ff70_holdout`.
   Rather than convert `src/hsc` and break HEK/Sapien, `Dialect.cs` normalises the
   headers in memory on every run (`--dialect auto`, the default). Both rewrites are
   confined to the declaration's own line, so **diagnostic line numbers still match the
   file on disk**. If the project ever decides Assembly is the canonical toolchain,
   `--dialect assembly` turns the rewrite off and the files can be converted once.

### Clean

No arity errors, no unknown value types, no unknown script types, no duplicate script
names, and — once `fe-objects.txt` is supplied — no unresolved script objects, in any of
the seven files. That is a real result for 1200 lines of HaloScript that had never been
compiled, but read it narrowly: the compiler stops at defect 1, so nothing past the
first `sound_impulse_start` call in `fe_reinforcements.hsc` has been seen by the
compiler's own type checker. The static lint is a companion to the compiler, not a
replacement for it.

## Files

| File | Purpose |
|---|---|
| `build.sh` | restore + build + run, one command; patches and clones the dependency |
| `HscCompile.csproj` | the driver project; `-p:BlamiteProject=` points it at Blamite |
| `Program.cs` | argument handling, build guard, compile units, dry run and write |
| `Options.cs` | command-line parsing and `--help` |
| `Dialect.cs` | HEK -> `HS_Gen1` script-declaration normaliser |
| `Linter.cs` | non-fail-fast static checks against the opcode table and the context |
| `SyntheticContext.cs` | builds a scripting context from an `--objects` manifest |
| `fe-objects.txt` | every script object `src/hsc` needs; a Sapien to-do list |
| `make_test_cache.py` | synthetic cache fixture, so no real `.map` is touched |

## Warnings worth repeating

* Assembly's own dialog says this compiler "is not 100% accurate and could corrupt the
  map in rare cases". Keep the `.bak`.
* A decompile -> recompile round trip of a stock map is known to fail until nulled
  references to culled scripts are deleted by hand.
* Growing a cache lowers `virtualBase`, and contracted pointers only survive while
  `virtualBase - growth >= 0x50000000`. Blamite has no guard for this. Check the real
  map's virtual base before relying on growth.
* MCC has no macOS build. Nothing authored here can be play-tested here.
