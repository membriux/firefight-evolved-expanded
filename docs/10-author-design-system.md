# The Vengeful 'Vadam's Firefight design system, reconstructed from public evidence

Research date: 2026-11-21. Target: Steam Workshop item **3453792163**, "Halo Reach: Evolved
Public Beta", for Halo: The Master Chief Collection (app 976730), 7.334 GB of modified
Halo: Reach `.map` files, plus off-Workshop `Firefight Evolved` `.bin` gametypes.
Author Steam id64 `76561198063340220`, vanity `the_vengeful_vadam`.

Scope of this document: his **design decisions** only — economy, scenario structure,
purchase-point placement, squad delivery, and deliberate omissions. The file-format and
toolchain work lives in `01`–`06` of this folder. This document does not repeat it.

## 0. Honesty key, read this first

Every claim below carries one of these tags. Nothing is unlabelled.

| Tag | Meaning |
|---|---|
| **STATED** | The author wrote it: Workshop description, change notes, or his own forum/video text. Quoted verbatim where it matters. |
| **OBSERVED** | Read off the screen: Workshop preview screenshots, or frames of gameplay video that I downloaded and OCR'd myself. The on-screen string is quoted; the build date is given, because his prices moved. |
| **REPORTED** | A player said it on Steam discussions/comments or in a video. Second-hand. |
| **INFERENCE** | My reasoning. The basis is always given so you can reject it. |
| **UNKNOWN** | I could not determine it. Listed explicitly rather than guessed. |

The single biggest honesty caveat: **the 21 Workshop preview screenshots are all from launch
day (2025-03-28/29)** and show launch-day prices, several of which he changed within 24 hours.
Where a screenshot price and a change-note price disagree, the change note wins and I say so.

### Sources actually read

