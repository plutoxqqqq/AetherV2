-- AetherV2 Liquid Glass frontend entry.
-- The frontend is split into six readable source sections. Older builds referenced two
-- non-existent extra sections, which caused a guaranteed cache failure. This loader owns the
-- manifest, validates every cached part, repairs bad files, and supplies the missing final UI
-- controller/input section when assembling the frontend.

local license, suppliedMainApi = ...
license = type(license) == 'table' and license or {}

local PARTS = {
	'01-runtime.lua',
	'02-shell.lua',
	'03-controls.lua',
	'04-controls-extra.lua',
	'05-inspector.lua',
	'06-pages.lua'
}
local LOCAL_DIR = 'aetherv2/guis/liquidglass/'
local REMOTE_DIR = 'guis/liquidglass/'
local CACHE_REF_PATH = LOCAL_DIR..'.ref'

local function validSource(body)
	if type(body) ~= 'string' or #body < 32 or body == '404: Not Found' then return false end
	local head = body:sub(1, 300):lower()
	return not head:find('<!doctype html', 1, true)
		and not head:find('<html', 1, true)
		and not body:find('SourceEndpoint', 1, true)
end

local function currentRef()
	if type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') ~= '' then
		return shared.AetherV2PublicRef:gsub('%s+', '')
	end
	local ok, ref = pcall(readfile, 'aetherv2/profiles/commit.txt')
	if ok and type(ref) == 'string' then
		ref = ref:gsub('%s+', '')
		if ref ~= '' then return ref end
	end
	return 'main'
end

local function ensureFolder(path)
	if type(makefolder) ~= 'function' then return end
	local built = ''
	for segment in path:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if type(isfolder) ~= 'function' or not isfolder(built) then pcall(makefolder, built) end
	end
end

local function fetch(path, ref)
	if type(shared.AetherV2FetchSource) == 'function' then
		local ok, result = pcall(shared.AetherV2FetchSource, path, ref)
		if ok and validSource(result) then return result end
	end
	local ok, result = pcall(game.HttpGet, game,
		'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/'..path, true)
	return ok and validSource(result) and result or nil
end

local ACTIVE_REF = currentRef()
local cachedRef
if type(isfile) == 'function' and isfile(CACHE_REF_PATH) then
	local ok, value = pcall(readfile, CACHE_REF_PATH)
	if ok and type(value) == 'string' then cachedRef = value:gsub('%s+', '') end
end
local CACHE_IS_CURRENT = cachedRef == ACTIVE_REF

local function readValid(path)
	if type(isfile) ~= 'function' or not isfile(path) then return nil end
	local ok, body = pcall(readfile, path)
	return ok and validSource(body) and body or nil
end

local function cachePart(path, body)
	if type(writefile) ~= 'function' then return true end
	ensureFolder(path:gsub('/[^/]+$',''))
	for attempt = 1, 4 do
		local ok = pcall(writefile, path, body)
		if ok then
			task.wait(0.03 * attempt)
			local cached = readValid(path)
			if cached == body then return true end
		end
		if attempt < 4 then task.wait(0.03 * attempt) end
	end
	return false
end

local function getPart(name)
	local localPath = LOCAL_DIR..name
	if CACHE_IS_CURRENT then
		local cached = readValid(localPath)
		if cached then return cached end
	end

	local body = fetch(REMOTE_DIR..name, ACTIVE_REF)
	if not body and ACTIVE_REF ~= 'main' then body = fetch(REMOTE_DIR..name, 'main') end
	if not body then error('AetherV2 Liquid Glass: failed to load '..name, 0) end

	if type(writefile) == 'function' and not cachePart(localPath, body) then
		error('AetherV2 Liquid Glass: could not cache '..localPath..' - unreadable cache after retries', 0)
	end
	return body
end

