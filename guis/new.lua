-- AetherV2 controller entry + Liquid Glass frontend.
-- The GUI implementation is this file plus the pinned historical controller blob.
-- new.core.lua is not loaded from here.

local license = ... or {}
local CORE_PINNED = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/ca5df96f6040f2e7338038492df46e06406816c6/guis/new.core.lua'
local LIQUID_LOCAL = 'aetherv2/guis/liquidglass.lua'

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

local function fetchWithMainFallback(path)
	local ref = currentRef()
	local body, err = fetch(ref, path)
	if body then return body end
	if ref ~= 'main' then body, err = fetch('main', path) end
	return body, err
end

local function usableCore(body)
	return validSource(body)
		and not body:find('CORE_LOCAL', 1, true)
		and not body:find('Compatibility only', 1, true)
end

local function getCore()
	local ok, body = pcall(game.HttpGet, game, CORE_PINNED, true)
	if ok and usableCore(body) then return body end
	error('AetherV2 GUI: failed to load controller core', 0)
end
