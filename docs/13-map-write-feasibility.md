# Can a Halo: Reach MCC `.map` be modified and written back? — write feasibility

Tooling added by this document: `tools/map/reach_write.py` (writer library + CLI),
`tools/map/test_reach_write.py` (self-test, **387 assertions, 0 failures**, synthetic only).
Reader side unchanged: `tools/map/reach_cache.py`, `tools/map/parse_map.py`
(195 assertions, still passing).

Prior art this builds on, not repeated here: `research/07-map-container-format.md`
(header, tag index, pointer arithmetic, four MCC layout variants, and the finding that PC
MCC Reach maps are **not compressed**), `research/08-haloscript-decompile.md` (script node
format, per-build opcode tables), `research/01-blf-container-format.md` (the methodology:
parse, recompute integrity, prove a byte-identical round-trip, only then modify),
`research/04-workshop-mod-teardown.md` (mod package layout, EAC-disabled launch).

---

## 0. Verdict, up front

1. **No integrity check blocks binary patching.** The only whole-file integrity value in a
   Reach cache is a header `checksum` int32, which is an XOR of every `uint32` after the
   0xA000 header. It is trivially recomputable, and the evidence says the engine does not
   even check it. There is **no signature, no per-tag hash, and no hash over tag data**.
2. **The writer achieves a byte-identical field-level round-trip** on all four header layout
   variants and on two different section orderings — **against synthetic caches only**. No
   real `.map` has ever been opened by this project.
