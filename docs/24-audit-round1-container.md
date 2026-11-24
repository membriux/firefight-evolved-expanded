# 24 — Audit round 1: container and structural

Adversarial, independent audit of the nine shipped map caches in
`ready-to-install/`, plus the copies in `ready-to-install/MOD-PACKAGE/`.

**Date:** 2026-11-23
**Scope:** container and structural only. Gameplay behaviour, Megalo semantics and
script *meaning* are explicitly out of scope except where noted as a risk.
**Access:** read-only throughout. No file under `~/Desktop/Halo-Firefight` was
modified except this document.

## 0. Headline

No BLOCKER was found. All nine shipped caches are structurally well-formed under
rules derived independently from Assembly/Blamite source and cross-checked against
TagTool, and all nine are byte-identical to their `MOD-PACKAGE` copies.

Six RISK items and two COSMETIC items are recorded below, together with four
places where this project's own documentation is wrong or silently incomplete.

## 1. How the audit was made independent

The brief required not re-running this project's own tooling. The following were
built fresh for this audit and share no code with `project/`:

1. **A from-scratch Python header reader** (`/tmp/halo_audit/hdr.py`,
   `audit.py`). Field offsets were transcribed by hand from
   `Assembly-CrossPlatform/src/Blamite/Formats/ReachMCC/LayoutsU13/ReachMCC_LayoutsU13_Core.xml`
   (`<layout for="header" size="0xA000">`), and the pointer rules were derived by
   reading `ThirdGenHeader.cs`, `BasedPointerConverter.cs` and
   `ThirdGenPointerExpander.cs` rather than from any project document.

   Derived rules used, with their source:

   - Section file offset = `section.virtualAddress + offsetMask` (mod 2^32).
     From `BasedPointerConverter(basePointer, basePointer + mask)` and
     `PointerToOffset(p) = p - base + defaultStartOffset`.
   - Tag-area pointer to file offset = `p - virtualBaseAddress + tagSectionFileOffset`
     (`MetaAddressConverter`, `ThirdGenHeader.Load`).
   - Compressed (32-bit) tag pointers expand as `(p << 2) + 0x50000000`
     (`ThirdGenPointerExpander.Expand`, with `expandMagic` taken from the
     `Halo: Reach MCC Update 3` engine block in `Engines.xml`, line 984).
   - `HeaderSize` = `0xA000`, the `size` attribute of the header layout.
   - Canonical section virtual addresses, as Assembly itself would write them on
     save (`ThirdGenHeader.RebuildInteropData`): resource VA is left alone;
     `locale = rsrc.va + rsrc.size`; `tag = locale + locale.size`;
     `debug = tag + tag.size`, minus `Partitions[0].Size` if the debug mask was
     non-zero on load.

2. **A from-scratch checksum implementation** (`/tmp/halo_audit/cksum.py`), a pure
   XOR of every little-endian `uint32` from `0xA000` to EOF with the tail
   zero-padded to a 4-byte boundary, derived by reading
   `CacheFileExtensions.GenerateChecksum` in `Blam/ICacheFile.cs:229`.
   `reverseChecksum` is **false** for every Reach MCC engine (the only
   `<reverseChecksum>true</reverseChecksum>` in `Engines.xml` is at line 443,
   an alpha/beta Halo 3 build).

3. **A new C# driver against Blamite itself** (`/tmp/halo_audit/val/Program.cs`,
   built against `Blamite.csproj`, deliberately not the project's existing
   `/tmp/acp_test/probe`). It opens each cache through
   `CacheFileLoader.LoadCacheFile` and then forces every structured reader to
   run: all tags and their meta locations, the tag-name table, the string-ID
   table, all twelve language packs with every string read, the scenario script
   table, the resource table and page table, the simulation definitions, the tag
   interop table and the sound gestalt. Any thrown exception or out-of-range
   result is counted as a problem.

4. **TagTool as a second, unrelated authority.**
   `TheGuardians-CI/TagTool`, `TagTool/Cache/MCC/CacheFileHeaderMCC.cs`. This is
   the only source consulted that documents the region between the checksum and
   the section table, and it is the origin of finding R1 and doc finding D1.

5. **c20.reclaimers.net was checked and is not usable here.** The page index
   lists `/hr/map` ("HR map cache file"), but the page is a stub: the cloned
   source (`Sigmmma/c20`, `src/content/hr/map/readme.md`) is 80 bytes of front
   matter with no body, and `src/data/workflows/hr/map.yml` contains only a page
   reference. c20 documents Reach *tag* names, not the cache container. Our
   `07-map-container-format.md` already says exactly this, and it is right.

Independence cross-check: the from-scratch checksum reproduces the stored
checksum of all **nine stock retail files**, including `ff45_corvette.map`,
which was never touched by this project. An implementation that matches nine
untouched 343-shipped files is reproducing the real algorithm, not our
assumptions about it.

## 2. Agreement between the two external authorities

