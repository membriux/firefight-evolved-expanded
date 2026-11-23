#!/usr/bin/env python3
"""
blf.py -- reader/writer for Halo: Reach (MCC) game-variant BLF containers (.bin).

Scope: the *container* and the `chdr` content header. The Megalo bit-stream
inside `mpvr` is treated as an opaque blob; this library only recomputes the
`mpvr` integrity header that wraps it.

Everything in CONFIRMED comments below was verified byte-for-byte against the
two reference files:
    reference/Firefight Evolved.bin
    reference/Firefight Corvette Evolved.bin
Anything marked INFERENCE comes from prior art (ReachVariantEditor by
DavidJCobb, Blam-Network/blf, ManagedDonkey, TagTool) and was *not* provable
from those two files alone.

Chunk layout of a Reach MCC variant:

    offset  chunk  size    ver  minor  meaning
    0x0000  _blf      48     1      2  start of file
    0x0030  chdr     704    10      2  content header (title, desc, author...)
    0x02f0  mpvr   20520    54      1  game variant (hash header + bitstream)
    0x5318  _eof      17     1      1  end of file (authentication_type = 0)
    0x5329  _fsm     464     1      1  MCC fileshare metadata (signed, opaque)

Usage:
    from blf import BlfFile
    f = BlfFile.from_path("Firefight Evolved.bin")
    f.title = "MY VARIANT"
    f.description = "Hello."
    f.to_path("out.bin")            # integrity fields recomputed automatically

Self-test:
    python3 -I blf.py
"""

from __future__ import annotations

import hashlib
import os
import struct
import sys
from dataclasses import dataclass, field
from typing import List, Optional

__all__ = [
    "BlfError",
    "Chunk",
    "ContentHeader",
    "AuthorBlock",
    "BlfFile",
    "FILE_TYPE_GAME_VARIANT",
    "AUTH_TYPE_NONE",
]

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CHUNK_HEADER_SIZE = 12

# chdr file_type enum. Source: ReachVariantEditor formats/ugc_header.h.
# CONFIRMED: both reference files carry 6.
FILE_TYPE_NONE = -1
FILE_TYPE_DLC = 0
FILE_TYPE_CAMPAIGN_SAVE = 1
FILE_TYPE_SCREENSHOT = 2
FILE_TYPE_FILM = 3
FILE_TYPE_FILM_CLIP = 4
FILE_TYPE_MAP_VARIANT = 5
FILE_TYPE_GAME_VARIANT = 6
FILE_TYPE_PLAYLIST = 7

# _eof authentication_type enum. Source: ManagedDonkey network_blf.hpp,
# TagTool Blf.cs. CONFIRMED: both reference files use 0 (none), giving a
# 5-byte payload and a 17-byte chunk.
AUTH_TYPE_NONE = 0
AUTH_TYPE_CRC = 1
AUTH_TYPE_SHA1 = 2
AUTH_TYPE_RSA = 3

_AUTH_EXTRA_BYTES = {
    AUTH_TYPE_NONE: 0,
    AUTH_TYPE_CRC: 4,
    AUTH_TYPE_SHA1: 20,
    AUTH_TYPE_RSA: 256,
}

# chdr: title and description are fixed buffers of 128 UTF-16LE code units
# (256 bytes) each, NUL-terminated, zero-padded to the end of the buffer.
# CONFIRMED: title at payload 0x084, description at payload 0x184; in both
# reference files every byte after the NUL terminator is zero.
UGC_STRING_CODE_UNITS = 128
UGC_STRING_BYTES = UGC_STRING_CODE_UNITS * 2
MAX_STRING_CHARS = UGC_STRING_CODE_UNITS - 1  # leave room for the NUL

