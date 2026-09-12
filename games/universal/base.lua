local vape = shared.vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('AetherV2', 'Failed to load : ' .. err, 30, 'alert')
	end
	return res
end
local isfile = isfile
	or function(file)
		local suc, res = pcall(function()
			return readfile(file)
		end)
		return suc and res ~= nil and res ~= ''
	end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			if type(shared.AetherV2FetchSource) == 'function' then
				return shared.AetherV2FetchSource(path)
			end
			return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/' .. readfile('aetherv2/profiles/commit.txt') .. '/' .. select(1, path:gsub('aetherv2/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:sub(-4) == '.lua' then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'.. res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
-- Each module registers through run(). A bare `func()` meant one bad module aborted the whole
-- chunk part-way through, so a single error (a nil HUD frame, a missing remote) silently cost you
-- every module below it in the file. Isolate them: report the one that failed and keep loading.
local run = function(func)
	local success, result = xpcall(func, debug and debug.traceback or tostring)
	if not success then
		warn('[AetherV2] Skipped a universal module during startup: '..tostring(result))
	end
	return success
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local pathfindingService = cloneref(game:GetService('PathfindingService'))
local inputService = cloneref(game:GetService('UserInputService'))
local textService = cloneref(game:GetService('TextService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local proximityPromptService = cloneref(game:GetService('ProximityPromptService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = game:GetService('CoreGui')

local isnetworkowner = isnetworkowner or function() return true end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = { Enabled = false }
local Phase = { Enabled = false }

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

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
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

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function rakNetCheck(module)
	if not (raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
		notif(module, 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		return false
	end

	return true
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('AetherV2', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick()
				and game:HttpGet(
					'https://games.roblox.com/v1/games/'
						.. game.PlaceId
						.. '/servers/Public?sortOrder='
						.. (filter == 'Ascending' and 1 or 2)
						.. '&excludeFullGames=true&limit=100'
						.. (pointer and '&cursor=' .. pointer or '')
				)
			or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if
				tonumber(v.playing) < playersService.MaxPlayers
				and not table.find(visited, v.id)
				and not table.find(attempted, v.id)
			then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('AetherV2', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('AetherV2', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif(
			'AetherV2',
			'Failed to grab servers. (' .. (data and data.errors[1].message or 'no data') .. ')',
			5,
			'warning'
		)
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport(
			"shared.vapeserverhoplist = '"
				.. table.concat(visited, '/')
				.. "'\nshared.vapeserverhopprevious = '"
				.. game.JobId
				.. "'"
		)
	end
end))

vape.Libraries.string = loadstring(downloadFile('aetherv2/libraries/string.lua'), 'string')()
local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('aetherv2/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('aetherv2/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('aetherv2/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	customtags = {},
	data = {WhitelistedUsers = {}},
	loaded = true,
	localprio = 0,
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{
			CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)),
			Time = 0.1,
		},
		{
			CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)),
			Time = 0.08,
		},
		{
			CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)),
			Time = 0.03,
		},
		{
			CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)),
			Time = 0.03,
		},
	},
	Random = {},
	['Horizontal Spin'] = {
		{ CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12 },
		{ CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12 },
		{ CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12 },
		{ CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12 },
	},
	['Vertical Spin'] = {
		{ CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12 },
		{ CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12 },
		{ CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12 },
		{ CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12 },
	},
	Exhibition = {
		{
			CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)),
			Time = 0.1,
		},
		{
			CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)),
			Time = 0.2,
		},
	},
	['Exhibition Old'] = {
		{
			CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)),
			Time = 0.15,
		},
		{
			CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)),
			Time = 0.05,
		},
		{
			CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)),
			Time = 0.1,
		},
		{
			CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)),
			Time = 0.05,
		},
		{
			CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)),
			Time = 0.15,
		},
	},
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = { lplr.Character, gameCamera }
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				-- Take the movement into the wall out of the step and keep the rest, so pressing
				-- into a surface slides along it. The old line replaced the step with "go to one
				-- stud off the hit point", which is inside the character's own collision hull -
				-- so every frame shoved the body back into the wall and held it there. Pressed
				-- against a surface like that, wall friction takes over from gravity, which is
				-- the slow slide down instead of a fall.
				local into = dest:Dot(ray.Normal)
				if into < 0 then
					dest -= ray.Normal * into
				end
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then
			options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed
		end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
}
for name in SpeedMethods do
	if not table.find(SpeedMethodList, name) then
		table.insert(SpeedMethodList, name)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end,}
				end,
			},
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then
			return true
		end
		if isFriend(ent.Player) then
			return false
		end
		if not select(2, whitelist:get(ent.Player)) then
			return false
		end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then
				return true
			end
			if not ent.Player.Team then
				return true
			end
			if ent.Player.Team ~= lplr.Team then
				return true
			end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then
			return
		end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function()
		entitylib.refresh()
	end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function()
		entitylib.refresh()
	end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get()
		return 0, true
	end

	function whitelist:isingame()
		return false
	end

	function whitelist:tag()
		return ''
	end

	function whitelist:getplayer()
		return nil
	end

	function whitelist:playeradded() end
	function whitelist:process() end
	function whitelist:newchat() end
	function whitelist:oldchat() end
	function whitelist:hook() end
	function whitelist:announce() end
	function whitelist:update()
		return false
	end

	vape:Clean(function()
		table.clear(whitelist.data)
		table.clear(whitelist.customtags)
		table.clear(whitelist)
	end)
end)
entitylib.start()

local mouseClicked

local Fly
local LongJump

getgenv().used_init = true


--[[
    Combat
]]
