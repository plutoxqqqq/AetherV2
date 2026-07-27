--[[
	Prediction Library
	Original source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434

	Rewritten for accuracy at range and against jumping targets.

	What was wrong before, and what this does instead:

	- Flight time was `distance / speed`. A projectile that arcs is in the air for
	  noticeably longer than that, so every gravity-affected shot under-led its target -
	  and the error grows with distance, which is exactly why long shots missed behind.
	  The arc is now solved exactly (a quadratic in t^2), so the time of flight is the
	  real one.
	- The launch velocity it built did not have magnitude `projectileSpeed` once the
	  drop compensation was added, so the direction callers fire (`lookAt(...).LookVector
	  * speed`) was not the direction that was solved for. It now always does.
	- Gravity was applied to the target whenever their vertical velocity read above a
	  noise floor, with nothing stopping the predicted point from sinking through the
	  floor, and a target at the apex of a jump was treated as standing still. Target
	  motion is now simulated: gravity only while genuinely airborne, the fall clamps at
	  the ground, and a bunny-hopping target (playerJump) is re-launched when the
	  simulation lands them.
	- `playerHeight`, `playerJump` and `params` were accepted and then ignored. All three
	  are used now (foot offset, re-jump velocity, ground raycast).
	- Ping compensation was a flat `velocity * ping`, which threw a jumping target off by
	  the gravity term. It now advances the target through the same simulation.

	Call signature and return value are unchanged: the result is a point on the launch
	ray, so `CFrame.lookAt(origin, result).LookVector * projectileSpeed` is the solved
	shot. The time of flight is returned as a second value.
]]

local module = {}

local eps = 1e-6

local cloneref = cloneref or function(ref)
	return ref
end

local TweenService = cloneref(game:GetService("TweenService"))

----------------------------------------------------
-- Tracer utilities
----------------------------------------------------

local tracer = Instance.new("Part")

tracer.Anchored = true
tracer.CanCollide = false
tracer.CanQuery = false
tracer.CanTouch = false
tracer.CastShadow = false

function module.SpawnTracer(from, to, custom)
	local distance = (to - from).Magnitude

	if distance < 0.01 then
		return
	end

	local part = tracer:Clone()

	part.Color = custom.Color
	part.Size = Vector3.new(custom.Thick, custom.Thick, distance)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	part.Material = custom.Material
	part.Transparency = custom.Opacity or 0

	if custom.Fade then
		TweenService:Create(part, TweenInfo.new(custom.Lifetime), {
			Transparency = 1
		}):Play()
	end

	return part
end

function module.SpawnArcTracer(origin, aimDirection, projectileSpeed, gravity, travelTime, steps, custom)
	steps = steps or 20

	local stepTime = travelTime / steps
	local velocity = aimDirection * projectileSpeed
	local g = Vector3.new(0, -gravity, 0)
	local previous = origin

	local model = Instance.new("Model")
	model.Parent = workspace.Terrain

	for i = 1, steps do
		local t = i * stepTime
		local nextPosition = origin + velocity * t + 0.5 * g * t * t
		local line = module.SpawnTracer(previous, nextPosition, custom)

		if line then
			line.Parent = model
		end

		previous = nextPosition
	end

	task.delay(custom.Lifetime or 1, function()
		if model then
			model:Destroy()
		end
	end)
end

----------------------------------------------------
-- Target simulation
----------------------------------------------------

-- Height of the ground under `position`, or nil when it cannot be worked out.
local function findGround(position, velocityY, height, params)
	local floor

	-- A target that is not falling is standing on - or has just pushed off - ground we
	-- can place exactly with no cast at all: it is directly under their feet. That covers
	-- the two cases that matter most, a running target and a bunny-hopper we have just
	-- watched leave the floor, and it works even when the caller passes no RaycastParams.
	if velocityY > -1.5 then
		floor = position.Y - height
	end

	if params then
		local ok, result = pcall(workspace.Raycast, workspace, position, Vector3.new(0, -512, 0), params)

		if ok and result then
			local drop = position.Y - result.Position.Y
			-- Callers filter their own character out of these params, never the target's,
			-- so a hit inside the target's body is one of the target's own parts. A hit
			-- level with their feet while they are dropping fast is the same thing: you
			-- cannot be stood on a floor at eight studs per second downwards.
			local selfHit = drop < (height * 0.6) or (drop < (height + 0.5) and velocityY < -8)

			if not selfHit then
				floor = result.Position.Y
			end
		end
	end

	return floor
end

