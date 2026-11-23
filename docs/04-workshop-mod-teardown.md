# 04 — Workshop mod teardown: "Halo Reach: Evolved Public Beta" (id 3453792163)

Research date: 2026-11-20. Author of this document: research agent. Everything below is
labelled either **FACT** (read directly out of the Steam API, the Workshop page HTML, the
comment thread, the changelog, or the bytes of the user's two `.bin` files) or
**INFERENCE** (reasoned, not verified). Please keep that distinction when planning the
build — the single most expensive mistake available here is to assume the purchase logic
is scriptable from a gametype file.

---

## 0. Access log — what I could and could not read

| Source | Status |
|---|---|
| `ISteamRemoteStorage/GetPublishedFileDetails` for 3453792163 | Read in full. Not rate-limited. This gave the complete description verbatim. |
| Workshop item page HTML | Read on the third attempt. Steam returns HTTP 429 aggressively; 45–60 s between requests is the practical floor. |
| Change Notes page 1 | Read in full (10 updates, 2026-01-05 through 2026-03-15). |
| Change Notes pages 2+ | **Not read** — HTTP 429 on every retry. The item has been updated since 2025-03-28, so roughly a year of earlier change notes is unread. |
| Comment thread | Read in full: all 263 comments, via `steamcommunity.com/comment/PublishedFile_Public/render/...`. That endpoint is not rate-limited. |
| The three linked discussion threads | **Not read** — HTTP 429 on every retry. Only the discussions index loaded, and it carried no topic titles in the static HTML. |
| The author's other Workshop uploads | **Could not enumerate.** The profile's Workshop tab returns an empty shell to a logged-out client. A text search of the MCC Workshop for "Reach Evolved" returned 30 items, exactly one of which belongs to this author. See section 5. |
| The 7.33 GB Workshop payload itself | **Not downloaded.** It is Windows-only content and this machine is macOS. No `.map` file was opened. Every claim about map internals in this document is therefore inference from format constraints, not from inspection. |
| The two `.bin` game variants | Read at the bit level. They are present locally at `reference/Firefight Evolved.bin` and `reference/Firefight Corvette Evolved.bin`, and a sibling agent has already decoded them completely — see `research/02-mpvr-megalo-format.md`. That decode is the decisive evidence in section 4. |

---

## 1. A correction to the project's premise, up front

The user's brief describes item 3453792163 as "the Firefight Evolved mod". It is not.

**FACT.** Item 3453792163 is titled **"Halo Reach: Evolved Public Beta"**. It is a
7.334 GB full-game overhaul covering both campaign and Firefight. "Firefight Evolved" is
the name of the two companion game-variant `.bin` files, which are **not on the Steam
Workshop at all** — the author distributes them through a OneDrive link and through his
in-game file share.

This matters because it already answers the architectural question by itself: the thing on
the Workshop is the 7.33 GB map package, and the thing the user has locally is the 2 KB
settings pair. They are two different artifacts with two different distribution channels.

---

## 2. Hard metadata (all FACT)

| Field | Value |
|---|---|
| Published file id | 3453792163 |
| Title | Halo Reach: Evolved Public Beta |
| Author | The Vengeful 'Vadam — `https://steamcommunity.com/profiles/76561198063340220/` |
| Consumer app | 976730 (Halo: The Master Chief Collection) |
| **Creator app** | **1695795 — "Halo MCC Mod Uploader"** (the official Excession upload tool) |
| File size | 7,333,964,512 bytes (7.334 GB) |
| Posted | 2025-03-28 13:20 |
| Last updated | 2026-03-15 06:28 (Unix 1773581311) |
| Tags | `HaloReach`, `Campaign`, `Firefight` |
| Sidebar fields rendered by Steam | **`Engine: HaloReach` / `Game Content: Campaign, Firefight`** |
| Required items | **None.** The item page contains no `requiredItems` block at all. |
| Collections | None. |
| Lifetime subscriptions | 19,675 (11,399 current), 2,931 favourites, 65,172 views |
| Linked discussions | 3 threads (ids `567049339876355711`, `596270699756137490`, `682990478470386465`) |
| Item URL | `https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163` |

Three of those rows are load-bearing:

1. **`creator_app_id = 1695795` is the Halo MCC Mod Uploader.** That tool exists only to
   publish MCC mod *packages* — a `ModInfo.json` plus `maps/*.map` plus artwork. It is not
   a gametype uploader. Game variants have no place in its schema.
2. **`Engine: HaloReach` / `Game Content: Campaign, Firefight`** are Steam's rendering of
   `ModInfo.json`'s `Engine` and `GameModContents { HasCampaign, FirefightMaps[] }`
   fields. Steam is telling us directly that this package declares campaign content and
   Firefight map content.
3. **7.334 GB.** A gametype `.bin` is ~21 KB. Nothing but cache maps reaches gigabytes.

---

## 3. The author's own description, by section

The description is reproduced here only where it is load-bearing; the full text is in
`research/_raw/api1.json` under `description`.

### 3.1 Project framing (FACT, author's words)

> "Halo: Reach Evolved is a project that's been ongoing since 2018 when it was an Xbox 360
> mod. It brings in certain aspects from the original trilogy of Halo games, edits some of
> the Campaign encounters with brand new scripted sequences, and alters the weapons and
> vehicles to give each tool of destruction their own distinct niche, while introducing new
> ones."

> "The Firefight component has been transformed, featuring an ingame currency system using
> your Firefight score, which you can use to purchase weapon crates, base upgrades, armor
> abilities, and even win conditions!"

> "This is the public beta, featuring the first four missions of the Campaign, followed by
> the Firefight maps Installation 04, Unearthed, and Corvette. When the mod is out of beta,
> the rest of the Campaign will be available, and new Firefight maps will be released when
> they're ready."

Note the phrase **"brand new scripted sequences"** and **"edits some of the Campaign
encounters"**. Both describe scenario-level work: HaloScript (`.hsc`) and AI encounter
placement inside map tags. Neither is expressible in a game variant of any engine type.

### 3.2 The install instruction (FACT, author's words, verbatim)

> "YOU'RE GOING TO WANT MY FIREFIGHT EVOLVED GAMETYPES, which can be found either through
> my Vengeful Vadam gamertag's file share, or you can directly download it here:
> `https://1drv.ms/u/c/5c9ee221eeba4d00/IQA7hXws1q85Ta8dYxDsW4hpAfcblAd6RUemxxc74IxQve8?e=lXBdIJ`
> Place the bin files in `steamapps\common\Halo The Master Chief Collection\haloreach\game_variants`"

He repeats the same instruction verbatim as a pinned comment. This is the only installation
guidance the author provides anywhere on the page.

### 3.3 Sandbox overview (FACT)

The description lists 30+ weapon changes, including nine weapons marked "(New)": SMG,
Battle Rifle, Plasma Spate, Brute Plasma Spate, Mauler, Plasma Caster, Gravity Rifle,
Sentinel Beam, and a Brute variant. New weapons mean **new tags** — weapon tags, projectile
tags, first-person model and animation tags, HUD tags, damage-response tags. The author even
lists "Certain HUD elements for the new weapons are placeholder" as a known issue, which is
a tag-authoring complaint, not a scripting one.

The Sentinel Beam entry is the most informative single line in the whole description:

> "(New) Sentinel Beam: Exclusive to Installation 04's Sentinels…"

A weapon scoped to one specific Firefight map's AI characters can only be a per-map tag/
squad arrangement.

### 3.4 Credits (FACT)

Model, texture and shader credits to five contributors (Ludus Regard, Maik, Sean T,
savinpvtmike, VKMT), plus "King Feraligatr: AI improvements" and "Byzantine Is Roman:
Jetpack Elites" and "deadkiva7: Destructible Skirmisher masks". Every one of those is an
asset or tag contribution. There is not one scripting credit, and not one gametype credit.

---

## 4. The decisive architectural answer

### 4.1 Does the mod ship modified `.map` files?

**Yes. FACT, on four independent grounds:**

1. 7.334 GB payload size.
2. Uploaded with app 1695795, the Halo MCC Mod Uploader, whose only output is a mod
   package containing `maps/*.map`.
3. Steam renders `Engine: HaloReach` and `Game Content: Campaign, Firefight` from the
   package's `ModInfo.json`.
4. The description claims edited campaign encounters, new scripted sequences, new weapons
   with new models and new HUD elements, and new AI variants (Hunter Aggro, Hunter Pyro,
   Stealth Elite Major, Jetpack Elites). None of that is representable in any Halo Reach
   game variant.

Supporting comment-thread evidence (FACT): the author tells a user whose modded missions
showed "missing content" to "make sure they have both SP and MP installed" — that is MCC's
singleplayer and multiplayer *content packages*, which only matters if the mod is replacing
cache maps in both. He tells another user to "unsubscribe and resubscribe from the mod",
which is Workshop-package troubleshooting.

### 4.2 Do the variant `.bin` files contain the purchase logic?

**No. FACT, proven from the bytes** by the sibling decode in
`research/02-mpvr-megalo-format.md`. Summary of that proof:

- The `mpvr` chunk declares its own payload length: 963 bytes (Firefight Evolved) and
  1049 bytes (Firefight Corvette Evolved), inside a 20,520-byte fixed-size chunk.
- `variant_type = 4` = **firefight** engine.
- A field-by-field port of Reach's firefight variant body consumes *exactly* those byte
  counts — 7699 and 8387 bits plus 5 bits of alignment padding each. Nothing left over,
  nothing missing.
- The stored SHA-1 verifies for both files, proving the declared length is the real length
  and no region was skipped.
- The remaining ~19.5 KB of each chunk is **all zero bytes**. Not compressed script, not
  obfuscated data. Padding.

And structurally, Reach's firefight variant body **has no script section at all**. The
string table, trigger table, condition table, action table, variable declarations and HUD
widget declarations exist only on `GameVariantDataMultiplayer` (engine types 1 = forge,
2 = multiplayer). Megalo and Firefight are different engine types. You cannot put a Megalo
script into a Firefight variant; there is nowhere to put it.

What the two files *do* contain (FACT):

- `scenarioFlags = hazards_enabled | weapon_drops_enabled | ammo_crates_enabled`;
  generator flags clear, `generatorCount = 0`.
- `waveLimit = 0` → **no wave limit**. The match does not end on a wave count.
- `bonusTarget = 10000`, `eliteKillBonus = 1`, `startingLivesSpartan = 7`,
  `maxSpartanExtraLives = 20`, `bonusWaveDuration = 90 s`.
- Eight player/AI trait blocks, three custom skulls, escalating per-round skulls.
- Three rounds × three wave slots (initial / main / boss) + one bonus wave = ten wave
  definitions. Each holds up to twelve 8-bit **squad type** enums.
- The squad roster is entirely Covenant: `jackal_patrol`, `elite_patrol`,
  `skirmisher_patrol`, `elite_infantry`, `brute_patrol`, `hunter_infantry`,
  `elite_strike_team`, `brute_kill_team`, `brute_infantry`, `hunter_kill_team`,
  `skirmisher_infantry`, `hunter_strike_team`, grunts in the bonus wave.
  **There is no marine or ODST squad value in the enum, and no spawn-point reference of any
  kind.** Squad identities are indices into the *map's* Survival Mode Globals (`smdt`) tag.
- `mccExtensionVersion = 2`, `mccExtensionFlags = 0`.

And the diff between the two files is one boolean, repeated (FACT): of 996 decoded fields,
983 are identical; the differences are the title, description, author timestamp, and
`usesDropship` cleared on all ten wave definitions in the Corvette variant (Corvette is a
ship interior, so Phantoms cannot drop in).

### 4.3 So where does the logic live?

**INFERENCE, but tightly constrained — this is reasoning from what each format can and
cannot express, and I consider it close to certain:**

| Mechanic | Layer | Why |
|---|---|---|
| Marine / ODST ally squads | **Map** — scenario AI squads + HaloScript `ai_place` | The variant enum has no friendly squad values. Megalo has no AI-spawn verb at all (zero matches for AI/squad spawning across its 107 actions and 18 conditions). |
| Purchase menu and currency | **Map** — HaloScript | The firefight body has no HUD widget declarations, no strings, no arithmetic. |
| Pelican extraction, MAC Cannon, glassing beam, Covenant cruiser | **Map** — HaloScript, with cinematics and scripted objects | The variant has no round-ending condition beyond generic engine limits, and `waveLimit = 0` deliberately leaves termination to something external. |
| Sentinel hacking (team swap) | **Map** — HaloScript `ai_set_team` / `ai_allegiance` | Not expressible anywhere else. |
| Auto turret, purchasable Warthog / Scorpion / Falcon | **Map** — HaloScript object creation at scenario-defined points | Megalo *can* create objects, but Megalo is not present here. |
| New weapons, new AI variants, encounter edits, cinematics | **Map** — tags | Not expressible in any variant. |
| Wave composition, skulls, traits, lives, score targets, dropship on/off | **Variant `.bin`** | This is exactly and only what the 963/1049 bytes encode. |

The single strongest in-file hint that the logic is external is `waveLimit = 0` combined
with no round limit: the variant is configured to run forever, so that the map decides when
and how the match ends.

**Consequence for the project, stated plainly: authoring new Firefight Evolved-style
content requires the Halo Reach tag and map editing toolchain (HREK — Tool, Foundation,
Sapien, plus HaloScript compilation in Sapien). It cannot be done with gametype editing
alone.** The `.bin` is the easy 2 % of the work.

### 4.4 One qualifier worth knowing (CITED, not used by this mod)

Since MCC's July 2023 update, *multiplayer* Megalo has action **100 `Call HaloScript
Function`**, described in ReachVariantEditor's source as "[MCC-only; backported from Halo
4.] Calls a HaloScript function that the map has made available for use by Megalo. This
appears to be intended mainly for \*.MAP mod authors who are creating map-and-Megalo combo
mods." It takes a `VariantStringID` naming the function, resolved through the map's
`megalo_string_id_table` (`msit`) tag.

So a *multiplayer* variant on a custom map could drive a buy menu that calls into HSC. That
is a real alternative design path. **It is not what this mod does** — these are Firefight
variants, engine type 4, and Firefight has no Megalo at all.

---

## 5. The dependency chain

```
Halo: The Master Chief Collection  (Steam app 976730)
  + Halo: Reach  — BOTH the singleplayer and multiplayer content packages installed
  + launched via "Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)"
        │
        ├── Steam Workshop item 3453792163 — "Halo Reach: Evolved Public Beta"
        │      7.334 GB, uploaded with the Halo MCC Mod Uploader (app 1695795)
        │      Engine: HaloReach · Game Content: Campaign, Firefight
        │      Ships: ModInfo.json, maps/*.map (modified campaign + ff_* caches),
        │             firefight/*.json map entries, images/*.png
        │      Required items: NONE
        │      → provides ALL behaviour: tags, AI squads, HaloScript, purchase logic,
        │        cinematics, new weapons
        │
        └── "Firefight Evolved" gametype pack — NOT on the Workshop
               Distributed via OneDrive and the author's in-game file share
               ("Vengeful Vadam" gamertag)
               Two files, ~21 KB each:
                 · Firefight Evolved.bin          (title "FIREFIGHT EVOLVED")
                 · Firefight Corvette Evolved.bin (title " FIREFIGHT CORVETTE EVOLVED")
               → provides ONLY settings: waves, squad roster, skulls, traits, lives,
                 score targets, dropship flag
```

Ancestry, not runtime dependency (FACT, author-stated): the project began in 2018 as an
Xbox 360 mod. Commenters refer to "the original Reach Evolved" / "the old Reach Evolved"
and one asks "Why not just have 1.0 and 2.0 releases up on the workshop?" — the author did
not reply to that in the comment thread. The 360-era mod is not on the Workshop and is not
needed.

**Enumeration gap (honest).** I could not list the author's other Workshop uploads: the
profile's Workshop tab is empty to a logged-out client, and the Steam Workshop text search
for "Reach Evolved" across MCC returned 30 items with exactly one belonging to
`76561198063340220`. **INFERENCE:** this is probably his only MCC Workshop item, and the
"Halo: Reach Evolved" that the user's `.bin` descriptions reference is this same item, not a
separate larger mod. The brief's hypothesis that the two files depend on a *separate* bigger
Workshop mod resolves to: they depend on *this* one.

For the record, other "Evolved"-named items found in that search belong to **different
authors** and are unrelated: `2945040447` The Silent Cartographer: Evolved,
`2955571959` Halo Reach: Sandbox Evolved, `3014096841` Halo: Brutality Evolved,
`2898964217` Halo Infinite Evolved, `3594880812` Sprint Evolved.

---

## 6. Per-map scenario teardown

For each map: the author's stated design, then the implementation inference, labelled.

The three maps are all **stock Halo Reach Firefight maps**, which is good news — no new BSP
authoring is implied.

| Map | Stock cache name | Origin |
|---|---|---|
| Installation 04 | `cex_ff_halo` | Anniversary Map Pack |
| Unearthed | `ff_unearthed` | Defiant Map Pack |
| Corvette | `ff45_corvette` | Base game |

### 6.1 INSTALLATION 04

**Author's text (FACT, verbatim):**

> "The Covenant are interested in the Forerunner technology surrounding the beam tower.
> With a squad of marines, secure the tower, hold off Covenant reinforcements, as well as
> Sentinels, until you're able to call for a pelican extraction to win the game. During
> that time, you can use your Firefight score to purchase ODST reinforcements, an auto
> turret, a Falcon gunner ride akin to Call of Duty's 'chopper gunner', and even hack the
> nearby Sentinels to be on your side for a round."

Mechanic list extracted:

1. Ally squad present from the start (marines).
2. "Secure the tower" — an initial objective gating the rest.
3. Covenant reinforcement waves.
4. Sentinels as a third faction / additional enemy type.
5. Win condition: call a Pelican extraction.
6. Purchase: ODST reinforcements.
7. Purchase: auto turret.
8. Purchase: Falcon gunner ride, on a flight path, player in the gunner seat.
9. Purchase: hack nearby Sentinels to fight for you **for one round** (a timed allegiance
   flip).

**Why this map was chosen (FACT, from Halopedia):** vanilla `cex_ff_halo` is
"the first and — to date — only Firefight map to contain friendly AI alongside enemy
counterparts." Vanilla already has a squad of four ODSTs at the top of the beam tower, and
already has a D77 Pelican that flies in to deliver a Warthog weapon drop plus "an ODST
reinforcement [that] is correctly scripted to follow players." Vanilla also notes the four
tower ODSTs "have no pathfinding directions, which causes them to remain stationary".

**INFERENCE — implementation.** Vadam is extending machinery that already exists in this
one scenario rather than inventing it: the friendly-ODST character types, the Pelican
flyby/delivery script, and the follow-the-player ODST behaviour are all stock hooks in
`cex_ff_halo`. The Sentinels are new AI (the Sentinel Beam weapon is described as
"exclusive to Installation 04's Sentinels"), so they are added squads/characters with new
tags. "Hack for a round" is almost certainly an `ai_allegiance` / `ai_set_team` flip on the
Sentinel squad with a script timer, torn down at round end. The Falcon gunner ride is a
scripted vehicle on a spline path with the player seated — the changelog confirms this read
(see 7.2). The Pelican extraction win is a script-driven match end, which is exactly why the
variant carries `waveLimit = 0`.

### 6.2 UNEARTHED

**Author's text (FACT, verbatim):**

> "The Brutes are attempting to take over the BXR mining facility. Drop in with a squad of
> ODSTs to secure the base, but this will trigger a Covenant cruiser to slipspace into the
> AO. It will deploy phantoms to send Covenant reinforcements, and occasionally use its
> ship cannons to rain fire upon you. Your win condition is to hold out until you can
> purchase the MAC Cannon to destroy the ship. However, if you can't purchase the cannon on
> time, the glassing beam will activate and everyone dies, resulting in a loss. You can
> also purchase Marine reinforcements, another auto turret, a rocket Warthog which can be
> upgraded to a Gauss Warthog, and a Scorpion."

Mechanic list extracted:

1. Opening ODST drop-in — and a commenter confirms "It has cinematic at the beginning of the
   Unearthed map", with another complaining about "the unskippable cutscene at the beginning
   of single player FF".
2. "Secure the base" as a stage-one objective whose completion **triggers** stage two.
3. A Covenant cruiser arrives via slipspace — a scripted large-scale object/scenery event.
4. The cruiser deploys Phantoms carrying reinforcements.
5. Periodic ship-cannon barrage as an environmental hazard.
6. Win: purchase the MAC Cannon, which destroys the ship.
7. Lose: a glassing-beam timer expires first — a hard fail state killing all players.
8. Purchase: Marine reinforcements, auto turret, rocket Warthog upgradeable to Gauss,
   Scorpion.

**INFERENCE — implementation.** A cinematic at round start is decisive on its own: no
variant format of any engine type can play a cutscene. This is scenario cinematic scripting.
The cruiser is scenery or a scripted vehicle placed and animated by HSC; the ship-cannon
barrage is an effect-plus-damage script on a timer; the glassing beam is a second,
longer script timer whose expiry calls a loss. The "upgrade rocket Warthog to Gauss" is
almost certainly a second purchase that deletes the first vehicle and spawns the upgraded
one at the same point, because Reach has no runtime turret-swap. The "hold out until you can
purchase the MAC Cannon" phrasing plus the changelog line "MAC Cannon on Unearthed becomes
available at the start of Set 2" means purchase availability is **gated on Firefight set
progression**, i.e. the script is reading the engine's survival state — see
`survival_mode_*` in Reach's HSC function set.

### 6.3 CORVETTE

Not in the user's brief, but it is the third shipped map and the user owns its variant, so
it belongs here.

**Author's text (FACT, verbatim):**

> "You're tasked to board the Ardent Prayer to steal valuable intel that'll aid the war
> effort against the Covenant. Infiltrate with a squad of troopers, secure the hangar, and
> make preparations to storm the bridge! There's weapon crates to buy, a Shade turret to
> unlock and upgrade, a CoD-style Mystery Box that randomly spawns in specific locations,
> gametype objectives in between rounds to secure more points for you and your team, and
> even new bonus rounds! Corvette Cannonade has you control the Corvette's ship guns to
> destroy space banshees and seraph's. Sabre Strike puts you in the cockpit of a Sabre to
> destroy banshees!"

Mechanics: trooper ally squad; a staged hangar → bridge progression with **room unlocks**;
purchasable weapon crates; a Shade turret with an unlock-then-upgrade tier; a Mystery Box
that relocates between a fixed set of positions; **inter-round objectives borrowing
multiplayer gametypes (KOTH / Race / CTF)**; and two custom bonus rounds that place the
player in ship guns or in a Sabre cockpit.

**INFERENCE.** The inter-round KOTH / Race / CTF objectives are the most surprising item.
The changelog confirms they are real ("Co-op players should see the objective markers for
KOTH, Race, and CTF"; "Hill on corvette should no longer teleport to the gun room if you
don't have that room unlocked yet"). Since there is no Megalo here, these are hand-rolled in
HSC: a hill volume, a score accumulator, and an objective marker, re-implemented rather than
inherited from the multiplayer engine. The "hill teleporting to a locked room" bug is exactly
the signature of a script choosing a destination from a position list without checking an
unlock flag. The room unlock state, the Shade upgrade tier and the Mystery Box position are
all script globals.

---

## 7. What the change notes prove about the layer split

Ten updates are readable (2026-01-05 → 2026-03-15). Full text in
`research/_raw/changelog.html`. The useful thing about the changelog is that almost every
line names a change that is only possible on the map side.

### 7.1 Lines that can only be tag edits (FACT, author-stated changes)

"Battle Rifle damage increased from 7 to 8 per bullet"; "Battle Rifle projectile velocity
increased from 225 to 300 world units per second"; "Battle Rifle spread decreased from
0.3 – 0.6 to 0.1 – 0.1"; "Needle Rifle wait time between shots increased from 0.4 to 0.45
seconds"; "Nerfed Brute Plasma Spate: increased battery per shot to 1% from 0.5%";
"EMP shots vs player health nerfed from 25% effectiveness to 5%"; "Mauler and Gravity
Hammer use buffed brute melee weapon damage tag"; "Stealth Elite colors are changed from
light blue to dark gray"; "Stealth Elite major rank added".

World-units-per-second projectile velocities and a named "melee weapon damage tag" are tag
field values. None of this is reachable from a variant.

### 7.2 Lines that can only be per-map scenario script (FACT, author-stated)

- "Falcon on Installation 04 is now immune to EMP"
- "If you die while in the Falcon's gunner seat, the falcon will immediately fly away from the map"
- "Adjusted the Falcon's flight path to prevent getting hit by the spirit dropships"
- "Hacked Sentinels on I04 have tripled health and shields, deal more damage, and have more range"
- "Sentinels now patrol to different points on I04, and shouldn't try to touch the ground anymore"
- "If you lose your marine squad on Unearthed, you can buy another during the same round you lost them in"
- "MAC Cannon on Unearthed becomes available at the start of Set 2 instead of at the end of the set"
- "Map hazards on Unearthed (ship gun barrage, drones, etc) don't occur at the exact same time anymore"
- "Hill on corvette should no longer teleport to the gun room if you don't have that room unlocked yet"
- "Removed the covenant explosive batteries next to the door leading to the aftship on Corvette"
- "The shield door above the aftship … is permanently one-way, so co-op players that spawn late are no longer trapped"
- "Fixed optional firefight objectives not retriggering again after losing specific objectives"
- "Objectives should properly reset after a set completes, so they can activate again"
- "Buyable Sabre Round conversion added on Corvette, costs 2,500 points"
- "Price for AA shade increased from 3,000 to 6,000"; "Fuel Rod Shade … price on Corvette increased from 1,500 to 2,000"
- "Added new MA5B AR by savinpvtmike to the FF mystery box"; "Halo 1 Pistol added to mystery box"; "Fixed timing of the Mystery Box previews"
- "The Friendly Engineer should no longer cause crashes in Firefight Corvette co-op"
- "Two new Hunter variants added to Firefight: The Aggro … The Pyro"
- "Solo players and the host have fixed exits for the Corvette's ship guns. Co-op players might still experience issues."

**Prices are hard-coded in the map, not configurable from the gametype.** "costs 2,500
points", "increased from 3,000 to 6,000" — the author ships these by updating the 7.33 GB
Workshop package, never by reissuing the `.bin`. That is the clearest possible confirmation
of the split: in the entire readable changelog, **not one line is a gametype change.**

### 7.3 Lines that confirm AI tuning lives in tags, not the variant

"Increased AI enemy burst separation time for plasma spate, plasma caster, fuel rod gun, and
plasma turret"; "Increased AI engagement ranges for assault rifle, magnum, and smg users";
"Grunt Majors, Ultras, Heavies, and Spec-Ops fire the Plasma Pistol and Needler faster, at
slightly further range, and more accurately than Grunt Minors". These are per-weapon AI
firing-pattern fields, i.e. tag data. The variant's `baseTraitsWave` AI trait block is
26 bits total — it cannot express any of this.

### 7.4 Known co-op fragility (FACT, author-stated)

The author lists "This build is largely untested for co-op… There will likely be issues
with syncing", "Certain effects won't play in FF co-op", "Generator Defense and Firefight VS
are currently not supported". The changelog shows repeated co-op desync fixes around
scripted seats, the Grenade Launcher, and the Corvette ship guns. **INFERENCE:** HSC-driven
object creation and seat forcing in Firefight is host-authoritative and syncs poorly. Any new
content we build should assume solo-first and treat co-op as a separate hardening pass.

---

## 8. What the comment thread adds

263 comments read. Parsed text in `research/_raw/comments_all.txt`.

### 8.1 Installation (FACT, user- and author-stated)

- The author's pinned instruction repeats the description verbatim: place the `.bin` files
  in `steamapps\common\Halo The Master Chief Collection\haloreach\game_variants`.
- A user: "i dont have a game_variants file so i added one does that work?" — the folder may
  not exist on a clean install and creating it is the expected fix. (No author reply; treat
  "creating it works" as unconfirmed.)
- A user named Sanholic, answering another: "you gotta launch the game with the second
  option, the one that says **'Play Halo: MCC Anti-Cheat Disabled (Mods and Limited
  Services)'**". This is community guidance, not the author's, but it matches Halo Support's
  official position that "mods will not work unless Easy Anti-Cheat is disabled."
- The author to a user getting "missing content" in co-op: "make sure they have both SP and
  MP installed."
- The author to a user with a broken install: "unsubscribe and resubscribe from the mod."
- The OneDrive link has broken at least twice; six separate commenters reported "Download
  link is down" / "something went wrong", and the author replied "Game mode should be back
  up" and later "Download link for the gametype should be working again." **Plan for this
  link to be unavailable.** The in-game file share under the gamertag "Vengeful Vadam" is
  the author's stated fallback.
- One user with the `.bin` in place saw no change at all ("None of the new weapons, allies,
  buying system, nothing… Playing with Evolved Firefight of course"). **INFERENCE:** that is
  the signature of having the gametype but not an active Workshop mod — which again confirms
  that all behaviour comes from the map package and none from the `.bin`.
- One user: "Turns out I didn't even need the link to get the game mode to work." **INFERENCE:**
  the Workshop package may also register its own Firefight entries, or he had the variant
  already. Unverified.

### 8.2 Design feedback worth absorbing before we build (FACT, commenters)

The single most repeated complaint is that **friendly AI allies are weak and badly behaved**,
and it comes from many independent commenters:

- "Marines are basically just a waste of points, as their firing patterns are too sporadic
  and inaccurate compared to enemies… ODSTs can't hit anything with the new fuel rod cannon,
  they take 7-10 seconds after every sniper rifle shot… they don't change targets with the
  Spartan Laser and tend to shoot recently-killed bodies, and after five minutes of driving
  an ODST with a grenade launcher in the passenger seat of a warthog, he literally did not
  fire it once."
- "whenever a plasma grenade is thrown, they don't bother to dodge or evade from the blast"
- "They should spot enemies from farther away and start shooting at greater distances… they
  should take cover and evade"
- "They're only good as cannon fodder and as passengers for whatever vehicle you're using."
- "Is it me or Kat appears to fire only at close range while on the Hog turret?"

Other recurring points: Unearthed is overtuned relative to Installation 04 ("4-5 zealots and
a ranger squad backed up by minors/majors" in early rounds); Unearthed's spawn points are all
clustered around the compound, so a bad round snowballs; the Scorpion is not worth its price
against Covenant explosives; the opening Firefight cinematic is unskippable and becomes
annoying on repeat; fuel-rod Grunts travel in packs and one-shot the player.

One commenter asked the question most relevant to us: "if we use your firefight gametype, can
we make changes to it (like player health and damage, skulls, ai properties like shootyness,
etc.) without breaking it?" **The author did not answer in the comment thread.** Based on the
decode, the answer is: yes for traits, skulls, lives and wave composition, because those live
in the `.bin` and the map does not depend on their values; and no for anything behavioural,
because that is not in the `.bin` to change.

---

## 9. Prior art and reusable technique

Compiled by a research subagent from Steam, Nexus, GitHub, c20.reclaimers.net and Microsoft
Learn. Treat subscriber counts and file sizes as read on 2026-11-20.

### 9.1 Toolchain (the part the project actually needs)

| Tool | Link | What it is |
|---|---|---|
| Halo: Reach Mod Tools — MCC (HREK) | https://c20.reclaimers.net/hr/hr-ek/ | Official kit. Steam app **1695793**. Contains Tool, Foundation, Sapien, Standalone, MegaloEdit. Requires MCC (976730) and the Reach DLC (1064220). |
| Tool | https://c20.reclaimers.net/hr/hr-ek/hr-tool/ | Command-line import and `build-cache-file`. Also `megalo-convert-variant-files` (MegaloEdit `.mglo` → MCC `.bin`). |
| Foundation | https://c20.reclaimers.net/hr/hr-ek/hr-foundation/ | The tag editor. Reach has no Guerilla; Foundation replaces it. This is where weapon/AI/character tag edits happen. |
| Sapien | https://c20.reclaimers.net/hr/hr-ek/hr-sapien/ | Scenario and BSP editor. Places AI encounters and squads, **compiles HaloScript**, and has a live HS console. This is the single most important tool for us. |
| Halo MCC Mod Uploader (Excession) | Steam app **1695795** | Publishes the mod package. This is the app that uploaded 3453792163. |
| Reach HSC function reference | https://c20.reclaimers.net/hr/engine/scripting | ~1992 functions. Relevant families: `ai_place`, `ai_place_in_vehicle`, `ai_set_team`, `ai_allegiance`, `survival_mode_*`, `player_action_test_*`, `campaign_metagame_get_player_score`, `campaign_metagame_award_points`. |
| HaloScript syntax | https://c20.reclaimers.net/general/scripting | Plus the VS Code extension `Crisp.atlas`. |
| ManagedBlam | https://c20.reclaimers.net/general/mod-tools/managed-blam · https://c20.reclaimers.net/hr/API/ | .NET 4.8 tag API for scripted bulk tag edits. Sample plugin: https://github.com/num0005/SampleFoundationPlugin |
| Osoyoos launcher | https://github.com/num0005/Osoyoos-Launcher | Launcher/wrapper for the editing kits. |
| Foundry | https://github.com/ILoveAGoodCrisp/Foundry | Blender→Reach pipeline; also builds mod folders and launches MCC with `steam://launch/976730/option2`. |
| Assembly | https://github.com/XboxChaos/Assembly | Edits values directly in built Reach MCC cache files. Useful for quick experiments without a full rebuild. |
| Reclaimer | https://github.com/Gravemind2401/Reclaimer | View and extract only. |

### 9.2 Variant-format prior art

| Item | Link | Why it matters |
|---|---|---|
| ReachVariantEditor (DavidJCobb) | https://github.com/DavidJCobb/ReachVariantEditor | GPLv3. The authoritative `.bin` reference. `game_variants/types/firefight.{h,cpp}` is the firefight body; `types/multiplayer.cpp` + `components/megalo/*` is the Megalo body. **Note the repo is `ReachVariantEditor`, not `ReachVariantTool`.** |
| ReachVariantTool on Nexus | https://www.nexusmods.com/halothemasterchiefcollection/mods/192 | The shipped binary. Edits multiplayer, Forge and Firefight variants, and exposes options the in-game editor hides. |
| RVT Firefight concepts | https://davidjcobb.github.io/ReachVariantEditor/concepts/firefight.html | Explains wave / round / set / turn behaviour, and states that normal Firefight progression cannot be disabled "through game variant content alone" because that logic is in map scripts. |
| RVT Firefight editor docs | https://davidjcobb.github.io/ReachVariantEditor/editor/main_window_ff/index.html | Field-by-field walkthrough of what a Firefight variant can express. |
| Blam-Network/blf | https://github.com/Blam-Network/blf | Independent TS/Rust parser. `game_engine_survival.ts` field list matches RVT's, with no script block — this is the second-source confirmation that Firefight has no Megalo. |
| `hs_function_call` docs | https://davidjcobb.github.io/ReachVariantEditor/script/api/ns_game/actions/hs_function_call.html | The Megalo→HSC bridge, for the alternative multiplayer-variant design path. |
| MegaloEvolved | https://github.com/craftycodie/MegaloEvolved | Community Megalo IDE/compiler producing MegaloEdit-compatible output. |
| MegaloDocs | https://github.com/Sopitive/MegaloDocs | MegaloEdit and RVT documentation. |
| DavidJCobb/halo-reach-content | https://github.com/DavidJCobb/halo-reach-content | Real Megalo scripts (chess, minesweeper) as worked examples. |

### 9.3 The closest functional prior art

| Workshop id | Name | Subs | What it demonstrates |
|---|---|---|---|
| **3706452171** | The Prophets' Hand: Reach Firefight | 2,850 | **Closest match to Evolved.** Score-based credit shop, buyable AI reinforcements in tiers 1–5, vehicles, airstrikes — and its page states **"No custom game mode is required"**, which independently proves a buy-menu Firefight mod can ship with zero gametype file. It modified the squad templates. |
| 3434207298 | deadkiva7's Halo: Reach Firefight (Map Pack) | 4,256 | 14 Firefight maps, every one with friendly modified marines. Same author credited in Evolved for Skirmisher masks. Spartan-team companion: 3543102766. |
| 3240182577 | Trooper Firefight – 2024 | 16,762 | 17 GB. AI squadmates; play as Marine or ODST. First-person version: 3422510261. |
| 3215748441 | Firefight XL | 1,417 | 4× AI counts, friendly marines at 2× health. Notably it instructs users to **turn dropships off in the variant** to raise AI counts — the same `usesDropship` bit that is the entire delta between the user's two `.bin` files. |
| 2941809544 | ODST Firefight (Reach) | 1,379 | ODST player plus AI marines, set up through lobby traits and loadouts. |
| 2923946201 / 2986601070 | Hemorrhage / Beachhead AI Mayhem | 9,340 / 5,036 | HSC-driven endless war with dropship reinforcements and an in-game AI control switch. |
| 3029342213 | Holdoff with Marines and Elite ALLIES | 659 | Respawning allies plus an allied Falcon — the Falcon-ally pattern. |
| 3838097485 | Unearthed Firefight | 122 | Persistent friendly UNSC AI on the same map we care about. |
| 3212616637 | Halo Reach – Infantry | 14,161 | Marine-infantry overhaul across Firefight, campaign and multiplayer. |
| 2899279981 / 2899746029 | Halo Reach Mythic Overhaul (Firefight / Campaign) | — | 13.8 GB and 16.0 GB. Comparable split-by-mode overhaul packaging. |
| 2899383598 | Forge World AI Battleground | 12,211 | Spawns 180+ AI from the Forge menu but **requires replacing `haloreach.dll`**. Listed as a technique to avoid: not Workshop-safe, breaks on every MCC update. |

Workshop URL pattern: `https://steamcommunity.com/sharedfiles/filedetails/?id=<id>`

### 9.4 Nexus and GitHub

Nexus URL pattern: `https://www.nexusmods.com/halothemasterchiefcollection/mods/<id>`

- **2251** Friendly Marines in Halo Reach Firefight — replaces `ff60_airview.map`; marines
  respawn indefinitely. The minimal version of the ally-squad technique, one map, one cache.
- **2815** Elite Firefight — seven modes built purely by swapping squad types.
- **685** Forgable PvP Firefight gametype — Megalo, and reportedly works with EAC on.
- **1181** Rust gametype — a **Megalo item shop** with buyable bases and weapons. The best
  available reference for a currency/purchase UI inside Megalo's 4-widget ceiling.
- **1215** Halo City RPG — Megalo money and jobs.
- **2905** Firefight Reforged — Forge on Firefight maps, built with HREK.

GitHub:

- **https://github.com/NervyDestroyer/Halo-MCC-Scripts** — contains
  `HR/globals/global_firefight.hsc`, ~3,443 lines. **This is the single most valuable prior
  art for this project:** it is Reach's own Firefight wave/round/set flow in HaloScript,
  including `ai_sur_*` squad handling, Phantom dropships and `alpha_sync_slayer`. Read this
  before writing a line of HSC.
- https://github.com/petfelt/RVT-scripts — RVT script examples including `halo-moba`.
- https://github.com/faris0064/VSCode-ReachVariantTool — VS Code support for RVT script.
- **No open-source Reach map script implementing a buy menu or a friendly-squad spawner was
  found.** That part we write ourselves.
- The brief's `DavidJCobb/megalo-explanation` does not exist among that author's public repos.

---

## 10. Install and run procedure

### 10.1 For this mod, as a player

1. Own and install MCC (app 976730) with **Halo: Reach, both the singleplayer and
   multiplayer content packages**. Author-stated: a co-op partner missing one of them gets
   "missing content" errors.
2. Subscribe to Workshop item 3453792163. Steam downloads it to
   `steamapps\workshop\content\976730\3453792163\`.
3. Download the two gametype `.bin` files from the author's OneDrive link, or from his
   in-game file share under the gamertag **Vengeful Vadam**. They are not on the Workshop.
4. Place both `.bin` files in
   `steamapps\common\Halo The Master Chief Collection\haloreach\game_variants\`.
   Create the folder if it does not exist.
5. **Launch MCC through the "Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)"
   option**, not the default launch option. Equivalent URL: `steam://launch/976730/option2`.
6. Enable the mod in MCC's in-game mod browser, then start Firefight on Installation 04,
   Unearthed or Corvette and select the matching custom gametype (Firefight Evolved, or
   Firefight Corvette Evolved on Corvette).
7. If the modded content does not appear: unsubscribe and resubscribe (author's own advice).

### 10.2 Anti-cheat — the honest state of it

**FACT (official, Halo Support):** MCC mods do not work with Easy Anti-Cheat enabled. The
documented articles are
`https://support.halowaypoint.com/hc/en-us/articles/28916975982868` and
`https://support.halowaypoint.com/hc/en-us/articles/360037475251`. The EAC-disabled launch
option is the supported, 343-provided path; it is not a bypass. Launching that way disables
matchmaking and some online services for the session ("Limited Services").

**Nuance worth keeping straight:** a plain custom *game variant* `.bin` dropped into
`game_variants` is ordinary user content and is not itself what trips EAC — Nexus mod 685,
a Megalo gametype, is reported to work with EAC on. What requires the EAC-disabled path is
the **modified map package**. Since this mod is inseparable from its map package, the
EAC-disabled launch is required in practice. Several commenters hit exactly this and were
pointed at the second launch option.

### 10.3 Where files go, for our own new content

| Content | Path |
|---|---|
| Subscribed Workshop mod | `steamapps\workshop\content\976730\<published_file_id>\` |
| Built-in / manually installed game variants | `...\Halo The Master Chief Collection\haloreach\game_variants\` |
| Matchmaking variants | `...\haloreach\hopper_game_variants\` |
| User-saved variants (saved from in-game) | `%USERPROFILE%\AppData\LocalLow\MCC\LocalFiles\` |
| Local unpublished mod registration | `%USERPROFILE%\AppData\LocalLow\MCC\Config\ModManifest.txt` — one mod root folder path per line. Community-sourced, not in official docs; verify before relying on it. |

### 10.4 Mod package layout (the shape our output must take)

From the official Excession docs
(`https://learn.microsoft.com/en-us/halo-master-chief-collection/excession/setup/folderstructure`),
cross-checked against Foundry's `tools/cache_builder.py` and Vortex's MCC extension types:

```
<mod root>/
  ModInfo.json          ModIdentifier{ModGuid, HostedModIds.SteamWorkshopId},
                        ModVersion, MinAppVersion, MaxAppVersion,
                        Engine: "HaloReach",
                        Title / Description.Neutral,
                        InheritSharedFiles: "FromMCC",
                        ModContents,
                        GameModContents{ HasCampaign, MultiplayerMaps[], FirefightMaps[] }
  maps/
    *.map               built cache files (e.g. cex_ff_halo.map, ff_unearthed.map,
                        ff45_corvette.map)
  firefight/
    <name>.json         MapGuid, ScenarioFile (tag path, no extension),
                        Images, Flags, InsertionPoints (Reach needs none)
  images/
    *.png
```

**There is no game-variant field anywhere in that schema.** That is almost certainly why
Vadam distributes his `.bin` files by OneDrive instead of bundling them — the Workshop
simply has no slot for them. (Inference, but the schema gap is fact.)

---

## 11. Implications for "Firefight Evolved Expanded"

1. **The toolchain question is settled: we need HREK.** Tag edits in Foundation, AI squads
   and HaloScript in Sapien, cache build with Tool, package with the Mod Uploader. Gametype
   editing alone cannot produce any of the mechanics in the brief.
2. **Good news on scope: no BSP authoring.** All three shipped maps are stock Reach Firefight
   scenarios (`cex_ff_halo`, `ff_unearthed`, `ff45_corvette`). Extending to another map means
   editing another stock `ff*` scenario, not building geometry. The remaining stock Reach
   Firefight scenarios are `ff10_prototype` (Overlook), `ff30_waterfront` (Waterfront),
   `ff45_corvette` (Corvette), `ff50_park` (Beachhead), `ff60_airview` (Outpost),
   `ff60_icecave` (Glacier), `ff_unearthed` (Unearthed), `cex_ff_halo` (Installation 04),
   plus Courtyard and Holdout.
3. **Start from Installation 04's stock machinery.** `cex_ff_halo` is the only vanilla
   Firefight scenario that already has friendly AI, a Pelican delivery script and a
   follow-the-player ODST. It is the cheapest place to prototype an ally-squad purchase.
4. **Read `global_firefight.hsc` first** (NervyDestroyer/Halo-MCC-Scripts). It is Reach's own
   wave/round/set logic in HSC and defines the `survival_mode_*` surface our purchase gating
   must hook into.
5. **The `.bin` is a copy-and-tweak artifact, not a design surface.** 983 of 996 fields are
   identical between the mod's two variants, and the only behavioural difference is
   `usesDropship`. A new map's variant can be cloned from the existing one and edited in a
   few bits. The sibling decode in `research/02-mpvr-megalo-format.md` says a writer is
   mechanically straightforward: recompute `sha1(be32(length) || data)` at `0x2FC`, keep the
   length at `0x314`, keep the `chdr` chunk in sync, stay under 20,480 payload bytes
   (current files use under 5 %).
6. **Prices and availability gates belong in the map**, which means a price change is a
   7 GB republish. Design the price table so it is easy to regenerate, and consider pulling
   prices from a single HSC globals block.
7. **Budget real time for ally AI quality.** It is the loudest, most repeated complaint about
   this mod across 263 comments: allies do not engage at range, do not evade grenades, do not
   fire vehicle weapons, and do not take cover. Prior art to lift from: Firefight XL's 2×
   ally health, Trooper Firefight's squadmates, deadkiva7's marine variants, Nexus 2251.
8. **Treat co-op as a second milestone.** The author's own known-issues list and a year of
   changelog entries show HSC-driven seats, created objects and effects syncing badly in
   Firefight co-op.
9. **Make the opening cinematic skippable.** Two separate commenters called the unskippable
   Unearthed intro the most annoying thing about replaying it.
10. **Consider the alternative design path explicitly before committing.** A *multiplayer*
    Megalo variant plus a custom map, bridged by `hs_function_call`, would put the buy menu
    and currency in a 21 KB file we can iterate on in seconds, with only the AI spawn
    primitives in the map. The cost is Megalo's hard ceilings (1024 actions, 512 conditions,
    320 triggers, 112 strings, **4 HUD widgets**) and the loss of Firefight's built-in
    wave/round/set engine. Vadam chose pure-Firefight-plus-HSC; Prophets' Hand did too. This
    is a genuine fork in the road and should be a deliberate decision, not a default.

---

## 12. Open questions I could not close

1. **Change notes before 2026-01-05 are unread** (HTTP 429 on pagination). Roughly nine
   months of updates between the 2025-03-28 release and 2026-01-05 are unexamined. They
   likely contain the original feature announcements for the purchase system.
2. **The three linked discussion threads are unread** (HTTP 429). They may hold a FAQ or an
   install troubleshooting post.
3. **The author's other uploads could not be enumerated.** The profile Workshop tab is empty
   to a logged-out client. The "only one MCC item" conclusion rests on a single text search
   and should be re-checked from a signed-in browser.
4. **No `.map` file was opened.** Every statement about map internals here is inference from
   format constraints plus the author's own changelog wording. Confirming it requires a
   Windows machine, the subscribed Workshop package, and Assembly or HREK.
5. **Whether the purchase system uses Firefight score directly or a separate counter** is
   unknown. The author says "using your Firefight score". Reach HSC exposes
   `campaign_metagame_get_player_score` and `campaign_metagame_award_points`; Megalo has a
   distinct "requisition money" currency (actions 38, 39, 69). Which one this mod uses cannot
   be determined without the map.
6. **Whether creating a missing `game_variants` folder is sufficient** — a commenter asked,
   the author never answered.
7. **One commenter reported the mod working without the gametype file at all.** Possibly the
   Workshop package also registers its own Firefight entries. Unverified, and worth checking,
   because if true it changes our distribution story.
