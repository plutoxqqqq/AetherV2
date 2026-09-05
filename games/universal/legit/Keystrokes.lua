run(function()
    local Keystrokes, Style, Color, ShowSpace, ShowMouse, ShowLeft, ShowMiddle, ShowRight, ShowCPS
    local keys, inputKeys, holder, clicks = {}, {}, nil, {L = {}, R = {}}
    local clickHeads = {L = 1, R = 1}
    local cpsGeneration = 0
    local function layout()
        if not Keystrokes.Children then return end
        local mouseVisible = ShowMouse.Enabled and (ShowLeft.Enabled or ShowMiddle.Enabled or ShowRight.Enabled)
        local width = mouseVisible and 182 or 110
        local height = (ShowSpace.Enabled or (mouseVisible and ShowCPS.Enabled)) and 107 or 78
        Keystrokes.Children.Size = UDim2.fromOffset(width, height)
    end
    local function make(id, position, size, text, input)
        if keys[id] then keys[id].Key:Destroy() end
        local key = Instance.new('Frame'); key.Name = tostring(id); key.Position = position; key.Size = size; key.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value); key.BackgroundTransparency = 1 - Color.Opacity; key.Parent = holder
        local label = Instance.new('TextLabel'); label.Name = 'Label'; label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1; label.Font = Enum.Font.Gotham; label.Text = text; label.TextSize = 15; label.TextColor3 = Color3.new(1,1,1); label.Parent = key
        local corner = Instance.new('UICorner'); corner.CornerRadius = UDim.new(0, 4); corner.Parent = key
        keys[id] = {Key = key, Label = label, Input = input}
    end
    local function build()
        for _, key in keys do key.Key:Destroy() end; table.clear(keys); table.clear(inputKeys)
        local arrow = Style.Value == 'Arrow'
        make('W', UDim2.fromOffset(38, 0), UDim2.fromOffset(34, 36), arrow and '↑' or 'W', Enum.KeyCode.W)
        make('A', UDim2.fromOffset(0, 42), UDim2.fromOffset(34, 36), arrow and '←' or 'A', Enum.KeyCode.A)
        make('S', UDim2.fromOffset(38, 42), UDim2.fromOffset(34, 36), arrow and '↓' or 'S', Enum.KeyCode.S)
        make('D', UDim2.fromOffset(76, 42), UDim2.fromOffset(34, 36), arrow and '→' or 'D', Enum.KeyCode.D)
        if ShowSpace.Enabled then make('Space', UDim2.fromOffset(0, 83), UDim2.fromOffset(110, 24), '━━━━━━━━', Enum.KeyCode.Space) end
        if ShowMouse.Enabled then
            if ShowLeft.Enabled then make('MouseL', UDim2.fromOffset(118, 0), UDim2.fromOffset(29, 51), 'L', Enum.UserInputType.MouseButton1) end
            if ShowRight.Enabled then make('MouseR', UDim2.fromOffset(153, 0), UDim2.fromOffset(29, 51), 'R', Enum.UserInputType.MouseButton2) end
            if ShowMiddle.Enabled then make('MouseM', UDim2.fromOffset(147, 57), UDim2.fromOffset(12, 21), '', Enum.UserInputType.MouseButton3) end
            if ShowCPS.Enabled then
                if ShowLeft.Enabled then make('CPSL', UDim2.fromOffset(118, 83), UDim2.fromOffset(29, 24), '0', nil) end
                if ShowRight.Enabled then make('CPSR', UDim2.fromOffset(153, 83), UDim2.fromOffset(29, 24), '0', nil) end
            end
        end
        for _, entry in keys do
            if entry.Input then inputKeys[entry.Input] = entry end
        end
        layout()
    end
    local function illuminate(entry, pressed)
        entry.Pressed = pressed
        tweenService:Create(entry.Key, TweenInfo.new(0.08), {BackgroundColor3 = pressed and Color3.new(1,1,1) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value), BackgroundTransparency = pressed and 0 or 1 - Color.Opacity}):Play()
        tweenService:Create(entry.Label, TweenInfo.new(0.08), {TextColor3 = pressed and Color3.new() or Color3.new(1,1,1)}):Play()
    end
    Keystrokes = vape.Categories.Legit:CreateModule({Name = 'Keystrokes', Category = 'Hud', Size = UDim2.fromOffset(110, 107), Tooltip = 'Shows movement, spacebar, mouse buttons, and CPS onscreen', Function = function(enabled)
        cpsGeneration += 1
        if not enabled then return end
        local generation = cpsGeneration
        build()
        Keystrokes:Clean(inputService.InputBegan:Connect(function(input, processed)
            local entry = inputKeys[input.KeyCode] or inputKeys[input.UserInputType]
            if not entry then return end
            illuminate(entry, true)
            if not processed and entry == keys.MouseL then table.insert(clicks.L, tick())
            elseif not processed and entry == keys.MouseR then table.insert(clicks.R, tick()) end
        end))
        Keystrokes:Clean(inputService.InputEnded:Connect(function(input)
            local entry = inputKeys[input.KeyCode] or inputKeys[input.UserInputType]
            if entry then illuminate(entry, false) end
        end))
        task.spawn(function()
            while Keystrokes.Enabled and cpsGeneration == generation do
                local now = tick()
                for _, side in {'L', 'R'} do
                    local list, head = clicks[side], clickHeads[side]
                    while list[head] and now - list[head] > 1 do head += 1 end
                    -- Compact occasionally rather than shifting the entire array for every click.
                    if head > 32 then
                        table.move(list, head, #list, 1, list)
                        for index = #list - head + 2, #list do list[index] = nil end
                        head = 1
                    end
                    clickHeads[side] = head
                end
                if keys.CPSL then keys.CPSL.Label.Text = tostring(#clicks.L - clickHeads.L + 1) end
                if keys.CPSR then keys.CPSR.Label.Text = tostring(#clicks.R - clickHeads.R + 1) end
                task.wait(0.1)
            end
        end)
    end})
    holder = Instance.new('Frame'); holder.Size = UDim2.fromScale(1,1); holder.BackgroundTransparency = 1; holder.Parent = Keystrokes.Children
    local function rebuild() if Keystrokes.Enabled then build() else layout() end end
    Style = Keystrokes:CreateDropdown({Name = 'Key Style', List = {'Keyboard','Arrow'}, Function = rebuild})
    Color = Keystrokes:CreateColorSlider({Name = 'Color', DefaultValue = 0, DefaultOpacity = 0.5, Function = function(h,s,v,o) for _, entry in keys do if not entry.Pressed then entry.Key.BackgroundColor3 = Color3.fromHSV(h,s,v); entry.Key.BackgroundTransparency = 1-o end end end})
    ShowSpace = Keystrokes:CreateToggle({Name = 'Show Spacebar', Default = true, Function = rebuild})
    ShowMouse = Keystrokes:CreateToggle({Name = 'Show Mouse', Function = rebuild})
    ShowLeft = Keystrokes:CreateToggle({Name = 'Left Mouse', Default = true, Function = rebuild})
    ShowMiddle = Keystrokes:CreateToggle({Name = 'Middle Mouse', Default = true, Function = rebuild})
    ShowRight = Keystrokes:CreateToggle({Name = 'Right Mouse', Default = true, Function = rebuild})
    ShowCPS = Keystrokes:CreateToggle({Name = 'Show CPS', Function = rebuild})
end)