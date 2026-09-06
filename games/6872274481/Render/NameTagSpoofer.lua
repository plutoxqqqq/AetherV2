run(function()
	local NameTagSpoofer
	local CustomNameBox
	local trackedElements = setmetatable({}, {__mode = 'k'})
	local trackedUsernames = setmetatable({}, {__mode = 'k'})
	local hiddenLabels = setmetatable({}, {__mode = 'k'})
	local watched = setmetatable({}, {__mode = 'k'})
	local applying = setmetatable({}, {__mode = 'k'})

	local function getCustomName()
		if CustomNameBox and type(CustomNameBox.Value) == "string" and CustomNameBox.Value ~= "" then
			return CustomNameBox.Value
		end
		return "Me"
	end

	local function containsLocalName(text)
		return type(text) == 'string' and (text:find(lplr.Name, 1, true) ~= nil
			or text:find(lplr.DisplayName, 1, true) ~= nil)
	end

	local function setText(element, value)
		if not element.Parent or element.Text == value then return end
		applying[element] = true
		element.Text = value
		applying[element] = nil
	end

	local applyObject
	local function watchText(element)
		if watched[element] then return end
		watched[element] = true
		NameTagSpoofer:Clean(element:GetPropertyChangedSignal('Text'):Connect(function()
			if NameTagSpoofer.Enabled and not applying[element] then applyObject(element) end
		end))
	end

	applyObject = function(element)
		if not element or not element.Parent then return end
		if element:IsA('TextLabel') and table.find({'PlayerName', 'EntityName', 'DisplayName'}, element.Name) then
			watchText(element)
			local original = trackedElements[element]
			if original then
				if containsLocalName(element.Text) then original.Text = element.Text end
				setText(element, getCustomName())
			elseif containsLocalName(element.Text) then
				trackedElements[element] = {Text = element.Text}
				setText(element, getCustomName())
			end
		elseif element:IsA('TextBox') and element.Name == 'PlayerUsername' then
			watchText(element)
			local original = trackedUsernames[element]
			if original then
				if containsLocalName(element.Text) then original.Text = element.Text end
				setText(element, '@'..getCustomName())
			elseif containsLocalName(element.Text) then
				trackedUsernames[element] = {Text = element.Text}
				setText(element, '@'..getCustomName())
			end
		elseif element:IsA('TextLabel') and element.Name == '@'
			and element.Parent and element.Parent.Name == 'PlayerUsername' then
			if hiddenLabels[element] == nil then hiddenLabels[element] = element.Visible end
			element.Visible = false
		end
	end

	local function processRoot(root)
		if not root then return end
		applyObject(root)
		for _, descendant in root:GetDescendants() do applyObject(descendant) end
	end

	local function attachCharacter(character)
		if not character then return end
		processRoot(character)
		NameTagSpoofer:Clean(character.DescendantAdded:Connect(applyObject))
	end

	local function restore()
		for element, original in trackedElements do
			if element.Parent then pcall(setText, element, original.Text) end
		end
		for element, original in trackedUsernames do
			if element.Parent then pcall(setText, element, original.Text) end
		end
		for element, visible in hiddenLabels do
			if element.Parent then pcall(function() element.Visible = visible end) end
		end
		table.clear(trackedElements)
		table.clear(trackedUsernames)
		table.clear(hiddenLabels)
		table.clear(watched)
		table.clear(applying)
	end

	NameTagSpoofer = vape.Categories.Render:CreateModule({
		Name = 'NameTagSpoofer',
		Function = function(callback)
			if callback then
				processRoot(lplr.PlayerGui)
				attachCharacter(lplr.Character)
				NameTagSpoofer:Clean(lplr.PlayerGui.DescendantAdded:Connect(applyObject))
				NameTagSpoofer:Clean(lplr.CharacterAdded:Connect(attachCharacter))
				NameTagSpoofer:Clean(restore)
			else
				restore()
			end
		end,
		Tooltip = 'Customize your name in various places'
	})

	CustomNameBox = NameTagSpoofer:CreateTextBox({
		Name = 'Custom Name',
		Default = 'Me',
		Placeholder = 'Enter name...',
		Function = function()
			if not NameTagSpoofer.Enabled then return end
			for element in trackedElements do if element.Parent then setText(element, getCustomName()) end end
			for element in trackedUsernames do if element.Parent then setText(element, '@'..getCustomName()) end end
		end
	})
end)
