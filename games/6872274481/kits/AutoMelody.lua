run(function()
	local AutoMelody
	local Range
	local SelfHeal
	local TeammateHeal
	local UseHotbar
	local SwitchBack

	AutoMelody = kits:CreateModule({
		Name = 'AutoMelody',
		Function = function(callback)
			if callback then
				repeat
					local mag, hp, ent = Range.Value, math.huge, nil
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in entitylib.List do
							if v.Player and (SelfHeal.Enabled or v.Player ~= lplr) and (TeammateHeal.Enabled and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') or not TeammateHeal.Enabled and SelfHeal.Enabled and v.Player == lplr) then
								local newmag = (localPosition - v.RootPart.Position).Magnitude
								if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
									mag, hp, ent = newmag, v.Health, v
								end
							end
						end
					end

					local guitar = ent and getItem('guitar')
					if guitar then
						local previousSlot, previousTool = store.inventory.hotbarSlot, store.hand.tool

						if UseHotbar.Enabled then
							local slot = getHotbar(guitar.tool)
							if slot then
								hotbarSwitch(slot)
							end
						end

						bedwars.Handler:Get('GuitarHeal'):Fire('SendToServer', {
							healTarget = ent.Character
						})

						if UseHotbar.Enabled and SwitchBack.Enabled then
							if previousSlot and previousSlot ~= store.inventory.hotbarSlot then
								hotbarSwitch(previousSlot)
							elseif previousTool then
								switchItem(previousTool)
							end
						end
					end
					task.wait(0.1)
				until not AutoMelody.Enabled
			end
		end,
		Tooltip = 'Automatically uses the guitar to heal ur teammates/urself'
	})
	SelfHeal = AutoMelody:CreateToggle({
		Name = 'Self Heal',
		Default = true
	})
	TeammateHeal = AutoMelody:CreateToggle({
		Name = 'Teammate Heal',
		Default = true
	})
	Range = AutoMelody:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Decimal = 4
	})
	UseHotbar = AutoMelody:CreateToggle({
		Name = 'Use hotbar',
		Function = function(callback)
			if SwitchBack then
				SwitchBack.Object.Visible = callback
			end
		end,
		Tooltip = 'Visibly swaps onto the guitar slot before healing instead of playing it silently'
	})
	SwitchBack = AutoMelody:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'Returns to whatever you were holding after the heal'
	})
end)