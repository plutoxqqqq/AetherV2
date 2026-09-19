run(function()
	local AutoCrypt
	local ESP
	local Background
	local Color
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local tracked = {}

	local function icon()
		local ok, image = pcall(function() return bedwars.getIcon({itemType = 'gravestone'}, true) end)
		return ok and image or ''
	end

	local function add(obj)
		if tracked[obj] or not obj or not obj.Parent then return end

		local part = not obj:IsA('Model') and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart', true))
		if not part then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'gravestone'
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = part
		billboard.Parent = Folder

		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled

		local image = Instance.new('ImageLabel')
		image.Name = 'Icon'
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = icon()
		image.Parent = billboard

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = image

		tracked[obj] = billboard
	end

	local function remove(obj)
		if not tracked[obj] then return end
		tracked[obj]:Destroy()
		tracked[obj] = nil
	end

	local function clear()
		for _, billboard in tracked do
			billboard:Destroy()
		end
		table.clear(tracked)
	end

	local function start()
		for _, obj in collectionService:GetTagged('Gravestone') do
			add(obj)
		end

		AutoCrypt:Clean(collectionService:GetInstanceAddedSignal('Gravestone'):Connect(function(obj)
			if ESP.Enabled then add(obj) end
		end))
		AutoCrypt:Clean(collectionService:GetInstanceRemovedSignal('Gravestone'):Connect(remove))
		AutoCrypt:Clean(runService.RenderStepped:Connect(function()
			if not ESP.Enabled then return end
			for obj in tracked do
				if not obj or not obj.Parent then remove(obj) end
			end
		end))
	end

	AutoCrypt = kits:CreateModule({
		Name = 'AutoCrypt',
		Function = function(callback)
			if not callback then
				clear()
				return
			end
			if ESP.Enabled then start() end
		end,
		Tooltip = 'Shows every gravestone on the map, so you can see what the Crypt kit could claim'
	})

	ESP = AutoCrypt:CreateToggle({
		Name = 'Gravestone ESP',
		Tooltip = 'Shows gravestones where they are',
		Function = function(enabled)
			if Background and Background.Object then Background.Object.Visible = enabled end
			if Color and Color.Object then Color.Object.Visible = (enabled and Background.Enabled) end

			if not AutoCrypt.Enabled then return end
			if enabled then
				start()
			else
				clear()
			end
		end
	})
	Background = AutoCrypt:CreateToggle({
		Name = 'Background',
		Default = true,
		Tooltip = 'Draws a box behind the icon',
		Function = function(enabled)
			if Color and Color.Object then Color.Object.Visible = (enabled and ESP.Enabled) end
			for _, billboard in tracked do
				local blur = billboard:FindFirstChild('Blur')
				if blur then blur.Visible = enabled end
				local image = billboard:FindFirstChild('Icon')
				if image then image.BackgroundTransparency = 1 - (enabled and Color.Opacity or 0) end
			end
		end
	})
	Color = AutoCrypt:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			for _, billboard in tracked do
				local image = billboard:FindFirstChild('Icon')
				if image then
					image.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					image.BackgroundTransparency = 1 - opacity
				end
			end
		end
	})

	task.defer(function()
		if Background and Background.Object then Background.Object.Visible = ESP.Enabled end
		if Color and Color.Object then Color.Object.Visible = (ESP.Enabled and Background.Enabled) end
	end)
end)
