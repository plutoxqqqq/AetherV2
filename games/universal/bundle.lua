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

run(function()
	local Radar
	local Targets
	local DotStyle
	local PlayerColor
	local Clamp
	local Reference = {}
	local bkg

	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then
			return
		end
		if not Targets.NPCs.Enabled and ent.NPC then
			return
		end
		if (not ent.Targetable) and not ent.Friend then
			return
		end
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		local dot = Instance.new('Frame')
		dot.Size = UDim2.fromOffset(4, 4)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = entitylib.getEntityColor(ent)
			or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
		dot.Parent = bkg
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(DotStyle.Value == 'Circles' and 1 or 0, 0)
		corner.Parent = dot
		local stroke = Instance.new('UIStroke')
		stroke.Color = Color3.new()
		stroke.Thickness = 1
		stroke.Transparency = 0.8
		stroke.Parent = dot
		Reference[ent] = dot
	end

	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			v:Destroy()
		end
	end

	Radar = vape:CreateOverlay({
		Name = 'Radar',
		Icon = getcustomasset('aetherv2/assets/new/radaricon.png'),
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(12, 13),
		Function = function(callback)
			if callback then
				Radar:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
				Radar:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Radar:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for ent, dot in Reference do
						dot.BackgroundColor3 = entitylib.getEntityColor(ent)
							or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
					end
				end))
				Radar:Clean(runService.RenderStepped:Connect(function()
					for ent, dot in Reference do
						if entitylib.isAlive then
							local dt = CFrame.lookAlong(
								entitylib.character.RootPart.Position,
								gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
							):PointToObjectSpace(ent.RootPart.Position)
							dot.Position = UDim2.fromOffset(
								Clamp.Enabled and math.clamp(108 + dt.X, 2, 214) or 108 + dt.X,
								Clamp.Enabled and math.clamp(108 + dt.Z, 8, 214) or 108 + dt.Z
							)
						end
					end
				end))
			else
				for ent in Reference do
					Removed(ent)
				end
			end
		end,
	})
	Targets = Radar:CreateTargets({
		Players = true,
		Function = function()
			if Radar.Button.Enabled then
				Radar.Button:Toggle()
				Radar.Button:Toggle()
			end
		end,
	})
	DotStyle = Radar:CreateDropdown({
		Name = 'Dot Style',
		List = { 'Circles', 'Squares' },
		Function = function(val)
			for _, dot in Reference do
				dot.UICorner.CornerRadius = UDim.new(val == 'Circles' and 1 or 0, 0)
			end
		end,
	})
	PlayerColor = Radar:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			for ent, dot in Reference do
				dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(hue, sat, val)
			end
		end,
	})
	bkg = Instance.new('Frame')
	bkg.Size = UDim2.fromOffset(216, 216)
	bkg.Position = UDim2.fromOffset(2, 2)
	bkg.BackgroundColor3 = Color3.new()
	bkg.BackgroundTransparency = 0.5
	bkg.ClipsDescendants = true
	bkg.Parent = Radar.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bkg
	local stroke = Instance.new('UIStroke')
	stroke.Thickness = 2
	stroke.Color = Color3.new()
	stroke.Transparency = 0.4
	stroke.Parent = bkg
	local line1 = Instance.new('Frame')
	line1.Size = UDim2.new(0, 2, 1, 0)
	line1.Position = UDim2.fromScale(0.5, 0.5)
	line1.AnchorPoint = Vector2.new(0.5, 0.5)
	line1.ZIndex = 0
	line1.BackgroundColor3 = Color3.new(1, 1, 1)
	line1.BackgroundTransparency = 0.5
	line1.BorderSizePixel = 0
	line1.Parent = bkg
	local line2 = line1:Clone()
	line2.Size = UDim2.new(1, 0, 0, 2)
	line2.Parent = bkg
	local bar = Instance.new('Frame')
	bar.Size = UDim2.new(1, -6, 0, 4)
	bar.Position = UDim2.fromOffset(3, 0)
	bar.BackgroundColor3 = Color3.fromHSV(0.44, 1, 1)
	bar.Parent = bkg
	local barcorner = Instance.new('UICorner')
	barcorner.CornerRadius = UDim.new(0, 8)
	barcorner.Parent = bar
	Radar:CreateColorSlider({
		Name = 'Bar Color',
		Function = function(hue, sat, val)
			bar.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		end,
	})
	Radar:CreateToggle({
		Name = 'Show Background',
		Default = true,
		Function = function(callback)
			bkg.BackgroundTransparency = callback and 0.5 or 1
			bar.BackgroundTransparency = callback and 0 or 1
			stroke.Transparency = callback and 0.4 or 1
		end,
	})
	Radar:CreateToggle({
		Name = 'Show Cross',
		Default = true,
		Function = function(callback)
			line1.BackgroundTransparency = callback and 0.5 or 1
			line2.BackgroundTransparency = callback and 0.5 or 1
		end,
	})
	Clamp = Radar:CreateToggle({
		Name = 'Clamp Radar',
		Default = true,
	})
end)


run(function()
	local SessionInfo
	local FontOption
	local Hide
	local TextSize
	local BorderColor
	local Title
	local TitleOffset = {}
	local Custom
	local CustomBox
	local infoholder
	local infolabel
	local infostroke

	SessionInfo = vape:CreateOverlay({
		Name = 'Session Info',
		Icon = getcustomasset('aetherv2/assets/new/textguiicon.png'),
		Size = UDim2.fromOffset(16, 12),
		Position = UDim2.fromOffset(12, 14),
		Function = function(callback)
			if callback then
				local teleportedServers
				SessionInfo:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
					if not teleportedServers then
						teleportedServers = true
						queue_on_teleport(
							"shared.vapesessioninfo = '"
								.. httpService:JSONEncode(vape.Libraries.sessioninfo.Objects)
								.. "'"
						)
					end
				end))

				if shared.vapesessioninfo then
					for i, v in httpService:JSONDecode(shared.vapesessioninfo) do
						if vape.Libraries.sessioninfo.Objects[i] and v.Saved then
							vape.Libraries.sessioninfo.Objects[i].Value = v.Value
						end
					end
				end

				repeat
					if vape.Libraries.sessioninfo then
						local stuff = { '' }
						if Title.Enabled then
							stuff[1] = TitleOffset.Enabled and '<b>Session Info</b>\n<font size="4"> </font>'
								or '<b>Session Info</b>'
						end

						for i, v in vape.Libraries.sessioninfo.Objects do
							stuff[v.Index] = not table.find(Hide.ListEnabled, i) and i .. ': ' .. v.Function(v.Value)
								or false
						end

						if #Hide.ListEnabled > 0 then
							local key, val
							repeat
								local oldkey = key
								key, val = next(stuff, key)
								if val == false then
									table.remove(stuff, key)
									key = oldkey
								end
							until not key
						end

						if Custom.Enabled then
							table.insert(stuff, CustomBox.Value)
						end

						if not Title.Enabled then
							table.remove(stuff, 1)
						end
						infolabel.Text = table.concat(stuff, '\n')
						infolabel.FontFace = FontOption.Value
						infolabel.TextSize = TextSize.Value
						local size = getfontsize(removeTags(infolabel.Text), infolabel.TextSize, infolabel.FontFace)
						infoholder.Size =
							UDim2.fromOffset(size.X + 16, size.Y + (Title.Enabled and TitleOffset.Enabled and 4 or 16))
					end
					task.wait(1)
				until not SessionInfo.Button or not SessionInfo.Button.Enabled
			end
		end,
	})
	FontOption = SessionInfo:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
	})
	Hide = SessionInfo:CreateTextList({
		Name = 'Blacklist',
		Tooltip = 'Name of entry to hide',
		Icon = getcustomasset('aetherv2/assets/new/blockedicon.png'),
		Tab = getcustomasset('aetherv2/assets/new/blockedtab.png'),
		TabSize = UDim2.fromOffset(21, 16),
		Color = Color3.fromRGB(250, 50, 56),
	})
	SessionInfo:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			infoholder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			infoholder.BackgroundTransparency = 1 - opacity
		end,
	})
	BorderColor = SessionInfo:CreateColorSlider({
		Name = 'Border Color',
		Function = function(hue, sat, val, opacity)
			infostroke.Color = Color3.fromHSV(hue, sat, val)
			infostroke.Transparency = 1 - opacity
		end,
		Darker = true,
		Visible = false,
	})
	TextSize = SessionInfo:CreateSlider({
		Name = 'Text Size',
		Min = 1,
		Max = 30,
		Default = 16,
	})
	Title = SessionInfo:CreateToggle({
		Name = 'Title',
		Function = function(callback)
			if TitleOffset.Object then
				TitleOffset.Object.Visible = callback
			end
		end,
		Default = true,
	})
	TitleOffset = SessionInfo:CreateToggle({
		Name = 'Offset',
		Default = true,
		Darker = true,
	})
	SessionInfo:CreateToggle({
		Name = 'Border',
		Function = function(callback)
			infostroke.Enabled = callback
			BorderColor.Object.Visible = callback
		end,
	})
	Custom = SessionInfo:CreateToggle({
		Name = 'Add custom text',
		Function = function(enabled)
			CustomBox.Object.Visible = enabled
		end,
	})
	CustomBox = SessionInfo:CreateTextBox({
		Name = 'Custom text',
		Darker = true,
		Visible = false,
	})
	infoholder = Instance.new('Frame')
	infoholder.BackgroundColor3 = Color3.new()
	infoholder.BackgroundTransparency = 0.5
	infoholder.Parent = SessionInfo.Children
	vape:Clean(SessionInfo.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local newside = SessionInfo.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
		infoholder.Position = UDim2.fromScale(newside and 1 or 0, 0)
		infoholder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
	end))
	local sessioninfocorner = Instance.new('UICorner')
	sessioninfocorner.CornerRadius = UDim.new(0, 5)
	sessioninfocorner.Parent = infoholder
	infolabel = Instance.new('TextLabel')
	infolabel.Size = UDim2.new(1, -16, 1, -16)
	infolabel.Position = UDim2.fromOffset(8, 8)
	infolabel.BackgroundTransparency = 1
	infolabel.TextXAlignment = Enum.TextXAlignment.Left
	infolabel.TextYAlignment = Enum.TextYAlignment.Top
	infolabel.TextSize = 16
	infolabel.TextColor3 = Color3.new(1, 1, 1)
	infolabel.TextStrokeColor3 = Color3.new()
	infolabel.TextStrokeTransparency = 0.8
	infolabel.Font = Enum.Font.Arial
	infolabel.RichText = true
	infolabel.Parent = infoholder
	infostroke = Instance.new('UIStroke')
	infostroke.Enabled = false
	infostroke.Color = Color3.fromHSV(0.44, 1, 1)
	infostroke.Parent = infoholder
	addBlur(infoholder)
	vape.Libraries.sessioninfo = {
		Objects = {},
		AddItem = function(self, name, startvalue, func, saved)
			func, saved = func or function(val)
				return val
			end, saved == nil or saved
			self.Objects[name] =
				{ Function = func, Saved = saved, Value = startvalue or 0, Index = getTableSize(self.Objects) + 2 }
			return {
				Increment = function(_, val)
					self.Objects[name].Value += (val or 1)
				end,
				Get = function()
					return self.Objects[name].Value
				end,
			}
		end,
	}
	vape.Libraries.sessioninfo:AddItem('Time Played', os.clock(), function(value)
		return os.date('!%X', math.floor(os.clock() - value))
	end)
end)

--[[
    Combat
]]

run(function()
    local AimAssist
    local Targets
    local Part
    local FOV
    local Speed
    local CircleColor
    local CircleTransparency
    local CircleFilled
    local CircleObject
    local RightClick
    local ShowTarget
    local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)

    local function wrapAngle(num)
	num = num % math.pi
	num -= num >= (math.pi / 2) and math.pi or 0
	num += num < -(math.pi / 2) and math.pi or 0
	return num
    end

    AimAssist = vape.Categories.Combat:CreateModule({
	Name = 'AimAssist',
	Function = function(callback)
		if CircleObject then
			CircleObject.Visible = callback
		end
		if callback then
			local ent
			local rightClicked = not RightClick.Enabled or inputService:IsMouseButtonPressed(1)
			AimAssist:Clean(runService.RenderStepped:Connect(function(dt)
				if CircleObject then
					CircleObject.Position = inputService:GetMouseLocation()
				end

				if rightClicked and not vape.gui.ScaledGui.ClickGui.Visible then
					ent = entitylib.EntityMouse({
						Range = FOV.Value,
						Part = Part.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Origin = gameCamera.CFrame.Position,
					})

					if ent then
						local facing = gameCamera.CFrame.LookVector
						local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
						new = new == new and new or Vector3.zero

						if ShowTarget.Enabled then
							targetinfo.Targets[ent] = tick() + 1
						end

						if new ~= Vector3.zero then
							local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(new.X, new.Z))
							local diffPitch = math.asin(facing.Y) - math.asin(new.Y)
							local angle = Vector2.new(diffYaw, diffPitch)
								// (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)

							angle *= math.min(Speed.Value * dt, 1)
							mousemoverel(angle.X, angle.Y)
						end
					end
				end
			end))

			if RightClick.Enabled then
				AimAssist:Clean(inputService.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton2 then
						ent = nil
						rightClicked = true
					end
				end))

				AimAssist:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton2 then
						rightClicked = false
					end
				end))
			end
		end
	end,
	Tooltip = 'Smoothly aims to closest valid target',
    })
    Targets = AimAssist:CreateTargets({ Players = true })
    Part = AimAssist:CreateDropdown({
	Name = 'Part',
	List = { 'RootPart', 'Head' },
    })
    FOV = AimAssist:CreateSlider({
	Name = 'FOV',
	Min = 0,
	Max = 1000,
	Default = 100,
	Function = function(val)
		if CircleObject then
			CircleObject.Radius = val
		end
	end,
    })
    Speed = AimAssist:CreateSlider({
	Name = 'Speed',
	Min = 0,
	Max = 30,
	Default = 15,
    })
    AimAssist:CreateToggle({
	Name = 'Range Circle',
	Function = function(callback)
		if callback then
			CircleObject = Drawing.new('Circle')
			CircleObject.Filled = CircleFilled.Enabled
			CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
			CircleObject.Position = vape.gui.AbsoluteSize / 2
			CircleObject.Radius = FOV.Value
			CircleObject.NumSides = 100
			CircleObject.Transparency = 1 - CircleTransparency.Value
			CircleObject.Visible = AimAssist.Enabled
		else
			pcall(function()
				CircleObject.Visible = false
				CircleObject:Remove()
			end)
		end
		CircleColor.Object.Visible = callback
		CircleTransparency.Object.Visible = callback
		CircleFilled.Object.Visible = callback
	end,
    })
    CircleColor = AimAssist:CreateColorSlider({
	Name = 'Circle Color',
	Function = function(hue, sat, val)
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(hue, sat, val)
		end
	end,
	Darker = true,
	Visible = false,
    })
    CircleTransparency = AimAssist:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Decimal = 10,
	Default = 0.5,
	Function = function(val)
		if CircleObject then
			CircleObject.Transparency = 1 - val
		end
	end,
	Darker = true,
	Visible = false,
    })
    CircleFilled = AimAssist:CreateToggle({
	Name = 'Circle Filled',
	Function = function(callback)
		if CircleObject then
			CircleObject.Filled = callback
		end
	end,
	Darker = true,
	Visible = false,
    })
    RightClick = AimAssist:CreateToggle({
	Name = 'Require right click',
	Function = function()
		if AimAssist.Enabled then
			AimAssist:Toggle()
			AimAssist:Toggle()
		end
	end,
    })
    ShowTarget = AimAssist:CreateToggle({
	Name = 'Show target info',
    })
end)

run(function()
    local AutoClicker
    local Mode
    local CPS

    AutoClicker = vape.Categories.Combat:CreateModule({
	Name = 'AutoClicker',
	Function = function(callback)
		if callback then
			repeat
				if Mode.Value == 'Tool' then
					local tool = getTool()
					if tool and inputService:IsMouseButtonPressed(0) then
						tool:Activate()
					end
				else
					if mouse1click and (isrbxactive or iswindowactive)() then
						if not vape.gui.ScaledGui.ClickGui.Visible then
							(Mode.Value == 'Click' and mouse1click or mouse2click)()
						end
					end
				end

				task.wait(1 / CPS.GetRandomValue())
			until not AutoClicker.Enabled
		end
	end,
	Tooltip = 'Automatically clicks for you',
    })
    Mode = AutoClicker:CreateDropdown({
	Name = 'Mode',
	List = { 'Tool', 'Click', 'RightClick' },
	Tooltip = 'Tool - Automatically uses roblox tools (eg. swords)\nClick - Left click\nRightClick - Right click',
    })
    CPS = AutoClicker:CreateTwoSlider({
	Name = 'CPS',
	Min = 1,
	Max = 20,
	DefaultMin = 8,
	DefaultMax = 12,
    })
end)

run(function()
    local Reach
    local Targets
    local Mode
    local Value
    local Chance
    local Overlay = OverlapParams.new()
    Overlay.FilterType = Enum.RaycastFilterType.Include
    local modified = {}

    Reach = vape.Categories.Combat:CreateModule({
	Name = 'Reach',
	Function = function(callback)
		if callback then
			repeat
				local tool = getTool()
				tool = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true)
				if tool then
					if Mode.Value == 'TouchInterest' then
						local entites = {}
						for _, v in entitylib.List do
							if v.Targetable then
								if not Targets.Players.Enabled and v.Player then
									continue
								end
								if not Targets.NPCs.Enabled and v.NPC then
									continue
								end
								table.insert(entites, v.Character)
							end
						end

						Overlay.FilterDescendantsInstances = entites
						local parts = workspace:GetPartBoundsInBox(
							tool.Parent.CFrame * CFrame.new(0, 0, Value.Value / 2),
							tool.Parent.Size + Vector3.new(0, 0, Value.Value),
							Overlay
						)

						for _, v in parts do
							if Random.new().NextNumber(Random.new(), 0, 100) > Chance.Value then
								task.wait(0.2)
								break
							end

							firetouchinterest(tool.Parent, v, 1)
							firetouchinterest(tool.Parent, v, 0)
						end
					else
						if not modified[tool.Parent] then
							modified[tool.Parent] = tool.Parent.Size
						end
						tool.Parent.Size = modified[tool.Parent] + Vector3.new(0, 0, Value.Value)
						tool.Parent.Massless = true
					end
				end

				task.wait()
			until not Reach.Enabled
		else
			for i, v in modified do
				i.Size = v
				i.Massless = false
			end
			table.clear(modified)
		end
	end,
	Tooltip = 'Extends tool attack reach',
    })
    Targets = Reach:CreateTargets({ Players = true })
    Mode = Reach:CreateDropdown({
	Name = 'Mode',
	List = { 'TouchInterest', 'Resize' },
	Function = function(val)
		Chance.Object.Visible = val == 'TouchInterest'
	end,
	Tooltip = 'TouchInterest - Reports fake collision events to the server\nResize - Physically modifies the tools size',
    })
    Value = Reach:CreateSlider({
	Name = 'Range',
	Min = 0,
	Max = 2,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    Chance = Reach:CreateSlider({
	Name = 'Chance',
	Min = 0,
	Max = 100,
	Default = 100,
	Suffix = '%',
    })
end)

run(function()
    local SilentAim
    local Target
    local Mode
    local Method
    local MethodRay
    local IgnoredScripts
    local Range
    local HitChance
    local HeadshotChance
    local AutoFire
    local AutoFireShootDelay
    local AutoFireMode
    local AutoFirePosition
    local Wallbang
    local CircleColor
    local CircleTransparency
    local CircleFilled
    local CircleObject
    local Projectile
    local ProjectileSpeed
    local ProjectileGravity
    local RaycastWhitelist = RaycastParams.new()
    RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
    local ProjectileRaycast = RaycastParams.new()
    ProjectileRaycast.RespectCanCollide = true
    local fireoffset, rand, delayCheck = CFrame.identity, Random.new(), tick()
    local oldnamecall, oldray

    local function getTarget(origin, obj)
	if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then
		return
	end
	local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head'
		or 'RootPart'
	local ent = entitylib['Entity' .. Mode.Value]({
		Range = Range.Value,
		Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
		Part = targetPart,
		Origin = origin,
		Players = Target.Players.Enabled,
		NPCs = Target.NPCs.Enabled,
	})

	if ent then
		targetinfo.Targets[ent] = tick() + 1
		if Projectile.Enabled then
			ProjectileRaycast.FilterDescendantsInstances = { gameCamera, ent.Character }
			ProjectileRaycast.CollisionGroup = ent[targetPart].CollisionGroup
		end
	end

	return ent, ent and ent[targetPart], origin
    end

    local Hooks = {
	FindPartOnRayWithIgnoreList = function(args)
		local ent, targetPart, origin = getTarget(args[1].Origin, { args[2] })
		if not ent then
			return
		end
		if Wallbang.Enabled then
			return {
				targetPart,
				targetPart.Position,
				targetPart.GetClosestPointOnSurface(targetPart, origin),
				targetPart.Material,
			}
		end
		args[1] = Ray.new(origin, CFrame.lookAt(origin, targetPart.Position).LookVector * args[1].Direction.Magnitude)
	end,
	Raycast = function(args)
		if MethodRay.Value ~= 'All' and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[MethodRay.Value] then
			return
		end
		local ent, targetPart, origin = getTarget(args[1])
		if not ent then
			return
		end
		args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
		if Wallbang.Enabled then
			RaycastWhitelist.FilterDescendantsInstances = { targetPart }
			args[3] = RaycastWhitelist
		end
	end,
	ScreenPointToRay = function(args)
		local ent, targetPart, origin = getTarget(gameCamera.CFrame.Position)
		if not ent then
			return
		end
		local direction = CFrame.lookAt(origin, targetPart.Position)
		if Projectile.Enabled then
			local calc = prediction.SolveTrajectory(
				origin,
				ProjectileSpeed.Value,
				ProjectileGravity.Value,
				targetPart.Position,
				targetPart.Velocity,
				workspace.Gravity,
				ent.HipHeight,
				nil,
				ProjectileRaycast
			)
			if not calc then
				return
			end
			direction = CFrame.lookAt(origin, calc)
		end
		return { Ray.new(origin + (args[3] and direction.LookVector * args[3] or Vector3.zero), direction.LookVector) }
	end,
	Ray = function(args)
		local ent, targetPart, origin = getTarget(args[1])
		if not ent then
			return
		end
		if Projectile.Enabled then
			local calc = prediction.SolveTrajectory(
				origin,
				ProjectileSpeed.Value,
				ProjectileGravity.Value,
				targetPart.Position,
				targetPart.Velocity,
				workspace.Gravity,
				ent.HipHeight,
				nil,
				ProjectileRaycast
			)
			if not calc then
				return
			end
			args[2] = CFrame.lookAt(origin, calc).LookVector * args[2].Magnitude
		else
			args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
		end
	end,
    }
    Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
    Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
    Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

    SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if CircleObject then
			CircleObject.Visible = callback and Mode.Value == 'Mouse'
		end
		if callback then
			if Method.Value == 'Ray' then
				oldray = hookfunction(Ray.new, function(origin, direction)
					if checkcaller() then
						return oldray(origin, direction)
					end
					local calling = getcallingscript()

					if calling then
						local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled
							or { 'ControlScript', 'ControlModule' }
						if table.find(list, tostring(calling)) then
							return oldray(origin, direction)
						end
					end

					local args = { origin, direction }
					Hooks.Ray(args)
					return oldray(unpack(args))
				end)
			else
				oldnamecall = hookmetamethod(game, '__namecall', function(...)
					if getnamecallmethod() ~= Method.Value then
						return oldnamecall(...)
					end
					if checkcaller() then
						return oldnamecall(...)
					end

					local calling = getcallingscript()
					if calling then
						local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled
							or { 'ControlScript', 'ControlModule' }
						if table.find(list, tostring(calling)) then
							return oldnamecall(...)
						end
					end

					local self, args = ..., { select(2, ...) }
					local res = Hooks[Method.Value](args)
					if res then
						return unpack(res)
					end
					return oldnamecall(self, unpack(args))
				end)
			end

			repeat
				if CircleObject then
					CircleObject.Position = inputService:GetMouseLocation()
				end
				if AutoFire.Enabled then
					local origin = AutoFireMode.Value == 'Camera' and gameCamera.CFrame
						or entitylib.isAlive and entitylib.character.RootPart.CFrame
						or CFrame.identity
					local ent = entitylib['Entity' .. Mode.Value]({
						Range = Range.Value,
						Wallcheck = Target.Walls.Enabled or nil,
						Part = 'Head',
						Origin = (origin * fireoffset).Position,
						Players = Target.Players.Enabled,
						NPCs = Target.NPCs.Enabled,
					})

					if mouse1click and (isrbxactive or iswindowactive)() then
						if ent and canClick() then
							if delayCheck < tick() then
								if mouseClicked then
									mouse1release()
									delayCheck = tick() + AutoFireShootDelay.Value
								else
									mouse1press()
								end
								mouseClicked = not mouseClicked
							end
						else
							if mouseClicked then
								mouse1release()
							end
							mouseClicked = false
						end
					end
				end
				task.wait()
			until not SilentAim.Enabled
		else
			if oldnamecall then
				hookmetamethod(game, '__namecall', oldnamecall)
			end
			if oldray then
				hookfunction(Ray.new, oldray)
			end
			oldnamecall, oldray = nil, nil
		end
	end,
	ExtraText = function()
		return Method.Value:gsub('FindPartOnRay', '')
	end,
	Tooltip = 'Silently adjusts your aim towards the enemy',
    })
    Target = SilentAim:CreateTargets({ Players = true })
    Mode = SilentAim:CreateDropdown({
	Name = 'Mode',
	List = { 'Mouse', 'Position' },
	Function = function(val)
		if CircleObject then
			CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
		end
	end,
	Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character',
    })
    Method = SilentAim:CreateDropdown({
	Name = 'Method',
	List = {
		'FindPartOnRay',
		'FindPartOnRayWithIgnoreList',
		'FindPartOnRayWithWhitelist',
		'ScreenPointToRay',
		'ViewportPointToRay',
		'Raycast',
		'Ray',
	},
	Function = function(val)
		if SilentAim.Enabled then
			SilentAim:Toggle()
			SilentAim:Toggle()
		end
		MethodRay.Object.Visible = val == 'Raycast'
	end,
	Tooltip = 'FindPartOnRay* - old deprecated raycasts\nRaycast - the modern one\nPointToRay - ray from screen coords\nRay - hooks Ray.new',
    })
    MethodRay = SilentAim:CreateDropdown({
	Name = 'Raycast Type',
	List = { 'All', 'Exclude', 'Include' },
	Darker = true,
	Visible = false,
    })
    IgnoredScripts = SilentAim:CreateTextList({ Name = 'Ignored Scripts' })
    Range = SilentAim:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 1000,
	Default = 150,
	Function = function(val)
		if CircleObject then
			CircleObject.Radius = val
		end
	end,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    HitChance = SilentAim:CreateSlider({
	Name = 'Hit Chance',
	Min = 0,
	Max = 100,
	Default = 85,
	Suffix = '%',
    })
    HeadshotChance = SilentAim:CreateSlider({
	Name = 'Headshot Chance',
	Min = 0,
	Max = 100,
	Default = 65,
	Suffix = '%',
    })
    AutoFire = SilentAim:CreateToggle({
	Name = 'AutoFire',
	Function = function(callback)
		AutoFireShootDelay.Object.Visible = callback
		AutoFireMode.Object.Visible = callback
		AutoFirePosition.Object.Visible = callback
	end,
    })
    AutoFireShootDelay = SilentAim:CreateSlider({
	Name = 'Next Shot Delay',
	Min = 0,
	Max = 1,
	Decimal = 100,
	Visible = false,
	Darker = true,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
    })
    AutoFireMode = SilentAim:CreateDropdown({
	Name = 'Origin',
	List = { 'RootPart', 'Camera' },
	Visible = false,
	Darker = true,
	Tooltip = 'Determines the position to check for before shooting',
    })
    AutoFirePosition = SilentAim:CreateTextBox({
	Name = 'Offset',
	Function = function()
		local suc, res = pcall(function()
			return CFrame.new(unpack(AutoFirePosition.Value:split(',')))
		end)
		if suc then
			fireoffset = res
		end
	end,
	Default = '0, 0, 0',
	Visible = false,
	Darker = true,
    })
    Wallbang = SilentAim:CreateToggle({ Name = 'Wallbang' })
    SilentAim:CreateToggle({
	Name = 'Range Circle',
	Function = function(callback)
		if callback then
			CircleObject = Drawing.new('Circle')
			CircleObject.Filled = CircleFilled.Enabled
			CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
			CircleObject.Position = vape.gui.AbsoluteSize / 2
			CircleObject.Radius = Range.Value
			CircleObject.NumSides = 100
			CircleObject.Transparency = 1 - CircleTransparency.Value
			CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
		else
			pcall(function()
				CircleObject.Visible = false
				CircleObject:Remove()
			end)
		end
		CircleColor.Object.Visible = callback
		CircleTransparency.Object.Visible = callback
		CircleFilled.Object.Visible = callback
	end,
    })
    CircleColor = SilentAim:CreateColorSlider({
	Name = 'Circle Color',
	Function = function(hue, sat, val)
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(hue, sat, val)
		end
	end,
	Darker = true,
	Visible = false,
    })
    CircleTransparency = SilentAim:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Decimal = 10,
	Default = 0.5,
	Function = function(val)
		if CircleObject then
			CircleObject.Transparency = 1 - val
		end
	end,
	Darker = true,
	Visible = false,
    })
    CircleFilled = SilentAim:CreateToggle({
	Name = 'Circle Filled',
	Function = function(callback)
		if CircleObject then
			CircleObject.Filled = callback
		end
	end,
	Darker = true,
	Visible = false,
    })
    Projectile = SilentAim:CreateToggle({
	Name = 'Projectile',
	Function = function(callback)
		ProjectileSpeed.Object.Visible = callback
		ProjectileGravity.Object.Visible = callback
	end,
    })
    ProjectileSpeed = SilentAim:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 1000,
	Default = 1000,
	Darker = true,
	Visible = false,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    ProjectileGravity = SilentAim:CreateSlider({
	Name = 'Gravity',
	Min = 0,
	Max = 192.6,
	Default = 192.6,
	Darker = true,
	Visible = false,
    })
end)

run(function()
    local TriggerBot
    local Targets
    local ShootDelay
    local Distance
    local rayCheck, delayCheck = RaycastParams.new(), tick()

    local function getTriggerBotTarget()
	rayCheck.FilterDescendantsInstances = { lplr.Character, gameCamera }

	local ray = workspace:Raycast(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Distance.Value, rayCheck)
	if ray and ray.Instance then
		for _, v in entitylib.List do
			if
				v.Targetable
				and v.Character
				and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC)
			then
				if ray.Instance:IsDescendantOf(v.Character) then
					return entitylib.isVulnerable(v) and v
				end
			end
		end
	end
    end

    TriggerBot = vape.Categories.Combat:CreateModule({
	Name = 'TriggerBot',
	Function = function(callback)
		if callback then
			repeat
				if mouse1click and (isrbxactive or iswindowactive)() then
					if getTriggerBotTarget() and canClick() then
						if delayCheck < tick() then
							if mouseClicked then
								mouse1release()
								delayCheck = tick() + ShootDelay.Value
							else
								mouse1press()
							end
							mouseClicked = not mouseClicked
						end
					else
						if mouseClicked then
							mouse1release()
						end
						mouseClicked = false
					end
				end
				task.wait()
			until not TriggerBot.Enabled
		else
			if mouse1click and (isrbxactive or iswindowactive)() then
				if mouseClicked then
					mouse1release()
				end
			end
			mouseClicked = false
		end
	end,
	Tooltip = 'Shoots people that enter your crosshair',
    })
    Targets = TriggerBot:CreateTargets({
	Players = true,
	NPCs = true,
    })
    ShootDelay = TriggerBot:CreateSlider({
	Name = 'Next Shot Delay',
	Min = 0,
	Max = 1,
	Decimal = 100,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
	Tooltip = 'The delay set after shooting a target',
    })
    Distance = TriggerBot:CreateSlider({
	Name = 'Distance',
	Min = 0,
	Max = 1000,
	Default = 1000,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
end)

--[[
    Blatant
]]

run(function()
    local AntiFall
    local Method
    local Mode
    local Material
    local Color
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local part

    AntiFall = vape.Categories.Blatant:CreateModule({
	Name = 'AntiVoid',
	Function = function(callback)
		if callback then
			if Method.Value == 'Part' then
				local debounce = tick()
				part = Instance.new('Part')
				part.Size = Vector3.new(10000, 1, 10000)
				part.Transparency = 1 - Color.Opacity
				part.Material = Enum.Material[Material.Value]
				part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				part.CanCollide = Mode.Value == 'Collide'
				part.Anchored = true
				part.CanQuery = false
				part.Parent = workspace
				AntiFall:Clean(part)
				AntiFall:Clean(part.Touched:Connect(function(touchedpart)
					if touchedpart.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
						local root = entitylib.character.RootPart
						debounce = tick() + 0.1
						if Mode.Value == 'Velocity' then
							root.AssemblyLinearVelocity =
								Vector3.new(root.AssemblyLinearVelocity.X, 100, root.AssemblyLinearVelocity.Z)
						elseif Mode.Value == 'Impulse' then
							root:ApplyImpulse(
								Vector3.new(0, (100 - root.AssemblyLinearVelocity.Y), 0) * root.AssemblyMass
							)
						end
					end
				end))

				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						rayCheck.FilterDescendantsInstances = { gameCamera, lplr.Character, part }
						rayCheck.CollisionGroup = root.CollisionGroup
						local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
						if ray then
							part.Position = ray.Position - Vector3.new(0, 15, 0)
						end
					end
					task.wait(0.1)
				until not AntiFall.Enabled
			else
				local lastpos
				AntiFall:Clean(runService.PreSimulation:Connect(function()
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						lastpos = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and root.Position
							or lastpos
						if
							(root.Position.Y + (root.Velocity.Y * 0.016)) <= (workspace.FallenPartsDestroyHeight + 10)
						then
							lastpos = lastpos
								or Vector3.new(
									root.Position.X,
									(workspace.FallenPartsDestroyHeight + 20),
									root.Position.Z
								)
							root.CFrame += (lastpos - root.Position)
							root.Velocity *= Vector3.new(1, 0, 1)
						end
					end
				end))
			end
		end
	end,
	Tooltip = "Help's you with your Parkinson's\nPrevents you from falling into the void",
    })
    Method = AntiFall:CreateDropdown({
	Name = 'Method',
	List = { 'Part', 'Classic' },
	Function = function(val)
		if Mode.Object then
			Mode.Object.Visible = val == 'Part'
			Material.Object.Visible = val == 'Part'
			Color.Object.Visible = val == 'Part'
		end
		if AntiFall.Enabled then
			AntiFall:Toggle()
			AntiFall:Toggle()
		end
	end,
	Tooltip = 'Part - a part under you that stops the fall\nClassic - teleports you out of the void',
    })
    Mode = AntiFall:CreateDropdown({
	Name = 'Move Mode',
	List = { 'Impulse', 'Velocity', 'Collide' },
	Darker = true,
	Function = function(val)
		if part then
			part.CanCollide = val == 'Collide'
		end
	end,
	Tooltip = 'Velocity - Launches you upward after touching\nCollide - Allows you to walk on the part',
    })
    local materials = { 'ForceField' }
    for _, v in Enum.Material:GetEnumItems() do
	if v.Name ~= 'ForceField' then
		table.insert(materials, v.Name)
	end
    end
    Material = AntiFall:CreateDropdown({
	Name = 'Material',
	List = materials,
	Darker = true,
	Function = function(val)
		if part then
			part.Material = Enum.Material[val]
		end
	end,
    })
    Color = AntiFall:CreateColorSlider({
	Name = 'Color',
	DefaultOpacity = 0.5,
	Darker = true,
	Function = function(h, s, v, o)
		if part then
			part.Color = Color3.fromHSV(h, s, v)
			part.Transparency = 1 - o
		end
	end,
    })
end)

run(function()
    local AirWalk
    local platform = Instance.new('Part')
    platform.Name = 'AetherAirWalkGround'
    platform.Anchored = true
    platform.CanCollide = true
    platform.CanQuery = false
    platform.CanTouch = false
    platform.Transparency = 1
    platform.Size = Vector3.new(7, 0.3, 7)
    platform.CFrame = CFrame.new(0, -10000, 0)

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    rayCheck.RespectCanCollide = true
    local lastGroundY
    local trackedCharacter

    local function clearance(character)
	return character.HipHeight
		or ((character.Humanoid and character.Humanoid.HipHeight or 2) + (character.RootPart.Size.Y * 0.5))
    end

    local function groundBelow(root)
	-- A real floor anywhere below the player takes precedence over the fake platform.
	-- The platform itself is excluded from this raycast by the active filter.
	return workspace:Raycast(
		root.Position + Vector3.new(0, 0.75, 0),
		Vector3.new(0, -10000, 0),
		rayCheck
	)
    end

    AirWalk = vape.Categories.Blatant:CreateModule({
	Name = 'AirWalk',
	Function = function(callback)
		if callback then
			platform.CFrame = CFrame.new(0, -10000, 0)
			platform.Parent = workspace
			AirWalk:Clean(runService.PreSimulation:Connect(function()
				if not entitylib.isAlive then
					platform.CFrame = CFrame.new(0, -10000, 0)
					lastGroundY = nil
					trackedCharacter = nil
					return
				end

				local character = entitylib.character
				if trackedCharacter ~= character.Character then
					trackedCharacter = character.Character
					lastGroundY = nil
				end
				local root = character.RootPart
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, platform}
				pcall(function() rayCheck.CollisionGroup = root.CollisionGroup end)
				local ground = groundBelow(root)

				if ground and ground.Normal.Y > 0.15 then
					lastGroundY = ground.Position.Y
					platform.CFrame = CFrame.new(0, -10000, 0)
					return
				end

				if lastGroundY then
					platform.CFrame = CFrame.new(root.Position.X, lastGroundY - (platform.Size.Y * 0.5), root.Position.Z)
				else
					platform.CFrame = CFrame.new(0, -10000, 0)
				end
			end))
		else
			platform.Parent = nil
		end
	end,
	Tooltip = 'Creates stable fake ground over void at the height of your most recent real floor',
    })

    -- Remember real floor while the module is off too, so enabling it just after walking
    -- over an edge uses the ledge height instead of inventing ground at the current air height.
    vape:Clean(runService.PreSimulation:Connect(function()
	if AirWalk.Enabled or not entitylib.isAlive then
		if not entitylib.isAlive then
			lastGroundY = nil
			trackedCharacter = nil
		end
		return
	end
	local character = entitylib.character
	if trackedCharacter ~= character.Character then
		trackedCharacter = character.Character
		lastGroundY = nil
	end
	local root = character.RootPart
	rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, platform}
	pcall(function() rayCheck.CollisionGroup = root.CollisionGroup end)
	local ground = groundBelow(root)
	if ground and ground.Normal.Y > 0.15 then lastGroundY = ground.Position.Y end
    end))

    vape:Clean(function()
	platform:Destroy()
    end)