# chdr payload field offsets (little-endian in MCC files).
_CH_BUILD_MAJOR = 0x000  # u16
_CH_BUILD_MINOR = 0x002  # u16
_CH_FILE_TYPE = 0x004  # s8 + 3 pad
_CH_FILE_SIZE = 0x008  # u32  CONFIRMED = byte count through end of _eof
_CH_UNIQUE_ID = 0x00C  # u64
_CH_PARENT_UNIQUE_ID = 0x014  # u64
_CH_ROOT_UNIQUE_ID = 0x01C  # u64
_CH_GAME_ID = 0x024  # u64
_CH_ACTIVITY = 0x02C  # s8
_CH_GAME_MODE = 0x02D  # u8
_CH_GAME_ENGINE = 0x02E  # u8 + 1 pad
_CH_MAP_ID = 0x030  # s32
_CH_MEGALO_CATEGORY = 0x034  # 8 bytes
_CH_CREATOR = 0x03C  # 0x24 author block
_CH_MODIFIER = 0x060  # 0x24 author block
_CH_TITLE = 0x084  # 128 UTF-16LE code units
_CH_DESCRIPTION = 0x184  # 128 UTF-16LE code units
_CH_VARIANT_DATA = 0x284  # 16 bytes (engine icon index + pad)
_CH_MATCHMAKING_DATA = 0x294  # 16 bytes (hopper_identifier u16 + pad)
_CH_MODE_DATA = 0x2A4  # 16 bytes (campaign / firefight data)
_CHDR_PAYLOAD_SIZE = 0x2B4  # 692 == 704 - 12. CONFIRMED exact fit.

# Author block (0x24 bytes) field offsets, relative to the block.
_AU_TIMESTAMP = 0x00  # u64, Unix epoch seconds
_AU_XUID = 0x08  # u64
_AU_GAMERTAG = 0x10  # char[16], NUL-terminated
_AU_IS_ONLINE = 0x20  # u8 + 3 pad
_AUTHOR_BLOCK_SIZE = 0x24

# mpvr payload field offsets.
_MP_SHA1 = 0x00  # 20 bytes
_MP_UNUSED = 0x14  # 4 bytes (zero in both reference files)
_MP_LENGTH = 0x18  # u32 BIG-endian: hashed bitstream length
_MP_BITSTREAM = 0x1C  # bit-stream starts here (file offset 0x318)


class BlfError(Exception):
    """Raised when a BLF container is malformed or cannot be represented."""


# ---------------------------------------------------------------------------
# Chunk
# ---------------------------------------------------------------------------


@dataclass
class Chunk:
    """One BLF chunk.

    Header is 12 bytes: 4-byte ASCII signature, big-endian u32 size that
    INCLUDES the 12-byte header, big-endian u16 version, big-endian u16 minor
    version (ManagedDonkey/TagTool call this `minor_version`; some tools call
    it `flags` -- same bytes either way).  CONFIRMED against both references.
    """

    signature: bytes
    version: int
    minor_version: int
    payload: bytearray
    offset: Optional[int] = None  # offset it was read from, informational only

    @property
    def size(self) -> int:
        return CHUNK_HEADER_SIZE + len(self.payload)

    @property
    def name(self) -> str:
        return self.signature.decode("latin-1")

    def to_bytes(self) -> bytes:
        if len(self.signature) != 4:
            raise BlfError(f"chunk signature must be 4 bytes, got {self.signature!r}")
        head = self.signature + struct.pack(
            ">IHH", self.size, self.version, self.minor_version
        )
        return head + bytes(self.payload)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return (
            f"Chunk({self.name!r}, size={self.size}, ver={self.version}, "
            f"minor={self.minor_version})"
        )


# ---------------------------------------------------------------------------
# Author block
# ---------------------------------------------------------------------------


