# Halo: Reach (MCC) `.map` Cache File — Container Format

Tooling: `tools/map/parse_map.py` (CLI), `tools/map/reach_cache.py` (library),
`tools/map/test_parse_map.py` (self-test, 195 assertions, all passing),
`tools/map/reach_tag_groups.json` (four-character code → tag group name).

**No real `.map` file existed on this machine when this was written.** Nothing
below has been read out of a shipped Halo: Reach cache file by this project.
Everything is a transcription of cited prior art, implemented in code, and
verified against *synthetic* cache files that the self-test builds from the
same tables. That proves the reader's arithmetic, not the offsets. Read
§11 before trusting any number the tool prints.

## 1. Confidence legend

| Tag | Meaning |
|---|---|
| **SPEC-CITED** | Transcribed field-for-field from named prior art (file and line-level references in §2). Implemented. Never seen real bytes. |
| **SYNTHETIC-PROVEN** | The *code path* is exercised by `test_parse_map.py`, which writes a byte-exact cache from this spec and reads it back. Proves the implementation matches the spec. |
| **HEURISTIC** | Not stored in the file; computed by inference (e.g. tag sizes). Will be approximately right, can be wrong. |
| **UNTESTED** | Implemented from prior art and not reachable by the self-test (Xbox 360 AES decryption, the chunked-zlib decompressors). |

## 2. Prior art

Primary source: **Assembly / Blamite**, `github.com/XboxChaos/Assembly`. Its
`Formats/*.xml` layout database *is* the format documentation — Assembly reads
real Reach MCC maps with it, including every MCC update since 2019.

| What | Assembly path |
|---|---|
| MCC 2019 header (engine version 12) | `src/Blamite/Formats/ReachMCC/Layouts/ReachMCC_Layouts_Core.xml` |
| MCC U3–U7 header (version 13) | `src/Blamite/Formats/ReachMCC/LayoutsU3/ReachMCC_LayoutsU3_Core.xml` |
| MCC U8+ header (version 13) | `src/Blamite/Formats/ReachMCC/LayoutsU8/…`, `LayoutsU10/…`, `LayoutsU13/…` (identical `header` layouts) |
| Xbox 360 Reach header | `src/Blamite/Formats/Reach/Layouts/Reach_Layouts_Core.xml` |
| build string → layout, endianness, `expandMagic`, AES keys, compression type | `src/Blamite/Formats/Engines.xml` |
| magic / version / build-string matching | `src/Blamite/Blam/CacheFileLoader.cs` |
| section & partition maths, string and file tables | `src/Blamite/Blam/ThirdGen/Structures/ThirdGenHeader.cs` |
| index header, group/tag/global/interop tables | `src/Blamite/Blam/ThirdGen/Structures/ThirdGenTagTable.cs` |
| pointer contraction | `src/Blamite/Blam/ThirdGen/ThirdGenPointerExpander.cs` |
| pointer → file offset | `src/Blamite/Blam/{BasedPointerConverter,MetaAddressConverter}.cs` |
| string-id namespaces | `src/Blamite/Blam/StringIDNamespaceResolver.cs`, `Formats/Reach/Reach_StringIDs.xml` |
| MCC-era compression schemes | `src/Blamite/Compression/{CompressionManager,FirstGenSaberZLib,SecondGenSaberZLib,ThirdGenDurangoLZMA}.cs` |

Secondary source for group four-character codes: **`camden-smallwood/definitions`**,
`haloreach_mcc/_meta.json` — a dump of the real Halo: Reach MCC tag definitions
(`dumped_from: reach_tag_test.exe`). This is what settles `smdt` = `survival_mode_globals`.

`c20.reclaimers.net` does have a Halo Reach section (`/hr/tags/…` lists every
tag group *name*), but its cache-file page `/hr/map` is an **empty stub** as of
2026-11-21 and its tag pages carry no four-character codes. It is therefore not
usable as a layout source here; Assembly is the authority.

Local copies kept so this does not have to be re-fetched:

- `research/_raw/assembly-layouts/` — the five core layout XMLs, the two scenario
  layout XMLs, `Reach_StringIDs.xml`, and the whole `Engines.xml`.
