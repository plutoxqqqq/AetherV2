run(function()
	local CheatDetector
	local SelfDetect
	local Combat
	local Movement

	local Players = cloneref(game:GetService('Players'))

	---------------------------------------------------------------------------
	-- Tuning
	--
	-- Every threshold below is fixed. Nothing here is scaled by ping: a player's allowance is the
	-- same whether they are on 20ms or 200ms, which is deliberate - the checks describe what the
	-- game itself will and will not accept, and that does not change with somebody's connection.
	---------------------------------------------------------------------------
	local POLL = 0.1
	local STRIKE_MEMORY = 45

	-- Reach: anything past this is beyond what a melee swing can cover.
	local REACH_LIMIT = 15

	-- Killaura: a hit landed while facing away from the victim. From more than a block out, 90
	-- degrees off the facing direction is already impossible to aim; directly behind them the game
	-- gives a little more room, so that only flags past ~5 studs.
	local SIDE_ANGLE = 90
	local BEHIND_ANGLE = 160
	local SIDE_DISTANCE = 3
	local BEHIND_DISTANCE = 5

	-- Speed: sustained ground speed above this is faster than any legal movement buff.
	local SPEED_LIMIT = 21
	local SPEED_WINDOW = 1.5
	local SPEED_SAMPLES = 5
	local SPEED_SAMPLE_LIMIT = 0.85

	-- Kits that legitimately move faster than the limit. The check stands down entirely for them
	-- rather than trying to guess how much of the speed is the kit.
	local SPEED_KITS = {
		wind_walker = true,
		glacial_skater = true,
		elk_master = true,
		grim_reaper = true
	}

	-- Fly: nothing solid underneath for this long is a hover, not a fall.
	local VOID_TIME = 1
	local VOID_DESCENT = 1.5
	local VOID_DEPTH = 80

	-- AntiDeaths: a position snap the replicated velocity cannot explain. A normal jump moves with
	-- its velocity, so the displacement it leaves behind is tiny; even the softest AntiDeath drops
	-- or lifts the body a few studs instantly, which shows up here as unexplained vertical travel.
	local TELEPORT_VERTICAL = 4
	local TELEPORT_MARGIN = 3
	-- A deep drop followed by the same rise inside this window is the classic "under the map and
	-- straight back up" dodge.
	local UNDER_MAP_DROP = 25
	local UNDER_MAP_WINDOW = 2

	local required = {
		Reach = 3,
		Killaura = 3,
		Speed = 3,
		Fly = 3,
		AntiDeaths = 3
	}

	local strikes = {}
	local records = {}
	local speedTracks = {}
	local airTracks = {}
	local antiTracks = {}
	local pollThread

	local MOVEMENT_WORDS = {'speed', 'jump', 'haste', 'fury', 'strength', 'swift', 'agility', 'slow'}
	-- Kits that are allowed to leave the ground for long stretches.
	local HOVER_KITS = {owl = true}
	-- Items that are allowed to hold a player in the air.
	local HOVER_ITEMS = {'balloon', 'glider', 'parachute'}

	local groundRay = RaycastParams.new()
	groundRay.FilterType = Enum.RaycastFilterType.Exclude

	local function now()
		return tick()
	end

	local function isSelf(plr)
		return plr == Players.LocalPlayer
	end

	-- whitelist:get hands the targetable flag back in its second value, the same value the game reads
	-- before it lets a hit through, so anyone it marks untargetable is left alone here as well.
	local function whitelisted(plr)
		local ok, targetable = pcall(function()
			return select(2, whitelist:get(plr))
		end)
		return ok and targetable == false
	end

	-- Friends and manual whitelist entries are never accused: they are the people the user asked
	-- not to touch, and a false tag on them is worse than a miss.
	local function ignored(plr)
		if not plr or not plr.Parent then return true end
		if isSelf(plr) and not (SelfDetect and SelfDetect.Enabled) then return true end
		if CheatersFlagged[plr] == true then return true end
		if isFriend and isFriend(plr) then return true end
		if whitelisted(plr) then return true end
		return false
	end

	local function persist(plr, reason)
		pcall(function()
			if isfolder and not isfolder('aether') then makefolder('aether') end
			local path = 'aether/exploiters.json'
			local decoded = {}
			if isfile and isfile(path) then
				local body = select(2, pcall(readfile, path))
				local parsed = body and select(2, pcall(httpService.JSONDecode, httpService, body))
				if type(parsed) == 'table' then decoded = parsed end
			end
			table.insert(decoded, {name = plr.Name, userId = plr.UserId, reason = reason, at = os.time()})
			pcall(writefile, path, httpService:JSONEncode(decoded))
		end)
	end

	-- A player is only flagged once the same reason has been seen `required[reason]` times inside
	-- the memory window, so one odd reading is never enough on its own. `weight` lets the
	-- unmistakable patterns (a completed drop under the map and back) count for more than one.
	local function flag(plr, reason, weight)
		if ignored(plr) then return end
		local entry = strikes[plr]
		if not entry then
			entry = {}
			strikes[plr] = entry
		end
		local list = entry[reason]
		if not list then
			list = {}
			entry[reason] = list
		end
		local t = now()
		for _ = 1, weight or 1 do
			table.insert(list, t)
		end
		for index = #list, 1, -1 do
			if t - list[index] > STRIKE_MEMORY then table.remove(list, index) end
		end
		if #list < (required[reason] or 3) then return end
		CheatersFlagged[plr] = true
		whitelist.customtags[plr.Name] = {{text = 'CHEATER', color = Color3.fromRGB(235, 60, 60)}}
		if notif then notif('CheatDetector', tostring(plr.Name)..' flagged: '..reason, 8, 'alert') end
		persist(plr, reason)
		table.clear(entry)
	end

	-- Only status-effect attributes count, so unrelated attributes cannot hand out a free pass.
	local function hasEffect(character, words)
		for name in character:GetAttributes() do
			local lower = name:lower()
			if lower:find('effect', 1, true) then
				for _, word in words do
					if lower:find(word, 1, true) then return true end
				end
			end
		end
		return false
	end

	-- The game marks the characters it has had to move itself: void rescues, respawns and ability
	-- pulls. Speed and Fly read that so a server correction cannot look like a cheat. AntiDeaths
	-- deliberately does not, because a correction is exactly what it is looking for.
	local function recentlyCorrected(character)
		return character:GetAttribute('LastTeleported') ~= nil or character:GetAttribute('LastServerCorrected') ~= nil
	end

	local function heldItem(character)
		local value = character and character:FindFirstChild('HandInvItem')
		local tool = value and value.Value
		return tool and tool.Name or nil
	end

	local function holdingHoverItem(character)
		local name = heldItem(character)
		if not name then return false end
		name = name:lower()
		for _, needle in HOVER_ITEMS do
			if name:find(needle, 1, true) then return true end
		end
		return false
	end

	local function kitOf(plr)
		return (plr:GetAttribute('PlayingAsKit') or plr:GetAttribute('PlayingAsKits') or '')
	end

	local function entityList()
		local list = {}
		for _, ent in entitylib.List do
			if ent and ent.Character and (ent.RootPart or ent.Character:FindFirstChild('HumanoidRootPart')) and ent.Targetable ~= false then
				table.insert(list, ent)
			end
		end
		if SelfDetect and SelfDetect.Enabled and entitylib.character then
			table.insert(list, {
				Player = Players.LocalPlayer,
				Character = entitylib.character.Character,
				RootPart = entitylib.character.RootPart,
				Humanoid = entitylib.character.Humanoid
			})
		end
		return list
	end

	local function snapshot(ent)
		local plr = ent.Player
		local character = ent.Character
		if not plr or not character or ignored(plr) then return nil end
		local root = ent.RootPart or character:FindFirstChild('HumanoidRootPart')
		local humanoid = character:FindFirstChildOfClass('Humanoid')
		if not root or not root.Parent or not humanoid or humanoid.Health <= 0 then return nil end

		local state = humanoid:GetState()
		local record = {
			Player = plr,
			Character = character,
			Root = root,
			Humanoid = humanoid,
			Position = root.Position,
			Velocity = root.AssemblyLinearVelocity,
			Grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
			Hurt = state == Enum.HumanoidStateType.Physics,
			Seated = state == Enum.HumanoidStateType.Seated,
			HoverItem = holdingHoverItem(character),
			Kit = kitOf(plr),
			Teleported = recentlyCorrected(character),
			Time = now(),
			Previous = records[plr]
		}
		records[plr] = record
		return record
	end

	---------------------------------------------------------------------------
	-- Speed: sustained ground speed above anything the game can produce
	---------------------------------------------------------------------------

	local function median(values)
		local count = #values
		if count == 0 then return 0 end
		local sorted = table.clone(values)
		table.sort(sorted)
		if count % 2 == 1 then return sorted[(count + 1) // 2] end
		return (sorted[count // 2] + sorted[count // 2 + 1]) * 0.5
	end

	local function checkSpeed(record)
		-- Kits that really do move faster are exempt outright, so the limit can stay tight for
		-- everybody else instead of being raised until it stops catching cheaters.
		if SPEED_KITS[record.Kit] then
			speedTracks[record.Player] = nil
			return
		end

		local previous = record.Previous
		if not previous then return end
		local dt = record.Time - previous.Time
		if dt < 0.05 or dt > 0.5 then return end

		local track = speedTracks[record.Player]
		-- A sample only counts while they are running on the ground with nothing speeding them up:
		-- jumps, dashes, knockback and potions all move a player faster than sprinting legally.
		local usable = record.Grounded and not record.Hurt and not record.Teleported
			and not hasEffect(record.Character, MOVEMENT_WORDS)
		if usable then
			local delta = record.Position - previous.Position
			local speed = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt
			if not track then
				track = {start = record.Time, samples = {}}
				speedTracks[record.Player] = track
			end
			table.insert(track.samples, speed)
		end

		if not track then return end
		if record.Time - track.start < SPEED_WINDOW then return end

		local samples = track.samples
		track.start = record.Time
		track.samples = {}
		if #samples < SPEED_SAMPLES then return end

		local above = 0
		for _, speed in samples do
			if speed > SPEED_LIMIT then above += 1 end
		end
		-- The median carries the verdict and the share of samples has to agree with it, so one
		-- spike cannot flag someone and one stumble cannot excuse somebody who is cheating.
		if median(samples) > SPEED_LIMIT and (above / #samples) >= SPEED_SAMPLE_LIMIT then
			flag(record.Player, 'Speed')
		end
	end

	---------------------------------------------------------------------------
	-- Fly: hanging over the void with nothing underneath
	---------------------------------------------------------------------------

	local function overVoid(record)
		groundRay.FilterDescendantsInstances = {record.Character}
		return workspace:Raycast(record.Position, Vector3.new(0, -VOID_DEPTH, 0), groundRay) == nil
	end

	local function checkFly(record)
		local previous = record.Previous
		-- Descending people are falling, not hovering, which is what keeps a legitimate drop off
		-- the map from being read as flight.
		local hovering = not record.Grounded and record.Velocity.Y > -VOID_DESCENT
		if not previous or not hovering or record.Hurt or record.Seated or record.Teleported
			or record.HoverItem or HOVER_KITS[record.Kit]
			or hasEffect(record.Character, MOVEMENT_WORDS) then
			airTracks[record.Player] = nil
			return
		end

		local dt = record.Time - previous.Time
		if dt <= 0 or dt > 0.5 then
			airTracks[record.Player] = nil
			return
		end

		local track = airTracks[record.Player]
		if not track then
			track = {time = 0, moved = 0}
			airTracks[record.Player] = track
		end
		track.time += dt
		track.moved += (record.Position - previous.Position).Magnitude
		if track.time < VOID_TIME then return end

		-- The clock only means anything if there is no ground anywhere under them and they are
		-- actually holding their height rather than being carried by something.
		if record.Humanoid.SeatPart then
			airTracks[record.Player] = nil
			return
		end
		if overVoid(record) and track.moved > 1 then
			flag(record.Player, 'Fly')
		end
		airTracks[record.Player] = nil
	end

	---------------------------------------------------------------------------
	-- AntiDeaths: vertical teleports no velocity can explain
	---------------------------------------------------------------------------

	local function checkAntiDeaths(record)
		local previous = record.Previous
		if not previous then return end
		local dt = record.Time - previous.Time
		if dt <= 0 or dt > 0.5 then return end

		local delta = record.Position - previous.Position
		-- What the replicated velocity says the body should have moved. A jump matches it; a
		-- teleport does not.
		local expected = previous.Velocity * dt
		local unexplained = delta - expected
		if math.abs(unexplained.Y) < TELEPORT_VERTICAL or unexplained.Magnitude < TELEPORT_MARGIN then
			return
		end

		flag(record.Player, 'AntiDeaths')

		-- Deep drops are remembered so the trip back up can be matched to them: going under the
		-- map and straight back up is the signature, and it is worth more than a lone strike.
		if delta.Y <= -UNDER_MAP_DROP then
			antiTracks[record.Player] = {time = record.Time, depth = -delta.Y}
		elseif delta.Y >= UNDER_MAP_DROP then
			local under = antiTracks[record.Player]
			if under and record.Time - under.time <= UNDER_MAP_WINDOW then
				flag(record.Player, 'AntiDeaths', 2)
				antiTracks[record.Player] = nil
			end
		end
	end

	---------------------------------------------------------------------------
	-- Combat: reach, and hits landed while facing away
	---------------------------------------------------------------------------

	-- Split out of the damage handler so the connector tests can feed it a hit directly.
	local function evaluateHit(attackRoot, victimRoot, damageType)
		if damageType ~= 0 then return nil end
		local distance = (attackRoot.Position - victimRoot.Position).Magnitude
		if distance > REACH_LIMIT then
			return 'Reach'
		end

		local direction = victimRoot.Position - attackRoot.Position
		if direction.Magnitude <= 0 then return nil end
		local angle = math.deg(math.acos(math.clamp(attackRoot.CFrame.LookVector:Dot(direction.Unit), -1, 1)))

		local behind = angle >= BEHIND_ANGLE
		local minDistance = behind and BEHIND_DISTANCE or SIDE_DISTANCE
		if angle > SIDE_ANGLE and distance > minDistance then
			return 'Killaura'
		end
		return nil
	end

	local function onDamage(data)
		local attacker = data and data.fromEntity and Players:GetPlayerFromCharacter(data.fromEntity)
		local victim = data and data.entityInstance and Players:GetPlayerFromCharacter(data.entityInstance)
		if not attacker or not victim or attacker == victim or ignored(attacker) then return end
		local attackRoot = data.fromEntity:FindFirstChild('HumanoidRootPart')
		local victimRoot = data.entityInstance:FindFirstChild('HumanoidRootPart')
		if not attackRoot or not victimRoot or not attackRoot.Parent or not victimRoot.Parent then return end

		local reason = evaluateHit(attackRoot, victimRoot, data.damageType)
		if reason and optionEnabled(Combat, reason) then flag(attacker, reason) end
	end

	---------------------------------------------------------------------------
	-- Polling
	---------------------------------------------------------------------------

	local function poll()
		if not CheatDetector.Enabled then return end
		local checkSpeedOn = optionEnabled(Movement, 'Speed')
		local checkFlyOn = optionEnabled(Movement, 'Fly')
		local checkAntiDeathsOn = optionEnabled(Movement, 'AntiDeaths')
		if not (checkSpeedOn or checkFlyOn or checkAntiDeathsOn) then return end

		for _, ent in entityList() do
			local ok, record = pcall(snapshot, ent)
			if ok and record then
				if checkSpeedOn then pcall(checkSpeed, record) end
				if checkFlyOn then pcall(checkFly, record) end
				if checkAntiDeathsOn then pcall(checkAntiDeaths, record) end
			end
		end

		for plr in records do
			if not plr.Parent then
				records[plr] = nil
				speedTracks[plr] = nil
				airTracks[plr] = nil
				antiTracks[plr] = nil
				strikes[plr] = nil
			end
		end
	end

	local function group(name, tooltip)
		local children = {}
		local toggle = CheatDetector:CreateToggle({
			Name = name,
			Tooltip = tooltip,
			Default = true,
			Function = function(callback)
				for _, child in children do
					if child.Object then child.Object.Visible = callback end
				end
			end
		})
		local api = {Toggle = toggle, Options = {}}
		function api:Add(options)
			options.Darker = true
			local option = CheatDetector:CreateToggle(options)
			if option.Object then
				option.Object.Visible = toggle.Enabled == true
			end
			api.Options[options.Name] = option
			table.insert(children, option)
			return option
		end
		return api
	end

	-- The per-check toggles under each group used to be decoration: the checks read the group
	-- header and nothing else. The poll and damage paths now ask this before running one.
	local function optionEnabled(group, name)
		if not (group and group.Toggle.Enabled) then return false end
		local option = group.Options[name]
		return option == nil or option.Enabled == true
	end

	CheatDetector = vape.Categories.Utility:CreateModule({
		Name = 'CheatDetector',
		Tooltip = 'Flags players whose replicated movement or melee hits cannot actually happen',
		Function = function(callback)
			if pollThread then
				pcall(task.cancel, pollThread)
				pollThread = nil
			end
			table.clear(records)
			table.clear(speedTracks)
			table.clear(airTracks)
			table.clear(antiTracks)
			table.clear(strikes)
			if not callback then return end
			pollThread = task.spawn(function()
				while CheatDetector.Enabled do
					pcall(poll)
					task.wait(POLL)
				end
			end)
			CheatDetector:Clean(pollThread)
			if not CheatDetector.DamageConnection then
				CheatDetector.DamageConnection = vapeEvents.EntityDamageEvent.Event:Connect(function(data)
					if CheatDetector.Enabled then pcall(onDamage, data) end
				end)
				CheatDetector:Clean(CheatDetector.DamageConnection)
			end
		end
	})

	-- The decision functions are kept reachable so the checks can be exercised with synthetic
	-- records (the connector tests do exactly that) without needing a live match.
	CheatDetector.Checks = {
		Reach = evaluateHit,
		SpeedLimit = SPEED_LIMIT,
		ReachLimit = REACH_LIMIT,
		SpeedKits = SPEED_KITS
	}

	Combat = group('Combat checks', 'Reach and hits landed while facing away')
	Combat:Add({Name = 'Reach', Default = true})
	Combat:Add({Name = 'Killaura', Default = true})
	Movement = group('Movement checks', 'Speed, hovering over the void and vertical teleports')
	Movement:Add({Name = 'Speed', Default = true})
	Movement:Add({Name = 'Fly', Default = true})
	Movement:Add({Name = 'AntiDeaths', Default = true})
	SelfDetect = CheatDetector:CreateToggle({
		Name = '[TEST] Detect self',
		Default = false,
		Tooltip = 'Includes your own character in scans so you can verify detections'
	})
end)
