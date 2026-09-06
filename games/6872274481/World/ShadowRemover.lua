run(function()
	local ShadowRemover
	local connections = {}
	local originalShadows = {}
	local processedShadows = {}

	local function removeShadow(obj)
		if obj:IsA("BasePart") and not processedShadows[obj] then
			if not originalShadows[obj] then
				originalShadows[obj] = obj.CastShadow
			end
			obj.CastShadow = false
			processedShadows[obj] = true
		end
	end

	ShadowRemover = vape.Categories.World:CreateModule({
		Name = 'ShadowRemover',
		Function = function(callback)
			if callback then
				local descendants = workspace:GetDescendants()

				task.spawn(function()
					for i, obj in descendants do
						removeShadow(obj)
						if i % 100 == 0 then
							task.wait()
						end
					end
				end)

				local conn = workspace.DescendantAdded:Connect(function(obj)
					if ShadowRemover.Enabled then
						removeShadow(obj)
					end
				end)
				table.insert(connections, conn)
			else
				for obj, shadow in pairs(originalShadows) do
					if obj and obj.Parent then
						pcall(function()
							obj.CastShadow = shadow
						end)
					end
				end

				for _, conn in connections do
					conn:Disconnect()
				end
				table.clear(connections)
				table.clear(originalShadows)
				table.clear(processedShadows)
			end
		end,
	})
end)


do
local Runtime = AetherMatchRuntime


function Runtime:InstallLongJumpJadeHook(longJumpModule)
    if not longJumpModule or longJumpModule._AetherJadeV2Hook then return end
    longJumpModule._AetherJadeV2Hook=true
end

Runtime:InstallLongJumpJadeHook(Runtime.ModuleByName and Runtime.ModuleByName('LongJump'))


end

local function patchAetherRuntime(Runtime, ctx)


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
        
        
        self.WroteEnabled = nil
        coreRelease(self)
        if shouldRestore and moduleNow.Enabled ~= before then
            protected('lease.restore-state.'..name, function() moduleNow:Toggle(true) end)
        end
    end
    return lease
end


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


local directorStart = Runtime.MatchDirector.Start
function Runtime.MatchDirector:Start()
    if optionEnabled('Take over modules', true) then
        
        
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


if Runtime.AutoWin and Runtime.AutoWin.Children then
    Runtime.AutoWin.Children.Visible = optionEnabled('Show HUD', true) and Runtime.AutoWin.Enabled
end

return Runtime

end
    local patched, patchResult = xpcall(function()
        return patchAetherRuntime(AetherMatchRuntime, context)
    end, debug and debug.traceback or tostring)
    if not patched then warn('[AetherV2] AutoWin/JIK integration patch failed: '..tostring(patchResult)) end


AetherMatchRuntime.JadeHammerExploit = vape.Modules and vape.Modules.JadeHammerExploit or nil


local function run(fn)
	task.spawn(function()
		local ok, err = pcall(fn)
		if not ok then
			warn("[Aether Port] " .. tostring(err))
		end
	end)
end

repeat task.wait() until game:IsLoaded()


local vape = shared.vape or vape
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local lplr = players.LocalPlayer

local function notify(title, text, duration)
	duration = duration or 3
	if vape and vape.CreateNotification then
		pcall(function() vape:CreateNotification(title, text, duration) end)
	else
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = title,
				Text = text,
				Duration = duration
			})
		end)
	end
end

local function category(name)
	if vape and vape.Categories and vape.Categories[name] then
		return vape.Categories[name]
	end
	
	if vape and vape.Categories then
		for _, cat in pairs(vape.Categories) do
			if type(cat) == "table" and cat.CreateModule then
				return cat
			end
		end
	end
	return nil
end

local function createModule(catName, def)
	local cat = category(catName) or category("Utility") or category("Render") or category("Blatant")
	assert(cat and cat.CreateModule, "Aether GUI not ready (no CreateModule)")
	return cat:CreateModule(def)
end

local function isAlive(plr)
	plr = plr or lplr
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and root ~= nil and hum.Health > 0
end

