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

for _, folder in {'aetherv2', 'aetherv2/games', 'aetherv2/profiles', 'aetherv2/assets', 'aetherv2/libraries', 'aetherv2/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

for _, stale in {
	'aetherv2/games/6872274481/pack.lua',
	'aetherv2/games/6872274481/Blatant/DamageBoost.lua',
	'aetherv2/games/6872274481/Blatant/DeathAdderAimbot.lua',
	'aetherv2/games/6872274481/Combat/BowAssist.lua',
	'aetherv2/games/6872274481/Combat/HitregAdjuster.lua',
	'aetherv2/games/6872274481/Combat/NoClickDelay.lua',
} do
	if isfile(stale) then
		pcall(delfile, stale)
	end
end

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
		wipeFolder('aetherv2')
		wipeFolder('aetherv2/games')
		wipeFolder('aetherv2/guis')
		wipeFolder('aetherv2/libraries')
		pcall(delfile, 'aetherv2/main.lua')
		pcall(delfile, 'aetherv2/games/universal/pack.lua')
		pcall(delfile, 'aetherv2/games/6872274481/pack.lua')
		pcall(delfile, 'aetherv2/games/6872265039/pack.lua')
	end

	if remoteVersion then
		writefile('aetherv2/profiles/version.txt', remoteVersion)
	end
	writefile('aetherv2/profiles/commit.txt', SOURCE)
	shared.AetherV2PublicRef = SOURCE
end

if isfile('aetherv2/main.lua') then
	local cachedMain = readfile('aetherv2/main.lua')
	if not cachedMain:find('loadPackedFast', 1, true) then
		delfile('aetherv2/main.lua')
	end
end

return loadstring(downloadFile('aetherv2/main.lua'), 'main')(license)
