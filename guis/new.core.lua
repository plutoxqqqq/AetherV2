-- Compatibility only. The GUI implementation is guis/new.lua.
-- Old cached wrappers still fetch this file; keep them working until that cache is replaced.
local license = ... or {}

local PINNED = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/ca5df96f6040f2e7338038492df46e06406816c6/guis/new.core.lua'

local function usable(body)
	return type(body) == 'string'
		and #body > 8000
		and body:find('function mainapi:UpdateGUI', 1, true)
		and not body:find('CORE_LOCAL', 1, true)
		and not body:find('Compatibility only', 1, true)
		and not body:find('was removed; the GUI lives', 1, true)
end

local function patchBody(source)
	if type(source) ~= 'string' then return source end
	local old = [=[            v.Object.VapeLogo.Accent.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
            v.Object.VapeLogo.V4Logo.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
            v.Object.VapeLogo.V4Logo.TextColor3 = mainapi:TextColor(hue, sat, val)]=]
	local new = [=[            local mainLogo = v.Object and v.Object:FindFirstChild('VapeLogo', true)
            if mainLogo then
                local logoAccent = mainLogo:FindFirstChild('Accent', true)
                local v4Logo = mainLogo:FindFirstChild('V4Logo', true)
                if logoAccent then logoAccent.BackgroundColor3 = Color3.fromHSV(hue, sat, val) end
                if v4Logo then
                    v4Logo.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v4Logo.TextColor3 = mainapi:TextColor(hue, sat, val)
                end
            end]=]
	if source:find(old, 1, true) then
		source = source:gsub(old, new, 1)
	end
	source = source:gsub(
		'function mainapi:Load%(skipgui, profile%)\n\tif not skipgui then\n\t\tself%.GUIColor:SetValue%(nil, nil, nil, accent%.Notch%)\n\tend',
		'function mainapi:Load(skipgui, profile)\n\tif not skipgui then\n\t\tpcall(function()\n\t\t\tself.GUIColor:SetValue(nil, nil, nil, accent.Notch)\n\t\tend)\n\tend',
		1
	)
	return source
end

local function run(body, name)
	body = patchBody(body)
	local chunk, err = loadstring(body, name)
	if not chunk then error('AetherV2 GUI: '..tostring(err), 0) end
	return chunk(license)
end

if isfile and isfile('aetherv2/guis/new.lua') then
	local ok, source = pcall(readfile, 'aetherv2/guis/new.lua')
	-- Only execute a cached new.lua if it is a real controller, not this wrapper.
	if ok and usable(source) and not source:find('CORE_LOCAL', 1, true) then
		return run(source, 'guis/new.lua')
	end
end

local ok, body = pcall(game.HttpGet, game, PINNED, true)
if not ok or not usable(body) then
	error('AetherV2 GUI: compatibility core could not be loaded', 0)
end
return run(body, 'guis/new.core.lua')
