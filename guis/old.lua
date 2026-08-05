-- AetherV2's accent, rgb(190, 115, 255), as the HSV the GUI works in. It is the
-- default theme colour and stays changeable from the colour slider in settings.
local accent = {Hue = 0.7559524, Sat = 0.5490196, Value = 1}
local mainapi = {
	Categories = {},
	GUIColor = {
		Hue = accent.Hue,
		Sat = accent.Sat,
		Value = accent.Value
	},
	HeldKeybinds = {},
	Keybind = {'RightShift'},
	Loaded = false,
	Legit = {Modules = {}},
	Libraries = {},
	Modules = {},
	Place = game.PlaceId,
	Profile = 'default',
	Profiles = {},
	RainbowSpeed = {Value = 1},
	RainbowUpdateSpeed = {Value = 60},
	RainbowTable = {},
	Scale = {Value = 1},
	ToggleNotifications = {},
	ThreadFix = setthreadidentity and true or false,
	Version = '4.04',
	Windows = {}
}

local cloneref = cloneref or function(obj)
	return obj
end
local tweenService = cloneref(game:GetService('TweenService'))
local inputService = cloneref(game:GetService('UserInputService'))
local textService = cloneref(game:GetService('TextService'))
local guiService = cloneref(game:GetService('GuiService'))
local runService = cloneref(game:GetService('RunService'))
local httpService = cloneref(game:GetService('HttpService'))

local fontsize = Instance.new('GetTextBoundsParams')
fontsize.Width = math.huge
local notifications
local assetfunction = getcustomasset
local getcustomasset
local clickgui
local scaledgui
local tooltip
local scale
local gui

local color = {}
local tween = {
	tweens = {},
	tweenstwo = {}
}
local uipallet = {
	Main = Color3.fromRGB(30, 30, 30),
	Text = Color3.new(1, 1, 1),
	Font = Font.fromEnum(Enum.Font.Arial),
	FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold),
	Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear)
}

local getcustomassets = {
	['aetherv2/assets/old/barlogo.png'] = 'rbxasset://barlogo.png',
	['aetherv2/assets/old/blatanticon.png'] = 'rbxasset://blatanticon.png',
	['aetherv2/assets/old/checkbox.png'] = 'rbxasset://checkbox.png',
	['aetherv2/assets/old/combaticon.png'] = 'rbxasset://combaticon.png',
	['aetherv2/assets/old/friendsicon.png'] = 'rbxasset://friendsicon.png',
	['aetherv2/assets/old/guiicon.png'] = 'rbxasset://guiicon.png',
	['aetherv2/assets/old/info.png'] = 'rbxasset://info.png',
	['aetherv2/assets/old/pin.png'] = 'rbxasset://pin.png',
	['aetherv2/assets/old/profilesicon.png'] = 'rbxasset://profilesicon.png',
	['aetherv2/assets/old/rendericon.png'] = 'rbxasset://rendericon.png',
	['aetherv2/assets/old/search.png'] = 'rbxasset://search.png',
	['aetherv2/assets/old/settingsicon.png'] = 'rbxasset://settingsicon.png',
	['aetherv2/assets/old/targetinfoicon.png'] = 'rbxasset://targetinfoicon.png',
	['aetherv2/assets/old/textguiicon.png'] = 'rbxasset://textguiicon.png',
	['aetherv2/assets/old/textv4.png'] = 'rbxasset://textv4.png',
	['aetherv2/assets/old/textvape.png'] = 'rbxasset://textvape.png',
	['aetherv2/assets/old/utilityicon.png'] = 'rbxasset://utilityicon.png',
	['aetherv2/assets/old/vape.png'] = 'rbxassetid://14373395239',
	['aetherv2/assets/old/worldicon.png'] = 'rbxasset://worldicon.png'
}

local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

--[[
	Retiring the old accent.

	The default accent moved to rgb(190, 115, 255), but changing a default only ever decided
	what a *fresh* install starts on. Every existing install already had the old teal
	rgb(5, 133, 104) written into its config - the GUI accent, and every module colour option
	that had never been touched - and a saved value always beats a default, so the menu kept
	opening teal and the change looked like it had never happened.

	So the retired colour is rewritten on load, once. The stamp records which accent an
	install has been through; while it does not match, a saved colour that is still *exactly*
	the retired default is replaced, and anything the user actually chose is left alone. Once
	the pass has run the stamp is written and no saved colour is touched again, so picking
	teal back off the palette sticks.

	Hung off one table rather than a handful of locals, here and for the preset registry and
	the profile reset below: the main chunk of a GUI file is a single function, and Luau
	allows a function 200 locals.
]]
local configapi = {}
configapi.Accents = {
	Path = 'aetherv2/profiles/accent.txt',
	Stamp = table.concat({
		math.round(accent.Hue * 1000),
		math.round(accent.Sat * 1000),
		math.round(accent.Value * 1000)
	}, ','),
	Retired = {Hue = 0.46, Sat = 0.96, Value = 0.52, Notch = 4}
}
configapi.Accents.Done = isfile(configapi.Accents.Path) and (function()
	local suc, res = pcall(readfile, configapi.Accents.Path)
	return suc and type(res) == 'string' and res:gsub('%s+', '') == configapi.Accents.Stamp
end)() or false
-- Stamped once the first load has settled rather than the moment the first colour is
-- rewritten: game modules register after the menu is already up and their options are read
-- in a later pass, so the migration has to stay live for the whole session it runs in.
configapi.Accents.Stamped = configapi.Accents.Done

function configapi.Accents.Mark()
	if configapi.Accents.Stamped then return end
	configapi.Accents.Stamped = true
	pcall(writefile, configapi.Accents.Path, configapi.Accents.Stamp)
end

-- Was this saved colour left on the retired default, or did the user choose it? Rainbow and
-- custom colours are always the user's, and so is any preset notch other than the one the
-- old default sat on.
function configapi.Accents.IsRetired(saved)
	local retired = configapi.Accents.Retired
	if type(saved) ~= 'table' or saved.Rainbow or saved.CustomColor then return false end
	if saved.Notch and saved.Notch ~= retired.Notch then return false end
	if type(saved.Hue) ~= 'number' or type(saved.Sat) ~= 'number' or type(saved.Value) ~= 'number' then
		return saved.Notch == retired.Notch
	end
	return math.abs(saved.Hue - retired.Hue) < 0.02
		and math.abs(saved.Sat - retired.Sat) < 0.02
		and math.abs(saved.Value - retired.Value) < 0.02
end

-- Does this option actually default to the accent? One that ships a default of its own (a
-- white nametag, a black background) is never migrated; one that names the accent
-- explicitly, as the GUI colour slider does, still is.
function configapi.Accents.Defaulted(optionsettings)
	return (optionsettings.DefaultHue or accent.Hue) == accent.Hue
		and (optionsettings.DefaultSat or accent.Sat) == accent.Sat
		and (optionsettings.DefaultValue or accent.Value) == accent.Value
end

-- `defaulted` says whether the option in question takes its default from the accent at all.
function configapi.Accents.Apply(saved, defaulted)
	if configapi.Accents.Done or defaulted == false or not configapi.Accents.IsRetired(saved) then return saved end
	local migrated = table.clone(saved)
	migrated.Hue, migrated.Sat, migrated.Value = accent.Hue, accent.Sat, accent.Value
	if migrated.Notch then
		migrated.Notch = accent.Notch
	end
	return migrated
end

local getfontsize = function(text, size, font)
	fontsize.Text = text
	fontsize.Size = size
	if typeof(font) == 'Font' then
		fontsize.Font = font
	end
	return textService:GetTextBoundsAsync(fontsize)
end

local function addCorner(parent, radius)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = radius or UDim.new(0, 5)
	corner.Parent = parent

	return corner
end

local function addMaid(object)
	object.Connections = {}
	function object:Clean(callback)
		if typeof(callback) == 'Instance' then
			table.insert(self.Connections, {
				Disconnect = function()
					callback:ClearAllChildren()
					callback:Destroy()
				end
			})
		elseif type(callback) == 'function' then
			table.insert(self.Connections, {
				Disconnect = callback
			})
		else
			table.insert(self.Connections, callback)
		end
	end
end

local function addTooltip(gui, text)
	if not text then return end

	local function tooltipMoved(x, y)
		local right = x + 16 + tooltip.Size.X.Offset > (scale.Scale * 1920)
		tooltip.Position = UDim2.fromOffset((right and x - (tooltip.Size.X.Offset * scale.Scale) - 16 or x + 16) / scale.Scale, ((y + 11) - (tooltip.Size.Y.Offset / 2)) / scale.Scale)
		tooltip.Visible = true
	end

	gui.MouseEnter:Connect(function(x, y)
		local tooltipSize = getfontsize(text, tooltip.TextSize, uipallet.Font)
		tooltip.Size = UDim2.fromOffset(tooltipSize.X + 10, tooltipSize.Y + 6)
		tooltip.Text = text
		tooltipMoved(x, y)
	end)
	gui.MouseMoved:Connect(tooltipMoved)
	gui.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
end

local function checkKeybinds(compare, target, key)
	if type(target) == 'table' then
		if table.find(target, key) then
			for i, v in target do
				if not table.find(compare, v) then
					return false
				end
			end
			return true
		end
	end

	return false
end

local function createDownloader(text)
	if mainapi.Loaded ~= true then
		local downloader = mainapi.Downloader
		if not downloader then
			downloader = Instance.new('TextLabel')
			downloader.Size = UDim2.new(1, 0, 0, 40)
			downloader.BackgroundTransparency = 1
			downloader.TextStrokeTransparency = 0
			downloader.TextSize = 20
			downloader.TextColor3 = Color3.new(1, 1, 1)
			downloader.FontFace = uipallet.Font
			downloader.Parent = mainapi.gui
			mainapi.Downloader = downloader
		end
		downloader.Text = 'Downloading '..text
	end
end

local function createMobileButton(buttonapi, position)
	local heldbutton = false
	local button = Instance.new('TextButton')
	button.Size = UDim2.fromOffset(40, 40)
	button.Position = UDim2.fromOffset(position.X, position.Y)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = buttonapi.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
	button.Text = buttonapi.Name
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.FontFace = uipallet.Font
	button.Parent = mainapi.gui
	local buttonconstraint = Instance.new('UITextSizeConstraint')
	buttonconstraint.MaxTextSize = 16
	buttonconstraint.Parent = button

	button.MouseButton1Down:Connect(function()
		heldbutton = true
		local holdtime, holdpos = tick(), inputService:GetMouseLocation()
		repeat
			heldbutton = (inputService:GetMouseLocation() - holdpos).Magnitude < 6
			task.wait()
		until (tick() - holdtime) > 1 or not heldbutton
		if heldbutton then
			buttonapi.Bind = {}
			button:Destroy()
		end
	end)
	button.MouseButton1Up:Connect(function()
		heldbutton = false
	end)
	button.MouseButton1Click:Connect(function()
		buttonapi:Toggle()
		button.BackgroundColor3 = buttonapi.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
	end)

	buttonapi.Bind = {Button = button}
end

local function downloadFile(path, func)
	if not isfile(path) then
		createDownloader(path)
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
	end
	return (func or readfile)(path)
end

getcustomasset = not inputService.TouchEnabled and assetfunction and function(path)
	return downloadFile(path, assetfunction)
end or function(path)
	return getcustomassets[path] or ''
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function loopClean(tab)
	for i, v in tab do
		if type(v) == 'table' then
			loopClean(v)
		end
		tab[i] = nil
	end
end

local function loadJson(path)
	local suc, res = pcall(function()
		return httpService:JSONDecode(readfile(path))
	end)
	return suc and type(res) == 'table' and res or nil
end

