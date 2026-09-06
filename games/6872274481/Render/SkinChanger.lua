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
