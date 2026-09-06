run(function()
	local LeaderboardSpoof
	local RS = game.ReplicatedStorage

	local CURRENT_BOARD = "Ranked"
	local CUSTOM_POSITION = 1
	local CUSTOM_STAT = 5000
	local SHOW_IN_LIST = true
	local savedFullLeaderboards = nil

	local ClientStore
	pcall(function() ClientStore = bedwars.Store end)

	local function getBoardKey()
		if CURRENT_BOARD == "Ranked" then
			local key = "RankPoints_S15"
			pcall(function()
				key = require(RS.TS.rank["rank-util"]).RankUtil.activeRankMeta.leaderboard
			end)
			return key, true
		elseif CURRENT_BOARD == "Overall Wins" then
			return "OverallWins", false
		elseif CURRENT_BOARD == "Monthly Wins" then
			return "Wins", false
		elseif CURRENT_BOARD == "Top Gifters" then
			return "gift_leaderboard", false
		end
		return nil, false
	end

	local function computeRankDisplay(totalRP)
		local result = nil
		pcall(function()
			local RankMeta = require(RS.TS.rank["rank-meta"]).RankMeta
			local divisionIndex = math.min(math.floor(totalRP / 100), 24) 
			local remainder = totalRP - divisionIndex * 100            
			local rankInfo = RankMeta[divisionIndex]
			if rankInfo then
				result = {
					image = rankInfo.image,
					rankName = rankInfo.name,
					rankStatValue = remainder,   
				}
			end
		end)
		return result
	end

	local function doDispatch()
		if not ClientStore then return end
		local boardKey, isRanked = getBoardKey()
		if not boardKey then return end

		local state = ClientStore:getState()
		local currentLeaderboards = state.Leaderboard and state.Leaderboard.leaderboards

		if not savedFullLeaderboards and currentLeaderboards then
			savedFullLeaderboards = {}
			for k, v in pairs(currentLeaderboards) do
				savedFullLeaderboards[k] = v
			end
		end

		local lp = game.Players.LocalPlayer
		local rankDisplay = isRanked and computeRankDisplay(CUSTOM_STAT) or nil

		local localUser = {
			username = lp.Name,
			avatarImage = "rbxthumb://type=AvatarHeadShot&id=" .. lp.UserId .. "&w=60&h=60",
			statValue = rankDisplay and rankDisplay.rankStatValue or CUSTOM_STAT,  
			userId = lp.UserId,
		}
		if rankDisplay then
			localUser.statRank = rankDisplay
		end

		local newLeaderboards = {}
		if currentLeaderboards then
			for k, v in pairs(currentLeaderboards) do
				newLeaderboards[k] = v
			end
		end

		local currentBoardData = currentLeaderboards and currentLeaderboards[boardKey]
		local users = {}
		if currentBoardData and currentBoardData.users then
			for _, u in ipairs(currentBoardData.users) do
				if u.userId ~= lp.UserId then
					table.insert(users, u)
				end
			end
		end

		if SHOW_IN_LIST then
			local pos = math.max(1, math.min(CUSTOM_POSITION, #users + 1))
			table.insert(users, pos, localUser)
		end

		local newData = {
			lastRefresh = os.time(),
			users = users,
			leaderboardPosition = CUSTOM_POSITION,
			localStatValue = rankDisplay and rankDisplay.rankStatValue or CUSTOM_STAT,  
		}
		if rankDisplay then
			newData.localStatRank = rankDisplay
		end
		if currentBoardData and currentBoardData.nextReset then
			newData.nextReset = currentBoardData.nextReset
		end

		newLeaderboards[boardKey] = newData

		ClientStore:dispatch({
			type = "UpdateAllLeaderboards",
			leaderboards = newLeaderboards,
		})
	end

	local function doRevert()
		if not ClientStore or not savedFullLeaderboards then return end
		ClientStore:dispatch({
			type = "UpdateAllLeaderboards",
			leaderboards = savedFullLeaderboards,
		})
		savedFullLeaderboards = nil
	end

	LeaderboardSpoof = vape.Categories.Render:CreateModule({
		Name = "LeaderboardSpoof",
		Function = function(enabled)
			if enabled then doDispatch() else doRevert() end
		end,
		Tooltip = "Spoof your leaderboard stats (client sided only)"
	})

	LeaderboardSpoof:CreateDropdown({
		Name = "Board",
		List = {"Ranked", "Overall Wins", "Monthly Wins", "Top Gifters"},
		Default = "Ranked",
		Function = function(val)
			CURRENT_BOARD = val
			if LeaderboardSpoof.Enabled then doDispatch() end
		end
	})

	LeaderboardSpoof:CreateSlider({
		Name = "Position",
		Min = 1,
		Max = 200,
		Default = 1,
		Decimal = 1,
		Function = function(val)
			CUSTOM_POSITION = math.floor(val)
			if LeaderboardSpoof.Enabled then doDispatch() end
		end
	})

	LeaderboardSpoof:CreateSlider({
		Name = "Stat Value",
		Min = 1,
		Max = 4000,
		Default = 2400,
		Decimal = 1,
		Function = function(val)
			CUSTOM_STAT = math.floor(val)
			if LeaderboardSpoof.Enabled then doDispatch() end
		end
	})

	LeaderboardSpoof:CreateToggle({
		Name = "Show In List",
		Default = true,
		Function = function(state)
			SHOW_IN_LIST = state
			if LeaderboardSpoof.Enabled then doDispatch() end
		end
	})
end)
