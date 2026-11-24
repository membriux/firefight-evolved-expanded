# 15 — Steam Workshop publishing: package format, the game-variant gap, and the permission question

Status key used throughout: **FACT** = read from official documentation, a real
published package, or an open-source reader/writer of the format.
**INFERENCE** = reasoned from facts, labelled as such. **UNVERIFIED** = could not
be confirmed; do not spend an upload attempt on it.

Deliverable built from this document: `workshop/` (manifest, folder skeleton,
placeholder art, `UPLOAD.md`, `WORKSHOP-DESCRIPTION.txt`).

---

## 1. Sources actually read

| Source | What it is | Why it is authoritative |
|---|---|---|
| `learn.microsoft.com/en-us/halo-master-chief-collection/excession/*` | Official Excession (Halo MCC Mod Uploader) documentation — `setup/folderstructure`, `setup/mapfolders`, `creatingmodpackage/creatinghome`, `creatingmodpackage/firefightmapsmod`, `creatingmodpackage/specifyingproperties`, `uploading/uploadinghome`, `appendixa`, `appendixb` | First-party. Describes the UI fields, not the JSON key names. Last updated 2022-11-22. Local text copies: `research/_raw/excession-*.txt` |
| `Advanced-Multiplayer-Collective/ODSTAMP` → `CustomMaps/Homefront/ModInfo.json` + `multiplayer/homefront.json` | A **published** Halo 3 MCC Workshop mod (`SteamWorkshopId: 2898979550`) with its real manifest committed | Real, shipped, accepted by the uploader |
| `brandonchastain/HaloMods` → `CE/published/{TheArena,Snakepit,AlexMap}` | Three published Halo CE mods with manifests (`SteamWorkshopId: 3585293720`, …) | Same |
| `MtnDewIt/TagTool-NET-Test` → `TagTool/BlamFile/MCC/{ModInfo,FirefightMapInfo,MultiplayerMapInfo,CampaignMapInfo,MapImageInfo,InsertionPointInfo}.cs` | TagTool's deserializer for these exact files | Gives the **field names, C# types, and enum values** the docs omit |
| `Nexus-Mods/Vortex` → `extensions/games/game-masterchiefcollection/src/types.ts` | Vortex's MCC extension interface for `ModInfo.json` | Independent second reader; agrees with TagTool |
| `ILoveAGoodCrisp/Foundry` → `blender/addons/io_scene_foundry/tools/cache_builder.py` | The current open-source Reach/MCC mod packager (Blender toolset) | **Writes** a Reach Firefight package end to end, including `firefight/<name>.json` |
| Foundry `mcc/images/{small,large,loading_screen,rally_point_small}.png` and Microsoft's `excession_imagetemplate_bloodgulch{,_large}.png` | Shipped placeholder/template art | Source of the pixel dimensions below |
| Steam Subscriber Agreement §6 (store.steampowered.com/subscriber_agreement/) | The agreement the upload dialog makes you accept | Decides the derivative-work question in §6 below |
| Steamworks `ISteamUGC` docs | Workshop API | Settles dependencies and the 1 MB preview limit |
| Xbox/Microsoft Game Content Usage Rules (xbox.com/en-US/developers/rules) | Microsoft's licence for fan use of its game content | Covers the Halo content underneath everything here |
| `research/04-workshop-mod-teardown.md` | Prior teardown of 'Vadam's published item 3453792163 | Reused, re-checked, not re-derived |

Tooling note: the MCC Workshop item page and the Halo Support articles rate-limit
hard; the Excession docs and GitHub raw files do not. Search engines (DuckDuckGo
HTML, Mojeek) returned bot challenges (HTTP 202/403) throughout this session, so
discovery was done by GitHub code search over the format's key names instead,
which turned out to be strictly better evidence.

---

## 2. The mod package format

### 2.1 Folder structure (FACT, official docs + every real package seen)

```
<root folder>/                  Excession scans these; it only looks ONE level deep
  <mod folder>/                 one per mod; cannot be changed after creation
    ModInfo.json                created/rewritten by Excession; the manifest
    maps/                       all .map cache files, manually placed
    firefight/<name>.json       one per Firefight map (Excession creates these)
    multiplayer/<name>.json     one per multiplayer map
    campaign/<name>.json  + CampaignInfo.json   campaign mods
    images/*.png                all artwork, must be inside the mod folder
```

