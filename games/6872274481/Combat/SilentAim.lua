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
	
	local namecall
	local lastWarn = 0
	
	-- ProjectileFire(tool, ammo, projectile, shootPosition, rootPosition, velocity, shotId, draw, timestamp)
	-- - the order every caller in the pack itself uses (see fireProjectile in base.lua, and the
	-- kit modules that fire directly). The namecall hook drops the remote that starts the vararg
	-- list, so the packed table lines up one-to-one with that call: 1 tool, 2 ammo,
	-- 3 projectile, 4 shoot position, 5 root position, 6 velocity. Off-by-one reads here are
	-- what left shots unredirected or sent a position where a velocity belongs.
	local function locateLaunch(args)
		local projType, origin, velocity, velocityIndex = args[3], args[4], args[6], 6
		if type(projType) == 'string' and typeof(origin) == 'Vector3' and typeof(velocity) == 'Vector3' then
			return projType, origin, velocity, velocityIndex
		end
		-- Changed layout: find the pieces by type instead of by position. The launch vectors
		-- always arrive in order - shoot position, root position, velocity - so the third one is
		-- the velocity. The projectile name is the nearest known meta name *before* the shoot
		-- position, walked backwards so an ammo name sitting one slot earlier cannot win.
		local vectors = {}
		for index = 1, args.n do
			if typeof(args[index]) == 'Vector3' then table.insert(vectors, index) end
		end
		if #vectors < 3 then return end
		velocityIndex = vectors[3]
		origin, velocity = args[vectors[1]], args[velocityIndex]
		for index = vectors[1] - 1, 1, -1 do
			local value = args[index]
			if type(value) == 'string' and bedwars.ProjectileMeta[value] then
				projType = value
				break
			end
		end
		if type(projType) ~= 'string' then return end
		return projType, origin, velocity, velocityIndex
	end

	local function solveSilent(args)
		local projType, origin, velocity, velocityIndex = locateLaunch(args)
		if not projType or typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' then
			return
		end
	
		if (not OtherProjectiles.Enabled) and not projType:find('arrow') then
			return
		end
	
		if table.find(Blacklist.ListEnabled or {}, ((projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType)) then
			return
		end
	
		local meta = bedwars.ProjectileMeta[projType]
		if not meta then return end
	
		local speed = velocity.Magnitude
		if speed <= 0 then return end
	
		local map = workspace:FindFirstChild('Map')
		if map ~= rayCheck.FilterDescendantsInstances[1] then
			rayCheck.FilterDescendantsInstances = map and {map} or {}
		end
		local gravity = meta.gravitationalAcceleration or 196.2
	
		local plr = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Sort = sortmethods[Sort.Value or 'Distance'],
			MouseOrigin = gameCamera.ViewportSize / 2,
			Origin = origin
		})
		if not plr then return end
	
		local targetpart = getTargetPart(plr, TargetPart.Value)
		local targetpos
		if TargetPart.Value == 'Closest' then
			local center, magnitude = gameCamera.ViewportSize / 2, 9e9
			for _, v in plr.Character:GetChildren() do
				if v:IsA('BasePart') then
					local position, vis = gameCamera:WorldToViewportPoint(v.Position)
					if vis then
						local mag = (center - Vector2.new(position.X, position.Y)).Magnitude
						if mag < magnitude then
							magnitude, targetpos = mag, v.Position
						end
					end
				end
			end
			targetpos = targetpos or plr.Character.PrimaryPart and plr.Character.PrimaryPart.Position
		elseif TargetPart.Value == 'Dynamic' then
			local tool = store.hand.tool
			if tool and tool.Name:find('headhunter') and plr.Character:FindFirstChild('Head') then
				targetpos = plr.Character.Head.Position
			else
				targetpos = plr.Character.PrimaryPart and plr.Character.PrimaryPart.Position
			end
		end
	
		targetpos = targetpos or targetpart and targetpart.Position
		if not targetpos then return end
		local playerGravity = workspace.Gravity
		local balloons = plr.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
	
		if plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end
	
		if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
			for _, v in collectionService:GetTagged('Owl') do
				if v:GetAttribute('Target') == plr.Player.UserId and v:GetAttribute('Status') == 2 then
					playerGravity = 0
				end
			end
		end
	
		local pearl = projType == 'telepearl'
		local targetVelocity = pearl and Vector3.zero or plr.RootPart.AssemblyLinearVelocity
		local targetAirborne = not pearl and plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
		local calc, _, travelTime = prediction.SolveTrajectory(origin, speed * Prediction.Value, gravity, targetpos, targetVelocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck, targetAirborne, plr.RootPart.Position, plr.RootPart, nil, true)
		if not calc or not travelTime or travelTime > (meta.lifetimeSec or 3) then return end
	
		targetinfo.Targets[plr] = tick() + 1
		store.hitchance.SilentAim = {Value = getHitChance(plr, travelTime), Clock = tick()}
		-- Only the direction is redirected; the launch speed stays the one the shot actually has,
		-- so the server sees a normal-strength shot that happens to fly at the target.
		return CFrame.lookAt(origin, calc).LookVector * speed, velocityIndex
	end
	
	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if callback and not namecall then
				namecall = hookmetamethod(game, '__namecall', newcclosure(function(...)
					if SilentAim.Enabled and not checkcaller() and getnamecallmethod() == 'InvokeServer' and tostring(...) == 'ProjectileFire' then
						local self = ...
						local args = table.pack(select(2, ...))
						local success, newVelocity, velocityIndex = pcall(solveSilent, args)
						if success and typeof(newVelocity) == 'Vector3' and velocityIndex then
							args[velocityIndex] = newVelocity
						elseif not success and shared.VapeDeveloper and tick() > lastWarn then
							lastWarn = tick() + 5
							warn('[catvape] silentaim solve failed: '..tostring(newVelocity))
						end
						return self.InvokeServer(self, table.unpack(args, 1, args.n))
					end
					return namecall(...)
				end))
			end
		end,
		Tooltip = 'Redirects only the projectile values sent to the server, so enemies get hit while your shot flies exactly where you aimed on your own screen'
	})
	
	Targets = SilentAim:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic', 'Closest'}
	})
	local methods = {'Damage', 'Distance'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
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
		Function = function(callback)
			if Blacklist then
				Blacklist.Object.Visible = callback
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