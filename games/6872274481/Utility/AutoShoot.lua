run(function()
	local AutoShoot
	local Targets
	local Check
	local Animation
	local Projectiles
	local UseSophia
	local UseWhim
	local UseNazar
	local FireRate
	local SwitchDelay
	
	local FireDelays = {}
	
	local function getEntity()
		local selfpos = entitylib.character.RootPart.Position
		local plrs = entitylib.AllPosition({
			Origin = selfpos,
			Part = 'RootPart',
			Range = 22,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		})
		if #plrs > 0 then
			for _, v in plrs do
				local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
				local delta = (v.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)
				local angle = localfacing.Magnitude > 0 and delta.Magnitude > 0 and math.acos(math.clamp(localfacing.Unit:Dot(delta.Unit), -1, 1)) or 0
				if angle > (math.rad(120) / 2) then continue end
				return v
			end
		end
		return nil
	end
	
	AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 then
						local oldtool, oldhotbar = store.hand.tool, store.inventory.hotbarSlot
						for _, v in getProjectiles(Projectiles.ListEnabled, UseSophia.Enabled, UseWhim.Enabled, UseNazar.Enabled) do
							local item, ammo, projectile, itemMeta = unpack(v)
							if (FireDelays[item.itemType] or 0) < tick() then
								local ent = getEntity()
								if not Check.Enabled or ent then
									local hotbar = getHotbar(item.tool)
									switchItem(item.tool)
									if hotbar then
										hotbarSwitch(hotbar)
									end
	
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local origin = entitylib.character.RootPart.Position
									local calc = ent and prediction.SolveTrajectory(origin, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, nil, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true) or (not ent and (origin + gameCamera.CFrame.LookVector * 100))
									if calc then
										local shootPosition = (CFrame.new(origin, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
										local aim = ent and prediction.SolveTrajectory(shootPosition, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, nil, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true) or calc
										if Animation.Enabled then
											bedwars.ProjectileController:launchProjectileWithValues({
												initialVelocity = CFrame.lookAt(shootPosition, aim).LookVector * projSpeed,
												positionFrom = shootPosition,
												drawDurationSeconds = 1
											}, item.tool, itemMeta, ammo, nil, projectile):await()
										else
											local dir, id = CFrame.lookAt(shootPosition, aim).LookVector, httpService:GenerateGUID(true)
											bedwars.Handler:Get('ProjectileFire'):Fire('CallServerAsync',
												item.tool,
												ammo,
												projectile,
												shootPosition,
												origin,
												dir * projSpeed,
												id,
												{
													drawDurationSeconds = 1,
													shotId = httpService:GenerateGUID(false),
												},
												workspace:GetServerTimeNow() - 0.045
											):andThen(function(res)
												if res then
													res.Parent = replicatedStorage
												end
											end)
										end
										if ent then
											prediction.trackShot(ent.RootPart)
										end
										FireDelays[item.itemType] = tick() + (itemMeta.fireDelaySec + FireRate:GetRandomValue())
										task.wait(SwitchDelay.Value)
									end
								end
							end
						end
						if oldtool then
							switchItem(oldtool)
						end
						hotbarSwitch(oldhotbar)
					end
					task.wait(0.1)
				until not AutoShoot.Enabled
			end
		end,
		Tooltip = 'Automatically crossbow macro\'s'
	})
	
	Targets = AutoShoot:CreateTargets({Players = true})
	Check = AutoShoot:CreateToggle({
		Name = 'Target check',
		Function = function(callback)
			if Targets.Object then
				Targets.Object.Visible = callback
			end
		end,
		Default = true
	})
	Animation = AutoShoot:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the shot animation and arrow'
	})
	Projectiles = AutoShoot:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	UseSophia = AutoShoot:CreateToggle({
		Name = 'Use sophia',
		Tooltip = 'Also shoots sophia\'s frost staff, swapping it out of mist mode on its own'
	})
	UseWhim = AutoShoot:CreateToggle({
		Name = 'Use whim',
		Tooltip = 'Also casts whim\'s magic book, follows whatever element you have cycled'
	})
	UseNazar = AutoShoot:CreateToggle({
		Name = 'Use nazar',
		Tooltip = 'Also shoots nazar\'s life bow, crossbow and headhunter'
	})
	FireRate = AutoShoot:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoShoot:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)