local function makeDraggable(gui, window)
	gui.InputBegan:Connect(function(inputObj)
		if window and not window.Visible then return end
		if
			(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
			and (inputObj.Position.Y - gui.AbsolutePosition.Y < 40 or window)
		then
			local dragPosition = Vector2.new(gui.AbsolutePosition.X - inputObj.Position.X, gui.AbsolutePosition.Y - inputObj.Position.Y + guiService:GetGuiInset().Y) / scale.Scale
			local changed = inputService.InputChanged:Connect(function(input)
				if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
					local position = input.Position
					if inputService:IsKeyDown(Enum.KeyCode.LeftShift) then
						dragPosition = (dragPosition // 3) * 3
						position = (position // 3) * 3
					end
					gui.Position = UDim2.fromOffset((position.X / scale.Scale) + dragPosition.X, (position.Y / scale.Scale) + dragPosition.Y)
				end
			end)

			local ended
			ended = inputObj.Changed:Connect(function()
				if inputObj.UserInputState == Enum.UserInputState.End then
					if changed then
						changed:Disconnect()
					end
					if ended then
						ended:Disconnect()
					end
				end
			end)
		end
	end)
end

local function randomString()
	local array = {}
	for i = 1, math.random(10, 100) do
		array[i] = string.char(math.random(32, 126))
	end
	return table.concat(array)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return str:gsub('<[^<>]->', '')
end

do
	local res = isfile('aetherv2/profiles/color.txt') and loadJson('aetherv2/profiles/color.txt')
	if res then
		uipallet.Main = res.Main and Color3.fromRGB(unpack(res.Main)) or uipallet.Main
		uipallet.Text = res.Text and Color3.fromRGB(unpack(res.Text)) or uipallet.Text
		uipallet.Font = res.Font and Font.new(
			res.Font:find('rbxasset') and res.Font or string.format('rbxasset://fonts/families/%s.json', res.Font)
		) or uipallet.Font
		uipallet.FontSemiBold = Font.new(uipallet.Font.Family, Enum.FontWeight.SemiBold)
	end
	fontsize.Font = uipallet.Font
end

do
	function color.Dark(col, num)
		local h, s, v = col:ToHSV()
		return Color3.fromHSV(h, s, math.clamp(select(3, uipallet.Main:ToHSV()) > 0.5 and v + num or v - num, 0, 1))
	end

	function color.Light(col, num)
		local h, s, v = col:ToHSV()
		return Color3.fromHSV(h, s, math.clamp(select(3, uipallet.Main:ToHSV()) > 0.5 and v - num or v + num, 0, 1))
	end

	function mainapi:Color(h)
		local s = 0.75 + (0.15 * math.min(h / 0.03, 1))
		if h > 0.57 then
			s = 0.9 - (0.4 * math.min((h - 0.57) / 0.09, 1))
		end
		if h > 0.66 then
			s = 0.5 + (0.4 * math.min((h - 0.66) / 0.16, 1))
		end
		if h > 0.87 then
			s = 0.9 - (0.15 * math.min((h - 0.87) / 0.13, 1))
		end
		return h, s, 1
	end

	function mainapi:TextColor(h, s, v, col)
		if v < 0.7 then
			return Color3.new(1, 1, 1)
		end
		if s < 0.6 or h > 0.04 and h < 0.56 then
			return col or color.Light(uipallet.Main, 0.14)
		end
		return Color3.new(1, 1, 1)
	end
end

do
	function tween:Tween(obj, tweeninfo, goal, tab)
		tab = tab or self.tweens
		if tab[obj] then
			tab[obj]:Cancel()
			tab[obj] = nil
		end

		if obj.Parent and obj.Visible then
			tab[obj] = tweenService:Create(obj, tweeninfo, goal)
			tab[obj].Completed:Once(function()
				if tab then
					tab[obj] = nil
					tab = nil
				end
			end)
			tab[obj]:Play()
		else
			for i, v in goal do
				obj[i] = v
			end
		end
	end

	function tween:Cancel(obj)
		if self.tweens[obj] then
			self.tweens[obj]:Cancel()
			self.tweens[obj] = nil
		end
	end
end

mainapi.Libraries = {
	color = color,
	getcustomasset = getcustomasset,
	getfontsize = getfontsize,
	tween = tween,
	uipallet = uipallet,
}

local components
components = {
	Button = function(optionsettings, children, api)
		local button = Instance.new('TextButton')
		button.Name = optionsettings.Name..'Button'
		button.Size = UDim2.new(1, api.Category and -8 or 0, 0, 26)
		button.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		button.BackgroundTransparency = api.Category and 0 or 1
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Visible = optionsettings.Visible == nil or optionsettings.Visible
		button.Text = ''
		button.Parent = children
		addTooltip(button, optionsettings.Tooltip)
		local bkg = Instance.new('Frame')
		bkg.Size = UDim2.new(1, -10, 0, 18)
		bkg.Position = UDim2.fromOffset(5, 4)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.1)
		bkg.BorderSizePixel = 0
		bkg.Parent = button
		local label = Instance.new('TextLabel')
		label.Size = UDim2.new(1, -4, 1, -4)
		label.Position = UDim2.fromOffset(2, 2)
		label.BackgroundTransparency = 1
		label.Text = optionsettings.Name
		label.TextColor3 = uipallet.Text
		label.TextSize = 14
		label.FontFace = uipallet.Font
		label.Parent = bkg
		optionsettings.Function = optionsettings.Function or function() end
		
		button.MouseButton1Click:Connect(optionsettings.Function)
	end,
	ColorSlider = function(optionsettings, children, api)
		local optionapi = {
			Type = 'ColorSlider',
			-- Colour options default to the AetherV2 accent, the same colour the GUI
			-- theme starts on, so a module's boxes/chams/HUD match the menu out of the
			-- box. Each slider still moves independently once the user touches it.
			Hue = optionsettings.DefaultHue or accent.Hue,
			Sat = optionsettings.DefaultSat or accent.Sat,
			Value = optionsettings.DefaultValue or accent.Value,
			Opacity = optionsettings.DefaultOpacity or 1,
			Rainbow = false,
			Index = 0
		}
		
		local function createSlider(name, gradientColor)
			local slider = Instance.new('TextButton')
			slider.Name = optionsettings.Name..'Slider'..name
			slider.Size = UDim2.new(1, api.Category and -8 or 0, 0, 34)
			slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
			slider.BackgroundTransparency = api.Category and 0 or 1
			slider.BorderSizePixel = 0
			slider.AutoButtonColor = false
			slider.Visible = false
			slider.Text = ''
			slider.Parent = children
			local title = Instance.new('TextLabel')
			title.Name = 'Title'
			title.Size = UDim2.new(1, 0, 0, 15)
			title.BackgroundTransparency = 1
			title.Text = name
			title.TextColor3 = uipallet.Text
			title.TextSize = 13
			title.FontFace = uipallet.Font
			title.Parent = slider
			local bkg = Instance.new('Frame')
			bkg.Name = 'Slider'
			bkg.Size = UDim2.new(1, -10, 0, 12)
			bkg.Position = UDim2.fromOffset(5, 16)
			bkg.BackgroundColor3 = Color3.new(1, 1, 1)
			bkg.BorderSizePixel = 0
			bkg.Parent = slider
			local gradient = Instance.new('UIGradient')
			gradient.Color = gradientColor
			gradient.Parent = bkg
			local fill = bkg:Clone()
			fill.Name = 'Fill'
			fill.Size = UDim2.fromScale(math.clamp(name == 'Saturation' and optionapi.Sat or name == 'Vibrance' and optionapi.Value or optionapi.Opacity, 0, 0.99), 1)
			fill.Position = UDim2.new()
			fill.BackgroundTransparency = 1
			fill.Parent = bkg
			local knob = Instance.new('Frame')
			knob.Name = 'Knob'
			knob.Size = UDim2.fromOffset(3, 12)
			knob.Position = UDim2.fromScale(1, 0.5)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.BackgroundColor3 = slider.BackgroundColor3
			knob.BackgroundTransparency = 0.5
			knob.BorderSizePixel = 0
			knob.Parent = fill
		
			slider.InputBegan:Connect(function(inputObj)
				if
					(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
					and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (16 * scale.Scale)
				then
					local changed = inputService.InputChanged:Connect(function(input)
						if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
							optionapi:SetValue(nil, name == 'Saturation' and math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1) or nil, name == 'Vibrance' and math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1) or nil, name == 'Opacity' and math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1) or nil)
						end
					end)
		
					local ended
					ended = inputObj.Changed:Connect(function()
						if inputObj.UserInputState == Enum.UserInputState.End then
							if changed then changed:Disconnect() end
							if ended then ended:Disconnect() end
						end
					end)
				end
			end)
		
			return slider
		end
		
		local slider = Instance.new('TextButton')
		slider.Name = optionsettings.Name..'Slider'
		slider.Size = UDim2.new(1, api.Category and -8 or 0, 0, 34)
		slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		slider.BackgroundTransparency = api.Category and 0 or 1
		slider.BorderSizePixel = 0
		slider.AutoButtonColor = false
		slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
		slider.Text = ''
		slider.Parent = children
		addTooltip(slider, optionsettings.Tooltip)
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, 0, 0, 15)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = slider
		local valuebox = Instance.new('TextBox')
		valuebox.Name = 'Box'
		valuebox.Size = UDim2.fromOffset(60, 15)
		valuebox.Position = UDim2.new(1, -69, 0, 9)
		valuebox.BackgroundTransparency = 1
		valuebox.Visible = false
		valuebox.Text = ''
		valuebox.TextXAlignment = Enum.TextXAlignment.Right
		valuebox.TextColor3 = color.Dark(uipallet.Text, 0.16)
		valuebox.TextSize = 11
		valuebox.FontFace = uipallet.Font
		valuebox.ClearTextOnFocus = true
		valuebox.Parent = slider
		local bkg = Instance.new('Frame')
		bkg.Name = 'Slider'
		bkg.Size = UDim2.new(1, -10, 0, 12)
		bkg.Position = UDim2.fromOffset(5, 16)
		bkg.BackgroundColor3 = Color3.new(1, 1, 1)
		bkg.BorderSizePixel = 0
		bkg.Parent = slider
		local rainbowTable = {}
		for i = 0, 1, 0.1 do
			table.insert(rainbowTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
		end
		local gradient = Instance.new('UIGradient')
		gradient.Color = ColorSequence.new(rainbowTable)
		gradient.Parent = bkg
		local fill = bkg:Clone()
		fill.Name = 'Fill'
		fill.Size = UDim2.fromScale(math.clamp(optionapi.Hue, 0, 0.99), 1)
		fill.Position = UDim2.new()
		fill.BackgroundTransparency = 1
		fill.Parent = bkg
		local expandbutton = Instance.new('TextButton')
		expandbutton.Name = 'Expand'
		expandbutton.Size = UDim2.fromOffset(17, 13)
		expandbutton.Position = UDim2.new(0, textService:GetTextSize(title.Text, title.TextSize, title.Font, Vector2.new(1000, 1000)).X + 11, 0, 7)
		expandbutton.BackgroundTransparency = 1
		expandbutton.Text = ''
		expandbutton.Parent = slider
		local expand = Instance.new('ImageLabel')
		expand.Name = 'Expand'
		expand.Size = UDim2.fromOffset(9, 5)
		expand.Position = UDim2.fromOffset(4, 4)
		expand.BackgroundTransparency = 1
		expand.Image = getcustomasset('aetherv2/assets/new/expandicon.png')
		expand.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		expand.Parent = expandbutton
		local rainbow = Instance.new('TextButton')
		rainbow.Name = 'Rainbow'
		rainbow.Size = UDim2.fromOffset(12, 12)
		rainbow.Position = UDim2.new(1, -42, 0, 10)
		rainbow.BackgroundTransparency = 1
		rainbow.Text = ''
		rainbow.Parent = slider
		local knob = Instance.new('Frame')
		knob.Name = 'Knob'
		knob.Size = UDim2.fromOffset(3, 12)
		knob.Position = UDim2.fromScale(1, 0.5)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = slider.BackgroundColor3
		knob.BackgroundTransparency = 0.5
		knob.BorderSizePixel = 0
		knob.Parent = fill
		optionsettings.Function = optionsettings.Function or function() end
		local satSlider = createSlider('Saturation', ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, optionapi.Value)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, 1, optionapi.Value))
		}))
		local vibSlider = createSlider('Vibrance', ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, optionapi.Sat, 1))
		}))
		local opSlider = createSlider('Opacity', ColorSequence.new({
			ColorSequenceKeypoint.new(0, color.Dark(uipallet.Main, 0.02)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, optionapi.Sat, optionapi.Value))
		}))
		
		function optionapi:Save(tab)
			tab[optionsettings.Name] = {
				Hue = self.Hue,
				Sat = self.Sat,
				Value = self.Value,
				Opacity = self.Opacity,
				Rainbow = self.Rainbow
			}
		end
		
		function optionapi:Load(tab)
			-- A colour saved back when the accent was teal and never touched since is
			-- brought forward to the current accent, once per install.
			tab = configapi.Accents.Apply(tab, configapi.Accents.Defaulted(optionsettings))
			if tab.Rainbow ~= self.Rainbow then
				self:Toggle()
			end
			if self.Hue ~= tab.Hue or self.Sat ~= tab.Sat or self.Value ~= tab.Value or self.Opacity ~= tab.Opacity then
				self:SetValue(tab.Hue, tab.Sat, tab.Value, tab.Opacity)
			end
		end
		
		function optionapi:SetValue(h, s, v, o)
			self.Hue = h or self.Hue
			self.Sat = s or self.Sat
			self.Value = v or self.Value
			self.Opacity = o or self.Opacity
			satSlider.Slider.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, self.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, 1, self.Value))
			})
			vibSlider.Slider.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, 1))
			})
			opSlider.Slider.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, color.Dark(uipallet.Main, 0.02)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, self.Value))
			})
		
			if self.Rainbow then
				fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0, 0.99), 1)
			else
				tween:Tween(fill, uipallet.Tween, {Size = UDim2.fromScale(math.clamp(self.Hue, 0, 0.99), 1)})
			end
		
			if s then
				tween:Tween(satSlider.Slider.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Sat, 0, 0.99), 1)
				})
			end
			if v then
				tween:Tween(vibSlider.Slider.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Value, 0, 0.99), 1)
				})
			end
			if o then
				tween:Tween(opSlider.Slider.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Opacity, 0, 0.99), 1)
				})
			end
			optionsettings.Function(self.Hue, self.Sat, self.Value, self.Opacity)
		end
		
		function optionapi:Toggle()
			self.Rainbow = not self.Rainbow
			if self.Rainbow then
				table.insert(mainapi.RainbowTable, self)
			else
				local ind = table.find(mainapi.RainbowTable, self)
				if ind then
					table.remove(mainapi.RainbowTable, ind)
				end
			end
		end
		
		local doubleClick = tick()
		slider.InputBegan:Connect(function(inputObj)
			if
				(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
				and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (16 * scale.Scale)
			then
				if doubleClick > tick() then optionapi:Toggle() end
				doubleClick = tick() + 0.3
				local changed = inputService.InputChanged:Connect(function(input)
					if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
						optionapi:SetValue(math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1))
					end
				end)
		
				local ended
				ended = inputObj.Changed:Connect(function()
					if inputObj.UserInputState == Enum.UserInputState.End then
						if changed then
							changed:Disconnect()
						end
						if ended then
							ended:Disconnect()
						end
					end
				end)
			end
		end)
		slider:GetPropertyChangedSignal('Visible'):Connect(function()
			satSlider.Visible = expand.Rotation == 180 and slider.Visible
			vibSlider.Visible = satSlider.Visible
			opSlider.Visible = satSlider.Visible
		end)
		expandbutton.MouseEnter:Connect(function()
			expand.ImageColor3 = color.Dark(uipallet.Text, 0.16)
		end)
		expandbutton.MouseLeave:Connect(function()
			expand.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		end)
		expandbutton.MouseButton1Click:Connect(function()
			satSlider.Visible = not satSlider.Visible
			vibSlider.Visible = satSlider.Visible
			opSlider.Visible = satSlider.Visible
			expand.Rotation = satSlider.Visible and 180 or 0
		end)
		valuebox.FocusLost:Connect(function(enter)
			valuebox.Visible = false
			if enter then
				local commas = valuebox.Text:split(',')
				local suc, res = pcall(function()
					return tonumber(commas[1]) and Color3.fromRGB(tonumber(commas[1]), tonumber(commas[2]), tonumber(commas[3])) or Color3.fromHex(valuebox.Text)
				end)
		
				if suc then
					if optionapi.Rainbow then
						optionapi:Toggle()
					end
					optionapi:SetValue(res:ToHSV())
				end
			end
		end)
		
		optionapi.Object = slider
		api.Options[optionsettings.Name] = optionapi
		
		return optionapi
	end,
	Dropdown = function(optionsettings, children, api)
		local optionapi = {
			Type = 'Dropdown',
			Value = optionsettings.List[1] or 'None',
			Index = 0
		}
		
		local dropdown = Instance.new('TextButton')
		dropdown.Name = optionsettings.Name..'Dropdown'
		dropdown.Size = UDim2.new(1, api.Category and -8 or 0, 0, 37)
		dropdown.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		dropdown.BackgroundTransparency = api.Category and 0 or 1
		dropdown.BorderSizePixel = 0
		dropdown.AutoButtonColor = false
		dropdown.Visible = optionsettings.Visible == nil or optionsettings.Visible
		dropdown.Text = ''
		dropdown.Parent = children
		addTooltip(dropdown, optionsettings.Tooltip or optionsettings.Name)
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, 0, 0, 15)
		title.Position = UDim2.fromOffset(0, 0)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = dropdown
		local bkg = Instance.new('Frame')
		bkg.Name = 'BKG'
		bkg.Size = UDim2.new(1, -12, 1, -17)
		bkg.Position = UDim2.fromOffset(6, 16)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		bkg.BorderSizePixel = 0
		bkg.Parent = dropdown
		local button = Instance.new('TextButton')
		button.Name = 'Dropdown'
		button.Size = UDim2.new(1, -2, 1, -2)
		button.Position = UDim2.fromOffset(1, 1)
		button.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = ''
		button.Parent = bkg
		local valuelabel = Instance.new('TextLabel')
		valuelabel.Name = 'Title'
		valuelabel.Size = UDim2.new(1, 0, 0, 16)
		valuelabel.BackgroundTransparency = 1
		valuelabel.Text = optionapi.Value
		valuelabel.TextColor3 = uipallet.Text
		valuelabel.TextSize = 17
		valuelabel.TextTruncate = Enum.TextTruncate.AtEnd
		valuelabel.FontFace = uipallet.Font
		valuelabel.Parent = button
		optionsettings.Function = optionsettings.Function or function() end
		local dropdownchildren
		
		function optionapi:Save(tab)
			tab[optionsettings.Name] = {Value = self.Value}
		end
		
		function optionapi:Load(tab)
			if self.Value ~= tab.Value then
				self:SetValue(tab.Value)
			end
		end
		
		function optionapi:Change(list)
			optionsettings.List = list or {}
			if not table.find(optionsettings.List, self.Value) then
				self:SetValue(self.Value)
			end
		end
		
		function optionapi:SetValue(val, mouse)
			self.Value = table.find(optionsettings.List, val) and val or optionsettings.List[1] or 'None'
			valuelabel.Text = self.Value
			if dropdownchildren then
				dropdownchildren:Destroy()
				dropdownchildren = nil
				dropdown.Size = UDim2.new(1, api.Category and -8 or 0, 0, 37)
			end
			optionsettings.Function(self.Value, mouse)
		end
		
		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = uipallet.Main
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		end)
		button.MouseButton1Click:Connect(function()
			if not dropdownchildren then
				dropdown.Size = UDim2.new(1, api.Category and -8 or 0, 0, 37 + (#optionsettings.List - 1) * 18)
				dropdownchildren = Instance.new('Frame')
				dropdownchildren.Name = 'Children'
				dropdownchildren.Size = UDim2.new(1, 0, 0, (#optionsettings.List - 1) * 18)
				dropdownchildren.Position = UDim2.fromOffset(0, 18)
				dropdownchildren.BackgroundTransparency = 1
				dropdownchildren.Parent = button
				local ind = 0
				for _, v in optionsettings.List do
					if v == optionapi.Value then continue end
					local dropdownoption = Instance.new('TextButton')
					dropdownoption.Name = v..'Option'
					dropdownoption.Size = UDim2.new(1, 0, 0, 18)
					dropdownoption.Position = UDim2.fromOffset(0, ind * 18)
					dropdownoption.BackgroundColor3 = dropdown.BackgroundColor3
					dropdownoption.BorderSizePixel = 0
					dropdownoption.AutoButtonColor = false
					dropdownoption.Text = v
					dropdownoption.TextColor3 = uipallet.Text
					dropdownoption.TextSize = 17
					dropdownoption.TextTruncate = Enum.TextTruncate.AtEnd
					dropdownoption.FontFace = uipallet.Font
					dropdownoption.Parent = dropdownchildren
					dropdownoption.MouseEnter:Connect(function()
						dropdownoption.BackgroundColor3 = color.Dark(dropdown.BackgroundColor3, 0.02)
					end)
					dropdownoption.MouseLeave:Connect(function()
						dropdownoption.BackgroundColor3 = dropdown.BackgroundColor3
					end)
					dropdownoption.MouseButton1Click:Connect(function()
						optionapi:SetValue(v, true)
					end)
					ind += 1
				end
			else
				optionapi:SetValue(optionapi.Value, true)
			end
		end)
		
		optionapi.Object = dropdown
		api.Options[optionsettings.Name] = optionapi
		
		return optionapi
	end,
	Font = function(optionsettings, children, api)
		local fonts = {
			optionsettings.Blacklist,
			'Custom'
		}
		for _, v in Enum.Font:GetEnumItems() do
			if not table.find(fonts, v.Name) then
				table.insert(fonts, v.Name)
			end
		end
		
		local optionapi = {Value = Font.fromEnum(Enum.Font[fonts[1]])}
		local fontdropdown
		local fontbox
		optionsettings.Function = optionsettings.Function or function() end
		
		fontdropdown = components.Dropdown({
			Name = optionsettings.Name,
			List = fonts,
			Function = function(val)
				fontbox.Object.Visible = val == 'Custom' and fontdropdown.Object.Visible
				if val ~= 'Custom' then
					optionapi.Value = Font.fromEnum(Enum.Font[val])
					optionsettings.Function(optionapi.Value)
				else
					pcall(function()
						optionapi.Value = Font.fromId(tonumber(fontbox.Value))
					end)
					optionsettings.Function(optionapi.Value)
				end
			end,
			Darker = optionsettings.Darker,
			Visible = optionsettings.Visible
		}, children, api)
		optionapi.Object = fontdropdown.Object
		fontbox = components.TextBox({
			Name = optionsettings.Name..' Asset',
			Placeholder = 'font (rbxasset)',
			Function = function()
				if fontdropdown.Value == 'Custom' then
					pcall(function()
						optionapi.Value = Font.fromId(tonumber(fontbox.Value))
					end)
					optionsettings.Function(optionapi.Value)
				end
			end,
			Visible = false,
			Darker = true
		}, children, api)
		
		fontdropdown.Object:GetPropertyChangedSignal('Visible'):Connect(function()
			fontbox.Object.Visible = fontdropdown.Object.Visible and fontdropdown.Value == 'Custom'
		end)
		
		return optionapi
	end,
	Slider = function(optionsettings, children, api)
		local optionapi = {
			Type = 'Slider',
			Value = optionsettings.Default or optionsettings.Min,
			Max = optionsettings.Max,
			Index = getTableSize(api.Options)
		}
		
		local slider = Instance.new('TextButton')
		slider.Name = optionsettings.Name..'Slider'
		slider.Size = UDim2.new(1, api.Category and -8 or 0, 0, 31)
		slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		slider.BackgroundTransparency = api.Category and 0 or 1
		slider.BorderSizePixel = 0
		slider.AutoButtonColor = false
		slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
		slider.Text = ''
		slider.Parent = children
		addTooltip(slider, optionsettings.Tooltip)
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.fromOffset(60, 15)
		title.Position = UDim2.fromOffset(10, 4)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 12
		title.FontFace = uipallet.Font
		title.Parent = slider
		local valuebutton = Instance.new('TextButton')
		valuebutton.Name = 'Value'
		valuebutton.Size = UDim2.fromOffset(60, 15)
		valuebutton.Position = UDim2.new(1, -72, 0, 4)
		valuebutton.BackgroundTransparency = 1
		valuebutton.Text = optionapi.Value..(optionsettings.Suffix and ' '..(type(optionsettings.Suffix) == 'function' and optionsettings.Suffix(optionapi.Value) or optionsettings.Suffix) or '')
		valuebutton.TextXAlignment = Enum.TextXAlignment.Right
		valuebutton.TextColor3 = uipallet.Text
		valuebutton.TextSize = 13
		valuebutton.FontFace = uipallet.Font
		valuebutton.Parent = slider
		local valuebox = Instance.new('TextBox')
		valuebox.Name = 'Box'
		valuebox.Size = UDim2.fromOffset(60, 15)
		valuebox.Position = valuebutton.Position
		valuebox.BackgroundTransparency = 1
		valuebox.Visible = false
		valuebox.Text = optionapi.Value
		valuebox.TextXAlignment = Enum.TextXAlignment.Right
		valuebox.TextColor3 = uipallet.Text
		valuebox.TextSize = 13
		valuebox.FontFace = uipallet.Font
		valuebox.ClearTextOnFocus = false
		valuebox.Parent = slider
		local bkg = Instance.new('Frame')
		bkg.Name = 'Slider'
		bkg.Size = UDim2.new(1, -10, 0, 6)
		bkg.Position = UDim2.fromOffset(5, 21)
		bkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.2)
		bkg.BorderSizePixel = 0
		bkg.Parent = slider
		addCorner(bkg, UDim.new(1, 0))
		local fill = bkg:Clone()
		fill.Name = 'Fill'
		fill.Size = UDim2.fromScale(math.clamp((optionapi.Value - optionsettings.Min) / optionsettings.Max, 0.02, 0.98), 1)
		fill.Position = UDim2.new()
		fill.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		fill.Parent = bkg
		local knobholder = Instance.new('Frame')
		knobholder.Name = 'Knob'
		knobholder.Size = UDim2.fromOffset(24, 4)
		knobholder.Position = UDim2.fromScale(1, 0.5)
		knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
		knobholder.BackgroundTransparency = 1
		knobholder.Parent = fill
		local knob = Instance.new('Frame')
		knob.Name = 'Knob'
		knob.Size = UDim2.fromOffset(12, 12)
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		knob.Parent = knobholder
		addCorner(knob, UDim.new(1, 0))
		optionsettings.Function = optionsettings.Function or function() end
		optionsettings.Decimal = optionsettings.Decimal or 1
		
		function optionapi:Save(tab)
			tab[optionsettings.Name] = {
				Value = self.Value,
				Max = self.Max
			}
		end
		
		function optionapi:Load(tab)
			local newval = tab.Value == tab.Max and tab.Max ~= self.Max and self.Max or tab.Value
			if self.Value ~= newval then
				self:SetValue(newval, nil, true)
			end
		end
		
		function optionapi:Color(hue, sat, val, rainbowcheck)
			fill.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
			knob.BackgroundColor3 = mainapi.GUIColor.Rainbow and color.Light(uipallet.Main, 0.14) or mainapi:TextColor(hue, sat, val)
		end
		
		function optionapi:SetValue(value, pos, final)
			if tonumber(value) == math.huge or value ~= value then return end
			local check = self.Value ~= value
			self.Value = value
			tween:Tween(fill, uipallet.Tween, {
				Size = UDim2.fromScale(math.clamp(pos or math.clamp(value / optionsettings.Max, 0, 1), 0.02, 0.98), 1)
			})
			valuebutton.Text = self.Value..(optionsettings.Suffix and ' '..(type(optionsettings.Suffix) == 'function' and optionsettings.Suffix(self.Value) or optionsettings.Suffix) or '')
			if check or final then
				optionsettings.Function(value, final)
			end
		end
		
		slider.InputBegan:Connect(function(inputObj)
			if (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch) and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale) then
				local newPosition = math.clamp((inputObj.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1)
				optionapi:SetValue(math.floor((optionsettings.Min + (optionsettings.Max - optionsettings.Min) * newPosition) * optionsettings.Decimal) / optionsettings.Decimal, newPosition)
				local lastValue = optionapi.Value
				local lastPosition = newPosition
		
				local changed = inputService.InputChanged:Connect(function(input)
					if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
						local newPosition = math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1)
						optionapi:SetValue(math.floor((optionsettings.Min + (optionsettings.Max - optionsettings.Min) * newPosition) * optionsettings.Decimal) / optionsettings.Decimal, newPosition)
						lastValue = optionapi.Value
						lastPosition = newPosition
					end
				end)
		
				local ended
				ended = inputObj.Changed:Connect(function()
					if inputObj.UserInputState == Enum.UserInputState.End then
						if changed then
							changed:Disconnect()
						end
						if ended then
							ended:Disconnect()
						end
						optionapi:SetValue(lastValue, lastPosition, true)
					end
				end)
		
			end
		end)
		valuebutton.MouseButton1Click:Connect(function()
			valuebutton.Visible = false
			valuebox.Visible = true
			valuebox.Text = optionapi.Value
			valuebox:CaptureFocus()
		end)
		valuebox.FocusLost:Connect(function(enter)
			valuebutton.Visible = true
			valuebox.Visible = false
			if enter and tonumber(valuebox.Text) then
				optionapi:SetValue(tonumber(valuebox.Text), nil, true)
			end
		end)
		
		optionapi.Object = slider
		api.Options[optionsettings.Name] = optionapi
		
		return optionapi
	end,
	Targets = function(optionsettings, children, api)
		local optionapi = {
			Type = 'Targets',
			Function = optionsettings.Function or function() end
		}
		
		function optionapi:Save() end
		function optionapi:Load() end
		
		optionapi.Object = {Visible = true}
		api.Options.Targets = optionapi
		
		return mainapi.TargetOptions
	end,
	TextBox = function(optionsettings, children, api)
		local optionapi = {
			Type = 'TextBox',
			Value = optionsettings.Default or '',
			Index = 0
		}
		
		local textbox = Instance.new('TextButton')
		textbox.Name = optionsettings.Name..'TextBox'
		textbox.Size = UDim2.new(1, api.Category and -8 or 0, 0, 37)
		textbox.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		textbox.BackgroundTransparency = api.Category and 0 or 1
		textbox.BorderSizePixel = 0
		textbox.AutoButtonColor = false
		textbox.Visible = optionsettings.Visible == nil or optionsettings.Visible
		textbox.Text = ''
		textbox.Parent = children
		addTooltip(textbox, optionsettings.Tooltip)
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, 0, 0, 15)
		title.Position = UDim2.fromOffset(0, 0)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = textbox
		local bkg = Instance.new('Frame')
		bkg.Name = 'BKG'
		bkg.Size = UDim2.new(1, -12, 1, -17)
		bkg.Position = UDim2.fromOffset(6, 16)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		bkg.BorderSizePixel = 0
		bkg.Parent = textbox
		local box = Instance.new('TextBox')
		box.Size = UDim2.new(1, -2, 1, -2)
		box.Position = UDim2.fromOffset(1, 1)
		box.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		box.BorderSizePixel = 0
		box.Text = optionapi.Value
		box.PlaceholderText = optionsettings.Placeholder or 'Click to set'
		box.TextColor3 = uipallet.Text
		box.PlaceholderColor3 = color.Dark(uipallet.Text, 0.31)
		box.TextSize = 17
		box.FontFace = uipallet.Font
		box.ClearTextOnFocus = false
		box.Parent = bkg
		optionsettings.Function = optionsettings.Function or function() end
		local dropdownchildren
		
		function optionapi:Save(tab)
			tab[optionsettings.Name] = {Value = self.Value}
		end
		
		function optionapi:Load(tab)
			if self.Value ~= tab.Value then
				self:SetValue(tab.Value)
			end
		end
		
		function optionapi:SetValue(val, enter)
			self.Value = val
			box.Text = val
			optionsettings.Function(enter)
		end
		
		textbox.MouseButton1Click:Connect(function()
			box:CaptureFocus()
		end)
		box.FocusLost:Connect(function(enter)
			optionapi:SetValue(box.Text, enter)
		end)
		box:GetPropertyChangedSignal('Text'):Connect(function()
			optionapi:SetValue(box.Text)
		end)
		
		optionapi.Object = textbox
		api.Options[optionsettings.Name] = optionapi
		
		return optionapi
	end,
	TextList = function(optionsettings, children, api)
		local optionapi = {
			Type = 'TextList',
			List = optionsettings.Default or {},
			ListEnabled = optionsettings.Default or {},
			Objects = {},
			Window = {Visible = false},
			Index = getTableSize(api.Options)
		}
		optionsettings.Color = optionsettings.Color or Color3.fromRGB(190, 115, 255)
		
		local textlist = Instance.new('TextButton')
		textlist.Name = optionsettings.Name..'TextList'
		textlist.Size = UDim2.new(1, api.Category and -8 or 0, 0, 24)
		textlist.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		textlist.BackgroundTransparency = api.Category and 0 or 1
		textlist.BorderSizePixel = 0
		textlist.AutoButtonColor = false
		textlist.Visible = optionsettings.Visible == nil or optionsettings.Visible
		textlist.Text = ''
		textlist.Parent = children
		local label = Instance.new('TextLabel')
		label.Size = UDim2.new(1, -12, 1, -4)
		label.Position = UDim2.fromOffset(6, 0)
		label.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.1)
		label.BorderSizePixel = 0
		label.Text = " "..optionsettings.Name
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = uipallet.Text
		label.TextSize = 14
		label.FontFace = uipallet.Font
		label.Parent = textlist
		local listchildren = Instance.new('Frame')
		listchildren.Size = UDim2.fromOffset(240, 24)
		listchildren.Position = UDim2.fromScale(1, 0)
		listchildren.BackgroundColor3 = uipallet.Main
		listchildren.BackgroundTransparency = 0.06
		listchildren.BorderSizePixel = 0
		listchildren.Visible = false
		listchildren.Parent = clickgui
		optionapi.Window = listchildren
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Left
		windowlist.Padding = UDim.new(0, 3)
		windowlist.Parent = listchildren
		local addbkg = Instance.new('Frame')
		addbkg.Name = 'Add'
		addbkg.Size = UDim2.new(1, 0, 0, 24)
		addbkg.BackgroundTransparency = 1
		addbkg.BorderSizePixel = 0
		addbkg.Parent = listchildren
		local addbox = addbkg:Clone()
		addbox.Size = UDim2.fromScale(1, 1)
		addbox.BackgroundColor3 = uipallet.Main
		addbox.BackgroundTransparency = 0.06
		addbox.Parent = addbkg
		local addvalue = Instance.new('TextBox')
		addvalue.Size = UDim2.new(1, -10, 1, 0)
		addvalue.Position = UDim2.fromOffset(10, 0)
		addvalue.BackgroundTransparency = 1
		addvalue.Text = ''
		addvalue.PlaceholderText = optionsettings.Placeholder or 'Add entry...'
		addvalue.TextXAlignment = Enum.TextXAlignment.Left
		addvalue.TextColor3 = Color3.new(1, 1, 1)
		addvalue.TextSize = 15
		addvalue.FontFace = uipallet.Font
		addvalue.ClearTextOnFocus = false
		addvalue.Parent = addbkg
		optionsettings.Function = optionsettings.Function or function() end
		
		function optionapi:Save(tab)
			tab[optionsettings.Name] = {
				List = self.List,
				ListEnabled = self.ListEnabled
			}
		end
		
		function optionapi:Load(tab)
			self.List = tab.List or {}
			self.ListEnabled = tab.ListEnabled or {}
			self:ChangeValue()
		end
		
		function optionapi:Color(hue, sat, val, rainbowcheck)
			for _, obj in self.Objects do
				obj.Dot.ImageLabel.ImageColor3 = Color3.fromHSV(mainapi:Color(hue))
			end
		end
		
		function optionapi:ChangeValue(val)
			if val then
				local ind = table.find(self.List, val)
				if ind then
					table.remove(self.List, ind)
					ind = table.find(self.ListEnabled, val)
					if ind then
						table.remove(self.ListEnabled, ind)
					end
				else
					table.insert(self.List, val)
					table.insert(self.ListEnabled, val)
				end
			end
		
			optionsettings.Function(self.List)
			for _, v in self.Objects do
				v:Destroy()
			end
			table.clear(self.Objects)
			self.Selected = nil
		
			for i, v in self.List do
				local enabled = table.find(self.ListEnabled, v)
				local object = Instance.new('TextButton')
				object.Name = v
				object.Size = UDim2.new(1, -14, 0, 24)
				object.BackgroundTransparency = 1
				object.Text = ''
				object.Parent = listchildren
				local objectbkg = Instance.new('Frame')
				objectbkg.Name = 'BKG'
				objectbkg.Size = UDim2.new(1, -30, 1, 0)
				objectbkg.Position = UDim2.fromOffset(4, 0)
				objectbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.05)
				objectbkg.BorderSizePixel = 0
				objectbkg.Visible = true
				objectbkg.Parent = object
				local objectdot = Instance.new('Frame')
				objectdot.Name = 'Dot'
				objectdot.Size = UDim2.fromOffset(16, 16)
				objectdot.Position = UDim2.fromOffset(8, 4)
				objectdot.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
				objectdot.BorderSizePixel = 0
				objectdot.Parent = object
				local objectdotin = Instance.new('ImageLabel')
				objectdotin.Size = UDim2.fromScale(1, 1)
				objectdotin.BackgroundTransparency = 1
				objectdotin.Image = getcustomasset('aetherv2/assets/old/checkbox.png')
				objectdotin.ImageColor3 = uipallet.Text
				objectdotin.Parent = objectdot
				local objecttitle = Instance.new('TextLabel')
				objecttitle.Name = 'Title'
				objecttitle.Size = UDim2.new(1, -28, 1, 0)
				objecttitle.Position = UDim2.fromOffset(28, 0)
				objecttitle.BackgroundTransparency = 1
				objecttitle.Text = v
				objecttitle.TextXAlignment = Enum.TextXAlignment.Left
				objecttitle.TextColor3 = uipallet.Text
				objecttitle.TextSize = 18
				objecttitle.FontFace = uipallet.Font
				objecttitle.Parent = object
				if mainapi.ThreadFix then
					setthreadidentity(8)
				end
				local close = Instance.new('TextButton')
				close.Name = 'Close'
				close.Size = UDim2.fromOffset(24, 24)
				close.Position = UDim2.new(1, -24, 0, 0)
				close.BackgroundColor3 = objectbkg.BackgroundColor3
				close.BorderSizePixel = 0
				close.AutoButtonColor = false
				close.Text = 'x'
				close.TextColor3 = uipallet.Text
				close.TextSize = 14
				close.FontFace = uipallet.Font
				close.Parent = object
				close.MouseButton1Click:Connect(function()
					self:ChangeValue(v)
				end)
				object.MouseButton1Click:Connect(function()
					local ind = table.find(self.ListEnabled, v)
					if ind then
						table.remove(self.ListEnabled, ind)
						objectdotin.Visible = false
					else
						table.insert(self.ListEnabled, v)
						objectdotin.Visible = true
					end
					optionsettings.Function()
				end)
				table.insert(self.Objects, object)
			end
			mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		end
		
		addvalue.FocusLost:Connect(function(enter)
			if enter and not table.find(optionapi.List, addvalue.Text) then
				optionapi:ChangeValue(addvalue.Text)
				addvalue.Text = ''
			end
		end)
		textlist.MouseButton1Click:Connect(function()
			listchildren.Visible = not listchildren.Visible
		end)
		textlist:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			local actualPosition = (textlist.AbsolutePosition + guiService:GetGuiInset()) / scale.Scale
			listchildren.Position = UDim2.fromOffset(actualPosition.X + textlist.AbsoluteSize.X, actualPosition.Y)
		end)
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			listchildren.Size = UDim2.fromOffset(240, math.min((windowlist.AbsoluteContentSize.Y + 6) / scale.Scale, 606))
		end)
		
		if optionsettings.Default then
			optionapi:ChangeValue()
		end
		optionapi.Object = textlist
		api.Options[optionsettings.Name] = optionapi
		
		return optionapi
	end,
	Toggle = function(optionsettings, children, api)
		local optionapi = {
			Type = 'Toggle',
			Enabled = false,
			Index = getTableSize(api.Options)
		}
		
		local toggle = Instance.new('TextButton')
		toggle.Name = optionsettings.Name..'Toggle'
		toggle.Size = UDim2.new(1, api.Category and -8 or 0, 0, 24)
		toggle.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		toggle.BackgroundTransparency = api.Category and 0 or 1
		toggle.BorderSizePixel = 0
		toggle.AutoButtonColor = false
		toggle.Visible = optionsettings.Visible == nil or optionsettings.Visible
		toggle.Text = string.rep(' ', 32)..optionsettings.Name
		toggle.TextXAlignment = Enum.TextXAlignment.Left
		toggle.TextColor3 = uipallet.Text
		toggle.TextSize = 13
		toggle.FontFace = uipallet.Font
		toggle.Parent = children
		addTooltip(toggle, optionsettings.Tooltip)
		local knobholder = Instance.new('Frame')
		knobholder.Name = 'Knob'
		knobholder.Size = UDim2.fromOffset(22, 15)
		knobholder.Position = UDim2.fromOffset(7, 4)
		knobholder.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		knobholder.Parent = toggle
		addCorner(knobholder, UDim.new(1, 0))
		local knob = knobholder:Clone()
		knob.Size = UDim2.fromOffset(12, 11)
		knob.Position = UDim2.fromOffset(2, 2)
		knob.BackgroundColor3 = uipallet.Main
		knob.Parent = knobholder
		optionsettings.Function = optionsettings.Function or function() end
		
		function optionapi:Save(tab)
			tab[optionsettings.Name] = {Enabled = self.Enabled}
		end
		
		function optionapi:Load(tab)
			if self.Enabled ~= tab.Enabled then
				self:Toggle()
			end
		end
		
		function optionapi:Color(hue, sat, val, rainbowcheck)
			if self.Enabled then
				tween:Cancel(knobholder)
				knobholder.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
			end
			knob.BackgroundColor3 = mainapi.GUIColor.Rainbow and uipallet.Main or mainapi:TextColor(hue, sat, val, uipallet.Main)
		end
		
		function optionapi:Toggle()
			self.Enabled = not self.Enabled
			local rainbowcheck = mainapi.GUIColor.Rainbow and mainapi.RainbowMode.Value ~= 'Retro'
			knobholder.BackgroundColor3 = self.Enabled and (rainbowcheck and Color3.fromHSV(mainapi:Color((mainapi.GUIColor.Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)) or color.Light(uipallet.Main, 0.14)
			tween:Tween(knob, uipallet.Tween, {
				Position = UDim2.fromOffset(self.Enabled and 8 or 2, 2)
			})
			optionsettings.Function(self.Enabled)
		end
		
		toggle.MouseButton1Click:Connect(function()
			optionapi:Toggle()
		end)
		
		if optionsettings.Default then
			optionapi:Toggle()
		end
		optionapi.Object = toggle
		api.Options[optionsettings.Name] = optionapi
		
		return optionapi
	end,
	TwoSlider = function(optionsettings, children, api)
		local optionapi = {
			Type = 'TwoSlider',
			ValueMin = optionsettings.DefaultMin or optionsettings.Min,
			ValueMax = optionsettings.DefaultMax or 10,
			Max = optionsettings.Max,
			Index = getTableSize(api.Options)
		}
		
		local slider = Instance.new('TextButton')
		slider.Name = optionsettings.Name..'Slider'
		slider.Size = UDim2.new(1, api.Category and -8 or 0, 0, 31)
		slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		slider.BackgroundTransparency = api.Category and 0 or 1
		slider.BorderSizePixel = 0
		slider.AutoButtonColor = false
		slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
		slider.Text = ''
		slider.Parent = children
		addTooltip(slider, optionsettings.Tooltip)
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, 0, 0, 20)
		title.Position = UDim2.fromOffset(0, 1)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextColor3 = uipallet.Text
		title.TextSize = 12
		title.FontFace = uipallet.Font
		title.Parent = slider
		local valuebutton = Instance.new('TextButton')
		valuebutton.Name = 'Value'
		valuebutton.Size = UDim2.fromOffset(60, 15)
		valuebutton.Position = UDim2.new(1, -70, 0, 6)
		valuebutton.BackgroundTransparency = 1
		valuebutton.Text = optionapi.ValueMax
		valuebutton.TextXAlignment = Enum.TextXAlignment.Right
		valuebutton.TextColor3 = uipallet.Text
		valuebutton.TextSize = 11
		valuebutton.FontFace = uipallet.Font
		valuebutton.Parent = slider
		local valuebutton2 = valuebutton:Clone()
		valuebutton2.Position = UDim2.fromOffset(7, 6)
		valuebutton2.Text = optionapi.ValueMin
		valuebutton2.TextXAlignment = Enum.TextXAlignment.Left
		valuebutton2.Parent = slider
		local valuebox = Instance.new('TextBox')
		valuebox.Name = 'Box'
		valuebox.Size = valuebutton.Size
		valuebox.Position = valuebutton.Position
		valuebox.BackgroundTransparency = 1
		valuebox.Visible = false
		valuebox.Text = optionapi.ValueMin
		valuebox.TextXAlignment = Enum.TextXAlignment.Right
		valuebox.TextColor3 = uipallet.Text
		valuebox.TextSize = 11
		valuebox.FontFace = uipallet.Font
		valuebox.ClearTextOnFocus = false
		valuebox.Parent = slider
		local valuebox2 = valuebox:Clone()
		valuebox2.Position = valuebutton2.Position
		valuebox2.TextXAlignment = Enum.TextXAlignment.Left
		valuebox2.Parent = slider
		local bkg = Instance.new('Frame')
		bkg.Name = 'Slider'
		bkg.Size = UDim2.new(1, -10, 0, 6)
		bkg.Position = UDim2.fromOffset(5, 22)
		bkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.2)
		bkg.BorderSizePixel = 0
		bkg.Parent = slider
		addCorner(bkg, UDim.new(1, 0))
		local fill = bkg:Clone()
		fill.Name = 'Fill'
		fill.Position = UDim2.fromScale(math.clamp(optionapi.ValueMin / optionsettings.Max, 0, 0.99), 0)
		fill.Size = UDim2.fromScale(math.clamp(math.clamp(optionapi.ValueMax / optionsettings.Max, 0, 1), 0, 0.99) - fill.Position.X.Scale, 1)
		fill.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		fill.Parent = bkg
		local knob = Instance.new('Frame')
		knob.Name = 'Knob'
		knob.Size = UDim2.fromOffset(3, 12)
		knob.Position = UDim2.fromScale(0, 0.5)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		knob.BorderSizePixel = 0
		knob.Parent = fill
		local knobmax = knob:Clone()
		knobmax.Name = 'KnobMax'
		knobmax.Position = UDim2.fromScale(1, 0.5)
		knobmax.Parent = fill
		local arrow = Instance.new('ImageLabel')
		arrow.Name = 'Arrow'
		arrow.Size = UDim2.fromOffset(12, 6)
		arrow.Position = UDim2.new(1, -56, 0, 10)
		arrow.BackgroundTransparency = 1
		arrow.Image = getcustomasset('aetherv2/assets/new/rangearrow.png')
		arrow.ImageColor3 = color.Light(uipallet.Main, 0.14)
		arrow.Parent = slider
		optionsettings.Function = optionsettings.Function or function() end
		optionsettings.Decimal = optionsettings.Decimal or 1
		local random = Random.new()
		
		function optionapi:Save(tab)
			tab[optionsettings.Name] = {
				ValueMin = self.ValueMin,
				ValueMax = self.ValueMax
			}
		end
		
		function optionapi:Load(tab)
			if self.ValueMin ~= tab.ValueMin then
				self:SetValue(false, tab.ValueMin)
			end
			if self.ValueMax ~= tab.ValueMax then
				self:SetValue(true, tab.ValueMax)
			end
		end
		
		function optionapi:Color(hue, sat, val, rainbowcheck)
			fill.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
			knob.BackgroundColor3 = mainapi.GUIColor.Rainbow and color.Light(uipallet.Main, 0.14) or mainapi:TextColor(hue, sat, val)
			knobmax.BackgroundColor3 = knob.BackgroundColor3
		end
		
		function optionapi:GetRandomValue()
			return random:NextNumber(optionapi.ValueMin, optionapi.ValueMax)
		end
		
		function optionapi:SetValue(max, value)
			if tonumber(value) == math.huge or value ~= value then return end
			self[max and 'ValueMax' or 'ValueMin'] = value
			valuebutton.Text = self.ValueMax
			valuebutton2.Text = self.ValueMin
			local size = math.clamp(math.clamp(self.ValueMin / optionsettings.Max, 0, 1), 0, 0.99)
			tween:Tween(fill, TweenInfo.new(0.1), {
				Position = UDim2.fromScale(size, 0),
				Size = UDim2.fromScale(math.clamp(math.clamp(math.clamp(self.ValueMax / optionsettings.Max, 0, 0.99), 0, 0.99) - size, 0, 1), 1)
			})
		end
		
		slider.InputBegan:Connect(function(inputObj)
			if
				(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
				and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
				local maxCheck = (inputObj.Position.X - knobmax.AbsolutePosition.X) > -10
				local newPosition = math.clamp((inputObj.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1)
				optionapi:SetValue(maxCheck, math.floor((optionsettings.Min + (optionsettings.Max - optionsettings.Min) * newPosition) * optionsettings.Decimal) / optionsettings.Decimal, newPosition)
		
				local changed = inputService.InputChanged:Connect(function(input)
					if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
						local newPosition = math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1)
						optionapi:SetValue(maxCheck, math.floor((optionsettings.Min + (optionsettings.Max - optionsettings.Min) * newPosition) * optionsettings.Decimal) / optionsettings.Decimal, newPosition)
					end
				end)
		
				local ended
				ended = inputObj.Changed:Connect(function()
					if inputObj.UserInputState == Enum.UserInputState.End then
						if changed then
							changed:Disconnect()
						end
						if ended then
							ended:Disconnect()
						end
					end
				end)
			end
		end)
		valuebutton.MouseButton1Click:Connect(function()
			valuebutton.Visible = false
			valuebox.Visible = true
			valuebox.Text = optionapi.ValueMax
			valuebox:CaptureFocus()
		end)
		valuebutton2.MouseButton1Click:Connect(function()
			valuebutton2.Visible = false
			valuebox2.Visible = true
			valuebox2.Text = optionapi.ValueMin
			valuebox2:CaptureFocus()
		end)
		valuebox.FocusLost:Connect(function(enter)
			valuebutton.Visible = true
			valuebox.Visible = false
			if enter and tonumber(valuebox.Text) then
				optionapi:SetValue(true, tonumber(valuebox.Text))
			end
		end)
		valuebox2.FocusLost:Connect(function(enter)
			valuebutton2.Visible = true
			valuebox2.Visible = false
			if enter and tonumber(valuebox2.Text) then
				optionapi:SetValue(false, tonumber(valuebox2.Text))
			end
		end)
		
		optionapi.Object = slider
		api.Options[optionsettings.Name] = optionapi
		
		return optionapi
	end,
	Divider = function(children, text)
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		divider.BorderSizePixel = 0
		divider.Parent = children
		if text then
			local label = Instance.new('TextLabel')
			label.Name = 'DividerLabel'
			label.Size = UDim2.fromOffset(218, 27)
			label.BackgroundTransparency = 1
			label.Text = '          '..text:upper()
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = color.Dark(uipallet.Text, 0.43)
			label.TextSize = 9
			label.FontFace = uipallet.Font
			label.Parent = children
			divider.Position = UDim2.fromOffset(0, 26)
			divider.Parent = label
		end
	end
}

