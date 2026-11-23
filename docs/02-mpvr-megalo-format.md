# 02 — The `mpvr` chunk of Firefight Evolved / Firefight Corvette Evolved

Scope: the `mpvr` chunk only. The outer BLF container, `_blf`, `chdr` and `_eof` are
owned by another agent.

Decoder: `tools/mpvr.py` (+ `tools/bitreader.py`). Dumps:
`research/mpvr-dump-firefight-evolved.txt`, `research/mpvr-dump-corvette-evolved.txt`.

---

## 0. Headline result, stated plainly

**There is no Megalo script in either of these two files.** The task brief assumed one
was present. It is not, and this is not a limitation of the decode — it is a proven
property of the bytes:

1. The `mpvr` payload declares its own length: **963 bytes** for *Firefight Evolved* and
   **1049 bytes** for *Firefight Corvette Evolved*, out of a 20520-byte chunk.
2. The variant's engine-type field reads **4 = firefight**.
3. A complete, field-by-field port of Reach's firefight variant body consumes
   **exactly** 963 bytes (7699 bits + 5 bits of byte-alignment padding) and
   **exactly** 1049 bytes (8387 bits + 5 bits of padding). Nothing is left over and
   nothing is missing. See `--megalo-probe`: `closes exactly : True`.
4. The stored SHA-1 digest over that payload **verifies** for both files, which proves
   the declared length is the true length and that no data was skipped.
5. The remaining 19517 / 19431 bytes of the chunk are **entirely zero** — fixed-size
   chunk padding, not compressed or obfuscated script data (`nonzero_bytes = 0`).

Reach's firefight game-variant body structurally has no script section. Per
ReachVariantEditor's `game_variants/types/firefight.cpp` and `firefight.h`, the
firefight body is: UGC header, `isBuiltIn`, custom game options, scenario flags, MCC
extension version, a handful of wave/life/bonus scalars, eight player-trait blocks,
three custom skulls, elite respawn options, three rounds, and a bonus wave. There is no
string table, no trigger table, no condition table, no action table, no variable
declarations and no HUD widget declarations. Those members exist only on
`GameVariantDataMultiplayer` (engine types 1 = forge and 2 = multiplayer).

So these two `.bin` files are **gametype settings files, not scripts**. Their own
descriptions say so: *"Used with Halo: Reach Evolved Firefight"* — they are the
companion settings for a modded map, and the map is what carries the behaviour.
Section 6 covers where the purchase logic must actually live.

---

## 1. mpvr bit-stream layout

### 1.1 Chunk framing (proven from bytes)

Both files are byte-for-byte identical in structure here:

| Offset | Field | Value |
|---|---|---|
| `0x000` | `_blf` chunk | size 48, version 1, flags 2 |
| `0x030` | `chdr` chunk | size 704, version 10, flags 2 |
| `0x2F0` | `mpvr` chunk | size 20520, version 54 (`0x36`), flags 1 |
| `0x5318` | `_eof` chunk | size 17, version 1, flags 1 |

Chunk header is 12 bytes, big-endian: 4-byte signature, `uint32` size (including the
header), `uint16` version, `uint16` flags.

### 1.2 mpvr payload preamble (proven)

Immediately after the 12-byte chunk header, at `0x2FC`:

| Offset | Size | Field |
|---|---|---|
| `0x2FC` | 20 | SHA-1 digest of the variant data (big-endian words) |
| `0x310` | 4 | unused, zero in both files |
| `0x314` | 4 | `uint32` big-endian length of the variant data in bytes |
| `0x318` | n | **variant data — the bit stream starts here, byte-aligned** |
| `0x318+n` | … | zero padding to the end of the chunk |

`0x318` is also hardcoded in ReachVariantEditor's writer
(`base.cpp: memcpy(working + bufsize - size, buffer + 0x318, size)`), so the hashable
region always begins at a fixed file offset.

### 1.3 SHA-1 — solved, and it differs from ReachVariantEditor

The stored digest is:

```
sha1( be32(length) || variant_data )
```

