run(function()
	local AutoFarmerCletus
	local Range
	local Delay
	local nextPickup = 0

	local crops = {
		carrot = true,
		carrot_seeds = true,
		melon = true,
		melon_seeds = true,
		watermelon = true,
		pumpkin = true,
		pumpkin_block = true,
		pumpkin_seeds = true
	}

	local Pickup = bedwars.Handler:Get('PickupItemDrop')

	AutoFarmerCletus = kits:CreateModule({
		Name = 'AutoFarmerCletus',
		Function = function(callback)
			if callback then
				nextPickup = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'farmer_cletus' and tick() >= nextPickup then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('ItemDrop') do
							if crops[v.Name] and (v:GetAttribute('PickupReadyTime') or math.huge) < workspace:GetServerTimeNow() and (v.Position - origin).Magnitude <= Range.Value then
								nextPickup = tick() + Delay.Value
								Pickup:Fire('CallServerAsync', {itemDrop = v})
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFarmerCletus.Enabled
			end
		end,
		Tooltip = 'Automatically collects the crops and seeds your farm drops'
	})
	Range = AutoFarmerCletus:CreateSlider({
		Name = 'Collect Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoFarmerCletus:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(6)
		end
	})
	Delay = AutoFarmerCletus:CreateSlider({
		Name = 'Delay',
		Min = 0.05,
		Max = 2,
		Default = 0.15,
		Decimal = 100,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)
