if not _G.vape or not getgenv().used_init then return {} end
local module = {}
local eps = 1e-9
local cloneref = cloneref or function(ref) return ref end
local playersService = cloneref(game:GetService('Players'))
local tweenService = cloneref(game:GetService('TweenService'))
local statsService = cloneref(game:GetService('Stats'))

local responseTime

local function sampleRtt()
	local ok, ping = pcall(function()
		return statsService.Network.ServerStatsItem['Data Ping']:GetValue()
	end)
	if ok and type(ping) == 'number' and ping > 0 then
		return ping / 1000
	end
	return 0
end

function module.setLatency(value)
	if value == nil then
		responseTime = nil
	elseif type(value) == 'number' and value == value and value > 0 and value < math.huge then
		responseTime = value
	end
end

local latencyBias = 0

--[[
	A replicated position is stale by the sender's upstream plus our downstream, which measures as a
	full round trip rather than half of one. Leading by half a trip was measured over-shooting a 28
	stud/s target by 0.8 studs, so every source here reports a whole round trip.
]]
local function getBaseLatency()
	if store and store.ping and store.ping.total then
		return store.ping.total
	end

	if responseTime then
		return responseTime
	end

	local ok, ping = pcall(playersService.LocalPlayer.GetNetworkPing, playersService.LocalPlayer)
	if ok and type(ping) == 'number' and ping >= 0 then
		return ping * 2
	end
	return sampleRtt()
end

--[[
	No ping value measures the number the solver actually wants, which is how far behind the world
	a replicated position sits once the server's own compensation is folded in. The three sources
	above disagreed by 8ms on the machine this was written against, and the constant offsets each
	caller adds on top of them are not visible from here at all. The bias is therefore graded from
	landed shots instead of estimated, and getLatency reports the corrected figure.
]]
function module.getLatency()
	return math.max(getBaseLatency() + latencyBias, 0)
end

function module.getRawLatency()
	return getBaseLatency()
end

function module.Raycast(origin, direction, params)
	return workspace:Raycast(origin, direction, params)
end

module.IsTrajectoryClear = function(origin, velocity, gravity, travelTime, params, target, ignored)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = params.FilterType
	rayParams.FilterDescendantsInstances = table.clone(params.FilterDescendantsInstances)
	rayParams.IgnoreWater = params.IgnoreWater
	rayParams.CollisionGroup = params.CollisionGroup
	rayParams.RespectCanCollide = params.RespectCanCollide
	local lastPosition = origin
	for i = 1, 10 do
		local time = travelTime * (i / 10)
		local position = origin + velocity * time + Vector3.new(0, -gravity * 0.5 * time * time, 0)
		local direction = position - lastPosition
		local hit = module.Raycast(lastPosition, direction, rayParams)
		local ignoredHits = 0
		while hit do
			ignoredHits += 1
			if ignoredHits > 64 then
				return false, hit
			end
			if target and hit.Instance:IsDescendantOf(target) then
				return true
			end
			if not ignored or not ignored(hit.Instance) then
				return false, hit
			end
			rayParams:AddToFilter(hit.Instance)
			hit = module.Raycast(lastPosition, direction, rayParams)
		end
		lastPosition = position
	end
	return true
end

local tracer = Instance.new('Part')
tracer.Anchored = true
tracer.CanCollide = false
tracer.CanQuery = false
tracer.CanTouch = false
tracer.CastShadow = false

local isZero = function(d)
	return (d > -eps and d < eps)
end
local cuberoot = function(x)
	return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
end
local solveQuadric = function(c0, c1, c2)
	local s0, s1
	if isZero(c0) then
		return not isZero(c1) and -c2 / c1 or nil
	end

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
local solveCubic = function(c0, c1, c2, c3)
	local s0, s1, s2
	if isZero(c0) then
		return solveQuadric(c1, c2, c3)
	end

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
		local phi = (1 / 3) * math.acos(math.clamp(-q / math.sqrt(-cb_p), -1, 1))
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
	if isZero(c0) then
		local root0, root1, root2 = solveCubic(c1, c2, c3, c4)
		local cubic = {}
		if root0 then table.insert(cubic, root0) end
		if root1 then table.insert(cubic, root1) end
		if root2 then table.insert(cubic, root2) end
		return cubic
	end

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

		s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
		num = (s0 and 1 or 0) + (s1 and 1 or 0) + (s2 and 1 or 0)
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

		s0, s1 = solveQuadric(coeffs[0], coeffs[1], coeffs[2])
		num = (s0 and 1 or 0) + (s1 and 1 or 0)

		coeffs[2] = z + u
		coeffs[1] = q < 0 and v or -v
		coeffs[0] = 1

		if (num == 0) then
			local root0, root1 = solveQuadric(coeffs[0], coeffs[1], coeffs[2])
			num = num + (root0 and 1 or 0) + (root1 and 1 or 0)
			s0, s1 = root0, root1
		end
		if (num == 1) then
			local root0, root1 = solveQuadric(coeffs[0], coeffs[1], coeffs[2])
			num = num + (root0 and 1 or 0) + (root1 and 1 or 0)
			s1, s2 = root0, root1
		end
		if (num == 2) then
			local root0, root1 = solveQuadric(coeffs[0], coeffs[1], coeffs[2])
			num = num + (root0 and 1 or 0) + (root1 and 1 or 0)
			s2, s3 = root0, root1
		end
	end

	sub = 0.25 * A

	local roots = {}
	if (num > 3) then table.insert(roots, s3 - sub) end
	if (num > 2) then table.insert(roots, s2 - sub) end
	if (num > 1) then table.insert(roots, s1 - sub) end
	if (num > 0) then table.insert(roots, s0 - sub) end

	return roots
end
module.SpawnTracer = function(from, to, custom)
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
module.SpawnArcTracer = function(origin, aimDirection, projectileSpeed, gravity, travelTime, steps, custom)
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
		if l then
			l.Parent = model
		end
		prevPos = nextPos
	end
	task.delay(custom.Lifetime, model.Destroy, model)
end
local validNumber = function(value)
	return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local horizontalMask = Vector3.new(1, 0, 1)
local targetMotion = setmetatable({}, {__mode = 'k'})
local validVector = function(value)
	return typeof(value) == 'Vector3'
		and validNumber(value.X)
		and validNumber(value.Y)
		and validNumber(value.Z)
end

local function getAttribute(root, attribute)
	local character = root and root.Parent
	if character and character:IsA('Model') then
		return character:GetAttribute(attribute)
	end
end

local function resetMotion(root, state, position, velocity, time, spawnTime)
	local knockbackMark = state.knockbackMark
	local knockbackMultiplier = state.knockbackMultiplier
	local jumpVelocity = state.jumpVelocity
	local jumpPeriod = state.jumpPeriod
	table.clear(state)
	state.jumpVelocity = jumpVelocity
	state.jumpPeriod = jumpPeriod
	state.assembly = velocity
	state.damageTime = getAttribute(root, 'LastDamageTakenTime')
	state.knockbackMark = knockbackMark
	state.knockbackMultiplier = knockbackMultiplier
	state.position = position
	state.samples = {{position = position, time = time}}
	state.spawnTime = spawnTime
	state.stableVelocity = velocity
	state.time = time
	state.velocity = velocity
	targetMotion[root] = state
	return state
end

function module.markKnockback(target, multiplier, impulse)
	if typeof(target) ~= 'Instance' then return end

	local root = target:IsA('BasePart') and target or target:IsA('Model') and target.PrimaryPart
	if not root then return end

	local state = targetMotion[root] or {}
	state.knockbackMark = workspace:GetServerTimeNow()
	state.knockbackMultiplier = multiplier
	--[[
		Waiting to see the velocity jump costs the frame the jump happens on, which is the frame
		the target moves furthest. A caller that knows the hit can hand over the impulse the server
		is about to apply, and the extrapolation starts from it rather than from a reading taken
		one frame into the knockback.
	]]
	if validVector(impulse) then
		local horizontal = impulse * horizontalMask
		state.knockbackHint = horizontal.Magnitude > eps and horizontal or nil
		state.knockbackHintTime = state.knockbackMark
	end
	state.expectedImpulse = nil
	state.expectedLift = nil
	state.expectedTime = nil
	targetMotion[root] = state
end

function module.expectKnockback(target, arrival, impulse, multiplier)
	if typeof(target) ~= 'Instance' then return end

	local root = target:IsA('BasePart') and target or target:IsA('Model') and target.PrimaryPart
	if not root or not validNumber(arrival) or not validVector(impulse) then return end

	local horizontal = impulse * horizontalMask
	if horizontal.Magnitude <= eps and math.abs(impulse.Y) <= eps then return end

	local state = targetMotion[root] or {}
	state.expectedImpulse = horizontal
	state.expectedLift = impulse.Y
	state.expectedTime = arrival
	state.expectedMultiplier = multiplier
	targetMotion[root] = state
end

local pendingShots = {}
local residualSpread, residualSamples = 0, 0
local epochHits, epochShots, epochRate = 0, 0, nil
local stepDirection, stepSize = 1, 0.008

--[[
	Comparing a prediction against the replicated position cannot measure how stale that position
	is, because both sides of the comparison are shifted by the same unknown: the difference works
	out to the lead we applied and nothing else, no matter what the real staleness is. Driving a
	bias off it would converge on leading by zero. Whether the shot landed is the only ground truth
	the client actually holds, so the bias is searched rather than solved: hold a step until a batch
	comes back worse than the one before it, then halve it and turn around.
]]
local function applyEpoch()
	if epochShots < 12 then return end

	local rate = epochHits / epochShots
	epochHits, epochShots = 0, 0
	if epochRate and rate + 0.02 < epochRate then
		stepDirection = -stepDirection
		stepSize = math.max(stepSize * 0.7, 0.002)
	end
	epochRate = rate
	--[[
		A batch that already lands everything carries no gradient to follow, and stepping anyway
		walks the bias off the middle of the window that produced it until it falls out the far
		side. Searching only resumes once something is actually being missed.
	]]
	if rate >= 0.95 then return end
	latencyBias = math.clamp(latencyBias + stepDirection * stepSize, -0.12, 0.12)
