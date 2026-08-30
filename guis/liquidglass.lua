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

local function getPart(name)
	local localPath = LOCAL_DIR..name
	if isfile and isfile(localPath) then
		local ok, cached = pcall(readfile, localPath)
		if ok and validSource(cached) then return cached end
	end

	local ref = currentRef()
	local body = fetch(REMOTE_DIR..name, ref)
	if not body and ref ~= 'main' then body = fetch(REMOTE_DIR..name, 'main') end
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

local cache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or nil
local chunk, compileError = cache and cache[source] or nil
if not chunk then
	chunk, compileError = loadstring(source, 'guis/liquidglass/full.lua')
	if not chunk then error('AetherV2 Liquid Glass compile failed: '..tostring(compileError), 0) end
	if cache then cache[source] = chunk end
end

return chunk(license, suppliedMainApi)
