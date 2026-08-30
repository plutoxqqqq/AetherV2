-- AetherV2 BedWars source template. Shared setup/non-module logic stays here.
-- Category module blocks live beside this file and are reassembled into bundle.lua for runtime.
-- Run tools/build-bedwars-bundle.py after editing a module.
local license = ... or {}
if type(license) ~= 'table' then license = {} end
license.Closet = license.Closet == true

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local canDebug = not license.Closet
local run = function(func, timeout)
	local started = tick()
	local lastError
	repeat
		local success, result = xpcall(func, debug and debug.traceback or tostring)
		if success then
			return result
		end

		lastError = result
		if not timeout or timeout <= 0 then
			break
		end
		task.wait(0.2)
	until tick() - started >= timeout

	warn('[AetherV2] Skipped a BedWars module during startup: '..tostring(lastError))
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({
	EntityDamageEvent = Instance.new('BindableEvent')
}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
shared.bindable = Instance.new('BindableEvent')
getgenv().vapeEvents = vapeEvents

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local lightingService = cloneref(game:GetService('Lighting'))
local textService = cloneref(game:GetService('TextService'))
local tweenService = cloneref(game:GetService('TweenService'))
local proximityPromptService = cloneref(game:GetService('ProximityPromptService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))

local isnetworkowner = isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
if vape.Categories and not vape.Categories.Exploits then
	vape.Categories.Exploits = vape.Categories.Blatant
end

local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			if type(shared.AetherV2FetchSource) == 'function' then
				return shared.AetherV2FetchSource(path)
			end
			return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/'..select(1, path:gsub('aetherv2/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:sub(-4) == '.lua' then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local bedwars = {}
local rankCache = {}
local store = {
	lastHit = 0,
	attackReach = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	rank = setmetatable({}, {
		__index = function(self, index)
			return {
				async = function()
					if rankCache[index] then
						return rankCache[index]
					end

					if index then
						local rank = bedwars.Client:Get('FetchRanks'):CallServer({index.UserId})
						if typeof(rank) == 'table' and rank[1] and rank[1].rankDivision then
							rankCache[index] = rank[1].rankDivision
							return rankCache[index]
						end
					end

					return nil
				end,
			}
		end
	}),
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	selfProjectiles = {},
	hitchance = {},
	inventories = {},
	kitReady = false,
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {},
	ping = setmetatable({}, {
		__index = function(_, key)
			if key == 'total' or key == 'incoming' then
				local success, value = pcall(lplr.GetNetworkPing, lplr)
				return success and math.max(tonumber(value) or 0, 0) or 0
			end
		end
	})
}
getgenv().store = store

-- Publish stable experience metadata before the BedWars controllers finish loading. Home can
-- therefore identify the game immediately, while GetKit becomes authoritative as soon as the
-- Redux store or replicated player attributes are available.
local function activeBedwarsKit()
	local values = {
		store.equippedKit,
		lplr:GetAttribute('PlayingAsKit'),
		lplr:GetAttribute('PlayingAsKits'),
		lplr:GetAttribute('SelectedKit'),
		lplr:GetAttribute('Kit')
	}
	local ready = store.kitReady == true
	if bedwars.Store and type(bedwars.Store.getState) == 'function' then
		local ok, state = pcall(bedwars.Store.getState, bedwars.Store)
		if ok and type(state) == 'table' then
			ready = ready or type(state.Bedwars) == 'table'
			local bedwarsState = type(state.Bedwars) == 'table' and state.Bedwars or {}
			local kitState = type(state.Kit) == 'table' and state.Kit or {}
			table.insert(values, 1, bedwarsState.kit or kitState.kit or kitState.equippedKit)
		end
	end
	for _, value in values do
		if value ~= nil and tostring(value) ~= '' and tostring(value):lower() ~= 'none' then
			return tostring(value), true
		end
	end
	return nil, ready
end
if type(vape.SetGameInfo) == 'function' then
	vape:SetGameInfo({Name = 'BedWars', GetKit = activeBedwarsKit})
end

local Reach = {}
local HitBoxes = {}
local TrapDisabler
local AntiFallPart
local remotes, sides, oldinvrender, oldSwing = {}, {}, nil, nil
-- Declared before LongJump is registered so its Jade adapter closes over the same runtime
-- instance that is populated later by the direct AutoWin/Jade implementation.
local AetherMatchRuntime

-- Every kit module registers here instead of into a category tab. On the default GUI this
-- is the Kits window opened by the friends icon beside the search bar; GUIs that do not
-- implement that window fall back to the Minigames tab so nothing is lost on them.
local kits = vape.Categories.Kits

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('aetherv2/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0
	local inventory = store.inventory and store.inventory.inventory

	for _, item in pairs(inventory and inventory.items or {}) do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	local inventory = store.inventory and store.inventory.inventory
	for slot, item in pairs(inventory and inventory.items or {}) do
		local itemMeta = item and bedwars.ItemMeta[item.itemType]
		local bowMeta = itemMeta and itemMeta.projectileSource
		if bowMeta and type(bowMeta.ammoItemTypes) == 'table' and type(bowMeta.projectileType) == 'function'
			and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local ok, projectileType = pcall(bowMeta.projectileType, 'arrow')
			local projectileMeta = ok and bedwars.ProjectileMeta[projectileType]
			local bowDamage = projectileMeta and projectileMeta.combat and projectileMeta.combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv, find)
	local inventory = store.inventory and store.inventory.inventory
	for slot, item in pairs(type(inv) == 'table' and inv or inventory and inventory.items or {}) do
		local itemType = item and item.itemType
		if itemType and ((find and itemType:find(itemName, 1, true)) or itemType == itemName) then
			return item, slot
		end
	end
	return nil
end

-- Shared by ProjectileAura and AutoShoot. This used to be duplicated inside both
-- modules; when those copies were consolidated the call sites remained but the
-- helper itself was accidentally omitted, causing either module's loop to stop as
-- soon as it tried to enumerate the available ammunition.
local function projectileMatches(enabled, ...)
	for _, wanted in enabled or {} do
		local needle = tostring(wanted):lower()
		for index = 1, select('#', ...) do
			local value = select(index, ...)
			if value and tostring(value):lower() == needle then return true end
		end
	end
	return false
end

-- Enumerate every compatible source/ammunition pair. Do not stop at the first ammo type: a
-- source may support arrows, kit ammunition, and event ammunition at the same time.
local function getProjectiles(enabled, useSophia, useWhim)
	local projectiles, inventory = {}, store.inventory and store.inventory.inventory
	if type(inventory) ~= 'table' or type(inventory.items) ~= 'table' then return projectiles end
	for _, item in inventory.items do
		local itemMeta = item and bedwars.ItemMeta[item.itemType]
		local source = itemMeta and itemMeta.projectileSource
		local loweredType = item and tostring(item.itemType):lower() or ''
		local specialSource = useSophia and (loweredType:find('sophia', 1, true) or loweredType:find('frost_staff', 1, true))
			or useWhim and (loweredType:find('whim', 1, true) or loweredType:find('magic_book', 1, true))
		if source and item.tool and type(source.projectileType) == 'function' then
			for _, ammoType in source.ammoItemTypes or {} do
				local ammoItem = getItem(ammoType, inventory.items)
				if ammoItem and (ammoItem.amount or 1) > 0 then
					local ok, projectile = pcall(source.projectileType, ammoType)
					local projectileMeta = ok and projectile and bedwars.ProjectileMeta[projectile]
					local ammoMeta = bedwars.ItemMeta[ammoType]
					if projectileMeta and (specialSource or projectileMatches(enabled, ammoType, projectile, item.itemType, itemMeta.displayName, ammoMeta and ammoMeta.displayName, projectileMeta.displayName)) then
						table.insert(projectiles, {item, ammoType, projectile, source, projectileMeta})
					end
				end
			end
		end
	end
	return projectiles
end

local hitMotion = setmetatable({}, {__mode = 'k'})
local function getHitChance(ent, flight)
	flight = tonumber(flight)
	local root = ent and ent.RootPart
	if not root or not root.Parent or not flight or flight <= 0 or flight ~= flight then return 0 end
	local now = tick()
	local velocity = root.AssemblyLinearVelocity
	local horizontal = (velocity * Vector3.new(1, 0, 1)).Magnitude
	local last = hitMotion[root]
	local acceleration = 0
	if last and now > last.Clock then
		acceleration = ((velocity - last.Velocity) / math.max(now - last.Clock, 1 / 240)).Magnitude
	end
	hitMotion[root] = {Velocity = velocity, Clock = now}
	local airborne = ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air
	local errorBudget = (horizontal * flight * 0.28) + (acceleration * flight * flight * 0.12)
	if airborne then errorBudget += math.abs(velocity.Y) * flight * 0.12 end
	return math.clamp((100 - errorBudget) / 100, 0, 1)
end

local function projectileAcceleration(gravity)
	if typeof(gravity) == 'Vector3' then return gravity end
	gravity = math.abs(tonumber(gravity) or workspace.Gravity)
	return Vector3.new(0, -gravity, 0)
end

local function targetProjectileMotion(ent, targetPosition, stationary, raycastParams)
	if stationary then return Vector3.zero, Vector3.zero end
	local root, humanoid = ent and ent.RootPart, ent and ent.Humanoid
	if not root or not root.Parent then return end
	local velocity = root.AssemblyLinearVelocity
	local grounded = humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
	if not grounded and typeof(targetPosition) == 'Vector3' then
		local distance = math.max((tonumber(ent.HipHeight) or 3) + 0.75, 1)
		local ok, floor = pcall(workspace.Raycast, workspace, targetPosition, Vector3.new(0, -distance, 0), raycastParams)
		grounded = ok and floor ~= nil and floor.Normal.Y > 0.15 and velocity.Y <= 0.1
	end
	if grounded then
		return Vector3.new(velocity.X, 0, velocity.Z), Vector3.zero
	end

	local gravity = workspace.Gravity
	local character = ent.Character
	local balloons = character and character:GetAttribute('InflatedBalloons')
	if type(balloons) == 'number' and balloons > 0 then
		gravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
	end
	if root:FindFirstChild('rbxassetid://8200754399') then gravity = 6 end
	if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
		for _, owl in collectionService:GetTagged('Owl') do
			if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
				gravity = 0
				break
			end
		end
	end
	return velocity, Vector3.new(0, -gravity, 0)
end

-- Shared by every BedWars projectile aim module. The solver and transmitted velocity always use
-- the same world-space origin; callers may change the model speed for ping compensation, but the
-- returned vector is normalized back to the real launch speed used by the remote.
local function solveBedwarsProjectile(origin, speed, gravity, ent, targetPosition, options)
	options = type(options) == 'table' and options or {}
	if typeof(origin) ~= 'Vector3' or typeof(targetPosition) ~= 'Vector3' then return end
	speed = tonumber(speed)
	if not speed or speed <= 0 then return end
	local modelSpeed = speed * math.max(tonumber(options.PredictionScale) or 1, 0.05)
	local targetVelocity, targetAcceleration = targetProjectileMotion(
		ent,
		targetPosition,
		options.Stationary == true,
		options.RaycastParams
	)
	if not targetVelocity then return end
	local solution = prediction.SolveIntercept(
		origin,
		modelSpeed,
		projectileAcceleration(gravity),
		targetPosition,
		targetVelocity,
		targetAcceleration,
		0.001,
		math.max(tonumber(options.Lifetime) or 3, 0.001)
	)
	if not solution or solution.InitialVelocity.Magnitude <= 1e-3 then return end
	return {
		AimPosition = origin + solution.InitialVelocity,
		Velocity = solution.InitialVelocity.Unit * speed,
		FlightTime = solution.FlightTime,
		ImpactPosition = solution.ImpactPosition
	}
end

local function projectileLaunchOrigin(baseOrigin, aimVelocity)
	if typeof(baseOrigin) ~= 'Vector3' or typeof(aimVelocity) ~= 'Vector3' or aimVelocity.Magnitude <= 1e-3 then return baseOrigin end
	local constants = bedwars.BowConstantsTable
	if type(constants) ~= 'table' then return baseOrigin end
	local offset = Vector3.new(
		-(tonumber(constants.RelX) or 0),
		-(tonumber(constants.RelY) or 0),
		-(tonumber(constants.RelZ) or 0)
	)
	return (CFrame.lookAt(baseOrigin, baseOrigin + aimVelocity) * CFrame.new(offset)).Position
end

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	local inventory = store.inventory and store.inventory.inventory
	for slot, item in pairs(inventory and inventory.items or {}) do
		local itemMeta = item and bedwars.ItemMeta[item.itemType]
		local swordMeta = itemMeta and itemMeta.sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	local inventory = store.inventory and store.inventory.inventory
	for slot, item in pairs(inventory and inventory.items or {}) do
		local itemMeta = item and bedwars.ItemMeta[item.itemType]
		local toolMeta = itemMeta and itemMeta.breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

-- Resolves the most efficient held tool for a block's break type. store.tools only
-- pre-caches sword/stone/wood/wool, so break types outside that set (most notably the
-- bed frame) used to miss entirely and fall back to whatever was in hand. Any uncached
-- break type is now resolved on demand from the current inventory (finding the axe for
-- the bed, shears for wool, ...) and memoised; the cache is rebuilt whenever the
-- inventory changes (see updateStore). Returns nil when the inventory genuinely holds no
-- tool for the break type, so callers can apply their own fallback (e.g. the pickaxe).
local function getBreakTool(breakType)
	if not breakType then return end
	local cached = store.tools[breakType]
	if cached ~= nil then
		return cached or nil
	end
	local tool = getTool(breakType)
	store.tools[breakType] = tool or false
	return tool
end

local function getWool()
	local inventory = store.inventory and store.inventory.inventory
	for _, wool in pairs(inventory and inventory.items or {}) do
		if wool.itemType and wool.itemType:find('wool', 1, true) then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end
getgenv().getPlacedBlock = getPlacedBlock

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end


local knockbackSpeed, knockbackBoost = 0, tick()
local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return (20 + (knockbackBoost > tick() and knockbackSpeed or 0)) * (multi + 1)
end
getgenv().getSpeed = getSpeed

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function getHotbar(tool)
	local inventory = store.inventory or {}
	for i, v in (inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar

local function hotbarSwitch(slot)
	local inventory = store.inventory or {}
	if slot ~= nil and inventory.hotbarSlot ~= slot then
		local changed = false
		local connection = vapeEvents.InventoryChanged.Event:Connect(function()
			changed = true
		end)
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		-- Redux dispatch may publish InventoryChanged synchronously. Connecting first avoids
		-- missing that event, and the deadline prevents a renamed action from hanging a module.
		local deadline = tick() + 0.6
		repeat task.wait() until changed or (store.inventory and store.inventory.hotbarSlot == slot) or tick() >= deadline
		connection:Disconnect()
		return changed or (store.inventory and store.inventory.hotbarSlot == slot) or false
	end
	return inventory.hotbarSlot == slot
end
getgenv().hotbarSwitch = hotbarSwitch

-- Older kit ports referenced these helpers as globals even though the preserved match file never
-- defined them. Keep the implementations here, in the direct BedWars file, so those modules fail
-- closed instead of crashing only when their ability is first used.
local function getFunctionRange()
	-- Every caller already supplies a conservative live-build fallback. Blindly guessing a number
	-- from debug constants is less safe than using that explicit fallback.
	return nil
end

local function getFacingEntity(options)
	options = type(options) == 'table' and table.clone(options) or {}
	if not entitylib.isAlive then return nil end
	local root = entitylib.character and entitylib.character.RootPart
	if not root then return nil end
	options.Origin = options.Origin or root.Position
	options.Part = options.Part or 'RootPart'
	local ok, targets = pcall(entitylib.AllPosition, options)
	if not ok or type(targets) ~= 'table' then return nil end
	local look = gameCamera.CFrame.LookVector
	local best, bestDot
	for _, target in ipairs(targets) do
		local part = target and target[options.Part]
		local delta = part and part.Position - options.Origin
		if delta and delta.Magnitude > 0.001 then
			local dot = look:Dot(delta.Unit)
			if dot > 0.35 and (not bestDot or dot > bestDot) then
				best, bestDot = target, dot
			end
		end
	end
	return best
end

local function fireProjectile(item, ammo, projectile, target)
	if not entitylib.isAlive or type(item) ~= 'table' or not item.tool or not item.tool.Parent then return false end
	local root = entitylib.character and entitylib.character.RootPart
	local targetPart = target and (target.RootPart or target.PrimaryPart)
	local projectileMeta = bedwars.ProjectileMeta and bedwars.ProjectileMeta[projectile]
	if not root or not targetPart or not projectileMeta then return false end
	local speed = tonumber(projectileMeta.launchVelocity) or 100
	if speed <= 0 then return false end
	local origin = root.Position
	local velocity = CFrame.lookAt(origin, targetPart.Position).LookVector * speed
	local id = httpService:GenerateGUID(true)
	local draw = {drawDurationSeconds = projectileMeta.drawDurationSeconds or 1, shotId = httpService:GenerateGUID(false)}
	local remoteOK, remote = pcall(function()
		return bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	if not remoteOK or not remote or type(remote.InvokeServer) ~= 'function' then return false end
	pcall(bedwars.ProjectileController.createLocalProjectile, bedwars.ProjectileController,
		projectileMeta, ammo, projectile, origin, id, velocity, draw)
	local called, result = pcall(remote.InvokeServer, remote, item.tool, ammo, projectile,
		origin, origin, velocity, id, draw, workspace:GetServerTimeNow() - 0.045)
	if called and result ~= false then
		store.lastProjectileFire = workspace:GetServerTimeNow()
		targetinfo.Targets[target] = tick() + 1
		return true
	end
	return false
end

local function isFirstPerson()
	local camera = workspace.CurrentCamera or gameCamera
	return camera and (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1 or false
end

local function isGUIOpen()
	local scaled = vape.gui and vape.gui:FindFirstChild('ScaledGui')
	local click = scaled and scaled:FindFirstChild('ClickGui')
	return click and click.Visible or false
end

local function isHoldingItem(names)
	local hand = store.hand
	local held = hand and (hand.itemType or (hand.tool and hand.tool.Name))
	if not held then return false end
	for _, name in ipairs(names or {}) do
		if held == name or tostring(held):find(tostring(name), 1, true) then return true end
	end
	return false
end

local function getWorldFolder()
	local map = workspace:FindFirstChild('Map')
	if not map then return nil end
	if map:FindFirstChild('Blocks') then return map end
	for _, object in ipairs(map:GetDescendants()) do
		if object.Name == 'Blocks' and (object:IsA('Folder') or object:IsA('Model')) then return object.Parent end
	end
	return nil
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return vape:CreateNotification(...) end

-- Picks the first name this build's AnimationType actually defines. Naming a constant directly
-- and falling through with `or` silently substitutes a completely different animation when the
-- name is missing, which is how firing a projectile ended up playing a punch.
local function resolveAnimation(names)
	local types = bedwars.AnimationType
	if type(types) ~= 'table' then return nil end
	for _, name in names do
		if types[name] ~= nil then
			return types[name]
		end
	end
	return nil
end

-- Finds an animation by what its name MEANS rather than by an exact constant. Every constant we
-- could name is a name this build happens to use today: FP_BOW_SHOOT and BOW_SHOOT are not in it,
-- which is why the shot fired in silence with nothing to look at. `groups` are word sets tried
-- best-first - every word in a group has to appear somewhere in the animation's name - and
-- `reject` throws out the near misses (the charge and draw animations sit right next to the shot
-- in the same enum). Results are memoised per key because this walks the whole enum.
local animationMatches = {}
local function matchAnimation(key, groups, reject)
	local cached = animationMatches[key]
	if cached ~= nil then
		return cached or nil
	end
	local types = bedwars.AnimationType
	if type(types) ~= 'table' then return nil end

	local found
	for _, words in groups do
		for name, value in types do
			-- A TS enum carries its reverse mapping too, so half the pairs are number -> name.
			if type(name) ~= 'string' then continue end
			local lowered = name:lower()
			local hit = true
			for _, word in words do
				if not lowered:find(word, 1, true) then
					hit = false
					break
				end
			end
			if hit and reject then
				for _, word in reject do
					if lowered:find(word, 1, true) then
						hit = false
						break
					end
				end
			end
			if hit then
				found = value
				break
			end
		end
		if found ~= nil then break end
	end

	if found == nil then
		animationMatches[key] = false
	else
		animationMatches[key] = found
	end
	return found
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

-- Thousands separators for the resource counters. Written out rather than pulled from a
-- library because nothing else in this file needed one.
local function formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local sign = ''
	if text:sub(1, 1) == '-' then
		sign, text = '-', text:sub(2)
	end
	local out = text:reverse():gsub('(%d%d%d)', '%1,'):reverse()
	return sign..(out:gsub('^,', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end
getgenv().switchItem = switchItem

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout, nil
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local function waitForChildYield(obj, timeout, ...)
	local check, returned = tick(), obj
	for _, v in { ... } do
		if not returned then
			break
		end
		check = tick() + timeout
		repeat
			local new = returned:FindFirstChild(v)
			if new or tick() > check then
				returned = new
				break
			end
			task.wait()
		until false
	end
	return returned
end

local function rakNetCheck(module)
	if not (raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
		notif(module, 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		return false
	end

	return true
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local getBlockHits
local sortmethods, breakmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end,
	Mouse = function(a, b)
		local mouse = lplr:GetMouse()
		local origin = Vector2.new(mouse.X, mouse.Y)

		local posa, visa = gameCamera:WorldToScreenPoint(a.Entity.RootPart.Position)
		local posb, visb = gameCamera:WorldToScreenPoint(b.Entity.RootPart.Position)
		local dista = visa and (Vector2.new(posa.X, posa.Y) - origin).Magnitude or math.huge
        local distb = visb and (Vector2.new(posb.X, posb.Y) - origin).Magnitude or math.huge
        return (dista == dista and dista or math.huge) < (distb == distb and distb or math.huge)
	end
}, {
	Health = function(...)
		return getBlockHits(...)
	end,
	Distance = function(a)
		local pos = (entitylib.isAlive and (entitylib.character.RootPart.Position - Vector3.new(0, 1, 0)) or Vector3.zero)
		return (pos - Vector3.new(a.Position.X, pos.Y, a.Position.Z)).Magnitude
	end
}

local function screenPriorityDistance(entry, origin)
	local ent = entry and entry.Entity
	local root = ent and ent.RootPart
	if not root then return math.huge end
	local point, visible = gameCamera:WorldToViewportPoint(root.Position)
	if not visible then return math.huge end
	return (Vector2.new(point.X, point.Y) - origin).Magnitude
end
sortmethods.None = function() return false end
sortmethods.Closest = function(a, b) return (a.Magnitude or math.huge) < (b.Magnitude or math.huge) end
sortmethods.Farthest = function(a, b) return (a.Magnitude or 0) > (b.Magnitude or 0) end
sortmethods['Lowest health'] = function(a, b) return (a.Entity.Health or math.huge) < (b.Entity.Health or math.huge) end
sortmethods['Highest health'] = function(a, b) return (a.Entity.Health or 0) > (b.Entity.Health or 0) end
sortmethods.Mouse = function(a, b)
	local origin = inputService:GetMouseLocation()
	return screenPriorityDistance(a, origin) < screenPriorityDistance(b, origin)
end
sortmethods.Crosshair = function(a, b)
	local origin = gameCamera.ViewportSize / 2
	return screenPriorityDistance(a, origin) < screenPriorityDistance(b, origin)
end
shared.AetherScreenSorts = {[sortmethods.Mouse] = 'Mouse', [sortmethods.Crosshair] = 'Crosshair'}
local sortlist = {}
for name in sortmethods do table.insert(sortlist, name) end
table.sort(sortlist)
getgenv().sortlist = sortlist


run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') and not ent:HasTag('trainingRoomDummy') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)
					if plr ~= nil then
						table.insert(entity.Connections, hum.AnimationPlayed:Connect(function(track)
							entitylib.Events.AnimationPlayed:Fire(plr, track)
						end))
					end

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

local require, debug = require, debug
shared.gg = {}
run(function()
	canDebug = not table.find({'Solara', 'Xeno'}, ({identifyexecutor()})[1]) and true or false
	if not canDebug then
		local cheatenginelib = loadstring(downloadFile('aetherv2/libraries/cheatenginelib.lua'), 'cheatenginelib')(vape, vapeEvents, entitylib)
		require = function(v)
			return cheatenginelib[({v:GetFullName():gsub(lplr.Name, 'PlayerTemplate')})[1]]:await()
		end
		debug = setmetatable({getproto = function() return function() end end}, {
			__index = function(self, index)
				self[index] = function() end
				return self[index]
			end
		})
	end
end)

local CheatersFlagged = {}
run(function()
	-- Both waits below are bounded, and that is the whole point.
	--
	-- This chunk runs on the loader's own thread, so anything that spins here spins the load. The
	-- old loops had no exit at all: if the Knit require never resolved (a slow join, or a path moved
	-- by a game update) or this executor's debug library never filled in the upvalue, the loading
	-- screen sat at 88% forever and no GUI ever appeared. Now they give up and say so - run() reports
	-- it, and the loader carries on to build the menu.
	local KnitInit, Knit
	local knitDeadline = tick() + 45
	repeat
		KnitInit, Knit = pcall(function()
			return require(replicatedStorage.rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
		end)
		if KnitInit and Knit then break end
		task.wait()
	until tick() > knitDeadline
	if not (KnitInit and Knit) then
		error('BedWars Knit never became available - the game has not finished loading')
	end

	if canDebug and not debug.getupvalue(Knit.Start, 1) then
		local upvalueDeadline = tick() + 15
		repeat task.wait() until debug.getupvalue(Knit.Start, 1) or tick() > upvalueDeadline
		if not debug.getupvalue(Knit.Start, 1) then
			-- This executor's debug library cannot read it. Everything that needs it is already
			-- behind a canDebug check with a fallback, so carry on without rather than hang.
			warn('[AetherV2] debug.getupvalue is unavailable here - modules that need it are disabled')
			canDebug = false
		end
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak, OldHit = Client.Get, nil, nil

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AbilityIndicatorUtil = require(replicatedStorage.TS.games.bedwars.items['ability-indicator']['ability-indicator-util']).AbilityIndicatorUtil,
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AdetundeUpgradeMeta = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-upgrades']).FrostyHammerUpgradeMeta,
		AdetundeUtil = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-util']).FrostyHammerUtil,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BedwarsKitSkin = canDebug and debug.getupvalue(require(replicatedStorage.TS.games.bedwars['kit-skin']['bedwars-kit-skin-meta']).getKitSkinMetadata, 1) or {},
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BlockSelector = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.select['block-selector']).BlockSelector,
		BowConstantsTable = canDebug and debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8) or {RelX = 0, RelY = 0, RelZ = 0},
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EnchantMeta = require(replicatedStorage.TS.enchant['enchant-meta']).EnchantMeta,
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GamePlayer = require(replicatedStorage.TS.player['game-player']),
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		-- Every kit module talks to the server through `Handler:Get(name):Fire(method, ...)`,
		-- but nothing in this build ever defined Handler. The table's __index falls through to
		-- Knit.Controllers, which has no 'Handler' either, so bedwars.Handler was nil and every
		-- single kit threw "attempt to index nil value" on its first tick - which is exactly what
		-- "none of the kit modules work, they all say the game has changed" was. This is that
		-- wrapper, over the same Client the rest of the file uses.
		--
		-- Lookups are memoised (a kit loop runs at 10Hz and must not re-resolve a remote every
		-- pass) but only on success, so a remote that is not up yet is retried rather than
		-- cached as broken for the rest of the match.
		Handler = (function()
			local cache = {}
			local api = {}

			function api:Get(remoteName)
				local entry = cache[remoteName]
				if entry then return entry end

				local ok, remote = pcall(function()
					return bedwars.Client:Get(remoteName)
				end)
				remote = ok and remote or nil

				entry = {
					Remote = remote,
					instance = remote and remote.instance or nil,
					Fire = function(_, method, ...)
						if not remote then
							error('remote "'..tostring(remoteName)..'" is unavailable', 0)
						end
						local call = remote[method]
						if not call then
							error('remote "'..tostring(remoteName)..'" has no '..tostring(method), 0)
						end
						return call(remote, ...)
					end
				}

				if remote then
					cache[remoteName] = entry
				end
				return entry
			end

			return api
		end)(),
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = require(replicatedStorage.TS.item['item-meta']).items,
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NotificationController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SummonerKitBalance = require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-balance']).SummonerKitBalance,
		SummonerUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-util']),
		StatusEffectUtil = require(replicatedStorage.TS['status-effect']['status-effect-util']).StatusEffectUtil,
		StatusEffectMeta = require(replicatedStorage.TS['status-effect']['status-effect-type']).StatusEffectType,
		SorcererBalance = require(replicatedStorage.TS.balance['sorcerer-balance']).SorcererBalance,
		SyncEvents = require(lplr.PlayerScripts.TS['client-sync-events']).ClientSyncEvents,
		SharedConstants = canDebug and require(replicatedStorage.TS['shared-constants']).CpsConstants or {},
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = canDebug and debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 7) or {},
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})
	getgenv().bedwars = bedwars
	-- cv kit modules use the older AudioManager spelling. Keep that compatibility surface backed
	-- by Aether's resolved SoundManager rather than re-requiring an obsolete game module.
	if not bedwars.AudioManager then
		bedwars.AudioManager = {
			playAudio = function(_, sound, options)
				return bedwars.SoundManager:playSound(sound, options)
			end
		}
	end
	store.enchants = setmetatable({}, {
		__index = function(self, plr)
			return {
				async = function()
					if plr and plr.Character then
						for i in plr.Character:GetAttributes() do
							if i:find('StatusEffect_') and not i:find('_stacks') then
								local name = bedwars.StatusEffectMeta[({i:gsub('StatusEffect_', '')})[1]]
								if bedwars.StatusEffectMeta[name] then
									name = bedwars.StatusEffectMeta[name]
									for num = 1, 3 do
										name = name:gsub(`_{num}`, '')
									end

									if bedwars.EnchantMeta[name] then
										return bedwars.EnchantMeta[name].image
									end
								end
							end
						end
					end
					return nil
				end,
			}
		end
	})

	local function createMethodHook(object, method)
		local original = object[method]
		local hooks, order = {}, 0
		local wrapper

		local function sync()
			if #hooks > 0 then
				object[method] = wrapper
			elseif object[method] == wrapper then
				object[method] = original
			end
		end

		wrapper = function(...)
			local index = 0
			local function nextHook(...)
				index += 1
				local hook = hooks[index]
				if hook then
					return hook.Callback(nextHook, ...)
				end
				return original(...)
			end
			return nextHook(...)
		end

		return {
			Add = function(_, id, priority, callback)
				for i = #hooks, 1, -1 do
					if hooks[i].Id == id then
						table.remove(hooks, i)
					end
				end

				order += 1
				local entry = {
					Id = id,
					Priority = priority or 100,
					Order = order,
					Callback = callback,
				}

				table.insert(hooks, entry)
				table.sort(hooks, function(a, b)
					return a.Priority == b.Priority and a.Order < b.Order or a.Priority < b.Priority
				end)
				sync()

				return function()
					for i = #hooks, 1, -1 do
						if hooks[i] == entry then
							table.remove(hooks, i)
						end
					end
					sync()
				end
			end,
			Destroy = function()
				table.clear(hooks)
				sync()
			end,
		}
	end

	bedwars.ProjectileLaunchHook = createMethodHook(bedwars.ProjectileController, 'calculateImportantLaunchValues')
	vape:Clean(function()
		bedwars.ProjectileLaunchHook:Destroy()
	end)

	local function getproto(...)
		local success, res = pcall(debug.getproto, ...)
		return success and res or function() end
	end
	local remoteNames = {
		AfkStatus = canDebug and getproto(Knit.Controllers.AfkController.KnitStart, 1) or function() end,
		AttackEntity = canDebug and Knit.Controllers.SwordController.sendServerRequest or function() end,
		BeePickup = canDebug and Knit.Controllers.BeeNetController.trigger or function() end,
		CannonAim = canDebug and getproto(Knit.Controllers.CannonController.startAiming, 5) or function() end,
		CannonLaunch = canDebug and Knit.Controllers.CannonHandController.launchSelf or function() end,
		ConsumeBattery = canDebug and getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1) or function() end,
		ConsumeItem = canDebug and getproto(Knit.Controllers.ConsumeController.onEnable, 1) or function() end,
		ConsumeSoul = canDebug and Knit.Controllers.GrimReaperController.consumeSoul or function() end,
		ConsumeTreeOrb = canDebug and getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1) or function() end,
		DepositPinata = canDebug and getproto(getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5) or function() end,
		DragonBreath = canDebug and getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5) or function() end,
		DragonEndFly = canDebug and getproto(Knit.Controllers.VoidDragonController.flapWings, 1) or function() end,
		DragonFly = canDebug and Knit.Controllers.VoidDragonController.flapWings or function() end,
		DropItem = canDebug and Knit.Controllers.ItemDropController.dropItemInHand or function() end,
		EquipItem = canDebug and getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 4) or function() end,
		FireProjectile = canDebug and debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2) or function() end,
		GroundHit = canDebug and Knit.Controllers.FallDamageController.KnitStart or function() end,
		GuitarHeal = canDebug and Knit.Controllers.GuitarController.performHeal or function() end,
		HannahKill = canDebug and getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1) or function() end,
		HarvestCrop = canDebug and getproto(getproto(Knit.Controllers.CropController.KnitStart, 4), 1) or function() end,
		KaliyahPunch = canDebug and getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1) or function() end,
		MageSelect = canDebug and getproto(Knit.Controllers.MageController.registerTomeInteraction, 1) or function() end,
		MinerDig = canDebug and getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1) or function() end,
		PickupItem = canDebug and Knit.Controllers.ItemDropController.checkForPickup or function() end,
		PickupMetal = canDebug and getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4) or function() end,
		ReportPlayer = canDebug and require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer or function() end,
		ResetCharacter = canDebug and getproto(Knit.Controllers.ResetController.createBindable, 1) or function() end,
		SpawnRaven = canDebug and getproto(Knit.Controllers.RavenController.KnitStart, 1) or function() end,
		SummonerClawAttack = canDebug and Knit.Controllers.SummonerClawHandController.attack or function() end,
		WarlockTarget = canDebug and getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2) or function() end
	}

	local packages = httpService:JSONDecode(downloadFile('aetherv2/profiles/packages.json'))
	local function dumpRemote(tab)
		if not tab then return '' end
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' and packages.remotes[i] then
			remote = packages.remotes[i]
		end
		if remote == '' then
			notif('AetherV2', 'Failed to grab remote ('..i..')', 10, 'alert')
		end
		remotes[i] = remote
	end
    getgenv().remotes = remotes

	OldBreak = bedwars.BlockController.isBlockBreakable
	OldHit = bedwars.BlockBreaker.hitBlock

	bedwars.BlockBreaker.hitBlock = function(...)
        store.lastHit = tick()
        return OldHit(...)
    end
	if canDebug then
		Client.Get = function(self, remoteName)
			local call = OldGet(self, remoteName)

			if remoteName == remotes.AttackEntity then
				return {
					instance = call.instance,
					SendToServer = function(_, attackTable, ...)
						local suc, plr = pcall(function()
							return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
						end)

						-- Reach/telemetry work off the validate payload, but a malformed or
						-- differently-shaped attackTable must NEVER stop the hit from being sent.
						-- Reading it unguarded used to throw right here and silently eat the swing
						-- (the "script occasionally won't let me hit" bug); guard every field.
						local validate = attackTable.validate
						local selfField = validate and validate.selfPosition
						local targetField = validate and validate.targetPosition
						if selfField and targetField and selfField.value and targetField.value then
							local selfpos, targetpos = selfField.value, targetField.value
							local dist = (selfpos - targetpos).Magnitude
							store.attackReach = (dist * 100) // 1 / 100
							store.attackReachUpdate = tick() + 1

							-- dist > 0 guards CFrame.lookAt on equal positions (its LookVector is NaN,
							-- and NaN would poison selfPosition and make the server reject the hit).
							if (Reach.Enabled or HitBoxes.Enabled) and dist > 0 then
								validate.raycast = validate.raycast or {}
								selfField.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max(dist - 14.399, 0)
							end
						end

						-- Friends/whitelist protection: only drop the hit when the lookup positively
						-- reports this player as protected. If it errors, fail OPEN (send the hit)
						-- rather than silently eating a legit attack.
						if suc and plr then
							local ok, targetable = pcall(function()
								return (select(2, whitelist:get(plr)))
							end)
							if ok and not targetable then return end
						end

						return call:SendToServer(attackTable, ...)
					end
				}
			elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
				return {SendToServer = function() end}
			end

			return call
		end
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	getBlockHits = function(block, blockpos)
		if not block then return 0 end
		local itemMeta = bedwars.ItemMeta[block.Name]
		local breaktype = itemMeta and itemMeta.block and itemMeta.block.breakType
		local tool = getBreakTool(breaktype)
		local toolMeta = tool and bedwars.ItemMeta[tool.itemType]
		tool = toolMeta and toolMeta.breakBlock and toolMeta.breakBlock[breaktype] or 2
		return math.max(tonumber(getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos))) or tonumber(block:GetAttribute('MaxHealth')) or 1, 1) / math.max(tonumber(tool) or 2, 0.01)
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	local function isMinable(pos)
		for _, side in {Vector3.new(0, 3, 0), Vector3.new(3, 0, 0), Vector3.new(0, 0, 3)} do
			side = pos + side
			local block = getPlacedBlock(side)
			if not block or (block:GetAttribute("PlacedByUserId") or 0) ~= 0 then
				return true
			end
		end
		return false
	end
	-- How a finished path is scored, i.e. which of several ways in gets picked.
	--
	--   Blatant (the default, prefs nil)  - quickest, and nothing else. Lowest total hits wins.
	--   Legit (prefs.Legit)               - must be in line of sight, then closest to the player,
	--                                       while still preferring the efficient way in: distance is
	--                                       added to the cost at half a hit per block, so a genuinely
	--                                       cheaper path still beats a nearer one, and two comparable
	--                                       paths are decided by which is nearer to you.
	--   prefs.FewestBlocks (Health mode)  - number of blocks to break always wins, whatever they
	--                                       cost, with cost only breaking ties.
	local function pathScore(node, cost, depth, prefs)
		local primary, secondary = cost, depth or 0
		if prefs and prefs.FewestBlocks then
			primary, secondary = depth or 0, cost
		end
		if prefs and prefs.Legit and entitylib.isAlive then
			local from = entitylib.character.RootPart.Position
			primary += ((node - from).Magnitude / 3) * 0.5
		end
		return primary, secondary
	end

	local function calculatePath(target, blockpos, method, angle, wallcheck, prefs)
		-- Breaker's "Legit" mode passes a line-of-sight predicate function as `wallcheck`.
		-- When present, only air nodes genuinely visible from the camera are eligible AND the
		-- entire break path to that node must be visible, so we never blindly mine through walls.
		-- Any non-function value keeps the original behaviour (boolean/Vector3 -> isMinable gate),
		-- so AutoTool and Blatant breaking are completely unaffected.
		local legitCheck = type(wallcheck) == 'function' and wallcheck or nil
		local visited, unvisited, distances, air, path = {}, {{0, blockpos, 0}}, {[blockpos] = 0}, {}, {}
		local depths, visibility = {[blockpos] = 0}, {}
		local function push(value)
			table.insert(unvisited, value)
			local index = #unvisited
			while index > 1 do
				local parent = math.floor(index / 2)
				if unvisited[parent][1] <= value[1] then break end
				unvisited[index], index = unvisited[parent], parent
			end
			unvisited[index] = value
		end
		local function pop()
			local root, tail = unvisited[1], table.remove(unvisited)
			if #unvisited > 0 then
				local index = 1
				while index * 2 <= #unvisited do
					local child = index * 2
					if child < #unvisited and unvisited[child + 1][1] < unvisited[child][1] then child += 1 end
					if unvisited[child][1] >= tail[1] then break end
					unvisited[index], index = unvisited[child], child
				end
				unvisited[index] = tail
			end
			return root
		end

		local function isNodeVisible(pos)
			if visibility[pos] == nil then
				visibility[pos] = not legitCheck or legitCheck(pos)
			end
			return visibility[pos]
		end

		for _ = 1, (legitCheck and 300 or 10000) do
			local node = pop()
			if not node then break end
			if node[1] ~= distances[node[2]] then continue end
			visited[node[2]] = true

			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block and isNodeVisible(node[2]) then
						air[node[2]] = true
					end
					continue
				end

				local facing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
				local direction = (block.Position - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1)
				if facing.Magnitude < 0.001 or direction.Magnitude < 0.001 or math.acos(math.clamp(facing.Unit:Dot(direction.Unit), -1, 1)) > (math.rad(angle) / 2) then
					continue
				end

				local curdist = (method and method(block, side) or getBlockHits(block, side)) + node[1]
				if curdist < (distances[side] or math.huge) then
					push({curdist, side, node[3] + 1})
					distances[side] = curdist
					depths[side] = node[3] + 1
					path[side] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		local bestPrimary, bestSecondary = math.huge, math.huge
		local function consider(node)
			local primary, secondary = pathScore(node, distances[node], depths[node], prefs)
			if primary < bestPrimary or (primary == bestPrimary and secondary < bestSecondary) then
				pos, cost = node, distances[node]
				bestPrimary, bestSecondary = primary, secondary
			end
		end
		for node in air do
			if legitCheck then
				local ok, cur, guard = true, node, 0
				while cur ~= blockpos do
					guard += 1
					if guard > 10000 or not isNodeVisible(cur) then
						ok = false
						break
					end
					cur = path[cur]
				end
				if ok then
					consider(node)
				end
			elseif not wallcheck or isMinable(node) then
				consider(node)
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path,
				depths[pos],
			}
			return pos, cost, path, depths[pos]
		end
		return nil
	end
	bedwars.calculateBreakPath = calculatePath

	bedwars.placeBlock = function(pos, item)
		local function place()
			if not getItem(item) then return end
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
		-- IgnorePlaceHitboxes only suppresses avatar queries for this one placement
		-- transaction. Leaving CanQuery disabled on characters also removes them from
		-- projectile raycasts, which is why arrows could stop registering hits.
		if bedwars.IgnorePlaceHitboxes then
			return bedwars.IgnorePlaceHitboxes(place)
		end
		return place()
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, visualise, sort, angle, wallcheck, prefs)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive then return end

		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge, nil, nil, nil
		local bestPrimary, bestSecondary = math.huge, math.huge

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath, ddepth = calculatePath(block, v * 3, sort, angle or 360, wallcheck, prefs)
			if dpos then
				-- Score the whole entry the same way its nodes were scored, so a multi-cell block
				-- (a bed) picks the cell whose way in matches the mode too, not just the cheapest.
				local primary, secondary = pathScore(dpos, dcost, ddepth, prefs)
				if primary < bestPrimary or (primary == bestPrimary and secondary < bestSecondary) then
					cost, pos, target, path = dcost, dpos, v * 3, dpath
					bestPrimary, bestSecondary = primary, secondary
				end
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			local dmeta = bedwars.ItemMeta[dblock.Name]
			local breaktype = dblock.Name == 'gumdrop_bounce_pad' and 'stone' or (dmeta and dmeta.block and dmeta.block.breakType)
			-- getBreakTool searches the inventory for uncached break types like the bed
			-- frame, so the axe (or shears for wool) is selected instead of whatever is in
			-- hand. Fall back to the pickaxe when no better tool exists so we never silently
			-- mine the bed with a leftover pickaxe from a prior stone break.
			local tool = getBreakTool(breaktype) or store.tools.stone
			if tool then
				local now = workspace:GetServerTimeNow()
				local held = store.hand and store.hand.tool
				local holdingSword = held ~= nil and store.tools.sword ~= nil and held == store.tools.sword.tool
				local holdingProjectile = held ~= nil and store.hand.toolType == 'bow'
				-- Keep the sword equipped while a swing was just thrown so KillAura isn't
				-- interrupted, and keep the bow while ProjectileAura is actively firing so its
				-- shot isn't yanked away — but never leave the WRONG break tool equipped: if
				-- we're holding e.g. a leftover pickaxe on a wood block, still switch to the
				-- correct tool. The old guard blocked every switch during combat, which is how a
				-- pickaxe from a prior stone break ended up breaking wood while combat was active.
				local busyMelee = (now - bedwars.SwordController.lastAttack) <= 0.4 and holdingSword
				local busyProjectile = (now - (store.lastProjectileFire or 0)) <= 0.35 and holdingProjectile
				if not (busyMelee or busyProjectile) then
					if visualise then
						local hotbar = getHotbar(tool.tool)
						if hotbar then hotbarSwitch(hotbar) end
					end
					if not held or held ~= tool.tool then switchItem(tool.tool, 0) end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			local request = bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 0.25
						return result
					end

					-- Every BedWars call below is isolated so that one that shifted in a game
					-- update can't throw and abort the rest of this callback. Previously a single
					-- broken API (e.g. the removed BlockBreaker.healthbarMaid) silently took down
					-- both the healthbar and the swing animation that runs just after it.
					local showEffects = type(effects) == 'function' and effects() or effects
					local showAnimation = type(anim) == 'function' and anim() or anim
					if showEffects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						local drawHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						if drawHealthbar then
							pcall(drawHealthbar, bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, tonumber(dblock:GetAttribute('MaxHealth')) or blockhealthbar.blockHealth, blockdmg, dblock)
						end
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							pcall(function() bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr) end)
							if bedwars.BlockBreaker.healthbarMaid then
								pcall(function() bedwars.BlockBreaker.healthbarMaid:DoCleaning() end)
							end
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							pcall(function() bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr) end)
						end
					end

					if showAnimation then
						pcall(function()
							local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
							bedwars.ViewmodelController:playAnimation(15)
							task.wait(0.3)
							animation:Stop()
							animation:Destroy()
						end)
					end
				end
				return result
			end)

			return pos, path, target, request
		end
		return nil
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			local state = type(new.Bedwars) == 'table' and new.Bedwars or {}
			local previousKit = store.equippedKit
			local previousReady = store.kitReady
			store.kitReady = type(new.Bedwars) == 'table'
			store.equippedKit = state.kit and state.kit ~= 'none' and state.kit or ''
			if (previousKit ~= store.equippedKit or previousReady ~= store.kitReady) and type(vape.RefreshGameInfo) == 'function' then
				vape:RefreshGameInfo()
			end
		end

		if new.Game ~= old.Game then
			local state = type(new.Game) == 'table' and new.Game or {}
			store.matchState = state.matchState or 0
			store.queueType = state.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local function normalizeInventory(value)
				value = type(value) == 'table' and value or {}
				local inventory = type(value.inventory) == 'table' and value.inventory or {}
				if type(value.inventory) == 'table' and type(inventory.items) == 'table'
					and type(inventory.armor) == 'table' and type(value.hotbar) == 'table' then return value end
				local normalized = table.clone(value)
				normalized.inventory = table.clone(inventory)
				normalized.inventory.items = type(inventory.items) == 'table' and inventory.items or {}
				normalized.inventory.armor = type(inventory.armor) == 'table' and inventory.armor or {}
				normalized.hotbar = type(value.hotbar) == 'table' and value.hotbar or {}
				return normalized
			end
			local newinv = normalizeInventory(new.Inventory and new.Inventory.observedInventory)
			local oldinv = normalizeInventory(old.Inventory and old.Inventory.observedInventory)
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				-- Rebuild from scratch so on-demand break tools memoised by getBreakTool
				-- (e.g. the bed's axe) are dropped and re-resolved against the new inventory.
				store.tools = {sword = getSword()}
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = newinv.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					if handData then
						toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
					end
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					itemType = currentHand and currentHand.itemType,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})
	if type(vape.RefreshGameInfo) == 'function' then vape:RefreshGameInfo() end

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		local a = {
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		}
		shared.bindable:Fire(a)
		vapeEvents.EntityDamageEvent:Fire(a)
	end))

	vape:Clean(workspace.ChildAdded:Connect(function(projectile)
		task.delay(0, function()
			if projectile and projectile.Parent and entitylib.isAlive and projectile:GetAttribute('ProjectileShooter') == lplr.UserId then
				table.insert(store.selfProjectiles, projectile)
				projectile.Destroying:Once(function()
					local index = table.find(store.selfProjectiles, projectile)
					if index then
						table.remove(store.selfProjectiles, index)
					end
				end)
			end
		end)
	end))

	for _, event in {'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
	sessioninfo:AddItem('Cheater List', '', function()
		local text = ''
		for _, plr in playersService:GetPlayers() do
			if CheatersFlagged[plr] then
				text = text..'\n'..(plr.DisplayName ~= plr.Name and plr.DisplayName..' ('..plr.Name..')' or plr.Name)
			end
		end

		return text
	end, false)

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			store.map = waitForChildYield(workspace, 9e9, 'Map', 'Worlds'):GetChildren()[1]
			mapname = store.map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			if store.map then
				-- Block/terrain-only raycast filter shared by the ground/clear-space checks in
				-- TP Aura, AntiFall and other movement modules. It Includes only the map world
				-- (islands, generators and the placed-Blocks folder), so every one of those casts
				-- hits solid geometry and never a player/NPC. Without this it was left nil, which
				-- made casts collide with characters - e.g. TP Aura's target-facing clear check hit
				-- the target itself and rejected every teleport spot, so the module did nothing.
				local blockRay = RaycastParams.new()
				blockRay.FilterType = Enum.RaycastFilterType.Include
				blockRay.FilterDescendantsInstances = {store.map}
				blockRay.RespectCanCollide = true
				store.blockRaycast = blockRay
				vape:Clean(store.map.Blocks.ChildAdded:Connect(function(v) -- bedwars game is so bad bro 😭 how did you even break this event
					task.delay(0, function()
						if v:GetAttribute('Block') and (v:GetAttribute('PlacedByUserId') or 0) ~= 0 then
							local data = {
								blockRef = {
									blockPosition = v.Position / 3,
								},
								player = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId')),
							}
							for i, v in cache do
								if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
									table.clear(v[3])
									table.clear(v)
									cache[i] = nil
								end
							end
							vapeEvents.PlaceBlockEvent:Fire(data)
						end
					end)
				end))
			end
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = {workspace:WaitForChild('Map', 9e9)}
		store.airRay = rayParams

		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = workspace:Raycast((store.rootpart or entitylib.character.RootPart).Position, Vector3.new(0, -4.5, 0), rayParams) and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity or not canDebug then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			-- The catalogue and the warm-up call are both nice-to-haves, and both are read
			-- through structure the game is free to change - an upvalue index and an item id.
			-- Left unguarded, either one throwing took the whole block down BEFORE shopLoaded
			-- was set, which silently switched off everything that waits on the shop, AutoBuy
			-- included. The shop table itself is what actually matters here.
			pcall(function()
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			end)
			pcall(bedwars.Shop.getShopItem, 'iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				pcall(function()
					bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				end)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		shared.bindable:Destroy()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end, 20)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'NoFallDamage', 'MurderMystery', 'Invisible'} do
	vape:Remove(v)
