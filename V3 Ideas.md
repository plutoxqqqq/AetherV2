# V3 Ideas — AetherV3 Design Document & Roadmap

> **Scope: BedWars only.** AetherV3 stops being a multi-game framework and becomes a dedicated
> Roblox BedWars client. Every other game is dropped (§2.3).
> Status: **Proposal / brainstorm.** Nothing here is implemented yet.
> Target: AetherV3 (`version.txt` → `4.0`).
> Audit baseline: commit `a8bf1cc`, `version = 3.5`, 123,270 lines of Lua across 33 files.

---

## Table of Contents

1. [Vision & Goals](#1-vision--goals)
2. [Scope: What Is and Isn't BedWars](#2-scope-what-is-and-isnt-bedwars)
3. [Where V2 Stands Today — Full Audit](#3-where-v2-stands-today--full-audit)
4. [The Case for V3: Structural Problems](#4-the-case-for-v3-structural-problems)
5. [Aether Core — The V3 Architecture](#5-aether-core--the-v3-architecture)
6. [Bug Fix Program](#6-bug-fix-program)
7. [GUI Expansion](#7-gui-expansion)
8. [New Modules](#8-new-modules)
9. [Quality-of-Life Program](#9-quality-of-life-program)
10. [Performance Program](#10-performance-program)
11. [Executor Compatibility Layer](#11-executor-compatibility-layer)
12. [Surviving BedWars Updates](#12-surviving-bedwars-updates)
13. [Tooling, Testing & CI](#13-tooling-testing--ci)
14. [Repo Hygiene & File Disposition](#14-repo-hygiene--file-disposition)
15. [Phased Roadmap](#15-phased-roadmap)
16. [Risks & Open Questions](#16-risks--open-questions)
17. [Appendix A — Core API Sketch](#appendix-a--core-api-sketch)
18. [Appendix B — Module Manifest Schema](#appendix-b--module-manifest-schema)
19. [Appendix C — Naming & Style Conventions](#appendix-c--naming--style-conventions)

---

## 1. Vision & Goals

AetherV2 works, and parts of it are genuinely good — the prediction solver, the entity library,
the per-GUI loading screens, the `run()` isolation added recently. But it grew by accretion: four
GUIs that each re-implement the entire core, a 25k-line BedWars file with a 20k-line near-duplicate
next to it, three large unreferenced files in the repo root, and an 8.6k-line "universal" layer
whose only real job is pretending BedWars is one game among many.

It isn't. **Over 90% of the real module surface is BedWars.** BedWars is 161 modules in a
24,971-line file; the entire non-BedWars, non-universal remainder is 22 modules across ~11k lines
that nobody is maintaining.

**AetherV3's thesis, in two parts:**

1. **The interface should be a skin, not the program.** One core, many skins.
2. **The client should know it's playing BedWars.** Every module today is written defensively,
   as if it might be running in Jailbreak. Dropping that pretense means modules can read
   `bedwars.ItemMeta`, `bedwars.QueueMeta`, `bedwars.CombatConstant` and the live team/bed/generator
   state directly — which makes them simultaneously simpler, faster, and far more powerful.

Eight goals, in priority order:

| # | Goal | Success criterion |
|---|------|-------------------|
| G1 | **Narrow to BedWars** | One game, one adapter. All non-BedWars game files deleted; `universal.lua` dissolved into the BedWars core. |
| G2 | **Split core from skin** | A new theme is a ~600-line file, not an 11,000-line fork. `Save`/`Load`/`CreateModule`/`Uninject` exist exactly once. |
| G3 | **Fix everything known-broken** | §6 triage list closed out; no module ships in a state where toggling it errors. |
| G4 | **Expand the GUI hard** | §7: full parity across skins, plus ~35 new interface capabilities including BedWars-native panels. |
| G5 | **Ship a large module wave** | §8: 100+ new BedWars modules, weighted toward the overpowered end. |
| G6 | **QoL everywhere** | §9: 60+ small wins — the stuff that makes daily use pleasant. |
| G7 | **Survive BedWars updates** | §12: a game-build probe, a signature registry, and a self-diagnosing patch report. |
| G8 | **Make it survivable** | Manifests, schemas, a linter, CI, and a test harness so V4 isn't another rewrite. |

**Non-goals for V3:** other games, a different language, a native/external component, a paid
licensing backend, or anything touching account credentials. The whitelist stub in `main.lua`
(§6.1, B-07) should be deleted, not built out.

---

## 2. Scope: What Is and Isn't BedWars

### 2.1 In scope

| PlaceId | What it is | V2 file | Disposition |
|---|---|---|---|
| `6872274481` | **BedWars** (the match place) | `games/6872274481.lua`, 24,971 lines, 161 modules | **The product.** Becomes `game/` in V3. |
| `6872265039` | **BedWars Lobby** | `games/6872265039.lua`, 2,173 lines, 16 modules | Kept — same game. Merges into `game/lobby/` (WinStreak HUD, AutoGamble, OGNameTags, WinstreakSpoofer). |
| `8444591321` | BedWars alias | 45-line stub → `6872274481` | Becomes a line in `game/places.json`. |
| `8560631822` | BedWars alias | 45-line stub → `6872274481` | Becomes a line in `game/places.json`. |

Plus the parts of `games/universal.lua` (70 modules) that are actually used in BedWars — which is
most of them — absorbed and **specialized** rather than kept generic (§5.5).

### 2.2 Out of scope — deleted

| PlaceId | Game | Lines | Note |
|---|---|---|---|
| `71480482338212` | **BedFight** | 19,997 | BedWars-*family*, but a different game. Its header says "adapted from the BedWars module surface" — it is a fork that now needs its own maintenance. **Dropped.** See §16, open question 1: the shared-adapter design makes it cheap to re-add later if wanted. |
| `8768229691` (+5 aliases) | BedWars-like PvP/build game | 1,821 | Dropped. |
| `155615604` (+1 alias) | Prison Life | 2,571 | Dropped. |
| `5938036553` (+2 aliases) | — | 1,835 | Dropped. |
| `139566161526375` | — | 1,295 | Dropped. |
| `77790193039862` (+1 alias) | — | 1,090 | Dropped. |
| `11156779721` | — | 891 | Dropped. |
| `893973440` | Da Hood | 821 | Dropped. |
| `606849621` | Jailbreak | 798 | Dropped. |
| `142823291` | Murder Mystery 2 | 165 | Dropped. |

**Total removed by narrowing scope alone: ~31,300 lines**, plus the multi-game machinery in the
loader and the universal layer.

### 2.3 What "BedWars-only" actually buys us

This isn't just deletion. Assuming BedWars changes what modules *can be*:

- **Real reach**, not guessed reach. `bedwars.CombatConstant` and `bedwars.SwordController` expose
  the actual server-side attack validation shape. Today `Killaura` hardcodes `delta.Magnitude - 14.4`
  as a magic number in the attack packet builder. A BedWars-only client reads the constant.
- **Kit-aware everything.** 30+ `Auto<Kit>` modules exist because each kit was bolted on separately.
  With `bedwars.AbilityController` as a first-class dependency, kits become *data* (§8.6).
- **Item metadata for free.** `bedwars.ItemMeta` (53 references already) gives every item's type,
  tier, damage, cooldown and icon. Shop, hotbar, ESP, and auto-buy modules stop hardcoding names.
- **Match state as a first-class concept.** Teams, beds, generators, queue type, forge level, game
  phase — currently rediscovered independently by a dozen modules. In V3 it's one observable store
  (§5.4) every module subscribes to.
- **Projectile physics from the game's own tables.** `bedwars.ProjectileMeta` and
  `bedwars.BowConstantsTable` (30 references) drive the prediction solver instead of tuned guesses.
- **A GUI that shows BedWars.** Bed tracker, generator timers, team panel, shop panel, kit panel —
  impossible to justify in a generic client, obvious in a dedicated one (§7.6).

---

## 3. Where V2 Stands Today — Full Audit

### 3.1 File inventory

```
                                    lines    role                          V3 disposition
init.lua                              569    bootstrap + loading screen    → boot/
main.lua                              728    loader, teleport, splash #2   → boot/
guis/newer.lua                     11,060    "Nexus/Onyx" skin + full core → skins/nexus/
guis/new.lua                        8,808    default skin + full core      → skins/classic/
guis/old.lua                        4,381    legacy skin + full core       → skins/legacy/
guis/rise.lua                       3,438    Rise skin + full core         → skins/rise/
games/6872274481.lua               24,971    BedWars, 161 modules          → game/  (THE product)
games/6872265039.lua                2,173    BedWars lobby, 16 modules     → game/lobby/
games/universal.lua                 8,653    70 generic modules            → absorbed + specialized
games/71480482338212.lua           19,997    BedFight, 160 modules         → DELETE
games/155615604.lua                 2,571    Prison Life                   → DELETE
games/8768229691.lua                1,821                                  → DELETE
games/5938036553.lua                1,835                                  → DELETE
games/139566161526375.lua           1,295                                  → DELETE
games/77790193039862.lua            1,090                                  → DELETE
games/11156779721.lua                 891                                  → DELETE
games/893973440.lua                   821    Da Hood                       → DELETE
games/606849621.lua                   798    Jailbreak                     → DELETE
games/142823291.lua                   165    Murder Mystery 2              → DELETE
games/*.lua  (12 alias stubs)      45 each                                 → 2 kept as JSON, 10 DELETE
libraries/vm.lua                    1,355                                  → lib/
libraries/hash.lua                  1,351                                  → lib/
libraries/entity.lua                  456                                  → lib/ (BedWars-specialized)
libraries/prediction.lua              425                                  → lib/ (keep; best code here)
libraries/drawing.lua                 190                                  → lib/
libraries/base64.lua                   72                                  → lib/
libraries/string.lua                   18                                  → lib/
libraries/cheatenginelib.lua            2    effectively empty             → DELETE
render.lua                          7,189    unreferenced BedWars render   → port unique bits, DELETE
cv                                 15,652    unreferenced BedWars dump     → port unique bits, DELETE
prem                            487,602 B    unreferenced, minified blob   → DELETE
```

### 3.2 Runtime architecture today

```
loadstring(init.lua)
   └─ splash, folder tree, commit.txt pin
       └─ main.lua
            ├─ tears down shared.vape if present (reinject path)
            ├─ reads profiles/gui.txt  → new | newer | old | rise
            ├─ downloadFile('guis/<gui>.lua')      → returns `vape` (the WHOLE core)
            ├─ downloadFile('games/universal.lua') → 70 modules + entity/prediction/whitelist/sessioninfo
            ├─ downloadFile('games/<PlaceId>.lua') → BedWars (optional, warns on failure)
            └─ finishLoading() → vape:Load(), 10s autosave loop, queue_on_teleport
```

### 3.3 BedWars module surface (the thing we're keeping)

161 modules in `games/6872274481.lua`, across 15 categories. The game-API surface it depends on:

| `bedwars.*` reference | Uses | What it drives |
|---|---:|---|
| `Client` | 67 | Remote access |
| `ItemMeta` | 53 | Item names, tiers, icons, damage |
| `SwordController` | 43 | Killaura, reach, swing effects |
| `BlockController` | 33 | Scaffold, FastBreak, AutoBuildUp |
| `BowConstantsTable` | 30 | Projectile aimbot/aura |
| `AbilityController` | 26 | Every kit module |
| `Store` | 23 | Match state |
| `ProjectileMeta` | 20 | Projectile prediction |
| `BalloonController` | 19 | AutoBalloon, BalloonDisabler |
| `BlockBreaker` | 18 | Breaker, InstantBreak |
| `SoundManager` / `SoundList` | 24 | Kill effects, alarms |
| `SprintController` | 16 | KeepSprint, NoSlow |
| `placeBlock` / `breakBlock` | 24 | All block modules |
| `Shop` | 15 | AutoBuy, buy-armor/sword/pickaxe |
| `QueryUtil`, `KnockbackUtil`, `FovController`, `ViewmodelController`, `Roact`, `UILayers`, `DamageIndicator`, `KillFeedController`, `AnimationType`, `CombatConstant`, `FishingMinigameController` | ~90 | Everything else |

**This table is the real product surface.** In V3 it becomes an explicit, versioned, validated
binding layer (§12) rather than 400 scattered field accesses that silently break on update day.

### 3.4 GUI parity matrix

Counts are occurrences of the identifier in each skin. Zero means the capability does not exist.

| Capability | new | newer | old | rise |
|---|---:|---:|---:|---:|
| Module search | 11 | 34 | **0** | 3 |
| Favourites | 62 | 66 | **0** | **0** |
| Legit-mode tab (`legitapi`) | 17 | 17 | **0** | 3 |
| Overlay bar | 2 | 2 | **0** | **0** |
| Watermark | 1 | 7 | 1 | **0** |
| `CreateTextBox` (→ profile import/export UI) | 6 | 7 | **0** | **0** |
| `CreateBind` (keybind editor) | 2 | 2 | 2 | **0** |
| `applyFeatureTags` (NEW/PATCHED badges) | 2 | 2 | **0** | **0** |
| Tooltips | 65 | 76 | 33 | 14 |

Reading this: **`rise.lua` cannot bind a key to a module at all**, and **`old.lua` has no way to
import or export a profile**, because the widget was never ported. The 72 `Categories.Legit:CreateModule`
registrations have nowhere to render in `old.lua`.

### 3.5 Executor API dependency surface

| Call | Occurrences | Fragility |
|---|---:|---|
| `getcustomasset` | 304 | Low |
| `cloneref` | 225 | Low (shimmed) |
| `setthreadidentity` | 152 | **High** — identity model varies per executor |
| `debug.getupvalue` | 126 | **Critical** — breaks on every BedWars update |
| `hookfunction` | 55 | **Critical** |
| `debug.setupvalue` | 42 | **Critical** |
| `getconnections` | 33 | High |
| `isnetworkowner` | 23 | High — already special-cased for AWP/Nihon |
| `firesignal` / `firetouchinterest` | 13 | Medium |
| `hookmetamethod` / `getnamecallmethod` | 6 | High |

Hardcoded executor branches found: `{'AWP','Nihon'}`, `{'Solara','Xeno'}` (×2), `{'Argon','Delta'}`,
plus 33 references to `'Velocity'` — all inline rather than centralized.

---

## 4. The Case for V3: Structural Problems

### P1 — The core is fused to the skin (the big one)

`Save`, `Load`, `LoadOptions`, `SaveOptions`, `Uninject`, `CreateNotification`, `CreateCategory`,
`CreateCategoryList` and `CreateModule` exist **four times**:

```
                    new.lua  newer.lua  old.lua  rise.lua
CreateCategory        4005      4665      1898     1651
CreateCategoryList    4949      6141      2627     1926
CreateNotification    6348      7625      2996     2219
Load                  6466      7762      3086     2319
LoadOptions           6682      8014      3246     2408
Save                  6715      8047      3275     2437
SaveOptions           6766      8098      3321     2479
Uninject              6776      8108      3331     2489
```

Consequences:

- A config-format change means four edits, or three skins silently break.
- `rise.lua` has a fifth signature for `CreateNotification` (`continued` param) nothing else has.
- New skin work is prohibitively expensive, so `old.lua` and `rise.lua` have quietly rotted (§3.4).
- Bugs get fixed in `new.lua` and stay alive in the other three.
- ~28k lines of skin code where the genuine visual difference is maybe 6k.

### P2 — BedWars exists four times over

`games/6872274481.lua` (161 modules), `games/71480482338212.lua` (160 modules), `render.lua`
(7,189 lines) and `cv` (15,652 lines) all contain overlapping copies of the same BedWars logic.
The `enchant-table` collection block is byte-identical at `render.lua:1120`, `6872274481.lua:1519`,
and `71480482338212.lua:1382`. The `brokenBedTeam` handling appears in all three.

Every BedWars fix is currently a 2–4 file change, and the reflex has become "fix it in one place,
ship, find out later." Narrowing to BedWars-only collapses this to **one** implementation.

### P3 — The universal layer is a costume

`games/universal.lua` is 8,653 lines of code written to work in "any game" — and in practice it
runs in BedWars 95%+ of the time. That genericism has a real price:

- `Killaura` can't ask the game what reach the server accepts, so it hardcodes offsets.
- `ItemESP` can't read `ItemMeta`, so it string-matches names.
- `NoFallDamage` can't know about BedWars' void planes, so it guesses at ground height.
- Nothing knows what a bed, a generator, a team, or a kit is.

Deleting the costume is not a loss of capability. It's the single biggest capability *unlock* in
this document.

### P4 — Dead weight in the repo root

`render.lua`, `cv`, and `prem` are **not referenced by any code path**. `prem` is a single 487 KB
minified line. They were added as porting source material (`e3d40bb "Swap in the cv AntiLasso"`).
They are 30% of the repo by bytes, they poison `grep`, and a stale copy is a liability the moment
someone ports the wrong version of something out of one.

### P5 — Library publication has no contract

`vape.Libraries` is populated from four places at four times:

- `guis/*.lua:774` — `color`, `getcustomasset`, `getfontsize`, `tween`, `uipallet`
- `guis/*.lua:8415` — `targetinfo` (appended after the fact)
- `games/universal.lua:234` — `string`
- `games/universal.lua:275-279` — `entity`, `whitelist`, `prediction`, `auraanims`
- `games/universal.lua:885` — `sessioninfo`, **inside a `run()` block**

The BedWars file captures these at top level (`games/6872274481.lua:78`:
`local sessioninfo = vape.Libraries.sessioninfo`). If the universal module owning line 885 errors
first — and `run()` now swallows that into a warning — `sessioninfo` is captured as `nil` and the
BedWars session tracker dies with `attempt to index nil`, 1,400 lines from the actual cause.

### P6 — No manifest, no schema, no validation

`profiles/features.json` is three flat arrays of module names with no check that they correspond
to real modules. There is no machine-readable list of what BedWars modules exist, their categories,
their options, or their dependencies. Everything is discovered by executing a 25k-line file.

### P7 — Loader is sequential, unverified, and cache-fragile

`downloadFile` does one blocking `HttpGet` per missing file, prepends a watermark comment to every
`.lua`, and writes it. No hash check, no ETag, no parallelism, no rollback if a file lands corrupt.
`commit.txt` pins a ref but nothing validates the pinned commit's files are mutually consistent.

### P8 — The config format is JSON-inside-JSON

`configs/cc.json` is `{"config": "{\"Modules\":{...}}"}` — a JSON document whose only content is a
double-escaped JSON string. Unreadable, undiffable, unmergeable. Preset configs can't be reviewed.

---

## 5. Aether Core — The V3 Architecture

### 5.1 Proposed tree

```
aetherv3/
├── boot/
│   ├── init.lua              # entry: env probe, folder tree, integrity, handoff
│   ├── loader.lua            # manifest-driven parallel fetch + cache + rollback
│   └── splash.lua            # ONE loading screen impl, themed by skin manifest
├── core/
│   ├── core.lua              # the `aether` object; owns everything below
│   ├── registry.lua          # categories, modules, options — pure data
│   ├── module.lua            # module lifecycle: Enable/Disable/Toggle/Clean
│   ├── option.lua            # Toggle/Slider/Dropdown/Bind/Color/TextBox/Vector/Curve
│   ├── scheduler.lua         # unified tick loop, priority buckets, budgets
│   ├── signal.lua            # typed event bus (replaces the vapeEvents metatable)
│   ├── state.lua             # observable store; skins subscribe, never poll
│   ├── config.lua            # profile v2: read/write/migrate/diff/merge
│   ├── keybind.lua           # chords, modes (Hold/Toggle/Always), conflict detection
│   ├── notify.lua            # queue, priority, dedupe, rate-limit, sinks
│   ├── console.lua           # in-GUI log/error surface with stack traces
│   └── compat.lua            # executor capability probe + shims (§11)
├── game/                     # ← BedWars. Not "a game". THE game.
│   ├── bind.lua              # the ONE binding to bedwars.* (§12) — versioned, validated
│   ├── state.lua             # match state: phase, teams, beds, generators, queue, forge
│   ├── beds.lua              # bed tracking, layer counting, protection state
│   ├── generators.lua        # generator tracking, tier, spawn timers
│   ├── shop.lua              # shop/upgrade abstraction over bedwars.Shop + ItemMeta
│   ├── inventory.lua         # hotbar/inventory over bedwars.ItemMeta
│   ├── kits.lua              # kit engine + data-driven kit table (§8.6)
│   ├── combat.lua            # attack packet builder, reach model, hit validation
│   ├── blocks.lua            # place/break primitives over BlockController
│   ├── projectiles.lua       # ProjectileMeta + BowConstantsTable → prediction inputs
│   ├── lobby/                # ← games/6872265039.lua: winstreak HUD, AutoGamble, OGNameTags
│   ├── modules/              # the 161 + the new wave, split by category
│   │   ├── combat/  blatant/  legit/  movement/  render/  visuals/
│   │   ├── world/   utility/  inventory/  kits/   minigames/  exploits/
│   └── places.json           # 6872274481, 6872265039 + aliases 8444591321, 8560631822
├── lib/
│   ├── entity.lua            # evolved from libraries/entity.lua, BedWars-aware
│   ├── prediction.lua        # keep; it's the best code in the repo
│   ├── raycast.lua           # shared wallcheck/reach/LOS — currently reinvented per module
│   ├── esp.lua               # ONE ESP renderer: boxes/tracers/chams/nametags/healthbars
│   ├── drawing.lua           # Drawing API abstraction w/ ScreenGui fallback
│   ├── math3d.lua            # calculatePosition, hitbox math, CFrame helpers
│   ├── net.lua               # remote wrapper: rate limits, latency sim, replay, logging
│   ├── target.lua            # target selection & sorting (shared by every aura)
│   ├── session.lua           # sessioninfo, promoted to a real library
│   ├── string.lua  hash.lua  base64.lua  vm.lua
│   └── ui/                   # skin-agnostic widget primitives
├── skins/
│   ├── _contract.lua         # the interface every skin implements
│   ├── nexus/                # ← newer.lua, reborn
│   ├── classic/              # ← new.lua
│   ├── legacy/               # ← old.lua
│   ├── rise/                 # ← rise.lua
│   └── nova/                 # NEW (§7.1)
├── data/
│   ├── modules.json          # generated module manifest (Appendix B)
│   ├── kits.json             # kit definitions (replaces ~30 Auto<Kit> modules)
│   ├── items.json            # item tiers/priorities for buy + hotbar + ESP
│   ├── signatures.json       # bedwars.* binding signatures per game build (§12)
│   ├── executors.json        # executor quirks (§11)
│   └── features.json         # generated NEW/PATCHED/UPDATED tags
├── assets/
└── tools/                    # linter, manifest generator, schema validator (§13)
```

### 5.2 Core/skin contract (G2)

The core owns *all* state and logic. A skin receives an already-built registry and renders it.
Skins subscribe to the state store; they never own truth.

```lua
-- skins/_contract.lua — every skin returns a table shaped like this
return {
    Id       = 'nexus',
    Name     = 'Nexus',
    Version  = '1.0.0',
    Requires = { core = '>=3.0.0' },

    Palette  = { Main = ..., Text = ..., Accent = ..., Font = ... },
    Splash   = { Enabled = true, Style = 'nexus' },

    Capabilities = {          -- declared, and CHECKED at load
        Search = true, Favourites = true, Tooltips = true,
        Overlays = true, Legit = true, Keybinds = true,
        TextBoxes = true, Watermark = true, Console = true,
        MatchPanels = true,   -- bed/generator/team/shop panels (§7.6)
    },

    Mount        = function(self, core, root) end,
    Unmount      = function(self) end,
    RenderCategory = function(self, category) end,
    RenderModule   = function(self, module) end,
    RenderOption   = function(self, option) end,
    RenderPanel    = function(self, panel) end,     -- BedWars match panels
    Notify         = function(self, notification) end,
    SetVisible     = function(self, visible) end,
}
```

If a skin declares `Favourites = false`, the core hides favourite affordances rather than letting
half a feature render. If a skin declares a capability and doesn't implement the hook, the loader
refuses it with a clear error instead of erroring at first use.

**This one change kills P1 and roughly 20k lines.**

### 5.3 Registry: modules as data

Today a module *is* the closure that builds its GUI row. In V3 a module is a plain table.

```lua
core.Registry:Module{
    Name     = 'Killaura',
    Category = 'Combat',
    Tags     = {'popular'},
    Tooltip  = 'Automatically attacks nearby entities.',
    Since    = '3.0.0',

    Options = {
        { Kind='Slider',   Name='Attack range', Min=0, Max=30,  Default=18, Step=0.1, Unit='studs' },
        { Kind='Slider',   Name='Hit rate',     Min=1, Max=240, Default=20, Unit='hz' },
        { Kind='Dropdown', Name='Hit method',   List={'HitReg','Swing Time'}, Default='HitReg' },
        { Kind='Toggle',   Name='Face target',  Default=false },
        { Kind='Color',    Name='Attack color', Default={H=0.44,S=1,V=1} },
    },

    Depends   = {'lib.target', 'lib.raycast', 'game.combat'},
    GameBind  = {'SwordController', 'CombatConstant'},  -- validated at load (§12)
    Conflicts = {'TriggerBot'},                          -- surfaced in the GUI, not silently broken

    OnEnable  = function(self) end,
    OnDisable = function(self) end,
    OnTick    = { Bucket='combat', Rate=60, Fn=function(self, dt) end },
}
```

Wins: options declared once (search, presets, config schema, and the manifest all read one source);
`Conflicts`/`Depends`/`GameBind` become checkable; `OnTick` goes to the scheduler instead of every
module spawning its own `while task.wait() do` loop.

### 5.4 Match state store — the BedWars-only unlock

One observable store, updated once per tick, that every module reads instead of rediscovering:

```lua
aether.Match = {
    Phase        = 'playing',        -- lobby | starting | playing | ended
    QueueType    = 'duos',
    Teams        = { [1] = {Name='Red', Color=..., BedAlive=true, Players={...}, Layers=2}, ... },
    MyTeam       = 1,
    Beds         = { [1] = {Position=..., Alive=true, Layers=2, Protected=true}, ... },
    Generators   = { {Type='iron', Tier=2, Position=..., NextSpawn=1.8}, ... },
    ForgeLevel   = 1,
    Upgrades     = { Sharpness=false, Protection=1, Haste=false },
    Kits         = { ['PlayerName'] = 'kaliyah', ... },
    Alive        = 8,
    TimeLeft     = 412,
}
```

Downstream effects, all of which are hard today and trivial with this:

- BedESP, BedPlates, BedAlarm, BedAssist, BedProtector all read `Match.Beds` — one source, one
  update path, consistent layer counts.
- AutoBuy knows the forge level and buys what's actually available.
- Killaura can deprioritize players whose bed is already gone (they can't respawn) — or prioritize
  them, user's choice.
- AutoWin becomes a state machine over `Match.Phase` instead of a fragile timing loop.
- The GUI gets a live match panel for free (§7.6).

### 5.5 Absorbing `universal.lua` (G1)

The 70 universal modules split three ways:

| Fate | Count (approx) | Examples |
|---|---:|---|
| **Specialize** — rewritten against BedWars APIs | ~40 | Killaura, ProjectileAimbot, ProjectileAura, AimAssist, TriggerBot, AutoClicker, Reach, ItemESP, NoFallDamage, AntiFall, Fly, Spider, Phase, Blink, Chams, NameTags, HitBoxes |
| **Keep generic** — genuinely game-independent | ~20 | FPS/Ping/Coords HUD, Keystrokes, Radar, Freecam, Fullbright, TimeChanger, ZoomUnlocker, FFlagEditor, AutoRejoin, ServerHop, StaffDetector, MemoryCleaner |
| **Drop** — only existed for other games | ~10 | MurderMystery, PlayerModel/Disguise variants, game-agnostic remote spam helpers |

None of the ~40 lose anything. Every one of them gets *better* because it can finally ask the game
a direct question.

### 5.6 Scheduler (replaces N ad-hoc loops)

One `RenderStepped`/`Heartbeat` driver with named priority buckets and a per-frame budget:

| Bucket | Rate | Contents |
|---|---|---|
| `input` | every frame | keybinds, mouse state |
| `combat` | up to 240 Hz | aura, triggerbot, projectile aim, reach |
| `movement` | every frame | fly, speed, spider, phase, scaffold |
| `render` | every frame, budgeted | ESP, chams, tracers, bed plates |
| `match` | 10 Hz | bed/generator/team/upgrade state scan |
| `world` | 10 Hz | block finders, item finders, loot scans |
| `slow` | 1 Hz | session info, watermark, autobuy, stats |

Each bucket gets a millisecond budget. Overrun degrades gracefully (skip a `world` scan) rather
than tanking FPS. The GUI exposes live per-bucket timings (§7.7 Profiler) so a laggy config can be
diagnosed instead of guessed at.

### 5.7 Config / profile v2 (fixes P8)

- **Flat, readable JSON.** No string-in-string. Presets become reviewable in a diff.
- **Versioned + migrated.** `{"schema": 2, "core": "3.0.0", ...}` with a migration chain; V2
  profiles load and auto-upgrade on first read.
- **Per-mode namespaces.** `profiles/<name>/match.json`, `.../lobby.json` — lobby settings stop
  clobbering match settings.
- **Sparse writes.** Only values differing from default are stored. A profile becomes ~40 lines
  instead of ~4,000, and diffs mean something.
- **Atomic saves.** Write `.tmp`, verify parse, rename. A crash mid-save no longer nukes a config.
- **Autosave with dirty-tracking.** The current unconditional 10s `vape:Save()` loop
  (`main.lua:610`) rewrites the whole config forever, even when idle.
- **Backup ring.** Last 5 saves retained; one-click restore in the GUI.

### 5.8 Loader v2 (fixes P7)

- Fetch a signed `manifest.json` first: file list + SHA-256 + sizes.
- Parallel fetch with `task.spawn`, bounded concurrency, per-file retry with backoff.
- Verify hash before write; on mismatch retry, then fall back to the previous good cache.
- Delta updates: only re-download files whose hash changed.
- `commit.txt` gains a companion `installed.json` recording what's actually on disk.
- Offline mode: complete + hash-valid cache boots with a warning if HTTP is down.
- Kill the watermark hack — track cache metadata in `installed.json` instead of prepending a
  comment to every `.lua` (which offsets every line number in every stack trace by 1).
- **Much smaller payload.** Dropping 10 games and 3 dead files roughly halves what a fresh install
  downloads.

---

## 6. Bug Fix Program

### 6.1 Confirmed defects found during this audit

| ID | Severity | Location | Defect |
|---|---|---|---|
| **B-01** | **Crash** | `games/71480482338212.lua:4854` | `vape.Libraries.calculatePosition(...)` — **never defined anywhere in the repo.** Resolved by deletion under BedWars-only scope, **but check first**: if BedWars' Killaura was ever meant to use the same helper, the function is missing there too. |
| **B-02** | High | `guis/rise.lua` | No `CreateBind` implementation → **keybinds cannot be set at all** in the Rise skin. |
| **B-03** | High | `guis/old.lua` | No `CreateTextBox` → profile import/export UI missing entirely. |
| **B-04** | High | `guis/old.lua` | No `legitapi` → all 72 `Categories.Legit:CreateModule` registrations have nowhere to render. |
| **B-05** | Medium | `games/universal.lua:885` | `sessioninfo` published inside a `run()` block; BedWars captures it at top level (`6872274481.lua:78`). Any earlier failure ⇒ `nil` capture ⇒ delayed crash far from the cause. |
| **B-06** | Medium | `guis/old.lua`, `guis/rise.lua` | `applyFeatureTags` absent → NEW/PATCHED/UPDATED badges never render in two of four skins. |
| **B-07** | Low (dead code) | `main.lua:4-8` | `acceptedWhitelistKey = '1234-5678-9012-3456'` and `isWhitelisted()` are defined and **never called**. Delete both. |
| **B-08** | Low | `guis/old.lua`, `guis/rise.lua` | `license.Closet` honored only by `new.lua`, `newer.lua` and the BedWars file. Closet mode leaks notifications in two skins. |
| **B-09** | Low | `main.lua` / `init.lua` | `buildNewerLoadingScreen` duplicated verbatim across both, with a comment admitting they must be "kept in sync." |
| **B-10** | Low | `libraries/cheatenginelib.lua` | 2 lines. Unfinished stub or leftover. |
| **B-11** | Medium | loader | Watermark comment prepended to every cached `.lua` shifts all reported line numbers by 1 vs. the repo. Every stack trace is off by one. |
| **B-12** | Medium | `guis/rise.lua:2219` | `CreateNotification(title, text, duration, type, continued)` — a 5th parameter no other skin has. Any caller using it is skin-dependent. |
| **B-13** | Low | `games/universal.lua:3575` | `SpinBot` tooltip documents a known limitation ("does not work in first person") rather than handling it. |
| **B-14** | Medium | repo | `render.lua`, `cv`, `prem` unreferenced (§P4) — 30% of repo bytes, guaranteed to drift from the BedWars code they mirror. |
| **B-15** | Medium | `games/6872274481.lua:4727` | A module is commented out with "can't see from the repo, so the module is pulled rather than shipped broken and harmful." Needs a real disposition: fix it, or delete it and its config keys. |
| **B-16** | Low | `games/6872274481.lua` | Killaura's attack packet uses a bare `delta.Magnitude - 14.4` magic constant. Should come from `bedwars.CombatConstant` (§2.3). |

### 6.2 Bug classes to sweep systematically

Each of these is a pattern, not a single site.

**C1 — Unowned coroutines.** Every `task.spawn(function() while ... end)` not registered with a
maid. The splash mote animation (`init.lua:~89`) is the visible example; module code has many.
In V3 `OnTick` replaces almost all of them; any remaining spawn goes through `self:Track(thread)`.

**C2 — Unguarded upvalue surgery.** 126 `debug.getupvalue` + 42 `debug.setupvalue` calls, each of
which silently changes behavior when BedWars updates. V3 wraps all of them in
`compat.upvalue(fn, index, expectedType)` which validates and emits a **named diagnostic**
("SwordController upvalue 3 expected function, got nil — Killaura HitReg disabled") instead of
failing silently or half-working. This is the #1 source of "it broke after the update."

**C3 — Nil-character races.** `lplr.Character:FindFirstChild(...)` patterns assuming the character
exists. Centralize on `entitylib.character` with an `isAlive` guard; the scheduler skips
character-dependent buckets while dead — which in BedWars is a meaningful fraction of the match.

**C4 — Remote signature drift.** `profiles/packages.json` maps ~30 remote names. When BedWars
renames one, modules fail opaquely. `lib/net.lua` validates the map at load and emits one clear
notification listing every remote it could not resolve.

**C5 — Toggle re-entrancy.** Rapid toggling can start a second `OnEnable` before `OnDisable`
finishes. The lifecycle gets a state machine (`Idle → Enabling → Enabled → Disabling`) that queues
transitions.

**C6 — Cleanup leaks on uninject.** `Uninject` exists four times with four teardown orders. One
implementation, exercised by a test that reinjects 20× and asserts instance count returns to baseline.

**C7 — Cross-skin drift.** Anything fixed in `new.lua` and not the other three. §5.2 makes this
class structurally impossible.

**C8 — Duplicated BedWars logic.** Fixes applied to `6872274481.lua` but not `render.lua`/`cv`, or
vice versa. Deleting the duplicates (§14) makes this class impossible too.

### 6.3 Bug-fix infrastructure

- **In-GUI console** (`core/console.lua`): log panel with severity filter, module attribution,
  stack traces, copy button. Diagnostics currently go to `warn()` where nobody reads them.
- **Crash guard**: every `OnEnable`/`OnTick` in `xpcall`. Three errors in 10 seconds auto-disables
  the module, notifies once, and flags it in the GUI with a "show error" affordance.
- **`/aether diag`**: dumps executor identity, capability probe results, BedWars build id, failed
  `bedwars.*` bindings, failed remotes, module error counts, and per-bucket timings to the clipboard.
- **Safe mode**: hold `Shift` while injecting → core + skin only, no modules. Recovery path when a
  config bricks startup.
- **Patch report** (§12.3): on the first launch after a BedWars update, a panel listing exactly
  which bindings changed and which modules are affected.

---

## 7. GUI Expansion

### 7.1 Skins

- **Nexus** (from `newer.lua`) — flagship. Keep the Onyx language, rebuild on the core contract.
- **Classic** (from `new.lua`) — the familiar Vape-like look, full parity.
- **Legacy** (from `old.lua`) — brought to **full** parity: search, favourites, Legit tab, textboxes.
- **Rise** (from `rise.lua`) — brought to full parity, **keybinds fixed** (B-02).
- **Nova** (new) — horizontal command-bar layout: one top bar, `Ctrl+Space` palette, everything
  else summoned on demand. For people who want almost no chrome during a match.
- **Compact** (new) — single-column mobile/small-window layout that actually works on phone
  executors, with touch-sized hit targets.

Because skins are now ~600 lines, community skins become realistic: drop a folder in `skins/`,
it appears in the picker.

### 7.2 Window system

- **Dockable / snappable windows** with edge magnetism and a 4/8/16 px grid toggle.
- **Tabbed windows** — drag one category onto another to tab them together.
- **Resizable categories** with per-window persisted size (currently fixed-size lists).
- **Multi-monitor-safe clamping** — windows can't be dragged off-screen and lost.
- **Layout presets** — save/name/restore whole arrangements independent of module config.
- **Pin / always-on-top** per window; **collapse to title bar**; **per-window opacity**.
- **Focus dimming** — unfocused windows fade to a configurable transparency.

### 7.3 Search & navigation

- **Global fuzzy search** (`Ctrl+F`) across modules *and* options *and* tooltips — today's search
  only reaches module names, and only in two skins.
- **Command palette** (`Ctrl+Space`): type `killa range 22` → jumps to it and sets it.
- **Search operators**: `is:enabled`, `is:new`, `is:patched`, `cat:combat`, `bind:none`,
  `changed:` (differs from default), `kit:kaliyah`.
- **Recently used** and **Most used** virtual categories.
- **Jump-to-conflict** — click a conflict warning, land on the other module.

### 7.4 Option widgets (new kinds)

| Widget | Purpose |
|---|---|
| `Vector` | 3-axis numeric input (hitbox size, offsets) — currently three separate sliders. |
| `Curve` | Draggable curve editor for aim-smoothing / reach falloff / knockback profiles. |
| `KeybindChord` | Multi-key chords with Hold / Toggle / Always / Double-tap modes. |
| `MultiSelect` | Checkbox list — "allowed items", "blacklisted loot", "kits to counter" are all hacked out of dropdowns today. |
| `PlayerPicker` | Live player list with avatars, team color and kit icon for Targets/Friends. |
| `ItemPicker` | **BedWars item picker** backed by `bedwars.ItemMeta` — real icons, real names, tier grouping. |
| `KitPicker` | Kit selector with ability icons and cooldowns. |
| `BlockPicker` | Block type selector for scaffold/build modules. |
| `RangeSlider` | Two-handle min/max (e.g. random delay 0.1–0.3s). |
| `ColorGradient` | Multi-stop gradient editor for ESP/chams/bed plates. |
| `Preview` | Live inline preview (chams material, ESP style, kill effect, bed plate). |

### 7.5 Per-option affordances

- **Reset to default** on right-click, plus a "changed from default" dot.
- **Per-option keybinds** — bind a key to cycle a dropdown or nudge a slider, not just toggle modules.
- **Numeric entry** on every slider (click the value, type it).
- **Ctrl-drag = fine adjust**, **Shift-drag = coarse**.
- **Option-level tooltips with examples**, not one sentence.
- **Link options** — make two sliders move together (e.g. Killaura range and Reach).

### 7.6 BedWars match panels (the payoff for narrowing scope)

These are only justifiable in a dedicated client, and they're the most visible V3 feature.

- **Match panel** — phase, time left, queue type, alive count, your team, forge level, active
  upgrades. One glance instead of four HUD widgets.
- **Bed tracker** — every team's bed: alive/dead, layer count, material, distance, who's near it,
  and a "last damaged 4s ago" ticker. Click a bed → set it as the AutoWin/BedAssist target.
- **Generator panel** — every generator: type, tier, next-spawn countdown, whether someone's
  camping it. Sorted by distance. Click → path to it.
- **Team panel** — per-team roster with kit icons, armor tier, alive/dead, and a per-player threat
  score derived from kit + armor + distance + recent damage.
- **Shop panel** — mirrors `bedwars.Shop`: what you can afford right now, what your AutoBuy queue
  is, what upgrades your team has. Buy directly from the panel.
- **Kit panel** — your abilities with live cooldowns, plus enemy kits seen this match and their
  counters (fed by `data/kits.json`).
- **Inventory panel** — hotbar mirror with item metadata, durability, and drag-to-reorder that
  drives AutoHotbar's saved layout.
- **Resource ticker** — iron/gold/diamond/emerald income rate, time-to-next-upgrade.

### 7.7 Diagnostic panels

- **Console** — logs, errors, filters, copy, stack traces (§6.3).
- **Profiler** — live per-bucket frame cost, module cost ranking, memory, instance count, FPS graph.
  Makes "which module is lagging me" answerable.
- **Network** — outgoing remote calls/sec, per remote, with a rate-limit visualizer and a
  "last 200 calls" inspector. Invaluable for tuning aura cadence and debugging lagback.
- **Target inspector** — full readout on the current target: health, kit, armor, distance,
  predicted position, ping, whether wallcheck passed and why.
- **Binding health** — every `bedwars.*` binding with a green/amber/red status (§12).
- **Keybind map** — every bind in one screen with conflict highlighting.
- **Changelog panel** — release notes in-GUI on first launch after an update.

### 7.8 HUD & overlays

- **HUD editor mode** — drag every overlay (watermark, arraylist, keystrokes, target info, radar,
  session, CPS, coords, FPS, ping, armor, hotbar, bed status, generator timers) freely; snap-to-grid;
  per-element scale/opacity/font/anchor. Overlay positions are largely hardcoded per skin today.
- **Arraylist upgrades**: sort by length/alpha/category/custom, gradient/rainbow/static modes,
  suffix text per module (`Killaura [18.2]`), fade animations, max-height with overflow counter.
- **Keystrokes**: full WASD + mouse + sprint/crouch + CPS, per-key styling, custom key set.
- **Radar**: zoom, rotation-lock, bed/generator icons, team coloring, height indicators, click-to-target.
- **Target HUD**: portrait, health bar, kit icon, armor tier, distance, hit/miss ticker.
- **Notification center**: history, severity filter, dedupe ("×3"), position choice, do-not-disturb
  that still records.
- **Watermark**: templated (`{fps} FPS | {ping}ms | {kills}K | {beds}B | {profile}`), user-editable.

### 7.9 Theming

- **Full theme engine**: every color a named token (`accent`, `surface`, `surfaceAlt`, `text`,
  `textDim`, `positive`, `negative`, `warning`), editable in-GUI.
- **Theme import/export** as a small JSON blob shareable by string.
- **Built-in themes**: Onyx, Midnight, Amethyst, Sakura, Mint, Solarized, Nord, Catppuccin, High-Contrast.
- **Team-color mode** — the accent follows your BedWars team color.
- **Font picker** across bundled fonts + per-element size scaling.
- **Animation speed slider**, including **Reduce Motion** that kills every tween — an accessibility
  win and an FPS win on weak devices.

### 7.10 Accessibility & input

- **Full controller/gamepad navigation** for console-executor users.
- **Touch mode**: bigger hit targets, drag handles, long-press for tooltips.
- **Colorblind-safe palettes** for ESP and team colors — BedWars leans hard on red/green teams.
- **Scaling** from 0.5× to 2.0× with layout that actually reflows.
- **Keyboard-only navigation** with visible focus rings.

---

## 8. New Modules

All BedWars. Existing V2 modules are not re-listed. Each needs its own spec before implementation.

### 8.1 Combat (overpowered tier)

| Module | Concept |
|---|---|
| **OmniAura** | One aura engine replacing Killaura/TriggerBot/AutoClicker/SilentAura. Priority tree (lowest health → bed-less → closest → aiming-at-me → weakest armor), per-target cooldowns, cadence curve, multi-target fan-out. |
| **ReachRamp** | Reach that scales with target velocity and ping instead of a flat number, derived from `bedwars.CombatConstant` — stays plausible at high latency and fixes B-16. |
| **PredictiveAura** | Attacks where the target *will* be using `lib/prediction` — lands hits around bridge corners and on strafers. |
| **KnockbackControl** | Full knockback shaping over `bedwars.KnockbackUtil`: horizontal/vertical multipliers, directional override, jump-reset-aware, per-source rules. |
| **VoidCombo** | Detects when a combo is pushing someone toward the void and biases the aura's angle to finish it. |
| **CritTimer** | Times attacks for the crit window; integrates with the aura cadence and sprint reset. |
| **BlockHit** | Auto block/parry between swings using the game's own block state. |
| **RetaliationBot** | Stays fully idle until damaged, then engages for N seconds. The single best legit-mode feature. |
| **TargetLock** | Hard-locks one target until death or range break; smooth camera or silent. |
| **ArmorBreaker** | Prioritizes the weakest-armor target and switches to the tool that beats their tier. |
| **BedRush** | Combat mode that ignores players and pathfinds to the nearest enemy bed, fighting only what blocks the route. |
| **ClutchAssist** | On a lethal fall or void trajectory, auto-places a block or fires a grapple/pearl. |
| **AutoPot** | Auto-consume heal/speed/jump at thresholds, cooldown- and combat-aware. |
| **KitCounter** | Per-enemy-kit counterplay: auto-dodge known abilities, auto-swap to the counter item — driven by `data/kits.json`. |
| **HitSelect** | Chooses the hitbox part per target based on what the server actually accepts, learned from hit/miss feedback. |
| **AntiBot** | Filters NPCs out of targeting using movement-entropy heuristics. |
| **ReachEnvelope** | Draws the true server-accepted reach envelope, learned live from accepted vs. rejected hits. |
| **SmartSprint** | Sprint-reset and W-tap timing folded into one tuned behavior over `SprintController`. |

### 8.2 Projectiles

| Module | Concept |
|---|---|
| **ProjectileEngine** | One engine over `bedwars.ProjectileMeta` + `BowConstantsTable` replacing ProjectileAimbot/ProjectileAura/AutoShoot/BowAssist. Per-projectile gravity, drag and launch velocity read from the game, not tuned. |
| **ArcPredict HUD** | Renders your own predicted arc and impact point live while charging. |
| **DodgeNet** | Extends ProjectileDodger: predicts every incoming projectile, shows time-to-impact, and picks a dodge direction that doesn't walk you into the void. |
| **FireballAssist** | Auto-aims fireballs at bridges and at players mid-bridge. |
| **TNTAssist** | Placement/throw solver for TNT against beds and defenses, including layer-aware placement. |
| **PearlPath** | Solves ender pearl trajectories to a clicked destination, accounting for gravity and blocks. |
| **ProjectileSpam** | Rate-limited multi-projectile fire with per-type cooldown respect. |

### 8.3 Beds & objectives

| Module | Concept |
|---|---|
| **BedIntel** | Unified bed tracking: layer count, material, distance, damage history, defenders present. Feeds the bed panel (§7.6) and every other bed module. |
| **BedBreaker** | Full-auto bed breaking: tool selection, layer-aware break order, defense-first, resume after interruption. |
| **BedDefense** | Auto-rebuilds your bed's layers with the best available block when damaged, prioritizing the exposed face. |
| **BedAlarm+** | Directional alarm: who is attacking, from where, how many layers are left, with an on-screen arrow. |
| **BedRoute** | Pathfinds to a chosen enemy bed, bridging gaps automatically. |
| **DefenseAnalyzer** | Scores each enemy bed's defenses (layers × material hardness) and recommends the easiest target. |
| **TrapMapper** | Maps enemy traps around each base and routes around or disarms them. |

### 8.4 Resources & economy

| Module | Concept |
|---|---|
| **GenIntel** | Generator tracking: tier, next-spawn countdown, contested state. Feeds the generator panel. |
| **AutoFarm** | Full economy loop: collect from your gens → bank at the forge → buy the next upgrade → repeat, with configurable priorities. |
| **SmartBuy** | Replaces AutoBuy: a priority list over `bedwars.ItemMeta` with affordability, forge level, and "don't buy a sword I already beat" logic. |
| **UpgradeAdvisor** | Recommends the next team upgrade based on match phase and enemy pressure. |
| **AutoBank+** | Banks on a threshold, on a timer, or when threatened — with a safe-route pathfind. |
| **GenSteal** | Prioritized stealing from enemy generators, with an escape route and a "leave before they respawn" timer. |
| **ResourceHUD** | Income rate per resource, time-to-afford for the next target purchase. |

### 8.5 Movement & building

| Module | Concept |
|---|---|
| **Scaffold+** | Predictive bridging: tower / diagonal / god-bridge modes, block conservation, sprint-safe, and a "don't bridge into the void" guard. |
| **AutoBridge** | Bridges automatically along a pathfound route between islands. |
| **PathFly** | Waypoint-based flight along a saved path; loops, reverses, holds altitude. |
| **AutoPath** | A* to a clicked world point with automatic block-placement bridging. |
| **AntiVoid+** | Predicts a void death and cancels velocity, places a block, or triggers a saved recovery action. |
| **Strafe** | Air-strafe momentum control with a configurable friction model. |
| **Rewind** | Records the last N seconds of position; a key rewinds you along it (network-permitting). |
| **Waypoints** | Named saved coordinates per map, with a picker and an on-screen marker. |
| **SmoothFly** | Acceleration-curved flight that avoids the instant start/stop signature. |
| **NoSlow+** | Removes movement penalties (eating, blocking, bow-charging, water) as one unified module over `SprintController`. |
| **AutoParkour** | Auto-jump gaps, auto-vault ledges, auto-mantle around bases. |
| **Blink+** | Full packet-hold blink with a live buffer visualizer and a manual release key. |
| **Freecam+** | Freecam with recording, spline paths, playback and a cinematic mode. |
| **TunnelDig** | Digs a shaped tunnel through defenses with automatic tool switching. |
| **NukeBreaker** | Multi-block breaking in a configurable shape/radius over `BlockBreaker`. |

### 8.6 Kits — from 30 modules to one engine

Today there are 30+ `Auto<Kit>` modules (AutoKaida, AutoKaliyah, AutoNyx, AutoMelody, AutoLani,
AutoPyro, AutoZeno, AutoEmber, AutoNoelle, AutoUma, AutoTaliyah, AutoMarina, AutoElder, AutoDavey,
AutoHannah, AutoCaitlyn, AutoRamil, AutoAdetunde, AutoGingerbreadMan, AutoSheepHerder,
AutoBeekeeper, AutoStarCollector, AutoPickpocket, AutoWhisper, AutoMetal, AutoDrill, …), each
independently written, independently broken, independently maintained.

**Replace all of them with `AutoKit Engine`** — one module, plus `data/kits.json`:

```json
{
  "kaliyah": {
    "display": "Kaliyah",
    "ability": { "controller": "AbilityController", "action": "RequestDragonPunch" },
    "triggers": [
      { "when": "target.distance < 18 && ability.ready", "do": "use" },
      { "when": "self.health < 0.3", "do": "hold" }
    ],
    "counter": { "advice": "Bait the punch, then close.", "items": ["shield"] },
    "cooldown": 12
  }
}
```

Benefits: a new kit is a data entry, not a new module; every kit gets the same cooldown/priority
system for free; `KitCounter` (§8.1) and the kit panel (§7.6) read the same table; a kit that
breaks after an update fails visibly in the binding-health panel rather than silently.

Plus:

- **KitAdvisor** — suggests counterplay for the enemy kits present in the lobby.
- **AbilityTimers** — HUD timers for every enemy ability on cooldown, seeded from kill-feed and
  visual ability cues.
- **KitESP** upgrade — kit icon above every player, with ability-ready state.

### 8.7 Render & visuals

| Module | Concept |
|---|---|
| **UnifiedESP** | One ESP module with a layer system: box / corner-box / tracer / skeleton / chams / nametag / healthbar / armor / kit / distance / off-screen arrow — each independently toggled and colored. Replaces ~8 overlapping modules. |
| **BedPlates+** | Bed plates with layer count, material icons, damage flash, and team color. |
| **GeneratorESP+** | Tier badge, spawn countdown ring, contested highlight. |
| **StorageESP** | Chests and loot with a contents preview where readable. |
| **ProjectileESP** | Incoming projectile trajectories and predicted impact points. |
| **TrapESP** | Enemy traps and mines with arm state. |
| **DamageNumbers** | Floating damage/heal numbers over `DamageIndicator`, with crit styling and a combo counter. |
| **KillFeed+** | Custom feed over `KillFeedController` with kit icons, streaks, and your kills highlighted. |
| **WorldTuner** | The `AetherIRL` / `AetherAbyss` / `AetherStorm` / `AetherAurora` lighting families unified into one module with presets and an FPS-cost label per preset. |
| **XrayPlus** | Material-filtered x-ray with a per-material list and ore highlighting. |
| **NoRender** | Selectively stop rendering particle/effect classes for FPS, per-class checklist. |
| **CustomCrosshair** | Full crosshair editor: shape, gap, thickness, dot, dynamic spread, hit marker. |
| **ViewModel** | FOV, position, rotation, sway, bob over `ViewmodelController`. |
| **CameraTweaks** | Third-person offsets, shoulder swap, no-clip camera, zoom presets over `FovController`. |
| **Trail** | Configurable motion trail for you or targets. |

### 8.8 Utility

| Module | Concept |
|---|---|
| **MacroEngine** | Record and replay action macros; bind them; share as text. |
| **Scripting Console** | Sandboxed in-GUI Lua console with the core + BedWars API exposed and autocomplete. Turns Aether into a platform. |
| **AutoRejoin+** | Rejoin on kick/crash/disconnect with reason detection, backoff, and last-server memory. |
| **QueueManager** | Auto-queue a chosen mode after a match ends; retry on failure; track winstreak across queues. |
| **AFK Suite** | Anti-idle, auto-respond, auto-reconnect, plus an activity log of what happened while away. |
| **ChatFilter** | Client-side mute/highlight rules with regex, per-player. |
| **StaffDetector+** | Badge/group/gamepass heuristics, join alerts, auto-panic action. |
| **PanicButton** | One key: disable every non-legit module, restore camera/FOV/lighting, hide the GUI. |
| **ConfigSync** | Export a config to a shareable string / import by string, with a diff preview before applying. |
| **MatchRecorder** | Logs a match timeline (beds broken, kills, purchases) and can replay it as a summary. |
| **Statistics** | Persistent lifetime stats across sessions — kills, beds, wins, winstreak, per-module usage. |
| **Screenshot / Clip** | Hotkey capture with the GUI auto-hidden. |

### 8.9 Legit mode

Legit deserves real investment — it's currently 72 registrations with no home in two skins.

| Module | Concept |
|---|---|
| **AimAssist+** | Curve-editor-driven smoothing, per-axis speed, FOV falloff, humanized jitter, target-switch delay. |
| **LegitReach** | Reach that stays inside a plausible envelope and randomizes per swing. |
| **Humanizer** | Global input jitter/latency variance applied to every automated action. |
| **VisualsOnly Preset** | One toggle → ESP and HUD, nothing that touches gameplay. |
| **Profiles: Legit / Closet / Rage** | Three curated presets shipped in `configs/`, in readable JSON, replacing the current double-encoded `cc.json` / `rage.json`. |

### 8.10 Exploits

Highest-churn, most-likely-to-break category. V3 should:

- Put every exploit module behind a **capability probe** so it self-disables cleanly when its
  primitive is unavailable, instead of erroring.
- Show a **"last verified against BedWars build X"** date in the GUI so users know what's stale.
- Add **AutoPatchCheck**: on load, compare the live BedWars build against `data/signatures.json`
  and warn which modules are likely broken this build (§12).

---

## 9. Quality-of-Life Program

### 9.1 Configs & profiles

1. Named profiles with descriptions and tags (partially exists — finish it).
2. Per-mode profiles (match vs. lobby), auto-selected.
3. Profile inheritance: `rage` extends `base`.
4. Diff view before applying an imported config.
5. Undo/redo for config changes (`Ctrl+Z` in the GUI).
6. "Compare with default" filter — see only what you changed.
7. Sharing: profiles export to a compressed base64 string.
8. Auto-backup ring + one-click restore.
9. Import a V2 profile with automatic migration.
10. Lock a profile read-only so a tuned config can't drift.

### 9.2 Keybinds

11. Chords (`Ctrl+Shift+K`) and sequences (`G` then `A`).
12. Modes: Toggle / Hold / Always / Double-tap / On-release.
13. Conflict detection with a resolution prompt.
14. Bind profiles, switchable independently of module configs.
15. Bind to option changes (cycle dropdown, ±slider), not just module toggles.
16. Mouse buttons 3/4/5 and scroll bindable.
17. Controller bindings.
18. "Press any key" capture that handles modifiers correctly.
19. Bind to open a specific category or match panel directly.
20. Panic bind reserved and un-rebindable-to-conflict.

### 9.3 Notifications

21. Priority levels with distinct styling.
22. Dedupe with a `×N` counter.
23. Rate limiting so a looping module can't spam the screen.
24. Persistent history panel.
25. Position picker (4 corners + center-top).
26. Per-category mute.
27. Sound cues (optional, with volume) — bed alarm deserves a real one.
28. Toast → banner escalation for critical errors.
29. Progress notifications for long operations (AutoFarm phases, downloads).
30. "Copy details" button on error toasts.

### 9.4 Onboarding & discovery

31. First-run wizard: pick a skin, pick a preset, set the GUI bind, done.
32. Tooltips on **every** option, in every skin (14 in Rise vs 76 in Nexus today).
33. "What's new" panel after an update, driven by generated `features.json`.
34. Guided tour overlay for the main panels.
35. Per-module "how it works" long-form help, expandable inline.
36. Warning badges on modules known to be blatant.
37. Recommended-settings button per module.
38. Empty-state text everywhere ("No targets added — click + to add one").

### 9.5 Everyday friction

39. Remember window positions, scroll offsets, and expanded state per skin.
40. `Esc` closes the topmost window; `Esc` again closes the GUI.
41. Middle-click a module → open its settings directly.
42. Shift-click a toggle → enable and open settings.
43. Right-click a module → context menu (favourite, bind, reset, copy settings, help).
44. Copy/paste settings between modules of the same kind.
45. Bulk actions: disable all in category, disable all non-legit, invert.
46. "Disable all" panic that remembers state so you can restore it.
47. Search history and pinned searches.
48. Drag to reorder modules within a category (the `controller:ApplyOrder` scaffolding exists).
49. Collapse categories to a single row.
50. GUI opacity hotkey for quick screenshotting.

### 9.6 Feedback & clarity

51. Show *why* a module is inactive ("waiting for character", "no valid target", "binding missing").
52. Live value readouts on the module row (current reach, current CPS, current target).
53. Status dot per module: green active / amber degraded / red errored / grey idle.
54. Per-module error surface, with the stack trace one click away.
55. "Last used" and "total enabled time" per module.
56. FPS/ms cost estimate per module in the profiler.
57. Update-available indicator with the changelog one click away.
58. Executor compatibility badge per module (§11).
59. Ping indicator wherever latency-sensitive settings live.
60. "Patched in BedWars build X" state, visually distinct from "disabled" (§12).

---

## 10. Performance Program

- **Instance pooling** for ESP objects and notifications. Reuse, don't recreate per frame.
- **Frustum culling** before any ESP work — skip off-screen entities before computing anything.
- **Distance LOD** — drop ESP detail past configurable distances (boxes only past 100 studs).
- **Lazy skin construction** — build a category's GUI on first open, not at startup.
- **Batched property writes** — group Instance mutations to reduce property-change churn.
- **One scheduler** replacing N spawned loops (§5.6), with per-bucket budgets.
- **Precompiled asset table** so `getcustomasset` isn't called 304 times on path strings.
- **Deferred autosave** with dirty-tracking (§5.7) instead of an unconditional 10s full write.
- **Match-state scan at 10 Hz**, shared — instead of a dozen modules each walking the workspace
  every frame looking for beds, generators and teams. This is probably the single biggest FPS win
  available, and it only exists because of the BedWars-only scope.
- **Startup budget target**: < 2s warm-cache on a mid-tier executor (helped considerably by
  dropping 31k lines of other games).
- **Memory target**: report and cap instance count; leak test in CI (§13).

---

## 11. Executor Compatibility Layer

`core/compat.lua` probes once at boot and publishes a capability table:

```lua
compat.Has = {
    hookfunction = true, hookmetamethod = true, getconnections = true,
    setthreadidentity = true, upvalues = true, isnetworkowner = true,
    customasset = true, gethui = true, websocket = false,
    queueteleport = true, drawing = true, filesystem = true,
}
compat.Executor = { Name = 'Velocity', Version = '...', Quirks = {'identity8', 'noDrawing'} }
```

Then:

- **Modules declare requirements.** `Requires = {'hookfunction','upvalues'}`. Unsupported modules
  render greyed-out with "Requires hookfunction — not available on <executor>" rather than erroring.
- **Quirks table, not inline branches.** The scattered `{'AWP','Nihon'}`, `{'Solara','Xeno'}`,
  `{'Argon','Delta'}` and 33 `'Velocity'` checks move into `data/executors.json` — one place to
  update when a new executor ships.
- **Graceful shims.** Drawing API → ScreenGui fallback. `gethui` → CoreGui → PlayerGui chain.
  `queue_on_teleport` → no-op with a warning that settings won't survive a match teleport.
- **Compatibility badge per module** in the GUI (§9.6, #58).
- **A compatibility report** in `/aether diag` naming exactly which features are degraded.

---

## 12. Surviving BedWars Updates

This is the section that only exists because V3 is BedWars-only — and it addresses the #1 cause
of "the script broke" in this repo's history.

### 12.1 One binding layer

Today there are ~400 direct `bedwars.<Thing>` accesses spread across a 25k-line file, plus 126
`debug.getupvalue` calls reaching into game internals. When BedWars updates, they fail
individually, silently, in whatever order modules happen to run.

`game/bind.lua` becomes the **only** place that touches game internals:

```lua
bind:Define('SwordController', {
    Path      = {'Controllers', 'SwordController'},
    Expect    = { swingSword = 'function', lastAttack = 'number' },
    Fallbacks = { {'Client','SwordController'} },
    UsedBy    = {'Killaura','Reach','CritTimer','BlockHit'},
})
```

At load, every definition is resolved and type-checked once. A failure is recorded, named, and
attributed to the modules that depend on it — instead of erroring 1,400 lines later.

### 12.2 Signature registry

`data/signatures.json` records, per BedWars build, what each binding looked like:

```json
{
  "builds": {
    "2026.7.1": { "SwordController.swingSword": "function(self, tool, target)", "verified": "2026-07-20" }
  }
}
```

The client compares the live build against the registry at startup.

### 12.3 The patch report

On the first launch after a BedWars update, a panel opens listing:

- ✅ bindings that resolved and match the last known signature
- ⚠️ bindings that resolved but changed shape (arity, type) — and which modules use them
- ❌ bindings that failed to resolve — and which modules are therefore disabled

This turns update day from "everything is broken, which module is it" into a checklist. It also
gives users an honest answer instead of a mystery, and gives maintainers a bug report they can act
on without a repro.

### 12.4 Graceful degradation

A module whose binding failed does not error and does not silently no-op. It renders as
**Patched** with a reason string, stays off, and keeps its config intact so it works again the
moment the binding is fixed. `features.json` stops being hand-maintained (three flat arrays with
no validation) and becomes a *generated* output of the binding-health run.

---

## 13. Tooling, Testing & CI

None of this exists today; all of it is cheap relative to what it prevents.

### 13.1 `tools/lint.lua`
- Every `CreateModule` name is unique.
- Every name in `features.json` resolves to a real module.
- Every `vape.Libraries.X` read has a corresponding write **earlier in load order** — catches
  **B-01** and **B-05** mechanically.
- Every `bedwars.X` access goes through `game/bind.lua` — enforces §12.1.
- No `while true do` without a maid registration.
- No skin file defines a core function — enforces §5.2.
- Style: tabs, quote style, no trailing whitespace.

### 13.2 `tools/manifest.lua`
Statically extracts every module + option into `data/modules.json` (Appendix B). Feeds search, the
docs, config schema validation, and the changelog generator.

### 13.3 Schema validation
JSON Schema for `features.json`, `kits.json`, `items.json`, `signatures.json`, `places.json`,
`executors.json`, and profile v2. Validated in CI.

### 13.4 Headless smoke harness
A mock Roblox environment (stub `game`, services, `Instance.new`, executor globals, and a **stub
BedWars API surface** built from `data/signatures.json`) sufficient to `loadstring` core + a skin +
the game layer and assert:

- everything loads without error,
- every binding in `game/bind.lua` resolves against the stub,
- every module can be enabled and disabled 50× without error or instance growth,
- `Uninject` returns instance count to baseline (catches C6),
- config save → load → save round-trips byte-identical.

The BedWars-only scope is what makes this feasible: one game to stub, not eleven.

### 13.5 GitHub Actions
- Lint + schema validation on every PR.
- Smoke harness on every PR.
- Manifest regeneration, committed automatically.
- Changelog generated from manifest diffs (`features.json` becomes an *output*, not an input).
- Release tagging that writes `version.txt` and publishes a signed file manifest for the loader (§5.8).

---

## 14. Repo Hygiene & File Disposition

| File | Disposition |
|---|---|
| `games/71480482338212.lua` (BedFight, 19,997) | **Delete** — out of scope (§2.2). |
| `games/155615604.lua`, `893973440.lua`, `606849621.lua`, `142823291.lua`, `8768229691.lua`, `5938036553.lua`, `139566161526375.lua`, `77790193039862.lua`, `11156779721.lua` | **Delete** — out of scope. |
| 10 of the 12 alias stubs | **Delete**; the two BedWars aliases become `game/places.json`. |
| `render.lua` (7,189) | **Delete** after porting anything unique into `game/`. |
| `cv` (15,652) | **Delete** after porting anything unique into `game/`. |
| `prem` (487 KB) | **Delete** — unreferenced minified blob. |
| `libraries/cheatenginelib.lua` | **Delete** (2 lines) or finish it. |
| `games/universal.lua` | **Dissolve** — ~40 modules specialized into `game/modules/`, ~20 kept generic in `lib/`, ~10 dropped (§5.5). |
| `games/6872274481.lua` | **Split** into `game/` — bindings, state, and per-category module files. |
| `games/6872265039.lua` | **Move** to `game/lobby/`. |
| `main.lua` / `init.lua` splash duplication | **Merge** into `boot/splash.lua`. |
| `main.lua:4-8` whitelist stub | **Delete** (B-07). |
| `configs/*.json` | **Rewrite** in profile v2 flat format. |
| `guis/*.lua` | **Convert** to `skins/*/` against the core contract. |

Also add: `CONTRIBUTING.md` (module authoring guide), `ARCHITECTURE.md`, `CHANGELOG.md`,
`.editorconfig`, `selene.toml` / `stylua.toml`, `.github/pull_request_template.md`.

**Projected line count: ~123k → ~38k**, with substantially more features. Roughly:

| Source | Lines removed |
|---|---:|
| Non-BedWars games + aliases | ~31,300 |
| `render.lua` + `cv` + `prem` | ~23,000 + blob |
| Skin core deduplication (4× → 1×) | ~20,000 |
| `universal.lua` dissolution & dedup | ~5,000 |
| BedWars file dedup against ported render/cv | ~5,000 |

---

## 15. Phased Roadmap

Ordered so every phase ships something usable and nothing depends on a phase that hasn't landed.

### Phase 0 — Scope cut & groundwork (no user-visible change for BedWars players)
- Delete every out-of-scope game file and 10 alias stubs (§2.2).
- Delete `render.lua`, `cv`, `prem`, `cheatenginelib.lua` after porting anything unique.
- Fix **B-07** (dead whitelist) and audit **B-01** against the BedWars file before deleting BedFight.
- Add `tools/lint.lua`, schemas, CI, `.editorconfig`, stylua config.
- Write `ARCHITECTURE.md` documenting V2 as-is, as a reference for the port.

**Ships as a V2 point release.** Faster install, smaller download, zero feature loss for BedWars.

### Phase 1 — Core extraction (the load-bearing phase)
- Build `core/` by lifting the shared implementation out of `guis/new.lua`.
- Define `skins/_contract.lua`.
- Port **Nexus** first (flagship, most complete).
- Keep V2 skins loadable through a compatibility shim so nothing goes dark mid-migration.
- Scheduler, signal bus, state store, console.

### Phase 2 — Skin parity
- Port Classic, Legacy, Rise onto the core.
- Fix **B-02, B-03, B-04, B-06, B-08, B-12** — most cease to exist once there's one implementation.
- Ship the HUD editor and the theme engine.

### Phase 3 — The BedWars layer
- Build `game/bind.lua` + `data/signatures.json` (§12) — **do this before anything else in `game/`**,
  since every module will depend on it.
- Build `game/state.lua` (match store, §5.4) and the beds/generators/shop/inventory/kits helpers.
- Split `games/6872274481.lua` into `game/modules/` by category.
- Dissolve `universal.lua` (§5.5). Fix **B-05** and **B-16** in the process.
- Ship the BedWars match panels (§7.6) — the first visibly *new* thing users get.

### Phase 4 — Config, loader, compat
- Profile v2 + migration from V2 profiles.
- Loader v2 with hashes, parallel fetch, rollback, offline mode; fixes **B-11**.
- `core/compat.lua` + `data/executors.json`.
- Binding-health panel + patch report (§12.3).

### Phase 5 — Module wave
- §8 in order: Combat → Projectiles → Beds → Resources → Movement → Kits engine → Render → Utility → Legit.
- The **AutoKit Engine** (§8.6) is the highest-leverage single item: it retires 30 modules.
- Every new module ships with a manifest entry, a tooltip, a `GameBind` list, and a compat declaration.

### Phase 6 — QoL wave
- §9, front-loading keybinds, notifications, search, and onboarding.

### Phase 7 — Polish & release
- Profiler and Network panels.
- Headless smoke harness in CI (§13.4).
- Docs, changelog, `version.txt` → `4.0`.

---

## 16. Risks & Open Questions

| Risk | Mitigation |
|---|---|
| **Users on the dropped games lose support.** | Announce the scope cut clearly before Phase 0. V2 stays available on a tag for anyone who needs the other games. This is a deliberate trade: one game done properly beats eleven done badly. |
| **The rewrite stalls halfway** and the repo carries both architectures. | The compatibility shim in Phase 1 is mandatory. Every phase must leave `main` shippable. |
| **Dropping BedFight loses users.** | Quantify first. The shared-adapter design (§5.1) means re-adding it later is a `game/variants/bedfight/` folder with overrides, not a 20k-line fork. |
| **`universal.lua` dissolution loses a behavior** nobody documented. | Before dissolving, generate the module + option list from the manifest tool and diff it against the post-port list. Any asymmetry is explicit, never accidental. |
| **Users lose configs** in the profile v2 migration. | One-way-safe: V2 files are copied to `profiles/v2-backup/` untouched before any write. |
| **BedWars ships a large update mid-port.** | §12 is scheduled early (Phase 3, first item) precisely so update day becomes a diff against `signatures.json` rather than an archaeology session. |
| **Executor variance breaks the compat probe itself.** | Probe every capability inside `pcall`; a probe failure means "not available," never a crash. |
| **Scope.** §7–9 together are ~200 items. | They're deliberately independent and phased. Phases 0–4 are the actual V3; 5–7 are continuous delivery after it. |

**Open questions to decide before Phase 1:**

1. **BedFight: dropped, or a variant?** This document assumes dropped. If it has real usage, the
   alternative is `game/variants/bedfight/` carrying only genuine deltas — perhaps 800 lines instead
   of 20,000. Decide with usage data, not vibes.
2. **Four skins, or two plus community skins?** Recommendation: keep all four — they're cheap once
   the core is split — but gate them behind the capability contract so a half-finished skin can't ship.
3. **Is `Legit` a category or a *mode* that reshapes every module's defaults?** Recommendation: a
   mode. It's what people actually mean, and it makes the 72 Legit registrations coherent.
4. **Does the Scripting Console (§8.8) ship enabled by default?** Recommendation: no — opt-in behind
   a confirmation, since it runs arbitrary code against the core.
5. **Do we version the module manifest independently of the core**, so a broken binding can be
   hotfixed without a full release? Recommendation: yes, once Loader v2 lands.

---

## Appendix A — Core API Sketch

```lua
local aether = shared.aether            -- shared.vape aliased for back-compat

-- Registry
aether.Registry:Category{ Name = 'Combat', Icon = 'combaticon', Order = 2 }
aether.Registry:Module{ ... }            -- see §5.3
aether.Registry:Get('Killaura')
aether.Registry:Find('aura')             -- fuzzy
aether.Registry:ByTag('new')

-- Module instance
mod.Enabled          -- read-only; use Toggle/Enable/Disable
mod:Enable() / mod:Disable() / mod:Toggle()
mod.Options['Attack range'].Value
mod:Track(connection|thread|instance|function)   -- the maid; auto-cleaned on disable
mod:Status('waiting for character')              -- surfaces in the GUI (§9.6 #51)
mod:Error(err)                                   -- routed to console + crash guard

-- BedWars match state (§5.4)
aether.Match.Phase                       -- lobby | starting | playing | ended
aether.Match.Beds[teamId].Layers
aether.Match.Generators                  -- sorted by distance
aether.Match:NearestEnemyBed()
aether.Match:ThreatScore(player)
aether.Signals.BedBroken:Connect(fn)
aether.Signals.MatchPhaseChanged:Connect(fn)

-- BedWars bindings (§12.1) — the ONLY path to game internals
aether.Bind.SwordController
aether.Bind:Health()                     -- resolved / changed / failed, per binding
aether.Bind:Require('BlockController')   -- named error the crash guard understands

-- Scheduler
aether.Scheduler:Add('combat', 60, fn)
aether.Scheduler:Budget('render', 3)     -- ms/frame
aether.Scheduler:Stats()                 -- feeds the Profiler panel

-- State (observable; skins subscribe)
aether.State:Get('gui.visible')
aether.State:Set('gui.visible', true)
aether.State:Subscribe('gui.visible', fn)

-- Config
aether.Config:Save() / :Load(profile) / :Export() / :Import(str)
aether.Config:Diff(profileA, profileB)

-- Notifications
aether:Notify{ Title='Aether', Text='...', Duration=5, Kind='info', Key='dedupe-key' }

-- Compat
aether.Compat.Has.hookfunction
aether.Compat:Require('hookfunction')
```

---

## Appendix B — Module Manifest Schema

`data/modules.json`, generated by `tools/manifest.lua`, consumed by search, docs, the changelog
generator, and profile schema validation.

```json
{
  "schema": 1,
  "generated": "2026-07-28T00:00:00Z",
  "core": "3.0.0",
  "game": "bedwars",
  "modules": [
    {
      "id": "combat.killaura",
      "name": "Killaura",
      "category": "Combat",
      "tags": ["popular"],
      "since": "1.0.0",
      "updated": "3.0.0",
      "status": "active",
      "requires": ["hookfunction", "upvalues"],
      "gameBind": ["SwordController", "CombatConstant"],
      "conflicts": ["TriggerBot"],
      "tooltip": "Automatically attacks nearby entities.",
      "options": [
        { "kind": "Slider",   "name": "Attack range", "min": 0, "max": 30, "default": 18, "unit": "studs" },
        { "kind": "Slider",   "name": "Hit rate",     "min": 1, "max": 240, "default": 20, "unit": "hz" },
        { "kind": "Dropdown", "name": "Hit method",   "list": ["HitReg", "Swing Time"], "default": "HitReg" },
        { "kind": "Toggle",   "name": "Face target",  "default": false }
      ]
    }
  ]
}
```

`status` is one of `active` | `degraded` | `patched` | `deprecated`, driven by the binding-health
run (§12.4) — replacing the hand-maintained three-array `features.json`, which becomes a generated
output.

---

## Appendix C — Naming & Style Conventions

Enforced by `tools/lint.lua` + stylua.

- **Indentation:** tabs. **Strings:** single quotes. **Line length:** soft 120.
- **Module names:** `PascalCase`, no spaces (matches commit `e3d40bb`'s cleanup).
- **Option names:** `Sentence case` with spaces (`'Attack range'`) — they're user-facing.
- **Files:** `lowercase.lua`; directories `lowercase`.
- **Libraries:** returned as a table named `module`, published through the core, never via `_G`.
- **Globals:** none. `shared.aether` is the only shared handle; `_G.AetherV2*` splash globals go away.
- **Game internals:** never accessed directly — always via `aether.Bind` (§12.1), enforced by the linter.
- **Comments:** explain *why*. The existing comments at `main.lua:11-16` and `universal.lua:31-33`
  are the model — they explain the failure that motivated the code.
- **Every module** ships with: a tooltip, a manifest entry, a `Requires` list, a `GameBind` list,
  and an `OnDisable` that fully reverses `OnEnable`.

---

*End of document. Sections 6–9 are actionable as written; sections 2, 5 and 15 need sign-off on
the open questions in §16 before Phase 1 starts — in particular question 1 (BedFight), which
changes what Phase 0 deletes.*
