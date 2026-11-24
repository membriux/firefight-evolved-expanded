; =====================================================================================================
;  fe_reinforcements.hsc  -  Firefight Evolved Expanded, purchase + reinforcement library
;  REWRITE 2026-11-23.  ZERO NEW SCRIPT OBJECTS.
; =====================================================================================================
;
;  WHY THIS FILE WAS REWRITTEN FROM SCRATCH
;  research/18 and research/19 established two hard facts:
;    1. Blamite's ScriptCompiler can only REFERENCE a script object, never create one, and
;    2. of the 54 objects the previous design needed, 53 do not exist in ff70_holdout
;       (build/logs/objcheck.log).  Creating them needs Sapien on Windows.
;  So this version references ONLY objects that ship inside Holdout's own scnr tag.  Every name below
;  was read out of the cache, not inferred from a Bungie script elsewhere, and the read is cited.
;
;  THE FOUR SUBSTITUTIONS THAT REMOVED 53 OBJECTS
;    trigger volumes (26 -> 0)   purchase input is now (objects_distance_to_object <player> <kiosk>),
;                                opcode 0x0B2, against objects the map already places.  Bungie uses
;                                the same call with the same arguments in Holdout's own
;                                survival_health_pack_highlight (decompile L2825-2840).
;    object names    (10 -> 0)   the kiosks are health_pack0..5 - six placed `health_station`
;                                device_controls, placement flags 0x00000000, i.e. present from map
;                                load, spread through the player base.  The previous proposal
;                                (sc_hack_*, sc_resupply_*, generator_switch*) is WRONG and is
;                                rejected here: every one of those has placement flag bit0
;                                ("not automatically") set, so it does not exist until a script
;                                creates it, and sc_hack_*/sc_resupply_*/sc_target_* sit in an
;                                off-map prop farm at x~487 y~65 z~11.4, 50 world units from the
;                                arena, where no player can reach them.  See build/logs/placecheck.py.
;    squads          (10 -> 0)   allies are the four stock drop-pod squads sq_sur_drop_01..04.  They
;                                are the only squads in Holdout that already carry a populated cell
;                                (4 actors, major upgrade "none", one character choice, one initial
;                                weapon) AND four spawn points with a `driver` seat in an
;                                invis_cov_squad_drop_pod.  The six sur_fireteam_01..06 squads CANNOT
;                                be used as the ally bodies: all six have 0 designer cells, 0
;                                templated cells and 0 spawn points, so ai_place on them spawns
;                                nothing, and giving them a cell needs tag growth, which Blamite
;                                rejects (research/19 section 4).
;    squad groups     (2 -> 0)   gr_survival_fireteams, reparented to root, is the ally group.
;    objective/roles  (3 -> 0)   obj_fireteams/fireteams already exists and is already filtered to
;                                squad group 9 (= gr_survival_fireteams) with follow = player,
;                                follow radius 3.0 and no capacity cap.  Bungie left a ready-made
;                                "allies follow the player" task in this map.
;    starting profiles(2 -> 0)   this definition set has no starting-profiles block at all.  Ally
;                                weapons come from the cell's `initial weapon` block out of the
;                                23-entry weapon palette - a 2-byte tag patch, see tools/patch.
;
;  VERIFIED OBJECT MANIFEST  (all STOCK; nothing below has to be authored)
;    object_name   health_pack0..5         scnr controls[3..8], health_station, flags 0x0
;    object_name   ammo_crate0, ammo_crate1 scnr equipment[0..1], ammo_box
;    object_name   sc_poa                  scnr scenery[48], unsc_halcyon_class_cruiser_poa, flags 0x0
;    object_name   dm_longsword_01         scnr machines[4], longsword
;    ai_squad      sq_sur_drop_01..04      scnr squads[26..29]
;    ai_squad      sq_sur_banshee_01/02    scnr squads[14..15]
;    ai_squad_group gr_survival_fireteams  scnr squad groups[9]
;    snd!          sound\game_sfx\ui\transition_beeps                       tag 8131
;    snd!          sound\game_sfx\multiplayer\flag_failure                  tag 3660
;    snd!          sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus  tag 9243
;  obj_fireteams / fireteams are passed as string_id arguments (ai_set_task arg types are
;  string_id, string_id), so they are not even script-object references - but both were still
;  confirmed present in the ai objectives block before being used.
;
;  print IS DELIBERATELY OFF THE CRITICAL PATH.  ReachMCC_U13_Scripting.xml marks opcode 0x028
;  null="true"; the engine will not run it.  Every print here is behind (if g_fe_debug ...).
; =====================================================================================================


; =====================================================================================================
;  1. PRICES - THE NAMED-CONSTANTS BLOCK.  RETUNE HERE, NOWHERE ELSE.
;
;  The author's real numbers, read out of ff_unearthed (research/14 section 6.2), not our earlier
;  guesses.  His ladder: marines 500 (4 bodies), turret 750, Warthog 1,000, hog upgrade 2,000,
;  Scorpion 3,500, MAC 10,000.
;
;  EXPECT THESE TO MOVE.  The author cut every launch price by 50-75% within 24 hours of release and
;  cut them again three weeks later (research/10 section 1.2).  Nothing below is sacred; all of it is
;  one line to change.
; =====================================================================================================
(global long k_fe_cost_squad      500)      ; [AUTHOR] buy_marines = 500 for four bodies = 125/body.
(global long k_fe_cost_spartan   1000)      ; SPARTAN TIER: 1,000 for TWO bodies = 500/body, i.e. 4x a
                                            ; trooper.  Chosen over "1,500 for four" (375/body) because
                                            ; 375/body is only 3x a trooper for a far tougher unit, and
                                            ; at the measured ~2,000-2,500 income per round the player
                                            ; could buy four Spartans nearly every round, which
                                            ; trivialises the mode.  1,000 is about half a round's
                                            ; income for two power units: a real trade, not a strict
                                            ; upgrade.  It also lands on the same rung as the author's
                                            ; Warthog, which reads right for two Spartans.
