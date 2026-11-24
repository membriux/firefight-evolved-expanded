#!/usr/bin/env python3
"""
decompile.py -- Halo: Reach (and Reach-MCC) HaloScript decompiler.

Takes a raw `scnr` (scenario) tag blob -- or a whole map / meta-area dump -- and
emits readable `.hsc`-style s-expressions.

WHAT THIS IS
    A clean-room Python reimplementation of the script-node walk that the
    Assembly / Blamite tag editor performs (XboxChaos/Assembly, GPLv3,
    `src/Blamite/Blam/Scripting/`).  No Assembly code is copied here, but the
    binary layouts and the expression-tree walk were learned from that project,
    and the *opcode tables* are read at runtime from Assembly's own
    `*_Scripting.xml` data files.  Those files are NOT vendored into this repo
    (GPLv3); fetch them with `--fetch-tables` or point `--table` at a local
    clone.  See research/08-haloscript-decompile.md.

    If you are on Windows, use Assembly itself. It is more complete and it is
    the reference implementation. This tool exists because Assembly is
    Windows-only (WPF / .NET Framework 4.8) and we are on macOS.

ADDRESSING
    A scenario's script tables are tag blocks whose addresses are *cache
    virtual addresses*, so a blob alone is not self-describing. You must say
    which virtual address corresponds to byte 0 of the blob you hand in:

        --base-va 0x...     VA of blob offset 0
        --scnr-va 0x...     VA of the start of the scnr tag (defaults to --base-va)

    On MCC, stored pointers are compressed: real = (stored << 2) + magic.
    Default magic is 0x50000000 (Reach MCC retail); Flight 1 used 0x10000000;
    original Xbox 360 Reach stores real addresses (use --no-expand).

    IMPORTANT: the script tables usually live in the shared meta area, *not*
    inside the scnr tag's own byte range. A scnr-only dump will very likely
    not contain them. Dump the whole tag-data / meta area (or the whole map)
    and pass --base-va for that region.

    If you have no addressing info, run with --probe: every known scnr layout
    variant is tried and the self-consistent ones are reported.

DEGRADATION
    Anything this tool cannot name is emitted as a loud marker containing the
    raw value, e.g. `<!UNKNOWN-FUNCTION opcode=0x1A8!>`. It never guesses a
    function name and never silently drops a node.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import struct
import sys
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

# --------------------------------------------------------------------------
# Known scnr header layouts (field -> offset), learned from Assembly's
# Formats/<engine>/Layouts*/*_Scenario.xml `<layout for="scnr">` blocks.
# --------------------------------------------------------------------------

SCNR_VARIANTS: Dict[str, Dict[str, int]] = {
    # Reach MCC, launch .. Update 12 (Oct 2019 .. Oct 2022)
    "reachmcc": {
        "string_table_size": 0x43C,
        "string_table_addr": 0x448,
        "script_count": 0x450,
        "script_addr": 0x454,
        "global_count": 0x45C,
        "global_addr": 0x460,
        "expr_count": 0x524,
        "expr_addr": 0x528,
    },
    # Reach MCC Update 13 (Jun 2023) and later -- scnr shrank by 0x20
    "reachmcc_u13": {
        "string_table_size": 0x41C,
        "string_table_addr": 0x428,
        "script_count": 0x430,
        "script_addr": 0x434,
        "global_count": 0x43C,
        "global_addr": 0x440,
        "expr_count": 0x504,
        "expr_addr": 0x508,
    },
    # Original Xbox 360 Halo: Reach (big endian)
    "reach360": {
        "string_table_size": 0x430,
        "string_table_addr": 0x43C,
        "script_count": 0x444,
        "script_addr": 0x448,
        "global_count": 0x450,
        "global_addr": 0x454,
        "expr_count": 0x518,
        "expr_addr": 0x51C,
    },
    "reachbeta": {
        "string_table_size": 0x418,
        "string_table_addr": 0x424,
        "script_count": 0x42C,
        "script_addr": 0x430,
        "global_count": 0x438,
        "global_addr": 0x43C,
        "expr_count": 0x4F4,
        "expr_addr": 0x4F8,
    },
    "reachalpha": {
        "string_table_size": 0x3F4,
        "string_table_addr": 0x400,
        "script_count": 0x408,
        "script_addr": 0x40C,
        "global_count": 0x414,
        "global_addr": 0x418,
        "expr_count": 0x4D0,
        "expr_addr": 0x4D4,
    },
}

# Element strides are identical across the whole Reach family.
STRIDE_SCRIPT = 0x18
STRIDE_PARAM = 0x24
STRIDE_GLOBAL = 0x28
STRIDE_EXPR = 0x18

# Expression-type enum (short at +0x6 of an expression element).
EXPR_GROUP = 8
EXPR_EXPRESSION = 9
EXPR_SCRIPT_REF = 10
EXPR_GLOBAL_REF = 13
EXPR_PARAM_REF = 29
EXPR_TYPE_NAMES = {
    EXPR_GROUP: "group",
    EXPR_EXPRESSION: "expression",
    EXPR_SCRIPT_REF: "script_reference",
    EXPR_GLOBAL_REF: "global_reference",
    EXPR_PARAM_REF: "parameter_reference",
}

NULL_DATUM = 0xFFFFFFFF

# Assembly's opcode-table data files, fetched on demand (GPLv3, not vendored).
TABLE_URLS = {
    "reachmcc_u13": "https://raw.githubusercontent.com/XboxChaos/Assembly/master/src/Blamite/Formats/ReachMCC/ReachMCC_U13_Scripting.xml",
    "reachmcc_u12": "https://raw.githubusercontent.com/XboxChaos/Assembly/master/src/Blamite/Formats/ReachMCC/ReachMCC_U12_Scripting.xml",
    "reachmcc_u11": "https://raw.githubusercontent.com/XboxChaos/Assembly/master/src/Blamite/Formats/ReachMCC/ReachMCC_U11_Scripting.xml",
    "reachmcc_u0": "https://raw.githubusercontent.com/XboxChaos/Assembly/master/src/Blamite/Formats/ReachMCC/ReachMCC_U0_Scripting.xml",
    "reach360": "https://raw.githubusercontent.com/XboxChaos/Assembly/master/src/Blamite/Formats/Reach/Reach_Scripting.xml",
}

# Calls worth flagging in --report. Names only; no semantics invented.
WATCHLIST_PATTERNS = [
    ("score read", r"^campaign_metagame_get_player_score$|^survival_mode_.*(score|lives|bonus)"),
    ("score write", r"^campaign_metagame_award_points$|^survival_increment_(human|elite)_score$|^survival_mode_lives_set$"),
    ("ai placement", r"^ai_place|^ai_erase|^ai_exit_limbo$|^ai_renew$|^ai_squad_group_get"),
    ("allegiance", r"allegiance|^ai_set_team|^ai_force_active|^unit_set_.*team"),
    ("player input", r"^player_action_test_|^unit_action_test_|^player_.*_button"),
    ("hud / notify", r"^chud_|^hud_|^objectives_|^submit_incident|^print$"),
    ("win / lose", r"^game_won$|^game_lost$|^game_end|^survival_mode_(end|begin)_|^game_safe_to_|^game_revert"),
    ("object spawn", r"^object_create|^object_destroy|^vehicle_|^device_"),
]


# --------------------------------------------------------------------------
# Opcode table
# --------------------------------------------------------------------------


@dataclass
class FuncInfo:
    opcode: int
    name: str
    return_type: str
    argc: Optional[int]
    args: List[str]
    variadic: bool


@dataclass
class TypeInfo:
    opcode: int
    name: str
    size: int
    quoted: bool
    enums: List[str]


@dataclass
class OpcodeTable:
    source: str
    funcs_by_opcode: Dict[int, FuncInfo]
    funcs_by_name: Dict[str, List[FuncInfo]]
    types_by_opcode: Dict[int, TypeInfo]
    types_by_name: Dict[str, TypeInfo]
    script_types: Dict[int, str]
    engine_globals: Dict[int, str]

    def func(self, opcode: int) -> Optional[FuncInfo]:
        return self.funcs_by_opcode.get(opcode)

    def vtype(self, opcode: int) -> Optional[TypeInfo]:
        return self.types_by_opcode.get(opcode)


def load_table(path: str) -> OpcodeTable:
    root = ET.parse(path).getroot()

    funcs_by_opcode: Dict[int, FuncInfo] = {}
    funcs_by_name: Dict[str, List[FuncInfo]] = {}
    for el in root.findall("./functions/function"):
        opcode = int(el.get("opcode"), 16)
        args = [a.get("type") for a in el.findall("arg")]
        argc_attr = el.get("argc")
        argc = int(argc_attr) if argc_attr is not None else None
        # flags="2" marks the special forms (begin/if/cond/and/or/sleep_until...)
        # whose argument count is not fixed.
        variadic = argc is None
        info = FuncInfo(opcode, el.get("name"), el.get("returnType") or "", argc, args, variadic)
        funcs_by_opcode[opcode] = info
        funcs_by_name.setdefault(info.name, []).append(info)

    types_by_opcode: Dict[int, TypeInfo] = {}
    types_by_name: Dict[str, TypeInfo] = {}
    for el in root.findall("./valueTypes/type"):
        opcode = int(el.get("opcode"), 16)
        info = TypeInfo(
            opcode,
            el.get("name"),
            int(el.get("size") or 0),
            (el.get("quoted") or "").lower() == "true",
            [e.text for e in el.findall("enum")],
        )
        types_by_opcode[opcode] = info
        types_by_name[info.name] = info

    script_types = {int(el.get("opcode"), 16): el.get("name") for el in root.findall("./scriptTypes/type")}
    engine_globals = {int(el.get("opcode"), 16): el.get("name") for el in root.findall("./globals/global")}

    return OpcodeTable(
        source=os.path.basename(path),
        funcs_by_opcode=funcs_by_opcode,
        funcs_by_name=funcs_by_name,
        types_by_opcode=types_by_opcode,
        types_by_name=types_by_name,
        script_types=script_types,
        engine_globals=engine_globals,
    )


def fetch_tables(dest: str) -> None:
    os.makedirs(dest, exist_ok=True)
    for key, url in TABLE_URLS.items():
        out = os.path.join(dest, key + ".xml")
        if os.path.exists(out):
            print(f"  have   {out}")
            continue
        print(f"  fetch  {url}")
        with urllib.request.urlopen(url, timeout=60) as r:
            data = r.read()
        with open(out, "wb") as f:
            f.write(data)
        print(f"  wrote  {out} ({len(data)} bytes)")


# --------------------------------------------------------------------------
# Binary reader
# --------------------------------------------------------------------------


class Blob:
    def __init__(self, data: bytes, big_endian: bool = False):
        self.d = data
        self.be = big_endian

    def _u(self, fmt: str, off: int, size: int):
        if off < 0 or off + size > len(self.d):
            raise IndexError(f"read of {size} at 0x{off:X} is outside the blob (0x{len(self.d):X} bytes)")
        return struct.unpack_from((">" if self.be else "<") + fmt, self.d, off)[0]

    def u16(self, off: int) -> int:
        return self._u("H", off, 2)

    def i16(self, off: int) -> int:
        return self._u("h", off, 2)

    def u32(self, off: int) -> int:
        return self._u("I", off, 4)

    def i32(self, off: int) -> int:
        return self._u("i", off, 4)

    def raw4(self, off: int) -> bytes:
        if off + 4 > len(self.d):
            raise IndexError(f"read of 4 at 0x{off:X} is outside the blob")
        return self.d[off : off + 4]

    def asciiz(self, off: int, maxlen: int) -> str:
        chunk = self.d[off : off + maxlen]
        nul = chunk.find(b"\0")
        if nul >= 0:
            chunk = chunk[:nul]
        return chunk.decode("cp1252", errors="replace")

    def cstr(self, off: int) -> str:
        nul = self.d.find(b"\0", off)
        if nul < 0:
            nul = len(self.d)
        return self.d[off:nul].decode("cp1252", errors="replace")


# --------------------------------------------------------------------------
# Decoded structures
# --------------------------------------------------------------------------


@dataclass
class Expr:
    index: int
    salt: int
    opcode: int
    value_type: int
    expr_type: int
    next_raw: int
    string_offset: int
    value_raw: bytes
    line: int
    string: Optional[str] = None

    @property
    def next_index(self) -> Optional[int]:
        if self.next_raw == NULL_DATUM:
            return None
        return self.next_raw & 0xFFFF

    @property
    def value_u32(self) -> int:
        return struct.unpack("<I", self.value_raw)[0]

    def value_datum(self, big_endian: bool) -> Optional[int]:
        v = struct.unpack(">I" if big_endian else "<I", self.value_raw)[0]
        if v == NULL_DATUM:
            return None
        return v & 0xFFFF


@dataclass
class ScriptEntry:
    index: int
    name_stringid: int
    exec_type: int
    return_type: int
    root_raw: int
    param_count: int
    param_addr: int
    name: Optional[str] = None
    params: List[Tuple[str, int]] = field(default_factory=list)

    @property
    def root_index(self) -> Optional[int]:
        if self.root_raw == NULL_DATUM:
            return None
        return self.root_raw & 0xFFFF


@dataclass
class GlobalEntry:
    index: int
    name: str
    type_opcode: int
    expr_raw: int

    @property
    def expr_index(self) -> Optional[int]:
        if self.expr_raw == NULL_DATUM:
            return None
        return self.expr_raw & 0xFFFF


@dataclass
class ScriptData:
    variant: str
    scripts: List[ScriptEntry]
    globals: List[GlobalEntry]
    exprs: Dict[int, Expr]
    string_table_offset: int
    string_table_size: int


# --------------------------------------------------------------------------
# Container parsing
# --------------------------------------------------------------------------


class Addressing:
    def __init__(self, base_va: int, expand_magic: Optional[int], expand_shift: int = 2):
        self.base_va = base_va
        self.expand_magic = expand_magic
        self.expand_shift = expand_shift

    def expand(self, stored: int) -> int:
        if self.expand_magic is None or stored == 0:
            return stored
        return (stored << self.expand_shift) + self.expand_magic

    def to_offset(self, stored: int) -> int:
        return self.expand(stored) - self.base_va


def read_header(blob: Blob, scnr_off: int, variant: str) -> Dict[str, int]:
    f = SCNR_VARIANTS[variant]
    return {
        "string_table_size": blob.i32(scnr_off + f["string_table_size"]),
        "string_table_addr": blob.u32(scnr_off + f["string_table_addr"]),
        "script_count": blob.i32(scnr_off + f["script_count"]),
        "script_addr": blob.u32(scnr_off + f["script_addr"]),
        "global_count": blob.i32(scnr_off + f["global_count"]),
        "global_addr": blob.u32(scnr_off + f["global_addr"]),
        "expr_count": blob.i32(scnr_off + f["expr_count"]),
        "expr_addr": blob.u32(scnr_off + f["expr_addr"]),
    }


def header_plausible(blob: Blob, hdr: Dict[str, int], addr: Addressing) -> Tuple[bool, str]:
    """Cheap self-consistency test used by --probe and by variant auto-detect."""
    n = len(blob.d)
    checks = [
        ("expr_count", 0 <= hdr["expr_count"] <= 2_000_000),
        ("script_count", 0 <= hdr["script_count"] <= 20_000),
        ("global_count", 0 <= hdr["global_count"] <= 20_000),
        ("string_table_size", 0 <= hdr["string_table_size"] <= 64 * 1024 * 1024),
    ]
    for name, ok in checks:
        if not ok:
            return False, f"{name} out of range ({hdr[name]})"

    if hdr["expr_count"] == 0 and hdr["script_count"] == 0 and hdr["global_count"] == 0:
        return False, "no scripts, globals or expressions"

    for name, count, stride in (
        ("expr", hdr["expr_count"], STRIDE_EXPR),
        ("script", hdr["script_count"], STRIDE_SCRIPT),
        ("global", hdr["global_count"], STRIDE_GLOBAL),
    ):
        if count == 0:
            continue
        off = addr.to_offset(hdr[name + "_addr"])
        if off < 0 or off + count * stride > n:
            return False, f"{name} table at 0x{off:X}+0x{count * stride:X} outside blob (0x{n:X})"

    # Spot-check expression records: expression types must be from the known set.
    # Real caches keep the whole 64512-node datum array in the tag, so a fifth of
    # it is unallocated and filled with the engine's 0xBA free-datum pattern.
    # Those records are not expressions and must not count against the sample.
    if hdr["expr_count"]:
        base = addr.to_offset(hdr["expr_addr"])
        good = 0
        sampled = 0
        free = 0
        step = max(1, hdr["expr_count"] // 64)
        for i in range(0, hdr["expr_count"], step):
            o = base + i * STRIDE_EXPR
            if blob.d[o + 2:o + STRIDE_EXPR] == b"\xba" * (STRIDE_EXPR - 2):
                free += 1
                continue
            et = blob.i16(o + 0x6) & 0xFF
            sampled += 1
            if et in EXPR_TYPE_NAMES:
                good += 1
        if sampled and good / sampled < 0.9:
            return False, (f"only {good}/{sampled} sampled expression types are known "
                           f"({free} free datums skipped)")
        if not sampled:
            return False, "every sampled expression datum is the 0xBA free pattern"

    return True, "ok"


def parse(blob: Blob, scnr_off: int, variant: str, addr: Addressing, stringids: Dict[int, str]) -> ScriptData:
    hdr = read_header(blob, scnr_off, variant)

    exprs: Dict[int, Expr] = {}
    if hdr["expr_count"]:
        base = addr.to_offset(hdr["expr_addr"])
        for i in range(hdr["expr_count"]):
            o = base + i * STRIDE_EXPR
            exprs[i] = Expr(
                index=i,
                salt=blob.u16(o + 0x0),
                opcode=blob.u16(o + 0x2),
                value_type=blob.u16(o + 0x4),
                expr_type=blob.i16(o + 0x6),
                next_raw=blob.u32(o + 0x8),
                string_offset=blob.u32(o + 0xC),
                value_raw=blob.raw4(o + 0x10),
                line=blob.i16(o + 0x14),
            )

    str_off = addr.to_offset(hdr["string_table_addr"]) if hdr["string_table_size"] else 0
    if hdr["string_table_size"]:
        for e in exprs.values():
            if e.string_offset < hdr["string_table_size"]:
                e.string = blob.cstr(str_off + e.string_offset)

    scripts: List[ScriptEntry] = []
    if hdr["script_count"]:
        base = addr.to_offset(hdr["script_addr"])
        for i in range(hdr["script_count"]):
            o = base + i * STRIDE_SCRIPT
            sid = blob.u32(o + 0x0)
            s = ScriptEntry(
                index=i,
                name_stringid=sid,
                exec_type=blob.i16(o + 0x4),
                return_type=blob.i16(o + 0x6),
                root_raw=blob.u32(o + 0x8),
                param_count=blob.i32(o + 0xC),
                param_addr=blob.u32(o + 0x10),
            )
            s.name = stringids.get(sid)
            if s.param_count:
                try:
                    po = addr.to_offset(s.param_addr)
                    for p in range(s.param_count):
                        po_p = po + p * STRIDE_PARAM
                        s.params.append((blob.asciiz(po_p, 0x20), blob.i16(po_p + 0x20)))
                except IndexError:
                    s.params = []
            scripts.append(s)

    globs: List[GlobalEntry] = []
    if hdr["global_count"]:
        base = addr.to_offset(hdr["global_addr"])
        for i in range(hdr["global_count"]):
            o = base + i * STRIDE_GLOBAL
            globs.append(
                GlobalEntry(
                    index=i,
                    name=blob.asciiz(o + 0x0, 0x20),
                    type_opcode=blob.i16(o + 0x20),
                    expr_raw=blob.u32(o + 0x24),
                )
            )

    return ScriptData(variant, scripts, globs, exprs, str_off, hdr["string_table_size"])


# --------------------------------------------------------------------------
# Emitter
# --------------------------------------------------------------------------


class Emitter:
    MULTILINE = ("if", "cond", "and", "or", "branch")

    def __init__(self, data: ScriptData, table: OpcodeTable, big_endian: bool, annotate: bool = False):
        self.data = data
        self.t = table
        self.be = big_endian
        self.annotate = annotate
        self.unknown_opcodes: Dict[int, int] = {}
        self.unknown_types: Dict[int, int] = {}
        self.unknown_expr_types: Dict[int, int] = {}
        self.calls: List[Tuple[str, str, int]] = []  # (function, owning script, expr index)
        self._script = "<globals>"
        fn = self.t.funcs_by_name.get("if")
        self.if_opcode = fn[0].opcode if fn else None
        ft = self.t.types_by_name.get("function_name")
        self.function_name_type = ft.opcode if ft else 0x02

    # --- chain helpers ---

    def chain(self, start: Optional[int], _guard: Optional[set] = None) -> List[Expr]:
        out: List[Expr] = []
        seen = set()
        i = start
        while i is not None:
            if i in seen or i not in self.data.exprs:
                break
            seen.add(i)
            e = self.data.exprs[i]
            out.append(e)
            i = e.next_index
        return out

    def children(self, e: Expr) -> List[Expr]:
        """Children of a group / reference node: the chain its value points at.
        Element 0 is the function_name node and carries the callee's name."""
        return self.chain(e.value_datum(self.be))

    # --- top level ---

    def emit_all(self) -> str:
        out: List[str] = []
        out.append("; Decompiled by tools/hsc/decompile.py")
        out.append(f"; scnr layout variant: {self.data.variant}")
        out.append(f"; opcode table: {self.t.source}")
        out.append(f"; {len(self.data.globals)} globals, {len(self.data.scripts)} scripts, "
                   f"{len(self.data.exprs)} expressions")
        out.append("; Markers of the form <!...!> are things this tool could not resolve.")
        out.append("")

        if self.data.globals:
            out.append("; ---------------- GLOBALS ----------------")
            for g in self.data.globals:
                self._script = f"<global {g.name}>"
                tname = self.type_name(g.type_opcode)
                if g.expr_index is None:
                    val = "<!NO-VALUE-EXPRESSION!>"
                else:
                    val = " ".join(self.emit_chain(self.chain(g.expr_index), 0)).strip()
                out.append(f"(global {tname} {g.name} {val})")
            out.append("")

        if self.data.scripts:
            out.append("; ---------------- SCRIPTS ----------------")
            for s in self.data.scripts:
                name = s.name if s.name else f"<!SID:0x{s.name_stringid:08X}!>"
                self._script = name
                etype = self.t.script_types.get(s.exec_type) or f"<!UNKNOWN-SCRIPT-TYPE {s.exec_type}!>"
                rtype = self.type_name(s.return_type)
                head = f"(script {etype} {rtype} {name}"
                if s.params:
                    plist = ", ".join(f"{self.type_name(pt)} {pn}" for pn, pt in s.params)
                    head += f" ({plist})"
                out.append(head)
                if s.root_index is None:
                    out.append("  <!NO-ROOT-EXPRESSION!>")
                else:
                    out.extend(self.emit_chain(self.chain(s.root_index), 1))
                out.append(")")
                out.append("")

        return "\n".join(out)

    # --- node dispatch ---

    def emit_chain(self, nodes: List[Expr], depth: int) -> List[str]:
        lines: List[str] = []
        for e in nodes:
            # A function_name node renders as nothing; it names its parent.
            if (e.expr_type & 0xFF) == EXPR_EXPRESSION and e.value_type == self.function_name_type:
                continue
            lines.extend(self.emit_node(e, depth))
        return lines

    def emit_node(self, e: Expr, depth: int) -> List[str]:
        pad = "  " * depth
        et = e.expr_type & 0xFF

        if et == EXPR_GROUP:
            return self.emit_group(e, depth)
        if et == EXPR_EXPRESSION:
            return [pad + self.emit_literal(e)]
        if et == EXPR_SCRIPT_REF:
            return self.emit_script_ref(e, depth)
        if et == EXPR_GLOBAL_REF:
            return [pad + self.emit_global_ref(e)]
        if et == EXPR_PARAM_REF:
            return [pad + (e.string if e.string else f"<!UNNAMED-PARAM idx={e.index}!>")]

        self.unknown_expr_types[et] = self.unknown_expr_types.get(et, 0) + 1
        return [pad + (f"<!UNKNOWN-EXPR-TYPE 0x{et:X} idx={e.index} opcode=0x{e.opcode:X} "
                       f"value=0x{e.value_u32:08X}!>")]

    # --- groups ---

    def emit_group(self, e: Expr, depth: int) -> List[str]:
        pad = "  " * depth
        info = self.t.func(e.opcode)
        kids = self.children(e)

        # line == 0 marks compiler-generated structure.
        if e.line == 0:
            if self.if_opcode is not None and e.opcode == self.if_opcode:
                return self.emit_cond(e, depth)
            # A compiler-inserted `begin`: splice its body in without parens.
            return self.emit_chain(kids, depth)

        if info is None:
            self.unknown_opcodes[e.opcode] = self.unknown_opcodes.get(e.opcode, 0) + 1
            name = f"<!UNKNOWN-FUNCTION opcode=0x{e.opcode:03X}!>"
        else:
            name = info.name
            self.calls.append((name, self._script, e.index))

        args = [k for k in kids if not ((k.expr_type & 0xFF) == EXPR_EXPRESSION
                                        and k.value_type == self.function_name_type)]
        return self.wrap(name, args, depth, pad, e)

    def emit_script_ref(self, e: Expr, depth: int) -> List[str]:
        pad = "  " * depth
        kids = self.children(e)
        if kids and kids[0].string:
            name = kids[0].string
        else:
            # Fall back to the script table if the name string is missing.
            idx = e.value_datum(self.be)
            tgt = self.data.scripts[idx] if idx is not None and idx < len(self.data.scripts) else None
            name = (tgt.name if tgt and tgt.name
                    else f"<!UNRESOLVED-SCRIPT-REF value=0x{e.value_u32:08X}!>")
        self.calls.append((name, self._script, e.index))
        args = [k for k in kids if not ((k.expr_type & 0xFF) == EXPR_EXPRESSION
                                        and k.value_type == self.function_name_type)]
        return self.wrap(name, args, depth, pad, e)

    def wrap(self, name: str, args: List[Expr], depth: int, pad: str, e: Expr) -> List[str]:
        tag = f"\t; expr {e.index}" if self.annotate else ""
        if not args:
            return [f"{pad}({name}){tag}"]

        multiline = name.startswith("begin") or name in self.MULTILINE
        if not multiline:
            # Try to keep simple calls on one line.
            rendered = [self.emit_node(a, 0) for a in args]
            if all(len(r) == 1 for r in rendered):
                flat = " ".join(r[0].strip() for r in rendered)
                if len(pad) + len(name) + len(flat) < 110:
                    return [f"{pad}({name} {flat}){tag}"]

        lines = [f"{pad}({name}{tag}"]
        for a in args:
            lines.extend(self.emit_node(a, depth + 1))
        lines.append(f"{pad})")
        return lines

    def emit_cond(self, e: Expr, depth: int) -> List[str]:
        """A `cond` is compiled to a chain of line-0 `if` groups. Rebuild it."""
        pad = "  " * depth
        clauses: List[Tuple[Expr, List[Expr]]] = []
        node: Optional[Expr] = e
        malformed = False

        while node is not None:
            kids = [k for k in self.children(node)
                    if not ((k.expr_type & 0xFF) == EXPR_EXPRESSION
                            and k.value_type == self.function_name_type)]
            if len(kids) < 2:
                malformed = True
                break
            test, body = kids[0], kids[1]
            rest = kids[2:]
            clauses.append((test, [body]))
            nxt = None
            for r in rest:
                if (r.expr_type & 0xFF) == EXPR_GROUP and r.line == 0 and r.opcode == e.opcode:
                    nxt = r
                elif (r.expr_type & 0xFF) == EXPR_EXPRESSION and r.line == 0:
                    pass  # compiler-added terminator
                else:
                    clauses[-1][1].append(r)
            node = nxt

        if malformed or not clauses:
            info = self.t.func(e.opcode)
            nm = info.name if info else f"<!UNKNOWN-FUNCTION opcode=0x{e.opcode:03X}!>"
            lines = [f"{pad}; <!COND-SHAPE-UNEXPECTED at expr {e.index} - emitted as a raw {nm} group!>"]
            kids = [k for k in self.children(e)
                    if not ((k.expr_type & 0xFF) == EXPR_EXPRESSION
                            and k.value_type == self.function_name_type)]
            lines.extend(self.wrap(nm, kids, depth, pad, e))
            return lines

        self.calls.append(("cond", self._script, e.index))
        lines = [f"{pad}(cond"]
        for test, body in clauses:
            t_lines = self.emit_node(test, 0)
            if len(t_lines) == 1:
                lines.append(f"{pad}  ({t_lines[0].strip()}")
            else:
                lines.append(f"{pad}  (")
                lines.extend(self.emit_node(test, depth + 2))
            for b in body:
                lines.extend(self.emit_node(b, depth + 2))
            lines.append(f"{pad}  )")
        lines.append(f"{pad})")
        return lines

    # --- leaves ---

    def emit_global_ref(self, e: Expr) -> str:
        if e.string:
            return e.string
        eng = self.t.engine_globals.get(e.opcode)
        if eng:
            return eng
        return f"<!UNRESOLVED-GLOBAL opcode=0x{e.opcode:X} value=0x{e.value_u32:08X}!>"

    def type_name(self, opcode: int) -> str:
        ti = self.t.vtype(opcode)
        if ti:
            return ti.name
        self.unknown_types[opcode] = self.unknown_types.get(opcode, 0) + 1
        return f"<!UNKNOWN-TYPE 0x{opcode:X}!>"

    def scaled_value(self, e: Expr, size: int) -> int:
        raw = struct.unpack(">I" if self.be else "<I", e.value_raw)[0]
        if size == 0:
            return 0
        if self.be:
            return raw >> (32 - size * 8)
        if size == 4:
            return raw
        return raw & ((1 << (size * 8)) - 1)

    def emit_literal(self, e: Expr) -> str:
        # A literal's `opcode` field holds the *actual* value type when the
        # compiler inserted a cast; 0xFFFF means "no cast".
        declared = self.t.vtype(e.value_type)
        actual = declared
        if e.opcode != 0xFFFF:
            cast = self.t.vtype(e.opcode)
            if cast is not None:
                actual = cast

        if actual is None:
            self.unknown_types[e.opcode if e.opcode != 0xFFFF else e.value_type] = 1
            return (f"<!UNKNOWN-TYPE value_type=0x{e.value_type:X} opcode=0x{e.opcode:X} "
                    f"raw=0x{e.value_u32:08X}!>")

        raw32 = struct.unpack(">I" if self.be else "<I", e.value_raw)[0]
        is_null = raw32 == 0xFFFFFFFF

        if actual.quoted:
            if is_null or e.string == "none":
                return "none"
            if e.string is None:
                return f"<!MISSING-STRING offset=0x{e.string_offset:X} type={actual.name}!>"
            return '"' + e.string.replace("\\", "\\\\").replace('"', '\\"') + '"'

        v = self.scaled_value(e, actual.size)
        n = actual.name

        if n == "void":
            return ""
        if n == "boolean":
            return "true" if (v & 0xFF) else "false"
        if n == "short":
            return str(struct.unpack("<h", struct.pack("<H", v & 0xFFFF))[0])
        if n == "long":
            return str(struct.unpack("<i", struct.pack("<I", v & 0xFFFFFFFF))[0])
        if n == "real":
            return f"{struct.unpack('<f', struct.pack('<I', v & 0xFFFFFFFF))[0]:.7g}"
        if n in ("script", "ai_command_script"):
            idx = struct.unpack("<h", struct.pack("<H", v & 0xFFFF))[0]
            if idx == -1:
                return e.string if e.string else "none"
            if 0 <= idx < len(self.data.scripts):
                tgt = self.data.scripts[idx]
                return tgt.name if tgt.name else f"<!SID:0x{tgt.name_stringid:08X}!>"
            return f"<!SCRIPT-INDEX-OOR {idx}!>"
        if n == "string_id":
            if e.string:
                return '"' + e.string + '"'
            return f"<!SID:0x{v:08X}!>"
        if actual.enums:
            if is_null:
                return "none"
            if 0 <= v < len(actual.enums):
                return actual.enums[v]
            return f"<!ENUM-OUT-OF-RANGE type={n} index={v}!>"
        if is_null:
            return "none"
        if e.string:
            return e.string
        return f"<!UNRENDERED type={n} raw=0x{raw32:08X}!>"


