run(function()
	local AutoMarina
	local Range

	AutoMarina = kits:CreateModule({
		Name = 'AutoMarina',
		Function = function(call)
			if call then
				local jellies = collection('jellyfish', AutoMarina, function(tab, obj)
					task.delay(0, function()
						if obj:GetAttribute('PlacedByUserId') == lplr.UserId then
							table.insert(tab, obj)
						end
					end)
				end)

				repeat
					if entitylib.isAlive and bedwars.AbilityController:canUseAbility('electrify_jellyfish', {disableBlockedAbilityAlert = true}) then
						for _, v in jellies do
							if v.PrimaryPart and entitylib.EntityPosition({
								Origin = v.PrimaryPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							}) then
								bedwars.AbilityController:useAbility('electrify_jellyfish')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoMarina.Enabled
			end
		end,
		Tooltip = 'Automatically uses "electrify" ability when enemies are near jellies.'
	})
	Range = AutoMarina:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 65,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)