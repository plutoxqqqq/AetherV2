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
local DOWNLOAD_BATCH = 24

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

-- One round trip per URL. The loader used to call remoteExists and then downloadFile on the
-- same path, paying for the file twice, and it raised instead of answering "not there yet"
-- when GitHub handed back a 404 body.
local function fetchRemote(rel)
	local suc, res = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE_COMMIT..'/'..rel, true)
	end)
	if not suc or type(res) ~= 'string' then
		return nil
	end
	local head = res:sub(1, 300):lower()
	if res == '404: Not Found' or head:find('^%s*404') or head:find('^%s*<!doctype html') or head:find('^%s*<html') then
		return nil
	end
	return res
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

-- A cached pack is only reusable for the exact module list and release it was built from,
-- and that key travels in the pack's own header. A pack written by an older loader carries no
-- header, so it is discarded instead of being trusted for modules it may not contain.
local PACK_HEADER = '--AetherV2 pack'

local function hashString(text)
	local hash = 2166136261
	for index = 1, #text do
		hash = bit32.bxor(hash, text:byte(index))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format('%08x', hash)
end

local function installedVersion()
	if not isfile('aetherv2/profiles/version.txt') then return '' end
	local ok, body = pcall(readfile, 'aetherv2/profiles/version.txt')
	return ok and type(body) == 'string' and body:gsub('%s+', '') or ''
end

local function packKey(folder, list)
	return hashString(folder..'\n'..installedVersion()..'\n'..list)
end

local function packHeader(key, count)
	return PACK_HEADER..' key='..key..' count='..count..'\n'
end

