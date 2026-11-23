# Firefight Evolved Expanded

Purchasable Marine/ODST reinforcements for Halo: Reach Firefight (MCC), on six maps Bungie never
scripted for it. HaloScript source + reverse-engineering tools.

Inspired by [Halo Reach: Evolved](https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163)
by The Vengeful 'Vadam, which does this on Installation 04, Unearthed and Corvette.

**Status: source complete, never compiled, never run in game.** See [Status](#status).

---

## The one thing to know first

**A Firefight game variant cannot spawn friendly AI.** Variants are engine type 4 (survival),
which has no script block. Megalo's action table has no AI-spawn action and the Firefight squad
palette (32 entries) is all Covenant. Confirmed four ways, including the original author's
changelog, where purchase prices ship in *map* updates only.

So this is a **map mod**, not a gametype. The logic lives in a modified `.map`.

---

## Happy path

### 1. Get the tools

| Need | Where |
|---|---|
| Halo Reach Editing Kit (HR-EK) | Steam app `1695793`, free, **Windows only** |
| Assembly (script compile/decompile) | https://github.com/XboxChaos/Assembly |
| Assembly on macOS/Linux | https://github.com/Jestzer/Assembly-CrossPlatform (net8.0, builds on arm64) |

Prefer Assembly over `tools/hsc/` here — ours is read-only.

### 2. Start from Installation 04, not a blank map

`cex_ff_halo` already ships friendly Marines, a Pelican script, a working `obj_marines` objective,
and **six inert `sur_fireteam_01`–`06` squads** to repurpose. Precedent: NukeTimeStories added
ODSTs to it in 2019 with Assembly alone, no `tool.exe`.

### 3. Create the squads in Sapien

Scenario tag → `squads` block. **One cell per body** — not one cell with count 8.

| Squad | Cells | Character | Team | Parent group |
|---|---|---|---|---|
| `sq_fe_garrison` | 6 × 1 | Marine or ODST | `human` | `gr_unsc_reinforcements` |
| `sq_fe_marines` | 8 × 1 | Marine | `human` | `gr_unsc_reinforcements` |
| `sq_fe_odst` | 8 × 1 | ODST | `human` | `gr_unsc_reinforcements` |

Per-cell field is `spawn count`. Weapon is `initial_primary_weapon`.

> **Never parent friendlies under `gr_survival_all`, `_waves`, `_remaining` or `_extras`.**
> `survival_wave_living_count` would never reach zero and waves would never end. On Courtyard,
> Overlook and Waterfront the Covenant pod spawner also waits on `gr_survival_extras` — living
> friendlies there permanently suppress enemy pods.

### 4. Create the objective

Copy `obj_marines` from `cex_ff_halo_main.hsc` L220-242: tasks `gate_marines`,
`gate_marines_followers`, `gate_marines_defenders`. Set the follow property on the follower task:

```
follow: player front / radius 10 / Z clamp 1
```

Re-arm with `ai_reset_objective`. **Do not use the fireteam API** — disabled in shipped Reach
(`;tysongr - 53954: Adios, fireteams`) and it was for elite players anyway.

### 5. Add the scripts

Compile `src/hsc/fe_reinforcements.hsc` plus the one file for your map:

| Map | Script | Tag |
|---|---|---|
| Beachhead | `ff50_park.hsc` | `ff50_park` |
| Overlook | `ff10_prototype.hsc` | `ff10_prototype` |
| Outpost | `ff60_airview.hsc` | `ff60_airview` |
| Holdout | `ff70_holdout.hsc` | `ff70_holdout` |
| Glacier | `ff60_icecave.hsc` | `ff60_icecave` |
| Waterfront | `ff30_waterfront.hsc` | `ff30_waterfront` |

If the compiler rejects a second `(script startup ...)`, merge its body into the stock map script.

### 6. Build and install

```
tool.exe build-cache-file levels\firefight\<map>\<map>
copy <HREK>\maps\<map>.map  "<MCC>\haloreach\maps\"
```

Launch via **Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)**
(`steam://launch/976730/option2`).

---

## Design reference

### Economy

Prices are the original author's, recovered from his changelog and playtest-corrected by him.
Measured income **~900 pts/min ≈ 2,000–2,500 per round**.

| Item | Cost | Gate |
|---|---|---|
| Marines (8) | 500 | — |
| ODSTs (8) | 750 | — |
| MG turret | 750 | — |
| Bank deposit/withdraw | 500/press | — |
| Ghost | 1,000 | R2 |
| Set item | 2,000 | R3 |
| One-shot strike | 3,000 | R3 |
| **Win purchase** | **8,000** | **R5** |

He cut every launch price 50–75% within 24h. **Start cheap.** The 6,000 rung is deliberately
empty — that is where his AA-Shade hike backfired.

### Actor cap

No published Reach actor constant exists. Derived ceiling **~34 concurrent actors** for both
sides: 6 carryover + 6 squads × ≤4 cells + 4 dropship crew.

`k_fe_actor_limit = 12` friendlies. Purchase is offered every wave and trims to free slots; deaths
free slots instantly. At full garrison (6+8=14) a buy lands partial.

Lower where geometry demands: **Outpost 6**, **Holdout 8**, **Glacier 8**, **Waterfront 10**.
Beachhead and Overlook carry 12.

