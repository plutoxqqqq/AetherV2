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
