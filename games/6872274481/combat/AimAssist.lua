run(function()
    local AimAssist
    local AimMode
    local Mode
    local Targets
    local Sort
    local AimPart
    local AimSpeed
    local Shake
    local Distance
    local AngleSlider
    local StrafeIncrease
    local BlockBreak
    local KillauraTarget
    local ClickAim
    local Mouse
    local Limit

    local function ease(t)
	return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
    end

    local cache = {}
    local function getMousePosition()
	if inputService.TouchEnabled then
		return gameCamera.ViewportSize / 2
	end
	return inputService.GetMouseLocation(inputService)
    end

    local function getAim(ent)
	if AimPart.Value == 'Closest' then
		if not cache[ent.Character] then
			cache[ent.Character] = ent.Character:GetChildren()
		end
		local localPosition, magnitude, part = getMousePosition(), 9e9, nil
		for _, v in cache[ent.Character] do
			if v and v.Parent and v:IsA('BasePart') then
				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)

				if vis then
					local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude

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

    local started, lasttarget = 0, nil
    local aimfuncs = {
	Simple = function(localcframe, ent, fps)
		local rng = Random.new()
		local speed = (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0))

		return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
	end,
	Adaptive = function(localcframe, ent, fps)
		local prog, rng = ease(math.min(tick() - started, 1)), Random.new()
		local speed = (AimSpeed.Value * 0.1 * prog) + (1 - prog) + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 5)
		return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
	end
    }

    local function GetTarget()
	if lasttarget then
		local localPosition = entitylib.character.RootPart.Position
		if not lasttarget or not lasttarget.RootPart or not lasttarget.Humanoid or not lasttarget.Humanoid.Health or lasttarget.Humanoid.Health <= 0 then
			return false
		end
		if (localPosition - lasttarget.RootPart.Position).Magnitude > Distance.Value then
			return false
		end
		if Targets.Walls.Enabled and entitylib.Wallcheck(localPosition, lasttarget.RootPart.Position, Targets.Walls.Enabled) then
			return false
		end
		return lasttarget
	end

	return false
    end

    local function getAttackData()
	if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.15 then
		return false
	end
	if ClickAim.Enabled and (tick() - bedwars.SwordController.lastSwing) > 0.3 then
		return false
	end
	if BlockBreak.Enabled and (tick() - store.lastHit) < 0.3 then
		return false
	end
	if Limit.Enabled and store.hand.toolType ~= 'sword' then
		return false
	end

	if (tick() - started) > 1 or not lasttarget or not lasttarget.Parent or not lasttarget.Humanoid or lasttarget.Humanoid.Health <= 0 then
		local ent = GetTarget() or KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
			Range = Distance.Value,
			Part = 'RootPart',
			Wallcheck = Targets.Walls.Enabled,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Sort = sortmethods[Sort.Value],
		})
		if ent then
			started = tick()
		end
		lasttarget = ent
	end
	return lasttarget
    end

    AimAssist = vape.Categories.Combat:CreateModule({
	Name = 'AimAssist',
	Function = function(callback)
		if callback then
			local rotate = 0

			AimAssist:Clean(runService.PostSimulation:Connect(function(dt)
				if entitylib.isAlive then
					entitylib.character.Humanoid.AutoRotate = tick() > rotate

					local ent = getAttackData()
					if ent then
						local root = entitylib.character.RootPart
						local delta = (ent.RootPart.Position - root.Position)
						local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
						local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
						if angle >= (math.rad(AngleSlider.Value) / 2) then
							return
						end
						targetinfo.Targets[ent] = tick() + 1

						local cframe, speed = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
						if AimMode.Value == 'First person' or AimMode.Value == 'Dynamic' and entitylib.character.Head.LocalTransparencyModifier == 1 then
							gameCamera.CFrame = cframe
						elseif AimMode.Value == 'Third person' or AimMode.Value == 'Dynamic' and entitylib.character.Head.LocalTransparencyModifier ~= 1 then
							cframe, speed = aimfuncs[Mode.Value](root.CFrame, ent, dt)
							entitylib.character.Humanoid.AutoRotate = false
							root.CFrame = CFrame.lookAlong(root.Position, cframe.LookVector * Vector3.new(1, 0, 1))
							rotate = tick() + 0.1
						elseif AimMode.Value == 'Mouse' then
							local viewport = gameCamera:WorldToViewportPoint(cframe.Position)
							local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
							mousemoverel(pos.X, pos.Y)
						end
					end
				end
			end))
		end
	end,
	Tooltip = 'Smoothly aims to closest valid target with sword'
    })
    Targets = AimAssist:CreateTargets({
	Players = true,
	Walls = true,
    })
    local modes = {}
    for i in aimfuncs do
	table.insert(modes, i)
    end
    AimMode = AimAssist:CreateDropdown({
	Name = 'Aim perspective',
	Tooltip = 'First person - camera\nThird person - turns your character\nMouse - moves your mouse\nDynamic - whichever you are in',
	List = {'First person', 'Third person', 'Mouse', 'Dynamic'},
	Default = 'First person'
    })
    Mode = AimAssist:CreateDropdown({
	Name = 'Mode',
	List = modes,
	Tooltip = 'Simple - Smooth aiming\nAdaptive - Advanced tracking with adaptive behavior',
	Default = modes[1],
    })
    local methods = {'Damage', 'Distance'}
    for _, i in sortlist do
	if not table.find(methods, i) then
		table.insert(methods, i)
	end
    end
    ClickAim = AimAssist:CreateToggle({
	Name = 'Click aim',
	Default = true,
    })
    Mouse = AimAssist:CreateToggle({Name = 'Require mouse down'})
    StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
    BlockBreak = AimAssist:CreateToggle({Name = 'Check block break'})
    KillauraTarget = AimAssist:CreateToggle({Name = 'Use killaura target'})
    AimSpeed = AimAssist:CreateSlider({
	Name = 'Aim speed',
	Min = 1,
	Max = 20,
	Default = 6,
    })
    Distance = AimAssist:CreateSlider({
	Name = 'Distance',
	Min = 1,
	Max = 30,
	Default = 30,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    Shake = AimAssist:CreateSlider({
	Name = 'Shake',
	Min = 0,
	Max = 100,
	Default = 0,
	Tooltip = 'Adds random jitter to simulate human aim',
    })
    AngleSlider = AimAssist:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 70,
    })
    Limit = AimAssist:CreateToggle({
	Name = 'Limit to items',
	Tooltip = 'Only attacks when sword is held',
    })
    Sort = AimAssist:CreateDropdown({
	Name = 'Target mode',
	List = methods,
	Default = 'Angle',
    })
    AimPart = AimAssist:CreateDropdown({
	Name = 'Target area',
	List = {'Center', 'Closest'},
	Default = 'Center',
    })
end)