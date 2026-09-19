run(function()
	local AimAssist
	local AimMode
	local Mode
	local Targets
	local Sort
	local AimPart
	local AimSpeed
	local Smoothness
	local Shake
	local Distance
	local AngleSlider
	local StrafeIncrease
	local BlockBreak
	local KillauraTarget
	local ClickAim
	local Mouse
	local Limit
	
	local rng = Random.new()
	local cache = setmetatable({}, {__mode = 'k'})
	
	local function getAim(ent)
		if AimPart.Value == 'Closest' then
			if not cache[ent.Character] then
				cache[ent.Character] = ent.Character:GetChildren()
			end
			local localPosition, magnitude, part = inputService.TouchEnabled and gameCamera.ViewportSize / 2 or inputService:GetMouseLocation(), 9e9, nil
			for _, v in cache[ent.Character] do
				if v and v.Parent and v:IsA('BasePart') then
					local position, vis = gameCamera:WorldToViewportPoint(v.Position)
					if vis then
						local mag = (localPosition - Vector2.new(position.X, position.Y)).Magnitude
						if mag < magnitude then
							magnitude = mag
							part = v
						end
					end
				end
			end
			if part then
				return part.Position
			end
		end
		return ent.RootPart.Position
	end
	
	local started, lasttarget, nextsearch = 0, nil, 0
	local aimfuncs = {
		Simple = function(localcframe, ent, fps)
			local speed = (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) / Smoothness.Value
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end,
		Adaptive = function(localcframe, ent, fps)
			local t = math.min(tick() - started, 1)
			local prog = t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
			local speed = ((AimSpeed.Value * 0.1 * prog) + (1 - prog) + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 5)) / Smoothness.Value
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end
	}
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				local rotate = 0
				AimAssist:Clean(runService.PostSimulation:Connect(function(dt)
					if entitylib.isAlive then
						entitylib.character.Humanoid.AutoRotate = tick() > rotate
	
						local blocked = Mouse.Enabled and not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.15
						blocked = blocked or (ClickAim.Enabled and (tick() - bedwars.SwordController.lastSwing) > 0.3)
						blocked = blocked or (BlockBreak.Enabled and (tick() - store.lastHit) < 0.3)
						blocked = blocked or (Limit.Enabled and store.hand.toolType ~= 'sword')
	
						local ent
						if not blocked then
							if entitylib.isAlive and lasttarget and lasttarget.Character and lasttarget.Character.Parent and lasttarget.RootPart and lasttarget.RootPart.Parent and lasttarget.Targetable and entitylib.isVulnerable(lasttarget) and (entitylib.character.RootPart.Position - lasttarget.RootPart.Position).Magnitude <= Distance.Value and not (Targets.Walls.Enabled and entitylib.Wallcheck(entitylib.character.RootPart.Position, lasttarget.RootPart.Position, Targets.Walls.Enabled, lasttarget)) and tick() < nextsearch then
								ent = lasttarget
							else
								local target = store.KillauraTarget
								ent = KillauraTarget.Enabled and entitylib.isAlive and target and target.Character and target.Character.Parent and target.RootPart and target.RootPart.Parent and target.Targetable and entitylib.isVulnerable(target) and (entitylib.character.RootPart.Position - target.RootPart.Position).Magnitude <= Distance.Value and not (Targets.Walls.Enabled and entitylib.Wallcheck(entitylib.character.RootPart.Position, target.RootPart.Position, Targets.Walls.Enabled, target)) and target or entitylib.EntityPosition({
									Range = Distance.Value,
									Part = 'RootPart',
									Wallcheck = Targets.Walls.Enabled,
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Priority = Targets.Priority.Value,
									Sort = sortmethods[Sort.Value]
								})
								if ent ~= lasttarget then
									started = tick()
								end
								lasttarget = ent
								nextsearch = tick() + 1
							end
						end
	
						if ent then
							local root = entitylib.character.RootPart
							local delta = (ent.RootPart.Position - root.Position)
							local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
							local horizontal = delta * Vector3.new(1, 0, 1)
							local angle = localfacing.Magnitude > 0 and horizontal.Magnitude > 0 and math.acos(math.clamp(localfacing.Unit:Dot(horizontal.Unit), -1, 1)) or 0
							if angle >= (math.rad(AngleSlider.Value) / 2) then
								return
							end
							targetinfo.Targets[ent] = tick() + 1
	
							local firstPerson = entitylib.character.Head.LocalTransparencyModifier == 1
							local perspective = AimMode.Value
							if perspective == 'Mouse' then
								local cframe, speed = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								local viewport = gameCamera:WorldToViewportPoint(cframe.Position)
								local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
								mousemoverel(pos.X, pos.Y)
							elseif perspective == 'First person' or (perspective == 'Dynamic' and firstPerson) then
								if not firstPerson then return end
								local cframe = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								gameCamera.CFrame = cframe
							elseif perspective == 'Third person' or (perspective == 'Dynamic' and not firstPerson) then
								if firstPerson then return end
								local cframe = aimfuncs[Mode.Value](root.CFrame, ent, dt)
								local direction = cframe.LookVector * Vector3.new(1, 0, 1)
								if direction.Magnitude > 0 then
									entitylib.character.Humanoid.AutoRotate = false
									root.CFrame = CFrame.lookAlong(root.Position, direction)
									rotate = tick() + 0.1
								end
							end
						end
					else
						lasttarget = nil
					end
				end))
			else
				lasttarget = nil
				if entitylib.isAlive then
					entitylib.character.Humanoid.AutoRotate = true
				end
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target with sword'
	})
	
	AimMode = AimAssist:CreateDropdown({
		Name = 'Aim perspective',
		Tooltip = 'First person - Uses your camera to aim\nThird person - Moves your character to where your supposed to look\nMouse - Moves your mouse & camera\nDynamic - Uses first person mode if ur in first person, and uses third person if ur in third person',
		List = {'First person', 'Third person', 'Dynamic'},
		Default = 'First person'
	})
	Mode = AimAssist:CreateDropdown({
		Name = 'Mode',
		List = {'Simple', 'Adaptive'},
		Tooltip = 'Simple - Smooth aiming\nAdaptive - Advanced tracking with adaptive behavior',
		Default = 'Simple'
	})
	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Angle', 'Damage', 'Distance'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click aim',
		Default = true
	})
	Mouse = AimAssist:CreateToggle({Name = 'Require mouse down'})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
	BlockBreak = AimAssist:CreateToggle({Name = 'Check block break'})
	KillauraTarget = AimAssist:CreateToggle({Name = 'Use killaura target'})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 6
	})
	Smoothness = AimAssist:CreateSlider({
		Name = 'Smoothness',
		Min = 1,
		Max = 20,
		Default = 1,
		Decimal = 10,
		Tooltip = 'Divides the aim speed to soften the snap, 1 leaves aiming unchanged'
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Shake = AimAssist:CreateSlider({
		Name = 'Shake',
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Adds random jitter to simulate human aim'
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
	})
	Limit = AimAssist:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks when sword is held'
	})
	Sort = AimAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Angle'
	})
	AimPart = AimAssist:CreateDropdown({
		Name = 'Target area',
		List = {'Center', 'Closest'},
		Default = 'Center'
	})
end)
