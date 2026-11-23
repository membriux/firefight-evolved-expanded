#!/usr/bin/env python3
"""
test_reach_write.py -- self-test for reach_write.py (the cache-file writer).

Run with::

    python3 -I tools/map/test_reach_write.py
    python3 tools/map/reach_write.py --self-test

WHAT THIS DOES AND DOES NOT PROVE
---------------------------------
There is still no real Halo: Reach ``.map`` file on this machine. Every test
below runs against the *synthetic* caches that ``test_parse_map.py`` builds,
plus one extra fixture built here whose interop sections are in the realistic
order (tag data first, debug section last - the order a shipped Reach map
uses, per Assembly's ThirdGenHeader.RebuildInteropData comment).

  PROVES      that encode is the exact inverse of decode for every field the
              reader understands (the round-trip gate); that the checksum
              algorithm is implemented as Assembly implements it and is
              stable, order-independent and sensitive to tag-data edits; that
              a same-size in-tag patch leaves everything else byte-identical;
              that the tag area can be grown at either end with every count,
              pointer, section, mask and partition left self-consistent, so
              that the *reader* parses the grown file and resolves every tag,
              tag name and string-id exactly as before; and that a tag or an
              index table can be relocated into the new space and re-pointed.
  DOES NOT    prove that MCC will load the result. The field offsets, the
  PROVE       growth convention and the engine's own tolerance for a resized
              tag area are all unverified against real bytes.
"""

from __future__ import annotations

import struct
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import reach_cache as rc          # noqa: E402
import reach_write as rw          # noqa: E402
import test_parse_map as tpm      # noqa: E402

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
# fixtures
# ---------------------------------------------------------------------------

def fixture(variant: rc.HeaderVariant) -> bytes:
    """A synthetic cache with a correct checksum (debug section BEFORE the tag area)."""
    data = bytearray(tpm.build_cache(variant))
    _hdr_put(data, variant, "checksum", rw.checksum_of(data, variant.header_size, variant.endian))
    return bytes(data)


def _hdr_put(buf: bytearray, variant: rc.HeaderVariant, name: str, value: int):
    kind, off = variant.fields[name]
    size = rc._KIND_SIZE[kind]
    fmt = variant.endian + {2: "H", 4: "I", 8: "Q"}[size]
    struct.pack_into(fmt, buf, off, value & ((1 << (size * 8)) - 1))


def fixture_debug_last(variant: rc.HeaderVariant) -> bytes:
    """Rebuild the synthetic cache with the shipped-map section order.

    Real Reach caches lay the file out as resource, locale, tag, debug - the
    debug section (string-id and tag-name tables) is *after* the tag data area,
    so growing the tag area has to move it. ``build_cache`` puts debug first,
    which would let a buggy writer pass. This fixture closes that hole.

    Built with raw struct writes, deliberately *not* with CacheWriter, so the
    thing under test is not used to build its own input.
    """
    src = tpm.build_cache(variant)
    e = variant.endian
    hdr_size = variant.header_size
    cache = rc.ReachCacheFile(src)
    debug_off, debug_size = cache.sections[rc.SECTION_DEBUG]
    meta_off, meta_size = cache.meta_offset, cache.meta_size

    new_meta_off = hdr_size
    new_debug_off = (new_meta_off + meta_size + 0xF) & ~0xF

    out = bytearray(src[:hdr_size])
    out.extend(b"\x00" * (new_debug_off + debug_size - len(out)))
    out[new_meta_off:new_meta_off + meta_size] = src[meta_off:meta_off + meta_size]
    out[new_debug_off:new_debug_off + debug_size] = src[debug_off:debug_off + debug_size]

    # sections and masks: masks stay 0, so the virtual address *is* the file
    # offset, which is what a shipped (uncompressed) map looks like.
    for i, (vaddr, size) in enumerate([(new_debug_off, debug_size), (0, 0),
                                       (new_meta_off, meta_size), (0, 0)]):
        struct.pack_into(e + "I", out, variant.sections + i * 8, vaddr)
        struct.pack_into(e + "I", out, variant.sections + i * 8 + 4, size)
    for i in range(4):
        struct.pack_into(e + "I", out, variant.offset_masks + i * 4, 0)

    _hdr_put(out, variant, "tag_buffer_offset", new_meta_off)
    _hdr_put(out, variant, "file_size", len(out))
    for name in rw.DEBUG_POINTER_FIELDS:
        if name in variant.fields and cache.header.get(name):
            _hdr_put(out, variant, name, cache.header[name] - debug_off + new_debug_off)
    # virtual base is unchanged: a tag's address is vbase + its offset inside
    # the tag area, and the tag area's *contents* did not move relative to its
    # own start.
    _hdr_put(out, variant, "checksum", rw.checksum_of(out, hdr_size, e))
    return bytes(out)


