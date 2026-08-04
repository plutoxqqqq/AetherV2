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
local loadstring = function(...)
	local res, err = compile(...)
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
	local primary = Color3.fromRGB(190, 115, 255)
	local cyan = Color3.fromRGB(226, 186, 255)

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

-- Loading screen for the 'new' GUI: fullscreen, transparent and minimal.
--
-- Nothing but the logo in the middle of the screen, a thin bar under it, one line of text, and a
-- light frame of detail around the edges - a vignette that keeps the middle of the screen clear, a
-- hairline top and bottom, and a bracket in each corner. The bar is tweened rather than snapped and
-- carries a slow shimmer, so a long step still visibly moves instead of looking frozen.
--
-- Kept in sync with the copy in the other loader file.
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
	scrim.BackgroundTransparency = 1
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
	tweenService:Create(scrim, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play()

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
	logo.Image = isfile('aetherv2/assets/new/loading.png') and getcustomasset('aetherv2/assets/new/loading.png') or ''
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
	tweenService:Create(shimmer, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.3), {Offset = Vector2.new(1, 0)}):Play()

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
			logo.Image = getcustomasset('aetherv2/assets/new/loading.png')
		end
	end
	return screen
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

	return buildNewLoadingScreen(screen)
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

-- A load that dies silently is indistinguishable from one that never started, and that is most of
-- what "the script just doesn't work" turns out to be. Every fatal path goes through here: the
-- screen comes down so nothing is left frozen on it, the reason goes to the console AND to a Roblox
-- notification so the user can actually report it, and only then does it raise.
local function failLoad(message)
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
	if path:sub(-4) == '.lua' and not compile(body, path) then
		return 'the downloaded file did not compile'
	end
	return nil
end

-- Fetch with retries. A single failed request used to end the whole load; most of them are
-- transient (a dropped connection, a moment of rate limiting) and succeed on the next try.
local function fetchFile(path, attempts)
	attempts = attempts or 3
	local url = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/'..select(1, path:gsub('aetherv2/', ''))
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
	if isfile(path) and path:sub(-4) == '.lua' and not compile(readfile(path), path) then
		warn('[AetherV2] Cached '..path..' is unusable, downloading it again')
		delfile(path)
	end
	if not isfile(path) then
		setPhaseProgress('Downloading '..path, 0.15)
		local body, problem = fetchFile(path)
		if not body then
			failLoad('Could not download '..path..' - '..tostring(problem))
		end
		if path:sub(-4) == '.lua' then
			body = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..body
		end
		writefile(path, body)
		setPhaseProgress('Downloaded '..path, 0.75)
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
-- This is the other half of the "stuck at 88%" fix. Game modules run during the load, and a module
-- that waits on something the game never provides used to take the whole load down with it: no
-- menu, no error, just a percentage that never moved. Now the loader watches instead of blocking -
-- the status text counts the seconds, so it is visibly alive - and if a chunk outstays its welcome
-- we build the menu without it. The chunk is not killed; if it does finish later, its modules are
-- added and their saved settings re-applied.
local function runWatchedChunk(source, chunkName, label, timeout, optional, ...)
	local chunk = compile(source, chunkName)
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

local function finishLoading()
	setPhase('Finalizing', 0.97, 0.99)
	vape.Init = nil
	local loaded, loadError = xpcall(function()
		vape:Load()
	end, debug.traceback)
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
		if #loadingWarnings > 0 then
			vape:CreateNotification('AetherV2', 'Loaded with non-critical game module warnings. Check the console for details.', 10, 'info')
			warn(table.concat(loadingWarnings, '\n'))
		end
	end

	setLoadingStatus('Finished loading', 1)
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
-- Songs live here for MP3Player. Created from main as well as init, so loading the script directly
-- (without init) still leaves somewhere to put music.
for _, folder in {'aetherv2/songs', 'aetherv2/songs/spotify'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
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
	-- Watched rather than waited on, and generous: universal is where every game-independent module
	-- is registered, so it is worth a long leash - but not an unlimited one.
	runWatchedChunk(downloadFile('aetherv2/games/universal.lua'), 'universal', 'Loading universal modules', 30, false, license)

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
	if isfile(placePath) then
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
		runWatchedChunk(placeSource, modulePlace, 'Loading module for this game', 15, true, license)
	end
	finishLoading()
else
	vape.Init = finishLoading
	setLoadingStatus('Ready for independent initialization', 1)
	return vape
end
