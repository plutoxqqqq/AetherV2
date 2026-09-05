run(function()
	local AutoCrocowolf
	local Range
	local Targets

	AutoCrocowolf = kits:CreateModule({
		Name = 'AutoCrocowolf',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'beast' and bedwars.AbilityController:canUseAbility('beast_form', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end

						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('beast_form')
						end
					end
					task.wait(0.1)
				until not AutoCrocowolf.Enabled
			end
		end,
		Tooltip = 'Automatically goes into beast form once enough enemies are around you'
	})
	Range = AutoCrocowolf:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoCrocowolf:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before transforming'
	})
end)