def snapshot(cache: rc.ReachCacheFile):
    """Everything about a parse that a correct edit must preserve."""
    return {
        "tags": [(t.index, t.group_code, t.address, t.path,
                  None if t.offset is None else bytes(cache.tag_bytes(t))[:0x40])
                 for t in cache.tags],
        "names": list(cache.tag_names),
        "strings": list(cache.stringids),
        "globals": dict(cache.global_tags),
        "groups": [(g.code, g.name_sid) for g in cache.groups],
    }


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

def test_round_trip(variant: rc.HeaderVariant):
    """THE GATE: re-encode every parsed field; the file must not change."""
    for label, data in (("debug-first", fixture(variant)),
                        ("debug-last", fixture_debug_last(variant))):
        cache = rc.ReachCacheFile(data)
        w = rw.CacheWriter(cache)
        out = w.reencode_all()
        if out == data:
            check(True, "%s/%s: re-encode is byte-identical" % (variant.name, label))
        else:
            diffs = [i for i in range(len(data)) if data[i] != out[i]]
            check(False, "%s/%s: re-encode differs at %d bytes, first 0x%X"
                  % (variant.name, label, len(diffs), diffs[0] if diffs else -1))
        check(len(out) == len(data), "%s/%s: re-encode kept the file length" % (variant.name, label))


def test_checksum(variant: rc.HeaderVariant):
    data = fixture(variant)
    cache = rc.ReachCacheFile(data)
    w = rw.CacheWriter(cache)
    stored, computed, ok = w.verify_checksum()
    check(ok, "%s: fixture checksum verifies (0x%08X)" % (variant.name, computed))
    # stable and idempotent
    check(w.compute_checksum() == computed, "%s: checksum is stable" % variant.name)
    w.update_checksum()
    check(w.bytes() == data, "%s: rewriting the same checksum changes nothing" % variant.name)
    # sensitive to a tag-data edit
    tag = next(t for t in cache.tags if t.offset is not None and t.group_code == "scnr")
    w2 = rw.CacheWriter(cache)
    w2.patch_tag(tag, b"\xDE\xAD\xBE\xEF")
    check(w2.compute_checksum() != computed, "%s: checksum changes after a tag edit" % variant.name)
    w2.update_checksum()
    check(rw.CacheWriter(w2.reparse()).verify_checksum()[2],
          "%s: checksum verifies again after update" % variant.name)
    # a header-only edit must NOT change it (the checksum covers only
    # everything after the header)
    w3 = rw.CacheWriter(cache)
    w3.put_header("xdk_version", 0x1234)
    check(w3.compute_checksum() == computed,
          "%s: header edits do not affect the checksum" % variant.name)


def test_same_size_patch(variant: rc.HeaderVariant):
    data = fixture(variant)
    cache = rc.ReachCacheFile(data)
    before = snapshot(cache)
    tag = next(t for t in cache.tags if t.group_code == "sqtm" and t.offset is not None)
    w = rw.CacheWriter(cache)
    w.patch_tag_field(tag, 0x10, "i32", 1500)          # "a price"
    w.update_checksum()
    out = w.bytes()
    check(len(out) == len(data), "%s: same-size patch did not change the file length" % variant.name)
    changed = [i for i in range(len(data)) if data[i] != out[i]]
    ck_off = variant.fields["checksum"][1]
    expected = set(range(tag.offset + 0x10, tag.offset + 0x14)) | set(range(ck_off, ck_off + 4))
    check(set(changed) <= expected,
          "%s: only the patched field and the checksum changed (%d bytes)" % (variant.name, len(changed)))
    after = rc.ReachCacheFile(out)
    check(struct.unpack_from(variant.endian + "i", after.tag_bytes(after.tags[tag.index]), 0x10)[0] == 1500,
          "%s: the patched value reads back" % variant.name)
    a = snapshot(after)
    check(a["names"] == before["names"] and a["strings"] == before["strings"]
          and a["globals"] == before["globals"] and a["groups"] == before["groups"],
          "%s: tables untouched by a same-size patch" % variant.name)
    check([t[:4] for t in a["tags"]] == [t[:4] for t in before["tags"]],
          "%s: tag table untouched by a same-size patch" % variant.name)


