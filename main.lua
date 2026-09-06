repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('AetherV2', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local SOURCE_COMMIT = (isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt')) or 'main'
local PLACE_ALIAS = {
	[8444591321] = 6872274481,
	[8560631822] = 6872274481,
}

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE_COMMIT..'/'..select(1, path:gsub('aetherv2/', '')), true)
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

local function remoteExists(rel)
	local suc, res = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE_COMMIT..'/'..rel, true)
	end)
	return suc and type(res) == 'string' and res ~= '404: Not Found' and not res:find('^%s*<!doctype html')
end

local function loadPacked(folder)
	local listPath = 'aetherv2/games/'..folder..'/files.txt'
	local relList = 'games/'..folder..'/files.txt'
	local list
	if isfile(listPath) then
		list = readfile(listPath)
	elseif remoteExists(relList) then
		list = downloadFile(listPath)
	else
		return false
	end
	local chunks = {}
	for line in string.gmatch(list, '[^\r\n]+') do
		line = line:gsub('^%s+', ''):gsub('%s+$', '')
		if line ~= '' and not line:find('^#') then
			table.insert(chunks, downloadFile('aetherv2/games/'..folder..'/'..line))
		end
	end
	if #chunks == 0 then
		return false
	end
	loadstring(table.concat(chunks, '\n'), folder)()
	return true
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('aetherv2/init.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/init.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Settings and vape.Settings.GUI and vape.Settings.GUI.Options and vape.Settings.GUI.Options['GUI bind indicator'] and vape.Settings.GUI.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.GUIBind and vape.GUIBind.Keys or {'RightShift'}, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfile('aetherv2/profiles/gui.txt') then
	writefile('aetherv2/profiles/gui.txt', 'new')
end
local gui = 'new'

if not isfolder('aetherv2/assets/'..gui) then
	makefolder('aetherv2/assets/'..gui)
end
vape = loadstring(downloadFile('aetherv2/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

if not shared.VapeIndependent then
	loadPacked('universal')
	local place = PLACE_ALIAS[game.PlaceId] or game.PlaceId
	if vape.Place == nil then
		vape.Place = place
	end
	if not loadPacked(tostring(place)) then
		warn('[AetherV2] No BedWars module folder for '..tostring(game.PlaceId))
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
