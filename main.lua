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

-- A missing remote pack.lua can come back as an empty body rather than a 404, and an
-- empty concatenation still compiles (it is only comments), so size and a code marker are
-- required before a pack is trusted. Without this the loader silently "succeeded" and the
-- modules were never registered.
local function packLooksValid(body)
	if type(body) ~= 'string' or #body < 4096 then return false end
	local head = body:sub(1, 8192)
	return head:find('run(function', 1, true) ~= nil
		or head:find('CreateModule', 1, true) ~= nil
		or head:find('vape', 1, true) ~= nil
end

-- loadPackedFast: use a local pack.lua when present, otherwise download once and cache the pack
local function loadPacked(folder)
	local packPath = 'aetherv2/games/'..folder..'/pack.lua'
	if isfile(packPath) then
		local cached = select(2, pcall(readfile, packPath))
		if packLooksValid(cached) then
			local chunk, err = loadstring(cached, folder)
			if chunk then
				local ok, result = pcall(chunk, license)
				if ok then
					return true
				end
				warn('[AetherV2] pack run failed '..folder..': '..tostring(result))
			else
				warn('[AetherV2] pack compile failed '..folder..': '..tostring(err))
			end
		else
			warn('[AetherV2] discarding invalid pack cache '..folder)
		end
		pcall(delfile, packPath)
	end

	-- A committed pack.lua turns a cold start from hundreds of HTTP requests into one.
	if not isfile(packPath) then
		local fetched, body = pcall(downloadFile, packPath)
		if fetched and packLooksValid(body) then
			local remoteChunk, remoteErr = loadstring(body, folder)
			if remoteChunk then
				local ran, result = pcall(remoteChunk, license)
				if ran then
					return true
				end
				warn('[AetherV2] remote pack run failed '..folder..': '..tostring(result))
			else
				warn('[AetherV2] remote pack compile failed '..folder..': '..tostring(remoteErr))
			end
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
	if not packLooksValid(packed) then
		return false, 'assembled pack failed validation'
	end
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
			-- Saving must never prevent the reinject from being queued. If the config write
			-- fails, the load-time repair path will preserve the previous file instead.
			pcall(function()
				vape:Save()
			end)
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
if type(vape) ~= 'table' then
	error('[AetherV2] The '..tostring(gui)..' frontend did not return a controller')
end
-- A stale cached frontend (or a frontend that failed partway through) can be missing the
-- maid helpers the game packs depend on. Supply functional fallbacks so a single missing
-- method can never abort pack loading or finishLoading again.
if type(vape.Clean) ~= 'function' or type(vape.Remove) ~= 'function' then
	local fallbackConnections = {}
	if type(vape.Clean) ~= 'function' then
		vape.Clean = function(_, ...)
			for index = 1, select('#', ...) do
				local item = select(index, ...)
				if item ~= nil then
					table.insert(fallbackConnections, item)
				end
			end
		end
		vape.CleanFallback = function()
			for _, item in fallbackConnections do
				pcall(function()
					if typeof(item) == 'Instance' then
						item:Destroy()
					elseif type(item) == 'table' and type(item.Disconnect) == 'function' then
						item:Disconnect()
					elseif type(item) == 'thread' then
						task.cancel(item)
					elseif type(item) == 'function' then
						item()
					end
				end)
			end
			table.clear(fallbackConnections)
		end
	end
	if type(vape.Remove) ~= 'function' then
		vape.Remove = function(self, name)
			local module = type(self) == 'table' and self.Modules and self.Modules[name]
			if not module then return end
			if type(module.Toggle) == 'function' and module.Enabled then
				pcall(module.Toggle, module, false)
			end
			if typeof(module.Object) == 'Instance' then
				pcall(function() module.Object:Destroy() end)
			end
		end
	end
end
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
