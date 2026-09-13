local StateSpoofer
local State
local Mode

local hook
local heartbeat

local rakNetSupported = rakNetCheck('StateSpoofer')

StateSpoofer = vape.Categories.Utility:CreateModule({
	Name = 'StateSpoofer',
	Function = function(callback)
		if callback then
			if Mode.Value == 'RakNet' then
				-- Keep the existing no-RakNet protection.
				if not rakNetCheck('StateSpoofer') then
					StateSpoofer:Toggle()
					return
				end

				hook = function(packet)
					if packet.AsArray[1] == 0x1b then
						local data = packet.AsBuffer
						buffer.writeu8(
							data,
							25,
							Enum.HumanoidStateType[State.Value].Value + 32
						)
						packet:SetData(data)
					end
				end

				raknet.add_send_hook(hook)
			else
				-- Direct mode: use the old NetworkHumanoidState method.
				heartbeat = runService.Heartbeat:Connect(function()
					if entitylib.isAlive then
						sethiddenproperty(
							entitylib.character.Humanoid,
							'NetworkHumanoidState',
							Enum.HumanoidStateType[State.Value].Value
						)
					end
				end)
			end
		else
			-- Clean up whichever mode is currently active.
			if hook then
				raknet.remove_send_hook(hook)
				hook = nil
			end

			if heartbeat then
				heartbeat:Disconnect()
				heartbeat = nil
			end
		end
	end,
	Tooltip = 'Spoof humanoid states on the server.'
})

local states = {}
for _, v in Enum.HumanoidStateType:GetEnumItems() do
	if v.Name ~= 'None' then
		table.insert(states, v.Name)
	end
end

State = StateSpoofer:CreateDropdown({
	Name = 'Humanoid State',
	List = states
})

Mode = StateSpoofer:CreateDropdown({
	Name = 'Mode',
	List = {'RakNet', 'Direct'}
})

-- RakNet by default when supported, otherwise Direct.
Mode.Value = rakNetSupported and 'RakNet' or 'Direct'
