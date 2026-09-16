run(function()
    local InfiniteJump
    local Mode
    local MaxJumps
    local TP
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local jumps = 0
    local lastJump = 0
    -- Two JumpRequests this close together are the same press: held spacebar and the landing
    -- frame both fire a second request that used to be counted as a fresh jump.
    local JUMP_DEBOUNCE = 0.09
    -- Hold mode reads the key itself. A held spacebar does not reliably repeat JumpRequest, so
    -- waiting for the engine to ask again is what made a held key stop jumping mid-air.
    local held = false

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

    local function isGrounded()
        local humanoid = entitylib.isAlive and entitylib.character and entitylib.character.Humanoid
        return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
    end

    local function isJumpKey(keyCode)
        return keyCode == Enum.KeyCode.Space or keyCode == Enum.KeyCode.ButtonA
    end

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
	Tooltip = 'Jump again in mid-air, either for as long as you hold the key or a fixed number of times per airtime',
	Function = function(callback: boolean)
		if callback then
			jumps = 0
			lastJump = 0
			held = false
			groundTick, tpTick, tpToggle, oldy = tick(), tick(), true, nil

			InfiniteJump:Clean(runService.PreSimulation:Connect(function()
				if not entitylib.isAlive then return end
				-- Touching the ground refills the jump counter, which is what makes the cap
				-- "per airtime" rather than per life.
				if isGrounded() then jumps = 0 end
				if TP.Enabled then tpDownStep() end
				-- Hold mode: the key is the whole condition, so the module asks for the next jump
				-- itself rather than hoping the engine repeats the request. Only in the air, so
				-- the first hop stays the game's own jump.
				if Mode.Value == 'Hold' and held and not isGrounded() then
					if tick() - lastJump >= JUMP_DEBOUNCE then
						local humanoid = entitylib.character.Humanoid
						if humanoid then
							lastJump = tick()
							humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end
			end))

			InfiniteJump:Clean(inputService.InputBegan:Connect(function(input)
				if isJumpKey(input.KeyCode) then held = true end
			end))
			InfiniteJump:Clean(inputService.InputEnded:Connect(function(input)
				if isJumpKey(input.KeyCode) then held = false end
			end))
			-- Releasing focus with the key down used to leave Hold mode jumping forever.
			InfiniteJump:Clean(inputService.WindowFocusReleased:Connect(function()
				held = false
			end))

			InfiniteJump:Clean(inputService.JumpRequest:Connect(function()
				if not entitylib.isAlive then return end
				local character = entitylib.character
				local humanoid, root = character.Humanoid, character.RootPart
				if not humanoid or not root then return end

				-- Leaving the ground is the game's own jump: it costs one of the allowance and
				-- is never boosted, so a normal hop still behaves normally.
				if isGrounded() then
					jumps = 1
					lastJump = tick()
					return
				end

				if Mode.Value ~= 'Jump' then return end
				-- A second request in the same beat is held spacebar or the landing frame, not a
				-- new jump. Counting it was the old double jump.
				if tick() - lastJump < JUMP_DEBOUNCE then return end

				if jumps >= MaxJumps.Value then return end
				jumps += 1
				lastJump = tick()
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end))
		else
			held = false
		end
	end,
	ExtraText = function()
		if TP.Enabled then return 'TP Down' end
		if Mode.Value == 'Jump' then return jumps .. '/' .. tostring(MaxJumps.Value) end
		return Mode.Value
	end,
    })
    Mode = InfiniteJump:CreateDropdown({
	Name = 'Mode',
	-- Jump first on purpose: the dropdown falls back to the first entry when a saved value is
	-- not in the list, and a config saved while the retired Velocity mode existed says exactly
	-- that. Jump is the closest thing to it, so that config keeps a capped number of jumps
	-- instead of silently switching the player to Hold.
	List = { 'Jump', 'Hold' },
	Default = 'Jump',
	Function = function(value)
		-- The cap only exists for Jump mode; hiding it in Hold mode keeps the option list
		-- honest about what actually reads it.
		if MaxJumps and MaxJumps.Object then
			MaxJumps.Object.Visible = value == 'Jump'
		end
	end,
	Tooltip = 'Jump: a fixed number of mid-air jumps per airtime, set by Max jumps.\nHold: keeps applying jumps for as long as the key is down',
    })
    MaxJumps = InfiniteJump:CreateSlider({
	Name = 'Max jumps',
	Min = 1,
	Max = 20,
	Default = 2,
	Tooltip = 'Jump mode only: how many jumps you get before touching the ground again, counted from the moment you leave it. 2 is a double jump; the counter refills on every landing',
	Visible = Mode.Value == 'Jump',
    })
    TP = InfiniteJump:CreateToggle({
	Name = 'TP Down',
	Tooltip = 'Touches the ground and returns once you have been airborne too long, so the server keeps seeing you land. Jumping is unaffected',
    })
end)
