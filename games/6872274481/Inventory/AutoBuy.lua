run(function()
	local util = vape.Libraries.bedwarsutil

	local AutoBuy
	local Sword
	local Armor
	local TierCheck
	local BedwarsCheck
	local GUI
	local SmartCheck
	local OpenShop
	local Custom = {}
	local CustomPost = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()
	local purchaseRules = {}
	local rulesPath = 'aetherv2/profiles/autobuy-rules.json'
	local rulesWindow

	local swords = {
		'wood_sword',
		'stone_sword',
		'iron_sword',
		'diamond_sword',
		'emerald_sword'
	}

	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}

	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe'
	}

	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe'
	}

	local function ruleAllows(itemType)
		local matched = false
		for _, rule in purchaseRules do
			if rule.Buy == itemType then
				matched = true
				local owned = getItem(rule.Condition) ~= nil
				if (rule.Operator == 'is owned' and owned) or (rule.Operator == 'is not owned' and not owned) then return true end
			end
		end
		return not matched
	end

	-- The shopkeeper only counts while it is within the shared 20 studs util.Shop uses, so a
	-- purchase can never be sent to a shop the player is nowhere near.
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		local entry = util.Shop.Nearby()
		if entry then
			shop = entry.Upgrades or entry.Shop or nil
			items = entry.Shop
			upgrades = entry.Upgrades
			newid = entry.Shop and entry.Id or nil
		end
		return shop, items, upgrades, newid
	end

	local function canBuy(item, currencytable, amount)
		return util.Shop.CanBuy(item, currencytable, amount)
	end

	local function buyItem(item, currencytable)
		if not id then return end
		if #purchaseRules > 0 and not ruleAllows(item.itemType) then return end
		util.Shop.Purchase(item, id, currencytable, {Label = 'AutoBuy'})
	end

	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge

		for i = tool, #tools do
			local v = util.Shop.Item(tools[i])
			if canBuy(v, currencytable) then
				if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
					if Armor.Enabled then
						local currentarmor = store.inventory.inventory.armor[2]
						currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
						if (table.find(armors, currentarmor) or 3) < 3 then break end
					end
					if Sword.Enabled then
						if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
					end
				end
				bought = true
				buyable = v
			end
			if TierCheck.Enabled and v.nextTier then break end
		end

		if buyable then
			buyItem(buyable, currencytable)
		end

		return bought
	end

	local function saveRules()
		writefile(rulesPath, httpService:JSONEncode(purchaseRules))
	end

	local function openPreferences()
		if rulesWindow then rulesWindow:Destroy() end
		local root = vape.gui:FindFirstChild('ScaledGui') or vape.gui
		rulesWindow = Instance.new('Frame')
		rulesWindow.Name, rulesWindow.Size, rulesWindow.Position = 'PurchasePreferences', UDim2.fromOffset(460, 310), UDim2.new(0.5, -230, 0.5, -155)
		rulesWindow.BackgroundColor3, rulesWindow.Parent = uipallet.Main, root
		Instance.new('UICorner', rulesWindow).CornerRadius = UDim.new(0, 6)
		local title = Instance.new('TextLabel')
		title.Size, title.Position, title.BackgroundTransparency = UDim2.new(1, -60, 0, 38), UDim2.fromOffset(14, 0), 1
		title.Text, title.TextColor3, title.TextSize, title.TextXAlignment, title.FontFace, title.Parent = 'Purchase preferences', uipallet.Text, 14, Enum.TextXAlignment.Left, uipallet.FontSemiBold, rulesWindow
		local close = Instance.new('TextButton')
		close.Size, close.Position, close.BackgroundTransparency, close.Text, close.TextColor3, close.Parent = UDim2.fromOffset(34, 34), UDim2.new(1, -38, 0, 2), 1, '×', uipallet.Text, rulesWindow
		close.MouseButton1Click:Connect(function() rulesWindow:Destroy(); rulesWindow = nil end)
		local items = {'arrow', 'wool_white', 'fireball', 'telepearl', 'tnt'}
		local conditions = {'wood_axe', 'stone_axe', 'wood_pickaxe', 'iron_sword', 'leather_chestplate'}
		local operators = {'is owned', 'is not owned'}
		local draft = {Buy = items[1], Condition = conditions[1], Operator = operators[1]}
		local function token(x, width, values, key, prefix)
			local button = Instance.new('TextButton')
			button.Size, button.Position = UDim2.fromOffset(width, 28), UDim2.fromOffset(x, 46)
			button.BackgroundColor3, button.TextColor3, button.TextSize, button.FontFace, button.Parent = color.Light(uipallet.Main, 0.05), uipallet.Text, 11, uipallet.Font, rulesWindow
			Instance.new('UICorner', button).CornerRadius = UDim.new(0, 5)
			local index = 1
			local function update() button.Text = prefix..values[index]; draft[key] = values[index] end
			button.MouseButton1Click:Connect(function() index = index % #values + 1; update() end)
			update(); return button
		end
		token(14, 115, items, 'Buy', 'Buy '); token(137, 145, conditions, 'Condition', 'if '); token(290, 112, operators, 'Operator', '')
		local add = Instance.new('TextButton')
		add.Size, add.Position, add.BackgroundColor3, add.Text, add.TextColor3, add.Parent = UDim2.fromOffset(34, 28), UDim2.fromOffset(410, 46), Color3.fromRGB(120, 80, 180), '+', Color3.new(1, 1, 1), rulesWindow
		Instance.new('UICorner', add).CornerRadius = UDim.new(0, 5)
		local list = Instance.new('ScrollingFrame')
		list.Size, list.Position, list.BackgroundTransparency, list.ScrollBarThickness, list.Parent = UDim2.new(1, -28, 1, -94), UDim2.fromOffset(14, 86), 1, 2, rulesWindow
		local layout = Instance.new('UIListLayout'); layout.Padding, layout.Parent = UDim.new(0, 5), list
		local function render()
			for _, child in list:GetChildren() do if child:IsA('Frame') then child:Destroy() end end
			for index, rule in purchaseRules do
				local row = Instance.new('Frame'); row.Size, row.BackgroundColor3, row.Parent = UDim2.new(1, -4, 0, 34), color.Light(uipallet.Main, 0.03), list
				Instance.new('UICorner', row).CornerRadius = UDim.new(0, 5)
				local label = Instance.new('TextLabel'); label.Size, label.Position, label.BackgroundTransparency, label.Text = UDim2.new(1, -70, 1, 0), UDim2.fromOffset(9, 0), 1, 'Only buy '..rule.Buy..' if '..rule.Condition..' '..rule.Operator
				label.TextColor3, label.TextSize, label.TextXAlignment, label.FontFace, label.Parent = uipallet.Text, 11, Enum.TextXAlignment.Left, uipallet.Font, row
				for _, action in {{'↑', -58, function() if index > 1 then purchaseRules[index], purchaseRules[index - 1] = purchaseRules[index - 1], purchaseRules[index] end end}, {'×', -30, function() table.remove(purchaseRules, index) end}} do
					local button = Instance.new('TextButton'); button.Size, button.Position, button.BackgroundTransparency, button.Text, button.TextColor3, button.Parent = UDim2.fromOffset(26, 30), UDim2.new(1, action[2], 0, 2), 1, action[1], uipallet.Text, row
					button.MouseButton1Click:Connect(function() action[3](); saveRules(); render() end)
				end
			end
			list.CanvasSize = UDim2.fromOffset(0, #purchaseRules * 39)
		end
		add.MouseButton1Click:Connect(function()
			for _, rule in purchaseRules do if rule.Buy == draft.Buy and rule.Condition == draft.Condition and rule.Operator ~= draft.Operator then notif('AutoBuy', 'Contradictory rule', 4, 'alert'); return end end
			table.insert(purchaseRules, table.clone(draft)); saveRules(); render()
		end)
		render()
	end

	if isfile(rulesPath) then
		pcall(function()
			local decoded = httpService:JSONDecode(readfile(rulesPath))
			if type(decoded) ~= 'table' then return end
			local valid = {}
			for _, rule in decoded do
				if type(rule) == 'table' and type(rule.Buy) == 'string' and type(rule.Condition) == 'string'
					and table.find({'is owned', 'is not owned'}, rule.Operator) then table.insert(valid, rule) end
			end
			purchaseRules = valid
		end)
	end

	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then					util.Queue.Await()
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end

				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					
					
					
					npctick = math.min(npctick, tick())
				end))

				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled and not util.Shop.BuyScreenOpen() then
						npc = nil
					end

					if npc and lastupgrades ~= upgrades then
						npctick = tick()
						lastupgrades = upgrades
					end

					if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
						local currencytable = {}
						local waitcheck
						for _, tab in Callbacks do
							for _, callback in tab do
								if callback(currencytable, shop, upgrades) then
									waitcheck = true
								end
							end
						end
						
						
						
						
						npctick = tick() + (waitcheck and 0.4 or 0.5)
					end

					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				npctick = tick()
				if rulesWindow then rulesWindow:Destroy(); rulesWindow = nil end
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})

	AutoBuy:CreateButton({Name = 'Purchase preferences', Function = openPreferences})
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			npctick = tick()
			Functions[2] = callback and function(currencytable, shop)
				if not shop then return end

				if store.equippedKit == 'dasher' then
					swords = {
						[1] = 'wood_dao',
						[2] = 'stone_dao',
						[3] = 'iron_dao',
						[4] = 'diamond_dao',
						[5] = 'emerald_dao'
					}
				elseif store.equippedKit == 'ice_queen' then
					swords[5] = 'ice_sword'
				elseif store.equippedKit == 'ember' then
					swords[5] = 'infernal_saber'
				elseif store.equippedKit == 'lumen' then
					swords[5] = 'light_sword'
				end

				return buyTool(store.tools.sword, swords, currencytable)
			end or nil
		end
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armour',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
				currentarmor = currentarmor and currentarmor.itemType or 'none'
				return buyTool({itemType = currentarmor}, armors, currencytable)
			end or nil
		end,
		Default = true
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Axe',
		Function = function(callback)
			npctick = tick()
			Functions[3] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
			end or nil
		end
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			npctick = tick()
			Functions[4] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.stone, pickaxes, currencytable)
			end or nil
		end
	})
	TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Function = function()
			if AutoBuy.Enabled then
				AutoBuy:Toggle()
				AutoBuy:Toggle()
			end
		end,
		Default = true
	})
	GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Buys iron armour before iron axe'
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local ind = tonumber(tab[1])
				if ind then
					(tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
						if not shop then return end

						local v = util.Shop.Item(tab[2])
						if v then
							local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
							item = (item and tonumber(tab[3]) - item.amount or tonumber(tab[3])) // v.amount
							if item > 0 and canBuy(v, currencytable, item) then
								for _ = 1, item do
									buyItem(v, currencytable)
								end
								return true
							end
						end
					end
				end
			end
		end
	})
end)
