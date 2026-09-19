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
	local Traps = createSection()
	local TrapESP = vape.Categories.Render:CreateModule({
		Name = 'TrapESP',
		Function = function(callback)
			Traps:Set(callback)
			for _, setting in {TrapBackground,
				TrapColor} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders traps placed by other teams'
	})
	local TrapBackground = TrapESP:CreateToggle({Name = 'Trap background', Default = true})
	local TrapColor = TrapESP:CreateColorSlider({
		Name = 'Trap background colour',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			for _, v in Traps.Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end
	})
	--------------------------------------------------------------------
	-- Traps
	--------------------------------------------------------------------

	Traps.Start = function(self)
		local function added(v)
			local billboard = Instance.new('BillboardGui')
			billboard.Parent = self.Folder
			billboard.Name = 'trap'
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			billboard.Size = UDim2.fromOffset(36, 36)
			billboard.AlwaysOnTop = true
			billboard.ClipsDescendants = false
			billboard.Adornee = v
			local blur = addBlur(billboard)
			if blur then blur.Visible = TrapBackground.Enabled end
			local frame = Instance.new('Frame')
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = Color3.fromHSV(TrapColor.Hue, TrapColor.Sat, TrapColor.Value)
			frame.BackgroundTransparency = 1 - (TrapBackground.Enabled and TrapColor.Opacity or 0)
			frame.Parent = billboard
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(32, 32)
			image.BackgroundTransparency = 1
			image.Image = bedwars.getIcon({itemType = 'snap_trap'}, true)
			image.Parent = frame
			local layout = Instance.new('UIListLayout')
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Padding = UDim.new(0, 4)
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
			end)
			layout.Parent = frame
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = frame
			self.Reference[v] = billboard
		end
		self:Clean(collectionService:GetInstanceAddedSignal('snap_trap'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('snap_trap'):Connect(function(v)
			if self.Reference[v] then
				self.Reference[v]:Destroy()
				self.Reference[v] = nil
			end
		end))
		for _, v in collectionService:GetTagged('snap_trap') do
			added(v)
		end
	end
	TrapBackground.Function = function(callback)
		TrapColor.Object.Visible = callback
		for _, v in Traps.Reference do
			v.Frame.BackgroundTransparency = 1 - (callback and TrapColor.Opacity or 0)
			if v.Blur then v.Blur.Visible = callback end
		end
	end
end)