Three load-bearing rules from the docs:

1. Mod folders must sit **directly** inside a configured root folder. Deeper
   nesting and Excession will not find the mod.
2. `.map` files go in `maps/` **by hand**. Excession never puts them there.
3. **Excession validates nothing.** Quoting the docs: "The current version of
   Excession does not check the existence of `.map` file or correctness of the
   `Scenario File Name` value. During the upload, Excession simply uploads all
   contents of the mod folder to Steam Workshop, without any validation of these
   aspects." A malformed package uploads happily and fails in MCC.

### 2.2 `ModInfo.json` — every field (FACT unless marked)

Key names and nesting are identical in TagTool's `ModInfo.cs`, Vortex's
`types.ts`, Foundry's writer, and all four real published manifests. Enum values
are from `ModInfo.cs`.

| Field | Type | Allowed / observed values | Notes |
|---|---|---|---|
| `ModIdentifier.ModGuid` | GUID string | any UUID | Identity of the mod. Must be stable across updates. |
| `ModIdentifier.HostedModIds.SteamWorkshopId` | int64 | assigned by Steam | Absent before the first upload; Excession writes it back afterwards. Foundry explicitly preserves it on rebuild. |
| `ModVersion` | `{Major,Minor,Patch}` ints | e.g. `1.0.2` | The docs' "Mod Version" field. |
| `MinAppVersion` | `{Major,Minor,Patch}` | observed `1.3065.0`, `1.3385.0`, `0.0.0` | Minimum MCC build. Wrong values produce Excession's **"Mod does not support this version of the product (app)"** on REFRESH. |
| `MaxAppVersion` | `{Major,Minor,Patch}` | observed `9.9999.9`, `1.3528.0`, `0.0.0` | `9.9999.9` is the real-world "any future build" idiom. |
| `Engine` | enum string | `Halo1`, `Halo2`, `Halo3`, `Halo4`, `Halo2A`, `Halo3ODST`, `HaloReach` (`Invalid` = -1 exists but is not a value you write) | This is the field Steam renders as **"Engine: HaloReach"** on the item page. |
| `Title.Neutral` | string | — | MCC mod-browser title. Key is `Neutral` (a localisation slot; only `Neutral` observed in the wild). |
| `Description.Neutral` | string | — | MCC mod-browser blurb. Real packages put Steam BBCode in here too, but the Workshop page description is a separate field you edit on Steam. |
| `InheritSharedFiles` | enum string | `FromMCC`, `FromExternalMod`, `Disabled` | `FromMCC` = take shared files from the base game. `Disabled` matches the docs' Advanced panel text "No source components are required… all shared files are expected to be local to the mod". |
| `ModContents.HasBackgroundVideos` | bool | false in all observed packages | Menu background videos. |
| `ModContents.HasNameplates` | bool | false in all observed packages | |
| `GameModContents.HasSharedFiles` | bool | false in all observed packages | A rebuilt shared cache ships with the mod. |
| `GameModContents.HasCampaign` | bool | — | True is what made Steam render **"Game Content: Campaign"** on 'Vadam's item. |
| `GameModContents.HasSpartanOps` | bool | false | Halo 4 only. |
| `GameModContents.HasController` | bool | false in all observed packages | Present in TagTool and every real manifest; **UNVERIFIED** what it does. Absent from Vortex's interface. Leave false. |
| `GameModContents.MultiplayerMaps` | string[] | e.g. `["multiplayer/homefront.json"]` | Paths relative to the mod folder. |
| `GameModContents.FirefightMaps` | string[] | e.g. `["firefight\\ff50_park.json"]` | Present in TagTool, Vortex and Foundry; this is what Steam renders as **"Game Content: … Firefight"**. Forward slashes appear in real published manifests, backslashes in Foundry output; both are observed, so either should parse (**INFERENCE**). |

Fields that do **not** exist anywhere in the schema: any game-variant field, any
Workshop-dependency field, any `.map` filename field, any price/mechanics field.

Not observed in any real file, so do not invent them: `Title`/`Description`
languages other than `Neutral`; a `Tags` array (Steam's `HaloReach`,
`Campaign`, `Firefight` tags are derived by Steam from `Engine` and
`GameModContents`, not written by you — **INFERENCE**, but the alternative
requires a field nobody has ever observed).