end)

run(function()
    local Desync
    local hook

    local function resync()
        if entitylib.isAlive then
            entitylib.character.RootPart.CFrame += Vector3.new(math.nan, math.nan, math.nan)
            notif('Desync', 'Resynced', 2, 'info')
        end
    end

    Desync = vape.Categories.Blatant:CreateModule({
        Name = 'Desync',
        Function = function(callback)
            if callback then
                if not rakNetCheck('Desync') then
                    Desync:Toggle()
                    return
                end

                hook = function(packet)
                    -- Runs on every outgoing packet on the network thread: a single error
                    -- here (short buffer, missing array) crashes/disconnects the client, so
                    -- everything is guarded with pcall and an explicit length check.
                    pcall(function()
                        if packet.AsArray and packet.AsArray[1] == 0x1b then
                            local data = packet.AsBuffer
                            if data and buffer.len(data) >= 5 then
                                buffer.writeu32(data, 1, 0xFFFFFFFF)
                                packet:SetData(data)
                            end
                        end
                    end)
                end

                resync()
                raknet.add_send_hook(hook)
            elseif hook then
                raknet.remove_send_hook(hook)
                hook = nil
            end
        end,
        Tooltip = 'Prevent the server from replicating your current position to other players'
    })

    Desync:CreateButton({
        Name = 'Resync',
        Function = resync
    })
end)

run(function()
    local InfiniteFly
    local UpSpeed
    local DownSpeed
    local HorizontalSpeed
    local state
    local generation = 0

    local function cleanup(restorePosition)
        local current = state
        state = nil
        if not current then return end
        if current.Connection then current.Connection:Disconnect() end
        if current.DiedConnection then current.DiedConnection:Disconnect() end
        if current.CharacterConnection then current.CharacterConnection:Disconnect() end
        if current.Clone and current.Clone.Parent then current.Clone:Destroy() end
        if current.Character and current.Character.Parent then
            local humanoid = current.Character:FindFirstChildOfClass('Humanoid')
            local root = current.Character:FindFirstChild('HumanoidRootPart') or current.Character.PrimaryPart
            if humanoid then humanoid.PlatformStand = false; humanoid.AutoRotate = true end
            if root then
                root.Anchored = false
                root.AssemblyAngularVelocity = Vector3.zero
                if restorePosition and current.SafeCFrame then root.CFrame = current.SafeCFrame end
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
        if gameCamera and current.CameraSubject and current.CameraSubject.Parent then gameCamera.CameraSubject = current.CameraSubject end
    end

    local function disable()
        task.defer(function() if InfiniteFly.Enabled then InfiniteFly:Toggle() end end)
    end

    local function start()
        if not entitylib.isAlive or not entitylib.character then disable(); return end
        cleanup(false)
        generation += 1
        local myGeneration = generation
        local character = entitylib.character.Character
        local root = entitylib.character.RootPart
        local humanoid = entitylib.character.Humanoid
        if not character or not root or not humanoid then disable(); return end

        local safe = root.CFrame
        local clone
        local oldArchivable = character.Archivable
        character.Archivable = true
        local ok, result = pcall(character.Clone, character)
        character.Archivable = oldArchivable
        if ok then clone = result end
        if clone then
            clone.Name = 'AetherInfiniteFlyVisual'
            for _, object in clone:GetDescendants() do
                if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy()
                elseif object:IsA('BasePart') then object.CanCollide = false; object.CanTouch = false; object.CanQuery = false end
            end
            clone.Parent = workspace
            clone:PivotTo(character:GetPivot())
        end

        state = {Character = character, Root = root, Humanoid = humanoid, Clone = clone, SafeCFrame = safe, CameraSubject = gameCamera.CameraSubject}
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true

        state.DiedConnection = humanoid.Died:Connect(function()
            -- Never leave the render/fly loop holding destroyed character references.
            generation += 1
            cleanup(false)
        end)
        state.CharacterConnection = lplr.CharacterAdded:Connect(function()
            generation += 1
            cleanup(false)
            if InfiniteFly.Enabled then task.delay(0.35, function() if InfiniteFly.Enabled then start() end end) end
        end)

        state.Connection = runService.Heartbeat:Connect(function(dt)
            if myGeneration ~= generation or not InfiniteFly.Enabled then return end
            if not root.Parent or humanoid.Health <= 0 then generation += 1; cleanup(false); return end
            if not isnetworkowner(root) then return end

            local move = humanoid.MoveDirection
            local vertical = 0
            if inputService:IsKeyDown(Enum.KeyCode.Space) then vertical += UpSpeed.Value end
            if inputService:IsKeyDown(Enum.KeyCode.LeftShift) or inputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical -= DownSpeed.Value end
            local horizontal = move.Magnitude > 0 and move.Unit * HorizontalSpeed.Value or Vector3.zero

            -- Drive velocity once per physics heartbeat. The previous implementation fought
            -- several movement writers and decelerated itself, which caused immediate lagbacks.
            root.AssemblyLinearVelocity = Vector3.new(horizontal.X, vertical, horizontal.Z)
            root.AssemblyAngularVelocity = Vector3.zero

            -- Keep a recent grounded position. On disable/death this is the only position we may
            -- restore to; never teleport to stale clone coordinates.
            local floor = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), RaycastParams.new())
            if floor and floor.Instance and floor.Instance.CanCollide then state.SafeCFrame = root.CFrame end
            if clone and clone.Parent then clone:PivotTo(root.CFrame) end
        end)
    end

    InfiniteFly = vape.Categories.Blatant:CreateModule({
        Name = 'InfiniteFly',
        Tooltip = 'Sustained flight with death-safe cleanup and a single physics velocity writer.',
        Function = function(callback)
            generation += 1
            if callback then start() else cleanup(false) end
        end
    })
    HorizontalSpeed = InfiniteFly:CreateSlider({Name = 'Speed', Min = 10, Max = 100, Default = 28, Suffix = ' studs/s'})
    UpSpeed = InfiniteFly:CreateSlider({Name = 'Up speed', Min = 5, Max = 100, Default = 28, Suffix = ' studs/s'})
    DownSpeed = InfiniteFly:CreateSlider({Name = 'Down speed', Min = 5, Max = 100, Default = 28, Suffix = ' studs/s'})
    InfiniteFly:Clean(function() generation += 1; cleanup(false) end)
end)

run(function()
    local HighJump
    local Mode
    local Value
    local AutoDisable

    local function jump()
	local state = entitylib.isAlive and Enum.HumanoidStateType.Running or nil

	if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
		local root = entitylib.character.RootPart

		if Mode.Value == 'Velocity' then
			entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			root.AssemblyLinearVelocity =
				Vector3.new(root.AssemblyLinearVelocity.X, Value.Value, root.AssemblyLinearVelocity.Z)
		elseif Mode.Value == 'Impulse' then
			entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.delay(0, function()
				root:ApplyImpulse(Vector3.new(0, Value.Value - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
			end)
		else
			local start = math.max(Value.Value - entitylib.character.Humanoid.JumpHeight, 0)
			repeat
				root.CFrame += Vector3.new(0, start * 0.016, 0)
				start = start - (workspace.Gravity * 0.016)
				if Mode.Value == 'CFrame' then
					task.wait()
				end
			until start <= 0
		end
	end
    end

    HighJump = vape.Categories.Blatant:CreateModule({
	Name = 'HighJump',
	Function = function(callback)
		if callback then
			if AutoDisable.Enabled then
				jump()
				HighJump:Toggle()
			else
				HighJump:Clean(runService.RenderStepped:Connect(function()
					if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
						jump()
					end
				end))
			end
		end
	end,
	ExtraText = function()
		return Mode.Value
	end,
	Tooltip = 'Lets you jump higher',
    })
    Mode = HighJump:CreateDropdown({
	Name = 'Mode',
	List = { 'Impulse', 'Velocity', 'CFrame', 'Instant' },
	Tooltip = 'Velocity - smooth boost up\nImpulse - the same using forces\nCFrame - moves you up\nInstant - teleport to the peak',
    })
    Value = HighJump:CreateSlider({
	Name = 'Velocity',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    AutoDisable = HighJump:CreateToggle({
	Name = 'Auto Disable',
	Default = true,
    })
end)

run(function()
    local HitBoxes
    local Targets
    local TargetPart
    local Expand
    local modified = {}

    HitBoxes = vape.Categories.Blatant:CreateModule({
	Name = 'HitBoxes',
	Function = function(callback)
		if callback then
			repeat
				for _, v in entitylib.List do
					if v.Targetable then
						if not Targets.Players.Enabled and v.Player then
							continue
						end
						if not Targets.NPCs.Enabled and v.NPC then
							continue
						end
						local part = v[TargetPart.Value]
						if not modified[part] then
							modified[part] = {part.Size, part.Massless}
						end
						part.Size = modified[part][1] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
						part.Massless = true
					end
				end
				task.wait()
			until not HitBoxes.Enabled
		else
			for i, v in modified do
				i.Size = v[1]
				i.Massless = v[2]
			end
			table.clear(modified)
		end
	end,
	Tooltip = 'Expands entities hitboxes',
    })
    Targets = HitBoxes:CreateTargets({ Players = true })
    TargetPart = HitBoxes:CreateDropdown({
	Name = 'Part',
	List = { 'RootPart', 'Head' },
    })
    Expand = HitBoxes:CreateSlider({
	Name = 'Expand amount',
	Min = 0,
	Max = 2,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
end)

run(function()
    local InfiniteJump
    local Mode
    local TP
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local jumps = 0

    --[[
        TP Down, ported from Fly.

        It is not a descent, and it never replaces the jump - which is what the old version did.
        It handed every JumpRequest to a teleport and returned, so with the option on the module
        stopped jumping altogether and looked completely broken.

        What Fly actually does, and what happens here: stay airborne long enough and the server
        starts treating you as falling. So once per stretch of airtime, drop to whatever is under
        you, hold there just long enough for the touch to register, then go straight back up to
        the height you left. The server sees a player who keeps landing; you never lose altitude.

        universal.lua builds its own entitylib, and AirTime is filled in by the game files rather
        than the library, so the airborne clock is kept here instead.
    ]]
    local groundTick, tpTick, tpToggle, oldy = tick(), tick(), true, nil

    local function tpDownStep()
        local character = entitylib.character
        local root = character and character.RootPart
        if not root or not root.Parent then return end
        if isnetworkowner and not isnetworkowner(root) then return end

        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
        rayCheck.CollisionGroup = root.CollisionGroup

        if tpToggle then
            -- Standing on something resets the clock, exactly as a real landing would.
            if workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), rayCheck) then
                groundTick = tick()
            end
            if oldy or (tick() - groundTick) <= 2 then return end
            local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
            if not ray then return end
            tpToggle = false
            oldy = root.Position.Y
            tpTick = tick() + 0.11
            root.CFrame = CFrame.lookAlong(
                Vector3.new(root.Position.X, ray.Position.Y + (character.HipHeight or 3), root.Position.Z),
                root.CFrame.LookVector
            )
        elseif oldy then
            if tpTick < tick() then
                root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, oldy, root.Position.Z), root.CFrame.LookVector)
                tpToggle = true
                oldy = nil
                groundTick = tick()
            else
                -- Held on the floor for the touch window. Falling away from it mid-hold is what
                -- would stop the landing registering at all.
                local velocity = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            end
        end
    end

    InfiniteJump = vape.Categories.Blatant:CreateModule({
	Name = 'InfiniteJump',
	Tooltip = 'Allows you to jump infinitely',
	Function = function(callback: boolean)
		if callback then
			jumps = 0
			groundTick, tpTick, tpToggle, oldy = tick(), tick(), true, nil

			InfiniteJump:Clean(runService.PreSimulation:Connect(function()
				if not TP.Enabled or not entitylib.isAlive then return end
				tpDownStep()
			end))

			InfiniteJump:Clean(inputService.JumpRequest:Connect(function()
				if not entitylib.isAlive then return end
				jumps += 1

				if jumps > 1 and Mode.Value == 'Velocity' then
					local power = math.sqrt(2 * workspace.Gravity * entitylib.character.Humanoid.JumpHeight)
					entitylib.character.RootPart.Velocity = Vector3.new(
						entitylib.character.RootPart.Velocity.X,
						power,
						entitylib.character.RootPart.Velocity.Z
					)
				elseif Mode.Value == 'Jump' then
					entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end))
		end
	end,
	ExtraText = function()
		return TP.Enabled and 'TP Down' or Mode.Value
	end,
    })
    Mode = InfiniteJump:CreateDropdown({
	Name = 'Mode',
	List = { 'Jump', 'Velocity' },
    })
    TP = InfiniteJump:CreateToggle({
	Name = 'TP Down',
	Tooltip = 'Touches the ground and returns once you have been airborne too long, so the server keeps seeing you land. Jumping is unaffected',
    })
end)

run(function()
    local Killaura
    local Targets
    local CPS
    local SwingRange
    local AttackRange
    local AngleSlider
    local Max
    local Mouse
    local Lunge
    local BoxSwingColor
    local BoxAttackColor
    local ParticleTexture
    local ParticleColor1
    local ParticleColor2
    local ParticleSize
    local Face
    local Overlay = OverlapParams.new()
    Overlay.FilterType = Enum.RaycastFilterType.Include
    local Particles, Boxes, AttackDelay = {}, {}, tick()
	local customSwing = game.PlaceId == 132768098780837
	local function getCustomSwingEvent()
		local events = customSwing and replicatedStorage:FindFirstChild('GameEvents')
		local combat = events and events:FindFirstChild('CombatRemotes')
		return combat and combat:FindFirstChild('Combat_SwingStarted')
	end
	local function customAttack(target, tool)
		local events = replicatedStorage:FindFirstChild('GameEvents')
		local combat = events and events:FindFirstChild('CombatRemotes')
		local remote = combat and (combat:FindFirstChild('Combat_AttemptHit') or combat:FindFirstChild('Combat_Hit'))
		if remote then
			remote:FireServer({
				target = target.Character,
				targetCharacter = target.Character,
				weapon = tool,
				hitPosition = target.RootPart.Position
			})
		end
	end

    local function getAttackData()
	if Mouse.Enabled then
		if not inputService:IsMouseButtonPressed(0) then
			return false
		end
	end

	if customSwing then
		local customSwingEvent = getCustomSwingEvent()
		local equipped = getTool()
		return customSwingEvent, {GripUp = Vector3.yAxis, Tool = equipped, Activate = function()
			if customSwingEvent and equipped then customSwingEvent:FireServer(equipped.Name) end
		end}
	end
	local tool = getTool()
	return tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true) or nil, tool
    end

    Killaura = vape.Categories.Blatant:CreateModule({
	Name = 'Killaura',
	Function = function(callback)
		if callback then
			repeat
				local interest, tool = getAttackData()
				local attacked = {}
				if interest then
					local plrs = entitylib.AllPosition({
						Range = SwingRange.Value,
						Wallcheck = Targets.Walls.Enabled or nil,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = Max.Value,
					})

					if #plrs > 0 then
						local selfpos = entitylib.character.RootPart.Position
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

						for _, v in plrs do
							local delta = (v.RootPart.Position - selfpos)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							if angle > (math.rad(AngleSlider.Value) / 2) then
								continue
							end

							table.insert(attacked, {
								Entity = v,
								Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor,
							})
							targetinfo.Targets[v] = tick() + 1

							if AttackDelay < tick() then
								AttackDelay = tick() + (1 / CPS.GetRandomValue())
								tool:Activate()
							end

							if Lunge.Enabled and tool.GripUp.X == 0 then
								break
							end
							if delta.Magnitude > AttackRange.Value then
								continue
							end

							if customSwing then
								customAttack(v, tool.Tool)
								continue
							end
							Overlay.FilterDescendantsInstances = { v.Character }
							for _, part in
								workspace:GetPartBoundsInBox(v.RootPart.CFrame, Vector3.new(4, 4, 4), Overlay)
							do
								firetouchinterest(interest.Parent, part, 1)
								firetouchinterest(interest.Parent, part, 0)
							end
						end
					end
				end

				for i, v in Boxes do
					v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
					if v.Adornee then
						v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
						v.Transparency = 1 - attacked[i].Check.Opacity
					end
				end

				for i, v in Particles do
					v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
					v.Parent = attacked[i] and gameCamera or nil
				end

				if Face.Enabled and attacked[1] then
					local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
					entitylib.character.RootPart.CFrame = CFrame.lookAt(
						entitylib.character.RootPart.Position,
						Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.01, vec.Z)
					)
				end

				task.wait()
			until not Killaura.Enabled
		else
			for _, v in Boxes do
				v.Adornee = nil
			end
			for _, v in Particles do
				v.Parent = nil
			end
		end
	end,
	Tooltip = 'Attack players around you\nwithout aiming at them',
    })
    Targets = Killaura:CreateTargets({ Players = true })
    CPS = Killaura:CreateTwoSlider({
	Name = 'Attacks per Second',
	Min = 1,
	Max = 20,
	DefaultMin = 12,
	DefaultMax = 12,
    })
    SwingRange = Killaura:CreateSlider({
	Name = 'Swing range',
	Min = 1,
	Max = 30,
	Default = 18,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    AttackRange = Killaura:CreateSlider({
	Name = 'Attack range',
	Min = 1,
	Max = 30,
	Default = 18,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    AngleSlider = Killaura:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 90,
    })
    Max = Killaura:CreateSlider({
	Name = 'Max targets',
	Min = 1,
	Max = 10,
	Default = 10,
    })
    Mouse = Killaura:CreateToggle({ Name = 'Require mouse down' })
    Lunge = Killaura:CreateToggle({ Name = 'Sword lunge only' })
    Killaura:CreateToggle({
	Name = 'Show target',
	Function = function(callback)
		BoxSwingColor.Object.Visible = callback
		BoxAttackColor.Object.Visible = callback
		if callback then
			for i = 1, 10 do
				local box = Instance.new('BoxHandleAdornment')
				box.Adornee = nil
				box.AlwaysOnTop = true
				box.Size = Vector3.new(3, 5, 3)
				box.CFrame = CFrame.new(0, -0.5, 0)
				box.ZIndex = 0
				box.Parent = vape.gui
				Boxes[i] = box
			end
		else
			for _, v in Boxes do
				v:Destroy()
			end
			table.clear(Boxes)
		end
	end,
    })
    BoxSwingColor = Killaura:CreateColorSlider({
	Name = 'Target Color',
	Darker = true,
	DefaultOpacity = 0.5,
	Visible = false,
    })
    BoxAttackColor = Killaura:CreateColorSlider({
	Name = 'Attack Color',
	Darker = true,
	DefaultOpacity = 0.5,
	Visible = false,
    })
    Killaura:CreateToggle({
	Name = 'Target particles',
	Function = function(callback)
		ParticleTexture.Object.Visible = callback
		ParticleColor1.Object.Visible = callback
		ParticleColor2.Object.Visible = callback
		ParticleSize.Object.Visible = callback
		if callback then
			for i = 1, 10 do
				local part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 2)
				part.Anchored = true
				part.CanCollide = false
				part.Transparency = 1
				part.CanQuery = false
				part.Parent = Killaura.Enabled and gameCamera or nil
				local particles = Instance.new('ParticleEmitter')
				particles.Brightness = 1.5
				particles.Size = NumberSequence.new(ParticleSize.Value)
				particles.Shape = Enum.ParticleEmitterShape.Sphere
				particles.Texture = ParticleTexture.Value
				particles.Transparency = NumberSequence.new(0)
				particles.Lifetime = NumberRange.new(0.4)
				particles.Speed = NumberRange.new(16)
				particles.Rate = 128
				particles.Drag = 16
				particles.ShapePartial = 1
				particles.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(
						0,
						Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)
					),
					ColorSequenceKeypoint.new(
						1,
						Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value)
					),
				})
				particles.Parent = part
				Particles[i] = part
			end
		else
			for _, v in Particles do
				v:Destroy()
			end
			table.clear(Particles)
		end
	end,
    })
    ParticleTexture = Killaura:CreateTextBox({
	Name = 'Texture',
	Default = 'rbxassetid://14736249347',
	Function = function()
		for _, v in Particles do
			v.ParticleEmitter.Texture = ParticleTexture.Value
		end
	end,
	Darker = true,
	Visible = false,
    })
    ParticleColor1 = Killaura:CreateColorSlider({
	Name = 'Color Begin',
	Function = function(hue, sat, val)
		for _, v in Particles do
			v.ParticleEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
				ColorSequenceKeypoint.new(
					1,
					Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value)
				),
			})
		end
	end,
	Darker = true,
	Visible = false,
    })
    ParticleColor2 = Killaura:CreateColorSlider({
	Name = 'Color End',
	Function = function(hue, sat, val)
		for _, v in Particles do
			v.ParticleEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(
					0,
					Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)
				),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val)),
			})
		end
	end,
	Darker = true,
	Visible = false,
    })
    ParticleSize = Killaura:CreateSlider({
	Name = 'Size',
	Min = 0,
	Max = 1,
	Default = 0.2,
	Decimal = 100,
	Function = function(val)
		for _, v in Particles do
			v.ParticleEmitter.Size = NumberSequence.new(val)
		end
	end,
	Darker = true,
	Visible = false,
    })
    Face = Killaura:CreateToggle({ Name = 'Face target' })
end)

run(function()
    local NoFallDamage
    local Mode
    local hook
    local spoofFalling = false
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    rayCheck.RespectCanCollide = true

    local function removeHook()
	spoofFalling = false
	if hook then
		pcall(raknet.remove_send_hook, hook)
		hook = nil
	end
    end

    local function installHook()
	if hook then return true end
	if not rakNetCheck('NoFallDamage') then return false end
	hook = function(packet)
		if not spoofFalling then return end
		pcall(function()
			local data = packet.AsBuffer
			local packetId = packet.AsArray and packet.AsArray[1]
			if not packetId and data and buffer.len(data) > 0 then packetId = buffer.readu8(data, 0) end
			if packetId == 0x1b and data and buffer.len(data) >= 26 then
				buffer.writeu8(data, 25, Enum.HumanoidStateType.Landed.Value + 32)
				packet:SetData(data)
			end
		end)
	end
	raknet.add_send_hook(hook)
	return true
    end

    local function standClearance(character)
	return character.HipHeight
		or ((character.Humanoid and character.Humanoid.HipHeight or 2) + (character.RootPart.Size.Y * 0.5))
    end

    local function groundBelow(character, distance)
	local root = character.RootPart
	rayCheck.FilterDescendantsInstances = {character.Character, gameCamera}
	pcall(function() rayCheck.CollisionGroup = root.CollisionGroup end)
	local result = workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), rayCheck)
	return result and result.Normal.Y > 0.15 and result or nil
    end

    NoFallDamage = vape.Categories.Blatant:CreateModule({
	Name = 'NoFallDamage',
	Function = function(callback)
		if callback then
			if Mode.Value == 'State' and not installHook() then
				NoFallDamage:Toggle()
				return
			end

			NoFallDamage:Clean(runService.PostSimulation:Connect(function()
				if not entitylib.isAlive then
					spoofFalling = false
					return
				end

				local character = entitylib.character
				local root, humanoid = character.RootPart, character.Humanoid
				local velocity = root.AssemblyLinearVelocity
				local falling = humanoid.FloorMaterial == Enum.Material.Air and velocity.Y < -1
				spoofFalling = Mode.Value == 'State' and falling
				if not falling or Mode.Value == 'State' or velocity.Y > -20 then return end

				local ground = groundBelow(character, 2000)
				if not ground then return end
				local floorY = ground.Position.Y + standClearance(character)
				local remaining = root.Position.Y - floorY
				if remaining <= 1 then return end

				if Mode.Value == 'TP' and velocity.Y <= -55 then
					character.Character:PivotTo(root.CFrame - Vector3.new(0, remaining, 0))
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
					humanoid:ChangeState(Enum.HumanoidStateType.Landed)
				elseif Mode.Value == 'Velocity' and velocity.Y <= -45 then
					local impactTime = remaining / math.max(math.abs(velocity.Y), 1)
					if remaining <= 8 or impactTime <= 0.2 then
						root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, -18), velocity.Z)
					end
				end
			end))
		else
			removeHook()
		end
	end,
	ExtraText = function() return Mode.Value end,
	Tooltip = 'Prevents universal fall damage with a ground teleport, impact slowdown, or landed-state spoof',
    })
    Mode = NoFallDamage:CreateDropdown({
	Name = 'Mode',
	List = {'TP', 'Velocity', 'State'},
	Default = 'TP',
	Function = function()
		if NoFallDamage.Enabled then
			NoFallDamage:Toggle()
			NoFallDamage:Toggle()
		end
	end,
    })
    vape:Clean(removeHook)
end)

run(function()
    local Step
    local Mode
    local StepHeight
	local ExtraHeight
    local activeTween
    local busy = false
    local nextStep = 0

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    rayCheck.RespectCanCollide = true
    local overlapCheck = OverlapParams.new()
    overlapCheck.FilterType = Enum.RaycastFilterType.Exclude
    overlapCheck.RespectCanCollide = true

    local function clearance(character)
	return character.HipHeight
		or ((character.Humanoid and character.Humanoid.HipHeight or 2) + (character.RootPart.Size.Y * 0.5))
    end

    local function findStep(character)
	local root, humanoid = character.RootPart, character.Humanoid
	local direction = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.05 or humanoid.FloorMaterial == Enum.Material.Air then return nil end
	direction = direction.Unit

	rayCheck.FilterDescendantsInstances = {character.Character, gameCamera}
	pcall(function() rayCheck.CollisionGroup = root.CollisionGroup end)
	local standHeight = clearance(character)
	local ground = workspace:Raycast(
		root.Position + Vector3.new(0, 0.5, 0),
		Vector3.new(0, -(standHeight + 3), 0),
		rayCheck
	)
	if not ground or ground.Normal.Y <= 0.15 then return nil end

	local castHeight = math.max(root.Size.Y, 2)
	local wallOrigin = root.Position - Vector3.new(0, math.max(standHeight - (castHeight * 0.5), 0), 0)
	local wall = workspace:Blockcast(
		CFrame.new(wallOrigin),
		Vector3.new(math.max(root.Size.X * 0.8, 1.4), castHeight, math.max(root.Size.Z * 0.8, 1.4)),
		direction * 2.75,
		rayCheck
	)
	if not wall or math.abs(wall.Normal.Y) > 0.25 then return nil end

	local wallNormal = wall.Normal * Vector3.new(1, 0, 1)
	if wallNormal.Magnitude < 0.1 then return nil end
	wallNormal = wallNormal.Unit
	local sample = wall.Position - (wallNormal * 0.75)
	local top = workspace:Raycast(
		Vector3.new(sample.X, ground.Position.Y + StepHeight.Value + 3, sample.Z),
		Vector3.new(0, -(StepHeight.Value + 4), 0),
		rayCheck
	)
	if not top or top.Normal.Y <= 0.15 then return nil end

	local height = top.Position.Y - ground.Position.Y
	if height <= 0.1 or height > StepHeight.Value + 0.05 then return nil end
	local landing = wall.Position - (wallNormal * (math.max(root.Size.X, root.Size.Z) * 0.55 + 0.65))
	local target = Vector3.new(landing.X, top.Position.Y + standHeight, landing.Z)

	overlapCheck.FilterDescendantsInstances = {character.Character, top.Instance}
	pcall(function() overlapCheck.CollisionGroup = root.CollisionGroup end)
	local occupied = workspace:GetPartBoundsInBox(
		CFrame.new(target),
		Vector3.new(math.max(root.Size.X * 0.85, 1.5), math.max(root.Size.Y * 0.9, 1.8), math.max(root.Size.Z * 0.85, 1.5)),
		overlapCheck
	)
	for _, part in ipairs(occupied) do
		if part.CanCollide then return nil end
	end
	return target, height
    end

    local function clearMotion()
	busy = false
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
    end

	local function jumpVelocity(height)
		return math.sqrt(2 * workspace.Gravity * math.max(height, 0.1))
	end

    Step = vape.Categories.Blatant:CreateModule({
	Name = 'Step',
	Function = function(callback)
		if callback then
			nextStep = 0
			Step:Clean(clearMotion)
			Step:Clean(runService.PreSimulation:Connect(function()
				if busy or tick() < nextStep or not entitylib.isAlive then return end
				local character = entitylib.character
				local target, height = findStep(character)
				if not target then return end

				local root, humanoid = character.RootPart, character.Humanoid
				local rotation = root.CFrame.Rotation
				nextStep = tick() + 0.2
				if Mode.Value == 'TP' then
					character.Character:PivotTo(CFrame.new(target) * rotation)
					local velocity = root.AssemblyLinearVelocity
					-- Pivoting gets the character onto the surface; the derived vertical velocity then
					-- clears its lip by the requested margin instead of relying on a fixed JumpPower
					-- that is too small for tall walls and excessive for short ones.
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, jumpVelocity(ExtraHeight.Value)), velocity.Z)
				elseif Mode.Value == 'Glide' then
					busy = true
					activeTween = tweenService:Create(
						root,
						TweenInfo.new(math.clamp(height / 18, 0.12, 0.45), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{CFrame = CFrame.new(target) * rotation}
					)
					activeTween.Completed:Once(function()
						activeTween = nil
						busy = false
					end)
					activeTween:Play()
				else
					busy = true
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					humanoid.Jump = true
					local velocity = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, jumpVelocity(height + ExtraHeight.Value), velocity.Z)
					task.delay(0.25, function() busy = false end)
				end
			end))
		else
			clearMotion()
		end
	end,
	ExtraText = function() return Mode.Value end,
	Tooltip = 'Moves onto walls only when their top is within the configured height above the real ground',
    })
    Mode = Step:CreateDropdown({
	Name = 'Mode',
	List = {'TP', 'Glide', 'Jump'},
	Default = 'TP',
	Function = function(value)
		if ExtraHeight and ExtraHeight.Object then ExtraHeight.Object.Visible = value ~= 'Glide' end
	end,
    })
    StepHeight = Step:CreateSlider({
	Name = 'Step height',
	Min = 1,
	Max = 50,
	Default = 20,
	Suffix = function(value) return value == 1 and 'stud' or 'studs' end,
    })
    ExtraHeight = Step:CreateSlider({
	Name = 'Extra height',
	Min = 0,
	Max = 15,
	Default = 5,
	Darker = true,
	Visible = function() return Mode and Mode.Value ~= 'Glide' end,
	Suffix = function(value) return value == 1 and 'stud' or 'studs' end,
	Tooltip = 'Additional apex clearance above the detected wall; jump velocity is calculated automatically',
    })
end)

run(function()
    local Mode
    local Value
    local AutoDisable

    LongJump = vape.Categories.Blatant:CreateModule({
	Name = 'LongJump',
	Function = function(callback)
		if callback then
			local exempt = tick() + 0.1
			LongJump:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
						if exempt < tick() and AutoDisable.Enabled then
							if LongJump.Enabled then
								LongJump:Toggle()
							end
						else
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end

					local root = entitylib.character.RootPart
					local dir = entitylib.character.Humanoid.MoveDirection * Value.Value
					if Mode.Value == 'Velocity' then
						root.AssemblyLinearVelocity = dir + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
					elseif Mode.Value == 'Impulse' then
						local diff = (dir - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
						if diff.Magnitude > (dir == Vector3.zero and 10 or 2) then
							root:ApplyImpulse(diff * root.AssemblyMass)
						end
					else
						root.CFrame += dir * dt
					end
				end
			end))
		end
	end,
	ExtraText = function()
		return Mode.Value
	end,
	Tooltip = 'Lets you jump farther',
    })
    Mode = LongJump:CreateDropdown({
	Name = 'Mode',
	List = { 'Velocity', 'Impulse', 'CFrame' },
	Tooltip = 'Velocity - smooth physics\nImpulse - the same using forces\nCFrame - moves the root directly',
    })
    Value = LongJump:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    AutoDisable = LongJump:CreateToggle({
	Name = 'Auto Disable',
	Default = true,
    })
end)

