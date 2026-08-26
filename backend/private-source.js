'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const registry = require('./key-registry');

const PORT = Number(process.env.PORT || 3000);
const REPOSITORY = process.env.GITHUB_REPO || 'plutoxqqqq/AetherV2';
const BRANCH = process.env.GITHUB_BRANCH || 'main';
const SESSION_MINUTES_VALUE = Number(process.env.AETHER_SESSION_MINUTES || 120);
const SESSION_MINUTES = Number.isFinite(SESSION_MINUTES_VALUE)
  ? Math.max(5, Math.min(1440, SESSION_MINUTES_VALUE))
  : 120;
const SESSION_TTL = SESSION_MINUTES * 60 * 1000;
const sessions = new Map();

const headers = {
  authorization: 'Bearer ' + (process.env.GITHUB_TOKEN || ''),
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

const githubUrl = endpoint => 'https://api.github.com/repos/' + REPOSITORY + '/' + endpoint;
const githubRequest = (endpoint, options = {}) => fetch(githubUrl(endpoint), {
  ...options,
  headers: {...headers, ...(options.headers || {})}
});

const github = async endpoint => {
  const response = await githubRequest(endpoint);
  if (!response.ok) {
    const error = new Error('GitHub request failed with HTTP ' + response.status);
    error.status = response.status === 404 ? 404 : 502;
    throw error;
  }
  return response;
};

const createOrigin = req => {
  const protocol = req.headers['x-forwarded-proto'] || 'https';
  return (process.env.PUBLIC_ORIGIN || protocol + '://' + req.headers.host).replace(/\/+$/, '');
};

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
  'loadstring(game:HttpGet(endpoint.."/source?path=init.lua&ref=main&session="..session, true), "init.lua")({',
  '    Closet = false,',
  '    SourceEndpoint = endpoint,',
  '    SourceToken = session',
  '})'
].join('\n');

const sourceFile = async (file, ref) => {
  const response = await github('contents/' + file + '?ref=' + encodeURIComponent(ref));
  const value = await response.json();
  if (value.type !== 'file' || typeof value.content !== 'string') {
    const error = new Error('GitHub returned an invalid source file');
    error.status = 502;
    throw error;
  }
  return Buffer.from(value.content.replace(/\n/g, ''), 'base64').toString('utf8');
};

const commitSha = async ref => {
  const value = await (await github('commits/' + encodeURIComponent(ref))).json();
  if (typeof value.sha !== 'string') {
    const error = new Error('GitHub returned an invalid commit');
    error.status = 502;
    throw error;
  }
  return value.sha;
};

const tree = async ref => {
  const value = await (await github('git/trees/' + encodeURIComponent(ref) + '?recursive=1')).json();
  if (Array.isArray(value.tree)) value.tree = value.tree.filter(entry => clientPath(entry.path));
  return JSON.stringify(value);
};

const validKey = value => registry.isValidKey(value);

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return res.writeHead(204).end();
    const url = new URL(req.url, 'http://localhost');

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, {
        success: true,
        service: 'aetherv2-private-source',
        keyGating: true,
        discordBot: Boolean(process.env.DISCORD_TOKEN)
      });
    }

    if (req.method === 'GET' && url.pathname === '/loader') {
      const key = url.searchParams.get('key') || '';
      if (!await validKey(key)) {
        return json(res, 401, {success: false, error: 'Invalid or disabled AetherV2 key'});
      }
      return text(res, 200, firstStageLoader(createOrigin(req), key));
    }

    if (req.method === 'GET' && url.pathname === '/authorize') {
      const key = url.searchParams.get('key') || '';
      const keyInfo = await registry.resolveKey(key);
      const person = {
        username: url.searchParams.get('username'),
        userId: url.searchParams.get('userId')
      };
      if (!keyInfo) return json(res, 401, {success: false, error: 'Invalid or disabled AetherV2 key'});
      if (!/^[A-Za-z0-9_]{3,20}$/.test(String(person.username || '')) ||
          !/^\d{1,20}$/.test(String(person.userId || ''))) {
        return json(res, 400, {success: false, error: 'Invalid Roblox identity'});
      }
      if (!await verifyRobloxIdentity(person)) {
        return json(res, 403, {success: false, error: 'Roblox identity could not be verified'});
      }
      const binding = await registry.bindKey(keyInfo.keyId, person);
      console.log('[AetherV2] key ' + binding.id.slice(0, 12) + ' used by ' + person.username + ' (' + person.userId + ')');
      return text(res, 200, sessionLoader(createOrigin(req), createSession(binding)));
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

const verifyRobloxIdentity = async person => {
  const response = await fetch('https://users.roblox.com/v1/users/' + encodeURIComponent(person.userId));
  if (!response.ok) return false;
  const value = await response.json();
  return typeof value.name === 'string' &&
    value.name.toLowerCase() === String(person.username).toLowerCase();
};

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

if (require.main === module) {
  server.listen(PORT, () => console.log('AetherV2 private-source proxy listening on ' + PORT));
  if (process.env.DISCORD_TOKEN) {
    try {
      const bot = require('./discord-bot');
      bot.startDiscordBot().catch(error => {
        console.error('[AetherV2] Discord bot failed:', error.message || error);
      });
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
  verifyRobloxIdentity
};
