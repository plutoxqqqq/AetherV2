--!nocheck
local license = ... or {}
if type(license) ~= 'table' then license = {} end

shared.AetherV2PremiumAuthorized = false
shared.AetherV2PremiumToken = nil
shared.AetherV2PremiumRef = nil
shared.AetherV2PremiumFetchSource = nil
shared.AetherV2PremiumFetchTree = nil
shared.AetherV2PremiumModules = {}

local function premiumEncode(value)
	return tostring(value):gsub('([^%w%-%._~])', function(character)
		return string.format('%%%02X', string.byte(character))
	end)
end

local function premiumEndpoint()
	local endpoint = type(license) == 'table' and license.PremiumEndpoint or nil
	if (type(endpoint) ~= 'string' or endpoint == '') and getgenv then
		pcall(function() endpoint = getgenv().AetherV2PremiumEndpoint end)
	end
	if type(endpoint) ~= 'string' or endpoint == '' then
		endpoint = shared.AetherV2PremiumEndpoint
	end
	if type(endpoint) ~= 'string' or endpoint == '' then
		endpoint = 'https://aetherv2.onrender.com'
	end
	return endpoint:gsub('/+$', '')
end

local function reportExecution()
	local player = game:GetService('Players').LocalPlayer
	if not player then return end
	local endpoint = premiumEndpoint()..'/analytics/execution'
	local requestFunction = (syn and syn.request) or http_request or request
	if type(requestFunction) == 'function' then
		local http = game:GetService('HttpService')
		local ok = pcall(requestFunction, {
			Url = endpoint,
			Method = 'POST',
			Headers = {['Content-Type'] = 'application/json'},
			Body = http:JSONEncode({userId = tostring(player.UserId), placeId = tostring(game.PlaceId)})
		})
		if ok then return end
	end
	pcall(game.HttpGet, game, endpoint, true)
end
task.spawn(reportExecution)

local function authorizePremium()
	local key = type(license) == 'table' and license.premiumKey or nil
	if type(key) ~= 'string' or key == '' or key == 'KEY_HERE' then return false end
	local player = game:GetService('Players').LocalPlayer
	if not player then return false end
	local endpoint = premiumEndpoint()
	local url = endpoint..'/premium/authorize?key='..premiumEncode(key)
		..'&username='..premiumEncode(player.Name)..'&userId='..premiumEncode(player.UserId)
	local ok, body = pcall(game.HttpGet, game, url, true)
	if not ok or type(body) ~= 'string' then return false end
	local stage = loadstring(body, 'aether-premium-authorize')
	if not stage then return false end
	local ran, session = pcall(stage)
	if not ran or type(session) ~= 'table'
		or type(session.Endpoint) ~= 'string'
		or type(session.Token) ~= 'string'
		or type(session.Ref) ~= 'string' then
		return false
	end
	shared.AetherV2PremiumEndpoint = session.Endpoint
	shared.AetherV2PremiumToken = session.Token
	shared.AetherV2PremiumRef = session.Ref
	shared.AetherV2PremiumFetchSource = function(path)
		return game:HttpGet(session.Endpoint..'/premium/source?path='..premiumEncode(path)
			..'&session='..premiumEncode(session.Token), true)
	end
	shared.AetherV2PremiumFetchTree = function()
		return game:HttpGet(session.Endpoint..'/premium/tree?session='..premiumEncode(session.Token), true)
	end
	shared.AetherV2PremiumAuthorized = true
	return true
end
pcall(authorizePremium)

local function analyticsEndpoint()
	return premiumEndpoint()..'/analytics/execution'
end

task.spawn(function()
	local player = game:GetService('Players').LocalPlayer
	if not player then return end
	local requestFunction = (syn and syn.request) or http_request or request
	if type(requestFunction) ~= 'function' then return end
	local http = game:GetService('HttpService')
	local sessionId = http:GenerateGUID(false):gsub('[^%w%-_]', '')
	local function send(eventName)
		pcall(requestFunction, {
			Url = analyticsEndpoint(),
			Method = 'POST',
			Headers = {['Content-Type'] = 'application/json'},
			Body = http:JSONEncode({
				event = eventName or 'heartbeat',
				sessionId = sessionId,
				username = player.Name,
				userId = tostring(player.UserId),
				placeId = tostring(game.PlaceId),
				access = shared.AetherV2PremiumAuthorized == true and 'premium' or 'free'
			})
		})
	end
	local deadline = os.clock() + 30
	local function running()
		local current = shared.vape
		return type(current) == 'table' and current.Loaded ~= false and current.Uninjecting ~= true
	end
	repeat task.wait(0.5) until running() or os.clock() >= deadline
	if not running() then return end
	while running() do
		send('heartbeat')
		for _ = 1, 10 do
			task.wait(1)
			if not running() then
				send('session_end')
				return
			end
		end
	end
	send('session_end')
end)

