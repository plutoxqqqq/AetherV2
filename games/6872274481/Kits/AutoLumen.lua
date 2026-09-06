run(function()
	local AutoLumen
	local Targets
	local Range
	local FullCharge
	local Delay

	local Balance = bedwars.LumenBalance or {MIN_CHARGE_TIME = 0.65, MAX_CHARGE_TIME = 1.25}
	local Sword = 'light_sword'
	local cooldown = 0

	local function getChargeTime()
		local itemmeta = bedwars.ItemMeta[Sword]
		local charged = itemmeta and itemmeta.sword and itemmeta.sword.chargedAttack
		local minimum = charged and charged.minChargeTimeSec or Balance.MIN_CHARGE_TIME
		local maximum = charged and charged.maxChargeTimeSec or Balance.MAX_CHARGE_TIME
		return FullCharge.Enabled and maximum or minimum
	end

	local function chargedSwing()
		local charge = bedwars.SwordChargeController
		if charge:getChargeState() ~= bedwars.ChargeState.Idle then return end

		charge:startCharging(Sword)
		local started = charge:getChargeStartTime()
		if started == 0 then return end

		local target = getChargeTime() + 0.05
		repeat task.wait() until not AutoLumen.Enabled or not entitylib.isAlive or (tick() - started) >= target

		local chargeTime = tick() - started
		charge:stopCharging(Sword)
		if not AutoLumen.Enabled or not entitylib.isAlive then return end

		local tool = store.hand.tool
		if not tool or tool.Name ~= Sword then return end

		local charged = bedwars.ItemMeta[Sword].sword.chargedAttack
		if not (charged.skipSwingDamage and chargeTime > (charged.minChargeTimeSec or Balance.MIN_CHARGE_TIME)) then
			bedwars.SwordController:swingSwordAtMouse(chargeTime)
		end

		bedwars.SyncEvents.SwordChargedSwing:fire(lplr, tool, {chargeTime = chargeTime})
		cooldown = tick() + Delay.Value
	end

	AutoLumen = kits:CreateModule({
		Name = 'AutoLumen',
		Function = function(callback)
			if callback then
				cooldown = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'lumen' and store.hand.tool and store.hand.tool.Name == Sword and tick() >= cooldown then
						local target = entitylib.EntityMouse({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})

						if target then
							chargedSwing()
						end
					end
					task.wait(0.1)
				until not AutoLumen.Enabled
			end
		end,
		Tooltip = 'Charges the sword of light and releases a wave whenever an enemy is in front of you, Killaura skips this sword because it has a charged attack'
	})
	Targets = AutoLumen:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoLumen:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FullCharge = AutoLumen:CreateToggle({
		Name = 'Full charge',
		Default = true,
		Tooltip = 'Holds the swing to the maximum charge, an upgraded lumen only fires the multi beam at full charge'
	})
	Delay = AutoLumen:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Suffix = 'seconds'
	})

end)
