; =====================================================================================================
;  ff60_icecave.hsc  -  GLACIER wiring for the Firefight Evolved Expanded purchase system
;  REWRITE 2026-11-23.  ZERO NEW SCRIPT OBJECTS.
;
;  Supersedes src/hsc/attic/ff60_icecave.design-era.hsc, which was written against the 54-object design
;  (new trigger volumes tv_fe_bank_in/out, new object names, a terminal at ps_wraith/p1).  Blamite's
;  ScriptCompiler can only REFERENCE a script object, never create one, so that file could not be
;  compiled against this cache at all.  It is kept because its map analysis is still correct and is
;  cited below; its object list is not.
;
;  Compiles as a unit after fe_shop_ctgl.hsc, which must itself come after the map's own 335-script
;  decompile.
;
;  TAG NAME -> FRIENDLY MAP NAME
;    scenario tag : levels\firefight\ff60_icecave\ff60_icecave
;    tag name     : ff60_icecave       <- what the engine, the scripts and the .map are named
;    map name     : Glacier            <- what the menu shows the player
;
;  Every object, squad, group and task named below was read out of ff60_icecave's own scnr tag with
;  build/logs/shop_survey.py and then PROVED by compiling against that cache: an object name the
;  scenario does not have is a hard compile failure here, not a warning (research/23 section 3).
;
;  =====================================================================================================
;  THE FIVE KIOSKS, AND THE ONE GENUINELY GOOD THING ABOUT GLACIER
;  =====================================================================================================
;  Glacier places six health_station device_controls with placement flags 0x00000000 - present from map
;  load with no script help.  ALL SIX FALL INSIDE TRIGGER VOLUME tv_wraith, whose runtime sector bounds
;  read x[-128.6,-83.5] y[241.0,275.6] z[-104.4,-100.3] out of the tag:
;
;    health_pack0  ( -94.68  272.45  -102.87)   TROOPERS, 4 bodies   500   always
;    health_pack1  (-104.93  273.77  -103.27)   SPARTANS, 2 bodies  1000   set   >= 1
;    health_pack2  ( -92.64  266.81  -102.85)   AMMO RESUPPLY        500   always
;    health_pack4  ( -98.86  261.46  -102.63)   BANK                 500   always
;    health_pack5  ( -97.76  258.22  -102.63)   DEMOLITION CHARGES  10000  set   >= 1   (THE WIN)
;    health_pack3  (-102.73  260.33  -102.64)   not used - left as a pure heal station
;
;  tv_wraith IS THE MAP'S OWN SHELTER AND BUNGIE LABELLED IT.  ff60_icecave's fragment script gates the
;  wraith01 / wraith02 shoot tasks on (not (volume_test_players tv_wraith)), so the Wraiths STOP
;  shelling while a player is inside that volume.  Every station of this shop is therefore inside the
;  one place on Glacier where the bombardment is scripted to pause.  That was the design's wish
;  (research/05 section 5.5) and it turns out to be free: the stations Bungie already placed are
;  already in there.
;
;  THE COST OF THAT, STATED PLAINLY: the design wanted the WIN terminal EXPOSED, out on the Wraith's
;  ground at one of the ps_wraith bombardment points, so the climax is a run through the barrage.  THAT
;  IS NOT REACHABLE WITH ZERO NEW OBJECTS.  Glacier's only always-present named interactive objects are
;  those six health stations and two doors (central_base_door_m60_unsc_doo, rear_base_door), and all
;  eight are inside tv_wraith.  ps_wraith/p0..p3 are point-set points, not objects, and
;  objects_distance_to_object cannot take one.  So Glacier's win is bought in shelter, and the run
;  through the barrage is the one piece of the Glacier design this port does not deliver.
;
;  The other cost is the same one every map pays: four of the six stations are health stations, so
;  standing at one to buy is standing at one to heal.  health_pack3 is the mitigation.
;
;  =====================================================================================================
;  WHAT GLACIER CANNOT SELL, READ OUT OF THE MAP AND NOT ASSUMED
;  =====================================================================================================
;  NO AIR SUPPORT, NO ORBITAL PASS, NO DROP PODS.  ff60_icecave is the only Firefight scenario in the
;  game with zero air-delivered objects, and the cache agrees with the script: Glacier has no
;  dm_longsword_01 at all (0 references in 5,564 lines of its own decompile), no sq_sur_drop_* squads,
;  no dm_drop_* machines, no dm_resupply_*/sc_resupply_*, no dm_target_*.  It is underground.  So there
;  is no air station and no Longsword station, and the trooper tier CANNOT arrive by pod - it walks in
;  from spawn points this port authors as tag data.
;
;  NO VEHICLE PURCHASE EITHER.  Glacier's only drivable-chassis squad is sq_sur_ghost_01 (vehicle
;  palette [6], ghost), and stock OWNS it: survival script L4946 runs
;  (f_load_phantom_cargo v_sur_phantom_01 "single" "sq_sur_ghost_01" none), i.e. a Phantom delivers
;  that Ghost as an ENEMY, and L4944 polls its health.  Selling it as an ally would collide with that
;  delivery.  The two Wraith squads are likewise driven by stock command scripts.  So Glacier's board
;  is the shortest of the set - five stations - and that is a property of the map, not an omission.
;
;  sur_fireteam_06 IS NOT TOUCHED, ANYWHERE.  On Glacier it is squad 23, parented to gr_survival_waves
;  (not to the fireteam group like its five siblings), flags 0x40 rather than 0x100, two spawn
;  formations, and one designer cell at 0x52DBAB4 which is the SAME BLOB sq_sur_wave_01 points at -
;  eight character choices resolving to brute, brute_captain, brute_chieftain_armor,
;  brute_chieftain_weapon.  It is a live Brute wave squad wearing a fireteam name.  Glacier therefore
;  has FIVE usable fireteam handles, not six; this port uses four (01-04) and leaves 05 free.
;
;  =====================================================================================================
;  NO STOCK SCRIPT IS EDITED.  THERE IS NO ff60_icecave_stock_hooks.hsc.
;  =====================================================================================================
;  But ONE TAG WRITE IS MANDATORY, and research/20 got this one wrong in a way worth naming.
;  Research/20 concluded Glacier needs no reparent because its gr_survival_fireteams (squad group 9)
;  hangs off group 1 gr_survival_extras, which is a root, so the chain never reaches gr_survival_all
;  and the stock wave counter is unaffected.  That is true, and it is not sufficient.  Stock
;  survival_wave_end_conditions calls
;        (ai_survival_cleanup "gr_survival_extras" true true)
;  at the end of EVERY WAVE (decompile L622, and again non-destructively at L681), and
;  ai_survival_cleanup on a group reaches its children.  Left as shipped, every ally the player buys is
;  deleted at the next wave boundary.  So Glacier needs the same 2-byte same-size write the other maps
;  need - set squad group 9's own `parent` to -1 - for a completely different reason.
;  tools/patch/shop_build.py applies it; research/23 section 4 records the offset and the before/after.
;
;  Each kiosk is a dormant script woken by fe_icecave_startup, which is the author's gating idiom
;  (research/14 section 6.5) and keeps the shop inert until the map says it is open.
; =====================================================================================================


