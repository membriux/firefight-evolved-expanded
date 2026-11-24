#!/usr/bin/env python3
"""tools/patch/shop_build.py  -  build the ALLY TIERS and the ally-group reparent into a staged
Firefight cache, for the Courtyard and Glacier ports of the purchase system.

    python3 tools/patch/shop_build.py <map-key> <in.stage2.map> <out.map>
    map-key in {ff20_courtyard, ff60_icecave}

This is the map-parameterised successor to tools/patch/holdout_fe_spartans.py.  Everything it does was
proven on ff70_holdout; nothing structurally new is attempted.  Read-only on the input.

WHAT IT WRITES, and why each piece is needed
--------------------------------------------
0. THE ALLY GROUP BECOMES A ROOT GROUP.  2 bytes, same size: squad group `gr_survival_fireteams`
   `parent` (squad_groups_block + 0x20, short_block_index) -> -1.
     Courtyard  needs it because its chain is fireteams -> gr_survival_waves -> gr_survival_all, and
                stock survival_wave_living_count reads (ai_living_count "gr_survival_all"), so allies
                would be counted as live enemies and the round would never end.
     Glacier    needs it because its chain is fireteams -> gr_survival_extras, which IS a root (so the
                wave count is fine), but stock survival_wave_end_conditions runs
                (ai_survival_cleanup "gr_survival_extras" true true) at the end of EVERY wave, and
                that reaches children.  Research/20 said Glacier needed no reparent; that was about
                the wave count only.  Without this write Glacier deletes every purchased ally each
                wave.
   -1 is an attested stock value for this field in both maps (Courtyard ships 5 root groups, Glacier
   ships 5).

1. THE EQUIPMENT PALETTE IS GROWN so Spartan abilities can be randomised.  A cell's
   `initial equipment` is a short_block_index INTO the scenario palette, so an eqip tag merely being
   in the tag table is not enough.  Both maps ship a tiny palette (Courtyard 2, Glacier 3), so the
   block is copied to new space with extra entries cloned from an existing entry and their datum
   swapped.  Appending never changes an existing index, so the placed ammo_box equipment is unaffected.

2. THE TROOPER SQUADS (sur_fireteam_01, _02) GET SPAWN POINTS.  Each already carries one 4-actor cell
   from the stage-2 build, pointed at the repointed Spartan-bodied character - and 0 spawn points,
   which means ai_place on it spawns NOTHING.  Spawn points are the missing half.  Their existing
   cell's weapon fields are also corrected in place, same size: the stage-2 cells inherited Covenant
   weapons from whatever squad was used as the byte template.

3. THE SPARTAN SQUADS (sur_fireteam_03, _04) GET A CELL AND SPAWN POINTS.  2 actors, major upgrade 4
   ('all'), one character choice at the repointed slot, a weighted weapon pool and a weighted ability
   pool.  The engine rolls per actor per spawn, so randomisation costs no script.

EVERY SPAWN POINT POSITION IS THE POSITION OF A PLACED `firefight_respawn_zone` SCENERY OBJECT in the
same map (spartan_respawn_* / elite_respawn_*), read out of the cache at build time.  Those are the
markers the engine itself spawns players on, so the ground is known walkable and known inside the
arena.  NO COORDINATE IS INVENTED.  Reusing one marker position across two squads is deliberate and is
attested in stock: Glacier's sq_sur_wraith_01 ships its `driver` and `gunner` spawn points at the
identical position.

sur_fireteam_05 is left free.  sur_fireteam_06 is never named: on Glacier it is a live Brute wave
squad wearing a fireteam name.
"""
import json
import os
import struct
import sys

PROJ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(PROJ, "tools", "map"))
sys.path.insert(0, os.path.join(PROJ, "tools", "patch"))

import reach_cache as rc    # noqa: E402
import reach_write as rw    # noqa: E402
import tagdefs             # noqa: E402

SPARTANS_BIPD = "objects\\characters\\spartans\\spartans"
RESPAWN_TAG = "objects\\multi\\firefight\\firefight_respawn_zone"

