#!/usr/bin/env python3
"""tools/patch/holdout_fe_spartans.py  -  build the SPARTAN ally tier into ff70_holdout.

Input  : a cache that already carries the char 8107 -> bipd spartans repoint
         (~/Desktop/build/ff70_holdout.stage2.map does).
Output : the same cache plus the Spartan tier, written only if Blamite loads it
         (CacheWriter.save() gates on the reference implementation by default).

WHAT IT ADDS, and why each piece is needed
------------------------------------------
1. Equipment palette 6 -> 7 entries. active_camouflage is in Holdout's TAG TABLE
   (eqip 7216) but NOT in the scenario's equipment palette, and a cell's
   `initial equipment` is a short_block_index into that palette - so the tag
   existing is not enough. The block is copied to new space with one extra
   entry cloned from the sprint entry and its datum swapped.

2. sur_fireteam_03 and sur_fireteam_04 each get:
     - one cell: 2 actors, major upgrade 4 ('all'), i.e. every Spartan is a major
     - one character choice  -> palette 25, the Spartan-bodied char
     - five weapon choices   -> sniper rifle / rocket launcher / spartan laser /
                                detached plasma turret / grenade launcher,
                                chance 1 each, so the engine randomises per actor
                                per spawn with NO script involvement
     - four equipment choices-> sprint / jet pack / drop shield / active camo,
                                same free randomisation
     - two spawn points at the exact positions of the placed scenery
       spartan_respawn_00 (442.14, 116.34, -4.96) and
       spartan_respawn_04 (440.42, 123.55, -5.16), so the ground is known
       walkable and known inside the base. Without spawn points a squad with
       cells still spawns nothing - that is why the trooper tier had to borrow
       the drop squads' pods.

SLOT CHECK, done against the input cache rather than assumed: sur_fireteam_01
and _02 already carry cells from the earlier stage, so this script refuses to
touch them and takes _03 and _04. _05 and _06 are left free for an ODST tier.

WHY THESE TWO SQUADS AND NOT NEW ONES: zero new script objects. sur_fireteam_03
and _04 already exist in the scnr, are already parented to gr_survival_fireteams
(squad group 9) and already carry obj_fireteams as their initial objective, whose
single task `fireteams` is already filtered to group 9 with follow = player.
"""
import os
import struct
import sys

PROJ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(PROJ, "tools", "map"))

import reach_cache as rc          # noqa: E402
import reach_write as rw          # noqa: E402

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/Desktop/build/ff70_holdout.stage2.map")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser(
    "~/Desktop/build/ff70_holdout.spartans.map")

SQUADS = ["sur_fireteam_03", "sur_fireteam_04"]
PAL_SPARTAN_CHAR = 25            # objects\characters\null\ai\null_cov_default, repointed to spartans
SPARTAN_COUNT = 2                # bodies per squad
MAJOR_ALL = 4                    # major_upgrade_enum: normal/few/many/none/all
WEAPON_POOL = [8, 11, 12, 15, 19]            # sniper, rocket, laser, plasma turret, grenade launcher
ABILITY_POOL = [1, 2, 5]                     # sprint, jet pack, drop shield (+ camo appended below)
CAMO_PATH = "objects\\equipment\\active_camouflage\\active_camouflage"
SPRINT_PATH = "objects\\equipment\\sprint\\sprint"
SPAWN_AT = [(442.14, 116.34, -4.96), (440.42, 123.55, -5.16)]

OFF_EQUIP_PALETTE, OFF_WEAPON_PALETTE, OFF_SQUADS, OFF_CHAR_PALETTE = 0x150, 0x168, 0x398, 0x3EC
SQUAD_SIZE, CELL_SIZE, CHOICE_SIZE, SPAWN_SIZE, PALETTE_SIZE = 0x6C, 0x6C, 0x10, 124, 0x10
SQ_SPAWN_POINTS, SQ_DESIGNER = 0x3C, 0x54
CELL_COUNT, CELL_MAJOR = 0x10, 0x12
CELL_CHARTYPE, CELL_WEAPON, CELL_EQUIPMENT = 0x14, 0x20, 0x38
CHOICE_INDEX, CHOICE_CHANCE = 0x0C, 0x0E
SP_NAME, SP_CELL, SP_POS = 12, 16, 20
SP_FLAGS, SP_CHAR, SP_WEAP, SP_WEAP2, SP_EQUIP, SP_VEH, SP_SEAT = 48, 50, 52, 54, 56, 58, 60