- `research/_raw/reach-defs/` — `_meta.json` plus the `scenario`,
  `survival_mode_globals`, `squad_template`, `wave_template`, `character`,
  `megalo_string_id_table`, `multiplayer_globals` and `scenario_hs_source_file`
  definition dumps (field-level structures — this is what the *next* layer needs).

## 3. File anatomy

A Reach cache file is a flat image of what the engine maps into memory:

```
0x00000  cache file header .................... 0xA000 bytes, 'daeh'/'head' at 0x0, 'toof'/'foot' at 0x9FFC
0x0A000  four "interop sections", in file order (their real offsets come from the header):
           debug         - string-id table, string-id index table, tag-name (file) table, namespace table
           localization  - locale/unicode string blobs
           resource      - raw/resource ("raw table") data
           tag           - the tag data area, a.k.a. "meta": index header + tag tables + every tag's fields
EOF
```

- Header size is **0xA000** for every Reach build, 360 and MCC alike
  (`<layout for="header" size="0xA000">` in all five layout files). This is much
  larger than Halo 3's 0x800; most of it is zero padding. SPEC-CITED.
- Magic: `head` big-endian (Xbox 360) or `daeh` little-endian (PC/MCC) at 0x0.
  **Engine version** is an `int32` at 0x4: `12` for Xbox 360 Reach and MCC
  2019–2020, `13` for MCC Update 3 onwards. Footer magic (`foot`/`toof`, also
  `Gfot`/`tofG`) sits at `header_size - 4`. SPEC-CITED, SYNTHETIC-PROVEN.
- Tags carry **no file offsets**, only virtual addresses; see §5.

## 4. Cache file header

Fields present in every variant, with per-variant offsets. All offsets hex.
`asciiz` = NUL-terminated ASCII (the layouts give no length; the tool reads up
to the next field, capped at 0x100 bytes — a scenario path is longer than 0x20
bytes, so a fixed 32-byte window would truncate it).

| Field | Type | 360 | MCC 2019 (v12) | MCC U3 (v13) | MCC U8+ (v13) |
|---|---|---|---|---|---|
| header magic | 4 bytes | 0x00 | 0x00 | 0x00 | 0x00 |
| engine version | i32 | 0x04 | 0x04 | 0x04 | 0x04 |
| file size | u32 / u64 | 0x08 | 0x08 (u64) | 0x08 (u64) | 0x08 (u32) |
| index header address | u32 / u64 | 0x10 | 0x10 (u64) | 0x10 (u64) | **0x2E8** (u64) |
| tag buffer offset | u32 | 0x14 | 0x18 | 0x18 | 0x10 |
| virtual size (tag area size) | u32 | 0x18 | 0x1C | 0x1C | 0x14 |
| cache type | i16 | 0x13C | 0x140 | 0x140 | 0x18 |
| file (tag name) table count | i32 | 0x2B4 | 0x2C0 | 0x2BC | 0x20 |
| file table offset | i32 | 0x2B8 | 0x2C4 | 0x2C0 | 0x24 |
| file table size | i32 | 0x2BC | 0x2C8 | 0x2C4 | 0x28 |
| file index table offset | i32 | 0x2C0 | 0x2CC | 0x2C8 | 0x2C |
| string-id count | i32 | 0x158 | 0x15C | 0x150 | 0x30 |
| string-id table offset | i32 | 0x164 | 0x168 | 0x15C | 0x34 |
| string-id table size | i32 | 0x15C | 0x160 | 0x154 | 0x38 |
| string-id index table offset | i32 | 0x160 | 0x164 | 0x158 | 0x3C |
| string namespace count | i32 | — | — | 0x160 | 0x40 |
| string namespace table offset | i32 | — | — | 0x164 | 0x44 |
| cache build date (FILETIME hi/lo) | i32,i32 | 0x16C/0x170 | 0x170/0x174 | 0x16C/0x170 | 0x50/0x54 |
| build string | asciiz | 0x11C | 0x120 | 0x120 | **0xA0** |
| internal (map) name | asciiz | 0x18C | 0x198 | 0x194 | 0xC0 |
| scenario tag path | asciiz | 0x1B0 | 0x1BC | 0x1B8 | 0xE0 |
| checksum | i32 | 0x2C4 | 0x2D0 | 0x2CC | 0x360 |
| virtual base address | u32 / u64 | 0x2E8 | 0x2F8 (u64) | 0x2F0 (u64) | 0x2E0 (u64) |
| xdk version | u32 | 0x2EC | 0x300 | 0x2F8 | 0x2F0 |
| partitions (6 × {load address, size}) | array | 0x2F0, 0x8 each | 0x308, 0x10 each | 0x300, 0x10 each | 0x300, 0x10 each |
| offset masks (4 × u32) | array | 0x46C | 0x4B4 | 0x4AC | 0x4CC |
| sections (4 × {virtual address u32, size u32}) | array | 0x47C | 0x4C4 | 0x4BC | 0x4DC |
| footer magic | 4 bytes | 0x9FFC | 0x9FFC | 0x9FFC | 0x9FFC |

