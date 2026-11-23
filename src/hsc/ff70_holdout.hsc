; =====================================================================================================
;  ff70_holdout   -   HOLDOUT, "PLATFORM DELTA"
;
;  TAG NAME -> FRIENDLY MAP NAME
;    scenario tag : levels\firefight\ff70_holdout\ff70_holdout
;    tag name     : ff70_holdout      <- what the engine, the scripts and the .map are named
;    map name     : Holdout           <- what the menu shows the player
;    Bungie's script: research/_raw/hsc/ff70_holdout.hsc - 1667 lines, 71 scripts, 32 globals, the
;    largest Firefight script Bungie shipped. Startup at L108-217.
;
;  Design source: research/05-map-scenario-designs.md section 5.4
;  Engine facts  : research/11-stock-map-spawn-geography.md section 9
;  Requires      : fe_reinforcements.hsc compiled BEFORE this file.
;
;  *** STARTUP SCRIPT COLLISION ***
;  ff70_holdout.hsc already declares (script startup ff70_holdout ...) at L108. Either delete the
;  declaration below and paste its body before the stock closing paren at L217 (preferred), or remove
;  the stock declaration and copy its whole configuration block (L113-215) into this one - including
;  (wake survival_banshee_spawn), (wake survival_drop_spawn), (wake survival_poa_control) and
;  (wake survival_rain_control), all of which this map needs.
;
;  WIN   buy LAUNCH CLEARANCE / EVAC SHUTTLE (8,000, not before round 5) AT THE EXPOSED TERMINAL IN
;        THE RIGHT DROP ZONE, then hold the lower helipad for 120 s while the shuttle lands.
;  LOSE  (a) life exhaustion, stock survival_mode_end_condition_lives;
;        (b) backstop: wave 16 completed with no clearance bought.
;
;  CATALOGUE  (prices retuned to the author's measured income, ~2,000-2,500 a round - see
;              fe_reinforcements.hsc section 1. [A] = his shipped price, [D] = derived on his ladder.)
;                                               cost   gate   script
;    Marine squad (3-4)                          500 [A]  -    ho_buy_marines   ps_gen defender anchors
;    ODST squad (4, 1 shotgun, 1 sniper)         750 [A]  -    ho_buy_odst      pod, beside ammo_crate0
;    Machinegun turret (rooftop or helipad)      750 [A]  -    ho_buy_turret
;    Anti-air battery (prioritises Banshees)   2,000 [D]  R3   ho_buy_aa        [G] see notes
;    Bank kiosk, deposit or withdraw             500 [A]  -    fe_bank_deposit / fe_bank_withdraw
;    LAUNCH CLEARANCE (win)                    8,000 [D]  R5   ho_buy_clearance EXPOSED TERMINAL
;
;  THE EXPOSED WIN TERMINAL - sq_sur_drop_04, in the right-hand drop zone
;  The author exiles Unearthed's MAC Cannon terminal to the Crane so the climax is a run through the
;  barrage (research/10 section 3.2). Holdout's economy lives in the three-level spawn building and on
;  the central platform; its exposure is the two flanking Covenant drop zones. So launch clearance is
;  bought DOWN IN THE RIGHT DROP ZONE, anchored on sq_sur_drop_04 - one of the four named Covenant pod
;  lanes, dm_drop_01 - dm_drop_04 / sq_sur_drop_01 - sq_sur_drop_04, all [V] in ff70_holdout.hsc - and
;  then the hold happens back on the lower helipad. It sits under the ps_banshee_02 strafing lane
;  (ps_banshee_02/p0 - p3 [V]), which is the barrage equivalent on this map.
;  Pick whichever of sq_sur_drop_01 - _04 reads farthest from ammo_crate0 and from ps_gen/gen0 - gen2
;  in Sapien, offset the volume clear of the pod's own landing footprint (research/10 build checklist
;  item 9), and do NOT put it on a ps_banshee flight-path point: those are air waypoints, not ground.
;  Named tag objects only. Do not invent a coordinate.
;
;  THE BANK  (new, from research/10 section 1.2)
;    tv_fe_bank_in / tv_fe_bank_out [NEW], 500 a press, beside ammo_crate0 - or at generator_switch0,
;    which sits at ps_gen/gen0 and is proven reachable and proven interactive on this map [V], and is
;    free to repurpose because this scenario's loss condition is the wave backstop, not generators.
;    Banked points leave the live score, so the 8,000 clearance survives a round of buying marines.
;    g_fe_bank must survive the set boundary; see fe_reinforcements.hsc section 6a.
;
;  =====================================================================================================
;  WHAT WAS REMOVED AND WHY
;  =====================================================================================================
;  THE FALCON GUNNER RIDE IS GONE (11,000). It was justified by "helipads make air delivery native to
;    the map [V]". The helipads are real geometry, but no map of the six references ANY UNSC aircraft,
;    and the only UNSC flight path in shipped Reach Firefight is ps_sur_pelican on cex_ff_halo, with
;    sq_sur_pelican and the command script cs_ff_halo_pelican. Holdout has none of them. A Falcon was
;    therefore a new object, a new AI pilot squad and a new flight path - on a SMALL multi-level map
;    where a tight orbit clips platform structure. Under the rule in fe_reinforcements.hsc section 2a
;    it is cut, not deferred.
;    NO GROUND VEHICLE WAS EVER SOLD HERE, and that was already correct: ff70_holdout.hsc names no
;    vehicle squad except the Banshees, so there is no chassis the stock scripts spawn and move on
;    the ground. [V]
;
;  THE "CENTRAL TURRET UPGRADE" IS GONE (3,000). It was sold as "upgrades stock map hardware".
;    ff70_holdout.hsc names no turret object. Its only map-unique scenery is sc_poa, the animated
;    Pillar of Autumn. [V] The claim had no referent, so the entry is deleted.
;
;  THE BANSHEE ESCALATION IS GONE from this file. Not because the names were wrong - the previous
;    sq_ho_banshee_01 / sq_ho_banshee_02 WERE invented and the real names are sq_sur_banshee_01 and
;    sq_sur_banshee_02 - but because Holdout ALREADY RUNS ITS OWN BANSHEE SPAWNER:
;        ff70_holdout.hsc L204   (wake survival_banshee_spawn)        ; ACTIVE, not commented
;        ff70_holdout.hsc L677   (ai_place sq_sur_banshee_01)         ; inside that spawner
;        ff70_holdout.hsc L678   (ai_place sq_sur_banshee_02)
;    gated on (<= (ai_task_count obj_survival/main_wave_gate) 10) and the four phantom booleans. [V]
;    A second thread calling ai_place on the same squads would race it. Holdout's Banshee hazard is
;    the richest in the game - real flight paths ps_banshee_01/p0-p2 and ps_banshee_02/p0-p3, command
;    scripts cs_banshee_01 / cs_banshee_02, and obj_survival tasks banshee_01 / banshee_02. Let it run.
;
;  WHAT REPLACED IT: the SNIPER hazard, which is authored on this map and shipped DORMANT.
;    sq_sur_sniper_01 - sq_sur_sniper_04 and gr_survival_snipers exist, survival_sniper_spawn is a
;    full dormant script at ff70_holdout.hsc L764-796, and its wake at L205 is COMMENTED OUT. [V]
;    So ho_escalation now simply wakes it. That is a verified one-line escalation using only stock
;    content - no new squads, no new paths, no hand-placing that could fight the spawner's own
;    (sleep_until (< (ai_living_count gr_survival_snipers) g_sur_sniper_limit)) gate at L784.
;
;  =====================================================================================================
;  GENERATOR DEFENCE IS GENUINELY AVAILABLE HERE - ONE OF ONLY TWO TARGET MAPS
;  =====================================================================================================
;  ff70_holdout.hsc has the point set ps_gen with points gen0 / gen1 / gen2, the command scripts
;  cs_gen0 / cs_gen1 / cs_gen2 at L251-270 that walk AI to them, and the AI tasks obj_survival/gen0 -
;  gen2 plus gen0_boost - gen2_boost gated on 3+ players. [V] Beachhead (ff50_park) is the only other
;  target map with that routing.
;  The shipped scenario design uses Generator Count 0 and a wave backstop instead, and that choice is
;  kept. But unlike Overlook, Outpost, Glacier and Waterfront, a generator loss condition HERE would
;  actually be driven by routed enemies, so it is a legitimate option if you want one. On those other
;  four it is decoration and has been removed.
;
;  =====================================================================================================
;  FRIENDLY AI PATHING IS THE KNOWN WEAK POINT HERE - AND HOLDOUT GIVES YOU THE ANSWER
;  =====================================================================================================
;  Ramps, helipads and an under-platform space are the worst case for Reach ally pathing, and stock
;  Installation 04's static tower ODSTs are documented as having no pathfinding at all (research/05
;  section 6 item 1). Holdout is also the ONLY target map where Bungie bothered to author
;  (cs_enable_pathfinding_failsafe TRUE) into a GROUND command script - cs_gen0 - cs_gen2. [V]
;  => Author the obj_marines/gate_marines_defenders task areas AT ps_gen/gen0, /gen1 and /gen2.
;     Bungie already proved AI can path to those three points on this map. It is the lowest-risk
;     friendly placement available anywhere in the six maps.
;  Bought Marines therefore defend; only the pod-delivered ODSTs follow a player.
;
;  =====================================================================================================
;  SCENARIO PREREQUISITES - author in Sapien. [NEW] = not in the stock tag. [V] = already there.
;  =====================================================================================================
;    squad group   gr_unsc_reinforcements      [NEW]
;        *** PARENTING WARNING ***  Child of NOTHING. Never gr_survival_all / _waves / _remaining
;        (waves never end - global_firefight.hsc L665-674), and NOT gr_survival_extras: Bungie's own
;        checklist parents gr_survival_marines there, and on Overlook, Waterfront and Courtyard that
;        group's living count gates the Covenant pod spawner. ff70_holdout.hsc does not reference
;        gr_survival_extras in script, but friendlies stay out of it on all six maps so the pack
;        behaves identically, and because gr_survival_extras is culled every wave by
;        (ai_survival_cleanup gr_survival_extras TRUE TRUE) - hsdoc_hr.txt L5153.
;        ALSO: never gr_survival_snipers. ff70_holdout.hsc L784 gates survival_sniper_spawn on that
;        group's living count, and ho_escalation wakes that spawner. [V]
;    squad group   gr_unsc_followers           [NEW]  child of gr_unsc_reinforcements
;    squads        sq_fe_garrison    [NEW]  team = human, **4 CELLS** - the FREE squad that
;                  arrives at match start and is topped back up to 4 at the start of every
;                  round. Cell count is a scenario tag field (the squad's cells block, per-cell
;                  'spawn count'); no script can change it. README.md section 2b0.
;                  sq_fe_marines     [NEW]  team = human, **8 CELLS** - the bought 500-point squad
;                  sq_fe_odst        [NEW]  team = human, **8 CELLS** - the bought 750-point squad
;                  sq_fe_gunner      [NEW]  team = human, 1 cell
;    objective     obj_marines                 [NEW]  tasks gate_marines, gate_marines_followers,
;                  gate_marines_defenders. Copied from cex_ff_halo. README section 2d.
;    point set     ps_gen  with points gen0, gen1, gen2          [V]  ff70_holdout.hsc L251-270
;                  USE THESE as the defender task areas. No new point set needed on this map.
;    anchors       ammo_crate0, ammo_crate1                      [V by convention]
;                  Global defaults on every Firefight map (global_firefight.hsc L54-55), created and
;                  HUD-tracked at L3177-3196. Terminal volumes and the friendly pod spawn point here.
;                  generator_switch0 - generator_switch2         [V]  device controls that sit at
;                  ps_gen/gen0 - gen2, so they are proven reachable AND proven interactive, and they
;                  are co-located with the defensible positions. Holdout's best terminal option if
;                  Generator Defense is off for this scenario (it is - Generator Count 0).
;    avoid         kill_sur_room_01 - kill_sur_room_08           [V]  the eight Covenant spawn rooms
;                  ps_banshee_01/p0 - p2, ps_banshee_02/p0 - p3  [V]  Banshee strafing lanes
;                  sq_sur_sniper_01 - _04 positions              [V]  enemy overwatch
;                  sq_sur_drop_01 - sq_sur_drop_04 spawn points   [V]  four Covenant pod lanes
;                  sc_poa                                        [V]  the animated Pillar of Autumn,
;                  (scenery_animation_start sc_poa ... any:thruster) at L245. Distant set dressing on
;                  a launch pad, almost certainly not walk-up-able. Do NOT build an interaction on it.
;    trigger vols  HOLDOUT HAS NO TRIGGER VOLUMES AT ALL. [V] Every tv_ below is new content and all
;                  must be POSTPROCESSED (saved and rebuilt) before volume_test_players works -
;                  hsdoc_hr.txt L216-217 requires it.
;                  tv_fe_board      [NEW] the terminal, at ammo_crate0 or generator_switch0
;                  tv_fe_helipad    [NEW] the lower helipad hold area for the win timer
;                  tv_fe_buy_marines tv_fe_buy_odst tv_fe_buy_turret tv_fe_buy_aa          [NEW]
;                  tv_fe_bank_in, tv_fe_bank_out   [NEW] the two bank kiosks, also at the terminal
;                  tv_fe_buy_clearance  [NEW] *** NOT at the terminal. *** Down in the right drop
;                    zone at sq_sur_drop_04. See the exposed-terminal note in the header.
;    device        dm_fe_pod_01     [NEW] friendly pod rail. The pattern is proven here -
;                  dm_drop_01 - dm_drop_04 and sq_sur_drop_01 - sq_sur_drop_04 all exist [V] - but a
;                  pod lands at the SQUAD'S tag spawn point, so a new rail and a new
;                  sq_fe_odst/driver point are required. Put it near ps_gen/gen0, which is the only
;                  safe-ish ground on this map with script evidence behind it.
;    objects       sc_fe_turret_01  [NEW] bought turret, "initially placed" off
;                  sc_fe_aa_battery [NEW] the anti-air battery
;                  sc_fe_shuttle    [NEW] the evac shuttle. Model its fly-in on cs_ff_halo_pelican,
;                                   cex_ff_halo_main.hsc L851-912 - the one working UNSC flight path
;                                   in shipped Reach Firefight. [V as a pattern]
; =====================================================================================================

