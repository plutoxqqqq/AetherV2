run(function()
	local AutoStar
	local Streamer
	local Range
	local Animation
	local Delay

	local cooldowns = {}

	AutoStar = kits:CreateModule({
		Name = 'AutoStarCollector',
		Function = function(callback)
			if callback then
				AutoStar:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if Streamer.Enabled and prompt.Name == 'stars_ProximityPrompt' then
						task.wait(0.1)
						prompt:InputHoldBegin()
					end
				end))

				repeat
					if not Streamer.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('stars') do
							if tick() > (cooldowns[v] or 0) and v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end

								if (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
									end

									bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoStar.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically collects stars'
	})
	Streamer = AutoStar:CreateToggle({
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
	Animation = AutoStar:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the collect animation'
	})
	Range = AutoStar:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	Delay = AutoStar:CreateSlider({
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