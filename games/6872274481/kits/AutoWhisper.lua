run(function()
	local AutoWhisper
	local Heal
	local Threshold
	local Fly

	AutoWhisper = kits:CreateModule({
		Name = 'AutoWhisper',
		Function = function(callback)
			if callback then
				local lowestpoint = math.huge

				repeat
					task.wait()
				until store.matchState ~= 0 or not AutoWhisper.Enabled
				if not AutoWhisper.Enabled then
					return
				end

				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end

				repeat
					local liftReady = Fly.Enabled and workspace:GetServerTimeNow() - (lplr:GetAttribute('OwlLiftReadyTime') or 0) > 0
					local healReady = Heal.Enabled and workspace:GetServerTimeNow() - (lplr:GetAttribute('OwlHealReadyTime') or 0) > 0

					if liftReady or healReady then
						for _, v in collectionService:GetTagged('Owl') do
							if v:GetAttribute('Owner') == lplr.UserId then
								local plr = playersService:GetPlayerByUserId(v:GetAttribute('Target'))
								local char = plr and plr.Character
								local root = char and char:FindFirstChild('HumanoidRootPart')

								if root then
									if liftReady and root.Velocity.Y < -10 and root.Position.Y < lowestpoint then
										bedwars.AbilityController:useAbility('OWL_LIFT')
									end

									local health = char:GetAttribute('Health')
									local maxHealth = char:GetAttribute('MaxHealth')
									if healReady and (Threshold.Value >= 100 or health and maxHealth and maxHealth > 0 and health / maxHealth <= Threshold.Value / 100) then
										bedwars.AbilityController:useAbility('OWL_HEAL')
									end
								end
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoWhisper.Enabled
			end
		end,
		Tooltip = 'Automatically uses whisper abilities'
	})
	Heal = AutoWhisper:CreateToggle({
		Name = 'Heal',
		Default = true,
		Function = function(call)
			if Threshold then
				Threshold.Object.Visible = call
			end
		end
	})
	Threshold = AutoWhisper:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 99,
		Darker = true,
		Suffix = '%'
	})
	Fly = AutoWhisper:CreateToggle({
		Name = 'Fly',
		Default = true
	})
end)