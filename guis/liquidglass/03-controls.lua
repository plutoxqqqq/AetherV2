    miniOrb.BackgroundColor3 = accent()
    page.ScrollBarImageColor3 = accent()
    inspectorBody.ScrollBarImageColor3 = accent()
end

local function currentViewport()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function applyLayout(instant)
    local viewport = currentViewport()
    local mobile = viewport.X < 760 or viewport.Y < 520
    state.CompactSidebar = mobile
    local sidebarWidth = mobile and 66 or 182
    local targetSize
    if state.Maximized then
        targetSize = UDim2.fromOffset(math.max(360, viewport.X - 22), math.max(360, viewport.Y - 22))
    elseif mobile then
        targetSize = UDim2.fromOffset(math.max(340, viewport.X - 20), math.max(420, viewport.Y - 20))
    else
        local scale = math.clamp(tonumber(liquidSettings.Scale) or 1, 0.78, 1.18)
        targetSize = UDim2.fromOffset(math.min(980 * scale, viewport.X - 42), math.min(620 * scale, viewport.Y - 42))
    end
    local shadowSize = UDim2.fromOffset(targetSize.X.Offset + 20, targetSize.Y.Offset + 20)
    if instant then
        shell.Size, shellShadow.Size = targetSize, shadowSize
    else
        tween(shell, 0.28, {Size = targetSize}, Enum.EasingStyle.Quint)
        tween(shellShadow, 0.28, {Size = shadowSize}, Enum.EasingStyle.Quint)
    end
    sidebar.Size = UDim2.new(0, sidebarWidth, 1, -58)
    content.Position = UDim2.fromOffset(sidebarWidth, 58)
    content.Size = UDim2.new(1, -sidebarWidth, 1, -58)
    statusPill.Visible = not mobile
    brandSub.Visible = not mobile
    if mobile then
        brandTitle.Position = UDim2.fromOffset(124, 15)
        filterBox.Size = UDim2.fromOffset(140, 32)
        filterBox.Position = UDim2.new(1, -158, 0, 22)
    else
        brandTitle.Position = UDim2.fromOffset(124, 8)
        filterBox.Size = UDim2.fromOffset(190, 32)
        filterBox.Position = UDim2.new(1, -214, 0, 22)
    end
    for _, record in pairs(state.NavButtons) do
        if record.Label then record.Label.Visible = not mobile end
        if record.Button then record.Button.Size = UDim2.new(1, 0, 0, 38) end
    end
    profileName.Visible = not mobile
    profileTier.Visible = not mobile
    profileButton.Size = UDim2.new(1, -16, 0, 46)
    avatar.Position = UDim2.new(0.5, -15, 0, 8)
    if not mobile then avatar.Position = UDim2.fromOffset(8, 8) end

    if state.SelectedModule and inspector.Visible then
        if mobile then
            inspector.Size = UDim2.new(1, -sidebarWidth - 8, 1, -58)
            inspector.Position = UDim2.new(1, 0, 0, 58)
        else
            inspector.Size = UDim2.new(0, 322, 1, -58)
            inspector.Position = UDim2.new(1, 0, 0, 58)
        end
    end
end

local function setBlur(enabled)
    if not blur or not blur.Parent then return end
    local target = enabled and liquidSettings.Blur and math.clamp(tonumber(liquidSettings.BlurSize) or 8, 0, 20) or 0
    if liquidSettings.Motion then
        TweenService:Create(blur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = target}):Play()
    else
        blur.Size = target
    end
end