local function guiColor()
	
	local ok, color = pcall(function()
		if vape.GUIColor then
			return Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		end
	end)
	if ok and color then return color end
	return Color3.fromRGB(120, 200, 255)
end

local store = shared.store or getgenv().store
local bedwars = shared.bedwars or (store and store.bedwars)
local entitylib = (vape and vape.Libraries and (vape.Libraries.entity or vape.Libraries.entitylib))
	or shared.vapeentity
	or shared.entityLibrary
local whitelist = (vape and vape.Libraries and vape.Libraries.whitelist) or shared.vapewhitelist


run(function()
	local reported = {}
	local Notify

	local AutoReport = createModule("Utility", {
		Name = "AutoReportV2",
		Tooltip = "Reports non-whitelisted players in the server",
		Function = function(on)
			if not on then return end
			task.spawn(function()
				while AutoReport.Enabled do
					for _, plr in ipairs(players:GetPlayers()) do
						if not AutoReport.Enabled then break end
						if plr == lplr or reported[plr] then continue end
						if not plr:GetAttribute("PlayerConnected") then continue end
						local tagged = false
						pcall(function()
							if whitelist and whitelist.get and whitelist:get(plr) ~= 0 then
								tagged = true
							end
						end)
						if tagged then continue end
						task.wait(1)
						reported[plr] = true
						local sent = false
						pcall(function()
							if bedwars and bedwars.Client and bedwars.ReportRemote then
								bedwars.Client:Get(bedwars.ReportRemote):SendToServer(plr.UserId)
								sent = true
							end
						end)
						if not sent then
							pcall(function()
								local net = replicatedStorage:FindFirstChild("rbxts_include")
								if net then
									local managed = net.node_modules["@rbxts"].net.out._NetManaged
									local remote = managed and (managed:FindFirstChild("ReportPlayer") or managed:FindFirstChild("BedwarsReportPlayer"))
									if remote then
										if remote:IsA("RemoteEvent") then remote:FireServer(plr.UserId) else remote:InvokeServer(plr.UserId) end
										sent = true
									end
								end
							end)
						end
						if store and store.statistics then
							store.statistics.reported = (store.statistics.reported or 0) + 1
						end
						if Notify and Notify.Enabled then
							notify("AutoReportV2", (sent and "Reported " or "No report remote — marked ") .. plr.Name, 4)
						end
					end
					task.wait(2)
				end
			end)
		end
	})

	Notify = AutoReport:CreateToggle({
		Name = "Notify",
		Default = false
	})
end)


run(function()
	local cfg = {
		speed = 0.5,
		c1 = {H = 0.6, S = 0.8, V = 1},
		c2 = {H = 0.8, S = 0.8, V = 0.8}
	}
	local conA, conB
	local Color1, Color2, Speed

	local function apply()
		pcall(function()
			if conA then conA:Disconnect() end
			local app = lplr.PlayerGui:FindFirstChild("QueueApp")
			if not app then return end
			local frame = app:FindFirstChild("1")
			if not frame then return end
			frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			local g = frame:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
			g.Rotation = 180
			g.Parent = frame
			conA = runService.RenderStepped:Connect(function()
				local t = (math.sin(tick() * cfg.speed) + 1) / 2
				local h = cfg.c1.H + (cfg.c2.H - cfg.c1.H) * t
				local s = cfg.c1.S + (cfg.c2.S - cfg.c1.S) * t
				local v = cfg.c1.V + (cfg.c2.V - cfg.c1.V) * t
				g.Color = ColorSequence.new(Color3.fromHSV(h, s, v))
			end)
		end)
	end

	local QueueCard = createModule("Render", {
		Name = "QueueCardMods",
		Tooltip = "Animated gradient on the queue card",
		Function = function(on)
			if on then
				apply()
				conB = lplr.PlayerGui.ChildAdded:Connect(function(c)
					if c.Name == "QueueApp" then
						task.wait(0.1)
						apply()
					end
				end)
			else
				if conA then conA:Disconnect() end
				if conB then conB:Disconnect() end
				conA, conB = nil, nil
			end
		end
	})

	Speed = QueueCard:CreateSlider({
		Name = "Animation Speed",
		Min = 1,
		Max = 5,
		Default = 3,
		Function = function(val)
			cfg.speed = math.clamp(val, 0.1, 5)
		end
	})

	if QueueCard.CreateColorSlider then
		QueueCard:CreateColorSlider({
			Name = "Color 1",
			Function = function(h, s, v)
				cfg.c1 = {H = h, S = s, V = v}
			end
		})
		QueueCard:CreateColorSlider({
			Name = "Color 2",
			Function = function(h, s, v)
				cfg.c2 = {H = h, S = s, V = v}
			end
		})
	end
end)


