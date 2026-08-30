--!nocheck
local license = ... or {}
if type(license) ~= 'table' then license = {} end
shared.AetherV2PremiumAuthorized = false
-- A premium session is valid for one execution only. A previous injection can leave
-- fetch closures/token state behind in shared, so clear every session-derived value
-- before attempting authorization for this execution.
shared.AetherV2PremiumToken = nil
shared.AetherV2PremiumRef = nil
shared.AetherV2PremiumFetchSource = nil
shared.AetherV2PremiumFetchTree = nil

-- A cached Lua file used to be compiled once to validate it and then compiled again moments later
-- to execute it.  The GUI and game chunks are large, so that duplicate parser/codegen work was a
-- noticeable part of every warm start.  Share validated chunks with main.lua for this one load.
local nativeLoadstring = loadstring
local compileCache = {}
shared.AetherCompileCache = compileCache
local watermark = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'
local function compileKey(source)
	return source:sub(1, #watermark) == watermark and source:sub(#watermark + 1) or source
end
local function cachedLoadstring(source, chunkName)
	local key = compileKey(source)
	local cached = compileCache[key]
	if cached then return cached end
	local chunk, err = nativeLoadstring(source, chunkName)
	if chunk then compileCache[key] = chunk end
	return chunk, err
end

-- A Lua file containing only the cache watermark or comments compiles successfully but does
-- nothing. Numeric game modules must contain executable source or Universal appears to be the only
-- file that loaded forever after one interrupted/empty cache write.
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

local cloneref = cloneref or function(ref) return ref end

local localAssetFunctions = {}
local function addLocalAssetFunction(candidate)
	if type(candidate) == 'function' and not table.find(localAssetFunctions, candidate) then
		table.insert(localAssetFunctions, candidate)
	end
end
addLocalAssetFunction(getcustomasset)
addLocalAssetFunction(getsynasset)
local executorEnvironment = getgenv and getgenv() or nil
if type(executorEnvironment) == 'table' then
	addLocalAssetFunction(executorEnvironment.getcustomasset)
	addLocalAssetFunction(executorEnvironment.getsynasset)
end
if type(syn) == 'table' then
	addLocalAssetFunction(syn.getcustomasset)
	addLocalAssetFunction(syn.getsynasset)
end

local function safeLocalAsset(path)
	for _, registerAsset in localAssetFunctions do
		local ok, result = pcall(registerAsset, path)
		if ok and type(result) == 'string' and result ~= '' then return result end
	end
	return ''
end

-- The public loader always runs. A premium key is optional and only creates a short-lived
-- session for the private AetherV2Premium repository when the Render validator accepts it.
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
	if (type(endpoint) ~= 'string' or endpoint == '') then endpoint = shared.AetherV2PremiumEndpoint end
	if type(endpoint) ~= 'string' or endpoint == '' then endpoint = 'https://aetherv2.onrender.com' end
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
	-- Executors without a request API still contribute to execution totals, but no user identity is sent.
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
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end


local function isLoadingScreenDisabled()
	return isfile('aetherv2/profiles/disableloading.txt') and readfile('aetherv2/profiles/disableloading.txt') == 'true'
end

local function getLoadingScreenParent()
	local parent
	if gethui then
		local ok, result = pcall(gethui)
		if ok and result then parent = result end
	end
	if not parent then
		local ok, result = pcall(function()
			return cloneref(game:GetService('CoreGui'))
		end)
		if ok then parent = result end
	end
	return parent
end

-- Which GUI the user has selected (defaults to 'new' before the first pick).
-- Profiles that still name the retired Nexus GUI are migrated to new immediately.
local function selectedGui()
	local ok, res = pcall(readfile, 'aetherv2/profiles/gui.txt')
	if ok and type(res) == 'string' then
		local selected = res:gsub('%s+', '')
		if selected == 'newer' then
			selected = 'new'
			pcall(writefile, 'aetherv2/profiles/gui.txt', selected)
		end
		return selected
	end
	return 'new'
end

-- Legacy Nexus loading-screen builder is unreachable after profile migration. It remains
local function buildNewLoadingScreen(screen)
	local tweenService = game:GetService('TweenService')
	local accent = Color3.fromRGB(190, 115, 255)
	local faint = Color3.fromRGB(224, 218, 244)

	-- Barely there: dark at the very top and bottom, clear through the middle, so the logo and bar
	-- read on a bright map without the screen becoming a wall.
	local scrim = Instance.new('Frame')
	scrim.Name = 'Scrim'
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.fromRGB(5, 7, 11)
	-- Keep the map subdued enough that the logo/status remain readable.  The old
	-- fully transparent scrim made the loading UI disappear on bright maps.
	scrim.BackgroundTransparency = 0.18
	scrim.BorderSizePixel = 0
	scrim.Parent = screen
	local vignette = Instance.new('UIGradient')
	vignette.Rotation = 90
	vignette.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.93),
		NumberSequenceKeypoint.new(1, 0.55)
	})
	vignette.Parent = scrim
	tweenService:Create(scrim, TweenInfo.new(0.18), {BackgroundTransparency = 0.08}):Play()

	-- Edge detail: a hairline along the top and bottom that fades out at both ends.
	for _, edge in {{0, 0, 20}, {1, 1, -20}} do
		local line = Instance.new('Frame')
		line.Name = 'EdgeLine'
		line.AnchorPoint = Vector2.new(0.5, edge[2])
		line.Position = UDim2.new(0.5, 0, edge[1], edge[3])
		line.Size = UDim2.new(1, -160, 0, 1)
		line.BackgroundColor3 = faint
		line.BackgroundTransparency = 0.88
		line.BorderSizePixel = 0
		line.Parent = scrim
		local fade = Instance.new('UIGradient')
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1)
		})
		fade.Parent = line
	end

	-- Edge detail: a bracket in each corner.
	for _, spec in {
		{Vector2.new(0, 0), 30, 30},
		{Vector2.new(1, 0), -30, 30},
		{Vector2.new(0, 1), 30, -30},
		{Vector2.new(1, 1), -30, -30}
	} do
		local anchor, ox, oy = spec[1], spec[2], spec[3]
		local arm = Instance.new('Frame')
		arm.Name = 'Bracket'
		arm.AnchorPoint = anchor
		arm.Position = UDim2.new(anchor.X, ox, anchor.Y, oy)
		arm.Size = UDim2.fromOffset(30, 1)
		arm.BackgroundColor3 = accent
		arm.BackgroundTransparency = 0.8
		arm.BorderSizePixel = 0
		arm.Parent = scrim
		local upright = arm:Clone()
		upright.Size = UDim2.fromOffset(1, 30)
		upright.Parent = scrim
	end

	local logo = Instance.new('ImageLabel')
	logo.Name = 'Logo'
	logo.AnchorPoint = Vector2.new(0.5, 1)
	logo.Position = UDim2.new(0.5, 0, 0.5, -16)
	logo.Size = UDim2.fromOffset(250, 96)
	logo.BackgroundTransparency = 1
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Image = isfile('aetherv2/assets/new/loading.png') and safeLocalAsset('aetherv2/assets/new/loading.png') or ''
	logo.ImageTransparency = 1
	logo.Parent = scrim
	tweenService:Create(logo, TweenInfo.new(0.5), {ImageTransparency = 0}):Play()

	local track = Instance.new('Frame')
	track.Name = 'ProgressTrack'
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0.5, 6)
	track.Size = UDim2.fromOffset(300, 3)
	track.BackgroundColor3 = faint
	track.BackgroundTransparency = 0.85
	track.BorderSizePixel = 0
	track.Parent = scrim
	local trackCorner = Instance.new('UICorner')
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new('Frame')
	fill.Name = 'ProgressFill'
	fill.Size = UDim2.fromScale(0.04, 1)
	fill.BackgroundColor3 = accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new('UICorner')
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	-- Slow shimmer along the fill. This is the "it is still alive" signal during a long step.
	local shimmer = Instance.new('UIGradient')
	shimmer.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accent),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(246, 236, 255)),
		ColorSequenceKeypoint.new(1, accent)
	})
	shimmer.Offset = Vector2.new(-1, 0)
	shimmer.Parent = fill
	-- A finite pass is considerably cheaper than an infinite UI tween on low-end
	-- executors, while progress updates themselves still show that loading is alive.
	tweenService:Create(shimmer, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1, 0)}):Play()

	local caption = Instance.new('TextLabel')
	caption.Name = 'Caption'
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 0.5, 22)
	caption.Size = UDim2.fromOffset(520, 16)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.Gotham
	caption.TextSize = 12
	caption.TextColor3 = faint
	caption.TextTransparency = 0.25
	caption.TextTruncate = Enum.TextTruncate.AtEnd
	caption.Text = 'Starting'
	caption.Parent = scrim

	local function readVersion()
		if not isfile('aetherv2/version.txt') then return nil end
		return (readfile('aetherv2/version.txt'):match('version%s*=%s*([^\r\n]+)'))
	end

	local version = Instance.new('TextLabel')
	version.Name = 'Version'
	version.AnchorPoint = Vector2.new(0.5, 1)
	version.Position = UDim2.new(0.5, 0, 1, -30)
	version.Size = UDim2.fromOffset(300, 14)
	version.BackgroundTransparency = 1
	version.Font = Enum.Font.Gotham
	version.TextSize = 11
	version.TextColor3 = faint
	version.TextTransparency = 0.62
	version.Text = 'AETHERV2  ' .. (readVersion() or '')
	version.Parent = scrim

	local lastProgress = 0.04
	local fillTween

	local function closeScreen()
		if not screen or not screen.Parent then return end
		local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tweenService:Create(scrim, fade, {BackgroundTransparency = 1}):Play()
		for _, object in scrim:GetDescendants() do
			if object:IsA('Frame') then
				tweenService:Create(object, fade, {BackgroundTransparency = 1}):Play()
			elseif object:IsA('TextLabel') then
				tweenService:Create(object, fade, {TextTransparency = 1}):Play()
			elseif object:IsA('ImageLabel') then
				tweenService:Create(object, fade, {ImageTransparency = 1}):Play()
			end
		end
		local closing = screen
		task.delay(0.35, function()
			if closing then
				closing:Destroy()
			end
		end)
	end

	_G.AetherV2LoadingScreen = screen
	_G.AetherV2CloseLoadingScreen = closeScreen
	_G.AetherV2SetLoadingStatus = function(text, progress)
		if not screen.Parent then return end
		-- Only ever forward, so a step that reports a smaller number cannot make the bar jump back.
		lastProgress = math.clamp(progress or lastProgress, lastProgress, 1)
		if caption.Parent then
			caption.Text = (text or 'Loading') .. '   ' .. math.floor(lastProgress * 100) .. '%'
		end
		if fill.Parent then
			if fillTween then
				fillTween:Cancel()
			end
			fillTween = tweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(lastProgress, 1)
			})
			fillTween:Play()
		end
		if version.Parent and version.Text == 'AETHERV2  ' then
			local found = readVersion()
			if found then
				version.Text = 'AETHERV2  ' .. found
			end
		end
		-- The logo is downloaded during the load, so pick it up as soon as it lands.
		if logo.Parent and logo.Image == '' and isfile('aetherv2/assets/new/loading.png') then
			logo.Image = safeLocalAsset('aetherv2/assets/new/loading.png')
		end
	end
	return screen
