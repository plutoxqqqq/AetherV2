run(function()
	local AutoZeno
	local Targets
	local TargetMode
	local Limit
	local AutoShockWave
	local ShockwaveRange
	local UseStrike
	local UseStorm
	local Range
	local Delay

	local function getAttackData()
		if Limit.Enabled then
			local tool = store.hand.tool
			local itemType = tool and tool.Name
			if itemType and bedwars.WizardUtil:isWizardStaff(itemType) then
				return tool, itemType
			end
			return nil
		end

		for _, item in store.inventory.inventory.items do
			if bedwars.WizardUtil:isWizardStaff(item.itemType) and item.tool then
				switchItem(item.tool, 0)
				return item.tool, item.itemType
			end
		end

		return nil
	end

	local function canUseAbility(ability, itemType)
		if not bedwars.WizardUtil:hasAbility(itemType, ability) then return false end
		local controller = bedwars.WizardStaffController
		if not controller then return false end
		local success, allowed = pcall(controller.canCastAbility, controller, ability)
		if not success or not allowed then return false end
		success, allowed = pcall(bedwars.AbilityController.canUseAbility, bedwars.AbilityController, ability, {disableBlockedAbilityAlert = true})
		return success and allowed
	end

	local function useAbility(ability, target)
		local data = {
			target = ability == 'SHOCKWAVE' and Vector3.zero or target
		}
		return pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, ability, newproxy(true), data)
	end

	AutoZeno = kits:CreateModule({
		Name = 'AutoZeno',
		Function = function(callback)
			if callback then
				local attempts = {}
				repeat
					if entitylib.isAlive then
						local staff, itemType = getAttackData()

						if staff and itemType then
							local localPosition = entitylib.character.RootPart.Position
							local castRange = math.min(Range.Value, bedwars.WizardUtil:getCastRange(itemType))
							local shockwave = AutoShockWave.Enabled and bedwars.WizardUtil:hasAbility(itemType, 'SHOCKWAVE')
							local ent = entitylib.EntityPosition({
								Origin = localPosition,
								Range = math.max(castRange, shockwave and ShockwaveRange.Value or 0),
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Sort = sortmethods[TargetMode.Value]
							})

							if ent then
								local distance = (localPosition - ent.RootPart.Position).Magnitude
								local target = ent.RootPart.Position + ((ent.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing()))
								local abilities = {
									{'LIGHTNING_STORM', UseStorm.Enabled and distance <= castRange},
									{'SHOCKWAVE', shockwave and distance <= ShockwaveRange.Value},
									{'LIGHTNING_STRIKE', UseStrike.Enabled and distance <= castRange}
								}
								for _, ability in abilities do
									if ability[2] and (attempts[ability[1]] or 0) <= tick() and canUseAbility(ability[1], itemType) then
										attempts[ability[1]] = tick() + math.max(Delay.Value, 0.25)
										local success = useAbility(ability[1], target)
										if success then
											task.wait(Delay.Value)
											break
										end
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoZeno.Enabled
			end
		end,
		Tooltip = 'Automatically uses zeno\'s staff.'
	})
	Targets = AutoZeno:CreateTargets({
		Players = true,
		NPCs = false,
	})
	local methods = {'Damage', 'Distance'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	TargetMode = AutoZeno:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Limit = AutoZeno:CreateToggle({
		Name = 'Limit to item',
		Default = true
	})
	UseStrike = AutoZeno:CreateToggle({
		Name = 'Use Lightning Strike',
		Default = true
	})
	UseStorm = AutoZeno:CreateToggle({Name = 'Use Lightning Storm'})
	AutoShockWave = AutoZeno:CreateToggle({
		Name = 'Auto Shockwave',
		Function = function(call)
			if ShockwaveRange then
				ShockwaveRange.Object.Visible = call
			end
		end,
		Tooltip = 'Automatically uses the shockwave ability when a target is near',
	})
	ShockwaveRange = AutoZeno:CreateSlider({
		Name = 'Shockwave Range',
		Visible = false,
		Darker = true,
		Min = 1,
		Max = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end,
		Decimal = 5,
		Default = 12
	})
	Range = AutoZeno:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 35,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end,
		Decimal = 5
	})
	Delay = AutoZeno:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 10,
		Default = 0.5,
		Decimal = 5,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)
