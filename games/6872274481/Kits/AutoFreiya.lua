run(function()
	local AutoFreiya
	local Range
	local Stacks
	local Delay

	local cooldown = 0

	AutoFreiya = kits:CreateModule({
		Name = 'AutoFreiya',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'ice_queen' and tick() >= cooldown and bedwars.AbilityController:canUseAbility('ice_queen', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						for _, v in entitylib.List do
							if v.Targetable and (v.Character:GetAttribute('IceQueenStacks') or 0) >= Stacks.Value and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								cooldown = tick() + Delay.Value
								bedwars.AbilityController:useAbility('ice_queen')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFreiya.Enabled
			end
		end,
		Tooltip = 'Automatically detonates ice stacks once enemies are frozen enough'
	})
	Range = AutoFreiya:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoFreiya:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 100,
		Suffix = 'seconds'
	})
	Stacks = AutoFreiya:CreateSlider({
		Name = 'Stacks',
		Min = 1,
		Max = 10,
		Default = 3,
		Tooltip = 'Ice stacks an enemy needs before detonating'
	})
end)
