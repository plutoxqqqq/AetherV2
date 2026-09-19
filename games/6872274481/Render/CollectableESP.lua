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
	local Collectables = createSection()
	local CollectableESP = vape.Categories.Render:CreateModule({
		Name = 'CollectableESP',
		Function = function(callback)
			Collectables:Set(callback)
			for _, setting in {CollectableDistance,
				CollectableScale,
				CollectableTransparency,
				CollectableColor,
				CollectableList} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders every kit collectable in the map, they have no nametag of their own'
	})
	local CollectableDistance = CollectableESP:CreateToggle({Name = 'Collectable distance', Default = true})
	local CollectableScale = CollectableESP:CreateSlider({Name = 'Collectable scale', Min = 0.5, Max = 3, Default = 1, Decimal = 10})
	local CollectableTransparency = CollectableESP:CreateSlider({Name = 'Collectable transparency', Min = 0, Max = 1, Default = 0.5, Decimal = 100, Darker = true})
	local CollectableColor = CollectableESP:CreateColorSlider({Name = 'Collectable text colour', Darker = true})
	local CollectableList = CollectableESP:CreateTextList({
		Name = 'Collectables list',
		Default = {'Coin', 'Crystal', 'Crystalheart', 'Energy', 'Ghost', 'Ingredient', 'Metal', 'Plant', 'Seed', 'Shadow Coin', 'Soul', 'Soulvine', 'Star', 'Tearbloom'},
		Darker = true,
		Function = function()
			Collectables:Restart()
		end
	})
	--------------------------------------------------------------------
	-- Collectables
	--------------------------------------------------------------------

	Collectables.Start = function(self)
		local tags = {
			['alchemist_ingedients'] = 'Ingredient',
			['alchemy_crystal'] = 'Crystal',
			['crystalheart_seed'] = 'Crystalheart',
			['forest_environment_plant'] = 'Plant',
			['ghost'] = 'Ghost',
			['hidden-metal'] = 'Metal',
			['jailor_soul'] = 'Soul',
			['murder_coin'] = 'Coin',
			['shadow_coin'] = 'Shadow Coin',
			['soulvine_seed'] = 'Soulvine',
			['spirit_gardener_energy'] = 'Energy',
			['spirit_gardener_seeds'] = 'Seed',
			['stars'] = 'Star',
			['tearbloom_seed'] = 'Tearbloom'
		}
		local function added(obj, tag)
			if self.Reference[obj] or not table.find(CollectableList.ListEnabled, tags[tag]) then return end
			local nametag = Instance.new('TextLabel')
			nametag.Name = tags[tag]
			nametag.Text = tags[tag]
			nametag.TextSize = 14 * CollectableScale.Value
			nametag.FontFace = uipallet.Font
			local size = getfontsize(nametag.Text, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = CollectableTransparency.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.TextColor3 = Color3.fromHSV(CollectableColor.Hue, CollectableColor.Sat, CollectableColor.Value)
			nametag.Parent = self.Folder
			self.Reference[obj] = nametag
		end
		for tag in tags do
			for _, obj in collectionService:GetTagged(tag) do
				added(obj, tag)
			end
			self:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
				added(obj, tag)
			end))
			self:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(obj)
				if self.Reference[obj] then
					self.Reference[obj]:Destroy()
					self.Reference[obj] = nil
				end
			end))
		end
		self:Clean(runService.PreRender:Connect(function()
			local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position
			for i, v in self.Reference do
				local part = i:IsA('Model') and i.PrimaryPart or i
				if not i.Parent or not part then
					v:Destroy()
					self.Reference[i] = nil
					continue
				end
				local screenPos, visible = gameCamera:WorldToViewportPoint(part.Position + Vector3.new(0, 2, 0))
				v.Visible = visible
				if not visible then continue end
				local text = CollectableDistance.Enabled and localPosition and `{v.Name} | {((localPosition - part.Position).Magnitude) // 1}m` or v.Name
				if v.Text ~= text then
					v.Text = text
					local size = getfontsize(text, v.TextSize, v.FontFace, Vector2.new(100000, 100000))
					v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				end
				v.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
			end
		end))
	end
	CollectableScale.Function = function(value)
		for _, v in Collectables.Reference do
			v.TextSize = 14 * value
			local size = getfontsize(v.Text, v.TextSize, v.FontFace, Vector2.new(100000, 100000))
			v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		end
	end
	CollectableTransparency.Function = function(value)
		for _, v in Collectables.Reference do
			v.BackgroundTransparency = value
		end
	end
	CollectableColor.Function = function(hue, sat, val)
		for _, v in Collectables.Reference do
			v.TextColor3 = Color3.fromHSV(hue, sat, val)
		end
	end
end)
