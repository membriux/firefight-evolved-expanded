; =====================================================================================================
;  ff30_waterfront   -   WATERFRONT, "UTKOZET BLACKOUT"
;
;  TAG NAME -> FRIENDLY MAP NAME
;    scenario tag : levels\firefight\ff30_waterfront\ff30_waterfront
;    tag name     : ff30_waterfront   <- what the engine, the scripts and the .map are named
;    map name     : Waterfront        <- what the menu shows the player
;    Bungie's script: research/_raw/hsc/ff30_waterfront.hsc - 1354 lines, 59 scripts, 24 globals.
;    Banner "; ====== M30 WATERFRONT ===". Startup at L25-158.
;
;  Design source: research/05-map-scenario-designs.md section 5.6
;  Engine facts  : research/11-stock-map-spawn-geography.md section 11
;  Requires      : fe_reinforcements.hsc compiled BEFORE this file.
;
;  *** STARTUP SCRIPT COLLISION ***
;  ff30_waterfront.hsc already declares (script startup ff30_waterfront ...) at L25. Either delete the
;  declaration below and paste its body before the stock closing paren at L158 (preferred), or remove
;  the stock declaration and copy its whole configuration block (L29-156) into this one - including
;  (weather_animate_force off 1 0) at L144, (wake survival_sniper_spawn) at L151 and
;  (wake survival_drop_spawn) at L152.
;
;  WIN   buy STATION SCRAM & INTAKE DEMOLITION (8,000, or 6,000 while the sealed basin ramps hold; not
;        before round 5) AT THE EXPOSED TERMINAL DOWN IN THE BASINS, then hold the Pump house for 120 s.
;  LOSE  (a) life exhaustion, stock survival_mode_end_condition_lives;
;        (b) backstop: wave 16 completed with no scram bought.
;
;  CATALOGUE  (prices retuned to the author's measured income, ~2,000-2,500 a round - see
;              fe_reinforcements.hsc section 1. [A] = his shipped price, [D] = derived on his ladder.)
;                                               cost   gate   script
;    Marine squad (3-4)                          500 [A]  -    wf_buy_marines    inside the House
;    ODST squad (4, 1 sniper, 1 shotgun)         750 [A]  -    wf_buy_odst       WALK-IN, cov. bridge
;    Machinegun turret (Circle or bridge mouth)  750 [A]  -    wf_buy_turret
;    Seal the basin ramps (map state)          1,000 [A]  -    wf_buy_seal       unlocks the 6,000 win
;    Counter-sniper team (2 ODST marksmen)     1,000 [D]  -    wf_buy_snipers    House roof
;    One-shot artillery barrage on the basins  3,000 [D]  R3   wf_buy_barrage
;    Bank kiosk, deposit or withdraw             500 [A]  -    fe_bank_deposit / fe_bank_withdraw
;    STATION SCRAM (win)                 8,000/6,000 [D]  R5   wf_buy_scram      EXPOSED TERMINAL
;
;  THE EXPOSED WIN TERMINAL - the basins, at sq_sur_drop_03
;  The author exiles Unearthed's MAC Cannon to the Crane so the climax is a run through the barrage
;  (research/10 section 3.2). On Waterfront the map does the work: the Covenant are dropped into the
;  water basins below the ring and the player's whole economy lives up in the buildings. So the scram
;  terminal goes DOWN THE RAMPS into the basins, anchored on sq_sur_drop_03 - one of the five named
;  Covenant pod lanes, dm_drop_01 - dm_drop_05 / sq_sur_drop_01 - sq_sur_drop_05, all [V] in
;  ff30_waterfront.hsc. Named tag objects only; read the position in Sapien, offset the volume clear of
;  the pod's own landing footprint, and keep it well away from tv_cliff_fall_left and
;  tv_cliff_fall_right [V], which are the map's lethal drops. Pick whichever of sq_sur_drop_01 - _05
;  reads farthest from ammo_crate0. Do not invent a coordinate.
;  Note the interaction with "Seal the basin ramps": sealing two ramps makes the win run LONGER as
;  well as the win cheaper. That is a real trade-off and it is intended - verify a sealed ramp does not
;  make the terminal unreachable, or the discount becomes a trap.
;
;  THE BANK  (new, from research/10 section 1.2)
;    tv_fe_bank_in / tv_fe_bank_out [NEW], 500 a press, beside ammo_crate0 in the House. Banked points
;    leave the live score, so the 8,000 scram survives a round of buying marines and sniper teams.
;    g_fe_bank must survive the set boundary; see fe_reinforcements.hsc section 6a.
;
;  =====================================================================================================
;  *** THE gr_survival_extras TRAP IS LIVE ON THIS MAP, AND THIS IS THE WORST MAP TO GET IT WRONG ON.
;  =====================================================================================================
;  ff30_waterfront.hsc L534 and L556 are the Covenant drop-pod spawner, survival_drop_spawn, and both
;  of them block on that group reaching zero:
;      L534  (<= (ai_living_count gr_survival_extras) 0)                      ; pre-spawn gate
;      L556  (sleep_until (<= (ai_living_count gr_survival_extras) 0))        ; post-burst gate
;  The stock startup wakes that spawner at L152. Waterfront has FIVE pod sites, the joint most of any
;  target map, and they are a large part of what makes this scenario work. A single living friendly
;  marine parented under gr_survival_extras SUPPRESSES ALL FIVE for the rest of the match, silently,
;  with no error. Bungie's own authoring checklist parents gr_survival_marines under
;  gr_survival_extras. DO NOT. Friendly squads go in gr_unsc_reinforcements, child of nothing.
;  Second trap on this map: never parent friendlies under gr_survival_snipers either. L495 gates
;  survival_sniper_spawn on (< (ai_living_count gr_survival_snipers) g_sur_sniper_limit), and that
;  spawner IS woken at L151. [V]
;
;  =====================================================================================================
;  WHAT WAS REMOVED AND WHY
;  =====================================================================================================
;  THE LIGHT VEHICLE IS GONE (6,000, "Mongoose or Ghost, mobility only").
;    ff30_waterfront.hsc names NO vehicle squad except sq_sur_banshee_01 and sq_sur_banshee_02 - no
;    Ghost, no Wraith, nothing on the ground. [V] Under the rule in fe_reinforcements.hsc section 2a -
;    "sell only a chassis the map's own hazard set already spawns and moves" - Waterfront sells none.
;    The design doc was already right that this map's vehicle terrain is unverified and the
;    ring-of-buildings geometry argues against armour; the rule now makes that a hard constraint.
;    Note that even the Banshees here are thin evidence: Waterfront has sq_sur_banshee_01 / _02 but
;    NO ps_banshee_* point sets, unlike Holdout which has ps_banshee_01/p0-p2 and ps_banshee_02/p0-p3.
;    Waterfront's Banshees have no authored flight path. [V]
;
;  THE GENERATOR LOSS CONDITION IS GONE (it was "Generator Count 3, pump controllers, lose all three").
;    ff30_waterfront.hsc assigns all twelve generator objects (L114-125) but has NO ps_gen point set,
;    NO cs_gen0 / cs_gen1 / cs_gen2 command scripts and NO obj_survival/gen0 - gen2 AI tasks. Its
;    obj_survival task list is extras_gate, generator, hero_follow, main_follow, remaining. The
;    Covenant have only the generic "generator" task and no approach points, so generator-defence AI
;    ROUTING IS NOT AUTHORED HERE. [V]
;    Also: generator0 - generator2 are fixed device machines at fixed tag positions and cannot be
;    "dressed as pump controllers spread across the ring" - they can only be counted and ordered.
;    Only Beachhead (ff50_park) and Holdout (ff70_holdout) have real generator routing.
;    Set Generator Count 0 in the gametype for this scenario. Loss is lives plus the wave backstop.
;
;  THE HAND-PLACED SNIPER ESCALATION IS GONE. The previous version called
;    (ai_place sq_wf_jackal_snipers) - an invented squad name. The real names are sq_sur_sniper_01
;    through sq_sur_sniper_04 in group gr_survival_snipers [V] - but more importantly WATERFRONT
;    ALREADY RUNS ITS OWN SNIPER SPAWNER: ff30_waterfront.hsc L151 is (wake survival_sniper_spawn),
;    uncommented, and that dormant script at L473-495 sets its own player-count-scaled limit
;    (g_sur_sniper_limit 1 or 2), calls (ai_force_full_lod gr_survival_snipers) at L493 and gates on
;    the group's living count at L495. [V] A second thread placing those squads would race it.
;    The Jackal snipers on the hill are live from wave one, with no help from us.
;
;  WHAT REPLACED IT: the BANSHEE hazard, which is authored on this map and shipped DORMANT.
;    sq_sur_banshee_01 and sq_sur_banshee_02 exist, the spawner calls (ai_place sq_sur_banshee_01) and
;    (ai_place sq_sur_banshee_02) itself at L457-458, and (wake survival_banshee_spawn) at L150 is
;    COMMENTED OUT. [V] So wf_escalation now wakes it - a one-line escalation using only stock
;    content, with Bungie's own spawner doing the placing and gating.
;    [G] on behaviour only: as noted above, Waterfront's Banshees have no ps_banshee_* path, so where
;    they fly is not authored. Bungie shipped the spawner dormant; that may be exactly why.
;
;  =====================================================================================================
;  FRIENDLY AI PLACEMENT - THE HARDEST OF THE SIX MAPS
;  =====================================================================================================
;  Five drop-pod sites plus four Phantom corridors is the densest arrival geometry of any target map.
;  Anything standing in the Circle takes fire from every side, and the source mod's players already
;  report allies are too squishy and do not take cover (research/05 5.6). There is no "behind".
;  Waterfront also gives you the LEAST positive geography of the six: no ps_gen, no ps_wraith, no
;  ps_banshee, and its only two trigger volumes - tv_cliff_fall_left and tv_cliff_fall_right - are
;  cliff-fall guards for the ENEMY sniper squads, tested as
;      (volume_test_object tv_cliff_fall_left (ai_get_object sq_sur_sniper_01/sniper_01))
;  in ff30_waterfront_fragments.hsc. [V] They are not player shelter. They are still useful
;  NEGATIVELY: they tell you where the map's lethal drops are. No friendly squad, no arrival point and
;  no terminal anywhere near either one.
;  => ammo_crate0 / ammo_crate1 plus the eight kill volumes is all the script-backed geography there
;     is here. Anchor everything INSIDE buildings, which is why the Marines defend and the sniper team
;     sits under cover.
;
;  =====================================================================================================
;  SCENARIO PREREQUISITES - author in Sapien. [NEW] = not in the stock tag. [V] = already there.
;  =====================================================================================================
;    squad group   gr_unsc_reinforcements      [NEW]  *** child of NOTHING - see the trap above ***
;    squad group   gr_unsc_followers           [NEW]  child of gr_unsc_reinforcements
;    squads        sq_fe_garrison    [NEW]  team = human, **6 CELLS** - the FREE squad that
;                  arrives at match start and is topped back up to 6 at the start of every
;                  round. Cell count is a scenario tag field (the squad's cells block, per-cell
;                  'spawn count'); no script can change it. README.md section 2b0.
;                  sq_fe_marines     [NEW]  team = human, **8 CELLS** - the bought 500-point squad
;                  sq_fe_odst        [NEW]  team = human, **8 CELLS** - the bought 750-point squad
;                  sq_fe_gunner      [NEW]  team = human, 1 cell
;                  sq_fe_sniper_01   [NEW]  2 ODST cells with sniper rifles, team = human.
;                  Renamed from the previous sq_wf_snipers to match the real numbering convention -
;                  stock uses zero-padded two-digit squad numbers (sq_sur_sniper_01 - _04), and the
;                  fe_ namespace deliberately avoids _sur_, which marks the survival tree.
;    objective     obj_marines                 [NEW]  tasks gate_marines, gate_marines_followers,
;                  gate_marines_defenders. Copied from cex_ff_halo. README section 2d.
;    point set     ps_fe_hold with points hold_01, hold_02, hold_03             [NEW]
;                  WATERFRONT HAS NO ps_gen AND NO POINT SETS beyond ps_sur_phantom_01 - _04 and
;                  ps_sur_bonus_phantom. [V] Nothing to borrow; author this one, INSIDE buildings.
;    anchors       ammo_crate0, ammo_crate1                      [V by convention]
;                  Global defaults on every Firefight map (global_firefight.hsc L54-55), created and
;                  HUD-tracked at L3177-3196. Terminal volumes and both friendly arrival spawn points
;                  go here. Read the positions out of the tag.
;                  sc_resupply_01 - sc_resupply_09               [V]  nine proven player-reachable
;                  delivery positions, already blip-able with (f_blip_object ... blip_ordnance).
;    avoid         kill_sur_room_01 - kill_sur_room_08           [V]  the eight Covenant spawn rooms
;                  tv_cliff_fall_left, tv_cliff_fall_right       [V]  the map's lethal drops
;                  sq_sur_drop_01 - sq_sur_drop_05 spawn points  [V]  five Covenant pod lanes
;                  sq_sur_sniper_01 - _04 positions              [V]  live enemy overwatch from wave 1
;    trigger vols  tv_cliff_fall_left, tv_cliff_fall_right  [V] exist. Do not reuse; avoid.
;                  tv_fe_board      [NEW] the terminal, beside ammo_crate0
;                  tv_fe_pump       [NEW] the Pump house hold area for the win timer
;                  tv_fe_buy_marines tv_fe_buy_odst tv_fe_buy_seal tv_fe_buy_turret
;                  tv_fe_buy_snipers tv_fe_buy_barrage                                     [NEW]
;                  tv_fe_bank_in, tv_fe_bank_out   [NEW] the two bank kiosks, also at the terminal
;                  tv_fe_buy_scram  [NEW] *** NOT at the terminal. *** Down in the basins at
;                    sq_sur_drop_03. See the exposed-terminal note in the header.
;                  All new volumes must be POSTPROCESSED (saved and rebuilt) before
;                  volume_test_players works - hsdoc_hr.txt L216-217 requires it.
;    devices       dm_fe_ramp_01, dm_fe_ramp_02   [NEW] the two sealable basin ramps
;    objects       sc_fe_turret_01  [NEW] bought turret, "initially placed" off
;  OPTIONAL ALTERNATIVE DELIVERY, with real evidence: Waterfront is one of the four target maps where
;  the Covenant pod pattern exists - dm_drop_01 - dm_drop_05 with sq_sur_drop_01 - sq_sur_drop_05 and
;  drop_pod_01 - drop_pod_05 duplicated five times in the stock file. [V] If you prefer a pod ODST
;  delivery here, copy fe_pod_sequence from ff70_holdout.hsc in this pack and add a new rail
;  dm_fe_pod_01 plus a new sq_fe_odst/driver spawn point. The walk-in below is kept as the default
;  because the design wants the covered-bridge arrival and because ai_place needs no new device.
; =====================================================================================================

