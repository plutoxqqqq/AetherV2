--!nocheck
local license = ... or {}
local globalenv = (getgenv and getgenv()) or _G
license.Whitelist = globalenv.whitelist or license.Whitelist

local cloneref = cloneref or function(ref) return ref end
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
-- GUI. Self-contained: builds its visuals on the shared AetherV2Loading
-- ScreenGui and wires the _G.AetherV2* globals the loader drives during startup.
local function buildNewerLoadingScreen(screen)
	local tweenService = game:GetService('TweenService')
	local primary = Color3.fromRGB(74, 141, 255)
	local cyan = Color3.fromRGB(96, 226, 214)

	-- Backdrop with a slow diagonal gradient drift.
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

	-- Drifting accent motes for a bit of depth.
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

	-- Card.
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

	-- Spinner: a ring whose gradient arc rotates forever.
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

	-- Wordmark with a slow highlight sweep.
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

	-- Progress track + gradient fill + shimmer sweep.
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

	-- Entrance.
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

local function createLoadingScreen()
	if isLoadingScreenDisabled() then return nil end
	-- Per-GUI loading screens: only 'new' and 'newer' show one at all.
	local gui = selectedGui()
	if gui ~= 'new' and gui ~= 'newer' then return nil end
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

	-- 'newer' gets its own redesigned screen; 'new' keeps the classic one below.
	if gui == 'newer' then
		buildNewerLoadingScreen(screen)
		return screen
	end

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
	
	local versionText = "Unknown"

	if isfile("aetherv2/version.txt") then
    	local data = readfile("aetherv2/version.txt")
    	versionText = data:match("version%s*=%s*([^\r\n]+)") or versionText
	end

	version.Text = "Version " .. versionText
	
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
		if version.Parent and isfile("aetherv2/version.txt") then
			local data = readfile("aetherv2/version.txt")
			local versionText = data:match("version%s*=%s*([^\r\n]+)") or "Unknown"
			version.Text = "Version "..versionText
		end
		if logo.Parent and logo.Image == '' and isfile('aetherv2/assets/new/loading.png') then
			logo.Image = getcustomasset and getcustomasset('aetherv2/assets/new/loading.png') or 'aetherv2/assets/new/loading.png'
		end
	end
	return screen
end

local loadingScreen = createLoadingScreen()
if not _G.AetherV2SetLoadingStatus then
	_G.AetherV2SetLoadingStatus = function() end
end

local function downloadFile(path, func)
	if not isfile(path) then
		if not license.Closet then
			_G.AetherV2SetLoadingStatus('Downloading '..path, 0.35)
		end
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/'..select(1, path:gsub('aetherv2/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
		_G.AetherV2SetLoadingStatus('Downloaded '..path, 0.55)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		local normalized = tostring(file):gsub('\\', '/')
		-- songs is the user's own music, so an update must never touch it - same as profiles/configs.
		if normalized:find('/init%.lua$') or normalized:find('/profiles') or normalized:find('/configs') or normalized:find('/songs') then continue end
		if isfile(file) then
			delfile(file)
		elseif isfolder(file) then
			wipeFolder(file)
		end
	end
end


for _, folder in {'aetherv2', 'aetherv2/games', 'aetherv2/profiles', 'aetherv2/assets', 'aetherv2/assets/new', 'aetherv2/libraries', 'aetherv2/guis', 'aetherv2/configs', 'aetherv2/songs', 'aetherv2/songs/spotify'} do
	if not isfolder(folder) then
		_G.AetherV2SetLoadingStatus('Creating '..folder, 0.18)
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

if not shared.VapeDeveloper then
	local commit = license.Commit or nil
	if not commit then
		local _, subbed = pcall(function()
			return game:HttpGet('https://github.com/plutoxqqqq/AetherV2')
		end)
		commit = subbed:find('currentOid')
		commit = commit and subbed:sub(commit + 13, commit + 52) or nil
		commit = commit and #commit == 40 and commit or 'main'
	end
	local oldCommit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt') or ''
	if oldCommit ~= commit then
		if commit ~= 'main' and oldCommit ~= '' then
			shared.updated = oldCommit
		end
		wipeFolder('aetherv2')
		wipeFolder('aetherv2/games')
		wipeFolder('aetherv2/guis')
		wipeFolder('aetherv2/libraries')
	end
	writefile('aetherv2/profiles/commit.txt', commit)
end

if not isfile('aetherv2/profiles/disableloading.txt') then
	writefile('aetherv2/profiles/disableloading.txt', 'false')
end

_G.AetherV2SetLoadingStatus('Checking version...', 0.62)
downloadFile('aetherv2/version.txt')

local versionData = readfile("aetherv2/version.txt")
local maintenance = versionData:match("maintenance%s*=%s*([^\r\n]+)")

if maintenance and maintenance:match("^%s*true%s*$") then
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

_G.AetherV2SetLoadingStatus('Preparing loading artwork...', 0.70)
pcall(downloadFile, 'aetherv2/assets/new/loading.png')

_G.AetherV2SetLoadingStatus('Loading main script...', 0.82)
return loadstring(downloadFile('aetherv2/main.lua'), 'main')(license)
