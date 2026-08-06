--[[
	AetherV2 "Nexus" GUI (newer.lua) - v6.0 "Onyx"

	A clean, dark re-chrome of the AetherV2 interface. Fully compatible with the
	existing AetherV2 backend: same asset table, keybind system, module API
	(CreateCategory / CreateModule / CreateToggle / CreateSlider / ...), config
	save & load format, and overlay system as guis/new.lua.

	Visual language (v6 redesign):
	 - Near-black "Onyx" base (#0C0D12) with a faint cool tint; crisp off-white
	   text. A single live accent (the GUI Theme colour) drives everything.
	 - Modules render as flat dark list items: enabling one lights a left accent
	   bar + accent label instead of flooding the whole row (gradient rainbow mode
	   still uses the classic full fill). A short glow ring pulses on enable.
	 - Windows are frosted-glass cards with a 10px radius and a faint hairline
	   edge (addWindowStroke) so they read as defined panels on the dark backdrop.
	 - New category windows fan out across a lattice instead of stacking, so every
	   category is reachable the moment it is opened.
	 - 0.16s Quad/Out micro-interactions everywhere (uipallet.Tween).

	Kept from the previous build:
	 - Plugin system    : mainapi:RegisterPlugin(name, pluginTable) + auto-loaded
	                      aetherv2/plugins/*.lua.
	 - Spotlight (`)    : quick command palette to toggle any module.
	 - Theme presets    : one-click accent swatches; with "Recolour modules with
	                      theme" on they also retint module colours (Killaura target
	                      boxes, ESP, tracers, particles, ...).
	 - Watermark / Keybind HUD overlays, favourites polish, notifications.

	Removed in v6: the Aether Neo overhaul engine and the Theme / Interface /
	Windows settings-clutter panes (their machinery falls back to sane defaults).
]]
local license = ... or {}
-- AetherV2's accent, rgb(190, 115, 255), as the HSV the GUI works in. It is the
-- default in every window and is also the sixth notch on the GUI Theme slider,
-- so it stays a preset the user can move off and come back to.
local accent = {Hue = 0.7559524, Sat = 0.5490196, Value = 1, Notch = 6}
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
	Libraries = {},
	Modules = {},
	Place = game.PlaceId,
	Profile = 'default',
	Profiles = {},
	RainbowSpeed = {Value = 1},
	RainbowUpdateSpeed = {Value = 60},
	RainbowTable = {},
	Scale = {Value = 1},
	ThreadFix = setthreadidentity and true or false,
	ToggleNotifications = {},
	Version = '6.0',
	ToggleMode = {Value = 'Toggle'},
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
local toolblur
local tooltip
local scale
local gui

local color = {}
local tween = {
	tweens = {},
	tweenstwo = {}
}
local uipallet = {
	-- Nexus v6 "Onyx" palette. Near-black ink surface with a faint cool tint
	-- (#0C0D12), crisp off-white text. Raised cards/rows are derived from Main via
	-- color.Light/Dark. Rows read as flat dark list items; the live accent shows as
	-- a left bar + text on enabled modules and a hairline under window headers,
	-- rather than the old full-row highlight.
	Main = Color3.fromRGB(12, 13, 18),
	Text = Color3.fromRGB(226, 230, 240),
	Font = Font.fromEnum(Enum.Font.Gotham),
	FontSemiBold = Font.fromEnum(Enum.Font.Gotham, Enum.FontWeight.SemiBold),
	Tween = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	-- Glass-morphism levels: transparency applied to blurred panels (windows,
	-- tooltips, notifications).
	Glass = 0.12
}
-- Every panel that addBlur() frosts is registered here so the Theme editor can
-- retune glass intensity in real time. Weak keys let destroyed panels collect.
local glassPanels = setmetatable({}, {__mode = 'k'})

-- Restore any theme overrides written by the Theme editor (base surface colour,
-- text colour, font face and glass intensity). new.lua already reads color.txt
-- on load; newer.lua previously did not, so Theme settings silently reverted
-- every time the GUI (re)loaded or you switched between GUI themes. Reading them
-- here - before any colour is derived from uipallet - makes them persist.
do
	local overrides
	pcall(function()
		local raw = readfile('aetherv2/profiles/color.txt')
		if raw and raw ~= '' then
			overrides = httpService:JSONDecode(raw)
		end
	end)
	if type(overrides) == 'table' then
		if overrides.Main then
			uipallet.Main = Color3.fromRGB(unpack(overrides.Main))
		end
		if overrides.Text then
			uipallet.Text = Color3.fromRGB(unpack(overrides.Text))
		end
		if overrides.Font then
			local suc, newfont = pcall(function()
				return Font.new(
					overrides.Font:find('rbxasset') and overrides.Font
					or string.format('rbxasset://fonts/families/%s.json', overrides.Font)
				)
			end)
			if suc and newfont then
				uipallet.Font = newfont
				uipallet.FontSemiBold = Font.new(newfont.Family, Enum.FontWeight.SemiBold)
			end
		end
		if tonumber(overrides.Glass) then
			uipallet.Glass = math.clamp(tonumber(overrides.Glass), 0, 0.9)
		end
	end
	fontsize.Font = uipallet.Font
end

-- Marks a GuiObject as a frosted-glass surface: applies the current glass
-- transparency and registers it for live re-tuning from Settings -> Theme.
local function addGlass(obj)
	obj.BackgroundTransparency = uipallet.Glass
	glassPanels[obj] = true
	return obj
end

--[[
	Nexus interface-behaviour hub. Every field is live-tuned from the Settings
	panes added at the bottom of this file (Interface / Windows /
	Notifications). The function slots (PlaySound, SpawnRipple, guide
	rendering) start as no-ops and are filled in once the ScreenGui exists, so
	components built earlier can call them unconditionally.
]]
local nexus = {
	Hover = {
		Style = 'Underline', -- Underline | Outline | Brighten | None
		Intensity = 1,
		Lift = false,
		Sounds = false,
		Pulse = false
	},
	Tooltip = {
		Delay = 0,
		Follow = true
	},
	Drag = {
		EdgeSnap = true,
		WindowSnap = true,
		SnapDistance = 12,
		Grid = false,
		GridSize = 24,
		Clamp = true,
		Lock = false,
		Smoothing = 0,
		Guides = true
	},
	Notify = {
		Position = 'Bottom Right',
		Duration = 1,
		Max = 6,
		Sound = false
	},
	OpenAnim = 'Cascade',
	SoundsEnabled = false,
	SoundVolume = 0.5,
	PlaySound = function() end,
	SpawnRipple = function() end,
	ShowGuides = function() end,
	HideGuides = function() end,
	OnWindowMoved = function() end
}
mainapi.Nexus = nexus

local getcustomassets = {
	['aetherv2/assets/new/add.png'] = 'rbxassetid://14368300605',
	['aetherv2/assets/new/alert.png'] = 'rbxassetid://14368301329',
	['aetherv2/assets/new/allowedicon.png'] = 'rbxassetid://14368302000',
	['aetherv2/assets/new/allowedtab.png'] = 'rbxassetid://14368302875',
	['aetherv2/assets/new/arrowmodule.png'] = 'rbxassetid://14473354880',
	['aetherv2/assets/new/back.png'] = 'rbxassetid://14368303894',
	['aetherv2/assets/new/bind.png'] = 'rbxassetid://14368304734',
	['aetherv2/assets/new/bindbkg.png'] = 'rbxassetid://14368305655',
	['aetherv2/assets/new/blatanticon.png'] = 'rbxassetid://14368306745',
	['aetherv2/assets/new/blockedicon.png'] = 'rbxassetid://14385669108',
	['aetherv2/assets/new/blockedtab.png'] = 'rbxassetid://14385672881',
	['aetherv2/assets/new/blur.png'] = 'rbxassetid://14898786664',
	['aetherv2/assets/new/blurnotif.png'] = 'rbxassetid://16738720137',
	['aetherv2/assets/new/close.png'] = 'rbxassetid://14368309446',
	['aetherv2/assets/new/closemini.png'] = 'rbxassetid://14368310467',
	['aetherv2/assets/new/colorpreview.png'] = 'rbxassetid://14368311578',
	['aetherv2/assets/new/combaticon.png'] = 'rbxassetid://14368312652',
	['aetherv2/assets/new/customsettings.png'] = 'rbxassetid://14403726449',
	['aetherv2/assets/new/discord.png'] = '',
	['aetherv2/assets/new/dots.png'] = 'rbxassetid://14368314459',
	['aetherv2/assets/new/edit.png'] = 'rbxassetid://14368315443',
	['aetherv2/assets/new/expandicon.png'] = 'rbxassetid://14368353032',
	['aetherv2/assets/new/expandright.png'] = 'rbxassetid://14368316544',
	['aetherv2/assets/new/expandup.png'] = 'rbxassetid://14368317595',
	['aetherv2/assets/new/friendstab.png'] = 'rbxassetid://14397462778',
	['aetherv2/assets/new/guisettings.png'] = 'rbxassetid://14368318994',
	['aetherv2/assets/new/guislider.png'] = 'rbxassetid://14368320020',
	['aetherv2/assets/new/guisliderrain.png'] = 'rbxassetid://14368321228',
	['aetherv2/assets/new/guiv4.png'] = 'rbxassetid://14368322199',
	['aetherv2/assets/new/guivape.png'] = 'rbxassetid://14657521312',
	['aetherv2/assets/new/info.png'] = 'rbxassetid://14368324807',
	['aetherv2/assets/new/inventoryicon.png'] = 'rbxassetid://14928011633',
	['aetherv2/assets/new/legit.png'] = 'rbxassetid://14425650534',
	['aetherv2/assets/new/legittab.png'] = 'rbxassetid://14426740825',
	['aetherv2/assets/new/loading.png'] = '',
	['aetherv2/assets/new/miniicon.png'] = 'rbxassetid://14368326029',
	['aetherv2/assets/new/notification.png'] = 'rbxassetid://16738721069',
	['aetherv2/assets/new/overlaysicon.png'] = 'rbxassetid://14368339581',
	['aetherv2/assets/new/overlaystab.png'] = 'rbxassetid://14397380433',
	['aetherv2/assets/new/pin.png'] = 'rbxassetid://14368342301',
	['aetherv2/assets/new/profilesicon.png'] = 'rbxassetid://14397465323',
	['aetherv2/assets/new/radaricon.png'] = 'rbxassetid://14368343291',
	['aetherv2/assets/new/rainbow_1.png'] = 'rbxassetid://14368344374',
	['aetherv2/assets/new/rainbow_2.png'] = 'rbxassetid://14368345149',
	['aetherv2/assets/new/rainbow_3.png'] = 'rbxassetid://14368345840',
	['aetherv2/assets/new/rainbow_4.png'] = 'rbxassetid://14368346696',
	['aetherv2/assets/new/range.png'] = 'rbxassetid://14368347435',
	['aetherv2/assets/new/rangearrow.png'] = 'rbxassetid://14368348640',
	['aetherv2/assets/new/rendericon.png'] = 'rbxassetid://14368350193',
	['aetherv2/assets/new/rendertab.png'] = 'rbxassetid://14397373458',
	['aetherv2/assets/new/search.png'] = 'rbxassetid://14425646684',
	['aetherv2/assets/new/targetinfoicon.png'] = 'rbxassetid://14368354234',
	['aetherv2/assets/new/targetnpc1.png'] = 'rbxassetid://14497400332',
	['aetherv2/assets/new/targetnpc2.png'] = 'rbxassetid://14497402744',
	['aetherv2/assets/new/targetplayers1.png'] = 'rbxassetid://14497396015',
	['aetherv2/assets/new/targetplayers2.png'] = 'rbxassetid://14497397862',
	['aetherv2/assets/new/targetstab.png'] = 'rbxassetid://14497393895',
	['aetherv2/assets/new/textguiicon.png'] = 'rbxassetid://14368355456',
	['aetherv2/assets/new/textv4.png'] = 'rbxassetid://14368357095',
	['aetherv2/assets/new/textvape.png'] = 'rbxassetid://14368358200',
	['aetherv2/assets/new/utilityicon.png'] = 'rbxassetid://14368359107',
	['aetherv2/assets/new/vape.png'] = 'rbxassetid://14373395239',
	['aetherv2/assets/new/warning.png'] = 'rbxassetid://14368361552',
	['aetherv2/assets/new/worldicon.png'] = 'rbxassetid://14368362492'
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

local function addBlur(parent, notif)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('aetherv2/assets/new/'..(notif and 'blurnotif' or 'blur')..'.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent

	-- Frosted glass: the sliced blur backdrop supplies the soft shadow/frost,
	-- and the panel itself becomes translucent so layers beneath shine through.
	if parent:IsA('GuiObject') and not notif then
		addGlass(parent)
	end

	return blur
end

-- Corners created with the default radius are registered (weakly, so
-- destroyed ones collect) and can be retuned live from Settings -> Interface.
local cornerRegistry = setmetatable({}, {__mode = 'k'})
local cornerRadius = 10

local function addCorner(parent, radius)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = radius or UDim.new(0, cornerRadius)
	corner.Parent = parent
	if not radius then
		cornerRegistry[corner] = true
	end

	return corner
end

-- v6 re-chrome: a faint hairline edge so windows read as defined cards against the
-- near-black backdrop. Theme-independent (a low-opacity white border), so it never
-- fights the accent. Applied to the main window, category windows and overlays.
local function addWindowStroke(parent, transparency)
	local stroke = Instance.new('UIStroke')
	stroke.Name = 'EdgeStroke'
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = transparency or 0.9
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function addCloseButton(parent, offset)
	local close = Instance.new('ImageButton')
	close.Name = 'Close'
	close.Size = UDim2.fromOffset(24, 24)
	close.Position = UDim2.new(1, -35, 0, offset or 9)
	close.BackgroundColor3 = Color3.new(1, 1, 1)
	close.BackgroundTransparency = 1
	close.AutoButtonColor = false
	close.Image = getcustomasset('aetherv2/assets/new/close.png')
	close.ImageColor3 = color.Light(uipallet.Text, 0.2)
	close.ImageTransparency = 0.5
	close.Parent = parent
	addCorner(close, UDim.new(1, 0))

	close.MouseEnter:Connect(function()
		close.ImageTransparency = 0.3
		tween:Tween(close, uipallet.Tween, {
			BackgroundTransparency = 0.6
		})
	end)
	close.MouseLeave:Connect(function()
		close.ImageTransparency = 0.5
		tween:Tween(close, uipallet.Tween, {
			BackgroundTransparency = 1
		})
	end)

	return close
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
		elseif type(callback) == 'thread' then
			table.insert(self.Connections, {
				Disconnect = function()
					pcall(task.cancel, callback)
				end
			})
		else
			table.insert(self.Connections, callback)
		end
	end
end

local function addTooltip(gui, text)
	if not text then return end

	local function configManagerVisible()
		return mainapi.Categories
			and mainapi.Categories.Profiles
			and mainapi.Categories.Profiles.ConfigManager
			and mainapi.Categories.Profiles.ConfigManager.Visible
	end

	-- Latest cursor position + delayed-show thread, so the configurable
	-- tooltip delay (Settings -> Interface) opens under the cursor's current
	-- location rather than where it entered the control.
	local lastx, lasty = 0, 0
	local pending

	local function cancelPending()
		if pending then
			pcall(task.cancel, pending)
			pending = nil
		end
	end

	-- The ScreenGui uses ZIndexBehavior.Global, and Roblox still fires MouseEnter
	-- on a control even when another panel is drawn over it. Opening the Windows
	-- settings pane over the Rebind GUI button, for instance, let the covered
	-- button pop its tooltip "through" the pane. Only show a tooltip when its
	-- control is actually the front-most thing under the cursor: hit-test the
	-- point and bail if an unrelated interactive element sits in front of us.
	local function occluded()
		local ok, list = pcall(function()
			return mainapi.gui.Parent:GetGuiObjectsAtPosition(lastx, lasty)
		end)
		if not ok or type(list) ~= 'table' or #list == 0 then return false end
		local selfIndex
		for idx, obj in list do
			if obj == gui or obj:IsDescendantOf(gui) or gui:IsDescendantOf(obj) then
				selfIndex = idx
				break
			end
		end
		-- Our control isn't reported under the cursor (coordinate edge cases) -
		-- trust the MouseEnter that got us here rather than wrongly hiding.
		if not selfIndex then return false end
		for idx = 1, selfIndex - 1 do
			local obj = list[idx]
			if (obj.Active or obj:IsA('GuiButton')) and obj ~= gui and not obj:IsDescendantOf(gui) then
				return true
			end
		end
		return false
	end

	local function tooltipMoved(x, y)
		if configManagerVisible() or occluded() then
			tooltip.Visible = false
			return
		end
		local right = x + 16 + tooltip.Size.X.Offset > (scale.Scale * 1920)
		tooltip.Position = UDim2.fromOffset(
			(right and x - (tooltip.Size.X.Offset * scale.Scale) - 16 or x + 16) / scale.Scale,
			((y + 11) - (tooltip.Size.Y.Offset / 2)) / scale.Scale
		)
		tooltip.Visible = toolblur.Visible
	end

	local function show()
		if configManagerVisible() then return end
		local tooltipSize = getfontsize(text, tooltip.TextSize, uipallet.Font)
		tooltip.Size = UDim2.fromOffset(tooltipSize.X + 10, tooltipSize.Y + 10)
		tooltip.Text = text
		tooltipMoved(lastx, lasty)
	end

	gui.MouseEnter:Connect(function(x, y)
		lastx, lasty = x, y
		cancelPending()
		if nexus.Tooltip.Delay > 0 then
			pending = task.delay(nexus.Tooltip.Delay, function()
				pending = nil
				show()
			end)
		else
			show()
		end
	end)
	gui.MouseMoved:Connect(function(x, y)
		lastx, lasty = x, y
		-- Anchored tooltips stay where they opened; following ones track the cursor.
		if tooltip.Visible and not nexus.Tooltip.Follow then return end
		if not pending then
			tooltipMoved(x, y)
		end
	end)
	gui.MouseLeave:Connect(function()
		cancelPending()
		tooltip.Visible = false
	end)
end

--[[
	Custom hover effects. Registered controls receive the user-selected hover
	treatment (Settings -> Interface): an accent underline growing from the
	centre, a single crisp accent outline, a brightness wash, or nothing - plus
	an optional lift (scale pop), hover sound and click pulse. Effect instances
	are created lazily on first hover so unhovered controls cost nothing.

	Only ONE outline is ever shown at a time (tracked in activeOutline): Roblox
	does not fire MouseLeave on a parent when the cursor moves onto a child, so
	without this a slider inside a module row would draw its own border on top of
	the row's - the "borders too much" double-outline. Handing off to the deepest
	hovered control keeps the outline tight and accurate.
]]
local activeOutline
local function addHoverFX(obj, opts)
	opts = opts or {}
	local underline, stroke, wash, lift

	local function accent()
		return Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
	end

	local function setHover(on)
		local style = nexus.Hover.Style
		local strength = nexus.Hover.Intensity
		if (on and style == 'Underline') or underline then
			if not underline then
				underline = Instance.new('Frame')
				underline.Name = 'HoverUnderline'
				underline.AnchorPoint = Vector2.new(0.5, 1)
				underline.Position = UDim2.new(0.5, 0, 1, 0)
				underline.Size = UDim2.new(0, 0, 0, 2)
				underline.BorderSizePixel = 0
				-- The ScreenGui uses ZIndexBehavior.Global, so ZIndex is compared
				-- across the whole GUI: anything above obj.ZIndex renders on top of
				-- settings panes/windows opened over this control. Matching
				-- obj.ZIndex keeps the effect above its own control (children draw
				-- after parents on ties) but below every panel layered over it.
				underline.ZIndex = obj.ZIndex
				underline.Parent = obj
			end
			local active = on and style == 'Underline'
			underline.BackgroundColor3 = accent()
			underline.BackgroundTransparency = 1 - (0.9 * strength)
			tween:Tween(underline, uipallet.Tween, {
				Size = active and UDim2.new(1, -16, 0, 2) or UDim2.new(0, 0, 0, 2)
			})
		end
		if (on and style == 'Outline') or stroke then
			if not stroke then
				stroke = Instance.new('UIStroke')
				stroke.Name = 'HoverOutline'
				stroke.Thickness = 1
				stroke.Transparency = 1
				-- Round joins + Border mode make the stroke hug the control's own
				-- UICorner so it traces the rounded shape instead of a hard box.
				stroke.LineJoinMode = Enum.LineJoinMode.Round
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = obj
			end
			local active = on and style == 'Outline'
			if active then
				if activeOutline and activeOutline ~= stroke and activeOutline.Parent then
					tweenService:Create(activeOutline, uipallet.Tween, {Transparency = 1}):Play()
				end
				activeOutline = stroke
			elseif activeOutline == stroke then
				activeOutline = nil
			end
			stroke.Color = accent()
			tweenService:Create(stroke, uipallet.Tween, {
				Transparency = active and 1 - (0.75 * strength) or 1
			}):Play()
		end
		if (on and style == 'Brighten') or wash then
			if not wash then
				wash = Instance.new('Frame')
				wash.Name = 'HoverWash'
				wash.Size = UDim2.fromScale(1, 1)
				wash.BackgroundColor3 = Color3.new(1, 1, 1)
				wash.BackgroundTransparency = 1
				wash.BorderSizePixel = 0
				-- Same Global-ZIndex constraint as the underline above.
				wash.ZIndex = obj.ZIndex
				wash.Parent = obj
			end
			tween:Tween(wash, uipallet.Tween, {
				BackgroundTransparency = (on and style == 'Brighten') and 1 - (0.1 * strength) or 1
			})
		end
		if (on and nexus.Hover.Lift) or lift then
			if not lift then
				lift = Instance.new('UIScale')
				lift.Name = 'HoverLift'
				lift.Parent = obj
			end
			local active = on and nexus.Hover.Lift
			-- A springy Back/Out ease on the way up reads as the control rising
			-- to meet the cursor; a plain settle on the way down avoids overshoot.
			tweenService:Create(lift, active
				and TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				or TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = active and 1.035 or 1
			}):Play()
		end
	end

	obj.MouseEnter:Connect(function()
		setHover(true)
		-- Fired straight off the input event (not gated behind a tween) so the
		-- tick lands the instant the cursor arrives instead of lagging behind it.
		if nexus.Hover.Sounds then
			nexus.PlaySound('hover')
		end
	end)
	obj.MouseLeave:Connect(function()
		setHover(false)
	end)
	if obj:IsA('GuiButton') and opts.Ripple ~= false then
		obj.MouseButton1Down:Connect(function()
			if nexus.Hover.Pulse then
				nexus.SpawnRipple(obj)
			end
			if nexus.Hover.Sounds then
				nexus.PlaySound('click')
			end
		end)
	end

	return obj
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
		if not downloader and not license.Closet then
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
		pcall(function()
			downloader.Text = 'Downloading '..text
		end)
	end
end

local function createMobileButton(buttonapi, position)
	local heldbutton = false
	local button = Instance.new('TextButton')
	button.Size = UDim2.fromOffset(40, 40)
	button.Position = UDim2.fromOffset(position.X, position.Y)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = buttonapi.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
	button.BackgroundTransparency = 0.5
	button.Text = buttonapi.Name
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.Gotham
	button.Parent = mainapi.gui
	local buttonconstraint = Instance.new('UITextSizeConstraint')
	buttonconstraint.MaxTextSize = 16
	buttonconstraint.Parent = button
	addCorner(button, UDim.new(1, 0))

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

getcustomasset = assetfunction and function(path)
	local suc, res = pcall(downloadFile, path, assetfunction)
	if suc then
		return res
	end
	return getcustomassets[path] or ''
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

local configFolder = 'aetherv2/configs'
local profileFolder = 'aetherv2/profiles'

local function ensureFolder(path)
	if makefolder and (not isfolder or not isfolder(path)) then
		pcall(makefolder, path)
	end
end

local function ensureDataFolders()
	ensureFolder('aetherv2')
	ensureFolder(profileFolder)
	ensureFolder(configFolder)
end

local function getConfigPath(profile)
	return configFolder..'/'..profile..mainapi.Place..'.json'
end

local function getLegacyProfilePath(profile)
	return profileFolder..'/'..profile..mainapi.Place..'.txt'
end

local function refreshConfigProfiles()
	local profiles, seen = {}, {}
	local function addProfile(name, bind)
		name = type(name) == 'string' and name:gsub('^%s*(.-)%s*$', '%1') or ''
		if name ~= '' and not seen[name] then
			seen[name] = true
			table.insert(profiles, {Name = name, Bind = bind or {}})
		end
	end

	for _, profile in mainapi.Profiles do
		addProfile(profile.Name, profile.Bind)
	end

	if listfiles then
		local suffix = tostring(mainapi.Place)..'.json'
		local suc, files = pcall(listfiles, configFolder)
		if suc then
			for _, path in files do
				local file = tostring(path):gsub('\\', '/')
				local name = file:match('/([^/]+)'..suffix:gsub('%.', '%%.')..'$')
				if name then
					addProfile(name)
				end
			end
		end
	end

	addProfile('default')
	table.sort(profiles, function(a, b)
		if a.Name == 'default' then return true end
		if b.Name == 'default' then return false end
		return a.Name:lower() < b.Name:lower()
	end)
	mainapi.Profiles = profiles
	return profiles
end

ensureDataFolders()

local defaultConfigs = {}

local function installBundledConfig(name, force)
	local sourcePath = 'aetherv2/configs/'..name..'.json'
	if force or not isfile(sourcePath) then
		local downloaded = pcall(downloadFile, sourcePath)
		if not downloaded then return false end
	end
	local wrapper = loadJson(sourcePath)
	if not wrapper then return false end
	local configName = wrapper.name or name
	local configPath = getConfigPath(configName)
	if force or not isfile(configPath) then
		writefile(configPath, wrapper.config or '{}')
	end
	if wrapper.gui then
		local guiPath = 'aetherv2/profiles/'..game.GameId..'.gui.txt'
		local guidata = isfile(guiPath) and loadJson(guiPath) or nil
		local defaultGui = httpService:JSONDecode(wrapper.gui)
		guidata = guidata or defaultGui
		guidata.Profiles = guidata.Profiles or {}
		local exists = false
		for _, profile in guidata.Profiles do
			if profile.Name == configName then
				exists = true
				break
			end
		end
		if not exists then
			table.insert(guidata.Profiles, {Name = configName, Bind = {}})
			writefile(guiPath, httpService:JSONEncode(guidata))
		end
	end
	return true
end

local function applySavedConfig(name)
	name = type(name) == 'string' and name:gsub('^%s*(.-)%s*$', '%1') or ''
	if name == '' then return false end
	mainapi:Save()
	mainapi:Load(true, name)
	mainapi:Save(name)
	return true
end

local function decodeJsonText(text)
	if type(text) ~= 'string' or text:gsub('%s+', '') == '' then return nil end
	local suc, res = pcall(function()
		return httpService:JSONDecode(text)
	end)
	return suc and type(res) == 'table' and res or nil
end

local function importJsonConfig(text, requestedName)
	local imported = decodeJsonText(text)
	if not imported then
		return false, 'The imported JSON is invalid.'
	end

	local configText = imported.config
	local configData = type(configText) == 'string' and decodeJsonText(configText) or type(configText) == 'table' and configText or imported
	if not configData then
		return false, 'The imported config data is invalid.'
	end

	local rawName = requestedName or imported.name or imported.profile or imported.Profile or ('imported-'..os.date('%Y%m%d-%H%M%S'))
	local configName = tostring(rawName):gsub('[\\/:*?"<>|]', '-'):gsub('^%s*(.-)%s*$', '%1')
	if configName == '' then
		configName = 'imported-'..os.date('%Y%m%d-%H%M%S')
	end

	ensureDataFolders()
	writefile(getConfigPath(configName), httpService:JSONEncode(configData))

	local guiPath = 'aetherv2/profiles/'..game.GameId..'.gui.txt'
	local guidata = isfile(guiPath) and loadJson(guiPath) or {Categories = {}, Profiles = mainapi.Profiles or {{Name = 'default', Bind = {}}}}
	if type(imported.gui) == 'string' then
		local importedGui = decodeJsonText(imported.gui)
		if importedGui then
			guidata.Categories = importedGui.Categories or guidata.Categories or {}
			guidata.Keybind = importedGui.Keybind or guidata.Keybind
		end
	end

	guidata.Profiles = guidata.Profiles or {}
	local found = false
	for _, profile in guidata.Profiles do
		if profile.Name == configName then
			found = true
			break
		end
	end
	if not found then
		table.insert(guidata.Profiles, {Name = configName, Bind = {}})
	end
	guidata.Profile = configName
	writefile(guiPath, httpService:JSONEncode(guidata))

	refreshConfigProfiles()
	mainapi:Load(true, configName)
	mainapi:Save(configName)
	return true, configName
end

local function installBundledConfigs(force)
	local installed = false
	for _, name in defaultConfigs do
		installed = installBundledConfig(name, force) or installed
	end
	refreshConfigProfiles()
	return installed
end

local function removeSavedConfig(name)
	name = type(name) == 'string' and name:gsub('^%s*(.-)%s*$', '%1') or ''
	if name == '' or name == 'default' then return false end
	if isfile(getConfigPath(name)) and delfile then
		delfile(getConfigPath(name))
	end
	for i = #mainapi.Profiles, 1, -1 do
		if mainapi.Profiles[i].Name == name then
			table.remove(mainapi.Profiles, i)
		end
	end
	if mainapi.Profile == name then
		mainapi.Profile = 'default'
	end
	mainapi:Save(mainapi.Profile)
	refreshConfigProfiles()
	return true
end

--[[
	Resetting the active profile.

	Deleting the config file never actually reset anything, because that is only one of
	four places a profile is written to:

	  * configs/<profile><place>.json - modules, their settings and binds, Legit, Kits,
	    the favourites order, and the config's own accent and menu key.
	  * profiles/<profile><place>.txt - a mirror of exactly the same data, which Load
	    falls back to when the config is missing. Deleting the config alone therefore
	    restored the whole profile from here on the very next injection, which is what
	    "reset doesn't reset" was.
	  * profiles/<GameId>.gui.txt - every GUI settings pane, each window's position, the
	    menu keybind and the per-profile binds.
	  * a handful of loose files - the forced game file, the GUI theme, the loading
	    screen and mobile button toggles.

	All four go. The list of configs and which one is active are not settings, so they are
	carried over: a reset lands back on the same profile with nothing else left of it.
]]
function configapi.ResetProfile()
	local profile = mainapi.Profile or 'default'

	-- Nothing may write the in-memory state back out from under the reset. The autosave
	-- loop runs every ten seconds and Uninject saves on its way out, and either one would
	-- put the profile straight back.
	mainapi.Loaded = false
	mainapi.Save = function() end

	ensureDataFolders()

	for _, path in {getConfigPath(profile), getLegacyProfilePath(profile)} do
		if isfile(path) and delfile then
			pcall(delfile, path)
		end
	end

	local profiles = {}
	for _, entry in mainapi.Profiles or {} do
		if type(entry) == 'table' and entry.Name then
			-- Profile keybinds are settings, so they do not survive.
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

	-- Drop the accent stamp as well, so the reload lands on the current default accent
	-- whatever this install had been carrying.
	if isfile(configapi.Accents.Path) and delfile then
		pcall(delfile, configapi.Accents.Path)
	end

	return profile
end

--[[
	Which configs came from the repo.

	The Configs window offers to re-download the config you are on, but only when it came
	from the published preset list, and nothing about a config on disk says where it came
	from. So it is written down: loading a preset records which file it came from, and
	listing the presets tops the record up. It lives beside the configs, so the offer is
	there on the next injection without the browser having been opened.
]]
configapi.Presets = {
	Path = profileFolder..'/presetconfigs.json'
}
configapi.Presets.Registry = (isfile(configapi.Presets.Path) and loadJson(configapi.Presets.Path)) or {}

-- Where the published configs live. Pinned to the commit this install is on, so the list and
-- the files it names always come from the same tree.
function configapi.Presets.Base()
	local commit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt') or 'main'
	return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/configs/'
end

function configapi.Presets.Remember(configName, preset)
	if type(configName) ~= 'string' or configName == '' then return end
	if type(preset) ~= 'table' or type(preset.file) ~= 'string' or preset.file == '' then return end
	local entry = configapi.Presets.Registry[configName]
	if entry and entry.file == preset.file and entry.name == preset.name then return end
	configapi.Presets.Registry[configName] = {file = preset.file, name = preset.name or configName}
	pcall(writefile, configapi.Presets.Path, httpService:JSONEncode(configapi.Presets.Registry))
end

function configapi.Presets.Get(configName)
	local entry = type(configName) == 'string' and configapi.Presets.Registry[configName] or nil
	return type(entry) == 'table' and type(entry.file) == 'string' and entry or nil
end

--[[
	profiles/features.json drives the little pills drawn on the right of each
	module row. Expected shape:
		{
			"newModules": [...],
			"updatedModules": [...]
		}
	Each list becomes a tag ('NEW', 'UPDATED') on every module it
	names. A bare array is still accepted and treated as newModules, which is
	the format the file used before the three lists existed.

	Names are matched loosely (case and separators ignored) so the file can say
	'krystal disabler' for a module registered as 'KrystalDisabler'.
]]
local featureLists = {
	{Tag = 'new', Key = 'newModules'},
	{Tag = 'updated', Key = 'updatedModules'}
}
local featureTags = {}

local function moduleTagKey(name)
	return (tostring(name):lower():gsub('[^%a%d]', ''))
end

do
	local path = 'aetherv2/profiles/features.json'
	local data
	-- features.json is repository metadata, not a user profile. Older clients
	-- cached it forever because it lives under profiles/, so refresh it from the
	-- selected commit before modules are created and fall back to disk offline.
	pcall(function()
		local commit = readfile('aetherv2/profiles/commit.txt')
		local body = game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/profiles/features.json', true)
		local decoded = httpService:JSONDecode(body)
		if type(decoded) == 'table' then
			data = decoded
			writefile(path, body)
		end
	end)
	if not data then
		pcall(downloadFile, path)
		data = loadJson(path) or {}
	end
	if #data > 0 then
		data = {newModules = data}
	end
	for _, list in featureLists do
		local names = data[list.Key]
		if type(names) == 'table' then
			for _, name in names do
				if type(name) == 'string' and name ~= '' then
					local key = moduleTagKey(name)
					featureTags[key] = featureTags[key] or {}
					table.insert(featureTags[key], list.Tag)
				end
			end
		end
	end
end

-- Appends the feature tags for a module onto its existing tag list, skipping
-- any it already carries.
local function applyFeatureTags(tags, name)
	for _, tag in featureTags[moduleTagKey(name)] or {} do
		local duplicate = false
		for _, existing in tags do
			if type(existing) == 'string' and existing:lower() == tag then
				duplicate = true
				break
			end
		end
		if not duplicate then
			table.insert(tags, tag)
		end
	end
end
--[[
	Custom positioning. Dragging honours the live settings in nexus.Drag
	(Settings -> Windows): grid snapping, screen-edge and window-to-window
	snapping with accent alignment guides, keep-on-screen clamping, drag
	smoothing and a global window lock. All maths happens in the scaled
	coordinate space every window position already uses (screen px / scale).
]]
local function makeDraggable(gui, window)
	-- Snaps a proposed position and reports which alignment edges (if any)
	-- were matched so guides can be drawn along them.
	local function applySnap(pos)
		local guideX, guideY
		if nexus.Drag.Grid then
			local grid = math.max(nexus.Drag.GridSize, 2)
			pos = Vector2.new(math.round(pos.X / grid) * grid, math.round(pos.Y / grid) * grid)
		end
		local size = gui.AbsoluteSize / scale.Scale
		local screen = mainapi.gui and mainapi.gui.AbsoluteSize / scale.Scale or Vector2.new(1920, 1080)
		local dist = nexus.Drag.SnapDistance
		if nexus.Drag.EdgeSnap then
			if math.abs(pos.X) < dist then
				pos = Vector2.new(0, pos.Y)
			elseif math.abs(screen.X - (pos.X + size.X)) < dist then
				pos = Vector2.new(screen.X - size.X, pos.Y)
			end
			if math.abs(pos.Y) < dist then
				pos = Vector2.new(pos.X, 0)
			elseif math.abs(screen.Y - (pos.Y + size.Y)) < dist then
				pos = Vector2.new(pos.X, screen.Y - size.Y)
			end
		end
		if nexus.Drag.WindowSnap then
			for _, v in mainapi.Categories do
				local other = v.Object
				if typeof(other) ~= 'Instance' or other == gui or not other.Visible then continue end
				local opos = Vector2.new(other.Position.X.Offset, other.Position.Y.Offset)
				local osize = other.AbsoluteSize / scale.Scale
				-- Align left edge / right-of / left-of the other window.
				for _, edge in {opos.X, opos.X + osize.X, opos.X - size.X} do
					if math.abs(pos.X - edge) < dist then
						pos = Vector2.new(edge, pos.Y)
						guideX = edge
						break
					end
				end
				for _, edge in {opos.Y, opos.Y + osize.Y, opos.Y - size.Y} do
					if math.abs(pos.Y - edge) < dist then
						pos = Vector2.new(pos.X, edge)
						guideY = edge
						break
					end
				end
			end
		end
		-- Sort-GUI lattice snapping. The "Sort GUI" button lays windows out on a
		-- fixed lattice (origin 6,60 stepping 230px across, wrapping to a second
		-- row at y=420). Snapping a hand-dragged window to that same lattice means
		-- manual placement lines up perfectly with one-click sorting, instead of
		-- landing a few pixels off. Shares the edge-snapping toggle.
		if nexus.Drag.EdgeSnap then
			local originX, stepX = 6, 230
			local col = math.round((pos.X - originX) / stepX)
			if col >= 0 then
				local snapX = originX + col * stepX
				if math.abs(pos.X - snapX) < dist then
					pos = Vector2.new(snapX, pos.Y)
					guideX = guideX or snapX
				end
			end
			for _, row in {60, 420} do
				if math.abs(pos.Y - row) < dist then
					pos = Vector2.new(pos.X, row)
					guideY = guideY or row
					break
				end
			end
		end
		if nexus.Drag.Clamp then
			pos = Vector2.new(
				math.clamp(pos.X, 0, math.max(screen.X - size.X, 0)),
				math.clamp(pos.Y, 0, math.max(screen.Y - size.Y, 0))
			)
		end
		return pos, guideX, guideY
	end

	gui.InputBegan:Connect(function(inputObj)
		if window and not window.Visible then return end
		if nexus.Drag.Lock then return end
		if
			(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
			and (inputObj.Position.Y - gui.AbsolutePosition.Y < 40 or window)
		then
			local dragPosition = Vector2.new(
				gui.AbsolutePosition.X - inputObj.Position.X,
				gui.AbsolutePosition.Y - inputObj.Position.Y + guiService:GetGuiInset().Y
			) / scale.Scale
			local target
			local moved = false

			local changed = inputService.InputChanged:Connect(function(input)
				if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
					moved = true
					local position = input.Position
					if inputService:IsKeyDown(Enum.KeyCode.LeftShift) then
						dragPosition = (dragPosition // 3) * 3
						position = (position // 3) * 3
					end
					local pos, guideX, guideY = applySnap(Vector2.new(
						(position.X / scale.Scale) + dragPosition.X,
						(position.Y / scale.Scale) + dragPosition.Y
					))
					nexus.ShowGuides(guideX, guideY)
					if nexus.Drag.Smoothing > 0 then
						target = pos
					else
						target = nil
						gui.Position = UDim2.fromOffset(pos.X, pos.Y)
					end
				end
			end)

			-- Drag smoothing: the window eases toward the latest target
			-- instead of jumping to it.
			local smoothed = runService.RenderStepped:Connect(function(dt)
				if target and nexus.Drag.Smoothing > 0 then
					local current = Vector2.new(gui.Position.X.Offset, gui.Position.Y.Offset)
					local eased = current:Lerp(target, math.clamp(dt / math.max(nexus.Drag.Smoothing, 0.01), 0, 1))
					gui.Position = UDim2.fromOffset(eased.X, eased.Y)
				end
			end)

			local ended
			ended = inputObj.Changed:Connect(function()
				if inputObj.UserInputState == Enum.UserInputState.End then
					if changed then
						changed:Disconnect()
					end
					if smoothed then
						smoothed:Disconnect()
					end
					if target then
						gui.Position = UDim2.fromOffset(target.X, target.Y)
					end
					nexus.HideGuides()
					if moved then
						nexus.OnWindowMoved(gui)
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
			res.Font:find('rbxasset') and res.Font
			or string.format('rbxasset://fonts/families/%s.json', res.Font)
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

	function mainapi:TextColor(h, s, v)
		-- Pick text colour from the accent's actual relative luminance rather
		-- than a hue heuristic, so every accent the theme slider can produce
		-- keeps readable text on enabled buttons, tags and accent controls.
		local col = Color3.fromHSV(h, s, v)
		local luminance = 0.2126 * col.R + 0.7152 * col.G + 0.0722 * col.B
		if luminance > 0.5 then
			return Color3.new(0.19, 0.19, 0.19)
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
		button.Size = UDim2.new(1, 0, 0, 31)
		button.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(button)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Visible = optionsettings.Visible == nil or optionsettings.Visible
		button.Text = ''
		button.Parent = children
		addTooltip(button, optionsettings.Tooltip)
		addHoverFX(button)
		local bkg = Instance.new('Frame')
		bkg.Size = UDim2.fromOffset(200, 27)
		bkg.Position = UDim2.fromOffset(10, 2)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
		bkg.Parent = button
		addCorner(bkg)
		local label = Instance.new('TextLabel')
		label.Size = UDim2.new(1, -4, 1, -4)
		label.Position = UDim2.fromOffset(2, 2)
		label.BackgroundColor3 = uipallet.Main
		label.Text = optionsettings.Name
		label.TextColor3 = color.Dark(uipallet.Text, 0.16)
		label.TextSize = 14
		label.FontFace = uipallet.Font
		label.Parent = bkg
		addCorner(label, UDim.new(0, 4))
		optionsettings.Function = optionsettings.Function or function() end
		
		button.MouseEnter:Connect(function()
			tween:Tween(bkg, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.0875)
			})
		end)
		button.MouseLeave:Connect(function()
			tween:Tween(bkg, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.05)
			})
		end)
		button.MouseButton1Click:Connect(optionsettings.Function)

		-- Expose the button and its label so callers can give feedback (eg. flashing
		-- "Copied!" on the Export to JSON button). Existing callers ignore the return.
		return {Object = button, Label = label, Name = optionsettings.Name}
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
			slider.Size = UDim2.new(1, 0, 0, 50)
			slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
			addGlass(slider)
			slider.BorderSizePixel = 0
			slider.AutoButtonColor = false
			slider.Visible = false
			slider.Text = ''
			slider.Parent = children
			local title = Instance.new('TextLabel')
			title.Name = 'Title'
			title.Size = UDim2.fromOffset(60, 30)
			title.Position = UDim2.fromOffset(10, 2)
			title.BackgroundTransparency = 1
			title.Text = name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = color.Dark(uipallet.Text, 0.16)
			title.TextSize = 11
			title.FontFace = uipallet.Font
			title.Parent = slider
			local bkg = Instance.new('Frame')
			bkg.Name = 'Slider'
			bkg.Size = UDim2.new(1, -20, 0, 2)
			bkg.Position = UDim2.fromOffset(10, 37)
			bkg.BackgroundColor3 = Color3.new(1, 1, 1)
			bkg.BorderSizePixel = 0
			bkg.Parent = slider
			local gradient = Instance.new('UIGradient')
			gradient.Color = gradientColor
			gradient.Parent = bkg
			local fill = bkg:Clone()
			fill.Name = 'Fill'
			fill.Size = UDim2.fromScale(math.clamp(name == 'Saturation' and optionapi.Sat or name == 'Vibrance' and optionapi.Value or optionapi.Opacity, 0.04, 0.96), 1)
			fill.Position = UDim2.new()
			fill.BackgroundTransparency = 1
			fill.Parent = bkg
			local knobholder = Instance.new('Frame')
			knobholder.Name = 'Knob'
			knobholder.Size = UDim2.fromOffset(24, 4)
			knobholder.Position = UDim2.fromScale(1, 0.5)
			knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
			knobholder.BackgroundColor3 = slider.BackgroundColor3
			knobholder.BorderSizePixel = 0
			knobholder.Parent = fill
			local knob = Instance.new('Frame')
			knob.Name = 'Knob'
			knob.Size = UDim2.fromOffset(14, 14)
			knob.Position = UDim2.fromScale(0.5, 0.5)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.BackgroundColor3 = uipallet.Text
			knob.Parent = knobholder
			addCorner(knob, UDim.new(1, 0))
		
			slider.InputBegan:Connect(function(inputObj)
				if
					(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
					and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
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
			slider.MouseEnter:Connect(function()
				tween:Tween(knob, uipallet.Tween, {
					Size = UDim2.fromOffset(16, 16)
				})
			end)
			slider.MouseLeave:Connect(function()
				tween:Tween(knob, uipallet.Tween, {
					Size = UDim2.fromOffset(14, 14)
				})
			end)
		
			return slider
		end
		
		local slider = Instance.new('TextButton')
		slider.Name = optionsettings.Name..'Slider'
		slider.Size = UDim2.new(1, 0, 0, 50)
		slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(slider)
		slider.BorderSizePixel = 0
		slider.AutoButtonColor = false
		slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
		slider.Text = ''
		slider.Parent = children
		addTooltip(slider, optionsettings.Tooltip)
		addHoverFX(slider, {Ripple = false})
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.fromOffset(60, 30)
		title.Position = UDim2.fromOffset(10, 2)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 11
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
		bkg.Size = UDim2.new(1, -20, 0, 2)
		bkg.Position = UDim2.fromOffset(10, 39)
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
		fill.Size = UDim2.fromScale(math.clamp(optionapi.Hue, 0.04, 0.96), 1)
		fill.Position = UDim2.new()
		fill.BackgroundTransparency = 1
		fill.Parent = bkg
		local preview = Instance.new('ImageButton')
		preview.Name = 'Preview'
		preview.Size = UDim2.fromOffset(12, 12)
		preview.Position = UDim2.new(1, -22, 0, 10)
		preview.BackgroundTransparency = 1
		preview.Image = getcustomasset('aetherv2/assets/new/colorpreview.png')
		preview.ImageColor3 = Color3.fromHSV(optionapi.Hue, optionapi.Sat, optionapi.Value)
		preview.ImageTransparency = 1 - optionapi.Opacity
		preview.Parent = slider
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
		local rainbow1 = Instance.new('ImageLabel')
		rainbow1.Size = UDim2.fromOffset(12, 12)
		rainbow1.BackgroundTransparency = 1
		rainbow1.Image = getcustomasset('aetherv2/assets/new/rainbow_1.png')
		rainbow1.ImageColor3 = color.Light(uipallet.Main, 0.37)
		rainbow1.Parent = rainbow
		local rainbow2 = rainbow1:Clone()
		rainbow2.Image = getcustomasset('aetherv2/assets/new/rainbow_2.png')
		rainbow2.Parent = rainbow
		local rainbow3 = rainbow1:Clone()
		rainbow3.Image = getcustomasset('aetherv2/assets/new/rainbow_3.png')
		rainbow3.Parent = rainbow
		local rainbow4 = rainbow1:Clone()
		rainbow4.Image = getcustomasset('aetherv2/assets/new/rainbow_4.png')
		rainbow4.Parent = rainbow
		local knobholder = Instance.new('Frame')
		knobholder.Name = 'Knob'
		knobholder.Size = UDim2.fromOffset(24, 4)
		knobholder.Position = UDim2.fromScale(1, 0.5)
		knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
		knobholder.BackgroundColor3 = slider.BackgroundColor3
		knobholder.BorderSizePixel = 0
		knobholder.Parent = fill
		local knob = Instance.new('Frame')
		knob.Name = 'Knob'
		knob.Size = UDim2.fromOffset(14, 14)
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = uipallet.Text
		knob.Parent = knobholder
		addCorner(knob, UDim.new(1, 0))
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
			-- brought forward to the current accent. Only options that take their default
			-- from the accent qualify, and only until the migration stamp is written.
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
			preview.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
			preview.ImageTransparency = 1 - self.Opacity
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
				fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
			else
				tween:Tween(fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
				})
			end
		
			if s then
				tween:Tween(satSlider.Slider.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
				})
			end
			if v then
				tween:Tween(vibSlider.Slider.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
				})
			end
			if o then
				tween:Tween(opSlider.Slider.Fill, uipallet.Tween, {
					Size = UDim2.fromScale(math.clamp(self.Opacity, 0.04, 0.96), 1)
				})
			end
		
			optionsettings.Function(self.Hue, self.Sat, self.Value, self.Opacity)
		end
		
		function optionapi:Toggle()
			self.Rainbow = not self.Rainbow
			if self.Rainbow then
				table.insert(mainapi.RainbowTable, self)
				rainbow1.ImageColor3 = Color3.fromRGB(5, 127, 100)
				task.delay(0.1, function()
					if not self.Rainbow then return end
					rainbow2.ImageColor3 = Color3.fromRGB(228, 125, 43)
					task.delay(0.1, function()
						if not self.Rainbow then return end
						rainbow3.ImageColor3 = Color3.fromRGB(225, 46, 52)
					end)
				end)
			else
				local ind = table.find(mainapi.RainbowTable, self)
				if ind then
					table.remove(mainapi.RainbowTable, ind)
				end
				rainbow3.ImageColor3 = color.Light(uipallet.Main, 0.37)
				task.delay(0.1, function()
					if self.Rainbow then return end
					rainbow2.ImageColor3 = color.Light(uipallet.Main, 0.37)
					task.delay(0.1, function()
						if self.Rainbow then return end
						rainbow1.ImageColor3 = color.Light(uipallet.Main, 0.37)
					end)
				end)
			end
		end
		
		local doubleClick = tick()
		preview.MouseButton1Click:Connect(function()
			preview.Visible = false
			valuebox.Visible = true
			valuebox:CaptureFocus()
			local text = Color3.fromHSV(optionapi.Hue, optionapi.Sat, optionapi.Value)
			valuebox.Text = math.round(text.R * 255)..', '..math.round(text.G * 255)..', '..math.round(text.B * 255)
		end)
		slider.InputBegan:Connect(function(inputObj)
			if
				(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
				and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
				if doubleClick > tick() then
					optionapi:Toggle()
				end
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
		slider.MouseEnter:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(16, 16)
			})
		end)
		slider.MouseLeave:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(14, 14)
			})
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
		rainbow.MouseButton1Click:Connect(function()
			optionapi:Toggle()
		end)
		valuebox.FocusLost:Connect(function(enter)
			preview.Visible = true
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
		dropdown.Size = UDim2.new(1, 0, 0, 40)
		dropdown.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(dropdown)
		dropdown.BorderSizePixel = 0
		dropdown.AutoButtonColor = false
		dropdown.Visible = optionsettings.Visible == nil or optionsettings.Visible
		dropdown.Text = ''
		dropdown.Parent = children
		addTooltip(dropdown, optionsettings.Tooltip or optionsettings.Name)
		addHoverFX(dropdown, {Ripple = false})
		local bkg = Instance.new('Frame')
		bkg.Name = 'BKG'
		bkg.Size = UDim2.new(1, -20, 1, -9)
		bkg.Position = UDim2.fromOffset(10, 4)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		bkg.Parent = dropdown
		addCorner(bkg, UDim.new(0, 6))
		local button = Instance.new('TextButton')
		button.Name = 'Dropdown'
		button.Size = UDim2.new(1, -2, 1, -2)
		button.Position = UDim2.fromOffset(1, 1)
		button.BackgroundColor3 = uipallet.Main
		button.AutoButtonColor = false
		button.Text = ''
		button.Parent = bkg
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, 0, 0, 29)
		title.BackgroundTransparency = 1
		title.Text = '         '..optionsettings.Name..' - '..optionapi.Value
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 13
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.FontFace = uipallet.Font
		title.Parent = button
		addCorner(button, UDim.new(0, 6))
		local arrow = Instance.new('ImageLabel')
		arrow.Name = 'Arrow'
		arrow.Size = UDim2.fromOffset(4, 8)
		arrow.Position = UDim2.new(1, -17, 0, 11)
		arrow.BackgroundTransparency = 1
		arrow.Image = getcustomasset('aetherv2/assets/new/expandright.png')
		arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		arrow.Rotation = 90
		arrow.Parent = button
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
			title.Text = '         '..optionsettings.Name..' - '..self.Value
			if dropdownchildren then
				arrow.Rotation = 90
				dropdownchildren:Destroy()
				dropdownchildren = nil
				dropdown.Size = UDim2.new(1, 0, 0, 40)
			end
			optionsettings.Function(self.Value, mouse)
		end
		
		button.MouseButton1Click:Connect(function()
			if not dropdownchildren then
				arrow.Rotation = 270
				dropdown.Size = UDim2.new(1, 0, 0, 40 + (#optionsettings.List - 1) * 26)
				dropdownchildren = Instance.new('Frame')
				dropdownchildren.Name = 'Children'
				dropdownchildren.Size = UDim2.new(1, 0, 0, (#optionsettings.List - 1) * 26)
				dropdownchildren.Position = UDim2.fromOffset(0, 27)
				dropdownchildren.BackgroundTransparency = 1
				dropdownchildren.Parent = button
				local ind = 0
				for _, v in optionsettings.List do
					if v == optionapi.Value then continue end
					local dropdownoption = Instance.new('TextButton')
					dropdownoption.Name = v..'Option'
					dropdownoption.Size = UDim2.new(1, 0, 0, 26)
					dropdownoption.Position = UDim2.fromOffset(0, ind * 26)
					dropdownoption.BackgroundColor3 = uipallet.Main
					dropdownoption.BorderSizePixel = 0
					dropdownoption.AutoButtonColor = false
					dropdownoption.Text = '         '..v
					dropdownoption.TextXAlignment = Enum.TextXAlignment.Left
					dropdownoption.TextColor3 = color.Dark(uipallet.Text, 0.16)
					dropdownoption.TextSize = 13
					dropdownoption.TextTruncate = Enum.TextTruncate.AtEnd
					dropdownoption.FontFace = uipallet.Font
					dropdownoption.Parent = dropdownchildren
					dropdownoption.MouseEnter:Connect(function()
						tween:Tween(dropdownoption, uipallet.Tween, {
							BackgroundColor3 = color.Light(uipallet.Main, 0.02)
						})
					end)
					dropdownoption.MouseLeave:Connect(function()
						tween:Tween(dropdownoption, uipallet.Tween, {
							BackgroundColor3 = uipallet.Main
						})
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
		dropdown.MouseEnter:Connect(function()
			tween:Tween(bkg, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.0875)
			})
		end)
		dropdown.MouseLeave:Connect(function()
			tween:Tween(bkg, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			})
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
		slider.Size = UDim2.new(1, 0, 0, 50)
		slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(slider)
		slider.BorderSizePixel = 0
		slider.AutoButtonColor = false
		slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
		slider.Text = ''
		slider.Parent = children
		addTooltip(slider, optionsettings.Tooltip)
		addHoverFX(slider, {Ripple = false})
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.fromOffset(60, 30)
		title.Position = UDim2.fromOffset(10, 2)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 11
		title.FontFace = uipallet.Font
		title.Parent = slider
		local valuebutton = Instance.new('TextButton')
		valuebutton.Name = 'Value'
		valuebutton.Size = UDim2.fromOffset(60, 15)
		valuebutton.Position = UDim2.new(1, -69, 0, 9)
		valuebutton.BackgroundTransparency = 1
		valuebutton.Text = optionapi.Value..(optionsettings.Suffix and ' '..(type(optionsettings.Suffix) == 'function' and optionsettings.Suffix(optionapi.Value) or optionsettings.Suffix) or '')
		valuebutton.TextXAlignment = Enum.TextXAlignment.Right
		valuebutton.TextColor3 = color.Dark(uipallet.Text, 0.16)
		valuebutton.TextSize = 11
		valuebutton.FontFace = uipallet.Font
		valuebutton.Parent = slider
		local valuebox = Instance.new('TextBox')
		valuebox.Name = 'Box'
		valuebox.Size = valuebutton.Size
		valuebox.Position = valuebutton.Position
		valuebox.BackgroundTransparency = 1
		valuebox.Visible = false
		valuebox.Text = optionapi.Value
		valuebox.TextXAlignment = Enum.TextXAlignment.Right
		valuebox.TextColor3 = color.Dark(uipallet.Text, 0.16)
		valuebox.TextSize = 11
		valuebox.FontFace = uipallet.Font
		valuebox.ClearTextOnFocus = false
		valuebox.Parent = slider
		local bkg = Instance.new('Frame')
		bkg.Name = 'Slider'
		bkg.Size = UDim2.new(1, -20, 0, 2)
		bkg.Position = UDim2.fromOffset(10, 37)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		bkg.BorderSizePixel = 0
		bkg.Parent = slider
		local fill = bkg:Clone()
		fill.Name = 'Fill'
		fill.Size = UDim2.fromScale(math.clamp((optionapi.Value - optionsettings.Min) / optionsettings.Max, 0.04, 0.96), 1)
		fill.Position = UDim2.new()
		fill.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		fill.Parent = bkg
		local knobholder = Instance.new('Frame')
		knobholder.Name = 'Knob'
		knobholder.Size = UDim2.fromOffset(24, 4)
		knobholder.Position = UDim2.fromScale(1, 0.5)
		knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
		knobholder.BackgroundColor3 = slider.BackgroundColor3
		knobholder.BorderSizePixel = 0
		knobholder.Parent = fill
		local knob = Instance.new('Frame')
		knob.Name = 'Knob'
		knob.Size = UDim2.fromOffset(14, 14)
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
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
			knob.BackgroundColor3 = fill.BackgroundColor3
		end
		
		function optionapi:SetValue(value, pos, final)
			if tonumber(value) == math.huge or value ~= value then return end
			local check = self.Value ~= value
			self.Value = value
			tween:Tween(fill, uipallet.Tween, {
				Size = UDim2.fromScale(math.clamp(pos or math.clamp(value / optionsettings.Max, 0, 1), 0.04, 0.96), 1)
			})
			valuebutton.Text = self.Value..(optionsettings.Suffix and ' '..(type(optionsettings.Suffix) == 'function' and optionsettings.Suffix(self.Value) or optionsettings.Suffix) or '')
			if check or final then
				optionsettings.Function(value, final)
			end
		end
		
		slider.InputBegan:Connect(function(inputObj)
			if
				(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
				and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
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
		slider.MouseEnter:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(16, 16)
			})
		end)
		slider.MouseLeave:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(14, 14)
			})
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
			Index = getTableSize(api.Options)
		}
		
		local textlist = Instance.new('TextButton')
		textlist.Name = 'Targets'
		textlist.Size = UDim2.new(1, 0, 0, 50)
		textlist.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(textlist)
		textlist.BorderSizePixel = 0
		textlist.AutoButtonColor = false
		textlist.Visible = optionsettings.Visible == nil or optionsettings.Visible
		textlist.Text = ''
		textlist.Parent = children
		addTooltip(textlist, optionsettings.Tooltip)
		local bkg = Instance.new('Frame')
		bkg.Name = 'BKG'
		bkg.Size = UDim2.new(1, -20, 1, -9)
		bkg.Position = UDim2.fromOffset(10, 4)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		bkg.Parent = textlist
		addCorner(bkg, UDim.new(0, 4))
		local button = Instance.new('TextButton')
		button.Name = 'TextList'
		button.Size = UDim2.new(1, -2, 1, -2)
		button.Position = UDim2.fromOffset(1, 1)
		button.BackgroundColor3 = uipallet.Main
		button.AutoButtonColor = false
		button.Text = ''
		button.Parent = bkg
		local buttontitle = Instance.new('TextLabel')
		buttontitle.Name = 'Title'
		buttontitle.Size = UDim2.new(1, -5, 0, 15)
		buttontitle.Position = UDim2.fromOffset(5, 6)
		buttontitle.BackgroundTransparency = 1
		buttontitle.Text = 'Target:'
		buttontitle.TextXAlignment = Enum.TextXAlignment.Left
		buttontitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
		buttontitle.TextSize = 15
		buttontitle.TextTruncate = Enum.TextTruncate.AtEnd
		buttontitle.FontFace = uipallet.Font
		buttontitle.Parent = button
		local items = buttontitle:Clone()
		items.Name = 'Items'
		items.Position = UDim2.fromOffset(5, 21)
		items.Text = 'Ignore none'
		items.TextColor3 = color.Dark(uipallet.Text, 0.16)
		items.TextSize = 11
		items.Parent = button
		addCorner(button, UDim.new(0, 4))
		local tool = Instance.new('Frame')
		tool.Size = UDim2.fromOffset(65, 12)
		tool.Position = UDim2.fromOffset(52, 8)
		tool.BackgroundTransparency = 1
		tool.Parent = button
		local toollist = Instance.new('UIListLayout')
		toollist.FillDirection = Enum.FillDirection.Horizontal
		toollist.Padding = UDim.new(0, 6)
		toollist.Parent = tool
		local window = Instance.new('TextButton')
		window.Name = 'TargetsTextWindow'
		window.Size = UDim2.fromOffset(220, 145)
		window.BackgroundColor3 = uipallet.Main
		window.BorderSizePixel = 0
		window.AutoButtonColor = false
		window.Visible = false
		window.Text = ''
		window.Parent = clickgui
		optionapi.Window = window
		addBlur(window)
		addCorner(window)
		local icon = Instance.new('ImageLabel')
		icon.Name = 'Icon'
		icon.Size = UDim2.fromOffset(18, 12)
		icon.Position = UDim2.fromOffset(10, 15)
		icon.BackgroundTransparency = 1
		icon.Image = getcustomasset('aetherv2/assets/new/targetstab.png')
		icon.Parent = window
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -36, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
		title.BackgroundTransparency = 1
		title.Text = 'Target settings'
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = window
		local close = addCloseButton(window)
		optionsettings.Function = optionsettings.Function or function() end
		
		function optionapi:Save(tab)
			tab.Targets = {
				Players = self.Players.Enabled,
				NPCs = self.NPCs.Enabled,
				Invisible = self.Invisible.Enabled,
				Walls = self.Walls.Enabled
			}
		end
		
		function optionapi:Load(tab)
			if self.Players.Enabled ~= tab.Players then
				self.Players:Toggle()
			end
			if self.NPCs.Enabled ~= tab.NPCs then
				self.NPCs:Toggle()
			end
			if self.Invisible.Enabled ~= tab.Invisible then
				self.Invisible:Toggle()
			end
			if self.Walls.Enabled ~= tab.Walls then
				self.Walls:Toggle()
			end
		end
		
		function optionapi:Color(hue, sat, val, rainbowcheck)
			bkg.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
			if self.Players.Enabled then
				tween:Cancel(self.Players.Object.Frame)
				self.Players.Object.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			end
			if self.NPCs.Enabled then
				tween:Cancel(self.NPCs.Object.Frame)
				self.NPCs.Object.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			end
			if self.Invisible.Enabled then
				tween:Cancel(self.Invisible.Object.Knob)
				self.Invisible.Object.Knob.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			end
			if self.Walls.Enabled then
				tween:Cancel(self.Walls.Object.Knob)
				self.Walls.Object.Knob.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			end
		end
		
		optionapi.Players = components.TargetsButton({
			Position = UDim2.fromOffset(11, 45),
			Icon = getcustomasset('aetherv2/assets/new/targetplayers1.png'),
			IconSize = UDim2.fromOffset(15, 16),
			IconParent = tool,
			ToolIcon = getcustomasset('aetherv2/assets/new/targetplayers2.png'),
			ToolSize = UDim2.fromOffset(11, 12),
			Tooltip = 'Players',
			Function = optionsettings.Function
		}, window, tool)
		optionapi.NPCs = components.TargetsButton({
			Position = UDim2.fromOffset(112, 45),
			Icon = getcustomasset('aetherv2/assets/new/targetnpc1.png'),
			IconSize = UDim2.fromOffset(12, 16),
			IconParent = tool,
			ToolIcon = getcustomasset('aetherv2/assets/new/targetnpc2.png'),
			ToolSize = UDim2.fromOffset(9, 12),
			Tooltip = 'NPCs',
			Function = optionsettings.Function
		}, window, tool)
		optionapi.Invisible = components.Toggle({
			Name = 'Ignore invisible',
			Function = function()
				local text = 'none'
				if optionapi.Invisible.Enabled then
					text = 'invisible'
				end
				if optionapi.Walls.Enabled then
					text = text == 'none' and 'behind walls' or text..', behind walls'
				end
				items.Text = 'Ignore '..text
				optionsettings.Function()
			end
		}, window, {Options = {}})
		optionapi.Invisible.Object.Position = UDim2.fromOffset(0, 81)
		optionapi.Walls = components.Toggle({
			Name = 'Ignore behind walls',
			Function = function()
				local text = 'none'
				if optionapi.Invisible.Enabled then
					text = 'invisible'
				end
				if optionapi.Walls.Enabled then
					text = text == 'none' and 'behind walls' or text..', behind walls'
				end
				items.Text = 'Ignore '..text
				optionsettings.Function()
			end
		}, window, {Options = {}})
		optionapi.Walls.Object.Position = UDim2.fromOffset(0, 111)
		if optionsettings.Players then
			optionapi.Players:Toggle()
		end
		if optionsettings.NPCs then
			optionapi.NPCs:Toggle()
		end
		if optionsettings.Invisible then
			optionapi.Invisible:Toggle()
		end
		if optionsettings.Walls then
			optionapi.Walls:Toggle()
		end
		
		close.MouseButton1Click:Connect(function()
			window.Visible = false
		end)
		button.MouseButton1Click:Connect(function()
			window.Visible = not window.Visible
			tween:Cancel(bkg)
			bkg.BackgroundColor3 = window.Visible and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.37)
		end)
		textlist.MouseEnter:Connect(function()
			if not optionapi.Window.Visible then
				tween:Tween(bkg, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)
		textlist.MouseLeave:Connect(function()
			if not optionapi.Window.Visible then
				tween:Tween(bkg, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				})
			end
		end)
		textlist:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			local actualPosition = (textlist.AbsolutePosition + Vector2.new(0, 60)) / scale.Scale
			window.Position = UDim2.fromOffset(actualPosition.X + 220, actualPosition.Y)
		end)
		
		optionapi.Object = textlist
		api.Options.Targets = optionapi
		
		return optionapi
	end,
	TargetsButton = function(optionsettings, children, api)
		local optionapi = {Enabled = false}
		
		local targetbutton = Instance.new('TextButton')
		targetbutton.Size = UDim2.fromOffset(98, 31)
		targetbutton.Position = optionsettings.Position
		targetbutton.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
		targetbutton.AutoButtonColor = false
		targetbutton.Visible = optionsettings.Visible == nil or optionsettings.Visible
		targetbutton.Text = ''
		targetbutton.Parent = children
		addCorner(targetbutton)
		addTooltip(targetbutton, optionsettings.Tooltip)
		local bkg = Instance.new('Frame')
		bkg.Size = UDim2.new(1, -2, 1, -2)
		bkg.Position = UDim2.fromOffset(1, 1)
		bkg.BackgroundColor3 = uipallet.Main
		bkg.Parent = targetbutton
		addCorner(bkg)
		local icon = Instance.new('ImageLabel')
		icon.Size = optionsettings.IconSize
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = optionsettings.Icon
		icon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		icon.Parent = bkg
		optionsettings.Function = optionsettings.Function or function() end
		local tooltipicon
		
		function optionapi:Toggle()
			self.Enabled = not self.Enabled
			tween:Tween(bkg, uipallet.Tween, {
				BackgroundColor3 = self.Enabled and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or uipallet.Main
			})
			tween:Tween(icon, uipallet.Tween, {
				ImageColor3 = self.Enabled and Color3.new(1, 1, 1) or color.Light(uipallet.Main, 0.37)
			})
			if tooltipicon then
				tooltipicon:Destroy()
			end
			if self.Enabled then
				tooltipicon = Instance.new('ImageLabel')
				tooltipicon.Size = optionsettings.ToolSize
				tooltipicon.BackgroundTransparency = 1
				tooltipicon.Image = optionsettings.ToolIcon
				tooltipicon.ImageColor3 = uipallet.Text
				tooltipicon.Parent = optionsettings.IconParent
			end
			optionsettings.Function(self.Enabled)
		end
		
		targetbutton.MouseEnter:Connect(function()
			if not optionapi.Enabled then
				tween:Tween(bkg, uipallet.Tween, {
					BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value - 0.25)
				})
				tween:Tween(icon, uipallet.Tween, {
					ImageColor3 = Color3.new(1, 1, 1)
				})
			end
		end)
		targetbutton.MouseLeave:Connect(function()
			if not optionapi.Enabled then
				tween:Tween(bkg, uipallet.Tween, {
					BackgroundColor3 = uipallet.Main
				})
				tween:Tween(icon, uipallet.Tween, {
					ImageColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)
		targetbutton.MouseButton1Click:Connect(function()
			optionapi:Toggle()
		end)
		
		optionapi.Object = targetbutton
		
		return optionapi
	end,
	TextBox = function(optionsettings, children, api)
		local optionapi = {
			Type = 'TextBox',
			Value = optionsettings.Default or '',
			Index = 0
		}
		
		local textbox = Instance.new('TextButton')
		textbox.Name = optionsettings.Name..'TextBox'
		textbox.Size = UDim2.new(1, 0, 0, 58)
		textbox.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(textbox)
		textbox.BorderSizePixel = 0
		textbox.AutoButtonColor = false
		textbox.Visible = optionsettings.Visible == nil or optionsettings.Visible
		textbox.Text = ''
		textbox.Parent = children
		addTooltip(textbox, optionsettings.Tooltip)
		addHoverFX(textbox, {Ripple = false})
		local title = Instance.new('TextLabel')
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Position = UDim2.fromOffset(10, 3)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 12
		title.FontFace = uipallet.Font
		title.Parent = textbox
		local bkg = Instance.new('Frame')
		bkg.Name = 'BKG'
		bkg.Size = UDim2.new(1, -20, 0, 29)
		bkg.Position = UDim2.fromOffset(10, 23)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		bkg.Parent = textbox
		addCorner(bkg, UDim.new(0, 4))
		local box = Instance.new('TextBox')
		box.Size = UDim2.new(1, -8, 1, 0)
		box.Position = UDim2.fromOffset(8, 0)
		box.BackgroundTransparency = 1
		box.Text = optionsettings.Default or ''
		box.PlaceholderText = optionsettings.Placeholder or 'Click to set'
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextColor3 = color.Dark(uipallet.Text, 0.16)
		box.PlaceholderColor3 = color.Dark(uipallet.Text, 0.31)
		box.TextSize = 12
		box.FontFace = uipallet.Font
		box.ClearTextOnFocus = false
		box.Parent = bkg
		optionsettings.Function = optionsettings.Function or function() end
		
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
		textlist.Size = UDim2.new(1, 0, 0, 50)
		textlist.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(textlist)
		textlist.BorderSizePixel = 0
		textlist.AutoButtonColor = false
		textlist.Visible = optionsettings.Visible == nil or optionsettings.Visible
		textlist.Text = ''
		textlist.Parent = children
		addTooltip(textlist, optionsettings.Tooltip)
		local bkg = Instance.new('Frame')
		bkg.Name = 'BKG'
		bkg.Size = UDim2.new(1, -20, 1, -9)
		bkg.Position = UDim2.fromOffset(10, 4)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		bkg.Parent = textlist
		addCorner(bkg, UDim.new(0, 4))
		local button = Instance.new('TextButton')
		button.Name = 'TextList'
		button.Size = UDim2.new(1, -2, 1, -2)
		button.Position = UDim2.fromOffset(1, 1)
		button.BackgroundColor3 = uipallet.Main
		button.AutoButtonColor = false
		button.Text = ''
		button.Parent = bkg
		local buttonicon = Instance.new('ImageLabel')
		buttonicon.Name = 'Icon'
		buttonicon.Size = UDim2.fromOffset(14, 12)
		buttonicon.Position = UDim2.fromOffset(10, 14)
		buttonicon.BackgroundTransparency = 1
		buttonicon.Image = optionsettings.Icon or getcustomasset('aetherv2/assets/new/allowedicon.png')
		buttonicon.Parent = button
		local buttontitle = Instance.new('TextLabel')
		buttontitle.Name = 'Title'
		buttontitle.Size = UDim2.new(1, -35, 0, 15)
		buttontitle.Position = UDim2.fromOffset(35, 6)
		buttontitle.BackgroundTransparency = 1
		buttontitle.Text = optionsettings.Name
		buttontitle.TextXAlignment = Enum.TextXAlignment.Left
		buttontitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
		buttontitle.TextSize = 15
		buttontitle.TextTruncate = Enum.TextTruncate.AtEnd
		buttontitle.FontFace = uipallet.Font
		buttontitle.Parent = button
		local amount = buttontitle:Clone()
		amount.Name = 'Amount'
		amount.Size = UDim2.new(1, -13, 0, 15)
		amount.Position = UDim2.fromOffset(0, 6)
		amount.Text = '0'
		amount.TextXAlignment = Enum.TextXAlignment.Right
		amount.Parent = button
		local items = buttontitle:Clone()
		items.Name = 'Items'
		items.Position = UDim2.fromOffset(35, 21)
		items.Text = 'None'
		items.TextColor3 = color.Dark(uipallet.Text, 0.43)
		items.TextSize = 11
		items.Parent = button
		addCorner(button, UDim.new(0, 4))
		local window = Instance.new('TextButton')
		window.Name = optionsettings.Name..'TextWindow'
		window.Size = UDim2.fromOffset(220, 85)
		window.BackgroundColor3 = uipallet.Main
		window.BorderSizePixel = 0
		window.AutoButtonColor = false
		window.Visible = false
		window.Text = ''
		window.Parent = api.Legit and mainapi.Legit.Window or clickgui
		optionapi.Window = window
		addBlur(window)
		addCorner(window)
		local icon = Instance.new('ImageLabel')
		icon.Name = 'Icon'
		icon.Size = optionsettings.TabSize or UDim2.fromOffset(19, 16)
		icon.Position = UDim2.fromOffset(10, 13)
		icon.BackgroundTransparency = 1
		icon.Image = optionsettings.Tab or getcustomasset('aetherv2/assets/new/allowedtab.png')
		icon.Parent = window
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -36, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = window
		local close = addCloseButton(window)
		local addbkg = Instance.new('Frame')
		addbkg.Name = 'Add'
		addbkg.Size = UDim2.fromOffset(200, 31)
		addbkg.Position = UDim2.fromOffset(10, 45)
		addbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		addbkg.Parent = window
		addCorner(addbkg)
		local addbox = addbkg:Clone()
		addbox.Size = UDim2.new(1, -2, 1, -2)
		addbox.Position = UDim2.fromOffset(1, 1)
		addbox.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		addbox.Parent = addbkg
		local addvalue = Instance.new('TextBox')
		addvalue.Size = UDim2.new(1, -35, 1, 0)
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
		local addbutton = Instance.new('ImageButton')
		addbutton.Name = 'AddButton'
		addbutton.Size = UDim2.fromOffset(16, 16)
		addbutton.Position = UDim2.new(1, -26, 0, 8)
		addbutton.BackgroundTransparency = 1
		addbutton.Image = getcustomasset('aetherv2/assets/new/add.png')
		addbutton.ImageColor3 = optionsettings.Color
		addbutton.ImageTransparency = 0.3
		addbutton.Parent = addbkg
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
			if window.Visible then
				bkg.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
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
			window.Size = UDim2.fromOffset(220, 85 + (#self.List * 35))
			amount.Text = #self.List
		
			local enabledtext = 'None'
			for i, v in self.ListEnabled do
				if i == 1 then enabledtext = '' end
				enabledtext = enabledtext..(i == 1 and v or ', '..v)
			end
			items.Text = enabledtext
		
			for i, v in self.List do
				local enabled = table.find(self.ListEnabled, v)
				local object = Instance.new('TextButton')
				object.Name = v
				object.Size = UDim2.fromOffset(200, 32)
				object.Position = UDim2.fromOffset(10, 47 + (i * 35))
				object.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				object.AutoButtonColor = false
				object.Text = ''
				object.Parent = window
				addCorner(object)
				local objectbkg = Instance.new('Frame')
				objectbkg.Name = 'BKG'
				objectbkg.Size = UDim2.new(1, -2, 1, -2)
				objectbkg.Position = UDim2.fromOffset(1, 1)
				objectbkg.BackgroundColor3 = uipallet.Main
				objectbkg.Visible = false
				objectbkg.Parent = object
				addCorner(objectbkg)
				local objectdot = Instance.new('Frame')
				objectdot.Name = 'Dot'
				objectdot.Size = UDim2.fromOffset(10, 11)
				objectdot.Position = UDim2.fromOffset(10, 12)
				objectdot.BackgroundColor3 = enabled and optionsettings.Color or color.Light(uipallet.Main, 0.37)
				objectdot.Parent = object
				addCorner(objectdot, UDim.new(1, 0))
				local objectdotin = objectdot:Clone()
				objectdotin.Size = UDim2.fromOffset(8, 9)
				objectdotin.Position = UDim2.fromOffset(1, 1)
				objectdotin.BackgroundColor3 = enabled and optionsettings.Color or color.Light(uipallet.Main, 0.02)
				objectdotin.Parent = objectdot
				local objecttitle = Instance.new('TextLabel')
				objecttitle.Name = 'Title'
				objecttitle.Size = UDim2.new(1, -30, 1, 0)
				objecttitle.Position = UDim2.fromOffset(30, 0)
				objecttitle.BackgroundTransparency = 1
				objecttitle.Text = v
				objecttitle.TextXAlignment = Enum.TextXAlignment.Left
				objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
				objecttitle.TextSize = 15
				objecttitle.FontFace = uipallet.Font
				objecttitle.Parent = object
				local close = Instance.new('ImageButton')
				close.Name = 'Close'
				close.Size = UDim2.fromOffset(16, 16)
				close.Position = UDim2.new(1, -26, 0, 8)
				close.BackgroundColor3 = Color3.new(1, 1, 1)
				close.BackgroundTransparency = 1
				close.AutoButtonColor = false
				close.Image = getcustomasset('aetherv2/assets/new/closemini.png')
				close.ImageColor3 = color.Light(uipallet.Text, 0.2)
				close.ImageTransparency = 0.5
				close.Parent = object
				addCorner(close, UDim.new(1, 0))
		
				close.MouseEnter:Connect(function()
					close.ImageTransparency = 0.3
					tween:Tween(close, uipallet.Tween, {
						BackgroundTransparency = 0.6
					})
				end)
				close.MouseLeave:Connect(function()
					close.ImageTransparency = 0.5
					tween:Tween(close, uipallet.Tween, {
						BackgroundTransparency = 1
					})
				end)
				close.MouseButton1Click:Connect(function()
					self:ChangeValue(v)
				end)
				object.MouseEnter:Connect(function()
					objectbkg.Visible = true
				end)
				object.MouseLeave:Connect(function()
					objectbkg.Visible = false
				end)
				object.MouseButton1Click:Connect(function()
					local ind = table.find(self.ListEnabled, v)
					if ind then
						table.remove(self.ListEnabled, ind)
						objectdot.BackgroundColor3 = color.Light(uipallet.Main, 0.37)
						objectdotin.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					else
						table.insert(self.ListEnabled, v)
						objectdot.BackgroundColor3 = optionsettings.Color
						objectdotin.BackgroundColor3 = optionsettings.Color
					end
		
					local enabledtext = 'None'
					for i, v in self.ListEnabled do
						if i == 1 then enabledtext = '' end
						enabledtext = enabledtext..(i == 1 and v or ', '..v)
					end
		
					items.Text = enabledtext
					optionsettings.Function()
				end)
		
				table.insert(self.Objects, object)
			end
		end
		
		addbutton.MouseEnter:Connect(function()
			addbutton.ImageTransparency = 0
		end)
		addbutton.MouseLeave:Connect(function()
			addbutton.ImageTransparency = 0.3
		end)
		addbutton.MouseButton1Click:Connect(function()
			if not table.find(optionapi.List, addvalue.Text) then
				optionapi:ChangeValue(addvalue.Text)
				addvalue.Text = ''
			end
		end)
		addvalue.FocusLost:Connect(function(enter)
			if enter and not table.find(optionapi.List, addvalue.Text) then
				optionapi:ChangeValue(addvalue.Text)
				addvalue.Text = ''
			end
		end)
		addvalue.MouseEnter:Connect(function()
			tween:Tween(addbkg, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)
		addvalue.MouseLeave:Connect(function()
			tween:Tween(addbkg, uipallet.Tween, {
				BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			})
		end)
		close.MouseButton1Click:Connect(function()
			window.Visible = false
		end)
		button.MouseButton1Click:Connect(function()
			window.Visible = not window.Visible
			tween:Cancel(bkg)
			bkg.BackgroundColor3 = window.Visible and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.37)
		end)
		textlist.MouseEnter:Connect(function()
			if not optionapi.Window.Visible then
				tween:Tween(bkg, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)
		textlist.MouseLeave:Connect(function()
			if not optionapi.Window.Visible then
				tween:Tween(bkg, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				})
			end
		end)
		textlist:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			local actualPosition = (textlist.AbsolutePosition - (api.Legit and mainapi.Legit.Window.AbsolutePosition or -guiService:GetGuiInset())) / scale.Scale
			window.Position = UDim2.fromOffset(actualPosition.X + 220, actualPosition.Y)
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
		
		local hovered = false
		local toggle = Instance.new('TextButton')
		toggle.Name = optionsettings.Name..'Toggle'
		toggle.Size = UDim2.new(1, 0, 0, 30)
		toggle.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(toggle)
		toggle.BorderSizePixel = 0
		toggle.AutoButtonColor = false
		toggle.Visible = optionsettings.Visible == nil or optionsettings.Visible
		toggle.Text = '          '..optionsettings.Name
		toggle.TextXAlignment = Enum.TextXAlignment.Left
		toggle.TextColor3 = color.Dark(uipallet.Text, 0.16)
		toggle.TextSize = 14
		toggle.FontFace = uipallet.Font
		toggle.Parent = children
		addTooltip(toggle, optionsettings.Tooltip)
		addHoverFX(toggle)
		local knobholder = Instance.new('Frame')
		knobholder.Name = 'Knob'
		knobholder.Size = UDim2.fromOffset(22, 12)
		knobholder.Position = UDim2.new(1, -30, 0, 9)
		knobholder.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		knobholder.Parent = toggle
		addCorner(knobholder, UDim.new(1, 0))
		local knob = knobholder:Clone()
		knob.Size = UDim2.fromOffset(8, 8)
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
		end
		
		function optionapi:Toggle()
			self.Enabled = not self.Enabled
			local rainbowcheck = mainapi.GUIColor.Rainbow and mainapi.RainbowMode.Value ~= 'Retro'
			tween:Tween(knobholder, uipallet.Tween, {
				BackgroundColor3 = self.Enabled and (rainbowcheck and Color3.fromHSV(mainapi:Color((mainapi.GUIColor.Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)) or (hovered and color.Light(uipallet.Main, 0.37) or color.Light(uipallet.Main, 0.14))
			})
			tween:Tween(knob, uipallet.Tween, {
				Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
			})
			xpcall(function()
				optionsettings.Function(self.Enabled)
			end, function(err)
				if shared.VapeDeveloper then
					mainapi:CreateNotification('AetherV2', 'gui error: '.. err, 15, 'warning')
					task.defer(error, err)
				end	
			end)
		end
		
		toggle.MouseEnter:Connect(function()
			hovered = true
			if not optionapi.Enabled then
				tween:Tween(knobholder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.37)
				})
			end
		end)
		toggle.MouseLeave:Connect(function()
			hovered = false
			if not optionapi.Enabled then
				tween:Tween(knobholder, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.14)
				})
			end
		end)
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
		slider.Size = UDim2.new(1, 0, 0, 50)
		slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
		addGlass(slider)
		slider.BorderSizePixel = 0
		slider.AutoButtonColor = false
		slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
		slider.Text = ''
		slider.Parent = children
		addTooltip(slider, optionsettings.Tooltip)
		addHoverFX(slider, {Ripple = false})
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.fromOffset(60, 30)
		title.Position = UDim2.fromOffset(10, 2)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 11
		title.FontFace = uipallet.Font
		title.Parent = slider
		local valuebutton = Instance.new('TextButton')
		valuebutton.Name = 'Value'
		valuebutton.Size = UDim2.fromOffset(60, 15)
		valuebutton.Position = UDim2.new(1, -69, 0, 9)
		valuebutton.BackgroundTransparency = 1
		valuebutton.Text = optionapi.ValueMax
		valuebutton.TextXAlignment = Enum.TextXAlignment.Right
		valuebutton.TextColor3 = color.Dark(uipallet.Text, 0.16)
		valuebutton.TextSize = 11
		valuebutton.FontFace = uipallet.Font
		valuebutton.Parent = slider
		local valuebutton2 = valuebutton:Clone()
		valuebutton2.Position = UDim2.new(1, -125, 0, 9)
		valuebutton2.Text = optionapi.ValueMin
		valuebutton2.Parent = slider
		local valuebox = Instance.new('TextBox')
		valuebox.Name = 'Box'
		valuebox.Size = valuebutton.Size
		valuebox.Position = valuebutton.Position
		valuebox.BackgroundTransparency = 1
		valuebox.Visible = false
		valuebox.Text = optionapi.ValueMin
		valuebox.TextXAlignment = Enum.TextXAlignment.Right
		valuebox.TextColor3 = color.Dark(uipallet.Text, 0.16)
		valuebox.TextSize = 11
		valuebox.FontFace = uipallet.Font
		valuebox.ClearTextOnFocus = false
		valuebox.Parent = slider
		local valuebox2 = valuebox:Clone()
		valuebox2.Position = valuebutton2.Position
		valuebox2.Parent = slider
		local bkg = Instance.new('Frame')
		bkg.Name = 'Slider'
		bkg.Size = UDim2.new(1, -20, 0, 2)
		bkg.Position = UDim2.fromOffset(10, 37)
		bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		bkg.BorderSizePixel = 0
		bkg.Parent = slider
		local fill = bkg:Clone()
		fill.Name = 'Fill'
		fill.Position = UDim2.fromScale(math.clamp(optionapi.ValueMin / optionsettings.Max, 0.04, 0.96), 0)
		fill.Size = UDim2.fromScale(math.clamp(math.clamp(optionapi.ValueMax / optionsettings.Max, 0, 1), 0.04, 0.96) - fill.Position.X.Scale, 1)
		fill.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		fill.Parent = bkg
		local knobholder = Instance.new('Frame')
		knobholder.Name = 'Knob'
		knobholder.Size = UDim2.fromOffset(16, 4)
		knobholder.Position = UDim2.fromScale(0, 0.5)
		knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
		knobholder.BackgroundColor3 = slider.BackgroundColor3
		knobholder.BorderSizePixel = 0
		knobholder.Parent = fill
		local knob = Instance.new('ImageLabel')
		knob.Name = 'Knob'
		knob.Size = UDim2.fromOffset(9, 16)
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundTransparency = 1
		knob.Image = getcustomasset('aetherv2/assets/new/range.png')
		knob.ImageColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		knob.Parent = knobholder
		local knobholdermax = knobholder:Clone()
		knobholdermax.Name = 'KnobMax'
		knobholdermax.Position = UDim2.fromScale(1, 0.5)
		knobholdermax.Parent = fill
		knobholdermax.Knob.Rotation = 180
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
			tab[optionsettings.Name] = {ValueMin = self.ValueMin, ValueMax = self.ValueMax}
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
			knob.ImageColor3 = fill.BackgroundColor3
			knobholdermax.Knob.ImageColor3 = fill.BackgroundColor3
		end
		
		function optionapi:GetRandomValue()
			return random:NextNumber(optionapi.ValueMin, optionapi.ValueMax)
		end
		
		function optionapi:SetValue(max, value)
			if tonumber(value) == math.huge or value ~= value then return end
			self[max and 'ValueMax' or 'ValueMin'] = value
			valuebutton.Text = self.ValueMax
			valuebutton2.Text = self.ValueMin
			local size = math.clamp(math.clamp(self.ValueMin / optionsettings.Max, 0, 1), 0.04, 0.96)
			tween:Tween(fill, TweenInfo.new(0.1), {
				Position = UDim2.fromScale(size, 0),
				Size = UDim2.fromScale(math.clamp(math.clamp(math.clamp(self.ValueMax / optionsettings.Max, 0.04, 0.96), 0.04, 0.96) - size, 0, 1), 1)
			})
		end
		
		knobholder.MouseEnter:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(11, 18)
			})
		end)
		knobholder.MouseLeave:Connect(function()
			tween:Tween(knob, uipallet.Tween, {
				Size = UDim2.fromOffset(9, 16)
			})
		end)
		knobholdermax.MouseEnter:Connect(function()
			tween:Tween(knobholdermax.Knob, uipallet.Tween, {
				Size = UDim2.fromOffset(11, 18)
			})
		end)
		knobholdermax.MouseLeave:Connect(function()
			tween:Tween(knobholdermax.Knob, uipallet.Tween, {
				Size = UDim2.fromOffset(9, 16)
			})
		end)
		slider.InputBegan:Connect(function(inputObj)
			if
				(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
				and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
				local maxCheck = (inputObj.Position.X - knobholdermax.AbsolutePosition.X) > -10
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
	if self.ThreadFix and not inputService.TouchEnabled then
		setthreadidentity(8)
		runService:SetRobloxGuiFocused((clickgui.Visible or guiService:GetErrorType() ~= Enum.ConnectionError.OK) and self.Blur.Enabled)
	end
end

addMaid(mainapi)

-- Sorts every module within its category alphabetically, but keeps favourited
-- modules pinned to the top of their category (also alphabetical amongst themselves).
function mainapi:SortModules()
	local sorting = {}
	for _, v in self.Modules do
		sorting[v.Category] = sorting[v.Category] or {}
		table.insert(sorting[v.Category], v.Name)
	end

	for _, sort in sorting do
		table.sort(sort, function(a, b)
			local fava, favb = self.Modules[a].Favourited, self.Modules[b].Favourited
			if (fava and true) ~= (favb and true) then
				return fava and true or false
			end
			return a < b
		end)
		for i, v in sort do
			local module = self.Modules[v]
			module.Index = i
			-- Two slots per module: the row, then its settings panel directly under it.
			-- Sharing one order left the pair tied, and a UIListLayout resolves a tie in
			-- whatever order it feels like.
			module.Object.LayoutOrder = i * 2
			-- OptionsChildren rather than Children: a module that draws a HUD (MP3Player,
			-- AutoWin and the rest) has Children pointing at its draggable HUD frame
			-- instead, so its settings panel was never given an order at all and stayed on
			-- 0 - which sorted it above every module in the category. That is exactly
			-- where those settings were turning up.
			local panel = module.OptionsChildren or module.Children
			if panel then
				panel.LayoutOrder = (i * 2) + 1
			end
		end
	end
end

function mainapi:CreateGUI()
	local categoryapi = {
		Type = 'MainWindow',
		Buttons = {},
		Options = {}
	}

	local window = Instance.new('TextButton')
	window.Name = 'GUICategory'
	window.Position = UDim2.fromOffset(6, 60)
	window.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
	window.AutoButtonColor = false
	window.Text = ''
	window.Parent = clickgui
	addBlur(window)
	addCorner(window)
	addWindowStroke(window)
	makeDraggable(window)
	-- AetherV2's own wordmark, in place of the Vape logo art this fork inherited: the
	-- header is the one part of the menu you see every single time it opens, so it is
	-- where the name belongs. Drawn as text rather than an image so it picks up the
	-- menu's font and needs no artwork of its own. The instance names are unchanged -
	-- UpdateGUI and the saved layouts still address them.
	local logo = Instance.new('TextLabel')
	logo.Name = 'VapeLogo'
	logo.Size = UDim2.fromOffset(getfontsize('AETHER', 15, uipallet.FontSemiBold).X, 18)
	logo.Position = UDim2.fromOffset(13, 10)
	logo.BackgroundTransparency = 1
	logo.Text = 'AETHER'
	logo.TextXAlignment = Enum.TextXAlignment.Left
	logo.TextColor3 = select(3, uipallet.Main:ToHSV()) > 0.5 and uipallet.Text or Color3.new(1, 1, 1)
	logo.TextSize = 15
	logo.FontFace = uipallet.FontSemiBold
	logo.Parent = window
	local logov4 = Instance.new('TextLabel')
	logov4.Name = 'V4Logo'
	logov4.Size = UDim2.fromOffset(24, 14)
	logov4.Position = UDim2.new(1, 5, 0, 2)
	logov4.BackgroundTransparency = 1
	logov4.Text = 'V2'
	logov4.TextXAlignment = Enum.TextXAlignment.Left
	logov4.TextColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
	logov4.TextSize = 13
	logov4.FontFace = uipallet.FontSemiBold
	logov4.Parent = logo
	local children = Instance.new('Frame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, -33)
	children.Position = UDim2.fromOffset(0, 37)
	children.BackgroundTransparency = 1
	children.Parent = window
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	windowlist.Parent = children
	local settingsbutton = Instance.new('TextButton')
	settingsbutton.Name = 'Settings'
	settingsbutton.Size = UDim2.fromOffset(40, 40)
	settingsbutton.Position = UDim2.new(1, -40, 0, 0)
	settingsbutton.BackgroundTransparency = 1
	settingsbutton.Text = ''
	settingsbutton.Parent = window
	addTooltip(settingsbutton, 'Open settings')
	local settingsicon = Instance.new('ImageLabel')
	settingsicon.Size = UDim2.fromOffset(14, 14)
	settingsicon.Position = UDim2.fromOffset(15, 12)
	settingsicon.BackgroundTransparency = 1
	settingsicon.Image = getcustomasset('aetherv2/assets/new/guisettings.png')
	settingsicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
	settingsicon.Parent = settingsbutton
	local discordbutton = Instance.new('ImageButton')
	discordbutton.Size = UDim2.fromOffset(16, 16)
	discordbutton.Position = UDim2.new(1, -56, 0, 11)
	discordbutton.BackgroundTransparency = 1
	discordbutton.Image = getcustomasset('aetherv2/assets/new/discord.png')
	discordbutton.Parent = window
	addTooltip(discordbutton, 'Join discord')
	local settingspane = Instance.new('TextButton')
	settingspane.Size = UDim2.fromScale(1, 1)
	settingspane.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
	settingspane.AutoButtonColor = false
	settingspane.Visible = false
	settingspane.Text = ''
	settingspane.Parent = window
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.new(1, -36, 0, 20)
	title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
	title.BackgroundTransparency = 1
	title.Text = 'Settings'
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = uipallet.Text
	title.TextSize = 13
	title.FontFace = uipallet.Font
	title.Parent = settingspane
	local close = addCloseButton(settingspane)
	local back = Instance.new('ImageButton')
	back.Name = 'Back'
	back.Size = UDim2.fromOffset(16, 16)
	back.Position = UDim2.fromOffset(11, 13)
	back.BackgroundTransparency = 1
	back.Image = getcustomasset('aetherv2/assets/new/back.png')
	back.ImageColor3 = color.Light(uipallet.Main, 0.37)
	back.Parent = settingspane
	local settingsversion = Instance.new('TextLabel')
	settingsversion.Name = 'Version'
	settingsversion.Size = UDim2.new(1, 0, 0, 16)
	settingsversion.Position = UDim2.new(0, 0, 1, -16)
	settingsversion.BackgroundTransparency = 1
	settingsversion.Text = 'Nexus '..mainapi.Version..' '..(
		isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt'):sub(1, 6) or ''
	)..' '
	settingsversion.TextColor3 = color.Dark(uipallet.Text, 0.3)
	settingsversion.TextXAlignment = Enum.TextXAlignment.Right
	settingsversion.TextSize = 10
	settingsversion.FontFace = uipallet.Font
	settingsversion.Parent = settingspane
	addCorner(settingspane)
	local settingschildren = Instance.new('Frame')
	settingschildren.Name = 'Children'
	settingschildren.Size = UDim2.new(1, 0, 1, -57)
	settingschildren.Position = UDim2.fromOffset(0, 41)
	settingschildren.BackgroundColor3 = uipallet.Main
	settingschildren.BorderSizePixel = 0
	settingschildren.Parent = settingspane
	local settingswindowlist = Instance.new('UIListLayout')
	settingswindowlist.SortOrder = Enum.SortOrder.LayoutOrder
	settingswindowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	settingswindowlist.Parent = settingschildren
	categoryapi.Object = window

	function categoryapi:CreateBind()
		local optionapi = {Bind = {'RightShift'}}

		local button = Instance.new('TextButton')
		button.Size = UDim2.fromOffset(220, 40)
		button.BackgroundColor3 = uipallet.Main
		addGlass(button)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = '          Rebind GUI'
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextColor3 = color.Dark(uipallet.Text, 0.16)
		button.TextSize = 14
		button.FontFace = uipallet.Font
		button.Parent = settingschildren
		addTooltip(button, 'Change the bind of the GUI')
		local bind = Instance.new('TextButton')
		bind.Name = 'Bind'
		bind.Size = UDim2.fromOffset(20, 21)
		bind.Position = UDim2.new(1, -10, 0, 9)
		bind.AnchorPoint = Vector2.new(1, 0)
		bind.BackgroundColor3 = Color3.new(1, 1, 1)
		bind.BackgroundTransparency = 0.92
		bind.BorderSizePixel = 0
		bind.AutoButtonColor = false
		bind.Text = ''
		bind.Parent = button
		addTooltip(bind, 'Click to bind')
		addCorner(bind, UDim.new(0, 4))
		local icon = Instance.new('ImageLabel')
		icon.Name = 'Icon'
		icon.Size = UDim2.fromOffset(12, 12)
		icon.Position = UDim2.new(0.5, -6, 0, 5)
		icon.BackgroundTransparency = 1
		icon.Image = getcustomasset('aetherv2/assets/new/bind.png')
		icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		icon.Parent = bind
		local label = Instance.new('TextLabel')
		label.Name = 'Text'
		label.Size = UDim2.fromScale(1, 1)
		label.Position = UDim2.fromOffset(0, 1)
		label.BackgroundTransparency = 1
		label.Visible = false
		label.Text = ''
		label.TextColor3 = color.Dark(uipallet.Text, 0.43)
		label.TextSize = 12
		label.FontFace = uipallet.Font
		label.Parent = bind

		function optionapi:SetBind(tab)
			mainapi.Keybind = #tab <= 0 and mainapi.Keybind or table.clone(tab)
			self.Bind = mainapi.Keybind
			if mainapi.VapeButton then
				mainapi.VapeButton:Destroy()
				mainapi.VapeButton = nil
			end

			bind.Visible = true
			label.Visible = true
			icon.Visible = false
			label.Text = table.concat(mainapi.Keybind, ' + '):upper()
			bind.Size = UDim2.fromOffset(math.max(getfontsize(label.Text, label.TextSize, label.Font).X + 10, 20), 21)
		end

		bind.MouseEnter:Connect(function()
			label.Visible = false
			icon.Visible = not label.Visible
			icon.Image = getcustomasset('aetherv2/assets/new/edit.png')
			icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
		end)
		bind.MouseLeave:Connect(function()
			label.Visible = true
			icon.Visible = not label.Visible
			icon.Image = getcustomasset('aetherv2/assets/new/bind.png')
			icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		end)
		bind.MouseButton1Click:Connect(function()
			mainapi.Binding = optionapi
		end)

		categoryapi.Options.Bind = optionapi

		return optionapi
	end

	function categoryapi:CreateButton(categorysettings)
		local optionapi = {
			Enabled = false,
			Index = getTableSize(categoryapi.Buttons)
		}

		local button = Instance.new('TextButton')
		button.Name = categorysettings.Name
		button.Size = UDim2.fromOffset(220, 40)
		button.BackgroundColor3 = uipallet.Main
		addGlass(button)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = (categorysettings.Icon and '                                 ' or '             ')..categorysettings.Name
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextColor3 = color.Dark(uipallet.Text, 0.16)
		button.TextSize = 14
		button.FontFace = uipallet.Font
		button.Parent = children
		addHoverFX(button)
		local icon
		if categorysettings.Icon then
			icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = categorysettings.Size
			icon.Position = UDim2.fromOffset(13, 13)
			icon.BackgroundTransparency = 1
			icon.Image = categorysettings.Icon
			icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
			icon.Parent = button
		end
		if categorysettings.Name == 'Profiles' then
			local label = Instance.new('TextLabel')
			label.Name = 'ProfileLabel'
			label.Size = UDim2.fromOffset(53, 24)
			label.Position = UDim2.new(1, -36, 0, 8)
			label.AnchorPoint = Vector2.new(1, 0)
			label.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
			label.Text = 'default'
			label.TextColor3 = color.Dark(uipallet.Text, 0.29)
			label.TextSize = 12
			label.FontFace = uipallet.Font
			label.Parent = button
			addCorner(label)
			mainapi.ProfileLabel = label
		end
		local arrow = Instance.new('ImageLabel')
		arrow.Name = 'Arrow'
		arrow.Size = UDim2.fromOffset(4, 8)
		arrow.Position = UDim2.new(1, -20, 0, 16)
		arrow.BackgroundTransparency = 1
		arrow.Image = getcustomasset('aetherv2/assets/new/expandright.png')
		arrow.ImageColor3 = color.Light(uipallet.Main, 0.37)
		arrow.Parent = button
		optionapi.Name = categorysettings.Name
		optionapi.Icon = icon
		optionapi.Object = button

		-- Opening a category has to actually show you the window. A saved layout can put one
		-- off the side of a smaller screen, or exactly on top of another window, and either way
		-- the tab reads as "nothing happened" - the button lit up and the panel was nowhere on
		-- screen. Anything that cannot be seen goes back to the slot this category was built
		-- with.
		local function revealWindow(window)
			local screen = mainapi.gui and mainapi.gui.AbsoluteSize / scale.Scale or Vector2.new(1920, 1080)
			local pos = window.Position
			local offscreen = pos.X.Offset < -40 or pos.Y.Offset < -40
				or pos.X.Offset > screen.X - 60 or pos.Y.Offset > screen.Y - 40
			local stacked = false
			for _, v in mainapi.Categories do
				local other = v.Object
				if typeof(other) == 'Instance' and other ~= window and other.Visible
					and other.Position == pos
				then
					stacked = true
					break
				end
			end
			if not (offscreen or stacked) then return end
			local default
			for _, v in mainapi.Categories do
				if v.Object == window then
					default = v.DefaultPosition
					break
				end
			end
			window.Position = default or UDim2.fromOffset(6, 60)
		end

		function optionapi:Toggle(state)
			if state ~= nil then
				if state == self.Enabled then return end
				self.Enabled = state
			else
				self.Enabled = not self.Enabled
			end
			tween:Tween(arrow, uipallet.Tween, {
				Position = UDim2.new(1, self.Enabled and -14 or -20, 0, 16)
			})
			button.TextColor3 = self.Enabled and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Dark(uipallet.Text, 0.16)
			if icon then
				icon.ImageColor3 = button.TextColor3
			end
			button.BackgroundColor3 = self.Enabled and color.Light(uipallet.Main, 0.02) or uipallet.Main
			local window = categorysettings.Window
			if typeof(window) ~= 'Instance' or not window.Parent then return end
			if self.Enabled then
				revealWindow(window)
			end
			window.Visible = self.Enabled
		end

		button.MouseEnter:Connect(function()
			if not optionapi.Enabled then
				button.TextColor3 = uipallet.Text
				if icon then icon.ImageColor3 = uipallet.Text end
				button.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end
		end)
		button.MouseLeave:Connect(function()
			if not optionapi.Enabled then
				button.TextColor3 = color.Dark(uipallet.Text, 0.16)
				if icon then icon.ImageColor3 = color.Dark(uipallet.Text, 0.16) end
				button.BackgroundColor3 = uipallet.Main
			end
		end)
		-- Both signals, because neither one is reliable everywhere: Activated is what carries
		-- touch and gamepad, and it is also the one that goes quiet on some executor-hosted
		-- ScreenGuis, which is what left these tabs dead to a plain mouse click. A normal click
		-- fires both, so the second one inside the same moment is dropped.
		local lastClick = 0
		local function clicked()
			local now = os.clock()
			if now - lastClick < 0.05 then return end
			lastClick = now
			optionapi:Toggle()
		end
		button.Activated:Connect(clicked)
		button.MouseButton1Click:Connect(clicked)

		categoryapi.Buttons[categorysettings.Name] = optionapi

		return optionapi
	end

	function categoryapi:CreateDivider(text)
		return components.Divider(children, text)
	end

	function categoryapi:CreateOverlayBar()
		local optionapi = {Toggles = {}}

		local bar = Instance.new('Frame')
		bar.Name = 'Overlays'
		bar.Size = UDim2.fromOffset(220, 36)
		bar.BackgroundColor3 = uipallet.Main
		addGlass(bar)
		bar.BorderSizePixel = 0
		bar.Parent = children
		components.Divider(bar)
		local button = Instance.new('ImageButton')
		button.Size = UDim2.fromOffset(24, 24)
		button.Position = UDim2.new(1, -29, 0, 7)
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.Image = getcustomasset('aetherv2/assets/new/overlaysicon.png')
		button.ImageColor3 = color.Light(uipallet.Main, 0.37)
		button.Parent = bar
		addCorner(button, UDim.new(1, 0))
		addTooltip(button, 'Open overlays menu')
		local shadow = Instance.new('TextButton')
		shadow.Name = 'Shadow'
		shadow.Size = UDim2.new(1, 0, 1, -5)
		shadow.BackgroundColor3 = Color3.new()
		shadow.BackgroundTransparency = 1
		shadow.AutoButtonColor = false
		shadow.ClipsDescendants = true
		shadow.Visible = false
		shadow.Text = ''
		shadow.Parent = window
		addCorner(shadow)
		local window = Instance.new('Frame')
		window.Size = UDim2.fromOffset(220, 42)
		window.Position = UDim2.fromScale(0, 1)
		window.BackgroundColor3 = uipallet.Main
		window.Parent = shadow
		addCorner(window)
		local icon = Instance.new('ImageLabel')
		icon.Name = 'Icon'
		icon.Size = UDim2.fromOffset(14, 12)
		icon.Position = UDim2.fromOffset(10, 13)
		icon.BackgroundTransparency = 1
		icon.Image = getcustomasset('aetherv2/assets/new/overlaystab.png')
		icon.ImageColor3 = uipallet.Text
		icon.Parent = window
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -36, 0, 38)
		title.Position = UDim2.fromOffset(36, 0)
		title.BackgroundTransparency = 1
		title.Text = 'Overlays'
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 15
		title.FontFace = uipallet.Font
		title.Parent = window
		local close = addCloseButton(window, 7)
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.fromOffset(0, 37)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		divider.BorderSizePixel = 0
		divider.Parent = window
		local childrentoggle = Instance.new('Frame')
		childrentoggle.Position = UDim2.fromOffset(0, 38)
		childrentoggle.BackgroundTransparency = 1
		childrentoggle.Parent = window
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Parent = childrentoggle

		function optionapi:CreateToggle(togglesettings)
			local toggleapi = {
				Enabled = false,
				Index = getTableSize(optionapi.Toggles)
			}

			local hovered = false
			local toggle = Instance.new('TextButton')
			toggle.Name = togglesettings.Name..'Toggle'
			toggle.Size = UDim2.new(1, 0, 0, 40)
			toggle.BackgroundTransparency = 1
			toggle.AutoButtonColor = false
			toggle.Text = string.rep(' ', 33 * scale.Scale)..togglesettings.Name
			toggle.TextXAlignment = Enum.TextXAlignment.Left
			toggle.TextColor3 = color.Dark(uipallet.Text, 0.16)
			toggle.TextSize = 14
			toggle.FontFace = uipallet.Font
			toggle.Parent = childrentoggle
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = togglesettings.Size
			icon.Position = togglesettings.Position
			icon.BackgroundTransparency = 1
			icon.Image = togglesettings.Icon
			icon.ImageColor3 = uipallet.Text
			icon.Parent = toggle
			local knob = Instance.new('Frame')
			knob.Name = 'Knob'
			knob.Size = UDim2.fromOffset(22, 12)
			knob.Position = UDim2.new(1, -30, 0, 14)
			knob.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			knob.Parent = toggle
			addCorner(knob, UDim.new(1, 0))
			local knobmain = knob:Clone()
			knobmain.Size = UDim2.fromOffset(8, 8)
			knobmain.Position = UDim2.fromOffset(2, 2)
			knobmain.BackgroundColor3 = uipallet.Main
			knobmain.Parent = knob
			toggleapi.Object = toggle

			function toggleapi:Toggle()
				self.Enabled = not self.Enabled
				tween:Tween(knob, uipallet.Tween, {
					BackgroundColor3 = self.Enabled and Color3.fromHSV(
						mainapi.GUIColor.Hue,
						mainapi.GUIColor.Sat,
						mainapi.GUIColor.Value
					) or (hovered and color.Light(uipallet.Main, 0.37) or color.Light(uipallet.Main, 0.14))
				})
				tween:Tween(knobmain, uipallet.Tween, {
					Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
				})
				togglesettings.Function(self.Enabled)
			end

			scale:GetPropertyChangedSignal('Scale'):Connect(function()
				toggle.Text = string.rep(' ', 33 * scale.Scale)..togglesettings.Name
			end)
			toggle.MouseEnter:Connect(function()
				hovered = true
				if not toggleapi.Enabled then
					tween:Tween(knob, uipallet.Tween, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.37)
					})
				end
			end)
			toggle.MouseLeave:Connect(function()
				hovered = false
				if not toggleapi.Enabled then
					tween:Tween(knob, uipallet.Tween, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.14)
					})
				end
			end)
			toggle.MouseButton1Click:Connect(function()
				toggleapi:Toggle()
			end)

			table.insert(optionapi.Toggles, toggleapi)

			return toggleapi
		end

		button.MouseEnter:Connect(function()
			button.ImageColor3 = uipallet.Text
			tween:Tween(button, uipallet.Tween, {
				BackgroundTransparency = 0.9
			})
		end)
		button.MouseLeave:Connect(function()
			button.ImageColor3 = color.Light(uipallet.Main, 0.37)
			tween:Tween(button, uipallet.Tween, {
				BackgroundTransparency = 1
			})
		end)
		button.MouseButton1Click:Connect(function()
			shadow.Visible = true
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 0.5
			})
			tween:Tween(window, uipallet.Tween, {
				Position = UDim2.new(0, 0, 1, -(window.Size.Y.Offset))
			})
		end)
		close.MouseButton1Click:Connect(function()
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 1
			})
			tween:Tween(window, uipallet.Tween, {
				Position = UDim2.fromScale(0, 1)
			})
			task.wait(0.2)
			shadow.Visible = false
		end)
		shadow.MouseButton1Click:Connect(function()
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 1
			})
			tween:Tween(window, uipallet.Tween, {
				Position = UDim2.fromScale(0, 1)
			})
			task.wait(0.2)
			shadow.Visible = false
		end)
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			window.Size = UDim2.fromOffset(220, math.min(37 + windowlist.AbsoluteContentSize.Y / scale.Scale, 605))
			childrentoggle.Size = UDim2.fromOffset(220, window.Size.Y.Offset - 5)
		end)

		mainapi.Overlays = optionapi

		return optionapi
	end

	function categoryapi:CreateSettingsDivider()
		components.Divider(settingschildren)
	end

	function categoryapi:CreateSettingsPane(categorysettings)
		local optionapi = {}

		local button = Instance.new('TextButton')
		button.Name = categorysettings.Name
		button.Size = UDim2.fromOffset(220, 40)
		button.BackgroundColor3 = uipallet.Main
		addGlass(button)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = '          '..categorysettings.Name
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextColor3 = color.Dark(uipallet.Text, 0.16)
		button.TextSize = 14
		button.FontFace = uipallet.Font
		button.Parent = settingschildren
		addHoverFX(button)
		local arrow = Instance.new('ImageLabel')
		arrow.Name = 'Arrow'
		arrow.Size = UDim2.fromOffset(4, 8)
		arrow.Position = UDim2.new(1, -20, 0, 16)
		arrow.BackgroundTransparency = 1
		arrow.Image = getcustomasset('aetherv2/assets/new/expandright.png')
		arrow.ImageColor3 = color.Light(uipallet.Main, 0.37)
		arrow.Parent = button
		local settingspane = Instance.new('TextButton')
		settingspane.Size = UDim2.fromScale(1, 1)
		settingspane.BackgroundColor3 = uipallet.Main
		settingspane.AutoButtonColor = false
		settingspane.Visible = false
		settingspane.Text = ''
		settingspane.Parent = window
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -36, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
		title.BackgroundTransparency = 1
		title.Text = categorysettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = settingspane
		local close = addCloseButton(settingspane)
		local back = Instance.new('ImageButton')
		back.Name = 'Back'
		back.Size = UDim2.fromOffset(16, 16)
		back.Position = UDim2.fromOffset(11, 13)
		back.BackgroundTransparency = 1
		back.Image = getcustomasset('aetherv2/assets/new/back.png')
		back.ImageColor3 = color.Light(uipallet.Main, 0.37)
		back.Parent = settingspane
		addCorner(settingspane)
		-- A ScrollingFrame (not a plain Frame) so panes with more options than the
		-- window is tall - Interface, Windows - scroll inside the window instead of
		-- spilling their bottom rows out past its edge, half-floating in mid-air.
		local settingschildren = Instance.new('ScrollingFrame')
		settingschildren.Name = 'Children'
		settingschildren.Size = UDim2.new(1, 0, 1, -57)
		settingschildren.Position = UDim2.fromOffset(0, 41)
		settingschildren.BackgroundColor3 = uipallet.Main
		settingschildren.BorderSizePixel = 0
		settingschildren.ScrollBarThickness = 3
		settingschildren.ScrollBarImageTransparency = 0.6
		settingschildren.ScrollingDirection = Enum.ScrollingDirection.Y
		settingschildren.CanvasSize = UDim2.new()
		settingschildren.AutomaticCanvasSize = Enum.AutomaticSize.Y
		settingschildren.ClipsDescendants = true
		settingschildren.Parent = settingspane
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.BackgroundColor3 = Color3.new(1, 1, 1)
		divider.BackgroundTransparency = 0.928
		divider.BorderSizePixel = 0
		divider.Parent = settingschildren
		local settingswindowlist = Instance.new('UIListLayout')
		settingswindowlist.SortOrder = Enum.SortOrder.LayoutOrder
		settingswindowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		settingswindowlist.Parent = settingschildren

		for i, v in components do
			optionapi['Create'..i] = function(_, settings)
				return v(settings, settingschildren, categoryapi)
			end
		end

		back.MouseEnter:Connect(function()
			back.ImageColor3 = uipallet.Text
		end)
		back.MouseLeave:Connect(function()
			back.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)
		back.MouseButton1Click:Connect(function()
			settingspane.Visible = false
		end)
		button.MouseEnter:Connect(function()
			button.TextColor3 = uipallet.Text
			button.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		end)
		button.MouseLeave:Connect(function()
			button.TextColor3 = color.Dark(uipallet.Text, 0.16)
			button.BackgroundColor3 = uipallet.Main
		end)
		button.MouseButton1Click:Connect(function()
			settingspane.Visible = true
		end)
		close.MouseButton1Click:Connect(function()
			settingspane.Visible = false
		end)
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			window.Size = UDim2.fromOffset(220, 45 + windowlist.AbsoluteContentSize.Y / scale.Scale)
			for _, v in categoryapi.Buttons do
				if v.Icon then
					v.Object.Text = string.rep(' ', 33 * scale.Scale)..v.Name
				end
			end
		end)

		return optionapi
	end

	function categoryapi:CreateGUISlider(optionsettings)
		local optionapi = {
			Type = 'GUISlider',
			Notch = accent.Notch,
			Hue = accent.Hue,
			Sat = accent.Sat,
			Value = accent.Value,
			Rainbow = false,
			CustomColor = false
		}
		local slidercolors = {
			Color3.fromRGB(250, 50, 56),
			Color3.fromRGB(242, 99, 33),
			Color3.fromRGB(252, 179, 22),
			Color3.fromRGB(5, 133, 104),
			Color3.fromRGB(47, 122, 229),
			Color3.fromRGB(190, 115, 255),
			Color3.fromRGB(232, 96, 152)
		}
		local slidercolorpos = {
			4,
			33,
			62,
			90,
			119,
			148,
			177
		}

		local function createSlider(name, gradientColor)
			local slider = Instance.new('TextButton')
			slider.Name = optionsettings.Name..'Slider'..name
			slider.Size = UDim2.fromOffset(220, 50)
			slider.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slider.BorderSizePixel = 0
			slider.AutoButtonColor = false
			slider.Visible = false
			slider.Text = ''
			slider.Parent = settingschildren
			local title = Instance.new('TextLabel')
			title.Name = 'Title'
			title.Size = UDim2.fromOffset(60, 30)
			title.Position = UDim2.fromOffset(10, 2)
			title.BackgroundTransparency = 1
			title.Text = name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = color.Dark(uipallet.Text, 0.16)
			title.TextSize = 11
			title.FontFace = uipallet.Font
			title.Parent = slider
			local holder = Instance.new('Frame')
			holder.Name = 'Slider'
			holder.Size = UDim2.fromOffset(200, 2)
			holder.Position = UDim2.fromOffset(10, 37)
			holder.BackgroundColor3 = Color3.new(1, 1, 1)
			holder.BorderSizePixel = 0
			holder.Parent = slider
			local uigradient = Instance.new('UIGradient')
			uigradient.Color = gradientColor
			uigradient.Parent = holder
			local fill = holder:Clone()
			fill.Name = 'Fill'
			fill.Size = UDim2.fromScale(math.clamp(1, 0.04, 0.96), 1)
			fill.Position = UDim2.new()
			fill.BackgroundTransparency = 1
			fill.Parent = holder
			local knobframe = Instance.new('Frame')
			knobframe.Name = 'Knob'
			knobframe.Size = UDim2.fromOffset(24, 4)
			knobframe.Position = UDim2.fromScale(1, 0.5)
			knobframe.AnchorPoint = Vector2.new(0.5, 0.5)
			knobframe.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			knobframe.BorderSizePixel = 0
			knobframe.Parent = fill
			local knob = Instance.new('Frame')
			knob.Name = 'Knob'
			knob.Size = UDim2.fromOffset(14, 14)
			knob.Position = UDim2.fromScale(0.5, 0.5)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.BackgroundColor3 = uipallet.Text
			knob.Parent = knobframe
			addCorner(knob, UDim.new(1, 0))
			if name == 'Custom color' then
				local reset = Instance.new('TextButton')
				reset.Size = UDim2.fromOffset(45, 20)
				reset.Position = UDim2.new(1, -52, 0, 5)
				reset.BackgroundTransparency = 1
				reset.Text = 'RESET'
				reset.TextColor3 = color.Dark(uipallet.Text, 0.16)
				reset.TextSize = 11
				reset.FontFace = uipallet.Font
				reset.Parent = slider
				reset.MouseButton1Click:Connect(function()
					optionapi:SetValue(nil, nil, nil, accent.Notch)
				end)
			end

			slider.InputBegan:Connect(function(inputObj)
				if
					(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
					and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
				then
					local changed = inputService.InputChanged:Connect(function(input)
						if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
							local value = math.clamp((input.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)
							optionapi:SetValue(
								name == 'Custom color' and value or nil,
								name == 'Saturation' and value or nil,
								name == 'Vibrance' and value or nil,
								name == 'Opacity' and value or nil
							)
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
			slider.MouseEnter:Connect(function()
				tween:Tween(knob, uipallet.Tween, {
					Size = UDim2.fromOffset(16, 16)
				})
			end)
			slider.MouseLeave:Connect(function()
				tween:Tween(knob, uipallet.Tween, {
					Size = UDim2.fromOffset(14, 14)
				})
			end)

			return slider
		end

		local slider = Instance.new('TextButton')
		slider.Name = optionsettings.Name..'Slider'
		slider.Size = UDim2.fromOffset(220, 50)
		slider.BackgroundTransparency = 1
		slider.AutoButtonColor = false
		slider.Text = ''
		slider.Parent = settingschildren
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.fromOffset(60, 30)
		title.Position = UDim2.fromOffset(10, 2)
		title.BackgroundTransparency = 1
		title.Text = optionsettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = color.Dark(uipallet.Text, 0.16)
		title.TextSize = 11
		title.FontFace = uipallet.Font
		title.Parent = slider
		local holder = Instance.new('Frame')
		holder.Name = 'Slider'
		holder.Size = UDim2.fromOffset(200, 2)
		holder.Position = UDim2.fromOffset(10, 37)
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Parent = slider
		local colornum = 0
		for i, color in slidercolors do
			local colorframe = Instance.new('Frame')
			colorframe.Size = UDim2.fromOffset(27 + (((i + 1) % 2) == 0 and 1 or 0), 2)
			colorframe.Position = UDim2.fromOffset(colornum, 0)
			colorframe.BackgroundColor3 = color
			colorframe.BorderSizePixel = 0
			colorframe.Parent = holder
			colornum += (colorframe.Size.X.Offset + 1)
		end
		local preview = Instance.new('ImageButton')
		preview.Name = 'Preview'
		preview.Size = UDim2.fromOffset(12, 12)
		preview.Position = UDim2.new(1, -22, 0, 10)
		preview.BackgroundTransparency = 1
		preview.Image = getcustomasset('aetherv2/assets/new/colorpreview.png')
		preview.ImageColor3 = Color3.fromHSV(optionapi.Hue, 1, 1)
		preview.Parent = slider
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
		local expandbutton = Instance.new('TextButton')
		expandbutton.Name = 'Expand'
		expandbutton.Size = UDim2.fromOffset(17, 13)
		expandbutton.Position = UDim2.new(0, getfontsize(title.Text, title.TextSize, title.Font).X + 11, 0, 7)
		expandbutton.BackgroundTransparency = 1
		expandbutton.Text = ''
		expandbutton.Parent = slider
		local expandicon = Instance.new('ImageLabel')
		expandicon.Name = 'Expand'
		expandicon.Size = UDim2.fromOffset(9, 5)
		expandicon.Position = UDim2.fromOffset(4, 4)
		expandicon.BackgroundTransparency = 1
		expandicon.Image = getcustomasset('aetherv2/assets/new/expandicon.png')
		expandicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		expandicon.Parent = expandbutton
		local rainbow = Instance.new('TextButton')
		rainbow.Name = 'Rainbow'
		rainbow.Size = UDim2.fromOffset(12, 12)
		rainbow.Position = UDim2.new(1, -42, 0, 10)
		rainbow.BackgroundTransparency = 1
		rainbow.Text = ''
		rainbow.Parent = slider
		local rainbow1 = Instance.new('ImageLabel')
		rainbow1.Size = UDim2.fromOffset(12, 12)
		rainbow1.BackgroundTransparency = 1
		rainbow1.Image = getcustomasset('aetherv2/assets/new/rainbow_1.png')
		rainbow1.ImageColor3 = color.Light(uipallet.Main, 0.37)
		rainbow1.Parent = rainbow
		local rainbow2 = rainbow1:Clone()
		rainbow2.Image = getcustomasset('aetherv2/assets/new/rainbow_2.png')
		rainbow2.Parent = rainbow
		local rainbow3 = rainbow1:Clone()
		rainbow3.Image = getcustomasset('aetherv2/assets/new/rainbow_3.png')
		rainbow3.Parent = rainbow
		local rainbow4 = rainbow1:Clone()
		rainbow4.Image = getcustomasset('aetherv2/assets/new/rainbow_4.png')
		rainbow4.Parent = rainbow
		local knob = Instance.new('ImageLabel')
		knob.Name = 'Knob'
		knob.Size = UDim2.fromOffset(26, 12)
		knob.Position = UDim2.fromOffset(slidercolorpos[accent.Notch] - 3, -5)
		knob.BackgroundTransparency = 1
		knob.Image = getcustomasset('aetherv2/assets/new/guislider.png')
		knob.ImageColor3 = slidercolors[accent.Notch]
		knob.Parent = holder
		optionsettings.Function = optionsettings.Function or function() end
		local rainbowTable = {}
		for i = 0, 1, 0.1 do
			table.insert(rainbowTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
		end
		local colorSlider = createSlider('Custom color', ColorSequence.new(rainbowTable))
		local satSlider = createSlider('Saturation', ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, optionapi.Value)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, 1, optionapi.Value))
		}))
		local vibSlider = createSlider('Vibrance', ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, optionapi.Sat, 1))
		}))
		local normalknob = getcustomasset('aetherv2/assets/new/guislider.png')
		local rainbowknob = getcustomasset('aetherv2/assets/new/guisliderrain.png')
		local rainbowthread

		function optionapi:Save(tab)
			tab[optionsettings.Name] = {
				Hue = self.Hue,
				Sat = self.Sat,
				Value = self.Value,
				Notch = self.Notch,
				CustomColor = self.CustomColor,
				Rainbow = self.Rainbow
			}
		end

		function optionapi:Load(tab)
			-- Configs written while the accent was teal carry it here too, which is what
			-- kept the menu itself opening on the retired colour.
			tab = configapi.Accents.Apply(tab, true)
			if tab.Rainbow then
				self:Toggle()
			end
			if self.Rainbow or tab.CustomColor then
				self:SetValue(tab.Hue, tab.Sat, tab.Value)
			else
				-- Preset accents are stored as a notch index. Each GUI theme has its
				-- own notch palette, so blindly re-applying the notch on load turned
				-- a saved accent into a different colour when you switched GUIs. If
				-- the stored notch still maps to the stored colour we keep the notch
				-- (same GUI); otherwise we restore the exact saved HSV so the accent
				-- survives the switch.
				local notchColor = tab.Notch and slidercolors[tab.Notch]
				if notchColor and tab.Hue and tab.Sat and tab.Value then
					local nh, ns, nv = notchColor:ToHSV()
					if math.abs(nh - tab.Hue) < 0.01 and math.abs(ns - tab.Sat) < 0.01 and math.abs(nv - tab.Value) < 0.01 then
						self:SetValue(nil, nil, nil, tab.Notch)
					else
						self:SetValue(tab.Hue, tab.Sat, tab.Value)
					end
				elseif tab.Hue and tab.Sat and tab.Value then
					self:SetValue(tab.Hue, tab.Sat, tab.Value)
				else
					self:SetValue(nil, nil, nil, tab.Notch)
				end
			end
		end

		function optionapi:SetValue(h, s, v, n)
			if n then
				if self.Rainbow then
					self:Toggle()
				end
				self.CustomColor = false
				h, s, v = slidercolors[n]:ToHSV()
			else
				self.CustomColor = true
			end

			self.Hue = h or self.Hue
			self.Sat = s or self.Sat
			self.Value = v or self.Value
			self.Notch = n
			preview.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
			satSlider.Slider.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, self.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, 1, self.Value))
			})
			vibSlider.Slider.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, 1))
			})

			if self.Rainbow or self.CustomColor then
				knob.Image = rainbowknob
				knob.ImageColor3 = Color3.new(1, 1, 1)
				tween:Tween(knob, uipallet.Tween, {
					Position = UDim2.fromOffset(slidercolorpos[accent.Notch] - 3, -5)
				})
			else
				knob.Image = normalknob
				knob.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
				tween:Tween(knob, uipallet.Tween, {
					Position = UDim2.fromOffset(slidercolorpos[n or accent.Notch] - 3, -5)
				})
			end

			if self.Rainbow then
				if h then
					colorSlider.Slider.Fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
				end
				if s then
					satSlider.Slider.Fill.Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
				end
				if v then
					vibSlider.Slider.Fill.Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
				end
			else
				if h then
					tween:Tween(colorSlider.Slider.Fill, uipallet.Tween, {
						Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
					})
				end
				if s then
					tween:Tween(satSlider.Slider.Fill, uipallet.Tween, {
						Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
					})
				end
				if v then
					tween:Tween(vibSlider.Slider.Fill, uipallet.Tween, {
						Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
					})
				end
			end
			optionsettings.Function(self.Hue, self.Sat, self.Value)
		end

		function optionapi:Toggle()
			self.Rainbow = not self.Rainbow
			if rainbowthread then
				task.cancel(rainbowthread)
			end

			if self.Rainbow then
				knob.Image = rainbowknob
				table.insert(mainapi.RainbowTable, self)

				rainbow1.ImageColor3 = Color3.fromRGB(5, 127, 100)
				rainbowthread = task.delay(0.1, function()
					rainbow2.ImageColor3 = Color3.fromRGB(228, 125, 43)
					rainbowthread = task.delay(0.1, function()
						rainbow3.ImageColor3 = Color3.fromRGB(225, 46, 52)
						rainbowthread = nil
					end)
				end)
			else
				self:SetValue(nil, nil, nil, accent.Notch)
				knob.Image = normalknob
				local ind = table.find(mainapi.RainbowTable, self)
				if ind then
					table.remove(mainapi.RainbowTable, ind)
				end

				rainbow3.ImageColor3 = color.Light(uipallet.Main, 0.37)
				rainbowthread = task.delay(0.1, function()
					rainbow2.ImageColor3 = color.Light(uipallet.Main, 0.37)
					rainbowthread = task.delay(0.1, function()
						rainbow1.ImageColor3 = color.Light(uipallet.Main, 0.37)
					end)
				end)
			end
		end

		expandbutton.MouseEnter:Connect(function()
			expandicon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
		end)
		expandbutton.MouseLeave:Connect(function()
			expandicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		end)
		expandbutton.MouseButton1Click:Connect(function()
			colorSlider.Visible = not colorSlider.Visible
			satSlider.Visible = colorSlider.Visible
			vibSlider.Visible = satSlider.Visible
			expandicon.Rotation = satSlider.Visible and 180 or 0
		end)
		preview.MouseButton1Click:Connect(function()
			preview.Visible = false
			valuebox.Visible = true
			valuebox:CaptureFocus()
			local text = Color3.fromHSV(optionapi.Hue, optionapi.Sat, optionapi.Value)
			valuebox.Text = math.round(text.R * 255)..', '..math.round(text.G * 255)..', '..math.round(text.B * 255)
		end)
		slider.InputBegan:Connect(function(inputObj)
			if
				(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
				and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
			then
				local changed = inputService.InputChanged:Connect(function(input)
					if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
						optionapi:SetValue(nil, nil, nil, math.clamp(math.round((input.Position.X - holder.AbsolutePosition.X) / scale.Scale / 27), 1, 7))
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
				optionapi:SetValue(nil, nil, nil, math.clamp(math.round((inputObj.Position.X - holder.AbsolutePosition.X) / scale.Scale / 27), 1, 7))
			end
		end)
		rainbow.MouseButton1Click:Connect(function()
			optionapi:Toggle()
		end)
		valuebox.FocusLost:Connect(function(enter)
			preview.Visible = true
			valuebox.Visible = false
			if enter then
				local commas = valuebox.Text:split(',')
				local suc, res = pcall(function()
					return tonumber(commas[1]) and Color3.fromRGB(
						tonumber(commas[1]),
						tonumber(commas[2]),
						tonumber(commas[3])
					) or Color3.fromHex(valuebox.Text)
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
		categoryapi.Options[optionsettings.Name] = optionapi

		return optionapi
	end

	back.MouseEnter:Connect(function()
		back.ImageColor3 = uipallet.Text
	end)
	back.MouseLeave:Connect(function()
		back.ImageColor3 = color.Light(uipallet.Main, 0.37)
	end)
	back.MouseButton1Click:Connect(function()
		settingspane.Visible = false
	end)
	close.MouseButton1Click:Connect(function()
		settingspane.Visible = false
	end)
	discordbutton.MouseButton1Click:Connect(function()
		task.spawn(function()
			local body = httpService:JSONEncode({
				nonce = httpService:GenerateGUID(false),
				args = {
					invite = {code = 'aetherv2'},
					code = 'aetherv2'
				},
				cmd = 'INVITE_BROWSER'
			})

			for i = 1, 14 do
				task.defer(function()
					request({
						Method = 'POST',
						Url = 'http://127.0.0.1:64'..(53 + i)..'/rpc?v=1',
						Headers = {
							['Content-Type'] = 'application/json',
							Origin = 'https://discord.com'
						},
						Body = body
					})
				end)
			end
		end)

		task.spawn(function()
			tooltip.Text = 'Copied!'
			setclipboard('https://discord.gg/aYu5c9v9zv')
		end)
	end)
	settingsbutton.MouseEnter:Connect(function()
		settingsicon.ImageColor3 = uipallet.Text
	end)
	settingsbutton.MouseLeave:Connect(function()
		settingsicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
	end)
	settingsbutton.MouseButton1Click:Connect(function()
		settingspane.Visible = true
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		window.Size = UDim2.fromOffset(220, 42 + windowlist.AbsoluteContentSize.Y / scale.Scale)
		for _, v in categoryapi.Buttons do
			if v.Icon then
				v.Object.Text = string.rep(' ', 36 * scale.Scale)..v.Name
			end
		end
	end)

	self.Categories.Main = categoryapi

	return categoryapi
end

--[[
	Settings redesign (v5.2) - shared engine for the reworked module settings.

	Powers the new expandable module settings: ease-in-out open/close,
	collapsible sub-categories, and the smooth "scroll a module into view +
	flash it" behaviour shared by the search bar and the favourites system.
	Kept at module scope (just above CreateCategory) so CreateModule can close
	over it without threading extra state through every component.
]]

-- Ease-in-out variant of the shared micro-tween. Reads the live speed / easing
-- style / master switch from uipallet.Tween (Settings -> Interface) but forces
-- InOut so panels grow and shrink symmetrically instead of snapping.
local function settingsTweenInfo()
	return TweenInfo.new(uipallet.Tween.Time, uipallet.Tween.EasingStyle, Enum.EasingDirection.InOut)
end

-- Explicit sub-category layouts for the heaviest modules, matched by option
-- name (case-insensitive). Any option a layout doesn't mention drops into a
-- leading "General" group, so partial matches (another game renaming a setting)
-- degrade gracefully instead of the setting vanishing.
local settingSubcategories = {
	Killaura = {
		{'Targeting', {'Targets', 'Target Mode', 'Attack Mode', 'Max targets', 'Max angle', 'Attackable check', 'GUI check', 'Require mouse down', 'Limit to items'}},
		{'Range & Timing', {'Swing range', 'Attack range', 'Swing time', 'Update rate', 'Fire rate', 'HitReg', 'Air Hit Chance', 'Continue Swinging'}},
		{'Visuals', {'Show target', 'Target Color', 'Attack Color', 'Render type', 'Target particles', 'Texture', 'Color Begin', 'Color End', 'Size'}},
		{'Animation', {'Custom Animation', 'Animation Mode', 'Animation Speed', 'No Swing', 'Swing only', 'Face target', 'No Tween'}},
		{'Advanced', {'Unpatch', 'Projectiles', 'Legit Switch'}}
	}
}

-- Fallback keyword buckets for any other module with enough settings to make
-- grouping worthwhile. The order here is the order groups render in (after the
-- leading General group).
local subKeywordGroups = {
	{'Targeting', {'target', 'aim', 'angle', 'fov', 'range', 'wall', 'npc', 'player', 'priorit', 'invis', 'distance', 'reach', 'sort'}},
	{'Visuals', {'color', 'colour', 'render', 'particle', 'texture', 'cham', 'esp', 'tracer', 'show', 'visual', 'glow', 'opacit', 'transparen', 'outline', 'gradient', 'indicator', 'marker', 'trail', 'size', 'hud'}},
	{'Timing', {'rate', 'speed', 'delay', 'time', 'cooldown', 'tick', 'cps', 'interval', 'chance', 'continue', 'fast', 'duration', 'ping', 'smooth'}}
}
local subAutoThreshold = 8

-- Buckets an option into a keyword group; falls back to General when nothing
-- in the name matches a known keyword.
local function classifySetting(name)
	if not name then return 'General' end
	local lower = name:lower()
	for _, group in subKeywordGroups do
		for _, key in group[2] do
			if lower:find(key, 1, true) then
				return group[1]
			end
		end
	end
	return 'General'
end

-- Session-only memory of which sub-categories a user left open, keyed by
-- "Module|Group". Deliberately not persisted (keeps the config save format
-- untouched) but makes re-opening a module feel sticky within a session.
local subGroupMemory = {}

-- Fades a soft highlight over a module row - the arrival cue for search jumps.
-- Cheap: one frame tweens its transparency out and destroys itself, so there's
-- nothing to clean up and no per-frame work.
local function flashModule(obj, tint)
	if not obj or not obj.Parent then return end
	local existing = obj:FindFirstChild('JumpFlash')
	if existing then existing:Destroy() end
	local flash = Instance.new('Frame')
	flash.Name = 'JumpFlash'
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = tint or Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.6
	flash.BorderSizePixel = 0
	flash.ZIndex = 6
	flash.Parent = obj
	addCorner(flash, UDim.new(0, cornerRadius))
	tweenService:Create(flash, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
	task.delay(0.6, function()
		flash:Destroy()
	end)
end
mainapi.FlashModule = flashModule

-- Smoothly scrolls a module's category so the module sits centred in the
-- category window, opening the category first if it's toggled-off or collapsed.
-- Accurate even when modules above have their settings expanded, because it
-- measures real layout (AbsolutePosition) rather than assuming 40px rows, and
-- it waits for the open/expand animation to settle before measuring so the
-- viewport height it centres against is the final one.
function mainapi:ScrollToModule(moduleapi, opts)
	opts = opts or {}
	local catapi = moduleapi and moduleapi.CategoryAPI
	local obj = moduleapi and moduleapi.Object
	if not catapi or not obj then return end

	local needsOpen = false
	-- Toggled-off category: turn its window on via the same button the user would.
	if catapi.Button and not catapi.Button.Enabled then
		catapi.Button:Toggle()
		needsOpen = true
	elseif catapi.Object and not catapi.Object.Visible then
		catapi.Object.Visible = true
		needsOpen = true
	end
	-- Minimised category: expand it so the rows exist to scroll to.
	if catapi.Expanded == false then
		catapi:Expand()
		needsOpen = true
	end

	-- Let the open/expand tween settle before measuring; otherwise the viewport
	-- is mid-grow and centring lands too high.
	local settle = needsOpen and (uipallet.Tween.Time + 0.03) or 0
	task.delay(settle, function()
		local frame = obj.Parent
		if not frame or not frame:IsA('ScrollingFrame') then return end
		local sc = scale.Scale
		-- Module top in unscaled canvas offsets (AbsolutePosition is post-scale).
		local moduleY = (obj.AbsolutePosition.Y - frame.AbsolutePosition.Y) / sc + frame.CanvasPosition.Y
		local viewport = frame.AbsoluteWindowSize.Y / sc
		local rowH = obj.AbsoluteSize.Y / sc
		local target = moduleY - (viewport / 2) + (rowH / 2)
		local maxScroll = math.max(0, frame.CanvasSize.Y.Offset - viewport)
		target = math.clamp(target, 0, maxScroll)

		if uipallet.Tween.Time <= 0 then
			frame.CanvasPosition = Vector2.new(0, target)
		else
			tweenService:Create(frame, settingsTweenInfo(), {
				CanvasPosition = Vector2.new(0, target)
			}):Play()
		end
		if opts.Flash ~= false then
			flashModule(obj, opts.Tint)
		end
	end)
end

function mainapi:CreateCategory(categorysettings)
	local categoryapi = {
		Type = 'Category',
		Expanded = false
	}

	-- Spread new category windows across a lattice instead of stacking every one
	-- at the same spot. Previously every category defaulted to (236, 60), so
	-- opening several piled them on top of each other and the ones underneath
	-- looked like they "wouldn't open". Slot 0 is the main window (6, 60); each
	-- category takes the next lattice cell (8 columns, wrapping to a second row),
	-- matching the "Sort GUI" layout. A saved profile position still overrides
	-- this on load, so arranged layouts are untouched.
	mainapi.CategorySlot = (mainapi.CategorySlot or 0) + 1
	local slot = mainapi.CategorySlot
	local defaultX = 6 + (slot % 8) * 230
	local defaultY = 60 + math.floor(slot / 8) * 360

	local window = Instance.new('TextButton')
	window.Name = categorysettings.Name..'Category'
	window.Size = UDim2.fromOffset(220, 41)
	window.Position = UDim2.fromOffset(defaultX, defaultY)
	window.BackgroundColor3 = uipallet.Main
	window.AutoButtonColor = false
	window.Visible = false
	window.Text = ''
	window.Parent = clickgui
	addBlur(window)
	addCorner(window)
	addWindowStroke(window)
	makeDraggable(window)
	local icon = Instance.new('ImageLabel')
	icon.Name = 'Icon'
	icon.Size = categorysettings.Size
	icon.Position = UDim2.fromOffset(12, (icon.Size.X.Offset > 20 and 14 or 13))
	icon.BackgroundTransparency = 1
	icon.Image = categorysettings.Icon
	icon.ImageColor3 = uipallet.Text
	icon.Parent = window
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.new(1, -(categorysettings.Size.X.Offset > 18 and 40 or 33), 0, 41)
	title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 0)
	title.BackgroundTransparency = 1
	title.Text = categorysettings.Name
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = uipallet.Text
	title.TextSize = 13
	title.FontFace = uipallet.Font
	title.Parent = window
	local arrowbutton = Instance.new('TextButton')
	arrowbutton.Name = 'Arrow'
	arrowbutton.Size = UDim2.fromOffset(40, 40)
	arrowbutton.Position = UDim2.new(1, -40, 0, 0)
	arrowbutton.BackgroundTransparency = 1
	arrowbutton.Text = ''
	arrowbutton.Parent = window
	local arrow = Instance.new('ImageLabel')
	arrow.Name = 'Arrow'
	arrow.Size = UDim2.fromOffset(9, 4)
	arrow.Position = UDim2.fromOffset(20, 18)
	arrow.BackgroundTransparency = 1
	arrow.Image = getcustomasset('aetherv2/assets/new/expandup.png')
	arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
	arrow.Rotation = 180
	arrow.Parent = arrowbutton
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, -41)
	children.Position = UDim2.fromOffset(0, 37)
	children.BackgroundTransparency = 1
	children.BorderSizePixel = 0
	children.Visible = false
	children.ScrollBarThickness = 2
	children.ScrollBarImageTransparency = 0.75
	children.ScrollingDirection = Enum.ScrollingDirection.Y
	children.Active = true
	children.ClipsDescendants = true
	children.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	children.CanvasSize = UDim2.new()
	children.Parent = window
	local divider = Instance.new('Frame')
	divider.Name = 'Divider'
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.fromOffset(0, 37)
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.928
	divider.BorderSizePixel = 0
	divider.Visible = false
	divider.Parent = window
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	windowlist.Parent = children

	function categoryapi:CreateModule(modulesettings)
		mainapi:Remove(modulesettings.Name, true)
		local moduleapi = {
			Enabled = false,
			Favourited = false,
			Options = {},
			Bind = {},
			Tags = {},
			Index = getTableSize(mainapi.Modules),
			ExtraText = modulesettings.ExtraText,
			Name = modulesettings.Name,
			Category = categorysettings.Name
		}

		local hovered = false
		-- Whether this module's settings panel is expanded. Replaces the old
		-- "is modulechildren.Visible" check so the row can keep treating itself as
		-- open while the collapse animation plays out (Visible only flips off once
		-- the ease-in-out finishes).
		local settingsOpen = false
		-- Points the shared favourites/search scroll engine at this module's
		-- category so ScrollToModule can open + centre it.
		moduleapi.CategoryAPI = categoryapi
		local modulebutton = Instance.new('TextButton')
		modulebutton.Name = modulesettings.Name
		modulebutton.Size = UDim2.fromOffset(220, 40)
		modulebutton.BackgroundColor3 = uipallet.Main
		addGlass(modulebutton)
		modulebutton.BorderSizePixel = 0
		modulebutton.AutoButtonColor = false
		modulebutton.Text = '            '..modulesettings.Name
		modulebutton.TextXAlignment = Enum.TextXAlignment.Left
		modulebutton.TextColor3 = color.Dark(uipallet.Text, 0.16)
		modulebutton.TextSize = 14
		modulebutton.FontFace = uipallet.Font
		modulebutton.Parent = children
		-- v6 redesign: a left accent bar that lights up in the theme colour when the
		-- module is on. The row itself stays a flat dark surface (a subtle raised
		-- tint) instead of the old full-accent highlight, so on/off reads as a clean
		-- list item with an accent edge + accent label.
		local accentbar = Instance.new('Frame')
		accentbar.Name = 'AccentBar'
		accentbar.Size = UDim2.fromOffset(3, 22)
		accentbar.Position = UDim2.new(0, 6, 0.5, 0)
		accentbar.AnchorPoint = Vector2.new(0, 0.5)
		accentbar.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		accentbar.BorderSizePixel = 0
		accentbar.BackgroundTransparency = 1
		accentbar.Visible = false
		accentbar.Parent = modulebutton
		addCorner(accentbar, UDim.new(1, 0))
		local indicatorholder = Instance.new('Frame')
		indicatorholder.Parent = modulebutton
		indicatorholder.Size = UDim2.fromOffset(0, 21)
		indicatorholder.AnchorPoint = Vector2.new(0, 0.5)
		indicatorholder.Name = 'Indicators'
		indicatorholder.BackgroundTransparency = 1
		indicatorholder.Position = UDim2.fromScale(0.85, 0.5)

		do
			local layout = Instance.new('UIListLayout')
			layout.Parent = indicatorholder
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Padding = UDim.new(0, 5)
		end

		modulesettings.Tags = modulesettings.Tags or {}
		pcall(function()
			applyFeatureTags(modulesettings.Tags, moduleapi.Name)
			for i, tag in modulesettings.Tags do
				tag = tag:upper()
				local size = getfontsize(removeTags(tag), 12, uipallet.Font, Vector2.new(100000, 100000))
				local indicator = Instance.new('TextLabel')
				indicator.LayoutOrder = i - 1
				indicator.Size = UDim2.new(0, size.X + 4, 0, 21)
				indicator.BackgroundColor3 = Color3.new(1, 1, 1)
				indicator.TextSize = 14
				indicator.TextTransparency = 1
				indicator.Text = tag
				indicator.Name = tag
				indicator.Position = UDim2.new()
				indicator.TextColor3 = Color3.new(0, 0, 0)
				indicator.FontFace = uipallet.Font
				indicator.Parent = indicatorholder
				addCorner(indicator, UDim.new(0, 5))
				local text = indicator:Clone()
				text.Position = UDim2.new()
				text.Size = UDim2.fromScale(1, 1)
				text.BackgroundTransparency = 1
				text.Name = 'Text'
				text.AnchorPoint = Vector2.new()
				text.TextSize = 12
				text.TextTransparency = 0
				text.Parent = indicator
				table.insert(moduleapi.Tags, indicator)
				indicator.Visible = tag ~= 'MATCHED'
			end
		end)
		local gradient = Instance.new('UIGradient')
		gradient.Rotation = 90
		gradient.Enabled = false
		gradient.Parent = modulebutton
		local modulechildren = Instance.new('Frame')
		local bind = Instance.new('TextButton')
		addTooltip(modulebutton, modulesettings.Tooltip)
		addHoverFX(modulebutton)
		addTooltip(bind, 'Click to bind')
		bind.Name = 'Bind'
		bind.Size = UDim2.fromOffset(20, 21)
		bind.Position = UDim2.new(1, -36, 0, 9)
		bind.AnchorPoint = Vector2.new(1, 0)
		bind.BackgroundColor3 = Color3.new(1, 1, 1)
		bind.BackgroundTransparency = 0.92
		bind.BorderSizePixel = 0
		bind.AutoButtonColor = false
		bind.Visible = false
		bind.Text = ''
		addCorner(bind, UDim.new(0, 4))
		-- Favourite visuals: one gold accent shared by the star chip, the
		-- border trim and the pulse ring.
		local favGold = Color3.fromRGB(255, 200, 60)
		local favstroke = Instance.new('UIStroke')
		favstroke.Name = 'FavouriteBorder'
		favstroke.Color = favGold
		favstroke.Thickness = 1.6
		favstroke.Transparency = 1
		favstroke.LineJoinMode = Enum.LineJoinMode.Round
		favstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		favstroke.Enabled = false
		favstroke.Parent = modulebutton
		-- Vertical sheen so the border reads as gold trim rather than a hard box.
		local favsheen = Instance.new('UIGradient')
		favsheen.Rotation = 90
		favsheen.Color = ColorSequence.new(favGold, Color3.fromRGB(214, 148, 34))
		favsheen.Parent = favstroke
		local favourite = Instance.new('TextButton')
		favourite.Name = 'Favourite'
		favourite.Size = UDim2.fromOffset(20, 20)
		-- Anchor to the row's vertical centre so the star chip sits dead-centre in
		-- the 40px row regardless of row height, instead of a hand-tuned offset.
		favourite.Position = UDim2.new(1, -60, 0.5, 0)
		favourite.AnchorPoint = Vector2.new(1, 0.5)
		favourite.TextYAlignment = Enum.TextYAlignment.Center
		favourite.TextXAlignment = Enum.TextXAlignment.Center
		favourite.BackgroundColor3 = Color3.new(1, 1, 1)
		favourite.BackgroundTransparency = 0.92
		favourite.BorderSizePixel = 0
		favourite.AutoButtonColor = false
		favourite.Visible = false
		favourite.Text = '★'
		favourite.TextColor3 = color.Dark(uipallet.Text, 0.43)
		favourite.TextSize = 13
		favourite.FontFace = uipallet.Font
		favourite.Parent = modulebutton
		addCorner(favourite, UDim.new(1, 0))
		addTooltip(favourite, 'Favourite (pins to top + adds to the Favourites tab)')
		local favscale = Instance.new('UIScale')
		favscale.Parent = favourite
		-- instant skips the colour tween; used on bulk paths (config loads)
		-- where animating every module at once would stutter.
		local function updateFavouriteVisual(instant)
			local starcolor = moduleapi.Favourited and favGold
				or ((hovered or settingsOpen) and color.Dark(uipallet.Text, 0.16) or color.Dark(uipallet.Text, 0.43))
			favourite.Visible = moduleapi.Favourited or hovered or settingsOpen
			if instant then
				favourite.TextColor3 = starcolor
				favstroke.Enabled = moduleapi.Favourited
				favstroke.Transparency = moduleapi.Favourited and 0.1 or 1
			else
				tween:Tween(favourite, uipallet.Tween, {TextColor3 = starcolor})
			end
		end
		moduleapi.UpdateFavouriteVisual = updateFavouriteVisual

		-- All the one-shot flourishes for a state change, kept out of SetFavourite
		-- so the state path stays readable. Only ever runs on user-driven toggles
		-- (silent = false); bulk config loads skip it entirely.
		local function playFavouriteBurst(state)
			-- Border trim fades with the state instead of snapping.
			if state then
				favstroke.Enabled = true
				favstroke.Transparency = 1
				tweenService:Create(favstroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0.1
				}):Play()
			else
				local fade = tweenService:Create(favstroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1
				})
				fade.Completed:Once(function()
					if not moduleapi.Favourited then
						favstroke.Enabled = false
					end
				end)
				fade:Play()
			end
			-- Star pop in both directions: shrink-in when favouriting,
			-- overshoot-out when unfavouriting.
			favscale.Scale = state and 0.6 or 1.2
			tweenService:Create(favscale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1
			}):Play()
			-- Ring pulse on BOTH transitions: gold as it swells outward when
			-- favouriting, a cool silver as it settles back into the alphabetical
			-- list when unfavouriting. Same swelling-ring motion either way so the
			-- move draws the eye to the module's new home.
			local oldpulse = modulebutton:FindFirstChild('FavouritePulse')
			if oldpulse then
				oldpulse:Destroy()
			end
			local pulse = Instance.new('UIStroke')
			pulse.Name = 'FavouritePulse'
			pulse.Color = state and favGold or Color3.fromRGB(170, 178, 194)
			pulse.Thickness = 1
			pulse.Transparency = 0.25
			pulse.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			pulse.Parent = modulebutton
			tweenService:Create(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				Thickness = state and 7 or 5
			}):Play()
			task.delay(0.55, function()
				pulse:Destroy()
			end)
		end

		-- Moves the category so the module's new home is on screen after a
		-- favourite/unfavourite: favouriting pins it to the very top so we scroll
		-- there, unfavouriting drops it back to its alphabetical slot so we centre
		-- on that. Deferred a frame so SortModules' new LayoutOrders have laid out.
		local function scrollToFavouriteHome(state)
			task.defer(function()
				local frame = modulebutton.Parent
				if not frame or not frame:IsA('ScrollingFrame') then return end
				if categoryapi.Expanded == false then
					categoryapi:Expand()
				end
				if state then
					if uipallet.Tween.Time <= 0 then
						frame.CanvasPosition = Vector2.new(0, 0)
					else
						tweenService:Create(frame, settingsTweenInfo(), {
							CanvasPosition = Vector2.new(0, 0)
						}):Play()
					end
				else
					-- Centre on the alphabetical slot; the ring pulse is the arrival
					-- cue so skip the extra flash.
					mainapi:ScrollToModule(moduleapi, {Flash = false})
				end
			end)
		end

		function moduleapi:SetFavourite(state, silent)
			state = state and true or false
			-- Early-out when nothing changes: config loads call SetFavourite on
			-- every module, and re-sorting all categories for each unchanged
			-- module made profile switching stutter badly.
			if self.Favourited == state then
				updateFavouriteVisual(true)
				return
			end
			self.Favourited = state
			updateFavouriteVisual(silent)
			mainapi:SortModules()
			-- Hand the ordered favourites list + the Favourites tab to the central
			-- controller; it owns everything shared between modules.
			if mainapi.Favourites then
				if state then
					mainapi.Favourites:Add(self)
				else
					mainapi.Favourites:Remove(self.Name)
				end
			end
			if mainapi.RefreshFavourites then
				task.defer(mainapi.RefreshFavourites)
			end
			if not silent then
				playFavouriteBurst(state)
				scrollToFavouriteHome(state)
			end
		end
		favourite.MouseEnter:Connect(function()
			-- tweenstwo so this doesn't cancel the star colour tween, which is
			-- keyed on the same object in the primary tween table.
			tween:Tween(favourite, uipallet.Tween, {BackgroundTransparency = 0.8}, tween.tweenstwo)
			tweenService:Create(favscale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.15
			}):Play()
		end)
		favourite.MouseLeave:Connect(function()
			tween:Tween(favourite, uipallet.Tween, {BackgroundTransparency = 0.92}, tween.tweenstwo)
			tweenService:Create(favscale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1
			}):Play()
		end)
		favourite.MouseButton1Click:Connect(function()
			moduleapi:SetFavourite(not moduleapi.Favourited)
		end)
		local bindicon = Instance.new('ImageLabel')
		bindicon.Name = 'Icon'
		bindicon.Size = UDim2.fromOffset(12, 12)
		bindicon.Position = UDim2.new(0.5, -6, 0, 5)
		bindicon.BackgroundTransparency = 1
		bindicon.Image = getcustomasset('aetherv2/assets/new/bind.png')
		bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		bindicon.Parent = bind
		local bindtext = Instance.new('TextLabel')
		bindtext.Size = UDim2.fromScale(1, 1)
		bindtext.Position = UDim2.fromOffset(0, 1)
		bindtext.BackgroundTransparency = 1
		bindtext.Visible = false
		bindtext.Text = ''
		bindtext.TextColor3 = color.Dark(uipallet.Text, 0.43)
		bindtext.TextSize = 12
		bindtext.FontFace = uipallet.Font
		bindtext.Parent = bind
		local bindcover = Instance.new('ImageLabel')
		bindcover.Name = 'Cover'
		bindcover.Size = UDim2.fromOffset(154, 40)
		bindcover.BackgroundTransparency = 1
		bindcover.Visible = false
		bindcover.Image = getcustomasset('aetherv2/assets/new/bindbkg.png')
		bindcover.ScaleType = Enum.ScaleType.Slice
		bindcover.SliceCenter = Rect.new(0, 0, 141, 40)
		bindcover.Parent = modulebutton
		local bindcovertext = Instance.new('TextLabel')
		bindcovertext.Name = 'Text'
		bindcovertext.Size = UDim2.new(1, -10, 1, -3)
		bindcovertext.BackgroundTransparency = 1
		bindcovertext.Text = 'PRESS A KEY TO BIND'
		bindcovertext.TextColor3 = uipallet.Text
		bindcovertext.TextSize = 11
		bindcovertext.FontFace = uipallet.Font
		bindcovertext.Parent = bindcover
		bind.Parent = modulebutton
		local dotsbutton = Instance.new('TextButton')
		dotsbutton.Name = 'Dots'
		dotsbutton.Size = UDim2.fromOffset(25, 40)
		dotsbutton.Position = UDim2.new(1, -25, 0, 0)
		dotsbutton.BackgroundTransparency = 1
		dotsbutton.Text = ''
		dotsbutton.Parent = modulebutton
		addTooltip(dotsbutton, 'Settings (right-click the module too)')
		local dots = Instance.new('ImageLabel')
		dots.Name = 'Dots'
		dots.Size = UDim2.fromOffset(3, 16)
		dots.Position = UDim2.fromOffset(4, 12)
		dots.BackgroundTransparency = 1
		dots.Image = getcustomasset('aetherv2/assets/new/dots.png')
		dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
		dots.Parent = dotsbutton
		modulechildren.Name = modulesettings.Name..'Children'
		modulechildren.Size = UDim2.new(1, 0, 0, 0)
		modulechildren.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		modulechildren.BorderSizePixel = 0
		modulechildren.Visible = false
		-- Clip so the ease-in-out open/close animation (tweening the panel height
		-- from 0) reveals rows cleanly instead of overflowing during the tween.
		modulechildren.ClipsDescendants = true
		modulechildren.Parent = children
		moduleapi.OptionsChildren = modulechildren
		moduleapi.Children = modulechildren
		if modulesettings.Size then
			local hudchildren = Instance.new('Frame')
			hudchildren.Name = modulesettings.Name..'HUD'
			hudchildren.Size = modulesettings.Size
			hudchildren.BackgroundTransparency = 1
			hudchildren.Visible = false
			hudchildren.Parent = scaledgui
			makeDraggable(hudchildren)
			moduleapi.Children = hudchildren
		end
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Parent = modulechildren
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.new(0, 0, 1, -1)
		divider.BackgroundColor3 = Color3.new(0.19, 0.19, 0.19)
		divider.BackgroundTransparency = 0.52
		divider.BorderSizePixel = 0
		divider.Visible = false
		divider.Parent = modulebutton
		modulesettings.Function = modulesettings.Function or function() end
		addMaid(moduleapi)

		function moduleapi:SetBind(tab, mouse)
			if tab.Mobile then
				createMobileButton(moduleapi, Vector2.new(tab.X, tab.Y))
				return
			end

			self.Bind = table.clone(tab)
			if mouse then
				bindcovertext.Text = #tab <= 0 and 'BIND REMOVED' or 'BOUND TO'
				bindcover.Size = UDim2.fromOffset(getfontsize(bindcovertext.Text, bindcovertext.TextSize).X + 20, 40)
				task.delay(1, function()
					bindcover.Visible = false
				end)
			end

			if #tab <= 0 then
				bindtext.Visible = false
				bindicon.Visible = true
				bind.Size = UDim2.fromOffset(20, 21)
			else
				bind.Visible = true
				bindtext.Visible = true
				bindicon.Visible = false
				bindtext.Text = table.concat(tab, ' + '):upper()
				bind.Size = UDim2.fromOffset(math.max(getfontsize(bindtext.Text, bindtext.TextSize, bindtext.Font).X + 10, 20), 21)
			end
		end

		local function updateModuleButtonVisual(animate)
			local rainbow = mainapi.GUIColor.Rainbow and mainapi.RainbowMode.Value ~= 'Retro'
			gradient.Enabled = false

			local bgColor, txtColor
			if moduleapi.Enabled then
				gradient.Enabled = rainbow and mainapi.RainbowMode.Value == 'Gradient'
				if gradient.Enabled then
					-- Gradient rainbow keeps the classic full-row fill.
					bgColor = Color3.new(1, 1, 1)
					txtColor = Color3.new(0.19, 0.19, 0.19)
					gradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(mainapi:Color((mainapi.GUIColor.Hue - (moduleapi.Index * 0.025)) % 1))),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(mainapi:Color((mainapi.GUIColor.Hue - ((moduleapi.Index + 1) * 0.025)) % 1)))
					})
					accentbar.Visible = false
					dots.ImageColor3 = txtColor
					bindicon.ImageColor3 = txtColor
					bindtext.TextColor3 = txtColor
				else
					-- v6 list-item style: dark row + bright accent bar + accent label
					-- (replaces the old full-accent highlight).
					local h, s, v = mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value
					if rainbow then
						h, s, v = mainapi:Color((mainapi.GUIColor.Hue - (moduleapi.Index * 0.025)) % 1)
					end
					-- Force a readable value/sat so even a dark accent stands out on the row.
					local accent = Color3.fromHSV(h, math.clamp(s, 0, 0.9), math.max(v, 0.82))
					bgColor = color.Light(uipallet.Main, 0.05)
					txtColor = accent
					accentbar.BackgroundColor3 = accent
					accentbar.Visible = true
					if animate then
						accentbar.BackgroundTransparency = 1
						tween:Tween(accentbar, uipallet.Tween, {BackgroundTransparency = 0})
					else
						accentbar.BackgroundTransparency = 0
					end
					dots.ImageColor3 = accent
					bindicon.ImageColor3 = accent
					bindtext.TextColor3 = accent
				end
			else
				txtColor = (hovered or settingsOpen) and uipallet.Text or color.Dark(uipallet.Text, 0.16)
				bgColor = (hovered or settingsOpen) and color.Light(uipallet.Main, 0.02) or uipallet.Main
				dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
				bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				bindtext.TextColor3 = color.Dark(uipallet.Text, 0.43)
				accentbar.Visible = false
			end

			-- Fade the toggle colour between on/off on genuine state changes so
			-- modules light up smoothly. Hover refreshes and the per-frame rainbow
			-- update stay instant (animating a colour that changes every frame would
			-- smear it), and a gradient fill can't be tweened, so set those directly.
			if animate and not rainbow and not gradient.Enabled then
				tween:Tween(modulebutton, uipallet.Tween, {BackgroundColor3 = bgColor, TextColor3 = txtColor}, tween.tweenstwo)
			else
				modulebutton.BackgroundColor3 = bgColor
				modulebutton.TextColor3 = txtColor
			end
		end

		function moduleapi:Toggle(multiple)
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			self.Enabled = not self.Enabled
			divider.Visible = self.Enabled
			if modulesettings.Size and self.Children then
				self.Children.Visible = self.Enabled
			end
			-- Animate single user toggles; bulk paths (config loads / "disable all")
			-- pass multiple = true and stay instant so they don't stutter.
			updateModuleButtonVisual(not multiple)
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

		-- Capture, per logical option, every frame it adds to the settings panel.
		-- Snapshotting modulechildren before/after each Create call is bullet-proof
		-- regardless of a component's internals (ColorSlider / TwoSlider / Targets
		-- each spawn several sibling frames), which the sub-category builder needs
		-- so it can re-home a whole option - not just its main row - into a group.
		local optionRecords = {}
		moduleapi.OptionRecords = optionRecords
		for i, v in components do
			moduleapi['Create'..i] = function(_, optionsettings)
				local before = {}
				for _, ch in modulechildren:GetChildren() do
					before[ch] = true
				end
				local result = v(optionsettings, modulechildren, moduleapi)
				local frames = {}
				for _, ch in modulechildren:GetChildren() do
					if not before[ch] and ch:IsA('GuiObject') then
						table.insert(frames, ch)
					end
				end
				if #frames > 0 then
					table.insert(optionRecords, {
						name = (type(optionsettings) == 'table' and optionsettings.Name) or i,
						frames = frames
					})
				end
				return result
			end
		end

		-- ===================================================================
		-- Reworked settings: ease-in-out open/close + collapsible sub-categories
		-- ===================================================================
		local subGroups = {}
		local subBuilt = false
		local settingsAnimating = false
		moduleapi.SubGroups = subGroups

		-- Unscaled height of everything currently laid out in the settings panel.
		local function panelContentHeight()
			return windowlist.AbsoluteContentSize.Y / scale.Scale
		end

		-- Buckets an option by the module's explicit layout, else by keyword.
		local explicitLayout = settingSubcategories[moduleapi.Name]
		local function groupForName(name)
			if explicitLayout then
				local lower = (name or ''):lower()
				for _, g in explicitLayout do
					for _, entry in g[2] do
						if entry:lower() == lower then
							return g[1]
						end
					end
				end
				return 'General'
			end
			return classifySetting(name)
		end

		-- Builds the collapsible sub-category UI once, the first time the panel
		-- opens. Bails on modules that wouldn't benefit (too few settings, or only
		-- one resulting group) so short panels stay flat - sub-categories should be
		-- "useful rather than a useless click".
		local function buildSubCategories()
			if subBuilt then return end
			subBuilt = true
			if #optionRecords < (explicitLayout and 2 or subAutoThreshold) then return end

			local order, bucket = {}, {}
			local function ensure(title)
				if not bucket[title] then
					bucket[title] = {}
					table.insert(order, title)
				end
				return bucket[title]
			end
			for _, rec in optionRecords do
				table.insert(ensure(groupForName(rec.name)), rec)
			end

			-- Render order: leading General, then the layout / keyword order.
			local finalOrder = {}
			if bucket['General'] then
				table.insert(finalOrder, 'General')
			end
			if explicitLayout then
				for _, g in explicitLayout do
					if bucket[g[1]] and g[1] ~= 'General' then
						table.insert(finalOrder, g[1])
					end
				end
			else
				for _, g in subKeywordGroups do
					if bucket[g[1]] and g[1] ~= 'General' then
						table.insert(finalOrder, g[1])
					end
				end
			end
			for _, title in order do
				if not table.find(finalOrder, title) then
					table.insert(finalOrder, title)
				end
			end

			if #finalOrder < 2 then return end

			local layoutIndex = 0
			for _, title in finalOrder do
				local records = bucket[title]
				layoutIndex += 1
				local headerOrder = layoutIndex * 1000

				local header = Instance.new('TextButton')
				header.Name = title..'SubHeader'
				header.Size = UDim2.new(1, 0, 0, 26)
				header.BackgroundColor3 = color.Dark(uipallet.Main, 0.03)
				header.BorderSizePixel = 0
				header.AutoButtonColor = false
				header.Text = ''
				header.LayoutOrder = headerOrder
				header.Parent = modulechildren
				local chevron = Instance.new('ImageLabel')
				chevron.Name = 'Chevron'
				chevron.Size = UDim2.fromOffset(4, 8)
				chevron.Position = UDim2.fromOffset(14, 9)
				chevron.BackgroundTransparency = 1
				chevron.Image = getcustomasset('aetherv2/assets/new/expandright.png')
				chevron.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				chevron.Parent = header
				local label = Instance.new('TextLabel')
				label.Name = 'Label'
				label.Size = UDim2.new(1, -60, 1, 0)
				label.Position = UDim2.fromOffset(28, 0)
				label.BackgroundTransparency = 1
				label.Text = title:upper()
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.TextColor3 = color.Dark(uipallet.Text, 0.36)
				label.TextSize = 10
				label.FontFace = uipallet.FontSemiBold
				label.Parent = header
				-- Count badge: how many settings live under this header.
				local count = Instance.new('TextLabel')
				count.Name = 'Count'
				count.Size = UDim2.fromOffset(20, 14)
				count.Position = UDim2.new(1, -30, 0.5, -7)
				count.BackgroundColor3 = color.Light(uipallet.Main, 0.06)
				count.Text = tostring(#records)
				count.TextColor3 = color.Dark(uipallet.Text, 0.4)
				count.TextSize = 10
				count.FontFace = uipallet.Font
				count.Parent = header
				addCorner(count, UDim.new(0, 4))

				local container = Instance.new('Frame')
				container.Name = title..'SubGroup'
				container.Size = UDim2.new(1, 0, 0, 0)
				container.BackgroundTransparency = 1
				container.BorderSizePixel = 0
				container.ClipsDescendants = true
				container.LayoutOrder = headerOrder + 1
				container.Parent = modulechildren
				local inner = Instance.new('Frame')
				inner.Name = 'Inner'
				inner.Size = UDim2.new(1, 0, 0, 0)
				inner.AutomaticSize = Enum.AutomaticSize.Y
				inner.BackgroundTransparency = 1
				inner.BorderSizePixel = 0
				inner.Parent = container
				local innerlist = Instance.new('UIListLayout')
				innerlist.SortOrder = Enum.SortOrder.LayoutOrder
				innerlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
				innerlist.Parent = inner

				-- Re-home each option's captured frames into this group's container,
				-- preserving their creation order. Guard against any frame a module
				-- may have since destroyed (parenting a destroyed instance errors).
				for ri, rec in ipairs(records) do
					for fi, frame in ipairs(rec.frames) do
						if frame and frame.Parent then
							frame.LayoutOrder = ri * 100 + fi
							frame.Parent = inner
						end
					end
				end

				local groupApi = {Title = title, Records = records, Header = header}
				local open = subGroupMemory[moduleapi.Name..'|'..title] or false

				local function groupHeight()
					return innerlist.AbsoluteContentSize.Y / scale.Scale
				end
				function groupApi.SetOpen(state, animate, noRemember)
					open = state and true or false
					groupApi.Open = open
					-- The live filter drives groups open/closed transiently; it passes
					-- noRemember so it doesn't clobber the user's remembered state.
					if not noRemember then
						subGroupMemory[moduleapi.Name..'|'..title] = open
					end
					tweenService:Create(chevron, settingsTweenInfo(), {
						Rotation = open and 90 or 0
					}):Play()
					tween:Tween(label, uipallet.Tween, {
						TextColor3 = open and color.Dark(uipallet.Text, 0.16) or color.Dark(uipallet.Text, 0.36)
					})
					local target = open and groupHeight() or 0
					if animate and uipallet.Tween.Time > 0 and container.Visible then
						tween:Tween(container, settingsTweenInfo(), {Size = UDim2.new(1, 0, 0, target)})
					else
						container.Size = UDim2.new(1, 0, 0, target)
					end
				end

				-- Keep an open group's height synced as options reveal / hide inside
				-- it (e.g. a colour picker expanding its sliders).
				innerlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					if open and not tween.tweens[container] then
						container.Size = UDim2.new(1, 0, 0, groupHeight())
					end
				end)
				header.MouseEnter:Connect(function()
					tween:Tween(header, uipallet.Tween, {BackgroundColor3 = color.Light(uipallet.Main, 0.02)})
				end)
				header.MouseLeave:Connect(function()
					tween:Tween(header, uipallet.Tween, {BackgroundColor3 = color.Dark(uipallet.Main, 0.03)})
				end)
				header.MouseButton1Click:Connect(function()
					groupApi.SetOpen(not open, true)
				end)
				-- Right-click a header to expand / collapse ALL groups at once.
				header.MouseButton2Click:Connect(function()
					local anyClosed = false
					for _, g in subGroups do
						if not g.Open then
							anyClosed = true
							break
						end
					end
					for _, g in subGroups do
						g.SetOpen(anyClosed, true)
					end
				end)

				groupApi.Container = container
				groupApi.SetVisible = function(state)
					header.Visible = state
					container.Visible = state
				end
				groupApi.SetOpen(open, false)
				table.insert(subGroups, groupApi)
			end

			-- ---- Per-module settings filter (major) --------------------------------
			-- On heavy panels, a small filter box that live-narrows the visible
			-- sub-categories: groups whose title or any setting name matches the
			-- query stay (and auto-expand); the rest hide. Only toggles the header /
			-- container visibility it owns, never an option's own Visible, so it
			-- can't fight a module's conditional show/hide logic.
			if #optionRecords >= 12 then
				local filter = Instance.new('TextBox')
				filter.Name = 'SettingsFilter'
				filter.Size = UDim2.new(1, 0, 0, 28)
				filter.LayoutOrder = -1000
				filter.BackgroundColor3 = color.Dark(uipallet.Main, 0.04)
				filter.BorderSizePixel = 0
				filter.Text = ''
				filter.PlaceholderText = 'Filter settings...'
				filter.PlaceholderColor3 = color.Dark(uipallet.Text, 0.5)
				filter.TextXAlignment = Enum.TextXAlignment.Left
				filter.TextColor3 = uipallet.Text
				filter.TextSize = 12
				filter.FontFace = uipallet.Font
				filter.ClearTextOnFocus = false
				filter.Parent = modulechildren
				local ficon = Instance.new('ImageLabel')
				ficon.Size = UDim2.fromOffset(12, 12)
				ficon.Position = UDim2.new(1, -22, 0.5, -6)
				ficon.BackgroundTransparency = 1
				ficon.Image = getcustomasset('aetherv2/assets/new/search.png')
				ficon.ImageColor3 = color.Light(uipallet.Main, 0.37)
				ficon.Parent = filter
				-- Pad the typed text so it clears the icon and left edge.
				local fpad = Instance.new('UIPadding')
				fpad.PaddingLeft = UDim.new(0, 10)
				fpad.PaddingRight = UDim.new(0, 26)
				fpad.Parent = filter
				filter:GetPropertyChangedSignal('Text'):Connect(function()
					local query = filter.Text:lower():gsub('^%s+', '')
					if query == '' then
						-- Restore every group to its remembered open state.
						for _, g in subGroups do
							g.SetVisible(true)
							g.SetOpen(subGroupMemory[moduleapi.Name..'|'..g.Title] or false, false, true)
						end
						return
					end
					for _, g in subGroups do
						local match = g.Title:lower():find(query, 1, true) ~= nil
						if not match then
							for _, rec in g.Records do
								if rec.name and rec.name:lower():find(query, 1, true) then
									match = true
									break
								end
							end
						end
						g.SetVisible(match)
						g.SetOpen(match, false, true)
					end
				end)
			end
		end
		moduleapi.BuildSubCategories = buildSubCategories

		-- Ease-in-out open/close of the whole settings panel. Tweens the panel
		-- height from/to 0; the category window height follows because the panel is
		-- a laid-out child, giving one smooth cascading animation.
		local function animatePanel(openState)
			settingsAnimating = true
			if openState then
				modulechildren.Visible = true
				local target = panelContentHeight()
				if uipallet.Tween.Time <= 0 then
					modulechildren.Size = UDim2.new(1, 0, 0, target)
					settingsAnimating = false
				else
					modulechildren.Size = UDim2.new(1, 0, 0, 0)
					tween:Tween(modulechildren, settingsTweenInfo(), {Size = UDim2.new(1, 0, 0, target)})
					task.delay(uipallet.Tween.Time + 0.02, function()
						settingsAnimating = false
						if settingsOpen then
							modulechildren.Size = UDim2.new(1, 0, 0, panelContentHeight())
						end
					end)
				end
			else
				if uipallet.Tween.Time <= 0 then
					modulechildren.Size = UDim2.new(1, 0, 0, 0)
					modulechildren.Visible = false
					settingsAnimating = false
				else
					tween:Tween(modulechildren, settingsTweenInfo(), {Size = UDim2.new(1, 0, 0, 0)})
					task.delay(uipallet.Tween.Time + 0.02, function()
						settingsAnimating = false
						if not settingsOpen then
							modulechildren.Visible = false
							modulechildren.Size = UDim2.new(1, 0, 0, 0)
						end
					end)
				end
			end
		end

		function moduleapi:SetSettingsOpen(state)
			state = state and true or false
			if state == settingsOpen then return end
			settingsOpen = state
			self.SettingsOpen = state
			if state then
				if not subBuilt then
					buildSubCategories()
					modulechildren.Visible = true
					settingsAnimating = true
					-- Let the freshly reparented sub-category layout produce a real
					-- content height before animating, so the open tween targets the
					-- right size. Only the very first open pays this (bounded) wait;
					-- later opens measure instantly.
					task.spawn(function()
						local tries = 0
						while windowlist.AbsoluteContentSize.Y <= 0 and tries < 4 do
							task.wait()
							tries += 1
						end
						if settingsOpen then
							animatePanel(true)
						else
							modulechildren.Visible = false
							settingsAnimating = false
						end
					end)
				else
					animatePanel(true)
				end
			else
				animatePanel(false)
			end
			updateModuleButtonVisual()
			updateFavouriteVisual()
			bind.Visible = #moduleapi.Bind > 0 or hovered or settingsOpen
		end
		function moduleapi:ToggleSettings()
			self:SetSettingsOpen(not settingsOpen)
		end

		bind.MouseEnter:Connect(function()
			bindtext.Visible = false
			bindicon.Visible = not bindtext.Visible
			bindicon.Image = getcustomasset('aetherv2/assets/new/edit.png')
			if not moduleapi.Enabled then bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.16) end
		end)
		bind.MouseLeave:Connect(function()
			bindtext.Visible = #moduleapi.Bind > 0
			bindicon.Visible = not bindtext.Visible
			bindicon.Image = getcustomasset('aetherv2/assets/new/bind.png')
			if not moduleapi.Enabled then
				bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
			end
		end)
		bind.MouseButton1Click:Connect(function()
			bindcovertext.Text = 'PRESS A KEY TO BIND'
			bindcover.Size = UDim2.fromOffset(getfontsize(bindcovertext.Text, bindcovertext.TextSize).X + 20, 40)
			bindcover.Visible = true
			mainapi.Binding = moduleapi
		end)
		dotsbutton.MouseEnter:Connect(function()
			if not moduleapi.Enabled then
				dots.ImageColor3 = uipallet.Text
			end
		end)
		dotsbutton.MouseLeave:Connect(function()
			if not moduleapi.Enabled then
				dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
			end
		end)
		dotsbutton.MouseButton1Click:Connect(function()
			moduleapi:ToggleSettings()
		end)
		dotsbutton.MouseButton2Click:Connect(function()
			moduleapi:ToggleSettings()
		end)
		modulebutton.MouseEnter:Connect(function()
			hovered = true
			updateModuleButtonVisual()
			updateFavouriteVisual()
			bind.Visible = #moduleapi.Bind > 0 or hovered or settingsOpen
		end)
		modulebutton.MouseLeave:Connect(function()
			hovered = false
			updateModuleButtonVisual()
			updateFavouriteVisual()
			bind.Visible = #moduleapi.Bind > 0 or hovered or settingsOpen
		end)
		modulebutton.MouseButton1Click:Connect(function()
			moduleapi:Toggle()
		end)
		modulebutton.MouseButton2Click:Connect(function()
			moduleapi:ToggleSettings()
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
			-- Only re-drive the panel height while it's open and not mid-animation:
			-- this lets a sub-category collapsing/expanding (or a colour picker
			-- revealing sliders) grow/shrink the panel live, without fighting the
			-- ease-in-out open/close tween or resizing a hidden panel.
			if settingsOpen and not settingsAnimating and not tween.tweens[modulechildren] then
				modulechildren.Size = UDim2.new(1, 0, 0, windowlist.AbsoluteContentSize.Y / scale.Scale)
			end
		end)

		moduleapi.Object = modulebutton
		mainapi.Modules[modulesettings.Name] = moduleapi

		mainapi:SortModules()

		return moduleapi
	end

	function categoryapi:Expand()
		if categorysettings.Profiles then
			refreshConfigProfiles()
			self:ChangeValue()
		end
		self.Expanded = not self.Expanded
		local targetHeight = self.Expanded and math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601) or 41
		-- Animate the category open/closed instead of snapping. The children frame
		-- is a clipping ScrollingFrame pinned to the window height, so tweening the
		-- window height alone reveals/hides the rows cleanly. Keep the rows mounted
		-- for the whole tween and only unmount them once a collapse has finished.
		if self.Expanded then
			children.Visible = true
		else
			task.delay(uipallet.Tween.Time, function()
				if not self.Expanded then
					children.Visible = false
				end
			end)
		end
		tween:Tween(window, uipallet.Tween, {Size = UDim2.fromOffset(220, targetHeight)})
		tweenService:Create(arrow, uipallet.Tween, {Rotation = self.Expanded and 0 or 180}):Play()
		divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
	end

	arrowbutton.MouseButton1Click:Connect(function()
		categoryapi:Expand()
	end)
	arrowbutton.MouseButton2Click:Connect(function()
		categoryapi:Expand()
	end)
	arrowbutton.MouseEnter:Connect(function()
		arrow.ImageColor3 = Color3.fromRGB(220, 220, 220)
	end)
	arrowbutton.MouseLeave:Connect(function()
		arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
	end)
	children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
	end)
	window.InputBegan:Connect(function(inputObj)
		if inputObj.Position.Y < window.AbsolutePosition.Y + 41 and inputObj.UserInputType == Enum.UserInputType.MouseButton2 then
			categoryapi:Expand()
		end
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		if categoryapi.Expanded then
			window.Size = UDim2.fromOffset(220, math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601))
		end
	end)

	categoryapi.Button = self.Categories.Main:CreateButton({
		Name = categorysettings.Name,
		Icon = categorysettings.Icon,
		Size = categorysettings.Size,
		Window = window
	})

	categoryapi.Object = window
	-- Remembered so a saved position that would stack this window on top of another one (or park
	-- it off-screen) can be thrown away on load in favour of this category's own lattice slot.
	categoryapi.DefaultPosition = UDim2.fromOffset(defaultX, defaultY)
	self.Categories[categorysettings.Name] = categoryapi

	return categoryapi
end

function mainapi:CreateOverlay(categorysettings)
	local window
	local categoryapi
	categoryapi = {
		Type = 'Overlay',
		Expanded = false,
		Button = self.Overlays:CreateToggle({
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
			Icon = categorysettings.Icon,
			Size = categorysettings.Size,
			Position = categorysettings.Position
		}),
		Pinned = false,
		Options = {}
	}

	window = Instance.new('TextButton')
	window.Name = categorysettings.Name..'Overlay'
	window.Size = UDim2.fromOffset(categorysettings.CategorySize or 220, 41)
	window.Position = UDim2.fromOffset(240, 46)
	window.BackgroundColor3 = uipallet.Main
	window.AutoButtonColor = false
	window.Visible = false
	window.Text = ''
	window.Parent = scaledgui
	local blur = addBlur(window)
	addCorner(window)
	addWindowStroke(window)
	makeDraggable(window)
	local icon = Instance.new('ImageLabel')
	icon.Name = 'Icon'
	icon.Size = categorysettings.Size
	icon.Position = UDim2.fromOffset(12, (icon.Size.X.Offset > 14 and 14 or 13))
	icon.BackgroundTransparency = 1
	icon.Image = categorysettings.Icon
	icon.ImageColor3 = uipallet.Text
	icon.Parent = window
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.new(1, -32, 0, 41)
	title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 0)
	title.BackgroundTransparency = 1
	title.Text = categorysettings.Name
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = uipallet.Text
	title.TextSize = 13
	title.FontFace = uipallet.Font
	title.Parent = window
	local pin = Instance.new('ImageButton')
	pin.Name = 'Pin'
	pin.Size = UDim2.fromOffset(16, 16)
	pin.Position = UDim2.new(1, -47, 0, 12)
	pin.BackgroundTransparency = 1
	pin.AutoButtonColor = false
	pin.Image = getcustomasset('aetherv2/assets/new/pin.png')
	pin.ImageColor3 = color.Dark(uipallet.Text, 0.43)
	pin.Parent = window
	local dotsbutton = Instance.new('TextButton')
	dotsbutton.Name = 'Dots'
	dotsbutton.Size = UDim2.fromOffset(17, 40)
	dotsbutton.Position = UDim2.new(1, -17, 0, 0)
	dotsbutton.BackgroundTransparency = 1
	dotsbutton.Text = ''
	dotsbutton.Parent = window
	local dots = Instance.new('ImageLabel')
	dots.Name = 'Dots'
	dots.Size = UDim2.fromOffset(3, 16)
	dots.Position = UDim2.fromOffset(4, 12)
	dots.BackgroundTransparency = 1
	dots.Image = getcustomasset('aetherv2/assets/new/dots.png')
	dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
	dots.Parent = dotsbutton
	local customchildren = Instance.new('Frame')
	customchildren.Name = 'CustomChildren'
	customchildren.Size = UDim2.new(1, 0, 0, 200)
	customchildren.Position = UDim2.fromScale(0, 1)
	customchildren.BackgroundTransparency = 1
	customchildren.Parent = window
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, -41)
	children.Position = UDim2.fromOffset(0, 37)
	children.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
	children.BorderSizePixel = 0
	children.Visible = false
	children.ScrollBarThickness = 2
	children.ScrollBarImageTransparency = 0.75
	children.CanvasSize = UDim2.new()
	children.Parent = window
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	windowlist.Parent = children
	addMaid(categoryapi)

	function categoryapi:Expand(check)
		if check and not blur.Visible then return end
		self.Expanded = not self.Expanded
		children.Visible = self.Expanded
		dots.ImageColor3 = self.Expanded and uipallet.Text or color.Light(uipallet.Main, 0.37)
		if self.Expanded then
			window.Size = UDim2.fromOffset(window.Size.X.Offset, math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601))
		else
			window.Size = UDim2.fromOffset(window.Size.X.Offset, 41)
		end
	end

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
			window.Size = UDim2.fromOffset(window.Size.X.Offset, 41)
			addGlass(window)
			blur.Visible = true
			icon.Visible = true
			title.Visible = true
			pin.Visible = true
			dotsbutton.Visible = true
		else
			window.Size = UDim2.fromOffset(window.Size.X.Offset, 0)
			window.BackgroundTransparency = 1
			blur.Visible = false
			icon.Visible = false
			title.Visible = false
			pin.Visible = false
			dotsbutton.Visible = false
		end
	end

	for i, v in components do
		categoryapi['Create'..i] = function(self, optionsettings)
			return v(optionsettings, children, categoryapi)
		end
	end

	dotsbutton.MouseEnter:Connect(function()
		if not children.Visible then
			dots.ImageColor3 = uipallet.Text
		end
	end)
	dotsbutton.MouseLeave:Connect(function()
		if not children.Visible then
			dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end
	end)
	dotsbutton.MouseButton1Click:Connect(function()
		categoryapi:Expand(true)
	end)
	dotsbutton.MouseButton2Click:Connect(function()
		categoryapi:Expand(true)
	end)
	pin.MouseButton1Click:Connect(function()
		categoryapi:Pin()
	end)
	window.MouseButton2Click:Connect(function()
		categoryapi:Expand(true)
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		if categoryapi.Expanded then
			window.Size = UDim2.fromOffset(window.Size.X.Offset, math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601))
		end
	end)
	self:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		categoryapi:Update()
	end))

	-- Optional per-overlay colour. Overlays that opt in with Color = true get a
	-- uniform 'Overlay Color' picker that tints their primary text and icons, so
	-- every overlay can be recoloured independently. Overlays that already ship
	-- their own colour control simply do not set this. Primary elements are the
	-- ones drawn in the theme's main text colour (muted labels and special colours
	-- like health bars keep their own colour because they don't match it).
	if categorysettings.Color then
		local overlayColor = uipallet.Text
		local colorOpt
		local function closeColor(a, b)
			return math.abs(a.R - b.R) < 0.06 and math.abs(a.G - b.G) < 0.06 and math.abs(a.B - b.B) < 0.06
		end
		local function applyTo(inst)
			if inst:IsA('TextLabel') or inst:IsA('TextButton') then
				inst.TextColor3 = overlayColor
			elseif inst:IsA('ImageLabel') or inst:IsA('ImageButton') then
				inst.ImageColor3 = overlayColor
			end
		end
		local function tag(inst)
			if inst:GetAttribute('OverlayColored') ~= nil then return end
			local primary = false
			if inst:IsA('TextLabel') or inst:IsA('TextButton') then
				primary = closeColor(inst.TextColor3, uipallet.Text)
			elseif inst:IsA('ImageLabel') or inst:IsA('ImageButton') then
				primary = closeColor(inst.ImageColor3, uipallet.Text)
			end
			if primary then
				inst:SetAttribute('OverlayColored', true)
				applyTo(inst)
			end
		end
		local function recolor()
			for _, inst in window:GetDescendants() do
				if inst:GetAttribute('OverlayColored') then applyTo(inst) end
			end
		end
		for _, inst in window:GetDescendants() do tag(inst) end
		window.DescendantAdded:Connect(function(inst)
			task.defer(tag, inst)
		end)
		colorOpt = categoryapi:CreateColorSlider({
			Name = 'Overlay Color',
			DefaultHue = 0,
			DefaultSat = 0,
			DefaultValue = 1,
			Darker = true,
			Function = function()
				if not colorOpt then return end
				overlayColor = Color3.fromHSV(colorOpt.Hue, colorOpt.Sat, colorOpt.Value)
				recolor()
			end
		})
		categoryapi.ColorOption = colorOpt
	end

	categoryapi:Update()
	categoryapi.Object = window
	categoryapi.Children = customchildren
	self.Categories[categorysettings.Name] = categoryapi

	return categoryapi
end

function mainapi:CreateCategoryList(categorysettings)
	local displayName = categorysettings.DisplayName or categorysettings.Name
	local categoryapi = {
		Type = 'CategoryList',
		Expanded = false,
		List = {},
		ListEnabled = {},
		Objects = {},
		Options = {}
	}
	categorysettings.Color = categorysettings.Color or Color3.fromRGB(190, 115, 255)

	-- Take a lattice slot like the normal categories do. These list windows all defaulted to the
	-- same (240, 46), so Friends, Targets and the config list opened stacked on each other (and on
	-- top of the first category), which reads as "the tab won't open".
	mainapi.CategorySlot = (mainapi.CategorySlot or 0) + 1
	local slot = mainapi.CategorySlot
	local defaultX = 6 + (slot % 8) * 230
	local defaultY = 60 + math.floor(slot / 8) * 360

	local window = Instance.new('TextButton')
	window.Name = displayName..'CategoryList'
	window.Size = UDim2.fromOffset(220, 45)
	window.Position = UDim2.fromOffset(defaultX, defaultY)
	window.BackgroundColor3 = uipallet.Main
	window.AutoButtonColor = false
	window.Visible = false
	window.Text = ''
	window.Parent = clickgui
	addBlur(window)
	addCorner(window)
	addWindowStroke(window)
	makeDraggable(window)
	local icon = Instance.new('ImageLabel')
	icon.Name = 'Icon'
	icon.Size = categorysettings.Size
	icon.Position = categorysettings.Position or UDim2.fromOffset(12, (categorysettings.Size.X.Offset > 20 and 13 or 12))
	icon.BackgroundTransparency = 1
	icon.Image = categorysettings.Icon
	icon.ImageColor3 = uipallet.Text
	icon.Parent = window
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.new(1, -(categorysettings.Size.X.Offset > 20 and 44 or 36), 0, 20)
	title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
	title.BackgroundTransparency = 1
	title.Text = displayName
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = uipallet.Text
	title.TextSize = 13
	title.FontFace = uipallet.Font
	title.Parent = window
	local arrowbutton = Instance.new('TextButton')
	arrowbutton.Name = 'Arrow'
	arrowbutton.Size = UDim2.fromOffset(40, 40)
	arrowbutton.Position = UDim2.new(1, -40, 0, 0)
	arrowbutton.BackgroundTransparency = 1
	arrowbutton.Text = ''
	arrowbutton.Parent = window
	local arrow = Instance.new('ImageLabel')
	arrow.Name = 'Arrow'
	arrow.Size = UDim2.fromOffset(9, 4)
	arrow.Position = UDim2.fromOffset(20, 19)
	arrow.BackgroundTransparency = 1
	arrow.Image = getcustomasset('aetherv2/assets/new/expandup.png')
	arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
	arrow.Rotation = 180
	arrow.Parent = arrowbutton
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, -45)
	children.Position = UDim2.fromOffset(0, 45)
	children.BackgroundTransparency = 1
	children.BorderSizePixel = 0
	children.Visible = false
	children.ScrollBarThickness = 2
	children.ScrollBarImageTransparency = 0.75
	children.CanvasSize = UDim2.new()
	children.Parent = window
	local childrentwo = Instance.new('Frame')
	childrentwo.BackgroundTransparency = 1
	childrentwo.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
	childrentwo.Visible = false
	childrentwo.Parent = children
	local settings = Instance.new('ImageButton')
	settings.Name = 'Settings'
	settings.Size = UDim2.fromOffset(16, 16)
	settings.Position = UDim2.new(1, -52, 0, 13)
	settings.BackgroundTransparency = 1
	settings.AutoButtonColor = false
	settings.Image = getcustomasset('aetherv2/assets/new/customsettings.png')
	settings.ImageColor3 = color.Dark(uipallet.Text, 0.43)
	settings.Parent = window

	-- Configs only: a World-icon button to the LEFT of the cog that opens the repo
	-- config browser - the configs/ folder of the repository, listed from presets.json,
	-- with an Info action and a Load action.
	--
	-- Loading one is a live switch, not an install: the file is written, registered as a
	-- profile and handed straight to mainapi:Load, which toggles the modules and applies
	-- the config's keybind and accent on the spot. Nothing here asks for a rejoin or a
	-- reinject, and the menu stays open behind the window.
	if categorysettings.Profiles then
		local repoBase = configapi.Presets.Base

		local downloadbtn = Instance.new('ImageButton')
		downloadbtn.Name = 'PresetDownload'
		downloadbtn.Size = UDim2.fromOffset(16, 16)
		downloadbtn.Position = UDim2.new(1, -74, 0, 13)
		downloadbtn.BackgroundTransparency = 1
		downloadbtn.AutoButtonColor = false
		downloadbtn.Image = getcustomasset('aetherv2/assets/new/worldicon.png')
		downloadbtn.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		downloadbtn.Parent = window
		addTooltip(downloadbtn, 'Browse the configs in the repo')
		downloadbtn.MouseEnter:Connect(function() downloadbtn.ImageColor3 = uipallet.Text end)
		downloadbtn.MouseLeave:Connect(function() downloadbtn.ImageColor3 = color.Dark(uipallet.Text, 0.43) end)

		local dl = Instance.new('Frame')
		dl.Name = 'PresetDownloader'
		dl.Size = UDim2.fromOffset(376, 352)
		dl.Position = UDim2.new(0.5, -188, 0.5, -176)
		dl.BackgroundColor3 = uipallet.Main
		dl.Visible = false
		dl.Parent = scaledgui
		addBlur(dl)
		addCorner(dl)
		addWindowStroke(dl)
		makeDraggable(dl)
		local dlmodal = Instance.new('TextButton')
		dlmodal.BackgroundTransparency = 1
		dlmodal.Text = ''
		dlmodal.Modal = true
		dlmodal.Parent = dl
		local dltitle = Instance.new('TextLabel')
		dltitle.Size = UDim2.new(1, -20, 0, 20)
		dltitle.Position = UDim2.fromOffset(16, 12)
		dltitle.BackgroundTransparency = 1
		dltitle.Text = 'Repo Configs'
		dltitle.TextXAlignment = Enum.TextXAlignment.Left
		dltitle.TextColor3 = uipallet.Text
		dltitle.TextSize = 14
		dltitle.FontFace = uipallet.FontSemiBold
		dltitle.Parent = dl
		local dlsubtitle = dltitle:Clone()
		dlsubtitle.Name = 'Subtitle'
		dlsubtitle.Position = UDim2.fromOffset(16, 30)
		dlsubtitle.Size = UDim2.new(1, -50, 0, 14)
		dlsubtitle.Text = 'Loads straight away, no rejoin'
		dlsubtitle.TextColor3 = color.Dark(uipallet.Text, 0.4)
		dlsubtitle.TextSize = 11
		dlsubtitle.FontFace = uipallet.Font
		dlsubtitle.Parent = dl
		local dlclose = addCloseButton(dl)
		-- Live search over the preset list.
		local dlsearchbkg = Instance.new('Frame')
		dlsearchbkg.Name = 'SearchBkg'
		dlsearchbkg.Size = UDim2.new(1, -20, 0, 26)
		dlsearchbkg.Position = UDim2.fromOffset(10, 52)
		dlsearchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.03)
		dlsearchbkg.BorderSizePixel = 0
		dlsearchbkg.Parent = dl
		addCorner(dlsearchbkg)
		local dlsearch = Instance.new('TextBox')
		dlsearch.Size = UDim2.new(1, -16, 1, 0)
		dlsearch.Position = UDim2.fromOffset(8, 0)
		dlsearch.BackgroundTransparency = 1
		dlsearch.Text = ''
		dlsearch.PlaceholderText = 'Search by name or tag'
		dlsearch.TextXAlignment = Enum.TextXAlignment.Left
		dlsearch.TextColor3 = uipallet.Text
		dlsearch.PlaceholderColor3 = color.Dark(uipallet.Text, 0.35)
		dlsearch.TextSize = 12
		dlsearch.FontFace = uipallet.Font
		dlsearch.ClearTextOnFocus = false
		dlsearch.Parent = dlsearchbkg
		-- Inline status so the window is never silently blank (loading, fetch
		-- failure, malformed list, or an empty preset catalogue).
		local dlstatus = Instance.new('TextLabel')
		dlstatus.Name = 'Status'
		dlstatus.Size = UDim2.new(1, -20, 0, 30)
		dlstatus.Position = UDim2.fromOffset(10, 88)
		dlstatus.BackgroundTransparency = 1
		dlstatus.Text = ''
		dlstatus.TextColor3 = color.Dark(uipallet.Text, 0.35)
		dlstatus.TextSize = 12
		dlstatus.FontFace = uipallet.Font
		dlstatus.Parent = dl
		local dllist = Instance.new('ScrollingFrame')
		dllist.Name = 'List'
		dllist.Size = UDim2.new(1, -20, 1, -98)
		dllist.Position = UDim2.fromOffset(10, 88)
		dllist.BackgroundTransparency = 1
		dllist.BorderSizePixel = 0
		dllist.ScrollBarThickness = 2
		dllist.ScrollBarImageTransparency = 0.75
		dllist.CanvasSize = UDim2.new()
		dllist.Parent = dl
		local dllayout = Instance.new('UIListLayout')
		dllayout.SortOrder = Enum.SortOrder.LayoutOrder
		dllayout.Padding = UDim.new(0, 6)
		dllayout.Parent = dllist
		dllayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			dllist.CanvasSize = UDim2.fromOffset(0, dllayout.AbsoluteContentSize.Y / scale.Scale)
		end)
		table.insert(mainapi.Windows, dl)

		-- Repaints the Load button of every row so exactly one of them reads Active.
		local refreshRows
		local downloading = {}

		local function download(preset)
			-- One request per preset at a time; double-clicking the button used
			-- to fire duplicate imports.
			if downloading[preset.file] then return end
			downloading[preset.file] = true
			dlstatus.Text = 'Fetching '..tostring(preset.name)..'...'
			dlstatus.Visible = true
			task.spawn(function()
				local ok, res = pcall(function()
					return game:HttpGet(repoBase()..preset.file, true)
				end)
				if not ok or not res or res == '404: Not Found' then
					downloading[preset.file] = nil
					dlstatus.Visible = false
					mainapi:CreateNotification('Configs', 'Could not download '..tostring(preset.name)..'.', 7, 'alert')
					return
				end
				-- Writes the config, registers it as a profile, equips it and applies it
				-- to the running menu. By the time this returns the modules are already on.
				local suc, result = importJsonConfig(res, preset.name)
				downloading[preset.file] = nil
				dlstatus.Visible = false
				if suc then
					configapi.Presets.Remember(tostring(result), preset)
					refreshConfigProfiles()
					categoryapi:ChangeValue()
					refreshRows()
					mainapi:CreateNotification('Configs', tostring(result)..' is loaded and active', 5, 'info')
				else
					mainapi:CreateNotification('Configs', tostring(result), 8, 'alert')
				end
			end)
		end

		local function info(preset)
			local tags = (preset.tags and #preset.tags > 0) and table.concat(preset.tags, ', ') or 'none'
			mainapi:CreateNotification(tostring(preset.name), 'By '..tostring(preset.credits or '?')..'\nTags: '..tags..(preset.description and ('\n'..preset.description) or ''), 9, 'info')
		end

		local rowbuttons = {}
		function refreshRows()
			for name, button in rowbuttons do
				local active = mainapi.Profile == name
				button.Text = active and 'Active' or 'Load'
				button.BackgroundColor3 = active and color.Light(uipallet.Main, 0.05) or Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
				button.TextColor3 = active and color.Dark(uipallet.Text, 0.4) or mainapi:TextColor(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
			end
		end

		local function makeRow(preset)
			-- A config already sitting on disk under a preset's name came from that preset,
			-- because the browser is the only thing that writes one. Record it, so installs
			-- that pulled a preset before any of this existed still get offered the sync.
			if isfile(getConfigPath(tostring(preset.name))) then
				configapi.Presets.Remember(tostring(preset.name), preset)
			end
			local row = Instance.new('Frame')
			row.Name = tostring(preset.name)
			row:SetAttribute('Tags', preset.tags and table.concat(preset.tags, ' ') or '')
			row.Size = UDim2.new(1, 0, 0, 46)
			row.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			row.Parent = dllist
			addCorner(row)
			if preset.description then
				addTooltip(row, tostring(preset.description))
			end
			local name = Instance.new('TextLabel')
			name.Size = UDim2.new(1, -140, 0, 18)
			name.Position = UDim2.fromOffset(12, 6)
			name.BackgroundTransparency = 1
			name.Text = tostring(preset.name)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = uipallet.Text
			name.TextSize = 13
			name.FontFace = uipallet.Font
			name.Parent = row
			local tagline = name:Clone()
			tagline.Size = UDim2.new(1, -140, 0, 14)
			tagline.Position = UDim2.fromOffset(12, 24)
			tagline.Text = (preset.tags and #preset.tags > 0) and table.concat(preset.tags, ' • ') or ''
			tagline.TextColor3 = color.Dark(uipallet.Text, 0.31)
			tagline.TextSize = 11
			tagline.Parent = row
			local function mkbtn(text, xoff, colour, fn)
				local b = Instance.new('TextButton')
				b.Size = UDim2.fromOffset(58, 26)
				b.Position = UDim2.new(1, xoff, 0.5, -13)
				b.AnchorPoint = Vector2.new(1, 0)
				b.BackgroundColor3 = colour
				b.Text = text
				b.TextColor3 = uipallet.Text
				b.TextSize = 12
				b.FontFace = uipallet.Font
				b.AutoButtonColor = true
				b.Parent = row
				addCorner(b, UDim.new(0, 5))
				b.MouseButton1Click:Connect(fn)
				return b
			end
			mkbtn('Info', -74, color.Light(uipallet.Main, 0.05), function() info(preset) end)
			rowbuttons[tostring(preset.name)] = mkbtn('Load', -10, Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value), function() download(preset) end)
		end

		-- Live search: match against the preset name and its tags.
		local function applyFilter()
			local query = dlsearch.Text:lower():gsub('%s+', '')
			for _, v in dllist:GetChildren() do
				if v:IsA('Frame') then
					local haystack = (v.Name..(v:GetAttribute('Tags') or '')):lower():gsub('%s+', '')
					v.Visible = query == '' or haystack:find(query, 1, true) ~= nil
				end
			end
		end
		dlsearch:GetPropertyChangedSignal('Text'):Connect(applyFilter)

		local refreshing = false
		local function refresh()
			if refreshing then return end
			refreshing = true
			for _, v in dllist:GetChildren() do
				if v:IsA('Frame') then v:Destroy() end
			end
			table.clear(rowbuttons)
			dlstatus.Text = 'Loading configs...'
			dlstatus.Visible = true
			task.spawn(function()
				local ok, res = pcall(function()
					return game:HttpGet(repoBase()..'presets.json', true)
				end)
				refreshing = false
				if not ok or not res or res == '404: Not Found' then
					dlstatus.Text = 'Could not reach the repo. Check your connection and reopen'
					mainapi:CreateNotification('Configs', 'Could not fetch the config list.', 7, 'alert')
					return
				end
				local decoded = select(2, pcall(function() return httpService:JSONDecode(res) end))
				if type(decoded) ~= 'table' or type(decoded.presets) ~= 'table' then
					dlstatus.Text = 'The config list is malformed'
					return
				end
				if #decoded.presets == 0 then
					dlstatus.Text = 'No configs published yet'
					return
				end
				dlstatus.Visible = false
				for _, preset in decoded.presets do
					pcall(makeRow, preset)
				end
				refreshRows()
				applyFilter()
			end)
		end

		-- Opening it is also offered by the first-run welcome popup, so the opener lives
		-- on mainapi rather than only on this button.
		function mainapi.OpenRepoConfigs()
			clickgui.Visible = false
			dl.Visible = true
			dl.Position = UDim2.new(0.5, -188, 0.5, -176)
			refresh()
		end

		downloadbtn.MouseButton1Click:Connect(mainapi.OpenRepoConfigs)
		dlclose.MouseButton1Click:Connect(function()
			dl.Visible = false
			clickgui.Visible = true
		end)

		-- Bottom of the Configs window, inside it rather than in a window of its own: one
		-- button, and only while the config you are on came from the preset list. It pulls
		-- that preset down again and applies it, so a config that has moved on upstream -
		-- or been changed locally by accident - can be put back without going hunting for
		-- it in the browser.
		local sync = Instance.new('Frame')
		sync.Name = 'PresetSync'
		-- Last in the list whatever else is in it; profile rows are rebuilt at order 0.
		sync.LayoutOrder = 1000
		sync.Size = UDim2.fromOffset(200, 66)
		sync.BackgroundTransparency = 1
		sync.Visible = false
		sync.Parent = children
		local syncdivider = Instance.new('Frame')
		syncdivider.Name = 'Divider'
		syncdivider.Size = UDim2.new(1, 0, 0, 1)
		syncdivider.Position = UDim2.fromOffset(0, 6)
		syncdivider.BackgroundColor3 = Color3.new(1, 1, 1)
		syncdivider.BackgroundTransparency = 0.9
		syncdivider.BorderSizePixel = 0
		syncdivider.Parent = sync
		local synclabel = Instance.new('TextLabel')
		synclabel.Name = 'Label'
		synclabel.Size = UDim2.new(1, 0, 0, 14)
		synclabel.Position = UDim2.fromOffset(0, 14)
		synclabel.BackgroundTransparency = 1
		synclabel.Text = 'Preset config'
		synclabel.TextXAlignment = Enum.TextXAlignment.Left
		synclabel.TextColor3 = color.Dark(uipallet.Text, 0.4)
		synclabel.TextSize = 11
		synclabel.TextTruncate = Enum.TextTruncate.AtEnd
		synclabel.FontFace = uipallet.Font
		synclabel.Parent = sync
		local syncbutton = Instance.new('TextButton')
		syncbutton.Name = 'SyncButton'
		syncbutton.Size = UDim2.new(1, 0, 0, 28)
		syncbutton.Position = UDim2.fromOffset(0, 32)
		syncbutton.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		syncbutton.AutoButtonColor = true
		syncbutton.Text = 'Sync to Config'
		syncbutton.TextColor3 = uipallet.Text
		syncbutton.TextSize = 13
		syncbutton.FontFace = uipallet.Font
		syncbutton.Parent = sync
		addCorner(syncbutton, UDim.new(0, 5))
		addTooltip(syncbutton, 'Re-download this preset and apply it')

		local syncing = false
		local function refreshSync()
			local entry = configapi.Presets.Get(mainapi.Profile)
			sync.Visible = entry ~= nil
			if not entry then return end
			synclabel.Text = 'Preset - '..tostring(entry.name or mainapi.Profile)
			if syncing then return end
			syncbutton.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
			syncbutton.TextColor3 = mainapi:TextColor(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		end
		-- Called by ChangeValue, so the section appears and disappears as configs are
		-- switched, added or removed.
		categoryapi.RefreshPresetSync = refreshSync

		syncbutton.MouseButton1Click:Connect(function()
			if syncing then return end
			local name = mainapi.Profile
			local entry = configapi.Presets.Get(name)
			if not entry then
				refreshSync()
				return
			end
			syncing = true
			syncbutton.Text = 'Syncing...'
			task.spawn(function()
				local ok, res = pcall(function()
					return game:HttpGet(repoBase()..entry.file, true)
				end)
				local suc, result
				if ok and res and res ~= '404: Not Found' then
					-- Same path the browser takes: overwrite the config, re-register it and
					-- hand it to Load, which toggles the modules on the spot.
					suc, result = importJsonConfig(res, name)
				end
				syncing = false
				syncbutton.Text = 'Sync to Config'
				if suc then
					configapi.Presets.Remember(tostring(result), entry)
					refreshConfigProfiles()
					categoryapi:ChangeValue()
					if refreshRows then refreshRows() end
					mainapi:CreateNotification('Configs', tostring(result)..' is back in sync with the repo', 5, 'info')
				else
					refreshSync()
					mainapi:CreateNotification('Configs', result and tostring(result) or ('Could not re-download '..name..'.'), 7, 'alert')
				end
			end)
		end)
	end

	local divider = Instance.new('Frame')
	divider.Name = 'Divider'
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.fromOffset(0, 41)
	divider.BorderSizePixel = 0
	divider.Visible = false
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.928
	divider.Parent = window
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	windowlist.Padding = UDim.new(0, 3)
	windowlist.Parent = children
	local windowlisttwo = Instance.new('UIListLayout')
	windowlisttwo.SortOrder = Enum.SortOrder.LayoutOrder
	windowlisttwo.HorizontalAlignment = Enum.HorizontalAlignment.Center
	windowlisttwo.Padding = UDim.new(0, 4)
	windowlisttwo.Parent = childrentwo
	local childrentwopadding = Instance.new('UIPadding')
	childrentwopadding.PaddingTop = UDim.new(0, 6)
	childrentwopadding.PaddingBottom = UDim.new(0, 6)
	childrentwopadding.Parent = childrentwo
	local addbkg = Instance.new('Frame')
	addbkg.Name = 'Add'
	addbkg.Size = UDim2.fromOffset(200, 31)
	addbkg.Position = UDim2.fromOffset(10, 45)
	addbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
	addbkg.Parent = children
	addCorner(addbkg)
	local addbox = addbkg:Clone()
	addbox.Size = UDim2.new(1, -2, 1, -2)
	addbox.Position = UDim2.fromOffset(1, 1)
	addbox.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
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
	local addbutton = Instance.new('ImageButton')
	addbutton.Name = 'AddButton'
	addbutton.Size = UDim2.fromOffset(16, 16)
	addbutton.Position = UDim2.new(1, -26, 0, 8)
	addbutton.BackgroundTransparency = 1
	addbutton.Image = getcustomasset('aetherv2/assets/new/add.png')
	addbutton.ImageColor3 = categorysettings.Color
	addbutton.ImageTransparency = 0.3
	addbutton.Parent = addbkg
	local cursedpadding = Instance.new('Frame')
	cursedpadding.Size = UDim2.fromOffset()
	cursedpadding.BackgroundTransparency = 1
	cursedpadding.Parent = children
	categorysettings.Function = categorysettings.Function or function() end

	function categoryapi:ChangeValue(val)
		if val then
			if categorysettings.Profiles then
				val = val:gsub('^%s*(.-)%s*$', '%1')
				if val == '' then return end
				local ind = self:GetValue(val)
				if ind then
					if val ~= 'default' then
						table.remove(mainapi.Profiles, ind)
						if isfile(getConfigPath(val)) and delfile then
							delfile(getConfigPath(val))
						end
						if mainapi.Profile == val then
							mainapi.Profile = 'default'
						end
						mainapi:Save(mainapi.Profile)
					end
				else
					table.insert(mainapi.Profiles, {Name = val, Bind = {}})
					mainapi:Save(val)
					mainapi:Load(true, val)
					mainapi:Save(val)
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
				object.Size = UDim2.fromOffset(200, 33)
				object.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				object.AutoButtonColor = false
				object.Text = ''
				object.Parent = children
				addCorner(object)
				local objectstroke = Instance.new('UIStroke')
				objectstroke.Color = color.Light(uipallet.Main, 0.1)
				objectstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				objectstroke.Enabled = false
				objectstroke.Parent = object
				local objecttitle = Instance.new('TextLabel')
				objecttitle.Name = 'Title'
				objecttitle.Size = UDim2.new(1, -10, 1, 0)
				objecttitle.Position = UDim2.fromOffset(10, 0)
				objecttitle.BackgroundTransparency = 1
				objecttitle.Text = v.Name
				objecttitle.TextXAlignment = Enum.TextXAlignment.Left
				objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.4)
				objecttitle.TextSize = 15
				objecttitle.FontFace = uipallet.Font
				objecttitle.Parent = object
				local dotsbutton = Instance.new('TextButton')
				dotsbutton.Name = 'Dots'
				dotsbutton.Size = UDim2.fromOffset(25, 33)
				dotsbutton.Position = UDim2.new(1, -25, 0, 0)
				dotsbutton.BackgroundTransparency = 1
				dotsbutton.Text = ''
				dotsbutton.Parent = object
				local dots = Instance.new('ImageLabel')
				dots.Name = 'Dots'
				dots.Size = UDim2.fromOffset(3, 16)
				dots.Position = UDim2.fromOffset(10, 9)
				dots.BackgroundTransparency = 1
				dots.Image = getcustomasset('aetherv2/assets/new/dots.png')
				dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
				dots.Parent = dotsbutton
				local bind = Instance.new('TextButton')
				addTooltip(bind, 'Click to bind')
				bind.Name = 'Bind'
				bind.Size = UDim2.fromOffset(20, 21)
				bind.Position = UDim2.new(1, -30, 0, 6)
				bind.AnchorPoint = Vector2.new(1, 0)
				bind.BackgroundColor3 = Color3.new(1, 1, 1)
				bind.BackgroundTransparency = 0.92
				bind.BorderSizePixel = 0
				bind.AutoButtonColor = false
				bind.Visible = false
				bind.Text = ''
				addCorner(bind, UDim.new(0, 4))
				local bindicon = Instance.new('ImageLabel')
				bindicon.Name = 'Icon'
				bindicon.Size = UDim2.fromOffset(12, 12)
				bindicon.Position = UDim2.new(0.5, -6, 0, 5)
				bindicon.BackgroundTransparency = 1
				bindicon.Image = getcustomasset('aetherv2/assets/new/bind.png')
				bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				bindicon.Parent = bind
				local bindtext = Instance.new('TextLabel')
				bindtext.Size = UDim2.fromScale(1, 1)
				bindtext.Position = UDim2.fromOffset(0, 1)
				bindtext.BackgroundTransparency = 1
				bindtext.Visible = false
				bindtext.Text = ''
				bindtext.TextColor3 = color.Dark(uipallet.Text, 0.43)
				bindtext.TextSize = 12
				bindtext.FontFace = uipallet.Font
				bindtext.Parent = bind
				bind.MouseEnter:Connect(function()
					bindtext.Visible = false
					bindicon.Visible = not bindtext.Visible
					bindicon.Image = getcustomasset('aetherv2/assets/new/edit.png')
					if v.Name ~= mainapi.Profile then
						bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
					end
				end)
				bind.MouseLeave:Connect(function()
					bindtext.Visible = #v.Bind > 0
					bindicon.Visible = not bindtext.Visible
					bindicon.Image = getcustomasset('aetherv2/assets/new/bind.png')
					if v.Name ~= mainapi.Profile then
						bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
					end
				end)
				local bindcover = Instance.new('ImageLabel')
				bindcover.Name = 'Cover'
				bindcover.Size = UDim2.fromOffset(154, 33)
				bindcover.BackgroundTransparency = 1
				bindcover.Visible = false
				bindcover.Image = getcustomasset('aetherv2/assets/new/bindbkg.png')
				bindcover.ScaleType = Enum.ScaleType.Slice
				bindcover.SliceCenter = Rect.new(0, 0, 141, 40)
				bindcover.Parent = object
				local bindcovertext = Instance.new('TextLabel')
				bindcovertext.Name = 'Text'
				bindcovertext.Size = UDim2.new(1, -10, 1, -3)
				bindcovertext.BackgroundTransparency = 1
				bindcovertext.Text = 'PRESS A KEY TO BIND'
				bindcovertext.TextColor3 = uipallet.Text
				bindcovertext.TextSize = 11
				bindcovertext.FontFace = uipallet.Font
				bindcovertext.Parent = bindcover
				bind.Parent = object
				dotsbutton.MouseEnter:Connect(function()
					if v.Name ~= mainapi.Profile then
						dots.ImageColor3 = uipallet.Text
					end
				end)
				dotsbutton.MouseLeave:Connect(function()
					if v.Name ~= mainapi.Profile then
						dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
					end
				end)
				dotsbutton.MouseButton1Click:Connect(function()
					if v.Name ~= mainapi.Profile then
						categoryapi:ChangeValue(v.Name)
					end
				end)
				object.MouseButton1Click:Connect(function()
					mainapi:Save()
					mainapi:Load(true, v.Name)
					mainapi:Save()
				end)
				object.MouseEnter:Connect(function()
					bind.Visible = true
					if v.Name ~= mainapi.Profile then
						objectstroke.Enabled = true
						objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
					end
				end)
				object.MouseLeave:Connect(function()
					bind.Visible = #v.Bind > 0
					if v.Name ~= mainapi.Profile then
						objectstroke.Enabled = false
						objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.4)
					end
				end)

				local function bindFunction(self, tab, mouse)
					v.Bind = table.clone(tab)
					if mouse then
						bindcovertext.Text = #tab <= 0 and 'BIND REMOVED' or 'BOUND TO '..table.concat(tab, ' + '):upper()
						bindcover.Size = UDim2.fromOffset(getfontsize(bindcovertext.Text, bindcovertext.TextSize).X + 20, 40)
						task.delay(1, function()
							bindcover.Visible = false
						end)
					end

					if #tab <= 0 then
						bindtext.Visible = false
						bindicon.Visible = true
						bind.Size = UDim2.fromOffset(20, 21)
					else
						bind.Visible = true
						bindtext.Visible = true
						bindicon.Visible = false
						bindtext.Text = table.concat(tab, ' + '):upper()
						bind.Size = UDim2.fromOffset(math.max(getfontsize(bindtext.Text, bindtext.TextSize, bindtext.Font).X + 10, 20), 21)
					end
				end

				bindFunction({}, v.Bind)
				bind.MouseButton1Click:Connect(function()
					bindcovertext.Text = 'PRESS A KEY TO BIND'
					bindcover.Size = UDim2.fromOffset(getfontsize(bindcovertext.Text, bindcovertext.TextSize).X + 20, 40)
					bindcover.Visible = true
					mainapi.Binding = {SetBind = bindFunction, Bind = v.Bind}
				end)
				if v.Name == mainapi.Profile then
					self.Selected = object
				end
				table.insert(self.Objects, object)
			else
				local enabled = table.find(self.ListEnabled, v)
				local object = Instance.new('TextButton')
				object.Name = v
				object.Size = UDim2.fromOffset(200, 32)
				object.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				object.AutoButtonColor = false
				object.Text = ''
				object.Parent = children
				addCorner(object)
				local objectbkg = Instance.new('Frame')
				objectbkg.Name = 'BKG'
				objectbkg.Size = UDim2.new(1, -2, 1, -2)
				objectbkg.Position = UDim2.fromOffset(1, 1)
				objectbkg.BackgroundColor3 = uipallet.Main
				objectbkg.Visible = false
				objectbkg.Parent = object
				addCorner(objectbkg)
				local objectdot = Instance.new('Frame')
				objectdot.Name = 'Dot'
				objectdot.Size = UDim2.fromOffset(10, 11)
				objectdot.Position = UDim2.fromOffset(10, 12)
				objectdot.BackgroundColor3 = enabled and categorysettings.Color or color.Light(uipallet.Main, 0.37)
				objectdot.Parent = object
				addCorner(objectdot, UDim.new(1, 0))
				local objectdotin = objectdot:Clone()
				objectdotin.Size = UDim2.fromOffset(8, 9)
				objectdotin.Position = UDim2.fromOffset(1, 1)
				objectdotin.BackgroundColor3 = enabled and categorysettings.Color or color.Light(uipallet.Main, 0.02)
				objectdotin.Parent = objectdot
				local objecttitle = Instance.new('TextLabel')
				objecttitle.Name = 'Title'
				objecttitle.Size = UDim2.new(1, -30, 1, 0)
				objecttitle.Position = UDim2.fromOffset(30, 0)
				objecttitle.BackgroundTransparency = 1
				objecttitle.Text = v
				objecttitle.TextXAlignment = Enum.TextXAlignment.Left
				objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
				objecttitle.TextSize = 15
				objecttitle.FontFace = uipallet.Font
				objecttitle.Parent = object
				if mainapi.ThreadFix then
					setthreadidentity(8)
				end
				local close = Instance.new('ImageButton')
				close.Name = 'Close'
				close.Size = UDim2.fromOffset(16, 16)
				close.Position = UDim2.new(1, -23, 0, 8)
				close.BackgroundColor3 = Color3.new(1, 1, 1)
				close.BackgroundTransparency = 1
				close.AutoButtonColor = false
				close.Image = getcustomasset('aetherv2/assets/new/closemini.png')
				close.ImageColor3 = color.Light(uipallet.Text, 0.2)
				close.ImageTransparency = 0.5
				close.Parent = object
				addCorner(close, UDim.new(1, 0))
				close.MouseEnter:Connect(function()
					close.ImageTransparency = 0.3
					tween:Tween(close, uipallet.Tween, {
						BackgroundTransparency = 0.6
					})
				end)
				close.MouseLeave:Connect(function()
					close.ImageTransparency = 0.5
					tween:Tween(close, uipallet.Tween, {
						BackgroundTransparency = 1
					})
				end)
				close.MouseButton1Click:Connect(function()
					categoryapi:ChangeValue(v)
				end)
				object.MouseEnter:Connect(function()
					objectbkg.Visible = true
				end)
				object.MouseLeave:Connect(function()
					objectbkg.Visible = false
				end)
				object.MouseButton1Click:Connect(function()
					local ind = table.find(self.ListEnabled, v)
					if ind then
						table.remove(self.ListEnabled, ind)
						objectdot.BackgroundColor3 = color.Light(uipallet.Main, 0.37)
						objectdotin.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					else
						table.insert(self.ListEnabled, v)
						objectdot.BackgroundColor3 = categorysettings.Color
						objectdotin.BackgroundColor3 = categorysettings.Color
					end
					categorysettings.Function()
				end)
				table.insert(self.Objects, object)
			end
		end
		if self.RefreshPresetSync then
			self.RefreshPresetSync()
		end
		mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
	end

	function categoryapi:Expand()
		if categorysettings.Profiles then
			refreshConfigProfiles()
			self:ChangeValue()
		end
		self.Expanded = not self.Expanded
		local targetHeight = self.Expanded and math.min(51 + windowlist.AbsoluteContentSize.Y / scale.Scale, 611) or 45
		-- Animated open/close (see the matching category Expand above): the children
		-- ScrollingFrame is pinned to the window height and clips, so a height tween
		-- reveals/hides the rows smoothly. Keep them mounted until a collapse ends.
		if self.Expanded then
			children.Visible = true
		else
			task.delay(uipallet.Tween.Time, function()
				if not self.Expanded then
					children.Visible = false
				end
			end)
		end
		tween:Tween(window, uipallet.Tween, {Size = UDim2.fromOffset(220, targetHeight)})
		tweenService:Create(arrow, uipallet.Tween, {Rotation = self.Expanded and 0 or 180}):Play()
		divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
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

	addbutton.MouseEnter:Connect(function()
		addbutton.ImageTransparency = 0
	end)
	addbutton.MouseLeave:Connect(function()
		addbutton.ImageTransparency = 0.3
	end)
	addbutton.MouseButton1Click:Connect(function()
		local value = addvalue.Text:gsub('^%s*(.-)%s*$', '%1')
		if value ~= '' and (categorysettings.Profiles and not categoryapi:GetValue(value) or not table.find(categoryapi.List, value)) then
			categoryapi:ChangeValue(value)
			addvalue.Text = ''
		end
	end)
	arrowbutton.MouseEnter:Connect(function()
		arrow.ImageColor3 = Color3.fromRGB(220, 220, 220)
	end)
	arrowbutton.MouseLeave:Connect(function()
		arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
	end)
	arrowbutton.MouseButton1Click:Connect(function()
		categoryapi:Expand()
	end)
	arrowbutton.MouseButton2Click:Connect(function()
		categoryapi:Expand()
	end)
	addvalue.FocusLost:Connect(function(enter)
		local value = addvalue.Text:gsub('^%s*(.-)%s*$', '%1')
		if enter and value ~= '' and (categorysettings.Profiles and not categoryapi:GetValue(value) or not table.find(categoryapi.List, value)) then
			categoryapi:ChangeValue(value)
			addvalue.Text = ''
		end
	end)
	addvalue.MouseEnter:Connect(function()
		tween:Tween(addbkg, uipallet.Tween, {
			BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		})
	end)
	addvalue.MouseLeave:Connect(function()
		tween:Tween(addbkg, uipallet.Tween, {
			BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		})
	end)
	children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
		divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
	end)
	settings.MouseEnter:Connect(function()
		settings.ImageColor3 = uipallet.Text
	end)
	settings.MouseLeave:Connect(function()
		settings.ImageColor3 = color.Dark(uipallet.Text, 0.43)
	end)
	settings.MouseButton1Click:Connect(function()
		childrentwo.Visible = not childrentwo.Visible
	end)
	window.InputBegan:Connect(function(inputObj)
		if inputObj.Position.Y < window.AbsolutePosition.Y + 41 and inputObj.UserInputType == Enum.UserInputType.MouseButton2 then
			categoryapi:Expand()
		end
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		if categoryapi.Expanded then
			window.Size = UDim2.fromOffset(220, math.min(51 + windowlist.AbsoluteContentSize.Y / scale.Scale, 611))
		end
	end)
	windowlisttwo:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		-- Divide by the GUI scale like every other panel does; without this the expanded
		-- cog panel's height was wrong at non-default scales, so its text/buttons were
		-- clipped and looked cramped. The +12 accounts for the top/bottom padding.
		childrentwo.Size = UDim2.fromOffset(220, (windowlisttwo.AbsoluteContentSize.Y / scale.Scale) + 12)
	end)

	categoryapi.Button = self.Categories.Main:CreateButton({
		Name = displayName,
		Icon = categorysettings.CategoryIcon,
		Size = categorysettings.CategorySize,
		Window = window
	})

	categoryapi.Object = window
	categoryapi.DefaultPosition = UDim2.fromOffset(defaultX, defaultY)
	self.Categories[categorysettings.Name] = categoryapi

	return categoryapi
end

--[[
	First run

	Opening the menu for the very first time drops a short card in front of it: what the
	menu key is, where configs come from, and where to ask for help. It is written once
	to profiles/welcome.txt and never shown again, and the file lives in profiles/ so a
	script update cannot bring it back.
]]
function mainapi:CreateWelcome()
	local seenpath = 'aetherv2/profiles/welcome.txt'
	if isfile(seenpath) then return end

	-- Two heights: the card on its own, and the card with the preset picker open under
	-- the question. Everything below the question moves with it.
	local shortHeight, tallHeight = 314, 452
	local cardHeight = shortHeight

	local card = Instance.new('Frame')
	card.Name = 'Welcome'
	card.Size = UDim2.fromOffset(430, cardHeight)
	card.Position = UDim2.new(0.5, -215, 0.5, -cardHeight / 2)
	card.BackgroundColor3 = uipallet.Main
	card.Visible = false
	card.Parent = scaledgui
	addBlur(card)
	addCorner(card)
	addWindowStroke(card)
	makeDraggable(card)
	local cardmodal = Instance.new('TextButton')
	cardmodal.BackgroundTransparency = 1
	cardmodal.Text = ''
	cardmodal.Modal = true
	cardmodal.Parent = card

	local logo = Instance.new('ImageLabel')
	logo.Name = 'Logo'
	logo.Size = UDim2.fromOffset(26, 26)
	logo.Position = UDim2.fromOffset(22, 22)
	logo.BackgroundTransparency = 1
	logo.Image = getcustomasset('aetherv2/assets/new/vape.png')
	logo.Parent = card

	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.new(1, -110, 0, 22)
	title.Position = UDim2.fromOffset(58, 22)
	title.BackgroundTransparency = 1
	title.Text = 'Welcome to AetherV2'
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = uipallet.Text
	title.TextSize = 18
	title.FontFace = uipallet.FontSemiBold
	title.Parent = card

	local subtitle = title:Clone()
	subtitle.Name = 'Subtitle'
	subtitle.Size = UDim2.new(1, -110, 0, 16)
	subtitle.Position = UDim2.fromOffset(58, 42)
	subtitle.Text = 'A few things worth knowing before you start'
	subtitle.TextColor3 = color.Dark(uipallet.Text, 0.4)
	subtitle.TextSize = 12
	subtitle.FontFace = uipallet.Font
	subtitle.Parent = card

	local rows = Instance.new('Frame')
	rows.Name = 'Rows'
	rows.Size = UDim2.new(1, -44, 0, 108)
	rows.Position = UDim2.fromOffset(22, 84)
	rows.BackgroundTransparency = 1
	rows.Parent = card
	local rowlist = Instance.new('UIListLayout')
	rowlist.SortOrder = Enum.SortOrder.LayoutOrder
	rowlist.Padding = UDim.new(0, 6)
	rowlist.Parent = rows

	for index, entry in {
		{Heading = 'Open and close the menu', Body = 'Press '..table.concat(mainapi.Keybind, ' + '):upper()..'. Rebind it from the key next to the logo'},
		{Heading = 'Configs live in the repo', Body = 'Profiles has a globe button that lists them, and loading one applies it right away'},
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

	local function makeButton(text, order, primary, fn)
		local button = Instance.new('TextButton')
		button.Name = text
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(126, 30)
		button.BackgroundColor3 = primary and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.04)
		button.AutoButtonColor = true
		button.Text = text
		button.TextColor3 = primary and mainapi:TextColor(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or uipallet.Text
		button.TextSize = 13
		button.FontFace = uipallet.Font
		button.Parent = card
		addCorner(button, UDim.new(0, 5))
		button.MouseButton1Click:Connect(fn)
		return button
	end

	--[[
		Setup step: do you want a config to start on?

		A fresh install starts with every module off, which is a strange place to be
		dropped. Answering yes opens the published preset list right here rather than
		sending the user off to find the browser, and loading one applies it on the spot -
		by the time the card is dismissed the config is already running.
	]]
	local question = Instance.new('Frame')
	question.Name = 'PresetQuestion'
	question.Size = UDim2.new(1, -44, 0, 46)
	question.Position = UDim2.fromOffset(22, 200)
	question.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
	question.Parent = card
	addCorner(question)
	local questiontitle = Instance.new('TextLabel')
	questiontitle.Size = UDim2.new(1, -140, 0, 16)
	questiontitle.Position = UDim2.fromOffset(10, 7)
	questiontitle.BackgroundTransparency = 1
	questiontitle.Text = 'Download a preset config?'
	questiontitle.TextXAlignment = Enum.TextXAlignment.Left
	questiontitle.TextColor3 = uipallet.Text
	questiontitle.TextSize = 13
	questiontitle.FontFace = uipallet.Font
	questiontitle.Parent = question
	local questionbody = questiontitle:Clone()
	questionbody.Size = UDim2.new(1, -140, 0, 14)
	questionbody.Position = UDim2.fromOffset(10, 24)
	questionbody.Text = 'Starts you on a ready-made setup instead of nothing'
	questionbody.TextColor3 = color.Dark(uipallet.Text, 0.36)
	questionbody.TextSize = 11
	questionbody.Parent = question

	local picker = Instance.new('ScrollingFrame')
	picker.Name = 'PresetPicker'
	picker.Size = UDim2.new(1, -44, 0, 116)
	picker.Position = UDim2.fromOffset(22, 254)
	picker.BackgroundTransparency = 1
	picker.BorderSizePixel = 0
	picker.ScrollBarThickness = 2
	picker.ScrollBarImageTransparency = 0.75
	picker.CanvasSize = UDim2.new()
	picker.Visible = false
	picker.Parent = card
	local pickerlist = Instance.new('UIListLayout')
	pickerlist.SortOrder = Enum.SortOrder.LayoutOrder
	pickerlist.Padding = UDim.new(0, 6)
	pickerlist.Parent = picker
	pickerlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		picker.CanvasSize = UDim2.fromOffset(0, pickerlist.AbsoluteContentSize.Y / scale.Scale)
	end)
	local pickerstatus = Instance.new('TextLabel')
	pickerstatus.Name = 'Status'
	pickerstatus.Size = UDim2.new(1, -44, 0, 16)
	pickerstatus.Position = UDim2.fromOffset(22, 374)
	pickerstatus.BackgroundTransparency = 1
	pickerstatus.Text = ''
	pickerstatus.TextXAlignment = Enum.TextXAlignment.Left
	pickerstatus.TextColor3 = color.Dark(uipallet.Text, 0.4)
	pickerstatus.TextSize = 11
	pickerstatus.FontFace = uipallet.Font
	pickerstatus.Visible = false
	pickerstatus.Parent = card

	local buttons = Instance.new('Frame')
	buttons.Name = 'Buttons'
	buttons.Size = UDim2.new(1, -44, 0, 30)
	buttons.Position = UDim2.fromOffset(22, 258)
	buttons.BackgroundTransparency = 1
	buttons.Parent = card
	local buttonlist = Instance.new('UIListLayout')
	buttonlist.FillDirection = Enum.FillDirection.Horizontal
	buttonlist.SortOrder = Enum.SortOrder.LayoutOrder
	buttonlist.Padding = UDim.new(0, 8)
	buttonlist.Parent = buttons

	local function dismiss()
		card.Visible = false
		clickgui.Visible = true
		pcall(writefile, seenpath, 'true')
	end

	makeButton('Browse configs', 1, false, function()
		dismiss()
		if mainapi.OpenRepoConfigs then
			mainapi.OpenRepoConfigs()
		end
	end).Parent = buttons
	makeButton('Copy discord', 2, false, function()
		if setclipboard then
			setclipboard('https://discord.gg/aYu5c9v9zv')
		end
		mainapi:CreateNotification('AetherV2', 'Discord invite copied to your clipboard', 5, 'info')
	end).Parent = buttons
	makeButton('Start', 3, true, dismiss).Parent = buttons

	local footer = Instance.new('TextLabel')
	footer.Name = 'Footer'
	footer.Size = UDim2.new(1, -44, 0, 14)
	footer.Position = UDim2.fromOffset(22, 294)
	footer.BackgroundTransparency = 1
	footer.Text = 'Shown once. Everything here lives in the menu if you need it later'
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextColor3 = color.Dark(uipallet.Text, 0.5)
	footer.TextSize = 11
	footer.FontFace = uipallet.Font
	footer.Parent = card

	-- Yes/No, and the card grows or shrinks around the answer.
	local picking = false
	local yesbutton, nobutton
	local function layout()
		picker.Visible = picking
		pickerstatus.Visible = picking and pickerstatus.Text ~= ''
		buttons.Position = UDim2.fromOffset(22, picking and 396 or 258)
		footer.Position = UDim2.fromOffset(22, picking and 432 or 294)
		cardHeight = picking and tallHeight or shortHeight
		card.Size = UDim2.fromOffset(430, cardHeight)
		for _, entry in {{Button = yesbutton, On = picking}, {Button = nobutton, On = not picking}} do
			if entry.Button then
				entry.Button.BackgroundColor3 = entry.On and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.05)
				entry.Button.TextColor3 = entry.On and mainapi:TextColor(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Dark(uipallet.Text, 0.3)
			end
		end
	end

	local function makeAnswer(text, xoff)
		local button = Instance.new('TextButton')
		button.Name = text
		button.Size = UDim2.fromOffset(56, 26)
		button.Position = UDim2.new(1, xoff, 0.5, -13)
		button.AnchorPoint = Vector2.new(1, 0)
		button.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
		button.AutoButtonColor = true
		button.Text = text
		button.TextColor3 = color.Dark(uipallet.Text, 0.3)
		button.TextSize = 12
		button.FontFace = uipallet.Font
		button.Parent = question
		addCorner(button, UDim.new(0, 5))
		return button
	end
	nobutton = makeAnswer('No', -10)
	yesbutton = makeAnswer('Yes', -72)

	local loading, loaded = false, nil
	local function makePresetRow(preset, order)
		local row = Instance.new('Frame')
		row.Name = tostring(preset.name)
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 42)
		row.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		row.Parent = picker
		addCorner(row)
		local name = Instance.new('TextLabel')
		name.Size = UDim2.new(1, -100, 0, 16)
		name.Position = UDim2.fromOffset(10, 5)
		name.BackgroundTransparency = 1
		name.Text = tostring(preset.name)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = uipallet.Text
		name.TextSize = 12
		name.FontFace = uipallet.Font
		name.Parent = row
		local body = name:Clone()
		body.Size = UDim2.new(1, -100, 0, 14)
		body.Position = UDim2.fromOffset(10, 22)
		body.Text = preset.description and tostring(preset.description)
			or ((preset.tags and #preset.tags > 0) and table.concat(preset.tags, ' • ') or '')
		body.TextColor3 = color.Dark(uipallet.Text, 0.36)
		body.TextSize = 11
		body.TextTruncate = Enum.TextTruncate.AtEnd
		body.Parent = row
		local get = Instance.new('TextButton')
		get.Size = UDim2.fromOffset(66, 24)
		get.Position = UDim2.new(1, -10, 0.5, -12)
		get.AnchorPoint = Vector2.new(1, 0)
		get.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		get.AutoButtonColor = true
		get.Text = 'Download'
		get.TextColor3 = mainapi:TextColor(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		get.TextSize = 11
		get.FontFace = uipallet.Font
		get.Parent = row
		addCorner(get, UDim.new(0, 5))
		get.MouseButton1Click:Connect(function()
			if loading then return end
			loading = true
			get.Text = '...'
			task.spawn(function()
				local ok, res = pcall(function()
					return game:HttpGet(configapi.Presets.Base()..tostring(preset.file), true)
				end)
				local suc, result
				if ok and res and res ~= '404: Not Found' then
					suc, result = importJsonConfig(res, preset.name)
				end
				loading = false
				get.Text = suc and 'Loaded' or 'Download'
				if not suc then
					pickerstatus.Text = 'Could not download '..tostring(preset.name)..'.'
					pickerstatus.Visible = true
					return
				end
				configapi.Presets.Remember(tostring(result), preset)
				refreshConfigProfiles()
				if mainapi.Categories.Profiles then
					mainapi.Categories.Profiles:ChangeValue()
				end
				-- Only one config can be active, so any earlier pick is no longer loaded.
				if loaded and loaded ~= get then
					loaded.Text = 'Download'
				end
				loaded = get
				pickerstatus.Text = tostring(result)..' is loaded and active'
				pickerstatus.Visible = true
			end)
		end)
	end

	local fetched = false
	local function fetchPresets()
		if fetched then return end
		fetched = true
		pickerstatus.Text = 'Loading configs...'
		layout()
		task.spawn(function()
			local ok, res = pcall(function()
				return game:HttpGet(configapi.Presets.Base()..'presets.json', true)
			end)
			local decoded = ok and res and res ~= '404: Not Found'
				and select(2, pcall(function() return httpService:JSONDecode(res) end))
				or nil
			if type(decoded) ~= 'table' or type(decoded.presets) ~= 'table' or #decoded.presets == 0 then
				fetched = false
				pickerstatus.Text = 'No configs available right now'
				layout()
				return
			end
			pickerstatus.Text = ''
			for index, preset in decoded.presets do
				pcall(makePresetRow, preset, index)
			end
			layout()
		end)
	end

	yesbutton.MouseButton1Click:Connect(function()
		picking = true
		layout()
		fetchPresets()
	end)
	nobutton.MouseButton1Click:Connect(function()
		picking = false
		layout()
	end)
	layout()

	addCloseButton(card).MouseButton1Click:Connect(dismiss)
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
		card.Position = UDim2.new(0.5, -215, 0.5, -cardHeight / 2)
	end)
	mainapi:Clean(watcher)
end

function mainapi:CreateSearch()
	local xscale = inputService.TouchEnabled and 0.1 or 0.5
	local searchbkg = Instance.new('Frame')
	searchbkg.Name = 'Search'
	searchbkg.Size = UDim2.fromOffset(220, 37)
	searchbkg.Position = UDim2.new(xscale, 0, 0, 13)
	searchbkg.AnchorPoint = Vector2.new(xscale, 0)
	searchbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
	searchbkg.Parent = clickgui
	local searchicon = Instance.new('ImageLabel')
	searchicon.Name = 'Icon'
	searchicon.Size = UDim2.fromOffset(14, 14)
	searchicon.Position = UDim2.new(1, -23, 0, 11)
	searchicon.BackgroundTransparency = 1
	searchicon.Image = getcustomasset('aetherv2/assets/new/search.png')
	searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
	searchicon.Parent = searchbkg
	local legiticon = Instance.new('ImageButton')
	legiticon.Name = 'Legit'
	legiticon.Size = UDim2.fromOffset(29, 16)
	legiticon.Position = UDim2.fromOffset(8, 11)
	legiticon.BackgroundTransparency = 1
	legiticon.Image = getcustomasset('aetherv2/assets/new/legit.png')
	legiticon.Parent = searchbkg
	local legitdivider = Instance.new('Frame')
	legitdivider.Name = 'LegitDivider'
	legitdivider.Size = UDim2.fromOffset(2, 12)
	legitdivider.Position = UDim2.fromOffset(43, 13)
	legitdivider.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
	legitdivider.BorderSizePixel = 0
	legitdivider.Parent = searchbkg
	addBlur(searchbkg)
	addCorner(searchbkg)
	-- Accent ring that fades in while the search box is focused (GUI polish).
	local searchstroke = Instance.new('UIStroke')
	searchstroke.Name = 'FocusRing'
	searchstroke.Color = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
	searchstroke.Thickness = 1
	searchstroke.Transparency = 1
	searchstroke.Parent = searchbkg
	local search = Instance.new('TextBox')
	search.Size = UDim2.new(1, -68, 0, 37)
	search.Position = UDim2.fromOffset(50, 0)
	search.BackgroundTransparency = 1
	search.Text = ''
	search.PlaceholderText = 'Search modules...'
	search.PlaceholderColor3 = color.Dark(uipallet.Text, 0.5)
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.TextColor3 = uipallet.Text
	search.TextSize = 12
	search.FontFace = uipallet.Font
	search.ClearTextOnFocus = false
	search.Parent = searchbkg
	-- Clear (x) button: only shown once there's a query to clear.
	local clearbutton = Instance.new('TextButton')
	clearbutton.Name = 'Clear'
	clearbutton.Size = UDim2.fromOffset(16, 16)
	clearbutton.Position = UDim2.new(1, -42, 0, 10)
	clearbutton.BackgroundColor3 = color.Light(uipallet.Main, 0.1)
	clearbutton.AutoButtonColor = false
	clearbutton.Text = '✕'
	clearbutton.TextColor3 = color.Dark(uipallet.Text, 0.3)
	clearbutton.TextSize = 10
	clearbutton.FontFace = uipallet.Font
	clearbutton.Visible = false
	clearbutton.Parent = searchbkg
	addCorner(clearbutton, UDim.new(1, 0))
	clearbutton.MouseEnter:Connect(function()
		clearbutton.TextColor3 = uipallet.Text
	end)
	clearbutton.MouseLeave:Connect(function()
		clearbutton.TextColor3 = color.Dark(uipallet.Text, 0.3)
	end)
	clearbutton.MouseButton1Click:Connect(function()
		search.Text = ''
		search:CaptureFocus()
	end)
	search.Focused:Connect(function()
		tweenService:Create(searchstroke, uipallet.Tween, {Transparency = 0.2}):Play()
	end)
	search.FocusLost:Connect(function()
		tweenService:Create(searchstroke, uipallet.Tween, {Transparency = 1}):Play()
	end)
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, -37)
	children.Position = UDim2.fromOffset(0, 34)
	children.BackgroundTransparency = 1
	children.BorderSizePixel = 0
	children.ScrollBarThickness = 2
	children.ScrollBarImageTransparency = 0.75
	children.CanvasSize = UDim2.new()
	children.Parent = searchbkg
	local divider = Instance.new('Frame')
	divider.Name = 'Divider'
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.fromOffset(0, 33)
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.928
	divider.BorderSizePixel = 0
	divider.Visible = false
	divider.Parent = searchbkg
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	windowlist.Parent = children
	-- Empty-state hint so a query matching nothing reads as "no matches" rather
	-- than a blank dropdown.
	local noresults = Instance.new('TextLabel')
	noresults.Name = 'NoResults'
	noresults.Size = UDim2.new(1, 0, 0, 34)
	noresults.BackgroundTransparency = 1
	noresults.Text = 'No modules found'
	noresults.TextColor3 = color.Dark(uipallet.Text, 0.4)
	noresults.TextSize = 12
	noresults.FontFace = uipallet.Font
	noresults.Visible = false
	noresults.Parent = children

	children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
		divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
	end)
	legiticon.MouseButton1Click:Connect(function()
		clickgui.Visible = false
		self.Legit.Window.Visible = true
		self.Legit.Window.Position = UDim2.new(0.5, -350, 0.5, -194)
	end)
	search:GetPropertyChangedSignal('Text'):Connect(function()
		clearbutton.Visible = search.Text ~= ''
		for _, v in children:GetChildren() do
			if v:IsA('TextButton') then
				v:Destroy()
			end
		end
		if search.Text == '' then
			noresults.Visible = false
			return
		end

		local matches = 0
		for i, v in self.Modules do
			-- Plain find: the query is user text, not a Lua pattern (typing
			-- characters like '(' or '%' used to error here).
			if i:lower():find(search.Text:lower(), 1, true) then
				matches += 1
				local button = v.Object:Clone()
				button.Bind:Destroy()
				button.MouseButton1Click:Connect(function()
					v:Toggle()
				end)

				button.MouseButton2Click:Connect(function()
					-- Hand off to the shared scroll engine: it opens the category if
					-- it's toggled-off or minimised, then smooth-scrolls so the module
					-- sits centred - accurate even when modules above have their
					-- settings expanded (the old LayoutOrder * 40 assumed 40px rows and
					-- landed in the wrong place) - and flashes it on arrival.
					self:ScrollToModule(v, {
						Tint = Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
					})
				end)

				button.Parent = children
				task.spawn(function()
					repeat
						for _, v2 in {'Text', 'TextColor3', 'BackgroundColor3'} do
							button[v2] = v.Object[v2]
						end
						button.UIGradient.Color = v.Object.UIGradient.Color
						button.UIGradient.Enabled = v.Object.UIGradient.Enabled
						button.Dots.Dots.ImageColor3 = v.Object.Dots.Dots.ImageColor3
						task.wait()
					until not button.Parent
				end)
			end
		end
		noresults.Visible = matches == 0
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
		searchbkg.Size = UDim2.fromOffset(220, math.min(37 + windowlist.AbsoluteContentSize.Y / scale.Scale, 437))
	end)

	self.Legit.Icon = legiticon
end

function mainapi:CreateLegit()
	local legitapi = {Modules = {}, Categories = {}}

	local window = Instance.new('Frame')
	window.Name = 'LegitGUI'
	window.Size = UDim2.fromOffset(700, 389)
	window.Position = UDim2.new(0.5, -350, 0.5, -194)
	window.BackgroundColor3 = uipallet.Main
	window.Visible = false
	window.Parent = scaledgui
	addBlur(window)
	addCorner(window)
	makeDraggable(window)
	local modal = Instance.new('TextButton')
	modal.BackgroundTransparency = 1
	modal.Text = ''
	modal.Modal = true
	modal.Parent = window
	local icon = Instance.new('ImageLabel')
	icon.Name = 'Icon'
	icon.Size = UDim2.fromOffset(16, 16)
	icon.Position = UDim2.fromOffset(18, 13)
	icon.BackgroundTransparency = 1
	icon.Image = getcustomasset('aetherv2/assets/new/legittab.png')
	icon.ImageColor3 = uipallet.Text
	icon.Parent = window
	local close = addCloseButton(window)
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.fromOffset(684, 300)
	children.Position = UDim2.fromOffset(14, 80)
	children.BackgroundTransparency = 1
	children.BorderSizePixel = 0
	children.ScrollBarThickness = 2
	children.ScrollBarImageTransparency = 0.75
	children.CanvasSize = UDim2.new()
	children.Parent = window
	local windowlist = Instance.new('UIGridLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.FillDirectionMaxCells = 4
	windowlist.CellSize = UDim2.fromOffset(163, 114)
	windowlist.CellPadding = UDim2.fromOffset(6, 5)
	windowlist.Parent = children
	local search = Instance.new('Frame')
	search.Position = UDim2.fromOffset(449, 42)
	search.Name = 'Search'
	search.Size = UDim2.fromOffset(240, 31)
	search.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
	search.Parent = window
	addCorner(search, UDim.new(0, 5))
	local searchbox = search:Clone()
	searchbox.Size = UDim2.new(1, -2, 1, -2)
	searchbox.Position = UDim2.fromOffset(1, 1)
	searchbox.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
	searchbox.Parent = search
	local searchvalue = Instance.new('TextBox')
	searchvalue.Size = UDim2.new(1, -35, 1, 0)
	searchvalue.Position = UDim2.fromOffset(10, 0)
	searchvalue.BackgroundTransparency = 1
	searchvalue.Text = ''
	searchvalue.PlaceholderText = 'Search mods'
	searchvalue.TextXAlignment = Enum.TextXAlignment.Left
	searchvalue.PlaceholderColor3 = color.Dark(uipallet.Text, 0.11)
	searchvalue.TextColor3 = color.Dark(uipallet.Text, 0.11)
	searchvalue.TextSize = 14
	searchvalue.FontFace = uipallet.Font
	searchvalue.ClearTextOnFocus = false
	searchvalue.Parent = search
	local searchicon = Instance.new('ImageLabel')
	searchicon.BackgroundTransparency = 1
	searchicon.Position = UDim2.new(1, -28, 0, 8)
	searchicon.Size = UDim2.fromOffset(12, 12)
	searchicon.Image = getcustomasset('aetherv2/assets/new/search.png')
	searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
	searchicon.Parent = searchbox
	local categorylist = Instance.new('Frame')
	categorylist.BackgroundTransparency = 1
	categorylist.Position = UDim2.fromOffset(22, 42)
	categorylist.Size = UDim2.fromOffset(1, 31)
	categorylist.Parent = window
	local categorylayout = Instance.new('UIListLayout')
	categorylayout.FillDirection = Enum.FillDirection.Horizontal
	categorylayout.Parent = categorylist
	categorylayout.SortOrder = Enum.SortOrder.LayoutOrder
	local categoryhighlight = Instance.new('Frame')
	categoryhighlight.BackgroundColor3 = color.Dark(uipallet.Text, 0.31)
	categoryhighlight.BorderSizePixel = 0
	categoryhighlight.Position = UDim2.fromOffset(0, 23)
	categoryhighlight.Size = UDim2.new()
	legitapi.Window = window
	table.insert(mainapi.Windows, window)
	
	local function updateCheck()
		local FocusedCategory = ''
		for _, v in legitapi.Categories do
			if v.Focused then
				FocusedCategory = v.Name
				break
			end
		end
		for i, v in legitapi.Modules do
			-- Plain find (and truncate gsub to its first return): the query is
			-- user text, not a Lua pattern, and gsub's replacement count used to
			-- leak into find's init argument.
			v.Object.Visible = (FocusedCategory == 'All' or v.ApiCategory == FocusedCategory) and (i == '' or i:lower():gsub(' ', ''):find((searchvalue.Text:lower():gsub(' ', '')), 1, true) and true) or false
		end
	end

	function legitapi:CreateCategory(categoryname)
		local category = {
			Name = categoryname,
			Focused = #self.Categories <= 0 and true or false
		}

		local children = Instance.new('TextButton')
		children.Name = category.Name
		children.LayoutOrder = #self.Categories + 1
		children.BackgroundTransparency = 1
		children.Size = UDim2.new(0, 80, 1, 0)
		children.FontFace = uipallet.Font
		children.TextColor3 = color.Dark(uipallet.Text, 0.31)
		children.Text = category.Name
		children.TextSize = 14
		children.TextXAlignment = Enum.TextXAlignment.Left
		children.Parent = categorylist
		children.MouseButton1Click:Connect(function()
			category:SetVisible()
		end)
		
		local sizex = textService:GetTextSize(children.Text, children.TextSize, children.Font, Vector2.new(1000, 1000)).X
		children.Size = UDim2.new(0, sizex + 30, 1, 0)

		function category:SetVisible(focused)
			focused = focused or focused == nil and true
			children.TextColor3 = focused and color.Light(uipallet.Text, 0.2) or color.Dark(uipallet.Text, 0.31)
			categoryhighlight.Parent = focused and children or categoryhighlight.Parent
			categoryhighlight.Size = focused and UDim2.fromOffset(sizex, 1) or categoryhighlight.Size
			category.Focused = focused

			if focused then
				for _, v in legitapi.Categories do
					if v.Name ~= category.Name and v.Focused then
						v:SetVisible(false)
					end
				end
				updateCheck()
			end
		end

		if category.Focused then
			category:SetVisible(true)
			updateCheck()
		end

		category.Window = children
		table.insert(legitapi.Categories, category)
		return category
	end

	function legitapi:CreateModule(modulesettings)
		mainapi:Remove(modulesettings.Name, true)
		local moduleapi = {
			Enabled = false,
			ApiCategory = modulesettings.Category or 'Game',
			Options = {},
			Name = modulesettings.Name,
			Legit = true
		}

		local module = Instance.new('TextButton')
		module.Name = modulesettings.Name
		module.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		module.Text = ''
		module.AutoButtonColor = false
		module.Parent = children
		addTooltip(module, modulesettings.Tooltip)
		addCorner(module)
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -16, 0, 20)
		title.Position = UDim2.fromOffset(16, 81)
		title.BackgroundTransparency = 1
		title.Text = modulesettings.Name
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = color.Dark(uipallet.Text, 0.31)
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = module
		local knob = Instance.new('Frame')
		knob.Name = 'Knob'
		knob.Size = UDim2.fromOffset(22, 12)
		knob.Position = UDim2.new(1, -57, 0, 14)
		knob.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		knob.Parent = module
		addCorner(knob, UDim.new(1, 0))
		local knobmain = knob:Clone()
		knobmain.Size = UDim2.fromOffset(8, 8)
		knobmain.Position = UDim2.fromOffset(2, 2)
		knobmain.BackgroundColor3 = uipallet.Main
		knobmain.Parent = knob
		local dotsbutton = Instance.new('TextButton')
		dotsbutton.Name = 'Dots'
		dotsbutton.Size = UDim2.fromOffset(14, 24)
		dotsbutton.Position = UDim2.new(1, -27, 0, 8)
		dotsbutton.BackgroundTransparency = 1
		dotsbutton.Text = ''
		dotsbutton.Parent = module
		local dots = Instance.new('ImageLabel')
		dots.Name = 'Dots'
		dots.Size = UDim2.fromOffset(2, 12)
		dots.Position = UDim2.fromOffset(6, 6)
		dots.BackgroundTransparency = 1
		dots.Image = getcustomasset('aetherv2/assets/new/dots.png')
		dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
		dots.Parent = dotsbutton
		local shadow = Instance.new('TextButton')
		shadow.Name = 'Shadow'
		shadow.Size = UDim2.new(1, 0, 1, -5)
		shadow.BackgroundColor3 = Color3.new()
		shadow.BackgroundTransparency = 1
		shadow.AutoButtonColor = false
		shadow.ClipsDescendants = true
		shadow.Visible = false
		shadow.Text = ''
		shadow.Parent = window
		addCorner(shadow)
		local settingspane = Instance.new('TextButton')
		settingspane.Size = UDim2.new(0, 220, 1, 0)
		settingspane.Position = UDim2.fromScale(1, 0)
		settingspane.BackgroundColor3 = uipallet.Main
		settingspane.AutoButtonColor = false
		settingspane.Text = ''
		settingspane.Parent = shadow
		local settingstitle = Instance.new('TextLabel')
		settingstitle.Name = 'Title'
		settingstitle.Size = UDim2.new(1, -36, 0, 20)
		settingstitle.Position = UDim2.fromOffset(36, 12)
		settingstitle.BackgroundTransparency = 1
		settingstitle.Text = modulesettings.Name
		settingstitle.TextXAlignment = Enum.TextXAlignment.Left
		settingstitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
		settingstitle.TextSize = 13
		settingstitle.FontFace = uipallet.Font
		settingstitle.Parent = settingspane
		local back = Instance.new('ImageButton')
		back.Name = 'Back'
		back.Size = UDim2.fromOffset(16, 16)
		back.Position = UDim2.fromOffset(11, 13)
		back.BackgroundTransparency = 1
		back.Image = getcustomasset('aetherv2/assets/new/back.png')
		back.ImageColor3 = color.Light(uipallet.Main, 0.37)
		back.Parent = settingspane
		addCorner(settingspane)
		local settingschildren = Instance.new('ScrollingFrame')
		settingschildren.Name = 'Children'
		settingschildren.Size = UDim2.new(1, 0, 1, -45)
		settingschildren.Position = UDim2.fromOffset(0, 41)
		settingschildren.BackgroundColor3 = uipallet.Main
		settingschildren.BorderSizePixel = 0
		settingschildren.ScrollBarThickness = 2
		settingschildren.ScrollBarImageTransparency = 0.75
		settingschildren.CanvasSize = UDim2.new()
		settingschildren.Parent = settingspane
		local settingswindowlist = Instance.new('UIListLayout')
		settingswindowlist.SortOrder = Enum.SortOrder.LayoutOrder
		settingswindowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		settingswindowlist.Parent = settingschildren
		if modulesettings.Size or moduleapi.ApiCategory == 'Hud' then
			local modulechildren = Instance.new('Frame')
			modulechildren.Size = modulesettings.Size or UDim2.fromOffset(120, 28)
			modulechildren.BackgroundTransparency = 1
			modulechildren.Visible = false
			modulechildren.Parent = scaledgui
			makeDraggable(modulechildren, window)
			local objectstroke = Instance.new('UIStroke')
			objectstroke.Color = Color3.fromRGB(190, 115, 255)
			objectstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			objectstroke.Thickness = 0
			objectstroke.Parent = modulechildren
			moduleapi.Children = modulechildren
		end
		modulesettings.Function = modulesettings.Function or function() end
		addMaid(moduleapi)

		function moduleapi:Toggle()
			moduleapi.Enabled = not moduleapi.Enabled
			if moduleapi.Children then
				moduleapi.Children.Visible = moduleapi.Enabled
			end
			title.TextColor3 = moduleapi.Enabled and color.Light(uipallet.Text, 0.2) or color.Dark(uipallet.Text, 0.31)
			module.BackgroundColor3 = moduleapi.Enabled and color.Light(uipallet.Main, 0.05) or color.Light(uipallet.Main, 0.02)
			tween:Tween(knob, uipallet.Tween, {
				BackgroundColor3 = moduleapi.Enabled and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.14)
			})
			tween:Tween(knobmain, uipallet.Tween, {
				Position = UDim2.fromOffset(moduleapi.Enabled and 12 or 2, 2)
			})
			if not moduleapi.Enabled then
				for _, v in moduleapi.Connections do
					v:Disconnect()
				end
				table.clear(moduleapi.Connections)
			end
			task.spawn(modulesettings.Function, moduleapi.Enabled)
		end

		-- Legit HUD modules used to also register a mirror toggle in the main
		-- Overlays menu, which is why Legit modules showed up there. They now
		-- live exclusively in the Legit window.

		back.MouseEnter:Connect(function()
			back.ImageColor3 = uipallet.Text
		end)
		back.MouseLeave:Connect(function()
			back.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)
		back.MouseButton1Click:Connect(function()
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 1
			})
			tween:Tween(settingspane, uipallet.Tween, {
				Position = UDim2.fromScale(1, 0)
			})
			task.wait(0.2)
			shadow.Visible = false
		end)
		dotsbutton.MouseButton1Click:Connect(function()
			shadow.Visible = true
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 0.5
			})
			tween:Tween(settingspane, uipallet.Tween, {
				Position = UDim2.new(1, -220, 0, 0)
			})
		end)
		dotsbutton.MouseEnter:Connect(function()
			dots.ImageColor3 = uipallet.Text
		end)
		dotsbutton.MouseLeave:Connect(function()
			dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
		end)
		module.MouseEnter:Connect(function()
			if not moduleapi.Enabled then
				module.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
			end
		end)
		module.MouseLeave:Connect(function()
			if not moduleapi.Enabled then
				module.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end
		end)
		module.MouseButton1Click:Connect(function()
			moduleapi:Toggle()
		end)
		module.MouseButton2Click:Connect(function()
			shadow.Visible = true
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 0.5
			})
			tween:Tween(settingspane, uipallet.Tween, {
				Position = UDim2.new(1, -220, 0, 0)
			})
		end)
		shadow.MouseButton1Click:Connect(function()
			tween:Tween(shadow, uipallet.Tween, {
				BackgroundTransparency = 1
			})
			tween:Tween(settingspane, uipallet.Tween, {
				Position = UDim2.fromScale(1, 0)
			})
			task.wait(0.2)
			shadow.Visible = false
		end)
		settingswindowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			settingschildren.CanvasSize = UDim2.fromOffset(0, settingswindowlist.AbsoluteContentSize.Y / scale.Scale)
		end)

		for i, v in components do
			moduleapi['Create'..i] = function(_, optionsettings)
				return v(optionsettings, settingschildren, moduleapi)
			end
		end

		moduleapi.Object = module
		legitapi.Modules[modulesettings.Name] = moduleapi

		local sorting = {}
		for _, v in legitapi.Modules do
			table.insert(sorting, v.Name)
		end
		table.sort(sorting)

		for i, v in sorting do
			legitapi.Modules[v].Object.LayoutOrder = i
		end

		return moduleapi
	end
	mainapi:Clean(searchvalue:GetPropertyChangedSignal('Text'):Connect(updateCheck))

	local function visibleCheck()
		for _, v in legitapi.Modules do
			if v.Children then
				local visible = clickgui.Visible
				for _, v2 in self.Windows do
					visible = visible or v2.Visible
				end
				v.Children.Visible = (not visible or window.Visible) and v.Enabled
			end
		end
	end

	close.MouseButton1Click:Connect(function()
		window.Visible = false
		clickgui.Visible = true
	end)
	self:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(visibleCheck))
	window:GetPropertyChangedSignal('Visible'):Connect(function()
		self:UpdateGUI(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
		visibleCheck()
	end)
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
	end)

	self.Legit = legitapi

	legitapi:CreateCategory('All')
	legitapi:CreateCategory('Hud')
	legitapi:CreateCategory('Game')
	legitapi:CreateCategory('Visuals')

	return legitapi
end

function mainapi:CreateNotification(title, text, duration, type)
	if not self.Notifications.Enabled then return end
	local color = type == 'alert' and Color3.fromRGB(250, 50, 56) or type == 'warning' and Color3.fromRGB(236, 129, 43) or Color3.fromRGB(220, 220, 220)
	if license.Closet or license.Webhook then
		if license.Webhook then
			request({
				Url = license.Webhook,
				Method = 'POST',
				Headers = {
					['Content-Type'] = 'application/json'
				},
				Body = httpService:JSONEncode({
					content = '',
					embeds = {{
						title = title or "AetherV2",
						description = removeTags(text or "None"),
						color = tonumber(color:ToHex(), 16),
						timestamp = os.date('%Y-%m-%dT%X.000Z'),
						fields = {}
					}},
					components = {}
				})
			})
		end
		return
	end
	duration = (tonumber(duration) or 5) * math.max(nexus.Notify.Duration, 0.1)
	task.delay(0, function()
		if self.ThreadFix then
			setthreadidentity(8)
		end
		-- Enforce the configured stack limit by retiring the oldest slide-in.
		if nexus.Notify.Max > 0 and #notifications:GetChildren() >= nexus.Notify.Max then
			local oldest = notifications:GetChildren()[1]
			if oldest then
				oldest:Destroy()
			end
		end
		local i = #notifications:GetChildren() + 1
		-- Corner placement (Settings -> Notifications). Right corners park the
		-- toast just off the right edge and slide it in by tweening AnchorPoint
		-- 0 -> 1 (the original trick); left corners mirror it with 1 -> 0.
		local left = nexus.Notify.Position == 'Bottom Left' or nexus.Notify.Position == 'Top Left'
		local top = nexus.Notify.Position == 'Top Left' or nexus.Notify.Position == 'Top Right'
		local anchorIn = Vector2.new(left and 0 or 1, 0)
		local anchorOut = Vector2.new(left and 1 or 0, 0)
		local notification = Instance.new('ImageLabel')
		notification.Name = 'Notification'
		notification.Size = UDim2.fromOffset(math.max(getfontsize(removeTags(text), 14, uipallet.Font).X + 80, 266), 75)
		notification.AnchorPoint = anchorOut
		notification.Position = UDim2.new(left and 0 or 1, 0, top and 0 or 1, top and (46 + (78 * (i - 1))) or -(29 + (78 * i)))
		notification.ZIndex = 5
		notification.BackgroundTransparency = 1
		notification.Image = getcustomasset('aetherv2/assets/new/notification.png')
		notification.ScaleType = Enum.ScaleType.Slice
		notification.SliceCenter = Rect.new(7, 7, 9, 9)
		notification.Parent = notifications
		addBlur(notification, true)
		local iconshadow = Instance.new('ImageLabel')
		iconshadow.Name = 'Icon'
		iconshadow.Size = UDim2.fromOffset(60, 60)
		iconshadow.Position = UDim2.fromOffset(-5, -8)
		iconshadow.ZIndex = 5
		iconshadow.BackgroundTransparency = 1
		iconshadow.Image = getcustomasset('aetherv2/assets/new/'..(type or 'info')..'.png')
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
		titlelabel.Size = UDim2.new(1, -56, 0, 20)
		titlelabel.Position = UDim2.fromOffset(46, 16)
		titlelabel.ZIndex = 5
		titlelabel.BackgroundTransparency = 1
		titlelabel.Text = "<stroke color='#FFFFFF' joins='round' thickness='0.3' transparency='0.5'>"..title..'</stroke>'
		titlelabel.TextXAlignment = Enum.TextXAlignment.Left
		titlelabel.TextYAlignment = Enum.TextYAlignment.Top
		titlelabel.TextColor3 = Color3.fromRGB(209, 209, 209)
		titlelabel.TextSize = 14
		titlelabel.RichText = true
		titlelabel.FontFace = uipallet.FontSemiBold
		titlelabel.Parent = notification
		local textshadow = titlelabel:Clone()
		textshadow.Name = 'Text'
		textshadow.Position = UDim2.fromOffset(47, 44)
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
		progress.Position = UDim2.new(0, 3, 1, -4)
		progress.ZIndex = 5
		progress.BackgroundColor3 =
			color
		progress.BorderSizePixel = 0
		progress.Parent = notification
		if nexus.Notify.Sound then
			nexus.PlaySound('notify')
		end
		if tween.Tween then
			tween:Tween(notification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
				AnchorPoint = anchorIn
			}, tween.tweenstwo)
			tween:Tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Size = UDim2.fromOffset(0, 2)
			})
		end
		task.delay(duration, function()
			if tween.Tween then
				tween:Tween(notification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
					AnchorPoint = anchorOut
				}, tween.tweenstwo)
			end
			task.wait(0.2)
			notification:ClearAllChildren()
			notification:Destroy()
		end)
	end)
end

local guipane
function mainapi:Load(skipgui, profile)
	if not skipgui then
		self.GUIColor:SetValue(nil, nil, nil, accent.Notch)
	end
	local guidata = {}
	local savecheck = true

	-- Restoring a saved window position used to be unconditional, and that gave a category two
	-- ways to look like it "won't open":
	--   * Configs written before each category got its own lattice slot stored the SAME position
	--     for all of them, so every one restores stacked on the same spot and only the topmost is
	--     ever visible. Categories added after that config was written have no saved position, so
	--     they take a fresh slot and open normally - which is exactly the "only the new tabs open,
	--     the original ones don't" symptom.
	--   * A position saved on a larger monitor can restore completely off the current screen.
	-- So a saved position is only honoured when it is on-screen and not already taken; otherwise
	-- the category falls back to its own default slot.
	local usedPositions = {}
	local function restorePosition(object, pos)
		if not (object and object.Object) then return end
		local default = object.DefaultPosition
		if not pos or pos.X == nil or pos.Y == nil then
			if default then object.Object.Position = default end
			return
		end
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		local uiscale = (scale and scale.Scale or 1)
		uiscale = uiscale > 0 and uiscale or 1
		local maxX, maxY = (viewport.X / uiscale) - 60, (viewport.Y / uiscale) - 40
		local offscreen = pos.X < -40 or pos.Y < -40 or pos.X > maxX or pos.Y > maxY
		local key = pos.X..','..pos.Y
		if default and (usedPositions[key] or offscreen) then
			object.Object.Position = default
			usedPositions[default.X.Offset..','..default.Y.Offset] = true
			return
		end
		usedPositions[key] = true
		object.Object.Position = UDim2.fromOffset(pos.X, pos.Y)
	end

	if isfile('aetherv2/profiles/'..game.GameId..'.gui.txt') then
		guidata = loadJson('aetherv2/profiles/'..game.GameId..'.gui.txt')
		if not guidata then
			guidata = {Categories = {}}
			self:CreateNotification('AetherV2', 'Failed to load GUI settings, Try rejoining ur game', 10, 'alert')
			delfile('aetherv2/profiles/'..game.GameId..'.gui.txt')
			savecheck = false
		end

		if not skipgui then
			-- Older/imported gui.txt files may not carry a Keybind; keep the
			-- current bind instead of nilling it (SetBind(nil) errors and the
			-- GUI could never be reopened).
			self.Keybind = guidata.Keybind or self.Keybind
			for i, v in guidata.Categories do
				local object = self.Categories[i]
				if not object then continue end
				if object.Options and v.Options then
					self:LoadOptions(object, v.Options)
				end
				if v.Enabled then
					-- Not every persisted category is a window category.  Older themes
					-- wrote utility/category-list entries here too; those objects have no
					-- Button and used to abort the entire GUI load ("index nil Toggle").
					if object.Button and object.Button.Toggle then
						object.Button:Toggle()
					elseif object.Object then
						object.Object.Visible = true
					end
				end
				if v.Pinned and object.Pin then
					object:Pin()
				end
				if v.Expanded and object.Expand then
					object:Expand()
				end
				if v.List and object.List and (#object.List > 0 or #v.List > 0) and object.ChangeValue then
					object.List = v.List or {}
					object.ListEnabled = v.ListEnabled or {}
					object:ChangeValue()
				end
				restorePosition(object, v.Position)
			end
		end
	end

	self.Profile = profile or guidata.Profile or 'default'
	self.Profiles = guidata.Profiles or {{
		Name = 'default', Bind = {}
	}}
	refreshConfigProfiles()
	self.Categories.Profiles:ChangeValue()
	if self.ProfileLabel then
		self.ProfileLabel.Text = #self.Profile > 10 and self.Profile:sub(1, 10)..'...' or self.Profile
		self.ProfileLabel.Size = UDim2.fromOffset(getfontsize(self.ProfileLabel.Text, self.ProfileLabel.TextSize, self.ProfileLabel.Font).X + 16, 24)
	end

	local configPath = getConfigPath(self.Profile)
	local legacyConfigPath = getLegacyProfilePath(self.Profile)
	if not isfile(configPath) and isfile(legacyConfigPath) then
		configPath = legacyConfigPath
	end

	if isfile(configPath) then
		local savedata = loadJson(configPath)
		if not savedata then
			savedata = {Categories = {}, Modules = {}, Legit = {}}
			self:CreateNotification('AetherV2', 'Failed to load '..self.Profile..' profile.', 10, 'alert')
			savecheck = false
		end

		savedata.Categories = savedata.Categories or {}
		savedata.Modules = savedata.Modules or {}
		savedata.Legit = savedata.Legit or {}

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
			-- Guarded: an entry written without a Position (an older or imported config) used to
			-- throw here and abort the rest of the config load.
			restorePosition(object, v.Position)
		end

		-- Snapshot the table first: a game module can still be registering itself on another
		-- thread while this runs (the loader stops waiting on one that stalls), and adding to
		-- the table mid-iteration would throw here and abort the whole config load.
		local modulesSnapshot = table.clone(self.Modules)
		for i, object in modulesSnapshot do
			local v = savedata.Modules[i]
			if not v then
				if object.Enabled then
					if skipgui and self.ToggleNotifications.Enabled then self:CreateNotification('Module Toggled', i.."<font color='#FFFFFF'> has been </font><font color='#FF5A5A'>Disabled</font><font color='#FFFFFF'>!</font>", 0.75) end
					object:Toggle(true)
				end
				continue
			end
			if object.Options and v.Options then
				self:LoadOptions(object, v.Options)
			end
			if (v.Enabled or false) ~= object.Enabled then
				if skipgui then
					if self.ToggleNotifications.Enabled then self:CreateNotification('Module Toggled', i.."<font color='#FFFFFF'> has been </font>"..(v.Enabled and "<font color='#5AFF5A'>Enabled</font>" or "<font color='#FF5A5A'>Disabled</font>").."<font color='#FFFFFF'>!</font>", 0.75) end
				end
				object:Toggle(true)
			end
			object:SetBind(v.Bind or {})
			object.Object.Bind.Visible = #(v.Bind or {}) > 0
			if object.SetFavourite then
				object:SetFavourite(v.Favourited, true)
			end
		end
		-- Reinstate the saved order of the Favourites tab now that every module's
		-- Favourited state has been applied (older configs simply have no order).
		if self.Favourites and savedata.FavouritesOrder then
			self.Favourites:ApplyOrder(savedata.FavouritesOrder)
		end
		-- Snapshot the table first: a game module can still be registering itself on another
		-- thread while this runs (the loader stops waiting on one that stalls), and adding to
		-- the table mid-iteration would throw here and abort the whole config load.
		local legitSnapshot = table.clone(self.Legit.Modules)
		for i, object in legitSnapshot do
			-- Visuals modules used to be registered in a category tab, so a config written
			-- before they moved has their settings under Modules. Read that once; the next
			-- save writes them into the Legit section.
			local v = savedata.Legit[i] or savedata.Modules[i]
			if not v then
				if object.Enabled then
					object:Toggle()
				end
				continue
			end
			if object.Options and v.Options then
				self:LoadOptions(object, v.Options)
			end
			if object.Enabled ~= (v.Enabled or false) then
				object:Toggle()
			end
			if v.Position and object.Children then
				object.Children.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
			end
		end

		-- Keybinds and GUI colour saved with this config take precedence over the shared gui file,
		-- so each config carries its own menu key and accent, applied even on a plain config switch
		-- (skipgui), which deliberately never touches the shared gui settings.
		if savedata.Keybind then
			self.Keybind = savedata.Keybind
		end
		if self.GUIColor and self.GUIColor.Load then
			pcall(function()
				if savedata.GUIColor then
					self.GUIColor:Load(savedata.GUIColor)
				else
					-- A config that carries no accent of its own gets the default one, not
					-- whatever the config before it happened to leave behind. Without this a
					-- profile switch (which never touches the shared gui settings) kept the
					-- previous config's colour and made the default look like it had moved.
					self.GUIColor:SetValue(nil, nil, nil, accent.Notch)
				end
				self:UpdateGUI(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
			end)
		end

		self:UpdateTextGUI(true)
	else
		local previousLoaded = self.Loaded
		self.Loaded = true
		self:Save()
		self.Loaded = previousLoaded
	end

	if self.Downloader then
		self.Downloader:Destroy()
		self.Downloader = nil
	end
	self.Loaded = savecheck
	self.Categories.Main.Options.Bind:SetBind(self.Keybind)
	-- The colours this pass brought forward are only on disk once the config is written
	-- back, so record the migration after a save rather than as the values are read.
	if savecheck and not configapi.Accents.Done then
		self:Save()
		configapi.Accents.Mark()
	end

	if not inputService.KeyboardEnabled or shared.VapeDeveloper then
		local hide = isfile('aetherv2/profiles/hide.txt') and readfile('aetherv2/profiles/hide.txt') or nil
		if hide ~= nil then
			hide = hide == 'true' and true or false
		end
		local button = Instance.new('TextButton')
		button.LayoutOrder = -1
		button.Size = UDim2.fromOffset(32, 32)
		button.Position = UDim2.new(1, -90, 0, 4)
		button.BackgroundColor3 = Color3.new()
		button.BackgroundTransparency = hide and 1 or 0.35
		button.Text = ''
		button.Parent = game.GameId == 2619619496 and cloneref(game:GetService('Players')).LocalPlayer.PlayerGui.TopBarAppGui.TopBarApp or gui
		local image = Instance.new('ImageLabel')
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Size = UDim2.fromOffset(22, 22)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = getcustomasset('aetherv2/assets/new/vape.png')
		image.ImageTransparency = hide and 1 or 0
		image.Parent = button
		local buttoncorner = Instance.new('UICorner')
		buttoncorner.Parent = button
		self.VapeButton = button
		mainapi:Clean(button)
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

		if guipane then
			guipane:CreateToggle({
				Name = 'Hide AetherV2 button',
				Default = hide or false,
				Function = function(call)
					button.BackgroundTransparency = call and 1 or 0.35
					image.ImageTransparency = call and 1 or 0
					writefile('aetherv2/profiles/hide.txt', tostring(call))
				end
			})
		end
	end
end

function mainapi:LoadOptions(object, savedoptions)
	for i, v in savedoptions do
		local option = object.Options[i]
		if not option then continue end
		option:Load(v)
	end
end

-- `modulesonly` is passed by the two CreateModule paths, which open by clearing anything already
-- registered under the new module's name. Without it the lookup fell through to the category
-- table, so a module that happened to share a tab's name tore that whole tab down - window,
-- sidebar button and all - the moment it registered.
function mainapi:Remove(obj, modulesonly)
	local tab = self.Modules[obj] and self.Modules
		or self.Legit.Modules[obj] and self.Legit.Modules
		or (not modulesonly and self.Categories)
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
		-- Drop any Favourites-tab proxy that mirrored the removed module.
		if self.RefreshFavourites then
			task.defer(self.RefreshFavourites)
		end
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

	-- Keybinds and the GUI accent travel WITH the config now, not only in the shared gui file, so
	-- switching or importing a config restores the menu key and colour it was saved with.
	savedata.Keybind = self.Keybind
	if self.GUIColor then
		savedata.GUIColor = {
			Hue = self.GUIColor.Hue,
			Sat = self.GUIColor.Sat,
			Value = self.GUIColor.Value,
			Notch = self.GUIColor.Notch,
			CustomColor = self.GUIColor.CustomColor,
			Rainbow = self.GUIColor.Rainbow
		}
	end

	for i, v in self.Categories do
		(v.Type ~= 'Category' and i ~= 'Main' and savedata or guidata).Categories[i] = {
			Enabled = i ~= 'Main' and v.Button and v.Button.Enabled or nil,
			Expanded = v.Type ~= 'Overlay' and v.Expanded or nil,
			Pinned = v.Pinned,
			Position = v.Object and {X = v.Object.Position.X.Offset, Y = v.Object.Position.Y.Offset} or nil,
			Options = mainapi:SaveOptions(v, v.Options),
			List = v.List,
			ListEnabled = v.ListEnabled
		}
	end

	for i, v in self.Modules do
		savedata.Modules[i] = {
			Enabled = v.Enabled,
			Favourited = v.Favourited,
			Bind = v.Bind.Button and {Mobile = true, X = v.Bind.Button.Position.X.Offset, Y = v.Bind.Button.Position.Y.Offset} or v.Bind,
			Options = mainapi:SaveOptions(v, true)
		}
	end
	-- Persist the Favourites-tab ordering alongside the per-module flags so the
	-- pinned order the user arranged survives a rejoin.
	savedata.FavouritesOrder = self.Favourites and self.Favourites:GetOrder() or nil

	for i, v in self.Legit.Modules do
		savedata.Legit[i] = {
			Enabled = v.Enabled,
			Position = v.Children and {X = v.Children.Position.X.Offset, Y = v.Children.Position.Y.Offset} or nil,
			Options = mainapi:SaveOptions(v, v.Options)
		}
	end

	ensureDataFolders()
	writefile('aetherv2/profiles/'..game.GameId..'.gui.txt', httpService:JSONEncode(guidata))
	writefile(getConfigPath(self.Profile), httpService:JSONEncode(savedata))
	-- Keep the legacy profile mirror current so changing GUI implementations cannot
	-- resurrect an older, partially saved copy of this profile.
	writefile(getLegacyProfilePath(self.Profile), httpService:JSONEncode(savedata))
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

function mainapi:Uninject()
	-- Hardened teardown. Every step is wrapped so a single erroring module/toggle
	-- can never abort the uninject partway and leave a half-alive GUI behind -
	-- that was why "Self destruct" (and re-injecting, which uninjects the old
	-- instance first) sometimes did nothing. The GUI is always destroyed and the
	-- shared handles always cleared, whatever any individual step does.
	pcall(function() mainapi:Save() end)
	mainapi.Loaded = nil
	for _, v in self.Modules do
		if v.Enabled then
			pcall(function() v:Toggle() end)
		end
	end
	for _, v in self.Legit.Modules do
		if v.Enabled then
			pcall(function() v:Toggle() end)
		end
	end
	for _, v in self.Categories do
		if v.Type == 'Overlay' and v.Button.Enabled then
			pcall(function() v.Button:Toggle() end)
		end
	end
	for _, v in mainapi.Connections do
		pcall(function()
			v:Disconnect()
		end)
	end
	if mainapi.ThreadFix then
		pcall(function()
			setthreadidentity(8)
			clickgui.Visible = false
			mainapi:BlurCheck()
		end)
	end
	pcall(function() mainapi.gui:ClearAllChildren() end)
	pcall(function() mainapi.gui:Destroy() end)
	pcall(function() table.clear(mainapi.Libraries) end)
	pcall(function() loopClean(mainapi) end)
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
if false then
	gui.Parent = cloneref(game:GetService('CoreGui'))--(gethui and gethui()) or cloneref(game:GetService('CoreGui'))
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
local scarcitybanner = Instance.new('TextLabel')
scarcitybanner.Size = UDim2.fromScale(1, 0.02)
scarcitybanner.Position = UDim2.fromScale(0, 0.97)
scarcitybanner.BackgroundTransparency = 1
scarcitybanner.Text = 'Thank you for choosing AetherV2! Join https://discord.gg/aYu5c9v9zv or click the Discord button to join.'
scarcitybanner.TextScaled = true
scarcitybanner.TextColor3 = Color3.new(1, 1, 1)
scarcitybanner.TextStrokeTransparency = 0.5
scarcitybanner.FontFace = uipallet.Font
scarcitybanner.Parent = clickgui
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
tooltip.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
tooltip.Visible = false
tooltip.Text = ''
tooltip.TextColor3 = color.Dark(uipallet.Text, 0.16)
tooltip.TextSize = 12
tooltip.FontFace = uipallet.Font
tooltip.Parent = scaledgui
toolblur = addBlur(tooltip)
addCorner(tooltip)
local toolstrokebkg = Instance.new('Frame')
toolstrokebkg.Size = UDim2.new(1, -2, 1, -2)
toolstrokebkg.Position = UDim2.fromOffset(1, 1)
toolstrokebkg.ZIndex = 6
toolstrokebkg.BackgroundTransparency = 1
toolstrokebkg.Parent = tooltip
local toolstroke = Instance.new('UIStroke')
toolstroke.Color = color.Light(uipallet.Main, 0.02)
toolstroke.Parent = toolstrokebkg
addCorner(toolstrokebkg, UDim.new(0, 4))
scale = Instance.new('UIScale')
scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
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

mainapi:CreateGUI()
mainapi.Categories.Main:CreateDivider()
mainapi:CreateCategory({
	Name = 'Combat',
	Icon = getcustomasset('aetherv2/assets/new/combaticon.png'),
	Size = UDim2.fromOffset(13, 14)
})
mainapi:CreateCategory({
	Name = 'Blatant',
	Icon = getcustomasset('aetherv2/assets/new/blatanticon.png'),
	Size = UDim2.fromOffset(14, 14)
})
-- Exploits: game-specific exploit modules (kit exploits, disablers). Uses the Blatant
-- icon for now until a dedicated asset is made.
mainapi:CreateCategory({
	Name = 'Exploits',
	Icon = getcustomasset('aetherv2/assets/new/blatanticon.png'),
	Size = UDim2.fromOffset(14, 14)
})
mainapi:CreateCategory({
	Name = 'Render',
	Icon = getcustomasset('aetherv2/assets/new/rendericon.png'),
	Size = UDim2.fromOffset(15, 14)
})
-- The 'Legit' category is intentionally NOT created as a tab any more. All Legit
-- modules now live in the dedicated window opened by the icon next to the search
-- bar (see the Categories.Legit alias set right after mainapi:CreateLegit()).
mainapi:CreateCategory({
	Name = 'Utility',
	Icon = getcustomasset('aetherv2/assets/new/utilityicon.png'),
	Size = UDim2.fromOffset(15, 14)
})
mainapi:CreateCategory({
	Name = 'World',
	Icon = getcustomasset('aetherv2/assets/new/worldicon.png'),
	Size = UDim2.fromOffset(14, 14)
})
mainapi:CreateCategory({
	Name = 'Inventory',
	Icon = getcustomasset('aetherv2/assets/new/inventoryicon.png'),
	Size = UDim2.fromOffset(15, 14)
})
mainapi:CreateCategory({
	Name = 'Minigames',
	Icon = getcustomasset('aetherv2/assets/new/miniicon.png'),
	Size = UDim2.fromOffset(19, 12)
})

--[[
	Favourites (rebuilt from scratch)

	Everything favourite-related routes through one controller stored at
	mainapi.Favourites. A module's star click / config load calls
	moduleapi:SetFavourite, which flips that module's own visuals and hands the
	shared bookkeeping to this controller:

	  * Order  - names of favourited modules in the order they were starred, so
	             the tab is stable and user-controlled rather than alphabetical.
	             Persisted per profile as savedata.FavouritesOrder.
	  * Rows   - one live proxy row per favourite. Each mirrors its source module
	             button (enabled colour, hover) through property signals; left
	             click toggles the real module, right click un-pins it.
	  * Header - a live "n" count beside the tab title, plus an empty-state hint.

	controller:Refresh rebuilds the tab and is safe to call anytime. It is driven
	by SetFavourite, by mainapi:Remove (module teardown) and by a config load,
	all via the mainapi.RefreshFavourites alias.
]]
do
	local favGold = Color3.fromRGB(255, 200, 60)
	local favCategory = mainapi:CreateCategory({
		Name = 'Favourites',
		Icon = getcustomasset('aetherv2/assets/new/allowedicon.png'),
		Size = UDim2.fromOffset(15, 14)
	})
	local favChildren = favCategory.Object.Children

	local controller = {
		Order = {}, -- array<string>: favourited module names, insertion order
		Rows = {}   -- [name] = {Object = TextButton, Connections = {RBXScriptConnection}}
	}
	mainapi.Favourites = controller

	-- Header row: a subtle section label with a live gold count on the right.
	local header = Instance.new('Frame')
	header.Name = 'Header'
	header.LayoutOrder = -1
	header.Size = UDim2.fromOffset(220, 32)
	header.BackgroundTransparency = 1
	header.Parent = favChildren
	local headerTitle = Instance.new('TextLabel')
	headerTitle.Name = 'Title'
	headerTitle.Size = UDim2.new(1, -24, 1, 0)
	headerTitle.Position = UDim2.fromOffset(14, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Text = 'PINNED'
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.TextColor3 = color.Dark(uipallet.Text, 0.30)
	headerTitle.TextSize = 12
	headerTitle.FontFace = uipallet.Font
	headerTitle.Parent = header
	local headerCount = Instance.new('TextLabel')
	headerCount.Name = 'Count'
	headerCount.Size = UDim2.new(1, -24, 1, 0)
	headerCount.Position = UDim2.fromOffset(10, 0)
	headerCount.BackgroundTransparency = 1
	headerCount.Text = '0'
	headerCount.TextXAlignment = Enum.TextXAlignment.Right
	headerCount.TextColor3 = favGold
	headerCount.TextSize = 12
	headerCount.FontFace = uipallet.Font
	headerCount.Parent = header

	local emptyLabel = Instance.new('TextLabel')
	emptyLabel.Name = 'Empty'
	emptyLabel.Size = UDim2.fromOffset(220, 46)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = 'Star a module to pin it here'
	emptyLabel.TextColor3 = color.Dark(uipallet.Text, 0.43)
	emptyLabel.TextSize = 12
	emptyLabel.FontFace = uipallet.Font
	emptyLabel.Parent = favChildren

	local function indexOf(name)
		for i, v in controller.Order do
			if v == name then return i end
		end
	end

	local function destroyRow(name)
		local row = controller.Rows[name]
		if not row then return end
		controller.Rows[name] = nil
		for _, connection in row.Connections do
			connection:Disconnect()
		end
		row.Object:Destroy()
	end

	local function buildRow(module)
		local source = module.Object
		if not source then return end
		local row = Instance.new('TextButton')
		row.Name = module.Name
		row.Size = UDim2.fromOffset(220, 40)
		row.BackgroundColor3 = source.BackgroundColor3
		row.BackgroundTransparency = source.BackgroundTransparency
		row.BorderSizePixel = 0
		row.AutoButtonColor = false
		row.Text = '            '..module.Name
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = source.TextColor3
		row.TextSize = 14
		row.FontFace = uipallet.Font
		row.Parent = favChildren
		addTooltip(row, module.Category..' • left-click toggles, right-click unpins')
		-- Every row on this tab is, by definition, a favourite - so give each the
		-- same gold trim the starred module carries in its own category, keeping
		-- the favourite styling consistent wherever the module shows up.
		local rowstroke = Instance.new('UIStroke')
		rowstroke.Name = 'FavouriteBorder'
		rowstroke.Color = favGold
		rowstroke.Thickness = 1.6
		rowstroke.Transparency = 0.1
		rowstroke.LineJoinMode = Enum.LineJoinMode.Round
		rowstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rowstroke.Parent = row
		local rowsheen = Instance.new('UIGradient')
		rowsheen.Rotation = 90
		rowsheen.Color = ColorSequence.new(favGold, Color3.fromRGB(214, 148, 34))
		rowsheen.Parent = rowstroke

		local tag = Instance.new('TextLabel')
		tag.Name = 'Category'
		tag.Size = UDim2.fromOffset(90, 40)
		tag.Position = UDim2.new(1, -100, 0, 0)
		tag.BackgroundTransparency = 1
		tag.Text = module.Category
		tag.TextXAlignment = Enum.TextXAlignment.Right
		tag.TextColor3 = color.Dark(uipallet.Text, 0.43)
		tag.TextSize = 10
		tag.FontFace = uipallet.Font
		tag.Parent = row

		local connections = {
			source:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
				row.BackgroundColor3 = source.BackgroundColor3
			end),
			source:GetPropertyChangedSignal('TextColor3'):Connect(function()
				row.TextColor3 = source.TextColor3
			end),
			source:GetPropertyChangedSignal('BackgroundTransparency'):Connect(function()
				row.BackgroundTransparency = source.BackgroundTransparency
			end),
			row.MouseButton1Click:Connect(function()
				if mainapi.PushUndo then mainapi:PushUndo(module) end
				module:Toggle()
			end),
			row.MouseButton2Click:Connect(function()
				module:SetFavourite(false)
			end)
		}
		controller.Rows[module.Name] = {Object = row, Connections = connections}
	end

	-- Add/Remove only touch the ordered list; the actual UI rebuild is deferred
	-- and coalesced by SetFavourite so a whole config load rebuilds once.
	function controller:Add(module)
		if not indexOf(module.Name) then
			table.insert(self.Order, module.Name)
		end
	end

	function controller:Remove(name)
		local i = indexOf(name)
		if i then
			table.remove(self.Order, i)
		end
	end

	-- The live favourite order, pruned to modules that still exist and are still
	-- favourited. Persisted so the tab order survives a rejoin.
	function controller:GetOrder()
		local order = {}
		for _, name in self.Order do
			local module = mainapi.Modules[name]
			if module and module.Favourited then
				table.insert(order, name)
			end
		end
		return order
	end

	-- Restore a saved order, then append any favourited modules the saved list
	-- didn't mention (added in a newer build, or by a plugin). Old configs with
	-- no saved order simply keep whatever order the load produced.
	function controller:ApplyOrder(order)
		if type(order) ~= 'table' then return end
		local seen = {}
		local rebuilt = {}
		local function push(name)
			local module = mainapi.Modules[name]
			if module and module.Favourited and not seen[name] then
				seen[name] = true
				table.insert(rebuilt, name)
			end
		end
		for _, name in order do
			push(name)
		end
		for _, name in self.Order do
			push(name)
		end
		self.Order = rebuilt
		self:Refresh()
	end

	function controller:Refresh()
		-- Drop order entries for modules that vanished or were unfavourited.
		for i = #self.Order, 1, -1 do
			local module = mainapi.Modules[self.Order[i]]
			if not module or not module.Favourited then
				table.remove(self.Order, i)
			end
		end
		-- Self-heal: adopt any module flagged Favourited outside SetFavourite
		-- (e.g. a plugin) so the tab never silently misses one.
		for name, module in mainapi.Modules do
			if module.Favourited and not indexOf(name) then
				table.insert(self.Order, name)
			end
		end
		-- Tear down rows no longer in the order.
		for name in self.Rows do
			if not indexOf(name) then
				destroyRow(name)
			end
		end
		-- Ensure a row per ordered favourite and lay them out in order.
		for order, name in self.Order do
			local module = mainapi.Modules[name]
			if module then
				if not self.Rows[name] then
					buildRow(module)
				end
				if self.Rows[name] then
					self.Rows[name].Object.LayoutOrder = order
				end
			end
		end
		headerCount.Text = tostring(#self.Order)
		emptyLabel.Visible = #self.Order == 0
	end

	-- Back-compat entry point used by mainapi:Remove and the config loader.
	mainapi.RefreshFavourites = function()
		controller:Refresh()
	end

	controller:Refresh()
end

mainapi.Categories.Main:CreateDivider('misc')

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
	Icon = getcustomasset('aetherv2/assets/new/friendstab.png'),
	Size = UDim2.fromOffset(17, 16),
	Placeholder = 'Roblox username',
	Color = Color3.fromRGB(190, 115, 255),
	Function = function()
		friends.Update:Fire()
		friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
	end
}
friends = mainapi:CreateCategoryList(friendssettings)
friends.Update = Instance.new('BindableEvent')
friends.ColorUpdate = Instance.new('BindableEvent')
friends:CreateToggle({
	Name = 'Recolor visuals',
	Darker = true,
	Default = true,
	Function = function()
		friends.Update:Fire()
		friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
	end
})
friendscolor = friends:CreateColorSlider({
	Name = 'Friends color',
	Darker = true,
	Function = function(hue, sat, val)
		for _, v in friends.Object.Children:GetChildren() do
			local dot = v:FindFirstChild('Dot')
			if dot and dot.BackgroundColor3 ~= color.Light(uipallet.Main, 0.37) then
				dot.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				dot.Dot.BackgroundColor3 = dot.BackgroundColor3
			end
		end
		friendssettings.Color = Color3.fromHSV(hue, sat, val)
		friends.ColorUpdate:Fire(hue, sat, val)
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
	Configs
]]
local profiles = mainapi:CreateCategoryList({
	Name = 'Profiles',
	DisplayName = 'Configs',
	Icon = getcustomasset('aetherv2/assets/new/profilesicon.png'),
	Size = UDim2.fromOffset(17, 10),
	Position = UDim2.fromOffset(12, 16),
	Placeholder = 'Type name',
	Profiles = true
})

local importNameBox
local importJsonBox = profiles:CreateTextBox({
	Name = 'Import JSON',
	Placeholder = 'Paste exported JSON here',
	Tooltip = 'Paste a JSON export, then click Import JSON to create a new config'
})
importNameBox = profiles:CreateTextBox({
	Name = 'Import Name',
	Placeholder = 'Optional config name',
	Tooltip = 'Optional name for the imported config. Invalid file characters are replaced automatically'
})
profiles:CreateButton({
	Name = 'Import JSON',
	Function = function()
		local text = importJsonBox.Value
		if (not text or text:gsub('%s+', '') == '') and getclipboard then
			local suc, clipboard = pcall(getclipboard)
			if suc then text = clipboard end
		end
		local suc, result = importJsonConfig(text, importNameBox.Value ~= '' and importNameBox.Value or nil)
		if suc then
			importJsonBox:SetValue('', false)
			importNameBox:SetValue('', false)
			profiles:ChangeValue()
			mainapi:CreateNotification('AetherV2', 'Imported config '..result..'.', 5, 'info')
		else
			mainapi:CreateNotification('AetherV2', result, 8, 'alert')
		end
	end,
	Tooltip = 'Imports a JSON config from the text box, or from your clipboard if the text box is empty'
})

--[[
	Targets
]]
local targets
targets = mainapi:CreateCategoryList({
	Name = 'Targets',
	Icon = getcustomasset('aetherv2/assets/new/friendstab.png'),
	Size = UDim2.fromOffset(17, 16),
	Placeholder = 'Roblox username',
	Function = function()
		targets.Update:Fire()
	end
})
targets.Update = Instance.new('BindableEvent')
mainapi:Clean(targets.Update)

mainapi:CreateLegit()
-- Route every `vape.Categories.Legit:CreateModule` registration into the Legit
-- window (opened via the search-bar icon) instead of a category tab. Using __index
-- (rather than a real key) keeps all Legit modules working while ensuring the Legit
-- api never shows up when the code iterates mainapi.Categories for real tabs.
-- Visuals is no longer a tab of its own. Its modules are render/HUD work, so they
-- belong beside the rest of it in the Legit window, under a Visuals tab there. This
-- proxy keeps every `vape.Categories.Visuals:CreateModule` call in the game modules
-- working untouched - it just pre-selects the tab and hands the call to the panel.
local visualsproxy
local function visualsCategory()
	visualsproxy = visualsproxy or setmetatable({
		CreateModule = function(_, modulesettings)
			modulesettings.Category = modulesettings.Category or 'Visuals'
			return mainapi.Legit:CreateModule(modulesettings)
		end
	}, {__index = mainapi.Legit})
	return visualsproxy
end
setmetatable(mainapi.Categories, {
	__index = function(_, key)
		if key == 'Legit' then
			return mainapi.Legit
		elseif key == 'Visuals' then
			return visualsCategory()
		end
	end
})
mainapi:CreateSearch()
mainapi.Categories.Main:CreateOverlayBar()
mainapi.Categories.Main:CreateSettingsDivider()
mainapi:CreateWelcome()


--[[
	General Settings
]]

local general = mainapi.Categories.Main:CreateSettingsPane({Name = 'General'})
mainapi.MultiKeybind = general:CreateToggle({
	Name = 'Enable Multi-Keybinding',
	Tooltip = 'Allows multiple keys to be bound to a module (eg. G + H)'
})
general:CreateToggle({
	Name = 'Disable Loading Screen',
	Function = function(callback)
		if not isfolder('aetherv2/profiles') then
			makefolder('aetherv2/profiles')
		end
		writefile('aetherv2/profiles/disableloading.txt', callback and 'true' or 'false')
		if callback and _G.AetherV2CloseLoadingScreen then
			pcall(_G.AetherV2CloseLoadingScreen)
		end
	end,
	Default = isfile('aetherv2/profiles/disableloading.txt') and readfile('aetherv2/profiles/disableloading.txt') == 'true',
	Tooltip = 'Prevents AetherV2 from showing its startup loading screen'
})
-- Reloads AetherV2 from scratch (shared by Reinject, Reset profile and the GUI
-- type switcher). Deferred onto a fresh thread so the button/dropdown handler
-- that triggered it returns BEFORE main.lua tears this instance down. Running the
-- teardown re-entrantly - inside a handler that lives on the very GUI being
-- destroyed - was unreliable and was a big part of why reinjecting and switching
-- GUI types "did nothing".
local function reloadAether()
	task.spawn(function()
		shared.vapereload = true
		local ok, err = pcall(function()
			if shared.VapeDeveloper then
				loadstring(readfile('aetherv2/main.lua'), 'main')(license)
			else
				loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/main.lua', true), 'main')(license)
			end
		end)
		if not ok then
			warn('[AetherV2] reload failed:', err)
		end
	end)
end

general:CreateButton({
	Name = 'Reset current profile',
	Function = function()
		configapi.ResetProfile()
		reloadAether()
	end,
	Tooltip = 'Wipes everything saved for this config and reloads on defaults'
})
-- Metadata for JSON exports. The Export to JSON button below refuses to copy until
-- credits, at least one tag and a description have all been supplied, so shared
-- configs always carry attribution and context.
local exportCredits = general:CreateTextBox({
	Name = 'Export Credits',
	Placeholder = 'Your username',
	Default = (function()
		local suc, res = pcall(function()
			return cloneref(game:GetService('Players')).LocalPlayer.Name
		end)
		return suc and res or ''
	end)(),
	Tooltip = 'Who made this config. Added to the JSON export as "credits"'
})
local exportTags = general:CreateTextBox({
	Name = 'Export Tags',
	Placeholder = 'pvp, rage, legit',
	Tooltip = 'Comma-separated tags for the export. At least one is required'
})
local exportDescription = general:CreateTextBox({
	Name = 'Export Description',
	Placeholder = 'Short description',
	Tooltip = 'A short description added to the JSON export as "description"'
})
local exportButton
exportButton = general:CreateButton({
	Name = 'Export to JSON',
	Function = function()
		-- Split the tags box on commas, trimming blanks so "pvp, , rage," becomes
		-- {"pvp", "rage"}.
		local tags = {}
		for tag in tostring(exportTags.Value):gmatch('[^,]+') do
			tag = tag:gsub('^%s+', ''):gsub('%s+$', '')
			if tag ~= '' then table.insert(tags, tag) end
		end
		local credits = tostring(exportCredits.Value):gsub('^%s+', ''):gsub('%s+$', '')
		local description = tostring(exportDescription.Value):gsub('^%s+', ''):gsub('%s+$', '')
		-- Ask for everything before copying: bail with a clear notification rather
		-- than exporting an anonymous, unlabelled config.
		if credits == '' or #tags == 0 or description == '' then
			mainapi:CreateNotification('AetherV2', 'Fill in credits, at least one tag and a description before exporting.', 6, 'alert')
			return
		end

		local tab = {}
		if isfile(getConfigPath(mainapi.Profile)) then
			tab.config = readfile(getConfigPath(mainapi.Profile))
		end
		if isfile('aetherv2/profiles/'..game.GameId..'.gui.txt') then
			tab.gui = readfile('aetherv2/profiles/'..game.GameId..'.gui.txt')
		end
		tab.game = tostring(mainapi.Place or 'universal'.. game.PlaceId)
		tab.credits = credits
		tab.tags = tags
		tab.description = description
		setclipboard(httpService:JSONEncode(tab))

		-- Subtle "copied" confirmation: briefly swap the button label to "Copied!"
		-- then restore it, so there is clear feedback without a disruptive popup.
		if exportButton and exportButton.Label then
			local label = exportButton.Label
			local original = label.Text
			label.Text = 'Copied!'
			task.delay(1.25, function()
				if label and label.Text == 'Copied!' then
					label.Text = original
				end
			end)
		end
	end,
	Tooltip = 'Copies your config to the clipboard as JSON, including credits, tags and a description'
})
general:CreateButton({
	Name = 'Self destruct',
	Function = function()
		-- Deferred so this click handler (which lives on the GUI Uninject
		-- destroys) returns before the teardown runs.
		task.spawn(function()
			mainapi:Uninject()
		end)
	end,
	Tooltip = 'Removes vape from the current game'
})
general:CreateButton({
	Name = 'Reinject',
	Function = function()
		reloadAether()
	end,
	Tooltip = 'Reloads vape for debugging purposes'
})

--[[
	Module Settings
]]

local modules = mainapi.Categories.Main:CreateSettingsPane({Name = 'Modules'})
modules:CreateToggle({
	Name = 'Teams by server',
	Tooltip = 'Ignore players on your team designated by the server',
	Default = true,
	Function = function()
		if mainapi.Libraries.entity and mainapi.Libraries.entity.Running then
			mainapi.Libraries.entity.refresh()
		end
	end
})
modules:CreateToggle({
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

guipane = mainapi.Categories.Main:CreateSettingsPane({Name = 'GUI'})
mainapi.Blur = guipane:CreateToggle({
	Name = 'Blur background',
	Function = function()
		mainapi:BlurCheck()
	end,
	Default = true,
	Tooltip = 'Blur the background of the GUI'
})
guipane:CreateToggle({
	Name = 'GUI bind indicator',
	Default = true,
	Tooltip = "Displays a message indicating your GUI upon injecting\nI.E. 'Press RSHIFT to open GUI'"
})
guipane:CreateToggle({
	Name = 'No module spacing',
	Tooltip = 'Removes module\'s text spacing',
	Function = function(callback)
		for _, v in mainapi.Modules do
			v.Object.Text = '            '..(callback and v.Name:gsub(' ', '') or v.Name)
		end
	end
})
guipane:CreateToggle({
	Name = 'Show tooltips',
	Function = function(enabled)
		tooltip.Visible = false
		toolblur.Visible = enabled
	end,
	Default = true,
	Tooltip = 'Toggles visibility of these'
})
guipane:CreateToggle({
	Name = 'Show legit mode',
	Function = function(enabled)
		clickgui.Search.Legit.Visible = enabled
		clickgui.Search.LegitDivider.Visible = enabled
		clickgui.Search.TextBox.Size = UDim2.new(1, enabled and -50 or -10, 0, 37)
		clickgui.Search.TextBox.Position = UDim2.fromOffset(enabled and 50 or 10, 0)
	end,
	Default = true,
	Tooltip = 'Shows the button to change to Legit Mode'
})
local scaleslider = {Object = {}, Value = 1}
mainapi.Scale = guipane:CreateToggle({
	Name = 'Auto rescale',
	Default = true,
	Function = function(callback)
		scaleslider.Object.Visible = not callback
		if callback then
			scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.45)
		else
			scale.Scale = scaleslider.Value
		end
	end,
	Tooltip = 'Automatically rescales the gui using the screens resolution'
})
scaleslider = guipane:CreateSlider({
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
guipane:CreateDropdown({
	Name = 'GUI Theme',
	List = inputService.TouchEnabled and {'newer', 'new', 'old'} or {'newer', 'new', 'old', 'rise'},
	Function = function(val, mouse)
		if mouse then
			-- Only act on a genuine change - re-picking the current GUI should not
			-- pointlessly tear everything down and reload.
			local current = (isfile('aetherv2/profiles/gui.txt') and readfile('aetherv2/profiles/gui.txt'):gsub('%s+', '')) or 'newer'
			if val == current then return end
			-- Flush the current profile (accent colour, module states, window
			-- positions, ...) to disk before we tear this GUI down and reload,
			-- so nothing changed since the last save is lost across the switch.
			pcall(function()
				mainapi:Save(mainapi.Profile)
			end)
			writefile('aetherv2/profiles/gui.txt', val)
			-- Deferred reload (see reloadAether): running main.lua synchronously
			-- inside this dropdown handler destroyed the GUI mid-callback, which is
			-- why switching GUI types often did nothing.
			reloadAether()
		end
	end,
	Tooltip = 'newer - AetherV2 Nexus\nnew - the newest vape theme\nold - the pre v4.05 theme\nrise - Rise 6.0'
})
mainapi.ThemeModules = guipane:CreateToggle({
	Name = 'Recolour modules with theme',
	Default = true,
	Tooltip = 'Also recolour module colours - boxes, ESP, tracers - when the GUI theme changes',
	Function = function(callback)
		if callback and mainapi.ApplyThemeToModules then
			mainapi:ApplyThemeToModules()
		end
	end
})
mainapi.ToggleMode = guipane:CreateDropdown({
	Name = 'Keybind mode',
	List = {'Toggle', 'Held'},
	Tooltip = 'Toggle - Keybind always activates when input starts or end\nHeld - Activates when input starts, Deactivate when input ends',
	Default = 'Toggle'
})
mainapi.RainbowMode = guipane:CreateDropdown({
	Name = 'Rainbow Mode',
	List = {'Normal', 'Gradient', 'Retro'},
	Tooltip = 'Normal - Smooth color fade\nGradient - Gradient color fade\nRetro - Static color'
})
mainapi.RainbowSpeed = guipane:CreateSlider({
	Name = 'Rainbow speed',
	Min = 0.1,
	Max = 10,
	Decimal = 10,
	Default = 1,
	Tooltip = 'Adjusts the speed of rainbow values'
})
mainapi.RainbowUpdateSpeed = guipane:CreateSlider({
	Name = 'Rainbow update rate',
	Min = 1,
	Max = 144,
	Default = 60,
	Tooltip = 'Adjusts the update rate of rainbow values',
	Suffix = 'hz'
})
guipane:CreateButton({
	Name = 'Reset GUI positions',
	Function = function()
		for _, v in mainapi.Categories do
			v.Object.Position = UDim2.fromOffset(6, 42)
		end
	end,
	Tooltip = 'This will reset your GUI back to default'
})
guipane:CreateButton({
	Name = 'Sort GUI',
	Function = function()
		local priority = {
			GUICategory = 1,
			CombatCategory = 2,
			BlatantCategory = 3,
			ExploitsCategory = 4,
			RenderCategory = 4,
			LegitCategory = 6,
			UtilityCategory = 7,
			WorldCategory = 8,
			InventoryCategory = 9,
			MinigamesCategory = 10,
			FavouritesCategory = 10,
			FriendsCategory = 10,
			ProfilesCategory = 11
		}
		local categories = {}
		for _, v in mainapi.Categories do
			if v.Type ~= 'Overlay' then
				table.insert(categories, v)
			end
		end
		table.sort(categories, function(a, b)
			return (priority[a.Object.Name] or 99) < (priority[b.Object.Name] or 99)
		end)

		local ind = 0
		for _, v in categories do
			if v.Object.Visible then
				v.Object.Position = UDim2.fromOffset(6 + (ind % 8 * 230), 60 + (ind > 7 and 360 or 0))
				ind += 1
			end
		end
	end,
	Tooltip = 'Sorts GUI'
})

--[[
	Notification Settings
]]

local notifpane = mainapi.Categories.Main:CreateSettingsPane({Name = 'Notifications'})
mainapi.Notifications = notifpane:CreateToggle({
	Name = 'Notifications',
	Function = function(enabled)
		if mainapi.ToggleNotifications.Object then
			mainapi.ToggleNotifications.Object.Visible = enabled
		end
	end,
	Tooltip = 'Shows notifications',
	Default = true
})
mainapi.ToggleNotifications = notifpane:CreateToggle({
	Name = 'Toggle alert',
	Tooltip = 'Notifies you if a module is enabled/disabled',
	Default = true,
	Darker = true
})

-- Push the current GUI accent onto every module colour option that supports it,
-- so picking a theme (preset or the slider below) also recolours module visuals:
-- Killaura target boxes, ESP, tracers, particles, and so on. Colour options that
-- are currently set to Rainbow, or explicitly flagged NoTheme, are left alone.
-- Gated by the "Recolour modules with theme" setting.
function mainapi:ApplyThemeToModules(h, s, v)
	if not (self.ThemeModules and self.ThemeModules.Enabled) then return end
	if not self.GUIColor then return end
	h = h or self.GUIColor.Hue
	s = s or self.GUIColor.Sat
	v = v or self.GUIColor.Value
	local function recolor(list)
		if type(list) ~= 'table' then return end
		for _, module in list do
			if type(module) == 'table' and type(module.Options) == 'table' then
				for _, opt in module.Options do
					if type(opt) == 'table' and opt.Type == 'ColorSlider' and not opt.Rainbow and not opt.NoTheme and opt.SetValue then
						pcall(function() opt:SetValue(h, s, v) end)
					end
				end
			end
		end
	end
	recolor(self.Modules)
	if self.Legit then recolor(self.Legit.Modules) end
end

-- Debounced version: dragging the GUI Theme slider fires continuously, so
-- coalesce to a single module recolour a moment after the last change instead of
-- retinting every module every frame (which would stutter).
local themeApplyToken = 0
function mainapi:QueueThemeToModules(h, s, v)
	if not (self.ThemeModules and self.ThemeModules.Enabled) then return end
	themeApplyToken += 1
	local myToken = themeApplyToken
	task.delay(0.12, function()
		if myToken == themeApplyToken then
			mainapi:ApplyThemeToModules(h, s, v)
		end
	end)
end

mainapi.GUIColor = mainapi.Categories.Main:CreateGUISlider({
	Name = 'GUI Theme',
	Function = function(h, s, v)
		mainapi:UpdateGUI(h, s, v, true)
		mainapi:QueueThemeToModules(h, s, v)
	end
})
mainapi.Categories.Main:CreateBind()


--[[
	Useful Overlays
]]

--[[
	Text GUI
]]

local textgui
textgui = mainapi:CreateOverlay({
	Name = 'Text GUI',
	Icon = getcustomasset('aetherv2/assets/new/textguiicon.png'),
	Size = UDim2.fromOffset(16, 12),
	Position = UDim2.fromOffset(12, 14),
	Function = function(callback)
		-- Nexus overlays only draw their on-screen content while pinned or while
		-- the menu is open, so enabling the Text GUI and closing the menu used to
		-- show nothing at all. Auto-pin it on enable so the text renders as a HUD
		-- right away; disabling hides it through the normal Button.Enabled gate,
		-- so no manual pinning is needed. Refresh Update() so it applies even when
		-- the module is toggled by keybind with the menu closed.
		if callback and not textgui.Pinned then
			textgui:Pin()
			if textgui.Update then
				textgui:Update()
			end
		end
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
local textguifont = textgui:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial',
	Function = function()
		mainapi:UpdateTextGUI()
	end
})
local textguicolor
local textguicolordrop = textgui:CreateDropdown({
	Name = 'Color Mode',
	List = {'Match GUI color', 'Custom color'},
	Function = function(val)
		textguicolor.Object.Visible = val == 'Custom color'
		mainapi:UpdateTextGUI()
	end
})
textguicolor = textgui:CreateColorSlider({
	Name = 'Text GUI color',
	Function = function()
		mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
	end,
	Darker = true,
	Visible = false
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
local textguigradientv4
local textguigradient = textgui:CreateToggle({
	Name = 'Gradient',
	Tooltip = 'Renders a gradient',
	Function = function(callback)
		textguigradientv4.Object.Visible = callback
		mainapi:UpdateTextGUI()
	end
})
textguigradientv4 = textgui:CreateToggle({
	Name = 'V4 Gradient',
	Function = function()
		mainapi:UpdateTextGUI()
	end,
	Darker = true,
	Visible = false
})
local textguianimations = textgui:CreateToggle({
	Name = 'Animations',
	Tooltip = 'Use animations on text gui',
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
local textguibackgroundtransparency = {
	Value = 0.5,
	Object = {Visible = {}}
}
local textguibackgroundtint = {Enabled = false}
local textguibackground = textgui:CreateToggle({
	Name = 'Render background',
	Function = function(callback)
		textguibackgroundtransparency.Object.Visible = callback
		textguibackgroundtint.Object.Visible = callback
		mainapi:UpdateTextGUI()
	end
})
textguibackgroundtransparency = textgui:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Decimal = 10,
	Function = function()
		mainapi:UpdateTextGUI()
	end,
	Darker = true,
	Visible = false
})
textguibackgroundtint = textgui:CreateToggle({
	Name = 'Tint',
	Function = function()
		mainapi:UpdateTextGUI()
	end,
	Darker = true,
	Visible = false
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
textguimoduleslist = textgui:CreateTextList({
	Name = 'Blacklist',
	Tooltip = 'Name of module to hide',
	Icon = getcustomasset('aetherv2/assets/new/blockedicon.png'),
	Tab = getcustomasset('aetherv2/assets/new/blockedtab.png'),
	TabSize = UDim2.fromOffset(21, 16),
	Color = Color3.fromRGB(250, 50, 56),
	Function = function()
		mainapi:UpdateTextGUI()
	end,
	Visible = false,
	Darker = true
})
local textguirender = textgui:CreateToggle({
	Name = 'Hide render',
	Function = function()
		mainapi:UpdateTextGUI()
	end
})
local textguibox
local textguifontcustom
local textguicolorcustomtoggle
local textguicolorcustom
local textguitext = textgui:CreateToggle({
	Name = 'Add custom text',
	Function = function(enabled)
		textguibox.Object.Visible = enabled
		textguifontcustom.Object.Visible = enabled
		textguicolorcustomtoggle.Object.Visible = enabled
		textguicolorcustom.Object.Visible = textguicolorcustomtoggle.Enabled and enabled
		mainapi:UpdateTextGUI()
	end
})
textguibox = textgui:CreateTextBox({
	Name = 'Custom text',
	Function = function()
		mainapi:UpdateTextGUI()
	end,
	Darker = true,
	Visible = false
})
textguifontcustom = textgui:CreateFont({
	Name = 'Custom Font',
	Blacklist = 'Arial',
	Function = function()
		mainapi:UpdateTextGUI()
	end,
	Darker = true,
	Visible = false
})
textguicolorcustomtoggle = textgui:CreateToggle({
	Name = 'Set custom text color',
	Function = function(enabled)
		textguicolorcustom.Object.Visible = enabled
		mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
	end,
	Darker = true,
	Visible = false
})
textguicolorcustom = textgui:CreateColorSlider({
	Name = 'Color of custom text',
	Function = function()
		mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
	end,
	Darker = true,
	Visible = false
})

--[[
	Text GUI Objects
]]

local VapeLabels = {}
local VapeLogo = Instance.new('ImageLabel')
VapeLogo.Name = 'Logo'
VapeLogo.Size = UDim2.fromOffset(80, 21)
VapeLogo.Position = UDim2.new(1, -142, 0, 3)
VapeLogo.BackgroundTransparency = 1
VapeLogo.BorderSizePixel = 0
VapeLogo.Visible = false
VapeLogo.BackgroundColor3 = Color3.new()
VapeLogo.Image = getcustomasset('aetherv2/assets/new/textvape.png')
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
VapeLogoV4.Size = UDim2.fromOffset(33, 18)
VapeLogoV4.Position = UDim2.new(1, 1, 0, 1)
VapeLogoV4.BackgroundColor3 = Color3.new()
VapeLogoV4.BackgroundTransparency = 1
VapeLogoV4.BorderSizePixel = 0
VapeLogoV4.Image = getcustomasset('aetherv2/assets/new/textv4.png')
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
local VapeLabelCustom = Instance.new('TextLabel')
VapeLabelCustom.Position = UDim2.fromOffset(5, 2)
VapeLabelCustom.BackgroundTransparency = 1
VapeLabelCustom.BorderSizePixel = 0
VapeLabelCustom.Visible = false
VapeLabelCustom.Text = ''
VapeLabelCustom.TextSize = 25
VapeLabelCustom.FontFace = textguifontcustom.Value
VapeLabelCustom.RichText = true
local VapeLabelCustomShadow = VapeLabelCustom:Clone()
VapeLabelCustom:GetPropertyChangedSignal('Position'):Connect(function()
	VapeLabelCustomShadow.Position = UDim2.new(
		VapeLabelCustom.Position.X.Scale,
		VapeLabelCustom.Position.X.Offset + 1,
		0,
		VapeLabelCustom.Position.Y.Offset + 1
	)
end)
VapeLabelCustom:GetPropertyChangedSignal('FontFace'):Connect(function()
	VapeLabelCustomShadow.FontFace = VapeLabelCustom.FontFace
end)
VapeLabelCustom:GetPropertyChangedSignal('Text'):Connect(function()
	VapeLabelCustomShadow.Text = removeTags(VapeLabelCustom.Text)
end)
VapeLabelCustom:GetPropertyChangedSignal('Size'):Connect(function()
	VapeLabelCustomShadow.Size = VapeLabelCustom.Size
end)
VapeLabelCustomShadow.TextColor3 = Color3.new()
VapeLabelCustomShadow.TextTransparency = 0.65
VapeLabelCustomShadow.Parent = textgui.Children
VapeLabelCustom.Parent = textgui.Children
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

--[[
	Target Info
]]

local targetinfo
local targetinfoobj
local targetinfobcolor
targetinfoobj = mainapi:CreateOverlay({
	Name = 'Target Info',
	Icon = getcustomasset('aetherv2/assets/new/targetinfoicon.png'),
	Size = UDim2.fromOffset(14, 14),
	Position = UDim2.fromOffset(12, 14),
	CategorySize = 240,
	Function = function(callback)
		if callback then
			task.spawn(function()
				repeat
					targetinfo:UpdateInfo()
					task.wait()
				until not targetinfoobj.Button or not targetinfoobj.Button.Enabled
			end)
		end
	end
})

local targetinfobkg = Instance.new('Frame')
targetinfobkg.Size = UDim2.fromOffset(240, 89)
targetinfobkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
targetinfobkg.BackgroundTransparency = 0.5
targetinfobkg.Parent = targetinfoobj.Children
local targetinfoblurobj = addBlur(targetinfobkg)
targetinfoblurobj.Visible = false
addCorner(targetinfobkg)
local targetinfoshot = Instance.new('ImageLabel')
targetinfoshot.Size = UDim2.fromOffset(26, 27)
targetinfoshot.Position = UDim2.fromOffset(19, 17)
targetinfoshot.BackgroundColor3 = uipallet.Main
targetinfoshot.Image = 'rbxthumb://type=AvatarHeadShot&id=1&w=420&h=420'
targetinfoshot.Parent = targetinfobkg
local targetinfoshotflash = Instance.new('Frame')
targetinfoshotflash.Size = UDim2.fromScale(1, 1)
targetinfoshotflash.BackgroundTransparency = 1
targetinfoshotflash.BackgroundColor3 = Color3.new(1, 0, 0)
targetinfoshotflash.Parent = targetinfoshot
addCorner(targetinfoshotflash)
local targetinfoshotblur = addBlur(targetinfoshot)
targetinfoshotblur.Visible = false
addCorner(targetinfoshot)
local targetinfoname = Instance.new('TextLabel')
targetinfoname.Size = UDim2.fromOffset(145, 20)
targetinfoname.Position = UDim2.fromOffset(54, 20)
targetinfoname.BackgroundTransparency = 1
targetinfoname.Text = 'Target name'
targetinfoname.TextXAlignment = Enum.TextXAlignment.Left
targetinfoname.TextYAlignment = Enum.TextYAlignment.Top
targetinfoname.TextScaled = true
targetinfoname.TextColor3 = color.Light(uipallet.Text, 0.4)
targetinfoname.TextStrokeTransparency = 1
targetinfoname.FontFace = uipallet.Font
local targetinfoshadow = targetinfoname:Clone()
targetinfoshadow.Position = UDim2.fromOffset(55, 21)
targetinfoshadow.TextColor3 = Color3.new()
targetinfoshadow.TextTransparency = 0.65
targetinfoshadow.Visible = false
targetinfoshadow.Parent = targetinfobkg
targetinfoname:GetPropertyChangedSignal('Size'):Connect(function()
	targetinfoshadow.Size = targetinfoname.Size
end)
targetinfoname:GetPropertyChangedSignal('Text'):Connect(function()
	targetinfoshadow.Text = targetinfoname.Text
end)
targetinfoname:GetPropertyChangedSignal('FontFace'):Connect(function()
	targetinfoshadow.FontFace = targetinfoname.FontFace
end)
targetinfoname.Parent = targetinfobkg
local targetinfohealthbkg = Instance.new('Frame')
targetinfohealthbkg.Name = 'HealthBKG'
targetinfohealthbkg.Size = UDim2.fromOffset(200, 9)
targetinfohealthbkg.Position = UDim2.fromOffset(20, 56)
targetinfohealthbkg.BackgroundColor3 = uipallet.Main
targetinfohealthbkg.BorderSizePixel = 0
targetinfohealthbkg.Parent = targetinfobkg
addCorner(targetinfohealthbkg, UDim.new(1, 0))
local targetinfohealth = targetinfohealthbkg:Clone()
targetinfohealth.Size = UDim2.fromScale(0.8, 1)
targetinfohealth.Position = UDim2.new()
targetinfohealth.BackgroundColor3 = Color3.fromHSV(1 / 2.5, 0.89, 0.75)
targetinfohealth.Parent = targetinfohealthbkg
targetinfohealth:GetPropertyChangedSignal('Size'):Connect(function()
	targetinfohealth.Visible = targetinfohealth.Size.X.Scale > 0.01
end)
local targetinfohealthextra = targetinfohealth:Clone()
targetinfohealthextra.Size = UDim2.new()
targetinfohealthextra.Position = UDim2.fromScale(1, 0)
targetinfohealthextra.AnchorPoint = Vector2.new(1, 0)
targetinfohealthextra.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
targetinfohealthextra.Visible = false
targetinfohealthextra.Parent = targetinfohealthbkg
targetinfohealthextra:GetPropertyChangedSignal('Size'):Connect(function()
	targetinfohealthextra.Visible = targetinfohealthextra.Size.X.Scale > 0.01
end)
local targetinfohealthblur = addBlur(targetinfohealthbkg)
targetinfohealthblur.SliceCenter = Rect.new(52, 31, 261, 510)
targetinfohealthblur.ImageColor3 = Color3.new()
targetinfohealthblur.Visible = false
local targetinfob = Instance.new('UIStroke')
targetinfob.Enabled = false
targetinfob.Color = Color3.fromHSV(0.44, 1, 1)
targetinfob.Parent = targetinfobkg

targetinfoobj:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial',
	Function = function(val)
		targetinfoname.FontFace = val
	end
})
local targetinfobackgroundtransparency = {
	Value = 0.5,
	Object = {Visible = {}}
}
local targetinfodisplay = targetinfoobj:CreateToggle({
	Name = 'Use Displayname',
	Default = true
})
targetinfoobj:CreateToggle({
	Name = 'Render Background',
	Function = function(callback)
		targetinfobkg.BackgroundTransparency = callback and targetinfobackgroundtransparency.Value or 1
		targetinfoshadow.Visible = not callback
		targetinfoblurobj.Visible = callback
		targetinfohealthblur.Visible = not callback
		targetinfoshotblur.Visible = not callback
		targetinfobackgroundtransparency.Object.Visible = callback
	end,
	Default = true
})
targetinfobackgroundtransparency = targetinfoobj:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Decimal = 10,
	Function = function(val)
		targetinfobkg.BackgroundTransparency = val
	end,
	Darker = true
})
local targetinfocolor
local targetinfocolortoggle = targetinfoobj:CreateToggle({
	Name = 'Custom Color',
	Function = function(callback)
		targetinfocolor.Object.Visible = callback
		if callback then
			targetinfobkg.BackgroundColor3 = Color3.fromHSV(targetinfocolor.Hue, targetinfocolor.Sat, targetinfocolor.Value)
			targetinfoshot.BackgroundColor3 = Color3.fromHSV(targetinfocolor.Hue, targetinfocolor.Sat, math.max(targetinfocolor.Value - 0.1, 0.075))
			targetinfohealthbkg.BackgroundColor3 = targetinfoshot.BackgroundColor3
		else
			targetinfobkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
			targetinfoshot.BackgroundColor3 = uipallet.Main
			targetinfohealthbkg.BackgroundColor3 = uipallet.Main
		end
	end
})
targetinfocolor = targetinfoobj:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		if targetinfocolortoggle.Enabled then
			targetinfobkg.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			targetinfoshot.BackgroundColor3 = Color3.fromHSV(hue, sat, math.max(val - 0.1, 0))
			targetinfohealthbkg.BackgroundColor3 = targetinfoshot.BackgroundColor3
		end
	end,
	Darker = true,
	Visible = false
})
targetinfoobj:CreateToggle({
	Name = 'Border',
	Function = function(callback)
		targetinfob.Enabled = callback
		targetinfobcolor.Object.Visible = callback
	end
})
targetinfobcolor = targetinfoobj:CreateColorSlider({
	Name = 'Border Color',
	Function = function(hue, sat, val, opacity)
		targetinfob.Color = Color3.fromHSV(hue, sat, val)
		targetinfob.Transparency = 1 - opacity
	end,
	Darker = true,
	Visible = false
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
				tween:Tween(targetinfohealth, TweenInfo.new(0.3), {
					Size = UDim2.fromScale(math.min(percent, 1), 1), BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
				})
				tween:Tween(targetinfohealthextra, TweenInfo.new(0.3), {
					Size = UDim2.fromScale(math.clamp(percent - 1, 0, 0.8), 1)
				})
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

function mainapi:UpdateTextGUI(afterload)
	if not afterload and not mainapi.Loaded then return end
	if textgui.Button.Enabled then
		local right = textgui.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
		VapeLogo.Visible = textguiwatermark.Enabled
		VapeLogo.Position = right and UDim2.new(1 / VapeTextScale.Scale, -113, 0, 6) or UDim2.fromOffset(0, 6)
		VapeLogoShadow.Visible = textguishadow.Enabled
		VapeLabelCustom.Text = textguibox.Value
		VapeLabelCustom.FontFace = textguifontcustom.Value
		VapeLabelCustom.Visible = VapeLabelCustom.Text ~= '' and textguitext.Enabled
		VapeLabelCustomShadow.Visible = VapeLabelCustom.Visible and textguishadow.Enabled
		VapeLabelSorter.HorizontalAlignment = right and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		VapeLabelHolder.Size = UDim2.fromScale(1 / VapeTextScale.Scale, 1)
		VapeLabelHolder.Position = UDim2.fromOffset(right and 3 or 0, 11 + (VapeLogo.Visible and VapeLogo.Size.Y.Offset or 0) + (VapeLabelCustom.Visible and 28 or 0) + (textguibackground.Enabled and 3 or 0))
		if VapeLabelCustom.Visible then
			local size = getfontsize(removeTags(VapeLabelCustom.Text), VapeLabelCustom.TextSize, VapeLabelCustom.FontFace)
			VapeLabelCustom.Size = UDim2.fromOffset(size.X, size.Y)
			VapeLabelCustom.Position = UDim2.new(right and 1 / VapeTextScale.Scale or 0, right and -size.X or 0, 0, (VapeLogo.Visible and 32 or 8))
		end

		local found = {}
		for _, v in VapeLabels do
			if v.Enabled then
				table.insert(found, v.Object.Name)
			end
			v.Object:Destroy()
		end
		table.clear(VapeLabels)

		local info = TweenInfo.new(0.3, Enum.EasingStyle.Exponential)
		for i, v in mainapi.Modules do
			if textguimodules.Enabled and table.find(textguimoduleslist.ListEnabled, i) then continue end
			if textguirender.Enabled and v.Category == 'Render' then continue end
			if v.Enabled or table.find(found, i) then
				local holder = Instance.new('Frame')
				holder.Name = i
				holder.Size = UDim2.fromOffset()
				holder.BackgroundTransparency = 1
				holder.ClipsDescendants = true
				holder.Parent = VapeLabelHolder
				local holderbackground
				local holdercolorline
				if textguibackground.Enabled then
					holderbackground = Instance.new('Frame')
					holderbackground.Size = UDim2.new(1, 3, 1, 0)
					holderbackground.BackgroundColor3 = color.Dark(uipallet.Main, 0.15)
					holderbackground.BackgroundTransparency = textguibackgroundtransparency.Value
					holderbackground.BorderSizePixel = 0
					holderbackground.Parent = holder
					local holderline = Instance.new('Frame')
					holderline.Size = UDim2.new(1, 0, 0, 1)
					holderline.Position = UDim2.new(0, 0, 1, -1)
					holderline.BackgroundColor3 = Color3.new()
					holderline.BackgroundTransparency = 0.928 + (0.072 * math.clamp((textguibackgroundtransparency.Value - 0.5) / 0.5, 0, 1))
					holderline.BorderSizePixel = 0
					holderline.Parent = holderbackground
					local holderline2 = holderline:Clone()
					holderline2.Name = 'Line'
					holderline2.Position = UDim2.new()
					holderline2.Parent = holderbackground
					holdercolorline = Instance.new('Frame')
					holdercolorline.Size = UDim2.new(0, 2, 1, 0)
					holdercolorline.Position = right and UDim2.new(1, -5, 0, 0) or UDim2.new()
					holdercolorline.BorderSizePixel = 0
					holdercolorline.Parent = holderbackground
				end
				local holdertext = Instance.new('TextLabel')
				holdertext.Position = UDim2.fromOffset(right and 3 or 6, 2)
				holdertext.BackgroundTransparency = 1
				holdertext.BorderSizePixel = 0
				holdertext.Text = ({i:gsub(' ', '')})[1]..(v.ExtraText and " <font color='#A8A8A8'>"..v.ExtraText()..'</font>' or '')
				holdertext.TextSize = 15
				holdertext.FontFace = textguifont.Value
				holdertext.RichText = true
				local size = getfontsize(removeTags(holdertext.Text), holdertext.TextSize, holdertext.FontFace)
				holdertext.Size = UDim2.fromOffset(size.X, size.Y)
				if textguishadow.Enabled then
					local holderdrop = holdertext:Clone()
					holderdrop.Position = UDim2.fromOffset(holdertext.Position.X.Offset + 1, holdertext.Position.Y.Offset + 1)
					holderdrop.Text = removeTags(holdertext.Text)
					holderdrop.TextColor3 = Color3.new()
					holderdrop.Parent = holder
				end
				holdertext.Parent = holder
				local holdersize = UDim2.fromOffset(size.X + 10, size.Y + (textguibackground.Enabled and 5 or 3))
				if textguianimations.Enabled then
					if not table.find(found, i) then
						tween:Tween(holder, info, {
							Size = holdersize
						})
					else
						holder.Size = holdersize
						if not v.Enabled then
							tween:Tween(holder, info, {
								Size = UDim2.fromOffset()
							})
						end
					end
				else
					holder.Size = v.Enabled and holdersize or UDim2.fromOffset()
				end
				table.insert(VapeLabels, {
					Object = holder,
					Text = holdertext,
					Background = holderbackground,
					Color = holdercolorline,
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

function mainapi:UpdateGUI(hue, sat, val, default)
	if mainapi.Loaded == nil then return end
	if not default and mainapi.GUIColor.Rainbow then return end
	if textgui.Button.Enabled then
		VapeLogoGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
			ColorSequenceKeypoint.new(1, textguigradient.Enabled and Color3.fromHSV(mainapi:Color((hue - 0.075) % 1)) or Color3.fromHSV(hue, sat, val))
		})
		VapeLogoGradient2.Color = textguigradient.Enabled and textguigradientv4.Enabled and VapeLogoGradient.Color or ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
		})
		VapeLabelCustom.TextColor3 = textguicolorcustomtoggle.Enabled and Color3.fromHSV(textguicolorcustom.Hue, textguicolorcustom.Sat, textguicolorcustom.Value) or VapeLogoGradient.Color.Keypoints[2].Value

		local customcolor = textguicolordrop.Value == 'Custom color' and Color3.fromHSV(textguicolor.Hue, textguicolor.Sat, textguicolor.Value) or nil
		for i, v in VapeLabels do
			v.Text.TextColor3 = customcolor or (mainapi.GUIColor.Rainbow and Color3.fromHSV(mainapi:Color((hue - ((textguigradient and i + 2 or i) * 0.025)) % 1)) or VapeLogoGradient.Color.Keypoints[2].Value)
			if v.Color then
				v.Color.BackgroundColor3 = v.Text.TextColor3
			end
			if textguibackgroundtint.Enabled and v.Background then
				v.Background.BackgroundColor3 = color.Dark(v.Text.TextColor3, 0.75)
			end
		end
	end

	if not clickgui.Visible and not mainapi.Legit.Window.Visible then return end
	local rainbow = mainapi.GUIColor.Rainbow and mainapi.RainbowMode.Value ~= 'Retro'

	for i, v in mainapi.Categories do
		if i == 'Main' then
			v.Object.VapeLogo.V4Logo.TextColor3 = Color3.fromHSV(hue, sat, val)
			for _, button in v.Buttons do
				if button.Enabled then
					button.Object.TextColor3 = rainbow and Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1)) or Color3.fromHSV(hue, sat, val)
					if button.Icon then
						button.Icon.ImageColor3 = button.Object.TextColor3
					end
				end
			end
		end

		if v.Options then
			for _, option in v.Options do
				if option.Color then
					option:Color(hue, sat, val, rainbow)
				end
			end
		end

		if v.Type == 'CategoryList' then
			v.Object.Children.Add.AddButton.ImageColor3 = rainbow and Color3.fromHSV(mainapi:Color(hue % 1)) or Color3.fromHSV(hue, sat, val)
			if v.Selected then
				v.Selected.BackgroundColor3 = rainbow and Color3.fromHSV(mainapi:Color(hue % 1)) or Color3.fromHSV(hue, sat, val)
				v.Selected.Title.TextColor3 = mainapi.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or mainapi:TextColor(hue, sat, val)
				v.Selected.Dots.Dots.ImageColor3 = v.Selected.Title.TextColor3
				v.Selected.Bind.Icon.ImageColor3 = v.Selected.Title.TextColor3
				v.Selected.Bind.TextLabel.TextColor3 = v.Selected.Title.TextColor3
			end
		end
	end

	for _, button in mainapi.Modules do
		if button.Enabled then
			button.Object.BackgroundColor3 = rainbow and Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1)) or Color3.fromHSV(hue, sat, val)
			button.Object.TextColor3 = mainapi.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or mainapi:TextColor(hue, sat, val)
			button.Object.UIGradient.Enabled = rainbow and mainapi.RainbowMode.Value == 'Gradient'
			if button.Object.UIGradient.Enabled then
				button.Object.BackgroundColor3 = Color3.new(1, 1, 1)
				button.Object.UIGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1))),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(mainapi:Color((hue - ((button.Index + 1) * 0.025)) % 1)))
				})
			end
			button.Object.Bind.Icon.ImageColor3 = button.Object.TextColor3
			button.Object.Bind.TextLabel.TextColor3 = button.Object.TextColor3
			button.Object.Dots.Dots.ImageColor3 = button.Object.TextColor3
		end

		for _, option in button.Options do
			if option.Color then
				option:Color(hue, sat, val, rainbow)
			end
		end

		for _, v in button.Tags do
			v.BackgroundColor3 = rainbow and Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1)) or button.Enabled and Color3.new(1, 1, 1) or Color3.fromHSV(hue, sat, val)
			v.BackgroundTransparency = (rainbow or not button.Enabled) and 0 or 0.85
			v:FindFirstChild('Text').TextColor3 = mainapi.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or mainapi:TextColor(hue, sat, val)
		end
	end

	for i, v in mainapi.Overlays.Toggles do
		if v.Enabled then
			tween:Cancel(v.Object.Knob)
			v.Object.Knob.BackgroundColor3 = rainbow and Color3.fromHSV(mainapi:Color((hue - (i * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
		end
	end

	if mainapi.Legit.Icon then
		mainapi.Legit.Icon.ImageColor3 = Color3.fromHSV(hue, sat, val)
	end

	if mainapi.Legit.Window.Visible then
		for _, v in mainapi.Legit.Modules do
			if v.Enabled then
				tween:Cancel(v.Object.Knob)
				v.Object.Knob.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			end

			for _, option in v.Options do
				if option.Color then
					option:Color(hue, sat, val, rainbow)
				end
			end
		end
	end
end

mainapi:Clean(notifications.ChildRemoved:Connect(function()
	-- Reflow using the same corner maths as CreateNotification, otherwise
	-- toasts jump to the bottom right whenever an older one expires while the
	-- user has picked a different corner in Settings -> Notifications.
	local left = nexus.Notify.Position == 'Bottom Left' or nexus.Notify.Position == 'Top Left'
	local top = nexus.Notify.Position == 'Top Left' or nexus.Notify.Position == 'Top Right'
	for i, v in notifications:GetChildren() do
		if tween.Tween then
			tween:Tween(v, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
				Position = UDim2.new(left and 0 or 1, 0, top and 0 or 1, top and (46 + (78 * (i - 1))) or -(29 + (78 * i)))
			})
		end
	end
end))

local whitelist = {Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3}
local function convert(input)
	return {KeyCode = {Name = input == Enum.UserInputType.MouseButton2 and 'MB2' or input == Enum.UserInputType.MouseButton1 and 'MB1' or 'MB3'}}
end
local function keybindStart(inputObj)
	if not inputService:GetFocusedTextBox() and (inputObj.KeyCode ~= Enum.KeyCode.Unknown or table.find(whitelist, inputObj.UserInputType)) then
		if table.find(whitelist, inputObj.UserInputType) then
			inputObj = convert(inputObj.UserInputType)
		end
		
		table.insert(mainapi.HeldKeybinds, inputObj.KeyCode.Name)
		if mainapi.Binding then return end

		-- Escape collapses any open module settings panels (quick way to tidy up
		-- after poking around several modules' settings).
		if inputObj.KeyCode == Enum.KeyCode.Escape and clickgui.Visible then
			for _, m in mainapi.Modules do
				if m.SettingsOpen and m.SetSettingsOpen then
					m:SetSettingsOpen(false)
				end
			end
		end

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
				mainapi:Save()
				mainapi:Load(true, v.Name)
				mainapi:Save()
				break
			end
		end
	end
end
local function keybindEnd(inputObj)
	if not inputService:GetFocusedTextBox() and (inputObj.KeyCode ~= Enum.KeyCode.Unknown or table.find(whitelist, inputObj.UserInputType)) then
		if table.find(whitelist, inputObj.UserInputType) then
			inputObj = convert(inputObj.UserInputType)
		end
		if mainapi.Binding then
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
end
mainapi:Clean(inputService.InputBegan:Connect(keybindStart))

mainapi:Clean(inputService.InputEnded:Connect(function(inputObj)
	if table.find(whitelist, inputObj.UserInputType) then
		inputObj = convert(inputObj.UserInputType)
	end
	if mainapi.ToggleMode.Value == "Held" and not table.find(mainapi.Keybind, ({tostring(inputObj.KeyCode):gsub("Enum.KeyCode.", "")})[1]) then
		keybindStart(inputObj)
	else
		keybindEnd(inputObj)
	end
end))

--[[
	=========================================================================
	 NEXUS ADDITIONS
	 Extension point kept from the Nexus redesign:
	  * Plugin system      (mainapi:RegisterPlugin + aetherv2/plugins/)
	 It reuses the existing component/overlay/save systems, so plugins persist
	 through the same profile files as every other option. (The old Theme Editor
	 and Stats Dashboard were removed in the v6 declutter.)
	=========================================================================
]]



--[[
	Plugin system
	Third-party modules register through mainapi:RegisterPlugin(name, plugin).
	The plugin table may contain any of:
	  Category = {Name = 'My Tab', Icon = <asset>, IconSize = UDim2}
	      -> creates a full category tab; returned entry.Category exposes the
	         normal CreateModule API.
	  Overlay = {Name = 'My HUD', Icon = <asset>, IconSize = UDim2,
	             Size = number, Function = function(enabled) end}
	      -> creates an overlay window; entry.Overlay.Children is a frame the
	         plugin can render custom content into.
	  Stats = {'Stat A', 'Stat B'}
	      -> registers new stat types on the Stats Dashboard.
	  Init = function(plugin, vape, entry) end
	      -> called once registration is complete.
	Files dropped into aetherv2/plugins/*.lua are loaded automatically at
	startup and receive mainapi as their first argument.
]]
mainapi.Plugins = {}
function mainapi:RegisterPlugin(name, plugin)
	assert(type(name) == 'string' and name ~= '', 'RegisterPlugin: name must be a non-empty string')
	assert(type(plugin) == 'table', 'RegisterPlugin: pluginTable must be a table')
	if self.Plugins[name] then
		return self.Plugins[name]
	end

	local entry = {
		Name = name,
		Plugin = plugin
	}

	if type(plugin.Stats) == 'table' and self.Stats then
		for _, statname in plugin.Stats do
			pcall(function()
				self.Stats:RegisterStat(statname)
			end)
		end
	end
	if type(plugin.Category) == 'table' then
		entry.Category = self:CreateCategory({
			Name = plugin.Category.Name or name,
			Icon = plugin.Category.Icon or getcustomasset('aetherv2/assets/new/customsettings.png'),
			Size = plugin.Category.IconSize or UDim2.fromOffset(15, 14)
		})
	end
	if type(plugin.Overlay) == 'table' then
		entry.Overlay = self:CreateOverlay({
			Name = plugin.Overlay.Name or name,
			Icon = plugin.Overlay.Icon or getcustomasset('aetherv2/assets/new/customsettings.png'),
			Size = plugin.Overlay.IconSize or UDim2.fromOffset(15, 14),
			Position = UDim2.fromOffset(12, 13),
			CategorySize = plugin.Overlay.Size,
			Function = plugin.Overlay.Function
		})
	end

	self.Plugins[name] = entry

	if type(plugin.Init) == 'function' then
		local suc, err = pcall(plugin.Init, plugin, self, entry)
		if not suc then
			self:CreateNotification('Plugins', 'Plugin '..name..' failed to initialize:\n'..tostring(err), 10, 'alert')
		end
	end

	return entry
end

-- Auto-load third-party plugins from aetherv2/plugins/*.lua.
task.defer(function()
	local suc, files = pcall(function()
		if not isfolder('aetherv2/plugins') then
			makefolder('aetherv2/plugins')
			return {}
		end
		return listfiles('aetherv2/plugins')
	end)
	if not suc then return end
	for _, file in files do
		if tostring(file):sub(-4) == '.lua' then
			local ok, err = pcall(function()
				local func = loadstring(readfile(file), 'plugin:'..tostring(file))
				if func then
					func(mainapi)
				end
			end)
			if not ok then
				warn('[AetherV2 Nexus] plugin error:', file, err)
				mainapi:CreateNotification('Plugins', 'Failed to load '..tostring(file)..'\n'..tostring(err), 10, 'alert')
			end
		end
	end
end)




--[[
	Notification customisation (Settings -> Notifications)
	Corner, duration multiplier, stack limit and sound for the toasts
	CreateNotification renders.
]]
do
	notifpane:CreateDropdown({
		Name = 'Notification position',
		List = {'Bottom Right', 'Bottom Left', 'Top Right', 'Top Left'},
		Tooltip = 'Screen corner notifications slide in from',
		Function = function(val)
			nexus.Notify.Position = val
		end
	})
	notifpane:CreateSlider({
		Name = 'Notification duration',
		Min = 0.5,
		Max = 3,
		Decimal = 10,
		Default = 1,
		Suffix = 'x',
		Tooltip = 'Multiplies how long every notification stays up',
		Function = function(val)
			nexus.Notify.Duration = val
		end
	})
	notifpane:CreateSlider({
		Name = 'Max notifications',
		Min = 1,
		Max = 12,
		Default = 6,
		Darker = true,
		Tooltip = 'Oldest toast is retired when the stack is full',
		Function = function(val)
			nexus.Notify.Max = val
		end
	})
	notifpane:CreateToggle({
		Name = 'Notification sound',
		Tooltip = 'Ping when a notification appears (needs UI sounds)',
		Function = function(callback)
			nexus.Notify.Sound = callback
		end
	})
	notifpane:CreateButton({
		Name = 'Test notification',
		Function = function()
			local types = {'info', 'warning', 'alert'}
			mainapi:CreateNotification('Nexus', 'This is a test notification.', 3, types[math.random(#types)])
		end
	})
end

--[[
	Watermark (Overlays -> Watermark)
	A pinnable accent-striped pill showing custom text, FPS, ping and a clock.
	Pin it (like any overlay) to keep it on screen while the GUI is closed.
]]
do
	local segments = {Fps = true, Ping = true, Clock = true}
	local watermarkText = 'AETHER'
	local bar, label, strip
	local fpsAccum, fpsFrames, fpsValue = 0, 0, 60

	local function refresh()
		if not label then return end
		local accent = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		local dim = color.Dark(uipallet.Text, 0.25):ToHex()
		local parts = {string.format('%s <font color="#%s">v%s</font>', watermarkText, accent:ToHex(), mainapi.Version)}
		if segments.Fps then
			table.insert(parts, string.format('%d fps', math.min(math.floor(fpsValue + 0.5), 999)))
		end
		if segments.Ping then
			local suc, ping = pcall(function()
				return math.floor(cloneref(game:GetService('Stats')).Network.ServerStatsItem['Data Ping']:GetValue())
			end)
			table.insert(parts, (suc and ping) and ping..' ms' or '? ms')
		end
		if segments.Clock then
			table.insert(parts, os.date('%H:%M:%S'))
		end
		label.Text = table.concat(parts, string.format(' <font color="#%s">|</font> ', dim))
		strip.BackgroundColor3 = accent
		local width = getfontsize(removeTags(label.Text), 13, uipallet.FontSemiBold).X
		bar.Size = UDim2.fromOffset(width + 34, 30)
	end

	local overlay = mainapi:CreateOverlay({
		Name = 'Watermark',
		Icon = getcustomasset('aetherv2/assets/new/textguiicon.png'),
		Size = UDim2.fromOffset(15, 14),
		Position = UDim2.fromOffset(12, 13),
		Color = true,
		Function = function(callback)
			if callback then
				local overlayapi = mainapi.Categories.Watermark
				fpsAccum, fpsFrames = 0, 0
				overlayapi:Clean(runService.Heartbeat:Connect(function(dt)
					fpsAccum += dt
					fpsFrames += 1
					if fpsAccum >= 0.5 then
						fpsValue = fpsFrames / fpsAccum
						fpsAccum, fpsFrames = 0, 0
						refresh()
					end
				end))
				refresh()
			end
		end
	})
	local holder = overlay.Children

	bar = Instance.new('Frame')
	bar.Name = 'WatermarkBar'
	bar.Size = UDim2.fromOffset(180, 30)
	bar.Position = UDim2.fromOffset(0, 4)
	bar.BackgroundColor3 = uipallet.Main
	bar.BorderSizePixel = 0
	bar.Parent = holder
	addBlur(bar)
	addCorner(bar)
	strip = Instance.new('Frame')
	strip.Name = 'Accent'
	strip.Size = UDim2.new(0, 3, 1, -8)
	strip.Position = UDim2.fromOffset(8, 4)
	strip.BorderSizePixel = 0
	strip.Parent = bar
	addCorner(strip, UDim.new(1, 0))
	label = Instance.new('TextLabel')
	label.Name = 'Label'
	label.Size = UDim2.new(1, -26, 1, 0)
	label.Position = UDim2.fromOffset(19, 0)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.Text = ''
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = uipallet.Text
	label.TextSize = 13
	label.FontFace = uipallet.FontSemiBold
	label.Parent = bar

	overlay:CreateToggle({
		Name = 'Show FPS',
		Default = true,
		Function = function(callback)
			segments.Fps = callback
			refresh()
		end
	})
	overlay:CreateToggle({
		Name = 'Show ping',
		Default = true,
		Function = function(callback)
			segments.Ping = callback
			refresh()
		end
	})
	overlay:CreateToggle({
		Name = 'Show clock',
		Default = true,
		Function = function(callback)
			segments.Clock = callback
			refresh()
		end
	})
	local textOption
	textOption = overlay:CreateTextBox({
		Name = 'Watermark text',
		Default = 'AETHER',
		Placeholder = 'AETHER',
		-- TextBox Functions receive the enter-pressed flag, not the value, so
		-- read the option's Value directly.
		Function = function()
			local val = textOption and tostring(textOption.Value or '') or ''
			watermarkText = val == '' and 'AETHER' or val
			refresh()
		end
	})
	refresh()
end

--[[
	Keybind HUD (Overlays -> Keybinds)
	Lists every module with a bind and its key(s); enabled modules light up in
	the accent colour. Pin the overlay to keep it visible in game.
]]
do
	local onlyEnabled = false
	local showKeys = true
	local bg, listTitle
	local rows = {}
	local lastSignature

	local function bindString(bind)
		if type(bind) ~= 'table' then return '' end
		local keys = {}
		for _, key in bind do
			if type(key) == 'string' then
				table.insert(keys, key:upper())
			end
		end
		if bind.Button then
			return 'TOUCH'
		end
		return table.concat(keys, '+')
	end

	local function refresh(force)
		if not bg then return end
		local entries = {}
		for name, mod in mainapi.Modules do
			local keys = bindString(mod.Bind)
			if keys ~= '' and (not onlyEnabled or mod.Enabled) then
				table.insert(entries, {Name = name, Keys = keys, Enabled = mod.Enabled})
			end
		end
		table.sort(entries, function(a, b)
			if a.Enabled ~= b.Enabled then
				return a.Enabled
			end
			return a.Name < b.Name
		end)

		local signature = tostring(showKeys)
		for _, entry in entries do
			signature ..= entry.Name..entry.Keys..tostring(entry.Enabled)..';'
		end
		if signature == lastSignature and not force then return end
		lastSignature = signature

		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)

		local accent = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		for i, entry in entries do
			local row = Instance.new('TextLabel')
			row.Name = entry.Name
			row.Size = UDim2.new(1, -20, 0, 16)
			row.Position = UDim2.fromOffset(10, 24 + (i - 1) * 17)
			row.BackgroundTransparency = 1
			row.Text = entry.Name
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextTruncate = Enum.TextTruncate.AtEnd
			row.TextColor3 = entry.Enabled and accent or color.Dark(uipallet.Text, 0.16)
			row.TextSize = 12
			row.FontFace = uipallet.Font
			row.Parent = bg
			if showKeys then
				-- Render the bind as a bright key-cap chip instead of dim grey text.
				-- The old faint right-aligned label was the "hard to see the keybind"
				-- complaint; a chip with a subtle background and semi-bold, full
				-- brightness text (accent when the module is live) reads clearly.
				local keytext = entry.Keys
				local width = math.max(getfontsize(keytext, 11, uipallet.FontSemiBold, Vector2.new(100000, 100000)).X + 12, 18)
				local keychip = Instance.new('Frame')
				keychip.Name = 'Key'
				keychip.AnchorPoint = Vector2.new(1, 0.5)
				keychip.Position = UDim2.new(1, 0, 0.5, 0)
				keychip.Size = UDim2.fromOffset(width, 15)
				keychip.BackgroundColor3 = color.Light(uipallet.Main, 0.1)
				keychip.BackgroundTransparency = 0.1
				keychip.BorderSizePixel = 0
				keychip.Parent = row
				addCorner(keychip, UDim.new(0, 4))
				local keylabel = Instance.new('TextLabel')
				keylabel.Name = 'Label'
				keylabel.Size = UDim2.fromScale(1, 1)
				keylabel.BackgroundTransparency = 1
				keylabel.Text = keytext
				keylabel.TextColor3 = entry.Enabled and accent or uipallet.Text
				keylabel.TextSize = 11
				keylabel.FontFace = uipallet.FontSemiBold
				keylabel.Parent = keychip
			end
			table.insert(rows, row)
		end
		listTitle.Text = #entries > 0 and 'KEYBINDS' or 'KEYBINDS - NONE BOUND'
		bg.Size = UDim2.new(1, 0, 0, 30 + #entries * 17)
	end

	local overlay = mainapi:CreateOverlay({
		Name = 'Keybinds',
		Icon = getcustomasset('aetherv2/assets/new/bind.png'),
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(12, 13),
		Color = true,
		Function = function(callback)
			if callback then
				local overlayapi = mainapi.Categories.Keybinds
				overlayapi:Clean(task.spawn(function()
					while true do
						refresh()
						task.wait(0.5)
					end
				end))
			end
		end
	})
	local holder = overlay.Children

	bg = Instance.new('Frame')
	bg.Name = 'KeybindsBkg'
	bg.Size = UDim2.new(1, 0, 0, 30)
	bg.Position = UDim2.fromOffset(0, 4)
	bg.BackgroundColor3 = uipallet.Main
	bg.BorderSizePixel = 0
	bg.Parent = holder
	addBlur(bg)
	addCorner(bg)
	listTitle = Instance.new('TextLabel')
	listTitle.Name = 'Title'
	listTitle.Size = UDim2.new(1, -20, 0, 14)
	listTitle.Position = UDim2.fromOffset(10, 7)
	listTitle.BackgroundTransparency = 1
	listTitle.Text = 'KEYBINDS'
	listTitle.TextXAlignment = Enum.TextXAlignment.Left
	listTitle.TextColor3 = color.Dark(uipallet.Text, 0.25)
	listTitle.TextSize = 10
	listTitle.FontFace = uipallet.Font
	listTitle.Parent = bg

	overlay:CreateToggle({
		Name = 'Only enabled modules',
		Function = function(callback)
			onlyEnabled = callback
			refresh(true)
		end
	})
	overlay:CreateToggle({
		Name = 'Show key names',
		Default = true,
		Function = function(callback)
			showKeys = callback
			refresh(true)
		end
	})
	refresh(true)
end

--[[
	=====================================================================
	Visual feature pack (v5.3) - flashy, user-facing GUI additions.

	Runs once, after the whole GUI is built, and is entirely self-contained
	(no backend contracts touched). Three headline features - a Spotlight
	command palette, one-click Theme presets and a staggered open cascade -
	plus a cluster of smaller visible touches (per-category enabled counts,
	a live enabled counter, enable glow rings, accent-tinted scrollbars, a
	breathing window edge, per-category open pops and a collapse-all button).
	=====================================================================

	Written as a function that is called immediately rather than a plain `do`
	block. Luau gives every function 200 local registers, and locals in a bare
	block share the registers of the chunk they sit in - this file already
	declares over 160 at the top level, so the last few locals down here pushed
	the main chunk past the limit and the WHOLE FILE failed to compile ("Out of
	local registers when trying to allocate themeSwatch"), which is what made
	the GUI throw on load and uninject. Its own function body means this pack
	gets its own register budget, and adding to it can never take the file down
	again.
	=====================================================================
]]
;(function()
	local function accent()
		return Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
	end
	-- ScreenGui is ZIndexBehavior.Global, so raise a whole overlay above the rest.
	local function raiseZ(root, z)
		root.ZIndex = z
		for _, d in root:GetDescendants() do
			if d:IsA('GuiObject') then
				d.ZIndex = z
			end
		end
	end

	-- Smoothly cross-fades the whole GUI accent to a target HSV (used by the
	-- theme presets). Steps SetValue so every module retints along the way.
	local recolorThread
	local function smoothAccent(th, ts, tv)
		if recolorThread then
			pcall(task.cancel, recolorThread)
			recolorThread = nil
		end
		if mainapi.GUIColor.Rainbow then
			pcall(function() mainapi.GUIColor:Toggle() end)
		end
		local sh, ss, sv = mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value
		recolorThread = task.spawn(function()
			for i = 1, 12 do
				local a = i / 12
				pcall(function()
					mainapi.GUIColor:SetValue(sh + (th - sh) * a, ss + (ts - ss) * a, sv + (tv - sv) * a)
				end)
				task.wait()
			end
			recolorThread = nil
			-- Also drive the theme onto module colours (Killaura target boxes, ESP,
			-- particles, ...) once the accent settles, if that setting is on.
			pcall(function() mainapi:ApplyThemeToModules(th, ts, tv) end)
		end)
	end

	-- One-shot accent ring that swells off a module row when it turns on.
	local function enableGlow(row)
		if typeof(row) ~= 'Instance' or not row.Parent then return end
		local old = row:FindFirstChild('EnableGlow')
		if old then old:Destroy() end
		local ring = Instance.new('UIStroke')
		ring.Name = 'EnableGlow'
		ring.Color = accent()
		ring.Thickness = 1
		ring.Transparency = 0.2
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Parent = row
		tweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Thickness = 6
		}):Play()
		task.delay(0.5, function() ring:Destroy() end)
	end

	-- =====================================================================
	-- MASSIVE 1 - Spotlight command palette (type to toggle any module)
	-- =====================================================================
	local spotOpen = false
	local spotRows, firstMatch = {}, nil

	local spotBackdrop = Instance.new('TextButton')
	spotBackdrop.Name = 'NexusSpotlight'
	spotBackdrop.Size = UDim2.fromScale(1, 1)
	spotBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	spotBackdrop.BackgroundTransparency = 1
	spotBackdrop.AutoButtonColor = false
	spotBackdrop.Text = ''
	spotBackdrop.Visible = false
	spotBackdrop.Parent = scaledgui

	local spotCard = Instance.new('TextButton')
	spotCard.Name = 'Card'
	-- Sized for the whole module list plus an expanded details panel underneath a row, and
	-- anchored dead centre. The old card was both small enough that details pushed everything
	-- out of view and hung above the middle of the screen at 0.42.
	spotCard.Size = UDim2.fromOffset(660, 560)
	spotCard.Position = UDim2.fromScale(0.5, 0.5)
	spotCard.AnchorPoint = Vector2.new(0.5, 0.5)
	spotCard.BackgroundColor3 = uipallet.Main
	spotCard.BackgroundTransparency = 0.02
	spotCard.AutoButtonColor = false
	spotCard.Text = ''
	spotCard.Parent = spotBackdrop
	addCorner(spotCard, UDim.new(0, 12))
	local spotStroke = Instance.new('UIStroke')
	spotStroke.Color = accent()
	spotStroke.Thickness = 1
	spotStroke.Transparency = 0.4
	spotStroke.Parent = spotCard
	local spotScale = Instance.new('UIScale')
	spotScale.Parent = spotCard

	local spotIcon = Instance.new('ImageLabel')
	spotIcon.Size = UDim2.fromOffset(16, 16)
	spotIcon.Position = UDim2.fromOffset(16, 17)
	spotIcon.BackgroundTransparency = 1
	spotIcon.Image = getcustomasset('aetherv2/assets/new/search.png')
	spotIcon.ImageColor3 = accent()
	spotIcon.Parent = spotCard
	local spotSearch = Instance.new('TextBox')
	spotSearch.Size = UDim2.new(1, -270, 0, 50)
	spotSearch.Position = UDim2.fromOffset(42, 0)
	spotSearch.BackgroundTransparency = 1
	spotSearch.Text = ''
	spotSearch.PlaceholderText = 'Toggle a module...'
	spotSearch.PlaceholderColor3 = color.Dark(uipallet.Text, 0.5)
	spotSearch.TextXAlignment = Enum.TextXAlignment.Left
	spotSearch.TextColor3 = uipallet.Text
	spotSearch.TextSize = 16
	spotSearch.FontFace = uipallet.FontSemiBold
	spotSearch.ClearTextOnFocus = false
	spotSearch.Parent = spotCard
	local spotHint = Instance.new('TextLabel')
	spotHint.Size = UDim2.fromOffset(210, 16)
	spotHint.Position = UDim2.new(1, -218, 0, 17)
	spotHint.BackgroundTransparency = 1
	spotHint.Text = 'Enter toggles • right-click for details'
	spotHint.TextXAlignment = Enum.TextXAlignment.Right
	spotHint.TextColor3 = color.Dark(uipallet.Text, 0.5)
	spotHint.TextSize = 10
	spotHint.FontFace = uipallet.Font
	spotHint.Parent = spotCard
	local spotDivider = Instance.new('Frame')
	spotDivider.Size = UDim2.new(1, -24, 0, 1)
	spotDivider.Position = UDim2.fromOffset(12, 50)
	spotDivider.BackgroundColor3 = Color3.new(1, 1, 1)
	spotDivider.BackgroundTransparency = 0.9
	spotDivider.BorderSizePixel = 0
	spotDivider.Parent = spotCard
	local spotResults = Instance.new('ScrollingFrame')
	spotResults.Name = 'Results'
	spotResults.Size = UDim2.new(1, -8, 1, -60)
	spotResults.Position = UDim2.fromOffset(4, 56)
	spotResults.BackgroundTransparency = 1
	spotResults.BorderSizePixel = 0
	spotResults.ScrollBarThickness = 3
	spotResults.ScrollBarImageColor3 = accent()
	spotResults.ScrollBarImageTransparency = 0.5
	spotResults.CanvasSize = UDim2.new()
	spotResults.AutomaticCanvasSize = Enum.AutomaticSize.Y
	spotResults.Parent = spotCard
	local spotList = Instance.new('UIListLayout')
	spotList.SortOrder = Enum.SortOrder.LayoutOrder
	spotList.Padding = UDim.new(0, 2)
	spotList.Parent = spotResults

	--[[
		Module details, read once from libraries/details.json.

		Shape: {"ModuleName": {"lines": ["..."], "requires": ["..."]}}. A plain array of strings
		is accepted as shorthand for `lines`. Missing entries just mean the panel says so, so a
		module added after the file was written degrades to a note rather than an error.
	]]
	local detailsData, detailsLoaded = {}, false
	local function moduleDetails(name)
		if not detailsLoaded then
			detailsLoaded = true
			-- Pulled from the repo on first use and cached like every other asset, so no loader
			-- manifest has to know about it.
			pcall(function()
				local parsed = httpService:JSONDecode(downloadFile('aetherv2/libraries/details.json'))
				if type(parsed) == 'table' then detailsData = parsed end
			end)
		end
		local entry = detailsData[name]
		if type(entry) == 'table' and entry[1] ~= nil and entry.lines == nil then
			entry = {lines = entry}
		end
		return type(entry) == 'table' and entry or nil
	end

	-- One expandable panel per row, built the first time that row is right-clicked.
	local function buildDetailsPanel(name, order)
		local entry = moduleDetails(name)
		local panel = Instance.new('Frame')
		panel.Name = 'Details'
		panel.Size = UDim2.new(1, -16, 0, 0)
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.BackgroundColor3 = color.Light(uipallet.Main, 0.03)
		panel.BorderSizePixel = 0
		panel.LayoutOrder = order
		panel.Parent = spotResults
		addCorner(panel, UDim.new(0, 6))
		local pad = Instance.new('UIPadding')
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = panel
		local list = Instance.new('UIListLayout')
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 4)
		list.Parent = panel

		local function line(text, colour, size, layout)
			local label = Instance.new('TextLabel')
			label.Size = UDim2.new(1, 0, 0, 0)
			label.AutomaticSize = Enum.AutomaticSize.Y
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextWrapped = true
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.TextColor3 = colour
			label.TextSize = size
			label.FontFace = uipallet.Font
			label.LayoutOrder = layout
			label.Parent = panel
			return label
		end

		local order2 = 0
		if entry then
			for _, text in (entry.lines or {}) do
				order2 += 1
				line(tostring(text), color.Dark(uipallet.Text, 0.12), 12, order2)
			end
			if entry.requires and #entry.requires > 0 then
				order2 += 1
				local heading = line('REQUIRES', accent(), 10, order2)
				heading.FontFace = uipallet.FontSemiBold
				for _, text in entry.requires do
					order2 += 1
					line('• '..tostring(text), color.Dark(uipallet.Text, 0.4), 12, order2)
				end
			end
		end
		if order2 == 0 then
			line('No details recorded for this module yet.', color.Dark(uipallet.Text, 0.5), 12, 1)
		end
		return panel
	end

	local function refreshSpot(query)
		for _, r in spotRows do r:Destroy() end
		table.clear(spotRows)
		firstMatch = nil
		query = (query or ''):lower()
		local matches = {}
		local function collect(source, fallbackCategory)
			for name, m in source do
				if query == '' or name:lower():find(query, 1, true) then
					table.insert(matches, {Module = m, Name = name, Category = m.Category or m.ApiCategory or fallbackCategory})
				end
			end
		end
		collect(mainapi.Modules)
		-- Legit modules live in their own table, so half the menu never showed up here.
		collect(mainapi.Legit and mainapi.Legit.Modules or {}, 'Legit')
		table.sort(matches, function(a, b) return a.Name < b.Name end)
		firstMatch = matches[1] and matches[1].Module or nil
		-- Every match is listed. The old build stopped at eighty, which with an empty query cut
		-- the list off well before the end of the menu.
		for i, match in matches do
			local m = match.Module
			local row = Instance.new('TextButton')
			row.Name = m.Name
			row.Size = UDim2.new(1, 0, 0, 30)
			row.BackgroundColor3 = Color3.new(1, 1, 1)
			row.BackgroundTransparency = 1
			row.AutoButtonColor = false
			row.Text = ''
			-- Two slots per match, so a details panel can sit directly under its own row.
			row.LayoutOrder = i * 2
			row.Parent = spotResults
			addCorner(row, UDim.new(0, 6))
			local dot = Instance.new('Frame')
			dot.Name = 'Dot'
			dot.Size = UDim2.fromOffset(7, 7)
			dot.Position = UDim2.new(0, 14, 0.5, -3)
			dot.BorderSizePixel = 0
			dot.BackgroundColor3 = m.Enabled and accent() or color.Light(uipallet.Main, 0.22)
			dot.Parent = row
			addCorner(dot, UDim.new(1, 0))
			local nm = Instance.new('TextLabel')
			nm.Size = UDim2.new(1, -130, 1, 0)
			nm.Position = UDim2.fromOffset(30, 0)
			nm.BackgroundTransparency = 1
			nm.Text = m.Name
			nm.TextXAlignment = Enum.TextXAlignment.Left
			nm.TextColor3 = color.Dark(uipallet.Text, 0.1)
			nm.TextSize = 13
			nm.FontFace = uipallet.Font
			nm.Parent = row
			local cat = Instance.new('TextLabel')
			cat.Size = UDim2.new(0, 96, 1, 0)
			cat.Position = UDim2.new(1, -104, 0, 0)
			cat.BackgroundTransparency = 1
			cat.Text = match.Category or ''
			cat.TextXAlignment = Enum.TextXAlignment.Right
			cat.TextColor3 = color.Dark(uipallet.Text, 0.5)
			cat.TextSize = 11
			cat.FontFace = uipallet.Font
			cat.Parent = row
			row.MouseEnter:Connect(function()
				tween:Tween(row, uipallet.Tween, {BackgroundTransparency = 0.94})
			end)
			row.MouseLeave:Connect(function()
				tween:Tween(row, uipallet.Tween, {BackgroundTransparency = 1})
			end)
			row.MouseButton1Click:Connect(function()
				m:Toggle()
				dot.BackgroundColor3 = m.Enabled and accent() or color.Light(uipallet.Main, 0.22)
				task.defer(function()
					if spotOpen then spotSearch:CaptureFocus() end
				end)
			end)
			-- Right click opens what the module actually does, straight under its row.
			local panel
			row.MouseButton2Click:Connect(function()
				if panel then
					panel:Destroy()
					panel = nil
					return
				end
				panel = buildDetailsPanel(match.Name, (i * 2) + 1)
				table.insert(spotRows, panel)
				if spotOpen then
					raiseZ(panel, 41)
				end
			end)
			table.insert(spotRows, row)
		end
		spotHint.Visible = firstMatch ~= nil
		-- Rows are built after the card was raised, so lift the fresh ones too
		-- (ZIndexBehavior.Global means each needs its own high ZIndex).
		if spotOpen then
			raiseZ(spotResults, 41)
		end
	end

	local function openSpot()
		if spotOpen then return end
		spotOpen = true
		raiseZ(spotBackdrop, 40)
		raiseZ(spotCard, 41)
		spotStroke.Color = accent()
		spotIcon.ImageColor3 = accent()
		spotBackdrop.Visible = true
		spotBackdrop.BackgroundTransparency = 1
		tween:Tween(spotBackdrop, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.45})
		spotScale.Scale = 0.92
		tweenService:Create(spotScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		spotSearch.Text = ''
		refreshSpot('')
		task.defer(function() spotSearch:CaptureFocus() end)
	end
	local function closeSpot()
		if not spotOpen then return end
		spotOpen = false
		pcall(function() spotSearch:ReleaseFocus() end)
		tween:Tween(spotBackdrop, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
		task.delay(0.2, function()
			if not spotOpen then spotBackdrop.Visible = false end
		end)
	end
	mainapi.OpenSpotlight = openSpot

	spotBackdrop.MouseButton1Click:Connect(closeSpot)
	-- Coalesced: the list is every module in the menu now, so rebuilding it on each keystroke
	-- of a fast query is real work to throw away.
	local spotQueryToken = 0
	spotSearch:GetPropertyChangedSignal('Text'):Connect(function()
		spotQueryToken += 1
		local token = spotQueryToken
		task.delay(0.05, function()
			if token == spotQueryToken then
				refreshSpot(spotSearch.Text)
			end
		end)
	end)
	spotSearch.FocusLost:Connect(function(enter)
		if enter and firstMatch then
			firstMatch:Toggle()
			refreshSpot(spotSearch.Text)
			task.defer(function()
				if spotOpen then spotSearch:CaptureFocus() end
			end)
		end
	end)
	-- Backquote (`) toggles Spotlight from anywhere the GUI isn't capturing text.
	mainapi:Clean(inputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Backquote and not inputService:GetFocusedTextBox() then
			if spotOpen then closeSpot() else openSpot() end
		elseif input.KeyCode == Enum.KeyCode.Escape and spotOpen then
			closeSpot()
		end
	end))

	-- =====================================================================
	-- MASSIVE 2 - Theme presets (one click recolours the whole GUI)
	-- =====================================================================
	local themePresets = {
		{Name = 'Ocean', H = 0.58, S = 0.72, V = 1.00},
		{Name = 'Sunset', H = 0.035, S = 0.78, V = 1.00},
		{Name = 'Grape', H = 0.78, S = 0.60, V = 1.00},
		{Name = 'Matrix', H = 0.34, S = 0.82, V = 0.95},
		{Name = 'Rose', H = 0.94, S = 0.55, V = 1.00},
		{Name = 'Gold', H = 0.12, S = 0.82, V = 1.00},
		{Name = 'Mono', H = 0.60, S = 0.05, V = 0.95}
	}

	local themeOpen = false
	local themePopover = Instance.new('Frame')
	themePopover.Name = 'NexusThemes'
	themePopover.Size = UDim2.fromOffset(180, 20 + (#themePresets + 1) * 30 + 10)
	themePopover.Position = UDim2.new(1, -60, 0, 60)
	themePopover.AnchorPoint = Vector2.new(1, 0)
	themePopover.BackgroundColor3 = uipallet.Main
	themePopover.BackgroundTransparency = 0.02
	themePopover.BorderSizePixel = 0
	themePopover.Visible = false
	themePopover.Parent = clickgui
	addCorner(themePopover, UDim.new(0, 10))
	local themeStroke = Instance.new('UIStroke')
	themeStroke.Color = Color3.new(1, 1, 1)
	themeStroke.Transparency = 0.9
	themeStroke.Parent = themePopover
	local themeTitle = Instance.new('TextLabel')
	themeTitle.Size = UDim2.new(1, -20, 0, 20)
	themeTitle.Position = UDim2.fromOffset(12, 6)
	themeTitle.BackgroundTransparency = 1
	themeTitle.Text = 'THEMES'
	themeTitle.TextXAlignment = Enum.TextXAlignment.Left
	themeTitle.TextColor3 = color.Dark(uipallet.Text, 0.4)
	themeTitle.TextSize = 10
	themeTitle.FontFace = uipallet.FontSemiBold
	themeTitle.Parent = themePopover
	local themeScale = Instance.new('UIScale')
	themeScale.Parent = themePopover
	-- Rows live in their own body frame so the title stays put (a UIListLayout on
	-- the popover itself would sweep the title into the row flow).
	local themeBody = Instance.new('Frame')
	themeBody.Name = 'Body'
	themeBody.Size = UDim2.new(1, 0, 1, -28)
	themeBody.Position = UDim2.fromOffset(0, 26)
	themeBody.BackgroundTransparency = 1
	themeBody.Parent = themePopover

	local function themeRow(labelText, swatchColor, layout, onClick)
		local row = Instance.new('TextButton')
		row.Size = UDim2.new(1, -12, 0, 28)
		row.Position = UDim2.fromOffset(6, 0)
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.BackgroundTransparency = 1
		row.AutoButtonColor = false
		row.Text = ''
		row.LayoutOrder = layout
		row.Parent = themeBody
		addCorner(row, UDim.new(0, 6))
		local chip = Instance.new('Frame')
		chip.Size = UDim2.fromOffset(16, 16)
		chip.Position = UDim2.new(0, 8, 0.5, -8)
		chip.BackgroundColor3 = swatchColor
		chip.BorderSizePixel = 0
		chip.Parent = row
		addCorner(chip, UDim.new(1, 0))
		local lbl = Instance.new('TextLabel')
		lbl.Size = UDim2.new(1, -36, 1, 0)
		lbl.Position = UDim2.fromOffset(32, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = labelText
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = color.Dark(uipallet.Text, 0.12)
		lbl.TextSize = 13
		lbl.FontFace = uipallet.Font
		lbl.Parent = row
		row.MouseEnter:Connect(function()
			tween:Tween(row, uipallet.Tween, {BackgroundTransparency = 0.92})
		end)
		row.MouseLeave:Connect(function()
			tween:Tween(row, uipallet.Tween, {BackgroundTransparency = 1})
		end)
		row.MouseButton1Click:Connect(onClick)
		return chip
	end
	local themeLayout = Instance.new('UIListLayout')
	themeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	themeLayout.Padding = UDim.new(0, 2)
	themeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	themeLayout.Parent = themeBody
	for i, preset in themePresets do
		themeRow(preset.Name, Color3.fromHSV(preset.H, preset.S, preset.V), i, function()
			smoothAccent(preset.H, preset.S, preset.V)
		end)
	end
	-- Rainbow row toggles the accent cycle.
	themeRow('Rainbow', Color3.fromRGB(232, 96, 152), #themePresets + 1, function()
		pcall(function() mainapi.GUIColor:Toggle() end)
	end)

	-- =====================================================================
	-- Toolbar (top-right): Spotlight + Themes quick buttons.
	local toolbar = Instance.new('Frame')
	toolbar.Name = 'NexusToolbar'
	toolbar.Size = UDim2.fromOffset(38, 10)
	toolbar.AutomaticSize = Enum.AutomaticSize.Y
	toolbar.Position = UDim2.new(1, -12, 0, 60)
	toolbar.AnchorPoint = Vector2.new(1, 0)
	toolbar.BackgroundTransparency = 1
	toolbar.Parent = clickgui
	local toolbarList = Instance.new('UIListLayout')
	toolbarList.SortOrder = Enum.SortOrder.LayoutOrder
	toolbarList.Padding = UDim.new(0, 8)
	toolbarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toolbarList.Parent = toolbar

	local function makeToolButton(order, iconAsset, glyph, tip)
		local btn = Instance.new('TextButton')
		btn.Name = 'Tool'..order
		btn.Size = UDim2.fromOffset(38, 38)
		btn.LayoutOrder = order
		btn.BackgroundColor3 = uipallet.Main
		btn.AutoButtonColor = false
		btn.Text = ''
		btn.ZIndex = 8
		btn.Parent = toolbar
		local blur = addBlur(btn)
		blur.ZIndex = 7
		addCorner(btn, UDim.new(0, 10))
		addTooltip(btn, tip)
		local content
		if iconAsset then
			content = Instance.new('ImageLabel')
			content.Size = UDim2.fromOffset(16, 16)
			content.Image = getcustomasset(iconAsset)
			content.ImageColor3 = color.Light(uipallet.Main, 0.5)
			content.BackgroundTransparency = 1
		else
			content = Instance.new('Frame')
			content.Size = UDim2.fromOffset(16, 16)
			content.BackgroundColor3 = accent()
			addCorner(content, UDim.new(1, 0))
		end
		content.Name = 'Icon'
		content.Position = UDim2.fromOffset(11, 11)
		content.ZIndex = 9
		content.Parent = btn
		if glyph then
			local g = Instance.new('TextLabel')
			g.Size = UDim2.fromScale(1, 1)
			g.BackgroundTransparency = 1
			g.Text = glyph
			g.TextColor3 = color.Light(uipallet.Main, 0.5)
			g.TextSize = 18
			g.FontFace = uipallet.FontSemiBold
			g.ZIndex = 9
			g.Parent = btn
			content = g
		end
		btn.MouseEnter:Connect(function()
			tween:Tween(btn, uipallet.Tween, {BackgroundColor3 = color.Light(uipallet.Main, 0.05)})
		end)
		btn.MouseLeave:Connect(function()
			tween:Tween(btn, uipallet.Tween, {BackgroundColor3 = uipallet.Main})
		end)
		return btn, content
	end

	local spotBtn = makeToolButton(1, 'aetherv2/assets/new/search.png', nil, 'Spotlight - quick toggle any module (`)')
	spotBtn.MouseButton1Click:Connect(function()
		if spotOpen then closeSpot() else openSpot() end
	end)
	local themeBtn, themeSwatch = makeToolButton(2, nil, nil, 'Themes - recolour the GUI')
	themeBtn.MouseButton1Click:Connect(function()
		themeOpen = not themeOpen
		if themeOpen then
			raiseZ(themePopover, 12)
			themeStroke.Color = accent()
			themePopover.Visible = true
			themeScale.Scale = 0.9
			tweenService:Create(themeScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		else
			themePopover.Visible = false
		end
	end)

	-- Glow ring: enabling a module (click OR keybind) flashes an accent ring off
	-- its row. This is the only "small touch" kept from the old visual pack.
	for _, m in mainapi.Modules do
		local origToggle = m.Toggle
		m.Toggle = function(self, ...)
			local before = self.Enabled
			origToggle(self, ...)
			if self.Enabled and not before then
				enableGlow(self.Object)
			end
		end
	end

	-- Closing the menu dismisses the Spotlight (it lives on the scaled root, not
	-- inside the menu) and the theme popover, so nothing lingers over the game.
	mainapi:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		if not clickgui.Visible then
			if spotOpen then closeSpot() end
			if themeOpen then
				themeOpen = false
				themePopover.Visible = false
			end
		end
	end))

	-- Keep the spotlight/theme button accents in sync after a theme change.
	mainapi.RefreshVisualPack = function()
		pcall(function()
			if themeSwatch then themeSwatch.BackgroundColor3 = accent() end
			spotStroke.Color = accent()
			spotIcon.ImageColor3 = accent()
		end)
	end
end)()

-- Simple, reliable open animation. Every visible window pops from 0.94 -> 1 the
-- instant the menu opens - no stagger and no per-window visibility gating, so
-- every category pops the same way. (The old "Cascade" mode set every window to
-- a shrunk scale up front and only tweened each back after a delayed, Visible-
-- gated callback, which left some categories stuck small and others lagging -
-- the "only some pop / some just stay" bug.)
do
	local openInfo = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	mainapi:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		if not clickgui.Visible then return end
		for _, v in mainapi.Categories do
			local win = v.Object
			if v.Type ~= 'Overlay' and typeof(win) == 'Instance' and win.Visible then
				local openscale = win:FindFirstChild('OpenScale')
				if not openscale then
					openscale = Instance.new('UIScale')
					openscale.Name = 'OpenScale'
					openscale.Parent = win
				end
				openscale.Scale = 0.94
				tween:Tween(openscale, openInfo, {Scale = 1})
			end
		end
	end))
end

return mainapi
