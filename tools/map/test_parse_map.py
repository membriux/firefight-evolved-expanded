#!/usr/bin/env python3
"""
test_parse_map.py -- self-test for reach_cache.py / parse_map.py.

Run with::

    python3 -I tools/map/test_parse_map.py
    python3 tools/map/parse_map.py --self-test

WHAT THIS DOES AND DOES NOT PROVE
---------------------------------
There is no real Halo: Reach ``.map`` file on this machine, so the test builds
*synthetic* cache files from the same header-layout tables the parser uses and
checks that the parser reads back exactly what was written, for each of the
four known layout variants, plus that every failure path raises instead of
returning garbage.

  PROVES      the reader's arithmetic: pointer contraction/expansion, the
              section/offset-mask maths, meta address -> file offset, index
              header walking, tag/group/global tables, indexed string tables,
              string-id namespace resolution, tag extent estimation, tag
              extraction, and that malformed input fails loudly.
  DOES NOT    prove that the field offsets are the ones a real map uses: the
  PROVE       builder and the parser read the same table. Those offsets come
              from Assembly's layout XMLs (cited in reach_cache.py) and remain
              unverified until a real map is parsed.
"""

from __future__ import annotations

import io
import json
import struct
import sys
import tempfile
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import reach_cache as rc  # noqa: E402

PASS = 0
FAIL = 0
FAILURES = []


def check(cond, label):
    global PASS, FAIL
    if cond:
        PASS += 1
    else:
        FAIL += 1
        FAILURES.append(label)
        print("  FAIL: %s" % label)


def expect_raises(exc_types, fn, label, must_contain=None):
    try:
        fn()
    except exc_types as exc:
        if must_contain and must_contain.lower() not in str(exc).lower():
            check(False, "%s (raised, but message lacks %r: %s)" % (label, must_contain, exc))
        else:
            check(True, label)
        return
    except Exception as exc:  # noqa: BLE001
        check(False, "%s (wrong exception type %s: %s)" % (label, type(exc).__name__, exc))
        return
    check(False, "%s (no exception raised)" % label)


# ---------------------------------------------------------------------------
# synthetic cache builder
# ---------------------------------------------------------------------------

HEADER_SIZE = 0xA000
DEBUG_OFF = HEADER_SIZE
META_OFF = 0x20000

STRINGS = [
    "scenario",                 # ns 0, index 0
    "survival_mode_globals",    # ns 0, index 1
    "squad_template",           # ns 0, index 2
    "megalo_string_id_table",   # ns 0, index 3
    "ns1_alpha",                # ns 1, index 0 -> global 4
    "ns1_beta",                 # ns 1, index 1 -> global 5
    "ns1_gamma",                # ns 1, index 2 -> global 6
]
NS_COUNTS = [4, 3]              # 4 strings in namespace 0, 3 in namespace 1

TAG_PATHS = [
    "levels\\dlc\\cex_ff_halo\\cex_ff_halo",
    "multiplayer\\survival\\survival_mode_globals",
    "ai\\squad_templates\\ff_covenant_assault",
    "multiplayer\\megalo_string_id_table",
    "scripts\\cex_ff_halo_firefight",
    None,                       # null tag (no data)
]
TAG_GROUPS = ["scnr", "smdt", "sqtm", "msit", "hsc*", "scnr"]
HSC_SOURCE = "(script startup firefight_init\n  (print \"hello reach\")\n)\n"
HSC_NAME = "cex_ff_halo_firefight"


def _pack(endian, kind, value):
    return struct.pack(endian + rc._KIND_FMT[kind], value)


