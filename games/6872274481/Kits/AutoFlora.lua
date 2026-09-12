run(function()
	local AutoFlora
	local Mode
	local Height
	local Speed
	local nextGlide = 0

	AutoFlora = kits:CreateModule({
		Name = 'AutoFlora',
		Function = function(callback)
			if callback then
				nextGlide = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'queen_bee' and tick() >= nextGlide and bedwars.AbilityController:canUseAbility('QUEEN_BEE_GLIDE', {disableBlockedAbilityAlert = true}) then
						local root = entitylib.character.RootPart

						if root.AssemblyLinearVelocity.Y <= -Speed.Value then
							local drop = Mode.Value == 'Void' and 2000 or Height.Value
							local ground = workspace:Raycast(root.Position, Vector3.new(0, -drop, 0), store.airRay)

							if not ground then
								nextGlide = tick() + 1
								bedwars.AbilityController:useAbility('QUEEN_BEE_GLIDE')
							end
						end
					end
					task.wait(0.05)
				until not AutoFlora.Enabled
			end
		end,
		Tooltip = 'Opens the glide the moment you drop with nothing under you'
	})

	Mode = AutoFlora:CreateDropdown({
		Name = 'Mode',
		List = {'Void', 'Any Drop'},
		Default = 'Void',
		Function = function(val)
			Height.Object.Visible = val == 'Any Drop'
		end,
		Tooltip = 'Void - only when there is no floor at all under you\nAny Drop - also for long falls onto the map'
	})
	Height = AutoFlora:CreateSlider({
		Name = 'Ground check',
		Min = 5,
		Max = 200,
		Default = 40,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Speed = AutoFlora:CreateSlider({
		Name = 'Fall speed',
		Min = 1,
		Max = 100,
		Default = 20,
		Tooltip = 'How fast you have to be dropping before it glides'
	})
end)