end

--[[
	The perpendicular half of the residual survives that problem, because a timing error can only
	displace a prediction along the direction of travel. What is left across it is the target having
	chosen to do something else, which is exactly the quantity the aim offset needs.
]]
local function measureSpread(shot)
	local root = shot.root
	if typeof(root) ~= 'Instance' or not root.Parent then return end

	local state = targetMotion[root]
	if not state or state.spawnTime ~= shot.spawnTime then return end
	if state.knockbackUntil and state.knockbackUntil > shot.fireTime then return end

	local residual = (root.Position - shot.impact) * horizontalMask
	if not validVector(residual) or residual.Magnitude > 30 then return end

	local cross = (residual - shot.direction * residual:Dot(shot.direction)).Magnitude
	residualSpread = residualSpread + (cross - residualSpread) * 0.2
	residualSamples = math.min(residualSamples + 1, 400)
end

local function resolveShots()
	if #pendingShots == 0 then return end
	local now = workspace:GetServerTimeNow()

	for index = #pendingShots, 1, -1 do
		local shot = pendingShots[index]
		if not shot.measured and now >= shot.dueTime then
			shot.measured = true
			measureSpread(shot)
		end
		if now > shot.dueTime + 0.35 then
			table.remove(pendingShots, index)
			epochShots += 1
			applyEpoch()
		end
	end
end

--[[
	SolveTrajectory runs every frame for aiming, so a solution only counts as a shot once a caller
	says it fired one.
]]
function module.trackShot(targetRoot)
	if typeof(targetRoot) ~= 'Instance' then return end

	local state = targetMotion[targetRoot]
	local solution = state and state.lastSolution
	if not solution or not validNumber(solution.travelTime) or not validVector(solution.impact) then return end

	local velocity = (state.velocity or Vector3.zero) * horizontalMask
	if velocity.Magnitude < 8 then return end

	if #pendingShots >= 24 then
		table.remove(pendingShots, 1)
	end
	table.insert(pendingShots, {
		direction = velocity.Unit,
		dueTime = solution.time + solution.travelTime,
		fireTime = solution.time,
		impact = solution.impact,
		root = targetRoot,
		spawnTime = state.spawnTime,
		speed = velocity.Magnitude
	})
end

function module.reportHit(targetRoot)
	if typeof(targetRoot) ~= 'Instance' then return end

	local now = workspace:GetServerTimeNow()
	for index = #pendingShots, 1, -1 do
		local shot = pendingShots[index]
		if shot.root == targetRoot and now >= shot.dueTime - 0.35 and now <= shot.dueTime + 0.35 then
			if not shot.measured then
				shot.measured = true
				measureSpread(shot)
			end
			table.remove(pendingShots, index)
			epochHits += 1
			epochShots += 1
			applyEpoch()
			return
		end
	end
end

function module.getResidualSpread()
	return residualSpread, residualSamples
end

function module.getLatencyBias()
	return latencyBias, epochRate
end

local worldFilter
local learnedParams = RaycastParams.new()
learnedParams.FilterType = Enum.RaycastFilterType.Include
local excludeParams = RaycastParams.new()
excludeParams.FilterType = Enum.RaycastFilterType.Exclude
excludeParams.IgnoreWater = true
excludeParams.RespectCanCollide = true
local excludeList, excludeTime = {}, 0

local castFloor = function(position, params)
	return module.Raycast(position, Vector3.new(0, workspace.FallenPartsDestroyHeight - position.Y, 0), params)
end

local function refreshExcludeList(root)
	local time = os.clock()
	if time - excludeTime > 1 then
		excludeTime = time
		table.clear(excludeList)
		for _, player in playersService:GetPlayers() do
			if player.Character then
				table.insert(excludeList, player.Character)
			end
		end
	end

	local character = root and root.Parent
	if character and not table.find(excludeList, character) then
		table.insert(excludeList, character)
	end
	return excludeList
end

local traceFloor = function(position, params, root)
	if params then
		local ray = castFloor(position, params)
		if ray then
			if params.FilterType == Enum.RaycastFilterType.Include then
				worldFilter = params.FilterDescendantsInstances
			end
			return ray.Position.Y
		end
	end

	if worldFilter and #worldFilter > 0 then
		learnedParams.FilterDescendantsInstances = worldFilter
		local ray = castFloor(position, learnedParams)
		if ray then
			return ray.Position.Y
		end
	end

	excludeParams.FilterDescendantsInstances = refreshExcludeList(root)
	local ray = castFloor(position, excludeParams)
	return ray and ray.Position.Y or nil
end