(global boolean g_ho_clearance_bought FALSE)
(global boolean g_ho_turret_built     FALSE)
(global boolean g_ho_aa_built         FALSE)
(global boolean g_ho_snipers_live     FALSE)
(global short   g_ho_hold_left        120)
(global short   g_ho_last_wave        -2)
(global short   g_ho_gate_round        0)     ; last absolute round whose gate banner has been shown
(global vehicle v_fe_pod_01           NONE)

; =====================================================================================================
;  STARTUP - named for the scenario tag. See the collision warning in the header.
; =====================================================================================================
(script startup ff70_holdout
    ; ---------------- PASTE MARKER: START OF FE ADDITIONS -------------------------------------------
    (sleep 5)
    (set ai_fe_group     gr_unsc_reinforcements)
    (set ai_fe_followers gr_unsc_followers)
    (set ai_fe_garrison  sq_fe_garrison)
    (set ai_fe_marines   sq_fe_marines)
    (set ai_fe_odst      sq_fe_odst)
    (set ai_fe_gunner    sq_fe_gunner)


    ; FRIENDLY CAP: 8, below the pack default of 12, and the free garrison is cut to 4 with it.
    ; Holdout is the worst pathing case of the six and the project already says so twice:
    ;   research/05 5.4: "Friendly AI on a map with ramps, helipads and an under-platform space is the
    ;     worst case for Reach's ally pathing - stock Installation 04's four tower ODSTs are documented
    ;     as having no pathfinding at all, and the author's players complain allies stand out in the
    ;     open." Also: "Holdout is small, multi-level and ramp-linked."
    ;   research/11 section 8.x: Holdout is the ONLY target map where Bungie bothered to author
    ;     (cs_enable_pathfinding_failsafe TRUE) into its ground command scripts cs_gen0-cs_gen2. Bungie
    ;     needing a pathfinding failsafe here is the strongest evidence in the whole pack that this
    ;     map's ground paths jam.
    ; A ramp is a one-body-wide corridor to Reach's ally AI. Eight friendlies spread over the central
    ; platform and the ps_gen/genN points is already as much as the geometry takes; fourteen would
    ; queue on the ramps and never arrive.
    ; 8 = a 4-man garrison plus a full-width four-body purchase, or a bigger purchase once the garrison
    ; has taken casualties.
    (set k_fe_actor_limit 8)
    (set k_fe_free_squad_size 4)

    (wake fe_garrison_watch)        ; free garrison (4 here, not 6): match start + every round start
    (wake fe_slots_banner_watch)    ; "slots full" / "slots available" HUD edges
    (wake ho_mission_start)
    (wake ho_board)
    (wake ho_escalation)
    (wake ho_gates)
    (wake ho_backstop)
    ; ---------------- PASTE MARKER: END OF FE ADDITIONS ---------------------------------------------
)

