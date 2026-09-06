run(function()
	local AutoSilas
	local SwapAura
	local PressAttack
	local Range
	local aura = ''

	local function getHurtAlly(origin)
		for _, v in entitylib.List do
			if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') and v.Health < v.MaxHealth and (v.RootPart.Position - origin).Magnitude <= Range.Value then
				return v
			end
		end
		return nil
	end

	AutoSilas = kits:CreateModule({
		Name = 'AutoSilas',
		Function = function(callback)
			if callback then
				aura = ''
				AutoSilas:Clean(bedwars.Handler:Get('UpdateRebellionAura').Remote:Connect(function(data)
					if data.player == lplr then
						aura = data.newAura
					end
				end))

				repeat
					if entitylib.isAlive and store.equippedKit == 'rebellion_leader' then
						local origin = entitylib.character.RootPart.Position
						local enemy = entitylib.EntityPosition({
							Origin = origin,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true
						})

						if PressAttack.Enabled and enemy and bedwars.AbilityController:canUseAbility('rebellion_shield', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('rebellion_shield')
						end

						if SwapAura.Enabled then
							local wanted = enemy and 'damage' or getHurtAlly(origin) and 'healing' or nil
							if wanted and aura ~= '' and aura ~= wanted and bedwars.AbilityController:canUseAbility('rebellion_aura_swap', {disableBlockedAbilityAlert = true}) then
								bedwars.AbilityController:useAbility('rebellion_aura_swap')
							end
						end
					end
					task.wait(0.1)
				until not AutoSilas.Enabled
			end
		end,
		Tooltip = 'Automatically swaps your aura and rallies your team'
	})
	Range = AutoSilas:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	SwapAura = AutoSilas:CreateToggle({
		Name = 'Swap aura',
		Default = true,
		Tooltip = 'Uses the damage aura near enemies and the healing aura near hurt allies'
	})
	PressAttack = AutoSilas:CreateToggle({
		Name = 'Press the attack',
		Default = true,
		Tooltip = 'Uses the shield ability when an enemy gets close'
	})
end)
