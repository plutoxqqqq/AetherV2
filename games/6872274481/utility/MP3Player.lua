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

run(function()
    local CustomTags
    local Color
    local TAG
    local old, old2
    local tagGuiConn
    local tagConnections = {}

    local function Color3ToHex(r, g, b)
	return string.lower(string.format('#%02X%02X%02X', r, g, b))
    end

    local function CompleteTagEffect()
	if not lplr:FindFirstChild('Tags') then
		return
	end
	local tagObj = lplr.Tags:FindFirstChild('0')
	if not tagObj then
		return
	end

	if not old then
		old = tagObj.Value
		old2 = tagObj:GetAttribute('Text')
	end

	local color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	local R = math.floor(color.R * 255)
	local G = math.floor(color.G * 255)
	local B = math.floor(color.B * 255)

	tagObj.Value = string.format("<font color='rgb(%d,%d,%d)'>[%s]</font>", R, G, B, TAG.Value)
	tagObj:SetAttribute('Text', TAG.Value)
	lplr:SetAttribute('ClanTag', TAG.Value)

	for _, connection in tagConnections do connection:Disconnect() end
	table.clear(tagConnections)
	if tagGuiConn then
		tagGuiConn:Disconnect()
		tagGuiConn = nil
	end

	local nameToFind = (lplr.DisplayName == '' or lplr.DisplayName == lplr.Name) and lplr.Name or lplr.DisplayName
	local replacement = string.format('<font transparency="0.3" color="%s">[%s]</font> %s', Color3ToHex(R, G, B), TAG.Value, nameToFind)
	local watched = setmetatable({}, {__mode = 'k'})
	local function watchLabel(label)
		if watched[label] or not label:IsA('TextLabel') then return end
		watched[label] = true
		local applying = false
		local function apply()
			if applying or not label.Parent then return end
			if label.Text:lower():find(nameToFind:lower(), 1, true) and label.Text ~= replacement then
				applying = true
				label.Text = replacement
				applying = false
			end
		end
		apply()
		table.insert(tagConnections, label:GetPropertyChangedSignal('Text'):Connect(apply))
	end
	local function watchGui(child)
		if child.Name ~= 'TabListScreenGui' or not child:IsA('ScreenGui') then
			return
		end
		for _, label in child:GetDescendants() do watchLabel(label) end
		table.insert(tagConnections, child.DescendantAdded:Connect(watchLabel))
	end
	tagGuiConn = lplr.PlayerGui.ChildAdded:Connect(watchGui)
	local existing = lplr.PlayerGui:FindFirstChild('TabListScreenGui')
	if existing then watchGui(existing) end
    end

    local function RemoveTagEffect()
	for _, connection in tagConnections do connection:Disconnect() end
	table.clear(tagConnections)

	if tagGuiConn then
		tagGuiConn:Disconnect()
		tagGuiConn = nil
	end

	if lplr:FindFirstChild('Tags') then
		local tagObj = lplr.Tags:FindFirstChild('0')
		if tagObj then
			if old then
				tagObj.Value = old
			end
			if old2 then
				tagObj:SetAttribute('Text', old2)
			end
		end
	end

	if lplr:GetAttribute('ClanTag') then
		lplr:SetAttribute('ClanTag', old)
	end

	old = nil
	old2 = nil
    end

    CustomTags = vape.Categories.Render:CreateModule({
	Name = 'CustomTags',
	Function = function(callback)
		if callback then
			CompleteTagEffect()
		else
			RemoveTagEffect()
		end
	end,
	Tooltip = 'Client-Sided visual custom clan tag on-chat'
    })

    Color = CustomTags:CreateColorSlider({
	Name = 'Color',
	Function = function()
		if CustomTags.Enabled then
			CompleteTagEffect()
		end
	end,
    })
    TAG = CustomTags:CreateTextBox({
	Name = 'Tag',
	Default = 'gg',
	Function = function()
		if CustomTags.Enabled then
			CompleteTagEffect()
		end
	end,
    })
end)

run(function()
    local GeneratorESP
    local Transparency
    local Scale
    local Whitelist
    local Whitelisted = { ListEnabled = {}, Object = nil }

    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local Reference, Strings, Cooldown = {}, {}, {}
    local Updates = {}

    local function getNumber(text)
	if not text or text == '' then
		return 0
	end
	local seconds = text:match('%[(%d+)%]')
	if seconds then
		return tonumber(seconds) or 0
	end
	local justNumber = text:match('(%d+)')
	if justNumber then
		return tonumber(justNumber) or 0
	end
	return 0
    end

    local function Added(ent)
	local App = ent.RoactTree.TeamOreGeneratorApp
	local Name = (App:FindFirstChild('GlobalOreGenerator') or App:FindFirstChild('TeamGenMain'))
	local Countdown = (Name or App):FindFirstChild('Countdown', true)
	if Name then
		Name = Name:FindFirstChild('Title')
	end

	local TierType = ''
	if Name then
		Name = Name.Text
		TierType = 'iron'
	else
		local Ore = ent:GetAttribute('Id')
		Ore = Ore:sub(0, #Ore - 2)
		TierType = (Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore)):lower()
		Name = Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore) .. ' Generator'
	end

	if Whitelist.Enabled and not table.find(Whitelisted.ListEnabled, TierType) then
		return
	end

	Strings[ent] = `{Name} %s%s`
	local nametag = Instance.new('TextLabel')
	nametag.TextSize = 14 * Scale.Value
	nametag.Font = Enum.Font.Arial
	local format = string.format(Strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, '')
	local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
	nametag.Name = Name
	nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
	nametag.AnchorPoint = Vector2.new(0.5, 1)
	nametag.BackgroundColor3 = Color3.new()
	nametag.BackgroundTransparency = 0.5
	nametag.BorderSizePixel = 0
	nametag.Visible = false
	nametag.Text = format
	nametag.TextColor3 = Color3.new(1, 1, 1)
	nametag.RichText = true
	nametag.Parent = Folder
	Reference[ent] = nametag

	local Update = function()
		Updates[ent] = true
	end
	GeneratorESP:Clean(ent:GetAttributeChangedSignal('GeneratorLevel'):Connect(Update))
	GeneratorESP:Clean(ent:GetAttributeChangedSignal('Cooldown'):Connect(Update))
	if Countdown then
		Cooldown[ent] = Countdown
		GeneratorESP:Clean(Countdown:GetPropertyChangedSignal('Text'):Connect(Update))
	end
	Update()
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

    GeneratorESP = vape.Categories.Render:CreateModule({
	Name = 'GeneratorESP',
	Function = function(call)
		if call then
			for _, v in collectionService:GetTagged('Generator') do
				Added(v)
			end
			GeneratorESP:Clean(collectionService:GetInstanceAddedSignal('Generator'):Connect(Added))
			GeneratorESP:Clean(collectionService:GetInstanceRemovedSignal('Generator'):Connect(Removing))
			GeneratorESP:Clean(runService.PreRender:Connect(function()
				for ent, nametag in Reference do
					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
					nametag.Visible = headVis
					if not headVis then
						continue
					end

					if Updates[ent] then
						nametag.Text = string.format(Strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, Cooldown[ent] and ` | {getNumber(Cooldown[ent].Text)}s` or '')
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
	Tooltip = 'Renders generator locations and info'
    })

    Transparency = GeneratorESP:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if GeneratorESP.Enabled then
			for ent in Reference do
				Updated(ent)
			end
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 100,
    })
    Scale = GeneratorESP:CreateSlider({
	Name = 'Scale',
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10,
	Function = function()
		if GeneratorESP.Enabled then
			for ent in Reference do
				Updated(ent)
			end
		end
	end,
    })
    Whitelist = GeneratorESP:CreateToggle({
	Name = 'Use whitelist',
	Default = true,
	Function = function(call)
		if Whitelisted.Object then
			Whitelisted.Object.Visible = call
		end
	end,
    })
    Whitelisted = GeneratorESP:CreateTextList({
	Name = 'Generators',
	Darker = true,
	Default = {'diamond', 'iron'},
    })
end)

run(function()
    local Health

    Health = vape.Categories.Render:CreateModule({
	Name = 'Health',
	Function = function(callback)
		if callback then
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromOffset(100, 20)
			label.Position = UDim2.new(0.5, 6, 0.5, 30)
			label.BackgroundTransparency = 1
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health')) .. ' ❤️' or ''
			label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
			label.TextSize = 18
			label.Font = Enum.Font.Arial
			label.Parent = vape.gui
			Health:Clean(label)
			Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health')) .. ' ❤️' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
			end))
		end
	end,
	Tooltip = 'Displays your health in the center of your screen'
    })
end)

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