All SPEC-CITED, SYNTHETIC-PROVEN (each variant gets its own synthetic file in
the self-test).

Cache file type (`CacheFileType.cs`): 0 campaign, 1 multiplayer, 2 main menu,
3 shared, 4 single-player shared.

### 4.1 Which layout a map uses

Assembly's algorithm, reimplemented: endianness from the magic, engine version
from 0x4, then **exact match on the build string** against `Engines.xml`.
Flattened table (build string → header layout):

| Build string | Release | Layout |
|---|---|---|
| `Jul 30 2019 14:17:16` | MCC Flight 2 | mcc-2019 |
| `Oct 24 2019 15:56:32` | MCC launch | mcc-2019 |
| `Jan 30 2020 16:55:25` | Update 1 | mcc-2019 |
| `Mar 24 2020 12:10:36` | Update 2 | mcc-2019 |
| `Jun  5 2020 10:40:14` | Update 3 | mcc-u3 |
| `Oct 15 2020 18:23:50` | Update 4 | mcc-u3 |
| `Nov 24 2020 18:32:37` | Update 5 | mcc-u3 |
| `Feb 17 2021 21:07:38` | Flight 3 | mcc-u3 |
| `Mar  4 2021 13:14:28` | Update 6 | mcc-u3 |
| `May 26 2021 10:02:45` | Update 7 | mcc-u3 |
| `Aug 11 2021 15:50:30` | Flight 4 | mcc-u8+ |
| `Sep 13 2021 09:49:52` | Update 8 | mcc-u8+ |
| `Sep 17 2021 13:25:40` | Update 9 | mcc-u8+ |
| `Jan 13 2022 00:54:50` | Update 10 | mcc-u8+ |
| `Aug  5 2022 20:35:02` | Update 11 | mcc-u8+ |
| `Aug 31 2022 11:53:49` / `…11:53:19` | MCC Toolset (+Fast) | mcc-u8+ |
| `Oct 12 2022 01:55:01` | Update 12 | mcc-u8+ |
| `Nov 16 2022 21:11:25` / `…21:13:04` | Toolset U1 (+Fast) | mcc-u8+ |
| `Jun 21 2023 15:35:31` | Update 13 | mcc-u8+ |
| `Jun 27 2023 08:55:51` / `…08:55:19` | Toolset U2 (+Fast) | mcc-u8+ |
| `Jul 16 2023 16:12:13` / `…16:08:14` | Toolset U3 (+Fast) | mcc-u8+ |
| `11860.10.07.24.0147.omaha_relea` | Xbox 360 retail | xbox360 |
| `00095.11.04.09.1509.demo` | Xbox 360 demo | xbox360 |

MCC has shipped updates since Jul 2023, so **an unknown build string is the
expected case** for a 2025/2026 map. The tool then falls back to structural
scoring and refuses to continue unless one layout's *index header address*
resolves to a structure whose magic really is `tags`; when it does continue it
prints `!! UNKNOWN BUILD` and marks every field unverified. The most likely
outcome for a current map is `mcc-u8+`, since that header has been stable
across Flight 4 → Update 13 (two years and six releases).

## 5. Pointers: three different conversions

This is the part that silently produces garbage if you get it wrong.

