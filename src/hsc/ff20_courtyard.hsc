; =====================================================================================================
;  ff20_courtyard.hsc  -  COURTYARD wiring for the Firefight Evolved Expanded purchase system
;  REWRITE 2026-11-23.  ZERO NEW SCRIPT OBJECTS.
;
;  Replaces nothing: Courtyard had no shop file before this one.  Compiles as a unit after
;  fe_shop_ctgl.hsc, which must itself come after the map's own 357-script decompile.
;
;  TAG NAME -> FRIENDLY MAP NAME
;    scenario tag : levels\firefight\ff20_courtyard\ff20_courtyard
;    tag name     : ff20_courtyard     <- what the engine, the scripts and the .map are named
;    map name     : Courtyard          <- what the menu shows the player
;
;  Every object, squad, group and task named below was read out of ff20_courtyard's own scnr tag with
;  build/logs/shop_survey.py and then PROVED by compiling against that cache: in this toolchain an
;  object name the scenario does not have is a hard compile failure, not a warning.  The negative
;  control that establishes that is in research/23 section 3.
;
;  =====================================================================================================
;  THE SIX KIOSKS, and why these six objects
;  =====================================================================================================
;  Courtyard places six health_station device_controls with placement flags 0x00000000 - present from
;  map load with no script help - and three #_door_interior_large_logo device_machines with the same
;  flags.  Those nine are the whole set of always-present named interactive objects inside the arena;
;  everything else named in the base is scenery, crates or a respawn-zone marker.  All nine sit inside
;  trigger volume safe_zone_soft_01, bounds x[-106.9,-54.0] y[-6.1,68.7] z[12.7,23.7], i.e. the
;  playable space.
;
;    health_pack0                   (-100.34  33.09  18.27)   TROOPERS, 4 bodies   500   always
;    health_pack1                   ( -99.92  37.90  18.27)   SPARTANS, 2 bodies  1000   set   >= 1
;    health_pack4                   ( -96.70  34.32  18.27)   BANK                 500   always
;    #_door_interior_large_logo_03  ( -98.75  35.50  17.70)   AMMO RESUPPLY        500   always
;    #_door_interior_large_logo_04  ( -91.86  35.50  16.50)   LONGSWORD PASS      3000   set   >= 1
;    health_pack2                   ( -74.60  33.50  18.27)   MAC STRIKE / WIN   10000   set   >= 1
;
;  The leading '#' survives the HaloScript lexer when quoted - proved on Holdout against a real cache,
;  re-proved here against Courtyard's - which is what makes the two door machines usable.
;
;  health_pack5 (-96.70 36.68 18.27) and health_pack3 (-74.60 37.50 18.27) ARE DELIBERATELY NOT USED.
;    health_pack5 is left as a pure heal station, because the four kiosks in the rear cluster already
;      crowd a 4-world-unit square and a fifth would make it impossible to heal without buying.
;    health_pack3 is REJECTED ON EVIDENCE: its position falls inside the runtime sector bounds of
;      trigger volume kill_soft_03 (x[-75.4,-68.5] y[36.5,52.6] z[16.3,30.7]).  That test is an
;      axis-aligned over-approximation of a 22-point volume, so it may be a false positive - but a
;      soft kill volume starts a "return to the battlefield" countdown, and a dwell-based purchase
;      inside one is a shop that kills the buyer.  Not worth the coin flip when a spare station exists.
;
;  COST OF THE CHOICE, STATED PLAINLY: four of the six kiosks are the map's health stations.  Standing
;  at one to buy is standing at one to heal, and the two uses are not separated.  health_pack5 and
;  health_pack3 are the mitigation, not a fix.
;
;  THE WIN TERMINAL IS DELIBERATELY EXPOSED.  health_pack2 is in the FORWARD cluster at x -74.6, about
;  25 world units from the rear base cluster at x -97..-100 where everything else is sold.  That
;  reproduces the author's own design - he exiles Unearthed's MAC Cannon terminal to the Crane so the
;  climax is a run through the barrage (research/10 section 3.2) - using an object Courtyard already
;  places, rather than a new one.
;
;  =====================================================================================================
;  WHAT IS NOT SOLD HERE, AND WHY NOT
;  =====================================================================================================
;  AIR SUPPORT IS NOT SOLD ON COURTYARD, although the map has the squads for it.
;  sq_sur_banshee_01 and _02 are the only Courtyard squads with a vehicle cell (vehicle palette [6],
;  banshee), and Holdout sold exactly these as an allied Banshee.  Courtyard cannot, because its stock
;  script OWNS them: survival_banshee_spawn (decompile L5061-5078) does
;  (begin_random_count 1 (ai_place "sq_sur_banshee_01") (ai_place "sq_sur_banshee_02")) every 2-3
;  minutes, gated on (<= (ai_task_count "obj_survival/extras_gate") 0), and banshee_emp_kill keeps
;  acting on them afterwards.  A purchased ALLY banshee would be re-placed as an ENEMY by that event,
;  or would block it.  Disabling the event means editing Bungie's text, which this port does not do.
;  Stated as a missing feature rather than shipped broken.
;
;  THE LONGSWORD PASS IS SOLD, WITH ONE KNOWN RISK.  dm_longsword_01 is machines[16] with placement
;  flag bit0 set, so it must be created before use, and stock Courtyard creates it the same way for
;  its weapon-resupply event (decompile L5371-5398: object_create, device_set_position_track "ff10",
;  device_animate_position, object_destroy).  The five calls are repeated here instead of calling the
;  stock script, so this file compiles standalone.  If a purchase lands inside the stock event's own
;  10-second animation window the two will fight over one device and the result is a visual glitch.
;  Holdout shipped the identical arrangement; this is parity, not a discovery.
;
;  =====================================================================================================
;  NO STOCK SCRIPT IS EDITED.  THERE IS NO ff20_courtyard_stock_hooks.hsc.
;  =====================================================================================================
;  The Holdout build needed two writes into stock globals (g_sur_drop_spawn, g_sur_drop_limit) because
;  it used sq_sur_drop_01..04 as the ally bodies and had to switch Bungie's drop-pod event off.  This
;  port uses sur_fireteam_01..04 instead, so Courtyard's Covenant drop pods keep working exactly as
;  shipped, as enemies, and the diff against Bungie's script text is EMPTY.  See fe_shop_ctgl.hsc
;  section 0 for the ai_erase collision that choice also avoids.
;
;  Each kiosk is a dormant script woken by fe_courtyard_startup, which is the author's gating idiom
;  (research/14 section 6.5) and keeps the shop inert until the map says it is open.
; =====================================================================================================


