; =====================================================================================================
;  ff10_prototype.hsc  -  OVERLOOK wiring for the Firefight Evolved Expanded purchase system
;  REWRITE 2026-11-23.  ZERO NEW SCRIPT OBJECTS.
; =====================================================================================================
;
;  Supersedes the pre-rewrite version of this file, which named 50-odd trigger volumes, object names
;  and squads that do not exist in this map.  Compiles as a unit after fe_shop_lib.hsc, which carries
;  the prices, the charging, the transaction template and everything that is identical between
;  Overlook and Beachhead.
;
;  Every object, squad, group and task named below was read out of ff10_prototype's OWN scnr tag.
;
;  THE SIX KIOSKS.  Overlook places six health_station device_controls (scnr controls[0..5]) with
;  placement flags 0x00000000, i.e. they exist from map load with no script help, all inside the
;  player base:
;
;    health_pack0  (148.34, 52.25,  0.41)   TROOPERS, 4 bodies   500   always
;    health_pack1  (143.00, 51.74,  0.41)   SPARTANS, 2 bodies  1000   set   >= 1
;    health_pack2  (144.76, 49.05,  0.41)   AMMO RESUPPLY        500   always
;    health_pack3  (142.19, 57.95,  0.41)   LONGSWORD PASS      3000   set   >= 1
;    health_pack4  (148.65, 51.57, -1.41)   BANK                 500   always
;    health_pack5  (145.28, 55.95, -1.41)   MAC STRIKE / WIN   10000   set   >= 1
;
;  COST OF THE CHOICE, STATED PLAINLY: these six objects are the map's health stations.  Standing at
;  one to buy is standing at one to heal, and the two uses are not separated.  The alternative
;  candidates were checked and rejected by direct read, not by preference: Overlook's sc_resupply_01..09,
;  hack_laser / hack_rocket / hack_sniper / hack_target and sc_target_01..03 all carry placement flag
;  bit0 ("not automatically"), so they do not exist until a script creates them, AND they all sit in an
;  off-map prop farm around (124-127, 35-39, -1.5) while the base is at (142-149, 49-58, 0.4) - about
;  20 world units away, unreachable.  generator_switch0..2 and generator_switch_cool/disabled0..2 are
;  likewise flag-bit0 objects created only during the generator event.  Overlook has no always-present
;  door machines, so unlike Holdout there is no seventh anchor and the shop is six stations, not seven.
;
;  THERE IS NO AIR-SUPPORT TIER ON THIS MAP.  Holdout's air tier flipped sq_sur_banshee_01/02 to team
;  human.  Overlook ships no banshee squad at all.  Its only vehicle squads are sq_sur_wraith_01/02,
;  whose spawn points sit at (316.9-322.0, 105.9-115.2, 40.9-41.5) - a staging area roughly 180 world
;  units from the base and 40 units above it - so a bare ai_place on them would stand an allied Wraith
;  up outside the playable space.  The tier is dropped rather than shipped broken, and the station it
;  would have used carries the Longsword pass instead.
;
;  Each kiosk is a dormant script woken by fe_overlook_startup, which is the author's gating idiom
;  (research/14 section 6.5) and keeps the shop inert until the map says it is open.
; =====================================================================================================


; =====================================================================================================
;  THE ALLY SQUADS, AND WHY THESE FOUR.
;
;  Overlook ships SIX empty fireteam handles, sur_fireteam_01..06, all parented to
;  gr_survival_fireteams (squad group 8) and all already carrying obj_fireteams as their initial
;  objective, whose single task `fireteams` Bungie already filtered to group 8 with follow = player and
;  follow radius 3.0.  The stage-2 build filled 01 and 02 with a 4-actor cell each; the shop tag build
;  filled 03 and 04 with a 2-actor Spartan cell each and gave all four their own on-foot spawn points
;  on this map's spartan_respawn_01..05 player respawn zones.  05 and 06 are left free.
;
;  WHY NOT THE DROP-POD SQUADS, WHICH IS WHAT HOLDOUT USED.  Overlook's stock
;  survival_drop_pod_manager does (ai_erase "sq_sur_drop_01") through "_05" at every round transition
;  and then (set g_sur_drop_spawn true), so allies living in those squads would be deleted between
;  rounds and the stock enemy pod event would switch itself back on.  Using the fireteam handles, which
;  no stock script on this map touches, avoids both - and means this port needs NO edit to any stock
;  script, where Holdout needed two.
;
;  2 trooper squads x 4 + 2 Spartan squads x 2 = 12 = k_fe_actor_limit exactly, so the cap binds at the
;  same moment the last handle fills.  Because the budget is shared, the per-squad emptiness test below
;  is what actually prevents re-placing a squad that still has living members; a budget check alone
;  would allow it.
; =====================================================================================================
(script static short fe_ov_troopers_alive
    (+ (ai_living_count "sur_fireteam_01") (ai_living_count "sur_fireteam_02"))
)

