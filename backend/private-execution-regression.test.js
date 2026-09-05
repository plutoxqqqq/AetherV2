'use strict';

const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const sourceServer = fs.readFileSync(path.join(__dirname, 'private-source-core.js'), 'utf8');
const sourceWrapper = fs.readFileSync(path.join(__dirname, 'private-source.js'), 'utf8');
const main = fs.readFileSync(path.join(__dirname, '..', 'main.lua'), 'utf8');
const mainWrapper = main;
const init = fs.readFileSync(path.join(__dirname, '..', 'init.lua'), 'utf8');
const initWrapper = init;
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

function readLuaTree(root) {
  const chunks = [];
  if (!fs.existsSync(root)) return '';
  const stat = fs.statSync(root);
  if (stat.isFile()) return root.endsWith('.lua') ? fs.readFileSync(root, 'utf8') : '';
  for (const entry of fs.readdirSync(root, {withFileTypes: true})) {
    const full = path.join(root, entry.name);
    if (entry.isDirectory()) chunks.push(readLuaTree(full));
    else if (entry.isFile() && entry.name.endsWith('.lua')) chunks.push(fs.readFileSync(full, 'utf8'));
  }
  return chunks.join('\n');
}

test('premium sessions are separate from the public AetherV2 source path', () => {
  assert.match(sourceServer, /PREMIUM_GITHUB_REPO/);
  assert.match(sourceServer, /const premiumSessionLoader/);
  assert.match(sourceServer, /url\.pathname === '\/premium\/authorize'/);
  assert.match(sourceServer, /url\.pathname === '\/premium\/source'/);
  assert.match(sourceServer, /premiumSourceFile/);
  assert.match(sourceWrapper, /require\('\.\/private-source-core'\)/);
});

test('public AetherV2 always uses raw GitHub while premium remains session-gated', () => {
  assert.match(main, /raw\.githubusercontent\.com\/plutoxqqqq\/AetherV2/);
  assert.doesNotMatch(main, /SourceEndpoint|SourceToken|privateSourceUrl/);
  assert.match(init, /pcall\(authorizePremium\)/);
  assert.match(main, /local function loadPremiumModules/);
});

test('split wrappers keep analytics heartbeat and premium tagging isolated', () => {
  assert.match(initWrapper, /event\s*=\s*eventName\s*or\s*'heartbeat'|sendTelemetry\(sessionId,\s*'heartbeat'\)/);
  assert.match(initWrapper, /sendTelemetry\(sessionId,\s*'session_end'\)/);
  assert.match(initWrapper, /sessionId/);
  assert.match(initWrapper, /AetherV2PremiumAuthorized/);
  assert.match(mainWrapper, /premiumModuleSnapshot/);
});

test('premium discovery loads every universal and place category without requiring files', () => {
  assert.match(main, /collectModules\('games\/universal\//);
  assert.match(main, /collectModules\('games\/'.*placeId/);
  assert.match(main, /CategoryApi = categoryApi/);
  assert.match(main, /for index, module in ipairs\(modules\) do/);
  assert.match(sourceServer, /url\.pathname === '\/premium\/tree'/);
  assert.match(sourceServer, /defaultPremiumAllowedPaths = \['games\/'\]/);
});

test('restored execution keeps exact PlaceId dispatch', () => {
  assert.match(main, /local requestedPlace = tostring\(game\.PlaceId\)/);
  assert.match(main, /local modulePlace = requestedPlace/);
  assert.match(main, /local repoPlacePath = 'games\/'\.\.modulePlace\.\.'\.lua'/);
  assert.equal(main.includes('game.GameId'), false);
});

test('premium source requests revalidate live key state and Roblox binding', () => {
  assert.match(sourceServer, /const requireSession = async value =>/);
  assert.match(sourceServer, /registry\.getKeyInfo\(session\.keyId\)/);
  assert.match(sourceServer, /info\.status !== 'active'/);
  assert.match(sourceServer, /binding\.username\.toLowerCase\(\) !== session\.username\.toLowerCase\(\)/);
  assert.match(sourceServer, /String\(binding\.userId\) !== session\.userId/);
  assert.match(sourceServer, /revoked, expired, rotated, or unlinked/);
});

test('Render serves premium only and retired normal-source routes stay removed', () => {
  for (const route of ['/loader', '/authorize', '/source', '/commit', '/history', '/tree']) {
    assert.equal(sourceServer.includes("url.pathname === '" + route + "'"), false, `retired route still present: ${route}`);
  }
  assert.match(sourceServer, /url\.pathname === '\/premium\/authorize'/);
  assert.match(sourceServer, /url\.pathname === '\/premium\/source'/);
  assert.match(sourceServer, /url\.pathname === '\/premium\/tree'/);
  assert.match(sourceServer, /premiumGithub\('contents\/'/);
  assert.match(sourceServer, /premiumGithub\('git\/trees\/'/);
  assert.doesNotMatch(sourceServer, /requestedLimit = 11|git\/blobs\//);
});

test('numeric game caches must contain executable source', () => {
  for (const loader of [init, main]) {
    assert.match(loader, /local function sourceHasCode\(path, source\)/);
    assert.match(loader, /numeric game module contains no executable code/);
    assert.match(loader, /cachedProblem/);
  }
});

test('public loader heals stale refs and publishes the current source tree', () => {
  assert.match(init, /shared\.AetherV2PublicRef = commit/);
  assert.match(init, /fetchFileList\(shared\.AetherV2PublicRef or 'main'\)/);
  assert.match(init, /verifySelectedAssets\(prefetchPaths\)/);
  assert.doesNotMatch(init, /selectedReleaseChannel|releasechannel\.txt/);
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

test('the split BedWars module baseline cannot silently disappear again', () => {
  const games = path.join(__dirname, '..', 'games');
  const bedwars = readLuaTree(path.join(games, '6872274481.lua'));
  const registered = new Set();
  for (const match of bedwars.matchAll(/:CreateModule\s*\(\s*\{[\s\S]{0,500}?\bName\s*=\s*['"]([^'"]+)['"]/g)) registered.add(match[1]);
  for (const match of bedwars.matchAll(/\bregister\s*\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]/g)) registered.add(match[2]);
  assert.ok(registered.size >= 100, `expected a substantial BedWars module set, found ${registered.size}`);
  for (const name of ['AutoBuy', 'AutoConsume', 'AutoFish', 'AutoHotbar', 'AutoSteal', 'FastConsume', 'FastDrop', 'OpenShop', 'LongJump', 'Killaura', 'Scaffold', 'Speed']) {
    assert.ok(registered.has(name), `missing BedWars module ${name}`);
  }
});