local sourceParts = table.create(#PARTS)
for index, name in ipairs(PARTS) do
	sourceParts[index] = getPart(name)
end

local source = table.concat(sourceParts, '\n')

-- 06-pages.lua in the broken split ends exactly where renderActions begins. Replace that
-- incomplete tail with the complete controller/input implementation below instead of asking the
-- loader for files that are not present in the repository.
local actionsStart = source:find("\nlocal function renderActions()", 1, true)
if actionsStart then source = source:sub(1, actionsStart - 1) end

-- Feature metadata is the source of truth for NEW / UPDATED / PATCHED / REMOVED tags and for the
-- statically-known premium list. Authorized premium modules loaded from the private source are
-- added to the short-lived shared lookup by main.lua; module objects themselves are never mutated.
local featurePrelude = [[
local featureMeta = {
    newModules = {},
    updatedModules = {},
    patchedModules = {},
    removedModules = {},
    premiumModules = {}
}

local function normalizeFeatureName(value)
    return tostring(value or ''):lower():gsub('[%s_%-%./]+', '')
end

local function addFeatureNames(destination, values)
    if type(values) ~= 'table' then return end
    for _, value in ipairs(values) do
        local key = normalizeFeatureName(value)
        if key ~= '' then destination[key] = true end
    end
end

local function loadFeatureMetadata()
    local function decode(body)
        if type(body) ~= 'string' then return false end
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, body)
        if not ok or type(decoded) ~= 'table' then return false end
        addFeatureNames(featureMeta.newModules, decoded.newModules or decoded.added)
        addFeatureNames(featureMeta.updatedModules, decoded.updatedModules or decoded.updated)
        addFeatureNames(featureMeta.patchedModules, decoded.patchedModules)
        addFeatureNames(featureMeta.removedModules, decoded.removedModules)
        addFeatureNames(featureMeta.premiumModules, decoded.premiumModules)
        return true
    end

    local loaded = false
    local remoteRef = currentRef()
    local function fetchFeature(ref)
        local ok, body = pcall(game.HttpGet, game,
            'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/profiles/features.json', true)
        return ok and type(body) == 'string' and body or nil
    end
    local body = fetchFeature(remoteRef)
    if body then loaded = decode(body) end
    if not loaded and remoteRef ~= 'main' then
        body = fetchFeature('main')
        if body then loaded = decode(body) end
    end
    if not loaded and type(isfile) == 'function' and isfile('aetherv2/profiles/features.json') then
        local ok, cached = pcall(readfile, 'aetherv2/profiles/features.json')
        if ok then decode(cached) end
    end
end
loadFeatureMetadata()

local function featureTagsFor(module)
    local key = normalizeFeatureName(moduleDisplayName(module))
    local tags = {}
    local function add(tag)
        for _, existing in ipairs(tags) do if existing == tag then return end end
        table.insert(tags, tag)
    end
    if featureMeta.newModules[key] then add('NEW') end
    if featureMeta.updatedModules[key] then add('UPDATED') end
    if featureMeta.patchedModules[key] then add('PATCHED') end
    if featureMeta.removedModules[key] then add('REMOVED') end
    if featureMeta.premiumModules[key] then add('PREMIUM') end
    if type(shared.AetherV2PremiumModules) == 'table' and shared.AetherV2PremiumModules[key] then add('PREMIUM') end
    return tags
end

local function tagColor(tag)
    if tag == 'PREMIUM' or tag == 'NEW' then return accent() end
    return COLORS.Surface
end

local function renderFeatureTags(parent, module)
    local tags = featureTagsFor(module)
    if #tags == 0 then return end
    local holder = create('Frame', {
        Name = 'FeatureTags', Size = UDim2.new(1, -28, 0, 20),
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -8),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 118
    }, parent)
    local layout = create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4)
    }, holder)
    local widths = {NEW = 36, UPDATED = 52, PATCHED = 52, REMOVED = 52, PREMIUM = 62}
    for _, tag in ipairs(tags) do
        local pill = label(holder, tag, 7, true, COLORS.White, Enum.TextXAlignment.Center)
        pill.Size = UDim2.fromOffset(widths[tag] or 50, 18)
        pill.BackgroundColor3 = tagColor(tag)
        pill.BackgroundTransparency = (tag == 'PREMIUM' or tag == 'NEW') and 0.12 or 0.25
        pill.ZIndex = 119
        corner(pill, 7)
        create('UIStroke', {
            Color = tagColor(tag), Thickness = 1,
            Transparency = (tag == 'PREMIUM' or tag == 'NEW') and 0.25 or 0.7
        }, pill)
    end
