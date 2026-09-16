run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoFalconer
	local Send
	local SendRange
	local SendDelay
	local Recall
	local RecallDelay
	local nextSend, nextRecall = 0, 0

	local function show(option, visible)
		if option and option.Object then option.Object.Visible = visible end
	end

	AutoFalconer = kits:CreateModule({
		Name = 'AutoFalconer',
		Function = function(callback)
			if callback then
				nextSend, nextRecall = 0, 0
				repeat
					if entitylib.isAlive and util.IsKit('falconer') then
						local target = Send.Enabled and entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = SendRange.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						}) or nil

						if target and tick() >= nextSend and util.Ability.Ready('SEND_FALCON') then
							nextSend = tick() + SendDelay.Value
							util.Ability.Use('SEND_FALCON')
						elseif not target and Recall.Enabled and tick() >= nextRecall and util.Ability.Ready('RECALL_FALCON') then
							nextRecall = tick() + RecallDelay.Value
							util.Ability.Use('RECALL_FALCON')
						end
					end
					task.wait(0.1)
				until not AutoFalconer.Enabled
			end
		end,
		Tooltip = 'Sends the falcon at nearby enemies and recalls it when the area is clear'
	})
	Send = AutoFalconer:CreateToggle({
		Name = 'Auto send',
		Default = true,
		Function = function(callback)
			show(SendRange, callback)
			show(SendDelay, callback)
		end
	})
	SendRange = AutoFalconer:CreateSlider({
		Name = 'Send range',
		Min = 1,
		Max = 100,
		Default = 40,
		Darker = true,
		Suffix = util.Studs
	})
	SendDelay = AutoFalconer:CreateSlider({
		Name = 'Send delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
	Recall = AutoFalconer:CreateToggle({
		Name = 'Auto recall',
		Default = false,
		Function = function(callback)
			show(RecallDelay, callback)
		end
	})
	RecallDelay = AutoFalconer:CreateSlider({
		Name = 'Recall delay',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
end)
