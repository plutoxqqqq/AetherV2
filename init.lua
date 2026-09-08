local license = ... or {}
if type(license) ~= 'table' then license = {} end

local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end
local cloneref = cloneref or function(obj)
	return obj
end

local SOURCE = 'main'

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE..'/'..select(1, path:gsub('aetherv2/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') or file:find('init') then continue end
		if isfile(file) then
			local ok, body = pcall(readfile, file)
			if ok and type(body) == 'string' and (body:find('if canDebug then', 1, true) or select(1, body:find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1) then
				pcall(delfile, file)
			end
		end
	end
end

for _, folder in {'aetherv2', 'aetherv2/games', 'aetherv2/profiles', 'aetherv2/assets', 'aetherv2/libraries', 'aetherv2/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

local disabledLoading = isfile('aetherv2/profiles/disableloading.txt')
	and readfile('aetherv2/profiles/disableloading.txt') == 'true'

local function closeLoading()
	if _G.AetherV2LoadingScreen then
		pcall(function() _G.AetherV2LoadingScreen:Destroy() end)
	end
	_G.AetherV2LoadingScreen = nil
	_G.AetherV2SetLoadingStatus = nil
	_G.AetherV2CloseLoadingScreen = nil
end

local function setStatus(text, progress)
	if type(_G.AetherV2SetLoadingStatusImpl) == 'function' then
		pcall(_G.AetherV2SetLoadingStatusImpl, text, progress)
	end
end

if not disabledLoading and not license.Closet then
	pcall(function()
		local coreGui = cloneref(game:GetService('CoreGui'))
		local players = cloneref(game:GetService('Players'))
		local gui = Instance.new('ScreenGui')
		gui.Name = 'AetherV2LoadingScreen'
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 999999
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		pcall(function()
			gui.Parent = gethui and gethui() or coreGui
		end)
		if not gui.Parent then
			gui.Parent = players.LocalPlayer:WaitForChild('PlayerGui')
		end

		local bg = Instance.new('Frame')
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
		bg.BorderSizePixel = 0
		bg.Parent = gui

		local title = Instance.new('TextLabel')
		title.Size = UDim2.new(1, -40, 0, 36)
		title.Position = UDim2.new(0, 20, 0.46, -40)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 28
		title.TextColor3 = Color3.fromRGB(190, 115, 255)
		title.Text = 'AetherV2'
		title.Parent = bg

		local status = Instance.new('TextLabel')
		status.Size = UDim2.new(1, -40, 0, 22)
		status.Position = UDim2.new(0, 20, 0.46, 4)
		status.BackgroundTransparency = 1
		status.Font = Enum.Font.Gotham
		status.TextSize = 16
		status.TextColor3 = Color3.fromRGB(220, 220, 220)
		status.Text = 'Starting…'
		status.Parent = bg

		local track = Instance.new('Frame')
		track.Size = UDim2.new(0.4, 0, 0, 6)
		track.Position = UDim2.new(0.3, 0, 0.46, 36)
		track.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
		track.BorderSizePixel = 0
		track.Parent = bg
		Instance.new('UICorner', track).CornerRadius = UDim.new(1, 0)

		local bar = Instance.new('Frame')
		bar.Size = UDim2.new(0.04, 0, 1, 0)
		bar.BackgroundColor3 = Color3.fromRGB(190, 115, 255)
		bar.BorderSizePixel = 0
		bar.Parent = track
		Instance.new('UICorner', bar).CornerRadius = UDim.new(1, 0)

		_G.AetherV2LoadingScreen = gui
		_G.AetherV2SetLoadingStatusImpl = function(text, progress)
			status.Text = tostring(text or '')
			if type(progress) == 'number' then
				bar.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
			end
		end
	end)
end

_G.AetherV2SetLoadingStatus = setStatus
_G.AetherV2CloseLoadingScreen = closeLoading
setStatus('Starting…', 0.08)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

for _, stale in {
	'aetherv2/games/6872274481/pack.lua',
	'aetherv2/games/6872274481/Blatant/DamageBoost.lua',
	'aetherv2/games/6872274481/Blatant/DeathAdderAimbot.lua',
	'aetherv2/games/6872274481/Combat/BowAssist.lua',
	'aetherv2/games/6872274481/Combat/HitregAdjuster.lua',
	'aetherv2/games/6872274481/Combat/NoClickDelay.lua',
} do
	if isfile(stale) then
		pcall(delfile, stale)
	end
end

if not shared.VapeDeveloper then
	local cachedVersion = isfile('aetherv2/profiles/version.txt') and readfile('aetherv2/profiles/version.txt') or ''
	local remoteVersion
	pcall(function()
		remoteVersion = game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..SOURCE..'/version.txt', true)
	end)
	if type(remoteVersion) == 'string' then
		remoteVersion = remoteVersion:gsub('%s+$', '')
		if remoteVersion:find('^%s*<!doctype html') or remoteVersion == '404: Not Found' then
			remoteVersion = nil
		end
	else
		remoteVersion = nil
	end

	if remoteVersion and cachedVersion:gsub('%s+', '') ~= remoteVersion:gsub('%s+', '') then
		setStatus('Updating…', 0.14)
		wipeFolder('aetherv2')
		wipeFolder('aetherv2/games')
		wipeFolder('aetherv2/guis')
		wipeFolder('aetherv2/libraries')
		pcall(delfile, 'aetherv2/main.lua')
		pcall(delfile, 'aetherv2/games/universal/pack.lua')
		pcall(delfile, 'aetherv2/games/6872274481/pack.lua')
		pcall(delfile, 'aetherv2/games/6872265039/pack.lua')
	end

	if remoteVersion then
		writefile('aetherv2/profiles/version.txt', remoteVersion)
	end
	writefile('aetherv2/profiles/commit.txt', SOURCE)
	shared.AetherV2PublicRef = SOURCE
end

if isfile('aetherv2/main.lua') then
	local cachedMain = readfile('aetherv2/main.lua')
	if not cachedMain:find('loadPackedFast', 1, true) then
		delfile('aetherv2/main.lua')
	end
end

setStatus('Loading…', 0.22)
return loadstring(downloadFile('aetherv2/main.lua'), 'main')(license)
