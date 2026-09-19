run(function()
	local AutoFortify
	local Layers
	local Debug
	local fortified = {}
	local fortifyRemote

	-- The Builder's hammer ability, straight from the pack's client wrapper (which finds it anywhere in
	-- ReplicatedStorage) with the raw instance kept as the way out if the wrapper ever stops carrying it.
	local function getRemote()
		if fortifyRemote then return fortifyRemote end

		local ok, remote = pcall(function() return bedwars.Client:Get('FortifyBlock') end)
		fortifyRemote = ok and remote or nil
		return fortifyRemote
	end

	local function fortify(remote, position)
		if type(remote.SendToServer) == 'function' then
			return pcall(remote.SendToServer, remote, position)
		end
		if remote.instance then
			return pcall(function() remote.instance:FireServer(position) end)
		end
		return false
	end

	-- The stack it checks: a pyramid of cells sitting on the bed, which is the shape the hammer fortifies.
	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end

	local function getMyBedCFrame()
		local team = lplr:GetAttribute('Team')
		if not team then return nil end

		for _, bed in collectionService:GetTagged('bed') do
			if bed and bed.Parent and bed:GetAttribute('Team'..team..'NoBreak') then
				return bed:IsA('BasePart') and bed.CFrame or (bed.PrimaryPart and bed.PrimaryPart.CFrame or bed:GetPivot())
			end
		end
		return nil
	end

	local function fortifyPass(bedCFrame)
		local remote = getRemote()
		if not remote then return end

		for layer = 0, Layers.Value - 1 do
			local pending = false
			for _, pos in getPyramid(layer + 1, 3) do
				if not AutoFortify.Enabled then return end

				local block, roundedPos = getPlacedBlock((bedCFrame * CFrame.new(pos)).Position)
				if block and block.Name ~= 'bed' then
					local key = tostring(roundedPos)
					if fortified[key] ~= block then
						fortify(remote, roundedPos)
						fortified[key] = block
						pending = true
						task.wait(0.05)
					end
				end
			end

			if pending then
				-- One layer per pass: the stack above the bed changes as the fortify lands, so the next layer
				-- is read fresh on the next pass instead of being aimed at a stale map.
				return
			end
		end
	end

	AutoFortify = kits:CreateModule({
		Name = 'AutoFortify',
		Function = function(callback)
			if not callback then
				table.clear(fortified)
				return
			end

			task.spawn(function()
				table.clear(fortified)
				repeat
					if entitylib.isAlive then
						local bedCFrame = getMyBedCFrame()
						if bedCFrame then
							local ok, err = pcall(fortifyPass, bedCFrame)
							if not ok and Debug.Enabled then
								notif('AutoFortify', tostring(err), 6, 'warning')
							end
						end
					end
					task.wait(0.1)
				until not AutoFortify.Enabled
			end)
		end,
		Tooltip = "Fortifies the blocks stacked on your bed from anywhere, with the Builder's hammer"
	})

	Layers = AutoFortify:CreateSlider({
		Name = 'Layers',
		Min = 1,
		Max = 10,
		Default = 3,
		Suffix = ' layers',
		Tooltip = 'How tall the pyramid it checks goes. More layers covers more of your stack but takes a little longer'
	})
	Debug = AutoFortify:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Reports fortify failures instead of staying quiet'
	})
end)
