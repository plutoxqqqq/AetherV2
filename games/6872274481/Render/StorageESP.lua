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
	local Storage = createSection()
	local StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			Storage:Set(callback)
			for _, setting in {StorageItems,
				StorageBackground,
				StorageColor} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Displays items in chests'
	})
	local StorageItems = StorageESP:CreateTextList({Name = 'Storage items'})
	local StorageBackground = StorageESP:CreateToggle({Name = 'Storage background', Default = true})
	local StorageColor = StorageESP:CreateColorSlider({
		Name = 'Storage background colour',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			for _, v in Storage.Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end
	})
	--------------------------------------------------------------------
	-- Storage
	--------------------------------------------------------------------

	Storage.Start = function(self)
		local connections = {}
		local function nearStorageItem(item)
			for _, v in StorageItems.ListEnabled do
				if item:find(v) then
					return v
				end
			end
		end
		local function refreshAdornee(v)
			local chest = v.Adornee:FindFirstChild('ChestFolderValue')
			chest = chest and chest.Value or nil
			if not chest then
				v.Enabled = false
				return
			end
			local chestitems = chest and chest:GetChildren() or {}
			for _, obj in v.Frame:GetChildren() do
				if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
					obj:Destroy()
				end
			end
			v.Enabled = false
			local alreadygot = {}
			for _, item in chestitems do
				if not alreadygot[item.Name] and (table.find(StorageItems.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
					alreadygot[item.Name] = true
					v.Enabled = true
					local blockimage = Instance.new('ImageLabel')
					blockimage.Size = UDim2.fromOffset(32, 32)
					blockimage.BackgroundTransparency = 1
					blockimage.Image = bedwars.getIcon({itemType = item.Name}, true)
					blockimage.Parent = v.Frame
				end
			end
			table.clear(chestitems)
		end
		local function removing(v)
			local billboard = self.Reference[v]
			if billboard then
				billboard:Destroy()
				self.Reference[v] = nil
			end
			local list = connections[v]
			if list then
				for _, connection in list do
					connection:Disconnect()
				end
				table.clear(list)
				connections[v] = nil
			end
		end
		local function clear()
			local references = table.clone(self.Reference)
			for v in references do
				removing(v)
			end
			table.clear(references)
		end
		local function added(v)
			local chest = v:WaitForChild('ChestFolderValue', 3)
			if not (chest and self.Enabled and v:HasTag('chest')) then return end
			if self.Reference[v] then
				removing(v)
			end
			chest = chest.Value
			if not chest then return end
			local billboard = Instance.new('BillboardGui')
			billboard.Parent = self.Folder
			billboard.Name = 'chest'
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			billboard.Size = UDim2.fromOffset(36, 36)
			billboard.AlwaysOnTop = true
			billboard.ClipsDescendants = false
			billboard.Adornee = v
			local blur = addBlur(billboard)
			if blur then blur.Visible = StorageBackground.Enabled end
			local frame = Instance.new('Frame')
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = Color3.fromHSV(StorageColor.Hue, StorageColor.Sat, StorageColor.Value)
			frame.BackgroundTransparency = 1 - (StorageBackground.Enabled and StorageColor.Opacity or 0)
			frame.Parent = billboard
			local layout = Instance.new('UIListLayout')
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Padding = UDim.new(0, 4)
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			local layoutConnection = layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
			end)
			layout.Parent = frame
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = frame
			self.Reference[v] = billboard
			connections[v] = {
				layoutConnection,
				chest.ChildAdded:Connect(function(item)
					if table.find(StorageItems.ListEnabled, item.Name) or nearStorageItem(item.Name) then
						refreshAdornee(billboard)
					end
				end),
				chest.ChildRemoved:Connect(function(item)
					if table.find(StorageItems.ListEnabled, item.Name) or nearStorageItem(item.Name) then
						refreshAdornee(billboard)
					end
				end)
			}
			task.spawn(refreshAdornee, billboard)
		end
		self.Refresh = function()
			for _, v in self.Reference do
				task.spawn(refreshAdornee, v)
			end
		end
		self:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('chest'):Connect(removing))
		self:Clean(clear)
		for _, v in collectionService:GetTagged('chest') do
			task.spawn(added, v)
		end
		self.Stop = function()
			table.clear(connections)
		end
	end
	StorageItems.Function = function()
		if Storage.Refresh then Storage.Refresh() end
	end
	StorageBackground.Function = function(callback)
		StorageColor.Object.Visible = callback
		for _, v in Storage.Reference do
			v.Frame.BackgroundTransparency = 1 - (callback and StorageColor.Opacity or 0)
			if v.Blur then v.Blur.Visible = callback end
		end
	end
end)