equivalently `sha1(file[0x314 : 0x318 + length])` — the 4-byte big-endian length field
followed immediately by the payload. **Verified against both files**:

| File | stored digest | status |
|---|---|---|
| Firefight Evolved | `dc0b8d4ff6f5558e702d5d103b5255cc0c10ab40` | MATCH |
| Firefight Corvette Evolved | `6eaf84e72364f680a0318a1093b5c3da59a78a42` | MATCH |

This was found by brute-forcing candidate arrangements over a range of lengths; exactly
one arrangement matched, and it matched both files, so it is not a coincidence.

Note the discrepancy with prior art: ReachVariantEditor's writer prepends a 34-byte salt
(`formats/sha1.h: reachSHA1Salt`) before the length word. **That salted form does not
match these MCC files.** The tool computes and prints both so the difference stays
visible. I did not determine why — plausible explanations are that the salt applies to
Xbox 360-era files or to a different engine type, or that MCC changed it; I have not
verified any of those, so treat the unsalted form as "true for MCC Reach firefight
variants" and nothing broader.

### 1.4 Bit order — proven from the data, not assumed

Fields are **MSB-first within each byte, big-endian across bytes**. Source-side this is
`cobb::bitreader::_consume_byte` / `read_bits` in
`helpers/bitreader.h`, which masks off the already-consumed high bits and accumulates
with `result = (result << consumed) | bits`.

Proven at runtime by `python3 -I tools/mpvr.py <file> --prove-bitorder`, which runs the
same field sequence under both orders:

```
MSB-first (big-endian)   engine=4   title='FIREFIGHT EVOLVED'   printable=103
LSB-first                engine=7   title='ļŀ\x90ĀŔĸļŐĘĔ...'    printable=1
```

MSB-first recovers the UTF-16BE title and description and a valid engine type;
LSB-first recovers neither. The task asked for the string table as the self-check: the
variant title/description are UTF-16BE NUL-terminated strings read straight out of the
bit stream, and the per-team names are genuine zlib-backed localized string tables
(section 1.6) — both decode cleanly only under MSB-first.

### 1.5 Field encoding rules (`cobb::bitnumber`)

Every scalar in the stream follows one template, from `helpers/bitnumber.h`:

`bitnumber<bitcount, underlying, offset, presence_bit, if_absent>`

- Read `bitcount` bits unsigned, MSB-first.
- If `offset` is set, **subtract 1** after reading (the game adds 1 before writing so
  that `-1` can be stored in a small unsigned field).
- Sign extension is applied only when the underlying type is signed **and** the field
  uses neither `offset` nor a presence bit (`write_as_signed()`).
- If a `presence_bit` is declared, a single bit precedes the value; the value is present
  only when that bit equals the declared polarity, otherwise the field takes `if_absent`
  and **no value bits are consumed**. Both polarities occur in practice:
  `player_traits.movement.jumpHeight` is present-when-1, and
  `ReachLoadout::nameIndex` is present-when-**0**.
- `bytenumber<T>` is simply `bitnumber<bits_in<T>, T>` — it is **not** byte-aligned, it
  is just a field whose width happens to be 8/16/32/64 bits.

Getting the `offset` and presence-polarity rules right is what makes the parse close to
the bit. They are the single most error-prone part of this format.

### 1.6 Localized string tables

Used here only for the eight team names (`ReachStringTable(1, 0x20, 5, 6)`). Layout,
ported from `formats/localized_string_table.cpp`:

1. `count`, `bitcount(max_count)` bits.
2. For each string, for each of **12 languages**: a 1-bit presence flag, then an
   `offset_bitlength`-bit byte offset into the shared buffer if present (else −1).
3. If `count > 0`: `uncompressed_size` (`buffer_size_bitlength` bits), a 1-bit
   `is_compressed`, then if compressed a second `buffer_size_bitlength`-bit compressed
   size, then that many raw bytes.
4. If compressed: the first 4 bytes of the blob are a redundant uncompressed length and
   must be skipped; the rest is raw zlib. Strings are NUL-terminated UTF-8 at the
   recorded offsets.

