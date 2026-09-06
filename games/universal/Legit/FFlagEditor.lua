run(function()
    local FFlag
    local Flags

    local function ChangeFFlag(suc)
	if not suc or not FFlag.Enabled then
		return
	end
	local success, json = pcall(function()
		return httpService:JSONDecode(Flags.Value)
	end)

	if not success or typeof(json) ~= 'table' then
		notif('AetherV2', 'Invalid json format for fflag', 12, 'warning')
		return
	end

	for i, v in json do
		i = i:gsub('DFInt', '')
			:gsub('DFFlag', '')
			:gsub('FFlag', '')
			:gsub('FInt', '')
			:gsub('DFString', '')
			:gsub('FString', '')

		pcall(setfflag, i, tostring(v))
	end

	notif('AetherV2', 'FFlags applied, Go in a new game to take effect', 12, 'info')
    end

    FFlag = vape.Categories.Legit:CreateModule({
	Name = 'FFlagEditor',
	Disabled = not setfflag,
	DsiabledTooltip = 'This module requires a specific function to work, Which your executor (' .. ({
		identifyexecutor(),
	})[1] .. ') does not have',
	Function = function(call)
		if call then
			ChangeFFlag(true)
		else
			notif('AetherV2', 'Inorder to disable fflags you have applied, You need to restart roblox', 20, 'info')
		end
	end,
    })

    Flags = FFlag:CreateTextBox({
	Name = 'FFlags',
	Placeholder = 'json format only',
	Function = ChangeFFlag,
    })
end)
