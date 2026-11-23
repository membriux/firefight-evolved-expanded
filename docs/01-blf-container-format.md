# Halo: Reach (MCC) Game-Variant BLF Container — Byte-Level Format

Target files (read-only reference):

- `reference/Firefight Evolved.bin` — SHA-1 `6f6c7760a53fbf2d9ee35e2ac211e0627c72e505`, 21753 bytes
- `reference/Firefight Corvette Evolved.bin` — SHA-1 `a96e1fb0b230f8f36a78abca081499f650310291`, 21753 bytes

Library: `tools/blf.py`. Self-test: `python3 -I tools/blf.py` (30 assertions, all passing).

## Confidence legend

| Tag | Meaning |
|---|---|
| **CONFIRMED** | Proven from the bytes of these two files, usually because the field differs between them in a way only one interpretation explains, or because a computation reproduces a stored value exactly. |
| **CORROBORATED** | Value read from the bytes and consistent with cited prior art, but these two files alone do not discriminate between competing interpretations. |
| **INFERENCE** | Taken from prior art; not provable from these two files (field is zero, constant, or unused here). |

Prior art consulted, with the caveat that the primary repo has been renamed —
`github.com/DavidJCobb/ReachVariantTool` now 404s and the code lives at
**`github.com/DavidJCobb/ReachVariantEditor`** (abbreviated RVE below).
Also: **`github.com/Blam-Network/blf`** (BN), ManagedDonkey
(`game/source/networking/tools/network_blf.hpp`), TagTool
(`TagTool/BlamFile/Blf.cs`), `CharlyReux/Kalo`, and
`MAVProxyUser/HaloMCC_FMOD_PoC` (`APPENDIX-HALO2-VARIANT-BIN.md`).
c20.reclaimers.net has **no** BLF or game-variant page. Assembly's
`PureBLF.cs` reads only a generic chunk header and has no `chdr`/`mpvr` code.

---

## 1. Container layout

### 1.1 Correction to the established model

The brief listed four chunks. **There are five.** A `_fsm` chunk follows
`_eof`:

| # | File offset | Chunk | Size | Version | Minor | Payload size |
|---|---|---|---|---|---|---|
| 1 | `0x0000` | `_blf` | 48 | 1 | 2 | 36 |
| 2 | `0x0030` | `chdr` | 704 | 10 | 2 | 692 |
| 3 | `0x02f0` | `mpvr` | 20520 | 54 | 1 | 20508 |
| 4 | `0x5318` | `_eof` | 17 | 1 | 1 | 5 |
| 5 | `0x5329` | `_fsm` | 464 | 1 | 1 | 452 |

Total `48 + 704 + 20520 + 17 + 464 = 21753`. **CONFIRMED** — identical chunk
table in both files.

### 1.2 Chunk header (12 bytes)

| Offset | Size | Endian | Field |
|---|---|---|---|
| `+0x00` | 4 | ASCII | Signature, e.g. `_blf` |
| `+0x04` | 4 | **big** | Size, **including** this 12-byte header |
| `+0x08` | 2 | **big** | Version (major) |
| `+0x0A` | 2 | **big** | Minor version |

**CONFIRMED**, matching the brief, with one naming note: the brief calls the
last field `flags`. ManagedDonkey (`network_blf.hpp:10-19`) and TagTool
(`Blf.cs:443-450`) both name it `minor_version`, and BN writes these chunks as
`_blf 1.2`, `chdr 10.2`, `mpvr 54.1`, `_eof 1.1`, `_fsm 1.1` — which exactly
reproduces the observed pairs. Same bytes; `minor_version` is the better name.
The container is big-endian in the chunk headers but **little-endian inside the
`chdr` payload** (see §3).

---

## 2. `_blf` — start of file (36-byte payload)

| Payload off | File off | Size | Endian | Field | Value in both files | Confidence |
|---|---|---|---|---|---|---|
| `0x00` | `0x0C` | 2 | — | Byte order mark | `FF FE` | **CONFIRMED** present; **CORROBORATED** as a BOM |
| `0x02` | `0x0E` | 32 | ASCII | File type / name string | all zero (empty) | **INFERENCE** |
| `0x22` | `0x2E` | 2 | — | Padding | `00 00` | **INFERENCE** |

