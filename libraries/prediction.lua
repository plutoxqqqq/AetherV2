--[[
	Prediction Library
	Source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434
]]
local module = {}
local eps = 1e-9
local cloneref = cloneref or function(ref) return ref end
local tweenService = cloneref(game:GetService('TweenService'))
local function isZero(d)
	return (d > -eps and d < eps)
end

local tracer = Instance.new('Part')
tracer.Anchored = true
tracer.CanCollide = false
tracer.CanQuery = false
tracer.CanTouch = false
tracer.CastShadow = false

local function cuberoot(x)
	return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
end

local function solveQuadric(c0, c1, c2)
	local s0, s1

	local p, q, D

	p = c1 / (2 * c0)
	q = c2 / c0
	D = p * p - q

	if isZero(D) then
		s0 = -p
		return s0
	elseif (D < 0) then
		return
	else -- if (D > 0)
		local sqrt_D = math.sqrt(D)

		s0 = sqrt_D - p
		s1 = -sqrt_D - p
		return s0, s1
	end
end

local function solveCubic(c0, c1, c2, c3)
	local s0, s1, s2

	local num, sub
	local A, B, C
	local sq_A, p, q
	local cb_p, D

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0

	sq_A = A * A
	p = (1 / 3) * (-(1 / 3) * sq_A + B)
	q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)

	cb_p = p * p * p
	D = q * q + cb_p

	if isZero(D) then
		if isZero(q) then -- one triple solution
			s0 = 0
			num = 1
		else -- one single and one double solution
			local u = cuberoot(-q)
			s0 = 2 * u
			s1 = -u
			num = 2
		end
	elseif (D < 0) then -- Casus irreducibilis: three real solutions
		local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
		local t = 2 * math.sqrt(-p)

		s0 = t * math.cos(phi)
		s1 = -t * math.cos(phi + math.pi / 3)
		s2 = -t * math.cos(phi - math.pi / 3)
		num = 3
	else -- one real solution
		local sqrt_D = math.sqrt(D)
		local u = cuberoot(sqrt_D - q)
		local v = -cuberoot(sqrt_D + q)

		s0 = u + v
		num = 1
	end

	sub = (1 / 3) * A

	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end

	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
	local s0, s1, s2, s3

	local coeffs = {}
	local z, u, v, sub
	local A, B, C, D
	local sq_A, p, q, r
	local num

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	D = c4 / c0

	sq_A = A * A
	p = -0.375 * sq_A + B
	q = 0.125 * sq_A * A - 0.5 * A * B + C
	r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

	if isZero(r) then
		coeffs[3] = q
		coeffs[2] = p
		coeffs[1] = 0
		coeffs[0] = 1

		local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
		num = #results
		s0, s1, s2 = results[1], results[2], results[3]
	else
		coeffs[3] = 0.5 * r * p - 0.125 * q * q
		coeffs[2] = -r
		coeffs[1] = -0.5 * p
		coeffs[0] = 1

		s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
		z = s0

		u = z * z - r
		v = 2 * z - p

		if isZero(u) then
			u = 0
		elseif (u > 0) then
			u = math.sqrt(u)
		else
			return
		end
		if isZero(v) then
			v = 0
		elseif (v > 0) then
			v = math.sqrt(v)
		else
			return
		end

		coeffs[2] = z - u
		coeffs[1] = q < 0 and -v or v
		coeffs[0] = 1

		do
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = #results
			s0, s1 = results[1], results[2]
		end

		coeffs[2] = z + u
		coeffs[1] = q < 0 and v or -v
		coeffs[0] = 1

		if (num == 0) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s0, s1 = results[1], results[2]
		end
		if (num == 1) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s1, s2 = results[1], results[2]
		end
		if (num == 2) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s2, s3 = results[1], results[2]
		end
	end

	sub = 0.25 * A

	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end
	if (num > 3) then s3 = s3 - sub end

	return {s3, s2, s1, s0}
end

function module.SpawnTracer(from, to, custom)
    local distance = (to - from).Magnitude
    if distance < 0.01 then return end

    local t = tracer:Clone()
    t.Color = custom.Color
    t.Size = vector.create(custom.Thick, custom.Thick, distance)
    t.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
    t.Material = custom.Material
	t.Transparency = custom.Opacity or 0

   	if custom.Fade then
		tweenService:Create(t, TweenInfo.new(custom.Lifetime), {
			Transparency = 1
		}):Play()
	end
    return t
end

