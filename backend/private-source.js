'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const registry = require('./key-registry');

const boundedNumber = (value, fallback, min, max) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
};

const PORT = boundedNumber(process.env.PORT, 3000, 1, 65535);
const REPOSITORY = process.env.GITHUB_REPO || '';
const BRANCH = process.env.GITHUB_BRANCH || '';
const TOKEN = process.env.GITHUB_TOKEN || '';
const PUBLIC_ORIGIN = String(process.env.PUBLIC_ORIGIN || '').replace(/\/+$/, '');
const SESSION_TTL = boundedNumber(process.env.AETHER_SESSION_MINUTES, 120, 5, 1440) * 60 * 1000;
const MAX_SESSIONS = boundedNumber(process.env.AETHER_MAX_SESSIONS, 2000, 10, 20000);
const MAX_SESSIONS_PER_KEY = boundedNumber(process.env.AETHER_MAX_SESSIONS_PER_KEY, 3, 1, 20);
const REQUEST_TIMEOUT_MS = boundedNumber(process.env.AETHER_REQUEST_TIMEOUT_MS, 8000, 1000, 30000);
const REQUEST_RETRIES = boundedNumber(process.env.AETHER_GITHUB_RETRIES, 3, 0, 6);
const RETRY_BASE_MS = boundedNumber(process.env.AETHER_RETRY_BASE_MS, 150, 0, 5000);
const RATE_WINDOW_MS = boundedNumber(process.env.AETHER_RATE_WINDOW_MS, 60000, 1000, 3600000);
const RATE_LIMIT = boundedNumber(process.env.AETHER_RATE_LIMIT, 180, 10, 10000);
const AUTH_RATE_LIMIT = boundedNumber(process.env.AETHER_AUTH_RATE_LIMIT, 20, 2, 1000);
const TRUST_PROXY = process.env.AETHER_TRUST_PROXY === 'true';
const sessions = new Map();
const rateBuckets = new Map();

if (!TOKEN || !REPOSITORY || !BRANCH) throw new Error('GITHUB_TOKEN, GITHUB_REPO, and GITHUB_BRANCH are required');
try {
  const origin = new URL(PUBLIC_ORIGIN);
  const local = ['localhost', '127.0.0.1', '::1'].includes(origin.hostname);
  if ((origin.protocol !== 'https:' && !local) || origin.username || origin.password || origin.search || origin.hash) throw new Error();
} catch {
  throw new Error('PUBLIC_ORIGIN must be a trusted HTTPS origin');
}

const syntacticRef = value => typeof value === 'string' && value.length > 0 && value.length <= 200 &&
  !value.includes('..') && !value.includes('\\') && !value.includes('?') && !value.includes('#') && !/\s/.test(value);
const allowedRefs = new Set((process.env.AETHER_ALLOWED_REFS || BRANCH).split(',').map(value => value.trim()).filter(Boolean));
allowedRefs.add(BRANCH);
for (const ref of allowedRefs) {
  if (!syntacticRef(ref)) throw new Error('AETHER_ALLOWED_REFS contains an invalid ref');
}

const defaultAllowedPaths = [
  'init.lua', 'main.lua', 'reinstall.luau', 'loadstring', 'version.txt', 'cv', 'gui',
  'assets/', 'configs/', 'games/', 'guis/', 'libraries/', 'profiles/'
];
const allowedPaths = (process.env.AETHER_ALLOWED_PATHS || defaultAllowedPaths.join(','))
  .split(',').map(value => value.trim()).filter(Boolean);

const headers = {
  authorization: 'Bearer ' + TOKEN,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-private-source-proxy',
  'x-github-api-version': '2022-11-28'
};

const wait = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const problem = (message, status = 400, extra = {}) => Object.assign(new Error(message), {status, ...extra});
const validRef = value => syntacticRef(value) && allowedRefs.has(value);
const validPath = value => typeof value === 'string' && value.length > 0 && value.length <= 300 &&
  !value.startsWith('/') && !value.includes('\\') && !value.includes('?') && !value.includes('#') &&
  value.split('/').every(segment => segment && segment !== '.' && segment !== '..');
const pathMatches = (value, includeAncestors = false) => allowedPaths.some(allowed =>
  allowed.endsWith('/')
    ? value.startsWith(allowed) || includeAncestors && allowed.startsWith(value + '/')
    : value === allowed
);
const clientPath = value => validPath(value) && pathMatches(value, false);
const treePath = value => validPath(value) && pathMatches(value, true);