(global long k_fe_cost_ammo       500)      ; [AUTHOR] buy_ammo1 (light weapon rack) = 500.
(global long k_fe_cost_air       1000)      ; [AUTHOR] buy_hog rung = 1,000.
(global long k_fe_cost_strike    3000)      ; [AUTHOR] buy_turret3 / buy_tank rung = 3,500; 3,000 here
                                            ;          because the Longsword pass is one-shot, not a
                                            ;          persistent asset.
(global long k_fe_bank_step       500)      ; [AUTHOR] deposit/withdraw = 500 a press.
(global long k_fe_cost_win      10000)      ; [AUTHOR] buy_mac = 10,000 and IS the win condition.

; =====================================================================================================
;  2. TUNING
;
;  k_fe_actor_limit IS THE ONE NUMBER MOST LIKELY TO NEED CHANGING.  The author shipped 8 after
;  playtesting his own map and had reasons we cannot see.  12 is the USER'S choice, and it is also the
;  figure our own earlier analysis derived independently (Bungie's 2 escorts per player x 6 slots).
;  Both of those are on record; 8 is the playtested one.
;
;  TWO CAVEATS ON 12, BOTH SPECIFIC AND BOTH REAL.
;    1. Engine headroom.  research/06 derives a ceiling of roughly 34 concurrent actors for BOTH
;       sides together (6 carryover + 6 squads x up to 4 cells + 4 dropship crew).  The friendly
;       budget comes out of the same pool as the Covenant spawner, so 12 friendlies is a materially
;       bigger bite than 8 and will show up as thinner enemy waves, not as an error.
;    2. Holdout specifically.  Holdout is the ONE stock map where Bungie authored
;       cs_enable_pathfinding_failsafe TRUE, and its ramps queue badly.  Our per-map analysis wanted
;       Holdout BELOW the default, at 8.  So 12 on Holdout is the most aggressive combination
;       available: the map most prone to AI congestion, at the highest cap.  Expect visible queueing
;       on the ramps with a full ally field.  Dropping to 10 or back to 8 is this one line.
; =====================================================================================================
(global short k_fe_actor_limit     12)      ; [USER] total living allies, troopers + Spartans together,
                                            ; counted with ai_living_count on the ROOT ally group.
                                            ; [AUTHOR's playtested value was 8.]
(global short k_fe_spartan_limit    4)      ; SPARTAN SUB-CAP: at most 4 Spartans alive at once, i.e.
                                            ; two purchases.  Without this a player who ignores
                                            ; troopers fills the whole budget with the strongest unit
                                            ; and the trooper tier becomes pointless.  12 total with a
                                            ; sub-cap of 4 means 4 Spartans + 8 troopers, or 12
                                            ; troopers, or any mix - which is the choice the sub-cap
                                            ; exists to create.
(global short k_fe_squad_size       4)      ; [AUTHOR] marine_rein delivers 4 bodies per purchase.
(global short k_fe_spartan_size     2)      ; two Spartans per purchase.
(global real  k_fe_kiosk_radius   2.5)      ; world units.  Bungie's own health-station proximity test
                                            ; uses 3.0 (decompile L2835); tightened so you must stand
                                            ; at the station, not merely walk past it.
(global short k_fe_dwell            8)      ; ticks the buyer must hold position.  30 ticks = 1 s.
(global short k_fe_cooldown       150)      ; 5 s anti-spam lock-out per station after a sale.
(global short k_fe_gate_spartan     1)      ; Spartans gated on SET >= 1, so round 1 of set 1 is still
                                            ; fought with troopers.
(global short k_fe_gate_air         2)      ; [AUTHOR] "not available until Round 2".
(global short k_fe_gate_strike      1)      ; gate on SET, not round - see section 9.
(global short k_fe_gate_win         1)      ; [AUTHOR] buy_mac waits on (>= (survival_mode_set_get) 1).

; =====================================================================================================
;  2a. THE SPARTAN LOADOUT POOLS.
;
;  THESE ARE TAG DATA, NOT SCRIPT.  They are listed here as editable documentation because the values
;  live in the squad cell, not in any script call, and tools/patch/holdout_fe_spartans.py is the one
;  place to change them.  Randomisation is FREE: weapon_palette_choice_block and
;  equipment_palette_choice_block each hold up to 8 entries with a `chance` weight (short at +0x0E),
;  and the engine picks per actor per spawn.  No random_range call, no script branch, no cost.
;
;  WEAPON POOL - scenario weapon palette indices, every one verified present in Holdout's own
;  23-entry palette (not merely present in the tag table):
;      [ 8] objects\weapons\rifle\sniper_rifle\sniper_rifle
;      [11] objects\weapons\support_high\rocket_launcher\rocket_launcher
;      [12] objects\weapons\support_high\spartan_laser\spartan_laser
;      [15] objects\vehicles\covenant\turrets\plasma_turret\weapon\plasma_turret\plasma_turret
;      [19] objects\weapons\rifle\grenade_launcher\grenade_launcher
;  THE HUMAN MACHINE-GUN TURRET IS NOT AVAILABLE AS A CARRIED WEAPON.
;  objects\vehicles\human\turrets\machinegun\machinegun is vehicle palette [0], a `vehi`, so a biped
;  cannot hold it and the cell's `initial weapon` cannot name it.  Palette [15] is the detached
;  Covenant plasma turret, which IS a `weap` and IS carryable - that is the closest thing to a
;  man-portable turret this map ships, and it is what the pool uses.
;
;  ABILITY POOL - scenario equipment palette indices:
;      [1] objects\equipment\sprint\sprint                 STOCK palette entry
;      [2] objects\equipment\jet_pack\jet_pack             STOCK palette entry
;      [5] objects\equipment\drop_shield\drop_shield       STOCK palette entry
;      [6] objects\equipment\active_camouflage\active_camouflage   APPENDED - see below
;  Active camo and evade are in Holdout's TAG TABLE (eqip 7216 and eqip 5580) but NOT in the
;  scenario's 6-entry equipment palette, and `initial equipment` is a short_block_index into that
;  palette - so the tag being present is not enough.  The patch appends active_camouflage as palette
;  entry [6] by cloning the sprint entry's 16-byte tag_reference and swapping its datum.  Evade is
;  deliberately left out: four abilities is already a wide pool and evade is the weakest of them.
;
;  armor_lockup (palette [4]) is also stock and deliberately NOT in the pool - an ally that locks
;  down mid-fight stops shooting, which is the opposite of what a premium unit should do.
;
;  RANK: the cell's `major upgrade` is set to 4 = 'all' (major_upgrade_enum is
;  normal/few/many/none/all), so every Spartan spawns at major rank.  The trooper cells keep the
;  stock 3 = 'none'.  That is the whole durability difference and it costs no tag beyond the field.
; =====================================================================================================

; =====================================================================================================
;  3. SOUNDS.  sfx_blip is NOT a built-in.  Stock declares it as a script global of type `sound`
;     holding a real tag path, identically in all ten shipped Firefight scripts
;     (research/_raw/hsc/omaha_release_11860/ff50_park.hsc:160), and Holdout declares it itself at
;     decompile L158 - so OURS IS RENAMED sfx_fe_blip to avoid a duplicate global when this file is
;     united with the map's full script for the write.  All three tags below were confirmed
;     present in ff70_holdout as group snd! (extracted/ff70_holdout/tags.tsv).
; =====================================================================================================
(global sound sfx_fe_blip "sound\game_sfx\ui\transition_beeps")
(global sound sfx_fe_buy "sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus")
(global sound sfx_fe_deny "sound\game_sfx\multiplayer\flag_failure")

; =====================================================================================================
;  4. STATE
; =====================================================================================================
(global boolean g_fe_debug      false)      ; (set g_fe_debug true) for print tracing. Never shipped on.
(global boolean g_fe_open       false)      ; the shop is live.  Set by the per-map startup script.
(global short   g_fe_rotor          0)      ; which of the four drop squads the next purchase uses.
(global short   g_fe_spartan_rotor  0)      ; which of the two Spartan squads the next purchase uses.
(global short   g_fe_spartan_buys   0)      ; successful Spartan purchases this match.
(global long    g_fe_bank           0)      ; shared bank, as in the author's build: one global, either
                                            ; player can withdraw what the other deposited.
(global short   g_fe_buys           0)      ; successful ally purchases this match.
(global boolean g_fe_won        false)      ; latch, so the win purchase can only fire once.

; =====================================================================================================
;  5. PRIMITIVES
;
;  fe_valid is Bungie's own validity guard, copied verbatim in shape from
;  survival_health_pack_highlight: an absent player slot yields object_get_health < 0.  There is no
;  player_in_game_count in the U13 table (checked), so this is the only guard available - and it is
;  the one the shipped map uses, for all eight slots unconditionally.
; =====================================================================================================
(script static boolean fe_valid (unit who)
    (>= (object_get_health who) 0)
)

; Proximity instead of a trigger volume.  Argument order matches Bungie's own call
; (objects_distance_to_object pack subject): first argument is object_list, second is object, and
; `player` -> `unit` -> `object` -> `object_list` all cast, which the compiler confirmed.
;
; THE NEGATIVE-RETURN GUARD (audit 25, RISK-G3).  objects_distance_to_object returns a NEGATIVE
; value when the object list is empty or the named object is absent, and (< -1 radius) is true, so
; without the (>= ... 0) term an absent anchor reports every player as "near" it.
(script static boolean fe_near (unit who, object kiosk)
    (and
        (fe_valid who)
        (>= (objects_distance_to_object who kiosk) 0)
        (< (objects_distance_to_object who kiosk) k_fe_kiosk_radius)
    )
)

(script static long fe_score (unit who)
    (campaign_metagame_get_player_score who)
)

; =====================================================================================================
;  6. CHARGING.  A NEGATIVE campaign_metagame_award_points, charged to THE ACTUAL BUYER.
;
;  This is the author's mechanism, not a workaround (research/14 section 6.1): affordability and buyer
;  identity are tested together in one `or` over all eight player slots, then a parallel `cond` over
;  the same eight slots fires exactly one negative award against whoever is standing at the kiosk.
;  The only change is that "standing at the kiosk" is a distance test instead of volume_test_object.
;
;  player0 is NOT used.  It does not exist in the U13 opcode table (confirmed in research/18) and it
;  would also charge the wrong player.  human_player_in_game_get returns `player`, which is exactly
;  the first argument type campaign_metagame_award_points declares.
; =====================================================================================================
(script static boolean fe_buyer_at (object kiosk, long cost)
    (or
        (and (fe_near (human_player_in_game_get 0) kiosk) (>= (fe_score (human_player_in_game_get 0)) cost))
        (and (fe_near (human_player_in_game_get 1) kiosk) (>= (fe_score (human_player_in_game_get 1)) cost))
        (and (fe_near (human_player_in_game_get 2) kiosk) (>= (fe_score (human_player_in_game_get 2)) cost))
        (and (fe_near (human_player_in_game_get 3) kiosk) (>= (fe_score (human_player_in_game_get 3)) cost))
        (and (fe_near (human_player_in_game_get 4) kiosk) (>= (fe_score (human_player_in_game_get 4)) cost))
        (and (fe_near (human_player_in_game_get 5) kiosk) (>= (fe_score (human_player_in_game_get 5)) cost))
        (and (fe_near (human_player_in_game_get 6) kiosk) (>= (fe_score (human_player_in_game_get 6)) cost))
        (and (fe_near (human_player_in_game_get 7) kiosk) (>= (fe_score (human_player_in_game_get 7)) cost))
    )
)

; Anyone at all standing at the kiosk, whether or not they can pay.  Used to decide between the
; success and the failure sound, so a broke player gets told no instead of nothing.
(script static boolean fe_anyone_at (object kiosk)
    (or
        (fe_near (human_player_in_game_get 0) kiosk)
        (fe_near (human_player_in_game_get 1) kiosk)
        (fe_near (human_player_in_game_get 2) kiosk)
        (fe_near (human_player_in_game_get 3) kiosk)
        (fe_near (human_player_in_game_get 4) kiosk)
        (fe_near (human_player_in_game_get 5) kiosk)
        (fe_near (human_player_in_game_get 6) kiosk)
        (fe_near (human_player_in_game_get 7) kiosk)
    )
)

; The charge.  Exactly one branch of the cond fires, against the buyer, never against player 0.
(script static void fe_charge_at (object kiosk, long cost)
    (cond
        ((and (fe_near (human_player_in_game_get 0) kiosk) (>= (fe_score (human_player_in_game_get 0)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 0) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 1) kiosk) (>= (fe_score (human_player_in_game_get 1)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 1) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 2) kiosk) (>= (fe_score (human_player_in_game_get 2)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 2) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 3) kiosk) (>= (fe_score (human_player_in_game_get 3)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 3) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 4) kiosk) (>= (fe_score (human_player_in_game_get 4)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 4) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 5) kiosk) (>= (fe_score (human_player_in_game_get 5)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 5) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 6) kiosk) (>= (fe_score (human_player_in_game_get 6)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 6) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 7) kiosk) (>= (fe_score (human_player_in_game_get 7)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 7) (- 0 cost)))
    )
)

