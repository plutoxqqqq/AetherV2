run(function()
    local AutoConsume
    local Health
    local SpeedPotion
    local Apple
    local ShieldPotion

    local function consumeCheck(attribute)
        if entitylib.isAlive then
            if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
                local speedpotion = getItem('speed_potion')
                if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
                    for _ = 1, 4 do
                        if bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = speedpotion.tool}) then break end
                    end
                end
            end

            if Apple.Enabled and (not attribute or attribute:find('Health')) then
                if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
                    local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')

                    if apple then
                        bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
                            item = apple.tool
                        })
                    end
                end
            end

            if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
                if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
                    local shield = getItem('big_shield') or getItem('mini_shield')

                    if shield then
                        bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
                            item = shield.tool
                        })
                    end
                end
            end
        end
    end

    AutoConsume = vape.Categories.Inventory:CreateModule({
        Name = 'AutoConsume',
        Function = function(callback)
            if callback then
                AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
                AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
                    if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
                        consumeCheck(attribute)
                    end
                end))
                consumeCheck()
            end
        end,
        Tooltip = 'Automatically heals for you when health or shield is under threshold'
    })
    Health = AutoConsume:CreateSlider({
        Name = 'Health Percent',
        Min = 1,
        Max = 99,
        Default = 70,
        Suffix = '%'
    })
    SpeedPotion = AutoConsume:CreateToggle({
        Name = 'Speed Potions',
        Default = true
    })
    Apple = AutoConsume:CreateToggle({
        Name = 'Apple',
        Default = true
    })
    ShieldPotion = AutoConsume:CreateToggle({
        Name = 'Shield Potions',
        Default = true
    })
end)

