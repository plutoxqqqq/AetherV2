run(function()
	local old, overcharge

	kits:CreateModule({
		Name = 'AutoVanessa',
		Function = function(callback)
			if callback then
				old = bedwars.TripleShotProjectileController.getChargeTime
				overcharge = bedwars.TripleShotProjectileController.overchargeStartTime
				bedwars.TripleShotProjectileController.getChargeTime = function()
					return 0
				end
				bedwars.TripleShotProjectileController.overchargeStartTime = tick()
			else
				bedwars.TripleShotProjectileController.getChargeTime = old
				bedwars.TripleShotProjectileController.overchargeStartTime = overcharge
			end
		end,
		Tooltip = 'Fully charges your bow instantly and enables triple shot as Vanessa'
	})
end)