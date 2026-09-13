run(function()
	local AutoCogsworth
	local Targets
	local Collect
	local Steal
	local Range
	local Delay
	local Overclock
	local OverclockRange
	local nextCollect = 0
	local nextOverclock = 0

	local function getBots()
		local controller = bedwars.GatherBotBasicController
		return controller and controller.gatherBotMap or {}
	end

	AutoCogsworth = kits:CreateModule({
		Name = 'AutoCogsworth',
		Function = function(callback)
			if callback then
				nextCollect = 0
				nextOverclock = 0

				repeat
					if entitylib.isAlive then
						local origin = entitylib.character.RootPart.Position

						if Collect.Enabled and tick() >= nextCollect then
							for bot in getBots() do
								if not bot.Parent then continue end
								local owner = bot:GetAttribute('PlacedByUserId')
								if not Steal.Enabled and owner ~= lplr.UserId then continue end
								if (bot:GetAttribute('HeldItemAmount') or 0) <= 0 then continue end
								if (bot:GetPivot().Position - origin).Magnitude > Range.Value then continue end

								bedwars.Handler:Get('GatherBotCollectItems'):Fire('SendToServer', {
									player = lplr,
									gatherBot = bot
								})
								nextCollect = tick() + Delay.Value
								break
							end
						end

						if Overclock.Enabled and store.equippedKit == 'steam_engineer' and tick() >= nextOverclock and bedwars.AbilityController:canUseAbility('STEAM_ENGINEER_OVERCLOCK', {disableBlockedAbilityAlert = true}) then
							local found = #entitylib.AllPosition({
								Range = OverclockRange.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled
							}) > 0

							if found then
								nextOverclock = tick() + 1
								bedwars.AbilityController:useAbility('STEAM_ENGINEER_OVERCLOCK')
							end
						end
					end
					task.wait(0.1)
				until not AutoCogsworth.Enabled
			end
		end,
		Tooltip = 'Empties gather bots from across the map and overclocks when a fight starts'
	})

	Targets = AutoCogsworth:CreateTargets({
		Players = true,
		NPCs = true
	})
	Collect = AutoCogsworth:CreateToggle({
		Name = 'Collect bots',
		Default = true,
		Tooltip = 'The games own collect prompt stops at 10 studs, the server never checks it'
	})
	Steal = AutoCogsworth:CreateToggle({
		Name = 'Steal enemy bots',
		Tooltip = 'Also empties gather bots that somebody else placed'
	})
	Range = AutoCogsworth:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 500,
		Default = 250,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoCogsworth:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 100,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	Overclock = AutoCogsworth:CreateToggle({
		Name = 'Overclock',
		Default = true,
		Function = function(callback)
			OverclockRange.Object.Visible = callback
		end
	})
	OverclockRange = AutoCogsworth:CreateSlider({
		Name = 'Overclock range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)
