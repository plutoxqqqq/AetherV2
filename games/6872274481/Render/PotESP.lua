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
	local Pots = createSection()
	local PotESP = vape.Categories.Render:CreateModule({
		Name = 'PotESP',
		Function = function(callback)
			Pots:Set(callback)
			for _, setting in {PotBackground,
				PotColor} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders an icon over desert pots'
	})
	local PotBackground = PotESP:CreateToggle({Name = 'Pot background', Default = true})
	local PotColor = PotESP:CreateColorSlider({
		Name = 'Pot background colour',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			for _, v in Pots.Reference do
				v.ViewportFrame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ViewportFrame.BackgroundTransparency = 1 - (PotBackground.Enabled and opacity or 0)
			end
		end
	})
	--------------------------------------------------------------------
	-- Pots
	--------------------------------------------------------------------

	Pots.Start = function(self)
		local template
		local function added(block)
			if block.Name ~= 'desert_pot' or self.Reference[block] then return end
			local billboard = Instance.new('BillboardGui')
			billboard.Parent = self.Folder
			billboard.Name = block.Name
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			billboard.Size = UDim2.fromOffset(36, 36)
			billboard.AlwaysOnTop = true
			billboard.ClipsDescendants = false
			billboard.Adornee = block
			local blur = addBlur(billboard)
			if blur then blur.Visible = PotBackground.Enabled end
			local viewport = Instance.new('ViewportFrame')
			viewport.Size = UDim2.fromOffset(36, 36)
			viewport.Position = UDim2.fromScale(0.5, 0.5)
			viewport.AnchorPoint = Vector2.new(0.5, 0.5)
			viewport.BackgroundColor3 = Color3.fromHSV(PotColor.Hue, PotColor.Sat, PotColor.Value)
			viewport.BackgroundTransparency = 1 - (PotBackground.Enabled and PotColor.Opacity or 0)
			viewport.BorderSizePixel = 0
			viewport.Ambient = Color3.new(1, 1, 1)
			viewport.LightColor = Color3.new(1, 1, 1)
			viewport.Parent = billboard
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = viewport
			if template == nil then
				local assets = replicatedStorage:FindFirstChild('Assets')
				local blocks = assets and assets:FindFirstChild('Blocks')
				local model = blocks and blocks:FindFirstChild('desert_pot')
				template = model and model:FindFirstChildWhichIsA('MeshPart', true) or false
			end
			if template then
				local mesh = template:Clone()
				mesh.CFrame = CFrame.Angles(0, math.rad(25), 0)
				mesh.Parent = viewport
				local camera = Instance.new('Camera')
				camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.75, 3.9), Vector3.new(0, 0.05, 0))
				camera.Parent = viewport
				viewport.CurrentCamera = camera
			end
			self.Reference[block] = billboard
		end
		self.Added = added
		for _, v in collectionService:GetTagged('block') do
			added(v)
		end
		self:Clean(collectionService:GetInstanceAddedSignal('block'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('block'):Connect(function(block)
			if self.Reference[block] then
				self.Reference[block]:Destroy()
				self.Reference[block] = nil
			end
		end))
	end
	PotBackground.Function = function(callback)
		PotColor.Object.Visible = callback
		for _, v in Pots.Reference do
			v.ViewportFrame.BackgroundTransparency = 1 - (callback and PotColor.Opacity or 0)
			if v.Blur then v.Blur.Visible = callback end
		end
	end
end)
