run(function()
	local FastClimb
	local watched
	local DEFAULT_CLIMB_SPEED = 12

	-- Writing the humanoid's climb speed on Heartbeat loses to the game: BedWars restores it from
	-- its own movement controller, and the property settles on the game's value for the frame that
	-- the engine actually simulates. So the value is written on Stepped, the last write before
	-- movement is simulated, and anything that changes the property is answered immediately.
	local function apply()
		if not FastClimb.Enabled then return end
		local character = lplr.Character
		local humanoid = character and character:FindFirstChildOfClass('Humanoid')
		if not humanoid or humanoid.Health <= 0 then return end
		local want = math.clamp(FastClimb.ClimbSpeed.Value, 1, 100)
		if humanoid.ClimbSpeed ~= want then
			humanoid.ClimbSpeed = want
		end
	end

	local function watch(character)
		if watched then
			watched:Disconnect()
			watched = nil
		end
		local humanoid = character and character:FindFirstChildOfClass('Humanoid')
		if humanoid then
			watched = humanoid:GetPropertyChangedSignal('ClimbSpeed'):Connect(apply)
		end
	end

	FastClimb = vape.Categories.Blatant:CreateModule({
		Name = 'FastClimb',
		Function = function(callback)
			if callback then
				watch(lplr.Character)
				FastClimb:Clean(lplr.CharacterAdded:Connect(watch))
				FastClimb:Clean(runService.Stepped:Connect(apply))
				apply()
			else
				if watched then
					watched:Disconnect()
					watched = nil
				end
				local character = lplr.Character
				local humanoid = character and character:FindFirstChildOfClass('Humanoid')
				if humanoid then
					humanoid.ClimbSpeed = DEFAULT_CLIMB_SPEED
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
		Suffix = 'studs/s',
		Function = function()
			apply()
		end
	})
end)
