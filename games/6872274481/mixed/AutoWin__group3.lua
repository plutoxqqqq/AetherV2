run(function()
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
		Knit = bedwars.Knit,
		kits = kits,
        canDebug = canDebug
    }

    ----------------------------------------------------------------------------------------------
    -- TrixieExploit (direct implementation)
    ----------------------------------------------------------------------------------------------
-- TrixieExploit
--
-- Trixie's stock Rift Warp is documented as a 9-block movement. BedWars uses 3 studs per block,
-- so current builds commonly expose the client-side range as 27 studs. We deliberately discover
-- the live Trixie/Rift function instead of hardcoding a controller/remote name; if the client no
-- longer owns this calculation, the module fails closed and leaves the ability untouched.

local function registerTrixie(context)
    local vape = context and context.vape
    local lplr = context and context.lplr
    local Knit = context and context.Knit
    local canDebug = context and context.canDebug
    local dbg = context and context.debug
    local notif = context and context.notif

    local function notify(message)
        if type(notif) == 'function' then
            pcall(notif, 'TrixieExploit', message, 6, 'warning')
        else
            warn('[AetherV2] TrixieExploit: '..tostring(message))
        end
    end

    if not vape then
        warn('[AetherV2] TrixieExploit: vape unavailable during registration')
        return
    end

    -- The live match file already resolves the selected kit category (Kits on modern GUIs,
    -- Minigames on older ones). The former deferred registrar only retried Categories.Kits,
    -- silently omitting this module for the latter.
    local kits = context and context.kits
    if not kits then
        kits = vape.Categories and (vape.Categories.Kits or vape.Categories.Minigames)
    end

    if not (kits and type(kits.CreateModule) == 'function') then
        warn('[AetherV2] TrixieExploit: active kit category is unavailable')
        notify('The active kit category is unavailable; TrixieExploit could not be registered.')
        return
    end

    -- Protect against reloads/re-entry of the direct BedWars match file.
    if vape.Modules and vape.Modules.TrixieExploit then
        return vape.Modules.TrixieExploit
    end

    local TrixieExploit, Distance
    local patched = {}

    local function currentKit()
        if not lplr then return '' end
        return tostring(lplr:GetAttribute('PlayingAsKits') or lplr:GetAttribute('PlayingAsKit') or ''):lower()
    end

    local function isTrixie()
        return currentKit():find('trixie', 1, true) ~= nil
    end

    local function restore()
        if not (dbg and type(dbg.setconstant) == 'function') then
            table.clear(patched)
            return
        end

        for i = #patched, 1, -1 do
            local record = patched[i]
            pcall(dbg.setconstant, record.fn, record.index, record.original)
        end
        table.clear(patched)
    end

    local function inspectFunction(fn, label, seenFunctions, studCandidates, blockCandidates)
        if type(fn) ~= 'function' or seenFunctions[fn] then return end
        seenFunctions[fn] = true

        local ok, constants = pcall(dbg.getconstants, fn)
        if not ok or type(constants) ~= 'table' then return end

        local loweredLabel = tostring(label):lower()
        local marked = loweredLabel:find('trixie', 1, true) ~= nil or loweredLabel:find('rift', 1, true) ~= nil
        if not marked then
            for _, constant in ipairs(constants) do
                if type(constant) == 'string' then
                    local lowered = constant:lower()
                    if lowered:find('trixie', 1, true) or lowered:find('rift', 1, true) then
                        marked = true
                        break
                    end
                end
            end
        end

        if marked then
            for index, constant in ipairs(constants) do
                if type(constant) == 'number' then
                    if math.abs(constant - 27) < 0.001 then
                        table.insert(studCandidates, {fn = fn, index = index, original = constant, label = label})
                    elseif math.abs(constant - 9) < 0.001 then
                        table.insert(blockCandidates, {fn = fn, index = index, original = constant, label = label})
                    end
                end
            end
        end

        if type(dbg.getprotos) == 'function' then
            local protoOk, protos = pcall(dbg.getprotos, fn)
            if protoOk and type(protos) == 'table' then
                for index, proto in ipairs(protos) do
                    inspectFunction(proto, tostring(label)..'.proto'..index, seenFunctions, studCandidates, blockCandidates)
                end
            end
        end
    end

    local function inspectContainer(container, label, seenContainers, seenFunctions, studCandidates, blockCandidates)
        if type(container) ~= 'table' or seenContainers[container] then return end
        seenContainers[container] = true

        for memberName, member in pairs(container) do
            if type(member) == 'function' then
                inspectFunction(member, tostring(label)..'.'..tostring(memberName), seenFunctions, studCandidates, blockCandidates)
            end
        end

        -- TypeScript/Knit class methods can live on the instance metatable rather than as direct
        -- table members, so inspect both the metatable and its __index table when present.
        local mt = getmetatable(container)
        if type(mt) == 'table' then
            for memberName, member in pairs(mt) do
                if type(member) == 'function' then
                    inspectFunction(member, tostring(label)..'.metatable.'..tostring(memberName), seenFunctions, studCandidates, blockCandidates)
                end
            end
            if type(mt.__index) == 'table' then
                inspectContainer(mt.__index, tostring(label)..'.__index', seenContainers, seenFunctions, studCandidates, blockCandidates)
            end
        end
    end

    local function discover()
        local studCandidates, blockCandidates = {}, {}
        local seenFunctions, seenContainers = {}, {}
        local controllers = Knit and Knit.Controllers
        if type(controllers) ~= 'table' then return studCandidates, blockCandidates end

        for controllerName, controller in pairs(controllers) do
            inspectContainer(controller, controllerName, seenContainers, seenFunctions, studCandidates, blockCandidates)
        end

        return studCandidates, blockCandidates
    end

    local function reportFailure(message)
        notify(message)
        return false
    end

    local function apply()
        restore()

        if not (TrixieExploit and TrixieExploit.Enabled) then return false end
        if not isTrixie() then
            return reportFailure('Equip Trixie before using this module.')
        end
        if not (canDebug and dbg and type(dbg.getconstants) == 'function' and type(dbg.setconstant) == 'function') then
            return reportFailure('Your executor cannot patch the Rift Warp range calculation.')
        end

        local studCandidates, blockCandidates = discover()
        -- Prefer the 27-stud representation. Only fall back to a 9-block constant when no
        -- Trixie/Rift function exposes 27, which avoids touching unrelated duration constants.
        local candidates = #studCandidates > 0 and studCandidates or blockCandidates
        if #candidates == 0 then
            return reportFailure('No live Rift Warp range constant was found; BedWars may now validate it server-side.')
        end

        local desiredBlocks = Distance.Value
        for _, record in ipairs(candidates) do
            local replacement = math.abs(record.original - 27) < 0.001 and desiredBlocks * 3 or desiredBlocks
            local ok = pcall(dbg.setconstant, record.fn, record.index, replacement)
            if ok then
                table.insert(patched, record)
            end
        end

        if #patched == 0 then
            return reportFailure('Rift Warp was found but its range could not be patched.')
        end

        return true
    end

    local created, moduleOrError = pcall(kits.CreateModule, kits, {
        Name = 'TrixieExploit',
        Function = function(enabled)
            if enabled then
                task.defer(apply)
            else
                restore()
            end
        end,
        Tooltip = 'Extends Trixie Rift Warp by patching its live client range calculation. Server validation can still clamp unsupported distances.'
    })

    if not created or not moduleOrError then
        warn('[AetherV2] TrixieExploit registration failed: '..tostring(moduleOrError))
        notify('TrixieExploit failed to register. Check the developer console.')
        return
    end
    TrixieExploit = moduleOrError

    Distance = TrixieExploit:CreateSlider({
        Name = 'Warp distance',
        Min = 9,
        Max = 30,
        Default = 18,
        Suffix = ' blocks',
        Function = function()
            if TrixieExploit.Enabled then task.defer(apply) end
        end
    })

    TrixieExploit:Clean(function()
        restore()
    end)

    return TrixieExploit
end

    local trixieLoaded, trixieResult = xpcall(function()
        return registerTrixie(context)
    end, debug and debug.traceback or tostring)
    if not trixieLoaded then warn('[AetherV2] TrixieExploit failed to load: '..tostring(trixieResult)) end

    ----------------------------------------------------------------------------------------------
    -- AutoWin/Jade reactive runtime (direct implementation)
    ----------------------------------------------------------------------------------------------
local function registerAetherRuntime(context)
-- AetherV2 BedWars reactive runtime
-- Compiled directly in games/6872274481.lua with the live match-file context.
-- The dependency dump in libraries/bedwars is a reference only; this runtime deliberately
-- distinguishes live controllers/replicated state from compatibility fallbacks.

local ctx = context
assert(type(ctx) == 'table', 'Aether BedWars runtime requires context')

local vape = assert(ctx.vape, 'missing vape')
local vapeEvents = ctx.vapeEvents
local entitylib = assert(ctx.entitylib, 'missing entitylib')
local bedwars = assert(ctx.bedwars, 'missing bedwars')
local store = assert(ctx.store, 'missing store')
local lplr = assert(ctx.lplr, 'missing local player')
local playersService = assert(ctx.playersService, 'missing Players')
local runService = assert(ctx.runService, 'missing RunService')
local collectionService = assert(ctx.collectionService, 'missing CollectionService')
local replicatedStorage = assert(ctx.replicatedStorage, 'missing ReplicatedStorage')
local httpService = assert(ctx.httpService, 'missing HttpService')
local guiService = ctx.guiService
local coreGui = ctx.coreGui
local gameCamera = ctx.gameCamera or workspace.CurrentCamera
local inputService = ctx.inputService
local remotes = ctx.remotes or {}
local sortmethods = ctx.sortmethods or {}
local breakmethods = ctx.breakmethods or {}
local frictionTable = ctx.frictionTable or {}
local updateVelocity = ctx.updateVelocity or function() end
local getItem = assert(ctx.getItem, 'missing getItem')
local getWool = ctx.getWool
local getBestArmor = ctx.getBestArmor
local getPlacedBlock = assert(ctx.getPlacedBlock, 'missing getPlacedBlock')
local switchItem = assert(ctx.switchItem, 'missing switchItem')
local isnetworkowner = ctx.isnetworkowner or function() return true end
local notif = ctx.notif or function() end
local safePlaceBlock = ctx.placeBlock or bedwars.placeBlock
local safeBreakBlock = ctx.breakBlock or bedwars.breakBlock

local Runtime = {Version = 7, Errors = {}, Context = ctx}

local function now()
    return tick()
end

local function safe(label, fn, ...)
    if type(fn) ~= 'function' then return false, 'missing function' end
    local ok, result = pcall(fn, ...)
    if not ok then
        Runtime.Errors[label] = {At = now(), Error = tostring(result)}
        return false, result
    end
    return true, result
end

local function ask(label, fn, ...)
    local ok, result = safe(label, fn, ...)
    return ok and result or nil
end

local function moduleByName(name)
    if vape.Modules and vape.Modules[name] then return vape.Modules[name] end
    for _, panel in {vape.Kits, vape.Legit} do
        if panel and panel.Modules and panel.Modules[name] then return panel.Modules[name] end
    end
end

local function rootOfLocal()
    local char = entitylib.character
    if entitylib.isAlive and char and char.RootPart and char.RootPart.Parent then
        return char.RootPart, char, char.Humanoid
    end
end

local function partOf(object)
    if not object then return nil end
    if object:IsA('BasePart') then return object end
    return object.PrimaryPart or object:FindFirstChildWhichIsA('BasePart')
end

local function itemCount(name)
    local item = ask('inventory.getItem.'..tostring(name), getItem, name)
    return item and item.amount or 0
end

local function copyTable(source)
    local out = {}
    for key, value in pairs(source or {}) do out[key] = value end
    return out
end

--------------------------------------------------------------------------------
-- BedWars capability layer
--------------------------------------------------------------------------------
local Capabilities = {
    Match = {}, Metadata = {}, Inventory = {}, Blocks = {}, Abilities = {}, Kits = {}, Shop = {}, Queue = {}, Network = {},
    Status = {},
    Source = {LIVE = 'live', CONTROLLER = 'controller', REPLICATED = 'replicated', METADATA = 'metadata', FALLBACK = 'fallback', UNKNOWN = 'unknown'}
}
Runtime.BedWarsAPI = Capabilities

local referenceStates = {PRE = 0, RUNNING = 1, POST = 2}
Capabilities.Match.States = {
    PRE = (bedwars.MatchStates and bedwars.MatchStates.PRE) or referenceStates.PRE,
    RUNNING = (bedwars.MatchStates and bedwars.MatchStates.RUNNING) or referenceStates.RUNNING,
    POST = (bedwars.MatchStates and bedwars.MatchStates.POST) or referenceStates.POST
}

function Capabilities.Match:GetState()
    local state = store.matchState
    if type(state) == 'number' then return state, self.Source or Capabilities.Source.REPLICATED end
    local live = ask('match.store', function() return bedwars.Store:getState().Game.matchState end)
    if type(live) == 'number' then return live, Capabilities.Source.CONTROLLER end
    return Capabilities.Match.States.PRE, Capabilities.Source.FALLBACK
end

function Capabilities.Match:GetTeam()
    local team = lplr:GetAttribute('Team')
    if team ~= nil then return team, Capabilities.Source.REPLICATED end
    local value = ask('match.team', function() return bedwars.Store:getState().Game.myTeam end)
    if type(value) == 'table' then value = value.id end
    if value ~= nil then return value, Capabilities.Source.CONTROLLER end
    local char = lplr.Character
    value = char and char:GetAttribute('Team') or nil
    return value, value ~= nil and Capabilities.Source.REPLICATED or Capabilities.Source.UNKNOWN
end

function Capabilities.Metadata:GetItem(itemType)
    local meta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
    return meta, meta and Capabilities.Source.LIVE or Capabilities.Source.UNKNOWN
end

function Capabilities.Inventory:Get()
    local inv = store.inventory and store.inventory.inventory
    if type(inv) == 'table' then return inv, Capabilities.Source.REPLICATED end
    return {items = {}, armor = {}}, Capabilities.Source.UNKNOWN
end

function Capabilities.Inventory:GetHeld()
    return store.hand, store.hand and Capabilities.Source.REPLICATED or Capabilities.Source.UNKNOWN
end

function Capabilities.Shop:GetItem(itemType, shopId)
    if not bedwars.Shop or type(bedwars.Shop.getShopItem) ~= 'function' then return nil, Capabilities.Source.UNKNOWN end
    local item = ask('shop.item.'..tostring(itemType), function()
        return bedwars.Shop.getShopItem(itemType, lplr, shopId and {shopId = shopId} or nil)
    end)
    return item, item and Capabilities.Source.LIVE or Capabilities.Source.UNKNOWN
end

function Capabilities.Queue:GetMeta()
    return bedwars.QueueMeta or {}, bedwars.QueueMeta and Capabilities.Source.LIVE or Capabilities.Source.UNKNOWN
end

function Capabilities.Kits:GetEquipped()
    local kit = store.equippedKit
    if kit == nil or kit == '' then kit = lplr:GetAttribute('PlayingAsKit') or lplr:GetAttribute('PlayingAsKits') end
    return kit, kit and Capabilities.Source.REPLICATED or Capabilities.Source.UNKNOWN
end

function Capabilities.Blocks:Get(position)
    return ask('blocks.get', getPlacedBlock, position)
end

function Capabilities.Blocks:Place(position, itemType)
    return safe('blocks.place', safePlaceBlock, position, itemType, false)
end

function Capabilities.Blocks:Break(block)
    return safe('blocks.break', safeBreakBlock, block, true, true, nil, true, breakmethods.Distance, 360, false)
end

--------------------------------------------------------------------------------
-- Movement ownership. New systems use leases instead of independently writing movement.
-- Legacy movement modules are observed in one central compatibility boundary.
--------------------------------------------------------------------------------
local Movement = {
    Current = nil,
    Serial = 0,
    ExternalNames = {'JadeInstaKill', 'LongJump', 'Fly', 'Speed', 'Scaffold', 'TPAura', 'RecoveryTP', 'AntiDeath'},
    Priorities = {Ordinary = 10, AutoWin = 40, Ability = 70, Emergency = 100}
}
Runtime.Movement = Movement

function Movement:_expired()
    return self.Current and self.Current.Expires and self.Current.Expires <= now()
end

function Movement:_clearExpired()
    if self:_expired() then self.Current = nil end
end

function Movement:GetOwner()
    self:_clearExpired()
    return self.Current and self.Current.Owner or nil
end

function Movement:GetExternalOwner(ignore)
    if store.rootpart and ignore ~= 'HitboxTransaction' then return 'HitboxTransaction' end
    for _, name in ipairs(self.ExternalNames) do
        if name ~= ignore then
            local module = moduleByName(name)
            if module and module.Enabled then return name end
        end
    end
end

function Movement:CanWrite(owner)
    self:_clearExpired()
    if not self.Current then return true end
    return self.Current.Owner == owner
end

function Movement:Acquire(owner, priority, ttl, onPreempt, allowExternal)
    self:_clearExpired()
    priority = priority or self.Priorities.Ordinary
	local external = if allowExternal then nil else self:GetExternalOwner(owner)
    if external and external ~= owner then return nil, 'external:'..external end
    local current = self.Current
    if current and current.Owner ~= owner and current.Priority > priority then return nil, 'owned:'..current.Owner end
    if current and current.Owner ~= owner and current.OnPreempt then safe('movement.preempt.'..current.Owner, current.OnPreempt, owner) end
    self.Serial += 1
    local serial = self.Serial
    local lease = {Owner = owner, Priority = priority, Expires = now() + (ttl or 0.5), Serial = serial, Released = false}
    function lease:Renew(seconds)
        if self.Released then return false end
        if Movement.Current ~= self then return false end
        self.Expires = now() + (seconds or ttl or 0.5)
        return true
    end
    function lease:Release()
        if self.Released then return end
        self.Released = true
        if Movement.Current == self then Movement.Current = nil end
    end
    lease.OnPreempt = onPreempt
    self.Current = lease
    return lease
end

--------------------------------------------------------------------------------
-- Module leases. Restore only values that still equal the value this lease wrote.
--------------------------------------------------------------------------------
local ModuleLeases = {Active = {}, Serial = 0}
Runtime.ModuleLeases = ModuleLeases

local function optionCurrent(option)
    if option.Enabled ~= nil then return option.Enabled, 'toggle' end
    return option.Value, 'value'
end

local function optionSet(option, value, kind)
    if kind == 'toggle' then
        if option.Enabled ~= value then safe('lease.option.toggle', function() option:Toggle() end) end
    elseif option.SetValue and option.Value ~= value then
        safe('lease.option.value', function() option:SetValue(value) end)
    end
end

function ModuleLeases:Acquire(owner, name, wantedOptions, wantEnabled)
    local key = owner..':'..name
    if self.Active[key] then return self.Active[key] end
    local module = moduleByName(name)
    if not module then return nil, 'missing module' end
    self.Serial += 1
    local lease = {Owner = owner, Name = name, Module = module, Options = {}, Released = false, Serial = self.Serial}
    lease.OldEnabled = module.Enabled and true or false
    lease.WroteEnabled = nil
    for optionName, wanted in pairs(wantedOptions or {}) do
        local option = module.Options and module.Options[optionName]
        if option then
            local old, kind = optionCurrent(option)
            if old ~= wanted then
                optionSet(option, wanted, kind)
                table.insert(lease.Options, {Option = option, Old = old, Written = wanted, Kind = kind})
            end
        end
    end
    if wantEnabled ~= false and not module.Enabled then
        safe('lease.module.enable.'..name, function() module:Toggle(true) end)
        if module.Enabled then lease.WroteEnabled = true end
    end
    function lease:Release()
        if self.Released then return end
        self.Released = true
        ModuleLeases.Active[key] = nil
        for index = #self.Options, 1, -1 do
            local entry = self.Options[index]
            local current = optionCurrent(entry.Option)
            if current == entry.Written then optionSet(entry.Option, entry.Old, entry.Kind) end
        end
        if self.WroteEnabled and self.Module.Enabled == true then
            safe('lease.module.restore.'..self.Name, function() self.Module:Toggle(true) end)
        end
    end
    self.Active[key] = lease
    return lease
end

function ModuleLeases:ReleaseOwner(owner)
    local list = {}
    for key, lease in pairs(self.Active) do if lease.Owner == owner then table.insert(list, lease) end end
    for _, lease in ipairs(list) do lease:Release() end
end

function ModuleLeases:Count(owner)
    local count = 0
    for _, lease in pairs(self.Active) do if not owner or lease.Owner == owner then count += 1 end end
    return count
end

--------------------------------------------------------------------------------
-- Shared JadeAbilityAdapter. Used by JIK and the LongJump Jade compatibility hook.
--------------------------------------------------------------------------------
local Jade = {
    Compatibility = {'jade_hammer_3', 'jade_hammer_2', 'jade_hammer_1', 'jade_hammer', 'jade_hammer_jump'},
    AbilityMap = {
        jade_hammer_3 = {'jade_hammer_3_jump', 'jade_hammer_jump'},
        jade_hammer_2 = {'jade_hammer_2_jump', 'jade_hammer_jump'},
        jade_hammer_1 = {'jade_hammer_jump', 'jade_hammer_1_jump'},
        jade_hammer = {'jade_hammer_jump'},
        jade_hammer_jump = {'jade_hammer_jump', 'jade_hammer_3_jump', 'jade_hammer_2_jump', 'jade_hammer_1_jump'}
    },
    Last = {}
}
Runtime.Jade = Jade

local function jadeTier(name)
    local normalized = tostring(name or ''):lower():gsub('[%s%-]+', '_')
    local tier = tonumber(normalized:match('jade_hammer_(%d+)'))
    return tier or (normalized:find('jade_hammer', 1, true) and 0 or -1)
end

local function normalizeItemType(value)
    if type(value) ~= 'string' then return nil end
    return value:lower():gsub('[%s%-]+', '_')
end

function Jade:IsHammerName(value)
    local normalized = normalizeItemType(value)
    return normalized == 'jade_hammer_jump' or (normalized ~= nil and normalized:match('^jade_hammer(_%d+)?$') ~= nil)
end

function Jade:_candidateNames()
    local names, seen = {}, {}
    for _, name in ipairs(self.Compatibility) do seen[name] = true; table.insert(names, name) end
    if type(bedwars.ItemMeta) == 'table' then
        for name, meta in pairs(bedwars.ItemMeta) do
			if type(name) == 'string' and self:IsHammerName(name) and type(meta) == 'table' and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    table.sort(names, function(a, b) return jadeTier(a) > jadeTier(b) end)
    return names
end

function Jade:GetBestHammer()
    local found, seen = {}, {}
    local function add(item, source, fallbackType)
        if type(item) ~= 'table' then return end
        local tool = item.tool
        local itemType = normalizeItemType(item.itemType or fallbackType or (tool and tool.Name))
        if not self:IsHammerName(itemType) then return end
        if (not tool or typeof(tool) ~= 'Instance' or not tool.Parent) and lplr.Character then
            local handValue = lplr.Character:FindFirstChild('HandInvItem')
            handValue = handValue and handValue.Value
            if handValue and self:IsHammerName(handValue.Name) then tool = handValue end
        end
        if not tool or typeof(tool) ~= 'Instance' or not tool.Parent then return end
		if seen[tool] then return end
		seen[tool] = true
        table.insert(found, {
            Item = {itemType = itemType, tool = tool, amount = item.amount or 1},
            Source = source,
            Tier = jadeTier(itemType)
        })
    end

    for _, name in ipairs(self:_candidateNames()) do
        add(ask('jade.item.'..name, getItem, name), Capabilities.Source.REPLICATED, name)
    end

    local observed = store.inventory and store.inventory.inventory
    if observed then
        add(observed.hand, Capabilities.Source.REPLICATED)
        for _, item in pairs(observed.items or {}) do add(item, Capabilities.Source.REPLICATED) end
    end
    add(store.hand, Capabilities.Source.LIVE)

    local function addTools(container, source)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA('Tool') and self:IsHammerName(tool.Name) then
                add({itemType = tool.Name, tool = tool}, source)
            end
        end
    end
    addTools(lplr.Character, Capabilities.Source.LIVE)
    addTools(lplr:FindFirstChildOfClass('Backpack'), Capabilities.Source.LIVE)

    table.sort(found, function(a, b) return a.Tier > b.Tier end)
    if found[1] then
        return found[1].Item, {Source = found[1].Source, Tier = found[1].Tier}
    end
    return nil, {Source = Capabilities.Source.REPLICATED, Reason = 'not-in-inventory'}
end

local function liveAbilityController()
    local controller = bedwars.AbilityController
    if not controller then return nil, Capabilities.Source.UNKNOWN, false end
    local knit = bedwars.Knit and bedwars.Knit.Controllers
    if knit and (controller == knit.AbilityController or controller == knit.JadeHammerController) then
        return controller, Capabilities.Source.CONTROLLER, true
    end
    -- The reference dump's compatibility AbilityController has a canUseAbility stub that always
    -- returns true. A controller we cannot positively tie to the live Knit graph is usable for a
    -- request fallback, but not authoritative for readiness.
    return controller, Capabilities.Source.FALLBACK, false
