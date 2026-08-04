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
	local primary = Color3.fromRGB(190, 115, 255)
	local cyan = Color3.fromRGB(226, 186, 255)

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
			logo.Image = getcustomasset('aetherv2/assets/new/loading.png')
		end
	end
	return screen
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

	-- 'newer' keeps its own screen; 'new' uses the minimal fullscreen one.
	if gui == 'newer' then
		buildNewerLoadingScreen(screen)
		return screen
	end

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
	if path:sub(-4) == '.lua' and not loadstring(body, path) then
		return 'the downloaded file did not compile'
	end
	return nil
end

local function repoUrl(path, ref)
	return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..(ref or readfile('aetherv2/profiles/commit.txt'))..'/'..select(1, path:gsub('aetherv2/', ''))
end

-- Fetch with retries, returning the body or nil plus a reason. Most failures here are transient - a
-- dropped connection, a moment of rate limiting - and one of them used to end the whole load.
local function fetchFile(path, ref, attempts)
	attempts = attempts or 3
	local url = repoUrl(path, ref)
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
			task.wait(attempt)
		end
	end
	return nil, problem
end

local function storeFile(path, body)
	if path:sub(-4) == '.lua' then
		body = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..body
	end
	writefile(path, body)
end

local function downloadFile(path, func)
	-- Heal a broken cache instead of trusting it forever.
	if isfile(path) and path:sub(-4) == '.lua' and not loadstring(readfile(path), path) then
		warn('[AetherV2] Cached '..path..' is unusable, downloading it again')
		delfile(path)
	end
	if not isfile(path) then
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


for _, folder in {'aetherv2', 'aetherv2/games', 'aetherv2/profiles', 'aetherv2/assets', 'aetherv2/assets/new', 'aetherv2/libraries', 'aetherv2/guis', 'aetherv2/configs', 'aetherv2/songs', 'aetherv2/songs/spotify'} do
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
	local sources = {
		{Url = 'https://api.github.com/repos/plutoxqqqq/AetherV2/commits/main', Pattern = '"sha"%s*:%s*"(%x+)"'},
		{Url = 'https://github.com/plutoxqqqq/AetherV2/commits/main.atom', Pattern = 'Commit/(%x+)'},
		{Url = 'https://github.com/plutoxqqqq/AetherV2', Pattern = 'currentOid[^%x]*(%x+)'}
	}
	for _, source in sources do
		local suc, body = pcall(function()
			return game:HttpGet(source.Url, true)
		end)
		if suc and type(body) == 'string' then
			local found = body:match(source.Pattern)
			if found and #found >= 40 then
				return found:sub(1, 40)
			end
		end
	end
	return nil
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
	local oldCommit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt') or ''
	_G.AetherV2SetLoadingStatus('Checking for updates', 0.12)
	local commit = license.Commit or resolveCommit()

	if commit and commit ~= oldCommit then
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
	elseif oldCommit == '' then
		-- First run with no answer from GitHub: fall back to main rather than having no ref at all.
		writefile('aetherv2/profiles/commit.txt', commit or 'main')
	else
		-- Up to date. The stored list is this commit's file list, so it can drive the prefetch below
		-- without another request.
		prefetchPaths = readFileList()
		if not prefetchPaths then
			-- Nothing stored yet: an install from before this list existed, or one whose last update
			-- could not fetch it. Fetch it now, so the prefetch has something to work from and the
			-- next update can be incremental instead of wiping.
			prefetchPaths = fetchFileList(oldCommit)
			if prefetchPaths then
				writeFileList(prefetchPaths)
			end
		end
	end
end

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
			include = path:sub(1, 8 + #gui) == 'assets/'..gui..'/' or path == 'assets/new/loading.png'
		elseif path:sub(-4) == '.lua' or path:sub(-5) == '.json' or path:sub(-4) == '.txt' then
			-- Only this game's module, never the other twenty-odd.
			if path:sub(1, 6) == 'games/' then
				include = path == 'games/universal.lua' or path == 'games/'..place..'.lua'
			elseif path:sub(1, 5) == 'guis/' then
				include = path == 'guis/'..gui..'.lua'
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
			if not isfile(target) then
				table.insert(wanted, target)
			end
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
prefetch(prefetchPaths)

_G.AetherV2SetLoadingStatus('Preparing loading artwork...', 0.70)
pcall(downloadFile, 'aetherv2/assets/new/loading.png')

_G.AetherV2SetLoadingStatus('Loading main script', 0.82)
local mainChunk = loadstring(downloadFile('aetherv2/main.lua'), 'main')
if not mainChunk then
	-- The cache heal above should have caught this, so if it still will not compile the copy on
	-- GitHub is genuinely broken - say so instead of erroring on a nil call with the screen up.
	failLoad('main.lua did not compile')
end
return mainChunk(license)
