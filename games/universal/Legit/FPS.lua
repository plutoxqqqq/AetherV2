run(function()
    --[[
		Frames counted from real render timestamps over a moving one second window, so the number is the
		framerate right now rather than a figure that slowly catches up with the machine.
	]]
    local FPS
    local label

    FPS = vape.Categories.Legit:CreateModule({
	Name = 'FPS',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			local frames, startClock = {}, os.clock()
			local nextUpdate = 0
			FPS:Clean(runService.RenderStepped:Connect(function()
				local now = os.clock()
				frames[#frames + 1] = now
				while frames[1] and frames[1] < now - 1 do
					table.remove(frames, 1)
				end
				if now >= nextUpdate then
					-- Four updates a second keeps the readout honest without flickering.
					nextUpdate = now + 0.25
					local elapsed = now - startClock
					local count = #frames
					-- Before the first second the window is not full yet, so scale the count by the time it covers.
					local rate = elapsed < 1 and (elapsed > 0 and count / elapsed or 0) or count
					label.Text = math.floor(rate + 0.5) .. ' FPS'
				end
			end))
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'Shows the current framerate',
    })
    FPS:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    FPS:CreateColorSlider({
	Name = 'Colour',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end,
    })
    label = Instance.new('TextLabel')
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 0.5
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.Text = 'inf FPS'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = FPS.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)