for (const allowed of allowedPaths) {
  const sample = allowed.endsWith('/') ? allowed.slice(0, -1) : allowed;
  if (!validPath(sample)) throw new Error('AETHER_ALLOWED_PATHS contains an invalid path');
}

const json = (res, status, value, extraHeaders = {}) => {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,OPTIONS',
    'access-control-allow-headers': 'content-type',
    ...extraHeaders
  });
  res.end(JSON.stringify(value));
};

const text = (res, status, value, contentType = 'text/plain; charset=utf-8') => {
  res.writeHead(status, {
    'content-type': contentType,
    'cache-control': 'no-store',
    'access-control-allow-origin': '*'
  });
  res.end(value);
};

const requestIp = req => String(
  TRUST_PROXY && req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown'
).split(',')[0].trim().slice(0, 100);
const consumeRateLimit = (req, pathname) => {
  const now = Date.now();
  if (rateBuckets.size > 10000) {
    for (const [key, value] of rateBuckets) if (value.resetAt <= now) rateBuckets.delete(key);
  }
  const authRoute = pathname === '/loader' || pathname === '/authorize';
  const limit = authRoute ? AUTH_RATE_LIMIT : RATE_LIMIT;
  const key = requestIp(req) + ':' + (authRoute ? 'auth' : 'source');
  let bucket = rateBuckets.get(key);
  if (!bucket || bucket.resetAt <= now) bucket = {count: 0, resetAt: now + RATE_WINDOW_MS};
  bucket.count += 1;
  rateBuckets.set(key, bucket);
  return bucket.count <= limit ? null : Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
};

const retryStatus = status => status === 408 || status === 429 || status >= 500;
const fetchWithRetry = async (url, options = {}, retries = REQUEST_RETRIES) => {
  let lastError;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const response = await fetch(url, {...options, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS)});
      if (!retryStatus(response.status) || attempt === retries) return response;
      lastError = problem('Upstream request failed with HTTP ' + response.status, 502);
    } catch (error) {
      lastError = problem('Upstream request timed out or failed', 502, {cause: error});
      if (attempt === retries) throw lastError;
    }
    await wait(RETRY_BASE_MS * (2 ** attempt));
  }
  throw lastError || problem('Upstream request failed', 502);
};

const githubUrl = endpoint => 'https://api.github.com/repos/' + REPOSITORY + '/' + endpoint;
const githubRequest = endpoint => fetchWithRetry(githubUrl(endpoint), {headers});
const github = async endpoint => {
  const response = await githubRequest(endpoint);
  if (!response.ok) throw problem(
    response.status === 404 ? 'Requested source was not found' : 'GitHub source request failed with HTTP ' + response.status,
    response.status === 404 ? 404 : 502
  );
  return response;
};

const createOrigin = () => PUBLIC_ORIGIN;
const firstStageLoader = (origin, key) => [
  'local endpoint = ' + JSON.stringify(origin),
  'local key = ' + JSON.stringify(key),
  'local players = game:GetService("Players")',
  'repeat task.wait() until players.LocalPlayer',
  'local player = players.LocalPlayer',
  'local function encode(value)',
  '  return tostring(value):gsub("([^%w%-%._~])", function(character)',
  '    return string.format("%%%02X", string.byte(character))',
  '  end)',
  'end',
  'local url = endpoint.."/authorize?key="..encode(key).."&username="..encode(player.Name).."&userId="..tostring(player.UserId)',
  'local stage = game:HttpGet(url, true)',
  'loadstring(stage, "aether-authorize")()'
].join('\n');

const sessionLoader = (origin, session) => [
  'local endpoint = ' + JSON.stringify(origin),
  'local session = ' + JSON.stringify(session),
  'loadstring(game:HttpGet(endpoint.."/source?path=init.lua&ref=' + encodeURIComponent(BRANCH) + '&session="..session, true), "init.lua")({',
  '    Closet = false,',
  '    SourceEndpoint = endpoint,',
  '    SourceToken = session,',
  '    SourceRef = ' + JSON.stringify(BRANCH),
  '})'
].join('\n');

