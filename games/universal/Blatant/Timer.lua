run(function()
	local Timer
	local Value
	local animationSpeeds = {}
	local stepPhysicsFailure

	local function scaleAnimations(scale)
		local character = entitylib and entitylib.character and entitylib.character.Character
		if not character then return end
		local humanoid = character:FindFirstChildOfClass('Humanoid')
		local animator = humanoid and humanoid:FindFirstChildOfClass('Animator')
		if not animator then return end

		for _, track in animator:GetPlayingAnimationTracks() do
			if animationSpeeds[track] == nil then
				animationSpeeds[track] = track.Speed
			end
			pcall(track.AdjustSpeed, track, animationSpeeds[track] * scale)
		end
	end

	local function restoreAnimations()
		for track, speed in animationSpeeds do
			pcall(function() track:AdjustSpeed(speed) end)
		end
		table.clear(animationSpeeds)
	end

	Timer = vape.Categories.Blatant:CreateModule({
		Name = 'Timer',
		Function = function(callback)
			if callback then
				-- StepPhysics is available to supported executors.  Pause and Run are
				-- PluginSecurity methods in Roblox clients, so calling them here caused the
				-- RenderStepped callback to error before Timer could take a single step.
				pcall(setfflag, 'SimEnableStepPhysics', 'True')
				pcall(setfflag, 'SimEnableStepPhysicsSelective', 'True')
				Timer:Clean(runService.RenderStepped:Connect(function(dt)
					local scale = math.max(Value.Value, 1)
					local root = entitylib.character and entitylib.character.RootPart
					if root and scale > 1 and not stepPhysicsFailure then
						local success, problem = pcall(workspace.StepPhysics, workspace, dt * (scale - 1), {root})
						if not success and not stepPhysicsFailure then
							stepPhysicsFailure = tostring(problem)
							warn('[AetherV2] Timer could not step local physics: '..stepPhysicsFailure)
						end
					end
					scaleAnimations(scale)
				end))
			else
				restoreAnimations()
				stepPhysicsFailure = nil
			end
		end,
		Tooltip = 'Change the client game simulation speed',
	})

	Value = Timer:CreateSlider({
		Name = 'Value',
		Min = 1,
		Max = 3,
		Default = 1,
		Decimal = 10,
	})
end)
