; =====================================================================================================
;  ff30_waterfront.hsc  -  WATERFRONT wiring for the Firefight Evolved Expanded purchase system
;  REWRITE 2026-11-23.  ZERO NEW SCRIPT OBJECTS.
;
;  Supersedes the earlier 557-line version of this file, which was written before research/18 and /19
;  and referenced 53 script objects Waterfront does not contain.
; =====================================================================================================
;
;  Compiles as a unit after src/hsc/fe_reinforcements_wo.hsc.  Every object name, squad and squad group
;  named below was read out of ff30_waterfront's OWN scnr tag (build/wo/ff30_waterfront.stage2.survey.json).
;
;  THE SIX KIOSKS.  Waterfront places six health_station device_controls with placement flags
;  0x00000000, i.e. they exist from map load with no script help, all six inside the player base:
;
;    health_pack0  (  4.42, 222.97, 44.95)   TROOPERS, 4 bodies   500   always
;    health_pack1  (  7.54, 226.20, 44.95)   SPARTANS, 2 bodies  1000   set   >= 1
;    health_pack2  (  7.54, 222.68, 44.95)   BANK                 500   always
;    health_pack3  (  6.70, 219.76, 44.95)   AMMO RESUPPLY        500   always
;    health_pack4  ( 12.20, 212.00, 44.16)   LONGSWORD PASS      3000   set   >= 1
;    health_pack5  ( 16.14, 211.70, 44.16)   MAC STRIKE / WIN   10000   set   >= 1
;
;  WHICH PURCHASE WENT ON WHICH PAD IS NOT ARBITRARY.  All fifteen pairwise distances were measured
;  from this map's own control block.  The closest pair is health_pack2-health_pack3 at 3.038 world
;  units and the widest-separated pair in the base is health_pack4-health_pack5 at 3.95.  The two
;  expensive purchases - the 3,000 Longsword and the 10,000 win - therefore sit on pads 4 and 5, the
;  pair hardest to confuse, and the two 500-point purchases sit on the closest pair.  k_fe_kiosk_radius
;  is set to 1.45 for this map in the startup script below, which is under half of 3.038, so no
;  standing position is inside two stations' discs at once and no station can cross-trigger another.
;
;  WHY THE HEALTH STATIONS AND NOTHING ELSE.  Every other candidate was checked against this map's own
;  placement flags and positions, not inherited from the Holdout write-up:
;    * sc_hack_laser/rocket/sniper/target and sc_resupply_01..09 all carry placement flag bit0
;      ("not automatically"), so they do not exist until a script creates them, AND they sit in an
;      off-map prop farm around (-20, 244, 58) - roughly 25 world units from the base at (8, 222, 45)
;      and 13 units above it, where no player can reach them.
;    * generator_switch0..2 also carry bit0, and so do dm_resupply_01..09 and dm_drop_01..05.
;    * ammo_crate0/1 carry 0x101: they are the thing the ammo station CREATES, not an anchor.
;  That leaves health_pack0..5 as the only always-present, player-reachable interactive objects in the
;  base - which is exactly the conclusion Holdout reached, re-derived here from Waterfront's bytes.
;
;  COST OF THE CHOICE, STATED PLAINLY: these six objects are the map's health stations.  Standing at
;  one to buy is standing at one to heal, and the two uses are not separated.  Waterfront has no door
;  or other always-placed visible interactive object to move them onto - unlike Holdout, whose ten
;  #_m70_door_* machines gave it a seventh anchor - so the overlap cannot be reduced on this map.
;
;  NO VEHICLE TIER.  See fe_reinforcements_wo.hsc section 16: Waterfront's own stock
;  survival_banshee_spawn already ai_places sq_sur_banshee_01/02, so a purchase cannot place them
;  again safely.  That station sells ammo instead.
;
;  WATERFRONT-SPECIFIC CAUTION, ON RECORD: this is the densest hostile geometry of the seven-map set,
;  and our earlier per-map analysis wanted its ally cap at 10.  k_fe_actor_limit is 12 as the user
;  asked.  Expect queueing around the base ramps and the water edge with a full ally field; dropping to
;  10 is one line in fe_reinforcements_wo.hsc.
;
;  Each kiosk is a dormant script woken by fe_waterfront_startup, which is the author's gating idiom
;  (research/14 section 6.5) and keeps the shop inert until the map says it is open.
; =====================================================================================================


