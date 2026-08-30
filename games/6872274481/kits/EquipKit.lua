run(function()
	local EquipKit
	local Kit

	local old = {}

	EquipKit = kits:CreateModule({
		Name = 'EquipKit',
		Function = function(callback)
			if callback then
				EquipKit:Toggle()
				notif('EquipKit', `{bedwars.Handler:Get('BedwarsActivateKit'):Fire('CallServer', {kit = old[Kit.Value]}) and 'Successfully equipped' or 'Failed to equip'} {Kit.Value}.`, 10, 'info')
			end
		end
	})
	local list = {}
	for i, v in bedwars.BedwarsKitMeta do
		table.insert(list, v.name)
		old[v.name] = i
	end
	table.sort(list)
	Kit = EquipKit:CreateDropdown({
		Name = 'Equip kit',
		List = list,
		Default = 'None'
	})
end)