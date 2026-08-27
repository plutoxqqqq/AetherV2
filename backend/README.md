# AetherV2 backend services

This directory contains the key-gated private-source service, its Discord management bot, and the separate config-review service.

## Security model

The Discord bot generates a random 256-bit key and returns the raw value exactly once in an ephemeral response. The registry stores only its SHA-256 key ID plus safe metadata, binding, usage count, and audit history.

On first authorization, a key binds to a Roblox username/UserId verified against Roblox. Successful later authorizations by that same identity increment the usage count. Source access uses a short-lived in-memory session, but every `/source`, `/tree`, and `/commit` request rechecks the session’s key ID against the live registry. Revocation or expiry therefore invalidates existing sessions instead of waiting for their session TTL.

The proxy allows only configured refs and client path prefixes. It fails closed if the registry or GitHub cannot be checked. Requests have timeouts and bounded retries; registry mutations retry GitHub SHA conflicts idempotently.

The application never stores or logs raw keys. Key IDs, usernames, and UserIds are safe to log. Note that loaders place a raw key in an HTTPS query string because Roblox executors use `game:HttpGet`; hosting/CDN access logs must therefore be disabled or tightly restricted and redacted.

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
PUBLIC_ORIGIN=https://source.example.com

DISCORD_TOKEN=...
DISCORD_APPLICATION_ID=...
DISCORD_OWNER_IDS=123456789012345678,optional_second_owner
DISCORD_GUILD_ID=optional_test_guild
```

`DISCORD_OWNER_IDS` contains immutable Discord user IDs. Display names and usernames never authorize management actions. `DISCORD_GUILD_ID` makes command updates appear immediately in that guild; without it, commands register globally.

Legacy `AETHER_KEY`, `AETHER_KEYS`, and singular `DISCORD_OWNER_ID` fallbacks are no longer read. Keys already represented in the registry continue to work; an old environment-only raw key that never received a registry record must be replaced with `/key generate`.

## Optional hardening and capacity variables

```text
AETHER_REGISTRY_FILE=backend/key-bindings.json
AETHER_ALLOWED_REFS=main
AETHER_ALLOWED_PATHS=init.lua,main.lua,loadstring,version.txt,cv,gui,assets/,configs/,games/,guis/,libraries/,profiles/
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

## Running and deploying

The source proxy can start the bot in the same process:

```bash
npm run start:source
```

If `DISCORD_TOKEN` is absent, only the proxy runs. The bot can also run separately with `npm run start:bot`. The older config-review service runs with `npm start` and uses its own `ADMIN_KEY` and `DATA_FILE` settings.

For a combined deployment, use `node private-source.js`, an HTTPS origin matching `PUBLIC_ORIGIN`, and outbound access to GitHub, Roblox, and Discord. Protect service logs and dashboard access. The first registry write creates or upgrades the version-3 registry through GitHub’s Contents API.

## Discord key commands

All key-management responses are ephemeral and restricted to configured Discord managers:

- `/key panel` — dashboard with totals, key list, audit log, and refresh.
- `/key generate` — creates a key and shows the raw key/loader once in copy-button code blocks.
- `/key list` — paginated list, filterable by status, username, label, and source.
- `/key info` — copy-friendly safe details for a full key ID or unique prefix.
- `/key edit` — changes label or expiry. `none` clears either value.
- `/key renew` — sets a required future expiry and reactivates an expired/revoked key.
- `/key unlink` — asks for confirmation, then removes the Roblox binding.
- `/key revoke` — asks for confirmation, records a `revoke` event, and invalidates source sessions.
- `/key enable` — enables a non-expired revoked key and records an `enable` event.
- `/key rotate` — asks for confirmation, revokes the old key, transfers its binding, and shows the replacement raw key once.
- `/key audit` — paginated, size-bounded audit output.

Raw keys cannot be listed, inspected, or recovered because they are not stored. Rotate when a user loses one.

## Registry and failure behavior

The complete registry structure is validated before reads are accepted or writes are sent. Key records, bindings, usage counters, dates, rotation links, and audit events are checked; malformed or orphaned data is rejected rather than normalized silently.

Registry mutations carry an operation ID. If GitHub reports a SHA conflict, timeout, rate limit, or transient server failure, the operation rereads the registry and retries without duplicating generation, binding usage, or audit events.

Source and authorization rate limits are per process and per observed client IP. Leave `AETHER_TRUST_PROXY=false` unless the service is reachable only through a trusted reverse proxy that replaces `X-Forwarded-For`. Sessions and limiter buckets are in memory, so a restart invalidates sessions and resets limits. Run a shared external limiter/session store if deploying multiple replicas. A GitHub or registry outage intentionally blocks source access until validation is available.

## Config-review service

`server.js` remains separate from key management. It accepts config submissions, exposes an `ADMIN_KEY`-protected review queue, and publishes accepted config files through GitHub. Its persistent `DATA_FILE` must be backed up. Do not reuse Discord, GitHub, admin, or Aether access keys across roles.
