run(function()
	local KrystalDisabler
	local Momentum
	local SuppressCorrections
	local oldUpdateMomentum, hookedUpdateMomentum
	local patchedSignals = setmetatable({}, {__mode = 'k'})
	local lastRemoteReport = 0

	local function getController()
		return bedwars and bedwars.GlacialSkaterController
	end

	
	
	
	
	local function reportMomentum(target)
		local handler = bedwars and bedwars.Handler
		if not handler then return end
		local now = tick()
		if now - lastRemoteReport < 0.1 then return end
		lastRemoteReport = now
		pcall(function()
			local remote = handler:Get('MomentumUpdate')
			if remote and remote.Remote then
				remote:Fire('SendToServer', {momentumValue = target})
			end
		end)
	end

	
	
	
	local function setKrystalMomentum(controller, report)
		controller = controller or getController()
		if not controller then return end
		local target = Momentum and Momentum.Value or 1000
		controller.momentum = target
		controller.lastMomentumReport = target
		if report then
			reportMomentum(target)
		end
	end

	local function patchMovementSignal(signal)
		if not signal or not getconnections or not hookfunction then return end
		for _, connection in getconnections(signal) do
			local func = connection and connection.Function
			if func and patchedSignals[func] == nil then
				
				
				
				local ok, original = pcall(hookfunction, func, function() end)
				patchedSignals[func] = (ok and original) or false
			end
		end
	end

	
	
	local function restoreSignals()
		for func, original in pairs(patchedSignals) do
			if type(original) == 'function' then
				pcall(hookfunction, func, original)
			end
		end
		table.clear(patchedSignals)
	end

	local function patchCharacter(character)
		if not SuppressCorrections or not SuppressCorrections.Enabled then return end
		local root = character and character.RootPart
		if not root then return end
		patchMovementSignal(root:GetPropertyChangedSignal('CFrame'))
		patchMovementSignal(root:GetPropertyChangedSignal('Velocity'))
		patchMovementSignal(root:GetPropertyChangedSignal('AssemblyLinearVelocity'))
	end

	KrystalDisabler = kits:CreateModule({
		Name = 'KrystalDisabler',
		Category = 'Ability',
		Function = function(callback)
			local controller = getController()
			if callback then
				if not controller or type(controller.updateMomentum) ~= 'function' then
					notif('KrystalDisabler', 'Krystal controller is unavailable.', 5, 'warning')
					KrystalDisabler:Toggle()
					return
				end

				lastRemoteReport = 0
				if not oldUpdateMomentum then
					
					
					
					local original = controller.updateMomentum
					oldUpdateMomentum = original
					
					
					hookedUpdateMomentum = function(self, ...)
						if not KrystalDisabler.Enabled then
							return original(self, ...)
						end
						setKrystalMomentum(self, false)
						local result = original(self, ...)
						setKrystalMomentum(self, true)
						return result
					end
					controller.updateMomentum = hookedUpdateMomentum
				end

				KrystalDisabler:Clean(runService.PreSimulation:Connect(function()
					setKrystalMomentum(nil, true)
				end))

				KrystalDisabler:Clean(entitylib.Events.LocalAdded:Connect(patchCharacter))
				if entitylib.isAlive then
					patchCharacter(entitylib.character)
				end
				setKrystalMomentum(controller, true)
				pcall(controller.updateMomentum, controller)
			else
				
				
				if controller and oldUpdateMomentum and controller.updateMomentum == hookedUpdateMomentum then
					controller.updateMomentum = oldUpdateMomentum
				end
				oldUpdateMomentum, hookedUpdateMomentum = nil, nil
				restoreSignals()
			end
		end,
		Tooltip = 'Removes Krystal lagbacks by keeping momentum maxed and muting the correction listeners'
	})

	Momentum = KrystalDisabler:CreateSlider({
		Name = 'Momentum',
		Min = 100,
		Max = 10000,
		Default = 1000
	})

	SuppressCorrections = KrystalDisabler:CreateToggle({
		Name = 'Suppress corrections',
		Default = true,
		Function = function(callback)
			if callback then
				if KrystalDisabler and KrystalDisabler.Enabled and entitylib.isAlive then
					patchCharacter(entitylib.character)
				end
			else
				restoreSignals()
			end
		end,
		Tooltip = 'Silences the listeners the server corrects you through. Needs getconnections and hookfunction'
	})
end)