`FF FE` is the little-endian UTF-16 BOM; TagTool's comment says "-2 means
little endian", which lines up with `chdr` being little-endian. The 32-byte
string is empty here, so its meaning is not provable from these files —
however RVE's own `Resources/gametype_files/blank_ff.bin` carries the text
`game var` at exactly payload offset `0x02`, which supports this layout and
contradicts TagTool's variant (which inserts an extra `short` first).

`_blf` is **byte-identical in both files** and needs no changes to re-skin.

---

## 3. `chdr` — content header (692-byte payload, little-endian)

Payload begins at file offset `0x3C`. The field table below accounts for all
692 bytes exactly (`0x2B4 == 692`), with no trailing slack.

The little-endian reading is **CONFIRMED**: `file_size` decodes to 21289
little-endian (a sensible value, see §3.3) versus 1,678,245,888 big-endian; and
the title at `0x084` decodes as UTF-16**LE** text.

### 3.1 Field map

| Payload off | File off | Size | Type | Field | `Firefight Evolved` | `Firefight Corvette Evolved` | Confidence |
|---|---|---|---|---|---|---|---|
| `0x000` | `0x03C` | 2 | u16 LE | `build_number` | `0xFFFF` (65535) | `0xFFFF` | **CORROBORATED** |
| `0x002` | `0x03E` | 2 | u16 LE | `build_sequence_number` | `0xFFFF` | `0xFFFF` | **CORROBORATED** |
| `0x004` | `0x040` | 1 | s8 | **`file_type`** | `6` = game variant | `6` | **CONFIRMED** value; **CORROBORATED** enum |
| `0x005` | `0x041` | 3 | — | Padding | `00 00 00` | same | **INFERENCE** |
| `0x008` | `0x044` | 4 | u32 LE | **`file_size`** | `21289` | `21289` | **CONFIRMED** (see §3.3) |
| `0x00C` | `0x048` | 8 | u64 LE | `unique_id` | `0` | `0` | **INFERENCE** |
| `0x014` | `0x050` | 8 | u64 LE | `parent_unique_id` | `0` | `0` | **INFERENCE** |
| `0x01C` | `0x058` | 8 | u64 LE | `root_unique_id` | `0` | `0` | **INFERENCE** |
| `0x024` | `0x060` | 8 | u64 LE | `game_id` | `0` | `0` | **INFERENCE** |
| `0x02C` | `0x068` | 1 | s8 | `activity` | `6` | `6` | value **CONFIRMED**; enum **does not fit** (see §3.4) |
| `0x02D` | `0x069` | 1 | u8 | `game_mode` | `2` | `2` | **CORROBORATED** (2 = survival/Firefight) |
| `0x02E` | `0x06A` | 1 | u8 | `game_engine` | `4` | `4` | **CORROBORATED** (4 = survival) |
| `0x02F` | `0x06B` | 1 | — | Padding | `00` | `00` | **INFERENCE** |
| `0x030` | `0x06C` | 4 | s32 LE | `map_id` | `-1` (any map) | `-1` | **CORROBORATED** |
| `0x034` | `0x070` | 8 | — | Megalo category index + pad | `FF 00 00 00 00 00 00 00` | same | **INFERENCE** |
| `0x03C` | `0x078` | 36 | block | **Creator block** | see §3.2 | see §3.2 | partly **CONFIRMED** |
| `0x060` | `0x09C` | 36 | block | **Modifier block** | all-zero timestamp/xuid | same | **INFERENCE** |
| `0x084` | `0x0C0` | 256 | UTF-16LE[128] | **Title** | `FIREFIGHT EVOLVED` | ` FIREFIGHT CORVETTE EVOLVED` | **CONFIRMED** |
| `0x184` | `0x1C0` | 256 | UTF-16LE[128] | **Description** | 86 chars | 119 chars | **CONFIRMED** |
| `0x284` | `0x2C0` | 16 | u8/u32 + pad | Game-variant data: engine icon index | `FF` then zeros | same | **INFERENCE** |
| `0x294` | `0x2D0` | 16 | u16 + pad | Matchmaking data: **`hopper_identifier`** | `0` | `0` | **INFERENCE** |
| `0x2A4` | `0x2E0` | 16 | — | Campaign / Firefight data | all zero | all zero | **INFERENCE** |
| `0x2B4` | `0x2F0` | — | — | *end of payload* | | | **CONFIRMED** |