mainapi.Components = setmetatable(components, {
	__newindex = function(self, ind, func)
		for _, v in mainapi.Modules do
			rawset(v, 'Create'..ind, function(_, settings)
				return func(settings, v.Children, v)
			end)
		end
		if mainapi.Legit then
			for _, v in mainapi.Legit.Modules do
				rawset(v, 'Create'..ind, function(_, settings)
					return func(settings, v.Children, v)
				end)
			end
		end
		rawset(self, ind, func)
	end
})

task.spawn(function()
	repeat
		local hue = tick() * (0.2 * mainapi.RainbowSpeed.Value) % 1
		for _, v in mainapi.RainbowTable do
			if v.Type == 'GUISlider' then
				v:SetValue(mainapi:Color(hue))
			else
				v:SetValue(hue)
			end
		end
		task.wait(1 / mainapi.RainbowUpdateSpeed.Value)
	until mainapi.Loaded == nil
end)

function mainapi:BlurCheck()
	if self.ThreadFix then
		setthreadidentity(8)
		runService:SetRobloxGuiFocused((clickgui.Visible or guiService:GetErrorType() ~= Enum.ConnectionError.OK) and self.Blur.Enabled)
	end
end

addMaid(mainapi)

function mainapi:CreateBar()
	local categoryapi = {
		Type = 'Category',
		Expanded = false,
		Options = {},
		TopBar = true
	}

	local bar = Instance.new('Frame')
	bar.Size = UDim2.fromOffset(180, 40)
	bar.Position = UDim2.fromScale(0.5, 0)
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.BackgroundColor3 = uipallet.Main
	bar.BackgroundTransparency = 0.06
	bar.BorderSizePixel = 0
	bar.Parent = clickgui
	local logo = Instance.new('ImageLabel')
	logo.Size = UDim2.fromOffset(92, 25)
	logo.Position = UDim2.fromOffset(11, 8)
	logo.BackgroundTransparency = 1
	logo.Image = getcustomasset('aetherv2/assets/old/barlogo.png')
	logo.ImageColor3 = uipallet.Text
	logo.Parent = bar
	local settingsbutton = Instance.new('TextButton')
	settingsbutton.Size = UDim2.fromOffset(32, 32)
	settingsbutton.Position = UDim2.fromOffset(108, 4)
	settingsbutton.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
	settingsbutton.BackgroundTransparency = 0.12
	settingsbutton.BorderSizePixel = 0
	settingsbutton.Text = ''
	settingsbutton.AutoButtonColor = false
	settingsbutton.Parent = bar
	local settingsicon = Instance.new('ImageLabel')
	settingsicon.Size = UDim2.fromOffset(26, 26)
	settingsicon.Position = UDim2.fromOffset(4, 4)
	settingsicon.BackgroundTransparency = 1
	settingsicon.Image = getcustomasset('aetherv2/assets/old/settingsicon.png')
	settingsicon.ImageColor3 = uipallet.Text
	settingsicon.Parent = settingsbutton
	local children = Instance.new('Frame')
	children.Size = UDim2.fromOffset(181, 0)
	children.Position = UDim2.new(0, 108, 1, 0)
	children.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
	children.BorderSizePixel = 0
	children.Visible = false
	children.Parent = bar
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Left
	windowlist.Parent = children
	local searchbutton = settingsbutton:Clone()
	searchbutton.Position = UDim2.fromOffset(144, 4)
	searchbutton.Parent = bar
	searchbutton.ImageLabel.Image = getcustomasset('aetherv2/assets/old/search.png')

	function categoryapi:CreateBind()
		local optionapi = {}

		local button = Instance.new('TextButton')
		button.Size = UDim2.new(1, 0, 0, 24)
		button.BackgroundColor3 = color.Dark(children.BackgroundColor3, 0.05)
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Visible = true
		button.Text = ''
		button.Parent = children
		addTooltip(button, 'Shift click any module to bind it to a key.')
		local buttonbkg = Instance.new('Frame')
		buttonbkg.Size = UDim2.new(1, -8, 0, 20)
		buttonbkg.Position = UDim2.fromOffset(4, 2)
		buttonbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.1)
		buttonbkg.BorderSizePixel = 0
		buttonbkg.Parent = button
		local buttontext = Instance.new('TextLabel')
		buttontext.Size = UDim2.fromScale(1, 1)
		buttontext.BackgroundTransparency = 1
		buttontext.Text = 'Rebind GUI'
		buttontext.TextColor3 = uipallet.Text
		buttontext.TextSize = 16
		buttontext.FontFace = uipallet.Font
		buttontext.Parent = buttonbkg

		function optionapi:SetBind(tab, mouse)
			mainapi.Keybind = #tab <= 0 and mainapi.Keybind or table.clone(tab)
			self.Bind = mainapi.Keybind
			if mainapi.VapeButton then
				mainapi.VapeButton:Destroy()
				mainapi.VapeButton = nil
			end

			if mouse then
				buttontext.Text = 'Bound to '..table.concat(mainapi.Keybind, ' + '):upper()
				task.delay(1, function()
					buttontext.Text = 'Rebind GUI'
				end)
			end
		end

		button.MouseButton1Click:Connect(function()
			mainapi.Binding = optionapi
			buttontext.Text = 'Press a key'
		end)

		categoryapi.Options.Bind = optionapi

		return optionapi
	end

	for i, v in components do
		categoryapi['Create'..i] = function(self, optionsettings)
			return v(optionsettings, children, categoryapi)
		end
	end

	settingsbutton.MouseButton1Click:Connect(function()
		children.Visible = not children.Visible
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.Size = UDim2.fromOffset(181, math.min(windowlist.AbsoluteContentSize.Y / scale.Scale, 600))
	end)

	categoryapi.Object = bar
	self.Categories.TopBar = categoryapi

	return categoryapi
