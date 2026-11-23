# Building a modified Halo: Reach MCC `.map` without Windows

Question: can a working, modified Reach MCC `.map` be produced on this Mac (Apple M4
Pro, macOS 26 / Darwin 25.6) without running the Windows-only Halo Reach Editing Kit?

Short answer: **yes for editing an existing `.map`, no for building one from tags.**
Nothing open-source anywhere reimplements `tool build-cache-file`, so a from-scratch
cache build still needs 343 Industries' `tool.exe` on Windows. But a *modification* of
a shipped map — new script nodes, repurposed squads, changed tag fields — can be made
entirely on macOS, and the critical piece of that toolchain was built and run on this
machine during this investigation.

The caveat that dominates every verdict below: **MCC has no macOS build**, so a map
produced here cannot be play-tested here. Windows (or a Windows VM, or MCC under
CrossOver) is needed for verification regardless of how the map is authored.

## Confidence legend

| Tag | Meaning |
|---|---|
| **TESTED** | Run on this Mac during this investigation. Commands and output recorded below. |
| **SOURCE-VERIFIED** | Read in the project's own source code or `.csproj`, with a file reference. |
| **DOCUMENTED** | Stated in vendor or project documentation. |
| **REPORTED** | A forum post, issue comment or video. Not verified. |
| **UNTESTED** | Inferred from the above. Nobody has demonstrated it. |

## Ranked verdicts

