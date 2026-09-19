run(function()
	local OreESP
	local Background
	local Color
	local Scale
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local tracked = {}

	local function icon()
		local ok, image = pcall(function() return bedwars.getIcon({itemType = 'iron'}, true) end)
		return ok and image or ''
	end

	local function isOre(obj)
		if typeof(obj) ~= 'Instance' or not obj:IsA('BasePart') then return false end
		return obj.Name:lower():find('ore_mesh_block') ~= nil
	end

	local function create(obj)
		if tracked[obj] or not isOre(obj) then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'ore'
		billboard.Size = UDim2.fromOffset(40, 40)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = obj
		billboard.Parent = Folder

		local frame = Instance.new('Frame')
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = Background.Enabled and 0.4 or 1
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BorderSizePixel = 0
		frame.Parent = billboard

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame

		local image = Instance.new('ImageLabel')
		image.Size = UDim2.new(1, -6, 1, -6)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = icon()
		image.Parent = frame

		local blur = addBlur(frame)
		blur.Visible = Background.Enabled

		tracked[obj] = {Billboard = billboard, Frame = frame, Blur = blur, Image = image}
		applyScale()
	end

	local function remove(obj)
		local entry = tracked[obj]
		if not entry then return end
		entry.Billboard:Destroy()
		tracked[obj] = nil
	end

	local function applyScale()
		for _, entry in tracked do
			entry.Billboard.Size = UDim2.fromOffset(40, 40) * Scale.Value
		end
	end

	local function clear()
		for _, entry in tracked do
			entry.Billboard:Destroy()
		end
		table.clear(tracked)
	end

	OreESP = vape.Categories.Render:CreateModule({
		Name = 'OreESP',
		Function = function(callback)
			if not callback then
				clear()
				return
			end

			for _, obj in workspace:GetDescendants() do
				create(obj)
			end

			OreESP:Clean(workspace.DescendantAdded:Connect(function(obj)
				task.wait(0.1)
				if OreESP.Enabled then create(obj) end
			end))
			OreESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
				remove(obj)
			end))
		end,
		Tooltip = 'Puts an icon above ore blocks in the map so you can find them'
	})

	Background = OreESP:CreateToggle({
		Name = 'Background',
		Default = true,
		Tooltip = 'Draws a box behind the icon',
		Function = function(enabled)
			if Color and Color.Object then Color.Object.Visible = enabled end
			for _, entry in tracked do
				entry.Frame.BackgroundTransparency = enabled and 0.4 or 1
				entry.Blur.Visible = enabled
			end
		end
	})
	Color = OreESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.6,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			for _, entry in tracked do
				entry.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				entry.Frame.BackgroundTransparency = 1 - opacity
			end
		end
	})
	Scale = OreESP:CreateSlider({
		Name = 'Scale',
		Min = 0.5,
		Max = 3,
		Default = 1,
		Decimal = 10,
		Function = applyScale
	})

	task.defer(function()
		if Color and Color.Object then Color.Object.Visible = Background.Enabled end
	end)
end)