end

local function createLoadingScreen()
	if license.Closet or isLoadingScreenDisabled() then return nil end
	-- Only the current new GUI uses the Aether loading screen.
	local gui = selectedGui()
	if gui ~= 'new' then return nil end
	local parent = getLoadingScreenParent()
	if not parent then return nil end
	local existing = parent:FindFirstChild('AetherV2Loading')
	if existing and _G.AetherV2SetLoadingStatus then return existing end

	local screen = existing or Instance.new('ScreenGui')
	screen.Name = 'AetherV2Loading'
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 2147483647
	screen.Parent = parent
	screen:ClearAllChildren()

	return buildNewLoadingScreen(screen)
end

local loadingScreen = createLoadingScreen()
-- Yield once so Roblox can render the screen before downloads/requires occupy
-- the loader thread.  Without this, the first visible frame could be the fade-out.
if loadingScreen then task.wait() end
if not _G.AetherV2SetLoadingStatus then
	_G.AetherV2SetLoadingStatus = function() end
end

-- A load that dies here used to leave the loading screen sitting on the user's face forever, with
-- the reason only in the console. Take the screen down and say what happened.
local function failLoad(message)
	table.clear(compileCache)
	shared.AetherCompileCache = nil
	if _G.AetherV2CloseLoadingScreen then
		pcall(_G.AetherV2CloseLoadingScreen)
	elseif _G.AetherV2LoadingScreen then
		pcall(function() _G.AetherV2LoadingScreen:Destroy() end)
	end
	_G.AetherV2LoadingScreen = nil
	_G.AetherV2SetLoadingStatus = nil
	_G.AetherV2CloseLoadingScreen = nil
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

