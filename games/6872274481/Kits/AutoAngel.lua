run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoAngel
	local Range
	local Delay
	local nextUse = 0

	AutoAngel = kits:CreateModule({
		Name = 'AutoAngel',
		Function = function(callback)
			if callback then
				nextUse = 0
				repeat
					if entitylib.isAlive and util.IsKit('angel') and tick() >= nextUse and util.Ability.Ready('trinity_swap_form') then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
						if target then
							nextUse = tick() + Delay.Value
							util.Ability.Use('trinity_swap_form')
						end
					end
					task.wait(0.1)
				until not AutoAngel.Enabled
			end
		end,
		Tooltip = 'Swaps between the Trinity Light and Void forms while an enemy is close'
	})
	Range = AutoAngel:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = util.Studs
	})
	Delay = AutoAngel:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 3,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)