local cloneref = cloneref or function(obj)
	return obj
end

local function exists(path)
	local ok, data = pcall(readfile, path)
	return ok and type(data) == 'string' and data ~= ''
end

local function safeAsset(path)
	for _, fn in {getcustomasset, getsynasset} do
		if type(fn) == 'function' then
			local ok, result = pcall(fn, path)
			if ok and type(result) == 'string' and result ~= '' then
				return result
			end
		end
	end
	if type(syn) == 'table' then
		for _, fn in {syn.getcustomasset, syn.getsynasset} do
			if type(fn) == 'function' then
				local ok, result = pcall(fn, path)
				if ok and type(result) == 'string' and result ~= '' then
					return result
				end
			end
		end
	end
	return ''
end

for _, folder in {
	'aetherv2',
	'aetherv2/games',
	'aetherv2/profiles',
	'aetherv2/assets',
	'aetherv2/assets/new',
	'aetherv2/libraries',
	'aetherv2/guis',
	'aetherv2/songs',
	'aetherv2/songs/spotify'
} do
	if not isfolder(folder) then
		pcall(makefolder, folder)
	end
end

-- Per-file cache revisions.
-- GitHub's recursive tree gives each repository blob its SHA. We keep that SHA beside
-- every locally cached file, so an existing file is reused when its remote blob is the
-- same and replaced only when that specific file changed.
local revisionPath = 'aetherv2/profiles/file-revisions.json'
local httpService = game:GetService('HttpService')
local revisions = {}
local remoteFiles = {}
local checkedFiles = {}

local function loadRevisions()
	if not exists(revisionPath) then return end
	local ok, decoded = pcall(function()
		return httpService:JSONDecode(readfile(revisionPath))
	end)
	if ok and type(decoded) == 'table' then
		revisions = decoded
	end
end

local function saveRevisions()
	pcall(function()
		writefile(revisionPath, httpService:JSONEncode(revisions))
	end)
end

local function cachePath(relative)
	return 'aetherv2/'..relative
end

local function isLocalOnly(relative)
	return relative:sub(1, 6) == 'songs/' or relative:sub(1, 8) == 'configs/'
end

local function validDownloadedFile(path, body)
	if type(body) ~= 'string' or #body < 1 then return false end
	local head = body:sub(1, 300):lower()
	if head:find('^%s*404') or head:find('^%s*429') or head:find('^%s*5%d%d:') or head:find('<!doctype html') or head:find('<html') then
		return false
	end
	if path:lower():sub(-4) == '.png' then
		return body:sub(1, 8) == '\137PNG\r\n\26\n'
	end
	return true
end

local function ensureFolder(path)
	local parent = path:gsub('\\', '/'):match('^(.*)/[^/]+$')
	if not parent then return end
	local built = ''
	for segment in parent:gmatch('[^/]+') do
		built = built == '' and segment or built..'/'..segment
		if not isfolder(built) then
			pcall(makefolder, built)
		end
	end
end

local function fetchTree()
	local ok, body = pcall(function()
		return game:HttpGet('https://api.github.com/repos/plutoxqqqq/AetherV2/git/trees/main?recursive=1', true)
	end)
	if not ok or type(body) ~= 'string' then
		return false, 'GitHub tree request failed'
	end
	local decodedOk, decoded = pcall(function()
		return httpService:JSONDecode(body)
	end)
	if not decodedOk or type(decoded) ~= 'table' or type(decoded.tree) ~= 'table' then
		return false, 'GitHub tree response was invalid'
	end
	for _, entry in ipairs(decoded.tree) do
		if type(entry) == 'table' and entry.type == 'blob' and type(entry.path) == 'string' and type(entry.sha) == 'string' then
			remoteFiles[entry.path] = entry.sha
		end
	end
	return true
end

local function downloadCurrent(relative, expectedSha)
	local path = cachePath(relative)
	local ok, body = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/'..relative, true)
	end)
	if not ok or not validDownloadedFile(relative, body) then
		warn('[AetherV2] Failed to update '..relative)
		return false
	end
	if relative:sub(-4) == '.lua' then
		body = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..body
	end
	ensureFolder(path)
	local wrote = pcall(writefile, path, body)
	if not wrote then
		warn('[AetherV2] Failed to write '..path)
		return false
	end
	revisions[relative] = expectedSha
	checkedFiles[relative] = true
	return true
end

local function refreshCachedFiles()
	loadRevisions()
	local ok, err = fetchTree()
	if not ok then
		warn('[AetherV2] File revision check skipped: '..tostring(err))
		return false
	end

	for relative, remoteSha in pairs(remoteFiles) do
		if not isLocalOnly(relative) then
			local path = cachePath(relative)
			if isfile(path) then
				if revisions[relative] == remoteSha then
					checkedFiles[relative] = true
				else
					downloadCurrent(relative, remoteSha)
				end
			end
		end
	end

	return true
