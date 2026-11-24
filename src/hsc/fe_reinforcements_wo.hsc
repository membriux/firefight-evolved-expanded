; =====================================================================================================
;  fe_reinforcements_wo.hsc  -  purchase + reinforcement library for WATERFRONT and OUTPOST
;  2026-11-23.  ZERO NEW SCRIPT OBJECTS.
; =====================================================================================================
;
;  This is a sibling of src/hsc/fe_reinforcements.hsc, not a replacement for it.  That file is the
;  shipped Holdout library and is left untouched; this one exists because the Holdout library hard-codes
;  Holdout-only objects (sq_sur_drop_01..04, dm_drop_01..04, sc_poa, sq_sur_banshee_01/02) and neither
;  of these two maps has the same set.  Everything that was map-neutral is carried over unchanged in
;  shape; everything map-specific has been moved out into the per-map kiosk file.
;
;  COMPILE UNIT ORDER (both maps):
;    build/wo/fe_culled_shims.hsc              restores the culled `player_count` script
;    build/wo/<map>/stock_unescaped.hsc        the map's OWN decompiled scripts, backslashes collapsed
;    src/hsc/fe_reinforcements_wo.hsc          this file
;    src/hsc/<map>.hsc                         the six kiosks, the ally refresh and the startup script
;
;  No stock-hooks file is needed on either map, and that is a real difference from Holdout.  Holdout
;  had to switch Bungie's drop-pod event off because it borrowed sq_sur_drop_01..04 as the ally bodies.
;  These two maps use sur_fireteam_01..04 instead, which stock declares and binds
;  (ai_sur_fireteam_squad0..5) but never places, wakes or cleans up - checked by reading every
;  reference in both decompiles, 12 each, all of them the six declarations plus the six `set`s.  So the
;  stock script needs no edit of any kind here.
;
;  EVERY NAME BELOW EXISTS IN BOTH MAPS' OWN scnr TAG.  Read out of the caches, not assumed:
;    ai_squad        sur_fireteam_01..06      Waterfront squads[14..18,31], Outpost squads[14..18,26]
;    ai_squad_group  gr_survival_fireteams    Waterfront groups[6], Outpost groups[9]
;    ai_squad_group  gr_survival_waves        Waterfront groups[5], Outpost groups[5]
;    ai_squad_group  gr_survival_all          both groups[0]
;    object_name     dm_longsword_01          Waterfront machines, Outpost machines; placement flag
;                                             bit0 set on both, i.e. script-created, exactly as the
;                                             map's own stock script does it
;    ai_objective    obj_fireteams / task `fireteams`   both maps, objective[1], one task
;    snd!  sound\game_sfx\ui\transition_beeps                        WF tag 8768, OP tag 9438
;    snd!  sound\game_sfx\multiplayer\flag_failure                   WF tag 4446, OP tag 4620
;    snd!  sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus  WF tag 10054, OP tag 10220
;
;  print IS DELIBERATELY OFF THE CRITICAL PATH.  ReachMCC_U13_Scripting.xml marks opcode 0x028
;  null="true"; the engine will not run it.  Every print here is behind (if g_fe_debug ...).
; =====================================================================================================


; =====================================================================================================
;  1. PRICES - THE NAMED-CONSTANTS BLOCK.  RETUNE HERE, NOWHERE ELSE.
;
;  The author's real numbers, read out of ff_unearthed (research/14 section 6.2): marines 500 for four
;  bodies, turret 750, Warthog 1,000, hog upgrade 2,000, Scorpion 3,500, MAC 10,000.
;
;  EXPECT THESE TO MOVE.  The author cut every launch price by 50-75% within 24 hours of release and
;  cut them again three weeks later (research/10 section 1.2).
; =====================================================================================================
(global long k_fe_cost_squad      500)      ; [AUTHOR] buy_marines = 500 for four bodies = 125/body.
(global long k_fe_cost_spartan   1000)      ; SPARTAN TIER: 1,000 for TWO bodies = 500/body, i.e. 4x a
                                            ; trooper, and the same rung as the author's Warthog.
(global long k_fe_cost_ammo       500)      ; [AUTHOR] buy_ammo1 (light weapon rack) = 500.
(global long k_fe_cost_strike    3000)      ; [AUTHOR] buy_turret3 / buy_tank rung = 3,500; 3,000 here
                                            ;          because the Longsword pass is one-shot.
(global long k_fe_bank_step       500)      ; [AUTHOR] deposit/withdraw = 500 a press.
(global long k_fe_cost_win      10000)      ; [AUTHOR] buy_mac = 10,000 and IS the win condition.

