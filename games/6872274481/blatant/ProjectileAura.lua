run(function()
	local ProjectileAura
	local Targets
	local FireRate
	local Range
	local List
	local UseSophia
	local UseWhim
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	local projectileRemote
	local FireDelays = {}
	local generation = 0

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

	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			generation += 1
			if not callback then return end
			local token = generation
			repeat
				if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.3 and entitylib.isAlive then
					local ent = entitylib.EntityPosition({
						Part = 'RootPart',
						Range = Range.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled
					})
					local remote = ent and getProjectileRemote()
					if ent and ent.RootPart and remote then
						local rootPosition = entitylib.character.RootPart.Position
						for _, data in getProjectiles(List.ListEnabled, UseSophia.Enabled, UseWhim.Enabled) do
							if token ~= generation or not ProjectileAura.Enabled then break end
							local item, ammo, projectile, source, meta = unpack(data)
							local now = workspace:GetServerTimeNow()
							if item.tool and item.tool.Parent and (FireDelays[item.itemType] or 0) <= now then
								rayCheck.FilterDescendantsInstances = {lplr.Character, ent.Character, gameCamera}
								local speed = meta.launchVelocity
								local first = solveBedwarsProjectile(rootPosition, speed, meta.gravitationalAcceleration, ent, ent.RootPart.Position, {
									RaycastParams = rayCheck,
									Lifetime = meta.lifetimeSec or 3
								})
								local shootPosition = first and projectileLaunchOrigin(rootPosition, first.Velocity)
								local solution = shootPosition and solveBedwarsProjectile(shootPosition, speed, meta.gravitationalAcceleration, ent, ent.RootPart.Position, {
									RaycastParams = rayCheck,
									Lifetime = meta.lifetimeSec or 3
								})
								if solution then
									switchItem(item.tool, 0)
									FireDelays[item.itemType] = now + (source.fireDelaySec or 0) + FireRate:GetRandomValue()
									task.spawn(function()
										if token ~= generation or not ProjectileAura.Enabled or not item.tool.Parent then return end
										local velocity = solution.Velocity
										local id = httpService:GenerateGUID(true)
										local draw = {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}
										pcall(bedwars.ProjectileController.createLocalProjectile, bedwars.ProjectileController, meta, ammo, projectile, shootPosition, id, velocity, draw)
										local ok, result = pcall(remote.InvokeServer, remote, item.tool, ammo, projectile, shootPosition, rootPosition, velocity, id, draw, workspace:GetServerTimeNow() - 0.045)
										if token ~= generation or not ProjectileAura.Enabled then return end
										if ok and result ~= false then
											store.lastProjectileFire = workspace:GetServerTimeNow()
											targetinfo.Targets[ent] = tick() + 1
											prediction.trackShot(ent.RootPart)
											local sounds = source.launchSound
											local sound = type(sounds) == 'table' and #sounds > 0 and sounds[math.random(1, #sounds)] or nil
											if sound then pcall(bedwars.SoundManager.playSound, bedwars.SoundManager, sound) end
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
		Tooltip = 'Shoots people around you'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
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