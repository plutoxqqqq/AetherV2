run(function()
	local AutoGrove
	local Delay
	local nextWater = 0

	AutoGrove = kits:CreateModule({
		Name = 'AutoGrove',
		Function = function(callback)
			if callback then
				nextWater = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'spirit_gardener' and tick() >= nextWater and bedwars.AbilityController:canUseAbility('spirit_gardener_water', {disableBlockedAbilityAlert = true}) then
						nextWater = tick() + Delay.Value
						bedwars.AbilityController:useAbility('spirit_gardener_water')
					end
					task.wait(0.1)
				until not AutoGrove.Enabled
			end
		end,
		Tooltip = 'Automatically feeds spirit energy to your flowers so they never wither'
	})
	Delay = AutoGrove:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 20,
		Default = 3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)