def test_growth(variant: rc.HeaderVariant, layout: str, mode: str):
    data = fixture(variant) if layout == "debug-first" else fixture_debug_last(variant)
    cache = rc.ReachCacheFile(data)
    before = snapshot(cache)
    old_meta_size = cache.meta_size
    w = rw.CacheWriter(cache)
    # Downward growth is asked for in the minimum legal granularity: the
    # synthetic fixture's virtual base sits only 0x10000 above the expand
    # magic, so a full allocator page would push it below 0x50000000 (which
    # the writer refuses - see test_failure_paths).
    page = rw.ALLOC_PAGE if mode == "end" else rw.SEGMENT_ALIGN
    g = w.grow_tag_area(0x40, mode=mode, page=page)
    tag_label = "%s/%s/%s" % (variant.name, layout, mode)
    check(g.granted == page, "%s: growth rounded up to one 0x%X page" % (tag_label, page))
    out = w.bytes()
    check(len(out) == len(data) + g.granted, "%s: file grew by exactly the granted amount" % tag_label)

    after = rc.ReachCacheFile(out)
    check(after.meta_size == old_meta_size + g.granted, "%s: virtual size updated" % tag_label)
    old_debug = cache.sections[rc.SECTION_DEBUG][0] + cache.offset_masks[rc.SECTION_DEBUG]
    new_debug = after.sections[rc.SECTION_DEBUG][0] + after.offset_masks[rc.SECTION_DEBUG]
    if layout == "debug-last":
        # proves the test is not passing trivially: the debug section really
        # had to move, which is the case a shipped Reach map presents.
        check(new_debug == old_debug + g.granted,
              "%s: debug section was shifted by the growth (0x%X -> 0x%X)"
              % (tag_label, old_debug, new_debug))
    else:
        check(new_debug == old_debug, "%s: debug section before the tag area did not move" % tag_label)
    check(not [x for x in after.diag.warnings if "tag data area" in x or "outside" in x],
          "%s: no bounds warnings after growth (%s)" % (tag_label, after.diag.warnings))
    a = snapshot(after)
    check(a["names"] == before["names"], "%s: tag-name table still resolves" % tag_label)
    check(a["strings"] == before["strings"], "%s: string-id table still resolves" % tag_label)
    check(a["globals"] == before["globals"], "%s: global tag table still resolves" % tag_label)
    check(a["groups"] == before["groups"], "%s: tag group table still resolves" % tag_label)
    check([(t[0], t[1], t[3], t[4]) for t in a["tags"]] == [(t[0], t[1], t[3], t[4]) for t in before["tags"]],
          "%s: every tag still resolves to the same bytes" % tag_label)
    if mode == "end":
        check([t[2] for t in a["tags"]] == [t[2] for t in before["tags"]],
              "%s: tag addresses unchanged" % tag_label)
    else:
        check(after.virtual_base == cache.virtual_base - g.granted,
              "%s: virtual base moved down by the growth" % tag_label)
    check(rw.CacheWriter(after).verify_checksum()[2], "%s: checksum valid after growth" % tag_label)
    # the new space really is inside the tag area and really is free
    check(after.meta_offset <= g.free_offset < after.meta_offset + after.meta_size,
          "%s: new space is inside the tag area" % tag_label)
    check(out[g.free_offset:g.free_offset + g.granted] == b"\x00" * g.granted,
          "%s: new space is zeroed" % tag_label)
    check(w.expand(w.contract(g.free_address)) == g.free_address,
          "%s: the new space's address survives pointer contraction" % tag_label)
    return out