end

function mainapi:CreateCategory(categorysettings)
	local categoryapi = {
		Type = 'Category',
		Expanded = false,
		Options = {}
	}

	local window = Instance.new('TextButton')
	window.Name = categorysettings.Name..'Category'
	window.Size = UDim2.fromOffset(categorysettings.WindowSize or 160, 40)
	window.Position = UDim2.fromOffset(categorysettings.Name == 'GUI' and 4 or 174, 68)
	window.BackgroundColor3 = uipallet.Main
	window.BackgroundTransparency = 0.06
	window.BorderSizePixel = 0
	window.AutoButtonColor = false
	window.Visible = categorysettings.Name == 'GUI'
	window.Text = ''
	window.Parent = clickgui
	makeDraggable(window)
	local iconshadow = Instance.new('ImageLabel')
	iconshadow.Name = 'Icon'
	iconshadow.Size = UDim2.fromOffset(26, 26)
	iconshadow.Position = UDim2.fromOffset(7, 7)
	iconshadow.BackgroundTransparency = 1
	iconshadow.Image = categorysettings.Icon
	iconshadow.ImageColor3 = Color3.new()
	iconshadow.ImageTransparency = 0.5
	iconshadow.Parent = window
	local icon = iconshadow:Clone()
	icon.Position = UDim2.fromOffset(6, 6)
	icon.ImageColor3 = uipallet.Text
	icon.ImageTransparency = 0
	icon.Parent = window
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = categorysettings.Name
	title.TextColor3 = uipallet.Text
	title.TextSize = 17
	title.FontFace = uipallet.Font
	title.Parent = window
	local arrowbutton = Instance.new('TextButton')
	arrowbutton.Name = 'Arrow'
	arrowbutton.Size = UDim2.fromOffset(30, 40)
	arrowbutton.Position = UDim2.new(1, -30, 0, 0)
	arrowbutton.BackgroundTransparency = 1
	arrowbutton.Text = '+'
	arrowbutton.TextColor3 = uipallet.Text
	arrowbutton.TextSize = 17
	arrowbutton.FontFace = uipallet.Font
	arrowbutton.Parent = window
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, 0)
	children.Position = UDim2.fromScale(0, 1)
	children.BackgroundColor3 = window.BackgroundColor3
	children.BackgroundTransparency = categorysettings.Name == 'Settings' and 0.06 or 1
	children.BorderSizePixel = 0
	children.Visible = false
	children.ScrollBarThickness = 0
	children.ScrollBarImageTransparency = 0.75
	children.CanvasSize = UDim2.new()
	children.Parent = window
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Left
	windowlist.Parent = children

	function categoryapi:CreateModule(modulesettings)
		mainapi:Remove(modulesettings.Name)
		local moduleapi = {
			Enabled = false,
			Options = {},
			Bind = {},
			Index = modulesettings.Index or getTableSize(mainapi.Modules),
			ExtraText = modulesettings.ExtraText,
			Name = modulesettings.Name,
			Category = categorysettings.Name
		}

		local modulebutton = Instance.new('TextButton')
		modulebutton.Name = modulesettings.Name
		modulebutton.Size = UDim2.new(1, -16, 0, 30)
		modulebutton.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
		modulebutton.BackgroundTransparency = 0.06
		modulebutton.BorderSizePixel = 0
		modulebutton.AutoButtonColor = false
		modulebutton.Text = modulesettings.Name
		modulebutton.TextColor3 = uipallet.Text
		modulebutton.TextSize = 17
		modulebutton.FontFace = uipallet.Font
		modulebutton.Parent = children
		local gradient = Instance.new('UIGradient')
		gradient.Rotation = 90
		gradient.Enabled = false
		gradient.Parent = modulebutton
		local hover = Instance.new('Frame')
		hover.Size = UDim2.fromScale(1, 1)
		hover.BackgroundColor3 = Color3.new()
		hover.BackgroundTransparency = 0.9
		hover.BorderSizePixel = 0
		hover.Visible = false
		hover.Parent = modulebutton
		local modulechildren = Instance.new('Frame')
		local dotsbutton = Instance.new('TextButton')
		addTooltip(modulebutton, modulesettings.Tooltip)
		dotsbutton.Name = 'Dots'
		dotsbutton.Size = UDim2.fromOffset(16, 30)
		dotsbutton.Position = UDim2.fromScale(1, 0)
		dotsbutton.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		dotsbutton.BackgroundTransparency = 0.06
		dotsbutton.BorderSizePixel = 0
		dotsbutton.AutoButtonColor = false
		dotsbutton.Text = ''
		dotsbutton.TextColor3 = uipallet.Text
		dotsbutton.TextSize = 17
		dotsbutton.FontFace = uipallet.Font
		dotsbutton.LineHeight = 0.3
		dotsbutton.Parent = modulebutton
		modulechildren.Name = modulesettings.Name..'Children'
		modulechildren.Size = UDim2.new(1, 0, 0, 0)
		modulechildren.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		modulechildren.BackgroundTransparency = 0.06
		modulechildren.BorderSizePixel = 0
		modulechildren.Visible = false
		modulechildren.Parent = children
		moduleapi.Children = modulechildren
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Parent = modulechildren
		modulesettings.Function = modulesettings.Function or function() end
		if modulesettings.Special then
			modulebutton.Size = UDim2.new(1, 0, 0, 30)
			dotsbutton.Visible = false
		end
		addMaid(moduleapi)

		function moduleapi:SetBind(tab, mouse)
			if tab.Mobile then
				createMobileButton(moduleapi, Vector2.new(tab.X, tab.Y))
				return
			end

			self.Bind = table.clone(tab)
			if mouse then
				modulebutton.Text = #tab <= 0 and 'Unbound' or 'Bound to '..table.concat(tab, ' + '):upper()
				task.delay(1, function()
					modulebutton.Text = modulesettings.Name
				end)
			end
		end

		function moduleapi:Toggle(multiple)
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			self.Enabled = not self.Enabled
			gradient.Enabled = self.Enabled
			modulebutton.TextColor3 = uipallet.Text
			modulebutton.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
			modulebutton.BackgroundTransparency = self.Enabled and 0 or 0.06
			if not self.Enabled then
				for _, v in self.Connections do
					v:Disconnect()
				end
				table.clear(self.Connections)
			end
			if not multiple then
				mainapi:UpdateTextGUI()
			end
			task.spawn(modulesettings.Function, self.Enabled)
		end

		for i, v in components do
			moduleapi['Create'..i] = function(self, optionsettings)
				dotsbutton.Text = '·\n·\n·'
				return v(optionsettings, modulechildren, moduleapi)
			end
		end

		dotsbutton.MouseButton1Click:Connect(function()
			modulechildren.Visible = not modulechildren.Visible
			dotsbutton.BackgroundColor3 = modulechildren.Visible and color.Dark(children.BackgroundColor3, 0.05) or color.Light(uipallet.Main, 0.02)
		end)
		dotsbutton.MouseButton2Click:Connect(function()
			modulechildren.Visible = not modulechildren.Visible
			dotsbutton.BackgroundColor3 = modulechildren.Visible and color.Dark(children.BackgroundColor3, 0.05) or color.Light(uipallet.Main, 0.02)
		end)
		modulebutton.MouseEnter:Connect(function()
			hover.Visible = true
		end)
		modulebutton.MouseLeave:Connect(function()
			hover.Visible = false
		end)
		modulebutton.MouseButton1Click:Connect(function()
			if inputService:IsKeyDown(Enum.KeyCode.LeftShift) and not modulesettings.Special then
				modulebutton.Text = 'Press a key'
				mainapi.Binding = moduleapi
				return
			end
			moduleapi:Toggle()
		end)
		modulebutton.MouseButton2Click:Connect(function()
			modulechildren.Visible = not modulechildren.Visible
			dotsbutton.BackgroundColor3 = modulechildren.Visible and color.Dark(children.BackgroundColor3, 0.05) or color.Light(uipallet.Main, 0.02)
		end)
		if inputService.TouchEnabled then
			local heldbutton = false
			modulebutton.MouseButton1Down:Connect(function()
				heldbutton = true
				local holdtime, holdpos = tick(), inputService:GetMouseLocation()
				repeat
					heldbutton = (inputService:GetMouseLocation() - holdpos).Magnitude < 3
					task.wait()
				until (tick() - holdtime) > 1 or not heldbutton or not clickgui.Visible
				if heldbutton and clickgui.Visible then
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					clickgui.Visible = false
					tooltip.Visible = false
					mainapi:BlurCheck()

					for _, mobileButton in mainapi.Modules do
						if mobileButton.Bind.Button then
							mobileButton.Bind.Button.Visible = true
						end
					end

					local touchconnection
					touchconnection = inputService.InputBegan:Connect(function(inputType)
						if inputType.UserInputType == Enum.UserInputType.Touch then
							if mainapi.ThreadFix then
								setthreadidentity(8)
							end
							createMobileButton(moduleapi, inputType.Position + Vector3.new(0, guiService:GetGuiInset().Y, 0))
							clickgui.Visible = true
							mainapi:BlurCheck()
							for _, mobileButton in mainapi.Modules do
								if mobileButton.Bind.Button then
									mobileButton.Bind.Button.Visible = false
								end
							end
							touchconnection:Disconnect()
						end
					end)
				end
			end)
			modulebutton.MouseButton1Up:Connect(function()
				heldbutton = false
			end)
		end
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			modulechildren.Size = UDim2.new(1, 0, 0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		end)

		moduleapi.Object = modulebutton
		mainapi.Modules[modulesettings.Name] = moduleapi

		local sorting = {}
		for _, v in mainapi.Modules do
			if v.Category == 'GUI' then continue end
			sorting[v.Category] = sorting[v.Category] or {}
			table.insert(sorting[v.Category], v.Name)
		end

		for _, sort in sorting do
			table.sort(sort)
			for i, v in sort do
				local module = mainapi.Modules[v]
				module.Index = i
				-- Two slots per module: the row, then its settings panel directly under it.
				-- Sharing one order left the pair tied, and a UIListLayout resolves a tie in
				-- whatever order it feels like.
				module.Object.LayoutOrder = i * 2
				if module.Children then
					module.Children.LayoutOrder = (i * 2) + 1
				end
			end
		end

		if modulesettings.Special then
			local num = 0
			for i in mainapi.Categories do
				if i ~= 'Main' and i ~= 'TopBar' then
					num += 1
				end
			end
			moduleapi.Index = num
		end

		return moduleapi
	end

	function categoryapi:Expand()
		self.Expanded = not self.Expanded
		children.Visible = self.Expanded
		arrowbutton.Text = self.Expanded and '-' or '+'
	end

	for i, v in components do
		categoryapi['Create'..i] = function(self, optionsettings)
			return v(optionsettings, children, categoryapi)
		end
	end

	arrowbutton.MouseButton1Click:Connect(function()
		categoryapi:Expand()
	end)
	arrowbutton.MouseButton2Click:Connect(function()
		categoryapi:Expand()
	end)
	window.MouseButton2Click:Connect(function(inputObj)
		categoryapi:Expand()
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		children.Size = UDim2.new(1, 0, 0, math.min(windowlist.AbsoluteContentSize.Y / scale.Scale, 600))
	end)

	if categorysettings.Name == 'GUI' then
		self.Categories.Main = categoryapi
	else
		categoryapi.Button = self.Categories.Main:CreateModule({
			Name = categorysettings.Name,
			Function = function(callback)
				window.Visible = callback
			end,
			Special = true
		})
		self.Categories[categorysettings.Name] = categoryapi
	end
	categoryapi.Object = window

	return categoryapi
end

function mainapi:CreateLegit(categorysettings)
	local categoryapi = {
		Type = 'Category',
		Expanded = false,
		Modules = {}
	}

	local window = Instance.new('TextButton')
	window.Name = categorysettings.Name..'Category'
	window.Size = UDim2.fromOffset(160, 40)
	window.Position = UDim2.fromOffset(174, 68)
	window.BackgroundColor3 = uipallet.Main
	window.BackgroundTransparency = 0.06
	window.BorderSizePixel = 0
	window.AutoButtonColor = false
	window.Visible = false
	window.Text = ''
	window.Parent = clickgui
	makeDraggable(window)
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = categorysettings.Name
	title.TextColor3 = uipallet.Text
	title.TextSize = 17
	title.FontFace = uipallet.Font
	title.Parent = window
	local arrowbutton = Instance.new('TextButton')
	arrowbutton.Name = 'Arrow'
	arrowbutton.Size = UDim2.fromOffset(30, 40)
	arrowbutton.Position = UDim2.new(1, -30, 0, 0)
	arrowbutton.BackgroundTransparency = 1
	arrowbutton.Text = '+'
	arrowbutton.TextColor3 = uipallet.Text
	arrowbutton.TextSize = 17
	arrowbutton.FontFace = uipallet.Font
	arrowbutton.Parent = window
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, 0)
	children.Position = UDim2.fromScale(0, 1)
	children.BackgroundColor3 = window.BackgroundColor3
	children.BackgroundTransparency = categorysettings.Name == 'Settings' and 0.06 or 1
	children.BorderSizePixel = 0
	children.Visible = false
	children.ScrollBarThickness = 0
	children.ScrollBarImageTransparency = 0.75
	children.CanvasSize = UDim2.new()
	children.Parent = window
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Left
	windowlist.Parent = children

	function categoryapi:CreateModule(modulesettings)
		local moduleapi = {
			Enabled = false,
			Options = {},
			Index = modulesettings.Index or getTableSize(mainapi.Modules),
			ExtraText = modulesettings.ExtraText,
			Name = modulesettings.Name,
			Category = categorysettings.Name
		}
		mainapi:Remove(modulesettings.Name)

		local modulebutton = Instance.new('TextButton')
		modulebutton.Name = modulesettings.Name
		modulebutton.Size = UDim2.new(1, -16, 0, 30)
		modulebutton.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
		modulebutton.BackgroundTransparency = 0.06
		modulebutton.BorderSizePixel = 0
		modulebutton.AutoButtonColor = false
		modulebutton.Text = modulesettings.Name
		modulebutton.TextColor3 = uipallet.Text
		modulebutton.TextSize = 17
		modulebutton.FontFace = uipallet.Font
		modulebutton.Parent = children
		local gradient = Instance.new('UIGradient')
		gradient.Rotation = 90
		gradient.Enabled = false
		gradient.Parent = modulebutton
		local hover = Instance.new('Frame')
		hover.Size = UDim2.fromScale(1, 1)
		hover.BackgroundColor3 = Color3.new()
		hover.BackgroundTransparency = 0.9
		hover.BorderSizePixel = 0
		hover.Visible = false
		hover.Parent = modulebutton
		local settingschildren = Instance.new('Frame')
		local dotsbutton = Instance.new('TextButton')
		dotsbutton.Name = 'Dots'
		dotsbutton.Size = UDim2.fromOffset(16, 30)
		dotsbutton.Position = UDim2.fromScale(1, 0)
		dotsbutton.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		dotsbutton.BackgroundTransparency = 0.06
		dotsbutton.BorderSizePixel = 0
		dotsbutton.AutoButtonColor = false
		dotsbutton.Text = ''
		dotsbutton.TextColor3 = uipallet.Text
		dotsbutton.TextSize = 17
		dotsbutton.FontFace = uipallet.Font
		dotsbutton.LineHeight = 0.3
		dotsbutton.Parent = modulebutton
		settingschildren.Name = modulesettings.Name..'Children'
		settingschildren.Size = UDim2.new(1, 0, 0, 0)
		settingschildren.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		settingschildren.BackgroundTransparency = 0.06
		settingschildren.BorderSizePixel = 0
		settingschildren.Visible = false
		settingschildren.Parent = children
		moduleapi.Settings = settingschildren
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Parent = settingschildren
		if modulesettings.Size then
			local moduleholder = Instance.new('Frame')
			moduleholder.Size = modulesettings.Size
			moduleholder.BackgroundTransparency = 1
			moduleholder.Visible = false
			moduleholder.Parent = scaledgui
			makeDraggable(moduleholder, window)
			local objectstroke = Instance.new('UIStroke')
			objectstroke.Color = Color3.fromRGB(190, 115, 255)
			objectstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			objectstroke.Thickness = 0
			objectstroke.Parent = moduleholder
			moduleapi.Children = moduleholder
		end
		modulesettings.Function = modulesettings.Function or function() end
		addMaid(moduleapi)

		function moduleapi:Toggle(multiple)
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			moduleapi.Enabled = not moduleapi.Enabled
			if moduleapi.Children then
				moduleapi.Children.Visible = moduleapi.Enabled
			end
			gradient.Enabled = moduleapi.Enabled
			modulebutton.TextColor3 = uipallet.Text
			modulebutton.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
			modulebutton.BackgroundTransparency = moduleapi.Enabled and 0 or 0.06
			if not moduleapi.Enabled then
				for _, v in moduleapi.Connections do
					v:Disconnect()
				end
				table.clear(moduleapi.Connections)
			end
			if not multiple then
				mainapi:UpdateTextGUI()
			end
			task.spawn(modulesettings.Function, moduleapi.Enabled)
		end

		for i, v in components do
			moduleapi['Create'..i] = function(self, optionsettings)
				dotsbutton.Text = '·\n·\n·'
				return v(optionsettings, settingschildren, moduleapi)
			end
		end

		dotsbutton.MouseButton1Click:Connect(function()
			settingschildren.Visible = not settingschildren.Visible
			dotsbutton.BackgroundColor3 = settingschildren.Visible and color.Dark(children.BackgroundColor3, 0.05) or color.Light(uipallet.Main, 0.02)
		end)
		dotsbutton.MouseButton2Click:Connect(function()
			settingschildren.Visible = not settingschildren.Visible
			dotsbutton.BackgroundColor3 = settingschildren.Visible and color.Dark(children.BackgroundColor3, 0.05) or color.Light(uipallet.Main, 0.02)
		end)
		modulebutton.MouseEnter:Connect(function()
			hover.Visible = true
		end)
		modulebutton.MouseLeave:Connect(function()
			hover.Visible = false
		end)
		modulebutton.MouseButton1Click:Connect(function()
			moduleapi:Toggle()
		end)
		modulebutton.MouseButton2Click:Connect(function()
			settingschildren.Visible = not settingschildren.Visible
			dotsbutton.BackgroundColor3 = settingschildren.Visible and color.Dark(children.BackgroundColor3, 0.05) or color.Light(uipallet.Main, 0.02)
		end)
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			settingschildren.Size = UDim2.new(1, 0, 0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		end)

		moduleapi.Object = modulebutton
		categoryapi.Modules[modulesettings.Name] = moduleapi

		local sorting = {}
		for _, v in categoryapi.Modules do
			sorting[v.Category] = sorting[v.Category] or {}
			table.insert(sorting[v.Category], v.Name)
		end

		for _, sort in sorting do
			table.sort(sort)
			for i, v in sort do
				categoryapi.Modules[v].Index = i
				categoryapi.Modules[v].Object.LayoutOrder = i
				categoryapi.Modules[v].Settings.LayoutOrder = i
			end
		end

		return moduleapi
	end

	function categoryapi:Expand()
		self.Expanded = not self.Expanded
		children.Visible = self.Expanded
		arrowbutton.Text = self.Expanded and '-' or '+'
	end

	for i, v in components do
		categoryapi['Create'..i] = function(self, optionsettings)
			return v(optionsettings, children, categoryapi)
		end
	end

	arrowbutton.MouseButton1Click:Connect(function()
		categoryapi:Expand()
	end)
	arrowbutton.MouseButton2Click:Connect(function()
		categoryapi:Expand()
	end)
	window.MouseButton2Click:Connect(function(inputObj)
		categoryapi:Expand()
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		children.Size = UDim2.new(1, 0, 0, math.min(windowlist.AbsoluteContentSize.Y / scale.Scale, 600))
	end)

	categoryapi.Button = self.Categories.Main:CreateModule({
		Name = categorysettings.Name,
		Function = function(callback)
			window.Visible = callback
		end,
		Special = true
	})
	self.Categories[categorysettings.Name] = categoryapi
	categoryapi.Object = window

	return categoryapi
