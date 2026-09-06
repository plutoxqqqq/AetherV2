run(function()
	local AutoCard
	local Range
	local Delay
	local nextThrow = 0

	AutoCard = kits:CreateModule({
		Name = 'AutoCard',
		Function = function(callback)
			if callback then
				nextThrow = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'card' and tick() >= nextThrow and bedwars.AbilityController:canUseAbility('CARD_THROW', {disableBlockedAbilityAlert = true}) then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})

						if target then
							nextThrow = tick() + Delay.Value
							bedwars.AbilityController:useAbility('CARD_THROW')
						end
					end
					task.wait(0.1)
				until not AutoCard.Enabled
			end
		end,
		Tooltip = 'Automatically throws Fortuna cards at whoever is near you'
	})
	Range = AutoCard:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoCard:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.4,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)
