'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GITHUB_TOKEN = 'test-token';
process.env.GITHUB_REPO = 'plutoxqqqq/AetherV2';
process.env.GITHUB_BRANCH = 'release/security';
process.env.AETHER_RETRY_BASE_MS = '0';
process.env.AETHER_GITHUB_RETRIES = '2';
process.env.AETHER_GITHUB_CONFLICT_RETRIES = '4';

const empty = () => ({version: 3, keys: {}, bindings: {}, audit: []});
let stored;
let shaCounter;
let conflictWrites;
let readFailures;
let requests;

const response = (status, value) => ({
  status,
  ok: status >= 200 && status < 300,
  headers: {get: () => null},
  json: async () => value,
  text: async () => JSON.stringify(value)
});

global.fetch = async (url, options = {}) => {
  requests.push({url: String(url), options});
  if (options.method === 'PUT') {
    if (conflictWrites > 0) {
      conflictWrites -= 1;
      return response(409, {message: 'conflict'});
    }
    const body = JSON.parse(options.body);
    assert.equal(body.branch, 'release/security');
    stored = Buffer.from(body.content, 'base64').toString('utf8');
    shaCounter += 1;
    return response(200, {sha: 'sha-' + shaCounter});
  }
  if (readFailures.length) return response(readFailures.shift(), {message: 'temporary failure'});
  if (stored === null) return response(404, {message: 'Not Found'});
  return response(200, {sha: 'sha-' + shaCounter, content: Buffer.from(stored).toString('base64')});
};

const registry = require('./key-registry');

test.beforeEach(() => {
  stored = JSON.stringify(empty());
  shaCounter = 1;
  conflictWrites = 0;
  readFailures = [];
  requests = [];
});

test('raw keys are never stored and every successful authorization increments usage', async () => {
  const created = await registry.createKey({label: 'Tester', actor: 'owner'});
  assert.equal(created.key.length, 64);
  assert.equal(stored.includes(created.key), false);

  const first = await registry.bindKey(created.keyId, {username: 'Alpha_User', userId: '111'});
  const second = await registry.bindKey(created.keyId, {username: 'alpha_user', userId: '111'});
  assert.equal(first.firstUse, true);
  assert.equal(second.firstUse, false);
  assert.equal((await registry.getKeyInfo(created.keyId)).uses, 2);

  await assert.rejects(
    registry.bindKey(created.keyId, {username: 'Different_User', userId: '222'}),
    error => error.status === 403
  );
  const actions = (await registry.getAudit(20)).map(event => event.action);
  assert.ok(actions.includes('bind'));
  assert.ok(actions.includes('use'));
});

test('expiry invalidates a key, enable refuses it, and renew reactivates it', async () => {
  const created = await registry.createKey({expiresAt: '2099-01-01T00:00:00.000Z', actor: 'owner'});
  await registry.editKey({id: created.keyId, expiresAt: '2000-01-01T00:00:00.000Z', actor: 'owner'});
  assert.equal(await registry.isValidKey(created.key), false);
  await assert.rejects(registry.enableKey({id: created.keyId, actor: 'owner'}), error => error.status === 409 && /renew/i.test(error.message));

  const renewed = await registry.renewKey({id: created.keyId, expiresAt: '2099-02-01T00:00:00.000Z', actor: 'owner'});
  assert.equal(renewed.record.enabled, true);
  assert.equal(renewed.record.expiresAt, '2099-02-01T00:00:00.000Z');
  assert.equal(await registry.isValidKey(created.key), true);
  assert.ok((await registry.getAudit(20)).some(event => event.action === 'renew'));
});

test('revoke and enable create distinct audit actions', async () => {
  const created = await registry.createKey({actor: 'owner'});
  await registry.revokeKey({id: created.keyId, actor: 'owner'});
  assert.equal(await registry.isValidKey(created.key), false);
  await registry.enableKey({id: created.keyId, actor: 'owner'});
  assert.equal(await registry.isValidKey(created.key), true);
  const actions = (await registry.getAudit(20)).map(event => event.action);
  assert.ok(actions.includes('revoke'));
  assert.ok(actions.includes('enable'));
});

