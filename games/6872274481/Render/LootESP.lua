run(function()
	local LootESP
	local IronToggle
	local DiamondToggle
	local EmeraldToggle
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local CollectionService = collectionService

	local lootTypes = {
		iron = {
			keywords = {'iron'},
			color = Color3.fromRGB(200, 200, 200),
			icon = 'iron',
			displayName = 'IRON'
		},
		diamond = {
			keywords = {'diamond'},
			color = Color3.fromRGB(85, 200, 255),
			icon = 'diamond',
			displayName = 'DIAMOND'
		},
		emerald = {
			keywords = {'emerald'},
			color = Color3.fromRGB(0, 255, 100),
			icon = 'emerald',
			displayName = 'EMERALD'
		}
	}

	local function getLootType(itemName)
		local nameLower = itemName:lower()
		for lootType, config in pairs(lootTypes) do
			for _, keyword in ipairs(config.keywords) do
				if nameLower:find(keyword, 1, true) then
					return lootType, config
				end
			end
		end
		return nil
	end

	local function isLootEnabled(lootType)
		if lootType == 'iron' then
			return IronToggle.Enabled
		elseif lootType == 'diamond' then
			return DiamondToggle.Enabled
		elseif lootType == 'emerald' then
			return EmeraldToggle.Enabled
		end
		return false
	end

	local function getProperIcon(lootType)
		local icon = bedwars.getIcon({itemType = lootType}, true)

		if not icon or icon == "" then
			return nil
		end

		return icon
	end

	local function Added(lootHandle, lootType, config)
		if not isLootEnabled(lootType) then return end
		if Reference[lootHandle] then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = lootType
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(40, 40)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = lootHandle

		local blur = addBlur(billboard)
		blur.Visible = true

		local iconImage = getProperIcon(config.icon)

		if iconImage then
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(40, 40)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundColor3 = Color3.new(0, 0, 0)
			image.BackgroundTransparency = 0.3
			image.BorderSizePixel = 0
			image.Image = iconImage
			image.Parent = billboard

			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = image
		else
			local frame = Instance.new('Frame')
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = Color3.new(0, 0, 0)
			frame.BackgroundTransparency = 0.3
			frame.BorderSizePixel = 0
			frame.Parent = billboard

			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = frame

			local textLabel = Instance.new('TextLabel')
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.Position = UDim2.fromScale(0.5, 0.5)
			textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = config.displayName
			textLabel.TextColor3 = config.color
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.GothamBold
			textLabel.TextStrokeTransparency = 0.5
			textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			textLabel.Parent = frame
		end

		Reference[lootHandle] = billboard
	end

	local function Removed(lootHandle)
		if Reference[lootHandle] then
			Reference[lootHandle]:Destroy()
			Reference[lootHandle] = nil
		end
	end

	local function findExistingLoot()
		local tagged = CollectionService:GetTagged('ItemDrop')
		for _, drop in ipairs(tagged) do
			local handle = drop:FindFirstChild('Handle')
			if handle then
				local lootType, config = getLootType(drop.Name)
				if lootType and isLootEnabled(lootType) then
					if not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end

	local function refreshLootType(lootType)
		if not LootESP.Enabled then return end

		local enabled = isLootEnabled(lootType)

		if not enabled then
			for handle, billboard in pairs(Reference) do
				if billboard.Name == lootType then
					billboard:Destroy()
					Reference[handle] = nil
				end
			end
		else
			local tagged = CollectionService:GetTagged('ItemDrop')
			for _, drop in ipairs(tagged) do
				local handle = drop:FindFirstChild('Handle')
				if handle then
					local dropLootType, config = getLootType(drop.Name)
					if dropLootType == lootType and not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end

	LootESP = vape.Categories.Render:CreateModule({
		Name = 'LootESP',
		Function = function(callback)
			if callback then
				findExistingLoot()

				LootESP:Clean(CollectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(drop)
					if not LootESP.Enabled then return end

					task.defer(function()
						local handle = drop:FindFirstChild('Handle')
						if not handle then return end

						local lootType, config = getLootType(drop.Name)
						if lootType and isLootEnabled(lootType) then
							Added(handle, lootType, config)
						end
					end)
				end))

				LootESP:Clean(CollectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(drop)
					local handle = drop:FindFirstChild('Handle')
					if handle then
						Removed(handle)
					end
				end))

			else
				for handle, billboard in pairs(Reference) do
					billboard:Destroy()
				end
				table.clear(Reference)
			end
		end,
		Tooltip = 'esp for loot (iron, emerald, diamonds)'
	})

	IronToggle = LootESP:CreateToggle({
		Name = 'Iron',
		Function = function(callback)
			refreshLootType('iron')
		end,
		Default = true
	})

	DiamondToggle = LootESP:CreateToggle({
		Name = 'Diamond',
		Function = function(callback)
			refreshLootType('diamond')
		end,
		Default = true
	})

	EmeraldToggle = LootESP:CreateToggle({
		Name = 'Emerald',
		Function = function(callback)
			refreshLootType('emerald')
		end,
		Default = true
	})
end)