end

refreshCachedFiles()

if not exists('aetherv2/assets/new/loading.png') then
	pcall(function()
		local body = game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/assets/new/loading.png', true)
		if type(body) == 'string' and body:sub(1, 8) == '\137PNG\r\n\26\n' then
			writefile('aetherv2/assets/new/loading.png', body)
			if remoteFiles['assets/new/loading.png'] then
				revisions['assets/new/loading.png'] = remoteFiles['assets/new/loading.png']
				checkedFiles['assets/new/loading.png'] = true
			end
		end
	end)
end

local function loadingParent()
	if gethui then
		local ok, gui = pcall(gethui)
		if ok and gui then return gui end
	end
	local ok, gui = pcall(function()
		return cloneref(game:GetService('CoreGui'))
	end)
	return ok and gui or nil
end

local function closeLoadingScreen()
	local screen = _G.AetherV2LoadingScreen
	_G.AetherV2LoadingScreen = nil
	_G.AetherV2CloseLoadingScreen = nil
	_G.AetherV2SetLoadingStatus = nil
	if typeof(screen) == 'Instance' then
		local tweenService = game:GetService('TweenService')
		local fade = TweenInfo.new(0.25)
		for _, object in screen:GetDescendants() do
			if object:IsA('ImageLabel') then
				pcall(function()
					tweenService:Create(object, fade, {ImageTransparency = 1}):Play()
				end)
			elseif object:IsA('Frame') then
				pcall(function()
					tweenService:Create(object, fade, {BackgroundTransparency = 1}):Play()
				end)
			end
		end
		task.delay(0.3, function()
			if screen then
				screen:Destroy()
			end
		end)
	end
end

local skipLoading = license.Closet == true
	or (exists('aetherv2/profiles/disableloading.txt') and readfile('aetherv2/profiles/disableloading.txt') == 'true')

if not skipLoading then
	local parent = loadingParent()
	if parent then
		local old = parent:FindFirstChild('AetherV2Loading')
		if old then old:Destroy() end
		local screen = Instance.new('ScreenGui')
		screen.Name = 'AetherV2Loading'
		screen.IgnoreGuiInset = true
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 2147483647
		screen.Parent = parent

		local scrim = Instance.new('Frame')
		scrim.Name = 'Scrim'
		scrim.Size = UDim2.fromScale(1, 1)
		scrim.BackgroundColor3 = Color3.fromRGB(5, 7, 11)
		scrim.BackgroundTransparency = 0.18
		scrim.BorderSizePixel = 0
		scrim.Parent = screen

		local logo = Instance.new('ImageLabel')
		logo.Name = 'Logo'
		logo.AnchorPoint = Vector2.new(0.5, 0.5)
		logo.Position = UDim2.fromScale(0.5, 0.5)
		logo.Size = UDim2.fromOffset(250, 96)
		logo.BackgroundTransparency = 1
		logo.ScaleType = Enum.ScaleType.Fit
		logo.ImageTransparency = 1
		logo.Parent = scrim
		if exists('aetherv2/assets/new/loading.png') then
			logo.Image = safeAsset('aetherv2/assets/new/loading.png')
		end
		game:GetService('TweenService'):Create(logo, TweenInfo.new(0.4), {ImageTransparency = 0}):Play()

		_G.AetherV2LoadingScreen = screen
		_G.AetherV2CloseLoadingScreen = closeLoadingScreen
		_G.AetherV2SetLoadingStatus = function()
			if logo.Parent and logo.Image == '' and exists('aetherv2/assets/new/loading.png') then
				logo.Image = safeAsset('aetherv2/assets/new/loading.png')
			end
		end
		task.wait()
	end
end

if not exists('aetherv2/main.lua') then
	local ok, body = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/main/main.lua', true)
	end)
	if not ok or type(body) ~= 'string' or body == '404: Not Found' or #body < 20 then
		closeLoadingScreen()
		error('Could not download aetherv2/main.lua')
	end
	writefile('aetherv2/main.lua', body)
	if remoteFiles['main.lua'] then
		revisions['main.lua'] = remoteFiles['main.lua']
		checkedFiles['main.lua'] = true
	end
end

local ok, result = pcall(function()
	return loadstring(readfile('aetherv2/main.lua'), 'main')(license)
end)
if not ok then
	closeLoadingScreen()
	error(result)
end

-- Only write revisions for files we actually verified or successfully updated.
if next(checkedFiles) then
	for relative in pairs(checkedFiles) do
		local remoteSha = remoteFiles[relative]
		if remoteSha then
			revisions[relative] = remoteSha
		end
	end
	saveRevisions()
end

return result
