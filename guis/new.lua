-- AetherV2 classic GUI entry.
-- Keep the large implementation in new.core.lua and apply compatibility fixes here before compiling it.

local license = ... or {}
local CORE_LOCAL = 'aetherv2/guis/new.core.lua'

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

local function validSource(body)
	if type(body) ~= 'string' or #body <= 32 or body == '404: Not Found' then return false end
	local head = body:sub(1, 300):lower()
	return not head:find('<!doctype html') and not head:find('<html') and not body:find('SourceEndpoint', 1, true)
end

local function fetch(ref, path)
	local url = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/'..path
	local ok, body = pcall(game.HttpGet, game, url, true)
	return ok and validSource(body) and body or nil, body
end

local function getCore()
	if isfile and isfile(CORE_LOCAL) then
		local readOk, cached = pcall(readfile, CORE_LOCAL)
		if readOk and validSource(cached) then return cached end
	end

	local activeRef = currentRef()
	local body, lastError = fetch(activeRef, 'guis/new.core.lua')
	if body then return body end

	if activeRef ~= 'main' then
		body, lastError = fetch('main', 'guis/new.core.lua')
		if body then return body end
	end

	error('AetherV2 GUI: failed to load new.core.lua: '..tostring(lastError), 0)
end

local source = getCore()

local function patchExact(label, old, new, installedMarker)
	if installedMarker and source:find(installedMarker, 1, true) then return true end
	local first, last = source:find(old, 1, true)
	if not first then
		warn('[AetherV2] GUI compatibility patch skipped ('..label..'): marker not found')
		return false
	end
	if source:find(old, last + 1, true) then
		warn('[AetherV2] GUI compatibility patch skipped ('..label..'): marker is not unique')
		return false
	end
	source = source:sub(1, first - 1)..new..source:sub(last + 1)
	return true
end

patchExact('main logo colour refresh', [=[
	for i, v in mainapi.Categories do
		if i == 'Main' then
			v.Object.VapeLogo.Accent.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			v.Object.VapeLogo.V4Logo.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			v.Object.VapeLogo.V4Logo.TextColor3 = mainapi:TextColor(hue, sat, val)
			for _, button in v.Buttons do
]=], [=[
	for i, v in mainapi.Categories do
		if i == 'Main' then
			local mainLogo = v.Object and v.Object:FindFirstChild('VapeLogo', true)
			if mainLogo then
				local logoAccent = mainLogo:FindFirstChild('Accent', true)
				local v4Logo = mainLogo:FindFirstChild('V4Logo', true)
				if logoAccent then logoAccent.BackgroundColor3 = Color3.fromHSV(hue, sat, val) end
				if v4Logo then
					v4Logo.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					v4Logo.TextColor3 = mainapi:TextColor(hue, sat, val)
				end
			end
			for _, button in v.Buttons do
]=], "local mainLogo = v.Object and v.Object:FindFirstChild('VapeLogo', true)")

patchExact('category edit hover state', [=[
function mainapi:CreateCategory(categorysettings)
	local categoryapi = {
		Type = 'Category',
		Expanded = false
	}
]=], [=[
function mainapi:CreateCategory(categorysettings)
	local categoryapi = {
		Type = 'Category',
		Expanded = false
	}
	local categoryHovered = false
]=], 'local categoryHovered = false')

patchExact('module hidden state refresh', [=[
		function moduleapi:SetHidden(hidden)
			self.Hidden = hidden and true or false
			modulebutton.Visible = mainapi.EditGUI or not self.Hidden
			editbox.BackgroundColor3 = self.Hidden and uipallet.Main or Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
			editstroke.Color = self.Hidden and color.Dark(uipallet.Text, 0.43) or Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
			if categoryapi.UpdateHidden then categoryapi:UpdateHidden() end
		end
]=], [=[
		function moduleapi:RefreshHiddenState(editing)
			if editing == nil then editing = mainapi.EditGUI == true end
			modulebutton.Visible = editing or not self.Hidden
			edit.Visible = editing
			modulebutton.Text = string.rep(' ', editing and 50 or 12)..self.Name
			if self.Hidden then modulechildren.Visible = false end
			self:RefreshVisual()
		end

		function moduleapi:SetHidden(hidden)
			hidden = hidden and true or false
			self.Hidden = hidden
			self:RefreshHiddenState()
			if categoryapi.UpdateHidden then categoryapi:UpdateHidden() end
		end
]=], 'function moduleapi:RefreshHiddenState(editing)')

