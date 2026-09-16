run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoWarrior
	local Targets
	local Range
	local Amount

	AutoWarrior = kits:CreateModule({
		Name = 'AutoWarrior',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'warrior' and bedwars.AbilityController:canUseAbility('warrior_strike', {disableBlockedAbilityAlert = true}) then
						local found = #entitylib.AllPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})

						if found >= Amount.Value then
							bedwars.AbilityController:useAbility('warrior_strike')
						end
					end
					task.wait(0.1)
				until not AutoWarrior.Enabled
			end
		end,
		Tooltip = 'Automatically uses Warrior Strike once enough enemies are next to you'
	})

	Targets = AutoWarrior:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoWarrior:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 14,
		Suffix = util.Studs
	})
	Amount = AutoWarrior:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before striking'
	})
end)
