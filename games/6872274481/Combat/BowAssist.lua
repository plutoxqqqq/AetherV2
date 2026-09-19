run(function()
	local BowAssist
	local Targets
	local Sort
	local AimPart
	local FOV
	local AimSpeed
	local Smoothness
	local Distance
	local Shake
	local Clear
	local Blacklist
	
	local drawStart, oldStart, oldStop = 0
	local rng = Random.new()
	
	local arcCheck = RaycastParams.new()
	arcCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	BowAssist = vape.Categories.Combat:CreateModule({
		Name = 'BowAssist',
		Function = function(callback)
			if callback then
				oldStart = bedwars.DefaultProjectileSourceController.onStartCharging
				bedwars.DefaultProjectileSourceController.onStartCharging = function(self, ...)
					drawStart = tick()
					return oldStart(self, ...)
				end
	
				oldStop = bedwars.DefaultProjectileSourceController.onStopCharging
				bedwars.DefaultProjectileSourceController.onStopCharging = function(self, ...)
					drawStart = 0
					return oldStop(self, ...)
				end
	
				BowAssist:Clean(runService.PostSimulation:Connect(function(dt)
					if drawStart == 0 or not entitylib.isAlive then return end
	
					local meta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
					local source = meta and meta.projectileSource
					if not source or not source.projectileType then return end
	
					local ammo = store.hand.tool.Name
					if source.ammoItemTypes and #source.ammoItemTypes > 0 then
						ammo = nil
						for _, v in store.inventory.inventory.items do
							if table.find(source.ammoItemTypes, v.itemType) then
								ammo = v.itemType
								break
							end
						end
					end
					if not ammo then return end
	
					local projType = source.projectileType(ammo)
					if table.find(Blacklist.ListEnabled or {}, ((projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType)) then return end
	
					local projmeta = bedwars.ProjectileMeta[projType]
					if not projmeta or type(projmeta.launchVelocity) ~= 'number' then return end
	
					local scalar = source.minStrengthScalar or 1
					local ratio = source.maxStrengthChargeSec and math.clamp((tick() - drawStart) / source.maxStrengthChargeSec, 0, 1) or 1
					local projSpeed = projmeta.launchVelocity * (scalar + (1 - scalar) * ratio)
	
					local localPosition = entitylib.character.RootPart.Position
					local ent = entitylib.EntityMouse({
						Range = FOV.Value,
						Part = 'RootPart',
						Wallcheck = Targets.Walls.Enabled,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value,
						Origin = localPosition,
						Sort = sortmethods[Sort.Value]
					})
					if not ent or (localPosition - ent.RootPart.Position).Magnitude > Distance.Value then return end
	
					local targetPosition = ent[AimPart.Value].Position
					local shootPosition = (CFrame.new(localPosition, targetPosition) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
					local gravity = projmeta.gravitationalAcceleration or 196.2
					local calc, _, travelTime = prediction.SolveTrajectory(shootPosition, projSpeed, gravity, targetPosition, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, nil, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true)
					if not calc then return end
	
					if Clear.Enabled and travelTime then
						local ignorelist = {gameCamera, lplr.Character}
						for _, v in entitylib.List do
							if v.Character then
								table.insert(ignorelist, v.Character)
							end
						end
						arcCheck.FilterDescendantsInstances = ignorelist
						if not prediction.IsTrajectoryClear(shootPosition, calc - shootPosition, gravity, travelTime, arcCheck) then return end
					end
	
					targetinfo.Targets[ent] = tick() + 1
					local jitter = Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * dt, (rng:NextNumber() - 0.5) * Shake.Value * dt, (rng:NextNumber() - 0.5) * Shake.Value * dt)
					local speed = math.clamp((AimSpeed.Value / Smoothness.Value) * dt, 0, 1)
					gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.Position, calc + jitter), speed)
					if entitylib.character.Head.LocalTransparencyModifier ~= 1 then
						-- Third person: the view sits behind the shoulder and the shot follows the cursor, so ease the
						-- cursor onto the drop as well instead of only turning the camera.
						local viewport = gameCamera:WorldToViewportPoint(calc)
						local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * speed
						mousemoverel(pos.X, pos.Y)
					end
				end))
			else
				drawStart = 0
				bedwars.DefaultProjectileSourceController.onStartCharging = oldStart
				bedwars.DefaultProjectileSourceController.onStopCharging = oldStop
			end
		end,
		Tooltip = 'Eases your camera onto the arrow drop while you draw a bow'
	})
	
	Targets = BowAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = BowAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance'
	})
	AimPart = BowAssist:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = BowAssist:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 220,
		Tooltip = 'How far from your crosshair a target can sit before it gets ignored'
	})
	Distance = BowAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 300,
		Default = 200,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AimSpeed = BowAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 5
	})
	Smoothness = BowAssist:CreateSlider({
		Name = 'Smoothness',
		Min = 1,
		Max = 20,
		Default = 2,
		Decimal = 10,
		Tooltip = 'Divides the aim speed to soften the pull, 1 leaves it unchanged'
	})
	Shake = BowAssist:CreateSlider({
		Name = 'Shake',
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Adds random jitter so the pull does not read as a straight line'
	})
	Clear = BowAssist:CreateToggle({
		Name = 'Clear shot only',
		Default = true,
		Tooltip = 'Stops assisting when a block is in the way of the arc'
	})
	Blacklist = BowAssist:CreateTextList({
		Name = 'Blacklist',
		Default = {'gloop', 'telepearl'},
		Darker = true,
		Placeholder = 'projectile',
		Tooltip = 'Projectile types the assist leaves alone'
	})
end)