; =====================================================================================================
;  2. TUNING
;
;  k_fe_actor_limit IS THE ONE NUMBER MOST LIKELY TO NEED CHANGING.  The author shipped 8 after
;  playtesting his own map.  12 is the USER'S choice and is implemented as asked.  Two caveats, both
;  specific and both on record:
;    1. Engine headroom.  research/06 derives a ceiling of roughly 34 concurrent actors for BOTH sides
;       together.  The friendly budget comes out of the same pool as the Covenant spawner, so 12
;       friendlies is a materially bigger bite than 8 and will show up as thinner enemy waves.
;    2. Per-map.  Our own earlier analysis wanted WATERFRONT at 10 (densest hostile geometry of the
;       set) and OUTPOST's Deck at 6 (one small platform).  12 is therefore the most aggressive
;       setting available on both, and on Outpost in particular expect visible congestion on the Deck
;       with a full ally field.  Dropping to 10, 8 or 6 is this one line.
; =====================================================================================================
(global short k_fe_actor_limit     12)      ; [USER] total living allies, troopers + Spartans together,
                                            ; counted with ai_living_count on the ROOT ally group.
                                            ; [AUTHOR's playtested value was 8.]
(global short k_fe_spartan_limit    4)      ; SPARTAN SUB-CAP: at most 4 Spartans alive at once, i.e.
                                            ; two purchases.  Without it a player fills the whole
                                            ; budget with the strongest unit and the trooper tier
                                            ; becomes pointless.
(global short k_fe_squad_size       4)      ; [AUTHOR] 4 bodies per trooper purchase.
(global short k_fe_spartan_size     2)      ; two Spartans per purchase.
(global real  k_fe_kiosk_radius   1.1)      ; world units.  SET PER MAP IN THE MAP'S STARTUP SCRIPT.
                                            ;
                                            ; THIS IS NOT HOLDOUT'S 2.5, AND THE REASON IS ARITHMETIC
                                            ; RATHER THAN TASTE.  Two stations cross-trigger whenever
                                            ; the distance between them is less than 2 x the radius,
                                            ; because then one standing position is inside both discs
                                            ; and both dormant kiosk scripts fire on the same dwell.
                                            ; Measured closest pair, from each map's own control block:
                                            ;     Waterfront  health_pack2-health_pack3  3.038 wu
                                            ;     Outpost     health_pack2-health_pack4  2.334 wu
                                            ; so the radius must stay below 1.519 and 1.167
                                            ; respectively.  Each map's startup sets its own value;
                                            ; this declaration is the TIGHTER of the two, so a map that
                                            ; forgot to set it would be over-strict rather than wrong.
                                            ;
                                            ; THE SAME ARITHMETIC APPLIED TO HOLDOUT'S OWN NUMBERS, from
                                            ; the coordinates documented in src/hsc/ff70_holdout.hsc,
                                            ; puts health_pack4 and health_pack5 2.36 wu apart against a
                                            ; 2.5 radius - i.e. the shipped Holdout artifact can fire its
                                            ; BANK and its 10,000-point WIN purchase from one standing
                                            ; position.  Flagged for whoever owns that map; not changed
                                            ; here, because that map is not this task's.
                                            ;
                                            ; The cost of the tight radius is that the buyer must stand
                                            ; ON the pad rather than near it.  That is the right way to
                                            ; spend the error budget: a shop that needs precise footing
                                            ; is a nuisance, a shop that silently charges 10,000 for a
                                            ; 500 deposit is a broken game.
(global short k_fe_dwell            8)      ; ticks the buyer must hold position.  30 ticks = 1 s.
(global short k_fe_cooldown       150)      ; 5 s anti-spam lock-out per station after a sale.
(global short k_fe_gate_spartan     1)      ; Spartans gated on SET >= 1.
(global short k_fe_gate_strike      1)      ; gate on SET, not round.
(global short k_fe_gate_win         1)      ; [AUTHOR] buy_mac waits on (>= (survival_mode_set_get) 1).

; =====================================================================================================
;  2a. THE ALLY BODIES AND THE SPARTAN LOADOUT POOLS - TAG DATA, NOT SCRIPT.
;
;  Listed here as editable documentation because the values live in the squad cells, not in any script
;  call.  build/logs/wo_build_tags.py is the one place to change them.
;
;  THE BODIES ARE SPARTANS IN BOTH TIERS.  No stock Firefight cache contains a Marine or ODST `char`
;  tag; all eight were scanned (research/18 section 3.1).  The ally character is the one palette entry
;  no cell referenced, objects\characters\null\ai\null_cov_default - Waterfront palette [23], Outpost
;  palette [24], both verified unreferenced by every designer AND templated cell in their own map -
;  with its `unit` tag_reference repointed to objects\characters\spartans\spartans.  That repoint is
;  already in both staged caches and already loaded in Blamite (research/20).  The cheap tier is
;  therefore called TROOPERS, not Marines.  The two tiers differ by COUNT, RANK and LOADOUT:
;      troopers  4 bodies  major upgrade 3 'none'  stock cell weapons
;      Spartans  2 bodies  major upgrade 4 'all'   randomised heavy weapon + randomised ability
;
;  Randomisation is FREE: weapon_palette_choice_block and equipment_palette_choice_block each hold up
;  to 8 entries with a `chance` weight, and the engine picks per actor per spawn.  No random_range
;  call, no script branch, no cost.
;
;  WEAPON POOL - PER MAP, because the two scenario weapon palettes are NOT in the same order.  Every
;  index below was read out of that map's own palette:
;      Waterfront  [14] sniper_rifle  [18] rocket_launcher  [19] spartan_laser
;                  [21] plasma_turret (detached, carryable)  [ 9] grenade_launcher
;      Outpost     [12] sniper_rifle  [16] rocket_launcher  [17] spartan_laser
;                  [21] plasma_turret (detached, carryable)  [ 7] grenade_launcher
;  THE HUMAN MACHINE-GUN TURRET IS NOT AVAILABLE AS A CARRIED WEAPON.  Outpost ships
;  objects\vehicles\human\turrets\machinegun\machinegun as VEHICLE palette [0] - it is a `vehi`, so a
;  biped cannot hold it and a cell's `initial weapon` cannot name it.  Waterfront does not ship it at
;  all.  Weapon palette [21] on both maps is the detached Covenant plasma turret, which IS a `weap`
;  and IS carryable, and that is what the pool uses.
;
;  SECONDARY WEAPON - WATERFRONT ONLY, AND ROUND-2 FIXED (audit 25, research/28).  Waterfront's four
;  ally cells all pointed at ONE `initial secondary weapon` choice block holding palette [12]
;  plasma_rifle, so every purchased human ally carried a Covenant weapon and a per-squad tweak would
;  have silently edited all four.  Each ally cell now has its OWN secondary block, allocated fresh in
;  the already-granted page and REPOINTED - never written through, because writing into a shared
;  choice block is exactly how an earlier pass armed Waterfront's stock drop squad with a DMR.  The
;  content is now Waterfront's own palette [4] objects\weapons\pistol\magnum\magnum, a human sidearm.
;  Outpost's ally cells carry NO secondary block at all (count 0, read from the cache) and are left
;  that way, which is what the other five maps do.
;
;  ABILITY POOL - also per map, and shorter than Holdout's by necessity.  Both maps ship a 4-entry
;  equipment palette and BOTH ALREADY CONTAIN active_camouflage, so unlike Holdout no camo append was
;  needed; what is missing on both is the jet pack, whose eqip tag IS in both tag tables (WF 7879,
;  OP 8778) but not in either scenario palette, so it is appended as entry [4] by cloning the sprint
;  entry's 16-byte tag_reference and swapping its datum - the mechanism Holdout proved on camo.
;      Waterfront  [0] sprint  [1] active_camouflage  [3] drop_shield  [4] jet_pack (appended)
;      Outpost     [1] sprint  [0] active_camouflage  [3] drop_shield  [4] jet_pack (appended)
;  Palette entry [2] on both maps is objects\gear\human\military\ammo_box\ammo_box, a gear pickup
;  rather than an armour ability, and it is deliberately NOT in the pool.  Neither map ships
;  armor_lockup, so the "an ally that locks down stops shooting" problem does not arise here.
;
;  SPAWN POINTS.  sur_fireteam_01..06 ship with 0 spawn points on both maps, and a squad with cells
;  but no spawn points places nothing.  Points are authored per ally squad, each at the exact
;  position of a Bungie-authored on-foot position in that map, so the ground is known walkable,
;  known inside the base and known player-spawnable.  Nothing here invents a coordinate.
;
;  ROUND-2 FIX, WF-3 / OP-3 (audit 25, research/28).  THE TROOPER SQUADS NOW CARRY FOUR POINTS EACH,
;  NOT TWO.  sur_fireteam_01 and _02 declare `normal diff count` 4 and shipped with only 2 spawn
;  points, i.e. half the placement sites the cell asks for; every passing map in the pack gives a
;  count-4 cell four points, and the Unearthed marines6 build grew count and point list together.
;  The two added points per squad are the exact coordinates of two of that map's own PLAYER STARTING
;  LOCATIONS - Bungie's own on-foot spawn positions, taken from the player-base cluster, never from
;  the Elite cluster - and all four are verified inside safe_zone_soft and inside no kill volume by
;  build/r2/r2_contain.py, whose polygon test calibrates 16/16 on each map's own player starts.
;  The Spartan squads keep two points against a two-actor cell, which already matched.
;
;  ALL ALLIES SIT IN gr_survival_fireteams, which is reparented to root by a 2-byte same-size patch.
;  WITHOUT THAT PATCH THE MAP HANGS BETWEEN WAVES and nothing in this file compensates for it: stock
;  survival_wave_living_count counts (ai_living_count "gr_survival_all"), and in stock both maps chain
;  gr_survival_fireteams -> gr_survival_waves -> gr_survival_all.
; =====================================================================================================

; =====================================================================================================
;  3. SOUNDS.  sfx_blip is NOT a built-in: stock declares it as a script global of type `sound` holding
;     a real tag path, and both of these maps declare it themselves, so OURS ARE PREFIXED sfx_fe_ to
;     avoid a duplicate global when this file is united with the map's own script.
; =====================================================================================================
(global sound sfx_fe_blip "sound\game_sfx\ui\transition_beeps")
(global sound sfx_fe_buy "sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus")
(global sound sfx_fe_deny "sound\game_sfx\multiplayer\flag_failure")

; =====================================================================================================
;  4. STATE
; =====================================================================================================
(global boolean g_fe_debug      false)      ; (set g_fe_debug true) for print tracing. Never shipped on.
(global boolean g_fe_open       false)      ; the shop is live.  Set by the per-map startup script.
(global short   g_fe_rotor          0)      ; which trooper squad the next purchase uses.
(global short   g_fe_spartan_rotor  0)      ; which Spartan squad the next purchase uses.
(global short   g_fe_spartan_buys   0)      ; successful Spartan purchases this match.
(global long    g_fe_bank           0)      ; shared bank, as in the author's build.
(global short   g_fe_buys           0)      ; successful trooper purchases this match.
(global boolean g_fe_won        false)      ; latch, so the win purchase can only fire once.

; =====================================================================================================
;  5. PRIMITIVES
;
;  fe_valid is Bungie's own validity guard, copied in shape from survival_health_pack_highlight: an
;  absent player slot yields object_get_health < 0.  There is no player_in_game_count in the U13 table,
;  so this is the only guard available - and it is the one both shipped maps use, for all eight slots.
;
;  STRICTLY POSITIVE, NOT >= 0 (audit 29, RISK-R2).  object_get_health < 0 means "no such object", so
;  (>= ... 0) is an EXISTENCE test, not a liveness test: a player at exactly 0 health - dead, not yet
;  despawned - passed it, and a corpse lying inside a station's radius could still be charged by
;  fe_charge_at.  Bungie's own liveness boundary in these same caches puts 0 on the DEAD side:
;  f_blip_object_until_dead and f_blip_ai_until_dead - both present in all seven stock caches - wait
;  on (<= (object_get_health ...) 0) to mean dead.  So "alive" is (> ... 0), and that is what a buyer
;  has to be.  This is a predicate read out of stock, not one invented here.
; =====================================================================================================
(script static boolean fe_valid (unit who)
    (> (object_get_health who) 0)
)

; Proximity instead of a trigger volume.  objects_distance_to_object (0x0B2) takes (object_list,
; object); `player` -> `unit` -> `object` -> `object_list` all cast.  Bungie makes the same call with
; the same arguments against these same health stations in both maps' own
; survival_health_pack_highlight.
;
; THE NEGATIVE-RETURN GUARD (audit 25, RISK-G3).  objects_distance_to_object returns a NEGATIVE
; value when the object list is empty or the named object is absent, and (< -1 radius) is true.
; Without the (>= ... 0) term an absent or destroyed anchor reports EVERY player as "near" it,
; wherever they are standing, and the station fires once per cooldown for anyone who can pay.
; fe_valid already covers the player side; this covers the kiosk side.  Bungie's own
; survival_health_pack_highlight - the call this comment cites - likewise tests BOTH ends.  `and`
; short-circuits, so the second distance call is only evaluated once the first has proved the object
; is present.
(script static boolean fe_near (unit who, object kiosk)
    (and
        (fe_valid who)
        (>= (objects_distance_to_object who kiosk) 0)
        (< (objects_distance_to_object who kiosk) k_fe_kiosk_radius)
    )
)

(script static long fe_score (unit who)
    (campaign_metagame_get_player_score who)
)

; =====================================================================================================
;  6. CHARGING.  A NEGATIVE campaign_metagame_award_points, charged to THE ACTUAL BUYER.
;
;  The author's mechanism, not a workaround (research/14 section 6.1): affordability and buyer identity
;  are tested together in one `or` over all eight player slots, then a parallel `cond` over the same
;  eight slots fires exactly one negative award against whoever is standing at the kiosk.
;
;  player0 is NOT used.  It does not exist in the U13 opcode table and it would also charge the wrong
;  player.  human_player_in_game_get returns `player`, which is exactly the first argument type
;  campaign_metagame_award_points declares.
; =====================================================================================================
(script static boolean fe_buyer_at (object kiosk, long cost)
    (or
        (and (fe_near (human_player_in_game_get 0) kiosk) (>= (fe_score (human_player_in_game_get 0)) cost))
        (and (fe_near (human_player_in_game_get 1) kiosk) (>= (fe_score (human_player_in_game_get 1)) cost))
        (and (fe_near (human_player_in_game_get 2) kiosk) (>= (fe_score (human_player_in_game_get 2)) cost))
        (and (fe_near (human_player_in_game_get 3) kiosk) (>= (fe_score (human_player_in_game_get 3)) cost))
        (and (fe_near (human_player_in_game_get 4) kiosk) (>= (fe_score (human_player_in_game_get 4)) cost))
        (and (fe_near (human_player_in_game_get 5) kiosk) (>= (fe_score (human_player_in_game_get 5)) cost))
        (and (fe_near (human_player_in_game_get 6) kiosk) (>= (fe_score (human_player_in_game_get 6)) cost))
        (and (fe_near (human_player_in_game_get 7) kiosk) (>= (fe_score (human_player_in_game_get 7)) cost))
    )
)

; Anyone at all standing at the kiosk, whether or not they can pay.  Used to decide between the
; success and the failure sound, so a broke player gets told no instead of nothing.
(script static boolean fe_anyone_at (object kiosk)
    (or
        (fe_near (human_player_in_game_get 0) kiosk)
        (fe_near (human_player_in_game_get 1) kiosk)
        (fe_near (human_player_in_game_get 2) kiosk)
        (fe_near (human_player_in_game_get 3) kiosk)
        (fe_near (human_player_in_game_get 4) kiosk)
        (fe_near (human_player_in_game_get 5) kiosk)
        (fe_near (human_player_in_game_get 6) kiosk)
        (fe_near (human_player_in_game_get 7) kiosk)
    )
)

; The charge.  Exactly one branch of the cond fires, against the buyer, never against player 0.
(script static void fe_charge_at (object kiosk, long cost)
    (cond
        ((and (fe_near (human_player_in_game_get 0) kiosk) (>= (fe_score (human_player_in_game_get 0)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 0) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 1) kiosk) (>= (fe_score (human_player_in_game_get 1)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 1) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 2) kiosk) (>= (fe_score (human_player_in_game_get 2)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 2) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 3) kiosk) (>= (fe_score (human_player_in_game_get 3)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 3) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 4) kiosk) (>= (fe_score (human_player_in_game_get 4)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 4) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 5) kiosk) (>= (fe_score (human_player_in_game_get 5)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 5) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 6) kiosk) (>= (fe_score (human_player_in_game_get 6)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 6) (- 0 cost)))
        ((and (fe_near (human_player_in_game_get 7) kiosk) (>= (fe_score (human_player_in_game_get 7)) cost))
            (campaign_metagame_award_points (human_player_in_game_get 7) (- 0 cost)))
    )
)

