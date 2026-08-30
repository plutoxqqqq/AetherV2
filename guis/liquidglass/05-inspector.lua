        if not state.SelectedModule and inspector.Parent then inspector.Visible=false end
    end)
end

local function moduleBindText(module)
    local bind=module.Bind
    if type(bind)=='table' and bind.Button then return 'Mobile button' end
    if type(bind)=='table' and #bind>0 then return table.concat(bind,' + '):upper() end
    return 'Not bound'
end

local function sortedOptions(module)
    local result={}
    local seen={}
    for key,option in pairs(module.Options or {}) do
        if type(option)=='table' and not seen[option] then
            seen[option]=true
            local name=option.Name or (type(key)=='string' and key) or tostring(option.Type or 'Option')
            table.insert(result,{Name=name,Option=option,Index=tonumber(option.Index) or 9999})
        end
    end
    table.sort(result,function(a,b) if a.Index==b.Index then return tostring(a.Name)<tostring(b.Name) end return a.Index<b.Index end)
    for i,button in ipairs(module.LiquidButtons or {}) do
        table.insert(result,{Name=button.Name or 'Action',Option=button,Index=10000+i})
    end
    return result
end

local function buildInspector(module)
    if not module then return end
    state.SelectedModule=module
    activeOptionRefreshers={}
    clearChildren(inspectorBody,inspectorList)
    inspectorTitle.Text=moduleDisplayName(module)
    inspectorCategory.Text=tostring(module.LiquidCategory or module.Category or 'Module')

    local master=cardSurface(inspectorBody,72,1)
    local masterTitle=label(master,'Enabled',12,true); masterTitle.Size=UDim2.new(1,-80,0,22); masterTitle.Position=UDim2.fromOffset(12,10); masterTitle.ZIndex=115
    local masterSub=label(master,tostring(module.Tooltip or 'Toggle this module'),9,false,COLORS.Tertiary); masterSub.Size=UDim2.new(1,-80,0,30); masterSub.Position=UDim2.fromOffset(12,31); masterSub.TextWrapped=true; masterSub.TextYAlignment=Enum.TextYAlignment.Top; masterSub.ZIndex=115
    local masterSwitch,refreshMaster=makeSwitch(master,function() return module.Enabled==true end,function(value)
        if module.Enabled~=value and type(module.Toggle)=='function' then pcall(module.Toggle,module); remember(module) end
    end)
    masterSwitch.AnchorPoint=Vector2.new(1,0.5); masterSwitch.Position=UDim2.new(1,-12,0.5,0); masterSwitch.ZIndex=116
    registerOptionRefresher(refreshMaster)

    local bindRow=cardSurface(inspectorBody,50,2)
    local bindTitle=label(bindRow,'Keybind',11,true); bindTitle.Size=UDim2.new(1,-130,1,0); bindTitle.Position=UDim2.fromOffset(12,0); bindTitle.ZIndex=115
    local bindButton=textButton(bindRow,moduleBindText(module)); bindButton.Size=UDim2.fromOffset(126,30); bindButton.Position=UDim2.new(1,-138,0,10); bindButton.BackgroundColor3=COLORS.Surface; bindButton.BackgroundTransparency=0.28; bindButton.TextSize=9; bindButton.ZIndex=116; corner(bindButton,10)
    connect(bindButton.MouseButton1Click,function()
        state.BindingModule=module
        bindButton.Text='Press a key…'
    end)
    registerOptionRefresher(function() if state.BindingModule~=module then bindButton.Text=moduleBindText(module) end end)

    local displayRow=cardSurface(inspectorBody,58,3)
    local displayTitle=label(displayRow,'Display name',11,true); displayTitle.Size=UDim2.new(0,92,0,20); displayTitle.Position=UDim2.fromOffset(12,7); displayTitle.ZIndex=115
    local displayBox=create('TextBox',{Size=UDim2.new(1,-116,0,30),Position=UDim2.fromOffset(104,14),BackgroundColor3=COLORS.Surface,BackgroundTransparency=.26,Text=moduleDisplayName(module),PlaceholderText=tostring(module.Name or ''),PlaceholderColor3=COLORS.Tertiary,TextColor3=COLORS.Text,TextSize=10,Font=Enum.Font.Gotham,ClearTextOnFocus=false,BorderSizePixel=0,ZIndex=116},displayRow)
    corner(displayBox,10); create('UIStroke',{Color=COLORS.White,Transparency=.92,Thickness=1},displayBox)
    connect(displayBox.FocusLost,function(enter)
        if enter and type(mainapi.SetModuleNickname)=='function' then
            pcall(mainapi.SetModuleNickname,mainapi,module,displayBox.Text)
            inspectorTitle.Text=moduleDisplayName(module)
            if state.RenderPage then state.RenderPage() end
        end
    end)

    if type(module.SetHidden)=='function' then
        local hiddenRow=cardSurface(inspectorBody,54,4)
        local hiddenTitle=label(hiddenRow,'Hide from menu',11,true); hiddenTitle.Size=UDim2.new(1,-80,0,22); hiddenTitle.Position=UDim2.fromOffset(12,8); hiddenTitle.ZIndex=115
        local hiddenSub=label(hiddenRow,'Keeps the module available to configs and search',8,false,COLORS.Tertiary); hiddenSub.Size=UDim2.new(1,-80,0,18); hiddenSub.Position=UDim2.fromOffset(12,29); hiddenSub.ZIndex=115
        local hiddenSwitch,refreshHidden=makeSwitch(hiddenRow,function() return module.Hidden==true end,function(value) pcall(module.SetHidden,module,value) end)
        hiddenSwitch.AnchorPoint=Vector2.new(1,.5); hiddenSwitch.Position=UDim2.new(1,-12,.5,0); hiddenSwitch.ZIndex=116
        registerOptionRefresher(refreshHidden)
    end

    local options=sortedOptions(module)
    if #options>0 then
        local heading=label(inspectorBody,'SETTINGS',9,true,COLORS.Tertiary); heading.Size=UDim2.new(1,0,0,18); heading.LayoutOrder=10; heading.ZIndex=114
        local order=10
        for _,entry in ipairs(options) do
            controlFor(inspectorBody,entry.Option,entry.Name,order)
            order+=1
        end
    else
        local empty=cardSurface(inspectorBody,54,10)
        local emptyText=label(empty,'This module has no additional settings',10,false,COLORS.Tertiary,Enum.TextXAlignment.Center); emptyText.Size=UDim2.fromScale(1,1); emptyText.ZIndex=115
    end

    inspector.Visible=true
    applyLayout(true)
    inspector.Position=UDim2.new(1,330,0,58)
    tween(inspector,0.28,{Position=UDim2.new(1,0,0,58)},Enum.EasingStyle.Quint)
