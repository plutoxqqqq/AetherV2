'use strict';

// The source service is deployed from GITHUB_BRANCH (normally main), but key usage also mutates
// the persistent registry. Writing those mutations back to the deployment branch makes each loader
// authorization create a source commit, which can trigger a Render redeploy and erase the in-memory
// source session while the same client is still loading. Preload the registry against a dedicated
// data branch, then restore the source branch before the real server module initializes.
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

module.exports = require('./private-source-server');
