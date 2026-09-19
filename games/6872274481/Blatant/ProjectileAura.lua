run(function()
	local ProjectileAura
	local Targets
	local FireRate
	local Range
	local Part
	local List
	local UseSophia
	local UseWhim
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	local projectileRemote
	local FireDelays = {}
	local generation = 0

	local function resolveProjectileAuraPart(ent, requested, projectileType)
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

	local function getProjectileRemote()
		if projectileRemote and type(projectileRemote.InvokeServer) == 'function' then return projectileRemote end
		local ok, remote = pcall(function()
			local handler = bedwars.Handler:Get('ProjectileFire')
			return handler and handler.Remote and handler.Remote.instance
		end)
		if not ok or not remote then
			ok, remote = pcall(function() return bedwars.Client:Get(remotes.FireProjectile).instance end)
		end
		if ok and remote and type(remote.InvokeServer) == 'function' then projectileRemote = remote end
		return projectileRemote
	end

	-- Plays the shot the same way the game does for whatever is in hand, so the viewmodel, the
	-- third person animation and the launch sound all happen on the frame the projectile leaves.
	local function playShot(item, meta, ammo, projectile, shootPosition, velocity)
		local toolName = tostring(item.tool and item.tool.Name or '')
		local holdingCrossbow = toolName:find('crossbow', 1, true) ~= nil
		local holdingBow = toolName:find('bow', 1, true) ~= nil

		if holdingCrossbow then
			pcall(bedwars.ViewmodelController.playAnimation, bedwars.ViewmodelController, bedwars.AnimationType.FP_CROSSBOW_FIRE)
			pcall(bedwars.GameAnimationUtil.playAnimation, lplr, bedwars.AnimationType.CROSSBOW_FIRE)
		elseif holdingBow then
			pcall(bedwars.ViewmodelController.playAnimation, bedwars.ViewmodelController, bedwars.AnimationType.FP_BOW_FIRE or bedwars.AnimationType.FP_CROSSBOW_FIRE)
			pcall(bedwars.GameAnimationUtil.playAnimation, lplr, bedwars.AnimationType.BOW_FIRE)
		else
			local shootAnim = meta and meta.thirdPerson and meta.thirdPerson.shootAnimation
			if shootAnim then
				pcall(bedwars.GameAnimationUtil.playAnimation, lplr, shootAnim)
			end
		end

		local id = httpService:GenerateGUID(true)
		local draw = {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}
		pcall(bedwars.ProjectileController.createLocalProjectile, bedwars.ProjectileController, meta, ammo, projectile, shootPosition, id, velocity, draw)

		local remote = getProjectileRemote()
		if not remote then return false end
		local ok, result = pcall(remote.InvokeServer, remote, item.tool, ammo, projectile, shootPosition, entitylib.character.RootPart.Position, velocity, id, draw, workspace:GetServerTimeNow() - 0.045)
		if ok and result ~= false then
			local sounds = meta and meta.launchSound
			local sound = type(sounds) == 'table' and #sounds > 0 and sounds[math.random(1, #sounds)] or nil
			local manager = bedwars.SoundManager
			if sound and manager and type(manager.playSound) == 'function' then
				pcall(manager.playSound, manager, sound)
			end
			return true
		end
		return false
	end

	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			generation += 1
			if not callback then return end
			local token = generation
			repeat
				if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 and entitylib.isAlive then
					local ent = entitylib.EntityPosition({
						Part = 'RootPart',
						Range = Range.Value,
						Players = Targets.Players.Enabled,
						Priority = Targets.Priority and Targets.Priority.Value,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled
					})
					if ent and ent.RootPart then
						local rootPosition = entitylib.character.RootPart.Position
						for _, data in getProjectiles(List.ListEnabled, UseSophia.Enabled, UseWhim.Enabled) do
							if token ~= generation or not ProjectileAura.Enabled then break end
							local item, ammo, projectile, source, meta = unpack(data)
							local itemMeta = item.tool and bedwars.ItemMeta[item.tool.Name] or nil
							local now = workspace:GetServerTimeNow()
							local aimPart = resolveProjectileAuraPart(ent, Part.Value, projectile)
							if not aimPart then continue end
							if item.tool and item.tool.Parent and (FireDelays[item.itemType] or 0) <= now then
								rayCheck.FilterDescendantsInstances = {lplr.Character, ent.Character, gameCamera}
								local speed = meta.launchVelocity
								local first = solveBedwarsProjectile(rootPosition, speed, meta.gravitationalAcceleration, ent, aimPart.Position, {
									RaycastParams = rayCheck,
									Lifetime = meta.lifetimeSec or 3
								})
								local shootPosition = first and projectileLaunchOrigin(rootPosition, first.Velocity)
								local solution = shootPosition and solveBedwarsProjectile(shootPosition, speed, meta.gravitationalAcceleration, ent, aimPart.Position, {
									RaycastParams = rayCheck,
									Lifetime = meta.lifetimeSec or 3
								})
								if solution then
									store.hitchance.ProjectileAura = {Value = getHitChance(ent, (aimPart.Position - shootPosition).Magnitude / math.max(speed, 1)), Clock = tick()}
									switchItem(item.tool, 0)
									FireDelays[item.itemType] = now + ((itemMeta and tonumber(itemMeta.fireDelaySec)) or 0.5) + FireRate:GetRandomValue()
									task.spawn(function()
										if token ~= generation or not ProjectileAura.Enabled or not item.tool.Parent then return end
										if playShot(item, meta, ammo, projectile, shootPosition, solution.Velocity) then
											store.lastProjectileFire = workspace:GetServerTimeNow()
											targetinfo.Targets[ent] = tick() + 1
											prediction.trackShot(ent.RootPart)
										else
											FireDelays[item.itemType] = workspace:GetServerTimeNow()
										end
									end)
									task.wait(FireRate:GetRandomValue())
								end
							end
						end
					end
				end
				task.wait(0.03)
			until not ProjectileAura.Enabled or token ~= generation
		end,
		Tooltip = 'Shoots people around you with viewmodel animations'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	Part = ProjectileAura:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic'},
		Default = 'Dynamic',
		Tooltip = 'Dynamic uses Head for headhunters and the body/root for other projectiles'
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	UseSophia = ProjectileAura:CreateToggle({
		Name = 'Use sophia',
		Tooltip = 'Also shoots sophia\'s frost staff, swapping it out of mist mode on its own'
	})
	UseWhim = ProjectileAura:CreateToggle({
		Name = 'Use whim',
		Tooltip = 'Also casts whim\'s magic book, follows whatever element you have cycled'
	})
	FireRate = ProjectileAura:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
