; =====================================================================================================
;  FIREFIGHT EVOLVED EXPANDED - fe_reinforcements.hsc
;  Reusable purchase-on-score core library for Halo: Reach Firefight (MCC / Halo Reach Editing Kit).
;
;  WHAT THIS IS
;    A map-side HaloScript library that lets players spend their live Firefight score on friendly
;    AI squads (Marines, ODSTs) and hardware. It is compiled into a modified .map by HR-EK.
;    It CANNOT live in a .bin game variant: Firefight variants contain no Megalo at all
;    (research/02-mpvr-megalo-format.md, research/06-ai-squad-spawning.md section 0).
;
;  HOW TO READ THE TAGS IN THE COMMENTS
;    [V]   = verified. The function or the whole pattern appears in a shipped Bungie Firefight script
;            on disk under research/_raw/hsc/, or in the official Reach HaloScript function dump
;            (research/_raw/hsc/hsdoc_hr.txt). Citations are given as file:line.
;    [G]   = GUESS. The function exists and is spelled correctly, but this specific *use* of it is not
;            backed by any shipped script. Expect to fix these first.
;    [NEW] = this identifier does NOT exist in any shipped script or stock tag. It is content you must
;            author in Sapien before the script will compile. Not a guess - a to-do.
;
;  THE NAMING RULE THIS LIBRARY OBEYS  (research/11-stock-map-spawn-geography.md section 3.1)
;    sq_ squad | gr_ squad group | ps_ point set | tv_ trigger volume | kill_ kill volume |
;    dm_ device machine | sc_ scenery | cr_ crate | obj_ AI objective | cs_ command script.
;    Survival-tree objects carry the _sur_ infix and zero-padded two-digit numbers:
;    sq_sur_wraith_01, sq_sur_ghost_02, sq_sur_sniper_04, sq_sur_banshee_01, sq_sur_drop_05.
;    Unprefixed, single-digit, 0-based exceptions that are real and must be spelled exactly:
;    generator0-generator2, generator_switch0-2, ammo_crate0/ammo_crate1, health_pack0-5,
;    spartan_01-06 (respawn zones).
;    OUR OWN new objects deliberately use fe_ and NEVER _sur_, because _sur_ marks membership of the
;    survival squad-group tree, which is the one thing a friendly squad must stay out of (see below).
;
;  LOAD ORDER
;    This file must be compiled BEFORE the per-scenario file that calls it (ff50_park.hsc etc.).
;    See README.md step 6.
;
;  =====================================================================================================
;  THE ONE RULE YOU MUST NOT BREAK  (global_firefight.hsc L665-674) [V]
;  =====================================================================================================
;    Firefight computes wave end as:
;        (script static short survival_wave_living_count
;          (+ (ai_living_count gr_survival_all)
;             (ai_living_count gr_survival_remaining)
;             ... dropship crews ...))
;    Therefore every friendly squad authored for this system MUST have its parent squad group set to
;    gr_unsc_reinforcements [NEW], and that group must be a child of NOTHING.
;
;  =====================================================================================================
;  *** THE TRAP. READ THIS BEFORE YOU PARENT ANYTHING IN SAPIEN. ***
;  =====================================================================================================
;    Bungie's own Firefight authoring checklist parents friendly marines as
;        gr_survival_marines -> gr_survival_extras
;    DO NOT COPY THAT. gr_survival_extras is not in survival_wave_living_count, so it will not stall
;    waves - but on Overlook, Waterfront and Courtyard the Covenant drop-pod spawner waits on that
;    group reaching ZERO, twice per burst:
;        ff10_prototype.hsc L507  (<= (ai_living_count gr_survival_extras) 0)   ; pre-gate
;        ff10_prototype.hsc L529  (sleep_until (<= (ai_living_count gr_survival_extras) 0))
;        ff30_waterfront.hsc L534 / L556   same two lines
;        ff20_courtyard.hsc L481 / L501    same two lines
;    A living friendly marine parented under gr_survival_extras therefore SUPPRESSES COVENANT DROP
;    PODS FOR THE REST OF THE MATCH on those maps - silently, with no error.
;    gr_survival_extras is also culled: survival_wave_end_conditions calls
;        (ai_survival_cleanup gr_survival_extras TRUE TRUE)
;    which per hsdoc_hr.txt L5153 enables "cure isolation death" and deletes inactive actors, so
;    friendlies in it get garbage-collected the moment they are separated from the fight.
;    => Parent friendly squads OUTSIDE the survival tree entirely. gr_unsc_reinforcements, child of
;       nothing. This warning is repeated at every parenting site in every per-map file.
;
;  SCENARIO PREREQUISITES (authored in Foundation/Sapien - NOT scriptable; see README.md section 2)
;    squad group : gr_unsc_reinforcements   [NEW]  child of NOTHING
;    squad group : gr_unsc_followers        [NEW]  child of gr_unsc_reinforcements
;    squads      : sq_fe_garrison   [NEW]  team = human, 6 CELLS - the free round-start squad
;                  sq_fe_marines    [NEW]  team = human, 8 CELLS - the bought Marine squad
;                  sq_fe_odst       [NEW]  team = human, 8 CELLS - the bought ODST squad
;                  sq_fe_gunner, sq_fe_sniper_01   [NEW]  team = human
;                  Cell counts are a scenario tag field. See section 2b and README.md section 2b/2c.
;    objective   : obj_marines              [NEW on these six maps] - see section 9 and README.md
;    trigger volumes for the purchase terminals (one per catalogue entry, per map)  [NEW]
;    trigger volumes : tv_fe_bank_in, tv_fe_bank_out  [NEW] the two bank kiosks - see section 6a
;    trigger volume  : the WIN terminal volume, sited at the map's exposed named anchor, NOT at
;                      ammo_crate0 - see section 11a and each scenario file's header
; =====================================================================================================


; =====================================================================================================
;  1. ECONOMY - TUNABLE CONSTANTS
;
;  WHERE THESE NUMBERS COME FROM, AND WHAT CHANGED
;  The previous version of this block priced everything off an assumed 4,000-5,000 points per round on
;  Normal and a 30,000-point win purchase. Both are withdrawn. The income figure was an estimate
;  derived from the Score Attack achievement; it has been superseded by a MEASUREMENT.
;  research/10-author-design-system.md section 1.3 OCR'd the score counter out of a complete 21-minute
;  Unearthed playthrough of the mod we are emulating and got ~900 points per MINUTE, i.e.
;
;      one round  ~ 2,000-2,500 points        one set (3 rounds + bonus) ~ 7,000-8,500 points
;
;  That is roughly half of what this pack used to assume, so every old price was 3-6x too expensive.
;  The author's own price history says the same thing from the other direction: within 24 HOURS of
;  release he cut nine prices by 50-75% (ODSTs 2,000->750, Sentinel Hack 3,000->1,000, Falcon
;  4,000->3,000, Scorpion 5,000->2,500, Gauss 3,000->2,000, Warthog 1,500->1,000, Marines 1,000->500,
;  Base Power 750->350, Overshield/Camo 750->500) because players never reached the interesting
;  purchases. An overpriced economy is the failure mode he actually hit. START CHEAP.
;
;  HIS TIER RATIOS, which are the part worth copying (research/10 section 1.3):
;      impulse / repeatable  = under 1/3 of a round's income     250 - 750
;      standard              = about 1/2 a round                 1,000
;      set purchase          = about one round                   2,000 - 2,500
;      heavy                 = about 1.5 rounds                   3,000 - 3,500
;      win purchase          = about 4 rounds                     8,000 - 10,000
;      punitive              = a whole set, deliberately painful  6,000  (he used it once, the AA Shade)
;
;  EVIDENCE TAG ON EVERY PRICE BELOW
;      [AUTHOR]  = a price the author actually shipped, after his own playtest corrections.
;      [DERIVED] = he never priced this item. The number is placed on the matching rung of HIS ladder
;                  by us. It is our inference, not his evidence. Do not quote it as his.
;
;  They are globals, not literals, so you can retune the whole pack from this block, and so you can
;  change them live from the Sapien / Standalone console with (set k_fe_cost_marines 400).
; =====================================================================================================
(global long k_fe_cost_marines           500)   ; [AUTHOR] Unearthed "trooper reinforcements" 1,000->500.
                                                ;  ALWAYS the cheapest entry on every board. 1/5 of a
                                                ;  round's income, so it is affordable every round and
                                                ;  usually twice. This is the point of the whole pack.
(global long k_fe_cost_odst              750)   ; [AUTHOR] Installation 04 "call in ODSTs" 2,000->750.
                                                ;  Always the second cheapest entry.
(global long k_fe_cost_turret            750)   ; [AUTHOR] "buy Machinegun Turret (750 points)", both
                                                ;  his outdoor maps, never gated. A fortification you
                                                ;  buy on reflex at the position you are defending.
(global long k_fe_cost_map_state        1000)   ; [AUTHOR] rung: Medium Weapon Rack 1,000. Barricade /
                                                ;  seal ramps / unlock a piece of map state.
(global long k_fe_cost_turret_upgrade   1000)   ; [DERIVED] standard rung. His only priced upgrades are
                                                ;  vehicle-tier swaps (Gauss 2,000, Fuel Rod Shade
                                                ;  2,000); a turret variant swap is cheaper than those.