local getTargetMotion = function(root, position, velocity, airborne, playerGravity)
	if not root or not validVector(position) or not validVector(velocity) then
		return {
			acceleration = Vector3.zero,
			position = position,
			velocity = velocity
		}
	end

	local time = workspace:GetServerTimeNow()
	local spawnTime = getAttribute(root, 'SpawnTime')
	local state = targetMotion[root] or {}
	if state.time and time - state.time < 1 / 240 then
		local knockback = state.knockbackUntil and time < state.knockbackUntil
		return {
			acceleration = Vector3.zero,
			decay = state.knockbackDecay,
			flying = state.flying,
			impulse = knockback and state.knockbackImpulse,
			knockback = knockback,
			knockbackBase = knockback and state.knockbackBase,
			expectedImpulse = state.expectedImpulse,
			expectedLift = state.expectedLift,
			expectedTime = state.expectedTime,
			missRate = state.missRate,
			position = state.position,
			state = state,
			stale = state.updateInterval and math.clamp(state.updateInterval * 0.5, 0, 0.06) or nil,
		strafeElapsed = state.strafeReversal and time - state.strafeReversal or nil,
			strafeHalf = state.strafeHalf,
			strafeSeen = state.strafeSeen,
			strafeSpeed = state.strafeSpeed,
			strafeDirection = state.strafeDirection,
			turnRate = state.turnRate,
			turnSeen = state.turnSeen,
			velocity = state.velocity
		}
	end
	if not state.time or time - state.time > 0.75 or state.spawnTime ~= spawnTime then
		state = resetMotion(root, state, position, velocity, time, spawnTime)
		return {
			acceleration = Vector3.zero,
			position = position,
			state = state,
			velocity = velocity
		}
	end

	local delta = time - state.time
	if delta <= eps then
		return {
			acceleration = Vector3.zero,
			flying = state.flying,
			position = state.position,
			state = state,
			velocity = state.velocity
		}
	end
	local displacement = position - state.position
	local instantVelocity = displacement / delta
	local assemblyAgreement = velocity.Magnitude > 5
		and instantVelocity.Magnitude > 5
		and velocity.Unit:Dot(instantVelocity.Unit) > 0.75
		and math.abs(velocity.Magnitude - instantVelocity.Magnitude) < math.max(40, velocity.Magnitude * 0.75)
	if state.pendingPosition then
		if (position - state.position).Magnitude < 2 then
			state.pendingPosition = nil
			state.pendingTime = nil
		elseif (position - state.pendingPosition).Magnitude < 2 then
			state = resetMotion(root, state, position, velocity, time, spawnTime)
			return {
				acceleration = Vector3.zero,
				changed = true,
				position = position,
				state = state,
				velocity = velocity
			}
		else
			state.pendingPosition = nil
			state.pendingTime = nil
		end
	end

	local displacementLimit = math.max(12, (math.max(state.velocity.Magnitude, velocity.Magnitude) + 30) * delta * 1.5)
	if (displacement.Magnitude > displacementLimit or instantVelocity.Magnitude > 260) and not assemblyAgreement then
		state.pendingPosition = position
		state.pendingTime = time
		state.time = time
		return {
			acceleration = Vector3.zero,
			flying = state.flying,
			invalid = true,
			position = state.position,
			state = state,
			velocity = state.velocity
		}
	end

	local samples = state.samples
	table.insert(samples, {position = position, time = time})
	while #samples > 6 or (#samples > 2 and time - samples[1].time > 0.14) do
		table.remove(samples, 1)
	end

	local measuredVelocity
	local oldest = samples[1]
	if oldest and time - oldest.time > 0.02 then
		measuredVelocity = (position - oldest.position) / (time - oldest.time)
		if not validVector(measuredVelocity) or measuredVelocity.Magnitude > 260 then
			measuredVelocity = nil
		end
	end

	--[[
		The vertical fallback further down reads a stale value if it draws on the whole sample
		window: for a couple of frames after a landing that window still spans the fall, so a
		target resting on the floor reports tens of studs per second of phantom descent. The last
		sample pair is used there instead, since it cannot outlive the event that produced it.
	]]
	local recentVelocity
	local previousSample = samples[#samples - 1]
	if previousSample and time - previousSample.time > eps then
		recentVelocity = (position - previousSample.position) / (time - previousSample.time)
		if not validVector(recentVelocity) or recentVelocity.Magnitude > 260 then
			recentVelocity = nil
		end
	end

	local damageTime = getAttribute(root, 'LastDamageTakenTime')
	local damageChanged = validNumber(damageTime) and damageTime > 0 and damageTime ~= state.damageTime
	local marked = time - (state.knockbackMark or -math.huge) < 0.25
	local velocityChange = velocity - state.assembly
	local measuredAgreement = measuredVelocity
		and measuredVelocity.Magnitude > 5
		and velocity.Magnitude > 5
		and measuredVelocity.Unit:Dot(velocity.Unit) > 0.7
		and (measuredVelocity - velocity).Magnitude < math.max(35, velocity.Magnitude * 0.6)
	local velocityInvalid = (velocityChange.Magnitude > math.max(70, state.velocity.Magnitude * 2 + 35) or velocity.Magnitude > 260)
		and not marked
		and not damageChanged
		and not measuredAgreement
	if velocityInvalid then
		local candidate = state.velocityCandidate
		if candidate and time - state.velocityCandidateTime < 0.12 and (candidate - velocity).Magnitude < math.max(12, velocity.Magnitude * 0.2) then
			state.velocityCandidate = nil
			state.velocityCandidateTime = nil
		else
			state.velocityCandidate = velocity
			state.velocityCandidateTime = time
			velocity = state.assembly
		end
	else
		state.velocityCandidate = nil
		state.velocityCandidateTime = nil
	end

	local assemblyHorizontal = velocity * horizontalMask
	local measuredHorizontal = measuredVelocity and measuredVelocity * horizontalMask
	local horizontalVelocity = assemblyHorizontal
	local measuredAccepted
	if measuredHorizontal then
		local difference = (measuredHorizontal - assemblyHorizontal).Magnitude
		if difference < math.max(6, assemblyHorizontal.Magnitude * 0.35) then
			horizontalVelocity = assemblyHorizontal:Lerp(measuredHorizontal, 0.15)
			measuredAccepted = true
		elseif assemblyHorizontal.Magnitude < 2 and measuredHorizontal.Magnitude > 2 then
			local candidate = state.measuredCandidate
			local consistent = candidate
				and time - state.measuredCandidateTime < 0.15
				and candidate.Magnitude > eps
				and measuredHorizontal.Magnitude > eps
				and candidate.Unit:Dot(measuredHorizontal.Unit) > 0.8
				and math.abs(candidate.Magnitude - measuredHorizontal.Magnitude) < math.max(12, measuredHorizontal.Magnitude * 0.35)
			if measuredHorizontal.Magnitude < 45 or consistent then
				horizontalVelocity = measuredHorizontal
				measuredAccepted = true
				state.measuredCandidate = nil
				state.measuredCandidateTime = nil
			else
				state.measuredCandidate = measuredHorizontal
				state.measuredCandidateTime = time
				horizontalVelocity = state.velocity * horizontalMask
			end
		else
			state.measuredCandidate = nil
			state.measuredCandidateTime = nil
		end
	end

	local verticalVelocity = velocity.Y
	if measuredAccepted and measuredVelocity then
		if math.abs(verticalVelocity - measuredVelocity.Y) < 8 then
			verticalVelocity = verticalVelocity + (measuredVelocity.Y - verticalVelocity) * 0.15
		elseif recentVelocity and math.abs(verticalVelocity) < 1 and (state.flying or math.abs(recentVelocity.Y) < 45) then
			verticalVelocity = recentVelocity.Y
		end
	end
	if not airborne and math.abs(verticalVelocity) < 2 then
		verticalVelocity = 0
	end

	local combinedVelocity = Vector3.new(horizontalVelocity.X, verticalVelocity, horizontalVelocity.Z)
	local previousVelocity = state.velocity
	local difference = (combinedVelocity - previousVelocity).Magnitude
	local previousHorizontal = previousVelocity * horizontalMask
	local directionChanged = horizontalVelocity.Magnitude > 2
		and previousHorizontal.Magnitude > 2
		and horizontalVelocity.Unit:Dot(previousHorizontal.Unit) < 0.65
	--[[
		The blend ran at one fixed rate, so every change below the snap threshold trailed the
		target by the smoother's ~50ms time constant. Scaling the blend by how far the reading
		moved keeps steady movement as damped as it was while letting a sharp change converge
		within a frame. The term is squared so sensor noise, which sits near zero, stays damped.
	]]
	local shift = difference / math.max(previousVelocity.Magnitude * 0.35, 7)
	local changed = shift >= 1 or directionChanged
	local currentVelocity
	if changed then
		currentVelocity = combinedVelocity
	else
		local alpha = math.clamp(delta * 20, 0.2, 1)
		currentVelocity = previousVelocity:Lerp(combinedVelocity, alpha + (1 - alpha) * shift * shift)
	end

	--[[
		Knockback corroborated by a damage event or an explicit mark is treated as an impulse at
		a far lower magnitude than the uncorroborated PlatformStand case. Anything under the old
		bar was indistinguishable from player movement and got extrapolated flat for the whole
		flight, which is what made a small nudge miss by so much at range.
	]]
	local humanoid = root.Parent and root.Parent:FindFirstChildWhichIsA('Humanoid')
	local impulseChange = (currentVelocity - previousVelocity) * horizontalMask
	local knockbackStarted = (marked or damageChanged)
		and (impulseChange.Magnitude > 1.5 or math.abs(currentVelocity.Y - previousVelocity.Y) > 1.5)
	if not knockbackStarted and humanoid and humanoid.PlatformStand then
		knockbackStarted = impulseChange.Magnitude > 5 or math.abs(currentVelocity.Y - previousVelocity.Y) > 5
	end

	if state.expectedTime then
		if knockbackStarted or time > state.expectedTime + 0.35 then
			state.expectedImpulse, state.expectedTime, state.expectedMultiplier, state.expectedLift = nil, nil, nil, nil
		elseif time >= state.expectedTime then
			state.knockbackHint = state.expectedImpulse
			state.knockbackHintTime = time
			state.knockbackMark = time
			state.knockbackMultiplier = state.expectedMultiplier
			state.expectedImpulse, state.expectedTime, state.expectedMultiplier, state.expectedLift = nil, nil, nil, nil
		end
	end

	local hint = state.knockbackHint
	if hint and time - (state.knockbackHintTime or -math.huge) > 0.25 then
		hint, state.knockbackHint, state.knockbackHintTime = nil, nil, nil
	end
	if hint and not knockbackStarted and not state.knockbackUntil then
		knockbackStarted = true
	end
	if knockbackStarted then
		state.knockbackBase = state.stableVelocity * horizontalMask
		state.knockbackDecay = airborne and 1.8 or 3.5
		state.knockbackSeed = hint
		state.knockbackStart = time
		state.knockbackUntil = time + 0.6
	end

	local knockback = state.knockbackUntil and time < state.knockbackUntil
	local knockbackImpulse
	if knockback then
		knockbackImpulse = currentVelocity * horizontalMask - state.knockbackBase
		local seed = state.knockbackSeed
		if seed and time - state.knockbackStart < 0.12 and seed.Magnitude > knockbackImpulse.Magnitude then
			knockbackImpulse = seed
		end
		local previousImpulse = state.knockbackImpulse
		if previousImpulse
			and previousImpulse.Magnitude > 4
			and knockbackImpulse.Magnitude > 4
			and previousImpulse.Unit:Dot(knockbackImpulse.Unit) < 0.35
		then
			state.knockbackUntil = nil
			knockback = false
		end
		if previousImpulse
			and knockback
			and previousImpulse.Magnitude > 3
			and knockbackImpulse.Magnitude > 3
			and previousImpulse.Unit:Dot(knockbackImpulse.Unit) > 0.8
			and knockbackImpulse.Magnitude < previousImpulse.Magnitude
		then
			local decay = -math.log(knockbackImpulse.Magnitude / previousImpulse.Magnitude) / delta
			if validNumber(decay) and decay > 0 then
				state.knockbackDecay = state.knockbackDecay + (math.clamp(decay, 0.75, 8) - state.knockbackDecay) * 0.35
			end
		end
		if knockbackImpulse.Magnitude < 3 and time - state.knockbackStart > 0.1 then
			state.knockbackSeed = nil
			state.knockbackUntil = nil
			knockback = false
		else
			state.knockbackImpulse = knockbackImpulse
		end
	end

	if airborne then
		local verticalChange = (currentVelocity.Y - previousVelocity.Y) / delta
		if validNumber(verticalChange) then
			state.verticalAcceleration = state.verticalAcceleration
				and state.verticalAcceleration + (verticalChange - state.verticalAcceleration) * 0.25
				or verticalChange
		end
		state.airTime = (state.airTime or 0) + delta
		if state.airTime > 0.6 and state.verticalAcceleration and validNumber(playerGravity) and playerGravity > 0 then
			if state.verticalAcceleration > -playerGravity * 0.4 then
				local floorY = traceFloor(position, nil, root)
				state.flying = floorY and position.Y - floorY > 12 or false
			else
				state.flying = false
			end
		end
	else
		state.airTime = nil
		state.verticalAcceleration = nil
		state.flying = nil
	end

	if airborne and not state.airborne and currentVelocity.Y > 5 and not knockback then
		local takeoff = currentVelocity.Y
		local reference = state.jumpVelocity or takeoff
		if takeoff < reference * 1.5 and takeoff > reference * 0.5 then
			state.jumpVelocity = state.jumpVelocity and (state.jumpVelocity + (takeoff - state.jumpVelocity) * 0.35) or takeoff
			if state.jumpStart then
				local period = time - state.jumpStart
				local rise = state.jumpBase and state.position.Y - state.jumpBase
				if period > 0.15 and period < 1.5 then
					if state.jumpPeriod then
						local drift = math.abs(period - state.jumpPeriod) / state.jumpPeriod
						state.jumpDrift = state.jumpDrift and (state.jumpDrift + (drift - state.jumpDrift) * 0.35) or drift
					end
					state.jumpPeriod = state.jumpPeriod and (state.jumpPeriod + (period - state.jumpPeriod) * 0.35) or period
				end
				if period > 0.15 and period < 1.5 and rise and rise > 1 and rise < 8 then
					state.climbStep = state.climbStep and (state.climbStep + (rise - state.climbStep) * 0.35) or rise
					state.climbSeen = math.min((state.climbSeen or 0) + 1, 6)
				else
					state.climbStep, state.climbSeen = nil, nil
				end
			end
			state.jumpStart = time
			state.jumpBase = state.position.Y
		elseif not state.jumpVelocity then
			state.jumpVelocity = takeoff
			state.jumpStart = time
			state.jumpBase = state.position.Y
		end
	end
	state.airborne = airborne

	--[[
		A target holding one direction and a target strafing read identically for one frame, but
		leading the second one at full value is wrong as soon as the flight time approaches the
		time they spend on a side. Reversals are timed the way jumps already are, and only a target
		seen turning around more than once is treated as an oscillator, so a single dodge cannot
		start shortening the lead on someone running in a straight line.
	]]
	local strafeHorizontal = currentVelocity * horizontalMask
	if strafeHorizontal.Magnitude > 4 and not knockback then
		state.strafeSlow = nil
		state.strafeSpeed = state.strafeSpeed and (state.strafeSpeed + (strafeHorizontal.Magnitude - state.strafeSpeed) * 0.2) or strafeHorizontal.Magnitude
		local unit = strafeHorizontal.Unit
		local previous = state.strafeDirection
		if previous and unit:Dot(previous) < -0.5 then
			local last = state.strafeReversal
			if last then
				local half = time - last
				if half > 0.08 and half < 1.2 then
					state.strafeHalf = state.strafeHalf and (state.strafeHalf + (half - state.strafeHalf) * 0.35) or half
					state.strafeSeen = math.min((state.strafeSeen or 0) + 1, 6)
				end
			end
			state.strafeDirection = unit
			state.strafeReversal = time
		elseif not previous or unit:Dot(previous) > 0.5 then
			state.strafeDirection = unit
		end
	elseif strafeHorizontal.Magnitude < 1 then
		state.strafeSlow = state.strafeSlow or time
		if time - state.strafeSlow > 0.35 then
			state.strafeDirection = nil
		end
	end
	if state.strafeReversal and time - state.strafeReversal > 2.5 then
		state.strafeHalf, state.strafeReversal, state.strafeSeen, state.strafeSpeed = nil, nil, nil, nil
	end

	local previousTurn = state.turnUnit
	if strafeHorizontal.Magnitude > 5 and not knockback then
		local unit = strafeHorizontal.Unit
		if previousTurn and delta > eps then
			local cross = previousTurn.X * unit.Z - previousTurn.Z * unit.X
			local angle = math.atan2(cross, math.clamp(previousTurn:Dot(unit), -1, 1))
			if math.abs(angle) < 1.4 then
				local rate = angle / delta
				local settled = state.turnRate
				if settled and settled * rate > 0 and math.abs(rate) > 0.25 then
					state.turnSeen = math.min((state.turnSeen or 0) + 1, 12)
				elseif math.abs(rate) < 0.25 then
					state.turnSeen = math.max((state.turnSeen or 0) - 1, 0)
				else
					state.turnSeen = 0
				end
				state.turnRate = settled and settled + (rate - settled) * 0.3 or rate
			else
				state.turnRate, state.turnSeen = nil, 0
			end
		end
		state.turnUnit = unit
	else
		state.turnRate, state.turnSeen, state.turnUnit = nil, 0, nil
	end
	if state.strafeReversal and time - state.strafeReversal < delta * 1.5 then
		state.turnRate, state.turnSeen = nil, 0
	end

	--[[
		The trip is not the only thing a reading is behind by; it also waited however long since the
		sender last posted one, which averages half an update interval on top. The gap between
		readings that actually moved measures that per target rather than assuming everyone
		replicates as often as we sample, and it is only timed while the target is moving, since a
		stationary one stops producing updates to time.
	]]
	if strafeHorizontal.Magnitude > 4 then
		if displacement.Magnitude > eps then
			local last = state.updateTime
			if last then
				local gap = time - last
				if gap > eps and gap < 0.5 then
					state.updateInterval = state.updateInterval and (state.updateInterval + (gap - state.updateInterval) * 0.2) or gap
				end
			end
			state.updateTime = time
		end
	else
		state.updateInterval, state.updateTime = nil, nil
	end

	local pending = state.pending
	if pending then
		while pending[1] and pending[1].arrival <= time do
			local entry = table.remove(pending, 1)
			local miss = ((position - entry.position) * horizontalMask).Magnitude / entry.horizon
			if state.missRate then
				miss = math.min(miss, state.missRate * 1.5)
			end
			state.missRate = state.missRate and (state.missRate + (miss - state.missRate) * 0.3) or miss
		end
	end

	local acceleration = Vector3.zero
	if not knockback and horizontalVelocity.Magnitude > 1 then
		local change = (currentVelocity - previousVelocity) * horizontalMask / delta
		local parallel = change:Dot(horizontalVelocity.Unit)
		local perpendicular = (change - horizontalVelocity.Unit * parallel).Magnitude
		if parallel < -8 and perpendicular < math.abs(parallel) * 0.6 then
			acceleration = horizontalVelocity.Unit * math.max(parallel, -400)
		end
	end

	if not knockback then
		state.stableVelocity = currentVelocity
		state.knockbackImpulse = nil
	end
	state.assembly = velocity
	state.damageTime = damageTime
	state.position = position
	state.time = time
	state.velocity = currentVelocity
	return {
		acceleration = acceleration,
		changed = changed or knockbackStarted,
		decay = state.knockbackDecay,
		flying = state.flying,
		impulse = knockback and knockbackImpulse,
		knockback = knockback,
		knockbackBase = knockback and state.knockbackBase,
		expectedImpulse = state.expectedImpulse,
		expectedLift = state.expectedLift,
		expectedTime = state.expectedTime,
		missRate = state.missRate,
		position = position,
		state = state,
		stale = state.updateInterval and math.clamp(state.updateInterval * 0.5, 0, 0.06) or nil,
		strafeElapsed = state.strafeReversal and time - state.strafeReversal or nil,
		strafeHalf = state.strafeHalf,
		strafeSeen = state.strafeSeen,
		strafeSpeed = state.strafeSpeed,
		strafeDirection = state.strafeDirection,
		turnRate = state.turnRate,
		turnSeen = state.turnSeen,
		velocity = currentVelocity
	}
end

local gradeSpeed, gradeGravity, gradeInterval = 240, 35, 0.1

function module.Observe(root, position, velocity, airborne, playerGravity, origin, playerHeight, playerJump)
	if typeof(root) ~= 'Instance' then return end

	local motion = getTargetMotion(root, position, velocity, airborne, playerGravity)
	local state = motion.state
	if not state or not validVector(origin) then return end

	local now = workspace:GetServerTimeNow()
	if now - (state.gradeTime or -math.huge) < gradeInterval then return end

	module.SolveTrajectory(origin, gradeSpeed, gradeGravity, position, velocity, playerGravity, playerHeight, playerJump, nil, airborne, position, root, nil, true)
end

local solveMotionTime = function(origin, speed, projectileAcceleration, positionAtTime, minimum)
	local function evaluate(time)
		local offset = positionAtTime(time) - origin - projectileAcceleration * (0.5 * time * time)
		return offset:Dot(offset) - speed * speed * time * time
	end

	local low = minimum or 0
	local lowValue = evaluate(low)
	if not validNumber(lowValue) then return end
	local distance = (positionAtTime(low) - origin).Magnitude
	local start = low
	local maximum = math.min(math.max(distance / speed * 4 + 1, low + 2), 12)
	for i = 1, 72 do
		local alpha = i / 72
		local high = start + (maximum - start) * math.pow(alpha, 1.35)
		local highValue = evaluate(high)
		if not validNumber(highValue) then return end
		if math.abs(highValue) < math.max(1e-7, speed * speed * high * high * 1e-7) then
			return high
		end
		if (highValue > 0) ~= (lowValue > 0) then
			for _ = 1, 60 do
				local mid = (low + high) * 0.5
				if (evaluate(mid) > 0) == (lowValue > 0) then
					low = mid
				else
					high = mid
				end
			end
			return high
		end
		low = high
		lowValue = highValue
	end
end

local solveInterceptTime = function(disp, velocity, acceleration, speed, minimum)
	minimum = minimum or 0
	local halfAccel = acceleration * 0.5
	if halfAccel:Dot(halfAccel) < eps then
		local a = velocity:Dot(velocity) - speed * speed
		local b = 2 * velocity:Dot(disp)
		local c = disp:Dot(disp)
		if math.abs(a) < eps then
			local time = math.abs(b) > eps and -c / b or nil
			return time and time > math.max(eps, minimum) and time or nil
		end

		local discriminant = b * b - 4 * a * c
		local tolerance = eps * (b * b + math.abs(4 * a * c) + 1)
		if discriminant < -tolerance then
			return
		end

		local root = math.sqrt(math.max(discriminant, 0))
		local q = -0.5 * (b + (b >= 0 and root or -root))
		local first = q / a
		local second = math.abs(q) > eps and c / q or nil
		first = first and first > math.max(eps, minimum) and first or nil
		second = second and second > math.max(eps, minimum) and second or nil
		if first and second then
			return math.min(first, second)
		end
		return first or second
	end

	local c4 = halfAccel:Dot(halfAccel)
	local c3 = 2 * halfAccel:Dot(velocity)
	local c2 = 2 * halfAccel:Dot(disp) + velocity:Dot(velocity) - speed * speed
	local c1 = 2 * velocity:Dot(disp)
	local c0 = disp:Dot(disp)
	local root0, root1, root2 = solveCubic(4 * c4, 3 * c3, 2 * c2, c1)
	local critical = {}
	if validNumber(root0) and root0 > minimum then table.insert(critical, root0) end
	if validNumber(root1) and root1 > minimum then table.insert(critical, root1) end
	if validNumber(root2) and root2 > minimum then table.insert(critical, root2) end
	table.sort(critical)

	local function evaluate(time)
		return ((((c4 * time + c3) * time + c2) * time + c1) * time + c0)
	end

	local function tolerance(time)
		return math.max(1e-7, speed * speed * time * time * 1e-7)
	end

	local function bisect(low, high, lowValue)
		for _ = 1, 60 do
			local mid = (low + high) * 0.5
			local value = evaluate(mid)
			if (value > 0) == (lowValue > 0) then
				low = mid
				lowValue = value
			else
				high = mid
			end
		end
		return high
	end

	local previous = minimum
	local previousValue = evaluate(previous)
	for _, time in critical do
		local value = evaluate(time)
		if previousValue * value < 0 then
			return bisect(previous, time, previousValue)
		end
		if math.abs(value) <= tolerance(time) then
			return time
		end
		previous = time
		previousValue = value
	end

	if previousValue < 0 then
		local high = math.max(previous * 2, previous + 1)
		local highValue = evaluate(high)
		while highValue < 0 do
			high *= 2
			highValue = evaluate(high)
		end
		return bisect(previous, high, previousValue)
	end
	return
end

--[[
	Returns the time until the target reaches floorY, or nil with a grounded flag when it is
	already resting on it. Solves 0.5 * g * t^2 - vY * t - height = 0 for the positive root.
]]
--[[
	Elapsed time an oscillator spends heading one way and then the other, signed against its current
	heading, so multiplying by the present velocity gives displacement rather than distance.
]]
local strafeDisplacement = function(elapsed, remaining, half)
	local travelled, sign, cursor, segment = 0, 1, 0, remaining
	for _ = 1, 16 do
		local step = math.min(elapsed - cursor, segment)
		if step <= 0 then break end
		travelled += sign * step
		cursor += step
		sign, segment = -sign, half
	end
	return travelled
end

local solveLandingTime = function(startY, floorY, verticalVelocity, playerGravity)
	local height = startY - floorY
	if height <= eps and verticalVelocity <= 0 then
		return nil, true
	end

	local discriminant = verticalVelocity * verticalVelocity + 2 * playerGravity * height
	if discriminant < 0 then
		return nil
	end

	local landing = (verticalVelocity + math.sqrt(discriminant)) / playerGravity
	return validNumber(landing) and landing > eps and landing or nil
end

--[[
	Only a target already seen chaining jumps is extrapolated into another one. Height cannot go
	below the floor, so blending an unproven hop toward its mean can only ever aim high, which
	measured as a consistent 0.9 stud upward bias against a target that was simply standing there.
	Without an observed period the honest guess is that they stay where they landed.
]]
local jumpHeightAt = function(groundY, jumpVelocity, playerGravity, elapsed, jumpPeriod, uncertainty, climb)
	if not jumpPeriod then
		return groundY
	end

	local rise = climb or 0
	local airTime = climb and (jumpVelocity + math.sqrt(math.max(jumpVelocity * jumpVelocity - 2 * playerGravity * climb, 0))) / playerGravity or 2 * jumpVelocity / playerGravity
	local period = math.max(jumpPeriod, airTime)
	local cycles = math.floor(elapsed / period)
	local phase = elapsed - cycles * period
	local height = rise * cycles
	if phase < airTime then
		height += jumpVelocity * phase - playerGravity * (0.5 * phase * phase)
	else
		height += rise
	end

	local blend = math.clamp((elapsed / period) * 0.5 + (uncertainty or 0), 0, 0.8)
	if blend > 0 then
		local mean
		if climb then
			mean = (jumpVelocity * airTime * airTime * 0.5 - playerGravity * airTime * airTime * airTime / 6 + climb * (period - airTime)) / period + climb * (elapsed / period - 0.5)
		else
			local apex = jumpVelocity * jumpVelocity / (2 * playerGravity)
			mean = (2 / 3) * apex * (airTime / period)
		end
		height += (mean - height) * blend
	end
	return groundY + height
end

local function solveStaticLaunch(origin, target, speed, acceleration)
	local delta = target - origin
	if speed <= eps then return end

	local pull = -acceleration.Y
	if math.abs(pull) <= eps then
		local distance = delta.Magnitude
		if distance <= eps then return end
		local time = distance / speed
		return delta / time, time
	end

	local a = 0.25 * pull * pull
	local b = (pull * delta.Y) - (speed * speed)
	local c = delta:Dot(delta)
	local discriminant = (b * b) - (4 * a * c)
	if discriminant < 0 then return end

	local root = math.sqrt(discriminant)
	local first, second = (-b - root) / (2 * a), (-b + root) / (2 * a)
	local squared = first > eps and first or (second > eps and second or nil)
	if not squared then return end

	local time = math.sqrt(squared)
	if not validNumber(time) or time <= eps then return end

	local velocity = (delta + Vector3.new(0, 0.5 * pull * time * time, 0)) / time
	if not validVector(velocity) then return end

	return velocity, time
end

module.SolveTrajectory = function(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params, targetAirborne, targetRootPosition, targetRoot, minimumTime, strict)
	resolveShots()
	targetVelocity = targetVelocity or Vector3.zero
	projectileSpeed = tonumber(projectileSpeed) or 0
	gravity = tonumber(gravity) or 0
	playerGravity = tonumber(playerGravity) or 0
	playerHeight = tonumber(playerHeight) or 0
	if typeof(targetRootPosition) == 'Instance' and targetRootPosition:IsA('BasePart') then
		targetRoot = targetRootPosition
		targetRootPosition = targetRoot.Position
	end
	if not validVector(origin)
		or not validVector(targetPos)
		or not validVector(targetVelocity)
		or not validNumber(projectileSpeed)
		or projectileSpeed <= eps
		or not validNumber(gravity)
		or not validNumber(playerGravity)
		or not validNumber(playerHeight)
	then
		local state = targetRoot and targetMotion[targetRoot]
		local lastSolution = state and state.lastSolution
		local currentPosition = typeof(targetRoot) == 'Instance' and targetRoot:IsA('BasePart') and targetRoot.Position
		if lastSolution
			and validVector(origin)
			and validVector(currentPosition)
			and workspace:GetServerTimeNow() - lastSolution.time < 0.08
			and math.abs(lastSolution.projectileSpeed - projectileSpeed) < 0.01
			and math.abs(lastSolution.gravity - gravity) < 0.01
			and (lastSolution.origin - origin).Magnitude < 4
			and (lastSolution.targetPosition - currentPosition).Magnitude < 6
		then
			return origin + lastSolution.velocity, lastSolution.impact, lastSolution.travelTime
		end
		if strict then return nil end
		return targetPos, targetPos
	end
	if not validVector(targetRootPosition) then
		targetRootPosition = targetPos
	end
	local targetOffset = targetPos - targetRootPosition
	if type(targetAirborne) ~= 'boolean' then
		targetAirborne = nil
	end
	if targetAirborne == nil then
		targetAirborne = math.abs(targetVelocity.Y) > 0.01
	end

	local motion = getTargetMotion(targetRoot, targetRootPosition, targetVelocity, targetAirborne, playerGravity)
	targetRootPosition = motion.position
	targetPos = targetRootPosition + targetOffset
	targetVelocity = motion.velocity
	local solutionTargetPosition = targetRootPosition
	--[[
		Cross-track residual is the target having done something other than what was extrapolated,
		and turning costs along-track progress as well as pushing sideways, so the point covering
		both outcomes sits a little behind the full lead rather than on it. The size is taken from
		the measured spread and stays at zero until enough shots have been graded, so this can never
		move the aim on a guess.
	]]
	if residualSamples >= 8 then
		local lead = targetVelocity * horizontalMask
		if lead.Magnitude > 6 then
			targetPos -= lead.Unit * math.clamp(residualSpread * 0.5, 0, 2)
		end
	end
	--[[
		Every solution is kept and graded against where the target actually was when the projectile
		would have arrived, giving a per-target measure of how much of its movement this model fails
		to explain, in studs per second so it compares directly against the target's own speed. A
		target the model reads correctly scores near zero no matter how fast or how curved its path
		is, so nothing here touches it; one whose miss rivals its speed has movement that carries no
		information, and leading it the full amount measured worse than not leading at all. Knockback
		is exempt because its own branch already beats both. Vertical is never damped, since gravity
		is not a guess.
	]]
	local leadConfidence = 1
	local missRate = motion.missRate
	if missRate and missRate > eps and not motion.knockback then
		local speed = (targetVelocity * horizontalMask).Magnitude
		if speed > eps then
			leadConfidence = (speed * speed) / (speed * speed + missRate * missRate)
		end
	end
	--[[
		A caller reading FloorMaterial can report a target as grounded on the frame it leaves the
		floor, and a target flagged that way used to fall with no gravity and no landing solve at
		all. Meaningful downward velocity is treated as airborne regardless of the passed flag;
		getTargetMotion already zeroes vertical velocity under 2 for genuinely grounded targets,
		so this cannot latch on to a standing player.
	]]
	local targetAcceleration = Vector3.zero
	if playerGravity > 0 and (targetAirborne or targetVelocity.Y < -1) and not motion.flying then
		targetAcceleration = Vector3.new(0, -playerGravity, 0)
	end
	local horizontalAcceleration = motion.acceleration
	local horizontalVelocity = targetVelocity * horizontalMask
	local stopTime
	if horizontalAcceleration.Magnitude > eps and horizontalVelocity.Magnitude > eps then
		local slowdown = horizontalAcceleration:Dot(horizontalVelocity.Unit)
		stopTime = math.abs(slowdown) > eps and -horizontalVelocity.Magnitude / slowdown or nil
		if not validNumber(stopTime) or stopTime <= eps or stopTime > 0.35 then
			horizontalAcceleration = Vector3.zero
			stopTime = nil
		end
	end

	--[[
		Past the moment a proven oscillator turns around, further lead does not merely get less
		certain, it points the wrong way. Clamping the lead there is not enough either, since the
		target does not stop, it comes back; the displacement is folded out of the learned half
		period so the aim tracks the fold rather than freezing at it.
	]]
	local strafeHalf, strafeRemaining, strafeVelocity
	if motion.strafeHalf and (motion.strafeSeen or 0) >= 2 then
		if horizontalVelocity.Magnitude > 4 then
			strafeHalf, strafeVelocity = motion.strafeHalf, horizontalVelocity
		elseif motion.strafeDirection and (motion.strafeSpeed or 0) > 4 then
			strafeHalf, strafeVelocity = motion.strafeHalf, motion.strafeDirection * motion.strafeSpeed
		end
		if strafeHalf then
			strafeRemaining = math.clamp(strafeHalf - (motion.strafeElapsed or 0), 0, strafeHalf)
		end
	end

	local turnRate
	if not strafeHalf
		and (motion.turnSeen or 0) >= 4
		and validNumber(motion.turnRate)
		and horizontalVelocity.Magnitude > 5
		and horizontalAcceleration.Magnitude <= eps
	then
		turnRate = math.clamp(motion.turnRate, -5, 5)
		if math.abs(turnRate) < 0.25 then
			turnRate = nil
		end
	end

	local jumpVelocity, jumpPeriod, jumpDrift, climbStep
	if validNumber(playerJump) and playerJump > 0 and playerGravity > 0 and not motion.flying then
		jumpVelocity = playerJump
		local observed = motion.state and motion.state.jumpVelocity
		if validNumber(observed) and observed > 0 then
			jumpVelocity = math.clamp(observed, playerJump * 0.6, playerJump * 1.6)
		end
		local period = motion.state and motion.state.jumpPeriod
		if validNumber(period) and period > 0 then
			jumpPeriod = period
		end
		local drift = motion.state and motion.state.jumpDrift
		jumpDrift = validNumber(drift) and math.clamp(drift, 0, 0.8) or 0.2
		local climb = motion.state and motion.state.climbStep
		if jumpPeriod
			and validNumber(climb)
			and (motion.state.climbSeen or 0) >= 2
			and climb < jumpVelocity * jumpVelocity / (2 * playerGravity)
			and workspace:GetServerTimeNow() - (motion.state.jumpStart or -math.huge) < jumpPeriod * 2
		then
			climbStep = climb
		end
	end

	local groundY, landingTime, floorLimit
	if playerHeight > 0 then
		local floorY = traceFloor(targetRootPosition, params, targetRoot)
		if floorY then
			floorLimit = floorY + playerHeight + targetOffset.Y
		end
		if floorY and (targetAcceleration.Y < 0 or jumpVelocity) and not motion.flying then
			local landing, grounded = solveLandingTime(targetRootPosition.Y, floorY + playerHeight, targetVelocity.Y, playerGravity)
			local horizontal = targetVelocity * horizontalMask
			if landing and horizontal.Magnitude * landing > 2 then
				local settled
				for i = 1, 4 do
					local sampleTime = landing * (i / 4)
					local sampleFloor = traceFloor(targetRootPosition + horizontal * sampleTime, params, targetRoot)
					if sampleFloor then
						local height = targetRootPosition.Y + targetVelocity.Y * sampleTime - playerGravity * (0.5 * sampleTime * sampleTime)
						if height <= sampleFloor + playerHeight then
							local solved = solveLandingTime(targetRootPosition.Y, sampleFloor + playerHeight, targetVelocity.Y, playerGravity)
							if solved then
								floorY = sampleFloor
								landing = solved
								settled = true
								break
							end
						end
					end
				end

				if not settled then
					local drifted = traceFloor(targetRootPosition + horizontal * landing, params, targetRoot)
					if drifted and math.abs(drifted - floorY) > eps then
						floorY = drifted
						landing, grounded = solveLandingTime(targetRootPosition.Y, floorY + playerHeight, targetVelocity.Y, playerGravity)
					end
				end
			end

			if climbStep and targetAirborne and motion.state.jumpBase then
				local raised = motion.state.jumpBase + climbStep - playerHeight
				local rising = math.max(targetVelocity.Y, 0)
				if floorY < raised - climbStep * 0.5 and targetRootPosition.Y + rising * rising / (2 * playerGravity) >= raised + playerHeight then
					floorY = raised
					landing, grounded = solveLandingTime(targetRootPosition.Y, floorY + playerHeight, targetVelocity.Y, playerGravity)
				end
			end

			if grounded then
				targetRootPosition = Vector3.new(targetRootPosition.X, floorY + playerHeight, targetRootPosition.Z)
				targetPos = targetRootPosition + targetOffset
				targetVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)
				targetAcceleration = Vector3.zero
				if jumpVelocity then
					groundY = floorY + playerHeight + targetOffset.Y
					landingTime = 0
				end
			else
				groundY = floorY + playerHeight + targetOffset.Y
				landingTime = landing
			end
		end
	end

	local latency = module.getLatency() + (motion.stale or 0)
	local projectileAcceleration = Vector3.new(0, -gravity, 0)
	local positionAtTime
	local time
	if motion.knockback and motion.impulse and motion.knockbackBase then
		local basePosition = targetPos
		local baseVelocity = motion.knockbackBase
		local impulse = motion.impulse
		local decay = math.max(motion.decay or 1.8, eps)
		positionAtTime = function(value)
			local total = latency + value
			local horizontalOffset = baseVelocity * total + impulse * ((1 - math.exp(-decay * total)) / decay)
			local vertical = landingTime and total >= landingTime
				and groundY
				or basePosition.Y + targetVelocity.Y * total + targetAcceleration.Y * (0.5 * total * total)
			return Vector3.new(basePosition.X + horizontalOffset.X, vertical, basePosition.Z + horizontalOffset.Z)
		end
		time = solveMotionTime(origin, projectileSpeed, projectileAcceleration, positionAtTime, minimumTime)
	elseif motion.expectedImpulse and motion.expectedTime then
		local basePosition = targetPos
		local baseVelocity = horizontalVelocity
		local impulse = motion.expectedImpulse
		local decay = math.max(motion.decay or (targetAirborne and 1.8 or 3.5), eps)
		local delay = math.max(motion.expectedTime - workspace:GetServerTimeNow(), 0) + latency
		local lift = validNumber(motion.expectedLift) and motion.expectedLift > eps and motion.expectedLift or nil
		positionAtTime = function(value)
			local total = latency + value
			local horizontalOffset = baseVelocity * total
			if total > delay then
				local since = total - delay
				horizontalOffset += impulse * ((1 - math.exp(-decay * since)) / decay)
			end
			local vertical = landingTime and total >= landingTime
				and groundY
				or basePosition.Y + targetVelocity.Y * total + targetAcceleration.Y * (0.5 * total * total)
			if lift and total > delay then
				local since = total - delay
				vertical += math.max(lift * since - playerGravity * (0.5 * since * since), 0)
			end
			return Vector3.new(basePosition.X + horizontalOffset.X, vertical, basePosition.Z + horizontalOffset.Z)
		end
		time = solveMotionTime(origin, projectileSpeed, projectileAcceleration, positionAtTime, minimumTime)
	elseif strafeHalf then
		local basePosition = targetPos
		local baseVertical = targetVelocity.Y
		local horizontal = strafeVelocity
		local half, remaining = strafeHalf, strafeRemaining
		positionAtTime = function(value)
			local total = latency + value
			local offset = horizontal * strafeDisplacement(total, remaining, half)
			local vertical
			if jumpVelocity and landingTime and groundY and total >= landingTime then
				vertical = jumpHeightAt(groundY, jumpVelocity, playerGravity, total - landingTime, jumpPeriod, jumpDrift, climbStep)
			elseif landingTime and groundY and total >= landingTime then
				vertical = groundY
			else
				vertical = basePosition.Y + baseVertical * total + targetAcceleration.Y * (0.5 * total * total)
			end
			return Vector3.new(basePosition.X + offset.X, vertical, basePosition.Z + offset.Z)
		end
		time = solveMotionTime(origin, projectileSpeed, projectileAcceleration, positionAtTime, minimumTime)
	elseif turnRate then
		local basePosition = targetPos
		local baseVertical = targetVelocity.Y
		local speedAlong = horizontalVelocity.Magnitude
		local unit = horizontalVelocity.Unit
		local normal = Vector3.new(-unit.Z, 0, unit.X)
		local radius = speedAlong / turnRate
		local sweepLimit = math.min(2.6 / math.abs(turnRate), 0.1 * (motion.turnSeen or 4))
		positionAtTime = function(value)
			local total = latency + value
			local swept = math.min(total, sweepLimit) * turnRate
			local offset = unit * (radius * math.sin(swept)) + normal * (radius * (1 - math.cos(swept)))
			if total > sweepLimit then
				local heading = unit * math.cos(swept) + normal * math.sin(swept)
				offset += heading * (speedAlong * (total - sweepLimit))
			end
			local vertical
			if jumpVelocity and landingTime and groundY and total >= landingTime then
				vertical = jumpHeightAt(groundY, jumpVelocity, playerGravity, total - landingTime, jumpPeriod, jumpDrift, climbStep)
			elseif landingTime and groundY and total >= landingTime then
				vertical = groundY
			else
				vertical = basePosition.Y + baseVertical * total + targetAcceleration.Y * (0.5 * total * total)
			end
			return Vector3.new(basePosition.X + offset.X, vertical, basePosition.Z + offset.Z)
		end
		time = solveMotionTime(origin, projectileSpeed, projectileAcceleration, positionAtTime, minimumTime)
	elseif jumpVelocity and landingTime and groundY then
		local basePosition = targetPos
		local baseVertical = targetVelocity.Y
		local baseLanding = landingTime
		local horizontal = horizontalVelocity
		local horizontalAccel = horizontalAcceleration
		local stop = stopTime
		positionAtTime = function(value)
			local total = latency + value
			local horizontalTime = stop and math.min(total, stop) or total
			local offset = horizontal * horizontalTime + horizontalAccel * (0.5 * horizontalTime * horizontalTime)
			local vertical = total >= baseLanding
				and jumpHeightAt(groundY, jumpVelocity, playerGravity, total - baseLanding, jumpPeriod, jumpDrift, climbStep)
				or basePosition.Y + baseVertical * total - playerGravity * (0.5 * total * total)
			return Vector3.new(basePosition.X + offset.X, vertical, basePosition.Z + offset.Z)
		end
		time = solveMotionTime(origin, projectileSpeed, projectileAcceleration, positionAtTime, minimumTime)
	else
		if latency > eps then
			local horizontalTime = stopTime and math.min(latency, stopTime) or latency
			local horizontalOffset = horizontalVelocity * horizontalTime + horizontalAcceleration * (0.5 * horizontalTime * horizontalTime)
			targetRootPosition += horizontalOffset
			targetPos += horizontalOffset
			if stopTime and latency >= stopTime then
				targetVelocity = Vector3.new(0, targetVelocity.Y, 0)
				horizontalVelocity = Vector3.zero
				horizontalAcceleration = Vector3.zero
				stopTime = nil
			else
				horizontalVelocity += horizontalAcceleration * latency
				targetVelocity = Vector3.new(horizontalVelocity.X, targetVelocity.Y, horizontalVelocity.Z)
				if stopTime then
					stopTime -= latency
				end
			end

			if landingTime and latency >= landingTime then
				targetPos = Vector3.new(targetPos.X, groundY, targetPos.Z)
				targetVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)
				targetAcceleration = Vector3.zero
				landingTime = nil
			else
				local verticalOffset = Vector3.new(0, targetVelocity.Y * latency + targetAcceleration.Y * (0.5 * latency * latency), 0)
				targetRootPosition += verticalOffset
				targetPos += verticalOffset
				targetVelocity += Vector3.new(0, targetAcceleration.Y * latency, 0)
				if landingTime then
					landingTime -= latency
				end
			end
		end

		local disp = targetPos - origin
		if disp:Dot(disp) <= eps then
			return targetPos, targetPos, 0
		end

		local relativeAcceleration = targetAcceleration - projectileAcceleration
		if stopTime then
			positionAtTime = function(value)
				local horizontalTime = math.min(value, stopTime)
				local horizontalOffset = horizontalVelocity * horizontalTime + horizontalAcceleration * (0.5 * horizontalTime * horizontalTime)
				local vertical = landingTime and value >= landingTime
					and groundY
					or targetPos.Y + targetVelocity.Y * value + targetAcceleration.Y * (0.5 * value * value)
				return Vector3.new(targetPos.X + horizontalOffset.X, vertical, targetPos.Z + horizontalOffset.Z)
			end
			time = solveMotionTime(origin, projectileSpeed, projectileAcceleration, positionAtTime, minimumTime)
		else
			time = solveInterceptTime(disp, targetVelocity, relativeAcceleration, projectileSpeed, minimumTime)
		end
		if not positionAtTime and landingTime and (not time or time > landingTime) then
			local landedPosition = Vector3.new(targetPos.X, groundY, targetPos.Z)
			local landedVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)
			time = solveInterceptTime(landedPosition - origin, landedVelocity, -projectileAcceleration, projectileSpeed, math.max(landingTime, minimumTime or 0))
		end
	end

	if time and validNumber(time) and time > eps then
		local futureTarget
		if positionAtTime then
			futureTarget = positionAtTime(time)
		elseif landingTime and time > landingTime then
			futureTarget = Vector3.new(
				targetPos.X + targetVelocity.X * time,
				groundY,
				targetPos.Z + targetVelocity.Z * time
			)
		else
			futureTarget = targetPos + targetVelocity * time + targetAcceleration * (0.5 * time * time)
		end
		if floorLimit and validVector(futureTarget) and futureTarget.Y < floorLimit then
			futureTarget = Vector3.new(futureTarget.X, floorLimit, futureTarget.Z)
		end
		local launchVelocity = (futureTarget - origin - projectileAcceleration * (0.5 * time * time)) / time

		local confidence = leadConfidence
		if confidence < 1 and validVector(futureTarget) then
			local present = positionAtTime and positionAtTime(0) or targetPos
			if not validVector(present) then
				present = targetPos
			end
			local damped = Vector3.new(
				present.X + (futureTarget.X - present.X) * confidence,
				futureTarget.Y,
				present.Z + (futureTarget.Z - present.Z) * confidence
			)
			local dampedVelocity, dampedTime = solveStaticLaunch(origin, damped, projectileSpeed, projectileAcceleration)
			if dampedVelocity and dampedTime then
				futureTarget, launchVelocity, time = damped, dampedVelocity, dampedTime
			end
		end
		if validVector(futureTarget)
			and validVector(launchVelocity)
			and math.abs(launchVelocity.Magnitude - projectileSpeed) < math.max(0.05, projectileSpeed * 0.002)
		then
			local state = motion.state
			if state then
				local now = workspace:GetServerTimeNow()
				state.lastSolution = {
					gravity = gravity,
					impact = futureTarget,
					origin = origin,
					projectileSpeed = projectileSpeed,
					targetPosition = solutionTargetPosition,
					time = now,
					travelTime = time,
					velocity = launchVelocity
				}
				if now - (state.gradeTime or -math.huge) >= 0.1 then
					state.gradeTime = now
					state.pending = state.pending or {}
					if #state.pending >= 16 then
						table.remove(state.pending, 1)
					end
					table.insert(state.pending, {
						arrival = now + time + latency,
						horizon = time + latency,
						position = futureTarget - targetOffset
					})
				end
			end
			return origin + launchVelocity, futureTarget, time
		end
	end

	local lastSolution = motion.state and motion.state.lastSolution
	if lastSolution
		and not motion.changed
		and not motion.knockback
		and workspace:GetServerTimeNow() - lastSolution.time < 0.08
		and math.abs(lastSolution.projectileSpeed - projectileSpeed) < 0.01
		and math.abs(lastSolution.gravity - gravity) < 0.01
		and (lastSolution.origin - origin).Magnitude < 4
		and (lastSolution.targetPosition - solutionTargetPosition).Magnitude < 6
	then
		return origin + lastSolution.velocity, lastSolution.impact, lastSolution.travelTime
	end

	if strict then
		return nil
	end
	return targetPos, targetPos
