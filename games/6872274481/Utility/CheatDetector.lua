run(function()
	local CheatDetector
	local SelfDetect
	local Combat
	local Movement

	local Players = cloneref(game:GetService('Players'))

	---------------------------------------------------------------------------
	-- Tuning
	---------------------------------------------------------------------------
	local POLL = 0.1
	local STRIKE_MEMORY = 45

	-- Nothing here can see the server. Above this much local ping every position this client holds
	-- is too stale to accuse anybody with, so the position checks stand down instead of guessing.
	local MAX_PING = 0.25

	-- CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE is where an ordinary sword's reach sits, and
	-- 24 is the longest attackRange any melee weapon in the game has (whisper feather).
	local REACH_BASE = 14.4
	local MAX_MELEE_RANGE = 24
	-- Interpolation between the server's snapshot and this client's frames, the rounding the server
	-- does on a hit, and the fact that the victim kept moving for the attacker's whole round trip.
	local REACH_MARGIN = 2.5
	local REACH_PER_PING = 20
	local REACH_DRIFT_CAP = 3

	-- A hit that lands more than this far behind the attacker was not aimed, so the only way the
	-- server accepted it is an expanded hitbox.
	local HITBOX_ANGLE = 100

	-- One swing reaches one player, and the shortest attack cooldown in the game is longer than
	-- MULTI_WINDOW, so two victims inside it cannot come from two swings.
	local MULTI_WINDOW = 0.1
	local MULTI_WINDOW_WIDE = 1
	local MULTI_VICTIMS = 3

	-- Sprinting is 20 studs per second before modifiers. 24 leaves room for every legal movement
	-- buff and still sits under what a speed cheat is set to, and the window makes a single
	-- knockback or ability boost irrelevant.
	local SPEED_LIMIT = 24
	local SPEED_WINDOW = 1.5
	local SPEED_SAMPLES = 5
	local SPEED_SAMPLE_LIMIT = 0.85

	-- Hovering this long with no ground underneath is not something the game hands out, except to
	-- the kits and items listed below.
	local FLY_TIME = 3
	local FLY_DESCENT = 1.5
	local FLY_GROUND = 60

	local required = {
		Reach = 3,
		Killaura = 3,
		Speed = 3,
		Fly = 3
	}

	local strikes = {}
	local records = {}
	local speedTracks = {}
	local airTracks = {}
	local hitHistory = {}
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

	local function playerPing(plr)
		local ok, ping = pcall(function()
			return plr:GetNetworkPing()
		end)
		return ok and tonumber(ping) or 0
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
	-- the memory window, so one odd reading is never enough on its own.
	local function flag(plr, reason)
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
		table.insert(list, t)
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

	-- The game marks the characters it has had to move itself.
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

	-- The reach the game itself would have given the weapon they were holding, taken from the hand
	-- the game keeps in HandInvItem rather than the observed inventory, which lags behind.
	local function weaponReach(character)
		local name = heldItem(character)
		local meta = name and bedwars.ItemMeta and bedwars.ItemMeta[name]
		local range = meta and meta.sword and tonumber(meta.sword.attackRange)
		if not range or range <= 0 then range = REACH_BASE end
		return math.clamp(range, REACH_BASE, MAX_MELEE_RANGE)
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
			Time = now(),
			Teleported = recentlyCorrected(character),
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
	-- Fly: sustained hover with no ground underneath
	---------------------------------------------------------------------------

	local function checkFly(record)
		local previous = record.Previous
		local hovering = not record.Grounded and record.Velocity.Y > -FLY_DESCENT
		if not previous or not hovering or record.Hurt or record.Teleported or record.Seated
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
		if track.time < FLY_TIME then return end

		airTracks[record.Player] = nil
		-- Riding or being carried puts something solid under them.
		if record.Humanoid.SeatPart then return end
		groundRay.FilterDescendantsInstances = {record.Character}
		local hit = workspace:Raycast(record.Position, Vector3.new(0, -FLY_GROUND, 0), groundRay)
		if not hit and track.moved > 2 then
			flag(record.Player, 'Fly')
		end
	end

	---------------------------------------------------------------------------
	-- Combat: reach, and one swing reaching more than one player
	---------------------------------------------------------------------------

	local function onDamage(data)
		local attacker = data and data.fromEntity and Players:GetPlayerFromCharacter(data.fromEntity)
		local victim = data and data.entityInstance and Players:GetPlayerFromCharacter(data.entityInstance)
		if not attacker or not victim or attacker == victim or ignored(attacker) then return end
		local attackRoot = data.fromEntity:FindFirstChild('HumanoidRootPart')
		local victimRoot = data.entityInstance:FindFirstChild('HumanoidRootPart')
		if not attackRoot or not victimRoot or not attackRoot.Parent or not victimRoot.Parent then return end

		local distance = (attackRoot.Position - victimRoot.Position).Magnitude
		local ping = math.clamp(playerPing(attacker), 0, MAX_PING)
		local direction = victimRoot.Position - attackRoot.Position
		local angle = 0
		if direction.Magnitude > 0 then
			angle = math.deg(math.acos(math.clamp(attackRoot.CFrame.LookVector:Dot(direction.Unit), -1, 1)))
		end

		if data.damageType ~= 0 then return end

		local reach = weaponReach(data.fromEntity)
		local victimSpeed = Vector3.new(victimRoot.AssemblyLinearVelocity.X, 0, victimRoot.AssemblyLinearVelocity.Z).Magnitude
		local drift = math.min(victimSpeed * ping, REACH_DRIFT_CAP)
		local allowance = reach + REACH_MARGIN + (ping * REACH_PER_PING) + drift

		if Combat.Toggle.Enabled then
			if distance > allowance then
				flag(attacker, 'Reach')
			end

			local t = now()
			local history = hitHistory[attacker]
			if not history then
				history = {}
				hitHistory[attacker] = history
			end
			table.insert(history, {time = t, victim = victim})
			for index = #history, 1, -1 do
				if t - history[index].time > MULTI_WINDOW_WIDE then table.remove(history, index) end
			end

			local closeSeen, seen = {}, {}
			for _, hit in history do
				seen[hit.victim] = true
				if t - hit.time <= MULTI_WINDOW then closeSeen[hit.victim] = true end
			end
			local closeVictims, victims = 0, 0
			for _ in closeSeen do closeVictims += 1 end
			for _ in seen do victims += 1 end

			-- Two different players inside one attack cooldown, or three inside a second, cannot come
			-- from separate swings. A hit landed more than a right angle behind the attacker is the
			-- same signature from the other side: something else picked the target.
			if closeVictims >= 2 or victims >= MULTI_VICTIMS then
				flag(attacker, 'Killaura')
			elseif distance <= allowance and distance > 2 and angle > HITBOX_ANGLE then
				flag(attacker, 'Killaura')
			end
		end
	end

	---------------------------------------------------------------------------
	-- Polling
	---------------------------------------------------------------------------

	local function poll()
		if not CheatDetector.Enabled then return end
		-- Records still have to be refreshed while laggy so the next clean poll compares against a
		-- recent position instead of a stale one.
		local movement = Movement.Toggle.Enabled and playerPing(Players.LocalPlayer) <= MAX_PING
		for _, ent in entityList() do
			local ok, record = pcall(snapshot, ent)
			if ok and record and movement then
				pcall(checkSpeed, record)
				pcall(checkFly, record)
			end
		end

		for plr in records do
			if not plr.Parent then
				records[plr] = nil
				speedTracks[plr] = nil
				airTracks[plr] = nil
				hitHistory[plr] = nil
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
		local api = {Toggle = toggle}
		function api:Add(options)
			options.Darker = true
			local option = CheatDetector:CreateToggle(options)
			if option.Object then
				option.Object.Visible = toggle.Enabled == true
			end
			table.insert(children, option)
			return option
		end
		return api
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
			table.clear(hitHistory)
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
	Combat = group('Combat checks', 'Reach and one-swing-many-victims behaviour')
	Combat:Add({Name = 'Reach', Default = true})
	Combat:Add({Name = 'Killaura', Default = true})
	Movement = group('Movement checks', 'Speed and hover behaviour')
	Movement:Add({Name = 'Speed', Default = true})
	Movement:Add({Name = 'Fly', Default = true})
	SelfDetect = CheatDetector:CreateToggle({
		Name = '[TEST] Detect self',
		Default = false,
		Tooltip = 'Includes your own character in scans so you can verify detections'
	})
end)
