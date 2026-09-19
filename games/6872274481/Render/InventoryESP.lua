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
	local Inventory = createSection()
	local InventoryESP = vape.Categories.Render:CreateModule({
		Name = 'InventoryESP',
		Function = function(callback)
			Inventory:Set(callback)
			for _, setting in {InventoryArmor,
				InventoryEmpty,
				InventoryColor} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Shows the inventory of whoever you are currently targeting'
	})
	local InventoryArmor = InventoryESP:CreateToggle({Name = 'Inventory armour', Default = true})
	local InventoryEmpty = InventoryESP:CreateToggle({Name = 'Inventory empty', Tooltip = 'Keeps the panel up when the server has not shared their inventory yet'})
	local InventoryColor = InventoryESP:CreateColorSlider({
		Name = 'Inventory background colour',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			if InventoryPanel then
				InventoryPanel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				InventoryPanel.BackgroundTransparency = 1 - opacity
			end
		end
	})
	--------------------------------------------------------------------
	-- Inventory
	--------------------------------------------------------------------
	local InventoryPanel

	Inventory.Start = function(self)
		local slotCount, slotSize, slotPadding, columns, headerHeight = 24, 32, 4, 6, 46
		local window, headshot, nametag, grid, armorholder, armordivider
		local slots, armorslots = {}, {}
		local function createSlot(parent)
			local slot = Instance.new('Frame')
			slot.Size = UDim2.fromOffset(slotSize, slotSize)
			slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slot.BorderSizePixel = 0
			slot.Visible = false
			slot.Parent = parent
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = slot
			local stroke = Instance.new('UIStroke')
			stroke.Color = color.Light(uipallet.Main, 0.034)
			stroke.Parent = slot
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = UDim2.fromOffset(slotSize - 8, slotSize - 8)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.BackgroundTransparency = 1
			icon.Parent = slot
			local amount = Instance.new('TextLabel')
			amount.Name = 'Amount'
			amount.Size = UDim2.fromOffset(slotSize - 4, 11)
			amount.Position = UDim2.fromOffset(0, slotSize - 13)
			amount.BackgroundTransparency = 1
			amount.Text = ''
			amount.TextXAlignment = Enum.TextXAlignment.Right
			amount.TextSize = 11
			amount.TextColor3 = uipallet.Text
			amount.TextStrokeColor3 = Color3.new()
			amount.TextStrokeTransparency = 0.4
			amount.FontFace = uipallet.Font
			amount.Parent = slot
			return slot
		end
		local function setSlot(slot, item, highlight)
			if not item or not item.itemType then
				slot.Visible = false
				return
			end
			slot.Visible = true
			slot.Icon.Image = bedwars.getIcon(item, true)
			slot.Amount.Text = (item.amount or 1) > 1 and tostring(item.amount) or ''
			slot.UIStroke.Color = highlight and Color3.fromHSV(InventoryColor.Hue, InventoryColor.Sat, InventoryColor.Value) or color.Light(uipallet.Main, 0.034)
		end
		local function refresh()
			if not window or not window.Parent then return end
			local ent, highest = nil, tick()
			for i, v in targetinfo.Targets do
				if v < tick() then
					targetinfo.Targets[i] = nil
					continue
				end
				if v > highest then
					ent, highest = i, v
				end
			end
			local player = ent and ent.Player or nil
			local inventory = player and store.inventories[player] or nil
			if not ent or (not inventory and not InventoryEmpty.Enabled) then
				window.Visible = false
				return
			end
			window.Visible = true
			nametag.Text = player and player.DisplayName or (ent.Character and ent.Character.Name) or ''
			headshot.Image = 'rbxthumb://type=AvatarHeadShot&id='..(player and player.UserId or 1)..'&w=420&h=420'
			inventory = inventory or {items = {}, armor = {}}
			local hand = inventory.hand
			local shown = 0
			for i, v in slots do
				local item = inventory.items[i]
				setSlot(v, item, item and hand and item.tool == hand.tool)
				if v.Visible then
					shown = i
				end
			end
			local rows = math.max(math.ceil(shown / columns), 1)
			local gridheight = (rows * slotSize) + ((rows - 1) * slotPadding)
			grid.Size = UDim2.new(1, -28, 0, gridheight)
			local height = headerHeight + 10 + gridheight + 10
			if InventoryArmor.Enabled then
				armordivider.Visible = true
				armorholder.Visible = true
				armordivider.Position = UDim2.fromOffset(0, height - 1)
				for i = 1, 3 do
					setSlot(armorslots[i], inventory.armor[i + 3])
				end
				setSlot(armorslots[4], hand, true)
				armorholder.Position = UDim2.fromOffset(14, height + 9)
				height += slotSize + 19
			else
				armordivider.Visible = false
				armorholder.Visible = false
			end
			window.Size = UDim2.fromOffset(240, height)
		end
		window = Instance.new('Frame')
		window.Name = 'ESPInventory'
		window.Size = UDim2.fromOffset(240, headerHeight)
		window.Position = UDim2.fromOffset(12, 260)
		window.BackgroundColor3 = Color3.fromHSV(InventoryColor.Hue, InventoryColor.Sat, InventoryColor.Value)
		window.BackgroundTransparency = 1 - InventoryColor.Opacity
		window.Visible = false
		window.Parent = vape.gui.ScaledGui or vape.gui
		addBlur(window)
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = window
		headshot = Instance.new('ImageLabel')
		headshot.Name = 'Headshot'
		headshot.Size = UDim2.fromOffset(26, 26)
		headshot.Position = UDim2.fromOffset(14, 11)
		headshot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		headshot.Image = ''
		headshot.Parent = window
		local headcorner = Instance.new('UICorner')
		headcorner.CornerRadius = UDim.new(0, 4)
		headcorner.Parent = headshot
		nametag = Instance.new('TextLabel')
		nametag.Name = 'Name'
		nametag.Size = UDim2.new(1, -60, 0, 26)
		nametag.Position = UDim2.fromOffset(48, 11)
		nametag.BackgroundTransparency = 1
		nametag.Text = ''
		nametag.TextXAlignment = Enum.TextXAlignment.Left
		nametag.TextSize = 13
		nametag.TextColor3 = uipallet.Text
		nametag.TextTruncate = Enum.TextTruncate.AtEnd
		nametag.FontFace = uipallet.Font
		nametag.Parent = window
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.fromOffset(0, headerHeight - 1)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		divider.BorderSizePixel = 0
		divider.Parent = window
		grid = Instance.new('Frame')
		grid.Name = 'Items'
		grid.Size = UDim2.new(1, -28, 0, 0)
		grid.Position = UDim2.fromOffset(14, headerHeight + 10)
		grid.BackgroundTransparency = 1
		grid.Parent = window
		local layout = Instance.new('UIGridLayout')
		layout.CellSize = UDim2.fromOffset(slotSize, slotSize)
		layout.CellPadding = UDim2.fromOffset(slotPadding, slotPadding)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i = 1, slotCount do
			local slot = createSlot(grid)
			slot.LayoutOrder = i
			slots[i] = slot
		end
		armordivider = Instance.new('Frame')
		armordivider.Name = 'ArmorDivider'
		armordivider.Size = UDim2.new(1, 0, 0, 1)
		armordivider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		armordivider.BorderSizePixel = 0
		armordivider.Parent = window
		armorholder = Instance.new('Frame')
		armorholder.Name = 'Armour'
		armorholder.Size = UDim2.fromOffset(240, slotSize)
		armorholder.BackgroundTransparency = 1
		armorholder.Parent = window
		local armorlayout = Instance.new('UIListLayout')
		armorlayout.FillDirection = Enum.FillDirection.Horizontal
		armorlayout.Padding = UDim.new(0, slotPadding)
		armorlayout.Parent = armorholder
		for i = 1, 4 do
			local slot = createSlot(armorholder)
			slot.LayoutOrder = i
			armorslots[i] = slot
		end
		InventoryPanel = window
		task.spawn(function()
			repeat
				if not self.Enabled then break end
				refresh()
				task.wait(0.1)
			until false
			window.Visible = false
		end)
		self.Stop = function()
			window:Destroy()
			InventoryPanel = nil
		end
	end
	InventoryArmor.Function = function()
		Inventory:Restart()
	end
	InventoryEmpty.Function = function()
		Inventory:Restart()
	end
end)