Field names from BN
`blf_lib/src/blam/haloreach/v12065_11_08_24_1738_tu1actual/saved_games/saved_game_files.rs:53-121`;
read order cross-checked against RVE `formats/ugc_header.cpp:54-86` and
`html/src/raw/game_variant_chdr.js:51-84` (the JS file carries `assertBytePos`
checks that pin title, description and end-of-chunk — these agree with the
offsets measured here).

### 3.2 Author block (creator / modifier), 36 bytes

| Block off | Size | Type | Field | Creator (Evolved) | Creator (Corvette) | Confidence |
|---|---|---|---|---|---|---|
| `+0x00` | 8 | u64 LE | **Timestamp, Unix epoch seconds** | `1696702687` = 2023-10-07 18:18:07Z | `1763923489` = 2025-11-23 18:44:49Z | **CONFIRMED** |
| `+0x08` | 8 | u64 LE | `xuid` | `0x0009000004B7AD44` | identical | **CORROBORATED** |
| `+0x10` | 16 | char[16] | Gamertag, NUL-terminated | `A6` then 15 NULs | identical | **meaning NOT verified** |
| `+0x20` | 1 | u8 | `is_online` | `1` | `1` | **INFERENCE** |
| `+0x21` | 3 | — | Padding | `00 00 00` | `00 00 00` | **INFERENCE** |

The timestamp is the strongest single result in the whole `chdr`: it is the
**only non-text field that differs between the two files**, and both values
decode as plausible authoring dates under Unix-epoch-seconds. FILETIME would
give year-1601-relative nonsense. This matches RVE's comment in
`formats/content_author.h` ("seconds since Jan 1 1970"). Note only the low 4
bytes differ; the high 4 are zero in both, so strictly the bytes prove a
*little-endian integer of at least 4 bytes*; the u64 width is **INFERENCE**.

**Honest flag on the gamertag:** the 16-byte field is the single byte `0xA6`
followed by NULs, in *both* the creator and modifier blocks of *both* files.
`0xA6` is not printable ASCII. Prior art says this is a NUL-terminated
gamertag of at most 15 characters, and the position fits, but the actual
content here is not a legible gamertag and I cannot explain `0xA6`. Treat the
field offset as **CORROBORATED** and the byte value as unexplained. It does
not need to change to re-skin a variant.

The modifier block is entirely zero except the same `0xA6` gamertag byte and
`is_online = 1`.

### 3.3 `file_size` semantics — CONFIRMED

`chdr.file_size = 21289 = 0x5329`, which is **exactly the offset of `_fsm`**,
i.e. the byte count through the end of `_eof`. It therefore **excludes the
trailing `_fsm` chunk**, even though `_fsm` is physically present and the real
file is 21753 bytes. This is consistent with RVE writing the field *after*
emitting `_eof` (`ugc_header.cpp:156-158`, called from `base.cpp:454-456`).

Both files carry the same value because both are the same total size.

### 3.4 Enum values that do not fit prior art — flagged

`activity = 6`. RVE's documented enum
(`html/src/raw/game_variant_chdr.js:12-20`) is: `-1` none, `0` activities,
`1` campaign, `2` survival, `3` matchmaking, `4` forge, `5` theater. **There is
no 6.** Either the MCC-era enum was extended, or the field at `0x02C` is not
`activity`. I am reporting the raw value and declining to name it. This does
not block re-skinning — the field is identical in both files and should be
copied verbatim.

`game_mode = 2` (survival/Firefight) and `game_engine = 4` (survival) are both
in range and consistent with these being Firefight variants.

### 3.5 Title and description buffers — CONFIRMED

- Fixed buffers of **128 UTF-16LE code units = 256 bytes** each.
- NUL-terminated, then **zero-padded to the end of the buffer**. Verified: in
  all four buffers across the two files, every byte after the terminator is
  `0x00`.
