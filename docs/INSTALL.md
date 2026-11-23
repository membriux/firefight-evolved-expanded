# INSTALL — where things go

## There are no `.map` files in this zip yet

This package contains **source and tools**, not finished maps. A `.map` has to be compiled on
Windows with the Halo Reach Editing Kit. See "Build the maps" below.

So read this in two parts: what you can do **tonight** with zero tools, and what the folder is
**for** when you get to a Windows PC.

---

## 1. Tonight — you already own buyable Marines

You do not need anything in this zip for this. You played the wrong map.

The modded maps are named **"(Evolved)"** in the map list.

1. Launch MCC via **Play Halo: MCC Anti-Cheat Disabled (Mods and Limited Services)**
   (`steam://launch/976730/option2`)
2. Firefight → map: **Unearthed (Evolved)** ← this is the one with buyable **Marines**
3. Game type: **FIREFIGHT EVOLVED** (the `.bin` you already placed)
4. In-game, walk to a green cube waypoint — one is labelled **ORDNANCE**
5. **HOLD E.** Do not tap it.

The hub on Unearthed is in **Facility Interior**. Troopers cost **500 points**, roughly thirty
seconds of play. Armor abilities are in the **Store Room**, vehicles spawn in the garage, and the
MAC Cannon win terminal is out on the **Crane**, deliberately outside the defensible area.

Installation 04 instead gives you ODSTs, an auto turret, a Falcon gunner run and a Sentinel hack.
Its terminals are on the **Upper Deck** and in **Station 2 Interior**.

If no prompt appears: you are not close enough to a terminal, you tapped instead of held, you are
under the price, or the item is round-gated (`Auto Turret not available until Round 3`, locked
ones read `TERMINAL LOCKED`).

---

## 2. Where files go

| What | Where |
|---|---|
| Game variants (`.bin`) | `...\Halo The Master Chief Collection\haloreach\game_variants\` |
| Workshop map mods | Steam handles these — `...\steamapps\workshop\content\976730\<id>\` |
| Your own compiled maps | `...\Halo The Master Chief Collection\haloreach\maps\` |
| HR-EK project tags | `<HREK install>\tags\` |
| HR-EK compiled output | `<HREK install>\maps\` — copy from here to the MCC `maps\` folder |

Create `game_variants` if it does not exist. Files go in **loose**, not in a subfolder, and not as
a zip. **Fully quit and relaunch MCC** afterwards — it scans for variants once, at the title
screen.

Launching a map mod requires the **anti-cheat-disabled** option above. That requirement comes from
the map package, not from gametype files.

---

## 3. Build the maps (Windows only)

Nothing here can be compiled on macOS. You need:

- **Halo Reach Editing Kit** — Steam app **1695793**, free. Tools: Foundation, Sapien, Tool.
- **Assembly** — https://github.com/XboxChaos/Assembly — reads *and writes* Reach map scripts.
  **Use Assembly over the tools in `tools/hsc/`**; ours are read-only and exist only because
  Assembly is a Windows WPF app.

Order of work:

1. Install HR-EK.
2. **Start with Installation 04 (`cex_ff_halo`), not a new map.** Vanilla Installation 04 already
   ships friendly ODSTs, a Pelican script, and a working `obj_marines` objective. You would be
   extending proven code instead of writing squads from nothing.
3. Follow the numbered steps in `src/hsc/README.md`.
4. Compile with Tool, then copy the `.map` into MCC's `haloreach\maps\` folder.

### Send me the author's map and I can do better

If you copy **one** file to Drive, I can decompile his actual implementation here:

```
...\steamapps\workshop\content\976730\3453792163\cex_ff_halo.map
```

Then on the Mac:

```bash
python3 tools/map/parse_map.py cex_ff_halo.map --extract
```

That yields his real prices, his exact `ai_place` squad names, his purchase-input method, and how
he keeps allied AI out of the wave-clear count. Reach maps on PC MCC are not compressed, and there
is an `hsc*` tag group holding HaloScript **source** — if he left it in, you get his actual code,
not a reconstruction.

---

## 4. What is in this zip

| Folder | Contents |
|---|---|
| `src/hsc/` | 7 HaloScript files — the purchase system and six map scenarios |
| `research/` | 11 documents: formats, toolchain, AI spawning, the author's design system, mod survey |
| `tools/` | 11 Python tools — BLF read/write, mpvr decode/encode, `.map` parser, HaloScript decompiler |
| `reference/` | The author's two original `.bin` files, unmodified |
| `research/_raw/` | 241 reference files, including Bungie's own Firefight scripts for all six maps |

Read `README.md` first — it carries the full findings and every open question.

---

## 5. Honest status

- **Nothing here has run in MCC.** All confidence is structural, not tested.
- **Marines cannot come from a game variant.** Firefight variants are engine type 4 (survival),
  which has no script field; Megalo has no AI-spawn action and no Marine squad index. Confirmed
  four separate ways, including the author's own changelog, where prices ship in *map* updates.
- The economy now matches his real playtested prices (Marines 500, ODSTs 750, win 8,000) rather
  than my earlier estimate, which measurement refuted.
- 24 open questions are logged in `src/hsc/README.md`. The big three: `obj_marines` is verified
  only on Installation 04, a *negative* `campaign_metagame_award_points` has no shipped precedent,
  and the purchase input `player_action_test_*` is untested.
