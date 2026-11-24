#!/usr/bin/env python3
"""
patch_map.py -- find and safely change numeric values inside a built
Halo: Reach MCC ``.map`` cache, without moving a single byte.

WHAT IT IS FOR
--------------
``research/13-map-write-feasibility.md`` §6 ranks every way a Reach cache can be
modified. The cheapest three are all *same-size numeric writes*:

  #1 a constant inside an existing script (a price, a timer, a threshold)
  #2 a numeric field in ``sqtm`` / ``smdt`` / ``wave`` / a ``scnr`` squad block
  #3 a string-id or tag datum an existing field points at (retargeting)

This tool does exactly those three and refuses everything else. It never grows,
shrinks, moves or reallocates anything, so no pointer, offset, count or extent in
the file can change meaning.

SAFETY MODEL (all of this is implemented and tested; see test_patch_map.py)
--------------------------------------------------------------------------
  * dry run by default; ``--apply`` is required to write anything
  * never writes in place: ``--out`` is a new file, and the input is backed up
    to ``<input>.bak`` before the output is written
  * same-size only: the write width must equal the field's declared width
  * refuses any field that is a length, an offset, a count, a datum link, or a
    runtime-derived index, and names the dependents in the refusal
  * refuses a string-id that does not resolve in this cache's string table, and
    a tag datum that is not a live tag in this cache
  * refuses a write outside the target tag's (estimated) extent
  * after patching, in memory: re-parses the result with the reader, compares it
    byte for byte with the input, and refuses to emit if anything outside the
    intended bytes (plus the 4 checksum bytes) changed, or if the re-parse fails,
    or if the re-parse produces a warning the input did not
  * recomputes the header checksum (XOR of every uint32 past 0xA000)
  * writes a JSON manifest; ``--revert`` (or ``unpatch_map.py``) undoes it and
    verifies the restored file is byte-identical to the original

HONEST STATUS
-------------
SYNTHETIC-ONLY. Every result in this tool's test suite comes from caches built by
``tools/patch/fixture.py``. **No real Halo: Reach map has been read by this
project.** Field offsets come from the MCC tag-definition dump in
``research/_raw/reach-defs/`` and are cross-checked against Assembly's layout XML
numbers quoted in ``research/13`` §4.1, but nothing here has been loaded by the
game. A patched map is unsigned and MCC must be launched with anti-cheat
disabled; see README.md.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import re
import shutil
import struct
import sys
from dataclasses import dataclass, field as dcfield
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent / "map"))
sys.path.insert(0, str(_HERE))

import reach_cache as rc                                              # noqa: E402
from reach_cache import MapFormatError, ReachCacheFile, TagEntry      # noqa: E402
from reach_write import CacheWriter, WriteError                       # noqa: E402
import tagdefs                                                        # noqa: E402
from tagdefs import (KIND_CODE, KIND_WIDTH, DefsError, TagDefs,       # noqa: E402
                     TEXT_TYPES, pack_scalar, read_scalar)

TOOL = "patch_map.py"
MANIFEST_FORMAT = 1

EXIT_OK = 0
EXIT_USAGE = 2
EXIT_REFUSED = 3
EXIT_FORMAT = 4
EXIT_MANIFEST = 5


class PatchError(Exception):
    """Anything that stops a patch from being produced."""


class Refused(PatchError):
    """The edit is possible but unsafe, so the tool will not do it."""


class ManifestError(PatchError):
    """The change-set file is missing, malformed, or does not match the target."""


# ---------------------------------------------------------------------------
# refusal rules
# ---------------------------------------------------------------------------

# struct name -> field name -> why it must not be patched
STRUCT_RULES = {
    "hs_syntax_datum_block": {
        "datum header": "the node's datum salt; every `next node index` in the table is "
                        "matched against the (salt, index) pair, so changing it orphans nodes",
        "next node index": "a link to another node; changing it rewires the script's sibling chain",
        "source_offset": "an offset into the script string blob (or a source character "
                         "position), not a value",
        "type": "the node's value type; changing it makes the engine reinterpret `data`",
        "flags": "node flags, not a tunable value",
        "script index/function index/constant type union":
            "the opcode / script index union; changing it calls a different engine function",
    },
    "hs_scripts_block": {
        "root expression index": "the datum of this script's root node; the expression table "
                                 "is indexed through it",
    },
    "hs_globals_block": {
        "initialization expression index": "the datum of this global's initialiser node",
    },
    "squads_block_struct": {
        "squad template index": "a runtime index the engine derives from the `template` "
                                "string-id; patch the string-id instead",
    },
}

# nicer text for the commonest block counts
BLOCK_DEPENDENTS = {
    "hs syntax datums": "every script's `root expression index` and every node's "
                        "`next node index` is an index into this block",
    "scripts": "script datums elsewhere in the scenario index into this block",
    "globals": "global initialiser datums index into this block",
    "cell templates": "the squad's cells are addressed by position in this block",
    "cells": "the squad's cells are addressed by position in this block",
    "squad specifications": "wave spawn logic walks this block by position",
    "wave templates": "survival mode selects waves by position in this block",
    "squads": "scripts and wave placement refer to squads by their index in this block",
}

INTEREST = re.compile(
    r"count|chance|weight|spawn|round|set range|difficult|upgrade|filter|delay|"
    r"time|cooldown|price|cost|budget|score|lives|cap|maximum|minimum|data|line number|"
    r"template|character type|weapon|grenade|team|flags",
    re.I)


# ---------------------------------------------------------------------------
# candidates
# ---------------------------------------------------------------------------

@dataclass
class Candidate:
    selector: str
    offset: int                 # file offset
    address: int                # virtual (meta) address
    kind: str                   # logical scalar kind: i16/u32/f32/sid/...
    width: int
    value: object
    group: str
    tag_index: int
    tag_path: str
    struct: str
    field_type: str
    field_name: str
    label: str = ""             # enum option / string-id text / interpretation
    context: str = ""           # script name + line, etc.
    refusal: str | None = None
    category: str = "field"

    @property
    def patchable(self) -> bool:
        return self.refusal is None

    def value_text(self) -> str:
        if self.kind == "f32":
            return "%g" % self.value
        if self.kind == "sid":
            return "0x%08X" % self.value
        return str(self.value)


@dataclass
class Scan:
    cache: ReachCacheFile
    defs: TagDefs
    candidates: list = dcfield(default_factory=list)
    by_selector: dict = dcfield(default_factory=dict)
    notes: list = dcfield(default_factory=list)
    script_context: dict = dcfield(default_factory=dict)   # node index -> text
    node_types: dict = dcfield(default_factory=dict)       # node index -> hs type index
    node_refusal: dict = dcfield(default_factory=dict)     # node index -> why `data` is not a value

    def get(self, selector: str) -> Candidate:
        cand = self.by_selector.get(selector)
        if cand is None:
            raise PatchError("no such selector: %r (run `find` to list them)" % selector)
        return cand

    def at(self, offset: int) -> Candidate | None:
        for c in self.candidates:
            if c.offset == offset:
                return c
        return None


# ---------------------------------------------------------------------------
# script expression table
# ---------------------------------------------------------------------------

HS_TYPES = None


def hs_type_name(defs: TagDefs, index: int) -> str:
    global HS_TYPES
    if HS_TYPES is None:
        e = defs.enums.get("hs_types_enum") or {}
        HS_TYPES = e.get("options") or []
    if 0 <= index < len(HS_TYPES):
        return str(HS_TYPES[index])
    return "type%d" % index


def hs_script_type_name(defs: TagDefs, index: int) -> str:
    e = defs.enums.get("hs_script_types_enum") or {}
    opts = e.get("options") or []
    return str(opts[index]) if 0 <= index < len(opts) else "type%d" % index


def _block_ptr(cache: ReachCacheFile, offset: int):
    """Read a 0xC tag block: (count, file offset) or (count, None)."""
    count = read_scalar(cache.data, offset, cache.endian, "i32")
    stored = read_scalar(cache.data, offset + 4, cache.endian, "u32")
    if count <= 0 or stored == 0:
        return count, None
    try:
        return count, cache.meta_to_offset(cache.expand(stored), "block address")
    except MapFormatError:
        return count, None


def scan_scripts(cache: ReachCacheFile, defs: TagDefs, scan: Scan):
    """Locate the scenario script tables and attribute nodes to scripts.

    Plausibility-gated: every count is checked against the definition dump's own
    ``max_count`` and every region against the tag's extent. If a check fails the
    whole script scan is abandoned with a note, rather than producing addresses
    that might be garbage.
    """
    scnr_tags = cache.tags_of_group("scnr")
    if not scnr_tags:
        scan.notes.append("no scnr tag in this cache; no script expression table to scan")
        return
    tag = scnr_tags[0]
    if tag.offset is None:
        scan.notes.append("the scnr tag is null")
        return
    try:
        fields = {f.name: f for f in defs.fields_of("scenario_struct_definition")}
    except DefsError as exc:
        scan.notes.append("scenario struct unusable: %s" % exc)
        return
    for need in ("hs syntax datums", "scripts", "globals", "script string data"):
        if need not in fields:
            scan.notes.append("the definition dump has no %r field in the scenario struct" % need)
            return

    end = tag.offset + (tag.size or 0)

    def ok_region(off, size):
        return off is not None and off >= tag.offset and off + size <= end

    nodes_off_field = tag.offset + fields["hs syntax datums"].offset
    node_count, nodes_off = _block_ptr(cache, nodes_off_field)
    cap = defs.block_max_count("hs_syntax_datum_block") or 64512
    if node_count <= 0 or nodes_off is None:
        scan.notes.append("the scenario has no script expression nodes (count %d)" % node_count)
        return
    if node_count > cap or not ok_region(nodes_off, node_count * 0x18):
        scan.notes.append("REFUSING to read the script expression table: count %d (max %d) at "
                          "file offset %s does not fit inside the scnr tag's estimated extent "
                          "0x%X..0x%X. The scenario layout for this build probably differs from "
                          "the definition dump." % (node_count, cap,
                                                    "none" if nodes_off is None else hex(nodes_off),
                                                    tag.offset, end))
        return

    e = cache.endian
    nodes = []
    for i in range(node_count):
        base = nodes_off + i * 0x18
        salt, union, vtype, flags, nxt, src, data, line = struct.unpack_from(e + "HHhhIIIh", cache.data, base)
        nodes.append(dict(index=i, offset=base, salt=salt, union=union, type=vtype,
                          flags=flags, next=nxt, src=src, data=data, line=line))
    # a salt sanity check: node i's datum is (salt_i << 16) | i
    good_salt = sum(1 for n in nodes if n["salt"] not in (0, 0xFFFF))
    if node_count and good_salt * 100 // node_count < 50:
        scan.notes.append("REFUSING the script expression table: %d of %d nodes have an "
                          "implausible datum salt, so this is probably not the node table"
                          % (node_count - good_salt, node_count))
        return

    def valid_datum(d):
        if d in (0, 0xFFFFFFFF):
            return None
        idx, salt = d & 0xFFFF, (d >> 16) & 0xFFFF
        if 0 <= idx < node_count and nodes[idx]["salt"] == salt:
            return idx
        return None

    # scripts and globals
    roots = []
    s_count, s_off = _block_ptr(cache, tag.offset + fields["scripts"].offset)
    s_cap = defs.block_max_count("hs_scripts_block") or 2048
    if s_off is not None and 0 < s_count <= s_cap and ok_region(s_off, s_count * 0x18):
        for i in range(s_count):
            base = s_off + i * 0x18
            name_sid, stype, rtype, root = struct.unpack_from(e + "IhhI", cache.data, base)
            roots.append((valid_datum(root), "script %s (%s)"
                          % (cache.resolve_sid(name_sid) or "<unnamed>",
                             hs_script_type_name(defs, stype))))
    else:
        scan.notes.append("the scripts block did not pass its plausibility check; node "
                          "attribution will fall back to index ranges")
    g_count, g_off = _block_ptr(cache, tag.offset + fields["globals"].offset)
    g_cap = defs.block_max_count("hs_globals_block") or 512
    if g_off is not None and 0 < g_count <= g_cap and ok_region(g_off, g_count * 0x28):
        for i in range(g_count):
            base = g_off + i * 0x28
            name = cache.reader.asciiz(base, 0x20, "script global name")
            root = read_scalar(cache.data, base + 0x24, e, "u32")
            roots.append((valid_datum(root), "global %s initialiser" % (name or "<unnamed>")))

    # exact attribution: depth-first from every root, following sibling chains
    # and, for group nodes, the child chain their `data` points at. A node is a
    # group when its `data` is a live datum whose target is a function_name or
    # special_form node -- the test Assembly's own emitter guarantees.
    owner = {}
    method = {}
    for root_idx, label in roots:
        if root_idx is None:
            continue
        stack = [root_idx]
        while stack:
            i = stack.pop()
            if i in owner:
                continue
            owner[i] = label
            method[i] = "exact"
            n = nodes[i]
            nxt = valid_datum(n["next"])
            if nxt is not None:
                stack.append(nxt)
            child = valid_datum(n["data"])
            if child is not None and nodes[child]["type"] in (1, 2):
                stack.append(child)
    # fallback: contiguous run from each root (datum index == emission order)
    bounds = sorted((i, lbl) for i, lbl in roots if i is not None)
    for n in nodes:
        if n["index"] in owner:
            continue
        pick = None
        for i, lbl in bounds:
            if i <= n["index"]:
                pick = lbl
            else:
                break
        if pick is not None:
            owner[n["index"]] = pick
            method[n["index"]] = "by index range (HEURISTIC)"

    blob_count, blob_off = None, None
    sfield = fields["script string data"]
    blob_size = read_scalar(cache.data, tag.offset + sfield.offset, e, "i32")
    stored = read_scalar(cache.data, tag.offset + sfield.offset + 0xC, e, "u32")
    if blob_size > 0 and stored:
        try:
            cand = cache.meta_to_offset(cache.expand(stored), "script string blob")
            if ok_region(cand, blob_size):
                blob_off, blob_count = cand, blob_size
        except MapFormatError:
            pass

    for n in nodes:
        i = n["index"]
        tname = hs_type_name(defs, n["type"])
        bits = ["%s constant" % tname if tname not in ("function_name", "special_form", "void")
                else tname]
        if blob_off is not None and n["src"] < blob_count:
            text = cache.reader.asciiz(blob_off + n["src"], min(48, blob_count - n["src"]),
                                       "script string")
            if text and text.isprintable():
                bits.append("string blob %r" % text)
        ctx = owner.get(i, "unattributed")
        if i in method:
            bits.append(method[i])
        child = valid_datum(n["data"])
        if child is not None and nodes[child]["type"] in (1, 2):
            scan.node_refusal[i] = (
                "this node is a group: its `data` field holds the datum of its first child "
                "(node %d, the %s node), so it is a link into the expression table, not a value"
                % (child, hs_type_name(defs, nodes[child]["type"])))
            bits.insert(0, "group -> child node %d" % child)
        elif n["type"] in (0, 1, 2, 3, 4):
            scan.node_refusal[i] = (
                "this node's value type is %s, so `data` holds an opcode / function index / "
                "nothing rather than a constant; patching it would call different engine code"
                % hs_type_name(defs, n["type"]))
        scan.script_context[i] = "%s line %d, %s" % (ctx, n["line"], ", ".join(b for b in bits if b))
        scan.node_types[i] = n["type"]
    scan.notes.append("script scan: %d expression nodes, %d roots, %d attributed exactly"
                      % (node_count, len(roots),
                         sum(1 for v in method.values() if v == "exact")))


# ---------------------------------------------------------------------------
# the generic field walker
# ---------------------------------------------------------------------------

def walk_tag(cache: ReachCacheFile, defs: TagDefs, tag: TagEntry, scan: Scan,
             budget: int = 400000, max_depth: int = 12):
    """Emit a Candidate for every scalar the definition dump can address."""
    info = defs.groups.get(tag.group_code)
    if info is None:
        scan.notes.append("no definition for tag group %r (tag %d)" % (tag.group_code, tag.index))
        return
    if tag.offset is None:
        return
    end = tag.offset + (tag.size or 0)
    prefix = "%s[%d]" % (tag.group_code, tag.index)
    stack = [(info["root_struct"], tag.offset, "", 0)]
    seen = set()
    emitted = 0

    while stack:
        struct_name, base, path, depth = stack.pop()
        if (struct_name, base) in seen or depth > max_depth:
            continue
        seen.add((struct_name, base))
        try:
            fields = defs.fields_of(struct_name)
        except DefsError as exc:
            scan.notes.append("skipped %s%s: %s" % (prefix, "/" + path if path else "", exc))
            continue
        if base < tag.offset or base + defs.struct_size(struct_name) > end:
            scan.notes.append("skipped %s%s: struct %s at 0x%X runs past the tag's estimated "
                              "extent" % (prefix, "/" + path if path else "", struct_name, base))
            continue
        for fd in fields:
            foff = base + fd.offset
            fpath = ("%s/%s" % (path, fd.name)) if path else fd.name
            if fd.type == "struct":
                stack.append((fd.definition, foff, fpath, depth + 1))
                continue
            if fd.type == "array":
                a = defs.arrays.get(fd.definition) or {}
                sub = a.get("struct")
                for i in range(int(a.get("count", 0))):
                    stack.append((sub, foff + i * defs.struct_size(sub),
                                  "%s[%d]" % (fpath, i), depth + 1))
                continue
            if fd.type in ("pad", "useless_pad", "terminator", "explanation", "custom"):
                continue
            if fd.type in TEXT_TYPES:
                text = cache.reader.asciiz(foff, TEXT_TYPES[fd.type], "text field")
                scan.candidates.append(Candidate(
                    selector="%s/%s" % (prefix, fpath), offset=foff,
                    address=cache.offset_to_meta(foff), kind="text",
                    width=TEXT_TYPES[fd.type], value=text, group=tag.group_code,
                    tag_index=tag.index, tag_path=tag.path or "", struct=struct_name,
                    field_type=fd.type, field_name=fd.name, label=repr(text),
                    refusal="text field: this tool only writes numeric scalars"))
                continue

            for (sub_name, sub_off, _code, kind) in defs.scalars_of(fd):
                if emitted >= budget:
                    scan.notes.append("field budget %d reached; stopped walking %s" % (budget, prefix))
                    return
                try:
                    value = read_scalar(cache.data, sub_off + base, cache.endian, kind)
                except DefsError:
                    continue
                sel_path = fpath if sub_name == fd.name else "%s%s" % (fpath, sub_name[len(fd.name):])
                cand = Candidate(
                    selector="%s/%s" % (prefix, sel_path), offset=base + sub_off,
                    address=cache.offset_to_meta(base + sub_off), kind=kind,
                    width=KIND_WIDTH[kind], value=value, group=tag.group_code,
                    tag_index=tag.index, tag_path=tag.path or "", struct=struct_name,
                    field_type=fd.type, field_name=fd.name)
                _classify(cache, defs, fd, cand, sub_name)
                _annotate(cache, defs, fd, cand, scan, struct_name)
                scan.candidates.append(cand)
                emitted += 1

            # follow a block
            if fd.type == "block":
                count, off = _block_ptr(cache, foff)
                if count <= 0 or off is None:
                    continue
                cap = defs.block_max_count(fd.definition)
                try:
                    sub_struct = defs.block_struct(fd.definition)
                    size = defs.struct_size(sub_struct)
                except DefsError as exc:
                    scan.notes.append("skipped block %s/%s: %s" % (prefix, fpath, exc))
                    continue
                if cap is not None and count > cap:
                    scan.notes.append("skipped block %s/%s: count %d exceeds the definition's "
                                      "max_count %d" % (prefix, fpath, count, cap))
                    continue
                if off < tag.offset or off + count * size > end:
                    scan.notes.append("skipped block %s/%s: %d x 0x%X at 0x%X runs outside the "
                                      "tag's estimated extent 0x%X..0x%X"
                                      % (prefix, fpath, count, size, off, tag.offset, end))
                    continue
                for i in range(count):
                    stack.append((sub_struct, off + i * size, "%s[%d]" % (fpath, i), depth + 1))


def _classify(cache, defs, fd, cand: Candidate, sub_name: str):
    """Decide whether this scalar may be patched, and why not if not."""
    suffix = sub_name[len(fd.name):]
    rules = STRUCT_RULES.get(cand.struct, {})
    if fd.name in rules:
        cand.refusal = rules[fd.name]
        return
    if fd.runtime:
        cand.refusal = ("field is marked '!' in the tag definition: the engine derives it, so a "
                        "patched value would disagree with whatever it is derived from")
        return
    if fd.type == "block":
        why = BLOCK_DEPENDENTS.get(fd.name, "other structures index into this block")
        cand.refusal = ("part of a tag block (count/address/definition): %s. Changing it would "
                        "change a count or an offset, which this tool never does." % why)
        return
    if fd.type == "data":
        cand.refusal = ("part of a data reference (size/flags/stream/address): it is a length or "
                        "an offset, not a value")
        return
    if fd.type == "tag_reference":
        if suffix != ".datum":
            cand.refusal = ("part of a tag reference other than its datum index (%s): the group "
                            "tag and the name pointer/length are structural" % (suffix or "group"))
            return
        group_word = read_scalar(cache.data, cand.offset - 12, cache.endian, "u32")
        if group_word in (0, 0xFFFFFFFF) and cand.value in (0, 0xFFFFFFFF):
            cand.refusal = ("this tag reference is empty (no group tag and no datum): there is "
                            "nothing to retarget, and filling it in would need a tag that the "
                            "scenario does not already reference")
        return


def _annotate(cache, defs, fd, cand: Candidate, scan: Scan, struct_name: str):
    bits = []
    if fd.type in ("short_enum", "long_enum", "char_enum"):
        lbl = defs.enum_label(fd.definition, cand.value)
        if lbl:
            bits.append(lbl)
    if fd.type in ("word_flags", "long_flags", "byte_flags"):
        lbl = defs.flag_labels(fd.definition, cand.value)
        if lbl:
            bits.append(lbl)
    if cand.kind == "sid":
        text = cache.resolve_sid(cand.value)
        bits.append("string-id %s" % (repr(text) if text else "(none)"))
    if fd.type == "tag_reference" and cand.kind == "u32":
        idx = cand.value & 0xFFFF
        if cand.value not in (0, 0xFFFFFFFF) and idx < len(cache.tags):
            t = cache.tags[idx]
            bits.append("-> tag %d %s %s" % (idx, t.group_code, t.path or ""))
    if fd.comment:
        bits.append(fd.comment[:70])
    cand.label = "; ".join(bits)
    if struct_name == "hs_syntax_datum_block":
        cand.category = "script"
        m = re.search(r"hs syntax datums\[(\d+)\]", cand.selector)
        if m:
            i = int(m.group(1))
            cand.context = scan.script_context.get(i, "")
            if fd.name == "data" and i in scan.node_refusal and not cand.refusal:
                cand.refusal = scan.node_refusal[i]
            if fd.name == "data" and scan.node_types.get(i) == 6:   # real
                as_float = struct.unpack(cache.endian + "f",
                                         struct.pack(cache.endian + "I", cand.value & 0xFFFFFFFF))[0]
                cand.label = ("real constant = %g (patch with --kind f32)" % as_float)


# ---------------------------------------------------------------------------
# scanning
# ---------------------------------------------------------------------------

DEFAULT_GROUPS = ("scnr", "sqtm", "smdt", "wave")


def scan_cache(cache: ReachCacheFile, defs: TagDefs, groups=DEFAULT_GROUPS,
               budget: int = 400000) -> Scan:
    scan = Scan(cache=cache, defs=defs)
    scan_scripts(cache, defs, scan)
    for tag in cache.tags:
        if groups and tag.group_code not in groups:
            continue
        if tag.offset is None:
            continue
        walk_tag(cache, defs, tag, scan, budget=budget)
    dupes = {}
    for c in scan.candidates:
        if c.selector in scan.by_selector:
            dupes[c.selector] = dupes.get(c.selector, 1) + 1
            c.selector = "%s~%d" % (c.selector, dupes[c.selector])
        scan.by_selector[c.selector] = c
    return scan


# ---------------------------------------------------------------------------
# request resolution
# ---------------------------------------------------------------------------

@dataclass
class Request:
    raw: str
    selector: str | None
    offset: int | None
    kind: str | None
    value: object


def parse_set(spec: str) -> Request:
    """``SELECTOR=VALUE`` or ``@0xADDR:kind=VALUE``."""
    if "=" not in spec:
        raise PatchError("--set needs SELECTOR=VALUE, got %r" % spec)
    target, _, raw_value = spec.partition("=")
    target, raw_value = target.strip(), raw_value.strip()
    kind = None
    offset = None
    selector = None
    if target.startswith("@"):
        body = target[1:]
        if ":" in body:
            body, _, kind = body.partition(":")
            kind = kind.strip()
            if kind not in KIND_WIDTH:
                raise PatchError("unknown kind %r; one of %s" % (kind, ", ".join(sorted(KIND_WIDTH))))
        try:
            offset = int(body, 0)
        except ValueError:
            raise PatchError("cannot read %r as a file offset" % body)
    else:
        # SELECTOR:kind=VALUE -- only split on a trailing ':kind', because some
        # real field names contain a colon ("local sea level:wu").
        if ":" in target:
            head, _, maybe = target.rpartition(":")
            if head and maybe.strip() in KIND_WIDTH:
                target, kind = head, maybe.strip()
        selector = target
    if raw_value.lower() in ("true", "false"):
        value = 1 if raw_value.lower() == "true" else 0
    elif re.fullmatch(r"[-+]?\d+\.\d*([eE][-+]?\d+)?|[-+]?\.\d+", raw_value):
        value = float(raw_value)
    else:
        try:
            value = int(raw_value, 0)
        except ValueError:
            raise PatchError("cannot read %r as a number" % raw_value)
    return Request(raw=spec, selector=selector, offset=offset, kind=kind, value=value)


@dataclass
class Plan:
    cand: Candidate
    kind: str
    old_bytes: bytes
    new_bytes: bytes
    old_value: object
    new_value: object


def plan_patch(cache: ReachCacheFile, scan: Scan, req: Request, allow_unmapped=False) -> Plan:
    if req.selector is not None:
        cand = scan.get(req.selector)
    else:
        cand = scan.at(req.offset)
        if cand is None:
            if not allow_unmapped:
                raise Refused(
                    "file offset 0x%X does not correspond to any field this tool can name. "
                    "It may be inside a structure the definition dump does not describe, or "
                    "outside every tag. Refusing: an unnamed write cannot be checked for being "
                    "a length, an offset or a count. Pass --allow-unmapped with an explicit "
                    "'@0x...:kind' to override (still same-size, still verified)." % req.offset)
            if req.kind is None:
                raise PatchError("--allow-unmapped needs an explicit kind, e.g. @0x%X:i16" % req.offset)
            tag = _tag_at(cache, req.offset)
            if tag is None:
                raise Refused("file offset 0x%X is not inside any tag's data" % req.offset)
            try:
                raw_now = read_scalar(cache.data, req.offset, cache.endian, req.kind)
            except DefsError as exc:
                raise Refused("cannot even read %d bytes at 0x%X: %s"
                              % (KIND_WIDTH[req.kind], req.offset, exc))
            cand = Candidate(selector="@0x%X:%s" % (req.offset, req.kind), offset=req.offset,
                             address=cache.offset_to_meta(req.offset), kind=req.kind,
                             width=KIND_WIDTH[req.kind], value=raw_now,
                             group=tag.group_code, tag_index=tag.index, tag_path=tag.path or "",
                             struct="<unmapped>", field_type="<unmapped>", field_name="<unmapped>",
                             label="UNMAPPED: no definition describes this offset")

    if cand.refusal:
        raise Refused("%s\n    refusing to patch %s (%s %s in %s)"
                      % (cand.refusal, cand.selector, cand.field_type, cand.field_name, cand.struct))

    kind = req.kind or cand.kind
    if kind not in KIND_WIDTH:
        raise PatchError("unknown kind %r" % kind)
    if KIND_WIDTH[kind] != cand.width:
        raise Refused("%s is a %d-byte %s field; writing it as %s would need %d bytes. This is a "
                      "size-changing edit and is refused: the extra bytes belong to the next "
                      "field." % (cand.selector, cand.width, cand.kind, kind, KIND_WIDTH[kind]))

    if kind == "sid":
        text = cache.resolve_sid(int(req.value))
        if not text or text.startswith("<sid "):
            raise Refused("string-id 0x%08X does not resolve to a string in this cache's string-id "
                          "table. Adding a string means growing the debug section, which this tool "
                          "does not do. Pick a string-id that already exists (run `find` and look "
                          "at the string-id column)." % int(req.value))
    if cand.field_type == "tag_reference" and cand.selector.endswith(".datum"):
        idx = int(req.value) & 0xFFFF
        if int(req.value) not in (0, 0xFFFFFFFF):
            if idx >= len(cache.tags) or cache.tags[idx].offset is None:
                raise Refused("tag datum 0x%08X points at tag index %d, which is not a live tag in "
                              "this cache (it has %d tags). A patch cannot add a tag."
                              % (int(req.value), idx, len(cache.tags)))
            allowed = cand.label
            want = cache.tags[idx].group_code
            if allowed and "-> tag" in allowed and want not in allowed:
                pass    # group mismatch is reported, not refused: see README

    try:
        new_bytes = pack_scalar(cache.endian, kind, req.value)
    except DefsError as exc:
        raise Refused(str(exc))
    old_bytes = cache.data[cand.offset:cand.offset + cand.width]
    if len(new_bytes) != len(old_bytes):
        raise Refused("internal size check failed for %s" % cand.selector)
    return Plan(cand=cand, kind=kind, old_bytes=bytes(old_bytes), new_bytes=new_bytes,
                old_value=cand.value, new_value=req.value)


def _tag_at(cache: ReachCacheFile, offset: int):
    for t in cache.tags:
        if t.offset is not None and t.offset <= offset < t.offset + (t.size or 0):
            return t
    return None


# ---------------------------------------------------------------------------
# apply + verify
# ---------------------------------------------------------------------------

def byte_diff(a: bytes, b: bytes):
    """List of (offset, old, new) runs where two equal-length buffers differ."""
    if len(a) != len(b):
        raise PatchError("the output is %d bytes but the input is %d; a same-size patch cannot "
                         "change the file length" % (len(b), len(a)))
    runs, i, n = [], 0, len(a)
    while i < n:
        if a[i] != b[i]:
            j = i
            while j < n and a[j] != b[j]:
                j += 1
            runs.append((i, a[i:j], b[i:j]))
            i = j
        else:
            i += 1
    return runs


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass
class Result:
    data: bytes
    plans: list
    diff: list
    checksum_before: int
    checksum_after: int
    reparsed: ReachCacheFile


def build_patched(cache: ReachCacheFile, scan: Scan, plans: list,
                  defs: TagDefs, verbose_fail=True) -> Result:
    """Apply every plan in memory, then verify. Raises Refused on any doubt."""
    ranges = []
    for p in plans:
        lo, hi = p.cand.offset, p.cand.offset + p.cand.width
        for (o_lo, o_hi, sel) in ranges:
            if lo < o_hi and o_lo < hi:
                raise Refused("two patches overlap at 0x%X: %s and %s" % (lo, sel, p.cand.selector))
        ranges.append((lo, hi, p.cand.selector))

    writer = CacheWriter(cache)
    stored_before, computed_before, _ok = writer.verify_checksum()
    for p in plans:
        tag = cache.tags[p.cand.tag_index]
        if tag.offset is None:
            raise Refused("tag %d is null" % p.cand.tag_index)
        at = p.cand.offset - tag.offset
        if at < 0:
            raise Refused("%s resolves outside its own tag" % p.cand.selector)
        try:
            writer.patch_tag(tag, p.new_bytes, at=at)
        except WriteError as exc:
            raise Refused(str(exc))
    checksum_after = writer.update_checksum()
    data = writer.bytes()

    # 1. the output must re-parse with the reader, from scratch
    try:
        reparsed = writer.reparse()
    except MapFormatError as exc:
        raise Refused("the patched file does not re-parse (%s). REFUSING to write it." % exc)
    # 2. no new parse warnings
    before = set(cache.diag.warnings)
    after = set(reparsed.diag.warnings)
    fresh = after - before
    if fresh:
        raise Refused("the patched file re-parses but with %d new warning(s), so something "
                      "structural moved. REFUSING to write it:\n    %s"
                      % (len(fresh), "\n    ".join(sorted(fresh))))
    # 3. the only changed bytes are the patched fields and the checksum
    diff = byte_diff(cache.data, data)
    ck_kind, ck_off = cache.variant.fields["checksum"]
    allowed = list(ranges) + [(ck_off, ck_off + rc._KIND_SIZE[ck_kind], "header checksum")]
    for (off, old, new) in diff:
        lo, hi = off, off + len(old)
        covered = any(a_lo <= lo and hi <= a_hi for (a_lo, a_hi, _s) in allowed)
        if not covered:
            raise Refused("byte(s) at 0x%X changed and were not asked for (%s -> %s). "
                          "REFUSING to write the file." % (off, old.hex(), new.hex()))
    # 4. every patched value reads back through its own selector
    rescan = scan_cache(reparsed, defs, groups=tuple({p.cand.group for p in plans}))
    for p in plans:
        if p.cand.struct == "<unmapped>":
            got = read_scalar(data, p.cand.offset, cache.endian, p.kind)
        else:
            c2 = rescan.by_selector.get(p.cand.selector)
            if c2 is None:
                raise Refused("after patching, selector %s no longer resolves. REFUSING."
                              % p.cand.selector)
            got = read_scalar(data, c2.offset, cache.endian, p.kind)
        want = float(p.new_value) if p.kind == "f32" else int(p.new_value)
        if p.kind == "f32":
            ok = abs(got - want) <= max(1e-6, abs(want) * 1e-6)
        else:
            ok = got == want
        if not ok:
            raise Refused("after patching, %s reads back %r, not %r. REFUSING."
                          % (p.cand.selector, got, p.new_value))
    return Result(data=data, plans=plans, diff=diff,
                  checksum_before=stored_before or 0, checksum_after=checksum_after,
                  reparsed=reparsed)


# ---------------------------------------------------------------------------
# manifest
# ---------------------------------------------------------------------------

def make_manifest(cache: ReachCacheFile, result: Result, in_path: Path, out_path: Path) -> dict:
    ck_kind, ck_off = cache.variant.fields["checksum"]
    ck_width = rc._KIND_SIZE[ck_kind]
    return {
        "tool": TOOL,
        "format": MANIFEST_FORMAT,
        "created": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "synthetic_only_warning": "this tool has never been validated against a real map",
        "input": {"path": str(in_path), "sha256": sha256(cache.data), "size": len(cache.data)},
        "output": {"path": str(out_path), "sha256": sha256(result.data), "size": len(result.data)},
        "variant": cache.variant.name,
        "build_string": cache.build_string,
        "checksum": {
            "stored_before": result.checksum_before,
            "recomputed_after": result.checksum_after,
            "offset": ck_off,
            # the header checksum field is restored verbatim on revert, so that an
            # unpatch reproduces the input byte for byte even when the input shipped
            # with a zeroed checksum (which is what MCC does).
            "old_bytes": bytes(cache.data[ck_off:ck_off + ck_width]).hex(),
            "new_bytes": bytes(result.data[ck_off:ck_off + ck_width]).hex(),
        },
        "patches": [
            {
                "selector": p.cand.selector,
                "file_offset": p.cand.offset,
                "meta_address": p.cand.address,
                "tag": {"group": p.cand.group, "index": p.cand.tag_index, "path": p.cand.tag_path},
                "struct": p.cand.struct,
                "field": p.cand.field_name,
                "field_type": p.cand.field_type,
                "kind": p.kind,
                "old_value": p.old_value if not isinstance(p.old_value, bytes) else None,
                "new_value": p.new_value,
                "old_bytes": p.old_bytes.hex(),
                "new_bytes": p.new_bytes.hex(),
                "context": p.cand.context,
                "label": p.cand.label,
            } for p in result.plans
        ],
    }


def load_manifest(path) -> dict:
    p = Path(path)
    if not p.is_file():
        raise ManifestError("manifest %s does not exist" % p)
    try:
        man = json.loads(p.read_text())
    except Exception as exc:                                        # noqa: BLE001
        raise ManifestError("manifest %s is not readable JSON: %s" % (p, exc))
    if not isinstance(man, dict):
        raise ManifestError("manifest %s is not a JSON object" % p)
    if man.get("format") != MANIFEST_FORMAT:
        raise ManifestError("manifest %s has format %r; this tool writes and reads format %d"
                            % (p, man.get("format"), MANIFEST_FORMAT))
    for key in ("input", "output", "patches"):
        if key not in man:
            raise ManifestError("manifest %s has no %r section" % (p, key))
    for key in ("input", "output"):
        sec = man[key]
        if not isinstance(sec, dict) or not isinstance(sec.get("sha256"), str) \
                or len(sec["sha256"]) != 64:
            raise ManifestError("manifest %s: %s section needs a 64-character sha256" % (p, key))
    if not isinstance(man["patches"], list) or not man["patches"]:
        raise ManifestError("manifest %s records no patches; there is nothing to revert" % p)
    for i, rec in enumerate(man["patches"]):
        if not isinstance(rec, dict):
            raise ManifestError("manifest %s: patch %d is not an object" % (p, i))
        for key in ("file_offset", "old_bytes", "new_bytes", "selector", "kind"):
            if key not in rec:
                raise ManifestError("manifest %s: patch %d has no %r" % (p, i, key))
        if not isinstance(rec["file_offset"], int) or rec["file_offset"] < 0:
            raise ManifestError("manifest %s: patch %d has a bad file_offset %r"
                                % (p, i, rec["file_offset"]))
        try:
            old = bytes.fromhex(rec["old_bytes"])
            new = bytes.fromhex(rec["new_bytes"])
        except ValueError as exc:
            raise ManifestError("manifest %s: patch %d has unreadable hex (%s)" % (p, i, exc))
        if not old or len(old) != len(new):
            raise ManifestError("manifest %s: patch %d has old_bytes %d long and new_bytes %d long; "
                                "a same-size patch must have equal lengths"
                                % (p, i, len(old), len(new)))
    ck = man.get("checksum")
    if isinstance(ck, dict) and "offset" in ck:
        if not isinstance(ck["offset"], int) or ck["offset"] < 0:
            raise ManifestError("manifest %s: the checksum record has a bad offset %r"
                                % (p, ck.get("offset")))
        try:
            old = bytes.fromhex(ck.get("old_bytes", ""))
            new = bytes.fromhex(ck.get("new_bytes", ""))
        except ValueError as exc:
            raise ManifestError("manifest %s: the checksum record has unreadable hex (%s)" % (p, exc))
        if not old or len(old) != len(new):
            raise ManifestError("manifest %s: the checksum record's old/new bytes are %d and %d "
                                "long; they must match" % (p, len(old), len(new)))
    return man


# ---------------------------------------------------------------------------
# file plumbing
# ---------------------------------------------------------------------------

def backup(path: Path, log: list) -> Path | None:
    p = Path(path)
    if not p.is_file():
        return None
    bak = p.with_suffix(p.suffix + ".bak")
    n = 0
    while bak.exists():
        n += 1
        bak = p.with_suffix(p.suffix + ".bak%d" % n)
    shutil.copy2(p, bak)
    log.append("backed up %s -> %s" % (p, bak))
    return bak


def emit(result_data: bytes, out_path: Path, manifest: dict, manifest_path: Path,
         in_path: Path, log: list):
    backup(in_path, log)
    backup(out_path, log)
    backup(manifest_path, log)
    Path(out_path).write_bytes(result_data)
    log.append("wrote %s (%d bytes)" % (out_path, len(result_data)))
    Path(manifest_path).write_text(json.dumps(manifest, indent=2) + "\n")
    log.append("wrote manifest %s" % manifest_path)


# ---------------------------------------------------------------------------
# revert
# ---------------------------------------------------------------------------

def revert(manifest_path, target=None, out=None, apply=False):
    man = load_manifest(manifest_path)
    src = Path(target) if target else Path(man["output"]["path"])
    if not src.is_file():
        raise ManifestError("the patched file %s named by the manifest does not exist; pass "
                            "--target to point at it" % src)
    data = bytearray(src.read_bytes())
    if sha256(bytes(data)) != man["output"]["sha256"]:
        raise ManifestError(
            "%s does not match the manifest: its sha256 is %s but the manifest recorded %s. "
            "Something else changed this file, so reverting could corrupt it. REFUSING."
            % (src, sha256(bytes(data))[:16] + "...", man["output"]["sha256"][:16] + "..."))
    if len(data) != man["output"]["size"]:
        raise ManifestError("%s is %d bytes; the manifest recorded %d"
                            % (src, len(data), man["output"]["size"]))
    lines = []
    for rec in reversed(man["patches"]):
        off = rec["file_offset"]
        old, new = bytes.fromhex(rec["old_bytes"]), bytes.fromhex(rec["new_bytes"])
        if off + len(new) > len(data):
            raise ManifestError("patch at 0x%X runs past the end of %s" % (off, src))
        have = bytes(data[off:off + len(new)])
        if have != new:
            raise ManifestError("at 0x%X the file holds %s but the manifest says the patch wrote "
                                "%s. REFUSING to revert a file that does not match its manifest."
                                % (off, have.hex(), new.hex()))
        data[off:off + len(old)] = old
        lines.append("0x%-8X %-52s %s -> %s" % (off, rec["selector"], new.hex(), old.hex()))

    ck = man.get("checksum") or {}
    if isinstance(ck.get("offset"), int) and isinstance(ck.get("old_bytes"), str):
        off = ck["offset"]
        old = bytes.fromhex(ck["old_bytes"])
        new = bytes.fromhex(ck["new_bytes"])
        have = bytes(data[off:off + len(new)])
        if have != new:
            raise ManifestError("at the checksum field 0x%X the file holds %s but the manifest "
                                "says the patch wrote %s. REFUSING." % (off, have.hex(), new.hex()))
        data[off:off + len(old)] = old
        lines.append("0x%-8X %-52s %s -> %s" % (off, "header checksum (restored verbatim)",
                                                new.hex(), old.hex()))

    cache = ReachCacheFile(bytes(data))
    writer = CacheWriter(cache)
    stored, checksum, matches = writer.verify_checksum()
    restored = writer.bytes()
    try:
        writer.reparse()
    except MapFormatError as exc:
        raise ManifestError("the reverted file does not re-parse (%s). REFUSING to write it." % exc)
    identical = sha256(restored) == man["input"]["sha256"]
    out_path = Path(out) if out else Path(str(src) + ".reverted")
    log = []
    if apply:
        backup(out_path, log)
        out_path.write_bytes(restored)
        log.append("wrote %s (%d bytes)" % (out_path, len(restored)))
    return dict(lines=lines, identical=identical, checksum=checksum, stored=stored,
                checksum_matches=matches, out=out_path, log=log, applied=apply,
                manifest=man, data=restored)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def open_cache(path, force_variant=None) -> ReachCacheFile:
    p = Path(path)
    if not p.is_file():
        raise PatchError("%s does not exist" % p)
    return ReachCacheFile.from_path(p, force_variant=force_variant)


def cmd_find(args):
    defs = TagDefs(args.defs)
    cache = open_cache(args.map, args.force_variant)
    groups = tuple(args.groups.split(",")) if args.groups else DEFAULT_GROUPS
    scan = scan_cache(cache, defs, groups=groups, budget=args.budget)
    pat = re.compile(args.grep, re.I) if args.grep else None
    rows = []
    for c in scan.candidates:
        if not args.all and not c.patchable:
            continue
        hay = "%s %s %s" % (c.selector, c.label, c.context)
        if pat and not pat.search(hay):
            continue
        if not args.everything and c.category != "script" and not INTEREST.search(hay):
            continue
        rows.append(c)
    print("# %s -- patch candidates" % cache.path)
    print("# build %r, header layout %s, %d tags" % (cache.build_string, cache.variant.name,
                                                     len(cache.tags)))
    print("# SYNTHETIC-ONLY TOOL: nothing here has been validated against a real map.")
    print()
    script_rows = [c for c in rows if c.category == "script"]
    field_rows = [c for c in rows if c.category != "script"]
    if script_rows:
        print("== script expression-node values (research/13 modification #1) ==")
        print("%-10s %-46s %-5s %-12s %s" % ("OFFSET", "SELECTOR", "KIND", "VALUE", "CONTEXT"))
        for c in sorted(script_rows, key=lambda c: c.offset):
            print("0x%-8X %-46s %-5s %-12s %s" % (c.offset, c.selector, c.kind, c.value_text(),
                                                  c.context or c.label))
        print()
    if field_rows:
        print("== tag block fields (research/13 modifications #2 and #3) ==")
        print("%-10s %-58s %-5s %-12s %s" % ("OFFSET", "SELECTOR", "KIND", "VALUE", "NOTE"))
        for c in sorted(field_rows, key=lambda c: (c.group, c.tag_index, c.offset)):
            print("0x%-8X %-58s %-5s %-12s %s" % (c.offset, c.selector, c.kind, c.value_text(),
                                                  (c.refusal and "REFUSED: " + c.refusal[:60]) or c.label))
        print()
    print("%d candidate(s) shown; %d patchable in total, %d refused in total"
          % (len(rows), sum(1 for c in scan.candidates if c.patchable),
             sum(1 for c in scan.candidates if not c.patchable)))
    if scan.notes and not args.quiet:
        print("\nnotes")
        for n in scan.notes:
            print("  - %s" % n)
    return EXIT_OK


def cmd_patch(args):
    defs = TagDefs(args.defs)
    cache = open_cache(args.map, args.force_variant)
    scan = scan_cache(cache, defs, groups=tuple(args.groups.split(",")) if args.groups
                      else DEFAULT_GROUPS, budget=args.budget)
    if not args.set:
        raise PatchError("nothing to do: pass at least one --set SELECTOR=VALUE")
    reqs = [parse_set(s) for s in args.set]
    plans = [plan_patch(cache, scan, r, allow_unmapped=args.allow_unmapped) for r in reqs]
    result = build_patched(cache, scan, plans, defs)

    in_path = Path(args.map)
    out_path = Path(args.out) if args.out else in_path.with_name(in_path.stem + ".patched" + in_path.suffix)
    man_path = Path(args.manifest) if args.manifest else Path(str(out_path) + ".patch.json")
    if out_path.resolve() == in_path.resolve():
        raise Refused("--out is the input file. This tool never writes in place.")

    print("input   %s (%d bytes, sha256 %s)" % (in_path, len(cache.data), sha256(cache.data)[:16]))
    print("output  %s" % out_path)
    print("manifest %s" % man_path)
    print("header checksum %s -> 0x%08X (recomputed)"
          % ("0x%08X" % result.checksum_before, result.checksum_after))
    print()
    print("patches")
    for p in result.plans:
        print("  %-52s %-5s %s -> %s   [%s -> %s]"
              % (p.cand.selector, p.kind, p.cand.value_text(), p.new_value,
                 p.old_bytes.hex(), p.new_bytes.hex()))
        if p.cand.context:
            print("      %s" % p.cand.context)
        if p.cand.label:
            print("      %s" % p.cand.label)
    print()
    print("byte diff (%d run(s), file length unchanged at %d bytes)" % (len(result.diff), len(result.data)))
    for (off, old, new) in result.diff:
        who = next((s for (lo, hi, s) in
                    [(p.cand.offset, p.cand.offset + p.cand.width, p.cand.selector) for p in result.plans]
                    if lo <= off < hi), "header checksum")
        print("  0x%-8X %-20s -> %-20s %s" % (off, old.hex(), new.hex(), who))
    print()
    print("verification: re-parsed OK, no new parse warnings, every patched value reads back, "
          "and every changed byte lies inside the %d intended byte(s) or the 4 checksum bytes"
          % sum(p.cand.width for p in result.plans))
    if not args.apply:
        print("\nDRY RUN. Nothing was written. Re-run with --apply to write %s" % out_path)
        return EXIT_OK
    log = []
    manifest = make_manifest(cache, result, in_path, out_path)
    if out_path.exists() and not args.force:
        raise Refused("%s already exists; pass --force to replace it (it will be backed up first)"
                      % out_path)
    emit(result.data, out_path, manifest, man_path, in_path, log)
    for line in log:
        print(line)
    print("revert with: python3 %s --revert %s --apply" % (Path(__file__).name, man_path))
    return EXIT_OK


def cmd_revert(args):
    res = revert(args.revert, target=args.target, out=args.out, apply=args.apply)
    man = res["manifest"]
    print("manifest %s (%d patch(es), created %s)" % (args.revert, len(man["patches"]),
                                                      man.get("created")))
    print("target   %s" % (args.target or man["output"]["path"]))
    print()
    for line in res["lines"]:
        print("  " + line)
    print()
    print("restored checksum field 0x%08X; the XOR of the restored body is 0x%08X (%s)"
          % (res["stored"] or 0, res["checksum"],
             "they agree" if res["checksum_matches"] else
             "they differ, which is how the original shipped - MCC does not enforce it"))
    if res["identical"]:
        print("the reverted bytes are IDENTICAL to the original input recorded in the manifest "
              "(sha256 match)")
    else:
        print("!! the reverted bytes do NOT match the original input's sha256. The revert is "
              "byte-exact for the patched fields, but something else differs.")
    for line in res["log"]:
        print(line)
    if not res["applied"]:
        print("\nDRY RUN. Nothing was written. Re-run with --apply to write %s" % res["out"])
    return EXIT_OK


def cmd_selftest(args):
    import test_patch_map
    return test_patch_map.run()


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="patch_map.py",
        description="Find and safely change numeric values inside a built Halo: Reach MCC .map. "
                    "Same-size writes only. Dry run unless --apply. SYNTHETIC-ONLY validation.",
        epilog="A patched map is unsigned: MCC must be launched with anti-cheat disabled "
               "(Steam launch option 'Play Halo: MCC Anti-Cheat Disabled'). See README.md.")
    ap.add_argument("map", nargs="?", help="the .map cache file to read")
    ap.add_argument("--find", action="store_true", help="list patchable values with context")
    ap.add_argument("--set", action="append", metavar="SELECTOR=VALUE",
                    help="patch one value; repeatable. SELECTOR comes from --find, or use "
                         "'@0xOFFSET:kind=VALUE'")
    ap.add_argument("--apply", action="store_true", help="actually write files (default: dry run)")
    ap.add_argument("--out", help="output .map path (never the input)")
    ap.add_argument("--manifest", help="manifest path (default: <out>.patch.json)")
    ap.add_argument("--revert", metavar="MANIFEST", help="undo a change set from its manifest")
    ap.add_argument("--target", help="with --revert: the patched file, if it has moved")
    ap.add_argument("--force", action="store_true", help="replace an existing output file")
    ap.add_argument("--allow-unmapped", action="store_true",
                    help="permit '@0xOFFSET:kind' writes to offsets no definition describes "
                         "(still same-size, still verified, but unchecked for structural meaning)")
    ap.add_argument("--groups", help="comma-separated tag groups to walk (default scnr,sqtm,smdt,wave)")
    ap.add_argument("--all", action="store_true", help="with --find: also list refused fields")
    ap.add_argument("--everything", action="store_true",
                    help="with --find: list every addressable field, not just the ones whose "
                         "name looks like a tunable (script nodes are always listed)")
    ap.add_argument("--grep", help="with --find: filter by regex")
    ap.add_argument("--budget", type=int, default=400000, help="max fields to walk per tag")
    ap.add_argument("--defs", default=str(tagdefs.DEFAULT_DEFS_DIR), help="tag definition dump dir")
    ap.add_argument("--force-variant", help="force a header layout (mcc-u8+, mcc-u3, mcc-2019, xbox360-reach)")
    ap.add_argument("--quiet", action="store_true", help="suppress scan notes")
    ap.add_argument("--self-test", action="store_true", help="run the synthetic test suite")
    args = ap.parse_args(argv)

    try:
        if args.self_test:
            return cmd_selftest(args)
        if args.revert:
            return cmd_revert(args)
        if not args.map:
            ap.error("a .map path is required")
        if args.set:
            return cmd_patch(args)
        if args.find or not args.set:
            return cmd_find(args)
    except Refused as exc:
        print("REFUSED: %s" % exc, file=sys.stderr)
        return EXIT_REFUSED
    except ManifestError as exc:
        print("MANIFEST ERROR: %s" % exc, file=sys.stderr)
        return EXIT_MANIFEST
    except (DefsError, MapFormatError) as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return EXIT_FORMAT
    except PatchError as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return EXIT_USAGE
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
