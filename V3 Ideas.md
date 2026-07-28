# V3 Ideas — AetherV3 (Roblox BedWars only)

> **Scope: Roblox BedWars only.** AetherV3 stops being a multi-game framework and becomes a
> dedicated Roblox BedWars client. Every other game is dropped.
> **This revision is about modules, GUI, bugs and behaviour** — not a repo rewrite. The structural
> work is compressed to §3: only the plumbing the rest of this document actually needs.
> Status: proposal. Target `version.txt` → `4.0`. Baseline: `a8bf1cc`, v3.5, 123k lines / 33 files.

---

## Contents

1. [Scope & Thesis](#1-scope--thesis)
2. [Vocabulary — Roblox BedWars, Not Minecraft](#2-vocabulary--roblox-bedwars-not-minecraft)
3. [Foundations](#3-foundations)
4. [Bug Fix Program](#4-bug-fix-program)
5. [GUI Expansion](#5-gui-expansion)
6. [Modules](#6-modules)
7. [Behaviour & QoL](#7-behaviour--qol)
8. [Performance](#8-performance)
9. [Surviving BedWars Updates](#9-surviving-bedwars-updates)
10. [Roadmap, Housekeeping & Open Questions](#10-roadmap-housekeeping--open-questions)

---

## 1. Scope & Thesis

Over 90% of the real module surface is BedWars: 161 modules in `games/6872274481.lua` (24,971
lines) plus 16 in the lobby file, against 22 modules across ~11k lines of games nobody maintains.
`games/universal.lua` (8,653 lines, 70 modules) is written as if it might be running in Jailbreak —
and in practice runs in BedWars ~100% of the time.

**Thesis: the client should know it's playing BedWars.** Dropping the generic pretense is not a
loss of capability, it's the biggest capability *unlock* available:

- `bedwars.CombatConstant` / `SwordController` expose the real server-side attack validation, so
  reach and hit registration stop being magic numbers (`delta.Magnitude - 14.4`, today).
- `bedwars.ItemMeta` (53 refs) gives every item's type, tier, damage, cooldown and icon — shop,
  hotbar, ESP and buy modules stop string-matching names.
- `bedwars.ProjectileMeta` + `BowConstantsTable` (30 refs) drive projectile prediction from the
  game's own tables instead of tuned guesses.
- `bedwars.AbilityController` (26 refs) + `BedwarsKitMeta` turn `AutoKit`'s 325 lines of hardcoded
  per-kit closures into a data file, and bring home the eight kit modules that escaped it (§6.10).
- Beds, generators, teams, forge level and match phase become one shared observable store instead
  of a dozen modules each walking the workspace every frame.

**Goals, in priority order:**

| # | Goal | Success criterion |
|---|------|-------------------|
| G1 | Fix everything known-broken | §4 triage closed; no module errors on toggle. |
| G2 | Expand the GUI hard | §5: full parity across skins + BedWars-native match panels. |
| G3 | Ship a module list worth maintaining | §6: 223 V2 modules → 70, each with a named binding; 9 genuinely new, 12 deleted. |
| G4 | Behaviour that feels deliberate | §7: conflicts, priorities, safety guards, QoL. |
| G5 | Survive BedWars updates | §9: one binding layer, signature registry, patch report. |
| G6 | Narrow to BedWars | Non-BedWars game files deleted; `universal.lua` specialized in. |

**Non-goals:** other games, other languages, native components, licensing backends, anything
touching account credentials. The dead whitelist stub in `main.lua` gets deleted, not built out.

**Dropped (~31,300 lines):** BedFight (`71480482338212`, 19,997), Prison Life, Da Hood, Jailbreak,
MM2, and five unidentified places, plus 10 of 12 alias stubs. Kept: `6872274481` (match),
`6872265039` (lobby), and the two BedWars aliases as data.

---

## 2. Vocabulary — Roblox BedWars, Not Minecraft

Chunks of V2 (and of the first draft of this document) carry Minecraft-client vocabulary and
Minecraft mechanics that **do not exist in Roblox BedWars**. Every module spec must be written
against the game we're actually in. This is a review checklist, not a style note.

**Does not exist here — never design against it:**

| Minecraft-ism | Reality in Roblox BedWars |
|---|---|
| Right-click sword blocking / block-hitting | No sword block. There *is* a **shield item** (see `InfiniteShield`) — defensive timing modules go through the shield, not the sword. |
| Jump/sprint **critical hits** | No crit mechanic. Attack timing is a cooldown window from `CombatConstant`, nothing more. Do not ship "CritTimer" or crit-styled damage numbers. |
| **W-tap / sprint-reset** knockback tech | Knockback comes from `KnockbackUtil`; sprint is `SprintController` state. Model those directly; the MC timing folklore doesn't transfer. |
| **God-bridge / ninja-bridge** | Bridging is block placement against `BlockController`. Modes are tower / flat / diagonal / downward — not MC technique names. |
| **Ore x-ray**, caves, mining ore | No ores. Resources come from **generators**. `Xray` is still useful — but as *see-through-bed-defenses and base walls*, not ore hunting. |
| **Hunger / eating**, gapples | No hunger. Consumables are potions (heal / speed / jump) via `AutoConsume`. |
| **Elytra**, boats, water/`Swim`, Jesus-walk | Vertical mobility is **balloons** (`BalloonController`), **lasso**, and kit abilities. Maps are void, not ocean. |
| Ender pearls | **Telepearls** (`AutoPearl`), plus kit teleports (`MissileTP`, `RavenTP`). |
| Anvils, enchanting like MC | There *is* an enchant table in-game (the repo already collects from it) — model it from `ItemMeta`, not from MC's enchanting rules. |

**Does exist and is under-used — design against these:** kits and `AbilityController` (Owl, Terra,
Vulcan, Raven, Krystal, Triton, Kaliyah, Kaida, Nyx, Melody, Lani, Pyro, Zeno, Ember, Noelle, Uma,
Taliyah, Marina, Elder, Davey, Hannah, Caitlyn, Ramil, Adetunde, GingerbreadMan, SheepHerder,
Beekeeper, StarCollector, Pickpocket, Whisper, Metal, Drill…), generators and forge tiers, team
upgrades, the shop (`bedwars.Shop`), traps/landmines, balloons, lassos, telepearls, fireballs, TNT,
the fishing minigame (`FishingMinigameController`), queue types, winstreak, and the void.

**Action:** sweep every existing tooltip, option name and module name for MC vocabulary during the
port (§4, C9). A user reading "block hit" in a Roblox client learns the wrong mental model.

---

## 3. Foundations

The minimum structure §4–§7 assume. Everything here exists to make modules and the GUI better; none
of it is a repo redesign for its own sake.

**F1 — One binding layer.** ~400 direct `bedwars.<Thing>` accesses and 126 `debug.getupvalue` calls
are spread across a 25k-line file, failing individually and silently on update day. `game/bind.lua`
becomes the only path to game internals:

```lua
bind:Define('SwordController', {
    Path   = {'Controllers', 'SwordController'},
    Expect = { swingSword = 'function', lastAttack = 'number' },
    UsedBy = {'OmniAura','ReachControl','ShieldSync','HitboxSolver'},
})
```

Resolved and type-checked once at load; a failure is named, attributed to its modules, and surfaced
(§9) instead of erroring 1,400 lines later.

**F2 — Match state store.** One observable table, scanned at 10 Hz, that every module reads instead
of rediscovering: `Phase`, `QueueType`, `Teams`, `Beds` (position / alive / layers / material),
`Generators` (type / tier / next spawn / contested), `ForgeLevel`, `Upgrades`, `Kits` per player,
`Alive`, `TimeLeft`. This single change is what makes the bed/generator/team/shop panels (§5.6),
the whole objectives module family (§6.8), and the biggest FPS win (§8) possible.

**F3 — Modules as data.** A module is a table (name, category, tooltip, options, `Depends`,
`GameBind`, `Conflicts`, `OnEnable`/`OnDisable`/`OnTick`), not a closure that builds its own GUI
row. Options declared once feed search, presets, config schema, conflict detection and the GUI.

**F4 — One scheduler.** Named priority buckets with per-frame millisecond budgets — `input` (every
frame), `combat` (≤240 Hz), `movement` (every frame), `render` (budgeted), `match` (10 Hz), `world`
(10 Hz), `slow` (1 Hz) — replacing N ad-hoc `while task.wait()` loops. Overrun degrades a bucket
instead of tanking FPS, and per-bucket timings feed the profiler panel.

**F5 — Core/skin split.** `Save`, `Load`, `LoadOptions`, `SaveOptions`, `Uninject`,
`CreateNotification`, `CreateCategory`, `CreateCategoryList` and `CreateModule` currently exist
**four times**, once per skin (~28k lines of skin code where the genuine visual difference is maybe
6k). One core, skins render an already-built registry against a declared capability contract. This
is the single change that makes §5 affordable and kills bug class C7 outright.

**F6 — Config v2.** `configs/cc.json` is `{"config": "{\"Modules\":{…}}"}` — a JSON document whose
only content is a double-escaped JSON string. Flat readable JSON, sparse writes (only non-defaults),
atomic save, versioned with migration from V2, backup ring.

*Also assumed, not specified here:* loader with hash verification and parallel fetch, executor
capability probe (`compat.Has.hookfunction` etc. — 152 `setthreadidentity`, 55 `hookfunction`, 33
`getconnections` calls need it), and `data/` for kits, items, signatures, executors.

---

## 4. Bug Fix Program

### 4.1 Confirmed defects

| ID | Severity | Location | Defect |
|---|---|---|---|
| **B-01** | Crash | `games/71480482338212.lua:4854` | `vape.Libraries.calculatePosition(...)` — never defined anywhere in the repo. Deleted with BedFight, **but check the BedWars Killaura for the same missing helper first.** |
| **B-02** | High | `guis/rise.lua` | No `CreateBind` → **keybinds cannot be set at all** in Rise. |
| **B-03** | High | `guis/old.lua` | No `CreateTextBox` → profile import/export UI missing entirely. |
| **B-04** | High | `guis/old.lua` | No `legitapi` → all 72 `Categories.Legit:CreateModule` registrations have nowhere to render. |
| **B-05** | Medium | `games/universal.lua:885` | `sessioninfo` published inside a `run()` block; BedWars captures it at top level (`6872274481.lua:78`). Any earlier failure ⇒ `nil` capture ⇒ delayed crash far from the cause. |
| **B-06** | Medium | `old.lua`, `rise.lua` | `applyFeatureTags` absent → NEW/PATCHED badges never render in two skins. |
| **B-07** | Low | `main.lua:4-8` | `acceptedWhitelistKey` + `isWhitelisted()` defined, never called. Delete. |
| **B-08** | Low | `old.lua`, `rise.lua` | `license.Closet` honored only by `new.lua`, `newer.lua`, BedWars — Closet mode leaks notifications in two skins. |
| **B-09** | Low | `main.lua` / `init.lua` | `buildNewerLoadingScreen` duplicated verbatim, with a comment admitting they must be "kept in sync." |
| **B-10** | Low | `libraries/cheatenginelib.lua` | 2 lines. Finish or delete. |
| **B-11** | Medium | loader | Watermark comment prepended to every cached `.lua` shifts every reported line number by 1. Every stack trace is off by one. |
| **B-12** | Medium | `guis/rise.lua:2219` | `CreateNotification(…, continued)` — a 5th parameter no other skin has. Callers become skin-dependent. |
| **B-13** | Low | `games/universal.lua:3575` | `SpinBot` tooltip documents a limitation ("does not work in first person") instead of handling it. |
| **B-14** | Medium | repo | `render.lua` (7,189), `cv` (15,652), `prem` (487 KB) unreferenced — 30% of repo bytes, duplicating BedWars logic they will drift from. The `enchant-table` block is byte-identical in three files. |
| **B-15** | Medium | `games/6872274481.lua:4727` | A module commented out with "can't see from the repo, so the module is pulled rather than shipped broken and harmful." Needs a real disposition: fix, or delete it and its config keys. |
| **B-16** | Low | `games/6872274481.lua` | Killaura's attack packet uses a bare `delta.Magnitude - 14.4`. Should come from `bedwars.CombatConstant`. |

### 4.2 Bug classes to sweep

- **C1 — Unowned coroutines.** Every `task.spawn(function() while … end)` not registered with a
  maid (splash motes at `init.lua:~89` is the visible one; module code has many). `OnTick` replaces
  almost all of them; survivors go through `self:Track(thread)`.
- **C2 — Unguarded upvalue surgery.** 126 `debug.getupvalue` + 42 `debug.setupvalue`, each silently
  changing behaviour on update day. Wrap all in `compat.upvalue(fn, i, expectedType)` emitting a
  **named** diagnostic ("SwordController upvalue 3 expected function, got nil — OmniAura HitReg
  disabled"). This is the #1 source of "it broke after the update."
- **C3 — Nil-character races.** `lplr.Character:FindFirstChild(…)` assuming the character exists.
  Centralize on `entitylib.character` + an `isAlive` guard; the scheduler skips character-dependent
  buckets while dead — a meaningful fraction of a BedWars match.
- **C4 — Remote signature drift.** `profiles/packages.json` maps ~30 remotes; when one is renamed
  modules fail opaquely. Validate the map at load, emit one notification listing every unresolved
  remote.
- **C5 — Toggle re-entrancy.** Rapid toggling starts a second `OnEnable` before `OnDisable`
  finishes. Lifecycle becomes a state machine (`Idle → Enabling → Enabled → Disabling`) that queues.
- **C6 — Cleanup leaks on uninject.** Four `Uninject` implementations, four teardown orders. One
  implementation, tested by reinjecting 20× and asserting instance count returns to baseline.
- **C7 — Cross-skin drift.** Anything fixed in `new.lua` and nowhere else. F5 makes this
  structurally impossible.
- **C8 — Duplicated BedWars logic.** Fixes applied to `6872274481.lua` but not `render.lua`/`cv`.
  Deleting the duplicates makes this impossible too.
- **C9 — Minecraft-isms.** Module names, tooltips, options and *behaviours* modelled on a game we
  aren't in (§2). Audit every one; either re-ground it in the real mechanic or delete it.
- **C10 — Silent no-ops.** Modules that toggle green and do nothing because their binding, remote
  or executor capability is missing. Every one must report *why* it's inactive (§7.6).

### 4.3 Infrastructure

- **In-GUI console** — severity filter, module attribution, stack traces, copy button. Diagnostics
  currently go to `warn()`, where nobody reads them.
- **Crash guard** — every `OnEnable`/`OnTick` in `xpcall`; three errors in 10s auto-disables the
  module, notifies once, flags it in the GUI with "show error".
- **`/aether diag`** — executor identity, capability probe, BedWars build id, failed bindings,
  failed remotes, module error counts, per-bucket timings → clipboard.
- **Safe mode** — hold `Shift` while injecting for core + skin only, no modules. Recovery path when
  a config bricks startup.
- **Lint in CI** — unique module names, `features.json` entries resolve to real modules, every
  `vape.Libraries.X` read has a write earlier in load order (catches B-01 and B-05 mechanically),
  every `bedwars.X` goes through the binding layer, no unmaided `while true`.

---

## 5. GUI Expansion

### 5.1 Skins

**Nexus** (`newer.lua`, flagship) · **Classic** (`new.lua`) · **Legacy** (`old.lua`, brought to full
parity: search, favourites, Legit tab, textboxes) · **Rise** (`rise.lua`, full parity + **keybinds
fixed**, B-02) · **Nova** (new — horizontal command bar, `Ctrl+Space` palette, near-zero chrome
during a match) · **Compact** (new — single-column layout that actually works on phone executors).

Parity today, by identifier count — zero means the capability doesn't exist:

| Capability | new | newer | old | rise |
|---|---:|---:|---:|---:|
| Module search | 11 | 34 | **0** | 3 |
| Favourites | 62 | 66 | **0** | **0** |
| Legit tab (`legitapi`) | 17 | 17 | **0** | 3 |
| `CreateTextBox` | 6 | 7 | **0** | **0** |
| `CreateBind` | 2 | 2 | 2 | **0** |
| `applyFeatureTags` | 2 | 2 | **0** | **0** |
| Tooltips | 65 | 76 | 33 | 14 |

Once skins are ~600 lines instead of forks of the whole core, community skins become realistic:
drop a folder in `skins/`, it appears in the picker.

### 5.2 Windows

Dockable/snappable windows with edge magnetism and a grid toggle · tabbed windows (drag a category
onto another) · resizable categories with persisted size · off-screen clamping · **layout presets**
saved independently of module config · pin/always-on-top · collapse to title bar · per-window
opacity · focus dimming.

### 5.3 Search & navigation

Global fuzzy search (`Ctrl+F`) across modules **and options and tooltips** (today: module names
only, in two skins) · command palette (`Ctrl+Space`: type `omni range 22` → jump and set) · search
operators (`is:enabled`, `is:new`, `is:patched`, `cat:combat`, `bind:none`, `changed:`,
`kit:kaliyah`) · Recently used / Most used virtual categories · jump-to-conflict.

### 5.4 Option widgets

| Widget | Purpose |
|---|---|
| `Vector` | 3-axis numeric input (hitbox expansion, offsets) — three sliders today. |
| `Curve` | Draggable curve editor: aim smoothing, reach falloff, knockback profiles. |
| `KeybindChord` | Chords with Hold / Toggle / Always / Double-tap. |
| `MultiSelect` | Checkbox list — "allowed items", "kits to counter", "blacklisted loot" are all hacked out of dropdowns today. |
| `PlayerPicker` | Live roster with avatar, team colour, kit icon. |
| `ItemPicker` | Backed by `bedwars.ItemMeta` — real icons, real names, tier grouping. |
| `KitPicker` | Kit selector with ability icons and cooldowns. |
| `BlockPicker` | Block type selector for scaffold/defense modules. |
| `RangeSlider` | Two-handle min/max (randomized delay 0.10–0.30s). |
| `ColorGradient` | Multi-stop gradient for ESP, chams, bed plates. |
| `Preview` | Live inline preview (chams material, ESP style, kill effect, bed plate). |

Per-option affordances: right-click to reset + "changed from default" dot · per-option keybinds
(cycle a dropdown, nudge a slider) · click-to-type on every slider · Ctrl-drag fine / Shift-drag
coarse · tooltips with examples on **every** option in **every** skin · linked options.

### 5.5 BedWars match panels

The payoff for narrowing scope, and the most visible new feature.

- **Match panel** — phase, time left, queue type, alive count, your team, forge level, active
  upgrades. One glance instead of four HUD widgets.
- **Bed tracker** — every team's bed: alive/dead, layer count, material, distance, defenders
  present, "last damaged 4s ago". Click a bed → set it as the Autopilot / BedBreaker target.
- **Generator panel** — type, tier, next-spawn countdown, contested state, sorted by distance.
  Click → path to it.
- **Team panel** — per-team roster with kit icons, armor tier, alive/dead, and a threat score from
  kit + armor + distance + recent damage.
- **Shop panel** — mirrors `bedwars.Shop`: what you can afford now, your buy queue, your team's
  upgrades. Buy from the panel.
- **Kit panel** — your abilities with live cooldowns; enemy kits seen this match with counters.
- **Inventory panel** — hotbar mirror with item metadata and drag-to-reorder that drives
  AutoHotbar's saved layout.
- **Resource ticker** — iron/gold/diamond/emerald income rate, time-to-next-upgrade.

### 5.6 Diagnostic panels

- **Console** — logs, errors, filters, stack traces, copy (§4.3).
- **Profiler** — per-bucket frame cost, module cost ranking, memory, instance count, FPS graph.
  Makes "which module is lagging me" answerable.
- **Network** — remote calls/sec per remote, rate-limit visualizer, last-200-calls inspector.
  Essential for tuning aura cadence and diagnosing lagback.
- **Hit-reg inspector** — accepted vs. rejected attacks over time, with the reach envelope the
  server is actually honouring right now (feeds `ReachControl`, §6.4).
- **Target inspector** — health, kit, armor, distance, predicted position, ping, wallcheck result
  and *why* it passed or failed.
- **Binding health** — every `bedwars.*` binding with green/amber/red status (§9).
- **Keybind map** — every bind on one screen with conflict highlighting.
- **Changelog panel** — release notes in-GUI on first launch after an update.

### 5.7 HUD & overlays

**HUD editor mode**: drag every overlay (watermark, arraylist, keystrokes, target info, radar,
session, CPS, coords, FPS, ping, armor, hotbar, bed status, generator timers) freely, snap-to-grid,
per-element scale/opacity/font/anchor — positions are hardcoded per skin today.
**Arraylist**: sort by length/alpha/category/custom, gradient/rainbow/static, per-module suffix
(`OmniAura [18.2]`), fade animation, max height with overflow counter.
**Radar**: zoom, rotation lock, bed/generator icons, team colours, height indicators, click-to-target.
**Target HUD**: portrait, health bar, kit icon, armor tier, distance, hit/miss ticker.
**Notification center**: history, severity filter, dedupe (`×3`), position choice, do-not-disturb
that still records.
**Watermark**: templated and user-editable — `{fps} FPS | {ping}ms | {kills}K | {beds}B | {profile}`.

### 5.8 Theming & accessibility

Full theme engine with named tokens (`accent`, `surface`, `surfaceAlt`, `text`, `textDim`,
`positive`, `negative`, `warning`), editable in-GUI · theme import/export as a shareable string ·
built-ins (Onyx, Midnight, Amethyst, Sakura, Mint, Solarized, Nord, Catppuccin, High-Contrast) ·
**team-colour mode** where the accent follows your BedWars team · font picker · animation-speed
slider including **Reduce Motion** (accessibility win *and* FPS win) · controller navigation ·
touch mode with larger targets · **colourblind-safe ESP and team palettes** (BedWars leans hard on
red/green) · 0.5×–2.0× scaling that reflows · keyboard-only navigation with focus rings.

---

## 6. Modules

V2 makes **247 module registrations** across the three surviving game files — 161 in
`6872274481.lua`, 70 in `universal.lua`, 16 in the lobby — resolving to **223 unique module names**
(21 names appear in more than one file). Every one of them was read before this section was written.
The "207 modules" figure in earlier drafts undercounted: sixteen registrations declare their `Name`
with double quotes and were missed by the audit script, including all eleven lobby modules beyond
the obvious five.

The first draft of this document answered that with *more* — "130+ new/rebuilt modules, weighted to
the overpowered end". That was the wrong instinct. A module list is not a feature count; it is a
maintenance surface, and V2's problem was never that it had too few modules. It was that it had four
auras, three projectile aimbots, eleven lighting modules and a `Swim` toggle for a game with no
water — and that a third of the list either did nothing observable, or worked only until the server
noticed.

**V3 ships 70 modules.** 201 of V2's 223 names are absorbed into them, 10 become HUD elements or GUI
features rather than modules, and 12 are deleted outright. Nine modules are genuinely new. The
section is shorter than V2's list and strictly more capable, because the capability now lives in
options on engines that are actually maintained instead of in modules that each rediscover the same
mechanic badly.

### 6.1 What got cut, and why

Three kinds of entry were removed. Each cut is named here rather than quietly dropped, because "we
deleted your favourite toggle" deserves a reason.

**Cut 1 — gimmicks: mechanics that don't exist in Roblox BedWars, or don't work the way the module
assumed.** These are §2's failure mode, and the first V3 draft reintroduced several of its own.

| Cut | Why |
|---|---|
| `SpinBot`, "AntiAim" | Nothing in BedWars reads your look vector for validation, and no other client aims off it. Spinning is a self-inflicted visual. |
| `Swim`, `Gravity`, `Spider`, `Parkour` | No water on the map pool; `Gravity` and `Spider` are Roblox-physics toys with no BedWars use; `Parkour` is Minecraft vocabulary for "jump the gap", which `SpeedEngine` already does. |
| `Invisible` | Client-local only. You are invisible to yourself. |
| "VoidPull" (draft) | Lassos pull *you* toward an anchor. They do not yank other players. The module was designed against a mechanic that isn't there. |
| "Strafe", "Rewind" (draft) | Both assume a client-authoritative movement model. `Humanoid` state is reconciled; a friction model and a position rewind are lagback generators with a nice slider. |
| "HitSelect" (draft) | Presumes per-body-part server hit validation to learn against. `CombatConstant` validates distance and cadence, not limbs. |
| "MacroEngine" (draft) | Recorded input replay in a game where every action is a validated remote call. It records the tell and replays it. |

**Cut 2 — clutter: entries that were real, but were an option, a HUD element, or a panel wearing a
module's clothes.** Each of these cost a GUI row, a config key, a lifecycle and a bug surface, and
gave back a line of text.

| Cut | Became |
|---|---|
| `Clock`, `Coords`, `FPS`, `Ping`, `Keystrokes`, `Speedmeter`, `Timer` | HUD elements in the HUD editor (§5.7). They draw a number; they are not modules. |
| `Waypoints` | Radar and map markers (§5.7). |
| `Search`, `Memory` | GUI search (§5.3) and the profiler panel (§5.6). |
| "BedIntel", "GenIntel", "DefenseAnalyzer", "UpgradeAdvisor", "ResourceHUD", "KitAdvisor", "AbilityTimers" (draft) | The match state store (F2) and the match panels (§5.5). A tracker with no behaviour is data, and data belongs in the store that every module already reads. |
| `ReachDisplay`, `PotionStatus`, `KitDisplay` | Readouts on the owning module's row (§7.6) and the relevant panel. |
| "SwingTiming", "SprintSync", "Humanizer" (draft) | Shared services (§6.3). They were never modules; they were things three modules each needed. |
| "MultiHit", "PredictiveAura", "TargetLock", "RetaliationBot", "VoidCombo", "AntiBot", "ComboKeeper", "BackTrack+", "ProjectileSpam", "AutoJump", "BlockFly", "AutoBridge", "TunnelDig", "BedRoute", "ArcPredict", "AbilityChain", "GenSteal", "ForgeManager", "ConfigSync", "MatchRecorder", "KillFeed+", "Trail" (draft) | Options and modes of the module they were carved off. Every one of them was one checkbox on something that already existed. |

**Cut 3 — dead weight: entries whose premise doesn't survive contact with the game.**

| Cut | Why |
|---|---|
| `StaffDetector`, `CheatDetector` | Badge, group and gamepass heuristics on strangers. High false-positive rate, no true-positive mechanism — Roblox moderation does not join your lobby wearing a badge. The useful half (a bound kill switch) is `PanicButton`, which is kept. |
| `AutoToxic`, `ChatSpammer`, `ChatCrasher` | Harassment and griefing tooling with zero competitive value, and the fastest route to a report. |
| `Schematica` | Saved base blueprints auto-built from stored resources. Enormous placement-validation surface, months of tuning, and it loses to boxing yourself in with four blocks. |
| `MurderMystery` | Different game (§1). |
| "Scripting Console" (draft) | Arbitrary Lua against the core, shipped to users, behind a confirmation dialog. The confirmation dialog is not a security model. The legitimate need — inspecting state while developing a module — is the diagnostics panel (§5.6). |
| "AutoWin+" (draft) | It was Autopilot's endgame phase with its own name and its own copy of the phase machine. |

### 6.2 Design rules

Every module below satisfies all six. A proposal that fails one is an option, a service, a panel, or
nothing.

1. **It names a binding.** Every module declares the `bedwars.*` surface it stands on, and that
   surface is one the repo already touches. The *Stands on* column is not decoration — it is the
   feasibility argument, and it is what §9's patch report attributes failures to. A module whose
   mechanic can't be named in `bind.lua` is folklore.
2. **It owns a channel, or it submits to one.** Exactly one module writes the attack remote, one
   writes movement speed, one arbitrates block placement, one writes camera CFrame. Everything else
   submits a request. Contention is a lint error (§6.16), not a race between two toggles.
3. **It is a mode, not a module, if it shares 80% of its code.** `Silent` and `Packet` aura are
   delivery modes of one targeting engine. `Range` is a mode of `BedBreaker`. This is the single
   rule V2 violated most.
4. **It has behaviour.** If it only reads and draws, it's the match store plus a panel (§5.5) or a
   HUD element (§5.7).
5. **It degrades instead of desyncing.** A module whose steady state is "the server hasn't noticed
   yet" is exploit-tier (§6.15) and gated, not a headline feature. This is where the draft's
   `AntiDeath+`, `DesyncEngine` and `NoClip+` went.
6. **It survives its own success.** Anything that scales with player count, block count or projectile
   count declares its scheduler bucket and its budget (F4), or it is the thing the profiler blames.

### 6.3 Shared services — the parts that are not modules

Seven behaviours that three or more modules each need. In V2 each caller reimplemented them; in the
draft several were promoted to modules, which is how "SwingTiming" ended up in a combat table next
to the two modules that consume it. They live in the core, have no GUI row, and appear in the
binding-health panel like any other binding.

| Service | Provides | Consumers |
|---|---|---|
| **SwingTiming** | The real sword cooldown window from `CombatConstant` / `SwordController.lastAttack`, plus accepted/rejected feedback. | OmniAura, ShieldSync, ArmorBreaker, HitboxSolver |
| **TargetProvider** | One ranked, filtered target list per frame — priority tree, team filter, wallcheck, NPC filter, FOV. | OmniAura, ProjectileEngine, TargetOrbit, AutoKit Engine, KitCounter, PlayerESP |
| **MovementChannel** | The single writer of walk speed, velocity and character CFrame, with a correction detector. | SpeedEngine, NoSlow, FlyEngine, BalloonFly, LassoSwing, TeleportSuite, AntiVoid, AutoPath, TargetOrbit |
| **BlockChannel** | The single arbiter of `placeBlock` / `breakBlock`, with one placement rate limit matched to what `BlockController` accepts and a priority queue across callers. | Scaffold, BlockPlacer, Breaker, BridgeCut, BedBreaker, BedDefense, TrapLayer |
| **PathSolver** | Route between two world points across an island map, with gap-bridging requests handed to BlockChannel. | AutoPath, Autopilot, AutoFarm, BedBreaker |
| **RemoteBudget** | One global ceiling on outbound remote traffic, so three modules cannot collectively spam past what the server tolerates. | every module that fires a remote |
| **Humanizer** | One coherent jitter and latency-variance source, seeded per session. | every automated action; exposed as a single intensity control in Legit mode (§6.14) |

### 6.4 Combat — 9 modules (29 V2 modules in, 1 new)

Twenty-nine V2 modules collapse into nine: four auras, three reach entries, two hitbox modules, six
one-effect nullifiers and a dozen single-mechanic toggles. The mechanics are worth keeping; the
fragmentation is not.

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **OmniAura** | The one melee engine: targeting via TargetProvider, cadence via SwingTiming, and three delivery modes — **Swing** (animated), **Silent** (server-side rotation only), **Packet** (straight to the sword remote, no animation, rotation or viewmodel tell). Options cover what V2 shipped as separate modules: hits per accepted window, multi-target fan-out, target lock, prediction against `lib/prediction` for strafers and bridge corners, recorded-position fallback when the live position is rejected, and *engage-only-when-damaged* for legit play. | `SwordController` (43 refs), `CombatConstant`, `QueryUtil` | Killaura, Aura, SilentAura, TPAura, SilentAim, TriggerBot, AutoClicker, NoClickDelay, BackTrack |
| **ReachControl** | One owner of distance for sword, placement and break. Learns the envelope the server is actually honouring right now from accepted vs. rejected actions, ramps within it by target velocity and your ping, and draws it. Replaces the bare `delta.Magnitude - 14.4` (B-16) and the three independent reach sliders. Interaction range is InteractEngine's channel, not this one. | `CombatConstant`, `BlockController`, `BlockBreaker` | Reach, ReachDisplay, Extender |
| **HitboxSolver** | Per-target hitbox expansion that auto-shrinks the moment the server starts rejecting. The shrink is the module — expansion without it is a lagback with extra steps. | `QueryUtil`, SwingTiming feedback | HitBoxes, HitFix |
| **KnockbackControl** | Full shaping over `KnockbackUtil`: horizontal and vertical multipliers, directional override, full negation, per-source rules (sword / fireball / TNT / ability), and a **juggle** mode that times your cadence against knockback recovery so the target never lands. | `KnockbackUtil`, `KnockbackController` | Velocity, KnockbackDelay |
| **ShieldSync** *(new)* | Raises the shield in the dead time between accepted attack windows and drops it to swing, driven by SwingTiming. This is the Roblox-correct answer to "block hitting" (§2) — a real item with a real state, not a Minecraft technique. Nothing in V2 does this; `InfiniteShield` is a duration exploit and stays gated (§6.15). | `SwordController`, `ItemMeta`, SwingTiming | — |
| **ArmorBreaker** | Prioritizes the weakest-armor target and swaps to the tool that beats their tier, from real item data instead of name matching. | `ItemMeta` (53 refs) | ArmorSwitch, AutoTool |
| **EffectNullifier** | One data-driven canceller for incoming status effects — balloons, lassos, traps, suffocation, ragdoll, kit abilities. A new effect is a table row, not a new module; V2 needed six. Named for what it does: V2's `Disabler` is a movement-detection bypass and belongs to AntiLagback. | `StatusEffectMeta`, `StatusEffectUtil` | BalloonDisabler, KrystalDisabler, TrapDisabler, AntiLasso, AntiSuffocate, AntiRagdoll |
| **AutoConsume** | Heal / speed / jump potions at thresholds, cooldown- and combat-aware, with pre-engagement prep. Absorbs the status readout as a row readout. | `ItemMeta`, `StatusEffectMeta` | AutoConsume, FastConsume, PotionStatus |
| **AntiLagback** | Detects a server correction, reverts smoothly instead of snapping, identifies which module caused it, and throttles *that* module before the user notices. The correction signal is published to MovementChannel, so every movement module gets it for free. | `Store`, MovementChannel | AntiLagback, Disabler |

### 6.5 Projectiles & explosives — 4 modules (10 V2 modules in, 1 new)

Ten V2 modules each tune their own gravity constant, while `ProjectileMeta` (20 refs) and
`BowConstantsTable` (30 refs) sit right there with the real numbers.

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **ProjectileEngine** | Aim, aura, charge and release for every throwable and fired projectile, solved from the game's own tables rather than tuned constants. Owns your projectile aim channel; the camera is never touched. Draws your own predicted arc and impact point while charging as a display option. | `ProjectileMeta`, `BowConstantsTable`, `ProjectileController`, `ProjectileLaunchHook` | ProjectileAimbot, ProjectileAura, AutoShoot, BowAssist, AutoRelease, ProjectileLanding |
| **ExplosiveSolver** *(new)* | Fireball and TNT as the objective tools they actually are: aim at bridges to cut them, at players mid-bridge, and at bed defenses by layer — with your own self-damage and self-knockback solved for, including deliberate fireball-jump routing. V2 has no explosive module at all despite fireballs being one of the strongest items in the game. | `ProjectileMeta`, `KnockbackUtil`, `ItemMeta` | — |
| **TelepearlSolver** | Solves telepearl trajectories to a clicked destination through gravity and geometry, with a landing-safety check against the void. | `ProjectileMeta`, `ItemMeta` | AutoPearl |
| **IncomingProjectiles** | The render *and* reaction owner for **other people's** projectiles: live trajectories, predicted impact points, trails, and time-to-impact. Optional single-input dodge that yields to any active movement module and refuses any direction ending in the void — the draft's auto-dodge fought every other movement module and walked people off the map. | `ProjectileController`, `ProjectileMeta` | ProjectileTracers, Arrows, ProjectileDodger |

### 6.6 Movement — 9 modules (19 V2 modules in, 1 new)

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **SpeedEngine** | One speed module with modes (CFrame / velocity / humanoid), per-mode lagback profiles, vertical variants, and automatic fallback to whichever mode the server currently tolerates. Six V2 modules were six hardcoded points in this space. | MovementChannel, `SprintController` | Speed, Step, LongJump, HighJump, BoostAirJump, InfiniteJump, Parkour |
| **FlyEngine** | Acceleration-curved flight without the instant start/stop signature, with altitude hold and waypoint paths. Declared in conflict with Scaffold's tower mode and with BalloonFly. | MovementChannel | Fly |
| **BalloonFly** | Automated balloon use for vertical travel and clutch saves — the game's own flight, and the one the server has no opinion about. | `BalloonController` (19 refs) | AutoBalloon |
| **LassoSwing** | Lasso to a clicked point or target with swing-momentum handling and a release solver. | `ItemMeta`, MovementChannel | AutoLasso |
| **TeleportSuite** | Mouse teleport with a safety guard — never into the void, never inside geometry, never past the distance the server accepts. Kit teleports are kit-engine entries that *call* this solver rather than reimplementing it (§6.10). | MovementChannel, `Store` | MouseTP |
| **AntiVoid** | Predicts void and fall death, then recovers with whatever you actually have: cancel velocity, place a block, pop a balloon, fire a telepearl. Manual mode binds the same recovery to a key, which is what a "ClutchAssist" module would have been. | `FallDamageController`, BlockChannel, `BalloonController` | AntiFall, NoFallDamage, SafeWalk |
| **NoSlow** | Removes the game's own movement penalties — bow charge, item use, ability windup — and keeps sprint state coherent so movement modules and aura stop fighting over it. Submits to MovementChannel rather than writing speed directly, which is why it composes with SpeedEngine instead of racing it. | `SprintController` (16 refs) | NoSlowdown, Sprint, KeepSprint |
| **TargetOrbit** | Auto-strafes a locked target at a set radius and height, void-aware and bridge-aware. | MovementChannel, TargetProvider | TargetStrafe, PlayerAttach |
| **AutoPath** *(new)* | Click a point, get walked there — across islands, with gap-bridging requests handed to BlockChannel and known traps routed around. This is PathSolver with a GUI, and it is not extra surface: Autopilot, AutoFarm and BedBreaker all need the same solver, so shipping it as a module costs one row and makes the hardest dependency in §6 independently testable. | PathSolver, BlockChannel | — |

### 6.7 Building & breaking — 4 modules (6 V2 modules in, 1 new)

Every module here submits to BlockChannel. That is what stops V2's situation where three modules
each place blocks at their own rate and the server rejects all of them.

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **Scaffold** | Predictive bridging: tower / flat / diagonal / downward, plus a **block-flight** mode for when FlyEngine is being corrected. Block conservation, sprint-safe, "don't bridge into the void" guard, and an **auto** mode that bridges a PathSolver route between islands without input. Modes are named for what they do, not for Minecraft techniques (§2). | `BlockController` (33), `placeBlock` (15), BlockChannel | Scaffold, AutoBuildUp |
| **BlockPlacer** | The general placement module, offensive and defensive from one rate limiter: box yourself in below a health threshold, box an enemy in, suffocate, and place from a chosen block priority list. | `placeBlock`, `BlockSelector`, BlockChannel | Block-In, AutoSuffocate |
| **Breaker** | Owns the break channel. Multi-block breaking in a configurable shape and radius, tool auto-swap by hardness, and layer-aware ordering. Tunnels are a shape, not a module. | `BlockBreaker` (18), `breakBlock` (9), `BlockBreakController` | Breaker, FastBreak |
| **BridgeCut** *(new)* | Breaks the block a moving enemy is about to step on, or the bridge behind a rusher, solved from their predicted position rather than their current one. The single highest-value use of the break channel in BedWars and V2 has nothing like it — `Breaker` is a radius, not a target. Submits to Breaker's channel; it supplies the targeting policy only. | `BlockBreaker`, `lib/prediction`, TargetProvider | — |

### 6.8 Objectives — 5 modules (3 V2 modules in, 2 new)

Beds are how the game is won, and V2 devotes five modules to them — three of which are ESP, leaving
`BedAssist` and `BedProtector` as the only bed *behaviour* in the client. With the match store (F2)
holding bed state, these become behaviour instead of scanning, and two obvious gaps get filled.

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **BedBreaker** | Full-auto breaking: tool selection, layer-aware order, defenses first, resume after interruption, a "don't start what you can't finish" check against nearby defenders, and a **range** mode that breaks from the maximum accepted distance with no walk-in. Target selection reads the store's defense score (layers × material hardness × defenders), so the easiest bed is the default target rather than the nearest. | `BlockBreaker`, `ItemMeta`, match store, PathSolver | BedAssist |
| **BedDefense** | Rebuilds your bed's exposed faces with the best available block the moment they're damaged, prioritizing the face under attack. | BlockChannel, `ItemMeta`, match store | BedProtector |
| **BedAlarm** | Directional alarm: who, from where, layers remaining, on-screen arrow, distinct sound. The one notification in this client that earns a sound cue. | match store, `SoundManager` (17 refs) | BedAlarm |
| **TrapLayer** *(new)* | Buys and places traps and landmines at your base's actual chokepoints — derived from the map's approach paths, not from a fixed offset — and re-arms them as they're consumed. V2 can *see* traps (`TrapESP`) and *ignore* them (`TrapDisabler`); nothing in it ever places one, which is the half that wins games. | `Shop`, `ItemMeta`, BlockChannel, PathSolver | — |
| **RushAlert** *(new)* | Fires before the bed is touched, not after: detects players crossing toward your island, names the team and kit, estimates arrival, and optionally recalls Autopilot from the map. `BedAlarm` tells you that you already lost a layer; this is the one that lets you not lose it. | match store, TargetProvider | — |

### 6.9 Economy — 6 modules (8 V2 modules in, 2 new)

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **SmartBuy** | One priority list over real item data, covering personal purchases *and* team upgrades and forge tiers, with affordability, tier gating and "don't buy a sword I already beat" logic. V2 splits this across two item modules with no upgrade support at all. | `Shop` (15), `ShopItems`, `ItemMeta`, `TeamUpgradeMeta`, `BedwarsShopController` | AutoBuy, ShopClicker |
| **AutoFarm** | The loop: collect from generators → bank at the forge → hand the next purchase to SmartBuy → repeat. **Enemy** generators are a target mode with an escape route and a "leave before they respawn" timer, not a second module. | match store, PathSolver, `Store` | AutoBank, AutoSteal |
| **DropManager** | Owns the ground-item filter: drop junk, protect priority items, void-drop enemy loot, filtered auto-pickup. Pickup *range* is InteractEngine's channel; this owns *what*. | `ItemDropController`, `ItemMeta` | AutoVoidDrop, FastDrop |
| **AutoLoot** *(new)* | Owns *containers*, where DropManager owns the ground: restock from your team chest against SmartBuy's priority list, and strip an enemy chest when you take their base. Routed by PathSolver, opened through InteractEngine. V2 can render chests four different ways and open none of them. | `ItemMeta`, InteractEngine, PathSolver | — |
| **EnchantAuto** *(new)* | Collects from and applies at the enchant table by priority. The repo already collects the enchant-table block in three files (B-14) and never built a module on it. | `EnchantMeta` | — |
| **AutoFish** | Solves the fishing minigame and banks the output; the same solver covers honor farming, which is the same minigame with a different reward. | `FishingMinigameController` (6 refs) | AutoFish, AutoHonor |

### 6.10 Kits — 2 modules (9 V2 modules in, 0 new)

**Correcting the record:** earlier drafts of this document claimed V2 has "30+ `Auto<Kit>` modules"
that V3 would collapse into one. It does not, and the claim should not survive into V3 planning.
There is exactly **one** `AutoKit` module, and it already dispatches through an
`AutoKitFunctions[kit]` table covering **23 kits**, with per-kit toggles generated from
`BedwarsKitMeta`. V2 got the structure right here.

The problem is what's *inside* the table: those 23 entries are **325 lines of hardcoded Lua
closures** (`6872274481.lua:14501–14826`). A new kit means shipping code. A changed ability breaks a
closure buried mid-table with nothing naming it, which is exactly the failure §9 exists to end. And
**eight** kit behaviours escaped the table entirely and became their own modules across three
different categories — `AutoKaida` in Blatant, `OwlAura`/`VulcanAimbot`/`TerraAimbot` in Blatant,
`MissileTP`/`RavenTP`/`TritonClutch`/`GrimReaperFix` in Utility.

So the real change is smaller than advertised and better defined: **23 closures become data, 8
strays come home, and the dispatch table stops being code.**

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **AutoKit Engine** | `AutoKit`'s dispatch structure kept, its 23 hardcoded closures replaced by `data/kits.json`: a kit is a data entry naming its ability, triggers, aim target and cooldown. Aimed abilities are solved by ProjectileEngine, kit teleports by TeleportSuite, kit clutches by AntiVoid, kit auras by OmniAura — the engine routes, it does not reimplement. A new kit is a JSON entry; a kit broken by an update fails *visibly* in the binding-health panel (§9) instead of inside closure 14 of 23. | `AbilityController` (26), `BedwarsKitMeta`, `kit` | AutoKit, AutoKaida, OwlAura, VulcanAimbot, TerraAimbot, TritonClutch, MissileTP, RavenTP, GrimReaperFix |
| **KitCounter** | The same table read from the other side: what the enemy kits present can do, when their abilities are back up (estimated from use), which item counters them, and which windows to dodge. Feeds the kit panel (§5.5); kit icons and ability-ready state are a PlayerESP layer, not a second ESP module. | `BedwarsKitMeta`, `data/kits.json`, TargetProvider | AutoCounter |

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

### 6.11 Render & visuals — 10 modules (49 V2 modules in, 0 new)

Nothing new here on purpose. Forty-nine V2 modules — eleven of them lighting presets, nine player-ESP
variants, eight world-ESP variants — become ten modules with layers. Every one is drawn on a budgeted
scheduler bucket with pooling, frustum culling and distance LOD (§8), which V2 does for none of
them. This is the largest single reduction in the document.

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **PlayerESP** | One player ESP with independently toggled, independently coloured layers: box, corner box, tracer, skeleton, chams, nametag, health bar, armor tier, kit icon with ability-ready state, distance, off-screen arrow. | `QueryUtil`, `getIcon`, TargetProvider, `drawing` | ESP, Chams, NameTags, Tracers, PlayerOutline, ArmorHighlight, Health, KitESP, KitDisplay |
| **WorldESP** | The same layer treatment for world objects: bed plates with layer count, material icon and damage flash; generators with tier badge, spawn-countdown ring and contested highlight; chests and loot with a contents preview where readable; traps and beehives with arm state and blast radius. Eight V2 modules, one scan, one draw pass. | match store, `getIcon`, `ItemMeta` | BedESP, BedPlates, GeneratorESP, StorageESP, LootESP, ItemESP, TrapESP, BeehiveESP |
| **BlockESP** | See-through-defenses view: obsidian, team blocks and bed shells highlighted by hardness. This is what `Xray` means in a game with no ores (§2). | `BlockController`, `QueryUtil` | Xray |
| **DamageNumbers** | Floating damage and heal numbers with a combo counter. No crit styling — there are no crits (§2). | `DamageIndicator` (8 refs) | DamageIndicator, HitColor, WhiteHits |
| **WorldTuner** | Every lighting and atmosphere preset as one module with a preset list, plus manual time / atmosphere / brightness and an **FPS-cost label per preset**. Eleven V2 modules that each set the same handful of `Lighting` properties. | `Lighting`, `VisualizerUtils` | IRLReplica, AbyssalDepths, StormMode, AuroraSky, ChillLighting, Shader, Bloom, MotionBlur, Fullbright, TimeChanger, Atmosphere |
| **NoRender** | A per-class checklist of particles, effects and decorations to stop rendering, plus the FFlag tweaks that actually move the needle, with measured cost shown per entry. | `RunService`, executor FFlag capability | PotatoMode, FPSBoost, ShadowRemover, RemoveNeon, FFlagEditor |
| **UITuner** | The game's own interface: hide, reposition or restyle BedWars HUD elements. Separate from NoRender because it is a legit-safe visual preference rather than a performance switch. | `UILayers`, `Roact`, `AppController`, `StreamerModeController` | Interface, UICleanup, RemovePlayerLevelUI, StreamRemover, OG4v4v4v4 |
| **CameraSuite** | FOV, third-person offsets, shoulder swap, zoom presets, and freecam with a spectate target. One owner of the camera CFrame channel. | `FovController` (9 refs) | FOV, ZoomUnlocker, Freecam |
| **ViewModel** | First-person model FOV, position, rotation, sway and bob. | `ViewmodelController` (14), `InventoryViewmodelController` | Viewmodel, ViewmodelVisuals, LegacyAnimation |
| **Crosshair** | Shape, gap, thickness, dot, dynamic spread, hit marker driven by SwingTiming's accepted-hit signal. | `drawing`, SwingTiming | Crosshair |

### 6.12 Utility — 10 modules (55 V2 modules in, 0 new)

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **Autopilot** | The headline: plays the match as a phase machine over the match store — farm → bank → buy → route to the weakest bed → break → hunt survivors → close — with clutch recovery, a bail-out when outnumbered, and a hand-back to the user at any point. Every other module in §6 is a component it drives, which is exactly why it is one module and not five. Gated behind an explicit acknowledgement (§10.4). | match store, PathSolver, and most of §6 | AutoPlay, AutoWin |
| **QueueManager** | Auto-queues a chosen mode after a match, retries on failure, tracks winstreak across queues, and hops on a bad server. | `QueueController`, `QueueMeta` | AutoRejoin, Rejoin, ServerHop |
| **AFKGuard** | Anti-idle, auto-reconnect, and a log of what happened while you were away. | `Players`, `Store` | Anti-AFK |
| **PanicButton** | One key: disable every non-legit module, restore camera, FOV and lighting, hide the GUI. Its bind is reserved and cannot be conflicted away (§7.2). | module registry | Panic |
| **InteractEngine** | One owner of interaction range and speed — chests, shops, prompts, pickups — so five V2 modules stop stacking multipliers on the same channel. Block placement and break distance are ReachControl's; this is prompts and containers. | `ProximityPrompt`, `ClickHold`, `InteractExtender` surface | PickupRange, FastInteraction, InteractExtender, ProximityPromptDuration, ProximityExtender |
| **Cosmetics** | Every purely local appearance option in one module with a preview: skins, tags, cursors, kill and win effects, armor trims, capes, hats, texture packs, sounds, trails, block selector colour. Twenty-five V2 modules that all do the same class of thing, none of which is visible to anyone else. | `ItemMeta`, `KillEffectController`, `SoundList`, `SoundManager` | SkinChanger, CustomTags, CustomCursor, InvisibleCursor, KillEffect, WinEffect, BedBreakEffect, ArmorTrims, ChinaHat, Cape, GamingChair, TexturePack, AnimationPlayer, SongBeats, SoundChanger, CleanKit, BlockSelectorColor, Breadcrumbs, Headless, OGNameTags, AutoEmote, NightmareEmote, CustomClanTag, TitleChanger, LARPKits |
| **Spoofer** | Everything that misreports *you* — to the server or to other clients — in one module, with one honesty setting and a per-entry label saying whether it is client-local (cosmetic) or server-visible (risk). V2's fourteen spoofers had fourteen risk profiles and no way to tell which was which: six are lobby-only vanity sitting in the same list as things the server can actually see. Includes an **inspect** mode — V2's `ACMODView` — that shows you what everyone else sees. | `KillFeedController`, `Store`, `GamePlayer` | NameTagSpoofer, DeviceSpoofer, StateSpoofer, KillfeedSpoofer, WinstreakSpoofer, Disguise, PlayerModel, NametagSpoof, LeaderboardSpoof, PlayerProfileSpoof, StatsBoardSpoof, SetPlayerLevel, SetPlayerWins, ACMODView |
| **Statistics** | Persistent lifetime and per-session stats — kills, beds, wins, winstreak, per-module usage and enabled time — plus a match timeline (beds, kills, purchases, deaths) rendered as an after-action summary. Absorbs V2's lobby-only `ViewMatchHistory`, which fetched the same data and displayed it once. Feeds §7.6's "last used" surface. | `Store`, config store | ViewMatchHistory |
| **ChatFilter** | Client-side mute, highlight and regex rules, per player, plus chat position and name colouring. | `TextChatService` | ChatPosition, ChatNameColor |
| **AutoHotbar** | Saved hotbar layouts applied on spawn and after purchases, driven by the inventory panel's drag-to-reorder (§5.5). Kept as-is in scope, rebuilt on the new lifecycle. | `getInventory`, `ItemMeta` | AutoHotbar |

### 6.13 Lobby — 1 module

The lobby file's five registrations mostly stop being lobby-specific: `Sprint` is NoSlow, `Headless`
and `OGNameTags` are Cosmetics, `WinstreakSpoofer` is Spoofer. What remains is genuinely
lobby-only:

| Module | What it does | Retires |
|---|---|---|
| **AutoGamble** | Automated gambling with a configurable stop rule — stop on profit, stop on loss, stop after N. The stop rule is the module; V2's version is a click loop. | AutoGamble |

Winstreak and next-milestone readouts are HUD elements (§5.7); mode selection and auto-ready are
QueueManager options (§6.12).

### 6.14 Legit mode — 2 modules

72 Legit registrations currently have no home in two skins (B-04). Legit deserves investment as a
*mode that reshapes every module's defaults* — capping ReachControl to a plausible envelope, forcing
OmniAura to Swing delivery, raising Humanizer's intensity — rather than as a category with its own
duplicate modules. Only two behaviours exist solely in this mode:

| Module | What it does | Stands on | Retires |
|---|---|---|---|
| **AimAssist** | Curve-driven camera smoothing with per-axis speed, FOV falloff, target-switch delay and humanized jitter. The only module in the document that moves the camera for aim; OmniAura's Silent and Packet modes never touch it. | TargetProvider, Humanizer, `FovController` | AimAssist |
| **VisualsOnly** | One toggle: everything that draws, nothing that acts. Disables and locks every module that writes a remote or a movement channel. | module registry | — |

Presets — Legit / Closet / Rage — ship in `configs/` as readable JSON (F6), replacing the
double-encoded `cc.json` and `rage.json`.

### 6.15 Exploit tier — 8 modules, all gated

These are the modules whose steady state is "the server hasn't corrected me yet" (design rule 5).
They are not deleted — several are the most powerful things in the client — but they are quarantined
under one contract rather than mixed into the combat and movement tables where their risk is
invisible.

**The contract:** each sits behind a capability probe and self-disables cleanly when its primitive is
unavailable, instead of erroring · each shows **"last verified against BedWars build X"** in the GUI
· each is off by default, badged blatant (§7.4), and excluded from every shipped preset ·
**AutoPatchCheck** compares the live build against `data/signatures.json` at load and warns which of
them are likely broken this build (§9) · any one of them that cannot be brought under this contract
is deleted rather than shipped in V2's state of "works until it silently doesn't".

| Module | Retires |
|---|---|
| **DesyncEngine** — position-packet hold and burst, with a live buffer visualizer and manual release. Declared in conflict with AntiLagback. | FakeLag, Desync, Blink |
| **AntiDeath** — health-state desync, auto-disabling the instant the server corrects. | AntiDeath |
| **NoClip** — phase with a re-solidify guard, so a correction doesn't drop you into the void. | NoClip |
| **InfiniteShield** — shield duration beyond what the item grants. The *timing* half is ShieldSync (§6.4) and is not gated. | InfiniteShield |
| **InstantKill** | InstantKill |
| **DamageBoost** | DamageBoost |
| **ShopTierBypass** | ShopTierBypass |
| **ProjectileExploit** | ProjectileExploit |

### 6.16 Uniqueness invariants

"No two modules do the same thing" is enforceable, not aspirational. These are the pairs that look
like overlaps, with the boundary stated, plus the lint that keeps them apart.

| Pair | Boundary |
|---|---|
| OmniAura · ProjectileEngine · AutoKit Engine · AimAssist | Four things aim. Melee is OmniAura, projectiles are ProjectileEngine, abilities are the kit engine, and **only AimAssist moves the camera**. |
| ReachControl · InteractEngine | Sword, place and break distance vs. prompt and container distance. Two channels, never both. |
| Breaker · BedBreaker · BridgeCut | Breaker owns the break channel; the other two supply targeting policy (objective layers, predicted footfall) and submit to it. |
| Scaffold · BlockPlacer · BedDefense · TrapLayer | All place blocks; all submit to BlockChannel's single rate limit with declared priority. Route bridging vs. enclosure vs. objective repair vs. trap arming. |
| SpeedEngine · NoSlow · FlyEngine · AntiVoid · TargetOrbit · AutoPath | All move you; all write through MovementChannel, which resolves precedence rather than letting the last writer win. |
| PlayerESP · WorldESP · BlockESP · IncomingProjectiles | Players vs. world objects vs. terrain-through-walls vs. projectiles. Projectile rendering lives with the projectile module and is not duplicated in §6.11. |
| Cosmetics · Spoofer | What only you see vs. what others see. If it leaves your client, it is Spoofer's, with a risk label. |
| WorldTuner · NoRender · UITuner | Lighting and atmosphere vs. render suppression for FPS vs. the game's own interface. |
| DropManager · AutoLoot · InteractEngine | Ground items vs. containers vs. the range and speed both use. |
| AntiLagback · DesyncEngine | One reacts to corrections; one causes them. Declared conflict, surfaced in the GUI. |
| BedAlarm · RushAlert | After the bed is hit vs. before. |

**Enforced in CI** (§4.3): module names unique across the registry · every module declares exactly
one owned channel or none · no two modules declare the same owned channel · every module's
`GameBind` list resolves through `bind.lua` · every `Retires` entry appears exactly once across the
whole of §6 · every one of V2's 223 names appears exactly once in §6.17.

### 6.17 Disposition audit — all 223 V2 modules

Every V2 module name, each with exactly one destination. Nothing in §6.4–§6.15 duplicates something
that already exists; where two engines could plausibly claim the same V2 module, §6.16 states the
split.

**Absorbed into a V3 module** (201 names):

| Destination | Retires |
|---|---|
| OmniAura | Killaura, Aura, SilentAura, TPAura, SilentAim, TriggerBot, AutoClicker, NoClickDelay, BackTrack |
| ReachControl | Reach, ReachDisplay, Extender |
| HitboxSolver | HitBoxes, HitFix |
| KnockbackControl | Velocity, KnockbackDelay |
| ArmorBreaker | ArmorSwitch, AutoTool |
| EffectNullifier | BalloonDisabler, KrystalDisabler, TrapDisabler, AntiLasso, AntiSuffocate, AntiRagdoll |
| AutoConsume | AutoConsume, FastConsume, PotionStatus |
| AntiLagback | AntiLagback, Disabler |
| ProjectileEngine | ProjectileAimbot, ProjectileAura, AutoShoot, BowAssist, AutoRelease, ProjectileLanding |
| TelepearlSolver | AutoPearl |
| IncomingProjectiles | ProjectileTracers, Arrows, ProjectileDodger |
| SpeedEngine | Speed, Step, LongJump, HighJump, BoostAirJump, InfiniteJump, Parkour |
| FlyEngine | Fly |
| BalloonFly | AutoBalloon |
| LassoSwing | AutoLasso |
| TeleportSuite | MouseTP |
| AntiVoid | AntiFall, NoFallDamage, SafeWalk |
| NoSlow | NoSlowdown, Sprint, KeepSprint |
| TargetOrbit | TargetStrafe, PlayerAttach |
| Scaffold | Scaffold, AutoBuildUp |
| BlockPlacer | Block-In, AutoSuffocate |
| Breaker | Breaker, FastBreak |
| BedBreaker | BedAssist |
| BedDefense | BedProtector |
| BedAlarm | BedAlarm |
| SmartBuy | AutoBuy, ShopClicker |
| AutoFarm | AutoBank, AutoSteal |
| DropManager | AutoVoidDrop, FastDrop |
| AutoFish | AutoFish, AutoHonor |
| AutoKit Engine | AutoKit, AutoKaida, OwlAura, VulcanAimbot, TerraAimbot, TritonClutch, MissileTP, RavenTP, GrimReaperFix |
| KitCounter | AutoCounter |
| PlayerESP | ESP, Chams, NameTags, Tracers, PlayerOutline, ArmorHighlight, Health, KitESP, KitDisplay |
| WorldESP | BedESP, BedPlates, GeneratorESP, StorageESP, LootESP, ItemESP, TrapESP, BeehiveESP |
| BlockESP | Xray |
| DamageNumbers | DamageIndicator, HitColor, WhiteHits |
| WorldTuner | IRLReplica, AbyssalDepths, StormMode, AuroraSky, ChillLighting, Shader, Bloom, MotionBlur, Fullbright, TimeChanger, Atmosphere |
| NoRender | PotatoMode, FPSBoost, ShadowRemover, RemoveNeon, FFlagEditor |
| UITuner | Interface, UICleanup, RemovePlayerLevelUI, StreamRemover, OG4v4v4v4 |
| CameraSuite | FOV, ZoomUnlocker, Freecam |
| ViewModel | Viewmodel, ViewmodelVisuals, LegacyAnimation |
| Crosshair | Crosshair |
| Autopilot | AutoPlay, AutoWin |
| QueueManager | AutoRejoin, Rejoin, ServerHop |
| AFKGuard | Anti-AFK |
| PanicButton | Panic |
| InteractEngine | PickupRange, FastInteraction, InteractExtender, ProximityPromptDuration, ProximityExtender |
| Cosmetics | SkinChanger, CustomTags, CustomCursor, InvisibleCursor, KillEffect, WinEffect, BedBreakEffect, ArmorTrims, ChinaHat, Cape, GamingChair, TexturePack, AnimationPlayer, SongBeats, SoundChanger, CleanKit, BlockSelectorColor, Breadcrumbs, Headless, OGNameTags, AutoEmote, NightmareEmote, CustomClanTag, TitleChanger, LARPKits |
| Spoofer | NameTagSpoofer, DeviceSpoofer, StateSpoofer, KillfeedSpoofer, WinstreakSpoofer, Disguise, PlayerModel, NametagSpoof, LeaderboardSpoof, PlayerProfileSpoof, StatsBoardSpoof, SetPlayerLevel, SetPlayerWins, ACMODView |
| Statistics | ViewMatchHistory |
| ChatFilter | ChatPosition, ChatNameColor |
| AutoHotbar | AutoHotbar |
| AutoGamble | AutoGamble |
| AimAssist | AimAssist |
| DesyncEngine *(gated)* | FakeLag, Desync, Blink |
| AntiDeath *(gated)* | AntiDeath |
| NoClip *(gated)* | NoClip |
| InfiniteShield *(gated)* | InfiniteShield |
| InstantKill *(gated)* | InstantKill |
| DamageBoost *(gated)* | DamageBoost |
| ShopTierBypass *(gated)* | ShopTierBypass |
| ProjectileExploit *(gated)* | ProjectileExploit |

**Not modules** (10 names) — they exist, they just aren't module rows:

| Destination | Names |
|---|---|
| HUD elements (§5.7) | FPS, Ping, Clock, Coords, Keystrokes, Speedmeter, Timer, Waypoints |
| GUI search (§5.3) | Search |
| Profiler panel (§5.6) | Memory |

**Deleted** (12 names), with the reason in §6.1: AutoToxic, ChatSpammer, ChatCrasher, StaffDetector,
CheatDetector, Schematica, Spider, Gravity, Swim, Invisible, SpinBot, MurderMystery.

**New in V3** (9 modules, no V2 ancestor): ShieldSync, ExplosiveSolver, AutoPath, BridgeCut,
TrapLayer, RushAlert, AutoLoot, EnchantAuto, VisualsOnly.

### 6.18 Cross-module behaviour rules

Overpowered modules interfere with each other more than they interfere with the game. The engine
enforces:

- **Declared conflicts** — FlyEngine vs. Scaffold's block-flight mode, AntiLagback vs. DesyncEngine,
  AimAssist vs. OmniAura's silent modes. Surfaced in the GUI, not silently broken.
- **One owner per channel** (§6.16) — attack, movement, block, camera, remote budget. Contention is
  a lint error, not a race.
- **Global rate ceiling** — all remote traffic passes RemoteBudget, so three modules cannot
  collectively spam past what the server tolerates.
- **Safety guards** — nothing acts while dead, in the lobby, in a cutscene, or during respawn.
- **Randomization is central** — Humanizer is one service, so every module's jitter is coherent
  rather than each rolling its own and producing a *more* distinctive fingerprint.
- **Auto-throttle on correction** — a lagback tells AntiLagback which module caused it, and that
  module backs off before the user notices.
- **No new module without a disposition check** — every proposal is diffed against §6.17 and tested
  against the six rules in §6.2 first. If an existing module already does 80% of it, it becomes a
  mode or an option of that module. That check is the entire difference between this list and V2's.

---

## 7. Behaviour & QoL

### 7.1 Configs & profiles

Named profiles with descriptions and tags · per-mode profiles (match vs lobby) auto-selected ·
inheritance (`rage` extends `base`) · diff view before applying an import · undo/redo (`Ctrl+Z`) ·
"compare with default" filter · export to a compressed string · auto-backup ring with one-click
restore · V2 profile migration · read-only lock so a tuned config can't drift.

### 7.2 Keybinds

Chords (`Ctrl+Shift+K`) and sequences (`G` then `A`) · modes: Toggle / Hold / Always / Double-tap /
On-release · conflict detection with a resolution prompt · bind profiles switchable independently of
module config · bind to *option* changes, not just module toggles · mouse 3/4/5 and scroll ·
controller bindings · "press any key" capture that handles modifiers · bind to open a category or
match panel · a reserved panic bind that can't be conflicted away.

### 7.3 Notifications

Priority levels with distinct styling · dedupe with `×N` · rate limiting so a looping module can't
spam the screen · persistent history · position picker · per-category mute · optional sound cues
(the bed alarm deserves a real one) · toast → banner escalation for critical errors · progress
notifications for long operations (AutoFarm phases, downloads) · "copy details" on error toasts.

### 7.4 Onboarding & discovery

First-run wizard (skin, preset, GUI bind, done) · tooltips on **every** option in **every** skin (14
in Rise vs 76 in Nexus today) · "what's new" panel after an update · guided tour of the match panels
· per-module long-form help, expandable inline · warning badges on modules known to be blatant ·
"recommended settings" button per module · empty-state text everywhere.

### 7.5 Everyday friction

Remember window positions, scroll offsets and expanded state per skin · `Esc` closes the topmost
window, `Esc` again closes the GUI · middle-click a module → its settings · shift-click → enable and
open settings · right-click → context menu (favourite, bind, reset, copy settings, help) ·
copy/paste settings between similar modules · bulk actions (disable category, disable all non-legit,
invert) · "disable all" that remembers state so you can restore it · search history and pinned
searches · drag to reorder modules (the `controller:ApplyOrder` scaffolding already exists) ·
collapse categories to one row · GUI opacity hotkey for screenshots.

### 7.6 Feedback & clarity

This is where V2 hurts most: modules that look enabled and do nothing.

- Show **why** a module is inactive — "waiting for character", "no valid target", "binding missing",
  "requires hookfunction", "throttled after lagback".
- Live value readouts on the module row: current reach, current CPS, current target.
- Status dot per module: green active / amber degraded / red errored / grey idle.
- Per-module error surface with the stack trace one click away.
- "Last used" and "total enabled time" per module.
- FPS/ms cost per module in the profiler.
- Executor compatibility badge per module.
- Ping indicator wherever latency-sensitive settings live.
- **"Patched in BedWars build X"** as a state visually distinct from "disabled" (§9).

---

## 8. Performance

- **Instance pooling** for ESP objects and notifications — reuse, don't recreate per frame.
- **Frustum culling** before any ESP work; **distance LOD** (boxes only past 100 studs).
- **Lazy skin construction** — build a category's GUI on first open, not at startup.
- **One scheduler** with per-bucket budgets (F4) replacing N spawned loops.
- **Shared match scan at 10 Hz** instead of a dozen modules each walking the workspace every frame
  for beds, generators and teams. Probably the single biggest FPS win available — and it only
  exists because of the BedWars-only scope.
- **Precompiled asset table** so `getcustomasset` isn't called 304 times on path strings.
- **Deferred autosave with dirty tracking** — `main.lua:610` currently rewrites the whole config
  every 10s forever, even when idle.
- **Targets:** < 2s warm-cache startup on a mid-tier executor; instance count reported and capped;
  leak test in CI.

---

## 9. Surviving BedWars Updates

The #1 cause of "the script broke" in this repo's history.

1. **One binding layer** (F1) — every `bedwars.*` access resolved and type-checked once, with
   `UsedBy` attribution, instead of ~400 scattered field reads failing in whatever order modules
   happen to run.
2. **Signature registry** — `data/signatures.json` records what each binding looked like per game
   build (`"SwordController.swingSword": "function(self, tool, target)"`, verified date). Compared
   against the live build at startup.
3. **Patch report** — on first launch after an update, a panel listing ✅ bindings that match,
   ⚠️ bindings that resolved but changed shape (and which modules use them), ❌ bindings that failed
   (and which modules are therefore off). Update day becomes a checklist instead of archaeology.
4. **Graceful degradation** — a module with a failed binding renders as **Patched** with a reason
   string, stays off, keeps its config, and works again the moment the binding is fixed.
   `features.json` stops being three hand-maintained arrays and becomes a *generated* output of the
   binding-health run.

---

## 10. Roadmap, Housekeeping & Open Questions

### 10.1 Phases

| Phase | Content |
|---|---|
| **0 — Scope cut** | Delete out-of-scope games + 10 alias stubs, `render.lua`, `cv`, `prem`, `cheatenginelib.lua` (port anything unique first). Fix B-07; audit B-01 against BedWars before deleting BedFight. Ships as a V2 point release: faster install, zero feature loss. |
| **1 — Core split** | Lift the shared core out of `new.lua` (F5), define the skin contract, port Nexus, add scheduler / state store / console. V2 skins stay loadable through a shim so nothing goes dark mid-migration. |
| **2 — Skin parity** | Classic, Legacy, Rise onto the core. B-02, B-03, B-04, B-06, B-08, B-12 mostly cease to exist. HUD editor + theme engine. |
| **3 — BedWars layer** | `bind.lua` + `signatures.json` **first** (everything depends on it), then match state, beds/generators/shop/inventory/kits helpers, split the 25k-line file by category, dissolve `universal.lua`. Fixes B-05, B-16. Ship the match panels — the first visibly new thing users get. |
| **4 — Module wave** | §6.3 shared services **first** — SwingTiming, TargetProvider, MovementChannel, BlockChannel, PathSolver, RemoteBudget, Humanizer — because every table below submits to one of them. Then Combat → Projectiles → Movement → Building → Objectives → Economy → Kits → Render → Utility → Legit, with the exploit tier (§6.15) last and behind its contract. **Render is the largest single reduction** (49 → 10); **Autopilot is the headline**; the 12 deletions in §6.1 ship in Phase 0 with the scope cut. |
| **5 — Behaviour wave** | §7, front-loading keybinds, notifications, search, onboarding, and §7.6 clarity. |
| **6 — Polish** | Profiler and network panels, config v2 + migration, loader hashing (B-11), docs, `version.txt` → `4.0`. |

### 10.2 Housekeeping

Delete: 9 out-of-scope game files + 10 alias stubs, `render.lua`, `cv`, `prem`,
`libraries/cheatenginelib.lua`, the whitelist stub. Merge: the duplicated splash builder (B-09).
Rewrite: `configs/*.json` in flat format. Add: `CONTRIBUTING.md` (module authoring guide),
`CHANGELOG.md`, `.editorconfig`, stylua/selene config, a lint + smoke check in CI.

**Projected: ~123k → ~38k lines, with substantially more features** — ~31k from dropped games, ~23k
from the unreferenced root files, ~20k from skin core deduplication, ~10k from `universal.lua` and
BedWars dedup.

**Conventions:** tabs; single quotes; module names `PascalCase` with no spaces; option names
`Sentence case`; no globals except `shared.aether`; game internals only via the binding layer;
every module ships a tooltip, a `Requires` list, a `GameBind` list, and an `OnDisable` that fully
reverses `OnEnable`.

### 10.3 Risks

| Risk | Mitigation |
|---|---|
| Users on dropped games lose support | Announce before Phase 0; V2 stays on a tag. One game done properly beats eleven done badly. |
| The rewrite stalls halfway | The Phase 1 compatibility shim is mandatory; every phase leaves `main` shippable. |
| `universal.lua` dissolution loses undocumented behaviour | Generate the module + option list before and after, and diff. Any asymmetry is explicit. |
| Users lose configs in migration | V2 profiles copied to `profiles/v2-backup/` untouched before any write. |
| BedWars ships a large update mid-port | §9 is scheduled first in Phase 3 precisely so update day is a diff, not archaeology. |
| The overpowered wave gets people banned faster than V2 did | §6.18 (rate ceiling, auto-throttle, safety guards), the §6.15 exploit contract, and blatancy badges (§7.4) are part of the module wave, not a follow-up. |
| Scope — §5–§7 is ~200 items | Deliberately independent and phased. Phases 0–3 are V3; 4–6 are continuous delivery after it. |

### 10.4 Open questions

1. **BedFight: dropped, or a variant?** This document assumes dropped. If usage justifies it, the
   alternative is a variant folder carrying only genuine deltas — maybe 800 lines, not 20,000.
   Decide with data.
2. **Four skins, or two plus community skins?** Recommendation: keep four — cheap once the core is
   split — but gate them behind the capability contract so a half-finished skin can't ship.
3. **Is Legit a category or a mode that reshapes every module's defaults?** Recommendation: a mode.
   It's what people actually mean, and it makes the 72 Legit registrations coherent.
4. **Do the 12 deleted modules (§6.1) need a deprecation path?** Recommendation: no for the six
   gimmicks and three griefing modules, but `StaffDetector` has real users who will notice. Announce
   it with the Phase 0 scope cut rather than silently in a module wave.
5. **Is Autopilot (§6.12) shipped on, or gated?** Recommendation: gated behind an explicit
   acknowledgement. It's the most powerful and the most conspicuous thing in the document.

---

*Sections 4–7 are actionable as written. Section 2 is a review gate: no module spec lands until its
mechanics are checked against Roblox BedWars rather than inherited from a Minecraft client.*
