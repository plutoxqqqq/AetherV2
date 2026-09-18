run(function()
	--------------------------------------------------------------------------
	-- InfiniteFly
	--
	-- A sustained-flight movement controller for long void crossings.
	--
	-- The frame pipeline is deliberately linear:
	--
	--   INPUT -> DESIRED MOVEMENT -> PHYSICS/COLLISION VALIDATION -> APPLICATION
	--         -> OBSERVE ACTUAL RESULT -> PREDICTION RECONCILIATION
	--         -> STATE UPDATE -> RECOVERY IF NECESSARY
	--
	-- It is not:
	--
	--   INPUT -> CFrame spam -> hope the server accepts it
	--
	-- Deliberately absent: packet spoofing, fake grounded states, fake platform
	-- parts, network-ownership manipulation, one-shot teleports and anything else
	-- whose only purpose is to convince the server the character is somewhere it
	-- is not. What the server does with a character that stays airborne too long
	-- is treated as an engineering constraint: the controller observes it, gets
	-- conservative around it, and recovers from it, but never fights it.
	--
	-- Corrections are detected by comparing the observed character against the
	-- controller's *own previous prediction* - never by "moved more than N
	-- studs", which ordinary movement passes every frame.
	--------------------------------------------------------------------------

	local InfiniteFly
	local Speed
	local VerticalSpeed
	local CycleHeight
	local CycleDuration
	local AutoLand
	local VoidRecovery
	local Debug

	-- Every entry is a time or a distance and says which in its name.
	local TUNING = {
		-- --- airborne timing -------------------------------------------------
		-- Continuous airtime starts drawing correction somewhere around 2-2.5
		-- seconds in BedWars. That is an observed range, not a published
		-- constant, and Fly.lua's own `airleft > 2` is AetherV2's response
		-- threshold rather than proof of the server's number. So the controller
		-- works from a lower bound plus an explicit reserve, and treats "budget
		-- spent" as "hold altitude and look for real ground" - never as a switch
		-- that unlocks anything.
		ObservedAirtimeLowerBound = 2, -- seconds
		AirborneSafetyMargin = 0.4, -- seconds kept in reserve below that bound
		AirborneGrace = 0.12, -- seconds of Air before it counts as airborne

		-- --- horizontal controller -------------------------------------------
		HorizontalAcceleration = 55, -- studs/s^2
		HorizontalDeceleration = 75, -- studs/s^2
		WallSkin = 0.6, -- studs of clearance kept between the body and a face
		WallLookahead = 6, -- multiplier of the skin; how far ahead the cast reaches
		LandingHorizontalSpeed = 16, -- studs/s of steering allowed during a landing

		-- --- vertical controller ---------------------------------------------
		VerticalAcceleration = 65, -- studs/s^2
		VerticalRateGain = 5, -- 1/s, altitude error -> commanded vertical speed
		HoldBand = 0.6, -- studs; dead band so the altitude hold cannot oscillate
		StateEpsilon = 0.75, -- studs/s below which the vertical axis is "level"
		CycleMinPeriod = 0.5, -- seconds; floor for one half of the altitude cycle

		-- --- prediction / reconciliation -------------------------------------
		PredictionSlackPosition = 0.4, -- studs of always-tolerated position error
		PredictionSlackSpeed = 0.65, -- multiplier of one frame of commanded travel
		PredictionSlackVelocity = 14, -- studs/s of always-tolerated velocity error
		CorrectionDisplacement = 2.5, -- studs of unexplained position error
		CorrectionVelocity = 22, -- studs/s of unexplained velocity error
		ControlLossCommand = 6, -- studs/s of commanded horizontal motion that counts
		ControlLossSpeed = 1.5, -- studs/s of observed horizontal motion that does not

		-- --- correction recovery ---------------------------------------------
		CorrectionHoldTime = 0.2, -- seconds spent hands-off after a correction
		CorrectionRetain = 0.5, -- fraction of observed horizontal speed kept there
		RecoveryStep = 0.55, -- intensity multiplier applied per correction
		RecoveryFloor = 0.2, -- lowest intensity the ramp may decay to
		RecoveryRamp = 0.45, -- intensity regained per second of stable observation
		RecoveryStabilityTime = 0.4, -- seconds of stability before the ramp starts
		RecoveryStableError = 0.5, -- studs of prediction error that still counts as stable
		CorrectionWindow = 5, -- seconds; window used to count correction bursts
		CorrectionBurst = 4, -- corrections inside the window worth telling the user about

		-- --- world samples ---------------------------------------------------
		GroundSampleInterval = 0.05, -- seconds between ordinary ground samples
		FarGroundInterval = 0.25, -- seconds between long-range (void) ground samples
		GroundProbeRange = 400, -- studs searched for ordinary ground
		-- A shape cast is capped by the engine at 1024 studs, so the long range has to stay
		-- under that: asking for more raises "Attempt to shapecast with distance ...", which
		-- used to abort the frame and switch the module straight back off. `CastLimit` is
		-- the hard ceiling every probe is clamped to (see `castDistance`).
		VoidProbeRange = 1000, -- studs searched when the void is the question
		CastLimit = 1024, -- studs; engine maximum shape cast distance
		LandingNormalY = 0.6, -- minimum upward normal accepted as a landing surface
		ProbeLift = 0.3, -- studs the ground probe starts above the feet, so it never starts
		-- inside the surface the character is already standing on

		-- --- landing ---------------------------------------------------------
		LandingRange = 60, -- studs; a valid surface inside this can start an approach
		IdleLandingRange = 45, -- studs; settle distance when nothing is held
		ForcedLandingRange = 25, -- studs; end a spent flight at this distance
		DescentLandingRange = 55, -- studs; end a commanded descent at this distance
		LandingApproachSpeed = 16, -- studs/s descent used for the approach
		LandingContactGap = 0.75, -- studs; root-to-standing clearance counting as contact
		LandingConfirmTime = 0.12, -- seconds of confirmed contact before the flight ends
		LandingVelocityClamp = 18, -- studs/s downward clamp while landing (see NoFallDamage)

		-- --- world boundary / void recovery ----------------------------------
		WorldFloorMargin = 80, -- studs above FallenPartsDestroyHeight that is the boundary
		VoidRecoveryLead = 1.2, -- seconds of descent left before the boundary triggers
		WorldFloorClearance = 140, -- studs of clearance that ends a boundary recovery
		WorldFloorClimb = 26, -- studs/s climb used to leave the boundary line
		VoidSteerRange = 320, -- studs; how far recovery will steer toward known ground

		-- --- bookkeeping -----------------------------------------------------
		SafeGroundRefresh = 0.25, -- seconds between refresh writes of the safe position
		DebugInterval = 0.25, -- seconds between debug status blocks
	}

	-- The controller acts below the observed lower bound, not at it.
	local AIRBORNE_TRIGGER = TUNING.ObservedAirtimeLowerBound - TUNING.AirborneSafetyMargin

	-- Shape casts are capped by the engine; a request past the cap throws instead of returning
	-- a miss, so every cast distance is clamped before it reaches the world.
	local function castDistance(distance)
		distance = tonumber(distance) or 0
		if distance <= 0 then return 0 end
		return math.min(distance, TUNING.CastLimit)
	end

	local State = {
		Disabled = 'DISABLED',
		GroundStart = 'GROUND_START',
		Ascending = 'ASCENDING',
		Stabilising = 'STABILISING',
		Descending = 'DESCENDING',
		Landing = 'LANDING',
		Corrected = 'CORRECTED',
		Recovering = 'RECOVERING',
	}

	local function flat(vector)
		return Vector3.new(vector.X, 0, vector.Z)
	end

	local function approach(current, target, rate, dt)
		local delta = target - current
		local step = rate * dt
		if math.abs(delta) <= step then return target end
		return current + (delta > 0 and step or -step)
	end

	local function approachVector(current, target, rate, dt)
		local delta = target - current
		local distance = delta.Magnitude
		local step = rate * dt
		if distance <= step or distance < 1e-4 then return target end
		return current + (delta / distance) * step
	end

	local function debugLog(message)
		if Debug and Debug.Enabled then
			print('[InfiniteFly] '..message)
		end
	end

	--------------------------------------------------------------------------
	-- Input
	--
	-- WASD is tracked from input events rather than read back from
	-- Humanoid.MoveDirection, so the controller knows *why* it is moving and can
	-- reason about a released key. The connection set is created once per enable
	-- and registered with the module maid, so re-enabling cannot multiply it.
	--------------------------------------------------------------------------

	local keys = {Forward = false, Back = false, Left = false, Right = false, Up = false, Down = false}
	local keyCodes = {
		Forward = {Enum.KeyCode.W},
		Back = {Enum.KeyCode.S},
		Left = {Enum.KeyCode.A},
		Right = {Enum.KeyCode.D},
		Up = {Enum.KeyCode.Space, Enum.KeyCode.ButtonA},
		Down = {Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL2},
	}
	local inputBound = false

	local function resetInput()
		for name in keys do
			keys[name] = false
		end
	end

	local function keyName(code)
		for name, list in keyCodes do
			for _, candidate in list do
				if candidate == code then return name end
			end
		end
		return nil
	end

	local function bindInput()
		if inputBound then return end
		inputBound = true
		-- gameProcessedEvent is intentionally not used to filter: the engine marks Space as
		-- processed because it drives the jump, which would make the climb key untrackable.
		-- A focused text box is the case that actually matters, and the frame loop re-checks it.
		InfiniteFly:Clean(inputService.InputBegan:Connect(function(input)
			local name = keyName(input.KeyCode)
			if not name or inputService:GetFocusedTextBox() then return end
			keys[name] = true
		end))
		InfiniteFly:Clean(inputService.InputEnded:Connect(function(input)
			local name = keyName(input.KeyCode)
			if not name then return end
			keys[name] = false
		end))
		-- Losing focus with a key held used to leave it stuck down forever.
		InfiniteFly:Clean(inputService.WindowFocusReleased:Connect(resetInput))
		InfiniteFly:Clean(inputService.TextBoxFocused:Connect(resetInput))
	end

	local function cameraBasis(root)
		local look = gameCamera and gameCamera.CFrame.LookVector or Vector3.zAxis
		local forward = flat(look)
		if forward.Magnitude < 0.01 then
			-- Looking straight up or down: the flattened look vector is undefined, so
			-- fall back to the character's own horizontal facing.
			forward = flat(root.CFrame.LookVector)
		end
		if forward.Magnitude < 0.01 then
			return Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
		end
		forward = forward.Unit
		-- The right vector is rebuilt from the flattened forward axis rather than read
		-- from the camera, so camera pitch can never leak into the movement plane.
		local right = forward:Cross(Vector3.yAxis)
		if right.Magnitude < 0.01 then right = Vector3.xAxis end
		return forward, right.Unit
	end

	local function inputDirection(root, humanoid)
		if inputService:GetFocusedTextBox() then
			resetInput()
			return Vector3.zero
		end
		local axisZ = (keys.Forward and 1 or 0) - (keys.Back and 1 or 0)
		local axisX = (keys.Right and 1 or 0) - (keys.Left and 1 or 0)
		if axisX == 0 and axisZ == 0 then
			-- Touch and gamepad have no WASD scan codes: fall back to the engine's own
			-- movement input rather than refusing to move at all.
			local move = flat(humanoid.MoveDirection)
			return move.Magnitude > 0.05 and move.Unit or Vector3.zero
		end
		local forward, right = cameraBasis(root)
		local direction = forward * axisZ + right * axisX
		-- Diagonal input is longer than a single key; clamp it so W+D is not faster.
		return direction.Magnitude > 1 and direction.Unit or direction
	end

	--------------------------------------------------------------------------
	-- Reusable cast parameters
	--
	-- Three parameter objects for the module's lifetime; the excluded character
	-- reference is updated when the character (or AntiVoid's helper part) changes
	-- instead of a new table being built every frame.
	--------------------------------------------------------------------------

	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.RespectCanCollide = true

	local forwardParams = RaycastParams.new()
	forwardParams.FilterType = Enum.RaycastFilterType.Exclude
	forwardParams.RespectCanCollide = true

	local filterList = {}
	local filterCharacter
	local filterAuxiliary

	local function refreshFilter(character)
		local auxiliary = typeof(AntiFallPart) == 'Instance' and AntiFallPart or nil
		if filterCharacter == character and filterAuxiliary == auxiliary then return end
		filterCharacter, filterAuxiliary = character, auxiliary
		table.clear(filterList)
		if character then table.insert(filterList, character) end
		if gameCamera then table.insert(filterList, gameCamera) end
		if auxiliary then table.insert(filterList, auxiliary) end
		groundParams.FilterDescendantsInstances = filterList
		forwardParams.FilterDescendantsInstances = filterList
	end

	--------------------------------------------------------------------------
	-- Character geometry
	--------------------------------------------------------------------------

	-- The distance from the root's centre to the ground while standing. entitylib folds the
	-- root half-height and the R6 leg offset into HipHeight, so the entity is the reference
	-- and the model-derived value is only a fallback. Every landing decision uses this one
	-- helper, so the geometry can never be assumed two different ways at once.
	local function clearanceOf(entity, root, humanoid)
		return (entity and entity.HipHeight) or ((humanoid.HipHeight or 2) + (root.Size.Y * 0.5))
	end

	local function rigOf()
		local entity = entitylib.character
		if not (entitylib.isAlive and entity) then return nil end
		local character = entity.Character
		if not (character and character.Parent) then return nil end
		local humanoid = entity.Humanoid
		if not (humanoid and humanoid.Parent and humanoid.Health > 0) then return nil end
		local root = entity.RootPart
		-- The cached root is only trusted while it is still inside the character; a
		-- rebuilt rig must not keep the controller writing to a dead part.
		if not (root and root.Parent == character) then
			root = character:FindFirstChild('HumanoidRootPart') or character.PrimaryPart
			if not root then return nil end
		end
		return entity, root, character, humanoid
	end

	-- Probes are rebuilt per rig: a ray can miss awkward terrain, so the ground is
	-- sampled by a character-sized block cast plus its four cardinal neighbours.
	local function buildProbes(root)
		local offsetX = math.max(root.Size.X * 0.75, 1.5)
		local offsetZ = math.max(root.Size.Z * 0.75, 1.5)
		return {
			Vector3.zero,
			Vector3.new(offsetX, 0, 0),
			Vector3.new(-offsetX, 0, 0),
			Vector3.new(0, 0, offsetZ),
			Vector3.new(0, 0, -offsetZ),
		}
	end

	--------------------------------------------------------------------------
	-- Session
	--
	-- Everything cached about the character lives here and is thrown away on
	-- death, respawn, rig replacement and disable.
	--------------------------------------------------------------------------

	local session

	local function blankSession(entity, root, character, humanoid)
		local created = {
			Entity = entity,
			Root = root,
			Character = character,
			Humanoid = humanoid,
			Clearance = clearanceOf(entity, root, humanoid),
			Probes = buildProbes(root),
			State = State.GroundStart,
			StateElapsed = 0,
			Grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
			GroundSince = nil,
			AirborneSince = nil,
			AirborneElapsed = 0,
			LastGroundAt = tick(),
			AirborneBudgetLogged = false,
			CycleElapsed = 0,
			CycleBaseY = nil,
			HoldY = nil,
			Takeoff = 0,
			CommandedVelocity = Vector3.zero,
			CommandedHorizontal = 0,
			LastDt = 0,
			WallBlocked = false,
			Prediction = {Has = false, Position = Vector3.zero, Velocity = Vector3.zero},
			PredictionError = 0,
			PredictionVelocityError = 0,
			Intensity = 1,
			Recovery = {Active = false, Reason = nil, Since = 0, StableSince = tick()},
			Corrections = {Total = 0, WindowStart = tick(), WindowCount = 0, Notified = 0},
			DebugSignature = nil,
			SafeGround = nil,
			SafeGroundAt = 0,
			Landing = false,
			LandingReason = nil,
			ContactTime = 0,
			Ground = nil,
			GroundDistance = math.huge,
			FarGroundDistance = math.huge,
			GroundAt = 0,
			FarGroundAt = 0,
			DebugAt = 0,
			ControlWarned = 0,
		}
		created.Ground = {Valid = false, Gap = math.huge, Distance = 0, SurfaceY = nil, Normal = nil, Instance = nil}
		if created.Grounded then
			created.SafeGround = root.Position
			created.SafeGroundAt = tick()
		end
		return created
	end

	local function beginSession(entity, root, character, humanoid)
		session = blankSession(entity, root, character, humanoid)
		refreshFilter(character)
		debugLog('Flight session started ('..character.Name..')')
	end

	local function endSession(reason)
		if not session then return end
		debugLog('Flight session ended ('..tostring(reason)..'), corrections: '..session.Corrections.Total)
		session = nil
	end

	--------------------------------------------------------------------------
	-- Ground sampling
	--
	-- "No hit" is not an emergency: during a long void crossing the ground ray
	-- is expected to come back empty. Distance and normal decide how a hit is
	-- interpreted, not its absence.
	--------------------------------------------------------------------------

	-- The long-range sample is only read for reporting (void versus near ground), so it
	-- reuses one table instead of allocating a new one on every probe.
	local farSample = {Valid = false, Gap = math.huge, Distance = 0, SurfaceY = nil, Normal = nil, Instance = nil}

	local function sampleGround(session, root, range, into)
		local clearance = session.Clearance
		local probes = session.Probes
		local origin = root.Position
		local lift = TUNING.ProbeLift
		local box = root.Size
		range = castDistance(range)
		local halfHeight = box.Y * 0.5
		local bestDistance, bestNormal, bestInstance
		for index = 1, #probes do
			-- The probe starts slightly above the feet: a shape that begins inside a part can
			-- report a meaningless contact, and standing on the ground is exactly that case.
			local from = CFrame.new(origin + probes[index] + Vector3.new(0, lift, 0))
			local hit = workspace:Blockcast(from, box, Vector3.new(0, -range, 0), groundParams)
			if hit and hit.Instance and hit.Instance.CanCollide and hit.Normal.Y >= TUNING.LandingNormalY then
				if not bestDistance or hit.Distance < bestDistance then
					bestDistance, bestNormal, bestInstance = hit.Distance, hit.Normal, hit.Instance
				end
			end
		end
		if bestDistance then
			-- gap = studs the root still has to descend before it is standing on the surface.
			into.Valid = true
			into.Distance = bestDistance
			into.Gap = math.max(halfHeight + bestDistance - clearance - lift, 0)
			into.SurfaceY = origin.Y + lift - halfHeight - bestDistance
			into.Normal = bestNormal
			into.Instance = bestInstance
		else
			into.Valid = false
			into.Distance = range
			into.Gap = math.huge
			into.SurfaceY = nil
			into.Normal = nil
			into.Instance = nil
		end
		return into
	end

	--------------------------------------------------------------------------
	-- Forward collision
	--
	-- The cast runs *before* any movement is committed. A surface shortens the
	-- step along its normal (a slide) instead of the step being applied and then
	-- reversed, which is what pushes a body into a face and holds it there.
	--------------------------------------------------------------------------

	local function slideStep(root, character, step)
		local distance = step.Magnitude
		if distance < 1e-4 then return step, false end
		distance = castDistance(distance)
		step = step.Unit * distance
		local direction = step.Unit
		local skin = TUNING.WallSkin
		refreshFilter(character)
		local box = Vector3.new(root.Size.X * 0.95, math.max(root.Size.Y * 0.7, 1), root.Size.Z * 0.95)
		local hit = workspace:Blockcast(
			CFrame.new(root.Position - direction * skin),
			box,
			direction * (distance + skin * TUNING.WallLookahead),
			forwardParams
		)
		if not hit then return step, false end
		if hit.Distance <= 1e-3 then
			-- The shape already overlaps the face, which is what hugging a wall looks like.
			-- Slide along it; pushing the body back out of it every frame is the jitter.
			local overlap = -step:Dot(hit.Normal)
			if overlap > 0 then return step + hit.Normal * overlap, true end
			return step, true
		end
		local approach = -direction:Dot(hit.Normal)
		if approach <= 1e-4 then return step, false end
		-- The cast started one skin behind the body, so that skin is already inside the
		-- reported distance and the body's own radius comes off on top of it.
		local allowed = (hit.Distance - skin) * approach - skin
		local into = -step:Dot(hit.Normal)
		if into <= allowed then return step, false end
		return step + hit.Normal * (into - allowed), true
	end

	--------------------------------------------------------------------------
	-- Prediction and reconciliation
	--
	-- Frame N records what it asked for (and where that should put the character
	-- one step later). Frame N+1 compares the *observed* character against that
	-- record. Comparing immediately after applying could never detect a server
	-- correction, because the local result is by definition the local result.
	--------------------------------------------------------------------------

	local function makePrediction(session, observedPosition, velocity, grounded, dt)
		-- Gravity keeps acting on the assembly between the write and the next read.
		local gravityStep = grounded and 0 or (workspace.Gravity * dt)
		local predictedVelocity = velocity - Vector3.new(0, gravityStep, 0)
		local predictedPosition = observedPosition + (velocity + predictedVelocity) * 0.5 * dt
		local prediction = session.Prediction
		prediction.Has = true
		prediction.Position = predictedPosition
		prediction.Velocity = predictedVelocity
	end

	local function reconcile(session, observedPosition, observedVelocity, grounded)
		local prediction = session.Prediction
		local horizontalObserved = flat(observedVelocity)
		if not prediction.Has then
			return {Kind = 'seed', Position = 0, Velocity = 0}
		end

		local positionError = (observedPosition - prediction.Position).Magnitude
		local velocityError = (observedVelocity - prediction.Velocity).Magnitude
		local travel = session.CommandedHorizontal * session.LastDt
		local slack = TUNING.PredictionSlackPosition + travel * TUNING.PredictionSlackSpeed
		local lostControl = (not session.WallBlocked)
			and not grounded
			and session.CommandedHorizontal > TUNING.ControlLossCommand
			and horizontalObserved.Magnitude < TUNING.ControlLossSpeed

		local kind = 'normal'
		if session.WallBlocked and positionError <= math.max(TUNING.CorrectionDisplacement, slack * 3) then
			-- Our own cast already explained a shorter step.
			kind = 'collision'
		elseif
			lostControl
			or positionError > math.max(TUNING.CorrectionDisplacement, slack * 2.5)
			or velocityError > math.max(TUNING.CorrectionVelocity, TUNING.PredictionSlackVelocity * 2.5)
		then
			kind = 'correction'
		elseif positionError > slack or velocityError > TUNING.PredictionSlackVelocity then
			-- Physics deviation: another writer, a slope, a nudge. Not worth a state change.
			kind = 'deviation'
		end

		return {
			Kind = kind,
			Position = positionError,
			Velocity = velocityError,
			LostControl = lostControl,
		}
	end

	-- A correction owns the new position and velocity. The only useful response is to
	-- accept them, re-seed every cached value from the observation, and stop pushing.
	local function reinitialise(session, position, velocity)
		session.HoldY = nil
		session.CycleBaseY = nil
		session.CycleElapsed = 0
		session.CommandedVelocity = velocity
		session.CommandedHorizontal = flat(velocity).Magnitude
		session.Prediction.Has = false
		session.SafeGroundAt = 0
	end

	local function noteCorrection(session, report)
		local stamp = tick()
		local corrections = session.Corrections
		corrections.Total += 1
		if stamp - corrections.WindowStart > TUNING.CorrectionWindow then
			corrections.WindowStart = stamp
			corrections.WindowCount = 0
		end
		corrections.WindowCount += 1

		session.Intensity = math.max(TUNING.RecoveryFloor, session.Intensity * TUNING.RecoveryStep)
		session.Recovery.Active = true
		session.Recovery.Reason = 'correction'
		session.Recovery.Since = stamp
		session.Recovery.StableSince = stamp

		debugLog(string.format(
			'Unexpected displacement detected (position %.2f, velocity %.2f, control loss %s) - intensity %.2f',
			report.Position,
			report.Velocity,
			tostring(report.LostControl),
			session.Intensity
		))

		if corrections.WindowCount >= TUNING.CorrectionBurst and stamp - corrections.Notified > 10 then
			corrections.Notified = stamp
			notif(
				'InfiniteFly',
				'Movement corrections detected ('..corrections.WindowCount..' in '..TUNING.CorrectionWindow..'s) - holding back.',
				5,
				'warning'
			)
		end
	end

	local function beginVoidRecovery(session, detail)
		if session.Recovery.Active and session.Recovery.Reason == 'void' then return end
		local escalated = session.Recovery.Active
		local stamp = tick()
		session.Recovery.Active = true
		-- The world boundary outranks any other recovery: what happens here is permanent.
		session.Recovery.Reason = 'void'
		session.Recovery.Since = stamp
		session.Recovery.StableSince = stamp
		session.Intensity = math.max(TUNING.RecoveryFloor, session.Intensity * TUNING.RecoveryStep)
		session.HoldY = nil
		debugLog('Recovery started (world boundary'
			..(detail and ': '..detail or '')
			..(escalated and ', escalated from correction recovery' or '')
			..') - intensity '
			..string.format('%.2f', session.Intensity))
	end

	local function endRecovery(session, why)
		session.Recovery.Active = false
		session.Recovery.Reason = nil
		session.Intensity = 1
		session.HoldY = nil
		session.CycleBaseY = nil
		debugLog('Recovery stabilised ('..why..')')
	end

	--------------------------------------------------------------------------
	-- Timers
	--
	-- cycleElapsed, airborneElapsed and stateElapsed are three different clocks.
	-- A cycle can end while the character never stopped being airborne, so
	-- airborne time must never be derived from the cycle clock.
	--------------------------------------------------------------------------

	local function updateTimers(session, grounded, dt)
		local stamp = tick()
		session.CycleElapsed += dt
		session.StateElapsed += dt

		if grounded then
			session.LastGroundAt = stamp
			session.Grounded = true
			session.GroundSince = session.GroundSince or stamp
			-- A stair lip or a slope edge flickers FloorMaterial for a frame or two. Only a
			-- contact that lasts restarts the airborne clock, so a graze cannot hide how long
			-- the character has really been up.
			if stamp - session.GroundSince >= TUNING.AirborneGrace then
				session.AirborneSince = nil
				session.AirborneElapsed = 0
				session.AirborneBudgetLogged = false
			end
		else
			session.GroundSince = nil
			if not session.AirborneSince then
				session.AirborneSince = stamp
			end
			session.AirborneElapsed = stamp - session.AirborneSince
			if session.AirborneElapsed > TUNING.AirborneGrace then
				session.Grounded = false
			end
		end
	end

	local function setState(session, state)
		if session.State == state then return end
		session.State = state
		session.StateElapsed = 0
		debugLog('State -> '..state)
	end

	--------------------------------------------------------------------------
	-- Vertical controller
	--------------------------------------------------------------------------

	local function flightVertical(session, observedPosition, grounded, wantsUp, wantsDown, cycleAllowed)
		-- The cycle clock only runs while the cycle is what is flying the character, so the
		-- reported figure is the age of the current cycle phase rather than the age of the
		-- flight - which is exactly why it can never be used as airborne time.
		if wantsUp then
			session.CycleBaseY = nil
			session.CycleElapsed = 0
			return VerticalSpeed.Value
		end
		if wantsDown then
			session.CycleBaseY = nil
			session.CycleElapsed = 0
			return -VerticalSpeed.Value
		end
		if grounded then
			session.HoldY = nil
			session.CycleBaseY = nil
			session.CycleElapsed = 0
			return 0
		end

		if cycleAllowed and CycleHeight.Value > 0 then
			local amplitude = CycleHeight.Value
			local period = math.max(CycleDuration.Value, TUNING.CycleMinPeriod)
			if not session.CycleBaseY then
				-- Start the cycle at zero vertical speed from where the character actually
				-- is, so engaging it never produces a step change in altitude.
				session.CycleBaseY = observedPosition.Y + amplitude
				session.CycleElapsed = 0
			end
			local phase = (session.CycleElapsed / period) * math.pi - math.pi * 0.5
			local targetY = session.CycleBaseY + amplitude * math.sin(phase)
			return math.clamp(
				(targetY - observedPosition.Y) * TUNING.VerticalRateGain,
				-VerticalSpeed.Value,
				VerticalSpeed.Value
			)
		end

		session.CycleBaseY = nil
		session.CycleElapsed = 0
		if not session.HoldY then session.HoldY = observedPosition.Y end
		local error = session.HoldY - observedPosition.Y
		if math.abs(error) <= TUNING.HoldBand then return 0 end
		local signed = error - (error > 0 and TUNING.HoldBand or -TUNING.HoldBand)
		return math.clamp(signed * TUNING.VerticalRateGain, -VerticalSpeed.Value, VerticalSpeed.Value)
	end

	--------------------------------------------------------------------------
	-- Landing
	--
	-- Not "a ray got close, turn the module off". A landing is a state: descend
	-- under control, confirm real contact, then finish.
	--------------------------------------------------------------------------

	local function shouldLand(session, ground, airtimeExceeded, wantsUp, wantsDown, hasHorizontalInput, grounded)
		if not AutoLand.Enabled then return false end
		if session.Recovery.Active then return false end
		if not ground.Valid or ground.Gap > TUNING.LandingRange then return false end
		-- Already at the surface: there is nothing to land into. This is deliberately the
		-- measured gap rather than FloorMaterial, which flickers on stairs and slopes.
		if ground.Gap <= TUNING.LandingContactGap then return false end
		-- A climb request is the pilot asking to leave the surface, so it can never be the
		-- moment to start an approach: without this the idle rule below cancels a take-off
		-- as soon as the character clears the contact gap.
		if wantsUp then return false end
		if not hasHorizontalInput and not wantsDown and ground.Gap <= TUNING.IdleLandingRange then
			return true, 'nothing held over solid ground'
		end
		if airtimeExceeded and not wantsUp and ground.Gap <= TUNING.ForcedLandingRange then
			return true, 'airborne budget spent with ground in reach'
		end
		if wantsDown and ground.Gap <= TUNING.DescentLandingRange then
			return true, 'descending into ground'
		end
		return false
	end

	local function landingDescent(ground)
		-- Proportional approach: fast while there is room, gentle at the surface.
		return -math.clamp((ground.Valid and ground.Gap or TUNING.LandingApproachSpeed) * 1.2, 2, TUNING.LandingApproachSpeed)
	end

	--------------------------------------------------------------------------
	-- Debug
	--------------------------------------------------------------------------

	local function debugStatus(session, observedVelocity, wantsRecovery)
		if not (Debug and Debug.Enabled) then return end
		local stamp = tick()
		-- A state or recovery change is printed straight away rather than waiting for the
		-- interval: those are the moments worth seeing in a log.
		local signature = tostring(session.State)..'|'..tostring(session.Recovery.Reason)
		if stamp - session.DebugAt < TUNING.DebugInterval and signature == session.DebugSignature then
			return
		end
		session.DebugAt = stamp
		session.DebugSignature = signature
		local distance = session.GroundDistance
		local horizontal = flat(observedVelocity).Magnitude
		print(string.format(
			'[InfiniteFly] State: %s\n'
				..'[InfiniteFly] Airborne: %.2fs\n'
				..'[InfiniteFly] Cycle: %.2fs\n'
				..'[InfiniteFly] Horizontal speed: %.1f\n'
				..'[InfiniteFly] Vertical speed: %.1f\n'
				..'[InfiniteFly] Prediction error: %.2f\n'
				..'[InfiniteFly] Ground distance: %s\n'
				..'[InfiniteFly] Recovery: %s\n'
				..'[InfiniteFly] Intensity: %.2f',
			session.State,
			session.AirborneElapsed,
			session.CycleElapsed,
			horizontal,
			observedVelocity.Y,
			session.PredictionError,
			distance == math.huge and 'none' or string.format('%.1f', distance),
			wantsRecovery and (session.Recovery.Reason or 'true') or 'false',
			session.Intensity
		))
	end

	--------------------------------------------------------------------------
	-- Frame
	--------------------------------------------------------------------------

	local function finishLanding(session, root)
		-- No residual climb: the character is standing, so the vertical component the
		-- controller was commanding is removed and normal ground physics resumes.
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		session.CommandedVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		session.CommandedHorizontal = flat(velocity).Magnitude
		session.Prediction.Has = false
		session.Landing = false
		session.HoldY = nil
		setState(session, State.GroundStart)
		debugLog('Landing confirmed')
		if AutoLand.Enabled and InfiniteFly.Enabled then
			task.spawn(function()
				if InfiniteFly.Enabled then InfiniteFly:Toggle() end
			end)
		end
	end

	local function step(dt)
		if not InfiniteFly.Enabled then return end

		local entity, root, character, humanoid = rigOf()
		if not root then
			endSession('no live character')
			return
		end
		if not session
			or session.Root ~= root
			or session.Character ~= character
			or session.Humanoid ~= humanoid
			or session.Entity ~= entity
		then
			-- A new rig invalidates every cached value: positions, predictions, timers.
			beginSession(entity, root, character, humanoid)
		end

		refreshFilter(character)

		local observedPosition = root.Position
		local observedVelocity = root.AssemblyLinearVelocity
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local owned = isnetworkowner(root)
		local climbing = humanoid:GetState() == Enum.HumanoidStateType.Climbing

		-- 1. Reconcile the previous frame's prediction against reality.
		local report = reconcile(session, observedPosition, observedVelocity, grounded)
		session.PredictionError = report.Position
		session.PredictionVelocityError = report.Velocity
		if report.Kind == 'correction' then
			noteCorrection(session, report)
			-- Accept where the correction actually left the character instead of asking for a
			-- return to the pre-correction flight path.
			reinitialise(session, observedPosition, observedVelocity)
		elseif report.Kind ~= 'normal' and report.Kind ~= 'seed' then
			session.Recovery.StableSince = tick()
		end

		-- 2. Clocks.
		updateTimers(session, grounded, dt)
		local airtimeExceeded = session.AirborneElapsed >= AIRBORNE_TRIGGER
		if airtimeExceeded and not session.AirborneBudgetLogged then
			session.AirborneBudgetLogged = true
			debugLog(string.format(
				'Airborne budget spent (%.2fs) - holding altitude and looking for real ground',
				session.AirborneElapsed
			))
		end

		-- 3. World samples.
		if tick() - session.GroundAt >= TUNING.GroundSampleInterval then
			sampleGround(session, root, TUNING.GroundProbeRange, session.Ground)
			session.GroundAt = tick()
		end
		local ground = session.Ground
		if tick() - session.FarGroundAt >= TUNING.FarGroundInterval then
			sampleGround(session, root, TUNING.VoidProbeRange, farSample)
			session.FarGroundDistance = farSample.Valid and farSample.Gap or math.huge
			session.FarGroundAt = tick()
		end
		session.GroundDistance = ground.Valid and ground.Gap or session.FarGroundDistance

		-- 4. Last known safe ground: written only from real contact.
		if grounded and tick() - session.SafeGroundAt > TUNING.SafeGroundRefresh then
			session.SafeGround = observedPosition
			session.SafeGroundAt = tick()
		end

		local wantsUp = keys.Up
		local wantsDown = keys.Down
		local horizontalInput = inputDirection(root, humanoid)
		local hasHorizontalInput = horizontalInput.Magnitude > 0.05

		-- 5. World-boundary danger. Distance to the kill plane plus remaining descent
		-- time - "nothing below" on its own is a normal void crossing, not danger.
		local voidDanger = false
		if VoidRecovery.Enabled and not grounded then
			local boundary = workspace.FallenPartsDestroyHeight + TUNING.WorldFloorMargin
			local clearance = observedPosition.Y - boundary
			local descent = math.max(-observedVelocity.Y, 0.1)
			if clearance < TUNING.WorldFloorMargin or (clearance / descent) < TUNING.VoidRecoveryLead then
				voidDanger = true
			end
		end

		-- 6. Mode. State names all live in the State table; these modes are the
		-- responsibilities they separate.
		local mode
		if session.Recovery.Active and session.Recovery.Reason == 'correction'
			and tick() - session.Recovery.Since < TUNING.CorrectionHoldTime
		then
			mode = 'corrected'
		elseif voidDanger then
			-- Checked before the generic recovery branch: a descent toward the kill plane is
			-- never left to a correction recovery's reduced climb.
			beginVoidRecovery(session)
			mode = 'recovering'
		elseif session.Recovery.Active then
			mode = 'recovering'
		elseif session.Landing then
			-- An approach belongs to the pilot: a climb request takes the controller back out
			-- of it, unless the surface is already under the feet and the contact is being
			-- confirmed - at that point the flight is over either way.
			if wantsUp and not (grounded and ground.Valid and ground.Gap <= TUNING.LandingContactGap) then
				session.Landing = false
				session.ContactTime = 0
				debugLog('Landing aborted (climb requested) - returning to flight')
				mode = session.Grounded and 'ground' or 'flight'
			else
				mode = 'landing'
			end
		else
			local land, reason = shouldLand(session, ground, airtimeExceeded, wantsUp, wantsDown, hasHorizontalInput, grounded)
			if land then
				session.Landing = true
				session.LandingReason = reason
				session.ContactTime = 0
				mode = 'landing'
				debugLog('Ground detected ('..reason..', '..string.format('%.1f', ground.Gap)..' studs) - landing')
			else
				mode = session.Grounded and 'ground' or 'flight'
			end
		end

		-- 7. Targets.
		local intensity = mode == 'corrected' and 0 or session.Intensity
		local verticalTarget, horizontalTarget
		if mode == 'landing' then
			-- Losing the surface mid-approach must not turn into a blind descent.
			verticalTarget = ground.Valid and landingDescent(ground) or math.max(session.CommandedVelocity.Y, 0)
			horizontalTarget = horizontalInput * math.min(Speed.Value, TUNING.LandingHorizontalSpeed)
		elseif mode == 'corrected' then
			-- One beat of hands off: no new horizontal drive, altitude supported at whatever
			-- the correction left behind. Fighting it here is what produces more lagback.
			verticalTarget = math.max(observedVelocity.Y, 0)
			horizontalTarget = flat(observedVelocity) * TUNING.CorrectionRetain
		elseif mode == 'recovering' and session.Recovery.Reason == 'void' then
			verticalTarget = math.min(VerticalSpeed.Value, TUNING.WorldFloorClimb)
			local safe = session.SafeGround
			if safe and (safe - observedPosition).Magnitude <= TUNING.VoidSteerRange then
				-- Point the horizontal controller at the last place that was solid ground and
				-- climb out at the configured speed. Movement, not relocation.
				local steer = flat(safe - observedPosition)
				horizontalTarget = steer.Magnitude > 4 and steer.Unit * Speed.Value * TUNING.RecoveryFloor or Vector3.zero
			else
				horizontalTarget = horizontalInput * Speed.Value * TUNING.RecoveryFloor
			end
		else
			verticalTarget = flightVertical(session, observedPosition, session.Grounded, wantsUp, wantsDown, mode == 'flight')
			horizontalTarget = horizontalInput * Speed.Value * intensity
		end

		-- 8. State label.
		local state
		if mode == 'landing' then
			state = State.Landing
		elseif mode == 'corrected' then
			state = State.Corrected
		elseif mode == 'recovering' then
			state = State.Recovering
		elseif session.Grounded then
			state = wantsUp and State.Ascending or State.GroundStart
		elseif verticalTarget > TUNING.StateEpsilon then
			state = State.Ascending
		elseif verticalTarget < -TUNING.StateEpsilon then
			state = State.Descending
		else
			state = State.Stabilising
		end
		setState(session, state)

		-- 9. Standing on real ground: the ground has its own movement controller, so the
		-- only thing InfiniteFly does here is leave, when asked, on a ramped climb.
		if mode == 'ground' and not session.Landing then
			session.Prediction.Has = false
			session.HoldY = nil
			session.CycleBaseY = nil
			if session.Recovery.Active then
				-- Real ground under the feet is the strongest possible stability signal.
				endRecovery(session, 'standing on ground')
			end
			if wantsUp then
				-- The take-off ramps in the controller's own state, not on the observation: ground
				-- contact zeroes the character's vertical velocity every frame, so a ramp built from
				-- the observation could never build up enough to leave the floor. The horizontal
				-- part is taken straight from the character, so walking is left untouched.
				session.Takeoff = approach(session.Takeoff, VerticalSpeed.Value, TUNING.VerticalAcceleration, dt)
				local velocity = Vector3.new(observedVelocity.X, session.Takeoff, observedVelocity.Z)
				root.AssemblyLinearVelocity = velocity
				session.CommandedVelocity = velocity
				session.CommandedHorizontal = flat(velocity).Magnitude
			else
				session.Takeoff = 0
				session.CommandedVelocity = Vector3.zero
				session.CommandedHorizontal = 0
			end
			debugStatus(session, observedVelocity, false)
			return
		end

		-- 10. Local movement control has to be ours. If the server owns the assembly, or
		-- a ladder does, observe and wait: ownership is never taken by force.
		if not owned or climbing then
			session.Prediction.Has = false
			session.CommandedHorizontal = 0
			session.CommandedVelocity = Vector3.new(0, observedVelocity.Y, 0)
			if tick() - session.ControlWarned > 5 then
				session.ControlWarned = tick()
				debugLog('Movement control unavailable ('..(climbing and 'climbing' or 'server owns the assembly')..') - observing')
			end
			debugStatus(session, observedVelocity, session.Recovery.Active)
			return
		end

		-- 11. Horizontal: desired -> collision validated -> applied.
		local currentHorizontal = flat(session.CommandedVelocity)
		local rate = (horizontalTarget.Magnitude >= currentHorizontal.Magnitude and TUNING.HorizontalAcceleration
			or TUNING.HorizontalDeceleration) * math.max(intensity, TUNING.RecoveryFloor)
		local nextHorizontal = approachVector(currentHorizontal, horizontalTarget, rate, dt)
		-- The vertical axis is only allowed full rate for a world-boundary escape; every other
		-- recovery keeps the reduced intensity.
		local escaping = mode == 'recovering' and session.Recovery.Reason == 'void'
		-- Gravity is added by the engine between this write and the next look at the character,
		-- so the ramp aims at the velocity the character should actually end up with. Without
		-- this the configured climb rate is always one frame of gravity short, and the altitude
		-- hold only works through its error term. It is dropped for the last few studs of a
		-- landing approach: there the point is to press into the surface and let the contact
		-- confirm the landing, not to hover above it.
		local pressing = mode == 'landing' and ground.Valid and ground.Gap <= TUNING.LandingContactGap * 4
		local gravityStep = (session.Grounded or pressing) and 0 or (workspace.Gravity * dt)
		local nextVertical = approach(
			session.CommandedVelocity.Y,
			verticalTarget + gravityStep,
			TUNING.VerticalAcceleration * math.max(intensity, escaping and 1 or TUNING.RecoveryFloor),
			dt
		)

		local displacement = nextHorizontal * dt
		local blocked = false
		if displacement.Magnitude > 1e-4 then
			displacement, blocked = slideStep(root, character, displacement)
			nextHorizontal = displacement / math.max(dt, 1e-4)
		end
		session.WallBlocked = blocked

		if mode == 'landing' then
			-- The one place a downward clamp is legitimate: it makes the arrival less
			-- abrupt rather than hiding anything.
			nextVertical = math.max(nextVertical, -TUNING.LandingVelocityClamp + gravityStep)
		end

		-- 12. Record the prediction before applying it.
		local velocity = Vector3.new(nextHorizontal.X, nextVertical, nextHorizontal.Z)
		makePrediction(session, observedPosition, velocity, session.Grounded, dt)
		session.CommandedVelocity = velocity
		session.CommandedHorizontal = flat(velocity).Magnitude
		session.LastDt = dt

		-- 13. Apply. A single writer, once per frame, and the engine resolves whatever
		-- remains - the cast above only makes sure we never ask to drive into a face.
		root.AssemblyLinearVelocity = velocity

		-- 14. Landing contact is a fact about the character, not about the ray.
		if mode == 'landing' then
			if ground.Valid and ground.Gap <= TUNING.LandingContactGap and grounded then
				session.ContactTime += dt
				if session.ContactTime >= TUNING.LandingConfirmTime then
					-- The landing ends the controller's involvement; nothing after this point in the
					-- frame is meaningful, and AutoLand may already be tearing the session down.
					finishLanding(session, root)
					return
				end
			else
				session.ContactTime = 0
				if not ground.Valid or ground.Gap > TUNING.LandingRange then
					session.Landing = false
					debugLog('Landing aborted (surface lost) - returning to flight')
				end
			end
		else
			session.ContactTime = 0
		end

		-- 15. Recovery feedback: aggressiveness only comes back while the character keeps
		-- doing what the controller predicted, never on a bare timer.
		if session.Recovery.Active then
			if report.Kind == 'normal' and report.Position <= TUNING.RecoveryStableError then
				if tick() - session.Recovery.StableSince >= TUNING.RecoveryStabilityTime then
					if session.Recovery.Reason == 'void' then
						local boundary = workspace.FallenPartsDestroyHeight + TUNING.WorldFloorMargin
						if observedPosition.Y - boundary >= TUNING.WorldFloorClearance and observedVelocity.Y >= 0 then
							endRecovery(session, 'world boundary cleared')
						end
					else
						session.Intensity = math.min(1, session.Intensity + TUNING.RecoveryRamp * dt)
						if session.Intensity >= 1 then
							endRecovery(session, 'observations stable')
						end
					end
				end
			else
				session.Recovery.StableSince = tick()
			end
		end

		debugStatus(session, observedVelocity, session.Recovery.Active)
	end

	local function shutdown()
		session = nil
		resetInput()
		-- The maid has just disconnected the input handlers; the guard has to come down with
		-- them or the next enable would silently fly without any input tracking.
		inputBound = false
		filterCharacter, filterAuxiliary = nil, nil
		store.infinitefly = nil
	end

	InfiniteFly = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteFly [BETA]',
		Tooltip = 'Infinitely fly over the void'
		Function = function(callback)
			if callback then
						local entity, root, character, humanoid = rigOf()
				if root then
					beginSession(entity, root, character, humanoid)
				else
					session = nil
				end
				bindInput()
				-- One connection set per enable, all of it registered with the module maid.
				InfiniteFly:Clean(runService.PreSimulation:Connect(function(dt)
					local ok, err = pcall(step, dt)
					if not ok then
						warn('[InfiniteFly] Frame failed: '..tostring(err))
						if InfiniteFly.Enabled then
							task.spawn(function()
								if InfiniteFly.Enabled then InfiniteFly:Toggle() end
							end)
						end
					end
				end))
				InfiniteFly:Clean(entitylib.Events.LocalAdded:Connect(function()
					-- Respawn: throw the old rig's numbers away and start again.
					session = nil
				end))
				InfiniteFly:Clean(entitylib.Events.LocalRemoved:Connect(function()
					session = nil
				end))
				InfiniteFly:Clean(shutdown)
				-- Tells NoFallDamage's server-state method to stand down while we are moving.
				store.infinitefly = true
			else
				shutdown()
			end
		end,
	})
	Speed = InfiniteFly:CreateSlider({
		Name = 'Horizontal Speed',
		Min = 10,
		Max = 100,
		Default = 23,
		Suffix = ' studs/s',
	})
	VerticalSpeed = InfiniteFly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 0,
		Max = 200,
		Default = 50,
		Suffix = ' studs/s',
	})
	CycleHeight = InfiniteFly:CreateSlider({
		Name = 'Cycle Height',
		Min = 0,
		Max = 24,
		Default = 6,
		Suffix = ' studs',
		Tooltip = 'Amplitude of the slow altitude cycle used over the void.\n0 holds a fixed altitude instead. The cycle starts and ends at zero vertical speed.',
	})
	CycleDuration = InfiniteFly:CreateSlider({
		Name = 'Cycle Duration',
		Min = 1,
		Max = 10,
		Default = 3,
		Suffix = 's',
		Tooltip = 'Seconds for one climb, and seconds for one descent, of the altitude cycle.',
	})
	AutoLand = InfiniteFly:CreateToggle({
		Name = 'Auto Land',
		Default = true,
		Tooltip = 'Ends a flight deliberately: approach, confirm real contact, then finish.\nIt also lands when the observed airborne window is spent and solid ground is in reach.',
	})
	VoidRecovery = InfiniteFly:CreateToggle({
		Name = 'Void Recovery',
		Default = true,
		Tooltip = 'Recovers from a descent toward the world kill plane by climbing and\nsteering toward the last known solid ground. Movement only - no teleport.',
	})
	Debug = InfiniteFly:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Prints the controller state, its clocks, prediction error and ground distance.',
	})
end)
