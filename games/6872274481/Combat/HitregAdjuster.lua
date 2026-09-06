run(function()
	local HitregAdjuster, Hitreg
	local firstConnection, restoreConnection

	HitregAdjuster = vape.Categories.Combat:CreateModule({
		Name = 'HitregAdjuster',
		Function = function(enabled)
			if not enabled then return end
			local sync = bedwars.SyncEvents and bedwars.SyncEvents.SwordSwing
			if not sync then
				notif('HitregAdjuster', 'Sword swing events are unavailable.', 5, 'warning')
				HitregAdjuster:Toggle()
				return
			end
			local original
			firstConnection = sync:setPriority(150):connect(function(event)
				original = event.attackSpeed
				event.attackSpeed = 10 / math.max(Hitreg.Value - 1, 1)
			end)
			restoreConnection = sync:setPriority(300):connect(function(event)
				if original ~= nil then event.attackSpeed = original end
			end)
			HitregAdjuster:Clean(function()
				if firstConnection then firstConnection:Destroy(); firstConnection = nil end
				if restoreConnection then restoreConnection:Destroy(); restoreConnection = nil end
			end)
		end,
		Tooltip = 'Adjusts manual and AutoClicker sword swing spacing without changing Killaura timing.'
	})
	Hitreg = HitregAdjuster:CreateSlider({Name = 'Hitreg', Min = 1, Max = 36, Default = 35, Suffix = ' hits / 10s'})
end)
end