run(function()
    local MouseTP
    local Mode
    local Target
    local TravelGaps
    local navigation
    local generation = 0
    local markers = {}
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.RespectCanCollide = true

    local function alive()
        return entitylib.isAlive and entitylib.character and entitylib.character.RootPart and entitylib.character.Humanoid
    end

    local function cleanupMarkers()
        for _, marker in markers do pcall(marker.Destroy, marker) end
        table.clear(markers)
    end

    local function stopNavigation()
        generation += 1
        navigation = nil
        cleanupMarkers()
        if entitylib.isAlive and entitylib.character.Humanoid then
            pcall(entitylib.character.Humanoid.MoveTo, entitylib.character.Humanoid, entitylib.character.RootPart.Position)
        end
    end

    local function disableSoon(message)
        if message then notif('MouseTP', message, 4, 'warning') end
        task.defer(function() if MouseTP.Enabled then MouseTP:Toggle() end end)
    end

    local function floorAt(position, root)
        ray.FilterDescendantsInstances = {lplr.Character, gameCamera}
        local result = workspace:Raycast(position + Vector3.new(0, 2.5, 0), Vector3.new(0, -9, 0), ray)
        return result and result.Instance.CanCollide and result or nil
    end

    local function standingSpace(position, root)
        ray.FilterDescendantsInstances = {lplr.Character, gameCamera}
        return workspace:Raycast(position + Vector3.new(0, 1.2, 0), Vector3.new(0, 4.3, 0), ray) == nil
    end

    local function segmentClear(a, b)
        ray.FilterDescendantsInstances = {lplr.Character, gameCamera}
        local delta = b - a
        if delta.Magnitude < 0.05 then return true end
        local chest = a + Vector3.new(0, 1.6, 0)
        local hit = workspace:Raycast(chest, Vector3.new(delta.X, math.min(delta.Y, 1.5), delta.Z), ray)
        return hit == nil
    end

    local function copyWaypoints(path)
        local out = {}
        for _, waypoint in path:GetWaypoints() do
            table.insert(out, {Position = waypoint.Position, Action = waypoint.Action})
        end
        return out
    end

    local function routeTime(points)
        local total = 0
        for i = 2, #points do
            local delta = points[i].Position - points[i - 1].Position
            total += Vector3.new(delta.X, 0, delta.Z).Magnitude / 16
            if delta.Y > 2.6 or points[i].Action == Enum.PathWaypointAction.Jump then total += 0.22 end
            if delta.Y < -4 then total += math.min(math.abs(delta.Y) / 45, 0.45) end
        end
        return total
    end

    local function normalizeRoute(points, allowGap)
        if not points or #points < 2 then return nil end
        local cleaned = {points[1]}
        for i = 2, #points do
            local previous = cleaned[#cleaned]
            local current = points[i]
            local delta = current.Position - previous.Position
            local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
            -- Reject only genuinely impossible vertical moves. Ordinary stairs, one/two-block
            -- jumps and natural drops are left to the Humanoid instead of being over-validated.
            if delta.Y > 7.4 and horizontal < 4.5 then return nil end
            local floor = floorAt(current.Position, entitylib.character.RootPart)
            if not floor and not allowGap and i < #points then return nil end
            if not standingSpace(current.Position, entitylib.character.RootPart) and i < #points then return nil end
            table.insert(cleaned, current)
        end
        return cleaned
    end

    local function computeCandidate(startPos, destination, params, allowGap)
        local path = pathfindingService:CreatePath(params)
        local ok = pcall(path.ComputeAsync, path, startPos, destination)
        if not ok or path.Status ~= Enum.PathStatus.Success then return nil end
        local points = normalizeRoute(copyWaypoints(path), allowGap)
        if not points then return nil end
        return {Waypoints = points, Time = routeTime(points)}
    end

    local function directCandidate(startPos, destination, allowGap)
        if not segmentClear(startPos, destination) then return nil end
        local points = normalizeRoute({
            {Position = startPos, Action = Enum.PathWaypointAction.Walk},
            {Position = destination, Action = Enum.PathWaypointAction.Walk}
        }, allowGap)
        return points and {Waypoints = points, Time = routeTime(points)} or nil
    end

    local function findRoute(startPos, destination)
        local candidates = {}
        local function add(candidate) if candidate then table.insert(candidates, candidate) end end
        -- Try direct movement first because it is frequently faster than Roblox's conservative path.
        add(directCandidate(startPos, destination, false))
        local profiles = {
            {AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 3},
            {AgentRadius = 1.6, AgentHeight = 4.5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 2},
            {AgentRadius = 1.2, AgentHeight = 4, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 2}
        }
        for _, profile in profiles do add(computeCandidate(startPos, destination, profile, false)) end
        if #candidates == 0 and TravelGaps.Enabled then
            add(directCandidate(startPos, destination, true))
            for _, profile in profiles do add(computeCandidate(startPos, destination, profile, true)) end
        end
        table.sort(candidates, function(a, b) return a.Time < b.Time end)
        return candidates[1]
    end

    local function drawRoute(points)
        cleanupMarkers()
        for index = 2, #points do
            local part = Instance.new('Part')
            part.Name = 'AetherMouseTPPath'
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Material = Enum.Material.Neon
            part.Transparency = 0.45
            part.Size = Vector3.new(1.8, 0.08, 1.8)
            part.CFrame = CFrame.new(points[index].Position - Vector3.new(0, 2.65, 0))
            part.Parent = workspace
            table.insert(markers, part)
        end
    end

    local function gapSupport(root, target)
        if floorAt(root.Position, root) then return end
        -- Built-in AirWalk style support: hold vertical velocity while keeping horizontal
        -- Humanoid movement intact. No permanent platform/part is created.
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, -0.5), velocity.Z)
        if target and target.Y > root.Position.Y + 1.5 then
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(root.AssemblyLinearVelocity.Y, 18), velocity.Z)
        end
    end

    local function travel(destination)
        if not alive() then disableSoon('You must be alive to use MouseTP.'); return end
        generation += 1
        local myGeneration = generation
        local root, humanoid = entitylib.character.RootPart, entitylib.character.Humanoid
        local route = findRoute(root.Position, destination)
        if not route then
            disableSoon(TravelGaps.Enabled and 'No viable route was found.' or 'No grounded route was found. Enable Travel over gaps if needed.')
            return
        end
        navigation = {Destination = destination, Waypoints = route.Waypoints, Index = 2, LastProgress = tick(), LastDistance = math.huge, LastRepath = 0}
        drawRoute(route.Waypoints)

        MouseTP:Clean(runService.Heartbeat:Connect(function()
            if myGeneration ~= generation or not MouseTP.Enabled or not alive() or not navigation then return end
            root, humanoid = entitylib.character.RootPart, entitylib.character.Humanoid
            local dest = navigation.Destination
            if (root.Position - dest).Magnitude <= 2.6 then
                root.CFrame = CFrame.new(dest) * root.CFrame.Rotation
                stopNavigation(); disableSoon(); return
            end
            local point = navigation.Waypoints[navigation.Index]
            if not point then
                if tick() - navigation.LastRepath > 0.25 then
                    navigation.LastRepath = tick()
                    local replanned = findRoute(root.Position, dest)
                    if replanned then navigation.Waypoints, navigation.Index = replanned.Waypoints, 2; drawRoute(replanned.Waypoints) end
                end
                return
            end
            local delta = point.Position - root.Position
            local distance = delta.Magnitude
            if distance <= 2.4 then
                navigation.Index += 1
                navigation.LastProgress, navigation.LastDistance = tick(), math.huge
                return
            end
            if distance < navigation.LastDistance - 0.08 then
                navigation.LastDistance, navigation.LastProgress = distance, tick()
            elseif tick() - navigation.LastProgress > 0.85 and tick() - navigation.LastRepath > 0.35 then
                navigation.LastRepath = tick()
                local replanned = findRoute(root.Position, dest)
                if replanned then navigation.Waypoints, navigation.Index = replanned.Waypoints, 2; navigation.LastProgress = tick(); drawRoute(replanned.Waypoints) end
            end
            if point.Action == Enum.PathWaypointAction.Jump or point.Position.Y > root.Position.Y + 2.2 then
                humanoid.Jump = true
            end
            if TravelGaps.Enabled then gapSupport(root, point.Position) end
            humanoid:MoveTo(Vector3.new(point.Position.X, root.Position.Y, point.Position.Z))
        end))
    end

    MouseTP = vape.Categories.Blatant:CreateModule({
        Name = 'MouseTP',
        Function = function(callback)
            if not callback then stopNavigation(); return end
            if not alive() then disableSoon('You must be alive to use MouseTP.'); return end
            local mouse = lplr:GetMouse()
            local hit = mouse and mouse.Hit
            if not hit then disableSoon('No target position found.'); return end
            local destination = hit.Position
            if Mode.Value == 'TP' then
                entitylib.character.RootPart.CFrame = CFrame.new(destination + Vector3.new(0, 3, 0)) * entitylib.character.RootPart.CFrame.Rotation
                disableSoon(); return
            end
            travel(destination + Vector3.new(0, 2.8, 0))
        end,
        Tooltip = 'Moves to the clicked point. Legit chooses the fastest viable path and only rejects genuinely impossible routes.'
    })
    Mode = MouseTP:CreateDropdown({Name = 'Mode', List = {'Legit', 'TP'}, Default = 'TP', Function = function(value)
        if TravelGaps and TravelGaps.Object then TravelGaps.Object.Visible = value == 'Legit' end
        if navigation and value ~= 'Legit' then stopNavigation() end
    end})
    TravelGaps = MouseTP:CreateToggle({Name = 'Travel over gaps', Darker = true, Visible = function() return Mode and Mode.Value == 'Legit' end, Tooltip = 'Uses temporary vertical support only when a grounded route is unavailable.'})
end)

run(function()
    local Mode
    local StudLimit = { Object = {} }
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local overlapCheck = OverlapParams.new()
    overlapCheck.MaxParts = 9e9
    local modified, fflag = {}
    local teleported

    local function grabClosestNormal(ray)
	local partCF, mag, closest = ray.Instance.CFrame, 0, Enum.NormalId.Top
	for _, normal in Enum.NormalId:GetEnumItems() do
		local dot = partCF:VectorToWorldSpace(Vector3.fromNormalId(normal)):Dot(ray.Normal)
		if dot > mag then
			mag, closest = dot, normal
		end
	end
	return Vector3.fromNormalId(closest).X ~= 0 and 'X' or 'Z'
    end

    local Functions = {
	Part = function()
		local chars = { gameCamera, lplr.Character }
		for _, v in entitylib.List do
			table.insert(chars, v.Character)
		end
		overlapCheck.FilterDescendantsInstances = chars

		local parts = workspace:GetPartBoundsInBox(
			entitylib.character.RootPart.CFrame + Vector3.new(0, 1, 0),
			entitylib.character.RootPart.Size + Vector3.new(1, entitylib.character.HipHeight, 1),
			overlapCheck
		)
		for _, part in parts do
			if part.CanCollide and (not Spider.Enabled or SpiderShift) then
				modified[part] = true
				part.CanCollide = false
			end
		end

		for part in modified do
			if not table.find(parts, part) then
				modified[part] = nil
				part.CanCollide = true
			end
		end
	end,
	Character = function()
		for _, part in lplr.Character:GetDescendants() do
			if part:IsA('BasePart') and part.CanCollide and (not Spider.Enabled or SpiderShift) then
				modified[part] = true
				part.CanCollide = Spider.Enabled and not SpiderShift
			end
		end
	end,
	CFrame = function()
		local chars = { gameCamera, lplr.Character }
		for _, v in entitylib.List do
			table.insert(chars, v.Character)
		end
		rayCheck.FilterDescendantsInstances = chars
		overlapCheck.FilterDescendantsInstances = chars

		local ray = workspace:Raycast(
			entitylib.character.Head.CFrame.Position,
			entitylib.character.Humanoid.MoveDirection * 1.1,
			rayCheck
		)
		if ray and (not Spider.Enabled or SpiderShift) then
			local phaseDirection = grabClosestNormal(ray)
			if ray.Instance.Size[phaseDirection] <= StudLimit.Value then
				local root = entitylib.character.RootPart
				local dest = root.CFrame + (ray.Normal * (-ray.Instance.Size[phaseDirection] - (root.Size.X / 1.5)))

				if #workspace:GetPartBoundsInBox(dest, Vector3.one, overlapCheck) <= 0 then
					if Mode.Value == 'Motor' then
						motorMove(root, dest)
					else
						root.CFrame = dest
					end
				end
			end
		end
	end,
	FFlag = function()
		if teleported then
			return
		end
		setfflag('AssemblyExtentsExpansionStudHundredth', '-10000')
		fflag = true
	end,
    }
    Functions.Motor = Functions.CFrame

    Phase = vape.Categories.Blatant:CreateModule({
	Name = 'NoClip',
	Function = function(callback)
		if callback then
			Phase:Clean(runService.Stepped:Connect(function()
				if entitylib.isAlive then
					Functions[Mode.Value]()
				end
			end))

			if Mode.Value == 'FFlag' then
				Phase:Clean(lplr.OnTeleport:Connect(function()
					teleported = true
					setfflag('AssemblyExtentsExpansionStudHundredth', '30')
				end))
			end
		else
			if fflag then
				setfflag('AssemblyExtentsExpansionStudHundredth', '30')
			end
			for part in modified do
				part.CanCollide = true
			end
			table.clear(modified)
			fflag = nil
		end
	end,
	Tooltip = 'Lets you Phase/Clip through walls. (Hold shift to use No Clip over spider)',
    })
    Mode = Phase:CreateDropdown({
	Name = 'Mode',
	List = { 'Part', 'Character', 'CFrame', 'Motor', 'FFlag' },
	Function = function(val)
		StudLimit.Object.Visible = val == 'CFrame' or val == 'Motor'
		if fflag then
			setfflag('AssemblyExtentsExpansionStudHundredth', '30')
		end
		for part in modified do
			part.CanCollide = true
		end
		table.clear(modified)
		fflag = nil
	end,
	Tooltip = 'Part - nearby parts\nCharacter - local collisions\nCFrame - teleport past\nMotor - CFrame with bypass\nFFlag - all physics',
    })
    StudLimit = Phase:CreateSlider({
	Name = 'Wall Size',
	Min = 1,
	Max = 20,
	Default = 5,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
	Darker = true,
	Visible = false,
    })
end)

run(function()
    local Speed
	local CustomProperties
    local Mode
    local Options
    local AutoJump
    local AutoJumpCustom
    local AutoJumpValue
    local w, s, a, d = 0, 0, 0, 0

    Speed = vape.Categories.Blatant:CreateModule({
	Name = 'Speed',
	Function = function(callback)
		frictionTable.Speed = callback and CustomProperties.Enabled or nil
		updateVelocity()
		if callback then
			Speed:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive and not Fly.Enabled and not LongJump.Enabled then
					local state = entitylib.character.Humanoid:GetState()
					if state == Enum.HumanoidStateType.Climbing then
						return
					end

					local movevec = TargetStrafeVector
						or Options.MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s))
						or entitylib.character.Humanoid.MoveDirection
					SpeedMethods[Mode.Value](Options, movevec, dt)
					if
						AutoJump.Enabled
						and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air
						and movevec ~= Vector3.zero
					then
						if AutoJumpCustom.Enabled then
							local velocity = entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)
							entitylib.character.RootPart.Velocity =
								Vector3.new(velocity.X, AutoJumpValue.Value, velocity.Z)
						else
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end
			end))

			w, s, a, d =
				inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0,
				inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0,
				inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0,
				inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
			for _, v in { 'InputBegan', 'InputEnded' } do
				Speed:Clean(inputService[v]:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.W then
							w = v == 'InputBegan' and -1 or 0
						elseif input.KeyCode == Enum.KeyCode.S then
							s = v == 'InputBegan' and 1 or 0
						elseif input.KeyCode == Enum.KeyCode.A then
							a = v == 'InputBegan' and -1 or 0
						elseif input.KeyCode == Enum.KeyCode.D then
							d = v == 'InputBegan' and 1 or 0
						end
					end
				end))
			end
		else
			if Options.WalkSpeed and entitylib.isAlive then
				entitylib.character.Humanoid.WalkSpeed = Options.WalkSpeed
			end
			Options.WalkSpeed = nil
		end
	end,
	ExtraText = function()
		return Mode.Value
	end,
	Tooltip = 'Increases your movement with various methods',
    })
    Mode = Speed:CreateDropdown({
	Name = 'Mode',
	List = SpeedMethodList,
	Function = function(val)
		Options.WallCheck.Object.Visible = val == 'CFrame' or val == 'TP'
		Options.TPFrequency.Object.Visible = val == 'TP'
		Options.PulseLength.Object.Visible = val == 'Pulse'
		Options.PulseDelay.Object.Visible = val == 'Pulse'
		if Speed.Enabled then
			Speed:Toggle()
			Speed:Toggle()
		end
	end,
	Tooltip = 'Velocity/Impulse - physics\nCFrame - root\nTP - large teleports\nPulse - speed bursts\nWalkSpeed - classic, detected',
    })
    Options = {
	MoveMethod = Speed:CreateDropdown({
		Name = 'Move Mode',
		List = { 'MoveDirection', 'Direct' },
		Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector',
	}),
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
	}),
	TPFrequency = Speed:CreateSlider({
		Name = 'TP Frequency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
	}),
	PulseLength = Speed:CreateSlider({
		Name = 'Pulse Length',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
	}),
	PulseDelay = Speed:CreateSlider({
		Name = 'Pulse Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
	}),
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true,
		Darker = true,
		Visible = false,
	}),
	TPTiming = tick(),
	rayCheck = RaycastParams.new(),
    }
    Options.rayCheck.RespectCanCollide = true
    CustomProperties = Speed:CreateToggle({
	Name = 'Custom Properties',
	Function = function()
		if Speed.Enabled then
			Speed:Toggle()
			Speed:Toggle()
		end
	end,
	Default = true,
    })
    AutoJump = Speed:CreateToggle({
	Name = 'AutoJump',
	Function = function(callback)
		AutoJumpCustom.Object.Visible = callback
	end,
    })
    AutoJumpCustom = Speed:CreateToggle({
	Name = 'Custom Jump',
	Function = function(callback)
		AutoJumpValue.Object.Visible = callback
	end,
	Tooltip = 'Allows you to adjust the jump power',
	Darker = true,
	Visible = false,
    })
    AutoJumpValue = Speed:CreateSlider({
	Name = 'Jump Power',
	Min = 1,
	Max = 50,
	Default = 30,
	Darker = true,
	Visible = false,
    })
end)

run(function()
    local Mode
    local Value
    local State
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local Active, Truss

    Spider = vape.Categories.Blatant:CreateModule({
	Name = 'Spider',
	Function = function(callback)
		if callback then
			if Truss then
				Truss.Parent = gameCamera
			end
			Spider:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local chars = { gameCamera, lplr.Character, Truss }
					for _, v in entitylib.List do
						table.insert(chars, v.Character)
					end
					SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
					rayCheck.FilterDescendantsInstances = chars
					rayCheck.CollisionGroup = root.CollisionGroup

					if Mode.Value ~= 'Part' then
						local vec = entitylib.character.Humanoid.MoveDirection * 2.5
						local ray = workspace:Raycast(
							root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0),
							vec,
							rayCheck
						)
						if Active and not ray then
							root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
						end

						Active = ray
						if Active and ray.Normal.Y == 0 then
							if not Phase.Enabled or not SpiderShift then
								if State.Enabled then
									entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
								end

								root.Velocity *= Vector3.new(1, 0, 1)
								if Mode.Value == 'CFrame' then
									root.CFrame += Vector3.new(0, Value.Value * dt, 0)
								elseif Mode.Value == 'Impulse' then
									root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
								else
									root.Velocity += Vector3.new(0, Value.Value, 0)
								end
							end
						end
					else
						local ray = workspace:Raycast(
							root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0),
							entitylib.character.RootPart.CFrame.LookVector * 2,
							rayCheck
						)
						if ray and (not Phase.Enabled or not SpiderShift) then
							Truss.Position = ray.Position - ray.Normal * 0.9 or Vector3.zero
						else
							Truss.Position = Vector3.zero
						end
					end
				end
			end))
		else
			if Truss then
				Truss.Parent = nil
			end
			SpiderShift = false
		end
	end,
	Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)',
    })
    Mode = Spider:CreateDropdown({
	Name = 'Mode',
	List = { 'Velocity', 'Impulse', 'CFrame', 'Part' },
	Function = function(val)
		Value.Object.Visible = val ~= 'Part'
		State.Object.Visible = val ~= 'Part'
		if Truss then
			Truss:Destroy()
			Truss = nil
		end
		if val == 'Part' then
			Truss = Instance.new('TrussPart')
			Truss.Size = Vector3.new(2, 2, 2)
			Truss.Transparency = 1
			Truss.Anchored = true
			Truss.Parent = Spider.Enabled and gameCamera or nil
		end
	end,
	Tooltip = 'Velocity - smooth boost up\nCFrame - moves you up\nPart - a climbable part in front of you',
    })
    Value = Spider:CreateSlider({
	Name = 'Speed',
	Min = 0,
	Max = 100,
	Default = 30,
	Darker = true,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    State = Spider:CreateToggle({
	Name = 'Climb State',
	Darker = true,
    })
end)

run(function()
    local SpinBot
    local Mode
    local XToggle
    local YToggle
    local ZToggle
    local Value
    local AngularVelocity

    SpinBot = vape.Categories.Blatant:CreateModule({
	Name = 'SpinBot',
	Function = function(callback)
		if callback then
			SpinBot:Clean(runService.PreSimulation:Connect(function()
				if entitylib.isAlive then
					if Mode.Value == 'RotVelocity' then
						local originalRotVelocity = entitylib.character.RootPart.RotVelocity
						entitylib.character.Humanoid.AutoRotate = false
						entitylib.character.RootPart.RotVelocity = Vector3.new(
							XToggle.Enabled and Value.Value or originalRotVelocity.X,
							YToggle.Enabled and Value.Value or originalRotVelocity.Y,
							ZToggle.Enabled and Value.Value or originalRotVelocity.Z
						)
					elseif Mode.Value == 'CFrame' then
						local val = math.rad((tick() * (20 * Value.Value)) % 360)
						local x, y, z = entitylib.character.RootPart.CFrame:ToOrientation()
						entitylib.character.RootPart.CFrame = CFrame.new(entitylib.character.RootPart.Position)
							* CFrame.Angles(
								XToggle.Enabled and val or x,
								YToggle.Enabled and val or y,
								ZToggle.Enabled and val or z
							)
					elseif AngularVelocity then
						AngularVelocity.Parent = entitylib.isAlive and entitylib.character.RootPart
						AngularVelocity.MaxTorque = Vector3.new(
							XToggle.Enabled and math.huge or 0,
							YToggle.Enabled and math.huge or 0,
							ZToggle.Enabled and math.huge or 0
						)
						AngularVelocity.AngularVelocity = Vector3.new(Value.Value, Value.Value, Value.Value)
					end
				end
			end))
		else
			if entitylib.isAlive and Mode.Value == 'RotVelocity' then
				entitylib.character.Humanoid.AutoRotate = true
			end
			if AngularVelocity then
				AngularVelocity.Parent = nil
			end
		end
	end,
	Tooltip = 'Makes your character spin around in circles (does not work in first person)',
    })
    Mode = SpinBot:CreateDropdown({
	Name = 'Mode',
	List = { 'CFrame', 'RotVelocity', 'BodyMover' },
	Function = function(val)
		if AngularVelocity then
			AngularVelocity:Destroy()
			AngularVelocity = nil
		end
		AngularVelocity = val == 'BodyMover' and Instance.new('BodyAngularVelocity') or nil
	end,
    })
    Value = SpinBot:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 100,
	Default = 40,
    })
    XToggle = SpinBot:CreateToggle({ Name = 'Spin X' })
    YToggle = SpinBot:CreateToggle({
	Name = 'Spin Y',
	Default = true,
    })
    ZToggle = SpinBot:CreateToggle({ Name = 'Spin Z' })
end)

run(function()
    local Jesus
    local platform = Instance.new('Part')
    platform.Name = 'AetherJesusPlatform'
    platform.Anchored = true
    platform.CanCollide = true
    platform.CanQuery = false
    platform.CanTouch = false
    platform.Transparency = 1
    platform.Size = Vector3.new(6, 0.25, 6)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = false

    Jesus = vape.Categories.Blatant:CreateModule({
        Name = 'Jesus',
        Function = function(enabled)
            if enabled then
                platform.Parent = workspace
                Jesus:Clean(runService.PreSimulation:Connect(function()
                    if not entitylib.isAlive then
                        platform.CFrame = CFrame.new(0, -10000, 0)
                        return
                    end
                    local root = entitylib.character.RootPart
                    rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera, platform}
                    local result = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), rayParams)
                    if result and result.Material == Enum.Material.Water then
                        platform.CFrame = CFrame.new(root.Position.X, result.Position.Y - 0.15, root.Position.Z)
                    else
                        platform.CFrame = CFrame.new(0, -10000, 0)
                    end
                end))
            else
                platform.Parent = nil
            end
        end,
        Tooltip = 'Lets you walk on water'
    })
    vape:Clean(function() platform:Destroy() end)
end)

run(function()
    local TargetStrafe
    local Targets
    local SearchRange
    local StrafeRange
    local YFactor
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local module, old

    TargetStrafe = vape.Categories.Blatant:CreateModule({
	Name = 'TargetStrafe',
	Function = function(callback)
		if callback then
			if not module then
				local suc = pcall(function()
					module = require(lplr.PlayerScripts.PlayerModule).controls
				end)
				if not suc then
					module = {}
				end
			end

			old = module.moveFunction
			local flymod, ang, oldent = vape.Modules.Fly or { Enabled = false }
			module.moveFunction = function(self, vec, face)
				local wallcheck = Targets.Walls.Enabled
				local ent = not inputService:IsKeyDown(Enum.KeyCode.S)
					and entitylib.EntityPosition({
						Range = SearchRange.Value,
						Wallcheck = wallcheck,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
					})

				if ent then
					local root, targetPos = entitylib.character.RootPart, ent.RootPart.Position
					rayCheck.FilterDescendantsInstances = { lplr.Character, gameCamera, ent.Character }
					rayCheck.CollisionGroup = root.CollisionGroup

					if flymod.Enabled or workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck) then
						local factor, localPosition = 0, root.Position
						if ent ~= oldent then
							ang = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
						end
						local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
						local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
						local newPos = entityPos
							+ (CFrame.Angles(0, math.rad(ang), 0).LookVector * (StrafeRange.Value - yFactor))
						local startRay, endRay = entityPos, newPos

						if not wallcheck and workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck) then
							startRay, endRay =
								entityPos
									+ (
										CFrame.Angles(0, math.rad(ang), 0).LookVector
										* (entityPos - localPosition).Magnitude
									),
								entityPos
						end

						local ray = workspace:Blockcast(
							CFrame.new(startRay),
							Vector3.new(1, entitylib.character.HipHeight + (root.Size.Y / 2), 1),
							(endRay - startRay),
							rayCheck
						)
						if (localPosition - newPos).Magnitude < 3 or ray then
							factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
							if ray then
								newPos = ray.Position + (ray.Normal * 1.5)
								factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
							end
						end

						if not flymod.Enabled and not workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
							newPos = entityPos
							factor = 40
						end

						ang += factor % 360
						vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
						vec = vec == vec and vec or Vector3.zero
						TargetStrafeVector = vec
					else
						ent = nil
					end
				end

				TargetStrafeVector = ent and vec or nil
				oldent = ent
				return old(self, vec, face)
			end
		else
			if module and old then
				module.moveFunction = old
			end
			TargetStrafeVector = nil
		end
	end,
	Tooltip = 'Automatically strafes around the opponent',
    })
    Targets = TargetStrafe:CreateTargets({
	Players = true,
	Walls = true,
    })
    SearchRange = TargetStrafe:CreateSlider({
	Name = 'Search Range',
	Min = 1,
	Max = 30,
	Default = 24,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    StrafeRange = TargetStrafe:CreateSlider({
	Name = 'Strafe Range',
	Min = 1,
	Max = 30,
	Default = 18,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    YFactor = TargetStrafe:CreateSlider({
	Name = 'Y Factor',
	Min = 0,
	Max = 100,
	Default = 100,
	Suffix = '%',
    })
end)

-- Client-side time scale.  The base simulation tick still runs normally; values above one add
-- only the extra local physics time needed to reach the selected multiplier.
run(function()
	local Timer
	local Value
	local animationSpeeds = {}
	local stepPhysicsFailure

	local function scaleAnimations(scale)
		local character = entitylib and entitylib.character and entitylib.character.Character
		if not character then return end
		local humanoid = character:FindFirstChildOfClass('Humanoid')
		local animator = humanoid and humanoid:FindFirstChildOfClass('Animator')
		if not animator then return end

		for _, track in animator:GetPlayingAnimationTracks() do
			if animationSpeeds[track] == nil then
				animationSpeeds[track] = track.Speed
			end
			pcall(track.AdjustSpeed, track, animationSpeeds[track] * scale)
		end
	end

	local function restoreAnimations()
		for track, speed in animationSpeeds do
			pcall(function() track:AdjustSpeed(speed) end)
		end
		table.clear(animationSpeeds)
	end

	Timer = vape.Categories.Blatant:CreateModule({
		Name = 'Timer',
		Function = function(callback)
			if callback then
				-- StepPhysics is available to supported executors.  Pause and Run are
				-- PluginSecurity methods in Roblox clients, so calling them here caused the
				-- RenderStepped callback to error before Timer could take a single step.
				pcall(setfflag, 'SimEnableStepPhysics', 'True')
				pcall(setfflag, 'SimEnableStepPhysicsSelective', 'True')
				Timer:Clean(runService.RenderStepped:Connect(function(dt)
					local scale = math.max(Value.Value, 1)
					local root = entitylib.character and entitylib.character.RootPart
					if root and scale > 1 and not stepPhysicsFailure then
						local success, problem = pcall(workspace.StepPhysics, workspace, dt * (scale - 1), {root})
						if not success and not stepPhysicsFailure then
							stepPhysicsFailure = tostring(problem)
							warn('[AetherV2] Timer could not step local physics: '..stepPhysicsFailure)
						end
					end
					scaleAnimations(scale)
				end))
			else
				restoreAnimations()
				stepPhysicsFailure = nil
			end
		end,
		Tooltip = 'Change the client game simulation speed',
	})

	Value = Timer:CreateSlider({
		Name = 'Value',
		Min = 1,
		Max = 3,
		Default = 1,
		Decimal = 10,
	})
end)


run(function()
	local Wallhop
	local Offset
	local Mode
	local CameraTime
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	local cameraRestore
	local cameraTurn
	local timeout = 0

	local function updateCamera()
		if cameraRestore then
			gameCamera.CFrame = CFrame.new(
				gameCamera.CFrame.Position.X,
				gameCamera.CFrame.Position.Y,
				gameCamera.CFrame.Position.Z,
				unpack(cameraRestore, 4, cameraRestore.n)
			)
			cameraRestore = nil
		end
		if not cameraTurn then return false end

		local alpha = math.clamp((os.clock() - cameraTurn.StartedAt) / cameraTurn.Duration, 0, 1)
		-- Ease in and out so the turn has no visible snap at either end.  Apply only the
		-- incremental yaw, which preserves both the live camera position and player input.
		local progress = alpha * alpha * (3 - (2 * alpha))
		local delta = progress - cameraTurn.Progress
		if delta ~= 0 then
			gameCamera.CFrame *= CFrame.Angles(0, math.rad(cameraTurn.Offset * delta), 0)
			cameraTurn.Progress = progress
		end
		if alpha >= 1 then cameraTurn = nil end
		return cameraTurn ~= nil
	end

	local function doCheck()
		if updateCamera() then return end

		if not entitylib.isAlive then
			return
		end

		local hum = entitylib.character.Humanoid
		local root = entitylib.character.RootPart
		if hum.MoveDirection.Magnitude <= 0 then
			return
		end
		if root.AssemblyLinearVelocity.Y >= 0 or hum.FloorMaterial ~= Enum.Material.Air then
			return
		end

		params.CollisionGroup = root.CollisionGroup
		params.FilterDescendantsInstances = { lplr.Character }

		local parts = workspace:GetPartBoundsInBox(
			CFrame.new(root.Position - Vector3.new(0, entitylib.character.HipHeight / 2, 0)),
			Vector3.new(3, entitylib.character.HipHeight, 3),
			params
		)
		local wall = false

		for _, part in parts do
			if part:IsA('BasePart') and part.CanCollide then
				local pos = part:GetClosestPointOnSurface(root.Position)
				if root.Position.Y - pos.Y > root.Size.Y / 2 then
					wall = true
					break
				end
			end
		end

		if wall and os.clock() - timeout > 0.2 then
			-- The original logic only rotated the camera. Actually request a jump here.
			hum.Jump = true
			hum:ChangeState(Enum.HumanoidStateType.Jumping)

			if Mode.Value == 'Legit' then
				cameraTurn = {
					StartedAt = os.clock(),
					Duration = math.max(CameraTime.Value, 0.01),
					Offset = Offset.Value,
					Progress = 0
				}
			else
				cameraRestore = table.pack(gameCamera.CFrame:GetComponents())
				gameCamera.CFrame *= CFrame.Angles(0, math.rad(Offset.Value), 0)
			end
			timeout = os.clock()
		end
	end

	Wallhop = vape.Categories.Blatant:CreateModule({
		Name = 'Wallhop',
		Function = function(callback)
			if callback then
				if workspace.AuthorityMode == Enum.AuthorityMode.Server then
					Wallhop:Clean(runService:BindToSimulation(doCheck))
				else
					Wallhop:Clean(runService.RenderStepped:Connect(doCheck))
				end
			else
				cameraRestore = nil
				cameraTurn = nil
			end
		end,
		Tooltip = 'Automatically jumps and rotates the camera for wallhopping.'
	})

	Offset = Wallhop:CreateSlider({
		Name = 'Offset',
		Min = -45,
		Max = 45,
		Default = 45,
		Suffix = 'degrees'
	})
	Mode = Wallhop:CreateDropdown({
		Name = 'Mode',
		List = {'Instant', 'Legit'},
		Default = 'Instant',
		Function = function(value)
			if CameraTime and CameraTime.Object then CameraTime.Object.Visible = value == 'Legit' end
			if value ~= 'Legit' then cameraTurn = nil end
		end,
		Tooltip = 'Instant applies the offset for one frame. Legit turns the camera over the selected time.'
	})
	CameraTime = Wallhop:CreateSlider({
		Name = 'Camera Time',
		Min = 0.05,
		Max = 2,
		Default = 0.25,
		Decimal = 100,
		Suffix = 's',
		Visible = false,
		Tooltip = 'How long Legit mode takes to reach the wallhop camera angle.'
	})
end)


--[[
    Render
]]

run(function()
    local Arrows
    local Targets
    local Color
    local Teammates
    local Distance
    local DistanceLimit
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local function Added(ent)
	if not Targets.Players.Enabled and ent.Player then
		return
	end
	if not Targets.NPCs.Enabled and ent.NPC then
		return
	end
	if Teammates.Enabled and not ent.Targetable and not ent.Friend and not ent.Friend then
		return
	end
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	local arrow = Instance.new('ImageLabel')
	arrow.Size = UDim2.fromOffset(256, 256)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.BackgroundTransparency = 1
	arrow.BorderSizePixel = 0
	arrow.Visible = false
	arrow.Image = getcustomasset('aetherv2/assets/new/arrowmodule.png')
	arrow.ImageColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	arrow.Parent = Folder
	Reference[ent] = arrow
    end

    local function Removed(ent)
	local v = Reference[ent]
	if v then
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		Reference[ent] = nil
		v:Destroy()
	end
    end

    local function ColorFunc(hue, sat, val)
	local color = Color3.fromHSV(hue, sat, val)
	for ent, EntityArrow in Reference do
		EntityArrow.ImageColor3 = entitylib.getEntityColor(ent) or color
	end
    end

    local function Loop()
	for ent, arrow in Reference do
		if Distance.Enabled then
			local distance = entitylib.isAlive
					and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
				or math.huge
			if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
				arrow.Visible = false
				continue
			end
		end

		local _, rootVis = gameCamera:WorldToScreenPoint(ent.RootPart.Position)
		arrow.Visible = not rootVis
		if rootVis then
			continue
		end

		local dir = CFrame.lookAlong(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1))
			:PointToObjectSpace(ent.RootPart.Position)
		arrow.Rotation = math.deg(math.atan2(dir.Z, dir.X))
	end
    end

    Arrows = vape.Categories.Render:CreateModule({
	Name = 'Arrows',
	Function = function(callback)
		if callback then
			Arrows:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
			for _, v in entitylib.List do
				if Reference[v] then
					Removed(v)
				end
				Added(v)
			end
			Arrows:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
				if Reference[ent] then
					Removed(ent)
				end
				Added(ent)
			end))
			Arrows:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
				ColorFunc(Color.Hue, Color.Sat, Color.Value)
			end))
			Arrows:Clean(runService.RenderStepped:Connect(Loop))
		else
			for i in Reference do
				Removed(i)
			end
		end
	end,
	Tooltip = 'Draws arrows on screen when entities\nare out of your field of view',
    })
    Targets = Arrows:CreateTargets({
	Players = true,
	Function = function()
		if Arrows.Enabled then
			Arrows:Toggle()
			Arrows:Toggle()
		end
	end,
    })
    Color = Arrows:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if Arrows.Enabled then
			ColorFunc(hue, sat, val)
		end
	end,
    })
    Teammates = Arrows:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if Arrows.Enabled then
			Arrows:Toggle()
			Arrows:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities',
    })
    Distance = Arrows:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end,
    })
    DistanceLimit = Arrows:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false,
    })
end)

run(function()
    local Chams
    local Targets
    local Mode
    local FillColor
    local OutlineColor
    local FillTransparency
    local OutlineTransparency
    local Teammates
    local Walls
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local function Added(ent)
	if not Targets.Players.Enabled and ent.Player then
		return
	end
	if not Targets.NPCs.Enabled and ent.NPC then
		return
	end
	if Teammates.Enabled and not ent.Targetable and not ent.Friend then
		return
	end
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	if Mode.Value == 'Highlight' then
		local cham = Instance.new('Highlight')
		cham.Adornee = ent.Character
		cham.DepthMode = Enum.HighlightDepthMode[Walls.Enabled and 'AlwaysOnTop' or 'Occluded']
		cham.FillColor = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
		cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
		cham.FillTransparency = FillTransparency.Value
		cham.OutlineTransparency = OutlineTransparency.Value
		cham.Parent = Folder
		Reference[ent] = cham
	else
		local chams = {}
		for _, v in ent.Character:GetChildren() do
			if
				v:IsA('BasePart')
				and (
					ent.NPC
					or v.Name:find('Arm')
					or v.Name:find('Leg')
					or v.Name:find('Hand')
					or v.Name:find('Feet')
					or v.Name:find('Torso')
					or v.Name == 'Head'
				)
			then
				local box = Instance.new(v.Name == 'Head' and 'SphereHandleAdornment' or 'BoxHandleAdornment')
				if v.Name == 'Head' then
					box.Radius = 0.75
				else
					box.Size = v.Size
				end
				box.AlwaysOnTop = Walls.Enabled
				box.Adornee = v
				box.ZIndex = 0
				box.Transparency = FillTransparency.Value
				box.Color3 = entitylib.getEntityColor(ent)
					or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				box.Parent = Folder
				table.insert(chams, box)
			end
		end
		Reference[ent] = chams
	end
    end

    local function Removed(ent)
	if Reference[ent] then
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		if type(Reference[ent]) == 'table' then
			for _, v in Reference[ent] do
				v:Destroy()
			end
			table.clear(Reference[ent])
		else
			Reference[ent]:Destroy()
		end
		Reference[ent] = nil
	end
    end

    Chams = vape.Categories.Render:CreateModule({
	Name = 'Chams',
	Function = function(callback)
		if callback then
			Chams:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
			Chams:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
				if Reference[ent] then
					Removed(ent)
				end
				Added(ent)
			end))
			Chams:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
				for i, v in Reference do
					local color = entitylib.getEntityColor(i)
						or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
					if type(v) == 'table' then
						for _, v2 in v do
							v2.Color3 = color
						end
					else
						v.FillColor = color
					end
				end
			end))
			for _, v in entitylib.List do
				if Reference[v] then
					Removed(v)
				end
				Added(v)
			end
		else
			for i in Reference do
				Removed(i)
			end
		end
	end,
	Tooltip = 'Render players through walls',
    })
    Targets = Chams:CreateTargets({
	Players = true,
	Function = function()
		if Chams.Enabled then
			Chams:Toggle()
			Chams:Toggle()
		end
	end,
    })
    Mode = Chams:CreateDropdown({
	Name = 'Mode',
	List = { 'Highlight', 'BoxHandles' },
	Function = function(val)
		OutlineColor.Object.Visible = val == 'Highlight'
		OutlineTransparency.Object.Visible = val == 'Highlight'
		if Chams.Enabled then
			Chams:Toggle()
			Chams:Toggle()
		end
	end,
    })
    FillColor = Chams:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		for i, v in Reference do
			local color = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
			if type(v) == 'table' then
				for _, v2 in v do
					v2.Color3 = color
				end
			else
				v.FillColor = color
			end
		end
	end,
    })
    OutlineColor = Chams:CreateColorSlider({
	Name = 'Outline Color',
	DefaultSat = 0,
	Function = function(hue, sat, val)
		for i, v in Reference do
			if type(v) ~= 'table' then
				v.OutlineColor = Color3.fromHSV(hue, sat, val)
			end
		end
	end,
	Darker = true,
    })
    FillTransparency = Chams:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Function = function(val)
		for _, v in Reference do
			if type(v) == 'table' then
				for _, v2 in v do
					v2.Transparency = val
				end
			else
				v.FillTransparency = val
			end
		end
	end,
	Decimal = 10,
    })
    OutlineTransparency = Chams:CreateSlider({
	Name = 'Outline Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Function = function(val)
		for _, v in Reference do
			if type(v) ~= 'table' then
				v.OutlineTransparency = val
			end
		end
	end,
	Decimal = 10,
	Darker = true,
    })
    Walls = Chams:CreateToggle({
	Name = 'Render Walls',
	Function = function(callback)
		for _, v in Reference do
			if type(v) == 'table' then
				for _, v2 in v do
					v2.AlwaysOnTop = callback
				end
			else
				v.DepthMode = Enum.HighlightDepthMode[callback and 'AlwaysOnTop' or 'Occluded']
			end
		end
	end,
	Default = true,
    })
    Teammates = Chams:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if Chams.Enabled then
			Chams:Toggle()
			Chams:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities',
    })
