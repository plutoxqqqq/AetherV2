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

run(function()
    local context = AetherRuntimeContext
    
    
    


local function registerTrixie(context)
    local vape = context and context.vape
    local lplr = context and context.lplr
    local Knit = context and context.Knit
    local canDebug = context and context.canDebug
    local dbg = context and context.debug
    local notif = context and context.notif

    local function notify(message)
        if type(notif) == 'function' then
            pcall(notif, 'TrixieExploit', message, 6, 'warning')
        else
            warn('[AetherV2] TrixieExploit: '..tostring(message))
        end
    end

    if not vape then
        warn('[AetherV2] TrixieExploit: vape unavailable during registration')
        return
    end

    
    
    
    local kits = context and context.kits
    if not kits then
        kits = vape.Categories and (vape.Categories.Kits or vape.Categories.Minigames)
    end

    if not (kits and type(kits.CreateModule) == 'function') then
        warn('[AetherV2] TrixieExploit: active kit category is unavailable')
        notify('The active kit category is unavailable; TrixieExploit could not be registered.')
        return
    end

    
    if vape.Modules and vape.Modules.TrixieExploit then
        return vape.Modules.TrixieExploit
    end

    local TrixieExploit, Distance
    local patched = {}

    local function currentKit()
        if not lplr then return '' end
        return tostring(lplr:GetAttribute('PlayingAsKits') or lplr:GetAttribute('PlayingAsKit') or ''):lower()
    end

    local function isTrixie()
        return currentKit():find('trixie', 1, true) ~= nil
    end

    local function restore()
        if not (dbg and type(dbg.setconstant) == 'function') then
            table.clear(patched)
            return
        end

        for i = #patched, 1, -1 do
            local record = patched[i]
            pcall(dbg.setconstant, record.fn, record.index, record.original)
        end
        table.clear(patched)
    end

    local function inspectFunction(fn, label, seenFunctions, studCandidates, blockCandidates)
        if type(fn) ~= 'function' or seenFunctions[fn] then return end
        seenFunctions[fn] = true

        local ok, constants = pcall(dbg.getconstants, fn)
        if not ok or type(constants) ~= 'table' then return end

        local loweredLabel = tostring(label):lower()
        local marked = loweredLabel:find('trixie', 1, true) ~= nil or loweredLabel:find('rift', 1, true) ~= nil
        if not marked then
            for _, constant in ipairs(constants) do
                if type(constant) == 'string' then
                    local lowered = constant:lower()
                    if lowered:find('trixie', 1, true) or lowered:find('rift', 1, true) then
                        marked = true
                        break
                    end
                end
            end
        end

        if marked then
            for index, constant in ipairs(constants) do
                if type(constant) == 'number' then
                    if math.abs(constant - 27) < 0.001 then
                        table.insert(studCandidates, {fn = fn, index = index, original = constant, label = label})
                    elseif math.abs(constant - 9) < 0.001 then
                        table.insert(blockCandidates, {fn = fn, index = index, original = constant, label = label})
                    end
                end
            end
        end

        if type(dbg.getprotos) == 'function' then
            local protoOk, protos = pcall(dbg.getprotos, fn)
            if protoOk and type(protos) == 'table' then
                for index, proto in ipairs(protos) do
                    inspectFunction(proto, tostring(label)..'.proto'..index, seenFunctions, studCandidates, blockCandidates)
                end
            end
        end
    end

    local function inspectContainer(container, label, seenContainers, seenFunctions, studCandidates, blockCandidates)
        if type(container) ~= 'table' or seenContainers[container] then return end
        seenContainers[container] = true

        for memberName, member in pairs(container) do
            if type(member) == 'function' then
                inspectFunction(member, tostring(label)..'.'..tostring(memberName), seenFunctions, studCandidates, blockCandidates)
            end
        end

        
        
        local mt = getmetatable(container)
        if type(mt) == 'table' then
            for memberName, member in pairs(mt) do
                if type(member) == 'function' then
                    inspectFunction(member, tostring(label)..'.metatable.'..tostring(memberName), seenFunctions, studCandidates, blockCandidates)
                end
            end
            if type(mt.__index) == 'table' then
                inspectContainer(mt.__index, tostring(label)..'.__index', seenContainers, seenFunctions, studCandidates, blockCandidates)
            end
        end
    end

    local function discover()
        local studCandidates, blockCandidates = {}, {}
        local seenFunctions, seenContainers = {}, {}
        local controllers = Knit and Knit.Controllers
        if type(controllers) ~= 'table' then return studCandidates, blockCandidates end

        for controllerName, controller in pairs(controllers) do
            inspectContainer(controller, controllerName, seenContainers, seenFunctions, studCandidates, blockCandidates)
        end

        return studCandidates, blockCandidates
    end

    local function reportFailure(message)
        notify(message)
        return false
    end

    local function apply()
        restore()

        if not (TrixieExploit and TrixieExploit.Enabled) then return false end
        if not isTrixie() then
            return reportFailure('Equip Trixie before using this module.')
        end
        if not (canDebug and dbg and type(dbg.getconstants) == 'function' and type(dbg.setconstant) == 'function') then
            return reportFailure('Your executor cannot patch the Rift Warp range calculation.')
        end

        local studCandidates, blockCandidates = discover()
        
        
        local candidates = #studCandidates > 0 and studCandidates or blockCandidates
        if #candidates == 0 then
            return reportFailure('No live Rift Warp range constant was found; BedWars may now validate it server-side.')
        end

        local desiredBlocks = Distance.Value
        for _, record in ipairs(candidates) do
            local replacement = math.abs(record.original - 27) < 0.001 and desiredBlocks * 3 or desiredBlocks
            local ok = pcall(dbg.setconstant, record.fn, record.index, replacement)
            if ok then
                table.insert(patched, record)
            end
        end

        if #patched == 0 then
            return reportFailure('Rift Warp was found but its range could not be patched.')
        end

        return true
    end

    local created, moduleOrError = pcall(kits.CreateModule, kits, {
        Name = 'TrixieExploit',
        Function = function(enabled)
            if enabled then
                task.defer(apply)
            else
                restore()
            end
        end,
        Tooltip = 'Extends Trixie Rift Warp by patching its live client range calculation. Server validation can still clamp unsupported distances.'
    })

    if not created or not moduleOrError then
        warn('[AetherV2] TrixieExploit registration failed: '..tostring(moduleOrError))
        notify('TrixieExploit failed to register. Check the developer console.')
        return
    end
    TrixieExploit = moduleOrError

    Distance = TrixieExploit:CreateSlider({
        Name = 'Warp distance',
        Min = 9,
        Max = 30,
        Default = 18,
        Suffix = ' blocks',
        Function = function()
            if TrixieExploit.Enabled then task.defer(apply) end
        end
    })

    TrixieExploit:Clean(function()
        restore()
    end)

    return TrixieExploit
end

    local trixieLoaded, trixieResult = xpcall(function()
        return registerTrixie(context)
    end, debug and debug.traceback or tostring)
    if not trixieLoaded then warn('[AetherV2] TrixieExploit failed to load: '..tostring(trixieResult)) end


end)
