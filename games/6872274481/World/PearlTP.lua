run(function()
	local PearlTP
	local Legit
	local Limit
	local SwitchBack

	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		local remote = bedwars.Client:Get(remotes.FireProjectile)
		if remote and remote.instance then
			projectileRemote = remote.instance
		end
	end)

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

	local function throwPearl(target)
		if not entitylib.isAlive then
			notif('PearlTP', 'Character missing.', 3, 'warning')
			return false
		end

		local pearl = getItem('telepearl')
		if not pearl or not pearl.tool then
			notif('PearlTP', 'No telepearl available.', 3, 'warning')
			return false
		end

		local old = store.hand
		if Limit.Enabled and (not old or not old.tool or old.tool.Name:lower() ~= 'telepearl') then
			notif('PearlTP', 'Hold a telepearl first.', 3, 'warning')
			return false
		end

		local meta = bedwars.ProjectileMeta.telepearl
		if not meta or not meta.launchVelocity or not meta.gravitationalAcceleration then
			notif('PearlTP', 'Telepearl projectile data unavailable.', 3, 'warning')
			return false
		end

		local origin = entitylib.character.RootPart.Position
		local aim = prediction.SolveTrajectory(
			origin,
			meta.launchVelocity,
			meta.gravitationalAcceleration,
			target,
			Vector3.zero,
			workspace.Gravity,
			0,
			0
		)
		if not aim then
			notif('PearlTP', 'Target is too far away for the telepearl.', 4, 'warning')
			return false
		end

		local direction = (aim - origin).Unit * meta.launchVelocity
		if direction.Magnitude <= 0 then
			notif('PearlTP', 'Could not calculate a pearl trajectory.', 3, 'warning')
			return false
		end

		switchItem(pearl.tool)
		if Legit.Enabled then
			local hotbar = getHotbar(pearl.tool)
			if hotbar then hotbarSwitch(hotbar) end
		end

		local projectile = bedwars.ProjectileController:createLocalProjectile(
			meta,
			'telepearl',
			'telepearl',
			origin,
			nil,
			direction,
			{drawDurationSeconds = 1}
		)

		local success = pcall(function()
			local result = projectileRemote:InvokeServer(
				pearl.tool,
				'telepearl',
				'telepearl',
				origin,
				origin,
				direction,
				httpService:GenerateGUID(true),
				{
					drawDurationSeconds = 1,
					shotId = httpService:GenerateGUID(false)
				},
				workspace:GetServerTimeNow() - 0.045
			)
			if result then
				pcall(function() result.Parent = replicatedStorage end)
			end
		end)

		if not success and projectile then
			projectile:Destroy()
		end

		if SwitchBack.Enabled and old and old.tool and old.tool ~= pearl.tool then
			switchItem(old.tool)
			if Legit.Enabled then
				local oldHotbar = getHotbar(old.tool)
				if oldHotbar then hotbarSwitch(oldHotbar) end
			end
		end

		return success
	end

	PearlTP = vape.Categories.World:CreateModule({
		Name = 'PearlTP',
		Function = function(callback)
			if not callback then return end

			-- Capture the cursor position at activation so the target cannot move while
			-- the trajectory is being calculated.
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
		Tooltip = 'Throws a telepearl to the position under your mouse using the fastest valid trajectory.'
	})

	Legit = PearlTP:CreateToggle({
		Name = 'Legit Switch',
		Default = true,
		Tooltip = 'Visually switches to the telepearl before throwing and back afterwards.'
	})

	Limit = PearlTP:CreateToggle({
		Name = 'Limit to item',
		Tooltip = 'Only activates when you are already holding a telepearl.'
	})

	SwitchBack = PearlTP:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Tooltip = 'Returns to the item you were holding before PearlTP.'
	})
end)
