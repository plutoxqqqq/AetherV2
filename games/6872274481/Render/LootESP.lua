run(function()
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local function createSection()
		local section = {
			Enabled = false,
			Connections = {},
			Reference = {},
			Folder = Instance.new('Folder')
		}
		section.Folder.Parent = Folder
		function section:Clean(item)
			if type(item) == 'function' then
				table.insert(self.Connections, {Disconnect = item})
			elseif item then
				table.insert(self.Connections, item)
			end
		end
		function section:Clear()
			for _, connection in self.Connections do
				pcall(function() connection:Disconnect() end)
			end
			table.clear(self.Connections)
			if self.Stop then self.Stop(self) end
			for instance in self.Reference do
				pcall(function() instance:Destroy() end)
			end
			table.clear(self.Reference)
			self.Folder:ClearAllChildren()
		end
		function section:Set(callback)
			if callback == self.Enabled then return end
			self.Enabled = callback
			self:Clear()
			if callback and self.Start then self.Start(self) end
		end
		return section
	end
	local Loot = createSection()
	local LootESP = vape.Categories.Render:CreateModule({
		Name = 'LootESP',
		Function = function(callback)
			Loot:Set(callback)
			for _, setting in {LootIron,
				LootDiamond,
				LootEmerald} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders loot drops of iron, diamonds and emeralds'
	})
	local LootIron = LootESP:CreateToggle({Name = 'Loot iron', Default = true})
	local LootDiamond = LootESP:CreateToggle({Name = 'Loot diamond', Default = true})
	local LootEmerald = LootESP:CreateToggle({Name = 'Loot emerald', Default = true})
	--------------------------------------------------------------------
	-- Loot
	--------------------------------------------------------------------

	Loot.Start = function(self)
		local lootTypes = {
			iron = {keywords = {'iron'}, color = Color3.fromRGB(200, 200, 200), icon = 'iron', displayName = 'IRON'},
			diamond = {keywords = {'diamond'}, color = Color3.fromRGB(85, 200, 255), icon = 'diamond', displayName = 'DIAMOND'},
			emerald = {keywords = {'emerald'}, color = Color3.fromRGB(0, 255, 100), icon = 'emerald', displayName = 'EMERALD'}
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
		end
		local function isLootEnabled(lootType)
			if lootType == 'iron' then return LootIron.Enabled end
			if lootType == 'diamond' then return LootDiamond.Enabled end
			if lootType == 'emerald' then return LootEmerald.Enabled end
			return false
		end
		local function added(lootHandle, lootType, config)
			if not isLootEnabled(lootType) then return end
			if self.Reference[lootHandle] then return end
			local billboard = Instance.new('BillboardGui')
			billboard.Parent = self.Folder
			billboard.Name = lootType
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			billboard.Size = UDim2.fromOffset(40, 40)
			billboard.AlwaysOnTop = true
			billboard.ClipsDescendants = false
			billboard.Adornee = lootHandle
			local blur = addBlur(billboard)
			if blur then blur.Visible = true end
			local iconImage = bedwars.getIcon({itemType = config.icon}, true)
			if iconImage and iconImage ~= '' then
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
			self.Reference[lootHandle] = billboard
		end
		local function removed(lootHandle)
			if self.Reference[lootHandle] then
				self.Reference[lootHandle]:Destroy()
				self.Reference[lootHandle] = nil
			end
		end
		self.FindLoot = function()
			for _, drop in collectionService:GetTagged('ItemDrop') do
				local handle = drop:FindFirstChild('Handle')
				if handle then
					local lootType, config = getLootType(drop.Name)
					if lootType and isLootEnabled(lootType) and not self.Reference[handle] then
						added(handle, lootType, config)
					end
				end
			end
		end
		self.IsLootEnabled = isLootEnabled
		self.Added = added
		self.Removed = removed
		self.FindLoot()
		self:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(drop)
			if not self.Enabled then return end
			task.defer(function()
				local handle = drop:FindFirstChild('Handle')
				if not handle then return end
				local lootType, config = getLootType(drop.Name)
				if lootType and isLootEnabled(lootType) then
					added(handle, lootType, config)
				end
			end)
		end))
		self:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(drop)
			local handle = drop:FindFirstChild('Handle')
			if handle then
				removed(handle)
			end
		end))
	end
	local lootConfigs = {
		iron = {icon = 'iron', displayName = 'IRON', color = Color3.fromRGB(200, 200, 200)},
		diamond = {icon = 'diamond', displayName = 'DIAMOND', color = Color3.fromRGB(85, 200, 255)},
		emerald = {icon = 'emerald', displayName = 'EMERALD', color = Color3.fromRGB(0, 255, 100)}
	}
	local function refreshLoot(section, lootType)
		if not Loot.Enabled then return end
		local enabled = section.IsLootEnabled and section.IsLootEnabled(lootType)
		if not enabled then
			for handle, billboard in Loot.Reference do
				if billboard.Name == lootType then
					billboard:Destroy()
					Loot.Reference[handle] = nil
				end
			end
		else
			for _, drop in collectionService:GetTagged('ItemDrop') do
				local handle = drop:FindFirstChild('Handle')
				if handle and not Loot.Reference[handle] then
					section.Added(handle, lootType, lootConfigs[lootType])
				end
			end
		end
	end
	LootIron.Function = function() refreshLoot(Loot, 'iron') end
	LootDiamond.Function = function() refreshLoot(Loot, 'diamond') end
	LootEmerald.Function = function() refreshLoot(Loot, 'emerald') end
end)
