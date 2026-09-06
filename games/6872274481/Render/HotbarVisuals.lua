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
	local SlotColor, GradientOn, Rounding, Highlight, HideNums, GuiSync
	local ColorA, ColorB, RoundSize, HighlightColor

	local function paint()
		local icons = ({pcall(function()
			return lplr.PlayerGui.hotbar["1"].ItemsHotbar
		end)})[2]
		if typeof(icons) ~= "Instance" then return end
		for _, slot in ipairs(icons:GetChildren()) do
			local label = ({pcall(function()
				return slot:FindFirstChildWhichIsA("ImageButton"):FindFirstChildWhichIsA("TextLabel")
			end)})[2]
			if typeof(label) ~= "Instance" then continue end
			local btn = label.Parent
			if SlotColor and SlotColor.Enabled and not (GradientOn and GradientOn.Enabled) then
				local c = ColorA
				btn.BackgroundColor3 = c and Color3.fromHSV(c.Hue or 0, c.Sat or 0, c.Value or 1) or guiColor()
			end
			if GuiSync and GuiSync.Enabled then
				btn.BackgroundColor3 = guiColor()
			end
			if GradientOn and GradientOn.Enabled and not (GuiSync and GuiSync.Enabled) then
				btn.BackgroundColor3 = Color3.new(1, 1, 1)
				if not btn:FindFirstChildWhichIsA("UIGradient") then
					local g = Instance.new("UIGradient")
					local a = ColorA and Color3.fromHSV(ColorA.Hue or 0, ColorA.Sat or 0, ColorA.Value or 1) or Color3.fromRGB(80, 160, 255)
					local b = ColorB and Color3.fromHSV(ColorB.Hue or 0.7, ColorB.Sat or 0.8, ColorB.Value or 1) or Color3.fromRGB(180, 80, 255)
					g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b)})
					g.Parent = btn
					table.insert(made, g)
				end
			end
			if Rounding and Rounding.Enabled and not btn:FindFirstChildWhichIsA("UICorner") then
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, RoundSize and RoundSize.Value or 8)
				c.Parent = btn
				table.insert(made, c)
			end
			if Highlight and Highlight.Enabled and not btn:FindFirstChildWhichIsA("UIStroke") then
				local s = Instance.new("UIStroke")
				s.Thickness = 1.3
				s.Color = (GuiSync and GuiSync.Enabled) and guiColor()
					or (HighlightColor and Color3.fromHSV(HighlightColor.Hue or 0, HighlightColor.Sat or 0, HighlightColor.Value or 1))
					or Color3.new(1, 1, 1)
				s.Parent = btn
				table.insert(made, s)
			end
			if HideNums and HideNums.Enabled then
				label.Visible = false
			end
		end
	end

	local function clear()
		for _, o in ipairs(made) do
			pcall(function() o:Destroy() end)
		end
		table.clear(made)
		pcall(function()
			local icons = lplr.PlayerGui.hotbar["1"].ItemsHotbar
			for _, slot in ipairs(icons:GetChildren()) do
				local btn = slot:FindFirstChildWhichIsA("ImageButton")
				if btn then
					btn.BackgroundColor3 = Color3.fromRGB(29, 36, 46)
					local lab = btn:FindFirstChildWhichIsA("TextLabel")
					if lab then lab.Visible = true end
				end
			end
		end)
	end

	local Hotbar = createModule("Render", {
		Name = "HotbarVisuals",
		Tooltip = "Recolor / round / outline hotbar slots",
		Function = function(on)
			if on then
				Hotbar:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(v)
					if v.Name == "hotbar" then
						task.wait(0.05)
						paint()
					end
				end))
				paint()
			else
				clear()
			end
		end
	})

	GuiSync = Hotbar:CreateToggle({Name = "GUI Color Sync", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	SlotColor = Hotbar:CreateToggle({Name = "Slot Color", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	GradientOn = Hotbar:CreateToggle({Name = "Gradient Slot Color", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	Rounding = Hotbar:CreateToggle({Name = "Rounding", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	Highlight = Hotbar:CreateToggle({Name = "Outline Highlight", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	HideNums = Hotbar:CreateToggle({Name = "No Slot Numbers", Function = function() if Hotbar.Enabled then clear(); paint() end end})
	RoundSize = Hotbar:CreateSlider({Name = "Round Radius", Min = 1, Max = 16, Default = 8})
	if Hotbar.CreateColorSlider then
		ColorA = Hotbar:CreateColorSlider({Name = "Slot / Gradient 1"})
		ColorB = Hotbar:CreateColorSlider({Name = "Gradient 2"})
		HighlightColor = Hotbar:CreateColorSlider({Name = "Outline Color"})
	end
end)
