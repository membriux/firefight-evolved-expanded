; =====================================================================================================
;  ff60_icecave   -   GLACIER, "BELOW BABD CATHA"
;
;  TAG NAME -> FRIENDLY MAP NAME
;    scenario tag : levels\firefight\ff60_icecave\ff60_icecave
;    tag name     : ff60_icecave      <- what the engine, the scripts and the .map are named
;    map name     : Glacier           <- what the menu shows the player
;    Bungie's script: research/_raw/hsc/ff60_icecave.hsc - 1111 lines, 30 scripts, 13 globals, the
;    SMALLEST Firefight script Bungie shipped. Banner "; ====== M60 ICE CAVE ===". Startup at L7-128.
;
;  Design source: research/05-map-scenario-designs.md section 5.5
;  Engine facts  : research/11-stock-map-spawn-geography.md section 10
;  Requires      : fe_reinforcements.hsc compiled BEFORE this file.
;
;  *** STARTUP SCRIPT COLLISION ***
;  ff60_icecave.hsc already declares (script startup ff60_icecave ...) at L7. Either delete the
;  declaration below and paste its body before the stock closing paren at L128 (preferred), or remove
;  the stock declaration and copy its whole configuration block (L11-126) into this one - including
;  (wake weapon_drop_control), which is Glacier's replacement for survival_resupply_pod_spawn.
;
;  =====================================================================================================
;  THE HARD CONSTRAINT: GLACIER IS UNDERGROUND, AND THE SCRIPT PROVES IT.
;  =====================================================================================================
;  ff60_icecave.hsc is the only Firefight script in the game with ZERO air-delivered objects:
;      NO dm_drop_*          (no Covenant pod rails)
;      NO sq_sur_drop_*      (no pod squads)
;      NO survival_drop_spawn
;      NO dm_resupply_*, NO sc_resupply_*      (no weapon drop pods)
;      NO dm_target_*, NO sc_target_*          (no Target Locator pods)
;      NO dm_longsword_01                      (nothing flies over)
;      NO survival_resupply_pod_spawn           - replaced by weapon_drop_control at L124
;  Instead it has three STATIC weapon holders, sc_weapon_01 / sc_weapon_02 / sc_weapon_03 in folder
;  sc_weapons, created with (object_create_folder_anew sc_weapons) at L1057 and blipped with
;  (f_blip_object sc_weapon_0N blip_ordnance). [V]
;  So: NO Pelican, NO Falcon, NO drop pod and NO orbital strike are sold here. That was already the
;  design's conclusion and the script confirms it outright.
;
;  WIN   buy DEMOLITION CHARGES (8,000, not before round 5) AT THE SHAFT, OUT ON THE WRAITH'S GROUND,
;        then survive 180 s - longer than any other scenario, because there is no air support to
;        shortcut the hold.
;  LOSE  (a) life exhaustion, stock survival_mode_end_condition_lives;
;        (b) backstop: wave 16 completed with no charges bought.
;
;  CATALOGUE  (prices retuned to the author's measured income, ~2,000-2,500 a round - see
;              fe_reinforcements.hsc section 1. [A] = his shipped price, [D] = derived on his ladder.)
;                                               cost   gate   script
;    Marine squad (3-4)                          500 [A]  -    gl_buy_marines    inside tv_wraith
;    ODST squad (4, 1 rocket, 1 shotgun)         750 [A]  -    gl_buy_odst       WALK-IN, no pod
;    Machinegun turret (awning or Rampart)       750 [A]  -    gl_buy_turret
;    Ghost (player usable)                     1,000 [A]  R2   gl_buy_ghost      verified map chassis
;    Bank kiosk, deposit or withdraw             500 [A]  -    fe_bank_deposit / fe_bank_withdraw
;    DEMOLITION CHARGES (win)                  8,000 [D]  R5   gl_buy_charges    EXPOSED TERMINAL
;
;  No strike and no air purchase here, by the hard constraint above - so Glacier's board is the second
;  shortest of the six, with one R2 gate and the win.
;
;  THE EXPOSED WIN TERMINAL - ps_wraith/p1, OUTSIDE tv_wraith
;  The author exiles Unearthed's MAC Cannon terminal to the Crane so the climax is a run through the
;  barrage (research/10 section 3.2). Glacier gives the BEST-EVIDENCED version of that on any of the
;  six maps, because Bungie labelled both the shelter and the exposure:
;    - tv_wraith is the shelter. ff60_icecave_fragments.hsc gates the wraith01 / wraith02 shoot tasks
;      on (not (volume_test_players tv_wraith)) [V] - the Wraiths STOP shelling while players are
;      inside it. That is why the routine economy and the Marine anchors sit in there.
;    - ps_wraith/p0 - p3 is the exposure. Those are the Wraith's own bombardment target points, driven
;      by (cs_shoot_point) at ff60_icecave.hsc L180-192. [V]
;  So the charge rig goes at whichever of ps_wraith/p0 - p3 reads farthest from ammo_crate0 and is
;  OUTSIDE tv_wraith - p1 is the placeholder name in this file. Fictionally that is the shaft the
;  Covenant came down, which is what the charges are being rigged on.
;  Named tag objects only. No coordinate for any of them exists in any public source - read them in
;  Sapien. Do not invent one.
;
;  THE BANK  (new, from research/10 section 1.2)
;    tv_fe_bank_in / tv_fe_bank_out [NEW], 500 a press, beside ammo_crate0 INSIDE tv_wraith, so the
;    repeat presses happen in the one volume the map's own script says is sheltered. Banked points
;    leave the live score, so the 8,000 charges survive a round of buying marines. Must survive the
;    set boundary; see fe_reinforcements.hsc section 6a.
;
;  =====================================================================================================
;  WHAT WAS REMOVED AND WHY
;  =====================================================================================================
;  THE ROCKET WARTHOG (7,000) AND THE SCORPION (12,000) ARE GONE.
;    The justification was "both Wraith and Ghost hazards are verified on Glacier, so vehicles do path
;    here". The Wraith half of that is wrong in a specific way: Glacier's Wraiths are sq_sur_wraith_01
;    and sq_sur_wraith_02 driven by (cs_shoot_point ps_wraith/p0-p3) in cs_wraith_shoot at L180-192 -
;    a STATIONARY bombardment command script that parks them and has them shell four fixed points.
;    [V] It proves the Wraith sits still. It proves nothing about drivable ground, and a Wraith hovers.
;    The Ghost half is better evidence, and it is kept: see the Ghost entry below.
;    Under the rule in fe_reinforcements.hsc section 2a - "sell only a chassis the map's own hazard
;    set already spawns and moves" - a hovering Ghost qualifies on this map and a wheeled Warthog or
;    a tracked Scorpion does not. "Snowy pathways separated by jagged rock" is exactly the geometry
;    where that distinction matters. Both entries are cut, not deferred.
;
;  THE GENERATOR LOSS CONDITION IS GONE (it was "Generator Count 2, survey power units, lose all").
;    ff60_icecave.hsc assigns all twelve generator objects (L93-104) but has NO ps_gen point set, NO
;    cs_gen0 / cs_gen1 / cs_gen2 command scripts and NO obj_survival/gen0 - gen2 AI tasks. Its
;    generator fragments are only the alive-flag conditions obj_sgen0_0_23 - obj_sgen2_0_25
;    (b_sur_generator0_alive etc.) - the Covenant have the generic "generator" task and no approach
;    points, so generator-defence AI ROUTING IS NOT AUTHORED HERE. [V]
;    Also: generator0 - generator2 are fixed device machines at fixed tag positions. They cannot be
;    moved or "dressed as survey power units"; they can only be counted and ordered.
;    Only Beachhead (ff50_park) and Holdout (ff70_holdout) have real generator routing.
;    Set Generator Count 0 in the gametype for this scenario. Loss is lives plus the wave backstop.
;
;  THE CAVERN-COLLAPSE EFFECT IS GONE from gl_win_hold. It called
;    (effect_new_on_object_marker <pod impact effect> sc_gl_turret_01 "fx_impact")
;    which (a) used the pod-impact effect as a stand-in, (b) fired it on a turret that may not exist
;    at that moment, and (c) named the marker "fx_impact", which belongs to a drop-pod RAIL
;    (ff20_courtyard.hsc L530), not to a turret. The win works without it. Add a real collapse effect
;    on a real marker if you author one.
;
;  =====================================================================================================
;  tv_wraith IS THE BEST SCRIPT-BACKED SAFE ZONE ON ANY OF THE SIX MAPS. USE IT.
;  =====================================================================================================
;  ff60_icecave_fragments.hsc opens with exactly this, twice:
;      (script static boolean obj_swrait_0_1  (not (volume_test_players tv_wraith)))
;      (script static boolean obj_swrait_0_2  (not (volume_test_players tv_wraith)))
;  Those two fragments are the task conditions on obj_survival/wraith01 and /wraith02. [V]
;  Read plainly: THE WRAITHS STOP SHELLING WHEN PLAYERS ARE INSIDE tv_wraith. That is Bungie's own
;  authored statement that this volume is sheltered ground. It is the only verified safe zone in the
;  pack - everywhere else we only have ammo_crate0 by convention and the kill volumes telling us
;  where NOT to go.
;  => Put the friendly arrival spawn points, the defender task areas and the purchase terminal INSIDE
;     tv_wraith. Read its bounds in Sapien; no coordinate for it exists in any public source.
;  Glacier's other trigger volume, tv_null, is a deliberate never-true wait used at L204 in
;  cs_wraith_lock as (sleep_until (volume_test_players tv_null)). Do not reuse it for anything.
;
;  =====================================================================================================
;  SCENARIO PREREQUISITES - author in Sapien. [NEW] = not in the stock tag. [V] = already there.
;  =====================================================================================================
;    squad group   gr_unsc_reinforcements      [NEW]
;        *** PARENTING WARNING ***  Child of NOTHING. Never gr_survival_all / _waves / _remaining
;        (waves never end - global_firefight.hsc L665-674), and NOT gr_survival_extras: Bungie's own
;        checklist parents gr_survival_marines there, and on Overlook, Waterfront and Courtyard that
;        group's living count gates the Covenant pod spawner. ff60_icecave.hsc has no pod spawner to
;        suppress, but friendlies stay out of gr_survival_extras on all six maps so the pack behaves
;        identically, and because gr_survival_extras is culled every wave by
;        (ai_survival_cleanup gr_survival_extras TRUE TRUE) - hsdoc_hr.txt L5153, "cure isolation
;        death" plus deletion of inactive actors. On a map this enclosed, that cull is a real risk.
;    squad group   gr_unsc_followers           [NEW]  child of gr_unsc_reinforcements
;    squads        sq_fe_garrison    [NEW]  team = human, **6 CELLS** - the FREE squad that
;                  arrives at match start and is topped back up to 6 at the start of every
;                  round. Cell count is a scenario tag field (the squad's cells block, per-cell
;                  'spawn count'); no script can change it. README.md section 2b0.
;                  sq_fe_marines     [NEW]  team = human, **8 CELLS** - the bought 500-point squad
;                  sq_fe_odst        [NEW]  team = human, **8 CELLS** - the bought 750-point squad
;                  sq_fe_gunner      [NEW]  team = human, 1 cell
;                  sq_fe_odst needs NO vehicle on its cells here - walk-in, no pod.
;    objective     obj_marines                 [NEW]  tasks gate_marines, gate_marines_followers,
;                  gate_marines_defenders. Copied from cex_ff_halo. README section 2d.
;                  Put the defender task areas INSIDE tv_wraith.
;    point set     ps_fe_hold with points hold_01, hold_02, hold_03             [NEW]
;                  GLACIER HAS NO ps_gen. Its only non-Phantom point set is ps_wraith, which is the
;                  Wraith's four firing points - the exact ground you must avoid. Author ps_fe_hold
;                  inside tv_wraith.
;    anchors       tv_wraith                                     [V]  ff60_icecave_fragments.hsc L1-5
;                  ammo_crate0, ammo_crate1                      [V by convention]
;                  Global defaults on every Firefight map (global_firefight.hsc L54-55), created and
;                  HUD-tracked at L3177-3196. Cross-check them against tv_wraith so the terminal is
;                  inside the sheltered volume.
;                  sc_weapon_01, sc_weapon_02, sc_weapon_03      [V]  ff60_icecave.hsc, folder
;                  sc_weapons. Three permanent, player-reachable, already-blipped positions. A second
;                  terminal can sit at one with no new geometry, and the blip machinery exists.
;                  Any "buy a weapon" purchase on Glacier must use this folder pattern
;                  (object_create_folder_anew sc_weapons) - the dm_resupply_* / sc_resupply_* pattern
;                  that works on the other five maps does not exist here at all.
;    avoid         kill_sur_room_01 - kill_sur_room_08           [V]  the eight Covenant spawn rooms
;                  ps_wraith/p0 - p3                             [V]  the Wraith's four firing points
;                  i.e. the open ground it is scripted to shell
;                  the base roof - jetpack-only and AI-proof (research/05 5.5). No turret anchor, no
;                  squad spawn point, no defender task area up there.
;    trigger vols  tv_wraith        [V]   ALREADY EXISTS. Use it.
;                  tv_null          [V]   exists, never true by design. Do not reuse.
;                  tv_fe_board      [NEW] the terminal, inside tv_wraith
;                  tv_fe_buy_marines tv_fe_buy_odst tv_fe_buy_turret tv_fe_buy_ghost     [NEW]
;                  tv_fe_bank_in, tv_fe_bank_out   [NEW] the two bank kiosks, also at the terminal
;                  tv_fe_buy_charges  [NEW] *** NOT at the terminal, and NOT inside tv_wraith. ***
;                    At ps_wraith/p1. See the exposed-terminal note in the header.
;                  All new volumes must be POSTPROCESSED (saved and rebuilt) before
;                  volume_test_players works - hsdoc_hr.txt L216-217 requires it.
;    objects       sc_fe_turret_01  [NEW] bought turret, "initially placed" off
;                  sc_fe_ghost      [NEW] the bought Ghost, placed inside tv_wraith
; =====================================================================================================

