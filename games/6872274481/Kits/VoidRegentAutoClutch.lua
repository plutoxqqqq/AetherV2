run(function()
	local VoidRegentAutoClutch
	local Range
	local Depth
	local FallSpeed
	local FaceGround
	local lastClutch = 0

	VoidRegentAutoClutch = kits:CreateModule({
		Name = 'VoidRegentAutoClutch',
		Function = function(callback)
			if callback then
				VoidRegentAutoClutch:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive and store.equippedKit == 'regent' and store.airRay and tick() >= lastClutch and bedwars.VoidAxeController then
						local root = entitylib.character.RootPart
						if root.Velocity.Y < -FallSpeed.Value and not entitylib.Raycast(root.Position, Vector3.new(0, -Depth.Value, 0), store.airRay) and bedwars.AbilityController:canUseAbility('void_axe_jump', {disableBlockedAbilityAlert = true}) then
							local ground = getNearGround(Range.Value / 3)
							local delta = ground and (ground - root.Position) * Vector3.new(1, 0, 1)
							if delta and delta.Magnitude > 0 then
								lastClutch = tick() + 0.5
								if FaceGround.Enabled then
									root.CFrame = CFrame.lookAt(root.Position, root.Position + delta.Unit)
								end
								bedwars.VoidAxeController:useVoidAxe()
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'Dashes the void axe back towards solid ground when you fall off the map'
	})
	Range = VoidRegentAutoClutch:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 60,
		Default = 45,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far to look for ground to dash back to'
	})
	Depth = VoidRegentAutoClutch:CreateSlider({
		Name = 'Depth',
		Min = 10,
		Max = 150,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Nothing beneath you within this counts as the void'
	})
	FallSpeed = VoidRegentAutoClutch:CreateSlider({
		Name = 'Fall speed',
		Min = 0,
		Max = 100,
		Default = 10,
		Tooltip = 'Only clutches once you are dropping this fast'
	})
	FaceGround = VoidRegentAutoClutch:CreateToggle({
		Name = 'Face ground',
		Default = true,
		Tooltip = 'Turns you towards the ground first, the dash always goes where you face'
	})
end)