patchExact('late module edit refresh', [=[
		moduleapi.Object = modulebutton
		mainapi.Modules[modulesettings.Name] = moduleapi

		mainapi:SortModules()
]=], [=[
		moduleapi.Object = modulebutton
		mainapi.Modules[modulesettings.Name] = moduleapi
		moduleapi:RefreshHiddenState(mainapi.EditGUI == true)
		if categoryapi.UpdateHidden then categoryapi:UpdateHidden() end

		mainapi:SortModules()
		task.defer(function()
			if not moduleapi.Object or not moduleapi.Object.Parent then return end
			moduleapi:RefreshHiddenState(mainapi.EditGUI == true)
			if categoryapi.UpdateHidden then categoryapi:UpdateHidden() end
			mainapi:SortModules()
			local parent = moduleapi.Object.Parent
			local layout = parent:FindFirstChildOfClass('UIListLayout')
			if parent:IsA('ScrollingFrame') and layout then
				parent.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / scale.Scale)
			end
		end)
]=], 'task.defer(function()\n\t\t\tif not moduleapi.Object or not moduleapi.Object.Parent then return end')

patchExact('category edit mode refresh', [=[
	function categoryapi:SetEditMode(enabled)
		for _, module in mainapi.Modules do
			if module.Category == categorysettings.Name then
				module.Object.Visible = enabled or not module.Hidden
				module.Object.Text = string.rep(' ', enabled and 50 or 12)..module.Name
				local edit = module.Object:FindFirstChild('Edit')
				if edit then edit.Visible = enabled end
			end
		end
		done.Visible = enabled
		pencilbutton.Visible = not enabled
		self:UpdateHidden()
	end
]=], [=[
	function categoryapi:SetEditMode(enabled)
		enabled = enabled == true
		self.EditMode = enabled
		for _, module in mainapi.Modules do
			if module.Category == categorysettings.Name then
				if module.RefreshHiddenState then
					module:RefreshHiddenState(enabled)
				else
					module.Object.Visible = enabled or not module.Hidden
					local edit = module.Object:FindFirstChild('Edit')
					if edit then edit.Visible = enabled end
				end
			end
		end
		done.Visible = enabled
		pencilbutton.Visible = not enabled and categoryHovered
		self:UpdateHidden()
	end
]=], 'self.EditMode = enabled')

patchExact('category hover refresh', [=[
	window.MouseEnter:Connect(function()
		pencilbutton.Visible = not mainapi.EditGUI
		categoryapi:UpdateHidden()
	end)
	window.MouseLeave:Connect(function()
		if not mainapi.EditGUI then
			pencilbutton.Visible = false
			hiddenCount.Visible = false
		end
	end)
]=], [=[
	window.MouseEnter:Connect(function()
		categoryHovered = true
		pencilbutton.Visible = not mainapi.EditGUI
		categoryapi:UpdateHidden()
	end)
	window.MouseLeave:Connect(function()
		categoryHovered = false
		if not mainapi.EditGUI then
			pencilbutton.Visible = false
			hiddenCount.Visible = false
		end
	end)
	clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		if not clickgui.Visible then
			-- Closing the whole menu is also the end of a global category-edit session.
			-- Otherwise Done/pencil visibility and hidden rows retain half of the old state
			-- when Roblox suppresses MouseLeave on an invisible ScreenGui.
			if mainapi.EditGUI then
				mainapi.EditGUI = false
				for _, category in mainapi.Categories do
					if category.Type == 'Category' and category.SetEditMode then category:SetEditMode(false) end
				end
				pcall(mainapi.Save, mainapi)
			end
			categoryHovered = false
			pencilbutton.Visible = false
			hiddenCount.Visible = false
			return
		end
		task.defer(function()
			if not clickgui.Visible or not window.Visible then return end
			local mouse = inputService:GetMouseLocation()
			local position, size = window.AbsolutePosition, window.AbsoluteSize
			categoryHovered = mouse.X >= position.X and mouse.X <= position.X + size.X
				and mouse.Y >= position.Y and mouse.Y <= position.Y + size.Y
			pencilbutton.Visible = categoryHovered and not mainapi.EditGUI
			categoryapi:UpdateHidden()
		end)
	end)
]=], 'categoryHovered = true')