; The credit, for the bank withdrawal.  Same shape, positive amount, affordability clause dropped
; because a withdrawal has no price.
(script static void fe_credit_at (object kiosk, long amount)
    (cond
        ((fe_near (human_player_in_game_get 0) kiosk) (campaign_metagame_award_points (human_player_in_game_get 0) amount))
        ((fe_near (human_player_in_game_get 1) kiosk) (campaign_metagame_award_points (human_player_in_game_get 1) amount))
        ((fe_near (human_player_in_game_get 2) kiosk) (campaign_metagame_award_points (human_player_in_game_get 2) amount))
        ((fe_near (human_player_in_game_get 3) kiosk) (campaign_metagame_award_points (human_player_in_game_get 3) amount))
        ((fe_near (human_player_in_game_get 4) kiosk) (campaign_metagame_award_points (human_player_in_game_get 4) amount))
        ((fe_near (human_player_in_game_get 5) kiosk) (campaign_metagame_award_points (human_player_in_game_get 5) amount))
        ((fe_near (human_player_in_game_get 6) kiosk) (campaign_metagame_award_points (human_player_in_game_get 6) amount))
        ((fe_near (human_player_in_game_get 7) kiosk) (campaign_metagame_award_points (human_player_in_game_get 7) amount))
    )
)

