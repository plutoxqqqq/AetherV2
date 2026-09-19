run(function()
    local Speedmeter
    local label

    Speedmeter = vape.Categories.Legit:CreateModule({
	Name = 'Speedmeter',
	Category = 'Hud',
	Function = function(callback)
		if callback then
			-- Read straight off the character's velocity instead of differencing two positions: position
			-- sampling lags, misses vertical movement and only ever shows an average over the gap.
			local smooth = 0
			repeat
				local speed = 0
				if entitylib.isAlive then
					local velocity = entitylib.character.RootPart.AssemblyLinearVelocity
					speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				end
				-- A light ease keeps the last digit from flickering without hiding real changes.
				smooth = smooth == 0 and speed or smooth + (speed - smooth) * 0.45
				label.Text = math.floor(smooth + 0.5) .. ' sps'
				task.wait(0.1)
			until not Speedmeter.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'A label showing the average velocity in studs',
    })
    Speedmeter:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end,
    })
    Speedmeter:CreateColorSlider({
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
    label.Text = '0 sps'
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundColor3 = Color3.new()
    label.Parent = Speedmeter.Children
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = label
end)

-- Executor FPS cap control. This intentionally uses only the documented executor
-- capability and restores Roblox's normal cap when disabled.
