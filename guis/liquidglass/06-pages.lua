    for i,spec in ipairs({{'Search',function() if mainapi.LiquidGlass and mainapi.LiquidGlass.OpenSpotlight then mainapi.LiquidGlass.OpenSpotlight() end end},{'Settings',function() state.Page='Settings'; state.Category=nil; if state.RenderPage then state.RenderPage() end end},{'Disable all',function() for _,m in ipairs(collectModules()) do if m.Enabled and type(m.Toggle)=='function' then pcall(m.Toggle,m) end end end}}) do
        local b=textButton(homeButtons,spec[1]); b.Size=UDim2.fromOffset(i==3 and 98 or 78,30); b.BackgroundColor3=i==1 and accent() or COLORS.Surface; b.BackgroundTransparency=i==1 and 0.08 or 0.3; b.TextSize=9; b.LayoutOrder=i; b.ZIndex=115; corner(b,10); connect(b.MouseButton1Click,spec[2])
    end

    sectionHeading(page,'Recently used',2)
    local recentHolder=create('Frame',{Size=UDim2.new(1,0,0,112),BackgroundTransparency=1,LayoutOrder=3,ZIndex=110},page)
    local recentGrid=createGrid(recentHolder,102)
    local byName={}; for _,m in ipairs(modules) do byName[moduleDisplayName(m)]=m end
    local shown=0
    for _,name in ipairs(state.Recent) do
        local m=byName[name]
        if m then shown+=1; moduleCard(recentHolder,m,shown) end
    end
    if shown==0 then
        for _,m in ipairs(modules) do if m.Enabled and shown<4 then shown+=1; moduleCard(recentHolder,m,shown) end end
    end
    if shown==0 then
        local none=cardSurface(recentHolder,80,1); none.Size=UDim2.new(1,0,0,80)
        local t=label(none,'Modules you use will appear here',10,false,COLORS.Tertiary,Enum.TextXAlignment.Center); t.Size=UDim2.fromScale(1,1); t.ZIndex=114
    end
    local function rg()
        local one=state.CompactSidebar or recentHolder.AbsoluteSize.X<600
        recentGrid.FillDirectionMaxCells=one and 1 or 2; recentGrid.CellSize=one and UDim2.new(1,-2,0,96) or UDim2.new(0.5,-5,0,96)
        recentHolder.Size=UDim2.new(1,0,0,math.ceil(math.max(shown,1)/(one and 1 or 2))*106)
    end
    rg(); connect(recentHolder:GetPropertyChangedSignal('AbsoluteSize'),rg)

    sectionHeading(page,'Quick access',4)
    local quick=create('Frame',{Size=UDim2.new(1,0,0,138),BackgroundTransparency=1,LayoutOrder=5,ZIndex=110},page)
    local qgrid=createGrid(quick,64)
    actionCard(quick,'Diagnostics','Inspect Aether health',1,function() state.Page='Diagnostics'; if state.RenderPage then state.RenderPage() end end)
    actionCard(quick,'Profiles','Switch or manage configs',2,function() state.Page='Category'; state.Category='Profiles'; if state.RenderPage then state.RenderPage() end end)
    actionCard(quick,'Update Center','Version and update tools',3,function() state.Page='Updates'; if state.RenderPage then state.RenderPage() end end)
    actionCard(quick,'Actions','All Aether commands',4,function() state.Page='Actions'; if state.RenderPage then state.RenderPage() end end)
    local function qg() local one=state.CompactSidebar or quick.AbsoluteSize.X<600; qgrid.FillDirectionMaxCells=one and 1 or 2; qgrid.CellSize=one and UDim2.new(1,-2,0,64) or UDim2.new(0.5,-5,0,64); quick.Size=UDim2.new(1,0,0,one and 286 or 138) end
    qg(); connect(quick:GetPropertyChangedSignal('AbsoluteSize'),qg)
end

