-- AetherV2 Liquid Glass GUI
-- Completely new unified frontend; Aether's current new GUI is used only as the
-- controller/config backend so existing modules, profiles, binds and saving stay compatible.
-- No GlassmorphicUI source is copied here.

local license, suppliedMainApi = ...
license = type(license) == 'table' and license or {}

local cloneref = cloneref or function(v) return v end
local TweenService = cloneref(game:GetService('TweenService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local RunService = cloneref(game:GetService('RunService'))
local Lighting = cloneref(game:GetService('Lighting'))
local Players = cloneref(game:GetService('Players'))
local HttpService = cloneref(game:GetService('HttpService'))
local GuiService = cloneref(game:GetService('GuiService'))
local lplr = Players.LocalPlayer

local isfile = isfile or function(path)
    local ok, value = pcall(readfile, path)
    return ok and type(value) == 'string' and value ~= ''
end

local function validSource(body)
    if type(body) ~= 'string' or #body < 64 or body == '404: Not Found' then return false end
    local head = body:sub(1, 300):lower()
    return not head:find('<!doctype html', 1, true) and not head:find('<html', 1, true)
end

local function currentRef()
    if type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') ~= '' then
        return shared.AetherV2PublicRef:gsub('%s+', '')
    end
    local ok, value = pcall(readfile, 'aetherv2/profiles/commit.txt')
    if ok and type(value) == 'string' and value:gsub('%s+', '') ~= '' then
        return value:gsub('%s+', '')
    end
    return 'main'
end

local function getBackendSource()
    if isfile('aetherv2/guis/new.lua') then
        local ok, body = pcall(readfile, 'aetherv2/guis/new.lua')
        if ok and validSource(body) then return body end
    end

    local body
    if type(shared.AetherV2FetchSource) == 'function' then
        local ok, result = pcall(shared.AetherV2FetchSource, 'guis/new.lua', currentRef())
        if ok then body = result end
    end
    if not validSource(body) then
        local ok, result = pcall(game.HttpGet, game,
            'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..currentRef()..'/guis/new.lua', true)
        if ok then body = result end
    end
    if not validSource(body) then
        error('AetherV2 Liquid Glass: could not load the Aether GUI controller backend', 0)
    end
    return body
end

local mainapi = suppliedMainApi
if type(mainapi) ~= 'table' then
    local backendChunk, backendError = loadstring(getBackendSource(), 'aether-liquid-controller')
    if not backendChunk then error('AetherV2 Liquid Glass backend compile failed: '..tostring(backendError), 0) end
    mainapi = backendChunk(license)
end
if type(mainapi) ~= 'table' then error('AetherV2 Liquid Glass backend returned an invalid controller', 0) end
if suppliedMainApi == nil and type(mainapi.LiquidGlass) == 'table' then return mainapi end

-- Capture settings metadata while future universal/game modules are created. The legacy
-- API intentionally stores very little metadata on option objects; Liquid Glass needs it
-- to render a faithful native control without scraping pixels from the old menu.
do
    local components = mainapi.Components
    if type(components) == 'table' then
        local originals = {}
        for kind, fn in pairs(components) do
            if type(fn) == 'function' then originals[kind] = fn end
        end
        for kind, original in pairs(originals) do
            local componentKind, componentFn = kind, original
            components[componentKind] = function(settings, children, api)
                settings = settings or {}
                local result = componentFn(settings, children, api)
                if componentKind == 'Button' then
                    api.LiquidButtons = api.LiquidButtons or {}
                    if type(result) == 'table' then
                        result.LiquidMeta = settings
                        result.LiquidType = 'Button'
                        result.Type = result.Type or 'Button'
                        result.Name = result.Name or settings.Name or 'Action'
                        result.Tooltip = result.Tooltip or settings.Tooltip
                        result.Function = result.Function or settings.Function or function() end
                        result.Visible = settings.Visible
                        if not table.find(api.LiquidButtons, result) then
                            result.Index = result.Index or #api.LiquidButtons
                            table.insert(api.LiquidButtons, result)
                        end
                    else
                        table.insert(api.LiquidButtons, {
                            Type = 'Button',
                            LiquidType = 'Button',
                            LiquidMeta = settings,
                            Name = settings.Name or 'Action',
                            Tooltip = settings.Tooltip,
                            Function = settings.Function or function() end,
                            Visible = settings.Visible,
                            Index = #api.LiquidButtons
                        })
                    end
                elseif componentKind == 'Divider' then
                    api.LiquidDividers = api.LiquidDividers or {}
                    table.insert(api.LiquidDividers, {
                        Type = 'Divider', Name = settings.Name or settings.Text,
                        Index = #api.LiquidDividers
                    })
                elseif type(result) == 'table' then
                    result.LiquidMeta = settings
                    result.LiquidType = componentKind
                    result.Name = result.Name or settings.Name
                    if result.Type == nil and componentKind ~= 'Targets' then result.Type = componentKind end
                    result.Min = result.Min or settings.Min
                    result.Max = result.Max or settings.Max
                    result.Decimal = result.Decimal or settings.Decimal
                    result.ListValues = settings.List
                    result.Suffix = settings.Suffix
                    result.Tooltip = settings.Tooltip
                end
                return result
            end
        end
    end
end

local COLORS = {
    Text = Color3.fromRGB(245, 245, 250),
    Secondary = Color3.fromRGB(177, 179, 192),
    Tertiary = Color3.fromRGB(124, 126, 140),
    Surface = Color3.fromRGB(20, 21, 28),
    Surface2 = Color3.fromRGB(31, 32, 42),
    Deep = Color3.fromRGB(8, 9, 13),
    White = Color3.new(1, 1, 1),
    Red = Color3.fromRGB(255, 95, 87),
    Yellow = Color3.fromRGB(254, 188, 46),
    Green = Color3.fromRGB(40, 200, 64)
}

local function accent()
    local c = mainapi.GUIColor or {Hue = 0.756, Sat = 0.55, Value = 1}
    return Color3.fromHSV(c.Hue or 0.756, c.Sat or 0.55, c.Value or 1)
end

local settingsPath = 'aetherv2/profiles/liquidglass.json'
local liquidSettings = {
    GlassOpacity = 0.82,
    Blur = true,
    BlurSize = 8,
    Motion = true,
    Scale = 1,
    CompactCards = false
}

local function loadLiquidSettings()
    if not isfile(settingsPath) then return end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(settingsPath)) end)
    if not ok or type(decoded) ~= 'table' then return end
    for key, value in pairs(decoded) do
        if liquidSettings[key] ~= nil then liquidSettings[key] = value end
    end
end

local function saveLiquidSettings()
    if type(writefile) ~= 'function' then return end
    pcall(function() writefile(settingsPath, HttpService:JSONEncode(liquidSettings)) end)
end
loadLiquidSettings()

local uiConnections = {}
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(uiConnections, connection)
    return connection
end

local function create(className, props, parent)
    local object = Instance.new(className)
    if props then
        for key, value in pairs(props) do
            object[key] = value
        end
    end
    if parent then object.Parent = parent end
    return object
end

local function corner(parent, radius)
    return create('UICorner', {CornerRadius = UDim.new(0, radius or 12)}, parent)
end

local function padding(parent, l, r, t, b)
    return create('UIPadding', {
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0),
        PaddingTop = UDim.new(0, t or l or 0), PaddingBottom = UDim.new(0, b or t or l or 0)
    }, parent)
