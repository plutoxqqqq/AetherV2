'use strict';

const crypto = require('node:crypto');
const registry = require('./key-registry');

const REPOSITORY = process.env.GITHUB_REPO || '';
const BRANCH = process.env.AETHER_REGISTRY_BRANCH || 'aether-key-registry';
const TOKEN = process.env.GITHUB_TOKEN || '';
const CONFLICT_FILE = process.env.AETHER_CONFLICT_FILE || 'backend/key-conflicts.json';
const REQUEST_TIMEOUT_MS = Math.max(1000, Math.min(30000, Number(process.env.AETHER_REQUEST_TIMEOUT_MS) || 8000));
const RETRIES = Math.max(0, Math.min(6, Number(process.env.AETHER_GITHUB_RETRIES) || 3));
const CONFLICT_RETRIES = Math.max(1, Math.min(8, Number(process.env.AETHER_GITHUB_CONFLICT_RETRIES) || 4));
const MAX_CONFLICTS = Math.max(50, Math.min(5000, Number(process.env.AETHER_CONFLICT_LIMIT) || 1000));
const originalBindKey = registry.bindKey.bind(registry);
let queue = Promise.resolve();

const headers = {
  authorization: 'Bearer ' + TOKEN,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-key-conflicts',
  'x-github-api-version': '2022-11-28'
};
const problem = (message, status = 400, extra = {}) => Object.assign(new Error(message), {status, ...extra});
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const nowIso = () => new Date().toISOString();
const cleanActor = value => String(value || 'unknown').trim().slice(0, 100) || 'unknown';
const cleanUsername = value => String(value || '').trim();
const cleanUserId = value => String(value || '').trim();
const validUsername = value => /^[A-Za-z0-9_]{3,20}$/.test(value);
const validUserId = value => /^\d{1,20}$/.test(value);
const validKeyId = value => /^[a-f0-9]{64}$/.test(String(value || ''));
const validConflictId = value => /^[a-f0-9]{24}$/.test(String(value || ''));

if (!TOKEN) throw new Error('GITHUB_TOKEN is required');
if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(REPOSITORY)) throw new Error('GITHUB_REPO must be configured as owner/repository');

const empty = () => ({version: 1, conflicts: {}, bans: {}});
const endpoint = () => 'https://api.github.com/repos/' + REPOSITORY + '/contents/' + CONFLICT_FILE;

const validate = input => {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw problem('Conflict registry must be an object', 502);
  if (input.version !== 1 || !input.conflicts || typeof input.conflicts !== 'object' || Array.isArray(input.conflicts) || !input.bans || typeof input.bans !== 'object' || Array.isArray(input.bans)) {
    throw problem('Conflict registry has an invalid shape', 502);
  }
  const conflictEntries = Object.entries(input.conflicts);
  if (conflictEntries.length > MAX_CONFLICTS) throw problem('Conflict registry exceeds the configured limit', 502);
  for (const [id, item] of conflictEntries) {
    if (!validConflictId(id) || !item || typeof item !== 'object' || !validKeyId(item.keyId)) throw problem('Conflict registry contains an invalid conflict', 502);
    if (!validUsername(item.boundUsername) || !validUserId(String(item.boundUserId))) throw problem('Conflict registry contains an invalid bound identity', 502);
    if (!validUsername(item.attemptedUsername) || !validUserId(String(item.attemptedUserId))) throw problem('Conflict registry contains an invalid attempted identity', 502);
    if (!['open', 'resolved', 'ignored'].includes(item.status)) throw problem('Conflict registry contains an invalid status', 502);
    if (!Number.isSafeInteger(item.attempts) || item.attempts < 1) throw problem('Conflict registry contains an invalid attempt count', 502);
    if (!Number.isFinite(Date.parse(item.firstSeenAt)) || !Number.isFinite(Date.parse(item.lastSeenAt))) throw problem('Conflict registry contains an invalid timestamp', 502);
  }
  for (const [userId, ban] of Object.entries(input.bans)) {
    if (!validUserId(userId) || !ban || typeof ban !== 'object' || !validUsername(ban.username) || !Number.isFinite(Date.parse(ban.bannedAt)) || typeof ban.bannedBy !== 'string') {
      throw problem('Conflict registry contains an invalid user ban', 502);
    }
  }
  return input;
};

