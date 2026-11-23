#!/usr/bin/env python3
"""
parse_map.py -- report on, and extract tags from, a Halo: Reach ``.map`` cache file.

Usage
-----
    python3 tools/map/parse_map.py <path-to.map>                 # header + tag listing
    python3 tools/map/parse_map.py <map> --extract               # also dump tags to ./extracted/<map stem>/
    python3 tools/map/parse_map.py <map> --extract -o DIR        # dump somewhere else
    python3 tools/map/parse_map.py <map> --groups scnr,smdt,sqtm # pick which groups to dump
    python3 tools/map/parse_map.py <map> --all-tags --extract    # dump every tag (big)
    python3 tools/map/parse_map.py <map> --dump-meta             # also dump the whole tag-data area
    python3 tools/map/parse_map.py <map> --json                  # machine-readable report on stdout
    python3 tools/map/parse_map.py <map> --list-only             # just the tag table
    python3 tools/map/parse_map.py <map> --variant mcc-u8+       # force a header layout (last resort)
    python3 tools/map/parse_map.py --self-test                   # run the synthetic-cache test suite

Exit codes
----------
    0  parsed
    2  the file contradicts the cache-file spec (bad magic field, impossible offset, ...)
    3  the file looks compressed or packed rather than a flat cache file
    4  a cache header was found but no known header layout fits it (new MCC build?)

Stdlib only. Nothing here has been run against a real ``.map`` file; see the
STATUS block in reach_cache.py and research/07-map-container-format.md.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from reach_cache import (  # noqa: E402
    INTERESTING_GROUPS,
    VARIANTS,
    CompressedCacheError,
    MapFormatError,
    ReachCacheFile,
    UnknownBuildError,
    extract,
)


def human(n):
    if n is None:
        return "-"
    for unit in ("B", "KiB", "MiB", "GiB"):
        if abs(n) < 1024 or unit == "GiB":
            return "%.1f %s" % (n, unit) if unit != "B" else "%d B" % n
        n /= 1024.0


def print_report(cache: ReachCacheFile, out=None):
    out = out or sys.stdout
    s = cache.summary()
    p = lambda *a: print(*a, file=out)  # noqa: E731

    p("=" * 78)
    p("HALO: REACH CACHE FILE")
    p("=" * 78)
    p("file                 %s" % s["path"])
    p("size on disk         0x%X (%s)" % (s["file_size_actual"], human(s["file_size_actual"])))
    p("endianness           %s" % s["endian"])
    p("engine version       %d  (header offset 0x4)" % s["engine_version"])
    p("build string         %r" % s["build_string"])
    p("engine               %s" % (s["engine"] or "UNKNOWN BUILD"))
    p("header layout        %s   (%s)" % (s["header_layout"], s["detection"]))
    p("header size          0x%X   footer magic present: %s" % (s["header_size"], s["footer_magic_ok"]))
    p("cache type           %s" % s["cache_type"])
    p("internal name        %r" % s["internal_name"])
    p("scenario path        %r" % s["scenario_name"])
    p("cache build date     %s" % (s["build_date"] or "-"))
    p("checksum             0x%08X" % (s["checksum"] & 0xFFFFFFFF if s["checksum"] is not None else 0))
    p("")
    p("tag data ('meta') area")
    p("  file offset        0x%X   (%s)" % (s["tag_data_offset"], s["tag_data_source"]))
    p("  size               0x%X (%s)" % (s["tag_data_size"], human(s["tag_data_size"])))
    p("  virtual base       0x%X" % s["virtual_base_address"])
    p("  pointer expansion  %s" % ("virtual = (stored << 2) + 0x%X" % s["expand_magic"]
                                   if s["expand_magic"] else "none (32-bit pointers)"))
    p("")
    p("interop sections (index: name, virtual address, size, offset mask)")
    for i, sec in enumerate(s["sections"]):
        p("  %d %-13s vaddr 0x%08X  size 0x%08X  mask 0x%08X"
          % (i, sec["name"], sec["virtual_address"], sec["size"], sec["offset_mask"]))
    p("")
    ih = s["index_header"]
    p("index header @ file offset 0x%X (magic 'tags' verified)" % ih["offset"])
    p("  tag groups         %d @ 0x%X" % (ih["group_count"], ih["group_table_address"]))
    p("  tags               %d @ 0x%X" % (ih["tag_count"], ih["tag_table_address"]))
    p("  global tags        %d @ 0x%X" % (ih["global_count"], ih["global_table_address"]))
    p("  tag interops       %d @ 0x%X" % (ih["interop_count"], ih["interop_table_address"]))
    c = s["counts"]
    p("  tag names          %d    string ids %d    null tags %d"
      % (c["tag_names"], c["string_ids"], c["null_tags"]))
    p("")
    if s["global_tags"]:
        p("global tags (group -> tag index)")
        line = "  "
        for k, v in s["global_tags"].items():
            piece = "%s=%d  " % (k, v)
            if len(line) + len(piece) > 76:
                p(line)
                line = "  "
            line += piece
        p(line)
        p("")

    # group census, most interesting first
    census = {}
    for t in cache.tags:
        census.setdefault(t.group_code, []).append(t)
    p("tag group census (%d groups, %d tags)" % (len(cache.groups), len(cache.tags)))
    for code in sorted(census, key=lambda k: (-len(census[k]), k)):
        if len(census[code]) == 0:
            continue
        g = cache._group_by_code.get(code)
        name = (g.name if g else "") or ""
        star = " <<<" if code in INTERESTING_GROUPS else ""
        p("  %-6s %5d  %s%s" % (repr(code)[1:-1], len(census[code]), name, star))
    p("")

    if cache.diag.notes:
        p("notes")
        for n in cache.diag.notes:
            p("  - %s" % n)
        p("")
    if cache.diag.warnings:
        p("!! WARNINGS -- read these before trusting anything above")
        for w in cache.diag.warnings:
            p("  !! %s" % w)
        p("")


def print_listing(cache: ReachCacheFile, groups=None, out=None):
    out = out or sys.stdout
    p = lambda *a: print(*a, file=out)  # noqa: E731
    p("%-5s %-10s %-6s %-26s %-10s %-10s %s"
      % ("idx", "datum", "group", "group name", "offset", "est size", "path"))
    for t in cache.tags:
        if groups and t.group_code not in groups:
            continue
        p("%-5d 0x%08X %-6s %-26s %-10s %-10s %s"
          % (t.index, t.datum, repr(t.group_code)[1:-1], (t.group_name or "")[:26],
             ("0x%X" % t.offset) if t.offset is not None else "-",
             ("0x%X" % t.size) if t.size else "-",
             t.path if t.path is not None else "<no name>"))


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="parse_map.py",
        description="Parse a Halo: Reach (MCC or Xbox 360) .map cache file: header, tag index, tag extraction.")
    ap.add_argument("map", nargs="?", help="path to the .map cache file")
    ap.add_argument("-x", "--extract", action="store_true",
                    help="dump tags and tables to the output directory")
    ap.add_argument("-o", "--outdir", default=None,
                    help="output directory (default: ./extracted/<map stem>/)")
    ap.add_argument("--groups", default=",".join(INTERESTING_GROUPS),
                    help="comma-separated four-character group codes to dump (default: %(default)s)")
    ap.add_argument("--all-tags", action="store_true", help="dump every tag, not just --groups")
    ap.add_argument("--dump-meta", action="store_true", help="also dump the entire tag-data area as meta.bin")
    ap.add_argument("--list-only", action="store_true", help="print only the tag listing")
    ap.add_argument("--no-list", action="store_true", help="print the header report without the tag listing")
    ap.add_argument("--json", action="store_true", help="print the report as JSON")
    ap.add_argument("--variant", default=None,
                    help="force a header layout instead of detecting it: " +
                         ", ".join(v.name for v in VARIANTS))
    ap.add_argument("--self-test", action="store_true",
                    help="build synthetic cache files and verify the parser against them")
    args = ap.parse_args(argv)

    if args.self_test:
        import test_parse_map
        return test_parse_map.run()

    if not args.map:
        ap.error("a .map path is required (or --self-test)")

    try:
        cache = ReachCacheFile.from_path(args.map, force_variant=args.variant)
    except CompressedCacheError as exc:
        print("COMPRESSED / NOT A FLAT CACHE FILE\n%s" % exc, file=sys.stderr)
        return 3
    except UnknownBuildError as exc:
        print("UNKNOWN BUILD\n%s" % exc, file=sys.stderr)
        return 4
    except MapFormatError as exc:
        print("MALFORMED CACHE FILE\n%s" % exc, file=sys.stderr)
        return 2

    groups = [g for g in (x.strip() for x in args.groups.split(",")) if g]

    if args.json:
        payload = cache.summary()
        payload["tags"] = [{
            "index": t.index, "datum": t.datum, "group": t.group_code,
            "group_name": t.group_name, "path": t.path,
            "virtual_address": t.address, "file_offset": t.offset, "estimated_size": t.size,
        } for t in cache.tags]
        print(json.dumps(payload, indent=2, default=str))
    elif args.list_only:
        print_listing(cache, out=sys.stdout)
    else:
        print_report(cache)
        if not args.no_list:
            print("tag listing (%d tags)" % len(cache.tags))
            print_listing(cache)

    if args.extract:
        stem = Path(args.map).stem
        outdir = Path(args.outdir) if args.outdir else Path.cwd() / "extracted" / stem
        manifest = extract(cache, outdir, groups=groups,
                           all_tags=args.all_tags, dump_meta=args.dump_meta)
        print("\nextracted %d files to %s" % (len(manifest["written"]), outdir), file=sys.stderr)
        if manifest["errors"]:
            print("  %d extraction errors (see manifest.json)" % len(manifest["errors"]), file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
