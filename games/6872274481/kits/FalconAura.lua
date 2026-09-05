run(function()
	local FalconAura
	local Range
	local Delay
	local Recall
	local nextSend = 0

	FalconAura = kits:CreateModule({
		Name = 'FalconAura',
		Function = function(callback)
			if callback then
				nextSend = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'falconer' and tick() >= nextSend then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})

						if target and bedwars.AbilityController:canUseAbility('SEND_FALCON', {disableBlockedAbilityAlert = true}) then
							nextSend = tick() + Delay.Value
							bedwars.AbilityController:useAbility('SEND_FALCON')
						elseif not target and Recall.Enabled and bedwars.AbilityController:canUseAbility('RECALL_FALCON', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('RECALL_FALCON')
						end
					end
					task.wait(0.1)
				until not FalconAura.Enabled
			end
		end,
		Tooltip = 'Automatically sends Bekzat falcon at whoever is near you'
	})
	Range = FalconAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 150,
		Default = 80,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = FalconAura:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	Recall = FalconAura:CreateToggle({
		Name = 'Recall when clear',
		Default = true,
		Tooltip = 'Calls the falcon back once nobody is in range'
	})
end)