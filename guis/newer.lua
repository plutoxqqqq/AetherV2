-- AetherV2 Nexus GUI entry.
-- The implementation lives in newer.core.lua; this wrapper installs compatibility fixes before it runs.

local license = ... or {}
local CORE_LOCAL = 'aetherv2/guis/newer.core.lua'
local FALLBACK_COMMIT = '1a6a7d57004f4cbc974ce7aecb12f04017c93763'

local function currentRef()
	local ok, ref = pcall(readfile, 'aetherv2/profiles/commit.txt')
	if ok and type(ref) == 'string' then
		ref = ref:gsub('%s+', '')
		if ref ~= '' then return ref end
	end
	return 'main'
end

local function validSource(body)
	return type(body) == 'string' and #body > 32 and body ~= '404: Not Found'
end

local function fetch(ref, path)
	local url = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/'..path
	local ok, body = pcall(game.HttpGet, game, url, true)
	return ok and validSource(body) and body or nil, body
end

local function getCore()
	local body, lastError = fetch(currentRef(), 'guis/newer.core.lua')
	if body then return body end

	body, lastError = fetch('main', 'guis/newer.core.lua')
	if body then return body end

	if isfile and isfile(CORE_LOCAL) then
		local readOk, cached = pcall(readfile, CORE_LOCAL)
		if readOk and validSource(cached) then return cached end
	end

	body, lastError = fetch(FALLBACK_COMMIT, 'guis/newer.lua')
	if body then return body end
	error('AetherV2 GUI: failed to load newer.core.lua: '..tostring(lastError), 0)
end

local source = getCore()

local function patchExact(label, old, new, installedMarker)
	if installedMarker and source:find(installedMarker, 1, true) then return true end
	local first, last = source:find(old, 1, true)
	if not first then
		warn('[AetherV2] Nexus compatibility patch skipped ('..label..'): marker not found')
		return false
	end
	if source:find(old, last + 1, true) then
		warn('[AetherV2] Nexus compatibility patch skipped ('..label..'): marker is not unique')
		return false
	end
	source = source:sub(1, first - 1)..new..source:sub(last + 1)
	return true
end

patchExact('main logo colour refresh', [=[
	for i, v in mainapi.Categories do
		if i == 'Main' then
			v.Object.VapeLogo.V4Logo.TextColor3 = Color3.fromHSV(hue, sat, val)
			for _, button in v.Buttons do
]=], [=[
	for i, v in mainapi.Categories do
		if i == 'Main' then
			local mainLogo = v.Object and v.Object:FindFirstChild('VapeLogo', true)
			local v4Logo = mainLogo and mainLogo:FindFirstChild('V4Logo', true)
			if v4Logo then v4Logo.TextColor3 = Color3.fromHSV(hue, sat, val) end
			for _, button in v.Buttons do
]=], "local mainLogo = v.Object and v.Object:FindFirstChild('VapeLogo', true)")

-- Game modules register after the GUI has already laid out its built-in rows. Nexus used to add the
-- module to mainapi.Modules and sort it, but never explicitly refreshed the row/canvas on a late add.
-- That is why category managers could count the module while the actual category did not show it.
patchExact('late module row refresh', [=[
		moduleapi.Object = modulebutton
		mainapi.Modules[modulesettings.Name] = moduleapi

		mainapi:SortModules()

		return moduleapi
]=], [=[
		moduleapi.Object = modulebutton
		mainapi.Modules[modulesettings.Name] = moduleapi
		modulebutton.Visible = true

		mainapi:SortModules()
		task.defer(function()
			if not modulebutton.Parent then return end
			modulebutton.Visible = true
			mainapi:SortModules()
			local parent = modulebutton.Parent
			local layout = parent:FindFirstChildOfClass('UIListLayout')
			if parent:IsA('ScrollingFrame') and layout then
				parent.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / scale.Scale)
			end
		end)

		return moduleapi
]=], 'late module row refresh')

-- The marker above lives only in this wrapper, so inject a harmless source marker to keep the patch
-- idempotent when a cached transformed source is encountered.
if source:find('modulebutton.Visible = true', 1, true) and not source:find('-- Aether late module row refresh', 1, true) then
	source = '-- Aether late module row refresh\n'..source
end

local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
local compiled, compileError = cache and cache[source] or nil
if not compiled then
	compiled, compileError = loadstring(source, 'guis/newer.core.lua')
	if not compiled then error('AetherV2 GUI: transformed newer.core.lua did not compile: '..tostring(compileError), 0) end
	if cache then cache[source] = compiled end
end

return compiled(license)