SQUAD_SIZE, CELL_SIZE, CHOICE_SIZE, PALETTE_SIZE = 0x6C, 0x6C, 0x10, 0x10
GRP_PARENT = 0x20
SQ_SPAWN_POINTS, SQ_DESIGNER = 0x3C, 0x54
CELL_COUNT, CELL_MAJOR = 0x10, 0x12
CELL_CHARTYPE, CELL_WEAPON, CELL_WEAPON2, CELL_EQUIP, CELL_VEH = 0x14, 0x20, 0x2C, 0x38, 0x46
CHOICE_INDEX, CHOICE_CHANCE = 0x0C, 0x0E
SP_NAME, SP_CELL, SP_POS = 0x0C, 0x10, 0x14
SP_FLAGS, SP_CHAR, SP_WEAP, SP_WEAP2, SP_EQUIP, SP_VEH, SP_SEAT = 0x30, 0x32, 0x34, 0x36, 0x38, 0x3A, 0x3C
MAJOR_NONE, MAJOR_ALL = 3, 4

# =====================================================================================================
#  PER-MAP CONFIGURATION.  Every index here is a scenario-palette index in THAT map's own palette and
#  was read with build/logs/shop_survey.py before it was written down.  The script re-reads the palette
#  at build time and refuses if an index does not resolve to the tag named in the comment.
# =====================================================================================================
MAPS = {
    "ff20_courtyard": {
        "char_slot": 24,            # objects\characters\null\ai\null_cov_default, repointed in stage 2
        "trooper_squads": ["sur_fireteam_01", "sur_fireteam_02"],
        "spartan_squads": ["sur_fireteam_03", "sur_fireteam_04"],
        "trooper_count": 4,
        "spartan_count": 2,
        # trooper cell corrections: (field, palette index, expected tag suffix)
        "trooper_weapon": (7, "rifle\\dmr\\dmr"),
        "trooper_weapon2": (4, "pistol\\magnum\\magnum"),
        "trooper_major": MAJOR_NONE,
        "spartan_weapons": [
            (14, "rifle\\sniper_rifle\\sniper_rifle"),
            (18, "support_high\\rocket_launcher\\rocket_launcher"),
            (19, "support_high\\spartan_laser\\spartan_laser"),
            (9,  "rifle\\grenade_launcher\\grenade_launcher"),
            (21, "plasma_turret\\plasma_turret"),
        ],
        # equipment palette entries to append, in order, cloned from the entry named in `clone_from`
        "equip_append": [
            "objects\\equipment\\sprint\\sprint",
            "objects\\equipment\\jet_pack\\jet_pack",
            "objects\\equipment\\active_camouflage\\active_camouflage",
        ],
        "equip_clone_from": "objects\\equipment\\drop_shield\\drop_shield",
        # ability pool: existing drop_shield plus the three appended.  Resolved by PATH, not index, so
        # a palette that ships in a different order cannot silently shift the pool.
        "ability_paths": [
            "objects\\equipment\\drop_shield\\drop_shield",
            "objects\\equipment\\sprint\\sprint",
            "objects\\equipment\\jet_pack\\jet_pack",
            "objects\\equipment\\active_camouflage\\active_camouflage",
        ],
        # spawn point positions, by the name of the placed firefight_respawn_zone marker.
        # All four are in the REAR base cluster, beside the shop.
        "spawn_at": {
            "sur_fireteam_01": ["spartan_respawn_01", "spartan_respawn_05",
                                "spartan_respawn_03", "elite_respawn_04"],
            "sur_fireteam_02": ["spartan_respawn_01", "spartan_respawn_05",
                                "spartan_respawn_03", "elite_respawn_04"],
            "sur_fireteam_03": ["spartan_respawn_01", "spartan_respawn_05"],
            "sur_fireteam_04": ["spartan_respawn_03", "elite_respawn_04"],
        },
        "cell_template_from": "sur_fireteam_01",
        "spawn_template_from": "sq_sur_drop_01",
    },
    "ff60_icecave": {
        "char_slot": 24,
        "trooper_squads": ["sur_fireteam_01", "sur_fireteam_02"],
        "spartan_squads": ["sur_fireteam_03", "sur_fireteam_04"],
        "trooper_count": 4,
        "spartan_count": 2,
        "trooper_weapon": (7, "rifle\\dmr\\dmr"),
        "trooper_weapon2": None,        # Glacier's stage-2 cell has no secondary-weapon entry
        "trooper_major": MAJOR_NONE,
        # CLOSE-QUARTERS pool: Glacier is a cave, and its 21-entry palette has no detached plasma
        # turret (Courtyard's [21]), so the fifth slot does not exist here.
        "spartan_weapons": [
            (13, "rifle\\shotgun\\shotgun"),
            (18, "support_high\\rocket_launcher\\rocket_launcher"),
            (19, "support_high\\spartan_laser\\spartan_laser"),
            (9,  "rifle\\grenade_launcher\\grenade_launcher"),
        ],
        "equip_append": [
            "objects\\equipment\\sprint\\sprint",
            "objects\\equipment\\active_camouflage\\active_camouflage",
        ],
        "equip_clone_from": "objects\\equipment\\drop_shield\\drop_shield",
        # NO JET PACK on Glacier: it is underground with no air support, by the map's own design.
        "ability_paths": [
            "objects\\equipment\\drop_shield\\drop_shield",
            "objects\\equipment\\sprint\\sprint",
            "objects\\equipment\\active_camouflage\\active_camouflage",
        ],
        # spartan_respawn_01/_02/_03 are INSIDE tv_wraith, the volume whose occupancy stops the
        # Wraith bombardment.  spartan_respawn_04 is outside it but still a placed respawn zone,
        # i.e. still walkable in-arena floor; it is the fourth trooper point because tv_wraith
        # contains only three markers.
        "spawn_at": {
            "sur_fireteam_01": ["spartan_respawn_01", "spartan_respawn_02",
                                "spartan_respawn_03", "spartan_respawn_04"],
            "sur_fireteam_02": ["spartan_respawn_01", "spartan_respawn_02",
                                "spartan_respawn_03", "spartan_respawn_04"],
            "sur_fireteam_03": ["spartan_respawn_01", "spartan_respawn_03"],
            "sur_fireteam_04": ["spartan_respawn_02", "spartan_respawn_03"],
        },
        "cell_template_from": "sur_fireteam_01",
        "spawn_template_from": "sq_sur_wraith_01",
    },
    # ff70_holdout: the PORT of the original Holdout build onto this same fireteam pattern.
    # The original used sq_sur_drop_01..04 as the ally bodies, which collided with stock
    # survival_drop_spawn: it runs (ai_erase "sq_sur_drop_01".."04") on every cycle UNGATED by
    # g_sur_drop_spawn, and then ends the cycle with (set g_sur_drop_spawn true), which undoes the
    # two global writes ff70_holdout_stock_hooks.hsc made. Allies were therefore deleted on a timer
    # and Spartan-bodied ENEMIES resumed dropping. Using the fireteam squads removes both: the stock
    # drop-pod event is left exactly as Bungie shipped it and the diff against its text is empty.
    "ff70_holdout": {
        "char_slot": 25,            # objects\characters\null\ai\null_cov_default, repointed in stage 2
        "trooper_squads": ["sur_fireteam_01", "sur_fireteam_02"],
        "spartan_squads": ["sur_fireteam_03", "sur_fireteam_04"],
        "trooper_count": 4,
        "spartan_count": 2,
        "trooper_weapon": (13, "rifle\\dmr\\dmr"),
        "trooper_weapon2": None,    # Holdout's stage-2 trooper cell has no secondary-weapon entry
        "trooper_major": MAJOR_NONE,
        "spartan_weapons": [
            (8,  "rifle\\sniper_rifle\\sniper_rifle"),
            (11, "support_high\\rocket_launcher\\rocket_launcher"),
            (12, "support_high\\spartan_laser\\spartan_laser"),
            (19, "rifle\\grenade_launcher\\grenade_launcher"),
            (15, "plasma_turret\\plasma_turret"),
        ],
        # Holdout already ships sprint [1], jet_pack [2] and drop_shield [5]; only camo is missing.
        "equip_append": [
            "objects\\equipment\\active_camouflage\\active_camouflage",
        ],
        "equip_clone_from": "objects\\equipment\\drop_shield\\drop_shield",
        "ability_paths": [
            "objects\\equipment\\drop_shield\\drop_shield",
            "objects\\equipment\\sprint\\sprint",
            "objects\\equipment\\jet_pack\\jet_pack",
            "objects\\equipment\\active_camouflage\\active_camouflage",
        ],
        # All four markers are in the player base, the same cluster the shop sits in:
        # spartan_respawn_00 (442.14,116.34,-4.96)  _01 (443.46,120.72,-7.24)
        # spartan_respawn_04 (440.42,123.55,-5.16)  _05 (444.44,120.72,-8.70)
        "spawn_at": {
            "sur_fireteam_01": ["spartan_respawn_00", "spartan_respawn_01",
                                "spartan_respawn_04", "spartan_respawn_05"],
            "sur_fireteam_02": ["spartan_respawn_00", "spartan_respawn_01",
                                "spartan_respawn_04", "spartan_respawn_05"],
            "sur_fireteam_03": ["spartan_respawn_00", "spartan_respawn_04"],
            "sur_fireteam_04": ["spartan_respawn_01", "spartan_respawn_05"],
        },
        "cell_template_from": "sur_fireteam_01",
        "spawn_template_from": "sq_sur_drop_01",
    },
}


