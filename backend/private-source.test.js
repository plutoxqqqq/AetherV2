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

test('session loader preserves and encodes the configured branch at runtime', () => {
  const source = proxy.sessionLoader('https://source.example.test', 'b'.repeat(64));
  assert.match(source, /local ref = "release\/security"/);
  assert.match(source, /&ref="\.\.encode\(ref\)/);
  assert.doesNotMatch(source, /ref=main/);
});

test('key mutation invalidation removes every existing source session', () => {
  const first = proxy.createSession(binding);
  const second = proxy.createSession(binding);
  assert.equal(proxy.requireSession(first).keyId, id);
  assert.equal(proxy.invalidateSessionsForKey(id), 2);
  assert.throws(() => proxy.requireSession(second), error => error.status === 401 && /missing or expired/.test(error.message));
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

test('large source files fall back to Git blobs when Contents API omits content', async () => {
  const originalFetch = global.fetch;
  const blobSha = 'b'.repeat(40);
  const calls = [];
  global.fetch = async url => {
    const requestUrl = String(url);
    calls.push(requestUrl);
    if (requestUrl.includes('/contents/games/6872274481.lua?ref=release%2Fsecurity')) {
      return {
        status: 200,
        ok: true,
        json: async () => ({
          type: 'file',
          size: 1049949,
          sha: blobSha,
          encoding: 'none',
          content: ''
        })
      };
    }
    if (requestUrl.includes('/git/blobs/' + blobSha)) {
      return {
        status: 200,
        ok: true,
        json: async () => ({
          encoding: 'base64',
          content: Buffer.from('return "large"\n').toString('base64')
        })
      };
    }
    return {status: 404, ok: false, json: async () => ({message: 'unexpected request'})};
  };

  try {
    assert.equal(await proxy.sourceFile('games/6872274481.lua', 'release/security'), 'return "large"\n');
    assert.equal(calls.length, 2);
    assert.ok(calls[1].includes('/git/blobs/' + blobSha));
  } finally {
    global.fetch = originalFetch;
  }
});

test('GitHub failures are surfaced without serving stale source', async () => {
  await assert.rejects(proxy.sourceFile('init.lua', 'release/security'), error => error.status === 502);
});