end

local function label(parent, text, size, bold, color, align)
    return create('TextLabel', {
        BackgroundTransparency = 1,
        Text = tostring(text or ''),
        TextColor3 = color or COLORS.Text,
        TextSize = size or 14,
        Font = bold and Enum.Font.GothamMedium or Enum.Font.Gotham,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        BorderSizePixel = 0
    }, parent)
end

local function textButton(parent, text)
    return create('TextButton', {
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = text or '',
        TextColor3 = COLORS.Text,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0
    }, parent)
end

local glassRecords = {}
local function glassify(frame, radius, depth)
    radius = radius or 18
    depth = depth or 1
    frame.BackgroundColor3 = COLORS.Surface
    frame.BackgroundTransparency = math.clamp(0.28 + (1 - liquidSettings.GlassOpacity) * 0.42 + (depth - 1) * 0.08, 0.18, 0.72)
    frame.BorderSizePixel = 0
    corner(frame, radius)

    local tint = create('Frame', {
        Name = 'LiquidTint', Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent(),
        BackgroundTransparency = 0.94 + math.min(depth * 0.012, 0.035), BorderSizePixel = 0,
        Active = false, ZIndex = math.max(frame.ZIndex, 1)
    }, frame)
    corner(tint, radius)
    local tintGradient = create('UIGradient', {
        Rotation = 28,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.18),
            NumberSequenceKeypoint.new(0.42, 0.82),
            NumberSequenceKeypoint.new(1, 0.48)
        })
    }, tint)

    local sheen = create('Frame', {
        Name = 'LiquidSheen', Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.White,
        BackgroundTransparency = 0.97, BorderSizePixel = 0, Active = false,
        ZIndex = math.max(frame.ZIndex, 1)
    }, frame)
    corner(sheen, radius)
    local sheenGradient = create('UIGradient', {
        Rotation = -38,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(0.18, 0.78),
            NumberSequenceKeypoint.new(0.62, 0.96),
            NumberSequenceKeypoint.new(1, 0.58)
        })
    }, sheen)

    local rim = create('UIStroke', {
        Name = 'LiquidRim', ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = COLORS.White, Thickness = depth == 1 and 1.15 or 1,
        Transparency = depth == 1 and 0.68 or 0.78
    }, frame)
    local rimGradient = create('UIGradient', {
        Rotation = -45,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.35, accent()),
            ColorSequenceKeypoint.new(0.7, Color3.fromRGB(145, 195, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(0.4, 0.62),
            NumberSequenceKeypoint.new(0.72, 0.82),
            NumberSequenceKeypoint.new(1, 0.3)
        })
    }, rim)

    local record = {Frame = frame, Tint = tint, TintGradient = tintGradient, Sheen = sheen,
        SheenGradient = sheenGradient, Rim = rim, RimGradient = rimGradient, Depth = depth}
    table.insert(glassRecords, record)
    return record