@dataclass
class AuthorBlock:
    """chdr creator / modifier block, 0x24 bytes.

    CONFIRMED: the 4-byte timestamp difference between the two reference files
    decodes as Unix epoch seconds (1696702687 = 2023-10-07, 1763923489 =
    2025-11-23), which is consistent with the creation dates of the two
    variants. INFERENCE (from ReachVariantEditor content_author.h): the field
    is a full u64, the next u64 is an XUID, and the following 16 bytes are a
    NUL-terminated gamertag.
    """

    timestamp: int = 0
    xuid: int = 0
    gamertag_raw: bytes = b"\x00" * 16
    is_online: int = 0
    _pad: bytes = b"\x00" * 3

    @classmethod
    def unpack(cls, buf: bytes, off: int) -> "AuthorBlock":
        timestamp, xuid = struct.unpack_from("<QQ", buf, off + _AU_TIMESTAMP)
        gamertag_raw = bytes(buf[off + _AU_GAMERTAG : off + _AU_GAMERTAG + 16])
        is_online = buf[off + _AU_IS_ONLINE]
        pad = bytes(buf[off + _AU_IS_ONLINE + 1 : off + _AUTHOR_BLOCK_SIZE])
        return cls(timestamp, xuid, gamertag_raw, is_online, pad)

    def pack(self) -> bytes:
        if len(self.gamertag_raw) != 16:
            raise BlfError("gamertag_raw must be exactly 16 bytes")
        if len(self._pad) != 3:
            raise BlfError("author pad must be exactly 3 bytes")
        return (
            struct.pack("<QQ", self.timestamp, self.xuid)
            + self.gamertag_raw
            + bytes([self.is_online])
            + self._pad
        )

    @property
    def gamertag(self) -> str:
        """Gamertag as text, up to the NUL. Decoded leniently.

        NOTE: in both reference files this field is the single byte 0xA6
        followed by NULs, which is not valid ASCII. Meaning unverified.
        """
        return self.gamertag_raw.split(b"\x00", 1)[0].decode("latin-1")

    @gamertag.setter
    def gamertag(self, value: str) -> None:
        raw = value.encode("latin-1")
        if len(raw) > 15:
            raise BlfError("gamertag must be at most 15 characters plus NUL")
        self.gamertag_raw = raw + b"\x00" * (16 - len(raw))


# ---------------------------------------------------------------------------
# chdr
# ---------------------------------------------------------------------------


