; =====================================================================================================
;  ff60_airview   -   OUTPOST, "TYRANT"
;
;  TAG NAME -> FRIENDLY MAP NAME
;    scenario tag : levels\firefight\ff60_airview\ff60_airview
;    tag name     : ff60_airview      <- what the engine, the scripts and the .map are named
;    map name     : Outpost           <- what the menu shows the player
;    Bungie's script: research/_raw/hsc/ff60_airview.hsc, 1365 lines, banner
;    "; ====== FF60 AIRVIEW FIREFIGHT SCIRPTS ===", startup at L16-126. The leanest of the six:
;    46 scripts, 16 globals, no drop pods, no trigger volumes, no point sets beyond the Phantoms.
;
;  Design source: research/05-map-scenario-designs.md section 5.3
;  Engine facts  : research/11-stock-map-spawn-geography.md section 8
;  Requires      : fe_reinforcements.hsc compiled BEFORE this file.
;
;  *** STARTUP SCRIPT COLLISION ***
;  ff60_airview.hsc already declares (script startup ff60_airview ...) at L16. Either delete the
;  declaration below and paste its body before the stock closing paren at L125 (preferred), or remove
;  the stock declaration and copy its whole configuration block (L19-123) into this one - including
;  (object_cannot_take_damage sc_bfg_default) and (object_cannot_take_damage sc_bfg_destroyed) at
;  L19-20, which this map needs at startup.
;
;  WIN   buy TYRANT FIRING SOLUTION (8,000, not before round 5) AT THE WRECKED CANNON, then man the
;        live cannon and destroy three Phantoms in 90 s - 60 s if the wrecked cannon was repaired first.
;  LOSE  (a) life exhaustion, stock survival_mode_end_condition_lives;
;        (b) backstop: wave 16 completed with the gun unfired.
;
;  CATALOGUE  (prices retuned to the author's measured income, ~2,000-2,500 a round - see
;              fe_reinforcements.hsc section 1. [A] = his shipped price, [D] = derived on his ladder.)
;                                               cost   gate   script
;    Marine squad (3-4)                          500 [A]  -    op_buy_marines    base first floor
;    ODST squad (4, 1 rocket)                    750 [A]  -    op_buy_odst       WALK-IN - see below
;    Machinegun turret (Base Front/Active Gun)   750 [A]  -    op_buy_turret
;    Ghost (player usable)                     1,000 [A]  R2   op_buy_ghost      verified map chassis
;    Repair the wrecked Tyrant cannon          2,000 [D]  R3   op_buy_repair     halves the firing timer
;    Bank kiosk, deposit or withdraw             500 [A]  -    fe_bank_deposit / fe_bank_withdraw
;    TYRANT FIRING SOLUTION (win)              8,000 [D]  R5   op_buy_firing_solution   AT THE WRECK
;
;  THE EXPOSED WIN TERMINAL - sc_bfg_destroyed
;  The author exiles Unearthed's MAC Cannon terminal to the Crane so the climax is a run through the
;  barrage (research/10 section 3.2). Outpost's equivalent is the best fiction fit of the six: the map
;  ships TWO named Tyrant cannons, sc_bfg_default (live) and sc_bfg_destroyed (wrecked), and Bungie
;  makes both invulnerable at ff60_airview.hsc L19-20 with (object_cannot_take_damage ...). [V]
;  So the firing solution is bought at the WRECK, on the far flank, out of the Deck's stair chokepoint
;  - and then carried back to the live gun to be used. Two trips across open glacial hillside with the
;  Ghost hazard and four live Jackal snipers on it. The host object cannot be destroyed, which is
;  exactly what you want under a terminal you are forced to reach.
;  Named tag objects only - sc_bfg_destroyed is script-named [V]; its position is [TAG], so read it in
;  Sapien and confirm the wreck is actually walk-up-able before committing. Fallback if it is not: the
;  sc_resupply_* position farthest from ammo_crate0 (nine of them exist here [V], all proven
;  player-reachable and already blip-able). Do not invent a coordinate.
;
;  THE BANK  (new, from research/10 section 1.2)
;    tv_fe_bank_in / tv_fe_bank_out [NEW], 500 a press, beside ammo_crate0 on the base first floor by
;    the health packs - which is where the author put his own kiosks on Installation 04, "next to the
;    health pack", i.e. on the route every player already walks. Banked points leave the live score, so
;    the 8,000 firing solution survives a round of buying marines. Must survive the set boundary.
;
;  =====================================================================================================
;  *** THE ODST DROP POD IS GONE. THIS MAP CANNOT DELIVER ONE. ***
;  =====================================================================================================
;  The previous version sold "ODST squad - drop pods onto Base Front - the engine already ships
;  drop-pod hazards [V]". That citation is true of Firefight in general and FALSE of this map.
;  ff60_airview.hsc contains:
;      NO dm_drop_*          (no pod rails)
;      NO sq_sur_drop_*      (no pod squads)
;      NO v_sur_drop_*       (no pod vehicle globals)
;      NO survival_drop_spawn wake, and no survival_drop_spawn script
;  Outpost ships ZERO drop-pod infrastructure. A pod here would be 100% new content: a new rail with
;  the invis_cov_squad_drop_pod tag, a new squad spawn point, a new drop_pod_NN continuous script and
;  the pod_impact effect reference.
;
;  DECISION TAKEN: changed to a WALK-IN arrival, i.e. a bare (ai_place ai_fe_odst) at a tag spawn
;  point beside ammo_crate0 - exactly the delivery Glacier already uses.
;  WHY walk-in and not a Pelican: a Pelican is MORE new content, not less. The only UNSC flight path
;  in shipped Reach Firefight is ps_sur_pelican on cex_ff_halo, with sq_sur_pelican and the command
;  script cs_ff_halo_pelican; none of the six target maps has any of them, and none references any
;  UNSC aircraft at all. Walk-in needs one thing that already works on every map - ai_place,
;  hsdoc_hr.txt L1277, called by every stock Firefight script - plus one new spawn point. It is the
;  cheapest honest delivery, and it is the lowest-risk line in the whole pack.
;  The fiction cost is small: Outpost is a ground installation with a single stairway, so troopers
;  arriving on foot through the base reads fine.
;
;  =====================================================================================================
;  OTHER THINGS REMOVED, AND WHY
;  =====================================================================================================
;  THE GENERATOR LOSS CONDITION IS GONE (it was "0, or 1 on the hard variant - fail on lose all").
;    ff60_airview.hsc assigns all twelve generator objects (L80-91) but has NO ps_gen point set, NO
;    cs_gen0/cs_gen1/cs_gen2 command scripts and NO obj_survival/gen0-gen2 AI tasks. Its obj_survival
;    task list is the minimal set: generator, hero_follow, main_follow, remaining. The Covenant have
;    only the generic "generator" task and no approach points, so generator-defence AI routing is NOT
;    AUTHORED here. Only Beachhead (ff50_park) and Holdout (ff70_holdout) have it. [V]
;    Set Generator Count 0 in the gametype for this scenario.
;
;  THE "ROOF TURRET UPGRADE" IS GONE. It was sold as "upgrades stock hardware". There is no stock
;    turret object on this map: the only map-unique scenery ff60_airview.hsc names is sc_bfg_default
;    and sc_bfg_destroyed. [V] The claim had no referent, so the entry is deleted rather than
;    silently turned into a second new turret.
;
;  =====================================================================================================
;  FRIENDLY AI IS CAPPED LOWER ON THIS MAP. The Deck is so dominant that a roof turret plus a full
;  friendly squad can stall the AI entirely (research/05 5.3). k_fe_actor_limit is lowered in startup,
;  and no turret anchor is offered on the roof.
;
;  =====================================================================================================
;  SCENARIO PREREQUISITES - author in Sapien. [NEW] = not in the stock tag. [V] = already there.
;  =====================================================================================================
;    squad group   gr_unsc_reinforcements      [NEW]
;        *** PARENTING WARNING ***  Child of NOTHING. Never gr_survival_all / _waves / _remaining
;        (waves never end - global_firefight.hsc L665-674), and NOT gr_survival_extras: Bungie's own
;        checklist parents gr_survival_marines there, and on Overlook, Waterfront and Courtyard that
;        group's living count is what gates the Covenant pod spawner. ff60_airview.hsc itself never
;        references gr_survival_extras, but friendlies stay out of it on all six maps so the pack
;        behaves identically everywhere, and because gr_survival_extras is culled every wave by
;        (ai_survival_cleanup gr_survival_extras TRUE TRUE) - hsdoc_hr.txt L5153, "cure isolation
;        death" plus deletion of inactive actors.
;        ALSO: do not parent friendlies under gr_survival_snipers. ff60_airview.hsc L748 gates
;        survival_sniper_spawn on (< (ai_living_count gr_survival_snipers) g_sur_sniper_limit). [V]
;    squad group   gr_unsc_followers           [NEW]  child of gr_unsc_reinforcements
;    squads        sq_fe_garrison    [NEW]  team = human, **4 CELLS** - the FREE squad that
;                  arrives at match start and is topped back up to 4 at the start of every
;                  round. Cell count is a scenario tag field (the squad's cells block, per-cell
;                  'spawn count'); no script can change it. README.md section 2b0.
;                  sq_fe_marines     [NEW]  team = human, **8 CELLS** - the bought 500-point squad
;                  sq_fe_odst        [NEW]  team = human, **8 CELLS** - the bought 750-point squad
;                  sq_fe_gunner      [NEW]  team = human, 1 cell
;                  sq_fe_odst needs NO vehicle on its cells here - walk-in, no pod.
;    objective     obj_marines                 [NEW]  tasks gate_marines, gate_marines_followers,
;                  gate_marines_defenders. Copied from cex_ff_halo. README section 2d.
;    point set     ps_fe_hold with points hold_01, hold_02, hold_03             [NEW]
;                  OUTPOST HAS NO ps_gen AND NO POINT SETS AT ALL beyond ps_sur_phantom_01 - _04 and
;                  ps_sur_bonus_phantom. [V] There is nothing to borrow; author this one.
;    anchors       ammo_crate0, ammo_crate1                      [V by convention]
;                  Global defaults on every Firefight map (global_firefight.hsc L54-55), created and
;                  HUD-tracked at L3177-3196. Terminal volumes and both friendly arrival spawn points
;                  go here. Read the positions out of the tag.
;                  sc_bfg_default                                [V]  ff60_airview.hsc L19
;                  The live "Tyrant" AA gun, explicitly made invulnerable at startup - Bungie treating
;                  it as permanent mission furniture. It is the map's focal point, so the ground
;                  around it is the de facto stronghold and a good second defender anchor. Its
;                  position is [TAG] - read it in Sapien.
;                  sc_resupply_01 - sc_resupply_09               [V]  nine Bungie-vetted, proven
;                  player-reachable delivery positions, already blip-able with
;                  (f_blip_object sc_resupply_01 blip_ordnance). A terminal can sit at one with no new
;                  geometry.
;                  NOTE health_pack0 - health_pack5 are in the authoring checklist but are referenced
;                  by NO per-map script, so the design's "spawns by the health packs" is [TAG] at
;                  best. Do not plan around them.
;    avoid         kill_sur_room_01 - kill_sur_room_08           [V]  the eight Covenant spawn rooms
;                  sq_sur_sniper_01 - sq_sur_sniper_04 positions [V]  the dominant overwatch firing
;                  positions, and they are enemy-owned
;    trigger vols  OUTPOST HAS NO TRIGGER VOLUMES AT ALL. [V] Every tv_ below is new content and all
;                  must be POSTPROCESSED (saved and rebuilt) before volume_test_players works -
;                  hsdoc_hr.txt L216-217 requires it.
;                  tv_fe_board      [NEW] the terminal, beside ammo_crate0
;                  tv_fe_gun        [NEW] the cannon seat area, for the fallback win
;                  tv_fe_buy_marines tv_fe_buy_odst tv_fe_buy_turret tv_fe_buy_ghost
;                  tv_fe_buy_repair                                                 [NEW]
;                  tv_fe_bank_in, tv_fe_bank_out   [NEW] the two bank kiosks, also at the terminal
;                  tv_fe_buy_solution  [NEW] *** NOT at the terminal. *** At sc_bfg_destroyed, the
;                    wrecked Tyrant on the far flank. See the exposed-terminal note in the header.
;    objects       sc_fe_turret_01  [NEW] bought turret, "initially placed" off
;                  sc_fe_ghost      [NEW] the bought Ghost, placed beside ammo_crate0
;                  sc_bfg_default   [V]   the live Tyrant cannon - ALREADY IN THE TAG
;                  sc_bfg_destroyed [V]   the wrecked Tyrant cannon - ALREADY IN THE TAG
;                  The previous version invented sc_op_cannon_live and sc_op_cannon_wreck for these
;                  two. They exist under the real names above; use them.
; =====================================================================================================

