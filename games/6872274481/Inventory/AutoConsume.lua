run(function()
	local AutoConsume
	local Health
	local HealthItems
	local Shields
	local SpeedPotions
	local Mushrooms
	local OtherConsumables

	local HEALTH_PRIORITY = {'golden_apple', 'big_apple', 'orange', 'apple'}
	local consumeCooldown = {}
	local CONSUME_COOLDOWN = 0.4

	local function itemMeta(id)
		return bedwars.ItemMeta and bedwars.ItemMeta[id] or nil
	end

	local function isConsumable(id)
		local meta = itemMeta(id)
		return meta and type(meta.consumable) == 'table' or false
	end

	-- Items are discovered from ItemMeta instead of a hardcoded list, so every BedWars
	-- consumable (including SingleMushroom-style items) is recognised as it is added.
	local function classOf(id)
		if not isConsumable(id) then return nil end
		local lower = id:lower()
		local consumable = itemMeta(id).consumable or {}
		local effect = consumable.statusEffect and tostring(consumable.statusEffect.statusEffectType or ''):lower() or ''
		if lower:find('shield', 1, true) or effect:find('shield') then return 'shield' end
		if lower:find('mushroom', 1, true) then return 'mushroom' end
		if lower:find('speed', 1, true) or effect:find('speed') then return 'speed' end
		if lower:find('apple', 1, true) or lower:find('orange', 1, true) or lower:find('heal', 1, true) or consumable.requiresMissingHealth or effect:find('health') then return 'health' end
		return 'other'
	end

	local function inventoryItems()
		local inventory = store.inventory and store.inventory.inventory
		return inventory and inventory.items or {}
	end

	local function pick(predicate)
		local chosen
		for _, item in inventoryItems() do
			if item and item.itemType and predicate(item.itemType) then
				chosen = chosen or item
			end
		end
		return chosen
	end

	local function best(class)
		if class == 'health' then
			for _, name in HEALTH_PRIORITY do
				local found = pick(function(id) return id == name end)
				if found then return found end
			end
			return pick(function(id) return classOf(id) == 'health' end)
		end
		return pick(function(id) return classOf(id) == class end)
	end

	local function use(item, key)
		if not item or not item.tool then return false end
		local now = os.clock()
		key = key or item.itemType
		if (consumeCooldown[key] or 0) > now then return false end
		consumeCooldown[key] = now + CONSUME_COOLDOWN
		return pcall(function()
			bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = item.tool})
		end)
	end

	local function consumeClass(class)
		return use(best(class), class)
	end

	local function healthPercent(character)
		local health = tonumber(character:GetAttribute('Health')) or 0
		local maxHealth = tonumber(character:GetAttribute('MaxHealth')) or 100
		return maxHealth > 0 and (health / maxHealth) * 100 or 100
	end

	local function check(attribute)
		if not entitylib.isAlive or not lplr.Character then return end
		local character = lplr.Character

		if not attribute or attribute:find('Health') then
			if healthPercent(character) <= Health.Value then
				local used = HealthItems.Enabled and consumeClass('health')
				if not used and Mushrooms.Enabled then
					consumeClass('mushroom')
				end
			end
		end

		if Shields.Enabled and (not attribute or attribute:find('Shield')) then
			if (tonumber(character:GetAttribute('Shield_POTION')) or 0) == 0 then
				consumeClass('shield')
			end
		end

		if SpeedPotions.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
			if not character:GetAttribute('StatusEffect_speed') then
				consumeClass('speed')
			end
		end

		if OtherConsumables.Enabled then
			-- Only auto-use "other" consumables whose status effect is currently missing,
			-- so utility items with downsides are never wasted blindly.
			for _, item in inventoryItems() do
				local id = item and item.itemType
				local meta = id and itemMeta(id)
				local effect = meta and meta.consumable and meta.consumable.statusEffect
				local effectType = effect and effect.statusEffectType
				if effectType and classOf(id) == 'other' and not character:GetAttribute('StatusEffect_'..tostring(effectType)) then
					use(item, id)
				end
			end
		end
	end

	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(check))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
						check(attribute)
					end
				end))
				check()
			end
		end,
		Tooltip = 'Automatically consumes the right BedWars healing, shield, speed and utility items'
	})
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = '%'
	})
	HealthItems = AutoConsume:CreateToggle({
		Name = 'Health items',
		Default = true,
		Tooltip = 'Uses apples, oranges and similar healing items below the threshold'
	})
	Mushrooms = AutoConsume:CreateToggle({
		Name = 'Mushrooms',
		Default = false,
		Tooltip = 'Consumes mushroom items as a healing fallback (for example SingleMushroom)'
	})
	Shields = AutoConsume:CreateToggle({
		Name = 'Shield Potions',
		Default = true
	})
	SpeedPotions = AutoConsume:CreateToggle({
		Name = 'Speed Potions',
		Default = true
	})
	OtherConsumables = AutoConsume:CreateToggle({
		Name = 'Other consumables',
		Default = false,
		Tooltip = 'Uses other status-effect consumables when their effect is missing'
	})
end)
