#!/usr/bin/env python3
"""mpvr_write.py - serializer for the `mpvr` bit-stream of Halo: Reach (MCC)
Firefight game variants.

Design rationale
----------------
A hand-written writer that mirrors the reader field-by-field is the single
biggest risk in this format: one wrong bit width, one missed `offset` or
presence-polarity rule, and the stream desynchronises *silently* - the file
still hashes, still loads structurally, and the decoded contents are garbage.

This module therefore does NOT re-implement the field sequence. It reuses
`mpvr.read_firefight()` unchanged, and swaps the BitReader underneath it for
an `EchoBitReader` that mirrors every `read(n)` call into a BitWriter. Because
every read in `mpvr.py` - including the ones inside `read_string_table()` that
bypass the Parser helpers - funnels through `BitReader.read()`, the emitted
stream is bit-for-bit identical to the input by construction. There is no
second copy of the field order to keep in sync.

Modifications are applied as a patch map keyed by the same field-path strings
`mpvr.Parser` already uses for its trace (e.g. `round[1].wave_boss.squads[0]`).
Each patch is applied immediately at its own field: the echo appended exactly
that field's bits to the end of the writer, so overwriting the tail from the
recorded start position is always correct, even when the replacement is a
different length (which is what variable-length UTF-16 titles need).

Self-test (`python3 -I tools/mpvr_write.py`) re-encodes both reference files
with an EMPTY patch map and asserts byte-identical output against the original
payload. Nothing in this project may be trusted until that assertion passes.
"""

import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mpvr  # noqa: E402
from bitreader import BitReader  # noqa: E402

MAX_STRING_CHARS = 127  # 128-code-unit read window, minus the NUL terminator


class MpvrWriteError(Exception):
    pass


# ---------------------------------------------------------------------------
# bit writer
# ---------------------------------------------------------------------------


