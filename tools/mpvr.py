#!/usr/bin/env python3
"""mpvr.py - decoder for the `mpvr` chunk of Halo: Reach (MCC) .bin game variants.

Ported from DavidJCobb/ReachVariantEditor (GPLv3), specifically:
  native/src/ReachVariantTool/helpers/bitreader.h      (bit order)
  native/src/ReachVariantTool/helpers/bitnumber.h      (field encoding rules)
  native/src/ReachVariantTool/game_variants/base.cpp   (mpvr block framing + SHA-1)
  native/src/ReachVariantTool/game_variants/types/firefight.cpp
  native/src/ReachVariantTool/game_variants/types/multiplayer.cpp
  native/src/ReachVariantTool/game_variants/components/*
  native/src/ReachVariantTool/formats/localized_string_table.cpp

Bit order is MSB-first within each byte and big-endian across bytes. This is
proven at runtime by --prove-bitorder, which recovers the localized string
table and the UTF-16BE title/description.

Usage:
    python3 mpvr.py <file.bin> [--dump] [--json] [--prove-bitorder] [--megalo-probe]
"""

import argparse
import hashlib
import json
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bitreader import BitReader  # noqa: E402

# ---------------------------------------------------------------------------
# constants from ReachVariantEditor
# ---------------------------------------------------------------------------

REACH_SHA1_SALT = bytes([
    0xED, 0xD4, 0x30, 0x09, 0x66, 0x6D, 0x5C, 0x4A,
    0x5C, 0x36, 0x57, 0xFA, 0xB4, 0x0E, 0x02, 0x2F,
    0x53, 0x5A, 0xC6, 0xC9, 0xEE, 0x47, 0x1F, 0x01,
    0xF1, 0xA4, 0x47, 0x56, 0xB7, 0x71, 0x4F, 0x1C,
    0x36, 0xEC,
])

# mpvr payload: 20-byte SHA-1, 4 unused bytes, 4-byte BE hashable length, then bits.
MPVR_HASH_LEN = 20
MPVR_PREAMBLE = 28          # hash + unused4 + length4
LANGUAGE_COUNT = 12         # formats/localized_string_table.h

GAME_ENGINE = {0: 'none', 1: 'forge', 2: 'multiplayer', 3: 'campaign', 4: 'firefight'}
FILE_TYPE = {-1: 'none', 0: 'dlc', 1: 'campaign_save', 2: 'screenshot', 3: 'film',
             4: 'film_clip', 5: 'map_variant', 6: 'game_variant', 7: 'playlist'}
GAME_MODE = {0: 'none', 1: 'campaign', 2: 'firefight', 3: 'matchmaking',
             4: 'forge', 5: 'theater'}

FF_SQUAD = {
    -1: 'none', 0: 'brutes', 1: 'brute_kill_team', 2: 'brute_patrol',
    3: 'brute_infantry', 4: 'brute_tactical', 5: 'brute_chieftains', 6: 'elites',
    7: 'elite_patrol', 8: 'elite_infantry', 9: 'elite_airborne', 10: 'elite_tactical',
    11: 'elite_spec_ops', 12: 'engineers', 13: 'elite_generals', 14: 'grunts',
    15: 'hunter_kill_team', 16: 'hunter_patrol', 17: 'hunter_strike_team',
    18: 'jackal_patrol', 19: 'elite_strike_team', 20: 'skirmisher_patrol',
    21: 'hunters', 22: 'jackal_snipers', 23: 'jackals', 24: 'hunter_infantry',
    25: 'guta', 26: 'skirmishers', 27: 'hunter_tactical', 28: 'skirmisher_infantry',
    29: 'heretics', 30: 'heretic_snipers', 31: 'heretic_heavy',
}

FF_SKULLS = ['iron', 'black_eye', 'tough_luck', 'catch', 'fog', 'famine',
             'thunderstorm', 'tilt', 'mythic', 'assassin', 'blind', 'cowbell',
             'grunt_birthday_party', 'iwhbyd', 'red', 'yellow', 'blue']

WEAPON = {-4: 'random', -3: 'unchanged', -2: 'map_default', -1: 'none',
          0: 'dmr', 1: 'assault_rifle', 2: 'plasma_pistol', 3: 'spiker',
          4: 'energy_sword', 5: 'magnum', 6: 'needler', 7: 'plasma_rifle',
          8: 'rocket_launcher', 9: 'shotgun', 10: 'sniper_rifle', 11: 'spartan_laser',
          12: 'gravity_hammer', 13: 'plasma_repeater', 14: 'needle_rifle',
          15: 'focus_rifle', 16: 'plasma_launcher', 17: 'concussion_rifle',
          18: 'grenade_launcher', 19: 'golf_club', 20: 'fuel_rod_gun',
          21: 'machine_gun_turret', 22: 'plasma_cannon', 23: 'target_locator'}

ABILITY = {-4: 'random', -3: 'unchanged', -2: 'map_default', -1: 'none',
           0: 'sprint', 1: 'jetpack', 2: 'armor_lock', 3: 'unused_power_fist',
           4: 'active_camo', 5: 'unused_ammo_pack', 6: 'unused_sensor_pack',
           7: 'hologram', 8: 'evade', 9: 'drop_shield'}

WEAPON_SET = {-3: 'random', -2: 'map_default', -1: 'none', 0: 'human', 1: 'covenant',
              2: 'no_snipers', 3: 'rocket_launchers', 4: 'no_power_weapons',
              5: 'juggernaut', 6: 'slayer_pro', 7: 'rifles_only', 8: 'mid_range_only',
              9: 'long_range_only', 10: 'sniper_rifles', 11: 'melee',
              12: 'energy_swords', 13: 'gravity_hammers', 14: 'mass_destruction'}

VEHICLE_SET = {-2: 'map_default', 0: 'mongooses', 1: 'warthogs', 2: 'no_aircraft',
               3: 'only_aircraft', 4: 'no_tanks', 5: 'only_tanks',
               6: 'no_light_ground', 7: 'only_light_ground', 8: 'no_covenant',
               9: 'all_covenant', 10: 'no_human', 11: 'all_human', 12: 'none',
               13: 'all'}

