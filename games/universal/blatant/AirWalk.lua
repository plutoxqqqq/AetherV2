run(function()
    local AirWalk
    local platform = Instance.new('Part')
    platform.Name = 'AetherAirWalkGround'
    platform.Anchored = true
    platform.CanCollide = true
    platform.CanQuery = false
    platform.CanTouch = false
    platform.Transparency = 1
    platform.Size = Vector3.new(7, 0.3, 7)
    platform.CFrame = CFrame.new(0, -10000, 0)

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    rayCheck.RespectCanCollide = true
    local lastGroundY
    local trackedCharacter

    local function clearance(character)
	return character.HipHeight
		or ((character.Humanoid and character.Humanoid.HipHeight or 2) + (character.RootPart.Size.Y * 0.5))
    end

    local function groundBelow(root)
	-- A real floor anywhere below the player takes precedence over the fake platform.
	-- The platform itself is excluded from this raycast by the active filter.
	return workspace:Raycast(
		root.Position + Vector3.new(0, 0.75, 0),
		Vector3.new(0, -10000, 0),
		rayCheck
	)
    end

    AirWalk = vape.Categories.Blatant:CreateModule({
	Name = 'AirWalk',
	Function = function(callback)
		if callback then
			platform.CFrame = CFrame.new(0, -10000, 0)
			platform.Parent = workspace
			AirWalk:Clean(runService.PreSimulation:Connect(function()
				if not entitylib.isAlive then
					platform.CFrame = CFrame.new(0, -10000, 0)
					lastGroundY = nil
					trackedCharacter = nil
					return
				end

				local character = entitylib.character
				if trackedCharacter ~= character.Character then
					trackedCharacter = character.Character
					lastGroundY = nil
				end
				local root = character.RootPart
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, platform}
				pcall(function() rayCheck.CollisionGroup = root.CollisionGroup end)
				local ground = groundBelow(root)

				if ground and ground.Normal.Y > 0.15 then
					lastGroundY = ground.Position.Y
					platform.CFrame = CFrame.new(0, -10000, 0)
					return
				end

				if lastGroundY then
					platform.CFrame = CFrame.new(root.Position.X, lastGroundY - (platform.Size.Y * 0.5), root.Position.Z)
				else
					platform.CFrame = CFrame.new(0, -10000, 0)
				end
			end))
		else
			platform.Parent = nil
		end
	end,
	Tooltip = 'Creates stable fake ground over void at the height of your most recent real floor',
    })

    -- Remember real floor while the module is off too, so enabling it just after walking
    -- over an edge uses the ledge height instead of inventing ground at the current air height.
    vape:Clean(runService.PreSimulation:Connect(function()
	if AirWalk.Enabled or not entitylib.isAlive then
		if not entitylib.isAlive then
			lastGroundY = nil
			trackedCharacter = nil
		end
		return
	end
	local character = entitylib.character
	if trackedCharacter ~= character.Character then
		trackedCharacter = character.Character
		lastGroundY = nil
	end
	local root = character.RootPart
	rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, platform}
	pcall(function() rayCheck.CollisionGroup = root.CollisionGroup end)
	local ground = groundBelow(root)
	if ground and ground.Normal.Y > 0.15 then lastGroundY = ground.Position.Y end
    end))

    vape:Clean(function()
	platform:Destroy()
    end)
end)