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
	-- Uninject clears these itself; repeating it here covers the case where the old
	-- instance was broken enough that its own teardown never got that far. A stale
	-- _G.vape is what lets the NEXT script find this one and run on its GUI.
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
local function normalizeSourceEndpoint(value)
	if type(value) ~= 'string' then return nil end
	value = value:gsub('%s+', '')
	while value:sub(-1) == '/' do value = value:sub(1, -2) end
	return value ~= '' and value or nil
end
local function urlEncode(value)
	return tostring(value):gsub('([^%w%-%._~])', function(character)
		return string.format('%%%02X', string.byte(character))
	end)
end
local sourceEndpoint
local sourceToken
local sourceRef
if type(license) == 'table' then
	sourceEndpoint = normalizeSourceEndpoint(license.SourceEndpoint)
	sourceToken = type(license.SourceToken) == 'string' and license.SourceToken or nil
	sourceRef = type(license.SourceRef) == 'string' and license.SourceRef or nil
end
if not sourceEndpoint and getgenv then
	pcall(function()
		sourceEndpoint = normalizeSourceEndpoint(getgenv().AetherV2SourceEndpoint)
		sourceToken = sourceToken or getgenv().AetherV2SourceToken
	end)
end
if not sourceEndpoint then
	sourceEndpoint = normalizeSourceEndpoint(shared.AetherV2SourceEndpoint)
	sourceToken = sourceToken or shared.AetherV2SourceToken
end
local function privateSourceUrl(path, ref)
	if not sourceEndpoint then return nil end
	ref = ref or sourceRef
	if not ref or ref == '' then error('Private source configuration is missing SourceRef', 0) end
	local sessionSuffix = sourceToken and ('&session='..urlEncode(sourceToken)) or ''
	return sourceEndpoint..'/source?path='..urlEncode(path:gsub('^aetherv2/', ''))..'&ref='..urlEncode(ref)..sessionSuffix
end
-- init.lua owns the loading UI.  main.lua only reports progress to that shared screen.

local closeLoadingScreen

local function setLoadingStatus(text, progress)
	if _G.AetherV2SetLoadingStatus then
		pcall(_G.AetherV2SetLoadingStatus, text, progress)
	end
end

closeLoadingScreen = function()
	-- Prefer the screen's own closer so the active loading screen can fade
	-- out; the classic screen's closer just destroys, so nothing regresses.
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

-- A load that dies silently is indistinguishable from one that never started, and that is most of
-- what "the script just doesn't work" turns out to be. Every fatal path goes through here: the
-- screen comes down so nothing is left frozen on it, the reason goes to the console AND to a Roblox
-- notification so the user can actually report it, and only then does it raise.
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

-- Loading phases.
--
-- Progress used to be reported with fixed numbers from wherever the code happened to be, so a
-- download that ran during the 88% step reported 60% and then 72%. The screen only ever moves
-- forward, so those updates were dropped entirely and the bar sat still - which is what "stuck at
-- 88%" looks like from the outside even when work is happening. Each step now owns a slice of the
-- bar and anything inside it reports within that slice, so the bar always moves and never jumps back.
local phaseFrom, phaseTo = 0, 1

local function setPhase(text, from, to)
	phaseFrom, phaseTo = from, to
	setLoadingStatus(text, from)
end

local function setPhaseProgress(text, alpha)
	setLoadingStatus(text, phaseFrom + ((phaseTo - phaseFrom) * math.clamp(alpha or 0, 0, 1)))
end

-- Did we get the file we asked for, or did GitHub hand us something else? A rate-limit page, an
-- error body or a half-received file written to disk is a permanent break: isfile() says the file
-- is there forever after, so every later injection loads the same broken copy. Returns a reason
-- when the payload is not usable.
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
	if path:sub(-4) == '.lua' and not loadstring(body, path) then
		return 'the downloaded file did not compile'
	end
	return nil
end

