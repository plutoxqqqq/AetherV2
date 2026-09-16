run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoBlockKicker
	local Kick
	local KickRange
	local KickDelay
	local Stomp
	local StompTargets
	local StompRange
	local StompDelay
	local nextKick, nextStomp = 0, 0

	local function show(option, visible)
		if option and option.Object then option.Object.Visible = visible end
	end

	AutoBlockKicker = kits:CreateModule({
		Name = 'AutoBlockKicker',
		Function = function(callback)
			if callback then
				nextKick, nextStomp = 0, 0
				repeat
					if entitylib.isAlive and util.IsKit('block_kicker') then
						if Kick.Enabled and tick() >= nextKick and util.Ability.Ready('BLOCK_KICK') then
							local target = entitylib.EntityPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = KickRange.Value,
								Part = 'RootPart',
								Players = true,
								Wallcheck = true
							})
							if target then
								nextKick = tick() + KickDelay.Value
								util.Ability.Use('BLOCK_KICK')
							end
						end
						if Stomp.Enabled and tick() >= nextStomp and util.Ability.Ready('BLOCK_STOMP') then
							local found = #entitylib.AllPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = StompRange.Value,
								Part = 'RootPart',
								Players = true
							})
							if found >= StompTargets.Value then
								nextStomp = tick() + StompDelay.Value
								util.Ability.Use('BLOCK_STOMP')
							end
						end
					end
					task.wait(0.1)
				until not AutoBlockKicker.Enabled
			end
		end,
		Tooltip = 'Kicks a block at nearby enemies and stomps once enough of them are around'
	})
	Kick = AutoBlockKicker:CreateToggle({
		Name = 'Auto kick',
		Default = true,
		Function = function(callback)
			show(KickRange, callback)
			show(KickDelay, callback)
		end
	})
	KickRange = AutoBlockKicker:CreateSlider({
		Name = 'Kick range',
		Min = 1,
		Max = 60,
		Default = 25,
		Darker = true,
		Suffix = util.Studs
	})
	KickDelay = AutoBlockKicker:CreateSlider({
		Name = 'Kick delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
	Stomp = AutoBlockKicker:CreateToggle({
		Name = 'Auto stomp',
		Default = true,
		Function = function(callback)
			show(StompTargets, callback)
			show(StompRange, callback)
			show(StompDelay, callback)
		end
	})
	StompTargets = AutoBlockKicker:CreateSlider({
		Name = 'Stomp targets',
		Min = 1,
		Max = 8,
		Default = 2,
		Darker = true
	})
	StompRange = AutoBlockKicker:CreateSlider({
		Name = 'Stomp range',
		Min = 1,
		Max = 60,
		Default = 20,
		Darker = true,
		Suffix = util.Studs
	})
	StompDelay = AutoBlockKicker:CreateSlider({
		Name = 'Stomp delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
end)
