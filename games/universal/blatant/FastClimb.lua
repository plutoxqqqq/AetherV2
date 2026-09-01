run(function()
	local FastClimb
	local Speed

	FastClimb = vape.Categories.Blatant:CreateModule({
		Name = 'FastClimb',
		Function = function(callback)
			if callback then
				FastClimb:Clean(runService.PreSimulation:Connect(function()
					if not entitylib.isAlive then
						return
					end
					local character = entitylib.character
					local hum = character.Humanoid
					local root = character.RootPart
					if hum:GetState() ~= Enum.HumanoidStateType.Climbing then
						return
					end
					local velocity = root.AssemblyLinearVelocity
					if math.abs(velocity.Y) > 0.01 then
						root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.sign(velocity.Y) * Speed.Value, velocity.Z)
					end
				end))
			end
		end,
		Tooltip = 'Climb ladders and climbable surfaces faster.'
	})

	Speed = FastClimb:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 100,
		Default = 50,
		Suffix = 'studs/s'
	})
end)