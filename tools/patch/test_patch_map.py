#!/usr/bin/env python3
"""
test_patch_map.py -- self-test for the surgical patch tool.

SYNTHETIC ONLY. Every byte under test comes from ``tools/patch/fixture.py``.
No real Halo: Reach map is read, copied or opened by this suite, and none has
ever been seen by this project.

Run:  python3 tools/patch/test_patch_map.py
      python3 tools/patch/patch_map.py --self-test
"""

from __future__ import annotations

import hashlib
import io
import json
import struct
import sys
import tempfile
from contextlib import redirect_stdout
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent / "map"))
sys.path.insert(0, str(_HERE))

import reach_cache as rc                                   # noqa: E402
import reach_write as rw                                    # noqa: E402
import fixture                                              # noqa: E402
import patch_map as pm                                      # noqa: E402
import tagdefs                                              # noqa: E402
from tagdefs import TagDefs, DefsError                       # noqa: E402

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
    global PASS, FAIL
    try:
        fn()
    except exc_types as exc:
        if must_contain and must_contain.lower() not in str(exc).lower():
            check(False, "%s (raised, but message lacks %r: %s)" % (label, must_contain, exc))
        else:
            check(True, label)
        return
    except Exception as exc:                                # noqa: BLE001
        check(False, "%s (wrong exception %s: %s)" % (label, type(exc).__name__, exc))
        return
    check(False, "%s (no exception raised)" % label)


def sha(b):
    return hashlib.sha256(b).hexdigest()


# ---------------------------------------------------------------------------
# 1. the definition resolver
# ---------------------------------------------------------------------------

def test_defs():
    defs = TagDefs()
    ok, bad = defs.validate_all()
    check(len(ok) >= 390, "at least 390 structs validate against their own sizeof() (got %d)" % len(ok))
    check(len(bad) == len(tagdefs.KNOWN_BAD),
          "exactly the %d known-bad structs fail validation (got %d)" % (len(tagdefs.KNOWN_BAD), len(bad)))
    check(sorted(n for n, _ in bad) == sorted(tagdefs.KNOWN_BAD),
          "the failing structs are exactly the documented KNOWN_BAD list")
    for name in tagdefs.KNOWN_BAD:
        expect_raises(DefsError, lambda n=name: defs.fields_of(n),
                      "fields_of refuses non-validating struct %s" % name, "sizeof")
    check(defs.conflicts == [], "no definition conflicts between the dump files (%s)" % defs.conflicts)

    # the load-bearing scenario offsets, cross-checked against Assembly's
    # LayoutsU13 numbers quoted in research/13 section 4.1
    f = {fd.name: fd for fd in defs.fields_of("scenario_struct_definition")}
    for name, want in (("script string data", fixture.SCNR_SCRIPT_STRING),
                       ("scripts", fixture.SCNR_SCRIPTS),
                       ("globals", fixture.SCNR_GLOBALS),
                       ("hs syntax datums", fixture.SCNR_SYNTAX),
                       ("squads", fixture.SCNR_SQUADS)):
        check(f[name].offset == want,
              "scenario %r is at 0x%X (research/13 and the dump agree)" % (name, want))
    check(defs.struct_size("scenario_struct_definition") == fixture.SCNR_SIZE,
          "scenario struct is 0x%X bytes" % fixture.SCNR_SIZE)

    node = {fd.name: fd for fd in defs.fields_of("hs_syntax_datum_block")}
    check(defs.struct_size("hs_syntax_datum_block") == 0x18, "an expression node is 0x18 bytes")
    check(node["data"].offset == 0x10, "the node's value field `data` is at +0x10 (research/13)")
    check(node["line number"].offset == 0x14, "the node's `line number` is at +0x14")
    check(node["next node index"].offset == 0x08, "the node's `next node index` is at +0x08")
    check(node["datum header"].offset == 0x00, "the node's datum salt is at +0x00")

    script = {fd.name: fd for fd in defs.fields_of("hs_scripts_block")}
    check(defs.struct_size("hs_scripts_block") == 0x18, "a script element is 0x18 bytes")
    check(script["root expression index"].offset == 0x08, "script root expression index at +0x08")

    squad = {fd.name: fd for fd in defs.fields_of("squads_block_struct")}
    check(defs.struct_size("squads_block_struct") == 0x6C,
          "a scenario squad element is 0x6C bytes (research/07 section 10.1)")
    check(squad["squad template index"].runtime, "`squad template index!` is marked runtime")

    cell = {fd.name: fd for fd in defs.fields_of("cell_template_block_struct")}
    check(defs.struct_size("cell_template_block_struct") == fixture.SQTM_CELL_SIZE,
          "a sqtm cell template is 0x%X bytes" % fixture.SQTM_CELL_SIZE)
    check(cell["normal diff count"].offset == 0x10, "sqtm cell `normal diff count` at +0x10")
    check(cell["major upgrade"].offset == 0x12, "sqtm cell `major upgrade` at +0x12")

    spec = {fd.name: fd for fd in defs.fields_of("wave_squad_specification_struct_struct")}
    check(defs.struct_size("wave_squad_specification_struct_struct") == fixture.WAVE_SPEC_SIZE,
          "a wave squad specification is 0x24 bytes")
    check(spec["weight"].offset == 0x1C, "wave spec `weight` at +0x1C")
    check(spec["min spawn"].offset == 0x1E, "wave spec `min spawn` at +0x1E")
    check(spec["max spawn"].offset == 0x1F, "wave spec `max spawn` at +0x1F")
    check(spec["placement filter"].offset == 0x20, "wave spec `placement filter` at +0x20")

    smdt = {fd.name: fd for fd in defs.fields_of("survival_mode_globals_struct_definition")}
    check(smdt["wave templates"].offset == 0x40, "smdt `wave templates` block at +0x40")

    cond = {fd.name: fd for fd in defs.fields_of("ai_spawn_conditions_struct")}
    check(cond["round range"].offset == 0x04 and cond["set range"].offset == 0x08,
          "ai_spawn_conditions: round range +0x04, set range +0x08")
    check(defs.enum_label("major_upgrade_enum", 1) == "few", "enum labels resolve (major upgrade 1 = few)")
    check(defs.flag_labels("global_campaign_difficulty_enum", 0x5) == "easy|heroic",
          "flag labels resolve (0x5 = easy|heroic)")
    return defs