1. **Section offset masks** (`BasedPointerConverter`): the tag/debug/locale/
   resource sections each have a `virtual address` and an `offset mask`, and
   `file offset = pointer + mask`. In a shipped (uncompressed, unrelocated) map
   the masks are 0 and the section "virtual address" *is* the file offset.
   The tag data area therefore starts at
   `sections[2].virtual_address + offset_masks[2]`, and its size is the header's
   `virtual size`. (`ThirdGenHeader.CalculateTagDataSegment`.)
2. **Meta addresses** (`MetaAddressConverter`): everything inside the tag area
   is addressed by virtual address:
   `file offset = address − virtual_base_address + tag_area_file_offset`.
3. **Pointer contraction** (`ThirdGenPointerExpander`, MCC only): the 64-bit
   MCC builds store tag and tag-block pointers squeezed into 32 bits:
   `virtual = (stored32 << 2) + 0x50000000`, writing back as
   `stored32 = (virtual − 0x50000000) >> 2`. `0x50000000` is `<expandMagic>` for
   every Halo: Reach MCC engine in `Engines.xml`. The *index header address* and
   the four table addresses inside the index header are full `uint64`s and are
   **not** contracted; the per-tag `memory address` and in-tag block pointers
   **are**. Xbox 360 maps have no contraction.

All three SPEC-CITED and SYNTHETIC-PROVEN (the self-test builds contracted
addresses and reads them back).

Partitions (6 entries) are load-address/size pairs for the engine's memory
partitions; the tool reports them but does not need them.

## 6. Tag index

Located at the `index header address`, converted with §5 rule 2. Its last field
is the magic `tags` — read as an int in file endianness, i.e. the bytes are
`sgat` in a little-endian MCC map. The parser treats a magic mismatch as fatal:
it is the one cheap, decisive check that the whole header layout was right.

**Index header** — MCC (size 0x4C, `uint64` addresses) / Xbox 360 (size 0x2C, `uint32`):

| Field | MCC | 360 |
|---|---|---|
| number of tag groups | 0x00 | 0x00 |
| tag group table address | 0x08 | 0x04 |
| number of tags | 0x10 | 0x08 |
| tag table address | 0x18 | 0x0C |
| number of global tags | 0x20 | 0x10 |
| global tag table address | 0x28 | 0x14 |
| number of tag interops | 0x30 | 0x18 |
| tag interop table address | 0x38 | 0x1C |
| magic (`tags`) | 0x48 | 0x28 |

**Tag group element** (0x10 bytes):

| Offset | Type | Field |
|---|---|---|
| 0x00 | i32 | group magic — the four-character code, stored so that the int renders big-endian (`'s'<<24 \| 'c'<<16 \| 'n'<<8 \| 'r'` = `scnr`) |
| 0x04 | i32 | parent group magic (`0xFFFFFFFF` = none) |
| 0x08 | i32 | grandparent group magic |
| 0x0C | u32 | string-id of the group's long name (`scenario`, `survival_mode_globals`, …) |

**Tag element** (0x8 bytes — note what is *missing*):

| Offset | Type | Field |
|---|---|---|
| 0x00 | i16 | tag group index (into the group table; −1 = none) |
| 0x02 | u16 | datum index salt (`0xFFFF` = null datum) |
| 0x04 | u32 | memory address (contracted on MCC; `0` or `0xFFFFFFFF` = no data in this map) |

- A tag's **datum index** is `(salt << 16) | position_in_tag_table`; tag
  references elsewhere carry the datum, and the low 16 bits index this table.
- There is **no size field**. Assembly never needs one because it walks a tag
  through a field layout. The tool therefore *estimates* each tag's extent as
  the gap to the next tag address in the tag area (last tag runs to the end of
  the area). **HEURISTIC** — a dumped `.bin` may carry trailing padding, and if
  the mod author inserted data it may carry more than one tag's worth. Each
  dump gets a `.json` sidecar flagging `size_is_estimated: true`.
- A **null** address in a non-shared map means the tag is resident in a shared
  cache (`shared.map`, `campaign.map`) instead. Expect many of these.

**Global tag element** (0x8): `{i32 group magic, u32 datum index}` — this is how
you find *the* scenario without scanning: `global['scnr']`. `matg` (globals) and
friends appear here too.

**Tag interop element** (0x8): `{u32 pointer, i32 type}`.

