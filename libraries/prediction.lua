--[[
	Prediction Library
	Source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434
]]

--[[
	Improved Prediction Library

	Rewritten for Roblox projectile prediction.

	Changes:
	- Stable player movement prediction
	- Correct gravity handling
	- Ping compensation
	- Better jumping/falling accuracy
	- Keeps tracer utilities
]]

local module = {}

local eps = 1e-9

local cloneref = cloneref or function(ref)
	return ref
end

local TweenService = cloneref(game:GetService("TweenService"))


local function isZero(x)
	return math.abs(x) < eps
end



----------------------------------------------------
-- Math helpers
----------------------------------------------------

local function cubeRoot(x)
	if x < 0 then
		return -((-x)^(1/3))
	end

	return x^(1/3)
end



local function solveQuadric(a,b,c)

	if isZero(a) then

		if isZero(b) then
			return
		end

		return -c/b
	end


	local d = b*b - 4*a*c

	if d < 0 then
		return
	end


	local sqrt = math.sqrt(d)


	return
		(-b + sqrt)/(2*a),
		(-b - sqrt)/(2*a)

end



local function solveCubic(a,b,c,d)

	if isZero(a) then
		return solveQuadric(b,c,d)
	end


	b/=a
	c/=a
	d/=a


	local p =
		c - b*b/3


	local q =
		2*b*b*b/27
		- b*c/3
		+ d


	local discriminant =
		q*q/4
		+
		p*p*p/27



	if discriminant > 0 then

		local sqrt =
			math.sqrt(discriminant)


		return
			cubeRoot(-q/2+sqrt)
			+
			cubeRoot(-q/2-sqrt)
			-
			b/3


	elseif isZero(discriminant) then

		local u =
			cubeRoot(-q/2)


		return
			2*u-b/3,
			-u-b/3


	else

		local r =
			math.sqrt(-p*p*p/27)


		local theta =
			math.acos(-q/(2*r))


		local m =
			2*math.sqrt(-p/3)


		return
			m*math.cos(theta/3)-b/3,
			m*math.cos((theta+2*math.pi)/3)-b/3,
			m*math.cos((theta+4*math.pi)/3)-b/3
	end

end

----------------------------------------------------
-- Tracer utilities
----------------------------------------------------

local tracer = Instance.new("Part")

tracer.Anchored = true
tracer.CanCollide = false
tracer.CanQuery = false
tracer.CanTouch = false
tracer.CastShadow = false



function module.SpawnTracer(from,to,custom)

	local distance =
		(to-from).Magnitude


	if distance < 0.01 then
		return
	end


	local part =
		tracer:Clone()


	part.Color =
		custom.Color


	part.Size =
		Vector3.new(
			custom.Thick,
			custom.Thick,
			distance
		)


	part.CFrame =
		CFrame.lookAt(
			from,
			to
		)
		*
		CFrame.new(
			0,
			0,
			-distance/2
		)


	part.Material =
		custom.Material


	part.Transparency =
		custom.Opacity or 0



	if custom.Fade then

		TweenService:Create(
			part,
			TweenInfo.new(custom.Lifetime),
			{
				Transparency = 1
			}
		):Play()

	end


	return part

end




function module.SpawnArcTracer(
	origin,
	aimDirection,
	projectileSpeed,
	gravity,
	travelTime,
	steps,
	custom
)


	steps =
		steps or 20


	local stepTime =
		travelTime/steps


	local velocity =
		aimDirection*projectileSpeed


	local g =
		Vector3.new(
			0,
			-gravity,
			0
		)


	local previous =
		origin



	local model =
		Instance.new("Model")


	model.Parent =
		workspace.Terrain



	for i=1,steps do

		local t =
			i*stepTime


		local nextPosition =
			origin
			+
			velocity*t
			+
			0.5*g*t*t



		local line =
			module.SpawnTracer(
				previous,
				nextPosition,
				custom
			)


		if line then
			line.Parent=model
		end


		previous =
			nextPosition

	end



	task.delay(
		custom.Lifetime or 1,
		function()
			if model then
				model:Destroy()
			end
		end
	)

end




----------------------------------------------------
-- Prediction solver
----------------------------------------------------

-- Predicts where a target will be after projectile travel time.
-- This intentionally avoids quartic solving because Roblox characters
-- are controlled objects, not ballistic objects.


local function predictTarget(
	position,
	velocity,
	time,
	gravity
)


	local predicted =
		position
		+
		velocity*time



	if gravity then

		predicted +=
			Vector3.new(
				0,
				-0.5*gravity*time*time,
				0
			)

	end


	return predicted

end





local function calculateFlightTime(
	origin,
	target,
	speed
)


	return
		(target-origin).Magnitude
		/
		speed

end






local function solveProjectile(
	origin,
	target,
	speed,
	projectileGravity
)


	local displacement =
		target-origin



	local distance =
		displacement.Magnitude



	local time =
		distance/speed



	local velocity =
		displacement/time



	-- compensate projectile drop

	if projectileGravity then

		velocity +=
			Vector3.new(
				0,
				0.5*
				projectileGravity*
				time,
				0
			)

	end


	return time,velocity

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


	if not projectileSpeed
	or projectileSpeed <= eps then
		return
	end



	targetVelocity =
		targetVelocity
		or Vector3.zero



	playerGravity =
		playerGravity
		or 0



	ping =
		ping
		or 0



	iterations =
		math.clamp(
			iterations or 3,
			1,
			5
		)



	------------------------------------------------
	-- Network compensation
	------------------------------------------------

	-- Only compensate once.
	-- Old version applied ping twice which caused
	-- jumping players to drift heavily.

	local position =
		targetPosition
		+
		targetVelocity*ping





	------------------------------------------------
	-- Remove tiny grounded velocity noise
	------------------------------------------------

	if math.abs(targetVelocity.Y) < 2 then

		targetVelocity =
			Vector3.new(
				targetVelocity.X,
				0,
				targetVelocity.Z
			)

	end





	------------------------------------------------
	-- Iterative solve
	------------------------------------------------

	local time =
		calculateFlightTime(
			origin,
			position,
			projectileSpeed
		)



	local aimVelocity



	for i = 1, iterations do


		local predicted =
			predictTarget(
				position,
				targetVelocity,
				time,
				playerGravity
			)



		local newTime,newVelocity =
			solveProjectile(
				origin,
				predicted,
				projectileSpeed,
				projectileGravity
			)



		if newVelocity then

			aimVelocity =
				newVelocity

		end



		if math.abs(newTime-time) < 0.001 then

			time =
				newTime

			break

		end



		time =
			newTime

	end




	if not aimVelocity then
		return
	end




	return
		origin
		+
		aimVelocity

end






----------------------------------------------------
-- Helper function for external use
----------------------------------------------------

function module.PredictPosition(
	position,
	velocity,
	time,
	gravity
)


	return predictTarget(
		position,
		velocity,
		time,
		gravity
	)

end





return module