run(function()
    local KitDisplay

    local function getKitMeta(player)
	local kit = player:GetAttribute('PlayingAsKits') or player:GetAttribute('PlayingAsKit') or 'none'
	return bedwars.BedwarsKitMeta[kit] or bedwars.BedwarsKitMeta.none
    end

    local function getPlayerFromDraft(render, name)
	local id = render and render:match('id=(%d+)')
	if id then
		local player = playersService:GetPlayerByUserId(tonumber(id))
		if player then
			return player
		end
	end

	for _, v in playersService:GetPlayers() do
		if render and render:find('id=' .. v.UserId, 1, true) then
			return v
		end

		if name and (v.Name == name or v.DisplayName == name or v:GetAttribute('DisguiseDisplayName') == name) then
			return v
		end

		local displayName
		pcall(function()
			displayName = bedwars.StreamerModeController:getDisplayName(v)
		end)
		if name and displayName == name then
			return v
		end
	end
	return nil
    end

    local waitForChild = function(start, ...)
	local parent = start
	for _, v in {...} do
		parent = parent and parent:WaitForChild(v, 5)
		if not parent then
			break
		end
	end
	return parent
    end

    local function getPlayerName(card)
	local textbar = card and card:FindFirstChild('TextBackgroundBar')
	local label = textbar and textbar:FindFirstChild('PlayerName') or card and card:FindFirstChild('PlayerName', true)
	return label and label.Text or ''
    end

    local function getDraftCard(container)
	if not container then
		return
	end
	return container.Name == 'MatchDraftPlayerCard' and container or container:FindFirstChild('MatchDraftPlayerCard', true)
    end

    local function callback5v5(v, plr)
	if not v then
		return
	end
	local render = v:FindFirstChild('PlayerRender', true)
	local player = plr or getPlayerFromDraft(render and render.Image or '', getPlayerName(v))

	if player then
		local kitImage = getKitMeta(player)
		local roact = v:FindFirstChild('KitImage')

		if not roact then
			roact = Instance.new('ImageLabel', v)
			roact.BackgroundTransparency = 1
			roact.AnchorPoint = Vector2.new(1, 0.5)
			roact.Position = UDim2.fromScale(1.05, 0.5)
			roact.Name = 'KitImage'
			roact.Size = UDim2.fromScale(1.5, 1.5)
			roact.ZIndex = 1
			roact.ImageTransparency = 0.4
			roact.SliceCenter = Rect.new(0, 0, 0, 0)
			roact.SliceScale = 1
			roact.ScaleType = Enum.ScaleType.Crop

			KitDisplay:Clean(roact)

			local ratio = Instance.new('UIAspectRatioConstraint', roact)
			ratio.Name = '1'
			ratio.AspectRatio = 1
			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
			ratio.DominantAxis = Enum.DominantAxis.Width
		end

		roact.Image = kitImage.renderImage
		roact.Position = UDim2.fromScale(1.05, 0)
		tweenService:Create(roact, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.fromScale(1.05, 0.4)}):Play()

		local function update()
			kitImage = getKitMeta(player)
			roact.Image = kitImage.renderImage
		end

		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(update))
		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKit'):Connect(update))
	end
    end

    local function callbacksquad(v)
	if not v then
		return
	end
	local render = v:FindFirstChild('PlayerRender', true)
	local player = render and getPlayerFromDraft(render.Image, '') or nil

	if player then
		local kitImage = getKitMeta(player)
		local Roact = v:FindFirstChild('Kitcvrender')

		if not Roact then
			local base = v:FindFirstChild('3') or v:WaitForChild('3', 5)
			if not base then
				return
			end
			Roact = base:Clone()
			Roact.Parent = v
			Roact.Name = 'Kitcvrender'
			KitDisplay:Clean(Roact)
		end

		Roact.Image = kitImage.renderImage

		KitDisplay:Clean(render:GetPropertyChangedSignal('Image'):Connect(function()
			local newplayer = getPlayerFromDraft(render.Image, '')
			if newplayer then
				player = newplayer
				kitImage = getKitMeta(player)
				Roact.Image = kitImage.renderImage
			end
		end))

		local function update()
			kitImage = getKitMeta(player)
			Roact.Image = kitImage.renderImage
		end

		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(update))
		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKit'):Connect(update))
	end
    end

    local function setup5v5(DraftApp)
	local Background = DraftApp:FindFirstChild('DraftAppBackground')
	local BodyContainer = Background and Background:FindFirstChild('1') and Background['1']:FindFirstChild('BodyContainer')
	local hooked = false

	for i = 1, 2 do
		local dtc = BodyContainer and BodyContainer:FindFirstChild('Team' .. i .. 'Column')
		if dtc then
			hooked = true
			KitDisplay:Clean(dtc.ChildAdded:Connect(function(child)
				task.delay(0.2, function()
					if KitDisplay.Enabled then
						callback5v5(getDraftCard(child))
					end
				end)
			end))

			for _, v in dtc:GetChildren() do
				if v:IsA('Frame') then
					callback5v5(getDraftCard(v))
				end
			end
		end
	end

	if not hooked then
		for _, label in DraftApp:GetDescendants() do
			if label:IsA('TextLabel') and label.Name == 'PlayerName' then
				local container = label.Parent
				for _ = 1, 3 do
					container = container and container.Parent
				end
				if container then
					callback5v5(getDraftCard(container))
				end
			end
		end

		KitDisplay:Clean(DraftApp.DescendantAdded:Connect(function(child)
			if child:IsA('TextLabel') and child.Name == 'PlayerName' then
				task.delay(0.2, function()
					local container = child.Parent
					for _ = 1, 3 do
						container = container and container.Parent
					end
					if KitDisplay.Enabled and container then
						callback5v5(getDraftCard(container))
					end
				end)
			end
		end))
	end

	return hooked
    end

    local function setupSquad(DraftApp)
	local Background = DraftApp:FindFirstChild('DraftAppBackground')
	local BodyContainer = Background and Background:FindFirstChild('1') and Background['1']:FindFirstChild('BodyContainer')
	local TeamsColumn = BodyContainer and BodyContainer:FindFirstChild('TeamsColumn')
	if not TeamsColumn then
		return
	end

	for _, v: Instance in TeamsColumn:GetChildren() do
		if v:IsA('Frame') then
			local plrframe = waitForChild(v, '1', '2', '4')
			if plrframe then
				for _, plr in plrframe:GetChildren() do
					callbacksquad(plr)
				end

				KitDisplay:Clean(plrframe.ChildAdded:Connect(function(plr)
					KitDisplay:Toggle()
					KitDisplay:Toggle()
				end))
			end
		end
	end
    end

    KitDisplay = kits:CreateModule({
	Name = 'KitDisplay',
	Category = 'Visual',
	Function = function(call)
		if call then
			local DraftApp = lplr.PlayerGui:WaitForChild('MatchDraftApp', 9e9)
			setup5v5(DraftApp)
			setupSquad(DraftApp)
		end
	end,
	Tooltip = 'Allows you to see the other opponent kits'
    })
end)

run(function()
    local KitESP
    local Background
    local Color = {}
    local Reference = {}
    local kitGeneration = 0
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local ESPKits = {
	alchemist = {'alchemist_ingedients', 'wild_flower'},
	beekeeper = {'bee', 'bee'},
	bigman = {'treeOrb', 'natures_essence_1'},
	ghost_catcher = {'ghost', 'ghost_orb'},
	metal_detector = {'hidden-metal', 'iron'},
	sheep_herder = {'SheepModel', 'purple_hay_bale'},
	sorcerer = {'alchemy_crystal', 'wild_flower'},
	star_collector = {'stars', 'crit_star'},
    }

    local function Added(v, icon)
	local billboard = Instance.new('BillboardGui')
	billboard.Parent = Folder
	billboard.Name = icon
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.Size = UDim2.fromOffset(36, 36)
	billboard.AlwaysOnTop = true
	billboard.ClipsDescendants = false
	billboard.Adornee = v
	local blur = addBlur(billboard)
	blur.Visible = Background.Enabled
	local image = Instance.new('ImageLabel')
	image.Size = UDim2.fromOffset(36, 36)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
	image.BorderSizePixel = 0
	image.Image = bedwars.getIcon({ itemType = icon }, true)
	image.Parent = billboard
	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0, 4)
	uicorner.Parent = image
	Reference[v] = billboard
    end

    local function addKit(kitName, tag, icon)
	KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
		if store.equippedKit == kitName and v.PrimaryPart then Added(v.PrimaryPart, icon) end
	end))
	KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
		if v.PrimaryPart and Reference[v.PrimaryPart] then
			Reference[v.PrimaryPart]:Destroy()
			Reference[v.PrimaryPart] = nil
		end
	end))
    end
	local function refreshKit()
		Folder:ClearAllChildren()
		table.clear(Reference)
		local kit = ESPKits[store.equippedKit]
		if not kit then return end
		for _, object in collectionService:GetTagged(kit[1]) do if object.PrimaryPart then Added(object.PrimaryPart, kit[2]) end end
	end

    KitESP = kits:CreateModule({
	Name = 'KitESP',
	Category = 'Visual',
	Function = function(callback)
		kitGeneration += 1
		if callback then
			local generation = kitGeneration
			for kitName, kit in ESPKits do addKit(kitName, kit[1], kit[2]) end
			local activeKit = store.equippedKit
			refreshKit()
			-- Kit changes are store-driven but this store wrapper has no change signal. Polling four
			-- times a second is indistinguishable to the user and avoids a comparison every frame.
			task.spawn(function()
				while KitESP.Enabled and kitGeneration == generation do
					task.wait(0.25)
					if kitGeneration ~= generation then break end
					if store.equippedKit ~= activeKit then activeKit = store.equippedKit; refreshKit() end
				end
			end)
		else
			Folder:ClearAllChildren()
			table.clear(Reference)
		end
	end,
	Tooltip = 'ESP for certain kit related objects'
    })
    Background = KitESP:CreateToggle({
	Name = 'Background',
	Function = function(callback)
		if Color.Object then
			Color.Object.Visible = callback
		end
		for _, v in Reference do
			v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
			v.Blur.Visible = callback
		end
	end,
	Default = true,
    })
    Color = KitESP:CreateColorSlider({
	Name = 'Background Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		for _, v in Reference do
			v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			v.ImageLabel.BackgroundTransparency = 1 - opacity
		end
	end,
	Darker = true,
    })
end)

