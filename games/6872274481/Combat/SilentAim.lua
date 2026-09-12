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

	local function resolveTargetPart(ent, requested, projectileType)
		local character = ent and ent.Character
		local root = ent and (ent.RootPart or ent.HumanoidRootPart) or character and character.PrimaryPart
		if not character then return root end
		local function first(...)
			for index = 1, select('#', ...) do
				local partName = select(index, ...)
				local part = partName and character:FindFirstChild(partName)
				if part and part:IsA('BasePart') then return part end
			end
			return root
		end
		if requested == 'Dynamic' then
			requested = tostring(projectileType or ''):lower():find('headhunter', 1, true) and 'Head' or 'RootPart'
		end
		if requested == 'Head' then return first('Head') end
		if requested == 'Torso' then return first('UpperTorso', 'Torso', 'LowerTorso') end
		if requested == 'Left arm' then return first('LeftHand', 'LeftLowerArm', 'LeftUpperArm', 'Left Arm') end
		if requested == 'Right arm' then return first('RightHand', 'RightLowerArm', 'RightUpperArm', 'Right Arm') end
		if requested == 'Left leg' then return first('LeftFoot', 'LeftLowerLeg', 'LeftUpperLeg', 'Left Leg') end
		if requested == 'Right leg' then return first('RightFoot', 'RightLowerLeg', 'RightUpperLeg', 'Right Leg') end
		if requested == 'Random' then
			local available = {first('Head'), first('UpperTorso', 'Torso'), first('LeftHand', 'Left Arm'), first('RightHand', 'Right Arm'), first('LeftFoot', 'Left Leg'), first('RightFoot', 'Right Leg')}
			local filtered = {}
			for _, part in ipairs(available) do if part and part ~= root then table.insert(filtered, part) end end
			return #filtered > 0 and filtered[math.random(1, #filtered)] or root
		end
		return root
	end

	local function chooseTarget(origin, projectileType)
		local ent = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			Priority = Targets.Priority and Targets.Priority.Value,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Origin = origin,
			Sort = sortmethods[Sort.Value]
		})
		if not ent then return end
		local part = resolveTargetPart(ent, TargetPart.Value, projectileType)
		if not part or not part.Parent then return end
		return ent, part
	end

	local function solveShot(launch, projmeta, worldmeta)
		if type(launch) ~= 'table' or typeof(launch.positionFrom) ~= 'Vector3'
			or typeof(launch.initialVelocity) ~= 'Vector3' or not projmeta then
			return
		end

		local projectileType = tostring(projmeta.projectile or '')
		if projectileType == '' then return end
		if (not OtherProjectiles.Enabled) and not projectileType:find('arrow') then return end

		local blacklistName = (projectileType == 'glue_trap' or projectileType == 'glue_projectile') and 'gloop' or projectileType
		if table.find(Blacklist.ListEnabled or {}, blacklistName) then return end

		local origin = launch.positionFrom
		local ent, part = chooseTarget(origin, projectileType)
		if not ent or not part then return end

		local ok, meta = pcall(projmeta.getProjectileMeta, projmeta)
		meta = ok and meta or bedwars.ProjectileMeta[projectileType]
		if type(meta) ~= 'table' then return end

		local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
		local gravity = launch.gravitationalAcceleration or ((meta.gravitationalAcceleration or 196.2) * (projmeta.gravityMultiplier or 1))
		local speed = tonumber(meta.launchVelocity) or launch.initialVelocity.Magnitude
		if not speed or speed <= 0 then return end

		local solution = solveBedwarsProjectile(origin, speed, gravity, ent, part.Position, {
			Lifetime = lifetime,
			PredictionScale = Prediction.Value,
			Stationary = projectileType == 'telepearl',
			RaycastParams = rayCheck
		})
		if not solution then return end

		store.hitchance.SilentAim = {Value = getHitChance(ent, (part.Position - origin).Magnitude / math.max(speed, 1)), Clock = tick()}
		targetinfo.Targets[ent] = tick() + 1
		launch.initialVelocity = solution.Velocity
		launch.positionFrom = origin
		launch.deltaT = lifetime
		launch.gravitationalAcceleration = gravity
		return launch
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
					local projmeta, worldmeta = select(2, ...), select(3, ...)
					local ok, result = pcall(solveShot, launch, projmeta, worldmeta)
					if ok and result then launch = result end
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
		Tooltip = 'Redirects the projectile you fire toward a target without ever moving your aim'
	})

	Targets = SilentAim:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic'},
		Tooltip = 'Dynamic aims at the head with a headhunter, since that is the only bow that pays extra for one, and at the body with everything else'
	})
	local methods = {'Damage', 'Distance'}
	for _, i in sortlist do
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
