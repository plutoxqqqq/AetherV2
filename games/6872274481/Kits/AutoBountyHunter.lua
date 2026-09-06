run(function()
	local AutoBountyHunter
	local Track
	local Reroll
	local RerollRange
	local Delay

	local trackCooldown, rerollCooldown = 0, 0
	local trackAbilities = {'bounty_hunter_4', 'bounty_hunter_3', 'bounty_hunter_2', 'bounty_hunter_1'}

	local function getTarget()
		local kit = bedwars.Store:getState().Kit
		return kit and kit.bountyHunterTarget
	end

	local function getTrackAbility()
		local enabled = bedwars.AbilityController.enabledAbilities
		for _, ability in trackAbilities do
			if enabled and enabled[ability] then
				return ability
			end
		end

		local level = bedwars.BountyHunterUtil and bedwars.BountyHunterUtil.getBountyHunterLevel(lplr) or 0
		return 'bounty_hunter_'..math.clamp(level + 1, 1, 4)
	end

	local function useAbility(ability)
		if not bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
			return false
		end
		bedwars.AbilityController:useAbility(ability)
		return true
	end

	AutoBountyHunter = kits:CreateModule({
		Name = 'AutoBountyHunter',
		Function = function(callback)
			if callback then
				trackCooldown, rerollCooldown = 0, 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'bounty_hunter' then
						local target = getTarget()
						local ent = target and entitylib.getEntity(target)

						if Track.Enabled and target and tick() >= trackCooldown and useAbility(getTrackAbility()) then
							trackCooldown = tick() + Delay.Value
						end

						if Reroll.Enabled and tick() >= rerollCooldown then
							local distance = ent and ent.RootPart and (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude or math.huge
							if distance > RerollRange.Value and useAbility('bounty_hunter_reroll') then
								rerollCooldown = tick() + 1
							end
						end
					end
					task.wait(0.1)
				until not AutoBountyHunter.Enabled
			end
		end,
		Tooltip = 'Keeps the bounty tracker up on your target and rerolls bounties you cannot reach'
	})
	Track = AutoBountyHunter:CreateToggle({
		Name = 'Auto track',
		Default = true,
		Tooltip = 'Uses the tracking ability whenever it comes off cooldown, the marker lasts 15 seconds'
	})
	Delay = AutoBountyHunter:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = 'seconds'
	})
	Reroll = AutoBountyHunter:CreateToggle({
		Name = 'Auto reroll',
		Tooltip = 'Rerolls the bounty when your target is dead, gone or further away than the range below'
	})
	RerollRange = AutoBountyHunter:CreateSlider({
		Name = 'Reroll range',
		Min = 10,
		Max = 500,
		Default = 250,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})

end)