class BitWriter:
    """MSB-first bit sink. Stores one Python int (0/1) per bit so that a
    variable-length splice is a plain list assignment."""

    def __init__(self):
        self.bits = []

    def __len__(self):
        return len(self.bits)

    def write(self, value, n):
        if n <= 0:
            return
        value &= (1 << n) - 1
        self.bits.extend((value >> (n - 1 - i)) & 1 for i in range(n))

    @staticmethod
    def encode(value, n):
        value &= (1 << n) - 1
        return [(value >> (n - 1 - i)) & 1 for i in range(n)]

    def replace_tail(self, start, bits):
        """Replace everything from bit index `start` to the end."""
        if start > len(self.bits):
            raise MpvrWriteError("splice start %d past end %d" % (start, len(self.bits)))
        self.bits[start:] = list(bits)

    def to_bytes(self):
        """Pad to a byte boundary with zero bits and pack MSB-first.

        Zero padding is correct for these files: both references close at
        bit 7699/8387 with 5 padding bits, and the self-test below proves the
        padded result reproduces the stored 963/1049-byte payloads exactly.
        """
        bits = self.bits
        pad = (-len(bits)) % 8
        if pad:
            bits = bits + [0] * pad
        out = bytearray(len(bits) // 8)
        for i, b in enumerate(bits):
            if b:
                out[i >> 3] |= 0x80 >> (i & 7)
        return bytes(out)

    @property
    def bit_length(self):
        return len(self.bits)


class EchoBitReader(BitReader):
    """BitReader that mirrors every read into a BitWriter."""

    def __init__(self, data, bitpos, writer):
        super().__init__(data, bitpos)
        self.writer = writer

    def read(self, n):
        value = super().read(n)
        self.writer.write(value, n)
        return value


# ---------------------------------------------------------------------------
# patching parser
# ---------------------------------------------------------------------------


class PatchParser(mpvr.Parser):
    """mpvr.Parser whose reads are echoed, with optional per-field overrides.

    Patch values are *logical* values, i.e. the same values `mpvr.py` reports
    in its trace: `offset` fields take the real value (the +1 is re-applied
    here), booleans take True/False, strings take str.
    """

    def __init__(self, data, bitpos, patches=None):
        self.writer = BitWriter()
        self.br = EchoBitReader(data, bitpos, self.writer)
        self.trace = []
        self.patches = dict(patches or {})
        self.applied = set()

    # -- helpers -----------------------------------------------------------
    def _wants(self, name):
        return name is not None and name in self.patches

    def _apply(self, name, start, bits):
        self.writer.replace_tail(start, bits)
        self.applied.add(name)

    # -- overrides ---------------------------------------------------------
    def bn(self, bits, signed=False, offset=False, presence=None,
           if_absent=0, name=None):
        wstart = len(self.writer)
        value = super().bn(bits, signed=signed, offset=offset,
                           presence=presence, if_absent=if_absent, name=name)
        if not self._wants(name):
            return value
        new = self.patches[name]
        if presence is not None:
            raise MpvrWriteError(
                "refusing to patch %r: presence-bit fields are not supported "
                "by this writer" % name)
        raw = new + 1 if offset else new
        limit = 1 << bits
        if offset:
            if not 0 <= raw < limit:
                raise MpvrWriteError(
                    "%s: value %d does not fit an offset-encoded %d-bit field"
                    % (name, new, bits))
        elif signed:
            if not -(limit >> 1) <= new < (limit >> 1):
                raise MpvrWriteError(
                    "%s: value %d does not fit a signed %d-bit field"
                    % (name, new, bits))
        else:
            if not 0 <= raw < limit:
                raise MpvrWriteError(
                    "%s: value %d does not fit an unsigned %d-bit field"
                    % (name, new, bits))
        self._apply(name, wstart, BitWriter.encode(raw, bits))
        # the trace should report what we actually wrote
        if self.trace and self.trace[-1][2] == name:
            t = self.trace[-1]
            self.trace[-1] = (t[0], t[1], t[2], new)
        return new

    def bit(self, name=None):
        wstart = len(self.writer)
        value = super().bit(name=name)
        if not self._wants(name):
            return value
        new = bool(self.patches[name])
        self._apply(name, wstart, BitWriter.encode(1 if new else 0, 1))
        if self.trace and self.trace[-1][2] == name:
            t = self.trace[-1]
            self.trace[-1] = (t[0], t[1], t[2], new)
        return new

    def utf16_str(self, maxlen, name=None):
        wstart = len(self.writer)
        value = super().utf16_str(maxlen, name=name)
        if not self._wants(name):
            return value
        new = self.patches[name]
        if not isinstance(new, str):
            raise MpvrWriteError("%s: expected str, got %r" % (name, type(new)))
        if len(new) > maxlen - 1:
            raise MpvrWriteError(
                "%s: %d characters exceeds the %d-character limit (the %d-unit "
                "buffer must hold a NUL terminator)"
                % (name, len(new), maxlen - 1, maxlen))
        bits = []
        for ch in new:
            cp = ord(ch)
            if cp > 0xFFFF:
                raise MpvrWriteError(
                    "%s: %r is outside the BMP and needs a surrogate pair, "
                    "which this writer does not emit" % (name, ch))
            bits.extend(BitWriter.encode(cp, 16))
        bits.extend(BitWriter.encode(0, 16))  # NUL terminator
        self._apply(name, wstart, bits)
        if self.trace and self.trace[-1][2] == name:
            t = self.trace[-1]
            self.trace[-1] = (t[0], t[1], t[2], new)
        return new


# ---------------------------------------------------------------------------
# transcode entry point
# ---------------------------------------------------------------------------


def locate_mpvr(data):
    """Returns (chunk_offset, chunk_size, bitstream_offset, declared_length)."""
    for c in mpvr.walk_chunks(data):
        if c['signature'] == 'mpvr':
            base = c['offset'] + 12
            length, = struct.unpack('>I', data[base + 24:base + 28])
            return c['offset'], c['size'], base + mpvr.MPVR_PREAMBLE, length
    raise MpvrWriteError('no mpvr chunk found')


def transcode(data, patches=None, strict=True):
    """Re-encode the mpvr bit-stream of `data`, applying `patches`.

    Returns a dict with the new payload bytes, the decoded (post-patch) tree
    and the field trace.
    """
    _coff, _csize, bit_off, declared = locate_mpvr(data)

    p = PatchParser(data, bit_off * 8, patches)
    engine = p.bn(4, name='variant_type')
    if engine != 4:
        raise MpvrWriteError(
            'engine type %d (%s) is not firefight(4); this writer only handles '
            'the firefight body' % (engine, mpvr.enum_name(mpvr.GAME_ENGINE, engine)))
    variant = mpvr.read_firefight(p)

    consumed_bits = p.br.pos - bit_off * 8
    if (consumed_bits + 7) // 8 != declared:
        raise MpvrWriteError(
            'parse did not close on the declared length: consumed %d bits '
            '(%d bytes) but the length field says %d bytes'
            % (consumed_bits, (consumed_bits + 7) // 8, declared))
    if p.br.overflow:
        raise MpvrWriteError('reader overflowed by %d bits' % p.br.overflow)

    if strict:
        missed = set(p.patches) - p.applied
        if missed:
            raise MpvrWriteError(
                'these patch keys never matched a field (typo in the path?): %s'
                % ', '.join(sorted(missed)))

    return {
        'payload': p.writer.to_bytes(),
        'bit_length': p.writer.bit_length,
        'variant': variant,
        'trace': p.trace,
        'original_length': declared,
    }


def rebuild_file(data, patches=None):
    """Return a complete new .bin with the mpvr bit-stream re-encoded.

    Only the mpvr chunk's bit-stream region, its length field and its SHA-1
    change. chdr/_eof derived fields are recomputed by blf.py by the caller.
    """
    import blf

    res = transcode(data, patches)
    payload = res['payload']

    blob = blf.BlfFile.parse(data)
    chunk = blob.require('mpvr')
    room = len(chunk.payload) - blf._MP_BITSTREAM
    if len(payload) > room:
        raise MpvrWriteError(
            'new bit-stream is %d bytes but the fixed-size mpvr chunk only has '
            'room for %d' % (len(payload), room))

    tail = bytearray(room)
    tail[:len(payload)] = payload
    chunk.payload[blf._MP_BITSTREAM:] = tail
    struct.pack_into('>I', chunk.payload, blf._MP_LENGTH, len(payload))
    res['blf'] = blob
    return res


# ---------------------------------------------------------------------------
# self-test: byte-identical round-trip on unmodified input
# ---------------------------------------------------------------------------


def _round_trip(path):
    data = open(path, 'rb').read()
    _coff, _csize, bit_off, declared = locate_mpvr(data)
    original = data[bit_off:bit_off + declared]

    res = transcode(data, patches=None)
    produced = res['payload']

    name = os.path.basename(path)
    if len(produced) != len(original):
        return False, ('%s: length mismatch - produced %d bytes, original %d'
                       % (name, len(produced), len(original)))
    if produced != original:
        for i, (a, b) in enumerate(zip(produced, original)):
            if a != b:
                bad = [t for t in res['trace'] if t[0] <= (bit_off + i) * 8 < t[0] + t[1]]
                where = bad[-1][2] if bad else '<unnamed/padding>'
                return False, (
                    '%s: first differing byte at payload offset %d (file 0x%x): '
                    'produced 0x%02x, original 0x%02x; that byte falls inside '
                    'field %r' % (name, i, bit_off + i, a, b, where))
    return True, '%s: %d bytes, byte-identical' % (name, len(produced))


def _full_file_round_trip(path):
    """Rebuild the whole container with no patches and compare every byte."""
    import blf

    data = open(path, 'rb').read()
    res = rebuild_file(data, patches=None)
    out = res['blf'].to_bytes(recompute=True)
    name = os.path.basename(path)
    if out != data:
        diffs = [i for i, (a, b) in enumerate(zip(out, data)) if a != b]
        return False, ('%s: whole-file rebuild differs at %d byte(s), first at '
                       '0x%x' % (name, len(diffs), diffs[0] if diffs else -1))
    return True, '%s: whole-file rebuild byte-identical (%d bytes)' % (name, len(out))


def self_test(paths):
    ok = True
    print('mpvr_write self-test: byte-identical re-encode of unmodified input')
    print('-' * 72)
    for path in paths:
        for fn in (_round_trip, _full_file_round_trip):
            good, msg = fn(path)
            print('  %-6s %s' % ('PASS' if good else 'FAIL', msg))
            ok = ok and good
    print('-' * 72)
    print('RESULT: %s' % ('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    args = sys.argv[1:]
    if not args:
        ref = os.path.join(root, 'reference')
        args = sorted(os.path.join(ref, f) for f in os.listdir(ref)
                      if f.lower().endswith('.bin'))
    return self_test(args)


if __name__ == '__main__':
    sys.exit(main())
