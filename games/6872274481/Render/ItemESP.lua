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
	local Items = createSection()
	local ItemESP = vape.Categories.Render:CreateModule({
		Name = 'ItemESP',
		Function = function(callback)
			Items:Set(callback)
			for _, setting in {ItemDistance,
				ItemTransparency,
				ItemScale,
				ItemWhitelistOnly,
				ItemAllowed} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders tags on dropped items'
	})
	local ItemDistance = ItemESP:CreateToggle({Name = 'Item distance', Tooltip = 'Shows the distance of the item'})
	local ItemTransparency = ItemESP:CreateSlider({Name = 'Item transparency', Default = 0.5, Min = 0, Max = 1, Decimal = 100})
	local ItemScale = ItemESP:CreateSlider({Name = 'Item scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10})
	local ItemWhitelistOnly = ItemESP:CreateToggle({Name = 'Item whitelist only', Tooltip = 'Only renders whitelisted items'})
	local ItemAllowed = ItemESP:CreateTextList({Name = 'Item allowed items', Darker = true, Visible = false})
	--------------------------------------------------------------------
	-- Items
	--------------------------------------------------------------------

	Items.Start = function(self)
		local strings, sizes = {}, {}
		local function added(ent)
			local name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
			if ItemWhitelistOnly.Enabled and not table.find(ItemAllowed.ListEnabled, name:lower()) then return end
			strings[ent] = name .. '%s'
			if ItemDistance.Enabled then
				strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '.. strings[ent]
			end
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * ItemScale.Value
			nametag.Font = Enum.Font.Arial
			local size = getfontsize(removeTags(ent.Name), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = ent.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = 0.5
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			local amount = ent:GetAttribute('Amount') or 1
			local suffix = amount >= 2 and ' x' .. tostring(amount) or ''
			nametag.Text = ItemDistance.Enabled and string.format(strings[ent], 0, suffix) or string.format(strings[ent], suffix)
			nametag.TextColor3 = Color3.new(1, 1, 1)
			nametag.RichText = true
			nametag.Parent = self.Folder
			self.Reference[ent] = nametag
		end
		local function updated(ent)
			local nametag = self.Reference[ent]
			if nametag then
				nametag.TextSize = 14 * ItemScale.Value
				nametag.BackgroundTransparency = ItemTransparency.Value
			end
		end
		local function removing(ent)
			if self.Reference[ent] then
				self.Reference[ent]:Destroy()
				self.Reference[ent] = nil
			end
		end
		self:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(removing))
		self:Clean(runService.PreRender:Connect(function()
			for ent, nametag in self.Reference do
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
				nametag.Visible = headVis
				if not headVis then continue end
				local amount = ent:GetAttribute('Amount') or 1
				local mag = ItemDistance.Enabled and entitylib.isAlive
					and math.floor((entitylib.character.RootPart.Position - ent.Position).Magnitude) or nil
				local cache = tostring(mag or '') .. ':' .. tostring(amount)
				if sizes[ent] ~= cache then
					local suffix = amount >= 2 and ' x' .. tostring(amount) or ''
					nametag.Text = ItemDistance.Enabled and string.format(strings[ent], mag or 0, suffix)
						or string.format(strings[ent], suffix)
					local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
					nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
					sizes[ent] = cache
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end))
		for _, v in collectionService:GetTagged('ItemDrop') do
			added(v)
		end
		self.Stop = function()
			table.clear(strings)
			table.clear(sizes)
		end
		self.Updated = updated
	end
	ItemDistance.Function = function()
		Items:Restart()
	end
	ItemTransparency.Function = function()
		if Items.Enabled then
			for ent in Items.Reference do
				local nametag = Items.Reference[ent]
				nametag.TextSize = 14 * ItemScale.Value
				nametag.BackgroundTransparency = ItemTransparency.Value
			end
		end
	end
	ItemScale.Function = ItemTransparency.Function
	ItemWhitelistOnly.Function = function(callback)
		if ItemAllowed.Object then
			ItemAllowed.Object.Visible = callback
		end
		Items:Restart()
	end
	ItemAllowed.Function = function()
		Items:Restart()
	end
end)
