run(function()
	local AutoBee
	local Collect
	local CollectRange
	local CollectDelay
	local LimitCollect
	local Deposit
	local DepositRange
	local DepositDelay

	AutoBee = kits:CreateModule({
		Name = 'AutoBeekeeper',
		Function = function(callback)
			if callback then
				local hives = collection('beehive', AutoBee)

				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position

						if Collect.Enabled and (not LimitCollect.Enabled or store.hand.tool and store.hand.tool.Name == 'bee_net') then
							for _, v in collectionService:GetTagged('bee') do
								if v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude <= CollectRange.Value then
									bedwars.Handler:Get('PickUpBee'):Fire('SendToServer', {
										beeId = v:GetAttribute('BeeId')
									})

									if CollectDelay.Value > 0 then
										task.wait(CollectDelay.Value)
									end
								end
							end
						end

						if Deposit.Enabled and getItem('bee') then
							for _, v in hives do
								if not getItem('bee') then
									break
								end

								local prompt = v:FindFirstChildWhichIsA('ProximityPrompt')
								if prompt and (v:GetAttribute('Level') or 0) < 10 and v:GetAttribute('PlacedByUserId') == lplr.UserId and (localPosition - v.Position).Magnitude <= DepositRange.Value then
									task.spawn(fireproximityprompt, prompt)

									if DepositDelay.Value > 0 then
										task.wait(DepositDelay.Value)
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoBee.Enabled
			end
		end,
		Tooltip = 'Automatically deposit bees, and collects nearby bees'
	})
	Collect = AutoBee:CreateToggle({
		Name = 'Collect bees',
		Default = true,
		Function = function(call)
			if CollectRange then
				CollectRange.Object.Visible = call
				CollectDelay.Object.Visible = call
				LimitCollect.Object.Visible = call
			end
		end
	})
	CollectRange = AutoBee:CreateSlider({
		Name = 'Collect Range',
		Min = 1,
		Max = 22,
		Default = 20,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	CollectDelay = AutoBee:CreateSlider({
		Name = 'Collect delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Darker = true
	})
	LimitCollect = AutoBee:CreateToggle({
		Name = 'Limit to item',
		Darker = true
	})
	Deposit = AutoBee:CreateToggle({
		Name = 'Deposit bees',
		Function = function(call)
			if DepositRange then
				DepositRange.Object.Visible = call
				DepositDelay.Object.Visible = call
			end
		end,
		Tooltip = 'Automatically puts the bees into a beehive'
	})
	DepositRange = AutoBee:CreateSlider({
		Name = 'Deposit Range',
		Min = 1,
		Max = 14,
		Default = 14,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	DepositDelay = AutoBee:CreateSlider({
		Name = 'Deposit Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Darker = true,
		Visible = false
	})
end)