; =====================================================================================================
;  STATION 1  -  TROOPERS, 500.  Four bodies on foot from whichever of sur_fireteam_01 / _02 is
;  EMPTY (round-2 fix WF-1/WF-2; the old build rotated positionally and could re-place a live squad).
;  The cap AND the per-squad emptiness test are both inside fe_has_room, which is checked BEFORE the
;  charge, so a full field hits (fe_deny "health_pack0") rather than taking the money and delivering
;  nothing.
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
;  Two gates, both checked before the charge: the shared ally budget (k_fe_actor_limit, 12) and the
;  Spartan sub-cap (k_fe_spartan_limit, 4).  Spartans sit in gr_survival_fireteams like the troopers,
;  so they consume the SAME budget - buying Spartans costs you troopers, which is the whole point.
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
;  STATION 3  -  AMMO RESUPPLY, 500, on health_pack3.  Two ammo boxes inside the base, created the
;  same way stock does.
; =====================================================================================================
(script dormant void fe_kiosk_ammo
    (sleep_until
        (begin
            (fe_wait_at "health_pack3")
            (if (fe_transact "health_pack3" k_fe_cost_ammo)
                (fe_deliver_ammo)
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 4  -  LONGSWORD PASS, 3000, from Set 2, on health_pack4.  Gated on SET rather than round, per the author's
;  pattern for his heavy rung.  Clears the living wave.
; =====================================================================================================
(script dormant void fe_kiosk_strike
    (sleep_until
        (begin
            (fe_wait_at "health_pack4")
            (if (fe_gate_set k_fe_gate_strike)
                (if (fe_transact "health_pack4" k_fe_cost_strike)
                    (fe_deliver_strike)
                )
                (fe_deny "health_pack4")
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 5  -  BANK, 500 a press, shared across all players, on health_pack2.
; =====================================================================================================
(script dormant void fe_kiosk_bank
    (sleep_until
        (begin
            (fe_wait_at "health_pack2")
            (fe_bank_use "health_pack2")
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 6  -  MAC STRIKE, 10000, from Set 2.  This is the win condition.
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
;  re-issue it.  ai_reset_objective takes `ai`, so it is called on the ally GROUP, which covers all
;  four ally squads in one call.
;
;  Waterfront's obj_fireteams task `fireteams` is ALREADY a follow task in stock - follow = player,
;  follow radius 3.0, Z clamp 1.0, squad group filter 6 = gr_survival_fireteams - so unlike Outpost
;  this map needs no task patch at all.  Read out of the tag, not assumed.
; =====================================================================================================
(script continuous void fe_waterfront_ally_refresh
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
;  not the wave machinery, not the generator scripts, not g_sur_drop_spawn.  Waterfront needs no
;  stock-script edit because the ally bodies are sur_fireteam_01..04, which stock declares and binds
;  (ai_sur_fireteam_squad0..5) but never places, wakes or cleans up - all 12 references in this map's
;  own decompile are the six declarations plus the six `set`s.  The stock drop-pod event and its
;  sq_sur_drop_01..05 squads are left completely alone, and none of their cells reference the
;  repointed character palette entry [23], so no stock enemy changes appearance.
; =====================================================================================================
(script startup fe_waterfront_startup
    (sleep 30)
    ; Waterfront's own measured kiosk separation allows 1.45; see fe_reinforcements_wo.hsc section 2.
    (set k_fe_kiosk_radius 1.45)
    (set g_fe_open true)
    (set g_fe_rotor 0)
    (set g_fe_spartan_rotor 0)
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
    (if g_fe_debug (print "fe: waterfront shop open"))
)