# ---------------------------------------------------------------------------
# 2. the fixture parses
# ---------------------------------------------------------------------------

def test_fixture(variant):
    data = fixture.build(variant)
    marks = dict(fixture.LANDMARKS)
    cache = rc.ReachCacheFile(data, path="fixture.map")
    check(cache.variant.name == variant.name, "%s: fixture detected as %s" % (variant.name, variant.name))
    tolerated = [w for w in cache.diag.warnings if "namespace table" in w]
    check(not (set(cache.diag.warnings) - set(tolerated)),
          "%s: fixture parses with no unexpected warnings (%s)"
          % (variant.name, cache.diag.warnings))
    if variant.field("string_namespace_table_count"):
        check(cache.diag.warnings == [],
              "%s: this layout has a namespace table, so there is no namespace warning" % variant.name)
    else:
        check(len(tolerated) == 1,
              "%s: this layout has no namespace table field, so the reader warns about it" % variant.name)
    check(len(cache.tags) == len(fixture.TAGS), "%s: all %d tags present" % (variant.name, len(fixture.TAGS)))
    check([t.group_code for t in cache.tags] == [g for g, _ in fixture.TAGS],
          "%s: tag groups in order" % variant.name)
    stored, computed, ok = rw.CacheWriter(cache).verify_checksum()
    check(stored == 0, "%s: the fixture ships a zeroed checksum, like MCC does" % variant.name)
    check(computed == rw.checksum_of(data, variant.header_size, variant.endian),
          "%s: checksum_of agrees with the writer" % variant.name)
    return cache, marks


# ---------------------------------------------------------------------------
# 3. find
# ---------------------------------------------------------------------------

