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

## Community Configs

Users submit configs from the Community Configs window in the GUI. Reviewers accept or reject them.

- The moderation tools (Review queue, Publish now, Edit, Delete) are offered only to the accounts in `configapi.Presets.Reviewers` in `guis/new.lua`: `plutoxqqqqqq` and `aetherv2owner`. Names are compared lowercase on both sides, so `AetherV2Owner`, `aetherv2owner` and `AETHERV2OWNER` all match. Extend the list on one install with `getgenv().AetherConfigReviewers = {'name', 12345}`, or add UserIds to `Reviewers.UserIds` so a rename cannot lock a reviewer out.
- That list only decides who is shown the buttons. The real gate is `ADMIN_KEY`: every moderation write and `GET /admin/verify` require it. The client reads it from `aetherv2/profiles/configadminkey.txt`, or a reviewer pastes it into the Review window's key bar once.
- To add or remove a reviewer: change the list and give the account the current `ADMIN_KEY`. Rotate `ADMIN_KEY` on the service to revoke every reviewer at once.

Default backend: `https://aether-config-backend.aether-config-backend-plutoxqq.workers.dev`  
Override with `getgenv().AetherConfigBackend` or `aetherv2/profiles/configbackend.txt`. Every
backend route the client uses — Community Configs, premium sessions and analytics — resolves
through that one origin via `configapi.Presets.Route`, so a single override repoints the client.

## Backend

One entrypoint, `index.js`, serves every route behind one origin: Community Configs (`ADMIN_KEY`),
the premium source proxy plus analytics, and the Discord key bot (`DISCORD_TOKEN`). Set
`PREMIUM_GITHUB_REPO` to load the premium stack; without it the same process serves Community
Configs alone. The modules it composes:

- `server.js` — Community Configs API and GitHub publishing (`ADMIN_KEY`)
- `private-source-core.js` — premium source proxy and sessions
- `private-source.js` — standalone premium entrypoint
- `key-registry.js` — GitHub-backed key registry
- `discord-bot.js` — owner-only key commands (`DISCORD_OWNER_IDS`)
- `data-path.js` — resolves every mutable state file under `backend/data/`

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
