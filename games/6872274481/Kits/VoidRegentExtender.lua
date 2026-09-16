run(function()
	local util = vape.Libraries.bedwarsutil
	local VoidRegentExtender
	local Multiplier

	VoidRegentExtender = kits:CreateModule({
		Name = 'VoidRegentExtender',
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			util.Hook.Controller(VoidRegentExtender, 'VoidAxeController', 'useVoidAxe', function(original, ...)
				local dashed = util.Ability.Ready('void_axe_jump')
				local results = table.pack(original(...))
				if dashed and VoidRegentExtender.Enabled and util.IsKit('regent') then
					local root = util.Utils.Root()
					local value = Multiplier and Multiplier.Value or 1
					if root and value > 1 then
						-- The dash follows the look direction; the controller is only passed `self`
						-- by some call paths, so the direction can never be read from the arguments.
						root:ApplyImpulse(root.CFrame.LookVector * Vector3.new(1, 0, 1) * root.AssemblyMass * (value - 1) * 70)
					end
				end
				return table.unpack(results, 1, results.n)
			end)
		end,
		Tooltip = 'Extends how far the Void Regent axe dash launches you'
	})
	Multiplier = VoidRegentExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x',
		Tooltip = 'How much further than normal the dash carries you. 1x is the game\'s own distance'
	})
end)
