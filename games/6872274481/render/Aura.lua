run(function()
	local Aura
	local nimConnections = {}
	local nimFolder = nil
	local nimHighlight = nil
	local nimParts = {}
	local nimExtra = {}
	local nimH, nimS, nimV = 0.65, 1, 1
	local nimSpeed = 1.5
	local nimStyle = 'randomshi'
	local nimOrbCount = 8
	local nimMode = 'Solid'
	local nimOrbCountSlider = nil

	local function removeAura()
		for _, conn in nimConnections do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(nimConnections)
		table.clear(nimParts)
		table.clear(nimExtra)
		if nimFolder then
			pcall(function() nimFolder:Destroy() end)
			nimFolder = nil
		end
		if nimHighlight then
			pcall(function() nimHighlight:Destroy() end)
			nimHighlight = nil
		end
	end

	local function makePart(size, shape)
		local p = Instance.new('Part')
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Size = size or Vector3.new(0.45, 0.45, 0.45)
		if shape then p.Shape = shape end
		p.Parent = nimFolder
		return p
	end

	local function makeHighlight(character, fillTrans)
		local hl = Instance.new('Highlight')
		hl.Adornee = character
		hl.OutlineTransparency = 0
		hl.FillTransparency = fillTrans or 0.78
		hl.OutlineColor = Color3.fromHSV(nimH, nimS, nimV)
		hl.FillColor = Color3.fromHSV(nimH, nimS, nimV)
		hl.Parent = nimFolder
		return hl
	end

	local setups = {
		['randomshi'] = function(character)
			nimHighlight = makeHighlight(character, 0.75)
			for i = 1, nimOrbCount do
				local orb = makePart(Vector3.new(0.5, 0.5, 0.5), Enum.PartType.Ball)
				orb:SetAttribute('I', i)
				orb:SetAttribute('TIER', 1)
				table.insert(nimParts, orb)
			end
			local innerCount = math.max(3, math.floor(nimOrbCount * 0.6))
			for i = 1, innerCount do
				local orb = makePart(Vector3.new(0.28, 0.28, 0.28), Enum.PartType.Ball)
				orb:SetAttribute('I', i)
				orb:SetAttribute('TIER', 2)
				orb:SetAttribute('COUNT', innerCount)
				table.insert(nimExtra, orb)
			end
		end,
		['Saiyan'] = function(character)
			nimHighlight = makeHighlight(character, 0.55)
			nimHighlight.OutlineTransparency = 0.1
			for i = 1, 32 do
				local fl = makePart(Vector3.new(0.13, 0.8 + math.random() * 0.7, 0.13))
				fl:SetAttribute('TYPE', 'flame')
				fl:SetAttribute('AO', (i / 32) * math.pi * 2 + math.random() * 0.3)
				fl:SetAttribute('RO', 0.6 + math.random() * 0.8)
				fl:SetAttribute('SP', 2.5 + math.random() * 3.5)
				fl:SetAttribute('YO', math.random() * 5)
				fl:SetAttribute('LN', 0.5 + math.random() * 1.1)
				table.insert(nimParts, fl)
			end
			for i = 1, 18 do
				local ember = makePart(Vector3.new(0.1, 0.1, 0.1), Enum.PartType.Ball)
				ember:SetAttribute('TYPE', 'ember')
				ember:SetAttribute('AO', (i / 18) * math.pi * 2)
				ember:SetAttribute('RO', 0.4 + math.random() * 1.6)
				ember:SetAttribute('SP', 3 + math.random() * 4)
				ember:SetAttribute('YO', math.random() * 4)
				table.insert(nimExtra, ember)
			end
		end,
		['Storm'] = function(character)
			nimHighlight = makeHighlight(character, 0.94)
			nimHighlight.OutlineTransparency = 0.65
			local cloudOffsets = {
				Vector3.new(-2.2,5.2,0.3),Vector3.new(-1.1,5.6,-0.2),Vector3.new(0,5.9,0.4),
				Vector3.new(1.1,5.6,-0.3),Vector3.new(2.2,5.2,0.2),Vector3.new(-1.7,6.1,0.5),
				Vector3.new(-0.6,6.5,-0.3),Vector3.new(0.5,6.7,0.4),Vector3.new(1.6,6.2,-0.2),
				Vector3.new(-1.0,7.0,0.3),Vector3.new(0.0,7.3,-0.4),Vector3.new(1.0,6.9,0.2),
				Vector3.new(-2.0,5.3,-0.6),Vector3.new(0.1,5.4,-0.7),Vector3.new(1.9,5.3,-0.5),
				Vector3.new(-0.4,6.3,0.7),Vector3.new(0.5,6.0,-0.6),Vector3.new(0,5.7,0),
				Vector3.new(-1.5,5.0,0.8),Vector3.new(1.5,5.0,-0.8),Vector3.new(0,4.8,0.6),
			}
			for _, offset in cloudOffsets do
				local cloud = makePart(Vector3.new(1.3 + math.random()*0.8, 1.1 + math.random()*0.6, 1.2 + math.random()*0.7), Enum.PartType.Ball)
				cloud.Color = Color3.new(0.28, 0.28, 0.38)
				cloud.Material = Enum.Material.SmoothPlastic
				cloud.Transparency = 0.1 + math.random() * 0.18
				cloud:SetAttribute('TYPE', 'cloud')
				cloud:SetAttribute('OX', offset.X)
				cloud:SetAttribute('OY', offset.Y)
				cloud:SetAttribute('OZ', offset.Z)
				cloud:SetAttribute('BOB', math.random() * math.pi * 2)
				table.insert(nimParts, cloud)
			end
			for i = 1, 55 do
				local rain = makePart(Vector3.new(0.03, 0.45, 0.03))
				rain.Color = Color3.new(0.65, 0.82, 1)
				rain.Transparency = 0.28
				rain:SetAttribute('TYPE', 'rain')
				rain:SetAttribute('RX', (math.random() - 0.5) * 6.5)
				rain:SetAttribute('RZ', (math.random() - 0.5) * 6.5)
				rain:SetAttribute('RY', math.random() * 7)
				rain:SetAttribute('SPD', 6 + math.random() * 6)
				rain:SetAttribute('DRIFT', (math.random() - 0.5) * 0.5)
				table.insert(nimParts, rain)
			end
			for i = 1, 5 do
				local bolt = makePart(Vector3.new(0.05, 4.5, 0.05))
				bolt.Color = Color3.new(0.88, 0.88, 1)
				bolt.Transparency = 1
				bolt:SetAttribute('TYPE', 'lightning')
				bolt:SetAttribute('LX', (math.random() - 0.5) * 3)
				bolt:SetAttribute('LZ', (math.random() - 0.5) * 3)
				bolt:SetAttribute('NEXT', math.random() * 3 + 0.5)
				bolt:SetAttribute('FLASH', 0)
				table.insert(nimExtra, bolt)
			end
		end,
		['Sakura'] = function(character)
			nimHighlight = makeHighlight(character, 0.86)
			for i = 1, 24 do
				local petal = makePart(Vector3.new(0.32, 0.06, 0.28))
				petal.Color = Color3.fromHSV(0.92, 0.55, 1)
				petal:SetAttribute('TYPE', 'drift')
				petal:SetAttribute('AO', (i / 24) * math.pi * 2 + math.random() * 0.5)
				petal:SetAttribute('RD', 1.2 + math.random() * 2.0)
				petal:SetAttribute('YO', (math.random() - 0.3) * 6)
				petal:SetAttribute('DS', 0.4 + math.random() * 0.7)
				petal:SetAttribute('SW', math.random() * math.pi * 2)
				table.insert(nimParts, petal)
			end
			for i = 1, 14 do
				local petal = makePart(Vector3.new(0.28, 0.06, 0.24))
				petal.Color = Color3.fromHSV(0.93, 0.6, 1)
				petal:SetAttribute('TYPE', 'burst')
				local angle = math.random() * math.pi * 2
				local elev = (math.random() - 0.3) * math.pi * 0.6
				petal:SetAttribute('DX', math.cos(elev) * math.cos(angle))
				petal:SetAttribute('DY', math.sin(elev) * 0.6 + 0.25)
				petal:SetAttribute('DZ', math.cos(elev) * math.sin(angle))
				petal:SetAttribute('DIST', math.random() * 4)
				petal:SetAttribute('SPD', 1.2 + math.random() * 1.5)
				petal:SetAttribute('PHASE', math.random() * math.pi * 2)
				table.insert(nimExtra, petal)
			end
		end,
		['randomshi2'] = function(character)
			nimHighlight = makeHighlight(character, 0.45)
			nimHighlight.OutlineTransparency = 0.05
			for i = 1, 28 do
				local node = makePart(Vector3.new(0.28, 0.28, 0.28), Enum.PartType.Ball)
				node:SetAttribute('TYPE', 'ring')
				node:SetAttribute('I', i)
				node:SetAttribute('PH', (i / 28) * math.pi * 2)
				table.insert(nimParts, node)
			end
			for i = 1, 20 do
				local particle = makePart(Vector3.new(0.18, 0.18, 0.18), Enum.PartType.Ball)
				particle:SetAttribute('TYPE', 'spiral')
				particle:SetAttribute('ANGLE', (i / 20) * math.pi * 2)
				particle:SetAttribute('RADIUS', 2 + math.random() * 2)
				particle:SetAttribute('YO', (math.random() - 0.5) * 4)
				particle:SetAttribute('SPD', 0.5 + math.random() * 0.8)
				table.insert(nimParts, particle)
			end
			for i = 1, 16 do
				local frag = makePart(Vector3.new(0.15, 0.15, 0.15))
				frag:SetAttribute('TYPE', 'debris')
				frag:SetAttribute('AO', (i / 16) * math.pi * 2)
				frag:SetAttribute('RD', 2.5 + math.random() * 1.5)
				frag:SetAttribute('YO', (math.random() - 0.5) * 4)
				frag:SetAttribute('SP', 0.4 + math.random() * 0.6)
				table.insert(nimExtra, frag)
			end
		end,
		['Seraph'] = function(character)
			nimHighlight = makeHighlight(character, 0.8)
			local cometTilts = {0, math.pi / 3, math.pi * 2 / 3, math.pi / 5}
			local cometPhases = {0, math.pi / 2, math.pi, math.pi * 3 / 2}
			for c = 1, 4 do
				for j = 0, 8 do
					local sz = math.max(0.08, 0.5 - j * 0.045)
					local part = makePart(Vector3.new(sz, sz, sz), Enum.PartType.Ball)
					part:SetAttribute('COMET', c)
					part:SetAttribute('TRAIL', j)
					part:SetAttribute('TILT', cometTilts[c])
					part:SetAttribute('PHASE', cometPhases[c])
					table.insert(nimParts, part)
				end
			end
		end,
		['randomshi3'] = function(character)
			nimHighlight = makeHighlight(character, 0.42)
			nimHighlight.OutlineTransparency = 0.0
			for i = 1, 22 do
				local wisp = makePart(Vector3.new(0.18, 0.55, 0.18), Enum.PartType.Ball)
				wisp:SetAttribute('TYPE', 'wisp')
				wisp:SetAttribute('AO', (i / 22) * math.pi * 2 + math.random() * 0.4)
				wisp:SetAttribute('RO', 0.5 + math.random() * 1.2)
				wisp:SetAttribute('SP', 1.2 + math.random() * 2)
				wisp:SetAttribute('YO', math.random() * 6)
				table.insert(nimParts, wisp)
			end
			for i = 1, 14 do
				local frag = makePart(Vector3.new(0.25, 0.06, 0.2))
				frag:SetAttribute('TYPE', 'fragment')
				frag:SetAttribute('AO', (i / 14) * math.pi * 2)
				frag:SetAttribute('RD', 1.8 + math.random() * 1.4)
				frag:SetAttribute('YO', (math.random() - 0.5) * 2.5)
				frag:SetAttribute('SP', 0.6 + math.random() * 0.8)
				table.insert(nimExtra, frag)
			end
			local ring = makePart(Vector3.new(0.08, 0.08, 0.08))
			ring:SetAttribute('TYPE', 'deathring')
			ring:SetAttribute('RAD', 0)
			table.insert(nimExtra, ring)
		end,
		['snakers'] = function(character)
			nimHighlight = makeHighlight(character, 0.6)
			nimHighlight.OutlineTransparency = 0.05
			for i = 1, 36 do
				local scale = makePart(Vector3.new(0.35, 0.2, 0.25))
				scale:SetAttribute('TYPE', 'scale')
				scale:SetAttribute('I', i)
				scale:SetAttribute('TOTAL', 36)
				table.insert(nimParts, scale)
			end
			for i = 1, 20 do
				local ember = makePart(Vector3.new(0.12, 0.12, 0.12), Enum.PartType.Ball)
				ember:SetAttribute('TYPE', 'breath')
				ember:SetAttribute('AO', (i / 20) * math.pi * 2)
				ember:SetAttribute('DIST', math.random() * 5)
				ember:SetAttribute('SPD', 1.5 + math.random() * 2)
				ember:SetAttribute('YO', (math.random() - 0.5) * 3)
				table.insert(nimExtra, ember)
			end
		end,
	}

	local animators = {
		['randomshi'] = function(t, dt, base, col)
			local count = nimOrbCount
			local radius = 3.5
			for _, orb in nimParts do
				local i = orb:GetAttribute('I')
				local angle = (i / count) * math.pi * 2 + t * nimSpeed
				local x = math.cos(angle) * radius
				local z = math.sin(angle) * radius
				local y = math.sin(t * 2.5 + i * 0.8) * 0.5
				local pulse = 0.42 + math.abs(math.sin(t * 3 + i)) * 0.3
				local sz = 0.35 + pulse * 0.25
				local h = (i / count + t * 0.08) % 1
				pcall(function()
					orb.CFrame = CFrame.new(base + Vector3.new(x, y, z))
					orb.Color = Color3.fromHSV(h, 1, 1)
					orb.Size = Vector3.new(sz, sz, sz)
				end)
			end
			for _, orb in nimExtra do
				local i = orb:GetAttribute('I')
				local cnt = orb:GetAttribute('COUNT') or math.max(3, math.floor(nimOrbCount * 0.6))
				local angle = (i / cnt) * math.pi * 2 - t * nimSpeed * 1.4
				local r2 = 1.8
				local x = math.cos(angle) * r2
				local z = math.sin(angle) * r2
				local y = math.sin(t * 3.5 + i * 1.2) * 0.3
				local h = (i / cnt + t * 0.12) % 1
				pcall(function()
					orb.CFrame = CFrame.new(base + Vector3.new(x, y, z))
					orb.Color = Color3.fromHSV(h, 1, 1)
				end)
			end
		end,
		['Saiyan'] = function(t, dt, base, col)
			for _, p in nimParts do
				local typ = p:GetAttribute('TYPE')
				if typ == 'flame' then
					local ao = p:GetAttribute('AO')
					local ro = p:GetAttribute('RO')
					local sp = p:GetAttribute('SP')
					local yo = p:GetAttribute('YO')
					local ln = p:GetAttribute('LN')
					yo = yo + dt * sp * nimSpeed
					if yo > 5 then yo = 0 end
					p:SetAttribute('YO', yo)
					local wobble = math.sin(t * 3.5 + ao) * 0.22
					local flicker = math.sin(t * 8 + ao * 2) * 0.06
					local rx = math.cos(ao + wobble) * (ro + flicker)
					local rz = math.sin(ao + wobble) * (ro + flicker)
					local fade = yo / 5
					local fireH = 0.04 - (1 - fade) * 0.04
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(rx, yo - 1.8, rz))
						p.Color = Color3.fromHSV(fireH, 1, 0.7 + fade * 0.3)
						p.Transparency = math.clamp(fade * 1.1, 0, 0.92)
						p.Size = Vector3.new(0.09 + (1 - fade) * 0.1, ln * (1 - fade * 0.4), 0.09 + (1 - fade) * 0.1)
					end)
				end
			end
			for _, p in nimExtra do
				local typ = p:GetAttribute('TYPE')
				if typ == 'ember' then
					local ao = p:GetAttribute('AO')
					local ro = p:GetAttribute('RO')
					local sp = p:GetAttribute('SP')
					local yo = p:GetAttribute('YO')
					yo = yo + dt * sp * nimSpeed * 0.7
					if yo > 4 then yo = 0 end
					p:SetAttribute('YO', yo)
					local drift = math.sin(t * 2 + ao) * 0.3
					local rx = math.cos(ao + drift) * ro
					local rz = math.sin(ao + drift) * ro
					local fade = yo / 4
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(rx, yo - 1.5, rz))
						p.Color = Color3.fromHSV(0.06 + fade * 0.05, 1, 1)
						p.Transparency = math.clamp(fade * 1.3, 0, 1)
					end)
				end
			end
		end,
		['Storm'] = function(t, dt, base, col)
			for _, p in nimParts do
				local typ = p:GetAttribute('TYPE')
				if typ == 'cloud' then
					local ox = p:GetAttribute('OX')
					local oy = p:GetAttribute('OY')
					local oz = p:GetAttribute('OZ')
					local bob = p:GetAttribute('BOB')
					local drift = math.sin(t * 0.3 + bob) * 0.18
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(ox + drift * 0.3, oy + math.sin(t * 0.6 + bob) * 0.14, oz + drift * 0.15))
					end)
				elseif typ == 'rain' then
					local rx = p:GetAttribute('RX')
					local rz = p:GetAttribute('RZ')
					local ry = p:GetAttribute('RY')
					local spd = p:GetAttribute('SPD')
					local driftV = p:GetAttribute('DRIFT')
					ry = ry - dt * spd * nimSpeed
					if ry < -1.5 then ry = 7 end
					p:SetAttribute('RY', ry)
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(rx + driftV * t * 0.1, ry, rz)) * CFrame.Angles(0.08, 0, 0)
					end)
				end
			end
			for _, bolt in nimExtra do
				local flash = bolt:GetAttribute('FLASH')
				local nextTime = bolt:GetAttribute('NEXT')
				if flash > 0 then
					flash = flash - dt
					if flash <= 0 then
						flash = 0
						bolt:SetAttribute('NEXT', 1.5 + math.random() * 4)
					end
					pcall(function() bolt.Transparency = math.clamp(flash * 7, 0, 1) end)
					bolt:SetAttribute('FLASH', flash)
				else
					nextTime = nextTime - dt
					bolt:SetAttribute('NEXT', nextTime)
					if nextTime <= 0 then
						for _, b in nimExtra do
							local lx = (math.random() - 0.5) * 3.5
							local lz = (math.random() - 0.5) * 3.5
							b:SetAttribute('FLASH', 0.18 + math.random() * 0.12)
							b:SetAttribute('LX', lx)
							b:SetAttribute('LZ', lz)
							pcall(function()
								b.CFrame = CFrame.new(base + Vector3.new(lx, 2.25, lz))
								b.Transparency = 0
							end)
						end
						break
					else
						pcall(function() bolt.Transparency = 1 end)
					end
				end
			end
		end,
		['Sakura'] = function(t, dt, base, col)
			for _, petal in nimParts do
				local typ = petal:GetAttribute('TYPE')
				if typ == 'drift' then
					local ao = petal:GetAttribute('AO')
					local rd = petal:GetAttribute('RD')
					local yo = petal:GetAttribute('YO')
					local ds = petal:GetAttribute('DS')
					local sw = petal:GetAttribute('SW')
					yo = yo + dt * ds * nimSpeed
					if yo > 5.5 then yo = -1.5 end
					petal:SetAttribute('YO', yo)
					local sway = math.sin(t * 1.8 + sw) * 0.7
					local rx = math.cos(ao + sway * 0.25) * (rd + sway * 0.15)
					local rz = math.sin(ao + sway * 0.25) * (rd + sway * 0.15)
					local normalizedY = (yo + 1.5) / 7
					local fade = math.clamp(normalizedY * 1.3, 0, 0.85)
					pcall(function()
						petal.CFrame = CFrame.new(base + Vector3.new(rx, yo, rz)) * CFrame.Angles(math.sin(t + sw) * 0.6, ao + t * 0.4, math.cos(t * 0.8 + sw) * 0.6)
						petal.Color = Color3.fromHSV(0.92, 0.55 + math.sin(t * 0.5 + ao) * 0.08, 1)
						petal.Transparency = fade
					end)
				end
			end
			for _, petal in nimExtra do
				local typ = petal:GetAttribute('TYPE')
				if typ == 'burst' then
					local dx = petal:GetAttribute('DX')
					local dy = petal:GetAttribute('DY')
					local dz = petal:GetAttribute('DZ')
					local dist = petal:GetAttribute('DIST')
					local spd = petal:GetAttribute('SPD')
					dist = dist + dt * spd * nimSpeed
					if dist > 4.5 then
						dist = 0
						local angle = math.random() * math.pi * 2
						local elev = (math.random() - 0.3) * math.pi * 0.5
						petal:SetAttribute('DX', math.cos(elev) * math.cos(angle))
						petal:SetAttribute('DY', math.sin(elev) * 0.55 + 0.28)
						petal:SetAttribute('DZ', math.cos(elev) * math.sin(angle))
					end
					petal:SetAttribute('DIST', dist)
					local fade = dist / 4.5
					pcall(function()
						petal.CFrame = CFrame.new(base + Vector3.new(dx * dist, dy * dist, dz * dist)) * CFrame.Angles(t * spd, t * spd * 0.8, 0)
						petal.Color = Color3.fromHSV(0.92, 0.58, 1)
						petal.Transparency = math.clamp(fade * 1.3, 0, 1)
					end)
				end
			end
		end,
		['randomshi2'] = function(t, dt, base, col)
			for _, node in nimParts do
				local typ = node:GetAttribute('TYPE')
				if typ == 'ring' then
					local ph = node:GetAttribute('PH')
					local portalRadius = 2.8
					local ringX = math.cos(ph) * portalRadius
					local ringY = math.sin(ph) * portalRadius
					local pulse = 0.3 + math.abs(math.sin(t * 1.5 + ph)) * 0.4
					local darkH = (0.75 + (ph / (math.pi * 2)) * 0.15 + t * 0.03) % 1
					pcall(function()
						node.CFrame = CFrame.new(base + Vector3.new(ringX, ringY + 1, -3.5))
						node.Color = Color3.fromHSV(darkH, 1, pulse)
						node.Size = Vector3.new(0.22 + pulse * 0.12, 0.22 + pulse * 0.12, 0.22 + pulse * 0.12)
					end)
				elseif typ == 'spiral' then
					local angle = node:GetAttribute('ANGLE')
					local radius = node:GetAttribute('RADIUS')
					local yo = node:GetAttribute('YO')
					local spd = node:GetAttribute('SPD')
					radius = radius - dt * spd * nimSpeed * 0.4
					if radius < 0.3 then
						radius = 2 + math.random() * 2
						angle = math.random() * math.pi * 2
						yo = (math.random() - 0.5) * 4
						node:SetAttribute('YO', yo)
						node:SetAttribute('ANGLE', angle)
					end
					angle = angle + dt * nimSpeed * (1.5 / math.max(radius, 0.3))
					node:SetAttribute('RADIUS', radius)
					node:SetAttribute('ANGLE', angle)
					local fade = 1 - (radius / 4)
					local h = (0.75 + t * 0.05) % 1
					pcall(function()
						node.CFrame = CFrame.new(base + Vector3.new(math.cos(angle) * radius, yo, math.sin(angle) * radius))
						node.Color = Color3.fromHSV(h, 1, 0.6 + fade * 0.4)
						node.Transparency = math.clamp(fade * 0.7, 0, 0.9)
					end)
				end
			end
			for _, node in nimExtra do
				local typ = node:GetAttribute('TYPE')
				if typ == 'debris' then
					local ao = node:GetAttribute('AO')
					local rd = node:GetAttribute('RD')
					local yo = node:GetAttribute('YO')
					local sp = node:GetAttribute('SP')
					local angle = ao + t * sp * nimSpeed
					local wobble = math.sin(t * 1.8 + ao) * 0.5
					local h = (0.78 + ao * 0.03 + t * 0.03) % 1
					pcall(function()
						node.CFrame = CFrame.new(base + Vector3.new(math.cos(angle) * rd, yo + wobble, math.sin(angle) * rd)) * CFrame.Angles(t * sp * 2, t * sp, 0)
						node.Color = Color3.fromHSV(h, 1, 0.5 + math.abs(math.sin(t * 2 + ao)) * 0.4)
					end)
				end
			end
		end,
		['Seraph'] = function(t, dt, base, col)
			for _, part in nimParts do
				local c = part:GetAttribute('COMET')
				local j = part:GetAttribute('TRAIL')
				local tilt = part:GetAttribute('TILT')
				local phase = part:GetAttribute('PHASE')
				local angle = phase + t * nimSpeed * 1.4 - j * 0.18
				local radius = 3.2
				local fx = math.cos(angle) * radius
				local fy = math.sin(angle) * radius * math.sin(tilt)
				local fz = math.sin(angle) * radius * math.cos(tilt)
				local h = (c / 4 + t * 0.1) % 1
				local fade = j / 8
				pcall(function()
					part.CFrame = CFrame.new(base + Vector3.new(fx, fy, fz))
					part.Color = Color3.fromHSV(h, 1, 1 - fade * 0.3)
					part.Transparency = fade * 0.9
				end)
			end
		end,
		['randomshi3'] = function(t, dt, base, col)
			for _, p in nimParts do
				local typ = p:GetAttribute('TYPE')
				if typ == 'wisp' then
					local ao = p:GetAttribute('AO')
					local ro = p:GetAttribute('RO')
					local sp = p:GetAttribute('SP')
					local yo = p:GetAttribute('YO')
					yo = yo + dt * sp * nimSpeed * 0.55
					if yo > 6 then yo = 0 end
					p:SetAttribute('YO', yo)
					local sway = math.sin(t * 1.4 + ao) * 0.35
					local rx = math.cos(ao + sway * 0.2) * (ro + sway * 0.12)
					local rz = math.sin(ao + sway * 0.2) * (ro + sway * 0.12)
					local fade = yo / 6
					local h = (0.72 + fade * 0.1) % 1
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(rx, yo - 2, rz))
						p.Color = Color3.fromHSV(h, 0.7 + fade * 0.2, 0.5 + (1 - fade) * 0.4)
						p.Transparency = math.clamp(fade * 1.2, 0, 0.95)
						p.Size = Vector3.new(0.12 + (1 - fade) * 0.1, 0.45 + (1 - fade) * 0.2, 0.12 + (1 - fade) * 0.1)
					end)
				end
			end
			for _, p in nimExtra do
				local typ = p:GetAttribute('TYPE')
				if typ == 'fragment' then
					local ao = p:GetAttribute('AO')
					local rd = p:GetAttribute('RD')
					local yo = p:GetAttribute('YO')
					local sp = p:GetAttribute('SP')
					local angle = ao + t * sp * nimSpeed * 1.2
					local bob = math.sin(t * 2.5 + ao) * 0.4
					local h = (0.75 + t * 0.04 + ao * 0.02) % 1
					local pulse = 0.4 + math.abs(math.sin(t * 2 + ao)) * 0.4
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(math.cos(angle) * rd, yo + bob, math.sin(angle) * rd)) * CFrame.Angles(t * sp * 3, t * sp * 2, math.sin(t + ao))
						p.Color = Color3.fromHSV(h, 0.6, pulse)
						p.Transparency = 0.1 + (1 - pulse) * 0.5
					end)
				elseif typ == 'deathring' then
					local rad = p:GetAttribute('RAD')
					rad = rad + dt * nimSpeed * 1.8
					if rad > 5 then rad = 0 end
					p:SetAttribute('RAD', rad)
					local fade = rad / 5
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(0, -2.2, 0))
						p.Size = Vector3.new(rad * 2, 0.05, rad * 2)
						p.Color = Color3.fromHSV(0.76, 0.8, 0.7)
						p.Transparency = math.clamp(fade, 0.05, 0.97)
					end)
				end
			end
		end,
		['snakers'] = function(t, dt, base, col)
			for _, p in nimParts do
				local typ = p:GetAttribute('TYPE')
				if typ == 'scale' then
					local i = p:GetAttribute('I')
					local total = p:GetAttribute('TOTAL')
					local progress = i / total
					local angle = progress * math.pi * 4 + t * nimSpeed * 0.8
					local helixRadius = 1.5 + math.sin(progress * math.pi) * 0.8
					local helixY = (progress - 0.5) * 6 + math.sin(t * 1.5 + progress * math.pi * 2) * 0.2
					local scaleX = math.cos(angle) * helixRadius
					local scaleZ = math.sin(angle) * helixRadius
					local fireH = math.clamp(0.02 + math.sin(t * 2 + progress * 4) * 0.04, 0, 0.12)
					local fireV = 0.8 + math.sin(t * 4 + i) * 0.2
					local pulse = 0.5 + math.sin(t * 3 + progress * math.pi * 2) * 0.3
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(scaleX, helixY, scaleZ)) * CFrame.Angles(0, angle + math.pi / 2, math.sin(t * 2 + progress) * 0.3)
						p.Color = Color3.fromHSV(fireH, 1, fireV)
						p.Size = Vector3.new(0.25 + pulse * 0.15, 0.14, 0.2 + pulse * 0.1)
						p.Transparency = math.clamp((1 - pulse) * 0.5, 0, 0.6)
					end)
				end
			end
			for _, p in nimExtra do
				local typ = p:GetAttribute('TYPE')
				if typ == 'breath' then
					local ao = p:GetAttribute('AO')
					local dist = p:GetAttribute('DIST')
					local spd = p:GetAttribute('SPD')
					local yo = p:GetAttribute('YO')
					dist = dist + dt * spd * nimSpeed
					if dist > 5.5 then
						dist = 0
						ao = math.random() * math.pi * 2
						yo = (math.random() - 0.5) * 3
						p:SetAttribute('AO', ao)
						p:SetAttribute('YO', yo)
					end
					p:SetAttribute('DIST', dist)
					local fade = dist / 5.5
					local sz = 0.12 + (1 - fade) * 0.12
					pcall(function()
						p.CFrame = CFrame.new(base + Vector3.new(math.cos(ao) * dist, yo, math.sin(ao) * dist))
						p.Color = Color3.fromHSV(0.02 + fade * 0.1, 1, 1)
						p.Size = Vector3.new(sz, sz, sz)
						p.Transparency = math.clamp(fade * 1.2, 0, 1)
					end)
				end
			end
		end,
	}

	local function applyAura()
		removeAura()
		local character = lplr.Character
		if not character then return end
		if not character:FindFirstChild('HumanoidRootPart') then return end

		nimFolder = Instance.new('Folder')
		nimFolder.Name = 'skidAura'
		nimFolder.Parent = workspace

		local setup = setups[nimStyle]
		if setup then setup(character) end

		local t = 0
		local conn = runService.RenderStepped:Connect(function(dt)
			if not Aura or not Aura.Enabled then return end
			t = t + dt

			local char = lplr.Character
			local hrp = char and char:FindFirstChild('HumanoidRootPart')
			if not hrp then return end
			local base = hrp.Position

			local baseColor
			if nimMode == 'Rainbow' then
				baseColor = Color3.fromHSV((t * 0.15) % 1, 1, 1)
			elseif nimMode == 'Pulse' then
				baseColor = Color3.fromHSV(nimH, nimS, 0.5 + math.abs(math.sin(t * 2)) * 0.5)
			else
				baseColor = Color3.fromHSV(nimH, nimS, nimV)
			end

			if nimHighlight then
				pcall(function()
					nimHighlight.OutlineColor = baseColor
					nimHighlight.FillColor = baseColor
				end)
			end

			local anim = animators[nimStyle]
			if anim then anim(t, dt, base, baseColor) end
		end)
		table.insert(nimConnections, conn)

		local charConn = character.AncestryChanged:Connect(function(_, parent)
			if not parent then removeAura() end
		end)
		table.insert(nimConnections, charConn)
	end

	local _auraCharConn
	_auraCharConn = lplr.CharacterAdded:Connect(function()
		if Aura and Aura.Enabled then
			task.wait(1)
			if Aura and Aura.Enabled then
				applyAura()
			end
		end
	end)

	Aura = vape.Categories.Render:CreateModule({
		Name = 'Aura',
		Tooltip = 'skid = aura !! i love this module',
		Function = function(callback)
			if callback then
				applyAura()
			else
				removeAura()
				if _auraCharConn then
					_auraCharConn:Disconnect()
					_auraCharConn = nil
				end
			end
		end
	})

	Aura:CreateDropdown({
		Name = 'Style',
		List = {'randomshi', 'Saiyan', 'Storm', 'Sakura', 'randomshi2', 'Seraph', 'randomshi3', 'snakers'},
		Default = 'randomshi',
		Function = function(val)
			nimStyle = val
			if nimOrbCountSlider then
				nimOrbCountSlider.Visible = (val == 'randomshi')
			end
			if Aura.Enabled then applyAura() end
		end
	})

	Aura:CreateColorSlider({
		Name = 'Color',
		Function = function(h, s, v)
			nimH, nimS, nimV = h, s, v
		end
	})

	Aura:CreateSlider({
		Name = 'Speed',
		Min = 0.5,
		Max = 5,
		Default = 1.5,
		Function = function(val)
			nimSpeed = val
		end
	})

	nimOrbCountSlider = Aura:CreateSlider({
		Name = 'Orb Count',
		Min = 3,
		Max = 20,
		Default = 8,
		Function = function(val)
			nimOrbCount = math.floor(val)
			if Aura.Enabled and nimStyle == 'randomshi' then applyAura() end
		end
	})
end)