run(function()
	local ArmorChanger
	local Trim
	local Color
	local Effect
	local Rank
	
	local added = {}
	local trims, colors, effects = {}, {}, {}
	
	for _, trim in bedwars.ArmorTrimType do
		table.insert(trims, trim)
	end
	table.sort(trims)
	
	for _, color in bedwars.ArmorTrimColor do
		table.insert(colors, color)
	end
	table.sort(colors)
	
	for _, effect in bedwars.ArmorTrimEffectType do
		table.insert(effects, effect)
	end
	table.sort(effects)
	
	local function clearTrim()
		for _, v in added do
			if v.Parent then
				v:Destroy()
			end
		end
		table.clear(added)
	end
	
	local function applyTrim()
		clearTrim()
		if not ArmorChanger.Enabled or not lplr.Character then return end
	
		local before = {}
		for _, v in lplr.Character:GetDescendants() do
			before[v] = true
		end
	
		bedwars.ArmorTrimController:attachArmorTrimEffects(lplr.Character, Trim.Value, Color.Value, Rank.Value - 1, Effect.Value)
	
		for _, v in lplr.Character:GetDescendants() do
			if not before[v] then
				table.insert(added, v)
			end
		end
	end
	
	ArmorChanger = vape.Categories.Render:CreateModule({
		Name = 'ArmorTrims',
		Function = function(callback)
			if callback then
				ArmorChanger:Clean(lplr.CharacterAdded:Connect(function()
					task.wait(1)
					applyTrim()
				end))
				ArmorChanger:Clean(clearTrim)
			end
			applyTrim()
		end,
		Tooltip = 'Puts an armor trim on yourself, only you can see it'
	})
	Trim = ArmorChanger:CreateDropdown({
		Name = 'Trim',
		List = trims,
		Function = function()
			if ArmorChanger.Enabled then
				applyTrim()
			end
		end
	})
	Color = ArmorChanger:CreateDropdown({
		Name = 'Color',
		List = colors,
		Function = function()
			if ArmorChanger.Enabled then
				applyTrim()
			end
		end
	})
	Effect = ArmorChanger:CreateDropdown({
		Name = 'Effect',
		List = effects,
		Function = function()
			if ArmorChanger.Enabled then
				applyTrim()
			end
		end
	})
	Rank = ArmorChanger:CreateSlider({
		Name = 'Tier',
		Min = 1,
		Max = 7,
		Default = 7,
		Function = function()
			if ArmorChanger.Enabled then
				applyTrim()
			end
		end,
		Tooltip = 'Higher tiers use the fancier version of the effect, 7 is nightmare'
	})
	
end)