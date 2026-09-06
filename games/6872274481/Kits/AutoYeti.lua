run(function()
	local AutoYeti
	local Range
	local Targets

	AutoYeti = kits:CreateModule({
		Name = 'AutoYeti',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'yeti' and bedwars.AbilityController:canUseAbility('yeti_glacial_roar', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end

						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('yeti_glacial_roar')
						end
					end
					task.wait(0.1)
				until not AutoYeti.Enabled
			end
		end,
		Tooltip = 'Automatically roars once enough enemies are around you'
	})
	Range = AutoYeti:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoYeti:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before roaring'
	})
end)
