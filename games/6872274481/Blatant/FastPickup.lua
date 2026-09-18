run(function()
	local FastPickup
	local FastPickupDelay

	-- The drop list is looked up per pass instead of being held: the folder is created when the
	-- first item drops and can disappear between rounds, and a WaitForChild here would park the
	-- module's thread forever on a server where nothing has dropped yet.
	local function getDropCache()
		local cache = workspace:FindFirstChild('ItemDropsCache')
		return cache or nil
	end

	-- The pickup remote behind ItemDropController.checkForPickup. Going through Handler means a
	-- server where the remote could not be read answers with no instance instead of throwing.
	local function pickup(drop)
		local entry = bedwars.Handler:Get(remotes.PickupItem)
		local instance = entry and entry.instance
		if not instance or type(instance.InvokeServer) ~= 'function' then return end
		pcall(function()
			instance:InvokeServer({itemDrop = drop})
		end)
	end

	FastPickup = vape.Categories.Blatant:CreateModule({
		Name = 'FastPickup',
		Tooltip = 'picks up items faster than usual',
		Function = function(callback)
			if callback then
				FastPickup:Clean(task.spawn(function()
					while FastPickup.Enabled do
						if entitylib.isAlive then
							local cache = getDropCache()
							if cache then
								for _, drop in pairs(cache:GetChildren()) do
									if drop and drop.Parent then
										task.spawn(function()
											local delay = FastPickupDelay and FastPickupDelay.Value or 0
											if delay > 0 then task.wait(delay) end
											if not FastPickup.Enabled or not drop.Parent then return end
											pcall(pickup, drop)
										end)
									end
								end
							end
						end
						task.wait(0.05)
					end
				end))
			end
		end
	})

	FastPickupDelay = FastPickup:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 0.5,
		Default = 0,
		Decimal = 100,
		Suffix = 's'
	})
end)