end

function Jade:ResolveAbility(hammer)
    local itemType = normalizeItemType(type(hammer) == 'table' and (hammer.itemType or (hammer.tool and hammer.tool.Name)) or tostring(hammer or ''))
    if not self:IsHammerName(itemType) then return nil, {Source = Capabilities.Source.UNKNOWN, Reason = 'not-a-jade-hammer'} end
    local candidates, seen = {}, {}
    local function add(value)
        if type(value) == 'string' and value ~= '' and not seen[value] then seen[value] = true; table.insert(candidates, value) end
    end
    for _, value in ipairs(self.AbilityMap[itemType] or {}) do add(value) end
    if itemType ~= 'jade_hammer_jump' then add(itemType..'_jump') end
    add('jade_hammer_jump')

    local meta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
    if type(meta) == 'table' then
        for key, value in pairs(meta) do
            local lowered = tostring(key):lower()
            if lowered:find('abil') and type(value) == 'string' then add(value) end
        end
    end

    local controller, source, authoritative = liveAbilityController()
    if controller then
        for _, candidate in ipairs(candidates) do
            local handler
            if type(controller.getAbilityHandler) == 'function' then
                handler = ask('jade.handler.'..candidate, controller.getAbilityHandler, controller, candidate)
            end
            if handler ~= nil then return candidate, {Source = source, Authoritative = authoritative, Handler = handler} end
            for _, field in ipairs({'abilities', 'Abilities', 'handlers', 'abilityHandlers'}) do
                if type(controller[field]) == 'table' and controller[field][candidate] ~= nil then
                    return candidate, {Source = source, Authoritative = authoritative, Handler = controller[field][candidate]}
                end
            end
        end
    end
    return candidates[1], {Source = Capabilities.Source.METADATA, Authoritative = false, Candidates = candidates}
end

function Jade:GetState(ability)
    local controller, source, authoritative = liveAbilityController()
    if controller and type(controller.canUseAbility) == 'function' then
        local ok, ready = pcall(controller.canUseAbility, controller, ability, {disableBlockedAbilityAlert = true})
        if ok and authoritative then
            return ready and 'READY' or 'BLOCKED', {Source = source, Authoritative = true}
        elseif ok then
            return 'UNKNOWN', {Source = source, Authoritative = false, Reported = ready}
        end
    end
    return 'UNKNOWN', {Source = Capabilities.Source.UNKNOWN, Authoritative = false}
end

function Jade:Equip(hammer, timeout, cancelled)
    if not hammer or not hammer.tool then return false, 'missing-hammer' end
    local held = store.hand
    if held and held.tool == hammer.tool then return true, 'already-held' end
    safe('jade.switch', switchItem, hammer.tool, 0.05)
    local deadline = now() + (timeout or 0.8)
    repeat
        if cancelled and cancelled() then return false, 'cancelled' end
        held = store.hand
        if held and (held.tool == hammer.tool or held.itemType == hammer.itemType) then return true, 'replicated' end
        task.wait(0.03)
    until now() >= deadline
    return false, 'held-tool-not-acknowledged'
end

local function activationSignals(root, humanoid, ability)
    local state, source = Jade:GetState(ability)
    local attrs = {}
    local char = lplr.Character
    if char then
        for name, value in pairs(char:GetAttributes()) do
            local lower = tostring(name):lower()
            if lower:find('jade') or lower:find('hammer') or lower:find('ability') then attrs[name] = value end
        end
    end
    return {
        Position = root and root.Position,
        Velocity = root and root.AssemblyLinearVelocity or Vector3.zero,
        Floor = humanoid and humanoid.FloorMaterial,
        Readiness = state,
        ReadinessInfo = source,
        Attributes = attrs
    }
end

local function attributesChanged(before, after)
    for key, value in pairs(after or {}) do if before[key] ~= value then return true end end
    for key in pairs(before or {}) do if after[key] == nil then return true end end
    return false
end

function Jade:ObserveActivation(before, ability, timeout, cancelled)
    local deadline = now() + (timeout or 1.0)
    repeat
        if cancelled and cancelled() then return false, 'cancelled', nil end
        local root, _, humanoid = rootOfLocal()
        if not root then return false, 'character-lost', nil end
        local current = activationSignals(root, humanoid, ability)
        local moved = before.Position and (root.Position - before.Position).Magnitude > 1.25
        local velocityChanged = (root.AssemblyLinearVelocity - before.Velocity).Magnitude > 12
        local airborne = before.Floor ~= Enum.Material.Air and humanoid.FloorMaterial == Enum.Material.Air
        local cooldown = before.Readiness == 'READY' and current.Readiness == 'BLOCKED'
        local attribute = attributesChanged(before.Attributes, current.Attributes)
        if cooldown or airborne or moved or velocityChanged or attribute then
            return true, cooldown and 'cooldown-transition' or airborne and 'airborne-transition' or attribute and 'attribute-transition' or 'movement-transition', current
        end
        task.wait(0.03)
    until now() >= deadline
    return false, 'cast-not-confirmed', nil
end

function Jade:RequestActivation(hammer, ability, targetPosition, cancelled)
    local root, _, humanoid = rootOfLocal()
    if not root then return false, 'no-character' end
    local before = activationSignals(root, humanoid, ability)
    local request = {Sent = false, Paths = {}}

    local controllers = {bedwars.JadeHammerController, bedwars.HammerController, bedwars.ToolController, bedwars.ViewmodelController}
    for _, controller in ipairs(controllers) do
        if controller then
            for _, method in ipairs({'useTool', 'activateTool', 'activate', 'useItem'}) do
                if type(controller[method]) == 'function' then
                    local ok, result = pcall(controller[method], controller, hammer.tool, targetPosition)
                    table.insert(request.Paths, {Path = method, OK = ok, Result = result})
                    if ok and result ~= false then request.Sent = true; break end
                end
            end
        end
        if request.Sent then break end
    end

    if not request.Sent and hammer.tool and type(hammer.tool.Activate) == 'function' then
        local ok = pcall(hammer.tool.Activate, hammer.tool)
        table.insert(request.Paths, {Path = 'Tool.Activate', OK = ok})
        request.Sent = ok
    end

    if not request.Sent and inputService then
        local ok = pcall(function()
            local vim = game:GetService('VirtualInputManager')
            local center = gameCamera.ViewportSize / 2
            vim:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
            vim:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
        end)
        table.insert(request.Paths, {Path = 'VirtualInput', OK = ok})
        request.Sent = ok
    end

    -- Direct ability use is a compatibility request path, never success proof. Only use it when
    -- the live controller exists; the dump fallback is not allowed to manufacture authority.
    local controller, source, authoritative = liveAbilityController()
    if not request.Sent and controller and authoritative and type(controller.useAbility) == 'function' then
        local ok, result = pcall(controller.useAbility, controller, ability)
        table.insert(request.Paths, {Path = 'AbilityController.useAbility', OK = ok, Result = result, Source = source})
        request.Sent = ok and result ~= false
    end

    self.Last.Request = request
    if not request.Sent then return false, 'no-activation-path', request end
    local confirmed, reason, signal = self:ObserveActivation(before, ability, 1.1, cancelled)
    self.Last.Confirmation = {Confirmed = confirmed, Reason = reason, Signal = signal}
    return confirmed, reason, request
end

function Jade:GetCooldownState(ability)
    return self:GetState(ability)
end

function Jade:ActivateForTraversal(owner, direction, cancelled)
    local hammer = self:GetBestHammer()
    if not hammer then return {confirmed = false, reason = 'missing-hammer'} end
    local ability, abilityInfo = self:ResolveAbility(hammer)
    local ready, readyInfo = self:GetState(ability)
    if ready == 'BLOCKED' then return {confirmed = false, reason = 'cooldown', ability = ability, readiness = ready, readinessInfo = readyInfo} end
    local lease, leaseReason = Movement:Acquire(owner or 'LongJump', Movement.Priorities.Ability, 3, nil, true)
    if not lease then return {confirmed = false, reason = leaseReason} end
    local equipped, equipReason = self:Equip(hammer, 0.8, cancelled)
    if not equipped then lease:Release(); return {confirmed = false, reason = equipReason} end
    local root = rootOfLocal()
    local target = root and (root.Position + (direction or root.CFrame.LookVector) * 20) or nil
    local confirmed, reason = self:RequestActivation(hammer, ability, target, cancelled)
    task.delay(3, function() lease:Release() end)
    return {confirmed = confirmed, reason = reason, hammer = hammer, ability = ability, abilityInfo = abilityInfo, readiness = ready, readinessInfo = readyInfo, lease = lease}
end

--------------------------------------------------------------------------------
-- WorldSnapshot
--------------------------------------------------------------------------------
local WorldSnapshot = {}
WorldSnapshot.__index = WorldSnapshot
Runtime.WorldSnapshot = WorldSnapshot

function WorldSnapshot.new(owner)
    local self = setmetatable({}, WorldSnapshot)
    self.Owner = owner
    self.Version = 0
    self.DynamicAt = 0
    self.WorldAt = 0
    self.WorldDirty = true
    self.Signature = ''
    self.Beds = {}
    self.Generators = {}
    self.Shops = {}
    self.Enemies = {}
    self.Connections = {}
    local function dirty() self.WorldDirty = true end
    safe('snapshot.bed.add', function() table.insert(self.Connections, collectionService:GetInstanceAddedSignal('bed'):Connect(dirty)) end)
    safe('snapshot.bed.remove', function() table.insert(self.Connections, collectionService:GetInstanceRemovedSignal('bed'):Connect(dirty)) end)
    safe('snapshot.gen.add', function() table.insert(self.Connections, collectionService:GetInstanceAddedSignal('Generator'):Connect(dirty)) end)
    safe('snapshot.gen.remove', function() table.insert(self.Connections, collectionService:GetInstanceRemovedSignal('Generator'):Connect(dirty)) end)
    return self
end

function WorldSnapshot:Destroy()
    for _, connection in ipairs(self.Connections) do safe('snapshot.disconnect', connection.Disconnect, connection) end
    table.clear(self.Connections)
end

