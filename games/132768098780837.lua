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

local function heldTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
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

-- Remember real game calls. Several remotes require extra data which changes between rounds;
-- replaying the game's own arguments is considerably more reliable than fabricating them.
local lastBlockHit
local lastBlockPlace
local lastAbility
if hookmetamethod and getnamecallmethod then
	local oldNamecall
	oldNamecall = hookmetamethod(game, '__namecall', function(self, ...)
		if getnamecallmethod() == 'FireServer' and typeof(self) == 'Instance' then
			local args = table.pack(...)
			if self.Name == 'Block_AttemptHit' then
				lastBlockHit = {Remote = self, Args = args}
			elseif self.Name == 'Block_Place' or self.Name == 'Block_AttemptPlace' then
				lastBlockPlace = {Remote = self, Args = args}
			elseif self.Name == 'Ability_Use' then
				lastAbility = {Remote = self, Args = args}
			end
		end
		return oldNamecall(self, ...)
	end)
end

local function replay(call)
	if call and call.Remote.Parent then
		call.Remote:FireServer(table.unpack(call.Args, 1, call.Args.n))
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
	Tooltip = 'Removes the hit delay from the block you are currently breaking',
	Function = function(enabled)
		if not enabled then return end
		task.spawn(function()
			repeat
				-- Use the exact block, camera data, and tool data from the normal hit request.
				-- The old implementation only hit cores and therefore did nothing to most blocks.
				replay(lastBlockHit)
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
	Tooltip = 'Disables local detectors and rejects abrupt server position corrections',
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
			task.spawn(function()
				local currentRoot = root()
				local accepted = currentRoot and currentRoot.CFrame
				repeat
					runService.PreSimulation:Wait()
					currentRoot = root()
					if currentRoot then
						local current = currentRoot.CFrame
						if accepted and (current.Position - accepted.Position).Magnitude > 14 then
							currentRoot.CFrame = accepted
							currentRoot.AssemblyLinearVelocity = Vector3.zero
						else
							accepted = current
						end
					else
						accepted = nil
					end
				until not AntiCheatDisabler.Enabled
			end)
		else
			for _, connection in disabledConnections do if connection.Enable then connection:Enable() end end
			table.clear(disabledConnections)
		end
	end
})

local function abilityActive()
	local character = lplr.Character
	if not character then return false end
	for name, value in character:GetAttributes() do
		name = name:lower()
		if name:find('ability', 1, true) and (name:find('active', 1, true) or name:find('using', 1, true)) then
			return value == true
		end
	end
	for _, value in character:GetDescendants() do
		local name = value.Name:lower()
		if value:IsA('BoolValue') and name:find('ability', 1, true) and name:find('active', 1, true) then
			return value.Value
		end
	end
	return false
end

local InfiniteAbility = vape.Categories.Blatant:CreateModule({
	Name = 'InfiniteAbility',
	Tooltip = 'Extends an ability only while the character reports that it is active',
	Function = function(enabled)
		if not enabled then return end
		task.spawn(function()
			repeat
				if abilityActive() then replay(lastAbility) end
				runService.Heartbeat:Wait()
			until not InfiniteAbility.Enabled
		end)
	end
})

local ScaffoldLimit
local blockWords = {'block', 'wool', 'stone', 'plank', 'wood', 'brick', 'concrete'}
local function isBlockTool(tool)
	if not tool then return false end
	if tool:GetAttribute('BlockType') or tool:GetAttribute('Placeable') then return true end
	local name = tool.Name:lower()
	for _, word in blockWords do if name:find(word, 1, true) then return true end end
	return false
end

local function placeBelow()
	local currentRoot = root()
	local tool = heldTool()
	if not currentRoot or (ScaffoldLimit.Enabled and not isBlockTool(tool)) then return end
	local position = Vector3.new(
		math.floor(currentRoot.Position.X / 3 + 0.5) * 3,
		math.floor((currentRoot.Position.Y - 3.5) / 3 + 0.5) * 3,
		math.floor(currentRoot.Position.Z / 3 + 0.5) * 3
	)
	local remote = getRemote('BedWarsRemotes', 'Block_Place') or getRemote('BedWarsRemotes', 'Block_AttemptPlace')
	if remote then
		remote:FireServer({
			blockPosition = position,
			position = position,
			blockType = tool and (tool:GetAttribute('BlockType') or tool.Name) or nil,
			item = tool
		})
	elseif lastBlockPlace then
		replay(lastBlockPlace)
	end
end

local Scaffold = vape.Categories.Utility:CreateModule({
	Name = 'Scaffold',
	Tooltip = 'Automatically places blocks beneath the player',
	Function = function(enabled)
		if not enabled then return end
		task.spawn(function()
			repeat
				placeBelow()
				task.wait(0.05)
			until not Scaffold.Enabled
		end)
	end
})
ScaffoldLimit = Scaffold:CreateToggle({Name = 'Limit to items'})

local NoCPSCap = vape.Categories.Combat:CreateModule({
	Name = 'NoCPSCap',
	Tooltip = 'Sends every sword activation instead of waiting for the client swing cap',
	Function = function(enabled)
		if not enabled then return end
		local character = lplr.Character
		local function bind(tool)
			if not tool:IsA('Tool') then return end
			NoCPSCap:Clean(tool.Activated:Connect(function()
				local remote = getRemote('CombatRemotes', 'Combat_SwingStarted')
				if remote then remote:FireServer(tool.Name) end
			end))
		end
		if character then
			for _, tool in character:GetChildren() do bind(tool) end
			NoCPSCap:Clean(character.ChildAdded:Connect(bind))
		end
	end
})
