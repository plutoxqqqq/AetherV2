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
	local accent = Color3.fromRGB(120, 235, 215)
	local faint = Color3.fromRGB(214, 224, 244)

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
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 255, 252)),
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
		local url = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/'..select(1, path:gsub('aetherv2/', ''))
		local body, problem
		-- Most failures here are transient - a dropped connection, a moment of rate limiting - and
		-- one of them used to end the whole load.
		for attempt = 1, 3 do
			local suc, res = pcall(function()
				return game:HttpGet(url, true)
			end)
			if suc then
				problem = payloadProblem(path, res)
				if not problem then
					body = res
					break
				end
			else
				problem = tostring(res)
			end
			if attempt < 3 then
				if not license.Closet then
					_G.AetherV2SetLoadingStatus('Retrying '..path..' ('..attempt..'/3)', 0.35)
				end
				task.wait(attempt)
			end
		end
		if not body then
			failLoad('Could not download '..path..' - '..tostring(problem))
		end
		if path:sub(-4) == '.lua' then
			body = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..body
		end
		writefile(path, body)
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
	local oldCommit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt') or ''
	local commit = license.Commit or nil
	if not commit then
		-- Resolve the newest commit, and be strict about what counts as an answer.
		--
		-- This used to read the response without checking whether the request even succeeded: on a
		-- failed call `subbed` is the error message, the match fails, and the commit silently became
		-- 'main'. That is not harmless - the block below then sees a different commit, wipes the
		-- whole install and re-downloads every file. On a flaky connection that happened on every
		-- single injection, which is most of what "it takes forever" and "it got stuck downloading"
		-- actually was. A lookup that fails now changes nothing at all.
		for attempt = 1, 3 do
			local suc, page = pcall(function()
				return game:HttpGet('https://github.com/plutoxqqqq/AetherV2')
			end)
			if suc and type(page) == 'string' then
				local at = page:find('currentOid')
				local found = at and page:sub(at + 13, at + 52) or nil
				if found and #found == 40 and found:match('^%x+$') then
					commit = found
					break
				end
			end
			if attempt < 3 then
				task.wait(attempt)
			end
		end
	end

	if commit and commit ~= oldCommit then
		-- Only a real, resolved commit is allowed to wipe the cache.
		if oldCommit ~= '' then
			shared.updated = oldCommit
		end
		wipeFolder('aetherv2')
		wipeFolder('aetherv2/games')
		wipeFolder('aetherv2/guis')
		wipeFolder('aetherv2/libraries')
		writefile('aetherv2/profiles/commit.txt', commit)
	elseif oldCommit == '' then
		-- First run with no answer from GitHub: fall back to main rather than having no ref at all.
		writefile('aetherv2/profiles/commit.txt', commit or 'main')
	end
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

_G.AetherV2SetLoadingStatus('Loading main script', 0.82)
local mainChunk = loadstring(downloadFile('aetherv2/main.lua'), 'main')
if not mainChunk then
	-- The cache heal above should have caught this, so if it still will not compile the copy on
	-- GitHub is genuinely broken - say so instead of erroring on a nil call with the screen up.
	failLoad('main.lua did not compile')
end
return mainChunk(license)