| # | Route | Verdict | One-line reason |
|---|---|---|---|
| 1 | Borrow or rent Windows for an hour | **Viable** | Officially supported, ~$1–3 on EC2, and Windows is needed to play-test anyway |
| 2 | Subscribe to an existing mod that already does this | **Viable** | "Halo Reach: Evolved" already sells ODST/Marine reinforcements on both target maps |
| 3 | Blamite (Assembly's library) on macOS via .NET 8 | **Partly viable — best technical route** | Builds and opens a Reach MCC cache on this Mac (TESTED); carries the Reach script compiler and the tag-data allocator |
| 4 | Pure-Python binary patching with `tools/map/reach_write.py` | **Partly viable** | Write-back, growth and relocation already implemented and self-tested; no HaloScript *compiler* |
| 5 | `tool.exe` under Wine/CrossOver on Apple Silicon | **Partly viable, untested anywhere on macOS** | Works under Wine on x86 Linux; zero macOS reports; Rosetta ends after macOS 27 |
| 6 | Windows 11 ARM VM + Prism x64 emulation | **Partly viable** | Free with UTM or VMware Fusion, but it is route 1 with extra steps |
| 7 | Mac-native loose-tag editing (`blam-tags`, Baboon) | **Partly viable, useless alone** | Byte-exact Reach tag editing on macOS, but no cache builder |
| 8 | Project Reclaimer Kit on macOS | **Partly viable for prototyping only** | Edits Reach Firefight squads and HaloScript natively; will not compile them, and output plays only in Reclaimer |
| 9 | GitHub Actions `windows-latest` running `tool.exe` | **Mostly dead** | Ownership-gated depot, 14 GB runner disk vs a 7 GB depot, EULA exposure |
| 10 | TagTool, Invader, Blamite Engine, ManagedBlam off Windows | **Dead** | Gen3 cache serialization is `NotImplementedException`; Invader is Halo CE only; ManagedBlam is mixed-mode x64 Windows |

---

## 1. Binary patching an existing `.map` — the main event

### 1.1 What was already in place

`tools/map/reach_cache.py` reads the cache. `tools/map/reach_write.py` (568 lines,
already present, written before this investigation) writes it. Its self-test passes on
this Mac:

```
$ cd tools/map && python3 test_reach_write.py
387 assertions, 0 failures
```
**TESTED.** The writer already implements, against synthetic caches for all four header
variants (`mcc-u8+`, `mcc-u3`, `mcc-2019`, `xbox360`):

- full re-encode of every parsed field with a byte-identical round-trip gate;
- the header checksum (XOR of every little-endian `uint32` from `0xA000` to EOF) —
  independently confirmed below to be exactly what Assembly computes;
- same-size in-place patching of bytes inside a tag;
- `grow_tag_area()` — insert pages, then fix up `virtual size`, section virtual
  addresses, offset masks, partitions and `file size`;
- `relocate_tag()` / `relocate_table()` — move a tag or an index table into new space
  and fix every count and pointer that the move invalidates, including contracted
  pointers and pointers internal to the moved blob.

One defect found: run under `pytest` from the repo root, `test_reach_write.py` errors
with `fixture 'variant' not found`, because its test functions take a plain `variant`
argument. Run as a script it is fine. Worth renaming the helpers so CI can collect it.

### 1.2 Is there editable slack in a shipped map?

**No usable slack, and Assembly does not look for any.** Its `MetaAllocator`
(`src/Blamite/Blam/Util/MetaAllocator.cs`) starts each session with two **empty** free
lists; free areas exist only because something was freed during that same session, and
nothing is persisted between sessions. **SOURCE-VERIFIED.** So "find the padding and
write there" is not a strategy — the strategy is free-then-reallocate, and failing
that, grow the file.

### 1.3 Does a checksum have to be recomputed, and does MCC care?

- Algorithm: XOR of every little-endian `uint32` from `HeaderSize` (0xA000) to EOF,
  tail zero-padded (`Blamite/Blam/ICacheFile.cs`, `GenerateChecksum`); written at
  header `0x360` for the U8+ layout. **SOURCE-VERIFIED**, and matches what
  `reach_write.py` already computes.
- There is no signature, no per-tag hash, and no hash covering the tag data area. The
  only SHA-1s in a Reach cache are the two per-language locale hashes and the resource
  page hashes, none of which cover tag data.
- Assembly's maintainer (Lord-Zedd, issue #368, 2025-03-03): *"Checksums are updated
  but that doesn't matter in MCC."* **REPORTED**, consistent with the absence of any
  verification field in the format.

### 1.4 Does MCC validate map integrity at load?

- The documented requirement is not a checksum but **anti-cheat**: Halo Waypoint's
  "MCC Modtacular" posts say to *"ensure that you have anti-cheat disabled, which can
  be selected upon launching MCC from your Steam library"* — the launch entry named
  **"Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)"**. **DOCUMENTED.**
  `INSTALL.md` in this project already tells the user to launch that way.
- With EAC on, modified files are reported as a file conflict and features are blocked.
  **REPORTED.**
- No evidence was found that MCC checks map file size or content hashes with EAC off.
  Assembly's tag injection grows map files routinely and those maps are played.
  **UNTESTED but well-precedented.**

### 1.5 Assembly's recompiler, and whether it is portable

Assembly's HaloScript compiler exists and covers Reach MCC:

- grammar `src/Blamite/Blam/Scripting/ANTLR/HS_Gen1.g4`; compiler
  `src/Blamite/Blam/Scripting/Compiler/ScriptCompiler.cs` (~1130 lines) plus
  `ScriptCompilerUtility.cs`, `ScriptCompilerTypeHandling.cs`;
- compiling is enabled when the engine name contains "Reach" or "Halo 3"
  (`ScriptEditor.xaml.cs:107`); on save, `ScnrScriptFile.cs:271-283` selects
  `ScriptLayout.HaloReach` and throws `NotImplementedException` for anything else;
- it **rebuilds every script table from scratch**, so adding new scripts, new globals
  and new expressions is supported. Expression datums start at index 0 with salt
  `0xE373` (`SaltGenerator.GetSalt("script node")`) and increment per node.
  **SOURCE-VERIFIED.**

Limits to respect:

- It can only *reference* names that already exist in the scenario's blocks
  (`ai_squad`, `object_name`, `trigger_volume`, `zone_set`, …). **Adding a squad is a
  separate operation** — growing the `scnr` Squads tag block through the allocator.
- The opcode XML must match the map's MCC update (`ReachMCC_U0/U11/U12/U13_Scripting.xml`
  selected by build string in `Formats/Engines.xml`). A mismatch silently produces
  wrong opcodes.