### 2.3 `firefight/<name>.json` — every field

From TagTool's `FirefightMapInfo.cs` plus Foundry's writer plus the structurally
identical published multiplayer examples.

| Field | Type | Notes |
|---|---|---|
| `MapGuid` | GUID string | Per-map identity, stable across updates. |
| `ScenarioFile` | string | **The `.scenario` tag path relative to `tags\`, without the extension** — e.g. `levels\firefight\ff50_park\ff50_park`. Explicitly *not* the `.map` filename. Not validated by Excession. |
| `Title.Neutral` | string | TagTool parses this into a **31-character** buffer (`ParseLocalizedString(31, "Title")`). Keep titles ≤ 31 chars. |
| `Description.Neutral` | string | TagTool parses into a **127-character** buffer. Keep descriptions ≤ 127 chars. |
| `Images.Large` / `.Thumbnail` / `.LoadingScreen` / `.TopDown` | strings | Mod-folder-relative PNG paths. `""` is accepted (observed). |
| `Flags` | string[] | Observed value: `["DisableSavedFilms"]` (Foundry and the published Homefront map), matching the docs' "Allow Saved Films" switch. `[]` = saved films allowed. **Note:** `Flags` is absent from TagTool's `FirefightMapInfo`, so TagTool ignores it; Excession and the game read it. |
| `InsertionPoints` | object[] | Reach Firefight needs **none** — the docs say so explicitly ("Halo: Reach, you do not need to set up Insertion Points"); ODST does. Each entry, if used: `ZoneSetName`, `ZoneSetIndex`, `Valid`, `Title`, `Description`, `Thumbnail`, and an `ODST` sub-object (`IsFirefight`, `ReturnFromMapGuid`). Zone set is a **textual ID** for Reach, a number for Halo 3/ODST. |
| `MapDefaultPrimaryWeapon` | enum string | `e_damage_reporting_type` code name; `_damage_reporting_type_invalid` = no override (observed in real packages). |

Multiplayer-only fields that must **not** appear in a Firefight map file:
`MaximumTeamsByGameCategory`, `MapDefaultPrimaryWeaponForge`, and anything to do
with `multiplayer_object_types.bin` (that import is for MP maps in Reach, H2A and
H4 and decides which MP gametypes are offered).

### 2.4 How maps are referenced (FACT — and the thing most likely to be gotten wrong)

```
ModInfo.json → GameModContents.FirefightMaps[]
             → firefight/<name>.json → ScenarioFile  (tag path, no extension)
