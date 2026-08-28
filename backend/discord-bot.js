'use strict';

// Keep Discord key-management writes off the branch that deploys the private source service.
// This mirrors private-source.js so generate/edit/revoke/renew/rotate operations update only the
// registry data branch and cannot restart the loader service.
const sourceBranch = process.env.GITHUB_BRANCH || '';
const registryBranch = process.env.AETHER_REGISTRY_BRANCH || 'aether-key-registry';
if (!sourceBranch) throw new Error('GITHUB_BRANCH is required');
if (!registryBranch || registryBranch === sourceBranch) {
  throw new Error('AETHER_REGISTRY_BRANCH must be different from GITHUB_BRANCH');
}

process.env.GITHUB_BRANCH = registryBranch;
try {
  require('./key-registry');
} finally {
  process.env.GITHUB_BRANCH = sourceBranch;
}

const bot = require('./discord-bot-server');

if (require.main === module) {
  bot.startDiscordBot().catch(error => {
    console.error('[AetherV2] Discord bot failed:', error.message || error);
    process.exitCode = 1;
  });
}

module.exports = bot;
