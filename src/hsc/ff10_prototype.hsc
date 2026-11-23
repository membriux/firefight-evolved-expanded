; =====================================================================================================
;  ff10_prototype   -   OVERLOOK, "VISEGRAD RELAY, HOUR ZERO"
;
;  TAG NAME -> FRIENDLY MAP NAME
;    scenario tag : levels\firefight\ff10_prototype\ff10_prototype
;    tag name     : ff10_prototype    <- what the engine, the scripts and the .map are named
;    map name     : Overlook          <- what the menu shows the player
;    Bungie's script: research/_raw/hsc/ff10_prototype.hsc, 1414 lines, banner
;    "; ====== M10 PROTOTYPE FIREFIGHT SCIRPTS ===" (Bungie's own typo), startup at L24-157.
;
;  Design source: research/05-map-scenario-designs.md section 5.2
;  Engine facts  : research/11-stock-map-spawn-geography.md section 7
;  Requires      : fe_reinforcements.hsc compiled BEFORE this file.
;
;  *** STARTUP SCRIPT COLLISION ***
;  ff10_prototype.hsc already declares (script startup ff10_prototype ...) at L24. Either delete the
;  declaration below and paste its body before the stock closing paren at L157 (preferred), or remove
;  the stock declaration and copy its whole configuration block (L30-155) into this one.
;
;  WIN   buy RELAY UPLINK (8,000, or 6,000 if the bridge barricade was bought and still stands; not
;        before round 5) AT THE EXPOSED TERMINAL ACROSS THE RIVER, then hold the uplink room for 150 s.
;  LOSE  (a) life exhaustion, stock survival_mode_end_condition_lives;
;        (b) backstop: wave 16 completed with no uplink = relay lost.
;
;  CATALOGUE  (prices retuned to the author's measured income, ~2,000-2,500 a round - see
;              fe_reinforcements.hsc section 1. [A] = his shipped price, [D] = derived on his ladder.)
;                                               cost   gate   script
;    Marine squad (3-4)                          500 [A]  -    ov_buy_marines
;    ODST squad (4, 1 sniper, 1 grenade lchr)    750 [A]  -    ov_buy_odst    pod, beside ammo_crate0
;    Bridge barricade (map state)              1,000 [A]  -    ov_buy_barricade  unlocks the 6,000 win
;    Machinegun turret (bridge mouth)            750 [A]  -    ov_buy_turret
;    Bank kiosk, deposit or withdraw             500 [A]  -    fe_bank_deposit / fe_bank_withdraw
;    RELAY UPLINK (win)                  8,000/6,000 [D]  R5   ov_buy_uplink     EXPOSED TERMINAL
;
;  Overlook sells no vehicle and no strike (see the removals below), so this is the shortest board of
;  the six and the only one with no R2 or R3 gate. Its single gate is the win.
;
;  THE EXPOSED WIN TERMINAL - the far side of the covered bridge, at sq_sur_drop_05
;  The author exiles Unearthed's MAC Cannon to the Crane so the climax is a run through the barrage
;  (research/10 section 3.2). Overlook's geometry gives us the cleanest version of that run on any of
;  the six maps: every Covenant drop lands across the river and the covered bridge is the ONLY
;  crossing. So the uplink terminal goes on the FAR bank, in the Covenant drop zone, anchored on
;  sq_sur_drop_05 - the fifth and last of the named Covenant pod lanes, dm_drop_01 - dm_drop_05 /
;  sq_sur_drop_01 - sq_sur_drop_05, all [V] in ff10_prototype.hsc. Named tag objects only; read the
;  position in Sapien, and offset the volume so it does not sit under the pod's own landing footprint
;  (research/10 build checklist item 9: keep pod zones clear of the thing you need to reach).
;  If p05 reads too close to the bridge mouth, use whichever of sq_sur_drop_01 - _05 is farthest from
;  ammo_crate0. Do not invent a coordinate.
;
;  THE BANK  (new, from research/10 section 1.2)
;    tv_fe_bank_in / tv_fe_bank_out [NEW], 500 a press, beside ammo_crate0 in the barn. His own kiosks
;    sit on the route players already walk every round. Banked points leave the live score, so the
;    8,000 uplink survives a round of buying marines. g_fe_bank must survive the set boundary.
;
;  =====================================================================================================
;  TWO THINGS WERE REMOVED FROM THIS SCENARIO. BOTH WERE SOLD ON BAD EVIDENCE.
;  =====================================================================================================
;  1. EVERY VEHICLE PURCHASE IS GONE - Scorpion (12,000), Rocket Warthog (6,000), Gauss upgrade.
;     The justification was "Overlook is verified Wraith terrain". It is the weakest vehicle evidence
;     of any of the six maps. ff10_prototype.hsc names sq_sur_wraith_01 and sq_sur_wraith_02 but has
;     NO ps_wraith point set at all, so those Wraiths have no authored firing points and no authored
;     movement whatsoever - the script never tells them to go anywhere. On Beachhead and Glacier,
;     where ps_wraith does exist, the Wraiths are driven by (cs_shoot_point ps_wraith/p0-p3) in
;     cs_wraith_shoot, which is a STATIONARY bombardment script and proves nothing about drivable
;     ground either. And a Wraith hovers.
;     Overlook also names no Ghost squad, so there is no vehicle chassis on this map that the stock
;     scripts are known to spawn and move. Under the rule in fe_reinforcements.hsc section 2a -
;     "sell only a chassis the map's own hazard set already spawns and moves" - Overlook sells none.
;     The freed 22,000 of catalogue is not redistributed; the board is simply shorter.
;
;  2. THE GENERATOR LOSS CONDITION IS GONE - it was "Generator Count 1, uplink generator, fail on
;     lose-all". generator0 - generator2 are fixed device machines at fixed tag positions on every
;     map; they cannot be moved, re-dressed or chosen per scenario, only counted and ordered. Worse,
;     ff10_prototype.hsc assigns all twelve generator objects (L114-125) but has NO ps_gen point set,
;     NO cs_gen0/cs_gen1/cs_gen2 command scripts and NO obj_survival/gen0-gen2 AI tasks. Its
;     obj_survival task list is the minimal set: generator, hero_follow, main_follow, remaining. So
;     the Covenant have only the generic "generator" task and no approach points - generator-defence
;     AI routing is NOT AUTHORED on this map. A generator loss condition here fires on damage that no
;     enemy is being routed to deliver.
;     Only Beachhead (ff50_park) and Holdout (ff70_holdout) have ps_gen/gen0-gen2 plus the per-
;     generator tasks. [V] Loss on Overlook is now lives plus the wave-16 backstop, both verified.
;     The win is a volume hold, which never depended on generators.
;
;  =====================================================================================================
;  *** THE gr_survival_extras TRAP IS LIVE ON THIS MAP. ***
;  =====================================================================================================
;  ff10_prototype.hsc L507 and L529 are the Covenant drop-pod spawner, survival_drop_spawn, and both
;  of them block on that group reaching zero:
;      L507  (<= (ai_living_count gr_survival_extras) 0)                      ; pre-spawn gate
;      L529  (sleep_until (<= (ai_living_count gr_survival_extras) 0))        ; post-burst gate
;  The stock startup wakes that spawner at L150-152. So a single living friendly marine parented under
;  gr_survival_extras SUPPRESSES ALL FIVE COVENANT DROP PODS for the rest of the match, silently.
;  Bungie's own authoring checklist parents gr_survival_marines under gr_survival_extras. DO NOT.
;  Friendly squads go in gr_unsc_reinforcements, child of nothing.
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
;    objective     obj_marines                 [NEW]  tasks gate_marines, gate_marines_followers,
;                  gate_marines_defenders. Copied from cex_ff_halo. README section 2d.
;    point set     ps_fe_hold  with points hold_01, hold_02, hold_03       [NEW]
;                  OVERLOOK HAS NO ps_gen AND NO ps_wraith, so unlike Beachhead and Holdout there is
;                  NO existing point set to borrow for defender positions. You must author one. Put
;                  its points next to ammo_crate0 / ammo_crate1.
;    anchors       ammo_crate0, ammo_crate1                      [V by convention]
;                  Global defaults present on every Firefight map (global_firefight.hsc L54-55),
;                  created and HUD-tracked at L3177-3196. Overlook's own script never mentions them,
;                  precisely because the globals already default to those names.
;                  The design doc's claim "both ammo crates are inside the barn [V]" is NOT script-
;                  verifiable - it is plausible and consistent with Bungie's practice, but read the
;                  real positions out of the tag before you build an economy on them. [TAG]
;    avoid         kill_sur_room_01 - kill_sur_room_08           [V]  the eight Covenant spawn rooms
;                  sq_sur_drop_01 - sq_sur_drop_05 spawn points  [V]  five Covenant pod lanes
;    trigger vols  OVERLOOK HAS NO TRIGGER VOLUMES AT ALL in main or fragments. [V] Every tv_ below
;                  is 100% new content, and all of them must be POSTPROCESSED (saved and rebuilt)
;                  before volume_test_players will work - hsdoc_hr.txt L216-217 requires it.
;                  tv_fe_board        [NEW] the terminal, beside ammo_crate0
;                  tv_fe_uplink       [NEW] the uplink room hold area for the win timer
;                  tv_fe_buy_marines tv_fe_buy_odst tv_fe_buy_barricade tv_fe_buy_turret   [NEW]
;                  tv_fe_bank_in, tv_fe_bank_out   [NEW] the two bank kiosks, also at the terminal
;                  tv_fe_buy_uplink   [NEW] *** NOT at the terminal. *** Across the river at
;                    sq_sur_drop_05. See the exposed-terminal note in the header.
;    device        dm_fe_pod_01       [NEW] friendly pod rail. Pattern proven here five times over:
;                  dm_drop_01 - dm_drop_05 and sq_sur_drop_01 - sq_sur_drop_05 all exist [V], so a
;                  sixth copy of drop_pod_NN is routine. But a pod lands at the SQUAD'S tag spawn
;                  point, so a new rail and a new sq_fe_odst/driver point are still required, and
;                  must NOT reuse a Covenant site.
;                  dm_fe_barricade_01 [NEW] the covered-bridge barrier, a device_machine that closes
;    objects       sc_fe_turret_01    [NEW] "initially placed" off
;  NOTE: the jetpack tower is unreachable by AI (research/05 5.2). No turret anchor, no squad spawn
;  point, no defender task area up there.
; =====================================================================================================

(global boolean g_ov_uplink_bought  FALSE)
(global boolean g_ov_barricade_up   FALSE)
(global boolean g_ov_turret_built   FALSE)
(global short   g_ov_hold_left      150)
(global short   g_ov_last_wave      -2)
(global short   g_ov_gate_round      0)       ; last absolute round whose gate banner has been shown
(global vehicle v_fe_pod_01         NONE)

; =====================================================================================================
;  STARTUP - named for the scenario tag. See the collision warning in the header.
; =====================================================================================================
(script startup ff10_prototype
    ; ---------------- PASTE MARKER: START OF FE ADDITIONS -------------------------------------------
    (sleep 5)
    (set ai_fe_group     gr_unsc_reinforcements)
    (set ai_fe_followers gr_unsc_followers)
    (set ai_fe_garrison  sq_fe_garrison)
    (set ai_fe_marines   sq_fe_marines)
    (set ai_fe_odst      sq_fe_odst)
    (set ai_fe_gunner    sq_fe_gunner)

    ; FRIENDLY CAP: 12, the pack default. Overlook is one of the two maps that can carry it. The relay
    ; valley is open ground with five Covenant pod sites (dm_drop_01-05) and no interior chokepoint
    ; that fourteen bodies could plug, so the pathing argument that lowers Holdout, Glacier and Outpost
    ; does not apply here. See fe_reinforcements.hsc section 2.4 for where 12 comes from.
    ; THE DROP-POD TRAP STILL APPLIES ON THIS MAP AND IS WORSE THAN THE CAP. ff10_prototype.hsc L507
    ; and L529 both gate the Covenant pod spawner on (<= (ai_living_count gr_survival_extras) 0), so a
    ; single living friendly parented under gr_survival_extras silently suppresses Covenant drop pods
    ; for the whole match. sq_fe_garrison, sq_fe_marines and sq_fe_odst must be children of
    ; gr_unsc_reinforcements, which is a child of NOTHING. Re-read the trap block at the top of
    ; fe_reinforcements.hsc before you parent anything in Sapien.
    (set k_fe_actor_limit 12)
    (set k_fe_free_squad_size 6)

    (wake fe_garrison_watch)        ; free 6-man garrison: match start + every round start
    (wake fe_slots_banner_watch)    ; "slots full" / "slots available" HUD edges
    (wake ov_mission_start)
    (wake ov_board)
    (wake ov_escalation)
    (wake ov_gates)
    (wake ov_backstop)
    ; ---------------- PASTE MARKER: END OF FE ADDITIONS ---------------------------------------------
)

; The mission trigger is the terminal volume beside ammo_crate0, or 60 s.
; The design doc's "interacting with the radio in the upper barn room [V] starts the uplink" has no
; engine referent: no object resembling a radio appears anywhere in ff10_prototype.hsc. The only
; player-interactable devices the script names are generator_switch0 - generator_switch2, and with no
; ps_gen on this map their reachability is unproven here. So the trigger is a plain trigger volume.
(script dormant ov_mission_start
    (sleep_until (volume_test_players tv_fe_board) 15 1800)
    (fe_board_open)
    (fe_notify "ov_board_online")
    (sound_impulse_start sfx_blip NONE 1)           ; ff20_courtyard.hsc L780 [V]
)

(script continuous ov_board
    (sleep_forever)
    (sleep_until
        (begin
            (player_action_test_reset)
            (sleep 5)
            (if (and g_fe_board_open (player_action_test_action))
                (begin
                    (if (volume_test_players tv_fe_buy_marines)   (ov_buy_marines))
                    (if (volume_test_players tv_fe_buy_odst)      (ov_buy_odst))
                    (if (volume_test_players tv_fe_buy_barricade) (ov_buy_barricade))
                    (if (volume_test_players tv_fe_buy_turret)    (ov_buy_turret))
                    (if (volume_test_players tv_fe_buy_uplink)    (ov_buy_uplink))
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
;  MARINES - 500, ungated, re-buyable the moment the last squad is gone. Defenders, anchored on the new
;  ps_fe_hold points near the ammo crates. 500 is the author's own post-playtest Marine price and about
;  a fifth of a round's income, so a squad is affordable every round and usually twice.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void ov_buy_marines
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
            (fe_notify "ov_bought_marines")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  ODSTs - 750, ungated, drop pod beside ammo_crate0.
;  Overlook is one of the four target maps where the pod pattern genuinely exists: dm_drop_01 - _05
;  and sq_sur_drop_01 - _05, with drop_pod_01 - drop_pod_05 duplicated in the stock file. [V]
;  The sequence below is Bungie's, ff20_courtyard.hsc L511-545, and the two lines before
;  fe_pod_sequence must stay inline because sq_fe_odst/driver has to be a literal (stock does the
;  same at ff20_courtyard.hsc L518). [V]
;  These ODSTs FOLLOW the buyer via obj_marines/gate_marines_followers.
; ---------------------------------------------------------------------------------------------------
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void ov_buy_odst
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
            (fe_notify "ov_bought_odst")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  BRIDGE BARRICADE - 1,000, ungated. Pure map state: closes the covered bridge, and discounts the win
;  purchase by 2,000 while it stands (8,000 -> 6,000). 1,000 is the author's Medium Weapon Rack rung -
;  about half a round's income, a real choice but not a saving project. device_set_position is the stock door/position driver
;  (ff45_corvette_main.hsc L7-8 slams doors with it; global_firefight.hsc L1934-1975 polls the
;  generator switches the same way). [V]
; ---------------------------------------------------------------------------------------------------
(script static void ov_buy_barricade
    (if (and (not g_ov_barricade_up) (fe_try_buy k_fe_cost_map_state))
        (begin
            (object_create_anew dm_fe_barricade_01)
            (device_set_position dm_fe_barricade_01 1)
            (set g_ov_barricade_up TRUE)
            (fe_notify "ov_bought_barricade")
            (wake ov_barricade_watch)
        )
    )
)

; The discount only applies while the barricade is intact, so watch its health.
; object_get_health returns -1 if the object does not exist (hsdoc_hr.txt L378). [V]
(script continuous ov_barricade_watch
    (sleep_forever)
    (sleep_until (<= (object_get_health dm_fe_barricade_01) 0) 30)
    (set g_ov_barricade_up FALSE)
    (fe_notify "ov_barricade_lost")
)

; ---------------------------------------------------------------------------------------------------
;  MACHINEGUN TURRET - 750, ungated. The bridge mouth is the dominant anchor on this map.
;  750 is the author's own shipped turret price and he never gated it: a turret is a fortification you
;  buy on reflex at the position you are defending.
;  [G] vehicle_load_magic is real (hsdoc_hr.txt L1025) and cex_ff_halo_main.hsc L865-868 uses it to
;  load a Warthog into a Pelican, but no shipped script crews a turret with it. Ship the turret
;  unmanned if it will not take a gunner - a player-usable turret is still a purchase.
; ---------------------------------------------------------------------------------------------------
(script static void ov_buy_turret
    (if (and (not g_ov_turret_built) (fe_try_buy k_fe_cost_turret))
        (begin
            (object_create_anew sc_fe_turret_01)
            (ai_object_set_team sc_fe_turret_01 player)    ; global_firefight.hsc L1728 [V]
            (ai_place ai_fe_gunner)
            (sleep 1)
            (vehicle_load_magic sc_fe_turret_01 "" (ai_actors ai_fe_gunner))   ; [G]
            (set g_ov_turret_built TRUE)
            (fe_notify "ov_bought_turret")
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  WIN - RELAY UPLINK. 8,000, or 6,000 while the barricade stands. Round 5 gate. Bought ACROSS THE
;  RIVER at sq_sur_drop_05, not at the barn board - see the header.
;  8,000 is four rounds of measured income (research/10 section 1.3), which is where the author's own
;  MAC Cannon gate lands his players. The old 30,000/20,000 is withdrawn: at 2,000-2,500 a round that
;  was eight to twelve rounds of income, i.e. unreachable inside a 16-wave match.
; ---------------------------------------------------------------------------------------------------
(script static long ov_win_cost
    (if g_ov_barricade_up k_fe_cost_win_discount k_fe_cost_win)
)

(script static void ov_buy_uplink
    (if (and (not g_ov_uplink_bought) (fe_win_unlocked) (fe_try_buy (ov_win_cost)))
        (begin
            (set g_ov_uplink_bought TRUE)
            (fe_notify "ov_bought_uplink")
            (wake ov_win_hold)
        )
    )
)

; ---------------------------------------------------------------------------------------------------
;  WIN SEQUENCE - 150 s of transmission with at least one player inside tv_fe_uplink.
;  This no longer depends on a generator surviving: see the removal note in the header. The hold is a
;  pure volume test, which is the verified half of the original design.
; ---------------------------------------------------------------------------------------------------
(script continuous ov_win_hold
    (sleep_forever)
    (set g_ov_hold_left 150)
    (sleep_until
        (begin
            (sleep 30)                                     ; 30 ticks = 1 second
            (if (volume_test_players tv_fe_uplink)
                (set g_ov_hold_left (- g_ov_hold_left 1))
            )
            (<= g_ov_hold_left 0)
        )
        1
    )
    (fe_mission_won)
)

; ---------------------------------------------------------------------------------------------------
;  ESCALATION - armour from round 3, second Wraith in set 2.
;  THE SQUAD NAMES ARE NOW THE REAL ONES, grepped out of ff10_prototype.hsc:
;    sq_sur_wraith_01, sq_sur_wraith_02   [V]
;  The previous version invented sq_ov_wraith_01 / sq_ov_wraith_02, which exist nowhere.
;  [G] on the BEHAVIOUR, not the names: Overlook has no ps_wraith and no obj_survival wraith tasks,
;  so once placed these Wraiths fall through to the map's minimal task set (generator, hero_follow,
;  main_follow, remaining) and will most likely just follow the players. Whatever they do, the stock
;  script does not direct them. The design claim "the Wraith crosses to the yard" is unsupported.
;  Overlook's startup wakes survival_drop_spawn but no vehicle spawner, so ai_place here does not
;  fight a stock thread.
; ---------------------------------------------------------------------------------------------------
(script dormant ov_escalation
    (set g_ov_last_wave (survival_mode_wave_get))
    (sleep_until
        (begin
            (if (!= g_ov_last_wave (survival_mode_wave_get))
                (begin
                    (set g_ov_last_wave (survival_mode_wave_get))
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
;  ROUND GATE BANNER
;  The author's pacing device (research/10 section 1.2): every unlock is announced on the round
;  boundary with a HUD banner, because an unannounced gate reads as a bug. His 0.1.6 note: "HUD
;  messages for important events (switches becoming available, Unearthed's MAC Cannon, Installation
;  04's Evac Pelican, etc) are now implemented to make objectives more clear ingame."
;  Overlook has only one gate, the win, so there is only one banner - and it has to say WHERE, because
;  the uplink terminal is across the river. fe_notify string ids are [G]: each needs a real string in
;  the map's string tags, or use the stock incident mechanism (fe_reinforcements.hsc section 11 b).
; ---------------------------------------------------------------------------------------------------
(script dormant ov_gates
    (sleep_until
        (begin
            (if (> (fe_round_index) g_ov_gate_round)
                (begin
                    (set g_ov_gate_round (fe_round_index))
                    (if (= g_ov_gate_round k_fe_win_round_gate)
                        (begin
                            (fe_notify "ov_gate_win")   ; "The relay uplink is now available - at the
                            (sound_impulse_start sfx_blip NONE 1)   ;  far end of the bridge."
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
;  LOSE BACKSTOP - wave 16 with no uplink purchased. Now the ONLY scripted loss on this map; the rest
;  is stock life exhaustion. s_survival_wave_complete_count is global_firefight.hsc L124. [V]
; ---------------------------------------------------------------------------------------------------
(script dormant ov_backstop
    (sleep_until (>= s_survival_wave_complete_count k_fe_wave_backstop) 30)
    (if (not g_ov_uplink_bought)
        (fe_mission_lost)
    )
)

; ---------------------------------------------------------------------------------------------------
;  TEST HARNESS - shape copied from ff20_courtyard.hsc L1253-1260 (test_squad_drop). [V]
; ---------------------------------------------------------------------------------------------------
(script static void test_fe_marines
    (fe_board_open)
    (set k_fe_cost_marines 0)
    (ov_buy_marines)
)

(script static void test_fe_odst
    (fe_board_open)
    (set k_fe_cost_odst 0)
    (ai_erase ai_fe_odst)
    (sleep 30)
    (ov_buy_odst)
)