TagTool and Assembly were compared on the one thing they both describe, the
U13 (`Jun 21 2023` / `Jul 16 2023`, engine version 13) header. Walking
`CacheFileHeaderMCC` field by field puts `Checksum` at `0x360` and
`SectionTable` at `0x4CC`. Assembly's `ReachMCC_LayoutsU13_Core.xml` puts
`checksum` at `0x360`, `offset masks` at `0x4CC` and `sections` at `0x4DC`
(masks are `4 x u32` = `0x10`, so the section array begins at `0x4DC`). The two
code bases, written by different teams, agree exactly. The derived rules above
can therefore be treated as the format's real invariants, not one tool's guess.

Where they differ is coverage, and that difference is finding D1: TagTool models
`ContentHashMask` (`0x364`), `SecuritySalt` (`0x368`), `ContentHash1/2/3`
(`0x370`, `0x384`, `0x398`, each `0x14`), `RSAKeyBlobHash` (`0x3AC`, `0x20`) and
`RSASignature` (`0x3CC`, `0x100`). Assembly models none of them, so Assembly
never updates them on save.

## 3. Build identification

| File family | Version @0x4 | Build string | Engine | Layout |
|---|---|---|---|---|
| seven `ff*.FINAL.map` and their stock originals | 13 | `Jun 21 2023 15:35:31` | Halo: Reach MCC Update 13 | `LayoutsU13` |
| `ff_unearthed.*` and `maps-stock/ff_unearthed.map` | 13 | `Jul 16 2023 16:12:13` | Halo: Reach MCC **Toolset** Update 3 | `LayoutsU13` |

Note for the record: `maps-stock/ff_unearthed.map` is **not** a retail file. Its
build string is the mod-toolset build, and unlike all nine genuine retail stock
maps its `RSAKeyBlobHash` and `RSASignature` are zeroed. That is consistent with
the user's description of it as the original author's own modded, played map.

## 4. Per-file verdict

All nine shipped files: **PASS** (container and structural).

| File | Size | Δ vs stock | Checksum | Sections tile | Pointers | Verdict |
|---|---|---|---|---|---|---|
| `ff10_prototype.FINAL.map` | 190,746,624 | +131,072 | `0x9B192803` OK | exact | all resolve | PASS |
| `ff20_courtyard.FINAL.map` | 183,345,152 | +131,072 | `0x6695F732` OK | exact | all resolve | PASS |
| `ff30_waterfront.FINAL.map` | 192,610,304 | +131,072 | `0x10C7C35F` OK | exact | all resolve | PASS |
| `ff50_park.FINAL.map` | 172,314,624 | +135,168 | `0xBE0C93E7` OK | exact | all resolve | PASS |
| `ff60_airview.FINAL.map` | 173,092,864 | +131,072 | `0x05B1E6B6` OK | exact | all resolve | PASS |
| `ff60_icecave.FINAL.map` | 165,036,032 | +135,168 | `0xD9DB8E6C` OK | exact | all resolve | PASS |
| `ff70_holdout.FINAL.map` | 153,612,288 | +135,168 | `0x0C7816E4` OK | exact | all resolve | PASS |
| `ff_unearthed.marines6.map` | 912,592,896 | +65,536 | `0x8EA44555` OK | exact | all resolve | PASS (see R2) |
| `ff_unearthed.tuned.map` | 912,527,360 | 0 | `0xB35A145E` OK | exact | all resolve | PASS |

Blamite driver result: `problems=0` on all seven `ff*.FINAL.map`. `problems=1` on
`marines6` and `tuned` — the same single problem that `maps-stock/ff_unearthed.map`
itself produces (R6, inherited).

## 5. What was checked, and the result

### 5.1 Header field consistency and section tiling

For all eighteen files (nine shipped, nine stock), every section's file extent was
recomputed as `virtualAddress + offsetMask` and the resulting intervals, plus the
`0..0xA000` header, were required to tile `[0, file size)` with **no gap and no
overlap**. All eighteen tile exactly. Worked example, `ff10_prototype.FINAL.map`:

```
header   [0x00000000, 0x0000A000)
debug    [0x0000A000, 0x0038D000)   va 0x0B1DC000  mask 0xF4E2E000
resource [0x0038D000, 0x03249000)   va 0x00000000  mask 0x0038D000
tag      [0x03249000, 0x0B279000)   va 0x0322C000  mask 0x0001D000
locale   [0x0B279000, 0x0B5E9000)   va 0x02EBC000  mask 0x083BD000
                                    file size      0x0B5E9000 = 190,746,624
```

Other header invariants, all passing on all nine:

- `file size` @`0x08` equals the real file length, exactly, on all eighteen files.
- `virtual size` @`0x14` equals the tag section's size on all eighteen.
- `tag buffer offset` @`0x10` equals the tag section's virtual address on all eighteen.
- Footer magic `foot` is intact at `0x9FFC` on all eighteen.
- `index header address` resolves inside the tag extent, and the structure there
  carries magic `tags` (`0x74616773`) on all eighteen.

### 5.2 Partitions