- A decompile → recompile round trip of a stock map fails until nulled references to
  culled scripts are deleted by hand (the compiler emits "…may actually be a culled
  script").
- Assembly's own dialog warns the compiler "is not 100% accurate and could corrupt the
  map in rare cases."

Where the data lives, for anyone reimplementing this (scenario layout
`Formats/ReachMCC/Layouts/ReachMCC_Layouts_Scenario.xml`; U3/U8/U10/U13 inherit it).
Each table is a **separate allocation in the tag data area**; `scnr` holds only counts
and contracted 32-bit pointers:

| Table | count @ | address @ | element size |
|---|---|---|---|
| string table | 0x43C (size) | 0x448 | bytes |
| scripts | 0x450 | 0x454 | 0x18 |
| globals | 0x45C | 0x460 | 0x28 |
| tag references | 0x468 | 0x46C | 0x10 |
| expressions | 0x524 | 0x528 | 0x18 |

Script parameters are 0x24 bytes, in blocks deduplicated by sequence hash.

Save order (`ScnrScriptFile.SaveScripts`, lines 71-96): expressions, strings, globals,
tag references, then parameters and scripts; each through
`allocator.Reallocate(old, oldSize, newSize)` or `Allocate`; then the new counts and
contracted pointers are written into `scnr`; then `cache.SaveChanges`.

The allocator, in enough detail to reimplement (`MetaAllocator.cs`, page 0x10000):

1. `Allocate` does a best-fit search of the free list; with `align > 4` it refuses
   blocks inside partitions 1 and 5 (read-only); on failure it calls `Expand`.
2. `Reallocate` shrinks by freeing and zeroing the tail; grows in place if a free area
   starts exactly at `addr + oldSize`; otherwise frees the old block (which merges with
   neighbours, so the new block often lands at the same address), allocates, copies,
   and zeroes the old range. Zeroing shared blocks is a known bug (issue #343).
3. `Expand` rounds up to 0x10000, resizes the meta segment with
   `SegmentResizeOrigin.Beginning`, which **inserts zero bytes at the segment's start
   file offset** and shifts every later segment, then **lowers `virtualBase` by the
   delta** so existing pointers stay valid.
4. On save, `ThirdGenHeader.Serialize` rewrites partitions (partition[0].load = new
   meta base, sizes recomputed back-to-front), then sections in the order
   resource → locale → tag → debug, then the offset masks (`segment file offset −
   section va`), `virtual base`, `virtual size`, `tag buffer offset`, `file size`, the
   string-ID and file-name offsets, and finally the checksum.

**SOURCE-VERIFIED.** This is the same arithmetic `reach_write.grow_tag_area()` already
implements, which is a useful cross-check on both.

One unresolved risk: growth lowers `virtualBase`, and contracted pointers only survive
while `virtualBase − growth >= 0x50000000`. Assembly has no guard for this. Check the
real map's virtual base before relying on growth.

### 1.6 The shortcut nobody expected: we may not need to add squads at all

From this project's own `research/11-stock-map-spawn-geography.md`: `cex_ff_halo`
(Installation 04) is the one stock Firefight map that already ships friendly Marines
(`gr_survival_marines`, `sq_marines_01`), and every Firefight map carries **six
pre-existing, currently inert squad definitions** (`sur_fireteam_01`–`06`) that already
have spawn geometry and are already named in the script.

If reinforcements are built by *repurposing* those — swapping a character palette index
and reparenting a squad group — then the squad work is a set of **same-size field
patches**, which `reach_write.patch_tag_field()` already does, and no tag block has to
grow at all. Only the script tables need to grow. That is a much smaller problem than
"inject new squads".

This is corroborated from the other direction: the "Original Installation 04 Fire
Fight" Workshop mod restores *existing* ODST squads 01/02, and NukeTimeStories'
2019 tutorial added ODSTs to Installation 04 **with Assembly alone, no `tool.exe`**
(https://www.youtube.com/watch?v=EKxtydRhCTc, mod at
nexusmods.com/halothemasterchiefcollection/mods/93). Those maps are stale against
current MCC builds, but they prove the technique.

### Verdict on angle 1: **partly viable, and the most promising technical route.**
Write-back is mechanically solved and self-tested; the checksum is understood and
probably irrelevant; MCC does not verify map integrity with EAC off. The missing piece
is a HaloScript *compiler*, and the cheapest way to get one is not to write it — see
section 2.

---

## 2. Blamite on macOS: the tested result

The find: **`Jestzer/Assembly-CrossPlatform`** (GPL-3.0, branch `dev`, last push
2026-03-03) is an Avalonia port of Assembly in which `src/Blamite` has been converted
to an SDK-style project targeting **`net8.0`**, with Windows-only dependencies moved
behind `Condition="$([MSBuild]::IsOSPlatform('Windows'))"` and a `WINDOWS` compile
constant (`src/Directory.Build.props`). The port still contains
`Blam/Scripting/Compiler/ScriptCompiler.cs`, `Blam/Scripting/ScnrScriptFile.cs` and
`Blam/Util/MetaAllocator.cs`. **SOURCE-VERIFIED.**

Its published releases are Windows and Linux only — there is no macOS download — so
this was built from source here:

```
$ brew install dotnet                      # .NET SDK 11.0.100
$ git clone --depth 1 -b dev https://github.com/Jestzer/Assembly-CrossPlatform.git
$ dotnet build src/Blamite/Blamite.csproj -c Release
    159 Warning(s)
    0 Error(s)
Time Elapsed 00:00:04.36
```

**TESTED. Blamite compiles cleanly on macOS arm64.** The warnings are a local `Half`
type shadowing `System.Half` and unused variables; none are platform problems.

A ~45-line console driver (`/tmp/acp_test/probe`) was then written against it and run
against a synthetic `mcc-u8+` cache generated by this project's own
`test_parse_map.build_cache()` (padded to the 0x1000 segment alignment Blamite
enforces, with `file_size` and `checksum` fixed up by `reach_write.py`):

```
formats dir: .../src/Blamite/Formats
engines loaded: (ok)                    # 255 engine definitions
OPENED. engine=ThirdGeneration build=Aug 11 2021 15:50:30 tags=0 groups=0 scenario=cex_ff_halo
ANTLR HS_Gen1 parse ok, children=1
public types reachable from an external driver: ScriptCompiler, ScnrScriptFile, MetaAllocator, BlamScriptDecompiler
```

**TESTED.** On this Mac, natively, Blamite matched the Reach MCC build string, selected
the U8+ header layout, read the header through it (including the internal map name
`cex_ff_halo`), ran the Reach HaloScript ANTLR front end, and exposed the compiler,
the scenario script-file class, the allocator and the decompiler as public types a
driver can call. `tags=0 groups=0` is an artefact of the synthetic fixture's minimal
tag index, not a Blamite failure.

Two friction points found and worth recording:

1. The Homebrew SDK is .NET 11 and the projects target `net8.0`; run with
   `DOTNET_ROLL_FORWARD=LatestMajor` or install the 8.0 runtime.
2. `Blamite.csproj` copies `Formats\**\*` with a backslash and no `Link`, so on macOS
   the whole `Formats` tree is **flattened** into the output directory and
   `Formats/MapInfo/Engines.xml` overwrites the real `Formats/Engines.xml`. The layout
   loader then fails with *"A(n) engine element is missing the required build
   attribute"*. Workaround used: run with the working directory set to
   `src/Blamite` and pass the source `Formats` path. A one-line csproj fix
   (`<Link>Formats\%(RecursiveDir)%(Filename)%(Extension)</Link>`) would solve it
   properly.

The Avalonia GUI is **not** the useful part: its views are Welcome, HaloMap,
MetaEditor, BitmapPreview, MapCompressor and MemoryPoker — there is **no script editor**,
and the block reallocate/allocate commands present in the upstream WPF
`MetaEditor.xaml.cs:1058-1253` have no equivalent in the port (only tooltip strings
survive). **SOURCE-VERIFIED.** So the GUI cannot compile scripts or grow a tag block.

**What this means.** The driver that is actually needed is about 60 lines of C#,
modelled directly on `ScriptEditor.xaml.cs:406-440`:

```
ICharStream  stream   = CharStreams.fromstring(hscText);
var          lexer    = new HS_Gen1Lexer(stream);
var          parser   = new HS_Gen1Parser(new CommonTokenStream(lexer)) { BuildParseTree = true };
IParseTree   tree     = parser.hsc();
var          context  = scriptFile.LoadContext(reader, cache);
var          compiler = new ScriptCompiler(cache, buildInfo, opcodes, context, progress, logger, debug);
ParseTreeWalker.Default.Walk(compiler, tree);
scriptFile.SaveScripts(compiler.Result(), stream, progress);
```

That is far less work than porting ~1,500 lines of C# compiler to Python, and it runs
on this Mac today. It also means `tools/hsc/decompile.py` has a native cross-check:
`BlamScriptDecompiler` is reachable from the same driver.

### Verdict on angle 2 (cross-platform toolchains): **one hit, the rest dead.**

| Tool | Reach? | Can it write/build? | Platform | Evidence |
|---|---|---|---|---|
| **Blamite (Assembly-CrossPlatform fork)** | Yes, through Toolset U3 (Jul 2023) | Edits an existing `.map`; compiles Reach scripts into it; grows the file. **Cannot build from tags.** | **macOS arm64 — TESTED** | built and run here |
| Assembly (upstream, XboxChaos) | Yes | Same capability | Windows only: WPF `WinExe` on .NET Framework 4.8. PR #375 "multiplatform ui" was a joke, closed unmerged | SOURCE-VERIFIED |
| TagTool (TheGuardians) | Read only | **No.** `Cache/Gen3/GameCacheGen3.cs:180-183` is `throw new NotImplementedException()`; `SaveStrings`, `TagCacheGen3.AllocateTag` likewise. Reach scripts are *deleted* when porting (`PortingContextGen3.Reach.cs:97-98`) | `net8.0-windows`, P/Invokes `kernel32`, `xcompress`, `D3DCompiler_47`, `fmod` | SOURCE-VERIFIED |
| Invader | No — Halo CE only | Builds CE caches | Linux/macOS via CMake | DOCUMENTED |
| Blamite *Engine* (Elaztek) | Unrelated hobby game engine | n/a | n/a | DOCUMENTED |
| Foundation (HREK) | Yes | Tag editor, needs ManagedBlam | Windows WPF; runs under wine-staging 11 with `dotnet35sp1 dotnet48` on x86 Linux | REPORTED |
| ManagedBlam.dll | Yes | Loose tags | **Mixed-mode C++/CLI, x64, .NET Framework 4.8** — Mono and .NET Core cannot host it; needs non-high-entropy ASLR | DOCUMENTED |
| Osoyoos launcher | Yes | Shells out to `tool.exe` | `net8.0-windows`, WPF | SOURCE-VERIFIED |
| `blam-tags` (camden-smallwood, Rust) | Yes — claims byte-exact round-trip across every Reach MCC tag | **Loose tag files only. No cache builder, no script compiler** | Cross-platform `cargo build`, macOS documented | DOCUMENTED |
| Baboon (Zoephie, Rust GUI on blam-tags) | Yes (`haloreach_mcc`) | Guerilla-style loose-tag editor; launches the kit's exes to compile | **Ships `baboon-macos-aarch64.tar.gz`** (release `dev`, 2026-11-20, 35 MB) — verified present via the GitHub API, not downloaded or run | DOCUMENTED |
| Reclaimer (Gravemind2401) | Yes | Read/export only | `net10.0-windows` | SOURCE-VERIFIED |
| Project Reclaimer Kit | Yes | Reach Firefight maps "open and edit" but **do not compile**; only Reach MP compiles; output plays in Reclaimer, not MCC | macOS native | DOCUMENTED |

**There is no open-source reimplementation of `tool build-cache-file` for any Gen3
game.** Searches of GitHub repos, code and issues found none; `landaire/hsc` (D, 2016)
is an abandoned stub. The only open cache builder in existence is Invader, for Halo CE.

---

## 3. Running HR-EK on macOS

State of this machine, **TESTED**: no `wine`, `wine64`, `crossover`, `dotnet` (before
this session), `mono`, `msbuild`, Steam, Parallels, VMware, UTM or Whisky. `uname -m`
is `arm64`, CPU "Apple M4 Pro", and the Rosetta daemon `oahd` is running.

### Wine options in 2026

- Homebrew's `wine-stable`, `wine@staging` and `wine@devel` casks were **disabled on
  2026-09-01** (`fails_gatekeeper_check`). `brew install` no longer works. **DOCUMENTED.**
- Builds continue at `github.com/Gcenx/macOS_Wine_builds` (11.21, 2026-10-31). They are
  **x86_64 only** (`--enable-archs=i386,x86_64`), i.e. Rosetta 2. Install by untarring
  to `/Applications` and clearing the quarantine xattr. **DOCUMENTED.**
- Whisky is archived (last push May 2025) and its cask deprecated as unmaintained.
  Kegworks continues as Sikarugir.
- CrossOver 26.3 wraps the same x86_64 Wine under Rosetta; $74/year with a full
  two-week trial. A CrossOver *Preview* with native ARM64 Wine plus a FEX x86-64
  emulator exists (macOS 26.5+), but CodeWeavers says it is "not expected to be useful
  for anything beyond testing". **DOCUMENTED.**
- Apple's Game Porting Toolkit is a Wine build plus D3DMetal; irrelevant to a CLI tool.
- **Rosetta 2 deprecation**, from Apple's developer documentation: available "through
  macOS 27 — as a general-purpose tool for Intel apps", after which only a gaming
  subset remains. So this route has roughly a two-release shelf life.

### Has `tool.exe` ever worked under Wine?

The evidence is good on x86 Linux and **completely absent on macOS**:

- **HREK `tool.exe` runs under Wine on Linux.** Baboon issues #66 and #67 (2026-09)
  show `WINEPREFIX=… wine "$HREK/tool.exe" tag-file-report …` and `… render …`
  loading tags and writing `reports/debug.txt`; the failures reported were engine
  asserts about content, not Wine. **REPORTED, but from bug reports with command lines.**
- **A full `build-cache-file` under headless Wine exists — for H2EK, not Reach.**
  `TheRunaway5/Halo-2-Decompiled`, `tools/build_deserted_native.py` runs
  `wine tool_fast.exe -batch` with `DISPLAY` unset through bitmaps,
  `structure-new-from-ass`, lightmaps and `build-cache-file … win64`, asserting
  `returncode == 0` at every stage, with `WINEDLLOVERRIDES=mscoree,mshtml=d` (no .NET
  at all). **SOURCE-VERIFIED code, not a user report.**
- Proton issue #6235 (HREK, AppID 1695793) covers Foundation, Sapien, Tag Test and
  MegaloEdit. Foundation was broken until 2026-08-29, when it was reported working on
  wine-staging 11 with `winetricks dotnet35sp1 dotnet48`. **`tool.exe` is never
  mentioned in the thread.**
- c20's wiki documents a Wine command line only for the 32-bit Halo CE HEK. There is no
  Linux or Wine page for H2EK, H3EK or HREK.
- **No report of any Halo editing kit on macOS, CrossOver, Apple Silicon or a Steam
  Deck was found.** Absence of reports is weak evidence, not proof.

An important correction to the premise: `tool.exe` is a **native C++ program**.
ManagedBlam and .NET 4.8 are needed by Foundation and by scripted tag edits, not by
`tool`. The mixed-mode .NET problem therefore does not block this route.

The Mac-specific risk that nobody has tested: the Gen3 engine packs 64-bit pointers
into 32 bits and only works within ~16 GB of the executable base — the reason
ManagedBlam needs `/HIGHENTROPYVA:NO`. Wine on Linux evidently lays memory out
acceptably; Wine on macOS under Rosetta has a different address-space layout. A crash
in `cseries\port_64.h` would be the signature of this failing. **UNTESTED.**

### Getting the kit onto a Mac at all

HREK requires **owning Halo Reach** (Steam `mustownapptopurchase: 976730`), so
anonymous SteamCMD cannot fetch it. **DOCUMENTED.** The depot (1701260) is ~7.04 GB
download / 7.14 GB installed, plus a `.7z` of tags the installer unpacks. With an
owning account, the files can be pulled onto macOS without Wine:

```
steamcmd +@sSteamCmdForcePlatformType windows +login <user> +app_update 1695793 validate +quit
# or DepotDownloader (osx-arm64 build): -app 1695793 -depot 1701260
```
Then extract the `.7z` natively with `7zz` rather than running the `.bat`. **UNTESTED**
but mechanically ordinary. The same trick (`ForcePlatformType windows` on app 976730)
is also how a stock `cex_ff_halo.map` could be obtained on this Mac for route 1 —
currently there is **no `.map` file anywhere on this machine** (verified by a
filesystem search), which is the single biggest gap in the whole plan.

### Verdict on angle 3: **partly viable, worth a bounded experiment, do not bet on it.**
A reasonable test order, each step cheap: Gcenx wine-staging 11.21 in a fresh 64-bit
prefix with `winetricks vcrun2019 d3dcompiler_47 msxml3`; `wine tool.exe` for usage
output; then `tag-file-report`; then `build-cache-file`. If that fails, the CrossOver
trial. Cap the effort at a couple of hours — the H2EK precedent is encouraging but the
Apple Silicon pointer-layout risk is real and unexamined.

---

## 4. Editing tags without Sapien

Feasible, and partly solved by other people already:

- **`blam-tags`** (Rust, cross-platform, active to 2026-11-17) claims byte-exact
  read/write round-trip across every Halo Reach MCC tag, has a CLI
  (`blam-tag-shell`), Python bindings, and documents macOS build configuration. It has
  **no license file**, so reusing its code is legally unclear even though using the
  tool is fine.
- **Baboon** is a Guerilla/Foundation-style GUI on top of it and **ships a macOS arm64
  binary** (asset verified via the GitHub API; not downloaded or run here).
- Hand-editing is also tractable with this project's own tools: the squad block and
  character palette offsets are known (`scnr` Squad Groups 0x3A0/0x28, Squads
  0x3AC/0x6C, Character Palette 0x400/0x10 from the Xbox 360 plugin; MCC field order
  from `research/_raw/reach-defs/*.json`).

**What must be recompiled versus patched.** This is the crux:

- Edits to a **loose tag** (`.scenario` in the HREK tags tree) require
  `tool build-cache-file` afterwards — Windows, or Wine at best.
- Edits to a **built cache** require no compiler at all for data fields, and only
  Blamite's script compiler for new script nodes. Same-size field edits (character
  palette index, squad group parent, squad flags, spawn counts) are pure byte patches
  that `reach_write.patch_tag_field()` already performs.

So the honest framing is: editing tags on macOS is easy and useless on its own;
editing the *cache* on macOS is harder and sufficient. **Route 1/2 dominates route 4.**

### Verdict on angle 4: **partly viable — necessary only if the loose-tag route is taken, which requires Windows anyway.**

---

## 5. Pre-built mod resources

**The feature already exists, shipped, by someone else.**

- **"Halo Reach: Evolved Public Beta"** by The Vengeful 'Vadam, Steam Workshop
  `3453792163` (7.3 GB, posted 2025-03-28, updated 2026-03). On **Installation 04** you
  start with a Marine squad and can **buy ODST reinforcements**, an auto turret, a
  Falcon gunner and hacked Sentinels. On **Unearthed** you drop in with ODSTs and can
  **buy Marine reinforcements**, a turret, a Warthog and a Scorpion. Corvette is
  included. Friendly-AI work credited to King Feraligatr. It requires separate
  "Firefight Evolved" gametypes distributed via OneDrive. **Compiled `.map` only — no
  tags, no permissions statement.**
- Also relevant: "Installation 04: The Last Stand" (`3639410660`) adds 30 ODSTs plus a
  per-round ally respawn script; "Original Installation 04 Fire Fight" (`2925564858`)
  restores the stock ODST squads 01/02; deadkiva7's pack adds friendly AI across 14
  maps including Unearthed (Night).
- **Tags that are published**: King Feraligatr's *Enhanced Reach Friendly AI*
  (nexusmods 2076) is an explicit modder's resource with ODST/Trooper/Marine/"reviver"
  **character** tags — no scenario, no squads. Its Nexus permissions require asking the
  author before modifying or redistributing.
- **Script sources that are published**: `KSIEdge/HaloReachScripts` has
  `cex_ff_halo_main.hsc`, `ff_unearthed_mission.hsc` and `global_firefight.hsc` plus
  Phantom-drop and squad-drop snippets. `ILoveAGoodCrisp/HaloReachScenarios` (GPL-3.0)
  has Blender BSPs for both target maps but **no scenario tags**.
- **No repo anywhere ships a Reach `.scenario` with squads, and no bot or service
  compiles maps on request.** Checked GitHub, Nexus, ModDB and the Workshop.
- Live communities: Halo Modding Reclaimers Discord (discord.reclaimers.net, c20's
  home), the Halo Mods Discord, King Feraligatr's and NukeTimeStories' servers.

### Verdict on angle 5: **viable, and the cheapest path to *playing* the feature.**
Two concrete actions worth more than any amount of binary patching: subscribe to
Vadam's mod and see whether it already is what the user wants; and ask Vadam (Workshop
thread, Halo Mods Discord, or X) whether he will share the Evolved Firefight scenario
tags or bless a derivative. If he says yes, the project's remaining work collapses.

