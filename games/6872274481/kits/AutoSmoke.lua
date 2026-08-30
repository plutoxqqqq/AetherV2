run(function()
	local AutoSmoke
	local Range
	local Health
	local Delay
	local nextBomb = 0

	AutoSmoke = kits:CreateModule({
		Name = 'AutoSmoke',
		Function = function(callback)
			if callback then
				nextBomb = 0

				repeat
					local bomb = entitylib.isAlive and store.equippedKit == 'smoke' and tick() >= nextBomb and getItem('smoke_bomb') or nil
					if bomb and entitylib.character.Health <= (entitylib.character.MaxHealth * (Health.Value / 100)) then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true
						})

						if target then
							nextBomb = tick() + Delay.Value
							bedwars.Handler:Get('ConsumeItem'):Fire('CallServer', {item = bomb.tool})
						end
					end
					task.wait(0.1)
				until not AutoSmoke.Enabled
			end
		end,
		Tooltip = 'Automatically pops a smoke bomb when you are low with enemies nearby'
	})
	Range = AutoSmoke:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Health = AutoSmoke:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 50,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Pops the bomb at or below this much health'
	})
	Delay = AutoSmoke:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 15,
		Default = 5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)