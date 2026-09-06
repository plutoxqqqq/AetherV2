run(function()
	local AutoRagnar

	local function getBed()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude <= 22 and not v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				return v
			end
		end
		return
	end

	AutoRagnar = kits:CreateModule({
		Name = 'AutoRagnar',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'berserker' and bedwars.AbilityController:canUseAbility('berserker_rage', {disableBlockedAbilityAlert = true}) and getBed() then
						bedwars.AbilityController:useAbility('berserker_rage')
					end
					task.wait(0.1)
				until not AutoRagnar.Enabled
			end
		end,
		Tooltip = 'Automatically uses "Berserker Rage" ability when near\nopponent\'s bed.'
	})
end)
