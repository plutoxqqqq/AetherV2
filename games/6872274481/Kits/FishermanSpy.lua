run(function()
	local FishermanSpy
	local Teammates

	FishermanSpy = kits:CreateModule({
		Name = 'FishermanSpy',
		Function = function(call)
			if call then
				FishermanSpy:Clean(bedwars.Handler:Get('FishCaught').Remote:Connect(function(data)
					if data.dropData and data.dropData.drops and data.catchingPlayer and (not Teammates.Enabled or lplr.Team ~= data.catchingPlayer.Team) then
						local text = {}
						for _, v in data.dropData.drops do
							local itemmeta = bedwars.ItemMeta[v.itemType]
							table.insert(text, `{v.amount} {(itemmeta and itemmeta.displayName or v.itemType):lower()}{v.amount >= 2 and 's' or ''}`)
						end

						if #text > 0 then
							notif('FishermanSpy', `{data.catchingPlayer.Name} caught {table.concat(text, ', ')}`, 20, 'info')
						end
					end
				end))
			end
		end,
		Tooltip = 'Notifies you whenever someone reels in a fish, and what it dropped'
	})
	Teammates = FishermanSpy:CreateToggle({
		Name = 'Ignore teammate',
		Default = true
	})
end)