; =====================================================================================================
;  7. FEEDBACK.  sound_impulse_start (sound, object, real) - the kiosk itself is the emitter, so the
;     cue is positional and the buyer hears it at the terminal.
; =====================================================================================================
(script static void fe_ok (object kiosk)
    (sound_impulse_start sfx_fe_buy kiosk 5)
)

(script static void fe_deny (object kiosk)
    (sound_impulse_start sfx_fe_deny kiosk 5)
)

(script static void fe_blip (object what)
    (sound_impulse_start sfx_fe_blip what 3)
    (chud_track_object what true)
)

(script static void fe_unblip (object what)
    (chud_track_object what false)
)

; =====================================================================================================
;  8. THE ALLY BUDGET.
;
;  The cap is read off the ally squad GROUP, exactly as the author does it, and
;  survival_wave_living_count is left COMPLETELY STOCK (research/14 section 6.4).  That works only
;  because gr_survival_fireteams has been reparented to root and so sits outside gr_survival_all.
;  Both tiers live in that one group, so buying Spartans costs you troopers - which is the point.
; =====================================================================================================
(script static short fe_allies_alive
    (ai_living_count "gr_survival_fireteams")
)

(script static short fe_slots_free
    (- k_fe_actor_limit (fe_allies_alive))
)

; ROUND-2 FIX, WF-1 / OP-1 (research/25 class 4, research/28).
; The budget term alone is NOT sufficient to know a squad is reusable, and this file shipped with
; only the budget term while the other five maps also tested squad emptiness.  Traced failure:
; two 4-body squads, k_fe_actor_limit 12, k_fe_squad_size 4.  With both squads full,
; fe_slots_free = 12 - 8 = 4, which satisfies (>= 4 4), so the third purchase passed the gate,
; charged 500 and called ai_place on a squad that still had four living members.  The map can
; field at most 8 troopers, so that purchase could never deliver.
; The fix is the shape fe_shop_ctgl.hsc (Courtyard / Glacier / Holdout) already shipped: a tier
; can only sell if one of ITS OWN squads is actually empty.  Checked BEFORE the charge, so a full
; field refuses the sale - the kiosk's (fe_deny ...) branch - instead of taking the money.
(script static boolean fe_squad_empty (ai squad)
    (<= (ai_living_count squad) 0)
)