(global boolean g_op_solution_bought FALSE)
(global boolean g_op_cannon_repaired FALSE)
(global boolean g_op_turret_built    FALSE)
(global boolean g_op_ghost_built     FALSE)
(global short   g_op_fire_window     90)     ; seconds allowed for the firing sequence
(global short   g_op_phantoms_killed 0)
(global short   g_op_last_wave       -2)
(global short   g_op_gate_round       0)      ; last absolute round whose gate banner has been shown

; =====================================================================================================
;  STARTUP - named for the scenario tag. See the collision warning in the header.
; =====================================================================================================
(script startup ff60_airview
    ; ---------------- PASTE MARKER: START OF FE ADDITIONS -------------------------------------------
    (sleep 5)
    (set ai_fe_group     gr_unsc_reinforcements)
    (set ai_fe_followers gr_unsc_followers)
    (set ai_fe_garrison  sq_fe_garrison)
    (set ai_fe_marines   sq_fe_marines)
    (set ai_fe_odst      sq_fe_odst)
    (set ai_fe_gunner    sq_fe_gunner)


    ; FRIENDLY CAP: 6, the LOWEST in the pack, and the free garrison is cut to 4 with it.
    ; This map already carried the project's tightest budget before the spec changed, and the reason is
    ; recorded verbatim in research/05 5.3: "The Deck is so dominant that a purchased auto turret on
    ; the roof plus 6 friendly AI could stall the AI entirely. Cap friendly AI at 4 on this map and
    ; deny a roof turret anchor." The Deck is a single raised platform reached by stairs; it is the
    ; one position on Outpost worth holding, and it is small. Fourteen friendly bodies on it would
    ; physically block the stairhead, which is also the lane the Covenant must climb - the wave then
    ; cannot reach the players, cannot die, and the round reads as stalled.
    ; 6 = a 4-man garrison plus a two-body top-up purchase. The spec's 8-man squad is NEVER delivered
    ; in full on this map and that is deliberate.
    ; IF YOU ALSO ENABLE A DECK OR ROOF TURRET ANCHOR, drop this to 4, which is research/05's own
    ; number, and accept that purchases then only replace casualties.
    (set k_fe_actor_limit 6)
    (set k_fe_free_squad_size 4)

    (wake fe_garrison_watch)        ; free garrison (4 here, not 6): match start + every round start
    (wake fe_slots_banner_watch)    ; "slots full" / "slots available" HUD edges
    (wake op_mission_start)
    (wake op_board)
    (wake op_escalation)
    (wake op_gates)
    (wake op_backstop)
    ; ---------------- PASTE MARKER: END OF FE ADDITIONS ---------------------------------------------
)

