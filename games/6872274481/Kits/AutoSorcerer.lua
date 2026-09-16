run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoSorcerer
	local Range
	local Delay
	local nextUse = 0

	AutoSorcerer = kits:CreateModule({
		Name = 'AutoSorcerer',
		Function = function(callback)
			if callback then
				nextUse = 0
				repeat
					if entitylib.isAlive and util.IsKit('sorcerer') and tick() >= nextUse and util.Ability.Ready('SORCERER_PROJECTILE_FIRE') then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
						if target then
							nextUse = tick() + Delay.Value
							util.Ability.Use('SORCERER_PROJECTILE_FIRE')
						end
					end
					task.wait(0.1)
				until not AutoSorcerer.Enabled
			end
		end,
		Tooltip = 'Fires the sorcerer projectile at the closest enemy in range'
	})
	Range = AutoSorcerer:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 40,
		Suffix = util.Studs
	})
	Delay = AutoSorcerer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.4,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)
