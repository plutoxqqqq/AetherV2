-- AetherV2 GUI compatibility core.
-- Always fetch the authoritative core and normalize line endings before applying
-- compatibility transforms. This prevents stale CRLF caches from bypassing the logo fix.
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
	source = source:gsub('\r\n', '\n'):gsub('\r', '\n')

	local old = table.concat({
		'\t\t\tv.Object.VapeLogo.Accent.BackgroundColor3 = Color3.fromHSV(hue, sat, val)',
		'\t\t\tv.Object.VapeLogo.V4Logo.BackgroundColor3 = Color3.fromHSV(hue, sat, val)',
		'\t\t\tv.Object.VapeLogo.V4Logo.TextColor3 = mainapi:TextColor(hue, sat, val)'
	}, '\n')
	local new = table.concat({
		'\t\t\tlocal mainLogo = v.Object and v.Object:FindFirstChild(\'VapeLogo\', true)',
		'\t\t\tif mainLogo then',
		'\t\t\t\tlocal logoAccent = mainLogo:FindFirstChild(\'Accent\', true)',
		'\t\t\t\tlocal v4Logo = mainLogo:FindFirstChild(\'V4Logo\', true)',
		'\t\t\t\tif logoAccent then logoAccent.BackgroundColor3 = Color3.fromHSV(hue, sat, val) end',
		'\t\t\t\tif v4Logo then',
		'\t\t\t\t\tv4Logo.BackgroundColor3 = Color3.fromHSV(hue, sat, val)',
		'\t\t\t\t\tv4Logo.TextColor3 = mainapi:TextColor(hue, sat, val)',
		'\t\t\t\tend',
		'\t\t\tend'
	}, '\n')
	if source:find(old, 1, true) then
		source = source:gsub(old, new, 1)
	else
		-- Fallback for indentation changes: remove each unsafe direct member chain.
		local changed
		source, changed = source:gsub('%f[%w_]v%.Object%.VapeLogo%.Accent%.BackgroundColor3%s*=%s*Color3%.fromHSV%(%s*hue%s*,%s*sat%s*,%s*val%s*%)', '')
		if changed > 0 then
			source = source:gsub('%f[%w_]v%.Object%.VapeLogo%.V4Logo%.BackgroundColor3%s*=%s*Color3%.fromHSV%(%s*hue%s*,%s*sat%s*,%s*val%s*%)', '')
			source = source:gsub('%f[%w_]v%.Object%.VapeLogo%.V4Logo%.TextColor3%s*=%s*mainapi:TextColor%(%s*hue%s*,%s*sat%s*,%s*val%s*%)', '')
		end
	end

	local loadOld = 'function mainapi:Load(skipgui, profile)\n\tif not skipgui then\n\t\tself.GUIColor:SetValue(nil, nil, nil, accent.Notch)\n\tend'
	local loadNew = 'function mainapi:Load(skipgui, profile)\n\tif not skipgui then\n\t\tpcall(function()\n\t\t\tself.GUIColor:SetValue(nil, nil, nil, accent.Notch)\n\t\tend)\n\tend'
	if source:find(loadOld, 1, true) then
		source = source:gsub(loadOld, loadNew, 1)
	end
	return source
end

local function run(body, name)
	body = patchBody(body)
	if type(body) ~= 'string' or body:find('v%.Object%.VapeLogo', 1, false) then
		error('AetherV2 GUI: unsafe VapeLogo access remained after compatibility patch', 0)
	end
	local chunk, err = loadstring(body, name)
	if not chunk then error('AetherV2 GUI: '..tostring(err), 0) end
	return chunk(license)
end

local ok, body = pcall(game.HttpGet, game, PINNED, true)
if not ok or not usable(body) then
	error('AetherV2 GUI: compatibility core could not be loaded', 0)
end
return run(body, 'guis/new.core.lua')
