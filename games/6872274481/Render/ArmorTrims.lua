run(function()
	local ArmourTrims
	local Trim
	local Colour
	local Effect
	local Tier
	local added = {}
	local trims, colours, effects = {}, {}, {}
	local trimvalues, colourvalues, effectvalues = {}, {}, {}

	local function label(value)
		return (tostring(value):gsub('_', ' '):gsub('%a+', function(word)
			return word:sub(1, 1):upper()..word:sub(2):lower()
		end))
	end

	for _, v in bedwars.ArmorTrimType or {} do
		local meta = bedwars.ArmorTrimMeta and bedwars.ArmorTrimMeta[v]
		local name = meta and meta.name or label(v)
		if trimvalues[name] == nil then
			trimvalues[name] = v
			table.insert(trims, name)
		end
	end
	table.sort(trims)

	for i, v in bedwars.ArmorTrimColor or {} do
		local name = label(i)
		if colourvalues[name] == nil then
			colourvalues[name] = v
			table.insert(colours, name)
		end
	end
	table.sort(colours)

	for _, v in bedwars.ArmorTrimEffectType or {} do
		local meta = bedwars.ArmorTrimEffectMeta and bedwars.ArmorTrimEffectMeta[v]
		local name = meta and meta.name or label(v)
		if effectvalues[name] == nil then
			effectvalues[name] = v
			table.insert(effects, name)
		end
	end
	table.sort(effects)

	local slotnames = {[0] = 'helmet', [1] = 'chestplate', [2] = 'boots'}

	local function wornSlots()
		local worn = {}
		for _, v in store.inventory.inventory.armor or {} do
			local itemmeta = typeof(v) == 'table' and bedwars.ItemMeta[v.itemType]
			if itemmeta and itemmeta.armor and slotnames[itemmeta.armor.slot] then
				worn[slotnames[itemmeta.armor.slot]] = true
			end
		end
		return worn
	end

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
		if not ArmourTrims.Enabled or not lplr.Character then return end
		if not bedwars.ArmorTrimController or not bedwars.ArmorTrimUtil or not bedwars.AccessoryUtil then return end

		local trim = trimvalues[Trim.Value]
		local colour = colourvalues[Colour.Value]
		local effect = effectvalues[Effect.Value]
		if not trim or not colour or not effect then return end

		local before = {}
		for _, v in lplr.Character:GetDescendants() do
			before[v] = true
		end

		bedwars.ArmorTrimController:attachArmorTrimEffects(lplr.Character, trim, colour, Tier.Value - 1, effect)

		local colourmeta = bedwars.ArmorTrimColorMeta and bedwars.ArmorTrimColorMeta[colour]
		local worn = wornSlots()
		for _, v in bedwars.ArmorTrimUtil.createArmorTrims(trim, colourmeta and colourmeta.color or Color3.new(1, 1, 1), Tier.Value - 1) do
			local slot
			for piece in worn do
				if table.find(v.Name:split('_'), piece) then
					slot = piece
					break
				end
			end

			if slot then
				bedwars.AccessoryUtil:addAccessory(lplr.Character, v)
			else
				v:Destroy()
			end
		end
		bedwars.WeldTable:weldCharacterAccessories(lplr.Character)

		for _, v in lplr.Character:GetDescendants() do
			if not before[v] then
				table.insert(added, v)
			end
		end
	end

	ArmourTrims = vape.Categories.Render:CreateModule({
		Name = 'ArmourTrims',
		Function = function(callback)
			if callback then
				ArmourTrims:Clean(lplr.CharacterAdded:Connect(function()
					task.wait(1)
					applyTrim()
				end))
				ArmourTrims:Clean(clearTrim)
			end
			applyTrim()
		end,
		Tooltip = 'Puts an armour trim on yourself that only you can see'
	})

	Trim = ArmourTrims:CreateDropdown({
		Name = 'Trim',
		List = trims,
		Function = function()
			if ArmourTrims.Enabled then
				applyTrim()
			end
		end
	})
	Colour = ArmourTrims:CreateDropdown({
		Name = 'Colour',
		List = colours,
		Function = function()
			if ArmourTrims.Enabled then
				applyTrim()
			end
		end
	})
	Effect = ArmourTrims:CreateDropdown({
		Name = 'Effect',
		List = effects,
		Function = function()
			if ArmourTrims.Enabled then
				applyTrim()
			end
		end
	})
	Tier = ArmourTrims:CreateSlider({
		Name = 'Tier',
		Min = 1,
		Max = 7,
		Default = 7,
		Function = function()
			if ArmourTrims.Enabled then
				applyTrim()
			end
		end,
		Suffix = function(val)
			local meta = bedwars.ArmorTrimEffectRankMeta and bedwars.ArmorTrimEffectRankMeta[val - 1]
			return meta and meta.tier and label(meta.tier) or ''
		end,
		Tooltip = 'Higher tiers use the fancier version of the effect'
	})
end)