# --------------------------------------------------------------------------
# Table auto-detect by call arity
# --------------------------------------------------------------------------


def score_table(data: ScriptData, table: OpcodeTable, big_endian: bool) -> Tuple[float, int, int]:
    """Fraction of group calls whose argument count matches the table.

    Reach gives each overload its own opcode (ai_place/1 and ai_place/2 are
    different opcodes), so argument count is a strong fingerprint for picking
    the right MCC build's opcode table. Opcodes DO shift between builds.
    """
    em = Emitter(data, table, big_endian)
    checked = 0
    matched = 0
    missing = 0
    for e in data.exprs.values():
        if (e.expr_type & 0xFF) != EXPR_GROUP or e.line == 0:
            continue
        info = table.func(e.opcode)
        if info is None:
            missing += 1
            continue
        if info.variadic:
            continue
        kids = em.children(e)
        argc = sum(1 for k in kids
                   if not ((k.expr_type & 0xFF) == EXPR_EXPRESSION
                           and k.value_type == em.function_name_type))
        checked += 1
        if argc == info.argc:
            matched += 1
    return (matched / checked if checked else 0.0), checked, missing


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def load_stringids(path: Optional[str]) -> Dict[int, str]:
    if not path:
        return {}
    with open(path) as f:
        raw = json.load(f)
    if isinstance(raw, dict):
        out = {}
        for k, v in raw.items():
            out[int(k, 16) if isinstance(k, str) and k.lower().startswith("0x") else int(k)] = v
        return out
    if isinstance(raw, list):
        return {i: s for i, s in enumerate(raw) if isinstance(s, str)}
    raise SystemExit("--stringids must be a JSON object {id: name} or an array indexed by stringID")