; =====================================================================================================
;  STATION 1  -  TROOPERS, 500.  Four bodies, on foot, from sur_fireteam_01 or _02.
;  The cap and the squad-availability test are both checked BEFORE the charge, so a full field refuses
;  the sale rather than taking the money and delivering nothing.
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
;  Three gates, all before the charge: the shared ally budget (k_fe_actor_limit, 12), the Spartan
;  sub-cap (k_fe_spartan_limit, 4) and whether one of the two Spartan squads is actually empty.
;  Spartans sit in gr_survival_fireteams like the troopers, so they consume the SAME budget - buying
;  Spartans costs you troopers, which is the whole point.
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
;  STATION 3  -  BANK, 500 a press, shared across all players.
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
;  STATION 4  -  AMMO RESUPPLY, 500, on the always-present central base door.
; =====================================================================================================
(script dormant void fe_kiosk_ammo
    (sleep_until
        (begin
            (fe_wait_at "#_door_interior_large_logo_03")
            (if (fe_transact "#_door_interior_large_logo_03" k_fe_cost_ammo)
                (fe_deliver_ammo)
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 5  -  LONGSWORD PASS, 3000, from Set 2.  Gated on SET rather than round, per the author's
;  pattern for his heavy rung.  Clears the current wave group; it does not end the match.
; =====================================================================================================
;  WE DO NOT DESTROY THE DEVICE (audit 25, RISK-G2).  Stock survival_resupply_pod_spawn drives this
;  same machine and then blocks on
;      (sleep_until (>= (device_get_position "dm_longsword_01") 0.4) 1)
;  before it wakes the weapon-drop pods.  An object_destroy landing inside that window removes the
;  device the stock loop is polling, so the condition can never become true and the resupply loop
;  never completes another cycle: no further weapon or grenade drops for the rest of the match.  That
;  destroy was the one unrecoverable interaction, so it is gone.  The rest self-heals: our
;  device_set_position_track ... 0 can reset the track under a stock animation, but our own
;  device_animate_position immediately drives the position to 1, past 0.4.  Stock calls
;  object_create and device_set_position_track on this machine at the head of EVERY resupply cycle
;  and destroys it itself at the end of each, so it needs nothing of ours to persist.  The cost is
;  cosmetic: until the next stock resupply the longsword sits at the end of its flight path.
(script static void fe_ct_deliver_strike
    (object_create "dm_longsword_01")
    (device_set_position_track "dm_longsword_01" "ff10" 0)
    (device_animate_position "dm_longsword_01" 1 10 3 3 false)
    (sleep 90)
    (ai_kill_no_statistics "gr_survival_waves")
    (sleep 120)
)

(script dormant void fe_kiosk_strike
    (sleep_until
        (begin
            (fe_wait_at "#_door_interior_large_logo_04")
            (if (fe_gate_set k_fe_gate_strike)
                (if (fe_transact "#_door_interior_large_logo_04" k_fe_cost_strike)
                    (fe_ct_deliver_strike)
                )
                (fe_deny "#_door_interior_large_logo_04")
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 6  -  MAC STRIKE, 10000, from Set 2.  THE WIN CONDITION, on the exposed forward terminal.
;  The beacon passed to fe_mission_won is the kiosk itself: Courtyard ships no cruiser scenery, and
;  inventing one would be a new object.
; =====================================================================================================
(script dormant void fe_kiosk_win
    (sleep_until
        (begin
            (fe_wait_at "health_pack2")
            ; VALIDATE BEFORE CHARGING (audit 29, RISK-R1).  fe_transact deducts k_fe_cost_win the moment
            ; it is reached, and fe_mission_won's own (not g_fe_won) / (not b_survival_game_end_condition)
            ; guard only ran afterwards - so buying during the bonus round, or in the seconds after any
            ; stock end condition fires, took 10,000 points and delivered nothing.  Both preconditions are
            ; now part of the kiosk's own test, so the sale is refused BEFORE any deduction.  The guard
            ; inside fe_mission_won stays as belt and braces.  No new script object: both globals already
            ; exist and are already referenced by this compile unit.
            (if (and (fe_gate_set k_fe_gate_win) (not g_fe_won) (not b_survival_game_end_condition))
                (if (fe_transact "health_pack2" k_fe_cost_win)
                    (fe_mission_won "health_pack2")
                )
                (fe_deny "health_pack2")
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
;
;  This script does NOT reparent anything and cannot: squad group membership is tag data.  Courtyard's
;  gr_survival_fireteams is squad group 6 and ships parented to group 5 gr_survival_waves, whose parent
;  is group 0 gr_survival_all - so without the reparent patch every purchased ally is counted by stock
;  survival_wave_living_count and the round never ends.  tools/patch/shop_build.py applies it.
; =====================================================================================================
(script continuous void fe_courtyard_ally_refresh
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
;  Opens the shop and wakes the six stations.  It touches NOTHING stock: not survival_wave_living_count,
;  not the wave machinery, not the drop-pod event, not the generator scripts.  That is only possible
;  because the allies sit in a squad group reparented to root, outside gr_survival_all, and because the
;  ally bodies are the fireteam squads rather than Bungie's drop squads.
; =====================================================================================================
(script startup void fe_courtyard_startup
    (sleep 30)
    ; MEASURED KIOSK RADIUS.  The library default is 2.5 world units, which is WRONG for
    ; this map: its closest two shop anchors (health_pack4 <-> #_door_interior_large_logo_03) are only 2.433 world
    ; units apart, so any radius >= 1.216 lets one standing position reach both kiosks and
    ; charge for both sales.  1.10 is the measured-safe value, taken straight from the
    ; placed-object coordinates in this map's own scnr tag.
    (set k_fe_kiosk_radius 1.10)
    (set g_fe_open true)
    (set g_fe_air_rotor 0)
    (set g_fe_bank 0)
    (set g_fe_buys 0)
    (set g_fe_spartan_buys 0)
    (set g_fe_won false)
    (wake fe_kiosk_reinforce)
    (wake fe_kiosk_spartan)
    (wake fe_kiosk_bank)
    (wake fe_kiosk_ammo)
    (wake fe_kiosk_strike)
    (wake fe_kiosk_win)
    (if g_fe_debug (print "fe: courtyard shop open"))
)