---

## 6. A hosted or remote build

- **GitHub Actions `windows-latest`** fails on three independent counts: the HREK depot
  is ownership-gated so SteamCMD needs a real logged-in account (Steam Guard workable
  via the `STEAM_CONFIG_VDF` trick that `game-ci/steam-deploy` documents, or a TOTP
  shared secret, both unpleasant); the standard runner guarantees only **14 GB** of
  SSD against a 7 GB depot plus extraction; and caching or uploading HREK files or
  stock tags as artifacts would be redistribution under the mod-tools EULA. Larger
  runners cost $0.022/min. No HREK CI, Docker or headless precedent was found.
  **Mostly dead.**
- `tool build-cache-file` itself is a console program and the H2EK precedent ran it
  with no display, so "headless" is not the obstacle — provisioning and licensing are.
- **Cloud Windows that actually works**: an EC2 Windows instance (t3.xlarge ≈
  $0.19/hr, m6i.xlarge ≈ $0.38/hr, plus ~100 GB gp3), RDP in, install Steam or
  SteamCMD normally. One to three hours is roughly $1–3. Use a personal AWS account,
  never a corporate or production one, and delete the instance and its volume
  afterwards. Shadow PC is a full Windows desktop on a monthly subscription.
  GeForce Now cannot install arbitrary software and is useless here.
