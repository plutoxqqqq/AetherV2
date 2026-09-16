run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoCat
	local Range
	local Delay
	local nextUse = 0

	AutoCat = kits:CreateModule({
		Name = 'AutoCat',
		Function = function(callback)
			if callback then
				nextUse = 0
				repeat
					if entitylib.isAlive and util.IsKit('cat') and tick() >= nextUse and util.Ability.Ready('CAT_POUNCE') then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
						if target then
							nextUse = tick() + Delay.Value
							util.Ability.Use('CAT_POUNCE')
						end
					end
					task.wait(0.1)
				until not AutoCat.Enabled
			end
		end,
		Tooltip = 'Pounces at the closest enemy in range'
	})
	Range = AutoCat:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 20,
		Suffix = util.Studs
	})
	Delay = AutoCat:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)