end

-- MouseTP is universal, but its BedWars choice is installed only after the live BedWars
-- controllers and inventory helpers are ready. Other games keep the shorter Legit/TP list.
do
	local mouseTPBridge = vape.Libraries.MouseTPBridge
	if mouseTPBridge and type(mouseTPBridge.SetBedWars) == 'function' then
		mouseTPBridge:SetBedWars(function(position)
			if not entitylib.isAlive then return false, 'Character missing.' end
			local pearl = getItem('telepearl')
			local meta = bedwars.ProjectileMeta and bedwars.ProjectileMeta.telepearl
			if not pearl or not pearl.tool or not meta then return false, 'No Telepearl is available.' end

			local root = entitylib.character.RootPart
			local target = position
			local aim = prediction.SolveTrajectory(
				root.Position,
				meta.launchVelocity,
				meta.gravitationalAcceleration,
				target,
				Vector3.zero,
				workspace.Gravity,
				0,
				0
			)
			if not aim then return false, 'The selected position is outside Telepearl range.' end

			local remote
			local remoteOK = pcall(function() remote = bedwars.Client:Get(remotes.FireProjectile).instance end)
			if not remoteOK or not remote or type(remote.InvokeServer) ~= 'function' then
				return false, 'The BedWars projectile remote is unavailable.'
			end

			local old = store.hand
			local slot = getHotbar(pearl.tool)
			switchItem(pearl.tool, 0.1)
			if slot then hotbarSwitch(slot) end
			task.wait(0.03)

			local direction = CFrame.lookAt(root.Position, aim).LookVector * meta.launchVelocity
			local id = httpService:GenerateGUID(true)
			local draw = {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}
			local success, result = pcall(function()
				bedwars.ProjectileController:createLocalProjectile(
					meta,
					'telepearl',
					'telepearl',
					root.Position,
					id,
					direction,
					draw
				)
				return remote:InvokeServer(
					pearl.tool,
					'telepearl',
					'telepearl',
					root.Position,
					root.Position,
					direction,
					id,
					draw,
					workspace:GetServerTimeNow() - 0.045
				)
			end)

			if old and old.tool then
				task.delay(0.12, function()
					if old.tool.Parent then
						switchItem(old.tool)
						local oldSlot = getHotbar(old.tool)
						if oldSlot then hotbarSwitch(oldSlot) end
					end
				end)
			end
			return success and result ~= false, success and 'Telepearl launch was rejected.' or tostring(result)
		end)
		vape:Clean(function()
			if vape.Libraries.MouseTPBridge == mouseTPBridge then mouseTPBridge:SetBedWars(nil) end
		end)
	end
