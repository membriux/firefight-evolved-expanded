#!/usr/bin/env python3
"""
tagdefs.py -- field-offset resolver for Halo: Reach MCC tag structures.

Where the offsets come from
---------------------------
``research/_raw/reach-defs/*.json`` is a dump of the *real* MCC Reach tag
definitions (camden-smallwood/definitions @ haloreach_mcc).  Each struct in
that dump carries both its field list *and* its compiled ``sizeof()``.  This
module walks the field list with a type->size table and **requires the sum to
equal the declared size**.  A struct whose fields do not add up to its own
``sizeof()`` is rejected and never used to compute an address.

That is a real check, not a vibe:

  * 390 of the 399 structs in the dump validate with the size table below.
    The 9 that do not are listed in ``KNOWN_BAD`` and are refused on use.
  * The offsets this module derives for ``scenario`` independently reproduce
    the numbers Assembly's ``LayoutsU13`` layout XML gives in
    ``research/13-map-write-feasibility.md`` §4.1:
      script string data 0x41C, scripts 0x430, hs syntax datums 0x504.
    Two unrelated sources agreeing is the strongest evidence this project has
    for any tag-internal offset.
  * ``hs_syntax_datum_block`` is 24 bytes with ``data`` at 0x10, matching the
    expression-node layout in §4.1; ``squads_block_struct`` is 0x6C, matching
    ``research/07`` §10.1.

STATUS: SYNTHETIC-PROVEN against fixtures built by ``tools/patch/fixture.py``.
The dump is from one MCC build.  A map from a different build may place these
fields elsewhere; ``patch_map.py`` therefore plausibility-checks every table it
reads and refuses rather than guesses.
"""

from __future__ import annotations

import json
import struct
from dataclasses import dataclass, field as dcfield
from pathlib import Path

_HERE = Path(__file__).resolve().parent
DEFAULT_DEFS_DIR = _HERE.parent.parent / "research" / "_raw" / "reach-defs"


class DefsError(Exception):
    """The definition dump is missing, malformed, or a struct does not validate."""


# ---------------------------------------------------------------------------
# type -> size, and type -> how to read a scalar
# ---------------------------------------------------------------------------
# Sizes are the Blam gen3 field sizes. The table is validated by summing every
# struct in the dump and comparing with its own declared sizeof(); see
# TagDefs.validate_all().

SIZES = {
    "angle": 4, "angle_bounds": 8, "byte_flags": 1, "char_block_index": 1,
    "char_enum": 1, "char_integer": 1, "custom": 0, "data": 20, "explanation": 0,
    "fraction_bounds": 8, "int64_integer": 8, "long_block_flags": 4,
    "long_block_index": 4, "long_enum": 4, "long_flags": 4, "long_integer": 4,
    "long_string": 256, "real": 4, "real_bounds": 8, "real_euler_angles_2d": 8,
    "real_euler_angles_3d": 12, "real_fraction": 4, "real_plane_2d": 12,
    "real_plane_3d": 16, "real_point_2d": 8, "real_point_3d": 12,
    "real_quaternion": 16, "real_rgb_color": 12, "real_vector_3d": 12,
    "rgb_color": 4, "short_block_index": 2, "short_bounds": 4, "short_enum": 2,
    "short_integer": 2, "string": 32, "string_id": 4, "tag": 4,
    "tag_reference": 16, "terminator": 0, "word_block_flags": 2, "word_flags": 2,
    "block": 12, "custom_short_block_index": 2, "tag_interop": 16,
}