patchExact('home free premium tier row', [=[
	local gameRow = row(146, 'Current game', 'Detecting…')
	local kitRow = row(194, 'Detected kit', 'Checking…')
	local profileRow = row(242, 'Current profile', tostring(mainapi.Profile))
	local sessionRow = row(290, 'AetherV2', 'v'..tostring(mainapi.Version)..' • 0m')
]=], [=[
	local gameRow = row(146, 'Current game', 'Detecting…')
	local kitRow = row(194, 'Detected kit', 'Checking…')
	local profileRow = row(242, 'Current profile', tostring(mainapi.Profile))
	local function aetherHomeTier()
		return shared.AetherV2PremiumAuthorized == true and 'Premium' or 'Free'
	end
	local sessionRow = row(290, 'AetherV2', 'v'..tostring(mainapi.Version)..' • '..aetherHomeTier()..' • 0m')
]=], 'local function aetherHomeTier()')

patchExact('home free premium tier uptime', [=[
				sessionRow.Detail.Text = 'v'..tostring(mainapi.Version)..' • '..math.floor((os.clock() - (mainapi.StartedAt or os.clock())) / 60)..'m'
]=], [=[
				sessionRow.Detail.Text = 'v'..tostring(mainapi.Version)..' • '..aetherHomeTier()..' • '..math.floor((os.clock() - (mainapi.StartedAt or os.clock())) / 60)..'m'
]=], "sessionRow.Detail.Text = 'v'..tostring(mainapi.Version)..' • '..aetherHomeTier()")

-- Cloud Configs reuses the existing JSON import path. The optional skipLoad flag is
-- only used for background Sync to Copy updates so an inactive local copy can be
-- refreshed without switching the player's current config.
patchExact('cloud import skip-load signature', [=[
local function importJsonConfig(text, requestedName)
]=], [=[
local function importJsonConfig(text, requestedName, skipLoad)
]=], 'local function importJsonConfig(text, requestedName, skipLoad)')

patchExact('cloud import preserve active profile', [=[
	guidata.Profile = configName
	writefile(guiPath, httpService:JSONEncode(guidata))
]=], [=[
	if not skipLoad then guidata.Profile = configName end
	writefile(guiPath, httpService:JSONEncode(guidata))
]=], 'if not skipLoad then guidata.Profile = configName end')

patchExact('cloud import background load guard', [=[
	refreshConfigProfiles()
	mainapi:Load(true, configName)
	mainapi:Save(configName)
	return true, configName
end
]=], [=[
	refreshConfigProfiles()
	if not skipLoad then
		mainapi:Load(true, configName)
		mainapi:Save(configName)
	end
	return true, configName
end
]=], 'if not skipLoad then\n\t\tmainapi:Load(true, configName)')

patchExact('cloud config serializer bridge', [=[
local importNameBox
local importJsonBox = profiles:CreateTextBox({
]=], [=[
mainapi.CloudConfigInternals = {
	ImportJson = importJsonConfig,
	RefreshProfiles = refreshConfigProfiles,
	ConfigPath = getConfigPath
}

local importNameBox
local importJsonBox = profiles:CreateTextBox({
]=], 'mainapi.CloudConfigInternals = {')

local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
local compiled, compileError = cache and cache[source] or nil
if not compiled then
	compiled, compileError = loadstring(source, 'guis/new.core.lua')
	if not compiled then error('AetherV2 GUI: transformed new.core.lua did not compile: '..tostring(compileError), 0) end
	if cache then cache[source] = compiled end
end

local mainapi = compiled(license)

-- Cloud Configs is intentionally a small public client layer. Failure to fetch or
-- initialise it must never prevent normal/local Aether configs from working.
local cloudSource, cloudError
if isfile and isfile('aetherv2/libraries/cloud-configs.lua') then
	local ok, cached = pcall(readfile, 'aetherv2/libraries/cloud-configs.lua')
	if ok and validSource(cached) then cloudSource = cached end
end
if not cloudSource then
	cloudSource, cloudError = fetch(currentRef(), 'libraries/cloud-configs.lua')
	if not cloudSource and currentRef() ~= 'main' then cloudSource, cloudError = fetch('main', 'libraries/cloud-configs.lua') end
end
if cloudSource then
	local cloudChunk, cloudCompileError = loadstring(cloudSource, 'libraries/cloud-configs.lua')
	if cloudChunk then
		local ok, err = pcall(cloudChunk, mainapi, license)
		if not ok then warn('[AetherV2] Cloud Configs failed to initialise: '..tostring(err)) end
	else
		warn('[AetherV2] Cloud Configs did not compile: '..tostring(cloudCompileError))
	end
elseif cloudError then
	warn('[AetherV2] Cloud Configs could not be fetched: '..tostring(cloudError))
end

return mainapi
