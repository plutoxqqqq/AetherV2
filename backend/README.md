# AetherV2 config review backend

This small, dependency-free Node service stores submissions, rejects identical config payloads, exposes an authenticated review queue, returns decisions to uploaders, and publishes accepted configs plus their catalogue entry through GitHub's Contents API.

## 1. Requirements

* A host with **Node 20 or newer**, HTTPS, persistent disk, and outbound access to `api.github.com` (Railway, Render, Fly.io, a VPS, or a container host all work).
* A fine-grained GitHub personal access token for `plutoxqqqq/AetherV2`, limited to **Contents: Read and write**. Never put this token in Lua or commit it.
* A long random maintainer key. Generate one with `openssl rand -hex 32`.

## 2. Configure and run locally

```bash
cd backend
export ADMIN_KEY='paste-the-random-maintainer-key'
export GITHUB_TOKEN='github_pat_...'
export GITHUB_REPO='plutoxqqqq/AetherV2'
export GITHUB_BRANCH='main'
export DATA_FILE="$PWD/data.json"
npm test
npm start
```

`PORT` defaults to `3000`. `DATA_FILE` must be on a persistent volume in production. Back it up: it contains uploader receipt tokens and review outcomes (but no GitHub credential). Put the service behind HTTPS; the Roblox executor sends metadata and the admin key to it.

## 3. Private Aether source proxy

The same service can proxy private Aether source files while keeping the GitHub token on the server. It exposes:

* `GET /source?path=init.lua&ref=main` to return a repository file.
* `GET /commit?ref=main` to return the commit SHA.
* `GET /tree?ref=<sha>` to return the recursive Git tree used by the updater.

The proxy is intentionally only a source-at-rest protection layer. Once an authorized executor receives Lua source, that client can inspect or copy it. The existing owner lock still performs the runtime account check, but no client-side Lua system can make copied code impossible to modify.

After deployment, set the executor environment before running the loader:

```lua
getgenv().AetherV2SourceEndpoint = 'https://YOUR-BACKEND-HOST'
loadstring(game:HttpGet('https://YOUR-PUBLIC-LOADER-URL/loadstring', true))()
```

If the loader itself is not hosted separately, keep a one-line copy of the loader in a private admin location and replace `YOUR-PUBLIC-LOADER-URL` with that public bootstrap URL. The private repository cannot host its own first-stage loader after visibility is changed.

## 4. Deploy

1. Create a new service from this repository and set its root/working directory to `backend`.
2. Use `npm start` as the start command; no build command is needed.
3. Add `ADMIN_KEY`, `GITHUB_TOKEN`, `GITHUB_REPO=plutoxqqqq/AetherV2`, `GITHUB_BRANCH=main`, and optionally `DATA_FILE=/data/aether-submissions.json` as secret environment variables.
4. Mount a persistent volume at `/data` when using that `DATA_FILE` value. Without a volume, decisions and duplicate history disappear on redeploy.
5. Expose the assigned `PORT`, enable HTTPS, and test `curl https://YOUR-HOST/submissions` returns HTTP 401.
6. Restrict platform logs and dashboard access. Rotate both keys immediately if either is exposed.

Accepted submissions create/update `configs/<slug>.json`, then update `configs/presets.json`. GitHub therefore records auditable commits. Protect `main` appropriately; if direct writes are prohibited, set `GITHUB_BRANCH` to a publishing branch and merge its commits through a pull request.

## 5. Connect Aether clients

Create this local executor file (the directory exists after Aether first starts):

```text
aetherv2/profiles/configbackend.txt
```

Its only content is the HTTPS origin, with no trailing route, for example `https://aether-configs.example.com`. Alternatively set `getgenv().AetherConfigBackend` before loading Aether.

Only the maintainer should create `aetherv2/profiles/configadminkey.txt`, containing the exact `ADMIN_KEY`. Do **not** share a config folder containing this file. Regular uploaders need no secret. They receive a random per-submission receipt token, stored locally in `configsubmissions.json`, which can reveal only that submission's decision.

## 6. API contract and operations

* `POST /submissions` validates metadata and config data and returns `{id, token, status}`. The server returns HTTP 409 when the config data is identical to any prior submission.
* `GET /submissions?status=pending` requires `Authorization: Bearer <ADMIN_KEY>` and powers the review queue.
* `GET /submissions/:id?token=<receipt>` lets an uploader retrieve only their outcome.
* `PATCH /submissions/:id`, also admin-authenticated, accepts `{"action":"accept"}` or `{"action":"reject","reason":"..."}`. Acceptance publishes to GitHub before recording success.
* `DELETE /public-configs`, also admin-authenticated, accepts `{"file":"known-preset.json"}`. The service verifies the file against the live catalogue, unlists it, and deletes its config file before returning success. A Roblox username is never accepted as authorization.

Every response is JSON and includes a `success` boolean. Failed operations also include
an `error` message (and `details` when the upstream service supplies useful context), so
clients do not have to infer success from response text.

For production, monitor disk space and HTTP 5xx responses, back up `DATA_FILE`, keep Node patched, rate-limit POST requests at the reverse proxy, and allow request bodies no larger than 2 MB (the application also enforces this). Restore by redeploying with the same environment secrets and restored data file. Test acceptance on a non-protected staging branch before enabling the live maintainer key.