# A scalar field expands into one or more patchable sub-scalars:
#   suffix -> (relative offset, struct code, logical kind name)
# struct codes are used with the cache's endian prefix.
_SCALARS = {
    "char_integer": [("", 0, "b", "i8")],
    "char_enum": [("", 0, "B", "u8")],
    "byte_flags": [("", 0, "B", "u8")],
    "char_block_index": [("", 0, "b", "i8")],
    "short_integer": [("", 0, "h", "i16")],
    "short_enum": [("", 0, "h", "i16")],
    "word_flags": [("", 0, "H", "u16")],
    "word_block_flags": [("", 0, "H", "u16")],
    "short_block_index": [("", 0, "h", "i16")],
    "custom_short_block_index": [("", 0, "h", "i16")],
    "long_integer": [("", 0, "i", "i32")],
    "long_enum": [("", 0, "i", "i32")],
    "long_flags": [("", 0, "I", "u32")],
    "long_block_flags": [("", 0, "I", "u32")],
    "long_block_index": [("", 0, "i", "i32")],
    "int64_integer": [("", 0, "q", "i64")],
    "string_id": [("", 0, "I", "sid")],
    "real": [("", 0, "f", "f32")],
    "angle": [("", 0, "f", "f32")],
    "real_fraction": [("", 0, "f", "f32")],
    "short_bounds": [(".lower", 0, "h", "i16"), (".upper", 2, "h", "i16")],
    "real_bounds": [(".lower", 0, "f", "f32"), (".upper", 4, "f", "f32")],
    "angle_bounds": [(".lower", 0, "f", "f32"), (".upper", 4, "f", "f32")],
    "fraction_bounds": [(".lower", 0, "f", "f32"), (".upper", 4, "f", "f32")],
    "real_point_2d": [(".x", 0, "f", "f32"), (".y", 4, "f", "f32")],
    "real_point_3d": [(".x", 0, "f", "f32"), (".y", 4, "f", "f32"), (".z", 8, "f", "f32")],
    "real_vector_3d": [(".i", 0, "f", "f32"), (".j", 4, "f", "f32"), (".k", 8, "f", "f32")],
    "real_euler_angles_2d": [(".yaw", 0, "f", "f32"), (".pitch", 4, "f", "f32")],
    "real_euler_angles_3d": [(".yaw", 0, "f", "f32"), (".pitch", 4, "f", "f32"), (".roll", 8, "f", "f32")],
    "real_rgb_color": [(".r", 0, "f", "f32"), (".g", 4, "f", "f32"), (".b", 8, "f", "f32")],
    "rgb_color": [("", 0, "I", "u32")],
    "tag": [("", 0, "I", "u32")],
    # tag_reference: only the datum index is a legal patch target; the other
    # three words are the group tag and the name pointer/length.
    "tag_reference": [(".group", 0, "I", "u32"), (".name_address", 4, "I", "u32"),
                      (".name_length", 8, "i", "i32"), (".datum", 12, "I", "u32")],
    # data reference: size / flags / stream position / address
    "data": [(".size", 0, "i", "i32"), (".flags", 4, "I", "u32"),
             (".stream", 8, "I", "u32"), (".address", 12, "I", "u32")],
    # block: count / address / definition
    "block": [(".count", 0, "i", "i32"), (".address", 4, "I", "u32"),
              (".definition", 8, "I", "u32")],
}

KIND_WIDTH = {"i8": 1, "u8": 1, "i16": 2, "u16": 2, "i32": 4, "u32": 4,
              "i64": 8, "u64": 8, "f32": 4, "sid": 4}
KIND_CODE = {"i8": "b", "u8": "B", "i16": "h", "u16": "H", "i32": "i",
             "u32": "I", "i64": "q", "u64": "Q", "f32": "f", "sid": "I"}

TEXT_TYPES = {"string": 32, "long_string": 256}

# Structs in the dump whose fields do not sum to their declared sizeof() with
# the table above. They are refused on use rather than silently mis-addressed.
KNOWN_BAD = (
    "scenario_light_struct", "ai_scene_block", "triggers_block",
    "order_completion_condition", "ai_scene_role_block",
    "scenario_cutscene_camera_point_block", "orders_block",
    "order_ending_block", "effect_gpu_data_block",
)