; Trigger: reaching the terminal, or 45 s.
(script dormant ho_mission_start
    (sleep_until (volume_test_players tv_fe_board) 15 1350)
    (fe_board_open)
    (fe_notify "ho_board_online")
    (sound_impulse_start sfx_blip NONE 1)           ; ff20_courtyard.hsc L780 [V]
)

(script continuous ho_board
    (sleep_forever)
    (sleep_until
        (begin
            (player_action_test_reset)
            (sleep 5)
            (if (and g_fe_board_open (player_action_test_action))
                (begin
                    (if (volume_test_players tv_fe_buy_marines)   (ho_buy_marines))
                    (if (volume_test_players tv_fe_buy_odst)      (ho_buy_odst))
                    (if (volume_test_players tv_fe_buy_turret)    (ho_buy_turret))
                    (if (volume_test_players tv_fe_buy_aa)        (ho_buy_aa))
                    (if (volume_test_players tv_fe_buy_clearance) (ho_buy_clearance))
                    ; The two bank kiosks. Separate 1-second cooldown, because a bank is a repeat
                    ; interaction - fe_reinforcements.hsc section 6a.
                    (if (volume_test_players tv_fe_bank_in)       (fe_bank_deposit))
                    (if (volume_test_players tv_fe_bank_out)      (fe_bank_withdraw))
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
;  Anchored, never following: see the pathing note in the header.
;  Author obj_marines/gate_marines_defenders with its task areas at ps_gen/gen0, /gen1, /gen2 - the
;  only friendly positions on any target map that Bungie has already proven AI can path to. [V]
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void ho_buy_marines
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
            (fe_notify "ho_bought_marines")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  ODSTs - 750, ungated, drop pod. Holdout is one of the four target maps where the pod pattern exists:
;  dm_drop_01 - dm_drop_04 with sq_sur_drop_01 - sq_sur_drop_04 and drop_pod_01 - drop_pod_04. [V]
;  The sequence is Bungie's, ff20_courtyard.hsc L511-545. The two lines before fe_pod_sequence stay
;  inline because sq_fe_odst/driver must be a literal (stock does the same, ff20_courtyard.hsc L518).
;  Land it near ps_gen/gen0 - NOT on a Covenant pod site, which are enemy approach lanes by design.
;  These ODSTs FOLLOW the buyer via obj_marines/gate_marines_followers.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void ho_buy_odst
    (if (fe_try_buy_squad k_fe_cost_odst ai_fe_odst)
        (begin
            ; ONE POD, EIGHT MEN. The pod sequence below carries down whoever the HEV pod tag
            ; actually seats, which is a vehicle tag property this project has never verified - the
            ; existence of a UNSC/HEV pod tag in the stock Reach tag set is already [G] in
            ; fe_reinforcements.hsc section 10. If the pod seats fewer than k_fe_buy_squad_size, the
            ; surplus bodies are placed at sq_fe_odst's tag spawn point and simply do not ride down.
            ; Two honest fixes, pick one in Sapien: author a second rail dm_fe_pod_02 [NEW] and fire
            ; fe_pod_sequence twice, or switch this map's ODSTs to the walk-in delivery that Outpost
            ; and Glacier already use, which needs no pod at all.
            (object_create dm_fe_pod_01)
            (fe_place_up_to ai_fe_odst k_fe_buy_squad_size)
            (sleep 1)
            (set v_fe_pod_01 (ai_vehicle_get_from_spawn_point sq_fe_odst/driver))
            (sleep 1)
            (fe_pod_sequence dm_fe_pod_01 v_fe_pod_01)
            (fe_squad_arrive ai_fe_odst)
            (fe_squad_follow ai_fe_odst)                   ; obj_marines/gate_marines_followers
            (fe_blip_squad ai_fe_odst)
            (set g_fe_odst_buys (+ g_fe_odst_buys 1))
            (wake fe_odst_expiry)
            (fe_notify "ho_bought_odst")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  MACHINEGUN TURRET - 750, ungated, the author's own shipped turret price, which he never gated.
;  [G] vehicle_load_magic is real (hsdoc_hr.txt L1025) and cex_ff_halo_main.hsc L865-868 uses it to
;  load a Warthog into a Pelican, but no shipped script crews a turret with it. Ship it unmanned if
;  the gunner will not take the seat.
; ---------------------------------------------------------------------------------------------------
(script static void ho_buy_turret
    (if (and (not g_ho_turret_built) (fe_try_buy k_fe_cost_turret))
        (begin
            (object_create_anew sc_fe_turret_01)
            (ai_object_set_team sc_fe_turret_01 player)    ; global_firefight.hsc L1728 [V]
            (ai_place ai_fe_gunner)
            (sleep 1)
            (vehicle_load_magic sc_fe_turret_01 "" (ai_actors ai_fe_gunner))   ; [G]
            (set g_ho_turret_built TRUE)
            (fe_notify "ho_bought_turret")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  ANTI-AIR BATTERY - 2,000, round 3 gate. [DERIVED] Priced on the author's set-purchase rung (Gauss
;  upgrade 2,000, Fuel Rod Shade 2,000) - one round's income, one per set - and gated to Round 3 like
;  his own heavy unlocks. He never priced an AA emplacement for an exterior map.
;  *** THE ONE PRICE TO WATCH IN THIS PACK. *** His Corvette AA Shade is the loudest balance signal in
;  his whole changelog: 3,000 -> 6,000, doubled with no compensating buff plus an added overheat
;  penalty, because "a fixed emplacement that can hit everything on the map is the single most
;  overpowered purchase he shipped" (research/10 section 1.2). We still start at 2,000, because start-
;  cheap is the lesson; but if play shows this battery deletes the Banshee threat, this is the one item
;  to raise toward his punitive 6,000 rung - and give it his overheat, not a price rise alone.
;  The direct answer to Holdout's Banshee hazard, which is the richest in
;  the game here: real flight paths ps_banshee_01 and ps_banshee_02, command scripts cs_banshee_01 /
;  cs_banshee_02, obj_survival tasks banshee_01 / banshee_02, and a live spawner woken at L204. [V]
;  [G] "An auto turret that prioritises Banshees" is a TARGETING BIAS problem, and the primitives are
;  real but unused for this purpose by any shipped Firefight script:
;    (ai_object_set_targeting_bias <object> <real>)   used by stock on generators,
;                                                     global_firefight.hsc L1940 [V]
;    (ai_prefer_target_team <ai> <team>)              hsdoc, no Firefight usage
;  What is implemented: an ordinary turret, crewed, with its gunner squad told to prefer the covenant
;  team. If the bias does not steer it onto aircraft, ship it as a plain second turret and reprice to
;  750, the plain turret price - the purchase still works, it just is not AA-specific.
;  Keep it single-target and destructible, or it deletes the map's only air threat (research/05 5.4).
; ---------------------------------------------------------------------------------------------------
(script static void ho_buy_aa
    (if (and (not g_ho_aa_built)
             (fe_gate_open k_fe_gate_heavy)
             (fe_try_buy k_fe_cost_set_item))
        (begin
            (object_create_anew sc_fe_aa_battery)
            (ai_object_set_team sc_fe_aa_battery player)                           ; [V]
            (ai_place ai_fe_gunner)
            (sleep 1)
            (vehicle_load_magic sc_fe_aa_battery "" (ai_actors ai_fe_gunner))      ; [G]
            (ai_prefer_target_team ai_fe_gunner covenant)                          ; [G]
            (set g_ho_aa_built TRUE)
            (fe_notify "ho_bought_aa")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  WIN - LAUNCH CLEARANCE - 8,000, round 5 gate, then 120 s on the lower helipad.
;  Bought down in the right drop zone at sq_sur_drop_04, not at the board - see the header.
;  8,000 is four rounds of measured income (research/10 section 1.3), which is where the author's own
;  win gate lands his players. The old 30,000 is withdrawn: at 2,000-2,500 a round that was twelve
;  rounds of income, i.e. unreachable inside a 16-wave match.
; ---------------------------------------------------------------------------------------------------
(script static void ho_buy_clearance
    (if (and (not g_ho_clearance_bought) (fe_win_unlocked) (fe_try_buy k_fe_cost_win))
        (begin
            (set g_ho_clearance_bought TRUE)
            (fe_notify "ho_bought_clearance")
            (wake ho_win_hold)
        )
    )
)

; The per-second countdown inside a (sleep_until (begin (sleep ...) ...) 1) wrapper is Bungie's own
; loop idiom: ff20_courtyard.hsc L464-500, ff45_corvette_main.hsc L81-96. [V]
(script continuous ho_win_hold
    (sleep_forever)
    (set g_ho_hold_left 120)
    (object_create_anew sc_fe_shuttle)          ; [NEW] needs an object plus a command script
    (sleep_until
        (begin
            (sleep 30)                          ; 30 ticks = 1 second
            (if (volume_test_players tv_fe_helipad)
                (set g_ho_hold_left (- g_ho_hold_left 1))
            )
            (<= g_ho_hold_left 0)
        )
        1
    )
    (fe_mission_won)
)

; ---------------------------------------------------------------------------------------------------
;  ESCALATION - wake the map's own dormant sniper hazard from round 2.
;  This is the whole escalation now, and it is entirely stock content:
;    sq_sur_sniper_01 - sq_sur_sniper_04 and gr_survival_snipers exist in ff70_holdout.hsc,
;    survival_sniper_spawn is a full dormant script at L764-796 with its own player-count-scaled
;    limit (g_sur_sniper_limit 1 or 2) and its own living-count gate at L784,
;    and (wake survival_sniper_spawn) is COMMENTED OUT at L205. [V]
;  We do NOT ai_place the snipers by hand - that would fight the spawner's gate. We do NOT touch the
;  Banshees at all: ff70_holdout.hsc L204 already wakes survival_banshee_spawn, which calls
;  (ai_place sq_sur_banshee_01) / (ai_place sq_sur_banshee_02) itself at L677-678. [V]
;  The previous version's sq_ho_banshee_01 / sq_ho_banshee_02 were invented names AND a duplicate
;  spawner. Both problems are gone.
; ---------------------------------------------------------------------------------------------------
(script dormant ho_escalation
    (set g_ho_last_wave (survival_mode_wave_get))
    (sleep_until
        (begin
            (if (!= g_ho_last_wave (survival_mode_wave_get))
                (begin
                    (set g_ho_last_wave (survival_mode_wave_get))
                    (if (and (not g_ho_snipers_live) (>= (survival_mode_round_get) 1))
                        (begin
                            (wake survival_sniper_spawn)
                            (set g_ho_snipers_live TRUE)
                        )
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
;    R3  anti-air battery        R5  LAUNCH CLEARANCE, down in the right drop zone
;  fe_notify string ids are [G]; each needs a real string in the map's string tags, or use the stock
;  incident mechanism (fe_reinforcements.hsc section 11 b).
; ---------------------------------------------------------------------------------------------------
(script dormant ho_gates
    (sleep_until
        (begin
            (if (> (fe_round_index) g_ho_gate_round)
                (begin
                    (set g_ho_gate_round (fe_round_index))
                    (if (= g_ho_gate_round k_fe_gate_heavy)
                        (fe_notify "ho_gate_heavy")     ; "The anti-air battery is now available!"
                    )
                    (if (= g_ho_gate_round k_fe_win_round_gate)
                        (begin
                            (fe_notify "ho_gate_win")   ; "Launch clearance is now available - at the
                            (sound_impulse_start sfx_blip NONE 1)   ;  right landing zone."
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
;  LOSE BACKSTOP - wave 16 with no clearance bought. The only scripted loss here; the rest is stock
;  life exhaustion. s_survival_wave_complete_count is global_firefight.hsc L124. [V]
; ---------------------------------------------------------------------------------------------------
(script dormant ho_backstop
    (sleep_until (>= s_survival_wave_complete_count k_fe_wave_backstop) 30)
    (if (not g_ho_clearance_bought)
        (fe_mission_lost)
    )
)

; ---------------------------------------------------------------------------------------------------
;  TEST HARNESS - shape copied from ff20_courtyard.hsc L1253-1260 (test_squad_drop). [V]
; ---------------------------------------------------------------------------------------------------
(script static void test_fe_marines
    (fe_board_open)
    (set k_fe_cost_marines 0)
    (ho_buy_marines)
)

(script static void test_fe_odst
    (fe_board_open)
    (set k_fe_cost_odst 0)
    (ai_erase ai_fe_odst)
    (sleep 30)
    (ho_buy_odst)
)