(global boolean g_gl_charges_bought  FALSE)
(global boolean g_gl_turret_built    FALSE)
(global boolean g_gl_ghost_built     FALSE)
(global short   g_gl_hold_left       180)
(global short   g_gl_last_wave       -2)
(global short   g_gl_gate_round       0)      ; last absolute round whose gate banner has been shown

; =====================================================================================================
;  STARTUP - named for the scenario tag. See the collision warning in the header.
; =====================================================================================================
(script startup ff60_icecave
    ; ---------------- PASTE MARKER: START OF FE ADDITIONS -------------------------------------------
    (sleep 5)
    (set ai_fe_group     gr_unsc_reinforcements)
    (set ai_fe_followers gr_unsc_followers)
    (set ai_fe_garrison  sq_fe_garrison)
    (set ai_fe_marines   sq_fe_marines)
    (set ai_fe_odst      sq_fe_odst)
    (set ai_fe_gunner    sq_fe_gunner)

    ; FRIENDLY CAP: 8, not the pack default of 12. Glacier is the lowest cap of the five outdoor-ish
    ; maps and it is lowered for two independent reasons, both already documented in this project:
    ;   1. 180 s of final hold with two Wraiths live is the heaviest simultaneous-AI moment in the
    ;      whole pack, and research/05 5.5 flags it by name: "may exceed the engine's comfortable
    ;      simultaneous-AI budget when combined with 6 friendly AI".
    ;   2. Pathing. This is an underground cave whose ground is described as "snowy pathways separated
    ;      by jagged rock pieces" (research/05 5.5), and the only sheltered anchor the script proves is
    ;      a single trigger volume, tv_wraith (research/11 7.x / the header above). Fourteen bodies
    ;      funnelling through one cave mouth into one volume is the classic ally traffic jam: they
    ;      block each other, block the player's firing lane, and block the doorway the Covenant must
    ;      use, which is the one thing that can make a wave look stalled when it is not.
    ; 8 = the free garrison of 6 plus a two-body top-up purchase. A purchase here lands a partial
    ; squad almost always. That is the correct trade on this map.
    (set k_fe_actor_limit 8)
    (set k_fe_free_squad_size 6)

    (wake fe_garrison_watch)        ; free 6-man garrison: match start + every round start
    (wake fe_slots_banner_watch)    ; "slots full" / "slots available" HUD edges
    (wake gl_mission_start)
    (wake gl_board)
    (wake gl_escalation)
    (wake gl_gates)
    (wake gl_backstop)
    ; ---------------- PASTE MARKER: END OF FE ADDITIONS ---------------------------------------------
)

