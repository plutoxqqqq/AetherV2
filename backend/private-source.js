'use strict';

// Source code and key-registry data deliberately live on different branches. Key usage must never
// mutate the deployment branch, otherwise a normal authorization can redeploy Render and destroy
// the in-memory source session that is still loading.
const sourceBranch = process.env.GITHUB_BRANCH || '';
const registryBranch = process.env.AETHER_REGISTRY_BRANCH || 'aether-key-registry';
if (!sourceBranch) throw new Error('GITHUB_BRANCH is required');
if (!registryBranch || registryBranch === sourceBranch) {
  throw new Error('AETHER_REGISTRY_BRANCH must be different from GITHUB_BRANCH');
}

// A cold client can legitimately request dozens of authenticated files in a short burst. The old
// 180/min default was close enough to normal startup traffic that one late request (often the game
// module) could be throttled. Keep explicit higher values, but do not allow the private source
// service to start below a sane authenticated-loader floor.
const configuredRate = Number(process.env.AETHER_RATE_LIMIT || 0);
if (!Number.isFinite(configuredRate) || configuredRate < 600) process.env.AETHER_RATE_LIMIT = '600';

process.env.GITHUB_BRANCH = registryBranch;
let registry;
try {
  registry = require('./key-registry');
} finally {
  process.env.GITHUB_BRANCH = sourceBranch;
}

// requireSession used to call isKeyIdActive for every /source request, and isKeyIdActive reads the
// GitHub-backed registry every time. That doubled upstream GitHub traffic for essentially every
// file in a cold load and made GitHub secondary throttling a realistic late-startup failure mode.
// Cache only the active/inactive answer for a few seconds. Registry mutations performed by this
// process clear the cache immediately, so revoke/disable/rotate still invalidate existing sessions
// on their next request rather than waiting for the TTL.
const activeStatusCache = new Map();
const statusCacheMs = Math.max(1000, Math.min(15000, Number(process.env.AETHER_KEY_STATUS_CACHE_MS) || 5000));
const originalIsKeyIdActive = registry.isKeyIdActive.bind(registry);
registry.isKeyIdActive = async id => {
  const now = Date.now();
  const cached = activeStatusCache.get(id);
  if (cached && cached.expiresAt > now) return cached.value;
  const value = await originalIsKeyIdActive(id);
  activeStatusCache.set(id, {value: Boolean(value), expiresAt: now + statusCacheMs});
  return Boolean(value);
};

for (const name of ['bindKey', 'createKey', 'editKey', 'unlinkKey', 'revokeKey', 'enableKey', 'renewKey', 'rotateKey']) {
  if (typeof registry[name] !== 'function') continue;
  const original = registry[name].bind(registry);
  registry[name] = async (...args) => {
    try {
      return await original(...args);
    } finally {
      activeStatusCache.clear();
    }
  };
}

const service = require('./private-source-server');

if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  service.server.listen(port, () => console.log('AetherV2 private-source proxy listening on ' + port));
  if (process.env.DISCORD_TOKEN) {
    try {
      const bot = require('./discord-bot');
      bot.startDiscordBot().catch(error => console.error('[AetherV2] Discord bot failed:', error.message || error));
    } catch (error) {
      console.error('[AetherV2] Discord bot could not start:', error.message || error);
    }
  }
}

module.exports = service;