end

function mainapi:CreateOverlay(categorysettings)
	local window
	local categoryapi
	categoryapi = {
		Type = 'Overlay',
		Expanded = false,
		Button = self.Categories.Main:CreateModule({
			Name = categorysettings.Name,
			Function = function(callback)
				window.Visible = callback and (clickgui.Visible or categoryapi.Pinned)
				if not callback then
					for _, v in categoryapi.Connections do
						v:Disconnect()
					end
					table.clear(categoryapi.Connections)
				end

				if categorysettings.Function then
					task.spawn(categorysettings.Function, callback)
				end
			end,
			Special = true
		}),
		Pinned = false,
		Options = {}
	}
	categoryapi.Options = categoryapi.Button.Options

	window = Instance.new('TextButton')
	window.Name = categorysettings.Name..'Overlay'
	window.Size = UDim2.fromOffset(categorysettings.WindowSize or 178, 40)
	window.Position = UDim2.fromOffset(174, 68)
	window.BackgroundColor3 = uipallet.Main
	window.BackgroundTransparency = 0.06
	window.BorderSizePixel = 0
	window.AutoButtonColor = false
	window.Text = ''
	window.Parent = scaledgui
	makeDraggable(window)
	local iconshadow = Instance.new('ImageLabel')
	iconshadow.Name = 'Icon'
	iconshadow.Size = UDim2.fromOffset(26, 26)
	iconshadow.Position = UDim2.fromOffset(7, 7)
	iconshadow.BackgroundTransparency = 1
	iconshadow.Image = categorysettings.Icon
	iconshadow.ImageColor3 = Color3.new()
	iconshadow.ImageTransparency = 0.5
	iconshadow.Parent = window
	local icon = iconshadow:Clone()
	icon.Position = UDim2.fromOffset(6, 6)
	icon.ImageColor3 = uipallet.Text
	icon.ImageTransparency = 0
	icon.Parent = window
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = categorysettings.Name
	title.TextColor3 = uipallet.Text
	title.TextSize = 17
	title.FontFace = uipallet.Font
	title.Parent = window
	local pin = Instance.new('ImageButton')
	pin.Name = 'Pin'
	pin.Size = UDim2.fromOffset(18, 18)
	pin.Position = UDim2.new(1, -23, 0, 11)
	pin.BackgroundTransparency = 1
	pin.AutoButtonColor = false
	pin.Image = getcustomasset('aetherv2/assets/old/pin.png')
	pin.ImageColor3 = color.Dark(uipallet.Text, 0.43)
	pin.Parent = window
	local customchildren = Instance.new('Frame')
	customchildren.Name = 'CustomChildren'
	customchildren.Size = UDim2.new(1, 0, 0, 200)
	customchildren.Position = UDim2.fromScale(0, 1)
	customchildren.BackgroundTransparency = 1
	customchildren.Parent = window
	categoryapi.Button.OriginalChildren = categoryapi.Button.Children
	categoryapi.Button.Children = customchildren
	categoryapi.Button.Button = categoryapi.Button
	addMaid(categoryapi)

	function categoryapi:Pin()
		self.Pinned = not self.Pinned
		pin.ImageColor3 = self.Pinned and uipallet.Text or color.Dark(uipallet.Text, 0.43)
	end

	function categoryapi:Update()
		window.Visible = self.Button.Enabled and (clickgui.Visible or self.Pinned)
		if self.Expanded then
			self:Expand()
		end

		if clickgui.Visible then
			window.Size = UDim2.fromOffset(window.Size.X.Offset, 40)
			window.BackgroundTransparency = 0.06
			icon.Visible = true
			iconshadow.Visible = true
			title.Visible = true
			pin.Visible = true
		else
			window.Size = UDim2.fromOffset(window.Size.X.Offset, 0)
			window.BackgroundTransparency = 1
			icon.Visible = false
			iconshadow.Visible = false
			title.Visible = false
			pin.Visible = false
		end
	end

	categoryapi.Button.OriginalChildren.UIListLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		categoryapi.Button.Object.Size = UDim2.new(1, -16, 0, 30)
		categoryapi.Button.Object.Dots.Visible = true
	end)
	pin.MouseButton1Click:Connect(function()
		categoryapi:Pin()
	end)
	window.MouseButton2Click:Connect(function()
		categoryapi:Pin()
	end)
	self:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		categoryapi:Update()
	end))

	categoryapi:Update()
	categoryapi.Object = window
	categoryapi.Children = customchildren
	self.Categories[categorysettings.Name] = categoryapi

	return categoryapi.Button
end

function mainapi:CreateCategoryList(categorysettings)
	local categoryapi = {
		Type = 'CategoryList',
		Expanded = false,
		List = {},
		ListEnabled = {},
		Objects = {},
		Options = {}
	}

	local window = Instance.new('TextButton')
	window.Name = categorysettings.Name..'CategoryList'
	window.Size = UDim2.fromOffset(categorysettings.WindowSize or 160, 40)
	window.Position = UDim2.fromOffset(174, 68)
	window.BackgroundColor3 = uipallet.Main
	window.BackgroundTransparency = 0.06
	window.BorderSizePixel = 0
	window.AutoButtonColor = false
	window.Visible = false
	window.Text = ''
	window.Parent = clickgui
	makeDraggable(window)
	local iconshadow = Instance.new('ImageLabel')
	iconshadow.Name = 'Icon'
	iconshadow.Size = UDim2.fromOffset(26, 26)
	iconshadow.Position = UDim2.fromOffset(7, 7)
	iconshadow.BackgroundTransparency = 1
	iconshadow.Image = categorysettings.Icon
	iconshadow.ImageColor3 = Color3.new()
	iconshadow.ImageTransparency = 0.5
	iconshadow.Parent = window
	local icon = iconshadow:Clone()
	icon.Position = UDim2.fromOffset(6, 6)
	icon.ImageColor3 = uipallet.Text
	icon.ImageTransparency = 0
	icon.Parent = window
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = categorysettings.Name
	title.TextColor3 = uipallet.Text
	title.TextSize = 17
	title.FontFace = uipallet.Font
	title.Parent = window
	local arrowbutton = Instance.new('TextButton')
	arrowbutton.Name = 'Arrow'
	arrowbutton.Size = UDim2.fromOffset(30, 40)
	arrowbutton.Position = UDim2.new(1, -30, 0, 0)
	arrowbutton.BackgroundTransparency = 1
	arrowbutton.Text = '+'
	arrowbutton.TextColor3 = uipallet.Text
	arrowbutton.TextSize = 17
	arrowbutton.FontFace = uipallet.Font
	arrowbutton.Parent = window
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, 0)
	children.Position = UDim2.fromScale(0, 1)
	children.BackgroundColor3 = window.BackgroundColor3
	children.BackgroundTransparency = 0.06
	children.BorderSizePixel = 0
	children.Visible = false
	children.ScrollBarThickness = 0
	children.ScrollBarImageTransparency = 0.75
	children.CanvasSize = UDim2.new()
	children.Parent = window
	local childrentwo = Instance.new('Frame')
	childrentwo.BackgroundTransparency = 1
	childrentwo.BackgroundColor3 = window.BackgroundColor3
	childrentwo.Parent = children
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Left
	windowlist.Padding = UDim.new(0, 3)
	windowlist.Parent = children
	local windowlisttwo = Instance.new('UIListLayout')
	windowlisttwo.SortOrder = Enum.SortOrder.LayoutOrder
	windowlisttwo.HorizontalAlignment = Enum.HorizontalAlignment.Left
	windowlisttwo.Parent = childrentwo
	local addbkg = Instance.new('Frame')
	addbkg.Name = 'Add'
	addbkg.Size = UDim2.new(1, 0, 0, 32)
	addbkg.Position = UDim2.fromOffset(10, 45)
	addbkg.BackgroundTransparency = 1
	addbkg.BorderSizePixel = 0
	addbkg.Parent = children
	local addbox = addbkg:Clone()
	addbox.Size = UDim2.new(1, -50, 1, -8)
	addbox.Position = UDim2.fromOffset(4, 4)
	addbox.BackgroundColor3 = color.Dark(uipallet.Main, 0.14)
	addbox.BackgroundTransparency = 0
	addbox.Parent = addbkg
	local addvalue = Instance.new('TextBox')
	addvalue.Size = UDim2.new(1, -35, 1, 0)
	addvalue.Position = UDim2.fromOffset(10, 0)
	addvalue.BackgroundTransparency = 1
	addvalue.Text = ''
	addvalue.PlaceholderText = categorysettings.Placeholder or 'Add entry...'
	addvalue.TextXAlignment = Enum.TextXAlignment.Left
	addvalue.TextColor3 = Color3.new(1, 1, 1)
	addvalue.TextSize = 15
	addvalue.FontFace = uipallet.Font
	addvalue.ClearTextOnFocus = false
	addvalue.Parent = addbkg
	local addbutton = Instance.new('TextButton')
	addbutton.Name = 'AddButton'
	addbutton.Size = UDim2.new(0, 44, 1, -8)
	addbutton.Position = UDim2.new(1, -46, 0, 4)
	addbutton.BackgroundTransparency = 1
	addbutton.Text = 'Add'
	addbutton.TextColor3 = uipallet.Text
	addbutton.TextSize = 18
	addbutton.FontFace = uipallet.Font
	addbutton.Parent = addbkg
	categoryapi.Profiles = categorysettings.Profiles
	categorysettings.Function = categorysettings.Function or function() end

	function categoryapi:ChangeValue(val)
		if val then
			if categorysettings.Profiles then
				local ind = self:GetValue(val)
				if ind then
					if val ~= 'default' then
						table.remove(mainapi.Profiles, ind)
						if isfile('aetherv2/profiles/'..val..mainapi.Place..'.txt') and delfile then
							delfile('aetherv2/profiles/'..val..mainapi.Place..'.txt')
						end
					end
				else
					table.insert(mainapi.Profiles, {Name = val, Bind = {}})
				end
			else
				local ind = table.find(self.List, val)
				if ind then
					table.remove(self.List, ind)
					ind = table.find(self.ListEnabled, val)
					if ind then
						table.remove(self.ListEnabled, ind)
					end
				else
					table.insert(self.List, val)
					table.insert(self.ListEnabled, val)
				end
			end
		end

		categorysettings.Function()
		for _, v in self.Objects do
			v:Destroy()
		end
		table.clear(self.Objects)
		self.Selected = nil

		for i, v in (categorysettings.Profiles and mainapi.Profiles or self.List) do
			if categorysettings.Profiles then
				local object = Instance.new('TextButton')
				object.Name = v.Name
				object.Size = UDim2.new(1, -14, 0, 20)
				object.BackgroundTransparency = 1
				object.Text = ''
				object.Parent = children
				local objectbkg = Instance.new('Frame')
				objectbkg.Name = 'BKG'
				objectbkg.Size = UDim2.new(1, -30, 1, 0)
				objectbkg.Position = UDim2.fromOffset(4, 0)
				objectbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.05)
				objectbkg.BorderSizePixel = 0
				objectbkg.Visible = true
				objectbkg.Parent = object
				local objecttitle = Instance.new('TextLabel')
				objecttitle.Name = 'Title'
				objecttitle.Size = UDim2.new(1, -8, 1, 0)
				objecttitle.Position = UDim2.fromOffset(8, 0)
				objecttitle.BackgroundTransparency = 1
				objecttitle.Text = v.Name
				objecttitle.TextXAlignment = Enum.TextXAlignment.Left
				objecttitle.TextColor3 = uipallet.Text
				objecttitle.TextSize = 18
				objecttitle.FontFace = uipallet.Font
				objecttitle.Parent = object
				if mainapi.ThreadFix then
					setthreadidentity(8)
				end
				local close = Instance.new('TextButton')
				close.Name = 'Close'
				close.Size = UDim2.fromOffset(20, 20)
				close.Position = UDim2.new(1, -24, 0, 0)
				close.BackgroundColor3 = objectbkg.BackgroundColor3
				close.BorderSizePixel = 0
				close.AutoButtonColor = false
				close.Text = 'x'
				close.TextColor3 = uipallet.Text
				close.TextSize = 14
				close.FontFace = uipallet.Font
				close.Parent = object
				close.MouseButton1Click:Connect(function()
					if v.Name ~= mainapi.Profile then
						self:ChangeValue(v.Name)
					end
				end)

				local function bindFunction(self, tab, mouse)
					v.Bind = table.clone(tab)
					if mouse then
						objecttitle.Text = #tab <= 0 and 'Unbound' or 'Bound to '..table.concat(tab, ' + '):upper()
						task.delay(1, function()
							objecttitle.Text = v.Name
						end)
					end
				end

				bindFunction({}, v.Bind)
				object.MouseButton1Click:Connect(function()
					if inputService:IsKeyDown(Enum.KeyCode.LeftShift) then
						objecttitle.Text = 'Press a key'
						mainapi.Binding = {SetBind = bindFunction, Bind = v.Bind}
						return
					end
					mainapi:Save(v.Name)
					mainapi:Load(true)
				end)
				if v.Name == mainapi.Profile then
					self.Selected = object
				end
				table.insert(self.Objects, object)
			else
				local enabled = table.find(self.ListEnabled, v)
				local object = Instance.new('TextButton')
				object.Name = v
				object.Size = UDim2.new(1, -14, 0, 24)
				object.BackgroundTransparency = 1
				object.Text = ''
				object.Parent = children
				local objectbkg = Instance.new('Frame')
				objectbkg.Name = 'BKG'
				objectbkg.Size = UDim2.new(1, -30, 1, 0)
				objectbkg.Position = UDim2.fromOffset(4, 0)
				objectbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.05)
				objectbkg.BorderSizePixel = 0
				objectbkg.Visible = true
				objectbkg.Parent = object
				local objectdot = Instance.new('Frame')
				objectdot.Name = 'Dot'
				objectdot.Size = UDim2.fromOffset(16, 16)
				objectdot.Position = UDim2.fromOffset(8, 4)
				objectdot.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
				objectdot.BorderSizePixel = 0
				objectdot.Parent = object
				local objectdotin = Instance.new('ImageLabel')
				objectdotin.Size = UDim2.fromScale(1, 1)
				objectdotin.BackgroundTransparency = 1
				objectdotin.Image = getcustomasset('aetherv2/assets/old/checkbox.png')
				objectdotin.ImageColor3 = uipallet.Text
				objectdotin.Parent = objectdot
				local objecttitle = Instance.new('TextLabel')
				objecttitle.Name = 'Title'
				objecttitle.Size = UDim2.new(1, -28, 1, 0)
				objecttitle.Position = UDim2.fromOffset(28, 0)
				objecttitle.BackgroundTransparency = 1
				objecttitle.Text = v
				objecttitle.TextXAlignment = Enum.TextXAlignment.Left
				objecttitle.TextColor3 = uipallet.Text
				objecttitle.TextSize = 18
				objecttitle.FontFace = uipallet.Font
				objecttitle.Parent = object
				if mainapi.ThreadFix then
					setthreadidentity(8)
				end
				local close = Instance.new('TextButton')
				close.Name = 'Close'
				close.Size = UDim2.fromOffset(24, 24)
				close.Position = UDim2.new(1, -24, 0, 0)
				close.BackgroundColor3 = objectbkg.BackgroundColor3
				close.BorderSizePixel = 0
				close.AutoButtonColor = false
				close.Text = 'x'
				close.TextColor3 = uipallet.Text
				close.TextSize = 14
				close.FontFace = uipallet.Font
				close.Parent = object
				close.MouseButton1Click:Connect(function()
					self:ChangeValue(v)
				end)
				object.MouseButton1Click:Connect(function()
					local ind = table.find(self.ListEnabled, v)
					if ind then
						table.remove(self.ListEnabled, ind)
						objectdotin.Visible = false
					else
						table.insert(self.ListEnabled, v)
						objectdotin.Visible = true
					end
					categorysettings.Function()
				end)
				table.insert(self.Objects, object)
			end
			mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		end
	end

	function categoryapi:Expand()
		self.Expanded = not self.Expanded
		children.Visible = self.Expanded
		arrowbutton.Text = self.Expanded and '-' or '+'
	end

	function categoryapi:GetValue(name)
		for i, v in mainapi.Profiles do
			if v.Name == name then
				return i
			end
		end
	end

	for i, v in components do
		categoryapi['Create'..i] = function(self, optionsettings)
			return v(optionsettings, childrentwo, categoryapi)
		end
	end

	addbutton.MouseButton1Click:Connect(function()
		if not table.find(categoryapi.List, addvalue.Text) then
			categoryapi:ChangeValue(addvalue.Text)
			addvalue.Text = ''
		end
	end)
	arrowbutton.MouseButton1Click:Connect(function()
		categoryapi:Expand()
	end)
	arrowbutton.MouseButton2Click:Connect(function()
		categoryapi:Expand()
	end)
	addvalue.FocusLost:Connect(function(enter)
		if enter and not table.find(categoryapi.List, addvalue.Text) then
			categoryapi:ChangeValue(addvalue.Text)
			addvalue.Text = ''
		end
	end)
	window.MouseButton2Click:Connect(function(inputObj)
		categoryapi:Expand()
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		children.Size = UDim2.new(1, 0, 0, math.min((windowlist.AbsoluteContentSize.Y + 6) / scale.Scale, 606))
	end)
	windowlisttwo:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		childrentwo.Size = UDim2.new(1, 0, 0, windowlisttwo.AbsoluteContentSize.Y)
	end)

	categoryapi.Button = self.Categories.Main:CreateModule({
		Name = categorysettings.Name,
		Function = function(callback)
			window.Visible = callback
		end,
		Special = true
	})
	categoryapi.Object = window
	self.Categories[categorysettings.Name] = categoryapi

	return categoryapi
