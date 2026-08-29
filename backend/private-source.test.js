'use strict';

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
