-- AetherV2 GUI entry. Loads the pinned controller core, strips the unsafe
-- VapeLogo member access, and wraps Load/UpdateGUI so a missing logo cannot
-- abort config loading.
local license = ... or {}

local PINNED = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/ca5df96f6040f2e7338038492df46e06406816c6/guis/new.core.lua'

local function usable(body)
	return type(body) == 'string'
		and #body > 8000
		and body:find('function mainapi:UpdateGUI', 1, true)
end

local ok, body = pcall(game.HttpGet, game, PINNED, true)
if not ok or not usable(body) then
	error('AetherV2 GUI: pinned core could not be loaded', 0)
end

body = body:gsub('\r\n', '\n'):gsub('\r', '\n')
body = body:gsub('%f[%w_]v%.Object%.VapeLogo%.Accent%.BackgroundColor3%s*=%s*Color3%.fromHSV%(%s*hue%s*,%s*sat%s*,%s*val%s*%)', '')
body = body:gsub('%f[%w_]v%.Object%.VapeLogo%.V4Logo%.BackgroundColor3%s*=%s*Color3%.fromHSV%(%s*hue%s*,%s*sat%s*,%s*val%s*%)', '')
body = body:gsub('%f[%w_]v%.Object%.VapeLogo%.V4Logo%.TextColor3%s*=%s*mainapi:TextColor%(%s*hue%s*,%s*sat%s*,%s*val%s*%)', '')

local chunk, compileError = loadstring(body, 'guis/new.core.lua')
if not chunk then
	error('AetherV2 GUI: pinned core did not compile: '..tostring(compileError), 0)
end

local mainapi = chunk(license)

do
	local oldUpdate = mainapi and mainapi.UpdateGUI
	if type(oldUpdate) == 'function' then
		function mainapi:UpdateGUI(...)
			pcall(oldUpdate, self, ...)
		end
	end
	local oldLoad = mainapi and mainapi.Load
	if type(oldLoad) == 'function' then
		function mainapi:Load(...)
			local okLoad, err = pcall(oldLoad, self, ...)
			if not okLoad then
				warn('[AetherV2] GUI Load recovered: '..tostring(err))
			end
		end
	end
end

return mainapi
