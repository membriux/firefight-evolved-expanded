; =====================================================================================================
;  ff60_airview.hsc  -  OUTPOST wiring for the Firefight Evolved Expanded purchase system
;  REWRITE 2026-11-23.  ZERO NEW SCRIPT OBJECTS.
;
;  Supersedes the earlier 554-line version of this file, which was written before research/18 and /19
;  and referenced 53 script objects Outpost does not contain.
; =====================================================================================================
;
;  Compiles as a unit after src/hsc/fe_reinforcements_wo.hsc.  Every object name, squad and squad group
;  named below was read out of ff60_airview's OWN scnr tag (build/wo/ff60_airview.stage2.survey.json).
;
;  THE SIX KIOSKS.  Outpost places six health_station device_controls with placement flags 0x00000000,
;  i.e. they exist from map load with no script help:
;
;    health_pack0  (-133.06, -128.38, 13.54)  TROOPERS, 4 bodies   500   always
;    health_pack1  (-130.55, -124.88, 13.49)  SPARTANS, 2 bodies  1000   set   >= 1
;    health_pack2  (-130.87, -130.10, 12.21)  BANK                 500   always
;    health_pack3  (-117.36, -132.09, 14.90)  MAC STRIKE / WIN   10000   set   >= 1
;    health_pack4  (-129.31, -131.83, 12.36)  AMMO RESUPPLY        500   always
;    health_pack5  (-127.46, -129.97, 12.36)  LONGSWORD PASS      3000   set   >= 1
;
;  FIVE OF THE SIX SIT INSIDE A 6-UNIT BALL on the Deck and health_pack3 is 13 units out from that
;  cluster.  That is a tighter shop than Holdout's, and it is a consequence of the map, not a choice:
;  the Deck is one small platform and Bungie put five stations on it.
;
;  THE STATION LAYOUT IS DRIVEN BY THAT GEOMETRY.  All fifteen pairwise distances were measured from
;  this map's own control block.  The closest pair is health_pack2-health_pack4 at 2.334 world units,
;  then health_pack4-health_pack5 at 2.62 and health_pack0-health_pack2 at 3.09; health_pack3's nearest
;  neighbour is 10.63 away.  So the 10,000-point WIN purchase goes on health_pack3, the one station
;  nobody can be standing at by accident, and the two 500-point purchases take the closest pair.
;  k_fe_kiosk_radius is set to 1.10 for this map in the startup script below, which is under half of
;  2.334, so no standing position is inside two stations' discs at once and no station can cross-trigger
;  another.  1.10 is the tightest radius in the project and it means the buyer must stand ON the pad.
;
;  WHY THE HEALTH STATIONS AND NOTHING ELSE.  Every other candidate was checked against this map's own
;  placement flags and positions, not inherited from the Holdout write-up:
;    * sc_hack_laser/rocket/sniper and sc_resupply_01..09 all carry placement flag bit0
;      ("not automatically") and sit in an off-map prop farm around (-98, -53, 17), some 80 world units
;      from the Deck at (-130, -130, 13).  Unreachable even if they existed.
;    * generator_switch0..2 also carry bit0.
;    * dm_resupply_01..09 and dm_target_01..03 ARE auto-placed on this map (flags 0x00000000, unlike
;      Waterfront where they are not) - but they are invis_resupply_capsule markers, i.e. invisible, and
;      the nearest is 14.6 units off the Deck.  An invisible shop is worse than a shared one.
;    * ammo_crate0/1 carry 0x101: they are the thing the ammo station CREATES, not an anchor.
;    * #_door_interior_large_logo_02..04 exist as object names on this map and the quoted-'#' lexer
;      trick is proven, but all three are tram-tunnel doors well away from the Deck.
;  So health_pack0..5 are the only always-present, visible, player-reachable interactive objects in the
;  play space.
;
;  COST OF THE CHOICE, STATED PLAINLY: these six objects are the map's health stations.  Standing at
;  one to buy is standing at one to heal, and the two uses are not separated.
;
;  NO VEHICLE TIER.  See fe_reinforcements_wo.hsc section 16: Outpost ships no banshee squad at all,
;  and its sq_sur_ghost_01/02 are delivered by stock as Phantom cargo (f_load_phantom_cargo), never by
;  ai_place.  That station sells ammo instead.
;
;  NO DROP PODS - AND THAT IS NOT A SIMPLIFICATION, IT IS THE MAP.  Outpost ships zero drop-pod
;  infrastructure: no sq_sur_drop_* squads, no dm_drop_* machines, no pod rails and no drop-pod
;  spawner, and its decompile has no g_sur_drop_spawn / g_sur_drop_limit globals at all.  Allies
;  therefore walk out of the respawn zone on foot.  This is the reason the whole ally design on both of
;  these maps is built on sur_fireteam_01..04 with authored spawn points rather than on Holdout's
;  borrowed drop squads.
;
;  OUTPOST-SPECIFIC CAUTIONS, ON RECORD:
;    1. ALLY CAP.  The Deck is one small platform and our earlier per-map analysis wanted its ally cap
;       at 6, not 12.  k_fe_actor_limit is 12 as the user asked.  EXPECT CONGESTION: twelve allies plus
;       the player plus the Covenant wave on a platform this size will visibly jam, and the shop sits in
;       the middle of it.  Dropping to 6 or 8 is one line in fe_reinforcements_wo.hsc.
;    2. THE TASK PATCH.  Unlike Waterfront, Outpost's obj_fireteams task `fireteams` ships as a STUB:
;       follow = 0 (none), follow radius 0.0, Z clamp 0.0, squad group filter -1.  Read out of the tag.
;       Four same-size writes turn it into a follow task - follow = 1, radius 8.0, Z clamp 1.0, filter
;       9 = gr_survival_fireteams.  Every written value is attested in THIS map's own objectives
;       (sniper_01, remaining, hero_follow, main_follow and bonus_follow all carry follow 1 / radius 8 /
;       Z clamp 1).  WITHOUT THAT PATCH the allies spawn and fight but never follow the player.  The
;       radius is 8 rather than Waterfront's 3 because 8 is the value this map attests; on a platform
;       this crowded the looser leash is also the kinder one.
;
;  Each kiosk is a dormant script woken by fe_outpost_startup, which is the author's gating idiom
;  (research/14 section 6.5) and keeps the shop inert until the map says it is open.
; =====================================================================================================


