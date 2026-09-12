run(function()
	local Interface
	local HotbarOpenInventory = ({pcall(function()
		return require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	end)})[2]
	local HotbarHealthbar = ({pcall(function()
		return require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
	end)})[2]
	local HotbarApp = ({pcall(function()
		return getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	end)})[2]
	local old, new = {}, {}
	local madeHotbar, madeHealth = {}, {}
	local hotbarTextConnection, healthTextConnection
	local HotbarGuiSync, HotbarSlotColor, HotbarGradient, HotbarRounding, HotbarHighlight, HotbarHideNums
	local HotbarColorA, HotbarColorB, HotbarOutlineColor, HotbarRoundSize
	local HealthGuiSync, HealthMainOn, HealthGradOn, HealthBgOn, HealthRoundOn, HealthStrokeOn, HealthTextOn, HealthFontOn
	local HealthMainCol, HealthGradCol, HealthBgCol, HealthStrokeCol, HealthTextCol, HealthRoundSize, HealthFontDrop, HealthTextList

	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)

	local function modifyconstant(func, ind, val)
		if not func then return end
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) then return end
		new[func][ind] = val

		if Interface.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end

	local function guiColor()
		local ok, hue = pcall(function()
			return vape.GUIColor and vape.GUIColor.Hue or 0.6
		end)
		if not ok then hue = 0.6 end
		return Color3.fromHSV(hue, 1, 1)
	end

	local function isAlive()
		local character = lplr.Character
		local humanoid = character and character:FindFirstChildOfClass('Humanoid')
		return humanoid ~= nil and humanoid.Health > 0
	end

	local function hotbarIcons()
		local icons = ({pcall(function()
			return lplr.PlayerGui.hotbar['1'].ItemsHotbar
		end)})[2]
		return typeof(icons) == 'Instance' and icons or nil
	end

	local function paintHotbar()
		local icons = hotbarIcons()
		if not icons then return end
		for _, slot in ipairs(icons:GetChildren()) do
			local label = ({pcall(function()
				return slot:FindFirstChildWhichIsA('ImageButton'):FindFirstChildWhichIsA('TextLabel')
			end)})[2]
			if typeof(label) ~= 'Instance' then continue end
			local button = label.Parent
			if HotbarGuiSync and HotbarGuiSync.Enabled then
				button.BackgroundColor3 = guiColor()
			elseif HotbarSlotColor and HotbarSlotColor.Enabled and not (HotbarGradient and HotbarGradient.Enabled) then
				local c = HotbarColorA
				button.BackgroundColor3 = c and Color3.fromHSV(c.Hue or 0, c.Sat or 0, c.Value or 1) or guiColor()
			end
			if HotbarGradient and HotbarGradient.Enabled and not (HotbarGuiSync and HotbarGuiSync.Enabled) then
				button.BackgroundColor3 = Color3.new(1, 1, 1)
				if not button:FindFirstChildWhichIsA('UIGradient') then
					local g = Instance.new('UIGradient')
					local a = HotbarColorA and Color3.fromHSV(HotbarColorA.Hue or 0, HotbarColorA.Sat or 0, HotbarColorA.Value or 1) or Color3.fromRGB(80, 160, 255)
					local b = HotbarColorB and Color3.fromHSV(HotbarColorB.Hue or 0.7, HotbarColorB.Sat or 0.8, HotbarColorB.Value or 1) or Color3.fromRGB(180, 80, 255)
					g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b)})
					g.Parent = button
					table.insert(madeHotbar, g)
				end
			end
			if HotbarRounding and HotbarRounding.Enabled and not button:FindFirstChildWhichIsA('UICorner') then
				local c = Instance.new('UICorner')
				c.CornerRadius = UDim.new(0, HotbarRoundSize and HotbarRoundSize.Value or 8)
				c.Parent = button
				table.insert(madeHotbar, c)
			end
			if HotbarHighlight and HotbarHighlight.Enabled and not button:FindFirstChildWhichIsA('UIStroke') then
				local s = Instance.new('UIStroke')
				s.Thickness = 1.3
				s.Color = (HotbarGuiSync and HotbarGuiSync.Enabled) and guiColor()
					or (HotbarOutlineColor and Color3.fromHSV(HotbarOutlineColor.Hue or 0, HotbarOutlineColor.Sat or 0, HotbarOutlineColor.Value or 1))
					or Color3.new(1, 1, 1)
				s.Parent = button
				table.insert(madeHotbar, s)
			end
			if HotbarHideNums and HotbarHideNums.Enabled then
				label.Visible = false
			end
		end
	end

	local function clearHotbar()
		for _, o in ipairs(madeHotbar) do
			pcall(function() o:Destroy() end)
		end
		table.clear(madeHotbar)
		pcall(function()
			local icons = hotbarIcons()
			for _, slot in ipairs(icons and icons:GetChildren() or {}) do
				local btn = slot:FindFirstChildWhichIsA('ImageButton')
				if btn then
					btn.BackgroundColor3 = Color3.fromRGB(29, 36, 46)
					local lab = btn:FindFirstChildWhichIsA('TextLabel')
					if lab then lab.Visible = true end
				end
			end
		end)
	end

	local function applyHealthbar()
		if not Interface or not Interface.Enabled then return end
		local bar = ({pcall(function()
			return lplr.PlayerGui.hotbar['1'].HotbarHealthbarContainer.HealthbarProgressWrapper['1']
		end)})[2]
		if typeof(bar) ~= 'Instance' then return end

		if HealthGuiSync and HealthGuiSync.Enabled then
			bar.BackgroundColor3 = guiColor()
		elseif HealthMainOn and HealthMainOn.Enabled then
			bar.BackgroundColor3 = HealthMainCol and Color3.fromHSV(HealthMainCol.Hue or 0, HealthMainCol.Sat or 0.8, HealthMainCol.Value or 1) or Color3.fromRGB(203, 54, 36)
			if HealthGradOn and HealthGradOn.Enabled then
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
				local g = bar:FindFirstChildWhichIsA('UIGradient') or Instance.new('UIGradient', bar)
				local a = HealthMainCol and Color3.fromHSV(HealthMainCol.Hue or 0, HealthMainCol.Sat or 0.8, HealthMainCol.Value or 1) or Color3.fromRGB(203, 54, 36)
				local b = HealthGradCol and Color3.fromHSV(HealthGradCol.Hue or 0.05, HealthGradCol.Sat or 0.8, HealthGradCol.Value or 1) or Color3.fromRGB(255, 160, 40)
				g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b)})
				table.insert(madeHealth, g)
			end
		end

		local bg = bar.Parent and bar.Parent.Parent
		if typeof(bg) == 'Instance' then
			if HealthBgOn and HealthBgOn.Enabled then
				bg.BackgroundColor3 = HealthBgCol and Color3.fromHSV(HealthBgCol.Hue or 0.6, HealthBgCol.Sat or 0.2, HealthBgCol.Value or 0.2) or Color3.fromRGB(41, 51, 65)
			end
			if HealthStrokeOn and HealthStrokeOn.Enabled and not bg:FindFirstChildWhichIsA('UIStroke') then
				local s = Instance.new('UIStroke')
				s.Thickness = 1.6
				s.Color = HealthStrokeCol and Color3.fromHSV(HealthStrokeCol.Hue or 0, HealthStrokeCol.Sat or 0, HealthStrokeCol.Value or 1) or Color3.new(1, 1, 1)
				s.Parent = bg
				table.insert(madeHealth, s)
			end
			if HealthRoundOn and HealthRoundOn.Enabled then
				for _, f in ipairs(bar.Parent:GetChildren()) do
					if f:IsA('Frame') and not f:FindFirstChildWhichIsA('UICorner') then
						local c = Instance.new('UICorner')
						c.CornerRadius = UDim.new(0, HealthRoundSize and HealthRoundSize.Value or 4)
						c.Parent = f
						table.insert(madeHealth, c)
					end
				end
				if not bg:FindFirstChildWhichIsA('UICorner') then
					local c = Instance.new('UICorner')
					c.CornerRadius = UDim.new(0, HealthRoundSize and HealthRoundSize.Value or 4)
					c.Parent = bg
					table.insert(madeHealth, c)
				end
			end

			local label = bg:FindFirstChild('1')
			if typeof(label) == 'Instance' and label:IsA('TextLabel') then
				if HealthTextCol and HealthTextOn and HealthTextOn.Enabled then
					label.TextColor3 = Color3.fromHSV(HealthTextCol.Hue or 0, HealthTextCol.Sat or 0, HealthTextCol.Value or 1)
				end
				if HealthFontOn and HealthFontOn.Enabled and HealthFontDrop then
					pcall(function() label.Font = Enum.Font[HealthFontDrop.Value] end)
				end
				local function rewrite()
					local custom = ''
					if HealthTextList and HealthTextList.ObjectList and #HealthTextList.ObjectList > 0 then
						custom = HealthTextList.ObjectList[math.random(1, #HealthTextList.ObjectList)]
					end
					local hp = isAlive() and tostring(math.floor(lplr.Character:GetAttribute('Health') or 0)) or '0'
					if HealthTextOn and HealthTextOn.Enabled and custom ~= '' then
						label.Text = custom:gsub('<health>', hp)
					else
						label.Text = hp
					end
				end
				rewrite()
				if healthTextConnection then healthTextConnection:Disconnect() end
				healthTextConnection = label:GetPropertyChangedSignal('Text'):Connect(rewrite)
			end
		end
	end

	local function clearHealthbar()
		if healthTextConnection then healthTextConnection:Disconnect() end
		healthTextConnection = nil
		for _, o in ipairs(madeHealth) do
			pcall(function() o:Destroy() end)
		end
		table.clear(madeHealth)
		pcall(function()
			local bar = lplr.PlayerGui.hotbar['1'].HotbarHealthbarContainer.HealthbarProgressWrapper['1']
			bar.BackgroundColor3 = Color3.fromRGB(203, 54, 36)
			bar.Parent.Parent.BackgroundColor3 = Color3.fromRGB(41, 51, 65)
		end)
	end

	Interface = vape.Categories.Legit:CreateModule({
		Name = 'Interface',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
			if callback then
				Interface:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(v)
					if v.Name == 'hotbar' then
						task.wait(0.05)
						paintHotbar()
					elseif v.Name == 'HotbarHealthbarContainer' then
						task.wait(0.05)
						applyHealthbar()
					end
				end))
				paintHotbar()
				applyHealthbar()
			else
				clearHotbar()
				clearHealthbar()
			end
		end,
		Tooltip = 'Customize bedwars UI, hotbar and healthbar',
		Category = 'Hud'
	})

	if canDebug then
		local fontitems = {'LuckiestGuy'}
		for _, v in Enum.Font:GetEnumItems() do
			if v.Name ~= 'LuckiestGuy' then
				table.insert(fontitems, v.Name)
			end
		end
		Interface:CreateDropdown({
			Name = 'Health Font',
			List = fontitems,
			Function = function(val)
				modifyconstant(HotbarHealthbar and HotbarHealthbar.render, 77, val)
			end
		})
		Interface:CreateColorSlider({
			Name = 'Health Colour',
			Function = function(hue, sat, val)
				modifyconstant(HotbarHealthbar and HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
				if Interface.Enabled then
					local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
					hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
					if hotbar then
						hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					end
				end
			end
		})
		Interface:CreateColorSlider({
			Name = 'Hotbar Colour',
			DefaultOpacity = 0.8,
			Function = function(hue, sat, val, opacity)
				local func = oldinvrender or (HotbarOpenInventory and HotbarOpenInventory.render)
				local render = HotbarApp and debug.getupvalue(HotbarApp, 23)
				render = render and render.render
				modifyconstant(render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
				modifyconstant(render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
				modifyconstant(render, 54, 1 - opacity)
				modifyconstant(render, 55, math.clamp(1.2 - opacity, 0, 1))
				modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
				modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
				modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
			end
		})
	end

	HotbarGuiSync = Interface:CreateToggle({Name = 'Hotbar GUI sync', Function = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end})
	HotbarSlotColor = Interface:CreateToggle({Name = 'Hotbar slot colour', Function = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end})
	HotbarGradient = Interface:CreateToggle({Name = 'Hotbar gradient', Function = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end})
	HotbarRounding = Interface:CreateToggle({Name = 'Hotbar rounding', Function = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end})
	HotbarHighlight = Interface:CreateToggle({Name = 'Hotbar outline', Function = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end})
	HotbarHideNums = Interface:CreateToggle({Name = 'Hotbar no numbers', Function = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end})
	HotbarRoundSize = Interface:CreateSlider({Name = 'Hotbar round radius', Min = 1, Max = 16, Default = 8})
	HotbarColorA = Interface:CreateColorSlider({Name = 'Hotbar colour 1'})
	HotbarColorB = Interface:CreateColorSlider({Name = 'Hotbar gradient 2'})
	HotbarOutlineColor = Interface:CreateColorSlider({Name = 'Hotbar outline colour'})

	HealthGuiSync = Interface:CreateToggle({Name = 'Healthbar GUI sync', Function = function() if Interface.Enabled then clearHealthbar(); applyHealthbar() end end})
	HealthMainOn = Interface:CreateToggle({Name = 'Healthbar main colour', Default = true, Function = function() if Interface.Enabled then applyHealthbar() end end})
	HealthGradOn = Interface:CreateToggle({Name = 'Healthbar gradient', Function = function() if Interface.Enabled then applyHealthbar() end end})
	HealthBgOn = Interface:CreateToggle({Name = 'Healthbar background', Function = function() if Interface.Enabled then applyHealthbar() end end})
	HealthRoundOn = Interface:CreateToggle({Name = 'Healthbar rounding', Function = function() if Interface.Enabled then clearHealthbar(); applyHealthbar() end end})
	HealthStrokeOn = Interface:CreateToggle({Name = 'Healthbar outline', Function = function() if Interface.Enabled then clearHealthbar(); applyHealthbar() end end})
	HealthTextOn = Interface:CreateToggle({Name = 'Healthbar custom text', Function = function() if Interface.Enabled then applyHealthbar() end end})
	HealthFontOn = Interface:CreateToggle({Name = 'Healthbar custom font'})
	HealthRoundSize = Interface:CreateSlider({Name = 'Healthbar round size', Min = 1, Max = 16, Default = 4})
	local fonts = {'LuckiestGuy', 'GothamBold', 'SourceSansBold', 'Arcade', 'Fantasy'}
	HealthFontDrop = Interface:CreateDropdown({Name = 'Healthbar font', List = fonts, Default = 'LuckiestGuy'})
	HealthTextList = Interface:CreateTextList({Name = 'Healthbar text', TempText = 'use <health>'})
	HealthMainCol = Interface:CreateColorSlider({Name = 'Healthbar colour'})
	HealthGradCol = Interface:CreateColorSlider({Name = 'Healthbar secondary'})
	HealthBgCol = Interface:CreateColorSlider({Name = 'Healthbar background colour'})
	HealthStrokeCol = Interface:CreateColorSlider({Name = 'Healthbar outline colour'})
	HealthTextCol = Interface:CreateColorSlider({Name = 'Healthbar text colour'})
end)
