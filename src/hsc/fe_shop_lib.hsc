; =====================================================================================================
;  fe_shop_lib.hsc  -  Firefight Evolved Expanded, MAP-AGNOSTIC purchase library
;  2026-11-23.  ZERO NEW SCRIPT OBJECTS.
; =====================================================================================================
;
;  WHY THIS FILE EXISTS ALONGSIDE fe_reinforcements.hsc
;  fe_reinforcements.hsc is the proven Holdout library, and every one of its delivery scripts names a
;  Holdout object: sq_sur_drop_01..04, dm_drop_01..04, sq_sur_banshee_01/02, sc_poa.  Editing it would
;  break Holdout and collide with the other maps being ported in parallel.  This file is the same
;  design with the map-specific half removed: everything here either names NO object at all, or names
;  an object that was verified present, by direct tag read, in BOTH ff10_prototype (Overlook) and
;  ff50_park (Beachhead).  The per-map files supply the squad handles and the kiosks.
;
;  WHAT IS SHARED, AND THE READ THAT JUSTIFIES IT
;    object_name  health_pack0..5     scnr controls[0..5] on both maps, control palette
;                                     `health_station`, placement flags 0x00000000, i.e. present from
;                                     map load, clustered inside the player base.  Bungie's own
;                                     survival_health_pack_highlight tests exactly these six with
;                                     (objects_distance_to_object pack subject) at radius 3 - the same
;                                     call this file uses - so proximity on these objects is the
;                                     shipped pattern, not an experiment.
;    object_name  ammo_crate0/1       scnr equipment[0..1] on both maps, `ammo_box`, placement flags
;                                     0x00000101, i.e. script-created - and both maps' stock
;                                     survival_ammo_crate_create does (object_create_anew ...) on
;                                     exactly these two names.
;    object_name  dm_longsword_01     scnr machines on both maps, `longsword`.  Both maps' stock
;                                     resupply event drives it with
;                                     (device_set_position_track "dm_longsword_01" "ff10" 0) then
;                                     (device_animate_position ... 1 10 3 3 false), so the track name
;                                     "ff10" is attested in each map's own script.
;    ai_squad_group gr_survival_fireteams   present on both maps; reparented to ROOT by the tag build.
;    ai_squad_group gr_survival_all / gr_survival_waves   present on both maps.
;    ai_objective obj_fireteams, task `fireteams`   present on both maps with follow = player,
;                                     follow radius 3.0, and the task's squad group filter already set
;                                     to the gr_survival_fireteams index.  Bungie shipped a ready-made
;                                     "allies follow the player" task in both.
;    snd!  transition_beeps, flag_failure, omaha_ui\...\winning_bonus   all three confirmed in both
;                                     maps' tag tables (Overlook 9680/5115/10599, Beachhead
;                                     8789/4399/9729).
;
;  print IS OFF THE CRITICAL PATH.  ReachMCC_U13_Scripting.xml marks opcode 0x028 null="true"; the
;  engine will not run it.  Every print below is behind (if g_fe_debug ...).
;
;  NAMES.  Everything declared here is prefixed k_fe_ / g_fe_ / sfx_fe_ / fe_, and neither map's 197
;  stock globals nor their 359 / 377 stock scripts use any of those prefixes, so nothing is redeclared.
; =====================================================================================================


; =====================================================================================================
;  1. PRICES - THE NAMED-CONSTANTS BLOCK.  RETUNE HERE, NOWHERE ELSE.
;
;  The author's real numbers (research/14 section 6.2): marines 500 for a squad, turret 750, Warthog
;  1,000, hog upgrade 2,000, Scorpion 3,500, MAC 10,000.  He cut every launch price by 50-75% within
;  24 hours of release and cut them again three weeks later, so treat none of this as sacred.
; =====================================================================================================
(global long k_fe_cost_squad      500)      ; [AUTHOR] buy_marines = 500 for one squad.
                                            ; THE SQUAD IS FOUR BODIES ON BOTH OF THESE MAPS, not six:
                                            ; the cell this tier spawns is the stage-2 cell, whose
                                            ; `normal diff count` is 4, copied from each map's own
                                            ; sq_sur_drop_01.  125/body.
(global long k_fe_cost_spartan   1000)      ; SPARTAN TIER: 1,000 for TWO bodies = 500/body, 4x a
                                            ; trooper.  Half a round's measured income for two power
                                            ; units: a trade, not a strict upgrade.
(global long k_fe_cost_ammo       500)      ; [AUTHOR] buy_ammo1 (light weapon rack) = 500.
(global long k_fe_cost_strike    3000)      ; [AUTHOR] buy_turret3 / buy_tank rung = 3,500; 3,000 here
                                            ;          because the Longsword pass is one-shot.
