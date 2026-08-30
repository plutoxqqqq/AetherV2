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

--[[AETHER_MODULE:kits/Multiplier.lua]]

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

--[[AETHER_MODULE:mixed/AutoWin__group3.lua]]


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
