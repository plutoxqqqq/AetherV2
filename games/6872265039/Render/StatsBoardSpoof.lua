run(function()
	local StatsBoardSpoof
	local RANK_NAME, LB_RANK, RP, PLAYER_LEVEL, XP_CURRENT, XP_MAX, WINS, BED_BREAKS, FINAL_KILLS, HONOR

	local originals = {}
	local SBS_RS = game:GetService("ReplicatedStorage")
	local SBS_ImageId = require(SBS_RS.TS.image["image-id"]).BedwarsImageId
	local RANK_TO_IMAGE = {
		["Bronze 1"]="BRONZE_RANK",["Bronze 2"]="BRONZE_RANK",["Bronze 3"]="BRONZE_RANK",["Bronze 4"]="BRONZE_RANK",
		["Silver 1"]="SILVER_RANK",["Silver 2"]="SILVER_RANK",["Silver 3"]="SILVER_RANK",["Silver 4"]="SILVER_RANK",
		["Gold 1"]="GOLD_RANK",["Gold 2"]="GOLD_RANK",["Gold 3"]="GOLD_RANK",["Gold 4"]="GOLD_RANK",
		["Platinum 1"]="PLATINUM_RANK",["Platinum 2"]="PLATINUM_RANK",["Platinum 3"]="PLATINUM_RANK",["Platinum 4"]="PLATINUM_RANK",
		["Diamond 1"]="DIAMOND_RANK",["Diamond 2"]="DIAMOND_RANK",["Diamond 3"]="DIAMOND_RANK",["Diamond 4"]="DIAMOND_RANK",
		["Emerald 1"]="EMERALD_RANK",["Emerald 2"]="EMERALD_RANK",["Emerald 3"]="EMERALD_RANK",["Emerald 4"]="EMERALD_RANK",
		["Nightmare"]="NIGHTMARE_RANK",
	}

	local RANK_LIST = {
		"Bronze 1","Bronze 2","Bronze 3","Bronze 4",
		"Silver 1","Silver 2","Silver 3","Silver 4",
		"Gold 1","Gold 2","Gold 3","Gold 4",
		"Platinum 1","Platinum 2","Platinum 3","Platinum 4",
		"Diamond 1","Diamond 2","Diamond 3","Diamond 4",
		"Emerald 1","Emerald 2","Emerald 3","Emerald 4",
		"Nightmare"
	}

	local RANK_BAR_COLORS = {
		Bronze    = Color3.fromRGB(188, 110, 60),
		Silver    = Color3.fromRGB(180, 180, 190),
		Gold      = Color3.fromRGB(255, 200, 0),
		Platinum  = Color3.fromRGB(60, 220, 255),
		Diamond   = Color3.fromRGB(90, 150, 255),
		Emerald   = Color3.fromRGB(0, 200, 100),
		Nightmare = Color3.fromRGB(180, 0, 255),
	}
	local function getBaseRankSBS(rankName)
		return rankName:match("^(%a+)")
	end
	local function formatNumber(n)
		local s = tostring(n)
		local result = ""
		local len = #s
		for i = 1, len do
			result = result .. s:sub(i, i)
			if (len - i) % 3 == 0 and i ~= len then
				result = result .. ","
			end
		end
		return result
	end

	local function getBoard()
		local lobby = workspace:FindFirstChild("Lobby")
		if not lobby then return nil end
		local boards = lobby:FindFirstChild("Boards")
		if not boards then return nil end
		local sb = boards:FindFirstChild("StatsBoard")
		if not sb then return nil end
		local board = sb:FindFirstChild("Board")
		if not board then return nil end
		return board:FindFirstChild("StatsBoard")
	end

	local function getElements(gui)
		if not gui then return nil end
		local outer = gui:FindFirstChild("1")
		if not outer then return nil end
		local inner = outer:FindFirstChild("1")
		if not inner then return nil end
		local header = inner:FindFirstChild("1")
		local scroll = inner:FindFirstChild("AutoCanvasScrollingFrame")
		if not scroll or not header then return nil end

		local levelSection = scroll:FindFirstChild("3")
		local lvlPB = levelSection and levelSection:FindFirstChild("ProgressBar")

		local rankedSection = scroll:FindFirstChild("4")
		local rankDisplay = rankedSection and rankedSection:FindFirstChild("3")
		local rankInfoArea = rankDisplay and rankDisplay:FindFirstChild("3")
		local rankNameFrame = rankInfoArea and rankInfoArea:FindFirstChild("2")
		local rpFrame = rankInfoArea and rankInfoArea:FindFirstChild("3")
		local pbContainer = rpFrame and rpFrame:FindFirstChild("ProgressBarContainer")

		local globalSection = scroll:FindFirstChild("5")
		local statsContent = globalSection and globalSection:FindFirstChild("3")
		local basicStats = statsContent and statsContent:FindFirstChild("2")

		return {
			rankImage   = rankDisplay and rankDisplay:FindFirstChild("2"),
			levelLabel  = levelSection and levelSection:FindFirstChild("2"),
			xpLabel     = levelSection and levelSection:FindFirstChild("3"),
			lvlProgress = lvlPB and lvlPB:FindFirstChild("CurrProgress"),
			rankName    = rankNameFrame and rankNameFrame:FindFirstChild("RankName"),
			lbRank      = rankNameFrame and rankNameFrame:FindFirstChild("LeaderboardRank"),
			rpBar       = pbContainer and pbContainer:FindFirstChild("ProgressBar"),
			currentRP   = rpFrame and rpFrame:FindFirstChild("CurrentRP"),
			honorVal    = basicStats and basicStats:FindFirstChild("2") and basicStats:FindFirstChild("2"):FindFirstChild("5"),
			winsVal     = basicStats and basicStats:FindFirstChild("3") and basicStats:FindFirstChild("3"):FindFirstChild("5"),
			bedVal      = basicStats and basicStats:FindFirstChild("4") and basicStats:FindFirstChild("4"):FindFirstChild("5"),
			killsVal    = basicStats and basicStats:FindFirstChild("5") and basicStats:FindFirstChild("5"):FindFirstChild("5"),
		}
	end

	local function readRealStats()
		local gui = getBoard()
		if not gui then return end
		local e = getElements(gui)
		if not e then return end
		if e.levelLabel then PLAYER_LEVEL = tonumber(e.levelLabel.Text:match("(%d+)")) or 1 end
		if e.xpLabel then
			local cur, max = e.xpLabel.Text:match("(%d+)%s*/%s*(%d+)")
			XP_CURRENT = tonumber(cur) or 0
			XP_MAX = tonumber(max) or 1
		end
		if e.rankName then RANK_NAME = e.rankName.Text end
		if e.lbRank then LB_RANK = tonumber(e.lbRank.Text:gsub(",",""):match("(%d+)")) or 1 end
		if e.currentRP then RP = tonumber(e.currentRP.Text:match("(%d+)")) or 0 end
		if e.honorVal then HONOR = tonumber(e.honorVal.Text) or 0 end
		if e.winsVal then WINS = tonumber(e.winsVal.Text) or 0 end
		if e.bedVal then BED_BREAKS = tonumber(e.bedVal.Text) or 0 end
		if e.killsVal then FINAL_KILLS = tonumber(e.killsVal.Text) or 0 end
	end

	local function applySpoof()
		local gui = getBoard()
		if not gui then
			notif({Title = "StatsBoardSpoof", Message = "Board not found! Make sure you are in the Lobby.", Duration = 3})
			return
		end
		local e = getElements(gui)
		if not e then return end

		for k, v in pairs(e) do
			if v and v:IsA("TextLabel") then
				originals[k] = v.Text
			elseif v and v:IsA("Frame") then
				originals[k] = v.Size
			elseif v and v:IsA("ImageLabel") then
				originals[k] = v.Image
			end
		end

		if e.rankImage then
			local imgKey = RANK_TO_IMAGE[RANK_NAME]
			if imgKey then e.rankImage.Image = SBS_ImageId[imgKey] end
		end
		if e.levelLabel  then e.levelLabel.Text  = "Player Level " .. PLAYER_LEVEL end
		if e.xpLabel     then e.xpLabel.Text     = XP_CURRENT .. " / " .. XP_MAX end
		if e.lvlProgress then e.lvlProgress.Size = UDim2.new(math.clamp(XP_CURRENT / XP_MAX, 0, 1), 0, 1, 0) end
		if e.rankName    then e.rankName.Text    = RANK_NAME end
		if e.lbRank      then e.lbRank.Text      = 'Leaderboard Rank: <b><font color="rgb(185,188,255)">' .. formatNumber(LB_RANK) .. "</font></b>" end
		local isNightmare = RANK_NAME == "Nightmare"
		if e.currentRP then
			if isNightmare then
				e.currentRP.Visible = false
			else
				e.currentRP.Visible = true
				e.currentRP.Text = '<b><font color="#ffffff">' .. RP .. " RP</font></b> / 100"
			end
		end
		if e.rpBar then
			if isNightmare then
				e.rpBar.Parent.Visible = false
			else
				e.rpBar.Parent.Visible = true
				e.rpBar.Size = UDim2.new(RP / 100, 0, 1, 0)
				local barColor = RANK_BAR_COLORS[getBaseRankSBS(RANK_NAME or "")]
				if barColor then e.rpBar.BackgroundColor3 = barColor end
			end
		end
		if e.honorVal    then e.honorVal.Text    = tostring(HONOR) end
		if e.winsVal     then e.winsVal.Text     = tostring(WINS) end
		if e.bedVal      then e.bedVal.Text      = tostring(BED_BREAKS) end
		if e.killsVal    then e.killsVal.Text    = tostring(FINAL_KILLS) end
	end

	local function revertSpoof()
		local gui = getBoard()
		if not gui then return end
		local e = getElements(gui)
		if not e then return end
		for k, v in pairs(originals) do
			local elem = e[k]
			if elem then
				if elem:IsA("TextLabel") then elem.Text = v
				elseif elem:IsA("Frame") then elem.Size = v
				elseif elem:IsA("ImageLabel") then elem.Image = v end
			end
		end
		originals = {}
	end

	local sbsLoop = nil
	StatsBoardSpoof = vape.Categories.Render:CreateModule({
		Name = "StatsBoardSpoof",
		Tooltip = "Spoof your StatsBoard display (client-sided only)",
		Function = function(enabled)
			if enabled then
				readRealStats()
				if sbsLoop then task.cancel(sbsLoop) end
				sbsLoop = task.spawn(function()
					while StatsBoardSpoof.Enabled do
						applySpoof()
						task.wait(0.5)
					end
				end)
			else
				if sbsLoop then task.cancel(sbsLoop) sbsLoop = nil end
				revertSpoof()
				RANK_NAME, LB_RANK, RP, PLAYER_LEVEL, XP_CURRENT, XP_MAX, WINS, BED_BREAKS, FINAL_KILLS, HONOR = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
			end
		end
	})

	StatsBoardSpoof:CreateDropdown({
		Name = "Rank",
		List = RANK_LIST,
		Default = "Silver 3",
		Function = function(val)
			RANK_NAME = val
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Leaderboard Rank",
		Min = 1,
		Max = 100000,
		Default = 11469,
		Decimal = 1,
		Function = function(val)
			LB_RANK = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "RP",
		Min = 0,
		Max = 100,
		Default = 26,
		Decimal = 1,
		Function = function(val)
			RP = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Player Level",
		Min = 1,
		Max = 200,
		Default = 40,
		Decimal = 1,
		Function = function(val)
			PLAYER_LEVEL = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Wins",
		Min = 0,
		Max = 50000,
		Default = 621,
		Decimal = 1,
		Function = function(val)
			WINS = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Bed Breaks",
		Min = 0,
		Max = 50000,
		Default = 269,
		Decimal = 1,
		Function = function(val)
			BED_BREAKS = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Final Kills",
		Min = 0,
		Max = 100000,
		Default = 457,
		Decimal = 1,
		Function = function(val)
			FINAL_KILLS = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})

	StatsBoardSpoof:CreateSlider({
		Name = "Honor",
		Min = 0,
		Max = 10000,
		Default = 2,
		Decimal = 1,
		Function = function(val)
			HONOR = math.floor(val)
			if StatsBoardSpoof.Enabled then applySpoof() end
		end
	})
end)
