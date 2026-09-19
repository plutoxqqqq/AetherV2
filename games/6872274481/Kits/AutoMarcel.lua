run(function()
	local AutoMarcel
	local Delay
	local Debug

	local function getController()
		local knit = bedwars.Knit
		local controllers = knit and knit.Controllers
		return controllers and controllers.DefenderKitController or nil
	end

	-- The defender scanner runs in one of three modes, and the request that goes out depends on which.
	local function getScannerMode()
		local ok, state = pcall(bedwars.Store.getState, bedwars.Store)
		local kit = ok and type(state) == 'table' and state.Kit
		return kit and kit.defenderScannerMode or nil
	end

	local function request(controller, blockPos, blockType)
		local mode = getScannerMode()

		if mode == 'upgrade' and type(controller.requestScannerAction) == 'function' then
			return pcall(controller.requestScannerAction, controller, blockPos, 'upgrade', blockType)
		end
		if mode == 'refund' and type(controller.requestScannerAction) == 'function' then
			return pcall(controller.requestScannerAction, controller, blockPos, 'refund')
		end

		if type(controller.requestPlaceDefenderBlock) == 'function' then
			return pcall(controller.requestPlaceDefenderBlock, controller, blockPos)
		end

		-- Builds that keep the request on the controller's remote rather than a method of its own.
		local remote = controller.requestPlaceDefenderBlockRemote
		if remote then
			if type(remote.SendToServer) == 'function' then
				return pcall(function() remote:SendToServer(blockPos) end)
			end
			if type(remote.FireServer) == 'function' then
				return pcall(function() remote:FireServer(blockPos) end)
			end
		end

		return false, 'this BedWars build has no defender placement path'
	end

	local reportedFailure = false

	AutoMarcel = kits:CreateModule({
		Name = 'AutoMarcel',
		Function = function(callback)
			if not callback then return end
			reportedFailure = false

			task.spawn(function()
				repeat
					if entitylib.isAlive then
						local controller = getController()
						local schematic = controller and controller.currentSchematic
						if type(schematic) == 'table' then
							for blockPos, blockType in schematic do
								if not AutoMarcel.Enabled then break end
								if not entitylib.isAlive then break end

								local ok, err = request(controller, blockPos, blockType)
								if not ok and Debug.Enabled and not reportedFailure then
									reportedFailure = true
									notif('AutoMarcel', tostring(err), 8, 'warning')
								end
								task.wait(Delay.Value)
							end
						end
					end
					task.wait(0.1)
				until not AutoMarcel.Enabled
			end)
		end,
		Tooltip = "Builds the whole Defender (Marcel) schematic for you: every block the scanner has left to place"
	})

	Delay = AutoMarcel:CreateSlider({
		Name = 'Delay',
		Tooltip = 'Wait time between placements',
		Min = 0,
		Max = 1,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's'
	})
	Debug = AutoMarcel:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Reports when this BedWars build has no placement path instead of staying quiet'
	})
end)
