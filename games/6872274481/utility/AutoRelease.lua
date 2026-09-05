run(function()
    local AutoRelease
    local Percentage
    local Delay

    local launchHook, last = nil, 0
    local charge = 0

    AutoRelease = vape.Categories.Utility:CreateModule({
	Name = 'AutoRelease',
	Function = function(call)
		if call then
			launchHook = bedwars.ProjectileLaunchHook:Add('AutoRelease', 20, function(nextLaunch, ...)
				local projmeta = select(2, ...)
				if projmeta and typeof(projmeta) == 'table' then
					charge = (projmeta.velocityMultiplier / 1) * 100
					last = os.clock() + 0.1
				end

				return nextLaunch(...)
			end)

			repeat
				if last > os.clock() and charge >= Percentage.Value then
					task.wait(Delay.Value)
					mouse1click()
					task.wait(0.2)
				end
				task.wait()
			until not AutoRelease.Enabled
		else
			if launchHook then
				launchHook()
				launchHook = nil
			end
		end
	end,
        Tooltip = 'Automatically releases your projectile source when\nat certain charging percentage'
    })

    Percentage = AutoRelease:CreateSlider({
	Name = 'Percentage',
	Min = 0,
	Max = 100,
	Suffix = '%',
	Default = 100,
    })
    Delay = AutoRelease:CreateSlider({
	Name = 'Release delay',
	Min = 0,
	Max = 5,
	Default = 0.5,
	Decimal = 10,
	Suffix = function(val)
		return val <= 1 and 'sec' or 'secs'
	end,
    })
end)