; The credit, for the bank withdrawal.  Same shape, positive amount, and the affordability clause is
; dropped because a withdrawal has no price.
(script static void fe_credit_at (object kiosk, long amount)
    (cond
        ((fe_near (human_player_in_game_get 0) kiosk) (campaign_metagame_award_points (human_player_in_game_get 0) amount))
        ((fe_near (human_player_in_game_get 1) kiosk) (campaign_metagame_award_points (human_player_in_game_get 1) amount))
        ((fe_near (human_player_in_game_get 2) kiosk) (campaign_metagame_award_points (human_player_in_game_get 2) amount))
        ((fe_near (human_player_in_game_get 3) kiosk) (campaign_metagame_award_points (human_player_in_game_get 3) amount))
        ((fe_near (human_player_in_game_get 4) kiosk) (campaign_metagame_award_points (human_player_in_game_get 4) amount))
        ((fe_near (human_player_in_game_get 5) kiosk) (campaign_metagame_award_points (human_player_in_game_get 5) amount))
        ((fe_near (human_player_in_game_get 6) kiosk) (campaign_metagame_award_points (human_player_in_game_get 6) amount))
        ((fe_near (human_player_in_game_get 7) kiosk) (campaign_metagame_award_points (human_player_in_game_get 7) amount))
    )
)

