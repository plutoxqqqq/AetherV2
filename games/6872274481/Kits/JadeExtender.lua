run(function()
	local util = vape.Libraries.bedwarsutil
	local JadeExtender
	local Multiplier

	JadeExtender = kits:CreateModule({
		Name = 'JadeExtender',
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			util.Hook.Controller(JadeExtender, 'JadeHammerController', 'useJadeHammer', function(original, ...)
				local jumped = util.Ability.Ready('jade_hammer_jump')
				local results = table.pack(original(...))
				if jumped and JadeExtender.Enabled and util.IsKit('jade') then
					local root = util.Utils.Root()
					local value = Multiplier and Multiplier.Value or 1
					if root and value > 1 then
						root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * (value - 1) * 20.5, 0))
					end
				end
				return table.unpack(results, 1, results.n)
			end)
		end,
		Tooltip = 'Extends how far the Jade Hammer jump launches you'
	})
	Multiplier = JadeExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x',
		Tooltip = 'How much higher than normal the hammer jump carries you. 1x is the game\'s own height'
	})
end)