- Usable length is therefore **127 characters** plus the NUL.
- Observed lengths: title 17 / 27 chars; description 86 / 119 chars. The
  Corvette description at 119 chars leaves only 8 spare code units — the
  127-char ceiling is a real constraint for the build phase.
- Note the Corvette title begins with a **literal leading space**:
  `" FIREFIGHT CORVETTE EVOLVED"`. Preserve or drop deliberately, not by
  accident.

---

## 4. `_eof` — end of file (5-byte payload)

| Payload off | File off | Size | Endian | Field | Value | Confidence |
|---|---|---|---|---|---|---|
| `0x00` | `0x5324` | 4 | **big** | `total_file_size` | `21272 = 0x5318` | **CONFIRMED** |
| `0x04` | `0x5328` | 1 | u8 | `authentication_type` | `0` = none | **CONFIRMED** |

`total_file_size = 0x5318` is **exactly the offset of the `_eof` chunk itself**,
i.e. the number of bytes preceding it. Note this is *big*-endian, unlike
`chdr`. RVE notes the field is little-endian "in some files"
(`base.cpp:40-45`); in these files it is unambiguously big-endian
(`00 00 53 18`).

### 4.1 `authentication_type` enum

Source: ManagedDonkey `network_blf.hpp:48-56`, TagTool `Blf.cs:435-441`,
payload sizes from BN's `s_blf_chunk_end_of_file_with_*.rs`.

| Value | Meaning | Extra data after the byte | Chunk size |
|---|---|---|---|
| `0` | **none** | — | **17** |
| `1` | crc | u32 | 21 |
| `2` | sha1 | 20 bytes | 37 |
| `3` | rsa | 256 bytes | 268 |

**Our files use type 0 — there is no hash or signature in `_eof` at all.** The
17-byte chunk size is itself the proof: 12 header + 4 length + 1 type, with no
room for a digest. This directly answers one of the brief's hypotheses: the
"usual place" for a BLF SHA-1/RSA is empty here.

`_eof` is byte-identical in both files.

---

## 5. `_fsm` — MCC fileshare metadata (452-byte payload)

Payload base = `0x5335`. BN names this chunk "MCC fileshare metadata" and
states Reach itself "does not and cannot read or write this chunk; it is
managed entirely via the MCC menu" (`blf-ts/docs/guide/reading.md:42-52`,
`blf-ts/docs/guide/versions/mcc/index.md`).

| Payload off | File off | Size | BN field | Value in both files | Confidence |
|---|---|---|---|---|---|
| `0x000` | `0x5335` | 8 | `unknown0` | zero | **INFERENCE** |
| `0x008` | `0x533D` | 32 | `unknown8` | zero | **INFERENCE** |
| `0x028` | `0x535D` | 36 | `unknown28` | zero | **INFERENCE** |
| `0x04C` | `0x5381` | 8 | `unknown4c` | zero | **INFERENCE** |
| `0x054` | `0x5389` | 32 | `unknown54` | `d348...a22f` (non-zero) | **opaque — see §6.2** |
| `0x074` | `0x53A9` | 36 | `unknown74` | zero | **INFERENCE** |
| `0x098` | `0x53CD` | 40 | `unknown98` (ASCII hex) | `85E3D5677B0D64FD91FACB25D696BF315CB062A1` | **CONFIRMED location** |
| `0x0C0` | `0x53F5` | 256 | `file_signature` | non-zero | **CONFIRMED location** |
| `0x1C0` | `0x54F5` | 4 | padding | `00 00 00 00` | **CONFIRMED** |

Sizes total `8+32+36+8+32+36+40+256+4 = 452` — an exact fit for the 452-byte
payload. **CONFIRMED.**

### 5.1 The single most important observation in this document

**`_fsm` is byte-identical between the two reference files** — all 464 bytes,
including the 32-byte `0x054` field and the 256-byte signature at `0x0C0` —
**while every region before `_fsm` differs.**

Verified directly:

```
_fsm chunks are byte-identical : True
content before _fsm differs    : True
```

A digest or signature cannot be valid for two different payloads. So the
`_fsm` block in these files is **a stale, copy-pasted stock blob**, not a live
integrity field for either variant. See §6 for what follows from this.

