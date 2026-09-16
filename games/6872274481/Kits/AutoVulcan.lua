run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoVulcan
	local Range
	local Delay
	local nextMark = 0

	AutoVulcan = kits:CreateModule({
		Name = 'AutoVulcan',
		Function = function(callback)
			if callback then
				nextMark = 0
				repeat
					if entitylib.isAlive and util.IsKit('vulcan') and tick() >= nextMark and util.Ability.Ready('vulcan_artillery_mark') then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
						if target then
							nextMark = tick() + Delay.Value
							util.Ability.Use('vulcan_artillery_mark', {target = target.RootPart.Position})
						end
					end
					task.wait(0.1)
				until not AutoVulcan.Enabled
			end
		end,
		Tooltip = 'Marks the closest enemy for the Vulcan artillery'
	})
	Range = AutoVulcan:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 150,
		Default = 60,
		Suffix = util.Studs
	})
	Delay = AutoVulcan:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)