- **Windows 11 on ARM in a VM on this Mac**: Microsoft publishes an official Arm64 ISO
  explicitly for creating VMs; UTM is free and VMware Fusion has been free for all use
  since 2024-11-11. Windows 11 24H2's **Prism** emulates x64 user-mode code (with AVX
  and AVX2 since Insider build 27744), so an x64 console app like `tool.exe` should
  run. Needs ~64 GB plus the kit, runs unactivated with a watermark, and no Halo kit
  has ever been reported running this way. Sapien would additionally need the 3D
  acceleration that Parallels has and UTM does not. **Partly viable, untested.**

### Verdict on angle 6: **CI is mostly dead; a rented or virtual Windows box is just angle 7 with extra steps.**

---

## 7. The cheapest workaround of all

**Borrow Windows for an hour. Ranked first.** The reasoning, honestly:

1. It is the only route that is *officially supported*. HREK on Windows is the
   documented pipeline, with c20's guides, Osoyoos, Foundation and Sapien behind it.
2. **It is needed anyway.** MCC has no macOS build, so the modified map cannot be
   play-tested on this Mac no matter how it is authored. (MCC under CrossOver with EAC
   disabled is plausible and untested; it is not a plan.) Every technical workaround
   above still ends with "now find a Windows machine to see if it loads."
