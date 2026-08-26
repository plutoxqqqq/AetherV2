'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GITHUB_TOKEN = 'test-token';
process.env.GITHUB_REPO = 'plutoxqqqq/AetherV2';
process.env.GITHUB_BRANCH = 'main';
process.env.AETHER_KEYS = '';

let stored = null;
let shaCounter = 0;

const response = (status, value) => ({
  status,
  ok: status >= 200 && status < 300,
  json: async () => value,
  text: async () => JSON.stringify(value)
});

global.fetch = async (url, options = {}) => {
  if (options.method === 'PUT') {
    const body = JSON.parse(options.body);
    stored = Buffer.from(body.content, 'base64').toString('utf8');
    shaCounter += 1;
    return response(200, {sha: 'sha-' + shaCounter});
  }
  if (!stored) return response(404, {message: 'Not Found'});
  return response(200, {
    sha: 'sha-' + shaCounter,
    content: Buffer.from(stored).toString('base64')
  });
};

const registry = require('./key-registry');

test('dynamic key lifecycle never stores the raw key', async () => {
  const created = await registry.createKey({label: 'Test', actor: 'test-owner'});
  assert.equal(typeof created.key, 'string');
  assert.equal(created.key.length, 64);
  assert.equal(stored.includes(created.key), false);
  assert.equal((await registry.resolveKey(created.key)).keyId, created.keyId);
  assert.equal((await registry.getKeyInfo(created.keyId.slice(0, 12))).keyId, created.keyId);

  const first = await registry.bindKey(created.keyId, {
    username: 'Alpha_User',
    userId: '111'
  });
  assert.equal(first.firstUse, true);

  const same = await registry.bindKey(created.keyId, {
    username: 'alpha_user',
    userId: '111'
  });
  assert.equal(same.firstUse, false);

  await assert.rejects(
    registry.bindKey(created.keyId, {username: 'Different_User', userId: '222'}),
    error => error.status === 403
  );

  await registry.unlinkKey({id: created.keyId, actor: 'test-owner'});
  await registry.bindKey(created.keyId, {
    username: 'Different_User',
    userId: '222'
  });

  await registry.revokeKey({id: created.keyId, actor: 'test-owner'});
  assert.equal(await registry.isValidKey(created.key), false);

  await registry.enableKey({id: created.keyId, actor: 'test-owner'});
  assert.equal(await registry.isValidKey(created.key), true);
});
