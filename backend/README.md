# AetherV2 backend services

This directory contains one service with one entrypoint, `index.js`, that serves every route: the Community Configs API, the optional premium-key source proxy, its execution analytics, and the Discord management bot. Normal AetherV2 loads publicly from GitHub without a key.

## Security model

The Discord bot generates a random 256-bit key and returns the raw value exactly once in an ephemeral response. The registry stores only its SHA-256 key ID plus safe metadata, binding, usage count, and audit history.

On first authorization, a key binds to a Roblox username/UserId verified against Roblox. Successful later authorizations by that same identity increment the usage count. Premium access uses a short-lived in-memory session, and every `/premium/source` and `/premium/tree` request rechecks the key status and current Roblox binding against the live registry. Revocation or expiry therefore invalidates existing sessions instead of waiting for their session TTL.

The premium proxy allows only the configured private premium branch and premium path prefixes. It fails closed if the registry or GitHub cannot be checked. Requests have timeouts and bounded retries; registry mutations retry GitHub SHA conflicts idempotently.

The application never stores or logs raw keys. Key IDs, usernames, and UserIds are safe to log. Premium authorization sends the raw key to `/premium/authorize` over HTTPS, so hosting/CDN access logs must be disabled or tightly restricted and redacted.

## Requirements

- Node.js 20 or newer.
- A private GitHub repository and fine-grained token with **Contents: Read and write** for the registry branch.
- HTTPS for the public source origin.
- A Discord application with the `applications.commands` scope. Administrator permission is not required.

Install and verify:

```bash
cd backend
npm install
npm run check
npm test
```

`package-lock.json` is committed; production should use `npm ci`.

## Required environment variables

```text
GITHUB_TOKEN=github_pat_...
GITHUB_REPO=plutoxqqqq/AetherV2
GITHUB_BRANCH=main
# Private repository holding only premium modules; grant this token Contents: Read.
PREMIUM_GITHUB_REPO=plutoxqqqq/AetherV2Premium
PREMIUM_GITHUB_BRANCH=main
PUBLIC_ORIGIN=https://source.example.com

DISCORD_TOKEN=...
DISCORD_APPLICATION_ID=...
DISCORD_OWNER_IDS=123456789012345678,optional_second_owner
DISCORD_GUILD_ID=optional_test_guild
```

`PREMIUM_GITHUB_REPO` doubles as the switch that loads the premium stack: leave it unset and the same process serves Community Configs only, so a configs deployment never needs `PUBLIC_ORIGIN`. `ADMIN_KEY` authenticates the Community Configs review queue and is never used by the premium routes.

`DISCORD_OWNER_IDS` contains immutable Discord user IDs. Display names and usernames never authorize management actions. `DISCORD_GUILD_ID` makes command updates appear immediately in that guild; without it, commands register globally.

Legacy `AETHER_KEY`, `AETHER_KEYS`, and singular `DISCORD_OWNER_ID` fallbacks are no longer read. Keys already represented in the registry continue to work; an old environment-only raw key that never received a registry record must be replaced with `/key generate`.

## Optional hardening and capacity variables

```text
AETHER_REGISTRY_FILE=backend/key-bindings.json   # path on the registry branch, not a local file
AETHER_ALLOWED_REFS=main
AETHER_ALLOWED_PATHS=init.lua,main.lua,loadstring,version.txt,assets/,configs/,games/,guis/,libraries/,profiles/
# Restrict private premium files to the module paths the client needs.
PREMIUM_ALLOWED_PATHS=games/
AETHER_SESSION_MINUTES=120
AETHER_MAX_SESSIONS=2000
AETHER_MAX_SESSIONS_PER_KEY=3
AETHER_REQUEST_TIMEOUT_MS=8000
AETHER_GITHUB_RETRIES=3
AETHER_GITHUB_CONFLICT_RETRIES=4
AETHER_RETRY_BASE_MS=150
AETHER_RATE_WINDOW_MS=60000
AETHER_RATE_LIMIT=180
AETHER_AUTH_RATE_LIMIT=20
AETHER_TRUST_PROXY=false
AETHER_AUDIT_LIMIT=500
```

