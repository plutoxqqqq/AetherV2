'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const PORT = Number(process.env.PORT || 3000);
const REPOSITORY = process.env.GITHUB_REPO || 'plutoxqqqq/AetherV2';
const BRANCH = process.env.GITHUB_BRANCH || 'main';
const TOKEN = process.env.GITHUB_TOKEN || '';
const KEY_SOURCE = process.env.AETHER_KEYS || process.env.AETHER_KEY || '';
const KEYS = KEY_SOURCE.split(',').map(value => value.trim()).filter(Boolean);
const REGISTRY_FILE = process.env.AETHER_REGISTRY_FILE || 'backend/key-bindings.json';
const SESSION_MINUTES = Math.max(5, Math.min(1440, Number(process.env.AETHER_SESSION_MINUTES || 120)));
const SESSION_TTL = SESSION_MINUTES * 60 * 1000;
const sessions = new Map();
let registryQueue = Promise.resolve();

if (!TOKEN) throw new Error('GITHUB_TOKEN is required');
if (KEYS.length === 0) throw new Error('AETHER_KEYS is required');

const headers = {
  authorization: `Bearer ${TOKEN}`,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-private-source-proxy',
  'x-github-api-version': '2022-11-28'
};

const validRef = value =>
  typeof value === 'string' && value.length > 0 && value.length <= 200 &&
  !value.includes('..') && !value.includes('\\') && !value.includes('?') && !value.includes('#');

const validPath = value =>
  typeof value === 'string' && value.length > 0 && value.length <= 300 &&
  !value.startsWith('/') && !value.includes('\\') && !value.includes('?') && !value.includes('#') &&
  value.split('/').every(segment => segment && segment !== '.' && segment !== '..');

const clientPath = value =>
  validPath(value) && !value.startsWith('backend/') && !value.startsWith('.git/') &&
  !value.startsWith('.github/') && value !== 'README.md' && value !== 'LICENSE';

const digest = value => crypto.createHash('sha256').update(String(value || '')).digest();
const keyId = value => digest(value).toString('hex');
const keyDigests = KEYS.map(value => digest(value));
const validKey = value => {
  if (typeof value !== 'string' || value.length < 16 || value.length > 256) return false;
  const candidate = digest(value);
  return keyDigests.some(expected => crypto.timingSafeEqual(candidate, expected));
};

const identity = (username, userId) => {
  if (typeof username !== 'string' || !/^[A-Za-z0-9_]{3,20}$/.test(username)) return null;
  if (typeof userId !== 'string' || !/^\\d{1,20}$/.test(userId)) return null;
  return {username, userId};
};

