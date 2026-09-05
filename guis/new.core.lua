-- Compatibility only. The GUI implementation is guis/new.lua.
-- Old cached wrappers still fetch this file; keep them working until that cache is replaced.
local license = ... or {}

local function usable(body)
	return type(body) == 'string'
		and #body > 1000
		and not body:find('CORE_LOCAL', 1, true)
		and not body:find('was removed; the GUI lives', 1, true)
end

local function run(body, name)
	local chunk, err = loadstring(body, name)
	if not chunk then error('AetherV2 GUI: '..tostring(err), 0) end
	return chunk(license)
end

if isfile and isfile('aetherv2/guis/new.lua') then
	local ok, source = pcall(readfile, 'aetherv2/guis/new.lua')
	if ok and usable(source) then
		return run(source, 'guis/new.lua')
	end
end

local pinned = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/ca5df96f6040f2e7338038492df46e06406816c6/guis/new.core.lua'
local ok, body = pcall(game.HttpGet, game, pinned, true)
 if not ok or not usable(body) then
	error('AetherV2 GUI: compatibility core could not be loaded', 0)
end
return run(body, 'guis/new.core.lua')
