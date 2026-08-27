'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GITHUB_TOKEN = 'test-token';
process.env.GITHUB_REPO = 'plutoxqqqq/AetherV2';
process.env.GITHUB_BRANCH = 'release/security';
process.env.PUBLIC_ORIGIN = 'https://source.example.test';
process.env.AETHER_ALLOWED_REFS = 'release/security,release/candidate';
process.env.AETHER_MAX_SESSIONS_PER_KEY = '2';
process.env.AETHER_RETRY_BASE_MS = '0';
process.env.AETHER_GITHUB_RETRIES = '0';

global.fetch = async () => ({status: 500, ok: false, json: async () => ({message: 'failure'})});

const registry = require('./key-registry');
const proxy = require('./private-source');
const id = 'a'.repeat(64);
const binding = {id, binding: {username: 'Session_User', userId: '123'}};

test.beforeEach(() => {
  proxy.sessions.clear();
  registry.isKeyIdActive = async () => true;
});

test('session loader uses the configured branch instead of ref=main', () => {
  const source = proxy.sessionLoader('https://source.example.test', 'b'.repeat(64));
  assert.match(source, /ref=release%2Fsecurity/);
  assert.match(source, /SourceRef = "release\/security"/);
  assert.doesNotMatch(source, /ref=main/);
});

test('revoked key IDs immediately invalidate every existing source session', async () => {
  const first = proxy.createSession(binding);
  const second = proxy.createSession(binding);
  assert.equal((await proxy.requireSession(first)).keyId, id);
  registry.isKeyIdActive = async () => false;
  await assert.rejects(proxy.requireSession(second), error => error.status === 401 && /revoked or expired/.test(error.message));
  assert.equal(proxy.sessions.size, 0);
});

test('per-key session limit evicts the oldest session', () => {
  const first = proxy.createSession(binding);
  proxy.createSession(binding);
  proxy.createSession(binding);
  assert.equal(proxy.sessions.size, 2);
  assert.equal(proxy.sessions.has(first), false);
});

test('source refs and paths are restricted to configured allowlists', () => {
  assert.equal(proxy.validRef('release/security'), true);
  assert.equal(proxy.validRef('main'), false);
  assert.equal(proxy.clientPath('games/universal.lua'), true);
  assert.equal(proxy.clientPath('backend/key-bindings.json'), false);
  assert.equal(proxy.clientPath('.github/workflows/deploy.yml'), false);
  assert.equal(proxy.clientPath('games/../backend/key-bindings.json'), false);
  assert.equal(proxy.treePath('games'), true);
});

test('commit SHAs are approved only for the session that resolved them', () => {
  const commit = 'c'.repeat(40);
  const first = {approvedRefs: new Set([commit])};
  const second = {approvedRefs: new Set()};
  assert.equal(proxy.sessionAllowsRef(first, commit), true);
  assert.equal(proxy.sessionAllowsRef(second, commit), false);
  assert.equal(proxy.sessionAllowsRef(first, 'd'.repeat(40)), false);
  assert.equal(proxy.sessionAllowsRef(second, 'release/security'), true);
});

test('GitHub failures are surfaced without serving stale source', async () => {
  await assert.rejects(proxy.sourceFile('init.lua', 'release/security'), error => error.status === 502);
});