run(function()
    local NameTags
    local Targets
    local Color
    local Background
    local DisplayName
    local Health
    local Distance
    local Equipment
    local Rank
    local Enchant
    local DrawingToggle
    local Scale
    local FontOption
    local Teammates
    local DistanceCheck
    local DistanceLimit
    local Strings, Sizes, Reference = {}, {}, {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local methodused

    local Added = {
	Normal = function(ent)
		if not Targets.Players.Enabled and ent.Player then
			return
		end
		if not Targets.NPCs.Enabled and ent.NPC then
			return
		end
		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
			return
		end

		local nametag = Instance.new('TextLabel')
		Strings[ent] = ent.Player
				and whitelist:tag(ent.Player, true, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
			or ent.Character.Name

		if Health.Enabled then
			local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			Strings[ent] = Strings[ent]
				.. ' <font color="rgb('
				.. tostring(math.floor(healthColor.R * 255))
				.. ','
				.. tostring(math.floor(healthColor.G * 255))
				.. ','
				.. tostring(math.floor(healthColor.B * 255))
				.. ')">'
				.. math.round(ent.Health)
				.. '</font>'
		end

		if Distance.Enabled then
			Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '
				.. Strings[ent]
		end

		if Equipment.Enabled then
			for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
				local Icon = Instance.new('ImageLabel')
				Icon.Name = v
				Icon.Size = UDim2.fromOffset(30, 30)
				Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
				Icon.BackgroundTransparency = 1
				Icon.Image = ''
				Icon.Parent = nametag
			end
		end

		nametag.TextSize = 14 * Scale.Value
		nametag.FontFace = FontOption.Value
		local size =
			getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
		nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Background.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.Text = Strings[ent]
		nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.RichText = true
		nametag.Parent = Folder
		task.spawn(function()
			if Rank.Enabled and ent.Player then
				local Icon = Instance.new('ImageLabel')
				Icon.Name = 'RankIcon'
				Icon.Size = UDim2.fromOffset(30, 30)
				Icon.Position = UDim2.fromOffset(size.X + 10, -4)
				Icon.BackgroundTransparency = 1
				Icon.Image = store.rank[ent.Player]:async() and bedwars.RankMeta[store.rank[ent.Player]:async()].image
					or ''
				Icon.Parent = nametag
			end
		end)
		task.spawn(function()
			if Enchant.Enabled and ent.Player then
				local Icon = Instance.new('ImageLabel')
				Icon.Name = 'EnchantIcon'
				Icon.Size = UDim2.fromOffset(30, 30)
				Icon.Position = UDim2.fromOffset(-30, -4)
				Icon.BackgroundTransparency = 1
				Icon.Image = store.enchants[ent.Player]:async() or ''
				Icon.Parent = nametag
			end
		end)
		Reference[ent] = nametag
	end,
	Drawing = function(ent)
		if not Targets.Players.Enabled and ent.Player then
			return
		end
		if not Targets.NPCs.Enabled and ent.NPC then
			return
		end
		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
			return
		end

		local nametag = {}
		nametag.BG = Drawing.new('Square')
		nametag.BG.Filled = true
		nametag.BG.Transparency = 1 - Background.Value
		nametag.BG.Color = Color3.new()
		nametag.BG.ZIndex = 1
		nametag.Text = Drawing.new('Text')
		nametag.Text.Size = 15 * Scale.Value
		nametag.Text.Font = 0
		nametag.Text.ZIndex = 2
		Strings[ent] = ent.Player
				and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
			or ent.Character.Name

		if Health.Enabled then
			Strings[ent] = Strings[ent] .. ' ' .. math.round(ent.Health)
		end

		if Distance.Enabled then
			Strings[ent] = '[%s] ' .. Strings[ent]
		end

		nametag.Text.Text = Strings[ent]
		nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
		Reference[ent] = nametag
	end,
    }

    local Removed = {
	Normal = function(ent)
		local v = Reference[ent]
		if v then
			Reference[ent] = nil
			Strings[ent] = nil
			Sizes[ent] = nil
			v:Destroy()
		end
	end,
	Drawing = function(ent)
		local v = Reference[ent]
		if v then
			Reference[ent] = nil
			Strings[ent] = nil
			Sizes[ent] = nil
			for _, obj in v do
				pcall(function()
					obj.Visible = false
					obj:Remove()
				end)
			end
		end
	end,
    }

    local Updated = {
	Normal = function(ent)
		local nametag = Reference[ent]
		if nametag then
			Sizes[ent] = nil
			Strings[ent] = ent.Player
					and whitelist:tag(ent.Player, true, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
				or ent.Character.Name

			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]
					.. ' <font color="rgb('
					.. tostring(math.floor(healthColor.R * 255))
					.. ','
					.. tostring(math.floor(healthColor.G * 255))
					.. ','
					.. tostring(math.floor(healthColor.B * 255))
					.. ')">'
					.. math.round(ent.Health)
					.. '</font>'
			end

			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '
					.. Strings[ent]
			end

			if Equipment.Enabled and store.inventories[ent.Player] then
				local kit = ent.Player:GetAttribute('PlayingAsKit')
				local inventory = store.inventories[ent.Player]
				nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
				nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
				nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
				nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
				nametag.Kit.Image = kit and bedwars.BedwarsKitMeta[kit].renderImage or ''
			end

			if Enchant.Enabled and nametag:FindFirstChild('EnchantIcon') then
				nametag.EnchantIcon.Image = store.enchants[ent.Player]:async() or ''
			end

			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.Text = Strings[ent]
		end
	end,
	Drawing = function(ent)
		local nametag = Reference[ent]
		if nametag then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Sizes[ent] = nil
			Strings[ent] = ent.Player
					and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
				or ent.Character.Name

			if Health.Enabled then
				Strings[ent] = Strings[ent] .. ' ' .. math.round(ent.Health)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. Strings[ent]
				nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
			else
				nametag.Text.Text = Strings[ent]
			end

			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		end
	end,
    }

    local ColorFunc = {
	Normal = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.TextColor3 = entitylib.getEntityColor(i) or color
		end
	end,
	Drawing = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.Text.Color = entitylib.getEntityColor(i) or color
		end
	end,
    }

    local Loop = {
	Normal = function()
		local alive = entitylib.isAlive
		local localPosition = alive and entitylib.character.RootPart.Position
		for ent, nametag in Reference do
			local distance
			if alive and (DistanceCheck.Enabled or Distance.Enabled) then
				distance = (localPosition - ent.RootPart.Position).Magnitude
			end

			if DistanceCheck.Enabled then
				distance = distance or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					nametag.Visible = false
					continue
				end
			end

			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
			nametag.Visible = headVis
			if not headVis then
				continue
			end

			if Distance.Enabled then
				local mag = alive and math.floor(distance) or 0
				if Sizes[ent] ~= mag then
					nametag.Text = string.format(Strings[ent], mag)
					local ize = getfontsize(
						removeTags(nametag.Text),
						nametag.TextSize,
						nametag.FontFace,
						Vector2.new(100000, 100000)
					)
					nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
					Sizes[ent] = mag
				end
			end
			nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
		end
	end,
	Drawing = function()
		local alive = entitylib.isAlive
		local localPosition = alive and entitylib.character.RootPart.Position
		for ent, nametag in Reference do
			local distance
			if alive and (DistanceCheck.Enabled or Distance.Enabled) then
				distance = (localPosition - ent.RootPart.Position).Magnitude
			end

			if DistanceCheck.Enabled then
				distance = distance or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					nametag.Text.Visible = false
					nametag.BG.Visible = false
					continue
				end
			end

			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
			nametag.Text.Visible = headVis
			nametag.BG.Visible = headVis
			if not headVis then
				continue
			end

			if Distance.Enabled then
				local mag = alive and math.floor(distance) or 0
				if Sizes[ent] ~= mag then
					nametag.Text.Text = string.format(Strings[ent], mag)
					nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
					Sizes[ent] = mag
				end
			end
			nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
			nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
		end
	end,
    }

    NameTags = vape.Categories.Render:CreateModule({
	Name = 'NameTags',
	Function = function(callback)
		if callback then
			methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
			if Removed[methodused] then
				NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
			end
			if Added[methodused] then
				for _, v in entitylib.List do
					if Reference[v] then
						Removed[methodused](v)
					end
					Added[methodused](v)
				end
				NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed[methodused](ent)
					end
					Added[methodused](ent)
				end))
			end
			if Updated[methodused] then
				NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
				for _, v in entitylib.List do
					Updated[methodused](v)
				end
			end
			if ColorFunc[methodused] then
				NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
				end))
			end
			if Loop[methodused] then
				NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
			end
		else
			if Removed[methodused] then
				for i in Reference do
					Removed[methodused](i)
				end
			end
		end
	end,
	Tooltip = 'Renders nametags on entities through walls'
    })
    Targets = NameTags:CreateTargets({
	Players = true,
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    FontOption = NameTags:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    Color = NameTags:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if NameTags.Enabled and ColorFunc[methodused] then
			ColorFunc[methodused](hue, sat, val)
		end
	end,
    })
    Scale = NameTags:CreateSlider({
	Name = 'Scale',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10,
    })
    Background = NameTags:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 10,
    })
    Health = NameTags:CreateToggle({
	Name = 'Health',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    Distance = NameTags:CreateToggle({
	Name = 'Distance',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    Rank = NameTags:CreateToggle({
	Name = 'Rank',
	Tooltip = "Displays player's rank",
    })
    Enchant = NameTags:CreateToggle({
	Name = 'Enchant',
	Tooltip = "Displays player's enchant",
	Default = true,
    })
    Equipment = NameTags:CreateToggle({
	Name = 'Equipment',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    DisplayName = NameTags:CreateToggle({
	Name = 'Use Displayname',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = true,
    })
    Teammates = NameTags:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = true,
    })
    DrawingToggle = NameTags:CreateToggle({
	Name = 'Drawing',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
    })
    DistanceCheck = NameTags:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end,
    })
    DistanceLimit = NameTags:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false,
    })
end)

