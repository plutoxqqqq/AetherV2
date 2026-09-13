run(function()
	local AutoRamil
	local Range
	local Sorts
	local Targets
	local UseTornado
	local TornadoRange

	AutoRamil = kits:CreateModule({
		Name = 'AutoRamil',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'airbender' then
						local localPosition = entitylib.character.RootPart.Position
						local ent = entitylib.EntityPosition({
							Origin = localPosition,
							Range = UseTornado.Enabled and TornadoRange.Value > Range.Value and TornadoRange.Value or Range.Value,
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sorts.Value]
						})
						local mag = ent and (localPosition - ent.RootPart.Position).Magnitude or math.huge

						if mag <= Range.Value and bedwars.AbilityController:canUseAbility('airbender_tornado', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('airbender_tornado')
						end

						if UseTornado.Enabled and mag <= TornadoRange.Value and bedwars.AbilityController:canUseAbility('airbender_moving_tornado', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('airbender_moving_tornado')
						end
					end
					task.wait()
				until not AutoRamil.Enabled
			end
		end,
		Tooltip = 'Automatically use ramil abilities on certain conditions.'
	})
	Targets = AutoRamil:CreateTargets({
		Players = true,
		NPCs = false
	})
	local methods = {'Damage', 'Distance'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end

	Sorts = AutoRamil:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Range = AutoRamil:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 25,
		Default = 25,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
	UseTornado = AutoRamil:CreateToggle({
		Name = 'Use Moving Tornado',
		Function = function(call)
			if TornadoRange then
				TornadoRange.Object.Visible = call
			end
		end
	})
	TornadoRange = AutoRamil:CreateSlider({
		Name = 'Tornado Range',
		Min = 1,
		Max = 35,
		Default = 25,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
end)