def test_relocate_tag(variant: rc.HeaderVariant, mode: str = "end"):
    data = fixture_debug_last(variant)
    cache = rc.ReachCacheFile(data)
    before = snapshot(cache)
    tag = next(t for t in cache.tags if t.group_code == "sqtm" and t.offset is not None)
    old = cache.tag_bytes(tag)
    grown = old + b"\x5A" * 0x80                       # the tag gets BIGGER
    w = rw.CacheWriter(cache)
    addr = w.relocate_tag(tag, grown, mode=mode,
                          page=rw.ALLOC_PAGE if mode == "end" else rw.SEGMENT_ALIGN)
    label = "%s/%s" % (variant.name, mode)
    after = rc.ReachCacheFile(w.bytes())
    moved = after.tags[tag.index]
    check(moved.address == addr, "%s: relocated tag's address is the new one" % label)
    check(after.tag_bytes(moved)[:len(grown)] == grown,
          "%s: relocated tag reads back its grown contents (0x%X -> 0x%X bytes)"
          % (label, len(old), len(grown)))
    others = [t for t in after.tags if t.index != tag.index and t.offset is not None]
    ref = {t[0]: t[4] for t in before["tags"]}
    check(all(bytes(after.tag_bytes(t))[:0x40] == ref[t.index] for t in others),
          "%s: every other tag still reads back unchanged" % label)
    check(after.tag_names == before["names"], "%s: tag names survive relocation" % label)
    check(rw.CacheWriter(after).verify_checksum()[2], "%s: checksum valid after relocation" % label)


def test_relocate_hsc_with_internal_pointer(variant: rc.HeaderVariant):
    """Grow a tag that contains a pointer into itself (the hsc* source pointer)."""
    data = fixture_debug_last(variant)
    cache = rc.ReachCacheFile(data)
    tag = next(t for t in cache.tags if t.group_code == "hsc*")
    name, source = rc.read_hsc_source(cache, tag)
    blob = bytearray(cache.tag_bytes(tag))
    new_source = (tpm.HSC_SOURCE + "(script static void fe_buy_marines (print \"bought\"))\n")
    blob[0x20:0x24] = struct.pack(variant.endian + "i", len(new_source) + 1)
    blob = bytes(blob[:0x30]) + new_source.encode("ascii") + b"\x00"
    w = rw.CacheWriter(cache)
    # the source pointer at 0x2C must be re-based onto the tag's new address
    growth_target = cache.meta_offset + cache.meta_size            # where mode="end" will put it
    fixed = w.shift_internal_pointers(blob, tag.address, w.address_of(growth_target), [0x2C])
    addr = w.relocate_tag(tag, fixed)
    check(addr == w.address_of(growth_target), "%s: hsc tag landed where predicted" % variant.name)
    after = rc.ReachCacheFile(w.bytes())
    name2, source2 = rc.read_hsc_source(after, after.tags[tag.index])
    check(name2 == name, "%s: hsc tag name survives the move" % variant.name)
    check(source2 == new_source,
          "%s: the GROWN script source reads back through the re-based pointer (%d -> %d bytes)"
          % (variant.name, len(source), len(new_source)))
    check(rw.CacheWriter(after).verify_checksum()[2], "%s: checksum valid after hsc growth" % variant.name)


def test_relocate_table(variant: rc.HeaderVariant):
    """Move the tag table itself: the pattern a script-table rewrite needs."""
    data = fixture_debug_last(variant)
    cache = rc.ReachCacheFile(data)
    before = snapshot(cache)
    e = variant.endian
    blob = bytearray()
    for t in cache.tags:
        blob += struct.pack(e + "hHI", t.group_index, t.salt, t.raw_address)
    w = rw.CacheWriter(cache)
    addr = w.relocate_table("tag_table_address", "tag_count", bytes(blob), len(cache.tags))
    after = rc.ReachCacheFile(w.bytes())
    check(after.index_header["tag_table_address"] == addr, "%s: tag table pointer updated" % variant.name)
    check(after.index_header["tag_count"] == len(cache.tags), "%s: tag count preserved" % variant.name)
    a = snapshot(after)
    check([(t[0], t[1], t[2], t[3]) for t in a["tags"]] == [(t[0], t[1], t[2], t[3]) for t in before["tags"]],
          "%s: every tag resolves identically from the moved table" % variant.name)
    check(rw.CacheWriter(after).verify_checksum()[2], "%s: checksum valid after table move" % variant.name)


