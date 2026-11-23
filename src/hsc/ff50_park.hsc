; =====================================================================================================
;  ff50_park   -   BEACHHEAD, "LAST BUS OUT OF NEW ALEXANDRIA"
;
;  TAG NAME -> FRIENDLY MAP NAME
;    scenario tag : levels\firefight\ff50_park\ff50_park
;    tag name     : ff50_park        <- this is what the engine, the scripts and the .map are named
;    map name     : Beachhead        <- this is only what the menu shows the player
;    Bungie's own script for this map is research/_raw/hsc/ff50_park_main.hsc, 1579 lines, and its
;    startup script is (script startup ff50_park ...) at L109-208. The file and the startup script in
;    this pack are named to match, because the previous name "beachhead" has no engine referent.
;
;  Design source: research/05-map-scenario-designs.md section 5.1
;  Engine facts  : research/11-stock-map-spawn-geography.md section 6
;  Requires      : fe_reinforcements.hsc compiled BEFORE this file.
;
;  *** STARTUP SCRIPT COLLISION - READ BEFORE COMPILING ***
;  The stock ff50_park_main.hsc already declares (script startup ff50_park ...). A scenario cannot
;  hold two startup scripts of the same name. Do ONE of these:
;    (a) PREFERRED - delete the (script startup ff50_park ...) declaration below and paste its body
;        (the ten lines between the two PASTE markers) just before the closing paren of the stock
;        startup at ff50_park_main.hsc L207.
;    (b) Remove the stock declaration and keep this one - but then you must also copy the stock
;        configuration block (ff50_park_main.hsc L115-205: allegiances, zone set, fireteam squads,
;        phantom squads and sides right/right/left/left, gr_survival_waves, 6 squads per wave, the
;        twelve generator objects, sq_sur_remaining, k_sur_wave_timer 0, sq_ff_bonus, and the
;        survival_drop_spawn / survival_mode / survival_resupply_pod_spawn wakes) into it, or the map
;        will not run Firefight at all.
;
;  WIN   buy PELICAN DUST-OFF (8,000, not before round 5) AT THE EXPOSED TERMINAL, then hold the
;        Pavilion Roof for 120 s.
;  LOSE  (a) standard life exhaustion - stock survival_mode_end_condition_lives handles it;
;        (b) transport power couplings destroyed - KEPT ON THIS MAP, see the generator note below;
;        (c) backstop: wave 16 completed with no dust-off = district glassed.
;
;  CATALOGUE  (prices retuned to the author's measured income, ~2,000-2,500 a round - see
;              fe_reinforcements.hsc section 1. [A] = his shipped price, [D] = derived on his ladder.)
;                                               cost   gate   script
;    Marine squad (3-4, AR + DMR)                500 [A]  -    bh_buy_marines
;    ODST squad (4, 1 rocket, 1 shotgun)         750 [A]  -    bh_buy_odst       pod, beside ammo_crate0
;    Machinegun turret (Terrace or Bridge)       750 [A]  -    bh_buy_turret
;    Turret upgrade (rocket)                   1,000 [D]  R2   bh_buy_turret_upgrade
;    Ghost (player usable)                     1,000 [A]  R2   bh_buy_ghost      see vehicle note
;    Orbital strike on the access road         3,000 [D]  R3   bh_buy_strike
;    Bank kiosk, deposit or withdraw             500 [A]  -    fe_bank_deposit / fe_bank_withdraw
;    PELICAN DUST-OFF (win)                    8,000 [D]  R5   bh_buy_dustoff    EXPOSED TERMINAL
;
;  THE EXPOSED WIN TERMINAL - ps_wraith/p2
;  The author exiles Unearthed's MAC Cannon terminal to the Crane, outside the defensible area, so the
;  climax is a run through the barrage (research/10 section 3.2). Beachhead's equivalent is the best of
;  the six, because Bungie labelled the exposed ground for us: ps_wraith is the Wraith's own
;  bombardment point set, p0-p3, driven by (cs_shoot_point) in cs_wraith_shoot, ff50_park_main.hsc
;  L747-776. [V] Those four points ARE the ground the map shells. Put tv_fe_buy_dustoff at whichever of
;  p0-p3 reads farthest from ammo_crate0 and from ps_gen/gen0-gen2 in Sapien - p2 is the placeholder
;  name in this file - and keep it OUTSIDE tv_wraith_01 and tv_wraith_02, which are the volumes the
;  fragments test to call the Wraith off (ff50_park_fragments.hsc L23-26 [V]); inside them is shelter,
;  which is the opposite of what this terminal is for.
;  Named tag objects only. No coordinate for any of them exists in any public source - read them in
;  Sapien. Do not invent one.
;
;  THE BANK  (new, from research/10 section 1.2 - his own co-op fix, shipped the day after launch)
;    tv_fe_bank_in / tv_fe_bank_out [NEW], 500 a press, beside ammo_crate0 on the route players already
;    walk - his I04 kiosks sit "on the beam tower's internal ramps next to the health pack". Banked
;    points leave the live score, so they cannot be spent on marines by accident and the 8,000 dust-off
;    becomes a plan. g_fe_bank must survive the set boundary; see fe_reinforcements.hsc section 6a.
;
;  REMOVED SINCE THE LAST VERSION, AND WHY
;    Rocket Warthog + Gauss upgrade - the justification was "Wraith terrain verified". It was wrong.
;      Beachhead's Wraiths are sq_sur_wraith_01/_02 driven by (cs_shoot_point ps_wraith/p0-p3) in
;      cs_wraith_shoot, ff50_park_main.hsc L747-776 - a stationary bombardment script on four fixed
;      points. It proves the Wraith sits still and shells, and a Wraith hovers anyway. No shipped
;      script on this map spawns or moves any wheeled vehicle. See fe_reinforcements.hsc section 2a.
;    Falcon gunner ride - no map of the six references ANY UNSC aircraft. The only UNSC flight path in
;      shipped Reach Firefight is ps_sur_pelican on cex_ff_halo. Pure new content with no precedent.
;    The Ghost REPLACES them, on real evidence: ff50_park_main.hsc names sq_sur_ghost_01 and
;      sq_sur_ghost_02 and the stock Phantoms deliver them, so the engine demonstrably spawns and
;      moves a Ghost chassis on this map. [V]
;
;  GENERATOR LOSS CONDITION - VALID HERE. Beachhead is one of only TWO target maps where generator
;  defence is actually authored. ff50_park_main.hsc has the point set ps_gen with points gen0/gen1/
;  gen2 (L238-256), the command scripts cs_gen0/cs_gen1/cs_gen2 that send AI to them, and the
;  obj_survival/gen0-gen2 AI tasks with gen0_boost-gen2_boost gated on 3+ players
;  (ff50_park_fragments.hsc). On the other four target maps the Covenant have only the generic
;  "generator" task and no approach points, so a generator loss condition there is decoration. [V]
;
;  =====================================================================================================
;  SCENARIO PREREQUISITES - author these in Sapien, they are NOT scriptable
;  =====================================================================================================
;  [NEW] means it does not exist in the stock tag. [V] means it is already there, spelled exactly so.
;
;    squad group   gr_unsc_reinforcements      [NEW]
;        *** PARENTING WARNING ***  Child of NOTHING. Not gr_survival_all (waves never end -
;        global_firefight.hsc L665-674), and NOT gr_survival_extras either. Bungie's checklist puts
;        gr_survival_marines under gr_survival_extras; copying that is a trap. gr_survival_extras is
;        culled by (ai_survival_cleanup gr_survival_extras TRUE TRUE) every wave, and on three of the
;        pod maps it gates the Covenant pod spawner on reaching zero. Beachhead itself does not
;        reference gr_survival_extras in script, but keeping friendlies out of it is the rule
;        everywhere so the pack behaves identically on all six maps.
;    squad group   gr_unsc_followers           [NEW]  child of gr_unsc_reinforcements
;    squads        sq_fe_garrison    [NEW]  team = human, **6 CELLS** - the FREE squad that
;                  arrives at match start and is topped back up to 6 at the start of every
;                  round. Cell count is a scenario tag field (the squad's cells block, per-cell
;                  'spawn count'); no script can change it. README.md section 2b0.
;                  sq_fe_marines     [NEW]  team = human, **8 CELLS** - the bought 500-point squad
;                  sq_fe_odst        [NEW]  team = human, **8 CELLS** - the bought 750-point squad
;                  sq_fe_gunner      [NEW]  team = human, 1 cell
;                  NOTE the deliberate absence of _sur_ in these names: _sur_ marks the survival tree.
;    objective     obj_marines                 [NEW on this map]  copied from cex_ff_halo. Tasks
;                  gate_marines, gate_marines_followers, gate_marines_defenders. See README section 2d.
;                  obj_survival already exists and is left alone. [V]
;    point set     ps_gen  with points gen0, gen1, gen2          [V]  ff50_park_main.hsc L238-256.
;                  USE THESE as the task areas for obj_marines/gate_marines_defenders. They are the
;                  best-evidenced defensible friendly ground on any of the six maps: Bungie authored
;                  both the points and (cs_enable_pathfinding_failsafe TRUE) ground command scripts
;                  that walk AI to them, so pathing there is proven.
;    anchors       ammo_crate0, ammo_crate1                      [V by convention]
;                  Global defaults, present on every Firefight map (global_firefight.hsc L54-55),
;                  created and HUD-tracked at L3177-3196. Put the terminal volumes and the friendly
;                  arrival spawn points here. Read the positions out of the tag - no coordinate for
;                  them exists in any public source.
;    avoid         kill_sur_room_01 - kill_sur_room_08   [V]  the eight Covenant spawn rooms
;                  ps_wraith/p0 - p3                     [V]  the Wraith's four bombardment targets
;                  tv_wraith_01, tv_wraith_02            [V]  ff50_park_fragments.hsc L23-26
;                  sq_sur_drop_01 - sq_sur_drop_04 spawn points [V] Covenant pod lanes
;    trigger vols  tv_fe_board        [NEW] the terminal, beside ammo_crate0
;                  tv_fe_roof         [NEW] the Pavilion Roof hold area for the win timer
;                  one volume per catalogue entry, all side by side at the terminal:
;                    tv_fe_buy_marines  tv_fe_buy_odst   tv_fe_buy_turret
;                    tv_fe_buy_turret_up tv_fe_buy_ghost tv_fe_buy_strike   [NEW]
;                  tv_fe_bank_in, tv_fe_bank_out   [NEW] the two bank kiosks, also at the terminal
;                  tv_fe_buy_dustoff  [NEW] *** NOT at the terminal. *** At ps_wraith/p2, outside
;                    tv_wraith_01 / tv_wraith_02. See the exposed-terminal note in the header.
;    device        dm_fe_pod_01       [NEW] friendly pod rail. The pattern is proven on this map -
;                  dm_drop_01 - dm_drop_04 and sq_sur_drop_01 - sq_sur_drop_04 all exist [V] - but a
;                  pod lands at the SQUAD'S tag spawn point, so you need a new rail and a new
;                  sq_fe_odst/driver spawn point. Do not reuse a Covenant site: those are enemy lanes.
;    objects       sc_fe_turret_01    [NEW] turret (shade/machinegun), "initially placed" off
;                  sc_fe_ghost        [NEW] the bought Ghost, placed beside ammo_crate0
;                  sc_fe_pelican      [NEW] the dust-off Pelican. Model its command script on
;                                     cs_ff_halo_pelican, cex_ff_halo_main.hsc L851-912, which is the
;                                     one working UNSC flight path in shipped Reach Firefight. [V]
; =====================================================================================================