end

local function moduleCard(parent,module,order)
    local height=liquidSettings.CompactCards and 78 or 96
    local card,stroke=cardSurface(parent,height,order)
    card.Name='Module_'..tostring(module.Name or order)
    local hit=textButton(card,''); hit.Size=UDim2.fromScale(1,1); hit.ZIndex=112
    local name=label(card,moduleDisplayName(module),13,true); name.Size=UDim2.new(1,-76,0,24); name.Position=UDim2.fromOffset(14,10); name.ZIndex=114
    local cat=label(card,tostring(module.LiquidCategory or module.Category or ''),9,false,COLORS.Tertiary); cat.Size=UDim2.new(1,-78,0,16); cat.Position=UDim2.fromOffset(14,33); cat.ZIndex=114
    local desc=label(card,tostring(module.Tooltip or ''),9,false,COLORS.Secondary); desc.Size=UDim2.new(1,-28,0,32); desc.Position=UDim2.fromOffset(14,55); desc.TextWrapped=true; desc.TextYAlignment=Enum.TextYAlignment.Top; desc.ZIndex=114; desc.Visible=not liquidSettings.CompactCards
    local switch,refreshSwitch=makeSwitch(card,function() return module.Enabled==true end,function(value)
        if module.Enabled~=value and type(module.Toggle)=='function' then pcall(module.Toggle,module); remember(module) end
    end)
    switch.AnchorPoint=Vector2.new(1,0); switch.Position=UDim2.new(1,-12,0,12); switch.ZIndex=117
    connect(hit.MouseButton1Click,function() buildInspector(module) end)
    connect(hit.MouseEnter,function() tween(card,0.14,{BackgroundTransparency=0.38}); stroke.Transparency=0.82 end)
    connect(hit.MouseLeave,function() tween(card,0.14,{BackgroundTransparency=0.5}); stroke.Transparency=0.91 end)
    local function refresh()
        refreshSwitch(); stroke.Color=module.Enabled and accent() or COLORS.White; stroke.Transparency=module.Enabled and 0.55 or 0.91
        card.BackgroundColor3=module.Enabled and Color3.fromRGB(31,28,43) or COLORS.Surface2
    end
    state.ModuleCards[module]={Card=card,Refresh=refresh}
    refresh(); return card
