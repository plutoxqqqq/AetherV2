-- AetherV2 BedWars reactive runtime
-- Loaded by games/6872274481.lua with the live match-file context.
-- The dependency dump in libraries/bedwars is a reference only; this runtime deliberately
-- distinguishes live controllers/replicated state from compatibility fallbacks.

local ctx = ...
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