(global boolean g_bh_dustoff_bought FALSE)
(global boolean g_bh_turret_built   FALSE)
(global boolean g_bh_ghost_built    FALSE)
(global boolean g_bh_strike_used    FALSE)
(global short   g_bh_hold_left      120)      ; seconds of roof hold still required
(global short   g_bh_last_wave      -2)
(global short   g_bh_gate_round      0)       ; last absolute round whose gate banner has been shown
(global vehicle v_fe_pod_01         NONE)

; =====================================================================================================
;  STARTUP - named for the scenario tag, per Bungie's convention
;  (script startup ff20_courtyard ...), (script startup ff50_park ...), (script startup cex_ff_halo ...)
;  See the collision warning in the header before you compile this.
; =====================================================================================================
(script startup ff50_park
    ; ---------------- PASTE MARKER: START OF FE ADDITIONS -------------------------------------------
    (sleep 5)
    (set ai_fe_group     gr_unsc_reinforcements)
    (set ai_fe_followers gr_unsc_followers)
    (set ai_fe_garrison  sq_fe_garrison)
    (set ai_fe_marines   sq_fe_marines)
    (set ai_fe_odst      sq_fe_odst)
    (set ai_fe_gunner    sq_fe_gunner)

    ; FRIENDLY CAP: 12, the pack default, and this is the map with the best case for carrying it.
    ; Beachhead is the only target map besides Holdout with ps_gen/gen0-gen2 and ready-made cs_gen0-
    ; cs_gen2 command scripts, i.e. three defensible positions Bungie itself already proved AI can
    ; path to (research/11 section 6.2 calls it "the lowest-risk friendly placement available anywhere
    ; in the six maps"). Spreading the garrison and a bought squad over three authored anchors instead
    ; of one is what stops fourteen bodies becoming one traffic jam.
    ; See fe_reinforcements.hsc section 2.4 for where 12 comes from and why it is DERIVED, not an
    ; engine constant.
    (set k_fe_actor_limit 12)
    (set k_fe_free_squad_size 6)

    (wake fe_garrison_watch)        ; free 6-man garrison: match start + every round start
    (wake fe_slots_banner_watch)    ; "slots full" / "slots available" HUD edges
    (wake bh_mission_start)
    (wake bh_board)
    (wake bh_escalation)
    (wake bh_gates)
    (wake bh_backstop)
    ; ---------------- PASTE MARKER: END OF FE ADDITIONS ---------------------------------------------
)

; =====================================================================================================
;  MISSION TRIGGER - reaching the terminal, or 45 s, opens the purchase board
;  volume_test_players is hsdoc_hr.txt L216 and stock uses it widely
;  (ff50_park_fragments.hsc L23-26, ff50_park_main.hsc L783). [V]
; =====================================================================================================
(script dormant bh_mission_start
    (sleep_until (or (volume_test_players tv_fe_board) (volume_test_players tv_fe_roof)) 15 1350)
    (fe_board_open)
    (fe_notify "bh_board_online")              ; [G] string id must exist, see fe_notify notes
    (sound_impulse_start sfx_blip NONE 1)      ; stock blip, ff20_courtyard.hsc L780 [V]
)

; =====================================================================================================
;  PURCHASE BOARD
;  Mechanism: stand in the item's volume and press the action/reload key.
;  player_action_test_reset / player_action_test_action are hsdoc_hr.txt L2627 and L2663. [V functions]
;  [G] No shipped Firefight script polls player_action_test_*, and the action key is also Reload, so
;  reloading at the terminal will buy. The alternative is a player-usable device_machine switch per
;  item, polled with (device_get_position ...) exactly as stock polls the generator switches
;  (global_firefight.hsc L1934-1975); that needs extra tag work. See README section 5.
;  Beachhead has a second option no other map but Holdout has: generator_switch0 - generator_switch2
;  are real device controls sited at ps_gen/gen0 - gen2, so they are proven reachable and proven
;  interactive. Repurposing one as a purchase switch avoids inventing an interaction - but it collides
;  with Generator Defense, which this scenario keeps on. [V on the objects, design call is yours]
; =====================================================================================================
(script continuous bh_board
    (sleep_forever)
    (sleep_until
        (begin
            (player_action_test_reset)
            (sleep 5)
            (if (and g_fe_board_open (player_action_test_action))
                (begin
                    (if (volume_test_players tv_fe_buy_marines)   (bh_buy_marines))
                    (if (volume_test_players tv_fe_buy_odst)      (bh_buy_odst))
                    (if (volume_test_players tv_fe_buy_turret)    (bh_buy_turret))
                    (if (volume_test_players tv_fe_buy_turret_up) (bh_buy_turret_upgrade))
                    (if (volume_test_players tv_fe_buy_ghost)     (bh_buy_ghost))
                    (if (volume_test_players tv_fe_buy_strike)    (bh_buy_strike))
                    (if (volume_test_players tv_fe_buy_dustoff)   (bh_buy_dustoff))
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

; Every buy script re-checks affordability, cooldown, slot and round gate itself, so it is always
; safe to call one unconditionally.

; =====================================================================================================
;  T0  MARINES - 500
;  They defend rather than follow: Beachhead's ps_gen/gen0 - gen2 are the three best-evidenced
;  defensible positions in the pack, so author obj_marines/gate_marines_defenders with its task areas
;  AT those three points. fe_squad_hold assigns that task and starts the re-arm loop.
; =====================================================================================================
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void bh_buy_marines
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
            (fe_notify "bh_bought_marines")
        )
    )
)

; =====================================================================================================
;  T0+ ODSTs - 750, delivered by drop pod beside ammo_crate0
;  Structure is Bungie's hazard pod, ff20_courtyard.hsc L511-545, and the same shape appears four
;  times in ff50_park_main.hsc as drop_pod_01 - drop_pod_04. [V]
;  The two lines before fe_pod_sequence must stay here, not in the library: the spawn-point reference
;  sq_fe_odst/driver has to be a literal, exactly as stock does it (ff20_courtyard.hsc L518). [V]
;  These ODSTs FOLLOW the buyer, via obj_marines/gate_marines_followers.
; =====================================================================================================
;  AVAILABILITY: every wave of every round. The old gate required the previous squad to be ENTIRELY
;  dead before you could buy again; it is now a concurrent-slot test, so you may re-buy as soon as
;  casualties have freed k_fe_buy_min_fill slots under this map's k_fe_actor_limit. The price is
;  unchanged at the author's own post-playtest number even though the squad is now 8 cells instead of
;  4 - see fe_reinforcements.hsc section 1 and README.md section 2j for why bigger does not mean dearer.
(script static void bh_buy_odst
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
            (fe_notify "bh_bought_odst")
        )
    )
)

; =====================================================================================================
;  MACHINEGUN TURRET - 750 ungated, and its rocket upgrade - 1,000 gated to round 2
;  750 is the author's own shipped turret price, never gated on either of his maps: a turret is a
;  fortification you buy on reflex at the position you are defending. The variant upgrade takes his
;  Round 2 upgrade gate (his Gauss upgrade), announced by bh_gates.
;  object_create_anew is hsdoc_hr.txt L300 [V]; object_create_variant is used by stock to swap a
;  scenario object for a different variant (ff20_courtyard.hsc L747-757). [V]
;  [G] Crewing the turret with vehicle_load_magic (hsdoc_hr.txt L1025) is not done by any shipped
;  Firefight script, although cex_ff_halo_main.hsc L865-868 does use vehicle_load_magic to load a
;  Warthog into a Pelican, which proves the opcode works on a real object. ai_place_in_vehicle
;  (L1289) is the documented alternative and needs a vehicle squad authored in the scenario. If
;  neither works, ship the turret unmanned - a player-usable turret is still a purchase.
; =====================================================================================================
(script static void bh_buy_turret
    (if (and (not g_bh_turret_built) (fe_try_buy k_fe_cost_turret))
        (begin
            (object_create_anew sc_fe_turret_01)
            (ai_object_set_team sc_fe_turret_01 player)    ; stock uses this on generators,
                                                           ; global_firefight.hsc L1728 [V]
            (ai_place ai_fe_gunner)
            (sleep 1)
            (vehicle_load_magic sc_fe_turret_01 "" (ai_actors ai_fe_gunner))   ; [G]
            (set g_bh_turret_built TRUE)
            (fe_notify "bh_bought_turret")
        )
    )
)

(script static void bh_buy_turret_upgrade
    (if (and g_bh_turret_built
             (fe_gate_open k_fe_gate_upgrade)
             (fe_try_buy k_fe_cost_turret_upgrade))
        (begin
            ; [G] "rocket" must be a real variant name on the turret's object tag. Stock variant
            ; strings on Beachhead's own ordnance are "laser" / "rocket" / "sniper"
            ; (ff20_courtyard.hsc L755-757, and the same block in ff50_park_main.hsc) - check the
            ; turret tag in Foundation.
            (object_create_variant sc_fe_turret_01 "rocket")
            (fe_notify "bh_bought_turret_upgrade")
        )
    )
)

; =====================================================================================================
;  GHOST - 1,000, round 2 gate. The only vehicle sold on this map, and the only one with real evidence.
;  Price and gate are both the author's, taken off his Rocket Warthog: 1,500->1,000 after playtest,
;  "Warthog not available until Round 2" (research/10 section 1.1). [AUTHOR]
;  ff50_park_main.hsc names sq_sur_ghost_01 and sq_sur_ghost_02 and the stock Phantoms deliver them,
;  so the engine spawns and moves a Ghost chassis here. [V]
;  [G] That evidence covers the Covenant squad's own spawn point, not yours. Place sc_fe_ghost beside
;  ammo_crate0 and drive it out before you ship. Keep bought vehicles PLAYER driven: the source mod's
;  own players report Marines in a Scorpion not firing and troopers in a Warthog not shooting
;  (research/05 section 5.1 technical risks).
; =====================================================================================================
(script static void bh_buy_ghost
    (if (and (not g_bh_ghost_built)
             (fe_gate_open k_fe_gate_vehicle)
             (fe_try_buy k_fe_cost_light_vehicle))
        (begin
            (object_create_anew sc_fe_ghost)
            (set g_bh_ghost_built TRUE)
            (fe_notify "bh_bought_ghost")
        )
    )
)

; =====================================================================================================
;  ORBITAL STRIKE - 3,000, round 3 gate
;  [DERIVED] His heavy rung is 3,000-3,500 (Falcon gunner run 3,000, Scorpion 3,500) and he gates that
;  rung to Round 3 ("Scorpion not available until Round 3"). He never priced an orbital strike, so the
;  number is ours, placed on his ladder. Do not quote 3,000 as his price for this item.
;  The stock airstrike system is the verified mechanism: (airstrike_set_launches 2) in
;  ff20_courtyard.hsc L749 and L752 with (airstrike_weapons_exist) gating it, and ff50_park_main.hsc
;  carries the same resupply/target-locator block (dm_target_01 - dm_target_03,
;  sc_target_01 - sc_target_03). [V] airstrike_enable is hsdoc_hr.txt L5470.
;  [G] The direct "delete the wave" version underneath uses damage_objects_effect
;  (hsdoc_hr.txt L276) against gr_survival_all and needs a real damage tag path.
; =====================================================================================================
(script static void bh_buy_strike
    (if (and (not g_bh_strike_used)
             (fe_gate_open k_fe_gate_heavy)
             (fe_try_buy k_fe_cost_superweapon))
        (begin
            (airstrike_enable TRUE)
            (airstrike_set_launches 1)
            (submit_incident_with_cause_campaign_team "sur_airstrike_refill" player)  ; stock string id,
                                                        ; ff20_courtyard.hsc L751 [V]
            (set g_bh_strike_used TRUE)
            (fe_notify "bh_bought_strike")
            ; [G] alternative immediate salvo, needs a damage tag that exists in your tag set:
            ; (damage_objects_effect objects\weapons\support_high\missile_pod\damage_effects\missile_pod_detonation.damage_effect
            ;                        (ai_actors gr_survival_all))
        )
    )
)

; =====================================================================================================
;  WIN PURCHASE - PELICAN DUST-OFF - 8,000, round 5 gate, bought AT ps_wraith/p2
;  8,000 is four rounds of measured income (research/10 section 1.3), which is where the author's own
;  win gate lands his players: he gated Unearthed's MAC Cannon to the point the score curve crosses
;  ~8,000. The old 30,000 is withdrawn - at 2,000-2,500 a round it was twelve rounds of income, i.e.
;  unreachable inside a 16-wave match, which is exactly the mistake he corrected in 24 hours.
;  The terminal volume is at the exposed anchor, not at the board. See the header.
; =====================================================================================================
(script static void bh_buy_dustoff
    (if (and (not g_bh_dustoff_bought) (fe_win_unlocked) (fe_try_buy k_fe_cost_win))
        (begin
            (set g_bh_dustoff_bought TRUE)
            (fe_notify "bh_bought_dustoff")
            (wake bh_win_hold)
        )
    )
)

; =====================================================================================================
;  WIN SEQUENCE - hold the Pavilion Roof for 120 s while the Pelican comes in
;  The per-second countdown inside a (sleep_until (begin (sleep ...) ...) 1) wrapper is Bungie's own
;  loop idiom: ff20_courtyard.hsc L464-500 and ff45_corvette_main.hsc L81-96. [V]
;  Score keeps accruing during the hold, which is the point (research/05 section 5.1).
;  [NEW] sc_fe_pelican and its flight path. The pattern to copy is cs_ff_halo_pelican,
;  cex_ff_halo_main.hsc L851-912: a point set ps_sur_pelican with run_01 - run_05, face_01 and erase,
;  flown with cs_fly_by / cs_fly_to_and_face and unloaded with (vehicle_unload ... "pelican_lc"). That
;  point set exists on NO other map, so the path is yours to author - but the shape is proven. [V]
; =====================================================================================================
(script continuous bh_win_hold
    (sleep_forever)
    (set g_bh_hold_left 120)
    (object_create_anew sc_fe_pelican)                     ; [NEW]
    (sleep_until
        (begin
            (sleep 30)                                     ; 30 ticks = 1 second
            (if (volume_test_players tv_fe_roof)
                (set g_bh_hold_left (- g_bh_hold_left 1))
            )
            (<= g_bh_hold_left 0)
        )
        1
    )
    (fe_mission_won)
)

; =====================================================================================================
;  ESCALATION
;  Per-wave hook, copied from ff45_corvette_main.hsc L81-96 (ff45_wave_ticker). [V]
;  Skulls, squad species and hazard flags are GAMETYPE settings and live in the .bin, not here
;  (research/05 section 5.1 escalation table). What script adds on top is extra hazard vehicles.
;
;  ALL THREE SQUAD NAMES BELOW ARE STOCK AND GREPPED OUT OF ff50_park_main.hsc:
;    sq_sur_ghost_01, sq_sur_ghost_02, sq_sur_wraith_01, sq_sur_wraith_02   [V]
;  The previous version invented sq_bh_ghost_01, sq_bh_wraith_01, sq_bh_wraith_02, which exist
;  nowhere and would have been compile errors.
;
;  Note: ff50_park_main.hsc's own startup wakes survival_drop_spawn but NOT a ghost or wraith
;  spawner, so placing these ourselves does not fight a stock thread. Compare ff70_holdout, where it
;  would. Their task routing already exists: obj_survival has wraith tasks and the Wraiths run
;  cs_wraith_shoot against ps_wraith/p0 - p3. [V]
; =====================================================================================================
(script dormant bh_escalation
    (set g_bh_last_wave (survival_mode_wave_get))
    (sleep_until
        (begin
            (if (!= g_bh_last_wave (survival_mode_wave_get))
                (begin
                    (set g_bh_last_wave (survival_mode_wave_get))
                    ; round 2: Ghost on the access road
                    (if (>= (survival_mode_round_get) 1)
                        (if (<= (ai_living_count sq_sur_ghost_01) 0) (ai_place sq_sur_ghost_01))
                    )
                    ; round 3 and later: Wraith parks on Beach Road and shells ps_wraith/p0 - p3
                    (if (>= (survival_mode_round_get) 2)
                        (if (<= (ai_living_count sq_sur_wraith_01) 0) (ai_place sq_sur_wraith_01))
                    )
                    ; set 2: second Ghost and second Wraith. Hazard vehicles capped at 2 alive
                    ; (research/05 section 6 item 2).
                    (if (>= (survival_mode_set_get) 1)
                        (begin
                            (if (<= (ai_living_count sq_sur_ghost_02) 0) (ai_place sq_sur_ghost_02))
                            (if (<= (ai_living_count sq_sur_wraith_02) 0) (ai_place sq_sur_wraith_02))
                        )
                    )
                )
            )
            FALSE
        )
        1
    )
)

; =====================================================================================================
;  ROUND GATE BANNERS
;  The author's own pacing device, adopted here (research/10 section 1.2). He announces each unlock
;  with a HUD banner at the round boundary - OBSERVED verbatim: "The Warthog and Gauss upgrade are now
;  available!" and "The Scorpion and Auto Turret are now available!" - and his 0.1.6 note says why he
;  had to: "HUD messages for important events (switches becoming available, Unearthed's MAC Cannon,
;  Installation 04's Evac Pelican, etc) are now implemented to make objectives more clear ingame."
;  Without the banner the gate is invisible and reads as a bug.
;
;  The banner fires once per absolute round index, on the boundary, for the three gates this map uses:
;    R2  Ghost + rocket turret upgrade        R3  orbital strike        R5  PELICAN DUST-OFF
;  fe_notify string ids are [G] - each one needs a real string in the map's string tags, or swap
;  fe_notify for the stock incident mechanism (fe_reinforcements.hsc section 11 option b).
; =====================================================================================================
(script dormant bh_gates
    (sleep_until
        (begin
            (if (> (fe_round_index) g_bh_gate_round)
                (begin
                    (set g_bh_gate_round (fe_round_index))
                    (if (= g_bh_gate_round k_fe_gate_vehicle)
                        (fe_notify "bh_gate_vehicle")      ; "The Ghost and the rocket turret upgrade
                    )                                      ;  are now available!"
                    (if (= g_bh_gate_round k_fe_gate_heavy)
                        (fe_notify "bh_gate_heavy")        ; "The orbital strike is now available!"
                    )
                    (if (= g_bh_gate_round k_fe_win_round_gate)
                        (begin
                            (fe_notify "bh_gate_win")      ; "The Pelican dust-off can now be called
                            (sound_impulse_start sfx_blip NONE 1)   ;  in - from the Wraith's ground."
                        )
                    )
                )
            )
            FALSE
        )
        30
    )
)

; =====================================================================================================
;  LOSE BACKSTOP - wave 16 with no dust-off purchased
;  s_survival_wave_complete_count is Bungie's completed-wave counter (global_firefight.hsc L124,
;  incremented in the wave loop). [V]
; =====================================================================================================
(script dormant bh_backstop
    (sleep_until (>= s_survival_wave_complete_count k_fe_wave_backstop) 30)
    (if (not g_bh_dustoff_bought)
        (fe_mission_lost)
    )
)

; =====================================================================================================
;  TEST HARNESS - copy of the shape at the bottom of every pod-equipped stock map
;  (ff20_courtyard.hsc L1253-1260: test_squad_drop). Call these from the Standalone console. [V]
; =====================================================================================================
(script static void test_fe_marines
    (fe_board_open)
    (set k_fe_cost_marines 0)
    (bh_buy_marines)
)

(script static void test_fe_odst
    (fe_board_open)
    (set k_fe_cost_odst 0)
    (ai_erase ai_fe_odst)
    (sleep 30)
    (bh_buy_odst)
)