(global boolean g_wf_scram_bought   FALSE)
(global boolean g_wf_ramps_sealed   FALSE)
(global boolean g_wf_turret_built   FALSE)
(global boolean g_wf_snipers_bought FALSE)
(global boolean g_wf_barrage_used   FALSE)
(global boolean g_wf_banshees_live  FALSE)
(global short   g_wf_hold_left      120)
(global short   g_wf_last_wave      -2)
(global short   g_wf_gate_round      0)       ; last absolute round whose gate banner has been shown

; =====================================================================================================
;  STARTUP - named for the scenario tag. See the collision warning in the header.
; =====================================================================================================
(script startup ff30_waterfront
    ; ---------------- PASTE MARKER: START OF FE ADDITIONS -------------------------------------------
    (sleep 5)
    (set ai_fe_group     gr_unsc_reinforcements)
    (set ai_fe_followers gr_unsc_followers)
    (set ai_fe_garrison  sq_fe_garrison)
    (set ai_fe_marines   sq_fe_marines)
    (set ai_fe_odst      sq_fe_odst)
    (set ai_fe_gunner    sq_fe_gunner)


    ; FRIENDLY CAP: 10, below the pack default of 12. Not a pathing call - the ring is wide - but a
    ; total-population call. Waterfront has the densest arrival geometry of any target map: five
    ; Covenant pod sites plus four Phantom corridors plus sq_sur_sniper_01-04 plus two Banshees
    ; (research/11 section 5 table), so the HOSTILE half of the shared actor pool is already the
    ; heaviest of the six before a friendly is placed. Ten leaves the enemy spawner more room than
    ; twelve would. The sniper pair bought at wf_buy_snipers counts against this same 10, because it
    ; lives in gr_unsc_reinforcements like everything else.
    ; Second, independent reason to keep it low: research/05 5.6 records that friendlies in the ring
    ; "will take fire from every side" and that the source mod's players already report allies are
    ; "way too squishy". A bigger friendly squad here dies faster, it does not last longer.
    ; THE DROP-POD TRAP ALSO APPLIES ON THIS MAP: ff30_waterfront.hsc L534 and L556 gate the Covenant
    ; pod spawner on (<= (ai_living_count gr_survival_extras) 0). Friendlies must be children of
    ; gr_unsc_reinforcements, never of gr_survival_extras.
    (set k_fe_actor_limit 10)
    (set k_fe_free_squad_size 6)

    (wake fe_garrison_watch)        ; free 6-man garrison: match start + every round start
    (wake fe_slots_banner_watch)    ; "slots full" / "slots available" HUD edges
    (wake wf_mission_start)
    (wake wf_board)
    (wake wf_escalation)
    (wake wf_gates)
    (wake wf_backstop)
    ; ---------------- PASTE MARKER: END OF FE ADDITIONS ---------------------------------------------
)

