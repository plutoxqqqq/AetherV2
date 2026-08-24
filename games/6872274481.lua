-- AetherV2 BedWars match entry.
-- AutoWin V7 / JadeInstaKill V2 and the PR #144 BedWars additions are assembled here from the
-- preserved BedWars base and rewrite helpers in this repository.

local license = ... or {}
if type(license) ~= 'table' then license = {} end

local ARCHIVE_COMMIT = '8c61b6f4cc72f07ee4838ed766e7833196e0f264'

local function fail(message)
    warn('[AetherV2] BedWars rewrite failed: '..tostring(message))
    pcall(function()
        game:GetService('StarterGui'):SetCore('SendNotification', {
            Title = 'AetherV2 BedWars rewrite failed',
            Text = tostring(message),
            Duration = 8
        })
    end)
    error(message, 0)
end

local function currentRef()
    local ok, ref = pcall(readfile, 'aetherv2/profiles/commit.txt')
    if ok and type(ref) == 'string' then
        ref = ref:gsub('%s+', '')
        if ref ~= '' then return ref end
    end
    return 'main'
end

local function repositoryFile(path)
    local lastError
    local refs = {currentRef(), ARCHIVE_COMMIT}
    local seen = {}
    for _, ref in refs do
        if not seen[ref] then
            seen[ref] = true
            local url = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/'..path
            local success, result = pcall(game.HttpGet, game, url, true)
            if success and type(result) == 'string' and result ~= '' and result ~= '404: Not Found' then
                return result
            end
            lastError = result
        end
    end
    fail('Could not load BedWars source '..path..': '..tostring(lastError))
end

-- The full pre-rewrite match source is kept beside this entry so the rewrite is reproducible from
-- the current tree. The historical commit remains only as a compatibility fallback for old caches.
local source = repositoryFile('games/6872274481.base.lua')

