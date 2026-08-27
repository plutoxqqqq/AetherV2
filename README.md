> [!WARNING]
> AetherV2 is a private, key-gated build. Do not commit or post access keys, Discord tokens, or GitHub tokens.

# AetherV2

AetherCore Rebirth rebirthed. The current distribution uses a private source proxy, short-lived source sessions, and per-user access keys managed through Discord.

## Running AetherV2

Each approved user receives a unique loader from an owner. It has this shape:

```lua
loadstring(game:HttpGet(
    "https://YOUR-SOURCE-ORIGIN/loader?key=YOUR-ONE-TIME-ASSIGNED-KEY",
    true
))()
```

The key binds to the first verified Roblox username/UserId that authorizes it. Do not use the public raw-GitHub loadstring from older releases; the active loader retrieves client files through the authenticated source proxy.

Raw keys are intentionally not stored. Discord shows a new or rotated raw key and its loader once, in an ephemeral response. Later key management uses the SHA-256 key ID only; a lost raw key must be rotated, not recovered.

Revoked and expired keys invalidate existing source sessions on their next request. Renewing sets a future expiry and reactivates the key. Rotation revokes the old key, invalidates its sessions, and creates a replacement.

## Interface

The supported main interface is `guis/new.lua`. The retired `newer.lua`/Nexus implementation has been removed; old `newer` profile selections migrate to `new` automatically.

Settings → GUI includes a **Transparency** slider from 0% to 80%. At 0% the interface keeps its original appearance. Higher values progressively add restrained liquid-glass translucency, highlight, edge, and blur effects while keeping controls readable.

## Backend development

The backend directory contains:

- `private-source.js` — key-gated source proxy and short-lived sessions.
- `key-registry.js` — validated GitHub-backed key registry.
- `discord-bot.js` — owner-only key-management commands and dashboard.
- `server.js` — the separate public-config review API.

```bash
cd backend
npm install
npm run check
npm test
```

Deployment, environment variables, command behavior, and security limitations are documented in [backend/README.md](backend/README.md).

## Executors

AetherV2 expects an executor with strong Luau and filesystem support. Executor behavior can change, so test the private loader in a controlled account before distributing a key.

[Join the official Discord server](https://discord.gg/aYu5c9v9zv)
