run(function()
    local BulletTracers
    local Material
    local Lifetime
    local Curve
    local Opacity
    local Thickness
    local Color
    local Fade

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude

    local launchHook
    local lastTraced = 0

    local function drawTracer(origin, velocity, gravity)
	local velocityMagnitude = velocity.Magnitude
	if velocityMagnitude <= 0 then return end
	local velocityUnit = velocity / velocityMagnitude
	rayCheck.FilterDescendantsInstances = {lplr.Character}
	local ray = workspace:Raycast(origin, velocityUnit * 2000, rayCheck)
	local endpoint = ray and ray.Position or (origin + velocityUnit * 2000)
	lastTraced = tick()
	prediction.SpawnArcTracer(
		origin,
		velocityUnit,
		velocityMagnitude,
		gravity,
		(endpoint - origin).Magnitude / velocityMagnitude,
		Curve.Value,
		{
			Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value),
			Transparency = Opacity.Value,
			Thick = Thickness.Value,
			Material = Enum.Material[Material.Value],
			Lifetime = Lifetime.Value,
			Fade = Fade.Enabled,
		}
	)
    end

    BulletTracers = vape.Categories.Render:CreateModule({
	Name = 'ProjectileTracers',
	Function = function(callback)
		if callback then
			-- The tracer is drawn from the launch itself. Waiting for the projectile to appear in the
			-- workspace left a visible gap at the start of every shot: the model only arrives after
			-- the server has made it and replicated it back.
			if bedwars.ProjectileLaunchHook then
				launchHook = bedwars.ProjectileLaunchHook:Add('ProjectileTracers', 5, function(nextLaunch, ...)
					local result = nextLaunch(...)
					if type(result) == 'table' and typeof(result.positionFrom) == 'Vector3'
						and typeof(result.initialVelocity) == 'Vector3' then
						local projmeta = select(2, ...)
						local meta = projmeta and bedwars.ProjectileMeta[projmeta.projectile]
						drawTracer(
							result.positionFrom,
							result.initialVelocity,
							tonumber(result.gravitationalAcceleration) or (meta and tonumber(meta.gravitationalAcceleration)) or workspace.Gravity
						)
					end
					return result
				end)
				BulletTracers:Clean(function()
					if launchHook then launchHook(); launchHook = nil end
				end)
			end

			BulletTracers:Clean(workspace.ChildAdded:Connect(function(projectile)
				task.delay(0, function()
					-- The launch already drew this one; only shots that never came through the launch hook
					-- (someone else's, or a projectile spawned without one) are drawn from the model.
					if tick() - lastTraced < 0.75 then return end
					if projectile:GetAttribute('ProjectileShooter') ~= lplr.UserId then
						return
					end
					local origin = projectile:GetPivot().Position
					local velocity = projectile.PrimaryPart and projectile.PrimaryPart.Velocity or Vector3.zero
					local meta = bedwars.ProjectileMeta[projectile.Name]
					drawTracer(origin, velocity, meta and tonumber(meta.gravitationalAcceleration) or workspace.Gravity)
				end)
			end))
		elseif launchHook then
			launchHook()
			launchHook = nil
		end
	end,
	Tooltip = 'Replacement tracers for projectiles'
    })

    local materials = {'SmoothPlastic'}
    for _, v in Enum.Material:GetEnumItems() do
	if v.Name ~= 'SmoothPlastic' then
		table.insert(materials, v.Name)
	end
    end
    Material = BulletTracers:CreateDropdown({
	Name = 'Material',
	List = materials
    })
    Color = BulletTracers:CreateColorSlider({
	Name = 'Tracer Colour',
	DefaultOpacity = 0.5
    })
    Thickness = BulletTracers:CreateSlider({
	Name = 'Thickness',
	Min = 0.01,
	Max = 1,
	Default = 0.1,
	Decimal = 100
    })
    Curve = BulletTracers:CreateSlider({
	Name = 'Curveness',
	Min = 1,
	Max = 100,
	Default = 40,
	Tooltip = 'How curve the projectile is gonna be\n(More curve = more lag)'
    })
    Opacity = BulletTracers:CreateSlider({
	Name = 'Opacity',
	Min = 0,
	Max = 1,
	Default = 0,
	Decimal = 100
    })
    Lifetime = BulletTracers:CreateSlider({
	Name = 'Lifetime',
	Min = 0,
	Max = 5,
	Decimal = 100,
	Default = 2,
	Suffix = 'secs'
    })
    Fade = BulletTracers:CreateToggle({
	Name = 'Fade',
	Default = true
    })
end)