test('rotation of an expired key creates an active replacement and transfers binding safely', async () => {
  const created = await registry.createKey({expiresAt: '2099-01-01T00:00:00.000Z', actor: 'owner'});
  await registry.bindKey(created.keyId, {username: 'Bound_User', userId: '333'});
  await registry.editKey({id: created.keyId, expiresAt: '2000-01-01T00:00:00.000Z', actor: 'owner'});

  const rotated = await registry.rotateKey({id: created.keyId, actor: 'owner'});
  assert.equal(rotated.record.enabled, true);
  assert.equal(rotated.record.expiresAt, null);
  assert.equal(rotated.binding.username, 'Bound_User');
  assert.equal(rotated.binding.uses, 0);
  assert.equal(await registry.isValidKey(created.key), false);
  assert.equal((await registry.resolveKey(rotated.key)).keyId, rotated.keyId);
  assert.equal(stored.includes(rotated.key), false);
  assert.equal((await registry.getKeyInfo(created.keyId)).binding, null);
  assert.ok((await registry.getAudit(20)).some(event => event.action === 'rotate'));
});

test('complete registry validation rejects malformed nested structures', async t => {
  const badRegistries = [
    {version: 3, keys: [], bindings: {}, audit: []},
    {version: 3, keys: {}, bindings: {['a'.repeat(64)]: {username: 'User_1', userId: '1', firstUsedAt: new Date().toISOString(), uses: 1}}, audit: []},
    {version: 3, keys: {['b'.repeat(64)]: {label: 'x', source: 'discord', createdAt: null, createdBy: 'owner', enabled: true, expiresAt: null, rawKey: 'secret'}}, bindings: {}, audit: []},
    {version: 3, keys: {}, bindings: {}, audit: [{at: 'invalid', action: 'generate', keyId: null, actor: 'owner'}]},
    {version: 3, keys: {}, bindings: {}, audit: [{at: new Date().toISOString(), action: 'edit', keyId: null, actor: 'owner', changes: {rawKey: 'secret'}}]},
    {version: 3, keys: {['b'.repeat(64)]: {label: 'x', source: 'discord', createdAt: null, createdBy: 'owner', enabled: false, expiresAt: null, rotatedTo: 'c'.repeat(64)}}, bindings: {}, audit: []},
    {version: 3, keys: {}, bindings: {}, audit: [{at: new Date().toISOString(), action: 'generate', keyId: 'd'.repeat(64), actor: 'owner'}]}
  ];
  for (const value of badRegistries) {
    await t.test(JSON.stringify(value).slice(0, 80), async () => {
      stored = JSON.stringify(value);
      await assert.rejects(registry.listKeys(), error => error.status === 502);
    });
  }
});

test('GitHub reads retry transient failures and configured branch is always used', async () => {
  readFailures = [500, 502];
  assert.deepEqual(await registry.listKeys(), []);
  assert.equal(requests.filter(request => request.url.includes('?ref=release%2Fsecurity')).length, 3);
});

test('GitHub write conflicts retry idempotently without duplicate keys or audit events', async () => {
  conflictWrites = 1;
  const created = await registry.createKey({label: 'Conflict test', actor: 'owner'});
  const data = JSON.parse(stored);
  assert.deepEqual(Object.keys(data.keys), [created.keyId]);
  assert.equal(data.audit.filter(event => event.action === 'generate').length, 1);
  assert.equal(stored.includes(created.key), false);
});

test('filters match key status, username, label, and source', async () => {
  const first = await registry.createKey({label: 'Alpha customer', actor: 'owner'});
  await registry.bindKey(first.keyId, {username: 'Filter_User', userId: '555'});
  await registry.createKey({label: 'Beta customer', actor: 'owner'});
  assert.equal((await registry.listKeys({username: 'filter'})).length, 1);
  assert.equal((await registry.listKeys({label: 'beta'})).length, 1);
  assert.equal((await registry.listKeys({source: 'discord', status: 'active'})).length, 2);
});
