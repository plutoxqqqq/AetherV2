-- AetherV2 BedWars match entry.
-- Keeps the preserved BedWars base reproducible while applying small compatibility/runtime fixes.

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
    local refs = {currentRef(), 'main', ARCHIVE_COMMIT}
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
    local localPath = 'aetherv2/'..path
    local localSuccess, localBody = pcall(readfile, localPath)
    if localSuccess and type(localBody) == 'string' and localBody ~= '' then
        return localBody
    end
    fail('Could not load BedWars source '..path..': '..tostring(lastError))
end

local source = repositoryFile('games/6872274481.base.lua')

local function replaceBetween(startMarker, endMarker, replacement, label)
    local first = source:find(startMarker, 1, true)
    if not first then fail(label..' start marker missing') end
    local last = source:find(endMarker, first + #startMarker, true)
    if not last then fail(label..' end marker missing') end
    source = source:sub(1, first - 1)..replacement..source:sub(last)
end

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

-- Long-bracket strings do not interpret escape sequences. Older rewrite patches therefore
-- passed the literal characters "\\t" as indentation and failed to find the tab-indented
-- BedWars source, stopping startup before DaveyAim could register. Accept both forms so future
-- patches cannot regress on whitespace-only changes.
local function expandWhitespaceEscapes(value)
    local expanded = value:gsub('\\t', '\t')
    expanded = expanded:gsub('\\n', '\n')
    expanded = expanded:gsub('\\r', '\r')
    return expanded
end

local function replaceOnce(marker, replacement, label)
    marker = expandWhitespaceEscapes(marker)
    replacement = expandWhitespaceEscapes(replacement)
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
        for _, ref in {activeRef(), 'main', archiveCommit} do
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
        local localSuccess, localBody = pcall(readfile, 'aetherv2/'..path)
        if localSuccess and type(localBody) == 'string' and localBody ~= '' then
            local chunk, compileError = loadstring(localBody, chunkName)
            if chunk then return chunk end
            lastError = compileError
        end
        return nil, 'download/compile failed: '..tostring(lastError)
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

    -- Trixie is independent from AutoWin/Jade. Never let an unrelated runtime failure hide it.
    task.spawn(function()
        local trixieChunk, trixieError = loadArchived('games/aether/trixie_exploit.lua', 'TrixieExploit')
        if not trixieChunk then
            warn('[AetherV2] TrixieExploit failed to compile: '..tostring(trixieError))
            return
        end
        local trixieLoaded, trixieResult = xpcall(function()
            return trixieChunk(context)
        end, debug and debug.traceback or tostring)
        if not trixieLoaded then
            warn('[AetherV2] TrixieExploit failed to load: '..tostring(trixieResult))
        end
    end)

    local runtimeChunk, runtimeError = loadArchived('games/aether/rewrite.lua', 'AetherMatchRuntime')
    if not runtimeChunk then
        warn('[AetherV2] AutoWin/JIK runtime compile failed: '..tostring(runtimeError))
        notif('AetherV2', 'AutoWin/Jade runtime failed to compile. Check the console.', 8, 'warning')
        return
    end

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
    else
        local patched, patchResult = xpcall(function()
            return patchChunk(AetherMatchRuntime, context)
        end, debug and debug.traceback or tostring)
        if not patched then
            warn('[AetherV2] AutoWin/JIK integration patch failed: '..tostring(patchResult))
        end
    end

    local portsChunk, portsError = loadArchived('games/aether/alsploit_ports.lua', 'AetherBedWarsPorts')
    if not portsChunk then
        warn('[AetherV2] BedWars ports failed to compile: '..tostring(portsError))
        notif('AetherV2', 'BedWars port modules failed to compile. Check the console.', 8, 'warning')
    else
        local portsLoaded, portsResult = xpcall(function()
            return portsChunk(AetherMatchRuntime, context)
        end, debug and debug.traceback or tostring)
        if not portsLoaded then
            warn('[AetherV2] BedWars ports failed to load: '..tostring(portsResult))
            notif('AetherV2', 'BedWars port modules failed to load. Check the console.', 8, 'warning')
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

-- The modern GUI has a Kits window but no Minigames category. Keep Kits for actual kit modules,
-- then point old non-kit Minigames registrations (notably Breaker) at World instead of crashing.
replaceOnce(
    "local kits = vape.Categories.Kits or vape.Categories.Minigames",
    [=[local kits = vape.Categories.Kits or vape.Categories.Minigames
if vape.Categories and not vape.Categories.Minigames then
    vape.Categories.Minigames = vape.Categories.World or vape.Categories.Utility
end]=],
    'legacy Minigames category compatibility'
)

-- AutoEnchant must always have a real visible category even on GUI variants which omit Inventory.
replaceOnce(
    "    AutoEnchant = (vape.Categories.Inventory or vape.Categories.Utility):CreateModule({",
    [=[    local autoEnchantCategory = vape.Categories.Inventory or vape.Categories.Utility or vape.Categories.World
    if not autoEnchantCategory then error('AutoEnchant: no compatible category is available') end
    AutoEnchant = autoEnchantCategory:CreateModule({]=],
    'AutoEnchant category compatibility'
)

-- cv modules read store.ping.total. Supply it from Roblox's RTT API without a polling loop.
replaceOnce(
    "\tmatchState = 0,\n\tqueueType = 'bedwars_test',\n\ttools = {}\n}",
    "\tmatchState = 0,\n\tqueueType = 'bedwars_test',\n\ttools = {},\n\tping = setmetatable({}, {\n\t\t__index = function(_, key)\n\t\t\tif key == 'total' or key == 'incoming' then\n\t\t\t\tlocal success, value = pcall(lplr.GetNetworkPing, lplr)\n\t\t\t\treturn success and math.max(tonumber(value) or 0, 0) or 0\n\t\t\tend\n\t\tend\n\t})\n}",
    'cv ping compatibility'
)

-- Davey launch state is shared with the trajectory corrector. The old Heartbeat poll could see an
-- Air -> Ground flicker before the actual cannon impulse, and could also be overwritten by the
-- trajectory loop one frame later. Arm only after real launch motion and latch the actual landing.
replaceOnce(
[=[\t\treturn aimed
\tend

\tDaveyAim = kits:CreateModule({]=],
[=[\t\treturn aimed
\tend

\tlocal daveyLandingGeneration = 0
\tlocal daveyLanded = false

\tlocal function stopDaveyHorizontal(root)
\t\tif not root or not root.Parent then return end
\t\tlocal velocity = root.AssemblyLinearVelocity
\t\troot.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
\tend

\tlocal function getCannonLaunchSpeed()
\t\tlocal speed = 200
\t\tlocal controller = bedwars.CannonHandController
\t\tif canDebug and debug and type(debug.getconstant) == 'function' and controller and type(controller.launchSelf) == 'function' then
\t\t\tlocal ok, value = pcall(debug.getconstant, controller.launchSelf, 15)
\t\t\tif ok and type(value) == 'number' and value > 0 and value < 1000 then speed = value end
\t\tend
\t\treturn speed
\tend

\tlocal function ensureCannonMovement(cannon, launchDirection)
\t\tlocal generation = daveyLandingGeneration
\t\ttask.spawn(function()
\t\t\tlocal character = entitylib.isAlive and entitylib.character
\t\t\tlocal root = character and character.RootPart
\t\t\tif not root then return end
\t\t\tlocal startPosition = root.Position
\t\t\tlocal direction = launchDirection and launchDirection.Magnitude > 0.001 and launchDirection.Unit or nil
\t\t\tif not direction and cannon and cannon.Parent then
\t\t\t\tlocal look = cannon:GetAttribute('LookVector')
\t\t\t\tdirection = typeof(look) == 'Vector3' and look.Magnitude > 0.001 and look.Unit or cannon.CFrame.LookVector
\t\t\tend
\t\t\tif not direction then return end

\t\t\t-- launchSelf normally supplies this impulse itself. In first person some builds fire the
\t\t\t-- cannon/prompt but skip the local impulse, so only fill it in when no launch motion appears.
\t\t\tfor _ = 1, 3 do
\t\t\t\trunService.PreSimulation:Wait()
\t\t\t\tif generation ~= daveyLandingGeneration or daveyLanded or not root.Parent then return end
\t\t\t\tlocal velocity = root.AssemblyLinearVelocity
\t\t\t\tif velocity:Dot(direction) > 20 or (root.Position - startPosition).Magnitude > 1 then return end
\t\t\tend
\t\t\troot.AssemblyLinearVelocity = direction * getCannonLaunchSpeed()
\t\tend)
\tend

\tlocal function cancelHorizontalOnLanding()
\t\tdaveyLandingGeneration += 1
\t\tlocal generation = daveyLandingGeneration
\t\tdaveyLanded = false
\t\ttask.spawn(function()
\t\t\tlocal character = entitylib.isAlive and entitylib.character
\t\t\tlocal humanoid = character and character.Humanoid
\t\t\tlocal root = character and character.RootPart
\t\t\tif not humanoid or not root then return end

\t\t\tlocal startPosition = root.Position
\t\t\tlocal armed, finished = false, false
\t\t\tlocal floorConnection, stateConnection

\t\t\tlocal function cleanup()
\t\t\t\tif floorConnection then floorConnection:Disconnect(); floorConnection = nil end
\t\t\t\tif stateConnection then stateConnection:Disconnect(); stateConnection = nil end
\t\t\tend

\t\t\tlocal function landed()
\t\t\t\tif finished or generation ~= daveyLandingGeneration then return end
\t\t\t\tfinished = true
\t\t\t\tdaveyLanded = true
\t\t\t\tstopDaveyHorizontal(root)
\t\t\t\tcleanup()
\t\t\t\t-- Clamp the next two physics writes too; the cannon controller can write once more in
\t\t\t\t-- the same contact step after Humanoid reports Landed.
\t\t\t\ttask.spawn(function()
\t\t\t\t\tfor _ = 1, 2 do
\t\t\t\t\t\trunService.PreSimulation:Wait()
\t\t\t\t\t\tif generation ~= daveyLandingGeneration or not root.Parent then return end
\t\t\t\t\t\tstopDaveyHorizontal(root)
\t\t\t\t\tend
\t\t\t\tend)
\t\t\tend

\t\t\tfloorConnection = humanoid:GetPropertyChangedSignal('FloorMaterial'):Connect(function()
\t\t\t\tif armed and humanoid.FloorMaterial ~= Enum.Material.Air then landed() end
\t\t\tend)
\t\t\tstateConnection = humanoid.StateChanged:Connect(function(_, newState)
\t\t\t\tif armed and humanoid.FloorMaterial ~= Enum.Material.Air and (newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics) then
\t\t\t\t\tlanded()
\t\t\t\tend
\t\t\tend)

\t\t\tlocal timeout = tick() + 15
\t\t\trepeat
\t\t\t\trunService.PreSimulation:Wait()
\t\t\t\tif generation ~= daveyLandingGeneration or not entitylib.isAlive or entitylib.character ~= character or not root.Parent then
\t\t\t\t\tcleanup()
\t\t\t\t\treturn
\t\t\t\tend
\t\t\t\tlocal velocity = root.AssemblyLinearVelocity
\t\t\t\tlocal horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
\t\t\t\tif not armed and humanoid.FloorMaterial == Enum.Material.Air and ((root.Position - startPosition).Magnitude > 0.75 or math.abs(velocity.Y) > 8 or horizontal > 20) then
\t\t\t\t\tarmed = true
\t\t\t\tend
\t\t\t\tif armed and humanoid.FloorMaterial ~= Enum.Material.Air then landed() end
\t\t\tuntil finished or tick() >= timeout
\t\t\tcleanup()
\t\tend)
\tend

\tDaveyAim = kits:CreateModule({]=],
    'DaveyAim launch and landing state'
)

replaceOnce(
[=[\t\t\t\tif LaunchCannon.Enabled then
\t\t\t\t\tif Mode.Value == 'Legit' then
\t\t\t\t\t\tcannon.LaunchSelfPrompt:InputHoldBegin()
\t\t\t\t\t\ttask.wait(cannon.LaunchSelfPrompt.HoldDuration + runService.PostSimulation:Wait())
\t\t\t\t\telse
\t\t\t\t\t\tbedwars.CannonHandController:launchSelf(cannon)
\t\t\t\t\tend
\t\t\t\telse]=],
[=[\t\t\t\tif LaunchCannon.Enabled then
\t\t\t\t\tif Mode.Value == 'Legit' then
\t\t\t\t\t\tcannon.LaunchSelfPrompt:InputHoldBegin()
\t\t\t\t\t\ttask.wait(cannon.LaunchSelfPrompt.HoldDuration + runService.PostSimulation:Wait())
\t\t\t\t\telse
\t\t\t\t\t\tbedwars.CannonHandController:launchSelf(cannon)
\t\t\t\t\tend
\t\t\t\t\tcancelHorizontalOnLanding()
\t\t\t\t\tensureCannonMovement(cannon, launchDirection)
\t\t\t\telse]=],
    'DaveyAim automatic launch state'
)

replaceOnce(
[=[\t\t\t\t\tlocal connection = cannon.LaunchSelfPrompt.Triggered:Connect(function(plr)
\t\t\t\t\t\tif plr == lplr then
\t\t\t\t\t\t\tlaunched = true
\t\t\t\t\t\tend
\t\t\t\t\tend)]=],
[=[\t\t\t\t\tlocal connection = cannon.LaunchSelfPrompt.Triggered:Connect(function(plr)
\t\t\t\t\t\tif plr == lplr then
\t\t\t\t\t\t\tlaunched = true
\t\t\t\t\t\t\tcancelHorizontalOnLanding()
\t\t\t\t\t\t\tensureCannonMovement(cannon, launchDirection)
\t\t\t\t\t\tend
\t\t\t\t\tend)]=],
    'DaveyAim manual launch state'
)

-- Once the exact contact watcher has latched a landing, trajectory correction must immediately stop
-- writing horizontal velocity or it will undo the contact-frame clamp.
replaceOnce(
[=[\t\t\t\tlocal landing = tick() + time
\t\t\t\tlocal root
\t\t\t\trepeat
\t\t\t\t\trunService.PreSimulation:Wait()
\t\t\t\t\troot = entitylib.isAlive and entitylib.character.RootPart
\t\t\t\t\tif root then]=],
[=[\t\t\t\tlocal landing = tick() + time
\t\t\t\tlocal root
\t\t\t\trepeat
\t\t\t\t\trunService.PreSimulation:Wait()
\t\t\t\t\troot = entitylib.isAlive and entitylib.character.RootPart
\t\t\t\t\tif daveyLanded then break end
\t\t\t\t\tif root then]=],
    'DaveyAim correction landing gate'
)

replaceOnce(
    "\t\t\t\tuntil not root or tick() > landing",
    "\t\t\t\tuntil not root or tick() > landing or daveyLanded",
    'DaveyAim correction stop condition'
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
if not source:find("vape.Categories.Minigames = vape.Categories.World", 1, true) then fail('legacy category compatibility was not installed') end
if not source:find("autoEnchantCategory", 1, true) then fail('AutoEnchant category compatibility was not installed') end
if not source:find("ensureCannonMovement(cannon, launchDirection)", 1, true) then fail('DaveyAim first-person movement fallback was not installed') end
if not source:find("daveyLanded", 1, true) then fail('DaveyAim landing latch was not installed') end

local compiled, compileError
local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
if cache then compiled = cache[source] end
if not compiled then
    compiled, compileError = loadstring(source, 'games/6872274481.reactive.lua')
    if not compiled then fail('transformed BedWars source did not compile: '..tostring(compileError)) end
    if cache then cache[source] = compiled end
end

return compiled(license)