; Trigger: reaching the terminal beside ammo_crate0, or 45 s.
(script dormant wf_mission_start
    (sleep_until (volume_test_players tv_fe_board) 15 1350)
    (fe_board_open)
    (fe_notify "wf_board_online")
    (sound_impulse_start sfx_blip NONE 1)           ; ff20_courtyard.hsc L780 [V]
)

(script continuous wf_board
    (sleep_forever)
    (sleep_until
        (begin
            (player_action_test_reset)
            (sleep 5)
            (if (and g_fe_board_open (player_action_test_action))
                (begin
                    (if (volume_test_players tv_fe_buy_marines) (wf_buy_marines))
                    (if (volume_test_players tv_fe_buy_odst)    (wf_buy_odst))
                    (if (volume_test_players tv_fe_buy_seal)    (wf_buy_seal))
                    (if (volume_test_players tv_fe_buy_turret)  (wf_buy_turret))
                    (if (volume_test_players tv_fe_buy_snipers) (wf_buy_snipers))
                    (if (volume_test_players tv_fe_buy_barrage) (wf_buy_barrage))
                    (if (volume_test_players tv_fe_buy_scram)   (wf_buy_scram))
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
;  MARINES - 500, ungated, re-buyable as soon as the last squad is gone. Held inside the House, never
;  out in the Circle. 500 is the author's own post-playtest Marine price, a fifth of a round. Author the
;  obj_marines/gate_marines_defenders task areas on the new ps_fe_hold points, all under a roof.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void wf_buy_marines
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
            (fe_notify "wf_bought_marines")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  ODSTs - 750, ungated. WALK-IN over the covered bridge, which is the map's own protected approach.
;  One ai_place at a tag spawn point - hsdoc_hr.txt L1277, called by every stock Firefight script
;  (ff20_courtyard.hsc L516, cex_ff_halo_main.hsc L127-129). [V]
;  Honest note: there is no "arrives from off-map" mechanism in any shipped Firefight script. A squad
;  appears at its tag spawn point. If you want them to be seen walking in, put the spawn point at the
;  far end of the bridge and let the follow task bring them to the player; do not expect an entrance
;  animation. The pod alternative is documented at the end of the prerequisites block above.
;  These ODSTs FOLLOW the buyer via obj_marines/gate_marines_followers.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void wf_buy_odst
    (if (fe_try_buy_squad k_fe_cost_odst ai_fe_odst)
        (begin
            (fe_place_up_to ai_fe_odst k_fe_buy_squad_size)
            (fe_squad_arrive ai_fe_odst)
            (fe_squad_follow ai_fe_odst)                   ; obj_marines/gate_marines_followers
            (fe_blip_squad ai_fe_odst)
            (set g_fe_odst_buys (+ g_fe_odst_buys 1))
            (wake fe_odst_expiry)
            (fe_notify "wf_bought_odst")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  SEAL THE BASIN RAMPS - 1,000, ungated. Closes two of the ramp approaches and discounts the win by
;  2,000 while they hold (8,000 -> 6,000). 1,000 is the author's Medium Weapon Rack rung, about half a
;  round's income. device_set_position is the stock door/position driver
;  (ff45_corvette_main.hsc L7-8; global_firefight.hsc L1934-1975 polls the generator switches the
;  same way). [V]
; ---------------------------------------------------------------------------------------------------
(script static void wf_buy_seal
    (if (and (not g_wf_ramps_sealed) (fe_try_buy k_fe_cost_map_state))
        (begin
            (object_create_anew dm_fe_ramp_01)
            (object_create_anew dm_fe_ramp_02)
            (device_set_position dm_fe_ramp_01 1)
            (device_set_position dm_fe_ramp_02 1)
            (set g_wf_ramps_sealed TRUE)
            (fe_notify "wf_bought_seal")
            (wake wf_seal_watch)
        )
    )
)

; object_get_health returns -1 if the object does not exist (hsdoc_hr.txt L378). [V]
(script continuous wf_seal_watch
    (sleep_forever)
    (sleep_until
        (or (<= (object_get_health dm_fe_ramp_01) 0)
            (<= (object_get_health dm_fe_ramp_02) 0))
        30
    )
    (set g_wf_ramps_sealed FALSE)
    (fe_notify "wf_seal_lost")
)

; ---------------------------------------------------------------------------------------------------
;  MACHINEGUN TURRET - 750, ungated, the author's own shipped turret price. Circle or bridge mouth.
;  [G] vehicle_load_magic is real (hsdoc_hr.txt L1025) and cex_ff_halo_main.hsc L865-868 uses it to
;  load a Warthog into a Pelican, but no shipped script crews a turret with it. Ship it unmanned if
;  the gunner will not take the seat.
; ---------------------------------------------------------------------------------------------------
(script static void wf_buy_turret
    (if (and (not g_wf_turret_built) (fe_try_buy k_fe_cost_turret))
        (begin
            (object_create_anew sc_fe_turret_01)
            (ai_object_set_team sc_fe_turret_01 player)    ; global_firefight.hsc L1728 [V]
            (ai_place ai_fe_gunner)
            (sleep 1)
            (vehicle_load_magic sc_fe_turret_01 "" (ai_actors ai_fe_gunner))   ; [G]
            (set g_wf_turret_built TRUE)
            (fe_notify "wf_bought_turret")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  COUNTER-SNIPER TEAM - 1,000, ungated. [DERIVED] One rung above a plain squad on the author's ladder
;  (his ally squads are 500-750); he never sold a specialist ally team, so the number is ours.
;  Two ODST marksmen under cover, the direct answer to the Jackal
;  snipers, which on this map are LIVE FROM WAVE ONE: ff30_waterfront.hsc L151 wakes
;  survival_sniper_spawn, which places sq_sur_sniper_01 - sq_sur_sniper_04 itself. [V]
;  sq_fe_sniper_01 is a third friendly squad, so it uses the same actor budget as Marines and ODSTs.
;  Give its cells sniper rifles in Sapien, not at runtime.
;  *** PARENTING WARNING: sq_fe_sniper_01 goes in gr_unsc_reinforcements. NOT gr_survival_snipers -
;  that group's living count is what gates the enemy sniper spawner at L495. ***
; ---------------------------------------------------------------------------------------------------
(script static void wf_buy_snipers
    (if (and (not g_wf_snipers_bought)
             (fe_try_buy_squad k_fe_cost_squad_special sq_fe_sniper_01))
        (begin
            (ai_place sq_fe_sniper_01)
            (fe_squad_arrive sq_fe_sniper_01)
            (fe_squad_hold sq_fe_sniper_01)                ; obj_marines/gate_marines_defenders
            (fe_blip_squad sq_fe_sniper_01)
            (set g_wf_snipers_bought TRUE)
            (fe_notify "wf_bought_snipers")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  ARTILLERY BARRAGE ON THE BASINS - 3,000, one shot, round 3 gate.
;  [DERIVED] His heavy rung is 3,000-3,500 (Falcon gunner run 3,000, Scorpion 3,500) and he gates that
;  rung to Round 3. He never priced a barrage; the number is ours, placed on his ladder.
;  The stock airstrike system is the verified mechanism, and Waterfront has the full infrastructure
;  for it: dm_target_01 - dm_target_03, sc_target_01 - sc_target_03 and dm_longsword_01 all exist
;  here, unlike on Glacier. (airstrike_set_launches 2) with (airstrike_weapons_exist) gating it is
;  ff20_courtyard.hsc L749-752. [V] airstrike_enable is hsdoc_hr.txt L5470.
;  [G] The commented damage_objects_effect line is the direct "delete the wave" version and needs a
;  real damage tag path.
; ---------------------------------------------------------------------------------------------------
(script static void wf_buy_barrage
    (if (and (not g_wf_barrage_used)
             (fe_gate_open k_fe_gate_heavy)
             (fe_try_buy k_fe_cost_superweapon))
        (begin
            (airstrike_enable TRUE)
            (airstrike_set_launches 1)
            (submit_incident_with_cause_campaign_team "sur_airstrike_refill" player)   ; stock id [V]
            (set g_wf_barrage_used TRUE)
            (fe_notify "wf_bought_barrage")
            ; [G] (damage_objects_effect <your damage_effect tag> (ai_actors gr_survival_all))
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  WIN - STATION SCRAM - 8,000, or 6,000 while the ramps hold. Round 5 gate, 120 s Pump hold.
;  Bought down in the basins at sq_sur_drop_03, not at the House board - see the header.
;  8,000 is four rounds of measured income (research/10 section 1.3). The old 30,000/25,000 is
;  withdrawn: at 2,000-2,500 a round it was ten to twelve rounds of income, unreachable in 16 waves.
; ---------------------------------------------------------------------------------------------------
(script static long wf_win_cost
    (if g_wf_ramps_sealed k_fe_cost_win_discount k_fe_cost_win)
)

(script static void wf_buy_scram
    (if (and (not g_wf_scram_bought) (fe_win_unlocked) (fe_try_buy (wf_win_cost)))
        (begin
            (set g_wf_scram_bought TRUE)
            (fe_notify "wf_bought_scram")
            (wake wf_win_hold)
        )
    )
)

; The per-second countdown inside a (sleep_until (begin (sleep ...) ...) 1) wrapper is Bungie's own
; loop idiom: ff20_courtyard.hsc L464-500, ff45_corvette_main.hsc L81-96. [V]
(script continuous wf_win_hold
    (sleep_forever)
    (set g_wf_hold_left 120)
    (sleep_until
        (begin
            (sleep 30)                                     ; 30 ticks = 1 second
            (if (volume_test_players tv_fe_pump)
                (set g_wf_hold_left (- g_wf_hold_left 1))
            )
            (<= g_wf_hold_left 0)
        )
        1
    )
    (fe_mission_won)
)

; ---------------------------------------------------------------------------------------------------
;  ESCALATION - wake the map's own dormant Banshee hazard from round 3.
;  This is the whole escalation now, and it is entirely stock content:
;    sq_sur_banshee_01 and sq_sur_banshee_02 exist in ff30_waterfront.hsc, survival_banshee_spawn
;    places them itself at L457-458, and (wake survival_banshee_spawn) at L150 is COMMENTED OUT. [V]
;  We do NOT touch the snipers: L151 already wakes survival_sniper_spawn, which places
;  sq_sur_sniper_01 - _04 and gates on gr_survival_snipers at L495. The previous version's
;  (ai_place sq_wf_jackal_snipers) was both an invented name and a duplicate spawner.
;  [G] Waterfront's Banshees have no ps_banshee_* flight path, unlike Holdout's. Where they fly is
;  not authored. Bungie shipped this spawner dormant and that may be why - if they behave badly,
;  delete this wake and the escalation becomes gametype-only, which is a legitimate outcome.
; ---------------------------------------------------------------------------------------------------
(script dormant wf_escalation
    (set g_wf_last_wave (survival_mode_wave_get))
    (sleep_until
        (begin
            (if (!= g_wf_last_wave (survival_mode_wave_get))
                (begin
                    (set g_wf_last_wave (survival_mode_wave_get))
                    (if (and (not g_wf_banshees_live) (>= (survival_mode_round_get) 2))
                        (begin
                            (wake survival_banshee_spawn)
                            (set g_wf_banshees_live TRUE)
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
;    R3  artillery barrage        R5  STATION SCRAM, down in the basins
;  fe_notify string ids are [G]; each needs a real string in the map's string tags, or use the stock
;  incident mechanism (fe_reinforcements.hsc section 11 b).
; ---------------------------------------------------------------------------------------------------
(script dormant wf_gates
    (sleep_until
        (begin
            (if (> (fe_round_index) g_wf_gate_round)
                (begin
                    (set g_wf_gate_round (fe_round_index))
                    (if (= g_wf_gate_round k_fe_gate_heavy)
                        (fe_notify "wf_gate_heavy")     ; "The artillery barrage is now available!"
                    )
                    (if (= g_wf_gate_round k_fe_win_round_gate)
                        (begin
                            (fe_notify "wf_gate_win")   ; "Station scram is now available - at the
                            (sound_impulse_start sfx_blip NONE 1)   ;  intake, down in the basins."
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
;  LOSE BACKSTOP - wave 16 with no scram bought. The only scripted loss on this map; the rest is
;  stock life exhaustion. s_survival_wave_complete_count is global_firefight.hsc L124. [V]
; ---------------------------------------------------------------------------------------------------
(script dormant wf_backstop
    (sleep_until (>= s_survival_wave_complete_count k_fe_wave_backstop) 30)
    (if (not g_wf_scram_bought)
        (fe_mission_lost)
    )
)

; ---------------------------------------------------------------------------------------------------
;  TEST HARNESS - shape copied from ff20_courtyard.hsc L1253-1260 (test_squad_drop). [V]
; ---------------------------------------------------------------------------------------------------
(script static void test_fe_marines
    (fe_board_open)
    (set k_fe_cost_marines 0)
    (wf_buy_marines)
)

(script static void test_fe_odst
    (fe_board_open)
    (set k_fe_cost_odst 0)
    (ai_erase ai_fe_odst)
    (sleep 30)
    (wf_buy_odst)
)