; =====================================================================================================
;  STATION 1  -  TROOPERS, 500.  Four bodies on foot from whichever of sur_fireteam_01 / _02 is
;  EMPTY (round-2 fix OP-1/OP-2; the old build rotated positionally and could re-place a live squad).
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
;  STATION 3  -  AMMO RESUPPLY, 500, on health_pack4.  Two ammo boxes on the Deck, created the same
;  way stock does.
; =====================================================================================================
(script dormant void fe_kiosk_ammo
    (sleep_until
        (begin
            (fe_wait_at "health_pack4")
            (if (fe_transact "health_pack4" k_fe_cost_ammo)
                (fe_deliver_ammo)
            )
            (sleep k_fe_cooldown)
            false
        )
    )
)

; =====================================================================================================
;  STATION 4  -  LONGSWORD PASS, 3000, from Set 2, on health_pack5.  Gated on SET rather than round, per the author's
;  pattern for his heavy rung.  Clears the living wave.
; =====================================================================================================
(script dormant void fe_kiosk_strike
    (sleep_until
        (begin
            (fe_wait_at "health_pack5")
            (if (fe_gate_set k_fe_gate_strike)
                (if (fe_transact "health_pack5" k_fe_cost_strike)
                    (fe_deliver_strike)
                )
                (fe_deny "health_pack5")
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
;  STATION 6  -  MAC STRIKE, 10000, from Set 2, on health_pack3 - the one station 10 world units clear
;  of every other, so the most expensive purchase in the game cannot be triggered by accident.  This is
;  the win condition.
; =====================================================================================================
(script dormant void fe_kiosk_win
    (sleep_until
        (begin
            (fe_wait_at "health_pack3")
            ; VALIDATE BEFORE CHARGING (audit 29, RISK-R1).  fe_transact deducts k_fe_cost_win the moment
            ; it is reached, and fe_mission_won's own (not g_fe_won) / (not b_survival_game_end_condition)
            ; guard only ran afterwards - so buying during the bonus round, or in the seconds after any
            ; stock end condition fires, took 10,000 points and delivered nothing.  Both preconditions are
            ; now part of the kiosk's own test, so the sale is refused BEFORE any deduction.  The guard
            ; inside fe_mission_won stays as belt and braces.  No new script object: both globals already
            ; exist and are already referenced by this compile unit.
            (if (and (fe_gate_set k_fe_gate_win) (not g_fe_won) (not b_survival_game_end_condition))
                (if (fe_transact "health_pack3" k_fe_cost_win)
                    (fe_mission_won "health_pack3")
                )
                (fe_deny "health_pack3")
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
;  four ally squads in one call.  On this map the refresh is doing real work: the task it re-issues is
;  the one the tag patch above turned from a stub into a follow task.
; =====================================================================================================
(script continuous void fe_outpost_ally_refresh
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
;  not the wave machinery, not the generator scripts.  Outpost needs no stock-script edit because the
;  ally bodies are sur_fireteam_01..04, which stock declares and binds (ai_sur_fireteam_squad0..5) but
;  never places, wakes or cleans up - all 12 references in this map's own decompile are the six
;  declarations plus the six `set`s.  No stock cell references the repointed character palette entry
;  [24], so no stock enemy changes appearance.
; =====================================================================================================
(script startup fe_outpost_startup
    (sleep 30)
    ; Outpost's measured kiosk separation allows only 1.10; see fe_reinforcements_wo.hsc section 2.
    (set k_fe_kiosk_radius 1.10)
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
    (if g_fe_debug (print "fe: outpost shop open"))
)
