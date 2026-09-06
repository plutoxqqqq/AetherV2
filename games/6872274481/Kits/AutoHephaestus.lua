run(function()
	local AutoHephaestus
	local Summon
	local lastRepair, lastSummon = 0, 0

	AutoHephaestus = kits:CreateModule({
		Name = 'AutoHephaestus',
		Function = function(callback)
			if callback then
				AutoHephaestus:Clean(runService.Heartbeat:Connect(function()
					if store.equippedKit ~= 'tinker' then return end

					if bedwars.TinkerKitController.mounted then
						if tick() >= lastRepair and bedwars.AbilityController:canUseAbility('tinker_self_repair', {disableBlockedAbilityAlert = true}) and (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 1 then
							lastRepair = tick() + 0.5
							bedwars.AbilityController:useAbility('tinker_self_repair')
						end
					elseif Summon.Enabled and tick() >= lastSummon and bedwars.AbilityController:canUseAbility('tinker_summon', {disableBlockedAbilityAlert = true}) then
						lastSummon = tick() + 1
						bedwars.AbilityController:useAbility('tinker_summon')
					end
				end))
			end
		end,
		Tooltip = 'Automatically repairs your Tinker machine whenever the self repair ability is available'
	})
	Summon = AutoHephaestus:CreateToggle({
		Name = 'Summon tinker',
		Tooltip = 'Calls the machine back whenever you are not mounted on it'
	})
end)
