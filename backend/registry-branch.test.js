'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GITHUB_TOKEN = 'test-token';
process.env.GITHUB_REPO = 'plutoxqqqq/AetherV2';
process.env.GITHUB_BRANCH = 'release/security';
process.env.AETHER_REGISTRY_BRANCH = 'registry/security';
process.env.PUBLIC_ORIGIN = 'https://aether.example';

const requests = [];
global.fetch = async url => {
  requests.push(String(url));
  return {
    status: 404,
    ok: false,
    headers: {get: () => null},
    json: async () => ({message: 'Not Found'}),
    text: async () => 'Not Found'
  };
};

const proxy = require('./private-source');
const registry = require('./key-registry');

test('registry mutations are isolated from the private-source deployment branch', async () => {
  assert.equal(process.env.GITHUB_BRANCH, 'release/security');
  const loader = proxy.sessionLoader('https://aether.example', 'a'.repeat(64));
  assert.match(loader, /ref=release%2Fsecurity/);

  assert.deepEqual(await registry.listKeys(), []);
  assert.ok(requests.some(url => url.includes('backend/key-bindings.json?ref=registry%2Fsecurity')));
  assert.equal(requests.some(url => url.includes('backend/key-bindings.json?ref=release%2Fsecurity')), false);
});