def selftest() -> int:
    """Build a synthetic expression table and check the emitter.

    This validates the TREE WALK AND PRINTER ONLY. It cannot validate the
    binary layout -- that needs a real map.
    """
    import tempfile

    xml = """<?xml version="1.0"?><BlamScript game="test">
      <scriptTypes><type opcode="0x0" name="startup"/><type opcode="0x3" name="static"/></scriptTypes>
      <valueTypes>
        <type opcode="0x02" name="function_name" size="0"/>
        <type opcode="0x04" name="void" size="0"/>
        <type opcode="0x05" name="boolean" size="1"/>
        <type opcode="0x08" name="long" size="4"/>
        <type opcode="0x13" name="ai" size="4" quoted="true"/>
      </valueTypes>
      <functions>
        <function opcode="0x000" name="begin" returnType="passthrough" flags="2"/>
        <function opcode="0x004" name="if" returnType="passthrough" flags="2"/>
        <function opcode="0x100" name="ai_place" returnType="void" argc="1"><arg type="ai"/></function>
        <function opcode="0x101" name="award" returnType="void" argc="1"><arg type="long"/></function>
      </functions>
      <globals><global opcode="0x000" name="engine_glob" type="boolean"/></globals>
    </BlamScript>"""
    with tempfile.NamedTemporaryFile("w", suffix=".xml", delete=False) as f:
        f.write(xml)
        xml_path = f.name
    table = load_table(xml_path)

    exprs: Dict[int, Expr] = {}

    def mk(i, opcode, vtype, etype, nxt, value, line=1, string=None, stroff=0xFFFFFFFF):
        exprs[i] = Expr(i, 0, opcode, vtype, etype, nxt, stroff,
                        struct.pack("<I", value & 0xFFFFFFFF), line, string)

    # (begin (ai_place "sq_test") (award -1500) (<unknown 0x999>) g_flag)
    mk(0, 0x000, 0x03, EXPR_GROUP, NULL_DATUM, 1)                       # begin
    mk(1, 0xFFFF, 0x02, EXPR_EXPRESSION, 2, 0, string="begin")          # function_name
    mk(2, 0x100, 0x04, EXPR_GROUP, 5, 3)                                # ai_place
    mk(3, 0xFFFF, 0x02, EXPR_EXPRESSION, 4, 0, string="ai_place")
    mk(4, 0x13, 0x13, EXPR_EXPRESSION, NULL_DATUM, 0, string="sq_test", stroff=0)
    mk(5, 0x101, 0x04, EXPR_GROUP, 8, 6)                                # award
    mk(6, 0xFFFF, 0x02, EXPR_EXPRESSION, 7, 0, string="award")
    mk(7, 0x08, 0x08, EXPR_EXPRESSION, NULL_DATUM, 0xFFFFFA24)          # -1500
    mk(8, 0x999, 0x04, EXPR_GROUP, 10, 9)                               # unknown opcode
    mk(9, 0xFFFF, 0x02, EXPR_EXPRESSION, NULL_DATUM, 0, string="???")
    mk(10, 0x000, 0x05, EXPR_GLOBAL_REF, NULL_DATUM, 0, string="g_flag")

    data = ScriptData("synthetic", [ScriptEntry(0, 0x1234, 3, 0x04, 0, 0, 0, name="test_script")],
                      [GlobalEntry(0, "g_flag", 0x05, NULL_DATUM)], exprs, 0, 0)
    text = Emitter(data, table, big_endian=False).emit_all()
    print(text)

    failures = []
    for want in ['(script static void test_script', '(ai_place "sq_test")', '(award -1500)',
                 '<!UNKNOWN-FUNCTION opcode=0x999!>', 'g_flag', '<!NO-VALUE-EXPRESSION!>']:
        if want not in text:
            failures.append(want)
    os.unlink(xml_path)

    failures += selftest_binary()

    if failures:
        print("\nSELFTEST FAILED:", failures, file=sys.stderr)
        return 1
    print("\nSELFTEST OK -- tree walk, printer, and struct packing round-trip.")
    print("This does NOT validate the layout against a real map; only a real scnr can do that.")
    return 0