-- Where the target is `t` seconds from now, and how fast they are moving when they get
-- there. Horizontal motion is held constant (a humanoid runs at a fixed speed); vertical
-- motion is integrated arc by arc so landings - and re-jumps - happen at the right time
-- instead of being smeared into one parabola.
local function simulateTarget(position, velocity, t, gravity, height, jumpPower, groundY)
	local y, vy = position.Y, velocity.Y

	if t > eps then
		if gravity <= eps then
			y += vy * t
		else
			local floor = groundY and (groundY + height) or nil
			local remaining = t

			if not floor and math.abs(vy) < 1.5 then
				-- Nothing to stand on that we can see, and no real vertical motion: the
				-- target is running along the ground. Dropping them under gravity from
				-- here is what used to bury predicted points in the floor.
				vy, remaining = 0, 0
			end

			-- Arc by arc. Bounded so it can never spin, but high enough that a
			-- bunny-hopper can land and re-jump for the whole of a long, lobbed flight
			-- instead of being frozen on the floor half way through it.
			for _ = 1, 32 do
				if remaining <= eps then
					break
				end

				if floor and y <= floor + eps and vy <= 0 then
					y, vy = floor, jumpPower or 0
					if vy <= 0 then
						-- Standing still on the floor for the rest of the flight.
						break
					end
				end

				-- Time until the arc crosses the floor:
				--   0.5 * g * dt^2 - vy * dt - (y - floor) = 0
				local landing
				if floor then
					local drop = math.max(y - floor, 0)
					landing = (vy + math.sqrt(math.max(vy * vy + 2 * gravity * drop, 0))) / gravity
				end

				if not landing or landing <= eps or landing >= remaining then
					y += vy * remaining - 0.5 * gravity * remaining * remaining
					vy -= gravity * remaining
					if floor and y < floor then
						y, vy = floor, jumpPower or 0
					end
					break
				end

				y, vy = floor, jumpPower or 0
				remaining -= landing
				if vy <= 0 then
					break
				end
			end
		end
	end

	return Vector3.new(position.X + velocity.X * t, y, position.Z + velocity.Z * t),
		Vector3.new(velocity.X, vy, velocity.Z)
end

----------------------------------------------------
-- Ballistics
----------------------------------------------------

-- Exact time of flight for a projectile launched at `speed` under `gravity` that has to
-- cover `displacement`. Solving |d - 0.5*a*t^2| = speed*t for t gives
--   0.25*g^2 * t^4 + (g*dy - speed^2) * t^2 + |d|^2 = 0
-- which is a plain quadratic in t^2. Returns nil when the target is out of reach.
local function flightTime(displacement, speed, gravity)
	local distance = displacement.Magnitude

	if distance <= eps or speed <= eps then
		return
	end

	if gravity <= eps then
		return distance / speed
	end

	local a = 0.25 * gravity * gravity
	local b = gravity * displacement.Y - speed * speed
	local c = distance * distance

	local discriminant = b * b - 4 * a * c

	if discriminant < 0 then
		return
	end

	local root = math.sqrt(discriminant)
	local low = (-b - root) / (2 * a)
	local high = (-b + root) / (2 * a)

	-- The smaller positive root is the flat, fast trajectory - the direct shot rather
	-- than the lobbed one.
	local squared = low > eps and low or (high > eps and high or nil)

	if not squared then
		return
	end

	return math.sqrt(squared)
end

-- Launch velocity that covers `displacement` in exactly `t`. When `t` came out of
-- flightTime its magnitude is exactly the projectile speed, so the direction callers
-- fire is the direction that was solved for.
local function launchVelocity(displacement, t, gravity)
	return Vector3.new(
		displacement.X / t,
		displacement.Y / t + 0.5 * gravity * t,
		displacement.Z / t
	)
end

-- Best effort for a target the projectile simply cannot reach: throw it as far as it can
-- physically go towards them. Maximum range up (or down) a slope of angle a is launched
-- at a/2 + 45 degrees, so this is the furthest the shot can land in the right direction.
-- The old code kept the straight-line drop compensation here, which at extreme range
-- resolves to firing almost vertically.
local function maxRangeVelocity(displacement, speed)
	local flat = Vector3.new(displacement.X, 0, displacement.Z)
	local horizontal = flat.Magnitude

	if horizontal <= eps then
		return Vector3.new(0, displacement.Y >= 0 and speed or -speed, 0)
	end

	local angle = math.atan(displacement.Y / horizontal) * 0.5 + math.pi * 0.25
	local direction = flat.Unit
	local cos, sin = math.cos(angle), math.sin(angle)

	return Vector3.new(direction.X * cos * speed, sin * speed, direction.Z * cos * speed)
end

----------------------------------------------------
-- Main trajectory prediction
----------------------------------------------------

