run(function()
	local AutoNahila
	local Health
	local Range
	local Allies

	AutoNahila = kits:CreateModule({
		Name = 'AutoNahila',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'oasis' and bedwars.AbilityController:canUseAbility('oasis_heal_veil', {disableBlockedAbilityAlert = true}) then
						local character = entitylib.character
						local hurt = (character.Health / character.MaxHealth) <= (Health.Value / 100)

						if not hurt and Allies.Enabled then
							local origin = character.RootPart.Position
							for _, v in entitylib.List do
								if not v.Targetable and v.Player and v ~= character and (v.RootPart.Position - origin).Magnitude <= Range.Value and (v.Health / v.MaxHealth) <= (Health.Value / 100) then
									hurt = true
									break
								end
							end
						end

						if hurt then
							bedwars.AbilityController:useAbility('oasis_heal_veil')
						end
					end
					task.wait(0.1)
				until not AutoNahila.Enabled
			end
		end,
		Tooltip = 'Automatically drops the heal veil when you or a teammate is hurt'
	})
	Health = AutoNahila:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 60,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Heals at or below this much health'
	})
	Allies = AutoNahila:CreateToggle({
		Name = 'Heal teammates',
		Default = true
	})
	Range = AutoNahila:CreateSlider({
		Name = 'Ally range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)