end

local function sectionHeading(parent,text,order)
    local h=label(parent,tostring(text):upper(),9,true,COLORS.Tertiary)
    h.Size=UDim2.new(1,0,0,20); h.LayoutOrder=order or 0; h.ZIndex=112
    return h
end

local function actionCard(parent,titleText,subtitleText,order,callback,destructive)
    local card,stroke=cardSurface(parent,64,order)
    local hit=textButton(card,''); hit.Size=UDim2.fromScale(1,1); hit.ZIndex=113
    local title=label(card,titleText,12,true,destructive and COLORS.Red or COLORS.Text); title.Size=UDim2.new(1,-42,0,22); title.Position=UDim2.fromOffset(13,9); title.ZIndex=114
    local sub=label(card,subtitleText or '',9,false,COLORS.Tertiary); sub.Size=UDim2.new(1,-42,0,20); sub.Position=UDim2.fromOffset(13,32); sub.ZIndex=114
    local arrow=label(card,'›',19,false,destructive and COLORS.Red or COLORS.Tertiary,Enum.TextXAlignment.Center); arrow.Size=UDim2.fromOffset(26,40); arrow.Position=UDim2.new(1,-34,0,12); arrow.ZIndex=114
    connect(hit.MouseButton1Click,function() if callback then pcall(callback) end end)
    connect(hit.MouseEnter,function() tween(card,0.12,{BackgroundTransparency=0.38}); stroke.Transparency=0.82 end)
    connect(hit.MouseLeave,function() tween(card,0.12,{BackgroundTransparency=0.5}); stroke.Transparency=0.91 end)
    return card
end

local function createGrid(parent,cellHeight)
    return create('UIGridLayout',{
        CellPadding=UDim2.fromOffset(10,10), CellSize=UDim2.new(0.5,-5,0,cellHeight or 96),
        FillDirectionMaxCells=2, SortOrder=Enum.SortOrder.LayoutOrder,
        HorizontalAlignment=Enum.HorizontalAlignment.Left
    },parent)
end

local function panelApiFor(category)
    if category == 'Targets' and type(mainapi.TargetOptions) == 'table' then
        return {Options = mainapi.TargetOptions, LiquidButtons = {}, LiquidDividers = {}}
    end
    return select(1, categoryApiFor(category))
end

local function renderControlPanel(category, api, startOrder)
    if type(api) ~= 'table' then return startOrder or 1, 0 end
    local entries = sortedOptions(api)
    local count = #entries
    local order = startOrder or 1
    if count > 0 then
        sectionHeading(page, category == 'Aether' and 'Aether controls' or (category..' controls'), order)
        order += 1
        for _, entry in ipairs(entries) do
            controlFor(page, entry.Option, entry.Name, order)
            order += 1
        end
    end
    return order, count
end