local function replaceBetween(startMarker, endMarker, replacement, label)
    local first = source:find(startMarker, 1, true)
    if not first then fail(label..' start marker missing') end
    local last = source:find(endMarker, first + #startMarker, true)
    if not last then fail(label..' end marker missing') end
    source = source:sub(1, first - 1)..replacement..source:sub(last)
end

-- Use semantic needles for sections whose indentation has changed between BedWars snapshots. The
-- old loader searched the whole indented line exactly, so a tabs-vs-spaces cleanup made LongJump
-- fail before any BedWars module could register.
local function replaceBetweenNeedles(startNeedle, endNeedle, replacement, label)
    local startAt = source:find(startNeedle, 1, true)
    if not startAt then fail(label..' start marker missing') end
    local endAt = source:find(endNeedle, startAt + #startNeedle, true)
    if not endAt then fail(label..' end marker missing') end

    local beforeStart = source:sub(1, startAt - 1)
    local startLine = (beforeStart:match('.*()\n') or 0) + 1
    local beforeEnd = source:sub(1, endAt - 1)
    local endLine = (beforeEnd:match('.*()\n') or 0) + 1
    source = source:sub(1, startLine - 1)..replacement..source:sub(endLine)
end

local function replaceOnce(marker, replacement, label)
    local first, last = source:find(marker, 1, true)
    if not first then fail(label..' marker missing') end
    if source:find(marker, last + 1, true) then fail(label..' marker is not unique') end
    source = source:sub(1, first - 1)..replacement..source:sub(last + 1)
end

local runtimeBootstrap = [=[local AetherMatchRuntime
run(function()
    local archiveCommit = '8c61b6f4cc72f07ee4838ed766e7833196e0f264'
    local function activeRef()
        local ok, ref = pcall(readfile, 'aetherv2/profiles/commit.txt')
        if ok and type(ref) == 'string' then
            ref = ref:gsub('%s+', '')
            if ref ~= '' then return ref end
        end
        return 'main'
    end
    local function loadArchived(path, chunkName)
        local lastError
        local seen = {}
        for _, ref in {activeRef(), archiveCommit} do
            if not seen[ref] then
                seen[ref] = true
                local success, result = pcall(game.HttpGet, game,
                    'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/'..path, true)
                if success and type(result) == 'string' and result ~= '' and result ~= '404: Not Found' then
                    local chunk, compileError = loadstring(result, chunkName)
                    if chunk then return chunk end
                    lastError = compileError
                else
                    lastError = result
                end
            end
        end
        return nil, 'download/compile failed: '..tostring(lastError)
    end

    local runtimeChunk, runtimeError = loadArchived('games/aether/rewrite.lua', 'AetherMatchRuntime')
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

    local patchChunk, patchError = loadArchived('games/aether/rewrite_patch.lua', 'AetherMatchRuntimePatch')
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

    local portsChunk, portsError = loadArchived('games/aether/alsploit_ports.lua', 'AetherBedWarsPorts')
    if not portsChunk then
        warn('[AetherV2] BedWars ports failed to compile: '..tostring(portsError))
        notif('AetherV2', 'BedWars port modules failed to compile. Check the console.', 8, 'warning')
        return
    end
    local portsLoaded, portsResult = xpcall(function()
        return portsChunk(AetherMatchRuntime, context)
    end, debug and debug.traceback or tostring)
    if not portsLoaded then
        warn('[AetherV2] BedWars ports failed to load: '..tostring(portsResult))
        notif('AetherV2', 'BedWars port modules failed to load. Check the console.', 8, 'warning')
    end

    local trixieChunk, trixieError = loadArchived('games/aether/trixie_exploit.lua', 'TrixieExploit')
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

-- cv's DaveyAim reads store.ping.total before calling CannonHandController:launchSelf. Aether's
-- store did not provide that field, so the module stopped after aiming. Preserve cv's working
-- controller launch path and provide its missing latency dependency from Roblox's RTT API.
replaceOnce(
    "\tmatchState = 0,\n\tqueueType = 'bedwars_test',\n\ttools = {}\n}",
    "\tmatchState = 0,\n\tqueueType = 'bedwars_test',\n\ttools = {},\n\tping = setmetatable({}, {\n\t\t__index = function(_, key)\n\t\t\tif key == 'total' or key == 'incoming' then\n\t\t\t\tlocal success, value = pcall(lplr.GetNetworkPing, lplr)\n\t\t\t\treturn success and math.max(tonumber(value) or 0, 0) or 0\n\t\t\tend\n\t\tend\n\t})\n}",
    'cv ping compatibility'
)

-- DaveyAim should dump cannon momentum when the player touches down, regardless of whether the
-- launch came from the automatic Legit/Blatant path or from the manual prompt after aiming.
replaceOnce(
[=[		return aimed
	end

	DaveyAim = kits:CreateModule({]=],
[=[		return aimed
	end

	local function cancelHorizontalOnLanding()
		task.spawn(function()
			local character = entitylib.isAlive and entitylib.character
			local humanoid = character and character.Humanoid
			local root = character and character.RootPart
			if not humanoid or not root then return end

			local airborne = false
			local timeout = tick() + 15
			repeat
				runService.Heartbeat:Wait()
				if not entitylib.isAlive or entitylib.character ~= character or not root.Parent then return end

				if humanoid.FloorMaterial == Enum.Material.Air then
					airborne = true
				elseif airborne then
					local velocity = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
					return
				end
			until tick() >= timeout
		end)
	end

	DaveyAim = kits:CreateModule({]=],
    'DaveyAim landing movement helper'
)

replaceOnce(
[=[				if LaunchCannon.Enabled then
					if Mode.Value == 'Legit' then
						cannon.LaunchSelfPrompt:InputHoldBegin()
						task.wait(cannon.LaunchSelfPrompt.HoldDuration + runService.PostSimulation:Wait())
					else
						bedwars.CannonHandController:launchSelf(cannon)
					end
				else]=],
[=[				if LaunchCannon.Enabled then
					if Mode.Value == 'Legit' then
						cannon.LaunchSelfPrompt:InputHoldBegin()
						task.wait(cannon.LaunchSelfPrompt.HoldDuration + runService.PostSimulation:Wait())
						cancelHorizontalOnLanding()
					else
						bedwars.CannonHandController:launchSelf(cannon)
						cancelHorizontalOnLanding()
					end
				else]=],
    'DaveyAim automatic landing stop'
)

replaceOnce(
[=[					local connection = cannon.LaunchSelfPrompt.Triggered:Connect(function(plr)
						if plr == lplr then
							launched = true
						end
					end)]=],
[=[					local connection = cannon.LaunchSelfPrompt.Triggered:Connect(function(plr)
						if plr == lplr then
							launched = true
							cancelHorizontalOnLanding()
						end
					end)]=],
    'DaveyAim manual landing stop'
)

local jadeLongJump = [=[        jadeHammer = function(item, _, dir)
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
                repeat
                    task.wait()
                until not bedwars.AbilityController:canUseAbility(ability) or tick() >= deadline or not LongJump.Enabled
                if not LongJump.Enabled or bedwars.AbilityController:canUseAbility(ability) then return end
                JumpSpeed = 1.4 * Value.Value
                JumpTick = tick() + 2.5
                Direction = Vector3.new(dir.X, 0, dir.Z).Unit
            end
        end,
]=]

if not source:find("jade:ActivateForTraversal('LongJump'", 1, true) then
    replaceBetweenNeedles(
        'jadeHammer = function(item, _, dir)',
        'tnt = function(item, pos, dir)',
        jadeLongJump,
        'LongJump Jade method'
    )
end

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
if not source:find("cancelHorizontalOnLanding()", 1, true) then fail('DaveyAim landing stop was not installed') end

local compiled, compileError
local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
if cache then compiled = cache[source] end
if not compiled then
    compiled, compileError = loadstring(source, 'games/6872274481.reactive.lua')
    if not compiled then fail('transformed BedWars source did not compile: '..tostring(compileError)) end
    if cache then cache[source] = compiled end
end

return compiled(license)
