run(function()
	local AutoNyx
	local Targets

	AutoNyx = kits:CreateModule({
		Name = 'AutoNyx',
		Function = function(call)
			if call then
				AutoNyx:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.damageType == 0 and damageTable.fromEntity and damageTable.fromEntity.Name == lplr.Name and entitylib.EntityPosition({
						Range = 14.4,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					}) and bedwars.AbilityController:canUseAbility('midnight', {disableBlockedAbilityAlert = true}) then
						bedwars.AbilityController:useAbility('midnight')
					end
				end))
			end
		end,
		Tooltip = 'Automatically uses the "midnight" ability when meleeing a target'
	})
	Targets = AutoNyx:CreateTargets({
		Players = true,
		NPCs = false
	})
end)