local license = ... or {}
if type(license) ~= 'table' then license = {} end

repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local vape
local rawLoadstring = loadstring
local loadstring = function(...)
	local res, err = rawLoadstring(...)
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
local starterGui = cloneref(game:GetService('StarterGui'))

local SOURCE_COMMIT = (isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt'):gsub('%s+', '')) or 'main'
local BEDWARS_UNIVERSE = 2619619496
local PLACE_ALIAS = {
	[8444591321] = 6872274481,
	[8560631822] = 6872274481,
	[8200754399] = 6872274481,
	[132768098780837] = 6872274481,
	[16008862571] = 6872265039,
}

local function setPhase(text, progress)
	if _G.AetherV2SetLoadingStatus then
		pcall(_G.AetherV2SetLoadingStatus, text, progress)
	end
end

local function closeLoading()
	if _G.AetherV2CloseLoadingScreen then
		pcall(_G.AetherV2CloseLoadingScreen)
	elseif _G.AetherV2LoadingScreen then
		pcall(function() _G.AetherV2LoadingScreen:Destroy() end)
		_G.AetherV2LoadingScreen = nil
	end
end

local function toast(title, text, duration)
	pcall(function()
		starterGui:SetCore('SendNotification', {
			Title = title or 'AetherV2',
			Text = text or '',
			Duration = duration or 6
		})
	end)
end

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
		return false, 'no files.txt'
	end
	local names, chunks = {}, {}
	for line in string.gmatch(list, '[^\r\n]+') do
		line = line:gsub('^%s+', ''):gsub('%s+$', '')
		if line ~= '' and not line:find('^#') then
			table.insert(names, line)
		end
	end
	if #names == 0 then
		return false, 'empty files.txt'
	end
	for i, name in ipairs(names) do
		setPhase('Downloading '..folder..' ('..i..'/'..#names..')', 0.4 + (i / #names) * 0.35)
		local ok, body = pcall(downloadFile, 'aetherv2/games/'..folder..'/'..name)
		if ok then
			table.insert(chunks, body)
		else
			warn('[AetherV2] skipped '..folder..'/'..name..': '..tostring(body))
		end
	end
	if #chunks == 0 then
		return false, 'no chunks'
	end
	setPhase('Compiling '..folder, 0.8)
	local chunk, err = loadstring(table.concat(chunks, '\n'), folder)
	if not chunk then
		warn('[AetherV2] compile failed '..folder..': '..tostring(err))
		return false, err
	end
	local ok, result = pcall(chunk, license)
	if not ok then
		warn('[AetherV2] run failed '..folder..': '..tostring(result))
		return false, result
	end
	return true
end

local function loadLegacy(name)
	local path = 'aetherv2/games/'..name..'.lua'
	if isfile(path) or remoteExists('games/'..name..'.lua') then
		local chunk = loadstring(downloadFile(path), name)
		if chunk then
			pcall(chunk, license)
			return true
		end
	end
	return false
end

local function resolvePlace()
	local id = game.PlaceId
	if PLACE_ALIAS[id] then
		return PLACE_ALIAS[id]
	end
	if game.GameId == BEDWARS_UNIVERSE then
		if id == 6872265039 or id == 16008862571 then
			return 6872265039
		end
		return 6872274481
	end
	return id
end

local function finishLoading()
	vape.Init = nil
	pcall(function()
		vape:Load()
	end)
	task.spawn(function()
		repeat
			pcall(function()
				vape:Save()
			end)
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

	local bind = table.concat(vape.GUIBind and vape.GUIBind.Keys or vape.Keybind or {'RightShift'}, ' + '):upper()
	local msg = vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..bind..' to open GUI'
	toast('Finished Loading', msg, 8)
	if vape.CreateNotification then
		pcall(function()
			vape:CreateNotification('Finished Loading', msg, 6)
		end)
	end
	setPhase('Loaded', 1)
	task.delay(0.8, closeLoading)
end

if not isfile('aetherv2/profiles/gui.txt') then
	writefile('aetherv2/profiles/gui.txt', 'new')
end
local gui = 'new'

if not isfolder('aetherv2/assets/'..gui) then
	makefolder('aetherv2/assets/'..gui)
end
setPhase('Loading interface', 0.28)
vape = loadstring(downloadFile('aetherv2/guis/'..gui..'.lua'), 'gui')(license)
shared.vape = vape
_G.vape = vape

if not shared.VapeIndependent then
	setPhase('Loading universal modules', 0.34)
	if not loadPacked('universal') then
		loadLegacy('universal')
	end
	local place = resolvePlace()
	if vape.Place == nil then
		vape.Place = place
	end
	setPhase('Loading game modules ('..tostring(place)..')', 0.5)
	if not loadPacked(tostring(place)) then
		if not loadLegacy(tostring(place)) then
			warn('[AetherV2] No game module for '..tostring(game.PlaceId)..' -> '..tostring(place))
			toast('AetherV2', 'No game pack for '..tostring(game.PlaceId)..'. Universal only.', 8)
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
