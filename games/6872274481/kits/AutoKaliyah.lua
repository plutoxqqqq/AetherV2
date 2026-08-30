run(function()
	local AutoKaliyah
	local Range
	local Stacks
	local Delay
	local NoSlow

	local Legit = getFunctionRange(bedwars.DragonSlayerController.hasEligiblePunchTarget) or 14.4
	local modifier, old
	local noSlowUntil = 0

	local function punch()
		if NoSlow.Enabled then
			if not old then
				modifier = bedwars.SprintController:getMovementStatusModifier()
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if NoSlow.Enabled and tick() < noSlowUntil and tab and tab.moveSpeedMultiplier == 0 then
						tab.moveSpeedMultiplier = 1
					end
					return old(self, tab)
				end

				AutoKaliyah:Clean(function()
					modifier.addModifier = old
					modifier, old = nil, nil
					noSlowUntil = 0
				end)
			end
			noSlowUntil = math.max(noSlowUntil, tick() + Delay.Value + 0.1)
		end

		task.wait(Delay.Value)
		bedwars.AbilityController:useAbility('dragon_slayer_punch')
	end

	AutoKaliyah = kits:CreateModule({
		Name = 'AutoKaliyah',
		Function = function(call)
			if call then
				repeat
					if entitylib.isAlive and store.equippedKit == 'dragon_slayer' and bedwars.AbilityController:canUseAbility('dragon_slayer_punch', {disableBlockedAbilityAlert = true}) then
						local localPosition = entitylib.character.RootPart.Position
						for target, v in bedwars.DragonSlayerController.dragonEmblems do
							if v.stackCount >= Stacks.Value and target.PrimaryPart and (target.PrimaryPart.Position - localPosition).Magnitude <= Range.Value then
								punch()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoKaliyah.Enabled
			end
		end,
		Tooltip = 'Automatically uses the "punch" ability from kaliyah'
	})
	NoSlow = AutoKaliyah:CreateToggle({
		Name = 'No Slow',
		Default = true,
		Tooltip = 'Prevents you from being slowed down after using the "Punch" ability'
	})
	Range = AutoKaliyah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 18,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoKaliyah:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Stacks = AutoKaliyah:CreateSlider({
		Name = 'Stacks',
		Min = 1,
		Max = 3,
		Default = 1,
		Suffix = function(val)
			return val <= 1 and 'stack' or 'stacks'
		end,
		Tooltip = 'How many emblems a target needs before the punch fires, 3 stacks deals 25 damage against a wall instead of 10'
	})
	Delay = AutoKaliyah:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
end)