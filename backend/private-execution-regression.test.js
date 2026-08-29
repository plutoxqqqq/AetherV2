'use strict';

const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const sourceServer = fs.readFileSync(path.join(__dirname, 'private-source.js'), 'utf8');
const main = fs.readFileSync(path.join(__dirname, '..', 'main.lua'), 'utf8');

test('each authorized loader session owns fresh immutable-ref approval state', () => {
  assert.match(sourceServer, /shared\.AetherResolvedCommit = nil/);
  assert.match(sourceServer, /SourceEndpoint = endpoint/);
  assert.match(sourceServer, /SourceToken = session/);
  assert.match(sourceServer, /SourceRef = ref/);
});

test('game and GUI helpers inherit the authenticated private source transport', () => {
  assert.match(sourceServer, /shared\.AetherV2FetchSource = function/);
  assert.match(main, /shared\.AetherV2FetchSource = function/);
  assert.match(main, /shared\.AetherV2FetchSource\(path, ref\)/);
  assert.equal(main.includes('raw.githubusercontent.com/plutoxqqqq/AetherV2'), false);
});

test('restored execution keeps exact PlaceId dispatch', () => {
  assert.match(main, /local modulePlace = tostring\(game\.PlaceId\)/);
  assert.match(main, /local placePath = 'aetherv2\/games\/'\.\.modulePlace\.\.'\.lua'/);
  assert.equal(main.includes('game.GameId'), false);
});

test('authenticated source requests use the in-memory session instead of rereading the registry', () => {
  const requireSessionBody = sourceServer.match(/const requireSession = url => \{([\s\S]*?)\n\};/);
  assert.ok(requireSessionBody);
  assert.equal(requireSessionBody[1].includes('isKeyIdActive'), false);
  assert.match(sourceServer, /invalidateMutation\('revokeKey'/);
  assert.match(sourceServer, /invalidateMutation\('unlinkKey'/);
  assert.match(sourceServer, /invalidateMutation\('rotateKey'/);
});

test('private source still supports large BedWars files and bounded downgrade history', () => {
  assert.match(sourceServer, /git\/blobs\//);
  assert.match(sourceServer, /url\.pathname === '\/history'/);
  assert.match(sourceServer, /requestedLimit = 11/);
});
