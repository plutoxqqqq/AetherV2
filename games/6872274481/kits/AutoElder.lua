run(function()
	local AutoElder
	local Streamer
	local Range
	local Animation
	local Delay

	local Legit = getFunctionRange(bedwars.EldertreeController.createTreeOrbInteraction) or 10
	local cooldowns = {}

	AutoElder = kits:CreateModule({
		Name = 'AutoElder',
		Function = function(call)
			if call then
				AutoElder:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if Streamer.Enabled and prompt.Name == 'treeOrb' then
						task.delay(0.1, prompt.InputHoldBegin, prompt)
					end
				end))

				repeat
					if not Streamer.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('treeOrb') do
							if tick() > (cooldowns[v] or 0) and (localPosition - v.Spirit.Position).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end

								if (localPosition - v.Spirit.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
										bedwars.AudioManager:playAudio(bedwars.SoundList.CROP_HARVEST)
									end

									if bedwars.Handler:Get('ConsumeTreeOrb'):Fire('CallServer', {treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
										v:Destroy()
									end
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoElder.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically collects tree orbs'
	})
	Streamer = AutoElder:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			if Delay then
				Delay.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end
		end,
		Tooltip = 'Useful for when ur screensharing'
	})
	Animation = AutoElder:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the collect animation'
	})
	Range = AutoElder:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	AutoElder:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Delay = AutoElder:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)