def selftest_binary() -> List[str]:
    """Pack a synthetic scnr header + tables with the reachmcc_u13 offsets and
    read them back. Exercises the struct offsets, strides and addressing math."""
    failures: List[str] = []
    f = SCNR_VARIANTS["reachmcc_u13"]
    base_va = 0x50000000
    magic = 0x50000000

    def compress(real: int) -> int:
        return (real - magic) >> 2

    buf = bytearray(0x2000)

    expr_off, script_off, global_off, str_off = 0x1000, 0x1200, 0x1300, 0x1400
    exprs_in = [
        # salt, opcode, vtype, etype, next, stroff, value, line
        (0, 0x000, 0x03, EXPR_GROUP, NULL_DATUM, 0xFFFFFFFF, 1, 1),
        (0, 0xFFFF, 0x02, EXPR_EXPRESSION, NULL_DATUM, 0, 0, 0),
    ]
    for i, (salt, op, vt, et, nxt, so, val, line) in enumerate(exprs_in):
        o = expr_off + i * STRIDE_EXPR
        struct.pack_into("<HHhhIIIh", buf, o, salt, op, vt, et, nxt, so, val, line)

    struct.pack_into("<IhhIIII", buf, script_off, 0xDEADBEEF, 3, 0x04, 0, 0, 0, 0)
    buf[global_off : global_off + 7] = b"g_test\0"
    struct.pack_into("<hHI", buf, global_off + 0x20, 0x05, 0, NULL_DATUM)
    buf[str_off : str_off + 7] = b"begin\0\0"

    struct.pack_into("<i", buf, f["string_table_size"], 7)
    struct.pack_into("<I", buf, f["string_table_addr"], compress(base_va + str_off))
    struct.pack_into("<i", buf, f["script_count"], 1)
    struct.pack_into("<I", buf, f["script_addr"], compress(base_va + script_off))
    struct.pack_into("<i", buf, f["global_count"], 1)
    struct.pack_into("<I", buf, f["global_addr"], compress(base_va + global_off))
    struct.pack_into("<i", buf, f["expr_count"], len(exprs_in))
    struct.pack_into("<I", buf, f["expr_addr"], compress(base_va + expr_off))

    blob = Blob(bytes(buf))
    addr = Addressing(base_va, magic)
    hdr = read_header(blob, 0, "reachmcc_u13")
    ok, why = header_plausible(blob, hdr, addr)
    if not ok:
        failures.append(f"synthetic u13 header rejected: {why}")

    data = parse(blob, 0, "reachmcc_u13", addr, {})
    if len(data.exprs) != 2:
        failures.append(f"expected 2 expressions, got {len(data.exprs)}")
    if not data.globals or data.globals[0].name != "g_test":
        failures.append("global name did not round-trip")
    if not data.scripts or data.scripts[0].name_stringid != 0xDEADBEEF:
        failures.append("script stringID did not round-trip")
    if data.scripts and data.scripts[0].exec_type != 3:
        failures.append("script exec type did not round-trip")
    if data.exprs.get(1) and data.exprs[1].string != "begin":
        failures.append(f"string table lookup failed: {data.exprs[1].string!r}")
    return failures


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("blob", nargs="?", help="scnr tag blob, meta-area dump, or whole .map")
    ap.add_argument("--table", action="append", default=[],
                    help="Assembly *_Scripting.xml opcode table (repeat to let --auto-table choose)")
    ap.add_argument("--fetch-tables", metavar="DIR", nargs="?", const="tools/hsc/tables",
                    help="download Assembly's Reach scripting XMLs into DIR and exit")
    ap.add_argument("--variant", default="auto", choices=["auto"] + sorted(SCNR_VARIANTS),
                    help="scnr header layout (default: auto-detect)")
    ap.add_argument("--base-va", type=lambda s: int(s, 0), default=None,
                    help="cache virtual address corresponding to blob offset 0")
    ap.add_argument("--scnr-va", type=lambda s: int(s, 0), default=None,
                    help="virtual address of the scnr tag (default: --base-va)")
    ap.add_argument("--scnr-offset", type=lambda s: int(s, 0), default=None,
                    help="byte offset of the scnr tag inside the blob (alternative to --scnr-va)")
    ap.add_argument("--expand-magic", type=lambda s: int(s, 0), default=0x50000000,
                    help="MCC pointer expand magic; real = (stored << 2) + magic (default 0x50000000)")
    ap.add_argument("--no-expand", action="store_true", help="pointers are already real (Xbox 360 Reach)")
    ap.add_argument("--big-endian", action="store_true", help="Xbox 360 map")
    ap.add_argument("--stringids", help="JSON stringID table from the map parser, for script names")
    ap.add_argument("--out", help="write .hsc here instead of stdout")
    ap.add_argument("--json", help="also dump raw decoded tables here")
    ap.add_argument("--report", action="store_true", help="print a call-site report for the watchlist")
    ap.add_argument("--probe", action="store_true", help="only report which layout variants look valid")
    ap.add_argument("--auto-table", action="store_true", help="rank the supplied tables by call arity agreement")
    ap.add_argument("--annotate", action="store_true", help="append expression indices as comments")
    ap.add_argument("--selftest", action="store_true", help="run the built-in emitter self-test")
    args = ap.parse_args(argv)

    if args.fetch_tables:
        fetch_tables(args.fetch_tables)
        return 0
    if args.selftest:
        return selftest()
    if not args.blob:
        ap.error("a blob is required (or use --selftest / --fetch-tables)")

    with open(args.blob, "rb") as f:
        raw = f.read()
    blob = Blob(raw, big_endian=args.big_endian)

    scnr_off = args.scnr_offset if args.scnr_offset is not None else 0
    if args.scnr_offset is None and args.scnr_va is not None:
        if args.base_va is None:
            ap.error("--scnr-va needs --base-va")
        scnr_off = args.scnr_va - args.base_va

    base_va = args.base_va
    if base_va is None:
        base_va = 0
        print("warning: no --base-va given; assuming blob offset 0 == VA 0. "
              "Table addresses will almost certainly not resolve.", file=sys.stderr)

    addr = Addressing(base_va, None if args.no_expand else args.expand_magic)

    # --- pick the header layout ---
    candidates = sorted(SCNR_VARIANTS) if args.variant == "auto" else [args.variant]
    results = []
    for v in candidates:
        try:
            hdr = read_header(blob, scnr_off, v)
        except IndexError as exc:
            results.append((v, False, str(exc), None))
            continue
        ok, why = header_plausible(blob, hdr, addr)
        results.append((v, ok, why, hdr))

    if args.probe:
        print(f"blob: {args.blob} ({len(raw)} bytes)  scnr_off=0x{scnr_off:X}  base_va=0x{base_va:X}  "
              f"expand={'off' if args.no_expand else hex(args.expand_magic)}")
        for v, ok, why, hdr in results:
            print(f"  {v:<14} {'PLAUSIBLE' if ok else 'no':<10} {why}")
            if hdr:
                print(f"      scripts={hdr['script_count']} globals={hdr['global_count']} "
                      f"exprs={hdr['expr_count']} strtab_size={hdr['string_table_size']} "
                      f"expr_addr=0x{hdr['expr_addr']:08X}")
        return 0

    good = [r for r in results if r[1]]
    if not good:
        print("error: no scnr layout variant produced a self-consistent header.", file=sys.stderr)
        for v, ok, why, _ in results:
            print(f"  {v}: {why}", file=sys.stderr)
        print("Re-run with --probe, and check --base-va / --scnr-offset / --expand-magic.", file=sys.stderr)
        return 2
    if len(good) > 1 and args.variant == "auto":
        print(f"note: {len(good)} layout variants look plausible ({', '.join(g[0] for g in good)}); "
              f"using {good[0][0]}. Pass --variant to override.", file=sys.stderr)
    variant = good[0][0]

    stringids = load_stringids(args.stringids)
    data = parse(blob, scnr_off, variant, addr, stringids)

    if not args.table:
        print("error: at least one --table is required. Run --fetch-tables first.", file=sys.stderr)
        return 2
    tables = [load_table(p) for p in args.table]

    if args.auto_table or len(tables) > 1:
        ranked = []
        for t in tables:
            frac, checked, missing = score_table(data, t, args.big_endian)
            ranked.append((frac, -missing, t, checked, missing))
        ranked.sort(key=lambda r: (r[0], r[1]), reverse=True)
        print("opcode table ranking (by fixed-arity call agreement):", file=sys.stderr)
        for frac, _, t, checked, missing in ranked:
            print(f"  {t.source:<34} {frac * 100:6.2f}% of {checked} calls, "
                  f"{missing} opcodes not in table", file=sys.stderr)
        table = ranked[0][2]
        if ranked[0][0] < 0.95:
            print("WARNING: best table agrees on <95% of calls. Function names may be WRONG. "
                  "Opcodes shift between MCC builds -- find the map's build string.", file=sys.stderr)
    else:
        table = tables[0]

    em = Emitter(data, table, args.big_endian, annotate=args.annotate)
    text = em.emit_all()

    if args.out:
        with open(args.out, "w") as f:
            f.write(text)
        print(f"wrote {args.out} ({len(text)} bytes)", file=sys.stderr)
    else:
        print(text)

    if em.unknown_opcodes:
        print(f"\n; {len(em.unknown_opcodes)} unknown opcodes: "
              + ", ".join(f"0x{k:03X}x{v}" for k, v in sorted(em.unknown_opcodes.items())),
              file=sys.stderr)
    if em.unknown_expr_types:
        print(f"; unknown expression types: {em.unknown_expr_types}", file=sys.stderr)

    if args.report:
        print("\n==================== CALL-SITE REPORT ====================")
        by_name: Dict[str, List[Tuple[str, int]]] = {}
        for fn, owner, idx in em.calls:
            by_name.setdefault(fn, []).append((owner, idx))
        for label, pattern in WATCHLIST_PATTERNS:
            rx = re.compile(pattern)
            hits = {k: v for k, v in by_name.items() if rx.search(k)}
            print(f"\n-- {label} --")
            if not hits:
                print("   (none)")
            for fn in sorted(hits):
                owners = sorted({o for o, _ in hits[fn]})
                print(f"   {fn}  x{len(hits[fn])}  in: {', '.join(owners[:8])}"
                      + (" ..." if len(owners) > 8 else ""))
        print(f"\ntotal distinct functions called: {len(by_name)}")

    if args.json:
        with open(args.json, "w") as f:
            json.dump(
                {
                    "variant": variant,
                    "table": table.source,
                    "globals": [
                        {"index": g.index, "name": g.name,
                         "type": table.vtype(g.type_opcode).name if table.vtype(g.type_opcode) else g.type_opcode,
                         "expr": g.expr_index}
                        for g in data.globals
                    ],
                    "scripts": [
                        {"index": s.index, "name": s.name, "stringid": s.name_stringid,
                         "exec_type": table.script_types.get(s.exec_type, s.exec_type),
                         "return_type": table.vtype(s.return_type).name if table.vtype(s.return_type) else s.return_type,
                         "root": s.root_index,
                         "params": [{"name": p, "type": t} for p, t in s.params]}
                        for s in data.scripts
                    ],
                    "expression_count": len(data.exprs),
                    "unknown_opcodes": {f"0x{k:03X}": v for k, v in em.unknown_opcodes.items()},
                    "calls": [{"function": f, "script": o, "expr": i} for f, o, i in em.calls],
                },
                f,
                indent=2,
            )
        print(f"wrote {args.json}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