local function settingSlider(parent,name,valueGetter,valueSetter,min,max,order,suffix)
    local fake={Type='Slider',Name=name,Value=valueGetter(),Min=min,Max=max,Decimal=1,Suffix=suffix,Tooltip=nil,SetValue=function(self,value,_,final) self.Value=value; valueSetter(value,final) end}
    local row=makeSliderControl(parent,fake,name,order)
    registerOptionRefresher(function() fake.Value=valueGetter() end)
    return row
end

local function settingToggle(parent,name,getter,setter,order,subtitle)
    local fake={Type='Toggle',Name=name,Enabled=getter(),Tooltip=subtitle,Toggle=function(self) self.Enabled=not self.Enabled; setter(self.Enabled) end}
    local row=makeToggleControl(parent,fake,name,order)
    registerOptionRefresher(function() fake.Enabled=getter() end)
    return row
end

local function renderSettings()
    activeOptionRefreshers={}; state.ModuleCards={}; clearChildren(page)
    pageTitle.Text='Settings'; pageSubtitle.Text='Liquid Glass, profiles and Aether'; filterBox.Visible=false

    sectionHeading(page,'Appearance',1)
    settingSlider(page,'Glass opacity',function() return math.floor((liquidSettings.GlassOpacity or .82)*100+.5) end,function(v) liquidSettings.GlassOpacity=v/100; saveLiquidSettings(); refreshGlassTheme() end,20,100,2,'%')
    settingToggle(page,'Backdrop blur',function() return liquidSettings.Blur end,function(v) liquidSettings.Blur=v; saveLiquidSettings(); setBlur(state.Visible) end,3,'Blur the game behind the menu')
    settingSlider(page,'Blur strength',function() return tonumber(liquidSettings.BlurSize) or 8 end,function(v) liquidSettings.BlurSize=v; saveLiquidSettings(); setBlur(state.Visible) end,0,20,4)
    settingToggle(page,'Motion',function() return liquidSettings.Motion end,function(v) liquidSettings.Motion=v; saveLiquidSettings() end,5,'Spring and crossfade animations')
    settingSlider(page,'Interface scale',function() return math.floor((tonumber(liquidSettings.Scale) or 1)*100+.5) end,function(v) liquidSettings.Scale=v/100; saveLiquidSettings(); applyLayout(false) end,78,118,6,'%')
    settingToggle(page,'Compact module cards',function() return liquidSettings.CompactCards end,function(v) liquidSettings.CompactCards=v; saveLiquidSettings(); if state.RenderPage then state.RenderPage() end end,7,'Show denser module cards')

    sectionHeading(page,'Aether accent',20)
    settingSlider(page,'Accent hue',function() return math.floor(((mainapi.GUIColor and mainapi.GUIColor.Hue) or .756)*360+.5) end,function(v)
        if mainapi.GUIColor then mainapi.GUIColor.Hue=(v%360)/360 end
        pcall(function() mainapi:UpdateGUI(mainapi.GUIColor.Hue,mainapi.GUIColor.Sat,mainapi.GUIColor.Value) end)
        refreshGlassTheme(); updateStatus()
    end,0,360,21,'°')

    sectionHeading(page,'Profiles',30)
    local profiles=mainapi.Profiles or {{Name='default'}}
    local order=31
    for _,profile in ipairs(profiles) do
        local name=tostring(profile.Name or 'default')
        actionCard(page,name,name==tostring(mainapi.Profile) and 'Current profile' or 'Switch to this profile',order,function()
            if name~=mainapi.Profile then
                pcall(function() mainapi:Save() end)
                pcall(function() mainapi:Load(true,name) end)
                pcall(function() mainapi:Save() end)
                updateStatus(); if state.RenderPage then state.RenderPage() end
            end
        end)
        order+=1
    end

    sectionHeading(page,'System',100)
    actionCard(page,'Diagnostics','Open Aether Doctor / diagnostics',101,function() state.Page='Diagnostics'; if state.RenderPage then state.RenderPage() end end)
    actionCard(page,'Update Center','Check version, history and updates',102,function() state.Page='Updates'; if state.RenderPage then state.RenderPage() end end)
    actionCard(page,'Uninject Aether','Close AetherV2 and clean up',103,function() pcall(mainapi.Uninject,mainapi) end,true)
