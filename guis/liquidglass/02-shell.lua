    Name = 'AetherLiquidGlass', Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    BorderSizePixel = 0, Visible = false, ZIndex = 100
}, guiParent)
-- Liquid Glass owns the visible Aether interface. Keep the legacy controller alive, but hide
-- every pre-existing GuiObject sibling so the classic search/module UI cannot bleed through or
-- sit above the new shell. The Liquid Glass root is intentionally excluded.
local legacySweepInstalled = false
local function hideLegacyVisuals()
    if legacySweepInstalled then return end
    legacySweepInstalled = true
    local function hide(object)
        if typeof(object) ~= 'Instance' or not object:IsA('GuiObject') or object:IsDescendantOf(root) then return end
        object.Visible = false
        if not hiddenLegacy[object] then
            hiddenLegacy[object] = true
            connect(object:GetPropertyChangedSignal('Visible'), function()
                if object.Parent and object.Visible and not object:IsDescendantOf(root) then object.Visible = false end
            end)
        end
    end
    for _, child in ipairs(guiParent:GetChildren()) do
        if child ~= root then
            if child:IsA('GuiObject') then
                hide(child)
            elseif child:IsA('ScreenGui') or child:IsA('Folder') then
                for _, descendant in ipairs(child:GetDescendants()) do hide(descendant) end
            end
        end
    end
end

task.defer(hideLegacyVisuals)

local scrim = create('TextButton', {
    Name = 'Scrim', Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.Deep,
    BackgroundTransparency = 0.62, AutoButtonColor = false, Text = '', BorderSizePixel = 0,
    ZIndex = 100
}, root)

local shellShadow = create('Frame', {
    Name = 'Shadow', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(1000, 640), BackgroundColor3 = Color3.new(0,0,0),
    BackgroundTransparency = 0.42, BorderSizePixel = 0, ZIndex = 101
}, root)
corner(shellShadow, 30)

local shell = create('Frame', {
    Name = 'Shell', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(980, 620), BackgroundTransparency = 0.2, ClipsDescendants = true,
    BorderSizePixel = 0, ZIndex = 102
}, root)
local shellGlass = glassify(shell, 28, 1)

local topbar = create('Frame', {
    Name = 'Topbar', Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1,
    BorderSizePixel = 0, ZIndex = 110, Active = true
}, shell)
local topDivider = create('Frame', {
    Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 1, -1),
    BackgroundColor3 = COLORS.White, BackgroundTransparency = 0.91, BorderSizePixel = 0, ZIndex = 111
}, topbar)

local traffic = {}
for i, spec in ipairs({{COLORS.Red, 18}, {COLORS.Yellow, 38}, {COLORS.Green, 58}}) do
    local dot = textButton(topbar, '')
    dot.Name = 'Traffic'..i
    dot.Size = UDim2.fromOffset(12, 12)
    dot.Position = UDim2.fromOffset(spec[2], 23)
    dot.BackgroundColor3 = spec[1]
    dot.BackgroundTransparency = 0.03
    dot.ZIndex = 114
    corner(dot, 99)
    traffic[i] = dot
end

local brandOrb = create('Frame', {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(88, 15),
    BackgroundColor3 = accent(), BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 114
}, topbar)
corner(brandOrb, 9)
local brandGrad = create('UIGradient', {
    Rotation = -35,
    Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(239, 210, 255)),
        ColorSequenceKeypoint.new(0.45, accent()), ColorSequenceKeypoint.new(1, Color3.fromRGB(116, 103, 255))})
}, brandOrb)
local brandLetter = label(brandOrb, 'A', 15, true, COLORS.White, Enum.TextXAlignment.Center)
brandLetter.Size = UDim2.fromScale(1, 1)
brandLetter.ZIndex = 115

local brandTitle = label(topbar, 'Aether', 16, true)
brandTitle.Size = UDim2.fromOffset(112, 28)
brandTitle.Position = UDim2.fromOffset(124, 8)
brandTitle.ZIndex = 114
local brandSub = label(topbar, 'Liquid Glass', 10, false, COLORS.Tertiary)
brandSub.Size = UDim2.fromOffset(112, 16)
brandSub.Position = UDim2.fromOffset(124, 31)
brandSub.ZIndex = 114

