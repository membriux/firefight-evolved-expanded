; =====================================================================================================
;  ff70_holdout.hsc  -  Holdout wiring for the Firefight Evolved Expanded purchase system
;  PORTED 2026-11-23 to the FIRETEAM-SQUAD pattern.  ZERO NEW SCRIPT OBJECTS.
;  Previous version: src/hsc/attic/ff70_holdout.drop-squad-pattern.hsc
; =====================================================================================================
;
;  Compiles as a unit after fe_shop_ctgl.hsc, which must itself come after the map's own decompile.
;  There is NO ff70_holdout_stock_hooks.hsc any more: the diff against Bungie's script text is EMPTY.
;
;  WHY THE PORT.  The first Holdout build used sq_sur_drop_01..04 as the ally bodies, because they
;  were the only Holdout squads that already carried both a populated cell and spawn points.  Three
;  things were wrong with that, all read out of Holdout's own decompile:
;
;    1. survival_drop_spawn (decompile L5462, woken at L4970) runs
;         (ai_erase "sq_sur_drop_01") (ai_erase "sq_sur_drop_02")
;         (ai_erase "sq_sur_drop_03") (ai_erase "sq_sur_drop_04")
;       at L5486-5489 on every cycle, and those four calls are NOT inside the
;       (if g_sur_drop_spawn ...) gates that follow them.  So every cycle deleted whatever the player
;       had bought, whatever the hook globals said.
;    2. The same script ends its cycle with (set g_sur_drop_spawn true) at L5518, which UNDOES the
;       (set g_sur_drop_spawn false) that ff70_holdout_stock_hooks.hsc performed at startup.  After
;       the first cycle the stock drop-pod event therefore resumed - and because the ally character
;       palette slot is Spartan-bodied, it resumed dropping Spartan-looking ENEMIES.
;    3. It needed an edit to Bungie's own globals at all.
;
;  Using sur_fireteam_01..04, whose spawn points this build authors as tag data, removes all three.
;  The stock drop-pod event is left exactly as shipped and still delivers Covenant enemies.
;
;  THE SIX KIOSKS.  Every anchor below is a placed object with placement flags 0x00000000, i.e. it
;  exists from map load with no script help, and every one is inside the player base.  Positions were
;  read out of ff70_holdout's own scnr tag (controls[3..8], machines[14..26]):
;
;    health_pack0         (440.80, 122.64, -7.25)   TROOPERS, 4 bodies    500   always
;    health_pack5         (442.30, 120.74, -2.89)   SPARTANS, 2 bodies   1000   set >= 1
;    #_m70_door_small_05  (441.52, 116.82, -7.85)   BANK                  500   always
;    #_m70_door_ff_02     (445.86, 117.43, -5.76)   AMMO RESUPPLY         500   always
;    #_m70_door_small_03  (448.54, 120.75, -7.85)   LONGSWORD PASS       3000   set >= 1
;    health_pack2         (443.27, 113.55, -5.07)   MAC STRIKE / WIN    10000   set >= 1
;
;  THE KIOSK RADIUS IS MEASURED, NOT ASSUMED.  The six anchors above were chosen, out of the sixteen
;  always-present candidates Holdout places, to maximise the minimum separation between any two of
;  them.  Measured minimum separation of this set: 4.635 world units (#_m70_door_ff_02 <->
;  #_m70_door_small_03).  One standing position can therefore reach two kiosks only if the radius is
;  >= 2.317.  The library default is 2.5, which WOULD have allowed it, so this file overrides it to
;  1.45 - the value Waterfront measured and shipped - leaving a 1.6x margin.
;
;  The previous Holdout board used health_pack3 and #_m70_door_ff_02, which are 1.333 world units
;  apart, with a 2.5 radius: standing between them triggered the LONGSWORD and the AMMO sale at once
;  and charged for both.  That pairing is gone.
;
;  The leading '#' survives the HaloScript lexer when quoted; proved against this cache before use.
;
;  WHAT HOLDOUT DOES NOT SELL, AND WHY.  No air tier.  sq_sur_banshee_01 and _02 are the only Holdout
;  squads with a vehicle cell, and Holdout's own stock script owns both of them:
;  survival_banshee_spawn (L5315, woken at L4969) runs (ai_place "sq_sur_banshee_01") /
;  ("sq_sur_banshee_02") on a timer, banshee_emp_kill (L5349) keeps acting on them afterwards, and
;  cs_banshee_01/_02 are their command scripts.  A purchased ally Banshee would be re-placed as an
;  enemy by that event, or would block it.  Disabling the event means editing Bungie's text, which
;  this port does not do - the same call Courtyard made for the same reason.
; =====================================================================================================
; =====================================================================================================
;  STATION 1  -  TROOPERS, 500.  Four DMR-armed bodies, walking in from the base respawn markers.
;  The cap is checked BEFORE the charge, so a full field refuses the sale rather than taking the
;  money and delivering nothing.
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
;  Spartans sit in gr_survival_fireteams like the troopers, so they consume the SAME budget.
; =====================================================================================================
(script dormant void fe_kiosk_spartan
    (sleep_until
        (begin
            (fe_wait_at "health_pack5")
            (if (fe_gate_set k_fe_gate_spartan)
                (if (fe_has_spartan_room)
                    (if (fe_transact "health_pack5" k_fe_cost_spartan)
                        (fe_deliver_spartans)
                    )
                    (fe_deny "health_pack5")
                )
                (fe_deny "health_pack5")
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
            (fe_wait_at "#_m70_door_small_05")
            (fe_bank_use "#_m70_door_small_05")
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
            (fe_wait_at "#_m70_door_ff_02")
            (if (fe_transact "#_m70_door_ff_02" k_fe_cost_ammo)
                (fe_deliver_ammo)
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)
; =====================================================================================================
;  STATION 5  -  LONGSWORD PASS, 3000, from Set 2.  Clears the current wave group; it does not end
;  the match.  The three device calls are exactly the ones Holdout's own stock weapon-resupply event
;  makes on this same machine (decompile L5737-5764), including the "ff10" position track.
;
;  dm_longsword_01 is machines[4] with placement flag bit0 set, and stock Holdout creates it the same
;  way for its own event.  A purchase landing inside that event's ~10 second animation window means
;  two owners for one device.  Courtyard ships the identical arrangement.
;
;  WE DO NOT DESTROY THE DEVICE (audit 25, RISK-G2).  That overlap was shipped as a "visual glitch",
;  and it was worse than that.  Stock survival_resupply_pod_spawn drives this same machine and then
;  blocks on
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
; =====================================================================================================
(script static void fe_ho_deliver_strike
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
            (fe_wait_at "#_m70_door_small_03")
            (if (fe_gate_set k_fe_gate_strike)
                (if (fe_transact "#_m70_door_small_03" k_fe_cost_strike)
                    (fe_ho_deliver_strike)
                )
                (fe_deny "#_m70_door_small_03")
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)
; =====================================================================================================
;  STATION 6  -  MAC STRIKE, 10000, from Set 2.  THE WIN CONDITION.  The beacon passed to
;  fe_mission_won is the kiosk itself: Holdout ships no cruiser scenery and inventing one would be a
;  new object.
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
;  The author's refresh_gate_marines pattern: allies drift off a follow task, so re-issue it.
;  ai_reset_objective takes `ai`, so it is called on the ally GROUP, covering all four ally squads in
;  one call.  Holdout's obj_fireteams/fireteams task already ships working - squad group filter 9
;  (gr_survival_fireteams), follow 1, follow radius 3.0 - so unlike Outpost it needs no task patch.
;
;  This script does NOT reparent anything and cannot: squad group membership is tag data.  Holdout's
;  gr_survival_fireteams is squad group 9 and ships parented to group 1 gr_survival_waves, whose
;  parent is group 0 gr_survival_all - so without the reparent patch every purchased ally is counted
;  by stock survival_wave_living_count and the round never ends.  tools/patch/shop_build.py applies
;  it, and the same write is what puts the ally squads inside the one group k_fe_actor_limit counts.
; =====================================================================================================
(script continuous void fe_holdout_ally_refresh
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
;  Opens the shop, sets the measured kiosk radius and wakes the six stations.  It touches NOTHING
;  stock: not survival_wave_living_count, not the wave machinery, not the drop-pod event, not the
;  banshee event, not the generator scripts.
; =====================================================================================================
(script startup void fe_holdout_startup
    (sleep 30)
    (set k_fe_kiosk_radius 1.45)
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
    (if g_fe_debug (print "fe: holdout shop open"))
)