The 12 languages are english, japanese, german, french, spanish, mexican, italian,
korean, chinese_traditional, chinese_simplified, portugese, polish.

### 1.7 Firefight variant body — section map

Bit offsets are relative to the start of the variant data at `0x318`. Measured, not
assumed. Only the UGC header's length differs between the two files; everything after it
has identical sizes.

| Bit offset (FE) | Bit offset (FC) | Length | Section |
|---|---|---|---|
| 0 | 0 | 4 | `variant_type` (4 = firefight) |
| 4 | 4 | 2353 / 3041 | UGC header (variable: title/description/author strings) |
| 2357 | 3045 | 1 | `isBuiltIn` |
| 2358 | 3046 | 33 | custom game options → general |
| 2391 | 3079 | 181 | → respawn (incl. a 126-bit player-traits block) |
| 2572 | 3260 | 8 | → social |
| 2580 | 3268 | 511 | → map (base traits + 3 powerup trait blocks) |
| 3091 | 3779 | 1206 | → teams (8 × team data incl. string tables) |
| 4297 | 4985 | 972 | → loadouts (6 palettes × 5 loadouts) |
| 5269 | 5957 | 5 | `scenarioFlags` |
| 5274 | 5962 | 3 | `mccExtensionVersion` |
| 5277 | 5965 | 80 | wave/life/bonus scalars (see below) |
| 5357 | 6045 | 126 | `baseTraitsSpartan` |
| 5483 | 6171 | 126 | `baseTraitsElite` |
| 5609 | 6297 | 26 | `baseTraitsWave` (AI traits) |
| 5635 | 6323 | 260 | custom skull **red** (spartan + elite + wave traits) |
| 5895 | 6583 | 260 | custom skull **yellow** |
| 6155 | 6843 | 260 | custom skull **blue** |
| 6415 | 7103 | 172 | elite respawn options |
| 6587 | 7275 | 324 | `round[0]` |
| 6911 | 7599 | 324 | `round[1]` |
| 7235 | 7923 | 324 | `round[2]` |
| 7559 | 8247 | 12 | `bonusWaveDuration` (seconds) |
| 7571 | 8259 | 18 | `bonusWaveSkulls` |
| 7589 | 8277 | 102 | bonus wave |
| 7691 | 8379 | 8 | `mccExtensionFlags` (only if `mccExtensionVersion >= 2`) |
| **7699** | **8387** | — | end; 5 bits padding to the byte |

The 80-bit scalar run at offset 5277/5965 is, in order:
`waveLimit` (8), `unkB` (4), `bonusTarget` (15), `eliteKillBonus` (15),
`startingLivesSpartan` (7, offset), `startingLivesElite` (7, offset), `unkD` (15),
`maxSpartanExtraLives` (7, offset), `generatorCount` (2).

A player-traits block is a fixed 126 bits when `jumpHeight` is present (117 when
absent): defense 31, offense 48, movement 15 + 10, appearance 14, sensors 8.
A wave-traits (AI) block is 26 bits.

### 1.8 The Megalo section — where it *would* be

For completeness, and because this is what matters if the project moves to a scripted
multiplayer variant. **This is read from ReachVariantEditor's source
(`types/multiplayer.cpp`, `components/megalo/*`), not parsed from these files**, because
these files do not contain it.

In a `multiplayer`/`forge` body the order is:

1. `encodingVersion` (32), `engineVersion` (32)
2. UGC header, `isBuiltIn`, custom game options — same as firefight
3. **Script traits**: count (`bitcount(16)`), then that many script-trait blocks
4. **Script options**: count (`bitcount(16)`), then that many option blocks
5. **Variant string table** (`max_variant_strings = 112`) — the Megalo string table
6. `genericName` string index, localized name / description / category tables
7. engine icon, engine category, map permissions, player-rating params, `scoreToWin`,
   `fireteamsEnabled`, `symmetric`, option toggles (engine + megalo, disabled + hidden)
