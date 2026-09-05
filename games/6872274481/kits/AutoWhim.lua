run(function()
	local AutoWhim
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local nextFire = 0

	local function getSpellSource()
		local util = bedwars.MageKitUtil
		local element = bedwars.BalanceFile.MAGE_ELEMENT_CYCLE[(lplr:GetAttribute('MageElementIndex') or 0) + 1]
		if not element or table.find(util.getUnlockedMageElements(lplr), element) == nil then
			element = 'BASE'
		end

		local meta = util.MageElementMeta[element]
		return meta and meta.projectileSource or nil
	end

	local function castSpell()
		local item = getItem('mage_spellbook')
		local source = item and getSpellSource() or nil
		local target = source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil
		if not target then return end

		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if fireProjectile(item, 'mage_spellbook', source.projectileType('mage_spellbook'), target) then
				nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end

	AutoWhim = kits:CreateModule({
		Name = 'AutoWhim',
		Function = function(callback)
			if callback then
				nextFire = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'mage' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 and tick() >= nextFire then
						castSpell()
					end
					task.wait(0.1)
				until not AutoWhim.Enabled
			end
		end,
		Tooltip = 'Automatically casts Whim\'s magic book at whoever you\'re meleeing'
	})
	Targets = AutoWhim:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoWhim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoWhim:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoWhim:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)