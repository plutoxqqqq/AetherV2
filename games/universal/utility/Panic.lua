run(function()
	local Panic
	local armedUntil = 0

	Panic = vape.Categories.Utility:CreateModule({
		Name = 'Panic',
		Function = function(callback)
			if callback then
				local now = tick()
				if now > armedUntil then
					armedUntil = now + 8
					notif('Panic', 'Panic is armed. Activate Panic again within 8 seconds to turn every module off.', 8, 'warning')
					Panic:Toggle()
					return
				end
				armedUntil = 0
				for _, v in vape.Modules do
					if v.Enabled then
						v:Toggle()
					end
				end
			end
		end,
		Tooltip = 'Requires a second activation before disabling all currently enabled modules',
	})
end)