local function setOpen(open)
    state.Visible = open == true
    state.Minimized = false
    miniPill.Visible = false
    if open then
        root.Visible = true
        shell.Visible = true
        shellShadow.Visible = true
        scrim.BackgroundTransparency = 1
        shell.Position = UDim2.new(0.5, 0, 0.5, 10)
        shellShadow.Position = shell.Position
        tween(scrim, 0.2, {BackgroundTransparency = 0.62})
        tween(shell, 0.28, {Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Back)
        tween(shellShadow, 0.28, {Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Back)
        setBlur(true)
    else
        root.Visible = false
        shell.Visible = true
        shellShadow.Visible = true
        setBlur(false)
    end
end

local function minimize()
    if not state.Visible then return end
    state.Minimized = true
    root.Visible = false
    miniPill.Visible = true
    setBlur(false)
end

local function toggleMaximize()
    state.Maximized = not state.Maximized
    shell.Position = UDim2.fromScale(0.5, 0.5)
    shellShadow.Position = shell.Position
    applyLayout(false)
end

local function remember(module)
    local name = moduleDisplayName(module)
    for i = #state.Recent, 1, -1 do
        if state.Recent[i] == name then table.remove(state.Recent, i) end
    end
    table.insert(state.Recent, 1, name)
    while #state.Recent > 6 do table.remove(state.Recent) end
end

local function makeSwitch(parent, getter, setter, layoutOrder)
    local button = textButton(parent, '')
    button.Size = UDim2.fromOffset(42, 24)
    button.BackgroundColor3 = COLORS.Surface2
    button.BackgroundTransparency = 0.25
    button.LayoutOrder = layoutOrder or 0
    corner(button, 99)
    local knob = create('Frame', {
        Size = UDim2.fromOffset(18,18), Position = UDim2.fromOffset(3,3),
        BackgroundColor3 = COLORS.White, BorderSizePixel = 0, ZIndex = button.ZIndex + 1
    }, button)
    corner(knob, 99)
    local function refresh()
        local on = getter() == true
        button.BackgroundColor3 = on and accent() or COLORS.Surface2
        button.BackgroundTransparency = on and 0.05 or 0.25
        tween(knob, 0.18, {Position = UDim2.fromOffset(on and 21 or 3, 3)}, Enum.EasingStyle.Quint)
    end
    connect(button.MouseButton1Click, function()
        setter(not getter())
        refresh()
    end)
    refresh()
    return button, refresh
end

local function cardSurface(parent, height, order)
    local frame = create('Frame', {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = COLORS.Surface2,
        BackgroundTransparency = 0.5, BorderSizePixel = 0, LayoutOrder = order or 0, ZIndex = 110
    }, parent)
    corner(frame, 16)
    local stroke = create('UIStroke', {Color = COLORS.White, Transparency = 0.91, Thickness = 1}, frame)
    local sheen = create('UIGradient', {
        Rotation = 24,
        Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(55,57,72)),
            ColorSequenceKeypoint.new(0.55, COLORS.Surface2), ColorSequenceKeypoint.new(1, Color3.fromRGB(37,34,48))}),
        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.64)})
    }, frame)
    return frame, stroke, sheen
end

local function optionVisible(option)
    if type(option) ~= 'table' then return true end
    local object = option.Object
    if typeof(object) == 'Instance' and object:IsA('GuiObject') then return object.Visible end
    if type(object) == 'table' and object.Visible ~= nil then return object.Visible ~= false end
    local meta = option.LiquidMeta
    return not (type(meta) == 'table' and meta.Visible == false)
end

local activeOptionRefreshers = {}
local function registerOptionRefresher(fn)
    table.insert(activeOptionRefreshers, fn)
    return fn
end

local function optionSuffix(option, value)
    local suffix = option.Suffix or (option.LiquidMeta and option.LiquidMeta.Suffix)
    if type(suffix) == 'function' then
        local ok, result = pcall(suffix, value)
        if ok and result then return ' '..tostring(result) end
    elseif suffix then
        return ' '..tostring(suffix)
    end
    return ''
end

local function controlRow(parent, name, height, order, subtitle)
    local row, stroke = cardSurface(parent, height, order)
    local title = label(row, name, 12, true)
    title.Size = UDim2.new(1, -24, 0, 22)
    title.Position = UDim2.fromOffset(12, 6)
    title.ZIndex = 114
    if subtitle then
        local sub = label(row, subtitle, 9, false, COLORS.Tertiary)
        sub.Size = UDim2.new(1, -24, 0, 16)
        sub.Position = UDim2.fromOffset(12, 26)
        sub.ZIndex = 114
    end
    return row, stroke, title
end

local function makeSliderControl(parent, option, name, order)
    local row = controlRow(parent, name, 62, order, option.Tooltip)
    local min = tonumber(option.Min or (option.LiquidMeta and option.LiquidMeta.Min)) or 0
    local max = tonumber(option.Max or (option.LiquidMeta and option.LiquidMeta.Max)) or 100
    if max <= min then max = min + 1 end
    local decimal = tonumber(option.Decimal or (option.LiquidMeta and option.LiquidMeta.Decimal)) or 1
    local valueLabel = label(row, '', 10, false, COLORS.Secondary, Enum.TextXAlignment.Right)
    valueLabel.Size = UDim2.fromOffset(88, 20)
    valueLabel.Position = UDim2.new(1, -100, 0, 7)
    valueLabel.ZIndex = 115
    local track = create('Frame', {
        Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 1, -18),
        BackgroundColor3 = Color3.fromRGB(55,56,68), BackgroundTransparency = 0.15,
        BorderSizePixel = 0, ZIndex = 114
    }, row)
    corner(track, 99)
    local fill = create('Frame', {Size = UDim2.fromScale(0,1), BackgroundColor3 = accent(), BorderSizePixel = 0, ZIndex = 115}, track)
    corner(fill, 99)
    local knob = create('Frame', {
        Size = UDim2.fromOffset(14,14), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(1,0.5),
        BackgroundColor3 = COLORS.White, BorderSizePixel = 0, ZIndex = 116
    }, fill)
    corner(knob, 99)
    local hit = textButton(track, '')
    hit.Size = UDim2.new(1, 0, 0, 24)
    hit.Position = UDim2.fromOffset(0, -9)
    hit.ZIndex = 117
    local function refresh()
        local value = tonumber(option.Value) or min
        local alpha = math.clamp((value - min) / (max - min), 0, 1)
        fill.Size = UDim2.fromScale(alpha, 1)
        fill.BackgroundColor3 = accent()
        valueLabel.Text = tostring(value)..optionSuffix(option, value)
        row.Visible = optionVisible(option)
    end
    local function setFromX(x, final)
        local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = min + (max - min) * alpha
        value = math.floor(value * decimal + 0.5) / decimal
        value = math.clamp(value, min, max)
        pcall(function() option:SetValue(value, alpha, final == true) end)
        refresh()
    end
    connect(hit.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        setFromX(input.Position.X, false)
        local move, ended
        move = UserInputService.InputChanged:Connect(function(changed)
            local wanted = input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch
            if changed.UserInputType == wanted then setFromX(changed.Position.X, false) end
        end)
        ended = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if move then move:Disconnect() end
                if ended then ended:Disconnect() end
                setFromX(UserInputService:GetMouseLocation().X, true)
            end
        end)
    end)
    registerOptionRefresher(refresh)
    refresh()
    return row