The six partitions must abut one another, start at `virtual base address`, end at
`virtualBase + virtualSize`, and their sizes must sum to `virtual size`. All
eighteen files satisfy all four conditions. The growth is correctly absorbed by
the last partition, for example `ff10_prototype`:

```
stock  part5 size 0x59B0000   sum 0x8010000 = virtual size 0x8010000
FINAL  part5 size 0x59D0000   sum 0x8030000 = virtual size 0x8030000
```

`ff_unearthed` has a null partition 0 (load 0, size 0) in stock and in both
shipped builds; partitions 1-5 sum to `virtual size` in all three.

### 5.3 Checksum

Stored equals independently computed on **all eighteen files**:

```
ff10_prototype.FINAL   stored 0x9B192803  computed 0x9B192803
ff20_courtyard.FINAL   stored 0x6695F732  computed 0x6695F732
ff30_waterfront.FINAL  stored 0x10C7C35F  computed 0x10C7C35F
ff50_park.FINAL        stored 0xBE0C93E7  computed 0xBE0C93E7
ff60_airview.FINAL     stored 0x05B1E6B6  computed 0x05B1E6B6
ff60_icecave.FINAL     stored 0xD9DB8E6C  computed 0xD9DB8E6C
ff70_holdout.FINAL     stored 0x0C7816E4  computed 0x0C7816E4
ff_unearthed.marines6  stored 0x8EA44555  computed 0x8EA44555
ff_unearthed.tuned     stored 0xB35A145E  computed 0xB35A145E
```

Blamite's own `GenerateChecksum`, run through the C# driver, returns the same
value for each file as the Python implementation. Two independent
implementations plus a nine-file untouched-retail control.

### 5.4 Pointer integrity

Per shipped file, every one of the following was resolved and bounds-checked:

- **Tag table.** 13,189 to 17,983 entries per map. Every non-null entry's
  32-bit meta address was expanded and converted; **zero** land outside the tag
  extent on any of the nine. Null entries (`group index == -1`, `address == 0`)
  number 1-2 per map, identical to stock.
- **Tag group table.** 235 groups in every file, shipped and stock. Every group
  `stringid` index is inside the string-ID table.
- **Global tag table.** 7 entries (`draw`, `gpix`, `matg`, `play`, `scnr`,
  `ugh!`, `zone`) in every file. Every datum index resolves to a tag whose salt
  matches the datum's high half.
- **Tag interop table.** 1,902 to 3,103 entries per map. Every non-null pointer
  resolves inside the tag extent.
- **String-ID index table.** Every entry points inside the string data and the
  string it points at is NUL-terminated.
- **Tag name index table.** Same check. The only out-of-range entries are the
  `-1` sentinels belonging to the null tags, and they are present with identical
  values in the stock originals, including in `ff45_corvette.map`, which this
  project never touched.
- **String namespace table.** 17 entries in every file; all values in range; the
  table is byte-identical to stock in all seven `ff` maps.
- **`matg` locale pointers — the specific defect class called out in the brief.**
  For each of the eighteen files the `matg` tag was located through the global
  tag table, and all twelve language entries were read from the U13 `matg`
  languages array at offset `0x18` (the U13 layout overrides the base Reach
  offset of `0x298`; `0x18` is the one that yields in-range pointers, confirming
  the U13 layout is the right one for these builds). For every language, the
  locale index table pointer and the locale data pointer were converted through
  the locale section's base and mask and required to lie, with their full length,
  inside the locale extent. **216 of 216 language entries resolve. Zero
  out-of-range.** The rebase is visibly correct, for example `ff10_prototype`
  English: stock pointer `0x4A1E000` → file `0xB259000`; shipped pointer
  `0x2EBC000` → file `0xB279000`, which is the new locale extent's start. The
  SHA-1 index-table and string-data hashes are unchanged, which is correct
  because the locale payload is byte-identical (see 5.5).
- **Resource pages.** Every local (non-shared-file) resource page's
  `offset + compressedSize` was required to lie inside the raw/resource segment.
  Zero out of bounds on all seven `ff` maps. Two out of bounds on each of the
  three Unearthed builds, including the stock known-good one — see R6.
- **Structured readers.** Blamite's scenario script loader, resource table
  loader, zone/simulation tables, sound gestalt and all twelve language packs
  ran to completion on all nine with no exception.

Honest limit: pointer validation inside individual tag meta blocks was done only
to the depth Blamite's structured readers walk (scenario scripts, `matg`
locales, `play`/`zone` resource tables, sound gestalt, interop). An exhaustive
field-level walk of all ~14,000 tags per map would need Assembly's plugin-driven
`MetaReader`, which lives in the WPF application rather than in Blamite, and was
not attempted. A stale pointer inside a tag field that Blamite does not walk
would not have been caught.

### 5.5 Growth artefacts

Eight of the nine shipped files grew. The growth is accounted for in every case.

