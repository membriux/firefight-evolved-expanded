"""Emit a {stringID -> name} JSON table for decompile.py --stringids.

The scnr script/global tables store full stringID *values* (index + namespace +
length bits), so a flat index->string list is not usable directly. This resolves
every stringID value that appears in the scenario's script table, plus every
stringID value that any squad / cell name uses, through
``reach_cache.resolve_sid``.

Usage: python3 tools/map/sid_table_for_scripts.py <map> <out.json>
"""
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import reach_cache as rc  # noqa: E402

OFF_SCRIPTS = 0x430
STRIDE_SCRIPT = 0x18


def main(map_path, out_path):
    cache = rc.ReachCacheFile.from_path(map_path)
    data = cache.data
    scnr = cache.global_tag("scnr")
    base = scnr.offset

    n = struct.unpack_from("<i", data, base + OFF_SCRIPTS)[0]
    p = struct.unpack_from("<I", data, base + OFF_SCRIPTS + 4)[0]
    table = {}
    if n > 0 and p:
        off = cache.meta_to_offset(cache.expand(p))
        for i in range(n):
            sid = struct.unpack_from("<I", data, off + i * STRIDE_SCRIPT)[0]
            name = cache.resolve_sid(sid)
            if name and not name.startswith("<sid"):
                table["0x%08X" % sid] = name

    # Any other stringID whose plain index form is in range is also worth having
    # (script-parameter names, squad names referenced as strings, ...).
    for idx, s in enumerate(cache.stringids):
        if s:
            table.setdefault("0x%08X" % idx, s)

    with open(out_path, "w") as fh:
        json.dump(table, fh, indent=0)
    print("resolved %d/%d script names, %d total entries" %
          (sum(1 for k in table if int(k, 16) > len(cache.stringids)), n, len(table)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
