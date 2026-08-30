'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const registry = require('./key-registry');
const cloud = require('./cloud-configs');
require('./key-conflicts');

const boundedNumber = (value, fallback, min, max) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
};

const PORT = boundedNumber(process.env.PORT, 3000, 1, 65535);
const TOKEN = process.env.GITHUB_TOKEN || '';
const PREMIUM_REPOSITORY = process.env.PREMIUM_GITHUB_REPO || '';
const PREMIUM_BRANCH = process.env.PREMIUM_GITHUB_BRANCH || 'main';
let PUBLIC_ORIGIN = String(process.env.PUBLIC_ORIGIN || '');
while (PUBLIC_ORIGIN.endsWith('/')) PUBLIC_ORIGIN = PUBLIC_ORIGIN.slice(0, -1);
const SESSION_TTL = boundedNumber(process.env.AETHER_SESSION_MINUTES, 120, 5, 1440) * 60 * 1000;
const MAX_SESSIONS = boundedNumber(process.env.AETHER_MAX_SESSIONS, 2000, 10, 20000);
const MAX_SESSIONS_PER_KEY = boundedNumber(process.env.AETHER_MAX_SESSIONS_PER_KEY, 3, 1, 20);
const REQUEST_TIMEOUT_MS = boundedNumber(process.env.AETHER_REQUEST_TIMEOUT_MS, 8000, 1000, 30000);
const REQUEST_RETRIES = boundedNumber(process.env.AETHER_GITHUB_RETRIES, 3, 0, 6);
const RETRY_BASE_MS = boundedNumber(process.env.AETHER_RETRY_BASE_MS, 150, 0, 5000);
const RATE_WINDOW_MS = boundedNumber(process.env.AETHER_RATE_WINDOW_MS, 60000, 1000, 3600000);
const RATE_LIMIT = boundedNumber(process.env.AETHER_RATE_LIMIT, 180, 10, 10000);
const AUTH_RATE_LIMIT = boundedNumber(process.env.AETHER_AUTH_RATE_LIMIT, 20, 2, 1000);
const CLOUD_RATE_LIMIT = boundedNumber(process.env.AETHER_CLOUD_RATE_LIMIT, 120, 10, 10000);
const CLOUD_MAX_BODY = cloud.MAX_PAYLOAD_BYTES + (64 * 1024);
const TRUST_PROXY = process.env.AETHER_TRUST_PROXY === 'true';
const sessions = new Map();
const rateBuckets = new Map();
const cloudRootCache = new Map();

if (!TOKEN) throw new Error('GITHUB_TOKEN is required');
try {
  const origin = new URL(PUBLIC_ORIGIN);
  const local = ['localhost', '127.0.0.1', '::1'].includes(origin.hostname);
  if ((origin.protocol !== 'https:' && !local) || origin.username || origin.password || origin.search || origin.hash) throw new Error();
} catch {
  throw new Error('PUBLIC_ORIGIN must be a trusted HTTPS origin');
}

const syntacticRef = value => typeof value === 'string' && value.length > 0 && value.length <= 200 &&
  !value.includes('..') && !value.includes('\\') && !value.includes('?') && !value.includes('#') && !/\s/.test(value);
if (PREMIUM_REPOSITORY && !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(PREMIUM_REPOSITORY)) {
  throw new Error('PREMIUM_GITHUB_REPO must be owner/repository');
}
if (!syntacticRef(PREMIUM_BRANCH)) throw new Error('PREMIUM_GITHUB_BRANCH is invalid');

const defaultPremiumAllowedPaths = ['games/'];
const premiumAllowedPaths = (process.env.PREMIUM_ALLOWED_PATHS || defaultPremiumAllowedPaths.join(','))
  .split(',').map(value => value.trim()).filter(Boolean);
const validPath = value => typeof value === 'string' && value.length > 0 && value.length <= 300 &&
  !value.startsWith('/') && !value.includes('\\') && !value.includes('?') && !value.includes('#') &&
  value.split('/').every(segment => segment && segment !== '.' && segment !== '..');
const premiumPathMatches = value => premiumAllowedPaths.some(allowed =>
  allowed.endsWith('/') ? value.startsWith(allowed) : value === allowed
);
const premiumClientPath = value => validPath(value) && premiumPathMatches(value);
for (const allowed of premiumAllowedPaths) {
  const sample = allowed.endsWith('/') ? allowed.slice(0, -1) : allowed;
  if (!validPath(sample)) throw new Error('PREMIUM_ALLOWED_PATHS contains an invalid path');
}
const premiumEnabled = Boolean(PREMIUM_REPOSITORY && PREMIUM_BRANCH);

