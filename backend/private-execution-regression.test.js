'use strict';

const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const sourceServer = fs.readFileSync(path.join(__dirname, 'private-source.js'), 'utf8');
const main = fs.readFileSync(path.join(__dirname, '..', 'main.lua'), 'utf8');
const init = fs.readFileSync(path.join(__dirname, '..', 'init.lua'), 'utf8');
const aliases = [
  ['8444591321', '6872274481'],
  ['8560631822', '6872274481'],
  ['13246639586', '8768229691'],
  ['8542259458', '8768229691'],
  ['8542275097', '8768229691'],
  ['8592115909', '8768229691'],
  ['8951451142', '8768229691'],
  ['123804558118054', '5938036553'],
  ['131465939650733', '5938036553'],
  ['135564683255158', '155615604'],
  ['80041634734121', '77790193039862']
];

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
  assert.match(main, /local requestedPlace = tostring\(game\.PlaceId\)/);
  assert.match(main, /local modulePlace = requestedPlace/);
  assert.match(main, /local repoPlacePath = 'games\/'\.\.modulePlace\.\.'\.lua'/);
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

test('numeric game caches must contain executable source', () => {
  for (const loader of [init, main]) {
    assert.match(loader, /local function sourceHasCode\(path, source\)/);
    assert.match(loader, /numeric game module contains no executable code/);
    assert.match(loader, /cachedProblem/);
  }
});

test('the first authorized run publishes the exact source tree to main', () => {
  assert.match(init, /prefetchPaths = fetchFileList\(initialRef\)/);
  assert.match(init, /shared\.AetherV2KnownSourceFiles = prefetchPaths/);
  assert.match(main, /knownFiles\[repoPlacePath\] ~= nil/);
});

test('known compatible game modules cannot silently fall back to Universal', () => {
  assert.match(main, /shared\.AetherGameLoadTrace = gameLoadTrace/);
  assert.match(main, /Supported game module .* could not be downloaded/);
  assert.match(main, /runWatchedChunk\(placeSource, modulePlace, 'Loading module for this game', 75, false, license\)/);
  assert.match(main, /executed but registered no game modules/);
  assert.match(main, /traceGameLoad\('loaded'/);
});

test('all compatible child places forward through the authenticated session', () => {
  for (const [place, target] of aliases) {
    const source = fs.readFileSync(path.join(__dirname, '..', 'games', place + '.lua'), 'utf8');
    assert.match(source, new RegExp('local targetPlace = ' + target));
    assert.match(source, /shared\.AetherV2FetchSource/);
    assert.match(source, /pcall\(fetch, path\)/);
    assert.doesNotMatch(source, /pcall\(fetch, path, 3\)/);
    assert.match(source, /return chunk\(license\)/);
    assert.doesNotMatch(source, /raw\.githubusercontent\.com/);
  }
});
