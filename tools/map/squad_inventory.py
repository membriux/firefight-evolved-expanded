"""Squad / character-palette inventory for a Reach MCC cache, read from the
``scnr`` tag itself (not from scripts).

All offsets below are *derived*, not guessed: ``defwalk.Defs.layout()`` walks
``research/_raw/reach-defs/scenario.json`` and the walked size of every struct
used here matches its declared size, so the offsets are the official ones.

Usage:  python3 tools/map/squad_inventory.py <map> <out.json>
"""
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.expanduser("~/ffscripts"))

import reach_cache as rc  # noqa: E402
from defwalk import Defs  # noqa: E402

DEFS = os.path.join(ROOT, "research", "_raw", "reach-defs", "scenario.json")

# scenario_struct_definition
OFF_VEH_PALETTE = 0x138
OFF_SQUAD_GROUPS = 0x38C
OFF_SQUADS = 0x398
OFF_CHAR_PALETTE = 0x3EC
# squads_block_struct (0x6C)
SQ = dict(name=0x00, flags=0x20, team=0x24, parent=0x26, zone=0x28,
          objective=0x2A, filter=0x48, template=0x4C, tmpl_index=0x50,
          designer=0x54, templated=0x60)
SQ_SIZE = 0x6C
# cell_block_struct (0x6C)
CELL = dict(name=0x00, count=0x10, major=0x12, chartype=0x14, weapon=0x20,
            grenade=0x44, vehicle=0x46, variant=0x48, plscript=0x4C)
CELL_SIZE = 0x6C
CHOICE_SIZE = 0x10          # character_palette_choice_block_struct
CHOICE_INDEX = 0x0C
CHOICE_CHANCE = 0x0E
GROUP_SIZE = 0x28


def main(map_path, out_path):
    D = Defs(DEFS)
    teams = D.enums["ai_team_enum"]["options"]
    filters = D.enums.get("wave_placement_filter_enum", {}).get("options", [])
    sqflags = D.enums.get("squad_flags", {}).get("options", [])

    cache = rc.ReachCacheFile.from_path(map_path)
    data = cache.data
    scnr = cache.global_tag("scnr")
    base = scnr.offset

    def i32(o):
        return struct.unpack_from("<i", data, o)[0]

    def u32(o):
        return struct.unpack_from("<I", data, o)[0]

    def i16(o):
        return struct.unpack_from("<h", data, o)[0]

    def u16(o):
        return struct.unpack_from("<H", data, o)[0]

    def name32(o):
        return data[o:o + 0x20].split(b"\0")[0].decode("latin-1")

    def sid(o):
        s = cache.resolve_sid(u32(o))
        return None if (not s or s.startswith("<sid")) else s

    def block(o):
        n, p = i32(o), u32(o + 4)
        if n <= 0 or not p:
            return 0, 0
        return n, cache.meta_to_offset(cache.expand(p))

    def palette(o):
        n, po = block(o)
        out = []
        for i in range(n):
            datum = u32(po + i * 0x10 + 0xC)
            idx = datum & 0xFFFF
            t = cache.tags[idx] if 0 <= idx < len(cache.tags) else None
            out.append(t.path if (t and t.path) else "<datum 0x%08X>" % datum)
        return out

    chars = palette(base + OFF_CHAR_PALETTE)
    vehs = palette(base + OFF_VEH_PALETTE)

    gn, go = block(base + OFF_SQUAD_GROUPS)
    groups = [name32(go + i * GROUP_SIZE) for i in range(gn)]

    def flagnames(v):
        return [sqflags[i] for i in range(len(sqflags)) if v & (1 << i)] if sqflags else v

    sn, so = block(base + OFF_SQUADS)
    squads = []
    for i in range(sn):
        e = so + i * SQ_SIZE
        team_i = u16(e + SQ["team"])
        par = i16(e + SQ["parent"])
        filt = u32(e + SQ["filter"])
        rec = {
            "index": i,
            "name": name32(e + SQ["name"]),
            "flags": flagnames(u32(e + SQ["flags"])),
            "team": teams[team_i] if team_i < len(teams) else "team%d" % team_i,
            "group": groups[par] if 0 <= par < len(groups) else None,
            "wave_placement_filter": (filters[filt] if filt < len(filters) else filt),
            "template": sid(e + SQ["template"]),
            "squad_template_index": i32(e + SQ["tmpl_index"]),
            "cells": [],
        }
        for which in ("designer", "templated"):
            cc, co = block(e + SQ[which])
            for j in range(cc):
                c = co + j * CELL_SIZE
                chn, cho = block(c + CELL["chartype"])
                picks = []
                for k in range(chn):
                    ci = i16(cho + k * CHOICE_SIZE + CHOICE_INDEX)
                    picks.append({
                        "palette_index": ci,
                        "char": chars[ci] if 0 <= ci < len(chars) else None,
                        "chance": i16(cho + k * CHOICE_SIZE + CHOICE_CHANCE),
                    })
                vi = i16(c + CELL["vehicle"])
                rec["cells"].append({
                    "src": which,
                    "name": sid(c + CELL["name"]),
                    "normal_diff_count": i16(c + CELL["count"]),
                    "character_choices": picks,
                    "vehicle": vehs[vi] if 0 <= vi < len(vehs) else None,
                    "vehicle_variant": sid(c + CELL["variant"]),
                    "placement_script": sid(c + CELL["plscript"]),
                })
        squads.append(rec)

    payload = {
        "map": map_path,
        "build_string": cache.build_string,
        "scnr_tag_file_offset": base,
        "scnr_tag_size_estimate": scnr.size,
        "character_palette": chars,
        "vehicle_palette": vehs,
        "squad_groups": groups,
        "squads": squads,
    }
    with open(out_path, "w") as fh:
        json.dump(payload, fh, indent=1)
    empty = [s["name"] for s in squads if not s["cells"]]
    print("groups=%d squads=%d char_palette=%d empty_squads=%d" %
          (len(groups), len(squads), len(chars), len(empty)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
