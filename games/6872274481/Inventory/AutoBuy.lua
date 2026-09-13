run(function()
	local AutoBuy
	local Sword
	local Armor
	local Upgrades
	local TierCheck
	local BedwarsCheck
	local GUI
	local SmartCheck
	local ShopAnywhere
	local OpenShop
	local Custom = {}
	local CustomPost = {}
	local UpgradeToggles = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()
	local purchaseRules = {}
	local rulesPath = 'aetherv2/profiles/autobuy-rules.json'
	local rulesWindow
	local lastShopPrompt, lastShopPromptAt

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

	local function nearestItemShop()
		if not entitylib.isAlive then return nil end
		local root = entitylib.character.RootPart
		if not root then return nil end
		local closest, distance
		for _, entry in store.shop do
			if entry.Shop and entry.RootPart and entry.RootPart.Parent then
				local nextDistance = (entry.RootPart.Position - root.Position).Magnitude
				if not distance or nextDistance < distance then
					closest, distance = entry, nextDistance
				end
			end
		end
		return closest
	end

	local function shopPrompt(entry)
		local root = entry and entry.RootPart
		if not root or not root.Parent then return nil end
		return root:FindFirstChildWhichIsA('ProximityPrompt', true)
			or root.Parent:FindFirstChildWhichIsA('ProximityPrompt', true)
	end

	local function activateShop(entry)
		local prompt = shopPrompt(entry)
		local extender = ((getgenv and getgenv()) or _G).AetherInteractExtender
		if not prompt or type(extender) ~= 'table' or type(extender.Activate) ~= 'function' then
			return false, 'shop prompt unavailable'
		end
		if prompt == lastShopPrompt and tick() - lastShopPromptAt < 0.5 then return true end
		local ok, reason = extender.Activate(prompt)
		if ok then
			lastShopPrompt, lastShopPromptAt = prompt, tick()
		end
		return ok, reason
	end

	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if v.RootPart and v.RootPart.Parent and (v.RootPart.Position - localPosition).Magnitude <= 20 then
					shop = v.Upgrades or v.Shop or nil
					upgrades = upgrades or v.Upgrades
					items = items or v.Shop
					newid = v.Shop and v.Id or newid
				end
			end
		end
		
		
		if not shop and ShopAnywhere and ShopAnywhere.Enabled then
			local entry = nearestItemShop()
			if entry and activateShop(entry) then
				return entry.Upgrades or entry.Shop, entry.Shop ~= nil, entry.Upgrades ~= nil, entry.Shop and entry.Id or nil
			end
		end
		return shop, items, upgrades, newid
	end

	local function canBuy(item, currencytable, amount)
		amount = amount or 1
		if not currencytable[item.currency] then
			local currency = getItem(item.currency)
			currencytable[item.currency] = currency and currency.amount or 0
		end
		if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
		if item.lockedByForge or item.disabled then return false end
		if item.require and item.require.teamUpgrade then
			if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
				return false
			end
		end
		return currencytable[item.currency] >= (item.price * amount)
	end

	local function buyItem(item, currencytable)
		if not id then return end
		if #purchaseRules > 0 and not ruleAllows(item.itemType) then return end
		notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
		bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {
			shopItem = item,
			shopId = id
		}):andThen(function(suc)
			if suc then
				bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
				bedwars.Store:dispatch({
					type = 'BedwarsAddItemPurchased',
					itemType = item.itemType
				})
				bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
			end
		end)
		currencytable[item.currency] -= item.price
	end

	local function buyUpgrade(upgradeType, currencytable)
		if not Upgrades.Enabled then return end
		local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
		local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
		local currentTier = (currentUpgrades[upgradeType] or 0) + 1
		local bought = false

		for i = currentTier, #upgrade.tiers do
			local tier = upgrade.tiers[i]
			if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end

			if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
				notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
				bedwars.Handler:Get('RequestPurchaseTeamUpgrade'):Fire('CallServerAsync', upgradeType)
				currencytable.diamond -= tier.cost
				bought = true
			else
				break
			end
		end

		return bought
	end

	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge

		for i = tool, #tools do
			local v = bedwars.Shop.getShopItem(tools[i], lplr)
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
			if callback then
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end

				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					
					
					
					npctick = math.min(npctick, tick())
				end))

				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled then
						if not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then
							npc = nil
						end
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
	ShopAnywhere = AutoBuy:CreateToggle({
		Name = 'Shop anywhere',
		Tooltip = 'Uses InteractExtender to open the nearest item shop before buying'
	})
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
		Name = 'Buy Armor',
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
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for _, v in UpgradeToggles do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	local count = 0
	for i, v in bedwars.TeamUpgradeMeta do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades then return end
					if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
					return buyUpgrade(i, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (i == 'ARMOR' or i == 'DAMAGE')
		}))
		count += 1
	end
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
		Tooltip = 'Buys iron armor before iron axe'
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

						local v = bedwars.Shop.getShopItem(tab[2], lplr)
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
	local shopApi = {activateShop = activateShop, nearestItemShop = nearestItemShop}
	shared.AetherShopRuntime = shopApi
	vape:Clean(function() if shared.AetherShopRuntime == shopApi then shared.AetherShopRuntime = nil end end)

end)