; Trigger: reaching the terminal inside tv_wraith, or 60 s.
(script dormant gl_mission_start
    (sleep_until (volume_test_players tv_fe_board) 15 1800)
    (fe_board_open)
    (fe_notify "gl_board_online")
    (sound_impulse_start sfx_blip NONE 1)           ; ff20_courtyard.hsc L780 [V]
)

(script continuous gl_board
    (sleep_forever)
    (sleep_until
        (begin
            (player_action_test_reset)
            (sleep 5)
            (if (and g_fe_board_open (player_action_test_action))
                (begin
                    (if (volume_test_players tv_fe_buy_marines) (gl_buy_marines))
                    (if (volume_test_players tv_fe_buy_odst)    (gl_buy_odst))
                    (if (volume_test_players tv_fe_buy_turret)  (gl_buy_turret))
                    (if (volume_test_players tv_fe_buy_ghost)   (gl_buy_ghost))
                    (if (volume_test_players tv_fe_buy_charges) (gl_buy_charges))
                    ; The two bank kiosks. Separate 1-second cooldown, because a bank is a repeat
                    ; interaction - fe_reinforcements.hsc section 6a.
                    (if (volume_test_players tv_fe_bank_in)     (fe_bank_deposit))
                    (if (volume_test_players tv_fe_bank_out)    (fe_bank_withdraw))
                )
            )
            FALSE
        )
        1
    )
)