cache = rc.ReachCacheFile.from_path(SRC)
data = cache.data
scnr = cache.global_tag("scnr")
base = scnr.offset
bydatum = {t.datum: t for t in cache.tags}
bypath = {(t.group_code, t.path): t for t in cache.tags}


def blk(buf, off):
    n, ptr = struct.unpack_from("<Ii", buf, off)
    return (n, cache.meta_to_offset(cache.expand(ptr & 0xFFFFFFFF)) if n else None)


# --- sanity: the input must already have the Spartan-bodied char ------------------------------------
char_pal_n, char_pal_o = blk(data, base + OFF_CHAR_PALETTE)
victim_datum = struct.unpack_from("<I", data, char_pal_o + PAL_SPARTAN_CHAR * PALETTE_SIZE + 0xC)[0]
victim = bydatum[victim_datum]
unit_datum = struct.unpack_from("<I", data, victim.offset + 0x20)[0]
unit_tag = bydatum.get(unit_datum)
if unit_tag is None or not unit_tag.path.endswith("spartans\\spartans"):
    sys.exit("REFUSING: char palette[%d] (%s) does not point at the Spartan biped yet. "
             "Run the char repoint first." % (PAL_SPARTAN_CHAR, victim.path))
print("input ok : char palette[%d] %s -> %s" % (PAL_SPARTAN_CHAR, victim.path, unit_tag.path))

# --- locate the squads, and refuse to reuse an occupied slot ---------------------------------------
sq_n, sq_o = blk(data, base + OFF_SQUADS)
squad_off = {}
for i in range(sq_n):
    o = sq_o + i * SQUAD_SIZE
    squad_off[data[o:o + 32].split(b"\0")[0].decode("latin1")] = o
for name in ("sur_fireteam_01", "sur_fireteam_02", "sur_fireteam_03",
             "sur_fireteam_04", "sur_fireteam_05", "sur_fireteam_06"):
    o = squad_off[name]
    dn, _ = blk(data, o + SQ_DESIGNER)
    pn, _ = blk(data, o + SQ_SPAWN_POINTS)
    taken = name in SQUADS
    print("  slot %-18s cells=%d spawnpts=%d  %s"
          % (name, dn, pn, "<- THIS TIER" if taken else ("occupied" if dn else "free")))
    if taken and dn:
        sys.exit("REFUSING: %s already has %d cell(s); it is not a free slot." % (name, dn))

# --- templates: clone real stock structures so every unset field keeps a valid value ----------------
tpl_sq = squad_off["sq_sur_drop_01"]
tcn, tco = blk(data, tpl_sq + SQ_DESIGNER)
assert tcn == 1
CELL_TPL = bytes(data[tco:tco + CELL_SIZE])
ttn, tto = blk(data, tco + CELL_CHARTYPE)
assert ttn == 1
CHOICE_TPL = bytes(data[tto:tto + CHOICE_SIZE])
tpn, tpo = blk(data, tpl_sq + SQ_SPAWN_POINTS)
assert tpn == 4
SPAWN_TPL = bytes(data[tpo:tpo + SPAWN_SIZE])
print("templates: cell %d B from sq_sur_drop_01, choice %d B, spawn point %d B"
      % (len(CELL_TPL), len(CHOICE_TPL), len(SPAWN_TPL)))

# --- the equipment palette, grown by one for active camo -------------------------------------------
eq_n, eq_o = blk(data, base + OFF_EQUIP_PALETTE)
EQ_OLD = bytes(data[eq_o:eq_o + eq_n * PALETTE_SIZE])
sprint_i = None
for i in range(eq_n):
    t = bydatum.get(struct.unpack_from("<I", EQ_OLD, i * PALETTE_SIZE + 0xC)[0])
    if t is not None and t.path == SPRINT_PATH:
        sprint_i = i
camo = bypath.get(("eqip", CAMO_PATH))
if camo is None or sprint_i is None:
    sys.exit("REFUSING: need both the sprint palette entry and the active_camouflage eqip tag.")
CAMO_IDX = eq_n
print("equipment palette: %d -> %d entries; [%d] = %s (datum 0x%08X), cloned from [%d] sprint"
      % (eq_n, eq_n + 1, CAMO_IDX, camo.path, camo.datum, sprint_i))
camo_entry = bytearray(EQ_OLD[sprint_i * PALETTE_SIZE:(sprint_i + 1) * PALETTE_SIZE])
struct.pack_into("<I", camo_entry, 0xC, camo.datum)
EQ_NEW = EQ_OLD + bytes(camo_entry)
ABILITIES = ABILITY_POOL + [CAMO_IDX]