function WorldSnapshot:_refreshWorld()
    table.clear(self.Beds)
    local team = self.Team
    for _, bed in ipairs(collectionService:GetTagged('bed')) do
        local part = bed.Parent and partOf(bed) or nil
        if part then
            local own = team ~= nil and bed:GetAttribute('Team'..team..'NoBreak') and true or false
            table.insert(self.Beds, {
                Object = bed, Part = part, Position = part.Position, Own = own,
                Shielded = (bed:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow()
            })
        end
    end
    table.clear(self.Generators)
    for _, object in ipairs(collectionService:GetTagged('Generator')) do
        local part = object.Parent and partOf(object) or nil
        if part then
            local id = tostring(object:GetAttribute('Id') or ''):lower()
            table.insert(self.Generators, {Object = object, Part = part, Position = part.Position, Kind = id:find('emerald') and 'emerald' or id:find('diamond') and 'diamond' or 'iron'})
        end
    end
    table.clear(self.Shops)
    for _, entry in pairs(store.shop or {}) do
        local part = entry.RootPart and partOf(entry.RootPart) or nil
        if entry.Shop and part then table.insert(self.Shops, {Entry = entry, Position = part.Position, Id = entry.Id}) end
    end
    self.WorldDirty = false
    self.WorldAt = now()
end

local function armourTier()
    local ladder = {'leather_chestplate', 'iron_chestplate', 'diamond_chestplate', 'emerald_chestplate'}
    local best = 0
    local inv = store.inventory and store.inventory.inventory
    for _, entry in pairs((inv and inv.armor) or {}) do
        if entry and entry ~= 'empty' and entry.itemType then best = math.max(best, table.find(ladder, entry.itemType) or 0) end
    end
    if best == 0 and getBestArmor then
        local item = ask('snapshot.bestArmor', getBestArmor, 1)
        if item and item.itemType then best = table.find(ladder, item.itemType) or 0 end
    end
    return best
end

local function blockInventory()
    local inv = store.inventory and store.inventory.inventory
    local bestName, total = nil, 0
    for _, item in pairs((inv and inv.items) or {}) do
        local meta = bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
        if meta and meta.block and not tostring(item.itemType):find('tnt') and not tostring(item.itemType):find('cannon') and not tostring(item.itemType):find('bed') then
            total += item.amount or 0
            bestName = bestName or item.itemType
        end
    end
    return total, bestName
end

function WorldSnapshot:Refresh(force)
    local t = now()
    if not force and t - self.DynamicAt < 0.12 then return self end
    self.DynamicAt = t
    self.MatchState, self.MatchSource = Capabilities.Match:GetState()
    self.Team, self.TeamSource = Capabilities.Match:GetTeam()
    self.Map = store.map
    self.Queue = store.queueType
    self.Kit = Capabilities.Kits:GetEquipped()
    self.Root, self.Character, self.Humanoid = rootOfLocal()
    self.Alive = self.Root ~= nil
    self.Position = self.Root and self.Root.Position or nil
    local health = self.Character and self.Character.Health or 0
    local maxHealth = self.Character and self.Character.MaxHealth or 100
    self.Health = health
    self.HealthFraction = maxHealth > 0 and math.clamp(health / maxHealth, 0, 1) or 0
    self.Inventory = (store.inventory and store.inventory.inventory) or {items = {}, armor = {}}
    self.Hotbar = store.inventory and store.inventory.hotbar or {}
    self.Held = store.hand
    self.Iron = itemCount('iron')
    self.Diamond = itemCount('diamond')
    self.Emerald = itemCount('emerald')
    self.Blocks, self.BlockItem = blockInventory()
    self.ArmorTier = armourTier()

    if self.WorldDirty or t - self.WorldAt > 0.8 then self:_refreshWorld() end
    self.OwnBedAlive = false
    self.EnemyBeds = {}
    for _, bed in ipairs(self.Beds) do
        if bed.Own then self.OwnBedAlive = true else table.insert(self.EnemyBeds, bed) end
    end
    self.LastLife = self.Team ~= nil and not self.OwnBedAlive

    table.clear(self.Enemies)
    for _, ent in ipairs(entitylib.List or {}) do
        local root = ent.RootPart
        local sameTeam = ent.Player and self.Team ~= nil and ent.Player:GetAttribute('Team') == self.Team
        if ent.Targetable and root and root.Parent and not sameTeam and (not ent.Health or ent.Health > 0) then
            table.insert(self.Enemies, ent)
        end
    end
    table.sort(self.Enemies, function(a, b)
        if not self.Position then return false end
        return (a.RootPart.Position - self.Position).Magnitude < (b.RootPart.Position - self.Position).Magnitude
    end)
    self.NearbyThreat = self.Enemies[1]
    self.NearbyThreatDistance = self.NearbyThreat and self.Position and (self.NearbyThreat.RootPart.Position - self.Position).Magnitude or math.huge
    self.MovementOwner = Movement:GetOwner() or Movement:GetExternalOwner('AutoWin')

    local signature = table.concat({tostring(self.MatchState), tostring(self.Team), tostring(self.OwnBedAlive), tostring(#self.EnemyBeds), tostring(self.Alive), tostring(self.Blocks), tostring(self.ArmorTier), tostring(#self.Enemies)}, ':')
    if signature ~= self.Signature then self.Signature = signature; self.Version += 1 end
    return self
end

--------------------------------------------------------------------------------
-- Failure memory
--------------------------------------------------------------------------------
local FailureMemory = {}
FailureMemory.__index = FailureMemory
Runtime.FailureMemory = FailureMemory
function FailureMemory.new() return setmetatable({Entries = {}}, FailureMemory) end
function FailureMemory:_key(objective, action, route)
    return table.concat({objective or '?', action or '?', route or '?'}, '|')
end
function FailureMemory:Record(objective, action, route, reason, worldVersion)
    local key = self:_key(objective, action, route)
    local entry = self.Entries[key] or {Count = 0, First = now()}
    entry.Count += 1; entry.Last = now(); entry.Reason = reason; entry.WorldVersion = worldVersion
    entry.Cooldown = math.min(2 ^ math.min(entry.Count, 5), 30)
    self.Entries[key] = entry
    return entry
end
function FailureMemory:Penalty(objective, action, route, worldVersion)
    local entry = self.Entries[self:_key(objective, action, route)]
    if not entry then return 0 end
    if worldVersion and entry.WorldVersion and worldVersion - entry.WorldVersion >= 3 then return math.max(0, entry.Count - 2) * 4 end
    if now() - entry.Last > (entry.Cooldown or 0) then return math.max(0, entry.Count - 1) * 6 end
    return entry.Count * 18
end
function FailureMemory:ClearStale(worldVersion)
    for key, entry in pairs(self.Entries) do
        if now() - entry.Last > 120 or (worldVersion and entry.WorldVersion and worldVersion - entry.WorldVersion > 8) then self.Entries[key] = nil end
    end
end

--------------------------------------------------------------------------------
-- Hierarchical Navigation V2
--------------------------------------------------------------------------------
local Navigation = {}
Navigation.__index = Navigation
Runtime.Navigation = Navigation
local CELL = 3
local STAND = 1.5
local HEAD = {Vector3.new(0, 1, 0), Vector3.new(0, 2, 0)}
local DIRS = {Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1)}
local DROPS = {0, -1, 1, -2, -3}

function Navigation.new(snapshot)
    return setmetatable({Snapshot = snapshot, Cache = {}, Recalculations = 0, Expansions = 0, Solid = {}, SolidAt = 0}, Navigation)
end
function Navigation:Cell(pos) return bedwars.BlockController:getBlockPosition(pos) end
function Navigation:World(cell) return cell * CELL end
function Navigation:ClearLocalCache() table.clear(self.Solid); self.SolidAt = now() end
function Navigation:SolidAt(cell)
    if now() - self.SolidAt > 0.35 then self:ClearLocalCache() end
    local key = string.format('%d,%d,%d', cell.X, cell.Y, cell.Z)
    if self.Solid[key] ~= nil then return self.Solid[key] end
    local world = self:World(cell)
    local solid = getPlacedBlock(world) ~= nil
    if not solid then
        local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.RespectCanCollide = true
        params.FilterDescendantsInstances = {lplr.Character, gameCamera}
        solid = workspace:Raycast(world + Vector3.new(0,1.4,0), Vector3.new(0,-2.8,0), params) ~= nil
    end
    self.Solid[key] = solid
    return solid
end

local function heapPush(heap, node, score)
    local i = #heap + 1; heap[i] = {Node = node, Score = score}
    while i > 1 do local p = math.floor(i/2); if heap[p].Score <= heap[i].Score then break end; heap[p], heap[i] = heap[i], heap[p]; i = p end
end
local function heapPop(heap)
    if #heap == 0 then return nil end
    local top = heap[1]; heap[1] = heap[#heap]; heap[#heap] = nil
    local i = 1
    while true do
        local l, r, s = i*2, i*2+1, i
        if l <= #heap and heap[l].Score < heap[s].Score then s = l end
        if r <= #heap and heap[r].Score < heap[s].Score then s = r end
        if s == i then break end
        heap[i], heap[s] = heap[s], heap[i]; i = s
    end
    return top.Node
end
local function cellKey(cell) return string.format('%d,%d,%d', cell.X, cell.Y, cell.Z) end
local function heuristic(a,b) return math.abs(a.X-b.X)+math.abs(a.Z-b.Z)+math.abs(a.Y-b.Y)*1.35 end

function Navigation:_localPlan(fromPos, toPos, allowPlace, allowBreak, cancelled)
    self:ClearLocalCache()
    local startCell = self:Cell(Vector3.new(fromPos.X, fromPos.Y - STAND, fromPos.Z))
    local goalCell = self:Cell(Vector3.new(toPos.X, toPos.Y - STAND, toPos.Z))
    local open, came, g, closed = {}, {}, {}, {}
    local startKey = cellKey(startCell); g[startKey] = 0; heapPush(open, startCell, heuristic(startCell, goalCell))
    local best, bestH = startCell, heuristic(startCell, goalCell)
    local budget = math.clamp(450 + bestH * 18, 700, 3500)
    local expansions = 0
    while true do
        local current = heapPop(open); if not current then break end
        local key = cellKey(current)
        if not closed[key] then
            closed[key] = true; expansions += 1
            local h = heuristic(current, goalCell)
            if h < bestH then best, bestH = current, h end
            if h <= 0.5 or expansions >= budget then break end
            if expansions % 250 == 0 then task.wait(); if cancelled and cancelled() then return nil, expansions end end
            local base = g[key] or 0
            for _, dir in ipairs(DIRS) do
                for _, dy in ipairs(DROPS) do
                    local n = current + dir + Vector3.new(0,dy,0); local nk = cellKey(n)
                    if not closed[nk] and heuristic(n, goalCell) < bestH + 80 then
                        local bridge = not self:SolidAt(n)
                        if not bridge or (allowPlace and dy == 0) then
                            local blocked, mine = false, 0
                            for _, off in ipairs(HEAD) do
                                local head = n + off
                                if self:SolidAt(head) then
                                    if allowBreak and getPlacedBlock(self:World(head)) then mine += 1 else blocked = true end
                                end
                            end
                            if not blocked then
                                local cost = base + 1 + (bridge and 2.0 or 0) + mine*2.4 + math.abs(dy)*0.5
                                if cost < (g[nk] or math.huge) then g[nk] = cost; came[nk] = current; heapPush(open,n,cost+heuristic(n,goalCell)) end
                            end
                        end
                    end
                end
            end
            if allowPlace then
                local n = current + Vector3.new(0,1,0); local nk = cellKey(n)
                if not closed[nk] then
                    local cost = base + 4
                    if cost < (g[nk] or math.huge) then g[nk] = cost; came[nk] = current; heapPush(open,n,cost+heuristic(n,goalCell)) end
                end
            end
        end
    end
    self.Expansions = expansions
    local cells, cursor, guard = {}, best, 0
    while cursor and cellKey(cursor) ~= startKey and guard < 512 do table.insert(cells,1,cursor); cursor = came[cellKey(cursor)]; guard += 1 end
    return cells, expansions
end

local function groundScore(a,b)
    local distance = ((b-a)*Vector3.new(1,0,1)).Magnitude
    return distance + math.abs(b.Y-a.Y)*0.7
end

function Navigation:_strategicAnchors(snapshot, goal)
    local nodes = {{Kind='Start', Position=snapshot.Position}, {Kind='Goal', Position=goal}}
    for _, gen in ipairs(snapshot.Generators) do if gen.Kind ~= 'iron' then table.insert(nodes,{Kind='Generator',Position=gen.Position,Object=gen.Object}) end end
    for _, shop in ipairs(snapshot.Shops) do table.insert(nodes,{Kind='Shop',Position=shop.Position,Object=shop.Entry}) end
    for _, bed in ipairs(snapshot.Beds) do table.insert(nodes,{Kind=bed.Own and 'HomeBase' or 'EnemyBase',Position=bed.Position,Object=bed.Object}) end
    return nodes
end

function Navigation:_strategicPath(snapshot, goal)
    local nodes = self:_strategicAnchors(snapshot, goal)
    if #nodes <= 2 then return {nodes[1], nodes[2]} end
    local dist, prev, unvisited = {[1]=0}, {}, {}
    for i=1,#nodes do unvisited[i]=true end
    while true do
        local best, bestD
        for i in pairs(unvisited) do local d=dist[i] or math.huge; if not bestD or d<bestD then best,bestD=i,d end end
        if not best or best==2 then break end
        unvisited[best]=nil
        for j in pairs(unvisited) do
            local direct=(nodes[j].Position-nodes[best].Position).Magnitude
            if direct <= 135 or j==2 then
                local cost=bestD+groundScore(nodes[best].Position,nodes[j].Position)+(direct>90 and 18 or 0)
                if cost<(dist[j] or math.huge) then dist[j]=cost; prev[j]=best end
            end
        end
    end
    local ids={2}; local cursor=2; local guard=0
    while cursor~=1 and prev[cursor] and guard<32 do cursor=prev[cursor]; table.insert(ids,1,cursor); guard+=1 end
    if ids[1]~=1 then return {nodes[1],nodes[2]} end
    local path={}; for _,id in ipairs(ids) do table.insert(path,nodes[id]) end; return path
end

local function segmentKind(nav, previous, cell, allowBreak)
    if not nav:SolidAt(cell) then return 'Bridge' end
    if previous and cell.Y > previous.Y then return 'Climb' end
    if allowBreak then
        for _, off in ipairs(HEAD) do if getPlacedBlock(nav:World(cell+off)) then return 'Mine' end end
    end
    return 'Walk'
end

function Navigation:Plan(snapshot, goal, objective, allowBreak, cancelled)
    if not snapshot.Position or not goal then return nil, 'missing-position' end
    self.Recalculations += 1
    local strategic = self:_strategicPath(snapshot, goal)
    local route = {Objective=objective, Target=goal, Strategic=strategic, Segments={}, RequiredBlocks=0, ExpectedMining=0, Distance=0, ExpectedTime=0, Risk=0, Cost=0, WorldVersion=snapshot.Version, Recalculation=self.Recalculations, Expansions=0}
    local from = snapshot.Position
    for index=2,#strategic do
        local to = strategic[index].Position
        local cells, expansions = self:_localPlan(from,to,true,allowBreak,cancelled)
        route.Expansions += expansions or 0
        if not cells or #cells==0 then
            table.insert(route.Segments,{Kind='Wait',From=from,To=to,Reason='partial-route'}); route.Risk += 20
        else
            local previous = self:Cell(Vector3.new(from.X,from.Y-STAND,from.Z))
            local currentSegment
            for _,cell in ipairs(cells) do
                local kind=segmentKind(self,previous,cell,allowBreak)
                if not currentSegment or currentSegment.Kind~=kind then currentSegment={Kind=kind,Cells={}}; table.insert(route.Segments,currentSegment) end
                table.insert(currentSegment.Cells,cell)
                if kind=='Bridge' then route.RequiredBlocks += 1; route.Risk += 0.6 elseif kind=='Mine' then route.ExpectedMining += 1 end
                route.Distance += CELL; previous=cell
            end
        end
        from=to
    end
    route.RequiredBlocks += route.RequiredBlocks > 0 and 8 or 0
    route.ExpectedTime = route.Distance/16 + route.RequiredBlocks*0.08 + route.ExpectedMining*0.35
    route.Cost = route.ExpectedTime + route.Risk
    return route
end

--------------------------------------------------------------------------------
-- Loadout planner
--------------------------------------------------------------------------------
local LoadoutPlanner = {}
LoadoutPlanner.__index = LoadoutPlanner
Runtime.LoadoutPlanner = LoadoutPlanner
function LoadoutPlanner.new() return setmetatable({},LoadoutPlanner) end
function LoadoutPlanner:Evaluate(snapshot, route)
    local result={RequiredBlocks=route and route.RequiredBlocks or 8, Deficits={}, Purchases={}}
    result.RequiredBlocks=math.max(result.RequiredBlocks,8)
    if snapshot.Blocks<result.RequiredBlocks then result.Deficits.Blocks=result.RequiredBlocks-snapshot.Blocks end
    local desiredArmor=snapshot.LastLife and 2 or 1
    if snapshot.ArmorTier<desiredArmor then result.Deficits.Armor=desiredArmor-snapshot.ArmorTier end
    if result.Deficits.Blocks then table.insert(result.Purchases,{Kind='Blocks',Item='wool_white',Priority=100}) end
    local armour={'leather_chestplate','iron_chestplate','diamond_chestplate','emerald_chestplate'}
    if result.Deficits.Armor then table.insert(result.Purchases,{Kind='Armor',Item=armour[snapshot.ArmorTier+1],Priority=90}) end
    local tool=store.tools and store.tools.pickaxe
    if route and route.ExpectedMining>0 and not tool then table.insert(result.Purchases,{Kind='Tool',Item='wood_pickaxe',Priority=80}) end
    table.sort(result.Purchases,function(a,b)return a.Priority>b.Priority end)
    local ironNeed=0
    for _,purchase in ipairs(result.Purchases) do
        local item=Capabilities.Shop:GetItem(purchase.Item)
        if item and item.currency=='iron' then ironNeed+=item.price or 0 end
    end
    result.IronDeficit=math.max(ironNeed-snapshot.Iron,0)
    return result
end

--------------------------------------------------------------------------------
-- Action scheduler
--------------------------------------------------------------------------------
local ActionState={RUNNING='RUNNING',SUCCESS='SUCCESS',FAILED='FAILED',CANCELLED='CANCELLED',BLOCKED='BLOCKED'}
Runtime.ActionState=ActionState
local function action(kind,data)
    local a={Kind=kind,Data=data or {},State=ActionState.RUNNING,Started=now(),Reason=nil,Cancelled=false,ProgressAt=now()}
    function a:Cancel(reason) self.Cancelled=true; self.State=ActionState.CANCELLED; self.Reason=reason or 'cancelled' end
    function a:Finish(state,reason) self.State=state; self.Reason=reason; return state,reason end
    return a
end

local TravelAction={}
function TravelAction.new(director,objective,route)
    local a=action('Travel',{Objective=objective,Route=route,Segment=1,Cell=1,Best=math.huge,StallAt=now(),Lease=nil})
    return setmetatable(a,{__index=TravelAction})
end
function TravelAction:Cleanup()
    if self.Data.Lease then self.Data.Lease:Release(); self.Data.Lease=nil end
    local _,char=rootOfLocal(); if char and char.Humanoid then safe('travel.stop',char.Humanoid.Move,char.Humanoid,Vector3.zero,false) end
end
function TravelAction:Cancel(reason) self.Cancelled=true; self.State=ActionState.CANCELLED; self.Reason=reason; self:Cleanup() end
function TravelAction:Tick(director,snapshot)
    if self.Cancelled then return self.State,self.Reason end
    local route=self.Data.Route
    local goal=self.Data.Objective.Position
    if not snapshot.Alive or not goal then self:Cleanup(); return self:Finish(ActionState.CANCELLED,'character-or-target-lost') end
    if (snapshot.Position-goal).Magnitude <= (self.Data.Objective.StopRange or 8) then self:Cleanup(); return self:Finish(ActionState.SUCCESS,'arrived') end
    if snapshot.Version-route.WorldVersion>=4 then self:Cleanup(); return self:Finish(ActionState.BLOCKED,'route-stale') end
    if not self.Data.Lease then
        local lease,reason=Movement:Acquire('AutoWin',Movement.Priorities.AutoWin,0.5,function() self:Cancel('movement-preempted') end)
        if not lease then return self:Finish(ActionState.BLOCKED,reason) end
        self.Data.Lease=lease
    else self.Data.Lease:Renew(0.5) end
    local segment=route.Segments[self.Data.Segment]
    if not segment then self:Cleanup(); return self:Finish(ActionState.BLOCKED,'route-exhausted') end
    if segment.Kind=='Wait' then self:Cleanup(); return self:Finish(ActionState.BLOCKED,segment.Reason or 'route-wait') end
    local cell=segment.Cells and segment.Cells[self.Data.Cell]
    if not cell then self.Data.Segment+=1; self.Data.Cell=1; return ActionState.RUNNING end
    local root,char,humanoid=rootOfLocal(); if not root or not humanoid then self:Cleanup(); return self:Finish(ActionState.CANCELLED,'character-lost') end
    if segment.Kind=='Bridge' and not director.Navigation:SolidAt(cell) then
        if snapshot.Blocks<=0 or not snapshot.BlockItem then self:Cleanup(); return self:Finish(ActionState.BLOCKED,'no-blocks') end
        Capabilities.Blocks:Place(director.Navigation:World(cell),snapshot.BlockItem); director.Navigation:ClearLocalCache(); return ActionState.RUNNING
    elseif segment.Kind=='Mine' then
        for _,off in ipairs(HEAD) do local block=getPlacedBlock(director.Navigation:World(cell+off)); if block then Capabilities.Blocks:Break(block); director.Navigation:ClearLocalCache(); return ActionState.RUNNING end end
    elseif segment.Kind=='Climb' and humanoid.FloorMaterial~=Enum.Material.Air then
        safe('travel.jump',humanoid.ChangeState,humanoid,Enum.HumanoidStateType.Jumping)
    end
    local aim=director.Navigation:World(cell)+Vector3.new(0,(char.HipHeight or 2)+STAND,0)
    local delta=(aim-root.Position)*Vector3.new(1,0,1)
    if delta.Magnitude<1.7 then self.Data.Cell+=1; self.ProgressAt=now(); return ActionState.RUNNING end
    safe('travel.move',humanoid.Move,humanoid,delta.Unit,false)
    local distance=(goal-root.Position).Magnitude
    if distance<self.Data.Best-1 then self.Data.Best=distance; self.Data.StallAt=now(); self.ProgressAt=now() elseif now()-self.Data.StallAt>5 then self:Cleanup(); return self:Finish(ActionState.FAILED,'segment-stalled') end
    return ActionState.RUNNING
end

local BreakBedAction={}
function BreakBedAction.new(objective) return setmetatable(action('BreakBed',{Objective=objective,LastHit=0}),{__index=BreakBedAction}) end
function BreakBedAction:Tick(director,snapshot)
    local bed=self.Data.Objective.Target
    if not bed or not bed.Parent or not partOf(bed) then return self:Finish(ActionState.SUCCESS,'bed-gone') end
    local part=partOf(bed); if not snapshot.Position or (part.Position-snapshot.Position).Magnitude>28 then return self:Finish(ActionState.BLOCKED,'bed-out-of-range') end
    if (bed:GetAttribute('BedShieldEndTime') or 0)>workspace:GetServerTimeNow() then return self:Finish(ActionState.BLOCKED,'bed-shield') end
    if now()-self.Data.LastHit>=0.22 then self.Data.LastHit=now(); safe('autowin.breakbed',safeBreakBlock,part,true,true,nil,true,breakmethods.Distance,360,false); self.ProgressAt=now() end
    return ActionState.RUNNING
end

local CombatAction={}
function CombatAction.new(objective) return setmetatable(action('Combat',{Objective=objective,Aura=nil,Travel=nil,LastSeen=now()}),{__index=CombatAction}) end
function CombatAction:Cleanup() if self.Data.Aura then self.Data.Aura:Release(); self.Data.Aura=nil end; if self.Data.Travel then self.Data.Travel:Cancel('combat-cleanup'); self.Data.Travel=nil end end
function CombatAction:Cancel(reason) self.Cancelled=true;self.State=ActionState.CANCELLED;self.Reason=reason;self:Cleanup() end
function CombatAction:Tick(director,snapshot)
    local ent=self.Data.Objective.Target
    if not ent or not ent.RootPart or not ent.RootPart.Parent or (ent.Health and ent.Health<=0) then self:Cleanup();return self:Finish(ActionState.SUCCESS,'target-gone') end
    if snapshot.LastLife and snapshot.HealthFraction<0.38 then self:Cleanup();return self:Finish(ActionState.BLOCKED,'low-health-last-life') end
    local distance=(ent.RootPart.Position-snapshot.Position).Magnitude
    if distance>(self.Data.Objective.StopRange or 8)+5 then
        if not self.Data.Travel or self.Data.Travel.State~=ActionState.RUNNING then
            local route=director.Navigation:Plan(snapshot,ent.RootPart.Position,'hunt',true,function()return not director.Running end)
            if not route then return self:Finish(ActionState.FAILED,'no-combat-route') end
            self.Data.Objective.Position=ent.RootPart.Position;self.Data.Travel=TravelAction.new(director,self.Data.Objective,route)
        else self.Data.Objective.Position=ent.RootPart.Position end
        local state,reason=self.Data.Travel:Tick(director,snapshot)
        if state~=ActionState.RUNNING and state~=ActionState.SUCCESS then self:Cleanup();return self:Finish(state,reason) end
        return ActionState.RUNNING
    end
    if not self.Data.Aura then self.Data.Aura=ModuleLeases:Acquire('AutoWin','Killaura',{['Require mouse down']=false,['GUI check']=false},true) end
    self.ProgressAt=now();return ActionState.RUNNING
end

local HealAction={}
function HealAction.new(objective) return setmetatable(action('Heal',{Objective=objective,Consume=nil,Travel=nil}),{__index=HealAction}) end
function HealAction:Cleanup() if self.Data.Consume then self.Data.Consume:Release();self.Data.Consume=nil end;if self.Data.Travel then self.Data.Travel:Cancel('heal-cleanup') end end
function HealAction:Cancel(reason) self.Cancelled=true;self.State=ActionState.CANCELLED;self.Reason=reason;self:Cleanup() end
function HealAction:Tick(director,snapshot)
    if snapshot.HealthFraction>=0.82 then self:Cleanup();return self:Finish(ActionState.SUCCESS,'healed') end
    if not self.Data.Consume then self.Data.Consume=ModuleLeases:Acquire('AutoWin','AutoConsume',{},true) end
    if snapshot.NearbyThreat and snapshot.NearbyThreatDistance<45 and snapshot.Position then
        local away=(snapshot.Position-snapshot.NearbyThreat.RootPart.Position)*Vector3.new(1,0,1)
        if away.Magnitude>0.1 then
            self.Data.Objective.Position=snapshot.Position+away.Unit*35;self.Data.Objective.StopRange=5
            if not self.Data.Travel or self.Data.Travel.State~=ActionState.RUNNING then
                local route=director.Navigation:Plan(snapshot,self.Data.Objective.Position,'heal',false,function()return not director.Running end)
                if route then self.Data.Travel=TravelAction.new(director,self.Data.Objective,route) end
            end
            if self.Data.Travel then self.Data.Travel:Tick(director,snapshot) end
        end
    end
    if now()-self.Started>10 then self:Cleanup();return self:Finish(ActionState.BLOCKED,'heal-timeout') end
    return ActionState.RUNNING
end

local CollectAction={}
function CollectAction.new(objective) return setmetatable(action('Collect',{Objective=objective,Travel=nil,LastIron=nil,LastGain=now()}),{__index=CollectAction}) end
function CollectAction:Cleanup() if self.Data.Travel then self.Data.Travel:Cancel('collect-cleanup') end end
function CollectAction:Cancel(reason) self.Cancelled=true;self.State=ActionState.CANCELLED;self.Reason=reason;self:Cleanup() end
function CollectAction:Tick(director,snapshot)
    local target=self.Data.Objective.TargetIron or snapshot.Iron
    if snapshot.Iron>=target then self:Cleanup();return self:Finish(ActionState.SUCCESS,'resources-ready') end
    if not self.Data.Objective.Position then return self:Finish(ActionState.FAILED,'generator-missing') end
    if (snapshot.Position-self.Data.Objective.Position).Magnitude>10 then
        if not self.Data.Travel or self.Data.Travel.State~=ActionState.RUNNING then
            local route=director.Navigation:Plan(snapshot,self.Data.Objective.Position,'collect',false,function()return not director.Running end)
            if not route then return self:Finish(ActionState.FAILED,'generator-route-missing') end
            self.Data.Travel=TravelAction.new(director,self.Data.Objective,route)
        end
        local state,reason=self.Data.Travel:Tick(director,snapshot);if state~=ActionState.RUNNING and state~=ActionState.SUCCESS then return self:Finish(state,reason) end
    else
        if self.Data.LastIron==nil or snapshot.Iron>self.Data.LastIron then self.Data.LastIron=snapshot.Iron;self.Data.LastGain=now();self.ProgressAt=now() elseif now()-self.Data.LastGain>12 then return self:Finish(ActionState.BLOCKED,'generator-not-producing') end
    end
    return ActionState.RUNNING
end

local PurchaseAction={}
function PurchaseAction.new(objective) return setmetatable(action('Purchase',{Objective=objective,Travel=nil,LastBuy=0}),{__index=PurchaseAction}) end
function PurchaseAction:Cleanup() if self.Data.Travel then self.Data.Travel:Cancel('purchase-cleanup') end end
function PurchaseAction:Cancel(reason) self.Cancelled=true;self.State=ActionState.CANCELLED;self.Reason=reason;self:Cleanup() end
function PurchaseAction:Tick(director,snapshot)
    local shop=self.Data.Objective.Target
    if not shop then return self:Finish(ActionState.FAILED,'shop-missing') end
    if (snapshot.Position-shop.Position).Magnitude>18 then
        self.Data.Objective.Position=shop.Position
        if not self.Data.Travel or self.Data.Travel.State~=ActionState.RUNNING then
            local route=director.Navigation:Plan(snapshot,shop.Position,'purchase',false,function()return not director.Running end)
            if not route then return self:Finish(ActionState.FAILED,'shop-route-missing') end
            self.Data.Travel=TravelAction.new(director,self.Data.Objective,route)
        end
        local state,reason=self.Data.Travel:Tick(director,snapshot);if state~=ActionState.RUNNING and state~=ActionState.SUCCESS then return self:Finish(state,reason) end
        return ActionState.RUNNING
    end
    local plan=director.Loadout:Evaluate(snapshot,director.RoutePlan)
    if #plan.Purchases==0 then return self:Finish(ActionState.SUCCESS,'loadout-ready') end
    if now()-self.Data.LastBuy<0.25 then return ActionState.RUNNING end
    local desired=plan.Purchases[1];local item=Capabilities.Shop:GetItem(desired.Item,shop.Id)
    if not item then return self:Finish(ActionState.BLOCKED,'shop-item-unavailable:'..desired.Item) end
    local currency=itemCount(item.currency)
    if currency<(item.price or math.huge) then return self:Finish(ActionState.BLOCKED,'insufficient-'..tostring(item.currency)) end
    self.Data.LastBuy=now();safe('autowin.purchase',function() bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({shopItem=item,shopId=shop.Id}) end);self.ProgressAt=now();return ActionState.RUNNING
end

local BankAction={}
function BankAction.new(objective) return setmetatable(action('Bank',{Objective=objective,Lease=nil}),{__index=BankAction}) end
function BankAction:Tick()
    if not self.Data.Lease then self.Data.Lease=ModuleLeases:Acquire('AutoWin','AutoBank',{},true) end
    if self.Data.Lease then task.delay(0.5,function() if self.Data.Lease then self.Data.Lease:Release();self.Data.Lease=nil end end);return self:Finish(ActionState.SUCCESS,'delegated') end
    return self:Finish(ActionState.BLOCKED,'autobank-unavailable')
end
function BankAction:Cancel(reason) if self.Data.Lease then self.Data.Lease:Release() end;self.State=ActionState.CANCELLED;self.Reason=reason end

local ActionScheduler={}
ActionScheduler.__index=ActionScheduler
Runtime.ActionScheduler=ActionScheduler
function ActionScheduler.new(director) return setmetatable({Director=director,Current=nil,LastResult=nil},ActionScheduler) end
function ActionScheduler:Cancel(reason) if self.Current then self.Current:Cancel(reason);self.LastResult={State=self.Current.State,Reason=self.Current.Reason,Kind=self.Current.Kind};self.Current=nil end end
function ActionScheduler:Start(actionObject) self:Cancel('superseded');self.Current=actionObject;return actionObject end
function ActionScheduler:Tick(snapshot)
    if not self.Current then return nil end
    local state,reason=self.Current:Tick(self.Director,snapshot)
    if state and state~=ActionState.RUNNING then self.LastResult={State=state,Reason=reason,Kind=self.Current.Kind};self.Current=nil end
    return state,reason
end

--------------------------------------------------------------------------------
-- Objective planner with hysteresis
--------------------------------------------------------------------------------
local ObjectivePlanner={}
ObjectivePlanner.__index=ObjectivePlanner
Runtime.ObjectivePlanner=ObjectivePlanner
function ObjectivePlanner.new(failures) return setmetatable({Failures=failures,Current=nil,CommittedAt=0,Scores={}},ObjectivePlanner) end
local function nearest(list,pos)
    local best,bestD
    for _,entry in ipairs(list or {}) do local p=entry.Position or (entry.RootPart and entry.RootPart.Position);if p then local d=(p-pos).Magnitude;if not bestD or d<bestD then best,bestD=entry,d end end end
    return best,bestD or math.huge
end
function ObjectivePlanner:Score(snapshot,navigation,loadout)
    local candidates={};local function add(kind,score,data) data=data or {};data.Kind=kind;data.Score=score;table.insert(candidates,data) end
    if snapshot.MatchState==Capabilities.Match.States.PRE then add('WAIT',1000,{Reason='prematch'}) return candidates end
    if snapshot.MatchState==Capabilities.Match.States.POST then add('MATCH_DONE',1000) return candidates end
    if not snapshot.Alive then add('WAIT_RESPAWN',950) return candidates end
    if snapshot.LastLife and snapshot.HealthFraction<0.46 then add('HEAL',920+(0.46-snapshot.HealthFraction)*200) end
    if snapshot.NearbyThreat and snapshot.NearbyThreatDistance<16 then add('IMMEDIATE_THREAT',880-snapshot.NearbyThreatDistance,{Target=snapshot.NearbyThreat,Position=snapshot.NearbyThreat.RootPart.Position,StopRange=8}) end
    for _,bed in ipairs(snapshot.EnemyBeds) do
        local d=(bed.Position-snapshot.Position).Magnitude
        local penalty=self.Failures:Penalty('ATTACK_BED','Travel',tostring(bed.Object),snapshot.Version)
        local score=760-d*0.8-(bed.Shielded and 180 or 0)-penalty
        if snapshot.LastLife then score-=50 end
        add('ATTACK_BED',score,{Target=bed.Object,Position=bed.Position,Bed=bed,StopRange=8,Key=tostring(bed.Object)})
    end
    if #snapshot.EnemyBeds==0 and #snapshot.Enemies>0 then
        local ent=snapshot.Enemies[1];local d=(ent.RootPart.Position-snapshot.Position).Magnitude
        local health=ent.Health or 100
        add('HUNT_FINAL',700-d*0.6+(100-health)*0.2-self.Failures:Penalty('HUNT_FINAL','Combat',tostring(ent.Character),snapshot.Version),{Target=ent,Position=ent.RootPart.Position,StopRange=8,Key=tostring(ent.Character)})
    end
    local shop,shopDist=nearest(snapshot.Shops,snapshot.Position)
    if shop and snapshot.ArmorTier==0 then add('PURCHASE_LOADOUT',650-shopDist*0.5,{Target=shop,Position=shop.Position,StopRange=16}) end
    if snapshot.Blocks<8 and shop then add('PURCHASE_LOADOUT',675-shopDist*0.4,{Target=shop,Position=shop.Position,StopRange=16}) end
    local gen,genDist=nearest(snapshot.Generators,snapshot.Position)
    if gen and snapshot.Iron<16 then add('COLLECT_RESOURCES',520-genDist*0.3,{Target=gen,Position=gen.Position,TargetIron=16,StopRange=8}) end
    table.sort(candidates,function(a,b)return a.Score>b.Score end)
    return candidates
end
function ObjectivePlanner:Choose(snapshot,navigation,loadout)
    local list=self:Score(snapshot,navigation,loadout);table.clear(self.Scores);for _,obj in ipairs(list) do self.Scores[obj.Kind..':'..tostring(obj.Key or obj.Target or '')]=obj.Score end
    local best=list[1]
    if not best then return nil end
    if self.Current and now()-self.CommittedAt<2.0 then
        local currentScore=self.Current.Score or -math.huge
        if self.Current.Kind==best.Kind and (self.Current.Target==best.Target or not self.Current.Target) then self.Current.Score=best.Score;return self.Current end
        if best.Score<currentScore+35 then return self.Current end
    end
    self.Current=best;self.CommittedAt=now();return best
end

--------------------------------------------------------------------------------
-- Session supervisor
--------------------------------------------------------------------------------
local SessionSupervisor={}
SessionSupervisor.__index=SessionSupervisor
Runtime.SessionSupervisor=SessionSupervisor
function SessionSupervisor.new(module,options)
    return setmetatable({Module=module,Options=options,Queued=false,Rejoining=false,Connections={}},SessionSupervisor)
end
function SessionSupervisor:WriteState()
    safe('session.state',function()
        writefile('aetherv2/profiles/autowin.json',httpService:JSONEncode({enabled=self.Module.Enabled,resume=self.Options.ResumeInLobby.Enabled,queue=self.Options.Gamemode.Value,fallback=store.queueType,stamp=os.time()}))
    end)
end
function SessionSupervisor:ResolveQueue()
    local wanted=self.Options.Gamemode.Value
    if wanted=='Current' or not wanted then return store.queueType end
    if wanted=='Random' then
        local ids={};for id,meta in pairs(bedwars.QueueMeta or {}) do if not meta.disabled and not meta.voiceChatOnly and not meta.rankCategory then table.insert(ids,id) end end
        return #ids>0 and ids[math.random(1,#ids)] or store.queueType
    end
    return wanted
end
function SessionSupervisor:Queue()
    if self.Queued or not self.Options.Requeue.Enabled then return end
    local allowed=ask('session.queue-state',function() local s=bedwars.Store:getState();return not s.Game.customMatch and s.Party.leader.userId==lplr.UserId and s.Party.queueState==0 end)
    if not allowed then return end
    self.Queued=true;self:WriteState();safe('session.queue',bedwars.QueueController.joinQueue,bedwars.QueueController,self:ResolveQueue())
end
function SessionSupervisor:Rejoin()
    if self.Rejoining or not self.Options.AutoRejoin.Enabled then return end
    self.Rejoining=true;self:WriteState();safe('session.rejoin',function() game:GetService('TeleportService'):Teleport(6872265039,lplr) end)
    task.delay(8,function() if self.Module.Enabled then self.Rejoining=false end end)
end
function SessionSupervisor:Start()
    self:WriteState()
    if guiService then table.insert(self.Connections,guiService.ErrorMessageChanged:Connect(function(message) if self.Module.Enabled and type(message)=='string' and message~='' then task.delay(2,function() if self.Module.Enabled then self:Rejoin() end end) end end)) end
    if vapeEvents and vapeEvents.MatchEndEvent then table.insert(self.Connections,vapeEvents.MatchEndEvent.Event:Connect(function() if self.Module.Enabled then task.delay(1,function() if self.Module.Enabled then self:Queue() end end) end end)) end
end
function SessionSupervisor:Stop()
    for _,connection in ipairs(self.Connections) do safe('session.disconnect',connection.Disconnect,connection) end;table.clear(self.Connections);self.Rejoining=false;self:WriteState()
end

--------------------------------------------------------------------------------
-- MatchDirector
--------------------------------------------------------------------------------
local MatchDirector={}
MatchDirector.__index=MatchDirector
Runtime.MatchDirector=MatchDirector

function MatchDirector.new(module,options,hud)
    local self=setmetatable({},MatchDirector)
    self.Module=module;self.Options=options;self.HUD=hud;self.Running=true;self.Generation=0
    self.Snapshot=WorldSnapshot.new('AutoWin');self.Failures=FailureMemory.new();self.Navigation=Navigation.new(self.Snapshot);self.Loadout=LoadoutPlanner.new();self.Planner=ObjectivePlanner.new(self.Failures);self.Scheduler=ActionScheduler.new(self)
    self.Session=SessionSupervisor.new(module,options);self.RoutePlan=nil;self.Objective=nil;self.RecoveryLevel=0;self.LastProgress=now();self.LastFailure=nil;self.LastFailureReason=nil;self.LastWorldVersion=0
    return self
end

function MatchDirector:Cancel(reason)
    if not self.Running then return end
    self.Running=false;self.Generation+=1;self.Scheduler:Cancel(reason or 'director-stop');ModuleLeases:ReleaseOwner('AutoWin');local current=Movement.Current;if current and current.Owner=='AutoWin' then current:Release() end;self.Snapshot:Destroy();self.Session:Stop()
end

function MatchDirector:_routeFor(objective,snapshot)
    if not objective or not objective.Position then return nil end
    if self.RoutePlan and self.RoutePlan.Target and (self.RoutePlan.Target-objective.Position).Magnitude<6 and snapshot.Version-self.RoutePlan.WorldVersion<3 then return self.RoutePlan end
    self.RoutePlan=self.Navigation:Plan(snapshot,objective.Position,objective.Kind,true,function() return not self.Running end)
    return self.RoutePlan
end

function MatchDirector:_nearestShop(snapshot) return nearest(snapshot.Shops,snapshot.Position) end
function MatchDirector:_nearestGenerator(snapshot) return nearest(snapshot.Generators,snapshot.Position) end

function MatchDirector:_makeAction(objective,snapshot)
    if objective.Kind=='WAIT' or objective.Kind=='WAIT_RESPAWN' or objective.Kind=='MATCH_DONE' then return nil end
    if objective.Kind=='HEAL' then return HealAction.new(objective) end
    if objective.Kind=='IMMEDIATE_THREAT' or objective.Kind=='HUNT_FINAL' then return CombatAction.new(objective) end
    if objective.Kind=='COLLECT_RESOURCES' then return CollectAction.new(objective) end
    if objective.Kind=='PURCHASE_LOADOUT' then return PurchaseAction.new(objective) end
    if objective.Kind=='ATTACK_BED' then
        local distance=(snapshot.Position-objective.Position).Magnitude
        if distance<=26 then return BreakBedAction.new(objective) end
        local route=self:_routeFor(objective,snapshot);if not route then return nil,'route-unavailable' end
        local loadout=self.Loadout:Evaluate(snapshot,route)
        if snapshot.Blocks<loadout.RequiredBlocks then
            local shop=self:_nearestShop(snapshot)
            if shop then return PurchaseAction.new({Kind='PURCHASE_LOADOUT',Target=shop,Position=shop.Position,StopRange=16,Score=objective.Score+1}) end
            local gen=self:_nearestGenerator(snapshot)
            if gen then return CollectAction.new({Kind='COLLECT_RESOURCES',Target=gen,Position=gen.Position,TargetIron=math.max(16,loadout.IronDeficit+snapshot.Iron),StopRange=8}) end
        end
        return TravelAction.new(self,objective,route)
    end
    return nil,'unsupported-objective'
end

function MatchDirector:_interruptReason(snapshot)
    if snapshot.MatchState==Capabilities.Match.States.POST then return 'match-ended' end
    if not snapshot.Alive and self.Scheduler.Current then return 'local-death' end
    if self.Scheduler.Current and self.Objective then
        if self.Objective.Kind=='ATTACK_BED' and (not self.Objective.Target or not self.Objective.Target.Parent) then return 'bed-gone' end
        if (self.Objective.Kind=='HUNT_FINAL' or self.Objective.Kind=='IMMEDIATE_THREAT') and (not self.Objective.Target or not self.Objective.Target.RootPart or not self.Objective.Target.RootPart.Parent) then return 'target-gone' end
        if snapshot.LastLife and snapshot.HealthFraction<0.38 and self.Scheduler.Current.Kind~='Heal' then return 'last-life-low-health' end
        if snapshot.NearbyThreatDistance<10 and self.Objective.Kind~='IMMEDIATE_THREAT' and self.Scheduler.Current.Kind~='Combat' then return 'immediate-threat' end
    end
end

function MatchDirector:_recover(result,snapshot)
    if not result or result.State==ActionState.SUCCESS or result.State==ActionState.CANCELLED then self.RecoveryLevel=0;return end
    self.LastFailure=result.Kind;self.LastFailureReason=result.Reason
    local objective=self.Objective and self.Objective.Kind or '?';local routeKey=self.Objective and self.Objective.Key or '?'
    local entry=self.Failures:Record(objective,result.Kind,routeKey,result.Reason,snapshot.Version)
    self.RecoveryLevel=math.min(entry.Count,6)
    if self.RecoveryLevel<=1 then self.RoutePlan=nil
    elseif self.RecoveryLevel==2 then self.RoutePlan=nil;self.Navigation:ClearLocalCache()
    elseif self.RecoveryLevel==3 then self.Planner.Current=nil
    elseif self.RecoveryLevel==4 then
        local own;for _,bed in ipairs(snapshot.Beds) do if bed.Own then own=bed break end end
        if own and snapshot.OwnBedAlive then self.Planner.Current={Kind='RETURN_SAFE',Position=own.Position,StopRange=12,Score=1000};self.Planner.CommittedAt=now() end
    elseif self.RecoveryLevel==5 then self.Scheduler:Cancel('subsystem-restart');self.RoutePlan=nil
    else self.Planner.Current=nil;self.RoutePlan=nil;self.Failures:ClearStale(snapshot.Version) end
end

function MatchDirector:UpdateHUD(snapshot)
    if not self.HUD then return end
    local current=self.Scheduler.Current
    local route=self.RoutePlan
    self.HUD:Set({
        Objective=self.Objective and self.Objective.Kind or 'Waiting',Action=current and current.Kind or 'Idle',Target=self.Objective and ((self.Objective.Target and self.Objective.Target.Player and self.Objective.Target.Player.Name) or (self.Objective.Bed and 'Bed') or '') or '',
        Route=route and string.format('%d seg / %d exp',#route.Segments,route.Expansions) or 'none',Blocks=string.format('%d / %d',snapshot.Blocks,route and route.RequiredBlocks or 0),Health=string.format('%d%%',math.floor(snapshot.HealthFraction*100)),Risk=route and string.format('%.1f',route.Risk) or '0',Movement=snapshot.MovementOwner or 'none',Recovery=tostring(self.RecoveryLevel),World=tostring(snapshot.Version),Failure=self.LastFailureReason or '',Scores=self.Planner.Scores,Leases=ModuleLeases:Count('AutoWin'),Replans=self.Navigation.Recalculations
    })
end

function MatchDirector:Tick()
    local snapshot=self.Snapshot:Refresh()
    self.Failures:ClearStale(snapshot.Version)
    if snapshot.MatchState==Capabilities.Match.States.POST then self.Session:Queue() end
    if snapshot.MatchState==Capabilities.Match.States.PRE then self.Session.Queued=false end
    local interrupt=self:_interruptReason(snapshot);if interrupt then self.Scheduler:Cancel(interrupt);self.Planner.Current=nil;self.RoutePlan=nil end

    local previous=self.Scheduler.LastResult
    if previous then self:_recover(previous,snapshot);self.Scheduler.LastResult=nil end
    local objective=self.Planner:Choose(snapshot,self.Navigation,self.Loadout)
    if objective and (not self.Objective or self.Objective.Kind~=objective.Kind or self.Objective.Target~=objective.Target) then
        self.Scheduler:Cancel('objective-changed');self.RoutePlan=nil
    end
    self.Objective=objective

    if not self.Scheduler.Current and objective then
        local nextAction,reason=self:_makeAction(objective,snapshot)
        if nextAction then self.Scheduler:Start(nextAction) elseif reason then self.LastFailure='Planner';self.LastFailureReason=reason end
    end
    local state=self.Scheduler:Tick(snapshot)
    if state==ActionState.RUNNING and self.Scheduler.Current and now()-self.Scheduler.Current.ProgressAt<1 then self.LastProgress=now() end
    self:UpdateHUD(snapshot)
end

function MatchDirector:Start()
    self.Session:Start();ModuleLeases:Acquire('AutoWin','AutoTool',{},true);ModuleLeases:Acquire('AutoWin','NoFallDamage',{},true);ModuleLeases:Acquire('AutoWin','AntiVoid',{},true)
    if self.Options.KeepAwake.Enabled then ModuleLeases:Acquire('AutoWin','Anti-AFK',{},true) end
    local gen=self.Generation
    task.spawn(function()
        while self.Running and gen==self.Generation do
            local ok,err=xpcall(function() self:Tick() end,debug and debug.traceback or tostring)
            if not ok then Runtime.Errors.AutoWinDirector={At=now(),Error=tostring(err)};self.LastFailure='Director';self.LastFailureReason=tostring(err);self.RecoveryLevel=math.min(self.RecoveryLevel+1,6) end
            task.wait(0.1)
        end
    end)
    task.spawn(function()
        while self.Running and gen==self.Generation do
            task.wait(2)
            local limit=(self.Options.StuckLimit.Value or 0)*60
            if limit>0 and now()-self.LastProgress>limit then
                local snapshot=self.Snapshot:Refresh(true);self.RecoveryLevel=math.min(self.RecoveryLevel+1,6);self.Scheduler:Cancel('watchdog-stall');self.RoutePlan=nil;self.Planner.Current=nil;self.LastFailure='Watchdog';self.LastFailureReason='no subsystem progress';self.LastProgress=now();self.Failures:Record('WATCHDOG','Director','global','stalled',snapshot.Version)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- AutoWin HUD V2
--------------------------------------------------------------------------------
local function makeHUD(module,debugOption)
    local frame=module.Children
    if not frame then return nil end
    frame.Size=UDim2.fromOffset(286,154);if frame.Position==UDim2.new() then frame.Position=UDim2.fromOffset(16,220) end
    for _,child in ipairs(frame:GetChildren()) do if child.Name=='AetherAutoWinV7' then child:Destroy() end end
    local bg=Instance.new('Frame');bg.Name='AetherAutoWinV7';bg.Size=UDim2.fromScale(1,1);bg.BackgroundColor3=Color3.new();bg.BackgroundTransparency=0.3;bg.BorderSizePixel=0;bg.Parent=frame
    local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=bg
    local labels={};local names={'Objective','Action','Target','Route','Blocks','Health','Risk','Movement','Recovery'}
    for index,name in ipairs(names) do
        local label=Instance.new('TextLabel');label.Name=name;label.Size=UDim2.new(1,-12,0,14);label.Position=UDim2.fromOffset(7,5+(index-1)*15);label.BackgroundTransparency=1;label.Font=index<=2 and Enum.Font.GothamBold or Enum.Font.Gotham;label.TextSize=11;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextColor3=Color3.new(1,1,1);label.Text=name..': -';label.Parent=bg;labels[name]=label
    end
    local debugLabel=Instance.new('TextLabel');debugLabel.Size=UDim2.new(1,-12,0,28);debugLabel.Position=UDim2.fromOffset(7,138);debugLabel.BackgroundTransparency=1;debugLabel.Font=Enum.Font.Code;debugLabel.TextSize=9;debugLabel.TextXAlignment=Enum.TextXAlignment.Left;debugLabel.TextYAlignment=Enum.TextYAlignment.Top;debugLabel.TextColor3=Color3.fromRGB(180,180,180);debugLabel.Visible=false;debugLabel.Parent=bg
    local hud={Frame=frame,Labels=labels,Debug=debugLabel,Data={}}
    function hud:Set(data)
        self.Data=data
        for _,name in ipairs(names) do if labels[name] then labels[name].Text=name..': '..tostring(data[name] or '-') end end
        local dbg=debugOption and debugOption.Enabled
        debugLabel.Visible=dbg and true or false
        if dbg then debugLabel.Text=string.format('world %s | replans %s | leases %s\nlast: %s',data.World or '-',data.Replans or 0,data.Leases or 0,data.Failure or '-') end
        frame.Size=UDim2.fromOffset(286,dbg and 174 or 144)
    end
    return hud
end

--------------------------------------------------------------------------------
-- AutoWin module V7
--------------------------------------------------------------------------------
local AutoWin
local AutoOptions={}
AutoWin=vape.Categories.World:CreateModule({Name='AutoWin',Tooltip='Reactive match director: plans objectives, loadout, routes, combat and session lifecycle',Size=UDim2.fromOffset(286,144),Function=function(callback)
    if callback then
        local hud=makeHUD(AutoWin,AutoOptions.Debug);Runtime.AutoWinDirector=MatchDirector.new(AutoWin,AutoOptions,hud);Runtime.AutoWinDirector:Start();AutoWin:Clean(function() if Runtime.AutoWinDirector then Runtime.AutoWinDirector:Cancel('module-disabled');Runtime.AutoWinDirector=nil end end)
    elseif Runtime.AutoWinDirector then Runtime.AutoWinDirector:Cancel('module-disabled');Runtime.AutoWinDirector=nil end
end})
Runtime.AutoWin=AutoWin
AutoOptions.Aggression=AutoWin:CreateDropdown({Name='Aggression',List={'Safe','Balanced','Blatant'},Tooltip='Risk tolerance used by objective scoring and recovery'});pcall(function()AutoOptions.Aggression:SetValue('Balanced')end)
AutoOptions.TakeOver=AutoWin:CreateToggle({Name='Take over modules',Default=true,Tooltip='Temporarily leases existing Aether helpers and safely restores untouched settings'})
AutoOptions.KillPlayers=AutoWin:CreateToggle({Name='Kill players',Default=true})
AutoOptions.RespawnAfterBed=AutoWin:CreateToggle({Name='Respawn after bed',Default=true,Tooltip='Compatibility setting; semantic recovery decides when a safe reset is appropriate'})
AutoOptions.BankLoot=AutoWin:CreateToggle({Name='Bank loot',Default=true})
AutoOptions.YuziDash=AutoWin:CreateToggle({Name='Yuzi dash',Default=true,Tooltip='Allows traversal adapters to consider Yuzi movement when available'})
AutoOptions.AutoEquipKit=AutoWin:CreateToggle({Name='Auto equip Yuzi',Default=true,Darker=true})
AutoOptions.DaoPriority=AutoWin:CreateToggle({Name='Dao priority',Default=true,Darker=true})
AutoOptions.IronAmount=AutoWin:CreateSlider({Name='Iron amount',Min=8,Max=64,Default=16,Suffix=' iron'})
AutoOptions.WoolAmount=AutoWin:CreateSlider({Name='Block amount',Min=16,Max=128,Default=32,Suffix=' blocks'})
AutoOptions.BedReach=AutoWin:CreateSlider({Name='Bed reach',Min=3,Max=14,Default=8,Decimal=10,Suffix=' studs'})
AutoOptions.PlayerReach=AutoWin:CreateSlider({Name='Player reach',Min=3,Max=14,Default=8,Decimal=10,Suffix=' studs'})
AutoOptions.StartDelay=AutoWin:CreateSlider({Name='Start delay',Min=0,Max=10,Default=2,Decimal=10,Suffix=' seconds'})
AutoOptions.StuckLimit=AutoWin:CreateSlider({Name='Watchdog',Min=0,Max=10,Default=4,Decimal=10,Suffix=' minutes'})
AutoOptions.Requeue=AutoWin:CreateToggle({Name='Auto queue',Default=true})
local queueList={'Current','Random'};for id,meta in pairs(bedwars.QueueMeta or {}) do if not meta.disabled and not meta.voiceChatOnly then table.insert(queueList,id) end end;table.sort(queueList,function(a,b)if a=='Current'then return true elseif b=='Current'then return false elseif a=='Random'then return true elseif b=='Random'then return false else return tostring(a)<tostring(b) end end)
AutoOptions.Gamemode=AutoWin:CreateDropdown({Name='Gamemode',List=queueList,Darker=true})
AutoOptions.ResumeInLobby=AutoWin:CreateToggle({Name='Resume in lobby',Default=true,Darker=true})
AutoOptions.AutoRejoin=AutoWin:CreateToggle({Name='Auto rejoin',Default=true})
AutoOptions.KeepAwake=AutoWin:CreateToggle({Name='Keep awake',Default=true})
AutoOptions.ShowHUD=AutoWin:CreateToggle({Name='Show HUD',Default=true,Function=function(value)if AutoWin.Children then AutoWin.Children.Visible=value and AutoWin.Enabled end end})
AutoOptions.Notify=AutoWin:CreateToggle({Name='Notifications'})
AutoOptions.Debug=AutoWin:CreateToggle({Name='Debug',Tooltip='Shows objective/action diagnostics without notification spam'})

--------------------------------------------------------------------------------
-- JadeInstaKill V2 state machine
--------------------------------------------------------------------------------
local JIKState={IDLE='IDLE',ACQUIRE_TARGET='ACQUIRE_TARGET',VALIDATE='VALIDATE',ACQUIRE_MOVEMENT='ACQUIRE_MOVEMENT',EQUIP='EQUIP',REQUEST_CAST='REQUEST_CAST',CONFIRM_CAST='CONFIRM_CAST',ACTIVE='ACTIVE',OUTCOME='LANDING/OUTCOME',RECOVERY='RECOVERY',COOLDOWN='COOLDOWN'}
Runtime.JIKState=JIKState

local CharacterTransaction={}
CharacterTransaction.__index=CharacterTransaction
function CharacterTransaction.new(character)
    local self=setmetatable({Character=character,Cleaned=false,PartTransparency={},Connections={},OriginalCamera=nil,OriginalHeld=store.hand and store.hand.tool or nil,MovementLease=nil,Bindings={}},CharacterTransaction)
    return self
end
function CharacterTransaction:HidePart(part) if part:IsA('BasePart') and self.PartTransparency[part]==nil then self.PartTransparency[part]=part.LocalTransparencyModifier;part.LocalTransparencyModifier=1 end end
function CharacterTransaction:Cleanup()
    if self.Cleaned then return end;self.Cleaned=true
    for name in pairs(self.Bindings) do runService:UnbindFromRenderStep(name) end;table.clear(self.Bindings)
    for _,connection in ipairs(self.Connections) do safe('jik.tx.disconnect',connection.Disconnect,connection) end;table.clear(self.Connections)
    for part,value in pairs(self.PartTransparency) do if part.Parent then part.LocalTransparencyModifier=value end end;table.clear(self.PartTransparency)
    if self.MovementLease then self.MovementLease:Release();self.MovementLease=nil end
    if self.OriginalHeld and self.OriginalHeld.Parent then safe('jik.restore-held',switchItem,self.OriginalHeld,0) end
end

local Presentation={}
function Presentation.Start(transaction,character,targetTracker,cameraEnabled)
    for _,desc in ipairs(character:GetDescendants()) do transaction:HidePart(desc) end
    table.insert(transaction.Connections,character.DescendantAdded:Connect(function(desc) transaction:HidePart(desc) end))
    if cameraEnabled then
        local bind='AetherJIKPresentationV2';transaction.Bindings[bind]=true
        runService:BindToRenderStep(bind,Enum.RenderPriority.Camera.Value+1,function()
            local target=targetTracker.Root;if not target or not target.Parent then return end
            local root=rootOfLocal();if not root then return end
            gameCamera.CFrame=CFrame.lookAt(gameCamera.CFrame.Position,target.Position)
        end)
    end
end

local TargetTracker={}
TargetTracker.__index=TargetTracker
function TargetTracker.new(entity,range)
    return setmetatable({Entity=entity,Root=entity and entity.RootPart,Initial=entity and entity.RootPart and entity.RootPart.Position,Range=range,LastValid=now(),Reason=nil},TargetTracker)
end
function TargetTracker:Refresh(origin)
    local ent=self.Entity;local root=ent and ent.RootPart
    if root and root~=self.Root then self.Root=root end
    if not ent or not self.Root or not self.Root.Parent or not ent.Character or not ent.Character.Parent then self.Reason='root-or-character-lost';return false end
    if ent.Health and ent.Health<=0 then self.Reason='dead';return false end
    if origin and (self.Root.Position-origin).Magnitude>self.Range+8 then self.Reason='left-execution-range';return false end
    self.LastValid=now();return true
end

local JadeInstaKill
local JIKOptions={}
local JIK={State=JIKState.IDLE,Generation=0,Session=nil,Diagnostics={}}
Runtime.JIK=JIK

local function jikDebug(message,data)
    JIK.Diagnostics.At=now();JIK.Diagnostics.State=JIK.State;JIK.Diagnostics.Message=message
    if data then for k,v in pairs(data) do JIK.Diagnostics[k]=v end end
    if JIKOptions.Debug and JIKOptions.Debug.Enabled then warn('[AetherV2/JIK] '..message) end
end
local function jikTransition(state,detail)
    local old=JIK.State;JIK.State=state;JIK.Diagnostics.LastTransition=old..' -> '..state;if detail then JIK.Diagnostics.Detail=detail end
end
local function jikCancelled(generation) return not JadeInstaKill.Enabled or generation~=JIK.Generation or not entitylib.isAlive end
local function jikCleanup(session,reason)
    if session and session.Transaction then session.Transaction:Cleanup() end
    ModuleLeases:ReleaseOwner('JadeInstaKill')
    JIK.Session=nil
    jikTransition(JIKState.IDLE,reason)
end

local function acquireJikTarget()
    local root=rootOfLocal();if not root then return nil,'local-root-missing' end
    local ok,result=pcall(entitylib.EntityPosition,{Origin=root.Position,Range=JIKOptions.Range.Value,Part='RootPart',Players=JIKOptions.Targets.Players.Enabled,NPCs=JIKOptions.Targets.NPCs.Enabled})
    if not ok then return nil,'entitylib-error:'..tostring(result) end
    if not result then return nil,'no-target' end
    return result
end

local function validateJikTarget(target)
    if not target then return false,'nil-target' end
    local root=rootOfLocal();if not root then return false,'local-root-missing' end
    if not target.RootPart or not target.RootPart.Parent then return false,'target-root-missing' end
    if target.Health and target.Health<=0 then return false,'target-dead' end
    local distance=(target.RootPart.Position-root.Position).Magnitude
    if distance>JIKOptions.Range.Value+3 then return false,'out-of-range:'..string.format('%.1f',distance) end
    if target.Player and target.Player:GetAttribute('Team')==lplr:GetAttribute('Team') and lplr:GetAttribute('Team')~=nil then return false,'same-team' end
    return true,nil,distance
end

local function simulationResult(session)
    local state,stateInfo=Jade:GetState(session.Ability)
    jikDebug('Simulation: no cast sent',{Hammer=session.Hammer.itemType,Ability=session.Ability,Readiness=state,ReadinessSource=stateInfo.Source,Target=session.Target.Entity.Player and session.Target.Entity.Player.Name or 'NPC'})
    return true
end

local function runJikSession(target,generation)
    local session={Target=TargetTracker.new(target,JIKOptions.Range.Value),Transaction=nil,Hammer=nil,Ability=nil,Started=now(),Generation=generation}
    JIK.Session=session
    local function cancelled() return jikCancelled(generation) end
    local success,err=xpcall(function()
        jikTransition(JIKState.VALIDATE)
        local valid,reason,distance=validateJikTarget(target);if not valid then error('VALIDATE:'..reason) end
        session.Distance=distance

        local hammer,hammerInfo=Jade:GetBestHammer();session.Hammer=hammer;session.HammerInfo=hammerInfo
        if not hammer then error('EQUIP:no-supported-jade-hammer') end
        local ability,abilityInfo=Jade:ResolveAbility(hammer);session.Ability=ability;session.AbilityInfo=abilityInfo
        local readiness,readinessInfo=Jade:GetState(ability);session.Readiness=readiness;session.ReadinessInfo=readinessInfo
        if readiness=='BLOCKED' then error('REQUEST_CAST:ability-blocked') end

        jikTransition(JIKState.ACQUIRE_MOVEMENT)
        local lease,leaseReason=Movement:Acquire('JadeInstaKill',Movement.Priorities.Ability,1.0,function() JIK.Generation+=1 end,true)
        if not lease then error('ACQUIRE_MOVEMENT:'..tostring(leaseReason)) end
        -- JIK is an emergency ability owner. Suspend legacy writers that do not yet understand the
        -- shared lease; restore them only if they are still in the state this transaction wrote.
        for _,name in ipairs({'Fly','Speed','LongJump','Scaffold','TPAura'}) do ModuleLeases:Acquire('JadeInstaKill',name,{},false) end
        session.Transaction=CharacterTransaction.new(lplr.Character);session.Transaction.MovementLease=lease

        jikTransition(JIKState.EQUIP)
        local equipped,equipReason=Jade:Equip(hammer,0.9,cancelled)
        if not equipped then error('EQUIP:'..equipReason) end
        jikDebug('Hammer equipped',{Hammer=hammer.itemType,HeldConfirmation=equipReason,Ability=ability,Readiness=readiness,ReadinessSource=readinessInfo.Source,Distance=distance})
        if cancelled() then error('EQUIP:cancelled') end

        local mode=JIKOptions.Mode.Value
        if mode=='Spoof' then mode='Simulation' end -- legacy config migration; never forge lethal payloads.
        if mode=='Simulation' then simulationResult(session);return end

        Presentation.Start(session.Transaction,lplr.Character,session.Target,JIKOptions.Camera.Enabled)
        jikTransition(JIKState.REQUEST_CAST)
        local targetPosition=session.Target.Root.Position
        local confirmed,castReason,request=Jade:RequestActivation(hammer,ability,targetPosition,cancelled)
        session.Request=request
        jikTransition(JIKState.CONFIRM_CAST,castReason)
        if not confirmed then error('CONFIRM_CAST:'..castReason) end
        jikDebug('Cast confirmed',{Confirmation=castReason,RequestPath=request and request.Paths and request.Paths[1] and request.Paths[1].Path})

        jikTransition(JIKState.ACTIVE)
        local root,character,humanoid=rootOfLocal();if not root or not humanoid then error('ACTIVE:character-lost') end
        local originalOffset=(root.Position-session.Target.Root.Position)*Vector3.new(1,0,1)
        local activeDeadline=now()+10
        while not cancelled() and now()<activeDeadline do
            lease:Renew(0.5)
            root,character,humanoid=rootOfLocal();if not root or not humanoid then break end
            if not session.Target:Refresh(root.Position) then break end
            local targetRoot=session.Target.Root
            if Movement:CanWrite('JadeInstaKill') and isnetworkowner(root) then
                -- Follow only horizontally; Jade owns the vertical launch/slam. No forged damage or
                -- math.huge payload is sent by this mode.
                local targetPos=targetRoot.Position+originalOffset
                root.CFrame=CFrame.new(targetPos.X,root.Position.Y,targetPos.Z)*root.CFrame.Rotation
                local velocity=root.AssemblyLinearVelocity;local targetVelocity=targetRoot.AssemblyLinearVelocity
                local extra=JIKOptions.FasterFall.Enabled and JIKOptions.Gravity.Value*(1/60) or 0
                root.AssemblyLinearVelocity=Vector3.new(targetVelocity.X,velocity.Y-extra,targetVelocity.Z)
            end
            if humanoid.FloorMaterial~=Enum.Material.Air and now()-session.Started>0.3 then break end
            task.wait()
        end

        jikTransition(JIKState.OUTCOME,session.Target.Reason)
        if cancelled() then return end
        jikTransition(JIKState.COOLDOWN)
        local cooldownDeadline=now()+6
        while not cancelled() and now()<cooldownDeadline do
            local state=Jade:GetCooldownState(ability)
            if state=='READY' then break end
            -- UNKNOWN is not treated as blocked forever: once the observed movement has ended and a
            -- short guard elapsed, return to scanning rather than wedging the module busy.
            if state=='UNKNOWN' and now()-session.Started>1.2 then break end
            task.wait(0.08)
        end
    end,debug and debug.traceback or tostring)
    if not success then
        jikTransition(JIKState.RECOVERY,tostring(err));jikDebug('Job failed',{Failure=tostring(err),Hammer=session.Hammer and session.Hammer.itemType,Ability=session.Ability,Target=target.Player and target.Player.Name or 'NPC'})
    end
    jikCleanup(session,success and 'completed' or tostring(err))
end

JadeInstaKill=vape.Categories.Exploits:CreateModule({Name='JadeInstaKill',Tooltip='Uses the live Jade controller/tool path, confirms the cast, tracks one target, and cleans up transaction state',Function=function(callback)
    JIK.Generation+=1
    if not callback then if JIK.Session then jikCleanup(JIK.Session,'module-disabled') else JIK.State=JIKState.IDLE end;return end
    local generation=JIK.Generation
    task.spawn(function()
        while JadeInstaKill.Enabled and generation==JIK.Generation do
            if JIK.State==JIKState.IDLE and entitylib.isAlive then
                jikTransition(JIKState.ACQUIRE_TARGET)
                local target,reason=acquireJikTarget()
                if target then task.spawn(runJikSession,target,generation) else JIK.State=JIKState.IDLE;if reason~='no-target' then jikDebug('Target acquisition failed',{Failure=reason}) end end
            end
            task.wait(0.08)
        end
        if not JadeInstaKill.Enabled and JIK.Session then jikCleanup(JIK.Session,'scanner-ended') end
    end)
end})
Runtime.JadeInstaKill=JadeInstaKill
JIKOptions.Mode=JadeInstaKill:CreateDropdown({Name='Mode',List={'TP','Simulation','Spoof'},Tooltip='TP runs the real Jade slam. Simulation performs diagnostics only. Legacy Spoof configs are migrated to Simulation.'})
JIKOptions.Targets=JadeInstaKill:CreateTargets({Players=true,NPCs=true})
JIKOptions.Range=JadeInstaKill:CreateSlider({Name='Range',Min=1,Max=30,Default=18,Suffix=' studs'})
JIKOptions.FasterFall=JadeInstaKill:CreateToggle({Name='Increase gravity',Default=true,Function=function(value)if JIKOptions.Gravity and JIKOptions.Gravity.Object then JIKOptions.Gravity.Object.Visible=value end end})
JIKOptions.Gravity=JadeInstaKill:CreateSlider({Name='Extra gravity',Min=0,Max=500,Default=180,Suffix=' studs/s²'})
JIKOptions.Camera=JadeInstaKill:CreateToggle({Name='Camera lock',Default=true})
JIKOptions.Debug=JadeInstaKill:CreateToggle({Name='Debug',Tooltip='Logs state transitions, hammer/equip/readiness source and exact failure reasons'})
JadeInstaKill.ExtraText=function() return JIK.State end

function Runtime:GetJIKDiagnostics() return copyTable(JIK.Diagnostics) end

--------------------------------------------------------------------------------
-- LongJump Jade integration marker. games/6872274481.lua installs the adapter inside LongJump's
-- own method table, where its private JumpTick/JumpSpeed/Direction state can be updated. Wrapping
-- the module callback here used to activate Jade and return before those private values were set,
-- so the cast was detected but LongJump never entered its boost window.
--------------------------------------------------------------------------------
function Runtime:InstallLongJumpJadeHook(longJumpModule)
    if not longJumpModule or longJumpModule._AetherJadeV2Hook then return end
    longJumpModule._AetherJadeV2Hook=true
end

Runtime:InstallLongJumpJadeHook(moduleByName('LongJump'))

shared.AetherBedWarsRuntime=Runtime
return Runtime

end
    local loaded, result = xpcall(function()
        return registerAetherRuntime(context)
    end, debug and debug.traceback or tostring)
    if not loaded or type(result) ~= 'table' then
        warn('[AetherV2] AutoWin/JIK runtime failed: '..tostring(result))
        notif('AetherV2', 'AutoWin/Jade runtime failed to start. Check the console.', 8, 'warning')
        return
    end
    AetherMatchRuntime = result

    ----------------------------------------------------------------------------------------------
    -- AutoWin/Jade integration hardening (direct implementation)
    ----------------------------------------------------------------------------------------------
local function patchAetherRuntime(Runtime, ctx)
-- AutoWin/Jade hardening layer, compiled directly beside the reactive runtime.

assert(type(Runtime) == 'table' and type(ctx) == 'table', 'runtime hardening requires runtime + context')

local bedwars = ctx.bedwars
local store = ctx.store
local lplr = ctx.lplr
local entitylib = ctx.entitylib
local runService = ctx.runService
local replicatedStorage = ctx.replicatedStorage
local gameCamera = ctx.gameCamera or workspace.CurrentCamera
local switchItem = ctx.switchItem
local getItem = ctx.getItem
local isnetworkowner = ctx.isnetworkowner or function() return true end
local safePlaceBlock = ctx.placeBlock or bedwars.placeBlock
local safeBreakBlock = ctx.breakBlock or bedwars.breakBlock
local breakmethods = ctx.breakmethods or {}

local function now()
    return tick()
end

local function protected(label, fn, ...)
    if type(fn) ~= 'function' then return false, 'missing function' end
    local ok, result = pcall(fn, ...)
    if not ok then
        Runtime.Errors[label] = {At = now(), Error = tostring(result)}
    end
    return ok, result
end

local function moduleByName(name)
    local vape = ctx.vape
    if vape.Modules and vape.Modules[name] then return vape.Modules[name] end
    for _, panel in {vape.Kits, vape.Legit} do
        if panel and panel.Modules and panel.Modules[name] then return panel.Modules[name] end
    end
end

local function option(name)
    return Runtime.AutoWin and Runtime.AutoWin.Options and Runtime.AutoWin.Options[name]
end

local function optionEnabled(name, fallback)
    local value = option(name)
    if value and value.Enabled ~= nil then return value.Enabled end
    return fallback
end

local function optionValue(name, fallback)
    local value = option(name)
    if value and value.Value ~= nil then return value.Value end
    return fallback
end

--------------------------------------------------------------------------------
-- Module leases: add explicit enable/disable leases.
-- The core implementation already restores option values only if they still equal the value the
-- lease wrote. This adds the same rule to module enabled-state restoration, which is required for
-- temporarily suspending legacy movement writers while JIK owns movement.
--------------------------------------------------------------------------------
local leases = Runtime.ModuleLeases
local coreAcquire = leases.Acquire

function leases:Acquire(owner, name, wantedOptions, desiredEnabled)
    if owner == 'AutoWin' and desiredEnabled ~= false and not optionEnabled('Take over modules', true) then
        return nil, 'takeover-disabled'
    end

    local module = moduleByName(name)
    if not module then return nil, 'missing module' end
    local before = module.Enabled and true or false
    local lease, reason = coreAcquire(self, owner, name, wantedOptions, desiredEnabled)
    if not lease then return nil, reason end

    local writtenEnabled
    if desiredEnabled == false and module.Enabled then
        protected('lease.disable.'..name, function() module:Toggle(true) end)
        if module.Enabled == false then writtenEnabled = false end
    elseif desiredEnabled == true and not module.Enabled then
        protected('lease.enable.'..name, function() module:Toggle(true) end)
        if module.Enabled == true then writtenEnabled = true end
    elseif before ~= module.Enabled then
        writtenEnabled = module.Enabled and true or false
    end

    local coreRelease = lease.Release
    lease.Release = function(self)
        if self.Released then return end
        local moduleNow = self.Module
        local shouldRestore = writtenEnabled ~= nil and moduleNow and moduleNow.Enabled == writtenEnabled
        -- Stop the core release from applying its older enabled-state restoration. Options are
        -- still restored by it using its stale-write guard.
        self.WroteEnabled = nil
        coreRelease(self)
        if shouldRestore and moduleNow.Enabled ~= before then
            protected('lease.restore-state.'..name, function() moduleNow:Toggle(true) end)
        end
    end
    return lease
end

--------------------------------------------------------------------------------
-- Generic traversal adapter registry.
--------------------------------------------------------------------------------
local Traversal = {Adapters = {}}
Runtime.TraversalAdapters = Traversal

function Traversal:Register(name, adapter)
    adapter.Name = name
    self.Adapters[name] = adapter
end

function Traversal:Candidates(segment, snapshot)
    local list = {}
    for name, adapter in pairs(self.Adapters) do
        local ok, score, info = protected('traversal.can.'..name, adapter.CanTraverse, adapter, segment, snapshot)
        if ok and score then table.insert(list, {Name = name, Adapter = adapter, Score = score, Info = info}) end
    end
    table.sort(list, function(a, b) return a.Score > b.Score end)
    return list
end

function Traversal:Try(segment, snapshot, cancelled)
    for _, candidate in ipairs(self:Candidates(segment, snapshot)) do
        local ok, success, reason = pcall(candidate.Adapter.Execute, candidate.Adapter, segment, snapshot, candidate.Info, cancelled)
        if ok and success then return true, candidate.Name, reason end
        Runtime.Errors['traversal.'..candidate.Name] = ok and {At = now(), Error = tostring(reason)} or {At = now(), Error = tostring(success)}
    end
    return false, nil, 'no-adapter-succeeded'
end

--------------------------------------------------------------------------------
-- Yuzi traversal adapter.
-- Uses the live controller first, verifies cooldown/movement change, and only then lets traversal
-- skip the bridge segment. A failed dash never changes RoutePlan.RequiredBlocks, so normal bridging
-- remains the guaranteed fallback and resource planning cannot forget the blocks it may still need.
--------------------------------------------------------------------------------
local DAO_TIERS = {'wood_dao', 'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'}
local dashRay = RaycastParams.new()
dashRay.RespectCanCollide = true
dashRay.FilterType = Enum.RaycastFilterType.Exclude

local function bestDao()
    for index = #DAO_TIERS, 1, -1 do
        local item = getItem(DAO_TIERS[index])
        if item and item.tool then return item end
    end
end

local function yuziKit()
    local kit = store.equippedKit
    if kit == nil or kit == '' then kit = lplr:GetAttribute('PlayingAsKit') or lplr:GetAttribute('PlayingAsKits') end
    kit = string.lower(tostring(kit or ''))
    return kit == 'yuzi' or kit == 'dasher'
end

local YuziAdapter = {}
function YuziAdapter:CanTraverse(segment, snapshot)
    if not optionEnabled('Yuzi dash', true) or not yuziKit() or segment.Kind ~= 'Bridge' then return nil end
    if not segment.Cells or #segment.Cells < 3 or not snapshot.Position then return nil end
    local dao = bestDao()
    if not dao then return nil end

    local char = lplr.Character
    local nextDash = char and char:GetAttribute('CanDashNext')
    if type(nextDash) == 'number' and nextDash > workspace:GetServerTimeNow() then return nil end

    local lastCell = segment.Cells[math.min(#segment.Cells, 10)]
    local destination = lastCell * 3 + Vector3.new(0, 4, 0)
    local delta = destination - snapshot.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    if flat.Magnitude < 8 or flat.Magnitude > 38 then return nil end

    dashRay.FilterDescendantsInstances = {lplr.Character, gameCamera}
    local origin = snapshot.Position + Vector3.new(0, 2, 0)
    local beam = Vector3.new(destination.X, origin.Y, destination.Z) - origin
    if workspace:Raycast(origin, beam, dashRay) then return nil end
    local landing = workspace:Raycast(destination + Vector3.new(0, 10, 0), Vector3.new(0, -65, 0), dashRay)
    if not landing then return nil end

    return 100 + math.min(#segment.Cells, 10), {Dao = dao, Destination = destination, Direction = flat.Unit, BeforeDash = nextDash}
end

function YuziAdapter:Execute(_, snapshot, info, cancelled)
    local root = entitylib.isAlive and entitylib.character and entitylib.character.RootPart
    if not root or not isnetworkowner(root) then return false, 'movement-unavailable' end
    switchItem(info.Dao.tool, 0.05)
    local heldDeadline = now() + 0.7
    repeat
        if cancelled and cancelled() then return false, 'cancelled' end
        local hand = store.hand
        if hand and (hand.tool == info.Dao.tool or hand.itemType == info.Dao.itemType) then break end
        task.wait(0.03)
    until now() >= heldDeadline
    local hand = store.hand
    if not hand or (hand.tool ~= info.Dao.tool and hand.itemType ~= info.Dao.itemType) then return false, 'dao-not-held' end

    local data = {direction = info.Direction, origin = root.Position, weapon = info.Dao.itemType}
    local cast
    if bedwars.AbilityController and type(bedwars.AbilityController.useAbility) == 'function' then
        local ok, result = pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, 'dash', newproxy(true), data)
        if ok and result ~= false then cast = true end
        if not cast then
            ok, result = pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, 'dash', data)
            if ok and result ~= false then cast = true end
        end
    end
    if not cast then
        local ok = pcall(function()
            local events = replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events']
            events.useAbility:FireServer('dash', data)
        end)
        cast = ok
    end
    if not cast then return false, 'dash-request-failed' end

    local beforePosition = root.Position
    local beforeVelocity = root.AssemblyLinearVelocity
    local deadline = now() + 0.65
    repeat
        if cancelled and cancelled() then return false, 'cancelled' end
        if not root.Parent then return false, 'character-lost' end
        local changedCooldown = type(lplr.Character:GetAttribute('CanDashNext')) == 'number'
            and lplr.Character:GetAttribute('CanDashNext') > workspace:GetServerTimeNow()
        local moved = (root.Position - beforePosition).Magnitude > 2
        local accelerated = (root.AssemblyLinearVelocity - beforeVelocity).Magnitude > 15
        if changedCooldown and (moved or accelerated) then return true, 'dash-confirmed' end
        task.wait(0.03)
    until now() >= deadline
    return false, 'dash-not-confirmed'
end
Traversal:Register('Yuzi', YuziAdapter)

--------------------------------------------------------------------------------
-- Route annotation: explicitly records that an ability can substitute for a bridge segment without
-- subtracting fallback blocks from RequiredBlocks.
--------------------------------------------------------------------------------
local navPlan = Runtime.Navigation.Plan
function Runtime.Navigation:Plan(snapshot, goal, objective, allowBreak, cancelled)
    local route, reason = navPlan(self, snapshot, goal, objective, allowBreak, cancelled)
    if not route then return route, reason end
    route.AbilityCandidates = {}
    for index, segment in ipairs(route.Segments) do
        local candidates = Traversal:Candidates(segment, snapshot)
        if candidates[1] then
            route.AbilityCandidates[index] = candidates[1].Name
            segment.AbilityCandidate = candidates[1].Name
            route.ExpectedTime = math.max(0, route.ExpectedTime - math.min(#(segment.Cells or {}) * 3 / 16, 1.2))
        end
    end
    return route
end

--------------------------------------------------------------------------------
-- Incremental travel action used by the director. This replaces the director's main objective
-- travel leaf so route-segment ability substitution and legacy config ranges are actually consumed.
--------------------------------------------------------------------------------
local ActionState = Runtime.ActionState
local ReactiveTravel = {}
ReactiveTravel.__index = ReactiveTravel

function ReactiveTravel.new(director, objective, route)
    return setmetatable({
        Kind = 'Travel', State = ActionState.RUNNING, Reason = nil, Started = now(), ProgressAt = now(), Cancelled = false,
        Data = {Director = director, Objective = objective, Route = route, Segment = 1, Cell = 1, Lease = nil, Best = math.huge, StallAt = now(), AbilityTried = {}}
    }, ReactiveTravel)
end

function ReactiveTravel:Finish(state, reason)
    self.State, self.Reason = state, reason
    return state, reason
end

function ReactiveTravel:Cleanup()
    if self.Data.Lease then self.Data.Lease:Release(); self.Data.Lease = nil end
    local char = entitylib.character
    if char and char.Humanoid then protected('travel.stop', char.Humanoid.Move, char.Humanoid, Vector3.zero, false) end
end

function ReactiveTravel:Cancel(reason)
    if self.State ~= ActionState.RUNNING then return end
    self.Cancelled = true
    self:Cleanup()
    self:Finish(ActionState.CANCELLED, reason or 'cancelled')
end

function ReactiveTravel:Tick(director, snapshot)
    if self.Cancelled then return self.State, self.Reason end
    local route, objective = self.Data.Route, self.Data.Objective
    if not snapshot.Alive or not snapshot.Position or not objective.Position then self:Cleanup(); return self:Finish(ActionState.CANCELLED, 'character-or-target-lost') end
    objective.Position = objective.Target and objective.Target.RootPart and objective.Target.RootPart.Position or objective.Position
    if (snapshot.Position - objective.Position).Magnitude <= (objective.StopRange or 8) then self:Cleanup(); return self:Finish(ActionState.SUCCESS, 'arrived') end
    if snapshot.Version - route.WorldVersion >= 4 then self:Cleanup(); return self:Finish(ActionState.BLOCKED, 'route-stale') end

    if not self.Data.Lease then
        local lease, reason = Runtime.Movement:Acquire('AutoWin', Runtime.Movement.Priorities.AutoWin, 0.5, function() self:Cancel('movement-preempted') end)
        if not lease then return self:Finish(ActionState.BLOCKED, reason) end
        self.Data.Lease = lease
    else
        self.Data.Lease:Renew(0.5)
    end

    local segment = route.Segments[self.Data.Segment]
    if not segment then self:Cleanup(); return self:Finish(ActionState.BLOCKED, 'route-exhausted') end
    if segment.Kind == 'Wait' then self:Cleanup(); return self:Finish(ActionState.BLOCKED, segment.Reason or 'route-wait') end

    if segment.AbilityCandidate and not self.Data.AbilityTried[self.Data.Segment] then
        self.Data.AbilityTried[self.Data.Segment] = true
        local used = Traversal:Try(segment, snapshot, function() return self.Cancelled or not director.Running end)
        if used then
            self.Data.Segment += 1
            self.Data.Cell = 1
            self.ProgressAt = now()
            self.Data.StallAt = now()
            return ActionState.RUNNING
        end
        -- No route/resource mutation here. We deliberately fall through to the exact same bridge
        -- segment and block budget that existed before the failed ability attempt.
    end

    local cell = segment.Cells and segment.Cells[self.Data.Cell]
    if not cell then self.Data.Segment += 1; self.Data.Cell = 1; return ActionState.RUNNING end
    local root, char = entitylib.character and entitylib.character.RootPart, entitylib.character
    local humanoid = char and char.Humanoid
    if not root or not humanoid then self:Cleanup(); return self:Finish(ActionState.CANCELLED, 'character-lost') end

    if segment.Kind == 'Bridge' and not director.Navigation:SolidAt(cell) then
        if snapshot.Blocks <= 0 or not snapshot.BlockItem then self:Cleanup(); return self:Finish(ActionState.BLOCKED, 'no-blocks') end
        protected('travel.place', safePlaceBlock, director.Navigation:World(cell), snapshot.BlockItem, false)
        director.Navigation:ClearLocalCache()
        return ActionState.RUNNING
    elseif segment.Kind == 'Mine' then
        for _, off in ipairs({Vector3.new(0, 1, 0), Vector3.new(0, 2, 0)}) do
            local block = ctx.getPlacedBlock(director.Navigation:World(cell + off))
            if block then
                protected('travel.mine', safeBreakBlock, block, true, true, nil, true, breakmethods.Distance, 360, false)
                director.Navigation:ClearLocalCache()
                return ActionState.RUNNING
            end
        end
    elseif segment.Kind == 'Climb' and humanoid.FloorMaterial ~= Enum.Material.Air then
        protected('travel.jump', humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Jumping)
    end

    local aim = director.Navigation:World(cell) + Vector3.new(0, (char.HipHeight or 2) + 1.5, 0)
    local delta = (aim - root.Position) * Vector3.new(1, 0, 1)
    if delta.Magnitude < 1.7 then self.Data.Cell += 1; self.ProgressAt = now(); return ActionState.RUNNING end
    protected('travel.move', humanoid.Move, humanoid, delta.Unit, false)

    local remaining = (objective.Position - root.Position).Magnitude
    if remaining < self.Data.Best - 1 then
        self.Data.Best, self.Data.StallAt, self.ProgressAt = remaining, now(), now()
    elseif now() - self.Data.StallAt > 5 then
        self:Cleanup()
        return self:Finish(ActionState.FAILED, 'segment-stalled')
    end
    return ActionState.RUNNING
end
Runtime.ReactiveTravelAction = ReactiveTravel

--------------------------------------------------------------------------------
-- Planner integration with existing config names.
--------------------------------------------------------------------------------
local directorNew = Runtime.MatchDirector.new
function Runtime.MatchDirector.new(module, options, hud)
    local self = directorNew(module, options, hud)
    self.Planner.Options = options
    self.NotBefore = now() + (optionValue('Start delay', 0) or 0)
    return self
end

local plannerScore = Runtime.ObjectivePlanner.Score
function Runtime.ObjectivePlanner:Score(snapshot, navigation, loadout)
    local candidates = plannerScore(self, snapshot, navigation, loadout)
    local options = self.Options
    local killPlayers = not options or not options['Kill players'] or options['Kill players'].Enabled
    local aggression = options and options.Aggression and options.Aggression.Value or 'Balanced'
    local blockFloor = options and options['Block amount'] and options['Block amount'].Value or 32
    local ironFloor = options and options['Iron amount'] and options['Iron amount'].Value or 16
    local bedReach = options and options['Bed reach'] and options['Bed reach'].Value or 8
    local playerReach = options and options['Player reach'] and options['Player reach'].Value or 8

    for index = #candidates, 1, -1 do
        local objective = candidates[index]
        if not killPlayers and (objective.Kind == 'HUNT_FINAL' or objective.Kind == 'IMMEDIATE_THREAT') then
            table.remove(candidates, index)
        else
            if objective.Kind == 'ATTACK_BED' then
                objective.StopRange = bedReach
                if aggression == 'Safe' then objective.Score -= (objective.Bed and objective.Bed.Shielded and 80 or 0) + (snapshot.LastLife and 40 or 0)
                elseif aggression == 'Blatant' then objective.Score += 25 end
            elseif objective.Kind == 'HUNT_FINAL' or objective.Kind == 'IMMEDIATE_THREAT' then
                objective.StopRange = playerReach
            elseif objective.Kind == 'COLLECT_RESOURCES' then
                objective.TargetIron = math.max(objective.TargetIron or 0, ironFloor)
            end
        end
    end

    local hasPurchase = false
    for _, objective in ipairs(candidates) do if objective.Kind == 'PURCHASE_LOADOUT' then hasPurchase = true break end end
    if snapshot.Blocks < math.min(blockFloor, 48) and #snapshot.Shops > 0 and not hasPurchase then
        local shop = snapshot.Shops[1]
        table.insert(candidates, {Kind = 'PURCHASE_LOADOUT', Score = 690, Target = shop, Position = shop.Position, StopRange = 16})
    end

    if options and options['Bank loot'] and options['Bank loot'].Enabled and (snapshot.Diamond + snapshot.Emerald >= 3 or (snapshot.LastLife and snapshot.Diamond + snapshot.Emerald > 0)) then
        table.insert(candidates, {Kind = 'BANK', Score = snapshot.LastLife and 745 or 545})
    end
    table.sort(candidates, function(a, b) return a.Score > b.Score end)
    return candidates
end

local makeAction = Runtime.MatchDirector._makeAction
local SimpleBankAction = {}
SimpleBankAction.__index = SimpleBankAction
function SimpleBankAction.new()
    return setmetatable({Kind = 'Bank', State = ActionState.RUNNING, Reason = nil, Started = now(), ProgressAt = now(), Lease = nil}, SimpleBankAction)
end
function SimpleBankAction:Cancel(reason) if self.Lease then self.Lease:Release() end; self.State = ActionState.CANCELLED; self.Reason = reason end
function SimpleBankAction:Tick()
    if not self.Lease then self.Lease = Runtime.ModuleLeases:Acquire('AutoWin', 'AutoBank', {}, true) end
    if not self.Lease then self.State, self.Reason = ActionState.BLOCKED, 'autobank-unavailable'; return self.State, self.Reason end
    self.ProgressAt = now()
    if now() - self.Started > 0.8 then self.Lease:Release(); self.Lease = nil; self.State, self.Reason = ActionState.SUCCESS, 'bank-window-complete'; return self.State, self.Reason end
    return ActionState.RUNNING
end

function Runtime.MatchDirector:_makeAction(objective, snapshot)
    if objective.Kind == 'BANK' then return SimpleBankAction.new() end
    if objective.Kind == 'RETURN_SAFE' then
        local route = self:_routeFor(objective, snapshot)
		if route then return ReactiveTravel.new(self, objective, route) end
		return nil, 'safe-route-unavailable'
    end
    if objective.Kind == 'ATTACK_BED' and snapshot.Position and objective.Position and (snapshot.Position - objective.Position).Magnitude > 26 then
        local route = self:_routeFor(objective, snapshot)
        if not route then return nil, 'route-unavailable' end
        local blockFloor = optionValue('Block amount', 32)
        route.RequiredBlocks = math.max(route.RequiredBlocks, route.RequiredBlocks > 0 and blockFloor or math.min(blockFloor, 8))
        local loadout = self.Loadout:Evaluate(snapshot, route)
        if snapshot.Blocks < loadout.RequiredBlocks then
            local shop = self:_nearestShop(snapshot)
            if shop then return makeAction(self, {Kind = 'PURCHASE_LOADOUT', Target = shop, Position = shop.Position, StopRange = 16, Score = objective.Score + 1}, snapshot) end
            local gen = self:_nearestGenerator(snapshot)
            if gen then return makeAction(self, {Kind = 'COLLECT_RESOURCES', Target = gen, Position = gen.Position, TargetIron = math.max(optionValue('Iron amount', 16), loadout.IronDeficit + snapshot.Iron), StopRange = 8}, snapshot) end
        end
        return ReactiveTravel.new(self, objective, route)
    end
    return makeAction(self, objective, snapshot)
end

--------------------------------------------------------------------------------
-- Director lifecycle hardening: Start Delay, AutoBuy conflict prevention and narrow watchdog reset.
--------------------------------------------------------------------------------
local directorStart = Runtime.MatchDirector.Start
function Runtime.MatchDirector:Start()
    if optionEnabled('Take over modules', true) then
        -- AutoWin V7 owns its purchase plan. Prevent AutoBuy's independent loop from spending the
        -- same resources while PurchaseAction is deciding from RoutePlan, then restore it safely.
        Runtime.ModuleLeases:Acquire('AutoWin', 'AutoBuy', {}, false)
    end
    directorStart(self)
end

local directorTick = Runtime.MatchDirector.Tick
function Runtime.MatchDirector:Tick()
    if self.NotBefore and now() < self.NotBefore then
        local snapshot = self.Snapshot:Refresh()
        self.Objective = {Kind = 'WAIT', Score = 1000, Reason = 'start-delay'}
        self:UpdateHUD(snapshot)
        return
    end
    return directorTick(self)
end

-- Respect old Show HUD setting immediately after construction/config load.
if Runtime.AutoWin and Runtime.AutoWin.Children then
    Runtime.AutoWin.Children.Visible = optionEnabled('Show HUD', true) and Runtime.AutoWin.Enabled
end

return Runtime

end
    local patched, patchResult = xpcall(function()
        return patchAetherRuntime(AetherMatchRuntime, context)
    end, debug and debug.traceback or tostring)
    if not patched then warn('[AetherV2] AutoWin/JIK integration patch failed: '..tostring(patchResult)) end

    ----------------------------------------------------------------------------------------------
    -- Additional BedWars modules (direct implementation)
    ----------------------------------------------------------------------------------------------
local function registerAetherPorts(Runtime, ctx)
-- AetherV2 BedWars ports derived from the AlSploit implementations requested for PR #144.
-- The original behaviours are adapted to Aether's module lifecycle, entitylib targeting,
-- movement leases, live BedWars controllers and cleanup rules.

assert(type(Runtime) == 'table', 'AlSploit ports require AetherMatchRuntime')
assert(type(ctx) == 'table', 'AlSploit ports require match context')

local vape = assert(ctx.vape, 'missing vape')
local entitylib = assert(ctx.entitylib, 'missing entitylib')
local bedwars = assert(ctx.bedwars, 'missing bedwars')
local store = assert(ctx.store, 'missing store')
local lplr = assert(ctx.lplr, 'missing local player')
local runService = assert(ctx.runService, 'missing RunService')
local gameCamera = ctx.gameCamera or workspace.CurrentCamera
local getItem = assert(ctx.getItem, 'missing getItem')
local notif = ctx.notif or function() end
local workspaceService = game:GetService('Workspace')

local Ports = {Version = 1, Modules = {}, Diagnostics = {}}
Runtime.AlSploitPorts = Ports

local function safe(label, fn, ...)
    if type(fn) ~= 'function' then return false, 'missing function' end
    local ok, result = pcall(fn, ...)
    if not ok then
        Ports.Diagnostics[label] = {At = tick(), Error = tostring(result)}
        return false, result
    end
    return true, result
end

local function notify(text, duration, kind)
    safe('notify', notif, 'AetherV2', text, duration or 3, kind)
end

local function rootOfLocal()
    local char = entitylib.character
    if entitylib.isAlive and char and char.RootPart and char.RootPart.Parent then
        return char.RootPart, char, char.Humanoid
    end
    local character = lplr.Character
    local root = character and (character.PrimaryPart or character:FindFirstChild('HumanoidRootPart'))
    local humanoid = character and character:FindFirstChildOfClass('Humanoid')
    if root and humanoid and humanoid.Health > 0 then return root, character, humanoid end
end

local function matchRunning()
    local match = Runtime.BedWarsAPI and Runtime.BedWarsAPI.Match
    if not match then return store.matchState ~= 0 end
    local state = match:GetState()
    return state == match.States.RUNNING
end

local function equippedKit()
    local kits = Runtime.BedWarsAPI and Runtime.BedWarsAPI.Kits
    if kits then return select(1, kits:GetEquipped()) end
    return store.equippedKit or lplr:GetAttribute('PlayingAsKit')
end

local function horizontalUnit(vector)
    if not vector then return nil end
    local flat = Vector3.new(vector.X, 0, vector.Z)
    return flat.Magnitude > 0.01 and flat.Unit or nil
end

local function moduleByName(name)
    return vape.Modules and vape.Modules[name] or nil
end

local function register(categoryName, name, definition)
    local existing = moduleByName(name)
    if existing then
        Ports.Modules[name] = existing
        Ports.Diagnostics['duplicate.'..name] = {At = tick(), Existing = true}
        return existing, false
    end
    local category = vape.Categories and vape.Categories[categoryName]
    assert(category and type(category.CreateModule) == 'function', 'missing Aether category '..categoryName)
    definition.Name = name
    local module = category:CreateModule(definition)
    Ports.Modules[name] = module
    return module, true
end

local function abilityController()
    return bedwars.AbilityController or (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.AbilityController)
end

local function canUseAbility(name)
    local controller = abilityController()
    if not controller then return false end
    if type(controller.canUseAbility) == 'function' then
        local ok, result = pcall(controller.canUseAbility, controller, name, {disableBlockedAbilityAlert = true})
        if ok then return result ~= false end
    end
    return true
end

local function useAbility(name)
    local controller = abilityController()
    if not controller or type(controller.useAbility) ~= 'function' then return false, 'missing AbilityController' end
    local ok, result = pcall(controller.useAbility, controller, name)
    return ok and result ~= false, result
end

local function nearestTarget(range, includeNPCs)
    local root = rootOfLocal()
    if not root then return nil end
    local ok, target = pcall(entitylib.EntityPosition, {
        Origin = root.Position,
        Range = range,
        Part = 'RootPart',
        Players = true,
        NPCs = includeNPCs and true or false
    })
    return ok and target or nil
end

local function waitCancelable(seconds, cancelled, step)
    local deadline = tick() + seconds
    repeat
        if cancelled and cancelled() then return false end
        task.wait(step or 0.03)
    until tick() >= deadline
    return true
end

local function addMovementOwner(name)
    local movement = Runtime.Movement
    if not movement or not movement.ExternalNames then return end
    if not table.find(movement.ExternalNames, name) then table.insert(movement.ExternalNames, name) end
end

for _, name in ipairs({'JadeExploit', 'AntiHitBETA'}) do addMovementOwner(name) end

--------------------------------------------------------------------------------
-- YaminiExploit
--------------------------------------------------------------------------------
local YaminiExploit
local yaminiCreated
local YaminiOptions = {}
local yaminiGeneration = 0
YaminiExploit, yaminiCreated = register('Exploits', 'YaminiExploit', {
    Tooltip = 'Automatically uses Yamini/Cat pounce while moving when the ability is ready.',
    Function = function(callback)
        yaminiGeneration = yaminiGeneration + 1
        local generation = yaminiGeneration
        if not callback then return end
        task.spawn(function()
            local lastUse = 0
            while YaminiExploit.Enabled and generation == yaminiGeneration do
                local root, _, humanoid = rootOfLocal()
                local kit = tostring(equippedKit() or ''):lower()
                if root and humanoid and matchRunning() and (kit == 'cat' or kit:find('yamini', 1, true)) and humanoid.MoveDirection.Magnitude > 0 then
                    if tick() - lastUse >= 5.2 and canUseAbility('CAT_POUNCE') then
                        local used = useAbility('CAT_POUNCE')
                        if used then lastUse = tick() end
                    end
                end
                task.wait(1 / math.max(YaminiOptions.SpamSpeed.Value, 1))
            end
        end)
    end
})
if yaminiCreated then
    YaminiOptions.SpamSpeed = YaminiExploit:CreateSlider({Name = 'Spam speed', Min = 1, Max = 100, Default = 100, Suffix = ' checks/s'})
end

--------------------------------------------------------------------------------
-- JadeExploit
--------------------------------------------------------------------------------
local JadeExploit
local jadeCreated
local JadeOptions = {}
local jadeGeneration = 0
local jadeBusy = false

local function runJadeExploit(generation)
    if jadeBusy or not Runtime.Jade then return end
    local root, _, humanoid = rootOfLocal()
    if not root or not humanoid or humanoid.MoveDirection.Magnitude <= 0 or not matchRunning() then return end

    local target = JadeOptions.Smash.Enabled and nearestTarget(20, JadeOptions.Entities.Enabled) or nil
    if not target and not JadeOptions.Speed.Enabled then return end

    jadeBusy = true
    local cancelled = function()
        return not JadeExploit.Enabled or generation ~= jadeGeneration or not entitylib.isAlive
    end
    local movement = Runtime.Movement
    local lease
    local ok, err = xpcall(function()
        local hammer = Runtime.Jade:GetBestHammer()
        if not hammer then return end
        local ability = Runtime.Jade:ResolveAbility(hammer)
        local state = Runtime.Jade:GetState(ability)
        if state == 'BLOCKED' then return end

        lease = movement and movement:Acquire('JadeExploit', movement.Priorities.Ability, 3.5, nil, true) or nil
        if movement and not lease then return end
        local equipped = Runtime.Jade:Equip(hammer, 0.8, cancelled)
        if not equipped or cancelled() then return end

        root = rootOfLocal()
        if not root then return end
        if target and target.RootPart and target.RootPart.Parent and JadeOptions.Smash.Enabled then
            if (not movement or movement:CanWrite('JadeExploit')) and isnetworkowner(root) then
                root.CFrame = CFrame.new(root.Position + Vector3.new(0, 150, 0)) * root.CFrame.Rotation
            end
            if not waitCancelable(0.5, cancelled) then return end
            local confirmed = Runtime.Jade:RequestActivation(hammer, ability, target.RootPart.Position, cancelled)
            if not confirmed then return end
            local followUntil = tick() + 2.3
            repeat
                if cancelled() or not target.RootPart or not target.RootPart.Parent then break end
                root = rootOfLocal()
                if not root then break end
                if lease then lease:Renew(0.5) end
                if (not movement or movement:CanWrite('JadeExploit')) and isnetworkowner(root) then
                    local direction = horizontalUnit(target.RootPart.Position - root.Position)
                    if direction then
                        local velocity = root.AssemblyLinearVelocity
                        root.AssemblyLinearVelocity = Vector3.new(direction.X * 23.3, velocity.Y, direction.Z * 23.3)
                    end
                end
                task.wait()
            until tick() >= followUntil
        elseif JadeOptions.Speed.Enabled then
            local direction = horizontalUnit(humanoid.MoveDirection) or horizontalUnit(root.CFrame.LookVector)
            Runtime.Jade:RequestActivation(hammer, ability, root.Position + (direction or Vector3.zAxis) * 20, cancelled)
        end
    end, debug and debug.traceback or tostring)
    if not ok then Ports.Diagnostics.JadeExploit = {At = tick(), Error = tostring(err)} end
    if lease then lease:Release() end
    jadeBusy = false
end

JadeExploit, jadeCreated = register('Exploits', 'JadeExploit', {
    Tooltip = 'Auto-uses Jade hammer movement; Smash tracks nearby targets and Speed uses the hammer for movement.',
    Function = function(callback)
        jadeGeneration = jadeGeneration + 1
        local generation = jadeGeneration
        if not callback then jadeBusy = false; return end
        task.spawn(function()
            local lastUse = 0
            while JadeExploit.Enabled and generation == jadeGeneration do
                if tick() - lastUse >= 6 and not jadeBusy then
                    local hammer = Runtime.Jade and Runtime.Jade:GetBestHammer()
                    if hammer and rootOfLocal() then
                        lastUse = tick()
                        task.spawn(runJadeExploit, generation)
                    end
                end
                task.wait(1 / math.max(JadeOptions.SpamSpeed.Value, 1))
            end
        end)
    end
})
if jadeCreated then
    JadeOptions.SpamSpeed = JadeExploit:CreateSlider({Name = 'Spam speed', Min = 1, Max = 100, Default = 100, Suffix = ' checks/s'})
    JadeOptions.Entities = JadeExploit:CreateToggle({Name = 'Entities', Default = false})
    JadeOptions.Speed = JadeExploit:CreateToggle({Name = 'Speed', Default = false})
    JadeOptions.Smash = JadeExploit:CreateToggle({Name = 'Smash', Default = true})
end

--------------------------------------------------------------------------------
-- Shared visual decoy used by AntiHitBETA.
--------------------------------------------------------------------------------
local function createDecoy(followHorizontal)
    local root, character, humanoid = rootOfLocal()
    if not root or not character or not humanoid then return nil end
    local oldArchivable = character.Archivable
    character.Archivable = true
    local ok, clone = pcall(character.Clone, character)
    character.Archivable = oldArchivable
    if not ok or not clone then return nil end

    for _, object in ipairs(clone:GetDescendants()) do
        if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy() end
        if object:IsA('BasePart') then object.CanCollide = false end
        if object:IsA('BasePart') and object.Name == 'Cape' then object:Destroy() end
    end
    clone.Name = 'AetherMovementDecoy'
    clone.Parent = workspaceService
    local cloneRoot = clone.PrimaryPart or clone:FindFirstChild('HumanoidRootPart')
    local cloneHumanoid = clone:FindFirstChildOfClass('Humanoid')
    if not cloneRoot or not cloneHumanoid then clone:Destroy(); return nil end
    clone.PrimaryPart = cloneRoot
    cloneRoot.Anchored = true
    clone:PivotTo(character:GetPivot())
    local originalSubject = gameCamera.CameraSubject
    gameCamera.CameraSubject = cloneHumanoid

    local decoy = {Model = clone, Root = cloneRoot, Humanoid = cloneHumanoid, OriginalSubject = originalSubject, Connection = nil}
    if followHorizontal then
        decoy.Connection = runService.RenderStepped:Connect(function()
            local liveRoot = rootOfLocal()
            if not clone.Parent or not liveRoot then return end
            cloneRoot.CFrame = CFrame.new(liveRoot.Position.X, cloneRoot.Position.Y, liveRoot.Position.Z) * liveRoot.CFrame.Rotation
        end)
    end
    function decoy:Destroy()
        if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
        if gameCamera.CameraSubject == self.Humanoid then
            local _, _, liveHumanoid = rootOfLocal()
            gameCamera.CameraSubject = (self.OriginalSubject and self.OriginalSubject.Parent and self.OriginalSubject) or liveHumanoid
        end
        if self.Model and self.Model.Parent then self.Model:Destroy() end
        self.Model = nil
    end
    return decoy
end

--------------------------------------------------------------------------------
-- AntiHitBETA
--------------------------------------------------------------------------------
local AntiHitBETA
local antiHitCreated
local AntiHitOptions = {}
local antiHitGeneration = 0
local antiHitBusy = false
local antiHitDecoy

local function currentAttackDelay()
    local held = store.hand
    local meta = held and held.itemType and bedwars.ItemMeta and bedwars.ItemMeta[held.itemType]
    local sword = meta and meta.sword
    return sword and tonumber(sword.attackSpeed) or 0.3
end

local function antiHitCleanup()
    if antiHitDecoy then antiHitDecoy:Destroy(); antiHitDecoy = nil end
    antiHitBusy = false
    local movement = Runtime.Movement
    local current = movement and movement.Current
    if current and current.Owner == 'AntiHitBETA' then current:Release() end
end

local function executeAntiHit(generation)
    if antiHitBusy then return end
    local root = rootOfLocal()
    if not root then return end
    antiHitBusy = true
    local movement = Runtime.Movement
    local lease = movement and movement:Acquire('AntiHitBETA', movement.Priorities.Emergency, 1.5, antiHitCleanup, true) or nil
    if movement and not lease then antiHitBusy = false; return end
    local originalY = root.Position.Y
    antiHitDecoy = createDecoy(true)
    local delay = currentAttackDelay()
    local ok, err = xpcall(function()
        if generation ~= antiHitGeneration or not AntiHitBETA.Enabled then return end
        root = rootOfLocal()
        if not root then return end
        if (not movement or movement:CanWrite('AntiHitBETA')) and isnetworkowner(root) then
            root.CFrame = CFrame.new(root.Position + Vector3.new(0, 25, 0)) * root.CFrame.Rotation
        end
        if not waitCancelable(delay, function() return generation ~= antiHitGeneration or not AntiHitBETA.Enabled end) then return end
        root = rootOfLocal()
        if root and (not movement or movement:CanWrite('AntiHitBETA')) and isnetworkowner(root) then
            root.CFrame = CFrame.new(root.Position.X, originalY + 5, root.Position.Z) * root.CFrame.Rotation
        end
        waitCancelable(delay, function() return generation ~= antiHitGeneration or not AntiHitBETA.Enabled end)
    end, debug and debug.traceback or tostring)
    if not ok then Ports.Diagnostics.AntiHitBETA = {At = tick(), Error = tostring(err)} end
    if antiHitDecoy then antiHitDecoy:Destroy(); antiHitDecoy = nil end
    if lease then lease:Release() end
    antiHitBusy = false
end

AntiHitBETA, antiHitCreated = register('Blatant', 'AntiHitBETA', {
    Tooltip = 'BETA dodge port of AlSploit AntiHit using a short vertical displacement and decoy camera.',
    Function = function(callback)
        antiHitGeneration = antiHitGeneration + 1
        local generation = antiHitGeneration
        if not callback then antiHitCleanup(); return end
        AntiHitBETA:Clean(antiHitCleanup)
        task.spawn(function()
            while AntiHitBETA.Enabled and generation == antiHitGeneration do
                if entitylib.isAlive and matchRunning() and not antiHitBusy then
                    local target = nearestTarget(AntiHitOptions.Range.Value, AntiHitOptions.Entities.Enabled)
                    if target then task.spawn(executeAntiHit, generation) end
                end
                task.wait(0.04)
            end
        end)
    end
})
if antiHitCreated then
    AntiHitOptions.Entities = AntiHitBETA:CreateToggle({Name = 'Entities', Default = false})
    AntiHitOptions.Range = AntiHitBETA:CreateSlider({Name = 'Range', Min = 1, Max = 20, Default = 20, Suffix = ' studs'})
end

--------------------------------------------------------------------------------
-- NoFallDamageV2
--------------------------------------------------------------------------------
local NoFallDamageV2
local noFallCreated
local noFallGeneration = 0
local noFallBusy = false
NoFallDamageV2, noFallCreated = register('Blatant', 'NoFallDamageV2', {
    Tooltip = 'AlSploit-style fall-damage prevention: briefly reports a landed state while preserving downward velocity.',
    Function = function(callback)
        noFallGeneration = noFallGeneration + 1
        local generation = noFallGeneration
        noFallBusy = false
        if not callback then return end
        local connection = runService.PostSimulation:Connect(function()
            if noFallBusy or generation ~= noFallGeneration or not NoFallDamageV2.Enabled then return end
            local highJump = moduleByName('HighJump')
            if highJump and highJump.Enabled then return end
            local root, _, humanoid = rootOfLocal()
            if not root or not humanoid then return end
            local velocity = root.AssemblyLinearVelocity
            if velocity.Y >= -45 then return end
            noFallBusy = true
            task.spawn(function()
                local oldY = velocity.Y
                root = rootOfLocal()
                if not root or generation ~= noFallGeneration or not NoFallDamageV2.Enabled then noFallBusy = false; return end
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 44, root.AssemblyLinearVelocity.Z)
                safe('nofall.landed', humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Landed)
                runService.PreSimulation:Wait()
                root = rootOfLocal()
                if root and generation == noFallGeneration and NoFallDamageV2.Enabled then
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, oldY, root.AssemblyLinearVelocity.Z)
                end
                noFallBusy = false
            end)
        end)
        NoFallDamageV2:Clean(connection)
    end
})

return Ports

end
local function registerAetherPortsV2(Runtime, ctx)
-- AetherV2 BedWars ports derived from the AlSploit implementations requested for PR #144.
-- The original behaviours are adapted to Aether's module lifecycle, entitylib targeting,
-- movement leases, live BedWars controllers and cleanup rules.

assert(type(Runtime) == 'table', 'AlSploit ports require AetherMatchRuntime')
assert(type(ctx) == 'table', 'AlSploit ports require match context')

local vape = assert(ctx.vape, 'missing vape')
local entitylib = assert(ctx.entitylib, 'missing entitylib')
local bedwars = assert(ctx.bedwars, 'missing bedwars')
local store = assert(ctx.store, 'missing store')
local lplr = assert(ctx.lplr, 'missing local player')
local runService = assert(ctx.runService, 'missing RunService')
local gameCamera = ctx.gameCamera or workspace.CurrentCamera
local getItem = assert(ctx.getItem, 'missing getItem')
local notif = ctx.notif or function() end
local workspaceService = game:GetService('Workspace')

local Ports = {Version = 1, Modules = {}, Diagnostics = {}}
Runtime.AlSploitPortsV2 = Ports

local function safe(label, fn, ...)
    if type(fn) ~= 'function' then return false, 'missing function' end
    local ok, result = pcall(fn, ...)
    if not ok then
        Ports.Diagnostics[label] = {At = tick(), Error = tostring(result)}
        return false, result
    end
    return true, result
end

local function notify(text, duration, kind)
    safe('notify', notif, 'AetherV2', text, duration or 3, kind)
end

local function rootOfLocal()
    local char = entitylib.character
    if entitylib.isAlive and char and char.RootPart and char.RootPart.Parent then
        return char.RootPart, char, char.Humanoid
    end
    local character = lplr.Character
    local root = character and (character.PrimaryPart or character:FindFirstChild('HumanoidRootPart'))
    local humanoid = character and character:FindFirstChildOfClass('Humanoid')
    if root and humanoid and humanoid.Health > 0 then return root, character, humanoid end
end

local function matchRunning()
    local match = Runtime.BedWarsAPI and Runtime.BedWarsAPI.Match
    if not match then return store.matchState ~= 0 end
    local state = match:GetState()
    return state == match.States.RUNNING
end

local function equippedKit()
    local kits = Runtime.BedWarsAPI and Runtime.BedWarsAPI.Kits
    if kits then return select(1, kits:GetEquipped()) end
    return store.equippedKit or lplr:GetAttribute('PlayingAsKit')
end

local function horizontalUnit(vector)
    if not vector then return nil end
    local flat = Vector3.new(vector.X, 0, vector.Z)
    return flat.Magnitude > 0.01 and flat.Unit or nil
end

local function moduleByName(name)
    return vape.Modules and vape.Modules[name] or nil
end

local function register(categoryName, name, definition)
    local existing = moduleByName(name)
    if existing then
        Ports.Modules[name] = existing
        Ports.Diagnostics['duplicate.'..name] = {At = tick(), Existing = true}
        return existing, false
    end
    local category = vape.Categories and vape.Categories[categoryName]
    if not category and categoryName == 'Kits' then
        category = vape.Categories and (vape.Categories.Kits or vape.Categories.Minigames)
    elseif not category and categoryName == 'Exploits' then
        category = vape.Categories and (vape.Categories.Exploits or vape.Categories.Exploit)
    end
    assert(category and type(category.CreateModule) == 'function', 'missing Aether category '..categoryName)
    definition.Name = name
    local module = category:CreateModule(definition)
    Ports.Modules[name] = module
    return module, true
end

local function abilityController()
    return bedwars.AbilityController or (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.AbilityController)
end

local function canUseAbility(name)
    local controller = abilityController()
    if not controller then return false end
    if type(controller.canUseAbility) == 'function' then
        local ok, result = pcall(controller.canUseAbility, controller, name, {disableBlockedAbilityAlert = true})
        if ok then return result ~= false end
    end
    return true
end

local function useAbility(name)
    local controller = abilityController()
    if not controller or type(controller.useAbility) ~= 'function' then return false, 'missing AbilityController' end
    local ok, result = pcall(controller.useAbility, controller, name)
    return ok and result ~= false, result
end

local function nearestTarget(range, includeNPCs)
    local root = rootOfLocal()
    if not root then return nil end
    local ok, target = pcall(entitylib.EntityPosition, {
        Origin = root.Position,
        Range = range,
        Part = 'RootPart',
        Players = true,
        NPCs = includeNPCs and true or false
    })
    return ok and target or nil
end

local function waitCancelable(seconds, cancelled, step)
    local deadline = tick() + seconds
    repeat
        if cancelled and cancelled() then return false end
        task.wait(step or 0.03)
    until tick() >= deadline
    return true
end

--------------------------------------------------------------------------------
-- Shared visual decoy used by AntiHitBETA.
--------------------------------------------------------------------------------
local function createDecoy(followHorizontal)
    local root, character, humanoid = rootOfLocal()
    if not root or not character or not humanoid then return nil end
    local oldArchivable = character.Archivable
    character.Archivable = true
    local ok, clone = pcall(character.Clone, character)
    character.Archivable = oldArchivable
    if not ok or not clone then return nil end

    for _, object in ipairs(clone:GetDescendants()) do
        if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy() end
        if object:IsA('BasePart') then object.CanCollide = false end
        if object:IsA('BasePart') and object.Name == 'Cape' then object:Destroy() end
    end
    clone.Name = 'AetherMovementDecoy'
    clone.Parent = workspaceService
    local cloneRoot = clone.PrimaryPart or clone:FindFirstChild('HumanoidRootPart')
    local cloneHumanoid = clone:FindFirstChildOfClass('Humanoid')
    if not cloneRoot or not cloneHumanoid then clone:Destroy(); return nil end
    clone.PrimaryPart = cloneRoot
    cloneRoot.Anchored = true
    clone:PivotTo(character:GetPivot())
    local originalSubject = gameCamera.CameraSubject
    gameCamera.CameraSubject = cloneHumanoid

    local decoy = {Model = clone, Root = cloneRoot, Humanoid = cloneHumanoid, OriginalSubject = originalSubject, Connection = nil}
    if followHorizontal then
        decoy.Connection = runService.RenderStepped:Connect(function()
            local liveRoot = rootOfLocal()
            if not clone.Parent or not liveRoot then return end
            cloneRoot.CFrame = CFrame.new(liveRoot.Position.X, cloneRoot.Position.Y, liveRoot.Position.Z) * liveRoot.CFrame.Rotation
        end)
    end
    function decoy:Destroy()
        if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
        if gameCamera.CameraSubject == self.Humanoid then
            local _, _, liveHumanoid = rootOfLocal()
            gameCamera.CameraSubject = (self.OriginalSubject and self.OriginalSubject.Parent and self.OriginalSubject) or liveHumanoid
        end
        if self.Model and self.Model.Parent then self.Model:Destroy() end
        self.Model = nil
    end
    return decoy
end

--------------------------------------------------------------------------------
-- AntiHitBETA
--------------------------------------------------------------------------------
local AntiHitBETA
local antiHitCreated
local AntiHitOptions = {}
local antiHitGeneration = 0
local antiHitBusy = false
local antiHitDecoy

local function currentAttackDelay()
    local held = store.hand
    local meta = held and held.itemType and bedwars.ItemMeta and bedwars.ItemMeta[held.itemType]
    local sword = meta and meta.sword
    return sword and tonumber(sword.attackSpeed) or 0.3
end

local function antiHitCleanup()
    if antiHitDecoy then antiHitDecoy:Destroy(); antiHitDecoy = nil end
    antiHitBusy = false
    local movement = Runtime.Movement
    local current = movement and movement.Current
    if current and current.Owner == 'AntiHitBETA' then current:Release() end
end

local function executeAntiHit(generation)
    if antiHitBusy then return end
    local root = rootOfLocal()
    if not root then return end
    antiHitBusy = true
    local movement = Runtime.Movement
    local lease = movement and movement:Acquire('AntiHitBETA', movement.Priorities.Emergency, 1.5, antiHitCleanup, true) or nil
    if movement and not lease then antiHitBusy = false; return end
    local originalY = root.Position.Y
    antiHitDecoy = createDecoy(true)
    local delay = currentAttackDelay()
    local ok, err = xpcall(function()
        if generation ~= antiHitGeneration or not AntiHitBETA.Enabled then return end
        root = rootOfLocal()
        if not root then return end
        if (not movement or movement:CanWrite('AntiHitBETA')) and isnetworkowner(root) then
            root.CFrame = CFrame.new(root.Position + Vector3.new(0, 25, 0)) * root.CFrame.Rotation
        end
        if not waitCancelable(delay, function() return generation ~= antiHitGeneration or not AntiHitBETA.Enabled end) then return end
        root = rootOfLocal()
        if root and (not movement or movement:CanWrite('AntiHitBETA')) and isnetworkowner(root) then
            root.CFrame = CFrame.new(root.Position.X, originalY + 5, root.Position.Z) * root.CFrame.Rotation
        end
        waitCancelable(delay, function() return generation ~= antiHitGeneration or not AntiHitBETA.Enabled end)
    end, debug and debug.traceback or tostring)
    if not ok then Ports.Diagnostics.AntiHitBETA = {At = tick(), Error = tostring(err)} end
    if antiHitDecoy then antiHitDecoy:Destroy(); antiHitDecoy = nil end
    if lease then lease:Release() end
    antiHitBusy = false
end

AntiHitBETA, antiHitCreated = register('Blatant', 'AntiHitBETA', {
    Tooltip = 'BETA dodge port of AlSploit AntiHit using a short vertical displacement and decoy camera.',
    Function = function(callback)
        antiHitGeneration = antiHitGeneration + 1
        local generation = antiHitGeneration
        if not callback then antiHitCleanup(); return end
        AntiHitBETA:Clean(antiHitCleanup)
        task.spawn(function()
            while AntiHitBETA.Enabled and generation == antiHitGeneration do
                if entitylib.isAlive and matchRunning() and not antiHitBusy then
                    local target = nearestTarget(AntiHitOptions.Range.Value, AntiHitOptions.Entities.Enabled)
                    if target then task.spawn(executeAntiHit, generation) end
                end
                task.wait(0.04)
            end
        end)
    end
})
if antiHitCreated then
    AntiHitOptions.Entities = AntiHitBETA:CreateToggle({Name = 'Entities', Default = false})
    AntiHitOptions.Range = AntiHitBETA:CreateSlider({Name = 'Range', Min = 1, Max = 20, Default = 20, Suffix = ' studs'})
end

--------------------------------------------------------------------------------
-- NoFallDamageV2
--------------------------------------------------------------------------------
local NoFallDamageV2
local noFallCreated
local noFallGeneration = 0
local noFallBusy = false
NoFallDamageV2, noFallCreated = register('Blatant', 'NoFallDamageV2', {
    Tooltip = 'AlSploit-style fall-damage prevention: briefly reports a landed state while preserving downward velocity.',
    Function = function(callback)
        noFallGeneration = noFallGeneration + 1
        local generation = noFallGeneration
        noFallBusy = false
        if not callback then return end
        local connection = runService.PostSimulation:Connect(function()
            if noFallBusy or generation ~= noFallGeneration or not NoFallDamageV2.Enabled then return end
            local highJump = moduleByName('HighJump')
            if highJump and highJump.Enabled then return end
            local root, _, humanoid = rootOfLocal()
            if not root or not humanoid then return end
            local velocity = root.AssemblyLinearVelocity
            if velocity.Y >= -45 then return end
            noFallBusy = true
            task.spawn(function()
                local oldY = velocity.Y
                root = rootOfLocal()
                if not root or generation ~= noFallGeneration or not NoFallDamageV2.Enabled then noFallBusy = false; return end
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 44, root.AssemblyLinearVelocity.Z)
                safe('nofall.landed', humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Landed)
                runService.PreSimulation:Wait()
                root = rootOfLocal()
                if root and generation == noFallGeneration and NoFallDamageV2.Enabled then
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, oldY, root.AssemblyLinearVelocity.Z)
                end
                noFallBusy = false
            end)
        end)
        NoFallDamageV2:Clean(connection)
    end
})


run(function()
    local Value
    local CameraDir
    local LimitItems
    local ChangeDir
    local LongJumpBypass
    local BypassBoost
    local start
    local JumpTick, JumpSpeed, Direction = tick(), 0
    local jumpWasActive = false
	local function horizontalDirection(direction)
		local flat = direction and Vector3.new(direction.X, 0, direction.Z) or Vector3.zero
		if flat.Magnitude > 0.001 then return flat.Unit end
		local look = entitylib.isAlive and entitylib.character.RootPart.CFrame.LookVector or Vector3.zAxis
		flat = Vector3.new(look.X, 0, look.Z)
		return flat.Magnitude > 0.001 and flat.Unit or Vector3.zAxis
	end
    local projectileRemote = {InvokeServer = function() end}
    task.spawn(function()
        safe('longjump.projectile.remote', function()
            if bedwars.Client and remotes.FireProjectile then
                projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
            end
        end)
    end)

    local function launchProjectile(item, pos, proj, speed, dir)
        if not pos then return end

        pos = pos - dir * 0.1
        local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
        switchItem(item.tool, 0)
        task.wait(0.1)
        bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
        if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
			local itemMeta = bedwars.ItemMeta[item.itemType]
			local source = itemMeta and itemMeta.projectileSource
			local shoot = source and type(source.launchSound) == 'table' and #source.launchSound > 0 and source.launchSound or nil
			shoot = shoot and shoot[math.random(1, #shoot)] or nil
            if shoot then
                bedwars.SoundManager:playSound(shoot)
            end
        end
    end

    local LongJumpMethods = {
        cannon = function(_, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            bedwars.placeBlock(rounded, 'cannon', false)

            task.delay(0, function()
                local block, blockpos = getPlacedBlock(rounded)
                if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
                    local breaktype = bedwars.ItemMeta[block.Name].block.breakType
                    local tool = getBreakTool(breaktype)
                    if tool then
                        switchItem(tool.tool)
                    end

                    bedwars.Client:Get(remotes.CannonAim):SendToServer({
                        cannonBlockPos = blockpos,
                        lookVector = dir
                    })

                    local broken = 0.1
                    if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
                        broken = 0.4
                        bedwars.breakBlock(block, true, true)
                    end

                    task.delay(broken, function()
                        for _ = 1, 3 do
                            local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
                            if call then
                                bedwars.breakBlock(block, true, true)
                                JumpSpeed = 5.25 * Value.Value
                                JumpTick = tick() + 2.3
								Direction = horizontalDirection(dir)
                                break
                            end
                            task.wait(0.1)
                        end
                    end)
                end
            end)
        end,
        cat = function(_, _, dir)
            LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
                JumpSpeed = 4 * Value.Value
                JumpTick = tick() + 2.5
				Direction = horizontalDirection(dir)
                entitylib.character.RootPart.Velocity = Vector3.zero
            end))

            -- The pounce has to be timed off the frame the game actually leaps, and the only
            -- way to know that is the controller itself. This used to be fired by AutoKit's cat
            -- routine, so cat LongJumps silently did nothing unless that module happened to be
            -- on with the cat toggle ticked; the hook lives here now and is put back on cleanup.
            if bedwars.CatController and typeof(bedwars.CatController.leap) == 'function' then
                local controller = bedwars.CatController
                local original = controller.leap
                local hook
                hook = function(...)
                    vapeEvents.CatPounce:Fire()
                    return original(...)
                end
                controller.leap = hook
                LongJump:Clean(function()
                    if controller.leap == hook then
                        controller.leap = original
                    end
                end)
            end

            if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
                repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
            end

            if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
                bedwars.AbilityController:useAbility('CAT_POUNCE')
            end
        end,
        fireball = function(item, pos, dir)
            launchProjectile(item, pos, 'fireball', 60, dir)
        end,
        grappling_hook = function(item, pos, dir)
            launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
        end,
        jadeHammer = function(item, _, dir)
            local jade = AetherMatchRuntime and AetherMatchRuntime.Jade
            if jade then
                local result = jade:ActivateForTraversal('LongJump', dir, function()
                    return not LongJump.Enabled
                end)
                if not result.confirmed or not LongJump.Enabled then return end
                JumpSpeed = 1.4 * Value.Value
                JumpTick = tick() + 2.5
				Direction = horizontalDirection(dir)
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
				Direction = horizontalDirection(dir)
            end
        end,
        tnt = function(item, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
            bedwars.placeBlock(rounded, item.itemType, false)
        end,
        wood_dao = function(item, pos, dir)
            if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
                repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
            end

            if LongJump.Enabled then
                bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                switchItem(item.tool, 0.1)
                replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
                    direction = dir,
                    origin = pos,
                    weapon = item.itemType
                })
                JumpSpeed = 4.5 * Value.Value
                JumpTick = tick() + 2.4
				Direction = horizontalDirection(dir)
            end
        end
    }
    for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
        LongJumpMethods[v] = LongJumpMethods.wood_dao
    end
    for _, hammer in jadeHammerNames do
        LongJumpMethods[hammer] = LongJumpMethods.jadeHammer
    end
    LongJumpMethods.void_axe = LongJumpMethods.jadeHammer
    LongJumpMethods.siege_tnt = LongJumpMethods.tnt
    LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt

	local function heldLongJumpMethod()
		local hand = store.hand
		local tool = hand and hand.tool
		if not tool then return nil end
		local raw = hand.itemType or tool.Name
		local normalized = tostring(raw):lower():gsub('[%s%-]+', '_')
		local method = LongJumpMethods[raw] or LongJumpMethods[normalized]
		local jadeName = isJadeHammerName(normalized)
		if jadeName then method = LongJumpMethods.jadeHammer end
		if not method then return nil end
		local item = getItem(raw) or getItem(normalized)
		if jadeName and AetherMatchRuntime and AetherMatchRuntime.Jade then
			item = AetherMatchRuntime.Jade:GetBestHammer() or item
		end
		item = item or {itemType = normalized, tool = tool, amount = hand.amount or 1}
		return method, item, normalized
	end

    local LongJumpCreated
    LongJump, LongJumpCreated = register('Blatant', 'LongJump', {
        Name = 'LongJump',
        Function = function(callback)
            frictionTable.LongJump = callback or nil
            updateVelocity()
            if callback then
                -- Limit to items: only engage from a long-jump item you're HOLDING. Without one
                -- the driver below would hold you frozen in place waiting for a jump that can never
                -- come (the module's idle state pins your velocity), so turn straight back off.
				if LimitItems and LimitItems.Enabled and not heldLongJumpMethod() then
                    frictionTable.LongJump = nil
                    updateVelocity()
                    notif('LongJump', 'Hold a long-jump item to use it (Limit to items is on).', 4)
                    return task.spawn(function() if LongJump.Enabled then LongJump:Toggle() end end)
                end
                LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    -- Limit to items: the knockback (Heatseeker) boost isn't item-driven, so skip it.
                    if LimitItems and LimitItems.Enabled then return end
                    if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
                        local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
                            vertical = 0,
                            horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
                        }).Magnitude * 1.1

                        if knockbackBoost >= JumpSpeed then
                            local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
                            if not pos then return end
                            local vec = (entitylib.character.RootPart.Position - pos)
                            JumpSpeed = knockbackBoost
                            JumpTick = tick() + 2.5
                            Direction = Vector3.new(vec.X, 0, vec.Z).Unit
                        end
                    end
                end))
                LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
                    if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
                        local vec = entitylib.character.RootPart.CFrame.LookVector
                        JumpSpeed = 2.5 * Value.Value
                        JumpTick = tick() + 2.5
                        Direction = Vector3.new(vec.X, 0, vec.Z).Unit
                    end
                end))

                start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
                LongJump:Clean(runService.PreSimulation:Connect(function(dt)
                    local root = entitylib.isAlive and entitylib.character.RootPart or nil

                    if root and isnetworkowner(root) then
                        if JumpTick > tick() then
                            if not jumpWasActive then
                                jumpWasActive = true
                                longJumpActivation:Fire(root.AssemblyLinearVelocity)
                            end
                            -- Change direction mid-air: while the boost is running, steer it with
                            -- your movement keys (or where the camera looks) instead of riding the
                            -- fixed line it launched on. MoveDirection is already camera-relative, so
                            -- W/A/S/D bends the boost; with no keys down it holds its current heading.
                            if ChangeDir and ChangeDir.Enabled and Direction then
                                local steer = entitylib.character.Humanoid.MoveDirection
                                steer = Vector3.new(steer.X, 0, steer.Z)
                                if steer.Magnitude < 0.1 and CameraDir and CameraDir.Enabled then
                                    local look = gameCamera.CFrame.LookVector
                                    steer = Vector3.new(look.X, 0, look.Z)
                                end
                                if steer.Magnitude > 0.1 then
                                    Direction = steer.Unit
                                end
                            end
                            root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                            if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
                                root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
                            else
                                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
                            end
                            start = nil
                        else
                            jumpWasActive = false
                            if start then
                                root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
                            end
                            root.AssemblyLinearVelocity = Vector3.zero
                            JumpSpeed = 0
                        end
                    else
                        start = nil
                    end
                end))

				local heldMethod, heldItem = heldLongJumpMethod()
				if heldMethod then
					task.spawn(heldMethod, heldItem, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
                    return
                end

                -- Limit to items: a held item was already required above, so never fall through to
                -- the inventory/kit scan (which is what would otherwise fire a kit-based jump).
                if LimitItems and LimitItems.Enabled then return end

                for i, v in LongJumpMethods do
                    local item = getItem(i)
                    if item or store.equippedKit == i then
                        task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
                        break
                    end
                end
            else
                JumpTick = tick()
                jumpWasActive = false
                Direction = nil
                JumpSpeed = 0
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Lets you jump farther'
    })
    if LongJumpCreated then
        Value = LongJump:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 37,
        Default = 37,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    CameraDir = LongJump:CreateToggle({
        Name = 'Camera Direction'
    })
    LimitItems = LongJump:CreateToggle({
        Name = 'Limit to items',
        Tooltip = 'Only long-jumps from a held item. Without one LongJump turns itself back off instead of freezing you'
    })
        ChangeDir = LongJump:CreateToggle({
            Name = 'Change direction mid-air',
            Tooltip = 'Steer the boost with your movement keys instead of flying in a straight line'
        })
    end

    -- LongJumpBypass: reuses two built-in behaviours back to back. On key it activates a compatible
    -- tool the way LongJump does - by switching LongJump on, so the launch, arc and speed are
    -- LongJump's own - and while that boost carries you it applies BoostAirJump's push (upward
    -- velocity to beat the jump-height check) for you automatically, lifting you up without a held
    -- jump. When LongJump's boost is spent it hands control back: LongJump is put back how it found
    -- it and the maneuver ends. Lives in the same block as LongJump so it can watch the shared boost
    -- window (JumpTick) and reuse LongJumpMethods to check you actually have a compatible tool.
    local function findBypassTool()
		local method, item, name = heldLongJumpMethod()
		if method then return name, item end
        for name in LongJumpMethods do
            local item = getItem(name)
            if item or store.equippedKit == name then
                return name, item
            end
        end
    end

    local LongJumpBypassCreated
    LongJumpBypass, LongJumpBypassCreated = register('Exploits', 'LongJumpBypass', {
        Name = 'LongJumpBypass',
        Function = function(callback)
            if callback then
                repeat task.wait() until (store.matchState ~= 0 and store.map and entitylib.isAlive) or not LongJumpBypass.Enabled
                if not LongJumpBypass.Enabled then return end

                -- A compatible tool has to exist first: switched on with nothing to launch off,
                -- LongJump just pins you in place waiting for a jump that never comes.
                local toolName, item = findBypassTool()
                if not toolName then
                    notif('LongJumpBypass', 'Hold or carry a compatible tool (dao, jade hammer, void axe, cannon, tnt, grappling hook).', 5)
                    return task.spawn(function() if LongJumpBypass.Enabled then LongJumpBypass:Toggle() end end)
                end

                -- Put the tool in hand before LongJump switches on: it picks its launch method from
                -- store.hand first, so this makes the launch the tool we found rather than whatever an
                -- unordered inventory scan lands on (and lets it work under 'Limit to items'). store.hand
                -- catches up a beat later, so wait for it. Kit launches (cat) carry no tool - skip.
                if item and item.tool and not (store.hand and store.hand.tool == item.tool) then
                    switchItem(item.tool, 0.1)
                    local handDeadline = tick() + 0.6
                    repeat task.wait(0.05) until (store.hand and store.hand.tool == item.tool) or tick() > handDeadline or not LongJumpBypass.Enabled
                    if not LongJumpBypass.Enabled then return end
                end

                -- 1. Activate the compatible tool with LongJump's own behaviour. Switching the module
                --    on fires the launch and runs its boost driver, exactly as using LongJump yourself.
                local longWasOn = LongJump.Enabled
                if not LongJump.Enabled then LongJump:Toggle() end
                -- 'Limit to items' with nothing in hand makes LongJump switch straight back off.
                if not LongJump.Enabled then
                    return task.spawn(function() if LongJumpBypass.Enabled then LongJumpBypass:Toggle() end end)
                end

                -- 2. While that boost carries you, lift yourself with BoostAirJump's behaviour - the
                --    same upward-velocity push that beats the jump-height check - only applied for you
                --    automatically instead of while you hold jump. JumpTick (shared with LongJump
                --    above) is the boost window: it goes into the future when the tool fires and lapses
                --    when the boost is spent. Left on past that LongJump pins your velocity in place,
                --    so hand control back the moment it lapses.
                local bypassStart = tick()
                local boostStart
                local launchY = entitylib.character.RootPart.Position.Y
                local launched = false
                local direction
                repeat
                    runService.PreSimulation:Wait()
                    local boosting = JumpTick > tick()
                    if boosting and not launched then
                        launched = true
                        boostStart = tick()
                        launchY = entitylib.character.RootPart.Position.Y
                    end
                    if entitylib.isAlive and (boosting or launched) then
                        local root = entitylib.character.RootPart
                        if root then
                            local velocity = root.AssemblyLinearVelocity
                            local flat = Vector3.new(velocity.X, 0, velocity.Z)
                            local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
                            direction = direction or (flat.Magnitude > 1 and flat.Unit) or (look.Magnitude > 0 and look.Unit) or Vector3.zAxis
                            -- Keep the complete two-second flight moving forward at exactly 37.
                            -- Stop climbing after 65 studs so a high Boost value cannot cross the
                            -- game's vertical kill/check band, but continue the forward boost.
                            local lift = root.Position.Y - launchY < 65 and BypassBoost.Value or 0
                            root.AssemblyLinearVelocity = Vector3.new(direction.X * 37, lift, direction.Z * 37)
                        end
                    end
                until not LongJumpBypass.Enabled or (launched and tick() - boostStart >= 2) or tick() - bypassStart > 8

                -- Put LongJump back how we found it, then end the maneuver as asked.
                if LongJump.Enabled and not longWasOn then LongJump:Toggle() end
                -- Cancel every component only after LongJump's driver has been stopped. Gravity
                -- owns the next simulation frame, producing a true unpowered free-fall.
                if launched and entitylib.isAlive then
                    entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
                end
                return task.spawn(function() if LongJumpBypass.Enabled then LongJumpBypass:Toggle() end end)
            end
        end,
        Tooltip = 'Fires a compatible tool, flies forward and climbs briefly, then cancels velocity and free-falls'
    })
    if LongJumpBypassCreated then
            BypassBoost = LongJumpBypass:CreateSlider({
            Name = 'Boost',
            Min = 5,
            Max = 42,
            Default = 30,
            Suffix = ' studs/s',
            Tooltip = 'Maximum upward speed maintained while LongJump boosts you'
        })
    end
end)


--------------------------------------------------------------------------------
-- Restored Exploits modules
-- These were removed from the branch even though their module names did not say
-- "Exploit". They use the same port registration and cleanup boundaries as the
-- Jade module below.

local BalloonDisabler, BalloonAutoDisable
local balloonControllerState
local balloonAutoConnection

local function stopBalloonAutoDisable()
    if balloonAutoConnection then
        pcall(balloonAutoConnection.Disconnect, balloonAutoConnection)
        balloonAutoConnection = nil
    end
end

local function restoreBalloonController()
    local state = balloonControllerState
    balloonControllerState = nil
    if not state or not state.Controller then return end
    pcall(function()
        if state.Controller.hookBalloon == state.Hook then
            state.Controller.hookBalloon = state.HookOriginal
        end
        if state.Controller.enableBalloonPhysics == state.Physics then
            state.Controller.enableBalloonPhysics = state.PhysicsOriginal
        end
        if state.Controller.deflateBalloon == state.Deflate then
            state.Controller.deflateBalloon = state.DeflateOriginal
        end
    end)
end

BalloonDisabler = (function()
    local module, created = register('Exploits', 'BalloonDisabler', {
        Tooltip = 'Disables the local balloon anticheat controller while a balloon is equipped.',
        Function = function(callback)
            restoreBalloonController()
            if not callback then return end

            local controller = bedwars.BalloonController
            local item = safe('balloon.inventory', getItem, 'balloon')
            if not item then
                notify('BalloonDisabler: no balloon is available.', 5, 'alert')
                return
            end
            if not controller or type(controller.hookBalloon) ~= 'function' then
                notify('BalloonDisabler: balloon controller is unavailable.', 5, 'warning')
                return
            end

            local state = {
                Controller = controller,
                HookOriginal = controller.hookBalloon,
                PhysicsOriginal = controller.enableBalloonPhysics,
                DeflateOriginal = controller.deflateBalloon
            }
            balloonControllerState = state

            state.Hook = function(self, player, attachment, balloon)
                if tostring(player) ~= lplr.Name then
                    if state.HookOriginal then
                        return state.HookOriginal(self, player, attachment, balloon)
                    end
                    return
                end

                safe('balloon.hide', function()
                    if not balloon then return end
                    local visual = balloon:FindFirstChild('Balloon') or balloon:WaitForChild('Balloon', 1)
                    if visual then
                        visual.CFrame = CFrame.new(0, -1995, 0)
                        visual:ClearAllChildren()
                    end
                end)
                restoreBalloonController()
                task.delay(0.5, function()
                    if module.Enabled then
                        notify('BalloonDisabler: local balloon controller disabled.', 5)
                    end
                end)
            end
            state.Physics = function() end
            state.Deflate = function() end

            local installed, errorMessage = pcall(function()
                if type(controller.inflateBalloon) == 'function' then
                    controller:inflateBalloon()
                end
                controller.enableBalloonPhysics = state.Physics
                controller.deflateBalloon = state.Deflate
                controller.hookBalloon = state.Hook
            end)
            if not installed then
                restoreBalloonController()
                notify('BalloonDisabler: controller setup failed.', 5, 'warning')
                Ports.Diagnostics.BalloonDisabler = {At = tick(), Error = tostring(errorMessage)}
            end
        end
    })
    if created then
        BalloonAutoDisable = module:CreateToggle({
            Name = 'AutoDisable',
            Default = false,
            Function = function(enabled)
                stopBalloonAutoDisable()
                if not enabled then return end
                local inventories = ctx.replicatedStorage and ctx.replicatedStorage:FindFirstChild('Inventories')
                if not inventories then
                    notify('BalloonDisabler: inventory controller is unavailable.', 5, 'warning')
                    return
                end
                local connected, connection = pcall(inventories.DescendantAdded.Connect, inventories.DescendantAdded, function(object)
                    if object.Parent and object.Parent.Name == lplr.Name and object.Name == 'balloon' then
                        task.spawn(function()
                            repeat task.wait() until getItem('balloon') or not BalloonAutoDisable.Enabled
                            if BalloonAutoDisable.Enabled and not module.Enabled then
                                module:Toggle()
                            end
                        end)
                    end
                end)
                if connected then
                    balloonAutoConnection = connection
                    BalloonAutoDisable:Clean(connection)
                end
            end
        })
        module:Clean(function()
            stopBalloonAutoDisable()
            restoreBalloonController()
        end)
    end
    return module
end)()

local MultiAction, MultiActionActions, MultiActionContexts
local multiActionHooks, multiActionCalls, multiActionLast = {}, {}, {}
local multiActionControllers = {}
local multiActionActionNames = {'Hotbar switching', 'Melee attacking', 'Block placement'}
local multiActionContextNames = {'Projectile charging', 'Consuming', 'Ability aiming'}

local function multiActionSelected(option, name)
    return option and table.find(option.ListEnabled, name) ~= nil
end

local function refreshMultiActionControllers()
    local result, seen = {}, {}
    local function add(name, controller)
        if type(controller) == 'table' and not seen[controller] then
            seen[controller] = true
            table.insert(result, {Name = tostring(name):lower(), Value = controller})
        end
    end
    if bedwars.Knit and bedwars.Knit.Controllers then
        for name, controller in pairs(bedwars.Knit.Controllers) do add(name, controller) end
    end
    for name, controller in pairs(bedwars) do
        if type(name) == 'string' and name:find('Controller') then add(name, controller) end
    end
    add('blockplacer', store.blockPlacer)
    local placement = bedwars.BlockPlacementController
    add('blockplacementcontroller', placement)
    add('blockplacementplacer', placement and placement.blockPlacer)
    multiActionControllers = result
end

local multiActionPatterns = {
    ['Projectile charging'] = {'charg', 'draw', 'projectile'},
    Consuming = {'consum', 'eat', 'drink'},
    ['Ability aiming'] = {'aim', 'targeting'}
}

local function multiActionContextMatches(controllerName, key, context)
    local lower = tostring(key):lower()
    for _, pattern in ipairs(multiActionPatterns[context] or {}) do
        if lower:find(pattern, 1, true) then
            if context ~= 'Projectile charging'
                or controllerName:find('projectile')
                or controllerName:find('bow')
                or controllerName:find('crossbow')
                or lower:find('projectile')
                or lower:find('charg')
                or lower:find('draw') then
                return true
            end
        end
    end
    return false
end

local function multiActionValueActive(value, key)
    if type(value) == 'boolean' then return value end
    if type(value) == 'table' or typeof(value) == 'Instance' then return value ~= nil end
    return type(value) == 'number'
        and tostring(key):lower():find('consum', 1, true)
        and value > 0
        and tick() - value < 30
end

local function collectMultiActionBypasses(action)
    local bypasses, found = {}, {}
    for _, entry in ipairs(multiActionControllers) do
        for key, value in pairs(entry.Value) do
            if type(key) == 'string' then
                for _, context in ipairs(multiActionContextNames) do
                    if multiActionSelected(MultiActionContexts, context)
                        and multiActionContextMatches(entry.Name, key, context)
                        and multiActionValueActive(value, key) then
                        found[entry.Value] = found[entry.Value] or {}
                        table.insert(found[entry.Value], {Key = key, Value = value})
                        break
                    end
                end
            end
        end
    end

    for controller, contextStates in pairs(found) do
        if action ~= 'Hotbar switching' then
            for _, state in ipairs(contextStates) do
                table.insert(bypasses, {
                    Object = controller,
                    Key = state.Key,
                    Value = state.Value,
                    Temporary = type(state.Value) == 'boolean' and false or nil
                })
            end
        end
        for key, value in pairs(controller) do
            local lower = type(key) == 'string' and key:lower() or ''
            if type(value) == 'boolean' and value
                and (lower == 'busy' or lower == 'locked' or lower == 'actionblocked' or lower == 'isbusy') then
                table.insert(bypasses, {Object = controller, Key = key, Value = value, Temporary = false})
            end
        end
    end
    return bypasses
end

local function restoreMultiActionHooks()
    for _, hook in ipairs(multiActionHooks) do
        if hook.Object and hook.Object[hook.Key] == hook.Wrapper then
            hook.Object[hook.Key] = hook.Original
        end
    end
    table.clear(multiActionHooks)
    table.clear(multiActionCalls)
    table.clear(multiActionLast)
end

local function multiActionWithBypass(action, original, ...)
    if not MultiAction.Enabled
        or not multiActionSelected(MultiActionActions, action)
        or multiActionCalls[action] then
        return original(...)
    end
    local currentTime = os.clock()
    if currentTime - (multiActionLast[action] or 0) < 1 / 240 then
        return original(...)
    end
    multiActionLast[action], multiActionCalls[action] = currentTime, true

    local states = collectMultiActionBypasses(action)
    for _, state in ipairs(states) do
        if state.Object[state.Key] == state.Value then
            state.Object[state.Key] = state.Temporary
        end
    end

    local results = table.pack(pcall(original, ...))
    for index = #states, 1, -1 do
        local state = states[index]
        if state.Object[state.Key] == state.Temporary then
            state.Object[state.Key] = state.Value
        end
    end
    multiActionCalls[action] = nil
    if not results[1] then error(results[2], 0) end
    return table.unpack(results, 2, results.n)
end

local function hookMultiAction(object, key, action, predicate)
    if type(object) ~= 'table' or type(object[key]) ~= 'function' then return end
    for _, existing in ipairs(multiActionHooks) do
        if existing.Object == object and existing.Key == key then return end
    end
    local original = object[key]
    local wrapper
    wrapper = function(...)
        if predicate and not predicate(...) then return original(...) end
        return multiActionWithBypass(action, original, ...)
    end
    table.insert(multiActionHooks, {Object = object, Key = key, Original = original, Wrapper = wrapper})
    object[key] = wrapper
end

local function installMultiActionHooks()
    refreshMultiActionControllers()
    local sword = bedwars.SwordController
    hookMultiAction(sword, 'swingSwordAtMouse', 'Melee attacking')
    hookMultiAction(sword, 'swingSwordInRegion', 'Melee attacking')
    hookMultiAction(sword, 'attackEntity', 'Melee attacking')

    local placement = bedwars.BlockPlacementController
    hookMultiAction(placement, 'placeBlock', 'Block placement')
    hookMultiAction(placement and placement.blockPlacer, 'placeBlock', 'Block placement')
    hookMultiAction(store.blockPlacer, 'placeBlock', 'Block placement')

    local storeController = bedwars.Store
    hookMultiAction(storeController, 'dispatch', 'Hotbar switching', function(_, action)
        return type(action) == 'table' and action.type == 'InventorySelectHotbarSlot'
    end)
end

MultiAction = (function()
    local module, created = register('Exploits', 'MultiAction', {
        Tooltip = 'Separates compatible local action locks without changing progress, speed, cooldowns, inputs, or remotes.',
        Function = function(enabled)
            restoreMultiActionHooks()
            if not enabled then return end
            safe('multiaction.install', installMultiActionHooks)

            local nextRefresh = 0
            module:Clean(runService.Heartbeat:Connect(function()
                if tick() >= nextRefresh then
                    nextRefresh = tick() + 1
                    safe('multiaction.refresh', installMultiActionHooks)
                end
            end))
            module:Clean(lplr.CharacterAdded:Connect(function()
                task.defer(function()
                    if module.Enabled then safe('multiaction.character', installMultiActionHooks) end
                end)
            end))
        end
    })
    if created then
        MultiActionActions = module:CreateTextList({
            Name = 'Allowed actions',
            Default = multiActionActionNames,
            Tooltip = 'Enable only Hotbar switching, Melee attacking, or Block placement.'
        })
        MultiActionContexts = module:CreateTextList({
            Name = 'Active contexts',
            Default = multiActionContextNames,
            Tooltip = 'Enable Projectile charging, Consuming, or Ability aiming.'
        })
        module:Clean(function()
            restoreMultiActionHooks()
        end)
    end
    return module
end)()

if type(shared.AetherMultiActionCleanup) == 'function' then
    pcall(shared.AetherMultiActionCleanup)
end
shared.AetherMultiActionCleanup = restoreMultiActionHooks
vape:Clean(function()
    restoreMultiActionHooks()
    if shared.AetherMultiActionCleanup == restoreMultiActionHooks then
        shared.AetherMultiActionCleanup = nil
    end
end)

--------------------------------------------------------------------------------
-- InfiniteSigrid
-- This module was removed even though its name did not identify it as an exploit.
-- Keep it in the Kits window and use the live Elk controller when available.
--------------------------------------------------------------------------------
local InfiniteSigrid
local sigridGeneration = 0

InfiniteSigrid = (function()
    local module, created = register('Kits', 'InfiniteSigrid', {
        Tooltip = 'Keeps the Elk mount active while the Elk Master kit is equipped.',
        Function = function(callback)
            sigridGeneration += 1
            local generation = sigridGeneration
            if not callback then return end

            task.spawn(function()
                local mount
                while module.Enabled and generation == sigridGeneration do
                    if not mount then
                        safe('sigrid.resolve', function()
                            if bedwars.Client and type(bedwars.Client.Get) == 'function' then
                                mount = bedwars.Client:Get('ElkKitMounted')
                            end
                        end)
                    end

                    local kit = tostring(equippedKit() or ''):lower()
                    if mount and entitylib.isAlive and matchRunning() and kit == 'elk_master'
                        and type(mount.SendToServer) == 'function' then
                        safe('sigrid.mount', mount.SendToServer, mount)
                    end
                    task.wait(0.1)
                end
            end)
        end
    })
    if created then return module end
    return module
end)()

--------------------------------------------------------------------------------
-- JadeHammerExploit
-- The old reference teleport path is intentionally not reused. This module uses
-- Aether's shared Jade adapter for inventory, cooldown, ability resolution and
-- cleanup, while the targeted launch/steering state lives here.
--------------------------------------------------------------------------------
local JadeHammerExploit
local jadeGeneration = 0
local jadeState

local function jadeTargetRoot(target)
    if not target then return nil end
    local root = target.RootPart
    local character = target.Character
    if (not root or not root.Parent) and character then
        root = character.PrimaryPart or character:FindFirstChild('HumanoidRootPart')
    end
    return root and root.Parent and root or nil
end

local function validJadeTarget(target, origin, range)
    local root = jadeTargetRoot(target)
    if not root or target.Player == lplr or target.Targetable == false then return nil end
    local humanoid = target.Humanoid
        or (target.Character and target.Character:FindFirstChildOfClass('Humanoid'))
    if humanoid and humanoid.Health <= 0 then return nil end
    if origin and (root.Position - origin).Magnitude > range then return nil end
    return root
end

local function findJadeTarget(range, includeEntities)
    local root = rootOfLocal()
    if not root then return nil end

    local function query(players, npcs)
        local ok, target = pcall(entitylib.EntityPosition, {
            Origin = root.Position,
            Range = range,
            Part = 'RootPart',
            Players = players,
            NPCs = npcs
        })
        if not ok or not target then return nil end
        local targetRoot = validJadeTarget(target, root.Position, range)
        return targetRoot and target or nil, targetRoot
    end

    -- Query players first so an NPC cannot displace a valid player target.
    local target, targetRoot = query(true, false)
    if target then return target, targetRoot end
    if includeEntities then
        return query(false, true)
    end
end

local function jadeCleanup(restorePosition)
    local state = jadeState
    if not state then return end
    jadeState = nil

    if state.Connection then
        pcall(state.Connection.Disconnect, state.Connection)
        state.Connection = nil
    end
    if state.Lease then
        pcall(state.Lease.Release, state.Lease)
        state.Lease = nil
    end

    local root = rootOfLocal()
    if root and root.Parent then
        if restorePosition and state.OriginalCFrame then
            pcall(function() root.CFrame = state.OriginalCFrame end)
        end
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if state.OriginalTool and state.OriginalTool.Parent and type(switchItem) == 'function' then
        safe('jade.restore-tool', switchItem, state.OriginalTool, 0.05)
    end
end

local function finishJadeSmash(state, restorePosition)
    if jadeState ~= state then return end
    jadeCleanup(restorePosition)
end

local function beginJadeSmash(generation, target, targetRoot, hammer, ability)
    if jadeState or generation ~= jadeGeneration or not JadeHammerExploit.Enabled then return end

    local root, _, humanoid = rootOfLocal()
    local jade = Runtime.Jade
    if not root or not humanoid or humanoid.Health <= 0 or not jade then return end
    if not targetRoot or not targetRoot.Parent then return end
    if not isnetworkowner(root) then return end

    local movement = Runtime.Movement
    if not movement or type(movement.Acquire) ~= 'function' then return end

    local state = {
        OriginalCFrame = root.CFrame,
        OriginalTool = store.hand and store.hand.tool,
        Target = target,
        Hammer = hammer,
        Ability = ability,
        StartedAt = tick(),
        CooldownSeen = false,
        AirborneSeen = true
    }
    jadeState = state

    local priority = movement.Priorities and movement.Priorities.Ability or 40
    local acquired, lease = pcall(
        movement.Acquire,
        movement,
        'JadeHammerExploit',
        priority,
        3,
        function() finishJadeSmash(state, true) end,
        true
    )
    if not acquired or not lease then
        jadeState = nil
        return
    end
    state.Lease = lease

    local function cancelled()
        return jadeState ~= state
            or generation ~= jadeGeneration
            or not JadeHammerExploit.Enabled
            or not entitylib.isAlive
    end

    local ok, confirmed, reason = xpcall(function()
        root = rootOfLocal()
        if not root or cancelled() then return false, 'cancelled' end

        -- Rebuild the old teleport behaviour around the live root and preserve rotation.
        root.CFrame = CFrame.new(root.Position + Vector3.new(0, 150, 0)) * root.CFrame.Rotation

        local equipped, equipReason = jade:Equip(hammer, 0.8, cancelled)
        if not equipped then return false, equipReason or 'hammer-not-equipped' end

        local cast, castReason = jade:RequestActivation(
            hammer,
            ability,
            targetRoot.Position,
            cancelled,
            {PreferAbilityController = true}
        )
        if not cast then return false, castReason or 'jade-activation-not-confirmed' end
        state.ActivatedAt = tick()
        return true
    end, debug and debug.traceback or tostring)

    if not ok or not confirmed then
        Ports.Diagnostics.JadeHammerExploit = {At = tick(), Error = ok and tostring(reason) or tostring(confirmed)}
        finishJadeSmash(state, true)
        return
    end

    if cancelled() then
        finishJadeSmash(state, true)
        return
    end

    state.Connection = runService.Heartbeat:Connect(function()
        if cancelled() then
            finishJadeSmash(state, true)
            return
        end

        local liveRoot, _, liveHumanoid = rootOfLocal()
        local liveTargetRoot = jadeTargetRoot(state.Target)
        if not liveRoot or not liveHumanoid or liveHumanoid.Health <= 0 or not liveTargetRoot then
            finishJadeSmash(state, false)
            return
        end

        local elapsed = tick() - (state.ActivatedAt or state.StartedAt)
        if elapsed > 2.6 then
            finishJadeSmash(state, false)
            return
        end

        if liveHumanoid.FloorMaterial ~= Enum.Material.Air and elapsed > 0.3 then
            finishJadeSmash(state, false)
            return
        end

        local readiness = jade:GetCooldownState(ability)
        if readiness == 'BLOCKED' then state.CooldownSeen = true end
        if state.CooldownSeen and readiness == 'READY' and elapsed > 0.3 then
            finishJadeSmash(state, false)
            return
        end

        local offset = liveTargetRoot.Position - liveRoot.Position
        local horizontal = Vector3.new(offset.X, 0, offset.Z)
        if horizontal.Magnitude > 0 then
            horizontal = horizontal.Unit
            local horizontalSpeed = 23.3
            liveRoot.AssemblyLinearVelocity = Vector3.new(
                horizontal.X * horizontalSpeed,
                liveRoot.AssemblyLinearVelocity.Y,
                horizontal.Z * horizontalSpeed
            )
        end
    end)
    JadeHammerExploit:Clean(state.Connection)
end

JadeHammerExploit = (function()
    local module, created = register('Exploits', 'JadeHammerExploit', {
        Tooltip = 'Launches with Jade and steers the descent toward the closest valid target.',
        Function = function(callback)
            jadeGeneration += 1
            local generation = jadeGeneration
            jadeCleanup(not callback)
            if not callback then return end

            task.spawn(function()
                while JadeHammerExploit.Enabled and generation == jadeGeneration do
                    if not jadeState and entitylib.isAlive and matchRunning() then
                        local root = rootOfLocal()
                        local jade = Runtime.Jade
                        local hammer, hammerInfo = jade and jade:GetBestHammer()
                        if root and jade and hammer and hammerInfo then
                            local ability, abilityInfo = jade:ResolveAbility(hammer)
                            local readiness = ability and jade:GetCooldownState(ability)
                            local cooldownOK = readiness == 'READY'
                            if readiness == 'UNKNOWN' then
                                local controller = abilityController()
                                if controller and type(controller.canUseAbility) == 'function' then
                                    local checked, ready = pcall(
                                        controller.canUseAbility,
                                        controller,
                                        ability,
                                        {disableBlockedAbilityAlert = true}
                                    )
                                    cooldownOK = checked and ready == true
                                end
                            end
                            if ability and cooldownOK then
                                local target, targetRoot = findJadeTarget(JadeHammerExploitRange.Value, JadeHammerExploitEntities.Enabled)
                                if target and targetRoot then
                                    task.spawn(beginJadeSmash, generation, target, targetRoot, hammer, ability)
                                end
                            end
                        end
                    end
                    task.wait(0.08)
                end
            end)
        end
    })
    if created then
        JadeHammerExploitRange = module:CreateSlider({
            Name = 'Target Range',
            Min = 1,
            Max = 20,
            Default = 20,
            Suffix = ' studs'
        })
        JadeHammerExploitEntities = module:CreateToggle({
            Name = 'Target Entities',
            Default = false
        })
    end
    return module
end)()

-- Compatibility exports for older JIK callers without registering a duplicate UI module.
Ports.Modules.JadeInstaKill = JadeHammerExploit
Runtime.JadeHammerExploit = JadeHammerExploit
Runtime.JadeInstaKill = JadeHammerExploit

return Ports

end

    local portsLoaded, portsResult = xpcall(function()
        return registerAetherPorts(AetherMatchRuntime, context)
    end, debug and debug.traceback or tostring)
    if not portsLoaded then
        warn('[AetherV2] BedWars ports failed to load: '..tostring(portsResult))
        notif('AetherV2', 'BedWars port modules failed to load. Check the console.', 8, 'warning')
    end

    local portsV2Loaded, portsV2Result = xpcall(function()
        return registerAetherPortsV2(AetherMatchRuntime, context)
    end, debug and debug.traceback or tostring)
    if not portsV2Loaded then
        warn('[AetherV2] Newer BedWars ports failed to load: '..tostring(portsV2Result))
        notif('AetherV2', 'Newer BedWars port modules failed to load. Check the console.', 8, 'warning')
    end
end)