run(function()
	local ProjectileLanding
	local MarkerColor
	local launchHook
	local aimingInput = false
	local lastLaunch
	local states, watchers = {}, {}
	local aimVisual
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true

	local function newVisual(name)
		local marker = Instance.new('Part')
		marker.Name = name
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(1.85, 1.85, 1.85)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Material = Enum.Material.Neon
		marker.Transparency = 1
		marker.Parent = gameCamera
		return {Marker = marker}
	end

	local function destroyVisual(visual)
		if not visual then return end
		if visual.Highlight then visual.Highlight:Destroy() end
		if visual.Marker then visual.Marker:Destroy() end
		visual.Highlight = nil
		visual.Marker = nil
	end

	local function entityForInstance(instance)
		local model = instance and instance:FindFirstAncestorOfClass('Model')
		if not model then return end
		if entitylib.getEntityFromCharacter then
			local ent = entitylib.getEntityFromCharacter(model)
			if ent then return ent end
		end
		for _, ent in entitylib.List do
			if ent.Character == model then return ent end
		end
	end

	local function updateVisual(visual, result)
		if not visual or not visual.Marker then return end
		local color = Color3.fromHSV(MarkerColor.Hue, MarkerColor.Sat, MarkerColor.Value)
		visual.Marker.Color = color
		if not result or typeof(result.Position) ~= 'Vector3' then
			visual.Marker.Transparency = 1
			if visual.Highlight then visual.Highlight:Destroy(); visual.Highlight = nil end
			return
		end
		visual.Marker.CFrame = CFrame.new(result.Position + Vector3.new(0, 0.55, 0))
		visual.Marker.Transparency = math.clamp(MarkerColor.Opacity or 0, 0, 1)
		local ent = entityForInstance(result.Instance)
		local model = ent and ent.Character
		if model ~= visual.HighlightModel then
			if visual.Highlight then visual.Highlight:Destroy() end
			visual.Highlight, visual.HighlightModel = nil, model
			if model then
				local highlight = Instance.new('Highlight')
				highlight.Name = 'ProjectileLandingHit'
				highlight.Adornee = model
				highlight.FillTransparency = 0.55
				highlight.OutlineTransparency = 0.05
				highlight.Parent = gameCamera
				visual.Highlight = highlight
			end
		end
		if visual.Highlight then
			visual.Highlight.FillColor = color
			visual.Highlight.OutlineColor = color
		end
	end

	local function closestPoint(point, a, b)
		local segment = b - a
		local length = segment:Dot(segment)
		if length <= 1e-6 then return a end
		return a + segment * math.clamp((point - a):Dot(segment) / length, 0, 1)
	end

	local function movingEntityCollision(a, b, startTime, endTime)
		local bestPosition, bestInstance, bestDistance
		local sampleTime = (startTime + endTime) * 0.5
		for _, ent in entitylib.List do
			local root = ent.RootPart
			if root and root.Parent and (not ent.Health or ent.Health > 0) then
				local velocity = root.AssemblyLinearVelocity
				local center = root.Position + velocity * sampleTime
				local point = closestPoint(center, a, b)
				local delta = point - center
				local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if horizontal <= 2.1 and math.abs(delta.Y) <= 3.5 then
					local distance = (point - a).Magnitude
					if not bestDistance or distance < bestDistance then
						bestPosition, bestInstance, bestDistance = point, root, distance
					end
				end
			end
		end
		return bestPosition, bestInstance
	end

	local function trace(origin, velocity, gravity, lifetime, extraIgnore)
		if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or velocity.Magnitude <= 0.1 then return end
		local ignored = {lplr.Character, gameCamera}
		if extraIgnore then table.insert(ignored, extraIgnore) end
		for _, ent in entitylib.List do
			if ent.Character then table.insert(ignored, ent.Character) end
		end
		rayParams.FilterDescendantsInstances = ignored
		return prediction.TraceTrajectory(origin, velocity, projectileAcceleration(gravity), rayParams, lifetime, {
			Radius = 0.45,
			SegmentLength = 1,
			MaximumSteps = 600,
			CollisionTest = movingEntityCollision
		})
	end

	local function projectilePart(projectile)
		return projectile:IsA('BasePart') and projectile or projectile:IsA('Model') and projectile.PrimaryPart or nil
	end

	local function projectileMeta(projectile, part)
		return bedwars.ProjectileMeta[projectile.Name] or (part and bedwars.ProjectileMeta[part.Name]) or {}
	end

	local function clearWatcher(projectile)
		local watcher = watchers[projectile]
		if not watcher then return end
		watchers[projectile] = nil
		for _, connection in watcher do connection:Disconnect() end
	end

	local function removeProjectile(projectile)
		local state = states[projectile]
		if not state then return end
		states[projectile] = nil
		if state.Connection then state.Connection:Disconnect() end
		destroyVisual(state.Visual)
	end

	local function trackProjectile(projectile)
		if states[projectile] or projectile:GetAttribute('ProjectileShooter') ~= lplr.UserId then return end
		local part = projectilePart(projectile)
		if not part then return end
		clearWatcher(projectile)
		local meta = projectileMeta(projectile, part)
		local state = {
			Part = part,
			Born = tick(),
			Lifetime = math.clamp(tonumber(meta.lifetimeSec or meta.lifetime) or 7, 0.1, 10),
			Gravity = meta.gravitationalAcceleration or workspace.Gravity,
			Visual = newVisual('ProjectileLandingMarker')
		}
		states[projectile] = state
		state.Connection = projectile.AncestryChanged:Connect(function(_, parent)
			if not parent then removeProjectile(projectile) end
		end)
	end

	local function candidateProjectile(projectile)
		if not (projectile:IsA('BasePart') or projectile:IsA('Model')) then return false end
		if projectile:GetAttribute('ProjectileShooter') ~= nil or bedwars.ProjectileMeta[projectile.Name] then return true end
		local name = projectile.Name:lower()
		return name:find('projectile', 1, true) or name:find('arrow', 1, true)
			or name:find('snowball', 1, true) or name:find('fireball', 1, true)
			or name:find('telepearl', 1, true)
	end

	local function watchProjectile(projectile)
		if not candidateProjectile(projectile) then return end
		if projectile:GetAttribute('ProjectileShooter') ~= nil then
			trackProjectile(projectile)
			return
		end
		if states[projectile] or watchers[projectile] then return end
		local watcher = {}
		watcher.Attribute = projectile:GetAttributeChangedSignal('ProjectileShooter'):Connect(function()
			trackProjectile(projectile)
		end)
		watcher.Ancestry = projectile.AncestryChanged:Connect(function(_, parent)
			if not parent then clearWatcher(projectile) end
		end)
		watchers[projectile] = watcher
	end

	local function setAiming(input, value)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonR2 then
			aimingInput = value
		end
	end

	local function recordLaunch(nextLaunch, ...)
		local result = nextLaunch(...)
		if type(result) == 'table' and typeof(result.positionFrom) == 'Vector3'
			and typeof(result.initialVelocity) == 'Vector3' then
			lastLaunch = {
				Origin = result.positionFrom,
				Velocity = result.initialVelocity,
				Gravity = result.gravitationalAcceleration or workspace.Gravity,
				Lifetime = tonumber(result.lifetimeSec) or 7,
				Time = tick()
			}
		end
		return result
	end

	local function fallbackLaunch()
		if not entitylib.isAlive or not store.hand or not store.hand.tool then return end
		local itemMeta = bedwars.ItemMeta[store.hand.tool.Name]
		local source = itemMeta and itemMeta.projectileSource
		if not source then return end
		local ammo
		local inventory = store.inventory and store.inventory.inventory
		for _, item in inventory and inventory.items or {} do
			if table.find(source.ammoItemTypes or {}, item.itemType) then ammo = item.itemType; break end
		end
		local projectileType = ammo
		if type(source.projectileType) == 'function' then
			local ok, value = pcall(source.projectileType, ammo)
			if ok then projectileType = value end
		end
		local meta = bedwars.ProjectileMeta[projectileType] or {}
		local speed = (tonumber(meta.launchVelocity or source.launchVelocity) or 100) * (tonumber(source.velocityMultiplier) or 1)
		local origin = gameCamera.CFrame.Position
		pcall(function()
			local value = bedwars.ProjectileController:getLaunchPosition(gameCamera.CFrame)
			if typeof(value) == 'Vector3' then origin = value elseif typeof(value) == 'CFrame' then origin = value.Position end
		end)
		local mouseRay = lplr:GetMouse().UnitRay
		return origin, mouseRay.Direction.Unit * speed,
			(tonumber(meta.gravitationalAcceleration) or workspace.Gravity) * (tonumber(source.gravityMultiplier) or 1),
			tonumber(meta.lifetimeSec) or 7
	end

	local function update()
		for projectile, state in states do
			local part = state.Part
			local remaining = state.Lifetime - (tick() - state.Born)
			if remaining <= 0 or not projectile.Parent or not part.Parent then
				removeProjectile(projectile)
			else
				updateVisual(state.Visual, trace(part.Position, part.AssemblyLinearVelocity, state.Gravity, remaining, projectile))
			end
		end

		local result
		if aimingInput then
			if lastLaunch and tick() - lastLaunch.Time <= 0.25 then
				result = trace(lastLaunch.Origin, lastLaunch.Velocity, lastLaunch.Gravity, lastLaunch.Lifetime)
			else
				local origin, velocity, gravity, lifetime = fallbackLaunch()
				if origin then result = trace(origin, velocity, gravity, lifetime) end
			end
		end
		updateVisual(aimVisual, result)
	end

	local function clear()
		for projectile in states do removeProjectile(projectile) end
		for projectile in watchers do clearWatcher(projectile) end
		destroyVisual(aimVisual)
		aimVisual = nil
		lastLaunch = nil
		aimingInput = false
	end

	ProjectileLanding = vape.Categories.Render:CreateModule({
		Name = 'ProjectileLanding',
		Function = function(enabled)
			if not enabled then clear(); return end
			aimVisual = newVisual('ProjectileLandingAimMarker')
			if bedwars.ProjectileLaunchHook then
				launchHook = bedwars.ProjectileLaunchHook:Add('ProjectileLanding', 1, recordLaunch)
				ProjectileLanding:Clean(function()
					if launchHook then launchHook(); launchHook = nil end
				end)
			end
			ProjectileLanding:Clean(workspace.ChildAdded:Connect(watchProjectile))
			ProjectileLanding:Clean(inputService.InputBegan:Connect(function(input, processed)
				if not processed then setAiming(input, true) end
			end))
			ProjectileLanding:Clean(inputService.InputEnded:Connect(function(input) setAiming(input, false) end))
			for _, child in workspace:GetChildren() do watchProjectile(child) end
			local elapsed = 0
			ProjectileLanding:Clean(runService.Heartbeat:Connect(function(dt)
				elapsed += dt
				if elapsed < 0.05 then return end
				elapsed = 0
				update()
			end))
			ProjectileLanding:Clean(clear)
		end,
		Tooltip = 'Predicts held and local projectile landings with bounded deterministic trajectory simulation'
	})
	MarkerColor = ProjectileLanding:CreateColorSlider({Name = 'Marker Color', DefaultOpacity = 0})
end)
run(function()
    local BulletTracers
    local Material
    local Lifetime
    local Curve
    local Opacity
    local Thickness
    local Color
    local Fade

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude

    BulletTracers = vape.Categories.Render:CreateModule({
	Name = 'ProjectileTracers',
	Function = function(callback)
		if callback then
			BulletTracers:Clean(workspace.ChildAdded:Connect(function(projectile)
				task.delay(0, function()
					rayCheck.FilterDescendantsInstances = {projectile, lplr.Character}
					if projectile:GetAttribute('ProjectileShooter') ~= lplr.UserId then
						return
					end
					local origin = projectile:GetPivot().Position
					local velocity = projectile.PrimaryPart and projectile.PrimaryPart.Velocity or Vector3.zero
					local velocityMagnitude = velocity.Magnitude
					if velocityMagnitude <= 0 then
						return
					end
					local velocityUnit = velocity / velocityMagnitude
					local gravity = bedwars.ProjectileMeta[projectile.Name].gravitationalAcceleration
					local ray = workspace:Raycast(origin, velocityUnit * 2000, rayCheck)
					local endpoint = ray and ray.Position or (origin + velocityUnit * 2000)
					local travelTime = (endpoint - origin).Magnitude / velocityMagnitude

					prediction.SpawnArcTracer(
						origin,
						velocityUnit,
						velocityMagnitude,
						gravity,
						travelTime,
						Curve.Value,
						{
							Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value),
							Transparency = Opacity.Value,
							Thick = Thickness.Value,
							Material = Enum.Material[Material.Value],
							Lifetime = Lifetime.Value,
							Fade = Fade.Enabled,
						}
					)
				end)
			end))
		end
	end,
	Tooltip = 'Replacement tracers for projectiles'
    })

    local materials = {'SmoothPlastic'}
    for _, v in Enum.Material:GetEnumItems() do
	if v.Name ~= 'SmoothPlastic' then
		table.insert(materials, v.Name)
	end
    end
    Material = BulletTracers:CreateDropdown({
	Name = 'Material',
	List = materials
    })
    Color = BulletTracers:CreateColorSlider({
	Name = 'Tracer Color',
	DefaultOpacity = 0.5
    })
    Thickness = BulletTracers:CreateSlider({
	Name = 'Thickness',
	Min = 0.01,
	Max = 1,
	Default = 0.1,
	Decimal = 100
    })
    Curve = BulletTracers:CreateSlider({
	Name = 'Curveness',
	Min = 1,
	Max = 100,
	Default = 40,
	Tooltip = 'How curve the projectile is gonna be\n(More curve = more lag)'
    })
    Opacity = BulletTracers:CreateSlider({
	Name = 'Opacity',
	Min = 0,
	Max = 1,
	Default = 0,
	Decimal = 100
    })
    Lifetime = BulletTracers:CreateSlider({
	Name = 'Lifetime',
	Min = 0,
	Max = 5,
	Decimal = 100,
	Default = 2,
	Suffix = 'secs'
    })
    Fade = BulletTracers:CreateToggle({
	Name = 'Fade',
	Default = true
    })