const headers = {
  authorization: 'Bearer ' + TOKEN,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-premium-source',
  'x-github-api-version': '2022-11-28'
};
const wait = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const problem = (message, status = 400, extra = {}) => Object.assign(new Error(message), {status, ...extra});
const retryStatus = status => status === 408 || status === 429 || status >= 500;

const json = (res, status, value, extraHeaders = {}) => {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'access-control-allow-headers': 'content-type',
    ...extraHeaders
  });
  res.end(JSON.stringify(value));
};
const text = (res, status, value, contentType = 'text/plain; charset=utf-8') => {
  res.writeHead(status, {'content-type': contentType, 'cache-control': 'no-store', 'access-control-allow-origin': '*'});
  res.end(value);
};

const readCloudBody = req => new Promise((resolve, reject) => {
  let size = 0;
  let settled = false;
  const chunks = [];
  req.on('data', chunk => {
    if (settled) return;
    const value = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += value.length;
    if (size > CLOUD_MAX_BODY) {
      settled = true;
      reject(problem('Request body is too large', 413));
      return;
    }
    chunks.push(value);
  });
  req.on('end', () => {
    if (settled) return;
    settled = true;
    try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); }
    catch { reject(problem('Invalid JSON body', 400)); }
  });
  req.on('error', error => {
    if (!settled) {
      settled = true;
      reject(error);
    }
  });
});

