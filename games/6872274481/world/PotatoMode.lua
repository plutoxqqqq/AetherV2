run(function()
	local PotatoMode
	local originalProperties = {}
	local blockMonitorConnections = {}
	local processedBlocks = {}

	local blockColors = {
		["clay_white"] = Color3.fromRGB(255, 255, 255),
		["wool_white"] = Color3.fromRGB(255, 255, 255),
		["wool_red"] = Color3.fromRGB(255, 50, 50),
		["wool_green"] = Color3.fromRGB(50, 255, 50),
		["grass"] = Color3.fromRGB(50, 255, 50),
		["moss_block"] = Color3.fromRGB(50, 255, 50),
		["wool_blue"] = Color3.fromRGB(50, 100, 255),
		["wool_yellow"] = Color3.fromRGB(255, 255, 50),
		["wool_orange"] = Color3.fromRGB(255, 150, 50),
		["clay_orange"] = Color3.fromRGB(255, 150, 50),
		["wool_purple"] = Color3.fromRGB(180, 50, 255),
		["clay_light_brown"] = Color3.fromRGB(200, 170, 120),
		["wool_pink"] = Color3.fromRGB(255, 100, 200),
		["wool_black"] = Color3.fromRGB(50, 50, 50),
		["wool_cyan"] = Color3.fromRGB(50, 255, 255),
		["wool_magenta"] = Color3.fromRGB(255, 50, 150),
		["wool_lime"] = Color3.fromRGB(150, 255, 50),
		["wool_brown"] = Color3.fromRGB(150, 75, 0),
		["wood_plank_spruce"] = Color3.fromRGB(222, 184, 135),
		["wool_light_blue"] = Color3.fromRGB(100, 200, 255),
		["wool_gray"] = Color3.fromRGB(150, 150, 150),
		["clay"] = Color3.fromRGB(220, 180, 140),
		["wood"] = Color3.fromRGB(180, 140, 100),
		["stone"] = Color3.fromRGB(150, 150, 150),
		["andesite"] = Color3.fromRGB(150, 150, 150),
		["cobblestone"] = Color3.fromRGB(150, 150, 150),
		["obsidian"] = Color3.fromRGB(50, 30, 80),
		["bedrock"] = Color3.fromRGB(80, 80, 80),
		["tnt"] = Color3.fromRGB(255, 50, 50),
		["sandstone"] = Color3.fromRGB(220, 200, 150),
		["sand"] = Color3.fromRGB(220, 200, 150),
		["wool"] = Color3.fromRGB(200, 200, 200),
		["bed"] = Color3.fromRGB(200, 50, 50),
		["concrete"] = Color3.fromRGB(180, 180, 180),
	}

	local cachedColors = {}

	local function getBlockColor(blockName)
		if cachedColors[blockName] then
			return cachedColors[blockName]
		end

		if blockColors[blockName] then
			cachedColors[blockName] = blockColors[blockName]
			return blockColors[blockName]
		end

		local lowerName = blockName:lower()

		if blockColors[lowerName] then
			cachedColors[blockName] = blockColors[lowerName]
			return blockColors[lowerName]
		end

		if lowerName:find("wool", 1, true) then
			for key, color in pairs(blockColors) do
				if key:find("wool", 1, true) and lowerName:find(key, 1, true) then
					cachedColors[blockName] = color
					return color
				end
			end
			cachedColors[blockName] = blockColors["wool"]
			return blockColors["wool"]
		end

		for name, color in pairs(blockColors) do
			if lowerName:find(name, 1, true) then
				cachedColors[blockName] = color
				return color
			end
		end

		local defaultColor = Color3.fromRGB(150, 150, 150)
		cachedColors[blockName] = defaultColor
		return defaultColor
	end

	local function cleanupDeadReferences()
		for block, _ in pairs(originalProperties) do
			if not block or not block.Parent then
				originalProperties[block] = nil
				processedBlocks[block] = nil
			end
		end
	end

	local function simplifyBlock(block)
		if not block or not block.Parent or processedBlocks[block] then return end

		if not originalProperties[block] then
			originalProperties[block] = {
				Material = block.Material,
				Color = block.Color,
				TextureID = block:IsA("MeshPart") and block.TextureID or nil,
				Textures = {}
			}

			for _, child in block:GetChildren() do
				if child:IsA("Texture") or child:IsA("Decal") then
					table.insert(originalProperties[block].Textures, {
						Class = child.ClassName,
						Texture = child.Texture,
						StudsPerTileU = child.StudsPerTileU,
						StudsPerTileV = child.StudsPerTileV,
						Face = child.Face,
						Transparency = child.Transparency,
						Color3 = child:IsA("Decal") and child.Color3 or nil
					})
				end
			end
		end

		block.Material = Enum.Material.SmoothPlastic
		block.Color = getBlockColor(block.Name)

		for _, child in block:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end

		if block:IsA("MeshPart") and block.TextureID ~= "" then
			block.TextureID = ""
		end

		processedBlocks[block] = true
	end

	local function restoreBlock(block)
		if not block or not block.Parent then
			originalProperties[block] = nil
			processedBlocks[block] = nil
			return
		end

		local props = originalProperties[block]
		if not props then return end

		block.Material = props.Material or Enum.Material.Plastic
		block.Color = props.Color or Color3.fromRGB(255, 255, 255)

		if props.TextureID and block:IsA("MeshPart") then
			block.TextureID = props.TextureID
		end

		for _, textureProps in props.Textures do
			local newTexture
			if textureProps.Class == "Texture" then
				newTexture = Instance.new("Texture")
				newTexture.StudsPerTileU = textureProps.StudsPerTileU or 1
				newTexture.StudsPerTileV = textureProps.StudsPerTileV or 1
			else
				newTexture = Instance.new("Decal")
				newTexture.Color3 = textureProps.Color3 or Color3.fromRGB(255, 255, 255)
			end

			newTexture.Texture = textureProps.Texture or ""
			newTexture.Face = textureProps.Face or Enum.NormalId.Front
			newTexture.Transparency = textureProps.Transparency or 0
			newTexture.Parent = block
		end

		originalProperties[block] = nil
		processedBlocks[block] = nil
	end

	local function isTargetBlock(obj)
		if not obj:IsA("BasePart") then return false end

		local name = obj.Name

		if blockColors[name] then return true end

		local lowerName = name:lower()
		return lowerName:find("wool", 1, true) or
		       lowerName:find("clay", 1, true) or
		       lowerName:find("wood", 1, true) or
		       lowerName:find("stone", 1, true) or
		       lowerName:find("glass", 1, true) or
		       lowerName:find("plank", 1, true) or
		       lowerName:find("bed", 1, true) or
		       lowerName:find("obsidian", 1, true) or
		       lowerName:find("sand", 1, true) or
		       lowerName:find("end", 1, true) or
		       lowerName:find("tnt", 1, true) or
		       lowerName:find("barrier", 1, true) or
		       lowerName:find("magic", 1, true) or
		       lowerName:find("concrete", 1, true) or
		       lowerName:find("_block", 1, true) or
		       obj:IsA("Seat")
	end

	local function processExistingBlocks(simplify)
		local descendants = workspace:GetDescendants()

		task.spawn(function()
			for i, obj in descendants do
				if isTargetBlock(obj) then
					if simplify then
						simplifyBlock(obj)
					else
						restoreBlock(obj)
					end
				end
			end

			if not simplify then
				cleanupDeadReferences()
			end
		end)
	end

	local function setupBlockMonitor(simplify)
		for _, conn in blockMonitorConnections do
			conn:Disconnect()
		end
		table.clear(blockMonitorConnections)

		if not simplify then return end

		local mainConn = workspace.DescendantAdded:Connect(function(descendant)
			if isTargetBlock(descendant) then
				task.defer(function()
					if descendant and descendant.Parent then
						simplifyBlock(descendant)
					end
				end)
			end
		end)

		table.insert(blockMonitorConnections, mainConn)

		local lastCleanup = 0
		local cleanupConn = runService.Heartbeat:Connect(function()
			local now = tick()
			if now - lastCleanup >= 5 then
				lastCleanup = now
				cleanupDeadReferences()
			end
		end)

		table.insert(blockMonitorConnections, cleanupConn)
	end

	PotatoMode = vape.Categories.World:CreateModule({
		Name = 'PotatoMode',
		Function = function(callback)
			if callback then
				processExistingBlocks(true)
				setupBlockMonitor(true)
			else
				processExistingBlocks(false)
				for _, conn in blockMonitorConnections do
					conn:Disconnect()
				end
				table.clear(blockMonitorConnections)
				table.clear(cachedColors)
				cleanupDeadReferences()
			end
		end,
	})
end)