local function packKeyOf(body)
	if type(body) ~= 'string' then return nil end
	local line = body:match('^[^\r\n]*')
	if not line or line:sub(1, #PACK_HEADER) ~= PACK_HEADER then return nil end
	return line:match('key=(%x+)')
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

-- loadPacked used to run blind: files.txt was fetched twice (remoteExists, then downloadFile),
-- a 404 for a pack.lua that this repository does not publish was burned on every cold start,
-- and a cached pack was trusted forever. buildPack answers "is there a module list, and does the
-- cached pack actually describe it?"; preparePack runs that in a coroutine so both folders can
-- work at the same time; runPack only executes, in the order the game needs.
local function buildPack(job)
	local folder = job.Folder
	local listPath = 'aetherv2/games/'..folder..'/files.txt'

	-- The module list is fetched live so a module added to the repository shows up without
	-- waiting on a version bump. The cached copy is only an offline fallback.
	local list = fetchRemote('games/'..folder..'/files.txt')
	if list then
		local cachedList = isfile(listPath) and select(2, pcall(readfile, listPath)) or nil
		if cachedList ~= list then
			ensureParentFolder(listPath)
			pcall(writefile, listPath, list)
		end
	elseif isfile(listPath) then
		list = select(2, pcall(readfile, listPath))
	end
	if type(list) ~= 'string' or list == '' then
		job.Error = 'no files.txt'
		return
	end
	local names = parseFileList(list)
	if #names == 0 then
		job.Error = 'empty files.txt'
		return
	end
	job.Names = names
	job.Key = packKey(folder, list)

	local packPath = 'aetherv2/games/'..folder..'/pack.lua'
	if isfile(packPath) then
		local cached = select(2, pcall(readfile, packPath))
		if packKeyOf(cached) == job.Key and packLooksValid(cached) then
			local chunk, err = loadstring(cached, folder)
			if chunk then
				job.Chunk = chunk
				return
			end
			warn('[AetherV2] cached pack for '..folder..' does not compile: '..tostring(err))
		elseif packKeyOf(cached) == nil then
			warn('[AetherV2] discarding pack cache '..folder..' written by an older loader')
		else
			warn('[AetherV2] discarding stale pack cache '..folder..' (module list or release changed)')
		end
		pcall(delfile, packPath)
	end

	-- A committed pack would turn a cold start into a couple of requests instead of hundreds, so
	-- it is asked for alongside the sources rather than before them: in this repository that URL
	-- is a 404, and this way the 404 costs no wall clock time.
	local remotePack
	task.spawn(function()
		local body = fetchRemote('games/'..folder..'/pack.lua')
		if packKeyOf(body) == job.Key and packLooksValid(body) then
			remotePack = body
		end
	end)

	local bodies = downloadParallel(folder, names)
	local chunks = {}
	for index = 1, #names do
		if bodies[index] then
			table.insert(chunks, bodies[index])
		end
	end
	job.Bodies = bodies
	-- An incomplete download used to be concatenated anyway, silently baking the missing modules
	-- into the cache. Refuse to write a pack that is not the whole module list, and let runPack
	-- compile and run the modules that did arrive.
	if #chunks < #names then
		job.Error = 'incomplete module download ('..#chunks..'/'..#names..')'
		warn('[AetherV2] '..folder..': '..job.Error)
		return
	end

	if remotePack then
		local chunk = loadstring(remotePack, folder)
		if chunk then
			ensureParentFolder(packPath)
			pcall(writefile, packPath, remotePack)
			job.Chunk = chunk
			return
		end
	end

	local packed = packHeader(job.Key, #names)..table.concat(chunks, '\n')
	if not packLooksValid(packed) then
		job.Error = 'assembled pack failed validation'
		return
	end
	local chunk, err = loadstring(packed, folder)
	if not chunk then
		warn('[AetherV2] compile failed '..folder..': '..tostring(err))
		return
	end
	ensureParentFolder(packPath)
	pcall(writefile, packPath, packed)
	job.Chunk = chunk
end

local function preparePack(folder)
	local job = {Folder = folder, Ready = false}
	task.spawn(function()
		local ok, err = pcall(buildPack, job)
		if not ok then
			job.Error = tostring(err)
			warn('[AetherV2] pack preparation failed '..folder..': '..tostring(err))
		end
		job.Ready = true
	end)
	return job
end

local function runPack(job)
	if not job.Ready then
		repeat task.wait() until job.Ready
	end
	if job.Chunk then
		local ok, result = pcall(job.Chunk, license)
		if ok then
			return true
		end
		warn('[AetherV2] pack run failed '..job.Folder..': '..tostring(result))
		job.Error = job.Error or tostring(result)
		return false, result
	end
	-- The fallback compiles each source on its own, so one bad or missing module costs only
	-- itself instead of the whole folder.
	local ran = 0
	if job.Bodies and job.Names then
		for index, name in ipairs(job.Names) do
			local body = job.Bodies[index]
			if body then
				local one, oneErr = loadstring(body, job.Folder..'/'..name)
				if one then
					if pcall(one, license) then
						ran += 1
					end
				else
					warn('[AetherV2] compile failed '..job.Folder..'/'..name..': '..tostring(oneErr))
				end
			end
		end
	else
		local reason = job.Error or 'no module sources'
		warn('[AetherV2] '..job.Folder..' modules unavailable: '..reason)
		return false, reason
	end
	return ran > 0, job.Error
end

local function loadLegacy(name)
	local rel = 'games/'..name..'.lua'
	local path = 'aetherv2/'..rel
	local body
	if isfile(path) then
		body = select(2, pcall(readfile, path))
	else
		body = fetchRemote(rel)
		if body then
			body = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..body
			ensureParentFolder(path)
			pcall(writefile, path, body)
		end
	end
	if type(body) ~= 'string' or body == '' then
		return false
	end
	local chunk = loadstring(body, name)
	if chunk then
		pcall(chunk, license)
		return true
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
	-- Both packs are prepared at the same time. The universal pack is the smaller of the two,
	-- so its modules start running while the game pack is still on the wire, and neither folder
	-- waits on the other folder's module list.
	local universalJob = preparePack('universal')
	local place = resolvePlace()
	local placeJob = preparePack(tostring(place))
	if not runPack(universalJob) then
		loadLegacy('universal')
	end
	if vape.Place == nil then
		vape.Place = place
	end
	if not runPack(placeJob) then
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
