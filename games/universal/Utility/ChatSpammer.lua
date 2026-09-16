run(function()
    local ChatSpammer
    local Lines
    local Mode
    local Delay
    local Hide

    local FLOOD_TEXT = 'You must wait before sending another message.'
    local legacySay
    local hookedLegacy
    local floodWatched = false

    -- The chat window is only built the first time it is opened. The old code indexed
    -- RCTScrollContentView straight away, so on a fresh session that lookup returned nil and the
    -- error killed the module before a single message went out - which is why the toggle looked
    -- like it did nothing.
    local function watchFloodMessages()
        if floodWatched then return end
        local chat = coreGui:FindFirstChild('ExperienceChat')
        if not chat then return end
        floodWatched = true

        local function hide(message)
            if message and message.ContentText == FLOOD_TEXT then
                pcall(function() message.Visible = false end)
            end
        end

        local function hookList(list)
            if not list then return end
            ChatSpammer:Clean(list.ChildAdded:Connect(function(child)
                task.defer(hide, child)
            end))
            for _, child in list:GetChildren() do
                hide(child)
            end
        end

        hookList(chat:FindFirstChild('RCTScrollContentView', true))
        ChatSpammer:Clean(chat.DescendantAdded:Connect(function(object)
            if object.Name == 'RCTScrollContentView' then
                hookList(object)
            end
        end))
    end

    local function textChannel()
        local configuration = textChatService.ChatInputBarConfiguration
        local channel = configuration and configuration.TargetTextChannel
        if channel then return channel end
        -- The bar only names a channel once chat has been focused at least once, so fall back to
        -- the general channel it would have picked anyway.
        local channels = textChatService:FindFirstChild('TextChannels')
        if not channels then return nil end
        return channels:FindFirstChild('RBXGeneral') or channels:FindFirstChildWhichIsA('TextChannel')
    end

    local function send(message)
        if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channel = textChannel()
            if not channel then return false end
            return (pcall(function() channel:SendAsync(message) end))
        end
        local request = legacySay
        if not request then
            local events = replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents')
            request = events and events:FindFirstChild('SayMessageRequest')
            legacySay = request
        end
        if not request then return false end
        return (pcall(function() request:FireServer(message, 'All') end))
    end

    local function installLegacyHide()
        local events = replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents')
        if not events then return end
        local event = events:FindFirstChild('OnNewSystemMessage')
        if not event then return end
        local connections = getconnections and getconnections(event.OnClientEvent) or nil
        local connection = connections and connections[1]
        if not connection or type(connection.Function) ~= 'function' then return end

        hookedLegacy = connection.Function
        local original = hookedLegacy
        if hookfunction then
            hookfunction(hookedLegacy, function(data, ...)
                if type(data) == 'table' and tostring(data.Message):find('ChatFloodDetector') then
                    return
                end
                return original(data, ...)
            end)
        end
    end

    local function restoreLegacyHide()
        if not hookedLegacy then return end
        pcall(function()
            if restorefunction then
                restorefunction(hookedLegacy)
            end
        end)
        hookedLegacy = nil
    end

    ChatSpammer = vape.Categories.Utility:CreateModule({
	Name = 'ChatSpammer',
	Function = function(callback)
		if callback then
			if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
				if Hide.Enabled then watchFloodMessages() end
			elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
				if Hide.Enabled then pcall(installLegacyHide) end
			else
				notif('ChatSpammer', 'unsupported chat', 5, 'warning')
				ChatSpammer:Toggle()
				return
			end

			local ind = 1
			repeat
				local lines = Lines.ListEnabled
				local message
				if Mode.Value == 'Order' and #lines > 0 then
					message = lines[ind] or lines[1]
					ind = (ind % #lines) + 1
				else
					message = #lines > 0 and lines[math.random(1, #lines)] or 'vxpe on top'
				end

				if type(message) == 'string' and message ~= '' then
					send(message)
				end

				task.wait(tonumber(Delay.Value) or 1)
			until not ChatSpammer.Enabled
		else
			restoreLegacyHide()
			floodWatched = false
			legacySay = nil
		end
	end,
	Tooltip = 'Automatically types in chat',
    })
    Lines = ChatSpammer:CreateTextList({ Name = 'Lines' })
    Mode = ChatSpammer:CreateDropdown({
	Name = 'Mode',
	List = { 'Random', 'Order' },
    })
    Delay = ChatSpammer:CreateSlider({
	Name = 'Delay',
	Min = 0.1,
	Max = 10,
	Default = 1,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
    })
    Hide = ChatSpammer:CreateToggle({
	Name = 'Hide Flood Message',
	Default = true,
	Function = function()
		if ChatSpammer.Enabled then
			ChatSpammer:Toggle()
			ChatSpammer:Toggle()
		end
	end,
    })
end)
