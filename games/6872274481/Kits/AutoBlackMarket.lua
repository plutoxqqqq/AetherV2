run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoBlackMarket
	local Close
	local Range
	local nextUse = 0

	AutoBlackMarket = kits:CreateModule({
		Name = 'AutoBlackMarket',
		Function = function(callback)
			if callback then
				nextUse = 0
				repeat
					if entitylib.isAlive and util.IsKit('black_market_trader') and tick() >= nextUse then
						local threat = Close.Enabled and entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true
						}) or nil

						if threat and util.Ability.Ready('close_black_market') then
							nextUse = tick() + 1
							util.Ability.Use('close_black_market')
						elseif not threat and util.Ability.Ready('open_black_market') then
							nextUse = tick() + 1
							util.Ability.Use('open_black_market')
						end
					end
					task.wait(0.1)
				until not AutoBlackMarket.Enabled
			end
		end,
		Tooltip = 'Keeps the black market open and closes it while an enemy is close'
	})
	Close = AutoBlackMarket:CreateToggle({
		Name = 'Close when threatened',
		Default = true,
		Function = function(callback)
			if Range and Range.Object then Range.Object.Visible = callback end
		end
	})
	Range = AutoBlackMarket:CreateSlider({
		Name = 'Threat range',
		Min = 1,
		Max = 60,
		Default = 20,
		Darker = true,
		Suffix = util.Studs
	})
end)
