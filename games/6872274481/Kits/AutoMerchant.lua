run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoMerchant
	local Delay
	local MatchOnly
	local nextReroll = 0

	AutoMerchant = kits:CreateModule({
		Name = 'AutoMerchant',
		Function = function(callback)
			if callback then
				nextReroll = 0
				repeat
					if entitylib.isAlive and util.IsKit('merchant') and tick() >= nextReroll and util.Ability.Ready('merchant_reroll') then
						if not MatchOnly.Enabled or util.Queue.Ready() then
							nextReroll = tick() + Delay.Value
							util.Ability.Use('merchant_reroll')
						end
					end
					task.wait(0.1)
				until not AutoMerchant.Enabled
			end
		end,
		Tooltip = 'Rerolls the merchant stock on a delay'
	})
	Delay = AutoMerchant:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 30,
		Default = 5,
		Decimal = 10,
		Suffix = util.Seconds
	})
	MatchOnly = AutoMerchant:CreateToggle({
		Name = 'Match only',
		Default = true,
		Tooltip = 'Stops rerolling outside a real match'
	})
end)