run(function()
	local category = vape.Categories.Inventory or vape.Categories.Utility or vape.Categories.World
	if not category or type(category.CreateModule) ~= 'function' then
		warn('[AetherV2] AutoEnchant could not find a module category')
		return
	end
	if vape.Modules and vape.Modules.AutoEnchant then
		pcall(function() vape.Modules.AutoEnchant:Toggle() end)
	end

	local AutoEnchant, Desired, Repair, NotifyRolls, MaximumRolls, Reserve, Interval, Range
	local generation = 0

	local FALLBACK = {
		'Any',
		'Critical Strike',
		'Fire',
		'Life Steal',
		'Shield Gen',
		'Static',
		'Updraft',
		'Wind'
	}

	local function normalise(value)
		return tostring(value or ''):lower():gsub('[^%w]+', '')
	end

	local function pretty(key, meta)
		if type(meta) == 'table' then
			return tostring(meta.displayName or meta.name or key):gsub('_', ' ')
		end
		return tostring(key):gsub('_', ' ')
	end

	local function enchantList()
		local names, seen = {'Any'}, {any = true}
		if type(bedwars.EnchantMeta) == 'table' then
			for key, meta in pairs(bedwars.EnchantMeta) do
				local label = pretty(key, meta)
				local id = normalise(label)
				if id ~= '' and not seen[id] then
					seen[id] = true
					table.insert(names, label)
				end
			end
		end
		if #names == 1 then
			for _, name in ipairs(FALLBACK) do
				if not seen[normalise(name)] then
					table.insert(names, name)
				end
			end
		end
		table.sort(names, function(a, b)
			if a == 'Any' then return true end
			if b == 'Any' then return false end
			return a < b
		end)
		return names
	end

	local function diamonds()
		local item = getItem('diamond')
		return item and tonumber(item.amount) or 0
	end

	local function readEnchant()
		local raw
		pcall(function()
			local state = bedwars.Store and bedwars.Store:getState()
			raw = state and state.Bedwars and state.Bedwars.enchant
		end)
		if raw == nil then
			raw = lplr:GetAttribute('Enchant') or (lplr.Character and lplr.Character:GetAttribute('Enchant'))
		end
		if type(raw) == 'table' then
			raw = raw.enchant or raw.type or raw.itemType or raw.id or raw.name
		end
		if raw == nil or tostring(raw) == '' or normalise(raw) == 'none' then
			return ''
		end
		local meta = type(bedwars.EnchantMeta) == 'table' and (bedwars.EnchantMeta[raw] or bedwars.EnchantMeta[tostring(raw)])
		return pretty(raw, meta)
	end

	local function matchesDesired(current)
		if not Desired or Desired.Value == 'Any' then
			return current ~= ''
		end
		return normalise(current) == normalise(Desired.Value)
	end

	local function tablePosition(object)
		if typeof(object) ~= 'Instance' or not object.Parent then return end
		local ok, pos = pcall(function()
			if object:IsA('Model') then
				return object:GetPivot().Position
			end
			return object.Position
		end)
		if ok and typeof(pos) == 'Vector3' then
			return pos
		end
	end

	local function nearbyTable()
		if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then
			return
		end
		local origin = entitylib.character.RootPart.Position
		local best, bestDist
		local seen = {}
		local function consider(object)
			if seen[object] then return end
			seen[object] = true
			local pos = tablePosition(object)
			if not pos then return end
			local dist = (origin - pos).Magnitude
			if dist <= (Range and Range.Value or 18) and (not bestDist or dist < bestDist) then
				best, bestDist = object, dist
			end
		end
		for _, object in pairs(store.enchant or {}) do
			consider(object)
		end
		for _, tag in ipairs({'enchant-table', 'broken-enchant-table'}) do
			for _, object in ipairs(collectionService:GetTagged(tag)) do
				consider(object)
			end
		end
		return best, bestDist
	end

	local function invokeRemote(name, tableModel)
		local handler = bedwars.Handler and bedwars.Handler:Get(name)
		if handler then
			for _, method in ipairs({'CallServerAsync', 'SendToServer', 'FireServer', 'InvokeServer'}) do
				local ok, res = pcall(handler.Fire, handler, method, tableModel)
				if ok and res ~= false then
					return true
				end
			end
		end
		local ok, remote = pcall(function()
			return bedwars.Client:Get(name)
		end)
		if ok and remote then
			for _, method in ipairs({'CallServerAsync', 'SendToServer', 'Fire', 'Invoke'}) do
				if type(remote[method]) == 'function' then
					local sent, res = pcall(remote[method], remote, tableModel)
					if sent and res ~= false then
						return true
					end
				end
			end
			if remote.instance then
				local inst = remote.instance
				if inst:IsA('RemoteEvent') then
					local sent = pcall(function() inst:FireServer(tableModel) end)
					if sent then return true end
				elseif inst:IsA('RemoteFunction') then
					local sent = pcall(function() inst:InvokeServer(tableModel) end)
					if sent then return true end
				end
			end
		end
		return false
	end

	local function callController(names, tableModel)
		local controllers = {
			bedwars.EnchantTableController,
			bedwars.EnchantController,
			bedwars.TeamEnchantController
		}
		for _, controller in ipairs(controllers) do
			if type(controller) == 'table' then
				for _, name in ipairs(names) do
					if type(controller[name]) == 'function' then
						local ok, res = pcall(controller[name], controller, tableModel)
						if ok and res ~= false then
							return true
						end
					end
				end
			end
		end
		return false
	end

	local function roll(tableModel)
		if callController({'purchaseEnchant', 'rollEnchant', 'enchant', 'purchase'}, tableModel) then
			return true
		end
		for _, name in ipairs({
			'PurchaseEnchant',
			'RequestEnchant',
			'EnchantTablePurchase',
			'Enchant/purchase',
			'EnchantTable/purchase'
		}) do
			if invokeRemote(name, tableModel) then
				return true
			end
		end
		return false
	end

	local function repairTable(tableModel)
		if callController({'repairEnchantTable', 'repair'}, tableModel) then
			return true
		end
		for _, name in ipairs({'RepairEnchantTable', 'RepairEnchantTableRemote', 'EnchantTableRepair', 'Enchant/repair'}) do
			if invokeRemote(name, tableModel) then
				return true
			end
		end
		return false
	end

	local function enchantCost()
		local cost = 2
		pcall(function()
			local state = bedwars.Store and bedwars.Store:getState()
			local bedwarsState = state and state.Bedwars or {}
			local gameState = state and state.Game or {}
			cost = tonumber(bedwarsState.enchantCost or gameState.enchantCost) or 2
		end)
		return cost
	end

	AutoEnchant = category:CreateModule({
		Name = 'AutoEnchant',
		Tooltip = 'Walks the nearest team enchant table until the selected enchant lands.',
		Function = function(enabled)
			generation += 1
			local token = generation
			if not enabled then
				return
			end
			local worker = task.spawn(function()
				local rolls = 0
				local character = lplr.Character
				while AutoEnchant.Enabled and token == generation do
					if lplr.Character ~= character then
						character = lplr.Character
						rolls = 0
					end

					local current = readEnchant()
					if matchesDesired(current) then
						if NotifyRolls and NotifyRolls.Enabled and current ~= '' then
							notif('AutoEnchant', 'Have '..current, 3)
						end
						task.wait(0.35)
						continue
					end

					local tableModel = nearbyTable()
					if not tableModel then
						task.wait(0.2)
						continue
					end

					local broken = false
					pcall(function()
						broken = collectionService:HasTag(tableModel, 'broken-enchant-table')
					end)
					if broken then
						if not Repair.Enabled or diamonds() < Reserve.Value + 8 then
							task.wait(0.3)
							continue
						end
						if not repairTable(tableModel) then
							task.wait(0.8)
							continue
						end
						task.wait(math.max(Interval.Value, 0.2))
						continue
					end

					if rolls >= MaximumRolls.Value then
						notif('AutoEnchant', 'Hit the roll cap without '..tostring(Desired.Value)..'.', 5, 'warning')
						task.defer(function()
							if AutoEnchant.Enabled and token == generation then
								AutoEnchant:Toggle()
							end
						end)
						break
					end

					local cost = enchantCost()
					if diamonds() - cost < Reserve.Value then
						task.wait(0.25)
						continue
					end

					local before = current
					if not roll(tableModel) then
						task.wait(0.8)
						continue
					end
					rolls += 1
					if NotifyRolls and NotifyRolls.Enabled then
						notif('AutoEnchant', 'Roll '..rolls..'/'..MaximumRolls.Value, 1.5)
					end

					local deadline = tick() + 4
					repeat
						task.wait(0.05)
					until not AutoEnchant.Enabled or token ~= generation or readEnchant() ~= before or tick() >= deadline

					if AutoEnchant.Enabled and token == generation then
						task.wait(Interval.Value)
					end
				end
			end)
			AutoEnchant:Clean(worker)
		end
	})

	Desired = AutoEnchant:CreateDropdown({
		Name = 'Desired enchant',
		List = enchantList(),
		Default = 'Any',
		Tooltip = 'Any = stop once an enchant exists. Otherwise keep rolling until this name matches.'
	})
	Repair = AutoEnchant:CreateToggle({Name = 'Repair enchant table', Default = true})
	NotifyRolls = AutoEnchant:CreateToggle({Name = 'Notify rolls', Default = false})
	MaximumRolls = AutoEnchant:CreateSlider({Name = 'Maximum rolls', Min = 1, Max = 50, Default = 10})
	Reserve = AutoEnchant:CreateSlider({Name = 'Resource reserve', Min = 0, Max = 32, Default = 0, Suffix = ' diamonds'})
	Interval = AutoEnchant:CreateSlider({Name = 'Request interval', Min = 0.2, Max = 2, Default = 0.55, Decimal = 100, Suffix = 's'})
	Range = AutoEnchant:CreateSlider({Name = 'Table range', Min = 6, Max = 28, Default = 18, Suffix = ' studs'})
end)
