        row.Visible = optionVisible(option)
        refresh()
    end
    registerOptionRefresher(fullRefresh)
    fullRefresh()
    return row
end

local function makeDropdownControl(parent, option, name, order)
    local values = option.ListValues or (option.LiquidMeta and option.LiquidMeta.List) or {}
    local count = math.max(#values, 1)
    local expanded = false
    local row = controlRow(parent, name, 52, order, option.Tooltip)
    local current = textButton(row, '')
    current.Size = UDim2.fromOffset(132, 30)
    current.Position = UDim2.new(1, -144, 0, 10)
    current.BackgroundColor3 = COLORS.Surface
    current.BackgroundTransparency = 0.28
    current.ZIndex = 116
    corner(current, 10)
    create('UIStroke', {Color = COLORS.White, Transparency = 0.92, Thickness = 1}, current)
    local currentText = label(current, tostring(option.Value or values[1] or 'None'), 10, false, COLORS.Secondary)
    currentText.Size = UDim2.new(1, -28, 1, 0)
    currentText.Position = UDim2.fromOffset(10, 0)
    currentText.ZIndex = 117
    local chevron = label(current, '⌄', 13, true, COLORS.Tertiary, Enum.TextXAlignment.Center)
    chevron.Size = UDim2.fromOffset(24, 30)
    chevron.Position = UDim2.new(1, -26, 0, 0)
    chevron.ZIndex = 117
    local choices = create('Frame', {
        Name = 'Choices', Size = UDim2.new(1, -24, 0, math.min(count, 8) * 32 + 8),
        Position = UDim2.fromOffset(12, 46), BackgroundColor3 = COLORS.Deep,
        BackgroundTransparency = 0.12, BorderSizePixel = 0, Visible = false, ZIndex = 120
    }, row)
    corner(choices, 12)
    create('UIStroke', {Color = COLORS.White, Transparency = 0.88, Thickness = 1}, choices)
    padding(choices, 5, 5, 4, 4)
    local choicesScroll = create('ScrollingFrame', {
        Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = #values > 8 and 2 or 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), ZIndex = 121
    }, choices)
    local list = create('UIListLayout', {Padding = UDim.new(0,2), SortOrder = Enum.SortOrder.LayoutOrder}, choicesScroll)
    local function collapse()
        expanded = false
        choices.Visible = false
        row.Size = UDim2.new(1,0,0,52)
        chevron.Text = '⌄'
    end
    for i, value in ipairs(values) do
        local choice = textButton(choicesScroll, '')
        choice.Size = UDim2.new(1,-2,0,30)
        choice.LayoutOrder = i
        choice.BackgroundColor3 = COLORS.Surface2
        choice.BackgroundTransparency = 1
        choice.ZIndex = 122
        corner(choice, 8)
        local choiceText = label(choice, tostring(value), 10, false, COLORS.Secondary)
        choiceText.Size = UDim2.new(1,-20,1,0)
        choiceText.Position = UDim2.fromOffset(9,0)
        choiceText.ZIndex = 123
        connect(choice.MouseEnter, function() tween(choice,0.12,{BackgroundTransparency=0.55}) end)
        connect(choice.MouseLeave, function() tween(choice,0.12,{BackgroundTransparency=1}) end)
        connect(choice.MouseButton1Click, function()
            if type(option.SetValue) == 'function' then pcall(option.SetValue, option, value, true) end
            currentText.Text = tostring(option.Value or value)
            collapse()
        end)
    end
    connect(current.MouseButton1Click, function()
        expanded = not expanded
        choices.Visible = expanded
        row.Size = UDim2.new(1,0,0,expanded and (62 + math.min(count,8)*32) or 52)
        chevron.Text = expanded and '⌃' or '⌄'
    end)
    local function refresh()
        currentText.Text = tostring(option.Value or values[1] or 'None')
        row.Visible = optionVisible(option)
        if not row.Visible then collapse() end
    end
    registerOptionRefresher(refresh); refresh()
    return row
end

local function makeTextBoxControl(parent, option, name, order)
    local row = controlRow(parent, name, 66, order, option.Tooltip)
    local box = create('TextBox', {
        Size = UDim2.new(1,-24,0,30), Position = UDim2.fromOffset(12,29),
        BackgroundColor3 = COLORS.Surface, BackgroundTransparency = 0.28,
        BorderSizePixel = 0, Text = tostring(option.Value or ''),
        PlaceholderText = tostring((option.LiquidMeta and option.LiquidMeta.Placeholder) or 'Enter value'),
        PlaceholderColor3 = COLORS.Tertiary, TextColor3 = COLORS.Text, TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, ZIndex = 116
    }, row)
    corner(box, 10); padding(box,10,10,0,0)
    create('UIStroke', {Color=COLORS.White, Transparency=0.92, Thickness=1}, box)
    local mutating = false
    connect(box:GetPropertyChangedSignal('Text'), function()
        if mutating then return end
        if type(option.SetValue) == 'function' then pcall(option.SetValue, option, box.Text, false) end
    end)
    connect(box.FocusLost, function(enter)
        if type(option.SetValue) == 'function' then pcall(option.SetValue, option, box.Text, enter == true) end
    end)
    local function refresh()
        row.Visible = optionVisible(option)
        if not box:IsFocused() and tostring(option.Value or '') ~= box.Text then
            mutating = true; box.Text = tostring(option.Value or ''); mutating = false
        end
    end
    registerOptionRefresher(refresh); refresh()
    return row
end

local function makeColorControl(parent, option, name, order)
    local row = controlRow(parent, name, 168, order, option.Tooltip)
    local swatch = textButton(row, '')
    swatch.Size = UDim2.fromOffset(54,28); swatch.Position = UDim2.new(1,-66,0,7)
    swatch.ZIndex = 116; corner(swatch,9)
    create('UIStroke',{Color=COLORS.White,Transparency=0.84,Thickness=1},swatch)

    local tracks = {}
    local definitions = {
        {'Hue', 0, 1, function() return tonumber(option.Hue) or 0 end, function(v) pcall(option.SetValue, option, v, nil, nil, nil) end},
        {'Saturation', 0, 1, function() return tonumber(option.Sat) or 0 end, function(v) pcall(option.SetValue, option, nil, v, nil, nil) end},
        {'Brightness', 0, 1, function() return tonumber(option.Value) or 0 end, function(v) pcall(option.SetValue, option, nil, nil, v, nil) end},
        {'Opacity', 0, 1, function() return tonumber(option.Opacity) or 1 end, function(v) pcall(option.SetValue, option, nil, nil, nil, v) end}
    }
    for i, def in ipairs(definitions) do
        local y = 44 + (i-1)*28
        local nm = label(row, def[1], 9, false, COLORS.Tertiary)
        nm.Size = UDim2.fromOffset(70,20); nm.Position = UDim2.fromOffset(12,y); nm.ZIndex = 115
        local track = create('Frame',{Size=UDim2.new(1,-102,0,6),Position=UDim2.fromOffset(88,y+7),BackgroundColor3=Color3.fromRGB(52,53,65),BorderSizePixel=0,ZIndex=115},row)
        corner(track,99)
        local fill = create('Frame',{Size=UDim2.fromScale(def[4](),1),BackgroundColor3=accent(),BorderSizePixel=0,ZIndex=116},track)
        corner(fill,99)
        local knob = create('Frame',{Size=UDim2.fromOffset(12,12),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(1,0.5),BackgroundColor3=COLORS.White,BorderSizePixel=0,ZIndex=117},fill)
        corner(knob,99)
        local hit = textButton(track,''); hit.Size=UDim2.new(1,0,0,22); hit.Position=UDim2.fromOffset(0,-8); hit.ZIndex=118
        local function setX(x)
            local alpha=math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
            def[5](alpha)
        end
        connect(hit.InputBegan,function(input)
            if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
            setX(input.Position.X)
            local move,ended
            move=UserInputService.InputChanged:Connect(function(changed)
                local wanted=input.UserInputType==Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch
                if changed.UserInputType==wanted then setX(changed.Position.X) end
            end)
            ended=input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then if move then move:Disconnect() end; if ended then ended:Disconnect() end end
            end)
        end)
        tracks[i]={Fill=fill,Getter=def[4]}
    end

    if type(option.Toggle) == 'function' then
        local rainbowText = label(row,'Rainbow',9,false,COLORS.Tertiary)
        rainbowText.Size=UDim2.fromOffset(70,20); rainbowText.Position=UDim2.fromOffset(12,153); rainbowText.ZIndex=115
        local rainbowSwitch, rainbowRefresh = makeSwitch(row,function() return option.Rainbow==true end,function(v)
            if option.Rainbow~=v then pcall(option.Toggle,option) end
        end)
        rainbowSwitch.Size=UDim2.fromOffset(34,20); rainbowSwitch.Position=UDim2.new(1,-46,0,151); rainbowSwitch.ZIndex=116
        rainbowSwitch:FindFirstChildOfClass('UICorner').CornerRadius=UDim.new(1,0)
        registerOptionRefresher(rainbowRefresh)
    end
    local function refresh()
        row.Visible=optionVisible(option)
        local h,s,v=tonumber(option.Hue) or 0,tonumber(option.Sat) or 0,tonumber(option.Value) or 0
        swatch.BackgroundColor3=Color3.fromHSV(h,s,v)
        for _,record in ipairs(tracks) do
            record.Fill.Size=UDim2.fromScale(math.clamp(record.Getter(),0,1),1)
            record.Fill.BackgroundColor3=accent()
        end
    end
    registerOptionRefresher(refresh); refresh(); return row
