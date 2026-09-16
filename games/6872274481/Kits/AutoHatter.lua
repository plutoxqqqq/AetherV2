run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoHatter
	local Health
	local Range
	local Delay
	local nextUse = 0

	AutoHatter = kits:CreateModule({
		Name = 'AutoHatter',
		Function = function(callback)
			if callback then
				nextUse = 0
				repeat
					if entitylib.isAlive and util.IsKit('hatter') and tick() >= nextUse and util.Ability.Ready('HATTER_TELEPORT') then
						local percent = util.Health.Percent()
						local threat = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true
						})
						if threat and percent and percent <= Health.Value then
							nextUse = tick() + Delay.Value
							util.Ability.Use('HATTER_TELEPORT')
						end
					end
					task.wait(0.1)
				until not AutoHatter.Enabled
			end
		end,
		Tooltip = 'Teleports away through the hat when a nearby enemy has you low'
	})
	Health = AutoHatter:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 35,
		Suffix = util.Percent
	})
	Range = AutoHatter:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = util.Studs
	})
	Delay = AutoHatter:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)