end
-------------------------------------------------------------------------------
-- Aim preview / intercept solving
-------------------------------------------------------------------------------
-- Restored after a sync dropped them: ProjectileLanding traces held and live
-- projectiles with TraceTrajectory, and the BedWars base solves Telepearl and other
-- straight-line throws with SolveIntercept. Each keeps its own helpers so it cannot
-- drift when the motion model above changes.

local function finiteScalar(value)
	return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function finiteNumber(value)
	return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function finiteVector(value)
	return typeof(value) == 'Vector3'
		and finiteNumber(value.X)
		and finiteNumber(value.Y)
		and finiteNumber(value.Z)
end

-- Deterministically advances a projectile through its exact kinematic curve and tests every
-- chord against the world.  Callers supply acceleration as a world-space vector so this also
-- works for projectiles whose gravity is not the Workspace default.  The bounded step count is
-- important for previews: a stale projectile with a very long lifetime must never turn into an
-- unbounded render-thread raycast loop.
function module.TraceTrajectory(origin, initialVelocity, acceleration, raycastParams, lifetime, options)
	options = type(options) == 'table' and options or {}
	if not finiteVector(origin) or not finiteVector(initialVelocity) or not finiteVector(acceleration) then return nil end
	lifetime = tonumber(lifetime) or 5
	if not finiteNumber(lifetime) or lifetime <= 0 then return nil end
	lifetime = math.min(lifetime, tonumber(options.MaximumLifetime) or 10)

	local segmentLength = math.max(tonumber(options.SegmentLength) or 1.25, 0.1)
	local minimumStep = math.max(tonumber(options.MinimumStep) or (1 / 240), 1 / 1000)
	local maximumStep = math.max(tonumber(options.MaximumStep) or (1 / 30), minimumStep)
	local maximumSteps = math.max(math.floor(tonumber(options.MaximumSteps) or 720), 1)
	local radius = math.max(tonumber(options.Radius) or 0, 0)
	local collisionTest = type(options.CollisionTest) == 'function' and options.CollisionTest or nil

	local function positionAt(time)
		return origin + initialVelocity * time + acceleration * (0.5 * time * time)
	end

	local time, previous = 0, origin
	for _ = 1, maximumSteps do
		if time >= lifetime then break end
		local instantaneousSpeed = (initialVelocity + acceleration * time).Magnitude
		local step = math.clamp(segmentLength / math.max(instantaneousSpeed, 1), minimumStep, maximumStep)
		local nextTime = math.min(time + step, lifetime)
		local nextPosition = positionAt(nextTime)
		local displacement = nextPosition - previous
		local customPosition, customInstance
		if collisionTest then
			local ok, hitPosition, hitInstance = pcall(collisionTest, previous, nextPosition, time, nextTime)
			if ok and finiteVector(hitPosition) then
				customPosition, customInstance = hitPosition, hitInstance
			end
		end

		local worldResult
		if displacement.Magnitude > eps then
			if radius > 0 and workspace.Spherecast then
				local ok, result = pcall(workspace.Spherecast, workspace, previous, radius, displacement, raycastParams)
				if ok then worldResult = result end
			end
			if not worldResult then
				local ok, result = pcall(workspace.Raycast, workspace, previous, displacement, raycastParams)
				if ok then worldResult = result end
			end
		end

		if customPosition or worldResult then
			local worldPosition = worldResult and worldResult.Position
			local useCustom = customPosition and (not worldPosition
				or (customPosition - previous).Magnitude <= (worldPosition - previous).Magnitude)
			local hitPosition = useCustom and customPosition or worldPosition
			local alpha = displacement.Magnitude > eps
				and math.clamp((hitPosition - previous).Magnitude / displacement.Magnitude, 0, 1)
				or 0
			return {
				Position = hitPosition,
				Instance = useCustom and customInstance or worldResult.Instance,
				Normal = not useCustom and worldResult.Normal or nil,
				Material = not useCustom and worldResult.Material or nil,
				Time = time + (nextTime - time) * alpha,
				Velocity = initialVelocity + acceleration * (time + (nextTime - time) * alpha),
				RaycastResult = not useCustom and worldResult or nil,
				Expired = false
			}
		end

		time, previous = nextTime, nextPosition
	end

	return {
		Position = positionAt(lifetime),
		Instance = nil,
		Time = lifetime,
		Velocity = initialVelocity + acceleration * lifetime,
		Expired = true
	}