end

local function makeTextListControl(parent, option, name, order)
    local row = controlRow(parent, name, 92, order, option.Tooltip)
    local summary = label(row,'',9,false,COLORS.Tertiary)
    summary.Size=UDim2.new(1,-24,0,18); summary.Position=UDim2.fromOffset(12,27); summary.ZIndex=115
    local input = create('TextBox',{
        Size=UDim2.new(1,-68,0,28),Position=UDim2.fromOffset(12,54),BackgroundColor3=COLORS.Surface,
        BackgroundTransparency=0.28,BorderSizePixel=0,Text='',PlaceholderText=tostring((option.LiquidMeta and option.LiquidMeta.Placeholder) or 'Add entry'),
        PlaceholderColor3=COLORS.Tertiary,TextColor3=COLORS.Text,TextSize=10,Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,ZIndex=116
    },row); corner(input,9); padding(input,9,9,0,0)
    local add=textButton(row,'+')
    add.Size=UDim2.fromOffset(36,28); add.Position=UDim2.new(1,-48,0,54); add.BackgroundColor3=accent(); add.BackgroundTransparency=0.1; add.TextSize=16; add.ZIndex=116; corner(add,9)
    local function addValue()
        local value=input.Text:gsub('^%s*(.-)%s*$','%1')
        if value=='' then return end
        if type(option.ChangeValue)=='function' then pcall(option.ChangeValue,option,value) end
        input.Text=''
    end
    connect(add.MouseButton1Click,addValue)
    connect(input.FocusLost,function(enter) if enter then addValue() end end)
    local function refresh()
        row.Visible=optionVisible(option)
        local list=type(option.List)=='table' and option.List or {}
        if #list==0 then summary.Text='No entries' else
            local shown={}
            for i=1,math.min(#list,4) do table.insert(shown,tostring(list[i])) end
            summary.Text=table.concat(shown,'  •  ')..(#list>4 and ('  +'..tostring(#list-4)) or '')
        end
    end
    registerOptionRefresher(refresh); refresh(); return row
end

local function makeButtonControl(parent, option, name, order)
    local row = cardSurface(parent, 44, order)
    local button = textButton(row, tostring(name or 'Action'))
    button.Size=UDim2.new(1,-12,1,-12); button.Position=UDim2.fromOffset(6,6)
    button.BackgroundColor3=COLORS.Surface2; button.BackgroundTransparency=0.2; button.ZIndex=116; button.TextSize=11
    corner(button,11); create('UIStroke',{Color=COLORS.White,Transparency=0.92,Thickness=1},button)
    connect(button.MouseButton1Click,function()
        if type(option.Function)=='function' then pcall(option.Function) end
    end)
    return row
end

local function makeGenericControl(parent, option, name, order)
    local row = controlRow(parent,name,48,order,option.Tooltip)
    local value
    if option.Enabled~=nil then value=option.Enabled and 'On' or 'Off'
    elseif option.Value~=nil then value=tostring(option.Value)
    elseif option.ValueMin~=nil then value=tostring(option.ValueMin)..' – '..tostring(option.ValueMax)
    else value=tostring(option.Type or option.LiquidType or 'Option') end
    local valueLabel=label(row,value,10,false,COLORS.Secondary,Enum.TextXAlignment.Right)
    valueLabel.Size=UDim2.fromOffset(140,32); valueLabel.Position=UDim2.new(1,-152,0,8); valueLabel.ZIndex=116
    local function refresh()
        row.Visible=optionVisible(option)
        if option.Enabled~=nil then valueLabel.Text=option.Enabled and 'On' or 'Off'
        elseif option.Value~=nil then valueLabel.Text=tostring(option.Value)
        elseif option.ValueMin~=nil then valueLabel.Text=tostring(option.ValueMin)..' – '..tostring(option.ValueMax) end
    end
    registerOptionRefresher(refresh); refresh(); return row
end

local function controlFor(parent, option, name, order)
    local kind=tostring(option.Type or option.LiquidType or '')
    if kind=='' then
        if option.Hue~=nil and option.Sat~=nil and option.Value~=nil then kind='ColorSlider'
        elseif option.ValueMin~=nil and option.ValueMax~=nil then kind='TwoSlider'
        elseif option.Enabled~=nil and type(option.Toggle)=='function' then kind='Toggle'
        elseif type(option.List)=='table' and option.Objects~=nil then kind='TextList'
        elseif type(option.ListValues)=='table' or (type(option.List)=='table' and option.Value~=nil) then kind='Dropdown'
        elseif option.Max~=nil and option.Value~=nil and type(option.SetValue)=='function' then kind='Slider'
        elseif option.Value~=nil and type(option.SetValue)=='function' then kind='TextBox' end
    end
    if kind=='Toggle' then return makeToggleControl(parent,option,name,order) end
    if kind=='Slider' then return makeSliderControl(parent,option,name,order) end
    if kind=='TwoSlider' then return makeTwoSliderControl(parent,option,name,order) end
    if kind=='Dropdown' then return makeDropdownControl(parent,option,name,order) end
    if kind=='TextBox' then return makeTextBoxControl(parent,option,name,order) end
    if kind=='ColorSlider' then return makeColorControl(parent,option,name,order) end
    if kind=='TextList' or kind=='TextListEnabled' then return makeTextListControl(parent,option,name,order) end
    if kind=='Button' then return makeButtonControl(parent,option,name,order) end
    return makeGenericControl(parent,option,name,order)
end

local function closeInspector()
    state.SelectedModule=nil
    activeOptionRefreshers={}
    tween(inspector,0.24,{Position=UDim2.new(1,330,0,58)},Enum.EasingStyle.Quint)
    task.delay(liquidSettings.Motion and 0.25 or 0,function()
