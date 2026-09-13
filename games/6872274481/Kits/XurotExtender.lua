run(function()
	local XurotExtender
	local Multiplier

	local old

	XurotExtender = kits:CreateModule({
		Name = 'XurotExtender',
		Function = function(callback)
			if callback then
				old = bedwars.VoidDragonController.flapWings
				bedwars.VoidDragonController.flapWings = function(self, ...)
					local call = old(self, ...)

					if store.equippedKit == 'void_dragon' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * (Multiplier.Value - 1) * 40, 0))
					end
					return call
				end
			else
				bedwars.VoidDragonController.flapWings = old
			end
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