3. The cost is one to three dollars on EC2, or zero on a friend's PC, against an
   open-ended number of hours for the Wine, Prism and CI routes — each of which has at
   least one documented unknown that could sink it.
4. The project's own `INSTALL.md` already assumes this ("**for** when you get to a
   Windows PC"), and `src/hsc/README.md` already carries the 13-step HR-EK build.

The one qualification: a Windows hour spent compiling does not *build the knowledge*
that the macOS toolchain does. If the goal is iterate-and-tune on Firefight scripts
over weeks, paying once to stand up the Blamite driver (section 2) is a better
investment than renting an hour repeatedly. If the goal is "play purchasable ODSTs this
weekend", subscribe to Vadam's mod (section 5) on any Windows PC and stop.

---

## What to do next, in order

1. **Decide the actual goal.** Play the feature → Vadam's mod on a Windows PC, done.
   Author our own → continue.
2. **Get a stock `cex_ff_halo.map`.** Nothing on this Mac can be tested without one.
   `steamcmd +@sSteamCmdForcePlatformType windows +app_update 976730` with an owning
   account, or copy it off a Windows install. This is the current blocker on *every*
   technical route.
3. **Point the existing tools at it.** `parse_map.py --extract` and
   `tools/hsc/decompile.py`, then re-run `reach_write.py`'s round-trip gate against a
   real file. That converts the whole of `research/07` and `research/08` from
   SPEC-CITED to verified, and it costs nothing.
4. **Build the Blamite driver** (~60 lines of C#, section 2) and compile
   `src/hsc/fe_reinforcements.hsc` into a copy of the real map on this Mac. Fix the
   `Formats` flattening bug while there.
5. **In parallel, ask Vadam** about the Evolved tags. Cheap, and potentially saves
   everything.
6. **Only then** spend money or hours: one EC2 Windows hour to verify the map loads,
   which doubles as the HR-EK fallback if step 4 fails.

## Honest summary of what is and is not proven

Proven on this machine: Blamite builds and opens a Reach MCC cache natively on macOS
arm64 and exposes the Reach script compiler, the allocator and the decompiler;
`reach_write.py` passes 387 self-test assertions covering growth, relocation and the
checksum; the checksum algorithm matches Assembly's.

Not proven by anyone, anywhere: that a macOS-authored Reach `.map` loads in MCC; that
`tool.exe` runs under Wine on Apple Silicon; that growing the tag area keeps the
virtual base above `0x50000000` on a real map; that Assembly's Reach script compiler
round-trips a 2026-era MCC build without hand-editing culled references.

Flatly false as a hope: that any cross-platform tool can build a Reach cache from
tags. That capability does not exist outside `tool.exe`.
