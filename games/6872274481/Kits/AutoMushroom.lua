run(function()
	local AutoMushroom
	local Ingredient
	local Delay
	local nextAdd = 0

	local ingredients = {
		Mushrooms = 'alchemist_add_mushrooms',
		Flowers = 'alchemist_add_flower',
		Thorns = 'alchemist_add_thorns'
	}

	AutoMushroom = kits:CreateModule({
		Name = 'AutoMushroom',
		Function = function(callback)
			if callback then
				nextAdd = 0

				repeat
					local ability = ingredients[Ingredient.Value]
					if entitylib.isAlive and store.equippedKit == 'alchemist' and tick() >= nextAdd and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
						nextAdd = tick() + Delay.Value
						bedwars.AbilityController:useAbility(ability)
					end
					task.wait(0.1)
				until not AutoMushroom.Enabled
			end
		end,
		Tooltip = 'Automatically tops the alchemist flask up with an ingredient'
	})
	Ingredient = AutoMushroom:CreateDropdown({
		Name = 'Ingredient',
		List = {'Mushrooms', 'Flowers', 'Thorns'}
	})
	Delay = AutoMushroom:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)