| Source | What it gave |
|---|---|
| Workshop description (current, and 8 archive.org snapshots back to 2025-03-29) | the three scenario briefs, verbatim |
| **Change notes, all 21 entries, all 3 pages** (2025-03-28 → 2026-03-15) | the full price history. Pages 2–3 were the gap in prior research; they are now read. |
| 22 Workshop preview images, downloaded and read | purchase prompt strings, prices, HUD zone names on Installation 04 |
| Steam discussions, 4 topics incl. the 72-post Bug Report thread | co-op failure modes, win/lose confirmation, terminal object identity |
| 263 Workshop comments (prior agent's capture, re-used) | ally-AI complaints, balance feedback |
| YouTube: his channel (168 videos enumerated), 4 of his own trailers/previews, 3 third-party playthroughs | gameplay frames OCR'd for prompts, zones, round gates, and an empirical score curve |
| Reddit via PullPush, Bluesky, Nexus, ModDB, Patreon, Discord invite API | marketing copy only; **no prices anywhere** |

Rate-limiting note for whoever repeats this: `steamcommunity.com` returns HTTP 429 to
unauthenticated clients in bursts. Changelog pages 2 and 3 eventually came back on a 75-second
retry loop; discussions came back through a text-reader proxy. archive.org has the item page
but **no** snapshot of the changelog, so the retry loop is the only route to the old prices.

---

## 1. His economy

### 1.1 The one normalised table

"Price" = the most recent value I have evidence for. Arrows are his own changes in order.
"Gate" is a non-price unlock condition, which he uses as heavily as price.

#### Installation 04 (`cex_ff_halo`)

| Item | Price history | Gate | Evidence |
|---|---|---|---|
| Light Weapon Rack | **500** | none seen | OBSERVED, screenshot, launch: "Hold [E] to buy Light Weapon Rack (500 points)" |
| Medium Weapon Rack | **1,000** | none seen | OBSERVED on Unearthed; INFERENCE that the same rack tier exists on I04 (see 1.3) |
| Machinegun Turret | **750** | none seen | OBSERVED, screenshot, launch: "Hold [E] to buy Machinegun Turret (750 points)" |
| ODST reinforcements | **2,000 → 750** (0.1.1, 2025-03-29) | switch respawns if you lose all allies | STATED: "Installation 04 ODSTs: 2,000 -> 750". Launch price OBSERVED on screenshot: "Hold [E] to call in ODSTs (2,000 points)" |
| Sentinel Hack (one round) | **3,000 → 1,000** (0.1.1) | none seen | STATED: "Installation 04 Sentinel Hack: 3,000 -> 1,000" |
| Falcon gunner run | **4,000 → 3,000** (0.1.1) | none seen | STATED: "Installation 04 Falcon run: 4,000 -> 3,000". Launch price OBSERVED: "Hold [E] to call in a Falcon (4,000 points)" |
| Auto Turret | UNKNOWN | **"Auto Turret not available until Round 3…"** | OBSERVED, screenshot, launch |
| Evac Pelican (**win purchase**) | UNKNOWN | HUD message announces availability | STATED: "until you're able to call for a pelican extraction to win the game"; "HUD messages for important events (…Installation 04's Evac Pelican…)" |
| Deposit kiosk | **200 → 500** per use (2025-12-30) | none | STATED |
| Withdraw kiosk | **200 → 500** per use (2025-12-30) | none | STATED |

#### Unearthed (`ff_unearthed`)

| Item | Price history | Gate | Evidence |
|---|---|---|---|
| Base Power ("restore power to the base") | **750 → 350** (0.1.1) | none — it is the opening move | STATED: "Unearthed Base Power: 750 -> 350". 750 OBSERVED in his 2024 trailer: "Hold [E] to [restore] power to the base (750 …)" |
| Trooper / Marine reinforcements | **1,000 → 500** (0.1.1) | switch respawns if you lose all troopers and ODSTs mid-round | STATED: "Unearthed Marines: 1,000 -> 500". 1,000 OBSERVED in launch-build footage: "Hold [E] to request trooper reinforcements (1,000 points)" |
| Light Weapon Rack | **500** | none | OBSERVED, launch footage |
| Medium Weapon Rack | **1,000** | none | OBSERVED, launch footage and 2026-07 footage: "Hold [E] to buy Medium Weapon Rack (1000 points)" |
| Machinegun Turret | **750** | none | OBSERVED, 2026-07 footage |
| Drop Shield | **400** | none | OBSERVED, launch footage, zone "Store Room" |
| Overshield | **750 → 500** (0.1.1) | none | STATED |
| Active Camo | **750 → 500** (0.1.1) | none | STATED |
| Rocket Warthog | **1,500 → 1,000** (0.1.1) | **Round 2** | STATED; "Hold [E] to buy Warthog (1,…)" OBSERVED 2026-07; "Warthog not available until Round 2" OBSERVED |
| Gauss upgrade | **3,000 → 2,000** (0.1.1) | **Round 2** | STATED; OBSERVED 2026-07: "to upgrade to Gauss Warthog (2,000 points, takes effect …)" |
| Scorpion | **5,000 → 2,500** (0.1.1) **→ 3,500** (0.1.5, 2025-04-07) | **Round 3** | STATED both changes; "Scorpion not available until Round 3" OBSERVED |
| Auto Turret | UNKNOWN | **Round 3** | OBSERVED: "Auto Turret not available until Round 3…" |
| MAC Cannon (**win purchase**) | UNKNOWN | **Set 2, Round 3, Wave 5** → later "**start of Set 2**" (2026-03-15) | OBSERVED verbatim on screen: "…not available until Set 2, Round 3, Wave 5". STATED: "MAC Cannon on Unearthed becomes available at the start of Set 2 instead of at the end of the set" |
| Deposit / Withdraw kiosks | **200 → 500** | none | STATED |

#### Corvette (`ff45_corvette`), added 2025-12-23

| Item | Price history | Gate | Evidence |
|---|---|---|---|
| Room / door unlock — "the path to the Corvette's Gun Room" | **250** | none seen | OBSERVED in his own Corvette trailer: "Hold [E] to unlock the path to the Corvette's Gun Room (250 points)" |
| Mystery Box, one pull | **250** | box relocates between fixed positions | OBSERVED: "for a Random Weapon (250 points)" |
| Fuel Rod Shade | **1,500 → 2,000** (2026-02-17) | unlock-then-upgrade tier | STATED |
| AA Shade | **3,000 → 6,000** (2026-02-17) | unlock-then-upgrade tier | STATED |
| Sabre Round conversion | **2,500** | converts the *next* round | STATED: "Buyable Sabre Round conversion added on Corvette, costs 2,500 points" |
| Friendly Engineer | UNKNOWN | repeatable (he had to fix an infinite-respawn bug "after its second purchase") | STATED + REPORTED |
| Weapon crates | UNKNOWN | — | STATED in the description |
| Bridge access (**win purchase**, chained) | UNKNOWN per door | bought room by room | STATED: "make preparations to storm the bridge"; "You got a taste of this with Corvette, where you'd buy different sections of the map" |

#### Exodus — his unreleased fourth map, for forward-looking calibration

STATED in the description of his 2026-05-18 members-only preview video:

| Item | Price |
|---|---|
| Man Cannon, one-way traversal | **750** |
| Troopers, "deployed via Falcon" | **500** |
| Oddball objective reward (hold 30 s) | **+1,500** to the team |

### 1.2 What the price *moves* tell you — the valuable half

Read the directions, not the numbers.

**He cut almost every price by 50–75 % within 24 hours of launch.** The 0.1.1 note
(2025-03-29, one day after release) moves nine prices and every single one goes **down**:
ODSTs 2,000→750, Sentinel Hack 3,000→1,000, Falcon 4,000→3,000, Scorpion 5,000→2,500,
Gauss 3,000→2,000, Warthog 1,500→1,000, Marines 1,000→500, Base Power 750→350,
Overshield and Active Camo 750→500. **INFERENCE, high confidence:** his pre-release pricing
was pitched off an income assumption that was roughly 2–4× too high, and real play showed
players never reached the interesting purchases. Do not repeat that mistake — start cheap.

**The same patch added the bank.** "Added a banking system; one kiosk deposits 200 points,
another withdraws 200 points. This should help achieving win conditions in co-op easier."
(STATED.) **INFERENCE:** score is per-player, win purchases are expensive, and in co-op
nobody individually accumulates enough. The bank is a pooling mechanism bolted on because a
per-player wallet breaks a team win condition. Three weeks later the step size went 200→500
with "a second buffer" — i.e. the 200-step kiosk needed too many presses and was spammable.

**Only one price ever went up by itself: the Scorpion, 2,500→3,500** (0.1.5). Players
simultaneously complained it "is not worth its price against Covenant explosives", and the
same patch gave it a co-axial gun buff (7→10) and made it respawn each round once bought. So
the raise is paired with a buff and a persistence change — he decided the Scorpion was *too
available*, not too weak.

**The Corvette turret prices both went up, hard.** Fuel Rod Shade 1,500→2,000 *and* a tracking
buff; AA Shade **3,000→6,000** with no compensating buff and an added overheat penalty
("I made it overheat after extended use", STATED in his overview video). The AA Shade doubling
is the loudest balance signal in the whole changelog: **a fixed emplacement that can hit
everything on an interior map is the single most overpowered purchase he shipped.**

**Round gates, not price, are his real pacing tool.** On Unearthed the Warthog and Gauss
upgrade are locked to Round 2 and the Scorpion and Auto Turret to Round 3, and he announces
them with a HUD banner on the round boundary — OBSERVED verbatim: "The Warthog and Gauss
upgrade are now available!" and "The Scorpion and Auto Turret are now available!". Prices
alone would let a lucky early round break the curve; the gate makes the curve unbreakable.
The 0.1.6 note says why he had to add the banners: "HUD messages for important events
(switches becoming available, Unearthed's MAC Cannon, Installation 04's Evac Pelican, etc) are
now implemented to make objectives more clear ingame."

**Ally purchases are self-repairing.** Three separate notes add the same rule to both maps:
"if your team runs out of troopers and ODSTs during a round, the switch to buy trooper
reinforcements will respawn"; "Just like on Unearthed, if you run out of Marines and ODSTs,
and ODSTs were already bought, the switch to buy another squad of ODSTs will respawn"; and in
2026-03: "If you lose your marine squad on Unearthed, you can buy another during the same
round you lost them in." **INFERENCE:** a one-shot ally purchase is a trap, because allies die
fast; he converged on "the ally switch is effectively always re-buyable".

### 1.3 His price ladder, and what it implies about score per round

Collapsing all three maps, every price he has ever shipped lands on one of six rungs:

| Rung | Prices | What lives there |
|---|---|---|
| Impulse | 250 | Corvette door unlock, Mystery Box pull |
| Cheap utility | 350–500 | Base Power, Drop Shield 400, Overshield 500, Active Camo 500, Light Weapon Rack 500, ally squad 500–750 |
| Standard | 750–1,000 | Machinegun Turret 750, Medium Weapon Rack 1,000, Rocket Warthog 1,000, Sentinel Hack 1,000, Exodus Man Cannon 750 |
| Set purchase | 2,000–2,500 | Gauss upgrade 2,000, Fuel Rod Shade 2,000, Sabre Round 2,500 |
| Heavy | 3,000–3,500 | Falcon gunner run 3,000, Scorpion 3,500 |
| Punitive | 6,000 | AA Shade only |

**Score-per-round assumption — INFERENCE, with method.** I measured it rather than guessed.
I OCR'd the score counter out of every other second of a complete 21-minute solo Unearthed
playthrough (Dino, 2025-04-01, launch build) and got a monotone curve:

| Elapsed | Score |
|---|---|
| 1:18 | 581 |
| 4:40 | 1,239 |
| 8:00 | 3,891 |
| 11:42 | 5,282 |
| 14:29 | ~8,200 (MAC Cannon becomes available) |
| 20:34 | 18,365 |

That is roughly **900 points per minute** of sustained solo play, accelerating as waves get
denser. A Reach Firefight round is 5 waves; in this run a round ran about 2.5–3 minutes, so:

- **one round ≈ 2,000–2,500 points**
- **one set (3 rounds + bonus) ≈ 7,000–8,500 points**

Lay the ladder over that and his intent is unambiguous:

- 250–750 = **under a third of a round.** Buy on reflex, several times a round.
- 1,000–2,000 = **about one round's income.** One per round, a real choice.
- 2,500–3,500 = **1.5 rounds.** One per set. This is where the Scorpion and Falcon sit.
- 6,000 = **a whole set.** Deliberately almost unaffordable.
- The **win purchase is gated to land near 8,000 accumulated**, i.e. at the end of set 1 /
  into set 2 — which is exactly where he put the MAC Cannon gate (Set 2, Round 3, Wave 5,
  later loosened to the start of Set 2).

Caveat on this inference: that run's gametype score settings are not visible, it is the launch
build, and it is solo. Treat 900/min as the right order of magnitude, not a constant. But the
*ratios* — impulse = ⅓ round, heavy = 1.5 rounds, win = 4 rounds — are what you should copy.

### 1.4 Everything else the change notes record (completeness pass)

The 21 entries are overwhelmingly **tag-data balance**, not scenario work. For the design
system the relevant residue is above; for the record, the rest breaks down as:

- **Weapon/vehicle numbers** (the bulk): Battle Rifle 7→8 damage, velocity 225→300 world
  units/s, spread 0.3–0.6→0.1–0.1; Needle Rifle fire recovery 0.5→0.4 then wait 0.4→0.45;
  Spiker 15→10→15; Assault Rifle 7.5→8→8.75; Shotgun 5→8 min / 10→13 max, range 15→40;
  Machine Gun Turret 10→13; Scorpion co-axial 7→10; Rocket Warthog impact/explosion 45→65;
  Banshee 6→9 per bolt; Grenade Launcher explosion 180→220, EMP 100→150; Plasma Pistol
  battery/shot 0.002→0.01→"1 % from 0.5 %"; Scorpion health 600→800; jump height 115→125 %;
  Heroic damage 1.4→1.2 and Legendary 1.8→1.4 (i.e. he **lowered** incoming difficulty twice,
  and the 2025-12-23 note says "Difficulty adjustment across the board to be more lenient").
- **Enemy AI tuning**: engagement ranges up for AR/magnum/SMG users; burst separation up for
  plasma spate / plasma caster / fuel rod / plasma turret; fuel-rod Shade damage scaling
  "nerfed significantly"; EMP vs player health 25 %→5 %; Grunt Majors/Ultras/Heavies/Spec-Ops
  shoot faster and more accurately than Minors; Elites given "slightly slower, more
  telegraphed melee attacks".
- **Ally AI tuning**: "made a plethora of changes to their AI for the better, shoutout to King
  Feraligatr"; Troopers/ODSTs grenade collateral radius 3.5→5 world units and "now have melee
  damage"; "Troopers have their melee attacks fixed"; AI could not use the Grenade Launcher at
  all until 0.1.5 ("fixed an oversight").
- **New content**: two new Hunter variants, the Aggro and the Pyro (2026-01-13); Stealth Elite
  Major rank; Halo 1 Pistol and savinpvtmike's MA5B added to the Mystery Box; destructible
  Skirmisher masks; Evade AA added to two campaign missions.
- **Bug fixes that reveal mechanics** — these are the useful ones, see §3 and §4: the hill
  teleporting into a locked Corvette room; optional objectives not re-triggering after a set;
  the evac Pelican blocked by a drop pod; the Falcon made EMP-immune and set to fly away if its
  gunner dies; Sentinels "patrol to different points … shouldn't try to touch the ground";
  Unearthed hazards "don't occur at the exact same time anymore".

---

## 2. His scenario grammar

Three maps, one formula. It holds on all three.

### 2.1 The formula, in four lines

1. **Insert with a squad, under a cutscene.** You arrive with friendly AI already assigned to
   you — marines (I04), ODSTs in drop pods (Unearthed), troopers (Corvette) — and an
   unskippable opening cinematic plays. (STATED for all three; REPORTED repeatedly as
   annoying on replay.)
2. **One "secure the X" objective gates everything, and completing it summons the antagonist.**
   Secure the beam tower / secure the base / secure the hangar. On Unearthed the author is
   explicit that the trigger is causal: "Drop in with a squad of ODSTs to secure the base, **but
   this will trigger** a Covenant cruiser to slipspace into the AO."
3. **The antagonist supplies both the wave pressure and a recurring environmental hazard**, and
   the economy opens: point stations sell base upgrades, allies, armor abilities and vehicles,
   with heavy items locked behind round number and announced by a HUD banner at the round
   boundary.
4. **The win is a purchase; the loss is the antagonist's timer.** Buy the Pelican evac / the MAC
   Cannon / the chain of doors to the bridge, and the match ends in victory. Fail to buy in
   time and the antagonist finishes its job — on Unearthed, "the glassing beam will activate
   and everyone dies, resulting in a loss."

### 2.2 The same formula in table form

| | Installation 04 | Unearthed | Corvette |
|---|---|---|---|
| Opening squad | marines | ODSTs, arriving in drop pods | troopers |
| Opening cutscene | yes | yes (you spawn inside a drop pod) | yes |
| Stage-1 objective | secure the beam tower | secure the base (then restore base power, 350) | secure the hangar |
| Escalation trigger | Covenant interest in the Forerunner tech | securing the base summons a Covenant cruiser | boarding the Ardent Prayer |
| Third faction / twist | **Sentinels**, hostile, hackable for one round | **Covenant cruiser** overhead | the ship itself — locked rooms, friendly **Engineers** |
| Recurring hazard | Sentinels; Spirit dropships on the Falcon's flight path | ship-cannon barrage, drones; "don't occur at the exact same time anymore" | hangar-barrier Spirit drops; space combat |
| Win purchase | **Pelican extraction** | **MAC Cannon**, destroys the cruiser | **unlock the path to the bridge**, room by room |
| Win gate | HUD-announced availability | Set 2 / Round 3 / Wave 5 → start of Set 2 | sequential room purchases |
| Lose condition | lives exhausted (no scripted timer found) | **glassing beam timer** → everyone dies | lives exhausted (no scripted timer found) |
| Inter-round objectives | retro-fitted 2025-12-23 | retro-fitted 2025-12-23 | **KOTH / Race / CTF**, native |
| Bonus rounds | Falcon gunner ride (a purchase, not a round) | yes, observed ("Bonus round over… Lives added") | **Corvette Cannonade** (ship guns) and **Sabre Strike** (Sabre cockpit) |

### 2.3 Three structural decisions worth copying

**The win is bought, so the match has no natural end.** This is why the companion variant
carries `waveLimit = 0` (see `research/04`). Firefight never times out; the script ends it.
That single choice is what turns Firefight from an endurance score-chase into a scenario.

**The newest map's features get back-ported to the old ones.** 2025-12-23: "Unearthed and
Installation 04 have been updated to include the new gametype objective features introduced
in Corvette!" He treats the three maps as one product with a shared feature set, not three
one-offs. **Design implication for you: build the shared mechanics as a reusable block, not
per map.**

**Optional objectives and switch states must be reset at set boundaries, and he got this wrong
twice.** "Objectives should properly reset after a set completes, so they can activate again"
(2026-01-13) and "Fixed optional firefight objectives not retriggering again after losing
specific objectives" (2026-03-15). Any purchase or objective state you keep in a script global
needs an explicit per-set teardown.

---

## 3. His purchase-point placement

**This is the section the user needs most, so the uncertainty is marked hard.**

### 3.0 What the purchase point *is*, on every map

Not a menu. **A physical, world-placed UNSC computer terminal** — a pedestal with an angled
screen, the stock Reach "data terminal" look. You walk up and get a standard Reach
hold-to-interact prompt in the upper right:

> `Hold [E] to buy Light Weapon Rack (500 points)`
> `Hold [E] to buy Machinegun Turret (750 points)`
> `Hold [E] to call in ODSTs (2,000 points)`
> `Hold [E] to call in a Falcon (4,000 points)`
> `Hold [E] to request trooper reinforcements (1,000 points)`
> `Hold [E] to restore power to the base`
> `Hold [E] to buy Drop Shield (400 points)`
> `Hold [E] to upgrade to Gauss Warthog (2,000 points, takes effect …)`
> `Hold [E] to unlock the path to the Corvette's Gun Room (250 points)`
> `Hold [E] to withdraw 500 deposited points.`

All OBSERVED, read directly off screenshots and OCR'd video frames. The verb changes with the
item class — **buy** for objects, **call in** for air/ally delivery, **request** for ally
squads, **restore** for the base-power switch, **unlock** for map sections, **upgrade** for
tier swaps. That verb vocabulary is itself worth copying.

Four further facts about the object:

- **One terminal per purchasable, not one terminal with a list.** Screenshots show two and
  three terminals standing side by side, each advertising a different item, each with its own
  gate text ("Auto Turret not available until Round 3…" appears on its own terminal).
- **Terminals are consumed and conditionally respawned.** His own words: "the switch to buy
  another squad of ODSTs **will respawn**". He calls them *switches*; players call them
  *requisition terminals*.
- **The locked state is drawn on the terminal's own screen.** One screenshot shows a terminal
  displaying `UNSC SB ARRAY 2-H` / `TERMINAL LOCKED` / `Password`, with a red **-500** floating
  over it. INFERENCE: locked and unlocked terminals use different screen bitmaps, and the
  floating red cost is the standard Reach "you can't afford / cost" callout.
- **A yellow translucent hologram marks where the purchase will physically appear.** Visible in
  the Light Weapon Rack and Machinegun Turret screenshots — a wireframe gold volume, turret-
  shaped in the turret case, beside the terminal. INFERENCE from two independent screenshots.
- **REPORTED co-op failure mode, which tells you what the object is made of:** a desynced
  client saw "all of the requisition terminals and such being replaced by a mixture of covenant
  radar crates, and UNSC Supply Pods". INFERENCE: the terminals are placed scenery whose tag
  reference does not survive a late join.

### 3.1 Installation 04 — HIGH CONFIDENCE, two clusters plus the bank

The map's HUD zone names, read off his own screenshots: **Upper Deck**, **Station 2 Interior**,
**West Drop Zone**, **South Drop Zone**, **Field**, **West Ramp**. ("upper-deck" is
independently corroborated by a player's co-op bug report on this map.)

| Cluster | Zone | Sells | Evidence |
|---|---|---|---|
| **Exterior / base-upgrade cluster** | **Upper Deck** | Light Weapon Rack (500), Machinegun Turret (750); the Auto Turret gate message also appears here | OBSERVED, three screenshots, zone label legible in each |
| **Interior / call-in cluster** | **Station 2 Interior** | ODSTs (2,000), Falcon gunner run (4,000) — two terminals side by side | OBSERVED, two screenshots |
| **Bank** | the beam tower's **internal ramps, next to the health pack** | deposit, withdraw | **STATED verbatim**: "I04 has them on the beam tower's internal ramps next to the health pack" |

**Why there — INFERENCE.** The split is functional, not decorative. The things you buy to
*fortify a position* (weapon rack, turret) sit outdoors on the Upper Deck, at the position you
are defending, because that is where the turret and the rack have to physically exist. The
things you buy to *change the situation* (a squad, an air strike) sit in a sheltered interior,
because you need to survive the five seconds of the hold-to-interact while under fire. And the
bank sits **next to the health pack** — the one spot on the map every player already walks to
every round. He put the fiddly, repeated, multi-press interaction on the existing traffic route.

**Honest limit:** I cannot prove that "Station 2 Interior" *is* the interior of the structure
he calls the beam tower. His bank note places the kiosks on "the beam tower's internal ramps",
which is a third named location. Treat Upper Deck and Station 2 Interior as two distinct
defensible positions and the beam tower ramp as a third; do not assume two of the three are the
same room.

### 3.2 Unearthed — HIGH CONFIDENCE, one hub plus two outposts

HUD zone names observed: **Facility Interior**, **Facility**, **Store Room**, **Crane**,
**Conveyor**, **Drop Zone**, **Ramp**, **Mine**.

| Cluster | Zone | Sells | Evidence |
|---|---|---|---|
| **The hub — almost everything** | **Facility Interior** | trooper reinforcements, Base Power ("restore power to…"), Rocket Warthog, Gauss upgrade, Scorpion, Light and Medium Weapon Racks, Machinegun Turret; the gate banners for Warthog/Gauss/Scorpion/Auto Turret all read out here | OBSERVED repeatedly, in both the launch build (2025-04) and the current build (2026-07). Several prompts appear within ~10 seconds of each other in one room. |
| **Armor abilities** | **Store Room** | Drop Shield (400); INFERENCE that Overshield (500) and Active Camo (500) are here too | OBSERVED for Drop Shield |
| **Bank** | near the **base power switch**, i.e. in the hub | deposit, withdraw | **STATED verbatim**: "Unearthed has them near the base power switch" |
| **Auto Turret** | **first floor of the base** | the turret | **STATED verbatim**: "moved the autoturret to the first floor of the base" (2025-03-30), with a same-day hotfix that "moved the covvie drop pod landing zone that's next to the new autoturret location" |
| **MAC Cannon — the win purchase** | **Crane** | the win | OBSERVED: the gate string "…not available until Set 2, Round 3, Wave 5" is on screen while the HUD zone label reads **Crane** |
| **Vehicle delivery point** | the **garage** | where the bought Warthog and Scorpion materialise | **STATED**: "Scorpion and Warthog now spawn in the garage and respawn after each round once bought" |

**Why there — INFERENCE, and this is the most instructive placement on any of the three maps.**
Everything routine is crammed inside the defensible building, so the whole economy is usable
without leaving cover. But the **win purchase is deliberately exiled to the Crane**, away from
the hub. The run to the Crane under a Covenant cruiser's barrage, on the round the glassing
timer is burning down, *is* the climax. He also moved the two machine-gun turrets **closer to
the base** and moved two Covenant drop-pod landing zones (Jetpack Elites, Concussion Rifle
Brutes) **further away from the base** in the same patch — he tightens the friendly footprint
and pushes the hostile footprint out, then puts the win on the far side of the gap.

**Copy this pattern:** routine economy inside the defensible area; win purchase outside it.

### 3.3 Corvette — LOW CONFIDENCE. Read the caveat.

**I could not determine where Corvette's point stations physically sit.** There is no
third-party gameplay footage of Corvette Evolved on YouTube (I searched; every "Corvette
Firefight" result is vanilla or a different mod), his own Corvette video is a 5-minute
music-only trailer, and the promised "Overview Part 2" covering Firefight is unpublished.
**Do not build Corvette placement off this document.**

What I can say, with the evidence labelled:

- **OBSERVED, in his trailer, in situ:** `Hold [E] to unlock the path to the Corvette's Gun
  Room (250 points)` and `for a Random Weapon (250 points)`. So the room-unlock and the Mystery
  Box use the same terminal interaction as the other two maps.
- **STATED, his own term for the mechanic**, on a trailer caption: "Your Firefight score is
  your currency. **Spend it at the point stations** to purchase a variety of bonuses!" —
  *point stations* is the author's name for these objects. Use it.
- **STATED:** the Mystery Box "randomly spawns in specific locations", i.e. a fixed candidate
  list with a random pick, CoD-Zombies style.
- **STATED:** the Shade turret is "a Shade turret to unlock and upgrade" — a two-step purchase
  on one emplacement, not two separate turrets.
- **STATED, and this is the structural difference:** "You got a taste of this with Corvette,
  where you'd buy different sections of the map." On Corvette the purchases *are* the level
  progression. The map opens as the hangar and you buy your way aft and up to the bridge.
- **REPORTED, positional hints only:** a crash occurs "randomly after buying the first door" —
  so there is a defined *first* door, i.e. an ordered chain. The friendly Engineer is bought in
  or beside the **hangar** ("When spawning the friendly engineer in Corvette and leaving the
  hangar. If you return to the hangar, the engineer will be in a perpetual cycle of despawning
  and respawning"). The author removed "the covenant explosive batteries next to the door
  leading to the **aftship**", and fixed the shield door above the aftship to be permanently
  one-way — so hangar → aftship is an early link in the chain. The **Gun Room** is a separately
  unlockable room that also opens the Corvette Cannonade bonus round, and an unlock bug made
  "the hill on corvette teleport to the gun room if you don't have that room unlocked yet".
- **UNKNOWN:** the number of doors, the price of each after the first, the Shade's position,
  the Mystery Box's candidate positions, where the Sabre Round conversion is bought, and
  whether there is a bank on Corvette at all.

---

## 4. His squad delivery

| Map | Friendly arrival | Where |
|---|---|---|
| **Installation 04** | Marines are **present from the start**, on foot. Purchased **ODSTs arrive by drop pod**. Replacement marines arrive **by Pelican** between rounds: "After each round, if you lost your marine squad, a replacement pair of marines, **including the hog gunner**, will come with the Pelican that drops the warthog." The **win** is a Pelican that physically lands. | He **moved the ODST drop-pod landing zones closer to the beam tower** (0.1.5). Vanilla `cex_ff_halo` already has four stationary ODSTs at the top of the beam tower and already has a Pelican that flies in with a Warthog drop plus a follow-the-player ODST — he is extending stock machinery, not inventing it. |
| **Unearthed** | The player and squad **arrive inside drop pods during the opening cinematic** (REPORTED bug: "you don't spawn in the drop pod but pretty far away from where you should"). **"2 ODSTs will drop in when a new round starts"**, and also if you lose all ODSTs before Firefight officially begins. Purchased troopers arrive **by Pelican**. | Launch build dropped bought marines "out in the open"; 0.1.1 changed it to **"Marines are now dropped off directly to the base instead of out in the open."** A player saw the seam: "when I called troopers, they were at the initial spawn and didn't tp to the pelican" — INFERENCE: the squad is spawned at a fixed point and then moved to the Pelican's landing point, and the move can fail. |
| **Corvette** | Troopers **infiltrate with you** at the start. No delivery vehicle. The purchasable ally is a **friendly Engineer**, spawned at/near the hangar. | INFERENCE: it is a ship interior with no sky, so there is nothing to deliver by. |

**Enemy delivery, because he treats it as the same design surface:**

- Both outdoor maps use **Covenant drop pods with named, individually-tuned landing zones**,
  and he repositions them constantly: the Concussion Rifle Brute pod "was moved to the same
  spot as the Brute Stalker drop pod due to pathfinding issues at the previous location"; two
  pods moved "further away from the base"; one Fuel Rod Grunt pod swapped for a Spec-Ops squad
  (one Spec-Ops Elite with a Plasma Caster, three Spec-Ops Grunts with Plasma Rifles); drop-pod
  Elite Ultras replaced with Jetpack Elites; one Concussion Brute pod replaced with Stealth
  Brutes wielding Maulers. **A drop pod landing zone is a tuning knob, per-squad.**
- A drop pod can **block the win**: "The evac Pelican in Installation 04 won't land due to a
  shock trooper pod." Keep the win-vehicle's landing volume clear of pod zones.
- Corvette uses **Spirits and Phantoms into the hangar** past the shield barrier, and he delayed
  "the dropship deployment on Corvette by one second" to stop Jetpack Elites being stuck
  outside.
- The Falcon gunner ride is a **scripted flight path**, hardened three times: flight path
  adjusted twice so Spirit dropships stop intercepting it, made **immune to EMP**, and "if you
  die while in the Falcon's gunner seat, the falcon will immediately fly away from the map".

**The loudest player complaint in the entire corpus is that the allies are not worth buying.**
Multiple independent commenters: "Marines are basically just a waste of points, as their firing
patterns are too sporadic and inaccurate compared to enemies… ODSTs can't hit anything with the
new fuel rod cannon, they take 7–10 seconds after every sniper rifle shot… after five minutes
of driving an ODST with a grenade launcher in the passenger seat of a warthog, he literally did
not fire it once"; "whenever a plasma grenade is thrown, they don't bother to dodge"; "They're
only good as cannon fodder and as passengers for whatever vehicle you're using." He has patched
ally AI at least four times and it is still the top complaint. **If you copy one thing and fix
one thing: copy the purchase-point design, fix the ally AI.** Specifically, the fix list players
keep naming is engagement distance, target reacquisition, grenade evasion, and heavy-weapon
willingness.

---

## 5. What he avoided, and why

### 5.1 Per map

| Map | Conspicuously absent | Most likely reason |
|---|---|---|
| **Installation 04** | No Scorpion. No ground-vehicle purchase at all. | INFERENCE: vanilla already Pelican-drops a Warthog here, so the ground-vehicle slot is taken for free; and the fight is a tower hold, not a road fight. |
| | No MAC Cannon / no map-destroying win. | The win is an extraction, not a kill. One win verb per map. |
| | No Mystery Box, no KOTH/Race/CTF at launch. | Those were invented for Corvette eight months later and back-ported. |
| | No purchasable Shade turrets. | INFERENCE: Shades are the Corvette's signature; the Machinegun Turret fills the emplacement slot here. |
| **Unearthed** | **No air vehicle purchase at all** — no Falcon, no Banshee, nothing. | INFERENCE, high confidence: a Covenant cruiser is parked overhead firing ship cannons at the AO. There is no survivable airspace. This is the clearest "the map decides the catalogue" call he makes. |
| | No Sentinel hack. | No Forerunner tech on a human mining facility. |
| | No Pelican evac win. | The cruiser must die; a MAC Cannon is the only answer that fits the fiction. |
| **Corvette** | **No vehicles whatsoever.** No Warthog, no Scorpion, no Falcon, no Pelican. | Ship interior. No room, no sky, no landing surface. |
| | No drop-pod or Pelican squad delivery. | Same reason; the squad has to walk in with you. |
| | No auto turret. | INFERENCE: the Shade unlock/upgrade tier occupies the emplacement slot, and corridors do not need area denial. |
| | No MAC Cannon / no single win purchase. | The win is distributed across the door chain — the map *is* the win condition. |

### 5.2 The substitution rule, which is the actual lesson

He never just deletes a category — he **substitutes something the map can support**.
Corvette has no air vehicles, so the air content becomes two **bonus rounds**: Corvette
Cannonade (you man the ship's guns against Space Banshees and Seraphs) and Sabre Strike (you
fly a Sabre), plus the 2,500-point **Sabre Round conversion** that lets you *buy* the next
round as a Sabre round. Air fantasy delivered, zero air vehicles in the level.
Likewise Installation 04 has no purchasable vehicle, so the vehicle fantasy becomes the Falcon
**gunner** ride on a scripted path — "akin to Call of Duty's 'chopper gunner'" — which needs no
drivable space and no parking.

**The rule to copy: for every category the map cannot host, ship a scripted or bonus-round
version of the same fantasy instead of dropping it.**

### 5.3 Mechanics he avoided across the board

- **No Megalo.** Nothing in 21 change notes is a gametype change; every price and every gate is
  in the 7.33 GB map package. He has never shipped a price change via the `.bin`. (See
  `research/04` §7 for the proof.)
- **No `haloreach.dll` replacement**, unlike some AI-spawning Workshop mods. Workshop-safe.
- **No new BSPs.** All three maps are stock Firefight maps. No geometry authoring.
- **Co-op is explicitly second-class.** STATED known issue: "This build is largely untested for
  co-op… There will likely be issues with syncing", and "Generator Defense and Firefight VS are
  currently not supported." The Bug Report thread is dominated by co-op: hosts frozen at spawn,
  purchases registering minutes late ("buying is not working at the appropriate times… This
  caused us to not be able to buy the mac cannon at the end and thus lose the game"), the
  Engineer hard-crashing every non-host, Corvette turret dismounts flinging players into space,
  terminals rendering as the wrong objects for late joiners. **Design solo-first; treat co-op as
  a separate hardening pass.** The bank exists only because co-op broke the economy.

---

## 6. Build checklist, distilled

If you want his design on a new Firefight map, this is the shortest correct order.

1. **Pick a map with a defensible interior and one exposed landmark.** The interior holds the
   economy hub; the landmark holds the win purchase.
2. **Place one terminal per purchasable**, in two or three clusters, with the hold-to-interact
   verb matched to the item class (buy / call in / request / restore / unlock / upgrade).
   Put the bank, if you need one, on the route everyone already walks — he chose next to the
   health pack.
3. **Price off ~2,000–2,500 points per round.** Impulse 250–500, standard 750–1,000, set
   purchase 2,000–2,500, heavy 3,000–3,500, and reserve 6,000 for the one thing that would
   otherwise trivialise the map. **Then halve everything after the first real playtest**, which
   is exactly what he did within 24 hours.
4. **Gate heavies by round, not by price**, and announce the unlock with a HUD banner at the
   round boundary: "The X and Y are now available!"
5. **Make the ally purchase re-buyable** whenever the player has no allies left. He converged on
   this on both maps independently.
6. **Gate the win purchase to land around 4 rounds of income** (he used Set 2 / Round 3 / Wave 5,
   then loosened it to the start of Set 2) and put the terminal **outside** the defensible area.
7. **Give the antagonist a lose timer** so the win purchase is a race, not a formality.
8. **Reset every objective and switch state at the set boundary.** He shipped that bug twice.
9. **Keep drop-pod landing zones clear of your win vehicle's landing volume.**
10. **Fix the ally AI** — engagement distance, target reacquisition, grenade evasion,
    heavy-weapon willingness. It is the one part of his design the players reject.

---

## 7. Appendix: raw artefacts kept on disk

| Path | Contents |
|---|---|
| `research/_raw/changelog.html` | change notes page 1, entries 1–10 (2026-01-05 → 2026-03-15) |
| `research/_raw/cl_p2.html`, `cl_p3.html` | change notes pages 2–3, entries 11–21 (2025-03-28 → 2025-12-30) — **the price history** |
| `research/_raw/item.html`, `item2.html` | Workshop item page, full description and preview image URLs |
| `research/_raw/comments_all.txt` | 263 Workshop comments |
| `research/_raw/author_evidence/preview_images/img_01..22*.jpg` | the 22 Workshop preview images, downloaded |
| `research/_raw/author_evidence/ocr_*.txt` | per-frame OCR of his Corvette and Unearthed trailers, a full launch-build Unearthed playthrough (`ocr_dinofull`), and a 2026-07 current-build playthrough (`ocr_barth`) |
| `research/_raw/author_evidence/*.en.vtt.txt` | cleaned auto-transcripts of the three third-party playthroughs |
| `research/_raw/author_evidence/*.description` | YouTube descriptions, including the Exodus preview with its prices |
| `research/_raw/author_evidence/jcl2.txt`, `jcl3.txt` | reader-proxy captures of change-note pages 2–3 |
| `research/_raw/author_evidence/discussions/j_*.txt` | all four Steam discussion topics, all pages |

OCR line format is `frameIndex<TAB>text`; multiply the frame index by the sampling interval
noted in `ocr_dinofull` (2 s), `ocr_barth` (2 s), `ocr_cv` / `ocr_trun` (1 s), `ocr_d2` (0.5 s)
to get a video timestamp.