| File | Tag section | Debug section | Total |
|---|---|---|---|
| `ff10_prototype` | +0x20000 | 0 | +0x20000 |
| `ff20_courtyard` | +0x20000 | 0 | +0x20000 |
| `ff30_waterfront` | +0x20000 | 0 | +0x20000 |
| `ff50_park` | +0x20000 | +0x1000 | +0x21000 |
| `ff60_airview` | +0x20000 | 0 | +0x20000 |
| `ff60_icecave` | +0x20000 | +0x1000 | +0x21000 |
| `ff70_holdout` | +0x20000 | +0x1000 | +0x21000 |
| `ff_unearthed.marines6` | +0x10000 | 0 | +0x10000 |
| `ff_unearthed.tuned` | 0 | 0 | 0 |

The tag growth is `0x20000` = two `0x10000` pages, matching
`tagSegmentAlignment` of `0x10000`. The appended page is genuinely used but
sparsely: on `ff10_prototype` the appended `[0xB259000, 0xB279000)` holds 716
non-zero bytes with the last non-zero byte at `0xB269849`, so roughly the first
`0x10849` is live and the rest is allocator slack. Same pattern on the others.
That is normal `MetaAllocator` behaviour and not a defect.

The `0x1000` debug growth on `ff50_park`, `ff60_icecave` and `ff70_holdout` is
explained and benign: the string-ID data table grew past a `0x1000` boundary, so
the namespace and tag-name tables that follow it moved up one page. For
`ff50_park`, string data runs `0x50000 + 0x25BF69` → ends `0x2ABF69` → next page
`0x2AC000` in stock, versus `0x50000 + 0x25C192` → ends `0x2AC192` → next page
`0x2AD000` shipped. A naive byte diff reports ~22% of the debug section as
"changed" purely because of that one-page slide; with the slide applied, the
content matches.

Nothing after an insertion point shifted incorrectly:

- The locale section follows the tag section in file order on the `ff` maps. It
  shifted by exactly the total growth and is **byte-identical after the shift**
  (0 differing bytes, all seven maps).
- On the three maps with debug growth, the resource section shifted by exactly
  `+0x1000` and is **byte-identical after the shift** (0 differing bytes).
- No stale pointer targets a pre-growth offset. This is strongly testable here
  because the shipped files also rebased the section virtual addresses by large
  deltas (`ff10_prototype` locale VA moved `0x4A1E000` → `0x2EBC000`, a delta of
  `0x1B62000`). Any locale or section pointer left at its pre-edit value would
  resolve far outside the file and would have been caught by 5.4. None was.
  Tag-internal pointers needed no rebase at all, because `virtual base address`
  and the tag section's *file* offset are what the meta address converter uses,
  and on the four maps without debug growth both are unchanged; on the three with
  debug growth the tag file offset moved `+0x1000` and the index header address
  is correspondingly unchanged while its resolved offset moves `+0x1000`, which
  is right.

### 5.6 Tag table sanity

| File | Tags | Groups | String-IDs | Tag names |
|---|---|---|---|---|
| `ff10_prototype` | 14,650 = stock | 235 = stock | 71,288 → 71,326 (+38) | index identical |
| `ff20_courtyard` | 13,879 = stock | 235 = stock | 52,675 → 52,715 (+40) | index identical |
| `ff30_waterfront` | 14,181 = stock | 235 = stock | 57,069 → 57,107 (+38) | index identical |
| `ff50_park` | 14,034 = stock | 235 = stock | 70,659 → 70,697 (+38) | index identical |
| `ff60_airview` | 14,547 = stock | 235 = stock | 66,644 → 66,682 (+38) | index identical |
| `ff60_icecave` | 13,189 = stock | 235 = stock | 65,804 → 65,842 (+38) | index identical |
| `ff70_holdout` | 13,291 = stock | 235 = stock | 65,672 → 65,713 (+41) | index identical |
| `ff_unearthed.marines6` | 17,983 = stock | 235 = stock | 49,514 = stock | identical |
| `ff_unearthed.tuned` | 17,983 = stock | 235 = stock | 49,514 = stock | identical |

Byte-level comparison against stock:

- **Tag group table: byte-identical** on all nine.
- **Tag table: byte-identical** on all nine. No tag was added, removed, moved or
  re-salted.
- **Global tag table: byte-identical** on all nine.
- **String namespace table: byte-identical** on all nine.
- **String-ID index and data tables: the stock prefix is byte-identical** on all
  nine; the `ff` maps append 38-41 new entries, all with the `fe_` prefix
  (`fe_valid`, `fe_near`, `fe_score`, `fe_buyer_at`, `fe_anyone_at`,
  `fe_charge_at`, `fe_credit_at`, `fe_ok`, ...). That is the shop's own
  string-ID set, exactly what the mod should be adding.
- **Tag name index table: byte-identical** on all nine.

### 5.7 Diff of every shipped map against its stock original

Every differing byte run is classified. The seven `ff` maps all produce the same
nine-run signature, which is itself evidence of a systematic tool-driven edit
rather than corruption.

**Header (`0x0` - `0xA000`), 43-51 differing bytes, three runs:**