def test_find(defs, cache, marks):
    scan = pm.scan_cache(cache, defs)
    by_off = {c.offset: c for c in scan.candidates}

    price = by_off.get(marks["price_node_value"])
    check(price is not None, "the price node's value field is found")
    check(price.value == 500, "the price reads 500")
    check(price.patchable, "the price is patchable (%s)" % price.refusal)
    check("ff_buy_marines" in price.context, "the price carries its enclosing script name")
    check("line 42" in price.context, "the price carries its source line number")
    check("short constant" in price.context, "the price is labelled a short constant")
    check("exact" in price.context, "the price was attributed to its script exactly, not by range")
    check(price.selector == "scnr[0]/hs syntax datums[8]/data",
          "the price's selector is stable and readable: %s" % price.selector)

    gate = by_off.get(marks["gate_node_value"])
    check(gate is not None and gate.value == 3 and gate.patchable, "the round-gate constant is found")
    check("ff_round_gate" in gate.context, "the round gate names its script")
    cool = by_off.get(marks["cooldown_node_value"])
    check(cool is not None and cool.patchable, "the real-valued cooldown constant is found")
    check("real constant = 30" in cool.label, "a real constant is decoded as a float: %s" % cool.label)
    cap = by_off.get(marks["cap_node_value"])
    check(cap is not None and cap.value == 2 and cap.patchable, "the concurrent-cap constant is found")
    squad_ref = by_off.get(marks["squad_ref_node_value"])
    check(squad_ref is not None and squad_ref.patchable, "the squad-reference node value is found")
    check("ai constant" in squad_ref.context, "the squad-reference node is typed `ai`")

    # structural node fields must be refused
    nxt = by_off.get(marks["node_next_0"])
    check(nxt is not None and not nxt.patchable, "a node's `next node index` is refused")
    check("rewires" in (nxt.refusal or ""), "the refusal for `next` explains the rewiring risk")
    group_data = by_off.get(marks["nodes_off"] + 0x10)
    check(group_data is not None and not group_data.patchable,
          "a group node's `data` (a child link) is refused")
    check("group" in (group_data.refusal or ""), "the group-node refusal says it is a group")

    cell = by_off.get(marks["sqtm0_cell0_count"])
    check(cell is not None and cell.value == 3 and cell.patchable, "a sqtm cell count is found")
    check(cell.selector == "sqtm[2]/cell templates[0]/normal diff count",
          "the cell count's selector is readable: %s" % cell.selector)
    check("initial number of actors" in cell.label, "the cell count carries the dump's own comment")
    rr = by_off.get(marks["sqtm0_cell0_round_lower"])
    check(rr is not None and rr.value == 2 and rr.patchable, "a sqtm round-range bound is found")
    chance = by_off.get(marks["sqtm0_cell0_choice0_chance"])
    check(chance is not None and chance.value == 70 and chance.patchable, "a character chance is found")
    cdatum = by_off.get(marks["sqtm0_cell0_choice0_datum"])
    check(cdatum is not None and cdatum.patchable, "a character tag_reference datum is patchable")
    check("-> tag 5 char" in cdatum.label, "the tag reference resolves its target: %s" % cdatum.label)
    name_sid = by_off.get(marks["sqtm0_name_sid"])
    check(name_sid is not None and "ff_marines_light" in name_sid.label,
          "a string-id field resolves to its text: %s" % (name_sid and name_sid.label))

    blockcount = by_off.get(marks["sqtm0_cells_blockcount"])
    check(blockcount is not None and not blockcount.patchable, "a block count is refused")
    check("count" in (blockcount.refusal or "") and "offset" in (blockcount.refusal or ""),
          "the block-count refusal names counts and offsets")

    weight = by_off.get(marks["wave_spec0_weight"])
    check(weight is not None and weight.value == 50 and weight.patchable, "a wave weight is found")
    mn = by_off.get(marks["wave_spec0_min_spawn"])
    mx = by_off.get(marks["wave_spec0_max_spawn"])
    check(mn is not None and mn.value == 1 and mn.width == 1, "wave `min spawn` is a 1-byte field")
    check(mx is not None and mx.value == 2 and mx.width == 1, "wave `max spawn` is a 1-byte field")
    sq = by_off.get(marks["wave_spec0_sqtm_datum"])
    check(sq is not None and sq.patchable and "sqtm" in sq.label,
          "a wave's squad-template datum is patchable and names its target")
    smdt_sid = by_off.get(marks["smdt_wave0_sid"])
    check(smdt_sid is not None and "wave_marines" in smdt_sid.label, "an smdt wave name resolves")

    check(all(c.offset in by_off for c in scan.candidates), "every candidate is addressable")
    check(len({c.selector for c in scan.candidates}) == len(scan.candidates),
          "every selector is unique")
    check(sum(1 for c in scan.candidates if c.patchable) > 100,
          "more than 100 patchable values were found (%d)"
          % sum(1 for c in scan.candidates if c.patchable))
    check(any("attributed exactly" in n for n in scan.notes), "the scan reports its attribution count")
    return scan


# ---------------------------------------------------------------------------
# 4. patch round trip
# ---------------------------------------------------------------------------

