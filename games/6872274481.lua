-- AutoWin V7 / JadeInstaKill V2 match bootstrap.
--
-- The pre-rewrite BedWars match source is retained at games/6872274481.base.lua so the connector
-- can reuse its existing Git blob instead of serialising ~1.4 MB through a contents update. This
-- bootstrap removes the legacy AutoWin/JIK blocks before they are compiled, injects the shared
-- reactive runtime, loads the Aether-native ports from games/aether, and redirects LongJump's Jade
-- path to the same JadeAbilityAdapter.

local license = ... or {}
if type(license) ~= 'table' then license = {} end

local function fail(message)
    warn('[AetherV2] BedWars rewrite bootstrap failed: '..tostring(message))
    pcall(function()
        game:GetService('StarterGui'):SetCore('SendNotification', {
            Title = 'AetherV2 BedWars rewrite failed',
            Text = tostring(message),
            Duration = 8
        })
    end)
    error(message, 0)
end

local commit
local ok, err = pcall(function()
    commit = readfile('aetherv2/profiles/commit.txt')
end)
if not ok or type(commit) ~= 'string' or commit == '' then
    fail('Could not resolve the active Aether commit: '..tostring(err))
end

local function raw(path)
    local url = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/'..path
    local success, result = pcall(game.HttpGet, game, url, true)
    if not success or type(result) ~= 'string' or result == '' or result == '404: Not Found' then
        fail('Could not load '..path..': '..tostring(result))
    end
    return result
end

local source = raw('games/6872274481.base.lua')