def die(msg):
    sys.exit("REFUSING: %s" % msg)


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__.strip().splitlines()[2].strip())
    key, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    if key not in MAPS:
        die("unknown map key %r; known: %s" % (key, ", ".join(sorted(MAPS))))
    cfg = MAPS[key]

    cache = rc.ReachCacheFile.from_path(src)
    data = cache.data
    defs = tagdefs.TagDefs()
    scnr = cache.global_tag("scnr")
    base = scnr.offset
    SF = {f.name: f for f in defs.fields_of("scenario_struct_definition") if f.name}
    bydatum = {t.datum: t for t in cache.tags}
    bypath = {}
    for t in cache.tags:
        bypath.setdefault((t.group_code, t.path), t)

    def blk(off):
        n, ptr = struct.unpack_from("<Ii", data, off)
        return (n, cache.meta_to_offset(cache.expand(ptr & 0xFFFFFFFF)) if n else None)

    def sblk(name):
        return blk(base + SF[name].offset)

    def ssize(defn):
        for cand in (defn, defn + "_struct", defn.replace("_block", "_struct")):
            try:
                return defs.struct_size(cand)
            except Exception:
                continue
        die("no struct size for %r" % defn)

    def sid(off):
        raw = struct.unpack_from("<I", data, off)[0]
        try:
            return cache.resolve_sid(raw)
        except Exception:
            return None

    print("map    : %s  (%s)" % (key, src))
    print("build  : %r   tags=%d   scnr body @0x%X" % (cache.build_string, len(cache.tags), base))

    # ---- 0. the input must already be Spartan-bodied ------------------------------------------------
    cpal_n, cpal_o = sblk("character palette")
    slot = cfg["char_slot"]
    if slot >= cpal_n:
        die("character palette has %d entries; slot %d does not exist" % (cpal_n, slot))
    victim = bydatum.get(struct.unpack_from("<I", data, cpal_o + slot * PALETTE_SIZE + 0xC)[0])
    if victim is None:
        die("character palette[%d] is null" % slot)
    unit = bydatum.get(struct.unpack_from("<I", data, victim.offset + 0x20)[0])
    if unit is None or unit.path != SPARTANS_BIPD:
        die("char palette[%d] (%s) does not point at %s yet; run the stage-2 repoint first"
            % (slot, victim.path, SPARTANS_BIPD))
    print("input  : char palette[%d] %s -> %s  OK" % (slot, victim.path, unit.path))

    # ---- object names + placed respawn markers, for the spawn point positions -----------------------
    on_n, on_o, = sblk("object names")
    on_sz = ssize(SF["object names"].definition)
    names = [sid(on_o + i * on_sz) for i in range(on_n)]
    sc_n, sc_o = sblk("scenery")
    sc_sz = ssize(SF["scenery"].definition)
    sc_pal_n, sc_pal_o = sblk("scenery palette")
    sc_pal = [bydatum.get(struct.unpack_from("<I", data, sc_pal_o + i * PALETTE_SIZE + 0xC)[0])
              for i in range(sc_pal_n)]
    markers = {}
    for i in range(sc_n):
        off = sc_o + i * sc_sz
        pi, ni = struct.unpack_from("<hh", data, off)
        tag = sc_pal[pi] if 0 <= pi < len(sc_pal) else None
        if tag is None or tag.path != RESPAWN_TAG:
            continue
        nm = names[ni] if 0 <= ni < len(names) else None
        if nm:
            markers[nm] = struct.unpack_from("<fff", data, off + 0x08)
    print("markers: %d placed firefight_respawn_zone objects: %s"
          % (len(markers), ", ".join(sorted(markers))))
    for sq, pts in cfg["spawn_at"].items():
        for p in pts:
            if p not in markers:
                die("%s names respawn marker %r, which this map does not place" % (sq, p))

    # ---- the squad group reparent --------------------------------------------------------------------
    g_n, g_o = sblk("squad groups")
    groups = [data[g_o + i * 0x28:g_o + i * 0x28 + 32].split(b"\0")[0].decode("latin-1")
              for i in range(g_n)]
    if "gr_survival_fireteams" not in groups:
        die("this map has no gr_survival_fireteams squad group")
    gi = groups.index("gr_survival_fireteams")
    g_parent_off = g_o + gi * 0x28 + GRP_PARENT
    g_parent_now = struct.unpack_from("<h", data, g_parent_off)[0]
    roots = [n for i, n in enumerate(groups)
             if struct.unpack_from("<h", data, g_o + i * 0x28 + GRP_PARENT)[0] < 0]
    print("reparent: squad groups[%d] gr_survival_fireteams parent %d (%s) -> -1 @0x%X"
          % (gi, g_parent_now,
             groups[g_parent_now] if 0 <= g_parent_now < g_n else "(root)", g_parent_off))
    print("          -1 is attested in this map: %d root group(s) ship that way (%s)"
          % (len(roots), ", ".join(roots)))

    # ---- the squads -----------------------------------------------------------------------------------
    sq_n, sq_o = sblk("squads")
    squad = {}
    for i in range(sq_n):
        o = sq_o + i * SQUAD_SIZE
        squad[data[o:o + 32].split(b"\0")[0].decode("latin-1")] = (i, o)
    for nm in cfg["trooper_squads"] + cfg["spartan_squads"] + \
            [cfg["cell_template_from"], cfg["spawn_template_from"]]:
        if nm not in squad:
            die("squad %r not present" % nm)
    if "sur_fireteam_06" in squad:
        i06, o06 = squad["sur_fireteam_06"]
        print("untouched: sur_fireteam_06 is squad %d, parent %d, flags 0x%X - never written"
              % (i06, struct.unpack_from("<h", data, o06 + 0x26)[0],
                 struct.unpack_from("<I", data, o06 + 0x20)[0]))

    # trooper squads must already carry exactly one cell and no spawn points
    for nm in cfg["trooper_squads"]:
        _i, o = squad[nm]
        dn, _do = blk(o + SQ_DESIGNER)
        pn, _po = blk(o + SQ_SPAWN_POINTS)
        if dn != 1 or pn != 0:
            die("%s has %d cell(s) and %d spawn point(s); expected 1 and 0 from the stage-2 build"
                % (nm, dn, pn))
    # spartan squads must be completely free
    for nm in cfg["spartan_squads"]:
        _i, o = squad[nm]
        dn, _ = blk(o + SQ_DESIGNER)
        tn, _ = blk(o + 0x60)
        pn, _ = blk(o + SQ_SPAWN_POINTS)
        if dn or tn or pn:
            die("%s is not a free slot (cells=%d templated=%d spawnpts=%d)" % (nm, dn, tn, pn))

    # ---- palettes: validate every index we are about to write ---------------------------------------
    w_pal_n, w_pal_o = sblk("weapon palette")
    wpal = [bydatum.get(struct.unpack_from("<I", data, w_pal_o + i * PALETTE_SIZE + 0xC)[0])
            for i in range(w_pal_n)]

    def check_weapon(idx, suffix, label):
        if not (0 <= idx < w_pal_n) or wpal[idx] is None or not wpal[idx].path.endswith(suffix):
            die("%s: weapon palette[%d] is %s, expected something ending %r"
                % (label, idx, wpal[idx].path if 0 <= idx < w_pal_n and wpal[idx] else "(absent)",
                   suffix))
        print("   weapon palette[%2d] = %s   (%s)" % (idx, wpal[idx].path, label))

    print("weapon pool, validated against this map's own palette (%d entries):" % w_pal_n)
    tw_i, tw_s = cfg["trooper_weapon"]
    check_weapon(tw_i, tw_s, "trooper primary")
    if cfg["trooper_weapon2"]:
        t2_i, t2_s = cfg["trooper_weapon2"]
        check_weapon(t2_i, t2_s, "trooper secondary")
    for idx, suffix in cfg["spartan_weapons"]:
        check_weapon(idx, suffix, "spartan pool")

    # ---- equipment palette: clone + append ------------------------------------------------------------
    e_pal_n, e_pal_o = sblk("equipment palette")
    EQ_OLD = bytes(data[e_pal_o:e_pal_o + e_pal_n * PALETTE_SIZE])
    eq_paths = [bydatum.get(struct.unpack_from("<I", EQ_OLD, i * PALETTE_SIZE + 0xC)[0])
                for i in range(e_pal_n)]
    eq_paths = [t.path if t else None for t in eq_paths]
    clone_from = cfg["equip_clone_from"]
    if clone_from not in eq_paths:
        die("equipment palette has no %s entry to clone from (has: %s)" % (clone_from, eq_paths))
    clone_i = eq_paths.index(clone_from)
    EQ_NEW = bytearray(EQ_OLD)
    for p in cfg["equip_append"]:
        if p in eq_paths:
            die("equipment palette already has %s; appending it would duplicate" % p)
        t = bypath.get(("eqip", p))
        if t is None:
            die("this map's tag table has no eqip %s" % p)
        entry = bytearray(EQ_OLD[clone_i * PALETTE_SIZE:(clone_i + 1) * PALETTE_SIZE])
        struct.pack_into("<I", entry, 0xC, t.datum)
        EQ_NEW += entry
        eq_paths.append(p)
    print("equipment palette: %d -> %d entries, each cloned from [%d] %s"
          % (e_pal_n, len(eq_paths), clone_i, clone_from))
    ability_idx = []
    for p in cfg["ability_paths"]:
        if p not in eq_paths:
            die("ability %s is not in the new equipment palette" % p)
        ability_idx.append(eq_paths.index(p))
        print("   equipment palette[%d] = %s" % (eq_paths.index(p), p))

    # ---- templates, cloned from real structures in THIS map ------------------------------------------
    _i, tcell_sq = squad[cfg["cell_template_from"]]
    tcn, tco = blk(tcell_sq + SQ_DESIGNER)
    if tcn != 1:
        die("cell template squad %s has %d cells" % (cfg["cell_template_from"], tcn))
    CELL_TPL = bytes(data[tco:tco + CELL_SIZE])
    if struct.unpack_from("<h", CELL_TPL, CELL_VEH)[0] != -1:
        die("cell template has vehicle type %d, not -1; allies would spawn in a vehicle"
            % struct.unpack_from("<h", CELL_TPL, CELL_VEH)[0])
    chn, cho = blk(tco + CELL_CHARTYPE)
    if chn < 1:
        die("cell template has no character choice to use as a 16-byte template")
    ptn, _pto = blk(tco + 0x60)          # patrol `points`
    if ptn:
        die("cell template has %d patrol point(s); the clone would share that block with the "
            "template squad" % ptn)
    CHOICE_TPL = bytes(data[cho:cho + CHOICE_SIZE])
    _i, tsp_sq = squad[cfg["spawn_template_from"]]
    tpn, tpo = blk(tsp_sq + SQ_SPAWN_POINTS)
    if tpn < 1:
        die("spawn point template squad %s has no spawn points" % cfg["spawn_template_from"])
    SPAWN_SIZE = ssize("spawn_points_block")
    SPAWN_TPL = bytes(data[tpo:tpo + SPAWN_SIZE])
    print("templates: cell %dB from %s, choice %dB, spawn point %dB from %s"
          % (len(CELL_TPL), cfg["cell_template_from"], len(CHOICE_TPL), SPAWN_SIZE,
             cfg["spawn_template_from"]))

    # ---- allocate -------------------------------------------------------------------------------------
    n_sp = sum(len(v) for v in cfg["spawn_at"].values())
    need = (len(EQ_NEW)
            + len(cfg["spartan_squads"]) * (CELL_SIZE
                                            + CHOICE_SIZE
                                            + len(cfg["spartan_weapons"]) * CHOICE_SIZE
                                            + len(ability_idx) * CHOICE_SIZE)
            + len(cfg["trooper_squads"]) * 2 * CHOICE_SIZE      # fresh, unshared weapon choices
            + n_sp * SPAWN_SIZE
            + 256)
    w = rw.CacheWriter(cache)
    growth = w.grow_tag_area(need, mode="end")
    cur = growth.free_offset
    print("allocated 0x%X bytes (asked 0x%X) at file 0x%X / addr 0x%X"
          % (growth.granted, need, cur, growth.free_address))

    def emit(payload):
        nonlocal cur
        off = cur
        w.patch(off, bytes(payload))
        cur += len(payload)
        return off

    def set_block(buf_off, count, target_off):
        struct.pack_into("<i", w.buf, buf_off, count)
        struct.pack_into("<I", w.buf, buf_off + 4, w.contract(w.address_of(target_off)))

    def choice(index, chance=1):
        c = bytearray(CHOICE_TPL)
        struct.pack_into("<h", c, CHOICE_INDEX, index)
        struct.pack_into("<h", c, CHOICE_CHANCE, chance)
        return bytes(c)

    def spawn_points(sqname, cell_index=0):
        first = None
        for k, mname in enumerate(cfg["spawn_at"][sqname]):
            x, y, z = markers[mname]
            sp = bytearray(SPAWN_TPL)
            struct.pack_into("<I", sp, SP_NAME, 0)       # unnamed: nothing references these by name
            struct.pack_into("<h", sp, SP_CELL, cell_index)
            struct.pack_into("<fff", sp, SP_POS, x, y, z)
            struct.pack_into("<H", sp, SP_FLAGS, 0)
            struct.pack_into("<h", sp, SP_CHAR, -1)      # -1 = take the character from the cell
            struct.pack_into("<h", sp, SP_WEAP, -1)      # -1 = take the weapon from the cell, i.e.
            struct.pack_into("<h", sp, SP_WEAP2, -1)     #      from the randomised pool
            struct.pack_into("<h", sp, SP_EQUIP, -1)
            struct.pack_into("<h", sp, SP_VEH, -1)       # ON FOOT, whatever the template was
            struct.pack_into("<h", sp, SP_SEAT, 0)
            off = emit(sp)
            if k == 0:
                first = off
        return first, len(cfg["spawn_at"][sqname])

    # 1. relocate the equipment palette first, so the appended indices are live for the cells
    eq_off = emit(EQ_NEW)
    set_block(base + SF["equipment palette"].offset, len(eq_paths), eq_off)

    # 2. trooper squads: REPOINT the stage-2 cell's weapon blocks onto fresh choices, then give the
    #    squad spawn points.
    #
    #    THE WEAPON FIELDS MUST NOT BE EDITED IN PLACE.  The stage-2 build cloned its cells from a
    #    stock squad and left the clone's `initial weapon` / `initial secondary weapon` BLOCK POINTERS
    #    aimed at the template's own choice blobs, so those blobs are SHARED with live stock squads:
    #      Courtyard  sur_fireteam_01/_02 initial weapon -> 0x5865AE4, which is simultaneously
    #                 sq_sur_drop_01's initial weapon AND sq_sur_drop_02's CHARACTER choice;
    #                 initial secondary -> 0x5865AF4, also sq_sur_drop_04's secondary.
    #      Glacier    sur_fireteam_01/_02 initial weapon -> 0x52DC944, which is sq_sur_wraith_01's
    #                 and sq_sur_wraith_02's initial weapon.
    #    Writing a trooper rifle into those offsets would re-arm Bungie's drop squads and Wraith crews,
    #    or worse, rewrite a character index as a weapon index.  Emitting new choices and repointing
    #    the cell is the only safe form, and it is the same primitive the Spartan tier already uses.
    print()
    for nm in cfg["trooper_squads"]:
        _i, o = squad[nm]
        dn, do = blk(o + SQ_DESIGNER)
        wn, wo = blk(do + CELL_WEAPON)
        w2n, w2o = blk(do + CELL_WEAPON2)
        before_major = struct.unpack_from("<h", w.buf, do + CELL_MAJOR)[0]
        struct.pack_into("<h", w.buf, do + CELL_MAJOR, cfg["trooper_major"])
        before_w = struct.unpack_from("<h", data, wo + CHOICE_INDEX)[0] if wn else None
        new_w = emit(choice(cfg["trooper_weapon"][0]))
        set_block(do + CELL_WEAPON, 1, new_w)
        before_w2 = struct.unpack_from("<h", data, w2o + CHOICE_INDEX)[0] if w2n else None
        if cfg["trooper_weapon2"]:
            new_w2 = emit(choice(cfg["trooper_weapon2"][0]))
            set_block(do + CELL_WEAPON2, 1, new_w2)
        else:
            struct.pack_into("<i", w.buf, do + CELL_WEAPON2, 0)
            struct.pack_into("<I", w.buf, do + CELL_WEAPON2 + 4, 0)
        sp_first, sp_n = spawn_points(nm)
        set_block(o + SQ_SPAWN_POINTS, sp_n, sp_first)
        print("  %-18s TROOPERS: cell@0x%X n=%d major %d->%d weapon %s->%d (new choice@0x%X, was "
              "shared @0x%X) secondary %s->%s, %d spawn point(s) @0x%X"
              % (nm, do, struct.unpack_from("<h", w.buf, do + CELL_COUNT)[0],
                 before_major, cfg["trooper_major"], before_w, cfg["trooper_weapon"][0],
                 new_w, wo if wn else 0,
                 before_w2, cfg["trooper_weapon2"][0] if cfg["trooper_weapon2"] else "none",
                 sp_n, sp_first))

    # 3. spartan squads: a fresh cell, then spawn points
    for nm in cfg["spartan_squads"]:
        _i, o = squad[nm]
        char_off = emit(choice(slot))
        weap_first = None
        for k, (idx, _s) in enumerate(cfg["spartan_weapons"]):
            off = emit(choice(idx))
            if k == 0:
                weap_first = off
        eq_first = None
        for k, idx in enumerate(ability_idx):
            off = emit(choice(idx))
            if k == 0:
                eq_first = off
        cell = bytearray(CELL_TPL)
        struct.pack_into("<h", cell, CELL_COUNT, cfg["spartan_count"])
        struct.pack_into("<h", cell, CELL_MAJOR, MAJOR_ALL)
        struct.pack_into("<h", cell, CELL_VEH, -1)
        struct.pack_into("<i", cell, CELL_CHARTYPE, 1)
        struct.pack_into("<I", cell, CELL_CHARTYPE + 4, w.contract(w.address_of(char_off)))
        struct.pack_into("<i", cell, CELL_WEAPON, len(cfg["spartan_weapons"]))
        struct.pack_into("<I", cell, CELL_WEAPON + 4, w.contract(w.address_of(weap_first)))
        struct.pack_into("<i", cell, CELL_WEAPON2, 0)     # no secondary: the pool is the primary
        struct.pack_into("<I", cell, CELL_WEAPON2 + 4, 0)
        struct.pack_into("<i", cell, CELL_EQUIP, len(ability_idx))
        struct.pack_into("<I", cell, CELL_EQUIP + 4, w.contract(w.address_of(eq_first)))
        cell_off = emit(cell)
        set_block(o + SQ_DESIGNER, 1, cell_off)
        sp_first, sp_n = spawn_points(nm)
        set_block(o + SQ_SPAWN_POINTS, sp_n, sp_first)
        print("  %-18s SPARTANS: cell@0x%X n=%d major=all, %d weapon choice(s), %d ability choice(s), "
              "%d spawn point(s) @0x%X"
              % (nm, cell_off, cfg["spartan_count"], len(cfg["spartan_weapons"]), len(ability_idx),
                 sp_n, sp_first))

    # 4. the reparent, last, so it is the only same-size write outside the grown page
    struct.pack_into("<h", w.buf, g_parent_off, -1)

    w.update_checksum()
    n = w.save(out)
    print()
    print("Blamite gate PASSED; wrote %d bytes to %s" % (n, out))
    print("NEXT, AND NON-NEGOTIABLE: re-parse and byte-diff this output before calling it verified.")
    meta = {
        "map": key, "src": src, "out": out,
        "char_slot": slot, "char_tag": victim.index, "biped": unit.path,
        "group_index": gi, "group_parent_offset": g_parent_off,
        "group_parent_before": g_parent_now, "group_parent_after": -1,
        "equip_palette": eq_paths, "ability_idx": ability_idx,
        "spartan_weapons": [i for i, _ in cfg["spartan_weapons"]],
        "trooper_weapon": cfg["trooper_weapon"][0],
        "spawn_markers": {k: [[round(c, 2) for c in markers[m]] for m in v]
                          for k, v in cfg["spawn_at"].items()},
        "growth": {"granted": growth.granted, "free_offset": growth.free_offset,
                   "used": cur - growth.free_offset},
    }
    with open(out + ".shopbuild.json", "w") as fh:
        json.dump(meta, fh, indent=1)
    print("manifest: %s.shopbuild.json" % out)


if __name__ == "__main__":
    main()
