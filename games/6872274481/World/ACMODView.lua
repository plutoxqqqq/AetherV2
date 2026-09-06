run(function()
	
	
	local KnitInit, Knit
	local knitDeadline = tick() + 30
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit and Knit then break end
		task.wait()
	until tick() > knitDeadline
	if not (KnitInit and Knit) then
		error('Knit never became available for the anticheat view module')
	end

	if not debug.getupvalue(Knit.Start, 1) then
		local upvalueDeadline = tick() + 15
		repeat task.wait() until debug.getupvalue(Knit.Start, 1) or tick() > upvalueDeadline
		if not debug.getupvalue(Knit.Start, 1) then
			error('debug.getupvalue is unavailable, so the anticheat view module cannot start')
		end
	end

	local Players = game:GetService("Players")

	shared.PERMISSION_CONTROLLER_HASANYPERMISSIONS_REVERT = shared.PERMISSION_CONTROLLER_HASANYPERMISSIONS_REVERT or Knit.Controllers.PermissionController.hasAnyPermissions
	shared.MATCH_CONTROLLER_GETPLAYERPARTY_REVERT = shared.MATCH_CONTROLLER_GETPLAYERPARTY_REVERT or Knit.Controllers.MatchController.getPlayerParty

	local AC_MOD_View = {
		playerConnections = {},
		Enabled = false,
		Friends = {},
		parties = {},
		teamMap = {},
		display = {},
		isRefreshing = false,
		cacheDirty = true,
		disable_disguises = false,
		disguises = {},
		teamData = {}
	}

	AC_MOD_View.controller = Knit.Controllers.PermissionController
	AC_MOD_View.match_controller = Knit.Controllers.MatchController

	function AC_MOD_View:getPartyById(displayId)
		if not displayId then return end
		displayId = tostring(displayId)
		if self.display[displayId] then return self.display[displayId] end
		for _, party in pairs(self.parties) do
			if party.displayId == tostring(displayId) then
				self.display[displayId] = party
				return party
			end
		end
	end

	function AC_MOD_View:refreshDisplayCache()
		for _, plr in pairs(Players:GetPlayers()) do
			local playerId = tostring(plr.UserId)

			local playerPartyId = self.teamMap[playerId]
			if playerPartyId ~= nil then
				self:getPartyById(playerPartyId)
			end
			task.wait()
		end
	end

	function AC_MOD_View:refreshDisplayCacheAsync()
		task.spawn(self.refreshDisplayCache, self)
	end

	function AC_MOD_View:getPlayerTeamData(plr)
		if self.teamData[plr] then return self.teamData[plr] end

		self.teamData[plr] = {}

		local teamMembers = {}
		local playerTeam = plr.Team
		if not playerTeam then
			return teamMembers
		end

		local playerId = tostring(plr.UserId)
		self.Friends[playerId] = self.Friends[playerId] or {}

		for _, otherPlayer in pairs(Players:GetPlayers()) do
			if otherPlayer == plr then continue end

			local otherPlayerId = tostring(otherPlayer.UserId)
			local areFriends = self.Friends[playerId][otherPlayerId]

			if areFriends == nil then
				local suc, res = pcall(function()
					return plr:IsFriendsWith(otherPlayer.UserId)
				end)
				areFriends = suc and res or false

				if suc then
					self.Friends = self.Friends or {}
					self.Friends[playerId] = self.Friends[playerId] or {}
					self.Friends[playerId][otherPlayerId] = areFriends
					self.Friends[otherPlayerId] = self.Friends[otherPlayerId] or {}
					self.Friends[otherPlayerId][playerId] = areFriends
				end
			end

			if areFriends and otherPlayer.Team == playerTeam then
				table.insert(teamMembers, otherPlayerId)
			end
		end

		self.teamData[plr] = teamMembers

		return teamMembers
	end

	function AC_MOD_View:refreshPlayerTeamData()
		for i,v in pairs(Players:GetPlayers()) do
			self:getPlayerTeamData(v)
			task.wait()
		end
	end

	function AC_MOD_View:refreshPlayerTeamDataAsync()
		task.spawn(self.refreshPlayerTeamData, self)
	end

	function AC_MOD_View:refreshTeamMap()
		local allTeams = {}
		for _, p in pairs(Players:GetPlayers()) do
			local teamMembers = self:getPlayerTeamData(p)
			if teamMembers and #teamMembers > 0 then
				allTeams[p] = teamMembers
			end
		end

		local validTeams = {}
		for playerInTeams, members in pairs(allTeams) do
			local playerIdInTeams = tostring(playerInTeams.UserId)
			local cleanedMembers = {}

			for _, memberId in pairs(members) do
				local memberIdStr = tostring(memberId)
				if memberIdStr == playerIdInTeams then
					
				else
					table.insert(cleanedMembers, memberIdStr)
				end
			end

			if #cleanedMembers > 0 then
				validTeams[playerInTeams] = cleanedMembers
			end
		end

		self.parties = {}
		self.teamMap = {}
		local teamId = 0
		for playerInTeams, members in pairs(validTeams) do
			local playerIdInTeams = tostring(playerInTeams.UserId)
			if not self.teamMap[playerIdInTeams] then
				self.teamMap[playerIdInTeams] = teamId
				table.insert(self.parties, {
					displayId = tostring(teamId),
					members = members
				})
				teamId = teamId + 1

				for _, memberId in pairs(members) do
					self.teamMap[memberId] = teamId - 1
				end
			end
		end

		self.cacheDirty = false
		self.isRefreshing = false
	end

	function AC_MOD_View:refreshTeamMapAsync()
		if self.isRefreshing then return end
		self.isRefreshing = true
		task.spawn(function()
			self:refreshTeamMap()
		end)
	end

	function AC_MOD_View:getPlayerParty(plr)
		if not plr or not plr:IsA("Player") then
			return nil
		end

		local playerId = tostring(plr.UserId)

		if self.cacheDirty or not next(self.teamMap) then
			self:refreshTeamMapAsync()
		end

		local playerPartyId = self.teamMap[playerId]
		if playerPartyId ~= nil then
			return self:getPartyById(playerPartyId)
		end

		return nil
	end

	AC_MOD_View.mockGetPlayerParty = function(self, plr)
		local parties = self.parties
		if parties ~= nil and #parties > 0 then
			return shared.MATCH_CONTROLLER_GETPLAYERPARTY_REVERT(self, plr)
		end
		return AC_MOD_View:getPlayerParty(plr)
	end

	function AC_MOD_View:toggleDisableDisguises()
		if not self.Enabled then return end
		
		
		local remover = vape.Modules and vape.Modules.StreamRemover
		if remover and remover.Enabled ~= (self.disable_disguises == true) then
			remover:Toggle()
		end
	end

	function AC_MOD_View:refreshCore()
		self:refreshTeamMapAsync()
		self:refreshDisplayCacheAsync()
		self:refreshPlayerTeamDataAsync()

		self:toggleDisableDisguises()
	end

	function AC_MOD_View:refreshCoreAsync()
		task.spawn(self.refreshCore, self)
	end

	function AC_MOD_View:init()
		self.Enabled = true
		self.controller.hasAnyPermissions = function(self)
			return true
		end
		self.match_controller.getPlayerParty = self.mockGetPlayerParty

		self.playerConnections = {
			added = Players.PlayerAdded:Connect(function(player)
				self.cacheDirty = true
				self:refreshCoreAsync()
				player:GetPropertyChangedSignal("Team"):Connect(function()
					self.cacheDirty = true
					self:refreshCoreAsync()
				end)
			end),
			removed = Players.PlayerRemoving:Connect(function(player)
				local playerId = tostring(player.UserId)
				self.Friends[playerId] = nil
				for _, cache in pairs(self.Friends) do
					cache[playerId] = nil
				end
				self.cacheDirty = true
				self:refreshCoreAsync()
			end)
		}

		self:refreshCore()
	end

	function AC_MOD_View:disable()
		self.Enabled = false

		self.controller.hasAnyPermissions = shared.PERMISSION_CONTROLLER_HASANYPERMISSIONS_REVERT
		self.match_controller.getPlayerParty = shared.MATCH_CONTROLLER_GETPLAYERPARTY_REVERT

		if self.playerConnections then
			for _, v in pairs(self.playerConnections) do
				pcall(function() v:Disconnect() end)
			end
			table.clear(self.playerConnections)
		end

		self.parties = {}
		self.teamMap = {}
		self.Friends = {}
		self.display = {}
		self.teamData = {}
		self.cacheDirty = true

		self:toggleDisableDisguises()
	end

	shared.ACMODVIEWENABLED = false
	AC_MOD_View.moduleInstance = vape.Categories.World:CreateModule({
		Name = "ACMODView",
		Function = function(call)
			shared.ACMODVIEWENABLED = call
			if call then
				AC_MOD_View:init()
			else
				AC_MOD_View:disable()
			end
		end
	})

	AC_MOD_View.disableDisguisesToggle = AC_MOD_View.moduleInstance:CreateToggle({
		Name = "Remove Disguises",
		Function = function(call)
			AC_MOD_View.disable_disguises = call
			AC_MOD_View:toggleDisableDisguises()
		end,
		Default = true
	})
end)
