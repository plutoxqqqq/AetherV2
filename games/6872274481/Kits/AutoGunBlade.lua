run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoGunBlade
	local Range
	local Delay
	local nextUse = 0

	AutoGunBlade = kits:CreateModule({
		Name = 'AutoGunBlade',
		Function = function(callback)
			if callback then
				nextUse = 0
				repeat
					if entitylib.isAlive and util.IsKit('gun_blade') and tick() >= nextUse and util.Ability.Ready('hand_gun') then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
						if target then
							nextUse = tick() + Delay.Value
							util.Ability.Use('hand_gun')
						end
					end
					task.wait(0.1)
				until not AutoGunBlade.Enabled
			end
		end,
		Tooltip = 'Fires the gun blade at the closest enemy in range'
	})
	Range = AutoGunBlade:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 40,
		Suffix = util.Studs
	})
	Delay = AutoGunBlade:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.3,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)
