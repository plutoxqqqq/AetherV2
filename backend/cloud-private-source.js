'use strict';

const http = require('node:http');
const premium = require('./private-source');
const cloud = require('./cloud-configs');

const PORT = Math.max(1, Math.min(65535, Number(process.env.PORT) || 3000));
const MAX_BODY = cloud.MAX_PAYLOAD_BYTES + (64 * 1024);
const TRUST_PROXY = process.env.AETHER_TRUST_PROXY === 'true';
const RATE_WINDOW_MS = Math.max(1000, Math.min(3600000, Number(process.env.AETHER_RATE_WINDOW_MS) || 60000));
const CLOUD_RATE_LIMIT = Math.max(10, Math.min(1000, Number(process.env.AETHER_CLOUD_RATE_LIMIT) || 120));
const buckets = new Map();
const premiumHandler = premium.server.listeners('request')[0];

if (typeof premiumHandler !== 'function') throw new Error('AetherV2 premium request handler is unavailable');

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

const readBody = req => new Promise((resolve, reject) => {
  let size = 0;
  let settled = false;
  const chunks = [];
  req.on('data', chunk => {
    if (settled) return;
    const value = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += value.length;
    if (size > MAX_BODY) {
      settled = true;
      reject(Object.assign(new Error('Request body is too large'), {status: 413}));
      return;
    }
    chunks.push(value);
  });
  req.on('end', () => {
    if (settled) return;
    settled = true;
    try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); }
    catch { reject(Object.assign(new Error('Invalid JSON body'), {status: 400})); }
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
const rateLimit = req => {
  const now = Date.now();
  if (buckets.size > 10000) for (const [key, bucket] of buckets) if (bucket.resetAt <= now) buckets.delete(key);
  const key = requestIp(req);
  let bucket = buckets.get(key);
  if (!bucket || bucket.resetAt <= now) bucket = {count: 0, resetAt: now + RATE_WINDOW_MS};
  bucket.count += 1;
  buckets.set(key, bucket);
  return bucket.count <= CLOUD_RATE_LIMIT ? null : Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
};

const routeCloud = async (req, res, url) => {
  if (req.method === 'OPTIONS') return res.writeHead(204, {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'access-control-allow-headers': 'content-type'
  }).end();

  const retryAfter = rateLimit(req);
  if (retryAfter) return json(res, 429, {success: false, error: 'Too many cloud config requests; try again shortly'}, {'retry-after': String(retryAfter)});

  const shareMatch = url.pathname.match(/^\/cloud\/share\/([^/]+)$/);
  if (req.method === 'GET' && shareMatch) {
    const config = await cloud.resolveShare(decodeURIComponent(shareMatch[1]));
    return json(res, 200, {success: true, config});
  }

  if (url.pathname === '/cloud/import' && req.method === 'POST') {
    const session = await premium.requireSession(url);
    const config = await cloud.importShare(session, await readBody(req));
    return json(res, 201, {success: true, config});
  }

  if (url.pathname === '/cloud/configs') {
    const session = await premium.requireSession(url);
    if (req.method === 'GET') {
      const configs = await cloud.list(session, url.searchParams.get('placeId'));
      return json(res, 200, {success: true, limit: cloud.MAX_CONFIGS_PER_KEY, configs});
    }
    if (req.method === 'POST') {
      const config = await cloud.create(session, await readBody(req));
      return json(res, 201, {success: true, config, limit: cloud.MAX_CONFIGS_PER_KEY});
    }
  }

  const configMatch = url.pathname.match(/^\/cloud\/configs\/([a-f0-9-]{16,64})$/i);
  if (configMatch) {
    const session = await premium.requireSession(url);
    const id = configMatch[1];
    if (req.method === 'GET') {
      const config = await cloud.get(session, id);
      return json(res, 200, {success: true, config});
    }
    if (req.method === 'PUT') {
      const config = await cloud.save(session, id, await readBody(req));
      return json(res, 200, {success: true, config});
    }
    if (req.method === 'DELETE') {
      await cloud.remove(session, id);
      return json(res, 200, {success: true, id});
    }
    if (req.method === 'PATCH') {
      const input = await readBody(req);
      let config;
      if (input.action === 'rename') config = await cloud.rename(session, id, input.name);
      else if (input.action === 'sharing') config = await cloud.sharing(session, id, input.mode);
      else if (input.action === 'sync') config = await cloud.setSync(session, id, input.enabled);
      else if (input.action === 'restore-backup') config = await cloud.restoreBackup(session, id);
      else return json(res, 400, {success: false, error: 'Unknown cloud config action'});
      return json(res, 200, {success: true, config});
    }
  }

  return json(res, 404, {success: false, error: 'Cloud config endpoint not found'});
};

const server = http.createServer((req, res) => {
  let url;
  try { url = new URL(req.url, 'http://localhost'); }
  catch { return json(res, 400, {success: false, error: 'Invalid request URL'}); }

  if (!url.pathname.startsWith('/cloud/')) return premiumHandler(req, res);
  routeCloud(req, res, url).catch(error => {
    if (res.headersSent) return;
    json(res, error.status || 500, {success: false, error: error.message || 'Cloud config request failed'});
  });
});

if (require.main === module) {
  server.listen(PORT, () => console.log('AetherV2 premium + cloud service listening on ' + PORT));
  if (process.env.DISCORD_TOKEN) {
    try {
      const bot = require('./discord-bot');
      bot.startDiscordBot().catch(error => console.error('[AetherV2] Discord bot failed:', error.message || error));
    } catch (error) {
      console.error('[AetherV2] Discord bot could not start:', error.message || error);
    }
  }
}

module.exports = {server, routeCloud, readBody};
