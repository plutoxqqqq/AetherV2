run(function()
	local NametagSpoof
	local SpoofRankDropdown

	local lplr = game.Players.LocalPlayer
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")

	local BedwarsImageId = require(ReplicatedStorage.TS.image["image-id"]).BedwarsImageId

	local RANK_MAP = {
		Bronze = "BRONZE_RANK",
		Silver = "SILVER_RANK",
		Gold = "GOLD_RANK",
		Platinum = "PLATINUM_RANK",
		Diamond = "DIAMOND_RANK",
		Emerald = "EMERALD_RANK",
		Nightmare = "NIGHTMARE_RANK"
	}

	local loop

	local function findNametag(char)
		local head = char:FindFirstChild("Head")
		if not head then return nil end

		for _, gui in ipairs(CollectionService:GetTagged("EntityNameTag")) do
			if gui:IsA("BillboardGui") and (gui.Adornee == head or gui:IsDescendantOf(char)) then
				return gui
			end
		end

		local direct = head:FindFirstChild("Nametag")
		if direct and direct:IsA("BillboardGui") then
			return direct
		end

		return nil
	end

	local function waitForNametag(char)
		for i = 1, 50 do 
			local tag = findNametag(char)
			if tag then return tag end
			task.wait(0.1)
		end
	end

	local function applySpoof(char)
		local head = char:WaitForChild("Head", 5)
		if not head then return end

		local original = waitForNametag(char)
		if not original then return end
		local old = head:FindFirstChild("NSSpoofGui")
		if old then old:Destroy() end
		local clone = original:Clone()
		clone.Name = "NSSpoofGui"
		clone.Adornee = head
		clone.Parent = head

		original.Enabled = false

		return clone
	end

	local function updateRank(spoof)
		if not spoof then return end

		for _, d in ipairs(spoof:GetDescendants()) do
			if d:IsA("ImageLabel") then
				for _, rankKey in pairs(RANK_MAP) do
					if d.Image == BedwarsImageId[rankKey] then
						d.Image = BedwarsImageId[RANK_MAP[SpoofRankDropdown.Value]]
					end
				end
			end
		end
	end

	local function startLoop(char)
		if loop then task.cancel(loop) end

		loop = task.spawn(function()
			local head = char:WaitForChild("Head", 5)
			if not head then return end

			while NametagSpoof.Enabled and char.Parent do
				task.wait(0.05)

				local spoof = head:FindFirstChild("NSSpoofGui")
				if spoof then
					updateRank(spoof)
				end
			end
		end)
	end

	local function cleanup(char)
		if loop then
			task.cancel(loop)
			loop = nil
		end

		if not char then return end
		local head = char:FindFirstChild("Head")
		if not head then return end

		local spoof = head:FindFirstChild("NSSpoofGui")
		if spoof then spoof:Destroy() end

		local original = findNametag(char)
		if original then
			original.Enabled = true
		end
	end

	NametagSpoof = vape.Categories.Render:CreateModule({
		Name = "NametagSpoof",
		Function = function(callback)
			if callback then
				if lplr.Character then
					task.spawn(function()
						local spoof = applySpoof(lplr.Character)
						if spoof then
							updateRank(spoof)
							startLoop(lplr.Character)
						end
					end)
				end

				NametagSpoof:Clean(lplr.CharacterAdded:Connect(function(char)
					task.spawn(function()
						local spoof = applySpoof(char)
						if spoof then
							updateRank(spoof)
							startLoop(char)
						end
					end)
				end))
			else
				cleanup(lplr.Character)
			end
		end
	})

	SpoofRankDropdown = NametagSpoof:CreateDropdown({
		Name = "Rank",
		List = {"Bronze","Silver","Gold","Platinum","Diamond","Emerald","Nightmare"},
		Default = "Nightmare"
	})
end)