const githubRequest = async (url, options = {}, retries = RETRIES) => {
  let last;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const response = await fetch(url, {...options, headers: {...headers, ...(options.headers || {})}, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS)});
      if (!(response.status === 408 || response.status === 429 || response.status >= 500) || attempt === retries) return response;
      last = problem('GitHub conflict-store request failed with HTTP ' + response.status, 502);
    } catch (error) {
      last = problem('GitHub conflict-store request failed', 502, {cause: error});
      if (attempt === retries) throw last;
    }
    await wait(150 * (2 ** attempt));
  }
  throw last || problem('GitHub conflict-store request failed', 502);
};

const readStore = async () => {
  const response = await githubRequest(endpoint() + '?ref=' + encodeURIComponent(BRANCH));
  if (response.status === 404) return {data: empty(), sha: null};
  if (!response.ok) throw problem('Could not read key conflicts (HTTP ' + response.status + ')', 502);
  const remote = await response.json();
  if (!remote || typeof remote.content !== 'string' || typeof remote.sha !== 'string') throw problem('GitHub returned an invalid conflict store', 502);
  let parsed;
  try { parsed = JSON.parse(Buffer.from(remote.content.replace(/\n/g, ''), 'base64').toString('utf8')); }
  catch (error) { throw problem('Key conflict store is invalid JSON', 502, {cause: error}); }
  return {data: validate(parsed), sha: remote.sha};
};

const writeStore = async (data, sha, message) => {
  validate(data);
  const response = await githubRequest(endpoint(), {
    method: 'PUT',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({
      message: message || 'Update AetherV2 key conflicts',
      branch: BRANCH,
      content: Buffer.from(JSON.stringify(data, null, 2) + '\n').toString('base64'),
      ...(sha && {sha})
    })
  }, 0);
  if (!response.ok) {
    const retryable = response.status === 409 || response.status === 422 || response.status === 429 || response.status >= 500;
    throw problem('Could not write key conflicts (HTTP ' + response.status + ')', retryable ? 409 : 502, {retryable});
  }
};

const mutate = (message, fn) => {
  const work = async () => {
    let last;
    for (let attempt = 0; attempt < CONFLICT_RETRIES; attempt += 1) {
      const current = await readStore();
      const result = await fn(current.data);
      if (result && result.changed === false) return result.result;
      try {
        await writeStore(current.data, current.sha, message);
        return result && result.result;
      } catch (error) {
        last = error;
        if (!error.retryable || attempt === CONFLICT_RETRIES - 1) throw error;
        await wait(150 * (2 ** attempt));
      }
    }
    throw last || problem('Conflict update failed', 502);
  };
  const next = queue.then(work, work);
  queue = next.catch(() => undefined);
  return next;
};

const conflictId = (keyId, attemptedUserId) => crypto.createHash('sha256').update(keyId + ':' + attemptedUserId).digest('hex').slice(0, 24);

const recordConflict = async ({keyId, bound, attempted}) => mutate('Record AetherV2 key conflict', async data => {
  const id = conflictId(keyId, attempted.userId);
  const timestamp = nowIso();
  const existing = data.conflicts[id];
  if (existing) {
    existing.attemptedUsername = attempted.username;
    existing.lastSeenAt = timestamp;
    existing.attempts += 1;
    if (existing.status !== 'open') {
      existing.status = 'open';
      delete existing.resolution;
      delete existing.resolvedAt;
      delete existing.resolvedBy;
    }
  } else {
    data.conflicts[id] = {
      keyId,
      boundUsername: bound.username,
      boundUserId: String(bound.userId),
      attemptedUsername: attempted.username,
      attemptedUserId: String(attempted.userId),
      firstSeenAt: timestamp,
      lastSeenAt: timestamp,
      attempts: 1,
      status: 'open'
    };
  }
  const keys = Object.keys(data.conflicts);
  if (keys.length > MAX_CONFLICTS) {
    keys.sort((a, b) => Date.parse(data.conflicts[a].lastSeenAt) - Date.parse(data.conflicts[b].lastSeenAt));
    for (let i = 0; i < keys.length - MAX_CONFLICTS; i += 1) delete data.conflicts[keys[i]];
  }
  return {result: {conflictId: id, conflict: data.conflicts[id]}};
});