const encodePath = file => file.split('/').map(encodeURIComponent).join('/');
// GitHub's Contents API stops returning usable base64 content for files larger than 1 MiB.
// BedWars' match module is currently just over that limit, so fall back to the Git blob endpoint,
// which supports the full file size. The contents response includes the blob SHA we need.
const decodeBase64 = value => Buffer.from(value.replace(/\s/g, ''), 'base64').toString('utf8');
const sourceFile = async (file, ref) => {
  const response = await github('contents/' + encodePath(file) + '?ref=' + encodeURIComponent(ref));
  const value = await response.json();
  if (!value || value.type !== 'file') throw problem('GitHub returned an invalid source file', 502);

  const hasContents = value.encoding === 'base64' && typeof value.content === 'string' &&
    !(value.size > 0 && value.content.trim() === '');
  if (hasContents) return decodeBase64(value.content);

  if (typeof value.sha !== 'string' || !/^[a-f0-9]{40}$/i.test(value.sha)) {
    throw problem('GitHub returned an unusable large source file', 502);
  }
  const blob = await (await github('git/blobs/' + encodeURIComponent(value.sha))).json();
  if (!blob || blob.encoding !== 'base64' || typeof blob.content !== 'string') {
    throw problem('GitHub returned an unusable source blob', 502);
  }
  return decodeBase64(blob.content);
};

const commitSha = async ref => {
  const value = await (await github('commits/' + encodeURIComponent(ref))).json();
  if (!value || typeof value.sha !== 'string' || !/^[a-f0-9]{40,64}$/i.test(value.sha)) throw problem('GitHub returned an invalid commit', 502);
  return value.sha;
};

const tree = async ref => {
  const value = await (await github('git/trees/' + encodeURIComponent(ref) + '?recursive=1')).json();
  if (!value || !Array.isArray(value.tree) || value.truncated) throw problem('GitHub returned an incomplete source tree', 502);
  value.tree = value.tree.filter(entry => entry && typeof entry.path === 'string' && treePath(entry.path));
  return JSON.stringify(value);
};

const validKey = value => registry.isValidKey(value);

const pruneSessions = () => {
  const now = Date.now();
  for (const [session, value] of sessions) if (value.expiresAt <= now) sessions.delete(session);
};

const invalidateSessionsForKey = id => {
  let removed = 0;
  for (const [session, value] of sessions) {
    if (value.keyId === id) {
      sessions.delete(session);
      removed += 1;
    }
  }
  return removed;
};

const createSession = binding => {
  pruneSessions();
  if (!binding || !registry.validKeyId(binding.id) || !binding.binding) throw problem('Cannot create a session for an invalid binding', 500);
  const sameKey = Array.from(sessions.entries())
    .filter(([, value]) => value.keyId === binding.id)
    .sort((left, right) => left[1].createdAt - right[1].createdAt);
  while (sameKey.length >= MAX_SESSIONS_PER_KEY) sessions.delete(sameKey.shift()[0]);
  if (sessions.size >= MAX_SESSIONS) throw problem('The source session limit has been reached; try again shortly', 503);
  const session = crypto.randomBytes(32).toString('hex');
  const createdAt = Date.now();
  sessions.set(session, {
    createdAt,
    expiresAt: createdAt + SESSION_TTL,
    keyId: binding.id,
    approvedRefs: new Set(),
    username: binding.binding.username,
    userId: String(binding.binding.userId)
  });
  return session;
};

const requireSession = async url => {
  const session = typeof url === 'string' ? url : url.searchParams.get('session') || '';
  if (!/^[a-f0-9]{64}$/.test(session)) throw problem('A valid loader session is required', 401);
  const value = sessions.get(session);
  if (!value || value.expiresAt <= Date.now()) {
    sessions.delete(session);
    throw problem('The loader session is missing or expired; run your private loader again', 401);
  }
  let active;
  try {
    active = await registry.isKeyIdActive(value.keyId);
  } catch (error) {
    throw problem('Key status could not be verified; access is temporarily unavailable', 502, {cause: error});
  }
  if (!active) {
    invalidateSessionsForKey(value.keyId);
    throw problem('This key was revoked or expired; run a renewed loader', 401);
  }
  return value;
};

// Named refs are approved by configuration. Immutable commit SHAs become available
// only after this same session resolves one through /commit, preventing callers from
// using the proxy as an arbitrary private-repository file reader.
const sessionAllowsRef = (session, ref) => validRef(ref) || Boolean(
  session && syntacticRef(ref) && /^[a-f0-9]{40,64}$/i.test(ref) && session.approvedRefs.has(ref)
);

