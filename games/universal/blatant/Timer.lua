-- Client-side time scale: 1 = normal, below 1 = slow motion, above 1 = fast motion.
run(function()
	local Timer
	local Value
	local animationSpeeds = {}

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
			track:AdjustSpeed(animationSpeeds[track] * scale)
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
				setfflag('SimEnableStepPhysics', 'True')
				setfflag('SimEnableStepPhysicsSelective', 'True')
				Timer:Clean(runService.RenderStepped:Connect(function(dt)
					local scale = math.max(Value.Value, 0.1)
					local root = entitylib.character and entitylib.character.RootPart
					if root then
						runService:Pause()
						local success = pcall(function()
							workspace:StepPhysics(dt * scale, {root})
						end)
						runService:Run()
						if not success then runService:Run() end
					end
					scaleAnimations(scale)
				end))
			else
				restoreAnimations()
				pcall(function() runService:Run() end)
			end
		end,
		Tooltip = 'Change the client game simulation speed',
	})

	Value = Timer:CreateSlider({
		Name = 'Value',
		Min = 0.1,
		Max = 3,
		Default = 1,
		Decimal = 10,
	})
end)