| Run | Fields | Classification |
|---|---|---|
| `0x09`/`0x0A` - `0x48` | file size, tag buffer offset, virtual size, type, tag-name table count/offset/size/index, string-ID count/offset/size/index, namespace count/offset | intended |
| `0x35A` - `0x364` | last partition's size, then the checksum at `0x360` | intended |
| `0x4CD` - `0x4F8` | the four offset masks and the four section records | intended |

Everything else in the header is untouched, which is exactly why the security
block at `0x364` - `0x4CB` is stale (R1).

**Resource section:** 0 differing bytes on all nine.

**Locale section:** 0 differing bytes on all nine.

**Debug section:** two small runs per map plus, on the three maps with debug
growth, the one-page slide described in 5.5. Run one is the tail of the
string-ID index table (the 38-41 new entries); run two is the appended string
bytes. Example, `ff10_prototype`: `0x4F9E0` - `0x4FA77` is the last 38 entries of
the index table, which ends at `0xA000 + 71326*4 = 0x4FA78`; `0x2AF013` -
`0x2AF239` is the appended string data, starting at
`0x50000 + 0x25F013 = 0x2AF013`, the old end of the string data. Both intended.

**Tag section:** 0.23% - 0.28% of the section differs, in nine merged runs.
Mapping each run to the owning tag through the tag table and the name table:

| Run (ff10 example) | Size | Owner | Classification |
|---|---|---|---|
| `0x56F7A4D` | `0x377` | `matg` / `globals\globals`, starting `0x21` into the tag | the 12-language locale pointer array — intended, this is the locale rebase |
| `0x575035B` - `0x57CEE38` | `0x77ADD` | scenario script expression and script-string data | intended — the scenario scripts were recompiled, see R3 |
| `0x58DD648` - `0x58EFECC` | 4 runs, `0x2` to `0x4178` | squad-template block data (`sqtm` region) | intended — the mod's squads |
| `0x5C43280`, `0x5C4354C` | `0x8`, `0xEA` | inside `scnr` / `levels\firefight\ff10_prototype\ff10_prototype` (`0x5C43130` - `0x5C4399C`) | intended — scenario edits |
| `0x9974364` | `0x4` | `char` / `objects\characters\null\ai\null_cov_default` | intended — character tuning |

Nothing is unexplained. The one run that initially looked unexplained — the
`~0x75000`-`0x7D000` block with tens of thousands of scattered sub-runs and a
zeroed tail — is the scenario script table being rewritten smaller. The Blamite
driver confirms it: script count rises while expression count falls sharply
(`ff10_prototype` 359 → 397 scripts, 197 → 222 globals, but 19,261 → 16,639
expressions). The zeroed tail is the freed space.

`ff_unearthed.marines6` differs from its stock original in **9 bytes total**:
3 header bytes (`0x0A`-`0x17` region: file size and tag buffer/virtual size),
the last partition size and checksum at `0x35A`-`0x364`, the masks/sections at
`0x4CE`-`0x4F3`, and 5 bytes in the tag area at `0x300C3398`, `0x300C3548`,
`0x302B55D0`, `0x302B6664` and `0x302B7FE8`. Plus the `0x10000` appended page.
Scripts, resources, locales and string-IDs are all unchanged from stock.

`ff_unearthed.tuned` differs in **4 bytes total**: the checksum byte at `0x360`,
and three single bytes in the tag area at `0x300C3398`, `0x300C3548` and
`0x302B55D0`. See doc finding D2.

### 5.8 MOD-PACKAGE copies

Verified by hash, not inspection. MD5 of each packaged map against the published
original:

| Packaged copy | MD5 | Matches |
|---|---|---|
| `Firefight-Reinforcements/maps/ff10_prototype.map` | `87a3c0fbe3aa55373b5c355b84759a5d` | `ff10_prototype.FINAL.map` |
| `.../ff20_courtyard.map` | `44875c0e0e28fdcad5a14a0063c03c9a` | `ff20_courtyard.FINAL.map` |
| `.../ff30_waterfront.map` | `99cc8d6e6f7efe2f326803bbff6d1715` | `ff30_waterfront.FINAL.map` |
| `.../ff50_park.map` | `ccbc36829a0cd077c11b58c7b26d055d` | `ff50_park.FINAL.map` |
| `.../ff60_airview.map` | `b38aadf424b620a96198044d57e3c470` | `ff60_airview.FINAL.map` |
| `.../ff60_icecave.map` | `78f495044332e490b7cc846eef8aad95` | `ff60_icecave.FINAL.map` |
| `.../ff70_holdout.map` | `455f1d0c2bb8b963fafab4d69550d470` | `ff70_holdout.FINAL.map` |
| `.../ff_unearthed.map` | `9485119638a4600f5aa5c0785cb8a88b` | `ff_unearthed.marines6.map` |
| `Firefight-Reinforcements-Safe/maps/ff_unearthed.map` | `5e9e9479815b12cdab4bc604e1fa0ccf` | `ff_unearthed.tuned.map` |

All nine match. Nothing was re-encoded, truncated or re-saved on the way into the
package.

