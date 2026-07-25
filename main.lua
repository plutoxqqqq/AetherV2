local license = ... or {}
local globalenv = (getgenv and getgenv()) or _G
license.Whitelist = globalenv.whitelist or license.Whitelist
local acceptedWhitelistKey = '1234-5678-9012-3456'

local function isWhitelisted()
	return tostring(globalenv.whitelist or license.Whitelist or '') == acceptedWhitelistKey
end
repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local vape
local compile = loadstring
local loadstring = function(...)
	local res, err = compile(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
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
-- Loading screens are per-GUI: 'new' and 'newer' each get their own design and
-- 'old' / 'rise' get none.
local function selectedGui()
	local ok, res = pcall(readfile, 'aetherv2/profiles/gui.txt')
	if ok and type(res) == 'string' then
		return (res:gsub('%s+', ''))
	end
	return 'new'
end

-- Redesigned "Nexus" loading screen - used only when newer.lua is the active
-- GUI. Kept in sync with the copy in init.lua (init builds the screen first;
-- this is the fallback path). Self-contained + wires the _G.AetherV2* globals.
local function buildNewerLoadingScreen(screen)
	local tweenService = game:GetService('TweenService')
	local primary = Color3.fromRGB(74, 141, 255)
	local cyan = Color3.fromRGB(96, 226, 214)

	local background = Instance.new('Frame')
	background.Name = 'Backdrop'
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(9, 11, 17)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.Parent = screen
	local bgGrad = Instance.new('UIGradient')
	bgGrad.Rotation = 20
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(9, 12, 20)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 24, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 11, 17))
	})
	bgGrad.Parent = background
	tweenService:Create(bgGrad, TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Rotation = 48}):Play()

	for i = 1, 8 do
		local mote = Instance.new('Frame')
		mote.Size = UDim2.fromOffset(4, 4)
		mote.Position = UDim2.fromScale(math.random(4, 96) / 100, math.random(15, 100) / 100)
		mote.BackgroundColor3 = i % 2 == 0 and cyan or primary
		mote.BackgroundTransparency = 0.55
		mote.BorderSizePixel = 0
		mote.Parent = background
		local mc = Instance.new('UICorner')
		mc.CornerRadius = UDim.new(1, 0)
		mc.Parent = mote
		task.spawn(function()
			while mote.Parent do
				local dur = 4 + math.random() * 4
				tweenService:Create(mote, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Position = UDim2.fromScale(math.random(4, 96) / 100, math.random(8, 92) / 100),
					BackgroundTransparency = 0.25 + math.random() * 0.5
				}):Play()
				task.wait(dur)
			end
		end)
	end

	local card = Instance.new('Frame')
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(560, 300)
	card.BackgroundColor3 = Color3.fromRGB(13, 16, 26)
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.Parent = background
	local cardCorner = Instance.new('UICorner')
	cardCorner.CornerRadius = UDim.new(0, 20)
	cardCorner.Parent = card
	local cardStroke = Instance.new('UIStroke')
	cardStroke.Color = primary
	cardStroke.Transparency = 0.5
	cardStroke.Thickness = 1.5
	cardStroke.Parent = card
	local cardGrad = Instance.new('UIGradient')
	cardGrad.Rotation = 90
	cardGrad.Color = ColorSequence.new(primary, cyan)
	cardGrad.Parent = cardStroke
	local cardScale = Instance.new('UIScale')
	cardScale.Scale = 0.94
	cardScale.Parent = card

	local ring = Instance.new('Frame')
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Position = UDim2.new(0.5, 0, 0, 36)
	ring.Size = UDim2.fromOffset(54, 54)
	ring.BackgroundTransparency = 1
	ring.Parent = card
	local ringCorner = Instance.new('UICorner')
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring
	local ringStroke = Instance.new('UIStroke')
	ringStroke.Thickness = 3
	ringStroke.Color = primary
	ringStroke.Parent = ring
	local ringGrad = Instance.new('UIGradient')
	ringGrad.Color = ColorSequence.new(cyan, primary)
	ringGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.05),
		NumberSequenceKeypoint.new(1, 1)
	})
	ringGrad.Parent = ringStroke
	tweenService:Create(ringGrad, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Rotation = 360}):Play()

	local title = Instance.new('TextLabel')
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 104)
	title.Size = UDim2.fromOffset(420, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = 'AETHER V2'
	title.TextSize = 34
	title.TextColor3 = Color3.fromRGB(240, 244, 255)
	title.Parent = card
	local titleGrad = Instance.new('UIGradient')
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(236, 240, 255)),
		ColorSequenceKeypoint.new(0.5, cyan),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 240, 255))
	})
	titleGrad.Parent = title
	titleGrad.Offset = Vector2.new(-1, 0)
	tweenService:Create(titleGrad, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.6), {Offset = Vector2.new(1, 0)}):Play()

	local versionText = 'Unknown'
	if isfile('aetherv2/version.txt') then
		local data = readfile('aetherv2/version.txt')
		versionText = data:match('version%s*=%s*([^\r\n]+)') or versionText
	end
	local version = Instance.new('TextLabel')
	version.AnchorPoint = Vector2.new(0.5, 0)
	version.Position = UDim2.new(0.5, 0, 0, 148)
	version.Size = UDim2.fromOffset(300, 18)
	version.BackgroundTransparency = 1
	version.Font = Enum.Font.GothamMedium
	version.Text = 'NEXUS  •  Version '..versionText
	version.TextSize = 12
	version.TextColor3 = Color3.fromRGB(150, 160, 190)
	version.Parent = card

	local track = Instance.new('Frame')
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 206)
	track.Size = UDim2.fromOffset(460, 8)
	track.BackgroundColor3 = Color3.fromRGB(26, 32, 48)
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.Parent = card
	local trackCorner = Instance.new('UICorner')
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track
	local fill = Instance.new('Frame')
	fill.Size = UDim2.fromScale(0.04, 1)
	fill.BackgroundColor3 = primary
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new('UICorner')
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local fillGrad = Instance.new('UIGradient')
	fillGrad.Color = ColorSequence.new(primary, cyan)
	fillGrad.Parent = fill
	local shimmer = Instance.new('Frame')
	shimmer.Size = UDim2.fromScale(1, 1)
	shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shimmer.BackgroundTransparency = 0
	shimmer.BorderSizePixel = 0
	shimmer.Parent = fill
	local shimmerCorner = Instance.new('UICorner')
	shimmerCorner.CornerRadius = UDim.new(1, 0)
	shimmerCorner.Parent = shimmer
	local shimGrad = Instance.new('UIGradient')
	shimGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1)
	})
	shimGrad.Offset = Vector2.new(-1, 0)
	shimGrad.Parent = shimmer
	tweenService:Create(shimGrad, TweenInfo.new(1.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Offset = Vector2.new(1, 0)}):Play()

	local status = Instance.new('TextLabel')
	status.AnchorPoint = Vector2.new(0, 0)
	status.Position = UDim2.new(0.5, -230, 0, 224)
	status.Size = UDim2.fromOffset(340, 18)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = 'Starting AetherV2...'
	status.TextSize = 13
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(202, 210, 230)
	status.Parent = card
	local percent = Instance.new('TextLabel')
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.new(0.5, 230, 0, 224)
	percent.Size = UDim2.fromOffset(80, 18)
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.GothamBold
	percent.Text = '6%'
	percent.TextSize = 13
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.TextColor3 = cyan
	percent.Parent = card
	local footer = Instance.new('TextLabel')
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -16)
	footer.Size = UDim2.fromOffset(400, 16)
	footer.BackgroundTransparency = 1
	footer.Font = Enum.Font.Gotham
	footer.Text = 'discord.gg/aetherv2'
	footer.TextSize = 11
	footer.TextColor3 = Color3.fromRGB(96, 104, 130)
	footer.Parent = card

	tweenService:Create(background, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.05}):Play()
	tweenService:Create(cardScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

	local lastProgress = 0.06
	local closed = false
	local function closeScreen()
		if closed then return end
		closed = true
		if not screen or not screen.Parent then
			if screen then pcall(function() screen:Destroy() end) end
			return
		end
		tweenService:Create(background, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
		tweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.92}):Play()
		task.delay(0.4, function()
			if screen and screen.Parent then screen:Destroy() end
		end)
	end

	_G.AetherV2LoadingScreen = screen
	_G.AetherV2CloseLoadingScreen = closeScreen
	_G.AetherV2SetLoadingStatus = function(text, progress)
		if not screen.Parent then return end
		lastProgress = math.clamp(progress or lastProgress, lastProgress, 1)
		if status.Parent and text then status.Text = text end
		if percent.Parent then percent.Text = math.floor(lastProgress * 100)..'%' end
		if fill.Parent then
			tweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(math.clamp(lastProgress, 0.02, 1), 1)
			}):Play()
		end
	end
