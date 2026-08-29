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

test('premium sessions are separate from the public AetherV2 source path', () => {
  assert.match(sourceServer, /PREMIUM_GITHUB_REPO/);
  assert.match(sourceServer, /const premiumSessionLoader/);
  assert.match(sourceServer, /url\.pathname === '\/premium\/authorize'/);
  assert.match(sourceServer, /url\.pathname === '\/premium\/source'/);
  assert.match(sourceServer, /premiumSourceFile/);
});

test('public AetherV2 always uses raw GitHub while premium remains session-gated', () => {
  assert.match(main, /raw\.githubusercontent\.com\/plutoxqqqq\/AetherV2/);
  assert.doesNotMatch(main, /SourceEndpoint|SourceToken|privateSourceUrl/);
  assert.match(init, /pcall\(authorizePremium\)/);
  assert.match(main, /local function loadPremiumModules/);
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

test('the complete BedWars module baseline cannot silently disappear again', () => {
  const bedwars = fs.readFileSync(path.join(__dirname, '..', 'games', '6872274481.lua'), 'utf8');
  const registered = new Set();
  for (const match of bedwars.matchAll(/:CreateModule\s*\(\s*\{[\s\S]{0,500}?\bName\s*=\s*['"]([^'"]+)['"]/g)) {
    registered.add(match[1]);
  }
  for (const match of bedwars.matchAll(/\bregister\s*\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]/g)) {
    registered.add(match[2]);
  }

  const expected = [
  "ACMODView",
  "AimAssist",
  "Anti-AFK",
  "AntiDeath",
  "AntiHitBETA",
  "AntiLasso",
  "AntiSuffocate",
  "AntiVoid",
  "ArmorHighlight",
  "ArmorSwitch",
  "ArmorTrims",
  "Aura",
  "AutoAdetunde",
  "AutoAgni",
  "AutoBalloon",
  "AutoBank",
  "AutoBeekeeper",
  "AutoBountyHunter",
  "AutoBuildUp",
  "AutoBuilder",
  "AutoBuy",
  "AutoCaitlyn",
  "AutoCard",
  "AutoChargeProj",
  "AutoClicker",
  "AutoConsume",
  "AutoCounter",
  "AutoCrocowolf",
  "AutoCyber",
  "AutoDavey",
  "AutoDragonSword",
  "AutoDrill",
  "AutoElder",
  "AutoEldric",
  "AutoEmber",
  "AutoEnchant",
  "AutoEquipKit",
  "AutoEvelynn",
  "AutoFarmer",
  "AutoFarmerCletus",
  "AutoFish",
  "AutoFreiya",
  "AutoGingerbreadMan",
  "AutoGrim",
  "AutoGrove",
  "AutoHannah",
  "AutoHephaestus",
  "AutoHonor",
  "AutoHotbar",
  "AutoKaida",
  "AutoKaliyah",
  "AutoKit",
  "AutoKrystal",
  "AutoLani",
  "AutoLasso",
  "AutoLumen",
  "AutoMarina",
  "AutoMartin",
  "AutoMelody",
  "AutoMetal",
  "AutoMushroom",
  "AutoNahila",
  "AutoNazar",
  "AutoNoelle",
  "AutoNyx",
  "AutoPearl",
  "AutoPickpocket",
  "AutoPlay",
  "AutoPyro",
  "AutoRagnar",
  "AutoRamil",
  "AutoRelease",
  "AutoSheepHerder",
  "AutoShielderUlt",
  "AutoShoot",
  "AutoSilas",
  "AutoSmoke",
  "AutoSophia",
  "AutoStarCollector",
  "AutoSteal",
  "AutoSuffocate",
  "AutoTaliyah",
  "AutoTool",
  "AutoToxic",
  "AutoTriton",
  "AutoUma",
  "AutoVanessa",
  "AutoVoidDrop",
  "AutoVoidHunter",
  "AutoVoidKnight",
  "AutoWarden",
  "AutoWhim",
  "AutoWhisper",
  "AutoWin",
  "AutoXurot",
  "AutoYeti",
  "AutoZeno",
  "AutoZola",
  "BackTrack",
  "BalloonDisabler",
  "BedAlarm",
  "BedAssist",
  "BedBreakEffect",
  "BedESP",
  "BedPlates",
  "BedProtector",
  "BeehiveESP",
  "BlockIn",
  "BlockSelectorColor",
  "BoostAirJump",
  "BowAssist",
  "Breaker",
  "CannonSpeed",
  "ChatNameColor",
  "ChatPosition",
  "CheatDetector",
  "ChillLighting",
  "ClaimRewards",
  "CleanKit",
  "Crosshair",
  "CryptAura",
  "CustomCursor",
  "CustomTags",
  "DamageBoost",
  "DamageIndicator",
  "DaveyAim",
  "DeathAdderAimbot",
  "DeviceSpoofer",
  "EntityAnalyser",
  "EquipKit",
  "FOV",
  "FPSBoost",
  "FakeLag",
  "FalconAura",
  "FastBreak",
  "FastConsume",
  "FastDrop",
  "FastPlace",
  "FishermanSpy",
  "Fly",
  "GeneratorESP",
  "GrimReaperFix",
  "Headless",
  "Health",
  "HitBoxes",
  "HitColor",
  "HitFix",
  "HitregAdjuster",
  "IgnorePlaceHitboxes",
  "InstantKill",
  "Interface",
  "InvisibleCursor",
  "ItemESP",
  "JadeExploit",
  "JadeExtender",
  "JadeInstaKill",
  "KeepSprint",
  "KillEffect",
  "Killaura",
  "KillfeedSpoofer",
  "KitDisplay",
  "KitESP",
  "KnockbackDelay",
  "KrystalDisabler",
  "LeaveParty",
  "LegacyAnimation",
  "Legless",
  "LongJump",
  "LongJumpBypass",
  "LootESP",
  "MP3Player",
  "MissileTP",
  "MotionBlur",
  "MultiAction",
  "NameTagSpoofer",
  "NameTags",
  "NightmareEmote",
  "NoClickDelay",
  "NoFallDamage",
  "NoFallDamageV2",
  "NoSlowdown",
  "OG4v4v4v4",
  "OpenShop",
  "OwlAura",
  "PickupRange",
  "PlayerAttach",
  "PlayerOutline",
  "PotatoMode",
  "PotionStatus",
  "ProjectileAimbot",
  "ProjectileAura",
  "ProjectileDodger",
  "ProjectileLanding",
  "ProjectileTracers",
  "RavenTP",
  "Reach",
  "ReachDisplay",
  "ReaperBypass",
  "RecoveryTP",
  "RemoveNeon",
  "RemovePlayerLevelUI",
  "Scaffold",
  "Schematica",
  "ShadowRemover",
  "ShopClicker",
  "SilentAim",
  "SilentAura",
  "SkinChanger",
  "SongBeats",
  "SoundChanger",
  "Speed",
  "Spider",
  "Sprint",
  "StaffDetector",
  "StorageESP",
  "StreamRemover",
  "TPAura",
  "TerraAimbot",
  "TexturePack",
  "TransparentCharacter",
  "TrapDisabler",
  "TrapESP",
  "TriggerBot",
  "TritonClutch",
  "UICleanup",
  "Velocity",
  "Viewmodel",
  "ViewmodelVisuals",
  "VoidRegentAutoClutch",
  "VoidRegentExtender",
  "VulcanAssist",
  "Water",
  "WhiteHits",
  "WinEffect",
  "YaminiExploit",
  "YaminiExtender",
  "YuziExtender"
  ];
  assert.ok(registered.size >= expected.length, `expected at least ${expected.length} BedWars modules, found ${registered.size}`);
  assert.deepEqual(expected.filter(name => !registered.has(name)), []);
  for (const name of ['AutoBuy', 'AutoConsume', 'AutoFish', 'AutoHotbar', 'AutoSteal', 'FastConsume', 'FastDrop', 'OpenShop', 'LongJump']) {
    assert.ok(registered.has(name), `missing restored module ${name}`);
  }
});

