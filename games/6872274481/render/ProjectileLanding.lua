run(function()
	local ProjectileLanding
	local MarkerColor
	local launchHook
	local aimingInput = false
	local lastLaunch
	local states, watchers = {}, {}
	local aimVisual
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true

	local function newVisual(name)
		local marker = Instance.new('Part')
		marker.Name = name
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(1.85, 1.85, 1.85)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Material = Enum.Material.Neon
		marker.Transparency = 1
		marker.Parent = gameCamera
		return {Marker = marker}
	end

	local function destroyVisual(visual)
		if not visual then return end
		if visual.Highlight then visual.Highlight:Destroy() end
		if visual.Marker then visual.Marker:Destroy() end
		visual.Highlight = nil
		visual.Marker = nil
	end

	local function entityForInstance(instance)
		local model = instance and instance:FindFirstAncestorOfClass('Model')
		if not model then return end
		if entitylib.getEntityFromCharacter then
			local ent = entitylib.getEntityFromCharacter(model)
			if ent then return ent end
		end
		for _, ent in entitylib.List do
			if ent.Character == model then return ent end
		end
	end

	local function updateVisual(visual, result)
		if not visual or not visual.Marker then return end
		local color = Color3.fromHSV(MarkerColor.Hue, MarkerColor.Sat, MarkerColor.Value)
		visual.Marker.Color = color
		if not result or typeof(result.Position) ~= 'Vector3' then
			visual.Marker.Transparency = 1
			if visual.Highlight then visual.Highlight:Destroy(); visual.Highlight = nil end
			return
		end
		visual.Marker.CFrame = CFrame.new(result.Position + Vector3.new(0, 0.55, 0))
		visual.Marker.Transparency = math.clamp(MarkerColor.Opacity or 0, 0, 1)
		local ent = entityForInstance(result.Instance)
		local model = ent and ent.Character
		if model ~= visual.HighlightModel then
			if visual.Highlight then visual.Highlight:Destroy() end
			visual.Highlight, visual.HighlightModel = nil, model
			if model then
				local highlight = Instance.new('Highlight')
				highlight.Name = 'ProjectileLandingHit'
				highlight.Adornee = model
				highlight.FillTransparency = 0.55
				highlight.OutlineTransparency = 0.05
				highlight.Parent = gameCamera
				visual.Highlight = highlight
			end
		end
		if visual.Highlight then
			visual.Highlight.FillColor = color
			visual.Highlight.OutlineColor = color
		end
	end

	local function closestPoint(point, a, b)
		local segment = b - a
		local length = segment:Dot(segment)
		if length <= 1e-6 then return a end
		return a + segment * math.clamp((point - a):Dot(segment) / length, 0, 1)
	end

	local function movingEntityCollision(a, b, startTime, endTime)
		local bestPosition, bestInstance, bestDistance
		local sampleTime = (startTime + endTime) * 0.5
		for _, ent in entitylib.List do
			local root = ent.RootPart
			if root and root.Parent and (not ent.Health or ent.Health > 0) then
				local velocity = root.AssemblyLinearVelocity
				local center = root.Position + velocity * sampleTime
				local point = closestPoint(center, a, b)
				local delta = point - center
				local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if horizontal <= 2.1 and math.abs(delta.Y) <= 3.5 then
					local distance = (point - a).Magnitude
					if not bestDistance or distance < bestDistance then
						bestPosition, bestInstance, bestDistance = point, root, distance
					end
				end
			end
		end
		return bestPosition, bestInstance
	end

	local function trace(origin, velocity, gravity, lifetime, extraIgnore)
		if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or velocity.Magnitude <= 0.1 then return end
		local ignored = {lplr.Character, gameCamera}
		if extraIgnore then table.insert(ignored, extraIgnore) end
		for _, ent in entitylib.List do
			if ent.Character then table.insert(ignored, ent.Character) end
		end
		rayParams.FilterDescendantsInstances = ignored
		return prediction.TraceTrajectory(origin, velocity, projectileAcceleration(gravity), rayParams, lifetime, {
			Radius = 0.45,
			SegmentLength = 1,
			MaximumSteps = 600,
			CollisionTest = movingEntityCollision
		})
	end

	local function projectilePart(projectile)
		return projectile:IsA('BasePart') and projectile or projectile:IsA('Model') and projectile.PrimaryPart or nil
	end

	local function projectileMeta(projectile, part)
		return bedwars.ProjectileMeta[projectile.Name] or (part and bedwars.ProjectileMeta[part.Name]) or {}
	end

	local function clearWatcher(projectile)
		local watcher = watchers[projectile]
		if not watcher then return end
		watchers[projectile] = nil
		for _, connection in watcher do connection:Disconnect() end
	end

	local function removeProjectile(projectile)
		local state = states[projectile]
		if not state then return end
		states[projectile] = nil
		if state.Connection then state.Connection:Disconnect() end
		destroyVisual(state.Visual)
	end

	local function trackProjectile(projectile)
		if states[projectile] or projectile:GetAttribute('ProjectileShooter') ~= lplr.UserId then return end
		local part = projectilePart(projectile)
		if not part then return end
		clearWatcher(projectile)
		local meta = projectileMeta(projectile, part)
		local state = {
			Part = part,
			Born = tick(),
			Lifetime = math.clamp(tonumber(meta.lifetimeSec or meta.lifetime) or 7, 0.1, 10),
			Gravity = meta.gravitationalAcceleration or workspace.Gravity,
			Visual = newVisual('ProjectileLandingMarker')
		}
		states[projectile] = state
		state.Connection = projectile.AncestryChanged:Connect(function(_, parent)
			if not parent then removeProjectile(projectile) end
		end)
	end

	local function candidateProjectile(projectile)
		if not (projectile:IsA('BasePart') or projectile:IsA('Model')) then return false end
		if projectile:GetAttribute('ProjectileShooter') ~= nil or bedwars.ProjectileMeta[projectile.Name] then return true end
		local name = projectile.Name:lower()
		return name:find('projectile', 1, true) or name:find('arrow', 1, true)
			or name:find('snowball', 1, true) or name:find('fireball', 1, true)
			or name:find('telepearl', 1, true)
	end

	local function watchProjectile(projectile)
		if not candidateProjectile(projectile) then return end
		if projectile:GetAttribute('ProjectileShooter') ~= nil then
			trackProjectile(projectile)
			return
		end
		if states[projectile] or watchers[projectile] then return end
		local watcher = {}
		watcher.Attribute = projectile:GetAttributeChangedSignal('ProjectileShooter'):Connect(function()
			trackProjectile(projectile)
		end)
		watcher.Ancestry = projectile.AncestryChanged:Connect(function(_, parent)
			if not parent then clearWatcher(projectile) end
		end)
		watchers[projectile] = watcher
	end

	local function setAiming(input, value)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonR2 then
			aimingInput = value
		end
	end

	local function recordLaunch(nextLaunch, ...)
		local result = nextLaunch(...)
		if type(result) == 'table' and typeof(result.positionFrom) == 'Vector3'
			and typeof(result.initialVelocity) == 'Vector3' then
			lastLaunch = {
				Origin = result.positionFrom,
				Velocity = result.initialVelocity,
				Gravity = result.gravitationalAcceleration or workspace.Gravity,
				Lifetime = tonumber(result.lifetimeSec) or 7,
				Time = tick()
			}
		end
		return result
	end

	local function fallbackLaunch()
		if not entitylib.isAlive or not store.hand or not store.hand.tool then return end
		local itemMeta = bedwars.ItemMeta[store.hand.tool.Name]
		local source = itemMeta and itemMeta.projectileSource
		if not source then return end
		local ammo
		local inventory = store.inventory and store.inventory.inventory
		for _, item in inventory and inventory.items or {} do
			if table.find(source.ammoItemTypes or {}, item.itemType) then ammo = item.itemType; break end
		end
		local projectileType = ammo
		if type(source.projectileType) == 'function' then
			local ok, value = pcall(source.projectileType, ammo)
			if ok then projectileType = value end
		end
		local meta = bedwars.ProjectileMeta[projectileType] or {}
		local speed = (tonumber(meta.launchVelocity or source.launchVelocity) or 100) * (tonumber(source.velocityMultiplier) or 1)
		local origin = gameCamera.CFrame.Position
		pcall(function()
			local value = bedwars.ProjectileController:getLaunchPosition(gameCamera.CFrame)
			if typeof(value) == 'Vector3' then origin = value elseif typeof(value) == 'CFrame' then origin = value.Position end
		end)
		local mouseRay = lplr:GetMouse().UnitRay
		return origin, mouseRay.Direction.Unit * speed,
			(tonumber(meta.gravitationalAcceleration) or workspace.Gravity) * (tonumber(source.gravityMultiplier) or 1),
			tonumber(meta.lifetimeSec) or 7
	end

	local function update()
		for projectile, state in states do
			local part = state.Part
			local remaining = state.Lifetime - (tick() - state.Born)
			if remaining <= 0 or not projectile.Parent or not part.Parent then
				removeProjectile(projectile)
			else
				updateVisual(state.Visual, trace(part.Position, part.AssemblyLinearVelocity, state.Gravity, remaining, projectile))
			end
		end

		local result
		if aimingInput then
			if lastLaunch and tick() - lastLaunch.Time <= 0.25 then
				result = trace(lastLaunch.Origin, lastLaunch.Velocity, lastLaunch.Gravity, lastLaunch.Lifetime)
			else
				local origin, velocity, gravity, lifetime = fallbackLaunch()
				if origin then result = trace(origin, velocity, gravity, lifetime) end
			end
		end
		updateVisual(aimVisual, result)
	end

	local function clear()
		for projectile in states do removeProjectile(projectile) end
		for projectile in watchers do clearWatcher(projectile) end
		destroyVisual(aimVisual)
		aimVisual = nil
		lastLaunch = nil
		aimingInput = false
	end

	ProjectileLanding = vape.Categories.Render:CreateModule({
		Name = 'ProjectileLanding',
		Function = function(enabled)
			if not enabled then clear(); return end
			aimVisual = newVisual('ProjectileLandingAimMarker')
			if bedwars.ProjectileLaunchHook then
				launchHook = bedwars.ProjectileLaunchHook:Add('ProjectileLanding', 1, recordLaunch)
				ProjectileLanding:Clean(function()
					if launchHook then launchHook(); launchHook = nil end
				end)
			end
			ProjectileLanding:Clean(workspace.ChildAdded:Connect(watchProjectile))
			ProjectileLanding:Clean(inputService.InputBegan:Connect(function(input, processed)
				if not processed then setAiming(input, true) end
			end))
			ProjectileLanding:Clean(inputService.InputEnded:Connect(function(input) setAiming(input, false) end))
			for _, child in workspace:GetChildren() do watchProjectile(child) end
			local elapsed = 0
			ProjectileLanding:Clean(runService.Heartbeat:Connect(function(dt)
				elapsed += dt
				if elapsed < 0.05 then return end
				elapsed = 0
				update()
			end))
			ProjectileLanding:Clean(clear)
		end,
		Tooltip = 'Predicts held and local projectile landings with bounded deterministic trajectory simulation'
	})
	MarkerColor = ProjectileLanding:CreateColorSlider({Name = 'Marker Color', DefaultOpacity = 0})
end)