end

local AntiFallDirection
local Fly
local LongJump
-- LongJump is the authoritative compatible-tool detector. Anything that needs to know a
-- long-jump tool has genuinely entered its launch window listens for this edge instead of
-- maintaining a second, inevitably stale list of tool activation rules. (Extender used to be
-- its main consumer; it now hooks the four kit controllers directly.)
local longJumpActivation = Instance.new('BindableEvent')
vape:Clean(longJumpActivation)
local Attacking
-- Jade was changed from one hammer into three tiered item types. Keep the compatibility
-- list shared so movement/clutch modules cannot silently drift back to supporting only one tier.
-- BedWars has used both tiered tool ids and the shared jump id while moving Jade between
-- controller implementations. Keep one canonical set so every Jade consumer recognises the
-- held tool and the ability id instead of treating one of the live forms as a different kit.
local jadeHammerNames = {'jade_hammer_3', 'jade_hammer_2', 'jade_hammer_1', 'jade_hammer', 'jade_hammer_jump'}
local jadeJumpAbilities = {'jade_hammer_3_jump', 'jade_hammer_2_jump', 'jade_hammer_1_jump', 'jade_hammer_jump'}

local function normalizeJadeName(value)
	return type(value) == 'string' and value:lower():gsub('[%s%-]+', '_') or nil