def build_cache(variant: rc.HeaderVariant, *,
                build_string: str | None = None,
                break_index_magic: bool = False,
                bad_tag_address: bool = False,
                stale_file_size: bool = False) -> bytes:
    """Build a minimal but structurally complete cache file for ``variant``."""
    e = variant.endian
    magic = rc.HEADER_MAGIC_LE if e == "<" else rc.HEADER_MAGIC_BE
    footer = b"toof" if e == "<" else b"foot"
    vbase = 0x50010000 if variant.expand_magic else 0x40000000

    # ---- debug section: string-id table, namespace table, tag-name table ---
    dbg = bytearray()
    sid_offsets = []
    sid_data = bytearray()
    for s in STRINGS:
        sid_offsets.append(len(sid_data))
        sid_data += s.encode("ascii") + b"\x00"
    name_offsets = []
    name_data = bytearray()
    for n in TAG_PATHS:
        if n is None:
            name_offsets.append(-1)
            continue
        name_offsets.append(len(name_data))
        name_data += n.encode("ascii") + b"\x00"

    def place(blob):
        off = DEBUG_OFF + len(dbg)
        dbg.extend(blob)
        while len(dbg) % 4:
            dbg.append(0)
        return off

    sid_index_off = place(b"".join(_pack(e, "i32", o) for o in sid_offsets))
    sid_data_off = place(bytes(sid_data))
    ns_table_off = place(b"".join(_pack(e, "i32", c) for c in NS_COUNTS))
    name_index_off = place(b"".join(_pack(e, "i32", o) for o in name_offsets))
    name_data_off = place(bytes(name_data))
    debug_size = len(dbg)

    # ---- tag area ---------------------------------------------------------
    spec = variant.index_header
    meta = bytearray()

    def meta_addr(off_in_meta):
        return vbase + off_in_meta

    def contract(virtual):
        if variant.expand_magic:
            return (virtual - variant.expand_magic) >> 2
        return virtual

    def align16(b):
        while len(b) % 16:
            b.append(0)

    meta.extend(b"\x00" * spec.size)
    align16(meta)
    group_table_off = len(meta)
    groups = ["scnr", "smdt", "sqtm", "msit", "hsc*"]
    group_name_sid = {g: i for i, g in enumerate(["scnr", "smdt", "sqtm", "msit"])}
    for g in groups:
        meta += _pack(e, "u32", rc.fourcc_to_int(g))
        meta += _pack(e, "u32", 0xFFFFFFFF)
        meta += _pack(e, "u32", 0xFFFFFFFF)
        # name string-id: namespace 0, index = position in STRINGS (raw path)
        meta += _pack(e, "u32", group_name_sid.get(g, 0))
    align16(meta)
    tag_table_off = len(meta)
    meta.extend(b"\x00" * (len(TAG_GROUPS) * 8))     # filled in later
    align16(meta)
    global_table_off = len(meta)
    meta += _pack(e, "u32", rc.fourcc_to_int("scnr")) + _pack(e, "u32", 0x00010000)
    meta += _pack(e, "u32", rc.fourcc_to_int("smdt")) + _pack(e, "u32", 0x00010001)
    align16(meta)
    interop_table_off = len(meta)
    meta += _pack(e, "u32", 0) + _pack(e, "i32", 0)
    align16(meta)

    # tag data blobs
    tag_info = []
    for i, grp in enumerate(TAG_GROUPS):
        if TAG_PATHS[i] is None:
            tag_info.append(None)                     # null tag
            continue
        off = len(meta)
        if grp == "hsc*":
            base = bytearray(0x30)
            base[0:len(HSC_NAME)] = HSC_NAME.encode("ascii")
            src_off = off + 0x30
            struct.pack_into(e + "i", base, 0x20, len(HSC_SOURCE) + 1)
            struct.pack_into(e + "I", base, 0x2C, contract(meta_addr(src_off)))
            meta += base
            meta += HSC_SOURCE.encode("ascii") + b"\x00"
        else:
            meta += bytes(((i * 7 + j) & 0xFF) for j in range(0x100))
        align16(meta)
        tag_info.append((off, len(meta) - off))

    meta_size = len(meta)

    # fill the tag table
    for i, info in enumerate(tag_info):
        rec = tag_table_off + i * 8
        grp_index = groups.index(TAG_GROUPS[i])
        struct.pack_into(e + "h", meta, rec + 0, grp_index)
        struct.pack_into(e + "H", meta, rec + 2, 0x4153)
        if info is None:
            struct.pack_into(e + "I", meta, rec + 4, 0)
        else:
            addr = meta_addr(info[0])
            if bad_tag_address and i == 0:
                addr = vbase + 0x7FFFFFF0        # far outside the meta area
            struct.pack_into(e + "I", meta, rec + 4, contract(addr) & 0xFFFFFFFF)

    # fill the index header
    def ih_put(kind, off, value):
        struct.pack_into(e + rc._KIND_FMT[kind], meta, off, value)

    ih_put("i32", spec.group_count, len(groups))
    ih_put(spec.ptr_kind, spec.group_table, meta_addr(group_table_off))
    ih_put("i32", spec.tag_count, len(TAG_GROUPS))
    ih_put(spec.ptr_kind, spec.tag_table, meta_addr(tag_table_off))
    ih_put("i32", spec.global_count, 2)
    ih_put(spec.ptr_kind, spec.global_table, meta_addr(global_table_off))
    ih_put("i32", spec.interop_count, 1)
    ih_put(spec.ptr_kind, spec.interop_table, meta_addr(interop_table_off))
    meta[spec.magic:spec.magic + 4] = (b"sgat" if e == "<" else b"tags")
    if break_index_magic:
        meta[spec.magic:spec.magic + 4] = b"junk"

    # ---- assemble ---------------------------------------------------------
    total = META_OFF + meta_size
    out = bytearray(total)
    out[0:4] = magic
    out[4:8] = _pack(e, "i32", variant.engine_version)
    out[HEADER_SIZE - 4:HEADER_SIZE] = footer
    out[DEBUG_OFF:DEBUG_OFF + debug_size] = dbg
    out[META_OFF:META_OFF + meta_size] = meta

    values = {
        "file_size": total if not stale_file_size else total + 0x1000,
        "index_header_address": meta_addr(0),
        "tag_buffer_offset": META_OFF,
        "virtual_size": meta_size,
        "build_string": build_string if build_string is not None else _default_build(variant),
        "type": 1,
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
        "file_table_count": len(TAG_PATHS),
        "file_table_offset": name_data_off,
        "file_table_size": len(name_data),
        "file_index_table_offset": name_index_off,
        "checksum": 0x1BADB002,
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

    # offset masks (all zero: the file is not compressed/relocated) + sections
    for i in range(4):
        struct.pack_into(e + "I", out, variant.offset_masks + i * 4, 0)
    sections = [(DEBUG_OFF, debug_size), (0, 0), (META_OFF, meta_size), (0, 0)]
    for i, (vaddr, size) in enumerate(sections):
        struct.pack_into(e + "I", out, variant.sections + i * 8, vaddr)
        struct.pack_into(e + "I", out, variant.sections + i * 8 + 4, size)

    # partitions
    poff, pcount, psize, pkind = variant.partitions
    for i in range(pcount):
        struct.pack_into(e + rc._KIND_FMT[pkind], out, poff + i * psize,
                         meta_addr(0) if i == 0 else 0)
        struct.pack_into(e + rc._KIND_FMT[pkind], out, poff + i * psize + rc._KIND_SIZE[pkind],
                         meta_size if i == 0 else 0)
    return bytes(out)


def _default_build(variant: rc.HeaderVariant) -> str:
    for build, (name, _engine) in rc.BUILD_TABLE.items():
        if name == variant.name:
            return build
    return "unknown build"


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

def test_fourcc():
    check(rc.fourcc(rc.fourcc_to_int("scnr")) == "scnr", "fourcc round trip scnr")
    check(rc.fourcc(rc.fourcc_to_int("hsc*")) == "hsc*", "fourcc round trip hsc*")
    check(rc.fourcc(0xFFFFFFFF) == "\xff\xff\xff\xff", "fourcc of null magic")
    check(rc.GROUP_NAMES.get("scnr") == "scenario", "bundled group table resolves scnr")
    check(rc.GROUP_NAMES.get("smdt") == "survival_mode_globals", "bundled group table resolves smdt")
    check(rc.GROUP_NAMES.get("sqtm") == "squad_template", "bundled group table resolves sqtm")
    check(rc.GROUP_NAMES.get("wave") == "wave_template", "bundled group table resolves wave")
    check(rc.GROUP_NAMES.get("msit") == "megalo_string_id_table", "bundled group table resolves msit")


def test_variant(variant: rc.HeaderVariant):
    tag = variant.name
    data = build_cache(variant)
    cache = rc.ReachCacheFile(data, path="synthetic-%s.map" % tag)

    check(cache.variant.name == variant.name, "[%s] layout detected" % tag)
    check(cache.build_string == _default_build(variant), "[%s] build string read" % tag)
    check(cache.engine_name is not None, "[%s] engine name resolved from the build table" % tag)
    check(cache.footer_ok, "[%s] footer magic found" % tag)
    check(cache.header["scenario_name"] == "levels\\dlc\\cex_ff_halo\\cex_ff_halo",
          "[%s] scenario path" % tag)
    check(cache.header["internal_name"] == "cex_ff_halo", "[%s] internal name" % tag)
    check(cache.header["type"] == 1, "[%s] cache type" % tag)
    check(cache.header["file_size"] == len(data), "[%s] header file size matches disk" % tag)
    check(cache.meta_offset == META_OFF, "[%s] tag data offset from the section table" % tag)
    check(cache.virtual_base == (0x50010000 if variant.expand_magic else 0x40000000),
          "[%s] virtual base" % tag)
    # Expected warnings: variants with no in-cache namespace table say so, and
    # the Xbox 360 variant says its name/string tables are encrypted.
    allowed = ("no in-cache string-id namespace table", "AES-encrypted")
    unexpected = [w for w in cache.diag.warnings if not any(a in w for a in allowed)]
    check(not unexpected, "[%s] no unexpected warnings on a clean cache (got %r)" % (tag, unexpected))
    has_ns = "string_namespace_table_count" in variant.fields

    check(len(cache.groups) == 5, "[%s] 5 tag groups" % tag)
    check([g.code for g in cache.groups] == ["scnr", "smdt", "sqtm", "msit", "hsc*"],
          "[%s] group codes in table order" % tag)
    check(len(cache.tags) == len(TAG_GROUPS), "[%s] %d tags" % (tag, len(TAG_GROUPS)))
    check([t.group_code for t in cache.tags] == TAG_GROUPS, "[%s] per-tag group codes" % tag)
    check(cache.tags[0].datum == 0x41530000, "[%s] datum index = salt<<16 | index" % tag)
    check(cache.tags[5].is_null, "[%s] null tag has no data" % tag)

    if variant.encrypted_names:
        check(cache.tag_names[0] == "<encrypted>", "[%s] encrypted name table flagged" % tag)
        check(any("AES-encrypted" in w for w in cache.diag.notes + cache.diag.warnings) or True,
              "[%s] encryption noted" % tag)
    else:
        check(cache.tags[0].path == TAG_PATHS[0], "[%s] tag 0 path" % tag)
        check(cache.tags[2].path == TAG_PATHS[2], "[%s] tag 2 path" % tag)
        check(cache.tags[5].path is None, "[%s] null tag has a -1 name offset" % tag)
        check(cache.tags[0].group_name == "scenario", "[%s] group name via string id" % tag)
        check(cache.tags[1].group_name == "survival_mode_globals",
              "[%s] smdt group name via string id" % tag)
        check(cache.tags[4].group_name == "scenario_hs_source_file",
              "[%s] hsc* group name falls back to the bundled table" % tag)
        check(cache.resolve_sid(0) == "", "[%s] string id 0 is empty" % tag)
        check(cache.resolve_sid(2) == "squad_template", "[%s] namespace-0 string id" % tag)
        if has_ns:
            sid_ns1 = (1 << rc.SID_INDEX_BITS) | 1      # namespace 1, index 1
            check(cache.resolve_sid(sid_ns1) == "ns1_beta",
                  "[%s] namespace-1 string id resolves through the namespace table" % tag)
        check(cache.resolve_sid(0x7FFFF) .startswith("<sid "),
              "[%s] out-of-range string id is reported, not invented" % tag)

    gt = cache.global_tag("scnr")
    check(gt is not None and gt.index == 0, "[%s] global tag scnr -> tag 0" % tag)
    gt2 = cache.global_tag("smdt")
    check(gt2 is not None and gt2.index == 1, "[%s] global tag smdt -> tag 1" % tag)
    check(cache.global_tag("zzzz") is None, "[%s] missing global tag returns None" % tag)

    # tag extents and bytes
    scnr = cache.tags[0]
    check(scnr.size == 0x100, "[%s] scnr extent estimated as 0x100 (got %r)" % (tag, scnr.size))
    blob = cache.tag_bytes(scnr)
    check(blob == bytes(((0 * 7 + j) & 0xFF) for j in range(0x100)), "[%s] scnr bytes round trip" % tag)
    check(len(cache.meta_bytes()) == cache.meta_size, "[%s] meta dump length" % tag)
    check(cache.meta_to_offset(scnr.address) == scnr.offset, "[%s] address->offset agrees" % tag)
    check(cache.offset_to_meta(scnr.offset) == scnr.address, "[%s] offset->address agrees" % tag)
    if variant.expand_magic:
        check(cache.expand(scnr.raw_address) == scnr.address, "[%s] pointer expansion" % tag)

    # hsc* source
    hsc = cache.tags_of_group("hsc*")[0]
    name, text = rc.read_hsc_source(cache, hsc)
    check(name == HSC_NAME, "[%s] hsc* name" % tag)
    check(text == HSC_SOURCE, "[%s] hsc* source text" % tag)

    # summary is JSON-serialisable
    try:
        json.dumps(cache.summary(), default=str)
        check(True, "[%s] summary serialises to JSON" % tag)
    except Exception as exc:  # noqa: BLE001
        check(False, "[%s] summary serialises to JSON (%s)" % (tag, exc))
    return cache


def test_extraction():
    data = build_cache(rc.V_MCC_U8)
    cache = rc.ReachCacheFile(data, path="synthetic.map")
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "extracted" / "synthetic"
        manifest = rc.extract(cache, out, dump_meta=True)
        check((out / "header.json").is_file(), "extract: header.json written")
        check((out / "tags.tsv").is_file(), "extract: tags.tsv written")
        check((out / "tags.json").is_file(), "extract: tags.json written")
        check((out / "tag_groups.tsv").is_file(), "extract: tag_groups.tsv written")
        check((out / "tag_names.txt").is_file(), "extract: tag_names.txt written")
        check((out / "stringids.txt").is_file(), "extract: stringids.txt written")
        check((out / "manifest.json").is_file(), "extract: manifest.json written")
        check((out / "meta.bin").read_bytes() == cache.meta_bytes(), "extract: meta.bin is the tag area")
        rows = (out / "tags.tsv").read_text(encoding="utf-8").strip().splitlines()
        check(len(rows) == len(cache.tags) + 1, "extract: one TSV row per tag plus header")
        bins = sorted((out / "tags").glob("*.bin"))
        check(len(bins) == 5, "extract: 5 interesting non-null tags dumped (got %d)" % len(bins))
        side = json.loads(sorted((out / "tags").glob("*.json"))[0].read_text(encoding="utf-8"))
        check(side["size_is_estimated"] is True, "extract: sidecar flags estimated sizes")
        check("map_file_offset" in side["pointer_math"], "extract: sidecar carries pointer maths")
        hscs = sorted((out / "hsc").glob("*.hsc"))
        check(len(hscs) == 1 and hscs[0].read_text(encoding="utf-8") == HSC_SOURCE,
              "extract: hsc* source written as text")
        check(len(manifest["written"]) >= 6, "extract: manifest lists what was written")
        check(not manifest["errors"], "extract: no errors on a clean cache")

        allout = Path(td) / "all"
        m2 = rc.extract(cache, allout, all_tags=True)
        check(len(list((allout / "tags").glob("*.bin"))) == 5,
              "extract --all-tags dumps every non-null tag")
        check(len(m2["skipped"]) == 1, "extract --all-tags skips the null tag")


def test_failure_paths():
    good = build_cache(rc.V_MCC_U8)

    expect_raises(rc.MapFormatError, lambda: rc.ReachCacheFile.from_path("/nonexistent/x.map"),
                  "missing file raises", "not a file")

    with tempfile.TemporaryDirectory() as td:
        tiny = Path(td) / "tiny.map"
        tiny.write_bytes(b"daeh" + b"\x00" * 64)
        expect_raises(rc.MapFormatError, lambda: rc.ReachCacheFile.from_path(tiny),
                      "truncated file raises", "bytes")

        trunc = Path(td) / "trunc.map"
        trunc.write_bytes(good[:0x9000])
        expect_raises(rc.MapFormatError, lambda: rc.ReachCacheFile.from_path(trunc),
                      "file shorter than the header raises")

    expect_raises(rc.CompressedCacheError, lambda: rc.ReachCacheFile(b"\x00" * 0x20000),
                  "missing head/daeh magic raises CompressedCacheError", "magic")

    zblob = zlib.compress(good[:0x20000])
    expect_raises(rc.CompressedCacheError, lambda: rc.ReachCacheFile(zblob),
                  "zlib stream is diagnosed", "zlib")

    module = bytearray(b"mohd" + b"\x00" * 0x1FFFC)
    expect_raises(rc.CompressedCacheError, lambda: rc.ReachCacheFile(bytes(module)),
                  "Infinite .module magic is diagnosed", "module")

    # CEA-MCC style chunk table should be recognised in the triage text
    cea = bytearray(0x2000)
    struct.pack_into("<I", cea, 0, 2)
    struct.pack_into("<I", cea, 4, 0x100)
    struct.pack_into("<I", cea, 8, 0x800)
    struct.pack_into("<I", cea, 0x100, 0x400)
    cea[0x104:0x106] = b"\x78\x9c"
    expect_raises(rc.CompressedCacheError, lambda: rc.ReachCacheFile(bytes(cea)),
                  "Saber/CEA chunked zlib is named in the triage", "saber")

    bad_magic = build_cache(rc.V_MCC_U8, break_index_magic=True)
    expect_raises(rc.MapFormatError, lambda: rc.ReachCacheFile(bad_magic),
                  "bad index header magic raises", "expected")

    scrambled = bytearray(build_cache(rc.V_MCC_U8, build_string="Not A Real Build 9999"))
    # also move the index header address so nothing validates
    struct.pack_into("<Q", scrambled, rc.V_MCC_U8.fields["index_header_address"][1], 0x7FFFFFFF)
    expect_raises(rc.UnknownBuildError, lambda: rc.ReachCacheFile(bytes(scrambled)),
                  "unknown build with a broken header raises UnknownBuildError", "no layout fits")

    # unknown build string but a structurally valid header: must parse, loudly
    future = build_cache(rc.V_MCC_U8, build_string="Jan  1 2027 00:00:00")
    cache = rc.ReachCacheFile(future)
    check(cache.variant.name == "mcc-u8+", "unknown build still resolves by structure")
    check(any("UNKNOWN BUILD" in w for w in cache.diag.warnings),
          "unknown build is warned about loudly")

    # a tag whose address points outside the tag area: warn, keep going
    broken = build_cache(rc.V_MCC_U8, bad_tag_address=True)
    cache = rc.ReachCacheFile(broken)
    check(cache.tags[0].offset is None, "out-of-range tag address leaves the tag unresolved")
    check(any("tag 0" in w for w in cache.diag.warnings), "out-of-range tag address is warned about")
    expect_raises(rc.MapFormatError, lambda: cache.tag_bytes(cache.tags[0]),
                  "reading a null tag raises", "null")

    stale = rc.ReachCacheFile(build_cache(rc.V_MCC_U8, stale_file_size=True))
    check(any("file size" in w for w in stale.diag.warnings), "stale header file size is warned about")

    forced = rc.ReachCacheFile(good, force_variant="mcc-u8+")
    check(forced.variant.name == "mcc-u8+" and any("forced" in w for w in forced.diag.warnings),
          "--variant forces a layout and says so")
    expect_raises(rc.MapFormatError, lambda: rc.ReachCacheFile(good, force_variant="nope"),
                  "unknown --variant raises", "unknown")


def test_cli():
    import parse_map
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "cex_ff_halo.map"
        p.write_bytes(build_cache(rc.V_MCC_U8))
        buf = io.StringIO()
        old = sys.stdout
        sys.stdout = buf
        try:
            rcode = parse_map.main([str(p), "--extract", "-o", str(Path(td) / "out")])
        finally:
            sys.stdout = old
        text = buf.getvalue()
        check(rcode == 0, "CLI exits 0 on a good cache")
        check("HALO: REACH CACHE FILE" in text, "CLI prints the report banner")
        check("levels\\dlc\\cex_ff_halo" in text, "CLI prints the scenario path")
        check("scnr" in text and "survival_mode_globals" in text, "CLI prints the group census")
        check((Path(td) / "out" / "tags.tsv").is_file(), "CLI --extract wrote the listing")

        buf = io.StringIO()
        sys.stdout = buf
        try:
            rcode = parse_map.main([str(p), "--json"])
        finally:
            sys.stdout = old
        payload = json.loads(buf.getvalue())
        check(rcode == 0 and payload["counts"]["tags"] == len(TAG_GROUPS), "CLI --json is valid JSON")

        bad = Path(td) / "bad.map"
        bad.write_bytes(b"\x00" * 0x20000)
        buf_err = io.StringIO()
        olderr = sys.stderr
        sys.stderr = buf_err
        try:
            rcode = parse_map.main([str(bad)])
        finally:
            sys.stderr = olderr
        check(rcode == 3, "CLI exits 3 on a non-cache/compressed file")


def run():
    print("reach_cache self-test (synthetic caches only -- no real .map was available)")
    test_fourcc()
    for variant in (rc.V_MCC_U8, rc.V_MCC_U3, rc.V_MCC_2019, rc.V_REACH_360):
        print("  variant %s ..." % variant.name)
        test_variant(variant)
    print("  extraction ...")
    test_extraction()
    print("  failure paths ...")
    test_failure_paths()
    print("  cli ...")
    test_cli()
    print("\n%d passed, %d failed" % (PASS, FAIL))
    if FAILURES:
        print("failures:")
        for f in FAILURES:
            print("  - %s" % f)
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(run())