Manifest cross-check, which also passes: both `ModInfo.json` files list only
firefight JSONs that exist, every JSON's `ScenarioFile` matches the scenario path
in the corresponding map's header at `0xE0`, and the `maps/` directories contain
exactly the maps the manifests imply. `ff45_corvette` is correctly absent from
both the manifests and the `maps/` directories. The two hashes quoted in
`READ-ME-FIRST.txt` (SHA-256 `4c45d4b8...` for marines6, `c01e2096...` for tuned)
and the SHA-1 it quotes for the untouched original
(`21e4066fc760d7fa025446a7319decdb75ade4da`) are all correct.

### 5.9 Comparison against the known-good modified cache

`maps-stock/ff_unearthed.map` is the reference: a modified Reach cache the user
has actually played. Three container shapes exist in the audit set.

| Property | Retail stock `ff*` | Known-good `ff_unearthed` | Our `ff*.FINAL` | Our `marines6` |
|---|---|---|---|---|
| resource section VA | `0` | `0xA000` | `0` | `0xA000` |
| offset masks | all non-zero | all zero | all non-zero | debug `0x10000`, rest zero |
| VA space tiles with no gap | **no** (gap of `0xC28000`-`0x2E01000` between resource and locale) | yes | **yes** | no (`0x10000` debug/tag overlap) |
| debug VA = Assembly-canonical | no | **yes** | **yes** | **no** |
| debug/tag VA overlap | `0x80000` | none | `0x80000` | `0x10000` |
| RSA signature at `0x3CC` | present | **zeroed** | present, stale | zeroed |
| content hashes `0x370`/`0x384`/`0x398` | present | present | present, stale | present, stale |
| file extents tile exactly | yes | yes | yes | yes |

Readings:

- Our seven `ff` maps are precisely what Assembly produces when it re-serialises
  a retail map: `RebuildInteropData` closes the virtual-address gap that 343's
  files carry, and reproduces the `0x80000` debug/tag virtual overlap that
  Assembly's own source comments describe as "what the official files do". The
  overlap is present in all nine untouched retail stock files, so it is not a
  defect. The gap closure is a real difference from stock, but it is standard
  Assembly behaviour and the known-good reference is also gap-free. R5.
- `marines6` is the only file in the set whose shape matches **neither** a retail
  file nor the known-good reference. Its debug section's virtual address was left
  at the pre-growth value and the growth was absorbed into the offset mask
  instead. The arithmetic is correct, the file tiles exactly, and everything
  reads, but Assembly would have written VA `0x363E9000` with mask `0`. R2.
- The known-good reference zeroes the RSA signature; our seven `ff` maps keep
  the retail signature over changed content. R1.

## 6. Findings, severity-ranked

### BLOCKER

**None.** Nothing was found that makes any of the nine files structurally invalid,
internally inconsistent, or unreadable by the reference library. This is stated
as a negative result, not as a guarantee that the maps play correctly — see the
limits in 5.4 and finding R3.

### RISK

**R1 — Stale MCC security block in the seven `ff*.FINAL.map`.**
`ContentHash1/2/3` at `0x370`/`0x384`/`0x398`, `RSAKeyBlobHash` at `0x3AC` and
the 256-byte `RSASignature` at `0x3CC` are byte-identical to the retail
originals, while the content they cover has changed. `ContentHashMask` is `7`
(three hashes active) and `SecuritySalt` is `0x17800EA664197BFC`, both unchanged.
Evidence: the header diff touches only `0x09`-`0x48`, `0x35A`-`0x364` and
`0x4CD`-`0x4F8`; `0x364`-`0x4CB` is untouched. Neither Assembly nor TagTool
models or recomputes these fields, so every Assembly-made Reach MCC map mod has
this property — which is the practical argument that it is tolerated. Against
that: the known-good reference zeroes the signature rather than leaving it stale,
which suggests the official toolset deliberately clears it. I could not find a
published account of MCC's verification behaviour to settle this. Mitigation is
already in `INSTALL.txt`: the install requires launching through "Play Halo: MCC
Anti-Cheat Disabled (Mods and Limited Services)". If a map is rejected at load,
this is the first thing to test, by zeroing `0x3AC`-`0x4CC` and recomputing the
checksum.

**R2 — `marines6` has a non-canonical debug section virtual address.**
VA `0x363D9000` with debug mask `0x10000`, where Assembly would write VA
`0x363E9000` with mask `0`. Consequences: the debug section's virtual range
`[0x363D9000, 0x36641000)` overlaps the tag section's `[0x2F3F9000, 0x363E9000)`
by `0x10000`, and the file's shape matches no known-working cache. It is
arithmetically self-consistent (file offset = VA + mask), tiles the file exactly,
and Blamite reads it with zero problems, and retail files do carry a larger
`0x80000` overlap of the same kind — so this is a low-probability risk, not a
defect. It nonetheless justifies the existing advice to keep `tuned.map`, which
is canonical, as the fallback.

