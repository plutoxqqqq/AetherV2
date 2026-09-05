run(function()
    local TritonClutch
    local Legit
    local Back
    local LandCheck
    local BackDelay
    local Limit
    local Recall
    local NoCamera

    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    local projectileRemote = {InvokeServer = function() end}
    task.spawn(function()
	projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local harpoonAbilities = {'harpoon', 'HARPOON', 'harpoon_throw', 'HARPOON_THROW', 'triton_harpoon', 'TRITON_HARPOON'}
    local virtualInputManager = cloneref(game:GetService('VirtualInputManager'))

    local function isHarpoonTool(tool)
	local name = tool and tool.Name and tool.Name:lower()
	return name == 'harpoon' or name == 'trident' or name == 'triton_harpoon'
    end

    local function clickHeldHarpoon(target)
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end

	local before = #store.selfProjectiles
	local viewport = camera.ViewportSize
	local original = camera.CFrame
	pcall(function()
		camera.CFrame = CFrame.lookAt(original.Position, target)
	end)
	virtualInputManager:SendMouseButtonEvent(viewport.X / 2, viewport.Y / 2, 0, true, game, 0)
	task.wait()
	virtualInputManager:SendMouseButtonEvent(viewport.X / 2, viewport.Y / 2, 0, false, game, 0)
	camera.CFrame = original

	local started = tick()
	repeat
		if #store.selfProjectiles > before then
			return true
		end
		task.wait()
	until tick() - started > 0.25
	return false
    end

    local function waitForHarpoonClutch()
	local started = tick()
	repeat
		task.wait()
		local root = entitylib.isAlive and entitylib.character.RootPart
		if root and root.Velocity.Y > -10 then
			return true
		end
	until not TritonClutch.Enabled or tick() - started > 3
	return false
    end

    task.spawn(function()
	local success, abilityIds = pcall(function()
		return require(replicatedStorage.TS.ability['ability-id']).AbilityId
	end)
	if success then
		for _, ability in abilityIds do
			local lowered = tostring(ability):lower()
			if lowered:find('harpoon', 1, true) then
				table.insert(harpoonAbilities, ability)
			end
		end
	end
    end)

    local function useAbility(list, payloads)
	for _, ability in list do
		local allowed = true
		pcall(function()
			allowed = not bedwars.AbilityController.canUseAbility or bedwars.AbilityController:canUseAbility(ability)
		end)

		if allowed then
			for _, data in payloads do
				local success, result = pcall(function()
					return bedwars.AbilityController:useAbility(ability, newproxy(true), data)
				end)
				if success and result ~= false then
					return true
				end

				success, result = pcall(function()
					return bedwars.AbilityController:useAbility(ability, data)
				end)
				if success and result ~= false then
					return true
				end

				pcall(function()
					bedwars.Client:Get(remotes.UseAbility).instance:FireServer(ability, data)
				end)
			end
		end
	end
	return false
    end

    local function fireHarpoonProjectile(pos, spot, item)
	local projectileType = 'harpoon_projectile'
	local meta = bedwars.ProjectileMeta[projectileType]
	if not meta then
		return false
	end

	local launchVelocity = meta.launchVelocity or 160
	local gravity = meta.gravitationalAcceleration or 0
	local calc = prediction.SolveTrajectory(pos, launchVelocity, gravity, spot, Vector3.zero, workspace.Gravity, 0, 0) or spot
	local dir = CFrame.lookAt(pos, calc).LookVector * launchVelocity
	local shotId = httpService:GenerateGUID(false)
	local landed = false
	local projectile

	pcall(function()
		projectile = bedwars.ProjectileController:createLocalProjectile(meta, projectileType, projectileType, pos, nil, dir, {drawDurationSeconds = 1})
	end)

	if projectile then
		task.spawn(function()
			repeat
				task.wait()
			until not projectile or not projectile.Parent
			landed = true
		end)
	end

	local success, result = pcall(function()
		return projectileRemote:InvokeServer(
			item.tool,
			projectileType,
			projectileType,
			pos,
			pos,
			dir,
			httpService:GenerateGUID(true),
			{
				drawDurationSeconds = 1,
				shotId = shotId
			},
			workspace:GetServerTimeNow() - 0.045
		)
	end)

	return success and result ~= nil, function()
		local started = tick()
		repeat
			task.wait()
		until landed or not TritonClutch.Enabled or tick() - started > 3
		return landed
	end
    end

    local function useHarpoon(pos, spot, item)
	local hotbar, old = getHotbar(item.tool), store.hand
	switchItem(item.tool)
	if Legit.Enabled and hotbar then
		hotbarSwitch(hotbar)
	end

	local used, clutchCheck, recallWait
	if not NoCamera.Enabled and clickHeldHarpoon(spot) then
		clutchCheck = waitForHarpoonClutch
		used = true
	else
		used, clutchCheck = fireHarpoonProjectile(pos, spot, item)
	end

	if not used then
		used = useAbility(harpoonAbilities, {
			{target = spot, origin = pos},
			{targetPosition = spot, position = pos},
			{position = spot},
			spot
		})
		clutchCheck = waitForHarpoonClutch
	end

	if used and Recall.Enabled then
		recallWait = function()
			task.wait(1.25)
			virtualInputManager:SendKeyEvent(true, Enum.KeyCode.C, false, game)
			task.wait()
			virtualInputManager:SendKeyEvent(false, Enum.KeyCode.C, false, game)

			local started, lastPosition, stable = tick(), nil, 0
			repeat
				task.wait(0.1)
				local root = entitylib.isAlive and entitylib.character.RootPart
				if root then
					local currentPosition = root.Position
					local moved = lastPosition and (currentPosition - lastPosition).Magnitude or math.huge
					if tick() - started > 0.75 and moved < 1 and root.Velocity.Magnitude < 8 then
						stable += 0.1
						if stable >= 0.3 then
							return true
						end
					else
						stable = 0
					end
					lastPosition = currentPosition
				end
			until not TritonClutch.Enabled or tick() - started > 7
			return false
		end
	end

	if Back.Enabled and LandCheck.Enabled and clutchCheck then
		clutchCheck()
	end
	if Back.Enabled and old and old.tool then
		if recallWait then
			recallWait()
		else
			task.wait(BackDelay:GetRandomValue())
		end
		switchItem(old.tool)
		if Legit.Enabled and getHotbar(old.tool) then
			hotbarSwitch(getHotbar(old.tool))
		end
	elseif recallWait then
		task.spawn(recallWait)
	end
    end

    local function findNearGround(origin, root)
	local best, bestScore
	local originPosition = origin.Position
	local velocity = root and root.Velocity or Vector3.zero
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local fallSpeed = math.max(-velocity.Y, 0)
	local samples = {}

	local function addSample(position)
		table.insert(samples, position)
	end

	local function getAimPoint(ray, predictedPosition)
		local hit = ray.Position + (ray.Normal * 0.35)
		local part = ray.Instance
		if part and part:IsA('BasePart') then
			local size = part.Size
			local localPredicted = part.CFrame:PointToObjectSpace(predictedPosition)
			local edgeMargin = math.min(0.45, math.max(math.min(size.X, size.Z) * 0.2, 0.08))
			local xLimit = math.max((size.X * 0.5) - edgeMargin, 0)
			local zLimit = math.max((size.Z * 0.5) - edgeMargin, 0)
			localPredicted = Vector3.new(math.clamp(localPredicted.X, -xLimit, xLimit), size.Y * 0.5 + 0.25, math.clamp(localPredicted.Z, -zLimit, zLimit))
			hit = part.CFrame:PointToWorldSpace(localPredicted)
		end
		return hit
	end

	addSample(originPosition)
	for time = 0.15, 2.4, 0.15 do
		local predictedPosition = originPosition + (horizontalVelocity * time) + Vector3.new(0, (velocity.Y * time) - (workspace.Gravity * time * time * 0.5), 0)
		local center = Vector3.new(predictedPosition.X, originPosition.Y, predictedPosition.Z)
		addSample(center)
		for radius = 1, 12, 1 do
			for angle = 0, 315, 45 do
				local radians = math.rad(angle)
				addSample(center + Vector3.new(math.cos(radians) * radius, 0, math.sin(radians) * radius))
			end
		end
	end

	for radius = 16, 72, 4 do
		for angle = 0, 315, 45 do
			local radians = math.rad(angle)
			addSample(originPosition + (horizontalVelocity * 0.65) + Vector3.new(math.cos(radians) * radius, 0, math.sin(radians) * radius))
		end
	end

	for _, sample in samples do
		local ray = workspace:Raycast(sample + Vector3.new(0, 128, 0), Vector3.new(0, -420, 0), rayCheck)
		if ray then
			local drop = math.max(originPosition.Y - ray.Position.Y, 1)
			local timeToPlatform = math.clamp((math.sqrt((fallSpeed * fallSpeed) + (2 * workspace.Gravity * drop)) - fallSpeed) / workspace.Gravity, 0.05, 2.5)
			local predictedPosition = originPosition + (horizontalVelocity * timeToPlatform)
			local aimPoint = getAimPoint(ray, predictedPosition)
			local horizontalDistance = (Vector3.new(aimPoint.X, originPosition.Y, aimPoint.Z) - Vector3.new(originPosition.X, originPosition.Y, originPosition.Z)).Magnitude
			local predictedDistance = (Vector3.new(aimPoint.X, predictedPosition.Y, aimPoint.Z) - Vector3.new(predictedPosition.X, predictedPosition.Y, predictedPosition.Z)).Magnitude
			local score = (predictedDistance * 1.35) + (horizontalDistance * 0.25) + (drop * 0.015)
			if not bestScore or score < bestScore then
				best, bestScore = aimPoint, score
			end
		end
	end
	return best
    end


    TritonClutch = kits:CreateModule({
	Name = 'TritonClutch',
	Category = 'Ability',
	Function = function(callback)
		if callback then
			local lasty, attempted
			repeat
				if entitylib.isAlive and (not Limit.Enabled or isHarpoonTool(store.hand.tool)) then
					local root = entitylib.character.RootPart
					local harpoon = getItem('harpoon') or getItem('triton_harpoon') or getItem('trident')
					rayCheck.FilterDescendantsInstances = {store.map}
					rayCheck.CollisionGroup = root.CollisionGroup

					local onGround = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air
					if onGround then
						lasty = root.CFrame
						attempted = false
					end

					if not onGround and not attempted and harpoon and root.Velocity.Y < -60 and not workspace:Raycast(root.Position, Vector3.new(0, -140, 0), rayCheck) then
						attempted = true
						local ground = findNearGround(root.CFrame, root) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame, root)
						if ground then
							useHarpoon(root.Position, ground, harpoon)
						end
					end
				end
				task.wait(0.03)
			until not TritonClutch.Enabled
		end
	end,
	Tooltip = 'Automatically throws Triton\'s harpoon onto nearby ground after falling a certain distance'
    })

    Legit = TritonClutch:CreateToggle({
	Name = 'Legit Switch',
	Tooltip = 'Visualizes the switching clientside',
	Default = true
    })
    Back = TritonClutch:CreateToggle({
	Name = 'Switch back',
	Default = true,
	Function = function(callback)
		if BackDelay then
			BackDelay.Object.Visible = callback
		end
		if LandCheck then
			LandCheck.Object.Visible = callback
		end
	end,
	Tooltip = 'Switches back to the previous slot after Recall finishes, or after the clutch delay when Recall is off'
    })
    LandCheck = TritonClutch:CreateToggle({
	Name = 'Only after clutch',
	Tooltip = 'Waits for the harpoon clutch before switching back; Recall still waits until the recall finishes',
	Darker = true
    })
    BackDelay = TritonClutch:CreateTwoSlider({
	Name = 'Switch Back Delay',
	Min = 0,
	Max = 2,
	DefaultMin = 0.1,
	DefaultMax = 0.2,
	Darker = true
    })
    Limit = TritonClutch:CreateToggle({
	Name = 'Limit to items',
	Tooltip = "Only throws Triton's harpoon when holding the harpoon or trident"
    })
    NoCamera = TritonClutch:CreateToggle({
	Name = 'Prevent Camera Movement',
	Tooltip = 'Uses server projectile logic instead of moving your camera for the click fallback',
	Default = true
    })
    Recall = TritonClutch:CreateToggle({
	Name = 'Recall',
	Tooltip = 'Presses C to activate Recall / Go to base after clutching'
    })
end)