const verifyRobloxIdentity = async person => {
  const response = await fetchWithRetry('https://users.roblox.com/v1/users/' + encodeURIComponent(person.userId));
  if (response.status === 404) return false;
  if (!response.ok) throw problem('Roblox identity verification is temporarily unavailable', 502);
  const value = await response.json();
  return value && typeof value.name === 'string' && value.name.toLowerCase() === String(person.username).toLowerCase();
};

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return res.writeHead(204).end();
    const url = new URL(req.url, 'http://localhost');
    const retryAfter = consumeRateLimit(req, url.pathname);
    if (retryAfter) return json(res, 429, {success: false, error: 'Too many requests; try again shortly'}, {'retry-after': String(retryAfter)});

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, {success: true, service: 'aetherv2-private-source', keyGating: true, discordBot: Boolean(process.env.DISCORD_TOKEN)});
    }

    if (req.method === 'GET' && url.pathname === '/loader') {
      const key = url.searchParams.get('key') || '';
      if (!await validKey(key)) return json(res, 401, {success: false, error: 'This AetherV2 key is invalid, revoked, or expired'});
      return text(res, 200, firstStageLoader(createOrigin(), key));
    }

    if (req.method === 'GET' && url.pathname === '/authorize') {
      const key = url.searchParams.get('key') || '';
      const keyInfo = await registry.resolveKey(key);
      const person = {username: url.searchParams.get('username'), userId: url.searchParams.get('userId')};
      if (!keyInfo) return json(res, 401, {success: false, error: 'This AetherV2 key is invalid, revoked, or expired'});
      if (!/^[A-Za-z0-9_]{3,20}$/.test(String(person.username || '')) || !/^\d{1,20}$/.test(String(person.userId || ''))) {
        return json(res, 400, {success: false, error: 'The Roblox username or UserId is invalid'});
      }
      if (!await verifyRobloxIdentity(person)) return json(res, 403, {success: false, error: 'The Roblox username does not match that UserId'});
      const binding = await registry.bindKey(keyInfo.keyId, person);
      console.log('[AetherV2] key ID ' + binding.id.slice(0, 12) + ' authorized for ' + person.username + ' (' + person.userId + ')');
      return text(res, 200, sessionLoader(createOrigin(), createSession(binding)));
    }

    const ref = url.searchParams.get('ref') || BRANCH;

    if (req.method === 'GET' && url.pathname === '/source') {
      const session = await requireSession(url);
      if (!sessionAllowsRef(session, ref)) return json(res, 403, {success: false, error: 'This source ref is not approved for this session'});
      const file = url.searchParams.get('path');
      if (!clientPath(file)) return json(res, 403, {success: false, error: 'This path is not available through the client proxy'});
      return text(res, 200, await sourceFile(file, ref));
    }

    if (req.method === 'GET' && url.pathname === '/commit') {
      const session = await requireSession(url);
      if (!validRef(ref)) return json(res, 403, {success: false, error: 'This source ref is not approved'});
      const commit = await commitSha(ref);
      session.approvedRefs.add(commit);
      return text(res, 200, commit);
    }

    if (req.method === 'GET' && url.pathname === '/tree') {
      const session = await requireSession(url);
      if (!sessionAllowsRef(session, ref)) return json(res, 403, {success: false, error: 'This source ref is not approved for this session'});
      return text(res, 200, await tree(ref), 'application/json; charset=utf-8');
    }

    return json(res, 404, {success: false, error: 'Endpoint not found'});
  } catch (error) {
    return json(res, error.status || 500, {success: false, error: error.message || 'Private source request failed'});
  }
});

if (require.main === module) {
  server.listen(PORT, () => console.log('AetherV2 private-source proxy listening on ' + PORT));
  if (process.env.DISCORD_TOKEN) {
    try {
      const bot = require('./discord-bot');
      bot.startDiscordBot().catch(error => console.error('[AetherV2] Discord bot failed:', error.message || error));
    } catch (error) {
      console.error('[AetherV2] Discord bot could not start:', error.message || error);
    }
  }
}

module.exports = {
  server,
  validPath,
  validRef,
  validKey,
  clientPath,
  treePath,
  verifyRobloxIdentity,
  sessionLoader,
  createSession,
  requireSession,
  sessionAllowsRef,
  invalidateSessionsForKey,
  sessions,
  sourceFile,
  commitSha,
  tree
};
