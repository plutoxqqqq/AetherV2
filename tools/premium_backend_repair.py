from pathlib import Path
import re

private_source = r'''\'use strict\';

const http = require('node:http');
const crypto = require('node:crypto');
const registry = require('./key-registry');

const boundedNumber = (value, fallback, min, max) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
};

const PORT = boundedNumber(process.env.PORT, 3000, 1, 65535);
const TOKEN = process.env.GITHUB_TOKEN || '';
const PREMIUM_REPOSITORY = process.env.PREMIUM_GITHUB_REPO || '';
const PREMIUM_BRANCH = process.env.PREMIUM_GITHUB_BRANCH || 'main';
const PUBLIC_ORIGIN = String(process.env.PUBLIC_ORIGIN || '').replace(/\\/+$/, '');
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

if (!TOKEN) throw new Error('GITHUB_TOKEN is required');
try {
  const origin = new URL(PUBLIC_ORIGIN);
  const local = ['localhost', '127.0.0.1', '::1'].includes(origin.hostname);
  if ((origin.protocol !== 'https:' && !local) || origin.username || origin.password || origin.search || origin.hash) throw new Error();
} catch {
  throw new Error('PUBLIC_ORIGIN must be a trusted HTTPS origin');
}

const syntacticRef = value => typeof value === 'string' && value.length > 0 && value.length <= 200 &&
  !value.includes('..') && !value.includes('\\\\') && !value.includes('?') && !value.includes('#') && !/\\s/.test(value);
if (PREMIUM_REPOSITORY && !/^[A-Za-z0-9_.-]+\\/[A-Za-z0-9_.-]+$/.test(PREMIUM_REPOSITORY)) {
  throw new Error('PREMIUM_GITHUB_REPO must be owner/repository');
}
if (!syntacticRef(PREMIUM_BRANCH)) throw new Error('PREMIUM_GITHUB_BRANCH is invalid');

const defaultPremiumAllowedPaths = ['games/'];
const premiumAllowedPaths = (process.env.PREMIUM_ALLOWED_PATHS || defaultPremiumAllowedPaths.join(','))
  .split(',').map(value => value.trim()).filter(Boolean);
const validPath = value => typeof value === 'string' && value.length > 0 && value.length <= 300 &&
  !value.startsWith('/') && !value.includes('\\\\') && !value.includes('?') && !value.includes('#') &&
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
    'access-control-allow-methods': 'GET,OPTIONS',
    'access-control-allow-headers': 'content-type',
    ...extraHeaders
  });
  res.end(JSON.stringify(value));
};
const text = (res, status, value, contentType = 'text/plain; charset=utf-8') => {
  res.writeHead(status, {'content-type': contentType, 'cache-control': 'no-store', 'access-control-allow-origin': '*'});
  res.end(value);
};

const requestIp = req => String(TRUST_PROXY && req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown')
  .split(',')[0].trim().slice(0, 100);
const consumeRateLimit = (req, pathname) => {
  const now = Date.now();
  if (rateBuckets.size > 10000) for (const [key, value] of rateBuckets) if (value.resetAt <= now) rateBuckets.delete(key);
  const authRoute = pathname === '/premium/authorize';
  const limit = authRoute ? AUTH_RATE_LIMIT : RATE_LIMIT;
  const key = requestIp(req) + ':' + (authRoute ? 'auth' : 'premium-source');
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
    userId: String(binding.binding.userId)
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
  try {
    info = await registry.getKeyInfo(session.keyId);
  } catch {
    sessions.delete(token);
    throw problem('The premium key is no longer active', 401);
  }
  const binding = info.binding;
  if (info.status !== 'active' || !binding || binding.username.toLowerCase() !== session.username.toLowerCase() || String(binding.userId) !== session.userId) {
    sessions.delete(token);
    throw problem('The premium key was revoked, expired, rotated, or unlinked', 401);
  }
  return session;
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
  return Buffer.from(body.content.replace(/\\s/g, ''), 'base64').toString('utf8');
};
const premiumTree = async () => {
  const response = await premiumGithub('git/trees/' + encodeURIComponent(PREMIUM_BRANCH) + '?recursive=1');
  const body = await response.json();
  if (!body || !Array.isArray(body.tree) || body.truncated) throw problem('GitHub returned an incomplete premium tree', 502);
  const tree = body.tree.filter(entry => entry && entry.type === 'blob' && premiumClientPath(entry.path) && entry.path.endsWith('.lua'))
    .map(entry => ({path: entry.path, mode: entry.mode, type: entry.type, sha: entry.sha, size: entry.size}));
  return JSON.stringify({sha: body.sha, truncated: false, tree});
};

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return res.writeHead(204).end();
    const url = new URL(req.url, 'http://localhost');
    const retryAfter = consumeRateLimit(req, url.pathname);
    if (retryAfter) return json(res, 429, {success: false, error: 'Too many requests; try again shortly'}, {'retry-after': String(retryAfter)});

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, {success: true, service: 'aetherv2-premium-source', normalSource: 'public-github', premiumEnabled, discordBot: Boolean(process.env.DISCORD_TOKEN)});
    }

    if (req.method === 'GET' && url.pathname === '/premium/authorize') {
      if (!premiumEnabled) return json(res, 503, {success: false, error: 'Premium modules are not configured yet'});
      const key = url.searchParams.get('key') || '';
      const keyInfo = await registry.resolveKey(key);
      const person = {username: url.searchParams.get('username'), userId: url.searchParams.get('userId')};
      if (!keyInfo) return json(res, 401, {success: false, error: 'This premium key is invalid, revoked, or expired'});
      if (!/^[A-Za-z0-9_]{3,20}$/.test(String(person.username || '')) || !/^\\d{1,20}$/.test(String(person.userId || ''))) {
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
  invalidateSessionsForKey,
  sessions,
  premiumSourceFile,
  premiumTree
};
'''
Path('backend/private-source.js').write_text(private_source)

