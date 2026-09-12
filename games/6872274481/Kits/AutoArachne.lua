run(function()
	local AutoArachne
	local Targets
	local Range
	local Amount

	AutoArachne = kits:CreateModule({
		Name = 'AutoArachne',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'spider_queen' and bedwars.AbilityController:canUseAbility('spider_queen_summon_spiders', {disableBlockedAbilityAlert = true}) then
						local found = #entitylib.AllPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})

						if found >= Amount.Value then
							bedwars.AbilityController:useAbility('spider_queen_summon_spiders')
						end
					end
					task.wait(0.1)
				until not AutoArachne.Enabled
			end
		end,
		Tooltip = 'Automatically summons spiders once an enemy is nearby'
	})

	Targets = AutoArachne:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = AutoArachne:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Amount = AutoArachne:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before summoning'
	})
end)
