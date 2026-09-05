run(function()
	local AutoEvelynn
	local Delay, OnlyFalling, OnlySwinging, FaceTarget
	local EVELYNN_RANGE = 120
	local SWING_WINDOW = 0.3
	local ATTEMPT_COOLDOWN = 0.35
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.RespectCanCollide = true
	local rayCharacter
	local swingMarker, swingSeenAt = nil, -math.huge

	local function soulPosition(soul)
		if not soul or not soul.Parent then return nil end
		if soul:IsA('BasePart') then return soul.Position end
		if soul:IsA('Model') then
			local ok, pivot = pcall(soul.GetPivot, soul)
			if ok then return pivot.Position end
		end
		local part = soul:FindFirstChildWhichIsA('BasePart', true)
		return part and part.Position or nil
	end

	local function fallingIntoVoid(root)
		if not root or root.AssemblyLinearVelocity.Y >= -2 then return false end
		if rayCharacter ~= lplr.Character then
			rayCharacter = lplr.Character
			ray.FilterDescendantsInstances = rayCharacter and {rayCharacter} or {}
		end
		return workspace:Raycast(root.Position, Vector3.new(0, -80, 0), ray) == nil
	end

	local function updateSwing()
		local value = bedwars.SwordController and bedwars.SwordController.lastSwing or 0
		if value ~= swingMarker then swingMarker, swingSeenAt = value, os.clock() end
	end

	local function findNearestTarget()
		if not entitylib.isAlive then return end
		local root, nearest, distance = entitylib.character.RootPart, nil, math.huge
		for _, entity in entitylib.List do
			if entity.Targetable and entity.Player and entity.RootPart and entity.RootPart.Parent then
				local magnitude = (entity.RootPart.Position - root.Position).Magnitude
				if magnitude < distance then nearest, distance = entity, magnitude end
			end
		end
		return nearest
	end

	local function faceNearestTarget()
		if not FaceTarget.Enabled or not entitylib.isAlive then return end
		local root, nearest = entitylib.character.RootPart, findNearestTarget()
		if nearest then
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(nearest.RootPart.Position.X, root.Position.Y, nearest.RootPart.Position.Z))
		end
	end

	local function faceAfterRecall(startPosition)
		if not FaceTarget.Enabled then return end
		task.spawn(function()
			local deadline = os.clock() + 0.4
			repeat
				task.wait()
				if not AutoEvelynn.Enabled or not entitylib.isAlive then return end
				local root = entitylib.character.RootPart
				if root and (root.Position - startPosition).Magnitude > 3 then break end
			until os.clock() >= deadline
			if AutoEvelynn.Enabled then faceNearestTarget() end
		end)
	end

	local function findNearestSoul(souls, root)
		local nearest, distance = nil, math.huge
		for _, soul in souls do
			local position = soulPosition(soul)
			if position then
				local magnitude = (position - root.Position).Magnitude
				if magnitude <= EVELYNN_RANGE and magnitude < distance then nearest, distance = soul, magnitude end
			end
		end
		return nearest
	end

	AutoEvelynn = kits:CreateModule({
		Name = 'AutoEvelynn',
		Category = 'Auto',
		Function = function(callback)
			if not callback then return end
			swingMarker, swingSeenAt = bedwars.SwordController and bedwars.SwordController.lastSwing or 0, -math.huge
			local souls = collection('EvelynnSoul', AutoEvelynn)
			task.spawn(function()
				repeat task.wait() until store.matchState ~= 0 or not AutoEvelynn.Enabled
				if not AutoEvelynn.Enabled then return end

				local pendingSoul, pendingSince, lastAttempt
				lastAttempt = 0
				repeat
					-- Do not run alongside cv's general AutoKit spirit collector.
					if entitylib.isAlive and store.equippedKit == 'spirit_assassin'
						and bedwars.SpiritAssassinController and not ((vape.Modules.AutoKit or {}).Enabled) then
						local root = entitylib.character.RootPart
						updateSwing()
						local soul = findNearestSoul(souls, root)
						if soul then
							local now = os.clock()
							if pendingSoul ~= soul then pendingSoul, pendingSince = soul, now end
							local swinging = store.hand.toolType == 'sword' and now - swingSeenAt <= SWING_WINDOW
							local conditionsReady = (not OnlyFalling.Enabled or fallingIntoVoid(root))
								and (not OnlySwinging.Enabled or swinging)
							if pendingSince and now - pendingSince >= Delay.Value and conditionsReady and soul.Parent
								and now - lastAttempt >= ATTEMPT_COOLDOWN then
								lastAttempt = now
								-- Revalidate just before using the spirit: the player can begin
								-- falling or stop swinging between the scan and this call.
								if (not OnlyFalling.Enabled or fallingIntoVoid(root))
									and (not OnlySwinging.Enabled or (store.hand.toolType == 'sword' and os.clock() - swingSeenAt <= SWING_WINDOW)) then
									local previous = root.Position
									local controller = bedwars.SpiritAssassinController
									local success = controller and pcall(controller.useSpirit, controller, lplr, soul)
									if success then faceAfterRecall(previous) end
								end
								pendingSoul, pendingSince = nil, nil
							end
						else
							pendingSoul, pendingSince = nil, nil
						end
					else
						pendingSoul, pendingSince = nil, nil
					end
					task.wait(0.03)
				until not AutoEvelynn.Enabled
			end)
		end,
		Tooltip = 'Conditionally recalls to Evelynn spirit orbs; AutoKit must be off'
	})
	Delay = AutoEvelynn:CreateSlider({Name = 'Delay', Min = 0, Max = 2, Default = 0.1, Decimal = 10, Suffix = 'seconds'})
	OnlyFalling = AutoEvelynn:CreateToggle({Name = 'Only when falling', Tooltip = 'Only recalls while falling into the void'})
	OnlySwinging = AutoEvelynn:CreateToggle({Name = 'Only while swinging', Tooltip = 'Only recalls while manually swinging'})
	FaceTarget = AutoEvelynn:CreateToggle({Name = 'Face target', Default = true, Tooltip = 'Faces the nearest enemy after recalling'})
end)