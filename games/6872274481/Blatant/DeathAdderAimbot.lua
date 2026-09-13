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
end
