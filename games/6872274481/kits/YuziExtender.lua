run(function()
	local YuziExtender
	local Multiplier

	local old

	YuziExtender = kits:CreateModule({
		Name = 'YuziExtender',
		Function = function(callback)
			if callback then
				old = bedwars.DaoController.dashForward
				bedwars.DaoController.dashForward = function(self, direction)
					local call = old(self, direction)
					local horizontal = direction and direction * Vector3.new(1, 0, 1) or Vector3.zero

					if store.equippedKit == 'dasher' and entitylib.isAlive and horizontal.Magnitude > 0 then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(horizontal.Unit * root.AssemblyMass * (Multiplier.Value - 1) * 70)
					end
					return call
				end
			else
				bedwars.DaoController.dashForward = old
			end
		end,
		Tooltip = 'Extends how far the yuzi dash launches you.'
	})
	Multiplier = YuziExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)