; =====================================================================================================
;  7. FEEDBACK.  sound_impulse_start (sound, object, real) - the kiosk itself is the emitter, so the
;     cue is positional and the buyer hears it at the terminal.
; =====================================================================================================
(script static void fe_ok (object kiosk)
    (sound_impulse_start sfx_fe_buy kiosk 5)
)

(script static void fe_deny (object kiosk)
    (sound_impulse_start sfx_fe_deny kiosk 5)
)

(script static void fe_blip (object what)
    (sound_impulse_start sfx_fe_blip what 3)
    (chud_track_object what true)
)

(script static void fe_unblip (object what)
    (chud_track_object what false)
)

; =====================================================================================================
;  8. THE ALLY BUDGET.
;
;  The cap is read off a ROOT squad group, exactly as the author does it, and
;  survival_wave_living_count is left COMPLETELY STOCK (research/14 section 6.4).  That works only
;  because the ally group sits outside gr_survival_all.
;
;  CORRECTION TO EARLIER NOTES, measured from the cache: gr_survival_fireteams (group 9) is NOT a root
;  group.  Its parent is group 1 gr_survival_waves, whose parent is group 0 gr_survival_all.  Left
;  alone, every purchased ally would be counted by (ai_living_count "gr_survival_all") inside
;  survival_wave_living_count, the wave would never report clear, and the round would never end.
;  Reparenting it to root is a 2-byte same-size write; tools/patch carries the exact edit.
;  NOTHING IN THIS FILE COMPENSATES FOR THAT PATCH.  Without it the map hangs between waves.
; =====================================================================================================
(script static short fe_allies_alive
    (ai_living_count "gr_survival_fireteams")
)

