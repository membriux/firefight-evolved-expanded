# 14 — First contact with a real Halo: Reach MCC map

Subject file: `/Users/sancjgui/Desktop/ff_unearthed.map`, 912,527,360 bytes (870.3 MiB).
SHA-1 `21e4066fc760d7fa025446a7319decdb75ade4da`.

The file was never written to. As a first action its permissions were changed to
`0444` (read-only for all) and the SHA-1 above was recorded; every tool in this
teardown opens it read-only and all derived data was written elsewhere. Nothing
in `tools/map/reach_write.py` was invoked.

Verdict up front: **the map is the MODIFIED "Halo Reach: Evolved" build, not stock
Unearthed**, and the author's purchasable-ally implementation has been recovered
in full, readable HaloScript.

---

## 1. Header

Our parser handled the real file without a single warning or exception. This was
its first contact with real bytes; `stderr` was empty and the `warnings` list in
`extracted/header.json` is empty. No field had to be forced, and no heuristic
fallback fired — the header layout was selected by an exact build-string match
against the engine table, not by scoring.

| Field | Value |
|---|---|
| Endianness | little (PC / MCC) |
| Engine version (`+0x4`) | 13 |
| Header layout variant | `mcc-u8+` (build string moved to `0xA0`, index header address at `0x2E8`) |
| Build string | `Jul 16 2023 16:12:13` |
| Engine identified | Halo: Reach MCC **Toolset Update 3** |
| Header size | `0xA000` (40,960) |
| Footer magic | present |
| Cache type | campaign / single player |
| Internal name | `ff_unearthed` |
| Scenario path | `levels\dlc\ff_unearthed\ff_unearthed` |
| Cache build date | absent (field is empty in this layout) |
| Checksum field | `0xB35A145C` |
| Compressed | no — the file is a plain uncompressed cache; the Saber gen-1/gen-2 probes in the parser were not triggered |
| Virtual base address | `0x1C9020000` |
| Tag-data (`meta`) area | file offset `0x2F3F9000`, size `0x6FE0000` (111.9 MiB) |
| Pointer expansion | `virtual = (stored << 2) + 0x50000000` |

Interop sections, as read from the header:

| # | Section | Virtual address | Size | Offset mask |
|---|---|---|---|---|
| 0 | debug | `0x363D9000` | `0x00268000` | 0 |
| 1 | resource | `0x0000A000` | `0x2F068000` | 0 |
| 2 | tag | `0x2F3F9000` | `0x06FE0000` | 0 |
| 3 | localization | `0x2F072000` | `0x00387000` | 0 |

Index header at file offset `0x2FA80CB0`, magic `tags` verified.

String tables: 17,983 tag names and 49,514 stringIDs, resolved across 17
stringID namespaces read from the cache's own namespace table. The tag-name and
stringID tables live in the debug section and were reached through the
`offset = pointer + debug_mask` conversion with `debug_mask = 0`.

Two of the 17,983 tag-table entries are null, which in Reach normally means the
tag is resolved from a shared cache rather than from this map.

### Pointer arithmetic that the tools do not yet derive for you

The script decompiler takes the whole map as a blob and needs a `--base-va` so
that `blob_offset = virtual_address - base_va`. For any MCC Reach cache that
value is

```
base_va = virtual_base - meta_offset
```

which here is `0x1C9020000 - 0x2F3F9000 = 0x199C27000`. The `scnr` tag sits at
file offset `0x306D9FC8`. Those two numbers, plus the default expansion magic
`0x50000000`, are the only manual inputs the decompiler needed. This should be
plumbed automatically from the parser into the decompiler; see section 8.

---

## 2. Stock or modified

**Modified. Confidence: certain.** Four independent lines of evidence, any one
of which would be sufficient:

1. **The build string is a toolset build, not a retail build.** `Jul 16 2023
   16:12:13` is the Halo: Reach MCC *Toolset* Update 3 build. The retail build of
   the same era is Update 13, `Jun 21 2023 15:35:31`. A map shipped by 343 in the
   player's MCC install carries the retail build string. A toolset build string
   means the cache was re-compiled by the modding toolset. This alone settles it.

