run(function()
	local HitAccuracy
	local ShowColor
	local HideUnused
	local sources = {'ProjectileAura', 'ProjectileAimbot', 'SilentAim'}
	local rows = {}
	local holder
	
	local function addRow(name)
		local row = Instance.new('Frame')
		row.BackgroundTransparency = 1
		row.Name = name
		row.Size = UDim2.new(1, 0, 0, 20)
		row.Parent = holder
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(10, 0)
		title.Size = UDim2.new(1, -20, 1, 0)
		title.Text = name
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextSize = 14
		title.TextStrokeColor3 = Color3.new()
		title.TextStrokeTransparency = 0.8
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = row
		local value = title:Clone()
		value.Name = 'Value'
		value.Text = '--'
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.Parent = row
	
		rows[name] = {Object = row, Title = title, Value = value}
	end
	
	local function refresh()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local shown = 0
		for _, v in sources do
			local chance = store.hitchance[v]
			local live = chance and (tick() - chance.Clock) < 2
			local row = rows[v]
			row.Object.Visible = live or not HideUnused.Enabled
	
			if row.Object.Visible then
				row.Object.Position = UDim2.fromOffset(0, 6 + (shown * 20))
				row.Value.Text = live and `{math.round(chance.Value * 100)}%` or '--'
				row.Value.TextColor3 = (live and ShowColor.Enabled) and Color3.fromHSV(chance.Value * 0.33, 0.75, 1) or Color3.new(1, 1, 1)
				shown += 1
			end
		end
	
		rows.Waiting.Object.Visible = shown == 0
		holder.Size = UDim2.fromOffset(190, 12 + (math.max(shown, 1) * 20))
	end
	
	HitAccuracy = vape:CreateOverlay({
		Name = 'Hit Accuracy',
		Icon = getcustomasset('aetherv2/assets/new/targetinfoicon.png'),
		Size = UDim2.fromOffset(18, 12),
		Position = UDim2.fromOffset(11, 14),
		Function = function(callback)
			if callback then
				repeat
					refresh()
					task.wait(0.05)
				until not HitAccuracy.Button or not HitAccuracy.Button.Enabled
			end
		end
	})
	HitAccuracy:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			for _, v in rows do
				v.Title.FontFace = val
				v.Value.FontFace = val
			end
		end
	})
	HideUnused = HitAccuracy:CreateToggle({
		Name = 'Hide unused',
		Function = function()
			if holder then
				refresh()
			end
		end,
		Default = true,
		Tooltip = 'Leaves out a module until it is actually aiming at someone'
	})
	ShowColor = HitAccuracy:CreateToggle({
		Name = 'Color the number',
		Default = true,
		Tooltip = 'Red through green as the chance climbs'
	})
	HitAccuracy:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			if holder then
				holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				holder.BackgroundTransparency = 1 - opacity
			end
		end
	})
	holder = Instance.new('Frame')
	holder.BackgroundColor3 = Color3.new()
	holder.BackgroundTransparency = 0.5
	holder.Size = UDim2.fromOffset(190, 32)
	holder.Parent = HitAccuracy.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = holder
	addBlur(holder)
	for _, v in sources do
		addRow(v)
	end
	addRow('Waiting')
	rows.Waiting.Object.Position = UDim2.fromOffset(0, 6)
	rows.Waiting.Title.Text = 'Hit chance'
	refresh()
	vape:Clean(HitAccuracy.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local newside = HitAccuracy.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
		holder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
		holder.Position = UDim2.fromScale(newside and 1 or 0, 0)
	end))
end)