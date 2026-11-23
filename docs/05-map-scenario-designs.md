# Firefight Evolved Expanded — Map Scenario Design Dossier

Document: `research/05-map-scenario-designs.md`
Date: 2026-11-20, **economy revised 2026-11-21**

> **REVISION 2026-11-21 — the purchase economy in §4 has been rebuilt and every scenario catalogue re-priced.**
> The original figures rested on an **unverified income estimate** (4,000–5,000 team points per round on Normal, read off the stock Score Attack achievement and flagged **[U]** at the time) and on a second-hand **30,000**-point price for the Corvette win switch. Both are now withdrawn. `research/10-author-design-system.md` §1.3 **measured** the real thing — OCR of the live score counter across a complete 21-minute playthrough of the mod — and got **≈ 900 points/minute, i.e. 2,000–2,500 a round and 7,000–8,500 a set**, about half the estimate; and §1.1 records every win purchase the author shipped as **UNKNOWN**, while his change notes show him cutting nine launch prices by 50–75% within 24 hours.
> Consequences, all applied below: marines **1,500 → 500**, ODSTs **3,000 → 750**, turret **4,000 → 750**, light vehicle **6,000 → 1,000**, strike **18,000 → 3,000**, win purchase **30,000 → 8,000** (6,000 on a fortify-first branch) with the round-5 gate kept; heavies now carry **round gates with a HUD banner at the round boundary**; a **bank** (two kiosks, 500 a press) is added to every map; and the **win terminal moves outside the defensible area** to a named exposed anchor per map (§4.4), reversing §6 item 4. Prices tagged **[A]** are the author's own shipped numbers; **[D]** are ours, placed on his rungs because he never priced that item.
Scope: engine-accurate, source-verified scenario designs for new objective-driven Halo: Reach Firefight missions in the style of The Vengeful 'Vadam's *Halo: Reach Evolved* Firefight component.

---

## 0. How to read this document (verification legend)

Every map fact below is tagged:

* **[V]** — verified against a cited source (Halopedia map article, Halopedia Firefight articles, ReachVariantTool documentation, the mod's own Steam Workshop description or author comments).
* **[U]** — **unverified**: not found in any source consulted. Treat as a design assumption that must be confirmed in-game or in the Halo: Reach Editing Kit (HREK) before it is built.

Primary sources used:

| Ref | Source |
|---|---|
| S1 | Halopedia, *Firefight* — https://www.halopedia.org/Firefight |
| S2 | Halopedia, *Firefight (Halo: Reach)* — https://www.halopedia.org/Firefight_(Halo:_Reach) |
| S3 | ReachVariantTool documentation (David J. Cobb), *Concepts → Firefight* — https://davidjcobb.github.io/ReachVariantEditor/concepts/firefight.html |
| S4 | ReachVariantTool documentation, *Firefight Settings* / *Round Settings* / *Bonus Wave Settings* — `.../editor/main_window_ff/scenario.html`, `round.html`, `bonus-wave.html` |
| S5 | Halopedia per-map articles: `Reach:Beachhead`, `Reach:Courtyard`, `Reach:Glacier`, `Reach:Holdout`, `Reach:Outpost`, `Reach:Overlook`, `Reach:Waterfront`, `Reach:Corvette`, `Reach:Unearthed`, `Reach:Installation 04` |
| S6 | Halopedia, *Campaign scoring* (Halo: Reach section) — difficulty/skull multipliers and the scoring formula |
| S7 | Halopedia, *Halo: Reach skulls* |
| S8 | Steam Workshop item 3453792163, *Halo Reach: Evolved Public Beta* — item description (official Firefight overview) |
| S9 | Steam Workshop item 3453792163 — 263 public comments, including author (The Vengeful 'Vadam) replies |
| S10 | Steam guide, Test Tube, *[Halo Reach] A closer look at Firefight waves/squads* — https://steamcommunity.com/sharedfiles/filedetails/?id=1967747082 |
| S11 | Halopedia per-map articles for the Reach **multiplayer** maps `Reach:Breakneck`, `Reach:Highlands`, `Reach:Condemned`, `Reach:Anchor 9`, `Reach:Boardwalk`, `Reach:Spire`, `Reach:Tempest` |

Raw captures are saved under `research/_raw/` (`wiki/*.html|*.txt`, `rvt_*.html`, `api1.json`, `item.html`).

---

## 1. The engine's real shape (task 6)

This is the skeleton every design below is built on. All of it is **[V]**.

### 1.1 Turn / set / round / wave

* The basic unit is the **wave**: six squads of NPCs spawn (or are delivered by dropships); the wave ends when they are dead. **[V, S3]**
* **Five waves = one round.** Specifically **one Initial Wave, three Main Waves, one Boss Wave.** **[V, S3, S4, S10]**
* **Three rounds + one optional Bonus Wave = one set.** **[V, S3, S10]**
* What multiplayer calls a "round", Firefight calls a **turn**. A turn spans an arbitrary number of sets and ends when the Spartans are defeated, the **wave limit** is reached, or the turn time limit expires. **[V, S3]**
* Wave limit is a single gametype number that *includes* bonus waves; the editor translates it into sets/rounds/waves. **[V, S4]**

### 1.2 Per-wave mechanics

* Each wave spawns **six squads of one type**. A normal squad is **4 troops**; Hunter, Brute Chieftain and Elite General squads are **1 troop**. So a standard wave is roughly **24 simultaneous enemies**, a Chieftain/Hunter wave only 6. **[V, S3, S4, S10]**
* All waves except the last in a round end when **all but three** enemies are dead. The last wave (Boss Wave) ends only when **all** are dead, and the last five survivors get waypoints. **[V, S3]**
* An empty/unsupported squad type makes the wave end after ~7–9 seconds. **[V, S3, S4]**
* If dropships are enabled, the wave cannot end until the dropships have fully left the map. **[V, S3]**
* On Boss Wave completion: **+1 extra life per Spartan**, all dead players respawn, all living players' shields refill, Hero medal. **[V, S3]**
* At the start of each round: **Weapon Drops** (UNSC heavy weapons air-dropped) if enabled, and extra lives for every round after the first. **[V, S3, S4]**
* **Bonus Wave**: ends on its **duration timer** (configurable in seconds) or if all Spartans are dead at once — not on kills. With dropships on, the dropships stay and keep delivering until the timer ends; everything spawned by the bonus wave dies instantly when it ends (hazard spawns survive). **[V, S3, S4]**
* **Iron skull must only be used on the Bonus Wave** — on normal waves it can softlock the match. **[V, S4]**

### 1.3 Spawn delivery methods available

* **Phantoms** are the standard dropship on every Firefight map; **Corvette uniquely uses Spirits** and spawns squads **behind locked doors** instead of in the open. **[V, S3, S5]**
* With dropships disabled, squads spawn "in a map-specific manner (typically just appearing out in the open)". **[V, S3, S4]**
* **Hazards** (a single on/off gametype flag) include map-specific extras: **Banshees** (Holdout), **drop pods carrying Brutes with Concussion Rifles, Grunts with Fuel Rod Guns, or Elite Ultras**, and **Wraiths**. **[V, S4]** Which hazard set a given map actually ships is listed per map in §2.
* **Ammo crates** (refill non-power UNSC weapons on touch) and **Generators** (1–3, with fail condition and choice of three spawn locations) are gametype flags. **[V, S4]**

### 1.4 Squad types available (the species palette)

Selectable per wave slot **[V, S4]**: Brutes, Brute Chieftains, Brute Infantry (Brutes+Jackals), Brute Kill Team (Brutes+Chieftains), Brute Patrol (Brutes+Grunts), Brute Tactical (Brutes+Skirmishers); Elites, Elite Airborne (jetpack Rangers), Elite Generals, Elite Infantry, Elite Patrol, Elite Spec Ops, Elite Strike Team, Elite Tactical; Engineers (**map-limited**); Grunts; Guta (**no map supports it**); Heretics / Heretic Heavy / Heretic Snipers (Elites with human weapons); Hunters, Hunter Infantry, Hunter Kill Team, Hunter Patrol, Hunter Strike Team, Hunter Tactical; Jackals, Jackal Patrol, Jackal Snipers; Skirmishers, Skirmisher Infantry, Skirmisher Patrol; None.

Not available in Firefight waves at all: **Engineers and Drones** (except as map features), **Elite Zealots and Field Marshals**. **[V, S2]** **Corvette is the only stock Firefight map that features Engineers.** **[V, S5]**

Squad Count quirk: if Squad Count is lower than the number of slots the engine reads (3 for Initial/Boss, 5 for Main), the remaining slots silently become **Brutes**. Leave defaults. **[V, S4]**

### 1.5 Skulls and scoring

* Skulls in default Firefight are **randomly activated at the beginning of every set**; in custom gametypes they are set **per round** and per bonus wave, plus up to **three Custom Skulls** (Red/Blue/Yellow) with user-defined effects and timing. **[V, S2, S4, S7]**
* Reach multipliers are **additive**, not multiplicative. Formula **[V, S6]**:
  `Points = unit base value × medal/style multipliers × (difficulty multiplier + sum of skull multipliers) × time multiplier`
* Reach difficulty multipliers **[V, S6]**: Easy **0.75×**, Normal **1.00×**, Heroic **1.25×**, Legendary **1.50×**.
* Reach skull multipliers **[V, S6, S7]**: Iron 1.2, Famine 1.2, Thunderstorm 1.2, Tilt 1.2, Mythic 1.2, Black Eye 1.1, Tough Luck 1.1, Catch 1.1, Cloud/Fog 1.1; Blind, Cowbell, Grunt Birthday Party, IWHBYD = 1.0 (no score effect).
* **Reach-specific per-unit base point values are [U]** — Halopedia publishes the per-unit table only for Halo 3/ODST (Grunt 10, Jackal 15, Brute 20, Jackal Sniper 20, Brute Captain 50, Hunter 150, Brute Chieftain 150, Ghost 100, Wraith 200, Phantom 250; death −25). Reach reuses the ODST-style Firefight medal/points pipeline **[V, S6]** but the exact Reach values were not confirmed by any source consulted. **Measure in-game before locking prices.**
* If player traits or skulls are customised to the player's *advantage*, kill scoring is disabled and the game awards **1 point per minute** instead. **[V, S2]** — This is a hard constraint on the whole purchase economy: buffing the player (more health, more ammo) kills the currency. Any player buff must be delivered as a **Custom Skull with a non-advantageous net effect**, or verified not to trip the flag.

### 1.6 Useful calibration anchors

* **MEASURED income, and it supersedes the two estimates below.** `research/10-author-design-system.md` §1.3 OCR'd the score counter out of a complete 21-minute solo Unearthed playthrough of the mod itself and got a monotone curve: 581 at 1:18, 1,239 at 4:40, 3,891 at 8:00, 5,282 at 11:42, ~8,200 at 14:29, 18,365 at 20:34. That is ≈ **900 points per minute**, and at 2.5–3 minutes a round:
  * **one round ≈ 2,000–2,500 points**
  * **one set (3 rounds + bonus) ≈ 7,000–8,500 points**
  This is a measurement of the actual mod on the actual engine, so it outranks everything else in this section. It is ~half of what §4.1 used to assume. Caveat kept honest: that run's score settings are not visible, it is the launch build, and it is solo — treat 900/min as the right order of magnitude, not a constant.
* ~~**Score Attack** achievement: 15,000 points, solo Heroic, one set → ~5,000 points per round.~~ **WITHDRAWN as a price anchor.** The achievement figure is still **[V, S2]**, but it measures *stock* Score Attack with stock scoring settings, and reading 5,000/round off it over-states this mod's real income by 2–2.5×. Use the measurement above.
* Firefight achievements: Firestarter 50,000, Blaze of Glory 200,000, Heat in the Pipe 1,000,000 in a single Firefight game. **[V, S2]**
* ~~**The mod's own price anchor**: the Corvette bridge end-trigger switch at **30,000 points** **[V, S9]**, which fixes the top of the price ladder.~~ **WITHDRAWN.** `research/10` read all 21 change-note entries across all three pages, 263 comments, the full description history and OCR of five videos, and records **every** win purchase he ever shipped — Installation 04's Evac Pelican, Unearthed's MAC Cannon, and the Corvette bridge chain — as **UNKNOWN** (§1.1). The 30,000 figure is a single second-hand comment reading, it describes a *chained* room-by-room purchase on his smallest map rather than one switch, and at 2,000–2,500 points a round it would be twelve rounds of income — i.e. unreachable inside a 16-wave match, which is precisely the failure he spent 24 hours correcting. It is not safe to anchor a ladder on it. **His real top-of-ladder evidence is a gate, not a price:** he gated Unearthed's MAC Cannon to the point his own score curve crosses ~8,000 (§1.3).
* MCC Reach Firefight supports **up to 8 players** (was 4), allows join-in-progress, and can disable AI spawns entirely. **[V, S1, S2]**

---

## 2. Map enumeration (task 1)

### 2.1 Stock Firefight maps — the complete list

Halopedia's *Firefight (Halo: Reach)* "Supported maps" section lists **ten** maps, and only ten **[V, S2]**:

Beachhead, Corvette, Courtyard, Glacier, Holdout, Outpost, Overlook, Waterfront (launch eight) + Unearthed (Defiant Map Pack) + Installation 04 (Anniversary Map Pack).

**Important correction to the candidate list in the brief:** *Breakneck, Highlands, Condemned, Anchor 9, Boardwalk, Spire* and *Tempest* are **Halo: Reach competitive multiplayer maps, not Firefight maps** **[V, S2, S11]**. They have no Firefight scenario tags, no Phantom flight paths, no AI spawn zones and no `ff*` scenario files. They are covered in §2.4 for completeness and ruled out in §3.

---

### 2.2 The eight candidate Firefight maps, in detail

Common to all eight: Phantom dropships, Weapon Drops at round start, ammo crates, 1–3 optional generators, and the full squad palette from §1.4. Species mix is a **gametype** property, not a map property, so "which species the stock game uses here" is only map-constrained for Engineers (Corvette) and Guta (nowhere). **[V, S2, S3, S4]**

#### Beachhead — `ff50_park` **[V, S5]**
* **Lore setting**: Caracalla Park, a natural park in New Alexandria, Reach; based on the final section of *Exodus*. **[V]**
* **Size / layout**: **large, asymmetrical**. Runs from a lagoon at one end, through open areas studded with boulders and trees, to a rocky wooded area. An **access road** divides lagoon from woods, running from the main **Pavilion** (player spawn) to a small central structure, which has a **bridge** to a smaller building on a hill. **[V]**
* **Verticality**: Pavilion has steps up to the spawn hallway and stairs to a **roof with a full view of the entire map**; bridge and hilltop building add a second tier. **[V]**
* **Defensible positions**: 3 strong — Pavilion roof (full map overwatch), Pavilion interior/Mezzanine (stairs chokepoint), central structure + bridge. Callouts: Pavilion, Mezzanine, Beach Road, Terrace, Bridge, Breezeway, Stage, Central Coast, Lake, Access Road, Garage, Roof. **[V]**
* **Vehicles**: ships a **drivable M12R Rocket Warthog in an open garage on the lower right of the Pavilion** — only Beachhead and Unearthed have the Rocket Hog in stock Firefight. Hazards are **Wraith and Ghost**, which proves heavy- and light-vehicle-drivable terrain along the access road and open park. **[V]** Scorpion-grade clearance on the road: **[U]** (highly likely; Wraith footprint is comparable).
* **Air sightlines**: wide open park with long open sky; Target Locator is available on surface maps. Falcon-style gunship lanes: **[U]** but geometry is permissive.
* **Drop methods used**: Phantoms into the open areas; drop-pod/Wraith/Ghost hazards. **[V]**

#### Overlook — `ff10_prototype` **[V, S5]**
* **Lore setting**: a kiva farm building in Visegrad, Reach; based on *Winter Contingency*. **[V]**
* **Size / layout**: **medium-large**, three sections — **barn**, **yard**, **enemy drop zone** — with yard and drop zone split by a **shallow river with a covered bridge** plus a narrow walkway where the river falls into a canyon. Drop zone is dressed with Covenant supply crates and roadblocks. Yard = barn courtyard (crates, hay bales, hay baler, three sheds) + a centre section running into a small forest. **[V]**
* **Verticality**: barn has **two interior levels** (upper rooms incl. a radio room with ammo boxes, lower floor) plus a **large tower reachable only by jetpack**, used for sniping. **[V]**
* **Defensible positions**: 3–4 — barn interior (stair chokepoint), barn courtyard, the covered bridge (natural kill funnel), jetpack tower (sniper perch). Both ammo crates are **inside the building**. **[V]**
* **Vehicles**: hazard is the **Wraith**, and Halopedia's own tactics section recommends commandeering it — heavy vehicles drive here. **[V]** Warthog across the river crossings: **[U]**.
* **Air sightlines**: open farmland and canyon; Target Locator explicitly useful when both Phantoms drop on the far side. **[V]**
* **Drop methods used**: **two Phantoms** into the dedicated enemy drop zone across the river; Wraith hazard. **[V]**

#### Outpost — `ff60_airview` **[V, S5]**
* **Lore setting**: Airview Base, near Sword Base and the Babd Catha Ice Shelf, partly melted by Covenant glassing; based on *The Package*. **[V]**
* **Size / layout**: **medium**, "plenty of wide open spaces" with boulders, vehicle wreckage and containers as cover. At one end a **base**, flanked by **two "Tyrant" cannons — one destroyed, one still active**. **[V]**
* **Verticality**: base has interior, **roof with a mounted Turret**, and a single stairway to that roof; health packs on the first floor and rear. **[V]**
* **Defensible positions**: 1 dominant — the **"Deck"** building; "all enemies except Skirmishers and Sangheili Rangers have to climb the stairs". Combat barrier on the rooftop front, wall beside the staircase shields from Phantom turret fire, ammo crate on the building's left wall. **[V]**
* **Vehicles**: the only vehicle dropped on the map is the **Ghost**, which is also the hazard, and it "can move around fast in the large map". **[V]** Warthog/Scorpion room: **[U]** — open ground suggests yes, but no source confirms a drivable UNSC vehicle here.
* **Air sightlines**: wide open glacial hillside, long lines; Target Locator recommended against the Ghost. **[V]**
* **Drop methods used**: Phantoms (their turret fire is called out as a threat to the Deck roof); Ghost hazard. **[V]**

#### Holdout — `ff70_holdout` **[V, S5]**
* **Lore setting**: **Platform Delta**, a landing platform beside the ship-breaking yards of Asźod, Reach, with the **UNSC Pillar of Autumn visible in the background**; based on the final section of *The Pillar of Autumn*. **[V]**
* **Size / layout**: **small**. Four sections — a **middle complex** of buildings and pads, **two drop zones** left and right, and a **rear terrace** linking the right drop zone to the complex. **[V]**
* **Verticality**: strongest of the stock set. Spawn building has **three levels** (interior with ammo caches, rooftop with a small sniping structure, basement with an ammo cache and access to the platform underside). Rooftop → two ramps → intermediate platform → ramps to the right area and the **middle platform**, which has a central structure containing a **Turret** and three ramps to the left drop zone and **two helipads** (one raised, one lower). There is also traversable space **beneath** the centre platform. **[V]**
* **Defensible positions**: 4+ — spawn rooftop, spawn basement, the turret structure on the central platform, the rear terrace ("a great sniping position when enemies push in too far"). **[V]**
* **Vehicles**: no ground vehicle is documented; the hazard is the **Banshee**. **[V]** Warthog/Scorpion viability: **[U]**, and the small, multi-level, ramp-linked platform geometry argues **against** ground armour. **Helipads exist**, which makes air insertion fiction cheap and legible.
* **Air sightlines**: open sky over the platform and the Autumn; Longsword flyovers appear in stock map imagery. Banshee hazard proves air pathing exists. **[V]**
* **Drop methods used**: Phantoms into two flanking drop zones; **Banshee** hazard. **[V]**

#### Glacier — `ff60_icecave` **[V, S5]**
* **Lore setting**: an **underground glacial cavern beneath Sword Base** in the Babd Catha Forerunner complex, containing a Forerunner structure; from *The Package*. **[V]**
* **Size / layout**: **medium, asymmetrical**. A main spawn building plus snowy pathways separated by jagged rock: a **centre path**, a **right circular path** that leads to **two bridges**, and a **left path encircling an inaccessible building**. Rocks around the base make heavy cover. **[V]**
* **Verticality**: the spawn building can be **climbed with a jetpack** for an excellent sniping position; the two bridges on the right path add a tier. Callouts: Base, Hillside, Rampart, Upper Pass, Landing. **[V]**
* **Defensible positions**: 2–3 — base interior/awning, rock ring around the base, bridges/Upper Pass.
* **Vehicles**: hazards are **Wraith and Ghost** — both heavy and light vehicles path here. **[V]**
* **Air sightlines**: **none — the map is underground, and the Target Locator does not appear for that reason**. **[V]** This is a hard, verified constraint: no Pelican, no Falcon, no orbital support fiction on Glacier.
* **Special**: fixed weapon holder with a **Spartan Laser**, plus racks for a **Sniper Rifle** and a **Rocket Launcher**. **[V]**
* **Drop methods used**: Phantoms into the cavern paths; Wraith and Ghost hazards. **[V]**

#### Waterfront — `ff30_waterfront` **[V, S5]**
* **Lore setting**: a **pumping station beside the water near the Ütközet dam**, Viery Territory, Reach, **at night**; based on *Nightfall*. **[V]**
* **Size / layout**: **medium-small**, industrial. Buildings arranged in a **ring around a central opening**, with several ramps leading down to **water basins where the Covenant are dropped**. The complex connects to land by a **covered bridge** that "offers great protection from airborne enemy fire". **[V]**
* **Verticality**: moderate — ring of buildings above, basins below, covered bridge. Callouts: Circle, Gully, Shed, House, Beach, Pump, Tunnel. **[V]**
* **Defensible positions**: 2–3 — the central building cluster (the map "forces players to defend the middle buildings"), the covered bridge, the Pump/Tunnel interiors.
* **Vehicles**: **none documented; [U]**, and the ring-of-buildings + ramps-to-basins geometry argues against armour. Do not design around a Scorpion here.
* **Air sightlines**: **Phantoms drop enemies in a full 360° circle around the map** — the sky is wide open, but so is every flank. **[V]**
* **Drop methods used**: Phantoms, 360° around the ring; hazard is **Jackal snipers on the hill**. **[V]**

#### Courtyard — `ff20_courtyard` **[V, S5]**
* **Lore setting**: the open courtyard and loading area outside **Sword Base**, near the Babd Catha Ice Shelf; from *ONI: Sword Base*. **[V]**
* **Size / layout**: **small**. Two main areas split by a **central bridge**. The left side is crowded with boxes and containers and holds **two enemy spawn rooms**; the right side is larger and more open. Player spawn is inside the ONI building with two exits — one onto an upper outdoor **terrace**, one down **under the main bridge**. Terrace is large with ramps to left, right and centre; an upper thin terrace runs along the left outskirts. **[V]**
* **Verticality**: good for its size — ONI building, terrace tier, bridge, under-bridge route.
* **Defensible positions**: 2 named by Halopedia — the **bridge ends on the second floor**, and the **elevated Terrace** (close to an ammo crate, overlooks Landing, only two entrances, but far from health packs). **[V]**
* **Vehicles**: only a **Forklift** — "the only Halo: Reach Firefight level to include the Forklift, or any civilian vehicle". No combat vehicle documented; **[U]** for Warthog, and the small two-pocket layout argues against it. **[V] for the Forklift.**
* **Air sightlines**: enclosed by Sword Base structures; Target Locator is usable (Halopedia recommends it), so sky access exists. **[V]**
* **Drop methods used**: Phantoms, **plus two map-built enemy spawn rooms on the left side** — the only stock map besides Corvette with door-style spawns. **[V]**

#### (Reference) The three maps already covered by the mod
* **Corvette** `ff45_corvette` — smallest Firefight map, circular hangar of the *Ardent Prayer*; **Spirits, not Phantoms**; squads spawn **behind locked doors**; the only map with **Engineers**; a Plasma Cannon on the upper walkway; Wraiths occasionally deployed despite the size; ordnance canisters at round start. **[V, S5]** Mod scenario: board, secure hangar, buy the path to the bridge **room by room** (price per door **UNKNOWN** — the "30,000 for the bridge switch" figure once cited here from S9 is withdrawn; see §1.6 and `research/10` §1.1, which records every win purchase he shipped as UNKNOWN), Mystery Box **250**, Shade turret unlock-then-upgrade (Fuel Rod 2,000, AA 6,000), Sabre Round conversion 2,500, inter-round objectives, Corvette Cannonade and Sabre Strike bonus rounds. **[V, S8, S9]**
* **Unearthed** `ff_unearthed` — medium-large BXR titanium mine; factory (interior, courtyard, crane) + two large drop zones joined by a ring road; **Rocket Warthog in the garage**, a **vehicle depot** in the west drop zone; the **only map where the Target Locator has three shots** "due to the map's slightly heavier emphasis on vehicular combat"; hazards Wraith, Ghost, Jackal snipers. **[V, S5]**
* **Installation 04** `cex_ff_halo` — Alpha Halo cliffside; **the only stock map with friendly AI (four ODSTs)**; the four tower ODSTs **have no pathfinding and stand still**, while **Pelican-delivered ODST reinforcements are correctly scripted to follow the player**; ODSTs will only board a **Warthog if it is spawned in by Pelican**. **[V, S5]** This is the single most important technical precedent in the whole dossier (see §6).

### 2.3 Why the multiplayer maps are a different category

| Map | Stock role | Players | Vehicles in MP sandbox | Firefight support |
|---|---|---|---|---|
| Breakneck | BTB, New Mombasa Section 21 construction site | 8–16 | Warthog (incl. Gauss), Ghost, Banshee **[V, S11]** | **None** |
| Highlands | CTF/Assault/Stockpile, Highland Mountains training preserve | 8–16 | Warthog, Falcon, Banshee **[V, S11]** | **None** |
| Condemned | Slayer, Orbital Gamma Station; circular, five multi-floor areas, low-grav core with shield doors | 6–12 | none (Banshee only referenced) **[V, S11]** | **None** |
| Anchor 9 | CTF/Assault/Stockpile, orbital dockyard; symmetrical, exterior low-grav walkway | 2–8 | none **[V, S11]** | **None** |
| Boardwalk | Arena, New Alexandria concourse | 4–12 | Mongoose; Falcon referenced **[V, S11]** | **None** |
| Spire | Invasion, Szurdok Ridge; huge beach + tower, Spartan offence | — | **Falcon, Banshee, Warthog [V, S11]** | **None** |
| Tempest | Noble Map Pack, Installation 04 weather spire; beach/cliffs/river, man cannons, aircraft-EMP beam | 8–16 | — **[V, S11]** | **None** |

These lack Firefight scenario scripts, AI spawn zones and Phantom paths entirely. Converting one is a *map port*, not a *scenario*.

---

## 3. Ruling out and ranking (task 2)

**Ruled out — already covered by the mod**: generic Firefight, **Corvette**, **Installation 04**, **Unearthed**. **[V, S8]**

**Ruled out — not Firefight maps**: Breakneck, Highlands, Condemned, Anchor 9, Boardwalk, Spire, Tempest (§2.3). Highest-potential future ports, for the record: **Spire** (already has Warthog/Falcon/Banshee and a huge vertical objective), **Highlands** (vehicle-scale, UNSC base fiction), **Condemned** (station-interior siege). All three would need new AI spawn volumes, dropship paths and `survival_mode` scripting.

**Ranking of the seven eligible maps** for a bespoke objective scenario. Criteria: strength of a canonical objective in the fiction; number of distinct defensible positions worth buying hardware for; verified vehicle terrain; air access for Pelican/Falcon set pieces; drop-zone geometry that escalation can lean on.

| Rank | Map | Score rationale |
|---|---|---|
| **1** | **Beachhead** | Large, verified vehicle terrain (Wraith *and* Ghost hazards), a stock **Rocket Warthog**, 3 real strongholds, a roof with total map overwatch, a civilian-evacuation premise straight out of *Exodus*, wide sky for air set pieces. Everything the catalogue wants to sell has somewhere to go. |
| **2** | **Overlook** | Medium-large, Wraith-drivable, a dedicated enemy drop zone across a **river with one covered bridge** — the single best natural chokepoint in Firefight — plus a two-storey barn and a sniper tower. Objective fiction (the Visegrad relay/first contact) is the strongest in the game. |
| **3** | **Outpost** | Has a **built-in objective object**: two "Tyrant" AA cannons, one active and one wrecked. Roof turret, single-stair stronghold, open ground for the Ghost. Repair-the-gun / hold-the-gun writes itself. |
| **4** | **Holdout** | Best verticality (3-level spawn building, central turret platform, two helipads, under-platform routes) and the best lore stakes in the series — Platform Delta with the *Pillar of Autumn* on the horizon. Small, so sell infantry and air, not armour. |
| **5** | **Glacier** | Distinct: underground, **no Target Locator and no air support possible [V]**, Forerunner structure, fixed Spartan Laser, Wraith/Ghost paths. Forces a different catalogue (ground armour + bodies, no Pelican), which is exactly what a six-mission set needs for variety. |
| **6** | **Waterfront** | Night, industrial, **360° Phantom drops** — a true all-round siege, the only one. Ring of buildings with basin approaches. Penalty: medium-small and no verified vehicle room, so the catalogue is infantry/turret/one-shot heavy. |
| 7 | Courtyard | Strong fiction (ONI, Halsey's data) and **two map-built enemy spawn doors** to seal — but small, no combat vehicle, and only two camping spots. Hold as a stretch mission; see §7 for a sketched premise. |

The six designed below are ranks 1–6.

---

## 4. The shared purchase economy (task 4)

### 4.1 Earnings model — **CORRECTED 2026-11-21, measurement beats estimate**

**What this section used to say, and why it was wrong.** The table below originally derived **4,000–5,000 team points per round on Normal** from the stock Score Attack achievement, and flagged itself **[U] — must be measured in-game before prices ship**. The measurement has now been done, on the mod itself rather than on stock Firefight, and it refutes the estimate: `research/10-author-design-system.md` §1.3 OCR'd the live score counter out of a complete 21-minute solo Unearthed playthrough and recovered ≈ **900 points per minute**, i.e.

> **one round ≈ 2,000–2,500 points · one set ≈ 7,000–8,500 points**

Every price in §4.2 was built on the old figure and was therefore **3–6× too expensive**; the whole ladder has been rebuilt below. The old table is kept here, struck through, because the correction is the point:

| Difficulty | Live skulls | Multiplier | ~~Est. **team** score per round~~ | ~~Est. per set~~ |
|---|---|---|---|---|
| Normal, set 1 | 0–1 | 1.0–1.2 | ~~≈ 4,000–5,000~~ → **≈ 2,000–2,500** | ~~≈ 14,000–17,000~~ → **≈ 7,000–8,500** |
| Normal, set 2+ | 2–3 | 1.2–1.6 | ~~≈ 5,000–7,000~~ → **≈ 2,500–3,000** | ~~≈ 18,000–24,000~~ → **≈ 9,000–11,000** |
| Legendary, set 1 | 0–1 | 1.5–1.7 | ~~≈ 6,000–8,000~~ → **≈ 3,000–3,500** | ~~≈ 20,000–27,000~~ → **≈ 10,000–12,000** |
| Legendary, set 2+ | 3–4 | 1.8–2.2 | ~~≈ 8,000–11,000~~ → **≈ 3,500–4,500** | ~~≈ 28,000–36,000~~ → **≈ 13,000–16,000** |

The corrected column is the measured ~2,000–2,500 Normal baseline scaled by the verified additive multipliers **[V, S6, S7]**; the multiplier arithmetic was never the problem, the base was. Prices are still set off the **Normal set-1** figure, deliberately: price for the worst-off player, let difficulty income be upside.

**Independent corroboration from the author's own behaviour.** Within 24 hours of release he cut nine prices by 50–75%, every single one downward — ODSTs 2,000→750, Sentinel Hack 3,000→1,000, Falcon 4,000→3,000, Scorpion 5,000→2,500, Gauss 3,000→2,000, Warthog 1,500→1,000, Marines 1,000→500, Base Power 750→350, Overshield and Active Camo 750→500 (`research/10` §1.2, all STATED in his change notes). Only one price ever rose on its own merits (the Scorpion, 2,500→3,500, paired with a buff) and one emplacement was doubled as a nerf (the Corvette AA Shade, 3,000→6,000). A designer who halves nine prices in a day had pitched them off an income assumption 2–4× too high — the same mistake this dossier made.

Bonus waves are the volatility: an unbounded dropship-fed bonus wave with the score-neutral skulls (Grunt Birthday Party, Cowbell, IWHBYD at 1.0×) plus Thunderstorm/Catch can add perhaps 1,500–3,000 in 90 seconds. Treat the bonus wave as the player's "savings event" — with the bank (§4.3 rule 6) it is what gets them over the line for a win purchase.

**Design target**: a reinforcement squad affordable **every round and usually twice**; a turret on reflex; one set-tier item per set; the win purchase at **about four rounds of income**, gated to round 5.

### 4.2 The single score-cost scale — **REBUILT on the author's real prices**

Anchored on **the prices the author actually shipped after his own playtest corrections**, laid over the measured ~2,000–2,500 points a round. The rung structure is his (`research/10` §1.3): impulse ≈ ⅓ of a round, standard ≈ ½ a round, set purchase ≈ one round, heavy ≈ 1.5 rounds, win ≈ 4 rounds, with 6,000 reserved as a punitive rung he used exactly once. Everything is a multiple of 250.

Evidence tag on every row: **[A]** = a price he shipped, post-correction. **[D]** = he never priced this item; we placed it on his rung. Do not quote a **[D]** number as his.

| Rung (share of a round) | Item class | Cost | Gate | Evidence |
|---|---|---|---|---|
| Impulse (⅕) | **Marine / trooper reinforcement squad** | **500** | none, always re-buyable | **[A]** Unearthed Marines 1,000→500 |
| Impulse (⅓) | **ODST reinforcement squad** | **750** | none, always re-buyable | **[A]** I04 ODSTs 2,000→750 |
| Impulse (⅓) | **Machinegun turret**, crewed | **750** | none | **[A]** "buy Machinegun Turret (750 points)", both his maps, never gated |
| Impulse (⅕) | **Bank kiosk**, deposit or withdraw | **500** per press | none | **[A]** his kiosks moved 200→500 |
| Standard (½) | **Map state**: barricade, seal ramps, unlock a route | **1,000** | none | **[A]** rung — Medium Weapon Rack 1,000 |
| Standard (½) | **Light vehicle** (Ghost only — see §4.3 rule 7) | **1,000** | **round 2** | **[A]** Rocket Warthog 1,500→1,000, "not available until Round 2" |
| Standard (½) | **Turret variant upgrade** (rocket) | **1,000** | round 2 | **[D]** his only priced upgrades are vehicle-tier swaps at 2,000 |
| Standard (½) | **Specialist ally team** (counter-sniper pair) | **1,000** | none | **[D]** one rung above a plain squad |
| Set (1 round) | **Set-tier item**: AA battery, repair a map objective | **2,000** | **round 3** | **[A]** rung — Gauss upgrade 2,000, Fuel Rod Shade 2,000 |
| Heavy (1.5) | **One-shot strike / barrage** | **3,000** | **round 3** | **[D]** his heavy rung — Falcon gunner run 3,000, Scorpion 3,500 |
| **Win (4 rounds)** | **WIN purchase** (extraction, firing solution, uplink, charges) | **8,000** (6,000 on a fortify-first branch) | **round 5** | **[D]** from his *gate*, not his price: every win purchase he shipped is UNKNOWN, but he gated the MAC Cannon to where his score curve crosses ~8,000 |
| Punitive (a set) | reserved — nothing in this pack is priced here | 6,000 | — | **[A]** AA Shade 3,000→6,000, the one thing he decided was overpowered |

**Deleted tiers, and why.** T3+ vehicle upgrade, T4 heavy vehicle and T4 air ride are gone — not re-priced, *removed* — because `src/hsc/fe_reinforcements.hsc` §2a only sells a chassis the map's own stock hazard set already spawns and moves, which on these six maps means a Ghost and nothing else. T5 at 18,000–20,000 collapses into the 3,000 heavy rung. T6 goes 30,000 → 8,000.

**Sanity check on the new curve** (Normal, ~2,250 a round, cumulative: 2.3k, 4.5k, 6.8k, +bonus ≈ 8.8k, 11k, 13.3k, 15.6k). A team that buys a squad every round (500) plus a turret (750) and still banks ~1,000 a round clears **8,000 banked around round 6–7**, i.e. early-to-mid set 3 — and clears it in set 2 if they skip a set-tier item or cash a good bonus wave. The round-5 gate therefore binds only on Legendary or on a greedy saver, which is exactly its job: **difficulty raises tension, not speed.** Compare the old ladder, where 30,000 was twelve rounds of income and the win was mathematically unreachable inside the 16-wave match the scenarios are built for.

**If play proves an item overpowered, raise that one price — do not raise the ladder.** That is what he did (Scorpion 2,500→3,500 with a buff; AA Shade 3,000→6,000 with an overheat). Start cheap and correct upward on evidence.

### 4.3 Economy rules that apply to all six scenarios

1. **Marines and ODSTs are always the two cheapest items on the board**, at 500 and 750, and are always purchasable in every round including the bonus wave. Non-negotiable. At a fifth and a third of a round's income they are meant to be bought on reflex, repeatedly — this is the feature the whole pack exists for, and the author converged on the same rule from the other direction: three separate change notes make the ally switch respawn whenever the player runs out of allies, because "a one-shot ally purchase is a trap" (`research/10` §1.2).
2. Reinforcements are **capped by living count, not by purchases** (max 8 friendly actors / 2 squads alive) — see §6 for why.
3. Prices are **flat across difficulties**; difficulty changes income, not cost. The round gates absorb the difference.
4. **Never sell a player buff** (health, damage, ammo) as a plain trait change — advantageous traits switch Firefight scoring to 1 point/minute and destroy the currency **[V, S2]**. Sell *units, hardware and map state* instead; deliver any buff as a Custom Skull whose net effect is not player-advantageous, and verify score still accrues.
5. Refund nothing. Let a destroyed Ghost hurt; the author's players already report vehicles respawning feels "weird" with one-use abilities **[V, S9]**.
6. **Every map carries a bank: two kiosks, 500 a press, deposit and withdraw.** Adopted wholesale from the author, who shipped it one day after launch with his reason STATED: "Added a banking system… This should help achieving win conditions in co-op easier", then moved the step 200→500 three weeks later because 200 needed too many presses and was spammable (`research/10` §1.2). Banked points are deducted from the live score and held outside it, so they cannot be spent on marines by accident and the 8,000 win purchase becomes a plan instead of a lucky streak. Site the kiosks on the route players already walk — his sit "next to the health pack" on I04 and "near the base power switch" on Unearthed; ours sit beside `ammo_crate0`. **The bank balance must not be reset at a set boundary** (he shipped the "state did not reset at the set boundary" bug twice, so every *other* purchase global does need an explicit per-set teardown — the bank is the one exception).
7. **Heavies unlock by round number, not by price alone, and the unlock is announced by a HUD banner at the round boundary.** Also his: Warthog and Gauss upgrade at Round 2, Scorpion and Auto Turret at Round 3, announced verbatim as "The Warthog and Gauss upgrade are now available!" — and his 0.1.6 note explains why the banners had to exist at all ("HUD messages for important events… to make objectives more clear ingame"). An unannounced gate reads as a bug. Each scenario script now carries a `*_gates` script that fires one banner per gate on the round boundary.
8. **The win-purchase terminal goes OUTSIDE the defensible area** — see §4.4.

### 4.4 Where the win purchase is bought — the exposed anchors

The author's most instructive placement decision (`research/10` §3.2): on Unearthed the whole routine economy is crammed inside the defensible building so it is usable without leaving cover, and then the **MAC Cannon is deliberately exiled to the Crane**. The run to the Crane under the cruiser's barrage, with the glassing timer burning, *is* the climax. In the same patch he pulled friendly turrets closer to the base and pushed Covenant drop-pod zones further out — he tightens the friendly footprint, widens the hostile one, and puts the win on the far side of the gap.

So: **routine economy beside `ammo_crate0`; win terminal at the map's exposed named anchor.** Every anchor below is a **named object read out of the shipped script** — no invented coordinates. Positions are **[TAG]**: read them in Sapien, and offset each volume clear of any pod landing footprint (`research/10` build checklist item 9).

| Map | Win purchase | Exposed anchor | Why that object |
|---|---|---|---|
| **Beachhead** `ff50_park` | Pelican dust-off | **`ps_wraith/p2`** (one of `ps_wraith/p0`–`p3`), kept outside `tv_wraith_01` / `tv_wraith_02` | `ps_wraith` is the Wraith's own bombardment point set, driven by `cs_shoot_point` in `cs_wraith_shoot` **[V]** — Bungie labelled the shelled ground for us. The `tv_wraith_*` volumes are where the Wraith is called off, i.e. shelter; the terminal must be outside them. |
| **Overlook** `ff10_prototype` | Relay uplink | **`sq_sur_drop_05`**, the far bank | Every Covenant drop lands across the river and the covered bridge is the **only** crossing **[V]**. The five named pod lanes `sq_sur_drop_01`–`05` are the far-bank ground. The cleanest barrage-run of the six. |
| **Outpost** `ff60_airview` | Tyrant firing solution | **`sc_bfg_destroyed`**, the wrecked AA cannon | Map-unique named scenery, made invulnerable at `ff60_airview.hsc` L19–20 **[V]** — a terminal host that cannot be destroyed, on the far flank from the Deck's stair chokepoint, with the Ghost hazard and four live Jackal snipers on the ground between. Best fiction fit in the pack: buy the solution at the dead gun, carry it to the live one. |
| **Holdout** `ff70_holdout` | Launch clearance | **`sq_sur_drop_04`**, the right-hand drop zone, under the `ps_banshee_02` strafing lane | The economy lives in the three-level spawn building and on the central platform; the two flanking Covenant drop zones are the exposure **[V]**. Do **not** anchor on a `ps_banshee_*` point — those are air waypoints, not ground. |
| **Glacier** `ff60_icecave` | Demolition charges | **`ps_wraith/p1`**, explicitly **outside `tv_wraith`** | The best-evidenced exposure anywhere in the pack, because Bungie labelled both halves: the fragments gate the Wraith shoot tasks on `(not (volume_test_players tv_wraith))` **[V]** — so `tv_wraith` is *proven* shelter and a `ps_wraith` point outside it is *proven* shelled ground. Fictionally the shaft the Covenant came down, which is what the charges are rigged on. |
| **Waterfront** `ff30_waterfront` | Station scram | **`sq_sur_drop_03`**, down in the basins, clear of `tv_cliff_fall_left` / `_right` | The Covenant are dropped into the water basins below the ring while the economy sits up in the buildings **[V]**; five named pod lanes mark the basin floor. Note the trade-off: "seal the basin ramps" makes the win *cheaper* and the run *longer* — verify a sealed ramp does not make the terminal unreachable, or the discount is a trap. |

This **reverses §6 item 4's old advice** ("place the win interactable at or next to the player's own stronghold"), which was written before his placement was recovered. His own answer to the complaint about not reaching the MAC in time was a **looser round gate**, not a closer terminal: he moved the gate from Set 2 / Round 3 / Wave 5 to the start of Set 2 and left the Crane exactly where it was.

---

## 5. Scenario designs (task 3)

Each scenario assumes: wave limit set to **16 waves** (= one set of 3 rounds + bonus, then a second set of 3 rounds + bonus, with the final round reserved for the finale), Phantom dropships on, hazards on, weapon drops on, ammo crates on, generators off unless stated.

---

### 5.1 BEACHHEAD — *"LAST BUS OUT OF NEW ALEXANDRIA"*

**Premise.** Caracalla Park is the last civilian collection point in this district of New Alexandria; the evac buses staged on Beach Road left without their rearguard. A Covenant lance has pushed into the park from the lagoon to cut the Pavilion off from the highway, and the UNSC needs the Pavilion held long enough for the last three transports to lift from the Stage. Noble-adjacent survivors — a Spartan and whatever Army troopers can be rallied — hold the Pavilion, feed the transports, and call the final dust-off from the Roof.

**Starting setup.** 1–4 players (MCC up to 8). Players spawn in the Pavilion hallway with **Assault Rifle + Magnum**, 2 frags, no armour ability until bought. **Two Army Troopers** (free, pre-placed) hold the Mezzanine stairs. The **Rocket Warthog is in the garage and drivable from wave 1** **[V]**, deliberately: it will die, and the player will have to buy its replacement.

**Trigger.** Walking out onto the Terrace (or 45 s elapsed) triggers a Covenant corvette overflight that drops the first Phantom on the Lake side and locks the access road with a Wraith hazard. A UNSC voice assigns the three-transport objective and opens the purchase board at the Pavilion radio.

**Escalation.**
| Round | Initial Wave | Main Waves | Boss Wave | Notes |
|---|---|---|---|---|
| 1 | Grunts (Phantom, Lake) | Jackal Patrol, Grunts, Skirmisher Patrol | Elites | Transport 1 lifts at end of round 1. |
| 2 | Brute Patrol | Brute Infantry, Skirmishers, Elite Patrol | Brute Kill Team | **Ghost hazard** on the access road. Thunderstorm on. |
| 3 | Elite Tactical | Elite Infantry, Heretics, Brute Tactical | Hunter Patrol | **Wraith hazard** parks on Beach Road; Transport 2 lifts. |
| Bonus 1 | Grunts, dropships on, 90 s | — | — | Grunt Birthday Party + Cowbell (score-neutral) + Catch. |
| 4 | Elite Airborne (jetpack Rangers onto the Roof) | Brute Kill Team, Elite Spec Ops, Heretic Snipers | Hunters | Roof is no longer safe; Catch + Tough Luck. |
| 5 | Elite Strike Team | Hunter Tactical, Brute Kill Team, Elite Spec Ops | Brute Chieftains | Second Wraith. Mythic on. |
| 6 | Hunter Kill Team | Elite Strike Team ×3 | Elite Generals | Finale round: Transport 3 loading. |

**WIN.** Purchase **PELICAN DUST-OFF — 8,000** (gated: not purchasable before round 5) **at the exposed terminal on `ps_wraith/p2`, out on the Wraith's bombardment ground** (§4.4), then survive **120 s** on the Pavilion Roof while the Pelican comes in. Score keeps accruing during the hold, and the hold is the Iron-skull-free final stand.

**LOSE.** Either (a) all Spartans dead with no lives left (standard), or (b) **the Pavilion is overrun**: if two or more generators — dressed as transport power couplings on the Stage — are destroyed, the last transport burns on the pad. Use Generator Count 2, fail condition "lose all". Hard backstop: if the Pelican has not been purchased by the **end of round 8 (wave 16)**, the district is glassed and the match is lost.

**Purchase catalogue.**
| Item | Cost | Gate | Notes |
|---|---|---|---|
| **Army/Marine reinforcement squad** (3, AR + DMR) | **500 [A]** | — | Always re-buyable. Spawns at the Mezzanine. |
| **ODST squad** (4, 1 rocket, 1 shotgun) | **750 [A]** | — | Drop pod beside `ammo_crate0`. |
| Machinegun turret, Pavilion Terrace or Bridge | 750 [A] | — | Two anchor points; one turret at a time. |
| Turret upgrade (rocket variant) | 1,000 [D] | R2 | |
| Ghost (player-driven) | 1,000 [A] | R2 | Price and gate both taken from his Rocket Warthog. |
| Orbital strike on the access road | 3,000 [D] | R3 | His heavy rung; he never priced a strike. |
| Bank kiosk, deposit or withdraw | 500 [A] | — | Beside `ammo_crate0`. |
| **PELICAN DUST-OFF (win)** | **8,000 [D]** | R5 | Bought at `ps_wraith/p2` — outside the stronghold (§4.4). |

Removed, not re-priced: Rocket Warthog, Gauss upgrade and the Falcon gunner ride (no shipped script on any of the six maps spawns or moves a wheeled vehicle or any UNSC aircraft — `src/hsc/fe_reinforcements.hsc` §2a).

**Technical risks.**
* Falcon gunner ride needs a flight path over a *large* map — Beachhead has the open sky for it but no stock aircraft, so flight paths are new content. **[U]**
* Scorpion is deliberately **not** sold: only Wraith/Ghost terrain is verified, and the access road's width for a Scorpion is **[U]**.
* Friendly AI driving the Rocket Warthog is a known failure mode: the author's players report Marines in a Scorpion not firing and troopers in a transport Warthog not shooting **[V, S9]**. Keep bought vehicles player-driven; let AI ride as passengers only.
* Two generators on the Stage sit in the open part of the park; verify Phantom drop paths do not spawn squads on top of them.

---

### 5.2 OVERLOOK — *"VISEGRAD RELAY, HOUR ZERO"*

**Premise.** The Visegrad relay has gone dark and the farm above it is the only defensible ground within ten kilometres. A Covenant advance force — the same kind of recon lance that opened the invasion — is pushing up from the river to take the farm as a staging point for the dig site below. A trooper fireteam and one Spartan have to hold the barn, keep the relay's uplink generator alive, and get a full data burst out to Sword Base before the Covenant bring heavy armour across the only bridge.

**Starting setup.** Players spawn in the upper barn (the campaign entry point) with **DMR + Magnum**, 1 frag. Two Army Troopers pre-placed in the barn courtyard. Both ammo crates are inside the barn **[V]**, which deliberately makes the barn the economic centre of the map.

**Trigger.** Interacting with the **radio in the upper barn room** **[V]** starts the uplink and the first Phantom drops into the dedicated enemy drop zone across the river.

**Escalation.**
| Round | Initial | Main | Boss | Notes |
|---|---|---|---|---|
| 1 | Grunts | Jackal Patrol, Grunts, Skirmisher Patrol | Elite Patrol | All drops land across the river; the covered bridge is the only crossing. |
| 2 | Skirmishers | Brute Patrol, Jackal Snipers, Grunts | Elites | Jackal Snipers take the far ridge; Catch on. |
| 3 | Brute Infantry | Elite Patrol, Brute Tactical, Skirmisher Infantry | Brute Kill Team | **Wraith hazard** crosses to the yard — the "armour on the bridge" beat. |
| Bonus 1 | Skirmishers, 90 s | — | — | Skirmisher bonus wave (the arcade-playlist precedent **[V, S2]**). |
| 4 | Elite Airborne | Elite Infantry, Heretics, Brute Kill Team | Hunter Patrol | Jetpack Rangers bypass the bridge entirely and hit the jetpack tower. |
| 5 | Elite Tactical | Hunter Tactical, Elite Spec Ops, Brute Kill Team | Elite Generals | Second Wraith; Mythic + Thunderstorm. |
| 6 | Hunter Kill Team | Elite Strike Team ×3 | Brute Chieftains | Uplink finale. |

**WIN.** Purchase **FULL DATA BURST / RELAY UPLINK — 8,000** (round 5 gate) **at the exposed terminal on the far bank, `sq_sur_drop_05`, across the covered bridge** (§4.4), then protect the uplink for **150 s** while it transmits. Fortify-first branch: **6,000** if the players bought and still hold the **bridge barricade**.

**LOSE.** Generator Count 1 (the uplink generator in the barn's lower floor), fail condition "lose all" — if the Covenant destroy it, the mission is lost regardless of score. Backstop: wave 16 with no uplink purchased = relay lost.

**Purchase catalogue.**
| Item | Cost | Gate | Notes |
|---|---|---|---|
| **Marine squad** (3) | **500 [A]** | — | Always re-buyable. Barn lower-floor door. |
| **ODST squad** (4, 1 sniper, 1 grenade launcher) | **750 [A]** | — | Drop pod into the barn courtyard. |
| Machinegun turret, barn courtyard or bridge mouth | 750 [A] | — | Bridge mouth is the dominant anchor. |
| Bridge barricade (map state: closes the covered bridge) | 1,000 [A] | — | Enables the 6,000 win branch. |
| Bank kiosk, deposit or withdraw | 500 [A] | — | Beside `ammo_crate0` in the barn. |
| **RELAY UPLINK (win)** | **8,000 [D]** / 6,000 with barricade | R5 | Bought across the river at `sq_sur_drop_05` (§4.4). |

Removed, not re-priced: Rocket Warthog, Gauss upgrade and Scorpion — Overlook names no Ghost squad and has no `ps_wraith` at all, so it sells no vehicle (`fe_reinforcements.hsc` §2a). This leaves it the shortest board of the six, with the win as its only gate.

**Technical risks.**
* Scorpion turning circle in the farmyard and over the covered bridge is **[U]**. Verify before shipping; fall back to Gauss Hog if it snags.
* The jetpack tower is a position **the AI cannot reach** — great for the player, but an auto turret placed there would trivialise waves. Do not offer a turret anchor on the tower.
* Elite Airborne squads exist specifically to punish the tower; confirm their jetpack pathing actually reaches it, or the counter-play never lands. **[U]**
* The uplink generator inside the barn risks the stock generator-AI behaviour where enemies prefer the generator over players; verify they still path up the barn stairs.

---

### 5.3 OUTPOST — *"TYRANT"*

**Premise.** Airview Base's twin anti-air "Tyrant" cannons are the only thing that can clear the sky over the Babd Catha shelf for the extraction convoy. One cannon is scrap; the other still has a firing solution and no crew. The Covenant know it, and they are landing infantry on the glassed hillside to kill the gun before it can engage the Phantom flotilla overhead. Hold the Deck, feed the gun, and use it.

**Starting setup.** Players spawn inside the base with **Assault Rifle + Magnum**; the **roof Turret is live from the start** **[V]**; three Marines pre-placed, one on the roof, two at the stairs. The active Tyrant cannon is the mission object; the wrecked one is a purchasable repair.

**Trigger.** Mounting the roof turret or 60 s elapsed. The first Phantom comes in low over ONI Road and the gun's targeting console unlocks the purchase board.

**Escalation.**
| Round | Initial | Main | Boss | Notes |
|---|---|---|---|---|
| 1 | Grunts | Grunts, Jackal Patrol, Skirmisher Patrol | Elites | Open ground approach; the single stairway holds easily. |
| 2 | Jackals | Brute Patrol, Skirmishers, Grunts | Brute Kill Team | **Ghost hazard** — fast flanking on the open hillside **[V]**. |
| 3 | Brute Tactical | Elite Patrol, Brute Infantry, Heretics | Hunter Patrol | Second Ghost; Thunderstorm. |
| Bonus 1 | Grunts, 90 s | — | — | Grunt Birthday Party + Catch. |
| 4 | Elite Airborne | Elite Infantry, Heretic Snipers, Brute Kill Team | Hunters | Rangers and Skirmishers bypass the stairway (the two unit types Halopedia names as able to reach the Deck roof **[V]**). |
| 5 | Elite Spec Ops | Hunter Tactical, Elite Strike Team, Brute Kill Team | Elite Generals | Drop-pod hazard waves on the Deck roof. |
| 6 | Hunter Kill Team | Elite Strike Team ×3 | Brute Chieftains | Firing sequence. |

**WIN.** Purchase **TYRANT FIRING SOLUTION — 8,000** (round 5 gate) **at `sc_bfg_destroyed`, the wrecked cannon on the far flank** (§4.4), then carry it back and **man the live cannon to destroy three Phantoms in 90 s**. Players who bought **Repair the Wrecked Cannon (2,000, R3)** earlier get a second gun and only need 60 s — a straight conversion of money into time.

**LOSE.** The convoy window closes: if the firing solution is not purchased and fired by the **end of wave 16**, the convoy is lost. Secondary loss: standard life exhaustion. Optional harder variant — Generator Count 1 on the active cannon's power unit, fail "lose all".

**Purchase catalogue.**
| Item | Cost | Gate | Notes |
|---|---|---|---|
| **Marine squad** (3) | **500 [A]** | — | Always re-buyable. Base first floor by the health packs. |
| **ODST squad** (4, 1 rocket) | **750 [A]** | — | **Walk-in** — Outpost ships zero drop-pod infrastructure **[V]**. |
| Machinegun turret, Base Front or Active Gun | 750 [A] | — | No roof anchor offered, by design. |
| Ghost (player-usable) | 1,000 [A] | R2 | The only vehicle chassis this map's own scripts spawn and move **[V]**. |
| Repair the wrecked Tyrant cannon | 2,000 [D] | R3 | Halves the final firing timer. His set rung. |
| Bank kiosk, deposit or withdraw | 500 [A] | — | Beside `ammo_crate0`, by the health packs — exactly where he put his. |
| **TYRANT FIRING SOLUTION (win)** | **8,000 [D]** | R5 | Bought at `sc_bfg_destroyed` (§4.4). |

**Technical risks.**
* **No UNSC vehicle is verified on Outpost [U]** — selling a Warthog or Scorpion here is the biggest unforced risk in this dossier. The catalogue sells the Ghost instead, which is verified map content.
* The Deck is so dominant that a purchased auto turret on the roof plus 6 friendly AI could stall the AI entirely. Cap friendly AI at 4 on this map and deny a roof turret anchor.
* Scripting a player-operated AA cannon that kills scripted Phantoms is new work; the Corvette ship-gun precedent exists in the mod but the author reports **ship guns fling co-op players out of the seat** **[V, S9]**. Budget co-op testing time.
* Phantoms are normally invulnerable set dressing in Firefight; destructible scripted Phantoms are **[U]**.

---

### 5.4 HOLDOUT — *"PLATFORM DELTA"*

**Premise.** The *Pillar of Autumn* is on the pad at Asźod and needs every minute it can get. Platform Delta is the landward approach — the pad the Covenant must take to put infantry on the shipbreaking yards. A Spartan and whatever ODSTs the Autumn can spare off-load onto Delta to buy the ship its launch window: hold the central platform, keep the helipads clear for the shuttle runs, and when the Autumn's engines light, get off the platform.

**Starting setup.** Players spawn in the three-level storeroom building with **DMR + Magnum**; the **central platform Turret is live** **[V]**; two ODSTs pre-placed on the rooftop. The basement ammo cache and the under-platform route are open from the start **[V]**.

**Trigger.** Reaching the central platform turret, or 45 s. A Covenant Phantom pair comes in over the two drop zones and the **Banshee hazard** activates **[V]**.

**Escalation.**
| Round | Initial | Main | Boss | Notes |
|---|---|---|---|---|
| 1 | Grunts | Grunts, Jackal Patrol, Skirmishers | Elite Patrol | Two drop zones, left and right — the player must split attention. |
| 2 | Jackal Patrol | Brute Patrol, Skirmisher Infantry, Grunts | Elites | **Banshee hazard** owns the sky over the pads. |
| 3 | Brute Infantry | Elite Patrol, Brute Tactical, Heretics | Brute Kill Team | Second Banshee; Catch + Tough Luck. |
| Bonus 1 | Grunts, 90 s | — | — | Score-neutral skulls + Thunderstorm. |
| 4 | Elite Airborne | Elite Infantry, Elite Spec Ops, Heretic Snipers | Hunter Patrol | Rangers land directly on the raised helipad. |
| 5 | Elite Tactical | Hunter Tactical, Brute Kill Team, Elite Strike Team | Elite Generals | Mythic on; under-platform becomes a Spec Ops infiltration route. |
| 6 | Hunter Kill Team | Elite Strike Team ×3 | Brute Chieftains | Launch sequence. |

**WIN.** Purchase **LAUNCH CLEARANCE / EVAC SHUTTLE — 8,000** (round 5 gate) **at the exposed terminal in the right-hand drop zone, `sq_sur_drop_04`, under the `ps_banshee_02` strafing lane** (§4.4), then hold the **lower helipad** for **120 s** while the shuttle lands, with all drop zones still feeding. The *Autumn* lifting in the background is the payoff shot.

**LOSE.** Timer-driven: the Autumn's window is **wave 16**. If clearance is not purchased and the hold not completed by then, the Covenant put armour on the yards and the match is lost. Standard life exhaustion also loses.

**Purchase catalogue.**
| Item | Cost | Gate | Notes |
|---|---|---|---|
| **Marine squad** (3) | **500 [A]** | — | Always re-buyable. Anchored on `ps_gen/gen0`–`gen2`. |
| **ODST squad** (4, 1 shotgun, 1 sniper) | **750 [A]** | — | Drop pod beside `ammo_crate0`. |
| Machinegun turret, rooftop or raised helipad | 750 [A] | — | Two anchors, one at a time. |
| **Anti-air battery** (prioritises Banshees) | 2,000 [D] | R3 | Direct answer to the verified Banshee hazard. **Watch this one:** his Corvette AA Shade went 3,000→6,000 plus an overheat because a fixed emplacement that hits everything was the most overpowered thing he shipped. Start at 2,000; if it deletes the air threat, raise *this* price and add the overheat. |
| Bank kiosk, deposit or withdraw | 500 [A] | — | Beside `ammo_crate0`, or repurpose `generator_switch0` at `ps_gen/gen0` **[V]**. |
| **LAUNCH CLEARANCE (win)** | **8,000 [D]** | R5 | Bought at `sq_sur_drop_04` (§4.4). |

Removed, not re-priced: the Falcon gunner ride — no map of the six references any UNSC aircraft (`fe_reinforcements.hsc` §2a).

**Technical risks.**
* **No ground vehicle is sold, by design**: Holdout is small, multi-level and ramp-linked, and Warthog/Scorpion viability is **[U]**. Do not try.
* Friendly AI on a map with ramps, helipads and an under-platform space is the worst case for Reach's ally pathing — stock Installation 04's four tower ODSTs are **documented as having no pathfinding at all** **[V, S5]**, and the author's players complain allies "stand out in the open" **[V, S9]**. Place bought squads on flat anchors (central platform, rooftop) and let only the Pelican/pod-delivered squad follow the player.
* The Falcon ride over a small map risks clipping the platform structures; a tight orbit path is **[U]**.
* Banshee hazard plus a purchased AA turret could delete the map's only air threat; make the AA battery single-target and destructible.

---

### 5.5 GLACIER — *"BELOW BABD CATHA"*

**Premise.** Under Sword Base, the ice has opened onto a Forerunner structure that ONI never finished surveying, and the Covenant have come down the shaft in force to claim it. There is no sky down here: no Target Locator, no Pelican, no orbital fire **[V]**. A Spartan and an ONI survey detail have to hold the cave base while demolition charges are rigged on the shaft, then bring the roof down on the whole excavation.

**Starting setup.** Players spawn in the cave base with **Assault Rifle + Magnum**. Fixed map hardware is unusually generous and all verified: a **Spartan Laser** in a weapon holder below the rocks, plus **Sniper Rifle and Rocket Launcher racks** **[V]**. Two ONI troopers pre-placed under the awning.

**Trigger.** Picking up the Spartan Laser or 60 s. Phantoms enter down the shaft; the demolition console at the base opens the purchase board.

**Escalation.**
| Round | Initial | Main | Boss | Notes |
|---|---|---|---|---|
| 1 | Grunts | Grunts, Jackal Patrol, Skirmisher Patrol | Elites | Three approach paths (centre, right circuit, left loop) **[V]**. |
| 2 | Skirmisher Patrol | Brute Patrol, Jackals, Grunts | Brute Kill Team | **Ghost hazard** on the circular right path. |
| 3 | Brute Infantry | Elite Patrol, Brute Tactical, Heretics | Hunter Patrol | **Wraith hazard** — the cave is verified Wraith terrain **[V]**. |
| Bonus 1 | Grunts, 90 s | — | — | Cowbell + Grunt Birthday Party + Catch. |
| 4 | Elite Tactical | Elite Infantry, Elite Spec Ops, Heretic Heavy | Hunters | Spec Ops camo in a dark cave; Fog/Cloud skull fits the fiction and pays 1.1×. |
| 5 | Elite Strike Team | Hunter Tactical, Brute Kill Team, Elite Spec Ops | Elite Generals | Second Wraith; Mythic. |
| 6 | Hunter Kill Team | Elite Strike Team ×3 | Brute Chieftains | Charges armed. |

**WIN.** Purchase **DEMOLITION CHARGES — 8,000** (round 5 gate) **at `ps_wraith/p1`, out on the Wraith's shelled ground and explicitly outside `tv_wraith`** (§4.4 — the best-evidenced exposed anchor in the pack), then survive **180 s** — longer than any other scenario, because there is no air support to shortcut the hold — and the cavern collapses. A pure attrition finale, which is what an underground map is for.

**LOSE.** Generator Count 2 dressed as survey power units for the charge rig, fail condition "lose all": lose both and the charges cannot be armed. Backstop at wave 16.

**Purchase catalogue.**
| Item | Cost | Gate | Notes |
|---|---|---|---|
| **Marine squad** (3) | **500 [A]** | — | Always re-buyable. Anchored **inside `tv_wraith`**, the one script-proven sheltered volume. |
| **ODST squad** (4, 1 rocket, 1 shotgun) | **750 [A]** | — | Walks in — **no pod or Pelican delivery is possible underground [V]**. |
| Machinegun turret, base awning or Rampart | 750 [A] | — | Never the roof (AI-proof perch). |
| Ghost | 1,000 [A] | R2 | Matches the verified Ghost hazard. |
| Bank kiosk, deposit or withdraw | 500 [A] | — | Beside `ammo_crate0`, inside `tv_wraith`. |
| **DEMOLITION CHARGES (win)** | **8,000 [D]** | R5 | Bought at `ps_wraith/p1`, outside `tv_wraith` (§4.4). |

Removed, not re-priced: Rocket Warthog and Scorpion — Glacier's Wraiths are a stationary `cs_shoot_point` bombardment script, which proves nothing about drivable ground (`fe_reinforcements.hsc` §2a). No strike either: the map has no `dm_target_*`, no `sc_target_*` and no `dm_longsword_01` **[V]**.

**Technical risks.**
* **Hard verified constraint: no Target Locator, no sky.** Any purchase involving a Pelican, Falcon, drop pod or orbital strike is invalid on Glacier **[V, S5]**. This scenario must sell bodies, turrets and armour only.
* Warthog and Scorpion clearance on "snowy pathways separated by jagged rock pieces" is **[U]** and is the main build risk; the Wraith hazard is encouraging but Wraiths hover.
* The jetpack-climbable base roof is an AI-proof perch; don't allow a turret anchor there.
* 180 s of final hold with two Wraiths live may exceed the engine's comfortable simultaneous-AI budget when combined with 6 friendly AI; see §6.

---

### 5.6 WATERFRONT — *"ÜTKÖZET BLACKOUT"*

**Premise.** The pumping station below the Ütközet dam feeds the Viery industrial belt, and the Covenant have worked out that killing it is cheaper than fighting for it. They are landing in the basins on every side at once, at night, with snipers already on the hill. A Spartan and a rifle section have to keep the pumps alive until engineering can scram the station safely — and then blow the intake so the Covenant cannot use it either.

**Starting setup.** Players spawn in the central House with **Assault Rifle + Magnum** and night vision (a Firefight-native feature **[V, S2]**). Two Marines pre-placed in the Circle. The **covered bridge is the only land connection and shields from airborne fire** **[V]** — the one safe lane on the map.

**Trigger.** Entering the Pump house or 45 s. Phantoms begin dropping in a **full 360° ring** **[V]** and the Jackal snipers on the hill open up.

**Escalation.**
| Round | Initial | Main | Boss | Notes |
|---|---|---|---|---|
| 1 | Grunts | Grunts, Jackal Patrol, Skirmisher Patrol | Elite Patrol | Drops in the basins; ramps are the chokes. |
| 2 | **Jackal Snipers** | Brute Patrol, Skirmishers, Grunts | Elites | Leans into the verified sniper-hill hazard. |
| 3 | Skirmisher Infantry | Elite Patrol, Brute Infantry, Heretic Snipers | Brute Kill Team | Catch + Tough Luck; night + Cloud skull. |
| Bonus 1 | Skirmishers, 90 s | — | — | Fast bonus wave suits the tight ring. |
| 4 | Elite Airborne | Elite Infantry, Elite Spec Ops, Heretic Heavy | Hunter Patrol | Rangers drop straight into the Circle. |
| 5 | Elite Tactical | Hunter Tactical, Brute Kill Team, Elite Strike Team | Elite Generals | Mythic + Thunderstorm. |
| 6 | Hunter Kill Team | Elite Strike Team ×3 | Brute Chieftains | Scram sequence. |

**WIN.** Purchase **STATION SCRAM & INTAKE DEMOLITION — 8,000** (round 5 gate) **at the exposed terminal down in the basins, `sq_sur_drop_03`** (§4.4), then hold the **Pump house** for **120 s**. Fortify-first branch: if the team bought **Seal the Basin Ramps (1,000)** and it is still intact, the win costs **6,000** — but the run to the intake gets longer, so verify a sealed ramp does not make the terminal unreachable.

**LOSE.** Generator Count 3 dressed as pump controllers, spread across the ring, fail condition **"lose all three"** — the 360° drops make a one-generator fail condition unsurvivable. Backstop at wave 16.

**Purchase catalogue.**
| Item | Cost | Gate | Notes |
|---|---|---|---|
| **Marine squad** (3) | **500 [A]** | — | Always re-buyable. Held inside the House, never in the Circle. |
| **ODST squad** (4, 1 sniper, 1 shotgun) | **750 [A]** | — | Walks in over the **covered bridge**, the map's own protected approach **[V]**. |
| Machinegun turret, Circle or bridge mouth | 750 [A] | — | |
| Seal the basin ramps (map state) | 1,000 [A] | — | Closes two ramp approaches; unlocks the 6,000 win price. |
| Counter-sniper team (2 ODST marksmen, under cover) | 1,000 [D] | — | Answer to the Jackal snipers, which are live from wave 1 **[V]**. |
| One-shot artillery barrage on the basins | 3,000 [D] | R3 | His heavy rung. |
| Bank kiosk, deposit or withdraw | 500 [A] | — | Beside `ammo_crate0` in the House. |
| **STATION SCRAM (win)** | **8,000 [D]** / 6,000 with ramps sealed | R5 | Bought at `sq_sur_drop_03`, in the basins (§4.4). |

Removed, not re-priced: the Mongoose/Ghost — Waterfront names no ground-vehicle squad at all **[V]** (`fe_reinforcements.hsc` §2a).

**Technical risks.**
* Three generators on a medium-small map with 360° drops may be unwinnable solo; tune generator health or drop to 2 generators for 1–2 players.
* **No vehicle purchase above light class**: unverified terrain **[U]**.
* Night + Cloud/Fog skull + 24 enemies is a readability problem; verify night vision and the HUD before stacking Blind-adjacent skulls (Blind is 1.0× anyway — no score reason to use it).
* Friendly AI in the ring will take fire from every side; the author's players already report allies are "way too squishy" and don't take cover **[V, S9]**. Anchor bought squads inside buildings, not in the Circle.

---

## 6. Cross-cutting technical risks (task 5)

1. **Friendly AI is the known weak point of this genre, verified twice over.** Stock Installation 04's four beam-tower ODSTs **have no pathfinding directions and stand still**, while the Pelican-delivered reinforcement squad **is correctly scripted to follow players** **[V, S5]**. In the mod's own comments, players report Marines being "a waste of points" because of inaccurate fire, allies not spotting or engaging at range, not taking cover, Marines in a Scorpion not firing, and troopers in a transport Warthog not shooting **[V, S9]**. Mitigations that follow directly from that evidence: copy the **Pelican/pod-delivered follower script**, not the static tower script; anchor squads on flat defensible ground; give bought squads precision weapons (DMR/sniper) rather than heavies, since ODSTs reportedly can't land the new Fuel Rod; and consider a small, non-score-affecting health boost to allies (ally traits are not player traits, so the 1-point-per-minute scoring penalty **[V, S2]** should not apply — **verify [U]**).
2. **Simultaneous AI budget.** A normal wave is 6 squads × 4 = **~24 enemies** **[V, S3, S10]**. Add 2 hazard vehicles, 6 friendly AI, a player-driven vehicle and a turret, and you are well past any stock configuration. An exact engine cap was not found (**[U]**), so the working rule for all six scenarios is: **friendly AI ≤ 6 alive**, **hazard vehicles ≤ 2 alive**, and never schedule a Hunter/Chieftain wave (6 single-unit squads) alongside a bonus-wave-style dropship feed.
3. **Co-op is the fragile path.** The mod's own release notes and comments document: Corvette **ship guns flinging co-op players out of the seat**, a **Wraith main-cannon shot crashing non-host clients**, grenade-launcher crashes, effects not playing in co-op, and the published known-issue that the build is "largely untested for co-op, especially for lobbies with players very far away from each other" **[V, S8, S9]**. Any scripted player-operated super-weapon (Outpost's Tyrant, any MAC analogue) must be co-op tested first; prefer non-seated one-shot purchases (call-in barrage) over seated gun emplacements where possible.
4. **Win-condition timing is the most complained-about mechanic in the shipped mod.** Players report losing Unearthed because they could not cross the map to the MAC before the glassing beam, and getting "Killed by the Guardians" when entering the MAC **[V, S9]**. Therefore every design above (a) gates the win purchase by round rather than relying on a tight timer, and (c) gives a generous post-purchase hold (120–180 s) instead of a race. **Point (b) is reversed as of 2026-11-21:** it used to say "place the win interactable at or next to the player's own stronghold", which was written before the author's own placement was recovered. He does the opposite — the MAC terminal is exiled to the Crane, outside the defensible area, and the run to it *is* the climax (`research/10` §3.2) — and his fix for the very complaint above was to **loosen the round gate** (Set 2/Round 3/Wave 5 → start of Set 2) while leaving the Crane where it was. So: win terminal outside the stronghold, at the named exposed anchors in §4.4, with the gate and the post-purchase hold absorbing the difficulty.
5. **Scoring integrity.** Any advantageous player trait or skull switches Firefight to 1 point/minute **[V, S2]** — which would silently break the currency these scenarios are built on. Audit every gametype change against that rule, and re-measure per-round income after every tuning pass.
6. **Spawn clustering.** A commenter notes that on Unearthed "the spawnpoints … are all clustered around the compound, and it can snowball extremely badly" **[V, S9]**. All six designs above use maps with **dedicated enemy drop zones away from the player stronghold** (Overlook, Holdout, Unearthed-style Beachhead lagoon, Outpost's ONI Road, Waterfront's basins) — preserve that separation when adding scripted spawns.
7. **Difficulty tuning drifts with purchases.** Comments report the shipped Firefight being over-tuned on enemy spawn rates and rank (too many Major Elites, too many Fuel Rod Grunts), and that skulls staying on through normal rounds feels punishing **[V, S9]**. The round tables above therefore keep skulls off in round 1, add one per round, and reserve Mythic for set 2.
8. **Per-map squad support.** Unsupported squad types cause a wave to end in ~7–9 seconds **[V, S3, S4]**, and the brief's own candidate list came with a community report of Hunters failing to spawn in MCC Firefight **[S9-adjacent]**. Before locking the escalation tables, test every chosen squad type on every chosen map; Engineers (Corvette-only **[V]**) and Guta (unsupported everywhere **[V]**) must never appear.

---

## 7. Appendix — holding designs and open questions

**Courtyard (rank 7), one-paragraph premise if a seventh mission is wanted.** *"SWORD BASE, LOADING DOCK"*: the ONI loading dock outside Sword Base still has Halsey's uncatalogued crates on the pad, and the Covenant have breached the two service rooms on the depot side. Hold the Terrace and bridge, seal both **map-built enemy spawn rooms** **[V]** as purchasable map state (1,000 each — a purchase no other map can offer), and win by buying **CRATE EXTRACTION — 8,000**, round 5 gate, **bought at `sq_sur_drop_04`** (Courtyard has four named pod lanes **[V]**) rather than on the Terrace, and loading the crates with the map's **Forklift** **[V]**. Marines at 500 and ODSTs at 750 as always, plus the 500-a-press bank; no combat vehicle sold (none verified **[U]**); machinegun turret at 750 on the Terrace and bridge ends, which Halopedia names as the two defensible spots **[V]**.

**Open questions that must be answered in-game or in HREK before build:**

1. Reach-specific **per-unit base point values** for Firefight kills. **Partly answered, and the answer changed the dossier.** The ladder is no longer calibrated on the withdrawn 30,000 Corvette figure or on a derived 4,000–8,000 a round; it is calibrated on the OCR measurement of the mod itself, ≈ 900 points/minute → 2,000–2,500 a round (§1.6, §4.1, `research/10` §1.3). Still worth doing: re-measure one round on Normal and one on Legendary, solo and 4-player, **in our build**, because the measured run was solo on his launch build with unknown score settings. If our measured income differs, retune the one constants block at the top of `src/hsc/fe_reinforcements.hsc` — every price in the pack reads from it.
2. Whether a **Scorpion** can actually path on Overlook and Glacier (Wraith hazard is verified on both; Wraiths hover). **[U]**
3. Whether any **UNSC vehicle** fits Outpost, Waterfront and Courtyard. **[U]**
4. Whether **ally traits** can be buffed without tripping the advantageous-traits scoring penalty. **[U]**
5. Whether **scripted destructible Phantoms** (needed for Outpost's win) are feasible, and whether a player-operated AA gun survives co-op. **[U]**
6. The engine's real **simultaneous AI ceiling** on each map. **[U]**
7. Whether **drop pods** can be used as a delivery animation for purchased ODSTs on each specific map, or only where the map's hazard set already includes them. **[U]**