(script static short fe_slots_free
    (- k_fe_actor_limit (fe_allies_alive))
)

(script static boolean fe_has_room
    (>= (fe_slots_free) k_fe_squad_size)
)

; THE SPARTAN SUB-CAP.  Spartans count against k_fe_actor_limit like everything else - both tiers are
; in gr_survival_fireteams, so fe_allies_alive already includes them - AND they additionally cannot
; exceed k_fe_spartan_limit between them.  Counted as the sum of the two Spartan squads rather than
; off a group, because there is no spare squad group to put only the Spartans in and the design
; refuses to invent one.
(script static short fe_spartans_alive
    (+ (ai_living_count "sur_fireteam_03") (ai_living_count "sur_fireteam_04"))
)

(script static boolean fe_has_spartan_room
    (and
        (>= (fe_slots_free) k_fe_spartan_size)
        (<= (+ (fe_spartans_alive) k_fe_spartan_size) k_fe_spartan_limit)
    )
)

; =====================================================================================================
;  9. GATING - ON SET, NOT ROUND, for the expensive items.
;     The author's own gates: the Warthog on Round 2, the MAC on (>= (survival_mode_set_get) 1).
;     Both opcodes exist in the U13 table: survival_mode_round_get 0x483, survival_mode_set_get 0x482.
; =====================================================================================================
(script static boolean fe_gate_round (short gate)
    (>= (survival_mode_round_get) gate)
)

(script static boolean fe_gate_set (short gate)
    (>= (survival_mode_set_get) gate)
)

; =====================================================================================================
;  10. ALLY DELIVERY.
;
;  ai_place takes ONE argument in this build (argc=1, opcode 0x1A7).  The two-argument partial
;  placement form the previous design relied on DOES NOT EXIST in ReachMCC_U13_Scripting.xml, so the
;  squad size is fixed by the cell (4 actors) and the cap is enforced by refusing the sale, not by
;  trimming it.  Four squads x 4 actors = 16 possible bodies; the cap of 8 is what binds.
;
;  Team is set at RUNTIME with ai_set_team (0x1E4), not by patching each squad's `team` field.  Stock
;  Holdout already declares the allegiance both ways in its own initialisation
;  (decompile L328-329: (ai_allegiance human player) (ai_allegiance player human)), so `human` is the
;  correct ally team on this map and no allegiance call of our own is needed.  One is issued anyway,
;  defensively, because it is idempotent.
;
;  THE BODIES ARE SPARTANS, NOT MARINES, IN BOTH TIERS.  No stock Firefight cache contains a marine
;  or ODST `char` tag - all eight were scanned (research/18 section 3.1).  The ally character is the
;  one palette entry no cell referenced, objects\characters\null\ai\null_cov_default (char tag 8107),
;  with its `unit` tag_reference datum repointed to objects\characters\spartans\spartans.  That is a
;  4-byte same-size patch, already applied and already proven to load in Blamite (research/19
;  section 3).  Allies will look like Spartans and sound like nothing, because a null character has no
;  dialogue.  The cheap tier is therefore called TROOPERS, not Marines: pretending otherwise would be
;  a lie in the one place a reader would believe it.  The two tiers differ by COUNT, RANK and
;  LOADOUT, which is all tag data:
;      troopers  4 bodies  major upgrade 3 'none'  DMR or assault rifle
;      Spartans  2 bodies  major upgrade 4 'all'   randomised heavy weapon + randomised ability
; =====================================================================================================
(script static void fe_squad_commit (ai squad)
    (ai_set_team squad human)
    (ai_allegiance human player)
    (ai_allegiance player human)
    (ai_set_task squad "obj_fireteams" "fireteams")
    (if g_fe_debug (print "fe: allies committed"))
)

; =====================================================================================================
;  10a. THE TROOPER TIER - DELIVERED BY DROP POD, AND THIS IS NOT DECORATION.
;
;  A BUG FOUND AND FIXED HERE, worth stating because the obvious implementation is wrong: a bare
;  (ai_place "sq_sur_drop_01") DOES NOT PUT ALLIES IN THE ARENA.  All four of that squad's spawn
;  points sit at (425.8-425.9, 105.9-108.4, 2.2) - outside the base, which is x 437-465, z -9..-3 -
;  and every one of them has `vehicle type` = cov_squad_drop_pod with a seat preference.  The actors
;  spawn strapped into a drop pod off the edge of the playable space and stay there.
;
;  The pod sequence below is what carries them in, and it is Bungie's own, copied call for call from
;  Holdout's drop_pod_01 (decompile L5525-5556): create the dm_drop_0N marker, place the squad, fetch
;  the pod vehicle from the squad's `driver` spawn point, attach pod to marker, drive the marker's
;  device position from 0 to 1 which flies the pod into the base, open the pod, unload it, fire the
;  stock impact effect, detach and destroy the marker.  Then and only then is the squad flipped to
;  team human.
;
;  Writing it out longhand rather than calling the stock script is deliberate: this file must compile
;  standalone, and the stock drop_pod_0N scripts also increment g_sur_drop_count and can switch
;  g_sur_drop_spawn off, which would interfere with the enemy-event disable in
;  ff70_holdout_stock_hooks.hsc.
;
;  Every object named is stock: dm_drop_01..04 are machines[0,27,28,29], placement flags 0x00000000,
;  i.e. present from map load; sq_sur_drop_0N/driver resolved as an ai_single_location against the
;  real cache; the effect path is the one the stock script uses.
; =====================================================================================================
(global vehicle v_fe_pod none)

