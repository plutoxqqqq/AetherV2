run(function()
    local Ping
    local label

    -- The engine's own ping figures. Data Ping is what the client actually measures against the server,
    -- and it refreshes faster than GetNetworkPing, which is only recomputed once a second.
    local stats = game:GetService('Stats')
    local function dataPing()
		local value = stats.Network and stats.Network.ServerStatsItem and stats.Network.ServerStatsItem['Data Ping']
		if not value then return nil end
		local ok, ping = pcall(function() return value:GetValue() end)
		return ok and tonumber(ping) or nil
    end

    Ping = vape.Categories.Legit:CreateModule({
	Name = 'Ping',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			-- Four samples a second with the median of the last few shown: a single spike stops telling you
			-- your connection is 400ms when it was one packet, and the number still moves with the real link.
			local samples = {}
			repeat
				local ping = dataPing()
				if not ping then ping = lplr:GetNetworkPing() * 1000 end
				if ping then
					table.insert(samples, ping)
					if #samples > 5 then table.remove(samples, 1) end
					local sorted = table.clone(samples)
					table.sort(sorted)
					label.Text = math.round(sorted[math.ceil(#sorted / 2)]) .. ' ms'
				end
				task.wait(0.25)
			until not Ping.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'Shows the current connection speed to the roblox server',
    })
    Ping:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    Ping:CreateColorSlider({
	Name = 'Colour',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end,
    })
    label = Instance.new('TextLabel')
    label.Size = UDim2.new(0, 100, 0, 41)
    label.BackgroundTransparency = 0.5
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.Text = '0 ms'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = Ping.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)
