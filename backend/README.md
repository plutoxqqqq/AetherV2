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

## 3. Deploy

1. Create a new service from this repository and set its root/working directory to `backend`.
2. Use `npm start` as the start command; no build command is needed.
3. Add `ADMIN_KEY`, `GITHUB_TOKEN`, `GITHUB_REPO=plutoxqqqq/AetherV2`, `GITHUB_BRANCH=main`, and optionally `DATA_FILE=/data/aether-submissions.json` as secret environment variables.
4. Mount a persistent volume at `/data` when using that `DATA_FILE` value. Without a volume, decisions and duplicate history disappear on redeploy.
5. Expose the assigned `PORT`, enable HTTPS, and test `curl https://YOUR-HOST/submissions` returns HTTP 401.
6. Restrict platform logs and dashboard access. Rotate both keys immediately if either is exposed.

Accepted submissions create/update `configs/<slug>.json`, then update `configs/presets.json`. GitHub therefore records auditable commits. Protect `main` appropriately; if direct writes are prohibited, set `GITHUB_BRANCH` to a publishing branch and merge its commits through a pull request.

## 4. Connect Aether clients

Create this local executor file (the directory exists after Aether first starts):

```text
aetherv2/profiles/configbackend.txt
```

Its only content is the HTTPS origin, with no trailing route, for example `https://aether-configs.example.com`. Alternatively set `getgenv().AetherConfigBackend` before loading Aether.

Only the maintainer should create `aetherv2/profiles/configadminkey.txt`, containing the exact `ADMIN_KEY`. Do **not** share a config folder containing this file. Regular uploaders need no secret. They receive a random per-submission receipt token, stored locally in `configsubmissions.json`, which can reveal only that submission's decision.

## 5. API contract and operations

* `POST /submissions` validates metadata and config data and returns `{id, token, status}`. The server returns HTTP 409 when the config data is identical to any prior submission.
* `GET /submissions?status=pending` requires `Authorization: Bearer <ADMIN_KEY>` and powers the review queue.
* `GET /submissions/:id?token=<receipt>` lets an uploader retrieve only their outcome.
* `PATCH /submissions/:id`, also admin-authenticated, accepts `{"action":"accept"}` or `{"action":"reject","reason":"..."}`. Acceptance publishes to GitHub before recording success.

For production, monitor disk space and HTTP 5xx responses, back up `DATA_FILE`, keep Node patched, rate-limit POST requests at the reverse proxy, and allow request bodies no larger than 2 MB (the application also enforces this). Restore by redeploying with the same environment secrets and restored data file. Test acceptance on a non-protected staging branch before enabling the live maintainer key.
