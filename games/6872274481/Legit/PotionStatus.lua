run(function()
    local PotionStatus

    local effects, background = {}, nil
    local replacements = {
        speed = 'rbxassetid://71873445837330',
    }

    local function Added(active)
        effects[active.statusEffect] = active.expireTime

        local max = active.expireTime - workspace:GetServerTimeNow()
        local effect = Instance.new('Frame')
        effect.BackgroundTransparency = 1
        effect.Parent = background
        local sidebar = Instance.new('Frame')
        sidebar.AnchorPoint = Vector2.new(0, 0.5)
        sidebar.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
        sidebar.BackgroundTransparency = 0.5
        sidebar.BorderSizePixel = 0
        sidebar.Position = UDim2.new(0, 53, 0.5, 1)
        sidebar.Size = UDim2.fromOffset(2, 27)
        sidebar.Parent = effect
        local effectimage = Instance.new('ImageLabel')
        effectimage.AnchorPoint = Vector2.new(0, 0.5)
        effectimage.BackgroundTransparency = 1
        effectimage.Position = UDim2.new(0, 10, 0.5, 0)
        effectimage.Size = UDim2.fromOffset(30, 30)
        effectimage.Parent = effect
        if replacements[active.statusEffect] then
            effectimage.Image = replacements[active.statusEffect]
        else
            local meta = bedwars.StatusEffectMeta[active.statusEffect]
            if meta and (meta.image or meta.item) then
                effectimage.Image = meta.image or bedwars.getIcon({itemType = meta.item}, true)
            end
        end
        local effectname = Instance.new('TextLabel')
        effectname.BackgroundTransparency = 1
        effectname.Position = UDim2.fromOffset(67, 10)
        effectname.Size = UDim2.fromOffset(108, 20)
        effectname.TextXAlignment = Enum.TextXAlignment.Left
        effectname.Font = Enum.Font.ArimoBold
        effectname.Text = (active.statusEffect:sub(0, 1):upper() .. active.statusEffect:sub(2, #active.statusEffect)):gsub('_',' ')
        effectname.TextColor3 = Color3.new(1, 1, 1)
        effectname.TextSize = 15
        effectname.Parent = effect
        do
            local shadow = effectname:Clone()
            shadow.TextColor3 = Color3.new()
            shadow.ZIndex = 0
            shadow.Position += UDim2.fromOffset(1, 1)
            shadow.Parent = effect
            shadow.TextTransparency = 0.5
        end
        effect.Size = UDim2.fromOffset(textService:GetTextSize(effectname.Text, 15, Enum.Font.ArimoBold, Vector2.new(1000, 57)).X + 80, 57)
        local effectduration = effectname:Clone()
        effectduration.Position = UDim2.fromOffset(67, 29)
        effectduration.TextSize = 14
        effectduration.Text = '00:00'
        effectduration.Parent = effect
        local shadow = effectduration:Clone()
        shadow.TextColor3 = Color3.new()
        shadow.ZIndex = 0
        shadow.TextTransparency = 0.5
        shadow.Position += UDim2.fromOffset(1, 1)
        shadow.Parent = effect
        local secs = 0
        repeat
            secs = math.floor(active.expireTime - workspace:GetServerTimeNow())
            local percent = math.max(secs / max, 0)
            effectduration.TextColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.962, 0.52)
            effectduration.Text = ('%02d:%02d'):format(math.floor(secs / 60), secs % 60)
            shadow.Text = effectduration.Text
            task.wait()
        until secs < 0
        effect:Destroy()
    end

    PotionStatus = vape.Categories.Legit:CreateModule({
        Name = 'PotionStatus',
        Tooltip = 'Shows you currently active effects',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive then
                        for _, v in bedwars.StatusEffectUtil:getAllActive(lplr.Character) do
                            if (not effects[v.statusEffect] or effects[v.statusEffect] ~= (v.expireTime or 0)) and (v.expireTime or 0) - workspace:GetServerTimeNow() > 0 then
                                task.spawn(Added, v)
                            end
                        end
                    end
                    task.wait(0.1)
                until not PotionStatus.Enabled
            end
        end,
        Category = 'Hud',
        Size = UDim2.fromOffset(247, 57)
    })
    PotionStatus:CreateToggle({
        Name = 'Render background',
        Default = true,
        Function = function(callback)
            if background then
                background.BackgroundTransparency = callback and 0.5 or 1
            end
        end,
    })
    background = Instance.new('Frame')
    background.BackgroundColor3 = Color3.new()
    background.BackgroundTransparency = 0.5
    background.Size = UDim2.new()
    background.Parent = PotionStatus.Children
    Instance.new('UICorner', background).CornerRadius = UDim.new(0, 4)
    local layout = Instance.new('UIListLayout')
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Parent = background
    layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        background.Size = UDim2.fromOffset(layout.AbsoluteContentSize.X, layout.AbsoluteContentSize.Y)
    end)
end)
