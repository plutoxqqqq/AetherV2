run(function()
	local AutoLasso
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local VoidClutch
	local ClutchFallSpeed
	local nextFire = 0
	local voidRay = RaycastParams.new()
	voidRay.RespectCanCollide = true
	voidRay.FilterType = Enum.RaycastFilterType.Exclude

	local function findClutchTarget()
		local root = entitylib.character.RootPart
		local velocity = root.AssemblyLinearVelocity
		if velocity.Y > -ClutchFallSpeed.Value then return end
		voidRay.FilterDescendantsInstances = {lplr.Character, gameCamera}
		local fallTime = math.clamp((-velocity.Y + math.sqrt(velocity.Y * velocity.Y + 2 * workspace.Gravity * 45)) / workspace.Gravity, 0.25, 1.35)
		local predicted = root.Position + velocity * fallTime + Vector3.new(0, -0.5 * workspace.Gravity * fallTime * fallTime, 0)
		if workspace:Raycast(root.Position, predicted - root.Position, voidRay) then return end

		return entitylib.EntityPosition({
			Origin = root.Position,
			Range = Range.Value,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled or nil,
			Sort = sortmethods.Distance
		})
	end

	local function throwLasso(target)
		local item = getItem('lasso')
		local source = item and bedwars.ItemMeta.lasso.projectileSource or nil
		target = target or (source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil)
		if not source or not target then return end

		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if fireProjectile(item, 'lasso', source.projectileType('lasso'), target) then
				nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end

	AutoLasso = kits:CreateModule({
		Name = 'AutoLasso',
		Function = function(callback)
			if callback then
				nextFire = 0

				repeat
					if entitylib.isAlive and tick() >= nextFire then
						if store.equippedKit == 'cowgirl' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 then
							throwLasso()
						elseif VoidClutch.Enabled then
							local target = findClutchTarget()
							if target then throwLasso(target) end
						end
					end
					task.wait(0.1)
				until not AutoLasso.Enabled
			end
		end,
		Tooltip = 'Automatically throws Lassy\'s lasso at whoever you\'re meleeing, with an optional void clutch'
	})
	Targets = AutoLasso:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoLasso:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoLasso:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoLasso:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
	VoidClutch = AutoLasso:CreateToggle({
		-- Keep the legacy option key so existing Aether AutoLasso configs
		-- automatically retain their void-rescue preference after the merge.
		Name = 'Void',
		Tooltip = 'Uses the lasso on a nearby target during a genuine void fall'
	})
	ClutchFallSpeed = AutoLasso:CreateSlider({
		Name = 'Clutch fall speed',
		Min = 1,
		Max = 100,
		Default = 18,
		Tooltip = 'Only attempts a clutch after falling at this speed'
	})
end)