# Premium-only service tests: old normal-source routes must not return, and every premium session
# must be checked against live key state/binding on each request.
private_test = r'''\'use strict\';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.GITHUB_TOKEN = 'test-token';
process.env.GITHUB_REPO = 'plutoxqqqq/AetherV2';
process.env.AETHER_REGISTRY_BRANCH = 'aether-key-registry';
process.env.PUBLIC_ORIGIN = 'https://aether.example';
process.env.PREMIUM_GITHUB_REPO = 'plutoxqqqq/AetherV2Premium';
process.env.PREMIUM_GITHUB_BRANCH = 'main';
process.env.PREMIUM_ALLOWED_PATHS = 'games/';
process.env.AETHER_KEY_LOCAL_FALLBACK = 'true';
process.env.AETHER_KEY_LOCAL_WRITE = 'true';
process.env.KEY_REGISTRY_FILE = path.join(__dirname, 'tmp-premium-source.json');
process.env.KEY_BINDINGS_FILE = path.join(__dirname, 'tmp-premium-bindings.json');
try { fs.unlinkSync(process.env.KEY_REGISTRY_FILE); } catch {}
try { fs.unlinkSync(process.env.KEY_BINDINGS_FILE); } catch {}

const registry = require('./key-registry');
const service = require('./private-source');

test.after(() => {
  try { fs.unlinkSync(process.env.KEY_REGISTRY_FILE); } catch {}
  try { fs.unlinkSync(process.env.KEY_BINDINGS_FILE); } catch {}
});

test('premium path validation accepts only configured game paths', () => {
  assert.equal(service.premiumClientPath('games/universal/render/example.lua'), true);
  assert.equal(service.premiumClientPath('games/6872274481/blatant/example.lua'), true);
  assert.equal(service.premiumClientPath('README.md'), false);
  assert.equal(service.premiumClientPath('../games/a.lua'), false);
});

test('premium loader only exposes session metadata', () => {
  const loader = service.premiumSessionLoader('https://aether.example', {token: 'a'.repeat(64)});
  assert.match(loader, /Endpoint=/);
  assert.match(loader, /Token=/);
  assert.match(loader, /Ref=/);
  assert.doesNotMatch(loader, /SourceEndpoint|\/source\?/);
});

test('premium sessions are revalidated against live key state and binding', async () => {
  const original = registry.getKeyInfo;
  const id = 'b'.repeat(64);
  const session = service.createSession({id, binding: {username: 'ExampleUser', userId: '12345'}});
  registry.getKeyInfo = async () => ({status: 'active', binding: {username: 'ExampleUser', userId: '12345'}});
  try {
    assert.equal((await service.requireSession(session.token)).keyId, id);
    registry.getKeyInfo = async () => ({status: 'disabled', binding: {username: 'ExampleUser', userId: '12345'}});
    await assert.rejects(() => service.requireSession(session.token), /revoked, expired, rotated, or unlinked/i);
    assert.equal(service.sessions.has(session.token), false);
  } finally {
    registry.getKeyInfo = original;
  }
});

test('unlinked or transferred bindings invalidate an existing premium session', async () => {
  const original = registry.getKeyInfo;
  const id = 'c'.repeat(64);
  const session = service.createSession({id, binding: {username: 'OriginalUser', userId: '777'}});
  registry.getKeyInfo = async () => ({status: 'active', binding: {username: 'DifferentUser', userId: '888'}});
  try {
    await assert.rejects(() => service.requireSession(session.token), /revoked, expired, rotated, or unlinked/i);
  } finally {
    registry.getKeyInfo = original;
  }
});
'''
Path('backend/private-source.test.js').write_text(private_test)