end

local function isJadeHammerName(value)
	local normalized = normalizeJadeName(value)
	return normalized ~= nil and (normalized == 'jade_hammer_jump' or normalized:match('^jade_hammer(_%d+)?$') ~= nil)
end

local function getJadeAbility(item)
	if not item then return end
	local itemType = normalizeJadeName(item.itemType or (item.tool and item.tool.Name))
	if not isJadeHammerName(itemType) then return end
	-- Tiered hammers are inventory upgrades, but live builds disagree on whether the
	-- ability is tiered, shared, or exposed directly as jade_hammer_jump.
	local abilities, seen = {}, {}
	local function add(ability)
		if ability and not seen[ability] then seen[ability] = true; table.insert(abilities, ability) end
	end
	if itemType ~= 'jade_hammer_jump' then add(itemType..'_jump') end
	for _, ability in jadeJumpAbilities do add(ability) end
	for _, ability in abilities do
		local ok, ready = pcall(bedwars.AbilityController.canUseAbility, bedwars.AbilityController, ability, {
			disableBlockedAbilityAlert = true
		})
		if ok and ready then return ability end
	end
	return abilities[1]
end

-- Equipping an inventory instance is not the same as pressing the hammer.  In particular,
-- useAbility by itself skips the Jade tool/controller input path in current BedWars builds.
-- Send the real primary-input edge after equipping so the controller creates the movement
-- state that the server expects (and that its movement checks use to permit the launch).
local function activateJadeTool(item)
	if not item or not item.tool then return false end
	switchItem(item.tool, 0.1)
	-- The input edge is ignored while the old hotbar item is still equipped.
	-- Wait briefly for the inventory store and character tool to agree before
	-- pressing the hammer, otherwise LongJump/JadeInstaKill can look enabled
	-- while the Jade controller never sees its activation.
	local equipDeadline = tick() + 0.6
	repeat
		task.wait()
	until (store.hand and store.hand.tool == item.tool) or tick() >= equipDeadline or not entitylib.isAlive
	local center = gameCamera.ViewportSize / 2
	local fired = pcall(function()
		local virtualInput = game:GetService('VirtualInputManager')
		if inputService.TouchEnabled then
			virtualInput:SendTouchEvent(0, Enum.UserInputState.Begin, center.X, center.Y)
			virtualInput:SendTouchEvent(0, Enum.UserInputState.End, center.X, center.Y)
		else
			virtualInput:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
			virtualInput:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
		end
	end)
	if not fired and mouse1click then fired = pcall(mouse1click) end
	return fired