end)

--[[
    SkinChanger

    Replaced with the reference build's approach. Rather than cloning skin models onto your
    hand and welding them, it sets the itemSkin field the game already carries on every
    inventory entry and re-renders the viewmodel, so the item shows up with that skin (and its
    sounds) through the game's own path. One dropdown per item kind - pick the skin family and
    every matching item you hold uses it.

    Client-side only: nobody else sees the change.
]]
run(function()
	local SkinChanger
	local Options = {}
	local skins, items = {}, {}

	local function prettify(text)
		return (text:gsub('_', ' '):gsub('%a+', function(word)
			return `{word:sub(1, 1):upper()}{word:sub(2)}`
		end))
	end

	local function getLabel(itemType, skin)
		local label = `_{skin}_`
		for word in itemType:gmatch('[^_]+') do
			label = label:gsub(`_{word}_`, '_')
		end
		label = label:gsub('^_+', ''):gsub('_+$', '')
		return label ~= '' and prettify(label) or prettify(skin)
	end

	for _, skin in bedwars.ItemSkinType do
		local meta = bedwars.getItemSkinMeta(skin)
		local item = meta and meta.itemType and bedwars.ItemMeta[meta.itemType]
		if item and not item.block then
			skins[meta.itemType] = skins[meta.itemType] or {}
			skins[meta.itemType][getLabel(meta.itemType, skin)] = skin
		end
	end

	for itemType in skins do
		table.insert(items, itemType)
	end
	table.sort(items, function(a, b)
		return prettify(a) < prettify(b)
	end)

	local function getSkin(itemType)
		local option = SkinChanger.Enabled and Options[itemType]
		return option and skins[itemType][option.Value] or nil
	end

	local function applySkins()
		local inventory = store.inventory.inventory
		for _, item in inventory.items do
			item.itemSkin = getSkin(item.itemType)
		end
		if inventory.hand then
			inventory.hand.itemSkin = getSkin(inventory.hand.itemType)
		end
		bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
	end

	SkinChanger = vape.Categories.Render:CreateModule({
		Name = 'SkinChanger',
		Function = function(callback)
			if callback then
				SkinChanger:Clean(vapeEvents.InventoryChanged.Event:Connect(applySkins))
				SkinChanger:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(applySkins))
				SkinChanger:Clean(lplr.CharacterAdded:Connect(function()
					task.spawn(function()
						for _ = 1, 10 do
							task.wait(0.4)
							if not SkinChanger.Enabled then return end
							applySkins()
						end
					end)
				end))
			end
			applySkins()
		end,
		Tooltip = 'Reskins the items you hold with their sounds, only you can see it'
	})

	for _, itemType in items do
		local list = {}
		for label in skins[itemType] do
			table.insert(list, label)
		end
		table.sort(list)
		table.insert(list, 1, 'None')

		Options[itemType] = SkinChanger:CreateDropdown({
			Name = prettify(itemType),
			List = list,
			Function = function()
				if SkinChanger.Enabled then
					applySkins()
				end
			end
		})
	end

end)