maps/<scenario>.map                                   (the built cache)
```

The manifest never names a `.map` file. The cache's filename is whatever
`tool build-cache-file "<tag path>" pc` emitted, i.e. the scenario tag's leaf
name. So for this project the six filenames are fully determined:
`ff50_park.map`, `ff10_prototype.map`, `ff60_airview.map`, `ff70_holdout.map`,
`ff60_icecave.map`, `ff30_waterfront.map`. (Tag-path form confirmed by
`src/hsc/README.md`'s own build step and by `research/07`'s observed
`levels\dlc\cex_ff_halo\cex_ff_halo`. The DLC maps — Unearthed, Installation 04 —
live under `levels\dlc\`, so a `ff_unearthed` tag path is **UNVERIFIED**: check it
in HR-EK before using it.)

Number of Firefight maps per package: **not limited** (official docs).

### 2.5 Images (FACT)

| Image | Pixel size (from shipped templates/placeholders) | Documented requirement |
|---|---|---|
| Thumbnail | **316 x 160** (Microsoft's `excession_imagetemplate_bloodgulch.png`, Foundry's `small.png`) | PNG, inside the mod folder, ~900 KB recommended |
| Large | **668 x 292** (Microsoft's `…_large.png`, Foundry's `large.png`) | PNG, ~900 KB recommended |
| Loading screen | **1920 x 1080** (Foundry's `loading_screen.png`; the docs name 1920x1080 as the example) | PNG, must render at game resolution |
| Top-down | 316 x 160 (Foundry's `top_down` slot) | PNG, ~900 KB recommended. MCC does not render it yet ("currently in development"). |
| Steam item preview | any | **PNG or JPG, under 1 MB**; chosen in the upload dialog; may live outside the mod folder; not packaged. Corroborated by Steamworks `ISteamUGC::AddItemPreviewFile` ("must be under 1MB"). |

The docs state recommended **file sizes** and never pixel dimensions, so the
pixel numbers above are "what Microsoft's own templates and the working
open-source packager use" — safe, but not an engine rule (**INFERENCE**).

### 2.6 Size limits (FACT)

No documented per-item ceiling for MCC. The reference point is 'Vadam's own item:
**7,333,964,512 bytes**. The only hard documented limit in the whole pipeline is
the 1 MB Steam preview image.

### 2.7 Dependencies on other Workshop items (FACT + UNVERIFIED)

- Steam's API *can* express them: `ISteamUGC::AddDependency(parent, child)` adds
  a Workshop item as a dependency of another, and `AddAppDependency(item, appid)`
  marks a required app/DLC. Steam renders these as "Required items".
- **Excession exposes neither.** Its documented upload flow is: pick the mod,
  confirm title/description, optionally pick a preview image, accept the Workshop
  Contribution Agreement, click UPLOAD. There is no dependency control, and
  nothing in `ModInfo.json` corresponds to one.
- 'Vadam's published item has **no `requiredItems` block at all**
  (`research/04` §2).
- **UNVERIFIED:** whether MCC's Workshop web pages let an item owner add required
  items by hand after publishing. Do not design around it.

Conclusion: in practice, an MCC mod **cannot declare a dependency** on another
Workshop item. Cross-mod requirements have to be stated in prose in the
description.

---

## 3. The game-variant gap — confirmed

**Confirmed, three independent ways:**

1. **Schema.** There is no game-variant field in `ModInfo.json`, in any of the
   three map-info schemas, or in TagTool's/Vortex's/Foundry's readers and
   writers. The content taxonomy is exactly: campaign, Spartan Ops, multiplayer
   maps, Firefight maps, shared files, background videos, nameplates, controller.
2. **Tool.** Excession's documented UI has sections for Campaign, Multiplayer
   Maps and Firefight Maps, and nothing else. `.bin` variants are never
   mentioned in the whole documentation set.
3. **Path mismatch.** MCC reads Reach variants from
   `…\Halo The Master Chief Collection\haloreach\game_variants\`. A subscribed
   item lands in `…\steamapps\workshop\content\976730\<published_file_id>\`.
   Nothing in the documented pipeline copies between the two.

**Consequence.** A mod that needs a companion gametype must distribute that
gametype out-of-band, and the Workshop description is the carrier for the link.
That is precisely what the original author does — his description and a pinned
comment both say, verbatim: *"YOU'RE GOING TO WANT MY FIREFIGHT EVOLVED
GAMETYPES, which can be found either through my Vengeful Vadam gamertag's file
share, or you can directly download it here: `https://1drv.ms/u/...`. Place the
bin files in `steamapps\common\Halo The Master Chief Collection\haloreach\game_variants`"*
— i.e. a OneDrive share link plus a manual copy instruction. Steam descriptions
accept BBCode `[url=…]`, so the link is clickable; Steam does flag new/unknown
link domains in *comments* for review, which is one more reason to put the link
in the description body rather than relying on a comment.

Two secondary routes exist and are worth knowing:

- **In-game file share.** Reach's file share under a gamertag can host variants,
  which is 'Vadam's primary channel. Zero hosting cost, but requires the user to
  go and find it in-game.