The configured `GITHUB_BRANCH` is always approved and is used by generated session loaders. Additional refs must be listed explicitly. Keep the path list limited to files the client genuinely needs; backend, workflow, Git metadata, and arbitrary repository files are denied by default.


## Premium modules

The public `init.lua` always loads normal AetherV2 from GitHub. When the optional `premiumKey` is valid, it authorizes a short-lived session with `/premium/authorize`, then reads the private `AetherV2Premium` tree through `/premium/tree`. Invalid, revoked, expired, or omitted keys do not interrupt the public loader.

Premium modules are discovered automatically from this layout:

```text
games/
  universal/
    blatant/
      module.lua
    render/
      module.lua
  <PlaceId>/
    blatant/
      module.lua
    world/
      module.lua
```

All universal modules load first, then modules for the current `PlaceId`. Every category folder is supported—including `blatant`, `render`, and `world`—and empty folders require no special handling. Each module receives `(vape, license, context)`, where `context.Category` is the matching AetherV2 category name and `context.CategoryApi` is its API when the category exists. A module may either register directly or return a function that receives the same arguments.

Keep `AetherV2Premium` private and grant the Render service's fine-grained GitHub token **Contents: Read** on it. Do not place its GitHub token or private URLs in the client loader.

## Running and deploying

`npm start` runs the whole service on one port:

```bash
npm start
```

The premium stack is loaded only when `PREMIUM_GITHUB_REPO` is set, because it validates its own settings while it loads. A deployment that sets it gets configs, premium, analytics and the Discord bot together; one that omits it serves Community Configs alone from the same process and the same folder. Set `PREMIUM_GITHUB_REPO` plus `PUBLIC_ORIGIN` to enable it, and `DISCORD_TOKEN` to start the bot in-process.

The split entrypoints still exist for a deployment that wants them separately:

```bash
npm run start:configs   # Community Configs only
npm run start:source    # premium proxy, analytics and the bot
npm run start:bot       # the Discord bot by itself
```

Every route serves the same origin either way. Point the client at one URL with `getgenv().AetherConfigBackend` or `aetherv2/profiles/configbackend.txt`; the client resolves each route through `configapi.Presets.Route`.

An HTTPS origin matching `PUBLIC_ORIGIN` and outbound access to GitHub, Roblox, and Discord are required for the premium routes. Protect service logs and dashboard access: `/premium/authorize` receives raw keys, so hosting and CDN access logs must be disabled or redacted. The first registry write creates or upgrades the version-3 registry through GitHub’s Contents API.

`GET /health` reports which capabilities this process loaded (`configs`, `premiumEnabled`, `executionAnalytics`, `discordBot`).

## State

Every mutable file lives in `backend/data/`, resolved by `data-path.js` against this directory rather than the process working directory:

- `data/configs.json` — submissions, review decisions, bans, ratings, download counts and version history (`DATA_FILE`).
- `data/execution-stats.json` — execution analytics (`AETHER_STATS_FILE`).

Each default keeps reading the pre-merge location (`backend/data.json`, `backend/execution-stats.json`) until the file is moved by hand, so an upgrade cannot start from an empty store. On a host with a persistent disk, set `DATA_FILE` and `AETHER_STATS_FILE` to the mounted paths instead and back them up.

`backend/key-bindings.json` is not live state: it is the local mirror of the registry that lives at the same path **on the `AETHER_REGISTRY_BRANCH` branch of `GITHUB_REPO`**. `AETHER_REGISTRY_FILE` and `AETHER_CONFLICT_FILE` are repository paths on that branch, not local filenames, so changing them moves where the registry is stored. The registry and the conflict ledger are read from and written to GitHub; there is no local registry database.

## Discord key commands

All key-management responses are ephemeral and restricted to configured Discord managers:

- `/key panel` — dashboard with totals, key list, audit log, and refresh.
- `/key generate` — creates an optional premium key and shows the raw key plus the public GitHub `premiumKey` loadstring once. Copyable values use both fenced code blocks and inline code for desktop/mobile.
- `/key list` — paginated list, filterable by status, username, label, and source.
- `/key info` — safe premium-key details; full key IDs, Roblox usernames/UserIds, and dates use both fenced and inline copy formats.
- `/key edit` — changes label or expiry. `none` clears either value.
- `/key renew` — sets a required future expiry and reactivates an expired/revoked key.
- `/key unlink` — asks for confirmation, then removes the Roblox binding.
- `/key revoke` — asks for confirmation, records a `revoke` event, and invalidates premium sessions; normal AetherV2 remains public.
- `/key enable` — enables a non-expired revoked key and records an `enable` event.
- `/key rotate` — asks for confirmation, revokes the old key, transfers its binding, and shows the replacement raw key once.
- `/key audit` — paginated, size-bounded audit output.