---

## 6. Integrity fields

There are exactly **three** integrity-ish fields plus one opaque block. Only
one is a real content hash, and it is fully solved.

| # | Field | Location | Covers | Status |
|---|---|---|---|---|
| 1 | `mpvr` SHA-1 | `mpvr` payload `0x00`, 20 bytes | the Megalo bit-stream | **SOLVED, reproducible** |
| 2 | `_eof.total_file_size` | `_eof` payload `0x00`, u32 BE | byte count before `_eof` | **SOLVED** (a length, not a hash) |
| 3 | `chdr.file_size` | `chdr` payload `0x008`, u32 LE | byte count through end of `_eof` | **SOLVED** (a length, not a hash) |
| 4 | `_fsm` `0x054` digest + `0x0C0` signature | `_fsm` payload | unknown | **unsolved, and demonstrably not enforced** |

### 6.1 The `mpvr` SHA-1 — solved

`mpvr` payload header:

| Payload off | File off | Size | Endian | Field | Confidence |
|---|---|---|---|---|---|
| `0x00` | `0x02FC` | 20 | — | **SHA-1 digest** | **CONFIRMED** |
| `0x14` | `0x0310` | 4 | — | Unused (zero in both files) | **CONFIRMED zero** |
| `0x18` | `0x0314` | 4 | **big** | **Hashed bit-stream length** | **CONFIRMED** |
| `0x1C` | **`0x0318`** | — | — | **Megalo bit-stream starts here** | **CONFIRMED** |

Observed: `Firefight Evolved` length = **963**, digest
`dc0b8d4ff6f5558e702d5d103b5255cc0c10ab40`; `Firefight Corvette Evolved`
length = **1049**, digest `6eaf84e72364f680a0318a1093b5c3da59a78a42`.
All 20480 bytes after the declared length are zero padding in both files
(verified).

**The algorithm, confirmed exactly on both files:**

```
digest = SHA1( pack_big_endian_u32(length) || payload[0x1C : 0x1C + length] )
```

No salt. Length prepended big-endian. The big-endian reading of the length
field is independently confirmed: `963` and `1049` are plausible script sizes,
whereas little-endian gives 3,271,753,728 and 419,692,544 — both larger than
the chunk.

**This contradicts the main community tool, and the contradiction matters.**
RVE (`base.cpp:243-275`) and BN's writer (`blf_lib/src/blf.rs:118,136-142`)
prepend a 34-byte "gen3 salt" and, for multiplayer variants, write the length
little-endian. I tested that scheme against both files: **it fails on both.**
The no-salt, big-endian-length scheme matches both. Prior art for the scheme
that actually works here is `CharlyReux/Kalo`
(`src/Kalo.Core/Scripting/Multiplayer/GameVariantFile.cs:56-63,101-106`).

`tools/blf.py` implements the confirmed scheme, verifies it on load, and
recomputes it on save. A tamper test proves both directions (`verify()`
detects a flipped bit; `recompute()` repairs it).

**This hash is not a blocker.** It is computed and rewritten automatically.

### 6.2 The 40-hex string is NOT a SHA-1 of this file

The brief's hypothesis was that
`85E3D5677B0D64FD91FACB25D696BF315CB062A1` — 40 hex chars — is a SHA-1 digest
over part of the file. **The evidence says it is a constant, not a digest:**

1. It is **identical in both reference files**, which have different content.
2. BN's test suite expects **exactly that string** as a hard-coded literal for
   a completely unrelated MCC variant,
   `blf-ts/tests/fixtures/reachmcc_zb_slayer_team_dmr_054.bin`
   (`blf-ts/src/chunks/mcc/s_blf_chunk_fileshare_metadata.test.ts`).
3. `MAVProxyUser/HaloMCC_FMOD_PoC` (`APPENDIX-HALO2-VARIANT-BIN.md:49-52`)
   reports the same string at the same `_fsm` offset in **all 40 Halo 2A stock
   variants** — a different game entirely.

