--[[

    Used to compile files with a good executor that has proper debug and require capabilities.

]]

for _, v in {isfolder, delfolder, makefolder} do
    assert(v, 'no folder functions :(')
end

assert(writefile, 'no file functions :(')
assert(require, 'no require functions :(')
assert(getscriptbytecode, 'no bytecode function (needed for decompiler to work)')

local cloneref = cloneref or function(obj)
    return obj
end

local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local HttpService = cloneref(game:GetService('HttpService'))
local Players = cloneref(game:GetService('Players'))
local lplr = Players.LocalPlayer

local Definitions, Controllers, Main = {
    DamageTypes = require(ReplicatedStorage.TS.damage["damage-type"]).DamageType,
    MatchStates = require(ReplicatedStorage.TS.match["match-state"]).MatchState,
    ItemMeta = require(ReplicatedStorage.TS.item["item-meta"]).items,
    AnimationType = require(ReplicatedStorage.TS.animation["animation-type"]).AnimationType,
    ProdAnimations = ReplicatedStorage.TS.animation.definitions["prod-animations"],
    ProjectileMeta = require(ReplicatedStorage.TS.projectile["projectile-meta"]).ProjectileMeta,
    TeamUpgradeMeta = debug.getupvalue(require(ReplicatedStorage.TS.games.bedwars["team-upgrade"]["team-upgrade-meta"]).getTeamUpgradeMetaForQueue, 2),
    AppIds = require(lplr.PlayerScripts.TS.ui.types["app-config"]).BedwarsAppIds,
    SummonerKitBalance = require(ReplicatedStorage.TS.games.bedwars.kit.kits.summoner["summoner-kit-balance"]).SummonerKitBalance,
    GameSound = ReplicatedStorage.TS.sound["game-sound"],
    GameSoundMeta = ReplicatedStorage.TS.sound["game-sound-meta"],
    Shop = require(ReplicatedStorage.TS.games.bedwars.shop["bedwars-shop"]).BedwarsShop.ShopItems,
    AudioCategory = require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out.shared.audio["audio-category"])
}, {
    GameQuery = ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out.shared["game-world-query"]["game-query-util"],
    RandomUtil = ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out.shared.util["random-util"],
    ObjectUtil = ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["object-utils"],
    IdUtil = ReplicatedStorage.TS.util["id-util"]
}, {
    Network = lplr.PlayerScripts.TS.lib.network
}

local time = os.time()

local function makefolder(folder)
    print('[BUNDLER]: Making folder: '..folder)
    getgenv().makefolder(folder)
end

local function delfolder(folder)
    print('[BUNDLER]: Deleting folder: '..folder)
    getgenv().delfolder(folder)
end

local function writefile(name, file)
    print('[BUNDLER]: Writing file: '..name..' to compiler')
    getgenv().writefile(name, file)
end

for _, v in {'compiler', 'compiler/definitions', 'compiler/controllers', 'compiler/main'} do
    if not isfolder(v) then
        makefolder(v)
    elseif v ~= 'compiler' then
        delfolder(v)
        makefolder(v)
    end
end

print('[BUNDLER]: Fetching definitions.. (requires a good executor to use require and debug functions, will error if bad!!)')
for i,v in Definitions do
    if i == 'ProdAnimations' or i == 'GameSound' or i == 'GameSoundMeta' then
        writefile('compiler/definitions/'..i..'.lua', decompile(v))
        continue
    end
    
    writefile('compiler/definitions/'..i..'.json', HttpService:JSONEncode(v))
end

print('[BUNDLER]: Fetching controllers..')
for i,v in Controllers do
    writefile('compiler/controllers/'..i..'.lua', decompile(v))
end

print('[BUNDLER]: Fetching main..')
for i,v in Main do
    writefile('compiler/main/'..i..'.lua', decompile(v))
end

print('[BUNDLER]: Completed in: '..(os.time() - time)..' seconds, feel free to star if you\'re using the Dependencies bundler for your script!')