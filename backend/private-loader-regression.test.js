'use strict';

const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const initSource = read('init.lua');
const mainSource = read('main.lua');

const aliases = [
  ['games/8444591321.lua', '6872274481'],
  ['games/8560631822.lua', '6872274481'],
  ['games/13246639586.lua', '8768229691'],
  ['games/8542259458.lua', '8768229691'],
  ['games/8542275097.lua', '8768229691'],
  ['games/8592115909.lua', '8768229691'],
  ['games/8951451142.lua', '8768229691'],
  ['games/123804558118054.lua', '5938036553'],
  ['games/131465939650733.lua', '5938036553'],
  ['games/135564683255158.lua', '155615604'],
  ['games/80041634734121.lua', '77790193039862']
];

test('restored init owns the loading screen and asset prefetch', () => {
  assert.match(initSource, /local function createLoadingScreen\(\)/);
  assert.match(initSource, /prefetch\(prefetchPaths\)/);
  assert.match(initSource, /aetherv2\/assets\/new\/loading\.png/);
  assert.match(initSource, /return mainChunk\(license\)/);
});

test('main still dispatches the exact PlaceId after universal', () => {
  assert.match(mainSource, /games\/universal\.lua/);
  assert.match(mainSource, /local modulePlace = tostring\(game\.PlaceId\)/);
  assert.match(mainSource, /'aetherv2\/games\/'\.\.modulePlace\.\.'\.lua'/);
});

test('all child-place forwarders use the authenticated private source path', () => {
  for (const [file, target] of aliases) {
    const source = read(file);
    assert.match(source, new RegExp('targetPlace = ' + target));
    assert.match(source, /shared\.AetherV2FetchSource/);
    assert.match(source, /return chunk\(license\)/);
    assert.equal(source.includes('raw.githubusercontent.com/plutoxqqqq/AetherV2'), false, file);
    assert.equal(source.includes('api.github.com/repos/plutoxqqqq/AetherV2'), false, file);
  }
});
