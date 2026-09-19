run(function()
	local PearlTP
	local Legit
	local Limit
	local SwitchBack

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	rayCheck.RespectCanCollide = true

	local function getMouseTarget(mousePosition)
		if not entitylib.isAlive then return nil end
		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
		local ray = gameCamera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
		local result = workspace:Raycast(ray.Origin, ray.Direction * 2048, rayCheck)
		return result and result.Position
	end

	-- Walks the pearl's own arc and reports the first thing it would hit, so a pearl aimed through a wall is
	-- called out instead of being thrown into it.
	local function getPathObstacle(origin, velocity, speed, gravity, target)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {lplr.Character, gameCamera}
		params.RespectCanCollide = true

		local step, previous = 0.05, origin
		for i = 1, 40 do
			local flight = i * step
			local point = origin + velocity.Unit * (speed * flight) + Vector3.new(0, -0.5 * gravity * flight * flight, 0)
			if (point - target).Magnitude <= 1 then
				-- the arc has arrived; anything past this point is the landing spot itself
				break
			end
			local segment = point - previous
			if segment.Magnitude > 0 then
				local hit = workspace:Raycast(previous, segment, params)
				if hit then
					return hit
				end
			end
			previous = point
		end
		return nil
	end

	local function throwPearl(target)
		if not entitylib.isAlive then notif('PearlTP', 'Character missing.', 3, 'warning'); return false end
		local pearl = getItem('telepearl')
		if not pearl or not pearl.tool then notif('PearlTP', 'No telepearl available.', 3, 'warning'); return false end

		local old = store.hand
		if Limit.Enabled and (not old or not old.tool or old.tool.Name:lower() ~= 'telepearl') then
			notif('PearlTP', 'Hold a telepearl first.', 3, 'warning')
			return false
		end

		local meta = bedwars.ProjectileMeta.telepearl
		if not meta or not meta.launchVelocity then
			notif('PearlTP', 'Telepearl projectile data unavailable.', 3, 'warning')
			return false
		end

		local origin = entitylib.character.RootPart.Position
		local speed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2

		-- Targets are fixed points in the world, so the target itself must not be modelled
		-- as falling. Passing workspace.Gravity here used to cancel out the projectile
		-- gravity too, which turned every shot into a flat line at the target.
		local calc = prediction.SolveTrajectory(origin, speed, gravity, target, Vector3.zero, 0, 0, 0)
		if not calc then
			notif('PearlTP', 'Target is too far away for the telepearl.', 4, 'warning')
			return false
		end

		local constants = bedwars.BowConstantsTable or {}
		local shootPosition = (CFrame.new(origin, calc) * CFrame.new(Vector3.new(
			-(tonumber(constants.RelX) or 0),
			-(tonumber(constants.RelY) or 0),
			-(tonumber(constants.RelZ) or 0)
		))).Position
		local aim = prediction.SolveTrajectory(shootPosition, speed, gravity, target, Vector3.zero, 0, 0, 0) or calc
		local direction = CFrame.lookAt(shootPosition, aim).LookVector * speed

		local obstacle = getPathObstacle(shootPosition, direction, speed, gravity, target)
		if obstacle and obstacle.Instance then
			notif('PearlTP', 'Obstacle in the way of the pearl (' .. obstacle.Instance.Name .. ')', 4, 'warning')
			return false
		end

		switchItem(pearl.tool)
		if Legit.Enabled then
			local hotbar = getHotbar(pearl.tool)
			if hotbar then hotbarSwitch(hotbar) end
		end

		local success = pcall(function()
			bedwars.Handler:Get('ProjectileFire'):Fire('CallServerAsync',
				pearl.tool,
				'telepearl',
				'telepearl',
				shootPosition,
				origin,
				direction,
				httpService:GenerateGUID(true),
				{
					drawDurationSeconds = 1,
					shotId = httpService:GenerateGUID(false)
				},
				workspace:GetServerTimeNow() - 0.045
			)
		end)

		if SwitchBack.Enabled and old and old.tool and old.tool ~= pearl.tool then
			switchItem(old.tool)
			if Legit.Enabled then
				local oldHotbar = getHotbar(old.tool)
				if oldHotbar then hotbarSwitch(oldHotbar) end
			end
		end
		return success
	end

	PearlTP = vape.Categories.Utility:CreateModule({
		Name = 'PearlTP',
		Function = function(callback)
			if not callback then return end
			local mousePosition = inputService:GetMouseLocation()
			local target = getMouseTarget(mousePosition)
			if not target then
				notif('PearlTP', 'No valid position under the mouse.', 3, 'warning')
				PearlTP:Toggle()
				return
			end
			throwPearl(target)
			PearlTP:Toggle()
		end,
		Tooltip = 'Throws a telepearl to the position under your mouse using the fastest valid trajectory'
	})

	Legit = PearlTP:CreateToggle({Name = 'Legit Switch', Default = true, Tooltip = 'Visually switches to the telepearl before throwing and back afterwards'})
	Limit = PearlTP:CreateToggle({Name = 'Limit to item', Tooltip = 'Only activates when you are already holding a telepearl'})
	SwitchBack = PearlTP:CreateToggle({Name = 'Switch back', Default = true, Tooltip = 'Returns to the item you were holding before PearlTP'})
end)