end

function mainapi:CreateNotification(title, text, duration, type)
	if not self.Notifications.Enabled then return end
	task.delay(0, function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		local i = #notifications:GetChildren() + 1
		local notification = Instance.new('Frame')
		notification.Name = 'Notification'
		notification.Size = UDim2.fromOffset(getfontsize(removeTags(text), 18, uipallet.Font).X + 36, 41)
		notification.Position = UDim2.new(1, 0, 1, -(29 + (44 * i)))
		notification.ZIndex = 5
		notification.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
		notification.BackgroundTransparency = 0.5
		notification.BorderSizePixel = 0
		notification.Parent = notifications
		local iconshadow = Instance.new('ImageLabel')
		iconshadow.Name = 'Icon'
		iconshadow.Size = UDim2.fromOffset(32, 32)
		iconshadow.Position = UDim2.fromOffset(1, 3)
		iconshadow.ZIndex = 5
		iconshadow.BackgroundTransparency = 1
		iconshadow.Image = getcustomasset('aetherv2/assets/old/info.png')
		iconshadow.ImageColor3 = Color3.new()
		iconshadow.ImageTransparency = 0.5
		iconshadow.Parent = notification
		local icon = iconshadow:Clone()
		icon.Position = UDim2.fromOffset(-1, -1)
		icon.ImageColor3 = Color3.new(1, 1, 1)
		icon.ImageTransparency = 0
		icon.Parent = iconshadow
		local titlelabel = Instance.new('TextLabel')
		titlelabel.Name = 'Title'
		titlelabel.Size = UDim2.new(1, -31, 0, 20)
		titlelabel.Position = UDim2.fromOffset(31, 0)
		titlelabel.ZIndex = 5
		titlelabel.BackgroundTransparency = 1
		titlelabel.Text = title
		titlelabel.TextXAlignment = Enum.TextXAlignment.Left
		titlelabel.TextYAlignment = Enum.TextYAlignment.Top
		titlelabel.TextColor3 = uipallet.Text
		titlelabel.TextSize = 18
		titlelabel.RichText = true
		titlelabel.FontFace = uipallet.Font
		titlelabel.Parent = notification
		local textshadow = titlelabel:Clone()
		textshadow.Name = 'Text'
		textshadow.Position = UDim2.fromOffset(32, 19)
		textshadow.Text = removeTags(text)
		textshadow.TextColor3 = Color3.new()
		textshadow.TextTransparency = 0.5
		textshadow.RichText = false
		textshadow.FontFace = uipallet.Font
		textshadow.Parent = notification
		local textlabel = textshadow:Clone()
		textlabel.Position = UDim2.fromOffset(-1, -1)
		textlabel.Text = text
		textlabel.TextColor3 = Color3.fromRGB(170, 170, 170)
		textlabel.TextTransparency = 0
		textlabel.RichText = true
		textlabel.Parent = textshadow
		local progress = Instance.new('Frame')
		progress.Name = 'Progress'
		progress.Size = UDim2.new(1, -13, 0, 2)
		progress.Position = UDim2.new(0, 0, 1, -2)
		progress.ZIndex = 5
		progress.BackgroundColor3 = type == 'alert' and Color3.fromRGB(250, 50, 56) or type == 'warning' and Color3.fromRGB(236, 129, 43) or Color3.fromRGB(220, 220, 220)
		progress.BorderSizePixel = 0
		progress.Parent = notification
		if tween.Tween then
			tween:Tween(notification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
				AnchorPoint = Vector2.new(1, 0)
			}, tween.tweenstwo)
			tween:Tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Size = UDim2.fromOffset(0, 2)
			})
		end
		task.delay(duration, function()
			if tween.Tween then
				tween:Tween(notification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
					AnchorPoint = Vector2.new(0, 0)
				}, tween.tweenstwo)
			end
			task.wait(0.2)
			notification:ClearAllChildren()
			notification:Destroy()
		end)
	end)
end

function mainapi:Load(skipgui, profile)
	if not skipgui then
		self.GUIColor:SetValue(accent.Hue, accent.Sat, accent.Value)
	end
	local guidata = {}
	local savecheck = true

	if isfile('aetherv2/profiles/'..game.GameId..'.gui.txt') then
		guidata = loadJson('aetherv2/profiles/'..game.GameId..'.gui.txt')
		if not guidata then
			guidata = {Categories = {}}
			self:CreateNotification('AetherV2', 'Failed to load GUI settings.', 10, 'alert')
			savecheck = false
		end

		if not skipgui then
			self.Keybind = guidata.Keybind
			for i, v in guidata.Categories do
				local object = self.Categories[i]
				if not object then continue end
				if object.Options and v.Options then
					self:LoadOptions(object, v.Options)
				end
				-- Some saved category entries are display-only containers and do not own a
				-- toggle button. Restore their visibility without aborting the whole load.
				if v.Enabled and object.Button and object.Button.Toggle then
					object.Button:Toggle()
				elseif v.Enabled and object.Object then
					object.Object.Visible = true
				end
				if v.Pinned then
					object:Pin()
				end
				if v.Expanded then
					object:Expand()
				end
				if v.List and (#object.List > 0 or #v.List > 0) then
					object.List = v.List or {}
					object.ListEnabled = v.ListEnabled or {}
					object:ChangeValue()
				end
				if v.Position and i ~= 'TopBar' then
					object.Object.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
				end
			end
		end
	end

	self.Profile = profile or guidata.Profile or 'default'
	self.Profiles = guidata.Profiles or {{
		Name = 'default',
		Bind = {}
	}}
	self.Categories.Profiles:ChangeValue()

	local profilePath = 'aetherv2/configs/'..self.Profile..self.Place..'.json'
	if not isfile(profilePath) then profilePath = 'aetherv2/profiles/'..self.Profile..self.Place..'.txt' end

	if isfile(profilePath) then
		local savedata = loadJson(profilePath)
		if not savedata then
			savedata = {
				Categories = {},
				Modules = {},
				Legit = {}
			}
			self:CreateNotification('AetherV2', 'Failed to load '..self.Profile..' profile.', 10, 'alert')
			savecheck = false
		end

		for i, v in savedata.Categories do
			local object = self.Categories[i]
			if not object then continue end
			if object.Options and v.Options then
				self:LoadOptions(object, v.Options)
			end
			if v.Pinned ~= object.Pinned then
				object:Pin()
			end
			if v.Expanded ~= nil and v.Expanded ~= object.Expanded then
				object:Expand()
			end
			if object.Button and object.Button.Toggle and (v.Enabled or false) ~= object.Button.Enabled then
				object.Button:Toggle()
			end
			if v.List and (#object.List > 0 or #v.List > 0) then
				object.List = v.List or {}
				object.ListEnabled = v.ListEnabled or {}
				object:ChangeValue()
			end
			object.Object.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
		end

		for i, v in savedata.Modules do
			local object = self.Modules[i]
			if not object then continue end
			if object.Options and v.Options then
				self:LoadOptions(object, v.Options)
			end
			if v.Enabled ~= object.Enabled then
				if skipgui then
					if self.ToggleNotifications.Enabled then self:CreateNotification('Module Toggled', i.."<font color='#FFFFFF'> has been </font>"..(v.Enabled and "<font color='#5AFF5A'>Enabled</font>" or "<font color='#FF5A5A'>Disabled</font>").."<font color='#FFFFFF'>!</font>", 0.75) end
				end
				object:Toggle(true)
			end
			object:SetBind(v.Bind)
		end

		for i, v in savedata.Legit do
			local object = self.Legit.Modules[i]
			if not object then continue end
			if object.Options and v.Options then
				self:LoadOptions(object, v.Options)
			end
			if object.Enabled ~= v.Enabled then
				object:Toggle()
			end
			if v.Position and object.Children then
				object.Children.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
			end
		end

		self:UpdateTextGUI(true)
	else
		self:Save()
	end

	if self.Downloader then
		self.Downloader:Destroy()
		self.Downloader = nil
	end
	self.Loaded = savecheck
	self.Categories.TopBar.Options.Bind:SetBind(self.Keybind)
	-- The colours this pass brought forward are only on disk once the config is written
	-- back, so record the migration after a save rather than as the values are read.
	if savecheck and not configapi.Accents.Done then
		self:Save()
		configapi.Accents.Mark()
	end

	if inputService.TouchEnabled and #self.Keybind == 1 and self.Keybind[1] == 'RightShift' then
		local button = Instance.new('TextButton')
		button.Size = UDim2.fromOffset(32, 32)
		button.Position = UDim2.new(1, -90, 0, 4)
		button.BackgroundColor3 = Color3.new()
		button.Text = ''
		button.Parent = gui
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(26, 26)
		image.Position = UDim2.fromOffset(3, 3)
		image.BackgroundTransparency = 1
		image.Image = getcustomasset('aetherv2/assets/old/vape.png')
		image.Parent = button
		self.VapeButton = button
		button.MouseButton1Click:Connect(function()
			if self.ThreadFix then
				setthreadidentity(8)
			end
			for _, v in self.Windows do
				v.Visible = false
			end
			for _, mobileButton in self.Modules do
				if mobileButton.Bind.Button then
					mobileButton.Bind.Button.Visible = clickgui.Visible
				end
			end
			clickgui.Visible = not clickgui.Visible
			tooltip.Visible = false
			self:BlurCheck()
		end)
	end
end

function mainapi:LoadOptions(object, savedoptions)
	for i, v in savedoptions do
		local option = object.Options[i]
		if not option then continue end
		option:Load(v)
	end
end

function mainapi:Remove(obj)
	local tab = (self.Modules[obj] and self.Modules or self.Legit.Modules[obj] and self.Legit.Modules or self.Categories)
	if tab and tab[obj] then
		local newobj = tab[obj]
		if self.ThreadFix then
			setthreadidentity(8)
		end

		for _, v in {'Object', 'Children', 'Toggle', 'Button'} do
			local childobj = typeof(newobj[v]) == 'table' and newobj[v].Object or newobj[v]
			if typeof(childobj) == 'Instance' then
				childobj:Destroy()
				childobj:ClearAllChildren()
			end
		end

		loopClean(newobj)
		tab[obj] = nil
	end
end

function mainapi:Save(newprofile)
	if not self.Loaded then return end
	local guidata = {
		Categories = {},
		Profile = newprofile or self.Profile,
		Profiles = self.Profiles,
		Keybind = self.Keybind
	}
	local savedata = {
		Modules = {},
		Categories = {},
		Legit = {}
	}

	for i, v in self.Categories do
		(v.Type ~= 'Category' and i ~= 'GUI' and savedata or guidata).Categories[i] = {
			Enabled = v.Button and v.Button.Enabled or nil,
			Expanded = v.Type ~= 'Overlay' and v.Expanded or nil,
			Pinned = v.Pinned,
			Position = {X = v.Object.Position.X.Offset, Y = v.Object.Position.Y.Offset},
			Options = mainapi:SaveOptions(v, v.Options),
			List = v.List,
			ListEnabled = v.ListEnabled
		}
	end

	for i, v in self.Modules do
		savedata.Modules[i] = {
			Enabled = v.Enabled,
			Bind = typeof(v.Bind) == 'Instance' and {Mobile = true, X = v.Bind.Position.X.Offset, Y = v.Bind.Position.Y.Offset} or v.Bind,
			Options = mainapi:SaveOptions(v, true)
		}
	end

	for i, v in self.Legit.Modules do
		savedata.Legit[i] = {
			Enabled = v.Enabled,
			Position = v.Children and {X = v.Children.Position.X.Offset, Y = v.Children.Position.Y.Offset} or nil,
			Options = mainapi:SaveOptions(v, v.Options)
		}
	end

	writefile('aetherv2/profiles/'..game.GameId..'.gui.txt', httpService:JSONEncode(guidata))
	writefile('aetherv2/profiles/'..self.Profile..self.Place..'.txt', httpService:JSONEncode(savedata))
	writefile('aetherv2/configs/'..self.Profile..self.Place..'.json', httpService:JSONEncode(savedata))
end

function mainapi:SaveOptions(object, savedoptions)
	if not savedoptions then return end
	savedoptions = {}
	for _, v in object.Options do
		if not v.Save then continue end
		v:Save(savedoptions)
	end
	return savedoptions
end

-- Everything AetherV2 parks in the shared global tables.
--
-- Uninject cleared shared.vape and left the rest behind, and that is what made another
-- script picked up after a self destruct come back wearing AetherV2's skin: every
-- Vape-derived script starts with `shared.vape or _G.vape`, so it adopted this instance's
-- api - and drew itself from AetherV2's assets - instead of building its own. The same
-- goes for the game-module handles (vapeEvents, store, bedwars, remotes and friends): a
-- later script that reads one is reading a torn-down instance.
--
-- Deliberately absent: shared.VapeDeveloper and shared.VapeCustomProfile, which the
-- loader sets before we run and the reinject path reads afterwards, and getgenv().Drawing,
-- which on some executors is the executor's own and not ours to take away.
local claimedGlobals = {
	'vape',
	'vapeEvents',
	'store',
	'bedwars',
	'remotes',
	'getPlacedBlock',
	'getSpeed',
	'getHotbar',
	'hotbarSwitch',
	'switchItem',
	'RealLifeBedWars',
	'Backtrack',
	'FakeLag',
	'EntityAnalyser',
	'texturepack',
	'used_init',
	'_aeroTierReady',
	'getAeroTier',
	'IsLongJumping',
	'LongJumpFireballThrown',
	'ProjectileAuraFiringLock',
	'ItemOwner',
	'AetherV2LoadingScreen',
	'AetherV2SetLoadingStatus',
	'AetherV2CloseLoadingScreen'
}
local claimedShared = {
	'vape',
	'vapereload',
	'VapeIndependent',
	'updated',
	'bindable',
	'gg',
	'ACMODVIEWENABLED',
	'RealLifeBedWars',
	'vapeserverhoplist',
	'vapeserverhopprevious',
	'vapesessioninfo',
	'MATCH_CONTROLLER_GETPLAYERPARTY_REVERT',
	'PERMISSION_CONTROLLER_HASANYPERMISSIONS_REVERT'
}

-- Any ScreenGui we own, wherever it ended up. The menu itself is destroyed by Uninject,
-- but the loader's progress screen lives outside it and a teardown mid-load would leave
-- it on screen for whatever loads next.
local function destroyOwnedScreens()
	local roots = {}
	if gethui then
		local ok, res = pcall(gethui)
		if ok and res then table.insert(roots, res) end
	end
	pcall(function()
		table.insert(roots, cloneref(game:GetService('CoreGui')))
	end)
	pcall(function()
		table.insert(roots, cloneref(game:GetService('Players')).LocalPlayer:FindFirstChildOfClass('PlayerGui'))
	end)
	for _, root in roots do
		if not root then continue end
		pcall(function()
			for _, child in root:GetChildren() do
				if child:IsA('ScreenGui') and (child:GetAttribute('AetherV2') or child.Name == 'AetherV2Loading') then
					child:Destroy()
				end
			end
		end)
	end
end

local function releaseGlobals()
	local genv = getgenv and getgenv() or nil
	for _, name in claimedGlobals do
		if genv then
			pcall(function()
				genv[name] = nil
			end)
		end
		pcall(function()
			_G[name] = nil
		end)
	end
	for _, name in claimedShared do
		pcall(function()
			shared[name] = nil
		end)
	end
	destroyOwnedScreens()
end

--[[
	Repo configs

	The two modern GUIs get a browser for these; here it is one button, because there is
	nowhere sensible to hang a window off. It pulls configs/presets.json, writes every
	config it names into aetherv2/configs as a profile for this place, and registers the
	names in the Profiles tab.

	Nothing asks for a rejoin: clicking a name in Profiles is already a live switch (it
	saves the outgoing profile and re-loads onto the new one), so the configs are usable
	the moment the button reports back.
]]
function mainapi:DownloadRepoConfigs()
	if self.DownloadingConfigs then return end
	self.DownloadingConfigs = true
	local function finish(text, kind)
		self.DownloadingConfigs = false
		self:CreateNotification('AetherV2', text, 8, kind)
	end

	task.spawn(function()
		self:CreateNotification('AetherV2', 'Downloading configs from the repo...', 4, 'info')
		local base = 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..(isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt') or 'main')..'/configs/'
		local ok, body = pcall(function()
			return game:HttpGet(base..'presets.json', true)
		end)
		if not ok or type(body) ~= 'string' or body == '404: Not Found' then
			return finish('Could not reach the repo to list configs', 'alert')
		end
		local listed = select(2, pcall(function()
			return httpService:JSONDecode(body)
		end))
		if type(listed) ~= 'table' or type(listed.presets) ~= 'table' or #listed.presets == 0 then
			return finish('The repo has no configs published yet', 'alert')
		end

		local guipath = 'aetherv2/profiles/'..game.GameId..'.gui.txt'
		local guidata = isfile(guipath) and loadJson(guipath) or {}
		if type(guidata) ~= 'table' then guidata = {} end
		guidata.Profiles = guidata.Profiles or self.Profiles or {{Name = 'default', Bind = {}}}

		local added = 0
		for _, preset in listed.presets do
			local suc, wrapper = pcall(function()
				return httpService:JSONDecode(game:HttpGet(base..tostring(preset.file), true))
			end)
			if not suc or type(wrapper) ~= 'table' then continue end
			-- The file is a wrapper: the config itself is the `config` field, held as a
			-- JSON string so it survives being carried around as one blob.
			local name = tostring(preset.name or wrapper.name or ''):gsub('[\\/:*?"<>|]', '-'):gsub('^%s*(.-)%s*$', '%1')
			if name == '' then continue end
			local config = wrapper.config
			if type(config) == 'table' then
				config = httpService:JSONEncode(config)
			end
			if type(config) ~= 'string' or config == '' then continue end
			pcall(writefile, 'aetherv2/configs/'..name..self.Place..'.json', config)
			pcall(writefile, 'aetherv2/profiles/'..name..self.Place..'.txt', config)
			local listedAlready = false
			for _, profile in guidata.Profiles do
				if profile.Name == name then
					listedAlready = true
					break
				end
			end
			if not listedAlready then
				table.insert(guidata.Profiles, {Name = name, Bind = {}})
			end
			added += 1
		end

		if added <= 0 then
			return finish('Could not download any of the repo configs', 'alert')
		end

		pcall(writefile, guipath, httpService:JSONEncode(guidata))
		self.Profiles = guidata.Profiles
		-- Each GUI refreshes its profile list differently (and rise's is a grid, not a
		-- list), so try both and let a miss fall through - the names are on disk either
		-- way and the tab picks them up when it is next drawn.
		pcall(function()
			local profiles = self.Categories.Profiles
			if profiles.ChangeValue then
				profiles:ChangeValue()
			elseif profiles.Update then
				profiles:Update()
			end
		end)
		finish(added..' config'..(added == 1 and '' or 's')..' ready in Profiles, pick one to load it', 'info')
	end)
end

function mainapi:Uninject()
	mainapi:Save()
	mainapi.Loaded = nil
	for _, v in self.Modules do
		if v.Enabled then
			v:Toggle()
		end
		v.Button = nil
		v.Options = {}
	end
	for _, v in self.Legit.Modules do
		if v.Enabled then
			v:Toggle()
		end
	end
	for _, v in self.Categories do
		if v.Type == 'Overlay' and v.Button.Enabled then
			v.Button:Toggle()
		end
	end
	for _, v in mainapi.Connections do
		pcall(function()
			v:Disconnect()
		end)
	end
	if mainapi.ThreadFix then
		setthreadidentity(8)
		clickgui.Visible = false
		mainapi:BlurCheck()
	end
	mainapi.gui:ClearAllChildren()
	mainapi.gui:Destroy()
	table.clear(mainapi.Libraries)
	loopClean(mainapi)
	shared.vape = nil
	shared.vapereload = nil
	shared.VapeIndependent = nil
	releaseGlobals()
end

gui = Instance.new('ScreenGui')
gui.Name = randomString()
-- Lets the teardown find this screen again no matter what it was renamed to.
gui:SetAttribute('AetherV2', true)
gui.DisplayOrder = 9999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.IgnoreGuiInset = true
gui.OnTopOfCoreBlur = true
if mainapi.ThreadFix then
	gui.Parent = (gethui and gethui()) or cloneref(game:GetService('CoreGui'))
else
	gui.Parent = cloneref(game:GetService('Players')).LocalPlayer.PlayerGui
	gui.ResetOnSpawn = false
end
mainapi.gui = gui
scaledgui = Instance.new('Frame')
scaledgui.Name = 'ScaledGui'
scaledgui.Size = UDim2.fromScale(1, 1)
scaledgui.BackgroundTransparency = 1
scaledgui.Parent = gui
clickgui = Instance.new('Frame')
clickgui.Name = 'ClickGui'
clickgui.Size = UDim2.fromScale(1, 1)
clickgui.BackgroundTransparency = 1
clickgui.Visible = false
clickgui.Parent = scaledgui
local modal = Instance.new('TextButton')
modal.BackgroundTransparency = 1
modal.Modal = true
modal.Text = ''
modal.Parent = clickgui
local cursor = Instance.new('ImageLabel')
cursor.Size = UDim2.fromOffset(64, 64)
cursor.BackgroundTransparency = 1
cursor.Visible = false
cursor.Image = 'rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png'
cursor.Parent = gui
notifications = Instance.new('Folder')
notifications.Name = 'Notifications'
notifications.Parent = scaledgui
tooltip = Instance.new('TextLabel')
tooltip.Name = 'Tooltip'
tooltip.Position = UDim2.fromScale(-1, -1)
tooltip.ZIndex = 5
tooltip.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
tooltip.BackgroundTransparency = 0.5
tooltip.BorderSizePixel = 0
tooltip.Visible = false
tooltip.Text = ''
tooltip.TextColor3 = uipallet.Text
tooltip.TextSize = 14
tooltip.FontFace = uipallet.Font
tooltip.Parent = scaledgui
scale = Instance.new('UIScale')
scale.Scale = 1
scale.Parent = scaledgui
mainapi.guiscale = scale
scaledgui.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)

mainapi:Clean(gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
	if mainapi.Scale.Enabled then
		scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
	end
end))

mainapi:Clean(scale:GetPropertyChangedSignal('Scale'):Connect(function()
	scaledgui.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
	for _, v in scaledgui:GetDescendants() do
		if v:IsA('GuiObject') and v.Visible then
			v.Visible = false
			v.Visible = true
		end
	end
end))

mainapi:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
	mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value, true)
	if clickgui.Visible and inputService.MouseEnabled then
		repeat
			local visibleCheck = clickgui.Visible
			for _, v in mainapi.Windows do
				visibleCheck = visibleCheck or v.Visible
			end
			if not visibleCheck then break end

			cursor.Visible = not inputService.MouseIconEnabled
			if cursor.Visible then
				local mouseLocation = inputService:GetMouseLocation()
				cursor.Position = UDim2.fromOffset(mouseLocation.X - 31, mouseLocation.Y - 32)
			end

			task.wait()
		until mainapi.Loaded == nil
		cursor.Visible = false
	end
