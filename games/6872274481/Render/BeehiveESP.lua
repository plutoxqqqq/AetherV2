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
	local Beehives = createSection()
	local BeehiveESP = vape.Categories.Render:CreateModule({
		Name = 'BeehiveESP',
		Function = function(callback)
			Beehives:Set(callback)
			for _, setting in {BeehiveColor,
				BeehiveTransparency,
				BeehiveScale} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders hives locations and info'
	})
	local BeehiveColor = BeehiveESP:CreateColorSlider({Name = 'Hive text colour'})
	local BeehiveTransparency = BeehiveESP:CreateSlider({Name = 'Hive transparency', Default = 0.5, Min = 0, Max = 1, Decimal = 100})
	local BeehiveScale = BeehiveESP:CreateSlider({Name = 'Hive scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10})
	--------------------------------------------------------------------
	-- Beehives
	--------------------------------------------------------------------

	Beehives.Start = function(self)
		local strings, updates = {}, {}
		local function updated(ent)
			local nametag = self.Reference[ent]
			if nametag then
				nametag.TextSize = 14 * BeehiveScale.Value
				nametag.TextColor3 = Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
				nametag.BackgroundTransparency = BeehiveTransparency.Value
			end
		end
		local function removing(ent)
			if self.Reference[ent] then
				self.Reference[ent]:Destroy()
				self.Reference[ent] = nil
			end
		end
		local function added(ent)
			local name = playersService:GetNameFromUserIdAsync(ent:GetAttribute('PlacedByUserId')) or 'Unknown'
			strings[ent] = `{name}'s beehive | %s Bee%s`
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * BeehiveScale.Value
			nametag.Font = Enum.Font.Arial
			local format = string.format(strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
			local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = 0.5
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = format
			nametag.TextColor3 = Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
			nametag.RichText = true
			nametag.Parent = self.Folder
			self.Reference[ent] = nametag
			self:Clean(ent:GetAttributeChangedSignal('Level'):Connect(function()
				updates[ent] = true
			end))
			updates[ent] = true
		end
		self.Stop = function(inner)
			table.clear(strings)
			table.clear(updates)
		end
		for _, v in collectionService:GetTagged('beehive') do
			added(v)
		end
		self:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(removing))
		self:Clean(runService.PreRender:Connect(function()
			for ent, nametag in self.Reference do
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
				nametag.Visible = headVis
				if not headVis then continue end
				if updates[ent] then
					nametag.Text = string.format(strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
					local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
					nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
					updates[ent] = nil
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end))
	end
	BeehiveColor.Function = function()
		if Beehives.Enabled then
			for ent in Beehives.Reference do
				local nametag = Beehives.Reference[ent]
				nametag.TextSize = 14 * BeehiveScale.Value
				nametag.TextColor3 = Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
				nametag.BackgroundTransparency = BeehiveTransparency.Value
			end
		end
	end
	BeehiveTransparency.Function = BeehiveColor.Function
	BeehiveScale.Function = BeehiveColor.Function
end)