end

local function interceptResidual(relativePosition, relativeVelocity, halfRelativeAcceleration, speed, time)
	local offset = relativePosition + relativeVelocity * time + halfRelativeAcceleration * (time * time)
	return offset:Dot(offset) - (speed * speed * time * time)
end

-- Solves |r + v*t + 0.5*(at-ap)*t^2| = projectileSpeed*t.  The result uses
-- the same speed supplied by the caller, so the solved angle and transmitted
-- velocity cannot drift apart.
function module.SolveIntercept(origin, projectileSpeed, projectileAcceleration, targetPosition, targetVelocity, targetAcceleration, minimumTime, maximumTime)
	if not finiteVector(origin) or not finiteVector(projectileAcceleration)
		or not finiteVector(targetPosition) or not finiteVector(targetVelocity)
		or not finiteVector(targetAcceleration) or not finiteNumber(projectileSpeed)
		or projectileSpeed <= eps then return nil end

	minimumTime = tonumber(minimumTime)
	if not finiteScalar(minimumTime) or minimumTime < 0 then minimumTime = 0 end
	minimumTime = math.max(minimumTime, eps)
	maximumTime = tonumber(maximumTime) or 10
	if not finiteNumber(maximumTime) or maximumTime < minimumTime then return nil end

	local relativePosition = targetPosition - origin
	local halfRelativeAcceleration = (targetAcceleration - projectileAcceleration) * 0.5
	local bestTime
	local function residualTolerance(root)
		local scale = math.max(projectileSpeed * projectileSpeed * root * root, 1)
		return math.max(0.0025, scale * 1e-5)
	end
	local function acceptRoot(root)
		if not finiteNumber(root) or root < minimumTime or root > maximumTime then return end
		local residual = math.abs(interceptResidual(
			relativePosition,
			targetVelocity,
			halfRelativeAcceleration,
			projectileSpeed,
			root
		))
		if residual <= residualTolerance(root)
			and (not bestTime or root < bestTime) then
			bestTime = root
		end
	end

	local c4 = halfRelativeAcceleration:Dot(halfRelativeAcceleration)
	local c3 = 2 * targetVelocity:Dot(halfRelativeAcceleration)
	local c2 = targetVelocity:Dot(targetVelocity)
		+ 2 * relativePosition:Dot(halfRelativeAcceleration)
		- projectileSpeed * projectileSpeed
	local c1 = 2 * relativePosition:Dot(targetVelocity)
	local c0 = relativePosition:Dot(relativePosition)
	local coefficientScale = math.max(math.abs(c4), math.abs(c3), math.abs(c2), math.abs(c1), math.abs(c0))
	if coefficientScale <= 0 then return nil end
	local coefficientEpsilon = coefficientScale * 1e-12
	if math.abs(c4) > coefficientEpsilon then
		-- A closed-form quartic is an optimization, not a hard dependency.  A
		-- degenerate resolvent or executor math edge case must fall through to the
		-- bounded numerical search instead of aborting the caller's target query.
		local solved, roots = pcall(module.solveQuartic, c4, c3, c2, c1, c0)
		if solved and type(roots) == 'table' then
			for _, root in roots do
				acceptRoot(root)
			end
		end
	elseif math.abs(c2) > coefficientEpsilon then
		local root0, root1 = solveQuadric(c2, c1, c0)
		acceptRoot(root0)
		acceptRoot(root1)
	elseif math.abs(c1) > coefficientEpsilon then
		acceptRoot(-c0 / c1)
	end

	-- Numerical fallback covers near-degenerate quartics and floating-point
	-- roots rejected by the closed form at very short ranges.
	if not bestTime then
		local steps = 192
		local times, values = {}, {}
		for step = 0, steps do
			local time = minimumTime + ((maximumTime - minimumTime) * step / steps)
			times[step + 1] = time
			values[step + 1] = interceptResidual(
				relativePosition,
				targetVelocity,
				halfRelativeAcceleration,
				projectileSpeed,
				time
			)
		end
		local function refineSignChange(low, high, lowValue)
			for _ = 1, 32 do
				local middle = (low + high) * 0.5
				local middleValue = interceptResidual(relativePosition, targetVelocity, halfRelativeAcceleration, projectileSpeed, middle)
				if math.abs(middleValue) <= residualTolerance(middle) then return middle end
				if (lowValue <= 0) == (middleValue <= 0) then
					low, lowValue = middle, middleValue
				else
					high = middle
				end
			end
			return (low + high) * 0.5
		end
		local function refineTangent(low, high)
			for _ = 1, 32 do
				local left = low + (high - low) / 3
				local right = high - (high - low) / 3
				local leftValue = math.abs(interceptResidual(relativePosition, targetVelocity, halfRelativeAcceleration, projectileSpeed, left))
				local rightValue = math.abs(interceptResidual(relativePosition, targetVelocity, halfRelativeAcceleration, projectileSpeed, right))
				if leftValue <= rightValue then high = right else low = left end
			end
			return (low + high) * 0.5
		end
		for index = 1, #times do
			local value = values[index]
			if math.abs(value) <= residualTolerance(times[index]) then acceptRoot(times[index]) end
			if index > 1 then
				local previousValue = values[index - 1]
				if (previousValue < 0 and value > 0) or (previousValue > 0 and value < 0) then
					acceptRoot(refineSignChange(times[index - 1], times[index], previousValue))
				end
			end
			if index > 1 and index < #times then
				local previousAbs, nextAbs = math.abs(values[index - 1]), math.abs(values[index + 1])
				if math.abs(value) <= previousAbs and math.abs(value) <= nextAbs then
					acceptRoot(refineTangent(times[index - 1], times[index + 1]))
				end
			end
		end
	end
	if not bestTime then return nil end

	local displacement = relativePosition
		+ targetVelocity * bestTime
		+ halfRelativeAcceleration * (bestTime * bestTime)
	if displacement.Magnitude <= eps then return nil end
	local initialVelocity = displacement / bestTime
	return {
		AimPosition = origin + initialVelocity,
		FlightTime = bestTime,
		ImpactPosition = targetPosition
			+ targetVelocity * bestTime
			+ targetAcceleration * (0.5 * bestTime * bestTime),
		InitialVelocity = initialVelocity
	}
