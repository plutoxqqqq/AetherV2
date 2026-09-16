run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoRaven
	local Transform
	local TransformRange
	local Send
	local SendRange
	local Delay
	local nextAction = 0

	local function show(option, visible)
		if option and option.Object then option.Object.Visible = visible end
	end

	AutoRaven = kits:CreateModule({
		Name = 'AutoRaven',
		Function = function(callback)
			if callback then
				nextAction = 0
				repeat
					if entitylib.isAlive and util.IsKit('raven') and tick() >= nextAction then
						local range = math.max(Transform.Enabled and TransformRange.Value or 0, Send.Enabled and SendRange.Value or 0)
						local target = range > 0 and entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = range,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						}) or nil

						if target and Transform.Enabled and util.Ability.Ready('raven_transform') then
							nextAction = tick() + Delay.Value
							util.Ability.Use('raven_transform')
						elseif target and Send.Enabled and util.Ability.Ready('raven_send_request') then
							nextAction = tick() + Delay.Value
							util.Ability.Use('raven_send_request')
						end
					end
					task.wait(0.1)
				until not AutoRaven.Enabled
			end
		end,
		Tooltip = 'Transforms into the raven or sends it at nearby enemies'
	})
	Transform = AutoRaven:CreateToggle({
		Name = 'Auto transform',
		Default = false,
		Function = function(callback)
			show(TransformRange, callback)
		end
	})
	TransformRange = AutoRaven:CreateSlider({
		Name = 'Transform range',
		Min = 1,
		Max = 80,
		Default = 30,
		Darker = true,
		Suffix = util.Studs
	})
	Send = AutoRaven:CreateToggle({
		Name = 'Auto send',
		Default = true,
		Function = function(callback)
			show(SendRange, callback)
		end
	})
	SendRange = AutoRaven:CreateSlider({
		Name = 'Send range',
		Min = 1,
		Max = 100,
		Default = 50,
		Darker = true,
		Suffix = util.Studs
	})
	Delay = AutoRaven:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)