# ---------------------------------------------------------------------------
# field model
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class FieldDef:
    offset: int              # offset within the struct
    type: str                # definition type name
    raw_name: str            # name exactly as the dump spells it
    name: str                # name with #comment and trailing markers removed
    markers: str             # the trailing ^*!~ markers, if any
    comment: str             # the part after '#'
    size: int
    definition: object = None

    @property
    def runtime(self) -> bool:
        """'!' marks a field the engine derives; patching one desynchronises it."""
        return "!" in self.markers


def split_name(raw: str | None):
    raw = raw or ""
    head, _, comment = raw.partition("#")
    markers = ""
    while head and head[-1] in "^*!~":
        markers = head[-1] + markers
        head = head[:-1]
    return head.strip(), markers, comment.strip()


# ---------------------------------------------------------------------------
# the definition set
# ---------------------------------------------------------------------------

class TagDefs:
    def __init__(self, defs_dir: Path | str = DEFAULT_DEFS_DIR):
        self.dir = Path(defs_dir)
        if not self.dir.is_dir():
            raise DefsError("tag definition dump not found at %s" % self.dir)
        self.structs: dict = {}
        self.arrays: dict = {}
        self.blocks: dict = {}
        self.enums: dict = {}
        self.groups: dict = {}          # four-cc -> {"name","root_block","root_struct"}
        self.conflicts: list = []
        self._fields_cache: dict = {}
        files = sorted(self.dir.glob("*.json"))
        if not files:
            raise DefsError("no *.json definition files in %s" % self.dir)
        for path in files:
            if path.name == "_meta.json":
                continue
            try:
                d = json.loads(path.read_text())
            except Exception as exc:                       # noqa: BLE001
                raise DefsError("%s is not readable JSON: %s" % (path.name, exc))
            for key, store in (("structs", self.structs), ("arrays", self.arrays),
                               ("blocks", self.blocks), ("enums_flags", self.enums)):
                for k, v in (d.get(key) or {}).items():
                    if k in store and store[k] != v:
                        self.conflicts.append("%s %r differs between definition files" % (key, k))
                    store.setdefault(k, v)
            code = d.get("tag")
            root_block = d.get("block")
            if code and root_block and root_block in (d.get("blocks") or {}):
                self.groups[code] = {
                    "name": d.get("name"),
                    "root_block": root_block,
                    "root_struct": d["blocks"][root_block]["struct"],
                    "file": path.name,
                }

    # -- sizes ------------------------------------------------------------

    def field_size(self, fl: dict) -> int:
        t = fl["type"]
        if t in SIZES:
            return SIZES[t]
        if t in ("pad", "useless_pad"):
            return int(fl["definition"])
        if t == "struct":
            return self.struct_size(fl["definition"])
        if t == "array":
            a = self.arrays.get(fl["definition"])
            if a is None:
                raise DefsError("unknown array definition %r" % fl["definition"])
            return int(a["count"]) * self.struct_size(a["struct"])
        raise DefsError("unknown field type %r" % t)

    def struct_size(self, name: str) -> int:
        s = self.structs.get(name)
        if s is None:
            raise DefsError("unknown struct %r" % name)
        return int(s["size"])

    def validate_all(self):
        """Sum every struct's fields and compare with its declared sizeof()."""
        ok, bad = [], []
        for name in sorted(self.structs):
            try:
                total = sum(self.field_size(f) for f in self.structs[name]["fields"])
            except DefsError as exc:
                bad.append((name, str(exc)))
                continue
            if total == self.struct_size(name):
                ok.append(name)
            else:
                bad.append((name, "fields sum to 0x%X but sizeof() is 0x%X"
                            % (total, self.struct_size(name))))
        return ok, bad

    # -- fields -----------------------------------------------------------

    def fields_of(self, struct_name: str) -> list:
        """Validated, offset-resolved field list for one struct."""
        if struct_name in self._fields_cache:
            return self._fields_cache[struct_name]
        s = self.structs.get(struct_name)
        if s is None:
            raise DefsError("unknown struct %r" % struct_name)
        if struct_name in KNOWN_BAD:
            raise DefsError("struct %r does not validate against its own sizeof() in the "
                            "definition dump; its field offsets are not trustworthy and this "
                            "tool refuses to address into it" % struct_name)
        out, off, seen = [], 0, {}
        for fl in s["fields"]:
            size = self.field_size(fl)
            name, markers, comment = split_name(fl.get("name"))
            if name:
                seen[name] = seen.get(name, 0) + 1
                if seen[name] > 1:
                    name = "%s#%d" % (name, seen[name])
            out.append(FieldDef(off, fl["type"], fl.get("name") or "", name, markers,
                                comment, size, fl.get("definition")))
            off += size
        if off != self.struct_size(struct_name):
            raise DefsError("struct %r: fields sum to 0x%X, sizeof() is 0x%X"
                            % (struct_name, off, self.struct_size(struct_name)))
        self._fields_cache[struct_name] = out
        return out

    def block_struct(self, block_name: str) -> str:
        b = self.blocks.get(block_name)
        if b is None:
            raise DefsError("unknown block %r" % block_name)
        return b["struct"]

    def block_max_count(self, block_name: str):
        b = self.blocks.get(block_name)
        return None if b is None else b.get("max_count")

    def enum_label(self, definition, value):
        """Option name for an enum value, or a flag list, else ''."""
        if not isinstance(definition, str):
            return ""
        e = self.enums.get(definition)
        if not e or "options" not in e:
            return ""
        opts = e["options"]
        if 0 <= value < len(opts):
            return str(opts[value])
        return ""

    def flag_labels(self, definition, value):
        if not isinstance(definition, str):
            return ""
        e = self.enums.get(definition)
        if not e or "options" not in e:
            return ""
        hits = [o for i, o in enumerate(e["options"]) if value & (1 << i)]
        return "|".join(hits)

    def scalars_of(self, fd: FieldDef):
        """Expand one field into its patchable scalar sub-fields."""
        specs = _SCALARS.get(fd.type)
        if not specs:
            return []
        return [(fd.name + suffix, fd.offset + rel, code, kind)
                for (suffix, rel, code, kind) in specs]