end)

run(function()
    local ESP
    local Targets
    local Color
    local Method
    local BoundingBox
    local Filled
    local HealthBar
    local Name
    local DisplayName
    local Background
    local Teammates
    local Distance
    local DistanceLimit
    local Reference = {}
    local methodused

    local function ESPWorldToViewport(pos)
	local newpos =
		gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(gameCamera.CFrame:PointToObjectSpace(pos)))
	return Vector2.new(newpos.X, newpos.Y)
    end

    local ESPAdded = {
	Drawing2D = function(ent)
		if not Targets.Players.Enabled and ent.Player then
			return
		end
		if not Targets.NPCs.Enabled and ent.NPC then
			return
		end
		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
			return
		end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Main = Drawing.new('Square')
		EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
		EntityESP.Main.ZIndex = 2
		EntityESP.Main.Filled = false
		EntityESP.Main.Thickness = 1
		EntityESP.Main.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)

		if BoundingBox.Enabled then
			EntityESP.Border = Drawing.new('Square')
			EntityESP.Border.Transparency = 0.35
			EntityESP.Border.ZIndex = 1
			EntityESP.Border.Thickness = 1
			EntityESP.Border.Filled = false
			EntityESP.Border.Color = Color3.new()
			EntityESP.Border2 = Drawing.new('Square')
			EntityESP.Border2.Transparency = 0.35
			EntityESP.Border2.ZIndex = 1
			EntityESP.Border2.Thickness = 1
			EntityESP.Border2.Filled = Filled.Enabled
			EntityESP.Border2.Color = Color3.new()
		end

		if HealthBar.Enabled then
			EntityESP.HealthLine = Drawing.new('Line')
			EntityESP.HealthLine.Thickness = 1
			EntityESP.HealthLine.ZIndex = 2
			EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			EntityESP.HealthBorder = Drawing.new('Line')
			EntityESP.HealthBorder.Thickness = 3
			EntityESP.HealthBorder.Transparency = 0.35
			EntityESP.HealthBorder.ZIndex = 1
			EntityESP.HealthBorder.Color = Color3.new()
		end

		if Name.Enabled then
			if Background.Enabled then
				EntityESP.TextBKG = Drawing.new('Square')
				EntityESP.TextBKG.Transparency = 0.35
				EntityESP.TextBKG.ZIndex = 0
				EntityESP.TextBKG.Thickness = 1
				EntityESP.TextBKG.Filled = true
				EntityESP.TextBKG.Color = Color3.new()
			end
			EntityESP.Drop = Drawing.new('Text')
			EntityESP.Drop.Color = Color3.new()
			EntityESP.Drop.Text = ent.Player
					and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
				or ent.Character.Name
			EntityESP.Drop.ZIndex = 1
			EntityESP.Drop.Center = true
			EntityESP.Drop.Size = 20
			EntityESP.Text = Drawing.new('Text')
			EntityESP.Text.Text = EntityESP.Drop.Text
			EntityESP.Text.ZIndex = 2
			EntityESP.Text.Color = EntityESP.Main.Color
			EntityESP.Text.Center = true
			EntityESP.Text.Size = 20
		end
		Reference[ent] = EntityESP
	end,
	Drawing3D = function(ent)
		if not Targets.Players.Enabled and ent.Player then
			return
		end
		if not Targets.NPCs.Enabled and ent.NPC then
			return
		end
		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
			return
		end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Line1 = Drawing.new('Line')
		EntityESP.Line2 = Drawing.new('Line')
		EntityESP.Line3 = Drawing.new('Line')
		EntityESP.Line4 = Drawing.new('Line')
		EntityESP.Line5 = Drawing.new('Line')
		EntityESP.Line6 = Drawing.new('Line')
		EntityESP.Line7 = Drawing.new('Line')
		EntityESP.Line8 = Drawing.new('Line')
		EntityESP.Line9 = Drawing.new('Line')
		EntityESP.Line10 = Drawing.new('Line')
		EntityESP.Line11 = Drawing.new('Line')
		EntityESP.Line12 = Drawing.new('Line')

		local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		for _, v in EntityESP do
			v.Thickness = 1
			v.Color = color
		end

		Reference[ent] = EntityESP
	end,
	DrawingSkeleton = function(ent)
		if not Targets.Players.Enabled and ent.Player then
			return
		end
		if not Targets.NPCs.Enabled and ent.NPC then
			return
		end
		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
			return
		end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Head = Drawing.new('Line')
		EntityESP.HeadFacing = Drawing.new('Line')
		EntityESP.Torso = Drawing.new('Line')
		EntityESP.UpperTorso = Drawing.new('Line')
		EntityESP.LowerTorso = Drawing.new('Line')
		EntityESP.LeftArm = Drawing.new('Line')
		EntityESP.RightArm = Drawing.new('Line')
		EntityESP.LeftLeg = Drawing.new('Line')
		EntityESP.RightLeg = Drawing.new('Line')

		local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		for _, v in EntityESP do
			v.Thickness = 2
			v.Color = color
		end

		Reference[ent] = EntityESP
	end,
    }

    local ESPRemoved = {
	Drawing2D = function(ent)
		local EntityESP = Reference[ent]
		if EntityESP then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			for _, v in EntityESP do
				pcall(function()
					v.Visible = false
					v:Remove()
				end)
			end
		end
	end,
    }
    ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
    ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D

    local ESPUpdated = {
	Drawing2D = function(ent)
		local EntityESP = Reference[ent]
		if EntityESP then
			if vape.ThreadFix then
				setthreadidentity(8)
			end

			if EntityESP.HealthLine then
				EntityESP.HealthLine.Color =
					Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			end

			if EntityESP.Text then
				EntityESP.Text.Text = ent.Player
						and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
					or ent.Character.Name
				EntityESP.Drop.Text = EntityESP.Text.Text
			end
		end
	end,
    }

    local ColorFunc = {
	Drawing2D = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.Main.Color = entitylib.getEntityColor(i) or color
			if v.Text then
				v.Text.Color = v.Main.Color
			end
		end
	end,
	Drawing3D = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			local playercolor = entitylib.getEntityColor(i) or color
			for _, v2 in v do
				v2.Color = playercolor
			end
		end
	end,
    }
    ColorFunc.DrawingSkeleton = ColorFunc.Drawing3D

    local ESPLoop = {
	Drawing2D = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive
						and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
					or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then
				continue
			end

			-- Project the top and bottom of the character on the world Y axis.  The old
			-- calculation offset opposite corners on the camera X axis and then used the
			-- signed difference as the size.  Its width consequently changed with camera
			-- angle (and could be negative), making boxes drift far away from their target.
			local halfHeight = math.max(ent.HipHeight + 1, 2.5)
			local topPos = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, halfHeight, 0))
			local bottomPos = gameCamera:WorldToViewportPoint(ent.RootPart.Position - Vector3.new(0, halfHeight, 0))
			local sizey = math.max(math.abs(bottomPos.Y - topPos.Y), 2)
			local sizex = math.max(sizey * 0.5, 2)
			local posx, posy = rootPos.X - (sizex / 2), math.min(topPos.Y, bottomPos.Y)
			EntityESP.Main.Position = Vector2.new(posx, posy) // 1
			EntityESP.Main.Size = Vector2.new(sizex, sizey) // 1
			if EntityESP.Border then
				EntityESP.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
				EntityESP.Border.Size = Vector2.new(sizex + 2, sizey - 2) // 1
				EntityESP.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
				EntityESP.Border2.Size = Vector2.new(sizex - 2, sizey + 2) // 1
			end

			if EntityESP.HealthLine then
				local healthposy = sizey * math.clamp(ent.Health / ent.MaxHealth, 0, 1)
				EntityESP.HealthLine.Visible = ent.Health > 0
				EntityESP.HealthLine.From = Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))) // 1
				EntityESP.HealthLine.To = Vector2.new(posx - 6, posy) // 1
				EntityESP.HealthBorder.From = Vector2.new(posx - 6, posy + 1) // 1
				EntityESP.HealthBorder.To = Vector2.new(posx - 6, (posy + sizey) - 1) // 1
			end

			if EntityESP.Text then
				EntityESP.Text.Position = Vector2.new(posx + (sizex / 2), posy + (sizey - 28)) // 1
				EntityESP.Drop.Position = EntityESP.Text.Position + Vector2.new(1, 1)
				if EntityESP.TextBKG then
					EntityESP.TextBKG.Size = EntityESP.Text.TextBounds + Vector2.new(8, 4)
					EntityESP.TextBKG.Position = EntityESP.Text.Position
						- Vector2.new(4 + (EntityESP.Text.TextBounds.X / 2), 0)
				end
			end
		end
	end,
	Drawing3D = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive
						and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
					or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then
				continue
			end

			local point1 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, 1.5))
			local point2 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, 1.5))
			local point3 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, 1.5))
			local point4 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, 1.5))
			local point5 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, -1.5))
			local point6 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, -1.5))
			local point7 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, -1.5))
			local point8 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, -1.5))
			EntityESP.Line1.From = point1
			EntityESP.Line1.To = point2
			EntityESP.Line2.From = point3
			EntityESP.Line2.To = point4
			EntityESP.Line3.From = point5
			EntityESP.Line3.To = point6
			EntityESP.Line4.From = point7
			EntityESP.Line4.To = point8
			EntityESP.Line5.From = point1
			EntityESP.Line5.To = point3
			EntityESP.Line6.From = point1
			EntityESP.Line6.To = point5
			EntityESP.Line7.From = point5
			EntityESP.Line7.To = point7
			EntityESP.Line8.From = point7
			EntityESP.Line8.To = point3
			EntityESP.Line9.From = point2
			EntityESP.Line9.To = point4
			EntityESP.Line10.From = point2
			EntityESP.Line10.To = point6
			EntityESP.Line11.From = point6
			EntityESP.Line11.To = point8
			EntityESP.Line12.From = point8
			EntityESP.Line12.To = point4
		end
	end,
	DrawingSkeleton = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive
						and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
					or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then
				continue
			end

			local rigcheck = ent.Humanoid.RigType == Enum.HumanoidRigType.R6
			pcall(function()
				local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.identity
				local head = ESPWorldToViewport((ent.Head.CFrame).p)
				local headfront = ESPWorldToViewport((ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
				local toplefttorso = ESPWorldToViewport(
					(ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p
				)
				local toprighttorso = ESPWorldToViewport(
					(ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p
				)
				local toptorso = ESPWorldToViewport(
					(ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p
				)
				local bottomtorso = ESPWorldToViewport(
					(ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p
				)
				local bottomlefttorso = ESPWorldToViewport(
					(ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p
				)
				local bottomrighttorso = ESPWorldToViewport(
					(ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p
				)
				local leftarm =
					ESPWorldToViewport((ent.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
				local rightarm =
					ESPWorldToViewport((ent.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
				local leftleg =
					ESPWorldToViewport((ent.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
				local rightleg =
					ESPWorldToViewport((ent.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
				EntityESP.Head.From = toptorso
				EntityESP.Head.To = head
				EntityESP.HeadFacing.From = head
				EntityESP.HeadFacing.To = headfront
				EntityESP.UpperTorso.From = toplefttorso
				EntityESP.UpperTorso.To = toprighttorso
				EntityESP.Torso.From = toptorso
				EntityESP.Torso.To = bottomtorso
				EntityESP.LowerTorso.From = bottomlefttorso
				EntityESP.LowerTorso.To = bottomrighttorso
				EntityESP.LeftArm.From = toplefttorso
				EntityESP.LeftArm.To = leftarm
				EntityESP.RightArm.From = toprighttorso
				EntityESP.RightArm.To = rightarm
				EntityESP.LeftLeg.From = bottomlefttorso
				EntityESP.LeftLeg.To = leftleg
				EntityESP.RightLeg.From = bottomrighttorso
				EntityESP.RightLeg.To = rightleg
			end)
		end
	end,
    }

    ESP = vape.Categories.Render:CreateModule({
	Name = 'ESP',
	Function = function(callback)
		if callback then
			methodused = 'Drawing' .. Method.Value
			if ESPRemoved[methodused] then
				ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
			end
			if ESPAdded[methodused] then
				for _, v in entitylib.List do
					if Reference[v] then
						ESPRemoved[methodused](v)
					end
					ESPAdded[methodused](v)
				end
				ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						ESPRemoved[methodused](ent)
					end
					ESPAdded[methodused](ent)
				end))
			end
			if ESPUpdated[methodused] then
				ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
				for _, v in entitylib.List do
					ESPUpdated[methodused](v)
				end
			end
			if ColorFunc[methodused] then
				ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
				end))
			end
			if ESPLoop[methodused] then
				ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
			end
		else
			if ESPRemoved[methodused] then
				for i in Reference do
					ESPRemoved[methodused](i)
				end
			end
		end
	end,
	Tooltip = 'Extra Sensory Perception\nRenders an ESP on players',
    })
    Targets = ESP:CreateTargets({
	Players = true,
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
    })
    Method = ESP:CreateDropdown({
	Name = 'Mode',
	List = { '2D', '3D', 'Skeleton' },
	Function = function(val)
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
		BoundingBox.Object.Visible = (val == '2D')
		Filled.Object.Visible = (val == '2D')
		HealthBar.Object.Visible = (val == '2D')
		Name.Object.Visible = (val == '2D')
		DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
		Background.Object.Visible = Name.Object.Visible and Name.Enabled
	end,
    })
    Color = ESP:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if ESP.Enabled and ColorFunc[methodused] then
			ColorFunc[methodused](hue, sat, val)
		end
	end,
    })
    BoundingBox = ESP:CreateToggle({
	Name = 'Bounding Box',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Darker = true,
    })
    Filled = ESP:CreateToggle({
	Name = 'Filled',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true,
    })
    HealthBar = ESP:CreateToggle({
	Name = 'Health Bar',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true,
    })
    Name = ESP:CreateToggle({
	Name = 'Name',
	Function = function(callback)
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
		local visible = callback and Method.Value == '2D'
		DisplayName.Object.Visible = visible
		Background.Object.Visible = visible
	end,
	Darker = true,
    })
    DisplayName = ESP:CreateToggle({
	Name = 'Use Displayname',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Darker = true,
	Visible = function() return Method and Method.Value == '2D' and Name and Name.Enabled end,
    })
    Background = ESP:CreateToggle({
	Name = 'Show Background',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true,
	Visible = function() return Method and Method.Value == '2D' and Name and Name.Enabled end,
    })
    Teammates = ESP:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities',
    })
    Distance = ESP:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end,
    })
    DistanceLimit = ESP:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false,
    })
end)

run(function()
    local Fullbright
    local Mode
    local oldsettings = {}
    local flag

    local function ChangeLighting(prop)
        if flag then
            return
        end

        flag = true
        lightingService.Ambient = Color3.new(1, 1, 1)
        lightingService.OutdoorAmbient = Color3.new(1, 1, 1)
        lightingService.Brightness = 3
        runService.RenderStepped:Wait()
        flag = false
    end

    Fullbright = vape.Categories.Render:CreateModule({
        Name = 'Fullbright',
        Function = function(callback)
            if callback then
                if Mode.Value == 'Lighting' then
                    for _, v in {'Ambient', 'OutdoorAmbient', 'Brightness'} do
                        oldsettings[v] = lightingService[v]
                    end

                    Fullbright:Clean(lightingService.Changed:Connect(ChangeLighting))
                    task.spawn(ChangeLighting)
                else
                    local inst = Instance.new('PointLight')
                    inst.Range = 1000
                    Fullbright:Clean(inst)

                    repeat
                        inst.Parent = entitylib.isAlive and entitylib.character.RootPart or nil
                        task.wait(0.1)
                    until not Fullbright.Enabled
                end
            else
                flag = false
                for i, v in oldsettings do
                    lightingService[i] = v
                end
                table.clear(oldsettings)
            end
        end,
        Tooltip = 'Increase the lighting of the world around you'
    })
    Mode = Fullbright:CreateDropdown({
        Name = 'Mode',
        List = {'Lighting', 'PointLight'},
        Function = function()
            if Fullbright.Enabled then
                Fullbright:Toggle()
                Fullbright:Toggle()
            end
        end
    })
end)

run(function()
    local GamingChair = { Enabled = false }
    local Color
    local wheelpositions = {
	Vector3.new(-0.8, -0.6, -0.18),
	Vector3.new(0.1, -0.6, -0.88),
	Vector3.new(0, -0.6, 0.7),
    }
    local chairhighlight
    local currenttween
    local movingsound
    local flyingsound
    local chairanim
    local chair

    GamingChair = vape.Categories.Render:CreateModule({
	Name = 'GamingChair',
	Function = function(callback)
		if callback then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			chair = Instance.new('MeshPart')
			chair.Color = Color3.fromRGB(21, 21, 21)
			chair.Size = Vector3.new(2.16, 3.6, 2.3) / Vector3.new(12.37, 20.636, 13.071)
			chair.CanCollide = false
			chair.Massless = true
			chair.MeshId = 'rbxassetid://12972961089'
			chair.Material = Enum.Material.SmoothPlastic
			chair.Parent = workspace
			movingsound = Instance.new('Sound')
			--movingsound.SoundId = downloadVapeAsset('vape/assets/ChairRolling.mp3')
			movingsound.Volume = 0.4
			movingsound.Looped = true
			movingsound.Parent = workspace
			flyingsound = Instance.new('Sound')
			--flyingsound.SoundId = downloadVapeAsset('vape/assets/ChairFlying.mp3')
			flyingsound.Volume = 0.4
			flyingsound.Looped = true
			flyingsound.Parent = workspace
			local chairweld = Instance.new('WeldConstraint')
			chairweld.Part0 = chair
			chairweld.Parent = chair
			if entitylib.isAlive then
				chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
				chairweld.Part1 = entitylib.character.RootPart
			end
			chairhighlight = Instance.new('Highlight')
			chairhighlight.FillTransparency = 1
			chairhighlight.OutlineColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			chairhighlight.DepthMode = Enum.HighlightDepthMode.Occluded
			chairhighlight.OutlineTransparency = 0.2
			chairhighlight.Parent = chair
			local chairarms = Instance.new('MeshPart')
			chairarms.Color = chair.Color
			chairarms.Size = Vector3.new(1.39, 1.345, 2.75) / Vector3.new(97.13, 136.216, 234.031)
			chairarms.CFrame = chair.CFrame * CFrame.new(-0.169, -1.129, -0.013)
			chairarms.MeshId = 'rbxassetid://12972673898'
			chairarms.CanCollide = false
			chairarms.Parent = chair
			local chairarmsweld = Instance.new('WeldConstraint')
			chairarmsweld.Part0 = chairarms
			chairarmsweld.Part1 = chair
			chairarmsweld.Parent = chair
			local chairlegs = Instance.new('MeshPart')
			chairlegs.Color = chair.Color
			chairlegs.Name = 'Legs'
			chairlegs.Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
			chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
			chairlegs.MeshId = 'rbxassetid://13003181606'
			chairlegs.CanCollide = false
			chairlegs.Parent = chair
			local chairfan = Instance.new('MeshPart')
			chairfan.Color = chair.Color
			chairfan.Name = 'Fan'
			chairfan.Size = Vector3.zero
			chairfan.CFrame = chair.CFrame * CFrame.new(0, -1.873, 0)
			chairfan.MeshId = 'rbxassetid://13004977292'
			chairfan.CanCollide = false
			chairfan.Parent = chair
			local trails = {}
			for _, v in wheelpositions do
				local attachment = Instance.new('Attachment')
				attachment.Position = v
				attachment.Parent = chairlegs
				local attachment2 = Instance.new('Attachment')
				attachment2.Position = v + Vector3.new(0, 0, 0.18)
				attachment2.Parent = chairlegs
				local trail = Instance.new('Trail')
				trail.Texture = 'http://www.roblox.com/asset/?id=13005168530'
				trail.TextureMode = Enum.TextureMode.Static
				trail.Transparency = NumberSequence.new(0.5)
				trail.Color = ColorSequence.new(Color3.new(0.5, 0.5, 0.5))
				trail.Attachment0 = attachment
				trail.Attachment1 = attachment2
				trail.Lifetime = 20
				trail.MaxLength = 60
				trail.MinLength = 0.1
				trail.Parent = chairlegs
				table.insert(trails, trail)
			end
			GamingChair:Clean(chair)
			GamingChair:Clean(movingsound)
			GamingChair:Clean(flyingsound)
			chairanim = { Stop = function() end }
			local oldmoving = false
			local oldflying = false
			repeat
				if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
					if not chairanim.IsPlaying then
						local temp2 = Instance.new('Animation')
						temp2.AnimationId = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15
								and 'http://www.roblox.com/asset/?id=2506281703'
							or 'http://www.roblox.com/asset/?id=178130996'
						chairanim = entitylib.character.Humanoid:LoadAnimation(temp2)
						chairanim.Priority = Enum.AnimationPriority.Movement
						chairanim.Looped = true
						chairanim:Play()
					end
					chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
					chairweld.Part1 = entitylib.character.RootPart
					chairlegs.Velocity = Vector3.zero
					chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
					chairfan.Velocity = Vector3.zero
					chairfan.CFrame = chair.CFrame
						* CFrame.new(0.047, -1.873, 0)
						* CFrame.Angles(0, math.rad(tick() * 180 % 360), math.rad(180))
					local moving = entitylib.character.Humanoid:GetState() == Enum.HumanoidStateType.Running
						and entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
					local flying = vape.Modules.Fly and vape.Modules.Fly.Enabled
						or vape.Modules.LongJump and vape.Modules.LongJump.Enabled
						or vape.Modules.InfiniteFly and vape.Modules.InfiniteFly.Enabled
					if movingsound.TimePosition > 1.9 then
						movingsound.TimePosition = 0.2
					end
					movingsound.PlaybackSpeed = (entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude
						/ 16
					for _, v in trails do
						v.Enabled = not flying and moving
						v.Color =
							ColorSequence.new(movingsound.PlaybackSpeed > 1.5 and Color3.new(1, 0.5, 0) or Color3.new())
					end
					if moving ~= oldmoving then
						if movingsound.IsPlaying then
							if not moving then
								movingsound:Stop()
							end
						else
							if not flying and moving then
								movingsound:Play()
							end
						end
						oldmoving = moving
					end
					if flying ~= oldflying then
						if flying then
							if movingsound.IsPlaying then
								movingsound:Stop()
							end
							if not flyingsound.IsPlaying then
								flyingsound:Play()
							end
							if currenttween then
								currenttween:Cancel()
							end
							currenttween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
								Size = Vector3.zero,
							})
							currenttween.Completed:Connect(function(state)
								if state == Enum.PlaybackState.Completed then
									chairfan.Transparency = 0
									chairlegs.Transparency = 1
									currenttween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
										Size = Vector3.new(1.534, 0.328, 1.537)
											/ Vector3.new(791.138, 168.824, 792.027),
									})
									currenttween:Play()
								end
							end)
							currenttween:Play()
						else
							if flyingsound.IsPlaying then
								flyingsound:Stop()
							end
							if not movingsound.IsPlaying and moving then
								movingsound:Play()
							end
							if currenttween then
								currenttween:Cancel()
							end
							currenttween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
								Size = Vector3.zero,
							})
							currenttween.Completed:Connect(function(state)
								if state == Enum.PlaybackState.Completed then
									chairfan.Transparency = 1
									chairlegs.Transparency = 0
									currenttween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
										Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488),
									})
									currenttween:Play()
								end
							end)
							currenttween:Play()
						end
						oldflying = flying
					end
				else
					chair.Anchored = true
					chairlegs.Anchored = true
					chairfan.Anchored = true
					repeat
						task.wait()
					until entitylib.isAlive and entitylib.character.Humanoid.Health > 0
					chair.Anchored = false
					chairlegs.Anchored = false
					chairfan.Anchored = false
					chairanim:Stop()
				end
				task.wait()
			until not GamingChair.Enabled
		else
			if chairanim then
				chairanim:Stop()
			end
		end
	end,
	Tooltip = 'Sit in the best gaming chair known to mankind',
    })
    Color = GamingChair:CreateColorSlider({
	Name = 'Color',
	Function = function(h, s, v)
		if chairhighlight then
			chairhighlight.OutlineColor = Color3.fromHSV(h, s, v)
		end
	end,
    })
end)

run(function()
    local Health

    Health = vape.Categories.Render:CreateModule({
	Name = 'Health',
	Function = function(callback)
		if callback then
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromOffset(100, 20)
			label.Position = UDim2.new(0.5, 6, 0.5, 30)
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.BackgroundTransparency = 1
			label.Text = '100 ❤️'
			label.TextSize = 18
			label.Font = Enum.Font.Arial
			label.Parent = vape.gui
			Health:Clean(label)

			repeat
				label.Text = entitylib.isAlive and math.round(entitylib.character.Humanoid.Health) .. ' ❤️' or ''
				label.TextColor3 = entitylib.isAlive
						and Color3.fromHSV(
							(entitylib.character.Humanoid.Health / entitylib.character.Humanoid.MaxHealth) / 2.8,
							0.86,
							1
						)
					or Color3.new()
				task.wait()
			until not Health.Enabled
		end
	end,
	Tooltip = 'Displays your health in the center of your screen',
    })
end)

run(function()
    local NameTags
    local Targets
    local Color
    local Background
    local DisplayName
    local Health
    local Distance
    local DrawingToggle
    local Scale
    local FontOption
    local Teammates
    local DistanceCheck
    local DistanceLimit
    local Strings, Sizes, Reference = {}, {}, {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local methodused

    local Added = {
	Normal = function(ent)
		if not Targets.Players.Enabled and ent.Player then
			return
		end
		if not Targets.NPCs.Enabled and ent.NPC then
			return
		end
		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
			return
		end
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		Strings[ent] = ent.Player
				and whitelist:tag(ent.Player, true, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
			or ent.Character.Name

		if Health.Enabled then
			local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			Strings[ent] = Strings[ent]
				.. ' <font color="rgb('
				.. tostring(math.floor(healthColor.R * 255))
				.. ','
				.. tostring(math.floor(healthColor.G * 255))
				.. ','
				.. tostring(math.floor(healthColor.B * 255))
				.. ')">'
				.. math.round(ent.Health)
				.. '</font>'
		end

		if Distance.Enabled then
			Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '
				.. Strings[ent]
		end

		local nametag = Instance.new('TextLabel')
		nametag.TextSize = 14 * Scale.Value
		nametag.FontFace = FontOption.Value
		local size =
			getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
		nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Background.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.Text = Strings[ent]
		nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end,
	Drawing = function(ent)
		if not Targets.Players.Enabled and ent.Player then
			return
		end
		if not Targets.NPCs.Enabled and ent.NPC then
			return
		end
		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
			return
		end

		local nametag = {}
		nametag.BG = Drawing.new('Square')
		nametag.BG.Filled = true
		nametag.BG.Transparency = 1 - Background.Value
		nametag.BG.Color = Color3.new()
		nametag.BG.ZIndex = 1
		nametag.Text = Drawing.new('Text')
		nametag.Text.Size = 15 * Scale.Value
		nametag.Text.Font = 0
		nametag.Text.ZIndex = 2
		Strings[ent] = ent.Player
				and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
			or ent.Character.Name

		if Health.Enabled then
			Strings[ent] = Strings[ent] .. ' ' .. math.round(ent.Health)
		end

		if Distance.Enabled then
			Strings[ent] = '[%s] ' .. Strings[ent]
		end

		nametag.Text.Text = Strings[ent]
		nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
		Reference[ent] = nametag
	end,
    }

    local Removed = {
	Normal = function(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			Strings[ent] = nil
			Sizes[ent] = nil
			v:Destroy()
		end
	end,
	Drawing = function(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			Strings[ent] = nil
			Sizes[ent] = nil
			for _, obj in v do
				pcall(function()
					obj.Visible = false
					obj:Remove()
				end)
			end
		end
	end,
    }

    local Updated = {
	Normal = function(ent)
		local nametag = Reference[ent]
		if nametag then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Sizes[ent] = nil
			Strings[ent] = ent.Player
					and whitelist:tag(ent.Player, true, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
				or ent.Character.Name

			if Health.Enabled then
				local color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]
					.. ' <font color="rgb('
					.. tostring(math.floor(color.R * 255))
					.. ','
					.. tostring(math.floor(color.G * 255))
					.. ','
					.. tostring(math.floor(color.B * 255))
					.. ')">'
					.. math.round(ent.Health)
					.. '</font>'
			end

			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '
					.. Strings[ent]
			end

			local size =
				getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.Text = Strings[ent]
		end
	end,
	Drawing = function(ent)
		local nametag = Reference[ent]
		if nametag then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Sizes[ent] = nil
			Strings[ent] = ent.Player
					and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
				or ent.Character.Name

			if Health.Enabled then
				Strings[ent] = Strings[ent] .. ' ' .. math.round(ent.Health)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. Strings[ent]
				nametag.Text.Text = entitylib.isAlive
						and string.format(
							Strings[ent],
							math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)
						)
					or Strings[ent]
			else
				nametag.Text.Text = Strings[ent]
			end

			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		end
	end,
    }

    local ColorFunc = {
	Normal = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.TextColor3 = entitylib.getEntityColor(i) or color
		end
	end,
	Drawing = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.Text.Color = entitylib.getEntityColor(i) or color
		end
	end,
    }

    local Loop = {
	Normal = function()
		for ent, nametag in Reference do
			if DistanceCheck.Enabled then
				local distance = entitylib.isAlive
						and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
					or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					nametag.Visible = false
					continue
				end
			end

			local headPos, headVis =
				gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
			nametag.Visible = headVis
			if not headVis then
				continue
			end

			if Distance.Enabled then
				local mag = entitylib.isAlive
						and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)
					or 0
				if Sizes[ent] ~= mag then
					nametag.Text = string.format(Strings[ent], mag)
					local ize = getfontsize(
						removeTags(nametag.Text),
						nametag.TextSize,
						nametag.FontFace,
						Vector2.new(100000, 100000)
					)
					nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
					Sizes[ent] = mag
				end
			end
			nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
		end
	end,
	Drawing = function()
		for ent, nametag in Reference do
			if DistanceCheck.Enabled then
				local distance = entitylib.isAlive
						and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
					or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					nametag.Text.Visible = false
					nametag.BG.Visible = false
					continue
				end
			end

			local headPos, headVis =
				gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
			nametag.Text.Visible = headVis
			nametag.BG.Visible = headVis
			if not headVis then
				continue
			end

			if Distance.Enabled then
				local mag = entitylib.isAlive
						and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)
					or 0
				if Sizes[ent] ~= mag then
					nametag.Text.Text = string.format(Strings[ent], mag)
					nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
					Sizes[ent] = mag
				end
			end
			nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
			nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
		end
	end,
    }

    NameTags = vape.Categories.Render:CreateModule({
	Name = 'NameTags',
	Function = function(callback)
		if callback then
			methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
			if Removed[methodused] then
				NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
			end
			if Added[methodused] then
				for _, v in entitylib.List do
					if Reference[v] then
						Removed[methodused](v)
					end
					Added[methodused](v)
				end
				NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed[methodused](ent)
					end
					Added[methodused](ent)
				end))
			end
			if Updated[methodused] then
				NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
				for _, v in entitylib.List do
					Updated[methodused](v)
				end
			end
			if ColorFunc[methodused] then
				NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
				end))
			end
			if Loop[methodused] then
				NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
			end
		else
			if Removed[methodused] then
				for i in Reference do
					Removed[methodused](i)
				end
			end
		end
	end,
	Tooltip = 'Renders nametags on entities through walls',
    })
    Targets = NameTags:CreateTargets({
	Players = true,
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    FontOption = NameTags:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    Color = NameTags:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if NameTags.Enabled and ColorFunc[methodused] then
			ColorFunc[methodused](hue, sat, val)
		end
	end,
    })
    Scale = NameTags:CreateSlider({
	Name = 'Scale',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10,
    })
    Background = NameTags:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 10,
    })
    Health = NameTags:CreateToggle({
	Name = 'Health',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    Distance = NameTags:CreateToggle({
	Name = 'Distance',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    DisplayName = NameTags:CreateToggle({
	Name = 'Use Displayname',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = true,
    })
    Teammates = NameTags:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities',
    })
    DrawingToggle = NameTags:CreateToggle({
	Name = 'Drawing',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    DistanceCheck = NameTags:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end,
    })
    DistanceLimit = NameTags:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false,
    })
end)

run(function()
    local PlayerModel
    local Scale
    local Local
    local Mesh
    local Texture
    local Rots = {}
    local models = {}

    local function addMesh(ent)
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	local root = ent.RootPart
	local part = Instance.new('Part')
	part.Size = Vector3.new(3, 3, 3)
	part.CFrame = root.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.Parent = workspace
	local meshd = Instance.new('SpecialMesh')
	meshd.MeshId = Mesh.Value
	meshd.TextureId = Texture.Value
	meshd.Scale = Vector3.one * Scale.Value
	meshd.Parent = part
	local weld = Instance.new('WeldConstraint')
	weld.Part0 = part
	weld.Part1 = root
	weld.Parent = part
	models[root] = part
    end

    local function removeMesh(ent)
	if models[ent.RootPart] then
		models[ent.RootPart]:Destroy()
		models[ent.RootPart] = nil
	end
    end

    PlayerModel = vape.Categories.Render:CreateModule({
	Name = 'PlayerModel',
	Function = function(callback)
		if callback then
			if Local.Enabled then
				PlayerModel:Clean(entitylib.Events.LocalAdded:Connect(addMesh))
				PlayerModel:Clean(entitylib.Events.LocalRemoved:Connect(removeMesh))
				if entitylib.isAlive then
					task.spawn(addMesh, entitylib.character)
				end
			end
			PlayerModel:Clean(entitylib.Events.EntityAdded:Connect(addMesh))
			PlayerModel:Clean(entitylib.Events.EntityRemoved:Connect(removeMesh))
			for _, ent in entitylib.List do
				task.spawn(addMesh, ent)
			end
		else
			for _, part in models do
				part:Destroy()
			end
			table.clear(models)
		end
	end,
	Tooltip = 'Change the player models to a Mesh',
    })
    Scale = PlayerModel:CreateSlider({
	Name = 'Scale',
	Min = 0,
	Max = 2,
	Default = 1,
	Decimal = 100,
	Function = function(val)
		for _, part in models do
			part.Mesh.Scale = Vector3.one * val
		end
	end,
    })
    for _, name in { 'Rotation X', 'Rotation Y', 'Rotation Z' } do
	table.insert(
		Rots,
		PlayerModel:CreateSlider({
			Name = name,
			Min = 0,
			Max = 360,
			Function = function(val)
				for root, part in models do
					part.WeldConstraint.Enabled = false
					part.CFrame = root.CFrame
						* CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
					part.WeldConstraint.Enabled = true
				end
			end,
		})
	)
    end
    Local = PlayerModel:CreateToggle({
	Name = 'Local',
	Function = function()
		if PlayerModel.Enabled then
			PlayerModel:Toggle()
			PlayerModel:Toggle()
		end
	end,
    })
    Mesh = PlayerModel:CreateTextBox({
	Name = 'Mesh',
	Placeholder = 'mesh id',
	Function = function()
		for _, part in models do
			part.Mesh.MeshId = Mesh.Value
		end
	end,
    })
    Texture = PlayerModel:CreateTextBox({
	Name = 'Texture',
	Placeholder = 'texture id',
	Function = function()
		for _, part in models do
			part.Mesh.TextureId = Texture.Value
		end
	end,
    })
end)

run(function()
    local Search
    local List
    local Color
    local FillTransparency
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local function Add(v)
	if not table.find(List.ListEnabled, v.Name) then
		return
	end
	if v:IsA('BasePart') or v:IsA('Model') then
		local box = Instance.new('BoxHandleAdornment')
		box.AlwaysOnTop = true
		box.Adornee = v
		box.Size = v:IsA('Model') and v:GetExtentsSize() or v.Size
		box.ZIndex = 0
		box.Transparency = FillTransparency.Value
		box.Color3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		box.Parent = Folder
		Reference[v] = box
	end
    end

    Search = vape.Categories.Render:CreateModule({
	Name = 'Search',
	Function = function(callback)
		if callback then
			Search:Clean(workspace.DescendantAdded:Connect(Add))
			Search:Clean(workspace.DescendantRemoving:Connect(function(v)
				if Reference[v] then
					Reference[v]:Destroy()
					Reference[v] = nil
				end
			end))

			for _, v in workspace:GetDescendants() do
				Add(v)
			end
		else
			Folder:ClearAllChildren()
			table.clear(Reference)
		end
	end,
	Tooltip = 'Draws box around selected parts\nAdd parts in Search frame',
    })
    List = Search:CreateTextList({
	Name = 'Parts',
	Function = function()
		if Search.Enabled then
			Search:Toggle()
			Search:Toggle()
		end
	end,
    })
    Color = Search:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		for _, v in Reference do
			v.Color3 = Color3.fromHSV(hue, sat, val)
		end
	end,
    })
    FillTransparency = Search:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Function = function(val)
		for _, v in Reference do
			v.Transparency = val
		end
	end,
	Decimal = 10,
    })
end)

