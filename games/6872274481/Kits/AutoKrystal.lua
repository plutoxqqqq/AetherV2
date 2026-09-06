run(function()
	local AutoKrystal

	local function getBed()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude <= 22 and not v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				return v
			end
		end
		return
	end

	AutoKrystal = kits:CreateModule({
		Name = 'AutoKrystal',
		Function = function(callback)
			if callback then
				repeat
					local bed = entitylib.isAlive and store.equippedKit == 'glacial_skater' and bedwars.AbilityController:canUseAbility('skating_freeze', {disableBlockedAbilityAlert = true}) and getBed()
					if bed then
						for _, v in store.blocks do
							if (bed.Position - v.Position).Magnitude <= 20 and v:GetAttribute('PlacedByUserId') then
								bedwars.AbilityController:useAbility('skating_freeze')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoKrystal.Enabled
			end
		end,
		Tooltip = 'Automatically uses freeze ability when near\nopponent\'s bed defense.'
	})
end)
