-- Support is intentionally bound to the real place. Force-loading this file elsewhere only
-- validates the loader and must not send this game's remotes in an unrelated experience.
if game.PlaceId ~= 132768098780837 then return end

local vape = shared.vape
local players = game:GetService('Players')
local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')
local lplr = players.LocalPlayer
local remotes = replicatedStorage:WaitForChild('GameEvents'):WaitForChild('BedWarsRemotes')
local hitRemote = remotes:WaitForChild('Block_AttemptHit')
local abilityRemote = remotes:WaitForChild('Ability_Use')

local function root()
	local character = lplr.Character
	return character and character:FindFirstChild('HumanoidRootPart')
end

local function isCore(object)
	local name = object.Name:lower()
	return object:IsA('BasePart') and (name:find('core', 1, true) or name == 'placedblock')
end

local function hitBlock(block)
	local characterRoot = root()
	if characterRoot and block and block.Parent then
		hitRemote:FireServer({camPos = workspace.CurrentCamera.CFrame.Position, hitPos = block.Position, blockInstance = block})
	end
end

local BreakerRange
local Breaker = vape.Categories.World:CreateModule({
	Name = 'Breaker',
	Tooltip = 'Automatically breaks nearby cores',
	Function = function(enabled)
		if enabled then
			task.spawn(function()
				repeat
					local characterRoot = root()
					if characterRoot then
						for _, object in workspace:GetDescendants() do
							if isCore(object) and (object.Position - characterRoot.Position).Magnitude <= BreakerRange.Value then
								hitBlock(object)
							end
						end
					end
					task.wait(0.1)
				until not Breaker.Enabled
			end)
		end
	end
})
BreakerRange = Breaker:CreateSlider({Name = 'Range', Min = 1, Max = 30, Default = 18})

local FastBreak = vape.Categories.World:CreateModule({
	Name = 'FastBreak',
	Tooltip = 'Removes the delay between block hit requests',
	Function = function(enabled)
		if enabled then
			task.spawn(function()
				repeat
					local characterRoot = root()
					if characterRoot then
						for _, object in workspace:GetDescendants() do
							if isCore(object) and (object.Position - characterRoot.Position).Magnitude <= 18 then hitBlock(object) end
						end
					end
					runService.Heartbeat:Wait()
				until not FastBreak.Enabled
			end)
		end
	end
})

local AntiDeath = vape.Categories.Blatant:CreateModule({
	Name = 'AntiDeath',
	Tooltip = 'Prevents the local humanoid from entering the dead state',
	Function = function(enabled)
		if enabled then
			task.spawn(function()
				repeat
					local humanoid = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Humanoid')
					if humanoid then
						humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
						if humanoid.Health < 1 then humanoid.Health = 1 end
					end
					task.wait()
				until not AntiDeath.Enabled
				local humanoid = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Humanoid')
				if humanoid then humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end
			end)
		end
	end
})

local AntiCheatDisabler = vape.Categories.Blatant:CreateModule({
	Name = 'AntiCheatDisabler',
	Tooltip = 'Disables local movement-detection scripts and their teleport-back connections',
	Function = function(enabled)
		if enabled then
			for _, object in lplr.PlayerScripts:GetDescendants() do
				if object:IsA('LocalScript') then
					local name = object.Name:lower()
					if name:find('anticheat', 1, true) or name:find('movementcheck', 1, true) then object.Disabled = true end
				end
			end
		end
	end
})

local InfiniteAbility = vape.Categories.Blatant:CreateModule({
	Name = 'InfiniteAbility',
	Tooltip = 'Continuously uses the equipped ability without a client cooldown',
	Function = function(enabled)
		if enabled then
			task.spawn(function()
				repeat
					abilityRemote:FireServer()
					runService.Heartbeat:Wait()
				until not InfiniteAbility.Enabled
			end)
		end
	end
})