# player-trait enumerations (components/player_traits.h)
E = {
 'damage_resist': ['unchanged','010%','050%','090%','100%','110%','150%','200%','300%','500%','1000%','2000%','invulnerable'],
 'health_multiplier': ['unchanged','000%','100%','150%','200%','300%','400%'],
 'health_rate': ['unchanged','-25%','-10%','-05%','000%','050%','090%','100%','110%','200%'],
 'shield_multiplier': ['unchanged','000%','100%','150%','200%','300%','400%'],
 'shield_rate': ['unchanged','-25%','-10%','-05%','000%','010%','025%','050%','075%','090%','100%','110%','125%','150%','200%'],
 'bool_trait': ['unchanged','disabled','enabled'],
 'vampirism_rate': ['unchanged','000%','010%','025%','050%','100%'],
 'damage_multiplier': ['unchanged','000%','025%','050%','075%','090%','100%','110%','125%','150%','200%','300%','instant_kill'],
 'grenade_count': ['unchanged','map_default','none','frag_1','frag_2','frag_3','frag_4','plasma_1','plasma_2','plasma_3','plasma_4','each_1','each_2','each_3','each_4'],
 'infinite_ammo': ['unchanged','disabled','enabled','bottomless'],
 'ability_usage': ['unchanged','disabled','not_with_objectives','enabled'],
 'movement_speed': ['unchanged','000%','025%','050%','075%','090%','100%','110%','120%','130%','140%','150%','160%','170%','180%','190%','200%','300%'],
 'player_gravity': ['unchanged','050%','075%','100%','150%','200%'],
 'vehicle_usage': ['unchanged','none','passenger_only','driver_only','gunner_only','no_passenger','no_driver','no_gunner','full_use'],
 'double_jump': ['unchanged','disabled','enabled','enabled_plus_lunge'],
 'active_camo': ['unchanged','off','worst','poor','good','best'],
 'visible_identity': ['unchanged','none','allies','everyone'],
 'aura': ['unchanged','none','team_primary','darken_armor','pastel_armor','unknown_5','unknown_6'],
 'forced_color': ['unchanged','none','red','blue','green','orange','purple','gold','brown','pink','white','black','zombie','vibrant_pink'],
 'radar_state': ['unchanged','off','allies','normal','enhanced'],
 'radar_range': ['unchanged','10m','15m','25m','50m','75m','100m','150m'],
 'ai_vision': ['unchanged','0','1','2','3','4','5','6'],
 'ai_hearing': ['unchanged','1','2','3'],
 'ai_luck': ['unchanged','1','2','3','4','5','6','7'],
 'ai_shootiness': ['unchanged','1','2','3'],
 'ai_grenades': ['unchanged','1','2','3'],
}


def enum_name(table, value):
    if isinstance(table, dict):
        return table.get(value, '?%d' % value)
    if isinstance(value, int) and 0 <= value < len(table):
        return table[value]
    return '?%s' % value


def flag_names(value, names):
    out = [n for i, n in enumerate(names) if value & (1 << i)]
    return '|'.join(out) if out else 'none'


# ---------------------------------------------------------------------------
# field-reading helpers mirroring cobb::bitnumber semantics
# ---------------------------------------------------------------------------

class Node(dict):
    """Ordered dict subclass used as the structured object tree."""
    pass


class Parser:
    """Reads a Reach game-variant bit stream, recording a field trace."""

    def __init__(self, data, bitpos):
        self.br = BitReader(data, bitpos)
        self.trace = []     # (bitpos, bitlen, path, value) for every field read

    # cobb::bitnumber<bits, T, offset, presence, if_absent>
    def bn(self, bits, signed=False, offset=False, presence=None,
           if_absent=0, name=None):
        start = self.br.pos
        if presence is not None:
            bit = self.br.read(1)
            if bool(bit) != bool(presence):
                self._trace(start, name, if_absent)
                return if_absent
        v = self.br.read(bits)
        if offset:
            v -= 1
        elif signed and presence is None:
            # write_as_signed(): signed && !presence && !offset
            if v & (1 << (bits - 1)):
                v -= (1 << bits)
        self._trace(start, name, v)
        return v

    def bit(self, name=None):
        start = self.br.pos
        v = bool(self.br.read(1))
        self._trace(start, name, v)
        return v

    def _trace(self, start, name, value):
        if name:
            self.trace.append((start, self.br.pos - start, name, value))

    def ascii_str(self, maxlen, name=None):
        start = self.br.pos
        v = self.br.read_cstr_ascii(maxlen)
        self._trace(start, name, v)
        return v

    def utf16_str(self, maxlen, name=None):
        start = self.br.pos
        v = self.br.read_cstr_utf16(maxlen)
        self._trace(start, name, v)
        return v


# ---------------------------------------------------------------------------
# localized string table (formats/localized_string_table.cpp)
# ---------------------------------------------------------------------------

def bitcount(n):
    """cobb::bitcount - bits needed to hold value n."""
    b = 0
    while n:
        b += 1
        n >>= 1
    return b


def read_string_table(p, max_count, max_buffer_size,
                      offset_bitlength=None, buffer_size_bitlength=None):
    """Returns {'count':n, 'strings':[{lang_index: text}], 'compressed':bool}."""
    if offset_bitlength is None:
        offset_bitlength = bitcount(max_buffer_size - 1)
    if buffer_size_bitlength is None:
        buffer_size_bitlength = bitcount(max_buffer_size)
    count_bitlength = bitcount(max_count)

    br = p.br
    count = br.read(count_bitlength)
    n = min(count, max_count)
    all_offsets = []
    for _ in range(n):
        offs = []
        for _lang in range(LANGUAGE_COUNT):
            if br.read(1):
                offs.append(br.read(offset_bitlength))
            else:
                offs.append(-1)
        all_offsets.append(offs)

    result = {'count': count, 'compressed': False, 'strings': [],
              'buffer_size': 0, 'raw_buffer_size': 0}
    if n == 0:
        return result

    uncompressed_size = br.read(buffer_size_bitlength)
    is_compressed = bool(br.read(1))
    size = uncompressed_size
    if is_compressed:
        size = br.read(buffer_size_bitlength)
    buf = br.read_bytes(size)
    result['compressed'] = is_compressed
    result['buffer_size'] = uncompressed_size
    result['raw_buffer_size'] = size
    if is_compressed:
        # first 4 bytes are a redundant BE uncompressed length; zlib data follows
        try:
            buf = zlib.decompress(buf[4:])
        except zlib.error as exc:
            result['error'] = 'zlib: %s' % exc
            return result

    for offs in all_offsets:
        entry = {}
        for lang, off in enumerate(offs):
            if off < 0 or off >= len(buf):
                continue
            end = buf.find(b'\x00', off)
            if end < 0:
                end = len(buf)
            entry[lang] = buf[off:end].decode('utf-8', 'replace')
        result['strings'].append(entry)
    return result


