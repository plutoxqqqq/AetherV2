-- AetherV2 Liquid Glass frontend entry.
-- The replacement frontend is intentionally split into readable source sections under
-- guis/liquidglass/. They are concatenated and compiled as ONE Luau chunk, so every local,
-- function and state table behaves exactly as it would in a single 100+ KB liquidglass.lua.

local license, suppliedMainApi = ...
license = type(license) == 'table' and license or {}

local PARTS = {
	'01-runtime.lua',
	'02-shell.lua',
	'03-controls.lua',
	'04-controls-extra.lua',
	'05-inspector.lua',
	'06-pages.lua',
	'07-actions-input.lua',
	'08-finalize.lua'
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
	if not makefolder then return end
	local built = ''
	for segment in path:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if not isfolder or not isfolder(built) then pcall(makefolder, built) end
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
if isfile and isfile(CACHE_REF_PATH) then
	local ok, value = pcall(readfile, CACHE_REF_PATH)
	if ok and type(value) == 'string' then cachedRef = value:gsub('%s+', '') end
end
local CACHE_IS_CURRENT = cachedRef == ACTIVE_REF

local function getPart(name)
	local localPath = LOCAL_DIR..name
	if CACHE_IS_CURRENT and isfile and isfile(localPath) then
		local ok, cached = pcall(readfile, localPath)
		if ok and validSource(cached) then return cached end
	end
	local body = fetch(REMOTE_DIR..name, ACTIVE_REF)
	if not body and ACTIVE_REF ~= 'main' then body = fetch(REMOTE_DIR..name, 'main') end
	if not body then error('AetherV2 Liquid Glass: failed to load '..name, 0) end
	if type(writefile) == 'function' then
		ensureFolder(LOCAL_DIR)
		pcall(writefile, localPath, body)
	end
	return body
end

local source = table.create(#PARTS)
for index, name in ipairs(PARTS) do source[index] = getPart(name) end
source = table.concat(source, '\n')
if type(writefile) == 'function' then
	ensureFolder(LOCAL_DIR)
	pcall(writefile, CACHE_REF_PATH, ACTIVE_REF)
end

-- Premium modules keep their real module names/config keys. Require both loader-owned
-- markers so stale/legacy PRO metadata on ordinary modules cannot produce a premium badge.
local badgeMarker = "    local name=label(card,moduleDisplayName(module),13,true); name.Size=UDim2.new(1,-76,0,24); name.Position=UDim2.fromOffset(14,10); name.ZIndex=114"
local badgeReplacement = [[    local isPremiumModule=module.Premium==true and module.Tag=='PREMIUM'
    local name=label(card,moduleDisplayName(module),13,true); name.Size=UDim2.new(1,isPremiumModule and -154 or -76,0,24); name.Position=UDim2.fromOffset(14,10); name.ZIndex=114
    if isPremiumModule then
        local premium=label(card,'PREMIUM',8,true,Color3.fromRGB(238,222,255),Enum.TextXAlignment.Center)
        premium.Size=UDim2.fromOffset(62,20); premium.Position=UDim2.new(1,-142,0,12); premium.BackgroundColor3=accent(); premium.BackgroundTransparency=.78; premium.ZIndex=116; corner(premium,7)
        create('UIStroke',{Color=accent(),Transparency=.52,Thickness=1},premium)
    end]]
local first, last = source:find(badgeMarker, 1, true)
if first and not source:find(badgeMarker, last + 1, true) then
	source = source:sub(1, first - 1)..badgeReplacement..source:sub(last + 1)
else
	warn('[AetherV2] Liquid Glass premium badge patch skipped: module-card marker was not unique')
end

local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
local chunk, compileError = cache and cache[source] or nil
if not chunk then
	chunk, compileError = loadstring(source, 'guis/liquidglass/full.lua')
	if not chunk then error('AetherV2 Liquid Glass compile failed: '..tostring(compileError), 0) end
	if cache then cache[source] = chunk end
end

return chunk(license, suppliedMainApi)