2. **A whole private tag namespace, `dw4\`, with 1,185 tags.** Bungie and 343
   tag paths live under `objects\`, `levels\`, `sound\`, `multiplayer\`,
   `globals\`, `ui\`, `scenarios\`, `fx\` and similar. This map has 1,185 tags
   rooted at `dw4\`, spread over 40 tag groups: 130 `hlmt`, 124 `rmsh`, 102
   `mode`, 88 `effe`, 74 `bitm`, 60 `jpt!`, 57 `weap`, 50 `snd!`, 46 `scen`, 46
   `proj`, 41 `char`, 36 `bloc`, 29 `ctrl`, 27 `vehi`, 21 `chdt`, 17 `bipd` and
   so on. `dw4` is the author's own prefix; nearly every AI character in the map
   is a `_dw4` variant (`grunt_dw4`, `brute_chieftain_armor_dw4`,
   `skirmisher_murmillone_dw4`, `elite_bob_dw4`, `hunter_pyro`,
   `brute_stalker`), and the whole vehicle palette is `_dw4`
   (`phantom_dw4`, `wraith_dw4`, `scorpion_dw4`, `pelican_dw4`,
   `mac_15cm_mark_2488`, `apparition`, `tuning_fork_dw4`).

3. **Twenty-nine purchase device controls that do not exist in stock Reach**, all
   under `dw4\objects\levels\shared\device_controls\firefight\`:
   `buy_rifle_weapon_rack`, `buy_light_weapon_rack`, `buy_scorpion`, `buy_hog`,
   `buy_turret_mg`, `buy_marines`, `buy_mac`, `buy_holo`, `buy_jetpack`,
   `buy_evade`, `buy_camo`, `buy_os`, `buy_powerfist`, `buy_speedboost`,
   `buy_dropshield`, `buy_turret`, `buy_hog_upgrade`, `buy_base_power`,
   `buy_mystery_box`, `buy_jugg`, `deposit`, `withdraw`, `max_capacity`, plus
   gating signs `scorpion_r3`, `turret_switch`, `turret_r3`, `mac_s2`, `hog_r2`,
   `hog_up_wait`.

4. **Script count.** The scenario carries **485 scripts, 277 globals and 52,711
   expressions**, with a 38,201-byte script string table. Stock Reach Firefight
   scenarios are an order of magnitude smaller. The script bodies include whole
   subsystems with no Bungie equivalent: a shop, a bank, a mystery box, a
   juggernaut objective, CTF/oddball/HVT/race objectives inside Firefight, and a
   purchasable win condition.

Secondary corroboration: the audio the shop plays is the author's own
(`dw4\sound\game_sfx\chaching2\chaching2`), and the map fires custom campaign
incidents named `evolved_un_3`, `evolved_un_4`, `evolved_un_8` — the string
`evolved` appears 19 times in tag paths, including `dw4\ui\chud\evolved_br`.

---

## 3. Tag index

**17,983 tags across 235 tag groups.** The full listing is in
`extracted/tags.tsv` (index, datum, group, estimated size, path) and
`extracted/tags.json`; `extracted/tag_groups.tsv` has the group census.

The tags the project cares about:

| Group | Count | Where the single/global one lives | Tag index |
|---|---|---|---|
| `scnr` scenario | 1 | `levels\dlc\ff_unearthed\ff_unearthed` | 8 (global tag) |
| `smdt` survival_mode_globals | 1 | `firefight\firefight_globals` | 32 |
| `sqtm` squad_template | 159 | `ai\squad_templates\*` | — |
| `wave` wave_template | 32 | — | — |
| `char` character | 110 (41 of them `dw4\`) | — | — |
| `msit` megalo_string_id_table | 1 | `multiplayer\megalo\global` | 16,148 |
| `mulg` multiplayer_globals | 1 | `multiplayer\multiplayer_globals` | 16 |
| `matg` globals | 1 | `globals\globals` | 5 |
| `coop` coop_spawning_globals | 2 | `globals\ff`, `globals\mp` | 16,071 / 16,147 |

Global tags present: `draw`=0, `gpix`=1, `play`=2, `ugh!`=3, `zone`=4, `matg`=5,
`scnr`=8.

**There is no `hsc*` tag in this map, and no tag group whose code starts with
`hsc`.** HaloScript *source* is therefore not recoverable from the cache; the
scripts had to be decompiled from the compiled expression tree. (A
`scenario_hs_source_file` definition does exist in the MCC tag definitions, and
our `reach_cache.read_hsc_source` handles it — there is simply no instance here.
Source-bearing `hsc*` tags are stripped when a cache is built for release.)

---

## 4. Extracted artifacts

Written to `/Users/sancjgui/Desktop/Firefight Evolved Expanded/extracted/`:

| File | Size | Contents |
|---|---|---|
| `header.json` | 2.8 KB | the parsed header, as a machine-readable record |
| `tags.tsv` | 2.1 MB | all 17,983 tags: index, datum, group, offset, estimated size, path |
| `tags.json` | 5.1 MB | the same, structured |
| `tag_names.txt` | 1.1 MB | the tag-name string table |
| `stringids.txt` | 1.5 MB | all 49,514 stringIDs, flat index order |
| `tag_groups.tsv` | 8.7 KB | the 235-group census with counts |
| `manifest.json` | 64 KB | what was extracted and from where |
| `tags/` | 304 files | per-tag root-block binaries plus JSON side-cars for `scnr`, `smdt`, `sqtm`, `wave`, `msit`, `char`, `mulg`, `matg`, `coop` |
| `tags/0008_scnr_levels_dlc_ff_unearthed_ff_unearthed.bin` | 2,156 B | the `scnr` root block |
| `tags/0032_smdt_firefight_firefight_globals.bin` | 176 B | the `smdt` root block |
| `scnr_squads.json` | — | squad groups (with parent links), squads, cells, character palette, vehicle palette — produced by a new dumper, see section 7 |
| `stringids_resolved.json` | 1.6 MB | 44,766 `{raw_stringID: name}` pairs resolved through the cache's namespace table — the input the decompiler actually needs (see section 5) |
| `hsc/ff_unearthed_u13.hsc` | 504 KB, 16,195 lines | the decompiled scripts |
| `hsc/ff_unearthed_u13_raw.json` | 2.7 MB | the raw decoded script/global/expression tables |

Reproduction helpers added to `tools/map/`: `defwalk.py` (definition-driven
struct layout walker over the MCC tag-definition dumps) and `dump_squads.py`
(produces `extracted/scnr_squads.json`).

Note on sizes: the per-tag `.bin` files hold only each tag's **root block**. The
child tag blocks (squads, cells, scripts, expressions) live elsewhere in the
111.9 MiB tag-data area and are reached by pointer; they are not inside those
small binaries. The `scnr` root block is 2,156 bytes against a definition size
of 2,136 bytes (`scenario_struct_definition`), which is the expected agreement.

---

## 5. Decompiling the scripts

### Choosing the opcode table

The build is MCC Toolset Update 3, which post-dates retail Update 13. The U13
opcode table is therefore the correct one, and the layout probe agreed
unambiguously — of the five candidate scenario-script layouts, only
`reachmcc_u13` produced a self-consistent header:

```
reach360       no   no scripts, globals or expressions
reachalpha     no   script_count out of range (1585163259)
reachbeta      no   no scripts, globals or expressions
reachmcc       no   no scripts, globals or expressions
reachmcc_u13   PLAUSIBLE
   scripts=485 globals=277 exprs=52711 strtab_size=38201 expr_addr=0x5E720044
```

Command used:

```
python3 tools/hsc/decompile.py /Users/sancjgui/Desktop/ff_unearthed.map \
  --base-va 0x199C27000 --scnr-offset 0x306D9FC8 \
  --variant reachmcc_u13 --table tools/hsc/tables/reachmcc_u13.xml \
  --stringids <resolved-stringid-map.json> \
  --out extracted/hsc/ff_unearthed_u13.hsc \
  --json extracted/hsc/ff_unearthed_u13_raw.json
