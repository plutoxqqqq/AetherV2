run(function()
	local FastClimb
	local WalkSpeed
	local ClimbSpeed
	local applied = false
	local savedWalkSpeed

	local function restore()
		if not applied then return end
		applied = false
		if entitylib.isAlive then
			local hum = entitylib.character and entitylib.character.Humanoid
			if hum and savedWalkSpeed then
				hum.WalkSpeed = savedWalkSpeed
			end
		end
		savedWalkSpeed = nil
	end

	FastClimb = vape.Categories.Blatant:CreateModule({
		Name = 'FastClimb',
		Function = function(callback)
			if callback then
				FastClimb:Clean(runService.PreSimulation:Connect(function()
					if not entitylib.isAlive then
						restore()
						return
					end

					local character = entitylib.character
					local hum = character and character.Humanoid
					local root = character and character.RootPart
					if not hum or not root then
						restore()
						return
					end

					if hum:GetState() ~= Enum.HumanoidStateType.Climbing then
						restore()
						return
					end

					if not applied then
						savedWalkSpeed = hum.WalkSpeed
						applied = true
					end

					hum.WalkSpeed = WalkSpeed.Value

					local vel = root.AssemblyLinearVelocity
					local y = ClimbSpeed.Value
					if vel.Y < -0.05 then
						y = -ClimbSpeed.Value
					end
					root.AssemblyLinearVelocity = Vector3.new(vel.X, y, vel.Z)
				end))
				FastClimb:Clean(restore)
			else
				restore()
			end
		end,
		Tooltip = 'Boosts walkspeed and velocity only while climbing.'
	})

	WalkSpeed = FastClimb:CreateSlider({
		Name = 'Walk Speed',
		Min = 1,
		Max = 100,
		Default = 20,
		Suffix = 'studs/s'
	})

	ClimbSpeed = FastClimb:CreateSlider({
		Name = 'Climb Speed',
		Min = 1,
		Max = 100,
		Default = 50,
		Suffix = 'studs/s'
	})
end)

-- blatant/Fly.lua
