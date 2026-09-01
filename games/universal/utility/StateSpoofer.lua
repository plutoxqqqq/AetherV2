run(function()
    local StateSpoofer
    local State

    local hook

    StateSpoofer = vape.Categories.Utility:CreateModule({
	Name = 'StateSpoofer',
	Function = function(callback)
		if callback then
			if not rakNetCheck('StateSpoofer') then
				StateSpoofer:Toggle()
				return
			end

			hook = function(packet)
				-- Guarded so a short/unexpected packet can never crash the network thread.
				pcall(function()
					if packet.AsArray and packet.AsArray[1] == 0x1b then
						local data = packet.AsBuffer
						local stateEnum = State and Enum.HumanoidStateType[State.Value]
						if data and stateEnum and buffer.len(data) >= 26 then
							buffer.writeu8(data, 25, stateEnum.Value + 32)
							packet:SetData(data)
						end
					end
				end)
			end

			raknet.add_send_hook(hook)
		elseif hook then
			raknet.remove_send_hook(hook)
			hook = nil
		end
	end,
	Tooltip = 'Spoof humanoid states on the server',
    })
    local states = {}
    for _, v in Enum.HumanoidStateType:GetEnumItems() do
	if v.Name ~= 'None' then
		table.insert(states, v.Name)
	end
    end
    State = StateSpoofer:CreateDropdown({
	Name = 'Humanoid State',
	List = states,
    })
end)