const json = (res, status, value) => {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,OPTIONS',
    'access-control-allow-headers': 'content-type'
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

const githubUrl = endpoint => `https://api.github.com/repos/${REPOSITORY}/${endpoint}`;
const githubRequest = (endpoint, options = {}) => fetch(githubUrl(endpoint), {
  ...options,
  headers: {...headers, ...(options.headers || {})}
});

const github = async endpoint => {
  const response = await githubRequest(endpoint);
  if (!response.ok) {
    const error = new Error(`GitHub request failed with HTTP ${response.status}`);
    error.status = response.status === 404 ? 404 : 502;
    throw error;
  }
  return response;
};

const emptyRegistry = () => ({version: 1, bindings: {}});
const readRegistry = async () => {
  const response = await githubRequest(`contents/${REGISTRY_FILE}?ref=${encodeURIComponent(BRANCH)}`);
  if (response.status === 404) return {data: emptyRegistry(), sha: null};
  if (!response.ok) {
    const error = new Error(`Could not read key registry (HTTP ${response.status})`);
    error.status = 502;
    throw error;
  }
  const remote = await response.json();
  if (typeof remote.content !== 'string') throw new Error('Invalid key registry response');
  let data;
  try {
    data = JSON.parse(Buffer.from(remote.content.replace(/\n/g, ''), 'base64').toString('utf8'));
  } catch {
    throw new Error('Key registry is invalid JSON');
  }
  if (!data || typeof data !== 'object' || !data.bindings || typeof data.bindings !== 'object') {
    throw new Error('Key registry has an invalid shape');
  }
  return {data, sha: remote.sha};
};

const writeRegistry = async (data, sha) => {
  const body = {
    message: 'Record AetherV2 key binding',
    branch: BRANCH,
    content: Buffer.from(JSON.stringify(data, null, 2) + '\\n').toString('base64'),
    ...(sha && {sha})
  };
  const response = await githubRequest(`contents/${REGISTRY_FILE}`, {
    method: 'PUT',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify(body)
  });
  if (!response.ok) {
    const error = new Error(`Could not write key registry (HTTP ${response.status})`);
    error.status = 502;
    throw error;
  }
};

const withRegistryLock = work => {
  const next = registryQueue.then(work, work);
  registryQueue = next.catch(() => undefined);
  return next;
};

const verifyRobloxIdentity = async person => {
  const response = await fetch(`https://users.roblox.com/v1/users/${person.userId}`);
  if (!response.ok) return false;
  const value = await response.json();
  return typeof value.name === 'string' && value.name.toLowerCase() === person.username.toLowerCase();
};

const bindKey = async (key, person) => withRegistryLock(async () => {
  const id = keyId(key);
  const current = await readRegistry();
  const existing = current.data.bindings[id];
  const now = new Date().toISOString();

  if (existing) {
    const sameUser = String(existing.userId) === person.userId &&
      String(existing.username).toLowerCase() === person.username.toLowerCase();
    if (!sameUser) {
      const error = new Error('This key is already locked to another Roblox account');
      error.status = 403;
      throw error;
    }
    console.log(`[AetherV2] key ${id.slice(0, 12)} used by ${person.username} (${person.userId})`);
    return {id, binding: existing};
  }

  current.data.bindings[id] = {
    username: person.username,
    userId: person.userId,
    firstUsedAt: now,
    uses: 1
  };
  await writeRegistry(current.data, current.sha);
  console.log(`[AetherV2] key ${id.slice(0, 12)} bound to ${person.username} (${person.userId})`);
  return {id, binding: current.data.bindings[id]};
});

const createSession = binding => {
  const now = Date.now();
  for (const [session, value] of sessions) {
    if (value.expiresAt <= now) sessions.delete(session);
  }
  const session = crypto.randomBytes(32).toString('hex');
  sessions.set(session, {
    expiresAt: now + SESSION_TTL,
    keyId: binding.id,
    username: binding.binding.username,
    userId: String(binding.binding.userId)
  });
  return session;
};

const requireSession = url => {
  const session = url.searchParams.get('session') || '';
  const value = sessions.get(session);
  if (!value || value.expiresAt <= Date.now()) {
    sessions.delete(session);
    const error = new Error('A valid loader session is required');
    error.status = 401;
    throw error;
  }
  return value;
};

const firstStageLoader = (origin, key) => [
  `local endpoint = ${JSON.stringify(origin)}`,
  `local key = ${JSON.stringify(key)}`,
  `local players = game:GetService('Players')`,
  `repeat task.wait() until players.LocalPlayer`,
  `local player = players.LocalPlayer`,
  `local function encode(value)`,
  `  return tostring(value):gsub('([^%w%-%._~])', function(character)`,
  `    return string.format('%%%02X', string.byte(character))`,
  `  end)`,
  `end`,
  `local url = endpoint..'/authorize?key='..encode(key)..'&username='..encode(player.Name)..'&userId='..tostring(player.UserId)`,
  `local stage = game:HttpGet(url, true)`,
  `loadstring(stage, 'aether-authorize')()`
].join('\n');

const sessionLoader = (origin, session) => [
  `local endpoint = ${JSON.stringify(origin)}`,
  `local session = ${JSON.stringify(session)}`,
  `loadstring(game:HttpGet(endpoint..'/source?path=init.lua&ref=main&session='..session, true), 'init.lua')({`,
  `    Closet = false,`,
  `    SourceEndpoint = endpoint,`,
  `    SourceToken = session`,
  `})`
].join('\n');

const sourceFile = async (file, ref) => {
  const response = await github(`contents/${file}?ref=${encodeURIComponent(ref)}`);
  const value = await response.json();
  if (value.type !== 'file' || typeof value.content !== 'string') {
    const error = new Error('GitHub returned an invalid source file');
    error.status = 502;
    throw error;
  }
  return Buffer.from(value.content.replace(/\n/g, ''), 'base64').toString('utf8');
};

const commitSha = async ref => {
  const value = await (await github(`commits/${encodeURIComponent(ref)}`)).json();
  if (typeof value.sha !== 'string') {
    const error = new Error('GitHub returned an invalid commit');
    error.status = 502;
    throw error;
  }
  return value.sha;
};

const tree = async ref => {
  const value = await (await github(`git/trees/${encodeURIComponent(ref)}?recursive=1`)).json();
  if (Array.isArray(value.tree)) {
    value.tree = value.tree.filter(entry => clientPath(entry.path));
  }
  return JSON.stringify(value);
};

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return res.writeHead(204).end();
    const url = new URL(req.url, 'http://localhost');

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, {success: true, service: 'aetherv2-private-source', keyGating: true});
    }

    if (req.method === 'GET' && url.pathname === '/loader') {
      const key = url.searchParams.get('key') || '';
      if (!validKey(key)) return json(res, 401, {success: false, error: 'Invalid AetherV2 key'});
      const protocol = req.headers['x-forwarded-proto'] || 'https';
      const origin = process.env.PUBLIC_ORIGIN || `${protocol}://${req.headers.host}`;
      return text(res, 200, firstStageLoader(origin, key));
    }

    if (req.method === 'GET' && url.pathname === '/authorize') {
      const key = url.searchParams.get('key') || '';
      const person = identity(url.searchParams.get('username'), url.searchParams.get('userId'));
      if (!validKey(key)) return json(res, 401, {success: false, error: 'Invalid AetherV2 key'});
      if (!person) return json(res, 400, {success: false, error: 'Invalid Roblox identity'});
      if (!await verifyRobloxIdentity(person)) return json(res, 403, {success: false, error: 'Roblox identity could not be verified'});
      const binding = await bindKey(key, person);
      const protocol = req.headers['x-forwarded-proto'] || 'https';
      const origin = process.env.PUBLIC_ORIGIN || `${protocol}://${req.headers.host}`;
      return text(res, 200, sessionLoader(origin, createSession(binding)));
    }

    const ref = url.searchParams.get('ref') || BRANCH;
    if (!validRef(ref)) return json(res, 400, {success: false, error: 'Invalid ref'});

    if (req.method === 'GET' && url.pathname === '/source') {
      requireSession(url);
      const file = url.searchParams.get('path');
      if (!clientPath(file)) return json(res, 403, {success: false, error: 'This file is not available through the client proxy'});
      return text(res, 200, await sourceFile(file, ref));
    }

    if (req.method === 'GET' && url.pathname === '/commit') {
      requireSession(url);
      return text(res, 200, await commitSha(ref));
    }

    if (req.method === 'GET' && url.pathname === '/tree') {
      requireSession(url);
      return text(res, 200, await tree(ref), 'application/json; charset=utf-8');
    }

    return json(res, 404, {success: false, error: 'Not found'});
  } catch (error) {
    return json(res, error.status || 500, {success: false, error: error.message || 'Proxy failure'});
  }
});

if (require.main === module) {
  server.listen(PORT, () => console.log(`AetherV2 private-source proxy listening on port ${PORT}`));
}

module.exports = {server, validPath, validRef, validKey, identity, clientPath};