(script static void fe_pod_01
    (object_create "dm_drop_01")
    (ai_place "sq_sur_drop_01")
    (sleep 1)
    (set v_fe_pod (ai_vehicle_get_from_spawn_point "sq_sur_drop_01/driver"))
    (sleep 1)
    (objects_attach "dm_drop_01" "" v_fe_pod "")
    (sleep 1)
    (device_set_position "dm_drop_01" 1)
    (sleep_until (>= (device_get_position "dm_drop_01") 0.85) 1)
    (unit_open v_fe_pod)
    (sleep 30)
    (vehicle_unload v_fe_pod none)
    (sleep_until (>= (device_get_position "dm_drop_01") 0.98) 1)
    (effect_new_on_object_marker
        "fx\fx_library\pod_impacts\default\pod_impact_default_large.effect"
        "dm_drop_01" "fx_impact")
    (sleep_until (>= (device_get_position "dm_drop_01") 1) 1)
    (sleep 1)
    (objects_detach "dm_drop_01" v_fe_pod)
    (object_destroy "dm_drop_01")
    (fe_squad_commit "sq_sur_drop_01")
)

(script static void fe_pod_02
    (object_create "dm_drop_02")
    (ai_place "sq_sur_drop_02")
    (sleep 1)
    (set v_fe_pod (ai_vehicle_get_from_spawn_point "sq_sur_drop_02/driver"))
    (sleep 1)
    (objects_attach "dm_drop_02" "" v_fe_pod "")
    (sleep 1)
    (device_set_position "dm_drop_02" 1)
    (sleep_until (>= (device_get_position "dm_drop_02") 0.85) 1)
    (unit_open v_fe_pod)
    (sleep 30)
    (vehicle_unload v_fe_pod none)
    (sleep_until (>= (device_get_position "dm_drop_02") 0.98) 1)
    (effect_new_on_object_marker
        "fx\fx_library\pod_impacts\default\pod_impact_default_large.effect"
        "dm_drop_02" "fx_impact")
    (sleep_until (>= (device_get_position "dm_drop_02") 1) 1)
    (sleep 1)
    (objects_detach "dm_drop_02" v_fe_pod)
    (object_destroy "dm_drop_02")
    (fe_squad_commit "sq_sur_drop_02")
)

(script static void fe_pod_03
    (object_create "dm_drop_03")
    (ai_place "sq_sur_drop_03")
    (sleep 1)
    (set v_fe_pod (ai_vehicle_get_from_spawn_point "sq_sur_drop_03/driver"))
    (sleep 1)
    (objects_attach "dm_drop_03" "" v_fe_pod "")
    (sleep 1)
    (device_set_position "dm_drop_03" 1)
    (sleep_until (>= (device_get_position "dm_drop_03") 0.85) 1)
    (unit_open v_fe_pod)
    (sleep 30)
    (vehicle_unload v_fe_pod none)
    (sleep_until (>= (device_get_position "dm_drop_03") 0.98) 1)
    (effect_new_on_object_marker
        "fx\fx_library\pod_impacts\default\pod_impact_default_large.effect"
        "dm_drop_03" "fx_impact")
    (sleep_until (>= (device_get_position "dm_drop_03") 1) 1)
    (sleep 1)
    (objects_detach "dm_drop_03" v_fe_pod)
    (object_destroy "dm_drop_03")
    (fe_squad_commit "sq_sur_drop_03")
)

(script static void fe_pod_04
    (object_create "dm_drop_04")
    (ai_place "sq_sur_drop_04")
    (sleep 1)
    (set v_fe_pod (ai_vehicle_get_from_spawn_point "sq_sur_drop_04/driver"))
    (sleep 1)
    (objects_attach "dm_drop_04" "" v_fe_pod "")
    (sleep 1)
    (device_set_position "dm_drop_04" 1)
    (sleep_until (>= (device_get_position "dm_drop_04") 0.85) 1)
    (unit_open v_fe_pod)
    (sleep 30)
    (vehicle_unload v_fe_pod none)
    (sleep_until (>= (device_get_position "dm_drop_04") 0.98) 1)
    (effect_new_on_object_marker
        "fx\fx_library\pod_impacts\default\pod_impact_default_large.effect"
        "dm_drop_04" "fx_impact")
    (sleep_until (>= (device_get_position "dm_drop_04") 1) 1)
    (sleep 1)
    (objects_detach "dm_drop_04" v_fe_pod)
    (object_destroy "dm_drop_04")
    (fe_squad_commit "sq_sur_drop_04")
)

