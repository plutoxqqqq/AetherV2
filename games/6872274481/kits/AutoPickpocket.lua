run(function()
	local AutoPickpocket
	local Targets
	local Range
	local Hidden

	local Legit = getFunctionRange(bedwars.MimicController.onKitLocalActivated) or 25
	local mimicPickPocket = bedwars.Handler:Get('MimicBlockPickPocketPlayer')
	local sounds = {bedwars.SoundList.MIMIC_PICKPOCKET_1, bedwars.SoundList.MIMIC_PICKPOCKET_2, bedwars.SoundList.MIMIC_PICKPOCKET_3}
	local random = Random.new()

	AutoPickpocket = kits:CreateModule({
		Name = 'AutoPickpocket',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local targets = entitylib.AllPosition({
							Range = Range.Value,
							Origin = localPosition,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = true,
							Sort = sortmethods.Distance
						})

						for _, v in targets do
							if mimicPickPocket:Fire('CallServer', v.Player) then
								bedwars.AudioManager:playAudio(sounds[random:NextInteger(1, #sounds)], {
									playbackSpeedMultiplier = 1.27,
									position = localPosition
								})
							end
						end

						if #targets <= 0 and Hidden.Enabled and store.equippedKit == 'mimic' and bedwars.AbilityController:canUseAbility('MIMIC_BLOCK_HIDDEN', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('MIMIC_BLOCK_HIDDEN')
						end
					end
					task.wait(0.1)
				until not AutoPickpocket.Enabled
			end
		end,
		Tooltip = 'Automatically pickpockets with milo kit.'
	})
	Targets = AutoPickpocket:CreateTargets({Players = true, Walls = true})

	Range = AutoPickpocket:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = Legit,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoPickpocket:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Hidden = AutoPickpocket:CreateToggle({
		Name = 'Hide when clear',
		Tooltip = 'Goes back into the block once nobody is in range'
	})
end)