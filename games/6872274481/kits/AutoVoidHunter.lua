run(function()
	local AutoVoidHunter
	local Range
	local Detonate

	AutoVoidHunter = kits:CreateModule({
		Name = 'AutoVoidHunter',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'void_hunter' then
						if Detonate.Enabled and bedwars.AbilityController:canUseAbility('void_hunter_detonate', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('void_hunter_detonate')
						elseif bedwars.AbilityController:canUseAbility('void_hunter_mark', {disableBlockedAbilityAlert = true}) then
							local target = entitylib.EntityPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true,
								Wallcheck = true
							})

							if target then
								bedwars.AbilityController:useAbility('void_hunter_mark')
							end
						end
					end
					task.wait(0.1)
				until not AutoVoidHunter.Enabled
			end
		end,
		Tooltip = 'Automatically marks whoever is near you and sets the mark off'
	})
	Range = AutoVoidHunter:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Detonate = AutoVoidHunter:CreateToggle({
		Name = 'Auto detonate',
		Default = true,
		Tooltip = 'Sets the mark off as soon as the game lets you'
	})
end)