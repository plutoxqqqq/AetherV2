run(function()
    local TrapESP
    local Background
    local Color

    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

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
	local image = Instance.new('ImageLabel')
	image.Size = UDim2.fromOffset(32, 32)
	image.BackgroundTransparency = 1
	image.Image = bedwars.getIcon({ itemType = 'snap_trap' }, true)
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
	Reference[v] = billboard
    end

    TrapESP = vape.Categories.Render:CreateModule({
	Name = 'TrapESP',
	Function = function(callback)
		if callback then
			repeat
				task.wait()
			until store.matchState ~= 0 or not TrapESP.Enabled
			if not TrapESP.Enabled then
				return
			end

			TrapESP:Clean(collectionService:GetInstanceAddedSignal('snap_trap'):Connect(Added))
			TrapESP:Clean(collectionService:GetInstanceRemovedSignal('snap_trap'):Connect(function(v)
				if Reference[v] then
					Reference[v]:Destroy()
					Reference[v] = nil
				end
			end))
		else
			table.clear(Reference)
			Folder:ClearAllChildren()
		end
	end,
	Tooltip = 'Render traps placed by other teams'
    })

    Background = TrapESP:CreateToggle({
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
	Default = true
    })
    Color = TrapESP:CreateColorSlider({
	Name = 'Background Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		for _, v in Reference do
			v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			v.Frame.BackgroundTransparency = 1 - opacity
		end
	end,
	Darker = true
    })
end)
