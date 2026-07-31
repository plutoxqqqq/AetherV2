-- Never operate this game's remotes in another place, even when this file is force-loaded.
if game.PlaceId ~= 132768098780837 then return end

local vape = shared.vape
local players = game:GetService('Players')
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
local lplr = players.LocalPlayer

local function getRemote(folder, name)
	local events = replicatedStorage:FindFirstChild('GameEvents')
	local remotes = events and events:FindFirstChild(folder)
	return remotes and remotes:FindFirstChild(name)
end

local function root()
	return lplr.Character and lplr.Character:FindFirstChild('HumanoidRootPart')
end

local function blocks()
	local result = {}
	local function add(object)
		local name = object.Name:lower()
		if object:IsA('BasePart') and (name:find('core', 1, true) or name == 'placedblock') then
			table.insert(result, object)
		end
	end
	for _, object in workspace:GetDescendants() do add(object) end
	-- Cores in this game can be unparented while retaining a valid engine reference.
	if getnilinstances then
		for _, object in getnilinstances() do add(object) end
	end
	return result
end

local function hitBlock(block)
	local remote = getRemote('BedWarsRemotes', 'Block_AttemptHit')
	local camera = workspace.CurrentCamera
	if remote and root() and camera and block then
		remote:FireServer({camPos = camera.CFrame.Position, hitPos = block.Position, blockInstance = block})
		return true
	end
	return false
end

local BreakerRange
local Breaker = vape.Categories.World:CreateModule({
	Name = 'Breaker',
	Tooltip = 'Automatically breaks nearby cores, including unparented core blocks',
	Function = function(enabled)
		if not enabled then return end
		task.spawn(function()
			repeat
				local currentRoot = root()
				if currentRoot then
					for _, block in blocks() do
						if (block.Position - currentRoot.Position).Magnitude <= BreakerRange.Value then hitBlock(block) end
					end
				end
				task.wait(0.08)
			until not Breaker.Enabled
		end)
	end
})
BreakerRange = Breaker:CreateSlider({Name = 'Range', Min = 1, Max = 30, Default = 18})

local FastBreak = vape.Categories.World:CreateModule({
	Name = 'FastBreak',
	Tooltip = 'Continuously sends hits so no client-side block cooldown is observed',
	Function = function(enabled)
		if not enabled then return end
		task.spawn(function()
			repeat
				local currentRoot = root()
				if currentRoot then
					for _, block in blocks() do
						if (block.Position - currentRoot.Position).Magnitude <= 18 then hitBlock(block) end
					end
				end
				runService.Heartbeat:Wait()
			until not FastBreak.Enabled
		end)
	end
})

local AntiDeath = vape.Categories.Blatant:CreateModule({
	Name = 'AntiDeath',
	Tooltip = 'Blocks the dead state and rescues the character from the void',
	Function = function(enabled)
		if not enabled then return end
		task.spawn(function()
			local safeCFrame
			local humanoid
			repeat
				local currentRoot = root()
				humanoid = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Humanoid')
				if currentRoot and humanoid then
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
					if humanoid.Health < 1 then humanoid.Health = 1 end
					if currentRoot.Position.Y > workspace.FallenPartsDestroyHeight + 20 then
						safeCFrame = currentRoot.CFrame
					elseif safeCFrame then
						currentRoot.AssemblyLinearVelocity = Vector3.zero
						currentRoot.CFrame = safeCFrame
					end
				end
				runService.Heartbeat:Wait()
			until not AntiDeath.Enabled
			if humanoid then humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end
		end)
	end
})

local disabledConnections = {}
local AntiCheatDisabler = vape.Categories.Blatant:CreateModule({
	Name = 'AntiCheatDisabler',
	Tooltip = 'Disables local movement detectors and anti-cheat remote teleport handlers',
	Function = function(enabled)
		if enabled then
			for _, object in lplr.PlayerScripts:GetDescendants() do
				if object:IsA('LocalScript') then
					local name = object.Name:lower()
					if name:find('anti', 1, true) or name:find('detect', 1, true) then object.Disabled = true end
				end
			end
			if getconnections then
				for _, object in replicatedStorage:GetDescendants() do
					local name = object.Name:lower()
					if object:IsA('RemoteEvent') and (name:find('anti', 1, true) or name:find('detect', 1, true) or name:find('teleport', 1, true)) then
						for _, connection in getconnections(object.OnClientEvent) do
							if connection.Disable then connection:Disable(); table.insert(disabledConnections, connection) end
						end
					end
				end
			end
		else
			for _, connection in disabledConnections do if connection.Enable then connection:Enable() end end
			table.clear(disabledConnections)
		end
	end
})

local InfiniteAbility = vape.Categories.Blatant:CreateModule({
	Name = 'InfiniteAbility',
	Tooltip = 'Uses Ability_Use every heartbeat without a client cooldown',
	Function = function(enabled)
		if not enabled then return end
		task.spawn(function()
			repeat
				local remote = getRemote('BedWarsRemotes', 'Ability_Use')
				if remote then remote:FireServer() end
				runService.Heartbeat:Wait()
			until not InfiniteAbility.Enabled
		end)
	end
})