run(function()
	local cons = {}
	local flagged = {TP = {}, Speed = {}, Fly = {}, Invis = {}}
	local DetTP, DetSpeed, DetFly, DetInvis
	local TPDist, SpeedDist

	local function flag(kind, plr, reason)
		if flagged[kind][plr] then return end
		flagged[kind][plr] = true
		notify("HackerDetector", plr.DisplayName .. " — " .. reason, 8)
		pcall(function()
			if not isfolder then return end
			if not isfolder("aether") then makefolder("aether") end
			local cache = {}
			pcall(function()
				cache = httpService:JSONDecode(readfile("aether/exploiters.json"))
			end)
			cache[plr.Name] = cache[plr.Name] or {UserId = plr.UserId, Hits = {}}
			table.insert(cache[plr.Name].Hits, {kind = kind, t = os.time()})
			writefile("aether/exploiters.json", httpService:JSONEncode(cache))
		end)
	end

	local function watch(plr)
		if plr == lplr then return end
		local lastPos = Vector3.zero
		local lastTP = plr:GetAttribute("LastTeleported") or 0

		table.insert(cons, plr:GetAttributeChangedSignal("LastTeleported"):Connect(function()
			lastTP = plr:GetAttribute("LastTeleported") or lastTP
		end))

		table.insert(cons, plr.CharacterAdded:Connect(function()
			task.delay(0.4, function()
				if isAlive(plr) then
					lastPos = plr.Character.HumanoidRootPart.Position
				end
			end)
		end))

		task.spawn(function()
			while HackerDetector.Enabled and plr.Parent do
				if isAlive(plr) then
					local root = plr.Character.HumanoidRootPart
					local pos = root.Position
					local delta = (pos - lastPos).Magnitude
					local officialTP = (plr:GetAttribute("LastTeleported") or 0) ~= lastTP

					if DetTP and DetTP.Enabled and delta >= (TPDist and TPDist.Value or 400) and not officialTP then
						flag("TP", plr, "Teleport")
					end
					if DetSpeed and DetSpeed.Enabled and delta >= (SpeedDist and SpeedDist.Value or 25) and officialTP then
						flag("Speed", plr, "Speed")
					end
					if DetFly and DetFly.Enabled then
						local params = RaycastParams.new()
						params.FilterDescendantsInstances = {plr.Character}
						params.FilterType = Enum.RaycastFilterType.Exclude
						local hit = workspace:Raycast(pos, Vector3.new(0, -80, 0), params)
						if not hit and root.AssemblyLinearVelocity.Y > -2 and delta > 8 then
							flag("Fly", plr, "InfiniteFly")
						end
					end
					if DetInvis and DetInvis.Enabled then
						local head = plr.Character:FindFirstChild("Head")
						if head and head.Transparency >= 0.9 then
							flag("Invis", plr, "Invisibility")
						end
					end
					lastPos = pos
				end
				task.wait(2.5)
			end
		end)
	end

	HackerDetector = createModule("Utility", {
		Name = "HackerDetector",
		Tooltip = "Flags suspicious movement on other players",
		Function = function(on)
			if on then
				for _, plr in ipairs(players:GetPlayers()) do
					watch(plr)
				end
				table.insert(cons, players.PlayerAdded:Connect(watch))
			else
				for _, c in ipairs(cons) do
					pcall(function() c:Disconnect() end)
				end
				table.clear(cons)
			end
		end
	})

	DetTP = HackerDetector:CreateToggle({Name = "Teleport", Default = true})
	DetSpeed = HackerDetector:CreateToggle({Name = "Speed", Default = true})
	DetFly = HackerDetector:CreateToggle({Name = "InfiniteFly", Default = true})
	DetInvis = HackerDetector:CreateToggle({Name = "Invisibility", Default = true})
	TPDist = HackerDetector:CreateSlider({Name = "TP Distance", Min = 80, Max = 800, Default = 400})
	SpeedDist = HackerDetector:CreateSlider({Name = "Speed Distance", Min = 15, Max = 80, Default = 25})
end)