run(function()
    local Tracers
    local Targets
    local Color
    local Transparency
    local StartPosition
    local EndPosition
    local Teammates
    local DistanceColor
    local Distance
    local DistanceLimit
    local Behind
    local Reference = {}

    local function Added(ent)
	if not Targets.Players.Enabled and ent.Player then
		return
	end
	if not Targets.NPCs.Enabled and ent.NPC then
		return
	end
	if Teammates.Enabled and not ent.Targetable and not ent.Friend then
		return
	end
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	local EntityTracer = Drawing.new('Line')
	EntityTracer.Thickness = 1
	EntityTracer.Transparency = 1 - Transparency.Value
	EntityTracer.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	Reference[ent] = EntityTracer
    end

    local function Removed(ent)
	local v = Reference[ent]
	if v then
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		Reference[ent] = nil
		pcall(function()
			v.Visible = false
			v:Remove()
		end)
	end
    end

    local function ColorFunc(hue, sat, val)
	if DistanceColor.Enabled then
		return
	end
	local tracerColor = Color3.fromHSV(hue, sat, val)
	for ent, EntityTracer in Reference do
		EntityTracer.Color = entitylib.getEntityColor(ent) or tracerColor
	end
    end

    local function Loop()
	local screenSize = vape.gui.AbsoluteSize
	local startVector = StartPosition.Value == 'Mouse' and inputService:GetMouseLocation()
		or Vector2.new(screenSize.X / 2, (StartPosition.Value == 'Middle' and screenSize.Y / 2 or screenSize.Y))

	for ent, EntityTracer in Reference do
		local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
		if Distance.Enabled and distance then
			if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
				EntityTracer.Visible = false
				continue
			end
		end

		local pos = ent[EndPosition.Value == 'Torso' and 'RootPart' or 'Head'].Position
		local rootPos, rootVis = gameCamera:WorldToViewportPoint(pos)
		if not rootVis and Behind.Enabled then
			local tempPos = gameCamera.CFrame:PointToObjectSpace(pos)
			tempPos = CFrame.Angles(0, 0, (math.atan2(tempPos.Y, tempPos.X) + math.pi)):VectorToWorldSpace(
				(CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1)))
			)
			rootPos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(tempPos))
			rootVis = true
		end

		local endVector = Vector2.new(rootPos.X, rootPos.Y)
		EntityTracer.Visible = rootVis
		EntityTracer.From = startVector
		EntityTracer.To = endVector
		if DistanceColor.Enabled and distance then
			EntityTracer.Color = Color3.fromHSV(math.min((distance / 128) / 2.8, 0.4), 0.89, 0.75)
		end
	end
    end

    Tracers = vape.Categories.Render:CreateModule({
	Name = 'Tracers',
	Function = function(callback)
		if callback then
			Tracers:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
			for _, v in entitylib.List do
				if Reference[v] then
					Removed(v)
				end
				Added(v)
			end
			Tracers:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
				if Reference[ent] then
					Removed(ent)
				end
				Added(ent)
			end))
			Tracers:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
				ColorFunc(Color.Hue, Color.Sat, Color.Value)
			end))
			Tracers:Clean(runService.RenderStepped:Connect(Loop))
		else
			for i in Reference do
				Removed(i)
			end
		end
	end,
	Tooltip = 'Renders tracers on players',
    })
    Targets = Tracers:CreateTargets({
	Players = true,
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end,
    })
    StartPosition = Tracers:CreateDropdown({
	Name = 'Start Position',
	List = { 'Middle', 'Bottom', 'Mouse' },
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end,
    })
    EndPosition = Tracers:CreateDropdown({
	Name = 'End Position',
	List = { 'Head', 'Torso' },
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end,
    })
    Color = Tracers:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if Tracers.Enabled then
			ColorFunc(hue, sat, val)
		end
	end,
    })
    Transparency = Tracers:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Function = function(val)
		for _, tracer in Reference do
			tracer.Transparency = 1 - val
		end
	end,
	Decimal = 10,
    })
    DistanceColor = Tracers:CreateToggle({
	Name = 'Color by distance',
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end,
    })
    Distance = Tracers:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end,
    })
    DistanceLimit = Tracers:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false,
    })
    Behind = Tracers:CreateToggle({
	Name = 'Behind',
	Default = true,
    })
    Teammates = Tracers:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities',
    })
end)

run(function()
    local Waypoints
    local FontOption
    local List
    local Color
    local Scale
    local Background
    WaypointFolder = Instance.new('Folder')
    WaypointFolder.Parent = vape.gui

    Waypoints = vape.Categories.Render:CreateModule({
	Name = 'Waypoints',
	Function = function(callback)
		if callback then
			for _, v in List.ListEnabled do
				local split = v:split('/')
				local tagSize =
					getfontsize(removeTags(split[2]), 14 * Scale.Value, FontOption.Value, Vector2.new(100000, 100000))
				local billboard = Instance.new('BillboardGui')
				billboard.Size = UDim2.fromOffset(tagSize.X + 8, tagSize.Y + 7)
				billboard.StudsOffsetWorldSpace = Vector3.new(unpack(split[1]:split(',')))
				billboard.AlwaysOnTop = true
				billboard.Parent = WaypointFolder
				local tag = Instance.new('TextLabel')
				tag.BackgroundColor3 = Color3.new()
				tag.BorderSizePixel = 0
				tag.Visible = true
				tag.RichText = true
				tag.FontFace = FontOption.Value
				tag.TextSize = 14 * Scale.Value
				tag.BackgroundTransparency = Background.Value
				tag.Size = billboard.Size
				tag.Text = split[2]
				tag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tag.Parent = billboard
			end
		else
			WaypointFolder:ClearAllChildren()
		end
	end,
	Tooltip = 'Mark certain spots with a visual indicator',
    })
    FontOption = Waypoints:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial',
	Function = function()
		if Waypoints.Enabled then
			Waypoints:Toggle()
			Waypoints:Toggle()
		end
	end,
    })
    List = Waypoints:CreateTextList({
	Name = 'Points',
	Placeholder = 'x, y, z/name',
	Function = function()
		if Waypoints.Enabled then
			Waypoints:Toggle()
			Waypoints:Toggle()
		end
	end,
    })
    Waypoints:CreateButton({
	Name = 'Add current position',
	Function = function()
		if entitylib.isAlive then
			local pos = entitylib.character.RootPart.Position // 1
			List:ChangeValue(pos.X .. ',' .. pos.Y .. ',' .. pos.Z .. '/Waypoint ' .. (#List.List + 1))
		end
	end,
    })
    Color = Waypoints:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		for _, v in WaypointFolder:GetChildren() do
			v.TextLabel.TextColor3 = Color3.fromHSV(hue, sat, val)
		end
	end,
    })
    Scale = Waypoints:CreateSlider({
	Name = 'Scale',
	Function = function()
		if Waypoints.Enabled then
			Waypoints:Toggle()
			Waypoints:Toggle()
		end
	end,
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10,
    })
    Background = Waypoints:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if Waypoints.Enabled then
			Waypoints:Toggle()
			Waypoints:Toggle()
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 10,
    })
end)

run(function()
    local ZoomUnlocker
    local Distance

    local old

    ZoomUnlocker = vape.Categories.Render:CreateModule({
	Name = 'ZoomUnlocker',
	Tooltip = 'Changes max zoom distance',
	Function = function(call)
		if call then
			old = lplr.CameraMaxZoomDistance
			lplr.CameraMaxZoomDistance = Distance.Value
		else
			lplr.CameraMaxZoomDistance = old
			old = nil
		end
	end,
    })

    Distance = ZoomUnlocker:CreateSlider({
	Name = 'Distance',
	Min = (lplr.CameraMinZoomDistance or 0),
	Max = 300,
	Decimal = 5,
	Default = (lplr.CameraMaxZoomDistance or 14),
	Function = function(val)
		if ZoomUnlocker.Enabled then
			lplr.CameraMaxZoomDistance = val
		end
	end,
    })
end)

--[[
    Utility
]]

run(function()
    local AnimationPlayer
    local IDBox
    local Priority
    local Speed
    local anim, animobject

    local function playAnimation(char)
	local animcheck = anim
	if animcheck then
		anim = nil
		animcheck:Stop()
	end

	local suc, res = pcall(function()
		anim = char.Humanoid.Animator:LoadAnimation(animobject)
	end)

	if suc then
		local currentanim = anim
		anim.Priority = Enum.AnimationPriority[Priority.Value]
		anim:Play()
		anim:AdjustSpeed(Speed.Value)
		AnimationPlayer:Clean(anim.Stopped:Connect(function()
			if currentanim == anim then
				anim:Play()
			end
		end))
	else
		notif('AnimationPlayer', 'failed to load anim : ' .. (res or 'invalid animation id'), 5, 'warning')
	end
    end

    AnimationPlayer = vape.Categories.Utility:CreateModule({
	Name = 'AnimationPlayer',
	Function = function(callback)
		if callback then
			animobject = Instance.new('Animation')
			local suc, id = pcall(function()
				return string.match(game:GetObjects('rbxassetid://' .. IDBox.Value)[1].AnimationId, '%?id=(%d+)')
			end)
			animobject.AnimationId = 'rbxassetid://' .. (suc and id or IDBox.Value)

			if entitylib.isAlive then
				playAnimation(entitylib.character)
			end
			AnimationPlayer:Clean(entitylib.Events.LocalAdded:Connect(playAnimation))
			AnimationPlayer:Clean(animobject)
		else
			if anim then
				anim:Stop()
			end
		end
	end,
	Tooltip = 'Plays a specific animation of your choosing at a certain speed',
    })
    IDBox = AnimationPlayer:CreateTextBox({
	Name = 'Animation',
	Placeholder = 'anim (num only)',
	Function = function(enter)
		if enter and AnimationPlayer.Enabled then
			AnimationPlayer:Toggle()
			AnimationPlayer:Toggle()
		end
	end,
    })
    local prio = { 'Action4' }
    for _, v in Enum.AnimationPriority:GetEnumItems() do
	if v.Name ~= 'Action4' then
		table.insert(prio, v.Name)
	end
    end
    Priority = AnimationPlayer:CreateDropdown({
	Name = 'Priority',
	List = prio,
	Function = function(val)
		if anim then
			anim.Priority = Enum.AnimationPriority[val]
		end
	end,
    })
    Speed = AnimationPlayer:CreateSlider({
	Name = 'Speed',
	Function = function(val)
		if anim then
			anim:AdjustSpeed(val)
		end
	end,
	Min = 0.1,
	Max = 2,
	Decimal = 10,
    })
end)

run(function()
    local NoCameraCollision
    local Mode
    local originalMode
    local renderName = 'AetherNoCameraCollision'
    local distance = 12
    local manualInput
    local cameraModule
    local nextCameraLookup = 0
    local firstPersonDistance = 1

    local function stopManual()
		runService:UnbindFromRenderStep(renderName)
		if manualInput then
			manualInput:Disconnect()
			manualInput = nil
		end
		cameraModule = nil
		nextCameraLookup = 0
	end

    local function getCameraController()
		if cameraModule then return cameraModule.activeCameraController end
		if os.clock() < nextCameraLookup then return end
		nextCameraLookup = os.clock() + 2

		pcall(function()
			local playerScripts = lplr:FindFirstChild('PlayerScripts')
			local playerModuleScript = playerScripts and playerScripts:FindFirstChild('PlayerModule')
			if not playerModuleScript then return end
			local playerModule = require(playerModuleScript)
			if type(playerModule.GetCameras) == 'function' then
				cameraModule = playerModule:GetCameras()
			end
		end)
		return cameraModule and cameraModule.activeCameraController
    end

    local function getCameraDistance()
		local controller = getCameraController()
		local firstPerson = lplr.CameraMode == Enum.CameraMode.LockFirstPerson
		local controllerDistance
		if controller then
			local success, value = pcall(function()
				firstPerson = firstPerson or controller.inFirstPerson == true
				return controller:GetCameraToSubjectDistance()
			end)
			if success and type(value) == 'number' and value == value and value < math.huge then
				controllerDistance = value
			end
		end
		return controllerDistance or distance, firstPerson
    end

    local function startManual()
		stopManual()
		distance = math.clamp((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude, 0.5, lplr.CameraMaxZoomDistance)
		manualInput = inputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				distance = math.clamp(distance - input.Position.Z * math.max(distance * 0.15, 1), 0.5, lplr.CameraMaxZoomDistance)
			end
		end)
		runService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
			-- Roblox updates character transparency from its own zoom state before this
			-- callback. Respect that state in first person instead of moving an already
			-- hidden character back into third person.
			local cameraDistance, firstPerson = getCameraDistance()
			distance = math.clamp(cameraDistance, 0.5, lplr.CameraMaxZoomDistance)
			if firstPerson or distance <= firstPersonDistance or gameCamera.CameraType == Enum.CameraType.Scriptable then return end
			local focus, look = gameCamera.Focus, gameCamera.CFrame.LookVector
			gameCamera.CFrame = CFrame.lookAlong(focus.Position - look * distance, look)
		end)
	end

    local function applyMode()
		stopManual()
		local success = pcall(function()
			lplr.DevCameraOcclusionMode = Mode.Value == 'Manual' and Enum.DevCameraOcclusionMode.Zoom or Enum.DevCameraOcclusionMode.Invisicam
		end)
		if success and Mode.Value == 'Manual' then startManual() end
		return success
    end

    NoCameraCollision = vape.Categories.Utility:CreateModule({
	Name = 'NoCameraCollision',
	Function = function(callback)
	    if callback then
		local success, currentMode = pcall(function() return lplr.DevCameraOcclusionMode end)
		if not success then
		    notif('NoCameraCollision', 'Camera occlusion mode is unavailable in this game.', 5, 'warning')
		    NoCameraCollision:Toggle()
		    return
		end
		originalMode = originalMode or currentMode
		NoCameraCollision:Clean(stopManual)
		if not applyMode() then
		    notif('NoCameraCollision', 'Camera occlusion mode is unavailable in this game.', 5, 'warning')
		    NoCameraCollision:Toggle()
		    return
		end
	    else
		stopManual()
		if originalMode then
		pcall(function() lplr.DevCameraOcclusionMode = originalMode end)
		originalMode = nil
		end
	    end
	end,
	Tooltip = 'Prevents walls from forcing the third-person camera to zoom in'
    })
    Mode = NoCameraCollision:CreateDropdown({
	Name = 'Mode',
	List = {'Manual', 'Invisicam'},
	Tooltip = 'Manual bypasses camera collision without making obstructing blocks transparent',
	Function = function()
		if NoCameraCollision.Enabled and not applyMode() then
			notif('NoCameraCollision', 'Camera occlusion mode is unavailable in this game.', 5, 'warning')
			NoCameraCollision:Toggle()
		end
	end
    })
end)

run(function()
    local AntiRagdoll

    AntiRagdoll = vape.Categories.Utility:CreateModule({
	Name = 'AntiRagdoll',
	Function = function(callback)
		if entitylib.isAlive then
			entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not callback)
		end

		if callback then
			AntiRagdoll:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			end))
		end
	end,
	Tooltip = 'Prevents you from getting knocked down in a ragdoll state',
    })
end)

run(function()
    local AutoRejoin
    local Sort

    AutoRejoin = vape.Categories.Utility:CreateModule({
	Name = 'AutoRejoin',
	Function = function(callback)
		if callback then
			local check
			AutoRejoin:Clean(guiService.ErrorMessageChanged:Connect(function(str)
				if
					(not check or guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick)
					and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost
					and not str:lower():find('ban')
				then
					check = true
					serverHop(nil, Sort.Value)
				end
			end))
		end
	end,
	Tooltip = 'Automatically rejoins into a new server if you get disconnected / kicked',
    })
    Sort = AutoRejoin:CreateDropdown({
	Name = 'Sort',
	List = { 'Descending', 'Ascending' },
	Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers',
    })
end)

run(function()
    local Blink
    local Type
    local AutoSend
    local AutoSendLength
    local oldphys, oldsend

    Blink = vape.Categories.Utility:CreateModule({
	Name = 'Blink',
	Function = function(callback)
		if callback then
			local teleported
			Blink:Clean(lplr.OnTeleport:Connect(function()
				setfflag('PhysicsSenderMaxBandwidthBps', '38760')
				setfflag('DataSenderRate', '60')
				teleported = true
			end))

			repeat
				local physicsrate, senderrate = '0', Type.Value == 'All' and '-1' or '60'
				if AutoSend.Enabled and tick() % (AutoSendLength.Value + 0.1) > AutoSendLength.Value then
					physicsrate, senderrate = '38760', '60'
				end

				if physicsrate ~= oldphys or senderrate ~= oldsend then
					setfflag('PhysicsSenderMaxBandwidthBps', physicsrate)
					setfflag('DataSenderRate', senderrate)
					oldphys, oldsend = physicsrate, senderrate
				end

				task.wait(0.03)
			until not Blink.Enabled and not teleported
		else
			if setfflag then
				setfflag('PhysicsSenderMaxBandwidthBps', '38760')
				setfflag('DataSenderRate', '60')
			end
			oldphys, oldsend = nil, nil
		end
	end,
	Tooltip = 'Chokes packets until disabled',
    })
    Type = Blink:CreateDropdown({
	Name = 'Type',
	List = { 'Movement Only', 'All' },
	Tooltip = 'Movement Only - Only chokes movement packets\nAll - Chokes remotes & movement',
    })
    AutoSend = Blink:CreateToggle({
	Name = 'Auto send',
	Function = function(callback)
		AutoSendLength.Object.Visible = callback
	end,
	Tooltip = 'Automatically send packets in intervals',
    })
    AutoSendLength = Blink:CreateSlider({
	Name = 'Send threshold',
	Min = 0,
	Max = 1,
	Decimal = 100,
	Darker = true,
	Visible = false,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
    })
end)

run(function()
    local ChatSpammer
    local Lines
    local Mode
    local Delay
    local Hide
    local oldchat

    ChatSpammer = vape.Categories.Utility:CreateModule({
	Name = 'ChatSpammer',
	Function = function(callback)
		if callback then
			if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
				if Hide.Enabled and coreGui:FindFirstChild('ExperienceChat') then
					ChatSpammer:Clean(
						coreGui.ExperienceChat
							:FindFirstChild('RCTScrollContentView', true).ChildAdded
							:Connect(function(msg)
								if
									msg.Name:sub(1, 2) == '0-'
									and msg.ContentText == 'You must wait before sending another message.'
								then
									msg.Visible = false
								end
							end)
					)
				end
			elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
				if Hide.Enabled then
					oldchat = hookfunction(
						getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function,
						function(data, ...)
							if data.Message:find('ChatFloodDetector') then
								return
							end
							return oldchat(data, ...)
						end
					)
				end
			else
				notif('ChatSpammer', 'unsupported chat', 5, 'warning')
				ChatSpammer:Toggle()
				return
			end

			local ind = 1
			repeat
				local message = (
					#Lines.ListEnabled > 0 and Lines.ListEnabled[math.random(1, #Lines.ListEnabled)] or 'vxpe on top'
				)
				if Mode.Value == 'Order' and #Lines.ListEnabled > 0 then
					message = Lines.ListEnabled[ind] or Lines.ListEnabled[1]
					ind = (ind % #Lines.ListEnabled) + 1
				end

				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
				end

				task.wait(Delay.Value)
			until not ChatSpammer.Enabled
		else
			if oldchat then
				hookfunction(
					getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function,
					oldchat
				)
			end
		end
	end,
	Tooltip = 'Automatically types in chat',
    })
    Lines = ChatSpammer:CreateTextList({ Name = 'Lines' })
    Mode = ChatSpammer:CreateDropdown({
	Name = 'Mode',
	List = { 'Random', 'Order' },
    })
    Delay = ChatSpammer:CreateSlider({
	Name = 'Delay',
	Min = 0.1,
	Max = 10,
	Default = 1,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
    })
    Hide = ChatSpammer:CreateToggle({
	Name = 'Hide Flood Message',
	Default = true,
	Function = function()
		if ChatSpammer.Enabled then
			ChatSpammer:Toggle()
			ChatSpammer:Toggle()
		end
	end,
    })
end)

run(function()
    local Disabler

    local function characterAdded(char)
	for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('CFrame')) do
		hookfunction(v.Function, function() end)
	end
	for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('Velocity')) do
		hookfunction(v.Function, function() end)
	end
    end

    Disabler = vape.Categories.Utility:CreateModule({
	Name = 'Disabler',
	Function = function(callback)
		if callback then
			Disabler:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
			if entitylib.isAlive then
				characterAdded(entitylib.character)
			end
		end
	end,
	Tooltip = 'Disables GetPropertyChangedSignal detections for movement',
    })
end)


run(function()
	local Panic
	local armedUntil = 0

	Panic = vape.Categories.Utility:CreateModule({
		Name = 'Panic',
		Function = function(callback)
			if callback then
				local now = tick()
				if now > armedUntil then
					armedUntil = now + 8
					notif('Panic', 'Panic is armed. Activate Panic again within 8 seconds to turn every module off.', 8, 'warning')
					Panic:Toggle()
					return
				end
				armedUntil = 0
				for _, v in vape.Modules do
					if v.Enabled then
						v:Toggle()
					end
				end
			end
		end,
		Tooltip = 'Requires a second activation before disabling all currently enabled modules',
	})
end)

run(function()
    local Rejoin

    Rejoin = vape.Categories.Utility:CreateModule({
	Name = 'Rejoin',
	Function = function(callback)
		if callback then
			notif('Rejoin', 'Rejoining...', 5)
			Rejoin:Toggle()
			if playersService.NumPlayers > 1 then
				teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
			else
				teleportService:Teleport(game.PlaceId)
			end
		end
	end,
	Tooltip = 'Rejoins the server',
    })
end)

run(function()
    local ServerHop
    local Sort

    ServerHop = vape.Categories.Utility:CreateModule({
	Name = 'ServerHop',
	Function = function(callback)
		if callback then
			ServerHop:Toggle()
			serverHop(nil, Sort.Value)
		end
	end,
	Tooltip = 'Teleports into a unique server',
    })
    Sort = ServerHop:CreateDropdown({
	Name = 'Sort',
	List = { 'Descending', 'Ascending' },
	Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers',
    })
    ServerHop:CreateButton({
	Name = 'Rejoin Previous Server',
	Function = function()
		notif(
			'ServerHop',
			shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server',
			5
		)
		if shared.vapeserverhopprevious then
			teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
		end
	end,
    })
end)

run(function()
    local StaffDetector
    local Mode
    local Profile
    local Users
    local Group
    local Role

    local function getRole(plr, id)
	local suc, res
	for _ = 1, 3 do
		suc, res = pcall(function()
			return plr:GetRankInGroup(id)
		end)
		if suc then
			break
		end
	end
	return suc and res or 0
    end

    local function getLowestStaffRole(roles)
	local highest = math.huge
	for _, v in roles do
		local low = v.Name:lower()
		if (low:find('admin') or low:find('mod') or low:find('dev')) and v.Rank < highest then
			highest = v.Rank
		end
	end
	return highest
    end

    local function playerAdded(plr)
	if not vape.Loaded then
		repeat
			task.wait()
		until vape.Loaded
	end

	local user = table.find(Users.ListEnabled, tostring(plr.UserId))
	if user or getRole(plr, tonumber(Group.Value) or 0) >= (tonumber(Role.Value) or 1) then
		notif(
			'StaffDetector',
			'Staff Detected (' .. (user and 'blacklisted_user' or 'staff_role') .. '): ' .. plr.Name,
			60,
			'alert'
		)
		whitelist.customtags[plr.Name] = { { text = 'GAME STAFF', color = Color3.new(1, 0, 0) } }

		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected\n' .. plr.Name,
				Duration = 60,
			})
		elseif Mode.Value == 'ServerHop' then
			serverHop()
		elseif Mode.Value == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape.Profile = Profile.Value
				vape:Load(true, Profile.Value)
			end
		elseif Mode.Value == 'AutoConfig' then
			vape.Save = function() end
			for _, v in vape.Modules do
				if v.Enabled then
					v:Toggle()
				end
			end
		end
	end
    end

    StaffDetector = vape.Categories.Utility:CreateModule({
	Name = 'StaffDetector',
	Function = function(callback)
		if callback then
			if Group.Value == '' or Role.Value == '' then
				local placeinfo = { Creator = { CreatorTargetId = tonumber(Group.Value) } }
				if Group.Value == '' then
					placeinfo = marketplaceService:GetProductInfo(game.PlaceId)
					if placeinfo.Creator.CreatorType ~= 'Group' then
						local desc = placeinfo.Description:split('\n')
						for _, str in desc do
							local _, begin = str:find('roblox.com/groups/')
							if begin then
								local endof = str:find('/', begin + 1)
								placeinfo = {
									Creator = {
										CreatorType = 'Group',
										CreatorTargetId = str:sub(begin + 1, endof - 1),
									},
								}
							end
						end
					end

					if placeinfo.Creator.CreatorType ~= 'Group' then
						notif('StaffDetector', 'Automatic Setup Failed (no group detected)', 60, 'warning')
						return
					end
				end

				local groupinfo = groupService:GetGroupInfoAsync(placeinfo.Creator.CreatorTargetId)
				Group:SetValue(placeinfo.Creator.CreatorTargetId)
				Role:SetValue(getLowestStaffRole(groupinfo.Roles))
			end

			if Group.Value == '' or Role.Value == '' then
				return
			end

			StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
			for _, v in playersService:GetPlayers() do
				task.spawn(playerAdded, v)
			end
		end
	end,
	Tooltip = 'Detects people with a staff rank ingame',
    })
    Mode = StaffDetector:CreateDropdown({
	Name = 'Mode',
	List = { 'Uninject', 'ServerHop', 'Profile', 'AutoConfig', 'Notify' },
	Function = function(val)
		if Profile.Object then
			Profile.Object.Visible = val == 'Profile'
		end
	end,
    })
    Profile = StaffDetector:CreateTextBox({
	Name = 'Profile',
	Default = 'default',
	Darker = true,
	Visible = false,
    })
    Users = StaffDetector:CreateTextList({
	Name = 'Users',
	Placeholder = 'player (userid)',
    })
    Group = StaffDetector:CreateTextBox({
	Name = 'Group',
	Placeholder = 'Group Id',
    })
    Role = StaffDetector:CreateTextBox({
	Name = 'Role',
	Placeholder = 'Role Rank',
    })
end)

run(function()
    local StateSpoofer
    local State

    local hook

    StateSpoofer = vape.Categories.Utility:CreateModule({
	Name = 'StateSpoofer',
	Function = function(callback)
		if callback then
			if not rakNetCheck('StateSpoofer') then
				StateSpoofer:Toggle()
				return
			end

			hook = function(packet)
				-- Guarded so a short/unexpected packet can never crash the network thread.
				pcall(function()
					if packet.AsArray and packet.AsArray[1] == 0x1b then
						local data = packet.AsBuffer
						local stateEnum = State and Enum.HumanoidStateType[State.Value]
						if data and stateEnum and buffer.len(data) >= 26 then
							buffer.writeu8(data, 25, stateEnum.Value + 32)
							packet:SetData(data)
						end
					end
				end)
			end

			raknet.add_send_hook(hook)
		elseif hook then
			raknet.remove_send_hook(hook)
			hook = nil
		end
	end,
	Tooltip = 'Spoof humanoid states on the server',
    })
    local states = {}
    for _, v in Enum.HumanoidStateType:GetEnumItems() do
	if v.Name ~= 'None' then
		table.insert(states, v.Name)
	end
    end
    State = StateSpoofer:CreateDropdown({
	Name = 'Humanoid State',
	List = states,
    })
end)

--[[
    World
]]