```

### Validation — passed

| Required stock name | Occurrences |
|---|---|
| `survival_mode_begin_new_wave` | 17 |
| `ai_place_wave` | 7 |
| `survival_total_score` | 7 |
| `campaign_metagame_award_points` | 206 |
| `ai_place` | 42 |

Beyond the three required names, the first thirty script names are a verbatim
run of Bungie's own Firefight library — `survival_ai_limit`,
`survival_wave_timer`, `survival_garbage_collector`, `survival_wave_spawn`,
`survival_wave_living_count`, `survival_wave_end_conditions`,
`survival_kill_volumes_on` / `_off`, `survival_total_score`,
`survival_dropship_spawner`, `f_survival_load_phantom`,
`f_survival_load_spirit`, `survival_callout_dropship_internal` — and the global
block opens with Bungie's exact Firefight globals (`gr_survival_phantom`,
`ai_sur_wave_spawns`, `ai_sur_fireteam_squad0..5`, `s_sur_wave_squad_count`,
`obj_sur_generator0..2`). The 206 `campaign_metagame_award_points` call sites all
carry a plausible score literal. The output is reliable.

### A real bug found in our decompiler

On the first pass the script *bodies* were correct but every script *name* was
wrong: script 0 came out as `privacy_full`, then `privacy_offline`, `roster`,
`player_rank`, `bungienet_user` — a contiguous run of unrelated UI stringIDs.
Globals were fine, because `decompile.py` reads a global's name as an inline
32-byte string. A script's name, by contrast, is a stringID, and the tool looked
it up in a flat table keyed by raw stringID value. That is wrong for MCC Reach:
stringIDs are namespaced (17-bit index, 8-bit namespace, 7-bit length), and the
cache carries its own namespace table. Resolving script name stringID `2141`
through `reach_cache.ReachCacheFile.resolve_sid` gives `survival_ai_limit`;
indexing the flat dump at 2141 gives `privacy_full`.

The fix applied here was to generate the `--stringids` map by calling
`resolve_sid` over the stringID space and dropping unresolved entries (44,766
usable names), then re-running. All 485 script names and all parameter names then
came out as real, meaningful identifiers. **`decompile.py` should resolve script
name stringIDs through the cache's namespace table rather than accept a flat
table**; the current `--stringids` contract silently produces confident nonsense
for names. This is exactly the failure mode the brief warned about, arriving from
an unexpected direction — the opcode table was right, the *name* table was wrong.

---

## 6. The author's implementation

This is the prize. Everything below is read directly out of
`extracted/hsc/ff_unearthed_u13.hsc`.

### 6.1 How score is deducted

Yes — it is a **negative `campaign_metagame_award_points`**, and it is charged to
*the specific player standing in the kiosk's trigger volume*, not to player 0.
Every purchase follows one rigid template. Taking the marines as the example:

```
(script dormant void buy_marines
  (sleep_until
    (begin
      (sleep_until (> (device_get_position "buy_marines") 0) 1)
      (if
        (or
          (and (>= (campaign_metagame_get_player_score (list_get (players_human) 0)) 500)
               (volume_test_object "tv_marines" (list_get (players_human) 0)))
          ... repeated for players 1 through 7 ...
        )
        (begin
          (sound_impulse_start "dw4\sound\game_sfx\chaching2\chaching2" "marinesk" 5)
          (cond
            ((volume_test_object "tv_marines" (list_get (players_human) 0))
              (campaign_metagame_award_points (list_get (players_human) 0) -500))
            ... repeated for players 1 through 7 ...
          )
          (ai_place "marine_pelican")
          (object_destroy "buy_marines")
          (set marines_bought_first_time true))
        (begin
          (sound_impulse_start "sound\game_sfx\multiplayer\flag_failure" "marinesk" 5)
          (device_set_position "buy_marines" 0)))
      false)))