-- Fetch with retries. A single failed request used to end the whole load; most of them are
-- transient (a dropped connection, a moment of rate limiting) and succeed on the next try.
local function fetchFile(path, attempts)
	attempts = attempts or 3
	local ref = readfile('aetherv2/profiles/commit.txt')
	local url = privateSourceUrl(path, ref) or ('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/'..select(1, path:gsub('aetherv2/', '')))
	local problem
	for attempt = 1, attempts do
		local suc, res = pcall(function()
			return game:HttpGet(url, true)
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

local function downloadFile(path, func)
	-- Heal a broken cache before trusting it. Without this, one interrupted write means the script
	-- never loads again on that machine, however many times it is re-injected.
	local exists = isfile(path)
	if exists and path:sub(-4) == '.lua' and not loadstring(readfile(path), path) then
		warn('[AetherV2] Cached '..path..' is unusable, downloading it again')
		delfile(path)
		exists = false
	end
	if not exists then
		setPhaseProgress('Downloading '..path, 0.15)
		local body, problem = fetchFile(path)
		if not body then
			failLoad('Could not download '..path..' - '..tostring(problem))
		end
		if path:sub(-4) == '.lua' then
			body = watermark..body
		end
		writefile(path, body)
		setPhaseProgress('Downloaded '..path, 0.75)
	end
	return (func or readfile)(path)
end

local function downloadOptionalFile(path)
	if isfile(path) then return true end
	local suc, res = pcall(function()
		local ref = readfile('aetherv2/profiles/commit.txt')
		return game:HttpGet(privateSourceUrl(path, ref) or ('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..ref..'/'..select(1, path:gsub('aetherv2/', ''))), true)
	end)
	if not suc or res == '404: Not Found' then return false end
	writefile(path, res)
	return true
end

local loadingWarnings = {}

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

-- Modules that arrived after the menu was already built. Their saved settings have to be applied
-- again, because vape:Load ran while they did not exist yet.
local lateModules = false

local function applyLateModules(chunkName)
	if not vape then return end
	lateModules = true
	task.spawn(function()
		-- Wait for the menu to exist before re-applying, in case the chunk finished first.
		local deadline = os.clock() + 30
		repeat task.wait(0.2) until vape.Loaded or os.clock() > deadline
		if not vape.Loaded then return end
		-- Re-applying the config toggles modules, and each toggle announces itself. On a late load
		-- that would be one notification per enabled module, so mute them for the pass.
		local notifications = vape.ToggleNotifications
		local wasEnabled = notifications and notifications.Enabled
		if notifications then
			notifications.Enabled = false
		end
		pcall(function()
			vape:Load(true)
		end)
		if notifications then
			notifications.Enabled = wasEnabled
		end
		pcall(function()
			vape:CreateNotification('AetherV2', chunkName..' modules finished loading and have been added', 6, 'info')
		end)
	end)
end

-- Run a loading chunk on its own thread, watching it rather than waiting on it.
--
-- Game modules can wait on runtime state that is not present yet. Watch them instead of blocking the
-- whole menu forever; if a chunk finishes later, apply its modules after the interface is already up.
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
	task.spawn(function()
		if vape and vape.ThreadFix then
			setthreadidentity(8)
		end
		ok, result = xpcall(function()
			return chunk(table.unpack(args, 1, args.n))
		end, debug.traceback)
		finished = true
		if not ok then
			warn('[AetherV2] '..chunkName..' failed: '..tostring(result))
		end
	end)

	local started = os.clock()
	while not finished do
		local elapsed = os.clock() - started
		if elapsed > timeout then
			table.insert(loadingWarnings, chunkName..' is still loading after '..math.floor(elapsed)..' seconds - the menu was opened without it')
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
		failLoad(result)
	end
	return result
end

local function finishLoading()
	setPhase('Finalizing', 0.97, 0.99)
	vape.Init = nil
	local loaded, loadError = xpcall(function()
		vape:Load()
	end, debug.traceback)
	table.clear(compileCache)
	shared.AetherCompileCache = nil
	if not loaded then
		failLoad(loadError)
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
					local config = _scriptconfig
					if config.SourceEndpoint then
						local function encode(value)
							return tostring(value):gsub('([^%w%-%._~])', function(character)
								return string.format('%%%02X', string.byte(character))
							end)
						end
						assert(config.SourceRef, 'Private source configuration is missing SourceRef')
						local session = config.SourceToken and '&session='..encode(config.SourceToken) or ''
						loadstring(game:HttpGet(config.SourceEndpoint..'/source?path=init.lua&ref='..encode(config.SourceRef)..session, true), 'init.lua')(config)
					else
						loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/init.lua', true), 'init.lua')(config)
					end
				end
			]]
			local teleportConfig = httpService:JSONEncode(license)
			teleportConfig = teleportConfig:gsub('":true', "=true"):gsub('{"', '{')
			teleportConfig = teleportConfig:gsub(',"', ','):gsub('":', '=')
			teleportConfig = teleportConfig:gsub('%[', '{'):gsub('%]', '}')
			teleportScript = teleportScript:gsub('_scriptconfig', teleportConfig)
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
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
	if not isfolder(folder) then
		makefolder(folder)
	end
end
if not isfile('aetherv2/profiles/commit.txt') then
	writefile('aetherv2/profiles/commit.txt', sourceEndpoint and sourceRef or 'main')
end
if not isfile('aetherv2/profiles/disableloading.txt') then
	writefile('aetherv2/profiles/disableloading.txt', 'false')
end
if not isfile('aetherv2/profiles/releasechannel.txt') then
	writefile('aetherv2/profiles/releasechannel.txt', 'stable')
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
	local modulePlace = tostring(game.PlaceId)
	if isfile('aetherv2/profiles/forcegame.txt')
		and readfile('aetherv2/profiles/forcegame.txt') == 'true'
		and isfile('aetherv2/profiles/forcegameid.txt') then
		local forced = readfile('aetherv2/profiles/forcegameid.txt'):match('^%s*(%d+)%s*$')
		modulePlace = forced or modulePlace
	end
	writefile('aetherv2/profiles/forcegame.txt', 'false')
	vape.Place = tonumber(modulePlace) or game.PlaceId
	local placePath = 'aetherv2/games/'..modulePlace..'.lua'
	local placeSource
	if isfile(placePath) then
		placeSource = downloadFile(placePath)
	elseif not shared.VapeDeveloper then
		setPhaseProgress('Downloading module for this game', 0.1)
		local body = fetchFile(placePath, 1)
		if body then
			writefile(placePath, watermark..body)
			placeSource = readfile(placePath)
		end
	end
	if placeSource then
		runWatchedChunk(placeSource, modulePlace, 'Loading module for this game', 15, true, license)
	end
	finishLoading()
else
	vape.Init = finishLoading
	setLoadingStatus('Ready for independent initialization', 1)
	return vape
end