end

local function makeTwoSliderControl(parent, option, name, order)
    local row = controlRow(parent, name, 72, order, option.Tooltip)
    local min = tonumber(option.Min or (option.LiquidMeta and option.LiquidMeta.Min)) or 0
    local max = tonumber(option.Max or (option.LiquidMeta and option.LiquidMeta.Max)) or 100
    local decimal = tonumber(option.Decimal or (option.LiquidMeta and option.LiquidMeta.Decimal)) or 1
    local values = label(row, '', 10, false, COLORS.Secondary, Enum.TextXAlignment.Right)
    values.Size = UDim2.fromOffset(118, 20)
    values.Position = UDim2.new(1, -130, 0, 7)
    values.ZIndex = 115
    local track = create('Frame', {Size = UDim2.new(1,-24,0,6), Position = UDim2.new(0,12,1,-19), BackgroundColor3 = Color3.fromRGB(55,56,68), BorderSizePixel = 0, ZIndex = 114}, row)
    corner(track,99)
    local range = create('Frame', {BackgroundColor3 = accent(), BorderSizePixel = 0, ZIndex = 115}, track)
    corner(range,99)
    local left = create('Frame', {Size = UDim2.fromOffset(14,14), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0,0.5), BackgroundColor3 = COLORS.White, BorderSizePixel = 0, ZIndex = 116}, range)
    local right = left:Clone(); right.Position = UDim2.fromScale(1,0.5); right.Parent = range
    corner(left,99); corner(right,99)
    local hit = textButton(track,''); hit.Size = UDim2.new(1,0,0,24); hit.Position = UDim2.fromOffset(0,-9); hit.ZIndex = 117
    local function refresh()
        local lo, hi = tonumber(option.ValueMin) or min, tonumber(option.ValueMax) or max
        local a = math.clamp((lo-min)/(max-min),0,1)
        local b = math.clamp((hi-min)/(max-min),0,1)
        range.Position = UDim2.fromScale(a,0); range.Size = UDim2.fromScale(math.max(b-a,0),1)
        range.BackgroundColor3 = accent(); values.Text = tostring(lo)..' – '..tostring(hi)
        row.Visible = optionVisible(option)
    end
    local draggingMax = false
    local function setFromX(x)
        local alpha = math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
        local value = math.floor((min+(max-min)*alpha)*decimal+0.5)/decimal
        pcall(function() option:SetValue(draggingMax, value) end); refresh()
    end
    connect(hit.InputBegan,function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local lo, hi = tonumber(option.ValueMin) or min, tonumber(option.ValueMax) or max
        local current = min+(max-min)*math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
        draggingMax = math.abs(current-hi) < math.abs(current-lo)
        setFromX(input.Position.X)
        local move, ended
        move = UserInputService.InputChanged:Connect(function(changed)
            local wanted = input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch
            if changed.UserInputType == wanted then setFromX(changed.Position.X) end
        end)
        ended = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then if move then move:Disconnect() end; if ended then ended:Disconnect() end end
        end)
    end)
    registerOptionRefresher(refresh); refresh(); return row
end


local function makeToggleControl(parent, option, name, order)
    local row = controlRow(parent, name, 48, order, option.Tooltip)
    local switch, refresh = makeSwitch(row, function()
        return option.Enabled == true
    end, function(value)
        if option.Enabled ~= value and type(option.Toggle) == 'function' then
            pcall(option.Toggle, option)
        end
    end)
    switch.AnchorPoint = Vector2.new(1, 0.5)
    switch.Position = UDim2.new(1, -12, 0.5, 0)
    switch.ZIndex = 116
    local function fullRefresh()
