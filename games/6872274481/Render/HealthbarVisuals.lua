local function category(name)
	if vape and vape.Categories and vape.Categories[name] then
		return vape.Categories[name]
	end
	if vape and vape.Categories then
		for _, cat in pairs(vape.Categories) do
			if type(cat) == "table" and cat.CreateModule then
				return cat
			end
		end
	end
	return nil
end

local function createModule(catName, def)
	local cat = category(catName) or category("Utility") or category("Render") or category("Blatant")
	assert(cat and cat.CreateModule, "Aether GUI not ready (no CreateModule)")
	return cat:CreateModule(def)
end

local function isAlive(plr)
	plr = plr or lplr
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and root ~= nil and hum.Health > 0
end

local function guiColor()
	local ok, color = pcall(function()
		if vape.GUIColor then
			return Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		end
	end)
	if ok and color then return color end
	return Color3.fromRGB(120, 200, 255)
end

run(function()
	local made = {}
	local textCon
	local MainOn, GradOn, BgOn, RoundOn, StrokeOn, TextOn, FontOn, GuiSync
	local MainCol, GradCol, BgCol, StrokeCol, TextCol, RoundSize, FontDrop, TextList

	local function apply()
		if not Healthbar.Enabled then return end
		local bar = ({pcall(function()
			return lplr.PlayerGui.hotbar["1"].HotbarHealthbarContainer.HealthbarProgressWrapper["1"]
		end)})[2]
		if typeof(bar) ~= "Instance" then return end

		if GuiSync and GuiSync.Enabled then
			bar.BackgroundColor3 = guiColor()
		elseif MainOn and MainOn.Enabled then
			bar.BackgroundColor3 = MainCol and Color3.fromHSV(MainCol.Hue or 0, MainCol.Sat or 0.8, MainCol.Value or 1) or Color3.fromRGB(203, 54, 36)
			if GradOn and GradOn.Enabled then
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
				local g = bar:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient", bar)
				local a = MainCol and Color3.fromHSV(MainCol.Hue or 0, MainCol.Sat or 0.8, MainCol.Value or 1) or Color3.fromRGB(203, 54, 36)
				local b = GradCol and Color3.fromHSV(GradCol.Hue or 0.05, GradCol.Sat or 0.8, GradCol.Value or 1) or Color3.fromRGB(255, 160, 40)
				g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b)})
				table.insert(made, g)
			end
		end

		local bg = bar.Parent and bar.Parent.Parent
		if typeof(bg) == "Instance" then
			if BgOn and BgOn.Enabled then
				bg.BackgroundColor3 = BgCol and Color3.fromHSV(BgCol.Hue or 0.6, BgCol.Sat or 0.2, BgCol.Value or 0.2) or Color3.fromRGB(41, 51, 65)
			end
			if StrokeOn and StrokeOn.Enabled and not bg:FindFirstChildWhichIsA("UIStroke") then
				local s = Instance.new("UIStroke")
				s.Thickness = 1.6
				s.Color = StrokeCol and Color3.fromHSV(StrokeCol.Hue or 0, StrokeCol.Sat or 0, StrokeCol.Value or 1) or Color3.new(1, 1, 1)
				s.Parent = bg
				table.insert(made, s)
			end
			if RoundOn and RoundOn.Enabled then
				for _, f in ipairs(bar.Parent:GetChildren()) do
					if f:IsA("Frame") and not f:FindFirstChildWhichIsA("UICorner") then
						local c = Instance.new("UICorner")
						c.CornerRadius = UDim.new(0, RoundSize and RoundSize.Value or 4)
						c.Parent = f
						table.insert(made, c)
					end
				end
				if not bg:FindFirstChildWhichIsA("UICorner") then
					local c = Instance.new("UICorner")
					c.CornerRadius = UDim.new(0, RoundSize and RoundSize.Value or 4)
					c.Parent = bg
					table.insert(made, c)
				end
			end

			local label = bg:FindFirstChild("1")
			if typeof(label) == "Instance" and label:IsA("TextLabel") then
				if TextCol and TextOn and TextOn.Enabled then
					label.TextColor3 = Color3.fromHSV(TextCol.Hue or 0, TextCol.Sat or 0, TextCol.Value or 1)
				end
				if FontOn and FontOn.Enabled and FontDrop then
					pcall(function() label.Font = Enum.Font[FontDrop.Value] end)
				end
				local function rewrite()
					local custom = ""
					if TextList and TextList.ObjectList and #TextList.ObjectList > 0 then
						custom = TextList.ObjectList[math.random(1, #TextList.ObjectList)]
					end
					local hp = isAlive() and tostring(math.floor(lplr.Character:GetAttribute("Health") or 0)) or "0"
					if TextOn and TextOn.Enabled and custom ~= "" then
						label.Text = custom:gsub("<health>", hp)
					else
						label.Text = hp
					end
				end
				rewrite()
				if textCon then textCon:Disconnect() end
				textCon = label:GetPropertyChangedSignal("Text"):Connect(rewrite)
			end
		end
	end

	local function clear()
		if textCon then textCon:Disconnect() end
		textCon = nil
		for _, o in ipairs(made) do
			pcall(function() o:Destroy() end)
		end
		table.clear(made)
		pcall(function()
			local bar = lplr.PlayerGui.hotbar["1"].HotbarHealthbarContainer.HealthbarProgressWrapper["1"]
			bar.BackgroundColor3 = Color3.fromRGB(203, 54, 36)
			bar.Parent.Parent.BackgroundColor3 = Color3.fromRGB(41, 51, 65)
		end)
	end

	Healthbar = createModule("Render", {
		Name = "HealthbarVisuals",
		Tooltip = "Recolor healthbar. Put <health> in custom text.",
		Function = function(on)
			if on then
				Healthbar:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(v)
					if v.Name == "HotbarHealthbarContainer" then
						task.wait(0.05)
						apply()
					end
				end))
				apply()
			else
				clear()
			end
		end
	})

	GuiSync = Healthbar:CreateToggle({Name = "GUI Color Sync", Function = function() if Healthbar.Enabled then clear(); apply() end end})
	MainOn = Healthbar:CreateToggle({Name = "Main Color", Default = true, Function = function() if Healthbar.Enabled then apply() end end})
	GradOn = Healthbar:CreateToggle({Name = "Gradient", Function = function() if Healthbar.Enabled then apply() end end})
	BgOn = Healthbar:CreateToggle({Name = "Background Color", Function = function() if Healthbar.Enabled then apply() end end})
	RoundOn = Healthbar:CreateToggle({Name = "Round", Function = function() if Healthbar.Enabled then clear(); apply() end end})
	StrokeOn = Healthbar:CreateToggle({Name = "Highlight", Function = function() if Healthbar.Enabled then clear(); apply() end end})
	TextOn = Healthbar:CreateToggle({Name = "Custom Text", Function = function() if Healthbar.Enabled then apply() end end})
	FontOn = Healthbar:CreateToggle({Name = "Custom Font"})
	RoundSize = Healthbar:CreateSlider({Name = "Round Size", Min = 1, Max = 16, Default = 4})
	if Healthbar.CreateDropdown then
		local fonts = {"LuckiestGuy", "GothamBold", "SourceSansBold", "Arcade", "Fantasy"}
		FontDrop = Healthbar:CreateDropdown({Name = "Font", List = fonts, Default = "LuckiestGuy"})
	end
	if Healthbar.CreateTextList then
		TextList = Healthbar:CreateTextList({Name = "Text", TempText = "use <health>"})
	end
	if Healthbar.CreateColorSlider then
		MainCol = Healthbar:CreateColorSlider({Name = "Main Color"})
		GradCol = Healthbar:CreateColorSlider({Name = "Secondary Color"})
		BgCol = Healthbar:CreateColorSlider({Name = "Background Color"})
		StrokeCol = Healthbar:CreateColorSlider({Name = "Highlight Color"})
		TextCol = Healthbar:CreateColorSlider({Name = "Text Color"})
	end
end)
