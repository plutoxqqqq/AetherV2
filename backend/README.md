# AetherV2 backend services

The backend folder contains the private source proxy and the older config-review service. The source proxy keeps the GitHub repository private and gives each approved person a key-bound, short-lived loader session.

## 1. Key-gated private source proxy

### What it does

1. You put one or more random keys in Render.
2. You give each person a loader containing their assigned key.
3. The first time the loader runs, it reads the executor's Roblox username and UserId, checks that username/UserId pair with Roblox, and asks the proxy to bind that key.
4. The proxy stores the binding in backend/key-bindings.json using a SHA-256 key ID. The raw key is never committed or printed to logs.
5. A key already bound to one account is rejected for a different username/UserId.
6. The proxy returns a short-lived session token. Only that session can request init.lua, the client tree, commits, and the other client files needed by AetherV2.

Unauthenticated users can only receive the small bootstrap loader when they provide a valid key. Direct /source, /tree, and /commit requests return HTTP 401 without a session. Backend files are blocked by the proxy.

This protects the source while it is stored in GitHub. It cannot make code impossible to copy after an authorized executor receives it, and a modified executor can spoof client-reported identity. The existing owner lock remains useful as a second runtime check.

### Required environment variables

Use a fine-grained GitHub token limited to this repository:

~~~
GITHUB_TOKEN=github_pat_...
GITHUB_REPO=plutoxqqqq/AetherV2
GITHUB_BRANCH=main
AETHER_KEYS=first-random-key,second-random-key
AETHER_SESSION_MINUTES=120
~~~

The token needs **Contents: Read and write** because the first use of a key writes its binding to the private repository. Keep the token only in Render's secret environment variables.

Generate a key locally with:

~~~
openssl rand -hex 32
~~~

Put one or more generated values in AETHER_KEYS, separated by commas. Do not commit the raw values to GitHub.

Optional:

~~~
PUBLIC_ORIGIN=https://aetherv2.onrender.com
~~~

If PUBLIC_ORIGIN is not set, the service uses the incoming Render host.

### Free Render setup

Render's free web service is enough for this small proxy:

1. Create a web service from the private plutoxqqqq/AetherV2 repository.
2. Set Root Directory to backend.
3. Leave Build Command blank.
4. Set Start Command to node private-source.js.
5. Add the environment variables above.
6. Deploy and test:

~~~
https://YOUR-RENDER-HOST/health
~~~

A healthy response contains "keyGating":true.

Free Render services can sleep when idle. If a restart clears the in-memory session, run the keyed loader again. The key binding itself persists in the private GitHub registry.

### Per-person loader

Give each person a loader with their own assigned key:

~~~
loadstring(game:HttpGet(
    'https://aetherv2.onrender.com/loader?key=ASSIGNED_KEY',
    true
))()
~~~

Replace ASSIGNED_KEY before sending it. The repository's loadstring file is also a template that can use getgenv().AetherV2SourceEndpoint and getgenv().AetherV2Key.

The public flow is:

~~~
/loader?key=assigned-key
        -> /authorize?key=...&username=...&userId=...
        -> short-lived session
        -> /source, /tree, /commit
~~~

The first-stage loader contains only the endpoint, the assigned key, and the identity handshake. It does not contain AetherV2 source.

### Future Discord bot

The current source of valid keys is the Render AETHER_KEYS variable. A future Discord bot can generate/revoke keys and update the same private registry or a small admin endpoint. The registry already stores stable key IDs, usernames, UserIds, first-use time, and usage metadata, so it can be extended without changing the loader protocol.

## 2. Config-review backend

The separate config-review service stores submissions, rejects identical config payloads, exposes an authenticated review queue, returns decisions to uploaders, and publishes accepted configs plus their catalogue entry through GitHub's Contents API.

### Local setup

~~~
cd backend
export ADMIN_KEY='paste-the-random-maintainer-key'
export GITHUB_TOKEN='github_pat_...'
export GITHUB_REPO='plutoxqqqq/AetherV2'
export GITHUB_BRANCH='main'
export DATA_FILE="$PWD/data.json"
npm test
npm start
~~~

PORT defaults to 3000. The review service needs a persistent DATA_FILE in production because it contains uploader receipt tokens and review outcomes.

### Deploying config review

1. Create a separate service from this repository.
2. Use backend as the root/working directory.
3. Use npm start as the start command.
4. Set ADMIN_KEY, GITHUB_TOKEN, GITHUB_REPO, GITHUB_BRANCH, and optionally DATA_FILE=/data/aether-submissions.json.
5. Mount persistent storage at /data if using that path.
6. Test that GET /submissions returns HTTP 401 without the admin key.

Accepted submissions create/update configs/<slug>.json, then update configs/presets.json. Protect main appropriately; if direct writes are prohibited, set GITHUB_BRANCH to a publishing branch and merge its commits through a pull request.

### Client connection

Create:

~~~
aetherv2/profiles/configbackend.txt
~~~

Its only content is the HTTPS origin of the config-review service. Only the maintainer should create aetherv2/profiles/configadminkey.txt; do not share a config folder containing that file.

### API contract

* POST /submissions validates metadata and config data and returns {id, token, status}.
* GET /submissions?status=pending requires Authorization: Bearer <ADMIN_KEY>.
* GET /submissions/:id?token=<receipt> lets an uploader retrieve only their outcome.
* PATCH /submissions/:id accepts {"action":"accept"} or {"action":"reject","reason":"..."}.
* DELETE /public-configs removes a known public config after admin authentication.

For production, monitor HTTP 5xx responses, back up DATA_FILE, keep Node patched, rate-limit requests at the reverse proxy, and rotate secrets immediately if they are exposed.
