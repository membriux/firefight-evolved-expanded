"""Dump scnr squads / squad groups / character palette from a Reach MCC cache."""
import json, mmap, struct, sys
sys.path.insert(0, '/Users/sancjgui/ffscripts')
sys.path.insert(0, '/Users/sancjgui/Desktop/Firefight Evolved Expanded/tools/map')
import reach_cache as rc
from defwalk import Defs

MAP = sys.argv[1]
DEFS = "/Users/sancjgui/Desktop/Firefight Evolved Expanded/research/_raw/reach-defs/scenario.json"
D = Defs(DEFS)
TEAMS = D.enums['ai_team_enum']['options']

cache = rc.ReachCacheFile.from_path(MAP)
data = cache.data
scnr = cache.global_tag('scnr')
SCNR = cache.meta_to_offset(cache.expand(scnr.meta_pointer)) if hasattr(scnr, 'meta_pointer') else scnr.offset
SCNR = scnr.offset

def u32(o): return struct.unpack_from('<I', data, o)[0]
def i32(o): return struct.unpack_from('<i', data, o)[0]
def u16(o): return struct.unpack_from('<H', data, o)[0]
def i16(o): return struct.unpack_from('<h', data, o)[0]
def s32(o, n=0x20):
    b = data[o:o+n]
    return b.split(b'\0')[0].decode('latin-1')
def sid(o): return cache.resolve_sid(u32(o))

def block(o):
    """(count, file_offset) for a tag block at absolute file offset o"""
    n = i32(o); p = u32(o + 4)
    if n <= 0 or not p: return 0, 0
    return n, cache.meta_to_offset(cache.expand(p))

# character palette -> tag paths
cn, co = block(SCNR + 0x3EC)
chars = []
for i in range(cn):
    e = co + i * 0x10
    datum = u32(e + 0xC)
    idx = datum & 0xFFFF
    t = cache.tags[idx] if 0 <= idx < len(cache.tags) else None
    chars.append(t.path if t and t.path else ('<datum 0x%08X>' % datum))

# vehicle palette
vn, vo = block(SCNR + 0x138)
vehs = []
for i in range(vn):
    datum = u32(vo + i * 0x10 + 0xC)
    idx = datum & 0xFFFF
    t = cache.tags[idx] if 0 <= idx < len(cache.tags) else None
    vehs.append(t.path if t and t.path else ('<datum 0x%08X>' % datum))

# squad groups
gn, go = block(SCNR + 0x38C)
groups = [s32(go + i * 0x28) for i in range(gn)]
gparent = []
for i in range(gn):
    par = i16(go + i * 0x28 + 0x20)
    gparent.append(groups[par] if 0 <= par < gn else None)

sn, so = block(SCNR + 0x398)
out = []
for i in range(sn):
    e = so + i * 0x6C
    name = s32(e + 0x00)
    team = u16(e + 0x24)
    parent = i16(e + 0x26)
    tmpl = sid(e + 0x4C)
    rec = {
        'index': i, 'name': name,
        'team': TEAMS[team] if team < len(TEAMS) else 'team%d' % team,
        'group': groups[parent] if 0 <= parent < len(groups) else None,
        'template': tmpl if tmpl and not tmpl.startswith('<sid') else None,
        'cells': [],
    }
    for which, coff in (('designer', e + 0x54), ('templated', e + 0x60)):
        cc, co2 = block(coff)
        for j in range(cc):
            c = co2 + j * 0x6C
            cname = sid(c + 0x00)
            count = i16(c + 0x10)
            ctn, cto = block(c + 0x14)
            ctypes = []
            for k in range(ctn):
                ci = i16(cto + k * 0x10 + 0xC)
                ctypes.append(chars[ci] if 0 <= ci < len(chars) else '<pal %d>' % ci)
            vi = i16(c + 0x46)
            rec['cells'].append({'src': which, 'name': cname, 'count': count,
                                 'characters': ctypes,
                                 'vehicle': vehs[vi] if 0 <= vi < len(vehs) else None,
                                 'vehicle_variant': sid(c + 0x48),
                                 'placement_script': sid(c + 0x4C)})
    out.append(rec)

json.dump({'character_palette': chars, 'vehicle_palette': vehs,
           'squad_groups': [{'name': g, 'parent': p} for g, p in zip(groups, gparent)],
           'squads': out},
          open(sys.argv[2], 'w'), indent=1)
print('squad_groups', len(groups), 'squads', len(out), 'char_palette', len(chars))