end

local function createInlineLoadingScreen()
	if isLoadingScreenDisabled() then return nil end
	-- Per-GUI loading screens: only 'new' and 'newer' show one at all.
	local gui = selectedGui()
	if gui ~= 'new' and gui ~= 'newer' then return nil end
	local parent = getLoadingScreenParent()
	if not parent then return nil end
	local existing = parent:FindFirstChild('AetherV2Loading')
	if existing and _G.AetherV2SetLoadingStatus then return existing end
	if gui == 'newer' then
		local screen = existing or Instance.new('ScreenGui')
		screen.Name = 'AetherV2Loading'
		screen.IgnoreGuiInset = true
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 2147483647
		screen.Parent = parent
		screen:ClearAllChildren()
		buildNewerLoadingScreen(screen)
		return screen
	end

	local screen = existing or Instance.new('ScreenGui')
	screen.Name = 'AetherV2Loading'
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 2147483647
	screen.Parent = parent
	screen:ClearAllChildren()

	local background = Instance.new('Frame')
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(8, 9, 14)
	background.BackgroundTransparency = 0.18
	background.BorderSizePixel = 0
	background.Parent = screen

	local gradient = Instance.new('UIGradient')
	gradient.Rotation = 25
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 10, 18)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 22, 34)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 9, 14))
	})
	gradient.Parent = background

	local card = Instance.new('Frame')
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(540, 330)
	card.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = background
	local cardCorner = Instance.new('UICorner')
	cardCorner.CornerRadius = UDim.new(0, 18)
	cardCorner.Parent = card
	local stroke = Instance.new('UIStroke')
	stroke.Color = Color3.fromRGB(90, 230, 210)
	stroke.Transparency = 0.74
	stroke.Thickness = 1
	stroke.Parent = card

	local glow = Instance.new('Frame')
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(430, 3)
	glow.BackgroundColor3 = Color3.fromRGB(90, 230, 210)
	glow.BackgroundTransparency = 0.68
	glow.BorderSizePixel = 0
	glow.Parent = card
	local glowCorner = Instance.new('UICorner')
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	local logo = Instance.new('ImageLabel')
	logo.Name = 'Logo'
	logo.AnchorPoint = Vector2.new(0.5, 0)
	logo.Position = UDim2.new(0.5, 0, 0, 28)
	logo.Size = UDim2.fromOffset(250, 108)
	logo.BackgroundTransparency = 1
	logo.ImageTransparency = 0.02
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Image = isfile('aetherv2/assets/new/loading.png') and (getcustomasset and getcustomasset('aetherv2/assets/new/loading.png') or 'aetherv2/assets/new/loading.png') or ''
	logo.Parent = card

	local version = Instance.new('TextLabel')
	version.Name = 'Version'
	version.AnchorPoint = Vector2.new(0.5, 0)
	version.Position = UDim2.new(0.5, 0, 0, 142)
	version.Size = UDim2.fromOffset(260, 22)
	version.BackgroundTransparency = 1
	version.Font = Enum.Font.GothamMedium
	version.TextSize = 14
	version.TextColor3 = Color3.fromRGB(190, 196, 220)
	version.Text = isfile('aetherv2/version.txt') and ('Version '..readfile('aetherv2/version.txt')) or 'Version loading...'
	version.Parent = card

	local status = Instance.new('TextLabel')
	status.Name = 'Status'
	status.Position = UDim2.fromOffset(54, 202)
	status.Size = UDim2.fromOffset(432, 22)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 14
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(235, 238, 255)
	status.Text = 'Starting AetherV2...'
	status.Parent = card

	local track = Instance.new('Frame')
	track.Name = 'ProgressTrack'
	track.Position = UDim2.fromOffset(54, 238)
	track.Size = UDim2.fromOffset(432, 10)
	track.BackgroundColor3 = Color3.fromRGB(28, 34, 50)
	track.BackgroundTransparency = 0.18
	track.BorderSizePixel = 0
	track.Parent = card
	local trackCorner = Instance.new('UICorner')
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new('Frame')
	fill.Name = 'ProgressFill'
	fill.Size = UDim2.fromScale(0.06, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 210)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new('UICorner')
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local detail = Instance.new('TextLabel')
	detail.Name = 'Detail'
	detail.Position = UDim2.fromOffset(54, 260)
	detail.Size = UDim2.fromOffset(432, 20)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 12
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = Color3.fromRGB(130, 142, 170)
	detail.Text = 'Preparing files and assets.'
	detail.Parent = card

	local lastProgress = 0.06
	local function closeScreen()
		if screen and screen.Parent then
			screen:Destroy()
		end
	end
	_G.AetherV2LoadingScreen = screen
	_G.AetherV2CloseLoadingScreen = closeScreen
	_G.AetherV2SetLoadingStatus = function(text, progress)
		if not screen.Parent then return end
		lastProgress = math.clamp(progress or lastProgress, lastProgress, 1)
		if status.Parent then status.Text = text end
		if detail.Parent then detail.Text = math.floor(lastProgress * 100)..'% complete' end
		if fill.Parent then fill.Size = UDim2.fromScale(lastProgress, 1) end
		if version.Parent and isfile('aetherv2/version.txt') then version.Text = 'Version '..readfile('aetherv2/version.txt') end
		if logo.Parent and logo.Image == '' and isfile('aetherv2/assets/new/loading.png') then
			logo.Image = getcustomasset and getcustomasset('aetherv2/assets/new/loading.png') or 'aetherv2/assets/new/loading.png'
		end
	end
	return screen
