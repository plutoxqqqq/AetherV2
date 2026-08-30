run(function()
	local AutoEmber
	local Targets
	local Range
	local Delay
	local Limit

	AutoEmber = kits:CreateModule({
		Name = 'AutoEmber',
		Function = function(call)
			if call then
				local clock = os.clock()

				repeat
					local tool = entitylib.isAlive and getItem('infernal_saber')
					if tool and (not Limit.Enabled or store.hand.tool == tool) and (Delay.Value <= 0 or os.clock() - clock >= Delay.Value) and entitylib.EntityPosition({
						Range = Range.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					}) then
						bedwars.Handler:Get('HellBladeRelease'):Fire('SendToServer', {
							chargeTime = 1,
							weapon = tool,
							player = lplr
						})
						clock = os.clock()
					end
					task.wait()
				until not AutoEmber.Enabled
			end
		end,
		Tooltip = 'Automatically releases the infernal saber charge when a target is in range'
	})
	Targets = AutoEmber:CreateTargets({
		Players = true,
		NPCs = false
	})
	Delay = AutoEmber:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
	Range = AutoEmber:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Limit = AutoEmber:CreateToggle({Name = 'Limit to item'})
end)