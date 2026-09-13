run(function()
	local AutoTrixie
	local Targets
	local Warp
	local WarpRange
	local Rewind
	local Health
	local nextAbility = 0

	AutoTrixie = kits:CreateModule({
		Name = 'AutoTrixie',
		Function = function(callback)
			if callback then
				nextAbility = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'void_walker' and tick() >= nextAbility then
						local humanoid = entitylib.character.Humanoid

						if Rewind.Enabled and humanoid.Health <= (humanoid.MaxHealth * (Health.Value / 100)) and bedwars.AbilityController:canUseAbility('void_walker_rewind', {disableBlockedAbilityAlert = true}) then
							nextAbility = tick() + 1
							bedwars.AbilityController:useAbility('void_walker_rewind')
						elseif Warp.Enabled and bedwars.AbilityController:canUseAbility('void_walker_warp', {disableBlockedAbilityAlert = true}) then
							local target = entitylib.EntityPosition({
								Range = WarpRange.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Wallcheck = Targets.Walls.Enabled,
								Sort = sortmethods.Distance
							})

							if target then
								local root = entitylib.character.RootPart
								root.CFrame = CFrame.lookAlong(root.Position, (target.RootPart.Position - root.Position) * Vector3.new(1, 0, 1))
								nextAbility = tick() + 1
								bedwars.AbilityController:useAbility('void_walker_warp')
							end
						end
					end
					task.wait(0.1)
				until not AutoTrixie.Enabled
			end
		end,
		Tooltip = 'Warps you onto whoever you are chasing and rifts you back out when it goes wrong'
	})

	Targets = AutoTrixie:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Warp = AutoTrixie:CreateToggle({
		Name = 'Warp to target',
		Default = true,
		Function = function(callback)
			WarpRange.Object.Visible = callback
		end,
		Tooltip = 'Turns you at the closest enemy before warping so the portal lands on them'
	})
	WarpRange = AutoTrixie:CreateSlider({
		Name = 'Warp range',
		Min = 5,
		Max = 80,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Rewind = AutoTrixie:CreateToggle({
		Name = 'Rewind on low health',
		Default = true,
		Function = function(callback)
			Health.Object.Visible = callback
		end
	})
	Health = AutoTrixie:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 40,
		Suffix = '%'
	})
end)