end

--[[
    Combat
]]

--[[AETHER_MODULE:render/HitAccuracy.lua]]
--[[AETHER_MODULE:utility/MemoryFixer.lua]]
--[[AETHER_MODULE:utility/AntiEffect.lua]]
--[[AETHER_MODULE:combat/AimAssist.lua]]

--[[AETHER_MODULE:combat/AutoClicker.lua]]

--[[AETHER_MODULE:combat/BowAssist.lua]]

--[[AETHER_MODULE:combat/NoClickDelay.lua]]

--[[AETHER_MODULE:combat/HitregAdjuster.lua]]
--[[AETHER_MODULE:blatant/DeathAdderAimbot.lua]]
--[[AETHER_MODULE:combat/Reach.lua]]

--[[AETHER_MODULE:combat/ShopClicker.lua]]

--[[AETHER_MODULE:combat/SilentAura.lua]]

--[[AETHER_MODULE:combat/Sprint.lua]]

--[[AETHER_MODULE:combat/TriggerBot.lua]]

--[[AETHER_MODULE:combat/Velocity.lua]]

--[[AETHER_MODULE:blatant/AntiVoid.lua]]

--[[AETHER_MODULE:blatant/NoFallDamage.lua]]

--[[AETHER_MODULE:blatant/AntiDeath.lua]]


--[[AETHER_MODULE:render/ChillLighting.lua]]