8. **Script code**:
   - condition count (`bitcount(512)` = 10 bits), then that many **conditions**
   - action count (`bitcount(1024)` = 11 bits), then that many **actions**
   - trigger count (`bitcount(320)`), then that many **triggers**
9. **Script stats**: count (`bitcount(4)`), then that many
10. **Variable declarations**: global, player, object, team — in that order
11. **HUD widget declarations**: count (`bitcount(4)`), then that many
12. **Entry points**, used MP object types
13. **Forge labels**: count (`bitcount(16)`), then that many
14. TU1 data if `encodingVersion >= 0x6B`; forge-specific data if this is a forge variant

Hard limits (`components/megalo/limits.h`): 1024 actions, 512 conditions, 320 triggers,
112 variant strings, 16 script traits, 16 script options, 16 forge labels, 4 script
stats, **4 HUD widgets**, 256 string IDs.

Relevant to this project, MCC Reach Megalo has **107 actions and 18 conditions**. A
headerless raw body of exactly this form is also what ReachVariantEditor's
`read_mglo()` consumes, and it stamps `version = 0x36` (54) — the same chunk version
these files use.

---

## 2. The decoder

`tools/mpvr.py`, Python 3, no third-party dependencies (`zlib` and `hashlib` are
stdlib). `tools/bitreader.py` holds the MSB-first reader.

```
python3 -I tools/mpvr.py <file.bin>                  # readable dump (default)
python3 -I tools/mpvr.py <file.bin> --json           # structured object tree
python3 -I tools/mpvr.py <file.bin> --trace          # per-field bit trace
python3 -I tools/mpvr.py <file.bin> --megalo-probe   # script presence + parse closure
python3 -I tools/mpvr.py <file.bin> --prove-bitorder # MSB vs LSB demonstration
```

The `--trace` mode emits `(absolute bit offset, bit width, field path, value)` for all
996 fields, which is what the diff in section 3 is built from. Every enumeration is
rendered by name (squads, skulls, weapons, abilities, armor abilities, traits, weapon
and vehicle sets), taken from ReachVariantEditor's headers.

Correctness evidence, in order of strength:

1. Both payloads close **exactly** on their declared byte length (5 bits of alignment
   padding, which is expected and required).
2. Both stored SHA-1 digests recompute correctly, independently confirming the length.
3. `--prove-bitorder` recovers human-readable text only under MSB-first.
4. Semantic sanity: `bonusTarget = 10000` (ReachVariantEditor's header comments it as
   "always 10000?"), `waveLimit = 0` (= `no_limit`), 7 starting lives, 20 max extra
   lives, skull counts rising per round, and squad names that read as a deliberately
   authored encounter list.
5. The author timestamps decode to 2023-10-07 and 2025-11-23, matching the two files'
   filesystem mtimes (Oct 7 2023 and Nov 23 2025).

Not implemented: the `multiplayer`/`forge` body and therefore the Megalo opcode
decoder. Writing one was not useful here because neither reference file contains a
script, and I will not ship a generated opcode table I have not been able to validate
against real data. The tool detects the engine type and says so explicitly rather than
guessing.

---

## 3. Diff: generic Firefight vs Corvette

Of **996 decoded fields, 983 are byte-identical**. The complete list of differences:

| Field | Firefight Evolved | Firefight Corvette Evolved |
|---|---|---|
| `header.created_by.timestamp` | 1696702687 (2023-10-07) | 1763923489 (2025-11-23) |
| `header.title` | `FIREFIGHT EVOLVED` | `​ FIREFIGHT CORVETTE EVOLVED` |
| `header.description` | "Used with Halo: Reach Evolved Firefight. Use your Firefight Score to purchase bonuses." | "Used with Halo: Reach Evolved Firefight Corvette. Fight your way through the Corvette to steal valuable Covenant intel." |
| `round[0..2].wave_{initial,main,boss}.uses_dropship` | `True` (all 9) | `False` (all 9) |
| `bonus_wave.uses_dropship` | `True` | `False` |