(global long k_fe_cost_light_vehicle    1000)   ; [AUTHOR] Rocket Warthog 1,500->1,000, Round 2 gate.
                                                ;  We sell a Ghost at the same price and the same gate.
(global long k_fe_cost_squad_special    1000)   ; [DERIVED] ally rung, one step above a plain squad:
                                                ;  the Waterfront counter-sniper pair.
(global long k_fe_cost_set_item         2000)   ; [AUTHOR] rung: Gauss upgrade 2,000 / Fuel Rod Shade
                                                ;  2,000. One round's income, one per set. Holdout's AA
                                                ;  battery and Outpost's cannon repair sit here.
(global long k_fe_cost_superweapon      3000)   ; [DERIVED] heavy rung = his Falcon gunner run 3,000 and
                                                ;  Scorpion 3,500. One-shot strike / barrage. He never
                                                ;  priced an orbital strike; this is OUR placement.
(global long k_fe_cost_win               8000)  ; [DERIVED] 4 rounds of measured income. He never
                                                ;  published a price for a win purchase on any map
                                                ;  (Evac Pelican, MAC Cannon and the Corvette bridge
                                                ;  doors are all UNKNOWN, research/10 section 1.1), but
                                                ;  he GATED Unearthed's MAC Cannon to land near 8,000
                                                ;  accumulated, which is what we price it at.
