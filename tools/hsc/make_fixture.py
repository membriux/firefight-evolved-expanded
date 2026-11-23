#!/usr/bin/env python3
"""
make_fixture.py -- build a synthetic Reach-MCC `scnr` blob for testing
decompile.py before the real map arrives.

It assembles a small expression tree by hand, using REAL opcodes read out of an
Assembly `*_Scripting.xml` table, and writes a blob with a real `reachmcc_u13`
scnr header. Running decompile.py on the result should reproduce the source
s-expressions below.

    python3 tools/hsc/make_fixture.py --table tools/hsc/tables/reachmcc_u13.xml \
        --out /tmp/fixture.scnr --stringids /tmp/fixture_sids.json

This is a round-trip test of OUR reader against OUR writer. It proves the tree
walk, the opcode lookup and the addressing math. It cannot prove the layout is
right for a real map -- only a real map can.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

from decompile import (  # noqa: E402
    EXPR_EXPRESSION,
    EXPR_GLOBAL_REF,
    EXPR_GROUP,
    NULL_DATUM,
    SCNR_VARIANTS,
    STRIDE_EXPR,
    STRIDE_GLOBAL,
    STRIDE_SCRIPT,
    load_table,
)

# What the fixture encodes:
#
#   (global long g_fe_spent 0)
#
#   (script static void fe_buy_marines
#     (begin
#       (if (>= (campaign_metagame_get_player_score (player0)) 1500)
#         (begin
#           (campaign_metagame_award_points (player0) -1500)
#           (ai_place sq_fe_marines)
#           (chud_post_message (player0) "fe_bought_marines")))))


class Builder:
    def __init__(self, table):
        self.t = table
        self.exprs = []  # (opcode, value_type, expr_type, string, value_u32, line)
        self.strings = bytearray()
        self.str_off = {}

    def intern(self, s: str) -> int:
        if s in self.str_off:
            return self.str_off[s]
        off = len(self.strings)
        self.strings += s.encode("cp1252") + b"\0"
        self.str_off[s] = off
        return off

    def add(self, opcode, value_type, expr_type, value=0, string=None, line=1) -> int:
        self.exprs.append([opcode, value_type, expr_type, string, value, line, NULL_DATUM])
        return len(self.exprs) - 1

    def link(self, ids):
        for a, b in zip(ids, ids[1:]):
            self.exprs[a][6] = b
        return ids[0] if ids else None

    def vt(self, name) -> int:
        ti = self.t.types_by_name[name]
        return ti.opcode

    def fn(self, name, argc=None):
        cands = self.t.funcs_by_name[name]
        if argc is not None:
            cands = [c for c in cands if c.argc == argc] or cands
        return cands[0]

    def literal(self, type_name, value, string=None) -> int:
        t = self.vt(type_name)
        return self.add(t, t, EXPR_EXPRESSION, value=value, string=string)

    def call(self, name, arg_ids, argc=None) -> int:
        info = self.fn(name, argc if argc is not None else len(arg_ids))
        fname = self.add(0xFFFF, self.vt("function_name"), EXPR_EXPRESSION,
                         string=name, line=0)
        head = self.link([fname] + arg_ids)
        gid = self.add(info.opcode, self.vt(info.return_type) if info.return_type in self.t.types_by_name
                       else self.vt("void"), EXPR_GROUP, value=head)
        return gid

    def global_ref(self, name, type_name) -> int:
        return self.add(0x0000, self.vt(type_name), EXPR_GLOBAL_REF, string=name)


def build(table):
    b = Builder(table)

    score = b.call("campaign_metagame_get_player_score", [b.literal("player", 0, "player0")])
    cost = b.literal("long", 1500)
    test = b.call(">=", [score, cost])

    deduct = b.call("campaign_metagame_award_points",
                    [b.literal("player", 0, "player0"),
                     b.literal("long", 0xFFFFFA24)])  # -1500
    place = b.call("ai_place", [b.literal("ai", 0x00000001, "sq_fe_marines")], argc=1)
    notify = b.call("chud_post_message",
                    [b.literal("player", 0, "player0"),
                     b.literal("string_id", 0x1111, "fe_bought_marines")])
    then = b.call("begin", [deduct, place, notify])
    iff = b.call("if", [test, then])
    root = b.call("begin", [iff])
    global_value = b.literal("long", 0)
    return b, root, global_value


def write_blob(b, root, global_value, variant="reachmcc_u13", base_va=0x50000000, magic=0x50000000):
    f = SCNR_VARIANTS[variant]
    scnr_size = 0x900
    expr_off = (scnr_size + 0xF) & ~0xF
    expr_size = len(b.exprs) * STRIDE_EXPR
    script_off = expr_off + expr_size
    global_off = script_off + STRIDE_SCRIPT
    str_off = global_off + STRIDE_GLOBAL
    total = str_off + len(b.strings) + 16

    buf = bytearray(total)

    for i, (opcode, vtype, etype, string, value, line, nxt) in enumerate(b.exprs):
        so = b.intern(string) if string is not None else 0xFFFFFFFF
        struct.pack_into("<HHhhIIIh", buf, expr_off + i * STRIDE_EXPR,
                         0, opcode & 0xFFFF, vtype, etype, nxt, so, value & 0xFFFFFFFF, line)

    # one script: (script static void fe_buy_marines ...)
    struct.pack_into("<IhhIIII", buf, script_off,
                     0x00001234, 3, b.vt("void"), root, 0, 0, 0)

    # one global: (global long g_fe_spent <expr>)
    gname = b"g_fe_spent\0"
    buf[global_off : global_off + len(gname)] = gname
    struct.pack_into("<hHI", buf, global_off + 0x20, b.vt("long"), 0, global_value)

    buf[str_off : str_off + len(b.strings)] = b.strings

    def compress(real):
        return (real - magic) >> 2

    struct.pack_into("<i", buf, f["string_table_size"], len(b.strings))
    struct.pack_into("<I", buf, f["string_table_addr"], compress(base_va + str_off))
    struct.pack_into("<i", buf, f["script_count"], 1)
    struct.pack_into("<I", buf, f["script_addr"], compress(base_va + script_off))
    struct.pack_into("<i", buf, f["global_count"], 1)
    struct.pack_into("<I", buf, f["global_addr"], compress(base_va + global_off))
    struct.pack_into("<i", buf, f["expr_count"], len(b.exprs))
    struct.pack_into("<I", buf, f["expr_addr"], compress(base_va + expr_off))
    return bytes(buf)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--table", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--stringids")
    args = ap.parse_args()

    table = load_table(args.table)
    b, root, global_value = build(table)
    # strings must be interned before they are packed; do a dry pass.
    for e in b.exprs:
        if e[3] is not None:
            b.intern(e[3])
    blob = write_blob(b, root, global_value)
    with open(args.out, "wb") as f:
        f.write(blob)
    print(f"wrote {args.out} ({len(blob)} bytes, {len(b.exprs)} expressions)")
    print("decompile with:")
    print(f"  python3 tools/hsc/decompile.py {args.out} --table {args.table} \\")
    print(f"      --base-va 0x50000000 --variant reachmcc_u13"
          + (f" --stringids {args.stringids}" if args.stringids else ""))

    if args.stringids:
        with open(args.stringids, "w") as f:
            json.dump({"0x00001234": "fe_buy_marines"}, f, indent=2)
        print(f"wrote {args.stringids}")


if __name__ == "__main__":
    main()