## 7. String-id table and tag-name table

Both are "indexed string tables": a count, an index table of `int32` offsets,
and a data blob of NUL-terminated strings; offset `−1` means no string.
Both live in the debug section, so their header offsets are converted with §5
rule 1. (`ThirdGenCacheFile.LoadFileNames` / `.LoadStringIDs`.)

- **Tag names**: one entry per tag, in tag-table order, holding the full tag
  path without extension, e.g. `levels\dlc\cex_ff_halo\cex_ff_halo`. This is the
  listing that tells you which scenario and squad tags an author touched.
- **String-ids**: Reach's bit layout is `indexBits=17, namespaceBits=8,
  lengthBits=7` (`Reach_StringIDs.xml`), i.e. index = bits 0–16, namespace =
  bits 17–24, length = bits 25–31. Values are *not* plain indices: each
  namespace maps onto a window of the global table.
  - MCC U3 and later ship a **string namespace table** in the cache (count +
    offset in the header): an `int32` string count per namespace, from which the
    windows are derived exactly as `ThirdGenCacheFile.LoadStringIDNamespaces`
    does — namespace *n*>0 starts at the running total, namespace 0 starts last
    with `min_index = counts[0]`. The tool reproduces this. SYNTHETIC-PROVEN.
  - MCC 2019 and Xbox 360 builds have no such table; Assembly uses a static
    per-build XML (`ReachMCC_StringIDs.xml`, `Reach_StringIDs.xml`). The tool
    does **not** implement that: it resolves ids as plain indices and prints a
    warning. Fine for `mcc-u8+` maps, wrong for 2019-era ones.
  - Deviation from Assembly, deliberate: Assembly subtracts whole string-id
    *values*, which assumes the length field is zero. The tool does the
    arithmetic on the index field only, so a populated length field cannot
    corrupt the result.
- On **Xbox 360** both tables are AES-encrypted (`Engines.xml` keys
  `LetsAllPlayNice!` for tag names, `ILikeSafeStrings` for string-ids,
  `BungieHaloReach!` for locales). The tool does not decrypt: it returns
  `<encrypted>` placeholders and says so. UNTESTED/not implemented — irrelevant
  for this project, which only deals with MCC maps.

## 8. MCC vs Xbox 360 Reach, summarised

| | Xbox 360 Reach | Reach in MCC (PC) |
|---|---|---|
| endianness | big (`head`) | little (`daeh`) |
| engine version @0x4 | 12 | 12 (2019–2020), 13 (U3+) |
| build string format | `11860.10.07.24.0147.omaha_relea` | a C `__DATE__ __TIME__`, e.g. `Jun 21 2023 15:35:31` |
| pointers | 32-bit, no contraction | 64-bit virtual base; tag pointers contracted `(p<<2)+0x50000000` |
| index header | 0x2C, `uint32` addresses | 0x4C, `uint64` addresses |
| tag names / string-ids | AES-encrypted | plaintext |
| string-id namespaces | static table per build | shipped in the cache (U3+) |
| header layout | stable | **moved twice**: 2019 → U3 → U8+ |
| compression | none | none on PC (see §9) |
| header size | 0xA000 | 0xA000 |
| tag group set | 177 plugins in Assembly | 72 overridden + fallback to the 360 set; same group codes |

## 9. Compression — what MCC actually does

The brief expected chunk compression. The cited answer is narrower:

- **PC MCC maps are not compressed.** No Halo: Reach MCC engine in Assembly's
  `Engines.xml` declares a `<compression>` element, and the default is `none`.
  Assembly opens `haloreach/maps/*.map` straight off disk. The only engines in
  the whole database that declare compression are: `cexbox` (Halo 1 Xbox),
  `cea360` (H1 Anniversary 360, LZX, unsupported even by Assembly), `ceamcc`
  (H1 Anniversary MCC), `h2mcc` (Halo 2 MCC) and `xb1mcc` (the **Xbox One
  2014** builds of H2A, Halo 3 and Halo 4). There is no Xbox One Reach build,
  so the per-section LZMA scheme cannot apply to a Reach map.
- Therefore: a Reach `.map` that does **not** start with `daeh` is either
  not a Reach map, or has been packed by something other than the game.
- The four schemes, for triage (`src/Blamite/Compression/`):

| Scheme | Shape |
|---|---|
| `ceamcc` (H1A MCC) | `int32 chunk_count` at 0x0, then that many `int32` chunk offsets; each chunk = `int32 decompressed_size`, 2-byte zlib header, raw deflate. Implemented as `reach_cache.decompress_saber_gen1`. UNTESTED. |
| `h2mcc` (H2 MCC) | uncompressed header, then a table of `{int32 compressed_size, int32 offset}`; `size < 0` = stored raw; chunk size `0x40000`. Implemented as `decompress_saber_gen2`. UNTESTED. |
| `xb1mcc` (XB1 2014 H2A/H3/H4) | the four interop *sections* are compressed individually; header arrays `compressed section offsets/sizes/types`; type 0 = raw, type 3 = LZMA whose dictionary-size byte is packed as `((b>>1)&0x1F)+10` shift; sections are rewritten in the order 0,1,3,2 and the offset masks fixed up. Not implemented — the Reach layouts have no such header fields, so it is unreachable for Reach. |
| `cea360` | LZX. Not implemented by anyone public. |

The parser's behaviour on a non-cache file: it runs `probe_compression()`,
which names a raw zlib stream, a bare LZMA stream, XZ, a zip, a Halo
Infinite-style `.module`, a `ceamcc`-shaped chunk table or an `h2mcc`-shaped
chunk table, prints the first 16 bytes if nothing matches, and exits **3**.
SYNTHETIC-PROVEN (each branch has a test).

## 10. The tag groups this project needs

Four-character codes confirmed against the MCC tag-definition dump
(`research/_raw/reach-defs/_meta.json`), which corrects two guesses in the brief:

| Code | Tag group | Why we care |
|---|---|---|
| `scnr` | `scenario` | squads, squad groups, character/weapon/vehicle palettes, trigger volumes, scripts, survival-mode flags |
| `smdt` | **`survival_mode_globals`** | the Firefight globals: wave templates, round/bonus structure, FF dialogue and strings. (The brief's `sudd` is the Halo 3: ODST name; Reach uses `smdt`.) |
| `sqtm` | `squad_template` | the Firefight squad palette: cell templates, character type, initial weapon/equipment/grenade, difficulty, major upgrade chance |
| `wave` | `wave_template` | wave definitions referenced by survival mode |
| `msit` | `megalo_string_id_table` | the Megalo string-id table (a block of string-ids) — the bridge to the gametype work in research/01–02 |
| `char` | `character` | AI character definitions referenced by squad cells |
| `weap` | `weapon` | **not `wpon`** |
| `vehi` | `vehicle` | |
| `bipd` | `biped` | |
| `mulg` | `multiplayer_globals` | |
| `matg` | `globals` | |
| `hsc*` | `scenario_hs_source_file` | HaloScript *source text* embedded in the map — directly comparable with `src/hsc/*.hsc` |
| `ai**` | `scenario_ai_resource` | AI data split out of the scenario |

`tools/map/reach_tag_groups.json` carries all 238 Reach MCC group codes, so the
listing prints a long name for every group even when the in-cache string-id
table cannot be resolved.

### 10.1 Where the Firefight data sits inside those tags (next layer's problem)

Not implemented here, but already located, from Assembly's **Xbox 360** Reach
plugin `src/Assembly/Plugins/Reach/scnr.xml` (MCC offsets differ — use
`Plugins/ReachMCC/scnr.xml` and the JSON definition dumps):

- `scnr` `Squad Groups` tagblock at 0x3A0, element 0x28
- `scnr` `Squads` tagblock at 0x3AC, element 0x6C; a squad carries
  `Squad Template Name` (string-id) and a `Squad Template` tag reference
- `scnr` `Character Palette` at 0x400, element 0x10
- `scnr` flags include `Survival Mode` (bit 0) and `Survival Mode Elite` (bit 1)
- `sqtm` holds `Cell Templates` with `Character Type`, `Initial Weapon`,
  `Initial Secondary Weapon`, `Initial Equipment`, `Grenade Type`, `Chance`,
  `Difficulty`, `Major Upgrade`
- `msit` is a single tagblock of `stringid` at 0x0, element 0x4

Field-level structures for `scenario`, `survival_mode_globals`,
`squad_template`, `wave_template`, `character` and
`scenario_hs_source_file` are in `research/_raw/reach-defs/*.json` — the dump
from the MCC executable, which is the best public description of the MCC-era
(not 360-era) field order.

Generic in-tag structures, from `ReachMCC_Layouts_Core.xml`, needed to walk any
of those tags:

| Structure | Size | Fields |
|---|---|---|
| tag block (array) | 0xC | `i32 entry count` @0x0, `u32 pointer` @0x4 (contracted) |
| tag reference | 0x10 | `i32 group magic` @0x0, `u32 datum index` @0xC |
| data reference | 0x14 | `i32 size` @0x0, `u32 pointer` @0xC |
| `hsc*` tag | — | `asciiz name` @0x0, `i32 source size` @0x20, `u32 source pointer` @0x2C |

## 11. The tool

### Usage

```bash
# header + full tag listing
python3 tools/map/parse_map.py /path/to/cex_ff_halo.map

# the same, plus dump the interesting tags to ./extracted/cex_ff_halo/
python3 tools/map/parse_map.py /path/to/cex_ff_halo.map --extract

# pick groups, or take everything, or also dump the whole tag area
python3 tools/map/parse_map.py MAP --extract --groups scnr,smdt,sqtm,wave,msit
python3 tools/map/parse_map.py MAP --extract --all-tags
python3 tools/map/parse_map.py MAP --extract --dump-meta        # writes meta.bin

# machine-readable, for the next agent
python3 tools/map/parse_map.py MAP --json > map.json
python3 tools/map/parse_map.py MAP --list-only                  # just the tag table

# last resort if the build string is unknown and detection refuses
python3 tools/map/parse_map.py MAP --variant mcc-u8+

# prove the reader against synthetic caches (no .map needed)
python3 tools/map/parse_map.py --self-test
python3 -I tools/map/test_parse_map.py
```

Stdlib only (`struct`, `json`, `zlib`, `pathlib`, `argparse`). No third-party
dependency. `zlib`/`lzma` would only be needed by the decompressors in §9,
and `zlib` is stdlib.

### Output of `--extract`

```
extracted/<map stem>/
  header.json        every header field, sections, partitions, index header, warnings
  tags.tsv           index, datum, group, group name, file offset, estimated size, address, path
  tags.json          the same, machine-readable
  tag_groups.tsv     group code, parent, long name, name string-id
  tag_names.txt      the raw tag-name table
  stringids.txt      the raw string-id table (resolved index -> string)
  manifest.json      what was written, skipped and errored
  tags/NNNN_<group>_<path>.bin   one file per extracted tag
  tags/NNNN_<group>_<path>.json  sidecar: virtual address, file offset, size, and the exact
                                 pointer arithmetic needed to follow pointers inside the blob
  hsc/NNNN_<name>.hsc            HaloScript source text from hsc* tags (best effort)
  meta.bin                       the whole tag data area (only with --dump-meta)
```

The sidecar is the important part for the next agent: it records
`virtual = (stored << 2) + 0x50000000`,
`map offset = virtual − virtual_base + tag_area_offset`, and
`offset inside this dump = virtual − tag_address`, with that map's actual
numbers substituted.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | parsed |
| 2 | contradicts the spec: bad index magic, impossible offset, implausible count, truncated file |
| 3 | not a flat cache file — looks compressed/packed (triage printed) |
| 4 | cache header found but no known layout fits (probably a newer MCC build) |

### Failure behaviour (deliberate)

Every derived offset is bounds-checked against the real file length before any
read; failures name the field, the raw value and the computed offset. The
index-header `tags` magic is a hard gate. Implausible counts (groups/tags/
globals/interops outside 0…65536, string counts over 1,000,000) are fatal.
A single tag whose address falls outside the tag area is a warning, not a
crash — the tag is marked unresolved and excluded from extraction. Stale header
`file size`, a missing footer magic, an all-zero section table, a tag-name count
that disagrees with the tag count, and an unknown build string all produce
loud `!!` warnings in the report.

## 12. Proven vs untested

| Area | Status |
|---|---|
| magic/endianness/version detection, footer check | SPEC-CITED, SYNTHETIC-PROVEN |
| all four header layouts (field offsets) | SPEC-CITED — **offsets unverified against a real map** |
| build string → layout table | SPEC-CITED (transcribed from `Engines.xml`), SYNTHETIC-PROVEN |
| structural fallback when the build is unknown | SYNTHETIC-PROVEN (incl. the refusal case) |
| section/offset-mask maths, meta address → file offset | SPEC-CITED, SYNTHETIC-PROVEN |
| pointer contraction/expansion (`0x50000000`) | SPEC-CITED, SYNTHETIC-PROVEN |
| index header + group/tag/global/interop tables | SPEC-CITED, SYNTHETIC-PROVEN |
| tag-name table, string-id table | SPEC-CITED, SYNTHETIC-PROVEN |
| string-id namespace resolution from the in-cache table | SPEC-CITED, SYNTHETIC-PROVEN (with one deliberate deviation, §7) |
| string-id resolution on 2019-era/360 builds (static XML tables) | **not implemented** — warns |
| tag extent (size) estimation | HEURISTIC |
| tag extraction + sidecars + listing | SYNTHETIC-PROVEN |
| `hsc*` source extraction | SPEC-CITED, SYNTHETIC-PROVEN against a synthetic `hsc*` tag; the real layout has only ever been read by Assembly |
| compression triage messages | SYNTHETIC-PROVEN |
| `ceamcc` / `h2mcc` decompressors | UNTESTED (and not needed for Reach) |
| `xb1mcc` per-section LZMA | documented, **not implemented** |
| Xbox 360 big-endian parse | SYNTHETIC-PROVEN for the container; AES decryption **not implemented** |
| resource/raw ("zone") data, locale strings, resource gestalt | out of scope |

Self-test result at time of writing: **195 assertions, 0 failures**, across all
four layout variants, extraction, the CLI, and 15 failure paths.

## 13. First contact checklist (do this when `cex_ff_halo.map` arrives)

1. `python3 tools/map/parse_map.py <map> --no-list` and read the top block.
   Check in this order: magic/endianness, engine version (expect 13), build
   string (expect a `Mon DD YYYY HH:MM:SS` form; if it is not in §4.1 the tool
   will say `!! UNKNOWN BUILD`), `footer magic present: True`, cache type
   (expect multiplayer for a Firefight map), scenario path (expect something
   like `levels\dlc\cex_ff_halo\cex_ff_halo`).
2. Confirm the tag counts look sane: a Reach MP/FF map has on the order of
   1,000–10,000 tags, hundreds of groups, and a large null-tag count (tags
   resident in `shared.map`).
3. Confirm the group census contains exactly one `scnr`, and that `smdt`,
   `sqtm`, `wave`, `msit` are present. If `smdt`/`sqtm` are **absent**, the
   Firefight palette is coming from a shared cache and the mod's changes are
   in `scnr` alone — that is itself a finding.
4. `--extract` and diff `tags.tsv` against the same listing from the *stock*
   `cex_ff_halo.map` (copy it out of the MCC install). The tags whose estimated
   size or path changed are exactly the author's edits. This diff is the
   fastest route to "what did the mod change".
5. Sanity-check one extracted blob by hand before building anything on it: the
   extents are estimates (§6).
6. Any `!!` warning in the report means stop and re-read this document before
   trusting the listing.

## 14. Known gaps and risks

- **The header offsets are unverified.** If a current MCC build moved the header
  a third time, detection will refuse (exit 4) rather than mislead — but it also
  will not parse. The fix is to compare the first 0x400 bytes against §4 and add
  a variant.
- Tag sizes are estimated, not read (§6). Anything that depends on exact tag
  extents must verify them through a field layout.
- Resource/raw data (`zone`, `play`, resource gestalt pages) is not touched, so
  tags whose payload lives in the resource section will extract as their base
  data only.
- Shared-cache resolution is not implemented: null tags are reported, not
  chased into `shared.map`.
- Locale/unicode strings (`unic`, the `matg` language block) are not read.
- Writing is not implemented at all. This is a read-only tool; the project's
  edit path remains the gametype `.bin` work in research/01–03.
