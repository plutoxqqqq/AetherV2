run(function()
	local AutoMartin
	local Targets
	local Range
	local Delay

	local cooldown = 0

	AutoMartin = kits:CreateModule({
		Name = 'AutoMartin',
		Function = function(callback)
			if callback then
				cooldown = 0

				repeat
					if tick() >= cooldown and entitylib.EntityPosition({
						Range = Range.Value,
						Part = 'RootPart',
						Wallcheck = Targets.Walls.Enabled,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Sort = sortmethods.Distance
					}) and bedwars.AbilityController:canUseAbility('cactus_fire', {disableBlockedAbilityAlert = true}) then
						cooldown = tick() + Delay.Value
						bedwars.AbilityController:useAbility('cactus_fire')
					end
					task.wait(0.1)
				until not AutoMartin.Enabled
			end
		end,
		Tooltip = 'Automatically uses "Wild growth" ability when within range.'
	})
	Targets = AutoMartin:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoMartin:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 0 and 'stud' or 'studs'
		end
	})
	Delay = AutoMartin:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 100,
		Suffix = 'seconds'
	})
end)