(global long k_fe_cost_win_discount     6000)   ; [DERIVED] the fortify-first branch (Overlook's bridge
                                                ;  barricade, Waterfront's sealed ramps). 25% off.
(global long k_fe_bank_step              500)   ; [AUTHOR] his kiosks moved 200->500 per press, because
                                                ;  200 needed too many presses and was spammable.

; =====================================================================================================
;  1a. ROUND GATES
;  "Round gates, not price, are his real pacing tool" (research/10 section 1.2). On Unearthed the
;  Warthog and Gauss upgrade are locked to Round 2 and the Scorpion and Auto Turret to Round 3, each
;  announced by a HUD banner on the round boundary: "The Warthog and Gauss upgrade are now available!"
;  Prices alone let a lucky early round break the curve; the gate makes the curve unbreakable.
;  Numbers are ABSOLUTE round indices, 1-based and continuous across sets - see fe_round_index.
; =====================================================================================================
(global short k_fe_gate_upgrade          2)     ; [AUTHOR pattern] turret variant upgrade. His Gauss
                                                ;  upgrade is a Round 2 unlock.
(global short k_fe_gate_vehicle          2)     ; [AUTHOR] "Warthog not available until Round 2".
(global short k_fe_gate_heavy            3)     ; [AUTHOR] "Scorpion not available until Round 3" and
                                                ;  "Auto Turret not available until Round 3". Our heavy
                                                ;  rung (strike / barrage) and set rung (AA battery,
                                                ;  cannon repair) ride this gate.
(global short k_fe_win_round_gate        5)     ; [DERIVED, from his gate not his price] the win costs
                                                ;  ~4 rounds of income, so it must not be purchasable
                                                ;  before round 5. He gated the MAC Cannon to Set 2 /
                                                ;  Round 3 / Wave 5, then loosened it to the start of
                                                ;  Set 2 - absolute round 4-9. Round 5 sits inside that.

; Wave index backstop for the loss condition. 16 waves = one set, then a second set.
; s_survival_wave_complete_count is Bungie's own counter (global_firefight.hsc L124). [V]
(global short k_fe_wave_backstop       16)

; =====================================================================================================
;  2. FRIENDLY AI BUDGET - AND THE SPEC THIS PACK NOW IMPLEMENTS
;
;  THE SPEC, verbatim from the author of this pack's requirements:
;      "a squad of 6 ODSTs/marines on the initial + every round, and 8 purchasable marines/ODSTs
;       every wave."
;  Implemented as: a FREE 6-man garrison squad at match start and topped back up to 6 at the start of
;  every round, plus an 8-man Marine or ODST squad that is purchasable in EVERY wave - subject to one
;  hard concurrent-alive cap. The cap is the whole safety mechanism. Read the next three blocks before
;  changing any number here.
;
;  --- 2.1 IS THERE A PUBLISHED ENGINE ACTOR LIMIT? NO. -----------------------------------------------
;  Searched and found nothing, so no number below is quoted as an engine constant:
;    * hsdoc_hr.txt (the complete official Reach HaloScript function dump, 292 KB) exposes NO actor
;      pool size. The only two actor-count functions in it are
;          (ai_lod_full_detail_actors <short>)      hsdoc_hr.txt L1229
;          ; "change the number of full detail AI characters we are allowed"
;      which is a level-of-detail knob and not a spawn cap, and
;          (ai_player_set_fireteam_max <unit> <short>)   hsdoc_hr.txt L1853
;      which caps one player's escort, not the map. There is no ai_actor_limit, no global, and no
;      scenario or matg field reachable from script.
;    * research/06 section 4 reached the same conclusion from the other direction after searching the
;      ChimpsAtSea Reach RE project, TagTool, Blam-Network and c20: "Hard engine actor-pool constant:
;      not publicly documented for Reach. UNPROVEN. ... Do not quote a number." The only MAXIMUM_ACTORS
;      constants on GitHub belong to Halo 1 decompilations and do not transfer to Reach.
;  So this pack does not claim an engine limit. It derives a working ceiling from what stock Firefight
;  itself demonstrably runs on these exact six maps.
;
;  --- 2.2 DERIVED CEILING, from stock Firefight's own peak population --------------------------------
;  Every figure here is read out of a shipped Bungie script. The arithmetic is ours, so the total is
;  labelled DERIVED, not measured.
;      6 squads per wave, always                 (global short k_sur_squad_per_wave_limit 6)
;                                                global_firefight.hsc L63, and every one of the six
;                                                per-map scripts sets (set s_sur_wave_squad_count 6).
;                                                Placed in one call:
;                                                (ai_place_wave (survival_mode_get_wave_squad)
;                                                   ai_sur_wave_spawns s_sur_wave_squad_count)
;                                                global_firefight.hsc L590-591.                  [V]
;      up to 4 members per squad                 squad size is baked into the map's wave templates;
;                                                Grunt squads are 4 cells, Hunter/Chieftain squads 1
;                                                (research/06 section 4).                   [DERIVED]
;      <= 6 enemies carried over from the        (sleep_until (< (survival_wave_living_count) 7))
;        previous wave                           global_firefight.hsc L678 - the next wave cannot
;                                                start until living drops below 7.                [V]
;      2 crew per dropship, 2 dropships max      (global short s_sur_dropship_crew_count 2) L94 and
;                                                (global short k_phantom_spawn_limit 2) L120.     [V]
;      1-2 hazard drop pods by player count      ff20_courtyard.hsc L466-472.                     [V]
;      AND the bonus round deliberately SUSTAINS (global short k_sur_bonus_limit 20)
;        20 living enemies, re-adding a squad     global_firefight.hsc L788, consumed at L852:
;        every time the count dips to 20          (<= (survival_mode_bonus_living_count) 20)
;                                                 -> (f_survival_bonus_spawner false) L865.       [V]
;
;  DERIVED PEAK of stock enemy population on a stock Firefight map:
;      6 carried over + (6 squads x up to 4 cells) + 4 dropship crew  =  about 34 concurrent actors,
;      and the bonus round holds a steady 20+ by design.
;  DERIVED WORKING CEILING used by this pack: about 34 concurrent AI actors of ALL kinds, friendly and
;  hostile together, is the most the engine is ever asked for by shipped content on these maps. That is
;  a ceiling for the WHOLE map, not a friendly allowance. Label it derived whenever you quote it.
;
;  --- 2.3 IS THE SPEC'S 8-PER-WAVE SURVIVABLE AS LITERALLY WRITTEN? NO. ------------------------------
;  A Reach Firefight ROUND is 5 waves - 1 initial, 3 main, 1 boss:
;      (global short k_sur_wave_per_round_limit 5)   global_firefight.hsc L75   [V]
;      (global short k_sur_round_per_set_limit 3)    global_firefight.hsc L76   [V]
;  So "8 purchasable every wave" granted literally, as a fresh 8 bodies per wave with no cap, is
;  8 x 5 = 40 bought friendlies per round, plus the free 6 = 46 friendly actors alive at the boss wave
;  if the player keeps buying and the squads survive. 46 friendlies ALONE exceeds the entire derived
;  ceiling for the map in 2.2 before a single Covenant squad is placed.
;  The failure mode is not a crash and not an error message. Per research/06 section 4 the engine
;  "does not error; extra actors simply fail to spawn or are culled". The Covenant wave spawner would
;  therefore place fewer and fewer enemies, and because wave end is
;      (sleep_until (< (survival_wave_living_count) 7))       global_firefight.hsc L678
;  a wave whose squads never arrived can also never be cleared on schedule - the match reads as
;  stalled, silently, mid-round, with no diagnostic.
;  => The per-wave GRANT is refused. The per-wave AVAILABILITY is kept. See 2.4.
;
;  --- 2.4 WHAT IS IMPLEMENTED INSTEAD: A CONCURRENT-ALIVE CAP ---------------------------------------
;  The 8-man squad is purchasable in every wave of every round, exactly as asked. What is capped is how
;  many friendly bodies may be ALIVE at one time. Deaths free slots immediately, because the slot count
;  is computed live from (ai_living_count ai_fe_group) and never from a purchase counter, so it cannot
;  drift. The intended loop is continuous re-buying under pressure rather than one big stack.
;
;  WHY 12 IS THE DEFAULT CAP. Two independent arguments land on the same number. First, the only
;  numeric friendly-AI allowance Bungie ever wrote for Firefight is two escorts per player:
;      (ai_player_set_fireteam_max (player_elite 0) 2)    global_firefight.hsc L2719, repeated for
;                                                         slots 1-5 at L2725/2731/2737/2743/2749  [V]
;  Six player slots x 2 = 12. (That block is commented out - ";tysongr - 53954: Adios, fireteams" at
;  L2715 - so it is evidence of Bungie's design budget, not of shipped behaviour.) Second, 12 is about
;  the headroom 2.2 leaves: a mid-wave map typically carries 7-24 live enemies, so a standing 12
;  friendlies lands the all-in total in the high 20s to high 30s, at or just over the derived stock
;  peak, and not at double it. Twelve is therefore the largest friendly population that is still the
;  same order of magnitude as something Bungie shipped. It is a judgement, not a measurement: verify
;  in-game, and if Covenant squads start arriving short, lower this first and nothing else.
;
;  CONSEQUENCE THE USER MUST KNOW. 6 free + 8 bought = 14, which is above the cap of 12. A purchase
;  made while the garrison is at full strength therefore delivers 6 of the 8, not 8. The full 8 lands
;  as soon as the garrison has taken two casualties, which on contact takes seconds. Raising this to 14
;  makes both squads fit exactly as specified and is a one-line change, but 14 is past both arguments
;  above, so it ships at 12.
; =====================================================================================================
(global short k_fe_actor_limit         12)      ; CONCURRENT CAP: friendly actors alive at once, across
                                                ;  the free garrison and every bought squad together.
                                                ;  DERIVED, not an engine constant - see 2.1 and 2.4.
                                                ;  Lowered per map in several startup scripts.
(global short k_fe_free_squad_size      6)      ; the free garrison the spec asks for: 6 at match start,
                                                ;  topped back up to 6 at the start of every round.
(global short k_fe_buy_squad_size       8)      ; the purchased squad the spec asks for: 8, available in
                                                ;  every wave, trimmed to the free slots that are left.
(global short k_fe_buy_min_fill         2)      ; refuse a purchase that would deliver fewer than this
                                                ;  many bodies, so nobody pays 500 for one marine.
(global short k_fe_buy_cooldown       450)      ; anti-spam cooldown in ticks. 30 ticks = 1 second.
(global short k_fe_squad_lifetime    9000)      ; 300 s. Timed expiry so the actor budget recovers.
                                                ;  Applies to BOUGHT squads only. The free garrison
                                                ;  never expires; it is re-topped each round instead.

; =====================================================================================================
;  2b. SQUAD SIZE IS A SCENARIO TAG FIELD, NOT A SCRIPT VALUE
;  k_fe_free_squad_size and k_fe_buy_squad_size above are only the number of members this script ASKS
;  for. The number it is ALLOWED to ask for is the cell capacity authored into the scenario tag, and no
;  HaloScript function can change it at placement time. The engine's own name for the field is visible
;  in the Mantini authoring API:
;      (<boolean> mantini_set_squad_cell_spawn_count <string> <long> <long>)   hsdoc_hr.txt L1727
;      ; "Set cell spawn count. Arg: <squad name> <cell index> <spawn count>"
;  so the field you are looking for in Foundation/Sapien is the squad's cells block and the per-cell
;  SPAWN COUNT. The exact values to enter are in README.md section 2b/2c:
;      sq_fe_garrison   6 cells, spawn count 1 each   -> capacity 6
;      sq_fe_marines    8 cells, spawn count 1 each   -> capacity 8
;      sq_fe_odst       8 cells, spawn count 1 each   -> capacity 8
;  One cell per body, spawn count 1, is preferred over one cell with spawn count 6 or 8, because only
;  the per-cell form lets you give each body its own weapon and its own starting location.
;  [G] on mantini_* as a RUNTIME call: Mantini is Sapien's in-editor AI authoring tool and no shipped
;  script calls any mantini_ function. It is cited here for the FIELD NAME only. Do not try to resize a
;  squad from script in a retail build.
; =====================================================================================================

; =====================================================================================================
;  2a. THE VEHICLE RULE  (this replaces the discredited "Wraith terrain verified" argument)
;
;  The old justification was wrong and is deleted. Beachhead's and Glacier's Wraiths are
;      (script command_script cs_wraith_shoot ... (cs_shoot_point ...))   ff50_park_main.hsc L747-776
;  driven onto four FIXED firing points ps_wraith/p0-p3 by cs_shoot_point. That is a STATIONARY
;  bombardment script. It proves the Wraith sits still and shells. It proves NOTHING about drivable
;  ground, and a Wraith hovers anyway. Overlook's Wraiths are worse evidence still: ff10_prototype.hsc
;  names sq_sur_wraith_01/_02 but has NO ps_wraith point set at all, so they have no authored
;  movement whatsoever.
;
;  THE REPLACEMENT RULE, applied to every file in this pack:
;      Sell only a vehicle chassis that the map's OWN stock hazard set already spawns and moves there.
;  That means a Ghost, and only on the three maps whose script names a Ghost squad:
;      Beachhead  ff50_park_main.hsc : sq_sur_ghost_01, sq_sur_ghost_02   [V]
;      Outpost    ff60_airview.hsc   : sq_sur_ghost_01, sq_sur_ghost_02   [V]
;      Glacier    ff60_icecave.hsc   : sq_sur_ghost_01                    [V]
;  Consequently the following purchases are REMOVED from this pack as unjustifiable:
;      Rocket Warthog and Gauss upgrade (Beachhead, Overlook, Glacier) - no wheeled vehicle is
;          spawned or moved by any of the six stock scripts.
;      Scorpion (Overlook, Glacier)  - same, plus tracked clearance is unevidenced anywhere.
;      Mongoose / light vehicle (Waterfront) - ff30_waterfront.hsc names no vehicle squad except
;          Banshees, which have no ps_banshee_* path on that map either.
;      Falcon gunner ride (Beachhead, Holdout) - no map of the six references ANY UNSC aircraft.
;          The only UNSC flight path in shipped Reach Firefight is ps_sur_pelican on cex_ff_halo.
;  k_fe_cost_vehicle_upgrade, k_fe_cost_heavy_vehicle and k_fe_cost_air_ride are gone with them.
;  [G] Even a Ghost is only proven at the Covenant squad's own tag spawn point. A Ghost you place at a
;  NEW position may still be wedged. Place it beside ammo_crate0 and drive it before you price it.
; =====================================================================================================

; =====================================================================================================
;  3. SQUAD AND GROUP BINDINGS
;  Declared 'none' here and (set ...) in each per-map startup script. This is exactly how stock
;  Firefight parameterises itself: global_firefight.hsc L8-37 declares ai globals as 'none' and every
;  per-map startup sets them to that map's scenario squad names (ff50_park_main.hsc L147-150,
;  ff10_prototype.hsc L78-81, ff60_airview.hsc L61-64, ...). [V]
; =====================================================================================================
(global ai ai_fe_group       none)      ; gr_unsc_reinforcements - the group holding all friendlies
(global ai ai_fe_followers   none)      ; gr_unsc_followers      - the child group the follow task filters on
(global ai ai_fe_garrison    none)      ; sq_fe_garrison 6 cell FREE squad, round start, defends
(global ai ai_fe_marines     none)      ; sq_fe_marines  8 cell bought Marine squad, walks on
(global ai ai_fe_odst        none)      ; sq_fe_odst     8 cell bought ODST squad, one heavy weapon
(global ai ai_fe_gunner      none)      ; sq_fe_gunner   1 man squad for the auto turret seat (optional)

; =====================================================================================================
;  4. RUNTIME STATE
; =====================================================================================================
(global boolean g_fe_debug        FALSE) ; (set g_fe_debug TRUE) in the console for (print) tracing
(global boolean g_fe_buy_locked   FALSE) ; TRUE while the anti-spam cooldown runs
(global boolean g_fe_board_open   FALSE) ; per-map startup opens the board after the mission trigger
(global short   g_fe_marine_buys  0)     ; purchase counters, for statistics / escalating prices
(global short   g_fe_odst_buys    0)
(global short   g_fe_place_n      0)     ; scratch: how many bodies the next ai_place may place.
                                         ; HaloScript has no local variables, so the partial-placement
                                         ; arithmetic in section 8a needs a global to work in. Never
                                         ; read it for anything else; it is overwritten by every place.
(global short   g_fe_last_round   0)     ; last absolute round whose free garrison has been delivered.
                                         ; 0 means "none yet", so the match-start drop fires on the
                                         ; first poll, which is the spec's "on the initial".
(global short   g_fe_garrison_drops 0)   ; how many times the free garrison has been topped up
(global boolean g_fe_slots_full   FALSE) ; edge state for the two HUD banners in section 11b
(global long    g_fe_bank         0)     ; banked points - see section 6a. NEVER reset at a set
                                         ; boundary: the whole purpose is to survive one.
(global boolean g_fe_bank_locked  FALSE) ; TRUE while the short bank cooldown runs

; =====================================================================================================
;  5. READING THE SCORE
;  Bungie's own score reader, global_firefight.hsc L1077-1086: [V]
;      (script static long survival_total_score
;        (+ (campaign_metagame_get_player_score (player_human 0)) ... (player_human 5)))
;  One deliberate change: stock passes (player_human N), which is indexed over LIVING players
;  (global_firefight.hsc L2876-2885 - players_human_living_count), so the stock sum drops a player's
;  score while that player is dead. Stock only uses it for monotonic achievement thresholds, where
;  that does not matter; an economy would wobble. (human_player_in_game_get N) is indexed by game slot
;  instead (global_firefight.hsc L2939-2946) and returns the <player> type that
;  campaign_metagame_get_player_score actually asks for (hsdoc_hr.txt L186, L5249).
;  [V on both functions, G on the combination]
;  MCC Firefight supports 8 players but stock sums slots 0-5 only; a 6-slot sum is kept here to match.
; =====================================================================================================
(script static long fe_score_gross
    (+
        (campaign_metagame_get_player_score (human_player_in_game_get 0))
        (campaign_metagame_get_player_score (human_player_in_game_get 1))
        (campaign_metagame_get_player_score (human_player_in_game_get 2))
        (campaign_metagame_get_player_score (human_player_in_game_get 3))
        (campaign_metagame_get_player_score (human_player_in_game_get 4))
        (campaign_metagame_get_player_score (human_player_in_game_get 5))
    )
)

; The spendable pot IS the live score. There is no separate ledger any more - see section 6.
(script static long fe_score_available
    (fe_score_gross)
)

; =====================================================================================================
;  6. CHARGING - THE REAL MECHANISM, NOT A WORKAROUND
;
;  The soft ledger (g_fe_spent) that used to live here is DELETED. It was built on the claim that Reach
;  has no way to subtract score. That claim was wrong:
;
;      (<void> campaign_metagame_award_points <player> <long>)        hsdoc_hr.txt L1772   [V]
;
;  The second argument is a SIGNED long, and Bungie calls it with positive values in shipped code:
;
;      (campaign_metagame_award_points (player0) 500)                 global_firefight.hsc L3382 [V]
;      ... 1000 / 5000 / 10000 / 20000 / 30000                        global_firefight.hsc L3385-3397
;
;  So passing a negative long charges the player, and the drop shows on the HUD, which is the feedback
;  an economy needs. (player0) is the accessor Bungie itself pairs with this function; it is not in
;  hsdoc_hr.txt but it is called in a shipped script, so it is verified by use. The documented
;  alternative is (human_player_in_game_get 0), hsdoc_hr.txt L186 - swap it in if (player0) will not
;  compile in your build.
;
;  Charged to game slot 0 only. Charging every slot would deduct cost x player count. The consequence
;  is that one player's displayed score carries the whole bill and can go negative; that is the honest
;  cost of using the real opcode instead of a hidden ledger. [G] on negative-value behaviour only:
;  no shipped script passes a negative, so verify the sign in Standalone before you ship.
; =====================================================================================================
(script static void (fe_charge (long cost))
    (campaign_metagame_award_points (player0) (- 0 cost))
    (if g_fe_debug (print "fe: charged"))
)

; The same opcode with a positive argument, which is the direction Bungie itself calls it in
; (global_firefight.hsc L3382-3397: 500 / 1000 / 5000 / 10000 / 20000 / 30000). [V]
(script static void (fe_credit (long amount))
    (campaign_metagame_award_points (player0) amount)
    (if g_fe_debug (print "fe: credited"))
)

; =====================================================================================================
;  6a. THE BANK  -  DEPOSIT / WITHDRAW KIOSKS, 500 PER PRESS
;
;  WHY THIS EXISTS. It is the author's own answer to a problem this pack has too, and we did not have
;  it. He shipped it one day after launch, in the same patch as the great price cut (research/10
;  section 1.2), with his own reason STATED: "Added a banking system; one kiosk deposits 200 points,
;  another withdraws 200 points. This should help achieving win conditions in co-op easier."
;  Three weeks later the step went 200 -> 500 "with a second buffer", i.e. 200 needed too many presses
;  and was spammable. We start where he ended up: 500 a press.
;
;  WHAT IT BUYS US MECHANICALLY. Firefight score is live and per-player, and it is also the thing the
;  player spends. Without a bank, points saved toward the win purchase are indistinguishable from
;  points about to be spent on marines, and in co-op nobody individually accumulates the win price.
;  Banked points are DEDUCTED from the live score and held in g_fe_bank, where fe_score_available
;  cannot see them - so they cannot be spent by accident, and the win purchase becomes a plan instead
;  of a lucky streak.
;
;  PLACEMENT, from his own words: "I04 has them on the beam tower's internal ramps next to the health
;  pack" and "Unearthed has them near the base power switch". He put the fiddly, repeated, multi-press
;  interaction on the route every player already walks every round. On our six maps that route is
;  ammo_crate0 / ammo_crate1 (global_firefight.hsc L54-55 [V]) and, on Beachhead and Holdout,
;  ps_gen/gen0-gen2. Two volumes per map: tv_fe_bank_in and tv_fe_bank_out. [NEW]
;
;  TWO KIOSKS, NOT ONE TOGGLE. He shipped two separate switches and so do we: a deposit press and a
;  withdraw press can never be confused under fire, and it matches the prompt vocabulary
;  ("Hold [E] to withdraw 500 deposited points.", OBSERVED).
;
;  THE SET-BOUNDARY RULE. research/10 section 2.3: he shipped the "objectives and switch states did
;  not reset at the set boundary" bug TWICE. Our rule is the inverse for this one global - g_fe_bank
;  must NOT be touched by any per-set teardown. If you add a teardown script, exclude it explicitly.
; =====================================================================================================
(script continuous fe_bank_cooldown_timer
    (sleep_forever)
    (set g_fe_bank_locked TRUE)
    (sleep 30)                                  ; 1 second. Short on purpose: a bank needs repeat
    (set g_fe_bank_locked FALSE)                ; presses, so it must not use k_fe_buy_cooldown.
)

(script static boolean fe_bank_deposit
    (if (and g_fe_board_open
             (not g_fe_bank_locked)
             (>= (fe_score_available) k_fe_bank_step))
        (begin
            (fe_charge k_fe_bank_step)
            (set g_fe_bank (+ g_fe_bank k_fe_bank_step))
            (wake fe_bank_cooldown_timer)
            (sound_impulse_start sfx_blip NONE 1)   ; stock blip, ff20_courtyard.hsc L780 [V]
            (if g_fe_debug (print "fe: deposited 500"))
            TRUE
        )
        (begin
            (if g_fe_debug (print "fe: deposit denied - score or kiosk cooldown"))
            FALSE
        )
    )
)

(script static boolean fe_bank_withdraw
    (if (and g_fe_board_open
             (not g_fe_bank_locked)
             (>= g_fe_bank k_fe_bank_step))
        (begin
            (set g_fe_bank (- g_fe_bank k_fe_bank_step))
            (fe_credit k_fe_bank_step)
            (wake fe_bank_cooldown_timer)
            (sound_impulse_start sfx_blip NONE 1)
            (if g_fe_debug (print "fe: withdrew 500"))
            TRUE
        )
        (begin
            (if g_fe_debug (print "fe: withdraw denied - empty bank or kiosk cooldown"))
            FALSE
        )
    )
)

; Console readout: (fe_bank_report)
(script static void fe_bank_report
    (print "fe: banked / live score below")
    (inspect g_fe_bank)
    (inspect (fe_score_available))
)

; =====================================================================================================
;  7. COOLDOWN
;  Pattern copied from Bungie's re-triggerable one-shots: a continuous script whose first statement is
;  (sleep_forever), woken with (wake ...). ff20_courtyard.hsc L511-513 (drop_pod_01) and
;  ff45_corvette_main.hsc L523-525 (ff45_resupply0) both do exactly this. [V]
;  The timed-sleep cooldown counter itself copies global_firefight.hsc L1933-1956
;  (s_surv_generator0_cooldown + (sleep s_surv_generator0_cooldown)). [V]
; =====================================================================================================
(script continuous fe_cooldown_timer
    (sleep_forever)
    (set g_fe_buy_locked TRUE)
    (sleep k_fe_buy_cooldown)
    (set g_fe_buy_locked FALSE)
    (if g_fe_debug (print "fe: cooldown over"))
)

; =====================================================================================================
;  8. THE PURCHASE GATES
; =====================================================================================================
(script static short fe_actors_alive
    (ai_living_count ai_fe_group)               ; hsdoc_hr.txt L1472 [V]
)

; How many of the concurrent cap's slots are still empty. This is the ONE number the whole
; reinforcement economy is gated on, and it is recomputed from the live world every time it is read -
; never from a purchase counter - so a friendly dying frees its slot on the same tick and no amount of
; buying, dying, expiring or garbage collection can make the bookkeeping drift.
; max is Bungie's own clamp idiom: (max 0 (- (ai_living_count ai_sur_phantom_01)
; s_sur_dropship_crew_count)), global_firefight.hsc L669. [V]
(script static short fe_slots_free
    (max 0 (- k_fe_actor_limit (fe_actors_alive)))
)