; Trigger: reaching the terminal beside ammo_crate0, or 60 s.
(script dormant op_mission_start
    (sleep_until (volume_test_players tv_fe_board) 15 1800)
    (fe_board_open)
    (fe_notify "op_board_online")
    (sound_impulse_start sfx_blip NONE 1)           ; ff20_courtyard.hsc L780 [V]
)

(script continuous op_board
    (sleep_forever)
    (sleep_until
        (begin
            (player_action_test_reset)
            (sleep 5)
            (if (and g_fe_board_open (player_action_test_action))
                (begin
                    (if (volume_test_players tv_fe_buy_marines)  (op_buy_marines))
                    (if (volume_test_players tv_fe_buy_odst)     (op_buy_odst))
                    (if (volume_test_players tv_fe_buy_turret)   (op_buy_turret))
                    (if (volume_test_players tv_fe_buy_ghost)    (op_buy_ghost))
                    (if (volume_test_players tv_fe_buy_repair)   (op_buy_repair))
                    (if (volume_test_players tv_fe_buy_solution) (op_buy_firing_solution))
                    ; The two bank kiosks. Separate 1-second cooldown, because a bank is a repeat
                    ; interaction - fe_reinforcements.hsc section 6a.
                    (if (volume_test_players tv_fe_bank_in)      (fe_bank_deposit))
                    (if (volume_test_players tv_fe_bank_out)     (fe_bank_withdraw))
                )
            )
            FALSE
        )
        1
    )
)