3. **Tags can be grown**, by growing the tag data area and relocating the tag into the new
   space. Implemented, tested both ways (grow-at-end and Assembly's grow-downward), including
   re-basing a pointer that lived inside the moved tag.
4. **Script injection is a month-scale job, not a weekend** — and the true blocker is not the
   file format, it is that the result can only be tested on Windows.
5. **The cheapest useful modification is a same-size numeric patch of a script expression
   node's 4-byte `value` field** (a price, a timer, a count). That is one `struct.pack_into`
   plus a checksum, with zero pointer arithmetic. It is reachable today.
6. **Assembly's recompiler algorithm is portable to Python** and Reach MCC is a first-class
   target of it. About 20 % of the work is serialising tables; about 80 % is parsing and
   type-checking HaloScript.

---

## 1. Integrity: exactly what a Reach MCC cache protects

### 1.1 The one checksum

Assembly `src/Blamite/Blam/ICacheFile.cs:229` (`CacheFileExtensions.GenerateChecksum`):

- seek to `HeaderSize` (0xA000 for every Reach build);
- read to EOF in 0x10000 blocks, rounding each block up to a multiple of 4;
- XOR every `uint32` (file endianness) into a running 32-bit accumulator;
- optionally byte-reverse the result if the engine sets `<reverseChecksum>` — **no Reach
  engine does**; `Engines.xml:37` says it is "only seen in alpha/beta H3".

It is written back into the header field `checksum` by
`ThirdGen/ThirdGenCacheFile.cs:59-80` (`SaveChanges`), *after* everything else, because
`WriteLanguageInfo` writes into the region the checksum covers. Offsets of the field, per
`research/07` §4: 0x2D0 (mcc-2019), 0x2CC (mcc-u3), **0x360 (mcc-u8+)**, 0x2C4 (Xbox 360).

Implemented as `reach_write.checksum_of()` / `CacheWriter.update_checksum()`.
Because the checksum starts at 0xA000 and the field lives inside the header, it is **not
self-referential**: header edits do not change it, tag-data edits do. Both proven by test.

### 1.2 Does the game enforce it? Evidence says no

| Evidence | Source | Reading |
|---|---|---|
| Assembly parses `checksum` into a property and **never compares it to anything** on load | grep for `Checksum` across `src/Blamite/Blam/` returns only serialise/deserialise/write sites | a map with a wrong checksum still loads in every tool, and nothing in the format demands correctness |
| "MCC sometimes ships maps with resource hashes and **checksums 0'd out**" | `src/Blamite/Serialization/EngineDescription.cs:164`; `Formats/Engines.xml:33-34` | shipped, retail-loadable maps exist whose integrity fields are zero. A validating loader could not load them |
| Assembly still recomputes it on save | `ThirdGenCacheFile.cs:76` | cheap insurance, not proof of enforcement |
| Modified maps demonstrably load (the Workshop mod in `research/04`, and Assembly's whole purpose) | `research/04`, `research/09` | some modification path exists and is in daily community use |

**Our writer recomputes the checksum anyway**, so the question is moot for us: we are correct
whether or not the engine looks. This is the single thing a real map will settle for free —
see §8.

### 1.3 The hashes that *do* exist, and what they cover

| Hash | Where | Algorithm | Does a tag edit invalidate it? |
|---|---|---|---|
| `index table hash`, `string data hash`, 0x14 bytes each, **per language**, 12 languages | inside the `matg` (globals) tag, `languages` array at 0x18, stride 0x50 (`Formats/ReachMCC/LayoutsU13/..._Core.xml:68-77`) | plain SHA-1 over the locale index table bytes, and over the locale string data bytes (`Blam/ThirdGen/Localization/ThirdGenLanguage.cs:137,144`) | **No** — unless you edit localisation strings. Then yes, and `hashlib.sha1` reproduces it exactly |
| `checksum` + `hash 1/2/3` (0x14 each) per resource page | `Formats/ReachMCC/Layouts/ReachMCC_Layouts_Resources.xml:177-180` | per-page, used by Assembly only to deduplicate injected raw pages | **No** — unless you touch raw/resource pages (geometry, sound, bitmaps) |
| Nothing else | — | — | — |

There is **no** RSA/ECDSA signature field anywhere in any Reach layout (360 or MCC). Grep of
all Reach and ReachMCC layout XMLs for `signature|rsa|hash|checksum` returns exactly the rows
above. The Xbox 360 build encrypts the *string* tables with AES (keys are published in
`Engines.xml`) — irrelevant to PC MCC, and encryption is not authentication anyway.

**Consequence for the project: adding new on-screen text is the one edit that pulls a hash
into scope.** New HUD/UI strings live in the localisation section and would require
recomputing two SHA-1s per language in `matg`. Reusing an existing string, or a string-id
that already exists, avoids this entirely.

### 1.4 The real gate: mod mode, not file hashing

- 343's own support articles state MCC mods do not work with Easy Anti-Cheat enabled; the
  supported path is the Steam launch option *"Play Halo: MCC Anti-Cheat Disabled (Mods and
  Limited Services)"* (`steam://launch/976730/option2`). Already established in
  `research/04` §10.2 with the two article URLs.
- EAC is a process/module integrity system. It gates *whether mod content is loaded at all*;
  it does not hash your `.map`. With it disabled, MCC loads mod-package maps as a supported
  feature.
- The official publishing tool performs **no integrity step at all**: the Excession docs say
  it "simply uploads all contents of the mod folder to Steam Workshop, without any validation"
  (learn.microsoft.com, *Folder Structure, Creating Root Folders, and ModInfo.json*). The
  `ModInfo.json` schema in `research/04` §10.4 has no hash, size or signature field.
- **Therefore the acceptable-modified-map recipe is: a structurally valid cache file, inside a
  mod package, launched with anti-cheat disabled.** Not a signature, not a trusted builder.

Unverified, and worth stating as such: whether overwriting the base install's
`haloreach/maps/*.map` also works. The mod-package route is the officially supported one, it
survives Steam file verification, and it is what the author of the existing mod uses. Prefer it.

---

## 2. The writer, and what its round-trip gate actually proves

`tools/map/reach_write.py` — stdlib only, no new dependencies.

```python
cache = ReachCacheFile.from_path("cex_ff_halo.map")
w = CacheWriter(cache)

w.verify_checksum()                       # (stored, computed, ok)
w.reencode_all()                          # THE GATE: must equal cache.data
w.patch_tag_field(tag, 0x10, "i32", 1500) # same-size numeric edit
g = w.grow_tag_area(0x400)                # -> GrowthResult(free_offset, free_address, ...)
w.relocate_tag(tag, bigger_blob)          # grow a tag: move to the end, repoint
w.relocate_table("tag_table_address", "tag_count", blob, n)
w.shift_internal_pointers(blob, old_base, new_base, [0x2C])
w.update_checksum(); w.save("out.map")
```

CLI:

```bash
python3 tools/map/reach_write.py MAP --verify-checksum   # the decisive real-map test
python3 tools/map/reach_write.py MAP --round-trip        # re-encode and diff
python3 tools/map/reach_write.py --self-test             # 387 synthetic assertions
```

### 2.1 Round-trip: identical, with an honest definition

The writer does **not** regenerate the 0xA000 header from scratch, and neither does Assembly.
Most of that header is padding and fields no public layout describes; regenerating it would
destroy information. "Byte-identical round-trip" here means:

> parse the file, then write **every field the reader parsed** back where it came from —
> every header field (including the asciiz strings), all four sections, all four offset masks,
> all six partitions, the eight index-header counts/addresses, and all N tag-table entries
> re-derived from the parsed `TagEntry` objects — and the file is unchanged, byte for byte.

That catches a wrong field kind, a wrong offset, wrong endianness, a sign error, and in
particular a broken pointer contraction (`(stored << 2) + 0x50000000`), because every tag
address is decoded and re-encoded. It does not and cannot prove that the offsets match a real
map; `research/07` §12 already says those are SPEC-CITED but unverified.

Result: **identical on all four variants × two section orderings.**

### 2.2 What the 387 assertions cover

| Area | Assertions prove | Status |
|---|---|---|
| Field-level round-trip | re-encode is byte-identical, length preserved | SYNTHETIC-PROVEN |
| Checksum | matches the fixture; stable; idempotent; changes on a tag edit; **unchanged by a header edit**; re-verifies after update | SYNTHETIC-PROVEN |
| Same-size in-tag patch | **only** the 4 patched bytes and the 4 checksum bytes change; the value reads back; every table and the whole tag table are untouched | SYNTHETIC-PROVEN |
| Growth, 4 variants × 2 layouts × 2 modes | file grows by exactly the granted amount; virtual size, sections, masks, partitions, table offsets stay self-consistent; the reader re-parses with no bounds warnings; tag names, string-ids, globals, groups and **every tag's bytes** resolve identically; new space is inside the tag area, zeroed, and contractible | SYNTHETIC-PROVEN |
| Debug-section shift | in the realistic ordering the debug section really *did* move by the growth (asserted, so the test cannot pass trivially) | SYNTHETIC-PROVEN |
| Relocating a tag | a tag grown by 0x80 bytes reads back its new contents at its new address; all other tags unchanged | SYNTHETIC-PROVEN |
| Relocating an index table | the tag table moved and repointed; all tags resolve identically through it | SYNTHETIC-PROVEN |
| Growing a tag with an internal pointer | an `hsc*` tag whose source blob grew, with its `0x2C` source pointer re-based, reads back the longer source through the reader's own code path | SYNTHETIC-PROVEN |
| Failure paths (12) | writes past EOF, null-tag edits, over-long in-tag patches, zero/bad-mode growth, unknown fields, unaligned/too-low/too-large pointer contraction, downward growth that would underflow the expand magic — all raise `WriteError` with a specific message | SYNTHETIC-PROVEN |

The existing fixture (`test_parse_map.build_cache`) puts the debug section *before* the tag
area. Real Reach caches are ordered resource, locale, tag, **debug**
(`ThirdGenHeader.cs:~218` comment: *"Section addresses are usually in the following order:
resource, locale, tag, debug"*). A writer that only ever grew a last-in-file tag area would
pass trivially, so `test_reach_write.fixture_debug_last()` rebuilds the fixture in the
shipped order, with raw struct writes rather than with the class under test.

### 2.3 Say it plainly

**This writer has never seen a real map.** 387 passing assertions prove internal consistency
and that encode inverts decode. They do not prove the header offsets, they do not prove MCC
tolerates a resized tag area, and they do not prove the engine loads the output. Until a real
`cex_ff_halo.map` is parsed, every number here is unverified.

---

## 3. Where the slack is

### 3.1 There is no free list, and no stored tag size

- A tag table entry is 8 bytes: `{i16 group index, u16 salt, u32 address}`. **No size.**
  Extents are inferred as the gap to the next tag address (`research/07` §6, HEURISTIC).
- Assembly has exactly the same problem and solves it the same way — its `MetaAllocator`
  starts with an **empty** free list (`ThirdGenCacheFile.cs:50`,
  `new MetaAllocator(this, 0x10000)`). Nothing in the cache records free space.
- So: **assume zero usable slack between tags.** Inter-tag padding exists (tag data is
  aligned), but it is a few bytes, it is unmeasurable without a layout for every tag, and
  the "gap to the next tag" is exactly what the reader already reports as the tag's size.
  Do not grow into it.
- Corollary: an in-place edit is only safe when it is **the same size**. The writer enforces
  this: `patch_tag` refuses a write that exceeds the tag's estimated extent (and says the
  extent is estimated).

### 3.2 Growing works by growing the tag area

Assembly's own mechanism (`MetaAllocator.Expand`, `MetaAllocator.cs:274-289`): round the
request up to the 0x10000 allocator page, call `MetaArea.Resize`, and register the new region
as free. `FileSegmenter.ResizeSegment` inserts the bytes into the file and recomputes the
offsets of every later segment. The tag segment is defined with
`SegmentResizeOrigin.Beginning`, so the space appears at the *start* of the tag area and
`MetaAddressConverter.MetaResized` compensates by **decrementing the virtual base** —
*"the meta segment grows downward in memory"*. Segment alignment for every Reach MCC engine
is `<segmentAlignment>0x1000</segmentAlignment>`.

`CacheWriter.grow_tag_area(size, mode=...)` implements both directions:

| | `mode="end"` (default) | `mode="beginning"` (Assembly's) |
|---|---|---|
| Insert point | end of the tag area | start of the tag area |
| Existing tag addresses | unchanged | unchanged (base moves down by the same delta) |
| Virtual base | unchanged | `-= delta` |
| New space addresses | `base + old_size …` | `new_base … old_base` |
| Risk | the debug section (string-id + tag-name tables) shifts and must be re-pointed | the base can underflow the `0x50000000` expand magic, after which pointers cannot be contracted — the writer refuses this case |

Both are tested. **Prefer `mode="end"`**: it never touches the virtual base, so no contracted
pointer anywhere in the file changes meaning, and the underflow class of bug cannot occur.

Fields the writer fixes up on growth (this list *is* the answer to "what breaks if you just
append bytes"):

1. header `virtual_size` — the tag area's size;
2. `sections[tag].size`, and `sections[*].virtual_address` for every area whose file offset
   moved (masks are preserved, so the rule-1 identity `file offset = vaddr + mask` still
   holds; on a shipped map every mask is 0 and the vaddr *is* the file offset, which makes
   this identical to Assembly's `RebuildInteropData` result);
3. header `tag_buffer_offset`;
4. header `virtual_base_address` (downward mode only);
5. header `file_size`;
6. the five debug-section pointers in the header —
   `string_index_table_offset`, `string_table_offset`, `string_namespace_table_offset`,
   `file_index_table_offset`, `file_table_offset`;
7. all six **partitions**, mirroring `ThirdGenHeader.AdjustPartitions`: partition 0's load
   address becomes the tag area's base, and sizes are recomputed from the end of the tag area
   backwards so the last live partition absorbs the growth;
8. the `checksum`, last.

`index_header_address`, every tag address and every in-tag pointer are deliberately **not**
touched: in end mode nothing inside the tag area moved, and in downward mode the file shift
and the base shift cancel exactly.

### 3.3 So: can a tag be grown?

Yes — by moving it, not by stretching it in place. `CacheWriter.relocate_tag(tag, blob)`
grows the area, writes the bigger blob into the new space, zeroes the vacated bytes (what
Assembly's allocator does on free), re-contracts the address into the tag table entry, and
recomputes the checksum. Any pointer *inside* the blob that pointed into the blob must be
re-based first; `shift_internal_pointers()` does that, and the `hsc*` test exercises it
end-to-end.

The cost is one 0x1000–0x10000 page of file growth per relocation (batch your edits), and
the risk is that MCC may care about something in the tag area that no public layout describes.

---

## 4. Script injection: what must change, in order

### 4.1 The tables (`scnr`, Reach MCC — Assembly `Formats/ReachMCC/.../_Scenario.xml`)

| Table | base `Layouts` offsets (U8–U12) | `LayoutsU13` offsets | Element |
|---|---|---|---|
| script **string** blob (data reference) | size 0x43C, address 0x448 | size 0x41C, address 0x428 | raw NUL-terminated Windows-1252 strings |
| **scripts** | count 0x450, address 0x454 | count 0x430, address 0x434 | 0x18 |
| script **globals** | count 0x45C, address 0x460 | count 0x43C, address 0x440 | 0x28 |
| script **tag references** | count 0x468, address 0x46C | count 0x448, address 0x44C | 0x10 |
| script **expressions** (the syntax nodes) | count 0x524, address 0x528 | count 0x504, address 0x508 | 0x18 |
| script **parameters** | per-script block, pointed to by each script element | — | 0x24 |

Script element (0x18): `i32 name stringID` @0x0 (Reach uses a stringID, Halo 3 used a
0x20-byte ASCII name), `i16 execution type` @0x4, `i16 return type` @0x6,
`i32 first expression datum` @0x8, `i32 parameter count` @0xC,
`u32 parameter list address` @0x10 (contracted), `u32 unknown` @0x14 (written as 0).

Expression / syntax node (0x18): `u16 datum salt` @0x0, `u16 opcode` @0x2,
`i16 value type` @0x4, `i16 expression type` @0x6, `u32 next expression datum` @0x8,
`u32 string table offset` @0xC, `u32 value` @0x10, `i16 source line` @0x14.
Datum indices are allocated linearly from salt `0xE373` (`SaltGenerator.GetSalt("script node")`),
so a node's list position equals its datum index; siblings are chained through
`next expression index`, terminated by `0xFFFFFFFF`.

Script global (0x28): asciiz name @0x0, `i16 type` @0x20, `u32 initialiser expression datum` @0x24.

### 4.2 Ordered edit plan to add "buy a marine squad"

A purchase needs: a currency read, a comparison, a deduction, a spawn, and some feedback.
In node terms that is on the order of 50–200 new expression nodes plus 1–3 new scripts.

1. **Decide what already exists.** Enumerate the `scnr` script table, the string blob, and
   the squad/object script-context blocks. Everything you can reuse is work you do not do.
2. **Build the new node list.** Easiest correct approach: read the existing expression table,
   append nodes, keep every existing datum index stable. Appending is safe because datum
   index == array position, so existing `next` links do not move.
3. **Extend the script string blob** with any new function/object/script names. Offsets are
   byte offsets into the blob and the blob is append-only if you keep existing entries in
   place; node `string table offset` fields point into it.
4. **Append script elements** for the new scripts (`static`/`dormant`/`continuous` per the
   `scriptTypes` enum in the per-build opcode XML), each pointing at its root node datum.
5. **Add the script name stringID.** Reach script names are stringIDs, not inline ASCII, so a
   new script name means a **new entry in the cache's string-id table**, which lives in the
   *debug section*: bump `string_table_count`, append to the string data and the index table,
   and (U3+) fix the namespace counts. That region is addressed by header offsets, so it has
   to be grown and re-pointed exactly like the tag area. Cheaper alternative: **reuse an
   existing stringID** and accept an odd script name.
6. **Add any new tag references** (0x10 each) if the new script names a tag that the scenario
   does not already reference.
7. **Reallocate each changed table** into fresh space (`relocate_table` pattern: grow, write,
   repoint address, update count) and write the six `scnr` count/address pairs.
8. **Only then** the AI side. The marine squad itself is the hard part, see §4.3.
9. Recompute the checksum. Package. Test on Windows.

### 4.3 The part that is not about file format at all

Assembly's script compiler **does not write the script-object blocks** — `object_name`,
`trigger_volume`, `cutscene_flag`, `ai_squad`, `unit_seat_mapping` are read only so that
names can be resolved to indices. *You cannot add new objects with it.* A genuinely new
marine squad needs a new element in the scenario's Squads block (0x6C per element on the 360
layout, `research/07` §10.1), a character palette entry, spawn positions, firing positions and
— on Reach — AI data that lives partly in `scenario_ai_resource` (`ai**`) tags. That is what
Sapien authors. Hand-assembling it blind, with no renderer and no validator, is the single
riskiest thing in this document.

**Do not author a new squad. Retarget an existing one.** `cex_ff_halo` already ships friendly
AI, a Pelican delivery script and a follow-the-player ODST (`research/04` §11.3). An existing
squad already has valid positions, a valid palette entry and valid AI data. Changing *which
character it spawns*, *how many*, and *when* is a small-field edit; conjuring a new squad is not.

### 4.4 Honest difficulty rating

| Job | Estimate |
|---|---|
| Patch numeric literals in existing nodes | hours |
| Retarget an existing squad / purchase (stringID, datum, count edits) | a weekend, most of it spent identifying the right fields |
| Hand-assemble 20–50 nodes for one new conditional spawn, reusing existing strings and stringIDs | 1–2 weeks |
| Port a usable HaloScript → node compiler (the `fe_*.hsc` sources in `src/hsc/`) | **1–3 months** |
| Author new squads/AI data blind, no HREK | do not attempt |

The schedule driver is not the code. It is that **nothing here can be tested on macOS.**
Every iteration is: patch on the Mac, copy to Windows, launch MCC with anti-cheat disabled,
load Firefight, observe, guess. A silent failure mode (the script simply never fires) costs a
full round trip to diagnose. Assembly's own UI warns its compiler is "not 100 % accurate and
could corrupt the map in rare cases" — and Assembly's authors could iterate in seconds.

---

## 5. How Assembly does it, and whether that ports

Read: `src/Blamite/Blam/Scripting/ScnrScriptFile.cs` (the writer),
`.../Compiler/ScriptCompiler.cs` (~46 KB ANTLR listener) and friends.

**Reach MCC is a supported target.** There is no Halo 3/ODST-only guard:
`ScnrScriptFile.cs:272-283` maps a build whose name contains `"Halo: Reach"` to
`ScriptLayout.HaloReach` and only throws `NotImplementedException` for anything it does not
recognise; the editor enables compilation for Reach at
`src/Assembly/.../Editors/ScriptEditor.xaml.cs:107`. U13 uses `LayoutsU13` plus
`ReachMCC_U13_Scripting.xml` (1882 functions, 1716 globals, the typecast table, script types
and value types).

**Compiler shape.** Top-down, expected-type-driven walk of an ANTLR parse tree, emitting a
flat array of 0x18-byte nodes. Links are fixed up with a stack of "nodes whose `next` is still
pending" (`ScriptCompilerUtility.cs:130-203`): open a datum when you append a node, link it
when the next sibling appears, close it at the end of the call. `(f a b)` becomes a *group*
node whose `value` is the datum of the `function_name` node, then the arguments chained after
it. A script body is wrapped in a synthetic `begin`. `cond` is lowered to nested `if`s.
`branch` synthesises an extra static script `<from>_to_<to>`. Strings are interned in a
dictionary with running byte offsets; non-string nodes reuse the `string table offset` field
to store the source character position (which is why it must be ignored when it exceeds the
blob size).

**Writer order** (`SaveScripts`, `ScnrScriptFile.cs:71-96`): expressions → string blob →
globals → tag references → parameter blocks → scripts → write the `scnr` struct back; then
the caller runs `cache.SaveChanges`, which saves the tag table, tag names, string-ids, the
header, language info and the checksum. Each table is `Reallocate`d: same size is a no-op,
shrink frees and zeroes the tail, grow extends in place if an adjacent free block exists and
otherwise allocates, copies and zeroes the old block.

**Portability.** The algorithm is ordinary bookkeeping — no cryptography, no undocumented
engine behaviour, nothing that needs .NET. Dependencies and their Python substitutes:

| Dependency | Port |
|---|---|
| `ANTLR/HS_Gen1.g4` grammar | not required — HaloScript is s-expressions; a 200-line hand-written reader does it |
| per-build opcode XML (`ReachMCC_U13_Scripting.xml`) | **reuse as-is**, `xml.etree` |
| layout XMLs | reuse as-is, or transcribe the six offsets in §4.1 |
| `MetaAllocator` + `FileSegmenter` + `IStream` | already replaced, in miniature, by `reach_write.py` (`grow_tag_area`, `relocate_*`) |
| compiler listener, type handling, type stack, context generator | ~3,500 lines of C# to port — the bulk |

Rough split by line count: **~20 % serialise the tables, ~80 % parse and type-check**. The
cheapest credible validation strategy, and the one to copy from the `.bin` work: decompile a
real map's scripts, recompile them unchanged, and require the bytes to match. Known compiler
gaps to inherit knowingly: several value types have no handler at all
(`ai_command_list`, `ai_behavior`, `ai_orders`, `conversation`, `style`, `damage_effect`,
`cutscene_recording`, budget references), 660 of 1882 U13 functions are marked `null="true"`
and unchecked, and the datum-salt wrap bug at salt `0xFFFE` bites at ~7,308 nodes.

---

## 6. Difficulty ranking, and the cheapest useful modification

| # | Modification | Mechanism | Difficulty | Reachable on macOS today? |
|---|---|---|---|---|
| 1 | **Change a number inside an existing script: a price, a timer, a count, a threshold** | find the expression node whose `value` @0x10 holds it; same-size `patch_tag_field`; recompute checksum | **trivial** — 4 bytes, no pointer maths | **Yes** |
| 2 | Change a numeric field in `sqtm` / `smdt` / a squad element (cell count, chance, difficulty, wave counts) | same-size patch | trivial–easy, once the field is identified | Yes |
| 3 | Change a tag reference or a stringID an existing node/field points at — e.g. retarget a purchase at a different squad, or a squad cell at a different `char` | same-size 4-byte datum/stringID write; the target tag and string must already exist in the map | easy | Yes |
| 4 | Edit `hsc*` source text | same-size patch | trivial **and useless** — `hsc*` is the stored *source*; the engine executes the expression table. Changing the text changes nothing. Worth knowing before someone wastes a day on it |
| 5 | Grow a tag (bigger blob, moved and re-pointed) | `relocate_tag` | moderate; implemented and tested | Yes, mechanically |
| 6 | Add a handful of nodes for one new condition (reusing existing strings and stringIDs) | append nodes, reallocate the expression table, update count+address | hard; 1–2 weeks | Build yes, validate no |
| 7 | Add a new script with a new name | #6 plus a new string-id table entry in the debug section | harder — the debug section must be grown and re-pointed too | Build yes |
| 8 | Add new on-screen text | localisation edit, plus two SHA-1s per language in `matg` | moderate but a different subsystem | Yes, with `hashlib` |
| 9 | Compile `src/hsc/*.hsc` into a map | full compiler port | 1–3 months | No |
| 10 | Author a new marine squad with AI data | new squad/palette/position/`ai**` data, no validator | do not attempt | No |
| 11 | Copy the author's purchase system into a *different* map | cross-cache tag injection (Assembly's `TagContainerInjector`) | months | No |

### 6.1 The answer the project should probably act on

**If the user obtains the author's map, the useful subset is #1 + #2 + #3, and that is a
real feature set:** retune prices, squad sizes, cooldowns, wave composition and *which*
squad a purchase delivers — all as same-size patches, all reachable from macOS, all
recomputable with a tool that already exists and whose arithmetic is tested. No new script
logic, no growth, no HREK.

What it cannot do: invent a purchase where none exists, and copy his purchase onto a map that
does not have one (#11). Duplicating a purchase *within* the same map is #6/#7 territory — it
needs new nodes, because each purchase is a distinct branch of script.

Starting instead from the **stock** `cex_ff_halo`, #1–#3 still buy something: that scenario
already has friendly AI and a delivery script, so changing when/how many allies arrive is a
numeric edit. A *purchase* (score check, deduction, prompt) is new logic, i.e. #6.

---

## 7. Residual risks

1. **The header offsets are unverified** (`research/07` §12). Everything in this document
   inherits that. A current MCC build may have moved the header a third time; detection
   refuses rather than misleads (exit 4).
2. **Tag extents are estimates.** `patch_tag` refuses a write past the estimate, which may be
   a false alarm; it may also *fail to* refuse one, if two tags share an estimated extent.
3. **The engine may validate something no public layout names.** Nothing in Assembly's model
   suggests it, and the community's modified maps load, but we are reasoning from a tool's
   source and not from the game's.
4. **Growth is the least-evidenced operation.** Assembly resizes the tag area routinely and
   its output loads, which is good evidence; but our *implementation* of that resize has only
   ever been checked against synthetic files, and in the opposite direction (end vs beginning)
   from Assembly's.
5. **Mod-package build is still untested end to end.** `ModInfo.json`, the `firefight/*.json`
   descriptors and the Workshop upload path (`research/04` §10.4) have never been exercised
   by this project.
6. **No feedback loop on macOS.** Restated because it is the dominant cost of every item
   above #5.

---

## 8. First contact: what to do the minute a real `.map` exists

In this order. Each step is cheap and each one can falsify a load-bearing assumption.

1. `python3 tools/map/parse_map.py MAP --no-list` — read the header block exactly as
   `research/07` §13 describes. Any `!!` means stop.
2. `python3 tools/map/reach_write.py MAP --verify-checksum`.
   **This is the single most valuable test in the project.** If stored == computed, then the
   header layout, the header size, the checksum algorithm and the file's own integrity are
   all confirmed at once, from one number. If it is zero, the map was built by something that
   leaves it blank — also informative (and consistent with
   `EngineDescription.cs:164`). If it is non-zero and wrong, re-read §1.1 before touching
   anything.
3. `python3 tools/map/reach_write.py MAP --round-trip` — must report IDENTICAL. If it does
   not, the diff offsets name the fields whose spec is wrong.
4. Diff the tag listing against the **stock** map (`research/07` §13.4) to find the author's
   edits.
5. Dump the `scnr` script expression table using the offsets in §4.1 and look for the price
   as a literal `value`. Then do the cheapest modification (§6.1, #1) and nothing else.
6. Only after a modified map has loaded in MCC should anything in §4.2 be started.
