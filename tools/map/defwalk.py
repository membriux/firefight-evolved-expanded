import json, sys

SZ = {
 'terminator':0,'explanation':0,'custom':0,
 'block':0xC,'tag_reference':0x10,'data':0x14,'tag_interop':0x10,
 'short_block_index':2,'custom_short_block_index':2,'long_block_index':4,'char_block_index':1,
 'real':4,'short_integer':2,'string_id':4,'long_integer':4,'short_enum':2,
 'real_point_3d':12,'word_flags':2,'long_flags':4,'char_integer':1,'string':32,
 'byte_flags':1,'real_euler_angles_2d':8,'long_enum':4,'long_block_flags':4,
 'real_vector_3d':12,'angle':4,'char_enum':1,'word_block_flags':2,'real_fraction':4,
 'real_plane_3d':16,'long_string':256,'rgb_color':4,'real_bounds':8,'short_bounds':4,
 'real_euler_angles_3d':12,'real_point_2d':8,'real_quaternion':16,'fraction_bounds':8,
 'int64_integer':8,'tag':4,'angle_bounds':8,'real_plane_2d':12,'real_rgb_color':12,
 'pad':None,'useless_pad':None,'struct':None,'array':None,
}

class Defs:
    def __init__(self, path):
        self.d = json.load(open(path))
        self.structs = self.d['structs']
        self.blocks = self.d['blocks']
        self.arrays = self.d.get('arrays', {})
        self.enums = self.d.get('enums_flags', {})
    def fsize(self, f):
        t = f['type']
        if t in ('pad','useless_pad'):
            return int(f['definition'])
        if t == 'struct':
            return self.ssize(f['definition'])
        if t == 'array':
            a = self.arrays[f['definition']]
            cnt = a.get('count') or a.get('max_count') or 0
            inner = a.get('struct') or a.get('definition')
            return int(cnt) * (self.ssize(inner) if inner else 0)
        s = SZ.get(t)
        if s is None:
            raise KeyError('unknown type '+t)
        return s
    def ssize(self, name):
        return self.structs[name]['size']
    def layout(self, name):
        """-> list of (offset, name, type, size, definition)"""
        off = 0; out = []
        for f in self.structs[name]['fields']:
            sz = self.fsize(f)
            out.append((off, f.get('name'), f['type'], sz, f.get('definition')))
            off += sz
        return out, off
    def check_all(self):
        bad = []
        for n, s in self.structs.items():
            try:
                _, tot = self.layout(n)
            except KeyError as e:
                bad.append((n, 'ERR '+str(e), s['size'])); continue
            if tot != s['size']:
                bad.append((n, tot, s['size']))
        return bad

if __name__ == '__main__':
    D = Defs(sys.argv[1])
    bad = D.check_all()
    print('structs', len(D.structs), 'mismatched', len(bad))
    for b in bad[:40]: print('  ', b)
