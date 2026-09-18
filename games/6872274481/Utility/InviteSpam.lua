run(function()
	local InviteSpam
	local invitedPlayers = {}
	local partyMembers = {}
	local inviteRemote
	local partyEventConnection
	local storeChangedConnection

	-- The party invite remote lives inside the lobby's net-managed folder, and that folder only
	-- exists once the lobby scripts have finished replicating. Resolving it lazily (and with a
	-- bounded wait) keeps switching the module on instant instead of yielding inside the pack, and
	-- keeps a game server - where the lobby remotes never appear - from ever blocking a thread.
	local function getInviteRemote()
		if inviteRemote then return inviteRemote end
		local ok, remote = pcall(function()
			local folder = replicatedStorage:FindFirstChild('rbxts_include')
			folder = folder and folder:FindFirstChild('node_modules')
			folder = folder and folder:FindFirstChild('@rbxts')
			folder = folder and folder:FindFirstChild('net')
			folder = folder and folder:FindFirstChild('out')
			folder = folder and folder:FindFirstChild('_NetManaged')
			local events = folder and folder:FindFirstChild('lobby-events@getEvents.Events')
			return events and events:FindFirstChild('inviteToParty') or nil
		end)
		inviteRemote = ok and remote or nil
		return inviteRemote
	end

	local function invitePlayer(player)
		if player == lplr then return end
		if invitedPlayers[player.UserId] then return end
		invitedPlayers[player.UserId] = true
		task.spawn(function()
			local remote = getInviteRemote()
			if not remote then
				invitedPlayers[player.UserId] = nil
				return
			end
			local success = pcall(function()
				remote:InvokeServer({player = player})
			end)
			if not success then
				-- Let the next pass try again rather than writing the player off for the session.
				invitedPlayers[player.UserId] = nil
			end
		end)
	end

	local function inviteAllPlayers()
		for _, player in ipairs(playersService:GetPlayers()) do
			invitePlayer(player)
		end
	end

	local function getPartyState()
		if not bedwars.Store or type(bedwars.Store.getState) ~= 'function' then return nil end
		local ok, state = pcall(bedwars.Store.getState, bedwars.Store)
		return ok and type(state) == 'table' and state or nil
	end

	local function getPartyMemberNames()
		local state = getPartyState()
		local party = state and state.Party
		if not party or not party.members then return {} end
		local names = {}
		for _, member in ipairs(party.members) do
			table.insert(names, member.name or member.displayName or 'Unknown')
		end
		return names
	end

	local function checkPartyChanges()
		local currentMembers = getPartyMemberNames()
		local oldMembers = partyMembers
		for _, name in ipairs(currentMembers) do
			if not table.find(oldMembers, name) then
				notif('InviteSpam', name..' joined your party', 3)
			end
		end
		for _, name in ipairs(oldMembers) do
			if not table.find(currentMembers, name) then
				notif('InviteSpam', name..' left your party', 3)
			end
		end
		partyMembers = currentMembers
	end

	local function disconnectParty()
		if storeChangedConnection then
			pcall(function() storeChangedConnection:disconnect() end)
			storeChangedConnection = nil
		end
		if partyEventConnection then
			pcall(function() partyEventConnection:Disconnect() end)
			partyEventConnection = nil
		end
	end

	InviteSpam = vape.Categories.Utility:CreateModule({
		Name = 'InviteSpam',
		Tooltip = 'Spam invites everyone in your server',
		Function = function(callback)
			if callback then
				invitedPlayers = {}
				partyMembers = {}

				inviteAllPlayers()

				if bedwars.Store and bedwars.Store.changed and type(bedwars.Store.changed.connect) == 'function' then
					storeChangedConnection = bedwars.Store.changed:connect(function(newState, oldState)
						if newState.Party ~= oldState.Party then
							checkPartyChanges()
						end
					end)
				end

				-- Best effort: the lobby pushes party updates through this event when it exists, and
				-- the store signal above already covers the game server.
				pcall(function()
					local folder = replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events']
					local event = folder and folder.partyInfoEvent
					if event then
						partyEventConnection = event.OnClientEvent:Connect(function()
							checkPartyChanges()
						end)
					end
				end)

				task.wait(0.5)
				checkPartyChanges()

				InviteSpam:Clean(function()
					disconnectParty()
					invitedPlayers = {}
					partyMembers = {}
				end)
			else
				disconnectParty()
				invitedPlayers = {}
				partyMembers = {}
			end
		end
	})
end)
