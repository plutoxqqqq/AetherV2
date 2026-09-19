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
	local Crops = createSection()
	local CropESP = vape.Categories.Render:CreateModule({
		Name = 'CropESP',
		Function = function(callback)
			Crops:Set(callback)
			for _, setting in {CropColor,
				CropTransparency,
				CropScale} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders crops that are ready to harvest'
	})
	local CropColor = CropESP:CreateColorSlider({Name = 'Crop text colour'})
	local CropTransparency = CropESP:CreateSlider({Name = 'Crop transparency', Min = 0, Max = 1, Default = 0.5, Decimal = 100, Darker = true})
	local CropScale = CropESP:CreateSlider({Name = 'Crop scale', Min = 0.1, Max = 1.5, Default = 1, Decimal = 10, Darker = true})
	--------------------------------------------------------------------
	-- Crops
	--------------------------------------------------------------------

	Crops.Start = function(self)
		local function added(ent)
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * CropScale.Value
			nametag.Font = Enum.Font.Arial
			nametag.Text = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or 'Crop'
			local size = getfontsize(nametag.Text, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = ent.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = CropTransparency.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.TextColor3 = Color3.fromHSV(CropColor.Hue, CropColor.Sat, CropColor.Value)
			nametag.RichText = true
			nametag.Parent = self.Folder
			self.Reference[ent] = nametag
		end
		for _, v in collectionService:GetTagged('HarvestableCrop') do
			added(v)
		end
		self:Clean(collectionService:GetInstanceAddedSignal('HarvestableCrop'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('HarvestableCrop'):Connect(function(ent)
			if self.Reference[ent] then
				self.Reference[ent]:Destroy()
				self.Reference[ent] = nil
			end
		end))
		self:Clean(runService.PreRender:Connect(function()
			for i, v in self.Reference do
				if not i.Parent then
					v:Destroy()
					self.Reference[i] = nil
					continue
				end
				local screenPos, visible = gameCamera:WorldToViewportPoint((i:IsA('Model') and i:GetPivot().Position or i.Position) + Vector3.new(0, 1, 0))
				v.Visible = visible
				if visible then
					v.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
				end
			end
		end))
	end
	CropColor.Function = function()
		if not Crops.Enabled then return end
		for _, v in Crops.Reference do
			v.TextColor3 = Color3.fromHSV(CropColor.Hue, CropColor.Sat, CropColor.Value)
		end
	end
	CropTransparency.Function = function(value)
		if not Crops.Enabled then return end
		for _, v in Crops.Reference do
			v.BackgroundTransparency = value
		end
	end
	CropScale.Function = function(value)
		if not Crops.Enabled then return end
		for _, v in Crops.Reference do
			v.TextSize = 14 * value
			local size = getfontsize(v.Text, v.TextSize, v.FontFace, Vector2.new(100000, 100000))
			v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		end
	end
end)
