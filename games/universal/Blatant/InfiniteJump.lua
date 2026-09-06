run(function()
    local InfiniteJump
    local Mode
    local TP
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local jumps = 0

    --[[
        TP Down, ported from Fly.

        It is not a descent, and it never replaces the jump - which is what the old version did.
        It handed every JumpRequest to a teleport and returned, so with the option on the module
        stopped jumping altogether and looked completely broken.

        What Fly actually does, and what happens here: stay airborne long enough and the server
        starts treating you as falling. So once per stretch of airtime, drop to whatever is under
        you, hold there just long enough for the touch to register, then go straight back up to
        the height you left. The server sees a player who keeps landing; you never lose altitude.

        universal.lua builds its own entitylib, and AirTime is filled in by the game files rather
        than the library, so the airborne clock is kept here instead.
    ]]
    local groundTick, tpTick, tpToggle, oldy = tick(), tick(), true, nil

    local function tpDownStep()
        local character = entitylib.character
        local root = character and character.RootPart
        if not root or not root.Parent then return end
        if isnetworkowner and not isnetworkowner(root) then return end

        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
        rayCheck.CollisionGroup = root.CollisionGroup

        if tpToggle then
            -- Standing on something resets the clock, exactly as a real landing would.
            if workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), rayCheck) then
                groundTick = tick()
            end
            if oldy or (tick() - groundTick) <= 2 then return end
            local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
            if not ray then return end
            tpToggle = false
            oldy = root.Position.Y
            tpTick = tick() + 0.11
            root.CFrame = CFrame.lookAlong(
                Vector3.new(root.Position.X, ray.Position.Y + (character.HipHeight or 3), root.Position.Z),
                root.CFrame.LookVector
            )
        elseif oldy then
            if tpTick < tick() then
                root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, oldy, root.Position.Z), root.CFrame.LookVector)
                tpToggle = true
                oldy = nil
                groundTick = tick()
            else
                -- Held on the floor for the touch window. Falling away from it mid-hold is what
                -- would stop the landing registering at all.
                local velocity = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            end
        end
    end

    InfiniteJump = vape.Categories.Blatant:CreateModule({
	Name = 'InfiniteJump',
	Tooltip = 'Allows you to jump infinitely',
	Function = function(callback: boolean)
		if callback then
			jumps = 0
			groundTick, tpTick, tpToggle, oldy = tick(), tick(), true, nil

			InfiniteJump:Clean(runService.PreSimulation:Connect(function()
				if not TP.Enabled or not entitylib.isAlive then return end
				tpDownStep()
			end))

			InfiniteJump:Clean(inputService.JumpRequest:Connect(function()
				if not entitylib.isAlive then return end
				jumps += 1

				if jumps > 1 and Mode.Value == 'Velocity' then
					local power = math.sqrt(2 * workspace.Gravity * entitylib.character.Humanoid.JumpHeight)
					entitylib.character.RootPart.Velocity = Vector3.new(
						entitylib.character.RootPart.Velocity.X,
						power,
						entitylib.character.RootPart.Velocity.Z
					)
				elseif Mode.Value == 'Jump' then
					entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end))
		end
	end,
	ExtraText = function()
		return TP.Enabled and 'TP Down' or Mode.Value
	end,
    })
    Mode = InfiniteJump:CreateDropdown({
	Name = 'Mode',
	List = { 'Jump', 'Velocity' },
    })
    TP = InfiniteJump:CreateToggle({
	Name = 'TP Down',
	Tooltip = 'Touches the ground and returns once you have been airborne too long, so the server keeps seeing you land. Jumping is unaffected',
    })
end)