def test_round_trip(defs, cache, marks):
    scan = pm.scan_cache(cache, defs)
    req = pm.parse_set("scnr[0]/hs syntax datums[8]/data=250")
    plan = pm.plan_patch(cache, scan, req)
    check(plan.old_value == 500 and plan.new_value == 250, "plan records old and new values")
    check(len(plan.old_bytes) == len(plan.new_bytes) == 4, "the write is the same size as the field")
    result = pm.build_patched(cache, scan, [plan], defs)
    check(len(result.data) == len(cache.data), "the patched file is exactly the same length")

    ck_kind, ck_off = cache.variant.fields["checksum"]
    changed = set()
    for (off, old, new) in result.diff:
        changed.update(range(off, off + len(old)))
    allowed = set(range(plan.cand.offset, plan.cand.offset + 4)) | set(range(ck_off, ck_off + 4))
    check(changed <= allowed, "only the patched field and the checksum changed (%s)"
          % sorted(hex(c) for c in (changed - allowed)))
    check(changed & set(range(plan.cand.offset, plan.cand.offset + 4)),
          "the patched field really did change")
    check(changed & set(range(ck_off, ck_off + 4)), "the checksum really did change")

    re_cache = result.reparsed
    check(re_cache.diag.warnings == cache.diag.warnings, "the re-parse produces no new warnings")
    rescan = pm.scan_cache(re_cache, defs)
    again = rescan.by_selector[plan.cand.selector]
    check(again.value == 250, "the new value reads back through the same selector")
    check("line 42" in again.context, "the context survives the patch")

    # nothing else in any tag moved or changed
    for t_old, t_new in zip(cache.tags, re_cache.tags):
        check(t_old.address == t_new.address and t_old.offset == t_new.offset,
              "tag %d did not move" % t_old.index)
    for t_old, t_new in zip(cache.tags, re_cache.tags):
        if t_old.group_code == "scnr":
            continue
        check(cache.tag_bytes(t_old) == re_cache.tag_bytes(t_new),
              "tag %d (%s) is byte-identical" % (t_old.index, t_old.group_code))
    check(cache.header["virtual_size"] == re_cache.header["virtual_size"],
          "the tag area size is unchanged")
    check(cache.meta_offset == re_cache.meta_offset, "the tag area did not move")
    stored, computed, ok = rw.CacheWriter(re_cache).verify_checksum()
    check(ok, "the patched file's stored checksum matches its recomputed checksum")
    check(computed == result.checksum_after, "the recorded checksum is the one in the file")
    return result


def test_multi_patch(defs, cache, marks):
    scan = pm.scan_cache(cache, defs)
    sets = [
        "scnr[0]/hs syntax datums[8]/data=1000",                           # price
        "scnr[0]/hs syntax datums[19]/data=2",                             # round gate
        "scnr[0]/hs syntax datums[12]/data=4",                             # concurrent cap
        "sqtm[2]/cell templates[0]/normal diff count=5",                   # squad size
        "sqtm[2]/cell templates[0]/place on/round range.lower=1",          # round gate in sqtm
        "wave[4]/squad specifications[0]/weight=90",                       # wave weighting
        "wave[4]/squad specifications[0]/min spawn=2",                     # 1-byte field
        "wave[4]/squad specifications[0]/squad template.datum=3",          # retarget a squad
        "sqtm[2]/cell templates[1]/major upgrade=3",                       # an enum
    ]
    plans = [pm.plan_patch(cache, scan, pm.parse_set(s)) for s in sets]
    result = pm.build_patched(cache, scan, plans, defs)
    check(len(result.plans) == len(sets), "all %d patches planned" % len(sets))
    rescan = pm.scan_cache(result.reparsed, defs)
    expect = {"scnr[0]/hs syntax datums[8]/data": 1000,
              "scnr[0]/hs syntax datums[19]/data": 2,
              "scnr[0]/hs syntax datums[12]/data": 4,
              "sqtm[2]/cell templates[0]/normal diff count": 5,
              "sqtm[2]/cell templates[0]/place on/round range.lower": 1,
              "wave[4]/squad specifications[0]/weight": 90,
              "wave[4]/squad specifications[0]/min spawn": 2,
              "wave[4]/squad specifications[0]/squad template.datum": 3,
              "sqtm[2]/cell templates[1]/major upgrade": 3}
    for sel, want in expect.items():
        got = rescan.by_selector[sel].value
        check(got == want, "%s reads back %r (wanted %r)" % (sel, got, want))
    check(rescan.by_selector["sqtm[2]/cell templates[1]/major upgrade"].label.startswith("none"),
          "the patched enum now labels itself 'none'")
    check("ff_marines_heavy" in rescan.by_selector["wave[4]/squad specifications[0]/squad template.datum"].label,
          "the retargeted wave entry now names the other squad template")
    changed = set()
    for (off, old, _new) in result.diff:
        changed.update(range(off, off + len(old)))
    allowed = set()
    for p in result.plans:
        allowed |= set(range(p.cand.offset, p.cand.offset + p.cand.width))
    ck_kind, ck_off = cache.variant.fields["checksum"]
    allowed |= set(range(ck_off, ck_off + 4))
    check(changed <= allowed, "nine patches changed only their own bytes plus the checksum")
    return result


def test_float_patch_real(defs, cache, marks):
    scan = pm.scan_cache(cache, defs)
    req = pm.parse_set("@0x%X:f32=12.5" % marks["cooldown_node_value"])
    plan = pm.plan_patch(cache, scan, req)
    check(plan.kind == "f32", "a real constant can be written as f32 at the same width")
    result = pm.build_patched(cache, scan, [plan], defs)
    got = struct.unpack_from(cache.endian + "f", result.data, marks["cooldown_node_value"])[0]
    check(abs(got - 12.5) < 1e-6, "the float cooldown reads back as 12.5 (got %r)" % got)
    check(len(result.data) == len(cache.data), "the float patch did not change the file length")


