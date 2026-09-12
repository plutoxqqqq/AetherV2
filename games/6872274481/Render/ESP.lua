run(function()
	local ESP
	local Sections = {}
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
		function section:Restart()
			if self.Enabled then
				self:Set(false)
				self:Set(true)
			end
		end
		table.insert(Sections, section)
		return section
	end

	ESP = vape.Categories.Render:CreateModule({
		Name = 'ESP',
		Function = function(callback)
			for _, section in Sections do
				section:Set(callback and section.Toggle and section.Toggle.Enabled or false)
			end
		end,
		Tooltip = 'Renders beds, hives, crates, collectables, crops, generators, items, inventories, loot, pots, chests and traps'
	})

	local function addSection(section, name, tooltip, settings)
		local toggle = ESP:CreateToggle({
			Name = name,
			Tooltip = tooltip,
			Default = true,
			Function = function(callback)
				if ESP.Enabled then
					section:Set(callback)
				end
				for _, setting in settings or {} do
					if setting and setting.Object then
						setting.Object.Visible = callback
					end
				end
			end
		})
		section.Toggle = toggle
		return toggle
	end

	--------------------------------------------------------------------
	-- Beds
	--------------------------------------------------------------------
	local Beds = createSection()
	Beds.Start = function(self)
		local function added(bed)
			if not self.Enabled or self.Reference[bed] then return end
			local bedFolder = Instance.new('Folder')
			bedFolder.Parent = self.Folder
			self.Reference[bed] = bedFolder
			local parts = bed:GetChildren()
			table.sort(parts, function(a, b)
				return a.Name > b.Name
			end)
			for _, part in parts do
				if part:IsA('BasePart') and part.Name ~= 'Blanket' then
					local handle = Instance.new('BoxHandleAdornment')
					handle.Size = part.Size + Vector3.new(0.01, 0.01, 0.01)
					handle.AlwaysOnTop = true
					handle.ZIndex = 2
					handle.Visible = true
					handle.Adornee = part
					handle.Color3 = part.Color
					if part.Name == 'Legs' then
						handle.Color3 = Color3.fromRGB(167, 112, 64)
						handle.Size = part.Size + Vector3.new(0.01, -1, 0.01)
						handle.CFrame = CFrame.new(0, -0.4, 0)
						handle.ZIndex = 0
					end
					handle.Parent = bedFolder
				end
			end
			table.clear(parts)
		end
		self:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
			task.delay(0.2, added, bed)
		end))
		self:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
			if self.Reference[bed] then
				self.Reference[bed]:Destroy()
				self.Reference[bed] = nil
			end
		end))
		for _, bed in collectionService:GetTagged('bed') do
			added(bed)
		end
	end
	local BedsToggle = addSection(Beds, 'Beds', 'Renders beds through walls')
	Beds.Toggle = BedsToggle

	--------------------------------------------------------------------
	-- Beehives
	--------------------------------------------------------------------
	local BeehiveColor = ESP:CreateColorSlider({Name = 'Hive text colour'})
	local BeehiveTransparency = ESP:CreateSlider({Name = 'Hive transparency', Default = 0.5, Min = 0, Max = 1, Decimal = 100})
	local BeehiveScale = ESP:CreateSlider({Name = 'Hive scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10})

	local Beehives = createSection()
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
	local BeehivesToggle = addSection(Beehives, 'Beehives', 'Renders hives locations and info', {BeehiveColor, BeehiveTransparency, BeehiveScale})
	Beehives.Toggle = BeehivesToggle

	--------------------------------------------------------------------
	-- Collectables
	--------------------------------------------------------------------
	local Collectables = createSection()
	local CollectableDistance = ESP:CreateToggle({Name = 'Collectable distance', Default = true})
	local CollectableScale = ESP:CreateSlider({Name = 'Collectable scale', Min = 0.5, Max = 3, Default = 1, Decimal = 10})
	local CollectableTransparency = ESP:CreateSlider({Name = 'Collectable transparency', Min = 0, Max = 1, Default = 0.5, Decimal = 100, Darker = true})
	local CollectableColor = ESP:CreateColorSlider({Name = 'Collectable text colour', Darker = true})
	local CollectableList = ESP:CreateTextList({
		Name = 'Collectables list',
		Default = {'Coin', 'Crystal', 'Crystalheart', 'Energy', 'Ghost', 'Ingredient', 'Metal', 'Plant', 'Seed', 'Shadow Coin', 'Soul', 'Soulvine', 'Star', 'Tearbloom'},
		Darker = true,
		Function = function()
			Collectables:Restart()
		end
	})

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
	local CollectablesToggle = addSection(Collectables, 'Collectables', 'Renders every kit collectable in the map, they have no nametag of their own', {CollectableDistance, CollectableScale, CollectableTransparency, CollectableColor, CollectableList})
	Collectables.Toggle = CollectablesToggle

	--------------------------------------------------------------------
	-- Crates
	--------------------------------------------------------------------
	local Crates = createSection()
	local CrateDistance = ESP:CreateToggle({Name = 'Crate distance', Default = true})
	local CrateScale = ESP:CreateSlider({Name = 'Crate scale', Min = 0.5, Max = 3, Default = 1, Decimal = 10})
	local CrateTransparency = ESP:CreateSlider({Name = 'Crate transparency', Min = 0, Max = 1, Default = 0.5, Decimal = 100, Darker = true})
	local CrateColor = ESP:CreateColorSlider({Name = 'Crate text colour', Darker = true})
	local CrateList = ESP:CreateTextList({
		Name = 'Crates list',
		Default = {'Cauldron', 'Chest', 'Crate', 'Crate Altar', 'Juggernaut Crate', 'Launch Pad', 'Lucky Block', 'Personal Chest', 'Reward Crate', 'Smelter', 'Squad Launcher', 'Team Crate'},
		Darker = true,
		Function = function()
			Crates:Restart()
		end
	})

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
	local CratesToggle = addSection(Crates, 'Crates', 'Renders the crates, chests, cauldrons and lucky blocks in the map with their distance', {CrateDistance, CrateScale, CrateTransparency, CrateColor, CrateList})
	Crates.Toggle = CratesToggle

	--------------------------------------------------------------------
	-- Crops
	--------------------------------------------------------------------
	local CropColor = ESP:CreateColorSlider({Name = 'Crop text colour'})
	local CropTransparency = ESP:CreateSlider({Name = 'Crop transparency', Min = 0, Max = 1, Default = 0.5, Decimal = 100, Darker = true})
	local CropScale = ESP:CreateSlider({Name = 'Crop scale', Min = 0.1, Max = 1.5, Default = 1, Decimal = 10, Darker = true})

	local Crops = createSection()
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
	local CropsToggle = addSection(Crops, 'Crops', 'Renders crops that are ready to harvest', {CropColor, CropTransparency, CropScale})
	Crops.Toggle = CropsToggle

	--------------------------------------------------------------------
	-- Generators
	--------------------------------------------------------------------
	local GeneratorTransparency = ESP:CreateSlider({Name = 'Generator transparency', Default = 0.5, Min = 0, Max = 1, Decimal = 100})
	local GeneratorScale = ESP:CreateSlider({Name = 'Generator scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10})
	local GeneratorWhitelist = ESP:CreateToggle({Name = 'Generator whitelist', Default = true})
	local GeneratorList = ESP:CreateTextList({Name = 'Generators list', Darker = true, Default = {'diamond', 'iron'}})

	local Generators = createSection()
	Generators.Start = function(self)
		local strings, cooldown, updates = {}, {}, {}
		local function getNumber(text)
			if not text or text == '' then return 0 end
			local seconds = text:match('%[(%d+)%]')
			if seconds then return tonumber(seconds) or 0 end
			local justNumber = text:match('(%d+)')
			if justNumber then return tonumber(justNumber) or 0 end
			return 0
		end
		local function updated(ent)
			local nametag = self.Reference[ent]
			if nametag then
				nametag.TextSize = 14 * GeneratorScale.Value
				nametag.BackgroundTransparency = GeneratorTransparency.Value
			end
		end
		local function removing(ent)
			if self.Reference[ent] then
				self.Reference[ent]:Destroy()
				self.Reference[ent] = nil
			end
		end
		local function added(ent)
			local app = ent.RoactTree.TeamOreGeneratorApp
			local name = (app:FindFirstChild('GlobalOreGenerator') or app:FindFirstChild('TeamGenMain'))
			local countdown = (name or app):FindFirstChild('Countdown', true)
			if name then
				name = name:FindFirstChild('Title')
			end
			local tierType = ''
			if name then
				name = name.Text
				tierType = 'iron'
			else
				local ore = ent:GetAttribute('Id')
				ore = ore:sub(0, #ore - 2)
				tierType = (ore:sub(0, 1):upper() .. ore:sub(2, #ore)):lower()
				name = ore:sub(0, 1):upper() .. ore:sub(2, #ore) .. ' Generator'
			end
			if GeneratorWhitelist.Enabled and not table.find(GeneratorList.ListEnabled, tierType) then return end
			strings[ent] = `{name} %s%s`
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * GeneratorScale.Value
			nametag.Font = Enum.Font.Arial
			local format = string.format(strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, '')
			local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = 0.5
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = format
			nametag.TextColor3 = Color3.new(1, 1, 1)
			nametag.RichText = true
			nametag.Parent = self.Folder
			self.Reference[ent] = nametag
			local update = function()
				updates[ent] = true
			end
			self:Clean(ent:GetAttributeChangedSignal('GeneratorLevel'):Connect(update))
			self:Clean(ent:GetAttributeChangedSignal('Cooldown'):Connect(update))
			if countdown then
				cooldown[ent] = countdown
				self:Clean(countdown:GetPropertyChangedSignal('Text'):Connect(update))
			end
			update()
		end
		self.Stop = function()
			table.clear(strings)
			table.clear(cooldown)
			table.clear(updates)
		end
		for _, v in collectionService:GetTagged('Generator') do
			added(v)
		end
		self:Clean(collectionService:GetInstanceAddedSignal('Generator'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('Generator'):Connect(removing))
		self:Clean(runService.PreRender:Connect(function()
			for ent, nametag in self.Reference do
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
				nametag.Visible = headVis
				if not headVis then continue end
				if updates[ent] then
					nametag.Text = string.format(strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, cooldown[ent] and ` | {getNumber(cooldown[ent].Text)}s` or '')
					local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
					nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
					updates[ent] = nil
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end))
	end
	GeneratorTransparency.Function = function()
		if Generators.Enabled then
			for ent in Generators.Reference do
				local nametag = Generators.Reference[ent]
				nametag.TextSize = 14 * GeneratorScale.Value
				nametag.BackgroundTransparency = GeneratorTransparency.Value
			end
		end
	end
	GeneratorScale.Function = GeneratorTransparency.Function
	GeneratorWhitelist.Function = function(callback)
		if GeneratorList.Object then
			GeneratorList.Object.Visible = callback
		end
		Generators:Restart()
	end
	GeneratorList.Function = function()
		Generators:Restart()
	end
	local GeneratorsToggle = addSection(Generators, 'Generators', 'Renders generator locations and info', {GeneratorTransparency, GeneratorScale, GeneratorWhitelist, GeneratorList})
	Generators.Toggle = GeneratorsToggle

	--------------------------------------------------------------------
	-- Items
	--------------------------------------------------------------------
	local ItemDistance = ESP:CreateToggle({Name = 'Item distance', Tooltip = 'Shows the distance of the item'})
	local ItemTransparency = ESP:CreateSlider({Name = 'Item transparency', Default = 0.5, Min = 0, Max = 1, Decimal = 100})
	local ItemScale = ESP:CreateSlider({Name = 'Item scale', Default = 1, Min = 0.1, Max = 1.5, Decimal = 10})
	local ItemWhitelistOnly = ESP:CreateToggle({Name = 'Item whitelist only', Tooltip = 'Only renders whitelisted items'})
	local ItemAllowed = ESP:CreateTextList({Name = 'Item allowed items', Darker = true, Visible = false})

	local Items = createSection()
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
	local ItemsToggle = addSection(Items, 'Items', 'Renders tags on dropped items', {ItemDistance, ItemTransparency, ItemScale, ItemWhitelistOnly, ItemAllowed})
	Items.Toggle = ItemsToggle

	--------------------------------------------------------------------
	-- Inventory
	--------------------------------------------------------------------
	local InventoryArmor = ESP:CreateToggle({Name = 'Inventory armour', Default = true})
	local InventoryEmpty = ESP:CreateToggle({Name = 'Inventory empty', Tooltip = 'Keeps the panel up when the server has not shared their inventory yet'})
	local InventoryPanel
	local Inventory = createSection()
	local InventoryColor = ESP:CreateColorSlider({
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
	local InventoryToggle = addSection(Inventory, 'Inventory', 'Shows the inventory of whoever you are currently targeting', {InventoryArmor, InventoryEmpty, InventoryColor})
	Inventory.Toggle = InventoryToggle

	--------------------------------------------------------------------
	-- Loot
	--------------------------------------------------------------------
	local LootIron = ESP:CreateToggle({Name = 'Loot iron', Default = true})
	local LootDiamond = ESP:CreateToggle({Name = 'Loot diamond', Default = true})
	local LootEmerald = ESP:CreateToggle({Name = 'Loot emerald', Default = true})

	local Loot = createSection()
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
	local LootToggle = addSection(Loot, 'Loot', 'Renders loot drops of iron, diamonds and emeralds', {LootIron, LootDiamond, LootEmerald})
	Loot.Toggle = LootToggle

	--------------------------------------------------------------------
	-- Pots
	--------------------------------------------------------------------
	local Pots = createSection()
	local PotBackground = ESP:CreateToggle({Name = 'Pot background', Default = true})
	local PotColor = ESP:CreateColorSlider({
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
	local PotsToggle = addSection(Pots, 'Pots', 'Renders an icon over desert pots', {PotBackground, PotColor})
	Pots.Toggle = PotsToggle

	--------------------------------------------------------------------
	-- Storage
	--------------------------------------------------------------------
	local Storage = createSection()
	local StorageItems = ESP:CreateTextList({Name = 'Storage items'})
	local StorageBackground = ESP:CreateToggle({Name = 'Storage background', Default = true})
	local StorageColor = ESP:CreateColorSlider({
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
	local StorageToggle = addSection(Storage, 'Storage', 'Displays items in chests', {StorageItems, StorageBackground, StorageColor})
	Storage.Toggle = StorageToggle

	--------------------------------------------------------------------
	-- Traps
	--------------------------------------------------------------------
	local Traps = createSection()
	local TrapBackground = ESP:CreateToggle({Name = 'Trap background', Default = true})
	local TrapColor = ESP:CreateColorSlider({
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
	local TrapsToggle = addSection(Traps, 'Traps', 'Renders traps placed by other teams', {TrapBackground, TrapColor})
	Traps.Toggle = TrapsToggle
end)
