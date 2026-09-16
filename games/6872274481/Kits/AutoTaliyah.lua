run(function()
	local util = vape.Libraries.bedwarsutil

	local AutoTaliyah
	local Emerald
	local Diamond
	local Iron
	local Amount

	local function getShopId()
		return util.Shop.Id('item')
	end

	AutoTaliyah = kits:CreateModule({
		Name = 'AutoTaliyah',
		Function = function(callback)
			if callback then
				local item = util.Shop.Item('chicken_shop_item')

				repeat
					local id = getShopId()
					if id then
						local chickenData = bedwars.TaliyahUtil:getPrice()
						if (chickenData.currency == 'emerald' and Emerald.Enabled or chickenData.currency == 'iron' and Iron.Enabled or chickenData.currency == 'diamond' and Diamond.Enabled) and chickenData.price >= Amount.Value then
							util.Shop.Purchase(item, id)
						end
					end
					task.wait(0.1)
				until not AutoTaliyah.Enabled
			end
		end,
		Tooltip = 'Automatically buy chickens when it sells for emerald'
	})
	Iron = AutoTaliyah:CreateToggle({
		Name = 'Iron',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is iron'
	})
	Emerald = AutoTaliyah:CreateToggle({
		Name = 'Emerald',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is emerald'
	})
	Diamond = AutoTaliyah:CreateToggle({
		Name = 'Diamond',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is diamond'
	})
	Amount = AutoTaliyah:CreateSlider({
		Name = 'Amount',
		Min = 1,
		Max = 1000,
		Default = 2,
		Tooltip = 'Only sells if the currency is selling for the selected amount'
	})
end)