# ---------------------------------------------------------------------------
# 5. refusals
# ---------------------------------------------------------------------------

def test_refusals(defs, cache, marks):
    scan = pm.scan_cache(cache, defs)

    def attempt(spec, **kw):
        return lambda: pm.plan_patch(cache, scan, pm.parse_set(spec), **kw)

    expect_raises(pm.Refused, attempt("sqtm[2]/cell templates[0]/normal diff count:i32=5"),
                  "refuses a wider write to a 2-byte field", "size-changing")
    expect_raises(pm.Refused, attempt("wave[4]/squad specifications[0]/min spawn:i16=5"),
                  "refuses a 2-byte write to a 1-byte field", "size-changing")
    expect_raises(pm.Refused, attempt("scnr[0]/hs syntax datums.count=5"),
                  "refuses a block count", "count")
    expect_raises(pm.Refused, attempt("scnr[0]/hs syntax datums.address=5"),
                  "refuses a block address", "offset")
    expect_raises(pm.Refused, attempt("sqtm[2]/cell templates.count=1"),
                  "refuses the cell-template block count", "addressed by position")
    expect_raises(pm.Refused, attempt("scnr[0]/scripts[0]/root expression index=4"),
                  "refuses a script's root expression index", "indexed through it")
    expect_raises(pm.Refused, attempt("scnr[0]/hs syntax datums[8]/next node index=0"),
                  "refuses a node's next-node link", "sibling chain")
    expect_raises(pm.Refused, attempt("scnr[0]/hs syntax datums[8]/datum header=1"),
                  "refuses a node's datum salt", "orphans nodes")
    expect_raises(pm.Refused, attempt("scnr[0]/hs syntax datums[8]/type=8"),
                  "refuses a node's value type", "reinterpret")
    expect_raises(pm.Refused, attempt("scnr[0]/hs syntax datums[8]/source_offset=0"),
                  "refuses a node's source offset", "offset")
    expect_raises(pm.Refused, attempt("scnr[0]/hs syntax datums[0]/data=7"),
                  "refuses a group node's child link", "group")
    expect_raises(pm.Refused, attempt("scnr[0]/hs syntax datums[1]/data=7"),
                  "refuses a function_name node's opcode", "function index")
    expect_raises(pm.Refused, attempt("scnr[0]/squads[0]/squad template index=7"),
                  "refuses a runtime-derived index", "derives")
    expect_raises(pm.Refused, attempt("scnr[0]/script string data.size=8"),
                  "refuses a data reference's size", "length or")
    expect_raises(pm.Refused, attempt("scnr[0]/squads[0]/name=1"),
                  "refuses a text field", "numeric")
    expect_raises(pm.Refused, attempt("sqtm[2]/cell templates[0]/normal diff count=70000"),
                  "refuses a value too large for the field", "does not fit")
    expect_raises(pm.Refused, attempt("wave[4]/squad specifications[0]/min spawn=200"),
                  "refuses a value too large for a signed byte", "does not fit")
    expect_raises(pm.Refused, attempt("sqtm[2]/cell templates[0]/activity name=0x7FFF"),
                  "refuses a string-id that is not in this cache", "does not resolve")
    expect_raises(pm.Refused, attempt("wave[4]/squad specifications[0]/squad template.datum=99"),
                  "refuses a tag datum that is not a live tag", "not a live tag")
    expect_raises(pm.Refused, attempt("sqtm[2]/cell templates[0]/character type[0]/character type.name_address=0"),
                  "refuses a tag reference's name pointer", "structural")
    expect_raises(pm.Refused, attempt("@0x100=5", allow_unmapped=False),
                  "refuses a raw offset no definition describes", "cannot be checked")
    expect_raises(pm.Refused, attempt("@0x100:i16=5", allow_unmapped=True),
                  "refuses an unmapped offset outside every tag", "not inside any tag")
    expect_raises(pm.PatchError, attempt("@0x%X=5" % marks["price_node_value"] + "x"),
                  "rejects a value it cannot read as a number")
    expect_raises(pm.PatchError, lambda: pm.parse_set("no-equals-sign"),
                  "rejects a --set without an '='", "SELECTOR=VALUE")
    expect_raises(pm.PatchError, lambda: pm.plan_patch(cache, scan, pm.parse_set("nope[0]/field=1")),
                  "rejects an unknown selector", "no such selector")
    expect_raises(pm.PatchError, lambda: pm.parse_set("@0x10:nope=1"),
                  "rejects an unknown kind", "unknown kind")

    # an unmapped but in-tag offset is permitted with the explicit flag
    pad = marks["nodes_off"] - 2          # padding between the string blob and the nodes
    check(scan.at(pad) is None, "the chosen raw offset is genuinely unmapped")
    ok_plan = pm.plan_patch(cache, scan, pm.parse_set("@0x%X:i16=9" % pad), allow_unmapped=True)
    check(ok_plan.cand.struct == "<unmapped>", "--allow-unmapped permits a named-kind raw write")
    check(ok_plan.cand.width == 2, "the raw write keeps the kind's width")

    # overlapping patches
    a = pm.plan_patch(cache, scan, pm.parse_set("scnr[0]/hs syntax datums[8]/data=1"))
    b = pm.plan_patch(cache, scan, pm.parse_set("@0x%X:i16=2" % (marks["price_node_value"] + 2)),
                      allow_unmapped=True)
    expect_raises(pm.Refused, lambda: pm.build_patched(cache, scan, [a, b], defs),
                  "refuses two patches that overlap", "overlap")

    # a write that would leave the tag's extent
    victim = [t for t in cache.tags if t.group_code == "char"][0]
    far = victim.offset + (victim.size or 0) - 1
    expect_raises(pm.Refused,
                  lambda: pm.build_patched(cache, scan,
                                           [pm.plan_patch(cache, scan,
                                                          pm.parse_set("@0x%X:i32=1" % far),
                                                          allow_unmapped=True)], defs),
                  "refuses a write that runs past the tag's estimated extent", "extent")