# ---------------------------------------------------------------------------
# shared components
# ---------------------------------------------------------------------------

def read_player_traits(p, prefix):
    t = Node()
    t['damage_resist'] = enum_name(E['damage_resist'], p.bn(4, name=prefix + '.defense.damage_resist'))
    t['health_mult'] = enum_name(E['health_multiplier'], p.bn(3, name=prefix + '.defense.health_mult'))
    t['health_rate'] = enum_name(E['health_rate'], p.bn(4, name=prefix + '.defense.health_rate'))
    t['shield_mult'] = enum_name(E['shield_multiplier'], p.bn(3, name=prefix + '.defense.shield_mult'))
    t['shield_rate'] = enum_name(E['shield_rate'], p.bn(4, name=prefix + '.defense.shield_rate'))
    t['overshield_rate'] = enum_name(E['shield_rate'], p.bn(4, name=prefix + '.defense.overshield_rate'))
    t['headshot_immune'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.defense.headshot_immune'))
    t['vampirism'] = enum_name(E['vampirism_rate'], p.bn(3, name=prefix + '.defense.vampirism'))
    t['assassin_immune'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.defense.assassin_immune'))
    t['cannot_die_from_damage'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.defense.cannot_die_from_damage'))

    t['damage_mult'] = enum_name(E['damage_multiplier'], p.bn(4, name=prefix + '.offense.damage_mult'))
    t['melee_mult'] = enum_name(E['damage_multiplier'], p.bn(4, name=prefix + '.offense.melee_mult'))
    t['weapon_primary'] = enum_name(WEAPON, p.bn(8, signed=True, name=prefix + '.offense.weapon_primary'))
    t['weapon_secondary'] = enum_name(WEAPON, p.bn(8, signed=True, name=prefix + '.offense.weapon_secondary'))
    t['grenade_count'] = enum_name(E['grenade_count'], p.bn(4, name=prefix + '.offense.grenade_count'))
    t['infinite_ammo'] = enum_name(E['infinite_ammo'], p.bn(2, name=prefix + '.offense.infinite_ammo'))
    t['grenade_regen'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.offense.grenade_regen'))
    t['weapon_pickup'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.offense.weapon_pickup'))
    t['ability_usage'] = enum_name(E['ability_usage'], p.bn(2, name=prefix + '.offense.ability_usage'))
    t['abilities_drop_on_death'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.offense.abilities_drop_on_death'))
    t['infinite_ability'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.offense.infinite_ability'))
    t['ability'] = enum_name(ABILITY, p.bn(8, signed=True, name=prefix + '.offense.ability'))

    t['speed'] = enum_name(E['movement_speed'], p.bn(5, name=prefix + '.movement.speed'))
    t['gravity'] = enum_name(E['player_gravity'], p.bn(4, name=prefix + '.movement.gravity'))
    t['vehicle_usage'] = enum_name(E['vehicle_usage'], p.bn(4, name=prefix + '.movement.vehicle_usage'))
    t['double_jump'] = enum_name(E['double_jump'], p.bn(2, name=prefix + '.movement.double_jump'))
    # bitnumber<9, int16_t, false, std::true_type, -1>
    t['jump_height'] = p.bn(9, presence=True, if_absent=-1, name=prefix + '.movement.jump_height')

    t['active_camo'] = enum_name(E['active_camo'], p.bn(3, name=prefix + '.appearance.active_camo'))
    t['waypoint'] = enum_name(E['visible_identity'], p.bn(2, name=prefix + '.appearance.waypoint'))
    t['visible_name'] = enum_name(E['visible_identity'], p.bn(2, name=prefix + '.appearance.visible_name'))
    t['aura'] = enum_name(E['aura'], p.bn(3, name=prefix + '.appearance.aura'))
    t['forced_color'] = enum_name(E['forced_color'], p.bn(4, name=prefix + '.appearance.forced_color'))

    t['radar_state'] = enum_name(E['radar_state'], p.bn(3, name=prefix + '.sensors.radar_state'))
    t['radar_range'] = enum_name(E['radar_range'], p.bn(3, name=prefix + '.sensors.radar_range'))
    t['directional_damage_indicator'] = p.bn(2, name=prefix + '.sensors.directional_damage_indicator')
    return t


def read_wave_traits(p, prefix):
    t = Node()
    t['vision'] = enum_name(E['ai_vision'], p.bn(3, name=prefix + '.vision'))
    t['hearing'] = enum_name(E['ai_hearing'], p.bn(2, name=prefix + '.hearing'))
    t['luck'] = enum_name(E['ai_luck'], p.bn(3, name=prefix + '.luck'))
    t['shootiness'] = enum_name(E['ai_shootiness'], p.bn(2, name=prefix + '.shootiness'))
    t['grenades'] = enum_name(E['ai_grenades'], p.bn(2, name=prefix + '.grenades'))
    t['dont_drop_equipment'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.dont_drop_equipment'))
    t['assassin_immunity'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.assassin_immunity'))
    t['headshot_immunity'] = enum_name(E['bool_trait'], p.bn(2, name=prefix + '.headshot_immunity'))
    t['damage_resist'] = enum_name(E['damage_resist'], p.bn(4, name=prefix + '.damage_resist'))
    t['damage_mult'] = enum_name(E['damage_multiplier'], p.bn(4, name=prefix + '.damage_mult'))
    return t


def read_respawn_options(p, prefix):
    o = Node()
    o['flags'] = flag_names(p.bn(4, name=prefix + '.flags'),
                            ['sync_with_team', 'respawn_with_teammate',
                             'respawn_at_location', 'respawn_on_kills'])
    o['lives_per_round'] = p.bn(6, name=prefix + '.lives_per_round')
    o['team_lives_per_round'] = p.bn(7, name=prefix + '.team_lives_per_round')
    o['respawn_time'] = p.bn(8, name=prefix + '.respawn_time')
    o['suicide_penalty'] = p.bn(8, name=prefix + '.suicide_penalty')
    o['betrayal_penalty'] = p.bn(8, name=prefix + '.betrayal_penalty')
    o['respawn_growth'] = p.bn(4, name=prefix + '.respawn_growth')
    o['loadout_cam_time'] = p.bn(4, name=prefix + '.loadout_cam_time')
    o['traits_duration'] = p.bn(6, name=prefix + '.traits_duration')
    o['traits'] = read_player_traits(p, prefix + '.traits')
    return o


def read_content_author(p, prefix):
    a = Node()
    a['timestamp'] = p.bn(64, name=prefix + '.timestamp')
    a['xuid'] = p.bn(64, name=prefix + '.xuid')
    a['author'] = p.ascii_str(16, name=prefix + '.author')
    a['is_online_id'] = p.bit(name=prefix + '.is_online_id')
    return a


def read_ugc_header(p):
    h = Node()
    h['content_type_raw'] = p.bn(4, offset=True, name='header.content_type')
    h['content_type'] = enum_name(FILE_TYPE, h['content_type_raw'])
    h['file_length'] = p.bn(32, name='header.file_length')
    h['unk08'] = p.bn(64, name='header.unk08')
    h['unk10'] = p.bn(64, name='header.unk10')
    h['unk18'] = p.bn(64, name='header.unk18')
    h['unk20'] = p.bn(64, name='header.unk20')
    h['activity'] = p.bn(3, offset=True, name='header.activity')
    h['game_mode_raw'] = p.bn(3, name='header.game_mode')
    h['game_mode'] = enum_name(GAME_MODE, h['game_mode_raw'])
    h['engine'] = p.bn(3, name='header.engine')
    h['map_id'] = p.bn(32, name='header.map_id')
    h['engine_category'] = p.bn(8, name='header.engine_category')
    h['created_by'] = read_content_author(p, 'header.created_by')
    h['modified_by'] = read_content_author(p, 'header.modified_by')
    h['title'] = p.utf16_str(128, name='header.title')
    h['description'] = p.utf16_str(128, name='header.description')
    if h['content_type_raw'] == 6:      # game_variant
        h['engine_icon'] = p.bn(8, name='header.engine_icon')
    if h['activity'] == 2:
        h['hopper_id'] = p.bn(16, name='header.hopper_id')
    if h['game_mode_raw'] == 1:         # campaign
        h['campaign_id'] = p.bn(8, name='header.campaign.id')
        h['campaign_difficulty'] = p.bn(2, name='header.campaign.difficulty')
        h['campaign_metagame_scoring'] = p.bn(2, name='header.campaign.metagame_scoring')
        h['campaign_rally_point'] = p.bn(8, name='header.campaign.rally_point')
        h['campaign_unk2A4'] = p.bn(32, name='header.campaign.unk2A4')
    elif h['game_mode_raw'] == 2:       # firefight
        h['campaign_difficulty'] = p.bn(2, name='header.campaign.difficulty')
        h['campaign_unk2A4'] = p.bn(32, name='header.campaign.unk2A4')
    return h


def read_custom_game_options(p):
    o = Node()

    g = Node()
    g['flags'] = flag_names(p.bn(4, name='options.general.flags'),
                            ['perfection_enabled', 'new_round_resets_players',
                             'new_round_resets_map', 'teams_enabled'])
    g['time_limit_min'] = p.bn(8, name='options.general.time_limit')
    g['round_limit'] = p.bn(5, name='options.general.round_limit')
    g['rounds_to_win'] = p.bn(4, name='options.general.rounds_to_win')
    g['sudden_death_time'] = p.bn(7, offset=True, name='options.general.sudden_death_time')
    g['grace_period'] = p.bn(5, name='options.general.grace_period')
    o['general'] = g

    o['respawn'] = read_respawn_options(p, 'options.respawn')

    s = Node()
    s['observers'] = p.bit(name='options.social.observers')
    s['team_changes'] = p.bn(2, name='options.social.team_changes')
    s['flags'] = flag_names(p.bn(5, name='options.social.flags'),
                            ['dead_player_voice', 'global_voice', 'proximity_voice',
                             'betrayal_booting', 'friendly_fire'])
    o['social'] = s

    m = Node()
    m['flags'] = flag_names(p.bn(6, name='options.map.flags'),
                            ['grenades', 'shortcuts', 'abilities', 'powerups',
                             'turrets', 'indestructible_vehicles'])
    m['base_traits'] = read_player_traits(p, 'options.map.base_traits')
    m['weapon_set'] = enum_name(WEAPON_SET, p.bn(8, signed=True, name='options.map.weapon_set'))
    m['vehicle_set'] = enum_name(VEHICLE_SET, p.bn(8, signed=True, name='options.map.vehicle_set'))
    m['powerup_red_traits'] = read_player_traits(p, 'options.map.powerups.red.traits')
    m['powerup_blue_traits'] = read_player_traits(p, 'options.map.powerups.blue.traits')
    m['powerup_yellow_traits'] = read_player_traits(p, 'options.map.powerups.yellow.traits')
    m['powerup_red_duration'] = p.bn(7, name='options.map.powerups.red.duration')
    m['powerup_blue_duration'] = p.bn(7, name='options.map.powerups.blue.duration')
    m['powerup_yellow_duration'] = p.bn(7, name='options.map.powerups.yellow.duration')
    o['map'] = m

    t = Node()
    t['scoring'] = p.bn(3, name='options.team.scoring')
    t['species'] = p.bn(3, name='options.team.species')
    t['designator_switch_type'] = p.bn(2, name='options.team.designator_switch_type')
    teams = []
    for i in range(8):
        td = Node()
        td['flags'] = flag_names(p.bn(4, name='options.team[%d].flags' % i),
                                 ['enabled', 'override_color_primary',
                                  'override_color_secondary', 'override_color_text'])
        td['name'] = read_string_table(p, 1, 0x20, 5, 6)
        td['initial_designator'] = p.bn(4, offset=True,
                                        name='options.team[%d].initial_designator' % i)
        td['spartan_or_elite'] = p.bn(1, name='options.team[%d].spartan_or_elite' % i)
        td['color_primary'] = p.bn(32, name='options.team[%d].color_primary' % i)
        td['color_secondary'] = p.bn(32, name='options.team[%d].color_secondary' % i)
        td['color_text'] = p.bn(32, name='options.team[%d].color_text' % i)
        td['fireteam_count'] = p.bn(5, name='options.team[%d].fireteam_count' % i)
        teams.append(td)
    t['teams'] = teams
    o['team'] = t

    lo = Node()
    lo['flags'] = flag_names(p.bn(2, name='options.loadouts.flags'),
                             ['spartan_loadouts', 'elite_loadouts'])
    palette_names = ['spartan_tier_1', 'elite_tier_1', 'spartan_tier_2',
                     'elite_tier_2', 'spartan_tier_3', 'elite_tier_3']
    palettes = Node()
    for pi, pname in enumerate(palette_names):
        entries = []
        for li in range(5):
            l = Node()
            l['visible'] = p.bit(name='options.loadouts.%s[%d].visible' % (pname, li))
            # bitnumber<7, int8_t, false, std::false_type, -1>: present when bit == 0
            l['name_index'] = p.bn(7, presence=False, if_absent=-1,
                                   name='options.loadouts.%s[%d].name_index' % (pname, li))
            l['weapon_primary'] = enum_name(WEAPON, p.bn(8, signed=True,
                                            name='options.loadouts.%s[%d].weapon_primary' % (pname, li)))
            l['weapon_secondary'] = enum_name(WEAPON, p.bn(8, signed=True,
                                              name='options.loadouts.%s[%d].weapon_secondary' % (pname, li)))
            l['ability'] = enum_name(ABILITY, p.bn(8, signed=True,
                                     name='options.loadouts.%s[%d].ability' % (pname, li)))
            l['grenade_count'] = p.bn(4, name='options.loadouts.%s[%d].grenade_count' % (pname, li))
            entries.append(l)
        palettes[pname] = entries
    lo['palettes'] = palettes
    o['loadouts'] = lo
    return o


def read_ff_wave(p, prefix):
    w = Node()
    w['uses_dropship'] = p.bit(name=prefix + '.uses_dropship')
    w['ordered_squads'] = p.bit(name=prefix + '.ordered_squads')
    w['squad_count'] = p.bn(4, name=prefix + '.squad_count')
    squads = []
    for i in range(12):
        # bitnumber<8, firefight_squad, true>  (offset: raw - 1)
        v = p.bn(8, offset=True, name=prefix + '.squads[%d]' % i)
        squads.append(enum_name(FF_SQUAD, v))
    w['squads'] = squads
    w['squads_active'] = squads[:w['squad_count']]
    return w


def read_ff_round(p, prefix):
    r = Node()
    sk = p.bn(18, name=prefix + '.skulls')
    r['skulls_raw'] = sk
    r['skulls'] = [n for i, n in enumerate(FF_SKULLS) if sk & (1 << i)]
    r['wave_initial'] = read_ff_wave(p, prefix + '.wave_initial')
    r['wave_main'] = read_ff_wave(p, prefix + '.wave_main')
    r['wave_boss'] = read_ff_wave(p, prefix + '.wave_boss')
    return r


# ---------------------------------------------------------------------------
# firefight variant body (types/firefight.cpp)
# ---------------------------------------------------------------------------

def read_firefight(p):
    v = Node()
    v['header'] = read_ugc_header(p)
    v['is_built_in'] = p.bit(name='is_built_in')
    v['options'] = read_custom_game_options(p)
    v['scenario_flags'] = flag_names(p.bn(5, name='scenario_flags'),
                                     ['hazards_enabled', 'all_generators_must_survive',
                                      'random_generator_spawns', 'weapon_drops_enabled',
                                      'ammo_crates_enabled'])
    mcc = p.bn(3, name='mcc_extension_version')
    v['mcc_extension_version'] = mcc
    v['wave_limit'] = p.bn(8, name='wave_limit')
    v['unkB'] = p.bn(4, name='unkB')
    v['bonus_target'] = p.bn(15, name='bonus_target')
    v['elite_kill_bonus'] = p.bn(15, name='elite_kill_bonus')
    v['starting_lives_spartan'] = p.bn(7, offset=True, name='starting_lives_spartan')
    v['starting_lives_elite'] = p.bn(7, offset=True, name='starting_lives_elite')
    v['unkD'] = p.bn(15, name='unkD')
    v['max_spartan_extra_lives'] = p.bn(7, offset=True, name='max_spartan_extra_lives')
    v['generator_count'] = p.bn(2, name='generator_count')
    v['base_traits_spartan'] = read_player_traits(p, 'base_traits_spartan')
    v['base_traits_elite'] = read_player_traits(p, 'base_traits_elite')
    v['base_traits_wave'] = read_wave_traits(p, 'base_traits_wave')
    skull_names = ['red', 'yellow', 'blue']
    custom = Node()
    for i, sname in enumerate(skull_names):
        cs = Node()
        cs['traits_spartan'] = read_player_traits(p, 'custom_skull.%s.traits_spartan' % sname)
        cs['traits_elite'] = read_player_traits(p, 'custom_skull.%s.traits_elite' % sname)
        cs['traits_wave'] = read_wave_traits(p, 'custom_skull.%s.traits_wave' % sname)
        custom[sname] = cs
    v['custom_skulls'] = custom
    v['elite_respawn_options'] = read_respawn_options(p, 'elite_respawn_options')
    rounds = []
    for i in range(3):
        rounds.append(read_ff_round(p, 'round[%d]' % i))
    v['rounds'] = rounds
    v['bonus_wave_duration_sec'] = p.bn(12, name='bonus_wave_duration')
    bsk = p.bn(18, name='bonus_wave_skulls')
    v['bonus_wave_skulls_raw'] = bsk
    v['bonus_wave_skulls'] = [n for i, n in enumerate(FF_SKULLS) if bsk & (1 << i)]
    v['bonus_wave'] = read_ff_wave(p, 'bonus_wave')
    if mcc >= 2:
        v['mcc_extension_flags'] = p.bn(8, name='mcc_extension_flags')
    return v


# ---------------------------------------------------------------------------
# container
# ---------------------------------------------------------------------------

def walk_chunks(data):
    chunks = []
    off = 0
    while off + 12 <= len(data):
        sig = data[off:off + 4]
        size, = struct.unpack('>I', data[off + 4:off + 8])
        ver, = struct.unpack('>H', data[off + 8:off + 10])
        flags, = struct.unpack('>H', data[off + 10:off + 12])
        chunks.append({'offset': off, 'signature': sig.decode('latin-1'),
                       'size': size, 'version': ver, 'flags': flags})
        if size <= 0 or sig == b'_eof':
            break
        off += size
    return chunks


def decode(path):
    data = open(path, 'rb').read()
    out = Node()
    out['file'] = os.path.basename(path)
    out['file_size'] = len(data)
    out['chunks'] = walk_chunks(data)

    mpvr = next((c for c in out['chunks'] if c['signature'] == 'mpvr'), None)
    if mpvr is None:
        raise SystemExit('no mpvr chunk found in %s' % path)

    base = mpvr['offset'] + 12
    hdr = Node()
    hdr['chunk_offset'] = mpvr['offset']
    hdr['chunk_size'] = mpvr['size']
    hdr['chunk_version'] = mpvr['version']
    hdr['chunk_flags'] = mpvr['flags']
    hdr['sha1'] = data[base:base + MPVR_HASH_LEN].hex()
    hdr['unused4'] = data[base + 20:base + 24].hex()
    hdr['hashable_length'], = struct.unpack('>I', data[base + 24:base + 28])
    hashable_start = base + MPVR_PREAMBLE
    hdr['hashable_start'] = hashable_start
    out['mpvr_header'] = hdr

    # SHA-1 verification.
    #
    # PROVEN against both reference files: the stored digest is
    #     sha1( be32(hashable_length) || variant_data )
    # which is the same thing as sha1( file[hash_len_field .. end_of_variant_data] ),
    # i.e. the 4-byte big-endian length field immediately followed by the payload.
    # ReachVariantEditor's writer prefixes a 34-byte salt (formats/sha1.h
    # reachSHA1Salt) as well; that variant does NOT match these MCC files, so the
    # salted form is computed too and reported for comparison.
    size = hdr['hashable_length']
    body = data[hashable_start:hashable_start + size]
    unsalted = struct.pack('>I', size) + body
    hdr['sha1_recomputed'] = hashlib.sha1(unsalted).hexdigest()
    hdr['sha1_recomputed_salted'] = hashlib.sha1(REACH_SHA1_SALT + unsalted).hexdigest()
    hdr['sha1_ok'] = (hdr['sha1_recomputed'] == hdr['sha1'])
    hdr['sha1_scheme'] = ('sha1(be32(len)||data)' if hdr['sha1_ok'] else
                          'salted' if hdr['sha1_recomputed_salted'] == hdr['sha1']
                          else 'UNKNOWN')

    p = Parser(data, hashable_start * 8)
    engine = p.bn(4, name='variant_type')
    out['engine_type'] = engine
    out['engine_name'] = enum_name(GAME_ENGINE, engine)

    if engine == 4:
        out['variant'] = read_firefight(p)
    elif engine in (1, 2):
        out['variant'] = None
        out['note'] = ('engine is %s; the multiplayer/forge body (which DOES carry a '
                       'Megalo script) is not implemented by this tool' % out['engine_name'])
    else:
        out['variant'] = None
        out['note'] = 'unsupported engine type %d' % engine

    # where did we land?
    end_bit = p.br.pos
    out['parse'] = {
        'end_bit_abs': end_bit,
        'end_bit_rel': end_bit - hashable_start * 8,
        'end_bytespan_rel': (end_bit - hashable_start * 8 + 7) // 8,
        'declared_hashable_bytes': size,
        'closes_exactly': ((end_bit - hashable_start * 8 + 7) // 8) == size,
        'bit_slack': size * 8 - (end_bit - hashable_start * 8),
        'overflow_bits': p.br.overflow,
    }

    # anything after the variant data, up to end of chunk
    chunk_end = mpvr['offset'] + mpvr['size']
    tail = data[hashable_start + size:chunk_end]
    out['tail'] = {'offset': hashable_start + size, 'length': len(tail),
                   'nonzero_bytes': sum(1 for b in tail if b),
                   'first_nonzero': next((i for i, b in enumerate(tail) if b), None)}
    out['trace'] = p.trace
    return out


# ---------------------------------------------------------------------------
# megalo probe
# ---------------------------------------------------------------------------

def megalo_probe(res):
    """Report whether a Megalo script section can exist in this variant.

    The Megalo script tables live in GameVariantDataMultiplayer only (see
    multiplayer.cpp). GameVariantDataFirefight has no script members at all, so
    a firefight-engine variant structurally cannot contain one.
    """
    lines = []
    eng = res['engine_name']
    lines.append('engine type       : %d (%s)' % (res['engine_type'], eng))
    if eng == 'firefight':
        lines.append('megalo section    : STRUCTURALLY ABSENT')
        lines.append('  Reach\'s firefight variant body (ReachVariantEditor '
                     'types/firefight.cpp) consists of:')
        lines.append('    ugc_header, isBuiltIn, custom_game_options, scenarioFlags,')
        lines.append('    mccExtensionVersion, wave/life/bonus scalars, 8x player_traits,')
        lines.append('    3x custom_skull, elite respawn options, 3x round, bonus wave.')
        lines.append('  There is no string table, no trigger/condition/action table,')
        lines.append('  no variable declarations and no HUD widget declarations.')
    else:
        lines.append('megalo section    : possible (multiplayer/forge body)')
    pr = res['parse']
    lines.append('parse end         : bit %d (%d bytes of %d declared)'
                 % (pr['end_bit_rel'], pr['end_bytespan_rel'], pr['declared_hashable_bytes']))
    lines.append('closes exactly    : %s (slack %d bits)'
                 % (pr['closes_exactly'], pr['bit_slack']))
    t = res['tail']
    lines.append('post-data tail    : %d bytes, %d nonzero -> %s'
                 % (t['length'], t['nonzero_bytes'],
                    'ALL ZERO PADDING' if t['nonzero_bytes'] == 0 else 'CONTAINS DATA'))
    lines.append('sha-1 verified    : %s' % res['mpvr_header']['sha1_ok'])
    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# bit-order proof
# ---------------------------------------------------------------------------

def prove_bitorder(path):
    """Read the same fields MSB-first and LSB-first; only one yields text."""
    data = open(path, 'rb').read()
    chunks = walk_chunks(data)
    mpvr = next(c for c in chunks if c['signature'] == 'mpvr')
    start = (mpvr['offset'] + 12 + MPVR_PREAMBLE) * 8

    class LsbReader(BitReader):
        def read(self, n):
            v = 0
            for i in range(n):
                bytepos = self.pos // 8
                if bytepos >= len(self.data):
                    self.overflow += 1
                    self.pos += 1
                    continue
                bit = (self.data[bytepos] >> (self.pos % 8)) & 1
                v |= bit << i
                self.pos += 1
            return v

    out = []
    for label, cls in (('MSB-first (big-endian)', BitReader), ('LSB-first', LsbReader)):
        p = Parser(data, start)
        p.br = cls(data, start)
        try:
            eng = p.bn(4)
            h = read_ugc_header(p)
            title, desc = h['title'], h['description']
        except Exception as exc:                        # noqa: BLE001
            eng, title, desc = -1, '<exception %s>' % exc, ''
        printable = sum(1 for ch in (title + desc) if 32 <= ord(ch) < 127)
        out.append('%-24s engine=%-3s title=%-28r desc=%-40r printable=%d'
                   % (label, eng, title[:28], desc[:40], printable))
    return '\n'.join(out)


# ---------------------------------------------------------------------------
# pseudo-code dump
# ---------------------------------------------------------------------------

def fmt_traits(t, indent):
    pad = ' ' * indent
    interesting = {k: v for k, v in t.items()
                   if v not in ('unchanged', -1, 0, 'none')}
    if not interesting:
        return pad + '(all unchanged)\n'
    s = ''
    for k, v in interesting.items():
        s += '%s%-30s %s\n' % (pad, k, v)
    return s


def dump(res):
    L = []
    w = L.append
    w('=' * 78)
    w('mpvr decode: %s' % res['file'])
    w('=' * 78)
    w('')
    w('-- container --------------------------------------------------------------')
    for c in res['chunks']:
        w('  0x%06X  %-4s  size=%-7d version=%-3d flags=%d'
          % (c['offset'], c['signature'], c['size'], c['version'], c['flags']))
    h = res['mpvr_header']
    w('')
    w('-- mpvr chunk header ------------------------------------------------------')
    w('  chunk offset        0x%X' % h['chunk_offset'])
    w('  chunk size          %d bytes (incl. 12-byte chunk header)' % h['chunk_size'])
    w('  chunk version       %d   flags %d' % (h['chunk_version'], h['chunk_flags']))
    w('  sha-1 (stored)      %s' % h['sha1'])
    w('  sha-1 (recomputed)  %s  [%s]'
      % (h['sha1_recomputed'], 'MATCH' if h['sha1_ok'] else 'MISMATCH'))
    w('  sha-1 scheme        %s' % h['sha1_scheme'])
    w('  sha-1 (RVE salted)  %s  [unused by these files]'
      % h['sha1_recomputed_salted'])
    w('  unused 4 bytes      %s' % h['unused4'])
    w('  hashable length     %d bytes' % h['hashable_length'])
    w('  bit stream starts   0x%X (byte-aligned)' % h['hashable_start'])
    pr = res['parse']
    w('  parse consumed      %d bits = %d bytes  (declared %d) -> %s'
      % (pr['end_bit_rel'], pr['end_bytespan_rel'], pr['declared_hashable_bytes'],
         'EXACT' if pr['closes_exactly'] else 'MISMATCH'))
    t = res['tail']
    w('  trailing bytes      %d (%d nonzero) %s'
      % (t['length'], t['nonzero_bytes'],
         '= zero padding' if t['nonzero_bytes'] == 0 else '= DATA PRESENT'))
    w('')
    w('-- engine -----------------------------------------------------------------')
    w('  variant_type        %d (%s)' % (res['engine_type'], res['engine_name']))
    w('')
    w('-- megalo probe -----------------------------------------------------------')
    for line in megalo_probe(res).split('\n'):
        w('  ' + line)
    w('')

    v = res.get('variant')
    if not v:
        w(res.get('note', ''))
        return '\n'.join(L)

    hd = v['header']
    w('-- ugc header -------------------------------------------------------------')
    w('  content_type        %s' % hd['content_type'])
    w('  file_length         %d' % hd['file_length'])
    w('  activity            %d' % hd['activity'])
    w('  game_mode           %s' % hd['game_mode'])
    w('  engine              %d' % hd['engine'])
    w('  engine_category     %d' % hd['engine_category'])
    w('  map_id              %d' % hd['map_id'])
    w('  engine_icon         %s' % hd.get('engine_icon'))
    w('  title               %r' % hd['title'])
    w('  description         %r' % hd['description'])
    w('  created_by          author=%r xuid=0x%X ts=%d online=%s'
      % (hd['created_by']['author'], hd['created_by']['xuid'],
         hd['created_by']['timestamp'], hd['created_by']['is_online_id']))
    w('  modified_by         author=%r xuid=0x%X ts=%d online=%s'
      % (hd['modified_by']['author'], hd['modified_by']['xuid'],
         hd['modified_by']['timestamp'], hd['modified_by']['is_online_id']))
    w('  campaign.difficulty %s' % hd.get('campaign_difficulty'))
    w('  campaign.unk2A4     %s' % hd.get('campaign_unk2A4'))
    w('')

    w('-- firefight settings -----------------------------------------------------')
    w('  is_built_in             %s' % v['is_built_in'])
    w('  scenario_flags          %s' % v['scenario_flags'])
    w('  mcc_extension_version   %s' % v['mcc_extension_version'])
    w('  mcc_extension_flags     %s' % v.get('mcc_extension_flags'))
    w('  wave_limit              %s' % v['wave_limit'])
    w('  unkB                    %s' % v['unkB'])
    w('  bonus_target            %s' % v['bonus_target'])
    w('  elite_kill_bonus        %s' % v['elite_kill_bonus'])
    w('  starting_lives_spartan  %s' % v['starting_lives_spartan'])
    w('  starting_lives_elite    %s' % v['starting_lives_elite'])
    w('  unkD                    %s' % v['unkD'])
    w('  max_spartan_extra_lives %s' % v['max_spartan_extra_lives'])
    w('  generator_count         %s' % v['generator_count'])
    w('  bonus_wave_duration     %s sec' % v['bonus_wave_duration_sec'])
    w('  bonus_wave_skulls       %s' % (v['bonus_wave_skulls'] or 'none'))
    w('')

    o = v['options']
    w('-- custom game options ----------------------------------------------------')
    g = o['general']
    w('  general: flags=%s time_limit=%smin round_limit=%s rounds_to_win=%s '
      'sudden_death=%ss grace=%ss'
      % (g['flags'], g['time_limit_min'], g['round_limit'], g['rounds_to_win'],
         g['sudden_death_time'], g['grace_period']))
    r = o['respawn']
    w('  respawn: flags=%s lives/round=%s team_lives=%s time=%ss suicide=%ss '
      'betrayal=%ss growth=%s cam=%s traits_dur=%s'
      % (r['flags'], r['lives_per_round'], r['team_lives_per_round'],
         r['respawn_time'], r['suicide_penalty'], r['betrayal_penalty'],
         r['respawn_growth'], r['loadout_cam_time'], r['traits_duration']))
    w('  respawn traits:')
    w(fmt_traits(r['traits'], 6).rstrip('\n'))
    s = o['social']
    w('  social: observers=%s team_changes=%s flags=%s'
      % (s['observers'], s['team_changes'], s['flags']))
    m = o['map']
    w('  map: flags=%s weapon_set=%s vehicle_set=%s'
      % (m['flags'], m['weapon_set'], m['vehicle_set']))
    w('  map base traits:')
    w(fmt_traits(m['base_traits'], 6).rstrip('\n'))
    for colour in ('red', 'blue', 'yellow'):
        w('  powerup %s (%ss):' % (colour, m['powerup_%s_duration' % colour]))
        w(fmt_traits(m['powerup_%s_traits' % colour], 6).rstrip('\n'))
    tm = o['team']
    w('  teams: scoring=%s species=%s designator_switch=%s'
      % (tm['scoring'], tm['species'], tm['designator_switch_type']))
    for i, td in enumerate(tm['teams']):
        nm = td['name']['strings'][0].get(0, '') if td['name']['strings'] else ''
        w('    team[%d] flags=%-40s name=%-12r desig=%s species=%s fireteams=%s '
          'colors=%06X/%06X/%06X'
          % (i, td['flags'], nm, td['initial_designator'], td['spartan_or_elite'],
             td['fireteam_count'], td['color_primary'] & 0xFFFFFF,
             td['color_secondary'] & 0xFFFFFF, td['color_text'] & 0xFFFFFF))
    lo = o['loadouts']
    w('  loadouts: flags=%s' % lo['flags'])
    for pname, entries in lo['palettes'].items():
        shown = ['%s%s/%s/%s/g%s' % ('' if e['visible'] else '(hidden) ',
                                     e['weapon_primary'], e['weapon_secondary'],
                                     e['ability'], e['grenade_count'])
                 for e in entries]
        w('    %-16s %s' % (pname, '; '.join(shown)))
    w('')

    w('-- base traits ------------------------------------------------------------')
    w('  spartan:')
    w(fmt_traits(v['base_traits_spartan'], 6).rstrip('\n'))
    w('  elite:')
    w(fmt_traits(v['base_traits_elite'], 6).rstrip('\n'))
    w('  wave (AI):')
    w(fmt_traits(v['base_traits_wave'], 6).rstrip('\n'))
    w('')

    w('-- custom skulls ----------------------------------------------------------')
    for sname, cs in v['custom_skulls'].items():
        w('  skull %s:' % sname)
        w('    spartan traits:')
        w(fmt_traits(cs['traits_spartan'], 8).rstrip('\n'))
        w('    elite traits:')
        w(fmt_traits(cs['traits_elite'], 8).rstrip('\n'))
        w('    wave traits:')
        w(fmt_traits(cs['traits_wave'], 8).rstrip('\n'))
    w('')

    er = v['elite_respawn_options']
    w('-- elite respawn options --------------------------------------------------')
    w('  flags=%s lives/round=%s team_lives=%s time=%ss growth=%s traits_dur=%s'
      % (er['flags'], er['lives_per_round'], er['team_lives_per_round'],
         er['respawn_time'], er['respawn_growth'], er['traits_duration']))
    w('')

    w('-- rounds / waves (AI SQUAD SPAWN TABLE) ----------------------------------')
    for i, rd in enumerate(v['rounds']):
        w('  round[%d] skulls=%s' % (i, rd['skulls'] or 'none'))
        for wkey in ('wave_initial', 'wave_main', 'wave_boss'):
            wv = rd[wkey]
            w('    %-13s dropship=%-5s ordered=%-5s count=%d squads=%s'
              % (wkey, wv['uses_dropship'], wv['ordered_squads'],
                 wv['squad_count'], ', '.join(wv['squads_active']) or '-'))
            w('      (all 12 slots: %s)' % ', '.join(wv['squads']))
    bw = v['bonus_wave']
    w('  bonus_wave     dropship=%-5s ordered=%-5s count=%d squads=%s'
      % (bw['uses_dropship'], bw['ordered_squads'], bw['squad_count'],
         ', '.join(bw['squads_active']) or '-'))
    w('      (all 12 slots: %s)' % ', '.join(bw['squads']))
    w('')
    return '\n'.join(L)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('files', nargs='+')
    ap.add_argument('--dump', action='store_true', help='readable pseudo-code dump')
    ap.add_argument('--json', action='store_true', help='structured object tree as JSON')
    ap.add_argument('--trace', action='store_true', help='per-field bit trace')
    ap.add_argument('--prove-bitorder', action='store_true')
    ap.add_argument('--megalo-probe', action='store_true')
    args = ap.parse_args()

    for path in args.files:
        if args.prove_bitorder:
            print('### bit-order proof: %s' % os.path.basename(path))
            print(prove_bitorder(path))
            print()
            continue
        res = decode(path)
        if args.megalo_probe:
            print('### %s' % os.path.basename(path))
            print(megalo_probe(res))
            print()
        if args.trace:
            for bitpos, bitlen, name, value in res['trace']:
                print('%8d +%-3d %-62s %s' % (bitpos, bitlen, name, value))
        if args.json:
            res.pop('trace', None)
            print(json.dumps(res, indent=2, default=str))
        if args.dump or not (args.json or args.megalo_probe or args.trace):
            print(dump(res))


if __name__ == '__main__':
    main()
