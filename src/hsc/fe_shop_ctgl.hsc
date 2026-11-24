; =====================================================================================================
;  fe_shop_ctgl.hsc  -  Firefight Evolved Expanded, map-neutral purchase + reinforcement library
;  WRITTEN 2026-11-23 for the Courtyard and Glacier ports.  ZERO NEW SCRIPT OBJECTS.
; =====================================================================================================
;
;  RELATION TO THE PROVEN REFERENCE
;  This file is src/hsc/fe_reinforcements.hsc (the Holdout library that compiled, wrote bytecode
;  through SaveScripts and re-loaded in Blamite) with every Holdout-specific name removed.  The
;  pricing, the cap, the charging mechanism, the proximity input, the feedback, the gating and the
;  transaction template are unchanged.  Four things differ, each for a reason read out of tag bytes:
;
;   1. ALLY BODIES ARE THE FIRETEAM SQUADS, NOT THE DROP SQUADS.
;      Holdout borrowed sq_sur_drop_01..04 because they were the only squads with a cell AND spawn
;      points, and it paid for that twice: it had to disable Bungie's own drop-pod event with two
;      global writes, and it inherited a collision it never resolved - stock survival_drop_spawn runs
;      (ai_erase "sq_sur_drop_01") .. ("sq_sur_drop_04") every cycle before it re-spawns them
;      (Holdout decompile L5486-5489; Courtyard decompile L5125-5128).  Those erases are not gated on
;      g_sur_drop_spawn or g_sur_drop_limit, so the Holdout build can silently delete allies the
;      player paid for.
;      The ports instead give sur_fireteam_01..04 their own spawn points as tag data, which is the
;      same primitive Holdout's own SPARTAN tier already used and proved
;      (tools/patch/holdout_fe_spartans.py).  Consequences: no stock script is touched at all, the
;      stock Covenant drop pods keep working as enemies where a map has them, and allies walk in
;      instead of riding a pod.
;
;   2. NO RE-PLACING AN OCCUPIED SQUAD.  fe_reinforcements rotated blindly across four squads and
;      said in its own comment that re-placing an occupied squad is "unproven behaviour".  With two
;      squads per tier that would happen on the third purchase, so this version refuses the sale
;      unless a squad in the tier is actually empty.  fe_has_room / fe_has_spartan_room now test
;      that, so the gate is checked BEFORE the charge, as everywhere else in this file.
;
;   3. fe_mission_won TAKES ITS BEACON AS AN ARGUMENT.  Holdout blipped sc_poa, the Pillar of Autumn
;      scenery it happens to place.  Neither Courtyard nor Glacier ships a cruiser, and inventing one
;      is a new object.  The per-map file passes the kiosk itself.
;
;   4. AIR SUPPORT AND THE ORBITAL/LONGSWORD PASS ARE NOT HERE.  Both depend on objects a map may not
;      have (sq_sur_banshee_*, dm_longsword_01), so they live in the per-map file, which is also
;      where the evidence that they exist is cited.
;
;  WHAT IS SHARED AND VERIFIED ON BOTH PORTED MAPS (read out of each map's own scnr, then proved by
;  compiling against that cache - a name that does not exist is a hard compile FAILURE here, not a
;  warning; see the negative control in research/23 section 3):
;      object_name    health_pack0..5         controls, placement flags 0x00000000
;      object_name    ammo_crate0, ammo_crate1 equipment, placement flags 0x00000101
;      ai_squad       sur_fireteam_01..05
;      ai_squad_group gr_survival_fireteams, gr_survival_all, gr_survival_waves
;      ai_objective   obj_fireteams, task `fireteams` (filter = that map's fireteam group, radius 3.0)
;      snd!           sound\game_sfx\ui\transition_beeps
;      snd!           sound\game_sfx\multiplayer\flag_failure
;      snd!           sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus
;
;  sur_fireteam_06 IS NEVER NAMED IN THIS FILE.  On Glacier it is squad 23, parented to
;  gr_survival_waves with flags 0x40 and a live cell shared with sq_sur_wave_01; touching it would
;  touch a Brute wave squad.  Nothing here references it, on any map.
;
;  print IS DELIBERATELY OFF THE CRITICAL PATH.  ReachMCC_U13_Scripting.xml marks opcode 0x028
;  null="true"; the engine will not run it.  Every print here is behind (if g_fe_debug ...).
; =====================================================================================================


; =====================================================================================================
;  1. PRICES - THE NAMED-CONSTANTS BLOCK.  RETUNE HERE, NOWHERE ELSE.
;
;  The author's real numbers, read out of ff_unearthed (research/14 section 6.2): marines 500 for four
;  bodies, turret 750, Warthog 1,000, hog upgrade 2,000, Scorpion 3,500, MAC 10,000.  Unchanged from
;  the Holdout build so the three maps price identically.
;
;  EXPECT THESE TO MOVE.  The author cut every launch price by 50-75% within 24 hours of release and
;  cut them again three weeks later (research/10 section 1.2).  Nothing below is sacred.
; =====================================================================================================
(global long k_fe_cost_squad      500)      ; [AUTHOR] buy_marines = 500 for four bodies = 125/body.
(global long k_fe_cost_spartan   1000)      ; SPARTAN TIER: 1,000 for TWO bodies = 500/body, 4x a
                                            ; trooper.  Half a round's measured income for two power
                                            ; units: a real trade, not a strict upgrade.
(global long k_fe_cost_ammo       500)      ; [AUTHOR] buy_ammo1 (light weapon rack) = 500.
(global long k_fe_cost_air       1000)      ; [AUTHOR] buy_hog rung = 1,000.  Courtyard only.
(global long k_fe_cost_strike    3000)      ; [AUTHOR] buy_turret3 / buy_tank rung = 3,500; 3,000 here
                                            ; because the pass is one-shot, not a persistent asset.
(global long k_fe_bank_step       500)      ; [AUTHOR] deposit/withdraw = 500 a press.
(global long k_fe_cost_win      10000)      ; [AUTHOR] buy_mac = 10,000 and IS the win condition.

; =====================================================================================================
;  2. TUNING
;
;  k_fe_actor_limit IS THE ONE NUMBER MOST LIKELY TO NEED CHANGING.  The author shipped 8 after
;  playtesting his own map; 12 is the USER'S choice and is what the Holdout build shipped.
;
;  ON THESE TWO MAPS 12 IS ALSO THE EXACT CEILING THE TAG DATA CAN REACH: two trooper squads of 4 and
;  two Spartan squads of 2 is 12 bodies and not one more, so the cap and the authored cells agree
;  instead of one silently binding the other.  Dropping to 10 or 8 is this one line.
;
;  Engine headroom caveat, unchanged and real: research/06 derives roughly 34 concurrent actors for
;  BOTH sides together, and the friendly budget comes out of the same pool as the Covenant spawner.
;  12 friendlies will show up as thinner enemy waves, not as an error.
; =====================================================================================================
(global short k_fe_actor_limit     12)      ; [USER] total living allies, troopers + Spartans together,
                                            ; counted with ai_living_count on the ally group.
                                            ; [AUTHOR's playtested value was 8.]
(global short k_fe_spartan_limit    4)      ; SPARTAN SUB-CAP: at most 4 alive, i.e. two purchases.
(global short k_fe_squad_size       4)      ; [AUTHOR] marine_rein delivers 4 bodies per purchase.
(global short k_fe_spartan_size     2)      ; two Spartans per purchase.
(global real  k_fe_kiosk_radius   2.5)      ; world units.  Bungie's own health-station proximity test
                                            ; uses 3.0; tightened so you must stand at the station.
(global short k_fe_dwell            8)      ; ticks the buyer must hold position.  30 ticks = 1 s.
(global short k_fe_cooldown       150)      ; 5 s anti-spam lock-out per station after a sale.
(global short k_fe_gate_spartan     1)      ; Spartans gated on SET >= 1.
(global short k_fe_gate_air         2)      ; [AUTHOR] "not available until Round 2".
(global short k_fe_gate_strike      1)      ; gate on SET, not round.
(global short k_fe_gate_win         1)      ; [AUTHOR] buy_mac waits on (>= (survival_mode_set_get) 1).

; =====================================================================================================
;  2a. THE SPARTAN LOADOUT POOLS ARE TAG DATA, NOT SCRIPT, AND ARE PER MAP.
;
;  weapon_palette_choice_block and equipment_palette_choice_block each hold up to 8 entries with a
;  `chance` weight at +0x0E, and the engine rolls per actor per spawn.  Randomisation therefore costs
;  no script at all.  The indices are scenario-palette indices and DIFFER BETWEEN MAPS, so they live
;  in tools/patch/shop_build.py, which reads each map's palette before it writes.  See research/23
;  section 5 for the per-map pools actually written.
;
;  THE HUMAN MACHINE-GUN TURRET IS NOT AVAILABLE AS A CARRIED WEAPON on any of these maps:
;  objects\vehicles\human\turrets\machinegun\machinegun is vehicle palette [1], a `vehi`, so a biped
;  cannot hold it and a cell's `initial weapon` cannot name it.
; =====================================================================================================

; =====================================================================================================
;  3. SOUNDS.  sfx_blip is NOT a built-in: stock declares it as a script global of type `sound` holding
;     a real tag path, identically in all ten shipped Firefight scripts, and both ported maps declare
;     it themselves - so OURS ARE PREFIXED sfx_fe_ to avoid a duplicate global when this file is
;     united with the map's own script.  All three tags were confirmed present as group snd! in both
;     ff20_courtyard and ff60_icecave (extracted/<map>/tags.tsv).
; =====================================================================================================
(global sound sfx_fe_blip "sound\game_sfx\ui\transition_beeps")
(global sound sfx_fe_buy "sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus")
(global sound sfx_fe_deny "sound\game_sfx\multiplayer\flag_failure")

; =====================================================================================================
;  4. STATE
; =====================================================================================================
(global boolean g_fe_debug      false)      ; (set g_fe_debug true) for print tracing. Never shipped on.
(global boolean g_fe_open       false)      ; the shop is live.  Set by the per-map startup script.
(global short   g_fe_air_rotor      0)      ; which air squad the next air purchase uses.
(global short   g_fe_spartan_buys   0)      ; successful Spartan purchases this match.
(global long    g_fe_bank           0)      ; shared bank: either player can withdraw what the other
                                            ; deposited, as in the author's build.
(global short   g_fe_buys           0)      ; successful trooper purchases this match.
(global boolean g_fe_won        false)      ; latch, so the win purchase can only fire once.

; =====================================================================================================
;  5. PRIMITIVES
;
;  fe_valid is Bungie's own validity guard, copied in shape from survival_health_pack_highlight: an
;  absent player slot yields object_get_health < 0.  There is no player_in_game_count in the U13
;  table, so this is the only guard available - and it is the one the shipped maps use, for all eight
;  slots unconditionally.
;
;  STRICTLY POSITIVE, NOT >= 0 (audit 29, RISK-R2).  object_get_health < 0 means "no such object", so
;  (>= ... 0) is an EXISTENCE test, not a liveness test: a player at exactly 0 health - dead, not yet
;  despawned - passed it, and a corpse lying inside a station's radius could still be charged by
;  fe_charge_at.  Bungie's own liveness boundary in these same caches puts 0 on the DEAD side:
;  f_blip_object_until_dead and f_blip_ai_until_dead - both present in all seven stock caches - wait
;  on (<= (object_get_health ...) 0) to mean dead.  So "alive" is (> ... 0), and that is what a buyer
;  has to be.  This is a predicate read out of stock, not one invented here.
; =====================================================================================================
(script static boolean fe_valid (unit who)
    (> (object_get_health who) 0)
)

; Proximity instead of a trigger volume.  Argument order matches Bungie's own call
; (objects_distance_to_object pack subject): first argument is object_list, second is object, and
; `player` -> `unit` -> `object` -> `object_list` all cast, which the compiler confirms.
;
; THE NEGATIVE-RETURN GUARD (audit 25, RISK-G3).  objects_distance_to_object returns a NEGATIVE
; value when the object list is empty or the named object is absent, and (< -1 radius) is true.
; Without the (>= ... 0) term an absent or destroyed anchor reports EVERY player as "near" it,
; wherever they are standing, and the station fires once per cooldown for anyone who can pay.  That
; exposure is highest on exactly these maps: three of Holdout's six anchors and two of Courtyard's
; are device_machine doors.  fe_valid already covers the player side; this covers the kiosk side.
; `and` short-circuits, so the second distance call is only evaluated once the first has proved the
; object is present.
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
;  The author's mechanism (research/14 section 6.1): affordability and buyer identity are tested
;  together in one `or` over all eight player slots, then a parallel `cond` over the same eight slots
;  fires exactly one negative award against whoever is standing at the kiosk.
;
;  player0 is NOT used: it does not exist in the U13 opcode table and it would charge the wrong
;  player.  human_player_in_game_get returns `player`, which is exactly the first argument type
;  campaign_metagame_award_points declares.
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
;  The cap is read off the ally squad group, exactly as the author does it, and
;  survival_wave_living_count is left COMPLETELY STOCK (research/14 section 6.4).  That works only
;  because the ally group sits outside gr_survival_all AND outside gr_survival_extras.
;
;  BOTH PORTED MAPS NEED THE REPARENT PATCH, FOR TWO DIFFERENT REASONS, AND NOTHING IN THIS FILE
;  COMPENSATES FOR EITHER.  Without it the shop is broken, not merely suboptimal:
;    Courtyard  gr_survival_fireteams (group 6) -> gr_survival_waves (5) -> gr_survival_all (0), so
;               stock survival_wave_living_count would count every ally as a live enemy and the round
;               would never end.  This is Holdout's problem exactly.
;    Glacier    gr_survival_fireteams (group 9) -> gr_survival_extras (1), which IS a root, so the
;               wave counter is fine - but stock survival_wave_end_conditions calls
;               (ai_survival_cleanup "gr_survival_extras" true true) at the end of EVERY wave
;               (decompile L622), which would delete every purchased ally each wave.  Research/20
;               concluded Glacier needed no reparent; that conclusion was about the wave count only.
;  Both fixes are the same 2-byte same-size write: set the group's own `parent` to -1.
;  tools/patch/shop_build.py applies it and research/23 section 4 records the offsets.
; =====================================================================================================
(script static short fe_allies_alive
    (ai_living_count "gr_survival_fireteams")
)

(script static short fe_slots_free
    (- k_fe_actor_limit (fe_allies_alive))
)

(script static boolean fe_squad_empty (ai squad)
    (<= (ai_living_count squad) 0)
)

; A tier can only sell if one of ITS squads is actually empty, because re-placing an occupied squad is
; unproven behaviour and this design refuses to rely on it.  Checked before the charge, like every
; other gate here, so a full field refuses the sale rather than taking the money.
(script static boolean fe_trooper_slot_free
    (or (fe_squad_empty "sur_fireteam_01") (fe_squad_empty "sur_fireteam_02"))
)

(script static boolean fe_has_room
    (and (>= (fe_slots_free) k_fe_squad_size) (fe_trooper_slot_free))
)

; THE SPARTAN SUB-CAP.  Spartans count against k_fe_actor_limit like everything else - both tiers are
; in gr_survival_fireteams, so fe_allies_alive already includes them - AND they additionally cannot
; exceed k_fe_spartan_limit between them.  Counted as the sum of the two Spartan squads rather than
; off a group, because there is no spare squad group to hold only the Spartans and the design refuses
; to invent one.
(script static short fe_spartans_alive
    (+ (ai_living_count "sur_fireteam_03") (ai_living_count "sur_fireteam_04"))
)

(script static boolean fe_spartan_slot_free
    (or (fe_squad_empty "sur_fireteam_03") (fe_squad_empty "sur_fireteam_04"))
)

(script static boolean fe_has_spartan_room
    (and
        (>= (fe_slots_free) k_fe_spartan_size)
        (and
            (<= (+ (fe_spartans_alive) k_fe_spartan_size) k_fe_spartan_limit)
            (fe_spartan_slot_free)
        )
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
;  10. ALLY DELIVERY - ON FOOT, FROM AUTHORED SPAWN POINTS.
;
;  Team is set at RUNTIME with ai_set_team (0x1E4), not by patching each squad's `team` field.  Both
;  ported maps declare the allegiance both ways in their own stock initialisation
;  ((ai_allegiance human player) (ai_allegiance player human)), so `human` is the correct ally team.
;  One pair is issued anyway, defensively, because the call is idempotent.
;
;  THE BODIES ARE SPARTANS, NOT MARINES, IN BOTH TIERS.  No stock Firefight cache contains a marine or
;  ODST `char` tag - all eight were scanned (research/18 section 3.1).  The ally character is the one
;  palette entry no cell referenced, objects\characters\null\ai\null_cov_default, with its `unit`
;  tag_reference datum repointed to objects\characters\spartans\spartans.  That is the 4-byte
;  same-size patch already in each .stage2.map and already proven to load in Blamite.  Allies look
;  like Spartans and say nothing, because a null character has no dialogue.  The cheap tier is
;  therefore called TROOPERS, not Marines: pretending otherwise would be a lie in the one place a
;  reader would believe it.  The two tiers differ by COUNT, RANK and LOADOUT, all tag data:
;      troopers  4 bodies  major upgrade 3 'none'  human rifle
;      Spartans  2 bodies  major upgrade 4 'all'   randomised heavy weapon + randomised ability
;
;  ai_place takes ONE argument in this build (argc=1, opcode 0x1A7).  The two-argument partial
;  placement form does not exist in ReachMCC_U13_Scripting.xml, so squad size is fixed by the cell and
;  the cap is enforced by refusing the sale, not by trimming it.
; =====================================================================================================
(script static void fe_squad_commit (ai squad)
    (ai_set_team squad human)
    (ai_allegiance human player)
    (ai_allegiance player human)
    (ai_set_task squad "obj_fireteams" "fireteams")
    (if g_fe_debug (print "fe: allies committed"))
)

; Place-then-commit, for squads whose spawn points are inside the arena and need no vehicle.
(script static void fe_squad_commit_placed (ai squad)
    (ai_place squad)
    (sleep 1)
    (fe_squad_commit squad)
    (fe_blip (ai_get_object squad))
    (sleep 90)
    (fe_unblip (ai_get_object squad))
)

(script static void fe_deliver_squad
    (cond
        ((fe_squad_empty "sur_fireteam_01") (fe_squad_commit_placed "sur_fireteam_01"))
        (true                               (fe_squad_commit_placed "sur_fireteam_02"))
    )
    (set g_fe_buys (+ g_fe_buys 1))
)

(script static void fe_deliver_spartans
    (cond
        ((fe_squad_empty "sur_fireteam_03") (fe_squad_commit_placed "sur_fireteam_03"))
        (true                               (fe_squad_commit_placed "sur_fireteam_04"))
    )
    (set g_fe_spartan_buys (+ g_fe_spartan_buys 1))
)

; Retire every ally.  ai_survival_cleanup (0x6B5) is the call both stock maps use on their own groups
; at round end.
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
;      withdraw what the other deposited (research/14 section 6.6).  Collapsed onto ONE kiosk: if you
;      can pay, you deposit; if you cannot and the bank holds something, you withdraw.
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
;  The author's 10,000-point MAC strike IS the win condition.
;
;  The beacon is an argument because Holdout's sc_poa cruiser does not exist on either ported map and
;  inventing one would be a new object.  The per-map file passes the kiosk, so the blip marks the
;  terminal the player just used.
;
;  (game_won) WAS WRONG AND IS GONE (audit 25, BLOCKER-G1).  It is a live opcode (0x442) in the U13
;  table, but being in the table says nothing about what it does inside a survival game, and Bungie's
;  Firefight never uses it to end a match: in every stock Firefight cache (game_won) appears exactly
;  once, as the entire body of a leftover CAMPAIGN script `end_mission` that nothing in Firefight
;  calls.  The note this file used to carry - that survival_spartans_increment_score and
;  event_survival_spartans_win_normal "are NOT in the U13 table (research/18 section 5)" - confused
;  two different namespaces.  They are not engine opcodes; they are SCENARIO SCRIPTS, and both are
;  declared in Courtyard's, Glacier's and Holdout's own script tables.  Each was verified present,
;  void and 0-arg in that map's own cache before this edit, as was the stock global
;  b_survival_game_end_condition and the dormant stock script survival_end_game that awaits it.
;
;  What replaces it is the real end-the-match path, which both oracles agree on:
;    * Bungie's own survival_mode_end_condition_complete - the "the players finished it" case - ends
;      with exactly these four calls, in this order;
;    * the author's playtested you_win, reached by (wake you_win) from his buy_mac, ends with the
;      last three of them.
;  Nothing here calls mp_round_end_with_winning_team directly: stock survival_end_game is woken once
;  by survival_mode at startup and then sits on (sleep_until b_survival_game_end_condition 1).
;  Setting that global is the documented way in, and survival_end_game then does the sleep_forever
;  sweep of the whole survival machine before ending the round - which our own call could not do.
;
;  THE LATCH IS NO LONGER PERMANENT (audit 25, follow-up 1).  g_fe_won used to be set true and never
;  cleared inside a session, so a win that failed or was interrupted locked the station out for the
;  rest of the match after the player had already paid 10,000.  It is now cleared 1800 ticks (60 s)
;  after the end condition is raised.  If the match ended, nothing is left to observe it; if the
;  match did NOT end, the station is live again and the player can retry - at full price, because
;  fe_transact charges at the kiosk, so there is no exploit in re-opening it.  The entry test also
;  refuses to start a second win sequence while an end condition is already pending.  fe_unblip is
;  called before the end condition is raised so the beacon is never left blipped on a kiosk.
; =====================================================================================================
(script static void fe_mission_won (object beacon)
    (if (and (not g_fe_won) (not b_survival_game_end_condition))
        (begin
            (set g_fe_won true)
            (fe_blip beacon)
            (sleep 30)
            (ai_kill_no_statistics "gr_survival_all")
            (sleep 60)
            (fe_unblip beacon)
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
;  14. AMMO RESUPPLY.  ammo_crate0/1 are equipment[0..1], ammo_box, placement flags 0x00000101, so
;      they are script-created - and both stock maps create them the same way
;      (object_create_anew on the ammo crate).  object_create_anew takes object_name, so the literal
;      name is used directly instead of stock's device_name global.
; =====================================================================================================
(script static void fe_deliver_ammo
    (object_create_anew "ammo_crate0")
    (object_create_anew "ammo_crate1")
    (fe_blip "ammo_crate0")
    (sleep 90)
    (fe_unblip "ammo_crate0")
)
