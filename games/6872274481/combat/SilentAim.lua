run(function()
	local SilentAim
	local Targets
	local TargetPart
	local Sort
	local Prediction
	local FOV
	local OtherProjectiles
	local Blacklist

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}

	local launchHook

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService.GetMouseLocation(inputService)
	end

	local function getPosition(ent)
		if TargetPart.Value == 'Closest' then
			local localPosition, magnitude, part = getMousePosition(), 9e9, nil
			for _, v in ent:GetChildren() do
				if v:IsA('BasePart') then
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
			return part and part.Position or ent.PrimaryPart and ent.PrimaryPart.Position
		elseif TargetPart.Value == 'Dynamic' then
			local tool = store.hand.tool
			if tool and tool.Name:find('headhunter') and ent:FindFirstChild('Head') then
				return ent.Head.Position
			end
			return ent.PrimaryPart and ent.PrimaryPart.Position
		end
		return
	end

	local function solveSilent(launch, launchMeta)
		local origin = launch and launch.positionFrom
		local velocity = launch and launch.initialVelocity
		local projType = launchMeta and launchMeta.projectile
		if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or type(projType) ~= 'string' then
			return
		end

		if (not OtherProjectiles.Enabled) and not projType:find('arrow') then
			return
		end

		if table.find(Blacklist.ListEnabled or {}, ((projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType)) then
			return
		end

		local meta = launchMeta.getProjectileMeta and launchMeta:getProjectileMeta() or bedwars.ProjectileMeta[projType]
		if not meta then return end

		local speed = velocity.Magnitude
		if speed <= 0 then return end
		local gravity = launch.gravitationalAcceleration or meta.gravitationalAcceleration or 196.2

		local plr = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Sort = sortmethods[Sort.Value or 'Distance'],
			Origin = origin,
		})
		if not plr then return end

		local targetpart = plr[TargetPart.Value]
		local targetpos = getPosition(plr.Character) or targetpart and targetpart.Position
		if not targetpos then return end
		local pearl = projType == 'telepearl'
		local solution = solveBedwarsProjectile(origin, speed, gravity, plr, targetpos, {
			Lifetime = launch.deltaT or meta.lifetimeSec or 3,
			PredictionScale = Prediction.Value,
			Stationary = pearl,
			RaycastParams = rayCheck
		})
		if not solution then return end

		targetinfo.Targets[plr] = tick() + 1
		return solution.Velocity
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if callback then
				if vape.Modules.ProjectileAimbot and vape.Modules.ProjectileAimbot.Enabled then
					notif('SilentAim', 'Disable ProjectileAimbot before enabling SilentAim.', 5, 'warning')
					SilentAim:Toggle()
					return
				end
				launchHook = bedwars.ProjectileLaunchHook:Add('SilentAim', 15, function(nextLaunch, ...)
					local launch = nextLaunch(...)
					-- ProjectileAimbot is the stronger explicit aim module; do not overwrite its result.
					if not (vape.Modules.ProjectileAimbot and vape.Modules.ProjectileAimbot.Enabled) then
						local velocity = solveSilent(launch, select(2, ...))
						if velocity then launch.initialVelocity = velocity end
					end
					return launch
				end)
				SilentAim:Clean(function()
					if launchHook then launchHook(); launchHook = nil end
				end)
			elseif launchHook then
				launchHook()
				launchHook = nil
			end
		end,
		Tooltip = 'Redirects projectile launch velocity toward the selected target without intercepting or blocking projectile remotes'
	})
	Targets = SilentAim:CreateTargets({
		Players = true,
		Walls = true,
	})
	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Dynamic', 'Closest'},
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = SilentAim:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Prediction = SilentAim:CreateSlider({
		Name = 'Prediction',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10
	})
	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	OtherProjectiles = SilentAim:CreateToggle({
		Name = 'Other Projectiles',
		Function = function(call)
			if Blacklist and Blacklist.Object then
				Blacklist.Object.Visible = call
			end
		end,
	    Default = true
	})
	Blacklist = SilentAim:CreateTextList({
		Name = 'Blacklist',
		Default = {'gloop', 'telepearl'},
		Darker = true,
		Placeholder = 'projectile'
	})
end)