def test_verification_guards(defs, cache, marks):
    """Prove the post-write checks really do refuse, by sabotaging the writer."""
    scan = pm.scan_cache(cache, defs)
    plan = pm.plan_patch(cache, scan, pm.parse_set("scnr[0]/hs syntax datums[8]/data=7"))
    original = rw.CacheWriter.update_checksum

    def scribble(self):
        self.buf[cache.meta_offset + 0x900] ^= 0xFF           # a stray byte nobody asked for
        return original(self)

    rw.CacheWriter.update_checksum = scribble
    try:
        expect_raises(pm.Refused, lambda: pm.build_patched(cache, scan, [plan], defs),
                      "refuses to emit when an unrequested byte changed", "not asked for")
    finally:
        rw.CacheWriter.update_checksum = original

    def wreck_index(self):
        spec = self.v.index_header
        ioff = self.offset_of(self.header["index_header_address"])
        self.buf[ioff + spec.magic:ioff + spec.magic + 4] = b"junk"
        return original(self)

    rw.CacheWriter.update_checksum = wreck_index
    try:
        expect_raises(pm.Refused, lambda: pm.build_patched(cache, scan, [plan], defs),
                      "refuses to emit a file that will not re-parse", "re-parse")
    finally:
        rw.CacheWriter.update_checksum = original

    def shrink(self):
        del self.buf[-4:]
        return original(self)

    rw.CacheWriter.update_checksum = shrink
    try:
        expect_raises((pm.Refused, pm.PatchError),
                      lambda: pm.build_patched(cache, scan, [plan], defs),
                      "refuses to emit a file whose length changed")
    finally:
        rw.CacheWriter.update_checksum = original

    # and the clean path still works after the sabotage is removed
    result = pm.build_patched(cache, scan, [plan], defs)
    check(len(result.data) == len(cache.data), "the clean path still works after the guards fired")


# ---------------------------------------------------------------------------
# 6. manifest, apply, revert
# ---------------------------------------------------------------------------