- **Payload smuggling.** Because Excession uploads the entire mod folder with no
  validation, the `.bin` files *can* be carried inside the Workshop item. The
  game will not load them from there, so the user still has to copy them into
  `game_variants\` by hand — it removes a download, not a step. (Game ignoring
  them in place is **INFERENCE** from the documented search paths.)

---

## 4. What was built: `workshop/`

```
workshop/
  ModInfo.json                     complete, Engine HaloReach, six Firefight maps
  firefight/ff10_prototype.json    one per map: real scenario tag paths, fresh GUIDs,
  firefight/ff30_waterfront.json   titles ≤31 chars, descriptions ≤127 chars
  firefight/ff50_park.json
  firefight/ff60_airview.json
  firefight/ff60_icecave.json
  firefight/ff70_holdout.json
  maps/PUT-COMPILED-MAPS-HERE.md   scenario → required .map filename table +
                                   the explicit "<<< REPLACE >>>" placeholder
  images/thumbnail.png             316 x 160 placeholder
  images/large.png                 668 x 292 placeholder
  images/loading_screen.png        1920 x 1080 placeholder
  images/top_down.png              316 x 160 placeholder
  images/workshop_preview.png      668 x 292 placeholder, for the upload dialog
  images/README.md                 what each image is and what to replace it with
  UPLOAD.md                        numbered Windows publish procedure + field notes
  WORKSHOP-DESCRIPTION.txt         Steam BBCode description, ready to paste