; Kept for the one-squad-per-slot fallback described in section 8a. A squad slot is free when nobody
; from that scenario squad is still alive.
(script static boolean (fe_slot_free (ai squad))
    (<= (ai_living_count squad) 0)
)

(script static boolean (fe_can_afford (long cost))
    (and
        g_fe_board_open
        (not g_fe_buy_locked)
        (>= (fe_score_available) cost)
    )
)

; Generic purchase for non-AI items (turret, vehicle, strike, win item).
; Returns TRUE if the purchase went through, and charges only on success.
(script static boolean (fe_try_buy (long cost))
    (if (fe_can_afford cost)
        (begin
            (fe_charge cost)
            (wake fe_cooldown_timer)
            TRUE
        )
        (begin
            (if g_fe_debug (print "fe: denied - score or cooldown"))
            FALSE
        )
    )
)

; Purchase for an AI squad. The old test was (and (fe_slot_free squad) (< actors limit)), i.e. the
; previous lot had to be ENTIRELY dead before you could buy again. That is what made reinforcements a
; once-a-round event instead of the continuous pressure the spec asks for, so it is replaced by the
; concurrent-slot test: you may buy in any wave, as often as the cooldown and your score allow, as
; long as the cap has left at least k_fe_buy_min_fill slots empty.
; The squad argument is no longer read here, and is kept only so that every per-map call site and the
; test harness compile unchanged.
(script static boolean (fe_try_buy_squad (long cost) (ai squad))
    (if (>= (fe_slots_free) k_fe_buy_min_fill)
        (fe_try_buy cost)
        (begin
            (if g_fe_debug (print "fe: denied - friendly slots full, wait for casualties"))
            FALSE
        )
    )
)