def read_scalar(data: bytes, offset: int, endian: str, kind: str):
    code = KIND_CODE[kind]
    width = KIND_WIDTH[kind]
    if offset < 0 or offset + width > len(data):
        raise DefsError("read of %s at 0x%X is outside the %d-byte file" % (kind, offset, len(data)))
    return struct.unpack_from(endian + code, data, offset)[0]


def pack_scalar(endian: str, kind: str, value):
    code = KIND_CODE[kind]
    if kind == "f32":
        return struct.pack(endian + code, float(value))
    value = int(value)
    width = KIND_WIDTH[kind]
    if code.islower():
        lo, hi = -(1 << (width * 8 - 1)), (1 << (width * 8 - 1)) - 1
    else:
        lo, hi = 0, (1 << (width * 8)) - 1
    if not (lo <= value <= hi):
        raise DefsError("value %d does not fit a %s field (range %d..%d); a wider write would "
                        "change the size of the field and is refused" % (value, kind, lo, hi))
    return struct.pack(endian + code, value)


if __name__ == "__main__":
    defs = TagDefs()
    ok, bad = defs.validate_all()
    print("definition dump: %s" % defs.dir)
    print("structs validated against their own sizeof(): %d" % len(ok))
    print("structs refused: %d" % len(bad))
    for name, why in bad:
        print("  !! %-44s %s" % (name, why))
    print("tag groups with a usable root struct: %s" % ", ".join(sorted(defs.groups)))
    for conflict in defs.conflicts:
        print("  ?? %s" % conflict)
