run(function()
	local FastClimb
	local ClimbSpeed

	local function localHumanoid()
		local character = lplr.Character
		local humanoid = character and character:FindFirstChildOfClass('Humanoid')
		if humanoid and humanoid.Health > 0 then
			return humanoid
		end
	end

	local function applyClimbSpeed()
		local humanoid = localHumanoid()
		if humanoid and humanoid.ClimbSpeed ~= ClimbSpeed.Value then
			humanoid.ClimbSpeed = ClimbSpeed.Value
		end
	end

	FastClimb = vape.Categories.Blatant:CreateModule({
		Name = 'FastClimb',
		Function = function(callback)
			if callback then
				FastClimb:Clean(lplr.CharacterAdded:Connect(function()
					task.wait(0.1)
					applyClimbSpeed()
				end))

				-- The game rewrites ClimbSpeed from its own movement state, so a one shot
				-- assignment only held for a frame. Keep it applied while the module is on.
				FastClimb:Clean(runService.Heartbeat:Connect(applyClimbSpeed))
				applyClimbSpeed()
			else
				local humanoid = localHumanoid()
				if humanoid then
					humanoid.ClimbSpeed = 12
				end
			end
		end,
		Tooltip = 'Increases climbing speed'
	})

	ClimbSpeed = FastClimb:CreateSlider({
		Name = 'Climb Speed',
		Min = 1,
		Max = 100,
		Default = 32,
		Suffix = 'studs/s'
	})
end)