; =====================================================================================================
;  8a. PARTIAL PLACEMENT - HOW THE 8-MAN SQUAD IS TRIMMED TO THE CAP
;  The two-argument form of ai_place is what makes a concurrent cap possible without refusing the sale:
;      (<void> ai_place <ai> <short>)   hsdoc_hr.txt L1280
;      ; "places the given number of members of the specified squad."
;  so an 8-cell squad can be stood up 8, 6, 4 or 2 bodies at a time against whatever the cap has left.
;  [V] on the opcode and its documented meaning.
;  [G] on this specific USE of it, twice over, and both are first-compile risks:
;    1. No shipped Firefight script calls the two-argument form at all - every stock call is the bare
;       (ai_place sq_name) (ff20_courtyard.hsc L516, cex_ff_halo_main.hsc L127-129). Stock uses counts
;       only on ai_place_wave, where the count means SQUADS and not members
;       (ai_place_wave ... ai_sur_wave_spawns s_sur_wave_squad_count), global_firefight.hsc L590-591.
;    2. Placing into a squad that already has living members is unproven. The engine may fill the
;       remaining empty cells, or it may do nothing, or it may re-place the whole squad.
;  VERIFY BOTH IN STANDALONE BEFORE YOU SHIP. Buy a squad, kill half of it, buy again, and count
;  bodies with (fe_slots_report).
;  IF PARTIAL PLACEMENT DOES NOT WORK, the fallback needs no script rewrite, only tag work: author the
;  bought squad as TWO 4-cell scenario squads instead of one 8-cell squad, keep the per-map buy script
;  calling fe_place_up_to on whichever of the two passes fe_slot_free, and the cap arithmetic below is
;  unchanged. That path is all stock opcodes.
; =====================================================================================================
; Places up to 'want' members of 'squad', trimmed to the free slots under the concurrent cap.
; Returns the number of bodies it asked the engine for; 0 means nothing was placed.
(script static short (fe_place_up_to (ai squad) (short want))
    (set g_fe_place_n (fe_slots_free))
    (if (> g_fe_place_n want) (set g_fe_place_n want))
    (if (> g_fe_place_n 0)
        (begin
            (ai_place squad g_fe_place_n)       ; hsdoc_hr.txt L1280 [V opcode] [G use]
            (if g_fe_debug (print "fe: placed friendlies, count below"))
            (if g_fe_debug (inspect g_fe_place_n))
        )
        (if g_fe_debug (print "fe: nothing placed - cap full"))
    )
    g_fe_place_n
)

; =====================================================================================================
;  9. STANDING A BOUGHT SQUAD UP, AND THE obj_marines OBJECTIVE
;
;  Friendly allegiance needs NO script: stock Firefight already runs
;    (ai_allegiance human player) / (ai_allegiance player human)   global_firefight.hsc L238-241 [V]
;  and all six per-map startups repeat it (ff50_park_main.hsc L116-117, ff10_prototype.hsc L31-32,
;  ff60_airview.hsc L25-26, ff70_holdout.hsc L114-115, ff60_icecave.hsc L12-13,
;  ff30_waterfront.hsc L30-31). [V] So a squad authored with team = human is hostile to covenant and
;  friendly to the players the moment it is placed.
;
;  POSITIONING AND MOVEMENT, HOWEVER, NEED A NEW AI OBJECTIVE, AND THERE IS NO WAY AROUND IT.
;  Every task in obj_survival carries a squad-group filter naming a gr_survival_* group, and
;  hold_task's filter is gr_survival_all specifically - the one group a friendly squad must never
;  join. The old fe_squad_hold called (ai_set_task squad obj_survival hold_task); a squad in
;  gr_unsc_reinforcements given that task matches NO task and stands still. That is now fixed.
;
;  THE PATTERN WE COPY: obj_marines, from Installation 04, cex_ff_halo_main.hsc.
;  It is the one shipped Firefight map with working friendly Marines, and it solves exactly our
;  problem with a SEPARATE objective. Its refresh scripts are L220-242: [V]
;
;      (script static void refresh_gate_marines
;          (sleep 5)
;          (ai_reset_objective obj_marines/gate_marines))
;      (script static void refresh_gate_marines_followers
;          (sleep 5)
;          (ai_reset_objective obj_marines/gate_marines_followers))
;      (script static void refresh_gate_marines_defenders
;          (sleep 5)
;          (ai_reset_objective obj_marines/gate_marines_defenders))
;
;  and the task conditions live in cex_ff_halo_fragments.hsc, which is the compiled form of what you
;  type into Sapien: [V]
;
;      (script static boolean obj_mplaye_3_15  (> (game_coop_player_count) 1))   ; follower slot 2
;      (script static boolean obj_mplaye_3_16  (> (game_coop_player_count) 2))   ; follower slot 3
;      (script static boolean obj_mplaye_3_17  (> (game_coop_player_count) 3))   ; follower slot 4
;      (script static boolean obj_mdefen_3_2   (volume_test_objects tv_north_deck (ai_actors gr_survival_waves)))
;      (script static boolean obj_mdefen_3_3   (volume_test_objects tv_west_deck  (ai_actors gr_survival_waves)))
;      (script static boolean obj_mdefen_3_4   (volume_test_objects tv_east_deck  (ai_actors gr_survival_waves)))
;      (script static boolean obj_mdefen_3_5   (volume_test_objects tv_south_deck (ai_actors gr_survival_waves)))
;
;  The "3" in obj_mdefen_3_N is the objective index: obj_marines is objective 3 in that scenario.
;  So the defenders reposition to whichever approach the live wave is actually on, and the follower
;  slots scale with player count. That is the whole friendly-AI design, and it is tag data.
;
;  HOW FOLLOW ACTUALLY WORKS, since this was the biggest error in the previous version of this pack:
;  following is a TASK PROPERTY IN THE SCENARIO TAG, not a script call. Per the shipped objective
;  tree, the obj_survival tasks remaining / hero_follow / main_follow / bonus_follow all carry
;      follow: player front
;      follow radius: 10
;      follow Z clamp: 1
;      exhaustion script: survival_refresh_follow
;  and that is what makes every Covenant wave on every stock map chase the player. It is re-armed
;  from script by (ai_reset_objective obj_survival/main_follow) after a sleep - see
;  ff50_park_main.hsc L213-216: [V]
;      (script static void survival_refresh_follow
;          (survival_refresh_sleep)
;          (ai_reset_objective obj_survival/main_follow))
;  We reproduce that shape below against obj_marines instead of obj_survival.
;
;  WHAT WE DELETED: the fireteam API. The old fe_squad_follow called
;      (ai_set_fireteam_absorber ...) (ai_player_add_fireteam_squad ...)
;      (ai_player_set_fireteam_max ...) (ai_player_set_fireteam_max_squad_absorb_distance ...)
;  Those opcodes are real, but the shipped block that uses them is commented out in
;  global_firefight.hsc L2710-2752 with Bungie's own note ";tysongr - 53954: Adios, fireteams", its
;  companion survival_elite_fireteams (L2792-2817) is dead too, and in any case it was the ELITE
;  PLAYER's fireteam - never marines. It is kept only as dead commented reference at the bottom of
;  this section.
; =====================================================================================================
(script static void (fe_squad_arrive (ai squad))
    (sleep 1)
    (ai_set_team squad human)                   ; hsdoc_hr.txt L1460 [V]
    (ai_renew squad)                            ; hsdoc_hr.txt L1439, full health + grenades [V]
    (ai_force_active squad TRUE)                ; hsdoc_hr.txt L1442, do not freeze when players leave [V]
    (ai_disposable squad FALSE)                 ; hsdoc_hr.txt L1340, do not garbage collect them [V]
    ; Make them aware of the live wave so they engage instead of idling. gr_survival_all is Bungie's
    ; own wave squad group (global_firefight.hsc L665). hsdoc_hr.txt L1364. [V]
    (ai_magically_see squad gr_survival_all)
    ; Bind them to OUR objective, not obj_survival.
    (ai_set_objective squad obj_marines)        ; hsdoc_hr.txt L1508 [V opcode] [NEW objective]
    (if g_fe_debug (print "fe: squad arrived"))
)

