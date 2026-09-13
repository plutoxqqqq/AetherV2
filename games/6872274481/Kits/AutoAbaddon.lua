run(function()
	local AutoAbaddon
	local Delay
	local Limit
	local Range
	local nextPlace = 0

	AutoAbaddon = kits:CreateModule({
		Name = 'AutoAbaddon',
		Function = function(callback)
			if callback then
				nextPlace = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'scarab' and tick() >= nextPlace and bedwars.AbilityController:canUseAbility('place_scarab_hive', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local hives = 0

						for _, v in collectionService:GetTagged('scarab_spawner') do
							local part = v:IsA('Model') and v.PrimaryPart or v
							if part and part:GetAttribute('PlacedByUserId') == lplr.UserId and (part.Position - origin).Magnitude <= Range.Value then
								hives += 1
							end
						end

						if hives < Limit.Value then
							nextPlace = tick() + Delay.Value
							bedwars.AbilityController:useAbility('place_scarab_hive')
						end
					end
					task.wait(0.1)
				until not AutoAbaddon.Enabled
			end
		end,
		Tooltip = 'Keeps scarab hives up around you without spamming the ability'
	})

	Limit = AutoAbaddon:CreateSlider({
		Name = 'Hives',
		Min = 1,
		Max = 10,
		Default = 3,
		Tooltip = 'Stops once this many of your hives are already standing nearby'
	})
	Range = AutoAbaddon:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 100,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far out hives still count toward the limit'
	})
	Delay = AutoAbaddon:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 1.5,
		Decimal = 100,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)
