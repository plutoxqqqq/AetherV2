run(function()
	local AutoFarmer
	local Range
	local Switch
	local Delay
	local nextHarvest = 0

	AutoFarmer = kits:CreateModule({
		Name = 'AutoFarmer',
		Function = function(callback)
			if callback then
				nextHarvest = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'farmer_cletus' and tick() >= nextHarvest then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('HarvestableCrop') do
							if v:IsA('BasePart') and (v.Position - origin).Magnitude <= Range.Value then
								nextHarvest = tick() + Delay.Value
								bedwars.breakBlock(v, true, true, nil, Switch.Enabled)
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFarmer.Enabled
			end
		end,
		Tooltip = 'Automatically harvests your crops once they are ripe'
	})
	Range = AutoFarmer:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoFarmer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	Switch = AutoFarmer:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Tooltip = 'Swaps to the right tool before harvesting'
	})
end)
