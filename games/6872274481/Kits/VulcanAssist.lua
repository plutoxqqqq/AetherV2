run(function()
	local VulcanAssist
	local Targets
	local Range
	local Sort

	VulcanAssist = kits:CreateModule({
		Name = 'VulcanAssist',
		Function = function(callback)
			if callback then
				repeat
					local turret = entitylib.isAlive and bedwars.Store:getState().Game.selectedTurret
					if turret then
						local origin = turret.Rotate.Position
						local ent = entitylib.EntityMouse({
							Range = Range.Value,
							Origin = origin,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						})
						local pos = ent and prediction.SolveTrajectory(origin, 320, 10, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, nil, store.airRay, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart)

						if pos then
							local delta = pos - origin
							bedwars.TurretCameraController.angleX = math.atan2(-delta.X, -delta.Z)
							bedwars.TurretCameraController.angleY = math.clamp(math.atan2(delta.Y, math.sqrt(delta.X ^ 2 + delta.Z ^ 2)), -0.8, 0.8)
						end
					end
					task.wait(0.1)
				until not VulcanAssist.Enabled
			end
		end,
		Tooltip = 'Automatically aims turret camera toward opponents'
	})
	Targets = VulcanAssist:CreateTargets({Walls = true, Players = true})

	local methods = {'Distance', 'Damage'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end

	Sort = VulcanAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = methods[1]
	})
	Range = VulcanAssist:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 500
	})
end)