class ContentHeader:
    """Typed view over a 692-byte `chdr` payload.

    Backed by the original bytearray, so every byte not explicitly written
    survives a round trip untouched.
    """

    def __init__(self, payload: bytearray):
        if len(payload) != _CHDR_PAYLOAD_SIZE:
            raise BlfError(
                f"chdr payload must be {_CHDR_PAYLOAD_SIZE} bytes, "
                f"got {len(payload)}"
            )
        self._buf = payload

    @property
    def raw(self) -> bytearray:
        return self._buf

    # -- scalar helpers ----------------------------------------------------
    def _u16(self, off: int) -> int:
        return struct.unpack_from("<H", self._buf, off)[0]

    def _set_u16(self, off: int, v: int) -> None:
        struct.pack_into("<H", self._buf, off, v)

    def _u32(self, off: int) -> int:
        return struct.unpack_from("<I", self._buf, off)[0]

    def _set_u32(self, off: int, v: int) -> None:
        struct.pack_into("<I", self._buf, off, v)

    def _u64(self, off: int) -> int:
        return struct.unpack_from("<Q", self._buf, off)[0]

    def _set_u64(self, off: int, v: int) -> None:
        struct.pack_into("<Q", self._buf, off, v)

    # -- fields ------------------------------------------------------------
    @property
    def build_major(self) -> int:
        return self._u16(_CH_BUILD_MAJOR)

    @property
    def build_minor(self) -> int:
        return self._u16(_CH_BUILD_MINOR)

    @property
    def file_type(self) -> int:
        return struct.unpack_from("<b", self._buf, _CH_FILE_TYPE)[0]

    @property
    def file_size(self) -> int:
        """Byte count through the end of `_eof`. CONFIRMED: 21289 in both
        reference files, which is the offset of `_fsm`, i.e. it EXCLUDES the
        trailing `_fsm` chunk."""
        return self._u32(_CH_FILE_SIZE)

    @file_size.setter
    def file_size(self, v: int) -> None:
        self._set_u32(_CH_FILE_SIZE, v)

    @property
    def unique_id(self) -> int:
        return self._u64(_CH_UNIQUE_ID)

    @unique_id.setter
    def unique_id(self, v: int) -> None:
        self._set_u64(_CH_UNIQUE_ID, v)

    @property
    def activity(self) -> int:
        return struct.unpack_from("<b", self._buf, _CH_ACTIVITY)[0]

    @property
    def game_mode(self) -> int:
        return self._buf[_CH_GAME_MODE]

    @property
    def game_engine(self) -> int:
        return self._buf[_CH_GAME_ENGINE]

    @property
    def map_id(self) -> int:
        return struct.unpack_from("<i", self._buf, _CH_MAP_ID)[0]

    @property
    def hopper_identifier(self) -> int:
        """INFERENCE (Blam-Network/blf saved_game_files.rs): u16 at payload
        0x294, meaningful only for matchmaking content. Zero in both
        reference files, so unverifiable here."""
        return self._u16(_CH_MATCHMAKING_DATA)

    @property
    def creator(self) -> AuthorBlock:
        return AuthorBlock.unpack(self._buf, _CH_CREATOR)

    @creator.setter
    def creator(self, block: AuthorBlock) -> None:
        self._buf[_CH_CREATOR : _CH_CREATOR + _AUTHOR_BLOCK_SIZE] = block.pack()

    @property
    def modifier(self) -> AuthorBlock:
        return AuthorBlock.unpack(self._buf, _CH_MODIFIER)

    @modifier.setter
    def modifier(self, block: AuthorBlock) -> None:
        self._buf[_CH_MODIFIER : _CH_MODIFIER + _AUTHOR_BLOCK_SIZE] = block.pack()

    # -- fixed-size UTF-16LE strings --------------------------------------
    def _get_str(self, off: int) -> str:
        raw = bytes(self._buf[off : off + UGC_STRING_BYTES])
        text = raw.decode("utf-16-le")
        nul = text.find("\x00")
        return text if nul < 0 else text[:nul]

    def _set_str(self, off: int, value: str) -> None:
        encoded = value.encode("utf-16-le")
        if len(encoded) // 2 > MAX_STRING_CHARS:
            raise BlfError(
                f"string needs {len(encoded) // 2} UTF-16 code units; the "
                f"buffer holds {UGC_STRING_CODE_UNITS} including the NUL "
                f"terminator (max {MAX_STRING_CHARS})"
            )
        buf = encoded + b"\x00" * (UGC_STRING_BYTES - len(encoded))
        self._buf[off : off + UGC_STRING_BYTES] = buf

    @property
    def title(self) -> str:
        return self._get_str(_CH_TITLE)

    @title.setter
    def title(self, value: str) -> None:
        self._set_str(_CH_TITLE, value)

    @property
    def description(self) -> str:
        return self._get_str(_CH_DESCRIPTION)

    @description.setter
    def description(self, value: str) -> None:
        self._set_str(_CH_DESCRIPTION, value)


# ---------------------------------------------------------------------------
# BlfFile
# ---------------------------------------------------------------------------


