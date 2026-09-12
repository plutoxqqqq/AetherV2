run(function()
	local AutoElektra
	local Targets
	local Range
	local Face
	local nextDash = 0

	AutoElektra = kits:CreateModule({
		Name = 'AutoElektra',
		Function = function(callback)
			if callback then
				nextDash = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'elektra' and tick() >= nextDash and bedwars.AbilityController:canUseAbility('ELECTRIC_DASH', {disableBlockedAbilityAlert = true}) then
						local target = entitylib.EntityPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Wallcheck = Targets.Walls.Enabled,
							Sort = sortmethods.Distance
						})

						if target then
							if Face.Enabled then
								local root = entitylib.character.RootPart
								root.CFrame = CFrame.lookAlong(root.Position, (target.RootPart.Position - root.Position) * Vector3.new(1, 0, 1))
							end

							nextDash = tick() + 0.5
							bedwars.AbilityController:useAbility('ELECTRIC_DASH')
						end
					end
					task.wait(0.1)
				until not AutoElektra.Enabled
			end
		end,
		Tooltip = 'Spends your dash charges on whoever walks into range'
	})

	Targets = AutoElektra:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoElektra:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Face = AutoElektra:CreateToggle({
		Name = 'Face target',
		Default = true,
		Tooltip = 'Turns you at them first so the dash actually goes through them'
	})
end)
