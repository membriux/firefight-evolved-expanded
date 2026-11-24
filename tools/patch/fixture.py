#!/usr/bin/env python3
"""
fixture.py -- synthetic Halo: Reach MCC cache files with *realistic tag content*.

``tools/map/test_parse_map.build_cache`` builds a structurally valid cache whose
tag bodies are junk byte patterns. That is enough to test the container layer and
not enough to test a field-level patcher. This module builds a cache whose
``scnr``, ``sqtm``, ``smdt`` and ``wave`` tags contain real structures:

  * a ``scnr`` with a script string blob, an ``hs_syntax_datum_block``
    (0x18-byte expression nodes, correctly chained, with group nodes pointing at
    their ``function_name`` children), an ``hs_scripts_block``, an
    ``hs_globals_block`` and a ``squads_block`` with designer cells;
  * two ``sqtm`` squad templates with cell templates and character choices;
  * an ``smdt`` with wave templates;
  * a ``wave`` with squad specifications.

Every structure offset below is a LITERAL, written out by hand from
``research/13-map-write-feasibility.md`` §4.1 (which transcribes Assembly's
``LayoutsU13`` XML) and from the field lists in the MCC definition dump. They are
deliberately *not* computed with ``tagdefs``: the test suite asserts that
``tagdefs`` derives these same numbers, so the fixture is an independent check on
the resolver rather than a tautology.

SYNTHETIC ONLY. No real map was read, copied or parsed to produce this.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "map"))
import reach_cache as rc                                  # noqa: E402

HEADER_SIZE = 0xA000
DEBUG_OFF = HEADER_SIZE
META_OFF = 0x20000

# --- literal offsets (see module docstring) --------------------------------
SCNR_SIZE = 0x858
SCNR_SQUADS = 0x398          # block: count @+0, address @+4
SCNR_SCRIPT_STRING = 0x41C   # data ref: size @+0, address @+0xC
SCNR_SCRIPTS = 0x430         # block
SCNR_GLOBALS = 0x43C         # block
SCNR_SYNTAX = 0x504          # block
NODE_SIZE = 0x18
SCRIPT_SIZE = 0x18
GLOBAL_SIZE = 0x28
SQUAD_SIZE = 0x6C
CELL_SIZE = 0x6C
SQTM_ROOT_SIZE = 0x10
SQTM_CELL_SIZE = 0x60
SQTM_CHOICE_SIZE = 0x20
SMDT_ROOT_SIZE = 0x70
SMDT_WAVE_SIZE = 0x14
WAVE_ROOT_SIZE = 0x0C
WAVE_SPEC_SIZE = 0x24

# hs_types_enum indices used below (scenario.json enums_flags.hs_types_enum)
T_SPECIAL_FORM = 1
T_FUNCTION_NAME = 2
T_VOID = 4
T_BOOLEAN = 5
T_REAL = 6
T_SHORT = 7
T_LONG = 8
T_AI = 19

NODE_SALT_BASE = 0xE373

STRINGS = [
    "scenario",                 # 0
    "survival_mode_globals",    # 1
    "squad_template",           # 2
    "ff_buy_marines",           # 3  script name
    "ff_round_gate",            # 4  script name
    "g_marine_budget",          # 5  script global name
    "ff_marines_light",         # 6  sqtm name
    "ff_marines_heavy",         # 7  sqtm name
    "cell_rifles",              # 8
    "cell_rockets",             # 9
    "wave_marines",             # 10
    "activity_patrol",          # 11
    "movement_default",         # 12
    "marine_squad",             # 13
]
NS_COUNTS = [len(STRINGS), 2]          # namespace 0 holds all of the above

SID = {s: i for i, s in enumerate(STRINGS)}

TAGS = [
    ("scnr", "levels\\dlc\\cex_ff_halo\\cex_ff_halo"),
    ("smdt", "multiplayer\\survival\\survival_mode_globals"),
    ("sqtm", "ai\\squad_templates\\ff_marines_light"),
    ("sqtm", "ai\\squad_templates\\ff_marines_heavy"),
    ("wave", "ai\\wave_templates\\wave_marines"),
    ("char", "characters\\marine\\marine"),
    ("hsc*", "scripts\\cex_ff_halo_firefight"),
]
GROUPS = ["scnr", "smdt", "sqtm", "wave", "char", "hsc*"]

HSC_SOURCE = "(script static void ff_buy_marines\n  (if (>= (player_score) 500)\n    (ai_place marine_squad)))\n"
HSC_NAME = "cex_ff_halo_firefight"

# --- the script string blob -------------------------------------------------
BLOB_STRINGS = ["begin", "if", ">=", "player_score", "ai_place", "ai_squad_count",
                "sleep", "survival_mode_round", "ff_buy_marines", "ff_round_gate",
                "g_marine_budget"]


def _blob():
    out, offs = bytearray(), {}
    for s in BLOB_STRINGS:
        offs[s] = len(out)
        out += s.encode("ascii") + b"\x00"
    while len(out) % 4:
        out.append(0)
    return bytes(out), offs


SCRIPT_BLOB, BLOB_OFF = _blob()

# --- the expression nodes ---------------------------------------------------
# (type, flags, next, source_string_or_None, data, line)
# data is filled with a datum for group nodes by _link() below.
NEXT_END = 0xFFFFFFFF

#  idx  role
#   0   group  (begin ...)            script 0 root
#   1   fn     begin
#   2   group  (if ...)
#   3   fn     if
#   4   group  (>= ...)
#   5   fn     >=
#   6   group  (player_score)
#   7   fn     player_score
#   8   const  500            <- the price
#   9   group  (ai_place ...)
#  10   fn     ai_place
#  11   ai ref 2              <- which squad the purchase delivers
#  12   const  2              <- concurrent cap
#  13   group  (begin ...)            script 1 root
#  14   fn     begin
#  15   group  (>= ...)
#  16   fn     >=
#  17   group  (survival_mode_round)
#  18   fn     survival_mode_round
#  19   const  3              <- round gate
#  20   const  30.0 (real)    <- cooldown seconds
#  21   const  1000           <- script global initialiser
NODES = [
    dict(kind="group", type=T_VOID, child=1, next=NEXT_END, src="begin", line=1),
    dict(kind="fn", type=T_FUNCTION_NAME, next=2, src="begin", data=0x0012, line=1),
    dict(kind="group", type=T_VOID, child=3, next=NEXT_END, src="if", line=2),
    dict(kind="fn", type=T_SPECIAL_FORM, next=4, src="if", data=0x0003, line=2),
    dict(kind="group", type=T_BOOLEAN, child=5, next=9, src=">=", line=2),
    dict(kind="fn", type=T_FUNCTION_NAME, next=6, src=">=", data=0x0051, line=2),
    dict(kind="group", type=T_LONG, child=7, next=8, src="player_score", line=2),
    dict(kind="fn", type=T_FUNCTION_NAME, next=NEXT_END, src="player_score", data=0x0233, line=2),
    dict(kind="const", type=T_SHORT, next=NEXT_END, data=500, line=42),
    dict(kind="group", type=T_VOID, child=10, next=NEXT_END, src="ai_place", line=43),
    dict(kind="fn", type=T_FUNCTION_NAME, next=11, src="ai_place", data=0x0119, line=43),
    dict(kind="const", type=T_AI, next=12, data=2, line=43),
    dict(kind="const", type=T_SHORT, next=NEXT_END, data=2, line=44),
    dict(kind="group", type=T_VOID, child=14, next=NEXT_END, src="begin", line=10),
    dict(kind="fn", type=T_FUNCTION_NAME, next=15, src="begin", data=0x0012, line=10),
    dict(kind="group", type=T_BOOLEAN, child=16, next=20, src=">=", line=12),
    dict(kind="fn", type=T_FUNCTION_NAME, next=17, src=">=", data=0x0051, line=12),
    dict(kind="group", type=T_SHORT, child=18, next=19, src="survival_mode_round", line=12),
    dict(kind="fn", type=T_FUNCTION_NAME, next=NEXT_END, src="survival_mode_round", data=0x0301, line=12),
    dict(kind="const", type=T_SHORT, next=NEXT_END, data=3, line=12),
    dict(kind="const", type=T_REAL, next=NEXT_END, data=30.0, line=13),
    dict(kind="const", type=T_LONG, next=NEXT_END, data=1000, line=3),
]
SCRIPTS = [
    # (name sid, script type, return type, root node)
    (SID["ff_buy_marines"], 3, T_VOID, 0),      # 3 = static
    (SID["ff_round_gate"], 2, T_VOID, 13),      # 2 = continuous
]
SCRIPT_GLOBALS = [(SID["g_marine_budget"], T_LONG, 21)]

# Addresses of the interesting values, filled in by build() for the tests.
LANDMARKS: dict = {}


def datum(index: int) -> int:
    return (((NODE_SALT_BASE + index) & 0xFFFF) << 16) | (index & 0xFFFF)


def _nodes_blob(endian: str) -> bytes:
    out = bytearray()
    for i, n in enumerate(NODES):
        rec = bytearray(NODE_SIZE)
        src = BLOB_OFF.get(n.get("src"), 0) if n.get("src") else 0
        if n["kind"] == "group":
            data = datum(n["child"])
        elif n["type"] == T_REAL:
            data = struct.unpack(endian + "I", struct.pack(endian + "f", n["data"]))[0]
        else:
            data = n.get("data", 0) & 0xFFFFFFFF
        opcode = n.get("data", 0) if n["kind"] == "fn" else 0
        struct.pack_into(endian + "H", rec, 0x00, (NODE_SALT_BASE + i) & 0xFFFF)
        struct.pack_into(endian + "H", rec, 0x02, opcode & 0xFFFF)
        struct.pack_into(endian + "h", rec, 0x04, n["type"])
        struct.pack_into(endian + "h", rec, 0x06, 0)
        struct.pack_into(endian + "I", rec, 0x08, n["next"] if n["next"] == NEXT_END else datum(n["next"]))
        struct.pack_into(endian + "I", rec, 0x0C, src)
        struct.pack_into(endian + "I", rec, 0x10, data)
        struct.pack_into(endian + "h", rec, 0x14, n["line"])
        out += rec
    return bytes(out)


# ---------------------------------------------------------------------------
# tag blob builders. Each takes the tag's offset inside the meta area and a
# ``contract`` callable (virtual address -> stored pointer).
# ---------------------------------------------------------------------------

def build_scnr(base: int, meta_addr, contract, endian: str) -> bytes:
    body = bytearray(SCNR_SIZE)
    tail = bytearray()

    def place(blob, align=4):
        while len(tail) % align:
            tail.append(0)
        off = SCNR_SIZE + len(tail)
        tail.extend(blob)
        return off

    # --- squads (2) with designer cells -----------------------------------
    cells = bytearray()
    for i, (name, count, upgrade) in enumerate([("cell_rifles", 4, 0), ("cell_rockets", 2, 2)]):
        rec = bytearray(CELL_SIZE)
        struct.pack_into(endian + "I", rec, 0x00, SID[name])
        struct.pack_into(endian + "H", rec, 0x04, 0x0F)              # difficulty flags
        struct.pack_into(endian + "h", rec, 0x08, 1)                 # round range lower
        struct.pack_into(endian + "h", rec, 0x0A, 5)                 # round range upper
        struct.pack_into(endian + "h", rec, 0x0C, 1)                 # set range lower
        struct.pack_into(endian + "h", rec, 0x0E, 3)                 # set range upper
        struct.pack_into(endian + "h", rec, 0x10, count)             # normal diff count
        struct.pack_into(endian + "h", rec, 0x12, upgrade)           # major upgrade
        struct.pack_into(endian + "h", rec, 0x46, -1)                # vehicle type (none)
        struct.pack_into(endian + "I", rec, 0x4C, SID["activity_patrol"])
        struct.pack_into(endian + "I", rec, 0x54, SID["activity_patrol"])
        struct.pack_into(endian + "I", rec, 0x58, SID["movement_default"])
        cells += rec
    cells_off = place(bytes(cells), 16)

    squads = bytearray()
    for i, name in enumerate(["marine_rally", "marine_reserve"]):
        rec = bytearray(SQUAD_SIZE)
        rec[0x00:0x00 + len(name)] = name.encode("ascii")
        struct.pack_into(endian + "I", rec, 0x20, 0x10)              # flags: initially placed
        struct.pack_into(endian + "h", rec, 0x24, 0)                 # team
        struct.pack_into(endian + "h", rec, 0x26, -1)
        struct.pack_into(endian + "h", rec, 0x28, -1)
        struct.pack_into(endian + "h", rec, 0x2A, -1)
        struct.pack_into(endian + "h", rec, 0x2C, -1)
        struct.pack_into(endian + "h", rec, 0x2E, -1)
        struct.pack_into(endian + "i", rec, 0x48, 1)                 # wave placement filter
        struct.pack_into(endian + "I", rec, 0x4C, SID["ff_marines_light"])
        struct.pack_into(endian + "i", rec, 0x50, 2)                 # squad template index!
        if i == 0:                                                   # designer cells
            struct.pack_into(endian + "i", rec, 0x54, 2)
            struct.pack_into(endian + "I", rec, 0x58, contract(meta_addr(base + cells_off)))
        squads += rec
    squads_off = place(bytes(squads), 16)

    blob_off = place(SCRIPT_BLOB, 4)
    nodes_off = place(_nodes_blob(endian), 16)

    scripts = bytearray()
    for (name_sid, stype, rtype, root) in SCRIPTS:
        rec = bytearray(SCRIPT_SIZE)
        struct.pack_into(endian + "I", rec, 0x00, name_sid)
        struct.pack_into(endian + "h", rec, 0x04, stype)
        struct.pack_into(endian + "h", rec, 0x06, rtype)
        struct.pack_into(endian + "I", rec, 0x08, datum(root))
        scripts += rec
    scripts_off = place(bytes(scripts), 16)

    globals_blob = bytearray()
    for (name_sid, gtype, root) in SCRIPT_GLOBALS:
        rec = bytearray(GLOBAL_SIZE)
        name = STRINGS[name_sid]
        rec[0x00:0x00 + len(name)] = name.encode("ascii")
        struct.pack_into(endian + "h", rec, 0x20, gtype)
        struct.pack_into(endian + "I", rec, 0x24, datum(root))
        globals_blob += rec
    globals_off = place(bytes(globals_blob), 16)

    # --- root struct pointers ---------------------------------------------
    struct.pack_into(endian + "i", body, SCNR_SQUADS + 0, 2)
    struct.pack_into(endian + "I", body, SCNR_SQUADS + 4, contract(meta_addr(base + squads_off)))
    struct.pack_into(endian + "i", body, SCNR_SCRIPT_STRING + 0, len(SCRIPT_BLOB))
    struct.pack_into(endian + "I", body, SCNR_SCRIPT_STRING + 0xC, contract(meta_addr(base + blob_off)))
    struct.pack_into(endian + "i", body, SCNR_SCRIPTS + 0, len(SCRIPTS))
    struct.pack_into(endian + "I", body, SCNR_SCRIPTS + 4, contract(meta_addr(base + scripts_off)))
    struct.pack_into(endian + "i", body, SCNR_GLOBALS + 0, len(SCRIPT_GLOBALS))
    struct.pack_into(endian + "I", body, SCNR_GLOBALS + 4, contract(meta_addr(base + globals_off)))
    struct.pack_into(endian + "i", body, SCNR_SYNTAX + 0, len(NODES))
    struct.pack_into(endian + "I", body, SCNR_SYNTAX + 4, contract(meta_addr(base + nodes_off)))

    LANDMARKS["scnr_base"] = base
    LANDMARKS["nodes_off"] = base + nodes_off
    LANDMARKS["price_node_value"] = base + nodes_off + 8 * NODE_SIZE + 0x10
    LANDMARKS["squad_ref_node_value"] = base + nodes_off + 11 * NODE_SIZE + 0x10
    LANDMARKS["cap_node_value"] = base + nodes_off + 12 * NODE_SIZE + 0x10
    LANDMARKS["gate_node_value"] = base + nodes_off + 19 * NODE_SIZE + 0x10
    LANDMARKS["cooldown_node_value"] = base + nodes_off + 20 * NODE_SIZE + 0x10
    LANDMARKS["node_next_0"] = base + nodes_off + 0x08
    LANDMARKS["syntax_count"] = base + SCNR_SYNTAX
    LANDMARKS["cell0_count"] = base + cells_off + 0x10
    return bytes(body) + bytes(tail)


def build_sqtm(base: int, meta_addr, contract, endian: str, which: int) -> bytes:
    body = bytearray(SQTM_ROOT_SIZE)
    tail = bytearray()

    def place(blob, align=16):
        while len(tail) % align:
            tail.append(0)
        off = SQTM_ROOT_SIZE + len(tail)
        tail.extend(blob)
        return off

    choices = bytearray()
    for chance in (70, 30):
        rec = bytearray(SQTM_CHOICE_SIZE)
        struct.pack_into(endian + "H", rec, 0x00, 0x0F)       # difficulty flags
        struct.pack_into(endian + "h", rec, 0x04, 1)          # round range lower
        struct.pack_into(endian + "h", rec, 0x06, 4)          # round range upper
        struct.pack_into(endian + "h", rec, 0x08, 1)          # set range lower
        struct.pack_into(endian + "h", rec, 0x0A, 3)          # set range upper
        struct.pack_into(endian + "I", rec, 0x0C, rc.fourcc_to_int("char"))
        struct.pack_into(endian + "I", rec, 0x18, 5)          # datum: the char tag
        struct.pack_into(endian + "h", rec, 0x1C, chance)     # chance
        choices += rec
    choices_off = place(bytes(choices))

    cells = bytearray()
    counts = (3, 2) if which == 0 else (6,)
    for i, count in enumerate(counts):
        rec = bytearray(SQTM_CELL_SIZE)
        struct.pack_into(endian + "I", rec, 0x00, SID["cell_rifles" if i == 0 else "cell_rockets"])
        struct.pack_into(endian + "H", rec, 0x04, 0x0F)
        struct.pack_into(endian + "h", rec, 0x08, 2)          # round range lower
        struct.pack_into(endian + "h", rec, 0x0A, 5)          # round range upper
        struct.pack_into(endian + "h", rec, 0x0C, 1)
        struct.pack_into(endian + "h", rec, 0x0E, 3)
        struct.pack_into(endian + "h", rec, 0x10, count)      # normal diff count
        struct.pack_into(endian + "h", rec, 0x12, 1 if i else 0)   # major upgrade
        if i == 0:
            struct.pack_into(endian + "i", rec, 0x14, 2)      # character type count
            struct.pack_into(endian + "I", rec, 0x18, contract(meta_addr(base + choices_off)))
        struct.pack_into(endian + "h", rec, 0x44, 0)          # grenade type
        struct.pack_into(endian + "I", rec, 0x58, SID["activity_patrol"])
        struct.pack_into(endian + "I", rec, 0x5C, SID["movement_default"])
        cells += rec
    cells_off = place(bytes(cells))

    struct.pack_into(endian + "I", body, 0x00, SID["ff_marines_light" if which == 0 else "ff_marines_heavy"])
    struct.pack_into(endian + "i", body, 0x04, len(counts))
    struct.pack_into(endian + "I", body, 0x08, contract(meta_addr(base + cells_off)))
    if which == 0:
        LANDMARKS["sqtm0_cell0_count"] = base + cells_off + 0x10
        LANDMARKS["sqtm0_cell0_round_lower"] = base + cells_off + 0x08
        LANDMARKS["sqtm0_cells_blockcount"] = base + 0x04
        LANDMARKS["sqtm0_cell0_choice0_chance"] = base + choices_off + 0x1C
        LANDMARKS["sqtm0_cell0_choice0_datum"] = base + choices_off + 0x18
        LANDMARKS["sqtm0_name_sid"] = base + 0x00
    return bytes(body) + bytes(tail)


def build_smdt(base: int, meta_addr, contract, endian: str) -> bytes:
    body = bytearray(SMDT_ROOT_SIZE)
    waves = bytearray()
    for i, name in enumerate(["wave_marines", "wave_marines"]):
        rec = bytearray(SMDT_WAVE_SIZE)
        struct.pack_into(endian + "I", rec, 0x00, SID[name])
        struct.pack_into(endian + "I", rec, 0x04, rc.fourcc_to_int("wave"))
        struct.pack_into(endian + "I", rec, 0x10, 4)          # datum: the wave tag
        waves += rec
    waves_off = SMDT_ROOT_SIZE
    struct.pack_into(endian + "i", body, 0x40, 2)
    struct.pack_into(endian + "I", body, 0x44, contract(meta_addr(base + waves_off)))
    LANDMARKS["smdt_wave0_sid"] = base + waves_off
    return bytes(body) + bytes(waves)


def build_wave(base: int, meta_addr, contract, endian: str) -> bytes:
    body = bytearray(WAVE_ROOT_SIZE)
    specs = bytearray()
    for i, (weight, lo, hi, filt) in enumerate([(50, 1, 2, 1), (20, 2, 4, 3)]):
        rec = bytearray(WAVE_SPEC_SIZE)
        struct.pack_into(endian + "I", rec, 0x00, rc.fourcc_to_int("sqtm"))
        struct.pack_into(endian + "I", rec, 0x0C, 2 + i)      # datum: a sqtm tag
        struct.pack_into(endian + "H", rec, 0x10, 0x0F)       # difficulty flags
        struct.pack_into(endian + "h", rec, 0x14, 2)          # round range lower
        struct.pack_into(endian + "h", rec, 0x16, 5)          # round range upper
        struct.pack_into(endian + "h", rec, 0x18, 1)          # set range lower
        struct.pack_into(endian + "h", rec, 0x1A, 3)          # set range upper
        struct.pack_into(endian + "h", rec, 0x1C, weight)     # weight
        struct.pack_into(endian + "b", rec, 0x1E, lo)         # min spawn
        struct.pack_into(endian + "b", rec, 0x1F, hi)         # max spawn
        struct.pack_into(endian + "i", rec, 0x20, filt)       # placement filter
        specs += rec
    specs_off = WAVE_ROOT_SIZE
    struct.pack_into(endian + "i", body, 0x00, 2)
    struct.pack_into(endian + "I", body, 0x04, contract(meta_addr(base + specs_off)))
    LANDMARKS["wave_spec0_weight"] = base + specs_off + 0x1C
    LANDMARKS["wave_spec0_min_spawn"] = base + specs_off + 0x1E
    LANDMARKS["wave_spec0_max_spawn"] = base + specs_off + 0x1F
    LANDMARKS["wave_spec0_sqtm_datum"] = base + specs_off + 0x0C
    LANDMARKS["wave_spec0_round_lower"] = base + specs_off + 0x14
    LANDMARKS["wave_specs_blockcount"] = base + 0x00
    return bytes(body) + bytes(specs)


def build_hsc(base: int, meta_addr, contract, endian: str) -> bytes:
    body = bytearray(0x30)
    body[0:len(HSC_NAME)] = HSC_NAME.encode("ascii")
    struct.pack_into(endian + "i", body, 0x20, len(HSC_SOURCE) + 1)
    struct.pack_into(endian + "I", body, 0x2C, contract(meta_addr(base + 0x30)))
    return bytes(body) + HSC_SOURCE.encode("ascii") + b"\x00"


def build_char(base: int, meta_addr, contract, endian: str) -> bytes:
    return bytes(0x40)          # a stub: it only has to exist as a reference target


BUILDERS = {
    "scnr": build_scnr,
    "smdt": build_smdt,
    "wave": build_wave,
    "hsc*": build_hsc,
    "char": build_char,
}


# ---------------------------------------------------------------------------
# assembly
# ---------------------------------------------------------------------------

def build(variant: rc.HeaderVariant = rc.V_MCC_U8) -> bytes:
    """Build a complete, parseable cache file with realistic tag contents."""
    LANDMARKS.clear()
    e = variant.endian
    magic = rc.HEADER_MAGIC_LE if e == "<" else rc.HEADER_MAGIC_BE
    footer = b"toof" if e == "<" else b"foot"
    vbase = 0x50010000 if variant.expand_magic else 0x40000000

    def meta_addr(off_in_meta):
        return vbase + off_in_meta

    def contract(virtual):
        if variant.expand_magic:
            if (virtual - variant.expand_magic) & 3:
                raise ValueError("unaligned fixture pointer 0x%X" % virtual)
            return (virtual - variant.expand_magic) >> 2
        return virtual

    # --- debug section -----------------------------------------------------
    dbg = bytearray()
    sid_data = bytearray()
    sid_offsets = []
    for s in STRINGS:
        sid_offsets.append(len(sid_data))
        sid_data += s.encode("ascii") + b"\x00"
    name_data = bytearray()
    name_offsets = []
    for _group, path in TAGS:
        name_offsets.append(len(name_data))
        name_data += path.encode("ascii") + b"\x00"

    def place_dbg(blob):
        off = DEBUG_OFF + len(dbg)
        dbg.extend(blob)
        while len(dbg) % 4:
            dbg.append(0)
        return off

    sid_index_off = place_dbg(b"".join(struct.pack(e + "i", o) for o in sid_offsets))
    sid_data_off = place_dbg(bytes(sid_data))
    ns_table_off = place_dbg(b"".join(struct.pack(e + "i", c) for c in NS_COUNTS))
    name_index_off = place_dbg(b"".join(struct.pack(e + "i", o) for o in name_offsets))
    name_data_off = place_dbg(bytes(name_data))
    debug_size = len(dbg)

    # --- tag area ----------------------------------------------------------
    spec = variant.index_header
    meta = bytearray(spec.size)

    def align(n=16):
        while len(meta) % n:
            meta.append(0)

    align()
    group_table_off = len(meta)
    for g in GROUPS:
        meta += struct.pack(e + "I", rc.fourcc_to_int(g))
        meta += struct.pack(e + "I", 0xFFFFFFFF)
        meta += struct.pack(e + "I", 0xFFFFFFFF)
        meta += struct.pack(e + "I", 0)
    align()
    tag_table_off = len(meta)
    meta += bytes(len(TAGS) * 8)
    align()
    global_table_off = len(meta)
    meta += struct.pack(e + "I", rc.fourcc_to_int("scnr")) + struct.pack(e + "I", 0x00010000)
    meta += struct.pack(e + "I", rc.fourcc_to_int("smdt")) + struct.pack(e + "I", 0x00010001)
    align()
    interop_table_off = len(meta)
    meta += struct.pack(e + "I", 0) + struct.pack(e + "i", 0)
    align()

    tag_offsets = []
    sqtm_seen = 0
    for group, _path in TAGS:
        align()
        base = len(meta)
        if group == "sqtm":
            blob = build_sqtm(base, meta_addr, contract, e, sqtm_seen)
            sqtm_seen += 1
        else:
            blob = BUILDERS[group](base, meta_addr, contract, e)
        meta += blob
        tag_offsets.append(base)
    align()
    meta_size = len(meta)

    for i, (group, _path) in enumerate(TAGS):
        rec = tag_table_off + i * 8
        struct.pack_into(e + "h", meta, rec + 0, GROUPS.index(group))
        struct.pack_into(e + "H", meta, rec + 2, 0x4153 + i)
        struct.pack_into(e + "I", meta, rec + 4, contract(meta_addr(tag_offsets[i])) & 0xFFFFFFFF)

    def ih_put(kind, off, value):
        struct.pack_into(e + rc._KIND_FMT[kind], meta, off, value)

    ih_put("i32", spec.group_count, len(GROUPS))
    ih_put(spec.ptr_kind, spec.group_table, meta_addr(group_table_off))
    ih_put("i32", spec.tag_count, len(TAGS))
    ih_put(spec.ptr_kind, spec.tag_table, meta_addr(tag_table_off))
    ih_put("i32", spec.global_count, 2)
    ih_put(spec.ptr_kind, spec.global_table, meta_addr(global_table_off))
    ih_put("i32", spec.interop_count, 1)
    ih_put(spec.ptr_kind, spec.interop_table, meta_addr(interop_table_off))
    meta[spec.magic:spec.magic + 4] = b"sgat" if e == "<" else b"tags"

    # --- file --------------------------------------------------------------
    total = META_OFF + meta_size
    out = bytearray(total)
    out[0:4] = magic
    out[4:8] = struct.pack(e + "i", variant.engine_version)
    out[HEADER_SIZE - 4:HEADER_SIZE] = footer
    out[DEBUG_OFF:DEBUG_OFF + debug_size] = dbg
    out[META_OFF:META_OFF + meta_size] = meta

    build_string = None
    for b, (name, _engine) in rc.BUILD_TABLE.items():
        if name == variant.name:
            build_string = b
            break
    values = {
        "file_size": total,
        "index_header_address": meta_addr(0),
        "tag_buffer_offset": META_OFF,
        "virtual_size": meta_size,
        "build_string": build_string or "unknown build",
        "type": 0,
        "string_table_count": len(STRINGS),
        "string_table_size": len(sid_data),
        "string_index_table_offset": sid_index_off,
        "string_table_offset": sid_data_off,
        "string_namespace_table_count": len(NS_COUNTS),
        "string_namespace_table_offset": ns_table_off,
        "cache_build_date_high": 0x01D9B0A0,
        "cache_build_date_low": 0x12345678,
        "internal_name": "cex_ff_halo",
        "scenario_name": "levels\\dlc\\cex_ff_halo\\cex_ff_halo",
        "file_table_count": len(TAGS),
        "file_table_offset": name_data_off,
        "file_table_size": len(name_data),
        "file_index_table_offset": name_index_off,
        "checksum": 0,
        "virtual_base_address": vbase,
        "xdk_version": 0,
    }
    for name, (kind, off) in variant.fields.items():
        val = values.get(name)
        if val is None:
            continue
        if kind == "str":
            window = variant.str_window(name)
            blob = str(val).encode("ascii")[:window - 1] + b"\x00"
            out[off:off + len(blob)] = blob
        else:
            struct.pack_into(e + rc._KIND_FMT[kind], out, off, val)
    for i in range(4):
        struct.pack_into(e + "I", out, variant.offset_masks + i * 4, 0)
    sections = [(DEBUG_OFF, debug_size), (0, 0), (META_OFF, meta_size), (0, 0)]
    for i, (vaddr, size) in enumerate(sections):
        struct.pack_into(e + "I", out, variant.sections + i * 8, vaddr)
        struct.pack_into(e + "I", out, variant.sections + i * 8 + 4, size)
    poff, pcount, psize, pkind = variant.partitions
    for i in range(pcount):
        struct.pack_into(e + rc._KIND_FMT[pkind], out, poff + i * psize, meta_addr(0) if i == 0 else 0)
        struct.pack_into(e + rc._KIND_FMT[pkind], out, poff + i * psize + rc._KIND_SIZE[pkind],
                         meta_size if i == 0 else 0)

    # file offsets of the landmarks, for the test suite
    for k in list(LANDMARKS):
        LANDMARKS[k] = LANDMARKS[k] + META_OFF
    return bytes(out)


def write(path, variant: rc.HeaderVariant = rc.V_MCC_U8) -> dict:
    data = build(variant)
    Path(path).write_bytes(data)
    return dict(LANDMARKS)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "fixture.map"
    marks = write(out)
    print("wrote %s (%d bytes)" % (out, Path(out).stat().st_size))
    for k, v in sorted(marks.items()):
        print("  %-28s file offset 0x%X" % (k, v))
