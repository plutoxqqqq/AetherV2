> [!WARNING]
> Do not commit or post access keys, Discord tokens, GitHub tokens, or `ADMIN_KEY`.

# AetherV2

Public AetherV2 loads from GitHub. Premium modules are optional and key-gated through Discord plus the premium source proxy.

## Running AetherV2

Public loader:

```lua
loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/init.lua', true), 'init.lua')()
```

Optional premium key (unlocks private `AetherV2Premium` modules only):

```lua
loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/init.lua', true), 'init.lua')({
	Closet = false,
	premiumKey = "KEY_HERE"
})
```

A raw premium key is shown once in Discord. It binds to the first verified Roblox username/UserId. Lost keys must be rotated. Revoke, expire, or rotate invalidates premium sessions; public AetherV2 keeps working.

## Interface

Supported UI: `guis/new.lua`. Old `newer` profile values migrate to `new`. Settings → GUI has a Transparency slider (0%–80%).

## Public configs

Users submit configs from Public Configs in the GUI. Reviewers accept or reject them.

- Review button is shown only to Roblox names in `reviewAccounts` inside `guis/new.lua` (currently `aetherv2owner`, `plutoxqqqqqq`).
- API auth is `ADMIN_KEY` on the config backend. The client sends it from `aetherv2/profiles/configadminkey.txt`.
- To change reviewers: edit that `reviewAccounts` table and give each reviewer the same `ADMIN_KEY`. Rotate `ADMIN_KEY` on the Worker/service to revoke access.

Default backend: `https://aether-config-backend.aether-config-backend-plutoxqq.workers.dev`  
Override with `getgenv().AetherConfigBackend` or `aetherv2/profiles/configbackend.txt`.

## Backend

- `private-source.js` — premium source proxy and sessions
- `key-registry.js` — GitHub-backed key registry
- `discord-bot.js` — owner-only key commands (`DISCORD_OWNER_IDS`)
- `server.js` — config-review API (`ADMIN_KEY`)

```bash
cd backend
npm install
npm run check
npm test
```

See [backend/README.md](backend/README.md).

## Executors

Needs an executor with solid Luau and filesystem support.

[Join the official Discord server](https://discord.gg/aYu5c9v9zv)