Three independent corpora, one constant value. BN describes the field as a
"40-char hex item id". MAVProxyUser's reading is that it is a **signing-key
fingerprint** identifying which key signed the adjacent 256-byte block, which
would be RSA-2048. That reading is an **INFERENCE** and is not proven, but the
"it is a constant, not a per-file digest" part is **CONFIRMED** by observation 1
alone.

So: nothing in this file is a SHA-1 over the file's own bytes except the
`mpvr` bit-stream hash, which is solved.

### 6.3 The `_fsm` 32-byte field at `0x054` — unsolved, stated plainly

The subagent research reported that in BN's own MCC fixtures this field is
SHA-256 over every byte before `_fsm`. **That does not hold for our files.** I
tested SHA-256, BLAKE2s and SHA3-256 over: bytes `[0, 0x5329)` (everything
before `_fsm`), `[0, 0x5318)` (everything before `_eof`), the whole file, the
`mpvr` payload, the `mpvr` bit-stream, and the `chdr` payload — for both files.
**No match.**

For reference, if someone wants to continue this thread:
`sha256(Evolved[:0x5329]) = 5e2ca48c29c6b298...`,
`sha256(Corvette[:0x5329]) = 363a5e83a5a0e947...`, neither of which is the
stored `d348...a22f`.

**I cannot say what this field covers. That is a genuine dead end, not a
hedge.** But §5.1 makes it moot: the field is byte-identical across two files
with different content, so it is stale in at least one of them and almost
certainly in both.

### 6.4 Does MCC validate any of this for a local variant?

**Assessment: no — and the `_fsm` block does not block us. Confidence: high
for `_fsm`, moderate-to-high for `mpvr`.**

The argument, strongest first:

1. **Strongest, and it is our own evidence.** Both reference files ship an
   identical `_fsm` while differing in `chdr` and `mpvr`. No digest or
   signature scheme can validate both. These are published, working variants
   from the Halo: Reach Evolved mod. Therefore MCC loaded at least one file
   whose `_fsm` block was invalid — so MCC does not gate loading on `_fsm`.
   - *The one assumption:* that both files actually load in MCC. They are
     distributed as working mod content, which is strong but is an assumption,
     not something I can verify from bytes. **State it explicitly before the
     build phase bets on it.**
2. **Independent agreement that `_fsm` is optional.** RVE stops reading at the
   first unrecognised chunk after `_eof`, so it silently drops `_fsm` and never
   writes one back (`base.cpp:372-378,438-465`). Kalo states MCC's built-in
   variants "carry a signed `_fsm` chunk; files saved by players do not"
   (`GameVariantFile.cs:12`). BN states Reach never reads it. A chunk that the
   standard editor deletes and that player-saved files lack cannot be
   load-bearing.
3. **Moderate, for the `mpvr` hash.** RVE is the main community editor, targets
   MCC, and always writes the salted/little-endian scheme — which, as §6.1
   shows, does *not* reproduce MCC-authored files. If MCC strictly enforced the
   scheme its own files use, every RVE-produced variant would be rejected.
   Since RVE is widely used successfully, MCC either ignores the `mpvr` hash or
   accepts both schemes. This is inference from tool ecology, not from a
   traced code path.
   - **This does not matter for us anyway**, because we reproduce the
     MCC-native scheme bit-for-bit, which is strictly the safer side of the
     question.
4. **What nobody has shown.** No source I found contains MCC's loader actually
   verifying or skipping either value. MAVProxyUser says outright that he did
   "not byte-trace the on-disk RSA verify call… verify-vs-parse ordering is not
   proven" (`APPENDIX-HALO2-VARIANT-BIN.md:63-65`).

**The experiment that would settle it**, in increasing cost:

- **A. Cheapest, decisive for `_fsm`.** Take the PoC file, flip one byte inside
  `_fsm`'s 256-byte signature, load it in MCC. If it loads, `_fsm` is ignored —
  done. Also try the `_fsm`-stripped 21289-byte variant
  (`BlfFile.remove("_fsm")`, already tested in the self-test to be
  self-consistent). If the stripped file loads, `_fsm` is conclusively optional.
- **B. Decisive for `mpvr`.** Corrupt the 20-byte `mpvr` digest only, leaving
  the bit-stream intact, and load. Loads ⇒ the hash is unchecked. Rejected ⇒
  checked, and our confirmed recompute is mandatory (which we already do).
