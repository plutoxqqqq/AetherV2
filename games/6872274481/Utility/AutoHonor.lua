run(function()
	local AutoHonor
	local Delay
	
	local Honored = {}
	local function honor()
		local list, team = playersService:GetPlayers(), lplr:GetAttribute('Team')
		table.sort(list, function(a, b)
			return a:GetAttribute('Team') == team and b:GetAttribute('Team') ~= team
		end)
		for _, v in list do
			local id = v:GetAttribute('Team')
			if v ~= lplr and id and not Honored[id] and (lplr:GetAttribute(id == team and 'HonorPointsLeftToGiveToAllies' or 'HonorPointsLeftToGiveToOpponents') or 0) > 0 then
				Honored[id] = true
				bedwars.HonorController:honorPlayer(v.UserId):await()
				task.wait(Delay.Value)
			end
		end
	end
	
	AutoHonor = vape.Categories.Utility:CreateModule({
		Name = 'AutoHonor',
		Function = function(callback)
			if callback then
				AutoHonor:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and #bedwars.Store:getState().Party.members <= 0 and store.matchState ~= 2 then
						honor()
					end
				end))
				AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(honor))
			end
		end,
		Tooltip = 'Automatically honor your teammates'
	})
	
	Delay = AutoHonor:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.1
	})
end)