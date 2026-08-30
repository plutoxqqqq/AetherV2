run(function()
    local BowAssist
    local Targets
    local Sort
    local Shake
    local Speed
    local Angle
    local FOV
    local AimPart
    local Distance
    local Smoothness
    local Clear
    local Blacklist
    local Mouse
    local ThirdPerson
    local Projectiles
    local aimRandom = Random.new()

    local function ease(t)
	return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
    end

    local function findAim(localcframe, predicted, fps, started, offset)
	local prog, rng = ease(math.min((tick() - started) / (1 / (Speed.Value * 0.5)), 1)), aimRandom
	local speed = (Speed.Value / Smoothness.Value) * prog

	return localcframe:Lerp(CFrame.lookAt(localcframe.p, predicted + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, offset + ((rng:NextNumber() - 0.5) * Shake.Value * fps), (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
    end

    local launchHook
    local lasttarget, started = nil, 0
    local function getAttackData()
	if not entitylib.isAlive then
		return false
	end
	if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) then
		return false
	end
	if not store.hand.tool or not bedwars.ItemMeta[store.hand.tool.Name].projectileSource and store.hand.toolType ~= 'bow' then
		return false
	end
	if Blacklist.Enabled and table.find(Projectiles.ListEnabled, store.hand.tool.Name == 'glue_trap' and 'gloop' or store.hand.tool.Name) then
		return false
	end

	if (tick() - started) > 1 or not lasttarget or not lasttarget.Parent or not lasttarget.Humanoid or lasttarget.Humanoid.Health <= 0 then
		local ent = entitylib.EntityMouse({
			Origin = entitylib.character.RootPart.Position,
			Range = FOV.Value,
			Part = AimPart.Value,
			Wallcheck = Targets.Walls.Enabled,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Sort = sortmethods[Sort.Value],
		})
		if ent and (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude > Distance.Value then ent = nil end
		if ent then
			started = tick()
		end
		lasttarget = ent
	end
	return lasttarget
    end

    local rayCheck = RaycastParams.new()

    BowAssist = vape.Categories.Combat:CreateModule({
	Name = 'BowAssist',
	Function = function(callback)
		if callback then
			local multi, predicted = 0, nil
			local lastpredicted = 0
			local lastent, found, update = nil, 0, 0

			launchHook = bedwars.ProjectileLaunchHook:Add('BowAssist', 10, function(nextLaunch, ...)
				local res = nextLaunch(...)
				local projmeta = select(2, ...)
				multi = projmeta and (projmeta.velocityMultiplier + 2) or 0
				if projmeta and tick() - update < 0.1 and lastent and lastent.RootPart then
					local meta = projmeta:getProjectileMeta()
					local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
					local calc = prediction.SolveTrajectory(entitylib.character.RootPart.Position, (meta.launchVelocity or 100) * (1 - lplr:GetNetworkPing()), gravity, lastent.RootPart.Position, lastent.RootPart.Velocity, workspace.Gravity, entitylib.character.HipHeight, nil, rayCheck)
					predicted = calc
					lastpredicted = tick()
				else
					predicted = nil
				end
				return res
			end)

			BowAssist:Clean(runService.PostSimulation:Connect(function(dt)
				local ent = getAttackData()
				if ent then
					local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
					local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
					local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
					if angle >= (math.rad(Angle.Value) / 2) then
						return
					end
					if ent ~= lastent then
						found = tick()
					end
					lastent = ent
					update = tick()
					if tick() - lastpredicted < 0.1 then
						targetinfo.Targets[ent] = tick() + 1
						local aimPosition = predicted or ent[AimPart.Value].Position
						if Clear.Enabled then
							rayCheck.FilterDescendantsInstances = {lplr.Character, ent.Character, gameCamera}
							if workspace:Raycast(gameCamera.CFrame.Position, aimPosition - gameCamera.CFrame.Position, rayCheck) then return end
						end
						local cframe, speed = findAim(gameCamera.CFrame, aimPosition, dt, found, multi + ((entitylib.character.RootPart.Position.Y - ent.RootPart.Position.Y) / 7))
						if inputService.MouseEnabled and entitylib.character.Head.LocalTransparencyModifier == 1 then
							gameCamera.CFrame = cframe
						elseif ThirdPerson.Enabled and inputService.MouseEnabled then
							local viewport = gameCamera:WorldToViewportPoint(aimPosition)
							local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
							mousemoverel(pos.X, pos.Y)
						end
					end
				end
			end))
		else
			if launchHook then
				launchHook()
				launchHook = nil
			end
		end
	end,
        Tooltip = 'Smoothly aims your projectile trajectory to the target'
    })

    Targets = BowAssist:CreateTargets({
	Players = true,
	Walls = true,
    })
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
	if not table.find(methods, i) then
		table.insert(methods, i)
	end
    end
    Sort = BowAssist:CreateDropdown({
	Name = 'Target mode',
	List = methods,
	Default = 'Angle',
    })
    AimPart = BowAssist:CreateDropdown({Name = 'Part', List = {'RootPart', 'Head'}})
    Distance = BowAssist:CreateSlider({Name = 'Distance', Min = 1, Max = 300, Default = 200, Suffix = ' studs'})
    Speed = BowAssist:CreateSlider({
	Name = 'Aim speed',
	Min = 1,
	Max = 20,
	Default = 7,
	Suffix = 'sp/s',
	Tooltip = 'How fast you will aim per second',
    })
    Smoothness = BowAssist:CreateSlider({Name = 'Smoothness', Min = 1, Max = 20, Default = 2, Decimal = 10, Tooltip = 'Divides aim speed to soften camera movement.'})
    Angle = BowAssist:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 120,
    })
    Shake = BowAssist:CreateSlider({
	Name = 'Shake',
	Min = 1,
	Max = 100,
	Default = 5,
	Tooltip = 'Jitters your screen, Simulating human aim',
    })
    FOV = BowAssist:CreateSlider({
	Name = 'FOV',
	Min = 1,
	Max = 1000,
	Default = 200,
    })
    Mouse = BowAssist:CreateToggle({
	Name = 'Require mouse down',
	Default = inputService.KeyboardEnabled,
    })
    ThirdPerson = BowAssist:CreateToggle({
	Name = 'Use mouse aim',
	Tooltip = 'Aims using the mouse if you are on third person',
	Default = true,
    })
    Blacklist = BowAssist:CreateToggle({
	Name = 'Use blacklist',
	Default = true,
	Function = function(callback)
		if Projectiles then
			Projectiles.Object.Visible = callback
		end
	end,
	Tooltip = 'Doesn\'t bow-assist if your holding one of the blacklisted projectiles',
    })
    Projectiles = BowAssist:CreateTextList({
	Name = 'Blacklisted',
	Default = { 'fireball', 'telepearl', 'gloop' },
	Darker = true,
    })
    Clear = BowAssist:CreateToggle({Name = 'Clear shot only', Default = true, Tooltip = 'Stops assisting when the aim path is obstructed.'})
end)