run(function()
	local parts = {}
	local cfg = {
		Spread = 35,
		Rate = 28,
		Height = 100,
		Wind = true,
		Color = Color3.new(1, 1, 1)
	}

	local function makeEmitter(parent, wind)
		local e = Instance.new("ParticleEmitter")
		e.RotSpeed = NumberRange.new(wind and 100 or 300)
		e.Rate = cfg.Rate
		e.Texture = "rbxassetid://8158344433"
		e.Rotation = NumberRange.new(110)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.17),
			NumberSequenceKeypoint.new(0.56, 0.39),
			NumberSequenceKeypoint.new(1, 1)
		})
		e.Lifetime = NumberRange.new(8, 14)
		e.Speed = NumberRange.new(8, 18)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(cfg.Spread, cfg.Spread)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.04, 1.3),
			NumberSequenceKeypoint.new(1, 0)
		})
		e.Color = ColorSequence.new(cfg.Color)
		if wind then
			e.Acceleration = Vector3.new(0, 0, 1)
		end
		e.Parent = parent
		return e
	end

	local function wipe()
		for _, o in ipairs(parts) do
			pcall(function() o:Destroy() end)
		end
		table.clear(parts)
	end

	local Weather = createModule("Render", {
		Name = "WeatherMods",
		Tooltip = "Local snow particles that follow you",
		Function = function(on)
			if not on then
				wipe()
				return
			end
			task.spawn(function()
				local base = Instance.new("Part")
				base.Size = Vector3.new(240, 0.5, 240)
				base.Name = "AetherWeatherBase"
				base.Transparency = 1
				base.CanCollide = false
				base.Anchored = true
				base.Parent = workspace
				table.insert(parts, base)
				local snow = makeEmitter(base, false)
				local wind = makeEmitter(base, true)
				wind.Enabled = cfg.Wind
				table.insert(parts, snow)
				table.insert(parts, wind)
				while Weather.Enabled do
					local root
					if entitylib and entitylib.isAlive and entitylib.character then
						root = entitylib.character.HumanoidRootPart or entitylib.character.RootPart
					elseif isAlive() then
						root = lplr.Character.HumanoidRootPart
					end
					if root then
						base.Position = root.Position + Vector3.new(0, cfg.Height, 0)
					end
					snow.Rate = cfg.Rate
					wind.Rate = cfg.Rate
					snow.SpreadAngle = Vector2.new(cfg.Spread, cfg.Spread)
					wind.SpreadAngle = Vector2.new(cfg.Spread, cfg.Spread)
					snow.Color = ColorSequence.new(cfg.Color)
					wind.Color = ColorSequence.new(cfg.Color)
					wind.Enabled = cfg.Wind
					task.wait(0.1)
				end
				wipe()
			end)
		end
	})

	Weather:CreateSlider({
		Name = "Spread", Min = 1, Max = 100, Default = 35,
		Function = function(v) cfg.Spread = v end
	})
	Weather:CreateSlider({
		Name = "Rate", Min = 1, Max = 100, Default = 28,
		Function = function(v) cfg.Rate = v end
	})
	Weather:CreateSlider({
		Name = "Height", Min = 1, Max = 200, Default = 100,
		Function = function(v) cfg.Height = v end
	})
	Weather:CreateToggle({
		Name = "Wind Effect", Default = true,
		Function = function(v) cfg.Wind = v end
	})
	if Weather.CreateColorSlider then
		Weather:CreateColorSlider({
			Name = "Particle Color",
			Function = function(h, s, v)
				cfg.Color = Color3.fromHSV(h, s, v)
			end
		})
	end
