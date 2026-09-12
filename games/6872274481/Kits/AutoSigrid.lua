run(function()
	local AutoSigrid
	local Combat
	local Targets
	local Range
	local nextSummon = 0

	AutoSigrid = kits:CreateModule({
		Name = 'AutoSigrid',
		Function = function(callback)
			if callback then
				nextSummon = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'elk_master' and tick() >= nextSummon and bedwars.AbilityController:canUseAbility('elk_summon', {disableBlockedAbilityAlert = true}) then
						local wanted = not Combat.Enabled

						if not wanted then
							wanted = #entitylib.AllPosition({
								Range = Range.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled
							}) > 0
						end

						if wanted then
							nextSummon = tick() + 1
							bedwars.AbilityController:useAbility('elk_summon')
						end
					end
					task.wait(0.1)
				until not AutoSigrid.Enabled
			end
		end,
		Tooltip = 'Keeps the elk summoned so you are never caught on foot'
	})

	Combat = AutoSigrid:CreateToggle({
		Name = 'Only in combat',
		Function = function(callback)
			Range.Object.Visible = callback
			Targets.Object.Visible = callback
		end,
		Tooltip = 'Waits until somebody is nearby instead of resummoning on cooldown'
	})
	Targets = AutoSigrid:CreateTargets({
		Players = true,
		NPCs = true,
		Visible = false
	})
	Range = AutoSigrid:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 80,
		Default = 40,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)