(script static boolean fe_trooper_slot_free
    (or (fe_squad_empty "sur_fireteam_01") (fe_squad_empty "sur_fireteam_02"))
)

(script static boolean fe_has_room
    (and (>= (fe_slots_free) k_fe_squad_size) (fe_trooper_slot_free))
)

; THE SPARTAN SUB-CAP.  Spartans count against k_fe_actor_limit like everything else - both tiers are
; in gr_survival_fireteams, so fe_allies_alive already includes them - AND they additionally cannot
; exceed k_fe_spartan_limit between them.  Counted as the sum of the two Spartan squads rather than
; off a group, because there is no spare squad group to put only the Spartans in and the design
; refuses to invent one.
(script static short fe_spartans_alive
    (+ (ai_living_count "sur_fireteam_03") (ai_living_count "sur_fireteam_04"))
)

; ROUND-2 FIX, WF-1 / OP-1, Spartan half.  The body sub-cap alone had the mirror-image hole: with
; sur_fireteam_03 alive (2) and sur_fireteam_04 wiped (0), fe_spartans_alive = 2 and 2 + 2 <= 4
; passed, and the blind rotor then re-placed the LIVING squad 03 while the empty squad 04 went
; unused.  Emptiness is now a third term, same as fe_shop_ctgl.hsc.
(script static boolean fe_spartan_slot_free
    (or (fe_squad_empty "sur_fireteam_03") (fe_squad_empty "sur_fireteam_04"))
)

(script static boolean fe_has_spartan_room
    (and
        (>= (fe_slots_free) k_fe_spartan_size)
        (and
            (<= (+ (fe_spartans_alive) k_fe_spartan_size) k_fe_spartan_limit)
            (fe_spartan_slot_free)
        )
    )
)

; =====================================================================================================
;  9. GATING - ON SET, NOT ROUND, for the expensive items.
;     The author's own gates: the Warthog on Round 2, the MAC on (>= (survival_mode_set_get) 1).
;     Both opcodes exist in the U13 table: survival_mode_round_get 0x483, survival_mode_set_get 0x482.
; =====================================================================================================
(script static boolean fe_gate_round (short gate)
    (>= (survival_mode_round_get) gate)
)