; Round-robin across the four stock drop-pod squads so a second purchase does not try to re-place a
; squad that still has living members.  Re-placing an occupied squad is unproven behaviour; rotating
; avoids needing to know.  ai_place takes ONE argument in this build (argc=1, opcode 0x1A7) - the
; two-argument partial-placement form the previous design relied on DOES NOT EXIST in
; ReachMCC_U13_Scripting.xml - so the squad size is fixed by the cell at 4 and the cap is enforced by
; refusing the sale, not by trimming it.
(script static void fe_deliver_squad
    (cond
        ((= g_fe_rotor 0) (fe_pod_01))
        ((= g_fe_rotor 1) (fe_pod_02))
        ((= g_fe_rotor 2) (fe_pod_03))
        (true             (fe_pod_04))
    )
    (set g_fe_rotor (+ g_fe_rotor 1))
    (if (>= g_fe_rotor 4) (set g_fe_rotor 0))
    (set g_fe_buys (+ g_fe_buys 1))
)

; =====================================================================================================
;  10b. THE SPARTAN TIER.
;
;  Two Spartans per purchase, out of sur_fireteam_03 and sur_fireteam_04 alternately.  WHICH SLOTS
;  WERE FREE WAS CHECKED, NOT ASSUMED: ff70_holdout.stage2.map already carries added cells on
;  sur_fireteam_01 and sur_fireteam_02, so those two are taken; 03, 04, 05 and 06 all still read
;  0 designer cells / 0 templated cells / 0 spawn points.  This tier takes 03 and 04 and leaves 05
;  and 06 free for an ODST tier.
;
;  These squads need no drop pod, because the patch authors their spawn points directly - two per
;  squad, at (442.14, 116.34, -4.96) and (440.42, 123.55, -5.16).  Those two coordinates are not
;  invented: they are the exact positions of the placed scenery named spartan_respawn_00 and
;  spartan_respawn_04 (objects\multi\firefight\firefight_respawn_zone, scnr scenery[0] and [4]), so
;  they are guaranteed to be walkable player-spawnable floor inside the base.
;
;  Spartans arrive on foot and immediately in the fight, which is the point of the premium tier: no
;  30-tick pod ride before they do anything.
; =====================================================================================================
(script static void fe_deliver_spartans
    (cond
        ((= g_fe_spartan_rotor 0) (fe_squad_commit_placed "sur_fireteam_03"))
        (true                     (fe_squad_commit_placed "sur_fireteam_04"))
    )
    (set g_fe_spartan_rotor (+ g_fe_spartan_rotor 1))
    (if (>= g_fe_spartan_rotor 2) (set g_fe_spartan_rotor 0))
    (set g_fe_spartan_buys (+ g_fe_spartan_buys 1))
)

; Place-then-commit, for squads whose spawn points are already in the arena and need no vehicle.
(script static void fe_squad_commit_placed (ai squad)
    (ai_place squad)
    (sleep 1)
    (fe_squad_commit squad)
    (fe_blip (ai_get_object squad))
    (sleep 90)
    (fe_unblip (ai_get_object squad))
)

; Air support.  sq_sur_banshee_01/02 are the only squads in Holdout that carry a vehicle cell, and
; their pilot is null_cov_flying (palette 26) which is LEFT ALONE - it is not the repointed character,
; so the pilot stays a normal invisible null and the Banshee is not affected by the Spartan repoint.
(script static void fe_deliver_air
    (cond
        ((= g_fe_rotor 0) (fe_squad_commit "sq_sur_banshee_01"))
        (true             (fe_squad_commit "sq_sur_banshee_02"))
    )
)

; Retire every ally.  ai_survival_cleanup (0x6B5) is the call stock Holdout uses on its own groups at
; round end (decompile L640, L699).
(script static void fe_retire_allies
    (ai_survival_cleanup "gr_survival_fireteams" true true)
)

; =====================================================================================================
;  11. THE GENERIC KIOSK TRANSACTION.
;
;  One template, used by every station in the per-map file.  The shape is the author's: block until
;  something happens at the terminal, test affordability and identity together, charge the buyer,
;  deliver, then lock the station out for a cooldown.  The difference is the input: his was
;  (sleep_until (> (device_get_position "<name>") 0) 1) on a purpose-placed device_control, and this
;  is a dwell on a distance test, because no purpose-placed control exists and one cannot be created.
;
;  (device_get_position "health_pack0") does compile - health_pack0..5 are device_controls and the
;  compiler resolves them as device_name - but it is NOT used, because whether a health station's
;  position tracks the player's hold-to-use interaction is unverified, and a wrong guess there is a
;  shop that never opens.  A dwell on a distance test has no unknowns.
;
;  Returns true if the sale went through, so the caller can run its own delivery.
; =====================================================================================================
(script static boolean fe_transact (object kiosk, long cost)
    (if (fe_buyer_at kiosk cost)
        (begin
            (fe_charge_at kiosk cost)
            (fe_ok kiosk)
            true
        )
        (begin
            (if (fe_anyone_at kiosk) (fe_deny kiosk))
            false
        )
    )
)

; Wait until somebody has been standing at the kiosk for k_fe_dwell ticks.  Two sleeps: the first
; blocks until a player arrives, the second confirms they are still there, which filters out players
; merely running past.
(script static void fe_wait_at (object kiosk)
    (sleep_until (fe_anyone_at kiosk) 5)
    (sleep k_fe_dwell)
)

