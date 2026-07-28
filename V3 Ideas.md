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
- `bedwars.AbilityController` (26 refs) turns 30+ `Auto<Kit>` modules into one data-driven engine.
- Beds, generators, teams, forge level and match phase become one shared observable store instead
  of a dozen modules each walking the workspace every frame.

**Goals, in priority order:**

| # | Goal | Success criterion |
|---|------|-------------------|
| G1 | Fix everything known-broken | §4 triage closed; no module errors on toggle. |
| G2 | Expand the GUI hard | §5: full parity across skins + BedWars-native match panels. |
| G3 | Ship a large module wave | §6: 130+ new/rebuilt modules, weighted to the overpowered end. |
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
    UsedBy = {'OmniAura','ReachRamp','SwingTiming','ShieldSync'},
})
```

Resolved and type-checked once at load; a failure is named, attributed to its modules, and surfaced
(§9) instead of erroring 1,400 lines later.

**F2 — Match state store.** One observable table, scanned at 10 Hz, that every module reads instead
of rediscovering: `Phase`, `QueueType`, `Teams`, `Beds` (position / alive / layers / material),
`Generators` (type / tier / next spawn / contested), `ForgeLevel`, `Upgrades`, `Kits` per player,
`Alive`, `TimeLeft`. This single change is what makes the bed/generator/team/shop panels (§5.6),
the whole objectives module family (§6.5), and the biggest FPS win (§8) possible.

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
  present, "last damaged 4s ago". Click a bed → set it as the AutoWin / BedBreaker target.
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
  server is actually honouring right now (feeds `ReachEnvelope`, §6.1).
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

V2 already ships **207 unique module names** across the three game files (161 registrations in
BedWars, 70 universal, 16 lobby). Every one of them was read before this section was written;
**§6.14 is the full disposition audit** — each existing module is either absorbed by something
below (named in the *Absorbs* column), kept as-is, or dropped. Nothing here re-proposes a module
that already exists under a different name; where a new idea came close, it was demoted to a *mode*
of the module it duplicated, and §6.14 lists those collisions explicitly.

Overpowered is the default tier — the legit tier is §6.11 and is opt-in.

### 6.1 Combat — the overpowered core

| Module | Concept | Absorbs |
|---|---|---|
| **OmniAura** | One aura engine. Priority tree (lowest health → bedless → closest → aiming-at-me → weakest armor), per-target cooldowns, cadence curve, multi-target fan-out. **Modes: Swing / Silent / Packet** — Packet issues attacks straight through the sword remote with no animation, rotation or viewmodel tell. (A separate "PacketAura" module would have duplicated V2's `SilentAura`; it's a mode.) | Killaura, Aura, SilentAura, TPAura, OwlAura, TriggerBot, AutoClicker, NoClickDelay |
| **MultiHit** | Multiple accepted attack packets per cooldown window, bounded by what `CombatConstant` actually validates rather than by guesswork. | DamageBoost (blatant half stays in §6.13) |
| **ReachRamp** | Reach scaled by target velocity and your ping from `CombatConstant`, not a flat slider. Stays plausible at high latency; fixes B-16. | Reach (combat) |
| **ReachEnvelope** | Learns the true server-accepted reach live from accepted vs. rejected hits and draws it. Feeds ReachRamp and the hit-reg inspector. | ReachDisplay |
| **HitboxSolver** | Per-target hitbox expansion that *auto-shrinks* when the server starts rejecting — the difference between a hitbox module that works and one that gets you lagged back. | HitBoxes, HitFix |
| **HitSelect** | Picks which body part to send per target, learned from hit/miss feedback. | — |
| **SilentAim+** | Server-side aim for melee **and** projectiles; camera untouched. Kit-ability aiming (`VulcanAimbot`, `TerraAimbot`) is *not* absorbed here — it belongs to the kit engine (§6.7). | SilentAim |
| **PredictiveAura** | Attacks where the target *will* be, via `lib/prediction` — lands hits around bridge corners and on strafers. | — |
| **BackTrack+** | When the live position is rejected, attack a recorded recent position that isn't. | BackTrack |
| **TargetLock** | Hard-locks one target until death or range break; silent or smooth-camera. | — |
| **TargetOrbit** | Auto-strafes a locked target at a set radius and height, void-aware. | TargetStrafe, PlayerAttach |
| **KnockbackControl** | Full shaping over `KnockbackUtil`: horizontal/vertical multipliers, directional override, full negation, per-source rules (sword / fireball / TNT / ability). | Velocity, KnockbackDelay |
| **ComboKeeper** | Times hits against `KnockbackUtil` so the target never lands — the most oppressive thing in this list. | — |
| **VoidCombo** | Detects a combo pushing someone toward the void and biases aura angle to finish it. | — |
| **VoidPull** | Uses lasso to yank a target off their bridge or over the edge. | AutoLasso (offensive half) |
| **SwingTiming** | The shared cadence service — real sword cooldown from `CombatConstant` — that OmniAura, MultiHit and ShieldSync all time against, rather than three modules each guessing. Replaces the MC "CritTimer" idea; there are no crits here (§2). | — |
| **SprintSync** | Sprint state managed through `SprintController` so movement modules and aura stop fighting each other. | Sprint, KeepSprint |
| **ShieldSync** | Auto-raises the shield between attack windows and drops it to swing. The Roblox-correct version of "block hit". | InfiniteShield (behaviour half) |
| **ArmorBreaker** | Prioritizes the weakest-armor target and swaps to the tool that beats their tier, via `ItemMeta`. | ArmorSwitch, AutoTool |
| **EffectNullifier** | One data-driven nullifier for incoming effects — balloons, lassos, traps, suffocation, ragdoll, kit abilities. New effects are table entries, not new modules. Deliberately **not** called "Disabler": V2's `Disabler` is a movement-detection bypass and lives with AntiLagback+. | BalloonDisabler, KrystalDisabler, TrapDisabler, AntiLasso, AntiSuffocate, AntiRagdoll |
| **AntiDeath+** | Health-state desync with an auto-disable the moment the server corrects, instead of riding a broken state into a lagback. (V2's `Health` is a Render-category display, not a health spoof — it goes to UnifiedESP, §6.8.) | AntiDeath |
| **AutoConsume+** | Heal / speed / jump potions at thresholds, cooldown- and combat-aware, with pre-fight prep. | AutoConsume, FastConsume, PotionStatus |
| **KitCounter** | Per-enemy-kit counterplay: dodge known abilities, swap to the counter item, from `data/kits.json`. | AutoCounter |
| **RetaliationBot** | Fully idle until damaged, then engages for N seconds. The single best legit-adjacent behaviour. | — |
| **AntiBot** | Filters NPCs out of targeting with movement-entropy heuristics. | — |
| **AntiAim** | Spoofs your reported look vector — breaks enemy aim assists and rotation-based checks. Absorbing `SpinBot` also retires its "does not work in first person" tooltip (B-13) by handling the case. | SpinBot |
| **DesyncEngine** | Position-packet hold/burst with a live buffer visualizer and manual release. | FakeLag, Desync, Blink |
| **AntiLagback+** | Detects a server correction and reverts smoothly instead of snapping; auto-throttles whichever module triggered it. | AntiLagback, Disabler |

### 6.2 Projectiles

| Module | Concept | Absorbs |
|---|---|---|
| **ProjectileEngine** | One engine over `ProjectileMeta` + `BowConstantsTable`: per-projectile gravity, drag and launch velocity read from the game, not tuned. Aim, aura, auto-release and charge timing in one place. | ProjectileAimbot, ProjectileAura, AutoShoot, BowAssist, AutoRelease |
| **ArcPredict HUD** | Renders **your own** predicted arc and impact point live while charging. Other people's projectiles are ProjectileESP's job (§6.8) — the split V2 blurs across three modules. | ProjectileLanding |
| **DodgeNet** | Predicts every incoming projectile, shows time-to-impact, picks a dodge direction that doesn't walk you into the void. | ProjectileDodger |
| **FireballAssist** | Auto-aims fireballs at bridges and at players mid-bridge, with self-damage and self-knockback accounted for. | — |
| **TNTAssist** | Placement/throw solver against beds and defenses, layer-aware. | — |
| **TelepearlSolver** | Solves telepearl trajectories to a clicked destination through gravity and geometry. | AutoPearl |
| **ProjectileSpam** | Rate-limited multi-projectile fire respecting per-type cooldowns. | ProjectileExploit (gated, §6.13) |

### 6.3 Movement

| Module | Concept | Absorbs |
|---|---|---|
| **SpeedEngine** | One speed module with modes (CFrame / velocity / animation-safe), per-mode lagback profiles, and auto-fallback to the mode the server currently tolerates. | Speed, Step, LongJump, HighJump, BoostAirJump, InfiniteJump |
| **FlyEngine** | Acceleration-curved flight without the instant start/stop signature, plus waypoint paths, loop/reverse, altitude hold. | Fly |
| **BalloonFly** | Automated balloon use for vertical travel and clutch saves — the game's real flight, and the one that doesn't trip anything. | AutoBalloon |
| **LassoSwing** | Auto-lasso to a clicked destination or target, with swing-momentum handling. | AutoLasso |
| **TeleportSuite** | One TP module with a safety guard (no TP into void/blocks) covering mouse, kit-missile and kit-raven teleports. | MouseTP, MissileTP, RavenTP |
| **AutoPath** | A* to a clicked world point, bridging gaps automatically. | — |
| **AntiVoid+** | Predicts void and fall death, then cancels velocity, places a block, pops a balloon, or fires a telepearl — whichever is available. **Manual mode** binds the same recovery to a key (a separate "ClutchAssist" would have been the same code twice). | AntiFall, NoFallDamage, TritonClutch, SafeWalk |
| **NoSlow+** | Removes movement penalties (bow charge, item use, ability windup) as one module over `SprintController`. | NoSlowdown |
| **Strafe** | Air-strafe momentum control with a configurable friction model. | — |
| **Rewind** | Records the last N seconds of position; a key rewinds you along the path. | — |
| **Waypoints** | Named saved coordinates per map with an on-screen marker and pathing. | Waypoints |
| **AutoJump** | Auto-jumps gaps and steps around bases. Not MC parkour tech — just gap handling. | Parkour |
| **Freecam+** | Freecam with recording, spline paths, playback and a cinematic mode. | Freecam |
| **NoClip+** | Phase with a re-solidify guard so you don't get corrected into the void. (`Block-In` is offensive block placement, not clipping — it stays in §6.4.) | NoClip |

### 6.4 Building & breaking

| Module | Concept | Absorbs |
|---|---|---|
| **Scaffold+** | Predictive bridging: tower / flat / diagonal / downward, block conservation, sprint-safe, "don't bridge into the void" guard, and placement rate matched to what `BlockController` accepts. | Scaffold |
| **AutoBridge** | Bridges automatically along a pathfound route between islands. | AutoBuildUp |
| **BlockFly** | Scaffold-driven flight for maps and modes where FlyEngine is corrected. | — |
| **ReachPlace** | Places and interacts at the true maximum server-accepted distance, learned like `ReachEnvelope`. **Audit first:** V2's `Extender` is Blatant-category and may already be placement reach rather than combat reach — if so it belongs here, not with ReachRamp. Interaction range (chests, prompts, pickups) is InteractEngine's channel, §6.9. | Extender (pending audit) |
| **NukeBreaker** | Multi-block breaking in a configurable shape and radius over `BlockBreaker`, with tool auto-swap. | Breaker, FastBreak |
| **TunnelDig** | Digs a shaped tunnel through defenses, tool-aware. | — |
| **AutoDefense** | Auto-boxes you in when health drops below a threshold, using the best available block. Its offensive twin — boxing an *enemy* in — is V2's `Block-In`, kept as a mode here rather than reinvented. | Block-In |
| **AutoSuffocate+** | Kept from V2 as the offensive placement module; folded under one placement rate-limiter with everything else in this table so block modules stop fighting each other. | AutoSuffocate |
| **Schematic+** | Saved base layouts (defense box, bed shell, tower) auto-built from stored resources. | Schematica |

### 6.5 Beds & objectives

| Module | Concept | Absorbs |
|---|---|---|
| **BedIntel** | Unified bed tracking: layers, material, distance, damage history, defenders present. Feeds the bed panel and every module below. Data only — the visuals stay in BedPlates+ (§6.8). | BedESP |
| **BedBreaker** | Full-auto breaking: tool selection, layer-aware order, defense-first, resume after interruption, and a "don't start what you can't finish" check against nearby defenders. **Range mode** breaks from maximum accepted distance with no walk-in (a separate "BedAura" would have been this module with one option changed). | BedAssist |
| **BedDefense** | Auto-rebuilds your bed's exposed face with the best available block when damaged. | BedProtector |
| **BedAlarm+** | Directional alarm: who, from where, layers remaining, on-screen arrow, optional sound. | BedAlarm |
| **BedRoute** | Pathfinds to a chosen enemy bed, bridging gaps, avoiding known traps. | — |
| **DefenseAnalyzer** | Scores each bed's defenses (layers × material hardness × defenders) and recommends the easiest target. | — |
| **TrapMapper** | Maps enemy traps and landmines around each base; routes around or disarms them. | TrapESP (logic half) |
| **AutoWin+** | A state machine over match phase: last bed broken → hunt survivors → close the game. Replaces a fragile timing loop. | AutoWin |

### 6.6 Resources & economy

| Module | Concept | Absorbs |
|---|---|---|
| **GenIntel** | Generator tracking: tier, next-spawn countdown, contested state, income rate. Data only; the world visuals stay in GeneratorESP+ (§6.8). | — |
| **AutoFarm** | The full loop: collect from your gens → bank at the forge → buy the next upgrade → repeat, with configurable priorities. | AutoBank |
| **SmartBuy** | A priority list over `ItemMeta` with affordability, forge level, and "don't buy a sword I already beat" logic. | AutoBuy, ShopClicker, ShopQuickBuy |
| **ForgeManager** | Buys team forge tiers and upgrades by priority the moment the team can afford them. | — |
| **UpgradeAdvisor** | Recommends the next upgrade from match phase and enemy pressure. | — |
| **GenSteal** | Prioritized enemy-generator stealing with an escape route and a "leave before they respawn" timer. | AutoSteal |
| **DropManager** | Drop junk, protect priority items, void-drop enemy loot, auto-pickup by filter. Pickup *range* is InteractEngine's (§6.9); this owns the filter. | AutoVoidDrop, FastDrop |
| **EnchantAuto** | Auto-collects from and applies at the enchant table by priority. | — |
| **AutoFish+** | Solves the fishing minigame via `FishingMinigameController` and banks the output; the same minigame framework covers honor farming. | AutoFish, AutoHonor |
| **ResourceHUD** | Income rate per resource, time-to-afford for the next queued purchase. | — |

### 6.7 Kits — 30 modules into one engine

There are 30+ `Auto<Kit>` modules today (AutoKaida, plus the whole roster), each independently
written, independently broken, independently maintained. Replace all of them with **AutoKit Engine**
— one module plus `data/kits.json`:

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

A new kit becomes a data entry; every kit gets the same cooldown and priority system for free;
`KitCounter` and the kit panel read the same table; a kit broken by an update fails *visibly* in the
binding-health panel instead of silently. Plus:

- **KitAdvisor** — counterplay suggestions for the enemy kits present, shown in the lobby.
- **AbilityTimers** — HUD cooldown timers for every enemy ability, seeded from kill-feed and visual
  ability cues.
- **KitESP+** — kit icon over every player with ability-ready state. (Absorbs KitESP, KitDisplay.)
- **AbilityChain** — chains your own kit ability into the aura's combo window (e.g. ability → close
  → ComboKeeper) instead of firing it on cooldown blindly.
- **Ability aiming** — `VulcanAimbot` and `TerraAimbot` are kit-ability aimbots, not melee aimbots.
  They become aimed ability entries in `kits.json`, solved by ProjectileEngine (§6.2). Same for
  `TritonClutch` (kit clutch → AntiVoid+ recovery entry), `RavenTP` / `MissileTP` (kit teleports →
  TeleportSuite), `OwlAura` (kit aura → OmniAura), `KrystalDisabler` (→ EffectNullifier) and
  `GrimReaperFix`. **Every kit-named module in V2 is a kit-engine data entry in V3** — that's the
  30-modules-to-one claim, stated precisely.

### 6.8 Render & visuals

| Module | Concept | Absorbs |
|---|---|---|
| **UnifiedESP** | One ESP with a layer system — box / corner box / tracer / skeleton / chams / nametag / healthbar / armor / kit / distance / off-screen arrow — each independently toggled and coloured. | ESP, Chams, NameTags, Tracers, PlayerOutline, ArmorHighlight, Health |
| **BedPlates+** | Layer count, material icon, damage flash, team colour. | BedPlates |
| **GeneratorESP+** | Tier badge, spawn countdown ring, contested highlight. | GeneratorESP |
| **StorageESP+** | Chests and loot with a contents preview where readable. | StorageESP, LootESP, ItemESP |
| **TrapESP+** | Traps and landmines with arm state and blast radius. | TrapESP, BeehiveESP |
| **ProjectileESP** | **Other people's** projectiles: trajectories, predicted impact points, arrow trails. | ProjectileTracers, Arrows |
| **BlockESP** | See-through-defenses view: obsidian/team blocks and bed shells highlighted by hardness. This is what `Xray` should be in BedWars — not ore hunting (§2). | Xray |
| **DamageNumbers** | Floating damage/heal numbers with a combo counter — no crit styling, there are no crits. | DamageIndicator, HitColor |
| **KillFeed+** | Custom feed with kit icons, streaks and your kills highlighted. | KillfeedSpoofer (display half) |
| **WorldTuner** | The AetherIRL / Abyss / Storm / Aurora lighting families as one module with presets, plus time/atmosphere/brightness, and an FPS-cost label per preset. | IRLReplica, AbyssalDepths, StormMode, AuroraSky, ChillLighting, Shader, Bloom, MotionBlur, Fullbright, TimeChanger, Atmosphere |
| **NoRender** | Per-class checklist of particles/effects to stop rendering, for FPS. | PotatoMode, FPSBoost, ShadowRemover, RemoveNeon |
| **UITuner** | The game's own UI: hide, reposition or restyle BedWars HUD elements. Separate from NoRender because it's a legit-safe visual preference, not a performance switch. | Interface, UICleanup, RemovePlayerLevelUI, StreamRemover, OG4v4v4v4 |
| **CustomCrosshair** | Shape, gap, thickness, dot, dynamic spread, hit marker. | Crosshair |
| **CameraTweaks** | Third-person offsets, shoulder swap, zoom presets, FOV over `FovController`. | FOV, ZoomUnlocker |
| **ViewModel+** | FOV, position, rotation, sway, bob over `ViewmodelController`. | Viewmodel, ViewmodelVisuals, LegacyAnimation |
| **Trail** | Configurable motion trail for you or your targets. | Breadcrumbs |

### 6.9 Utility

| Module | Concept | Absorbs |
|---|---|---|
| **Autopilot** | The headline overpowered module: plays the match. Farm → bank → buy → rush the weakest bed (DefenseAnalyzer) → break → hunt survivors, with clutch recovery and a bail-out when outnumbered. Everything else in §6 is a component of it. | AutoPlay |
| **MacroEngine** | Record, replay, bind and share action macros as text. | — |
| **Scripting Console** | Sandboxed in-GUI Lua console with the core + BedWars API and autocomplete. Turns Aether into a platform. Opt-in behind a confirmation. | — |
| **QueueManager** | Auto-queues a chosen mode after a match, retries on failure, tracks winstreak across queues. | AutoRejoin, Rejoin, ServerHop |
| **AFK Suite** | Anti-idle, auto-respond, auto-reconnect, plus a log of what happened while away. | Anti-AFK, AutoToxic |
| **ChatFilter** | Client-side mute/highlight rules with regex, per player. | ChatPosition, ChatNameColor |
| **StaffDetector+** | Badge/group/gamepass heuristics, join alerts, configurable panic action. | StaffDetector, CheatDetector |
| **PanicButton** | One key: disable every non-legit module, restore camera/FOV/lighting, hide the GUI. | Panic |
| **ConfigSync** | Export/import configs as a string with a diff preview before applying. | — |
| **MatchRecorder** | Logs a match timeline (beds, kills, purchases) and replays it as a summary. | — |
| **Statistics** | Persistent lifetime stats — kills, beds, wins, winstreak, per-module usage. | — |
| **Cosmetics** | Skin / tag / cursor / effect / audio customization in one place, all purely local. | SkinChanger, CustomTags, CustomCursor, InvisibleCursor, KillEffect, WinEffect, BedBreakEffect, ArmorTrims, ChinaHat, Cape, GamingChair, TexturePack, AnimationPlayer, SongBeats, SoundChanger, CleanKit, BlockSelectorColor |
| **SpooferSuite** | Everything that misreports *you* to the server or to other clients, in one place with a single honesty setting — instead of five modules with five risk profiles. | NameTagSpoofer, DeviceSpoofer, StateSpoofer, KillfeedSpoofer (spoof half), WinstreakSpoofer, Disguise, PlayerModel |
| **InteractEngine** | One owner for interaction range and speed (chests, shops, prompts, pickups), so three modules stop stacking multipliers on the same channel. | PickupRange, FastInteraction, InteractExtender, ProximityPromptDuration |

### 6.10 Lobby

**WinstreakHUD** (streak, session record, next-milestone) · **AutoGamble+** with a configurable stop
rule · **OGNameTags** kept · **QueueAutomation** — pick mode, auto-ready, auto-requeue. The lobby's
`Sprint` is the same module as the match one (SprintSync, §6.1) and stops being duplicated;
`WinstreakSpoofer` moves to SpooferSuite (§6.9).

### 6.11 Legit mode

72 registrations currently have no home in two skins. Legit deserves real investment as a *mode*
that reshapes defaults, not just a category.

- **AimAssist+** — curve-driven smoothing, per-axis speed, FOV falloff, humanized jitter,
  target-switch delay.
- **LegitReach** — stays inside a plausible envelope and randomizes per swing.
- **Humanizer** — global jitter and latency variance applied to every automated action.
- **VisualsOnly** — one toggle: ESP and HUD, nothing that touches gameplay.
- **Presets** — Legit / Closet / Rage shipped in `configs/` as readable JSON, replacing the current
  double-encoded `cc.json` / `rage.json`.

### 6.12 Cross-module behaviour rules

Overpowered modules interfere with each other more than they interfere with the game. The engine
must enforce:

- **Declared conflicts** — `OmniAura` vs `PacketAura`, `FlyEngine` vs `BlockFly`, `SpeedEngine`
  modes. Surfaced in the GUI, not silently broken.
- **One owner per channel** — exactly one module writes velocity, one writes CFrame, one owns the
  attack remote. Contention is a lint error, not a race.
- **Global rate ceiling** — all remote traffic passes one budget so three modules can't collectively
  spam past what the server tolerates.
- **Safety guards** — nothing acts while dead, in the lobby, in a cutscene, or during respawn.
- **Randomization is central** — one humanization service, so every module's jitter is coherent
  rather than each rolling its own.
- **Auto-throttle on correction** — a lagback tells `AntiLagback+` which module triggered it, and
  that module backs off before the user notices.
- **No new module without a disposition check** — every proposal is diffed against §6.14 first. If
  an existing module already does 80% of it, it becomes a mode or an option of that module. This is
  how V2 ended up with four auras, three projectile aimbots and five lighting modules.

### 6.13 Exploit tier

Highest churn, most likely to break. Policy, not a wish list:

- Every exploit module sits behind a **capability probe** and self-disables cleanly when its
  primitive is unavailable, instead of erroring.
- Each shows **"last verified against BedWars build X"** in the GUI so users know what's stale.
- **AutoPatchCheck** compares the live build against `data/signatures.json` at load and warns which
  modules are likely broken this build (§9).
- Existing entries (`ProjectileExploit`, `ShopTierBypass`, `InstantKill`, `DamageBoost`,
  `InfiniteShield`, `GrimReaperFix`) get audited into this contract or deleted — no module ships in
  the current state of "works until it silently doesn't."

### 6.14 Existing-module disposition audit

All **207** unique module names in V2, each with exactly one destination. Nothing proposed in
§6.1–§6.13 duplicates a module that already exists: where two engines could plausibly claim the
same V2 module, the split is stated in the row itself.

**Absorbed into a §6 engine** (the module is retired; its behaviour becomes a mode or option):

| Engine | Retires |
|---|---|
| OmniAura | Killaura, Aura, SilentAura, TPAura, OwlAura, TriggerBot, AutoClicker, NoClickDelay |
| ReachRamp / ReachEnvelope | Reach, ReachDisplay |
| HitboxSolver | HitBoxes, HitFix |
| SilentAim+ / AimAssist+ *(legit, §6.11)* | SilentAim, AimAssist |
| KnockbackControl | Velocity, KnockbackDelay |
| ArmorBreaker | ArmorSwitch, AutoTool |
| EffectNullifier | BalloonDisabler, KrystalDisabler, TrapDisabler, AntiLasso, AntiSuffocate, AntiRagdoll |
| AntiDeath+ / AntiLagback+ | AntiDeath, AntiLagback, Disabler |
| DesyncEngine | FakeLag, Desync, Blink |
| AntiAim | SpinBot |
| TargetOrbit / BackTrack+ | TargetStrafe, PlayerAttach, BackTrack |
| AutoConsume+ | AutoConsume, FastConsume, PotionStatus |
| KitCounter | AutoCounter |
| SprintSync / ShieldSync | Sprint, KeepSprint, InfiniteShield *(exploit half → §6.13)* |
| ProjectileEngine | ProjectileAimbot, ProjectileAura, AutoShoot, BowAssist, AutoRelease *(audit: Utility-category in V2)* |
| ArcPredict / DodgeNet / TelepearlSolver | ProjectileLanding, ProjectileDodger, AutoPearl |
| SpeedEngine | Speed, Step, LongJump, HighJump, BoostAirJump, InfiniteJump |
| FlyEngine / BalloonFly / LassoSwing | Fly, AutoBalloon, AutoLasso |
| TeleportSuite | MouseTP, MissileTP, RavenTP |
| AntiVoid+ | AntiFall, NoFallDamage, TritonClutch, SafeWalk |
| NoSlow+ / AutoJump / NoClip+ / Freecam+ / Waypoints | NoSlowdown, Parkour, NoClip, Freecam, Waypoints |
| Scaffold+ / AutoBridge / NukeBreaker / Schematic+ | Scaffold, AutoBuildUp, Breaker, FastBreak, Schematica |
| AutoDefense / AutoSuffocate+ | Block-In, AutoSuffocate |
| ReachPlace | Extender *(pending audit)* |
| BedIntel / BedBreaker / BedDefense / BedAlarm+ / AutoWin+ | BedESP, BedAssist, BedProtector, BedAlarm, AutoWin |
| AutoFarm / SmartBuy / GenSteal / DropManager | AutoBank, AutoBuy, ShopClicker, ShopQuickBuy, AutoSteal, AutoVoidDrop, FastDrop |
| AutoFish+ | AutoFish, AutoHonor |
| AutoKit Engine | AutoKit, AutoKaida *(and every other `Auto<Kit>`)*, VulcanAimbot, TerraAimbot, GrimReaperFix |
| KitESP+ | KitESP, KitDisplay |
| UnifiedESP | ESP, Chams, NameTags, Tracers, PlayerOutline, ArmorHighlight, Health |
| BedPlates+ / GeneratorESP+ / StorageESP+ / TrapESP+ | BedPlates, GeneratorESP, StorageESP, LootESP, ItemESP, TrapESP, BeehiveESP |
| ProjectileESP | ProjectileTracers, Arrows |
| BlockESP | Xray |
| DamageNumbers / KillFeed+ | DamageIndicator, HitColor |
| WorldTuner | IRLReplica, AbyssalDepths, StormMode, AuroraSky, ChillLighting, Shader, Bloom, MotionBlur, Fullbright, TimeChanger, Atmosphere |
| NoRender / UITuner | PotatoMode, FPSBoost, ShadowRemover, RemoveNeon, Interface, UICleanup, RemovePlayerLevelUI, StreamRemover, OG4v4v4v4 |
| CustomCrosshair / CameraTweaks / ViewModel+ / Trail | Crosshair, FOV, ZoomUnlocker, Viewmodel, ViewmodelVisuals, LegacyAnimation, Breadcrumbs |
| Autopilot / QueueManager / AFK Suite | AutoPlay, AutoRejoin, Rejoin, ServerHop, Anti-AFK, AutoToxic |
| StaffDetector+ / PanicButton | StaffDetector, CheatDetector, Panic |
| ChatFilter | ChatPosition, ChatNameColor |
| Cosmetics | SkinChanger, CustomTags, CustomCursor, InvisibleCursor, KillEffect, WinEffect, BedBreakEffect, ArmorTrims, ChinaHat, Cape, GamingChair, TexturePack, AnimationPlayer, SongBeats, SoundChanger, CleanKit, BlockSelectorColor |
| SpooferSuite | NameTagSpoofer, DeviceSpoofer, StateSpoofer, KillfeedSpoofer, WinstreakSpoofer, Disguise, PlayerModel |
| InteractEngine | PickupRange, FastInteraction, InteractExtender, ProximityPromptDuration |

**Kept as standalone modules** (nothing above duplicates them; they just get the new lifecycle,
config and status surface): AutoHotbar, AutoGamble, OGNameTags, Spider, Gravity, Swim *(audit: no
water on most maps — likely delete)*, Invisible, ChatSpammer, ChatCrasher, Memory, FFlagEditor,
Search, Timer, DamageBoost, InstantKill, ProjectileExploit, ShopTierBypass *(last five → §6.13)*.

**Become HUD elements, not modules** (they're overlays in the HUD editor, §5.7): FPS, Ping, Clock,
Coords, Keystrokes, Speedmeter.

**Dropped:** MurderMystery (other game).

**Near-duplicates caught by this audit** — ideas that were cut or demoted rather than shipped
alongside something that already exists:

| Proposed | Collided with | Resolution |
|---|---|---|
| PacketAura | `SilentAura` | Mode of OmniAura, not a module. |
| BedAura | `BedAssist` / BedBreaker | Range mode of BedBreaker. |
| ClutchAssist | `TritonClutch` / AntiVoid+ | Manual mode of AntiVoid+. |
| DisablerEngine (name) | `Disabler` (movement detection) | Renamed EffectNullifier; `Disabler` went to AntiLagback+. |
| SwingTiming as an aura | OmniAura cadence | Demoted to the shared timing service both use. |
| ProjectileESP vs ArcPredict | `ProjectileTracers` / `ProjectileLanding` | Split: yours vs theirs. |
| BedIntel vs BedPlates+ | `BedESP` / `BedPlates` | Split: data vs visuals. Same for GenIntel/GeneratorESP+. |
| ReachPlace vs InteractEngine | `InteractExtender`, `Extender` | Split: block placement vs interaction range. |
| DropManager vs InteractEngine | `PickupRange` | Range is InteractEngine's; filtering is DropManager's. |
| "CritTimer", "BlockHit" | — | Deleted outright: Minecraft mechanics that don't exist here (§2). |

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
| **4 — Module wave** | §6 in order: Combat → Projectiles → Movement → Building → Beds → Economy → Kits engine → Render → Utility → Legit. **AutoKit Engine is the highest-leverage single item** (retires 30 modules); **Autopilot is the headline**. |
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
| The overpowered wave gets people banned faster than V2 did | §6.12 (rate ceiling, auto-throttle, safety guards) and blatancy badges (§7.4) are part of the module wave, not a follow-up. |
| Scope — §5–§7 is ~200 items | Deliberately independent and phased. Phases 0–3 are V3; 4–6 are continuous delivery after it. |

### 10.4 Open questions

1. **BedFight: dropped, or a variant?** This document assumes dropped. If usage justifies it, the
   alternative is a variant folder carrying only genuine deltas — maybe 800 lines, not 20,000.
   Decide with data.
2. **Four skins, or two plus community skins?** Recommendation: keep four — cheap once the core is
   split — but gate them behind the capability contract so a half-finished skin can't ship.
3. **Is Legit a category or a mode that reshapes every module's defaults?** Recommendation: a mode.
   It's what people actually mean, and it makes the 72 Legit registrations coherent.
4. **Does the Scripting Console ship enabled?** Recommendation: no — opt-in behind a confirmation,
   since it runs arbitrary code against the core.
5. **Is Autopilot (§6.9) shipped on, or gated?** Recommendation: gated behind an explicit
   acknowledgement. It's the most powerful and the most conspicuous thing in the document.

---

*Sections 4–7 are actionable as written. Section 2 is a review gate: no module spec lands until its
mechanics are checked against Roblox BedWars rather than inherited from a Minecraft client.*
