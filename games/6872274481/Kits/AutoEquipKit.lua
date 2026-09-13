run(function()
	local AutoEquipKit
	local Kit

	local kits, list = {}, {}

	for i, v in bedwars.BedwarsKitMeta do
		if v.name ~= 'None' then
			table.insert(list, v.name)
		end
		kits[v.name] = i
	end
	table.sort(list)
	table.insert(list, 1, 'None')

	AutoEquipKit = kits:CreateModule({
		Name = 'AutoEquipKit',
		Function = function(callback)
			if callback then
				local last

				repeat
					if store.matchState == 2 and last == 1 and Kit.Value ~= 'None' then
						bedwars.Handler:Get('BedwarsActivateKit'):Fire('CallServer', {kit = kits[Kit.Value]})
						notif('AutoEquipKit', `Equipped {Kit.Value} for the next round.`, 10, 'info')
					end

					last = store.matchState
					task.wait(0.5)
				until not AutoEquipKit.Enabled
			end
		end,
		Tooltip = 'Equips a kit automatically when a round ends'
	})
	Kit = AutoEquipKit:CreateDropdown({
		Name = 'Equip kit',
		List = list,
		Default = 'None'
	})
end)
