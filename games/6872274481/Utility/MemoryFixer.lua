run(function()
	local MemoryFixer
	local Sync
	local Interval
	local Notify
	local signals = {'Heartbeat', 'PostSimulation', 'PreAnimation', 'PreRender', 'PreSimulation', 'RenderStepped', 'Stepped'}
	
	local function clean()
		if not getconnections or not getfunctionhash or not isexecutorclosure then
			return 0
		end
	
		local removed, seen = 0, {}
		for _, v in signals do
			for _, connection in getconnections(runService[v]) do
				if connection.Function and not connection.ForeignState and isexecutorclosure(connection.Function) then
					local hash = v..getfunctionhash(connection.Function)
					if seen[hash] then
						connection:Disconnect()
						removed += 1
					else
						seen[hash] = true
					end
				end
			end
		end
	
		if Sync.Enabled then
			for _, event in bedwars.SyncEvents or {} do
				if typeof(event) == 'table' and typeof(event.entries) == 'table' then
					table.clear(seen)
					for i, entry in event.entries do
						local callback = entry.callbackInfo and entry.callbackInfo.callback
						if callback and isexecutorclosure(callback) then
							local hash = getfunctionhash(callback)
							if seen[hash] then
								event.entries[i] = nil
								event.isSorted = false
								removed += 1
							else
								seen[hash] = true
							end
						end
					end
				end
			end
		end
	
		return removed
	end
	
	MemoryFixer = vape.Categories.Utility:CreateModule({
		Name = 'MemoryFixer',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat
						local removed = clean()
						if Notify.Enabled and removed > 0 then
							notif('MemoryFixer', `Dropped {removed} leftover connection{removed == 1 and '' or 's'}`, 5)
						end
						task.wait(Interval.Value)
					until not MemoryFixer.Enabled
				end)
			end
		end,
		Tooltip = 'Drops the duplicate loops and listeners an older injection left connected'
	})
	Sync = MemoryFixer:CreateToggle({
		Name = 'Sync events',
		Default = true,
		Tooltip = 'Also prunes duplicate bedwars sync event listeners, the ones that survive a reinject'
	})
	Interval = MemoryFixer:CreateSlider({
		Name = 'Interval',
		Min = 5,
		Max = 300,
		Default = 30,
		Suffix = 'seconds'
	})
	Notify = MemoryFixer:CreateToggle({
		Name = 'Notify',
		Default = true,
		Tooltip = 'Tells you how many it dropped'
	})
	MemoryFixer:CreateButton({
		Name = 'Clean now',
		Function = function()
			local removed = clean()
			notif('MemoryFixer', `Dropped {removed} leftover connection{removed == 1 and '' or 's'}`, 5)
		end
	})
end)
