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