def test_apply_and_revert(defs, variant):
    tmp = Path(tempfile.mkdtemp(prefix="ffpatch-"))
    src = tmp / "fixture.map"
    data = fixture.build(variant)
    marks = dict(fixture.LANDMARKS)
    src.write_bytes(data)
    out = tmp / "fixture.patched.map"
    man = tmp / "changeset.json"

    argv = [str(src), "--set", "scnr[0]/hs syntax datums[8]/data=750",
            "--set", "sqtm[2]/cell templates[0]/normal diff count=4",
            "--out", str(out), "--manifest", str(man), "--apply"]
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main(argv)
    check(code == pm.EXIT_OK, "apply exits 0")
    check(out.is_file(), "the output map was written")
    check(man.is_file(), "the manifest was written")
    check((tmp / "fixture.map.bak").is_file(), "the input was backed up to .bak")
    check(src.read_bytes() == data, "the input file is untouched, byte for byte")
    check(len(out.read_bytes()) == len(data), "the output is the same length as the input")

    m = json.loads(man.read_text())
    check(m["format"] == pm.MANIFEST_FORMAT, "the manifest records its format version")
    check(len(m["patches"]) == 2, "the manifest records both patches")
    rec = m["patches"][0]
    for key in ("selector", "file_offset", "meta_address", "old_value", "new_value",
                "old_bytes", "new_bytes", "kind", "tag", "field"):
        check(key in rec, "the manifest records %s" % key)
    check(rec["old_value"] == 500 and rec["new_value"] == 750, "the manifest records old and new")
    check(rec["file_offset"] == marks["price_node_value"], "the manifest records the address")
    check(m["input"]["sha256"] == sha(data), "the manifest records the input's sha256")
    check(m["output"]["sha256"] == sha(out.read_bytes()), "the manifest records the output's sha256")
    check("created" in m and m["created"].startswith("20"), "the manifest is timestamped")
    check("synthetic" in json.dumps(m).lower(), "the manifest carries the synthetic-only warning")

    # dry-run revert writes nothing
    rev_out = tmp / "reverted.map"
    res = pm.revert(man, out=rev_out, apply=False)
    check(not rev_out.exists(), "a dry-run revert writes nothing")
    check(res["identical"], "the dry-run revert reproduces the original bytes exactly")

    res = pm.revert(man, out=rev_out, apply=True)
    check(rev_out.is_file(), "the applied revert wrote the file")
    check(rev_out.read_bytes() == data, "the reverted file is byte-identical to the original input")
    check(sha(rev_out.read_bytes()) == m["input"]["sha256"], "and its sha256 matches the manifest")
    check(len(res["lines"]) == 3, "the revert reports both undone patches and the checksum")
    check(res["stored"] == 0, "the restored checksum field is the original zero")
    m2 = json.loads(man.read_text())
    check(m2["checksum"]["old_bytes"] == "00000000",
          "the manifest recorded the original (zeroed) checksum bytes")
    check(m2["checksum"]["new_bytes"] != "00000000", "and the patched checksum bytes")

    # the CLI revert path
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main(["--revert", str(man), "--out", str(tmp / "r2.map"), "--apply"])
    check(code == pm.EXIT_OK and (tmp / "r2.map").read_bytes() == data,
          "the --revert CLI restores the original bytes")

    # refusing to overwrite without --force
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(src), "--set", "scnr[0]/hs syntax datums[8]/data=751",
                        "--out", str(out), "--manifest", str(man), "--apply"])
    check(code == pm.EXIT_REFUSED, "refuses to overwrite an existing output without --force")
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(src), "--set", "scnr[0]/hs syntax datums[8]/data=751",
                        "--out", str(out), "--manifest", str(man), "--apply", "--force"])
    check(code == pm.EXIT_OK, "--force replaces it")
    check((tmp / "fixture.patched.map.bak").is_file(), "the replaced output was backed up first")
    check((tmp / "changeset.json.bak").is_file(), "the replaced manifest was backed up first")

    # refusing to write in place
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(src), "--set", "scnr[0]/hs syntax datums[8]/data=752",
                        "--out", str(src), "--apply"])
    check(code == pm.EXIT_REFUSED, "refuses --out equal to the input")
    return tmp, man, out, data


def test_manifest_errors(tmp, man, out, data):
    good = json.loads(man.read_text())

    def write(obj, name="bad.json"):
        p = tmp / name
        p.write_text(obj if isinstance(obj, str) else json.dumps(obj))
        return p

    expect_raises(pm.ManifestError, lambda: pm.load_manifest(tmp / "nope.json"),
                  "a missing manifest is a clean error", "does not exist")
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write("{not json")),
                  "unreadable JSON is a clean error", "not readable json")
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write("[1,2,3]")),
                  "a JSON array is a clean error", "not a json object")
    bad = dict(good); bad["format"] = 99
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "a wrong format version is a clean error", "format")
    bad = dict(good); bad.pop("patches")
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "a missing patches section is a clean error", "no 'patches'")
    bad = json.loads(json.dumps(good)); bad["patches"] = []
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "an empty patch list is a clean error", "nothing to revert")
    bad = json.loads(json.dumps(good)); bad["patches"][0].pop("old_bytes")
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "a patch missing old_bytes is a clean error", "old_bytes")
    bad = json.loads(json.dumps(good)); bad["patches"][0]["old_bytes"] = "zz01"
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "non-hex bytes are a clean error", "unreadable hex")
    bad = json.loads(json.dumps(good)); bad["patches"][0]["old_bytes"] = "0102"
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "old/new byte lengths that differ are a clean error", "equal lengths")
    bad = json.loads(json.dumps(good)); bad["patches"][0]["file_offset"] = -1
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "a negative offset is a clean error", "bad file_offset")
    bad = json.loads(json.dumps(good)); bad["input"]["sha256"] = "short"
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "a truncated sha256 is a clean error", "sha256")

    bad = json.loads(json.dumps(good)); bad["checksum"]["old_bytes"] = "01"
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "a checksum record with mismatched byte lengths is a clean error", "must match")
    bad = json.loads(json.dumps(good)); bad["checksum"]["offset"] = "nope"
    expect_raises(pm.ManifestError, lambda: pm.load_manifest(write(bad)),
                  "a checksum record with a bad offset is a clean error", "bad offset")

    # a manifest that no longer matches its target
    tampered = tmp / "tampered.map"
    blob = bytearray(out.read_bytes())
    blob[-8] ^= 0xFF
    tampered.write_bytes(bytes(blob))
    expect_raises(pm.ManifestError,
                  lambda: pm.revert(man, target=tampered, out=tmp / "x.map", apply=False),
                  "refuses to revert a file whose sha256 moved", "does not match the manifest")

    # a manifest whose recorded patch is not actually present
    recorded = json.loads(json.dumps(good))
    recorded["patches"][0]["new_bytes"] = "deadbeef"
    recorded["output"]["sha256"] = sha(out.read_bytes())
    p = write(recorded, "mismatch.json")
    expect_raises(pm.ManifestError,
                  lambda: pm.revert(p, target=out, out=tmp / "y.map", apply=False),
                  "refuses to revert when the file does not hold the recorded new bytes",
                  "does not match its manifest")

    # exit codes through the CLI
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main(["--revert", str(tmp / "bad.json")])
    check(code == pm.EXIT_MANIFEST, "a corrupt manifest exits %d" % pm.EXIT_MANIFEST)