-- Water: fills the void with real Roblox water, at exactly the height AntiFall puts its barrier.
--
-- Height comes from AntiFall's own barrier when that module is on, and is worked out the same way
-- (lowest block on the map, minus two) when it is not - so the surface always sits where the
-- barrier does, whether or not you use it.
--
-- Terrain mode is genuine Roblox water: waves, refraction, the lot. It is written locally, so it is
-- yours alone and never replicates. It follows you in slabs and clears the one behind you, because
-- filling a whole BedWars map at once is a lot of voxels for something you only ever see under your
-- feet. Part mode is the cheap version - one plane with the water material and Roblox's own water
-- texture on top - for anywhere terrain writes are unavailable.
run(function()
    local Water
    local Mode
    local Size
    local Depth
    local Waves
    local Color
    local part
    local filled
    local oldWater
    local fx        -- underwater screen effects (ColorCorrection / Blur / SunRays), Realistic mode only
    local oldFog    -- saved Lighting fog, put back the moment you surface
    local submerged -- currently below the water surface

    local function barrierHeight()
        if AntiFallPart and AntiFallPart.Parent then
            return AntiFallPart.Position.Y
        end
        local mag = math.huge
        pcall(function()
            for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
                pos = pos * 3
                if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
                    mag = pos.Y
                end
            end
        end)
        if mag == math.huge then return nil end
        return mag - 2
    end

    local function clearTerrain()
        if not filled then return end
        pcall(function()
            workspace.Terrain:FillBlock(filled.CFrame, filled.Size, Enum.Material.Air)
        end)
        filled = nil
    end

    local function applyWaterLook()
        local terrain = workspace.Terrain
        if not oldWater then
            oldWater = {
                Color = terrain.WaterColor,
                Transparency = terrain.WaterTransparency,
                Reflectance = terrain.WaterReflectance,
                WaveSize = terrain.WaterWaveSize,
                WaveSpeed = terrain.WaterWaveSpeed
            }
        end
        terrain.WaterColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        terrain.WaterTransparency = math.clamp(1 - Color.Opacity, 0, 1)
        terrain.WaterWaveSize = Waves.Enabled and 0.15 or 0
        terrain.WaterWaveSpeed = Waves.Enabled and 12 or 0
    end

    local function restoreWaterLook()
        if not oldWater then return end
        local terrain = workspace.Terrain
        pcall(function()
            terrain.WaterColor = oldWater.Color
            terrain.WaterTransparency = oldWater.Transparency
            terrain.WaterReflectance = oldWater.Reflectance
            terrain.WaterWaveSize = oldWater.WaveSize
            terrain.WaterWaveSpeed = oldWater.WaveSpeed
        end)
        oldWater = nil
    end

    local function makePart(height)
        if part then
            part.Position = Vector3.new(0, height, 0)
            return
        end
        part = Instance.new('Part')
        part.Name = 'AetherWater'
        part.Size = Vector3.new(10000, Depth.Value, 10000)
        part.Position = Vector3.new(0, height, 0)
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Material = Enum.Material.Water
        part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        part.Transparency = math.clamp(1 - Color.Opacity, 0, 1)
        part.Parent = workspace
        -- Roblox's own water surface texture on the top face, so Part mode reads as water rather
        -- than as a flat blue slab.
        local texture = Instance.new('Texture')
        texture.Name = 'WaterSurface'
        texture.Face = Enum.NormalId.Top
        texture.Texture = 'rbxasset://textures/water/normal_1.dds'
        texture.StudsPerTileU = 24
        texture.StudsPerTileV = 24
        texture.Transparency = 0.35
        texture.Parent = part
        pcall(function()
            bedwars.QueryUtil:setQueryIgnored(part, true)
        end)
    end

    local function removePart()
        if part then
            part:Destroy()
            part = nil
        end
    end

    ----------------------------------------------------------------------------
    -- Realistic mode. Terrain water, but glassy and reflective, and it comes alive only while you
    -- are actually in it: the look (fog, colour grade, god-rays, sway) and the buoyancy are applied
    -- when your eyes / body go under the surface and taken straight back off when you surface, so
    -- nothing here ever touches the world while you are stood on dry land.
    ----------------------------------------------------------------------------
    local FX_NAME = 'AetherWaterFX'

    local function applyRealisticLook()
        local terrain = workspace.Terrain
        if not oldWater then
            oldWater = {
                Color = terrain.WaterColor,
                Transparency = terrain.WaterTransparency,
                Reflectance = terrain.WaterReflectance,
                WaveSize = terrain.WaterWaveSize,
                WaveSpeed = terrain.WaterWaveSpeed
            }
        end
        terrain.WaterColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        terrain.WaterTransparency = math.clamp(1 - Color.Opacity, 0, 1)
        -- Glassy: reflect the sky and world off the surface, with livelier waves than the flat look.
		terrain.WaterReflectance = Waves.Enabled and 0.18 or 0.08
		terrain.WaterWaveSize = Waves.Enabled and 0.09 or 0.025
		terrain.WaterWaveSpeed = Waves.Enabled and 7 or 2
    end

    local function ensureFX()
        if fx then return end
        fx = {}
        local cc = Instance.new('ColorCorrectionEffect')
        cc.Name = FX_NAME
        cc.Enabled = false
        cc.Parent = lightingService
        fx.cc = cc
        local blur = Instance.new('BlurEffect')
        blur.Name = FX_NAME..'Blur'
        blur.Enabled = false
        blur.Size = 0
        blur.Parent = lightingService
        fx.blur = blur
        local rays = Instance.new('SunRaysEffect')
        rays.Name = FX_NAME..'Rays'
        rays.Enabled = false
        rays.Parent = lightingService
        fx.rays = rays
    end

    local function restoreFog()
        if not oldFog then return end
        pcall(function()
            lightingService.FogStart = oldFog.Start
            lightingService.FogEnd = oldFog.End
            lightingService.FogColor = oldFog.Color
        end)
        oldFog = nil
    end

    -- Came back up (or left Realistic mode): switch the look off and hand the fog back, but keep the
    -- effect instances around so diving straight back in does not churn them.
    local function surfaced()
        if not submerged then return end
        submerged = false
        restoreFog()
        if fx then
            pcall(function()
                fx.cc.Enabled = false
                fx.blur.Enabled = false
                fx.rays.Enabled = false
            end)
        end
    end

    local function removeFX()
        surfaced()
        if fx then
            for _, effect in fx do
                pcall(function() effect:Destroy() end)
            end
            fx = nil
        end
    end

    -- Called every frame while Realistic is on. surface is the top of the water slab.
    local function updateRealistic(surface)
        ensureFX()
        local cam = gameCamera
        local under = cam and cam.CFrame.Position.Y < surface

        if under then
            if not submerged then
                submerged = true
                if not oldFog then
                    oldFog = {Start = lightingService.FogStart, End = lightingService.FogEnd, Color = lightingService.FogColor}
                end
            end
            local col = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            local sway = 0.5 + 0.5 * math.sin(tick() * 1.4)
            -- Fog closes in the deeper/less clear the water is, so it reads as real water rather
            -- than a blue filter.
            lightingService.FogColor = col
            lightingService.FogStart = 0
            lightingService.FogEnd = 55 + Color.Opacity * 55 + sway * 6
            fx.cc.Enabled = true
            fx.cc.TintColor = col:Lerp(Color3.new(1, 1, 1), 0.05 + 0.04 * sway)
            fx.cc.Brightness = -0.04
            fx.cc.Contrast = 0.12
            fx.cc.Saturation = -0.08
			-- Blur and animated sun rays made this mode both muddy-looking and one
			-- of the most expensive visual modules. Colour/fog provide depth without
			-- adding full-screen render passes.
			fx.blur.Enabled = false
			fx.rays.Enabled = false
        else
            surfaced()
        end

        -- Buoyancy: while your body is under the surface, water drags your speed and floats you back
        -- up, so falling into it feels like water instead of air.
        if entitylib.isAlive then
            local root = entitylib.character.RootPart
            if root and isnetworkowner(root) and root.Position.Y < surface then
                local vel = root.AssemblyLinearVelocity
                local lift = math.clamp(vel.Y * 0.6 + 6, -8, 10)
                root.AssemblyLinearVelocity = Vector3.new(vel.X * 0.85, lift, vel.Z * 0.85)
            end
        end
    end

    local function refresh()
        local height = barrierHeight()
        if not height then return end

        if Mode.Value == 'Part' then
            clearTerrain()
            restoreWaterLook()
            makePart(height)
            part.Size = Vector3.new(10000, Depth.Value, 10000)
            part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
            part.Transparency = math.clamp(1 - Color.Opacity, 0, 1)
            return
        end

        removePart()
        if Mode.Value == 'Realistic' then
            applyRealisticLook()
        else
            applyWaterLook()
        end

        local centre = Vector3.new(0, height, 0)
        if entitylib.isAlive then
            local root = entitylib.character.RootPart
            centre = Vector3.new(root.Position.X, height, root.Position.Z)
        end
        -- Voxels are 4 studs, so snap to that grid: an unsnapped fill leaves seams between slabs.
        centre = Vector3.new(math.floor(centre.X / 4) * 4, math.floor(centre.Y / 4) * 4, math.floor(centre.Z / 4) * 4)
        local size = Vector3.new(Size.Value, math.max(Depth.Value, 4), Size.Value)

        if filled and (filled.CFrame.Position - centre).Magnitude < (Size.Value * 0.25) and filled.Size == size then
            return
        end
        clearTerrain()
        local cframe = CFrame.new(centre)
        local ok = pcall(function()
            workspace.Terrain:FillBlock(cframe, size, Enum.Material.Water)
        end)
        if ok then
            filled = {CFrame = cframe, Size = size}
        else
            -- Terrain writes refused: fall back to the plane rather than showing nothing.
            makePart(height)
        end
    end

    Water = (vape.Categories.Visuals or vape.Categories.Render):CreateModule({
        Name = 'Water',
        Function = function(callback)
            if callback then
                repeat task.wait() until (store.matchState ~= 0 and store.map) or not Water.Enabled
                if not Water.Enabled then return end
                Water:Clean(function()
                    clearTerrain()
                    restoreWaterLook()
                    removePart()
                    removeFX()
                end)
                Water:Clean(task.spawn(function()
                    while Water.Enabled do
                        refresh()
                        task.wait(0.5)
                    end
                end))
                -- Realistic mode's look and buoyancy have to react the instant you break the surface,
                -- so they run every frame rather than on the half-second refresh. Idle for the other
                -- modes, and it reverts itself the frame you surface or switch mode away.
				local nextRealisticUpdate = 0
				Water:Clean(runService.Heartbeat:Connect(function()
					if not Water.Enabled or Mode.Value ~= 'Realistic' then
						surfaced()
						return
					end
					if tick() < nextRealisticUpdate then return end
					nextRealisticUpdate = tick() + 0.1
                    local height = barrierHeight()
                    if not height then return end
                    updateRealistic(height + math.max(Depth.Value, 4) / 2)
                end))
            else
                clearTerrain()
                restoreWaterLook()
                removePart()
                removeFX()
            end
        end,
        Tooltip = 'Fills the void with Roblox water at AntiFall\'s barrier height',
        ExtraText = function()
            return Mode.Value
        end
    })
    Mode = Water:CreateDropdown({
        Name = 'Mode',
        List = {'Terrain', 'Part', 'Realistic'},
        Default = 'Terrain',
        Tooltip = 'Terrain - real Roblox water\nPart - one cheap plane across the map\nRealistic - reflective water with underwater effects',
        Function = function()
            if Water.Enabled then
                clearTerrain()
                restoreWaterLook()
                removePart()
                removeFX()
                task.spawn(refresh)
            end
        end
    })
    Size = Water:CreateSlider({
        Name = 'Area',
        Min = 128,
        Max = 2048,
        Default = 768,
        Suffix = ' studs',
        Tooltip = 'How wide a patch of water to keep filled around you, in Terrain mode'
    })
    Depth = Water:CreateSlider({
        Name = 'Depth',
        Min = 4,
        Max = 60,
        Default = 12,
        Suffix = ' studs',
        Tooltip = 'How deep the water goes below the surface'
    })
    Waves = Water:CreateToggle({
        Name = 'Waves',
        Default = true,
        Tooltip = 'Animate the surface. Off gives you a still, flat sheet',
        Function = function()
            if Water.Enabled and Mode.Value == 'Terrain' then
                applyWaterLook()
            end
        end
    })
    Color = Water:CreateColorSlider({
        Name = 'Color',
        DefaultOpacity = 0.7,
        Function = function()
            if not Water.Enabled then return end
            if Mode.Value == 'Terrain' then
                applyWaterLook()
            elseif part then
                part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                part.Transparency = math.clamp(1 - Color.Opacity, 0, 1)
            end
        end
    })
end)

--[[AETHER_MODULE:render/ChatPosition.lua]]

--[[AETHER_MODULE:blatant/BoostAirJump.lua]]

--[[AETHER_MODULE:exploits/BalloonDisabler.lua]]

-- KrystalDisabler lives further down, in the Kits window beside the rest of the kit modules.

