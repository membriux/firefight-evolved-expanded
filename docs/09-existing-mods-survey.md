# 09 — Survey of existing, already-built mods: "buy Marines/ODSTs in Halo: Reach Firefight"

Research date: 2026-11-21. Target platform: Halo: The Master Chief Collection on Steam (app 976730), Windows PC.
Goal of this document: find a finished mod the user can install and play, instead of building one with the Halo Reach Editing Kit.

## 0. Headline conclusion

**The user already owns the mod that does exactly what he wants: Steam Workshop item 3453792163, "Halo Reach: Evolved Public Beta" by The Vengeful 'Vadam.** Nothing needs to be built, and nothing new needs to be installed.

Verified purchase prompts, read directly off the mod author's own screenshots on the Workshop page:

- `Hold [E] to call in ODSTs (2,000 points)` — seen at the terminals in "Station 2 Interior" on Installation 04, with the gametype name `FIREFIGHT EVOLVED` in the bottom-right HUD.
- `Hold [E] to buy Machinegun Turret (750 points)` — seen on the Installation 04 "Upper Deck", same gametype.
- `Auto Turret not available until Round 3...` — proves some purchases are gated by round number, not only by price.
- Locked stations display `TERMINAL LOCKED` on the console screen until they unlock.

So the purchase system is not a menu you open from anywhere. It is a set of physical buy points in the map. Walk up to one, and the prompt appears on the right side of the HUD; then **hold** (not tap) the Use/Interact key, which is `E` on a default keyboard setup.

Why he saw no purchase menu is almost certainly one of these four things, in order of likelihood:

1. He launched the **vanilla** Firefight map instead of the modded one. The mod's maps appear as separate entries named with "(Evolved)" — a user in the comments refers to "finishing the firefight on Unearthed (Evolved)". Several users report the same symptom he had; one comment reads: "I've downloaded it, and placed the bin into the right folder, but when I play the game nothing seems to change! None of the new weapons, allies, buying system, nothing. Playing on Unearthed and Installation 04."
2. He never stood next to a buy point. The prompt only renders when you are within a few metres of a terminal/pad. Buy points show up at range as green cube waypoints on the HUD (one of the author's screenshots labels one `ORDNANCE` at 175 m).
3. He tapped `E` instead of holding it.
4. He launched MCC with anti-cheat enabled. Workshop mods only load in the second launch option, `Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)`.

## 1. Why only map mods can do this (structural fact, verified locally)

Both of the author's off-Workshop gametype files were decoded in this project (see `mpvr-dump-firefight-evolved.txt`, `mpvr-dump-corvette-evolved.txt`):

- `Firefight Evolved.bin` → title `FIREFIGHT EVOLVED`, description "Used with Halo: Reach Evolved Firefight. Use your Firefight Score to purchase bonuses."
- `Firefight Corvette Evolved.bin` → title ` FIREFIGHT CORVETTE EVOLVED`, description "Used with Halo: Reach Evolved Firefight Corvette. Fight your way through the Corvette to steal valuable Covenant intel."

Both decode as engine type 4 (firefight) with the Megalo section **structurally absent**: no string table, no triggers, no variables, no HUD widgets. The bins only carry lives, score targets, skull sets and scenario flags.

Consequence: in Reach Firefight, a score shop cannot live in a gametype. It must live in the `.map` scenario script. That is why only full map mods (Reach Evolved, The Prophets' Hand) have shops, and why no `.bin`-only download on Nexus can ever add buyable Marines.

## 2. Task 1 — The Prophets' Hand: Reach Firefight (the lead that was supposed to be strongest)

- Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3706452171
- Workshop ID 3706452171, "The Prophets' Hand: Reach Firefight (Beta 0.12)", author SteamID64 76561198429729113.
- Tags: HaloReach, Firefight. 14,131 views, 2,853 subscribers, 622 favourites. Created 2026-04-13, last updated 2026-07-18 (Unix 1776126619 / 1784568670). Current for MCC in 2026.
- Install: Steam Workshop subscribe only. Its own description states: "No custom game mode is required but the squad templates have been modified to UNSC troops." Like every Workshop mod it still needs MCC launched with anti-cheat disabled.
- Maps: **one** — Overlook. ("It currently only features one map, Overlook.")

What it actually offers, from the author's own description:

- "Players can earn credits through combat and completing bonus objectives to spend them on reinforcements and battlefield support."
- "Score-based credit shop system"
- "**Buyable Covenant reinforcements from Tier 1 through Tier 5**"
- "Prophets' Hand squad Hero Reinforcements"
- Weapon drops, equipment drops, vehicle drops, vehicle support
- Air Support, Glassing Beam Strike, Corvette Bombardment, Seraph Bomb Runs, Longsword strikes
- Random bonus objectives (Destroy Enemy Comms, Eliminate The High Value Target, Protect The Squad, Defend The Generator, Recover The Enemy Data Core) with failure penalties
- "ODST drop pod penalty events", "Enemy reinforcements delivered by Falcons"
- "Custom shop HUD messages with prices and instructions"

**The decisive point: in this mod you play as the Covenant and the UNSC are the enemy.** "you face UNSC troops, vehicles, bosses, and heavy support/air strikes." The ODSTs and Marines appear as hostiles — ODST drop pods are a *penalty* for failing an objective. The things you buy are Brutes, Elites and Prophets' Hand hero squads. One commenter puts it plainly: "I've always wanted to fight the humans in firefight."

Comment-page findings (68 comments read in full):

- Shops are physical: "UNSC I feel spawns way too close to where you spawn and by the **buy stations**"; "you can call in more AI through the **shops**, plus you get free allies randomly through drop pods and you get more free AI with every firefight round completed."
- Reinforcements die fast: "Any time I call for reinforcements they last for like a minute before being killed."
- Price inconsistency: "how much does each reinforcement cost? Because sometimes tier 1 costs me 1200 points and other times tier 2 costs 1500 points." The 0.12 changelog addresses this: "Fixed Shop costs being higher than displayed due to skulls."
- Stability is shaky right now: "crashing at start", "Hard crashing upon firefight start with most recent update", "Overlook crashes the game immediately upon the end of the loading screen". One user's workaround: non-vanilla Spartan armour pieces crash Reach Firefight mods, so equip only original Reach armour.
- Balance complaints: UNSC laser/flame/cryo troopers are considered overpowered; enemy spawns are very close to the player.

Changelog (from the page): Beta 0.12 reduced AI Cryothrower damage/accuracy and fixed shop costs; Beta 0.11 fixed tier 2–5 Brute reinforcements spawning on top of the Phantom, fixed the vehicle-support shop getting stuck, reduced Spartan boss health, added health/shield bars to drop allies, added a HUD message for when a shop is busy or on cooldown.

**Match rating for "buy Marines and ODSTs in Firefight": 1 / 5.** It has the best shop system of any Reach Firefight mod and it needs no gametype file, but the faction is inverted. What is missing is the entire point: you cannot buy Marines or ODSTs, because you are shooting at them.

## 3. Task 2 — What the mod he already owns actually does (and how to trigger the shop)

- Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163
- Workshop ID 3453792163, "Halo Reach: Evolved Public Beta", author The Vengeful 'Vadam (SteamID64 76561198063340220).
- 7,333,964,512 bytes (7.33 GB). 65,173 views, 11,400 subscribers. Created 2025-03-28, last updated 2026-11-12 (Unix 1743193258 / 1773581311). Actively maintained.
- Tags: HaloReach, Campaign, Firefight.

Firefight scenarios and what is purchasable, quoting the author's description:

**Installation 04** — "With a squad of marines, secure the tower, hold off Covenant reinforcements, as well as Sentinels, until you're able to call for a pelican extraction to win the game. During that time, you can use your Firefight score to purchase **ODST reinforcements**, an **auto turret**, a **Falcon gunner** ride akin to Call of Duty's 'chopper gunner', and even **hack the nearby Sentinels** to be on your side for a round."

**Unearthed** — "Drop in with a squad of ODSTs to secure the base... Your win condition is to hold out until you can purchase the **MAC Cannon** to destroy the ship. However, if you can't purchase the cannon on time, the glassing beam will activate and everyone dies... You can also purchase **Marine reinforcements**, another **auto turret**, a **rocket Warthog** which can be upgraded to a **Gauss Warthog**, and a **Scorpion**."

**Corvette** — "There's weapon crates to buy, a **Shade turret** to unlock and upgrade, a CoD-style **Mystery Box**, gametype objectives in between rounds, and new bonus rounds (Corvette Cannonade, Sabre Strike)."

Confirmed prices seen in-screenshot: ODSTs 2,000 points; Machinegun Turret 750 points. Author in the comments: Corvette's ending is "a switch to flip that'll cost 30,000 points" at the bridge, and "you have to buy the door leading to the gunroom and bridge."

Independent confirmation that buying allies works in play, from the comment thread:

- "Marines are basically just a waste of points, as their firing patterns are too sporadic and inaccurate compared to enemies." (so Marines are purchasable, and weak)
- "allies don't last too long unless you're constantly buying new ones"
- "abuse the buys and you should be fine"
- "when i called troopers, they were at the initial spawn and didn't tp to the pelican"
- "There are stations to deposit and withdraw points" — on top of the buy points there are point-transfer stations, which a commenter guessed are for sharing points with co-op teammates.

### How to open the purchase prompt — exact answer

There is no menu key and no pause-menu shop. The flow is:

1. Launch MCC through the launch option named `Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)`.
2. Firefight → pick the **modded** map entry, the one marked "(Evolved)" (e.g. "Unearthed (Evolved)"), under the modded/mod-added missions list. Not the vanilla map of the same name.
3. Gametype: `FIREFIGHT EVOLVED` for Installation 04 and Unearthed; ` FIREFIGHT CORVETTE EVOLVED` for Corvette. These are the two `.bin` files he already placed.
4. In the match, look for the green cube waypoints (one screenshot labels one `ORDNANCE`) and for UNSC consoles/terminals and holographic item previews near the base.
5. Stand next to one. A line appears at the right of the HUD, e.g. `Hold [E] to call in ODSTs (2,000 points)`.
6. **Hold** `E` (the Use/Interact bind) until it fires. Tapping does nothing.
7. If it says `TERMINAL LOCKED`, or you get `Auto Turret not available until Round 3...`, that item is round-gated — keep playing and come back.
8. Skulls inflate real cost versus the displayed number in some builds (the sibling mod had the same bug); if a buy fails with enough points on the HUD, bank a little more.

**Match rating: 5 / 5.** This is the requested feature, shipped and playable, including the bonus items (auto turrets, Warthog/Scorpion, super-weapon MAC cannon, Falcon gunner). What is missing: only three Firefight maps, the AI allies are widely considered weak, co-op has known sync bugs, and Generator Defense / Firefight VS are unsupported.

### Known failure modes for this mod (all from the item's own comments)

- "make sure they have both SP and MP installed" — Reach's singleplayer and multiplayer components must both be installed in MCC's install options, or modded missions show "missing content".
- "unsubscribe and resubscribe from the mod" — the author's standard fix for the mod not appearing.
- The gametype download link has broken and been restored more than once; the current link is in the description.
- Old or non-vanilla Spartan armour pieces can crash Reach Firefight mods.
- Unskippable intro cutscene on single-player Firefight; occasional load-screen crashes.

## 4. Task 3 — Everything else that was checked

### Steam Workshop (app 976730)

Method: 13 Workshop text searches ("firefight marines", "buy allies", "firefight shop", "purchasable", "reinforcements", "trooper firefight", "firefight odst", "score shop", "requisition", "buyable", "firefight overhaul", "marine firefight", "firefight ai") yielding 130 unique item IDs, then full metadata for all 130 via `ISteamRemoteStorage/GetPublishedFileDetails`, then keyword filtering on the descriptions.

Result: **only two Workshop items in the whole set have a Firefight score shop at all** — 3453792163 (Reach Evolved) and 3706452171 (The Prophets' Hand). Everything else that adds friendly Marines/ODSTs gives them to you for free.

| ID | Name | What it adds | Maps | Install | Gametype needed | 2026-current | Rating |
|---|---|---|---|---|---|---|---|
| 3453792163 | Halo Reach: Evolved Public Beta | Score shop: buy ODSTs, Marines, auto turrets, Warthog/Scorpion, Falcon gunner, Sentinel hack, MAC cannon, mystery box | Installation 04, Unearthed, Corvette (+ 4 campaign missions) | Workshop subscribe | Yes — 2 off-Workshop `.bin` files | Yes, updated 2026-11-12 | **5** |
| 3706452171 | The Prophets' Hand: Reach Firefight | Score shop, but you are Covenant: buy Brute/Elite tiers 1–5, hero squads, airstrikes, vehicles | Overlook only | Workshop subscribe | No | Yes, updated 2026-07-18 | 1 |
| 3568692404 | Halo Reach 457 Firefight | "At the start of each round, the player... can request reinforcements and weapon drops... requested via switches". Human reinforcements include marines, police, militia | 457 Overhaul Firefight maps | Workshop subscribe | Not stated | Updated 2025-09 | 2 (unverified whether it costs score; wording is "request", not "buy", and it appears to be once-per-round rather than a shop) |
| 3639410660 / 3777619436 / 3774628114 | Installation 04 / Unearthed / Corvette: The Last Stand | Free allies, respawning each round (Unearthed: 25 ODSTs, 2 Spartans, 28 Marines, a Falcon with 5 ODSTs, 2 Warthogs; doubled ally health) | one map each | Workshop subscribe | No | Updated 2026-09 | 2 |
| 3434207298 | deadkiva7's Halo: Reach Firefight (Map Pack) | 14 custom Firefight maps, "All maps have friendly AI. The marines are modified." Friendly AI tied to the "Hazards" scenario setting | 14 maps | Workshop subscribe | No (uses the Hazards toggle in standard FF options) | Updated 2026-11 | 2 |
| 3029342213 | Holdoff with Marines and Elite ALLIES! | Free Marine + Elite allies, ally Falcon | Holdoff | Workshop subscribe | No | 2023 | 2 |
| 3831541326 / 3820724534 | Installation 04 / Beachhead Warfare Chaos | Large-scale battle: allies with increased health, allied vehicles, timed spawns | one map each | Workshop subscribe | No | Updated 2026-10/11 | 2 |
| 3137359531 | Halo Reach Polished | "overhauled firefight experience with ally spawns", many trooper/Marine/ODST variants, buffed allies | campaign + Firefight | Workshop subscribe | No | Updated 2026 | 2 |
| 3240182577 / 3422510261 / 3130762911 | Trooper Firefight 2024 (3rd/1st person) / Improved Trooper Firefight | You *play as* a Marine/ODST; no purchasing | many | Workshop subscribe | No | Updated 2026 | 1 |
| 2903820909 | Halo: Reach – Sky on Fire | Fortified UNSC Army allies, Pelican-delivered reinforcements, free | Highlands-style resort map | Workshop subscribe | No | 2023 | 1 |
| 2899279981 | Halo Reach Mythic Overhaul Firefight | Sandbox/enemy overhaul, no ally shop | all FF maps | Workshop subscribe | No | Yes | 0 |
| 2986601070 / 2923946201 | Beachhead / Hemorrhage AI Mayhem | Endless AI war, dropship-delivered AI, free | one map each | Workshop subscribe | No | Yes | 1 |
| 3215748441 | Firefight XL | Bigger waves, "Friendly Marines get a 2x health buff" | FF maps | Workshop subscribe | No | Yes | 1 |
| 3797186862 / 3807472980 | Civil Unrest / Civil Unrest: Firefight | Human-vs-human campaign and endless battles; has in-world **terminals** with pages (RB/LB or PGUP/PGDN) but no Firefight-score ally shop | custom | Workshop subscribe | No | Updated 2026-11 | 1 |
| 2920103613 | Halo: Reach "Realism" Rebalance | More and deadlier friendly AI, free. Useful for its install note: "Firefight will be found under 'modded missions' in the Halo Reach Firefight menu" | all | Workshop subscribe | No | Yes | 1 |
| 3170803257 | Gashnor's Cursed Halo Reach | Joke overhaul; "shopping cart" is a vehicle, not a shop | all | Workshop subscribe | No | Yes | 0 |

### Nexus Mods (Halo: The Master Chief Collection)

Method: the site HTML is blocked from this environment (Cloudflare 403 / DNS), so data came from the public GraphQL endpoint `api-router.nexusmods.com/graphql` (game id 2971). The whole Firefight category was enumerated (107 mods) and the mod descriptions were searched for "purchase", "buy" and "score".

- **Mod 2251 — "Friendly Marines in Halo Reach Firefight"** (https://www.nexusmods.com/halothemasterchiefcollection/mods/2251). Category Firefight, 255 downloads, 7 endorsements, last updated 2023-01-19. Full description: "spawns infinitely friendly Marienes in Halo Reach Firefight, when one dies spawns a new one, it's only the maps Outpost included for now. installation: drop the `ff60_airview.map` to `Halo The Master Chief Collection / haloreach / maps` folder. make a backup of the map if you want to deinstall the mod." So: free infinite Marines, one map (Outpost), manual overwrite of a base game map file, nearly three years stale. **Rating 2 / 5** — friendly Marines but no purchasing, and overwriting a shipped `.map` is the riskiest install style here.
- **Mod 1181 — "Rust Modded Gametype"** (https://www.nexusmods.com/halothemasterchiefcollection/mods/1181). Category Gametypes, 221 downloads, 2021-06-11. It is a Reach **multiplayer** Megalo variant made in ReachVariantTool: resource nodes, team zones, buyable bases from a 400-resource "hobo shack" to a 5,000-resource "giga-base", an item shop selling weapons, armour abilities, Banshees and Warthogs, and raid bombs. Install: place the `.bin` in the MCC Reach gametype folder. **Rating 0 / 5** — a genuinely impressive Megalo shop, but it is PvP, not Firefight, and Megalo cannot spawn AI squads. Confirms the structural finding in section 1.
- Other Nexus Firefight-category mods of note, none with a shop: 942 "Halo Reach AI Spawning in Firefight" (spawn friendly AI during Firefight, 2,927 downloads, last touched 2021-01-10 — its sibling 1194 "Reach Firefight AI Spawn and Command" is explicitly marked "BROKEN DUE TO S7 UPDATE", so assume 942 is also pre-Season-7 and unsafe for 2026); 781 "Installation 04 Warfare FireFight" (marked BROKEN); 2519 "XBOX COMPATIBLE INSTALLATION 04 FRIENDLY MARINES FRIENDLY DROPSHIPS" (2024, free allies); 2069 "allies and heroes on installation 04"; 433 "Installation 04 Firefight – Cliff Edge Edition" (marked temporarily broken); 1858 "Defenders of Reach Spartan Firefight"; 164 "FireFight Fight What You Want". Searching every MCC mod description for "purchase" returned only three hits site-wide (1109 Halo 3 Zombies, 1181 Rust, 1215 Halo City RPG) — none of them Reach Firefight AI.

### ModDB, GitHub, community lists

- ModDB (`moddb.com/games/halo-the-master-chief-collection`) returns HTTP 403 to this environment; no MCC Reach Firefight shop mod surfaced from any other source, and ModDB is not where MCC mods are published in 2026 (Workshop and Nexus are).
- GitHub has no published Reach Firefight shop mod. The relevant GitHub tooling is the editing-kit/Megalo side (ReachVariantTool and friends), which section 1 shows cannot deliver this feature anyway.
- General web search engines (DuckDuckGo HTML, Bing, Mojeek) were all bot-blocked from this environment, and Reddit returned 403, so discovery was done through Steam's own search plus the Nexus GraphQL API rather than through a search engine. Steam Guides for app 976730 were also searched ("Reach Evolved", "firefight shop", "keybinds") — there is no guide for either shop mod.

## 5. Install steps for the top recommendation (zero-to-playing, assuming nothing)

He already has steps 1–3 done. Steps 4–8 are the part he is missing.

1. In Steam, make sure both Halo: Reach components are installed: right-click **Halo: The Master Chief Collection → Properties → DLC/Installed Components** and tick Halo: Reach **and** its multiplayer component. The author's own fix for "modded missions don't show up" is "make sure they have both SP and MP installed".
2. Subscribe to https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163 (7.33 GB). Wait for Steam to finish downloading it under `steamapps\workshop\content\976730\3453792163`.
3. Download the two gametype `.bin` files from the link in the mod description (the author's OneDrive link, also mirrored on his "Vengeful Vadam" in-game file share) and copy them to:
   `...\steamapps\common\Halo The Master Chief Collection\haloreach\game_variants\`
   The two files are `Firefight Evolved.bin` and `Firefight Corvette Evolved.bin`.
4. **Launch correctly.** Start MCC from Steam and, in the launch-options dialog, choose the second entry: `Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)`. Workshop mods are invisible in the normal launch mode. (If no dialog appears, Steam remembered a previous choice — in Steam, right-click the game → Properties → General and clear the saved launch option, or re-enable the launch selector.)
5. In MCC: **Halo: Reach → Firefight → Custom Game**. In the map list, pick the entry marked "(Evolved)" — e.g. "Installation 04 (Evolved)" or "Unearthed (Evolved)" — from the modded/mod-added missions section. Do not pick the plain vanilla map with the same name; that is the single most common reason people report "nothing changed".
6. Set the gametype to `FIREFIGHT EVOLVED` (for Installation 04 or Unearthed) or ` FIREFIGHT CORVETTE EVOLVED` (for Corvette). If the gametype is missing from the list, the `.bin` files are in the wrong folder.
7. Start the match. First, bank score — ODSTs cost 2,000 points and the HUD starts you at 0.
8. Find a buy point: look for green cube waypoints on the HUD, and for UNSC consoles near the base (Installation 04 has a cluster inside "Station 2 Interior" and more on the "Upper Deck"). Stand next to one, wait for the right-hand prompt such as `Hold [E] to call in ODSTs (2,000 points)`, then **hold** `E`. A Pelican flies in and drops the squad.
9. Recommended for a first run: **Installation 04 (Evolved)**, Normal or Heroic, solo. Community consensus is that Installation 04 is far better tuned than Unearthed ("Installation 04 felt a lot better as a solo map"; "Unearthed Firefight feels really overtuned"). Unearthed is the one with buyable **Marines** and the MAC-cannon ending, but it is also the one where you lose if you cannot reach and afford the cannon in time.

Troubleshooting order if the mod still does not appear: unsubscribe and resubscribe (the author's own advice); verify both Reach SP and MP components are installed; make sure you are in the anti-cheat-disabled launch mode; and strip any non-vanilla armour pieces off the Spartan, which is a known crash cause in Reach Firefight mods.

## 6. Conflicts and risks to his current setup

- **Nothing needs to be removed.** 3453792163 can stay subscribed exactly as it is.
- **Two Workshop map mods can coexist.** They are separate subscriptions and each presents its own map entries in the Firefight menu; you choose one per match. Subscribing to The Prophets' Hand alongside Reach Evolved is safe from a file-conflict standpoint — they touch different Firefight maps (Overlook vs Installation 04 / Unearthed / Corvette). The real costs are disk space (7.33 GB plus the Prophets' Hand package) and a longer mod list to scroll.
- **Do not install Nexus 2251 as things stand.** It overwrites a shipped base-game file (`haloreach\maps\ff60_airview.map`). That is a different and more fragile install class than the Workshop: it is wiped or broken by MCC updates and by Steam file verification, and if he ever runs "Verify integrity of game files" it reverts silently. If he ever does try it, back up the original `ff60_airview.map` first. It only affects Outpost, so it would not clash with Reach Evolved's maps.
- **Anti-cheat-disabled mode is required for all of this**, and it disables matchmaking and some online services for that session. That is normal and reversible — launch MCC normally to get matchmaking back.
- **Gametype files are additive and harmless.** The two `.bin` files only add entries to the Firefight gametype list; they do not modify anything the base game ships.
- **The Prophets' Hand is currently crash-prone** according to several recent comments. If he tries it, expect to troubleshoot, and keep Reach Evolved as the stable option.

## 7. Honest bottom line

The user does not need the HR-EK project to get buyable Marines and ODSTs in Reach Firefight. That feature is already installed on his machine, on two of the three Firefight maps he already downloaded, and is reached by walking to a terminal and holding `E`.

The HR-EK project is still the only route if what he wants is *his own* scenario: buyable Marines/ODSTs on arbitrary maps (Beachhead, Courtyard, Holdout, Overlook…), his own prices and tiers, or a Firefight shop that is not limited to one author's three maps. No existing mod provides a general, map-agnostic "buy Marines" system — because, as section 1 proves, that logic has to be compiled into each `.map`.
