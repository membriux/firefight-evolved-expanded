# `tools/patch` — the surgical patch tool

Change a number inside a built Halo: Reach MCC `.map` without moving a single
byte. No compiler, no tag growth, no Windows needed to produce the file.

```
tools/patch/patch_map.py      find + patch + revert, one CLI
tools/patch/unpatch_map.py    undo a change set from its manifest
tools/patch/tagdefs.py        field-offset resolver over the MCC tag definitions
tools/patch/fixture.py        synthetic caches with realistic tag content
tools/patch/test_patch_map.py 472 assertions, 0 failures, synthetic only
```

---

## ⚠️ Read this before you use it on a map you cannot replace

1. **A patched map is unsigned.** It is not signed before patching either — a
   Reach cache carries no signature and no per-tag hash — but patching it makes
   it a modified file that the retail launch path will not load.
   **MCC must be launched with anti-cheat disabled**: the Steam launch option
   *“Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)”*
   (`steam://launch/976730/option2`). With anti-cheat enabled, mod content is
   not loaded at all. Matchmaking and some services are unavailable in that
   mode. See `research/13-map-write-feasibility.md` §1.4 and `research/04` §10.2.
2. **The supported delivery route is a mod package**, not overwriting
   `haloreach/maps/*.map` in the base install. Overwriting the base install has
   never been verified by this project.
3. **This tool has never seen a real map.** Everything it knows about where
   fields live comes from the MCC tag-definition dump in
   `research/_raw/reach-defs/` and from Assembly's layout XML numbers quoted in
   `research/13` §4.1. Every assertion in the test suite runs against caches
   this project generated. **Nothing here proves the game loads the output.**
4. **Point it at a copy.** It never writes in place and it always writes a
   `.bak`, but work on a copy anyway. Keep the manifest: it is the only
   reversal record.
5. Before patching anything real, run the two cheapest falsification tests
   first (`research/13` §8):
   ```bash
   python3 tools/map/parse_map.py  YOUR.map --no-list     # any "!!" means stop
   python3 tools/map/reach_write.py YOUR.map --verify-checksum
   python3 tools/map/reach_write.py YOUR.map --round-trip  # must say IDENTICAL
   ```
   If `--round-trip` does not say IDENTICAL, the header layout for your build is
   wrong and **no patch should be attempted**.

---

## What it can find

`patch_map.py MAP --find` lists candidates with enough context to recognise
them. Two groups:

**Script expression-node constants** (`research/13` modification #1). The
scenario's `hs syntax datums` block is read, each 0x18-byte node decoded, and
each node attributed to the script or script-global whose root reaches it. A
node carries its own source line number, so a row reads:

```
OFFSET     SELECTOR                           KIND  VALUE   CONTEXT
0x20C68    scnr[0]/hs syntax datums[8]/data   i32   500     script ff_buy_marines (static) line 42, short constant, exact
```

That is how you recognise “that 500 is the Marine price”: the script name, the
line, the value type, and the literal. Attribution is marked `exact` when the
node was reached by walking the script's own sibling/child links, and
`by index range (HEURISTIC)` when it was only placed by emission order.

**Numeric fields in tag blocks** (`research/13` modifications #2 and #3) for
`scnr`, `sqtm`, `smdt` and `wave` by default (`--groups` to change). Each field
is named with the tag definition's own name and comment, enums are labelled,
string-ids are resolved to text, and tag references are resolved to their target
tag:

```
0x20F00  sqtm[2]/cell templates[0]/normal diff count            i16  3   initial number of actors on normal difficulty
0x20EF8  sqtm[2]/cell templates[0]/place on/round range.lower   i16  2   the rounds for which we will consider this
0x2108A  wave[4]/squad specifications[0]/min spawn              i8   1   Spawn AT LEAST this number of squads
0x20FD8  …/character type[0]/character type.datum               u32  5   -> tag 5 char characters\marine\marine
```

Useful flags: `--everything` (don't filter by name), `--all` (also list refused
fields *with the reason*), `--grep REGEX`, `--groups scnr,sqtm`.

### Where the offsets come from, and the check on them

`tagdefs.py` walks each struct's field list with a type→size table and
**requires the sum to equal the struct's own compiled `sizeof()`** as recorded in
the dump. 390 of 399 structs pass; the 9 that do not are listed in
`KNOWN_BAD` and the resolver refuses to address into them. Independently, the
offsets it derives for the scenario reproduce Assembly's `LayoutsU13` numbers
(`script string data` 0x41C, `scripts` 0x430, `hs syntax datums` 0x504), the
expression node is 0x18 with `data` at +0x10, and a scenario squad element is
0x6C — all of which `research/13` and `research/07` state from a different
source. Two unrelated sources agreeing is the strongest evidence this project
has for any tag-internal offset. It is still not a real map.

Every table read is also plausibility-gated: counts are checked against the
definition's own `max_count`, every region must fit inside the tag's estimated
extent, and ≥50 % of node datum salts must be plausible. A failed gate prints a
`REFUSING to read…` note instead of producing addresses that might be garbage.

---

## What it can patch

| Patchable | Why it is safe |
|---|---|
| Integer, real, enum and flag fields in a walked block | same-size scalar, nothing references the value |
| `short_bounds` / `real_bounds` endpoints (`round range.lower`, …) | same-size scalar |
| A script node's `data`, when the node is a **constant** | the value the engine compares or uses |
| A script node's `line number` | cosmetic |
| A `string_id` field — **only** to a string-id already in this cache | no table grows |
| A `tag_reference`'s **datum index** — only to a tag already in this cache | no table grows |

## What it refuses, and why

| Refused | Reason given |
|---|---|
| Any part of a tag block (`.count` / `.address` / `.definition`) | it is a count or an offset; the refusal names what indexes into that block |
| Any part of a data reference (`.size` / `.address` / …) | a length or an offset |
| A tag reference's group tag, name address or name length | structural |
| A node's `datum header`, `next node index`, `source_offset`, `type`, `flags`, opcode union | a salt, a link, an offset, or a type that changes how `data` is read |
| A **group** node's `data` | it is the datum of the node's first child — a link, not a value |
| A `function_name` / `special_form` / `void` node's `data` | an opcode or function index: patching it calls different engine code |
| A script's `root expression index`, a global's initialiser index | the expression table is indexed through it |
| Any field the definitions mark `!` (e.g. `squad template index!`) | the engine derives it; a patched value would disagree with its source |
| A write wider than the field | *size-changing edit* — the extra bytes belong to the next field |
| A value out of the field's range | would need a wider write |
| A string-id not in this cache's string table | adding one means growing the debug section |
| A tag datum that is not a live tag | a patch cannot add a tag |
| Text fields (`string`, `long_string`) | this tool only writes numeric scalars |
| A write past the target tag's **estimated** extent | extents are inferred from the gap to the next tag; see `research/13` §3.1 |
| An offset no definition describes | unnamed writes cannot be checked for being a length/offset/count. Override with `--allow-unmapped` **and** an explicit `@0xOFF:kind` — still same-size, still verified, but unchecked for meaning |

**Not reachable by patching at all:** new scripts, new nodes, new squads, new
strings, new tags, a second purchase, anything that needs one more byte.

---

## Safety guarantees

Each one is implemented and has a test that makes it fire:

* **Dry run by default.** `--apply` is required before any file is written.
* **Never in place.** `--out` must differ from the input; the tool refuses
  otherwise. The input is copied to `<input>.bak` before the output is written,
  and an existing output or manifest is backed up too (`.bak`, `.bak1`, …).
  `--force` is required to replace an existing output.
* **Same size, always.** The write width must equal the field's declared width.
  The file length is compared before and after.
* **Verify before emitting.** Patches are applied to an in-memory buffer, then:
  1. the result is re-parsed from scratch with `reach_cache` — a parse failure
     aborts and nothing is written;
  2. the re-parse must produce no warning the input did not;
  3. the input and output are byte-diffed and **any changed byte that is not
     inside a patched field or the 4-byte header checksum aborts the write**;
  4. every patched value is re-read through its own selector on the re-parsed
     file and must equal what was asked for.
  Only then is anything written to disk.
* **Checksum.** The header checksum (XOR of every `uint32` past 0xA000,
  Assembly's `GenerateChecksum`) is recomputed last. Evidence says MCC does not
  enforce it, and ships maps with it zeroed; recomputing makes the question moot.
* **Manifest.** Every patch records selector, file offset, meta address, tag,
  field, kind, old and new value, old and new bytes, context, timestamps, and
  sha256 of both input and output. The original checksum bytes are recorded too,
  so a revert is byte-exact even when the input shipped with a zeroed checksum.
* **Reversible.** `--revert` / `unpatch_map.py` refuses unless the target's
  sha256 matches the manifest and every recorded byte is still in place, then
  restores the originals and reports whether the result's sha256 equals the
  original input's. In the test suite it does.

Exit codes: `0` ok, `2` usage, `3` refused, `4` format/definition error,
`5` manifest error.

---

## Workflow: retune a price

```bash
cp "YOUR.map" work.map                      # always work on a copy

# 1. prove the container is understood (stop if this fails)
python3 tools/map/reach_write.py work.map --round-trip

# 2. find the number. Narrow it down by script name or by value.
python3 tools/patch/patch_map.py work.map --find --grep 'buy|purchase|marine'
python3 tools/patch/patch_map.py work.map --find | grep -E ' (500|1000|2000) '

# 3. read the row. Does the script name, the line and the value type all agree
#    with the price you expect? If the context says `group ->` or
#    `function_name`, you have the wrong node.

# 4. dry run. Read the byte diff.
python3 tools/patch/patch_map.py work.map \
    --set 'scnr[0]/hs syntax datums[8]/data=250' --out work.patched.map

# 5. apply
python3 tools/patch/patch_map.py work.map \
    --set 'scnr[0]/hs syntax datums[8]/data=250' --out work.patched.map --apply

# 6. if it misbehaves in game, go back
python3 tools/patch/unpatch_map.py work.patched.map.patch.json --apply
```

Multiple `--set` flags are applied as one change set, one manifest, one output —
which is what you want, because every launch of MCC costs a round trip to a
Windows machine.

## Workflow: resize a squad

```bash
python3 tools/patch/patch_map.py work.map --find --grep 'diff count|min spawn|max spawn|weight'
python3 tools/patch/patch_map.py work.map \
    --set 'sqtm[2]/cell templates[0]/normal diff count=5' \
    --set 'sqtm[2]/cell templates[0]/place on/round range.lower=1' \
    --set 'wave[4]/squad specifications[0]/weight=90' \
    --out work.patched.map --apply
```

`normal diff count` is the actor count for one cell of a squad template; a
squad's size is the sum over its cells. `major upgrade` (`normal/few/many/
none/all`) changes how many of them are upgraded ranks. `chance` in a character
choice block is the weighting between character types. `round range` / `set
range` gate a cell or a wave entry to particular Firefight rounds and sets.

## Selector grammar

```
GROUP[tagindex]/path/to/field               e.g. sqtm[2]/cell templates[0]/normal diff count
GROUP[tagindex]/field.sub                   e.g. …/character type.datum, …/round range.lower
SELECTOR:kind=VALUE                         force the read/write kind at the same width
@0xFILEOFFSET:kind=VALUE                    raw, needs --allow-unmapped if no field is there
```

`tagindex` is the position in the cache's tag table — stable for a given map.
Selectors are exactly what `--find` prints; copy and paste them. Values accept
decimal, `0x` hex, and (for `f32`) decimals.

## Running the tests

```bash
python3 tools/patch/patch_map.py --self-test      # 472 assertions
python3 tools/patch/tagdefs.py                    # struct validation report
python3 tools/patch/fixture.py /tmp/fx.map        # build a fixture and list its landmarks
```

## What remains unproven

* No real `.map` has been opened. Header offsets, scenario offsets, and the
  claim that MCC tolerates the result are all unverified.
* Tag extents are estimated from the gap to the next tag, so the extent guard
  can both false-alarm and, where two tags share an estimate, fail to fire.
* The Xbox 360 big-endian layout is implemented by the reader but not exercised
  by this suite (the fixture is built for the three little-endian MCC layouts).
* Whether a given constant in a given map is the thing you think it is. The tool
  shows you the script name, the line and the type; the judgement is yours.