run(function()
    local StorageESP
    local List
    local Background
    local Color
    local Reference = {}
    local Connections = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local function nearStorageItem(item)
	for _, v in List.ListEnabled do
		if item:find(v) then
			return v
		end
	end
	return nil
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
		if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
			alreadygot[item.Name] = true
			v.Enabled = true
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({ itemType = item.Name }, true)
			blockimage.Parent = v.Frame
		end
	end
	table.clear(chestitems)
    end

    local function Removing(v)
	local billboard = Reference[v]
	if billboard then
		billboard:Destroy()
		Reference[v] = nil
	end

	local connections = Connections[v]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		Connections[v] = nil
	end
    end

    local function Clear()
	local references = table.clone(Reference)
	for v in references do
		Removing(v)
	end
	table.clear(references)
	Folder:ClearAllChildren()
    end

    local function Added(v)
	local chest = v:WaitForChild('ChestFolderValue', 3)
	if not (chest and StorageESP.Enabled and v:HasTag('chest')) then
		return
	end
	if Reference[v] then
		Removing(v)
	end
	chest = chest.Value
	if not chest then
		return
	end
	local billboard = Instance.new('BillboardGui')
	billboard.Parent = Folder
	billboard.Name = 'chest'
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
	local layoutConnection = layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
	end)
	layout.Parent = frame
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame
	Reference[v] = billboard
	Connections[v] = {
		layoutConnection,
		chest.ChildAdded:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end),
		chest.ChildRemoved:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end),
	}
	task.spawn(refreshAdornee, billboard)
    end

    StorageESP = vape.Categories.Render:CreateModule({
	Name = 'StorageESP',
	Function = function(callback)
		if callback then
			StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
			StorageESP:Clean(collectionService:GetInstanceRemovedSignal('chest'):Connect(Removing))
			StorageESP:Clean(Clear)
			for _, v in collectionService:GetTagged('chest') do
				task.spawn(Added, v)
			end
		else
			Clear()
		end
	end,
	Tooltip = 'Displays items in chests'
    })
    List = StorageESP:CreateTextList({
	Name = 'Item',
	Function = function()
		for _, v in Reference do
			task.spawn(refreshAdornee, v)
		end
	end,
    })
    Background = StorageESP:CreateToggle({
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
    Color = StorageESP:CreateColorSlider({
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
end)

-- Lobby milestone state remains available when BedWars transitions into a match.  Keep this
-- integration defensive because older queues do not load the milestone controller or metadata.
run(function()
    local ClaimRewards, CratesOnly, Notify
    local claimGeneration = 0

    local function rewardApi()
        local controller = bedwars.MilestonesController
        local rewards = bedwars.MilestoneRewards
        local state = bedwars.Store and bedwars.Store:getState()
        state = state and state.Bedwars
        if not controller or type(rewards) ~= 'table' or not state then return end
        return controller, rewards, state
    end

    ClaimRewards = vape.Categories.Utility:CreateModule({
        Name = 'ClaimRewards',
        Function = function(enabled)
            claimGeneration += 1
            if not enabled then return end
            local generation = claimGeneration
            task.spawn(function()
                while ClaimRewards.Enabled and claimGeneration == generation do
                    local controller, rewards, state = rewardApi()
                    if not controller then
                        notif('ClaimRewards', 'Milestone rewards are unavailable in this queue.', 5, 'warning')
                        ClaimRewards:Toggle()
                        break
                    end
                    local claimed = controller.milestoneRewardsClaimed or state.milestoneRewardsClaimed or {}
                    local level = state.playerLevel or 0
                    for _, reward in rewards do
                        if not ClaimRewards.Enabled or claimGeneration ~= generation then break end
                        if reward.levelRequirement <= level and not table.find(claimed, reward.id) and (not CratesOnly.Enabled or reward.instantClaim) then
						local remote = bedwars.Client and bedwars.Client:Get('ClaimMilestoneReward')
						local ok, result = false, nil
						if remote then ok, result = pcall(remote.CallServer, remote, reward.id) end
                            if ok and result then
                                table.insert(claimed, reward.id)
                                if Notify.Enabled then notif('ClaimRewards', `Claimed {reward.description or reward.id}`, 5) end
                            end
                            task.wait(1)
                        end
                    end
                    task.wait(5)
                end
            end)
        end,
        Tooltip = 'Claims unlocked level milestone rewards with the native reward remote.'
    })
    CratesOnly = ClaimRewards:CreateToggle({Name = 'Crates only', Tooltip = 'Only claim instant crate rewards.'})
    Notify = ClaimRewards:CreateToggle({Name = 'Notify', Default = true})
end)

run(function()
	local category = vape.Categories.Inventory or vape.Categories.Utility or vape.Categories.World
	if not category or type(category.CreateModule) ~= 'function' then
		warn('[AetherV2] AutoEnchant could not find a module category')
		return
	end

	local AutoEnchant, Repair, Desired, MaximumRolls, Reserve, Interval
	local generation = 0
	local enchantNames = {}

	local function normalise(value)
		return tostring(value or ''):lower():gsub('[%s_%-]+', '')
	end

	local function displayName(key, meta)
		return tostring((type(meta) == 'table' and (meta.displayName or meta.name)) or key):gsub('_', ' ')
	end

	if type(bedwars.EnchantMeta) == 'table' then
		for key, meta in pairs(bedwars.EnchantMeta) do
			table.insert(enchantNames, displayName(key, meta))
		end
	end
	if #enchantNames == 0 then
		enchantNames = {'Critical Strike', 'Fire', 'Life Steal', 'Shield Gen', 'Static', 'Updraft', 'Wind'}
	end
	table.sort(enchantNames)

	local function diamonds()
		local item = getItem('diamond')
		return item and tonumber(item.amount) or 0
	end

	local function currentEnchant()
		local state
		pcall(function() state = bedwars.Store:getState() end)
		local value = type(state) == 'table' and state.Bedwars and state.Bedwars.enchant or nil
		value = value or lplr:GetAttribute('Enchant')
		if type(value) == 'table' then value = value.enchant or value.type or value.itemType end
		if value == nil or tostring(value) == '' or tostring(value):lower() == 'none' then return '' end
		return displayName(value, type(bedwars.EnchantMeta) == 'table' and bedwars.EnchantMeta[value] or nil)
	end

	local function hasDesired(value)
		return Desired and normalise(Desired.Value) == normalise(value)
	end

	local function findTable()
		if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then return end
		local nearest, nearestDistance
		for _, object in pairs(store.enchant or {}) do
			if typeof(object) == 'Instance' and object.Parent then
				local ok, position = pcall(function()
					return object:IsA('Model') and object:GetPivot().Position or object.Position
				end)
				if ok and typeof(position) == 'Vector3' then
					local distance = (entitylib.character.RootPart.Position - position).Magnitude
					if not nearestDistance or distance < nearestDistance then nearest, nearestDistance = object, distance end
				end
			end
		end
		return nearest, nearestDistance
	end

	local function request(controllerNames, remoteNames, tableModel)
		local controller = bedwars.EnchantTableController or bedwars.EnchantController
		for _, name in ipairs(controllerNames) do
			if controller and type(controller[name]) == 'function' then
				local ok, result = pcall(controller[name], controller, tableModel)
				if ok and result ~= false then return true end
			end
		end
		for _, name in ipairs(remoteNames) do
			local ok = pcall(function()
				local handler = bedwars.Handler and bedwars.Handler:Get(name)
				if not handler then error('missing remote') end
				handler:Fire('CallServerAsync', tableModel)
			end)
			if ok then return true end
		end
		return false
	end

	AutoEnchant = category:CreateModule({
		Name = 'AutoEnchant',
		Tooltip = 'Rolls a nearby team enchant table until an accepted enchant is obtained.',
		Function = function(enabled)
			generation += 1
			if not enabled then return end
			local token = generation
			local worker = task.spawn(function()
				local rolls, character = 0, lplr.Character
				while AutoEnchant.Enabled and token == generation do
					if lplr.Character ~= character then
						character, rolls = lplr.Character, 0
					end
					local tableModel, distance = findTable()
					if not tableModel or not distance or distance > 18 then
						task.wait(0.25)
						continue
					end
					if hasDesired(currentEnchant()) then
						rolls = 0
						task.wait(0.25)
						continue
					end
					if rolls >= MaximumRolls.Value then
						notif('AutoEnchant', 'Maximum rolls reached without the selected enchant.', 5, 'warning')
						task.defer(function() if AutoEnchant.Enabled and token == generation then AutoEnchant:Toggle() end end)
						break
					end
					local broken = false
					pcall(function() broken = collectionService:HasTag(tableModel, 'broken-enchant-table') end)
					if broken then
						if not Repair.Enabled or diamonds() < Reserve.Value + 8 then task.wait(0.25); continue end
						if not request({'repairEnchantTable', 'repair'}, {'RepairEnchantTable', 'RepairEnchantTableRemote'}, tableModel) then
							task.wait(1)
							continue
						end
						task.wait(math.max(Interval.Value, 0.25))
						continue
					end
					local state
					pcall(function() state = bedwars.Store:getState() end)
					local bedwarsState = type(state) == 'table' and type(state.Bedwars) == 'table' and state.Bedwars or {}
					local gameState = type(state) == 'table' and type(state.Game) == 'table' and state.Game or {}
					local cost = tonumber(bedwarsState.enchantCost or gameState.enchantCost) or 2
					if diamonds() - cost < Reserve.Value then task.wait(0.25); continue end
					local before = currentEnchant()
					if not request({'purchaseEnchant', 'rollEnchant'}, {'PurchaseEnchant', 'RequestEnchant'}, tableModel) then
						task.wait(1)
						continue
					end
					rolls += 1
					local deadline = tick() + 4
					repeat task.wait() until not AutoEnchant.Enabled or token ~= generation or lplr.Character ~= character or currentEnchant() ~= before or tick() >= deadline
					if AutoEnchant.Enabled and token == generation and lplr.Character == character then
						task.wait(Interval.Value)
					end
				end
			end)
			AutoEnchant:Clean(worker)
		end
	})
	Desired = AutoEnchant:CreateDropdown({Name = 'Desired enchant', List = enchantNames, Default = enchantNames[1], Tooltip = 'Stops rolling as soon as this enchant is obtained.'})
	Repair = AutoEnchant:CreateToggle({Name = 'Repair enchant table', Default = true})
	MaximumRolls = AutoEnchant:CreateSlider({Name = 'Maximum rolls', Min = 1, Max = 50, Default = 10})
	Reserve = AutoEnchant:CreateSlider({Name = 'Resource reserve', Min = 0, Max = 32, Default = 0, Suffix = ' diamonds'})
	Interval = AutoEnchant:CreateSlider({Name = 'Request interval', Min = 0.25, Max = 2, Default = 0.6, Decimal = 100, Suffix = 's'})
end)

run(function()
    local StreamRemover
    local hooks, originalText = {}, setmetatable({}, {__mode = 'k'})
    local refreshQueued = false
    local replacementCache = {}
    local function playerFromArgs(...)
        for i = 1, select('#', ...) do
            local value = select(i, ...)
            if typeof(value) == 'Instance' then
                if value:IsA('Player') then return value end
                local player = playersService:GetPlayerFromCharacter(value); if player then return player end
            elseif type(value) == 'table' then
                local candidate = rawget(value, 'player') or rawget(value, 'Player')
                if typeof(candidate) == 'Instance' and candidate:IsA('Player') then return candidate end
            end
        end
    end
    local function realValue(method, player, value)
        local lower = method:lower()
        if lower:find('display') and lower:find('name') then return player.DisplayName end
        if lower:find('user') and lower:find('name') or lower == 'getname' then return player.Name end
        if lower:find('level') then return tonumber(player:GetAttribute('PlayerLevel')) or value end
        return value
    end
    local function refreshController()
        local controller = (bedwars.Knit.Controllers and bedwars.Knit.Controllers.StreamerModeController) or bedwars.StreamerModeController
        if controller then pcall(function() controller:updateNametags(true) end) end
    end
    local function replacements()
        local result = {}
        for _, player in playersService:GetPlayers() do
            table.insert(result, {
                Player = player,
                Display = player:GetAttribute('DisguiseDisplayName'),
                Username = player:GetAttribute('DisguiseUsername'),
                Level = tostring(tonumber(player:GetAttribute('PlayerLevel')) or 0)
            })
        end
        replacementCache = result
        return result
    end
    local function refreshObject(object, players)
        if not object:IsA('TextLabel') and not object:IsA('TextButton') then return end
        local text = object.Text
        for _, data in players do
                local player = data.Player
                local disguised, username, level = data.Display, data.Username, data.Level
                local relevant = text == 'Me' or text == '[?]' or (disguised and disguised ~= '' and text:find(disguised, 1, true)) or (username and username ~= '' and text:find(username, 1, true))
                if relevant then
                    originalText[object] = originalText[object] or text
                    object.Text = text == '[?]' and '['..level..']' or text == 'Me' and player.DisplayName or text:gsub(disguised or '\0', player.DisplayName):gsub(username or '\0', player.Name)
                end
        end
    end
    local function refreshGui(root)
        for _, object in root:GetDescendants() do refreshObject(object, replacementCache) end
    end
    local function queueRefresh()
        if refreshQueued then return end
        refreshQueued = true
        task.defer(function()
            refreshQueued = false
            if StreamRemover.Enabled then replacements(); refreshController(); refreshGui(lplr.PlayerGui) end
        end)
    end
    local function installHooks()
        local gamePlayer = require(replicatedStorage.TS.player['game-player'])
        for name, fn in gamePlayer do
            if type(fn) == 'function' and (name:lower():find('name') or name:lower():find('level') or name:lower():find('disguise')) then
                hooks[name] = fn
                gamePlayer[name] = function(...)
                    local result = fn(...)
                    local player = playerFromArgs(...)
                    return player and realValue(name, player, result) or result
                end
            end
        end
        bedwars.GamePlayer = gamePlayer
    end
    StreamRemover = vape.Categories.Render:CreateModule({
        Name = 'StreamRemover',
        Function = function(enabled)
            if enabled then
                installHooks(); replacements(); refreshController(); refreshGui(lplr.PlayerGui)
                local function watch(player)
                    for _, attribute in {'DisguiseDisplayName', 'DisguiseUsername', 'PlayerLevel'} do
                        StreamRemover:Clean(player:GetAttributeChangedSignal(attribute):Connect(queueRefresh))
                    end
                    StreamRemover:Clean(player.CharacterAdded:Connect(function() task.defer(refreshController) end))
                end
                for _, player in playersService:GetPlayers() do watch(player) end
                StreamRemover:Clean(playersService.PlayerAdded:Connect(function(player) replacements(); watch(player) end))
                StreamRemover:Clean(playersService.PlayerRemoving:Connect(function() task.defer(replacements) end))
                StreamRemover:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(object)
                    -- Process only the new text object. Attribute changes use the coalesced full
                    -- refresh above, so a kill-feed tree being constructed cannot trigger dozens
                    -- of complete PlayerGui scans in the same frame.
                    if object:IsA('TextLabel') or object:IsA('TextButton') then refreshObject(object, replacementCache) end
                end))
            else
                local gamePlayer = bedwars.GamePlayer
                for name, fn in hooks do gamePlayer[name] = fn end
                table.clear(hooks)
                for object, text in originalText do if object.Parent then object.Text = text end end
                table.clear(originalText); refreshController()
            end
        end,
        Tooltip = 'Reversibly reveals real display names, usernames, and player levels in streamer-mode UI'
    })
end)

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

run(function()
    local ViewmodelVisuals
    local StrokeColor
    local Color

    local Instances = {}

    ViewmodelVisuals = vape.Categories.Render:CreateModule({
        Name = 'ViewmodelVisuals',
        Function = function(call)
            if call then
                local viewmodel = gameCamera:WaitForChild('Viewmodel', 9e9)
                if not ViewmodelVisuals.Enabled then
                    return
                end

                for i,v in viewmodel:GetChildren() do
                    if v:IsA('Accessory') then
                        local highlight = v.Handle:FindFirstChildOfClass('Highlight') or Instance.new('Highlight', v.Handle)
                        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        highlight.FillTransparency = Color.Opacity
                        highlight.OutlineTransparency = StrokeColor.Opacity
                        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)

                        ViewmodelVisuals:Clean(highlight)
                        table.insert(Instances, highlight)

                        break
                    end
                end

                ViewmodelVisuals:Clean(viewmodel.ChildAdded:Connect(function(visual)
                    if visual:IsA('Accessory') then
                        local highlight = visual.Handle:FindFirstChildOfClass('Highlight') or Instance.new('Highlight', visual.Handle)
                        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        highlight.FillTransparency = Color.Opacity
                        highlight.OutlineTransparency = StrokeColor.Opacity
                        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)

                        ViewmodelVisuals:Clean(highlight)
                        table.insert(Instances, highlight)
                    end
                end))

                ViewmodelVisuals:Clean(gameCamera.ChildAdded:Connect(function(visual)
                    if visual.Name == 'Viewmodel' then
                        ViewmodelVisuals:Toggle()
                        ViewmodelVisuals:Toggle()
                    end
                end))
            end
        end
    })

    Color = ViewmodelVisuals:CreateColorSlider({
        Name = 'Color',
        Default = Color3.new(1, 1, 1),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.FillColor = Color3.fromHSV(hue, sat, val)
                v.FillTransparency = opacity
            end
        end
    })
    StrokeColor = ViewmodelVisuals:CreateColorSlider({
        Name = 'Stroke Color',
        Default = Color3.new(),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.OutlineColor = Color3.fromHSV(hue, sat, val)
                v.OutlineTransparency = opacity
            end
        end
    })