local function renderCategory(category)
    activeOptionRefreshers={}
    state.ModuleCards={}
    clearChildren(page)
    local panelApi = panelApiFor(category)
    pageTitle.Text=category
    pageSubtitle.Text=panelApi and 'Aether controls and features' or ('Modules in '..category)
    filterBox.Visible=true
    local query=filterBox.Text:lower():gsub('^%s*(.-)%s*$','%1')
    local modules={}
    for _,module in ipairs(collectModules()) do
        local cat=tostring(module.LiquidCategory or module.Category or 'Other')
        local display=moduleDisplayName(module)
        if cat==category and (query=='' or display:lower():find(query,1,true) or tostring(module.Tooltip or ''):lower():find(query,1,true)) then
            table.insert(modules,module)
        end
    end
    local order, controlCount = renderControlPanel(category, panelApi, 1)
    if #modules==0 then
        if controlCount > 0 then return end
        local empty=cardSurface(page,112,order)
        empty.Size=UDim2.new(1,0,0,112)
        local icon=label(empty,'⌕',24,true,COLORS.Tertiary,Enum.TextXAlignment.Center); icon.Size=UDim2.new(1,0,0,34); icon.Position=UDim2.fromOffset(0,18); icon.ZIndex=114
        local text=label(empty,query=='' and 'No controls or modules in this category yet' or 'No matching modules',11,false,COLORS.Secondary,Enum.TextXAlignment.Center); text.Size=UDim2.new(1,-24,0,26); text.Position=UDim2.fromOffset(12,55); text.ZIndex=114
        return
    end
    if controlCount > 0 then sectionHeading(page,'Modules',order); order += 1 end
    local cardHeight = liquidSettings.CompactCards and 78 or 96
    local columns = (state.CompactSidebar or page.AbsoluteSize.X < 600) and 1 or 2
    local rows = math.max(1, math.ceil(#modules / columns))
    local gridHost = create('Frame', {Size = UDim2.new(1, 0, 0, rows * cardHeight + math.max(0, rows - 1) * 10), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 110}, page)
    local grid=createGrid(gridHost,cardHeight)
    for i,module in ipairs(modules) do moduleCard(gridHost,module,i) end
    local function updateGrid()
        local available=page.AbsoluteSize.X
        local oneColumn=state.CompactSidebar or available<600
        local cols = oneColumn and 1 or 2
        grid.FillDirectionMaxCells=cols
        grid.CellSize=oneColumn and UDim2.new(1,-2,0,cardHeight) or UDim2.new(0.5,-5,0,cardHeight)
        local rowCount = math.max(1, math.ceil(#modules / cols))
        gridHost.Size = UDim2.new(1, 0, 0, rowCount * cardHeight + math.max(0, rowCount - 1) * 10)
    end
    updateGrid(); connect(page:GetPropertyChangedSignal('AbsoluteSize'),updateGrid)
end

local function activeCount(modules)
    local count=0
    for _,m in ipairs(modules) do if m.Enabled then count+=1 end end
    return count
end

local function renderHome()
    activeOptionRefreshers={}; state.ModuleCards={}; clearChildren(page)
    pageTitle.Text='Home'; pageSubtitle.Text='Aether at a glance'; filterBox.Visible=false
    local modules=collectModules()

    local hero=cardSurface(page,154,1); hero.Size=UDim2.new(1,0,0,154)
    local glow=create('Frame',{Size=UDim2.fromOffset(86,86),Position=UDim2.fromOffset(20,24),BackgroundColor3=accent(),BackgroundTransparency=0.68,BorderSizePixel=0,ZIndex=112},hero); corner(glow,26)
    local heroOrb=create('Frame',{Size=UDim2.fromOffset(62,62),Position=UDim2.fromOffset(32,36),BackgroundColor3=accent(),BorderSizePixel=0,ZIndex=114},hero); corner(heroOrb,20)
    create('UIGradient',{Rotation=-38,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(244,220,255)),ColorSequenceKeypoint.new(0.48,accent()),ColorSequenceKeypoint.new(1,Color3.fromRGB(100,96,255))})},heroOrb)
    local a=label(heroOrb,'A',27,true,COLORS.White,Enum.TextXAlignment.Center); a.Size=UDim2.fromScale(1,1); a.ZIndex=115
    local hi=label(hero,'AetherV2',22,true); hi.Size=UDim2.new(1,-150,0,30); hi.Position=UDim2.fromOffset(120,24); hi.ZIndex=114
    local detail=label(hero,(shared.AetherV2PremiumAuthorized and 'Premium' or 'Free')..'  •  '..tostring(mainapi.Profile or 'default')..'  •  v'..tostring(mainapi.Version or '?'),10,false,COLORS.Secondary); detail.Size=UDim2.new(1,-150,0,20); detail.Position=UDim2.fromOffset(121,56); detail.ZIndex=114
    local session=label(hero,tostring(activeCount(modules))..' active of '..tostring(#modules)..' modules',10,false,COLORS.Tertiary); session.Size=UDim2.new(1,-150,0,20); session.Position=UDim2.fromOffset(121,80); session.ZIndex=114
    local homeButtons=create('Frame',{Size=UDim2.new(1,-134,0,38),Position=UDim2.fromOffset(120,105),BackgroundTransparency=1,ZIndex=114},hero)
    local hbList=create('UIListLayout',{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},homeButtons)
