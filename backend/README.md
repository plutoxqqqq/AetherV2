# AetherV2 Community Config Backend 2.0

This dependency-free Node 20 service powers Community Configs 2.0. It validates submissions, forks and updates, stores only hashed ownership receipts, prevents content-hash duplicates, tracks unique downloads, ratings and favorites, exposes creator/compatibility metadata and reporting, provides an authenticated review queue, and publishes accepted changes through bot-created branches and pull requests.

## Security and reliability

- JSON schema checks cap names, descriptions, tags, IDs, categories, and the 2 MB request body.
- Read and write rate limits are enforced independently per client IP.
- Every response includes x-request-id and x-aether-api-version: 2.
- CORS echoes only an origin listed in ALLOWED_ORIGINS; requests without an Origin header remain supported for Roblox executors.
- Maintainer authentication uses a timing-safe bearer-token comparison.
- Uploader receipt tokens are returned once and persisted only as SHA-256 hashes.
- Config payloads have canonical SHA-256 identities for duplicate and integrity checks.
- Every mutation creates a bounded audit record with a hashed actor, action, target, outcome, timestamp, and request ID.
- The JSON database is behind a replaceable storage interface and uses verified temporary-file renames.
- GitHub publishing stages the config and catalogue on a bot branch, rolls back the branch if either half fails, and opens a pull request. Deletion also restores the catalogue if payload deletion fails.

## Run locally

Requirements: Node 20 or newer, persistent storage, HTTPS in production, and outbound access to api.github.com.

    cd backend
    export ADMIN_KEY='a long random value'
    export GITHUB_TOKEN='github_pat_...'
    export GITHUB_REPO='plutoxqqqq/AetherV2'
    export GITHUB_BRANCH='main'
    export GITHUB_PUBLISH_MODE='pr'
    export DATA_FILE='/data/aether-community.json'
    export ALLOWED_ORIGINS='https://www.roblox.com,https://create.roblox.com'
    npm test
    npm start

Useful optional settings:

- PORT defaults to 3000.
- RATE_WINDOW_MS defaults to 60000.
- RATE_READ_LIMIT defaults to 180 per window.
- RATE_WRITE_LIMIT defaults to 20 per window.
- TRUST_PROXY must be true only behind a trusted proxy that overwrites X-Forwarded-For.
- GITHUB_PUBLISH_MODE may be direct for a staging repository; production should use pr.
- VERIFIED_CREATORS is an optional comma-separated list of creator credits that receive the verified badge.

The GitHub token needs Contents read/write and Pull requests read/write on only the configured repository. Protect the base branch and never put ADMIN_KEY or GITHUB_TOKEN in Lua, source control, shared profiles, or logs.

## Client connection

Put the HTTPS service origin, with no trailing route, in:

    aetherv2/profiles/configbackend.txt

A custom executor session can instead set getgenv().AetherConfigBackend. Only the maintainer should have aetherv2/profiles/configadminkey.txt. Ordinary users authenticate updates with the random receipt returned by their original accepted submission.

## API v2

Both the unprefixed compatibility routes and /v2-prefixed routes are accepted. All responses carry the v2 header.

- GET /v2/health reports storage, publishing mode, and API version.
- POST /submissions validates and queues a new config.
- POST /public-configs/:file/updates validates the original ownership receipt and queues a versioned update.
- GET /submissions?status=pending requires maintainer authentication.
- GET /submissions/:id accepts the uploader receipt or maintainer authentication.
- PATCH /submissions/:id accepts an authenticated accept/reject decision. Acceptance creates a publication branch and PR.
- GET /public-configs returns the sortable catalogue with download and rating data.
- GET /public-configs/:file returns the config with an integrity ETag and unique-download accounting.
- GET /public-configs/:file/versions returns its published version history.
- POST /public-configs/:file/ratings stores one replaceable vote per Roblox user and installation.
- POST /public-configs/:file/favorites stores one favorite per Roblox user and installation.
- POST /public-configs/:file/reports opens one bounded moderation report per user/config.
- GET /creators/:name returns the creator page, verified state, configs, and aggregate downloads.
- GET /reports requires maintainer authentication.
- DELETE /public-configs/:file accepts the owner receipt or maintainer authentication and opens a rollback-safe deletion PR.

Submission metadata can include `minimumVersion`, `gameVersion`, up to four screenshot URLs, and `forkOf`. Published manifests expose those fields plus owner-controlled deprecation status; the client keeps them in the compact details panel instead of adding more catalogue-row controls.

Every success body includes success: true. Failures include success: false and a stable error string; upstream details are included only when useful. Use the x-request-id value to correlate a client error with audit and platform logs.

## Storage and recovery

backend/lib/database.js contains the storage contract. JsonDatabase is the default; MemoryDatabase is used by integration tests and is an example for a future SQL adapter. Back up DATA_FILE and restrict it to the service account because it contains submission data and hashed receipts.

If a publication fails before the PR is opened, the bot branch restores the previous payload/catalogue state. If the process stops after a PR is opened, the protected base branch is still unchanged: close the PR or delete the bot branch. For database recovery, stop the service, restore DATA_FILE from backup, and restart.