- **C. Definitive.** Attach a debugger to `MCC-Win64-Shipping.exe`, break on
  the SHA-1/RSA call sites reached while enumerating the custom-games variant
  list, and read the comparison. Expensive; A and B should make it unnecessary.

Run A and B before the build phase commits. They are two file writes and two
game launches.

---

## 7. Byte-by-byte diff of the two reference files

Both files are 21753 bytes. **988 bytes differ, in 170 raw runs, which merge
into 14 regions.** Every single differing byte lies in `chdr` or `mpvr`.
`_blf`, `_eof` and `_fsm` are untouched.

| # | File offset | Len | Chunk | Payload off | Classification | Notes |
|---|---|---|---|---|---|---|
| 1 | `0x0078` | 4 | `chdr` | `0x03C` | **Timestamp** | Creator timestamp low dword: `1696702687` → `1763923489` |
| 2 | `0x00C0` | 27 | `chdr` | `0x084` | **Metadata text** | Title buffer |
| 3 | `0x00E0` | 21 | `chdr` | `0x0A4` | **Metadata text** | Title buffer (tail; split by incidentally-equal bytes) |
| 4 | `0x020E` | 19 | `chdr` | `0x1D2` | **Metadata text** | Description buffer |
| 5 | `0x0228` | 133 | `chdr` | `0x1EC` | **Metadata text** | Description buffer |
| 6 | `0x02FC` | 20 | `mpvr` | `0x000` | **Hash** | `mpvr` SHA-1 digest |
| 7 | `0x0316` | 2 | `mpvr` | `0x01A` | **Length field** | Low half of the BE u32 bit-stream length: `963` → `1049` |
| 8 | `0x0347` | 4 | `mpvr` | `0x04B` | **Script/settings payload** | Megalo bit-stream |
| 9 | `0x0368` | 28 | `mpvr` | `0x06C` | **Script/settings payload** | Megalo bit-stream |
| 10 | `0x0388` | 341 | `mpvr` | `0x08C` | **Script/settings payload** | Megalo bit-stream |
| 11 | `0x04E4` | 5 | `mpvr` | `0x1E8` | **Script/settings payload** | Megalo bit-stream |
| 12 | `0x04F0` | 347 | `mpvr` | `0x1F4` | **Script/settings payload** | Megalo bit-stream |
| 13 | `0x0651` | 116 | `mpvr` | `0x355` | **Script/settings payload** | Megalo bit-stream |
| 14 | `0x06C9` | 103 | `mpvr` | `0x3CD` | **Script/settings payload** | Megalo bit-stream |

Region boundaries are the merge of runs separated by three or fewer equal
bytes, so 8–14 are one logically contiguous bit-stream edit, not seven
independent ones. Because the payload is bit-packed, a one-bit insertion
early on reshuffles everything downstream — do not read these as seven
separate settings.

### 7.1 What the diff tells us

**Did NOT change between a Firefight variant and a different Firefight variant
on a different map:**

- Entire `_blf` chunk.
- Entire `_eof` chunk, including `total_file_size`.
- Entire `_fsm` chunk — the stale-blob finding of §5.1.
- `chdr`: build numbers, `file_type`, `file_size`, all four id fields,
  `activity`, `game_mode`, `game_engine`, `map_id` (both `-1`), Megalo
  category, creator **xuid**, the whole **modifier** block, engine icon index,
  `hopper_identifier`, and the Firefight/campaign data block.

**Changed:** title, description, creator timestamp, the bit-stream, and the
two `mpvr` fields that are *derived* from the bit-stream (its length and its
SHA-1).

So re-skinning touches a remarkably small surface. Notably `map_id` is `-1`
("any map") in both, so even the Corvette variant does not pin a map in
`chdr` — map selection lives elsewhere.

---

## 8. What must be rewritten to re-skin a variant

