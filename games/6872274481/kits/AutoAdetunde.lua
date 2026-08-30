run(function()
	local AutoAdetunde
	local GUI

	AutoAdetunde = kits:CreateModule({
		Name = 'AutoAdetunde',
		Function = function(callback)
			if callback then
				repeat
					if not GUI.Enabled or bedwars.AppController:isAppOpen('FrostyHammerApp') then
						for i, v in bedwars.AdetundeUtil.getUpgradesFromHammer(lplr) do
							local crystal = getItem('frost_crystal')
							if not crystal then
								break
							end

							local nextUpgrade = AutoAdetunde.Options[`Buy {i}`].Enabled and bedwars.AdetundeUpgradeMeta[i].tiers[v + 1]
							if nextUpgrade and crystal.amount >= nextUpgrade.price then
								bedwars.Handler:Get('UpgradeFrostyHammer'):Fire('CallServer', i)
								task.wait(0.1)
							end
						end
					end
					task.wait(0.5)
				until not AutoAdetunde.Enabled
			end
		end,
		Tooltip = 'Automatically upgrades ur frosty hammer'
	})
	for i in bedwars.AdetundeUpgradeMeta do
		AutoAdetunde:CreateToggle({
			Name = `Buy {i}`,
			Default = true
		})
	end

	GUI = AutoAdetunde:CreateToggle({
		Name = 'GUI Check',
		Tooltip = 'Only upgrades while the frosty hammer menu is open'
	})
end)