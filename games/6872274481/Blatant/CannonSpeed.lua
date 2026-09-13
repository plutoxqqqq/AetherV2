run(function()
	local CannonSpeed
	local Speed
	local originalSpeed

	local function setSpeed(value)
		local controller = bedwars.CannonHandController
		if not (canDebug and controller and type(controller.launchSelf) == 'function' and debug.setconstant) then
			return false
		end
		return pcall(debug.setconstant, controller.launchSelf, 15, value)
	end

	CannonSpeed = vape.Categories.Blatant:CreateModule({
		Name = 'CannonSpeed',
		Function = function(enabled)
			if enabled then
				local controller = bedwars.CannonHandController
				local ok, value = pcall(function()
					return canDebug and debug.getconstant and controller and debug.getconstant(controller.launchSelf, 15)
				end)
				originalSpeed = ok and value or nil
				if not setSpeed(Speed.Value) then
					notif('CannonSpeed', 'Cannon speed is unavailable in this BedWars build.', 5, 'warning')
					task.defer(function() if CannonSpeed.Enabled then CannonSpeed:Toggle() end end)
				end
			elseif originalSpeed ~= nil then
				setSpeed(originalSpeed)
				originalSpeed = nil
			end
		end,
		Tooltip = 'Changes the local cannon-launch speed where this BedWars build exposes it'
	})
	Speed = CannonSpeed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 400,
		Default = 200,
		Suffix = ' studs',
		Function = function(value)
			if CannonSpeed.Enabled then setSpeed(value) end
		end
	})
	CannonSpeed:CreateButton({
		Name = 'Sync to legit speed',
		Function = function() Speed:SetValue(200) end
	})
end)
