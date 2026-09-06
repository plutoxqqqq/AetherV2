run(function()
	local AutoDragonSword
	local Range
	local Targets

	AutoDragonSword = kits:CreateModule({
		Name = 'AutoDragonSword',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'dragon_sword' and bedwars.AbilityController:canUseAbility('dragon_sword_ult', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end

						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('dragon_sword_ult')
						end
					end
					task.wait(0.1)
				until not AutoDragonSword.Enabled
			end
		end,
		Tooltip = 'Automatically uses Lian ultimate once enough enemies are around you'
	})
	Range = AutoDragonSword:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoDragonSword:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before using the ultimate'
	})
end)