; ---- HOLD / DEFEND ---------------------------------------------------------------------------------
; Replaces the old (fe_squad_hold squad obj_survival hold_task), which could never work.
; gate_marines_defenders is Installation 04's real directional defender task
; (cex_ff_halo_main.hsc L230-232). The objective and task names are now hardcoded, which also removes
; the old unverified reliance on <string_id> as a script PARAMETER type.
; ai_set_task is (<boolean> ai_set_task <ai> <string_id> <string_id>), hsdoc_hr.txt L1505 [V]
; and stock drives it exactly this way: (ai_set_task squad obj_survival hold_task),
; ff50_park_main.hsc L234-236. [V]
(script static void (fe_squad_hold (ai squad))
    (ai_set_objective squad obj_marines)
    (ai_set_task squad obj_marines gate_marines_defenders)
    (wake fe_defender_refresh)
    (if g_fe_debug (print "fe: squad holding - gate_marines_defenders"))
)

; ---- FOLLOW ----------------------------------------------------------------------------------------
; The real mechanism: assign the follower task, then keep re-arming the objective. The follow
; behaviour itself (player front / radius 10 / Z clamp 1) is a Sapien task property - see README.
(script static void (fe_squad_follow (ai squad))
    (ai_set_objective squad obj_marines)
    (ai_set_task squad obj_marines gate_marines_followers)
    (wake fe_follower_refresh)
    (if g_fe_debug (print "fe: squad following - gate_marines_followers"))
)

; ---- OBJECTIVE REFRESH SCRIPTS ---------------------------------------------------------------------
; One-shot forms, copied line for line from cex_ff_halo_main.hsc L220-232 with obj_marines kept. [V]
(script static void fe_refresh_gate_marines
    (sleep 5)
    (ai_reset_objective obj_marines/gate_marines)
)

(script static void fe_refresh_gate_marines_followers
    (sleep 5)
    (ai_reset_objective obj_marines/gate_marines_followers)
)

(script static void fe_refresh_gate_marines_defenders
    (sleep 5)
    (ai_reset_objective obj_marines/gate_marines_defenders)
)

; Continuous re-armers. A follow task exhausts: once its slots are filled and the squad arrives, the
; task is done and the squad stops tracking until the objective is reset. Stock solves this by naming
; survival_refresh_follow as the task's "exhaustion script" in the tag AND by the timed re-arm shape
; at ff50_park_main.hsc L213-216. We do both: name fe_refresh_gate_marines_followers as the task's
; exhaustion script in Sapien, and run this as a belt-and-braces loop.
; survival_refresh_sleep is Bungie's own difficulty-scaled delay, global_firefight.hsc L2694-2699. [V]
(script continuous fe_follower_refresh
    (sleep_forever)
    (sleep_until
        (begin
            (survival_refresh_sleep)
            (ai_reset_objective obj_marines/gate_marines_followers)
            FALSE
        )
        1
    )
)

(script continuous fe_defender_refresh
    (sleep_forever)
    (sleep_until
        (begin
            (survival_refresh_sleep)
            (ai_reset_objective obj_marines/gate_marines_defenders)
            FALSE
        )
        1
    )
)

; Diagnostic: how many friendlies are currently matched to each task.
; ai_task_count is "the living count of the AI in the given task OR any of its children",
; hsdoc_hr.txt L1526 region, and the stock fragments use it heavily
; (ff60_icecave_fragments.hsc: (<= (ai_task_count obj_survival/remaining) 3)). [V]
(script static void fe_report_tasks
    (print "fe: gate / followers / defenders task counts")
    (inspect (ai_task_count obj_marines/gate_marines))
    (inspect (ai_task_count obj_marines/gate_marines_followers))
    (inspect (ai_task_count obj_marines/gate_marines_defenders))
)

