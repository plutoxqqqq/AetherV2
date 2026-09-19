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
	local Crates = createSection()
	local CrateESP = vape.Categories.Render:CreateModule({
		Name = 'CrateESP',
		Function = function(callback)
			Crates:Set(callback)
			for _, setting in {CrateDistance,
				CrateScale,
				CrateTransparency,
				CrateColor,
				CrateList} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Renders the crates, chests, cauldrons and lucky blocks in the map with their distance'
	})
	local CrateDistance = CrateESP:CreateToggle({Name = 'Crate distance', Default = true})
	local CrateScale = CrateESP:CreateSlider({Name = 'Crate scale', Min = 0.5, Max = 3, Default = 1, Decimal = 10})
	local CrateTransparency = CrateESP:CreateSlider({Name = 'Crate transparency', Min = 0, Max = 1, Default = 0.5, Decimal = 100, Darker = true})
	local CrateColor = CrateESP:CreateColorSlider({Name = 'Crate text colour', Darker = true})
	local CrateList = CrateESP:CreateTextList({
		Name = 'Crates list',
		Default = {'Cauldron', 'Chest', 'Crate', 'Crate Altar', 'Juggernaut Crate', 'Launch Pad', 'Lucky Block', 'Personal Chest', 'Reward Crate', 'Smelter', 'Squad Launcher', 'Team Crate'},
		Darker = true,
		Function = function()
			Crates:Restart()
		end
	})
	--------------------------------------------------------------------
	-- Crates
	--------------------------------------------------------------------

	Crates.Start = function(self)
		local tags = {
			['CrateAltar'] = 'Crate Altar',
			['GlitchedLuckyBlock'] = 'Lucky Block',
			['GrowingHalloweenLuckyBlock'] = 'Lucky Block',
			['HalloweenLuckyBlock'] = 'Lucky Block',
			['MagicalHeroLuckyBlock'] = 'Lucky Block',
			['NewYearsLuckyBlock'] = 'Lucky Block',
			['RewardCrate'] = 'Reward Crate',
			['brewing_cauldron'] = 'Cauldron',
			['cauldron'] = 'Cauldron',
			['chest'] = 'Chest',
			['crate'] = 'Crate',
			['infected-crate'] = 'Crate',
			['juggernaut-crate'] = 'Juggernaut Crate',
			['launch-pad'] = 'Launch Pad',
			['personal-chest'] = 'Personal Chest',
			['smelter-block'] = 'Smelter',
			['squad-launcher'] = 'Squad Launcher',
			['team-crate'] = 'Team Crate'
		}
		local parts = setmetatable({}, {__mode = 'k'})
		local function added(obj, tag)
			if self.Reference[obj] or not table.find(CrateList.ListEnabled, tags[tag]) then return end
			local nametag = Instance.new('TextLabel')
			nametag.Name = tags[tag]
			nametag.Text = tags[tag]
			nametag.TextSize = 14 * CrateScale.Value
			nametag.FontFace = uipallet.Font
			local size = getfontsize(nametag.Text, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = CrateTransparency.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.TextColor3 = Color3.fromHSV(CrateColor.Hue, CrateColor.Sat, CrateColor.Value)
			nametag.Parent = self.Folder
			parts[obj] = obj:IsA('Model') and obj.PrimaryPart or obj:IsA('BasePart') and obj or obj:FindFirstChildWhichIsA('BasePart')
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
				local part = parts[i]
				if not part then
					part = i:IsA('Model') and i.PrimaryPart or i:IsA('BasePart') and i or i:FindFirstChildWhichIsA('BasePart')
					parts[i] = part
				end
				if not i.Parent or not part then
					v:Destroy()
					self.Reference[i] = nil
					continue
				end
				local screenPos, visible = gameCamera:WorldToViewportPoint(part.Position + Vector3.new(0, 2, 0))
				v.Visible = visible
				if not visible then continue end
				local text = CrateDistance.Enabled and localPosition and `{v.Name} | {((localPosition - part.Position).Magnitude) // 1}m` or v.Name
				if v.Text ~= text then
					v.Text = text
					local size = getfontsize(text, v.TextSize, v.FontFace, Vector2.new(100000, 100000))
					v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				end
				v.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
			end
		end))
		self.Stop = function()
			table.clear(parts)
		end
	end
	CrateScale.Function = function(value)
		for _, v in Crates.Reference do
			v.TextSize = 14 * value
			local size = getfontsize(v.Text, v.TextSize, v.FontFace, Vector2.new(100000, 100000))
			v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		end
	end
	CrateTransparency.Function = function(value)
		for _, v in Crates.Reference do
			v.BackgroundTransparency = value
		end
	end
	CrateColor.Function = function(hue, sat, val)
		for _, v in Crates.Reference do
			v.TextColor3 = Color3.fromHSV(hue, sat, val)
		end
	end
end)