; =====================================================================================================
;  12. THE BANK.  The author's, unchanged in intent: 500 a press, one shared global, either player can
;      withdraw what the other deposited (research/14 section 6.6).  Collapsed onto ONE kiosk because
;      Holdout has six usable kiosks and six things worth selling: if you can pay, you deposit; if you
;      cannot and the bank holds something, you withdraw.
; =====================================================================================================
(script static void fe_bank_use (object kiosk)
    (cond
        ((fe_buyer_at kiosk k_fe_bank_step)
            (begin
                (fe_charge_at kiosk k_fe_bank_step)
                (set g_fe_bank (+ g_fe_bank k_fe_bank_step))
                (fe_ok kiosk)
                (if g_fe_debug (print "fe: deposit"))))
        ((>= g_fe_bank k_fe_bank_step)
            (begin
                (fe_credit_at kiosk k_fe_bank_step)
                (set g_fe_bank (- g_fe_bank k_fe_bank_step))
                (fe_ok kiosk)
                (if g_fe_debug (print "fe: withdraw"))))
        (true
            (fe_deny kiosk))
    )
)

; =====================================================================================================
;  13. THE WIN PURCHASE.
;
;  The author's 10,000-point MAC strike IS the win condition.  Holdout has no cannon-cruiser target
;  object, but it does place sc_poa - the UNSC Halcyon-class cruiser Pillar of Autumn, scenery[48],
;  placement flags 0x0, sitting off the map edge at (682, 250, 73).  So the ship doing the firing is
;  on screen already.
;
;  THIS FILE IS NOT COMPILED INTO ANY SHIPPED MAP (the Holdout build uses fe_shop_ctgl.hsc +
;  ff70_holdout.hsc).  It is corrected anyway so it cannot reintroduce BLOCKER-G1 if anyone builds
;  from it again.
;
;  (game_won) WAS WRONG AND IS GONE (audit 25, BLOCKER-G1).  It is a live opcode (0x442) in the U13
;  table, but being in the table says nothing about what it does inside a survival game, and Bungie's
;  Firefight never uses it to end a match: in every stock Firefight cache (game_won) appears exactly
;  once, as the entire body of a leftover CAMPAIGN script `end_mission` that nothing in Firefight
;  calls.  The old note here was wrong twice over: survival_spartans_increment_score and
;  event_survival_spartans_win_normal are not engine opcodes but SCENARIO SCRIPTS, and they ARE stock
;  Holdout scripts - both are declared, void and 0-arg, in Holdout's own script table, together with
;  the stock global b_survival_game_end_condition and the dormant stock script survival_end_game that
;  awaits it and then calls (mp_round_end_with_winning_team none).
; =====================================================================================================
(script static void fe_mission_won
    (if (and (not g_fe_won) (not b_survival_game_end_condition))
        (begin
            (set g_fe_won true)
            (fe_blip "sc_poa")
            (sleep 30)
            (ai_kill_no_statistics "gr_survival_all")
            (sleep 60)
            (fe_unblip "sc_poa")
            (survival_spartans_increment_score)
            (event_survival_spartans_win_normal)
            (submit_incident "survival_mm_game_complete")
            (set b_survival_game_end_condition true)
            (sleep 1800)
            (set g_fe_won false)
        )
    )
)

; =====================================================================================================
;  14. THE LONGSWORD PASS.
;
;  dm_longsword_01 is machines[4], a real longsword device_machine placed at (738, 15, 65) with
;  placement flag bit0 set, i.e. it must be created before use - which is exactly what stock Holdout
;  does (decompile L5737-5764: object_create, device_set_position_track "ff10",
;  device_animate_position, then object_destroy).  The same five calls are repeated here rather than
;  calling the stock script, so this file compiles standalone.
;
;  WE DO NOT DESTROY THE DEVICE (audit 25, RISK-G2): stock survival_resupply_pod_spawn polls
;  (sleep_until (>= (device_get_position "dm_longsword_01") 0.4) 1) on this same machine, and an
;  object_destroy inside that window stops all stock weapon and grenade drops for the rest of the
;  match.  Stock re-creates and re-animates the device at the head of every one of its own cycles.
; =====================================================================================================
(script static void fe_deliver_strike
    (object_create "dm_longsword_01")
    (device_set_position_track "dm_longsword_01" "ff10" 0)
    (device_animate_position "dm_longsword_01" 1 10 3 3 false)
    (sleep 90)
    (ai_kill_no_statistics "gr_survival_waves")
    (sleep 120)
)

; =====================================================================================================
;  15. AMMO RESUPPLY.  ammo_crate0/1 are equipment[0..1], ammo_box, placement flags 0x111, so they are
;      script-created - and stock Holdout creates them with the same call
;      (decompile L2804: (object_create_anew obj_ammo_crate0)).  object_create_anew takes object_name,
;      so the literal name is used directly instead of stock's device_name global.
; =====================================================================================================
(script static void fe_deliver_ammo
    (object_create_anew "ammo_crate0")
    (object_create_anew "ammo_crate1")
    (fe_blip "ammo_crate0")
    (sleep 90)
    (fe_unblip "ammo_crate0")
)

; =====================================================================================================
;  16. DIAGNOSTICS.  Debug only, and every call is behind g_fe_debug at the call site.
; =====================================================================================================
(script static void fe_report
    (if g_fe_debug (print "fe: report"))
)