run(function()
    local connection

    vape.Categories.World:CreateModule({
        Name = 'Anti-AFK',
        Function = function(callback)
            if callback then
                connection = lplr.Idled:Connect(function()
                    local VirtualUser = game:GetService('VirtualUser')

                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            elseif connection then
                connection:Disconnect()
                connection = nil
            end
        end,
        Tooltip = 'Lets you stay ingame without getting kicked'
    })
end)



run(function()
	local PromptEditor
	local Range
	local Hold
	local Instant
	local ThroughWalls
	local originals = setmetatable({}, {__mode = 'k'})
	local applying = setmetatable({}, {__mode = 'k'})
	local environment = (getgenv and getgenv()) or _G
	local api = environment.AetherInteractExtender or {}

	local function remember(prompt)
		if originals[prompt] then return true end
		local ok, state = pcall(function()
			return {
				Distance = prompt.MaxActivationDistance,
				Duration = prompt.HoldDuration,
				Sight = prompt.RequiresLineOfSight
			}
		end)
		if ok then originals[prompt] = state end
		return ok
	end

	local function applyPrompt(prompt)
		if typeof(prompt) ~= 'Instance' or not prompt:IsA('ProximityPrompt') or not remember(prompt) then return end
		applying[prompt] = true
		pcall(function()
			prompt.MaxActivationDistance = Range.Value
			prompt.HoldDuration = Instant.Enabled and 0 or Hold.Value
			prompt.RequiresLineOfSight = not ThroughWalls.Enabled
		end)
		applying[prompt] = nil
	end

	local function restorePrompt(prompt, original)
		if not prompt or not prompt.Parent or not original then return end
		applying[prompt] = true
		pcall(function()
			prompt.MaxActivationDistance = original.Distance
			prompt.HoldDuration = original.Duration
			prompt.RequiresLineOfSight = original.Sight
		end)
		applying[prompt] = nil
	end

	local function refresh()
		if not PromptEditor.Enabled then return end
		for prompt in originals do applyPrompt(prompt) end
	end


	api.IsEnabled = function()
		return PromptEditor and PromptEditor.Enabled == true
	end
	api.Activate = function(prompt)
		if not api.IsEnabled() then return false, 'PromptEditor is disabled' end
		if typeof(prompt) ~= 'Instance' or not prompt:IsA('ProximityPrompt') then return false, 'invalid prompt' end
		applyPrompt(prompt)
		if type(fireproximityprompt) ~= 'function' then return false, 'fireproximityprompt unavailable' end
		local ok, result = pcall(fireproximityprompt, prompt)
		return ok and result ~= false, ok and nil or tostring(result)
	end
	environment.AetherInteractExtender = api
	vape:Clean(function()
		if environment.AetherInteractExtender == api then environment.AetherInteractExtender = nil end
	end)

	PromptEditor = vape.Categories.World:CreateModule({
		Name = 'PromptEditor',
		Tooltip = 'Edits proximity prompt range, hold time and line-of-sight rules in one module',
		Function = function(callback)
			if callback then
				PromptEditor:Clean(workspace.DescendantAdded:Connect(applyPrompt))
				PromptEditor:Clean(proximityPromptService.PromptShown:Connect(applyPrompt))
				for _, prompt in workspace:GetDescendants() do applyPrompt(prompt) end
			else
				for prompt, original in originals do restorePrompt(prompt, original) end
				table.clear(originals)
				table.clear(applying)
			end
		end
	})
	Range = PromptEditor:CreateSlider({Name = 'Range', Min = 1, Max = 100, Default = 32, Suffix = ' studs', Function = refresh})
	Hold = PromptEditor:CreateSlider({Name = 'Hold duration', Min = 0, Max = 10, Default = 1, Decimal = 100, Suffix = 's', Function = refresh})
	Instant = PromptEditor:CreateToggle({Name = 'Instant', Tooltip = 'Sets prompt hold duration to zero', Function = refresh})
	ThroughWalls = PromptEditor:CreateToggle({Name = 'Through walls', Tooltip = 'Removes prompt line-of-sight checks', Function = refresh})
end)



--[[
	Freecam.

	A camera you fly yourself, plus the effects that turn flying around into a shot: eased
	movement, orbits, dollies, roll, shake, depth of field, motion blur, and a keyframe path
	you can play back. Every effect is off until it is switched on, so the module on its own
	is still just a freecam.

	It takes the camera outright - Scriptable, re-asserted every frame so a game that resets
	the camera cannot pull it back - and writes the CFrame in a render step ordered after
	Roblox's own camera, which is the only way roll, orbit and keyframe playback can exist
	at all. Everything it touches (camera type, field of view, mouse state, Lighting
	effects, the HUD) is saved on the way in and put back on the way out.

	Nothing here snaps: entering picks the camera up exactly where the game left it, every
	effect eases in and out, and leaving hands it straight back.
]]
run(function()
    local Freecam
    local Speed, Sensitivity, TimeScale
    local Smoothing, SmoothAmount, Acceleration, Deceleration
    local Fov, FovSpeed, Zoom, ZoomFov, ZoomKey
    local Roll, RollSpeed, Tilt
    local Shake, ShakeAmount, ShakeSpeed
    local Dof, AutoFocus, FocusDistance, FocusRange, DofStrength
    local MotionBlur, MotionBlurAmount
    local Orbit, OrbitDirection, OrbitSpeed, OrbitDistance
    local Dolly, DollyDirection, DollySpeed
    local KeyframeTime, KeyframeEase, KeyframeLoop
    local PathName, PathTarget, PathAction, KeyframeIndex
    local HideHud
    local Collision

    local starterGui = cloneref(game:GetService('StarterGui'))
    local bindName = 'AetherV2Freecam'..httpService:GenerateGUID(false)

    -- What the camera was doing before we took it, and what we hung off Lighting.
    local active = false
    local restore = {}
    local dofEffect, blurEffect
    local hiddenGuis, disabledEffects = {}, {}

    -- Live state. pos/yaw/pitch are what the input drives; the smooth* set is what actually
    -- renders, and the gap between the two is where smoothing lives.
    local pos, yaw, pitch = Vector3.zero, 0, 0
    local smoothPos, smoothYaw, smoothPitch = Vector3.zero, 0, 0
    local velocity = Vector3.zero
    local roll, manualRoll, fov, focus, blurSize = 0, 0, 70, 25, 0
    local orbitPivot, orbitAngle
    local shakeClock, firstFrame = 0, true
    local lastPos, lastYaw
    local keyframes, playback = {}, nil
    local pathFolder = 'aetherv2/profiles/camera-paths'

    local function safePathName()
        return tostring(PathName and PathName.Value or ''):gsub('[^%w%-%_ ]', ''):sub(1, 40)
    end

    local function encodeFrames()
        local out = {}
        for _, frame in keyframes do
            table.insert(out, {Position = {frame.Position.X, frame.Position.Y, frame.Position.Z}, Yaw = frame.Yaw, Pitch = frame.Pitch, Roll = frame.Roll, Fov = frame.Fov})
        end
        return out
    end

    local function decodeFrames(data)
        if type(data) ~= 'table' then return false end
        local out = {}
        for _, frame in data do
            if type(frame) ~= 'table' or type(frame.Position) ~= 'table' or #frame.Position ~= 3 then return false end
            table.insert(out, {Position = Vector3.new(tonumber(frame.Position[1]), tonumber(frame.Position[2]), tonumber(frame.Position[3])), Yaw = tonumber(frame.Yaw), Pitch = tonumber(frame.Pitch), Roll = tonumber(frame.Roll), Fov = tonumber(frame.Fov)})
            if not out[#out].Yaw or not out[#out].Pitch or not out[#out].Roll or not out[#out].Fov then return false end
        end
        keyframes = out
        return true
    end

    local function camera()
        gameCamera = workspace.CurrentCamera or gameCamera
        return gameCamera
    end

    -- Frame rate independent easing: the fraction of the remaining distance to cover this
    -- frame for a spring that would cover `rate` of it per second. Without the exponential a
    -- low frame rate overshoots and a high one crawls.
    local function approach(rate, dt)
        return 1 - math.exp(-math.max(rate, 0) * dt)
    end

    local function shortestAngle(from, to)
        return (to - from + math.pi) % (math.pi * 2) - math.pi
    end

    -- The menu owns the mouse while it is open and a focused text box owns the keyboard, so
    -- neither should be flying the camera around.
    local function inputAllowed()
        local suc, menu = pcall(function()
            return vape.gui.ScaledGui.ClickGui.Visible
        end)
        return (not (suc and menu)) and (not inputService:GetFocusedTextBox())
    end

    local function keyDown(key)
        return inputService:IsKeyDown(key)
    end

    local function named(name)
        local suc, key = pcall(function()
            return Enum.KeyCode[name]
        end)
        return suc and key and inputService:IsKeyDown(key) or false
    end

    ----------------------------------------------------------------------------------
    -- Lighting
    ----------------------------------------------------------------------------------

    -- The game may already have a depth of field or a blur, and two of either stack into a
    -- mess. Ours only goes up once theirs is out of the way, and theirs comes back untouched.
    local function suspendEffects()
        for _, effect in lightingService:GetChildren() do
            if (effect:IsA('DepthOfFieldEffect') or effect:IsA('BlurEffect'))
                and effect ~= dofEffect and effect ~= blurEffect and effect.Enabled then
                table.insert(disabledEffects, effect)
                effect.Enabled = false
            end
        end
    end

    local function releaseEffects()
        for _, effect in disabledEffects do
            pcall(function()
                effect.Enabled = true
            end)
        end
        table.clear(disabledEffects)
    end

    local function updateDof(dt)
        if not Dof.Enabled then
            if dofEffect then
                dofEffect:Destroy()
                dofEffect = nil
                if not blurEffect then
                    releaseEffects()
                end
            end
            return
        end
        if not dofEffect then
            suspendEffects()
            dofEffect = Instance.new('DepthOfFieldEffect')
            dofEffect.Name = 'AetherV2FreecamDOF'
            -- Wide open to start with, so switching it on racks into focus instead of
            -- slamming into it.
            dofEffect.FarIntensity = 0
            dofEffect.NearIntensity = 0
            dofEffect.FocusDistance = focus
            dofEffect.Parent = lightingService
        end

        local target = FocusDistance.Value
        if AutoFocus.Enabled then
            -- Focus on whatever is centre frame, which is what a focus puller would be
            -- doing. Empty shot falls back to the manual distance.
            local cam = camera()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {cam, lplr.Character}
            local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 2000, params)
            target = hit and (hit.Position - cam.CFrame.Position).Magnitude or FocusDistance.Value
        end
        -- A focus pull is a move in its own right, so it eases rather than jumps.
        focus += (target - focus) * approach(AutoFocus.Enabled and 4 or 8, dt)

        dofEffect.FocusDistance = focus
        dofEffect.InFocusRadius = FocusRange.Value
        dofEffect.FarIntensity = DofStrength.Value / 100
        dofEffect.NearIntensity = (DofStrength.Value / 100) * 0.6
    end

    local function updateMotionBlur(dt, moveSpeed, turnSpeed)
        if not MotionBlur.Enabled then
            if blurEffect then
                blurEffect:Destroy()
                blurEffect = nil
                if not dofEffect then
                    releaseEffects()
                end
            end
            return
        end
        if not blurEffect then
            suspendEffects()
            blurEffect = Instance.new('BlurEffect')
            blurEffect.Name = 'AetherV2FreecamBlur'
            blurEffect.Size = 0
            blurEffect.Parent = lightingService
        end
        -- Driven by how fast the shot is actually moving, so a locked-off camera stays sharp
        -- and only a whip pan smears. Eased both ways so it never pops.
        local target = math.clamp((moveSpeed / 90) + (turnSpeed / 2.2), 0, 1) * 24 * (MotionBlurAmount.Value / 100)
        blurSize += (target - blurSize) * approach(9, dt)
        blurEffect.Size = blurSize
    end

    ----------------------------------------------------------------------------------
    -- Interface
    ----------------------------------------------------------------------------------

    local function showInterface()
        if restore.CoreGui ~= nil then
            pcall(function()
                starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, restore.CoreGui)
            end)
        end
        for _, screen in hiddenGuis do
            pcall(function()
                screen.Enabled = true
            end)
        end
        table.clear(hiddenGuis)
    end

    -- AetherV2's own menu is a LayerCollector sitting in the same PlayerGui as the game's HUD
    -- whenever the executor has no CoreGui to hang it off, so a blanket sweep of PlayerGui took
    -- the menu down with the interface - and the menu is how you get back out of the shot.
    local function isOwnGui(screen)
        local suc, menu = pcall(function()
            return vape.gui
        end)
        if not suc or typeof(menu) ~= 'Instance' then return false end
        return screen == menu or screen:IsDescendantOf(menu) or menu:IsDescendantOf(screen)
    end

    local function hideInterface()
        if not HideHud.Enabled then return end
        pcall(function()
            starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        end)
        local playerGui = lplr:FindFirstChildOfClass('PlayerGui')
        if playerGui then
            for _, screen in playerGui:GetChildren() do
                if screen:IsA('LayerCollector') and screen.Enabled and not isOwnGui(screen) then
                    table.insert(hiddenGuis, screen)
                    screen.Enabled = false
                end
            end
        end
    end

    local function refreshInterface()
        if not active then return end
        showInterface()
        hideInterface()
    end

    ----------------------------------------------------------------------------------
    -- Keyframes
    ----------------------------------------------------------------------------------

    local function snapshot()
        return {Position = pos, Yaw = yaw, Pitch = pitch, Roll = roll, Fov = fov}
    end

    -- Catmull-Rom, so a path of three or more curves through its keyframes instead of
    -- cornering at each one. Endpoints repeat, which keeps the first and last segments sane.
    local function splinePoint(a, b, c, d, t)
        local t2, t3 = t * t, t * t * t
        return (b * 2 + (c - a) * t + (a * 2 - b * 5 + c * 4 - d) * t2 + (b * 3 - a - c * 3 + d) * t3) * 0.5
    end

    local function frameAt(index)
        local count = #keyframes
        if count == 0 then return nil end
        if KeyframeLoop.Enabled then
            return keyframes[((index - 1) % count) + 1]
        end
        return keyframes[math.clamp(index, 1, count)]
    end

    local function stopPlayback()
        if not playback then return end
        playback = nil
        -- Carry on from wherever the path left the camera rather than snapping back to
        -- wherever it was when play was pressed.
        pos, yaw, pitch = smoothPos, smoothYaw, smoothPitch
        manualRoll = roll
        velocity = Vector3.zero
    end

    local function startPlayback()
        if #keyframes < 2 then
            notif('Freecam', 'Save at least two keyframes first', 5, 'alert')
            return
        end
        playback = {Index = 1, Alpha = 0}
    end

    local function stepPlayback(dt)
        playback.Alpha += dt / math.max(KeyframeTime.Value, 0.05)

        while playback.Alpha >= 1 do
            playback.Alpha -= 1
            playback.Index += 1
            local lastSegment = KeyframeLoop.Enabled and #keyframes or (#keyframes - 1)
            if playback.Index > lastSegment then
                if KeyframeLoop.Enabled then
                    playback.Index = 1
                else
                    -- Land exactly on the final keyframe instead of stopping a frame short.
                    local last = keyframes[#keyframes]
                    pos, yaw, pitch, roll, fov = last.Position, last.Yaw, last.Pitch, last.Roll, last.Fov
                    smoothPos, smoothYaw, smoothPitch = pos, yaw, pitch
                    manualRoll = roll
                    playback = nil
                    return
                end
            end
        end

        local from, to = frameAt(playback.Index), frameAt(playback.Index + 1)
        if not (from and to) then
            playback = nil
            return
        end

        local t = playback.Alpha
        if KeyframeEase.Enabled then
            -- Slows into and out of every keyframe, which is the difference between a camera
            -- move and a slide.
            t = t * t * (3 - 2 * t)
        end

        if #keyframes > 2 then
            pos = splinePoint(frameAt(playback.Index - 1).Position, from.Position, to.Position, frameAt(playback.Index + 2).Position, t)
        else
            pos = from.Position:Lerp(to.Position, t)
        end
        yaw = from.Yaw + shortestAngle(from.Yaw, to.Yaw) * t
        pitch = from.Pitch + (to.Pitch - from.Pitch) * t
        roll = from.Roll + (to.Roll - from.Roll) * t
        fov = from.Fov + (to.Fov - from.Fov) * t
        smoothPos, smoothYaw, smoothPitch = pos, yaw, pitch
    end

    ----------------------------------------------------------------------------------
    -- The frame
    ----------------------------------------------------------------------------------

    local function step(realDt)
        local cam = camera()
        if not cam then return end
        -- Re-asserted every frame: a respawn, or a game that drives its own camera, would
        -- otherwise take it back mid-shot.
        if cam.CameraType ~= Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Scriptable
        end

        -- One clock for everything time-based, so slow motion slows the whole shot - movement,
        -- orbit, dolly, shake, focus pulls, playback - rather than one part of it.
        local dt = math.min(realDt, 0.1) * (TimeScale.Value / 100)
        local allowed = inputAllowed()

        if allowed then
            inputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            inputService.MouseIconEnabled = false
        else
            inputService.MouseBehavior = restore.MouseBehavior or Enum.MouseBehavior.Default
            inputService.MouseIconEnabled = true
            -- The first delta after the cursor is locked again is whatever the mouse did
            -- while it was free, and reading it would throw the camera across the map.
            firstFrame = true
        end

        if playback then
            -- Any deliberate move takes the camera back off the path.
            if allowed and (keyDown(Enum.KeyCode.W) or keyDown(Enum.KeyCode.A) or keyDown(Enum.KeyCode.S) or keyDown(Enum.KeyCode.D)) then
                stopPlayback()
            else
                stepPlayback(dt)
            end
        end

        local facing = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)

        if not playback then
            if allowed and not firstFrame then
                -- The delta arrives in pixels; dividing by 360 leaves the slider reading as a
                -- sensitivity rather than an arbitrary number.
                local delta = inputService:GetMouseDelta()
                yaw -= delta.X * (Sensitivity.Value / 360)
                pitch = math.clamp(pitch - delta.Y * (Sensitivity.Value / 360), -1.5, 1.5)
                facing = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
            end
            firstFrame = false

            local forward = (allowed and keyDown(Enum.KeyCode.W) and 1 or 0) - (allowed and keyDown(Enum.KeyCode.S) and 1 or 0)
            local side = (allowed and keyDown(Enum.KeyCode.D) and 1 or 0) - (allowed and keyDown(Enum.KeyCode.A) and 1 or 0)
            local rise = (allowed and keyDown(Enum.KeyCode.E) and 1 or 0) - (allowed and keyDown(Enum.KeyCode.Q) and 1 or 0)

            local direction = (facing.RightVector * side) + (facing.UpVector * rise) + (facing.LookVector * forward)
            if direction.Magnitude > 0 then
                direction = direction.Unit
            end

            -- Shift is the precision modifier: same controls at a quarter speed, for the small
            -- adjustments that make a framing work.
            local target = direction * (Speed.Value * ((allowed and keyDown(Enum.KeyCode.LeftShift)) and 0.25 or 1))

            if Dolly.Enabled then
                -- A dolly is hands-free: the camera creeps along its own axis at a fixed rate
                -- whatever the movement keys are doing.
                target += facing.LookVector * (DollySpeed.Value * (DollyDirection.Value == 'Backward' and -1 or 1))
            end

            if Smoothing.Enabled then
                -- Getting up to speed and coming to a stop are separate rates: a camera that
                -- accelerates hard but coasts to a halt reads very differently from one that
                -- does both the same way.
                local speedingUp = target.Magnitude > velocity.Magnitude
                velocity = velocity:Lerp(target, approach(speedingUp and Acceleration.Value or Deceleration.Value, dt))
            else
                velocity = target
            end
            local nextPosition = pos + velocity * dt
            if Collision.Enabled then
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {cam, lplr.Character}
                local hit = workspace:Raycast(pos, nextPosition - pos, params)
                if hit then
                    nextPosition = hit.Position + hit.Normal * 0.35
                    velocity -= hit.Normal * velocity:Dot(hit.Normal)
                end
            end
            pos = nextPosition

            if Orbit.Enabled then
                if not orbitPivot then
                    -- Lock onto whatever the camera was pointed at when the orbit started, so
                    -- the subject holds its place in frame rather than drifting out of it.
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = {cam, lplr.Character}
                    local hit = workspace:Raycast(pos, facing.LookVector * (OrbitDistance.Value * 4), params)
                    orbitPivot = hit and hit.Position or (pos + facing.LookVector * OrbitDistance.Value)
                    local offset = pos - orbitPivot
                    orbitAngle = math.atan2(offset.X, offset.Z)
                end
                orbitAngle += math.rad(OrbitSpeed.Value) * (OrbitDirection.Value == 'Anticlockwise' and -1 or 1) * dt
                -- Height still comes from the camera, so Q and E raise and lower the orbit
                -- while it runs.
                local height = pos.Y - orbitPivot.Y
                pos = orbitPivot + Vector3.new(math.sin(orbitAngle) * OrbitDistance.Value, height, math.cos(orbitAngle) * OrbitDistance.Value)
                local toPivot = orbitPivot - pos
                if toPivot.Magnitude > 0.001 then
                    yaw = math.atan2(-toPivot.X, -toPivot.Z)
                    pitch = math.clamp(math.asin(math.clamp(toPivot.Unit.Y, -1, 1)), -1.5, 1.5)
                end
            elseif orbitPivot then
                orbitPivot, orbitAngle = nil, nil
            end

            -- Roll from the two keys, plus the automatic bank into a strafe that stops a
            -- sideways move looking like a slide.
            if Roll.Enabled then
                if allowed then
                    manualRoll += math.rad(RollSpeed.Value) * ((named('C') and 1 or 0) - (named('Z') and 1 or 0)) * dt
                end
            else
                manualRoll = 0
            end
            local bank = (Roll.Enabled and allowed) and ((keyDown(Enum.KeyCode.D) and 1 or 0) - (keyDown(Enum.KeyCode.A) and 1 or 0)) or 0
            local rollTarget = manualRoll + math.rad(Roll.Enabled and Tilt.Value or 0) * bank
            roll += (rollTarget - roll) * approach(8, dt)

            -- Field of view, and the zoom that overrides it while its key is held. Both ride
            -- the same transition, so a zoom is a move rather than a cut.
            local wantedFov = (Zoom.Enabled and allowed and named(ZoomKey.Value)) and ZoomFov.Value or Fov.Value
            fov += (wantedFov - fov) * approach(FovSpeed.Value / 10, dt)

            -- Smoothing: the camera chases the position and angle the input asked for instead
            -- of being pinned to them, which is the whole difference between a rig and a hand.
            if Smoothing.Enabled then
                local alpha = approach(SmoothAmount.Value / 10, dt)
                smoothPos = smoothPos:Lerp(pos, alpha)
                smoothYaw += shortestAngle(smoothYaw, yaw) * alpha
                smoothPitch += (pitch - smoothPitch) * alpha
            else
                smoothPos, smoothYaw, smoothPitch = pos, yaw, pitch
            end
        end

        local moveSpeed = (smoothPos - (lastPos or smoothPos)).Magnitude / math.max(realDt, 0.001)
        local turnSpeed = math.abs(shortestAngle(lastYaw or smoothYaw, smoothYaw)) / math.max(realDt, 0.001)
        lastPos, lastYaw = smoothPos, smoothYaw

        local frame = CFrame.new(smoothPos) * CFrame.fromEulerAnglesYXZ(smoothPitch, smoothYaw, roll)

        if Shake.Enabled then
            -- Perlin rather than random: neighbouring samples are related, so this reads as a
            -- hand holding the camera instead of as noise.
            shakeClock += dt * ShakeSpeed.Value
            local amp = ShakeAmount.Value / 100
            frame = frame
                * CFrame.new(math.noise(shakeClock, 0, 0) * amp * 0.35, math.noise(0, shakeClock, 0) * amp * 0.35, 0)
                * CFrame.Angles(
                    math.noise(shakeClock, 3.7, 0) * amp * 0.05,
                    math.noise(1.3, shakeClock, 0) * amp * 0.05,
                    math.noise(0, 5.1, shakeClock) * amp * 0.09
                )
        end

        cam.CFrame = frame
        cam.FieldOfView = math.clamp(fov, 1, 120)

        updateDof(dt)
        updateMotionBlur(dt, moveSpeed, turnSpeed)
    end

    ----------------------------------------------------------------------------------
    -- Enter and leave
    ----------------------------------------------------------------------------------

    local function enter()
        local cam = camera()
        if not cam then return false end

        restore.CameraType = cam.CameraType
        restore.FieldOfView = cam.FieldOfView
        restore.CameraSubject = cam.CameraSubject
        restore.MouseBehavior = inputService.MouseBehavior
        restore.MouseIcon = inputService.MouseIconEnabled
        pcall(function()
            restore.CoreGui = starterGui:GetCoreGuiEnabled(Enum.CoreGuiType.All)
        end)

        -- Picked up exactly where the game left it, so entering is a handover and not a cut.
        pos = cam.CFrame.Position
        local look = cam.CFrame.LookVector
        yaw = math.atan2(-look.X, -look.Z)
        pitch = math.asin(math.clamp(look.Y, -1, 1))
        smoothPos, smoothYaw, smoothPitch = pos, yaw, pitch
        velocity = Vector3.zero
        roll, manualRoll = 0, 0
        fov = cam.FieldOfView
        focus = FocusDistance.Value
        blurSize = 0
        orbitPivot, orbitAngle, playback = nil, nil, nil
        -- The first mouse delta after locking the cursor is whatever was left over from
        -- before, and reading it would throw the camera across the map.
        firstFrame = true
        lastPos, lastYaw = nil, nil

        active = true
        cam.CameraType = Enum.CameraType.Scriptable
        hideInterface()
        -- Roblox errors on a second bind under the same name, and a leave that failed
        -- somewhere in the middle could have left the last one in place.
        pcall(function()
            runService:UnbindFromRenderStep(bindName)
        end)

        -- Sunk so the character stays exactly where it is while the camera flies off; a
        -- freecam that walks your body around is a freecam that gets you killed.
        contextService:BindActionAtPriority(
            bindName,
            function()
                return Enum.ContextActionResult.Sink
            end,
            false,
            Enum.ContextActionPriority.High.Value,
            Enum.KeyCode.W,
            Enum.KeyCode.A,
            Enum.KeyCode.S,
            Enum.KeyCode.D,
            Enum.KeyCode.E,
            Enum.KeyCode.Q,
            Enum.KeyCode.Space,
            Enum.KeyCode.Up,
            Enum.KeyCode.Down,
            Enum.KeyCode.Left,
            Enum.KeyCode.Right
        )
        return true
    end

    local function leave()
        if not active then return end
        active = false

        pcall(function()
            contextService:UnbindAction(bindName)
        end)
        pcall(function()
            runService:UnbindFromRenderStep(bindName)
        end)

        if dofEffect then
            dofEffect:Destroy()
            dofEffect = nil
        end
        if blurEffect then
            blurEffect:Destroy()
            blurEffect = nil
        end
        releaseEffects()
        showInterface()

        local cam = camera()
        if cam then
            pcall(function()
                cam.FieldOfView = restore.FieldOfView or cam.FieldOfView
                if restore.CameraSubject then
                    cam.CameraSubject = restore.CameraSubject
                end
                -- Last, so the game's camera scripts pick straight back up instead of
                -- fighting a scriptable camera that is still being written to.
                cam.CameraType = restore.CameraType or Enum.CameraType.Custom
            end)
        end
        pcall(function()
            inputService.MouseBehavior = restore.MouseBehavior or Enum.MouseBehavior.Default
            inputService.MouseIconEnabled = restore.MouseIcon == nil and true or restore.MouseIcon
        end)
        playback = nil
        table.clear(restore)
    end

    Freecam = vape.Categories.World:CreateModule({
	Name = 'Freecam',
	Function = function(callback)
		if callback then
			if not enter() then
				return
			end
			-- Ordered after Roblox's own camera step, so whatever it decided is replaced
			-- with ours rather than the two alternating frame to frame.
			runService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function(dt)
				if not Freecam.Enabled then return end
				local ok, err = pcall(step, dt)
				if not ok then
					warn('[AetherV2] Freecam: '..tostring(err))
				end
			end)
			-- Registered as well as called below, so an uninject also puts everything back.
			Freecam:Clean(leave)
		else
			leave()
		end
	end,
	Tooltip = 'Cinematic freecam - fly, orbit, dolly and record camera moves',
    })

    Speed = Freecam:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 400,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
	Tooltip = 'Hold shift for a quarter of it'
    })
    Sensitivity = Freecam:CreateSlider({
	Name = 'Sensitivity',
	Min = 0.05,
	Max = 3,
	Default = 0.9,
	Decimal = 100
    })
    TimeScale = Freecam:CreateSlider({
	Name = 'Slow motion',
	Min = 5,
	Max = 100,
	Default = 100,
	Suffix = '%',
	Tooltip = 'Slows every camera move at once'
    })

    Smoothing = Freecam:CreateToggle({
	Name = 'Smoothing',
	Default = true,
	Function = function(call)
		for _, option in {SmoothAmount, Acceleration, Deceleration} do
			if option and option.Object then
				option.Object.Visible = call
			end
		end
	end,
	Tooltip = 'Eases the camera instead of pinning it to your input'
    })
    SmoothAmount = Freecam:CreateSlider({
	Name = 'Smooth amount',
	Min = 1,
	Max = 100,
	Default = 70,
	Darker = true,
	Tooltip = 'Lower is looser'
    })
    Acceleration = Freecam:CreateSlider({
	Name = 'Acceleration',
	Min = 1,
	Max = 40,
	Default = 10,
	Darker = true
    })
    Deceleration = Freecam:CreateSlider({
	Name = 'Deceleration',
	Min = 1,
	Max = 40,
	Default = 6,
	Darker = true
    })

    Fov = Freecam:CreateSlider({
	Name = 'Field of view',
	Min = 15,
	Max = 120,
	Default = 70
    })
    FovSpeed = Freecam:CreateSlider({
	Name = 'FOV transition',
	Min = 1,
	Max = 100,
	Default = 35,
	Tooltip = 'How fast the field of view moves'
    })
    Zoom = Freecam:CreateToggle({
	Name = 'Zoom',
	Function = function(call)
		for _, option in {ZoomFov, ZoomKey} do
			if option and option.Object then
				option.Object.Visible = call
			end
		end
	end,
	Tooltip = 'Hold a key to push in'
    })
    ZoomFov = Freecam:CreateSlider({
	Name = 'Zoom FOV',
	Min = 3,
	Max = 90,
	Default = 25,
	Darker = true,
	Visible = false
    })
    ZoomKey = Freecam:CreateDropdown({
	Name = 'Zoom key',
	List = {'X', 'C', 'V', 'F', 'G', 'R', 'T', 'LeftControl', 'LeftAlt'},
	Default = 'X',
	Darker = true,
	Visible = false
    })

    Roll = Freecam:CreateToggle({
	Name = 'Roll and tilt',
	Function = function(call)
		for _, option in {RollSpeed, Tilt} do
			if option and option.Object then
				option.Object.Visible = call
			end
		end
	end,
	Tooltip = 'Z and C roll the camera'
    })
    RollSpeed = Freecam:CreateSlider({
	Name = 'Roll speed',
	Min = 5,
	Max = 180,
	Default = 45,
	Suffix = 'deg/s',
	Darker = true,
	Visible = false
    })
    Tilt = Freecam:CreateSlider({
	Name = 'Strafe tilt',
	Min = 0,
	Max = 30,
	Default = 6,
	Suffix = 'deg',
	Darker = true,
	Visible = false,
	Tooltip = 'Banks into sideways moves'
    })

    Shake = Freecam:CreateToggle({
	Name = 'Camera shake',
	Function = function(call)
		for _, option in {ShakeAmount, ShakeSpeed} do
			if option and option.Object then
				option.Object.Visible = call
			end
		end
	end,
	Tooltip = 'Handheld wobble'
    })
    ShakeAmount = Freecam:CreateSlider({
	Name = 'Shake amount',
	Min = 1,
	Max = 100,
	Default = 25,
	Darker = true,
	Visible = false
    })
    ShakeSpeed = Freecam:CreateSlider({
	Name = 'Shake speed',
	Min = 0.1,
	Max = 10,
	Default = 1.5,
	Decimal = 10,
	Darker = true,
	Visible = false
    })

    Dof = Freecam:CreateToggle({
	Name = 'Depth of field',
	Function = function(call)
		for _, option in {AutoFocus, FocusDistance, FocusRange, DofStrength} do
			if option and option.Object then
				option.Object.Visible = call
			end
		end
	end
    })
    AutoFocus = Freecam:CreateToggle({
	Name = 'Auto focus',
	Default = true,
	Darker = true,
	Visible = false,
	Tooltip = 'Focuses on whatever is centre frame'
    })
    FocusDistance = Freecam:CreateSlider({
	Name = 'Focus distance',
	Min = 1,
	Max = 500,
	Default = 25,
	Suffix = 'studs',
	Darker = true,
	Visible = false
    })
    FocusRange = Freecam:CreateSlider({
	Name = 'In focus range',
	Min = 1,
	Max = 200,
	Default = 20,
	Suffix = 'studs',
	Darker = true,
	Visible = false
    })
    DofStrength = Freecam:CreateSlider({
	Name = 'Blur strength',
	Min = 1,
	Max = 100,
	Default = 70,
	Darker = true,
	Visible = false
    })

    MotionBlur = Freecam:CreateToggle({
	Name = 'Motion blur',
	Function = function(call)
		if MotionBlurAmount and MotionBlurAmount.Object then
			MotionBlurAmount.Object.Visible = call
		end
	end,
	Tooltip = 'Blurs with the speed of the move'
    })
    MotionBlurAmount = Freecam:CreateSlider({
	Name = 'Motion blur amount',
	Min = 1,
	Max = 100,
	Default = 35,
	Darker = true,
	Visible = false
    })

    Orbit = Freecam:CreateToggle({
	Name = 'Orbit',
	Function = function(call)
		for _, option in {OrbitDirection, OrbitSpeed, OrbitDistance} do
			if option and option.Object then
				option.Object.Visible = call
			end
		end
	end,
	Tooltip = 'Circles whatever you were pointed at'
    })
    OrbitDirection = Freecam:CreateDropdown({
	Name = 'Orbit direction',
	List = {'Clockwise', 'Anticlockwise'},
	Default = 'Clockwise',
	Darker = true,
	Visible = false
    })
    OrbitSpeed = Freecam:CreateSlider({
	Name = 'Orbit speed',
	Min = 1,
	Max = 120,
	Default = 15,
	Suffix = 'deg/s',
	Darker = true,
	Visible = false
    })
    OrbitDistance = Freecam:CreateSlider({
	Name = 'Orbit distance',
	Min = 3,
	Max = 200,
	Default = 25,
	Suffix = 'studs',
	Darker = true,
	Visible = false
    })

    Dolly = Freecam:CreateToggle({
	Name = 'Dolly',
	Function = function(call)
		for _, option in {DollyDirection, DollySpeed} do
			if option and option.Object then
				option.Object.Visible = call
			end
		end
	end,
	Tooltip = 'Creeps along the camera axis on its own'
    })
    DollyDirection = Freecam:CreateDropdown({
	Name = 'Dolly direction',
	List = {'Forward', 'Backward'},
	Default = 'Forward',
	Darker = true,
	Visible = false
    })
    DollySpeed = Freecam:CreateSlider({
	Name = 'Dolly speed',
	Min = 0.5,
	Max = 60,
	Default = 4,
	Decimal = 10,
	Darker = true,
	Visible = false
    })

    Freecam:CreateButton({
	Name = 'Save keyframe',
	Function = function()
		if not Freecam.Enabled then
			notif('Freecam', 'Turn Freecam on first', 5, 'alert')
			return
		end
		table.insert(keyframes, snapshot())
		notif('Freecam', 'Keyframe '..#keyframes..' saved', 3, 'info')
	end,
	Tooltip = 'Records where the camera is and how it is pointed'
    })
    Freecam:CreateButton({
	Name = 'Play keyframes',
	Function = function()
		if not Freecam.Enabled then
			notif('Freecam', 'Turn Freecam on first', 5, 'alert')
			return
		end
		if playback then
			stopPlayback()
		else
			startPlayback()
		end
	end,
	Tooltip = 'Runs the path, or stops one already running'
    })
    Freecam:CreateButton({
	Name = 'Clear keyframes',
	Function = function()
		stopPlayback()
		table.clear(keyframes)
		notif('Freecam', 'Keyframes cleared', 3, 'info')
	end
    })
    PathName = Freecam:CreateTextBox({Name = 'Path name', Placeholder = 'Camera path'})
    PathTarget = Freecam:CreateTextBox({Name = 'Path copy name', Placeholder = 'New name for rename or duplicate'})
    PathAction = Freecam:CreateDropdown({Name = 'Path action', List = {'Save', 'Load', 'Duplicate', 'Rename', 'Delete', 'Update keyframe', 'Delete keyframe'}})
    KeyframeIndex = Freecam:CreateSlider({Name = 'Keyframe', Min = 1, Max = 100, Default = 1, Darker = true})
    Freecam:CreateButton({
        Name = 'Apply path action',
        Function = function()
            local name, action = safePathName(), PathAction.Value
            if name == '' then notif('Freecam', 'Enter a path name', 4, 'alert'); return end
            if not isfolder(pathFolder) then makefolder(pathFolder) end
            local path = pathFolder..'/'..name..'.json'
            if action == 'Save' or action == 'Duplicate' then
                if #keyframes == 0 then notif('Freecam', 'Add a keyframe first', 4, 'alert'); return end
                local target = action == 'Duplicate' and tostring(PathTarget.Value):gsub('[^%w%-%_ ]', ''):sub(1, 40) or name
                if target == '' then notif('Freecam', 'Enter a copy name', 4, 'alert'); return end
                writefile(pathFolder..'/'..target..'.json', httpService:JSONEncode(encodeFrames()))
            elseif action == 'Load' then
                local ok, data = pcall(function() return httpService:JSONDecode(readfile(path)) end)
                if not ok or not decodeFrames(data) then notif('Freecam', 'Camera path is missing or corrupt', 5, 'alert'); return end
            elseif action == 'Rename' then
                if not isfile(path) then notif('Freecam', 'Camera path not found', 4, 'alert'); return end
                local renamed = tostring(PathTarget.Value):gsub('[^%w%-%_ ]', ''):sub(1, 40)
                if renamed == '' then notif('Freecam', 'Enter a new name', 4, 'alert'); return end
                writefile(pathFolder..'/'..renamed..'.json', readfile(path)); delfile(path)
            elseif action == 'Delete' then
                if isfile(path) then delfile(path) end
            elseif action == 'Update keyframe' then
                local index = math.clamp(KeyframeIndex.Value, 1, #keyframes)
                if not keyframes[index] then notif('Freecam', 'Keyframe not found', 4, 'alert'); return end
                keyframes[index] = snapshot()
            elseif action == 'Delete keyframe' then
                local index = math.clamp(KeyframeIndex.Value, 1, #keyframes)
                if keyframes[index] then table.remove(keyframes, index) end
            end
            notif('Freecam', action..' complete', 3, 'info')
        end
    })
    KeyframeTime = Freecam:CreateSlider({
	Name = 'Keyframe time',
	Min = 0.2,
	Max = 30,
	Default = 4,
	Decimal = 10,
	Suffix = 'sec',
	Darker = true,
	Tooltip = 'Seconds between keyframes'
    })
    KeyframeEase = Freecam:CreateToggle({
	Name = 'Ease keyframes',
	Default = true,
	Darker = true,
	Tooltip = 'Slows into and out of each one'
    })
    KeyframeLoop = Freecam:CreateToggle({
	Name = 'Loop keyframes',
	Darker = true
    })

    HideHud = Freecam:CreateToggle({
	Name = 'Hide HUD',
	Function = refreshInterface,
	Tooltip = 'Hides the game interface while filming. The AetherV2 menu stays up'
    })
    Collision = Freecam:CreateToggle({Name = 'Camera collision', Default = true, Tooltip = 'Slides along solid geometry'})
end)

run(function()
	local ForcePlayerCollisions
	local Mode
	local ForceCollision

	local originals = setmetatable({}, {__mode = 'k'})
	local hitboxes = setmetatable({}, {__mode = 'k'})

	local function getBodyParts(character)
		local parts = {}

		if not character then
			return parts
		end

		for _, part in ipairs(character:GetChildren()) do
			if part:IsA('BasePart')
				and part.Name ~= 'HumanoidRootPart'
				and part.Name ~= 'Humanoid' then
				table.insert(parts, part)
			end
		end

		return parts
	end

	local function applyReal(character, state)
		if not character then return end

		for _, part in ipairs(getBodyParts(character)) do
			if originals[part] == nil then
				originals[part] = part.CanCollide
			end

			part.CanCollide = state
		end
	end

	local function restoreReal()
		for part, state in pairs(originals) do
			if part and part.Parent then
				part.CanCollide = state
			end

			originals[part] = nil
		end
	end

	local function removeHitbox(character)
		local folder = hitboxes[character]

		if folder then
			folder:Destroy()
			hitboxes[character] = nil
		end
	end

	local function createHitbox(character)
		if not character or not character.Parent then
			return
		end

		removeHitbox(character)

		local folder = Instance.new('Folder')
		folder.Name = 'PlayerCollisionHitbox'
		folder.Parent = character

		hitboxes[character] = folder

		for _, original in ipairs(getBodyParts(character)) do
			local hitbox = Instance.new('Part')
			hitbox.Name = original.Name .. '_Collision'
			hitbox.Size = original.Size
			hitbox.CFrame = original.CFrame
			hitbox.Transparency = 1
			hitbox.CanCollide = true
			hitbox.CanTouch = false
			hitbox.CanQuery = false
			hitbox.CastShadow = false
			hitbox.Massless = true
			hitbox.Anchored = false
			hitbox.Parent = folder

			local weld = Instance.new('WeldConstraint')
			weld.Part0 = hitbox
			weld.Part1 = original
			weld.Parent = hitbox
		end
	end

	local function clearHitboxes()
		for character, folder in pairs(hitboxes) do
			if folder then
				folder:Destroy()
			end

			hitboxes[character] = nil
		end
	end

	local function update()
		restoreReal()
		clearHitboxes()

		if not ForcePlayerCollisions.Enabled then
			return
		end

		for _, player in ipairs(playersService:GetPlayers()) do
			if player ~= lplr and player.Character then
				if Mode.Value == 'Real' then
					applyReal(player.Character, true)
				elseif Mode.Value == 'Hitbox' then
					createHitbox(player.Character)
				end
			end
		end
	end

	ForcePlayerCollisions = vape.Categories.World:CreateModule({
		Name = 'ForcePlayerCollisions',

		Function = function(callback)
			if callback then
				ForcePlayerCollisions:Clean(
					playersService.PlayerAdded:Connect(function(player)
						ForcePlayerCollisions:Clean(
							player.CharacterAdded:Connect(function()
								task.wait()
								update()
							end)
						)
					end)
				)

				ForcePlayerCollisions:Clean(
					runService.PreSimulation:Connect(function()
						if Mode.Value == 'Real'
							and ForceCollision.Value == 'On' then

							for _, player in ipairs(playersService:GetPlayers()) do
								if player ~= lplr and player.Character then
									applyReal(player.Character, true)
								end
							end
						end
					end)
				)

				update()
			else
				restoreReal()
				clearHitboxes()
			end
		end,

		ExtraText = function()
			return Mode.Value
		end,

		Tooltip = 'Makes other players physically collidable.'
	})

	Mode = ForcePlayerCollisions:CreateDropdown({
		Name = 'Mode',
		List = {'Real', 'Hitbox'},
		Default = 'Hitbox',
		Function = function(value)
			ForceCollision.Visible = value == 'Real'
			update()
		end
	})

	ForceCollision = ForcePlayerCollisions:CreateDropdown({
		Name = 'Force Collision',
		List = {'On', 'Off'},
		Default = 'On'
	})

	ForceCollision.Visible = Mode.Value == 'Real'
end)

run(function()
    local Gravity
    local Mode
    local Value
    local changed, old = false

    Gravity = vape.Categories.World:CreateModule({
	Name = 'Gravity',
	Function = function(callback)
		if callback then
			if Mode.Value == 'Workspace' then
				old = workspace.Gravity
				workspace.Gravity = Value.Value
				Gravity:Clean(workspace:GetPropertyChangedSignal('Gravity'):Connect(function()
					if changed then
						return
					end
					changed = true
					old = workspace.Gravity
					workspace.Gravity = Value.Value
					changed = false
				end))
			else
				Gravity:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
						local root = entitylib.character.RootPart
						if Mode.Value == 'Impulse' then
							root:ApplyImpulse(
								Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0) * root.AssemblyMass
							)
						else
							root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0)
						end
					end
				end))
			end
		else
			if old then
				workspace.Gravity = old
				old = nil
			end
		end
	end,
	Tooltip = 'Changes the rate you fall',
    })
    Mode = Gravity:CreateDropdown({
	Name = 'Mode',
	List = { 'Workspace', 'Velocity', 'Impulse' },
	Tooltip = 'Workspace - gravity for the whole game\nVelocity - only yours\nImpulse - the same using forces',
    })
    Value = Gravity:CreateSlider({
	Name = 'Gravity',
	Min = 0,
	Max = 192,
	Function = function(val)
		if Gravity.Enabled and Mode.Value == 'Workspace' then
			changed = true
			workspace.Gravity = val
			changed = false
		end
	end,
	Default = 192,
    })
end)


run(function()
    local Parkour

    Parkour = vape.Categories.World:CreateModule({
	Name = 'Parkour',
	Function = function(callback)
		if callback then
			local oldfloor
			Parkour:Clean(runService.RenderStepped:Connect(function()
				if entitylib.isAlive then
					local material = entitylib.character.Humanoid.FloorMaterial
					if material == Enum.Material.Air and oldfloor ~= Enum.Material.Air then
						entitylib.character.Humanoid.Jump = true
					end
					oldfloor = material
				end
			end))
		end
	end,
	Tooltip = 'Automatically jumps after reaching the edge',
    })
end)

run(function()
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local module, old

    vape.Categories.World:CreateModule({
	Name = 'SafeWalk',
	Function = function(callback)
		if callback then
			if not module then
				local suc = pcall(function()
					module = require(lplr.PlayerScripts.PlayerModule).controls
				end)
				if not suc then
					module = {}
				end
			end

			old = module.moveFunction
			module.moveFunction = function(self, vec, face)
				if entitylib.isAlive then
					rayCheck.FilterDescendantsInstances = { lplr.Character, gameCamera }
					local root = entitylib.character.RootPart
					local movedir = root.Position + vec
					local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
					if not ray then
						local check = workspace:Blockcast(
							root.CFrame,
							Vector3.new(3, 1, 3),
							Vector3.new(0, -(entitylib.character.HipHeight + 1), 0),
							rayCheck
						)
						if check then
							vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position)
								* Vector3.new(1, 0, 1)
						end
					end
				end

				return old(self, vec, face)
			end
		else
			if module and old then
				module.moveFunction = old
			end
		end
	end,
	Tooltip = 'Prevents you from walking off the edge of parts',
    })
end)

run(function()
    local Xray
    local List
    local modified = {}

    local function modifyPart(v)
	if v:IsA('BasePart') and not table.find(List.ListEnabled, v.Name) then
		modified[v] = true
		v.LocalTransparencyModifier = 0.5
	end
    end

    Xray = vape.Categories.World:CreateModule({
	Name = 'Xray',
	Function = function(callback)
		if callback then
			Xray:Clean(workspace.DescendantAdded:Connect(modifyPart))
			for _, v in workspace:GetDescendants() do
				modifyPart(v)
			end
		else
			for i in modified do
				i.LocalTransparencyModifier = 0
			end
			table.clear(modified)
		end
	end,
	Tooltip = 'Renders whitelisted parts through walls',
    })
    List = Xray:CreateTextList({
	Name = 'Part',
	Function = function()
		if Xray.Enabled then
			Xray:Toggle()
			Xray:Toggle()
		end
	end,
    })
end)


--[[
    Legit
]]