```

The five moving parts, in order:

1. **Input** is a `device_control` (`ctrl`) tag placed in the scenario. The script
   blocks on `(sleep_until (> (device_get_position "<name>") 0) 1)` — the player's
   hold-to-use interaction drives the device's position off zero. There is no
   button polling and no Megalo involvement.
2. **Affordability and buyer identity** are tested together, in one `or` over all
   eight player slots: `campaign_metagame_get_player_score` for the money and
   `volume_test_object "tv_<item>"` for "this player is the one at the terminal".
3. **The charge** is a second, parallel `cond` over the same eight slots that
   fires exactly one negative `campaign_metagame_award_points` against whoever is
   in the volume.
4. **Success** plays the author's own `chaching2` sound, delivers the goods, and
   destroys the terminal object.
5. **Failure** plays stock `sound\game_sfx\multiplayer\flag_failure` and resets
   the device with `(device_set_position "<name>" 0)`, so the prompt re-arms.

Each purchase is a `dormant` script woken by a gating script (section 6.5) and
wrapped in `(sleep_until (begin ... false))`, which is the author's idiom for an
infinite service loop.

### 6.2 Every price, as a literal

Read from the `campaign_metagame_award_points` argument inside each `buy_*`
script. The device-control tag and the trigger volume for each are listed because
they are the author's naming convention and we will want to copy it.

| Script | Price | Device (`device_get_position`) | Volume |
|---|---|---|---|
| `buy_hologram` | 200 | `holo` | `tv_holo` |
| `buy_evade` | 200 | `evade` | `tv_evade` |
| `buy_speedboost` | 300 | `speed` | `tv_speed` |
| `buy_powerfist` | 300 | `fist` | `tv_powerfist` |
| `buy_power` (base power) | 350 | `base_power` | `tv_power` |
| `buy_dropshield` | 400 | `drop` | `tv_drop` |
| `buy_jetpack` | 400 | `jetpack` | `tv_jetpack` |
| **`buy_marines`** | **500** | `buy_marines` | `tv_marines` |
| `buy_overshield` | 500 | `os` | `tv_os` |
| `buy_camo` | 500 | `camo` | `tv_camo` |
| `buy_ammo1` (light weapon rack) | 500 | `light_weap` | `tv_ammo1` |
| `deposit` (bank in) | 500 | `deposit` | `tv_deposit` |
| `buy_turret1` | 750 | `mg` | `tv_turret` |
| `buy_turret2` | 750 | `mg2` | `tv_turret2` |
| `buy_mysterybox` | 950 | `mystery_box` | `tv_mbox` |
| `buy_hog` (Warthog) | 1,000 | `buy_hog` | `tv_warthog` |
| `buy_ammo2` (rifle weapon rack) | 1,000 | `rifle_weap` | `tv_ammo2` |
| `buy_hogup` (Warthog upgrade) | 2,000 | `buy_hogup` | `tv_hogup` |
| `buy_tank` (Scorpion) | 3,500 | `buy_scorpion` | `tv_scorpion` |
| `buy_turret3` | 3,500 | `turret3` | `tv_turret3` |
| **`buy_mac`** (win condition) | **10,000** | `buy_mac` | `tv_mac` |

`withdraw` is the only non-negative counterpart: `+500` per press, gated on
`(> s_bank_count 0)`.

The distinct negative literals and their call-site counts are 200 (×16), 300
(×16), 350 (×8), 400 (×16), 500 (×40), 750 (×16), 950 (×8), 1,000 (×16), 2,000
(×8), 3,500 (×16), 10,000 (×8) — each price appearing eight times per purchase
because of the eight-player `cond`, so sixteen means two different items share
that price.

### 6.3 The Marines

**Squad name: `marine_rein`.** Four marines per purchase.

- `(ai_place "marine_rein")` is called **once**, and not from `buy_marines`.
  `buy_marines` places `marine_pelican` — the dropship. The Pelican's command
  script `pelican_marine_drop` then flies the route and places the marines
  mid-flight:
  ```
  (cs_ignore_obstacles true)
  (cs_vehicle_speed 0.75)
  ... blip the Pelican to all 8 players ...
  (cs_fly_to "ps_marine_pelican/p0")
  (cs_fly_to "ps_marine_pelican/p1")
  (ai_place "marine_rein")
  (ai_vehicle_enter_immediate "marine_rein/a" (ai_vehicle_get_from_starting_location "marine_pelican/pelican") pelican_p_r05)
  (ai_vehicle_enter_immediate "marine_rein/b" ... pelican_p_l04)
  (ai_vehicle_enter_immediate "marine_rein/c" ... pelican_p_r04)
  (ai_vehicle_enter_immediate "marine_rein/d" ... pelican_p_l05)
  (cs_fly_to "ps_marine_pelican/p2")
  (cs_fly_to_and_face "ps_marine_pelican/p3" "ps_marine_pelican/face0")
  (unit_open (ai_vehicle_get ai_current_actor))
  (sleep 60)
  (vehicle_unload (ai_vehicle_get ai_current_actor) pelican_p)
  (f_blip_ai "marine_rein" 5)
  (sleep 60)
  (chud_track_object ... false)
  (sleep 60)
  (unit_close (ai_vehicle_get ai_current_actor))
  ... fly the reverse route, p2 -> p1 -> p0 -> p4 ...
  (object_destroy (ai_vehicle_get_from_starting_location "marine_pelican/pelican"))
  (ai_erase ai_current_actor)
  ```
  So the marines are spawned, seated in four named Pelican seats, flown in,
  unloaded, blipped for the players, and the Pelican is destroyed and erased.
  This is a far more expensive presentation than a bare `ai_place`.
- `marine_rein/a`, `/b`, `/c`, `/d` are the squad's four **starting locations**,
  confirmed against the compiled scenario: the squad has a `spawn_points_block`
  of exactly four entries whose name stringIDs resolve to `a`, `b`, `c`, `d`, all
  pointing at cell 0.
- Once landed, the marines are kept on task by `refresh_gate_marines` and
  `refresh_gate_marines_defenders`, which `(sleep 5)` then
  `ai_reset_objective "obj_marines/gate_marine_followers"` and
  `"obj_marines/gate_marines_defenders"` respectively.

### 6.4 The concurrent-ally cap, and keeping allies out of the wave count

**The cap is 8 living allies, enforced by a dedicated `dormant` script
`infantry_limit`:**

```
(script dormant void infantry_limit
  (sleep_until
    (begin
      (if (>= (ai_living_count "gr_survival_marines") 8)
        (begin
          (object_destroy "buy_marines")
          (object_create_anew "max_cap")))
      (if (and (<= (ai_living_count "gr_survival_marines") 8)
               (= marines_bought_first_time false))
        (begin
          (object_destroy "max_cap")
          (object_create_anew "buy_marines")))
      ...)))
```

At the cap the buy terminal is destroyed and replaced by a `max_capacity` sign
object (`max_cap`); below the cap, and only if a purchase is not already in
flight, the terminal is restored. The `marines_bought_first_time` boolean is the
in-flight latch: `buy_marines` sets it true on a successful purchase, and
`marine_resupply` clears it:

```
(script dormant void marine_resupply
  (sleep_until
    (begin
      (sleep_until (and (<= (ai_living_count "marine_pelican") 0)
                        (= marines_bought_first_time true)) 60)
      (if (<= (ai_living_count "gr_survival_marines") 0)
        (begin
          (object_create_anew "buy_marines")
          ... blip "buy_marines" with blip_interface to all 8 players ...
          (sleep 210)
          (f_unblip_object "buy_marines")
          (set marines_bought_first_time false)))
      false)))
```

So the terminal comes back, and is highlighted for three and a half seconds, only
after the Pelican has left *and* every ally is dead.

**Allies are kept out of the wave-clear count structurally, by squad-group
hierarchy, not by filtering.** The stock counter is untouched:

```
(script static short survival_wave_living_count
  (+ (ai_living_count "gr_survival_all")
     (ai_living_count "gr_survival_remaining")
     (max 0 (- (ai_living_count ai_sur_phantom_01) s_sur_dropship_crew_count))
     (max 0 (- (ai_living_count ai_sur_phantom_02) s_sur_dropship_crew_count))
     (max 0 (- (ai_living_count ai_sur_phantom_03) s_sur_dropship_crew_count))
     (max 0 (- (ai_living_count ai_sur_phantom_04) s_sur_dropship_crew_count))))
```

The scenario's 25 squad groups and their parent links (read out of
`squad_groups_block`) show why that is enough:

```
gr_survival_all                 (no parent)
  gr_survival_waves             -> gr_survival_all
    gr_survival_fireteams       -> gr_survival_waves
gr_survival_extras              (no parent)
  gr_wraiths, gr_ghosts, gr_survival_cov_drop_pod, gr_survival_snipers,
  gr_survival_banshees, gr_survival_buggers, gr_survival_bob  -> gr_survival_extras
gr_survival_remaining           (no parent)
gr_survival_phantoms            (no parent)
gr_survival_ini_cov             (no parent)
gr_survival_marines             (no parent)          <-- allies
  gr_survival_marines_followers -> gr_survival_marines
