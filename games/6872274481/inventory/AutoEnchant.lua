run(function()
	local category = vape.Categories.Inventory or vape.Categories.Utility or vape.Categories.World
	if not category or type(category.CreateModule) ~= 'function' then
		warn('[AetherV2] AutoEnchant could not find a module category')
		return
	end

	local AutoEnchant, Repair, Desired, MaximumRolls, Reserve, Interval
	local generation = 0
	local enchantNames = {}

	local function normalise(value)
		return tostring(value or ''):lower():gsub('[%s_%-]+', '')
	end

	local function displayName(key, meta)
		return tostring((type(meta) == 'table' and (meta.displayName or meta.name)) or key):gsub('_', ' ')
	end

	if type(bedwars.EnchantMeta) == 'table' then
		for key, meta in pairs(bedwars.EnchantMeta) do
			table.insert(enchantNames, displayName(key, meta))
		end
	end
	if #enchantNames == 0 then
		enchantNames = {'Critical Strike', 'Fire', 'Life Steal', 'Shield Gen', 'Static', 'Updraft', 'Wind'}
	end
	table.sort(enchantNames)

	local function diamonds()
		local item = getItem('diamond')
		return item and tonumber(item.amount) or 0
	end

	local function currentEnchant()
		local state
		pcall(function() state = bedwars.Store:getState() end)
		local value = type(state) == 'table' and state.Bedwars and state.Bedwars.enchant or nil
		value = value or lplr:GetAttribute('Enchant')
		if type(value) == 'table' then value = value.enchant or value.type or value.itemType end
		if value == nil or tostring(value) == '' or tostring(value):lower() == 'none' then return '' end
		return displayName(value, type(bedwars.EnchantMeta) == 'table' and bedwars.EnchantMeta[value] or nil)
	end

	local function hasDesired(value)
		return Desired and normalise(Desired.Value) == normalise(value)
	end

	local function findTable()
		if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then return end
		local nearest, nearestDistance
		for _, object in pairs(store.enchant or {}) do
			if typeof(object) == 'Instance' and object.Parent then
				local ok, position = pcall(function()
					return object:IsA('Model') and object:GetPivot().Position or object.Position
				end)
				if ok and typeof(position) == 'Vector3' then
					local distance = (entitylib.character.RootPart.Position - position).Magnitude
					if not nearestDistance or distance < nearestDistance then nearest, nearestDistance = object, distance end
				end
			end
		end
		return nearest, nearestDistance
	end

	local function request(controllerNames, remoteNames, tableModel)
		local controller = bedwars.EnchantTableController or bedwars.EnchantController
		for _, name in ipairs(controllerNames) do
			if controller and type(controller[name]) == 'function' then
				local ok, result = pcall(controller[name], controller, tableModel)
				if ok and result ~= false then return true end
			end
		end
		for _, name in ipairs(remoteNames) do
			local ok = pcall(function()
				local handler = bedwars.Handler and bedwars.Handler:Get(name)
				if not handler then error('missing remote') end
				handler:Fire('CallServerAsync', tableModel)
			end)
			if ok then return true end
		end
		return false
	end

	AutoEnchant = category:CreateModule({
		Name = 'AutoEnchant',
		Tooltip = 'Rolls a nearby team enchant table until an accepted enchant is obtained.',
		Function = function(enabled)
			generation += 1
			if not enabled then return end
			local token = generation
			local worker = task.spawn(function()
				local rolls, character = 0, lplr.Character
				while AutoEnchant.Enabled and token == generation do
					if lplr.Character ~= character then
						character, rolls = lplr.Character, 0
					end
					local tableModel, distance = findTable()
					if not tableModel or not distance or distance > 18 then
						task.wait(0.25)
						continue
					end
					if hasDesired(currentEnchant()) then
						rolls = 0
						task.wait(0.25)
						continue
					end
					if rolls >= MaximumRolls.Value then
						notif('AutoEnchant', 'Maximum rolls reached without the selected enchant.', 5, 'warning')
						task.defer(function() if AutoEnchant.Enabled and token == generation then AutoEnchant:Toggle() end end)
						break
					end
					local broken = false
					pcall(function() broken = collectionService:HasTag(tableModel, 'broken-enchant-table') end)
					if broken then
						if not Repair.Enabled or diamonds() < Reserve.Value + 8 then task.wait(0.25); continue end
						if not request({'repairEnchantTable', 'repair'}, {'RepairEnchantTable', 'RepairEnchantTableRemote'}, tableModel) then
							task.wait(1)
							continue
						end
						task.wait(math.max(Interval.Value, 0.25))
						continue
					end
					local state
					pcall(function() state = bedwars.Store:getState() end)
					local bedwarsState = type(state) == 'table' and type(state.Bedwars) == 'table' and state.Bedwars or {}
					local gameState = type(state) == 'table' and type(state.Game) == 'table' and state.Game or {}
					local cost = tonumber(bedwarsState.enchantCost or gameState.enchantCost) or 2
					if diamonds() - cost < Reserve.Value then task.wait(0.25); continue end
					local before = currentEnchant()
					if not request({'purchaseEnchant', 'rollEnchant'}, {'PurchaseEnchant', 'RequestEnchant'}, tableModel) then
						task.wait(1)
						continue
					end
					rolls += 1
					local deadline = tick() + 4
					repeat task.wait() until not AutoEnchant.Enabled or token ~= generation or lplr.Character ~= character or currentEnchant() ~= before or tick() >= deadline
					if AutoEnchant.Enabled and token == generation and lplr.Character == character then
						task.wait(Interval.Value)
					end
				end
			end)
			AutoEnchant:Clean(worker)
		end
	})
	Desired = AutoEnchant:CreateDropdown({Name = 'Desired enchant', List = enchantNames, Default = enchantNames[1], Tooltip = 'Stops rolling as soon as this enchant is obtained.'})
	Repair = AutoEnchant:CreateToggle({Name = 'Repair enchant table', Default = true})
	MaximumRolls = AutoEnchant:CreateSlider({Name = 'Maximum rolls', Min = 1, Max = 50, Default = 10})
	Reserve = AutoEnchant:CreateSlider({Name = 'Resource reserve', Min = 0, Max = 32, Default = 0, Suffix = ' diamonds'})
	Interval = AutoEnchant:CreateSlider({Name = 'Request interval', Min = 0.25, Max = 2, Default = 0.6, Decimal = 100, Suffix = 's'})
end)
