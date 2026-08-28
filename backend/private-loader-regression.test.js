'use strict';

const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const initSource = fs.readFileSync(path.join(__dirname, '..', 'init.lua'), 'utf8');
const proxyWrapper = fs.readFileSync(path.join(__dirname, 'private-source.js'), 'utf8');
const bedwarsRuntime = fs.readFileSync(path.join(__dirname, '..', 'libraries', 'bedwars', 'runtime.lua'), 'utf8');

test('private bootstrap never calls the AetherV2 GitHub repository directly', () => {
  assert.equal(initSource.includes('raw.githubusercontent.com/plutoxqqqq/AetherV2'), false);
  assert.equal(initSource.includes('api.github.com/repos/plutoxqqqq/AetherV2'), false);
  assert.equal(initSource.includes('github.com/plutoxqqqq/AetherV2'), false);
  assert.match(initSource, /Private source endpoint is missing/);
});

test('exact PlaceId game source is manifest-driven and staged before main', () => {
  assert.match(initSource, /local modulePlace = tostring\(game\.PlaceId\)/);
  assert.match(initSource, /local gameRepoPath = 'games\/'\.\.modulePlace\.\.'\.lua'/);
  assert.match(initSource, /local gameExists = manifest\[gameRepoPath\] ~= nil/);
  assert.match(initSource, /if gameExists then table\.insert\(required, gameRepoPath\) end/);
  assert.match(initSource, /Could not stage /);
  assert.match(initSource, /writefile\('aetherv2\/profiles\/commit\.txt', commit\)/);
});

test('BedWars startup stages large dependencies before the watched game chunk', () => {
  assert.match(initSource, /profiles\/packages\.json/);
  assert.match(initSource, /libraries\/bedwars\/runtime\.lua/);
  assert.match(initSource, /AetherBedwarsRuntimeReady/);
  assert.match(initSource, /AetherBedwarsFallbackReady/);
  assert.match(initSource, /120, false, license/);
  assert.match(initSource, /BedWars game file ran but its runtime did not initialize/);
});

test('BedWars compatibility runtime isolates dependency failures', () => {
  assert.match(bedwarsRuntime, /local function assign\(name, resolver\)/);
  assert.match(bedwarsRuntime, /RuntimeErrors/);
  assert.match(bedwarsRuntime, /assign\('Client'/);
  assert.match(bedwarsRuntime, /assign\('Store'/);
  assert.match(bedwarsRuntime, /assign\('ItemMeta'/);
  assert.match(bedwarsRuntime, /bedwars\.Handler/);
});

test('source wrapper prevents registry-read amplification during startup bursts', () => {
  assert.match(proxyWrapper, /activeStatusCache/);
  assert.match(proxyWrapper, /AETHER_KEY_STATUS_CACHE_MS/);
  assert.match(proxyWrapper, /activeStatusCache\.clear\(\)/);
  assert.match(proxyWrapper, /AETHER_RATE_LIMIT = '600'/);
});