-- Did we get the file, or did GitHub hand us something else? A rate-limit page or a truncated body
-- written to disk is a permanent break: isfile() says the file is there from then on, so every
-- later injection loads the same broken copy and the script "just stops working".
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
	if path:sub(-4) == '.lua' and not cachedLoadstring(body, path) then
		return 'the downloaded file did not compile'
	end
	return nil
end

local function repoUrl(path, ref)
	local selectedRef = ref or shared.AetherV2PublicRef
	if type(selectedRef) ~= 'string' or selectedRef:gsub('%s+', '') == '' then
		local ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
		selectedRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or ''
	end
	if selectedRef == '' then selectedRef = 'main' end
	return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..selectedRef..'/'..select(1, path:gsub('^aetherv2/', ''))
end

local executorRequest = request or http_request
if type(executorRequest) ~= 'function' and type(syn) == 'table' then executorRequest = syn.request end
if type(executorRequest) ~= 'function' and type(http) == 'table' then executorRequest = http.request end

local function publicHttpGet(url, binary)
	if binary and type(executorRequest) == 'function' then
		local ok, response = pcall(executorRequest, {Url = url, Method = 'GET'})
		if ok and type(response) == 'table' then
			local status = tonumber(response.StatusCode or response.Status or response.status_code or 200) or 0
			local body = response.Body or response.body
			if status >= 200 and status < 300 and type(body) == 'string' then return body end
		end
	end
	return game:HttpGet(url, true)
