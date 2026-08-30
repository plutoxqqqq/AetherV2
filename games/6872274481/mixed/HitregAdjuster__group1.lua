run(function()
    if canDebug then
run(function()
	local HitregAdjuster, Hitreg
	local firstConnection, restoreConnection

	HitregAdjuster = vape.Categories.Combat:CreateModule({
		Name = 'HitregAdjuster',
		Function = function(enabled)
			if not enabled then return end
			local sync = bedwars.SyncEvents and bedwars.SyncEvents.SwordSwing
			if not sync then
				notif('HitregAdjuster', 'Sword swing events are unavailable.', 5, 'warning')
				HitregAdjuster:Toggle()
				return
			end
			local original
			firstConnection = sync:setPriority(150):connect(function(event)
				original = event.attackSpeed
				event.attackSpeed = 10 / math.max(Hitreg.Value - 1, 1)
			end)
			restoreConnection = sync:setPriority(300):connect(function(event)
				if original ~= nil then event.attackSpeed = original end
			end)
			HitregAdjuster:Clean(function()
				if firstConnection then firstConnection:Destroy(); firstConnection = nil end
				if restoreConnection then restoreConnection:Destroy(); restoreConnection = nil end
			end)
		end,
		Tooltip = 'Adjusts manual and AutoClicker sword swing spacing without changing Killaura timing.'
	})
	Hitreg = HitregAdjuster:CreateSlider({Name = 'Hitreg', Min = 1, Max = 36, Default = 35, Suffix = ' hits / 10s'})
end)

run(function()
	local DeathAdderAimbot, Mode, BedRange, Targets, Sort, TargetPart, FOV
	local originalDirection, hookedDirection

	local function aimPosition(origin)
		if Mode.Value == 'Bed' then
			local closest, distance
			for _, bed in collectionService:GetTagged('bed') do
				if not bed:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
					local magnitude = (origin - bed.Position).Magnitude
					if magnitude <= BedRange.Value and (not distance or magnitude < distance) then closest, distance = bed, magnitude end
				end
			end
			return closest and closest.Position
		end
		local ent = entitylib.EntityMouse({Range = FOV.Value, Part = 'RootPart', Wallcheck = Targets.Walls.Enabled,
			Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Origin = origin, Sort = sortmethods[Sort.Value]})
		if not ent then return end
		targetinfo.Targets[ent] = tick() + 1
		local tier = bedwars.SorcererBalance.getSorcererTierData(bedwars.SorcererBalance.getSorcererTier(lplr))
		local position = ent[TargetPart.Value].Position
		return position + ent.RootPart.AssemblyLinearVelocity * ((position - origin).Magnitude / ((tier and tier.projectileVelocity) or 70))
	end

	DeathAdderAimbot = vape.Categories.Blatant:CreateModule({Name = 'DeathAdderAimbot', Function = function(enabled)
		local controller = bedwars.SorcererController
		if enabled then
			if not controller or type(controller.getProjectileDirection) ~= 'function' then
				notif('DeathAdderAimbot', 'Death Adder controller is unavailable.', 5, 'warning'); DeathAdderAimbot:Toggle(); return
			end
			originalDirection = controller.getProjectileDirection
			hookedDirection = function(self, ...)
				if entitylib.isAlive then
					local origin = entitylib.character.RootPart.Position
					local aim = aimPosition(origin)
					if aim and aim ~= origin then return (aim - origin).Unit end
				end
				return originalDirection(self, ...)
			end
			controller.getProjectileDirection = hookedDirection
			DeathAdderAimbot:Clean(function()
				if controller.getProjectileDirection == hookedDirection then controller.getProjectileDirection = originalDirection end
				originalDirection, hookedDirection = nil, nil
			end)
		end
	end, Tooltip = 'Silently leads Death Adder spells toward a player or enemy bed.'})
	Mode = DeathAdderAimbot:CreateDropdown({Name = 'Mode', List = {'Player', 'Bed'}, Function = function(value)
		if BedRange then BedRange.Object.Visible = value == 'Bed'; FOV.Object.Visible = value == 'Player'; TargetPart.Object.Visible = value == 'Player'; Sort.Object.Visible = value == 'Player' end
	end})
	BedRange = DeathAdderAimbot:CreateSlider({Name = 'Bed range', Min = 1, Max = 60, Default = 60, Suffix = ' studs', Visible = false})
	Targets = DeathAdderAimbot:CreateTargets({Players = true, Walls = true})
	local methods = {'Distance', 'Damage'}
	for name in sortmethods do if not table.find(methods, name) then table.insert(methods, name) end end
	Sort = DeathAdderAimbot:CreateDropdown({Name = 'Target mode', List = methods, Default = 'Distance'})
	TargetPart = DeathAdderAimbot:CreateDropdown({Name = 'Part', List = {'RootPart', 'Head'}})
	FOV = DeathAdderAimbot:CreateSlider({Name = 'FOV', Min = 1, Max = 1000, Default = 1000})
end)

run(function()
	local BlockReach
		local BlockRange
		local BreakReach
		local BreakRange
		local SwordReach
		local SwordRange

		local old

		Reach = vape.Categories.Combat:CreateModule({
			Name = 'Reach',
			Tooltip = 'Allows you to place, attack, and break further',
			Function = function(callback)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordReach.Enabled and SwordRange.Value + 2 or 14.4
				if callback then
					old = bedwars.BlockSelector.getMouseInfo
					bedwars.BlockSelector.getMouseInfo = function(...)
						local Self, Select, Args = ...
						if not Args then
							Args = {}
						end
						if Select == 0 then
							Args.range = BlockReach.Enabled and BlockRange.Value or 24
						elseif Select == 1 then
							Args.range = BreakReach.Enabled and BreakRange.Value or 18
						end
						return old(Self, Select, Args)
					end
				else
					bedwars.BlockSelector.getMouseInfo = old
					old = nil
				end
			end,
		})
		SwordReach = Reach:CreateToggle({
			Name = 'Sword Reach',
			Default = true,
			Function = function(callback)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and callback and SwordRange.Value + 2 or 14.4
				pcall(function()
					SwordRange.Object.Visible = callback
				end)
			end,
		})
		SwordRange = Reach:CreateSlider({
			Name = 'Sword Range',
			Min = 1,
			Max = 18,
			Default = 18,
			Decimal = 5,
			Darker = true,
			Suffix = function(val)
				return val <= 1 and 'stud' or 'studs'
			end,
			Function = function(val)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and SwordReach.Enabled and val or 14.4
			end,
		})
		BlockReach = Reach:CreateToggle({
			Name = 'Placement Reach',
			Function = function(callback)
				BlockRange.Object.Visible = callback
			end,
		})
		BlockRange = Reach:CreateSlider({
			Name = 'Placement Range',
			Min = 1,
			Max = 60,
			Default = 18,
			Darker = true,
			Suffix = function(val)
				return val <= 1 and 'stud' or 'studs'
			end,
			Visible = false,
		})
		BreakReach = Reach:CreateToggle({
			Name = 'Break Reach',
			Function = function(callback)
				BreakRange.Object.Visible = callback
			end,
		})
		BreakRange = Reach:CreateSlider({
			Name = 'Break Range',
			Min = 1,
			Max = 30,
			Default = 30,
			Decimal = 5,
			Darker = true,
			Suffix = function(val)
				return val <= 1 and 'stud' or 'studs'
			end,
			Visible = false,
		})
		Reach:CreateButton({
			Name = 'Reset to default reach',
			Tooltip = 'Resets every range back to default',
			Function = function()
				BreakRange:SetValue(18)
				BlockRange:SetValue(24)
				SwordRange:SetValue(12.4)
			end,
		})
	end)
    else
	local Value
	local rayParams = RaycastParams.new()
	rayParams.RespectCanCollide = true

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				Reach:Clean(vapeEvents.CEAttacked.Event:Connect(function()
					local doAttack
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						if
							entitylib.isAlive
							and store.hand.toolType == 'sword'
							and bedwars.DaoController.chargingMaid == nil
						then
							local attackRange = Value.Value + 2
							rayParams.FilterDescendantsInstances = { lplr.Character }

							local unit = lplr:GetMouse().UnitRay
							local localPos = entitylib.character.RootPart.Position
							local rayRange = (attackRange or 14.4)
							local ray = workspace:Raycast(unit.Origin, unit.Direction * 200, rayParams)
							if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
								for _, ent in entitylib.List do
									doAttack = ent.Targetable
										and ray.Instance:IsDescendantOf(ent.Character)
										and (localPos - ent.RootPart.Position).Magnitude <= rayRange
									if doAttack then
										break
									end
								end
							end

							local region = bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							if doAttack then
								doAttack = region
							end
							if doAttack then
								local selfpos = entitylib.character.RootPart.Position
								local delta = (doAttack.RootPart.Position - selfpos)
								local dir = CFrame.lookAt(selfpos, doAttack.RootPart.Position).LookVector
								local pos = selfpos + dir * math.max(delta.Magnitude - 14.4, 0)

								bedwars.Client:Get('SwordHit'):SendToServer({
									weapon = store.hand.tool,
									chargedAttack = {chargeRatio = 0},
									entityInstance = doAttack.Character,
									validate = {
										raycast = {},
										targetPosition = {value = doAttack.RootPart.Position},
										selfPosition = {value = pos},
									},
								})
							end
						end
					end
				end))
			end
		end,
	})
	Value = Reach:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
	})
    end
end)