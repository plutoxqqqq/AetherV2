run(function()
	local AutoStyx
	local Range
	local Debug

	-- The Styx flow is three game events and two requests, all reached through the pack's client wrapper.
	local function getRemote(name)
		local ok, remote = pcall(function() return bedwars.Client:Get(name) end)
		return ok and remote or nil
	end

	local function requestOpen(uuid)
		local remote = getRemote('StyxTryOpenExitPortalFromClient')
		if not remote then return false, 'no exit portal request remote' end

		if type(remote.CallServer) == 'function' then
			local ok, result = pcall(remote.CallServer, remote, uuid)
			return ok, result
		end
		if remote.instance then
			local ok, result = pcall(function() return remote.instance:InvokeServer(uuid) end)
			return ok, result
		end
		return false, 'no way to ask for the exit portal'
	end

	local function sendPortal(data)
		local remote = getRemote('UseStyxPortalFromClient')
		if not remote then return false end

		if type(remote.SendToServer) == 'function' then
			return (pcall(remote.SendToServer, remote, {entrancePortalData = data}))
		end
		if remote.instance then
			return (pcall(function() remote.instance:FireServer({entrancePortalData = data}) end))
		end
		return false
	end

	local function describe(payload)
		if type(payload) ~= 'table' then return typeof(payload) end

		local parts = {}
		for key, value in payload do
			parts[#parts + 1] = tostring(key) .. '=' .. typeof(value)
			if #parts >= 8 then break end
		end
		return table.concat(parts, ' ')
	end

	local function report(message)
		if Debug.Enabled then
			notif('AutoStyx', message, 5)
		end
	end

	local function enemyInRange()
		if not entitylib.isAlive then return false end

		local position = entitylib.character.RootPart.Position
		for _, v in entitylib.List do
			if v.Targetable and v.RootPart and (v.RootPart.Position - position).Magnitude <= Range.Value then
				return true
			end
		end
		return false
	end

	AutoStyx = kits:CreateModule({
		Name = 'AutoStyx',
		Function = function(callback)
			if not callback then return end

			local exitPortalUUID = ''
			local entrancePortalData

			local entrance = getRemote('StyxSpawnEntrancePortalFromServer')
			if entrance then
				AutoStyx:Clean(entrance:Connect(function(payload)
					local data = type(payload) == 'table' and (payload.entrancePortalData or payload) or nil
					if type(data) == 'table' and (data.player == lplr or data.player == lplr.Character) then
						entrancePortalData = data
						report('Entrance portal ready (' .. describe(payload) .. ')')
					end
				end))
			end

			local exit = getRemote('StyxSpawnExitPortalFromServer')
			if exit then
				AutoStyx:Clean(exit:Connect(function(payload)
					local data = type(payload) == 'table' and (payload.exitPortalData or payload) or nil
					local uuid = type(data) == 'table' and (data.uuid or data.Uuid) or nil
					if not uuid then
						report('Exit portal event with no uuid (' .. describe(payload) .. ')')
						return
					end

					exitPortalUUID = uuid
					report('Exit portal ready (' .. describe(payload) .. ')')

					task.spawn(function()
						repeat task.wait(0.1) until not AutoStyx.Enabled or enemyInRange()
						if not AutoStyx.Enabled or exitPortalUUID == '' then return end

						local ok, result = requestOpen(exitPortalUUID)
						report(ok and ('Opened the exit portal (' .. tostring(result) .. ')') or ('Could not open the exit portal: ' .. tostring(result)))
					end)
				end))
			end

			local used = getRemote('StyxOpenExitPortalFromServer')
			if used then
				AutoStyx:Clean(used:Connect(function(payload)
					report('Exit portal used (' .. describe(payload) .. ')')
					if not entrancePortalData then return end

					task.wait(0.1)
					sendPortal(entrancePortalData)
				end))
			end
		end,
		Tooltip = 'Opens the exit portal the moment an enemy comes near, and carries your entrance portal through it'
	})

	Range = AutoStyx:CreateSlider({
		Name = 'Range',
		Tooltip = 'Enemy distance that opens the portal',
		Min = 1,
		Max = 30,
		Default = 10
	})
	Debug = AutoStyx:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Reports each portal event and what its payload held, so a changed game payload is visible'
	})
end)
