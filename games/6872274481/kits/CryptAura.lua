run(function()
	local CryptAura
	local Range
	local Delay
	local nextClaim = 0

	local claimed = setmetatable({}, {__mode = 'k'})

	local Activate = bedwars.Handler:Get('ActivateGravestone')

	CryptAura = kits:CreateModule({
		Name = 'CryptAura',
		Function = function(callback)
			if callback then
				nextClaim = 0
				table.clear(claimed)

				repeat
					if entitylib.isAlive and store.equippedKit == 'necromancer' and tick() >= nextClaim then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('Gravestone') do
							if not claimed[v] and v:GetAttribute('GravestoneSecret') and (v:GetPivot().Position - origin).Magnitude <= Range.Value then
								claimed[v] = true
								nextClaim = tick() + Delay.Value
								Activate:Fire('CallServer', {
									secret = v:GetAttribute('GravestoneSecret'),
									position = v:GetAttribute('GravestonePosition'),
									skeletonData = {
										associatedPlayerUserId = v:GetAttribute('GravestonePlayerUserId'),
										armorType = v:GetAttribute('ArmorType'),
										weaponType = v:GetAttribute('SwordType'),
										bowType = v:GetAttribute('BowType')
									}
								})
								break
							end
						end
					end
					task.wait(0.1)
				until not CryptAura.Enabled
			end
		end,
		Tooltip = 'Automatically claims the gravestones enemies drop into your undead army'
	})
	Range = CryptAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = CryptAura:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)