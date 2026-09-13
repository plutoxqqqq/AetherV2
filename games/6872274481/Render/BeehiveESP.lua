run(function()
    local HiveESP
    local Color
    local Transparency
    local Scale

    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local Reference, Strings = {}, {}
    local Updates = {}

    local function Added(ent)
	local Name = playersService:GetNameFromUserIdAsync(ent:GetAttribute('PlacedByUserId')) or 'Unknown'

	Strings[ent] = `{Name}'s beehive | %s Bee%s`
	local nametag = Instance.new('TextLabel')
	nametag.TextSize = 14 * Scale.Value
	nametag.Font = Enum.Font.Arial
	local format = string.format(Strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
	local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
	nametag.Name = Name
	nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
	nametag.AnchorPoint = Vector2.new(0.5, 1)
	nametag.BackgroundColor3 = Color3.new()
	nametag.BackgroundTransparency = 0.5
	nametag.BorderSizePixel = 0
	nametag.Visible = false
	nametag.Text = format
	nametag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	nametag.RichText = true
	nametag.Parent = Folder
	Reference[ent] = nametag

	HiveESP:Clean(ent:GetAttributeChangedSignal('Level'):Connect(function()
		Updates[ent] = true
	end))
	Updates[ent] = true
    end
    local function Updated(ent)
	if Reference[ent] then
		Reference[ent].TextSize = 14 * Scale.Value
		Reference[ent].TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		Reference[ent].BackgroundTransparency = Transparency.Value
	end
    end
    local function Removing(ent)
	if Reference[ent] then
		Reference[ent]:Destroy()
		Reference[ent] = nil
	end
    end

    HiveESP = vape.Categories.Render:CreateModule({
	Name = 'BeehiveESP',
	Function = function(call)
		if call then
			for _, v in collectionService:GetTagged('beehive') do
				Added(v)
			end
			HiveESP:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(Added))
			HiveESP:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(Removing))
			HiveESP:Clean(runService.PreRender:Connect(function()
				for ent, nametag in Reference do
					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
					nametag.Visible = headVis
					if not headVis then
						continue
					end

					if Updates[ent] then
						nametag.Text = string.format(Strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						Updates[ent] = nil
					end

					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
				end
			end))
		else
			for i in Reference do
				Removing(i)
			end
		end
	end,
	Tooltip = 'Renders hives locations and info'
    })

    Color = HiveESP:CreateColorSlider({
	Name = 'Text Color',
	Function = function(hue, sat, val)
		if HiveESP.Enabled then
			for ent in Reference do
				Updated(ent)
			end
		end
	end
    })
    Transparency = HiveESP:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if HiveESP.Enabled then
			for ent in Reference do
				Updated(ent)
			end
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 100
    })
    Scale = HiveESP:CreateSlider({
	Name = 'Scale',
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10,
	Function = function()
		if HiveESP.Enabled then
			for ent in Reference do
				Updated(ent)
			end
		end
	end
    })
end)