end
]]

local featureInsert = source:find("\nlocal function moduleCard(parent,module,order)", 1, true)
if featureInsert then
	source = source:sub(1, featureInsert - 1)..'\n'..featurePrelude..source:sub(featureInsert)
else
	error('AetherV2 Liquid Glass: module-card section is missing', 0)
end

-- Make the whole-card hit target leave the switch area to the switch itself. This removes the
-- intermittent click race where the card and switch both received the same mouse click.
source = source:gsub(
	"local hit=textButton%(card,''%); hit%.Size=UDim2%.fromScale%(1,1%); hit%.ZIndex=112",
	"local hit=textButton(card,''); hit.Size=UDim2.new(1,-64,1,0); hit.ZIndex=111; hit.Active=true",
	1
)
source = source:gsub("switch%.AnchorPoint=Vector2%.new%(1,0%); switch%.Position=UDim2%.new%(1,-12,0,12%); switch%.ZIndex=117",
	"switch.AnchorPoint=Vector2.new(1,0); switch.Position=UDim2.new(1,-12,0,12); switch.ZIndex=120",
	1
)

-- Rounded cards own all visual children so gradients, tag pills and hover surfaces cannot bleed
-- through the antialiased side pixels of an off module.
source = source:gsub("    corner(frame, 16)\n    local stroke",
    "    corner(frame, 16)\n    frame.ClipsDescendants = true\n    local stroke",
    1)