local function replaceBetween(startMarker, endMarker, replacement, label)
    local first = source:find(startMarker, 1, true)
    if not first then fail(label..' start marker missing') end
    local last = source:find(endMarker, first + #startMarker, true)
    if not last then fail(label..' end marker missing') end
    source = source:sub(1, first - 1)..replacement..source:sub(last)
end

local function replaceOnce(marker, replacement, label)
    local first, last = source:find(marker, 1, true)
    if not first then fail(label..' marker missing') end
    if source:find(marker, last + 1, true) then fail(label..' marker is not unique') end
    source = source:sub(1, first - 1)..replacement..source:sub(last + 1)
end

local runtimeBootstrap = [=[local AetherMatchRuntime
run(function()
    -- AutoWin V7 and JadeInstaKill V2 share one live BedWars capability/runtime layer.
    local runtimeSource = downloadFile('aetherv2/games/aether/rewrite.lua')
    local runtimeChunk, runtimeError = loadstring(runtimeSource, 'games/aether/rewrite')
    if not runtimeChunk then
        warn('[AetherV2] AutoWin/JIK runtime compile failed: '..tostring(runtimeError))
        notif('AetherV2', 'AutoWin/Jade runtime failed to compile. Check the console.', 8, 'warning')
        return
    end

    local context = {
        vape = vape,
        vapeEvents = vapeEvents,
        entitylib = entitylib,
        bedwars = bedwars,
        store = store,
        lplr = lplr,
        playersService = playersService,
        runService = runService,
        collectionService = collectionService,
        replicatedStorage = replicatedStorage,
        httpService = httpService,
        guiService = guiService,
        coreGui = coreGui,
        gameCamera = gameCamera,
        inputService = inputService,
        remotes = remotes,
        sortmethods = sortmethods,
        breakmethods = breakmethods,
        frictionTable = frictionTable,
        updateVelocity = updateVelocity,
        getItem = getItem,
        getWool = getWool,
        getBestArmor = getBestArmor,
        getPlacedBlock = getPlacedBlock,
        switchItem = switchItem,
        isnetworkowner = isnetworkowner,
        notif = notif,
        placeBlock = bedwars.placeBlock,
        breakBlock = bedwars.breakBlock,
        debug = debug,
        Knit = Knit,
        canDebug = canDebug
    }

    local loaded, result = xpcall(function()
        return runtimeChunk(context)
    end, debug and debug.traceback or tostring)
    if not loaded or type(result) ~= 'table' then
        warn('[AetherV2] AutoWin/JIK runtime failed: '..tostring(result))
        notif('AetherV2', 'AutoWin/Jade runtime failed to start. Check the console.', 8, 'warning')
        return
    end
    AetherMatchRuntime = result

    local patchSource = downloadFile('aetherv2/games/aether/rewrite_patch.lua')
    local patchChunk, patchError = loadstring(patchSource, 'games/aether/rewrite_patch')
    if not patchChunk then
        warn('[AetherV2] AutoWin/JIK integration patch compile failed: '..tostring(patchError))
        return
    end
    local patched, patchResult = xpcall(function()
        return patchChunk(AetherMatchRuntime, context)
    end, debug and debug.traceback or tostring)
    if not patched then
        warn('[AetherV2] AutoWin/JIK integration patch failed: '..tostring(patchResult))
    end

    local portsSource = downloadFile('aetherv2/games/aether/alsploit_ports.lua')
    local portsChunk, portsError = loadstring(portsSource, 'games/aether/alsploit_ports')
    if not portsChunk then
        warn('[AetherV2] AlSploit ports failed to compile: '..tostring(portsError))
        notif('AetherV2', 'BedWars port modules failed to compile. Check the console.', 8, 'warning')
        return
    end
    local portsLoaded, portsResult = xpcall(function()
        return portsChunk(AetherMatchRuntime, context)
    end, debug and debug.traceback or tostring)
    if not portsLoaded then
        warn('[AetherV2] AlSploit ports failed to load: '..tostring(portsResult))
        notif('AetherV2', 'BedWars port modules failed to load. Check the console.', 8, 'warning')
    end

    local trixieSource = downloadFile('aetherv2/games/aether/trixie_exploit.lua')
    local trixieChunk, trixieError = loadstring(trixieSource, 'games/aether/trixie_exploit')
    if not trixieChunk then
        warn('[AetherV2] TrixieExploit failed to compile: '..tostring(trixieError))
    else
        local trixieLoaded, trixieResult = xpcall(function()
            return trixieChunk(context)
        end, debug and debug.traceback or tostring)
        if not trixieLoaded then
            warn('[AetherV2] TrixieExploit failed to load: '..tostring(trixieResult))
        end
    end
end)

]=]

replaceBetween(
    "run(function()\n    ----------------------------------------------------------------------------------------------\n    -- AutoWin (v6) - the unattended match brain.",
    "\nrun(function()\n    -- EntityAnalyser",
    runtimeBootstrap,
    'AutoWin v6'
)

replaceBetween(
    "-- Jade hammer execution has two strategies. TP performs the stock slam while following a\n-- moving target; Spoof keeps the server-side damage-scaling payload and never moves the character.\nrun(function()",
    "\nrun(function()\n    local Value\n    local CameraDir\n    local LimitItems",
    "-- JadeInstaKill V2 is registered by AetherMatchRuntime above.\n",
    'JadeInstaKill legacy'
)

-- Several modules imported from cv expect store.ping.total to exist. cv owns a separate RTT sampler,
-- while Aether did not create store.ping at all; DaveyAim therefore errored after aiming and before
-- CannonHandController:launchSelf() was reached. Keep cv's proven launch flow and provide the missing
-- compatibility surface from Roblox's native round-trip ping instead of probing a gameplay remote.
replaceOnce(
    "\tmatchState = 0,\n\tqueueType = 'bedwars_test',\n\ttools = {}\n}",
    "\tmatchState = 0,\n\tqueueType = 'bedwars_test',\n\ttools = {},\n\tping = setmetatable({}, {\n\t\t__index = function(_, key)\n\t\t\tif key == 'total' or key == 'incoming' then\n\t\t\t\tlocal success, value = pcall(lplr.GetNetworkPing, lplr)\n\t\t\t\treturn success and math.max(tonumber(value) or 0, 0) or 0\n\t\t\tend\n\t\tend\n\t})\n}",
    'cv ping compatibility'
)

local jadeLongJump = [=[        jadeHammer = function(item, _, dir)
            -- LongJump and JadeInstaKill share one Jade resolver/equip/readiness/activation path.
            local jade = AetherMatchRuntime and AetherMatchRuntime.Jade
            if jade then
                local result = jade:ActivateForTraversal('LongJump', dir, function()
                    return not LongJump.Enabled
                end)
                if not result.confirmed or not LongJump.Enabled then return end
                JumpSpeed = 1.4 * Value.Value
                JumpTick = tick() + 2.5
                Direction = Vector3.new(dir.X, 0, dir.Z).Unit
                return
            end

            -- If the optional runtime failed to load, preserve the old controller path rather than
            -- breaking LongJump entirely. This is compatibility only; normal runs use the adapter.
            local ability = getJadeAbility(item)
            if not bedwars.AbilityController:canUseAbility(ability) then
                repeat
                    task.wait()
                    ability = getJadeAbility(item)
                until bedwars.AbilityController:canUseAbility(ability) or not LongJump.Enabled
            end
            if bedwars.AbilityController:canUseAbility(ability) and LongJump.Enabled then
                if not activateJadeTool(item) then bedwars.AbilityController:useAbility(ability) end
                local deadline = tick() + 0.75
                repeat task.wait() until not bedwars.AbilityController:canUseAbility(ability) or tick() >= deadline or not LongJump.Enabled
                if not LongJump.Enabled or bedwars.AbilityController:canUseAbility(ability) then return end
                JumpSpeed = 1.4 * Value.Value
                JumpTick = tick() + 2.5
                Direction = Vector3.new(dir.X, 0, dir.Z).Unit
            end
        end,
]=]

replaceBetween(
    "        jadeHammer = function(item, _, dir)\n",
    "        tnt = function(item, pos, dir)\n",
    jadeLongJump,
    'LongJump Jade method'
)

-- Acceptance checks happen before the transformed match source is compiled, so a BedWars update
-- that changes one of the expected boundaries fails loudly instead of executing a half-rewritten
-- mix of old and new state machines.
local forbidden = {
    '-- AutoWin (v6) - the unattended match brain.',
    'Spoof keeps the server-side damage-scaling payload',
    'AetherJadeCameraLock',
    'AetherJadeTargetFollow'
}
for _, token in ipairs(forbidden) do
    if source:find(token, 1, true) then fail('stale rewrite token remains: '..token) end
end
if not source:find("jade:ActivateForTraversal('LongJump'", 1, true) then fail('LongJump Jade adapter was not installed') end
if not source:find("ping = setmetatable({}, {", 1, true) then fail('cv ping compatibility was not installed') end
if not source:find("bedwars.CannonHandController:launchSelf(cannon)", 1, true) then fail('DaveyAim cv cannon launch path is missing') end
if not source:find('aetherv2/games/aether/rewrite.lua', 1, true) then fail('reactive runtime bootstrap was not installed') end
if not source:find('aetherv2/games/aether/alsploit_ports.lua', 1, true) then fail('BedWars port bootstrap was not installed') end
if not source:find('aetherv2/games/aether/trixie_exploit.lua', 1, true) then fail('TrixieExploit bootstrap was not installed') end

local compiled, compileError
local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
if cache then compiled = cache[source] end
if not compiled then
    compiled, compileError = loadstring(source, 'games/6872274481.reactive.lua')
    if not compiled then fail('transformed BedWars source did not compile: '..tostring(compileError)) end
    if cache then cache[source] = compiled end
end

return compiled(license)