function module.SolveTrajectory(
	origin,
	projectileSpeed,
	projectileGravity,
	targetPosition,
	targetVelocity,
	playerGravity,
	playerHeight,
	playerJump,
	params,
	iterations,
	ping
)
	if typeof(origin) ~= "Vector3" or typeof(targetPosition) ~= "Vector3" then
		return
	end

	if not projectileSpeed or projectileSpeed <= eps then
		return
	end

	projectileGravity = math.max(projectileGravity or 0, 0)
	playerGravity = math.max(playerGravity or 0, 0)
	playerHeight = playerHeight or 0
	targetVelocity = typeof(targetVelocity) == "Vector3" and targetVelocity or Vector3.zero
	ping = math.clamp(ping or 0, 0, 1)
	iterations = math.clamp(iterations or 10, 1, 24)

	-- Callers pass a jump power only for targets that are actually bunny-hopping.
	if playerJump and playerJump <= eps then
		playerJump = nil
	end

	local groundY = findGround(targetPosition, targetVelocity.Y, playerHeight, params)

	-- Network compensation. What we can see is `ping` seconds old, so roll the target
	-- forward through the same simulation the solve uses - a flat velocity * ping put a
	-- jumping target above or below where they really were by the gravity term.
	local position, velocity = targetPosition, targetVelocity
	if ping > eps then
		position, velocity = simulateTarget(targetPosition, targetVelocity, ping, playerGravity, playerHeight, playerJump, groundY)
	end

	-- Seed with the straight-line time and let the arc pull it out to the real one.
	local time = math.clamp((position - origin).Magnitude / projectileSpeed, 0, 20)
	local aimVelocity, flight, closest
	local step, lastSign = 1, 0

	for _ = 1, iterations do
		local predicted = simulateTarget(position, velocity, time, playerGravity, playerHeight, playerJump, groundY)
		local displacement = predicted - origin

		if displacement.Magnitude <= eps then
			break
		end

		local solved = flightTime(displacement, projectileSpeed, projectileGravity)

		if not solved then
			-- Beyond what the projectile can reach: send it as far towards them as it can
			-- go, so the caller still gets a usable shot instead of nothing back.
			aimVelocity = maxRangeVelocity(displacement, projectileSpeed)
			flight = projectileGravity > eps and ((2 * aimVelocity.Y) / projectileGravity) or (displacement.Magnitude / projectileSpeed)
			closest = nil
			break
		end

		-- The shot is only right where the arrival time agrees with the time the target
		-- was predicted for, so keep the closest agreement we have seen rather than
		-- whatever the last pass happened to produce.
		local disagreement = math.abs(solved - time)

		if not closest or disagreement < closest then
			closest = disagreement
			aimVelocity, flight = launchVelocity(displacement, solved, projectileGravity), solved
		end

		if disagreement < 0.0005 then
			break
		end

		-- Full steps while the estimate keeps moving the same way, halved as soon as it
		-- overshoots. A bunny-hopping target makes the time <-> position feedback jumpy
		-- enough that a plain fixed point iteration sits there ping-ponging between two
		-- arcs; damping only when that actually happens keeps the smooth cases fast.
		local delta = solved - time
		local sign = delta > 0 and 1 or -1

		if lastSign ~= 0 and sign ~= lastSign then
			step = math.max(step * 0.5, 0.1)
		end

		lastSign = sign
		time = math.clamp(time + delta * step, 0, 20)
	end

	if not aimVelocity then
		return
	end

	return origin + aimVelocity, flight
end

----------------------------------------------------
-- Helpers for external use
----------------------------------------------------

-- Where a target ends up after `time`. `height`, `jumpPower` and `groundY` are optional;
-- without them this is a plain ballistic extrapolation, with them it lands and re-jumps
-- the same way SolveTrajectory's internal simulation does.
function module.PredictPosition(position, velocity, time, gravity, height, jumpPower, groundY)
	local predicted = simulateTarget(
		position,
		typeof(velocity) == "Vector3" and velocity or Vector3.zero,
		time or 0,
		math.max(gravity or 0, 0),
		height or 0,
		jumpPower,
		groundY
	)

	return predicted
end

-- Exposed so modules that need the arc (landing predictors, tracers) can ask for the
-- same time of flight the aim solve used.
function module.FlightTime(origin, targetPosition, projectileSpeed, projectileGravity)
	if typeof(origin) ~= "Vector3" or typeof(targetPosition) ~= "Vector3" then
		return
	end

	return flightTime(targetPosition - origin, projectileSpeed or 0, math.max(projectileGravity or 0, 0))
end

return module
