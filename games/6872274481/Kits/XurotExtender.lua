run(function()
	local util = vape.Libraries.bedwarsutil
	local XurotExtender
	local Multiplier

	XurotExtender = kits:CreateModule({
		Name = 'XurotExtender',
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			util.Hook.Controller(XurotExtender, 'VoidDragonController', 'flapWings', function(original, ...)
				local results = table.pack(original(...))
				if XurotExtender.Enabled and util.IsKit('void_dragon') then
					local root = util.Utils.Root()
					local value = Multiplier and Multiplier.Value or 1
					if root and value > 1 then
						root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * (value - 1) * 40, 0))
					end
				end
				return table.unpack(results, 1, results.n)
			end)
		end,
		Tooltip = 'Extends how high each Xurot wing flap throws you'
	})
	Multiplier = XurotExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x',
		Tooltip = 'How much higher than normal each flap carries you. 1x is the game\'s own height'
	})
end)