That is the entire delta. **The only behavioural difference is one boolean per wave:
`usesDropship`, cleared on all ten wave definitions in the Corvette variant** — which
makes sense, since Corvette is a ship interior with no room for Phantom drop-ins, so
squads must spawn in place instead.

Everything else is shared: identical squad tables, identical per-round skulls, identical
player and AI traits, identical custom skulls, identical loadout palettes, identical
team setup, identical lives and bonus settings.

**Answer to the central question:** for the gametype file, essentially *nothing* is
per-map. One flag. If building new map variants, the gametype `.bin` can be copied
wholesale and edited in a few bits; all genuinely map-specific content (squad placement,
objectives, scripting) lives in the map, not here.

---

## 4. The settings the mod actually uses

Common to both files:

- `scenarioFlags = hazards_enabled | weapon_drops_enabled | ammo_crates_enabled`
  (generator flags clear, `generatorCount = 0` — no generator-defence mode)
- `mccExtensionVersion = 2` (current MCC version), `mccExtensionFlags = 0`
- `waveLimit = 0` → `no_limit`: the match does **not** end on a wave count. Termination
  is left to something else, which is consistent with objective-based win conditions
  driven from the map side.
- `bonusTarget = 10000`, `eliteKillBonus = 1`
- `startingLivesSpartan = 7`, `maxSpartanExtraLives = 20`, `startingLivesElite = −1`
- `bonusWaveDuration = 90 s`; bonus-wave skulls: iron, black_eye, tough_luck, catch,
  fog, famine, tilt, mythic
- Per-round skulls escalate: round 0 `tough_luck`; round 1 `tough_luck, catch`;
  round 2 `black_eye, tough_luck, catch`

Squad tables (identical in both files; this is the AI roster):

| Round | Initial (3) | Main (5) | Boss (3) |
|---|---|---|---|
| 0 | jackal_patrol ×3 | elite_patrol, skirmisher_patrol, elite_infantry, brute_patrol, hunter_infantry | elite_strike_team, brute_kill_team, elite_strike_team |
| 1 | jackal_patrol ×3 | elite_infantry, brute_patrol, elite_patrol, brute_infantry, hunter_kill_team | brute_kill_team, elite_strike_team, brute_kill_team |
| 2 | jackal_patrol ×3 | brute_patrol, skirmisher_infantry, elite_patrol, brute_infantry, hunter_strike_team | elite_strike_team, brute_kill_team, elite_strike_team |
| bonus | — | — | grunts ×3 (bonus wave) |

---

## 5. The six mechanisms asked about

Honest status for each. "Proven" means read out of these bytes; "cited" means read from
ReachVariantEditor's source; "inferred" means reasoned, not verified.

### (a) Spending Firefight score as currency — **not in this file**

*Proven:* nothing in the firefight variant body touches score-as-currency. The only
score-adjacent fields are `bonusTarget` (15 bits) and `eliteKillBonus` (15 bits), which
are scoring parameters, not a spending mechanism.

*Cited:* Reach Megalo does have a purchase primitive, and it is not generic score —
it is a separate "requisition" currency, with three dedicated actions:

- action **38** `Modify Player Requisition Money`
- action **39** `Set Player Requisition Purchase Modes`
- action **69** `Set Player Requisition Palette`

plus action **1** `Modify Score` and action **9** `Modify Variable` for arithmetic, and
condition **1** `Compare` for affordability checks. A Megalo implementation would read a
score variable, `Compare` it against a price, then `Modify Score` (debit) and act.

*Not determined:* which of these this mod uses, because the script is not here. Do not
assume it is the requisition system; an hsc implementation in the map could equally use
the engine's own Firefight score directly.

### (b) Spawning AI squads (marines / ODSTs) — **two separate answers**

This is the most important finding of the whole decode.

*Proven — the only AI machinery in this file* is the Firefight wave/squad table, and it
cannot spawn marines or ODSTs:

