local license = ... or {}
local globalenv = (getgenv and getgenv()) or _G
license.Whitelist = globalenv.whitelist or license.Whitelist
local acceptedWhitelistKey = '1234-5678-9012-3456'

local function isWhitelisted()
	return tostring(globalenv.whitelist or license.Whitelist or '') == acceptedWhitelistKey
end
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
local delfile = delfile or function(file)
	pcall(writefile, file, '')
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))
local startupMarkerPath = 'aetherv2/profiles/startup.json'

local function markStartup(stage, module)
	pcall(writefile, startupMarkerPath, httpService:JSONEncode({
		state = 'loading',
		stage = stage,
		module = module,
		time = os.time()
	}))
end

-- Loading UI is owned by init.lua so every entry path uses one canonical screen.
-- main.lua only reports progress to, and closes, that bootstrap-created instance.
local loadingScreenClosed = false

local function setLoadingStatus(text, progress)
	if license.Closet or loadingScreenClosed then
		return
	end

	local updateStatus = _G.AetherV2SetLoadingStatus
	if type(updateStatus) == 'function' then
		pcall(updateStatus, text, progress)
	end
end

local function closeLoadingScreen()
	if loadingScreenClosed then
		return
	end
	loadingScreenClosed = true

	local closeScreen = _G.AetherV2CloseLoadingScreen
	if type(closeScreen) == 'function' then
		pcall(closeScreen)
	else
		local screen = _G.AetherV2LoadingScreen
		if typeof(screen) == 'Instance' then
			pcall(function()
				screen:Destroy()
			end)
		end
	end

	_G.AetherV2LoadingScreen = nil
	_G.AetherV2SetLoadingStatus = nil
	_G.AetherV2CloseLoadingScreen = nil
end

