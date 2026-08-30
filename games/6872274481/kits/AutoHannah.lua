run(function()
	local AutoHannah
	local Targets
	local Sort
	local Range
	local AuraTarget
	local attempted = setmetatable({}, {__mode = 'k'})

	AutoHannah = kits:CreateModule({
		Name = 'AutoHannah',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'hannah' and not bedwars.StatusEffectUtil:isActive(lplr.Character, 'grounded') and not bedwars.StatusEffectUtil:isActive(lplr.Character, 'frosted') then
						local threshold = bedwars.BalanceFile.HANNAH_BASE_EXECUTE_THRESHOLD + (bedwars.BalanceFile.HANNAH_MAX_COMBO * bedwars.BalanceFile.HANNAH_COMBO_EXECUTE_BOOST)

						for _, ent in entitylib.AllPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						}) do
							if ent.Character:HasTag('HannahExecuteInteraction') and ent.Health <= ent.MaxHealth * threshold and (not AuraTarget.Enabled or (targetinfo.Targets[ent] or 0) > tick()) and (not attempted[ent.Character] or tick() - attempted[ent.Character] >= 0.3) then
								attempted[ent.Character] = tick()

								if bedwars.Handler:Get('HannahPromptTrigger'):Fire('CallServer', {
									user = lplr,
									victimEntity = ent.Character
								}) then
									local billboard = ent.Character:FindFirstChild('Hannah Execution Icon')
									if billboard then
										billboard:Destroy()
									end
								end

								break
							end
						end
					end
					task.wait(0.1)
				until not AutoHannah.Enabled
				table.clear(attempted)
			end
		end,
		Tooltip = 'Automatically executes low health players with Hannah.'
	})
	Targets = AutoHannah:CreateTargets({Players = true})
	local methods = {'Health', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AutoHannah:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Health'
	})
	Range = AutoHannah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AuraTarget = AutoHannah:CreateToggle({
		Name = 'Only killaura target',
		Tooltip = 'Only executes targets that are being attacked by killaura'
	})
end)