end

local closeLoadingScreen

local function setLoadingStatus(text, progress)
	if isLoadingScreenDisabled() then
		closeLoadingScreen()
		return
	end
	createInlineLoadingScreen()
	if _G.AetherV2SetLoadingStatus then
		pcall(_G.AetherV2SetLoadingStatus, text, progress)
	end
end

closeLoadingScreen = function()
	-- Prefer the screen's own closer so the redesigned (newer) screen can fade
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

local function downloadFile(path, func)
	if not isfile(path) then
		setLoadingStatus('Downloading '..path, 0.60)
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/'..select(1, path:gsub('aetherv2/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			closeLoadingScreen()
			error(res)
		end
		if suc then
			if path:find('.lua') then
				res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
			end
			writefile(path, res)
			setLoadingStatus('Downloaded '..path, 0.72)
		end
	end
	return (func or readfile)(path)
end

local function downloadOptionalFile(path)
	if isfile(path) then return true end
	local suc, res = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/'..select(1, path:gsub('aetherv2/', '')), true)
	end)
	if not suc or res == '404: Not Found' then return false end
	writefile(path, res)
	return true
end


local loadingWarnings = {}

local function runLoadingChunk(source, chunkName, ...)
	local chunk = loadstring(source, chunkName)
	if not chunk then
		closeLoadingScreen()
		error('Failed to compile '..chunkName)
	end
	local args = {...}
	local ok, result = xpcall(function()
		return chunk(table.unpack(args))
	end, debug.traceback)
	if not ok then
		closeLoadingScreen()
		error(result)
	end
	return result
