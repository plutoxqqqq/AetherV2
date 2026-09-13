run(function()
    local BedPlates
    local Background
    local Color
    local LayerCounter
    local LayerColor
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local function getBlockLayerHealth(block)
	local meta = bedwars.ItemMeta[block]
	return meta and meta.block and meta.block.health or 0
    end

    local function getLayerColor()
	return LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.new(1, 1, 1)
    end

    local function scanSide(self, start, tab)
	for _, side in sides do
		local layers = {}
		for i = 1, 15 do
			local block = getPlacedBlock(start + (side * i))
			if not block or block == self or block.Name == 'bed' then
				break
			end
			if not block:GetAttribute('NoBreak') then
				layers[block.Name] = (layers[block.Name] or 0) + 1
			end
		end

		for block, amount in layers do
			tab[block] = math.max(tab[block] or 0, amount)
		end
	end
    end

    local function refreshAdornee(v)
	for _, obj in v.Frame:GetChildren() do
		if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
			obj:Destroy()
		end
	end

	local start = v.Adornee.Position
	local layers = {}
	local alreadygot = {}
	scanSide(v.Adornee, start, layers)
	scanSide(v.Adornee, start + Vector3.new(0, 0, 3), layers)
	for block, amount in layers do
		table.insert(alreadygot, {block, amount})
	end
	table.sort(alreadygot, function(a, b)
		local healthA, healthB = getBlockLayerHealth(a[1]), getBlockLayerHealth(b[1])
		return healthA == healthB and a[1] < b[1] or healthA > healthB
	end)
	v.Enabled = #alreadygot > 0

	for _, blockData in alreadygot do
		local block, amount = blockData[1], blockData[2]
		local blockimage = Instance.new('ImageLabel')
		blockimage.Size = UDim2.fromOffset(32, 32)
		blockimage.BackgroundTransparency = 1
		blockimage.Image = bedwars.getIcon({ itemType = block }, true)
		blockimage.Parent = v.Frame
		if amount > 1 and (not LayerCounter or LayerCounter.Enabled) then
			local amounttext = Instance.new('TextLabel')
			amounttext.Name = 'Amount'
			amounttext.Size = UDim2.fromScale(1, 1)
			amounttext.BackgroundTransparency = 1
			amounttext.Text = tostring(amount)
			amounttext.TextColor3 = getLayerColor()
			amounttext.TextSize = 16
			amounttext.TextStrokeTransparency = 0.3
			amounttext.Font = Enum.Font.Arial
			amounttext.Parent = blockimage
		end
	end
    end

    local function refreshAll()
	for _, v in Reference do
		refreshAdornee(v)
	end
    end

    local function updateLayerTextColor()
	local textColor = getLayerColor()
	for _, v in Reference do
		for _, obj in v.Frame:GetDescendants() do
			if obj:IsA('TextLabel') and obj.Name == 'Amount' then
				obj.TextColor3 = textColor
			end
		end
	end
    end

    local function Added(v)
	local billboard = Instance.new('BillboardGui')
	billboard.Parent = Folder
	billboard.Name = 'bed'
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.Size = UDim2.fromOffset(36, 36)
	billboard.AlwaysOnTop = true
	billboard.ClipsDescendants = false
	billboard.Adornee = v
	local blur = addBlur(billboard)
	blur.Visible = Background.Enabled
	local frame = Instance.new('Frame')
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
	frame.Parent = billboard
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
	Reference[v] = billboard
	refreshAdornee(billboard)
    end

    local function refreshNear(data)
	data = data.blockRef.blockPosition * 3
	for i, v in Reference do
		if (data - i.Position).Magnitude <= 30 then
			refreshAdornee(v)
		end
	end
    end

    BedPlates = vape.Categories.Render:CreateModule({
	Name = 'BedPlates',
	Function = function(callback)
		if callback then
			for _, v in collectionService:GetTagged('bed') do
				task.spawn(Added, v)
			end
			BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
			BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
			BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
			BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
				if Reference[v] then
					Reference[v]:Destroy()
					Reference[v]:ClearAllChildren()
					Reference[v] = nil
				end
			end))
		else
			table.clear(Reference)
			Folder:ClearAllChildren()
		end
	end,
	Tooltip = 'Displays blocks over the bed',
    })
    Background = BedPlates:CreateToggle({
	Name = 'Background',
	Function = function(callback)
		if Color and Color.Object then
			Color.Object.Visible = callback
		end
		for _, v in Reference do
			v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
			v.Blur.Visible = callback
		end
	end,
	Default = true,
    })
    Color = BedPlates:CreateColorSlider({
	Name = 'Background Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		for _, v in Reference do
			v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			v.Frame.BackgroundTransparency = 1 - opacity
		end
	end,
	Darker = true,
    })
    LayerCounter = BedPlates:CreateToggle({
	Name = 'Layer Counter',
	Function = function(callback)
		if LayerColor and LayerColor.Object then
			LayerColor.Object.Visible = callback
		end
		refreshAll()
	end,
	Default = true,
    })
    LayerColor = BedPlates:CreateColorSlider({
	Name = 'Counter Text Color',
	DefaultSat = 0,
	DefaultValue = 1,
	Function = function()
		updateLayerTextColor()
	end,
	Visible = LayerCounter.Enabled,
    })
end)