; ---------------------------------------------------------------------------------------------------
;  MARINES - 500, ungated, re-buyable as soon as the last squad is gone - the author's own
;  post-playtest Marine price, a fifth of a round's income.
;  Defenders, anchored inside tv_wraith, which is the only verified sheltered
;  ground in the pack. Author obj_marines/gate_marines_defenders with its task areas on the new
;  ps_fe_hold points, all placed inside that volume.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void gl_buy_marines
    (if (fe_try_buy_squad k_fe_cost_marines ai_fe_marines)
        (begin
            ; 8 cells, trimmed to the free slots under the concurrent cap.
            ; [V] opcode, [G] use - see fe_reinforcements.hsc section 8a.
            (fe_place_up_to ai_fe_marines k_fe_buy_squad_size)
            (fe_squad_arrive ai_fe_marines)
            (fe_squad_hold ai_fe_marines)                  ; obj_marines/gate_marines_defenders
            (fe_blip_squad ai_fe_marines)
            (set g_fe_marine_buys (+ g_fe_marine_buys 1))
            (wake fe_marines_expiry)
            (fe_notify "gl_bought_marines")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  ODSTs - 750, ungated. WALK-IN ONLY. No pod, no Pelican, no shaft drop - see the header constraint.
;  This is the simplest and most reliable delivery in the whole pack: one ai_place at a tag spawn
;  point inside tv_wraith, nothing else. ai_place is hsdoc_hr.txt L1277 and every stock Firefight
;  script calls it (ff20_courtyard.hsc L516, cex_ff_halo_main.hsc L127-129). [V]
;  These ODSTs FOLLOW the buyer via obj_marines/gate_marines_followers.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void gl_buy_odst
    (if (fe_try_buy_squad k_fe_cost_odst ai_fe_odst)
        (begin
            (fe_place_up_to ai_fe_odst k_fe_buy_squad_size)
            (fe_squad_arrive ai_fe_odst)
            (fe_squad_follow ai_fe_odst)                   ; obj_marines/gate_marines_followers
            (fe_blip_squad ai_fe_odst)
            (set g_fe_odst_buys (+ g_fe_odst_buys 1))
            (wake fe_odst_expiry)
            (fe_notify "gl_bought_odst")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  MACHINEGUN TURRET - 750, ungated, the author's own shipped turret price, which he never gated.
;  Base awning or Rampart only, never the roof.
;  [G] vehicle_load_magic is real (hsdoc_hr.txt L1025) and cex_ff_halo_main.hsc L865-868 uses it to
;  load a Warthog into a Pelican, but no shipped script crews a turret with it. Ship it unmanned if
;  the gunner will not take the seat.
; ---------------------------------------------------------------------------------------------------
(script static void gl_buy_turret
    (if (and (not g_gl_turret_built) (fe_try_buy k_fe_cost_turret))
        (begin
            (object_create_anew sc_fe_turret_01)
            (ai_object_set_team sc_fe_turret_01 player)    ; global_firefight.hsc L1728 [V]
            (ai_place ai_fe_gunner)
            (sleep 1)
            (vehicle_load_magic sc_fe_turret_01 "" (ai_actors ai_fe_gunner))   ; [G]
            (set g_gl_turret_built TRUE)
            (fe_notify "gl_bought_turret")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  GHOST - 1,000, round 2 gate. Price and gate are both the author's, taken off his Rocket Warthog:
;  1,500->1,000 after playtest, "Warthog not available until Round 2" (research/10 section 1.1).
;  The only vehicle sold here, and the one with real evidence on this map:
;  ff60_icecave.hsc names sq_sur_ghost_01 (one only, where Beachhead and Outpost have two), so the
;  engine spawns and moves a Ghost chassis in these caverns. [V]
;  [G] That covers the Covenant squad's own spawn point, not yours. Place sc_fe_ghost inside tv_wraith
;  and drive it out through the whole route before you ship it.
; ---------------------------------------------------------------------------------------------------
(script static void gl_buy_ghost
    (if (and (not g_gl_ghost_built)
             (fe_gate_open k_fe_gate_vehicle)
             (fe_try_buy k_fe_cost_light_vehicle))
        (begin
            (object_create_anew sc_fe_ghost)
            (set g_gl_ghost_built TRUE)
            (fe_notify "gl_bought_ghost")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  WIN - DEMOLITION CHARGES - 8,000, round 5 gate, then a 180 s pure-attrition hold.
;  Bought at ps_wraith/p1, out on the shelled ground, not at the sheltered board - see the header.
;  8,000 is four rounds of measured income (research/10 section 1.3), which is where the author's own
;  win gate lands his players. The old 30,000 is withdrawn: at 2,000-2,500 a round that was twelve
;  rounds of income, i.e. unreachable inside a 16-wave match.
;  The hold does NOT require standing in a volume: this is the one finale in the pack that is simply
;  "stay alive", which is what an underground map with no air support is for. If every player dies
;  and lives run out during the hold, stock survival_mode_end_condition_lives loses the match for
;  them (global_firefight.hsc L2482-2502). [V]
; ---------------------------------------------------------------------------------------------------
(script static void gl_buy_charges
    (if (and (not g_gl_charges_bought) (fe_win_unlocked) (fe_try_buy k_fe_cost_win))
        (begin
            (set g_gl_charges_bought TRUE)
            (fe_notify "gl_bought_charges")
            (wake gl_win_hold)
        )
    )
)

(script continuous gl_win_hold
    (sleep_forever)
    (set g_gl_hold_left 180)
    (sleep_until
        (begin
            (sleep 30)                                     ; 30 ticks = 1 second
            (set g_gl_hold_left (- g_gl_hold_left 1))
            (<= g_gl_hold_left 0)
        )
        1
    )
    (fe_mission_won)
)

; ---------------------------------------------------------------------------------------------------
;  ESCALATION - Ghost from round 2, Wraith from round 3, second Wraith in set 2.
;  THE SQUAD NAMES ARE NOW THE REAL ONES, grepped out of ff60_icecave.hsc:
;    sq_sur_ghost_01, sq_sur_wraith_01, sq_sur_wraith_02   [V]
;  The previous version invented sq_gl_ghost_01, sq_gl_wraith_01 and sq_gl_wraith_02, which exist
;  nowhere. Note there is only ONE Ghost squad on this map, unlike Beachhead and Outpost.
;  Safe to ai_place these: ff60_icecave.hsc's startup wakes only survival_mode and
;  weapon_drop_control - no hazard spawner at all. [V] And once placed they ARE directed: the map has
;  ps_wraith/p0 - p3, the command scripts cs_wraith_shoot and cs_wraith_lock at L180-204, and the AI
;  tasks obj_survival/wraith01, wraith02 and wraith02_advance, whose conditions are the tv_wraith
;  fragments. This is the best-routed vehicle hazard of the six maps.
; ---------------------------------------------------------------------------------------------------
(script dormant gl_escalation
    (set g_gl_last_wave (survival_mode_wave_get))
    (sleep_until
        (begin
            (if (!= g_gl_last_wave (survival_mode_wave_get))
                (begin
                    (set g_gl_last_wave (survival_mode_wave_get))
                    (if (>= (survival_mode_round_get) 1)
                        (if (<= (ai_living_count sq_sur_ghost_01) 0) (ai_place sq_sur_ghost_01))
                    )
                    (if (>= (survival_mode_round_get) 2)
                        (if (<= (ai_living_count sq_sur_wraith_01) 0) (ai_place sq_sur_wraith_01))
                    )
                    (if (>= (survival_mode_set_get) 1)
                        (if (<= (ai_living_count sq_sur_wraith_02) 0) (ai_place sq_sur_wraith_02))
                    )
                )
            )
            FALSE
        )
        1
    )
)

; ---------------------------------------------------------------------------------------------------
;  ROUND GATE BANNERS
;  The author's pacing device (research/10 section 1.2): each unlock is announced on the round boundary,
;  because an unannounced gate reads as a bug. His 0.1.6 note: "HUD messages for important events
;  (switches becoming available, Unearthed's MAC Cannon, Installation 04's Evac Pelican, etc) are now
;  implemented to make objectives more clear ingame."
;    R2  Ghost        R5  DEMOLITION CHARGES, out on the Wraith's ground
;  fe_notify string ids are [G]; each needs a real string in the map's string tags, or use the stock
;  incident mechanism (fe_reinforcements.hsc section 11 b).
; ---------------------------------------------------------------------------------------------------
(script dormant gl_gates
    (sleep_until
        (begin
            (if (> (fe_round_index) g_gl_gate_round)
                (begin
                    (set g_gl_gate_round (fe_round_index))
                    (if (= g_gl_gate_round k_fe_gate_vehicle)
                        (fe_notify "gl_gate_vehicle")   ; "The Ghost is now available!"
                    )
                    (if (= g_gl_gate_round k_fe_win_round_gate)
                        (begin
                            (fe_notify "gl_gate_win")   ; "The demolition charges can now be rigged -
                            (sound_impulse_start sfx_blip NONE 1)   ;  at the shaft."
                        )
                    )
                )
            )
            FALSE
        )
        30
    )
)

; ---------------------------------------------------------------------------------------------------
;  LOSE BACKSTOP - wave 16 with no charges bought. Now the only scripted loss on this map; the rest
;  is stock life exhaustion. s_survival_wave_complete_count is global_firefight.hsc L124. [V]
; ---------------------------------------------------------------------------------------------------
(script dormant gl_backstop
    (sleep_until (>= s_survival_wave_complete_count k_fe_wave_backstop) 30)
    (if (not g_gl_charges_bought)
        (fe_mission_lost)
    )
)

; ---------------------------------------------------------------------------------------------------
;  TEST HARNESS - shape copied from ff20_courtyard.hsc L1253-1260 (test_squad_drop). [V]
; ---------------------------------------------------------------------------------------------------
(script static void test_fe_marines
    (fe_board_open)
    (set k_fe_cost_marines 0)
    (gl_buy_marines)
)

(script static void test_fe_odst
    (fe_board_open)
    (set k_fe_cost_odst 0)
    (ai_erase ai_fe_odst)
    (sleep 30)
    (gl_buy_odst)
)