run(function()
    local Theme, Preset, LockTime, ClockTime, RemoveClouds, Custom
    local Brightness, Exposure, ShadowSoftness, Diffuse, Specular
    local Ambient, OutdoorAmbient, TopShift, BottomShift
    local AtmosphereEnabled, AtmosphereColor, AtmosphereDecay, Density, Offset, Glare, Haze
    local BloomEnabled, BloomIntensity, BloomSize, BloomThreshold
    local ColorEnabled, Tint, Saturation, Contrast, ColorBrightness
    local RaysEnabled, RaysIntensity, RaysSpread, DepthEnabled, FarIntensity, FocusDistance, NearIntensity
    local CloudsEnabled, CloudCover, CloudDensity, CloudColor, CloudSize, CloudTransparency
    local GlobalShadows, Latitude, Technology
    local SkyEnabled, Skybox, SunTexture, MoonTexture, Stars, SunSize, MoonSize
    local WaterColor, WaterReflectance, WaterTransparency, WaterWaveSize, WaterWaveSpeed, UnderMapWater
    local created, preserved, lightingOriginal = {}, {}, {}
	local cloudOriginal
    local terrainOriginal, waterPart
    local cloudParts = setmetatable({}, {__mode = 'k'})
    local applying = false

    local lightingProperties = {'Ambient', 'Brightness', 'ColorShift_Bottom', 'ColorShift_Top', 'EnvironmentDiffuseScale', 'EnvironmentSpecularScale', 'ExposureCompensation', 'GlobalShadows', 'OutdoorAmbient', 'ShadowSoftness', 'ClockTime', 'GeographicLatitude', 'Technology'}
    local terrainProperties = {'WaterColor', 'WaterReflectance', 'WaterTransparency', 'WaterWaveSize', 'WaterWaveSpeed'}
    local effectClasses = {Sky = true, Atmosphere = true, BloomEffect = true, DepthOfFieldEffect = true, ColorCorrectionEffect = true, SunRaysEffect = true}
    local presets = {
        Default = {ClockTime = 14, Brightness = 2, Exposure = 0, Ambient = Color3.fromRGB(128,128,128), Outdoor = Color3.fromRGB(128,128,128), Atmosphere = false, Bloom = false},
        Shader = {ClockTime = 14, Brightness = 2.5, Exposure = -0.5, Ambient = Color3.fromRGB(20,20,20), Outdoor = Color3.fromRGB(30,30,30), Atmosphere = true, AtmosphereColor = Color3.fromRGB(103,103,103), Decay = Color3.fromRGB(80,80,80), Density = .3, Glare = .8, Bloom = true, BloomIntensity = 1, BloomSize = 56, BloomThreshold = .5, Contrast = .3, Saturation = -.2},
        Realistic = {ClockTime = 6.47, Brightness = 2.5, Exposure = .05, Ambient = Color3.fromRGB(55,55,55), Outdoor = Color3.fromRGB(55,55,55), Atmosphere = true, AtmosphereColor = Color3.fromRGB(185,185,185), Decay = Color3.fromRGB(95,102,115), Density = .35, Offset = .3, Bloom = true, BloomIntensity = .4, BloomSize = 22, BloomThreshold = 2.2},
        Blavish = {ClockTime = 6.1, Brightness = 2, Exposure = 0, Ambient = Color3.fromRGB(30,45,75), Outdoor = Color3.fromRGB(45,65,100), Atmosphere = true, AtmosphereColor = Color3.fromRGB(55,125,255), Decay = Color3.fromRGB(25,255,190), Density = .1, Glare = .1, Bloom = false},
        Aurora = {ClockTime = 1.5, Brightness = 1.4, Exposure = .1, Ambient = Color3.fromRGB(30,45,75), Outdoor = Color3.fromRGB(45,65,90), Atmosphere = true, AtmosphereColor = Color3.fromRGB(80,145,190), Decay = Color3.fromRGB(25,65,85), Density = .28, Haze = 1.2, Bloom = true, BloomIntensity = .5, BloomSize = 32, BloomThreshold = 1.4, Saturation = .2},
        Storm = {ClockTime = 15.5, Brightness = 1.1, Exposure = -.35, Ambient = Color3.fromRGB(38,43,52), Outdoor = Color3.fromRGB(48,55,65), Atmosphere = true, AtmosphereColor = Color3.fromRGB(95,105,120), Decay = Color3.fromRGB(42,48,60), Density = .48, Haze = 2.5, Bloom = true, BloomIntensity = .18, BloomSize = 18, BloomThreshold = 1.8, Saturation = -.35, Contrast = .18},
        Abyssal = {ClockTime = 0, Brightness = .7, Exposure = -.55, Ambient = Color3.fromRGB(5,18,28), Outdoor = Color3.fromRGB(8,28,38), Atmosphere = true, AtmosphereColor = Color3.fromRGB(10,70,85), Decay = Color3.fromRGB(0,18,30), Density = .62, Haze = 3.5, Bloom = true, BloomIntensity = .35, BloomSize = 30, BloomThreshold = 1.1, Saturation = -.1, Contrast = .3},
        Sunset = {ClockTime = 18.2, Brightness = 2.1, Exposure = .08, Ambient = Color3.fromRGB(105,70,85), Outdoor = Color3.fromRGB(150,95,75), Atmosphere = true, AtmosphereColor = Color3.fromRGB(255,155,110), Decay = Color3.fromRGB(95,45,85), Density = .3, Glare = .35, Bloom = true, BloomIntensity = .32, BloomSize = 24, BloomThreshold = 1.5, Saturation = .15},
        Night = {ClockTime = 0, Brightness = 1, Exposure = -.2, Ambient = Color3.fromRGB(20,25,55), Outdoor = Color3.fromRGB(25,35,65), Atmosphere = true, AtmosphereColor = Color3.fromRGB(55,70,125), Decay = Color3.fromRGB(15,20,45), Density = .25, Bloom = true, BloomIntensity = .2, BloomSize = 20, BloomThreshold = 1.8}
    }

    local function safeSet(object, property, value) if value ~= nil then pcall(function() object[property] = value end) end end
    local function colorValue(option) return Color3.fromHSV(option.Hue, option.Sat, option.Value) end
    local function remember(object, property, destination)
        if destination[property] == nil then pcall(function() destination[property] = object[property] end) end
    end
    local function removeEffects()
        for _, object in created do pcall(function() object:Destroy() end) end
        table.clear(created)
    end
    local function restore()
        removeEffects()
        for _, state in preserved do if state.Object then pcall(function() state.Object.Parent = state.Parent end) end end
        table.clear(preserved)
        for property, value in lightingOriginal do safeSet(lightingService, property, value) end
        table.clear(lightingOriginal)
		if terrainOriginal and terrainOriginal.Object then for property, value in terrainOriginal.Properties do safeSet(terrainOriginal.Object, property, value) end end
		terrainOriginal = nil
		if waterPart then waterPart:Destroy(); waterPart = nil end
		for part, state in cloudParts do if part.Parent then safeSet(part, 'Size', state.Size); safeSet(part, 'Color', state.Color); safeSet(part, 'Transparency', state.Transparency) end end
		table.clear(cloudParts)
		if cloudOriginal and cloudOriginal.Object then
			for property, value in cloudOriginal.Properties do
				safeSet(cloudOriginal.Object, property, value)
			end
		end
		cloudOriginal = nil
    end
    local function add(class, properties)
        local object = Instance.new(class)
        object.Name = 'AetherTheme'..class
        for property, value in properties do safeSet(object, property, value) end
        object.Parent = lightingService
        table.insert(created, object)
        return object
    end
    local function profileValue(profile, key, custom)
        if Custom.Enabled or Preset.Value == 'Custom' then return custom end
        local value = profile[key]
        return value == nil and custom or value
    end
    local function apply()
        if not Theme or not Theme.Enabled or applying then return end
        applying = true
        removeEffects()
        local profile = presets[Preset.Value] or presets.Default
        safeSet(lightingService, 'ClockTime', profileValue(profile, 'ClockTime', ClockTime.Value))
        safeSet(lightingService, 'Brightness', profileValue(profile, 'Brightness', Brightness.Value))
        safeSet(lightingService, 'ExposureCompensation', profileValue(profile, 'Exposure', Exposure.Value))
        safeSet(lightingService, 'ShadowSoftness', ShadowSoftness.Value)
        safeSet(lightingService, 'EnvironmentDiffuseScale', Diffuse.Value)
        safeSet(lightingService, 'EnvironmentSpecularScale', Specular.Value)
        safeSet(lightingService, 'GlobalShadows', GlobalShadows.Enabled)
		safeSet(lightingService, 'GeographicLatitude', Latitude.Value)
		if Technology.Value ~= 'Automatic' then safeSet(lightingService, 'Technology', Enum.Technology[Technology.Value]) end
        safeSet(lightingService, 'Ambient', profileValue(profile, 'Ambient', colorValue(Ambient)))
        safeSet(lightingService, 'OutdoorAmbient', profileValue(profile, 'Outdoor', colorValue(OutdoorAmbient)))
        safeSet(lightingService, 'ColorShift_Top', colorValue(TopShift))
        safeSet(lightingService, 'ColorShift_Bottom', colorValue(BottomShift))
		if SkyEnabled.Enabled then
			local faces = Skybox.Value ~= '' and Skybox.Value or nil
			add('Sky', {SkyboxBk = faces, SkyboxDn = faces, SkyboxFt = faces, SkyboxLf = faces, SkyboxRt = faces, SkyboxUp = faces,
				SunTextureId = SunTexture.Value, MoonTextureId = MoonTexture.Value, StarCount = Stars.Value, SunAngularSize = SunSize.Value, MoonAngularSize = MoonSize.Value})
		end

        if profileValue(profile, 'Atmosphere', AtmosphereEnabled.Enabled) then
            add('Atmosphere', {Color = profileValue(profile, 'AtmosphereColor', colorValue(AtmosphereColor)), Decay = profileValue(profile, 'Decay', colorValue(AtmosphereDecay)), Density = profileValue(profile, 'Density', Density.Value), Offset = profileValue(profile, 'Offset', Offset.Value), Glare = profileValue(profile, 'Glare', Glare.Value), Haze = profileValue(profile, 'Haze', Haze.Value)})
        end
        if profileValue(profile, 'Bloom', BloomEnabled.Enabled) then
            add('BloomEffect', {Intensity = profileValue(profile, 'BloomIntensity', BloomIntensity.Value), Size = profileValue(profile, 'BloomSize', BloomSize.Value), Threshold = profileValue(profile, 'BloomThreshold', BloomThreshold.Value)})
        end
        if ColorEnabled.Enabled then add('ColorCorrectionEffect', {TintColor = colorValue(Tint), Saturation = profileValue(profile, 'Saturation', Saturation.Value), Contrast = profileValue(profile, 'Contrast', Contrast.Value), Brightness = ColorBrightness.Value}) end
        if RaysEnabled.Enabled then add('SunRaysEffect', {Intensity = RaysIntensity.Value, Spread = RaysSpread.Value}) end
        if DepthEnabled.Enabled then add('DepthOfFieldEffect', {FarIntensity = FarIntensity.Value, FocusDistance = FocusDistance.Value, InFocusRadius = FocusDistance.Value, NearIntensity = NearIntensity.Value}) end

        local terrain = workspace:FindFirstChildOfClass('Terrain')
        if terrain then
			safeSet(terrain, 'WaterColor', colorValue(WaterColor)); safeSet(terrain, 'WaterReflectance', WaterReflectance.Value)
			safeSet(terrain, 'WaterTransparency', WaterTransparency.Value); safeSet(terrain, 'WaterWaveSize', WaterWaveSize.Value); safeSet(terrain, 'WaterWaveSpeed', WaterWaveSpeed.Value)
            local clouds = terrain:FindFirstChildOfClass('Clouds')
            if RemoveClouds.Enabled then
                if clouds then safeSet(clouds, 'Enabled', false) end
            elseif CloudsEnabled.Enabled then
                if not clouds then clouds = Instance.new('Clouds'); clouds.Name = 'AetherThemeClouds'; clouds.Parent = terrain; table.insert(created, clouds) end
                safeSet(clouds, 'Enabled', true); safeSet(clouds, 'Cover', CloudCover.Value); safeSet(clouds, 'Density', CloudDensity.Value); safeSet(clouds, 'Color', colorValue(CloudColor))
            end
			if UnderMapWater.Enabled and not waterPart then
				waterPart = Instance.new('Part'); waterPart.Name = 'AetherThemeUnderMapWater'; waterPart.Anchored = true; waterPart.CanCollide = false
				waterPart.Material = Enum.Material.Glass; waterPart.Color = colorValue(WaterColor); waterPart.Transparency = math.clamp(WaterTransparency.Value, 0, 1)
				waterPart.Size = Vector3.new(4096, 2, 4096); waterPart.Position = Vector3.new(0, -25, 0); waterPart.Parent = workspace
			elseif not UnderMapWater.Enabled and waterPart then waterPart:Destroy(); waterPart = nil end
        end
		local cloudFolder = workspace:FindFirstChild('Clouds')
		if cloudFolder then
			for _, part in cloudFolder:GetDescendants() do
				if part:IsA('BasePart') then
					cloudParts[part] = cloudParts[part] or {Size = part.Size, Color = part.Color, Transparency = part.Transparency}
					local original = cloudParts[part]
					safeSet(part, 'Size', original.Size * CloudSize.Value); safeSet(part, 'Color', colorValue(CloudColor)); safeSet(part, 'Transparency', CloudTransparency.Value)
				end
			end
		end
        applying = false
    end
    local function changed() if Theme and Theme.Enabled then apply() end end
	local function populatePreset()
		local profile = presets[Preset.Value]
		if not profile then return end
		local function set(option, value)
			if not option or value == nil or not option.SetValue then return end
			-- Color3 exposes ToHSV as an instance method. Calling the non-existent
			-- static variant aborted preset application before the lighting pass.
			if typeof(value) == 'Color3' then option:SetValue(value:ToHSV()) else option:SetValue(value) end
		end
		set(ClockTime, profile.ClockTime); set(Brightness, profile.Brightness); set(Exposure, profile.Exposure)
		set(Ambient, profile.Ambient); set(OutdoorAmbient, profile.Outdoor); set(AtmosphereEnabled, profile.Atmosphere)
		set(AtmosphereColor, profile.AtmosphereColor); set(AtmosphereDecay, profile.Decay); set(Density, profile.Density)
		set(Offset, profile.Offset); set(Glare, profile.Glare); set(Haze, profile.Haze); set(BloomEnabled, profile.Bloom)
		set(BloomIntensity, profile.BloomIntensity); set(BloomSize, profile.BloomSize); set(BloomThreshold, profile.BloomThreshold)
		set(Saturation, profile.Saturation); set(Contrast, profile.Contrast)
	end

    Theme = vape.Categories.Render:CreateModule({Name = 'Theme', Function = function(enabled)
        if enabled then
            for _, property in lightingProperties do remember(lightingService, property, lightingOriginal) end
            for _, object in lightingService:GetChildren() do if effectClasses[object.ClassName] then table.insert(preserved, {Object = object, Parent = object.Parent}); object.Parent = game end end
            local terrain = workspace:FindFirstChildOfClass('Terrain')
			if terrain then terrainOriginal = {Object = terrain, Properties = {}}; for _, property in terrainProperties do remember(terrain, property, terrainOriginal.Properties) end end
            local clouds = terrain and terrain:FindFirstChildOfClass('Clouds')
			if clouds then
				cloudOriginal = {Object = clouds, Properties = {}}
				for _, property in {'Enabled','Cover','Density','Color'} do
					remember(clouds, property, cloudOriginal.Properties)
				end
			end
            apply()
            Theme:Clean(lightingService:GetPropertyChangedSignal('ClockTime'):Connect(function()
                if not Theme.Enabled or not LockTime.Enabled or applying then return end
                -- Roblox advances ClockTime frequently. Rebuilding every post-processing object,
                -- rescanning clouds and rewriting terrain for a clock tick caused avoidable spikes.
                local profile = presets[Preset.Value] or presets.Default
                applying = true
                safeSet(lightingService, 'ClockTime', profileValue(profile, 'ClockTime', ClockTime.Value))
                applying = false
            end))
			Theme:Clean(workspace.ChildAdded:Connect(function(child) if child.Name == 'Clouds' or child:IsA('Terrain') then task.defer(apply) end end))
			Theme:Clean(lplr.CharacterAdded:Connect(function() task.defer(apply) end))
        else restore() end
    end, Tooltip = 'One customizable world-lighting, atmosphere, sky and post-processing theme'})
    Preset = Theme:CreateDropdown({Name = 'Preset', List = {'Realistic','Blavish','Custom'}, Default = 'Realistic', Function = function() if UnderMapWater then populatePreset() end; changed() end})
    Custom = Theme:CreateToggle({Name = 'Custom overrides', Tooltip = 'Use every slider and color below instead of the selected preset values', Function = changed})
    LockTime = Theme:CreateToggle({Name = 'Lock time', Default = true, Function = changed})
    ClockTime = Theme:CreateSlider({Name = 'Clock time', Min = 0, Max = 24, Default = 14, Decimal = 10, Suffix = 'h', Function = changed})
    Brightness = Theme:CreateSlider({Name = 'Brightness', Min = 0, Max = 10, Default = 2, Decimal = 100, Function = changed})
    Exposure = Theme:CreateSlider({Name = 'Exposure', Min = -3, Max = 3, Default = 0, Decimal = 100, Function = changed})
    ShadowSoftness = Theme:CreateSlider({Name = 'Shadow softness', Min = 0, Max = 1, Default = .2, Decimal = 100, Function = changed})
    Diffuse = Theme:CreateSlider({Name = 'Diffuse scale', Min = 0, Max = 1, Default = .8, Decimal = 100, Function = changed})
    Specular = Theme:CreateSlider({Name = 'Specular scale', Min = 0, Max = 1, Default = .8, Decimal = 100, Function = changed})
    GlobalShadows = Theme:CreateToggle({Name = 'Shadows', Default = true, Function = changed})
    Latitude = Theme:CreateSlider({Name = 'Latitude', Min = -180, Max = 180, Default = 41, Function = changed})
    Technology = Theme:CreateDropdown({Name = 'Technology', List = {'Automatic','Compatibility','Voxel','ShadowMap','Future'}, Default = 'Automatic', Function = changed})
    Ambient = Theme:CreateColorSlider({Name = 'Ambient', DefaultValue = .6, Function = changed})
    OutdoorAmbient = Theme:CreateColorSlider({Name = 'Outdoor ambient', DefaultValue = .6, Function = changed})
    TopShift = Theme:CreateColorSlider({Name = 'Top color shift', DefaultValue = 0, Function = changed})
    BottomShift = Theme:CreateColorSlider({Name = 'Bottom color shift', DefaultValue = 0, Function = changed})
    SkyEnabled = Theme:CreateToggle({Name = 'Sky', Default = true, Function = changed})
    Skybox = Theme:CreateTextBox({Name = 'Skybox', Placeholder = 'rbxassetid://', Function = changed})
    SunTexture = Theme:CreateTextBox({Name = 'Sun texture', Placeholder = 'rbxasset://sky/sun.jpg', Function = changed})
    MoonTexture = Theme:CreateTextBox({Name = 'Moon texture', Placeholder = 'rbxasset://sky/moon.jpg', Function = changed})
    Stars = Theme:CreateSlider({Name = 'Stars', Min = 0, Max = 5000, Default = 3000, Function = changed})
    SunSize = Theme:CreateSlider({Name = 'Sun size', Min = 0, Max = 21, Default = 21, Decimal = 10, Function = changed})
    MoonSize = Theme:CreateSlider({Name = 'Moon size', Min = 0, Max = 21, Default = 11, Decimal = 10, Function = changed})
    AtmosphereEnabled = Theme:CreateToggle({Name = 'Atmosphere', Default = true, Function = changed})
    AtmosphereColor = Theme:CreateColorSlider({Name = 'Atmosphere color', DefaultValue = .55, Function = changed})
    AtmosphereDecay = Theme:CreateColorSlider({Name = 'Atmosphere decay', DefaultValue = .5, Function = changed})
    Density = Theme:CreateSlider({Name = 'Atmosphere density', Min = 0, Max = 1, Default = .3, Decimal = 100, Function = changed})
    Offset = Theme:CreateSlider({Name = 'Atmosphere offset', Min = -1, Max = 1, Default = 0, Decimal = 100, Function = changed})
    Glare = Theme:CreateSlider({Name = 'Atmosphere glare', Min = 0, Max = 10, Default = 0, Decimal = 100, Function = changed})
    Haze = Theme:CreateSlider({Name = 'Atmosphere haze', Min = 0, Max = 10, Default = 0, Decimal = 100, Function = changed})
    BloomEnabled = Theme:CreateToggle({Name = 'Bloom', Default = true, Function = changed})
    BloomIntensity = Theme:CreateSlider({Name = 'Bloom intensity', Min = 0, Max = 5, Default = .4, Decimal = 100, Function = changed})
    BloomSize = Theme:CreateSlider({Name = 'Bloom size', Min = 0, Max = 100, Default = 24, Function = changed})
    BloomThreshold = Theme:CreateSlider({Name = 'Bloom threshold', Min = 0, Max = 5, Default = 1.5, Decimal = 100, Function = changed})
    ColorEnabled = Theme:CreateToggle({Name = 'Color correction', Default = true, Function = changed})
    Tint = Theme:CreateColorSlider({Name = 'Tint', DefaultValue = 0, Function = changed})
    Saturation = Theme:CreateSlider({Name = 'Saturation', Min = -2, Max = 2, Default = 0, Decimal = 100, Function = changed})
    Contrast = Theme:CreateSlider({Name = 'Contrast', Min = -2, Max = 2, Default = 0, Decimal = 100, Function = changed})
    ColorBrightness = Theme:CreateSlider({Name = 'Color brightness', Min = -1, Max = 1, Default = 0, Decimal = 100, Function = changed})
    RaysEnabled = Theme:CreateToggle({Name = 'Sun rays', Function = changed})
    RaysIntensity = Theme:CreateSlider({Name = 'Ray intensity', Min = 0, Max = 1, Default = .1, Decimal = 100, Function = changed})
    RaysSpread = Theme:CreateSlider({Name = 'Ray spread', Min = 0, Max = 1, Default = .8, Decimal = 100, Function = changed})
    DepthEnabled = Theme:CreateToggle({Name = 'Depth of field', Function = changed})
    FarIntensity = Theme:CreateSlider({Name = 'Far blur', Min = 0, Max = 1, Default = .1, Decimal = 100, Function = changed})
    FocusDistance = Theme:CreateSlider({Name = 'Focus distance', Min = 0, Max = 200, Default = 30, Function = changed})
    NearIntensity = Theme:CreateSlider({Name = 'Near blur', Min = 0, Max = 1, Default = 0, Decimal = 100, Function = changed})
    RemoveClouds = Theme:CreateToggle({Name = 'Remove clouds', Function = changed})
    CloudsEnabled = Theme:CreateToggle({Name = 'Custom clouds', Default = true, Function = changed})
    CloudCover = Theme:CreateSlider({Name = 'Cloud cover', Min = 0, Max = 1, Default = .5, Decimal = 100, Function = changed})
    CloudDensity = Theme:CreateSlider({Name = 'Cloud density', Min = 0, Max = 1, Default = .7, Decimal = 100, Function = changed})
    CloudSize = Theme:CreateSlider({Name = 'Cloud size', Min = .1, Max = 3, Default = 1, Decimal = 10, Function = changed})
    CloudTransparency = Theme:CreateSlider({Name = 'Cloud transparency', Min = 0, Max = 1, Default = .3, Decimal = 100, Function = changed})
    CloudColor = Theme:CreateColorSlider({Name = 'Cloud color', DefaultValue = 0, Function = changed})
    WaterColor = Theme:CreateColorSlider({Name = 'Water color', DefaultValue = .55, Function = changed})
    WaterReflectance = Theme:CreateSlider({Name = 'Water reflectance', Min = 0, Max = 1, Default = 1, Decimal = 100, Function = changed})
    WaterTransparency = Theme:CreateSlider({Name = 'Water transparency', Min = 0, Max = 1, Default = .3, Decimal = 100, Function = changed})
    WaterWaveSize = Theme:CreateSlider({Name = 'Water wave size', Min = 0, Max = 1, Default = .15, Decimal = 100, Function = changed})
    WaterWaveSpeed = Theme:CreateSlider({Name = 'Water wave speed', Min = 0, Max = 100, Default = 10, Decimal = 10, Function = changed})
    UnderMapWater = Theme:CreateToggle({Name = 'Below-map water', Function = changed, Tooltip = 'Adds a removable visual water plane below the map without editing terrain voxels.'})
	populatePreset()
    vape.Libraries.aetherTheme = Theme
end)

run(function()
    local Breadcrumbs
    local Texture
    local Lifetime
    local Thickness
    local FadeIn
    local FadeOut
    local trail, point, point2

    Breadcrumbs = vape.Categories.Legit:CreateModule({
	Name = 'Breadcrumbs',
	Function = function(callback)
		if callback then
			point = Instance.new('Attachment')
			point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
			point2 = Instance.new('Attachment')
			point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
			trail = Instance.new('Trail')
			trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
			trail.TextureMode = Enum.TextureMode.Static
			trail.Color = ColorSequence.new(
				Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value),
				Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value)
			)
			trail.Lifetime = Lifetime.Value
			trail.Attachment0 = point
			trail.Attachment1 = point2
			trail.FaceCamera = true

			Breadcrumbs:Clean(trail)
			Breadcrumbs:Clean(point)
			Breadcrumbs:Clean(point2)
			Breadcrumbs:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
				point.Parent = ent.HumanoidRootPart
				point2.Parent = ent.HumanoidRootPart
				trail.Parent = gameCamera
			end))
			if entitylib.isAlive then
				point.Parent = entitylib.character.RootPart
				point2.Parent = entitylib.character.RootPart
				trail.Parent = gameCamera
			end
		else
			trail = nil
			point = nil
			point2 = nil
		end
	end,
	Tooltip = 'Shows a trail behind your character'
    })
    Texture = Breadcrumbs:CreateTextBox({
	Name = 'Texture',
	Placeholder = 'Texture Id',
	Function = function(enter)
		if enter and trail then
			trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
		end
	end,
    })
    FadeIn = Breadcrumbs:CreateColorSlider({
	Name = 'Fade In',
	Function = function(hue, sat, val)
		if trail then
			trail.Color = ColorSequence.new(
				Color3.fromHSV(hue, sat, val),
				Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value)
			)
		end
	end,
    })
    FadeOut = Breadcrumbs:CreateColorSlider({
	Name = 'Fade Out',
	Function = function(hue, sat, val)
		if trail then
			trail.Color =
				ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(hue, sat, val))
		end
	end,
    })
    Lifetime = Breadcrumbs:CreateSlider({
	Name = 'Lifetime',
	Min = 1,
	Max = 5,
	Default = 3,
	Decimal = 10,
	Function = function(val)
		if trail then
			trail.Lifetime = val
		end
	end,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
    })
    Thickness = Breadcrumbs:CreateSlider({
	Name = 'Thickness',
	Min = 0,
	Max = 2,
	Default = 0.1,
	Decimal = 100,
	Function = function(val)
		if point then
			point.Position = Vector3.new(0, val - 2.7, 0)
		end
		if point2 then
			point2.Position = Vector3.new(0, -val - 2.7, 0)
		end
	end,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
end)

run(function()
    local Cape
    local Texture
    local part, motor

    local function createMotor(char)
	if motor then
		motor:Destroy()
	end
	part.Parent = gameCamera
	motor = Instance.new('Motor6D')
	motor.MaxVelocity = 0.08
	motor.Part0 = part
	motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
	motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
	motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
	motor.Parent = part
    end

    Cape = vape.Categories.Legit:CreateModule({
	Name = 'Cape',
	Function = function(callback)
		if callback then
			part = Instance.new('Part')
			part.Size = Vector3.new(2, 4, 0.1)
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			part.Transparency = 0
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.new()
			part.CastShadow = false
			part.Parent = gameCamera
			local capesurface = Instance.new('SurfaceGui')
			capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			capesurface.Adornee = part
			capesurface.Parent = part

			if Texture.Value:find('.webm') then
				local decal = Instance.new('VideoFrame')
				decal.Video = getcustomasset(Texture.Value)
				decal.Size = UDim2.fromScale(1, 1)
				decal.BackgroundTransparency = 1
				decal.Looped = true
				decal.Parent = capesurface
				decal:Play()
			else
				local decal = Instance.new('ImageLabel')
				decal.Image = Texture.Value ~= ''
						and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value))
					or 'rbxassetid://14637958134'
				decal.Size = UDim2.fromScale(1, 1)
				decal.BackgroundTransparency = 1
				decal.Parent = capesurface
			end
			Cape:Clean(part)
			Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
			if entitylib.isAlive then
				createMotor(entitylib.character)
			end

			repeat
				if motor and entitylib.isAlive then
					local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
					motor.DesiredAngle = math.rad(6)
						+ math.rad(velo)
						+ (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
				end
				capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
				part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
				task.wait()
			until not Cape.Enabled
		else
			part = nil
			motor = nil
		end
	end,
	Tooltip = "Add's a cape to your character",
    })
    Texture = Cape:CreateTextBox({
	Name = 'Texture',
    })
end)

run(function()
    local ChinaHat
    local Material
    local Color
    local hat

    ChinaHat = vape.Categories.Legit:CreateModule({
	Name = 'ChinaHat',
	Function = function(callback)
		if callback then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			hat = Instance.new('MeshPart')
			hat.Size = Vector3.new(3, 0.7, 3)
			hat.Name = 'ChinaHat'
			hat.Material = Enum.Material[Material.Value]
			hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			hat.CanCollide = false
			hat.CanQuery = false
			hat.Massless = true
			hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
			hat.Transparency = 1 - Color.Opacity
			hat.Parent = gameCamera
			hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
			local weld = Instance.new('WeldConstraint')
			weld.Part0 = hat
			weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
			weld.Parent = hat
			ChinaHat:Clean(hat)
			ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				if weld then
					weld:Destroy()
				end
				hat.Parent = gameCamera
				hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
				hat.Velocity = Vector3.zero
				weld = Instance.new('WeldConstraint')
				weld.Part0 = hat
				weld.Part1 = char.Head
				weld.Parent = hat
			end))

			repeat
				hat.LocalTransparencyModifier = (
					(gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0
				)
				task.wait()
			until not ChinaHat.Enabled
		else
			hat = nil
		end
	end,
	Tooltip = 'Puts a china hat on your character (ty mastadawn)',
    })
    local materials = { 'ForceField' }
    for _, v in Enum.Material:GetEnumItems() do
	if v.Name ~= 'ForceField' then
		table.insert(materials, v.Name)
	end
    end
    Material = ChinaHat:CreateDropdown({
	Name = 'Material',
	List = materials,
	Function = function(val)
		if hat then
			hat.Material = Enum.Material[val]
		end
	end,
    })
    Color = ChinaHat:CreateColorSlider({
	Name = 'Hat Color',
	DefaultOpacity = 0.7,
	Function = function(hue, sat, val, opacity)
		if hat then
			hat.Color = Color3.fromHSV(hue, sat, val)
			hat.Transparency = 1 - opacity
		end
	end,
    })
end)

run(function()
    local Clock
    local TwentyFourHour
    local label

    Clock = vape.Categories.Legit:CreateModule({
	Name = 'Clock',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			repeat
				label.Text = DateTime.now():FormatLocalTime('LT', TwentyFourHour.Enabled and 'zh-cn' or 'en-us')
				task.wait(1)
			until not Clock.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'Shows the current local time',
    })
    Clock:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    Clock:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end,
    })
    TwentyFourHour = Clock:CreateToggle({
	Name = '24 Hour Clock',
    })
    label = Instance.new('TextLabel')
    label.Size = UDim2.new(0, 100, 0, 41)
    label.BackgroundTransparency = 0.5
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.Text = '0:00 PM'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = Clock.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)

run(function()
    local Coords

    local gui, texts = nil, {}
    local division = game.GameId == 2619619496 and 3 or 1

    Coords = vape.Categories.Legit:CreateModule({
	Name = 'Coords',
	Category = 'Hud',
	Size = UDim2.fromOffset(288, 64),
	Function = function(callback)
		if gui then
			gui.Visible = callback
		end

		if callback then
			Coords:Clean(runService.PreAnimation:Connect(function()
				if entitylib.isAlive then
					local position = entitylib.character.RootPart.Position
					local size = 220
					for _, v in { 'x', 'y', 'z' } do
						local text = tostring(math.floor(position[v:upper()] / division))
						texts[v].Text = text
						size += (textService:GetTextSize(text, 20, Enum.Font.Arial, Vector2.new(1000, 56)).X * 0.1)
					end
					tweenService
						:Create(gui, TweenInfo.new(0.1), { Size = UDim2.fromOffset(math.round(size), 56) })
						:Play()
				end
			end))
		end
	end,
    })
    Coords:CreateToggle({
	Name = 'Render Background',
	Default = true,
	Function = function(callback)
		if gui then
			gui.BackgroundTransparency = callback and 0.5 or 1
		end
	end,
    })

    gui = Instance.new('Frame')
    gui.BackgroundColor3 = Color3.new()
    gui.BackgroundTransparency = 0.5
    gui.Size = UDim2.fromOffset(218, 56)
    gui.Parent = Coords.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = gui
    local semibold = Font.new('rbxasset://fonts/families/Arimo.json', Enum.FontWeight.SemiBold)
    for i, v in { 'x', 'y', 'z' } do
	local label = Instance.new('TextLabel')
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, v == 'x' and 1 or v == 'y' and 80 or 160, 0.5, -3)
	label.Size = UDim2.fromOffset(25, 25)
	label.FontFace = semibold
	label.Text = v:upper()
	label.ZIndex = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 12
	label.Parent = gui
	local labelshadow = label:Clone()
	labelshadow.Position = label.Position + UDim2.fromOffset(1, 1)
	labelshadow.ZIndex = 0
	labelshadow.Name = 'TextShadow'
	labelshadow.TextColor3 = Color3.new()
	labelshadow.Parent = gui
	local display = label:Clone()
	display.Position = UDim2.new(0, v == 'x' and 26 or v == 'y' and 104 or 186, 0.5, -6)
	display.Size = UDim2.fromOffset(40, 20)
	display.FontFace = semibold
	display.Text = '-0'
	display.TextXAlignment = Enum.TextXAlignment.Left
	display.TextSize = 19
	display.Parent = gui
	local shadow = display:Clone()
	shadow.Position = shadow.Position + UDim2.fromOffset(1, 1)
	shadow.Name = 'TextShadow'
	shadow.ZIndex = 0
	shadow.TextColor3 = Color3.new()
	shadow.Parent = gui
	vape:Clean(display:GetPropertyChangedSignal('Text'):Connect(function()
		shadow.Text = display.Text
	end))
	texts[v] = display
    end
    for _, v in { 68, 150 } do
	local spacing = Instance.new('Frame')
	spacing.AnchorPoint = Vector2.new(0, 0.5)
	spacing.Name = 'Spacing'
	spacing.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
	spacing.BackgroundTransparency = 0.5
	spacing.Position = UDim2.new(0, v, 0.5, -5)
	spacing.BorderSizePixel = 0
	spacing.Size = UDim2.fromOffset(2, 20)
	spacing.Parent = gui
    end
end)

run(function()
    local Disguise
    local Mode
    local IDBox
    local desc

    local function itemAdded(v, manual)
	if
		(not v:GetAttribute('Disguise'))
		and (
			(v:IsA('Accessory') and (not v:GetAttribute('InvItem')) and (not v:GetAttribute('ArmorSlot')))
			or v:IsA('ShirtGraphic')
			or v:IsA('Shirt')
			or v:IsA('Pants')
			or v:IsA('BodyColors')
			or manual
		)
	then
		repeat
			task.wait()
			v.Parent = game
		until v.Parent == game
		v:ClearAllChildren()
		v:Destroy()
	end
    end

    local function characterAdded(char)
	if Mode.Value == 'Character' then
		task.wait(0.1)
		char.Character.Archivable = true
		local clone = char.Character:Clone()
		repeat
			if
				pcall(function()
					desc = playersService:GetHumanoidDescriptionFromUserId(
						IDBox.Value == '' and 239702688 or tonumber(IDBox.Value)
					)
				end) and desc
			then
				break
			end
			task.wait(1)
		until not Disguise.Enabled
		if not Disguise.Enabled then
			clone:ClearAllChildren()
			clone:Destroy()
			clone = nil
			if desc then
				desc:Destroy()
				desc = nil
			end
			return
		end
		clone.Parent = game

		local originalDesc = char.Humanoid:WaitForChild('HumanoidDescription', 2)
			or {
				HeightScale = 1,
				SetEmotes = function() end,
				SetEquippedEmotes = function() end,
			}
		originalDesc.JumpAnimation = desc.JumpAnimation
		desc.HeightScale = originalDesc.HeightScale

		for _, v in clone:GetChildren() do
			if v:IsA('Accessory') or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') then
				v:ClearAllChildren()
				v:Destroy()
			end
		end

		clone.Humanoid:ApplyDescriptionClientServer(desc)
		for _, v in char.Character:GetChildren() do
			itemAdded(v)
		end
		Disguise:Clean(char.Character.ChildAdded:Connect(itemAdded))

		for _, v in clone:WaitForChild('Animate'):GetChildren() do
			if not char.Character:FindFirstChild('Animate') then
				return
			end
			local real = char.Character.Animate:FindFirstChild(v.Name)
			if v and real then
				local anim = v:FindFirstChildWhichIsA('Animation') or { AnimationId = '' }
				local realanim = real:FindFirstChildWhichIsA('Animation') or { AnimationId = '' }
				if realanim then
					realanim.AnimationId = anim.AnimationId
				end
			end
		end

		for _, v in clone:GetChildren() do
			v:SetAttribute('Disguise', true)
			if v:IsA('Accessory') then
				for _, v2 in v:GetDescendants() do
					if v2:IsA('Weld') and v2.Part1 then
						v2.Part1 = char.Character[v2.Part1.Name]
					end
				end
				v.Parent = char.Character
			elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
				v.Parent = char.Character
			elseif
				v.Name == 'Head'
				and char.Head:IsA('MeshPart')
				and (not char.Head:FindFirstChild('FaceControls'))
			then
				char.Head.MeshId = v.MeshId
			end
		end

		local localface = char.Character:FindFirstChild('face', true)
		local cloneface = clone:FindFirstChild('face', true)
		if localface and cloneface then
			itemAdded(localface, true)
			cloneface.Parent = char.Head
		end
		originalDesc:SetEmotes(desc:GetEmotes())
		originalDesc:SetEquippedEmotes(desc:GetEquippedEmotes())
		clone:ClearAllChildren()
		clone:Destroy()
		clone = nil
		if desc then
			desc:Destroy()
			desc = nil
		end
	else
		local data
		repeat
			if
				pcall(function()
					data = marketplaceService:GetProductInfo(
						IDBox.Value == '' and 43 or tonumber(IDBox.Value),
						Enum.InfoType.Bundle
					)
				end)
			then
				break
			end
			task.wait(1)
		until not Disguise.Enabled
		if not Disguise.Enabled then
			if data then
				table.clear(data)
				data = nil
			end
			return
		end
		if data.BundleType == 'AvatarAnimations' then
			local animate = char.Character:FindFirstChild('Animate')
			if not animate then
				return
			end
			for _, v in desc.Items do
				local animtype = v.Name:split(' ')[2]:lower()
				if animtype ~= 'animation' then
					local suc, res = pcall(function()
						return game:GetObjects('rbxassetid://' .. v.Id)
					end)
					if suc then
						animate[animtype]:FindFirstChildWhichIsA('Animation').AnimationId =
							res[1]:FindFirstChildWhichIsA('Animation', true).AnimationId
					end
				end
			end
		else
			notif('Disguise', "that's not an animation pack", 5, 'warning')
		end
	end
    end

    Disguise = vape.Categories.Legit:CreateModule({
	Name = 'Disguise',
	Function = function(callback)
		if callback then
			Disguise:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
			if entitylib.isAlive then
				characterAdded(entitylib.character)
			end
		end
	end,
	Tooltip = "Changes your character or animation to a specific ID (animation packs or userid's only)",
    })
    Mode = Disguise:CreateDropdown({
	Name = 'Mode',
	List = { 'Character', 'Animation' },
	Function = function()
		if Disguise.Enabled then
			Disguise:Toggle()
			Disguise:Toggle()
		end
	end,
    })
    IDBox = Disguise:CreateTextBox({
	Name = 'Disguise',
	Placeholder = 'Disguise User Id',
	Function = function()
		if Disguise.Enabled then
			Disguise:Toggle()
			Disguise:Toggle()
		end
	end,
    })
end)