end

local function refreshGlassTheme()
    local a = accent()
    for _, record in ipairs(glassRecords) do
        if record.Frame and record.Frame.Parent then
            record.Tint.BackgroundColor3 = a
            record.Frame.BackgroundTransparency = math.clamp(
                0.28 + (1 - liquidSettings.GlassOpacity) * 0.42 + (record.Depth - 1) * 0.08, 0.18, 0.72)
            record.RimGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, COLORS.White),
                ColorSequenceKeypoint.new(0.35, a),
                ColorSequenceKeypoint.new(0.7, Color3.fromRGB(145, 195, 255)),
                ColorSequenceKeypoint.new(1, COLORS.White)
            })
        end
    end
end

local function tween(object, duration, goal, style, direction)
    if not object or not object.Parent then return end
    if not liquidSettings.Motion then
        for key, value in pairs(goal) do object[key] = value end
        return
    end
    local info = TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out)
    local t = TweenService:Create(object, info, goal)
    t:Play()
    return t
end

-- Hide only the legacy category surfaces. Special controller windows (diagnostics,
-- update center, error logs) remain usable when an action explicitly opens them.
local hiddenLegacy = setmetatable({}, {__mode = 'k'})
local function hideLegacyMenus()
    for _, category in pairs(mainapi.Categories or {}) do
        local object = type(category) == 'table' and category.Object or nil
        if typeof(object) == 'Instance' and object:IsA('GuiObject') and not hiddenLegacy[object] then
            hiddenLegacy[object] = true
            object.Visible = false
            connect(object:GetPropertyChangedSignal('Visible'), function()
                if object.Parent and object.Visible then object.Visible = false end
            end)
        end
    end
    if mainapi.gui then
        local oldSpot = mainapi.gui:FindFirstChild('NexusSpotlight', true)
        if oldSpot and oldSpot:IsA('GuiObject') and not hiddenLegacy[oldSpot] then
            hiddenLegacy[oldSpot] = true
            oldSpot.Visible = false
            connect(oldSpot:GetPropertyChangedSignal('Visible'), function()
                if oldSpot.Parent and oldSpot.Visible then oldSpot.Visible = false end
            end)
        end
    end
end
hideLegacyMenus()

local guiParent = mainapi.gui
if typeof(guiParent) ~= 'Instance' then error('AetherV2 Liquid Glass: controller GUI root missing', 0) end

local blur = Lighting:FindFirstChild('AetherLiquidGlassBlur')
if blur and not blur:IsA('BlurEffect') then blur = nil end
if not blur then
    blur = create('BlurEffect', {Name = 'AetherLiquidGlassBlur', Size = 0}, Lighting)
end

local root = create('Frame', {
