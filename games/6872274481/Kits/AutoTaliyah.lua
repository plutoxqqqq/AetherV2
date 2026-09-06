run(function()
	local AutoTaliyah
	local Emerald
	local Diamond
	local Iron
	local Amount

	local function getShopId()
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
					return v.Id
				end
			end
		end
		return
	end

	AutoTaliyah = kits:CreateModule({
		Name = 'AutoTaliyah',
		Function = function(callback)
			if callback then
				local item = bedwars.Shop.getShopItem('chicken_shop_item', lplr)

				repeat
					local id = getShopId()
					if id then
						local chickenData = bedwars.TaliyahUtil:getPrice()
						if (chickenData.currency == 'emerald' and Emerald.Enabled or chickenData.currency == 'iron' and Iron.Enabled or chickenData.currency == 'diamond' and Diamond.Enabled) and chickenData.price >= Amount.Value then
							bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {
								shopItem = item,
								shopId = id
							}):andThen(function(suc)
								if suc then
									bedwars.AudioManager:playAudio(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
									bedwars.Store:dispatch({
										type = 'BedwarsAddItemPurchased',
										itemType = item.itemType
									})
									bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
								end
							end)
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
