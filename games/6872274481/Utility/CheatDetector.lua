run(function()
	local CheatDetector
	local SelfTest
	local toggles = {}

	-- How often every tracked body is sampled, how long a position is remembered, and how much
	-- score a single reason may add before the flag is raised.
	local SAMPLE_STEP = 0.05
	local HISTORY_TIME = 2
	local FLAG_SCORE = 70
	local SCORE_DECAY = 1.2
	local REASON_LIFE = 25
	local REASON_COOLDOWN = 6

	-- AntiDeaths: a position snap the replicated velocity cannot explain. A normal jump moves with
	-- its velocity, so the displacement it leaves behind is tiny; even the softest AntiDeath drops
	-- or lifts the body a few studs instantly, which shows up here as unexplained vertical travel.
	local TELEPORT_VERTICAL = 4
	local TELEPORT_MARGIN = 3
	-- A deep drop followed by the same rise inside this window is the classic "under the map and
	-- straight back up" dodge, and is worth more than a lone strike.
	local UNDER_MAP_DROP = 25
	local UNDER_MAP_WINDOW = 2

	local tips = {
		Speed = 'catches ppl movin way too fast',
		Reach = 'catches ppl hittin u from too far away',
		Killaura = 'catches ppl hittin mad fast or behind them',
		Fly = 'catches ppl floatin in the air',
		AntiDeaths = 'catches ppl teleportin out of a death they should not have survived'
	}

	local history = {}
	local meta = {}
	local score = {}
	local flagged = {}
	local reachStreak = {}
	local airTime = {}
	local speedTime = {}
	local kaData = {}
	local antiTracks = {}

	local function resetPlayer(plr)
		history[plr] = nil
		meta[plr] = nil
		score[plr] = nil
		reachStreak[plr] = nil
		airTime[plr] = nil
		speedTime[plr] = nil
		kaData[plr] = nil
		antiTracks[plr] = nil
	end

	local function resetAll()
		table.clear(history)
		table.clear(meta)
		table.clear(score)
		table.clear(flagged)
		table.clear(reachStreak)
		table.clear(airTime)
		table.clear(speedTime)
		table.clear(kaData)
		table.clear(antiTracks)
	end

	local function isOn(name)
		local t = toggles[name]
		return t and t.Enabled
	end

	-- whitelist:get hands the targetable flag back in its second value, the same value the game
	-- reads before it lets a hit through, so anyone it marks untargetable is left alone here too.
	local function whitelisted(plr)
		local ok, targetable = pcall(function()
			return select(2, whitelist:get(plr))
		end)
		return ok and targetable == false
	end

	-- Friends, manual whitelist entries and anyone already reported are never accused again: a
	-- false tag on somebody the user asked not to touch is worse than a miss.
	local function ignored(plr)
		if not plr or not plr.Parent then return true end
		if plr == lplr and not (SelfTest and SelfTest.Enabled) then return true end
		if CheatersFlagged[plr] then return true end
		if isFriend(plr) then return true end
		if whitelisted(plr) then return true end
		return false
	end

	local function notSelf(plr)
		return not ignored(plr)
	end

	local function getEntities()
		if SelfTest and SelfTest.Enabled and entitylib.character then
			local list = table.clone(entitylib.List)
			table.insert(list, entitylib.character)
			return list
		end
		return entitylib.List
	end

	-- The flagged players are written to disk and into the session's cheater list, and the tag the
	-- rest of the pack colours them with, so one verdict is visible everywhere.
	local function persist(plr, reason)
		pcall(function()
			if isfolder and not isfolder('aetherv2') then makefolder('aetherv2') end
			local path = 'aetherv2/exploiters.json'
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

	local function flagPlayer(plr, reasons)
		local key = tostring(plr)
		local now = os.clock()
		if flagged[key] and now < flagged[key] then return end
		flagged[key] = now + 20

		CheatersFlagged[plr] = true
		pcall(function()
			whitelist.customtags[plr.Name] = {{text = 'CHEATER', color = Color3.fromRGB(235, 60, 60)}}
		end)
		persist(plr, reasons)
		notif('CheatDetector', 'yo '..(plr.DisplayName or plr.Name)..' is prob cheatin -> '..reasons, 12, 'alert')
	end

	local function addScore(plr, amount, reason, label)
		if not plr or ignored(plr) then return end
		local now = os.clock()
		local s = score[plr]
		if not s then
			s = {value = 0, seen = {}, labels = {}, last = now}
			score[plr] = s
		end
		if s.seen[reason] and now - s.seen[reason] < REASON_COOLDOWN then return end
		s.seen[reason] = now
		s.labels[reason] = label
		s.value = s.value + amount
		if s.value >= FLAG_SCORE then
			local list = {}
			for r in s.labels do
				list[#list + 1] = s.labels[r]
			end
			table.sort(list)
			flagPlayer(plr, table.concat(list, ' + '))
			s.value = 0
			table.clear(s.seen)
			table.clear(s.labels)
		end
	end

	local function pushSample(plr, ent)
		local root = ent.RootPart
		if not root then return end
		local h = history[plr]
		if not h then
			h = {}
			history[plr] = h
		end
		local now = os.clock()
		local cf = root.CFrame
		h[#h + 1] = {t = now, pos = cf.Position, look = cf.LookVector, vel = root.AssemblyLinearVelocity}
		while h[1] and now - h[1].t > HISTORY_TIME do
			table.remove(h, 1)
		end
	end

	local function trackMeta(plr, ent)
		local now = os.clock()
		local m = meta[plr]
		if not m then
			m = {spawn = now, lastMove = now, lastDamaged = 0, char = ent.Character}
			meta[plr] = m
		end
		if m.char ~= ent.Character then
			m.char = ent.Character
			m.spawn = now
			m.lastMove = now
			m.lastPos = nil
			history[plr] = nil
			reachStreak[plr] = nil
			airTime[plr] = nil
			speedTime[plr] = nil
			antiTracks[plr] = nil
		end
		local root = ent.RootPart
		if root then
			if not m.lastPos or (root.Position - m.lastPos).Magnitude > 0.05 then
				m.lastMove = now
			end
			m.lastPos = root.Position
		end
		return m
	end

	local function getHumanoid(ent)
		if ent.Humanoid then return ent.Humanoid end
		return ent.Character and ent.Character:FindFirstChildOfClass('Humanoid')
	end

	-- Everything the game does on its own that could look like cheating: spawn protection, standing
	-- still, balloons, a server correction, a stun, a dash window, or a local connection too poor to
	-- judge from. Nothing is measured while any of these is in play.
	local function trusted(plr, ent)
		if not plr or not ent then return false end
		local char = ent.Character
		local root = ent.RootPart
		if not char or not root or not char.Parent or not root.Parent then return false end
		local m = meta[plr]
		if not m then return false end
		local now = os.clock()
		if now - m.spawn < 3 then return false end
		if now - m.lastMove > 0.35 then return false end
		local hum = getHumanoid(ent)
		if not hum or hum.Health <= 0 then return false end
		if (char:GetAttribute('InflatedBalloons') or 0) > 0 then return false end
		local serverNow = workspace:GetServerTimeNow()
		if serverNow - (plr:GetAttribute('LastTeleported') or 0) < 1.5 then return false end
		local stun = char:GetAttribute('StunnedUntilTime')
		if stun and stun > serverNow - 1 then return false end
		local dashNext = char:GetAttribute('CanDashNext')
		if dashNext and dashNext > serverNow then return false end
		if lplr:GetNetworkPing() > 0.15 then return false end
		local h = history[plr]
		if not h or #h < 8 then return false end
		return true
	end

	local function minDistanceTo(plr, point, window)
		local h = history[plr]
		if not h or #h == 0 then return nil end
		local now = os.clock()
		local best
		for i = #h, 1, -1 do
			local s = h[i]
			if now - s.t > window then break end
			local d = (s.pos - point).Magnitude
			if not best or d < best then best = d end
		end
		return best
	end

	local function minPairDistance(a, b, window)
		local ha, hb = history[a], history[b]
		if not ha or not hb then return nil end
		local now = os.clock()
		local best
		for i = #ha, 1, -1 do
			if now - ha[i].t > window then break end
			for j = #hb, 1, -1 do
				if now - hb[j].t > window then break end
				if math.abs(ha[i].t - hb[j].t) <= 0.12 then
					local d = (ha[i].pos - hb[j].pos).Magnitude
					if not best or d < best then best = d end
				end
			end
		end
		return best
	end

	-- The sample from roughly one network round trip ago, so a hit is judged against where both
	-- bodies were when the attacker's client decided to swing.
	local function recentSample(plr)
		local h = history[plr]
		if not h or #h == 0 then return nil end
		local ping = math.clamp(lplr:GetNetworkPing() * 0.5, 0, 0.3)
		local target = os.clock() - ping
		local best, bestDiff
		for i = #h, 1, -1 do
			local diff = math.abs(h[i].t - target)
			if not bestDiff or diff < bestDiff then
				best = h[i]
				bestDiff = diff
			end
		end
		return best
	end

	local function getAttackRange(plr)
		-- The held tool is replicated on the character, so read it there first; the inventory
		-- snapshot is only a fallback for the moment before it replicates.
		local name
		local character = plr.Character
		local hand = character and character:FindFirstChild('HandInvItem')
		local tool = hand and hand.Value
		name = tool and tool.Name
		if not name then
			local inv = store.inventories[plr]
			local handEntry = inv and inv.hand
			name = handEntry and handEntry.tool and handEntry.tool.Name
		end
		if not name then return nil end
		local itemMeta = bedwars.ItemMeta[name]
		local swordMeta = itemMeta and itemMeta.sword
		if not swordMeta then return nil end
		return swordMeta.attackRange
	end

	local function blockedByMap(fromPos, toPos)
		local dir = toPos - fromPos
		local dist = dir.Magnitude
		if dist < 3 then return false end
		-- cloneRaycast() excludes every body, so only the map can answer this.
		local hit = workspace:Raycast(fromPos, dir.Unit * (dist - 1.5), cloneRaycast())
		if not hit then return false end
		return (hit.Position - fromPos).Magnitude < dist - 2
	end

	local function kaState(plr)
		local d = kaData[plr]
		if not d then
			d = {targets = {}, intervals = {}, lastHit = 0, angleHits = {}, wallHits = {}}
			kaData[plr] = d
		end
		return d
	end

	local function pruneStamps(list, life)
		local now = os.clock()
		for i = #list, 1, -1 do
			if now - list[i] > life then table.remove(list, i) end
		end
		return #list
	end

	local function checkReach(attacker, victimPlr, victimPos, fromPosition)
		if not isOn('Reach') then return end
		local range = getAttackRange(attacker)
		if not range then return end

		local best
		if fromPosition then
			if victimPlr then
				best = minDistanceTo(victimPlr, fromPosition, 0.8)
			elseif victimPos then
				best = (victimPos - fromPosition).Magnitude
			end
		end
		if victimPlr then
			local paired = minPairDistance(attacker, victimPlr, 0.8)
			if paired and (not best or paired < best) then best = paired end
		end
		if not best then return end

		local allowance = range + 2.5 + math.min(lplr:GetNetworkPing(), 0.2) * 30
		if best > allowance then
			reachStreak[attacker] = (reachStreak[attacker] or 0) + 1
			if reachStreak[attacker] >= 3 then
				reachStreak[attacker] = 0
				addScore(attacker, 45, 'reach', 'reach ('..string.format('%.1f', best)..' studs, max is '..string.format('%.1f', allowance)..')')
			end
		else
			reachStreak[attacker] = 0
		end
	end

	local function checkKillaura(attacker, victimInstance, victimPlr, victimPos, fromPosition)
		if not isOn('Killaura') then return end
		local d = kaState(attacker)
		local now = os.clock()

		d.targets[victimInstance] = now
		local distinct = 0
		for inst, t in d.targets do
			if now - t <= 0.35 then
				distinct = distinct + 1
			else
				d.targets[inst] = nil
			end
		end
		if distinct >= 2 then
			addScore(attacker, 40, 'multi', 'killaura (hit '..distinct..' ppl at once)')
		end

		-- A machine swing cadence has no human jitter: the gaps between hits stay within a few
		-- percent of their own average, which no person clicking produces.
		if d.lastHit > 0 then
			local gap = now - d.lastHit
			if gap > 0.04 and gap < 1.2 then
				d.intervals[#d.intervals + 1] = gap
				while #d.intervals > 16 do
					table.remove(d.intervals, 1)
				end
				if #d.intervals >= 12 then
					local sum = 0
					for _, g in d.intervals do sum = sum + g end
					local mean = sum / #d.intervals
					local varSum = 0
					for _, g in d.intervals do varSum = varSum + (g - mean) ^ 2 end
					local sd = math.sqrt(varSum / #d.intervals)
					if mean > 0.05 and sd / mean < 0.07 then
						addScore(attacker, 45, 'timing', 'killaura (hits perfectly on beat, no human jitter)')
						table.clear(d.intervals)
					end
				end
			end
		end
		d.lastHit = now

		local attackerSample = recentSample(attacker)
		local origin = attackerSample and attackerSample.pos or fromPosition
		local look = attackerSample and attackerSample.look
		local targetPos = victimPos
		if victimPlr then
			local vs = recentSample(victimPlr)
			if vs then targetPos = vs.pos end
		end

		if origin and look and targetPos then
			local flatLook = look * Vector3.new(1, 0, 1)
			local flatDir = (targetPos - origin) * Vector3.new(1, 0, 1)
			if flatLook.Magnitude > 0.001 and flatDir.Magnitude > 0.001 then
				local angle = math.deg(math.acos(math.clamp(flatLook.Unit:Dot(flatDir.Unit), -1, 1)))
				if angle > 75 then
					d.angleHits[#d.angleHits + 1] = now
					if pruneStamps(d.angleHits, 15) >= 4 then
						table.clear(d.angleHits)
						addScore(attacker, 35, 'angle', 'killaura (swingin at ppl behind them)')
					end
				end
			end

			if blockedByMap(origin, targetPos) then
				d.wallHits[#d.wallHits + 1] = now
				if pruneStamps(d.wallHits, 15) >= 3 then
					table.clear(d.wallHits)
					addScore(attacker, 40, 'wall', 'killaura (hittin straight thru blocks)')
				end
			end
		end
	end

	local function onMeleeDamage(dmg)
		if not CheatDetector.Enabled then return end
		if dmg.damageType ~= 0 then return end
		if not dmg.fromEntity or not dmg.entityInstance then return end

		local attacker = playersService:GetPlayerFromCharacter(dmg.fromEntity)
		if not attacker or not notSelf(attacker) then return end

		local victimPlr = playersService:GetPlayerFromCharacter(dmg.entityInstance)
		if victimPlr then
			local vm = meta[victimPlr]
			if vm then vm.lastDamaged = os.clock() end
		end

		local victimRoot = dmg.entityInstance.PrimaryPart or dmg.entityInstance:FindFirstChild('HumanoidRootPart')
		local victimPos = victimRoot and victimRoot.Position

		local am = meta[attacker]
		if not am or os.clock() - am.spawn < 3 then return end
		if lplr:GetNetworkPing() > 0.15 then return end

		checkReach(attacker, victimPlr, victimPos, dmg.fromPosition)
		checkKillaura(attacker, dmg.entityInstance, victimPlr, victimPos, dmg.fromPosition)
	end

	-- Fly: hanging off the ground with almost no vertical speed while still travelling sideways is
	-- a hover, not a fall.
	local function checkFly(plr, ent, dt, rayParams)
		if not isOn('Fly') then
			airTime[plr] = 0
			return
		end
		local root = ent.RootPart
		-- Every entry of a ray filter has to be an instance, so the local body is only added while
		-- there is one; a respawning player would otherwise break the cast with a nil slot.
		local ignore = {ent.Character, gameCamera}
		if lplr.Character then table.insert(ignore, lplr.Character) end
		rayParams.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -250, 0), rayParams)
		local groundDist = hit and (root.Position.Y - hit.Position.Y) or 250
		local vel = root.AssemblyLinearVelocity
		local horizontal = (vel * Vector3.new(1, 0, 1)).Magnitude

		if groundDist > 8 and math.abs(vel.Y) < 3 and horizontal > 2 then
			airTime[plr] = (airTime[plr] or 0) + dt
			if airTime[plr] >= 1.75 then
				airTime[plr] = 0
				addScore(plr, 50, 'fly', 'fly (hoverin '..math.floor(groundDist)..' studs off the ground)')
			end
		else
			airTime[plr] = 0
		end
	end

	local function checkSpeed(plr, ent, dt)
		if not isOn('Speed') then
			speedTime[plr] = 0
			return
		end
		local m = meta[plr]
		-- Being hit is a free pass: knockback and the hit's own momentum are not the player moving.
		if m and os.clock() - (m.lastDamaged or 0) < 1.5 then
			speedTime[plr] = 0
			return
		end
		local h = history[plr]
		if not h or #h < 8 then
			speedTime[plr] = 0
			return
		end

		local now = os.clock()
		local newest, oldest, prev
		local maxStep = 0
		for i = #h, 1, -1 do
			local s = h[i]
			if now - s.t > 0.5 then break end
			if not newest then newest = s end
			if prev then
				local step = ((prev.pos - s.pos) * Vector3.new(1, 0, 1)).Magnitude
				if step > maxStep then maxStep = step end
			end
			prev = s
			oldest = s
		end

		if not newest or not oldest then
			speedTime[plr] = 0
			return
		end
		local span = newest.t - oldest.t
		-- A single huge step is a teleport, not sustained speed, so it is left to AntiDeaths.
		if span < 0.3 or maxStep > 8 then
			speedTime[plr] = 0
			return
		end

		local travelled = ((newest.pos - oldest.pos) * Vector3.new(1, 0, 1)).Magnitude
		local speed = travelled / span
		if speed > 34 then
			speedTime[plr] = (speedTime[plr] or 0) + dt
			if speedTime[plr] >= 1.2 then
				speedTime[plr] = 0
				addScore(plr, 45, 'speed', 'speed ('..math.floor(speed)..' studs a sec)')
			end
		else
			speedTime[plr] = 0
		end
	end

	-- AntiDeaths: compare the movement between the two newest samples with what the replicated
	-- velocity asked for, exactly as the pack always did, but feed it into the score instead of a
	-- strike table. Three of these inside the reason's life is what raises the flag.
	local function checkAntiDeaths(plr)
		if not isOn('AntiDeaths') then
			antiTracks[plr] = nil
			return
		end
		local h = history[plr]
		if not h or #h < 2 then return end

		local latest, previous = h[#h], h[#h - 1]
		local dt = latest.t - previous.t
		if dt <= 0 or dt > 0.5 then return end

		local delta = latest.pos - previous.pos
		local unexplained = delta - (previous.vel * dt)
		if math.abs(unexplained.Y) < TELEPORT_VERTICAL or unexplained.Magnitude < TELEPORT_MARGIN then
			return
		end

		addScore(plr, 30, 'antideaths', 'antideaths (moved '..string.format('%.1f', math.abs(unexplained.Y))..' studs with no velocity behind it)')

		if delta.Y <= -UNDER_MAP_DROP then
			antiTracks[plr] = {time = latest.t, depth = -delta.Y}
		elseif delta.Y >= UNDER_MAP_DROP then
			local under = antiTracks[plr]
			if under and latest.t - under.time <= UNDER_MAP_WINDOW then
				addScore(plr, 45, 'antideaths', 'antideaths (dropped '..math.floor(under.depth)..' studs and came straight back)')
				antiTracks[plr] = nil
			end
		end
	end

	local function decayScores(dt)
		local now = os.clock()
		for plr, s in score do
			s.last = now
			s.value = math.max(0, s.value - SCORE_DECAY * dt)
			for reason, t in s.seen do
				if now - t > REASON_LIFE then
					s.seen[reason] = nil
					s.labels[reason] = nil
				end
			end
			if s.value <= 0 and not next(s.seen) then
				score[plr] = nil
			end
		end
	end

	CheatDetector = vape.Categories.Utility:CreateModule({
		Name = 'CheatDetector',
		Tooltip = 'Flags possible cheaters',
		Function = function(callback)
			if callback then
				resetAll()

				CheatDetector:Clean(playersService.PlayerRemoving:Connect(function(plr)
					resetPlayer(plr)
					flagged[tostring(plr)] = nil
				end))

				CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(dmg)
					pcall(onMeleeDamage, dmg)
				end))

				task.spawn(function()
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					local last = os.clock()
					local decayAccum = 0
					repeat
						local now = os.clock()
						local dt = now - last
						last = now
						decayAccum = decayAccum + dt

						for _, ent in getEntities() do
							local plr = ent.Player
							if plr and notSelf(plr) and ent.RootPart and ent.Character then
								trackMeta(plr, ent)
								pushSample(plr, ent)
								if trusted(plr, ent) then
									checkFly(plr, ent, dt, rayParams)
									checkSpeed(plr, ent, dt)
								else
									airTime[plr] = 0
									speedTime[plr] = 0
								end
								-- AntiDeaths is the one check that must not stand down for a server
								-- correction: being snapped back into place is the thing it looks for.
								checkAntiDeaths(plr)
							end
						end

						if decayAccum >= 1 then
							decayScores(decayAccum)
							decayAccum = 0
						end

						task.wait(SAMPLE_STEP)
					until not CheatDetector.Enabled
					resetAll()
				end)
			else
				resetAll()
			end
		end
	})

	SelfTest = CheatDetector:CreateToggle({
		Name = 'Self',
		Default = false,
		Tooltip = 'Test on yourself'
	})

	for _, name in {'Speed', 'Reach', 'Killaura', 'Fly', 'AntiDeaths'} do
		toggles[name] = CheatDetector:CreateToggle({
			Name = name,
			Default = true,
			Tooltip = tips[name]
		})
	end
end)
