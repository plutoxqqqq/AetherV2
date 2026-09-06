run(function()
	local LeaveParty
	LeaveParty = vape.Categories.Utility:CreateModule({
		Name = 'LeaveParty',
		Function = function(enabled)
			if not enabled then return end
			local ok = pcall(function()
				bedwars.PartyController:leaveParty()
			end)
			if not ok then
				notif('LeaveParty', 'Party controls are unavailable.', 4, 'warning')
			end
			
			task.defer(function() if LeaveParty.Enabled then LeaveParty:Toggle() end end)
		end,
		Tooltip = 'Leaves the current BedWars party'
	})
end)
