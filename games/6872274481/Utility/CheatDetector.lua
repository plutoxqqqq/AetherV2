run(function()
	local CheatDetector
	local SelfDetect

	local RunService = cloneref(game:GetService('RunService'))
	local Players = cloneref(game:GetService('Players'))

	local POLL = 0.12
	local STRIKE_MEMORY = 45
	local MAX_PING = 0.3
	local REACH_BASE = 14.4
	local REACH_LIMIT = 16.5
	local HITBOX_MIN = 6
	local ANGLE_MELEE = 70
	local ANGLE_RANGED = 50
	local SPEED_LIMIT = 22
	local SPEED_WINDOW = 1.6
	local TELEPORT_STEP = 100
	local VERTICAL_REVERSAL = 25
	local FLY_TIME = 2.5
	local FLY_GROUND = 85

	local REQUIRED = {
		Reach = 3,
		Hitbox = 3,
		Aimbot = 3,
		Killaura = 3,
		AutoClicker = 3,
		Speed = 4,
		Fly = 4,
		Teleport = 2,
		AntiDeath = 2
	}

	local strikes = {}
	local records = {}
	local speedTracks = {}
	local airTracks = {}
	local verticalTracks = {}
	local hitHistory = {}
	local pollThread
	-- Forward declarations because poll() is defined before the option groups exist.
	local Movement
	local Blatant

	local MOVEMENT_WORDS = {'speed', 'jump', 'haste', 'fury', 'strength', 'swift', 'agility', 'slow'}
	local groundRay = RaycastParams.new()
	groundRay.FilterType = Enum.RaycastFilterType.Exclude

	local function now()
		return tick()
	end

	local function isSelf(plr)
		return plr == Players.LocalPlayer
	end

	local function ignored(plr)
		if not plr or not plr.Parent then return true end
		if isSelf(plr) and not (SelfDetect and SelfDetect.Enabled) then return true end
		return CheatersFlagged[plr] == true
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

	local function flag(plr, reason)
		if ignored(plr) then return end
		local entry = strikes[plr]
		if not entry then entry = {}; strikes[plr] = entry end
		local list = entry[reason]
		if not list then list = {}; entry[reason] = list end
		local t = now()
		table.insert(list, t)
		for index = #list, 1, -1 do
			if t - list[index] > STRIKE_MEMORY then table.remove(list, index) end
		end
		if #list < (REQUIRED[reason] or 3) then return end
		CheatersFlagged[plr] = true
		whitelist.customtags[plr.Name] = {{text = 'CHEATER', color = Color3.fromRGB(235, 60, 60)}}
		if notif then notif('CheatDetector', tostring(plr.Name)..' flagged: '..reason, 8, 'alert') end
		persist(plr, reason)
		table.clear(entry)
	end

	-- Only attributes that actually describe a status effect are considered, which stops
	-- unrelated attributes such as Health from granting a free pass to every movement check.
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

	local function recentlyCorrected(character)
		return character:GetAttribute('LastTeleported') ~= nil or character:GetAttribute('LastServerCorrected') ~= nil
	end

	local function weaponReach(plr)
		local inventory = store.inventories and store.inventories[plr]
		local hand = inventory and inventory.hand
		local meta = hand and bedwars.ItemMeta and bedwars.ItemMeta[hand.itemType]
		local range = meta and meta.sword and tonumber(meta.sword.attackRange)
		return range or REACH_BASE
	end

	local function entityList()
		local list = {}
		for _, ent in entitylib.List do
			if ent and ent.Character and (ent.RootPart or ent.Character:FindFirstChild('HumanoidRootPart')) and ent.Targetable ~= false then
				table.insert(list, ent)
			end
		end
		if SelfDetect and SelfDetect.Enabled and entitylib.character then
			table.insert(list, {Player = Players.LocalPlayer, Character = entitylib.character.Character, RootPart = entitylib.character.RootPart})
		end
		return list
	end

	local function snapshot(ent)
		local plr = ent.Player
		local character = ent.Character
		if not plr or not character or ignored(plr) then return nil end
		local root = ent.RootPart or character:FindFirstChild('HumanoidRootPart')
		local humanoid = character:FindFirstChildOfClass('Humanoid')
		if not root or not humanoid or humanoid.Health <= 0 then return nil end
		local previous = records[plr]
		local record = {
			Player = plr,
			Character = character,
			Root = root,
			Humanoid = humanoid,
			Position = root.Position,
			Velocity = root.AssemblyLinearVelocity,
			Grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
			Hurt = humanoid:GetState() == Enum.HumanoidStateType.Physics,
			Time = now(),
			Teleported = recentlyCorrected(character),
			Previous = previous
		}
		records[plr] = record
		return record
	end

	local function checkSpeed(record)
		local previous = record.Previous
		if not previous then return end
		local dt = record.Time - previous.Time
		if dt < 0.05 or dt > 0.5 then return end
		if record.Teleported or record.Hurt or hasEffect(record.Character, MOVEMENT_WORDS) then return end
		local delta = record.Position - previous.Position
		local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local speed = horizontal / dt
		local track = speedTracks[record.Player]
		if not track then
			track = {start = record.Time, total = 0, high = 0, count = 0}
			speedTracks[record.Player] = track
		end
		track.total += speed
		track.count += 1
		if speed > SPEED_LIMIT then track.high += 1 end
		if record.Time - track.start >= SPEED_WINDOW then
			local average = track.count > 0 and (track.total / track.count) or 0
			if average > SPEED_LIMIT and track.count > 0 and (track.high / track.count) >= 0.7 then
				flag(record.Player, 'Speed')
			end
			track.start, track.total, track.high, track.count = record.Time, 0, 0, 0
		end
	end

	local function checkFly(record)
		local previous = record.Previous
		if not previous then return end
		if record.Grounded or record.Hurt or record.Teleported or hasEffect(record.Character, MOVEMENT_WORDS) then
			airTracks[record.Player] = nil
			return
		end
		local moved = (record.Position - previous.Position).Magnitude > 0.05
		local floating = record.Velocity.Y > -2
		local track = airTracks[record.Player] or 0
		if moved and floating then
			track += record.Time - previous.Time
		else
			track = 0
		end
		airTracks[record.Player] = track
		if track < FLY_TIME then return end
		groundRay.FilterDescendantsInstances = {record.Character}
		local hit = workspace:Raycast(record.Position, Vector3.new(0, -FLY_GROUND, 0), groundRay)
		if not hit then
			flag(record.Player, 'Fly')
			airTracks[record.Player] = 0
		end
	end

	local function checkTeleport(record)
		local previous = record.Previous
		if not previous or record.Teleported or record.Hurt then return end
		if (record.Position - previous.Position).Magnitude > TELEPORT_STEP then
			flag(record.Player, 'Teleport')
		end
	end

	-- AntiDeath and similar modules fight the void by repeatedly reversing vertically or
	-- bouncing across the map floor. Three reversals inside eight seconds is not human.
	local function checkAntiDeath(record)
		local previous = record.Previous
		if not previous then return end
		local track = verticalTracks[record.Player]
		if not track then
			track = {sign = 0, reversals = {}, lastY = record.Position.Y}
			verticalTracks[record.Player] = track
		end
		local delta = record.Position.Y - previous.Position.Y
		local sign = delta > 0 and 1 or (delta < 0 and -1 or 0)
		if sign ~= 0 then
			if track.sign ~= 0 and sign ~= track.sign and math.abs(record.Position.Y - track.lastY) > VERTICAL_REVERSAL then
				table.insert(track.reversals, record.Time)
			end
			track.sign = sign
			track.lastY = record.Position.Y
		end
		for index = #track.reversals, 1, -1 do
			if record.Time - track.reversals[index] > 8 then table.remove(track.reversals, index) end
		end
		if #track.reversals >= 3 then
			flag(record.Player, 'AntiDeath')
			table.clear(track.reversals)
		end
	end

	local function onDamage(data)
		local attacker = data and data.fromEntity and Players:GetPlayerFromCharacter(data.fromEntity)
		local victim = data and data.entityInstance and Players:GetPlayerFromCharacter(data.entityInstance)
		if not attacker or not victim or ignored(attacker) then return end
		local attackRoot = data.fromEntity:FindFirstChild('HumanoidRootPart')
		local victimRoot = data.entityInstance:FindFirstChild('HumanoidRootPart')
		if not attackRoot or not victimRoot then return end
		local distance = (attackRoot.Position - victimRoot.Position).Magnitude
		local direction = victimRoot.Position - attackRoot.Position
		local angle = 0
		if direction.Magnitude > 0 then
			angle = math.deg(math.acos(math.clamp(attackRoot.CFrame.LookVector:Dot(direction.Unit), -1, 1)))
		end

		if data.damageType == 0 then
			local reach = math.max(weaponReach(attacker) + 1.5, REACH_LIMIT)
			if distance > reach then
				flag(attacker, 'Reach')
			elseif distance > HITBOX_MIN and angle > ANGLE_MELEE then
				flag(attacker, 'Hitbox')
			end
			local t = now()
			local history = hitHistory[attacker]
			if not history then history = {}; hitHistory[attacker] = history end
			table.insert(history, {time = t, victim = victim})
			for index = #history, 1, -1 do
				if t - history[index].time > 2.5 then table.remove(history, index) end
			end
			if #history >= 6 then
				local intervals = {}
				for index = 2, #history do table.insert(intervals, history[index].time - history[index - 1].time) end
				local minimum, maximum = math.huge, 0
				for _, interval in intervals do
					minimum = math.min(minimum, interval)
					maximum = math.max(maximum, interval)
				end
				if minimum < 0.2 and (maximum - minimum) <= 0.03 then
					flag(attacker, 'AutoClicker')
				end
			end
			local seen, victims = {}, 0
			for _, hit in history do
				if not seen[hit.victim] then seen[hit.victim] = true; victims += 1 end
			end
			if victims >= 3 and (t - history[1].time) <= 1.2 then
				flag(attacker, 'Killaura')
			end
		elseif distance >= 30 and angle > ANGLE_RANGED then
			flag(attacker, 'Aimbot')
		end
	end

	local function poll()
		if not CheatDetector.Enabled then return end
		local ping = select(2, pcall(function() return Players.LocalPlayer:GetNetworkPing() end))
		local laggy = type(ping) == 'number' and ping > MAX_PING
		for _, ent in entityList() do
			local ok, record = pcall(snapshot, ent)
			if ok and record then
				if not laggy then
					if Movement.Toggle.Enabled then
						pcall(checkSpeed, record)
						pcall(checkFly, record)
						pcall(checkTeleport, record)
					end
					if Blatant.Toggle.Enabled then
						pcall(checkAntiDeath, record)
					end
				end
			end
		end
		for plr in records do
			if not plr.Parent then
				records[plr] = nil
				speedTracks[plr] = nil
				airTracks[plr] = nil
				verticalTracks[plr] = nil
				hitHistory[plr] = nil
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
		Tooltip = 'Flags players for reach, killaura, speed, fly, teleport and void-abuse behaviour',
		Function = function(callback)
			if pollThread then
				pcall(task.cancel, pollThread)
				pollThread = nil
			end
			table.clear(records)
			table.clear(speedTracks)
			table.clear(airTracks)
			table.clear(verticalTracks)
			table.clear(hitHistory)
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
	local Combat = group('Combat checks', 'Reach, hitbox and aim anomalies')
	Combat:Add({Name = 'Reach', Default = true})
	Combat:Add({Name = 'Hitbox expansion', Default = true})
	Combat:Add({Name = 'Aimbot', Default = true})
	Combat:Add({Name = 'Killaura cadence', Default = true})
	Movement = group('Movement checks', 'Speed, fly and teleport anomalies')
	Movement:Add({Name = 'Speed', Default = true})
	Movement:Add({Name = 'Fly', Default = true})
	Movement:Add({Name = 'Teleport', Default = true})
	local Input = group('Input checks', 'Auto-clicker timing')
	Input:Add({Name = 'AutoClicker', Default = true})
	Blatant = group('Blatant checks', 'Void abuse and impossible vertical teleports')
	Blatant:Add({Name = 'AntiDeath', Default = true})
	SelfDetect = CheatDetector:CreateToggle({
		Name = '[TEST] Detect self',
		Default = false,
		Tooltip = 'Includes your own character in scans so you can verify detections'
	})
end)