; ---------------------------------------------------------------------------------------------------
;  MARINES - 500, ungated, re-buyable as soon as the last squad is gone - the author's own
;  post-playtest Marine price, a fifth of a round's income. Hold the single stairway: every enemy except Skirmishers and Rangers has to
;  climb it (research/05 5.3). Author the obj_marines/gate_marines_defenders task areas on the new
;  ps_fe_hold points, placed at the stairhead and around sc_bfg_default.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void op_buy_marines
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
            (fe_notify "op_bought_marines")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  ODSTs - 750, ungated. WALK-IN. NO POD. See the header: this map has zero pod infrastructure.
;  This is the single most reliable delivery in the pack: one ai_place at a tag spawn point beside
;  ammo_crate0, nothing else. ai_place is hsdoc_hr.txt L1277 and every stock Firefight script calls
;  it (ff20_courtyard.hsc L516, cex_ff_halo_main.hsc L127-129). [V]
;  These ODSTs FOLLOW the buyer via obj_marines/gate_marines_followers.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void op_buy_odst
    (if (fe_try_buy_squad k_fe_cost_odst ai_fe_odst)
        (begin
            (fe_place_up_to ai_fe_odst k_fe_buy_squad_size)
            (fe_squad_arrive ai_fe_odst)
            (fe_squad_follow ai_fe_odst)                   ; obj_marines/gate_marines_followers
            (fe_blip_squad ai_fe_odst)
            (set g_fe_odst_buys (+ g_fe_odst_buys 1))
            (wake fe_odst_expiry)
            (fe_notify "op_bought_odst")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  MACHINEGUN TURRET - 750, ungated, the author's own shipped turret price, which he never gated:
;  a turret is a fortification you buy on reflex at the position you are defending.
;  No roof anchor is offered, by design (see the header).
;  [G] vehicle_load_magic is real (hsdoc_hr.txt L1025) and cex_ff_halo_main.hsc L865-868 uses it to
;  load a Warthog into a Pelican, but no shipped script crews a turret with it. Ship it unmanned if
;  the gunner will not take the seat.
; ---------------------------------------------------------------------------------------------------
(script static void op_buy_turret
    (if (and (not g_op_turret_built) (fe_try_buy k_fe_cost_turret))
        (begin
            (object_create_anew sc_fe_turret_01)
            (ai_object_set_team sc_fe_turret_01 player)    ; global_firefight.hsc L1728 [V]
            (ai_place ai_fe_gunner)
            (sleep 1)
            (vehicle_load_magic sc_fe_turret_01 "" (ai_actors ai_fe_gunner))   ; [G]
            (set g_op_turret_built TRUE)
            (fe_notify "op_bought_turret")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  GHOST - 1,000, round 2 gate. Price and gate are both the author's, taken off his Rocket Warthog:
;  1,500->1,000 after playtest, "Warthog not available until Round 2" (research/10 section 1.1).
;  The only vehicle sold here, and the only one with real evidence on this map:
;  ff60_airview.hsc names sq_sur_ghost_01 and sq_sur_ghost_02 and the stock Phantoms deliver them, so
;  the engine demonstrably spawns and moves a Ghost chassis on Outpost. [V]
;  [G] That covers the Covenant squad's own spawn point, not yours. Place sc_fe_ghost beside
;  ammo_crate0 and drive it out before you ship.
;  NO WARTHOG AND NO SCORPION. research/05 5.3 was already right that selling wheeled or tracked
;  armour on unverified terrain is the biggest unforced risk in the dossier; the rule in
;  fe_reinforcements.hsc section 2a now makes that a hard rule across the pack.
; ---------------------------------------------------------------------------------------------------
(script static void op_buy_ghost
    (if (and (not g_op_ghost_built)
             (fe_gate_open k_fe_gate_vehicle)
             (fe_try_buy k_fe_cost_light_vehicle))
        (begin
            (object_create_anew sc_fe_ghost)
            (set g_op_ghost_built TRUE)
            (fe_notify "op_bought_ghost")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  REPAIR THE WRECKED TYRANT - 2,000, round 3 gate. Converts money into time: the firing window goes
;  90 s -> 60 s. [DERIVED] Priced on the author's set-purchase rung (his Gauss upgrade 2,000, Fuel Rod
;  Shade 2,000) - one round's income, one per set - and gated to Round 3 like his own heavy unlocks.
;  sc_bfg_destroyed is the REAL stock name for the wrecked gun (ff60_airview.hsc L20) and
;  sc_bfg_default is the live one (L19). Both are explicitly made invulnerable at startup with
;  (object_cannot_take_damage ...), which is Bungie treating them as permanent set dressing. [V]
;  [G] THEREFORE: a "repaired" variant of the wreck may not exist on the object tag, and the two
;  objects may not be interactive at all. object_create_variant itself is verified - stock swaps
;  ordnance variants with it using "laser" / "rocket" / "sniper" (ff20_courtyard.hsc L747-757) - but
;  the string "repaired" is a guess. If the tag has no such variant, delete this entry: the win still
;  works at 90 s, and the timer discount is a convenience, not a mechanic.
; ---------------------------------------------------------------------------------------------------
(script static void op_buy_repair
    (if (and (not g_op_cannon_repaired)
             (fe_gate_open k_fe_gate_heavy)
             (fe_try_buy k_fe_cost_set_item))
        (begin
            (object_create_variant sc_bfg_destroyed "repaired")   ; [G] variant string unverified
            (set g_op_cannon_repaired TRUE)
            (set g_op_fire_window 60)
            (fe_notify "op_bought_repair")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  WIN - TYRANT FIRING SOLUTION - 8,000, round 5 gate, bought AT sc_bfg_destroyed (see the header).
;  8,000 is four rounds of measured income (research/10 section 1.3), which is where the author's own
;  win gate lands his players. The old 30,000 is withdrawn: at 2,000-2,500 a round that was twelve
;  rounds of income, i.e. unreachable inside a 16-wave match.
; ---------------------------------------------------------------------------------------------------
(script static void op_buy_firing_solution
    (if (and (not g_op_solution_bought) (fe_win_unlocked) (fe_try_buy k_fe_cost_win))
        (begin
            (set g_op_solution_bought TRUE)
            (set g_op_phantoms_killed 0)
            (fe_notify "op_bought_solution")
            (wake op_firing_sequence)
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  WIN SEQUENCE - destroy three Phantoms from the cannon inside the firing window.
;
;  [G] THIS IS THE RISKIEST WIN CONDITION IN THE PACK, for two documented reasons:
;    1. Stock Firefight makes its Phantoms unkillable. ff60_airview.hsc runs
;       (object_cannot_die v_sur_phantom_01 TRUE) at L162, and the same for _02 at L327, _03 at L465,
;       _04 at L566 and v_sur_bonus_phantom at L680. [V] So the script below must first clear that
;       flag - (object_cannot_die <vehicle> FALSE), hsdoc_hr.txt L442 - and a destructible Firefight
;       Phantom is still unverified behaviour.
;    2. The source mod's own players report that scripted ship guns fling co-op players out of the
;       seat (research/05 section 6 item 3). Co-op test this before anything else.
;  v_sur_phantom_01 - v_sur_phantom_04 are real globals, declared in global_firefight.hsc L97-100, so
;  the references below resolve. [V]
;  A cheaper, safer alternative that keeps the fiction: make the win a 90 s hold at the gun instead of
;  three kills. That version is op_firing_hold at the bottom of this file and uses only verified calls.
; ---------------------------------------------------------------------------------------------------
(script continuous op_firing_sequence
    (sleep_forever)
    (object_cannot_die v_sur_phantom_01 FALSE)
    (object_cannot_die v_sur_phantom_02 FALSE)
    (object_cannot_die v_sur_phantom_03 FALSE)
    ; [G] the (if <cond> 1 0) arithmetic below relies on an if expression returning a number.
    ; Stock proves an if expression can return a boolean (global_firefight.hsc L3272-3287) but not a
    ; short. If the compiler objects, switch to op_firing_hold instead.
    (sleep_until
        (begin
            (sleep 30)
            (set g_op_fire_window (- g_op_fire_window 1))
            ; Count dead Phantoms. object_get_health returns -1 when the object is gone
            ; (hsdoc_hr.txt L378). [V]
            (set g_op_phantoms_killed
                (+ (if (<= (object_get_health v_sur_phantom_01) 0) 1 0)
                   (+ (if (<= (object_get_health v_sur_phantom_02) 0) 1 0)
                      (if (<= (object_get_health v_sur_phantom_03) 0) 1 0))))
            (or (>= g_op_phantoms_killed 3) (<= g_op_fire_window 0))
        )
        1
    )
    (if (>= g_op_phantoms_killed 3)
        (fe_mission_won)
        (begin
            ; Window missed. The convoy is not lost yet - the players can re-buy a solution.
            (set g_op_solution_bought FALSE)
            (fe_notify "op_window_missed")
        )
    )
)

; SAFE FALLBACK WIN, all verified calls. Delete op_firing_sequence's (wake ...) in
; op_buy_firing_solution and wake this instead if the destructible-Phantom work does not land.
(script continuous op_firing_hold
    (sleep_forever)
    (sleep_until
        (begin
            (sleep 30)
            (if (volume_test_players tv_fe_gun) (set g_op_fire_window (- g_op_fire_window 1)))
            (<= g_op_fire_window 0)
        )
        1
    )
    (fe_mission_won)
)

; ---------------------------------------------------------------------------------------------------
;  ESCALATION - Ghost hazard from round 2, second Ghost from round 3.
;  THE SQUAD NAMES ARE NOW THE REAL ONES, grepped out of ff60_airview.hsc:
;    sq_sur_ghost_01, sq_sur_ghost_02   [V]
;  The previous version invented sq_op_ghost_01 / sq_op_ghost_02, which exist nowhere.
;  Safe to ai_place these: ff60_airview.hsc's startup wakes only survival_mode and
;  survival_resupply_pod_spawn, and its only hazard spawner wake, (wake survival_jackal_spawn), is
;  COMMENTED OUT at L117. So nothing stock is already placing them and we are not racing a thread.
;  Contrast ff70_holdout, which does wake survival_banshee_spawn, and ff30_waterfront, which does
;  wake survival_sniper_spawn - on those two maps the equivalent ai_place has been removed.
;  We deliberately do NOT place sq_sur_sniper_01 - sq_sur_sniper_04 here: survival_sniper_spawn exists
;  in this file and is gated on gr_survival_snipers living count at L748, so hand-placing snipers
;  would fight that gate if the spawner is ever enabled.
; ---------------------------------------------------------------------------------------------------
(script dormant op_escalation
    (set g_op_last_wave (survival_mode_wave_get))
    (sleep_until
        (begin
            (if (!= g_op_last_wave (survival_mode_wave_get))
                (begin
                    (set g_op_last_wave (survival_mode_wave_get))
                    (if (>= (survival_mode_round_get) 1)
                        (if (<= (ai_living_count sq_sur_ghost_01) 0) (ai_place sq_sur_ghost_01))
                    )
                    (if (>= (survival_mode_round_get) 2)
                        (if (<= (ai_living_count sq_sur_ghost_02) 0) (ai_place sq_sur_ghost_02))
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
;    R2  Ghost        R3  repair the wrecked Tyrant        R5  TYRANT FIRING SOLUTION, at the wreck
;  fe_notify string ids are [G]; each needs a real string in the map's string tags, or use the stock
;  incident mechanism (fe_reinforcements.hsc section 11 b).
; ---------------------------------------------------------------------------------------------------
(script dormant op_gates
    (sleep_until
        (begin
            (if (> (fe_round_index) g_op_gate_round)
                (begin
                    (set g_op_gate_round (fe_round_index))
                    (if (= g_op_gate_round k_fe_gate_vehicle)
                        (fe_notify "op_gate_vehicle")   ; "The Ghost is now available!"
                    )
                    (if (= g_op_gate_round k_fe_gate_heavy)
                        (fe_notify "op_gate_heavy")     ; "The wrecked Tyrant can now be repaired!"
                    )
                    (if (= g_op_gate_round k_fe_win_round_gate)
                        (begin
                            (fe_notify "op_gate_win")   ; "The firing solution is now available - at
                            (sound_impulse_start sfx_blip NONE 1)   ;  the wrecked cannon."
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
;  LOSE BACKSTOP - wave 16 with the gun unfired. Now the only scripted loss on this map; the rest is
;  stock life exhaustion. s_survival_wave_complete_count is global_firefight.hsc L124. [V]
; ---------------------------------------------------------------------------------------------------
(script dormant op_backstop
    (sleep_until (>= s_survival_wave_complete_count k_fe_wave_backstop) 30)
    (if (not g_op_solution_bought)
        (fe_mission_lost)
    )
)

; ---------------------------------------------------------------------------------------------------
;  TEST HARNESS - shape copied from ff20_courtyard.hsc L1253-1260 (test_squad_drop). [V]
; ---------------------------------------------------------------------------------------------------
(script static void test_fe_marines
    (fe_board_open)
    (set k_fe_cost_marines 0)
    (op_buy_marines)
)

(script static void test_fe_odst
    (fe_board_open)
    (set k_fe_cost_odst 0)
    (ai_erase ai_fe_odst)
    (sleep 30)
    (op_buy_odst)
)