const requestIp = req => String(TRUST_PROXY && req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown')
  .split(',')[0].trim().slice(0, 100);
const consumeRateLimit = (req, pathname) => {
  const now = Date.now();
  if (rateBuckets.size > 10000) for (const [key, value] of rateBuckets) if (value.resetAt <= now) rateBuckets.delete(key);
  const authRoute = pathname === '/premium/authorize';
  const cloudRoute = pathname.startsWith('/cloud/');
  const limit = authRoute ? AUTH_RATE_LIMIT : cloudRoute ? CLOUD_RATE_LIMIT : RATE_LIMIT;
  const group = authRoute ? 'auth' : cloudRoute ? 'cloud' : 'premium-source';
  const key = requestIp(req) + ':' + group;
  let bucket = rateBuckets.get(key);
  if (!bucket || bucket.resetAt <= now) bucket = {count: 0, resetAt: now + RATE_WINDOW_MS};
  bucket.count += 1;
  rateBuckets.set(key, bucket);
  return bucket.count <= limit ? null : Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
};

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

const premiumGithub = async endpoint => {
  if (!premiumEnabled) throw problem('Premium modules are not configured yet', 503);
  const response = await fetchWithRetry('https://api.github.com/repos/' + PREMIUM_REPOSITORY + '/' + endpoint, {headers});
  if (!response.ok) throw problem(
    response.status === 404 ? 'Requested premium source was not found' : 'GitHub premium source request failed with HTTP ' + response.status,
    response.status === 404 ? 404 : 502
  );
  return response;
};

const createOrigin = () => PUBLIC_ORIGIN;
const premiumSessionLoader = (origin, session) => 'return {Endpoint=' + JSON.stringify(origin) +
  ',Token=' + JSON.stringify(session.token) + ',Ref=' + JSON.stringify(PREMIUM_BRANCH) + '}';

const cleanupSessions = () => {
  const now = Date.now();
  for (const [token, session] of sessions) if (session.expiresAt <= now) sessions.delete(token);
  while (sessions.size >= MAX_SESSIONS) sessions.delete(sessions.keys().next().value);
};
const invalidateSessionsForKey = keyId => {
  let removed = 0;
  for (const [token, session] of sessions) {
    if (session.keyId === keyId) {
      sessions.delete(token);
      removed += 1;
    }
  }
  return removed;
};
const createSession = binding => {
  cleanupSessions();
  const sameKey = [...sessions.entries()].filter(([, session]) => session.keyId === binding.id)
    .sort((left, right) => left[1].createdAt - right[1].createdAt);
  while (sameKey.length >= MAX_SESSIONS_PER_KEY) sessions.delete(sameKey.shift()[0]);
  const token = crypto.randomBytes(32).toString('hex');
  const createdAt = Date.now();
  const session = {
    token,
    createdAt,
    expiresAt: createdAt + SESSION_TTL,
    keyId: binding.id,
    username: binding.binding.username,
    userId: String(binding.binding.userId),
    keyRecord: binding.record || null
  };
  sessions.set(token, session);
  return session;
};

const sessionTokenFrom = value => typeof value === 'string' ? value : value.searchParams.get('session') || '';
const requireSession = async value => {
  const token = sessionTokenFrom(value);
  if (!/^[a-f0-9]{64}$/.test(token)) throw problem('A valid premium session is required', 401);
  const session = sessions.get(token);
  if (!session || session.expiresAt <= Date.now()) {
    sessions.delete(token);
    throw problem('The premium session is missing or expired; execute AetherV2 again', 401);
  }
  let info;
  try { info = await registry.getKeyInfo(session.keyId); }
  catch {
    sessions.delete(token);
    throw problem('The premium key is no longer active', 401);
  }
  const binding = info.binding;
  if (info.status !== 'active' || !binding || binding.username.toLowerCase() !== session.username.toLowerCase() || String(binding.userId) !== session.userId) {
    sessions.delete(token);
    throw problem('The premium key was revoked, expired, rotated, or unlinked', 401);
  }
  session.keyRecord = info.record || null;
  return session;
};

// Cloud ownership follows the root of a rotated key lineage plus the Roblox account.
// Rotation therefore keeps the same cloud data, while unlinking/rebinding the lineage to
// another Roblox UserId produces a different owner ID and cannot expose the previous data.
const cloudOwnerSession = async session => {
  let rootId = cloudRootCache.get(session.keyId);
  if (!rootId) {
    let currentId = session.keyId;
    let record = session.keyRecord;
    const seen = new Set([currentId]);
    for (let depth = 0; depth < 32; depth += 1) {
      const previous = record && record.rotatedFrom;
      if (!previous) {
        rootId = currentId;
        break;
      }
      if (seen.has(previous)) throw problem('Premium key rotation chain is invalid', 502);
      seen.add(previous);
      const info = await registry.getKeyInfo(previous);
      currentId = info.keyId;
      record = info.record;
    }
    if (!rootId) throw problem('Premium key rotation chain is too deep', 502);
    cloudRootCache.set(session.keyId, rootId);
  }
  return {
    ...session,
    keyId: crypto.createHash('sha256').update(String(rootId) + '\0' + String(session.userId)).digest('hex')
  };
};

const verifyRobloxIdentity = async person => {
  const response = await fetchWithRetry('https://users.roblox.com/v1/users/' + encodeURIComponent(person.userId));
  if (response.status === 404) return false;
  if (!response.ok) throw problem('Roblox identity verification is temporarily unavailable', 502);
  const value = await response.json();
  return value && typeof value.name === 'string' && value.name.toLowerCase() === String(person.username).toLowerCase();
};

const premiumSourceFile = async file => {
  if (!premiumClientPath(file) || !file.endsWith('.lua')) throw problem('This premium path is not available', 403);
  const response = await premiumGithub('contents/' + file.split('/').map(encodeURIComponent).join('/') + '?ref=' + encodeURIComponent(PREMIUM_BRANCH));
  const body = await response.json();
  if (!body || typeof body.content !== 'string' || body.encoding !== 'base64') throw problem('GitHub returned invalid premium source', 502);
  return Buffer.from(body.content.replace(/\s/g, ''), 'base64').toString('utf8');
};
const premiumTree = async () => {
  const response = await premiumGithub('git/trees/' + encodeURIComponent(PREMIUM_BRANCH) + '?recursive=1');
  const body = await response.json();
  if (!body || !Array.isArray(body.tree) || body.truncated) throw problem('GitHub returned an incomplete premium tree', 502);
  const tree = body.tree.filter(entry => entry && entry.type === 'blob' && premiumClientPath(entry.path) && entry.path.endsWith('.lua'))
    .map(entry => ({path: entry.path, mode: entry.mode, type: entry.type, sha: entry.sha, size: entry.size}));
  return JSON.stringify({sha: body.sha, truncated: false, tree});
};

const routeCloud = async (req, res, url) => {
  const shareMatch = url.pathname.match(/^\/cloud\/share\/([^/]+)$/);
  if (req.method === 'GET' && shareMatch) {
    const config = await cloud.resolveShare(decodeURIComponent(shareMatch[1]));
    return json(res, 200, {success: true, config});
  }

  if (req.method === 'POST' && url.pathname === '/cloud/import') {
    const session = await cloudOwnerSession(await requireSession(url));
    const config = await cloud.importShare(session, await readCloudBody(req));
    return json(res, 201, {success: true, config});
  }

  if (url.pathname === '/cloud/configs') {
    const session = await cloudOwnerSession(await requireSession(url));
    if (req.method === 'GET') {
      const configs = await cloud.list(session, url.searchParams.get('placeId'));
      return json(res, 200, {success: true, limit: cloud.MAX_CONFIGS_PER_KEY, configs});
    }
    if (req.method === 'POST') {
      const config = await cloud.create(session, await readCloudBody(req));
      return json(res, 201, {success: true, limit: cloud.MAX_CONFIGS_PER_KEY, config});
    }
  }

  const configMatch = url.pathname.match(/^\/cloud\/configs\/([a-f0-9-]{16,64})$/i);
  if (configMatch) {
    const session = await cloudOwnerSession(await requireSession(url));
    const id = configMatch[1];
    if (req.method === 'GET') {
      return json(res, 200, {success: true, config: await cloud.get(session, id)});
    }
    if (req.method === 'PUT') {
      return json(res, 200, {success: true, config: await cloud.save(session, id, await readCloudBody(req))});
    }
    if (req.method === 'DELETE') {
      await cloud.remove(session, id);
      return json(res, 200, {success: true, id});
    }
    if (req.method === 'PATCH') {
      const input = await readCloudBody(req);
      let config;
      if (input.action === 'rename') config = await cloud.rename(session, id, input.name);
      else if (input.action === 'sharing') config = await cloud.sharing(session, id, input.mode);
      else if (input.action === 'sync') config = await cloud.setSync(session, id, input.enabled);
      else if (input.action === 'restore-backup') config = await cloud.restoreBackup(session, id);
      else throw problem('Unknown cloud config action', 400);
      return json(res, 200, {success: true, config});
    }
  }

  return json(res, 404, {success: false, error: 'Cloud config endpoint not found'});
};

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return res.writeHead(204, {
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
      'access-control-allow-headers': 'content-type'
    }).end();
    const url = new URL(req.url, 'http://localhost');
    const retryAfter = consumeRateLimit(req, url.pathname);
    if (retryAfter) return json(res, 429, {success: false, error: 'Too many requests; try again shortly'}, {'retry-after': String(retryAfter)});

    if (url.pathname.startsWith('/cloud/')) return await routeCloud(req, res, url);

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, {
        success: true,
        service: 'aetherv2-premium-source',
        normalSource: 'public-github',
        premiumEnabled,
        cloudConfigs: true,
        cloudConfigLimit: cloud.MAX_CONFIGS_PER_KEY,
        discordBot: Boolean(process.env.DISCORD_TOKEN)
      });
    }

    if (req.method === 'GET' && url.pathname === '/premium/authorize') {
      if (!premiumEnabled) return json(res, 503, {success: false, error: 'Premium modules are not configured yet'});
      const key = url.searchParams.get('key') || '';
      const keyInfo = await registry.resolveKey(key);
      const person = {username: url.searchParams.get('username'), userId: url.searchParams.get('userId')};
      if (!keyInfo) return json(res, 401, {success: false, error: 'This premium key is invalid, revoked, or expired'});
      if (!/^[A-Za-z0-9_]{3,20}$/.test(String(person.username || '')) || !/^\d{1,20}$/.test(String(person.userId || ''))) {
        return json(res, 400, {success: false, error: 'The Roblox username or UserId is invalid'});
      }
      if (!await verifyRobloxIdentity(person)) return json(res, 403, {success: false, error: 'The Roblox username does not match that UserId'});
      const binding = await registry.bindKey(keyInfo.keyId, person);
      console.log('[AetherV2] premium key ID ' + binding.id.slice(0, 12) + ' authorized for ' + person.username + ' (' + person.userId + ')');
      return text(res, 200, premiumSessionLoader(createOrigin(), createSession(binding)));
    }

    if (req.method === 'GET' && url.pathname === '/premium/source') {
      await requireSession(url);
      const file = url.searchParams.get('path');
      return text(res, 200, await premiumSourceFile(file));
    }

    if (req.method === 'GET' && url.pathname === '/premium/tree') {
      await requireSession(url);
      return text(res, 200, await premiumTree(), 'application/json; charset=utf-8');
    }

    return json(res, 404, {success: false, error: 'Endpoint not found'});
  } catch (error) {
    return json(res, error.status || 500, {success: false, error: error.message || 'Premium source request failed'});
  }
});

if (require.main === module) {
  server.listen(PORT, () => console.log('AetherV2 premium-source service listening on ' + PORT));
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
  premiumClientPath,
  verifyRobloxIdentity,
  premiumSessionLoader,
  createSession,
  requireSession,
  cloudOwnerSession,
  routeCloud,
  readCloudBody,
  invalidateSessionsForKey,
  sessions,
  premiumSourceFile,
  premiumTree
};
