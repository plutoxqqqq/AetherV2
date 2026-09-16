local license = ... or {}
if type(license) ~= 'table' then license = {} end

local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end
local cloneref = cloneref or function(obj)
	return obj
end

local SOURCE = 'main'

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE..'/'..select(1, path:gsub('aetherv2/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') or file:find('init') then continue end
		if isfile(file) then
			local ok, body = pcall(readfile, file)
			if ok and type(body) == 'string' and (body:find('if canDebug then', 1, true) or select(1, body:find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1) then
				pcall(delfile, file)
			end
		end
	end
end

-- wipeFolder only ever looked at one level, and the module and pack caches live inside
-- aetherv2/games/<PlaceId>/..., so a release wipe reached them only through three hardcoded
-- delfile calls. Every other game kept serving the previous release's pack until the user hit
-- Update Modules. Walk the tree instead: a pack is matched by name (its header makes the
-- watermark prefix test fail) and a module by its watermark, whatever folder it sits in.
local function wipeCachedSources(root, depth)
	if depth > 4 or not isfolder(root) then return end
	for _, entry in listfiles(root) do
		if isfolder(entry) then
			wipeCachedSources(entry, depth + 1)
		elseif isfile(entry) then
			if entry:sub(-8) == 'pack.lua' then
				pcall(delfile, entry)
				continue
			end
			local ok, body = pcall(readfile, entry)
			if ok and type(body) == 'string' and (body:find('if canDebug then', 1, true) or select(1, body:find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1) then
				pcall(delfile, entry)
			end
		end
	end
end

for _, folder in {'aetherv2', 'aetherv2/games', 'aetherv2/profiles', 'aetherv2/assets', 'aetherv2/libraries', 'aetherv2/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Each launch used to delete modules that files.txt still listed, forcing them to be
-- re-downloaded every single time. The pack only ever loads files.txt entries, so stale
-- cache files are harmless and are no longer touched here.

-- The frontend refreshes profiles/features.json before it creates a single module and blocks on
-- that request while it builds. Starting it here instead makes the round trip overlap the version
-- check, the main.lua download and the GUI compile. The frontend falls back to its own fetch when
-- this is missing or older than a minute, so nothing depends on it landing.
local FEATURES_URL = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE..'/profiles/features.json'
task.spawn(function()
	local suc, body = pcall(function()
		return game:HttpGet(FEATURES_URL, true)
	end)
	if suc and type(body) == 'string' and body ~= '404: Not Found' and #body > 3 and not body:find('^%s*<!doctype html') and not body:find('^%s*<html') then
		shared.AetherV2Features = {Ref = SOURCE, Body = body, At = os.clock()}
	end
end)

if not shared.VapeDeveloper then
	local cachedVersion = isfile('aetherv2/profiles/version.txt') and readfile('aetherv2/profiles/version.txt') or ''
	local remoteVersion
	pcall(function()
		remoteVersion = game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE..'/version.txt', true)
	end)
	if type(remoteVersion) == 'string' then
		remoteVersion = remoteVersion:gsub('%s+$', '')
		if remoteVersion:find('^%s*<!doctype html') or remoteVersion == '404: Not Found' then
			remoteVersion = nil
		end
	else
		remoteVersion = nil
	end

	if remoteVersion and cachedVersion:gsub('%s+', '') ~= remoteVersion:gsub('%s+', '') then
		-- Keep the old and new release labels around so main.lua can announce the update
		-- once the GUI exists. main.lua clears the notice after showing it.
		local previousVersion = (cachedVersion:match('version%s*=%s*([^\r\n]+)') or ''):gsub('%s+$', '')
		local nextVersion = (remoteVersion:match('version%s*=%s*([^\r\n]+)') or ''):gsub('%s+$', '')
		if previousVersion ~= '' then
			shared.updated = {From = previousVersion, To = nextVersion}
		end
		wipeFolder('aetherv2')
		wipeFolder('aetherv2/games')
		wipeFolder('aetherv2/guis')
		wipeFolder('aetherv2/libraries')
		wipeCachedSources('aetherv2/games', 1)
		pcall(delfile, 'aetherv2/main.lua')
	end

	if remoteVersion then
		writefile('aetherv2/profiles/version.txt', remoteVersion)
	end
	writefile('aetherv2/profiles/commit.txt', SOURCE)
	shared.AetherV2PublicRef = SOURCE
end

-- A cached main.lua is only trustworthy when the loader that wrote it packs modules the way
-- this one reads them. That used to be a marker string inside main.lua, which is fragile: moving
-- the one comment that carried it deleted the cache on every launch. The stamp is written by
-- init.lua itself, so main.lua can be reorganised without costing anyone their cache.
local LOADER_REVISION = 'pack-1'
local loaderStampPath = 'aetherv2/profiles/loader.txt'
local loaderStamp = isfile(loaderStampPath) and readfile(loaderStampPath) or ''
if isfile('aetherv2/main.lua') and loaderStamp:gsub('%s+', '') ~= LOADER_REVISION then
	delfile('aetherv2/main.lua')
end
pcall(writefile, loaderStampPath, LOADER_REVISION)

return loadstring(downloadFile('aetherv2/main.lua'), 'main')(license)