local statusPill = textButton(topbar, '')
statusPill.Size = UDim2.fromOffset(250, 30)
statusPill.AnchorPoint = Vector2.new(0.5, 0.5)
statusPill.Position = UDim2.new(0.5, 0, 0.5, 0)
statusPill.BackgroundColor3 = COLORS.Surface2
statusPill.BackgroundTransparency = 0.5
statusPill.ZIndex = 114
corner(statusPill, 12)
create('UIStroke', {Color = COLORS.White, Transparency = 0.9, Thickness = 1}, statusPill)
local statusText = label(statusPill, '', 11, false, COLORS.Secondary, Enum.TextXAlignment.Center)
statusText.Size = UDim2.fromScale(1, 1)
statusText.ZIndex = 115

local searchButton = textButton(topbar, '')
searchButton.Size = UDim2.fromOffset(118, 32)
searchButton.Position = UDim2.new(1, -132, 0, 13)
searchButton.BackgroundColor3 = COLORS.Surface2
searchButton.BackgroundTransparency = 0.46
searchButton.ZIndex = 114
corner(searchButton, 12)
create('UIStroke', {Color = COLORS.White, Transparency = 0.9, Thickness = 1}, searchButton)
local searchIcon = label(searchButton, '⌕', 17, true, COLORS.Secondary)
searchIcon.Size = UDim2.fromOffset(26, 32)
searchIcon.Position = UDim2.fromOffset(10, 0)
searchIcon.ZIndex = 115
local searchText = label(searchButton, 'Search', 11, false, COLORS.Secondary)
searchText.Size = UDim2.new(1, -42, 1, 0)
searchText.Position = UDim2.fromOffset(38, 0)
searchText.ZIndex = 115

