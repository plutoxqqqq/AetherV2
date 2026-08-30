'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GITHUB_TOKEN = 'test-token';
process.env.GITHUB_REPO = 'plutoxqqqq/AetherV2';
process.env.PREMIUM_GITHUB_REPO = 'plutoxqqqq/AetherV2Premium';
process.env.PREMIUM_GITHUB_BRANCH = 'main';
process.env.AETHER_REGISTRY_BRANCH = 'aether-key-registry';

const cloud = require('./cloud-configs');

const configRecord = overrides => ({
  id: '11111111-1111-4111-8111-111111111111',
  ownerKeyId: 'a'.repeat(64),
  ownerUsername: 'ExampleUser',
  ownerUserId: '12345',
  name: 'Main Config',
  placeId: '6872274481',
  payload: JSON.stringify({Modules: {}, Legit: {}}),
  createdAt: '2026-08-30T03:00:00.000Z',
  updatedAt: '2026-08-30T03:05:00.000Z',
  backup: null,
  shareCode: null,
  copy: null,
  ...(overrides || {})
});

test('cloud config policy is capped at five configs per premium key', () => {
  assert.equal(cloud.MAX_CONFIGS_PER_KEY, 5);
});

test('cloud payload validation accepts Aether JSON objects only', () => {
  const payload = JSON.stringify({Modules: {KillAura: {Enabled: true}}});
  assert.equal(cloud.validatePayload(payload), payload);
  assert.throws(() => cloud.validatePayload('not-json'), /valid Aether JSON/i);
  assert.throws(() => cloud.validatePayload('[]'), /Aether config object/i);
  assert.throws(() => cloud.validatePayload(''), /required/i);
});

test('share codes use the short XXXX-XXXX format', () => {
  assert.equal(cloud.validShareCode('JE97-2H96'), true);
  assert.equal(cloud.validShareCode('JE972H96'), false);
  assert.equal(cloud.validShareCode('je97-2h96'), false);
  assert.equal(cloud.validShareCode('AAAA-1111'), false);
});

test('store validation rejects inconsistent share indexes', () => {
  const record = configRecord({shareCode: 'JE97-2H96'});
  const valid = {version: 1, configs: {[record.id]: record}, shares: {'JE97-2H96': record.id}};
  assert.equal(cloud.validateStore(valid), valid);
  assert.throws(() => cloud.validateStore({version: 1, configs: {[record.id]: record}, shares: {}}), /missing from the index/i);
});

test('public metadata never exposes owner IDs, key IDs, payloads, or backup contents', () => {
  const metadata = cloud.publicMetadata(configRecord({
    backup: {payload: JSON.stringify({old: true}), savedAt: '2026-08-30T03:01:00.000Z'}
  }));
  assert.equal(metadata.name, 'Main Config');
  assert.equal(metadata.hasBackup, true);
  assert.equal(Object.hasOwn(metadata, 'ownerKeyId'), false);
  assert.equal(Object.hasOwn(metadata, 'ownerUserId'), false);
  assert.equal(Object.hasOwn(metadata, 'payload'), false);
  assert.equal(Object.hasOwn(metadata, 'backup'), false);
});

test('copy metadata can reference a share code without granting ownership', () => {
  const record = configRecord({
    copy: {
      sourceCode: 'JE97-2H96',
      syncEnabled: true,
      sourceUpdatedAt: '2026-08-30T03:04:00.000Z'
    }
  });
  const store = {version: 1, configs: {[record.id]: record}, shares: {}};
  assert.equal(cloud.validateStore(store), store);
  const metadata = cloud.publicMetadata(record);
  assert.equal(metadata.isCopy, true);
  assert.equal(metadata.syncEnabled, true);
  assert.equal(Object.hasOwn(metadata, 'sourceCode'), false);
});