(global long k_fe_bank_step       500)      ; [AUTHOR] deposit/withdraw = 500 a press.
(global long k_fe_cost_win      10000)      ; [AUTHOR] buy_mac = 10,000 and IS the win condition.

; =====================================================================================================
;  2. TUNING
;
;  k_fe_actor_limit IS THE ONE NUMBER MOST LIKELY TO NEED CHANGING.  The author shipped 8 after
;  playtesting his own map; 12 is the USER'S choice and is also what our own independent analysis
;  derived.  research/06 puts the engine ceiling at roughly 34 concurrent actors for BOTH sides, and
;  the friendly budget comes out of the same pool as the Covenant spawner, so 12 friendlies will show
;  up as thinner enemy waves rather than as an error.
;
;  12 is also exactly the maximum this wiring can field: two trooper squads of 4 plus two Spartan
;  squads of 2 = 12.  So the cap binds at the same moment the last squad handle fills.
; =====================================================================================================
(global short k_fe_actor_limit     12)      ; [USER] total living allies, troopers + Spartans together,
                                            ; counted with ai_living_count on the ROOT ally group.
                                            ; [AUTHOR's playtested value was 8.]
(global short k_fe_spartan_limit    4)      ; SPARTAN SUB-CAP: at most 4 Spartans alive, i.e. two
                                            ; purchases.  Without it a player fills the whole budget
                                            ; with the strongest unit and the trooper tier is pointless.
(global short k_fe_squad_size       4)      ; bodies per trooper purchase, = the cell's own count.
(global short k_fe_spartan_size     2)      ; bodies per Spartan purchase, = the cell's own count.
(global real  k_fe_kiosk_radius   2.5)      ; world units.  Bungie's own health-station proximity test
                                            ; on these same six objects uses 3.0; tightened so you must
                                            ; stand at the station, not merely walk past it.
(global short k_fe_dwell            8)      ; ticks the buyer must hold position.  30 ticks = 1 s.
(global short k_fe_cooldown       150)      ; 5 s anti-spam lock-out per station after a sale.
(global short k_fe_gate_spartan     1)      ; Spartans gated on SET >= 1, so set 1 is fought with troopers.
(global short k_fe_gate_strike      1)      ; gate on SET, per the author's heavy rung.
(global short k_fe_gate_win         1)      ; [AUTHOR] buy_mac waits on (>= (survival_mode_set_get) 1).

; =====================================================================================================
;  3. SOUNDS.  sfx_blip is NOT a built-in: both maps declare it themselves as a script global of type
;     `sound` holding a real tag path (line 158 of each decompile), so OURS IS PREFIXED to avoid a
;     duplicate global when this file is united with the map's own script.
; =====================================================================================================
(global sound sfx_fe_blip "sound\game_sfx\ui\transition_beeps")
(global sound sfx_fe_buy "sound\game_sfx\ui\omaha_ui\exit_experience\winning_bonus")
(global sound sfx_fe_deny "sound\game_sfx\multiplayer\flag_failure")

; =====================================================================================================
;  4. STATE
; =====================================================================================================
(global boolean g_fe_debug      false)      ; (set g_fe_debug true) for print tracing. Never shipped on.
(global boolean g_fe_open       false)      ; the shop is live.  Set by the per-map startup script.
(global long    g_fe_bank           0)      ; shared bank, as in the author's build: one global, either
                                            ; player can withdraw what the other deposited.
(global short   g_fe_buys           0)      ; successful trooper purchases this match.
(global short   g_fe_spartan_buys   0)      ; successful Spartan purchases this match.
(global boolean g_fe_won        false)      ; latch, so the win purchase can only fire once.

; =====================================================================================================
;  5. PRIMITIVES
;
;  fe_valid is Bungie's own validity guard, the same shape their survival_health_pack_highlight uses:
;  an absent player slot yields object_get_health < 0.  There is no player_in_game_count in the U13
;  table, so this is the only guard available - and it is the one both shipped maps use, for all eight
;  slots unconditionally.
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

; Proximity instead of a trigger volume.  Argument order matches Bungie's own call
; (objects_distance_to_object pack subject): first argument is object_list, second is object.
;
; THE NEGATIVE-RETURN GUARD (audit 25, RISK-G3).  objects_distance_to_object returns a NEGATIVE
; value when the object list is empty or the named object is absent, and (< -1 radius) is true.
; Without the (>= ... 0) term an absent or destroyed anchor reports EVERY player as "near" it,
; wherever they are standing, and the station fires once per cooldown for anyone who can pay.
; fe_valid already covers the player side; this covers the kiosk side.  `and` short-circuits, so
; the second distance call is only evaluated once the first has proved the object is present.
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
;  This is the author's mechanism (research/14 section 6.1): affordability and buyer identity are
;  tested together in one `or` over all eight player slots, then a parallel `cond` over the same eight
;  slots fires exactly one negative award against whoever is standing at the kiosk.
;
;  player0 is NOT used.  human_player_in_game_get returns `player`, which is exactly the first
;  argument type campaign_metagame_award_points declares, and it identifies the buyer rather than
;  always charging slot 0.
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

; The charge.  Exactly one branch of the cond fires, against the buyer, never against slot 0.
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
;  The cap is read off a ROOT squad group, exactly as the author does it, and
;  survival_wave_living_count is left COMPLETELY STOCK (research/14 section 6.4).  That works only
;  because the ally group sits outside gr_survival_all.
;
;  BOTH MAPS SHIP gr_survival_fireteams AS A CHILD of gr_survival_waves, which is a child of
;  gr_survival_all, and both maps' stock survival_wave_living_count reads
;  (ai_living_count "gr_survival_all").  Left alone, every purchased ally would be counted as a live
;  enemy, the wave would never report clear, and the round would never end.  The tag build makes the
;  group a ROOT with one 2-byte write (Overlook @0x58DD648, Beachhead @0x4F3C11C).
;  NOTHING IN THIS FILE COMPENSATES FOR THAT WRITE.  Without it the map hangs between waves.
;
;  After the reparent the group contains exactly the six fireteam handles and nothing else - the stock
;  drop-pod squads are left in their own groups, untouched - so this count is the ally count with no
;  correction term.
; =====================================================================================================
(script static short fe_allies_alive
    (ai_living_count "gr_survival_fireteams")
)

(script static short fe_slots_free
    (- k_fe_actor_limit (fe_allies_alive))
)

; =====================================================================================================
;  9. GATING - ON SET, NOT ROUND, for the expensive items.
;     survival_mode_round_get 0x483, survival_mode_set_get 0x482, both in the U13 table.
; =====================================================================================================
(script static boolean fe_gate_round (short gate)
    (>= (survival_mode_round_get) gate)
)

(script static boolean fe_gate_set (short gate)
    (>= (survival_mode_set_get) gate)
)

; =====================================================================================================
;  10. COMMITTING A SQUAD TO THE PLAYER'S SIDE.
;
;  Team is set at RUNTIME with ai_set_team (0x1E4), not by patching each squad's `team` field.  Both
;  maps' stock initialisation already declares the allegiance both ways - (ai_allegiance human player)
;  and (ai_allegiance player human) - so `human` is the correct ally team on both, and the two calls
;  below are defensive and idempotent.
;
;  THE BODIES ARE SPARTANS IN BOTH TIERS.  No stock Firefight cache contains a Marine or ODST `char`
;  tag; all eight were scanned.  The ally character is the one palette entry no stock cell references,
;  objects\characters\null\ai\null_cov_default (Overlook slot 25, Beachhead slot 21 - each re-read and
;  re-asserted against that map's own designer AND templated cells), with its `unit` tag_reference
;  repointed to objects\characters\spartans\spartans.  Allies look like Spartans and say nothing,
;  because a null character has no dialogue.  The cheap tier is therefore called TROOPERS, not Marines.
;  The tiers differ by COUNT, RANK and LOADOUT, all of it tag data:
;      troopers  4 bodies  major upgrade 3 'none'  DMR or assault rifle
;      Spartans  2 bodies  major upgrade 4 'all'   randomised heavy weapon + randomised ability
; =====================================================================================================
(script static void fe_squad_commit (ai squad)
    (ai_set_team squad human)
    (ai_allegiance human player)
    (ai_allegiance player human)
    (ai_set_task squad "obj_fireteams" "fireteams")
    (if g_fe_debug (print "fe: allies committed"))
)

; Place, then commit, then blip for 3 s so the buyer can see what arrived.  Used for both tiers,
; because on these two maps BOTH tiers spawn on foot inside the base: the tag build authored each
; ally squad's own spawn points on that map's `spartan_respawn_*` player respawn zones, so there is
; no drop-pod ride and no off-arena spawn.
(script static void fe_squad_commit_placed (ai squad)
    (ai_place squad)
    (sleep 1)
    (fe_squad_commit squad)
    (fe_blip (ai_get_object squad))
    (sleep 90)
    (fe_unblip (ai_get_object squad))
)

; Retire every ally.  ai_survival_cleanup (0x6B5) is the call both maps' stock scripts use on their
; own groups at round end.
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
;      withdraw what the other deposited (research/14 section 6.6).  One kiosk: if you can pay you
;      deposit, if you cannot and the bank holds something you withdraw.
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
;  13. AMMO RESUPPLY.  ammo_crate0/1 are equipment[0..1] on both maps, `ammo_box`, placement flags
;      0x00000101, so they are script-created - and both maps' stock survival_ammo_crate_create creates
;      them with (object_create_anew obj_ammo_crate0/1).  object_create_anew takes object_name, so the
;      literal names are used directly instead of stock's device_name globals.
; =====================================================================================================
(script static void fe_deliver_ammo
    (object_create_anew "ammo_crate0")
    (object_create_anew "ammo_crate1")
    (fe_blip "ammo_crate0")
    (sleep 90)
    (fe_unblip "ammo_crate0")
)

; =====================================================================================================
;  14. THE LONGSWORD PASS.
;
;  dm_longsword_01 is a real longsword device_machine on both maps.  Both maps' stock resupply event
;  drives it with exactly the three calls below, including the position track name "ff10", so none of
;  it is guessed.  The strike itself is ai_kill_no_statistics on gr_survival_waves - the wave group,
;  which after the reparent no longer contains the ally group, so a Longsword pass cannot kill the
;  player's own troopers.
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
;  15. THE WIN PURCHASE.
;
;  The author's 10,000-point MAC strike IS the win condition.  gr_survival_all is killed first so the
;  arena is clear when the match ends; after the reparent that group no longer contains the allies.
;
;  Neither of these two maps places a cruiser object (Holdout's sc_poa), so there is no ship to blip
;  and none is invented - the sale cue and the kill are the whole feedback.
;
;  (game_won) WAS WRONG AND IS GONE (audit 25, BLOCKER-G1).  It is a live opcode (0x442) in the U13
;  table, but being in the table says nothing about what it does inside a survival game, and Bungie's
;  Firefight never uses it to end a match: in every stock Firefight cache (game_won) appears exactly
;  once, as the entire body of a leftover CAMPAIGN script `end_mission` that nothing in Firefight
;  calls.  The earlier note in this file claiming survival_spartans_increment_score and
;  event_survival_spartans_win_normal "are NOT in the U13 table" confused two different namespaces:
;  they are not engine opcodes, they are SCENARIO SCRIPTS, and both are declared in this map's own
;  script table - verified in each of the seven target caches before this edit.
;
;  What replaces it is the real end-the-match path, which both oracles agree on:
;    * Bungie's own survival_mode_end_condition_complete - the "the players finished it" case - ends
;      with exactly these four calls, in this order;
;    * the author's playtested you_win, reached by (wake you_win) from his buy_mac, ends with the
;      last three of them.
;  survival_spartans_increment_score is kept because it is in Bungie's win sequence and the audit
;  noted the mod would otherwise end with a wrong score; it is a 0-arg scenario script present in all
;  seven caches.  Nothing here calls mp_round_end_with_winning_team directly: stock survival_end_game
;  is a dormant script that survival_mode wakes once at startup and that then sits on
;  (sleep_until b_survival_game_end_condition 1).  Setting that global is the documented way in, and
;  survival_end_game does the sleep_forever sweep of the whole survival machine before ending the
;  round - which our own call could not do.
;
;  THE LATCH IS NO LONGER PERMANENT (audit 25, follow-up 1).  g_fe_won used to be set true and never
;  cleared inside a session, so a win that failed or was interrupted locked the station out for the
;  rest of the match after the player had already paid 10,000.  It is now cleared 1800 ticks (60 s)
;  after the end condition is raised.  If the match ended, nothing is left to observe it; if the
;  match did NOT end, the station is live again and the player can retry - at full price, because
;  fe_transact charges at the kiosk, so there is no exploit in re-opening it.  The entry test also
;  refuses to start a second win sequence while an end condition is already pending.
; =====================================================================================================
(script static void fe_mission_won
    (if (and (not g_fe_won) (not b_survival_game_end_condition))
        (begin
            (set g_fe_won true)
            (sleep 30)
            (ai_kill_no_statistics "gr_survival_all")
            (sleep 60)
            (survival_spartans_increment_score)
            (event_survival_spartans_win_normal)
            (submit_incident "survival_mm_game_complete")
            (set b_survival_game_end_condition true)
            (sleep 1800)
            (set g_fe_won false)
        )
    )
)