**R3 — The seven `ff` maps recompiled Bungie's entire scenario script table, not
just the added scripts.** Measured per map: scripts `+38` to `+41`, script
globals `+25` to `+28`, but expressions **down 13-14%** — `ff10_prototype`
19,261 → 16,639, `ff20_courtyard` 18,821 → 16,220, `ff50_park` 19,888 → 17,179,
`ff70_holdout` 20,164 → 17,446, `ff60_icecave` 17,415 → 14,865. An expression
table that shrinks by thousands of entries while gaining ~40 scripts means the
whole table was regenerated from decompiled source, so all ~360 stock scripts per
map went through an Assembly decompile/recompile round trip. This is by far the
largest behavioural blast radius in the change set and it is where a silent
gameplay regression would live. It is structurally clean and semantically
unverified. Note that `marines6` and `tuned` did **not** do this: their script
tables are byte-for-byte the stock ones (485 scripts, 277 globals, 52,711
expressions in all three Unearthed builds).

**R4 — Duplicate firefight map GUID across the two mod profiles.**
`Firefight-Reinforcements/firefight/ff_unearthed.json` and
`Firefight-Reinforcements-Safe/firefight/ff_unearthed.json` both declare
`MapGuid` `ee9b58f1-2eed-4f91-9198-6a94e6ffe9e4`. Installing both profiles at
once puts two mods on one firefight map GUID. Related observation: six of the
eight map GUIDs are deterministic version-5 (name-derived) values, while
`ff70_holdout` (`344e2f1c-3e14-4033-...`) and `ff_unearthed`
(`ee9b58f1-2eed-4f91-...`) are version-4 (random), i.e. inherited rather than
generated. If the original author's mod is also installed, those two will
collide with it. MCC keys firefight progress by map GUID.

**R5 — The seven `ff` maps' section virtual addresses were rebased.**
`ff10_prototype` is representative: locale VA `0x4A1E000` → `0x2EBC000`, tag VA
`0x4D8E000` → `0x322C000`, debug VA `0xCD1E000` → `0xB1DC000`, all shifted by the
`0x1B62000` virtual gap that 343's file left between the resource and locale
sections and that Assembly removes. All corresponding masks were updated so every
file offset is unchanged or correctly shifted, and tag-internal pointers are
unaffected because they are relative to `virtual base address`, which did not
change. This is unconditional Assembly save behaviour and the known-good
reference has the same gap-free property, so the risk is low — but it is a
structural difference from the stock files and belongs on the list.

**R6 — Two out-of-range resource pages in all three Unearthed builds
(inherited).** In `maps-stock/ff_unearthed.map`, `ff_unearthed.marines6.map` and
`ff_unearthed.tuned.map`, 2 of 18,931 local resource pages have
`offset + compressedSize` outside the raw/resource segment
`[0xA000, 0x2F072000)`. The condition is present, unchanged, in the known-good
file the user has already played, so it is inherited from the original author's
map rather than introduced here. All seven `ff` maps have zero out-of-range
pages.

### COSMETIC

**C1 — Tag-name data shrank by 1-9 bytes in the seven `ff` maps.**
`ff10_prototype` `0xCC080` → `0xCC07F`, `ff30_waterfront` `0xC45F0` → `0xC45E9`,
`ff60_airview` `0xC8FA0` → `0xC8F97`, and so on. The tag-name **index** table is
byte-identical to stock in every case and the common prefix of the name data is
byte-identical, so this is trailing padding only and every real tag name is
intact. The tag-name table is debug data and is not read by the engine at
runtime.

**C2 — `ready-to-install/READ-ME-FIRST.txt` is marked `SUPERSEDED` but still
sits beside the maps** and still contains step-by-step install instructions
(manual rename of `ff_unearthed.map`) that contradict
`MOD-PACKAGE/INSTALL.txt`. Its own banner tells the reader to ignore it. It
should be moved into `_superseded/` or deleted.

## 7. Where this project's documentation is wrong

**D1 — The MCC security block is entirely undocumented.**
`07-map-container-format.md` lines 95-122 give a complete, correct U13 header
table — and then jump from `checksum` at `0x360` straight to `offset masks` at
`0x4CC`, with nothing in between. The region `0x364`-`0x4CB` holds
`ContentHashMask`, `SecuritySalt`, three SHA-1 content hashes, an RSA key-blob
hash and a 256-byte RSA signature, per TagTool's
`TagTool/Cache/MCC/CacheFileHeaderMCC.cs`, whose field walk puts `Checksum` at
`0x360` and `SectionTable` at `0x4CC` in exact agreement with Assembly. A grep of
all 23 research documents for `0x364`, `0x368`, `0x384`, `0x398`, `SecuritySalt`,
`security salt`, `hash mask` and `RSA` in a cache-header context returns nothing.
The project therefore ships maps with stale signature and content-hash fields
without any document recording that those fields exist. This is the single most
material documentation gap found, and it is the origin of R1.