# Discord bot: keys are optional premium keys. The generated loader is the public GitHub init.lua
# loadstring, not the retired Render /loader route. Copyable values get both fenced and inline code.
bot_path = Path('backend/discord-bot.js')
bot = bot_path.read_text()
bot = bot.replace("const SOURCE_ORIGIN = String(process.env.PUBLIC_ORIGIN || '').replace(/\\/+$/, '');\n", '', 1)
bot = bot.replace(".setDescription('Manage AetherV2 access keys')", ".setDescription('Manage AetherV2 Premium keys')", 1)
bot = bot.replace(".setDescription('Open the private key dashboard')", ".setDescription('Open the private premium-key dashboard')", 1)
bot = bot.replace(".setDescription('Generate a new unbound key')", ".setDescription('Generate a new unbound premium key')", 1)
bot = bot.replace("const codeBlock = (value, language = 'text') => '```' + language + '\\n' + String(value ?? '').replace(/```/g, 'ˋˋˋ') + '\\n```';", "const codeBlock = (value, language = 'text') => '```' + language + '\\n' + String(value ?? '').replace(/```/g, 'ˋˋˋ') + '\\n```';\nconst copyable = (value, language = 'text') => codeBlock(value, language) + '\\n' + inline(value);", 1)
bot = bot.replace(".setTitle('🔐 AetherV2 Key Manager')", ".setTitle('🔐 AetherV2 Premium Key Manager')", 1)
bot = bot.replace(".setDescription('Owner-only access control. Raw keys are never stored and can only be shown once.')", ".setDescription('Owner-only premium access. Normal AetherV2 is public and does not require a key. Raw premium keys are never stored and can only be shown once.')", 1)
bot = bot.replace(".setTitle('🔑 AetherV2 Keys')", ".setTitle('🔑 AetherV2 Premium Keys')", 1)

old_fields = """      {name: 'Key ID', value: codeBlock(info.keyId), inline: false},
      {name: 'Label', value: inline(info.label || 'Unlabelled'), inline: true},
      {name: 'Status', value: inline(statusText(info.status)), inline: true},
      {name: 'Source', value: inline(info.source), inline: true},
      {name: 'Roblox account', value: inline(bindingText(info.binding)), inline: false},
      {name: 'Uses', value: inline(info.uses), inline: true},
      {name: 'Created', value: inline(dateText(info.createdAt)), inline: true},
      {name: 'Expires', value: inline(dateText(info.expiresAt)), inline: true}"""
new_fields = """      {name: 'Key ID', value: copyable(info.keyId), inline: false},
      {name: 'Label', value: inline(info.label || 'Unlabelled'), inline: true},
      {name: 'Status', value: inline(statusText(info.status)), inline: true},
      {name: 'Source', value: inline(info.source), inline: true},
      {name: 'Roblox username', value: info.binding ? copyable(info.binding.username) : inline('unbound'), inline: false},
      {name: 'Roblox UserId', value: info.binding ? copyable(info.binding.userId) : inline('unbound'), inline: false},
      {name: 'Uses', value: inline(info.uses), inline: true},
      {name: 'Created', value: copyable(dateText(info.createdAt)), inline: false},
      {name: 'Expires', value: copyable(dateText(info.expiresAt)), inline: false}"""
if old_fields not in bot:
    raise SystemExit('Discord detail fields not found')
bot = bot.replace(old_fields, new_fields, 1)
bot = bot.replace(".setFooter({text: 'Raw keys cannot be viewed or recovered'})", ".setFooter({text: 'Premium raw keys cannot be viewed or recovered'})", 1)

