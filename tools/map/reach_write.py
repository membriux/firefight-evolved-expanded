#!/usr/bin/env python3
"""Write support for Halo: Reach (MCC) `.map` cache files.

Companion to ``reach_cache.py`` (the reader). This module can

1. re-encode every field the reader parses, back over the original bytes, and
   prove the result is byte-identical (the "round-trip gate");
2. recompute the header checksum exactly as Assembly does;
3. patch bytes inside a tag in place (same size);
4. grow the tag data area and relocate a tag or a table into the new space,
   fixing up every count, pointer, section, offset mask and partition that the
   move invalidates.

Integrity model, from Assembly (``Blam/ICacheFile.cs`` ``GenerateChecksum``,
``Blam/ThirdGen/ThirdGenCacheFile.cs`` ``SaveChanges``/``WriteHeader``):

* the only whole-file integrity value in a Reach cache is the header
  ``checksum`` int32 = XOR of every little-endian uint32 from ``header_size``
  (0xA000) to EOF, tail zero-padded to a 4-byte multiple;
* there is no signature, no per-tag hash and no hash over the tag data area;
* the only SHA-1 hashes in a Reach cache are the two per-language locale
  hashes in the ``matg`` tag ("index table hash", "string data hash", 0x14
  bytes each) and the three resource-page hashes in the resource layouts.
  Neither covers tag data. Editing a tag does not invalidate them.

STATUS (2026-11-23). The round-trip gate, same-size patching and tag-area
growth have all been run against real Halo: Reach MCC caches (ff50_park,
ff70_holdout) and cross-checked by loading the output through Blamite, the
reference implementation. See ``verify_with_blamite()`` below.

**Our own reader accepting an output is NOT evidence that the output is well
formed.** Four earlier grown caches reparsed with zero warnings and a valid
checksum and were still rejected by Blamite. Run ``verify_with_blamite()`` (or
``--blamite-gate``) on every file this module writes before trusting it.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path

import reach_cache as rc
from reach_cache import MapFormatError, ReachCacheFile, TagEntry

SECTION_DEBUG = rc.SECTION_DEBUG
SECTION_RESOURCE = rc.SECTION_RESOURCE
SECTION_TAG = rc.SECTION_TAG
SECTION_LOCALE = rc.SECTION_LOCALE

# Assembly: new MetaAllocator(this, 0x10000) for third-gen caches, and
# <segmentAlignment>0x1000</segmentAlignment> for every Reach MCC engine.
ALLOC_PAGE = 0x10000
SEGMENT_ALIGN = 0x1000

# Header fields that hold a *pointer into the debug (string) section*, i.e.
# file offset = stored + offset_masks[debug]. Assembly writes these in
# ThirdGenHeader.Serialize via SegmentPointer.AsPointer().
DEBUG_POINTER_FIELDS = (
    "string_index_table_offset",
    "string_table_offset",
    "string_namespace_table_offset",
    "file_index_table_offset",
    "file_table_offset",
)


class WriteError(MapFormatError):
    """A requested edit cannot be made safely."""


def align_up(value: int, alignment: int) -> int:
    return (value + alignment - 1) & ~(alignment - 1)


@dataclass
class GrowthResult:
    mode: str
    requested: int
    granted: int          # bytes actually inserted (page-aligned)
    free_offset: int      # file offset of the new free space
    free_address: int     # virtual address of the new free space
    new_meta_size: int
    new_virtual_base: int


class CacheWriter:
    """Mutates a copy of a parsed cache file.

    The writer never regenerates the 0xA000 header from scratch: most of it is
    padding and fields no public layout describes. It overwrites only the
    fields the reader understands, which is also what Assembly does.
    """

    def __init__(self, cache: ReachCacheFile):
        self.cache = cache
        self.v = cache.variant
        self.e = cache.endian
        self.buf = bytearray(cache.data)
        self.header_size = self.v.header_size
        # live copies of the structures we may have to rewrite
        self.header = dict(cache.header)
        self.sections = [list(s) for s in cache.sections]
        self.masks = list(cache.offset_masks)
        self.partitions = [[p["load_address"], p["size"]] for p in cache.partitions]
        self.index_header = dict(cache.index_header)
        self.meta_offset = cache.meta_offset
        self.meta_size = cache.meta_size
        self.virtual_base = cache.virtual_base
        self.log: list[str] = []

    # -- primitives ---------------------------------------------------------

    def _fmt(self, kind: str) -> str:
        return self.e + rc._KIND_FMT[kind]

    def _put(self, kind: str, offset: int, value: int):
        size = rc._KIND_SIZE[kind]
        if offset < 0 or offset + size > len(self.buf):
            raise WriteError("write of %s at 0x%X is outside the %d-byte file"
                             % (kind, offset, len(self.buf)))
        mask = (1 << (size * 8)) - 1
        if kind.startswith("i"):
            # allow callers to pass unsigned values for signed fields
            # (the checksum is declared int32 but is a bit pattern)
            value = value & mask
            struct.pack_into(self.e + {2: "H", 4: "I", 8: "Q"}[size], self.buf, offset, value)
        else:
            struct.pack_into(self._fmt(kind), self.buf, offset, value & mask)

    def patch(self, offset: int, blob: bytes):
        """Overwrite ``len(blob)`` bytes at a file offset."""
        if offset < 0 or offset + len(blob) > len(self.buf):
            raise WriteError("patch of %d bytes at 0x%X is outside the %d-byte file"
                             % (len(blob), offset, len(self.buf)))
        self.buf[offset:offset + len(blob)] = blob

    def put_header(self, name: str, value):
        spec = self.v.fields.get(name)
        if spec is None:
            raise WriteError("header field %r does not exist in layout %s" % (name, self.v.name))
        kind, off = spec
        if kind == "str":
            window = self.v.str_window(name)
            blob = str(value).encode("ascii")[:window - 1] + b"\x00"
            # Only the string and its NUL are written. Bytes after the NUL are
            # left alone so that re-encoding a parsed value is byte-identical
            # even when the original had junk after the terminator.
            self.buf[off:off + len(blob)] = blob
        else:
            self._put(kind, off, int(value))
        self.header[name] = value

    def put_section(self, index: int, vaddr: int, size: int):
        base = self.v.sections + index * 8
        self._put("u32", base, vaddr)
        self._put("u32", base + 4, size)
        self.sections[index] = [vaddr, size]

    def put_mask(self, index: int, value: int):
        self._put("u32", self.v.offset_masks + index * 4, value)
        self.masks[index] = value

    def put_partition(self, index: int, address: int, size: int):
        off, count, entry, kind = self.v.partitions
        if index >= count:
            raise WriteError("partition %d does not exist" % index)
        base = off + index * entry
        self._put(kind, base, address)
        self._put(kind, base + rc._KIND_SIZE[kind], size)
        self.partitions[index] = [address, size]

    def put_index_field(self, name: str, value: int):
        """Write a field of the tag index header (counts and table addresses)."""
        spec = self.v.index_header
        ioff = self.offset_of(self.header["index_header_address"])
        layout = {
            "group_count": ("i32", spec.group_count),
            "group_table_address": (spec.ptr_kind, spec.group_table),
            "tag_count": ("i32", spec.tag_count),
            "tag_table_address": (spec.ptr_kind, spec.tag_table),
            "global_count": ("i32", spec.global_count),
            "global_table_address": (spec.ptr_kind, spec.global_table),
            "interop_count": ("i32", spec.interop_count),
            "interop_table_address": (spec.ptr_kind, spec.interop_table),
        }
        if name not in layout:
            raise WriteError("unknown index header field %r" % name)
        kind, rel = layout[name]
        self._put(kind, ioff + rel, value)
        self.index_header[name] = value

    def put_tag_entry(self, tag: TagEntry):
        """Write one 8-byte tag table element from a TagEntry."""
        table = self.offset_of(self.index_header["tag_table_address"])
        rec = table + tag.index * 8
        self._put("i16", rec + 0, tag.group_index)
        self._put("u16", rec + 2, tag.salt)
        self._put("u32", rec + 4, tag.raw_address)

    # -- address arithmetic (mirrors the reader, with the writer's own state) -

    def contract(self, address: int) -> int:
        if not self.v.expand_magic:
            return address
        if address == 0:
            return 0
        if address < self.v.expand_magic:
            raise WriteError("address 0x%X is below the expand magic 0x%X and cannot be contracted"
                             % (address, self.v.expand_magic))
        if (address - self.v.expand_magic) & 3:
            raise WriteError("address 0x%X is not 4-byte aligned; contraction would lose bits" % address)
        stored = (address - self.v.expand_magic) >> 2
        if stored > 0xFFFFFFFF:
            raise WriteError("address 0x%X does not fit in a contracted 32-bit pointer" % address)
        return stored

    def expand(self, stored: int) -> int:
        if not self.v.expand_magic or stored == 0:
            return stored
        return (stored << 2) + self.v.expand_magic

    def offset_of(self, address: int) -> int:
        return address - self.virtual_base + self.meta_offset

    def address_of(self, offset: int) -> int:
        return offset - self.meta_offset + self.virtual_base

    def area_offset(self, section: int) -> int:
        """File offset of an interop section (rule 1: vaddr + mask).

        The sum MUST be truncated to 32 bits, exactly as the reader does
        (``reach_cache`` ``_read_header``). On a real MCC cache the mask is a
        wrapping 32-bit delta and is usually "negative": ff50_park's debug
        section is vaddr 0x0B409000 + mask 0xF4C01000 = 0x1_0000A000, i.e.
        file offset 0xA000. Without the truncation every section looks as if
        it lived past 0x1_00000000, so ``grow_tag_area`` believed the debug
        section (string-id and tag-name tables) sat after the tag area and
        shifted it, which silently destroyed all 14034 tag names.
        """
        return (self.sections[section][0] + self.masks[section]) & 0xFFFFFFFF

    # -- checksum -----------------------------------------------------------

    def compute_checksum(self) -> int:
        """XOR of every uint32 after the header. Assembly: GenerateChecksum."""
        return checksum_of(self.buf, self.header_size, self.e)

    def update_checksum(self) -> int:
        value = self.compute_checksum()
        self.put_header("checksum", value)
        return value

    def verify_checksum(self):
        stored = self.header.get("checksum")
        stored = None if stored is None else stored & 0xFFFFFFFF
        computed = self.compute_checksum()
        return stored, computed, stored == computed

    # -- the round-trip gate ------------------------------------------------

    def reencode_all(self):
        """Write every parsed value back where it came from.

        If the file changes, decode and encode disagree somewhere: a wrong
        field kind, offset, endianness or a broken pointer contraction. This is
        the gate that must pass before any modification is trusted.
        """
        c = self.cache
        for name in self.v.fields:
            if name in c.header and c.header[name] is not None:
                self.put_header(name, c.header[name])
        for i, (vaddr, size) in enumerate(c.sections):
            self.put_section(i, vaddr, size)
        for i, mask in enumerate(c.offset_masks):
            self.put_mask(i, mask)
        for i, p in enumerate(c.partitions):
            self.put_partition(i, p["load_address"], p["size"])
        for name in ("group_count", "group_table_address", "tag_count", "tag_table_address",
                     "global_count", "global_table_address", "interop_count", "interop_table_address"):
            if name in c.index_header:
                self.put_index_field(name, c.index_header[name])
        for tag in c.tags:
            self.put_tag_entry(tag)
        return bytes(self.buf)

    # -- same-size edits ----------------------------------------------------

    def patch_tag(self, tag: TagEntry, blob: bytes, at: int = 0):
        """Overwrite bytes inside a tag. ``at`` is an offset inside the tag."""
        if tag.offset is None:
            raise WriteError("tag %d (%s) has no data in this map (null address)"
                             % (tag.index, tag.group_code))
        if tag.size is not None and at + len(blob) > tag.size:
            raise WriteError("patch of %d bytes at +0x%X exceeds tag %d's ESTIMATED extent 0x%X; "
                             "extents are inferred, so this may be a false alarm - pass a smaller "
                             "slice or relocate the tag instead"
                             % (len(blob), at, tag.index, tag.size))
        self.patch(tag.offset + at, blob)
        self.log.append("patched %d bytes at tag %d (%s) +0x%X"
                        % (len(blob), tag.index, tag.group_code, at))

    def patch_tag_field(self, tag: TagEntry, at: int, kind: str, value: int):
        """Write one scalar inside a tag (a price, a count, a timer)."""
        self.patch_tag(tag, struct.pack(self._fmt(kind), value), at)

    # -- growth -------------------------------------------------------------

    def grow_tag_area(self, size: int, mode: str = "end", page: int = ALLOC_PAGE) -> GrowthResult:
        """Insert free space into the tag data area and fix up the header.

        ``mode="end"``   new space goes after the last byte of the tag area.
                         Every existing virtual address stays valid; anything
                         stored after the tag area in the file shifts forward.
                         On ff50_park and ff70_holdout that is the localization
                         section, NOT the debug section: both maps place the
                         debug section (string-id and tag-name tables) before
                         the tag area. Never assume which section follows -
                         the code reads it from the section table.
        ``mode="beginning"`` mirrors Assembly exactly: space is inserted at the
                         start of the tag area and the virtual base is
                         decremented by the same amount, so existing addresses
                         still resolve ("the meta segment grows downward in
                         memory" - MetaAddressConverter.MetaResized).
        """
        if size <= 0:
            raise WriteError("grow_tag_area needs a positive size")
        if mode not in ("end", "beginning"):
            raise WriteError("mode must be 'end' or 'beginning'")
        # Assembly expands the meta area in allocator pages (0x10000) and the
        # segment itself is aligned to <segmentAlignment> (0x1000). ``page``
        # exists so a caller can ask for the minimum legal granularity.
        delta = align_up(align_up(size, max(page, 1)), SEGMENT_ALIGN)

        insert_at = self.meta_offset + self.meta_size if mode == "end" else self.meta_offset

        # Record the file offsets of everything that is addressed by a *file
        # offset* (as opposed to a virtual address) before the insertion.
        old_area_offsets = [self.area_offset(i) for i in range(4)]
        old_table_offsets = {}
        for name in DEBUG_POINTER_FIELDS:
            if name in self.v.fields and self.header.get(name) is not None:
                # same wrapping-mask rule as area_offset(): truncate to 32 bits
                old_table_offsets[name] = (self.header[name]
                                           + self.masks[SECTION_DEBUG]) & 0xFFFFFFFF

        # 1. insert the bytes
        self.buf[insert_at:insert_at] = b"\x00" * delta

        # 2. the tag area itself
        if mode == "end":
            new_meta_offset = self.meta_offset
            new_virtual_base = self.virtual_base
            free_offset = insert_at
        else:
            new_meta_offset = self.meta_offset
            new_virtual_base = self.virtual_base - delta
            if self.v.expand_magic and new_virtual_base < self.v.expand_magic + 4:
                raise WriteError(
                    "growing downward by 0x%X would drop the virtual base to 0x%X, below the "
                    "expand magic 0x%X: contracted pointers could not be encoded. Use mode='end'."
                    % (delta, new_virtual_base, self.v.expand_magic))
            free_offset = insert_at
        self.meta_offset = new_meta_offset
        self.virtual_base = new_virtual_base
        self.meta_size = self.meta_size + delta

        # 3. areas and tables that moved
        new_area_offsets = [off + delta if off >= insert_at else off
                            for off in old_area_offsets]
        # the tag area's own start never moves in either mode
        new_area_offsets[SECTION_TAG] = self.meta_offset

        # 4. sections and masks.
        #
        #    A section's file offset is vaddr + mask (mod 2^32), so when a
        #    section's data moves in the file that identity can be restored
        #    either by moving the vaddr or by moving the mask. ONLY THE MASK IS
        #    CORRECT. Everything that points *into* a section is stored as a
        #    pointer in that section's virtual address space, and Blamite
        #    resolves such a pointer with
        #
        #        file offset = pointer - section.vaddr + (section.vaddr + mask)
        #                    = pointer + mask
        #
        #    (``BasedPointerConverter.PointerToOffset``): the vaddr cancels.
        #    Bumping the vaddr therefore moves the section header's idea of
        #    where the section starts while leaving every pointer inside it
        #    resolving to the OLD file offset.
        #
        #    That is exactly how `Segment size is too large` was produced. The
        #    localization pointers live in the `matg` tag (per language:
        #    "locale index table offset", "locale data index offset"), and
        #    nothing rewrites them. After a 0x10000 "end" growth of Holdout the
        #    tag data segment declared 0x6F00000 bytes from file 0x1FFE000
        #    while language 0's locale index table was still resolved to file
        #    0x8EEE000 -- 0x6EF0000 away -- so Blamite's FileSegmenter found the
        #    tag segment overrunning its neighbour by exactly the growth delta
        #    and threw in ThirdGenLanguage.Load.
        #
        #    Keeping every vaddr fixed and letting the mask absorb the file
        #    movement keeps all three pointer spaces (tag, debug, locale) valid
        #    without rewriting a single pointer. On a zero-mask cache (the
        #    synthetic fixtures) a moved section simply acquires a non-zero
        #    mask, which is still the rule-1 identity.
        sizes = {SECTION_TAG: self.meta_size}
        for i in range(4):
            vaddr, size = self.sections[i]
            if vaddr == 0 and size == 0:
                continue
            new_size = sizes.get(i, size)
            if new_size != size:
                self.put_section(i, vaddr, new_size)
            moved = new_area_offsets[i] - old_area_offsets[i]
            if moved:
                self.put_mask(i, (self.masks[i] + moved) & 0xFFFFFFFF)
                self.log.append("section %d moved 0x%X in the file: mask 0x%08X -> 0x%08X, "
                                "vaddr 0x%08X kept so its pointers stay valid"
                                % (i, moved, (self.masks[i] - moved) & 0xFFFFFFFF,
                                   self.masks[i], vaddr))

        # 5. header fields
        if "virtual_size" in self.v.fields:
            self.put_header("virtual_size", self.meta_size)
        if "tag_buffer_offset" in self.v.fields:
            # The header's "tag buffer offset" holds the tag section's VIRTUAL
            # address, not its file offset: on ff50_park it reads 0x03CE9000,
            # which is sections[tag].vaddr, while vaddr+mask is file 0x2925000.
            # They coincide only on caches whose masks are zero, which is why
            # the synthetic fixtures never caught this.
            self.put_header("tag_buffer_offset", self.sections[SECTION_TAG][0])
        if "virtual_base_address" in self.v.fields:
            self.put_header("virtual_base_address", self.virtual_base)
        if "file_size" in self.v.fields:
            self.put_header("file_size", len(self.buf))
        # index_header_address is deliberately NOT touched. In "end" mode
        # nothing inside the tag area moved. In "beginning" mode the index
        # header moved forward in the file by exactly the amount the virtual
        # base moved down, so its stored address still resolves. Same reasoning
        # applies to every tag address and every in-tag pointer.
        # The five debug-section tables are header fields holding POINTERS, so
        # their value is (file offset - mask). Step 4 already moved the debug
        # mask by however far the debug section moved, which makes this loop a
        # no-op in that case - it is kept because it is also the correct answer
        # when only one of the two moves, and because it asserts the identity.
        for name, old_off in old_table_offsets.items():
            new_off = old_off + delta if old_off >= insert_at else old_off
            self.put_header(name, (new_off - self.masks[SECTION_DEBUG]) & 0xFFFFFFFF)

        # 6. partitions (Assembly: ThirdGenHeader.AdjustPartitions)
        self._adjust_partitions()

        # 7. checksum last
        self.update_checksum()
        self.log.append("grew tag area by 0x%X bytes (mode=%s); free space at file 0x%X, address 0x%X"
                        % (delta, mode, free_offset, self.address_of(free_offset)))
        return GrowthResult(mode=mode, requested=size, granted=delta,
                            free_offset=free_offset,
                            free_address=self.address_of(free_offset),
                            new_meta_size=self.meta_size,
                            new_virtual_base=self.virtual_base)

    def _adjust_partitions(self):
        off, count, entry, kind = self.v.partitions
        if not self.partitions:
            return
        # partition 0's load address is the tag area's base address
        first_addr, first_size = self.partitions[0]
        if first_addr:
            self.put_partition(0, self.virtual_base, first_size)
        partition_end = self.meta_offset + self.meta_size
        for i in range(count - 1, -1, -1):
            addr, size = self.partitions[i]
            if not addr:
                continue
            start = self.offset_of(addr)
            self.put_partition(i, addr, partition_end - start)
            partition_end = start

    # -- relocation (this is what "growing a tag" means) --------------------

    def relocate_tag(self, tag: TagEntry, blob: bytes, mode: str = "end",
                     page: int = ALLOC_PAGE) -> int:
        """Move a tag's data to fresh space at the end of the tag area.

        Returns the tag's new virtual address. The old bytes are zeroed, which
        is what Assembly's allocator does when it frees a block. The caller is
        responsible for fixing any pointer *inside* ``blob`` that was relative
        to the old address: ``shift_internal_pointers`` does the common case.
        """
        if tag.offset is None:
            raise WriteError("cannot relocate tag %d: it has no data in this map" % tag.index)
        old_offset, old_size = tag.offset, tag.size or len(blob)
        growth = self.grow_tag_area(len(blob), mode=mode, page=page)
        dest = growth.free_offset
        self.patch(dest, blob)
        # zero the vacated space
        self.patch(old_offset if mode == "end" else old_offset + growth.granted,
                   b"\x00" * old_size)
        new_address = self.address_of(dest)
        tag.raw_address = self.contract(new_address)
        tag.address = new_address
        tag.offset = dest
        tag.size = len(blob)
        self.put_tag_entry(tag)
        self.update_checksum()
        self.log.append("relocated tag %d (%s) to address 0x%X (file 0x%X), size 0x%X -> 0x%X"
                        % (tag.index, tag.group_code, new_address, dest, old_size, len(blob)))
        return new_address

    def relocate_table(self, index_field_addr: str, index_field_count: str,
                       blob: bytes, count: int, mode: str = "end",
                       page: int = ALLOC_PAGE) -> int:
        """Move one of the index header's tables into fresh space and repoint it.

        This is the exact operation a script-table rewrite needs: allocate,
        write, repoint, update the count.
        """
        growth = self.grow_tag_area(len(blob), mode=mode, page=page)
        dest = growth.free_offset
        self.patch(dest, blob)
        address = self.address_of(dest)
        self.put_index_field(index_field_addr, address)
        self.put_index_field(index_field_count, count)
        self.update_checksum()
        self.log.append("relocated %s to address 0x%X (file 0x%X), %d elements"
                        % (index_field_addr, address, dest, count))
        return address

    def shift_internal_pointers(self, blob: bytes, old_base: int, new_base: int,
                                pointer_offsets) -> bytes:
        """Re-point contracted pointers inside a moved blob.

        ``pointer_offsets`` are byte offsets inside ``blob`` holding contracted
        32-bit pointers that pointed *into the blob itself*.
        """
        out = bytearray(blob)
        for off in pointer_offsets:
            stored = struct.unpack_from(self._fmt("u32"), out, off)[0]
            if stored == 0:
                continue
            address = self.expand(stored)
            moved = address - old_base + new_base
            struct.pack_into(self._fmt("u32"), out, off, self.contract(moved))
        return bytes(out)

    # -- output -------------------------------------------------------------

    def bytes(self) -> bytes:
        return bytes(self.buf)

    def save(self, path, gate: bool = True) -> int:
        """Write the cache out, but only if Blamite will load it.

        The bytes go to a sibling temporary file first; the file at ``path``
        appears only after Blamite, the reference implementation, has loaded
        the result without throwing. A cache our own reader accepts and the
        game's own library rejects is worse than no cache, so a rejection
        raises and leaves nothing behind.

        ``gate=False`` skips the check. Use it only for synthetic fixtures,
        which are not real caches and which Blamite cannot load by design.
        """
        data = self.bytes()
        path = Path(path)
        if not gate:
            path.write_bytes(data)
            return len(data)

        tmp = path.with_name(path.name + ".blamite-gate.tmp")
        tmp.write_bytes(data)
        try:
            require_blamite_load(tmp, display_name=str(path))
        except BaseException:
            tmp.unlink(missing_ok=True)
            raise
        tmp.replace(path)
        self.log.append("Blamite gate passed; wrote %d bytes to %s" % (len(data), path))
        return len(data)

    def reparse(self) -> ReachCacheFile:
        """Parse what we have written, with the reader, from scratch."""
        return ReachCacheFile(self.bytes(), path=self.cache.path,
                              force_variant=self.v.name if self.cache.detection.startswith("forced") else None)


# ---------------------------------------------------------------------------
# The Blamite gate
#
# Our reader agreeing with our writer proves only that the two are consistent.
# Four grown caches passed that test with zero warnings and a valid checksum and
# were still rejected by Blamite with "Segment size is too large" (see
# research/19-holdout-retarget.md). The reference implementation is the only
# authority this module trusts, so every file it writes is loaded through it.
#
# The gate shells out to tools/compile's `hsc-compile --load-only <map>`, which
# calls Blamite's CacheFileLoader.LoadCacheFile and exits non-zero on any
# exception.
# ---------------------------------------------------------------------------

#: Path to hsc-compile.dll. Overrides the search below.
DRIVER_ENV = "FFEE_HSC_COMPILE"
#: Path to Blamite's Formats directory. Overrides the search below.
FORMATS_ENV = "BLAMITE_FORMATS"
#: Set to "off"/"0"/"no" to allow writing an unverified cache. Last resort.
GATE_ENV = "FFEE_BLAMITE_GATE"


class BlamiteRejected(WriteError):
    """Blamite refused to load a cache this module produced."""


def gate_disabled() -> bool:
    import os
    return os.environ.get(GATE_ENV, "").strip().lower() in ("off", "0", "no", "false")


def find_blamite_driver():
    """Locate hsc-compile.dll and Blamite's Formats dir, or return (None, None)."""
    import os
    env_driver = os.environ.get(DRIVER_ENV)
    candidates = []
    if env_driver:
        candidates.append(Path(env_driver))
    here = Path(__file__).resolve()
    for parent in here.parents:
        candidates.append(parent / "tools" / "compile" / "bin" / "Release" / "net8.0" / "hsc-compile.dll")
    driver = next((c for c in candidates if c.is_file()), None)
    if driver is None:
        return None, None

    env_formats = os.environ.get(FORMATS_ENV)
    formats = None
    for c in ([Path(env_formats)] if env_formats else []) + [driver.parent / "Formats"]:
        if (c / "Engines.xml").is_file():
            formats = c
            break
    return driver, formats


def blamite_load(path, timeout: int = 900):
    """Load ``path`` through Blamite. Returns (ok, detail).

    ``ok`` is None when the check could not be run at all (no driver, no
    dotnet): that is not a pass, and callers must not treat it as one.
    """
    import os
    import subprocess

    driver, formats = find_blamite_driver()
    if driver is None:
        return None, ("hsc-compile.dll not found. Build it with tools/compile/build.sh "
                      "--build-only, or set %s to its path." % DRIVER_ENV)
    if formats is None:
        return None, ("Blamite's Formats directory not found next to %s; set %s."
                      % (driver, FORMATS_ENV))

    env = dict(os.environ)
    env.setdefault("DOTNET_ROLL_FORWARD", "LatestMajor")
    env.setdefault("DOTNET_CLI_TELEMETRY_OPTOUT", "1")
    env.setdefault("DOTNET_NOLOGO", "1")
    cmd = ["dotnet", str(driver), "--formats", str(formats), "--load-only", "--map", str(path)]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
    except FileNotFoundError:
        return None, "dotnet is not on PATH; cannot run the Blamite gate."
    except subprocess.TimeoutExpired:
        return False, "Blamite did not finish within %ds" % timeout

    out = (p.stdout or "") + (p.stderr or "")
    if p.returncode == 0 and "LOAD: OK" in out:
        return True, out.strip()
    interesting = [ln for ln in out.splitlines()
                   if ln.startswith("FATAL") or "Exception" in ln or "ERROR" in ln]
    return False, "\n".join(interesting) or out.strip()


def require_blamite_load(path, display_name=None):
    """Raise unless Blamite loads ``path``."""
    name = display_name or str(path)
    ok, detail = blamite_load(path)
    if ok:
        return detail
    if ok is None:
        if gate_disabled():
            return ("GATE SKIPPED (%s is off): %s - this cache is UNVERIFIED."
                    % (GATE_ENV, detail))
        raise BlamiteRejected(
            "refusing to write %s: the Blamite gate could not be run, so the cache is "
            "unverified. %s  Set %s=off to write it anyway, and do not ship the result."
            % (name, detail, GATE_ENV))
    if gate_disabled():
        return "GATE FAILED but %s is off: %s" % (GATE_ENV, detail)
    raise BlamiteRejected(
        "Blamite REJECTED %s, so it was not written. Our reader accepting a cache is not "
        "evidence that it is well formed.\n%s" % (name, detail))


def checksum_of(data, header_size: int, endian: str = "<") -> int:
    """XOR every uint32 after ``header_size``; tail zero-padded.

    Assembly ``CacheFileExtensions.GenerateChecksum`` (Blam/ICacheFile.cs:229).
    """
    tail = bytes(data[header_size:])
    if len(tail) % 4:
        tail += b"\x00" * (4 - len(tail) % 4)
    acc = 0
    fmt = endian + "%dI" % (len(tail) // 4)
    for word in struct.unpack(fmt, tail):
        acc ^= word
    return acc & 0xFFFFFFFF


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(
        description="Write/patch a Halo: Reach MCC .map cache file (synthetic-only validation; "
                    "see research/13-map-write-feasibility.md before using on a real map).")
    ap.add_argument("map", nargs="?", help="path to a .map file")
    ap.add_argument("--variant", help="force a header layout (mcc-u8+, mcc-u3, mcc-2019, xbox360)")
    ap.add_argument("--verify-checksum", action="store_true",
                    help="compare the stored header checksum with the recomputed one. "
                         "On a real map this is the single most valuable test in this tool: "
                         "if they match, the checksum algorithm is confirmed.")
    ap.add_argument("--round-trip", action="store_true",
                    help="re-encode every parsed field and report whether the file is unchanged")
    ap.add_argument("--blamite-gate", action="store_true",
                    help="load the map through Blamite (the reference implementation) and report "
                         "whether it accepts it. This is the ONLY pass condition for a modified "
                         "cache; our own reader's approval is not evidence.")
    ap.add_argument("--self-test", action="store_true", help="run the writer self-test")
    args = ap.parse_args(argv)

    if args.self_test:
        import test_reach_write
        return test_reach_write.run()

    if not args.map:
        ap.error("a map path is required unless --self-test is given")

    if args.blamite_gate:
        ok, detail = blamite_load(args.map)
        print("blamite gate      %s" % {True: "PASS - Blamite loads this cache",
                                        False: "FAIL - Blamite rejects this cache",
                                        None: "COULD NOT RUN (not a pass)"}[ok])
        if detail:
            print(detail)
        if ok is not True:
            return 3
        if not args.verify_checksum and not args.round_trip:
            return 0

    cache = ReachCacheFile.from_path(args.map, force_variant=args.variant)
    w = CacheWriter(cache)
    status = 0

    if args.verify_checksum or not args.round_trip:
        stored, computed, ok = w.verify_checksum()
        print("stored checksum   0x%08X" % (stored or 0))
        print("computed checksum 0x%08X" % computed)
        print("match             %s" % ("YES - the XOR-after-header algorithm is confirmed on this file"
                                        if ok else "NO"))
        if not ok:
            print("   Either this map was built by a tool that leaves the field stale (MCC itself "
                  "sometimes ships zeroed checksums), or the algorithm differs for this build.")
            status = max(status, 1)

    if args.round_trip:
        before = cache.data
        after = w.reencode_all()
        if before == after:
            print("round-trip        IDENTICAL (%d bytes)" % len(after))
        else:
            diffs = [i for i in range(min(len(before), len(after))) if before[i] != after[i]]
            print("round-trip        DIFFERS at %d byte(s), first at 0x%X" % (len(diffs), diffs[0]))
            status = max(status, 2)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