@dataclass
class BlfFile:
    chunks: List[Chunk] = field(default_factory=list)

    # -- parsing -----------------------------------------------------------
    @classmethod
    def parse(cls, data: bytes) -> "BlfFile":
        chunks: List[Chunk] = []
        off = 0
        total = len(data)
        while off < total:
            if total - off < CHUNK_HEADER_SIZE:
                raise BlfError(
                    f"truncated chunk header at 0x{off:x}: "
                    f"{total - off} bytes remain"
                )
            sig = bytes(data[off : off + 4])
            size, version, minor = struct.unpack_from(">IHH", data, off + 4)
            if size < CHUNK_HEADER_SIZE:
                raise BlfError(
                    f"chunk {sig!r} at 0x{off:x} declares size {size}, "
                    f"which is below the {CHUNK_HEADER_SIZE}-byte header"
                )
            if off + size > total:
                raise BlfError(
                    f"chunk {sig!r} at 0x{off:x} declares size {size} but "
                    f"only {total - off} bytes remain"
                )
            chunks.append(
                Chunk(
                    signature=sig,
                    version=version,
                    minor_version=minor,
                    payload=bytearray(data[off + CHUNK_HEADER_SIZE : off + size]),
                    offset=off,
                )
            )
            off += size
        if not chunks:
            raise BlfError("file contains no chunks")
        if chunks[0].signature != b"_blf":
            raise BlfError(
                f"first chunk is {chunks[0].name!r}, expected '_blf'"
            )
        return cls(chunks=chunks)

    @classmethod
    def from_path(cls, path: str) -> "BlfFile":
        with open(path, "rb") as fh:
            return cls.parse(fh.read())

    # -- chunk access ------------------------------------------------------
    def find(self, name: str) -> Optional[Chunk]:
        want = name.encode("latin-1")
        for c in self.chunks:
            if c.signature == want:
                return c
        return None

    def require(self, name: str) -> Chunk:
        c = self.find(name)
        if c is None:
            raise BlfError(f"missing required chunk {name!r}")
        return c

    def remove(self, name: str) -> bool:
        """Drop a chunk by name. Returns True if one was removed."""
        want = name.encode("latin-1")
        before = len(self.chunks)
        self.chunks = [c for c in self.chunks if c.signature != want]
        return len(self.chunks) != before

    @property
    def chdr(self) -> ContentHeader:
        return ContentHeader(self.require("chdr").payload)

    # -- convenience passthroughs -----------------------------------------
    @property
    def title(self) -> str:
        return self.chdr.title

    @title.setter
    def title(self, value: str) -> None:
        self.chdr.title = value

    @property
    def description(self) -> str:
        return self.chdr.description

    @description.setter
    def description(self, value: str) -> None:
        self.chdr.description = value

    # -- mpvr integrity ----------------------------------------------------
    @staticmethod
    def compute_mpvr_sha1(payload: bytes) -> bytes:
        """SHA-1 over the big-endian u32 length followed by that many bytes of
        bit-stream starting at mpvr payload offset 0x1C.

        CONFIRMED: reproduces the stored digest exactly for BOTH reference
        files (lengths 963 and 1049). No salt is involved. Note that
        ReachVariantEditor and Blam-Network's writer prepend a 34-byte
        "gen3 salt" and, for multiplayer, write the length little-endian;
        that scheme does NOT reproduce these MCC-authored files, and was
        tested and rejected.
        """
        length = struct.unpack_from(">I", payload, _MP_LENGTH)[0]
        avail = len(payload) - _MP_BITSTREAM
        if length > avail:
            raise BlfError(
                f"mpvr length field is {length} but only {avail} bytes of "
                f"bit-stream are present"
            )
        data = payload[_MP_BITSTREAM : _MP_BITSTREAM + length]
        return hashlib.sha1(struct.pack(">I", length) + data).digest()

    @property
    def mpvr_bitstream_length(self) -> int:
        return struct.unpack_from(">I", self.require("mpvr").payload, _MP_LENGTH)[0]

    @property
    def mpvr_bitstream_offset_in_file(self) -> int:
        """Absolute file offset where the Megalo bit-stream begins."""
        mpvr = self.require("mpvr")
        base = 0
        for c in self.chunks:
            if c is mpvr:
                break
            base += c.size
        return base + CHUNK_HEADER_SIZE + _MP_BITSTREAM

    def verify(self) -> List[str]:
        """Check every integrity field. Returns a list of human-readable
        problems; an empty list means everything matches."""
        problems: List[str] = []

        mpvr = self.find("mpvr")
        if mpvr is not None:
            stored = bytes(mpvr.payload[_MP_SHA1 : _MP_SHA1 + 20])
            actual = self.compute_mpvr_sha1(bytes(mpvr.payload))
            if stored != actual:
                problems.append(
                    f"mpvr sha1 mismatch: stored {stored.hex()}, "
                    f"computed {actual.hex()}"
                )

        eof = self.find("_eof")
        if eof is not None:
            want = self._offset_of(eof)
            got = struct.unpack_from(">I", eof.payload, 0)[0]
            if got != want:
                problems.append(
                    f"_eof total_file_size is {got}, expected {want}"
                )

        chdr_chunk = self.find("chdr")
        if chdr_chunk is not None and eof is not None:
            want = self._offset_of(eof) + eof.size
            got = ContentHeader(chdr_chunk.payload).file_size
            if got != want:
                problems.append(f"chdr file_size is {got}, expected {want}")

        return problems

    def _offset_of(self, chunk: Chunk) -> int:
        off = 0
        for c in self.chunks:
            if c is chunk:
                return off
            off += c.size
        raise BlfError("chunk is not part of this file")

    # -- serialising -------------------------------------------------------
    def recompute(self) -> None:
        """Recompute every integrity field we have proven the meaning of.

        1. mpvr SHA-1 over (big-endian length || bit-stream).  CONFIRMED.
        2. _eof total_file_size = byte count preceding `_eof`.  CONFIRMED.
        3. chdr file_size = byte count through the end of `_eof`, which
           excludes any trailing `_fsm`.  CONFIRMED.

        NOT recomputed, because it cannot be: the `_fsm` chunk's 32-byte
        digest at payload 0x054 and its 256-byte signature at payload 0x0C0.
        See the module docs and research/01-blf-container-format.md.
        """
        mpvr = self.find("mpvr")
        if mpvr is not None:
            digest = self.compute_mpvr_sha1(bytes(mpvr.payload))
            mpvr.payload[_MP_SHA1 : _MP_SHA1 + 20] = digest

        eof = self.find("_eof")
        if eof is not None:
            struct.pack_into(">I", eof.payload, 0, self._offset_of(eof))
            chdr_chunk = self.find("chdr")
            if chdr_chunk is not None:
                ContentHeader(chdr_chunk.payload).file_size = (
                    self._offset_of(eof) + eof.size
                )

    def to_bytes(self, recompute: bool = True) -> bytes:
        if recompute:
            self.recompute()
        return b"".join(c.to_bytes() for c in self.chunks)

    def to_path(self, path: str, recompute: bool = True) -> int:
        data = self.to_bytes(recompute=recompute)
        parent = os.path.dirname(os.path.abspath(path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(path, "wb") as fh:
            fh.write(data)
        return len(data)

    # -- reporting ---------------------------------------------------------
    def describe(self) -> str:
        lines = []
        off = 0
        for c in self.chunks:
            lines.append(
                f"  0x{off:04x}  {c.name:5s} size={c.size:<6d} "
                f"ver={c.version} minor={c.minor_version}"
            )
            off += c.size
        h = self.chdr
        cr = h.creator
        lines.append(f"  title       : {h.title!r}")
        lines.append(f"  description : {h.description!r}")
        lines.append(
            f"  file_type={h.file_type} activity={h.activity} "
            f"game_mode={h.game_mode} engine={h.game_engine} map_id={h.map_id}"
        )
        lines.append(
            f"  chdr.file_size={h.file_size} creator.timestamp={cr.timestamp} "
            f"creator.xuid=0x{cr.xuid:016x}"
        )
        lines.append(
            f"  mpvr bitstream: {self.mpvr_bitstream_length} bytes at file "
            f"offset 0x{self.mpvr_bitstream_offset_in_file:03x}"
        )
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

_EXPECTED_CHUNKS = [
    ("_blf", 48, 1, 2),
    ("chdr", 704, 10, 2),
    ("mpvr", 20520, 54, 1),
    ("_eof", 17, 1, 1),
    ("_fsm", 464, 1, 1),
]


def _self_test() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    ref_dir = os.path.join(os.path.dirname(here), "reference")
    refs = [
        "Firefight Evolved.bin",
        "Firefight Corvette Evolved.bin",
    ]

    failures = 0

    def check(ok: bool, label: str) -> None:
        nonlocal failures
        print(f"  [{'PASS' if ok else 'FAIL'}] {label}")
        if not ok:
            failures += 1

    for name in refs:
        path = os.path.join(ref_dir, name)
        print(f"\n== {name}")
        if not os.path.exists(path):
            print(f"  [SKIP] not found: {path}")
            continue
        original = open(path, "rb").read()
        f = BlfFile.parse(original)

        # 1. chunk layout
        got = [(c.name, c.size, c.version, c.minor_version) for c in f.chunks]
        check(got == _EXPECTED_CHUNKS, f"chunk layout {got}")

        # 2. stored integrity fields already verify
        problems = f.verify()
        check(not problems, f"stored integrity fields verify ({problems})")

        # 3. no-op round trip is byte-identical, WITH recompute
        out = f.to_bytes(recompute=True)
        check(out == original, "round trip byte-identical (recompute on)")

        # 4. mpvr SHA-1 is reproducible from scratch
        mpvr = f.require("mpvr")
        stored = bytes(mpvr.payload[_MP_SHA1 : _MP_SHA1 + 20])
        check(
            BlfFile.compute_mpvr_sha1(bytes(mpvr.payload)) == stored,
            f"mpvr sha1 recomputes ({stored.hex()})",
        )

        # 5. writing the title/description back unchanged is a no-op
        g = BlfFile.parse(original)
        t, d = g.title, g.description
        g.title = t
        g.description = d
        check(
            g.to_bytes() == original,
            f"title/description rewrite is byte-identical ({t!r})",
        )

        # 6. changing the title changes only the title buffer, and the
        #    new value reads back
        h = BlfFile.parse(original)
        h.title = "ROUNDTRIP TEST"
        mutated = h.to_bytes()
        check(
            BlfFile.parse(mutated).title == "ROUNDTRIP TEST",
            "mutated title reads back",
        )
        check(
            len(mutated) == len(original),
            f"mutated file keeps length ({len(mutated)})",
        )
        chdr_off = 0x30
        title_off = chdr_off + CHUNK_HEADER_SIZE + _CH_TITLE
        differing = {
            i for i in range(len(original)) if original[i] != mutated[i]
        }
        in_title = {
            i for i in differing if title_off <= i < title_off + UGC_STRING_BYTES
        }
        check(
            differing == in_title,
            f"only the title buffer changed ({len(differing)} bytes, "
            f"all in [0x{title_off:04x},0x{title_off + UGC_STRING_BYTES:04x}))",
        )

        # 7. oversize strings are rejected, not silently truncated
        try:
            BlfFile.parse(original).title = "X" * 128
            check(False, "oversize title rejected")
        except BlfError:
            check(True, "oversize title rejected")

        # 8. a 127-char title is accepted (buffer limit minus the NUL)
        k = BlfFile.parse(original)
        k.title = "Y" * 127
        check(BlfFile.parse(k.to_bytes()).title == "Y" * 127, "127-char title fits")

        # 9. corrupting the bitstream is detected, then repaired by recompute
        m = BlfFile.parse(original)
        m.require("mpvr").payload[_MP_BITSTREAM] ^= 0xFF
        check(bool(m.verify()), "bitstream tamper detected by verify()")
        m.recompute()
        check(not m.verify(), "recompute() repairs the mpvr sha1")

        # 10. dropping _fsm yields a file whose own fields still verify
        n = BlfFile.parse(original)
        check(n.remove("_fsm"), "_fsm can be removed")
        stripped = n.to_bytes()
        check(
            len(stripped) == 21289 and not BlfFile.parse(stripped).verify(),
            f"_fsm-stripped file is self-consistent ({len(stripped)} bytes)",
        )

    # cross-file facts
    print("\n== cross-file")
    paths = [os.path.join(ref_dir, n) for n in refs]
    if all(os.path.exists(p) for p in paths):
        a = open(paths[0], "rb").read()
        b = open(paths[1], "rb").read()
        check(len(a) == len(b) == 21753, "both references are 21753 bytes")
        check(a[0x5329:] == b[0x5329:], "_fsm chunks are byte-identical")
        check(a[:0x5329] != b[:0x5329], "content before _fsm differs")
        print(
            "  note: _fsm identical + content differing proves the _fsm "
            "digest/signature cannot be valid for both files."
        )

    print(f"\n{'ALL TESTS PASSED' if not failures else f'{failures} FAILURE(S)'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(_self_test())