local sidebar = create('Frame', {
    Name = 'Sidebar', Size = UDim2.new(0, 182, 1, -58), Position = UDim2.fromOffset(0, 58),
    BackgroundColor3 = COLORS.Deep, BackgroundTransparency = 0.68, BorderSizePixel = 0,
    ClipsDescendants = true, ZIndex = 106
}, shell)
local sidebarDivider = create('Frame', {
    Size = UDim2.new(0, 1, 1, -18), Position = UDim2.new(1, -1, 0, 9),
    BackgroundColor3 = COLORS.White, BackgroundTransparency = 0.91, BorderSizePixel = 0, ZIndex = 108
}, sidebar)
local navScroll = create('ScrollingFrame', {
    Name = 'Navigation', Size = UDim2.new(1, -12, 1, -72), Position = UDim2.fromOffset(6, 10),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 108
}, sidebar)
padding(navScroll, 4, 4, 4, 4)
local navList = create('UIListLayout', {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, navScroll)

local profileButton = textButton(sidebar, '')
profileButton.Size = UDim2.new(1, -16, 0, 46)
profileButton.Position = UDim2.new(0, 8, 1, -54)
profileButton.BackgroundColor3 = COLORS.Surface2
profileButton.BackgroundTransparency = 0.58
profileButton.ZIndex = 108
corner(profileButton, 14)
local avatar = create('ImageLabel', {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1,
    Image = lplr and ('rbxthumb://type=AvatarHeadShot&id='..lplr.UserId..'&w=150&h=150') or '', ZIndex = 109
}, profileButton)
corner(avatar, 10)
local profileName = label(profileButton, tostring(mainapi.Profile or 'default'), 11, true)
profileName.Size = UDim2.new(1, -52, 0, 20)
profileName.Position = UDim2.fromOffset(46, 5)
profileName.ZIndex = 109
local profileTier = label(profileButton, shared.AetherV2PremiumAuthorized and 'Premium' or 'Free', 9, false, COLORS.Tertiary)
profileTier.Size = UDim2.new(1, -52, 0, 16)
profileTier.Position = UDim2.fromOffset(46, 23)
profileTier.ZIndex = 109

local content = create('Frame', {
    Name = 'Content', Size = UDim2.new(1, -182, 1, -58), Position = UDim2.fromOffset(182, 58),
    BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 106
}, shell)
local pageTitle = label(content, 'Home', 25, true)
pageTitle.Size = UDim2.new(1, -48, 0, 34)
pageTitle.Position = UDim2.fromOffset(24, 19)
pageTitle.ZIndex = 112
local pageSubtitle = label(content, 'Aether at a glance', 11, false, COLORS.Tertiary)
pageSubtitle.Size = UDim2.new(1, -48, 0, 22)
pageSubtitle.Position = UDim2.fromOffset(25, 50)
pageSubtitle.ZIndex = 112

local filterBox = create('TextBox', {
    Name = 'Filter', Size = UDim2.fromOffset(190, 32), Position = UDim2.new(1, -214, 0, 22),
    BackgroundColor3 = COLORS.Surface2, BackgroundTransparency = 0.5, Text = '', PlaceholderText = 'Filter modules',
    PlaceholderColor3 = COLORS.Tertiary, TextColor3 = COLORS.Text, TextSize = 11,
    Font = Enum.Font.Gotham, ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 113
}, content)
corner(filterBox, 12)
create('UIStroke', {Color = COLORS.White, Transparency = 0.91, Thickness = 1}, filterBox)
padding(filterBox, 12, 12, 0, 0)

local page = create('ScrollingFrame', {
    Name = 'Page', Size = UDim2.new(1, -32, 1, -92), Position = UDim2.fromOffset(16, 82),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = accent(), ScrollBarImageTransparency = 0.55,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 108
}, content)
padding(page, 8, 8, 2, 18)
local pageList = create('UIListLayout', {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, page)

local inspector = create('Frame', {
    Name = 'Inspector', AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 330, 0, 58),
    Size = UDim2.new(0, 322, 1, -58), BackgroundTransparency = 0.2, BorderSizePixel = 0,
    ClipsDescendants = true, Visible = false, ZIndex = 130
}, shell)
local inspectorGlass = glassify(inspector, 22, 2)
local inspectorTitle = label(inspector, '', 19, true)
inspectorTitle.Size = UDim2.new(1, -70, 0, 30)
inspectorTitle.Position = UDim2.fromOffset(18, 14)
inspectorTitle.ZIndex = 134
local inspectorCategory = label(inspector, '', 10, false, COLORS.Tertiary)
inspectorCategory.Size = UDim2.new(1, -70, 0, 18)
inspectorCategory.Position = UDim2.fromOffset(19, 42)
inspectorCategory.ZIndex = 134
local inspectorClose = textButton(inspector, '×')
inspectorClose.Size = UDim2.fromOffset(32, 32)
inspectorClose.Position = UDim2.new(1, -43, 0, 13)
inspectorClose.BackgroundColor3 = COLORS.Surface2
inspectorClose.BackgroundTransparency = 0.5
inspectorClose.TextSize = 18
inspectorClose.ZIndex = 134
corner(inspectorClose, 11)
local inspectorBody = create('ScrollingFrame', {
    Size = UDim2.new(1, -20, 1, -74), Position = UDim2.fromOffset(10, 66),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
    ScrollBarImageColor3 = accent(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(), ZIndex = 133
}, inspector)
padding(inspectorBody, 8, 8, 4, 18)
local inspectorList = create('UIListLayout', {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, inspectorBody)

local miniPill = textButton(guiParent, '')
miniPill.Name = 'AetherLiquidMini'
miniPill.AnchorPoint = Vector2.new(0.5, 0)
miniPill.Position = UDim2.new(0.5, 0, 0, 18)
miniPill.Size = UDim2.fromOffset(142, 38)
miniPill.BackgroundColor3 = COLORS.Surface
miniPill.BackgroundTransparency = 0.2
miniPill.Visible = false
miniPill.ZIndex = 160
corner(miniPill, 16)
glassify(miniPill, 16, 1)
local miniOrb = create('Frame', {Size = UDim2.fromOffset(22,22), Position = UDim2.fromOffset(9,8), BackgroundColor3 = accent(), BorderSizePixel = 0, ZIndex = 162}, miniPill)
corner(miniOrb, 8)
local miniLabel = label(miniPill, 'Aether', 12, true)
miniLabel.Size = UDim2.new(1, -44, 1, 0)
miniLabel.Position = UDim2.fromOffset(40, 0)
miniLabel.ZIndex = 162

local state = {
    Visible = false,
    Minimized = false,
    Maximized = false,
    Page = 'Home',
    Category = nil,
    SelectedModule = nil,
    BindingModule = nil,
    Recent = {},
    NavButtons = {},
    ModuleCards = {},
    ModuleFingerprint = '',
    CompactSidebar = false
}

local CATEGORY_ORDER = {'Combat', 'Blatant', 'Movement', 'Player', 'Utility', 'World', 'Inventory', 'Render', 'Legit', 'Kits', 'Minigames'}
local CATEGORY_ICONS = {
    Home = '⌂', Combat = '◉', Blatant = '⚡', Movement = '➜', Player = '◇', Utility = '⌘',
    World = '◫', Inventory = '▦', Render = '✦', Legit = '◎', Kits = '◈', Minigames = '◆',
    Actions = '⋯', Settings = '⚙', Aether = '◌', Profiles = '◧', Friends = '♡', Targets = '◎'
}

local function moduleDisplayName(module)
    if mainapi.GetModuleDisplayName then
        local ok, result = pcall(mainapi.GetModuleDisplayName, mainapi, module)
        if ok and type(result) == 'string' then return result end
    end
    return tostring(module.Name or 'Module')
end

local function collectModules()
    local modules, seen = {}, {}
    local function collect(tab, fallbackCategory)
        if type(tab) ~= 'table' then return end
        for key, module in pairs(tab) do
            if type(module) == 'table' and not seen[module] and (module.Name or type(key) == 'string') then
                seen[module] = true
                if module.Name == nil and type(key) == 'string' then module.Name = key end
                module.LiquidCategory = module.Category or module.LiquidCategory or fallbackCategory or 'Other'
                table.insert(modules, module)
            end
        end
    end
    collect(mainapi.Modules)
    collect(mainapi.Legit and mainapi.Legit.Modules, 'Legit')
    collect(mainapi.Kits and mainapi.Kits.Modules, 'Kits')
    table.sort(modules, function(a, b)
        local ca, cb = tostring(a.LiquidCategory or ''), tostring(b.LiquidCategory or '')
        if ca == cb then return moduleDisplayName(a):lower() < moduleDisplayName(b):lower() end
        return ca < cb
    end)
    return modules
end

local function categorySet(modules)
    local result = {}
    for _, module in ipairs(modules) do result[tostring(module.LiquidCategory or 'Other')] = true end
    return result
end

local PANEL_ALIASES = {Main = 'Aether', Profiles = 'Profiles'}
local PANEL_ICONS = {Aether = '◌', Profiles = '◧', Friends = '♡', Targets = '◎'}

local function categoryApiFor(displayName)
    local wanted = displayName == 'Aether' and 'Main' or displayName
    return type(mainapi.Categories) == 'table' and mainapi.Categories[wanted] or nil, wanted
end

local function categoryHasControls(api)
    if type(api) ~= 'table' then return false end
    if type(api.Options) == 'table' and next(api.Options) ~= nil then return true end
    if type(api.LiquidButtons) == 'table' and #api.LiquidButtons > 0 then return true end
    if type(api.LiquidDividers) == 'table' and #api.LiquidDividers > 0 then return true end
    return false
end

local function collectPanelCategories(moduleCategories)
    local result, seen = {}, {}
    for rawName, api in pairs(mainapi.Categories or {}) do
        local display = PANEL_ALIASES[tostring(rawName)] or tostring(rawName)
        if not moduleCategories[display] and not moduleCategories[tostring(rawName)] and categoryHasControls(api) then
            seen[display] = true
            table.insert(result, display)
        end
    end
    -- TargetOptions is a shared option surface rather than a normal category in new.core.
    if type(mainapi.TargetOptions) == 'table' and next(mainapi.TargetOptions) ~= nil and not seen.Targets then
        table.insert(result, 'Targets')
    end
    table.sort(result, function(a, b)
        local priority = {Aether = 1, Profiles = 2, Friends = 3, Targets = 4}
        local pa, pb = priority[a] or 100, priority[b] or 100
        if pa == pb then return a:lower() < b:lower() end
        return pa < pb
    end)
    return result
end

local function clearChildren(container, keep)
    for _, child in ipairs(container:GetChildren()) do
        if child ~= keep and not child:IsA('UIListLayout') and not child:IsA('UIGridLayout') and not child:IsA('UIPadding') then
            child:Destroy()
        end
    end
end

local function updateStatus()
    local gameName = game.Name
    pcall(function()
        if mainapi.GameInfo and mainapi.GameInfo.Name then gameName = tostring(mainapi.GameInfo.Name) end
    end)
    local tier = shared.AetherV2PremiumAuthorized and 'Premium' or 'Free'
    statusText.Text = tostring(gameName)..'  •  '..tier..'  •  v'..tostring(mainapi.Version or '?')
    profileName.Text = tostring(mainapi.Profile or 'default')
    profileTier.Text = tier
    brandOrb.BackgroundColor3 = accent()