function module.SpawnArcTracer(origin, aimDirection, projectileSpeed, gravity, travelTime, steps, custom)
    steps = steps or 20
    local stepTime = travelTime / steps
    local g = Vector3.new(0, -gravity, 0)
    local velocity = aimDirection * projectileSpeed

    local prevPos = origin
    local model = Instance.new('Model')
    model.Parent = workspace.Terrain
	if custom.Material == Enum.Material.Glass then
		Instance.new('Highlight', model).Enabled = false
	end
    for i = 1, steps do
        local t = i * stepTime
        local nextPos = origin + velocity * t + 0.5 * g * t * t
        local l = module.SpawnTracer(prevPos, nextPos, custom)
        l.Parent = model
        prevPos = nextPos
    end
	task.delay(custom.Lifetime, model.Destroy, model)
end
-- Solves a single ballistic intercept for a target moving at a constant
-- velocity from `point`. Returns the time-of-flight and the required launch
-- velocity vector (whose direction is the aim point and whose magnitude equals
-- projectileSpeed). The smallest positive root is chosen so the flattest,
-- fastest (direct) shot is always preferred instead of an arbitrary high arc.
local function solveIntercept(origin, projectileSpeed, gravity, point, vel)
	local disp = point - origin
	local p, q, r = vel.X, vel.Y, vel.Z
	local h, j, k = disp.X, disp.Y, disp.Z
	local l = -0.5 * gravity

	-- Gravity-free case: the quartic degenerates (its leading coefficient is zero and
	-- would divide by zero), so solve the linear intercept quadratic directly.
	if math.abs(gravity) < eps then
		local a = p * p + q * q + r * r - projectileSpeed * projectileSpeed
		local b = 2 * (h * p + j * q + k * r)
		local c = h * h + j * j + k * k
		local t
		if math.abs(a) < eps then
			if math.abs(b) > eps then t = -c / b end
		else
			local disc = b * b - 4 * a * c
			if disc >= 0 then
				local sq = math.sqrt(disc)
				for _, cand in {(-b - sq) / (2 * a), (-b + sq) / (2 * a)} do
					if cand > eps and (not t or cand < t) then t = cand end
				end
			end
		end
		if not t then return end
		return t, Vector3.new((h + p * t) / t, (j + q * t) / t, (k + r * t) / t)
	end

	local t
	local solutions = module.solveQuartic(
		l * l,
		-2 * q * l,
		q * q - 2 * j * l - projectileSpeed * projectileSpeed + p * p + r * r,
		2 * j * q + 2 * h * p + 2 * k * r,
		j * j + h * h + k * k
	)
	if solutions then
		for _, v in solutions do
			if v and v > eps and (not t or v < t) then
				t = v
			end
		end
	end
	if not t or t <= eps then return end

	local d = (h + p * t) / t
	local e = (j + q * t - l * t * t) / t
	local f = (k + r * t) / t
	return t, Vector3.new(d, e, f)
end

function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params, resolution, ping)
	if not projectileSpeed or projectileSpeed <= eps then return end
	targetVelocity = targetVelocity or Vector3.zero
	gravity = gravity or 0
	ping = ping or 0
	resolution = math.clamp(resolution or 6, 1, 12)

	-- Ping compensation: the target has already travelled `ping` seconds worth of
	-- velocity that we haven't seen replicated yet, so start from there.
	local basePos = targetPos + targetVelocity * ping

	-- The target only obeys gravity while it is airborne (jumping/falling). When
	-- grounded its vertical velocity is meaningless noise, so we ignore it.
	local airborne = playerGravity and playerGravity > 0 and (playerJump ~= nil or math.abs(targetVelocity.Y) > 0.5)
	local accelY = airborne and -playerGravity or 0

	-- Precompute the floor beneath the target so an airborne prediction can never
	-- sink the aim point through the map on long flight times.
	local floorY
	if accelY ~= 0 and params then
		local groundRay = workspace:Raycast(basePos + Vector3.new(0, math.max(playerHeight or 2, 2), 0), Vector3.new(0, -512, 0), params)
		if groundRay then
			floorY = groundRay.Position.Y + (playerHeight or 0)
		end
	end

	-- Iteratively refine the intercept time. Each pass predicts where the target
	-- will actually be after the current flight-time estimate (folding in its own
	-- gravity), then re-solves. This converges quickly and stays accurate at long
	-- range and while the target is jumping, where a single-shot solve drifts.
	local t = (basePos - origin).Magnitude / projectileSpeed
	local aimVel
	for _ = 1, resolution do
		local point = basePos
		if accelY ~= 0 then
			local dt = t + ping
			local dropY = 0.5 * accelY * dt * dt
			point = Vector3.new(basePos.X, basePos.Y + dropY, basePos.Z)
			if floorY and point.Y < floorY then
				point = Vector3.new(point.X, floorY, point.Z)
			end
		end

		local newT, V = solveIntercept(origin, projectileSpeed, gravity, point, targetVelocity)
		if not newT then break end
		aimVel = V
		if math.abs(newT - t) < 1e-3 then
			t = newT
			break
		end
		t = newT
	end

	if not aimVel then return end
	return origin + aimVel
end

return module