const isBanned = async userId => {
  const id = cleanUserId(userId);
  if (!validUserId(id)) return false;
  const current = await readStore();
  return Boolean(current.data.bans[id]);
};

const strictBindKey = async (id, person) => {
  const username = cleanUsername(person && person.username);
  const userId = cleanUserId(person && person.userId);
  if (!validUsername(username) || !validUserId(userId)) throw problem('Invalid Roblox identity');
  const current = await readStore();
  if (current.data.bans[userId]) throw problem('This Roblox account is banned from AetherV2 Premium keys', 403);
  try {
    return await originalBindKey(id, {username, userId});
  } catch (error) {
    if (error && error.status === 403 && /locked to another Roblox account/i.test(String(error.message || ''))) {
      try {
        const info = await registry.getKeyInfo(id);
        if (info && info.binding) await recordConflict({keyId: info.keyId, bound: info.binding, attempted: {username, userId}});
      } catch (recordError) {
        console.error('[AetherV2] could not persist key conflict:', recordError && recordError.message || recordError);
      }
    }
    throw error;
  }
};

const listConflicts = async ({status = 'open'} = {}) => {
  const current = await readStore();
  const wanted = String(status || 'open').toLowerCase();
  return Object.entries(current.data.conflicts)
    .map(([id, conflict]) => ({conflictId: id, ...conflict, banned: Boolean(current.data.bans[String(conflict.attemptedUserId)])}))
    .filter(item => wanted === 'all' || item.status === wanted)
    .sort((a, b) => Date.parse(b.lastSeenAt) - Date.parse(a.lastSeenAt));
};

const getConflict = async id => {
  const candidate = String(id || '').trim().toLowerCase();
  const current = await readStore();
  const matches = Object.keys(current.data.conflicts).filter(key => key === candidate || key.startsWith(candidate));
  if (!matches.length) throw problem('Conflict was not found', 404);
  if (matches.length > 1) throw problem('Conflict ID prefix is ambiguous', 409);
  const conflict = current.data.conflicts[matches[0]];
  return {conflictId: matches[0], ...conflict, banned: Boolean(current.data.bans[String(conflict.attemptedUserId)])};
};

const resolveConflict = async ({id, action, actor} = {}) => {
  const selected = await getConflict(id);
  const resolution = String(action || '').toLowerCase();
  if (!['ban_user', 'revoke_key', 'both', 'ignore'].includes(resolution)) throw problem('Unknown conflict action');

  if (resolution === 'revoke_key' || resolution === 'both') {
    try { await registry.revokeKey({id: selected.keyId, actor: cleanActor(actor)}); }
    catch (error) {
      if (!(error && error.status === 409 && /already revoked/i.test(String(error.message || '')))) throw error;
    }
  }

  return mutate('Resolve AetherV2 key conflict', async data => {
    const conflict = data.conflicts[selected.conflictId];
    if (!conflict) throw problem('Conflict was not found', 404);
    const timestamp = nowIso();
    if (resolution === 'ban_user' || resolution === 'both') {
      data.bans[String(conflict.attemptedUserId)] = {
        username: conflict.attemptedUsername,
        bannedAt: timestamp,
        bannedBy: cleanActor(actor),
        reason: 'Premium key conflict ' + selected.conflictId
      };
    }
    conflict.status = resolution === 'ignore' ? 'ignored' : 'resolved';
    conflict.resolution = resolution;
    conflict.resolvedAt = timestamp;
    conflict.resolvedBy = cleanActor(actor);
    return {result: {conflictId: selected.conflictId, conflict: {...conflict}, banned: Boolean(data.bans[String(conflict.attemptedUserId)])}};
  });
};

if (!registry.__aetherConflictWrapped) {
  registry.__aetherConflictWrapped = true;
  registry.bindKey = strictBindKey;
}

module.exports = {
  strictBindKey,
  recordConflict,
  listConflicts,
  getConflict,
  resolveConflict,
  isBanned,
  conflictId
};