end))

mainapi:CreateCategory({
	Name = 'GUI',
	Icon = getcustomasset('aetherv2/assets/old/guiicon.png')
})
local combat = mainapi:CreateCategory({
	Name = 'Combat',
	Icon = getcustomasset('aetherv2/assets/old/combaticon.png')
})
mainapi:CreateCategory({
	Name = 'Blatant',
	Icon = getcustomasset('aetherv2/assets/old/blatanticon.png'),
	WindowSize = 164
})
-- Exploits: game-specific exploit modules (kit exploits, disablers). Uses the Blatant
-- icon for now until a dedicated asset is made.
mainapi:CreateCategory({
	Name = 'Exploits',
	Icon = getcustomasset('aetherv2/assets/old/blatanticon.png'),
	WindowSize = 164
})
mainapi:CreateCategory({
	Name = 'Render',
	Icon = getcustomasset('aetherv2/assets/old/rendericon.png'),
	WindowSize = 196
})
mainapi:CreateCategory({
	Name = 'Legit',
	Icon = getcustomasset('aetherv2/assets/old/rendericon.png'),
	WindowSize = 196
})
mainapi:CreateCategory({
	Name = 'Utility',
	Icon = getcustomasset('aetherv2/assets/old/utilityicon.png'),
	WindowSize = 164
})
mainapi:CreateCategory({
	Name = 'World',
	Icon = getcustomasset('aetherv2/assets/old/worldicon.png')
})
mainapi:CreateCategory({
	Name = 'Inventory',
	Icon = getcustomasset('aetherv2/assets/old/worldicon.png')
})
mainapi:CreateCategory({
	Name = 'Minigames',
	Icon = getcustomasset('aetherv2/assets/old/worldicon.png')
})
mainapi.Legit = mainapi:CreateLegit({
	Name = 'Legit'
})
local settingspane = mainapi:CreateCategory({
	Name = 'Settings',
	Icon = getcustomasset('aetherv2/assets/old/settingsicon.png'),
	WindowSize = 166
})


--[[
	Friends
]]
local friends
local friendscolor = {
	Hue = 1,
	Sat = 1,
	Value = 1
}
local friendssettings = {
	Name = 'Friends',
	Icon = getcustomasset('aetherv2/assets/old/friendsicon.png'),
	Placeholder = 'Roblox username',
	WindowSize = 250,
	Function = function()
		friends.Update:Fire()
		friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
	end
}
friends = mainapi:CreateCategoryList(friendssettings)
friends.Update = Instance.new('BindableEvent')
friends.ColorUpdate = Instance.new('BindableEvent')
friendscolor = friends:CreateColorSlider({
	Name = 'Friends color',
	Darker = true,
	Function = function(hue, sat, val)
		friendssettings.Color = Color3.fromHSV(hue, sat, val)
		friends.ColorUpdate:Fire(hue, sat, val)
	end
})
friends:CreateToggle({
	Name = 'Recolor visuals',
	Darker = true,
	Default = true,
	Function = function()
		friends.Update:Fire()
		friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
	end
})
friends:CreateToggle({
	Name = 'Use friends',
	Darker = true,
	Default = true,
	Function = function()
		friends.Update:Fire()
		friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
	end
})
mainapi:Clean(friends.Update)
mainapi:Clean(friends.ColorUpdate)

--[[
	Profiles
]]
mainapi:CreateCategoryList({
	Name = 'Profiles',
	Icon = getcustomasset('aetherv2/assets/old/profilesicon.png'),
	Placeholder = 'Type name',
	WindowSize = 250,
	Profiles = true
})

--[[
	Targets
]]
local targets
targets = mainapi:CreateCategoryList({
	Name = 'Targets',
	Icon = getcustomasset('aetherv2/assets/old/friendsicon.png'),
	Placeholder = 'Roblox username',
	WindowSize = 250,
	Function = function()
		targets.Update:Fire()
	end
})
targets.Update = Instance.new('BindableEvent')
mainapi:Clean(targets.Update)

local topbar = mainapi:CreateBar()
mainapi.Categories.Main.Options = settingspane.Options

mainapi.GUIColor = settingspane:CreateColorSlider({
	Name = 'Gui Color',
	DefaultHue = accent.Hue,
	DefaultSat = accent.Sat,
	DefaultValue = accent.Value,
	Function = function(h, s, v)
		mainapi:UpdateGUI(h, s, v, true)
	end
})

local function changedOptions()
	for _, module in mainapi.Modules do
		for _, option in module.Options do
			if option.Type == 'Targets' then
				option.Function()
			end
		end
	end
end

mainapi.TargetOptions = {
	Players = settingspane:CreateToggle({
		Name = 'Players',
		Function = changedOptions,
		Default = true
	}),
	NPCs = settingspane:CreateToggle({
		Name = 'NPCs',
		Function = changedOptions
	}),
	Invisible = settingspane:CreateToggle({
		Name = 'Ignore invisible',
		Function = changedOptions
	}),
	Walls = settingspane:CreateToggle({
		Name = 'Ignore behind walls',
		Function = changedOptions
	})
}
settingspane:CreateToggle({
	Name = 'Teams by server',
	Tooltip = 'Ignore players on your team designated by the server',
	Default = true,
	Function = function()
		if mainapi.Libraries.entity and mainapi.Libraries.entity.Running then
			mainapi.Libraries.entity.refresh()
		end
	end
})
settingspane:CreateToggle({
	Name = 'Use team color',
	Tooltip = 'Uses the TeamColor property on players for render modules',
	Default = true,
	Function = function()
		if mainapi.Libraries.entity and mainapi.Libraries.entity.Running then
			mainapi.Libraries.entity.refresh()
		end
	end
})


--[[
	GUI Settings
]]

mainapi.Blur = topbar:CreateToggle({
	Name = 'Blur background',
	Function = function()
		mainapi:BlurCheck()
	end,
	Default = true,
	Tooltip = 'Blur the background of the GUI'
})
mainapi.Categories.Main.Options['GUI bind indicator'] = topbar:CreateToggle({
	Name = 'GUI bind indicator',
	Default = true,
	Tooltip = "Displays a message indicating your GUI upon injecting\nI.E. 'Press RSHIFT to open GUI'"
})
topbar:CreateToggle({
	Name = 'Show tooltips',
	Function = function(enabled)
		tooltip.Visible = false
	end,
	Default = true,
	Tooltip = 'Toggles visibility of these'
})
mainapi.MultiKeybind = topbar:CreateToggle({
	Name = 'Enable Multi-Keybinding',
	Tooltip = 'Allows multiple keys to be bound to a module (eg. G + H)'
})
mainapi.Notifications = topbar:CreateToggle({
	Name = 'Notifications',
	Function = function(enabled)
		if mainapi.ToggleNotifications.Object then
			mainapi.ToggleNotifications.Object.Visible = enabled
		end
	end,
	Tooltip = 'Shows notifications',
	Default = true
})
mainapi.ToggleNotifications = topbar:CreateToggle({
	Name = 'Toggle alert',
	Tooltip = 'Notifies you if a module is enabled/disabled',
	Default = true,
	Darker = true
})
local scaleslider = {Object = {}, Value = 1}
mainapi.Scale = topbar:CreateToggle({
	Name = 'Auto rescale',
	Default = true,
	Function = function(callback)
		scaleslider.Object.Visible = not callback
		if callback then
			scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
		else
			scale.Scale = scaleslider.Value
		end
	end,
	Tooltip = 'Automatically rescales the gui using the screens resolution'
})
scaleslider = topbar:CreateSlider({
	Name = 'Scale',
	Min = 0.1,
	Max = 2,
	Decimal = 10,
	Function = function(val, final)
		if final and not mainapi.Scale.Enabled then
			scale.Scale = val
		end
	end,
	Default = 1,
	Darker = true,
	Visible = false
})
topbar:CreateDropdown({
	Name = 'GUI Theme',
	List = inputService.TouchEnabled and {'new', 'newer', 'old'} or {'new', 'newer', 'old', 'rise'},
	Function = function(val, mouse)
		if mouse then
			writefile('aetherv2/profiles/gui.txt', val)
			shared.vapereload = true
			if shared.VapeDeveloper then
				loadstring(readfile('aetherv2/main.lua'), 'main')(license)
			else
				loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/main.lua', true), 'main')(license)
			end
		end
	end,
	Tooltip = 'new - The newest vape theme to since v4.05\nold - The vape theme pre v4.05\nrise - Rise 6.0'
})
mainapi.RainbowMode = topbar:CreateDropdown({
	Name = 'Rainbow Mode',
	List = {'Normal', 'Gradient', 'Retro'},
	Tooltip = 'Normal - Smooth color fade\nGradient - Gradient color fade\nRetro - Static color'
})
mainapi.RainbowSpeed = topbar:CreateSlider({
	Name = 'Rainbow speed',
	Min = 0.1,
	Max = 10,
	Decimal = 10,
	Default = 1,
	Tooltip = 'Adjusts the speed of rainbow values'
})
mainapi.RainbowUpdateSpeed = topbar:CreateSlider({
	Name = 'Rainbow update rate',
	Min = 1,
	Max = 144,
	Default = 60,
	Tooltip = 'Adjusts the update rate of rainbow values',
	Suffix = 'hz'
})
topbar:CreateButton({
	Name = 'Reset current profile',
	Function = function()
		-- Nothing may write the in-memory state back out from under the reset: the autosave
		-- loop runs every ten seconds and Uninject saves on its way out.
		mainapi.Loaded = false
		mainapi.Save = function() end

		local profile = mainapi.Profile or 'default'
		-- The config, and the mirror of it that Load falls back to. Deleting only the mirror
		-- - which is all this used to do - reset nothing at all, because the config it reads
		-- first was still sitting there.
		for _, path in {
			'aetherv2/configs/'..profile..mainapi.Place..'.json',
			'aetherv2/profiles/'..profile..mainapi.Place..'.txt'
		} do
			if isfile(path) and delfile then
				pcall(delfile, path)
			end
		end

		-- GUI settings, window positions and the menu keybind live in the shared gui file.
		-- The list of configs and which one is active are not settings, so a reset lands
		-- back on the same profile rather than on 'default'.
		local profiles = {}
		for _, entry in mainapi.Profiles or {} do
			if type(entry) == 'table' and entry.Name then
				table.insert(profiles, {Name = entry.Name, Bind = {}})
			end
		end
		if #profiles == 0 then
			profiles = {{Name = 'default', Bind = {}}}
		end
		pcall(writefile, 'aetherv2/profiles/'..game.GameId..'.gui.txt', httpService:JSONEncode({
			Categories = {},
			Profile = profile,
			Profiles = profiles,
			Keybind = {'RightShift'}
		}))

		for path, value in {
			['aetherv2/profiles/forcegame.txt'] = 'false',
			['aetherv2/profiles/forcegameid.txt'] = tostring(game.PlaceId),
			['aetherv2/profiles/hide.txt'] = 'false',
			['aetherv2/profiles/disableloading.txt'] = 'false',
			['aetherv2/profiles/gui.txt'] = 'new'
		} do
			pcall(writefile, path, value)
		end
		-- Drop the accent stamp too, so the reload lands on the current default accent.
		if isfile(configapi.Accents.Path) and delfile then
			pcall(delfile, configapi.Accents.Path)
		end

		shared.vapereload = true
		if shared.VapeDeveloper then
			loadstring(readfile('aetherv2/main.lua'), 'main')(license)
		else
			loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/main.lua', true), 'main')(license)
		end
	end,
	Tooltip = 'Wipes everything saved for this config and reloads on defaults'
})
topbar:CreateButton({
	Name = 'Download configs',
	Function = function()
		mainapi:DownloadRepoConfigs()
	end,
	Tooltip = 'Pulls the configs published in the repo into Profiles'
})
topbar:CreateButton({
	Name = 'Reset GUI positions',
	Function = function()
		for _, v in mainapi.Categories do
			v.Object.Position = UDim2.fromOffset(4, 68)
		end
	end,
	Tooltip = 'This will reset your GUI back to default'
})
topbar:CreateButton({
	Name = 'Sort GUI',
	Function = function()
		local priority = {
			GUICategory = 1,
			CombatCategory = 2,
			BlatantCategory = 3,
			ExploitsCategory = 4,
			RenderCategory = 4,
			LegitCategory = 5,
			UtilityCategory = 6,
			WorldCategory = 7,
			InventoryCategory = 8,
			MinigamesCategory = 9,
			FriendsCategory = 10,
			ProfilesCategory = 11
		}
		local categories = {}
		for _, v in mainapi.Categories do
			if v.Type ~= 'Overlay' and not v.TopBar then
				table.insert(categories, v)
			end
		end
		table.sort(categories, function(a, b) return
			(priority[a.Object.Name] or 99) < (priority[b.Object.Name] or 99)
		end)

		local offset = 4
		for _, v in categories do
			if v.Object.Visible then
				v.Object.Position = UDim2.fromOffset(offset, 68)
				offset += v.Object.Size.X.Offset + 6
			end
		end
	end,
	Tooltip = 'Sorts GUI'
})
topbar:CreateButton({
	Name = 'UNINJECT',
	Function = function()
		mainapi:Uninject()
	end,
	Tooltip = 'Removes vape from the current game'
})
topbar:CreateButton({
	Name = 'REINEJCT',
	Function = function()
		shared.vapereload = true
		if shared.VapeDeveloper then
			loadstring(readfile('aetherv2/main.lua'), 'main')(license)
		else
			loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/main.lua', true), 'main')(license)
		end
	end,
	Tooltip = 'Reloads vape for debugging purposes'
})
topbar:CreateBind()

--[[
	Target Info
]]

local targetinfo
local targetinfoobj
local targetinfobcolor
targetinfoobj = mainapi:CreateOverlay({
	Name = 'Target Info',
	Icon = 'rbxasset://targetinfoicon.png',
	Function = function(callback)
		if callback then
			task.spawn(function()
				repeat
					targetinfo:UpdateInfo()
					task.wait()
				until not targetinfoobj.Button or not targetinfoobj.Button.Enabled
			end)
		end
	end,
	WindowSize = 246
})

local targetinfobkg = Instance.new('Frame')
targetinfobkg.Size = UDim2.fromOffset(246, 74)
targetinfobkg.BackgroundColor3 = uipallet.Main
targetinfobkg.BackgroundTransparency = 0.06
targetinfobkg.BorderSizePixel = 0
targetinfobkg.Parent = targetinfoobj.Children
local targetinfoshot = Instance.new('ImageLabel')
targetinfoshot.Size = UDim2.fromOffset(62, 62)
targetinfoshot.Position = UDim2.fromOffset(6, 6)
targetinfoshot.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
targetinfoshot.BorderColor3 = color.Light(uipallet.Main, 0.2)
targetinfoshot.Image = 'rbxthumb://type=AvatarHeadShot&id=1&w=420&h=420'
targetinfoshot.Parent = targetinfobkg
local targetinfoshotflash = Instance.new('Frame')
targetinfoshotflash.Size = UDim2.fromScale(1, 1)
targetinfoshotflash.BackgroundTransparency = 1
targetinfoshotflash.BackgroundColor3 = Color3.new(1, 0, 0)
targetinfoshotflash.BorderSizePixel = 0
targetinfoshotflash.Parent = targetinfoshot
local targetinfoname = Instance.new('TextLabel')
targetinfoname.Size = UDim2.fromOffset(145, 18)
targetinfoname.Position = UDim2.fromOffset(73, 3)
targetinfoname.BackgroundTransparency = 1
targetinfoname.Text = 'Target Name'
targetinfoname.TextXAlignment = Enum.TextXAlignment.Left
targetinfoname.TextYAlignment = Enum.TextYAlignment.Top
targetinfoname.TextScaled = true
targetinfoname.TextColor3 = uipallet.Text
targetinfoname.TextStrokeTransparency = 1
targetinfoname.FontFace = uipallet.Font
local targetinfoshadow = targetinfoname:Clone()
targetinfoshadow.Position = UDim2.fromOffset(74, 4)
targetinfoshadow.TextColor3 = Color3.new()
targetinfoshadow.TextTransparency = 0.65
targetinfoshadow.Parent = targetinfobkg
targetinfoname.Parent = targetinfobkg
targetinfoname:GetPropertyChangedSignal('Text'):Connect(function()
	targetinfoshadow.Text = targetinfoname.Text
end)
local targetinfohealthbkg = Instance.new('Frame')
targetinfohealthbkg.Name = 'HealthBKG'
targetinfohealthbkg.Size = UDim2.fromOffset(98, 6)
targetinfohealthbkg.Position = UDim2.fromOffset(74, 25)
targetinfohealthbkg.BackgroundColor3 = uipallet.Main
targetinfohealthbkg.BorderColor3 = color.Light(uipallet.Main, 0.2)
targetinfohealthbkg.Parent = targetinfobkg
local targetinfohealth = targetinfohealthbkg:Clone()
targetinfohealth.Size = UDim2.fromScale(0.8, 1)
targetinfohealth.Position = UDim2.new()
targetinfohealth.BackgroundColor3 = Color3.new(1, 1, 0)
targetinfohealth.BorderSizePixel = 0
targetinfohealth.Parent = targetinfohealthbkg
local targetinfohealthextra = targetinfohealth:Clone()
targetinfohealthextra.Size = UDim2.new()
targetinfohealthextra.Position = UDim2.fromScale(1, 0)
targetinfohealthextra.AnchorPoint = Vector2.new(1, 0)
targetinfohealthextra.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
targetinfohealthextra.Visible = false
targetinfohealthextra.Parent = targetinfohealthbkg
local targetinfohealthtext = targetinfoname:Clone()
targetinfohealthtext.Size = UDim2.fromOffset(145, 12)
targetinfohealthtext.Position = UDim2.fromOffset(177, 22)
targetinfohealthtext.BackgroundTransparency = 1
targetinfohealthtext.Text = '80 hp'
local targetinfoshadow2 = targetinfohealthtext:Clone()
targetinfoshadow2.Position = UDim2.fromOffset(178, 23)
targetinfoshadow2.TextColor3 = Color3.new()
targetinfoshadow2.TextTransparency = 0.65
targetinfoshadow2.Parent = targetinfobkg
targetinfohealthtext.Parent = targetinfobkg

local targetinfobackgroundtransparency = {
	Value = 0.5,
	Object = {Visible = {}}
}
local targetinfodisplay = targetinfoobj:CreateToggle({
	Name = 'Use Displayname',
	Default = true
})

local lasthealth = 0
local lastmaxhealth = 0
targetinfo = {
	Targets = {},
	Object = targetinfobkg,
	UpdateInfo = function(self)
		local entitylib = mainapi.Libraries
		if not entitylib then return end
		for i, v in self.Targets do
			if v < tick() then
				self.Targets[i] = nil
			end
		end

		local v, highest = nil, tick()
		for i, check in self.Targets do
			if check > highest then
				v = i
				highest = check
			end
		end

		targetinfobkg.Visible = v ~= nil or mainapi.gui.ScaledGui.ClickGui.Visible
		if v then
			targetinfoname.Text = v.Player and (targetinfodisplay.Enabled and v.Player.DisplayName or v.Player.Name) or v.Character and v.Character.Name or targetinfoname.Text
			targetinfoshot.Image = 'rbxthumb://type=AvatarHeadShot&id='..(v.Player and v.Player.UserId or 1)..'&w=420&h=420'

			if not v.Character then
				v.Health = v.Health or 0
				v.MaxHealth = v.MaxHealth or 100
			end

			if v.Health ~= lasthealth or v.MaxHealth ~= lastmaxhealth then
				local percent = math.max(v.Health / v.MaxHealth, 0)
				targetinfohealth.Size = UDim2.fromScale(math.min(percent, 1), 1)
				targetinfohealth.BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
				targetinfohealthextra.Size = UDim2.fromScale(math.clamp(percent - 1, 0, 0.8), 1)
				targetinfohealthtext.Text = math.round(v.Health)..' hp'
				if lasthealth > v.Health and self.LastTarget == v then
					tween:Cancel(targetinfoshotflash)
					targetinfoshotflash.BackgroundTransparency = 0.3
					tween:Tween(targetinfoshotflash, TweenInfo.new(0.5), {
						BackgroundTransparency = 1
					})
				end
				lasthealth = v.Health
				lastmaxhealth = v.MaxHealth
			end

			if not v.Character then table.clear(v) end
			self.LastTarget = v
		end
		return v
	end
}
mainapi.Libraries.targetinfo = targetinfo

