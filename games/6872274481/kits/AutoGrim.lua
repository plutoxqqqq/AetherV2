run(function()
	local AutoGrim
	local Range
	local Health
	local Delay

	local Legit = getFunctionRange(bedwars.GrimReaperController.registerSoulInteractions) or 0

	AutoGrim = kits:CreateModule({
		Name = 'AutoGrim',
		Function = function(callback)
			if callback then
				local souls = collection(bedwars.GrimReaperController.soulsByPosition, AutoGrim)
				local cooldown = 0

				repeat
					if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') * (Health.Value / 100)) and not lplr.Character:GetAttribute('GrimReaperChannel') and (Delay.Value <= 0 or tick() - cooldown >= Delay.Value) then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in souls do
							if (localPosition - v.Position).Magnitude <= Range.Value then
								bedwars.Handler:Get('ConsumeGrimReaperSoul'):Fire('CallServer', {
									secret = v:GetAttribute('GrimReaperSoulSecret')
								})
								cooldown = tick()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoGrim.Enabled
			end
		end,
		Tooltip = 'Automatically consumes nearby souls when your health drops low'
	})
	Range = AutoGrim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 120,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoGrim:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Health = AutoGrim:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 25,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Only eats a soul once your health drops to this share of your maximum'
	})
	Delay = AutoGrim:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 10,
		Suffix = 'seconds'
	})
end)