def test_failure_paths():
    variant = rc.V_MCC_U8
    cache = rc.ReachCacheFile(fixture(variant))
    w = rw.CacheWriter(cache)
    tag = next(t for t in cache.tags if t.offset is not None)
    null_tag = next(t for t in cache.tags if t.offset is None)

    expect_raises(rw.WriteError, lambda: w.patch(len(w.buf) - 2, b"\x00" * 8),
                  "patch past EOF raises", "outside")
    expect_raises(rw.WriteError, lambda: w.patch_tag(null_tag, b"\x00"),
                  "patching a null tag raises", "no data")
    expect_raises(rw.WriteError, lambda: w.patch_tag(tag, b"\x00" * (tag.size + 1)),
                  "over-long in-tag patch raises", "estimated extent")
    expect_raises(rw.WriteError, lambda: w.grow_tag_area(0),
                  "zero growth raises", "positive")
    expect_raises(rw.WriteError, lambda: w.grow_tag_area(0x10, mode="sideways"),
                  "unknown growth mode raises", "mode must be")
    expect_raises(rw.WriteError, lambda: w.put_header("no_such_field", 1),
                  "unknown header field raises", "does not exist")
    expect_raises(rw.WriteError, lambda: w.put_index_field("no_such_field", 1),
                  "unknown index field raises", "unknown index header field")
    expect_raises(rw.WriteError, lambda: w.contract(variant.expand_magic - 4),
                  "address below the expand magic raises", "expand magic")
    expect_raises(rw.WriteError, lambda: w.contract(variant.expand_magic + 2),
                  "unaligned address raises", "aligned")
    expect_raises(rw.WriteError, lambda: w.contract(variant.expand_magic + (1 << 34)),
                  "address too large to contract raises", "does not fit")
    expect_raises(rw.WriteError, lambda: w.relocate_tag(null_tag, b"\x00" * 4),
                  "relocating a null tag raises", "no data")

    # growing downward until the virtual base would cross the expand magic
    low = rc.ReachCacheFile(fixture(variant))
    low_w = rw.CacheWriter(low)
    low_w.virtual_base = variant.expand_magic + 0x10
    expect_raises(rw.WriteError, lambda: low_w.grow_tag_area(0x10, mode="beginning"),
                  "downward growth that would underflow the expand magic raises", "expand magic")


def test_cli():
    variant = rc.V_MCC_U8
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "synthetic.map"
        p.write_bytes(fixture(variant))
        check(rw.main([str(p), "--verify-checksum"]) == 0, "CLI --verify-checksum exits 0 on a good file")
        check(rw.main([str(p), "--round-trip"]) == 0, "CLI --round-trip exits 0 on a good file")
        bad = bytearray(p.read_bytes())
        ck = variant.fields["checksum"][1]
        struct.pack_into("<I", bad, ck, 0xDEADBEEF)
        p.write_bytes(bytes(bad))
        check(rw.main([str(p), "--verify-checksum"]) == 1, "CLI reports a bad checksum")


def run():
    print("reach_write.py self-test  (SYNTHETIC CACHES ONLY - no real .map was involved)")
    for variant in rc.VARIANTS:
        print("-- %s" % variant.name)
        test_round_trip(variant)
        test_checksum(variant)
        test_same_size_patch(variant)
        for layout in ("debug-first", "debug-last"):
            for mode in ("end", "beginning"):
                test_growth(variant, layout, mode)
        test_relocate_tag(variant, "end")
        test_relocate_tag(variant, "beginning")
        test_relocate_hsc_with_internal_pointer(variant)
        test_relocate_table(variant)
    print("-- failure paths")
    test_failure_paths()
    print("-- CLI")
    test_cli()
    print("\n%d assertions, %d failures" % (PASS + FAIL, FAIL))
    for f in FAILURES:
        print("  - %s" % f)
    print("\nREMINDER: synthetic only. A writer that has never seen a real map is unproven.")
    return 1 if FAIL else 0


if __name__ == "__main__":
    raise SystemExit(run())