pattern = re.compile(r"const generatedText = \(result, title = 'Generated key'\) => \{[\s\S]*?\n\};\n\nconst keyIdFrom")
replacement = r'''const generatedText = (result, title = 'Generated premium key') => {
  const rawKey = String(result.key);
  const loader = "loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/init.lua', true), 'init.lua')({Closet = false, premiumKey = " + JSON.stringify(rawKey) + '})';
  const content = [
    '✅ **' + title + '**',
    '',
    'Normal AetherV2 works without this key. This key only unlocks AetherV2 Premium modules.',
    '',
    'Key ID', copyable(result.keyId),
    'Label ' + inline(result.record.label || 'Unlabelled') + '  •  expires ' + inline(dateText(result.record.expiresAt)),
    '',
    '⚠️ **Copy the raw premium key now. It is not stored and cannot be shown again.**',
    copyable(rawKey),
    '',
    'Premium loadstring', copyable(loader, 'lua')
  ].join('\n');
  if (content.length > MESSAGE_LIMIT) throw new Error('Generated premium loader exceeds Discord message limits');
  return content;
};

const keyIdFrom'''
bot, count = pattern.subn(lambda _: replacement, bot, count=1)
if count != 1:
    raise SystemExit('generatedText not found')

bot = bot.replace("revoke: ['Revoke this key?', 'Existing loader sessions will stop working immediately.']", "revoke: ['Revoke this premium key?', 'Existing premium sessions will stop working immediately. Normal AetherV2 will still load.']", 1)
bot = bot.replace("unlink: ['Unlink this account?', 'The next verified Roblox account will be able to claim this key.']", "unlink: ['Unlink this premium key?', 'The next verified Roblox account will be able to claim this premium key.']", 1)
bot = bot.replace("rotate: ['Rotate this key?', 'The old key and all of its sessions will be revoked. A replacement raw key will be shown once.']", "rotate: ['Rotate this premium key?', 'The old premium key and all premium sessions will be revoked. A replacement raw premium key will be shown once.']", 1)
bot = bot.replace("{name: 'Key ID', value: codeBlock(info.keyId)}", "{name: 'Key ID', value: copyable(info.keyId)}", 1)
bot = bot.replace("{name: 'Account', value: inline(bindingText(info.binding)), inline: true}", "{name: 'Account', value: info.binding ? copyable(info.binding.username) : inline('unbound'), inline: false}", 1)

bot = bot.replace("return reply(interaction, '✅ Updated key ' + inline(result.keyId) + '.\\nLabel ' + inline(result.record.label || 'none') + ' • expires ' + inline(dateText(result.record.expiresAt)) + '.');", "return reply(interaction, ['✅ Updated premium key', copyable(result.keyId), 'Label ' + inline(result.record.label || 'none'), 'Expires', copyable(dateText(result.record.expiresAt))].join('\\n'));", 1)
bot = bot.replace("return reply(interaction, '✅ Renewed and enabled ' + inline(result.keyId) + ' until ' + inline(dateText(result.record.expiresAt)) + '.');", "return reply(interaction, ['✅ Renewed and enabled premium key', copyable(result.keyId), 'Expires', copyable(dateText(result.record.expiresAt))].join('\\n'));", 1)
bot = bot.replace("return reply(interaction, '✅ Enabled ' + inline(result.keyId) + '.');", "return reply(interaction, ['✅ Enabled premium key', copyable(result.keyId)].join('\\n'));", 1)
bot = bot.replace("content: '✅ Revoked ' + inline(result.keyId) + '. Existing source sessions are now invalid.'", "content: ['✅ Revoked premium key', copyable(result.keyId), 'Existing premium sessions are now invalid. Normal AetherV2 is unaffected.'].join('\\n')", 1)
bot = bot.replace("content: '✅ Unlinked ' + inline(result.binding.username) + ' from ' + inline(result.keyId) + '.'", "content: ['✅ Unlinked Roblox account', copyable(result.binding.username), 'From premium key', copyable(result.keyId)].join('\\n')", 1)
bot = bot.replace("return reply(interaction, '✅ Updated ' + inline(result.keyId) + '.\\nLabel ' + inline(result.record.label || 'none') + ' • expires ' + inline(dateText(result.record.expiresAt)) + '.');", "return reply(interaction, ['✅ Updated premium key', copyable(result.keyId), 'Label ' + inline(result.record.label || 'none'), 'Expires', copyable(dateText(result.record.expiresAt))].join('\\n'));", 1)
bot = bot.replace("return reply(interaction, '✅ Renewed and enabled ' + inline(result.keyId) + ' until ' + inline(dateText(result.record.expiresAt)) + '.');", "return reply(interaction, ['✅ Renewed and enabled premium key', copyable(result.keyId), 'Expires', copyable(dateText(result.record.expiresAt))].join('\\n'));", 1)
bot = bot.replace("  if (!SOURCE_ORIGIN) throw new Error('PUBLIC_ORIGIN is required');\n", '', 1)