end)

--[[
    Utility
]]

-- MP3Player: plays your own .mp3 files out of the aetherv2/songs folder the loader creates.
--
-- The folder is scanned live, so songs added or deleted while you are in a game are picked up
-- without a reinject (Auto refresh, plus a Refresh button for right now). Anything the executor
-- can turn into an asset works - mp3, wav, ogg.
--
run(function()
    local MP3Player
    local Volume
    local Speed
    local Shuffle
    local Loop
    local AutoRefresh
    local PlayField
    local Playlist
    local ShowHUD
    local HUDProgress
    local HUDTime
    local HUDColor

    local SONGS = 'aetherv2/songs'
    local SPOTIFY = 'aetherv2/spotify'

    local sound
    local tracks, index = {}, 0
    local hudName, hudTime, hudBarFill, hudBackground
    local lastScan = 0
    local scanKey = ''
    -- When the current track was started, so the watchdog below can tell a song that has
    -- finished from one that has only just been asked to start.
    local lastPlay = 0

    -- Every filesystem call is optional: some executors ship none of them, and the module has to
    -- degrade to "no songs found" rather than erroring on load.
    local function fsList(path)
        local ok, res = pcall(function()
            if isfolder and not isfolder(path) then
                if makefolder then makefolder(path) end
                return {}
            end
            return listfiles and listfiles(path) or {}
        end)
        return ok and res or {}
    end

    local function isAudio(path)
        path = tostring(path):lower()
        return path:sub(-4) == '.mp3' or path:sub(-4) == '.wav' or path:sub(-4) == '.ogg'
    end

    local function fileName(path)
        local normalised = tostring(path):gsub('\\', '/')
        local name = normalised:match('([^/]+)$') or normalised
        return (name:gsub('%.[^%.]+$', ''))
    end

    local function scan(announce)
        local found = {}
        for _, file in fsList(SONGS) do
            if isAudio(file) then
                table.insert(found, {Name = fileName(file), Path = tostring(file):gsub('\\', '/')})
            end
        end
        for _, file in fsList(SPOTIFY) do
            if isAudio(file) then
                table.insert(found, {Name = fileName(file), Path = tostring(file):gsub('\\', '/')})
            end
        end
        table.sort(found, function(a, b)
            return a.Name:lower() < b.Name:lower()
        end)

        -- Playlist, when you have filled one in, is both the filter and the order.
        local wanted = Playlist and Playlist.ListEnabled or {}
        if #wanted > 0 then
            local ordered = {}
            for _, entry in wanted do
                local needle = entry:lower()
                for _, track in found do
                    if track.Name:lower():find(needle, 1, true) then
                        table.insert(ordered, track)
                        break
                    end
                end
            end
            if #ordered > 0 then
                found = ordered
            end
        end

        local key = ''
        for _, track in found do
            key = key .. track.Path .. ';'
        end
        local changed = key ~= scanKey
        scanKey = key
        tracks = found
        if changed and announce and MP3Player.Enabled then
            notif('MP3Player', #tracks > 0 and (#tracks .. ' song' .. (#tracks == 1 and '' or 's') .. ' loaded') or 'No songs in the songs folder yet', 3)
        end
        return changed
    end

    local function assetFor(path)
        local ok, asset = pcall(function()
            return getcustomasset(path)
        end)
        return ok and asset or nil
    end

    local function refreshHUD()
        if not hudName then return end
        local track = tracks[index]
        local colour = HUDColor and Color3.fromHSV(HUDColor.Hue, HUDColor.Sat, HUDColor.Value) or Color3.new(1, 1, 1)
        hudName.TextColor3 = colour
        hudName.Text = track and track.Name or 'No song loaded'
        if hudBackground then
            hudBackground.BackgroundTransparency = HUDColor and (1 - (HUDColor.Opacity * 0.65)) or 0.35
        end

        local length = sound and sound.TimeLength or 0
        local at = sound and sound.TimePosition or 0
        if hudTime then
            hudTime.Visible = HUDTime == nil or HUDTime.Enabled
            hudTime.TextColor3 = colour
            local function clock(t)
                t = math.max(math.floor(t), 0)
                return string.format('%d:%02d', t // 60, t % 60)
            end
            hudTime.Text = track and (clock(at) .. ' / ' .. clock(length)) or ''
        end
        if hudBarFill then
            hudBarFill.Parent.Visible = HUDProgress == nil or HUDProgress.Enabled
            hudBarFill.BackgroundColor3 = colour
            hudBarFill.Size = UDim2.fromScale(length > 0 and math.clamp(at / length, 0, 1) or 0, 1)
        end
    end

    local function stop()
        if sound then
            pcall(function()
                sound:Stop()
            end)
        end
    end

    -- Looping is the engine's job, not ours.
    --
    -- Repeating a song used to mean replaying it from the Ended handler, which is two
    -- problems at once: it leaves an audible gap at every repeat, and Ended is not
    -- something to depend on - a sound whose asset was still loading when Play ran can
    -- fire it immediately or never, and then the music just stops. Looped restarts the
    -- track inside the engine with no gap and no event involved.
    --
    -- Called on every play AND from the two toggles, so turning Loop on part way through a
    -- song loops that song rather than quietly waiting for the next one - which is what
    -- made the toggle look like it did nothing at all.
    local function applyLoop()
        if not (sound and Loop and Shuffle) then return end
        sound.Looped = Loop.Enabled and not Shuffle.Enabled
    end

    local function play(newIndex)
        if #tracks <= 0 then
            index = 0
            refreshHUD()
            return
        end
        -- Stamped before the asset is resolved, not after: a track the executor cannot load
        -- returns below, and leaving the stamp stale would have the watchdog walk the
        -- playlist several times a second complaining about each one.
        lastPlay = tick()
        index = ((newIndex - 1) % #tracks) + 1
        local track = tracks[index]
        local asset = track and assetFor(track.Path)
        if not asset then
            notif('MP3Player', 'Could not load ' .. (track and track.Name or 'that song'), 4, 'warning')
            return
        end
        if not sound then return end
        sound.SoundId = asset
        sound.Volume = Volume.Value / 100
        sound.PlaybackSpeed = Speed.Value
        sound.TimePosition = 0
        applyLoop()
        pcall(function()
            sound:Play()
        end)
        refreshHUD()
    end

    local function advance(step)
        if #tracks <= 0 then return end
        if Shuffle.Enabled and #tracks > 1 then
            local pick = index
            for _ = 1, 8 do
                pick = math.random(1, #tracks)
                if pick ~= index then break end
            end
            play(pick)
            return
        end
        play(index + step)
    end

    MP3Player = vape.Categories.Utility:CreateModule({
        Name = 'MP3Player',
        Function = function(callback)
            if callback then
                if not (listfiles and getcustomasset) then
                    notif('MP3Player', 'Your executor cannot read local files, so there is nothing to play', 6, 'warning')
                    return task.spawn(function()
                        if MP3Player.Enabled then MP3Player:Toggle() end
                    end)
                end
                if isfolder and makefolder then
                    if not isfolder(SONGS) then makefolder(SONGS) end
                end

                sound = Instance.new('Sound')
                sound.Name = 'AetherMP3'
                sound.Volume = Volume.Value / 100
                sound.PlaybackSpeed = Speed.Value
                sound.Parent = vape.gui
                MP3Player:Clean(sound)
                -- Only ever advances: a looping track never ends, because Looped keeps it
                -- going inside the engine.
                MP3Player:Clean(sound.Ended:Connect(function()
                    if not MP3Player.Enabled then return end
                    advance(1)
                end))

                -- Toggle() shows the HUD frame for any module with a Size, so put Show HUD back in
                -- charge of it now that the module is on.
                if MP3Player.Children then
                    MP3Player.Children.Visible = ShowHUD.Enabled
                end

                scan(true)
                if #tracks > 0 then
                    play(Shuffle.Enabled and math.random(1, #tracks) or 1)
                end

                MP3Player:Clean(task.spawn(function()
                    while MP3Player.Enabled do
                        if AutoRefresh.Enabled and tick() - lastScan > 3 then
                            lastScan = tick()
                            local changed = scan(true)
                            -- Nothing playing and songs have just appeared: start on them.
                            if changed and sound and not sound.IsPlaying and #tracks > 0 then
                                play(index > 0 and index or 1)
                            end
                        end
                        -- Backstop for a track that finished without Ended firing, which is
                        -- what left the playlist sitting in silence part way through. A
                        -- looping track is still playing, so this never touches it, and the
                        -- second since the last start keeps it off a song that is loading.
                        if sound and #tracks > 0 and sound.SoundId ~= '' and sound.IsLoaded
                            and not sound.IsPlaying and not sound.IsPaused
                            and (tick() - lastPlay) > 1 then
                            advance(1)
                        end
                        refreshHUD()
                        task.wait(0.2)
                    end
                end))
            else
                stop()
                sound = nil
                index = 0
                scanKey = ''
                refreshHUD()
            end
        end,
        Tooltip = 'Plays your own mp3 files from the aetherv2/songs folder, with a HUD and a live-refreshing playlist',
        Size = UDim2.fromOffset(236, 66),
        ExtraText = function()
            local track = tracks[index]
            return track and track.Name or nil
        end
    })

    -- HUD, built into the draggable frame the GUI hands us (same pattern AutoWin uses).
    if MP3Player.Children then
        local hud = MP3Player.Children
        if hud.Position == UDim2.new() then
            hud.Position = UDim2.fromOffset(16, 340)
        end
        hudBackground = Instance.new('Frame')
        hudBackground.Size = UDim2.fromScale(1, 1)
        hudBackground.BackgroundColor3 = Color3.new()
        hudBackground.BackgroundTransparency = 0.35
        hudBackground.BorderSizePixel = 0
        hudBackground.Parent = hud
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = hudBackground

        local title = Instance.new('TextLabel')
        title.Size = UDim2.new(1, -14, 0, 16)
        title.Position = UDim2.fromOffset(9, 5)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = Color3.fromRGB(170, 170, 170)
        title.Text = 'MP3Player'
        title.Parent = hudBackground

        hudName = Instance.new('TextLabel')
        hudName.Size = UDim2.new(1, -18, 0, 18)
        hudName.Position = UDim2.fromOffset(9, 21)
        hudName.BackgroundTransparency = 1
        hudName.Font = Enum.Font.GothamMedium
        hudName.TextSize = 13
        hudName.TextXAlignment = Enum.TextXAlignment.Left
        hudName.TextTruncate = Enum.TextTruncate.AtEnd
        hudName.TextColor3 = Color3.new(1, 1, 1)
        hudName.Text = 'No song loaded'
        hudName.Parent = hudBackground

        hudTime = Instance.new('TextLabel')
        hudTime.Size = UDim2.new(1, -18, 0, 14)
        hudTime.Position = UDim2.fromOffset(-9, 5)
        hudTime.BackgroundTransparency = 1
        hudTime.Font = Enum.Font.Gotham
        hudTime.TextSize = 11
        hudTime.TextXAlignment = Enum.TextXAlignment.Right
        hudTime.TextColor3 = Color3.new(1, 1, 1)
        hudTime.Text = ''
        hudTime.Parent = hudBackground

        local bar = Instance.new('Frame')
        bar.Size = UDim2.new(1, -18, 0, 4)
        bar.Position = UDim2.fromOffset(9, 46)
        bar.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        bar.BorderSizePixel = 0
        bar.Parent = hudBackground
        local barCorner = Instance.new('UICorner')
        barCorner.CornerRadius = UDim.new(1, 0)
        barCorner.Parent = bar

        hudBarFill = Instance.new('Frame')
        hudBarFill.Size = UDim2.fromScale(0, 1)
        hudBarFill.BackgroundColor3 = Color3.new(1, 1, 1)
        hudBarFill.BorderSizePixel = 0
        hudBarFill.Parent = bar
        local fillCorner = Instance.new('UICorner')
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = hudBarFill
    end

    MP3Player:CreateButton({
        Name = 'Play / Pause',
        Function = function()
            if not sound then return end
            if sound.IsPlaying then
                sound:Pause()
            elseif sound.SoundId ~= '' then
                sound:Resume()
            else
                play(index > 0 and index or 1)
            end
        end,
        Tooltip = 'Pause or resume the current song'
    })
    MP3Player:CreateButton({
        Name = 'Next song',
        Function = function()
            advance(1)
        end
    })
    MP3Player:CreateButton({
        Name = 'Previous song',
        Function = function()
            advance(-1)
        end
    })
    MP3Player:CreateButton({
        Name = 'Refresh songs',
        Function = function()
            lastScan = tick()
            scan(true)
            refreshHUD()
        end,
        Tooltip = 'Re-read the songs folder right now'
    })
    Volume = MP3Player:CreateSlider({
        Name = 'Volume',
        Min = 0,
        Max = 100,
        Default = 40,
        Suffix = '%',
        Function = function(val)
            if sound then
                sound.Volume = val / 100
            end
        end
    })
    Speed = MP3Player:CreateSlider({
        Name = 'Speed',
        Min = 0.5,
        Max = 2,
        Default = 1,
        Decimal = 100,
        Suffix = 'x',
        Function = function(val)
            if sound then
                sound.PlaybackSpeed = val
            end
        end,
        Tooltip = 'Playback speed'
    })
    Shuffle = MP3Player:CreateToggle({
        Name = 'Shuffle',
        Function = applyLoop,
        Tooltip = 'Pick the next song at random instead of in order'
    })
    Loop = MP3Player:CreateToggle({
        Name = 'Loop song',
        Function = applyLoop,
        Tooltip = 'Repeat the current song instead of moving on'
    })
    AutoRefresh = MP3Player:CreateToggle({
        Name = 'Auto refresh',
        Default = true,
        Tooltip = 'Watch the songs folder and pick up new or deleted files while you play'
    })
    PlayField = MP3Player:CreateTextBox({
        Name = 'Play song',
        Placeholder = 'song name',
        -- TextBox hands us `enter`, not the text, and fires on every keystroke - so only act once
        -- the name has actually been submitted.
        Function = function(enter)
            if not enter then return end
            local val = PlayField and PlayField.Value or ''
            if val == '' then return end
            scan(false)
            local needle = val:lower()
            for i, track in tracks do
                if track.Name:lower():find(needle, 1, true) then
                    play(i)
                    return
                end
            end
            notif('MP3Player', 'No song matching "' .. val .. '"', 4, 'warning')
        end,
        Tooltip = 'Type part of a song name to jump straight to it'
    })
    Playlist = MP3Player:CreateTextList({
        Name = 'Playlist',
        Placeholder = 'song name',
        Function = function()
            scan(true)
        end,
        Tooltip = 'Leave empty to play everything in the folder. Add names and only those play, in the order you list them'
    })
    ShowHUD = MP3Player:CreateToggle({
        Name = 'Show HUD',
        Default = true,
        Tooltip = 'Show the now-playing panel. Drag it by its own frame to move it',
        Function = function(callback)
            pcall(function()
                HUDProgress.Object.Visible = callback
                HUDTime.Object.Visible = callback
                HUDColor.Object.Visible = callback
            end)
            if MP3Player.Children then
                MP3Player.Children.Visible = callback and MP3Player.Enabled
            end
        end
    })
    HUDProgress = MP3Player:CreateToggle({
        Name = 'Progress bar',
        Default = true,
        Darker = true,
        Tooltip = 'Show how far through the song you are'
    })
    HUDTime = MP3Player:CreateToggle({
        Name = 'Show time',
        Default = true,
        Darker = true,
        Tooltip = 'Show elapsed and total time'
    })
    HUDColor = MP3Player:CreateColorSlider({
        Name = 'HUD color',
        Darker = true,
        DefaultOpacity = 0.55,
        Function = refreshHUD
    })
end)