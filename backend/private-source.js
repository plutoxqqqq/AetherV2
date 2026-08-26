'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const PORT = Number(process.env.PORT || 3000);
const REPOSITORY = process.env.GITHUB_REPO || 'plutoxqqqq/AetherV2';
const BRANCH = process.env.GITHUB_BRANCH || 'main';
const TOKEN = process.env.GITHUB_TOKEN || '';
const KEY_SOURCE = process.env.AETHER_KEYS || process.env.AETHER_KEY || '';
const KEYS = KEY_SOURCE.split(',').map(value => value.trim()).filter(Boolean);
const SESSION_MINUTES = Math.max(5, Math.min(1440, Number(process.env.AETHER_SESSION_MINUTES || 120)));
const SESSION_TTL = SESSION_MINUTES * 60 * 1000;
const sessions = new Map();

if (!TOKEN) {
  throw new Error('GITHUB_TOKEN is required');
}
if (KEYS.length === 0) {
  throw new Error('AETHER_KEYS is required');
}

const headers = {
  authorization: `Bearer ${TOKEN}`,
  accept: 'application/vnd.github+json',
  'user-agent': 'aetherv2-private-source-proxy',
  'x-github-api-version': '2022-11-28'
};

const validRef = value =>
  typeof value === 'string' && value.length > 0 && value.length <= 200 &&
  !value.includes('..') && !value.includes('\\') && !value.includes('?') &&
  !value.includes('#');

const validPath = value =>
  typeof value === 'string' && value.length > 0 && value.length <= 300 &&
  !value.startsWith('/') && !value.includes('\\') && !value.includes('?') && !value.includes('#') &&
  value.split('/').every(segment => segment && segment !== '.' && segment !== '..');

const digest = value => crypto.createHash('sha256').update(String(value || '')).digest();
const validKey = value => {
  if (typeof value !== 'string' || value.length < 16 || value.length > 256) return false;
  const candidate = digest(value);
  return KEYS.some(key => crypto.timingSafeEqual(candidate, digest(key)));
};

const createSession = () => {
  const now = Date.now();
  for (const [session, expiresAt] of sessions) {
    if (expiresAt <= now) sessions.delete(session);
  }
  const session = crypto.randomBytes(32).toString('hex');
  sessions.set(session, now + SESSION_TTL);
  return session;
};

const requireSession = url => {
  const session = url.searchParams.get('session') || '';
  const expiresAt = sessions.get(session);
  if (!expiresAt || expiresAt <= Date.now()) {
    sessions.delete(session);
    const error = new Error('A valid loader session is required');
    error.status = 401;
    throw error;
  }
  return session;
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

const github = async endpoint => {
  const response = await fetch(`https://api.github.com/repos/${REPOSITORY}/${endpoint}`, {headers});
  if (!response.ok) {
    const error = new Error(`GitHub request failed with HTTP ${response.status}`);
    error.status = response.status === 404 ? 404 : 502;
    throw error;
  }
  return response;
};

const sourceFile = async (file, ref) => {
  const response = await github(`contents/${file}?ref=${encodeURIComponent(ref)}`);
  const value = await response.json();
  if (value.type !== 'file' || typeof value.content !== 'string') {
    const error = new Error('GitHub returned an invalid source file');
    error.status = 502;
    throw error;
  }
  return Buffer.from(value.content.replace(/\\n/g, ''), 'base64').toString('utf8');
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

const tree = async ref =>
  (await github(`git/trees/${encodeURIComponent(ref)}?recursive=1`)).text();

const loader = (origin, session) => [
  `local endpoint = ${JSON.stringify(origin)}`,
  `local session = ${JSON.stringify(session)}`,
  `loadstring(game:HttpGet(endpoint..'/source?path=init.lua&ref=main&session='..session, true), 'init.lua')({`,
  `    Closet = false,`,
  `    SourceEndpoint = endpoint,`,
  `    SourceToken = session`,
  `})`
].join('\n');

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return res.writeHead(204).end();

    const url = new URL(req.url, 'http://localhost');
    const ref = url.searchParams.get('ref') || BRANCH;

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, {success: true, service: 'aetherv2-private-source', keyGating: true});
    }

    if (req.method === 'GET' && url.pathname === '/loader') {
      if (!validKey(url.searchParams.get('key'))) {
        return json(res, 401, {success: false, error: 'A valid AetherV2 key is required'});
      }
      const protocol = req.headers['x-forwarded-proto'] || 'https';
      const origin = process.env.PUBLIC_ORIGIN || `${protocol}://${req.headers.host}`;
      return text(res, 200, loader(origin, createSession()));
    }

    if (!validRef(ref)) return json(res, 400, {success: false, error: 'Invalid ref'});

    if (req.method === 'GET' && url.pathname === '/source') {
      requireSession(url);
      const file = url.searchParams.get('path');
      if (!validPath(file)) return json(res, 400, {success: false, error: 'Invalid source path'});
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

module.exports = {server, validPath, validRef, validKey, createSession, requireSession};
