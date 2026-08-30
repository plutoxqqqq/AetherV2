run(function()
	local runtime = shared.AetherShopRuntime
	if not runtime then warn('[AetherV2] OpenShop requires AutoBuy shop runtime'); return end
	local OpenShop
	OpenShop = vape.Categories.Inventory:CreateModule({
		Name = 'OpenShop',
		Function = function(callback)
			if not callback then return end
			local opened, reason = runtime.activateShop(runtime.nearestItemShop())
			if not opened then
				notif('OpenShop', reason == 'InteractExtender is disabled' and 'Enable InteractExtender first' or 'No item-shop prompt found', 4, 'alert')
			end
			task.defer(function()
				if OpenShop.Enabled then OpenShop:Toggle() end
			end)
		end,
		Tooltip = 'Opens the nearest item shop through InteractExtender'
	})
end)