# --- allocate -------------------------------------------------------------------------------------
need = len(EQ_NEW) + len(SQUADS) * (
    CHOICE_SIZE                                   # character choice
    + len(WEAPON_POOL) * CHOICE_SIZE              # weapon choices
    + len(ABILITIES) * CHOICE_SIZE                # equipment choices
    + CELL_SIZE
    + len(SPAWN_AT) * SPAWN_SIZE) + 256
w = rw.CacheWriter(cache)
growth = w.grow_tag_area(need, mode="end")
cur = growth.free_offset
print("allocated 0x%X bytes (asked 0x%X) at file 0x%X / addr 0x%X"
      % (growth.granted, need, cur, growth.free_address))


def emit(payload):
    """Write payload into the fresh space and return its file offset."""
    global cur
    off = cur
    w.patch(off, bytes(payload))
    cur += len(payload)
    return off


def set_block(buf_off, count, target_off):
    """Point a 12-byte tag block field at target_off, in the output buffer."""
    struct.pack_into("<i", w.buf, buf_off, count)
    struct.pack_into("<I", w.buf, buf_off + 4, w.contract(w.address_of(target_off)))


def choice(index, chance=1):
    c = bytearray(CHOICE_TPL)
    struct.pack_into("<h", c, CHOICE_INDEX, index)
    struct.pack_into("<h", c, CHOICE_CHANCE, chance)
    return bytes(c)


# relocate the equipment palette first, so its new index is live for the cells
eq_new_off = emit(EQ_NEW)
set_block(base + OFF_EQUIP_PALETTE, eq_n + 1, eq_new_off)

for name in SQUADS:
    sqo = squad_off[name]

    char_off = emit(choice(PAL_SPARTAN_CHAR))
    weap_off = None
    for k, wi in enumerate(WEAPON_POOL):
        off = emit(choice(wi))
        if k == 0:
            weap_off = off
    equip_off = None
    for k, ei in enumerate(ABILITIES):
        off = emit(choice(ei))
        if k == 0:
            equip_off = off

    cell = bytearray(CELL_TPL)
    struct.pack_into("<h", cell, CELL_COUNT, SPARTAN_COUNT)
    struct.pack_into("<h", cell, CELL_MAJOR, MAJOR_ALL)
    struct.pack_into("<i", cell, CELL_CHARTYPE, 1)
    struct.pack_into("<I", cell, CELL_CHARTYPE + 4, w.contract(w.address_of(char_off)))
    struct.pack_into("<i", cell, CELL_WEAPON, len(WEAPON_POOL))
    struct.pack_into("<I", cell, CELL_WEAPON + 4, w.contract(w.address_of(weap_off)))
    struct.pack_into("<i", cell, CELL_EQUIPMENT, len(ABILITIES))
    struct.pack_into("<I", cell, CELL_EQUIPMENT + 4, w.contract(w.address_of(equip_off)))
    cell_off = emit(cell)

    sp_first = None
    for k, (x, y, z) in enumerate(SPAWN_AT):
        sp = bytearray(SPAWN_TPL)
        struct.pack_into("<I", sp, SP_NAME, 0)            # unnamed; nothing references these by name
        struct.pack_into("<h", sp, SP_CELL, 0)            # the one cell we just made
        struct.pack_into("<fff", sp, SP_POS, x, y, z)
        struct.pack_into("<H", sp, SP_FLAGS, 0)
        struct.pack_into("<h", sp, SP_CHAR, -1)           # -1 = take the character from the cell
        struct.pack_into("<h", sp, SP_WEAP, -1)           # -1 = take the weapon from the cell,
        struct.pack_into("<h", sp, SP_WEAP2, -1)          #      i.e. from the randomised pool
        struct.pack_into("<h", sp, SP_EQUIP, -1)
        struct.pack_into("<h", sp, SP_VEH, -1)            # ON FOOT. the template is a drop-pod point.
        struct.pack_into("<h", sp, SP_SEAT, 0)
        off = emit(sp)
        if k == 0:
            sp_first = off

    set_block(sqo + SQ_DESIGNER, 1, cell_off)
    set_block(sqo + SQ_SPAWN_POINTS, len(SPAWN_AT), sp_first)
    print("  %s: %d bodies, major=all, cell@0x%X, %d weapon choices, %d abilities, %d spawn points"
          % (name, SPARTAN_COUNT, cell_off, len(WEAPON_POOL), len(ABILITIES), len(SPAWN_AT)))

w.update_checksum()
n = w.save(OUT)                      # gated on Blamite by default; raises and writes nothing on reject
print("Blamite gate PASSED; wrote %d bytes to %s" % (n, OUT))
