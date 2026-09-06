run(function()
	local AutoNazar
	local Consume
	local Health
	local Force
	local Empower
	local Range
	local empowered = false

	AutoNazar = kits:CreateModule({
		Name = 'AutoNazar',
		Function = function(callback)
			if callback then
				empowered = false
				AutoNazar:Clean(lplr.CharacterAdded:Connect(function()
					empowered = false
				end))

				repeat
					if entitylib.isAlive and store.equippedKit == 'nazar' then
						local character = entitylib.character
						local lifeForce = lplr:GetAttribute('LifeForce') or 0

						if Consume.Enabled and lifeForce >= Force.Value and (character.Health / character.MaxHealth) <= (Health.Value / 100) and bedwars.AbilityController:canUseAbility('consume_life_foce', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('consume_life_foce')
						end

						if Empower.Enabled then
							local wanted = entitylib.EntityPosition({
								Origin = character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							}) and true or false
							if wanted ~= empowered then
								local ability = wanted and 'enable_life_force_attack' or 'disable_life_force_attack'
								if bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
									bedwars.AbilityController:useAbility(ability)
									empowered = wanted
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoNazar.Enabled
			end
		end,
		Tooltip = 'Automatically spends life force to heal and empowers attacks near enemies'
	})
	Health = AutoNazar:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 70,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Consumes once your health drops below this'
	})
	Force = AutoNazar:CreateSlider({
		Name = 'Life force',
		Min = 1,
		Max = 150,
		Default = 35,
		Tooltip = 'Life force you need stored before consuming'
	})
	Range = AutoNazar:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Consume = AutoNazar:CreateToggle({
		Name = 'Consume life force',
		Default = true,
		Function = function(callback)
			Health.Object.Visible = callback
			Force.Object.Visible = callback
		end,
		Tooltip = 'Converts stored life force into health when hurt'
	})
	Empower = AutoNazar:CreateToggle({
		Name = 'Empower attacks',
		Default = true,
		Function = function(callback)
			Range.Object.Visible = callback
		end,
		Tooltip = 'Enables empowered attacks while an enemy is close and disables them after'
	})
end)
