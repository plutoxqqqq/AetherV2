run(function()
	local JadeExtender
	local Multiplier

	local old

	JadeExtender = kits:CreateModule({
		Name = 'JadeExtender',
		Function = function(callback)
			if callback then
				old = bedwars.JadeHammerController.useJadeHammer
				bedwars.JadeHammerController.useJadeHammer = function(self)
					local jumped = bedwars.AbilityController:canUseAbility('jade_hammer_jump', {disableBlockedAbilityAlert = true})
					local call = old(self)

					if jumped and store.equippedKit == 'jade' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * (Multiplier.Value - 1) * 20.5, 0))
					end
					return call
				end
			else
				bedwars.JadeHammerController.useJadeHammer = old
			end
		end,
		Tooltip = 'Extends how far the Jade Hammer jump launches you'
	})
	Multiplier = JadeExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)