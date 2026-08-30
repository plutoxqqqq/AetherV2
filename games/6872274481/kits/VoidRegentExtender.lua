run(function()
	local VoidRegentExtender
	local Multiplier

	local old

	VoidRegentExtender = kits:CreateModule({
		Name = 'VoidRegentExtender',
		Function = function(callback)
			if callback then
				old = bedwars.VoidAxeController.useVoidAxe
				bedwars.VoidAxeController.useVoidAxe = function(self)
					local dashed = bedwars.AbilityController:canUseAbility('void_axe_jump', {disableBlockedAbilityAlert = true})
					local call = old(self)

					if dashed and store.equippedKit == 'regent' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(root.CFrame.LookVector * Vector3.new(1, 0, 1) * root.AssemblyMass * (Multiplier.Value - 1) * 70)
					end
					return call
				end
			else
				bedwars.VoidAxeController.useVoidAxe = old
			end
		end,
		Tooltip = 'Extends how far the Void Regent axe dash launches you'
	})
	Multiplier = VoidRegentExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)