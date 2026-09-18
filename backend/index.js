'use strict';

// One service, one folder, one port.
//
// AetherV2 used to be three deployables with three entrypoints: the Community Configs review API
// (server.js), the premium source proxy plus execution analytics (private-source.js), and the
// Discord key bot (discord-bot.js). This file is the single entrypoint. Each service is still its
// own module with its own handler, so the split deployments keep working; the merged process just
// gives every route one listener and one origin the client can be pointed at.
//
// The client has always addressed all of them through configapi.Presets.Backend(), so no route
// moved. A single URL now covers configs, premium and analytics instead of one per deployable.

const http = require('node:http');

const boundedNumber = (value, fallback, min, max) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
};

const PORT = boundedNumber(process.env.PORT, 3000, 1, 65535);

const configs = require('./server');

// The premium stack validates GITHUB_TOKEN, GITHUB_REPO and PUBLIC_ORIGIN while it loads and
// refuses to start without them. Loading it only when PREMIUM_GITHUB_REPO is set keeps a
// Community-Configs-only deployment from dying at boot over settings it never reads, while a
// premium deployment still fails loudly on exactly the same checks as before.
let premium = null;
if (process.env.PREMIUM_GITHUB_REPO) {
  premium = require('./private-source-core');
}

const json = (res, status, value) => {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    // The union of what both services need: the config API takes Authorization, the rest do not.
    'access-control-allow-headers': 'authorization,content-type'
  });
  res.end(JSON.stringify(value));
};

// A probe against the merged service should report every capability in one round trip, so this
// answers before the services get a chance to. Each service keeps its own /health for the split
// deployments.
const health = res => json(res, 200, {
  success: true,
  service: 'aetherv2-backend',
  normalSource: 'public-github',
  configs: true,
  premiumEnabled: Boolean(premium && premium.premiumEnabled),
  executionAnalytics: Boolean(premium),
  discordBot: Boolean(process.env.DISCORD_TOKEN)
});

async function handleRequest(req, res) {
  try {
    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
        'access-control-allow-headers': 'authorization,content-type'
      }).end();
      return true;
    }
    const url = new URL(req.url, 'http://localhost');
    if (req.method === 'GET' && (url.pathname.replace(/\/+$/, '') || '/') === '/health') return health(res);
    // Order matters only in that each handler answers for its own paths and declines the rest.
    if (premium && await premium.handleRequest(req, res)) return true;
    if (await configs.handleRequest(req, res)) return true;
    return json(res, 404, {success: false, error: 'Endpoint not found'});
  } catch (error) {
    // A handler that has already written a response cannot be answered twice; end it instead of
    // throwing out of the promise and taking the process down.
    if (res.headersSent || res.writableEnded) {
      res.end();
      return true;
    }
    return json(res, error.status || 500, {success: false, error: error.message || 'Request failed'});
  }
}

const server = http.createServer((req, res) => {
  handleRequest(req, res);
});

if (require.main === module) {
  server.listen(PORT, () => console.log('AetherV2 backend listening on ' + PORT +
    (premium ? ' (configs + premium + analytics)' : ' (configs only)')));
  if (premium && process.env.DISCORD_TOKEN) {
    try {
      require('./discord-bot').startDiscordBot()
        .catch(error => console.error('[AetherV2] Discord bot failed:', error.message || error));
    } catch (error) {
      console.error('[AetherV2] Discord bot could not start:', error.message || error);
    }
  }
  // Analytics and the config store both live on a local disk, so a restart must not drop the
  // counters that have not been written yet.
  let stopping = false;
  const shutdown = () => {
    if (stopping) return;
    stopping = true;
    server.close(() => process.exit(0));
    try {
      if (premium) premium.executionStats.flush();
    } catch (error) {
      console.error('[AetherV2] execution analytics flush failed:', error.message || error);
    }
    setTimeout(() => process.exit(0), 5000).unref();
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

module.exports = {server, handleRequest, health, PORT, premium};
