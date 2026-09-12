run(function()
	local AutoMarrow
	local Mode
	local Targets
	local Range
	local Health

	AutoMarrow = kits:CreateModule({
		Name = 'AutoMarrow',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'skeleton' and bedwars.AbilityController:canUseAbility('skeleton_ability', {disableBlockedAbilityAlert = true}) then
						local humanoid = entitylib.character.Humanoid
						local low = humanoid.Health <= (humanoid.MaxHealth * (Health.Value / 100))
						local near = #entitylib.AllPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						}) > 0

						if (Mode.Value == 'Low Health' and low) or (Mode.Value == 'Enemy Near' and near) or (Mode.Value == 'Both' and (low or near)) then
							bedwars.AbilityController:useAbility('skeleton_ability')
						end
					end
					task.wait(0.1)
				until not AutoMarrow.Enabled
			end
		end,
		Tooltip = 'Automatically drops Toxic Escape clouds when you are in trouble'
	})

	Mode = AutoMarrow:CreateDropdown({
		Name = 'Mode',
		List = {'Both', 'Low Health', 'Enemy Near'},
		Default = 'Both'
	})
	Targets = AutoMarrow:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = AutoMarrow:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Health = AutoMarrow:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 45,
		Suffix = '%',
		Tooltip = 'Drops the clouds once you fall under this'
	})
end)
