-- AetherV2 Nexus GUI entry.
-- The implementation lives in newer.core.lua. This thin entry applies compatibility guards before
-- execution so a renamed/removed legacy logo object cannot abort the entire client during recolour.

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

	if isfile and isfile(CORE_LOCAL) then
		local readOk, cached = pcall(readfile, CORE_LOCAL)
		if readOk and validSource(cached) then return cached end
	end

	body, lastError = fetch(FALLBACK_COMMIT, 'guis/newer.lua')
	if body then return body end
	error('AetherV2 GUI: failed to load newer.core.lua: '..tostring(lastError), 0)
end

local source = getCore()
local installedMarker = "local mainLogo = v.Object and v.Object:FindFirstChild('VapeLogo', true)"
if not source:find(installedMarker, 1, true) then
	local old = [=[
	for i, v in mainapi.Categories do
		if i == 'Main' then
			v.Object.VapeLogo.V4Logo.TextColor3 = Color3.fromHSV(hue, sat, val)
			for _, button in v.Buttons do
]=]
	local new = [=[
	for i, v in mainapi.Categories do
		if i == 'Main' then
			local mainLogo = v.Object and v.Object:FindFirstChild('VapeLogo', true)
			local v4Logo = mainLogo and mainLogo:FindFirstChild('V4Logo', true)
			if v4Logo then v4Logo.TextColor3 = Color3.fromHSV(hue, sat, val) end
			for _, button in v.Buttons do
]=]
	local first, last = source:find(old, 1, true)
	if first and not source:find(old, last + 1, true) then
		source = source:sub(1, first - 1)..new..source:sub(last + 1)
	else
		warn('[AetherV2] Nexus logo compatibility patch skipped: marker missing or ambiguous')
	end
end

local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
local compiled, compileError = cache and cache[source] or nil
if not compiled then
	compiled, compileError = loadstring(source, 'guis/newer.core.lua')
	if not compiled then error('AetherV2 GUI: transformed newer.core.lua did not compile: '..tostring(compileError), 0) end
	if cache then cache[source] = compiled end
end

return compiled(license)