end

function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
	if typeof(origin) ~= 'Vector3' or typeof(targetPos) ~= 'Vector3'
		or typeof(targetVelocity) ~= 'Vector3' or not finiteScalar(projectileSpeed)
		or projectileSpeed <= eps then return end
	gravity = math.abs(tonumber(gravity) or 0)
	if not finiteScalar(gravity) then return end
	local numericHeight = tonumber(playerHeight)
	if numericHeight ~= nil and (not finiteScalar(numericHeight) or numericHeight < 0) then
		numericHeight = nil
	end

	local velocity = targetVelocity
	local grounded = false
	if numericHeight and numericHeight > 0 then
		local success, ray = pcall(workspace.Raycast, workspace, targetPos,
			Vector3.new(0, -numericHeight - 0.5, 0), params)
		grounded = success and ray ~= nil and velocity.Y <= 0.1
	end
	if grounded then
		-- A floor hit means the target is supported; its vertical velocity is
		-- zero, not the distance to the floor.  The old code injected that
		-- distance as a downward speed and systematically aimed low.
		velocity = Vector3.new(velocity.X, 0, velocity.Z)
	end

	local targetAcceleration = Vector3.zero
	-- Once the floor probe says the target is airborne, gravity still applies at
	-- the apex where Y velocity is zero.  The previous velocity/jump gate made
	-- that single frame look stationary and caused a systematic low shot.
	local targetGravity = tonumber(playerGravity)
	if not grounded and finiteScalar(targetGravity) and targetGravity > 0 then
		targetAcceleration = Vector3.new(0, -targetGravity, 0)
	end
	local solution = module.SolveIntercept(
		origin,
		projectileSpeed,
		Vector3.new(0, -gravity, 0),
		targetPos,
		velocity,
		targetAcceleration,
		0,
		10
	)
	if solution and solution.InitialVelocity.Magnitude > eps then
		return solution.AimPosition, solution.InitialVelocity.Unit, solution.FlightTime
	end
	return nil
end

return module