--[[
	Text GUI
]]

local textgui = mainapi:CreateOverlay({
	Name = 'Text GUI',
	Icon = getcustomasset('aetherv2/assets/old/textguiicon.png'),
	WindowSize = 178,
	Function = function()
		mainapi:UpdateTextGUI()
	end
})
local textguisort = textgui:CreateDropdown({
	Name = 'Sort',
	List = {'Alphabetical', 'Length'},
	Function = function()
		mainapi:UpdateTextGUI()
	end
})
local VapeTextScale = Instance.new('UIScale')
VapeTextScale.Parent = textgui.Children
local textguiscale = textgui:CreateSlider({
	Name = 'Scale',
	Min = 0,
	Max = 2,
	Decimal = 10,
	Default = 1,
	Function = function(val)
		VapeTextScale.Scale = val
		mainapi:UpdateTextGUI()
	end
})
local textguishadow = textgui:CreateToggle({
	Name = 'Shadow',
	Tooltip = 'Renders shadowed text',
	Function = function()
		mainapi:UpdateTextGUI()
	end
})
local textguiwatermark = textgui:CreateToggle({
	Name = 'Watermark',
	Tooltip = 'Renders a vape watermark',
	Function = function()
		mainapi:UpdateTextGUI()
	end
})
local textguibackground = textgui:CreateToggle({
	Name = 'Render background',
	Function = function(callback)
		mainapi:UpdateTextGUI()
	end
})
local textguimoduleslist
local textguimodules = textgui:CreateToggle({
	Name = 'Hide modules',
	Tooltip = 'Allows you to blacklist certain modules from being shown',
	Function = function(enabled)
		textguimoduleslist.Object.Visible = enabled
		mainapi:UpdateTextGUI()
	end
})
--[[textguimoduleslist = textgui:CreateTextList({
	Name = 'Blacklist',
	Tooltip = 'Name of module to hide',
	Icon = getcustomasset('new/blockedicon.png'),
	Tab = getcustomasset('new/blockedtab.png'),
	TabSize = UDim2.fromOffset(21, 16),
	Color = Color3.fromRGB(250, 50, 56),
	Function = function()
		mainapi:UpdateTextGUI()
	end,
	Visible = false,
	Darker = true
})]]
local textguirender = textgui:CreateToggle({
	Name = 'Hide render',
	Function = function(enabled)
		mainapi:UpdateTextGUI()
	end
})

--[[
	Text GUI Objects
]]

local VapeLabels = {}
local VapeLogo = Instance.new('ImageLabel')
VapeLogo.Name = 'Logo'
VapeLogo.Size = UDim2.fromOffset(96, 26)
VapeLogo.Position = UDim2.new(1, -142, 0, 3)
VapeLogo.BackgroundTransparency = 1
VapeLogo.BorderSizePixel = 0
VapeLogo.Visible = true
VapeLogo.BackgroundColor3 = Color3.new()
VapeLogo.Image = getcustomasset('aetherv2/assets/old/textvape.png')
VapeLogo.Parent = textgui.Children

local lastside = textgui.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
mainapi:Clean(textgui.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
	if mainapi.ThreadFix then
		setthreadidentity(8)
	end
	local newside = textgui.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
	if lastside ~= newside then
		lastside = newside
		mainapi:UpdateTextGUI()
	end
end))

local VapeLogoV4 = Instance.new('ImageLabel')
VapeLogoV4.Name = 'Logo2'
VapeLogoV4.Size = UDim2.fromOffset(43, 30)
VapeLogoV4.Position = UDim2.new(1, 1, 0, -2)
VapeLogoV4.BackgroundColor3 = Color3.new()
VapeLogoV4.BackgroundTransparency = 1
VapeLogoV4.BorderSizePixel = 0
VapeLogoV4.Image = getcustomasset('aetherv2/assets/old/textv4.png')
VapeLogoV4.Parent = VapeLogo
local VapeLogoShadow = VapeLogo:Clone()
VapeLogoShadow.Position = UDim2.fromOffset(1, 1)
VapeLogoShadow.ZIndex = 0
VapeLogoShadow.Visible = true
VapeLogoShadow.ImageColor3 = Color3.new()
VapeLogoShadow.ImageTransparency = 0.65
VapeLogoShadow.Parent = VapeLogo
VapeLogoShadow.Logo2.ZIndex = 0
VapeLogoShadow.Logo2.ImageColor3 = Color3.new()
VapeLogoShadow.Logo2.ImageTransparency = 0.65
local VapeLogoGradient = Instance.new('UIGradient')
VapeLogoGradient.Rotation = 90
VapeLogoGradient.Parent = VapeLogo
local VapeLogoGradient2 = Instance.new('UIGradient')
VapeLogoGradient2.Rotation = 90
VapeLogoGradient2.Parent = VapeLogoV4
local VapeLabelHolder = Instance.new('Frame')
VapeLabelHolder.Name = 'Holder'
VapeLabelHolder.Size = UDim2.fromScale(1, 1)
VapeLabelHolder.Position = UDim2.fromOffset(5, 37)
VapeLabelHolder.BackgroundTransparency = 1
VapeLabelHolder.Parent = textgui.Children
local VapeLabelSorter = Instance.new('UIListLayout')
VapeLabelSorter.HorizontalAlignment = Enum.HorizontalAlignment.Right
VapeLabelSorter.VerticalAlignment = Enum.VerticalAlignment.Top
VapeLabelSorter.SortOrder = Enum.SortOrder.LayoutOrder
VapeLabelSorter.Parent = VapeLabelHolder

function mainapi:UpdateTextGUI(afterload)
	if not afterload and not mainapi.Loaded then return end
	if textgui.Button.Enabled then
		local right = textgui.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
		VapeLogo.Visible = textguiwatermark.Enabled
		VapeLogo.Position = right and UDim2.new(1 / VapeTextScale.Scale, -141, 0, 4) or UDim2.fromOffset(5, 4)
		VapeLogoShadow.Visible = textguishadow.Enabled
		VapeLabelSorter.HorizontalAlignment = right and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		VapeLabelHolder.Size = UDim2.fromScale(1 / VapeTextScale.Scale, 1)
		VapeLabelHolder.Position = UDim2.fromOffset(4, 4 + (VapeLogo.Visible and VapeLogo.Size.Y.Offset or 0))

		local found = {}
		for _, v in VapeLabels do
			if v.Enabled then
				table.insert(found, v.Object.Name)
			end
			v.Object:Destroy()
		end
		table.clear(VapeLabels)

		for i, v in mainapi.Modules do
			if textguimodules.Enabled and table.find(textguimoduleslist.ListEnabled, i) then continue end
			if textguirender.Enabled and v.Category == 'Render' then continue end
			if v.Category == 'GUI' then continue end
			if v.Enabled or table.find(found, i) then
				local holder = Instance.new('Frame')
				holder.Name = i
				holder.Size = UDim2.fromOffset()
				holder.BackgroundTransparency = 1
				holder.ClipsDescendants = true
				holder.Parent = VapeLabelHolder
				local holdertext = Instance.new('TextLabel')
				holdertext.Position = UDim2.fromOffset(right and 3 or 0, 2)
				holdertext.BackgroundTransparency = 1
				holdertext.BorderSizePixel = 0
				holdertext.Text = i..(v.ExtraText and " <font color='#A8A8A8'>"..v.ExtraText()..'</font>' or '')
				holdertext.TextSize = 18
				holdertext.FontFace = uipallet.Font
				holdertext.RichText = true
				local size = getfontsize(removeTags(holdertext.Text), holdertext.TextSize, holdertext.FontFace)
				holdertext.Size = UDim2.fromOffset(size.X, size.Y)
				if textguishadow.Enabled then
					local holderdrop = holdertext:Clone()
					holderdrop.Position = UDim2.fromOffset(holdertext.Position.X.Offset + 1, holdertext.Position.Y.Offset + 1)
					holderdrop.Text = removeTags(holdertext.Text)
					holderdrop.TextColor3 = Color3.new()
					holderdrop.TextTransparency = 0.65
					holderdrop.Parent = holder
				end
				holdertext.Parent = holder
				local holdersize = UDim2.fromOffset(size.X + 10, size.Y + 3)
				holder.Size = v.Enabled and holdersize or UDim2.fromOffset()
				table.insert(VapeLabels, {
					Object = holder,
					Text = holdertext,
					Enabled = v.Enabled
				})
			end
		end

		if textguisort.Value == 'Alphabetical' then
			table.sort(VapeLabels, function(a, b)
				return a.Text.Text < b.Text.Text
			end)
		else
			table.sort(VapeLabels, function(a, b)
				return a.Text.Size.X.Offset > b.Text.Size.X.Offset
			end)
		end

		for i, v in VapeLabels do
			if v.Color then
				v.Color.Parent.Line.Visible = i ~= 1
			end
			v.Object.LayoutOrder = i
		end
	end

	mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value, true)
end

function mainapi:UpdateModuleColor(button, hue, sat, val, default, rainbowcheck)
	if button.Enabled then
		button.Object.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1)) or Color3.fromHSV(hue, sat, val)
		button.Object.TextColor3 = mainapi.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or mainapi:TextColor(hue, sat, val)
		button.Object.UIGradient.Enabled = rainbowcheck and mainapi.RainbowMode.Value == 'Gradient'
		if button.Object.UIGradient.Enabled then
			button.Object.BackgroundColor3 = Color3.new(1, 1, 1)
			button.Object.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1))),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(mainapi:Color((hue - ((button.Index + 1) * 0.025)) % 1)))
			})
		end
	end

	for _, option in button.Options do
		if option.Color then
			option:Color(hue, sat, val, rainbowcheck)
		end
	end
end

function mainapi:UpdateGUI(hue, sat, val, default)
	if mainapi.Loaded == nil then return end
	if not default and mainapi.GUIColor.Rainbow then return end
	if textgui.Button.Enabled then
		VapeLogoGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
			ColorSequenceKeypoint.new(1, mainapi.GUIColor.Rainbow and Color3.fromHSV(mainapi:Color((hue - 0.075) % 1)) or Color3.fromHSV(hue, sat, val))
		})
		VapeLogoGradient2.Color = mainapi.GUIColor.Rainbow and VapeLogoGradient.Color or ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
		})
		for i, v in VapeLabels do
			v.Text.TextColor3 = customcolor or (mainapi.GUIColor.Rainbow and Color3.fromHSV(mainapi:Color((hue - ((i + 2) * 0.025)) % 1)) or VapeLogoGradient.Color.Keypoints[2].Value)
		end
	end

	if not clickgui.Visible then return end
	local rainbowcheck = mainapi.GUIColor.Rainbow and mainapi.RainbowMode.Value ~= 'Retro'

	for i, v in mainapi.Categories do
		if v.Options then
			for _, option in v.Options do
				if option.Color then option:Color(hue, sat, val, rainbowcheck) end
			end
		end

		if v.Type == 'CategoryList' then
			if not v.Profiles then
				for _, obj in v.Objects do
					obj.Dot.ImageLabel.ImageColor3 = Color3.fromHSV(mainapi:Color(hue))
				end
			end

			if v.Selected then
				v.Selected.BKG.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color(hue % 1)) or Color3.fromHSV(hue, sat, val)
				v.Selected.Title.TextColor3 = mainapi.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or mainapi:TextColor(hue, sat, val)
			end
		end
	end

	for _, button in mainapi.Modules do
		self:UpdateModuleColor(button, hue, sat, val, default, rainbowcheck)
	end

	if mainapi.Legit then
		for _, button in mainapi.Legit.Modules do
			self:UpdateModuleColor(button, hue, sat, val, default, rainbowcheck)
		end
	end
end

mainapi:Clean(notifications.ChildRemoved:Connect(function()
	for i, v in notifications:GetChildren() do
		if tween.Tween then
			tween:Tween(v, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
				Position = UDim2.new(1, 0, 1, -(29 + (44 * i)))
			})
		end
	end
end))

mainapi:Clean(inputService.InputBegan:Connect(function(inputObj)
	if not inputService:GetFocusedTextBox() and inputObj.KeyCode ~= Enum.KeyCode.Unknown then
		table.insert(mainapi.HeldKeybinds, inputObj.KeyCode.Name)
		if mainapi.Binding then return end

		if checkKeybinds(mainapi.HeldKeybinds, mainapi.Keybind, inputObj.KeyCode.Name) then
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			for _, v in mainapi.Windows do
				v.Visible = false
			end
			clickgui.Visible = not clickgui.Visible
			tooltip.Visible = false
			mainapi:BlurCheck()
		end

		local toggled = false
		for i, v in mainapi.Modules do
			if checkKeybinds(mainapi.HeldKeybinds, v.Bind, inputObj.KeyCode.Name) then
				toggled = true
				if mainapi.ToggleNotifications.Enabled then
					mainapi:CreateNotification('Module Toggled', i.."<font color='#FFFFFF'> has been </font>"..(not v.Enabled and "<font color='#5AFF5A'>Enabled</font>" or "<font color='#FF5A5A'>Disabled</font>").."<font color='#FFFFFF'>!</font>", 0.75)
				end
				v:Toggle(true)
			end
		end
		if toggled then
			mainapi:UpdateTextGUI()
		end

		for _, v in mainapi.Profiles do
			if checkKeybinds(mainapi.HeldKeybinds, v.Bind, inputObj.KeyCode.Name) and v.Name ~= mainapi.Profile then
				mainapi:Save(v.Name)
				mainapi:Load(true)
				break
			end
		end
	end
end))

mainapi:Clean(inputService.InputEnded:Connect(function(inputObj)
	if not inputService:GetFocusedTextBox() and inputObj.KeyCode ~= Enum.KeyCode.Unknown then
		if mainapi.Binding and inputObj.KeyCode.Name ~= 'LeftShift' then
			if not mainapi.MultiKeybind.Enabled then
				mainapi.HeldKeybinds = {inputObj.KeyCode.Name}
			end
			mainapi.Binding:SetBind(checkKeybinds(mainapi.HeldKeybinds, mainapi.Binding.Bind, inputObj.KeyCode.Name) and {} or mainapi.HeldKeybinds, true)
			mainapi.Binding = nil
		end
	end

	local ind = table.find(mainapi.HeldKeybinds, inputObj.KeyCode.Name)
	if ind then
		table.remove(mainapi.HeldKeybinds, ind)
	end
end))

--[[
	First run

	The same card the modern GUIs show, built from nothing but frames so it works on
	these two skins as well. Written once to profiles/welcome.txt and never shown again -
	the marker is shared with every GUI, so switching skins does not bring it back.
]]
function mainapi:CreateWelcome()
	local seenpath = 'aetherv2/profiles/welcome.txt'
	if isfile(seenpath) then return end

	local card = Instance.new('Frame')
	card.Name = 'Welcome'
	card.Size = UDim2.fromOffset(430, 250)
	card.Position = UDim2.new(0.5, -215, 0.5, -125)
	card.BackgroundColor3 = uipallet.Main
	card.Visible = false
	card.Parent = scaledgui
	addCorner(card)
	makeDraggable(card)
	local cardmodal = Instance.new('TextButton')
	cardmodal.BackgroundTransparency = 1
	cardmodal.Text = ''
	cardmodal.Modal = true
	cardmodal.Parent = card
	local stroke = Instance.new('UIStroke')
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.9
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.new(1, -70, 0, 22)
	title.Position = UDim2.fromOffset(22, 20)
	title.BackgroundTransparency = 1
	title.Text = 'Welcome to AetherV2'
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = uipallet.Text
	title.TextSize = 18
	title.FontFace = uipallet.FontSemiBold
	title.Parent = card

	local subtitle = title:Clone()
	subtitle.Name = 'Subtitle'
	subtitle.Size = UDim2.new(1, -70, 0, 16)
	subtitle.Position = UDim2.fromOffset(22, 40)
	subtitle.Text = 'A few things worth knowing before you start'
	subtitle.TextColor3 = color.Dark(uipallet.Text, 0.4)
	subtitle.TextSize = 12
	subtitle.FontFace = uipallet.Font
	subtitle.Parent = card

	local rows = Instance.new('Frame')
	rows.Name = 'Rows'
	rows.Size = UDim2.new(1, -44, 0, 108)
	rows.Position = UDim2.fromOffset(22, 68)
	rows.BackgroundTransparency = 1
	rows.Parent = card
	local rowlist = Instance.new('UIListLayout')
	rowlist.SortOrder = Enum.SortOrder.LayoutOrder
	rowlist.Padding = UDim.new(0, 6)
	rowlist.Parent = rows

	for index, entry in {
		{Heading = 'Open and close the menu', Body = 'Press '..table.concat(mainapi.Keybind, ' + '):upper()..'. Rebind it from the settings window'},
		{Heading = 'Configs live in the repo', Body = 'Settings has a Download configs button, then pick one in Profiles to load it'},
		{Heading = 'Anything broken or missing', Body = 'discord.gg/aYu5c9v9zv, copied to your clipboard by the button below'}
	} do
		local row = Instance.new('Frame')
		row.Name = 'Row'..index
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		row.Parent = rows
		addCorner(row)
		local heading = Instance.new('TextLabel')
		heading.Size = UDim2.new(1, -20, 0, 14)
		heading.Position = UDim2.fromOffset(10, 3)
		heading.BackgroundTransparency = 1
		heading.Text = entry.Heading
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.TextColor3 = uipallet.Text
		heading.TextSize = 12
		heading.FontFace = uipallet.Font
		heading.Parent = row
		local body = heading:Clone()
		body.Position = UDim2.fromOffset(10, 16)
		body.Text = entry.Body
		body.TextColor3 = color.Dark(uipallet.Text, 0.36)
		body.TextSize = 11
		body.Parent = row
	end

	local function dismiss()
		card.Visible = false
		clickgui.Visible = true
		pcall(writefile, seenpath, 'true')
	end

	local buttons = Instance.new('Frame')
	buttons.Name = 'Buttons'
	buttons.Size = UDim2.new(1, -44, 0, 30)
	buttons.Position = UDim2.fromOffset(22, 190)
	buttons.BackgroundTransparency = 1
	buttons.Parent = card
	local buttonlist = Instance.new('UIListLayout')
	buttonlist.FillDirection = Enum.FillDirection.Horizontal
	buttonlist.SortOrder = Enum.SortOrder.LayoutOrder
	buttonlist.Padding = UDim.new(0, 8)
	buttonlist.Parent = buttons

	for index, entry in {
		{Text = 'Download configs', Action = function()
			dismiss()
			mainapi:DownloadRepoConfigs()
		end},
		{Text = 'Copy discord', Action = function()
			if setclipboard then
				setclipboard('https://discord.gg/aYu5c9v9zv')
			end
			mainapi:CreateNotification('AetherV2', 'Discord invite copied to your clipboard', 5, 'info')
		end},
		{Text = 'Start', Primary = true, Action = dismiss}
	} do
		local button = Instance.new('TextButton')
		button.Name = entry.Text
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(126, 30)
		button.BackgroundColor3 = entry.Primary and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.04)
		button.AutoButtonColor = true
		button.Text = entry.Text
		button.TextColor3 = entry.Primary and mainapi:TextColor(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or uipallet.Text
		button.TextSize = 13
		button.FontFace = uipallet.Font
		button.Parent = buttons
		addCorner(button, UDim.new(0, 5))
		button.MouseButton1Click:Connect(entry.Action)
	end

	local close = Instance.new('TextButton')
	close.Name = 'Close'
	close.Size = UDim2.fromOffset(24, 24)
	close.Position = UDim2.new(1, -32, 0, 16)
	close.BackgroundTransparency = 1
	close.Text = 'x'
	close.TextColor3 = color.Dark(uipallet.Text, 0.3)
	close.TextSize = 15
	close.FontFace = uipallet.Font
	close.Parent = card
	close.MouseButton1Click:Connect(dismiss)

	local footer = Instance.new('TextLabel')
	footer.Name = 'Footer'
	footer.Size = UDim2.new(1, -44, 0, 14)
	footer.Position = UDim2.fromOffset(22, 226)
	footer.BackgroundTransparency = 1
	footer.Text = 'Shown once. Everything here lives in the menu if you need it later'
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextColor3 = color.Dark(uipallet.Text, 0.5)
	footer.TextSize = 11
	footer.FontFace = uipallet.Font
	footer.Parent = card

	table.insert(mainapi.Windows, card)
	mainapi.WelcomeCard = card

	-- Shown the first time the menu is actually opened rather than on injection, so it
	-- never lands on top of whatever the user was doing before they asked for the menu.
	local watcher
	watcher = clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		if not clickgui.Visible then return end
		watcher:Disconnect()
		if isfile(seenpath) then return end
		clickgui.Visible = false
		card.Visible = true
		card.Position = UDim2.new(0.5, -215, 0.5, -125)
	end)
	mainapi:Clean(watcher)
end

mainapi:CreateWelcome()

return mainapi