if '/loader?key=' in bot or 'SOURCE_ORIGIN' in bot:
    raise SystemExit('Discord bot still contains retired Render loader')
if 'const copyable =' not in bot or 'premiumKey = ' not in bot:
    raise SystemExit('Discord premium copy/loader changes missing')
bot_path.write_text(bot)

# Update Discord tests for both desktop/mobile copy surfaces and the public premium loadstring.
test_path = Path('backend/discord-bot.test.js')
tests = test_path.read_text()
tests = tests.replace("test('generated raw keys and loaders use copy-button code blocks and stay within Discord limits', () => {", "test('generated premium keys and loaders support desktop and mobile copying', () => {", 1)
old = """  assert.ok(content.length <= bot.MESSAGE_LIMIT);
  assert.match(content, /```text\\n[c]+\\n```/);
  assert.match(content, /```lua\\nloadstring/);
  assert.match(content, /cannot be shown again/i);"""
new = """  assert.ok(content.length <= bot.MESSAGE_LIMIT);
  assert.match(content, /```text\\n[c]+\\n```/);
  assert.match(content, /`[c]+`/);
  assert.match(content, /```lua\\nloadstring/);
  assert.match(content, /`loadstring\\(game:HttpGet/);
  assert.match(content, /raw\\.githubusercontent\\.com\\/plutoxqqqq\\/AetherV2\\/main\\/init\\.lua/);
  assert.match(content, /premiumKey = \\\"[c]+\\\"/);
  assert.doesNotMatch(content, /\\/loader\\?key=/);
  assert.match(content, /only unlocks AetherV2 Premium/i);
  assert.match(content, /cannot be shown again/i);"""
if old not in tests:
    raise SystemExit('Discord generatedText test block not found')
tests = tests.replace(old, new, 1)
test_path.write_text(tests)

# Documentation: normal source is public; Render/key management is premium-only.
readme = Path('backend/README.md')
r = readme.read_text()
r = r.replace('This directory contains the key-gated private-source service, its Discord management bot, and the separate config-review service.', 'This directory contains the optional premium-key service, its Discord management bot, and the separate config-review service. Normal AetherV2 loads publicly from GitHub without a key.', 1)
r = r.replace('Source access uses a short-lived in-memory session, but every `/source`, `/tree`, and `/commit` request rechecks the session’s key ID against the live registry.', 'Premium access uses a short-lived in-memory session, and every `/premium/source` and `/premium/tree` request rechecks the key status and current Roblox binding against the live registry.', 1)
r = r.replace('The proxy allows only configured refs and client path prefixes.', 'The premium proxy allows only the configured private premium branch and premium path prefixes.', 1)
r = r.replace('The application never stores or logs raw keys. Key IDs, usernames, and UserIds are safe to log. Note that loaders place a raw key in an HTTPS query string because Roblox executors use `game:HttpGet`; hosting/CDN access logs must therefore be disabled or tightly restricted and redacted.', 'The application never stores or logs raw keys. Key IDs, usernames, and UserIds are safe to log. Premium authorization sends the raw key to `/premium/authorize` over HTTPS, so hosting/CDN access logs must be disabled or tightly restricted and redacted.', 1)
r = r.replace('- `/key generate` — creates a key and shows the raw key/loader once in copy-button code blocks.', '- `/key generate` — creates an optional premium key and shows the raw key plus the public GitHub `premiumKey` loadstring once. Copyable values use both fenced code blocks and inline code for desktop/mobile.', 1)
r = r.replace('- `/key info` — copy-friendly safe details for a full key ID or unique prefix.', '- `/key info` — safe premium-key details; full key IDs, Roblox usernames/UserIds, and dates use both fenced and inline copy formats.', 1)
r = r.replace('- `/key revoke` — asks for confirmation, records a `revoke` event, and invalidates source sessions.', '- `/key revoke` — asks for confirmation, records a `revoke` event, and invalidates premium sessions; normal AetherV2 remains public.', 1)
r = r.replace('A GitHub or registry outage intentionally blocks source access until validation is available.', 'A GitHub or registry outage intentionally blocks premium access until validation is available; normal public AetherV2 is unaffected.', 1)
readme.write_text(r)

print('premium backend and Discord bot repair applied')