(script static short fe_spartans_alive
    (+ (ai_living_count "sur_fireteam_03") (ai_living_count "sur_fireteam_04"))
)

; A trooper sale needs BOTH an empty trooper squad to stand up and room in the shared budget.
(script static boolean fe_has_room
    (and
        (>= (fe_slots_free) k_fe_squad_size)
        (or (= (ai_living_count "sur_fireteam_01") 0)
            (= (ai_living_count "sur_fireteam_02") 0))
    )
)

; A Spartan sale needs an empty Spartan squad, room in the shared budget, and room under the sub-cap.
(script static boolean fe_has_spartan_room
    (and
        (>= (fe_slots_free) k_fe_spartan_size)
        (<= (+ (fe_spartans_alive) k_fe_spartan_size) k_fe_spartan_limit)
        (or (= (ai_living_count "sur_fireteam_03") 0)
            (= (ai_living_count "sur_fireteam_04") 0))
    )
)

(script static void fe_deliver_squad
    (cond
        ((= (ai_living_count "sur_fireteam_01") 0) (fe_squad_commit_placed "sur_fireteam_01"))
        ((= (ai_living_count "sur_fireteam_02") 0) (fe_squad_commit_placed "sur_fireteam_02"))
    )
    (set g_fe_buys (+ g_fe_buys 1))
)

(script static void fe_deliver_spartans
    (cond
        ((= (ai_living_count "sur_fireteam_03") 0) (fe_squad_commit_placed "sur_fireteam_03"))
        ((= (ai_living_count "sur_fireteam_04") 0) (fe_squad_commit_placed "sur_fireteam_04"))
    )
    (set g_fe_spartan_buys (+ g_fe_spartan_buys 1))
)

