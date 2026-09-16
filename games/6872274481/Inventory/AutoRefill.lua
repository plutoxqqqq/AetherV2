run(function()
	local util = vape.Libraries.bedwarsutil

	local AutoRefill
	local Whitelist
	local Fighting

	-- Buys go through util.Shop, which is the same remote and the same currency bookkeeping
	-- AutoBuy uses, so a refill spends exactly like a manual shop purchase would.
	local SLIDER_MAX = 256

	local sliders = {}
	local order = {}
	local active = {}

	-- Sensible starting thresholds; the double slider under each whitelist entry owns them
	-- from there on.
	local defaults = {
		arrow = {Min = 16, Target = 32},
		wool = {Min = 16, Target = 64},
	}
	local fallback = {Min = 16, Target = 32}

	local function matchesFamily(itemType, family)
		return util.Families.Matches(itemType, family)
	end

	local function countFamily(family)
		return util.Inventory.Total(function(itemType)
			return matchesFamily(itemType, family)
		end)
	end

	-- A purchase is reserved the moment it is sent and stays reserved until the store catches up
	-- with it. Without that, a pass that started again before the inventory sync landed read the
	-- pre-purchase total, worked out the same shortfall a second time and bought it again, which
	-- is what made a refill overshoot. The reservation is dropped as soon as the observed total
	-- reaches what was expected, or after a timeout in case the purchase never went through.
	local RESERVATION_TIMEOUT = 3
	local reserved = {}

	local function reserveFamily(family, units)
		local record = reserved[family]
		if record then
			record.Units += units
			return
		end
		reserved[family] = {Baseline = countFamily(family), Units = units, Clock = os.clock()}
	end

	-- The authoritative count: what the inventory shows, plus anything bought but not yet synced.
	local function heldFamily(family)
		local observed = countFamily(family)
		local record = reserved[family]
		if not record then return observed end

		if observed >= record.Baseline + record.Units or os.clock() - record.Clock > RESERVATION_TIMEOUT then
			reserved[family] = nil
			return observed
		end
		return math.max(observed, record.Baseline + record.Units)
	end

	-- The shop only ever sells the neutral wool entry; the server hands back the wool of
	-- your own team, exactly like the manual shop does.
	local function purchaseType(family)
		return util.Families.ShopType(family)
	end

	local function refillFamily(family, target, shopId, currencytable)
		local item = util.Shop.Item(purchaseType(family))
		if not item then return false end

		local amount = math.max(tonumber(item.amount) or 1, 1)
		local price = math.max(tonumber(item.price) or 0, 0)
		local current = heldFamily(family)
		local needed = math.max(target - current, 0)
		if needed <= 0 then return false end

		-- The fewest bundles that still reach the target. A purchase hands over `amount` items, so
		-- rounding up is what reaches it, and it can never overshoot by more than one bundle.
		local purchases = math.ceil(needed / amount)

		-- Stack caps first, then whatever the currency on hand can actually pay for.
		local capacity = util.Inventory.StackCap(purchaseType(family))
		if capacity then
			purchases = math.min(purchases, math.max(math.ceil((capacity - current) / amount), 0))
		end
		if price > 0 then
			local wallet = currencytable[item.currency]
			if not wallet then
				wallet = util.Inventory.Amount(item.currency)
				currencytable[item.currency] = wallet
			end
			purchases = math.min(purchases, math.floor(wallet / price))
		end
		if purchases <= 0 or not util.Shop.CanBuy(item, currencytable, purchases) then return false end

		-- Spending only what is available is deliberate: a partial refill beats standing at
		-- the shop with an unreachable target.
		for _ = 1, purchases do
			util.Shop.Purchase(item, shopId, currencytable, {Label = 'AutoRefill'})
		end
		reserveFamily(family, purchases * amount)
		return true
	end

	local function refillPass(shopId)
		local currencytable = {}
		for _, family in order do
			local slider = sliders[family]
			if active[family] and slider then
				local minimum = tonumber(slider.ValueMin) or 0
				local target = tonumber(slider.ValueMax) or 0
				if minimum > 0 and heldFamily(family) < minimum then
					refillFamily(family, target, shopId, currencytable)
				end
			end
		end
	end

	-- Sliders follow the whitelist, and the order entries are bought in never changes
	-- mid-match: new entries are appended and existing ones keep their slot, so two passes
	-- in the same match always agree.
	local function syncItems()
		local list = Whitelist and Whitelist.List or {}
		local enabled = Whitelist and Whitelist.ListEnabled or {}
		table.clear(active)

		for _, raw in list do
			local family = util.Families.Name(raw)
			if family then
				if not table.find(order, family) then
					table.insert(order, family)
				end
				if not sliders[family] then
					local preset = defaults[family] or fallback
					sliders[family] = AutoRefill:CreateTwoSlider({
						Name = util.Families.Label(family),
						Min = 0,
						Max = SLIDER_MAX,
						Decimal = 1,
						DefaultMin = preset.Min,
						DefaultMax = preset.Target,
						Darker = true,
						Tooltip = 'Lower handle: refill once you drop below this amount\nUpper handle: buy until you are back up to this amount'
					})
				end
				if table.find(enabled, raw) then
					active[family] = true
				end
			end
		end

		for family, slider in sliders do
			if slider.Object then
				slider.Object.Visible = active[family] and true or false
			end
		end
	end

	AutoRefill = vape.Categories.Inventory:CreateModule({
		Name = 'AutoRefill',
		Function = function(callback)
			if not callback then
				-- Reservations describe purchases in flight for this session only.
				table.clear(reserved)
				return
			end

			if not util.Queue.Await(AutoRefill) then return end

			local nextPass = 0
			repeat
				local fighting = Fighting.Enabled and util.Utils.InCombat()
				local store = getgenv().store
				if util.Utils.Alive() and store and store.shopLoaded and store.matchState ~= 2 and not fighting and nextPass <= tick() then
					local shopId = util.Shop.Id('item')
					if shopId then
						refillPass(shopId)
						-- Long enough for the purchases this pass sent to land in the store, so the next one
						-- starts from real totals rather than the ones the reservation is still covering.
						nextPass = tick() + 0.75
					end
				end
				task.wait(util.PollInterval)
			until not AutoRefill.Enabled
		end,
		Tooltip = 'Buys the items you are running out of whenever you are near a shop'
	})

	Whitelist = AutoRefill:CreateTextList({
		Name = 'Whitelist',
		Placeholder = 'Item name...',
		Default = {'arrow', 'wool'},
		Function = function()
			syncItems()
		end,
		Tooltip = 'Items to keep topped up. One double slider per entry, and wool covers every wool colour'
	})

	-- Built from the default list first so a saved profile finds its sliders already there.
	syncItems()

	Fighting = AutoRefill:CreateToggle({
		Name = 'Ignore while fighting',
		Default = true,
		Tooltip = 'Stops refilling while you are in a fight, using the shared combat state'
	})
end)