-- (InfiniteSigrid removed. Re-asserting the ElkKitMounted remote to sustain the ride locked the
-- player server-side - you moved locally but stayed pinned for everyone else and could be hit.
-- A correct version needs the elk kit controller's real dismount/duration internals, which we
-- can't see from the repo, so the module is pulled rather than shipped broken and harmful.)

-- AutoBuildUp: towers you straight up. While you hold jump it fills the block-cell directly
-- beneath your feet - every cell as you rise, driven by position rather than a timer/apex - so
-- you build a gapless pillar and keep climbing as fast as you go up. Placement mirrors the
-- NoFall block clutch.
--[[AETHER_MODULE:blatant/AutoBuildUp.lua]]

--[[AETHER_MODULE:exploits/MultiAction.lua]]


-- RecoveryTP teleports at critical health after a confirmed landing.
--[[AETHER_MODULE:blatant/RecoveryTP.lua]]

-- BedWars' placement check queries character geometry before it sends the placement
-- remote. Suppress those queries only for the synchronous placement request; keeping
-- CanQuery false after it returns also hides an avatar from arrow/projectile raycasts.
--[[AETHER_MODULE:world/IgnorePlaceHitboxes.lua]]

--[[AETHER_MODULE:blatant/ProjectileDodger.lua]]

--[[AETHER_MODULE:blatant/TPAura.lua]]

-- cv's projectile charge routine, adapted to Aether's shared launch-hook registry.  The
-- registry composes with projectile modules already installed by Aether and restores the
-- original controller when the last hook is removed, avoiding the replacement/restore race the
-- reference implementation had when more than one module patched this method.
--[[AETHER_MODULE:blatant/AutoChargeProj.lua]]

--[[AETHER_MODULE:blatant/CannonSpeed.lua]]

--[[AETHER_MODULE:blatant/DamageBoost.lua]]

--[[AETHER_MODULE:blatant/FastBreak.lua]]

--[[AETHER_MODULE:world/FastPlace.lua]]

-- Consumes the supplied Grim Reaper soul and applies a configurable horizontal speed only while
-- the character is in the controller's soul-collecting channel. Leaving the form immediately
-- hands velocity control back to the game.
--[[AETHER_MODULE:kits/ReaperBypass.lua]]

--[[AETHER_MODULE:blatant/Fly.lua]]

--[[AETHER_MODULE:blatant/HitBoxes.lua]]


--[[AETHER_MODULE:blatant/InstantKill.lua]]

--[[AETHER_MODULE:blatant/KeepSprint.lua]]

--[[AETHER_MODULE:blatant/Killaura.lua]]
-- JadeInstaKill V2 is registered by AetherMatchRuntime above.

--[[AETHER_MODULE:blatant/LongJump.lua]]
--[[AETHER_MODULE:exploits/LongJumpBypass.lua]]

--[[
    Kit extenders

    Four modules, one per kit mobility ability: JadeExtender, VoidRegentExtender, CatExtender
    and YuziExtender. Each hooks the single controller method that performs its ability and
    pushes the character on with an extra impulse the moment that method fires.

    Hooking the controller (rather than watching velocity or ability cooldowns) is what makes
    this exact: the impulse lands on the frame the game itself performs the move, so it can
    never fire on knockback, an explosion or a hotbar change, and an ability the server
    refuses never produces one either.

    They share `createKitExtender` below because only four things actually differ between
    them - the controller, the method, the kit and the impulse - but each is registered as its
    own module with its own Multiplier, so one of them failing to register cannot take the
    other three out with it.
]]

-- `spec` is everything that differs between the four:
--   Name       - module name.
--   Kit        - store.equippedKit value the ability belongs to.
--   Controller - field on `bedwars` holding the controller to hook.
--   Method     - method on that controller which performs the move.
--   Argument   - index into the call's arguments holding the move direction, when it takes one.
--   Impulse    - (root, direction, multiplier) -> impulse to apply, or nil to apply none.
--   Tooltip    - module tooltip.
local function createKitExtender(spec)
    local Extender
    local Multiplier
    local controller, original, hooked

    -- Kit controllers are built when the match starts, so a module switched on in the lobby
    -- has nothing to hook yet: wait for it rather than give up, and stop the moment the module
    -- is switched off again.
    local function install()
        local target = bedwars[spec.Controller]
        while not target and Extender.Enabled do
            task.wait(0.1)
            target = bedwars[spec.Controller]
        end
        if not Extender.Enabled or not target then return end

        local method = target[spec.Method]
        if typeof(method) ~= 'function' then return end
        -- A second install racing the first (a fast off/on) would otherwise capture our own
        -- hook as `original`, and disabling would then restore the hook rather than the
        -- game's method.
        if hooked and method == hooked then return end

        controller, original = target, method
        hooked = function(...)
            -- Read out of the varargs here: the guarded block below is a closure, which
            -- cannot see `...` of the function it sits in.
			local direction = spec.Argument and select(spec.Argument, ...) or nil
			if spec.Argument and typeof(direction) ~= 'Vector3' then
				for index = 1, select('#', ...) do
					local candidate = select(index, ...)
					if typeof(candidate) == 'Vector3' then direction = candidate end
				end
			end
            local results = table.pack(method(...))

            if Extender.Enabled and entitylib.isAlive
				and (not spec.Argument or typeof(direction) == 'Vector3') then
				-- Controllers spend their cooldown before returning and several of them
				-- write velocity again at the end of the same frame. A deferred impulse
				-- therefore both proves the ability ran and cannot be overwritten by it.
				task.defer(function()
					pcall(function()
						if not Extender.Enabled or not entitylib.isAlive then return end
						local root = entitylib.character.RootPart
						local impulse = spec.Impulse(root, direction, Multiplier.Value)
						if impulse then root:ApplyImpulse(impulse) end
					end)
				end)
            end

            return table.unpack(results, 1, results.n)
        end

        controller[spec.Method] = hooked
    end

    Extender = kits:CreateModule({
        Name = spec.Name,
        Category = 'Ability',
        Function = function(callback)
            if callback then
                Extender:Clean(task.spawn(install))
            else
                -- Only put the method back if it is still ours; something else may have
                -- re-hooked it since, and restoring over that would undo their hook.
                if controller and original and controller[spec.Method] == hooked then
                    controller[spec.Method] = original
                end
                controller, original, hooked = nil, nil, nil
            end
        end,
        Tooltip = spec.Tooltip
    })

    Multiplier = Extender:CreateSlider({
        Name = 'Multiplier',
        Min = 1,
        Max = 5,
        Default = 2,
        Decimal = 10,
        Suffix = 'x',
        Tooltip = 'How much further than normal the ability carries you. 1x is the game\'s own distance'
    })

    return Extender
end

run(function()
    createKitExtender({
        Name = 'CatExtender',
        Kit = 'cat',
        Controller = 'CatController',
        Method = 'leap',
        -- leap(self, character, direction): the direction is the third argument.
        Argument = 3,
        Impulse = function(root, direction, multiplier)
            local flat = direction * Vector3.new(1, 0, 1)
            if flat.Magnitude <= 0 then return nil end
            return flat.Unit * root.AssemblyMass * (multiplier - 1) * 70
        end,
        Tooltip = 'Extends how far the Cat/Yamini pounce launches you'
    })
end)

--[[AETHER_MODULE:blatant/NoSlowdown.lua]]

--[[AETHER_MODULE:kits/OwlAura.lua]]

--[[AETHER_MODULE:blatant/PlayerAttach.lua]]

--[[AETHER_MODULE:blatant/ProjectileAimbot.lua]]

--[[AETHER_MODULE:combat/SilentAim.lua]]

--[[AETHER_MODULE:blatant/ProjectileAura.lua]]

--[[AETHER_MODULE:blatant/Speed.lua]]

--[[AETHER_MODULE:blatant/Spider.lua]]

--[[AETHER_MODULE:kits/TerraAimbot.lua]]

--[[
    Render
]]

--[[AETHER_MODULE:render/ArmorHighlight.lua]]

--[[AETHER_MODULE:render/BedESP.lua]]

--[[AETHER_MODULE:render/BeehiveESP.lua]]
--[[AETHER_MODULE:render/CustomTags.lua]]
--[[AETHER_MODULE:render/GeneratorESP.lua]]
--[[AETHER_MODULE:render/Health.lua]]
--[[AETHER_MODULE:render/ItemESP.lua]]
--[[AETHER_MODULE:kits/KitDisplay.lua]]
--[[AETHER_MODULE:kits/KitESP.lua]]
--[[AETHER_MODULE:render/NameTags.lua]]
--[[AETHER_MODULE:render/ProjectileLanding.lua]]
--[[AETHER_MODULE:render/ProjectileTracers.lua]]
--[[AETHER_MODULE:render/SkinChanger.lua]]
--[[AETHER_MODULE:render/StorageESP.lua]]
--[[AETHER_MODULE:utility/ClaimRewards.lua]]
--[[AETHER_MODULE:inventory/AutoEnchant.lua]]
--[[AETHER_MODULE:render/StreamRemover.lua]]
--[[AETHER_MODULE:render/TrapESP.lua]]
--[[AETHER_MODULE:render/ViewmodelVisuals.lua]]
--[[AETHER_MODULE:utility/MP3Player.lua]]

--[[AETHER_MODULE:utility/AntiSuffocate.lua]]

--[[AETHER_MODULE:utility/AutoBalloon.lua]]

--[[AETHER_MODULE:utility/AntiLasso.lua]]

--[[AETHER_MODULE:utility/AutoPearl.lua]]

--[[AETHER_MODULE:kits/TritonClutch.lua]]



--[[AETHER_MODULE:utility/AutoPlay.lua]]

--[[AETHER_MODULE:utility/LeaveParty.lua]]

--[[AETHER_MODULE:utility/AutoRelease.lua]]

--[[AETHER_MODULE:utility/AutoShoot.lua]]
--[[AETHER_MODULE:utility/AutoToxic.lua]]

--[[AETHER_MODULE:utility/AutoVoidDrop.lua]]

--[[AETHER_MODULE:utility/BackTrack.lua]]

--[[AETHER_MODULE:utility/CheatDetector.lua]]

--[[AETHER_MODULE:utility/FakeLag.lua]]

--[[AETHER_MODULE:utility/KnockbackDelay.lua]]

--[[AETHER_MODULE:kits/MissileTP.lua]]

--[[AETHER_MODULE:utility/PickupRange.lua]]

--[[AETHER_MODULE:utility/Scaffold.lua]]

--[[AETHER_MODULE:utility/StaffDetector.lua]]

--[[AETHER_MODULE:utility/TrapDisabler.lua]]

local AetherRuntimeContext = {
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

--[[AETHER_MODULE:kits/TrixieExploit.lua]]
local function registerAetherRuntimeBase(context)
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
Runtime.MatchDirector = MatchDirector
Runtime.Safe = safe
Runtime.Now = now
Runtime.RootOfLocal = rootOfLocal
Runtime.ModuleByName = moduleByName
Runtime.CopyTable = copyTable
Runtime.Context = ctx
shared.AetherBedWarsRuntime = Runtime
return Runtime
end
local runtimeLoaded, runtimeResult = xpcall(function()
    return registerAetherRuntimeBase(AetherRuntimeContext)
end, debug and debug.traceback or tostring)
if not runtimeLoaded or type(runtimeResult) ~= 'table' then
    error('[AetherV2] AutoWin/Jade runtime failed: '..tostring(runtimeResult))
end
AetherMatchRuntime = runtimeResult

--[[AETHER_MODULE:world/AutoWin.lua]]
--[[AETHER_MODULE:exploits/JadeInstaKill.lua]]
do
local Runtime = AetherMatchRuntime
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


end

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



local AetherPortContext = {Version = 2, Runtime = AetherMatchRuntime, Context = AetherRuntimeContext, Modules = {}, Diagnostics = {}}
AetherMatchRuntime.AlSploitPorts = AetherPortContext
AetherMatchRuntime.AlSploitPortsV2 = AetherPortContext

local function aetherPortSafe(label, fn, ...)
    if type(fn) ~= 'function' then return false, 'missing function' end
    local ok, result = pcall(fn, ...)
    if not ok then
        AetherPortContext.Diagnostics[label] = {At = tick(), Error = tostring(result)}
        return false, result
    end
    return true, result
end
local function aetherPortNotify(text, duration, kind)
    aetherPortSafe('notify', notif, 'AetherV2', text, duration or 3, kind)
end
local function aetherPortRoot()
    local char = entitylib.character
    if entitylib.isAlive and char and char.RootPart and char.RootPart.Parent then return char.RootPart, char, char.Humanoid end
    local character = lplr.Character
    local root = character and (character.PrimaryPart or character:FindFirstChild('HumanoidRootPart'))
    local humanoid = character and character:FindFirstChildOfClass('Humanoid')
    if root and humanoid and humanoid.Health > 0 then return root, character, humanoid end
end
local function aetherPortMatchRunning()
    local match = AetherMatchRuntime.BedWarsAPI and AetherMatchRuntime.BedWarsAPI.Match
    if not match then return store.matchState ~= 0 end
    return match:GetState() == match.States.RUNNING
end
local function aetherPortEquippedKit()
    local api = AetherMatchRuntime.BedWarsAPI and AetherMatchRuntime.BedWarsAPI.Kits
    if api then return select(1, api:GetEquipped()) end
    return store.equippedKit or lplr:GetAttribute('PlayingAsKit')
end
local function aetherPortHorizontalUnit(vector)
    if not vector then return nil end
    local flat = Vector3.new(vector.X, 0, vector.Z)
    return flat.Magnitude > 0.01 and flat.Unit or nil
end
local function aetherPortModule(name) return vape.Modules and vape.Modules[name] or nil end
local function aetherPortRegister(categoryName, name, definition)
    local existing = aetherPortModule(name)
    if existing then AetherPortContext.Modules[name] = existing; return existing, false end
    local category = vape.Categories and vape.Categories[categoryName]
    assert(category and type(category.CreateModule) == 'function', 'missing Aether category '..categoryName)
    definition.Name = name
    local module = category:CreateModule(definition)
    AetherPortContext.Modules[name] = module
    return module, true
end
local function aetherPortAbilityController()
    return bedwars.AbilityController or (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.AbilityController)
end
local function aetherPortCanUseAbility(name)
    local controller = aetherPortAbilityController()
    if not controller then return false end
    if type(controller.canUseAbility) == 'function' then
        local ok, result = pcall(controller.canUseAbility, controller, name, {disableBlockedAbilityAlert = true})
        if ok then return result ~= false end
    end
    return true
end
local function aetherPortUseAbility(name)
    local controller = aetherPortAbilityController()
    if not controller or type(controller.useAbility) ~= 'function' then return false, 'missing AbilityController' end
    local ok, result = pcall(controller.useAbility, controller, name)
    return ok and result ~= false, result
end
local function aetherPortNearestTarget(range, includeNPCs)
    local root = aetherPortRoot(); if not root then return nil end
    local ok, target = pcall(entitylib.EntityPosition, {Origin = root.Position, Range = range, Part = 'RootPart', Players = true, NPCs = includeNPCs and true or false})
    return ok and target or nil
end
local function aetherPortWait(seconds, cancelled, step)
    local deadline = tick() + seconds
    repeat if cancelled and cancelled() then return false end; task.wait(step or 0.03) until tick() >= deadline
    return true
end
local function aetherPortAddMovementOwner(name)
    local movement = AetherMatchRuntime.Movement
    if movement and movement.ExternalNames and not table.find(movement.ExternalNames, name) then table.insert(movement.ExternalNames, name) end
end
local function aetherPortCreateDecoy(followHorizontal)
    local root, character, humanoid = aetherPortRoot(); if not root or not character or not humanoid then return nil end
    local oldArchivable = character.Archivable; character.Archivable = true
    local ok, clone = pcall(character.Clone, character); character.Archivable = oldArchivable
    if not ok or not clone then return nil end
    for _, object in clone:GetDescendants() do
        if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy()
        elseif object:IsA('BasePart') then object.CanCollide = false; if object.Name == 'Cape' then object:Destroy() end end
    end
    clone.Name = 'AetherMovementDecoy'; clone.Parent = workspace
    local cloneRoot = clone.PrimaryPart or clone:FindFirstChild('HumanoidRootPart')
    local cloneHumanoid = clone:FindFirstChildOfClass('Humanoid')
    if not cloneRoot or not cloneHumanoid then clone:Destroy(); return nil end
    clone.PrimaryPart = cloneRoot; cloneRoot.Anchored = true; clone:PivotTo(character:GetPivot())
    local originalSubject = gameCamera.CameraSubject; gameCamera.CameraSubject = cloneHumanoid
    local decoy = {Model = clone, Root = cloneRoot, Humanoid = cloneHumanoid, OriginalSubject = originalSubject}
    if followHorizontal then
        decoy.Connection = runService.RenderStepped:Connect(function()
            local liveRoot = aetherPortRoot()
            if clone.Parent and liveRoot then cloneRoot.CFrame = CFrame.new(liveRoot.Position.X, cloneRoot.Position.Y, liveRoot.Position.Z) * liveRoot.CFrame.Rotation end
        end)
    end
    function decoy:Destroy()
        if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
        if gameCamera.CameraSubject == self.Humanoid then local _, _, liveHumanoid = aetherPortRoot(); gameCamera.CameraSubject = (self.OriginalSubject and self.OriginalSubject.Parent and self.OriginalSubject) or liveHumanoid end
        if self.Model and self.Model.Parent then self.Model:Destroy() end
    end
    return decoy
end

--[[AETHER_MODULE:exploits/YaminiExploit.lua]]
--[[AETHER_MODULE:exploits/JadeExploit.lua]]
--[[AETHER_MODULE:blatant/AntiHitBETA.lua]]
--[[AETHER_MODULE:exploits/BalloonDisabler.lua]]
--[[AETHER_MODULE:exploits/MultiAction.lua]]
--[[AETHER_MODULE:kits/InfiniteSigrid.lua]]
--[[AETHER_MODULE:exploits/JadeHammerExploit.lua]]
AetherMatchRuntime.JadeHammerExploit = vape.Modules and vape.Modules.JadeHammerExploit or nil



--[[AETHER_MODULE:utility/EntityAnalyser.lua]]

--[[
    World
]]

--[[AETHER_MODULE:world/Anti-AFK.lua]]

--[[AETHER_MODULE:world/AutoSuffocate.lua]]

--[[AETHER_MODULE:world/AutoTool.lua]]

--[[AETHER_MODULE:world/BedAssist.lua]]

--[[AETHER_MODULE:world/BedProtector.lua]]
--[[AETHER_MODULE:world/BlockIn.lua]]

--[[AETHER_MODULE:world/Schematica.lua]]

--[[
    Inventory
]]

--[[AETHER_MODULE:inventory/ArmorSwitch.lua]]

--[[
    AutoBank

    Two ways of putting resources somewhere safe, picked with Mode.

    Skybox is the reference build's design and does not use a chest at all. Whitelisted
    resources are DROPPED, and every drop we made is then held far out of the world where
    nobody can reach it - the item entity is ours to move, so parking it at the top of the
    skybox is a safe deposit box that no server-side range check applies to. Walk up to a shop
    (or die) and the whole stash is pulled back to your head and picked up.

    Chest is the legit one: it does exactly what banking by hand does. Nothing is dropped and
    nothing is held anywhere it should not be - stand within range of your personal chest and
    the whitelisted resources go into it through the same remote the chest UI uses, so from
    the server's point of view this is a player at their chest putting things away. It can
    take the lot back out again when you are at a shop and about to spend it.

    A count of everything currently banked can be shown above the hotbar, in either mode.
]]
--[[AETHER_MODULE:inventory/AutoBank.lua]]

--[[AETHER_MODULE:inventory/AutoBuy.lua]]
--[[AETHER_MODULE:inventory/OpenShop.lua]]

--[[AETHER_MODULE:inventory/AutoConsume.lua]]

--[[AETHER_MODULE:inventory/AutoFish.lua]]

--[[AETHER_MODULE:inventory/AutoHotbar.lua]]

--[[AETHER_MODULE:inventory/AutoSteal.lua]]

--[[AETHER_MODULE:inventory/FastConsume.lua]]

--[[AETHER_MODULE:inventory/FastDrop.lua]]

--[[
    Minigames
]]

--[[AETHER_MODULE:utility/AutoHonor.lua]]

--[[AETHER_MODULE:render/BedPlates.lua]]

--[[AETHER_MODULE:world/Breaker.lua]]

--[[
    Legit
]]

--[[AETHER_MODULE:render/ArmorTrims.lua]]

--[[AETHER_MODULE:legit/BedAlarm.lua]]

--[[AETHER_MODULE:legit/BedBreakEffect.lua]]

--[[AETHER_MODULE:legit/BlockSelectorColor.lua]]

--[[AETHER_MODULE:legit/CleanKit.lua]]

--[[AETHER_MODULE:legit/Crosshair.lua]]

--[[AETHER_MODULE:legit/DamageIndicator.lua]]

-- DeviceSpoofer, replaced with the reference build's version. Aether's only ever wrote a
-- local attribute back onto the player, which the server never reads. This hooks the input
-- controller the game asks for the device type and tells the server directly, which is what
-- actually changes what other clients see you as.
--[[AETHER_MODULE:legit/DeviceSpoofer.lua]]

--[[AETHER_MODULE:legit/FOV.lua]]

--[[AETHER_MODULE:legit/FPSBoost.lua]]

--[[AETHER_MODULE:legit/HitColor.lua]]

--[[AETHER_MODULE:legit/HitFix.lua]]

--[[AETHER_MODULE:legit/Interface.lua]]

--[[AETHER_MODULE:legit/KillEffect.lua]]

--[[AETHER_MODULE:legit/PotionStatus.lua]]

--[[AETHER_MODULE:legit/ReachDisplay.lua]]

--[[AETHER_MODULE:legit/SongBeats.lua]]

--[[AETHER_MODULE:legit/SoundChanger.lua]]

--[[AETHER_MODULE:legit/KillfeedSpoofer.lua]]

--[[AETHER_MODULE:legit/TexturePack.lua]]

--[[AETHER_MODULE:legit/UICleanup.lua]]

--[[AETHER_MODULE:legit/Viewmodel.lua]]

--[[AETHER_MODULE:legit/WinEffect.lua]]


-- Unique BedWars match modules ported from skid.lua.

--[[AETHER_MODULE:render/LootESP.lua]]

--[[AETHER_MODULE:world/NightmareEmote.lua]]

--[[AETHER_MODULE:world/AutoCounter.lua]]


--[[AETHER_MODULE:legit/TransparentCharacter.lua]]

--[[AETHER_MODULE:utility/Headless.lua]]

--[[AETHER_MODULE:utility/Legless.lua]]

--[[AETHER_MODULE:world/ShadowRemover.lua]]

--[[AETHER_MODULE:legit/WhiteHits.lua]]

--[[AETHER_MODULE:world/RemoveNeon.lua]]

--[[AETHER_MODULE:world/PotatoMode.lua]]

--[[AETHER_MODULE:legit/MotionBlur.lua]]

--[[AETHER_MODULE:kits/GrimReaperFix.lua]]

--[[AETHER_MODULE:utility/CustomCursor.lua]]


--[[AETHER_MODULE:render/NameTagSpoofer.lua]]

--[[AETHER_MODULE:render/Aura.lua]]


--[[AETHER_MODULE:render/ChatNameColor.lua]]

--[[AETHER_MODULE:render/PlayerOutline.lua]]

--[[AETHER_MODULE:world/ACMODView.lua]]

--[[AETHER_MODULE:utility/InvisibleCursor.lua]]

--[[AETHER_MODULE:render/LegacyAnimation.lua]]

--[[AETHER_MODULE:render/RemovePlayerLevelUI.lua]]

--[[AETHER_MODULE:render/OG4v4v4v4.lua]]

--[[
	Kits
	----
	cv base implementations, registered through Aether's Kits GUI category.
]]

--[[AETHER_MODULE:kits/AutoAdetunde.lua]]

--[[AETHER_MODULE:kits/AutoBeekeeper.lua]]

--[[AETHER_MODULE:kits/AutoBountyHunter.lua]]

--[[AETHER_MODULE:kits/AutoBuilder.lua]]

--[[AETHER_MODULE:kits/AutoCaitlyn.lua]]

--[[AETHER_MODULE:kits/AutoCard.lua]]

--[[AETHER_MODULE:kits/AutoCrocowolf.lua]]

--[[AETHER_MODULE:kits/AutoCyber.lua]]

--[[AETHER_MODULE:kits/AutoDavey.lua]]

--[[AETHER_MODULE:kits/AutoDragonSword.lua]]

--[[AETHER_MODULE:kits/AutoDrill.lua]]

--[[AETHER_MODULE:kits/AutoElder.lua]]

--[[AETHER_MODULE:kits/AutoEldric.lua]]

--[[AETHER_MODULE:kits/AutoEmber.lua]]

--[[AETHER_MODULE:kits/AutoEquipKit.lua]]

--[[AETHER_MODULE:kits/AutoFarmer.lua]]

--[[AETHER_MODULE:kits/AutoFarmerCletus.lua]]

--[[AETHER_MODULE:kits/AutoFreiya.lua]]

--[[AETHER_MODULE:kits/AutoGingerbreadMan.lua]]

--[[AETHER_MODULE:kits/AutoGrim.lua]]

--[[AETHER_MODULE:kits/AutoGrove.lua]]

--[[AETHER_MODULE:kits/AutoHannah.lua]]

--[[AETHER_MODULE:kits/AutoHephaestus.lua]]

--[[AETHER_MODULE:kits/AutoKaida.lua]]

--[[AETHER_MODULE:kits/AutoKaliyah.lua]]

--[[AETHER_MODULE:kits/AutoKit.lua]]

--[[AETHER_MODULE:kits/AutoKrystal.lua]]

--[[AETHER_MODULE:kits/AutoLani.lua]]

--[[AETHER_MODULE:kits/AutoLasso.lua]]

--[[AETHER_MODULE:kits/AutoLumen.lua]]

--[[AETHER_MODULE:kits/AutoMarina.lua]]

--[[AETHER_MODULE:kits/AutoMartin.lua]]

--[[AETHER_MODULE:kits/AutoMelody.lua]]

--[[AETHER_MODULE:kits/AutoMetal.lua]]

--[[AETHER_MODULE:kits/AutoMushroom.lua]]

--[[AETHER_MODULE:kits/AutoNahila.lua]]

--[[AETHER_MODULE:kits/AutoNazar.lua]]

--[[AETHER_MODULE:kits/AutoNoelle.lua]]

--[[AETHER_MODULE:kits/AutoNyx.lua]]

--[[AETHER_MODULE:kits/AutoPyro.lua]]

--[[AETHER_MODULE:kits/AutoRagnar.lua]]

--[[AETHER_MODULE:kits/AutoRamil.lua]]

--[[AETHER_MODULE:kits/AutoSheepHerder.lua]]

--[[AETHER_MODULE:kits/AutoShielderUlt.lua]]

--[[AETHER_MODULE:kits/AutoSilas.lua]]

--[[AETHER_MODULE:kits/AutoSmoke.lua]]

--[[AETHER_MODULE:kits/AutoSophia.lua]]

--[[AETHER_MODULE:kits/AutoStarCollector.lua]]

--[[AETHER_MODULE:kits/AutoTaliyah.lua]]

--[[AETHER_MODULE:kits/AutoTriton.lua]]

--[[AETHER_MODULE:kits/AutoUma.lua]]

--[[AETHER_MODULE:kits/AutoVanessa.lua]]

--[[AETHER_MODULE:kits/AutoVoidHunter.lua]]

--[[AETHER_MODULE:kits/AutoVoidKnight.lua]]

--[[AETHER_MODULE:kits/AutoWarden.lua]]

--[[AETHER_MODULE:kits/AutoWhim.lua]]

--[[AETHER_MODULE:kits/AutoWhisper.lua]]

--[[AETHER_MODULE:kits/AutoXurot.lua]]

--[[AETHER_MODULE:kits/AutoYeti.lua]]

--[[AETHER_MODULE:kits/AutoZeno.lua]]

--[[AETHER_MODULE:kits/AutoZola.lua]]

--[[AETHER_MODULE:kits/CryptAura.lua]]

--[[AETHER_MODULE:kits/DaveyAim.lua]]

--[[AETHER_MODULE:kits/EquipKit.lua]]

--[[AETHER_MODULE:kits/FalconAura.lua]]

--[[AETHER_MODULE:kits/FishermanSpy.lua]]

--[[AETHER_MODULE:kits/JadeExtender.lua]]

--[[AETHER_MODULE:kits/AutoPickpocket.lua]]

--[[AETHER_MODULE:kits/RavenTP.lua]]

--[[AETHER_MODULE:kits/VoidRegentAutoClutch.lua]]

--[[AETHER_MODULE:kits/VoidRegentExtender.lua]]

--[[AETHER_MODULE:kits/VulcanAssist.lua]]

--[[AETHER_MODULE:kits/YaminiExtender.lua]]

--[[AETHER_MODULE:kits/YuziExtender.lua]]

-- Aether-only: cv has no Agni implementation, so retain the existing targeted
-- rocket boost and void-clutch behavior as its own Kits module.
--[[AETHER_MODULE:kits/AutoAgni.lua]]

-- AutoKit covers normal spirit collection, while this Aether-only mode keeps
-- its conditional Evelynn recall workflow (fall/swing gates and facing).
--[[AETHER_MODULE:kits/AutoEvelynn.lua]]


-- KrystalDisabler (restored; InfiniteKrystal was folded into it). Krystal - the GlacialSkater
-- kit - skates on momentum: the controller decays it every step and reports the value to the
-- server, and the server correcting a client that disagrees is what reads as a lagback. So we
-- hook the controller's own updateMomentum and keep momentum pinned, re-assert it every
-- PreSimulation step, and suppress the local CFrame/Velocity correction listeners so the skate
-- never snaps back. Fails gracefully (notif + untoggle) if this build has no Krystal controller.
--
-- The hook wraps the original rather than replacing it: updateMomentum also drives the skate
-- itself, so a hook that swallows the call pins a momentum value you never actually move with.
-- We set momentum on both sides of the call instead, which is what stops the original walking
-- it back down. Kept from InfiniteKrystal: the Kits window home beside AutoKrystal, the
-- Enabled check inside the hook, the identity check before restoring, and a momentum figure
-- that is a number the server can plausibly see rather than 9e9.
--[[AETHER_MODULE:kits/KrystalDisabler.lua]]

--[[AETHER_MODULE:render/NoBob.lua]]