; =====================================================================================================
;  STATION 1  -  TROOPERS, 500.  Four Spartan-bodied troopers at major rank 'none', DMR or assault
;  rifle.  The cap is checked BEFORE the charge, so a full field refuses the sale rather than taking
;  the money and delivering nothing.
; =====================================================================================================
(script dormant void fe_kiosk_reinforce
    (sleep_until
        (begin
            (fe_wait_at "health_pack0")
            (if (fe_has_room)
                (if (fe_transact "health_pack0" k_fe_cost_squad)
                    (fe_deliver_squad)
                )
                (fe_deny "health_pack0")
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 2  -  SPARTANS, 1000 for TWO, gated on SET >= 1.
;
;  Three gates, all checked before the charge: the shared ally budget (k_fe_actor_limit, 12), the
;  Spartan sub-cap (k_fe_spartan_limit, 4) and a free Spartan squad.  Spartans sit in
;  gr_survival_fireteams like the troopers, so they consume the SAME budget - buying Spartans costs you
;  troopers, which is the whole point.
; =====================================================================================================
(script dormant void fe_kiosk_spartan
    (sleep_until
        (begin
            (fe_wait_at "health_pack1")
            (if (fe_gate_set k_fe_gate_spartan)
                (if (fe_has_spartan_room)
                    (if (fe_transact "health_pack1" k_fe_cost_spartan)
                        (fe_deliver_spartans)
                    )
                    (fe_deny "health_pack1")
                )
                (fe_deny "health_pack1")
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 3  -  AMMO RESUPPLY, 500.
; =====================================================================================================
(script dormant void fe_kiosk_ammo
    (sleep_until
        (begin
            (fe_wait_at "health_pack2")
            (if (fe_transact "health_pack2" k_fe_cost_ammo)
                (fe_deliver_ammo)
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 4  -  LONGSWORD PASS, 3000, gated on SET >= 1, per the author's pattern for his heavy rung.
; =====================================================================================================
(script dormant void fe_kiosk_strike
    (sleep_until
        (begin
            (fe_wait_at "health_pack3")
            (if (fe_gate_set k_fe_gate_strike)
                (if (fe_transact "health_pack3" k_fe_cost_strike)
                    (fe_deliver_strike)
                )
                (fe_deny "health_pack3")
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 5  -  BANK, 500 a press, shared across all players.
; =====================================================================================================
(script dormant void fe_kiosk_bank
    (sleep_until
        (begin
            (fe_wait_at "health_pack4")
            (fe_bank_use "health_pack4")
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 6  -  MAC STRIKE, 10000, gated on SET >= 1.  This is the win condition.
; =====================================================================================================
(script dormant void fe_kiosk_win
    (sleep_until
        (begin
            (fe_wait_at "health_pack5")
            ; VALIDATE BEFORE CHARGING (audit 29, RISK-R1).  fe_transact deducts k_fe_cost_win the moment
            ; it is reached, and fe_mission_won's own (not g_fe_won) / (not b_survival_game_end_condition)
            ; guard only ran afterwards - so buying during the bonus round, or in the seconds after any
            ; stock end condition fires, took 10,000 points and delivered nothing.  Both preconditions are
            ; now part of the kiosk's own test, so the sale is refused BEFORE any deduction.  The guard
            ; inside fe_mission_won stays as belt and braces.  No new script object: both globals already
            ; exist and are already referenced by this compile unit.
            (if (and (fe_gate_set k_fe_gate_win) (not g_fe_won) (not b_survival_game_end_condition))
                (if (fe_transact "health_pack5" k_fe_cost_win)
                    (fe_mission_won)
                )
                (fe_deny "health_pack5")
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  ALLY HOUSEKEEPING.
;
;  The task refresh is the author's refresh_gate_marines pattern: allies drift off a follow task, so
;  re-issue it.  ai_reset_objective (0x1FA) takes `ai`, so it is called on the ally GROUP, which covers
;  all four ally squads in one call.
; =====================================================================================================
(script continuous void fe_overlook_ally_refresh
    (sleep 150)
    (if (> (fe_allies_alive) 0)
        (begin
            (ai_reset_objective "gr_survival_fireteams")
            (ai_set_task "gr_survival_fireteams" "obj_fireteams" "fireteams")
        )
    )
)

; =====================================================================================================
;  STARTUP.
;
;  Opens the shop and wakes the six stations.  It touches NOTHING stock: not
;  survival_wave_living_count, not the wave machinery, not the generator scripts, and - unlike the
;  Holdout port - not g_sur_drop_spawn or g_sur_drop_limit either, because this map's allies do not
;  live in the drop-pod squads.  The whole stock script is left exactly as Bungie wrote it.
; =====================================================================================================
(script startup void fe_overlook_startup
    (sleep 30)
    ; MEASURED KIOSK RADIUS.  The library default is 2.5 world units, which is WRONG for
    ; this map: its closest two shop anchors (health_pack0 <-> health_pack4) are only 1.967 world
    ; units apart, so any radius >= 0.984 lets one standing position reach both kiosks and
    ; charge for both sales.  0.90 is the measured-safe value, taken straight from the
    ; placed-object coordinates in this map's own scnr tag.
    (set k_fe_kiosk_radius 0.90)
    (set g_fe_open true)
    (set g_fe_bank 0)
    (set g_fe_buys 0)
    (set g_fe_spartan_buys 0)
    (set g_fe_won false)
    (wake fe_kiosk_reinforce)
    (wake fe_kiosk_spartan)
    (wake fe_kiosk_ammo)
    (wake fe_kiosk_strike)
    (wake fe_kiosk_bank)
    (wake fe_kiosk_win)
    (if g_fe_debug (print "fe: overlook shop open"))
)
