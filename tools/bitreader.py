"""MSB-first bit reader matching cobb::bitreader from ReachVariantEditor.

Bit order (proven against ReachVariantEditor/native/src/ReachVariantTool/helpers/bitreader.h):
within each byte the most significant bit is read first, and multi-byte values are
assembled big-endian (result = (result << consumed) | next_bits).
"""


class BitReader:
    def __init__(self, data, bitpos=0):
        self.data = data
        self.pos = bitpos          # absolute bit position
        self.overflow = 0

    # -- position helpers ---------------------------------------------------
    @property
    def bytepos(self):
        return self.pos // 8

    @property
    def bitshift(self):
        return self.pos % 8

    @property
    def bytespan(self):
        return self.bytepos + (1 if self.bitshift else 0)

    def tell(self):
        return self.pos

    def seek(self, bitpos):
        self.pos = bitpos

    def skip(self, n):
        self.pos += n

    def align(self):
        if self.bitshift:
            self.pos += 8 - self.bitshift

    def eof(self):
        return self.bytepos >= len(self.data)

    # -- primitive reads ----------------------------------------------------
    def read(self, n):
        """Read n bits, MSB-first, unsigned."""
        if n == 0:
            return 0
        result = 0
        remaining = n
        while remaining:
            bytepos = self.pos // 8
            if bytepos >= len(self.data):
                self.overflow += remaining
                result <<= remaining
                self.pos += remaining
                return result
            shift = self.pos % 8
            byte = self.data[bytepos] & (0xFF >> shift)
            avail = 8 - shift
            if remaining < avail:
                byte >>= (avail - remaining)
                consumed = remaining
            else:
                consumed = avail
            result = (result << consumed) | byte
            self.pos += consumed
            remaining -= consumed
        return result

    def read_signed(self, n):
        """Two's complement signed read."""
        v = self.read(n)
        if n and (v & (1 << (n - 1))):
            v -= (1 << n)
        return v

    def read_bool(self):
        return bool(self.read(1))

    def read_bytes(self, count):
        return bytes(self.read(8) for _ in range(count))

    # -- cobb::bitnumber ----------------------------------------------------
    def bitnumber(self, bits, signed=False, offset=0, presence=False):
        """cobb::bitnumber<bits, T, offset/presence>.

        presence=True means a leading 1-bit flag; if clear the value is absent
        (returns None). offset is added after reading (used for 'or_value').
        """
        if presence:
            if not self.read(1):
                return None
        v = self.read_signed(bits) if signed else self.read(bits)
        return v + offset

    # -- strings ------------------------------------------------------------
    def read_cstr_ascii(self, maxlen):
        out = []
        for _ in range(maxlen):
            c = self.read(8)
            if c == 0:
                break
            out.append(c)
        return bytes(out).decode('latin-1')

    def read_cstr_utf16(self, maxlen):
        """Reads up to maxlen UTF-16 code units (big-endian), stopping at NUL."""
        out = []
        for _ in range(maxlen):
            c = self.read(16)
            if c == 0:
                break
            out.append(c)
        return ''.join(chr(c) for c in out)

    def read_wide_fixed(self, units):
        """Reads exactly `units` UTF-16BE code units, truncating at the first NUL."""
        vals = [self.read(16) for _ in range(units)]
        s = []
        for v in vals:
            if v == 0:
                break
            s.append(chr(v))
        return ''.join(s)

    # -- float --------------------------------------------------------------
    def read_float(self):
        import struct
        return struct.unpack('>f', self.read_bytes(4))[0]

    def read_compressed_float(self, bitcount, fmin, fmax, is_signed, unknown):
        raw = self.read(bitcount)
        rng = fmax - fmin
        max_encoded = 1 << bitcount
        if is_signed:
            max_encoded -= 1
        if unknown:
            if raw == 0:
                result = fmin
            elif raw == max_encoded - 1:
                result = fmax
            else:
                result = fmin + (raw - 0.5) * (rng / (max_encoded - 2))
        else:
            result = fmin + (raw + 0.5) * (rng / max_encoded)
        if is_signed:
            max_encoded -= 1
            if raw * 2 == max_encoded:
                result = (fmin + fmax) * 0.5
        return result
