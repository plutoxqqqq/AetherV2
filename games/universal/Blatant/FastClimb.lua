run(function()
	local FastClimb = vape.Categories.Blatant:CreateModule({
		Name = 'FastClimb',
		Function = function(callback)
			if callback then
				-- Keep re-applying so the game doesn't reset ClimbSpeed
				FastClimb:Clean(runService.Heartbeat:Connect(function()
					local char = lplr.Character
					local humanoid = char and char:FindFirstChildOfClass('Humanoid')
					if humanoid and humanoid.Health > 0 then
						humanoid.ClimbSpeed = FastClimb.ClimbSpeed.Value
					end
				end))
			else
				local char = lplr.Character
				local humanoid = char and char:FindFirstChildOfClass('Humanoid')
				if humanoid then
					humanoid.ClimbSpeed = 12
				end
			end
		end,
		Tooltip = 'Increases climbing speed'
	})

	FastClimb.ClimbSpeed = FastClimb:CreateSlider({
		Name = 'Climb Speed',
		Min = 1,
		Max = 100,
		Default = 32,
		Suffix = 'studs/s'
	})
end)
