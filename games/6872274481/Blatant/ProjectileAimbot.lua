run(function()
	-- Declared before the module table rather than with `local ProjectileAimbot = CreateModule(...)`:
	-- a local declared by that assignment is not in scope inside the table it initialises, so the
	-- `ProjectileAimbot:Clean(...)` call further down would look up a global that never exists and
	-- throw every time the module was switched on.
	local ProjectileAimbot
	local Blacklist
	local TargetPart
	local Targets
	local Sort
	local FOV
	local Horizontal
	local Vertical
	local AutoCharge
	local Aim = {}
	local OtherProjectiles
	local MaxAccuracy
	local maxAccuracyScale = 1
	local maxAccuracyGeneration = 0
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
	-- The arc test casts through everything except the shooter, the camera and every entity, so a
	-- blocked shot is rejected before the launch is committed rather than after.
	local arcCheck = RaycastParams.new()
	arcCheck.FilterType = Enum.RaycastFilterType.Exclude
	local arcFilter = {}
	local launchHook

	local function resolveProjectileAimbotPart(ent, requested, projectileType)
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
			for _, part in available do if part and part ~= root then table.insert(filtered, part) end end
			return #filtered > 0 and filtered[math.random(1, #filtered)] or root
		end
		return root
	end

	-- The target's own gravity is what its body will actually fall under, so the lead has to use
	-- it rather than workspace gravity: balloons, the 8200754399 slow-fall accessory and being
	-- an owl ability target all change it.
	local function targetGravityOf(ent)
		local gravity = workspace.Gravity
		local character = ent.Character
		local balloons = character and character:GetAttribute('InflatedBalloons')
		if type(balloons) == 'number' and balloons > 0 then
			gravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if ent.RootPart and ent.RootPart:FindFirstChild('rbxassetid://8200754399') then gravity = 6 end
		if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
			for _, owl in collectionService:GetTagged('Owl') do
				if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
					gravity = 0
					break
				end
			end
		end
		return gravity
	end

	local function arcIsClear(origin, velocity, gravity, travelTime)
		table.clear(arcFilter)
		table.insert(arcFilter, gameCamera)
		table.insert(arcFilter, lplr.Character)
		for _, ent in entitylib.List do
			if ent.Character then table.insert(arcFilter, ent.Character) end
		end
		arcCheck.FilterDescendantsInstances = arcFilter
		return prediction.IsTrajectoryClear(origin, velocity, gravity, travelTime, arcCheck) and true or false
	end

	local function solveAimbotLaunch(launch, projmeta, projectileType)
		local origin = launch.positionFrom
		local metaOk, meta = pcall(projmeta.getProjectileMeta, projmeta)
		meta = metaOk and meta or bedwars.ProjectileMeta[projectileType]
		if type(meta) ~= 'table' then return end
		local gravity = (tonumber(meta.gravitationalAcceleration) or 196.2) * (tonumber(projmeta.gravityMultiplier) or 1)
		local fullSpeed = tonumber(meta.launchVelocity) or launch.initialVelocity.Magnitude
		if not fullSpeed or fullSpeed <= 0 then return end
		-- Max accuracy models the shot at the speed the server will see it travel, which is what
		-- corrects for ping, so it scales the solve rather than the fired velocity.
		local solveSpeed = fullSpeed * maxAccuracyScale
		-- Auto Charge (or Aim change off) means the projectile leaves at its full launch speed;
		-- otherwise it keeps the draw strength it was fired with.
		local shootSpeed = (AutoCharge.Enabled or not Aim.Enabled) and fullSpeed or launch.initialVelocity.Magnitude

		local function valuesFor(ent)
			local aimPart = resolveProjectileAimbotPart(ent, TargetPart.Value, projectileType)
			if not aimPart or not aimPart.Parent then return end
			local targetPosition = aimPart.Position
			local targetVelocity = projectileType == 'telepearl' and Vector3.zero or aimPart.AssemblyLinearVelocity
			local playerGravity = targetGravityOf(ent)
			local root = ent.RootPart
			if not root then return end
			local airborne = (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air)
				or math.abs(root.AssemblyLinearVelocity.Y) > 0.01

			-- prediction.SolveTrajectory is the shared solve the rest of the pack aims with, so the
			-- lead here matches what the tracers and the hit chance display.
			local function solve(position)
				local ok, aimPoint, _, travelTime = pcall(
					prediction.SolveTrajectory,
					origin, solveSpeed, gravity, position, targetVelocity, playerGravity,
					ent.HipHeight, ent.Jumping and 42.6 or nil, store.airRay, airborne,
					root.Position, root, nil, true
				)
				if ok and aimPoint and travelTime then return aimPoint, travelTime end
			end

			local aimPoint, travelTime = solve(targetPosition)
			if not aimPoint then return end

			-- Horizontal and Vertical prediction scale the lead itself: 1 leaves the solve alone,
			-- above 1 aims further ahead of a moving or rising target.
			if Horizontal.Value ~= 1 or Vertical.Value ~= 1 then
				local rise = (targetVelocity.Y * travelTime) - (playerGravity * travelTime * travelTime * 0.5)
				local lead = Vector3.new(
					targetVelocity.X * travelTime * (Horizontal.Value - 1),
					rise * (Vertical.Value - 1),
					targetVelocity.Z * travelTime * (Horizontal.Value - 1)
				)
				local adjusted, adjustedTime = solve(targetPosition + lead)
				if adjusted then aimPoint, travelTime = adjusted, adjustedTime or travelTime end
			end

			local direction = CFrame.new(origin, aimPoint).LookVector
			local velocity = direction * solveSpeed
			if Targets.Walls.Enabled and travelTime and not arcIsClear(origin, velocity, gravity, travelTime) then
				return
			end
			return {Velocity = direction * shootSpeed, Time = travelTime, Player = ent}
		end

		-- Walk the candidates nearest first and take the first one whose arc is clear, so a
		-- blocked target does not stop the shot being aimed at all.
		local best
		for _, ent in entitylib.AllPosition({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority and Targets.Priority.Value,
			Origin = origin,
			MouseOrigin = gameCamera.ViewportSize / 2,
			Sort = sortmethods[Sort.Value],
			Limit = 10
		}) do
			local ok, values = pcall(valuesFor, ent)
			if ok and values then
				best = values
				break
			end
		end
		return best
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				if vape.Modules.SilentAim and vape.Modules.SilentAim.Enabled then vape.Modules.SilentAim:Toggle() end
				-- The hook receives (self, launchData, ...) - the draw request the game is about to turn
				-- into a launch. Auto Charge belongs here, before the game reads the charge, because the
				-- velocity it computes comes from the charge values; writing them onto the launch table
				-- afterwards only confused the local projectile and the aim beam.
				launchHook = bedwars.ProjectileLaunchHook:Add('ProjectileAimbot', 12, function(nextLaunch, self, launchData, ...)
					local projmeta = launchData
					if AutoCharge.Enabled and type(projmeta) == 'table' then
						local chargeMeta = bedwars.ProjectileMeta[projmeta.projectile]
						if chargeMeta and tonumber(chargeMeta.predictionLifetimeSec) then
							projmeta.drawDurationSeconds = math.max(tonumber(projmeta.drawDurationSeconds) or 0, chargeMeta.predictionLifetimeSec)
							projmeta.velocityMultiplier = math.max(tonumber(projmeta.velocityMultiplier) or 0, 1)
						end
					end

					local launch = nextLaunch(self, launchData, ...)
					if type(launch) ~= 'table' or typeof(launch.positionFrom) ~= 'Vector3'
						or typeof(launch.initialVelocity) ~= 'Vector3' or not projmeta then return launch end
					local projectileType = tostring(projmeta.projectile or '')
					if projectileType == '' or ((not OtherProjectiles.Enabled) and not projectileType:find('arrow')) then return launch end
					local blacklistName = (projectileType == 'glue_trap' or projectileType == 'glue_projectile') and 'gloop' or projectileType
					if table.find(Blacklist.ListEnabled or {}, blacklistName) then return launch end

					-- This runs inside the game's own launch path, so anything that throws here is a bow
					-- that never fires and an aim line that never draws. The solve is therefore optional
					-- work: a failure has to leave the launch exactly as the game built it.
					local ok, solved = pcall(solveAimbotLaunch, launch, projmeta, projectileType)
					if not ok then
						if shared.VapeDeveloper then
							warn('[catvape] projectile aimbot solve failed: ' .. tostring(solved))
						end
						return launch
					end
					if type(solved) ~= 'table' then return launch end

					-- Only the velocity is redirected. deltaT is the beam's simulation step and
					-- drawDurationSeconds is the charge the shot is being fired with: rewriting either of
					-- those is what removed the aim line and stopped the projectile from firing at all.
					launch.initialVelocity = solved.Velocity
					store.hitchance.ProjectileAimbot = {
						Value = getHitChance(solved.Player, solved.Time),
						Clock = tick()
					}
					targetinfo.Targets[solved.Player] = tick() + 1
					return launch
				end)
				ProjectileAimbot:Clean(function()
					if launchHook then launchHook(); launchHook = nil end
				end)
			elseif launchHook then
				launchHook()
				launchHook = nil
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Distance', 'Damage'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = ProjectileAimbot:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance'
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic'}
	})
	MaxAccuracy = ProjectileAimbot:CreateToggle({
		Name = 'Max accuracy',
		Tooltip = 'Changes prediction based on ping to give you the most accurate shots',
		Function = function(callback)
			maxAccuracyGeneration += 1
			local generation = maxAccuracyGeneration
			if callback then
				MaxAccuracy:Clean(task.spawn(function()
					repeat
						maxAccuracyScale = math.clamp(1 - lplr:GetNetworkPing(), 0.1, 1)
						task.wait(1)
					until not MaxAccuracy.Enabled or generation ~= maxAccuracyGeneration
				end))
			else
				maxAccuracyScale = 1
			end
		end
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	Horizontal = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'Scales how far ahead of the target you aim sideways'
	})
	Vertical = ProjectileAimbot:CreateSlider({
		Name = 'Vertical prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'Scales how far ahead of the target you aim while it rises or falls'
	})
	AutoCharge = ProjectileAimbot:CreateToggle({
		Name = 'Auto Charge',
		Function = function(callback)
			if Aim.Object then
				Aim.Object.Visible = callback
			end
		end,
		Default = true,
		Tooltip = 'Fully charges your bow, Allowing your projectile to deal more damage'
	})
	Aim = ProjectileAimbot:CreateToggle({
		Name = 'Aim change',
		Default = true,
		Darker = true,
		Tooltip = 'Changes your trajectory to match charge percentage'
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true
	})
	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Default = {'telepearl'}
	})
end)
