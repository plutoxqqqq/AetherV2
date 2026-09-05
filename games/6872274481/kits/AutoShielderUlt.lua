run(function()
	local AutoShielderUlt
	local Range
	local Targets
	local Delay
	local nextUlt = 0

	AutoShielderUlt = kits:CreateModule({
		Name = 'AutoShielderUlt',
		Function = function(callback)
			if callback then
				nextUlt = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'shielder' and tick() >= nextUlt then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end

						if found >= Targets.Value then
							nextUlt = tick() + Delay.Value
							bedwars.InfernalShieldController:useUlt()
						end
					end
					task.wait(0.1)
				until not AutoShielderUlt.Enabled
			end
		end,
		Tooltip = 'Automatically slams the infernal shield once enough enemies are around you'
	})
	Range = AutoShielderUlt:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoShielderUlt:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before slamming'
	})
	Delay = AutoShielderUlt:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)