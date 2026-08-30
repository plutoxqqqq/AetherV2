run(function()
	local AutoSophia
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local nextFire = 0
	local nextSwap = 0

	local staffs = {'frost_staff_3', 'frost_staff_2', 'frost_staff_1'}

	local function getStaff()
		for _, itemType in staffs do
			local item = getItem(itemType)
			if item then
				return item, itemType
			end
		end
		return nil
	end

	local function shootStaff()
		local item, itemType = getStaff()
		local source = item and bedwars.ItemMeta[itemType].projectileSource or nil
		local target = source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil
		if not target then return end

		local ready = bedwars.FrostyGunController.projectileMode == bedwars.FrostyGunMode.PROJECTILE
		local swapping = not ready and tick() >= nextSwap and bedwars.AbilityController:canUseAbility('frosty_gun_swap', {disableBlockedAbilityAlert = true})
		if not ready and not swapping then return end

		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if ready then
				if fireProjectile(item, itemType, source.projectileType(itemType), target) then
					nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
					task.wait(SwitchDelay.Value)
				end
			else
				nextSwap = tick() + 1
				bedwars.AbilityController:useAbility('frosty_gun_swap')
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end

	AutoSophia = kits:CreateModule({
		Name = 'AutoSophia',
		Function = function(callback)
			if callback then
				nextFire, nextSwap = 0, 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'winter_lady' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 and tick() >= nextFire then
						shootStaff()
					end
					task.wait(0.1)
				until not AutoSophia.Enabled
			end
		end,
		Tooltip = 'Automatically shoots Sophia\'s frost staff at whoever you\'re meleeing, swapping it out of mist mode when needed'
	})
	Targets = AutoSophia:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoSophia:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoSophia:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoSophia:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)