```

`SteamWorkshopId` is deliberately **omitted** from `ModInfo.json` (Excession
assigns it). `ModGuid` and all six `MapGuid`s are freshly generated UUID4s.

---

## 5. The Workshop description

`workshop/WORKSHOP-DESCRIPTION.txt`, written in the register of the successful
MCC Firefight mods surveyed in `research/09` (BBCode headers, a bolded one-line
hook, bullet feature lists, an explicit numbered install block, a known-issues
section, a credits section). It states: the six maps; that purchasable
Marine/ODST reinforcements are the core feature; the full price list (Marines
500, ODSTs 750, turret 750, bank 500/press, objective repair 1,000, turret
upgrade 1,000, Ghost 1,000, set item 2,000, heavy strike 3,000, win 8,000 /
6,000 fortified); that MCC must be launched through *"Play Halo: MCC Anti-Cheat
Disabled (Mods and Limited Services)"*; and where to get the companion gametype
`.bin` files, with a `<<< PASTE GAMETYPE DOWNLOAD LINK HERE >>>` marker.

Attribution to **The Vengeful 'Vadam** is the second block on the page, directly
under the title, before the feature list — with a link to his item and his
profile, an explicit statement that the purchase loop, prices and scenario design
are his, a statement that none of his files are included, and a recommendation to
play his mod first. It is repeated at the top of the credits list.

---

## 6. Etiquette and rules: is publishing this acceptable?

### 6.1 What Steam's terms actually require

Steam Subscriber Agreement §6.D, verbatim: *"with respect to Workshop
Contributions, you represent and warrant that the Workshop Contribution was
originally created by you (or, with respect to a Workshop Contribution to which
others contributed besides you, by you and the other contributors, and in such
case that you have the right to submit such Workshop Contribution on behalf of
those other contributors)."* You also warrant you have *"sufficient rights in all
User Generated Content"* and that submitting it *"does not violate any applicable
contract, law or regulation."* Valve reserves the right to remove any
contribution for any reason. The Workshop Contribution Agreement is the checkbox
in Excession's upload dialog, so clicking UPLOAD *is* making that warranty.

Mapped onto this project:

- **Our code is ours.** The `.hsc` scripts are written from scratch against
  Bungie's stock Firefight scripts; `research/` records that every called symbol
  was grepped out of real Bungie scripts or `hsdoc_hr.txt`. No 'Vadam file, tag,
  model, script or `.bin` is copied.
- **The design is his.** The score-as-currency loop, the specific prices (500 /
  750 and the rest were explicitly rebuilt onto *his* post-playtest numbers — see
  `src/hsc/README.md` correction 17), and the per-map scenario grammar come from
  his mod. Game mechanics, systems and numbers are not copyrightable in US law
  (17 U.S.C. §102(b) excludes ideas, procedures, processes and systems), so this
  is almost certainly not infringement. **But §6.D is an originality warranty,
  not a copyright test**, and "originally created by you" sits awkwardly with a
  mod whose headline feature and price table are someone else's design. This is a
  judgement call I cannot make for you; it is also not the real risk.
- **The underlying Halo content is Microsoft's.** Microsoft's Game Content Usage
  Rules grant a *"personal, non-exclusive, non-sublicenseable,
  non-transferable, revocable, limited license… to create derivative works based
  upon Game Content, strictly for your personal, noncommercial… use"*, and
  revocable at any time. So: free mod, fine; never monetise it, never put it
  behind a Patreon wall.

### 6.2 What the community's norms actually are

Honest answer: I could not find a written code of conduct for the Halo MCC
modding scene, and search engines were blocking automated queries throughout this
session, so this is inferred from observable behaviour rather than quoted from a
rulebook.

What is observable, from the MCC Workshop corpus already captured in
`research/_raw/browse_api.json` and from the platforms' own policies:

- **Credit lists are near-universal.** Essentially every substantial MCC mod page
  carries a `[h1]Credits[/h1]` block naming the author of every borrowed tag,
  model, sound and script — often with an explicit invitation to contact the
  author if a credit was missed ("If I have missed you, PLEASE REACH OUT TO ME!
  Everyone who works on models deserve their fair share of credit"). Asset reuse
  with credit is the normal, accepted mode of work in this scene.
- **The red line is passing someone's work off as your own.** The one explicit
  permission statement in the sampled corpus: *"Please do NOT reupload the armor
  claiming it as your own, if you do reupload please provide credit."* That is
  the norm in one sentence: reuse is fine, credit is mandatory, claiming is not.
- **Nexus Mods codifies the same thing.** Its terms: *"If you do not own all
  rights in the content that you upload to our site, you are solely responsible
  for ensuring that you have all necessary consents and permissions."* Nexus
  additionally runs a per-mod permissions matrix (upload-elsewhere,
  modify-and-reupload, asset-use) precisely because asking the original author is
  the expected step.
- **'Vadam has stated no terms.** Nothing in his Workshop description, his pinned
  comment, his profile, the three linked discussion threads, or his YouTube
  descriptions says anything about permissions, licensing or derivative work. His
  description is features, install instructions, known issues and credits. Silence
  is not permission, and it is not refusal either.
- **He is reachable and he is active.** Public Discord `discord.gg/3WJVDPa`,
  Twitter `@vengeful_vadam`, Patreon, a Steam profile, and a project he has been
  updating since 2018 and was still patching in 2026. He answers comments on his
  item page. The cost of asking is one message.
- **There is a Patreon.** He takes donations for this project. A derivative mod
  on the same storefront, aimed at the same audience, published without a
  conversation, is not a neutral act socially even when it is legally clear.

### 6.3 Recommendation

**Ask him first. Do not publish before he answers.**

The reasoning, plainly:

1. The expensive failure here is not legal, it is social. A takedown request, a
   public accusation of design theft, or a falling-out with the author of the mod
   you are extending costs more than the delay of one message. Workshop removal
   on request is entirely at Valve's discretion under §6.
2. The ask is cheap and the odds are good. You are not reusing his files; you are
   extending his idea to six maps he has not covered, with his credit at the top
   of the page and a recommendation to play his mod first. Modders generally say
   yes to that, and a "yes" converts this from a grey area into a collaboration
   you can state on the page ("with 'Vadam's permission").
3. If he says no, or does not answer within a couple of weeks, the fallback is
   good: **keep it a local mod.** Register the mod folder locally and play it, or
   distribute a plain zip to friends. Nothing about this project requires the
   Workshop to work.
4. If he says yes, change one line in `WORKSHOP-DESCRIPTION.txt` — "with his
   permission" — and publish with confidence.

What to send him: a short message naming his mod, saying what you built (score
purchases for Marines/ODSTs on six stock Firefight maps he has not covered),
stating that none of his files are used and that his credit is at the top of the
page, and asking whether he is OK with it being published. Offer to keep it
private if not. Attach the description text.

Two non-negotiables regardless of his answer, both from Microsoft's Game Content
Usage Rules: **keep it free**, and **do not imply any Microsoft, Halo Studios or
343 endorsement** (the description already carries the disclaimer line).

---

## 7. Alternative distribution routes

| Route | Effort to set up | Effort for the user | Reach | Notes |
|---|---|---|---|---|
| **Steam Workshop** (this package) | High: Windows, Excession, compiled maps, real art, one upload per revision of a multi-GB payload | Lowest: subscribe, EAC-disabled launch, enable in the mod browser — **plus** a manual gametype copy, which the Workshop cannot avoid | Highest by far: 'Vadam's item has 19,675 lifetime subscriptions and 65,172 views | Updates are a full republish of the payload. Prices live in the map, so a price tweak is a multi-GB re-upload. No dependency declaration possible. |
| **Plain zip + README** | Lowest: zip `maps/`, the `.bin` files and an install text file; host anywhere | Highest: unzip, copy maps to the right place, register the mod folder locally (community-reported `%USERPROFILE%\AppData\LocalLow\MCC\Config\ModManifest.txt`, one mod root path per line — **UNVERIFIED**, not in official docs), copy `.bin` files, EAC-disabled launch | Whoever you hand the link to | The only route that ships maps **and** gametypes in one archive. Best for private testing and for friends. Start here. |
| **Nexus Mods** | Medium: account, mod page, screenshots, category/permissions forms; file size limits per file but multi-part uploads are normal | Medium: download, read instructions, copy files by hand (Vortex's MCC extension can automate some of it) | Large Halo MCC modding audience, second only to the Workshop | Has a real permissions system, a changelog, versioned files, and a comment/bug tracker. Also the place where "ask the author" is an explicit, enforced field — which makes §6 matter more, not less. |
| **Original author's OneDrive pattern** | Lowest: upload the `.bin` files to OneDrive, click "Share", paste the `1drv.ms` link into whatever page you have | Low for a small file: click, download, copy to `game_variants\` | Only as far as the page carrying the link | This is exactly how 'Vadam ships his gametypes: files on OneDrive, link in the Workshop description, plus the in-game file share as a backup. Perfect for 21 KB `.bin` files; a bad fit for multi-GB maps (no CDN, no versioning, link rot, and the link can be flagged if posted in comments). |

Practical combination, in order: **zip for yourself and testers → Workshop for
the maps (if 'Vadam is OK with it) → OneDrive/file-share link in the description
for the gametypes**. Nexus is worth adding only if you want a changelog and a bug
tracker, or if you want the Workshop route off the table entirely.

---

## 8. What cannot be prepared in advance

Everything below needs a real compiled `.map`, a Windows machine, or an answer
from another human.

1. **The `.map` files themselves.** Nothing in `maps/` exists yet. HR-EK
   (`tool build-cache-file`) is Windows-only and MCC has no macOS build, so this
   is a hard gate. Every `.map` is also the thing the entire package exists to
   carry — all other blockers are small next to this one.
2. **Which maps actually ship.** The manifest currently claims all six. Any map
   that does not compile must be deleted from `GameModContents.FirefightMaps` and
   its `firefight/*.json` removed. One edit, but it cannot be made in advance.
3. **Real artwork.** Thumbnail, large and loading-screen images are placeholders
   because screenshots require the mod running in MCC.
4. **`MinAppVersion` / `MaxAppVersion`.** Set wide (1.0.0 → 9.9999.9). If
   Excession or MCC rejects the mod with "Mod does not support this version of
   the product (app)", these must be narrowed to the actual installed MCC build —
   a number only available on the machine doing the upload.
5. **`SteamWorkshopId`.** Assigned by Steam on first upload; Excession writes it
   back. Deliberately absent.
6. **Whether Excession adopts a hand-written manifest at all.** It creates and
   rewrites `ModInfo.json` itself. It *should* read this one — the key names,
   nesting and enum spellings match four real published packages and two
   independent readers — but this has not been tested against the tool.
   **UNVERIFIED.** If it refuses, rebuild through its UI using `UPLOAD.md`'s field
   tables as the script.
7. **Scenario-tag spelling for any DLC map.** The six here are stock
   `levels\firefight\…` paths. Unearthed and Installation 04 live under
   `levels\dlc\…`; confirm in HR-EK before adding them.
8. **The companion `.bin` files.** Not on disk — `build/` holds only
   `BUILD-REPORT.md`. Regenerate with `python3 tools/build_variants.py`, then host
   them and paste the link into the description's marker. Also: none of the six
   variants has ever been launched in MCC (`README.md`, "Known limits of this
   layer"), so the description's claims are structurally verified only.
9. **Verification that the whole thing is fun.** Score deduction via a negative
   `campaign_metagame_award_points` is still unproven in-game; the friendly-alive
   cap is derived, not measured. A first-pass publish before a playtest would be
   premature regardless of permissions.
10. **'Vadam's answer.** See §6.3. This is the blocker to clear first, because it
    is the only one that costs nothing to start and takes the longest to come
    back.