end)


run(function()
	local made = {}
	local SlotColor, GradientOn, Rounding, Highlight, HideNums, GuiSync
	local ColorA, ColorB, RoundSize, HighlightColor

	local function paint()
		local icons = ({pcall(function()
			return lplr.PlayerGui.hotbar["1"].ItemsHotbar
		end)})[2]
		if typeof(icons) ~= "Instance" then return end
		for _, slot in ipairs(icons:GetChildren()) do
			local label = ({pcall(function()
				return slot:FindFirstChildWhichIsA("ImageButton"):FindFirstChildWhichIsA("TextLabel")
			end)})[2]
			if typeof(label) ~= "Instance" then continue end
			local btn = label.Parent
			if SlotColor and SlotColor.Enabled and not (GradientOn and GradientOn.Enabled) then
				local c = ColorA
				btn.BackgroundColor3 = c and Color3.fromHSV(c.Hue or 0, c.Sat or 0, c.Value or 1) or guiColor()
			end
			if GuiSync and GuiSync.Enabled then
				btn.BackgroundColor3 = guiColor()
			end
			if GradientOn and GradientOn.Enabled and not (GuiSync and GuiSync.Enabled) then
				btn.BackgroundColor3 = Color3.new(1, 1, 1)
				if not btn:FindFirstChildWhichIsA("UIGradient") then
					local g = Instance.new("UIGradient")
					local a = ColorA and Color3.fromHSV(ColorA.Hue or 0, ColorA.Sat or 0, ColorA.Value or 1) or Color3.fromRGB(80, 160, 255)
					local b = ColorB and Color3.fromHSV(ColorB.Hue or 0.7, ColorB.Sat or 0.8, ColorB.Value or 1) or Color3.fromRGB(180, 80, 255)
					g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b)})
					g.Parent = btn
					table.insert(made, g)
				end
			end
			if Rounding and Rounding.Enabled and not btn:FindFirstChildWhichIsA("UICorner") then
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, RoundSize and RoundSize.Value or 8)
				c.Parent = btn
				table.insert(made, c)
			end
			if Highlight and Highlight.Enabled and not btn:FindFirstChildWhichIsA("UIStroke") then
				local s = Instance.new("UIStroke")
				s.Thickness = 1.3
				s.Color = (GuiSync and GuiSync.Enabled) and guiColor()
					or (HighlightColor and Color3.fromHSV(HighlightColor.Hue or 0, HighlightColor.Sat or 0, HighlightColor.Value or 1))
					or Color3.new(1, 1, 1)
				s.Parent = btn
				table.insert(made, s)
			end
			if HideNums and HideNums.Enabled then
				label.Visible = false
			end
		end
	end

	local function clear()
		for _, o in ipairs(made) do
			pcall(function() o:Destroy() end)
		end
		table.clear(made)
		pcall(function()
			local icons = lplr.PlayerGui.hotbar["1"].ItemsHotbar
			for _, slot in ipairs(icons:GetChildren()) do
				local btn = slot:FindFirstChildWhichIsA("ImageButton")
				if btn then
					btn.BackgroundColor3 = Color3.fromRGB(29, 36, 46)
					local lab = btn:FindFirstChildWhichIsA("TextLabel")
					if lab then lab.Visible = true end
				end
			end
		end)
	end

	local Hotbar = createModule("Render", {
		Name = "HotbarVisuals",
		Tooltip = "Recolor / round / outline hotbar slots",
		Function = function(on)
			if on then
				Hotbar:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(v)
					if v.Name == "hotbar" then
						task.wait(0.05)
						paint()
					end
				end))
				paint()
			else
				clear()
			end
		end
	})

	GuiSync = Hotbar:CreateToggle({Name = "GUI Color Sync", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	SlotColor = Hotbar:CreateToggle({Name = "Slot Color", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	GradientOn = Hotbar:CreateToggle({Name = "Gradient Slot Color", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	Rounding = Hotbar:CreateToggle({Name = "Rounding", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	Highlight = Hotbar:CreateToggle({Name = "Outline Highlight", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	HideNums = Hotbar:CreateToggle({Name = "No Slot Numbers", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	RoundSize = Hotbar:CreateSlider({Name = "Round Radius", Min = 1, Max = 16, Default = 8})
	if Hotbar.CreateColorSlider then
		ColorA = Hotbar:CreateColorSlider({Name = "Slot / Gradient 1"})
		ColorB = Hotbar:CreateColorSlider({Name = "Gradient 2"})
		HighlightColor = Hotbar:CreateColorSlider({Name = "Outline Color"})
	end
end)


run(function()
	local made = {}
	local textCon
	local MainOn, GradOn, BgOn, RoundOn, StrokeOn, TextOn, FontOn, GuiSync
	local MainCol, GradCol, BgCol, StrokeCol, TextCol, RoundSize, FontDrop, TextList

	local function apply()
		if not Healthbar.Enabled then return end
		local bar = ({pcall(function()
			return lplr.PlayerGui.hotbar["1"].HotbarHealthbarContainer.HealthbarProgressWrapper["1"]
		end)})[2]
		if typeof(bar) ~= "Instance" then return end

		if GuiSync and GuiSync.Enabled then
			bar.BackgroundColor3 = guiColor()
		elseif MainOn and MainOn.Enabled then
			bar.BackgroundColor3 = MainCol and Color3.fromHSV(MainCol.Hue or 0, MainCol.Sat or 0.8, MainCol.Value or 1) or Color3.fromRGB(203, 54, 36)
			if GradOn and GradOn.Enabled then
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
				local g = bar:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient", bar)
				local a = MainCol and Color3.fromHSV(MainCol.Hue or 0, MainCol.Sat or 0.8, MainCol.Value or 1) or Color3.fromRGB(203, 54, 36)
				local b = GradCol and Color3.fromHSV(GradCol.Hue or 0.05, GradCol.Sat or 0.8, GradCol.Value or 1) or Color3.fromRGB(255, 160, 40)
				g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b)})
				table.insert(made, g)
			end
		end

		local bg = bar.Parent and bar.Parent.Parent
		if typeof(bg) == "Instance" then
			if BgOn and BgOn.Enabled then
				bg.BackgroundColor3 = BgCol and Color3.fromHSV(BgCol.Hue or 0.6, BgCol.Sat or 0.2, BgCol.Value or 0.2) or Color3.fromRGB(41, 51, 65)
			end
			if StrokeOn and StrokeOn.Enabled and not bg:FindFirstChildWhichIsA("UIStroke") then
				local s = Instance.new("UIStroke")
				s.Thickness = 1.6
				s.Color = StrokeCol and Color3.fromHSV(StrokeCol.Hue or 0, StrokeCol.Sat or 0, StrokeCol.Value or 1) or Color3.new(1, 1, 1)
				s.Parent = bg
				table.insert(made, s)
			end
			if RoundOn and RoundOn.Enabled then
				for _, f in ipairs(bar.Parent:GetChildren()) do
					if f:IsA("Frame") and not f:FindFirstChildWhichIsA("UICorner") then
						local c = Instance.new("UICorner")
						c.CornerRadius = UDim.new(0, RoundSize and RoundSize.Value or 4)
						c.Parent = f
						table.insert(made, c)
					end
				end
				if not bg:FindFirstChildWhichIsA("UICorner") then
					local c = Instance.new("UICorner")
					c.CornerRadius = UDim.new(0, RoundSize and RoundSize.Value or 4)
					c.Parent = bg
					table.insert(made, c)
				end
			end

			local label = bg:FindFirstChild("1")
			if typeof(label) == "Instance" and label:IsA("TextLabel") then
				if TextCol and TextOn and TextOn.Enabled then
					label.TextColor3 = Color3.fromHSV(TextCol.Hue or 0, TextCol.Sat or 0, TextCol.Value or 1)
				end
				if FontOn and FontOn.Enabled and FontDrop then
					pcall(function() label.Font = Enum.Font[FontDrop.Value] end)
				end
				local function rewrite()
					local custom = ""
					if TextList and TextList.ObjectList and #TextList.ObjectList > 0 then
						custom = TextList.ObjectList[math.random(1, #TextList.ObjectList)]
					end
					local hp = isAlive() and tostring(math.floor(lplr.Character:GetAttribute("Health") or 0)) or "0"
					if TextOn and TextOn.Enabled and custom ~= "" then
						label.Text = custom:gsub("<health>", hp)
					else
						label.Text = hp
					end
				end
				rewrite()
				if textCon then textCon:Disconnect() end
				textCon = label:GetPropertyChangedSignal("Text"):Connect(rewrite)
			end
		end
	end

	local function clear()
		if textCon then textCon:Disconnect() end
		textCon = nil
		for _, o in ipairs(made) do
			pcall(function() o:Destroy() end)
		end
		table.clear(made)
		pcall(function()
			local bar = lplr.PlayerGui.hotbar["1"].HotbarHealthbarContainer.HealthbarProgressWrapper["1"]
			bar.BackgroundColor3 = Color3.fromRGB(203, 54, 36)
			bar.Parent.Parent.BackgroundColor3 = Color3.fromRGB(41, 51, 65)
		end)
	end

	Healthbar = createModule("Render", {
		Name = "HealthbarVisuals",
		Tooltip = "Recolor healthbar. Put <health> in custom text.",
		Function = function(on)
			if on then
				Healthbar:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(v)
					if v.Name == "HotbarHealthbarContainer" then
						task.wait(0.05)
						apply()
					end
				end))
				apply()
			else
				clear()
			end
		end
	})

	GuiSync = Healthbar:CreateToggle({Name = "GUI Color Sync", Function = function() if Healthbar.Enabled then clear(); apply() end end})
	MainOn = Healthbar:CreateToggle({Name = "Main Color", Default = true, Function = function() if Healthbar.Enabled then apply() end end})
	GradOn = Healthbar:CreateToggle({Name = "Gradient", Function = function() if Healthbar.Enabled then apply() end end})
	BgOn = Healthbar:CreateToggle({Name = "Background Color", Function = function() if Healthbar.Enabled then apply() end end})
	RoundOn = Healthbar:CreateToggle({Name = "Round", Function = function() if Healthbar.Enabled then clear(); apply() end end})
	StrokeOn = Healthbar:CreateToggle({Name = "Highlight", Function = function() if Healthbar.Enabled then clear(); apply() end end})
	TextOn = Healthbar:CreateToggle({Name = "Custom Text", Function = function() if Healthbar.Enabled then apply() end end})
	FontOn = Healthbar:CreateToggle({Name = "Custom Font"})
	RoundSize = Healthbar:CreateSlider({Name = "Round Size", Min = 1, Max = 16, Default = 4})
	if Healthbar.CreateDropdown then
		local fonts = {"LuckiestGuy", "GothamBold", "SourceSansBold", "Arcade", "Fantasy"}
		FontDrop = Healthbar:CreateDropdown({Name = "Font", List = fonts, Default = "LuckiestGuy"})
	end
	if Healthbar.CreateTextList then
		TextList = Healthbar:CreateTextList({Name = "Text", TempText = "use <health>"})
	end
	if Healthbar.CreateColorSlider then
		MainCol = Healthbar:CreateColorSlider({Name = "Main Color"})
		GradCol = Healthbar:CreateColorSlider({Name = "Secondary Color"})
		BgCol = Healthbar:CreateColorSlider({Name = "Background Color"})
		StrokeCol = Healthbar:CreateColorSlider({Name = "Highlight Color"})
		TextCol = Healthbar:CreateColorSlider({Name = "Text Color"})
	end
end)

notify("Aether Port", "Loaded 8 modules", 3)
