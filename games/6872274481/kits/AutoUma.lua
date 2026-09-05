run(function()
	local AutoUma
	local Range
	local Limit
	local Animation
	local AutoSummon
	local HealSpirit
	local AttackSpirit
	local TargetItemDrops
	local Diamond
	local Emerald

	local function getAttackData()
		if Limit.Enabled then
			local tool = (store.hand.tool and store.hand.tool.Name == 'spirit_staff') and store.hand.tool or nil
			return tool, tool and getHotbar(tool) or nil
		end
		for i, v in store.inventory.inventory.items do
			if v.itemType == 'spirit_staff' then
				switchItem(v, 0)
				return v, i
			end
		end
		return
	end

	local function getDrops(localPosition, ItemDrops)
		local drop, lastmag = nil, Range.Value + 1
		for i, v in ItemDrops do
			if v.Name == 'emerald' and Emerald.Enabled or v.Name == 'diamond' and Diamond.Enabled then
				local magnitude = (localPosition - v.Position).Magnitude
				if magnitude <= lastmag and not entitylib.Wallcheck(localPosition, v.Position, {gameCamera, lplr.Character, v}) then
					drop, lastmag = v, magnitude
				end
			end
		end
		return drop
	end

	AutoUma = kits:CreateModule({
		Name = 'AutoUma',
		Function = function(call)
			if call then
				local items = collection('ItemDrop', AutoUma)
				repeat
					local staff = getAttackData()
					if staff then
						if TargetItemDrops.Enabled then
							local attackSpirits = (lplr:GetAttribute('ReadySummonedAttackSpirits') or 0)
							local healSpirits = (lplr:GetAttribute('ReadySummonedHealSpirits') or 0)

							if AutoSummon.Enabled then
								if AttackSpirit.Enabled and attackSpirits < 1 and getItem('summon_stone') then
									bedwars.AbilityController:useAbility('summon_attack_spirit')
								end

								if HealSpirit.Enabled and healSpirits < 1 and getItem('summon_stone') then
									bedwars.AbilityController:useAbility('summon_heal_spirit')
								end
							end

							if (healSpirits + attackSpirits) > 0 then
								local localPosition = entitylib.character.RootPart.Position
								local drop = getDrops(localPosition, items)

								if drop then
									local shootpos = localPosition + Vector3.new(0, 2, 0)
									local dir = CFrame.lookAt(localPosition, drop.Position + Vector3.new(0, (localPosition - drop.Position).Magnitude / 5, 0)).LookVector * 100

									bedwars.Handler:Get('ProjectileFire').Remote.instance:InvokeServer(
										staff,
										nil,
										attackSpirits > 0 and 'attack_spirit' or 'heal_spirit',
										shootpos,
										localPosition,
										dir,
										httpService:GenerateGUID(),
										{
											drawDurationSeconds = 1,
											shotId = httpService:GenerateGUID(false),
										},
										workspace:GetServerTimeNow() - 0.045
									)

									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.WIZARD_BALL_CAST)
										bedwars.AudioManager:playAudio(bedwars.SoundList.SPIRIT_SUMMONER_CHANGE_AFFINITY, {})
									end

									task.wait(1.5)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoUma.Enabled
			end
		end,
		Tooltip = 'Automatically throw spirits at item drops and opponents.'
	})
	Range = AutoUma:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 80,
		Default = 50,
		Decimal = 5,
		Suffix = function(val)
			return val >= 2 and 'studs' or 'stud'
		end
	})
	Animation = AutoUma:CreateToggle({
		Name = 'Animation',
		Default = true
	})
	Limit = AutoUma:CreateToggle({
		Name = 'Limit to item',
		Default = true
	})
	AutoSummon = AutoUma:CreateToggle({
		Name = 'Auto Summon',
		Function = function(call)
			if AttackSpirit then
				AttackSpirit.Object.Visible = call
				HealSpirit.Object.Visible = call
			end
		end,
		Tooltip = 'Automattically summons spirit for you'
	})
	HealSpirit = AutoUma:CreateToggle({
		Name = 'Use heal spirit',
		Default = true,
		Visible = false,
		Darker = true
	})
	AttackSpirit = AutoUma:CreateToggle({
		Name = 'Use attack spirit',
		Default = true,
		Visible = false,
		Darker = true
	})
	TargetItemDrops = AutoUma:CreateToggle({
		Name = 'Target item drops',
		Default = true,
		Function = function(call)
			if Emerald then
				Emerald.Object.Visible = call
				Diamond.Object.Visible = call
			end
		end
	})
	Emerald = AutoUma:CreateToggle({
		Name = 'Emerald',
		Darker = true,
		Default = true
	})
	Diamond = AutoUma:CreateToggle({
		Name = 'Diamond',
		Darker = true,
		Default = true
	})
end)