run(function()
    local FFlag
    local Flags

    local function ChangeFFlag(suc)
	if not suc or not FFlag.Enabled then
		return
	end
	local success, json = pcall(function()
		return httpService:JSONDecode(Flags.Value)
	end)

	if not success or typeof(json) ~= 'table' then
		notif('AetherV2', 'Invalid json format for fflag', 12, 'warning')
		return
	end

	for i, v in json do
		i = i:gsub('DFInt', '')
			:gsub('DFFlag', '')
			:gsub('FFlag', '')
			:gsub('FInt', '')
			:gsub('DFString', '')
			:gsub('FString', '')

		pcall(setfflag, i, tostring(v))
	end

	notif('AetherV2', 'FFlags applied, Go in a new game to take effect', 12, 'info')
    end

    FFlag = vape.Categories.Legit:CreateModule({
	Name = 'FFlagEditor',
	Disabled = not setfflag,
	DsiabledTooltip = 'This module requires a specific function to work, Which your executor (' .. ({
		identifyexecutor(),
	})[1] .. ') does not have',
	Function = function(call)
		if call then
			ChangeFFlag(true)
		else
			notif('AetherV2', 'Inorder to disable fflags you have applied, You need to restart roblox', 20, 'info')
		end
	end,
    })

    Flags = FFlag:CreateTextBox({
	Name = 'FFlags',
	Placeholder = 'json format only',
	Function = ChangeFFlag,
    })
end)

run(function()
    local FOV
    local Value
    local oldfov

    FOV = vape.Categories.Legit:CreateModule({
	Name = 'FOV',
	Function = function(callback)
		if callback then
			oldfov = gameCamera.FieldOfView
			repeat
				gameCamera.FieldOfView = Value.Value
				task.wait()
			until not FOV.Enabled
		else
			gameCamera.FieldOfView = oldfov
		end
	end,
	Tooltip = 'Adjusts camera vision',
    })
    Value = FOV:CreateSlider({
	Name = 'FOV',
	Min = 30,
	Max = 120,
    })
end)

run(function()
    --[[
		Grabbing an accurate count of the current framerate
		Source: https://devforum.roblox.com/t/get-client-FPS-trough-a-script/282631
	]]
    local FPS
    local label

    FPS = vape.Categories.Legit:CreateModule({
	Name = 'FPS',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			local frames = {}
			local startClock = os.clock()
			local updateTick = tick()
			FPS:Clean(runService.PostSimulation:Connect(function()
				local updateClock = os.clock()
				for i = #frames, 1, -1 do
					frames[i + 1] = frames[i] >= updateClock - 1 and frames[i] or nil
				end
				frames[1] = updateClock
				if updateTick < tick() then
					updateTick = tick() + 1
					label.Text = math.floor(
						os.clock() - startClock >= 1 and #frames or #frames / (os.clock() - startClock)
					) .. ' FPS'
				end
			end))
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'Shows the current framerate',
    })
    FPS:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    FPS:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end,
    })
    label = Instance.new('TextLabel')
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 0.5
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.Text = 'inf FPS'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = FPS.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)

run(function()
    local LowHealthVignette, Threshold, WarningColor, Intensity, Pulse, Heartbeat
    local gui, heartbeatSound
    local edges = {}

    local function cleanup()
        if heartbeatSound then
            heartbeatSound:Stop()
            heartbeatSound:Destroy()
            heartbeatSound = nil
        end
        if gui then
            gui:Destroy()
            gui = nil
        end
        table.clear(edges)
    end

    local function effectiveHealth(character, humanoid)
        local shield = 0
        for _, attribute in {'Shield', 'HealthShield', 'Absorption', 'ExtraHealth'} do
            shield = math.max(shield, tonumber(character:GetAttribute(attribute)) or 0)
        end
        return humanoid.Health + shield, humanoid.MaxHealth + shield
    end

    local function createEdge(name, size, position, rotation)
        local edge = Instance.new('Frame')
        edge.Name = name
        edge.Size = size
        edge.Position = position
        edge.BorderSizePixel = 0
        edge.BackgroundTransparency = 1
		edge.ZIndex = 50
        edge.Parent = gui

        local gradient = Instance.new('UIGradient')
        gradient.Rotation = rotation
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
        gradient.Parent = edge
        table.insert(edges, edge)
    end

    local function localHumanoid()
        local character = lplr.Character
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        if not character or not humanoid or humanoid.Health <= 0 then return end
        -- A camera following another humanoid means the player is spectating.
        local subject = gameCamera and gameCamera.CameraSubject
        if subject and subject:IsA('Humanoid') and subject ~= humanoid then return end
        return character, humanoid
    end

    LowHealthVignette = vape.Categories.Legit:CreateModule({
        Name = 'LowHealthVignette',
        Function = function(enabled)
            cleanup()
            if not enabled then return end

            gui = Instance.new('Frame')
            gui.Name = 'AetherLowHealthVignette'
			gui.Size = UDim2.fromScale(1, 1)
			gui.BackgroundTransparency = 1
			gui.ZIndex = 50
            gui.Parent = vape.gui

            createEdge('Top', UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0), 90)
            createEdge('Bottom', UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0.82), 270)
            createEdge('Left', UDim2.new(0.14, 0, 0.64, 0), UDim2.fromScale(0, 0.18), 0)
            createEdge('Right', UDim2.new(0.14, 0, 0.64, 0), UDim2.fromScale(0.86, 0.18), 180)

            heartbeatSound = Instance.new('Sound')
            heartbeatSound.Name = 'Heartbeat'
            heartbeatSound.SoundId = 'rbxassetid://9114221327'
            heartbeatSound.Looped = true
            heartbeatSound.Volume = 0
            heartbeatSound.Parent = gui

            local accumulator, strength, warningColor = 0, 0, Color3.fromHSV(WarningColor.Hue, WarningColor.Sat, WarningColor.Value)
            LowHealthVignette:Clean(runService.RenderStepped:Connect(function(delta)
                accumulator += delta
                -- Health, attributes and camera subject do not need a 144/240Hz query. Keep the
                -- inexpensive pulse smooth, but sample gameplay state at no more than 30Hz.
                if accumulator >= 1 / 30 then
                    accumulator = 0
                    warningColor = Color3.fromHSV(WarningColor.Hue, WarningColor.Sat, WarningColor.Value)
                    for _, edge in edges do edge.BackgroundColor3 = warningColor end
                    local character, humanoid = localHumanoid()
                    strength = 0
                    if character and humanoid then
                        local health, maximum = effectiveHealth(character, humanoid)
                        local threshold = Threshold.Value / 100
                        local ratio = maximum > 0 and health / maximum or 1
                        if ratio <= threshold then
                            strength = math.clamp((threshold - ratio) / math.max(threshold, 0.01), 0, 1)
                            strength *= Intensity.Value / 100
                        end
                    end
                end
                local visibleStrength = Pulse.Enabled and strength * (0.75 + math.sin(os.clock() * 6) * 0.25) or strength
                for _, edge in edges do
                    edge.BackgroundTransparency = 1 - visibleStrength
                end

                heartbeatSound.Volume = visibleStrength > 0 and Heartbeat.Enabled and visibleStrength / 3 or 0
                if heartbeatSound.Volume > 0 and not heartbeatSound.IsPlaying then
                    heartbeatSound:Play()
                elseif heartbeatSound.Volume == 0 and heartbeatSound.IsPlaying then
                    heartbeatSound:Stop()
                end
            end))
        end,
        Tooltip = 'Shows a shield-aware screen-edge warning while your effective health is low'
    })
    Threshold = LowHealthVignette:CreateSlider({Name = 'Health percentage', Min = 1, Max = 100, Default = 30, Suffix = '%'})
    WarningColor = LowHealthVignette:CreateColorSlider({Name = 'Color', DefaultValue = 0, DefaultOpacity = 1})
    Intensity = LowHealthVignette:CreateSlider({Name = 'Intensity', Min = 1, Max = 100, Default = 70, Suffix = '%'})
    Pulse = LowHealthVignette:CreateToggle({Name = 'Pulse', Default = true})
    Heartbeat = LowHealthVignette:CreateToggle({Name = 'Heartbeat'})
end)

run(function()
    local Keystrokes, Style, Color, ShowSpace, ShowMouse, ShowLeft, ShowMiddle, ShowRight, ShowCPS
    local keys, inputKeys, holder, clicks = {}, {}, nil, {L = {}, R = {}}
    local clickHeads = {L = 1, R = 1}
    local cpsGeneration = 0
    local function layout()
        if not Keystrokes.Children then return end
        local mouseVisible = ShowMouse.Enabled and (ShowLeft.Enabled or ShowMiddle.Enabled or ShowRight.Enabled)
        local width = mouseVisible and 182 or 110
        local height = (ShowSpace.Enabled or (mouseVisible and ShowCPS.Enabled)) and 107 or 78
        Keystrokes.Children.Size = UDim2.fromOffset(width, height)
    end
    local function make(id, position, size, text, input)
        if keys[id] then keys[id].Key:Destroy() end
        local key = Instance.new('Frame'); key.Name = tostring(id); key.Position = position; key.Size = size; key.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value); key.BackgroundTransparency = 1 - Color.Opacity; key.Parent = holder
        local label = Instance.new('TextLabel'); label.Name = 'Label'; label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1; label.Font = Enum.Font.Gotham; label.Text = text; label.TextSize = 15; label.TextColor3 = Color3.new(1,1,1); label.Parent = key
        local corner = Instance.new('UICorner'); corner.CornerRadius = UDim.new(0, 4); corner.Parent = key
        keys[id] = {Key = key, Label = label, Input = input}
    end
    local function build()
        for _, key in keys do key.Key:Destroy() end; table.clear(keys); table.clear(inputKeys)
        local arrow = Style.Value == 'Arrow'
        make('W', UDim2.fromOffset(38, 0), UDim2.fromOffset(34, 36), arrow and '↑' or 'W', Enum.KeyCode.W)
        make('A', UDim2.fromOffset(0, 42), UDim2.fromOffset(34, 36), arrow and '←' or 'A', Enum.KeyCode.A)
        make('S', UDim2.fromOffset(38, 42), UDim2.fromOffset(34, 36), arrow and '↓' or 'S', Enum.KeyCode.S)
        make('D', UDim2.fromOffset(76, 42), UDim2.fromOffset(34, 36), arrow and '→' or 'D', Enum.KeyCode.D)
        if ShowSpace.Enabled then make('Space', UDim2.fromOffset(0, 83), UDim2.fromOffset(110, 24), '━━━━━━━━', Enum.KeyCode.Space) end
        if ShowMouse.Enabled then
            if ShowLeft.Enabled then make('MouseL', UDim2.fromOffset(118, 0), UDim2.fromOffset(29, 51), 'L', Enum.UserInputType.MouseButton1) end
            if ShowRight.Enabled then make('MouseR', UDim2.fromOffset(153, 0), UDim2.fromOffset(29, 51), 'R', Enum.UserInputType.MouseButton2) end
            if ShowMiddle.Enabled then make('MouseM', UDim2.fromOffset(147, 57), UDim2.fromOffset(12, 21), '', Enum.UserInputType.MouseButton3) end
            if ShowCPS.Enabled then
                if ShowLeft.Enabled then make('CPSL', UDim2.fromOffset(118, 83), UDim2.fromOffset(29, 24), '0', nil) end
                if ShowRight.Enabled then make('CPSR', UDim2.fromOffset(153, 83), UDim2.fromOffset(29, 24), '0', nil) end
            end
        end
        for _, entry in keys do
            if entry.Input then inputKeys[entry.Input] = entry end
        end
        layout()
    end
    local function illuminate(entry, pressed)
        entry.Pressed = pressed
        tweenService:Create(entry.Key, TweenInfo.new(0.08), {BackgroundColor3 = pressed and Color3.new(1,1,1) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value), BackgroundTransparency = pressed and 0 or 1 - Color.Opacity}):Play()
        tweenService:Create(entry.Label, TweenInfo.new(0.08), {TextColor3 = pressed and Color3.new() or Color3.new(1,1,1)}):Play()
    end
    Keystrokes = vape.Categories.Legit:CreateModule({Name = 'Keystrokes', Category = 'Hud', Size = UDim2.fromOffset(110, 107), Tooltip = 'Shows movement, spacebar, mouse buttons, and CPS onscreen', Function = function(enabled)
        cpsGeneration += 1
        if not enabled then return end
        local generation = cpsGeneration
        build()
        Keystrokes:Clean(inputService.InputBegan:Connect(function(input, processed)
            local entry = inputKeys[input.KeyCode] or inputKeys[input.UserInputType]
            if not entry then return end
            illuminate(entry, true)
            if not processed and entry == keys.MouseL then table.insert(clicks.L, tick())
            elseif not processed and entry == keys.MouseR then table.insert(clicks.R, tick()) end
        end))
        Keystrokes:Clean(inputService.InputEnded:Connect(function(input)
            local entry = inputKeys[input.KeyCode] or inputKeys[input.UserInputType]
            if entry then illuminate(entry, false) end
        end))
        task.spawn(function()
            while Keystrokes.Enabled and cpsGeneration == generation do
                local now = tick()
                for _, side in {'L', 'R'} do
                    local list, head = clicks[side], clickHeads[side]
                    while list[head] and now - list[head] > 1 do head += 1 end
                    -- Compact occasionally rather than shifting the entire array for every click.
                    if head > 32 then
                        table.move(list, head, #list, 1, list)
                        for index = #list - head + 2, #list do list[index] = nil end
                        head = 1
                    end
                    clickHeads[side] = head
                end
                if keys.CPSL then keys.CPSL.Label.Text = tostring(#clicks.L - clickHeads.L + 1) end
                if keys.CPSR then keys.CPSR.Label.Text = tostring(#clicks.R - clickHeads.R + 1) end
                task.wait(0.1)
            end
        end)
    end})
    holder = Instance.new('Frame'); holder.Size = UDim2.fromScale(1,1); holder.BackgroundTransparency = 1; holder.Parent = Keystrokes.Children
    local function rebuild() if Keystrokes.Enabled then build() else layout() end end
    Style = Keystrokes:CreateDropdown({Name = 'Key Style', List = {'Keyboard','Arrow'}, Function = rebuild})
    Color = Keystrokes:CreateColorSlider({Name = 'Color', DefaultValue = 0, DefaultOpacity = 0.5, Function = function(h,s,v,o) for _, entry in keys do if not entry.Pressed then entry.Key.BackgroundColor3 = Color3.fromHSV(h,s,v); entry.Key.BackgroundTransparency = 1-o end end end})
    ShowSpace = Keystrokes:CreateToggle({Name = 'Show Spacebar', Default = true, Function = rebuild})
    ShowMouse = Keystrokes:CreateToggle({Name = 'Show Mouse', Function = rebuild})
    ShowLeft = Keystrokes:CreateToggle({Name = 'Left Mouse', Default = true, Function = rebuild})
    ShowMiddle = Keystrokes:CreateToggle({Name = 'Middle Mouse', Default = true, Function = rebuild})
    ShowRight = Keystrokes:CreateToggle({Name = 'Right Mouse', Default = true, Function = rebuild})
    ShowCPS = Keystrokes:CreateToggle({Name = 'Show CPS', Function = rebuild})
end)


run(function()
    local Memory
    local label

    Memory = vape.Categories.Legit:CreateModule({
	Name = 'Memory',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			repeat
				label.Text = math.floor(
					tonumber(game:GetService('Stats'):FindFirstChild('PerformanceStats').Memory:GetValue())
				) .. ' MB'
				task.wait(1)
			until not Memory.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'A label showing the memory currently used by roblox',
    })
    Memory:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    Memory:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end,
    })
    label = Instance.new('TextLabel')
    label.Size = UDim2.new(0, 100, 0, 41)
    label.BackgroundTransparency = 0.5
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.Text = '0 MB'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = Memory.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)

run(function()
    local Ping
    local label

    Ping = vape.Categories.Legit:CreateModule({
	Name = 'Ping',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			repeat
				label.Text = math.round(lplr:GetNetworkPing() * 1000) .. ' ms'
				task.wait(1)
			until not Ping.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'Shows the current connection speed to the roblox server',
    })
    Ping:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    Ping:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end,
    })
    label = Instance.new('TextLabel')
    label.Size = UDim2.new(0, 100, 0, 41)
    label.BackgroundTransparency = 0.5
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.Text = '0 ms'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = Ping.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)

run(function()
    local SongBeats
    local List
    local FOV
    local FOVValue = {}
    local Volume
    local alreadypicked = {}
    local beattick = tick()
    local oldfov, songobj, songbpm, songtween

    local function choosesong()
	local list = List.ListEnabled
	if #alreadypicked >= #list then
		table.clear(alreadypicked)
	end

	if #list <= 0 then
		notif('SongBeats', 'no songs', 10)
		SongBeats:Toggle()
		return
	end

	local chosensong = list[math.random(1, #list)]
	if #list > 1 and table.find(alreadypicked, chosensong) then
		repeat
			task.wait()
			chosensong = list[math.random(1, #list)]
		until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
	end
	if not SongBeats.Enabled then
		return
	end

	local split = chosensong:split('/')
	if not isfile(split[1]) then
		notif('SongBeats', 'Missing song (' .. split[1] .. ')', 10)
		SongBeats:Toggle()
		return
	end

	songobj.SoundId = assetfunction(split[1])
	repeat
		task.wait()
	until songobj.IsLoaded or not SongBeats.Enabled
	if SongBeats.Enabled then
		beattick = tick() + (tonumber(split[3]) or 0)
		songbpm = 60 / (tonumber(split[2]) or 50)
		songobj:Play()
	end
    end

    SongBeats = vape.Categories.Legit:CreateModule({
	Name = 'SongBeats',
	Function = function(callback)
		if callback then
			songobj = Instance.new('Sound')
			songobj.Volume = Volume.Value / 100
			songobj.Parent = workspace
			oldfov = gameCamera.FieldOfView

			repeat
				if not songobj.Playing then
					choosesong()
				end
				if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
					beattick = tick() + songbpm
					gameCamera.FieldOfView = oldfov - FOVValue.Value
					songtween = tweenService:Create(
						gameCamera,
						TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear),
						{
							FieldOfView = oldfov,
						}
					)
					songtween:Play()
				end
				task.wait()
			until not SongBeats.Enabled
		else
			if songobj then
				songobj:Destroy()
			end
			if songtween then
				songtween:Cancel()
			end
			if oldfov then
				gameCamera.FieldOfView = oldfov
			end
			table.clear(alreadypicked)
		end
	end,
	Tooltip = 'Built in mp3 player',
    })
    List = SongBeats:CreateTextList({
	Name = 'Songs',
	Placeholder = 'filepath/bpm/start',
    })
    FOV = SongBeats:CreateToggle({
	Name = 'Beat FOV',
	Function = function(callback)
		if FOVValue.Object then
			FOVValue.Object.Visible = callback
		end
		if SongBeats.Enabled then
			SongBeats:Toggle()
			SongBeats:Toggle()
		end
	end,
	Default = true,
    })
    FOVValue = SongBeats:CreateSlider({
	Name = 'Adjustment',
	Min = 1,
	Max = 30,
	Default = 5,
	Darker = true,
    })
    Volume = SongBeats:CreateSlider({
	Name = 'Volume',
	Function = function(val)
		if songobj then
			songobj.Volume = val / 100
		end
	end,
	Min = 1,
	Max = 100,
	Default = 100,
	Suffix = '%',
    })
end)

run(function()
    local Speedmeter
    local label

    Speedmeter = vape.Categories.Legit:CreateModule({
	Name = 'Speedmeter',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			repeat
				local lastpos = entitylib.isAlive
						and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1)
					or Vector3.zero
				local dt = task.wait(0.2)
				local newpos = entitylib.isAlive
						and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1)
					or Vector3.zero
				label.Text = math.round(((lastpos - newpos) / dt).Magnitude) .. ' sps'
			until not Speedmeter.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'A label showing the average velocity in studs',
    })
    Speedmeter:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    Speedmeter:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end,
    })
    label = Instance.new('TextLabel')
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 0.5
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.Text = '0 sps'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = Speedmeter.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)

-- Executor FPS cap control. This intentionally uses only the documented executor
-- capability and restores Roblox's normal cap when disabled.
run(function()
    local FPSUnlocker, Cap
    FPSUnlocker = vape.Categories.Utility:CreateModule({
        Name = 'FPSUnlocker',
        Function = function(enabled)
            if typeof(setfpscap) ~= 'function' then
                if enabled then
                    notif('FPSUnlocker', 'Your executor does not support setfpscap.', 5, 'warning')
                    task.defer(function() if FPSUnlocker.Enabled then FPSUnlocker:Toggle() end end)
                end
                return
            end
            local ok = pcall(setfpscap, enabled and Cap.Value or 60)
            if not ok and enabled then
                notif('FPSUnlocker', 'The executor rejected setfpscap.', 5, 'warning')
                task.defer(function() if FPSUnlocker.Enabled then FPSUnlocker:Toggle() end end)
            end
        end,
        Tooltip = 'Changes the frame-rate cap when the executor supports setfpscap.'
    })
    Cap = FPSUnlocker:CreateSlider({
        Name = 'FPS cap',
        Min = 60,
        Max = 1000,
        Default = 240,
        Function = function(value)
            if FPSUnlocker.Enabled and typeof(setfpscap) == 'function' then pcall(setfpscap, value) end
        end
    })
end)


--[[AETHER_UNIVERSAL_UNORDERED_MODULES]]
-- blatant/DeathSpawn.lua
run(function()
    local DeathSpawn
    local generation = 0
    local deathConnection
    local characterConnection

    local function disconnect(connection)
        if connection then
            connection:Disconnect()
        end
    end

    local function clearConnections()
        disconnect(deathConnection)
        disconnect(characterConnection)
        deathConnection = nil
        characterConnection = nil
    end

    local function getHumanoid(character)
        return character and character:FindFirstChildOfClass('Humanoid')
    end

    local function getRoot(character)
        return character and character:FindFirstChild('HumanoidRootPart')
    end

    local function saveTransform(character)
        local root = getRoot(character)
        if not root then return nil end

        return root.Position, root.CFrame.Rotation
    end

    local function placeCharacter(character, position, rotation)
        local root = getRoot(character) or character:WaitForChild('HumanoidRootPart', 5)
        if not root or not position then return end

        -- Always attempt the placement as soon as the replacement character exists.
        root.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
        root.AssemblyLinearVelocity = Vector3.zero
    end

    local function hookCharacter(character, myGeneration)
        if myGeneration ~= generation or not DeathSpawn.Enabled then return end

        local humanoid = getHumanoid(character) or character:WaitForChild('Humanoid', 5)
        local root = getRoot(character) or character:WaitForChild('HumanoidRootPart', 5)
        if not humanoid or not root then return end

        disconnect(deathConnection)
        deathConnection = humanoid.Died:Connect(function()
            if myGeneration ~= generation or not DeathSpawn.Enabled then return end

            -- Capture the exact position and rotation at the moment of death.
            local position, rotation = saveTransform(character)
            if not position then return end

            disconnect(characterConnection)
            characterConnection = lplr.CharacterAdded:Connect(function(newCharacter)
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end

                task.defer(function()
                    if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                    placeCharacter(newCharacter, position, rotation)
                end)
            end)

            DeathSpawn:Clean(characterConnection)

            -- Roblox normally creates the replacement character automatically.
            -- If the current character remains present, keep attempting to restore
            -- the saved transform until CharacterAdded supplies the replacement.
        end)

        DeathSpawn:Clean(deathConnection)
    end

    DeathSpawn = vape.Categories.Blatant:CreateModule({
        Name = 'DeathSpawn',
        Function = function(callback)
            generation += 1
            local myGeneration = generation
            clearConnections()

            if not callback then return end

            if lplr.Character then
                hookCharacter(lplr.Character, myGeneration)
            end

            local connection = lplr.CharacterAdded:Connect(function(character)
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                hookCharacter(character, myGeneration)
            end)
            DeathSpawn:Clean(connection)
        end,
        Tooltip = 'Respawn at the position and rotation where you died.'
    })
end)
-- blatant/FastClimb.lua
run(function()
	local FastClimb
	local WalkSpeed
	local ClimbSpeed
	local applied = false
	local savedWalkSpeed

	local function restore()
		if not applied then return end
		applied = false
		if entitylib.isAlive then
			local hum = entitylib.character and entitylib.character.Humanoid
			if hum and savedWalkSpeed then
				hum.WalkSpeed = savedWalkSpeed
			end
		end
		savedWalkSpeed = nil
	end

	FastClimb = vape.Categories.Blatant:CreateModule({
		Name = 'FastClimb',
		Function = function(callback)
			if callback then
				FastClimb:Clean(runService.PreSimulation:Connect(function()
					if not entitylib.isAlive then
						restore()
						return
					end

					local character = entitylib.character
					local hum = character and character.Humanoid
					local root = character and character.RootPart
					if not hum or not root then
						restore()
						return
					end

					if hum:GetState() ~= Enum.HumanoidStateType.Climbing then
						restore()
						return
					end

					if not applied then
						savedWalkSpeed = hum.WalkSpeed
						applied = true
					end

					hum.WalkSpeed = WalkSpeed.Value

					local vel = root.AssemblyLinearVelocity
					local y = ClimbSpeed.Value
					if vel.Y < -0.05 then
						y = -ClimbSpeed.Value
					end
					root.AssemblyLinearVelocity = Vector3.new(vel.X, y, vel.Z)
				end))
				FastClimb:Clean(restore)
			else
				restore()
			end
		end,
		Tooltip = 'Boosts walkspeed and velocity only while climbing.'
	})

	WalkSpeed = FastClimb:CreateSlider({
		Name = 'Walk Speed',
		Min = 1,
		Max = 100,
		Default = 20,
		Suffix = 'studs/s'
	})

	ClimbSpeed = FastClimb:CreateSlider({
		Name = 'Climb Speed',
		Min = 1,
		Max = 100,
		Default = 50,
		Suffix = 'studs/s'
	})
end)

-- blatant/Fly.lua
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local TP
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, oldDeflate = 0, 0
	local KrystalKit, KrystalSpeed
	local SigridKit, SigridSpeed
	local GrimKit, GrimSpeed
	local ZephyrKit, ZephyrSpeed

	local function bedwarsEnv()
		return rawget(getgenv(), 'bedwars')
	end

	local function storeEnv()
		return rawget(getgenv(), 'store')
	end

	local function eventsEnv()
		return rawget(getgenv(), 'vapeEvents')
	end

	local function hasItem(name)
		local currentStore = storeEnv()
		local items = currentStore and currentStore.inventory and currentStore.inventory.inventory and currentStore.inventory.inventory.items
		if type(items) ~= 'table' then return false end
		for _, item in items do
			local itemType = item.itemType or item.Name
			local toolName = item.tool and item.tool.Name or ''
			if itemType == name or tostring(toolName):find(name, 1, true) then
				return true
			end
		end
		return false
	end

	local function movementSpeed()
		local fallback = Value.Value
		local currentStore = storeEnv()
		local character = lplr.Character
		if not entitylib.isAlive then return fallback end
		local equipped = currentStore and currentStore.equippedKit or lplr:GetAttribute('PlayingAsKit') or lplr:GetAttribute('PlayingAsKits')
		local kit = string.lower(tostring(equipped or ''))
		local function has(words)
			for _, word in words do
				if kit:find(word, 1, true) then return true end
			end
			return false
		end
		if KrystalKit.Enabled and has({'glacial_skater', 'ice_skater', 'glacier', 'krystal'}) then return KrystalSpeed.Value end
		local riding = lplr:GetAttribute('ElkKitMounted') or lplr:GetAttribute('SigridMounted')
			or (character and (character:GetAttribute('ElkKitMounted') or character:GetAttribute('SigridMounted') or character:FindFirstChild('ElkMount', true)))
		if SigridKit.Enabled and has({'elk_master', 'elk', 'rider', 'sigrid'}) and riding then return SigridSpeed.Value end
		local soul = character and (character:GetAttribute('GrimReaperChannel') or character:GetAttribute('SoulForm') or character:GetAttribute('GrimReaperGhost') or character:FindFirstChild('GrimReaperChannel', true))
		if GrimKit.Enabled and has({'grim_reaper', 'grim', 'soul'}) and soul then return GrimSpeed.Value end
		local stacks = tonumber(lplr:GetAttribute('WindWalkerStacks') or lplr:GetAttribute('WindWalkerStack') or lplr:GetAttribute('WindStacks')
			or (character and (character:GetAttribute('WindWalkerStacks') or character:GetAttribute('WindWalkerStack') or character:GetAttribute('WindStacks'))) or 0) or 0
		if ZephyrKit.Enabled and has({'wind_walker', 'zephyr', 'wind'}) and stacks >= 1 then return ZephyrSpeed.Value end
		return fallback
	end

	local function currentWalkSpeed()
		local bw = bedwarsEnv()
		if bw and bw.SprintController then
			local ok, result = pcall(function()
				local multi, increase = 0, true
				local modifiers = bw.SprintController:getMovementStatusModifier():getModifiers()
				for v in modifiers do
					local val = v.constantSpeedMultiplier or 0
					if val > math.max(multi, 1) then
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
				return 20 * (multi + 1)
			end)
			if ok and type(result) == 'number' then return result end
		end
		if entitylib.isAlive then
			return entitylib.character.Humanoid.WalkSpeed
		end
		return 16
	end

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()
			if callback then
				up, down = 0, 0
				local bw = bedwarsEnv()
				local balloon = bw and bw.BalloonController
				if balloon then
					oldDeflate = balloon.deflateBalloon
					balloon.deflateBalloon = function() end
					if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and hasItem('balloon') then
						pcall(function() balloon:inflateBalloon() end)
					end
					local events = eventsEnv()
					if events and events.AttributeChanged then
						Fly:Clean(events.AttributeChanged.Event:Connect(function(changed)
							if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and hasItem('balloon') then
								pcall(function() balloon:inflateBalloon() end)
							end
						end))
					end
				end

				local tpTick, tpToggle, oldy = tick(), true
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and isnetworkowner(entitylib.character.RootPart) then
						local root = entitylib.character.RootPart
						local moveDirection = entitylib.character.Humanoid.MoveDirection
						local currentStore = storeEnv()
						local balloons = lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) or 0
						local flyAllowed = balloons > 0 or (currentStore and currentStore.matchState == 2) or not bw
						local mass = (0.9 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
						local velo = currentWalkSpeed()
						local speed = movementSpeed()
						local destination = (moveDirection * math.max(speed - velo, 0) * dt)
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						rayCheck.CollisionGroup = root.CollisionGroup

						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end

						if not flyAllowed then
							if tpToggle then
								local airleft = tick() - (entitylib.character.AirTime or tick())
								if airleft > 2 then
									if not oldy then
										local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
										if ray and TP.Enabled then
											tpToggle = false
											oldy = root.Position.Y
											tpTick = tick() + 0.11
											root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + (entitylib.character.HipHeight or 3), root.Position.Z), root.CFrame.LookVector)
										end
									end
								end
							else
								if oldy then
									if tpTick < tick() then
										root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, oldy, root.Position.Z), root.CFrame.LookVector)
										tpToggle = true
										oldy = nil
									else
										mass = 0
									end
								end
							end
						end

						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * math.max(velo, speed)) + Vector3.new(0, mass, 0)
					end
				end))
				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				local bw = bedwarsEnv()
				local balloon = bw and bw.BalloonController
				if balloon and oldDeflate then
					balloon.deflateBalloon = oldDeflate
				end
				if PopBalloons.Enabled and entitylib.isAlive and balloon and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						pcall(function() balloon:deflateBalloon() end)
					end
				end
				oldDeflate = nil
			end
		end,
		ExtraText = function()
			return bedwarsEnv() and 'Heatseeker' or 'Normal'
		end,
		Tooltip = 'Makes you go zoom'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	KrystalKit = Fly:CreateToggle({Name = 'Krystal', Function = function(callback) if KrystalSpeed and KrystalSpeed.Object then KrystalSpeed.Object.Visible = callback end end})
	KrystalSpeed = Fly:CreateSlider({Name = 'Krystal Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
	SigridKit = Fly:CreateToggle({Name = 'Sigrid', Function = function(callback) if SigridSpeed and SigridSpeed.Object then SigridSpeed.Object.Visible = callback end end})
	SigridSpeed = Fly:CreateSlider({Name = 'Sigrid Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
	GrimKit = Fly:CreateToggle({Name = 'Grim Reaper', Function = function(callback) if GrimSpeed and GrimSpeed.Object then GrimSpeed.Object.Visible = callback end end})
	GrimSpeed = Fly:CreateSlider({Name = 'Grim Reaper Speed', Min = 1, Max = 80, Default = 37, Suffix = ' studs/s', Darker = true, Visible = false})
	ZephyrKit = Fly:CreateToggle({Name = 'Zephyr', Function = function(callback) if ZephyrSpeed and ZephyrSpeed.Object then ZephyrSpeed.Object.Visible = callback end end})
	ZephyrSpeed = Fly:CreateSlider({Name = 'Zephyr Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	PopBalloons = Fly:CreateToggle({
		Name = 'Pop Balloons',
		Default = true
	})
	TP = Fly:CreateToggle({
		Name = 'TP Down',
		Default = true
	})
end)

-- render/HitboxESP.lua
run(function()
	local HitboxESP
	local Color
	local Transparency
	local Walls
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Name = 'AetherHitboxESP'
	Folder.Parent = vape.gui

	local function isValid(ent)
		return ent.Player and ent.Player ~= lplr and ent.Character and ent.Character.Parent
	end

	local function remove(ent)
		local refs = Reference[ent]
		if not refs then
			return
		end
		for _, adornment in refs do
			adornment:Destroy()
		end
		Reference[ent] = nil
	end

	local function add(ent)
		if not isValid(ent) then
			return
		end
		remove(ent)

		local refs = {}
		local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		for _, part in ent.Character:GetDescendants() do
			if part:IsA('BasePart') and part.Transparency < 1 and part.Name ~= 'HumanoidRootPart' then
				local box = Instance.new('BoxHandleAdornment')
				box.Name = 'Hitbox'
				box.Adornee = part
				box.Size = part.Size
				box.CFrame = CFrame.identity
				box.AlwaysOnTop = Walls.Enabled
				box.ZIndex = 0
				box.Color3 = color
				box.Transparency = Transparency.Value
				box.Parent = Folder
				table.insert(refs, box)
			end
		end
		Reference[ent] = refs
	end

	HitboxESP = vape.Categories.Render:CreateModule({
		Name = 'HitboxESP',
		Function = function(callback)
			if callback then
				HitboxESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					add(ent)
				end))
				HitboxESP:Clean(entitylib.Events.EntityRemoved:Connect(function(ent)
					remove(ent)
				end))
				HitboxESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for ent, refs in Reference do
						local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						for _, box in refs do
							box.Color3 = color
						end
					end
				end))
				for _, ent in entitylib.List do
					add(ent)
				end
			else
				for ent in Reference do
					remove(ent)
				end
			end
		end,
		Tooltip = 'Displays player hitboxes as transparent coloured boxes.'
	})

	Color = HitboxESP:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for ent, refs in Reference do
				local color = entitylib.getEntityColor(ent) or Color3.fromHSV(hue, sat, val)
				for _, box in refs do
					box.Color3 = color
				end
			end
		end
	})

	Transparency = HitboxESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.65,
		Decimal = 10,
		Function = function(value)
			for _, refs in Reference do
				for _, box in refs do
					box.Transparency = value
				end
			end
		end
	})

	Walls = HitboxESP:CreateToggle({
		Name = 'Render Walls',
		Default = true,
		Function = function(callback)
			for _, refs in Reference do
				for _, box in refs do
					box.AlwaysOnTop = callback
				end
			end
		end
	})
end)