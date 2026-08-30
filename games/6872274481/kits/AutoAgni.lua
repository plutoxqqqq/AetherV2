run(function()
	local AutoAgni
	local Targets, Range, OnlySwinging, Clutch
	local swingMarker, swingSeenAt = nil, -math.huge
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.RespectCanCollide = true

	local function updateSwing()
		local value = bedwars.SwordController and bedwars.SwordController.lastSwing or 0
		if value ~= swingMarker then
			swingMarker, swingSeenAt = value, os.clock()
		end
	end

	local function voidFall(root)
		if not root or root.AssemblyLinearVelocity.Y >= -2 then return false end
		ray.FilterDescendantsInstances = lplr.Character and {lplr.Character} or {}
		return workspace:Raycast(root.Position, Vector3.new(0, -80, 0), ray) == nil
	end

	local function activate()
		local ok, ready = pcall(bedwars.AbilityController.canUseAbility, bedwars.AbilityController, 'rocket_detonate', {disableBlockedAbilityAlert = true})
		if not ok or not ready then return false end
		local used, result = pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, 'rocket_detonate')
		return used and result ~= false
	end

	AutoAgni = kits:CreateModule({
		Name = 'AutoAgni',
		Category = 'Auto',
		Function = function(callback)
			if not callback then return end
			swingMarker, swingSeenAt = bedwars.SwordController and bedwars.SwordController.lastSwing or 0, -math.huge
			local nextUse = 0
			repeat
				if entitylib.isAlive and store.equippedKit == 'agni' then
					local root = entitylib.character.RootPart
					updateSwing()
					if Clutch.Enabled and voidFall(root) then
						if os.clock() >= nextUse and activate() then nextUse = os.clock() + 0.35 end
						local land = getNearGround(30)
						local humanoid = entitylib.character.Humanoid
						if land and humanoid then
							local delta = Vector3.new(land.X - root.Position.X, 0, land.Z - root.Position.Z)
							if delta.Magnitude > 0.05 then humanoid:Move(delta.Unit, false) end
						end
					elseif not OnlySwinging.Enabled or os.clock() - swingSeenAt <= 0.3 then
						local target = entitylib.EntityPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled or nil,
							Sort = sortmethods.Distance
						})
						if target and os.clock() >= nextUse and activate() then nextUse = os.clock() + 0.35 end
					end
				end
				task.wait(0.03)
			until not AutoAgni.Enabled
		end,
		Tooltip = 'Automatically uses Agni rocket boost around selected targets; Clutch saves void falls'
	})
	Targets = AutoAgni:CreateTargets({Players = true, NPCs = true, Walls = true})
	Range = AutoAgni:CreateSlider({Name = 'Range', Min = 1, Max = 40, Default = 12, Suffix = ' studs'})
	OnlySwinging = AutoAgni:CreateToggle({Name = 'Only while swinging'})
	Clutch = AutoAgni:CreateToggle({Name = 'Clutch', Default = true, Tooltip = 'Uses Agni while falling into the void and walks toward nearby land'})
end)