Raw keys cannot be listed, inspected, or recovered because they are not stored. Rotate when a user loses one.

## Registry and failure behavior

The complete registry structure is validated before reads are accepted or writes are sent. Key records, bindings, usage counters, dates, rotation links, and audit events are checked; malformed or orphaned data is rejected rather than normalized silently.

Registry mutations carry an operation ID. If GitHub reports a SHA conflict, timeout, rate limit, or transient server failure, the operation rereads the registry and retries without duplicating generation, binding usage, or audit events.

Source and authorization rate limits are per process and per observed client IP. Leave `AETHER_TRUST_PROXY=false` unless the service is reachable only through a trusted reverse proxy that replaces `X-Forwarded-For`. Sessions and limiter buckets are in memory, so a restart invalidates sessions and resets limits. Run a shared external limiter/session store if deploying multiple replicas. A GitHub or registry outage intentionally blocks premium access until validation is available; normal public AetherV2 is unaffected.

## Community Configs service

`server.js` is a route group of the merged service and shares nothing with key management except the process. It accepts config submissions, exposes an `ADMIN_KEY`-protected review queue, and publishes accepted config files through GitHub. Its persistent `DATA_FILE` must be backed up. Do not reuse Discord, GitHub, admin, or Aether access keys across roles: merging the services merged the process, not the credentials.

The API paths keep their published `/public-configs` names so older clients keep working, even though the window and the docs now call the feature Community Configs.

Who can review:

- API: anyone presenting `Authorization: Bearer $ADMIN_KEY`. Set `ADMIN_KEY` on the service. Rotate that value to drop every reviewer at once.
- In-game: the tools are offered only to the accounts in `configapi.Presets.Reviewers` in `guis/new.lua` (`plutoxqqqqqq`, `aetherv2owner`; names match case-insensitively and UserIds may be listed alongside them). That list decides who is shown the buttons and nothing else. The client is published, so it can be read and a modified client can claim any username or UserId — treat the list as a menu filter, never as authorisation.
- The key is the gate. `GET /admin/verify` answers `200` only for the accepted key, which is how the client distinguishes a real key from a typo before it unlocks anything; every moderation write is checked separately.
- Client reads the key from `aetherv2/profiles/configadminkey.txt`, or the reviewer pastes it into the Review window's key bar, which writes that file.

How to change reviewers:

1. Add the account to `Reviewers` in `guis/new.lua`, preferably with its UserId, or extend it for one install with `getgenv().AetherConfigReviewers`.
2. Give each reviewer `configadminkey.txt` containing the current `ADMIN_KEY`, or let them paste it into the Review window once.
3. Restart the service after changing `ADMIN_KEY`.
4. `DISCORD_OWNER_IDS` does not grant config-review access.

## Execution analytics

The public loader reports one execution to the premium-source service without sending a premium key. When the executor exposes a request API, the report includes the Roblox UserId so the backend can count unique players; only a one-way SHA-256 hash is persisted. Executors without a request API still increment the anonymous execution total.

For durable all-time stats on Render, attach a persistent disk to the merged `npm start` service and set:

```text
AETHER_STATS_FILE=/var/data/execution-stats.json
AETHER_ANALYTICS_RATE_LIMIT=60
```

Run the Discord bot in the same process (`npm start`) so it reads the same live stats store. `/stats summary` shows the current hour, day, week, month, and all-time totals. `/stats graph` renders a PNG line graph for hourly (24 points), daily (30), weekly (12), or monthly (12) data and can graph either executions or unique players. Buckets use UTC.

The client-side report is intentionally lightweight and can be spoofed by a modified client, so these numbers are product telemetry rather than tamper-proof billing/security data. The analytics endpoint is separately rate-limited and never accepts or stores raw premium keys.
