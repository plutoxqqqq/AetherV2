run(function()
	local AutoShoot
	local Targets
	local Check
	local Projectiles
	local UseSophia
	local UseWhim
	local FireRate
	local SwitchDelay

	local fireDelays = {}
	local generation = 0
	local firing
	local projectileRemote
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude

	local function getTarget(origin)
		local facing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		for _, target in entitylib.AllPosition({
			Origin = origin,
			Part = 'RootPart',
			Range = 22,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10,
			Sort = sortmethods.Distance
		}) do
			local delta = (target.RootPart.Position - origin) * Vector3.new(1, 0, 1)
			if facing.Magnitude == 0 or delta.Magnitude == 0 or facing.Unit:Dot(delta.Unit) >= math.cos(math.rad(60)) then return target end
		end
	end

	local function getDirection(origin, target, projectileMeta)
		local speed = projectileMeta.launchVelocity
		if type(speed) ~= 'number' or speed <= 0 then return end
		if not target then return gameCamera.CFrame.LookVector * speed end
		rayCheck.FilterDescendantsInstances = {lplr.Character, target.Character, gameCamera}
		local gravity = projectileMeta.gravitationalAcceleration or 196.2
		local solution = solveBedwarsProjectile(origin, speed, gravity, target, target.RootPart.Position, {
			RaycastParams = rayCheck,
			Lifetime = projectileMeta.lifetimeSec or 3
		})
		return solution and solution.Velocity or nil
	end

	local function fireOne(data, target, token)
		local item, ammo, projectile, source, projectileMeta = table.unpack(data)
		if token ~= generation or not AutoShoot.Enabled or not entitylib.isAlive or not item.tool or not item.tool.Parent then return false end
		local now = workspace:GetServerTimeNow()
		if (fireDelays[item.itemType] or 0) > now then return false end
		local slot = getHotbar(item.tool)
		if not slot or not hotbarSwitch(slot) then return false end
		task.wait(math.clamp(lplr:GetNetworkPing(), 0, 0.2))
		if token ~= generation or not AutoShoot.Enabled or not entitylib.isAlive then return false end

		local root = entitylib.character.RootPart
		local rootPosition = root.Position
		local velocity = getDirection(rootPosition, target, projectileMeta)
		if not velocity then return false end
		local shootPosition = projectileLaunchOrigin(rootPosition, velocity)
		
		
		velocity = getDirection(shootPosition, target, projectileMeta) or velocity
		local id = httpService:GenerateGUID(true)
		local draw = {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}
		local created = pcall(bedwars.ProjectileController.createLocalProjectile, bedwars.ProjectileController,
			projectileMeta, ammo, projectile, shootPosition, id, velocity, draw)
		if not created then return false end

		local called, result = pcall(projectileRemote.InvokeServer, projectileRemote,
			item.tool, ammo, projectile, shootPosition, rootPosition, velocity, id, draw,
			workspace:GetServerTimeNow() - 0.045)
		fireDelays[item.itemType] = workspace:GetServerTimeNow() + (source.fireDelaySec or 0) + FireRate:GetRandomValue()
		if not called then return false end
		store.lastProjectileFire = workspace:GetServerTimeNow()
		if target then
			targetinfo.Targets[target] = tick() + 1
			prediction.trackShot(target.RootPart)
		end
		local sounds = source.launchSound
		local sound = type(sounds) == 'table' and #sounds > 0 and sounds[math.random(1, #sounds)] or nil
		if sound then pcall(bedwars.SoundManager.playSound, bedwars.SoundManager, sound) end
		return result ~= false
	end

	local function shoot(token)
		if firing or token ~= generation or not entitylib.isAlive then return end
		firing = token
		local originalSlot = store.hand.tool and getHotbar(store.hand.tool) or nil
		local origin = entitylib.character.RootPart.Position
		local target = getTarget(origin)
		if not Check.Enabled or target then
			for _, data in getProjectiles(Projectiles.ListEnabled, UseSophia.Enabled, UseWhim.Enabled) do
				if token ~= generation or not AutoShoot.Enabled then break end
				local ok, fired = pcall(fireOne, data, target, token)
				if ok and fired then task.wait(SwitchDelay.Value) end
			end
		end
		if token == generation and originalSlot ~= nil then hotbarSwitch(originalSlot) end
		if firing == token then firing = nil end
	end

	AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(enabled)
			generation += 1
			firing = nil
			if not enabled then return end
			local token = generation
			local ok, remote = pcall(function() return bedwars.Client:Get(remotes.FireProjectile).instance end)
			if not ok or not remote or type(remote.InvokeServer) ~= 'function' then
				notif('AutoShoot', 'The projectile remote is unavailable.', 5, 'warning')
				AutoShoot:Toggle()
				return
			end
			projectileRemote = remote
			local lastSwing = bedwars.SwordController.lastSwing or 0
			AutoShoot:Clean(task.spawn(function()
				while AutoShoot.Enabled and token == generation do
					local swing = bedwars.SwordController.lastSwing or 0
					if swing > lastSwing and tick() - swing <= 0.25 then
						lastSwing = swing
						task.spawn(shoot, token)
					else
						lastSwing = math.max(lastSwing, swing)
					end
					task.wait(0.03)
				end
			end))
		end,
		Tooltip = 'Fires compatible projectiles once after each manual sword swing'
	})
	Targets = AutoShoot:CreateTargets({Players = true})
	Check = AutoShoot:CreateToggle({
		Name = 'Target check',
		Default = true,
		Function = function(callback)
			if Targets.Object then Targets.Object.Visible = callback end
		end
	})
	Projectiles = AutoShoot:CreateTextList({Name = 'Projectiles', Default = {'arrow', 'snowball'}})
	UseSophia = AutoShoot:CreateToggle({Name = 'Use sophia', Tooltip = 'Also shoots compatible Sophia frost projectiles'})
	UseWhim = AutoShoot:CreateToggle({Name = 'Use whim', Tooltip = 'Also shoots compatible Whim book projectiles'})
	FireRate = AutoShoot:CreateTwoSlider({Name = 'Fire Rate', Min = 0, Max = 1, DefaultMin = 0.05, DefaultMax = 0.12, Decimal = 100})
	SwitchDelay = AutoShoot:CreateSlider({Name = 'Switch Delay', Min = 0, Max = 1, Decimal = 100, Suffix = 'seconds', Default = 0.02})
end)
