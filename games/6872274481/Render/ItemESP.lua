run(function()
    local ItemESP
    local Distance
    local Transparency
    local Scale
    local WhitelistOnly
    local Whitelist = {ListEnabled = {}, Object = nil}

    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local Reference, Strings, Sizes = {}, {}, {}

    local function Added(ent)
	local Name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
	if WhitelistOnly.Enabled and not table.find(Whitelist.ListEnabled, Name:lower()) then
		return
	end

	Strings[ent] = Name .. '%s'
	if Distance.Enabled then
		Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '.. Strings[ent]
	end

	local nametag = Instance.new('TextLabel')
	nametag.TextSize = 14 * Scale.Value
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
	nametag.Text = Distance.Enabled and string.format(Strings[ent], 0, suffix) or string.format(Strings[ent], suffix)
	nametag.TextColor3 = Color3.new(1, 1, 1)
	nametag.RichText = true
	nametag.Parent = Folder
	Reference[ent] = nametag
    end
    local function Updated(ent)
	if Reference[ent] then
		Reference[ent].TextSize = 14 * Scale.Value
		Reference[ent].BackgroundTransparency = Transparency.Value
	end
    end
    local function Removing(ent)
	if Reference[ent] then
		Reference[ent]:Destroy()
		Reference[ent] = nil
	end
    end

    ItemESP = vape.Categories.Render:CreateModule({
	Name = 'ItemESP',
	Function = function(call)
		if call then
			ItemESP:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(Added))
			ItemESP:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(Removing))
			ItemESP:Clean(runService.PreRender:Connect(function()
				for ent, nametag in Reference do
					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
					nametag.Visible = headVis
					if not headVis then
						continue
					end

					local amount = ent:GetAttribute('Amount') or 1
					local mag = Distance.Enabled and entitylib.isAlive
						and math.floor((entitylib.character.RootPart.Position - ent.Position).Magnitude) or nil
					local cache = tostring(mag or '') .. ':' .. tostring(amount)
					if Sizes[ent] ~= cache then
						local suffix = amount >= 2 and ' x' .. tostring(amount) or ''
						nametag.Text = Distance.Enabled and string.format(Strings[ent], mag or 0, suffix)
							or string.format(Strings[ent], suffix)
						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						Sizes[ent] = cache
					end
					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
				end
			end))

			for _, v in collectionService:GetTagged('ItemDrop') do
				Added(v)
			end
		else
			for i in Reference do
				Removing(i)
			end
		end
	end,
	Tooltip = 'Renders tags dropped items'
    })
    Distance = ItemESP:CreateToggle({
	Name = 'Distance',
	Tooltip = 'Shows the distance of the item',
	Function = function(callback)
		if ItemESP.Enabled then
			for ent in Reference do
				local Name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
				Strings[ent] = callback and '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '.. Strings[ent] or Name.. '%s'
			end
		end
	end
    })
    ItemESP:CreateToggle({
	Name = 'Group items',
	Tooltip = 'Group items into easier to read tags'
    })
    Transparency = ItemESP:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if ItemESP.Enabled then
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
    Scale = ItemESP:CreateSlider({
	Name = 'Scale',
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10,
	Function = function()
		if ItemESP.Enabled then
			for ent in Reference do
				Updated(ent)
			end
		end
	end
    })
    WhitelistOnly = ItemESP:CreateToggle({
	Name = 'Whitelist Only',
	Tooltip = 'Only renders whitelisted items',
	Function = function(call)
		if Whitelist.Object then
			Whitelist.Object.Visible = call

			if ItemESP.Enabled then
				ItemESP:Toggle()
				ItemESP:Toggle()
			end
		end
	end
    })
    Whitelist = ItemESP:CreateTextList({
	Name = 'Allowed items',
	Visible = false,
	Darker = true,
	Function = function()
		if ItemESP.Enabled then
			ItemESP:Toggle()
			ItemESP:Toggle()
		end
	end
    })
end)
