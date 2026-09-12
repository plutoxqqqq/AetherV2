local license = ... or {}
if type(license) ~= 'table' then license = {} end

if not game:IsLoaded() then
	game.Loaded:Wait()
end
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

local SOURCE_COMMIT = 'main'
local BEDWARS_UNIVERSE = 2619619496
local PLACE_ALIAS = {
	[8444591321] = 6872274481,
	[8560631822] = 6872274481,
	[8200754399] = 6872274481,
	[132768098780837] = 6872274481,
	[16008862571] = 6872265039,
}
local DOWNLOAD_BATCH = 48

local function toast(title, text, duration)
	pcall(function()
		starterGui:SetCore('SendNotification', {
			Title = title or 'AetherV2',
			Text = text or '',
			Duration = duration or 6
		})
	end)
end

local function ensureParentFolder(path)
	local parent = path:match('^(.*)/[^/]+$')
	if not parent or parent == '' then
		return
	end
	local acc = ''
	for part in string.gmatch(parent, '[^/]+') do
		acc = acc == '' and part or (acc..'/'..part)
		if not isfolder(acc) then
			pcall(makefolder, acc)
		end
	end
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE_COMMIT..'/'..select(1, path:gsub('aetherv2/', '')), true)
		end)
		if not suc or res == '404: Not Found' or (type(res) == 'string' and res:find('^%s*<!doctype html')) then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		ensureParentFolder(path)
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

local function parseFileList(list)
	local names = {}
	for line in string.gmatch(list, '[^\r\n]+') do
		line = line:gsub('^%s+', ''):gsub('%s+$', '')
		if line ~= '' and not line:find('^#') then
			table.insert(names, line)
		end
	end
	return names
end

local function downloadParallel(folder, names, phaseStart, phaseSpan)
	local bodies = table.create(#names)
	local done, cursor = 0, 0
	while cursor < #names do
		cursor += 1
		local idx, name = cursor, names[cursor]
		task.spawn(function()
			local ok, body = pcall(downloadFile, 'aetherv2/games/'..folder..'/'..name)
			if ok then
				bodies[idx] = body
			else
				warn('[AetherV2] skipped '..folder..'/'..name..': '..tostring(body))
			end
			done += 1
		end)
		if cursor % DOWNLOAD_BATCH == 0 then
			repeat task.wait() until done >= cursor or (cursor - done) < DOWNLOAD_BATCH
		end
	end
	repeat task.wait() until done >= #names
	return bodies
end

-- loadPackedFast: use a local pack.lua when present, otherwise download once and cache the pack
local function loadPacked(folder)
	local packPath = 'aetherv2/games/'..folder..'/pack.lua'
	if isfile(packPath) then
		local chunk, err = loadstring(readfile(packPath), folder)
		if chunk then
			local ok, result = pcall(chunk, license)
			if ok then
				return true
			end
			warn('[AetherV2] pack run failed '..folder..': '..tostring(result))
		else
			warn('[AetherV2] pack compile failed '..folder..': '..tostring(err))
		end
		pcall(delfile, packPath)
	end

	local listPath = 'aetherv2/games/'..folder..'/files.txt'
	local list
	if isfile(listPath) then
		list = readfile(listPath)
	elseif remoteExists('games/'..folder..'/files.txt') then
		list = downloadFile(listPath)
	else
		return false, 'no files.txt'
	end
	local names = parseFileList(list)
	if #names == 0 then
		return false, 'empty files.txt'
	end
	local bodies = downloadParallel(folder, names, 0, 0)
	local chunks = {}
	for i = 1, #names do
		if bodies[i] then
			table.insert(chunks, bodies[i])
		end
	end
	if #chunks == 0 then
		return false, 'no chunks'
	end
	local packed = table.concat(chunks, '\n')
	ensureParentFolder(packPath)
	pcall(writefile, packPath, packed)
	local chunk, err = loadstring(packed, folder)
	if not chunk then
		warn('[AetherV2] compile failed '..folder..': '..tostring(err))
		local ran = 0
		for i, name in ipairs(names) do
			local body = bodies[i]
			if body then
				local one, oneErr = loadstring(body, folder..'/'..name)
				if one then
					if pcall(one, license) then
						ran += 1
					end
				else
					warn('[AetherV2] compile failed '..folder..'/'..name..': '..tostring(oneErr))
				end
			end
		end
		return ran > 0
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
					loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/init.lua', true), 'loader')()
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
	if vape.CreateNotification then
		pcall(function()
			vape:CreateNotification('Finished Loading', msg, 4)
		end)
		local update = type(shared.updated) == 'table' and shared.updated or nil
		if update and not update.Notified then
			update.Notified = true
			task.delay(1, function()
				local text
				if update.From and update.From ~= '' and update.To and update.To ~= '' and update.From ~= update.To then
					text = 'Script has updated from v'..update.From..' to v'..update.To
				elseif update.To and update.To ~= '' then
					text = 'Script has updated to v'..update.To
				else
					text = 'Script has updated'
				end
				if update.Files and update.Files > 0 then
					text = text..' ('..update.Files..' file'..(update.Files == 1 and '' or 's')..' changed)'
				end
				pcall(function()
					vape:CreateNotification('AetherV2', text, 10, 'info')
				end)
			end)
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
vape = loadstring(downloadFile('aetherv2/guis/'..gui..'.lua'), 'gui')(license)
shared.vape = vape
_G.vape = vape

if not shared.VapeIndependent then
	if not loadPacked('universal') then
		loadLegacy('universal')
	end
	local place = resolvePlace()
	if vape.Place == nil then
		vape.Place = place
	end
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