gr_survival_aft, gr_survival_grm (no parent)
```

`gr_survival_marines` is a **root** group. It is not under `gr_survival_all`, so
`ai_living_count "gr_survival_all"` can never see an ally, and the wave never
fails to end because friendlies are alive. The cap check reads the ally root
group, which *does* include `gr_survival_marines_followers` (where `marine_rein`
lives) plus the pre-placed `sq_sur_ini_odsts`, so the pre-placed ODSTs count
against the budget of 8. Four pre-placed ODSTs plus one four-marine purchase
exactly fills it.

Note also `(script static void survival_wave_end_conditions (sleep_until (< (survival_wave_living_count) 7)) ...)`
— the wave-end threshold is the literal 7, even though the globals
`k_sur_ai_end_limit` and `k_sur_ai_rand_limit` exist and are 0. Whether that 7 is
the author's change or stock for this map is not established here; flagging it as
an open question.

### 6.5 Gating

Purchases are `dormant` scripts woken by unlock scripts as the match progresses.

- `buy_power` is woken at the start (from the initialisation path that also sets
  up `sq_sur_ini_odsts` with `ai_set_task "sq_sur_ini_odsts" "obj_marines" "gate_marines_defenders"`).
- The marine, turret 1/2 and ammo shops, plus `mystery_box` and the armour
  abilities, are woken once base power is online — the same block does
  `(wake infantry_limit)`, `(wake buy_marines)`, `(wake marine_resupply)`,
  `(wake buy_ammo1)`, `(wake buy_ammo2)`, and creates the `box` / `mbox` objects.
- `shop_round_unlocks` waits on
  `(and (>= (survival_mode_round_get) 1) (= power_online true))`, destroys the
  `hog_r2` "available round 2" sign, creates `buy_hog` and `buy_hogup`, wakes
  both, and fires `submit_incident_with_cause_campaign_team "evolved_un_3"`.
- A later round gate destroys `turret_r3` / `scorpion_r3`, creates `turret3` and
  `buy_scorpion`, wakes `buy_tank` and `buy_turret3`, and fires `evolved_un_4`.
- The MAC waits on `(>= (survival_mode_set_get) 1)` — set 2 — destroys `mac_s2`,
  creates `buy_mac`, wakes it, and fires `evolved_un_8`.
- `buy_mac` succeeding blips `sc_cannon_cruiser_target` to all eight players and
  calls `(wake you_win)`. The 10,000-point MAC strike *is* the win condition.

### 6.6 The bank

Two separate kiosks, 500 points a press, against one shared short
`s_bank_count` (initial 0):

- `deposit`: charge `-500` to the player in `tv_deposit`, then
  `(set s_bank_count (+ s_bank_count 500))`, destroy the `deposit` object,
  `(sleep 40)`, re-create it. The 40-tick (0.67 s) cooldown is the anti-spam
  buffer.
- `withdraw`: gated on `(> s_bank_count 0)`, award `+500` to the player in
  `tv_withdraw`, then `(set s_bank_count (- s_bank_count 500))`.

The bank is **shared across all players**, not per-player: one global short, and
either player can withdraw what the other deposited.

### 6.7 Other author subsystems present

Visible in the script and tag data, not analysed in depth here: a mystery box
(`buy_mysterybox` at 950, `mystery_box`, `box_counter1..3`, `box_weapon_deleted`,
globals `mystery_weapon`, `mystery_box_counter`, `box_timer`, `box_ready`,
`box_pass_check`, `box_0..2`), a juggernaut objective
(`page_objectives_juggernaut (ai inf_squad, ai vehicle_squad)`, `buy_jugg`
device), in-Firefight CTF / oddball / HVT / race objectives (`ctf_start`,
`oddball_start`, `hvt_start`, `race_start`, `hill_0..4`, `race_laps`,
`ball_points`), a named boss (`sq_sur_bob` with `elite_bob_dw4`, global
`vadambear` and `vadambear_line`), buyable armour abilities, a MAC cannon, and a
turret network (`turret1`, `cs_turret_online`, `cs_turret_offline`,
`f_turret (ai turret, device switch)`, `s_turret_online_count`).

### 6.8 Where our inferences in `src/hsc/` were wrong

Comparing the author's real implementation against `src/hsc/fe_reinforcements.hsc`:

| Topic | What we built | What he actually does | Verdict |
|---|---|---|---|
| Deduct mechanism | `(campaign_metagame_award_points (player0) (- 0 cost))` in `fe_charge` | negative `campaign_metagame_award_points` — same opcode, same sign | **right** |
| Who pays | hard-coded `(player0)` | an 8-way `cond` over `volume_test_object "tv_<item>"` on `(list_get (players_human) N)`; the player at the terminal pays | **wrong, and this is the biggest gap** — our version charges player 0 for everyone's purchases, which breaks co-op |
| Affordability check | `fe_can_afford` / `fe_try_buy` helper scripts taking `(long cost)` | no helpers at all; the score test is inlined 8 times per purchase alongside the volume test, in one `or` | **ours is better factored, his is what the engine actually ran** — note his style is fully unrolled, which matters if we ever need to match his expression budget |
| Marine price | `k_fe_cost_marines 500` | 500 | **right** |
| ODST price | `k_fe_cost_odst 750` | no ODST purchase exists on this map; the 4 ODSTs are pre-placed free (`sq_sur_ini_odsts`) and 750 is his turret price | **wrong item** — 750 is `buy_turret1` / `buy_turret2` |
| Turret price | `k_fe_cost_turret 750` | 750 | **right** |
| Map-state / weapon rack | `k_fe_cost_map_state 1000` | rifle rack 1,000, light rack 500 | **half right** — he has two tiers, we had one |
| Turret upgrade | `k_fe_cost_turret_upgrade 1000` (derived) | no turret upgrade; `buy_turret3` is a separate 3,500 heavy turret | **wrong** |
| Light vehicle | `k_fe_cost_light_vehicle 1000` | Warthog 1,000 | **right** |
| Set item / upgrade | `k_fe_cost_set_item 2000` | Warthog upgrade (Gauss) 2,000 | **right** |
| Superweapon | `k_fe_cost_superweapon 3000` (derived) | Scorpion 3,500 and heavy turret 3,500 | **close, 3,500 not 3,000** |
| Win purchase | `k_fe_cost_win 8000`, discount variant 6,000 (both derived) | MAC strike 10,000, single price, no discount branch | **wrong** — 10,000, and the win is a one-shot `(wake you_win)` after a 10,000 charge, not a tiered thing |
| Win round gate | `k_fe_win_round_gate 5` (derived) | gated on `(>= (survival_mode_set_get) 1)`, i.e. set 2, not a round number | **wrong unit** — he gates the win on *set*, and gates vehicles on *round* |
| Concurrent ally cap | `k_fe_actor_limit 12` | 8, via `(>= (ai_living_count "gr_survival_marines") 8)` | **wrong number** — 8, not 12 |
| Free garrison size | `k_fe_free_squad_size 6` | 4 (`sq_sur_ini_odsts`, one cell, 4 actors) | **wrong** — 4 |
| Bought squad size | `k_fe_buy_squad_size 8` | 4 (`marine_rein`, one cell, 4 actors, 4 starting locations a/b/c/d) | **wrong** — 4 per purchase, with 8 as the *total* cap, i.e. we conflated squad size with the cap |
| Squad expiry | `k_fe_squad_lifetime 9000` (300 s timed expiry) | no timer; the terminal returns only when the Pelican is gone **and** every ally is dead (`marine_resupply`) | **wrong mechanism** — he recovers budget by attrition, not by a lifetime |
| Separate groups for allies | `fe_refresh_gate_marines`, `..._followers`, `..._defenders` | `refresh_gate_marines`, `refresh_gate_marines_defenders`, and the real group tree `gr_survival_marines` (root) with `gr_survival_marines_followers` as its child | **right idea, right names, right structure** — this one we got essentially exactly |
| Keeping allies out of the wave count | explicit exclusion logic | nothing; `gr_survival_marines` is simply a root squad group outside `gr_survival_all`, and `survival_wave_living_count` is left stock | **ours is unnecessary** — the group tree does it for free, and his approach is strictly safer |
| Bank step | 500 per press, two kiosks, shared pot | 500 per press, two kiosks (`deposit` / `withdraw`), one shared `s_bank_count` | **right, including the 500 and the two-kiosk choice** |
| Bank anti-spam | second buffer | `object_destroy` + `(sleep 40)` + `object_create_anew` on the deposit kiosk | **right idea, now we have his exact implementation** |
| Input method | assumed device/volume | `device_get_position` on a `ctrl` tag plus `volume_test_object` on a `tv_*` volume | **right** |
| Arrival presentation | `fe_squad_arrive` | a full Pelican command script: blip, `cs_fly_to` route, four `ai_vehicle_enter_immediate` into named seats, `unit_open`, `vehicle_unload`, `f_blip_ai`, `unit_close`, reverse route, `object_destroy`, `ai_erase` | **we under-scoped this considerably** |

Summary of the delta: our *mechanism* was right almost everywhere (negative
award points, device + volume input, separate ally squad group, 500-point bank
with two kiosks, 500-point marines, 750 turret, 1,000 Warthog, 2,000 upgrade).
Our *numbers* were wrong on the cap (8 not 12), both squad sizes (4 not 6/8),
the win price (10,000 not 8,000), the heavy tier (3,500 not 3,000) and the gate
unit (set, not round). Our *architecture* was wrong in one way that matters:
charging `player0` instead of the player in the volume.

---

## 7. Squad data

`extracted/scnr_squads.json` holds the machine-readable dump: 25 squad groups
with parent links, 48 squads with team and group, each squad's designer and
templated cells with actor counts and resolved character tags, a 39-entry
character palette and a 15-entry vehicle palette.

The dumper is new (`reach_cache.py` has no squad support at all). It walks
`scenario_struct_definition` using the MCC tag definitions in
`research/_raw/reach-defs/scenario.json`, which gave these **MCC** block offsets
in the `scnr` root — note they differ from the Xbox 360 offsets recorded in
`research/07`:

| Block | MCC offset | 360 offset (research/07) | Element size |
|---|---|---|---|
| `scenario_object_names_block` | `0x0F0` | — | 8 |
| `scenario_vehicle_palette_block` | `0x138` | — | 16 |
| `squad_groups_block` | `0x38C` | `0x3A0` | 40 |
| `squads_block` | `0x398` | `0x3AC` | 108 |
| `squad_patrol_block` | `0x3B0` | — | — |
| `character_palette_block` | `0x3EC` | `0x400` | 16 |

Squad element layout (`squads_block_struct`, 108 bytes, validated against the
declared size): inline name `char[32]` at `0x00`, flags at `0x20`, team enum at
`0x24`, parent squad group index at `0x26`, initial zone `0x28`, initial
objective `0x2A`, initial task `0x2C`, editor folder `0x2E`, spawn formations
block `0x30`, **spawn points block `0x3C`**, wave placement filter `0x48`,
template stringID `0x4C`, squad template index `0x50`, designer cells block
`0x54`, templated cells block `0x60`.

Cell layout (`cell_block_struct`, 108 bytes, validated): name stringID `0x00`,
spawn conditions `0x04`, **normal-difficulty actor count `0x10`**, major upgrade
`0x12`, character-type choice block `0x14`, initial weapon `0x20`, secondary
weapon `0x2C`, equipment `0x38`, grenade type `0x44`, vehicle palette index
`0x46`, vehicle variant `0x48`, placement script `0x4C`.

A sanity note on the definition walker: 308 of 317 scenario structs reproduce
their declared size exactly with the field-size table used here, which is why
these offsets can be trusted. The nine that do not are all unrelated
(`orders_block`, `triggers_block`, `ai_scene_block`, cutscene cameras, lighting)
and none is on the squad path.

### The 48 squads

Teams are from `ai_team_enum` = `default, player, human, covenant, brute, mule,
spare, covenant_player`. "actors" is the summed normal-difficulty count.

| # | Squad | Team | Group | Cells | Actors | Characters |
|---|---|---|---|---|---|---|
| 0 | `sq_sur_wave_01` | default | gr_survival_waves | 1 | 0 | grunt_dw4, brute_dw4, elite_dw4, elite_jetpack_flying (+3 empty slots) |
| 1 | `sq_sur_wave_02` | default | gr_survival_waves | 1 | 0 | elite_officer_dw4, elite_stealth_dw4, elite_ultra_dw4, grunt_heavy_dw4, grunt_major_dw4, grunt_specops_dw4, grunt_ultra_dw4 |
| 2 | `sq_sur_wave_03` | default | gr_survival_waves | 1 | 0 | hunter_dw4, jackal_dw4, jackal_major_dw4, jackal_sniper_dw4, skirmisher_dw4, skirmisher_champion_dw4 |
| 3 | `sq_sur_wave_04` | default | gr_survival_waves | 1 | 0 | skirmisher_commando_dw4, skirmisher_murmillone_dw4, elite_story_dw4, brute_chieftain_armor_dw4 |
| 4–7 | `sq_sur_wave_05` … `sq_sur_wave_08` | default | gr_survival_waves | 0 | 0 | — |
| 8–11 | `sur_fireteam_01` … `sur_fireteam_04` | default | gr_survival_fireteams | 0 | 0 | — |
| 12 | `sq_ff_bonus` | default | gr_survival_bonus | 0 | 0 | — |
| 13 | `sq_sur_remaining` | default | gr_survival_remaining | 0 | 0 | — |
| 14–17 | `sq_sur_phantom_01` … `_04` | default | gr_survival_phantoms | 1 (`crew`) | 1 | grunt_dw4 |
| 18 | `sq_sur_bonus_phantom` | default | gr_survival_phantoms | 1 (`crew`) | 1 | grunt_dw4 |
| 19 | `sq_sur_wraith_01` | default | gr_wraith_01 | 1 | 2 | — (vehicle squad) |
| 20 | `sq_sur_wraith_02` | default | gr_wraith_02 | 1 | 2 | — (vehicle squad) |
| 21 | `sq_sur_ghost_01` | default | gr_ghost_01 | 2 (`crew_elites`, designer + templated) | 2 | elite_jetpack_flying; template `sq_camp_revenant` |
| 22 | `sq_sur_ghost_02` | default | gr_ghost_02 | 2 (`crew_elites`) | 2 | elite_jetpack_flying; template `sq_camp_revenant` |
| 23 | `sq_sur_drop_01` | default | gr_survival_cov_drop_pod | 1 (`elite_jetpack`) | 4 | elite_jetpack_flying |
| 24 | `sq_sur_drop_02` | default | gr_survival_cov_drop_pod | 1 (`grunt_heavy`) | 4 | grunt_heavy_dw4 |
| 25 | `sq_sur_drop_03` | default | gr_survival_cov_drop_pod | 1 (`brute`) | 4 | brute_dw4 |
| 26 | `sq_sur_drop_04` | default | gr_survival_cov_drop_pod | 1 (`specops`) | 4 | — |
| 27 | `sq_sur_drop_05` | default | gr_survival_cov_drop_pod | 1 (`brute_stalker`) | 4 | brute_stalker |
| 28–29 | `sur_fireteam_05`, `sur_fireteam_06` | default | gr_survival_fireteams | 0 | 0 | — |
| 30 | `sq_sur_sniper_01` | default | gr_survival_sniper_01 | 1 | 1 | jackal_sniper_dw4 |
| 31 | `sq_sur_sniper_02` | default | gr_survival_sniper_02 | 1 | 1 | jackal_sniper_dw4 |
| **32** | **`sq_sur_ini_odsts`** | default | **gr_survival_marines** | 1 (`odsts`) | **4** | **kf_trooper_odst**; 6 starting locations |
| 33 | `sq_sur_ini_cov0` | default | gr_survival_ini_cov | 2 (`chieftain`, `stalkers`) | 3 | brute_chieftain_weapon_dw4; brute_stalker ×2 |
| 34 | `sq_sur_ini_cov1` | default | gr_survival_ini_cov | 1 (`brute`) | 2 | brute_dw4 |
| 35 | `sq_sur_ini_cov2` | default | gr_survival_ini_cov | 1 (`grunt`) | 4 | grunt_dw4 |
| 36 | `sq_sur_ini_cov3` | default | gr_survival_ini_cov | 1 (`brute_captain`) | 1 | brute_captain_dw4 |
| 37 | `sq_sur_ini_cov4` | default | gr_survival_ini_cov | 2 (`jackal_minor`, `jackal_major`) | 2 | jackal_dw4; jackal_major_dw4 |
| 38 | `scorpion` | **player** | — | 1 (`cell_0`) | 2 | — (major upgrade enum 4) |
| 39 | `sq_sur_ini_cov5` | default | gr_survival_ini_cov | 1 | 2 | — |
| 40 | `sq_sur_ini_cov6` | default | gr_survival_ini_cov | 1 | 1 | — |
| 41 | `warthog` | **player** | — | 1 (`cell_0`) | 1 | — |
| **42** | **`marine_rein`** | **player** | **gr_survival_marines_followers** | 1 (`marines`) | **4** | — ; 4 starting locations `a`, `b`, `c`, `d` |
| **43** | **`marine_pelican`** | **player** | — | 1 | 1 | — ; 1 starting location `pelican` |
| 44 | `sq_sur_buggers` | default | gr_survival_buggers | 1 | 4 | bugger_dw4 |
| 45 | `sq_sur_cruiser_guns` | **mule** | — | 1 | 2 | — |
| 46 | `sq_turret` | **player** | — | 1 | 1 | — |
| 47 | `sq_sur_bob` | default | — | 1 (`bob`) | 1 | elite_bob_dw4 |

Reading notes:

- **The `sur_fireteam_*` squads are empty shells.** All six (`sur_fireteam_01`
  through `_06`) have zero cells and zero actors, and sit under
  `gr_survival_fireteams`, itself a child of `gr_survival_waves`. They are
  populated at runtime by the Firefight wave system via the globals
  `ai_sur_fireteam_squad0` … `ai_sur_fireteam_squad5`, which are exactly six — one
  per fireteam squad. Nothing about them is author-modified.
- **`sq_sur_wave_01` … `_04` carry a character menu, not a roster.** Each has one
  cell with a count of 0 and a character-type choice block listing four to eight
  candidate `dw4` characters (some slots empty, palette index −1). Counts come
  from the 32 `wave` templates at spawn time. `_05` through `_08` are entirely
  empty. This is where the author's reskin of the enemy roster lives: every
  candidate is a `_dw4` character.
- **Allies.** Only `sq_sur_ini_odsts` (4 × `kf_trooper_odst`, pre-placed, free)
  and `marine_rein` (4, purchased) are in the ally tree. Both sit under
  `gr_survival_marines`, which is why the single cap of 8 governs both.
- **Unresolved detail, stated rather than guessed:** `marine_rein`'s cell has an
  *empty* character-type choice block (count 0) and vehicle index −1, so the
  compiled scenario does not name the marines' `char` tag. The same is true of
  the vehicle squads (`scorpion`, `warthog`, `sq_turret`, `marine_pelican`,
  `sq_sur_cruiser_guns`, both wraiths) where it is expected, but also of
  `sq_sur_drop_04` and `sq_sur_ini_cov5/6`, where it is not. The squad's
  `template` stringID is 0 and its squad-template index is −1, so it is not
  coming from an `sqtm` either. Where `marine_rein` gets its biped is an open
  question; it is *not* answered by this teardown, and anyone copying the design
  needs to resolve it before relying on `ai_place` alone.
- `sq_sur_ini_odsts` is never `ai_place`d by any script; it is an initial
  placement, and the scripts only ever re-task it
  (`ai_set_task "sq_sur_ini_odsts" "obj_marines" "gate_marines_defenders"`).

### Palettes

Character palette (39 entries, all but a handful author-made):
`dw4\ai\generic`, `dw4\ai\generic_turret`, and `dw4\objects\characters\…\ai\`
variants of brute, brute_captain, brute_chieftain_armor,
brute_chieftain_weapon, brute_stalker, elite, elite_officer, elite_ultra,
elite_story, elite_specops, elite_stealth, elite_jetpack_flying,
`named\elite_bob_dw4`, grunt, grunt_major, grunt_ultra, grunt_heavy,
grunt_specops, hunter, hunter_aggro, hunter_pyro, jackal, jackal_major,
jackal_sniper, skirmisher, skirmisher_major, skirmisher_champion,
skirmisher_commando, skirmisher_murmillone, skirmisher_rifle,
skirmisher_rifle_major, bugger, bugger_major, bugger_ultra, bugger_captain, and
the null characters `null_cov_default_dw4`, `null_cov_flying_dw4`,
`null_human_default_dw4`, `null_human_flying_dw4`. The only non-`dw4` ally
character in use is `kf_trooper_odst`.

Vehicle palette (15): `phantom_dw4`, `wraith_dw4`, `warthog_dw4`, `ghost_dw4`,
`machinegun_dw4`, `cov_squad_drop_pod`, `tuning_fork_dw4`, `odst_pod`,
`scorpion_dw4`, `apparition`, `banshee_dw4`, `pelican_dw4`,
`mac_15cm_mark_2488`, `anti_infantry_turret`, `mongoose_dw4`.

### `smdt` — survival_mode_globals

The tag is `firefight\firefight_globals`, 112 bytes of root block:

| Offset | Field | Value |
|---|---|---|
| `0x00` | survival mode text | `multiplayer\survival_global_messages` |
| `0x10` | countdown sound | `sound\game_sfx\multiplayer\player_timer_beep` |
| `0x20` | respawn sound | `sound\game_sfx\multiplayer\player_respawn` |
| `0x30` | co-op spawning globals | `globals\ff` |
| `0x40` | wave templates | 32 |
| `0x4C` | state responses | 12 |
| `0x58` | spartan voices | 12 |
| `0x64` | team colors | 11 |

The 32 wave-template entries line up with the 32 `wave` tags in the index. This
tag looks structurally stock; the author's changes are in the `wave` and `char`
tags it points at, and in the scenario.

---

## 8. Tool findings and follow-ups

What worked, unmodified, on real bytes:

- `tools/map/parse_map.py` / `reach_cache.py` parsed the header, interop
  sections, index header, both string tables, all 17,983 tag entries and 235
  groups with zero warnings and zero exceptions, in under a second (it mmaps
  rather than reading 870 MB). Build-string detection, header-variant selection,
  pointer expansion, `meta_to_offset`, `debug_to_offset` and the 17-namespace
  stringID resolver all behaved. 195 synthetic assertions turned out to have been
  testing the right things.
- `tools/hsc/decompile.py` decoded 485 scripts, 277 globals and 52,711
  expressions into 16,195 lines of readable, validated HaloScript once given the
  right base address and opcode table. Its `--probe` mode picked the layout
  variant correctly and unambiguously.

What needs fixing, in priority order:

1. **Script-name stringID resolution in `decompile.py` is wrong** (section 5).
   It must resolve names through the cache's namespace table, not a flat
   index-keyed dict. As shipped it produces plausible but entirely false script
   and parameter names from a real map. Either take a `ReachCacheFile` and call
   `resolve_sid`, or document that `--stringids` must be a pre-resolved
   `{raw_sid: name}` map and make `parse_map.py --extract` emit exactly that.
2. **`parse_map.py` should emit the decompiler's addressing arguments.** The
   `base_va = virtual_base - meta_offset` relation and the `scnr` file offset are
   both known to the parser the moment it reads the header; requiring the operator
   to compute `0x199C27000` by hand is a trap. Emit them into `header.json` and
   accept them as a single `--from-header` flag in `decompile.py`.
3. **`reach_tag_groups.json` has wrong display names for real groups.** Observed
   mislabels: `hlmt` as `prop_breadcrumb_text` (it is `model`), `proj` as `key_t`
   (`projectile`), `eqip` as `prop_purchased_event` (`equipment`), `achi` as
   `prop_campaign_leader`, `cpgd` as `cookie_purchase_globals`, `chmt` as
   `chocolate_mountain_new`. These are cosmetic but actively misleading — the
   fake name `prop_purchased_event` on `eqip` generated 25 false hits when
   grepping the tag listing for purchase vocabulary, which is exactly the kind of
   false positive that could have produced a wrong stock/modified verdict.
4. **No squad parsing anywhere in the toolchain.** The dumper written for this
   teardown should be folded into `reach_cache.py` as a proper
   definition-driven tag walker. The definition-size table that validates 308 of
   317 scenario structs is the piece worth keeping; with it, any block in any of
   the dumped MCC definitions can be walked generically rather than by
   hand-coded offsets.
5. **Confirm the MCC vs 360 offset divergence in `research/07`.** That document
   records the Xbox 360 offsets for `Squad Groups` (`0x3A0`), `Squads` (`0x3AC`)
   and `Character Palette` (`0x400`). The MCC values are `0x38C`, `0x398` and
   `0x3EC`. Section 7 above has the corrected table; `research/07` should be
   amended so nobody uses the 360 numbers on an MCC cache.

Open questions this teardown did not settle:

- Where `marine_rein` (and `sq_sur_drop_04`, `sq_sur_ini_cov5/6`) get their
  character, given an empty character-type choice block, a zero template
  stringID and a −1 squad-template index.
- Whether the literal 7 in `survival_wave_end_conditions` is the author's change
  or stock for Unearthed, given that `k_sur_ai_end_limit` exists and is 0.
- The two null tag entries: which tags they are and which shared cache resolves
  them.
- Whether the stored checksum `0xB35A145C` is consistent with the file's
  contents. The parser reports the field but does not verify it; for a
  re-compiled map this is worth knowing before any write experiment.