; ---- DEAD REFERENCE: the fireteam API we are NOT using ---------------------------------------------
; Left in as a comment so nobody re-invents it. All four opcodes exist (hsdoc_hr.txt L1847-1866) but
; the shipped consumer is commented out (global_firefight.hsc L2710-2752, ";tysongr - 53954: Adios,
; fireteams") and it was the elite player's escort, not marines. Also note Bungie's own absorb
; distance of 3.0 world units, which is far too small for a squad meant to trail a player.
;   (script static void (fe_squad_follow_fireteam (ai squad) (unit buyer))
;       (ai_set_fireteam_absorber squad 1)
;       (ai_player_add_fireteam_squad buyer squad)
;       (ai_player_set_fireteam_max buyer 4)
;       (ai_player_set_fireteam_max_squad_absorb_distance buyer 3.0))

; Timed expiry. Keeps the actor budget recoverable over a long match, and stops a bought squad from
; wandering into the next wave's spawn. ai_erase is the stock despawn (ff20_courtyard.hsc L495-498). [V]
(script static void (fe_squad_retire (ai squad))
    (ai_erase squad)                            ; hsdoc_hr.txt L1334 [V]
    (ai_erase_inactive squad 30)                ; hsdoc_hr.txt L5150 [V]
)

; =====================================================================================================
;  9a. THE FREE GARRISON  -  6 MEN AT MATCH START AND AT THE START OF EVERY ROUND
;
;  THE SPEC HALF THIS IMPLEMENTS: "a squad of 6 ODSTs/marines on the initial + every round".
;
;  WHY IT IS A SEPARATE SCENARIO SQUAD. sq_fe_garrison is 6 cells; sq_fe_marines and sq_fe_odst are 8.
;  Cell capacity is a tag field that no script can change (section 2b), so a 6-man free squad and an
;  8-man bought squad cannot be the same scenario squad. sq_fe_garrison is also the squad that must
;  never expire, which is a second reason to keep it distinct from the bought ones.
;
;  TOP UP, DO NOT STACK. At each round boundary this does not place a fresh 6 on top of the survivors;
;  it heals the survivors and places only the difference, so the garrison is 6 strong at the start of
;  every round and never more than 6. Two reasons, both mechanical:
;    * stacking a fresh 6 each round would put 30 free bodies on the map by round 5 and starve the
;      Covenant spawner exactly as section 2.3 describes;
;    * ai_renew is Bungie's own "as good as new" refresh - "refreshes the health and grenade count of
;      a group of actors, so they are as good as new", hsdoc_hr.txt L1439 [V] - so a survivor is worth
;      as much as a replacement and costs no slot.
;  It is also clamped by fe_slots_free, so on a map whose cap is below 6 the garrison simply arrives
;  smaller rather than squeezing the enemy spawner.
;
;  THE ROUND BOUNDARY IS DETECTED, NOT HOOKED. There is no round-start callback to attach to, so this
;  polls Bungie's own counters through fe_round_index (section 13a), which flattens
;  survival_mode_set_get and survival_mode_round_get into a 1-based absolute round that keeps counting
;  across sets. The poll shape - a continuous script whose first statement is (sleep_forever), woken
;  with (wake ...), then an (sleep_until (begin ... FALSE) 1) ticker - is the same one the per-map
;  escalation scripts already use, which in turn copies ff20_courtyard.hsc L511-513. [V]
;  g_fe_last_round starts at 0 and the first round index is 1, so the first poll after the wake fires
;  immediately: that is the spec's "on the initial".
; =====================================================================================================
(script static void fe_garrison_deploy
    (if (> (ai_living_count ai_fe_garrison) 0)
        (ai_renew ai_fe_garrison)               ; hsdoc_hr.txt L1439 [V]
    )
    (set g_fe_place_n (- k_fe_free_squad_size (ai_living_count ai_fe_garrison)))
    (if (> g_fe_place_n (fe_slots_free)) (set g_fe_place_n (fe_slots_free)))
    (if (> g_fe_place_n 0)
        (begin
            (ai_place ai_fe_garrison g_fe_place_n)   ; hsdoc_hr.txt L1280 [V opcode] [G use, see 8a]
            (fe_squad_arrive ai_fe_garrison)
            (fe_squad_hold ai_fe_garrison)           ; obj_marines/gate_marines_defenders
            (fe_blip_squad ai_fe_garrison)
            (set g_fe_garrison_drops (+ g_fe_garrison_drops 1))
            (if g_fe_debug (print "fe: free garrison topped up"))
        )
        (if g_fe_debug (print "fe: garrison already at strength, or cap full"))
    )
)

; Woken once from each per-map startup script. Polls every second.
(script continuous fe_garrison_watch
    (sleep_forever)
    (sleep_until
        (begin
            (if (> (fe_round_index) g_fe_last_round)
                (begin
                    (set g_fe_last_round (fe_round_index))
                    (fe_garrison_deploy)
                )
            )
            FALSE
        )
        30
    )
)

; =====================================================================================================
;  10. DROP POD DELIVERY FOR ODSTs  -  ONLY ON BEACHHEAD AND HOLDOUT
;  Structure copied line for line from Bungie's stock Firefight hazard pods,
;  ff20_courtyard.hsc L511-545. [V] Only the squad and the pod device change.
;  The caller must resolve the pod vehicle itself, because (ai_vehicle_get_from_spawn_point
;  sq_name/driver) needs a LITERAL squad/spawn-point name and cannot be built from an ai global.
;  Stock does the same thing: ff20_courtyard.hsc L518. [V]
;
;  WHICH MAPS MAY USE THIS, read straight out of the shipped scripts:
;    Beachhead  ff50_park_main.hsc   dm_drop_01-04 + sq_sur_drop_01-04   -> pattern present  [V]
;    Overlook   ff10_prototype.hsc   dm_drop_01-05 + sq_sur_drop_01-05   -> pattern present  [V]
;    Holdout    ff70_holdout.hsc     dm_drop_01-04 + sq_sur_drop_01-04   -> pattern present  [V]
;    Waterfront ff30_waterfront.hsc  dm_drop_01-05 + sq_sur_drop_01-05   -> pattern present  [V]
;    Outpost    ff60_airview.hsc     NO dm_drop_*, NO sq_sur_drop_*, NO survival_drop_spawn  [V]
;    Glacier    ff60_icecave.hsc     NO dm_drop_*, NO sq_sur_drop_*, NO dm_longsword_01      [V]
;  Outpost and Glacier therefore use the walk-in delivery instead. See those two files.
;
;  "Pattern present" is NOT "free". A drop pod lands wherever the SQUAD'S TAG SPAWN POINT is -
;  dm_drop_NN is only an invisible animated rail (checklist tag invis_cov_squad_drop_pod, folder
;  dm_droprails) that carries the shell down to meet it. You cannot relocate a pod from script. The
;  four or five existing sites are by definition sited in Covenant approach lanes, so a friendly pod
;  needs a NEW rail dm_fe_pod_01 [NEW] and a NEW spawn point sq_fe_odst/driver [NEW], placed beside
;  ammo_crate0.
;
;  PREREQUISITE: the ODST squad's cells must have vehicle = the HEV pod and a pod seat.
;  Reach ships Covenant hazard pods; a UNSC/HEV pod tag may not exist in the stock tag set - if it
;  does not, use the walk-in delivery on every map. [G - the UNSC pod tag's existence is unverified]
; =====================================================================================================
; The pod is typed (device_name ...) because stock proves a device_name parameter is accepted by both
; the device_ and the object_ functions: global_firefight.hsc L3204-3209 passes (device_name pack) to
; object_get_health and chud_track_object_for_player. [V]
(script static void (fe_pod_sequence (device_name pod) (vehicle pod_vehicle))
    (objects_attach pod "" pod_vehicle "")
    (sleep 1)
    (device_set_position pod 1)
    (sleep_until (>= (device_get_position pod) 0.85) 1)
    (unit_open pod_vehicle)
    (sleep 15)
    (vehicle_unload pod_vehicle "")
    (sleep_until (>= (device_get_position pod) 0.98) 1)
    (effect_new_on_object_marker fx\fx_library\pod_impacts\default\pod_impact_default_large.effect pod "fx_impact")
    (sleep_until (>= (device_get_position pod) 1) 1)
    (sleep 1)
    (objects_detach pod pod_vehicle)
    (object_destroy pod)
)

; =====================================================================================================
;  11. PLAYER FEEDBACK
; =====================================================================================================
; Pick ONE of these three and delete the others once you know which works in your build.
;
; (a) Scripted training text. hud_set_training_text / hud_show_training_text are real
;     (hsdoc_hr.txt L3755-3761) but NO shipped Firefight script uses them, and the <string_id> has to
;     resolve to a real string in the map's string tags. [G]
; (b) Incidents. This IS what stock Firefight uses for every announcement
;     (global_firefight.hsc L2957-3140, submit_incident / submit_incident_with_cause_campaign_team,
;     hsdoc_hr.txt L5307-5328). [V] mechanism, but each new message needs a new incident entry in the
;     map's incident globals tag, which is tag work, not script work.
; (c) A blip sound only. (sound_impulse_start sfx_blip NONE 1) is stock
;     (ff20_courtyard.hsc L780). [V] Cheapest to get working; carries no text.
(script static void (fe_notify (string_id message))
    (hud_set_training_text message)             ; [G]
    (hud_show_training_text TRUE)               ; [G]
)

(script static void fe_notify_clear
    (hud_show_training_text FALSE)              ; [G]
)

; Put a navpoint on EVERY living member of a friendly squad, so players can find their reinforcements -
; and so that the number of navpoints on screen IS the slots-used readout. See section 11b for why
; that is the readout and not a number.
; chud_track_object_with_priority is (<void> ... <object> <long>), hsdoc_hr.txt L3839, and stock calls
; it on the ammo crates with priority 13: (chud_track_object_with_priority obj_ammo_crate0 13),
; global_firefight.hsc L3192. [V] Priority 13 is reused here rather than an invented 1.
; Unrolled to 8 because HaloScript has no loops and the bought squads are now 8 cells (section 2b).
; list_get is hsdoc_hr.txt L234, list_count L237, ai_actors L1493. [V]
(script static void (fe_blip_squad (ai squad))
    (if (> (list_count (ai_actors squad)) 0)
        (chud_track_object_with_priority (list_get (ai_actors squad) 0) 13))
    (if (> (list_count (ai_actors squad)) 1)
        (chud_track_object_with_priority (list_get (ai_actors squad) 1) 13))
    (if (> (list_count (ai_actors squad)) 2)
        (chud_track_object_with_priority (list_get (ai_actors squad) 2) 13))
    (if (> (list_count (ai_actors squad)) 3)
        (chud_track_object_with_priority (list_get (ai_actors squad) 3) 13))
    (if (> (list_count (ai_actors squad)) 4)
        (chud_track_object_with_priority (list_get (ai_actors squad) 4) 13))
    (if (> (list_count (ai_actors squad)) 5)
        (chud_track_object_with_priority (list_get (ai_actors squad) 5) 13))
    (if (> (list_count (ai_actors squad)) 6)
        (chud_track_object_with_priority (list_get (ai_actors squad) 6) 13))
    (if (> (list_count (ai_actors squad)) 7)
        (chud_track_object_with_priority (list_get (ai_actors squad) 7) 13))
)

; =====================================================================================================
;  11b. A HUD READOUT OF SLOTS USED - WHAT IS AND IS NOT REACHABLE
;  Asked for: an on-screen "friendly slots used / cap". Honest answer: a NUMBER is not reachable from
;  HaloScript without tag work, because nothing in hsdoc_hr.txt formats an integer into a displayable
;  string. hud_set_training_text and chud_track_object_with_priority both take a <string_id>, which is
;  a pointer to a string already authored in the map's string tags - you can show "SLOTS FULL", you
;  cannot show "9 / 12".
;  So the readout ships in three layers, cheapest first:
;    (a) NAVPOINT COUNT. fe_blip_squad above puts one navpoint on every living friendly, so the player
;        reads the slot usage by counting markers. Fully [V] opcode, no new tag content, works today.
;    (b) TWO PRE-AUTHORED BANNERS, fired on the edges only: "REINFORCEMENT SLOTS FULL" when a purchase
;        is refused, and "REINFORCEMENTS AVAILABLE" when slots open again. Each needs one real string
;        id in the map's string tags, same as every other fe_notify call in this pack. [G]
;    (c) CONSOLE READOUT, fe_slots_report in section 14. Exact numbers, dev only.
;  THE ONE WAY TO GET A REAL NUMBER ON SCREEN, and why it is not the default: the bonus round's timer
;  widget takes a number -
;      (<void> chud_bonus_round_set_timer <real>)     hsdoc_hr.txt L3537
;      (<void> chud_bonus_round_show_timer <boolean>) hsdoc_hr.txt L3531
;  and stock drives both (global_firefight.hsc L901-903). [V] You could push the slot count into that
;  widget and leave it visible. Do not: global_firefight.hsc owns those same three calls for the real
;  bonus round and resets them at L901-903, so the two uses would fight, and the number would appear
;  to the player under a bonus-round label. Listed because it is the only numeric option, not because
;  it is a good one. [G]
; =====================================================================================================
(script static void fe_slots_banner_full
    (fe_notify "fe_slots_full")                 ; [G] needs a real string id in the map
    (sound_impulse_start sfx_blip NONE 1)       ; ff20_courtyard.hsc L780 [V]
)

(script static void fe_slots_banner_open
    (fe_notify "fe_slots_open")                 ; [G] needs a real string id in the map
)

; Fires each banner once per transition, never per tick. Woken from each per-map startup script.
(script continuous fe_slots_banner_watch
    (sleep_forever)
    (sleep_until
        (begin
            (cond
                ((and (not g_fe_slots_full) (< (fe_slots_free) k_fe_buy_min_fill))
                    (begin (set g_fe_slots_full TRUE) (fe_slots_banner_full)))
                ((and g_fe_slots_full (>= (fe_slots_free) k_fe_buy_min_fill))
                    (begin (set g_fe_slots_full FALSE) (fe_slots_banner_open)))
            )
            FALSE
        )
        30
    )
)

; =====================================================================================================
;  11a. THE PURCHASE TERMINAL ANCHOR
;  ammo_crate0 / ammo_crate1 are the best-evidenced player-stronghold markers in Firefight, and they
;  exist on every map because the globals DEFAULT to those object names - no per-map script has to set
;  them (global_firefight.hsc L54-55): [V]
;      (global object_name obj_ammo_crate0 ammo_crate0)
;      (global object_name obj_ammo_crate1 ammo_crate1)
;  Stock creates and HUD-tracks them at global_firefight.hsc L3177-3196. [V]
;  So the terminal volumes, and the friendly arrival points, go beside ammo_crate0. Read its position
;  out of the scenario tag in Sapien; no coordinate exists in any public source.
;  This helper puts the stock crate waypoint on whichever crate you nominate as the terminal.
;
;  *** ONE EXCEPTION, AND IT IS A DELIBERATE ONE: THE WIN TERMINAL GOES OUTSIDE. ***
;  research/10 section 3.2, which is the most instructive placement the author makes: on Unearthed
;  everything routine is crammed inside the defensible building so the economy is usable without
;  leaving cover, but the MAC Cannon - the win purchase - is exiled to the CRANE, away from the hub.
;  The run to the Crane under a cruiser's barrage, while the glassing timer burns, IS the climax. In
;  the same patch he pulled the friendly turrets closer to the base and pushed two Covenant drop-pod
;  zones further away, then put the win on the far side of the gap.
;  Rule for this pack: routine economy beside ammo_crate0; the win terminal at the map's exposed
;  named anchor, one per map, listed in each scenario file's header and in research/05 section 4.4.
;  Only NAMED tag objects are used as those anchors - never an invented coordinate.
;  Note this reverses research/05 section 6 item 4 ("place the win interactable at or next to the
;  player's own stronghold"), which was written before the author's placement was recovered. His
;  mitigation for the complaint about reaching the MAC in time was a LOOSER ROUND GATE, not a closer
;  terminal - he moved the gate from Set 2/Round 3/Wave 5 to the start of Set 2 and left the Crane
;  where it was.
; =====================================================================================================
(script static void fe_blip_terminal
    (chud_track_object_with_priority obj_ammo_crate0 13)
)

; =====================================================================================================
;  12. RUNTIME WEAPON SWAP (optional - prefer authoring one squad per loadout)
;  There is NO plural units_add_equipment in Reach: the only form is
;    (unit_add_equipment <unit> <starting_profile> <boolean> <boolean>)   hsdoc_hr.txt L1097 [V]
;  and HaloScript has no loops, so the unroll below is the only way to re-arm a whole squad.
;  (list_get hsdoc_hr.txt L234, list_count L237, ai_actors L1493.) [V]
;  <profile> must be a starting_profile defined in the map's globals.
;  [G] starting_profile is a valid HaloScript TYPE (it appears in unit_add_equipment, hsdoc_hr.txt
;  L1097, and player_set_profile, L5581) but no shipped script uses it as a script PARAMETER type.
;  If the compiler rejects the parameter, inline the profile name at each call site instead.
; =====================================================================================================
(script static void (fe_arm_squad (ai squad) (starting_profile profile))
    (if (> (list_count (ai_actors squad)) 0)
        (unit_add_equipment (unit (list_get (ai_actors squad) 0)) profile TRUE FALSE))
    (if (> (list_count (ai_actors squad)) 1)
        (unit_add_equipment (unit (list_get (ai_actors squad) 1)) profile TRUE FALSE))
    (if (> (list_count (ai_actors squad)) 2)
        (unit_add_equipment (unit (list_get (ai_actors squad) 2)) profile TRUE FALSE))
    (if (> (list_count (ai_actors squad)) 3)
        (unit_add_equipment (unit (list_get (ai_actors squad) 3)) profile TRUE FALSE))
    (if (> (list_count (ai_actors squad)) 4)
        (unit_add_equipment (unit (list_get (ai_actors squad) 4)) profile TRUE FALSE))
    (if (> (list_count (ai_actors squad)) 5)
        (unit_add_equipment (unit (list_get (ai_actors squad) 5)) profile TRUE FALSE))
    (if (> (list_count (ai_actors squad)) 6)
        (unit_add_equipment (unit (list_get (ai_actors squad) 6)) profile TRUE FALSE))
    (if (> (list_count (ai_actors squad)) 7)
        (unit_add_equipment (unit (list_get (ai_actors squad) 7)) profile TRUE FALSE))
)

; =====================================================================================================
;  13. MISSION OUTCOME HELPERS
;  Both copied from Bungie's own end-condition scripts. A win is three statements:
;    (survival_spartans_increment_score) (event_survival_spartans_win_normal)
;    (set b_survival_game_end_condition true)                   global_firefight.hsc L2568-2588 [V]
;  A loss swaps in the elite versions:                          global_firefight.hsc L2482-2502 [V]
;  Setting b_survival_game_end_condition is what lets stock survival_end_game (L2434) run
;  (mp_round_end_with_winning_team none) and shut the match down cleanly. Do not call
;  mp_round_end_with_winning_team yourself.
; =====================================================================================================
(script static void fe_mission_won
    (if g_fe_debug (print "fe: MISSION WON"))
    (survival_spartans_increment_score)
    (event_survival_spartans_win_normal)
    (set b_survival_game_end_condition true)
)

(script static void fe_mission_lost
    (if g_fe_debug (print "fe: MISSION LOST"))
    (survival_elites_increment_score)
    (event_survival_elites_win_normal)
    (set b_survival_game_end_condition true)
)

; =====================================================================================================
;  13a. ROUND GATING
;  survival_mode_round_get is hsdoc_hr.txt L3474, survival_mode_set_get L3471. [V] Both are 0-based and
;  the round counter RESETS every set, so neither is usable as a gate on its own. fe_round_index
;  flattens them into a 1-based absolute round number that keeps counting across sets:
;      set 0 round 0 -> 1      set 1 round 0 -> 4      set 2 round 0 -> 7
;  So "round 5" means set 2, round 2 - one round after the start of set 2, which is where the author
;  eventually put his own win gate.
; =====================================================================================================
(script static short fe_round_index
    (+ (* (survival_mode_set_get) 3) (+ (survival_mode_round_get) 1))
)

; The one gate predicate every gated purchase calls. Price controls whether you CAN afford a thing;
; the gate controls whether a lucky early round is allowed to break the curve (research/10 1.2).
(script static boolean (fe_gate_open (short gate))
    (>= (fe_round_index) gate)
)

; The win purchase is gated by round, not by a timer (research/05 section 6 item 4: tight timers are
; the most complained-about mechanic in the shipped mod).
(script static boolean fe_win_unlocked
    (fe_gate_open k_fe_win_round_gate)
)

; =====================================================================================================
;  14. BOARD CONTROL
; =====================================================================================================
(script static void fe_board_open
    (set g_fe_board_open TRUE)
    (fe_blip_terminal)
    (if g_fe_debug (print "fe: purchase board OPEN"))
)

(script static void fe_board_close
    (set g_fe_board_open FALSE)
)

; Debug readout. Call from the Sapien / Standalone console: (fe_report)
; (print) is used all over the stock scripts (ff20_courtyard.hsc L514 etc). [V]
(script static void fe_report
    (print "fe: score / friendly actors below")
    (inspect (fe_score_gross))
    (inspect (fe_actors_alive))
)

; The slot ledger, in the order you need to read it: alive, cap, free, garrison strength, top-up count.
; This is layer (c) of the readout in section 11b and the only place exact numbers are available.
(script static void fe_slots_report
    (print "fe: alive / cap / free / garrison alive / garrison top-ups")
    (inspect (fe_actors_alive))
    (inspect k_fe_actor_limit)
    (inspect (fe_slots_free))
    (inspect (ai_living_count ai_fe_garrison))
    (inspect g_fe_garrison_drops)
)

; =====================================================================================================
;  15. SHARED SQUAD EXPIRY WATCHERS
;  One per BOUGHT squad. Woken by the per-map buy script. Retires survivors after k_fe_squad_lifetime
;  so the shared actor pool recovers, and never retires them mid boss wave.
;  survival_mode_current_wave_is_boss is hsdoc_hr.txt L3504. [V]
;  THERE IS DELIBERATELY NO fe_garrison_expiry. The free garrison is the player's standing baseline and
;  is bounded a different way - it is topped up to k_fe_free_squad_size and never past it (section 9a) -
;  so expiring it would only create a gap in the middle of a round for no budget gain.
;  Note that expiry is now a SECOND slot-recovery path on top of casualties. Both feed the same live
;  (ai_living_count ai_fe_group), so a retired squad frees its slots the moment ai_erase runs.
; =====================================================================================================
(script continuous fe_marines_expiry
    (sleep_forever)
    (sleep k_fe_squad_lifetime)
    (sleep_until (not (survival_mode_current_wave_is_boss)) 30)
    (fe_squad_retire ai_fe_marines)
    (if g_fe_debug (print "fe: marines retired"))
)

(script continuous fe_odst_expiry
    (sleep_forever)
    (sleep k_fe_squad_lifetime)
    (sleep_until (not (survival_mode_current_wave_is_boss)) 30)
    (fe_squad_retire ai_fe_odst)
    (if g_fe_debug (print "fe: odsts retired"))
)