- Structure: 3 rounds × 3 wave types (`waveInitial`, `waveMain`, `waveBoss`) + 1 bonus
  wave = **10 wave definitions**, each 102 bits:
  `usesDropship` (1) + `orderedSquads` (1) + `squadCount` (4) + **12 × 8-bit squad type**
  (`bitnumber<8, firefight_squad, offset>`, so the stored byte is `value + 1` and `0`
  means `none`).
- So a variant can reference at most **12 squad types per wave definition, 120 total**.
  `squadCount` says how many of the 12 slots are live; the engine spawns **six instances
  of one selected squad type per wave**, and advances the wave when all but three enemies
  are dead (per ReachVariantEditor's `firefight_round.h` commentary — cited, not
  verified by me).
- Squad identities are **indices into the map's SMDT (Survival Mode Globals) tag**, not
  into anything in this file. The 32 known values are all Covenant (brutes, elites,
  grunts, jackals, skirmishers, hunters, engineers, guta, heretics). **There is no
  marine or ODST squad value, and no spawn-point reference of any kind in the gametype
  file** — placement is entirely map-side.

*Proven — Megalo has no AI spawning at all:* grepping ReachVariantEditor's complete
107-action and 18-condition tables for `ai`, `squad`, `firefight` or `spawn`-AI returns
**zero** matches. Megalo can create *objects* (action **2** `Create Object`, action **87**
`Create Object Equidistant`) — which covers the auto turret and the vehicles — but it has
no verb that spawns a biped squad or an AI character.

*Cited — the bridge:* action **100** `Call HaloScript Function` is, in
ReachVariantEditor's own words, *"[MCC-only; backported from Halo 4.] Calls a HaloScript
function that the map has made available for use by Megalo. This appears to be intended
mainly for \*.MAP mod authors who are creating map-and-Megalo combo mods."* It takes one
argument, a `VariantStringID` naming the function.

*Inferred, and flagged as inference:* marine and ODST reinforcements, the MAC strike,
the glassing beam, the Pelican extraction and Sentinel hacking are therefore implemented
**map-side in HaloScript**, either triggered directly by the map's own scenario scripts
or invoked from Megalo via action 100. Firefight maps are campaign-style scenarios, so
they have full hsc scripting and AI squad placement available. I have not seen the map
files — they are not in `~/Desktop/Firefight Evolved/`, which contains only these two
`.bin` files — so this is reasoning from what the format can and cannot express, not a
verified claim.

### (c) HUD widgets for the purchase menu — **not in this file**

*Proven:* the firefight body has no widget declarations. Nothing in the 963/1049 bytes
describes a menu.

