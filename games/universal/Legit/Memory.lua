run(function()
    local Memory
    local label

    -- The engine's own performance counter is the only memory figure a client can read, so it is looked
    -- up once and then read directly rather than re-walking the Stats tree every second.
    local stats = game:GetService('Stats')
    local memoryStat = stats:FindFirstChild('PerformanceStats') and stats.PerformanceStats:FindFirstChild('Memory')
    local function usedMemory()
		if not memoryStat then return nil end
		local ok, value = pcall(function() return memoryStat:GetValue() end)
		return ok and tonumber(value) or nil
    end

    Memory = vape.Categories.Legit:CreateModule({
	Name = 'Memory',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			repeat
				local megabytes = usedMemory()
				if megabytes then label.Text = math.floor(megabytes + 0.5) .. ' MB' end
				task.wait(0.5)
			until not Memory.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'A label showing the memory currently used by roblox',
    })
    Memory:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    Memory:CreateColorSlider({
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
    label.Text = '0 MB'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = Memory.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)
