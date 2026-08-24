-- Hardening/integration layer for libraries/bedwars/aether/rewrite.lua.
-- Kept separate so the large reactive runtime stays readable and this compatibility layer can be
-- audited independently against Aether's existing modules/config names.

local Runtime, ctx = ...
assert(type(Runtime) == 'table' and type(ctx) == 'table', 'rewrite patch requires runtime + context')

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
        return route and ReactiveTravel.new(self, objective, route) or nil, route and nil or 'safe-route-unavailable'
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
