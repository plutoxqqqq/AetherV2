run(function()
	local util = vape.Libraries.bedwarsutil
	local YaminiExtender
	local Multiplier

	YaminiExtender = kits:CreateModule({
		Name = 'YaminiExtender',
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			util.Hook.Controller(YaminiExtender, 'CatController', 'leap', function(original, ...)
				local direction = util.FindVector(...)
				local results = table.pack(original(...))
				if YaminiExtender.Enabled and util.IsKit('cat') and direction then
					-- The leap is called with the character it is moving, so boost that root rather
					-- than assuming it is always the local player's.
					local character = select(1, ...)
					local root = typeof(character) == 'Instance' and character:FindFirstChild('HumanoidRootPart') or nil
					root = root or util.Utils.Root()
					local value = Multiplier and Multiplier.Value or 1
					if root and value > 1 then
						local flat = direction * Vector3.new(1, 0, 1)
						if flat.Magnitude > 1e-4 then
							root:ApplyImpulse(flat.Unit * root.AssemblyMass * (value - 1) * 70)
						end
					end
				end
				return table.unpack(results, 1, results.n)
			end)
		end,
		Tooltip = 'Extends how far the Cat/Yamini pounce launches you'
	})
	Multiplier = YaminiExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x',
		Tooltip = 'How much further than normal the pounce carries you. 1x is the game\'s own distance'
	})
end)
