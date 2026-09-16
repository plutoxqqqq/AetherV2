run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoDinoTamer
	local Range
	local Delay
	local nextUse = 0

	AutoDinoTamer = kits:CreateModule({
		Name = 'AutoDinoTamer',
		Function = function(callback)
			if callback then
				nextUse = 0
				repeat
					if entitylib.isAlive and util.IsKit('dino_tamer') and tick() >= nextUse and util.Ability.Ready('dino_charge') then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
						if target then
							nextUse = tick() + Delay.Value
							util.Ability.Use('dino_charge')
						end
					end
					task.wait(0.1)
				until not AutoDinoTamer.Enabled
			end
		end,
		Tooltip = 'Charges at the closest enemy in range'
	})
	Range = AutoDinoTamer:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 80,
		Default = 30,
		Suffix = util.Studs
	})
	Delay = AutoDinoTamer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)
