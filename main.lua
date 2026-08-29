local license = ... or {}
local globalenv = (getgenv and getgenv()) or _G
repeat task.wait() until game:IsLoaded()

-- If an AetherV2 instance is already injected, fully destroy it before loading
-- this one. Running the loadstring again is a valid "reinject" - it must tear
-- the old GUI down first, or two instances fight over input/GUI and the new one
-- appears not to load. Uninject is wrapped so even a half-broken old instance
-- (whose own teardown errors) still gets its GUI destroyed and the shared
-- handles cleared, so the fresh load always has a clean slate.
if shared.vape then
	local old = shared.vape
	pcall(function() old:Uninject() end)
	if type(old) == 'table' and typeof(old.gui) == 'Instance' then
		pcall(function() old.gui:Destroy() end)
	end
	shared.vape = nil
	pcall(function() _G.vape = nil end)
	if getgenv then
		pcall(function() getgenv().vape = nil end)
	end
end

local vape
local compile = loadstring
local compileCache = type(shared.AetherCompileCache) == 'table' and shared.AetherCompileCache or {}
local watermark = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'
local function compileKey(source)
	return source:sub(1, #watermark) == watermark and source:sub(#watermark + 1) or source
end
local function sourceHasCode(path, source)
	if not path:match('games/%d+%.lua$') then return true end
	if type(source) ~= 'string' then return false end
	source = compileKey(source):gsub('^\239\187\191', '')
	while true do
		local before = source
		source = source:gsub('^%s*%-%-%[(=*)%[.-%]%1%]', '')
		source = source:gsub('^%s*%-%-[^\r\n]*', '')
		if source == before then break end
	end
	return source:match('%S') ~= nil
end
local loadstring = function(...)
	local source, chunkName = ...
	local key = compileKey(source)
	local res, err = compileCache[key], nil
	if not res then
		res, err = compile(source, chunkName)
		if res then compileCache[key] = res end
	end
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
local httpService = cloneref(game:GetService('HttpService'))
local function selectedSourceRef(ref)
	if type(ref) == 'string' and ref:gsub('%s+', '') ~= '' then return ref:gsub('%s+', '') end
	if type(shared.AetherV2PublicRef) == 'string' and shared.AetherV2PublicRef:gsub('%s+', '') ~= '' then
		return shared.AetherV2PublicRef:gsub('%s+', '')
	end
	local ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
	if ok and type(cached) == 'string' and cached:gsub('%s+', '') ~= '' then return cached:gsub('%s+', '') end
	return 'main'
end

local function publicSourceUrl(path, ref)
	return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedSourceRef(ref)..'/'..path:gsub('^aetherv2/', '')
end

-- Game and GUI modules use this shared fetcher when they need another public source file.
shared.AetherV2FetchSource = function(path, ref)
	return game:HttpGet(publicSourceUrl(path, ref), true)
end

-- init.lua owns the loading UI. main.lua only reports progress to that shared screen.
local closeLoadingScreen

local function setLoadingStatus(text, progress)
	if _G.AetherV2SetLoadingStatus then
		pcall(_G.AetherV2SetLoadingStatus, text, progress)
	end
end

closeLoadingScreen = function()
	if _G.AetherV2CloseLoadingScreen then
		pcall(_G.AetherV2CloseLoadingScreen)
	else
		local screen = _G.AetherV2LoadingScreen
		if screen and screen.Parent then
			screen:Destroy()
		end
	end
	_G.AetherV2LoadingScreen = nil
	_G.AetherV2SetLoadingStatus = nil
	_G.AetherV2CloseLoadingScreen = nil
end

local function failLoad(message)
	table.clear(compileCache)
	shared.AetherCompileCache = nil
	closeLoadingScreen()
	warn('[AetherV2] Load failed: '..tostring(message))
	pcall(function()
		game:GetService('StarterGui'):SetCore('SendNotification', {
			Title = 'AetherV2 failed to load',
			Text = tostring(message):sub(1, 180),
			Duration = 12
		})
	end)
	error(message, 0)
end

local redirect = function()
	local body = httpService:JSONEncode({
		nonce = httpService:GenerateGUID(false),
		args = {
			invite = {code = 'aetherv2'},
			code = 'aetherv2'
		},
		cmd = 'INVITE_BROWSER'
	})

	for i = 1, 2 do
		task.spawn(function()
			request({
				Method = 'POST',
				Url = 'http://127.0.0.1:6463/rpc?v=1',
				Headers = {
					['Content-Type'] = 'application/json',
					Origin = 'https://discord.com'
				},
				Body = body
			})
		end)
	end
end

local phaseFrom, phaseTo = 0, 1

local function setPhase(text, from, to)
	phaseFrom, phaseTo = from, to
	setLoadingStatus(text, from)
end

local function setPhaseProgress(text, alpha)
	setLoadingStatus(text, phaseFrom + ((phaseTo - phaseFrom) * math.clamp(alpha or 0, 0, 1)))
end

local function payloadProblem(path, body)
	if type(body) ~= 'string' or #body < 8 then return 'empty response' end
	local head = body:sub(1, 300)
	if head:find('^%s*404') or head:find('^%s*429') or head:find('^%s*5%d%d:') then
		return (head:match('^[^\r\n]*'))
	end
	local lowered = head:lower()
	if lowered:find('<!doctype html') or lowered:find('<html') then
		return 'received an HTML error page instead of the file'
	end
	if path:lower():sub(-4) == '.png' and body:sub(1, 8) ~= '\137PNG\r\n\26\n' then
		return 'invalid PNG response'
	end
	if path:sub(-4) == '.lua' and not sourceHasCode(path, body) then
		return 'the numeric game module contains no executable code'
	end
	if path:sub(-4) == '.lua' and not loadstring(body, path) then
		return 'the downloaded file did not compile'
	end
	return nil
end

local function fetchFile(path, attempts)
	attempts = attempts or 3
	local ref = selectedSourceRef()
	local problem
	for attempt = 1, attempts do
		local suc, res = pcall(function()
			if type(shared.AetherV2FetchSource) ~= 'function' then
				error('Public GitHub source transport is unavailable', 0)
			end
			return shared.AetherV2FetchSource(path, ref)
		end)
		if suc then
			problem = payloadProblem(path, res)
			if not problem then return res end
		else
			problem = tostring(res)
		end
		if attempt < attempts then
			setPhaseProgress('Retrying '..path..' ('..attempt..'/'..attempts..')', 0.2 * attempt)
			task.wait(attempt)
		end
	end
	return nil, problem
end

local function ensureParentFolder(path)
	local parent = path:gsub('\\', '/'):match('^(.*)/[^/]+$')
	if not parent then return end
	local built = ''
	for segment in parent:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if not isfolder(built) then pcall(makefolder, built) end
	end
end

local function storePublicFile(path, body)
	ensureParentFolder(path)
	if path:sub(-4) == '.lua' then body = watermark..body end
	local ok, err = pcall(writefile, path, body)
	if not ok then return false, err end
	local readOk, cached = pcall(readfile, path)
	local problem = readOk and payloadProblem(path, cached) or 'unreadable cache'
	return problem == nil, problem
end

local function downloadFile(path, func)
	local exists = isfile(path)
	local cachedProblem = exists and payloadProblem(path, readfile(path)) or nil
	if cachedProblem then
		warn('[AetherV2] Cached '..path..' is unusable ('..cachedProblem..'), downloading it again')
		delfile(path)
		exists = false
	end
	if not exists then
		setPhaseProgress('Downloading '..path, 0.15)
		local body, problem = fetchFile(path)
		if not body then failLoad('Could not download '..path..' - '..tostring(problem)) end
		local stored, storeProblem = storePublicFile(path, body)
		if not stored then failLoad('Could not cache '..path..' - '..tostring(storeProblem)) end
		setPhaseProgress('Downloaded '..path, 0.75)
	end
	return (func or readfile)(path)
end

local function downloadOptionalFile(path)
	if isfile(path) then
		local ok, cached = pcall(readfile, path)
		if ok and not payloadProblem(path, cached) then return true end
		delfile(path)
	end
	local suc, res = pcall(function()
		if type(shared.AetherV2FetchSource) ~= 'function' then return nil end
		return shared.AetherV2FetchSource(path, selectedSourceRef())
	end)
	if not suc or payloadProblem(path, res) then return false end
	return storePublicFile(path, res)
end

local loadingWarnings = {}
local gameLoadTrace

local function traceGameLoad(state, detail)
	if not gameLoadTrace then return end
	gameLoadTrace.State = state
	gameLoadTrace.Detail = detail
	gameLoadTrace.UpdatedAt = os.clock()
	table.insert(gameLoadTrace.Events, {
		State = state,
		Detail = detail,
		At = gameLoadTrace.UpdatedAt
	})
	warn('[AetherV2/GameLoader] '..state..(detail and (' | '..tostring(detail)) or ''))
end

local function runLoadingChunk(source, chunkName, ...)
	local chunk = loadstring(source, chunkName)
	if not chunk then
		failLoad('Failed to compile '..chunkName)
	end
	local args = {...}
	local ok, result = xpcall(function()
		return chunk(table.unpack(args))
	end, debug.traceback)
	if not ok then
		failLoad(result)
	end
	return result
end

local lateModules = false

local function applyLateModules(chunkName)
	if not vape then return end
	lateModules = true
	task.spawn(function()
		local deadline = os.clock() + 30
		repeat task.wait(0.2) until vape.Loaded or os.clock() > deadline
		if not vape.Loaded then return end
		local notifications = vape.ToggleNotifications
		local wasEnabled = notifications and notifications.Enabled
		if notifications then notifications.Enabled = false end
		pcall(function() vape:Load(true) end)
		if notifications then notifications.Enabled = wasEnabled end
		pcall(function()
			vape:CreateNotification('AetherV2', chunkName..' modules finished loading and have been added', 6, 'info')
		end)
	end)
end

local function runWatchedChunk(source, chunkName, label, timeout, optional, ...)
	local chunk = loadstring(source, chunkName)
	if not chunk then
		local message = 'Failed to compile '..chunkName
		if optional then
			table.insert(loadingWarnings, message)
			return nil
		end
		failLoad(message)
	end

	local args = table.pack(...)
	local finished, ok, result = false, true, nil
	local worker
	worker = task.spawn(function()
		if vape and vape.ThreadFix then setthreadidentity(8) end
		ok, result = xpcall(function()
			return chunk(table.unpack(args, 1, args.n))
		end, debug.traceback)
		finished = true
		if not ok then warn('[AetherV2] '..chunkName..' failed: '..tostring(result)) end
	end)

	local started = os.clock()
	while not finished do
		local elapsed = os.clock() - started
		if elapsed > timeout then
			local message = chunkName..' is still loading after '..math.floor(elapsed)..' seconds'
			local requiredGame = gameLoadTrace and chunkName == tostring(gameLoadTrace.ResolvedPlace)
			if requiredGame then
				pcall(task.cancel, worker)
				traceGameLoad('failed', message)
				failLoad(message)
			end
			table.insert(loadingWarnings, message..' - the menu was opened without it')
			applyLateModules(chunkName)
			return nil
		end
		if elapsed > 1.5 then
			setPhaseProgress(label..'  ('..math.floor(elapsed)..'s)', elapsed / timeout)
		end
		task.wait(0.1)
	end

	if not ok then
		if optional then
			table.insert(loadingWarnings, tostring(result))
			return nil
		end
		if gameLoadTrace and chunkName == tostring(gameLoadTrace.ResolvedPlace) then
			traceGameLoad('failed', tostring(result))
		end
		failLoad(result)
	end
	return result
end

local function loadPremiumModules()
	local fetchSource = shared.AetherV2PremiumFetchSource
	local fetchTree = shared.AetherV2PremiumFetchTree
	if type(fetchSource) ~= 'function' or type(fetchTree) ~= 'function' then return end

	setPhase('Finding premium modules', 0.97, 0.975)
	local ok, treeBody = pcall(fetchTree)
	if not ok or type(treeBody) ~= 'string' then
		warn('[AetherV2] Premium modules were unavailable; continuing with normal modules')
		return
	end
	local decoded, tree = pcall(httpService.JSONDecode, httpService, treeBody)
	if not decoded or type(tree) ~= 'table' or type(tree.tree) ~= 'table' then
		warn('[AetherV2] Premium module list was invalid; continuing with normal modules')
		return
	end

	local placeId = tostring(vape.Place or game.PlaceId)
	local function collectModules(prefix, destination)
		for _, entry in ipairs(tree.tree) do
			local path = type(entry) == 'table' and entry.path or nil
			if type(entry) == 'table' and entry.type == 'blob' and type(path) == 'string'
				and path:sub(1, #prefix) == prefix and path:sub(-4) == '.lua' then
				-- The first folder below a game's root is the AetherV2 category:
				-- games/universal/render/example.lua -> Render.
				local category = path:sub(#prefix + 1):match('^([^/]+)/')
				if category and category ~= '' then
					table.insert(destination, {Path = path, Category = category})
				end
			end
		end
		table.sort(destination, function(left, right) return left.Path < right.Path end)
	end

	local universal, gameModules = {}, {}
	collectModules('games/universal/', universal)
	collectModules('games/'..placeId..'/', gameModules)

	local modules = {}
	for _, module in ipairs(universal) do table.insert(modules, module) end
	for _, module in ipairs(gameModules) do table.insert(modules, module) end
	for index, module in ipairs(modules) do
		setPhase('Loading premium modules ('..index..'/'..#modules..')', 0.975, 0.985)
		local received, source = pcall(fetchSource, module.Path)
		if received and type(source) == 'string' and #source >= 8 then
			local chunk, compileError = loadstring(source, 'premium/'..module.Path)
			if chunk then
				local categoryName, categoryApi = module.Category, nil
				for name, category in pairs(vape.Categories or {}) do
					if tostring(name):lower() == module.Category:lower() then
						categoryName, categoryApi = name, category
						break
					end
				end
				local context = {
					Category = categoryName,
					CategoryApi = categoryApi,
					Path = module.Path,
					Scope = module.Path:sub(1, #'games/universal/') == 'games/universal/' and 'universal' or 'game'
				}
				local ran, result = xpcall(function()
					return chunk(vape, license, context)
				end, debug.traceback)
				if ran and type(result) == 'function' then
					ran, result = xpcall(function()
						return result(vape, license, context)
					end, debug.traceback)
				end
				if not ran then warn('[AetherV2] Premium module '..module.Path..' failed: '..tostring(result)) end
			else
				warn('[AetherV2] Premium module '..module.Path..' did not compile: '..tostring(compileError))
			end
		else
			warn('[AetherV2] Premium module '..module.Path..' could not be fetched')
		end
	end
end

local function finishLoading()
	setPhase('Finalizing', 0.97, 0.99)
	vape.Init = nil
	local loaded, loadError = xpcall(function()
		vape:Load()
	end, debug.traceback)
	table.clear(compileCache)
	shared.AetherCompileCache = nil
	if not loaded then failLoad(loadError) end
	if shared.AetherV2PremiumAuthorized and not license.Closet then
		pcall(function()
			vape:CreateNotification('AetherV2 Premium', 'Premium key validated', 6, 'info')
		end)
	end
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function(state)
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				if shared.VapeDeveloper then
					loadstring(readfile('aetherv2/main.lua'), 'main')(_scriptconfig)
				else
					shared.AetherResolvedCommit = nil
					loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/init.lua', true), 'init.lua')(_scriptconfig)
				end
			]]
			local teleportConfig = httpService:JSONEncode(license)
			teleportConfig = teleportConfig:gsub('\":true', '=true'):gsub('{\"', '{')
			teleportConfig = teleportConfig:gsub(',\"', ','):gsub('\":', '=')
			teleportConfig = teleportConfig:gsub('%[', '{'):gsub('%]', '}')
			teleportScript = teleportScript:gsub('_scriptconfig', teleportConfig)
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = \"'..shared.VapeCustomProfile..'\"\n'..teleportScript
			end
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if vape.Categories and vape.Categories.Main and vape.Categories.Main.Options and vape.Categories.Main.Options['GUI bind indicator'] and vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			if vape.Place ~= 6872274481 then
				--task.spawn(redirect)
			end
			vape:CreateNotification('Finished Loading', (vape.VapeButton and 'Press the button in the top right' or 'Press '..table.concat(vape.Keybind, ' + '):upper())..' to open GUI', 5)
		end
		local update = shared.updated
		shared.updated = nil
		if type(update) == 'table' then
			task.delay(1, function()
				local text
				if update.From and update.To and update.From ~= update.To then
					text = 'Updated to v'..update.To..' (was v'..update.From..')'
				elseif update.To then
					text = 'Updated to the latest v'..update.To..' build'
				else
					text = 'Updated to the latest build'
				end
				if update.Files and update.Files > 0 then
					text = text..' - '..update.Files..' file'..(update.Files == 1 and '' or 's')..' changed'
				end
				vape:CreateNotification('AetherV2', text, 8, 'info')
			end)
		end
		if #loadingWarnings > 0 then
			vape:CreateNotification('AetherV2', 'Loaded with non-critical game module warnings. Check the console for details.', 10, 'info')
			warn(table.concat(loadingWarnings, '\n'))
		end
	end

	setLoadingStatus('Finished loading', 1)
	task.defer(closeLoadingScreen)
end

if not isfile('aetherv2/profiles/gui.txt') then
	writefile('aetherv2/profiles/gui.txt', 'new')
end
local validGuis = {new = true, old = true, rise = true}
local gui = readfile('aetherv2/profiles/gui.txt'):gsub('%s+', '')
if gui == 'newer' then
	gui = 'new'
	writefile('aetherv2/profiles/gui.txt', gui)
end
if not validGuis[gui] then
	gui = 'new'
	writefile('aetherv2/profiles/gui.txt', gui)
end

if not isfolder('aetherv2/assets/'..gui) then
	makefolder('aetherv2/assets/'..gui)
end
for _, folder in {'aetherv2/songs'} do
	if not isfolder(folder) then makefolder(folder) end
end
if not isfile('aetherv2/profiles/commit.txt') then
	writefile('aetherv2/profiles/commit.txt', selectedSourceRef())
end
if not isfile('aetherv2/profiles/disableloading.txt') then
	writefile('aetherv2/profiles/disableloading.txt', 'false')
end

globalenv.used_init = true
setPhase('Preparing loading artwork', 0.82, 0.84)
downloadOptionalFile('aetherv2/assets/new/loading.png')

setPhase('Loading interface', 0.84, 0.88)
vape = runLoadingChunk(downloadFile('aetherv2/guis/'..gui..'.lua'), 'gui', license)
_G.vape = vape
shared.vape = vape

if shared.mainAether then
	closeLoadingScreen()
	redirect()
	playersService.LocalPlayer:Kick('Your script is outdated, Get new one at discord.gg/aetherv2')
	return
end

if not shared.VapeIndependent then
	setPhase('Loading universal modules', 0.88, 0.93)
	runWatchedChunk(downloadFile('aetherv2/games/universal.lua'), 'universal', 'Loading universal modules', 30, false, license)

	setPhase('Loading game modules', 0.93, 0.97)
	local requestedPlace = tostring(game.PlaceId)
	local modulePlace = requestedPlace
	if isfile('aetherv2/profiles/forcegame.txt')
		and readfile('aetherv2/profiles/forcegame.txt') == 'true'
		and isfile('aetherv2/profiles/forcegameid.txt') then
		local forced = readfile('aetherv2/profiles/forcegameid.txt'):match('^%s*(%d+)%s*$')
		modulePlace = forced or modulePlace
	end
	writefile('aetherv2/profiles/forcegame.txt', 'false')
	vape.Place = tonumber(modulePlace) or game.PlaceId

	local repoPlacePath = 'games/'..modulePlace..'.lua'
	local placePath = 'aetherv2/'..repoPlacePath
	local knownFiles = shared.AetherV2KnownSourceFiles
	local exactKnown = type(knownFiles) == 'table' and knownFiles[repoPlacePath] ~= nil
	gameLoadTrace = {
		RequestedPlace = requestedPlace,
		ResolvedPlace = modulePlace,
		Path = repoPlacePath,
		KnownCompatible = exactKnown,
		StartedAt = os.clock(),
		Events = {}
	}
	shared.AetherGameLoadTrace = gameLoadTrace
	traceGameLoad('selected', (modulePlace ~= requestedPlace and ('forced from '..requestedPlace) or 'exact PlaceId'))

	local placeSource
	if isfile(placePath) then
		local cachedProblem = payloadProblem(placePath, readfile(placePath))
		if cachedProblem then
			traceGameLoad('cache-rejected', cachedProblem)
			delfile(placePath)
		else
			placeSource = readfile(placePath)
			traceGameLoad('source-ready', 'validated cache')
		end
	end

	if not placeSource and not shared.VapeDeveloper then
		setPhaseProgress('Downloading module for this game', 0.1)
		traceGameLoad('fetching', repoPlacePath)
		local body, problem = fetchFile(placePath, 3)
		if body then
			writefile(placePath, watermark..body)
			placeSource = readfile(placePath)
			traceGameLoad('source-ready', 'public GitHub source')
		elseif exactKnown then
			traceGameLoad('failed', problem)
			failLoad('Supported game module '..repoPlacePath..' could not be downloaded - '..tostring(problem))
		elseif problem and not tostring(problem):find('404', 1, true) then
			traceGameLoad('failed', problem)
			failLoad('Could not determine game compatibility for '..repoPlacePath..' - '..tostring(problem))
		else
			traceGameLoad('unsupported', 'exact file does not exist')
		end
	end

	if placeSource then
		local function registeredOptionCount()
			local count, seen = 0, {}
			for _, category in pairs(vape.Categories or {}) do
				local options = type(category) == 'table' and category.Options or nil
				if type(options) == 'table' and not seen[options] then
					seen[options] = true
					for _ in pairs(options) do count += 1 end
				end
			end
			return count
		end

		local before = registeredOptionCount()
		traceGameLoad('executing', #placeSource..' bytes')
		runWatchedChunk(placeSource, modulePlace, 'Loading module for this game', 75, false, license)
		local added = registeredOptionCount() - before
		gameLoadTrace.ModulesAdded = math.max(added, 0)
		if added <= 0 then
			traceGameLoad('loaded', '0 registered options')
			warn('[AetherV2] '..repoPlacePath..' executed but registered no game modules')
		else
			traceGameLoad('loaded', added..' registered options')
		end
	end
	loadPremiumModules()
	finishLoading()
else
	vape.Init = finishLoading
	setLoadingStatus('Ready for independent initialization', 1)
	return vape
end
