run(function()
	local AutoEldric
	local Targets
	local Range
	local Priority
	local Allies
	local Health
	local linked

	local Link = bedwars.Handler:Get('WarlockLinkTarget')

	local function getHurtAlly(origin)
		local best, bestHealth
		for _, v in entitylib.List do
			if not v.Targetable and v.Player and v ~= entitylib.character and (v.RootPart.Position - origin).Magnitude <= Range.Value then
				local ratio = v.Health / v.MaxHealth
				if ratio <= (Health.Value / 100) and (not bestHealth or ratio < bestHealth) then
					best, bestHealth = v, ratio
				end
			end
		end
		return best
	end

	local function link(target)
		if bedwars.AbilityController:canUseAbility('WARLOCK_LINK', {disableBlockedAbilityAlert = true}) then
			bedwars.AbilityController:useAbility('WARLOCK_LINK')
			task.wait(store.ping.total or 0.1)
		end

		if not AutoEldric.Enabled or not target.Character or not target.Character.Parent then return end
		linked = target.Character
		Link:Fire('CallServer', {target = target.Character})
	end

	AutoEldric = kits:CreateModule({
		Name = 'AutoEldric',
		Function = function(callback)
			if callback then
				linked = nil

				repeat
					if entitylib.isAlive and store.equippedKit == 'warlock' and store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
						local origin = entitylib.character.RootPart.Position
						local target

						if Priority.Value == 'Teammates' and Allies.Enabled then
							target = getHurtAlly(origin)
						end

						if not target then
							target = entitylib.EntityPosition({
								Origin = origin,
								Range = Range.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Wallcheck = Targets.Walls.Enabled
							})
						end

						if not target and Allies.Enabled then
							target = getHurtAlly(origin)
						end

						if target and target.Character ~= linked then
							link(target)
						elseif not target then
							linked = nil
						end
					end
					task.wait(0.1)
				until not AutoEldric.Enabled
			end
		end,
		Tooltip = 'Automatically links the warlock staff to enemies or hurt teammates'
	})
	Targets = AutoEldric:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoEldric:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 24,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoEldric:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(bedwars.WarlockBalance and bedwars.WarlockBalance.SELECTOR_RANGE or 24)
		end
	})
	Priority = AutoEldric:CreateDropdown({
		Name = 'Priority',
		List = {'Enemies', 'Teammates'},
		Tooltip = 'Which side the staff links first when both are in range'
	})
	Allies = AutoEldric:CreateToggle({
		Name = 'Heal teammates',
		Default = true,
		Tooltip = 'Links a hurt teammate when no enemy is in range'
	})
	Health = AutoEldric:CreateSlider({
		Name = 'Ally health',
		Min = 1,
		Max = 100,
		Default = 70,
		Darker = true,
		Suffix = function()
			return '%'
		end
	})

end)