end

-- Fetch with retries, returning the body or nil plus a reason. Most failures here are transient - a
-- dropped connection, a moment of rate limiting - and one of them used to end the whole load.
local function fetchFile(path, ref, attempts)
	attempts = attempts or 3
	local url = repoUrl(path, ref)
	local cleanPath = tostring(path):gsub('^aetherv2/', '')
	local problem
	for attempt = 1, attempts do
		local suc, res = pcall(function()
			return publicHttpGet(url, cleanPath:sub(1, 7) == 'assets/')
		end)
		if suc then
			problem = payloadProblem(path, res)
			if not problem then return res end
		else
			problem = tostring(res)
		end
		if attempt < attempts then
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
		if not isfolder(built) then
			local ok, err = pcall(makefolder, built)
			if not ok and not isfolder(built) then error('Could not create '..built..': '..tostring(err), 0) end
		end
	end
end

local function storeFile(path, body)
	ensureParentFolder(path)
	if path:sub(-4) == '.lua' then body = watermark..body end
	local ok, err = pcall(writefile, path, body)
	if not ok then error('Could not write '..path..': '..tostring(err), 0) end
	local readOk, cached = pcall(readfile, path)
	if not readOk or payloadProblem(path, cached) then error('Cached file verification failed for '..path, 0) end
	return true
end

local function downloadFile(path, func)
	-- Heal a broken cache instead of trusting it forever.
	local exists = isfile(path)
	local cachedProblem = exists and payloadProblem(path, readfile(path)) or nil
	if cachedProblem then
		warn('[AetherV2] Cached '..path..' is unusable ('..cachedProblem..'), downloading it again')
		delfile(path)
		exists = false
	end
	if not exists then
		if not license.Closet then
			_G.AetherV2SetLoadingStatus('Downloading '..path, 0.35)
		end
		local body, problem = fetchFile(path)
		if not body then
			failLoad('Could not download '..path..' - '..tostring(problem))
		end
		storeFile(path, body)
	end
	return (func or readfile)(path)
end

-- Files under profiles/ that come FROM the repository rather than from the user.
--
-- This is the whole reason features.json went stale: profiles/ holds the user's configs, binds, GUI
-- choice and colours, so a wipe skips the entire folder to protect them - and took these two along
-- for the ride. Downloaded once on a fresh install, never updated again, for everyone.
local repoProfileFiles = {
	['aetherv2/profiles/features.json'] = true,
	['aetherv2/profiles/packages.json'] = true
}