end

local function connectionCount()
    local count = #(mainapi.Connections or {})
    for _, module in ipairs(collectModules()) do count += #(module.Connections or {}) end
    return count
end

local function diagnosticsText()
    local executor = 'Unknown'
    pcall(function() if identifyexecutor then executor = tostring(select(1, identifyexecutor())) end end)
    local fps = 'Unavailable'
    pcall(function() fps = string.format('%.0f', workspace:GetRealPhysicsFPS()) end)
    local memory = 'Unavailable'
    pcall(function() memory = string.format('%.1f MB', collectgarbage('count') / 1024) end)
    local gameState = 'Place '..tostring(mainapi.Place or game.PlaceId)
    pcall(function()
        if mainapi.GameInfo and mainapi.GameInfo.Name then gameState = tostring(mainapi.GameInfo.Name)..' • '..gameState end
    end)
    local loadTrace = shared.AetherGameLoadTrace
    local loadState = type(loadTrace) == 'table' and tostring(loadTrace.State or 'unknown') or 'unavailable'
    return table.concat({
        'Executor: '..executor,
        'Filesystem: '..((type(isfile)=='function' and type(readfile)=='function' and type(writefile)=='function') and 'supported' or 'limited'),
        'HTTP: '..((type(request)=='function' or type(http_request)=='function' or type(game.HttpGet)=='function') and 'supported' or 'unavailable'),
        'Performance: '..fps..' physics FPS • '..memory..' Lua memory',
        'Runtime: '..tostring(connectionCount())..' tracked connections • '..tostring(mainapi.ActiveHooks or 0)..' active hooks',
        'Game: '..gameState,
        'Game loader: '..loadState,
        'Profile: '..tostring(mainapi.Profile or 'default')..' • Version: '..tostring(mainapi.Version or '?'),
        'Session: '..math.floor(os.clock() - (mainapi.StartedAt or os.clock()))..'s',
        'Errors this session: '..tostring(#(mainapi.ErrorLogs or {}))
    }, '\n')
end

local function textPanel(parent, text, order)
    local card = cardSurface(parent, 0, order)
    card.AutomaticSize = Enum.AutomaticSize.Y
    local body = label(card, text, 10, false, COLORS.Secondary)
    body.Size = UDim2.new(1, -28, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Position = UDim2.fromOffset(14, 12)
    body.TextWrapped = true
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextTruncate = Enum.TextTruncate.None
    body.ZIndex = 114
    local pad = create('UIPadding',{PaddingBottom=UDim.new(0,12)},card)
    return card, body
end

local function renderDiagnostics()
    activeOptionRefreshers={}; state.ModuleCards={}; clearChildren(page)
    pageTitle.Text='Diagnostics'; pageSubtitle.Text='Aether Doctor in Liquid Glass'; filterBox.Visible=false
    textPanel(page, diagnosticsText(), 1)
    actionCard(page,'Copy diagnostics','Copy the current runtime report',10,function()
        local copy=setclipboard or toclipboard
        if type(copy)=='function' then pcall(copy,diagnosticsText()) end
    end)
    actionCard(page,'Error logs','Review errors recorded this session',11,function() state.Page='Errors'; if state.RenderPage then state.RenderPage() end end)
    actionCard(page,'Reload game modules','Reinject the current game module set',12,function()
        if mainapi.UpdateGameModules then pcall(mainapi.UpdateGameModules) elseif mainapi.ReloadAether then pcall(mainapi.ReloadAether) end
    end)
end

local function formatError(entry, index)
    if type(entry) ~= 'table' then return tostring(index)..'. '..tostring(entry) end
    local title = entry.Module or entry.Name or entry.Source or ('Error '..tostring(index))
    local message = entry.Error or entry.Message or entry.Traceback or entry.Text
    if message == nil then
        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, entry)
        message = ok and encoded or tostring(entry)
    end
    return tostring(title)..'\n'..tostring(message)
end

local function renderErrors()
    activeOptionRefreshers={}; state.ModuleCards={}; clearChildren(page)
    pageTitle.Text='Error Logs'; pageSubtitle.Text='Errors recorded during this Aether session'; filterBox.Visible=false
    local errors = mainapi.ErrorLogs or {}
    if #errors == 0 then
        textPanel(page,'No errors have been recorded this session.',1)
    else
        for i, entry in ipairs(errors) do textPanel(page, formatError(entry,i), i) end
    end
    actionCard(page,'Copy all errors','Copy the complete error report',1000,function()
        local lines={}
        for i,e in ipairs(errors) do table.insert(lines,formatError(e,i)) end
        local copy=setclipboard or toclipboard
        if type(copy)=='function' then pcall(copy,table.concat(lines,'\n\n')) end
    end)
end

local function installedRef()
    if type(shared.AetherV2PublicRef)=='string' and shared.AetherV2PublicRef~='' then return shared.AetherV2PublicRef end
    local ok, ref = pcall(readfile,'aetherv2/profiles/commit.txt')
    return ok and tostring(ref):gsub('%s+','') or 'main'
end

local function renderUpdates()
    activeOptionRefreshers={}; state.ModuleCards={}; clearChildren(page)
    pageTitle.Text='Update Center'; pageSubtitle.Text='Version, source and runtime update controls'; filterBox.Visible=false
    textPanel(page,table.concat({
        'AetherV2 '..tostring(mainapi.Version or '?'),
        'Installed source: '..installedRef(),
        'Branch: main',
        shared.updated and 'An update was applied this session' or 'No pending session update notice'
    },'\n'),1)
    actionCard(page,'Update / reload Aether','Reload from the latest configured public source',10,function() if mainapi.ReloadAether then pcall(mainapi.ReloadAether) end end)
    actionCard(page,'Reload game modules','Refresh the current game-specific modules',11,function()
        if mainapi.UpdateGameModules then pcall(mainapi.UpdateGameModules) elseif mainapi.ReloadAether then pcall(mainapi.ReloadAether) end
    end)
    if mainapi.Changelogs and type(mainapi.Changelogs.CopyUpdateInfo)=='function' then
        actionCard(page,'Copy update info','Copy the current version and update information',12,function() pcall(mainapi.Changelogs.CopyUpdateInfo,mainapi.Changelogs) end)
    end
    actionCard(page,'Repository source','Copy the installed source reference',13,function()
        local copy=setclipboard or toclipboard
        if type(copy)=='function' then pcall(copy,installedRef()) end
    end)
end

local function actionDescription(action)
    local n=tostring(action.Name or ''):lower()
    if n:find('diagnostic',1,true) then return 'Inspect runtime and controller health' end
    if n:find('error',1,true) then return 'View errors from this session' end
    if n:find('update',1,true) then return 'Manage or apply Aether updates' end
    if n:find('reload',1,true) then return 'Reload the current Aether runtime' end
    if n:find('profile',1,true) then return 'Switch the active Aether profile' end
    if n:find('gui',1,true) then return 'Change Aether interface' end
    if n:find('uninject',1,true) then return 'Close Aether and clean its hooks' end
    return tostring(action.Category or 'Aether command')
end

local function getLiquidActions()
    local actions={}
    if type(mainapi.GetCommandActions)=='function' then
        local ok,result=pcall(mainapi.GetCommandActions,mainapi)
        if ok and type(result)=='table' then for _,a in ipairs(result) do table.insert(actions,a) end end
    end
    -- `new` is now the Liquid Glass frontend, so the controller's existing new/old/rise
    -- switch actions remain authoritative and no extra loader-only GUI name is introduced.
    table.sort(actions,function(a,b) return tostring(a.Name)<tostring(b.Name) end)
    return actions
end

local function renderActions()
    activeOptionRefreshers={}; state.ModuleCards={}; clearChildren(page)
    pageTitle.Text='Actions'; pageSubtitle.Text='Aether commands in one place'; filterBox.Visible=true
