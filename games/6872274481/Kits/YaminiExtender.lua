run(function()
	local YaminiExtender
	local Multiplier

	local old

	YaminiExtender = kits:CreateModule({
		Name = 'YaminiExtender',
		Function = function(callback)
			if callback then
				old = bedwars.CatController.leap
				bedwars.CatController.leap = function(self, character, direction)
					local call = old(self, character, direction)
					local horizontal = direction and direction * Vector3.new(1, 0, 1) or Vector3.zero
					local root = character and character:FindFirstChild('HumanoidRootPart')

					if store.equippedKit == 'cat' and root and horizontal.Magnitude > 0 then
						root:ApplyImpulse(horizontal.Unit * root.AssemblyMass * (Multiplier.Value - 1) * 70)
					end
					return call
				end
			else
				bedwars.CatController.leap = old
			end
		end,
		Tooltip = 'Extends how far the Cat/Yamini pounce launches you'
	})
	Multiplier = YaminiExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)