; =====================================================================================================
;  STATION 1  -  TROOPERS, 500.  Four bodies, ON FOOT - Glacier has no pod infrastructure.
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
;  Spartans sit in gr_survival_fireteams like the troopers, so they consume the SAME budget.
;
;  Glacier's Spartan weapon pool is a CLOSE-QUARTERS pool, not Holdout's long-range one, because the
;  map is a cave and because its 21-entry weapon palette has no detached plasma turret.  See
;  research/23 section 5 for the four entries actually written.
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
;  STATION 3  -  AMMO RESUPPLY, 500.  ammo_crate0/1 are equipment[0..1], ammo_box, placement flags
;  0x00000101, so they are script-created - which is exactly how stock Glacier creates them.
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
;  STATION 4  -  BANK, 500 a press, shared across all players.  On Glacier the bank matters more than
;  on any other map: with no air support and no strike to shortcut a hold, saving toward the 10,000
;  charges is the only way the win is reachable, and banked points leave the live score so they survive
;  a round of buying troopers.
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
;  STATION 5  -  DEMOLITION CHARGES, 10000, from Set 2.  THE WIN CONDITION.
;
;  Priced at the author's own MAC rung (10,000) rather than the design-era 8,000, so all three ported
;  maps share one win price and the ladder stays his.  The fiction is the charges rigged on the shaft
;  the Covenant came down; mechanically it is fe_mission_won, which latches, blips, clears
;  gr_survival_all and calls game_won.  The beacon is the kiosk itself - Glacier ships no cruiser, and
;  inventing one would be a new object.
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
                    (fe_mission_won "health_pack5")
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
;
;  This script does NOT reparent anything and cannot: squad group membership is tag data.  Without the
;  reparent described in the header, the stock per-wave gr_survival_extras cleanup deletes every ally.
; =====================================================================================================
(script continuous void fe_icecave_ally_refresh
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
;  Opens the shop and wakes the five stations.  It touches NOTHING stock: not survival_wave_living_count,
;  not the wave machinery, not weapon_drop_control, not the Wraith command scripts.  Glacier's own
;  (script startup ff60_icecave ...) is left exactly as Bungie wrote it; this is a SECOND startup
;  script, which the compiler accepts - the Holdout build shipped the same arrangement.
; =====================================================================================================
(script startup void fe_icecave_startup
    (sleep 30)
    ; MEASURED KIOSK RADIUS.  The library default is 2.5 world units, which is WRONG for
    ; this map: its closest two shop anchors (health_pack4 <-> health_pack5) are only 3.422 world
    ; units apart, so any radius >= 1.711 lets one standing position reach both kiosks and
    ; charge for both sales.  1.45 is the measured-safe value, taken straight from the
    ; placed-object coordinates in this map's own scnr tag.
    (set k_fe_kiosk_radius 1.45)
    (set g_fe_open true)
    (set g_fe_air_rotor 0)
    (set g_fe_bank 0)
    (set g_fe_buys 0)
    (set g_fe_spartan_buys 0)
    (set g_fe_won false)
    (wake fe_kiosk_reinforce)
    (wake fe_kiosk_spartan)
    (wake fe_kiosk_ammo)
    (wake fe_kiosk_bank)
    (wake fe_kiosk_win)
    (if g_fe_debug (print "fe: glacier shop open"))
)
