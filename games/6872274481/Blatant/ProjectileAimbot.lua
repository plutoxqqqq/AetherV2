run(function()
	local Blacklist
	local TargetPart
	local Targets
	local Sort
	local FOV
	local AutoCharge
	local Aim = {}
	local OtherProjectiles
	local MaxAccuracy
	local maxAccuracyScale = 1
	local maxAccuracyGeneration = 0
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
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

	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
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

					local origin = launch.positionFrom
					-- This runs inside the game's own launch path, so anything that throws here is a bow
					-- that never fires and an aim line that never draws. The solve is therefore optional
					-- work: a failure has to leave the launch exactly as the game built it.
					local ok, solved = pcall(function()
						local plr = entitylib.EntityMouse({
							Part = 'RootPart',
							Range = FOV.Value,
							Players = Targets.Players.Enabled,
							Priority = Targets.Priority and Targets.Priority.Value,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Origin = origin,
							Sort = sortmethods[Sort.Value]
						})
						if not plr then return end
						local targetPart = resolveProjectileAimbotPart(plr, TargetPart.Value, projectileType)
						if not targetPart or not targetPart.Parent then return end
						local metaOk, meta = pcall(projmeta.getProjectileMeta, projmeta)
						meta = metaOk and meta or bedwars.ProjectileMeta[projectileType]
						if type(meta) ~= 'table' then return end
						local gravity = launch.gravitationalAcceleration
							or ((meta.gravitationalAcceleration or 196.2) * (projmeta.gravityMultiplier or 1))
						local fullSpeed = tonumber(meta.launchVelocity) or launch.initialVelocity.Magnitude
						local speed = (AutoCharge.Enabled or not Aim.Enabled) and fullSpeed or launch.initialVelocity.Magnitude
						-- The prediction window is the one the game itself solves the aim beam over, so the
						-- aimbot lead and the drawn line agree.
						local solution = solveBedwarsProjectile(origin, speed, gravity, plr, targetPart.Position, {
							Lifetime = meta.predictionLifetimeSec or meta.lifetimeSec or 3,
							PredictionScale = maxAccuracyScale,
							Stationary = projectileType == 'telepearl',
							RaycastParams = rayCheck
						})
						if not solution then return end
						return {Player = plr, Speed = speed, Solution = solution, TargetPosition = targetPart.Position}
					end)

					if not ok or type(solved) ~= 'table' then
						if not ok and shared.VapeDeveloper then
							warn('[catvape] projectile aimbot solve failed: ' .. tostring(solved))
						end
						return launch
					end

					-- Only the velocity is redirected. deltaT is the beam's simulation step and
					-- drawDurationSeconds is the charge the shot is being fired with: rewriting either of
					-- those is what removed the aim line and stopped the projectile from firing at all.
					launch.initialVelocity = solved.Solution.Velocity
					store.hitchance.ProjectileAimbot = {
						Value = getHitChance(solved.Player, (solved.TargetPosition - origin).Magnitude / math.max(solved.Speed, 1)),
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