local oldDesc = "local desc=label(card,tostring(module.Tooltip or ''),9,false,COLORS.Secondary); desc.Size=UDim2.new(1,-28,0,32); desc.Position=UDim2.fromOffset(14,55); desc.TextWrapped=true; desc.TextYAlignment=Enum.TextYAlignment.Top; desc.ZIndex=114; desc.Visible=not liquidSettings.CompactCards"
local newDesc = "local hasFeatureTags=#featureTagsFor(module)>0; local desc=label(card,tostring(module.Tooltip or ''),9,false,COLORS.Secondary); desc.Size=UDim2.new(1,hasFeatureTags and -200 or -28,0,32); desc.Position=UDim2.fromOffset(14,55); desc.TextWrapped=true; desc.TextYAlignment=Enum.TextYAlignment.Top; desc.ZIndex=114; desc.Visible=not liquidSettings.CompactCards; renderFeatureTags(card,module)"
local descFirst = source:find(oldDesc,1,true)
if descFirst then source = source:sub(1,descFirst-1)..newDesc..source:sub(descFirst+#oldDesc) end

local finalTail = [[
local function renderActions()
    activeOptionRefreshers={}; state.ModuleCards={}; clearChildren(page)
    pageTitle.Text='Actions'; pageSubtitle.Text='Aether commands in one place'; filterBox.Visible=true
    local query=filterBox.Text:lower():gsub('^%s*(.-)%s*$','%1')
    local actions=getLiquidActions()
    if #actions==0 then
        local empty=cardSurface(page,112,1)
        local text=label(empty,'No actions available',11,false,COLORS.Secondary,Enum.TextXAlignment.Center)
        text.Size=UDim2.fromScale(1,1); text.ZIndex=114
        return
    end
    local shown=0
    for index,action in ipairs(actions) do
        local name=tostring(action.Name or 'Action')
        local desc=actionDescription(action)
        local haystack=(name..' '..desc):lower()
        if query=='' or haystack:find(query,1,true) then
            shown+=1
            actionCard(page,name,desc,index,function()
                if type(action.Function)=='function' then pcall(action.Function) end
            end)
        end
    end
    if shown==0 then
        local empty=cardSurface(page,112,1)
        local text=label(empty,'No matching actions',11,false,COLORS.Secondary,Enum.TextXAlignment.Center)
        text.Size=UDim2.fromScale(1,1); text.ZIndex=114
    end
end

local function renderSearchResults()
    activeOptionRefreshers={}; state.ModuleCards={}; clearChildren(page)
    pageTitle.Text='Search'; pageSubtitle.Text='Search every available module'; filterBox.Visible=true
    local query=filterBox.Text:lower():gsub('^%s*(.-)%s*$','%1')
    if query=='' then
        local empty=cardSurface(page,112,1)
        local text=label(empty,'Type a module name to search',11,false,COLORS.Secondary,Enum.TextXAlignment.Center)
        text.Size=UDim2.fromScale(1,1); text.ZIndex=114
        return
    end
    local matches={}
    for _,module in ipairs(collectModules()) do
        local name=moduleDisplayName(module)
        local haystack=(name..' '..tostring(module.LiquidCategory or module.Category or '')..' '..tostring(module.Tooltip or '')):lower()
        if haystack:find(query,1,true) then table.insert(matches,module) end
    end
    if #matches==0 then
        local empty=cardSurface(page,112,1)
        local text=label(empty,'No matching modules',11,false,COLORS.Secondary,Enum.TextXAlignment.Center)
        text.Size=UDim2.fromScale(1,1); text.ZIndex=114
        return
    end
    local cardHeight=liquidSettings.CompactCards and 78 or 96
    local oneColumn=state.CompactSidebar or page.AbsoluteSize.X<600
    local cols=oneColumn and 1 or 2
    local rows=math.max(1,math.ceil(#matches/cols))
    local host=create('Frame',{Size=UDim2.new(1,0,0,rows*cardHeight+math.max(0,rows-1)*10),BackgroundTransparency=1,LayoutOrder=1,ZIndex=110},page)
    local grid=createGrid(host,cardHeight)
    grid.FillDirectionMaxCells=cols
    grid.CellSize=oneColumn and UDim2.new(1,-2,0,cardHeight) or UDim2.new(0.5,-5,0,cardHeight)
    for i,module in ipairs(matches) do moduleCard(host,module,i) end
end

local function renderPage()
    if state.Page=='Home' then renderHome(); return end
    if state.Page=='Category' then renderCategory(state.Category or 'Combat'); return end
    if state.Page=='Search' then renderSearchResults(); return end
    if state.Page=='Settings' then renderSettings(); return end
    if state.Page=='Diagnostics' then renderDiagnostics(); return end
    if state.Page=='Errors' then renderErrors(); return end
    if state.Page=='Updates' then renderUpdates(); return end
    if state.Page=='Actions' then renderActions(); return end
    renderHome()
end
state.RenderPage=renderPage

local function navButton(name, icon, order, pageName, categoryName)
    local button=textButton(navScroll,'')
    button.Name='Nav_'..name
    button.Size=UDim2.new(1,0,0,38)
    button.LayoutOrder=order
    button.BackgroundColor3=COLORS.Surface2
    button.BackgroundTransparency=1
    button.ZIndex=110
    corner(button,10)
    local iconLabel=label(button,icon,14,true,COLORS.Secondary,Enum.TextXAlignment.Center)
    iconLabel.Size=UDim2.fromOffset(28,38); iconLabel.Position=UDim2.fromOffset(2,0); iconLabel.ZIndex=111
    local text=label(button,name,10,true,COLORS.Secondary)
    text.Size=UDim2.new(1,-40,1,0); text.Position=UDim2.fromOffset(34,0); text.ZIndex=111
    state.NavButtons[name]={Button=button,Label=text}
    connect(button.MouseEnter,function() tween(button,0.12,{BackgroundTransparency=0.55}) end)
    connect(button.MouseLeave,function() tween(button,0.12,{BackgroundTransparency=1}) end)
    connect(button.MouseButton1Click,function()
        state.Page=pageName
        state.Category=categoryName
        if pageName=='Category' or pageName=='Actions' or pageName=='Search' then
            filterBox.Text=''
        end
        renderPage()
    end)
end

local navOrder=1
navButton('Home',CATEGORY_ICONS.Home,navOrder,'Home'); navOrder+=1
for _,category in ipairs(CATEGORY_ORDER) do
    navButton(category,CATEGORY_ICONS[category] or '•',navOrder,'Category',category)
    navOrder+=1
end
for _,panel in ipairs(collectPanelCategories(categorySet(collectModules()))) do
    navButton(panel,PANEL_ICONS[panel] or '•',navOrder,'Category',panel)
    navOrder+=1
end
navButton('Search','⌕',navOrder,'Search'); navOrder+=1
navButton('Actions','⋯',navOrder,'Actions'); navOrder+=1
navButton('Settings','⚙',navOrder,'Settings')

connect(traffic[1].MouseButton1Click,function() setOpen(false) end)
connect(traffic[2].MouseButton1Click,minimize)
connect(traffic[3].MouseButton1Click,toggleMaximize)
connect(miniPill.MouseButton1Click,function() setOpen(true) end)
connect(inspectorClose.MouseButton1Click,closeInspector)
connect(searchButton.MouseButton1Click,function()
    state.Page='Search'; state.Category=nil
    filterBox.Text=''
    renderPage()
    task.defer(function() if filterBox.Parent and filterBox.Visible then pcall(function() filterBox:CaptureFocus() end) end end)
end)

local filterRevision=0
local function rerenderFilteredPage()
    if state.Page~='Category' and state.Page~='Search' and state.Page~='Actions' then return end
    filterRevision+=1
    local revision=filterRevision
    task.delay(0.12,function()
        if revision~=filterRevision or not root.Parent then return end
        local scroll=page.CanvasPosition
        renderPage()
        if page.Parent then page.CanvasPosition=scroll end
    end)
end
connect(filterBox:GetPropertyChangedSignal('Text'),rerenderFilteredPage)
connect(filterBox.FocusLost,function()
    -- Focus changes do not rebuild the results or mutate the search TextBox.
end)
filterBox.Active=true
filterBox.TextEditable=true

connect(UserInputService.InputBegan,function(input,gameProcessed)
    if gameProcessed then return end
    if input.UserInputType~=Enum.UserInputType.Keyboard then return end
    local key=tostring(input.KeyCode.Name)
    local bind=mainapi.Keybind or {'RightShift'}
    for _,wanted in ipairs(bind) do
        if tostring(wanted):lower()==key:lower() then
            setOpen(not state.Visible)
            break
        end
    end
end)

updateStatus()
applyLayout(true)
renderPage()
setOpen(false)

mainapi.LiquidGlass=mainapi.LiquidGlass or {}
mainapi.LiquidGlass.Open=function() setOpen(true) end
mainapi.LiquidGlass.Close=function() setOpen(false) end
mainapi.LiquidGlass.Toggle=function() setOpen(not state.Visible) end
mainapi.LiquidGlass.Minimize=minimize
mainapi.LiquidGlass.Maximize=toggleMaximize
mainapi.LiquidGlass.OpenSpotlight=function()
    state.Page='Search'; state.Category=nil
    filterBox.Text=''
    renderPage()
    setOpen(true)
    task.defer(function() if filterBox.Parent and filterBox.Visible then pcall(function() filterBox:CaptureFocus() end) end end)
end

task.spawn(function()
    local deadline=os.clock()+45
    while root.Parent and not mainapi.Loaded and os.clock()<deadline do task.wait(0.2) end
    if root.Parent and mainapi.Loaded and (state.Page=='Category' or state.Page=='Search') then
        renderPage()
    end
end)

return mainapi
]]

source = source..'\n'..finalTail

local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
local chunk, compileError = cache and cache[source] or nil
if not chunk then
	chunk, compileError = loadstring(source, 'guis/liquidglass/full.lua')
	if not chunk then error('AetherV2 Liquid Glass compile failed: '..tostring(compileError), 0) end
	if cache then cache[source] = chunk end
end

return chunk(license, suppliedMainApi)