| Field | Location | Required? | Handled by `tools/blf.py` |
|---|---|---|---|
| Title | `chdr` payload `0x084`, 128 UTF-16LE units | Yes | `f.title = "..."` |
| Description | `chdr` payload `0x184`, 128 UTF-16LE units | Yes | `f.description = "..."` |
| Creator timestamp | `chdr` payload `0x03C`, u64 LE Unix seconds | Optional, cosmetic | `f.chdr.creator` |
| `mpvr` SHA-1 | `mpvr` payload `0x00`, 20 bytes | **Yes, if the bit-stream changes** | automatic on save |
| `mpvr` length | `mpvr` payload `0x18`, u32 BE | Yes, if the bit-stream changes | caller sets; hash follows |
| `chdr.file_size` | `chdr` payload `0x008`, u32 LE | Yes, if any chunk resizes | automatic on save |
| `_eof.total_file_size` | `_eof` payload `0x00`, u32 BE | Yes, if any chunk resizes | automatic on save |
| `_fsm` digest/signature | `_fsm` payload `0x054` / `0x0C0` | **Cannot be regenerated; evidence says it is ignored** | left byte-exact; `remove("_fsm")` available |

Hard constraints for the build phase:

- Title and description are capped at **127 characters** each. The Corvette
  description already uses 119. The library raises `BlfError` rather than
  truncating.
- Changing only title/description keeps the file at **exactly 21753 bytes** and
  leaves all length fields and the `mpvr` hash valid — the cheapest possible
  edit.
- `chdr.file_size` excludes `_fsm`; `_eof.total_file_size` excludes `_eof`
  itself. Both are easy to get wrong by one chunk.

---

## 9. Library and proof of concept

### 9.1 `tools/blf.py`

Parses all five chunks, exposes a typed `chdr` view backed by the original
bytes (so unmapped bytes survive untouched), reads/writes the fixed-size
UTF-16LE title and description, verifies and recomputes all three solved
integrity fields, and serialises back out.

`python3 -I tools/blf.py` runs 30 assertions, **all passing**, including per
reference file:

- chunk layout matches the expected five-chunk table;
- the stored `mpvr` SHA-1, `_eof` length and `chdr.file_size` all verify as-is;
- **no-op round trip with recompute enabled is byte-identical to the original**
  (the headline requirement);
- the `mpvr` SHA-1 recomputes from scratch to the stored value;
- rewriting title/description with their existing values is byte-identical;
- changing the title alters **only** the 256 bytes of the title buffer and
  nothing else;
- a 128-char string is rejected, a 127-char string is accepted;
- a flipped bit in the bit-stream is detected by `verify()` and repaired by
  `recompute()`;
- `_fsm` can be removed, leaving a self-consistent 21289-byte file;

plus the cross-file checks that `_fsm` is identical while preceding content
differs.

### 9.2 `build/Firefight Evolved Expanded.bin`

Clone of `Firefight Evolved.bin` with:

- Title: `FIREFIGHT EVOLVED EXPANDED`
- Description: `Expanded build of Halo: Reach Evolved Firefight. Use your Firefight Score to purchase bonuses.`

Result: 21753 bytes (unchanged), SHA-1
`3d415bab4599cf3d618cac4193565109d90889e7`, `verify()` reports no problems,
**99 differing bytes, all inside the `chdr` title and description buffers**
(`0x00E2`–`0x027A`). `mpvr`, `_blf`, `_eof` and `_fsm` are byte-identical to
the source.

**Will MCC accept it? Probably yes.** Evidence:

- It is structurally indistinguishable from a file MCC already loads: same
  length, same chunk table, same every field except two text buffers.
- All three integrity fields that we can prove the meaning of verify correctly,
  and were verified correct in the source too.
- The `mpvr` bit-stream — the only part with real game logic — is bit-identical,
  so nothing downstream of the hash changed.
- The one unverifiable block, `_fsm`, is carried over byte-exact; and §5.1/§6.4
  argue it was already stale in the source, so copying it changes nothing about
  whether it validates.

**The residual risk is exactly one thing:** if MCC *does* validate `_fsm`
against file content, this file fails — but then the unmodified
`Firefight Corvette Evolved.bin` would fail too, since they share an identical
`_fsm`. So the risk is bounded by a claim we can disprove with experiment A in
§6.4, which costs one byte flip and one game launch. **Run it before building
on top of this.**
