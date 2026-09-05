run(function()
	local AutoVoidKnight
	local Iron
	local Emeralds
	local Keep
	local Ascend
	local Range

	local function feed(itemType, ability)
		local item = getItem(itemType)
		if item and item.amount > Keep.Value and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
			bedwars.AbilityController:useAbility(ability)
		end
	end

	AutoVoidKnight = kits:CreateModule({
		Name = 'AutoVoidKnight',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'void_knight' then
						if Iron.Enabled then
							feed('iron', 'void_knight_consume_iron')
						end

						if Emeralds.Enabled then
							feed('emerald', 'void_knight_consume_emerald')
						end

						if Ascend.Enabled and bedwars.AbilityController:canUseAbility('void_knight_ascend', {disableBlockedAbilityAlert = true}) then
							local near = entitylib.EntityPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							})
							if near then
								bedwars.AbilityController:useAbility('void_knight_ascend')
							end
						end
					end
					task.wait(0.2)
				until not AutoVoidKnight.Enabled
			end
		end,
		Tooltip = 'Automatically feeds your resources into the void and ascends in fights'
	})
	Keep = AutoVoidKnight:CreateSlider({
		Name = 'Keep',
		Min = 0,
		Max = 64,
		Default = 0,
		Tooltip = 'Resources left untouched in your inventory'
	})
	Range = AutoVoidKnight:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Iron = AutoVoidKnight:CreateToggle({
		Name = 'Iron',
		Default = true
	})
	Emeralds = AutoVoidKnight:CreateToggle({
		Name = 'Emeralds',
		Default = true
	})
	Ascend = AutoVoidKnight:CreateToggle({
		Name = 'Ascend',
		Default = true,
		Tooltip = 'Uses void ascension when an enemy is close'
	})
end)