### Scenario formula (the author's, worth copying)

1. Insert with an assigned friendly squad under a cutscene
2. One "secure the X" objective — completing it *summons* the antagonist
3. Antagonist brings wave pressure + a recurring environmental hazard; shop opens; heavies gated by round with a HUD banner
4. Win = a purchase worth ~4 rounds of income. Lose = the antagonist's timer. Match never ends naturally — the script ends it

**Site the win terminal outside the defensible area.** On Unearthed he exiles the MAC Cannon to
the Crane; the run under barrage is the climax. Ours use named tag anchors — `ps_wraith/p2`
(Beachhead), `sc_bfg_destroyed` (Outpost), `ps_wraith/p1` outside `tv_wraith` (Glacier).

### Conventions

`sq_` squad · `gr_` group · `ps_` point set · `tv_` trigger volume · `kill_` kill volume ·
`dm_` device machine · `sc_` scenery · `cr_` crate · `obj_` objective · `cs_` command script.
Survival objects carry `_sur_` and two-digit numbers: `sq_sur_phantom_01`.
Unprefixed and 0-based: `generator0`, `ammo_crate0`, `health_pack0`, `spartan_01`.
New content here uses the `fe_` namespace.

---

## Tools

Python 3, stdlib only, cross-platform.

```bash
python3 tools/map/parse_map.py <map.map> --extract   # cache -> tags, stringids, hsc
python3 tools/hsc/decompile.py <scnr.meta> --table <build.xml> --out out.hsc
```

| Tool | Does | Proven |
|---|---|---|
| `tools/blf.py` | Game-variant `.bin` read/write | Byte-identical round-trip, 30 assertions |
| `tools/mpvr.py` / `mpvr_write.py` | Firefight settings + wave table | Byte-identical round-trip, both references |
| `tools/map/reach_cache.py` | `.map` cache parse, 4 header variants | 195 assertions, **synthetic only** |
| `tools/map/reach_write.py` | `.map` write, tag growth, checksum | 387 assertions, **synthetic only** |
| `tools/hsc/decompile.py` | Script-node → `.hsc` | Fixture only |

Opcode tables are not bundled (GPL, from Assembly). Run `decompile.py --fetch-tables`.

**Opcode tables shift between MCC builds** — 1,566 of 1,882 names differ between U0 and U13;
`campaign_metagame_award_points` is `0x24E` on U0, `0x24C` on U13. Read the map's build string and
match the table, or output is confidently wrong.

---

## Facts worth not rediscovering

- PC MCC Reach maps are **not compressed**. Chunk compression is H1A/H2 MCC and Xbox One builds only.
- Only whole-file integrity value is a header checksum = XOR of uint32s past `0xA000`. MCC ships maps with it **zeroed** and does not enforce it. No signature, no per-tag hash.
- Tag sizes are **not stored**. Extents are the gap to the next tag. No free list, so assume zero inter-tag slack; grow by relocating.
- `campaign_metagame_award_points <player> <long>` takes a **signed** long — pass negative to charge. Bungie calls it with +500…+30000.
- There are exactly **10 native Firefight maps**. Breakneck and Highlands are multiplayer-only. Stock MCC has **no Forge on Firefight maps**.
- **Installation 04 is the only stock Firefight map with friendly AI baked in.**
- Script injection into a built cache is ~a month. Patching an existing 4-byte value (price, count, timer) is reachable today.
- Dead ends: TagTool throws `NotImplementedException` on Gen3 and deletes Reach scripts; Invader is Halo CE only; GitHub Actions can't work (Steam depot is ownership-gated). No open reimplementation of `tool build-cache-file` exists for any Gen3 game.

---

## Status

Honest state, so nobody wastes time assuming otherwise.

**Done:** 7 HaloScript files, all engine identifiers grepped from shipped Bungie scripts, economy
matched to the author's real prices, actor cap derived and applied, 13 research documents, working
read tools.

**Never done:** compiled. Run in MCC. Tested at all. There is no `.map` in this repo.

**Top unproven items** (24 logged in `src/hsc/README.md`):
1. `obj_marines` is verified only on Installation 04
2. A *negative* `campaign_metagame_award_points` has no shipped precedent
3. Purchase input `player_action_test_*` is untested
4. 2-arg `(ai_place <ai> <short>)` appears in no shipped script — fallback is two 4-cell squads
5. The `.map` parser and writer have never seen a real map file

**Already playable without any of this:** the original mod. Unearthed (Evolved) + `FIREFIGHT
EVOLVED` gametype, hold **E** at a green `ORDNANCE` terminal in Facility Interior. Marines 500.

---

## Credits

Original design, prices and scenario grammar: **The Vengeful 'Vadam**
([Halo Reach: Evolved](https://steamcommunity.com/sharedfiles/filedetails/?id=3453792163)).
Format documentation: [ReachVariantEditor](https://github.com/DavidJCobb/ReachVariantEditor),
[Assembly](https://github.com/XboxChaos/Assembly), [Reclaimers Library](https://c20.reclaimers.net).
Stock Firefight scripts (not redistributed here) are Bungie's.

Nothing from the original mod or from Bungie is redistributed in this repo.