**D2 — `READ-ME-FIRST.txt` line 39 says `tuned.map` "changes six bytes and
nothing else". It changes four.** Measured against
`maps-stock/ff_unearthed.map`: one byte at `0x360` (the low byte of the
checksum, `0xB35A145C` → `0xB35A145E`) and three single bytes in the tag area at
`0x300C3398`, `0x300C3548` and `0x302B55D0`. Total 4 differing bytes, 0 size
change. The claim understates nothing dangerous, but it is not accurate.

**D3 — `MOD-PACKAGE/INSTALL.txt` line 11 calls Blamite "the game's own Blamite
library".** Blamite is the cache library inside XboxChaos/Assembly, a third-party
modding tool. MCC shares no code with it. Passing Blamite proves a file is
readable by Assembly; it says nothing about what the retail engine accepts. The
same paragraph is otherwise commendably honest ("None of this has ever been run
in retail MCC"), which makes the one overstated clause worth fixing rather than
excusing.

**D4 — `21-shops-overlook-beachhead.md` line 428 records "size grew by exactly
the granted page ✅ +0x10000" for two maps; the shipped files grew `+0x20000` in
the tag section** (plus `+0x1000` in the debug section on `ff50_park`,
`ff60_icecave` and `ff70_holdout`). That is consistent with a later, second page
grant rather than with an error at the time of writing, but no document records
the deltas the shipped files actually carry. The table in 5.5 above is the first
record of them.

### Documentation that was checked and found correct

- The checksum algorithm, as described in `12-no-windows-workarounds.md` lines
  60 and 84-85, `13-map-write-feasibility.md` lines 20 and 44-48, and
  `18-first-build-attempt.md` line 307: XOR of every little-endian `uint32` from
  `0xA000` to EOF, tail zero-padded, written as an `int32` at `0x360`.
  Independently reimplemented and confirmed against all nine untouched retail
  stock files.
- The whole U13 column of the header field table in
  `07-map-container-format.md`, including the non-obvious entries
  (`index header address` at `0x2E8`, `build string` at `0xA0`, `checksum` at
  `0x360`, `offset masks` at `0x4CC`, `sections` at `0x4DC`, footer magic at
  `0x9FFC`). Every one verified against real files.
- `07-map-container-format.md` lines 48-51 on c20.reclaimers.net: the `/hr/map`
  page is indeed an empty stub, confirmed by cloning `Sigmmma/c20` — the source
  file is 80 bytes of front matter with no body. Assembly is correctly identified
  as the authority.
- `INSTALL.txt` line 188's claim that the shop price text is frozen because its
  string table is SHA-1 checked and was left alone: the locale payload is indeed
  byte-identical in every shipped map and the `matg` index-table and string-data
  SHA-1s are correspondingly unchanged and consistent.

## 8. What was not verified

Stated plainly, because a false PASS is the worst outcome here.

1. **Nothing was loaded by retail MCC.** No part of this audit runs the game.
2. **Whether MCC enforces the fields in R1** is unknown. No published account was
   found. The argument that it does not is circumstantial: Assembly leaves them
   stale on every save, and Assembly-made Reach MCC map mods are widely played.
3. **Field-level pointer validation inside individual tag meta** was done only to
   the depth Blamite's structured readers walk (see the limit at the end of 5.4).
   Roughly 14,000 tags per map were bounds-checked at the tag-table level, but
   not field by field.
4. **Script semantics.** R3 identifies that all stock scripts were recompiled; it
   does not establish whether the recompiled scripts behave the same. That needs
   a decompile-and-compare of stock versus shipped script source, which is a
   separate audit.
5. **Whether MCC's mod manifest loads replaced Firefight caches at all.** This
   project's own `INSTALL.txt` already flags it as untested; nothing in this
   audit changes that.
6. **Megalo / `mpvr` and the `.bin` game variants** were out of scope.

## 9. Reproduction

Artefacts, all under `/tmp/halo_audit/` and all written fresh for this audit:

| File | Purpose |
|---|---|
| `hdr.py` | hand-transcribed U13 header reader |
| `audit.py` | section tiling, canonical-VA, partition, table-bounds, tag-index checks |
| `cksum.py` | independent XOR checksum |
| `locales.py` | `matg` 12-language locale pointer resolution |
| `regiondiff.py` | per-section diff with shift handling, run classification |
| `whichtag.py` | maps a file offset to the owning tag and its name |
| `deep.py` | string-ID / tag-name / group / global-tag / namespace table integrity and stock comparison |
| `val/Program.cs` | C# driver over `Blamite.csproj`, forces every structured reader |

External sources cloned for the audit: `/tmp/tagtool`
(`TheGuardians-CI/TagTool`) and `/tmp/c20` (`Sigmmma/c20`). Assembly was read at
`/tmp/acp_test/Assembly-CrossPlatform` (commit `e69f5be`).

The C# driver needs `DOTNET_ROLL_FORWARD=LatestMajor` on this machine (the
project targets net8.0, only the .NET 11 runtime is installed) and
`System.Text.Encoding.CodePages` registered, otherwise the Reach script loader
throws on codepage 1252 — an environment issue, not a map defect.
