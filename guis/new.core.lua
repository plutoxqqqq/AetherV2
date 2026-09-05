-- Compatibility stub only. Do not load this from guis/new.lua.
-- Old cached injectors that still request new.core.lua get the pinned controller.
local license = ... or {}
local pinned = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/ca5df96f6040f2e7338038492df46e06406816c6/guis/new.core.lua'
local ok, body = pcall(game.HttpGet, game, pinned, true)
if not ok or type(body) ~= 'string' or #body < 1000 or body:find('CORE_LOCAL', 1, true) then
	error('AetherV2 GUI: compatibility core could not be loaded', 0)
end
local chunk, err = loadstring(body, 'guis/new.core.lua')
if not chunk then error('AetherV2 GUI: '..tostring(err), 0) end
return chunk(license)
