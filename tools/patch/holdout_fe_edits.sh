#!/bin/bash
# =====================================================================================================
#  tools/patch/holdout_fe_edits.sh
#  The COMPLETE tag-data edit list for Firefight Evolved Expanded on ff70_holdout.
#  14 same-size writes, 30 bytes of payload (one u32 + thirteen i16). NO tag growth, NO new blocks,
#  NO new script objects. Verified pre-patch values: build/logs/holdout_fe_offsets.py.
#
#  WHY RAW OFFSETS AND NOT PATH SELECTORS.  patch_map.py's path selectors cannot reach the scnr
#  sub-blocks on this map: it estimates the scnr tag's extent as 0x483803C..0x48388A8 while the real
#  scenario body starts at 0x452E000, so every scenario block is "outside the tag's estimated extent"
#  and is skipped (reproduce with --find --everything). Raw @offset:kind writes with
#  --allow-unmapped are the form research/19 already proved on this exact cache.
#
#  EVERY OFFSET BELOW WAS READ OUT OF ~/Desktop/ff70_holdout.map, sha256
#  c0b8a30f0a1cdc6fa9242ec144c6ccc3e8d580d0a8a39732bcf76b1c6a95d8a2, with
#  build/logs/holdout_fe_offsets.py, which also re-checks the pre-patch value of each one and refuses
#  if any has moved. RUN THAT FIRST. Offsets are file offsets and are only valid for a cache with
#  that hash.
#
#  Struct provenance (research/_raw/reach-defs/scenario.json, walked by tools/map/defwalk.py):
#    squad_groups_block     0x28 bytes; parent (short_block_index) at +0x20
#    squads_block_struct    0x6C bytes; team +0x24, parent +0x26, initial objective +0x2A
#    cell_block_struct      0x6C bytes; character type block +0x14, initial weapon block +0x20
#    character_palette_choice_block / weapon_palette_choice_block  0x10 bytes; index at +0x0C
#    character_struct_definition  unit tag_reference at +0x14, datum at +0x14+0xC = +0x20
# =====================================================================================================
set -euo pipefail

IN="${1:?usage: holdout_fe_edits.sh <in.map> <out.map>}"
OUT="${2:?usage: holdout_fe_edits.sh <in.map> <out.map>}"
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"

python3 "$PROJ/tools/patch/patch_map.py" "$IN" --allow-unmapped --apply --out "$OUT" \
\
`#  1. THE CHARACTER. char 8107 objects\characters\null\ai\null_cov_default is the ONLY palette` \
`#     entry referenced by no cell in any of the 31 squads, so repointing it cannot change any` \
`#     existing enemy. Its unit tag_reference datum goes bipd null -> bipd spartans (tag 9708).` \
`#     This is the 4-byte edit research/19 section 3 already applied and already proved loads in` \
`#     Blamite. It is what makes the allies Spartan-bodied; there is no marine or ODST char tag in` \
`#     any of the eight stock Firefight caches.` \
  --set '@0x73AA6A8:u32=0x8DC525EC' \
\
`#  2. THE ALLY GROUP. gr_survival_fireteams (squad group 9) parent 1 (gr_survival_waves) -> -1.` \
`#     gr_survival_waves is a child of gr_survival_all, and stock survival_wave_living_count reads` \
`#     (ai_living_count "gr_survival_all"). Left as shipped, every purchased ally would be counted` \
`#     as a live enemy, the wave would never report clear and the round would never end. Making the` \
`#     group a ROOT group is what lets survival_wave_living_count stay COMPLETELY STOCK, which is` \
`#     exactly how the author does it with his own root gr_survival_marines.` \
  --set '@0x454D6D4:i16=-1' \
\
`#  3-6. THE ALLY SQUADS. sq_sur_drop_01..04 parent 5 (gr_survival_extras) -> 9` \
`#       (gr_survival_fireteams). These four are the only squads in Holdout with a populated cell` \
`#       AND spawn points, so they are the only ones ai_place can actually stand up. Moving them` \
`#       into the ally group makes (ai_living_count "gr_survival_fireteams") the exact ally count` \
`#       for the cap of 8, and simultaneously takes them out of obj_survival/extras_gate, whose` \
`#       squad group filter is 5 - so they stop being eligible for the enemy objective.` \
  --set '@0x454F7B6:i16=9' \
  --set '@0x454F822:i16=9' \
  --set '@0x454F88E:i16=9' \
  --set '@0x454F8FA:i16=9' \
\
`#  7-10. THE ALLY ROLE. sq_sur_drop_01..04 initial objective 0 (obj_survival) -> 1 (obj_fireteams).` \
`#        obj_fireteams has exactly one task, 'fireteams', and Bungie already set its squad group` \
`#        filter to 9 and its follow mode to 'player' with follow radius 3.0 and no capacity cap.` \
`#        It is a ready-made "allies follow the player" task that this map ships unused.` \
  --set '@0x454F7BA:i16=1' \
  --set '@0x454F826:i16=1' \
  --set '@0x454F892:i16=1' \
  --set '@0x454F8FE:i16=1' \
\
`#  11-12. THE ALLY BODY. The four drop squads share only TWO distinct cells:` \
`#         cell A @0x454EBA0 is used by sq_sur_drop_01 and _04, cell B @0x454EC2C by _02 and _03.` \
`#         Each cell's character type block has one entry; its palette index moves to 25, the` \
`#         repointed null_cov_default. Two 2-byte writes cover all four squads.` \
  --set '@0x454EB8C:i16=25' \
  --set '@0x454EC18:i16=25' \
\
`#  13-14. THE ALLY WEAPON. This definition set has NO starting-profiles block, so the cell's` \
`#         'initial weapon' block out of the 23-entry weapon palette is the only way to arm an ally.` \
`#         cell A: 17 (concussion_rifle) -> 13 (dmr). cell B: 10 (flak_cannon) -> 0 (assault_rifle).` \
`#         Without these two writes the Spartan-bodied allies carry Brute weapons.` \
  --set '@0x454EB9C:i16=13' \
  --set '@0x454EC28:i16=0'

echo
echo "wrote $OUT"
echo "NEXT, AND NON-NEGOTIABLE: load the result in Blamite before calling it verified."
echo "  our parser passing is NOT sufficient evidence - research/19 section 4."