<<<<<<< HEAD
-- main.lua can be loaded directly by developer and teleport entrypoints, where
-- init.lua's equivalent helper is not in scope.  Keep failures actionable and
-- always remove the loader instead of replacing the original error with an
-- "attempt to call a nil value" crash.
local function failLoad(message)
	table.clear(compileCache)
	shared.AetherCompileCache = nil
	closeLoadingScreen()
	warn('[AetherV2] Load failed: '..tostring(message))
	pcall(function()
		game:GetService('StarterGui'):SetCore('SendNotification', {
			Title = 'AetherV2 failed to load',
			Text = tostring(message):sub(1, 180),
=======
-- main.lua owns failures after init.lua hands control over. Keeping this local
-- prevents a failed download or module from leaving the bootstrap screen visible.
local function failLoad(message)
	message = tostring(message)
	closeLoadingScreen()
	table.clear(compileCache)
	shared.AetherCompileCache = nil
	warn('[AetherV2] Load failed: '..message)
	pcall(function()
		game:GetService('StarterGui'):SetCore('SendNotification', {
			Title = 'AetherV2 failed to load',
			Text = message:sub(1, 180),
>>>>>>> d334db2f1027e9dfa565a6d61d29d573002f8347
			Duration = 12
		})
	end)
	error(message, 0)
end

-- Safe Mode can also be reached after the bootstrap has dismissed its loader.
-- It deliberately has its own parent resolver, rather than recreating loader UI.
local function getSafeModeParent()
	if gethui then
		local ok, parent = pcall(gethui)
		if ok and parent then
			return parent
		end
	end

	local ok, parent = pcall(function()
		return cloneref(game:GetService('CoreGui'))
	end)
	return ok and parent or nil
end

local function promptSafeMode(failure)
	if type(failure) ~= 'table' then return 'normal' end
	local parent = getSafeModeParent()
	if not parent then return 'normal' end
	local screen = Instance.new('ScreenGui')
	screen.Name = 'AetherSafeMode'
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 2147483647
	screen.Parent = parent
	local shade = Instance.new('Frame')
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new()
	shade.BackgroundTransparency = 0.25
	shade.Parent = screen
	local card = Instance.new('Frame')
	card.Size = UDim2.fromOffset(540, 300)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(17, 20, 31)
	card.Parent = shade
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local stroke = Instance.new('UIStroke')
	stroke.Color = Color3.fromRGB(190, 115, 255)
	stroke.Transparency = 0.35
	stroke.Parent = card
	local title = Instance.new('TextLabel')
	title.Size = UDim2.new(1, -36, 0, 36)
	title.Position = UDim2.fromOffset(18, 16)
	title.BackgroundTransparency = 1
	title.Text = 'AetherV2 Safe Mode'
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(240, 242, 252)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = card
	local reason = Instance.new('TextLabel')
	reason.Size = UDim2.new(1, -36, 0, 70)
	reason.Position = UDim2.fromOffset(18, 58)
	reason.BackgroundTransparency = 1
	reason.Text = 'The previous startup did not finish. Last stage: '..tostring(failure.module or failure.stage or 'unknown')..'\nChoose how this launch should recover.'
	reason.TextWrapped = true
	reason.TextXAlignment = Enum.TextXAlignment.Left
	reason.TextYAlignment = Enum.TextYAlignment.Top
	reason.TextColor3 = Color3.fromRGB(175, 181, 204)
	reason.TextSize = 14
	reason.Font = Enum.Font.Gotham
	reason.Parent = card
	local choice
	local function button(text, y, value, description)
		local object = Instance.new('TextButton')
		object.Size = UDim2.new(1, -36, 0, 44)
		object.Position = UDim2.fromOffset(18, y)
		object.BackgroundColor3 = value == 'normal' and Color3.fromRGB(113, 71, 170) or Color3.fromRGB(31, 36, 53)
		object.Text = text..'  —  '..description
		object.TextColor3 = Color3.fromRGB(235, 238, 249)
		object.TextSize = 13
		object.Font = Enum.Font.GothamMedium
		object.Parent = card
		local objectCorner = Instance.new('UICorner')
		objectCorner.CornerRadius = UDim.new(0, 7)
		objectCorner.Parent = object
		object.MouseButton1Click:Connect(function() choice = value end)
	end
	button('Start normally', 132, 'normal', 'retry the complete startup')
	button('Disable failed component', 184, 'disable', 'skip the last failing component')
	button('Core + GUI only', 236, 'core', 'load no universal or game modules')
	local deadline = os.clock() + 30
	repeat task.wait(0.05) until choice or os.clock() >= deadline
	choice = choice or 'normal'
	screen:Destroy()
	return choice
end

local redirect = function()
	local discordRequest = type(request) == 'function' and request or (type(http_request) == 'function' and http_request or (syn and type(syn.request) == 'function' and syn.request))
	if type(discordRequest) ~= 'function' then return end
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
			pcall(discordRequest, {
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

-- Requests are bounded so an executor/network stall cannot hold the bootstrap forever.
local function httpGet(url, timeout)
	timeout = timeout or 15
	local executorRequest = type(request) == 'function' and request or (type(http_request) == 'function' and http_request or (syn and type(syn.request) == 'function' and syn.request))
	if type(executorRequest) == 'function' then
		local finished, response = false, nil
		task.spawn(function()
			local success, result = pcall(executorRequest, {
				Url = url,
				Method = 'GET',
				Timeout = timeout
			})
			response = {Success = success, Value = result}
			finished = true
		end)
		local deadline = os.clock() + timeout
		repeat
			task.wait()
		until finished or os.clock() >= deadline
		if not finished then
			return nil, 'request timed out after '..tostring(timeout)..' seconds'
		end
		if not response.Success then
			return nil, tostring(response.Value)
		end
		if type(response.Value) == 'string' then
			return response.Value
		end
		if type(response.Value) == 'table' then
			local status = tonumber(response.Value.StatusCode or response.Value.status_code or response.Value.Status)
			if status and (status < 200 or status >= 300) then
				return nil, 'HTTP '..tostring(status)
			end
			return response.Value.Body or response.Value.body
		end
	end

	local finished, response = false, nil
	task.spawn(function()
		local success, body = pcall(function()
			return game:HttpGet(url, true)
		end)
		response = {Success = success, Body = body}
		finished = true
	end)
	local deadline = os.clock() + timeout
	repeat
		task.wait()
	until finished or os.clock() >= deadline
	if not finished then
		return nil, 'request timed out after '..tostring(timeout)..' seconds'
	end
	if not response.Success then
		return nil, tostring(response.Body)
	end
	return response.Body
end

local function storedCommit()
	local success, value = pcall(readfile, 'aetherv2/profiles/commit.txt')
	if success and type(value) == 'string' then
		value = value:gsub('%s+', '')
		if value ~= '' then return value end
	end
	return 'main'
end

-- Fetch with retries. A single failed request used to end the whole load; most of them are
-- transient (a dropped connection, a moment of rate limiting) and succeed on the next try.
local function fetchFile(path, attempts)
	attempts = attempts or 3
	local url = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..storedCommit()..'/'..select(1, path:gsub('aetherv2/', ''))
	local problem
	for attempt = 1, attempts do
		local res, requestProblem = httpGet(url, 20)
		if res ~= nil then
			problem = payloadProblem(path, res)
			if not problem then return res end
		else
			problem = requestProblem or 'empty response'
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
		local temporary = path..'.aether-new'
		writefile(temporary, body)
		local verified = readfile(temporary)
		if verified ~= body or (path:sub(-4) == '.lua' and not loadstring(verified, path)) then
			pcall(delfile, temporary)
			failLoad('Could not validate temporary download for '..path)
		end
		local moved = renamefile and pcall(renamefile, temporary, path) or false
		if not moved then
			writefile(path, verified)
			pcall(delfile, temporary)
		end
		setPhaseProgress('Downloaded '..path, 0.75)
	end
	return (func or readfile)(path)
end

local function downloadOptionalFile(path)
	if isfile(path) then return true end
	local res = httpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..storedCommit()..'/'..select(1, path:gsub('aetherv2/', '')), 15)
	if not res or payloadProblem(path, res) then return false end
	writefile(path, res)
	return true
end


local loadingWarnings = {}

local function compileWithTimeout(source, chunkName, timeout)
	local finished, chunk, compileError = false, nil, nil
	task.spawn(function()
		chunk, compileError = loadstring(source, chunkName)
		finished = true
	end)
	local deadline = os.clock() + timeout
	repeat
		task.wait()
	until finished or os.clock() >= deadline
	if not finished then
		return nil, 'timed out after '..tostring(timeout)..' seconds'
	end
	return chunk, compileError
end

local function runLoadingChunk(source, chunkName, ...)
	local chunk, compileError = compileWithTimeout(source, chunkName, 30)
	if not chunk then
		failLoad('Failed to compile '..chunkName..(compileError and ': '..tostring(compileError) or ''))
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
-- This is the other half of the "stuck at 88%" fix. Game modules run during the load, and a module
-- that waits on something the game never provides used to take the whole load down with it: no
-- menu, no error, just a percentage that never moved. Now the loader watches instead of blocking -
-- the status text counts the seconds, so it is visibly alive - and if a chunk outstays its welcome
-- we build the menu without it. The chunk is not killed; if it does finish later, its modules are
-- added and their saved settings re-applied.
local function runWatchedChunk(source, chunkName, label, timeout, optional, ...)
	local chunk, compileError = compileWithTimeout(source, chunkName, math.max(timeout or 15, 15))
	if not chunk then
		local message = 'Failed to compile '..chunkName..(compileError and ': '..tostring(compileError) or '')
		if optional then
			table.insert(loadingWarnings, message)
			return nil
		end
		failLoad(message)
	end

	local args = table.pack(...)
	local finished, ok, result = false, true, nil
	task.spawn(function()
		-- Same thread fix the GUI applies to its own spawned threads, so a chunk that now runs off
		-- the main thread keeps the identity it needs for protected calls.
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

local function runWithTimeout(func, timeout, label)
	local finished, success, result = false, false, nil
	task.spawn(function()
		success, result = xpcall(func, debug.traceback)
		finished = true
	end)
	local deadline = os.clock() + timeout
	repeat
		task.wait(0.1)
	until finished or os.clock() >= deadline
	if not finished then
		return false, false, label..' timed out after '..tostring(timeout)..' seconds'
	end
	return true, success, result
end

local function finishLoading()
	setPhase('Finalizing', 0.97, 0.99)
	vape.Init = nil
	local finished, loaded, loadError = runWithTimeout(function()
		vape:Load()
	end, 30, 'vape:Load')
	-- Source strings can be hundreds of kilobytes. They are only useful during startup validation;
	-- release both keys and compiled closures as soon as all startup chunks have run.
	table.clear(compileCache)
	shared.AetherCompileCache = nil
	if not loaded then
		failLoad(loadError)
	end
	pcall(delfile, startupMarkerPath)
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
				local globalenv = (getgenv and getgenv()) or _G
				globalenv.whitelist = '_whitelist'
				if shared.VapeDeveloper then
					loadstring(readfile('aetherv2/main.lua'), 'main')(_scriptconfig)
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/init.lua', true), 'init.lua')(_scriptconfig)
				end
			]]
			local teleportConfig = httpService:JSONEncode(license)
			teleportConfig = teleportConfig:gsub('":true', "=true"):gsub('{"', '{')
			teleportConfig = teleportConfig:gsub(',"', ','):gsub('":', '=')
			teleportConfig = teleportConfig:gsub('%[', '{'):gsub('%]', '}')
			teleportScript = teleportScript:gsub('_whitelist', tostring(globalenv.whitelist or license.Whitelist or 'KEY_HERE'))
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
		-- Update notice.
		--
		-- This used to read "Script has updated from <40 hex chars> to <40 hex chars>",
		-- which named two commits nobody can tell apart and fired for every commit the
		-- repository received - including ones that changed nothing this install has.
		-- init.lua now only leaves shared.updated behind when files on THIS machine were
		-- actually replaced, and hands over the version either side of it.
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
		if shared.AetherRolledBack then
			shared.AetherRolledBack = nil
			task.delay(1, function()
				vape:CreateNotification('AetherV2', 'Restored the previous cached revision successfully.', 8, 'info')
			end)
		end
		if #loadingWarnings > 0 then
			vape:CreateNotification('AetherV2', 'Loaded with non-critical game module warnings. Check the console for details.', 10, 'info')
			warn(table.concat(loadingWarnings, '\n'))
		end
	end

	setLoadingStatus('Finished loading', 1)
	-- The old two-second victory pause made an already-ready menu feel slow. Let the loading
	-- screen's own closer perform its fade immediately after the final status is rendered.
	task.defer(closeLoadingScreen)
end

-- init.lua creates these on the normal route, but main.lua is also a supported
-- direct/teleport entrypoint.  Make that route self-sufficient before any
-- profile or cache file is written.
for _, folder in {
	'aetherv2',
	'aetherv2/profiles',
	'aetherv2/assets',
	'aetherv2/guis',
	'aetherv2/games',
	'aetherv2/libraries',
	'aetherv2/songs'
} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not isfile('aetherv2/profiles/gui.txt') then
	writefile('aetherv2/profiles/gui.txt', 'new')
end
local validGuis = {new = true, newer = true, old = true, rise = true}
local gui = readfile('aetherv2/profiles/gui.txt'):gsub('%s+', '')
if not validGuis[gui] then
	gui = 'new'
	writefile('aetherv2/profiles/gui.txt', gui)
end

-- Nexus is now the one UI core.  The old GUI choices are preserved as skins so existing
-- gui.txt profiles continue to mean the same thing without loading a separate 400 KB client.
local guiSkin = ({new = 'Classic', newer = 'Nexus', old = 'Old', rise = 'Rise'})[gui] or 'Nexus'
license.Skin = guiSkin
local guiCore = 'newer'

if not isfolder('aetherv2/assets/'..gui) then
	makefolder('aetherv2/assets/'..gui)
end
if not isfile('aetherv2/profiles/commit.txt') then
	writefile('aetherv2/profiles/commit.txt', 'main')
end
if not isfile('aetherv2/profiles/disableloading.txt') then
	writefile('aetherv2/profiles/disableloading.txt', 'false')
end

globalenv.used_init = true
setPhase('Preparing loading artwork', 0.82, 0.84)
downloadOptionalFile('aetherv2/assets/new/loading.png')
setPhase('Loading interface', 0.84, 0.88)
markStartup('gui', guiCore)
vape = runLoadingChunk(downloadFile('aetherv2/guis/'..guiCore..'.lua'), 'gui', license)
_G.vape = vape
shared.vape = vape

local safeFailure = license.SafeModeFailure
local safeModeChoice = promptSafeMode(safeFailure)
license.SafeModeFailure = nil
if safeModeChoice == 'core' then
	license.SafeModeCoreOnly = true
elseif safeModeChoice == 'disable' then
	local failed = tostring((safeFailure and (safeFailure.module or safeFailure.stage)) or '')
	license.SafeModeDisabled = failed
	license.SafeModeSkipUniversal = failed == 'universal'
	license.SafeModeSkipGame = tonumber(failed) ~= nil or failed == 'game'
end

if shared.mainAether then
	closeLoadingScreen()
	redirect()
	playersService.LocalPlayer:Kick('Your script is outdated, Get new one at discord.gg/aetherv2')
	return
end

if not shared.VapeIndependent and not license.SafeModeCoreOnly then
	setPhase('Loading universal modules', 0.88, 0.93)
	-- Watched rather than waited on, and generous: universal is where every game-independent module
	-- is registered, so it is worth a long leash - but not an unlimited one.
	if not license.SafeModeSkipUniversal then
		markStartup('universal', 'universal')
		runWatchedChunk(downloadFile('aetherv2/games/universal.lua'), 'universal', 'Loading universal modules', 30, false, license)
	end

	setPhase('Loading game modules', 0.93, 0.97)
	local modulePlace = tostring(game.PlaceId)
	if isfile('aetherv2/profiles/forcegame.txt')
		and readfile('aetherv2/profiles/forcegame.txt') == 'true'
		and isfile('aetherv2/profiles/forcegameid.txt') then
		local forced = readfile('aetherv2/profiles/forcegameid.txt'):match('^%s*(%d+)%s*$')
		modulePlace = forced or modulePlace
	end
	-- Force-loading is a one-shot debugging action. Consume it before running the chunk so even a
	-- broken or stalled game module cannot leave the user permanently pinned to the wrong game.
	writefile('aetherv2/profiles/forcegame.txt', 'false')
	vape.Place = tonumber(modulePlace) or game.PlaceId
	local placePath = 'aetherv2/games/'..modulePlace..'.lua'
	local placeSource
	if license.SafeModeSkipGame then
		placeSource = nil
	elseif isfile(placePath) then
		placeSource = downloadFile(placePath)
	elseif not shared.VapeDeveloper then
		setPhaseProgress('Downloading module for this game', 0.1)
		-- One attempt only: most games simply have no module, and a 404 is the expected answer.
		-- Retrying it would add seconds and two pointless requests to every unsupported game.
		local body = fetchFile(placePath, 1)
		if body then
			writefile(placePath, '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..body)
			placeSource = readfile(placePath)
		end
	end
	if placeSource then
		-- Optional and watched: a game module that stalls (waiting on something the game has not
		-- replicated yet) must never cost you the menu.
		markStartup('game', modulePlace)
		runWatchedChunk(placeSource, modulePlace, 'Loading module for this game', 15, true, license)
	end
	finishLoading()
elseif license.SafeModeCoreOnly then
	finishLoading()
else
	vape.Init = finishLoading
	setLoadingStatus('Ready for independent initialization', 1)
	return vape
end