end

local function runOptionalLoadingChunk(source, chunkName, ...)
	local chunk = loadstring(source, chunkName)
	if not chunk then
		table.insert(loadingWarnings, 'Failed to compile '..chunkName)
		return nil
	end
	local args = {...}
	local ok, result = xpcall(function()
		return chunk(table.unpack(args))
	end, debug.traceback)
	if not ok then
		table.insert(loadingWarnings, result)
		return nil
	end
	return result
end

local function finishLoading()
	setLoadingStatus('Finalizing...', 0.94)
	vape.Init = nil
	local loaded, loadError = xpcall(function()
		vape:Load()
	end, debug.traceback)
	if not loaded then
		closeLoadingScreen()
		error(loadError)
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
			task.delay(1, function()
				if shared.updated then
					vape:CreateNotification('AetherV2', `Script has updated from {shared.updated} to {readfile('aetherv2/profiles/commit.txt')}`, 10, 'info')
				end
			end)
		end
		if #loadingWarnings > 0 then
			vape:CreateNotification('AetherV2', 'Loaded with non-critical game module warnings. Check the console for details.', 10, 'info')
			warn(table.concat(loadingWarnings, '\n'))
		end
	end

	setLoadingStatus('Finished Loading!', 1)
	task.delay(2, closeLoadingScreen)
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
setLoadingStatus('Preparing loading artwork...', 0.82)
downloadOptionalFile('aetherv2/assets/new/loading.png')
setLoadingStatus('Loading interface...', 0.84)
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
	setLoadingStatus('Loading universal modules...', 0.88)
	runLoadingChunk(downloadFile('aetherv2/games/universal.lua'), 'universal', license)
	if isfile('aetherv2/games/'..game.PlaceId..'.lua') then
		runOptionalLoadingChunk(readfile('aetherv2/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId), license)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				runOptionalLoadingChunk(downloadFile('aetherv2/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId), license)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	setLoadingStatus('Ready for independent initialization.', 1)
	return vape
end