(script static boolean fe_gate_set (short gate)
    (>= (survival_mode_set_get) gate)
)

; =====================================================================================================
;  10. ALLY DELIVERY.
;
;  ai_place takes ONE argument in this build (argc=1, opcode 0x1A7).  The two-argument partial
;  placement form an earlier design relied on DOES NOT EXIST in ReachMCC_U13_Scripting.xml, so squad
;  size is fixed by the cell and the cap is enforced by refusing the sale, not by trimming it.
;
;  Team is set at RUNTIME with ai_set_team (0x1E4), not by patching each squad's `team` field.  Both
;  stock maps already declare the allegiance both ways in their own initialisation
;  ((ai_allegiance human player) (ai_allegiance player human)), so `human` is the correct ally team on
;  both and no allegiance call of our own is needed.  One is issued anyway, defensively, because it is
;  idempotent.
;
;  NO DROP PODS.  Holdout delivered its troopers by pod because it borrowed the drop squads.  These
;  squads' spawn points are authored inside the base, so the allies simply walk out of the respawn
;  zone.  That matters for Outpost in particular, which ships NO drop-pod infrastructure at all: no
;  dm_drop_* machines, no sq_sur_drop_* squads, no pod rails and no drop-pod spawner.  Both maps
;  therefore use the same delivery path, and neither can spawn an ally outside the arena.
; =====================================================================================================
(script static void fe_squad_commit (ai squad)
    (ai_set_team squad human)
    (ai_allegiance human player)
    (ai_allegiance player human)
    (ai_set_task squad "obj_fireteams" "fireteams")
    (if g_fe_debug (print "fe: allies committed"))
)

; Place-then-commit, for squads whose spawn points are in the arena and need no vehicle.
(script static void fe_squad_commit_placed (ai squad)
    (ai_place squad)
    (sleep 1)
    (fe_squad_commit squad)
    (fe_blip (ai_get_object squad))
    (sleep 90)
    (fe_unblip (ai_get_object squad))
)