local function isUserFile(normalized)
	if normalized:find('/init%.lua$') then return true end
	if normalized:find('/configs') or normalized:find('/songs') then return true end
	if normalized:find('/profiles') then
		-- Everything in profiles/ is the user's, except the couple of files we ship.
		for repoFile in repoProfileFiles do
			if normalized:sub(-#repoFile) == repoFile then return false end
		end
		return true
	end
	return false
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		local normalized = tostring(file):gsub('\\', '/')
		if isUserFile(normalized) then continue end
		if isfile(file) then
			delfile(file)
		elseif isfolder(file) then
			wipeFolder(file)
		end
	end
end


for _, folder in {'aetherv2', 'aetherv2/games', 'aetherv2/profiles', 'aetherv2/assets', 'aetherv2/assets/new', 'aetherv2/assets/old', 'aetherv2/assets/rise', 'aetherv2/assets/wurst', 'aetherv2/libraries', 'aetherv2/guis', 'aetherv2/configs', 'aetherv2/songs', 'aetherv2/songs/spotify'} do
	if not isfolder(folder) then
		_G.AetherV2SetLoadingStatus('Creating '..folder, 0.08)
		makefolder(folder)
	end
end


-- Drop-a-song note, written once. MP3Player reads whatever is in aetherv2/songs, so the folder is
-- no use to anyone who does not know it is there.
if not isfile('aetherv2/songs/read me.txt') then
	pcall(writefile, 'aetherv2/songs/read me.txt', table.concat({
		'AetherV2 - MP3Player',
		'',
		'Put .mp3 (or .wav / .ogg) files in this folder and they show up in the MP3Player module',
		'under Utility. Songs are picked up while you play - no reinject needed.',
		'',
		'aetherv2/songs/spotify holds clips fetched by Spotify mode.',
		'This folder is never wiped by a script update.'
	}, '\n'))
end

-- Which commit are we on?
--
-- This used to download the repository's GitHub LANDING PAGE - 279 KB of HTML - on every single
-- execution, just to read one 40-character hash out of it. The sources below are the same answer for
-- a fraction of the bytes, tried cheapest first: the commits API is ~5 KB, the commit feed ~38 KB,
-- and the old HTML page is kept only as a last resort (the API is rate limited per IP, so it can
-- genuinely be unavailable).
--
-- It also used to read the response without checking whether the request even succeeded: on a failed
-- call the error message was parsed as if it were the page, the match failed, and the commit
-- silently became 'main' - which then looked like an update and wiped the entire install. On a flaky
-- connection that happened on every injection. A lookup that fails now changes nothing at all.
local function resolveCommit()
	local recent = shared.AetherResolvedCommit
	if type(recent) == 'table' and recent.Channel == 'main' and type(recent.Commit) == 'string'
		and os.clock() - (recent.CheckedAt or 0) < 60 then
		return recent.Commit
	end
	local sources = {
		{Url = 'https://api.github.com/repos/plutoxqqqq/AetherV2/commits/main', Pattern = '"sha"%s*:%s*"(%x+)'},
		{Url = 'https://github.com/plutoxqqqq/AetherV2/commits/main.atom', Pattern = 'Commit/(%x+)'},
		{Url = 'https://github.com/plutoxqqqq/AetherV2/tree/main', Pattern = 'currentOid[^%x]*(%x+)'}
	}
	for _, source in sources do
		local suc, body = pcall(game.HttpGet, game, source.Url, true)
		if suc and type(body) == 'string' then
			local found = body:match(source.Pattern)
			if found and #found >= 40 then
				found = found:sub(1, 40)
				shared.AetherResolvedCommit = {Commit = found, Channel = 'main', CheckedAt = os.clock()}
				return found
			end
		end
	end
	return 'main'
end

-- The list of files a commit contains, read straight from git.
--
-- Every entry carries the id of its contents, which changes if and only if that file changed, so
-- comparing this commit's list against the one saved at the last update names exactly the files
-- that went stale - usually a handful - and only those are dropped.
--
-- This used to be a manifest.json committed to the repository and regenerated by CI, which had to
-- be kept in step with the tree by hand and landed in a FOLLOW-UP commit: an install that arrived
-- between the two was handed a list describing a different tree, so it had to be thrown away and
-- the whole install refetched. A commit's own tree cannot fall behind the commit it belongs to,
-- so there is nothing to generate, nothing to commit and nothing to fall out of sync.
--
-- Deliberately forgiving: anything unexpected returns nil and the caller falls back to wiping
-- everything, which is exactly what used to happen anyway.
local function fetchFileList(ref)
	local suc, body = pcall(function()
		return game:HttpGet('https://api.github.com/repos/plutoxqqqq/AetherV2/git/trees/'..ref..'?recursive=1', true)
	end)
	if not suc or type(body) ~= 'string' then return nil end
	-- Only ever set on a repository far larger than this one, but a partial list would silently
	-- leave stale files in place, so it is not worth trusting.
	if body:find('"truncated"%s*:%s*true') then return nil end
	local entries = body:match('"tree"%s*:%s*%[(.*)%]')
	if not entries then return nil end
	local files = {}
	local count = 0
	-- An entry holds no nested objects, so one brace pair is exactly one path.
	for entry in entries:gmatch('{[^{}]*}') do
		if entry:match('"type"%s*:%s*"(%a+)"') == 'blob' then
			local path = entry:match('"path"%s*:%s*"([^"]+)"')
			local blob = entry:match('"sha"%s*:%s*"(%x+)"')
			-- Repository furniture - CI config, build scripts - is never part of an install.
			if path and blob and path:sub(1, 1) ~= '.' and path:sub(1, 6) ~= 'tools/' then
				files[path] = blob
				count += 1
			end
		end
	end
	if count < 8 then return nil end
	return files
end

-- What the last update left on disk, one 'id path' line per file. It lives beside commit.txt
-- because it describes this install rather than the repository.
local fileListPath = 'aetherv2/profiles/files.txt'

local function readFileList()
	if not isfile(fileListPath) then return nil end
	local body = readfile(fileListPath)
	if type(body) ~= 'string' then return nil end
	local files = {}
	local count = 0
	for blob, path in body:gmatch('(%x+) ([^\r\n]+)') do
		files[path] = blob
		count += 1
	end
	if count < 8 then return nil end
	return files
end

local function writeFileList(files)
	local lines = {}
	for path, blob in files do
		table.insert(lines, blob..' '..path)
	end
	table.sort(lines)
	pcall(writefile, fileListPath, table.concat(lines, '\n'))
end

-- Left behind on installs that predate the list above.
if isfile('aetherv2/profiles/manifest.json') then
	delfile('aetherv2/profiles/manifest.json')
end

local prefetchPaths = nil

-- The version this install is on right now, e.g. '3.5'. Read straight off disk, so
-- calling it before the update reports the version being replaced and calling it
-- after reports the one that landed.
local function installedVersion()
	if not isfile('aetherv2/version.txt') then return nil end
	local body = readfile('aetherv2/version.txt')
	if type(body) ~= 'string' then return nil end
	local found = body:match('version%s*=%s*([^\r\n]+)')
	return found and (found:gsub('%s+$', '')) or nil
end

if not shared.VapeDeveloper then
	local oldCommit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt'):gsub('%s+', '') or ''
	_G.AetherV2SetLoadingStatus('Checking for updates', 0.12)
	local commit = license.Commit or resolveCommit() or 'main'
	commit = tostring(commit):gsub('%s+', '')
	if commit == '' then commit = 'main' end
	shared.AetherV2PublicRef = commit

	if commit ~= oldCommit then
		local previousVersion = installedVersion()

		-- Update only what actually changed.
		--
		-- The old behaviour was to delete the whole install and pull all ~2.3 MB back down for any
		-- commit at all, however small. Comparing the new commit's file list against the one saved at
		-- the last update says exactly which files moved - usually a handful - and only those are
		-- dropped. Everything else stays on disk.
		--
		-- Missing either list falls back to the old full wipe, on purpose: with nothing to compare
		-- against, keeping files would mean keeping whatever is stale among them.
		local newFiles = fetchFileList(commit)
		local oldFiles = readFileList()

		-- How many files this update actually replaced. nil means the comparison was not
		-- available and everything was refetched, so there is no honest number to report.
		local changedFiles

		if newFiles and oldFiles then
			local changed = 0
			for path, blob in newFiles do
				local target = 'aetherv2/'..path
				if oldFiles[path] ~= blob and isfile(target) then
					delfile(target)
					changed += 1
				end
			end
			-- Files that no longer exist upstream.
			for path in oldFiles do
				if not newFiles[path] then
					local target = 'aetherv2/'..path
					if isfile(target) and not isUserFile('/'..target) then
						delfile(target)
						changed += 1
					end
				end
			end
			changedFiles = changed
			_G.AetherV2SetLoadingStatus('Updating '..changed..' file'..(changed == 1 and '' or 's'), 0.16)
		else
			wipeFolder('aetherv2')
			wipeFolder('aetherv2/games')
			wipeFolder('aetherv2/guis')
			wipeFolder('aetherv2/libraries')
		end

		-- Only an update the user would actually notice is worth announcing. A first
		-- install has nothing to compare against, and a commit that moved no file this
		-- install carries (a README edit, a change to another game's module) is not an
		-- update to this install at all - both used to fire the notification anyway.
		if oldCommit ~= '' and (changedFiles == nil or changedFiles > 0) then
			shared.updated = {From = previousVersion, Files = changedFiles}
		end

		writefile('aetherv2/profiles/commit.txt', commit)
		if newFiles then
			writeFileList(newFiles)
		elseif isfile(fileListPath) then
			-- Could not read the new list, so the stored one now describes an install that no longer
			-- exists. Drop it: a stale baseline would let a later update skip files that had genuinely
			-- changed. Without one, the next update simply wipes and refetches.
			delfile(fileListPath)
		end
		prefetchPaths = newFiles
	else
		prefetchPaths = readFileList()
		if not prefetchPaths then
			prefetchPaths = fetchFileList(commit)
			if prefetchPaths then writeFileList(prefetchPaths) end
		end
	end
else
	local ok, cached = pcall(readfile, 'aetherv2/profiles/commit.txt')
	shared.AetherV2PublicRef = ok and type(cached) == 'string' and cached:gsub('%s+', '') or 'main'
	if shared.AetherV2PublicRef == '' then shared.AetherV2PublicRef = 'main' end
end

-- main.lua uses this authoritative tree to make an exact supported game mandatory. When the tree
-- endpoint is unavailable it still probes the exact path, but it never guesses by GameId.
shared.AetherV2KnownSourceFiles = prefetchPaths

if not isfile('aetherv2/profiles/disableloading.txt') then
	writefile('aetherv2/profiles/disableloading.txt', 'false')
end

-- Pull every file this session will need, at the same time.
--
-- The GUI downloads its images through getcustomasset, one at a time, synchronously, while it is
-- building itself - around sixty round trips in a row on a fresh install before the menu appears,
-- each one a full request for a file of a few kilobytes. The libraries, universal.lua and the game
-- module are the same story in series. Latency, not bandwidth, is what makes a cold start slow.
--
-- So the whole set is fetched up front through a pool of workers. Everything after this hits a warm
-- cache and returns instantly, and the progress bar can finally show real progress. Nothing here is
-- required to succeed: whatever is missed simply falls through to the old on-demand download.
-- Big libraries only some games ever touch. They are left out of the prefetch on purpose: they are
-- pulled in by the module that needs them, which now runs after the menu is already up, so keeping
-- them off the critical path is worth more than having them early.
local deferredFiles = {
	['libraries/cheatenginelib.lua'] = true,
	['libraries/vm.lua'] = true
}

local function neededFiles(files)
	if not files then return {} end
	local gui = selectedGui()
	local assetFolder = gui
	local place = tostring(game.PlaceId)
	if isfile('aetherv2/profiles/forcegame.txt')
		and readfile('aetherv2/profiles/forcegame.txt') == 'true'
		and isfile('aetherv2/profiles/forcegameid.txt') then
		local forced = readfile('aetherv2/profiles/forcegameid.txt'):match('^%s*(%d+)%s*$')
		place = forced or place
	end
	local wanted = {}
	for path in files do
		local include = false
		-- assets/ is tested FIRST and by prefix, not by extension: the artwork folders hold the odd
		-- .json (a font descriptor) as well as images, and letting the extension rule see those first
		-- pulled another GUI's files down.
		if path:sub(1, 7) == 'assets/' then
			-- Only the selected GUI's artwork, plus the loading logo which is always shown.
			include = path:sub(1, 8 + #assetFolder) == 'assets/'..assetFolder..'/'
				or path == 'assets/new/loading.png'
				or gui == 'old' and (path == 'assets/new/guivape.png' or path == 'assets/new/guiv4.png')
		elseif path:sub(-4) == '.lua' or path:sub(-5) == '.json' or path:sub(-4) == '.txt' then
			-- Only this game's module, never the other twenty-odd.
			if path:sub(1, 6) == 'games/' then
				include = path == 'games/universal.lua' or path == 'games/'..place..'.lua'
			elseif path:sub(1, 5) == 'guis/' then
				include = path == 'guis/'..gui..'.lua' or path == 'guis/'..gui..'.core.lua'
			elseif path:sub(1, 6) == 'tools/' or path:sub(1, 1) == '.' then
				include = false
			elseif path == 'init.lua' then
				-- Loaded straight from GitHub by the user's loadstring; a disk copy is never read.
				include = false
			else
				include = true
			end
		end
		if include and not deferredFiles[path] then
			local target = 'aetherv2/'..path
			local exists = isfile(target)
			if exists then
				local ok, cached = pcall(readfile, target)
				local problem = ok and payloadProblem(target, cached) or 'unreadable cache'
				if problem then
					warn('[AetherV2] Cached '..target..' is unusable ('..problem..'), downloading it again')
					delfile(target)
					exists = false
				end
			end
			if not exists then table.insert(wanted, target) end
		end
	end
	return wanted
end

local function prefetch(files)
	local queue = neededFiles(files)
	local total = #queue
	if total == 0 then return end

	local index, done, active = 0, 0, 0
	local workers = math.min(8, total)
	active = workers
	for _ = 1, workers do
		task.spawn(function()
			while true do
				index += 1
				local path = queue[index]
				if not path then break end
				local body = fetchFile(path, nil, 2)
				if body then
					pcall(storeFile, path, body)
				end
				done += 1
				_G.AetherV2SetLoadingStatus('Downloading files ('..done..'/'..total..')', 0.22 + (0.4 * (done / total)))
			end
			active -= 1
		end)
	end

	-- Bounded: a worker that somehow never returns must not hold the load open.
	local deadline = os.clock() + 90
	repeat task.wait(0.05) until active <= 0 or os.clock() > deadline
end

local function selectedAssetPath(path)
	if type(path) ~= 'string' or path:sub(1, 7) ~= 'assets/' then return false end
	local gui = selectedGui()
	return path:sub(1, 8 + #gui) == 'assets/'..gui..'/'
		or path == 'assets/new/loading.png'
		or gui == 'old' and (path == 'assets/new/guivape.png' or path == 'assets/new/guiv4.png')
end

local function verifySelectedAssets(files)
	if type(files) ~= 'table' then return end
	for repoPath in files do
		if selectedAssetPath(repoPath) then
			local target = 'aetherv2/'..repoPath
			local valid = false
			if isfile(target) then
				local ok, cached = pcall(readfile, target)
				valid = ok and payloadProblem(target, cached) == nil
			end
			if not valid then
				if isfile(target) then delfile(target) end
				local body, problem = fetchFile(target, shared.AetherV2PublicRef, 3)
				if not body then failLoad('Could not download required asset '..repoPath..' - '..tostring(problem)) end
				local stored, storeError = pcall(storeFile, target, body)
				if not stored then failLoad('Could not cache required asset '..repoPath..' - '..tostring(storeError)) end
			end
		end
	end
end

_G.AetherV2SetLoadingStatus('Checking version', 0.18)
downloadFile('aetherv2/version.txt')

-- version.txt is only back on disk now, so this is the first point the version that
-- arrived can be read. main.lua turns the pair into the update notification.
if type(shared.updated) == 'table' then
	shared.updated.To = installedVersion()
end

local versionData = readfile("aetherv2/version.txt")
local maintenance = versionData:match("maintenance%s*=%s*([^\r\n]+)")

if maintenance and maintenance:match("^%s*true%s*$") then
	table.clear(compileCache)
	shared.AetherCompileCache = nil
	local StarterGui = game:GetService("StarterGui")

	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "AetherV2 Unavaliable",
			Text = "AetherV2 is currently under maintenance\nDiscord link copied to clipboard",
			Duration = 8
		})
	end)

	if setclipboard then
		setclipboard("https://discord.gg/aYu5c9v9zv")
	end

	return
end

-- Only worth doing once we know the script is actually going to run.
if not prefetchPaths then prefetchPaths = fetchFileList(shared.AetherV2PublicRef or 'main') end
prefetch(prefetchPaths)
verifySelectedAssets(prefetchPaths)

_G.AetherV2SetLoadingStatus('Preparing loading artwork...', 0.70)
pcall(downloadFile, 'aetherv2/assets/new/loading.png')

-- A rejected/unavailable premium check is deliberately silent: it must never prevent
-- normal AetherV2 from loading.
pcall(authorizePremium)

_G.AetherV2SetLoadingStatus('Loading main script', 0.82)
local mainChunk = cachedLoadstring(downloadFile('aetherv2/main.lua'), 'main')
if not mainChunk then
	-- The cache heal above should have caught this, so if it still will not compile the copy on
	-- GitHub is genuinely broken - say so instead of erroring on a nil call with the screen up.
	failLoad('main.lua did not compile')
end
return mainChunk(license)