*Cited:* Megalo supports a maximum of **4 HUD widgets** (`max_script_widgets = 4`),
declared in the widget block described in section 1.8, and manipulated by actions
**46** `Set Widget Text`, **47** `Set Widget Value Text`, **48** `Set Meter Parameters`,
**49** `Set Widget Icon`, **50** `Set Widget Visibility`. Four widgets is a hard ceiling
and is a real design constraint for any menu built this way. Objective text has separate
actions (**56** `Set Objective Description for Player`, **57**/**58** for icon caption
and icon).

### (d) Round / objective win conditions — **not in this file**

*Proven:* the firefight body's round structure is purely an encounter schedule — skulls
and squad lists per round. The round-ending conditions available are the generic engine
settings (`general.roundLimit = 0`, `roundsToWin`, `timeLimit`, and `waveLimit = 0` =
no limit). Nothing encodes "survive until Pelican extraction" or "buy the MAC before the
glassing beam".

*Cited:* Megalo's round-control verb is action **21** `End Round`; timers are actions
**17** `Set Timer Rate` / **43** `Reset Timer` with condition **5** `Timer Is Zero`.

*Inferred:* with `waveLimit = 0` and no round limit, these variants are deliberately
configured to run indefinitely so that the map's own scripting decides when and how the
match ends. That is consistent with the described objective-based win conditions, and it
is the single strongest piece of in-file evidence that the logic is external.

---

## 6. Can we re-encode a modified script?

Two separate questions, with two different answers.

### Re-encoding a modified **firefight settings** file: **yes, confidently.**

- The format is fully decoded and the parse closes to the bit on both files, so a writer
  is a mechanical mirror of the reader.
- The integrity check is solved and verified: recompute
  `sha1(be32(length) || data)` and write it at `0x2FC`, with the length at `0x314`.
  There is no encryption, no signature, and no second checksum inside the chunk.
- The chunk is fixed-size with zero padding, so a payload that changes length (title,
  description, author names are variable-length) needs no chunk resizing, as long as it
  stays under 20520 − 12 − 28 = 20480 bytes. Current payloads use under 5% of that.
- Known obstacles, all minor: the `chdr` chunk duplicates header metadata and must be
  kept in sync (ReachVariantEditor calls this `synch_chdr_to_mpvr`) — that chunk is the
  other agent's scope; and the `offset`/presence-bit rules in section 1.5 must be
  reproduced exactly or the stream desynchronises silently.
- Caveat: I have verified round-trip *hashing*, not round-trip *bytes*. A writer should
  be validated by re-encoding an unmodified file and asserting byte equality before
  anybody trusts it. That is a small, well-defined next step, and `tools/mpvr.py`'s trace
  mode gives the ground truth to diff against.

### Re-encoding a modified **Megalo script**: **not applicable to these files, and
substantially harder in general.**

- There is no script here to modify, so for this mod the question is moot. Changing the
  purchase or AI behaviour means editing the **map**, not the gametype.
- If the project moves to a scripted multiplayer variant, re-encoding is known to be
  feasible — ReachVariantEditor ships a working Megalo compiler and decompiler, and
  MegaloEdit is 343's official tool — but the obstacles are real: variable-width opcode
  argument encodings, index-into-table references for strings, forge labels and object
  types that must all be renumbered consistently, hard limits (1024 actions, 512
  conditions, 320 triggers, 4 widgets, 112 strings), and the zlib-compressed string
  table. Writing that from scratch here would duplicate ReachVariantEditor; the sensible
  path is to use ReachVariantEditor or MegaloEdit directly rather than extend `mpvr.py`.
- Also worth knowing: Firefight and multiplayer are *different engine types*. A Megalo
  script cannot simply be added to a firefight variant — the firefight body has no place
  to put one. Scripted behaviour on Firefight maps has to come from the map's HaloScript,
  or the mode has to be rebuilt as a multiplayer variant on a Firefight-style map.

---

## 7. Sources

- **DavidJCobb/ReachVariantEditor** (GPLv3) — note the repository is
  `ReachVariantEditor`, not `ReachVariantTool`; the brief's URL 404s. Cloned at
  `/tmp/rvt/ReachVariantEditor`. Primary reference for every bit width, field order and
  opcode name cited above. Key files: `helpers/bitreader.h`, `helpers/bitnumber.h`,
  `game_variants/base.cpp`, `game_variants/types/firefight.{h,cpp}`,
  `game_variants/types/multiplayer.cpp`, `game_variants/components/*`,
  `game_variants/components/megalo/{actions,conditions,limits}.*`,
  `formats/{localized_string_table,ugc_header,sha1}.*`.
- Opcode names and indices in section 5 were extracted programmatically from
  `actionFunctionList` (107 entries) and `conditionFunctionList` (18 entries) in array
  order, so the indices are the real opcode numbers.
- Not consulted: MegaloEdit's own documentation, c20.reclaimers.net, Assembly. They were
  unnecessary once it was established that these files contain no script;
  ReachVariantEditor's source was sufficient and is directly verifiable.

## 8. What I did not do

- Did not implement the Megalo opcode decoder, for the reasons in section 2.
- Did not determine why ReachVariantEditor's SHA-1 salt does not apply here.
- Did not examine the mod's map files; they are not present on this machine.
- Did not verify ReachVariantEditor's claims about engine runtime behaviour (six squads
  spawned per wave, reinforcement threshold, Set-based squad cycling). Those are quoted
  from its source comments and are labelled as cited, not proven.
