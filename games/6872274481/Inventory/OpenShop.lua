run(function()
	local runtime = shared.AetherShopRuntime

	local OpenShop
	OpenShop = vape.Categories.Inventory:CreateModule({
		Name = 'OpenShop',
		Function = function(callback)
			runtime.activateShop(runtime.nearestItemShop())

			task.defer(function()
				OpenShop:Toggle()
			end)
		end,
		Tooltip = 'Opens the nearest item shop'
	})
end)
