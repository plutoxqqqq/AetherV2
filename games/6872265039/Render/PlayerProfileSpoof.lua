run(function()
	local PlayerProfileSpoof
	local PPSRankDropdown
	local PPSRpSlider
	local PPSLeaderboardSlider

	local lplr = game.Players.LocalPlayer
	local PP_ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PP_BedwarsImageId = require(PP_ReplicatedStorage.TS.image["image-id"]).BedwarsImageId

	local PP_RANK_MAP = {
		["Bronze 1"] = "BRONZE_RANK",   ["Bronze 2"] = "BRONZE_RANK",   ["Bronze 3"] = "BRONZE_RANK",
		["Silver 1"] = "SILVER_RANK",   ["Silver 2"] = "SILVER_RANK",   ["Silver 3"] = "SILVER_RANK",
		["Gold 1"]   = "GOLD_RANK",     ["Gold 2"]   = "GOLD_RANK",     ["Gold 3"]   = "GOLD_RANK",
		["Platinum 1"]= "PLATINUM_RANK",["Platinum 2"]= "PLATINUM_RANK",["Platinum 3"]= "PLATINUM_RANK",
		["Diamond 1"] = "DIAMOND_RANK", ["Diamond 2"] = "DIAMOND_RANK", ["Diamond 3"] = "DIAMOND_RANK",
		["Emerald 1"] = "EMERALD_RANK", ["Emerald 2"] = "EMERALD_RANK", ["Emerald 3"] = "EMERALD_RANK",
		["Nightmare"] = "NIGHTMARE_RANK"
	}

	local PP_RANK_COLORS = {
		Bronze   = Color3.fromRGB(188, 110, 60),
		Silver   = Color3.fromRGB(180, 180, 190),
		Gold     = Color3.fromRGB(255, 200, 0),
		Platinum = Color3.fromRGB(60, 220, 255),
		Diamond  = Color3.fromRGB(90, 150, 255),
		Emerald  = Color3.fromRGB(0, 200, 100),
	}

	local PP_RANK_IMAGES = {}
	for _, key in ipairs({"BRONZE_RANK","SILVER_RANK","GOLD_RANK","PLATINUM_RANK","DIAMOND_RANK","EMERALD_RANK","NIGHTMARE_RANK"}) do
		local img = PP_BedwarsImageId[key]
		if img and img ~= "" then PP_RANK_IMAGES[img] = true end
	end

	local ALL_RANK_NAMES = {}
	for k in pairs(PP_RANK_MAP) do ALL_RANK_NAMES[k] = true end

	local ppLoop = nil

	local function getBaseRank(rankName)
		return rankName:match("^(%a+)")
	end

	local function ppDoSpoof()
		local playerGui = lplr:FindFirstChild("PlayerGui")
		if not playerGui then return end

		local rankName    = PPSRankDropdown.Value
		local rankKey     = PP_RANK_MAP[rankName]
		local rpValue     = PPSRpSlider.Value
		local lbRank      = PPSLeaderboardSlider.Value
		local isNightmare = rankName == "Nightmare"
		local fillColor   = PP_RANK_COLORS[getBaseRank(rankName)]
		local fillScale   = math.clamp(rpValue / 100, 0, 1)

		for _, v in ipairs(playerGui:GetDescendants()) do
			if v:IsA("ImageLabel") and PP_RANK_IMAGES[v.Image] then
				v.Image = PP_BedwarsImageId[rankKey]

			elseif v:IsA("TextLabel") then
				local name = v.Name
				local txt  = v.Text
				if name == "CurrentRP" then
					if isNightmare then
						v.Visible = false
					else
						v.Visible = true
						v.Text = rpValue .. " RP / 100"
					end
				elseif name == "RankName" then
					v.Text = rankName
				elseif txt:find("Leaderboard Rank:") then
					v.Text = "Leaderboard Rank: " .. lbRank
				end

			elseif v:IsA("Frame") then
				local name = v.Name
				if name == "ProgressBar" then
					if isNightmare then
						v.Visible = false
					else
						v.Visible = true
						if fillColor then
							v.BackgroundColor3 = fillColor
						end
						v.Size = UDim2.new(fillScale, 0, v.Size.Y.Scale, v.Size.Y.Offset)
					end
				elseif name == "ProgressBarContainer" then
					v.Visible = not isNightmare
				end
			end
		end
	end

	local function ppStartLoop()
		if ppLoop then task.cancel(ppLoop) end
		ppLoop = task.spawn(function()
			while PlayerProfileSpoof.Enabled do
				task.wait(0.1)
				ppDoSpoof()
			end
		end)
	end

	local function ppCleanup()
		if ppLoop then task.cancel(ppLoop) ppLoop = nil end
	end

	PlayerProfileSpoof = vape.Categories.Render:CreateModule({
		Name = "PlayerProfileSpoof",
		Function = function(callback)
			if callback then ppStartLoop() else ppCleanup() end
		end,
		Tooltip = "Spoofs rank, RP bar color and leaderboard rank in your profile UI (client sided)"
	})

	PPSRankDropdown = PlayerProfileSpoof:CreateDropdown({
		Name = "Rank",
		List = {
			"Bronze 1","Bronze 2","Bronze 3",
			"Silver 1","Silver 2","Silver 3",
			"Gold 1","Gold 2","Gold 3",
			"Platinum 1","Platinum 2","Platinum 3",
			"Diamond 1","Diamond 2","Diamond 3",
			"Emerald 1","Emerald 2","Emerald 3",
			"Nightmare"
		},
		Default = "Nightmare"
	})

	PPSRpSlider = PlayerProfileSpoof:CreateSlider({
		Name = "RP", Min = 0, Max = 100, Default = 50
	})

	PPSLeaderboardSlider = PlayerProfileSpoof:CreateSlider({
		Name = "Leaderboard Rank", Min = 1, Max = 10000, Default = 1
	})
end)
