run(function()
	local AutoMetal
	local Limit
	local StreamerMode
	local Duration
	local Range
	local Animation

	local Legit = getFunctionRange(bedwars.HiddenMetalController.onKitLocalActivated) or 0
	local cooldowns = {}

	AutoMetal = kits:CreateModule({
		Name = 'AutoMetal',
		Function = function(call)
			if call then
				AutoMetal:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if StreamerMode.Enabled and prompt.Name == 'hidden-metal-prompt' and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'metal_detector') then
						task.wait(0.1)
						prompt:InputHoldBegin()
					end
				end))

				repeat
					if not StreamerMode.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('hidden-metal') do
							if tick() > (cooldowns[v] or 0) and (localPosition - v.Part.Position).Magnitude <= Range.Value and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'metal_detector') then
								if Duration.Value > 0 then
									task.wait(Duration.Value)
								end

								if (localPosition - v.Part.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.SHOVEL_DIG)
										bedwars.AudioManager:playAudio(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
									end

									bedwars.Handler:Get('CollectCollectableEntity'):Fire('SendToServer', {
										id = v:GetAttribute('Id')
									})
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoMetal.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically uses the metal kit'
	})
	Limit = AutoMetal:CreateToggle({Name = 'Limit to item'})

	StreamerMode = AutoMetal:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			if Duration then
				Duration.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end
		end,
		Tooltip = 'Actually does the metal prompt thing for you'
	})
	Animation = AutoMetal:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the metal collect animation'
	})
	Range = AutoMetal:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = Legit,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	AutoMetal:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Duration = AutoMetal:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 5,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)
