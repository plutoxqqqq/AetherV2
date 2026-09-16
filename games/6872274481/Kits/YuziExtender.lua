run(function()
	local util = vape.Libraries.bedwarsutil
	local YuziExtender
	local Multiplier

	YuziExtender = kits:CreateModule({
		Name = 'YuziExtender',
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			util.Hook.Controller(YuziExtender, 'DaoController', 'dashForward', function(original, ...)
				local results = table.pack(original(...))
				if YuziExtender.Enabled and util.IsKit('dasher') then
					local root = util.Utils.Root()
					local value = Multiplier and Multiplier.Value or 1
					if root and value > 1 then
						-- The controller is not always handed the direction; the dash otherwise
						-- follows where you are looking, so that is the fallback.
						local direction = util.FindVector(...)
						local flat = direction and direction * Vector3.new(1, 0, 1) or root.CFrame.LookVector * Vector3.new(1, 0, 1)
						if flat.Magnitude > 1e-4 then
							root:ApplyImpulse(flat.Unit * root.AssemblyMass * (value - 1) * 70)
						end
					end
				end
				return table.unpack(results, 1, results.n)
			end)
		end,
		Tooltip = 'Extends how far the Yuzi dash launches you'
	})
	Multiplier = YuziExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x',
		Tooltip = 'How much further than normal the dash carries you. 1x is the game\'s own distance'
	})
end)