# ---------------------------------------------------------------------------
# 7. CLI smoke
# ---------------------------------------------------------------------------

def test_cli(defs, variant):
    tmp = Path(tempfile.mkdtemp(prefix="ffpatch-cli-"))
    src = tmp / "f.map"
    src.write_bytes(fixture.build(variant))
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(src), "--find"])
    text = buf.getvalue()
    check(code == pm.EXIT_OK, "find exits 0")
    check("ff_buy_marines" in text, "find prints the script name")
    check("normal diff count" in text, "find prints squad cell counts")
    check("SYNTHETIC-ONLY" in text, "find prints the synthetic-only warning")
    check("500" in text, "find prints the price")
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(src), "--find", "--grep", "min spawn"])
    check("min spawn" in buf.getvalue() and "normal diff count" not in buf.getvalue(),
          "--grep filters the listing")
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(src), "--find", "--all"])
    check("REFUSED" in buf.getvalue(), "--all shows refused fields and their reasons")
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(src), "--set", "scnr[0]/hs syntax datums[8]/data=600"])
    check(code == pm.EXIT_OK and "DRY RUN" in buf.getvalue(), "a patch is a dry run by default")
    check(not (tmp / "f.patched.map").exists(), "the dry run wrote nothing")
    buf = io.StringIO()
    err = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(src), "--set", "scnr[0]/hs syntax datums.count=2"])
    check(code == pm.EXIT_REFUSED, "a refused patch exits %d" % pm.EXIT_REFUSED)
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = pm.main([str(tmp / "missing.map"), "--find"])
    check(code == pm.EXIT_USAGE, "a missing map exits %d" % pm.EXIT_USAGE)


# ---------------------------------------------------------------------------

def run():
    print("patch_map self-test -- SYNTHETIC ONLY, no real map involved")
    print()
    print("[1] tag definition resolver")
    defs = test_defs()
    variants = [rc.V_MCC_U8, rc.V_MCC_U3, rc.V_MCC_2019]
    for v in variants:
        print("[2] fixture, header layout %s" % v.name)
        cache, marks = test_fixture(v)
        print("[3] find")
        test_find(defs, cache, marks)
        print("[4] patch round trip")
        test_round_trip(defs, cache, marks)
        test_multi_patch(defs, cache, marks)
        test_float_patch_real(defs, cache, marks)
        print("[5] refusals")
        test_refusals(defs, cache, marks)
        test_verification_guards(defs, cache, marks)
    print("[6] apply, manifest, revert")
    tmp, man, out, data = test_apply_and_revert(defs, rc.V_MCC_U8)
    print("[7] corrupt manifests")
    test_manifest_errors(tmp, man, out, data)
    print("[8] CLI")
    test_cli(defs, rc.V_MCC_U8)
    print()
    print("%d assertions passed, %d failed" % (PASS, FAIL))
    if FAILURES:
        for f in FAILURES:
            print("  - %s" % f)
        return 1
    print("SYNTHETIC-ONLY: these assertions prove internal consistency against fixtures this "
          "project generated. They do not prove that a real Halo: Reach map has these offsets, "
          "and they do not prove MCC loads the output.")
    return 0


if __name__ == "__main__":
    sys.exit(run())