; ROUND-2 FIX, WF-2 / OP-2 (research/25 class 4, research/28).
; THE BLIND ROTOR IS GONE.  g_fe_rotor selected a squad by position in a two-step cycle and never
; asked which squad was actually empty, so it could call ai_place on a squad with four living
; members.  Selection is now explicit per-squad occupancy, the shape fe_shop_ctgl.hsc ships: place
; the FIRST EMPTY squad, and if neither is empty place NOTHING.  Nothing can be charged in that
; last case either, because fe_has_room is tested before fe_transact in every kiosk and its false
; branch is (fe_deny <kiosk>) - the deny sound, no deduction.  The purchase counter now increments
; only on a real placement, so it can no longer lie if the guard is ever bypassed (the COSMETIC
; finding audit 25 raised against Overlook's fallback-less cond).
; g_fe_rotor / g_fe_spartan_rotor are left declared and left set by the startup script: they are
; now dead, like k_fe_cost_air on three other maps, and removing a global from a published table is
; a bigger change than leaving one unread.
(script static void fe_deliver_squad
    (cond
        ((fe_squad_empty "sur_fireteam_01")
            (begin
                (fe_squad_commit_placed "sur_fireteam_01")
                (set g_fe_buys (+ g_fe_buys 1))
            )
        )
        ((fe_squad_empty "sur_fireteam_02")
            (begin
                (fe_squad_commit_placed "sur_fireteam_02")
                (set g_fe_buys (+ g_fe_buys 1))
            )
        )
        (true
            (if g_fe_debug (print "fe: refused, both trooper squads occupied"))
        )
    )
)

; The Spartan tier: 2 bodies into whichever of sur_fireteam_03 / sur_fireteam_04 is empty.  WHICH
; SLOTS WERE FREE WAS
; CHECKED, NOT ASSUMED: both staged caches already carry added cells on sur_fireteam_01 and _02, so
; those two are the trooper tier; 03, 04, 05 and 06 all read 0 designer cells / 0 templated cells /
; 0 spawn points in both maps.  This tier takes 03 and 04 and leaves 05 and 06 free for an ODST tier.
(script static void fe_deliver_spartans
    (cond
        ((fe_squad_empty "sur_fireteam_03")
            (begin
                (fe_squad_commit_placed "sur_fireteam_03")
                (set g_fe_spartan_buys (+ g_fe_spartan_buys 1))
            )
        )
        ((fe_squad_empty "sur_fireteam_04")
            (begin
                (fe_squad_commit_placed "sur_fireteam_04")
                (set g_fe_spartan_buys (+ g_fe_spartan_buys 1))
            )
        )
        (true
            (if g_fe_debug (print "fe: refused, both Spartan squads occupied"))
        )
    )
)

; Retire every ally.  ai_survival_cleanup (0x6B5) is the call both stock maps use on their own groups
; at round end.
(script static void fe_retire_allies
    (ai_survival_cleanup "gr_survival_fireteams" true true)
)

; =====================================================================================================
;  11. THE GENERIC KIOSK TRANSACTION.
;
;  One template, used by every station in the per-map file.  The shape is the author's: block until
;  something happens at the terminal, test affordability and identity together, charge the buyer,
;  deliver, then lock the station out for a cooldown.  The difference is the input: his was
;  (sleep_until (> (device_get_position "<name>") 0) 1) on a purpose-placed device_control, and this is
;  a dwell on a distance test, because no purpose-placed control exists on either map and one cannot be
;  created without Sapien.
;
;  (device_get_position "health_pack0") does compile - health_pack0..5 are device_controls and the
;  compiler resolves them as device_name - but it is NOT used, because whether a health station's
;  position tracks the player's hold-to-use interaction is unverified, and a wrong guess there is a
;  shop that never opens.  A dwell on a distance test has no unknowns.
;
;  Returns true if the sale went through, so the caller can run its own delivery.
; =====================================================================================================
(script static boolean fe_transact (object kiosk, long cost)
    (if (fe_buyer_at kiosk cost)
        (begin
            (fe_charge_at kiosk cost)
            (fe_ok kiosk)
            true
        )
        (begin
            (if (fe_anyone_at kiosk) (fe_deny kiosk))
            false
        )
    )
)

; Wait until somebody has been standing at the kiosk for k_fe_dwell ticks.  Two sleeps: the first
; blocks until a player arrives, the second confirms they are still there, which filters out players
; merely running past.
(script static void fe_wait_at (object kiosk)
    (sleep_until (fe_anyone_at kiosk) 5)
    (sleep k_fe_dwell)
)

; =====================================================================================================
;  12. THE BANK.  The author's, unchanged in intent: 500 a press, one shared global, either player can
;      withdraw what the other deposited (research/14 section 6.6).  If you can pay, you deposit; if
;      you cannot and the bank holds something, you withdraw.
; =====================================================================================================
(script static void fe_bank_use (object kiosk)
    (cond
        ((fe_buyer_at kiosk k_fe_bank_step)
            (begin
                (fe_charge_at kiosk k_fe_bank_step)
                (set g_fe_bank (+ g_fe_bank k_fe_bank_step))
                (fe_ok kiosk)
                (if g_fe_debug (print "fe: deposit"))))
        ((>= g_fe_bank k_fe_bank_step)
            (begin
                (fe_credit_at kiosk k_fe_bank_step)
                (set g_fe_bank (- g_fe_bank k_fe_bank_step))
                (fe_ok kiosk)
                (if g_fe_debug (print "fe: withdraw"))))
        (true
            (fe_deny kiosk))
    )
)

; =====================================================================================================
;  13. THE WIN PURCHASE.
;
;  The author's 10,000-point MAC strike IS the win condition.  Holdout blipped sc_poa, the Pillar of
;  Autumn, because Holdout places that cruiser off the map edge.  NEITHER of these maps places a
;  cruiser or any other orbital-bombardment prop - checked against both object-name tables - so the
;  blip is put on the KIOSK itself, which is an `object` the caller already holds.  That is a cosmetic
;  substitution and it is the only difference from the Holdout win sequence.
;
;  (game_won) WAS WRONG AND IS GONE (audit 25, BLOCKER-G1).  It is a live opcode (0x442) in the U13
;  table, but being in the table says nothing about what it does inside a survival game, and Bungie's
;  Firefight never uses it to end a match: in every stock Firefight cache (game_won) appears exactly
;  once, as the entire body of a leftover CAMPAIGN script `end_mission` that nothing in Firefight
;  calls.  survival_spartans_increment_score and event_survival_spartans_win_normal are not engine
;  opcodes - they are SCENARIO SCRIPTS - and both are declared, void and 0-arg, in Waterfront's and
;  Outpost's own script tables, as are the stock global b_survival_game_end_condition and the dormant
;  stock script survival_end_game that awaits it.  All four were verified present in each of those
;  two caches before this edit.
;
;  What replaces it is the real end-the-match path, which both oracles agree on:
;    * Bungie's own survival_mode_end_condition_complete - the "the players finished it" case - ends
;      with exactly these four calls, in this order;
;    * the author's playtested you_win, reached by (wake you_win) from his buy_mac, ends with the
;      last three of them.
;  Nothing here calls mp_round_end_with_winning_team directly: stock survival_end_game is woken once
;  by survival_mode at startup and then sits on (sleep_until b_survival_game_end_condition 1).
;  Setting that global is the documented way in, and survival_end_game then does the sleep_forever
;  sweep of the whole survival machine before ending the round - which our own call could not do.
;
;  THE LATCH IS NO LONGER PERMANENT (audit 25, follow-up 1).  g_fe_won used to be set true and never
;  cleared inside a session, so a win that failed or was interrupted locked the station out for the
;  rest of the match after the player had already paid 10,000.  It is now cleared 1800 ticks (60 s)
;  after the end condition is raised.  If the match ended, nothing is left to observe it; if the
;  match did NOT end, the station is live again and the player can retry - at full price, because
;  fe_transact charges at the kiosk, so there is no exploit in re-opening it.  The entry test also
;  refuses to start a second win sequence while an end condition is already pending.
;
;  NOTHING IN THIS BLOCK TOUCHES THE ALLY-SLOT LOGIC (fe_has_room / fe_deliver_squad / g_fe_rotor),
;  which is this file's separate BLOCKER-W/O-1..3 and is being fixed elsewhere.
; =====================================================================================================
(script static void fe_mission_won (object kiosk)
    (if (and (not g_fe_won) (not b_survival_game_end_condition))
        (begin
            (set g_fe_won true)
            (fe_blip kiosk)
            (sleep 30)
            (ai_kill_no_statistics "gr_survival_all")
            (sleep 60)
            (fe_unblip kiosk)
            (survival_spartans_increment_score)
            (event_survival_spartans_win_normal)
            (submit_incident "survival_mm_game_complete")
            (set b_survival_game_end_condition true)
            (sleep 1800)
            (set g_fe_won false)
        )
    )
)

; =====================================================================================================
;  14. THE LONGSWORD PASS.
;
;  dm_longsword_01 is a real longsword device_machine on both maps (Waterfront at 409.43 668.95 94.47,
;  Outpost at -725.56 112.07 101.90), placement flag bit0 set on both, i.e. it must be created before
;  use.  The five calls below are copied from each map's OWN stock script, which does exactly this
;  (object_create, device_set_position_track "ff10", device_animate_position, then object_destroy).
;  The position-track name "ff10" is NOT assumed from Holdout: it is the literal string both
;  Waterfront's and Outpost's own decompiles pass, verified in each file before use.
;
;  WE DO NOT DESTROY THE DEVICE (audit 25, RISK-G2).  Stock survival_resupply_pod_spawn drives this
;  same machine and then blocks on
;      (sleep_until (>= (device_get_position "dm_longsword_01") 0.4) 1)
;  before it wakes the weapon-drop pods.  An object_destroy landing inside that window removes the
;  device the stock loop is polling, so the condition can never become true and the resupply loop -
;  an infinite (sleep_until (begin ... false)) - never completes another cycle: no further weapon or
;  grenade drops for the rest of the match.  That is the one unrecoverable interaction.
;
;  Of the three options (stop destroying / use another object / restore the position afterwards) this
;  takes the first.  There is no second longsword to retarget, and restoring the position would mean
;  writing to the device AFTER our animation, which can itself land in a stock poll window and
;  re-create exactly the deadlock we are removing.  Leaving it alone is the only fix with no new
;  window.  The remaining interaction self-heals: our device_set_position_track ... 0 can reset the
;  track under a stock animation, but our own device_animate_position immediately drives the position
;  to 1, past 0.4, which satisfies the stock poll.  Stock calls object_create and
;  device_set_position_track on this machine at the head of EVERY resupply cycle, so it needs nothing
;  of ours to persist, and it destroys the device itself at the end of each of its own cycles.  The
;  cost of this fix is cosmetic only: between our pass and the next stock resupply the longsword sits
;  at the end of its flight path instead of being removed.
; =====================================================================================================
(script static void fe_deliver_strike
    (object_create "dm_longsword_01")
    (device_set_position_track "dm_longsword_01" "ff10" 0)
    (device_animate_position "dm_longsword_01" 1 10 3 3 false)
    (sleep 90)
    (ai_kill_no_statistics "gr_survival_waves")
    (sleep 120)
)

; =====================================================================================================
;  15. AMMO RESUPPLY.  ammo_crate0 / ammo_crate1 are ammo_box equipment on both maps with placement
;      flags 0x00000101, i.e. script-created - and BOTH maps' own stock scripts create them with
;      exactly this call ((object_create_anew obj_ammo_crate0) in survival_ammo_crate_create on
;      Waterfront and survival_ammo_crate_waypoint on Outpost).  The literal object name is used here
;      instead of stock's object_name global so this file does not depend on a stock declaration.
;      Positions are inside the base on both maps: Waterfront (8.21, 222.91, 44.44) and
;      (15.53, 212.62, 43.60); Outpost (-115.36, -132.80, 14.49) and (-136.73, -129.47, 11.64).
; =====================================================================================================
(script static void fe_deliver_ammo
    (object_create_anew "ammo_crate0")
    (object_create_anew "ammo_crate1")
    (fe_blip "ammo_crate0")
    (sleep 90)
    (fe_unblip "ammo_crate0")
)

; =====================================================================================================
;  16. WHY THERE IS NO VEHICLE TIER ON EITHER MAP.  STATED, NOT HIDDEN.
;
;  Holdout sells air support by flipping sq_sur_banshee_01/02 to team human.  Neither of these maps can
;  take that station, and the reason is different on each:
;
;  WATERFRONT does ship sq_sur_banshee_01/02, but its own stock script places them from a dormant
;  script, survival_banshee_spawn, with (ai_place "sq_sur_banshee_01") (ai_place "sq_sur_banshee_02").
;  A purchase that also placed them would be a second ai_place on a squad the engine may already have
;  placed, and re-placing an occupied squad is unproven behaviour this project refuses to ship.
;  Holdout's own version avoids that by NOT calling ai_place at all - which means the purchase does
;  nothing unless a banshee happens to be alive already.  That is a real flaw in the reference, not a
;  thing to copy.
;
;  OUTPOST has no banshee squad at all.  Its only vehicle squads are sq_sur_ghost_01/02, and stock
;  does not ai_place those either: it loads them into a Phantom as cargo
;  ((f_load_phantom_cargo v_sur_phantom_01 "single" "sq_sur_ghost_01" none)).  Their single spawn point
;  carries vehicle index 1 (ghost) and sits ~60 world units from the Deck.  Placing them directly is
;  not a path stock ever takes on this map.
;
;  So the station that would have been VEHICLE SUPPORT is AMMO RESUPPLY on both maps instead - which is
;  also one of the author's own rungs (buy_ammo1 = 500) and is fully verified on both.  That leaves six
;  purchases on six stations, with no unverified call anywhere in the shop.
; =====================================================================================================

; =====================================================================================================
;  17. DIAGNOSTICS.  Debug only, and every call is behind g_fe_debug at the call site.
; =====================================================================================================
(script static void fe_report
    (if g_fe_debug (print "fe: report"))
)
