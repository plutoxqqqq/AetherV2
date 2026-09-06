run(function()
	local FastClimb
	local ClimbSpeed

	FastClimb = vape.Categories.Blatant:CreateModule({
		Name = 'FastClimb',
		Function = function(callback)
			if callback then
				FastClimb:Clean(lplr.CharacterAdded:Connect(function(character)
					local humanoid = character:WaitForChild('Humanoid')
					humanoid.ClimbSpeed = ClimbSpeed.Value
				end))

				if lplr.Character then
					local humanoid = lplr.Character:FindFirstChildOfClass('Humanoid')
					if humanoid then
						humanoid.ClimbSpeed = ClimbSpeed.Value
					end
				end
			end
		end,
		Tooltip = 'Increases climbing speed.'
	})

	ClimbSpeed = FastClimb:CreateSlider({
		Name = 'Climb Speed',
		Min = 1,
		Max = 100,
		Default = 32,
		Suffix = 'studs/s'
	})
end)