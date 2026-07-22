--[[
	AetherV2 "Nexus" GUI (newer.lua) - v5.0

	A glass-morphism redesign of the AetherV2 interface. Fully compatible with
	the existing AetherV2 backend: same asset table, keybind system, module API
	(CreateCategory / CreateModule / CreateToggle / CreateSlider / ...), config
	save & load format, and overlay system as guis/new.lua.

	Visual language:
	 - Deep navy/charcoal base (#0E1117 / #1A1F2A) with a single muted accent
	   (#4A8DFF by default, adjustable via the GUI Theme slider).
	 - Frosted glass panels: sliced blur.png backdrops + translucent surfaces
	   (see uipallet.Glass and the glass registry inside addBlur).
	 - Clean sans-serif typography (Gotham), 8px corner radius, soft shadows.
	 - 0.16s Quad/Out micro-interactions everywhere (uipallet.Tween).

	Nexus additions on top of the classic API:
	 - Stats Dashboard  : live counters + last-10-games history graph
	                      (mainapi.Stats, persisted to aetherv2/profiles/stats.json).
	 - Plugin system    : mainapi:RegisterPlugin(name, pluginTable) lets third
	                      parties add categories, overlays and stat types.
	                      Files in aetherv2/plugins/*.lua are auto-loaded.
	 - Theme Editor     : real-time glass intensity, font face and base theme
	                      adjustment (Settings -> Theme).

	New in v5.1 - deep interface customisation (see mainapi.Nexus):
	 - Custom hover     : selectable hover style (Underline / Outline /
	                      Brighten / None), intensity, lift (scale pop), hover
	                      sounds and click pulses on every control
	                      (Settings -> Interface).
	 - Custom positioning: window dragging gains edge + window-to-window
	                      snapping with alignment guides, grid snapping, drag
	                      smoothing, keep-on-screen clamping and a window lock,
	                      plus tile/cascade arrangement and named layouts saved
	                      to aetherv2/profiles/layouts.json (Settings -> Windows).
	 - Custom settings  : live corner radius, animation speed + easing style,
	                      tooltip delay/anchoring, UI sound pack with volume,
	                      window open animation, and notification position /
	                      duration / stack size / sound (Settings ->
	                      Interface, Windows and Notifications).
	 - Watermark        : pinnable overlay with FPS, ping and clock segments
	                      (Overlays -> Watermark).
	 - Keybind HUD      : pinnable overlay listing bound modules and their
	                      keys, live enabled highlighting (Overlays -> Keybinds).
	 - Favourites polish: the star chip, gold border trim and pulse ring are
	                      fully animated (hover scale, fade in/out, swelling
	                      ring) and share one gold accent.
]]
local license = ... or {}
local mainapi = {
	Categories = {},
	GUIColor = {
		Hue = 0.605,
		Sat = 0.71,
		Value = 1
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
	Version = '5.1',
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
	-- Nexus palette: deep navy base (#0E1117), soft blue-grey text. Surfaces are
	-- derived from Main via color.Light/Dark so #1A1F2A appears as raised cards.
	Main = Color3.fromRGB(14, 17, 23),
	Text = Color3.fromRGB(214, 220, 232),
	Font = Font.fromEnum(Enum.Font.Gotham),
	FontSemiBold = Font.fromEnum(Enum.Font.Gotham, Enum.FontWeight.SemiBold),
	Tween = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	-- Glass-morphism levels: transparency applied to blurred panels (windows,
	-- tooltips, notifications). Adjustable live from Settings -> Theme.
	Glass = 0.15
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
	OpenAnim = 'Pop',
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
local cornerRadius = 8

local function addCorner(parent, radius)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = radius or UDim.new(0, cornerRadius)
	corner.Parent = parent
	if not radius then
		cornerRegistry[corner] = true
	end

	return corner
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
downloadFile('aetherv2/profiles/features.json')
local newModules = loadJson('aetherv2/profiles/features.json') or {}
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
			Hue = optionsettings.DefaultHue or 0.44,
			Sat = optionsettings.DefaultSat or 1,
			Value = optionsettings.DefaultValue or 1,
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
		optionsettings.Color = optionsettings.Color or Color3.fromRGB(5, 134, 105)
		
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
		local semiPatched = optionsettings.SemiPatched
		if semiPatched then
			local warnbadge = Instance.new('TextLabel')
			warnbadge.Name = 'SemiPatched'
			warnbadge.Size = UDim2.fromOffset(16, 16)
			warnbadge.Position = UDim2.new(1, -54, 0, 7)
			warnbadge.BackgroundColor3 = Color3.fromRGB(232, 168, 42)
			warnbadge.Text = '!'
			warnbadge.TextColor3 = Color3.new(0, 0, 0)
			warnbadge.TextSize = 13
			warnbadge.FontFace = uipallet.Font
			warnbadge.Parent = toggle
			addCorner(warnbadge, UDim.new(1, 0))
			addTooltip(warnbadge, 'Semi-patched: '..tostring(semiPatched)..' (occasionally works but is buggy)')
		end
		local patched = optionsettings.Patched
		if patched then
			local patchbadge = Instance.new('TextLabel')
			patchbadge.Name = 'Patched'
			patchbadge.Size = UDim2.fromOffset(16, 16)
			patchbadge.Position = UDim2.new(1, semiPatched and -74 or -54, 0, 7)
			patchbadge.BackgroundColor3 = Color3.fromRGB(207, 68, 68)
			patchbadge.Text = '✗'
			patchbadge.TextColor3 = Color3.new(1, 1, 1)
			patchbadge.TextSize = 12
			patchbadge.FontFace = uipallet.Font
			patchbadge.Parent = toggle
			addCorner(patchbadge, UDim.new(1, 0))
			addTooltip(patchbadge, 'Patched: '..tostring(patched))
		end
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
					mainapi:CreateNotification('Vape', 'gui error: '.. err, 15, 'warning')
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
			if optionapi.Enabled and semiPatched then
				pcall(function()
					mainapi:CreateNotification('Semi-patched', optionsettings.Name..' is semi-patched: '..tostring(semiPatched)..'. It occasionally works but is buggy, so results may be inconsistent.', 8, 'warning')
				end)
			end
			if optionapi.Enabled and patched then
				pcall(function()
					mainapi:CreateNotification('Patched', optionsettings.Name..' is patched: '..tostring(patched)..'. It no longer works as intended.', 8, 'warning')
				end)
			end
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
			self.Modules[v].Index = i
			self.Modules[v].Object.LayoutOrder = i
			if self.Modules[v].Children then
				self.Modules[v].Children.LayoutOrder = i
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
	makeDraggable(window)
	local logo = Instance.new('ImageLabel')
	logo.Name = 'VapeLogo'
	logo.Size = UDim2.fromOffset(62, 18)
	logo.Position = UDim2.fromOffset(11, 10)
	logo.BackgroundTransparency = 1
	logo.Image = getcustomasset('aetherv2/assets/new/guivape.png')
	logo.ImageColor3 = select(3, uipallet.Main:ToHSV()) > 0.5 and uipallet.Text or Color3.new(1, 1, 1)
	logo.Parent = window
	local logov4 = Instance.new('ImageLabel')
	logov4.Name = 'V4Logo'
	logov4.Size = UDim2.fromOffset(28, 16)
	logov4.Position = UDim2.new(1, 1, 0, 1)
	logov4.BackgroundTransparency = 1
	logov4.Image = getcustomasset('aetherv2/assets/new/guiv4.png')
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

		function optionapi:Toggle()
			self.Enabled = not self.Enabled
			tween:Tween(arrow, uipallet.Tween, {
				Position = UDim2.new(1, self.Enabled and -14 or -20, 0, 16)
			})
			button.TextColor3 = self.Enabled and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or uipallet.Text
			if icon then
				icon.ImageColor3 = button.TextColor3
			end
			button.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			categorysettings.Window.Visible = self.Enabled
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
		button.MouseButton1Click:Connect(function()
			optionapi:Toggle()
		end)

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
			Notch = 5,
			Hue = 0.605,
			Sat = 0.71,
			Value = 1,
			Rainbow = false,
			CustomColor = false
		}
		local slidercolors = {
			Color3.fromRGB(250, 50, 56),
			Color3.fromRGB(242, 99, 33),
			Color3.fromRGB(252, 179, 22),
			Color3.fromRGB(5, 133, 104),
			Color3.fromRGB(47, 122, 229),
			Color3.fromRGB(126, 84, 217),
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
					optionapi:SetValue(nil, nil, nil, 5)
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
		knob.Position = UDim2.fromOffset(slidercolorpos[4] - 3, -5)
		knob.BackgroundTransparency = 1
		knob.Image = getcustomasset('aetherv2/assets/new/guislider.png')
		knob.ImageColor3 = slidercolors[4]
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
					Position = UDim2.fromOffset(slidercolorpos[4] - 3, -5)
				})
			else
				knob.Image = normalknob
				knob.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
				tween:Tween(knob, uipallet.Tween, {
					Position = UDim2.fromOffset(slidercolorpos[n or 4] - 3, -5)
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
				self:SetValue(nil, nil, nil, 5)
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

function mainapi:CreateCategory(categorysettings)
	local categoryapi = {
		Type = 'Category',
		Expanded = false
	}

	local window = Instance.new('TextButton')
	window.Name = categorysettings.Name..'Category'
	window.Size = UDim2.fromOffset(220, 41)
	window.Position = UDim2.fromOffset(236, 60)
	window.BackgroundColor3 = uipallet.Main
	window.AutoButtonColor = false
	window.Visible = false
	window.Text = ''
	window.Parent = clickgui
	addBlur(window)
	addCorner(window)
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
		mainapi:Remove(modulesettings.Name)
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

		local patchedReason = modulesettings.Patched
		local semiPatchedReason = modulesettings.SemiPatched
		local hardPatched = patchedReason and not semiPatchedReason
		local hovered = false
		local modulebutton = Instance.new('TextButton')
		modulebutton.Name = modulesettings.Name
		modulebutton.Size = UDim2.fromOffset(220, 40)
		modulebutton.BackgroundColor3 = hardPatched and color.Dark(uipallet.Main, 0.04) or uipallet.Main
		addGlass(modulebutton)
		modulebutton.BorderSizePixel = 0
		modulebutton.AutoButtonColor = false
		modulebutton.Text = '            '..modulesettings.Name
		modulebutton.TextXAlignment = Enum.TextXAlignment.Left
		modulebutton.TextColor3 = color.Dark(uipallet.Text, 0.16)
		modulebutton.TextSize = 14
		modulebutton.FontFace = uipallet.Font
		modulebutton.Parent = children
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
			if table.find(newModules, moduleapi.Name) then
				table.insert(modulesettings.Tags, 'new')
			end
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
		if patchedReason or semiPatchedReason then
			pcall(function()
				local badgetext = semiPatchedReason and 'SEMI-PATCHED' or 'PATCHED'
				local badgecolor = semiPatchedReason and Color3.fromRGB(224, 152, 44) or Color3.fromRGB(206, 66, 66)
				local size = getfontsize(badgetext, 12, uipallet.Font, Vector2.new(100000, 100000))
				local badge = Instance.new('TextLabel')
				badge.Name = 'PatchBadge'
				badge.LayoutOrder = -1
				badge.Size = UDim2.new(0, size.X + 8, 0, 16)
				badge.BackgroundColor3 = badgecolor
				badge.TextSize = 11
				badge.Text = badgetext
				badge.TextColor3 = Color3.new(1, 1, 1)
				badge.FontFace = uipallet.Font
				badge.Parent = indicatorholder
				addCorner(badge, UDim.new(0, 4))
				addTooltip(badge, tostring(semiPatchedReason or patchedReason))
			end)
		end
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
				or ((hovered or modulechildren.Visible) and color.Dark(uipallet.Text, 0.16) or color.Dark(uipallet.Text, 0.43))
			favourite.Visible = moduleapi.Favourited or hovered or modulechildren.Visible
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
			if not state then return end
			-- Soft gold ring that swells outward and dissolves on favouriting.
			local oldpulse = modulebutton:FindFirstChild('FavouritePulse')
			if oldpulse then
				oldpulse:Destroy()
			end
			local pulse = Instance.new('UIStroke')
			pulse.Name = 'FavouritePulse'
			pulse.Color = favGold
			pulse.Thickness = 1
			pulse.Transparency = 0.25
			pulse.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			pulse.Parent = modulebutton
			tweenService:Create(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				Thickness = 7
			}):Play()
			task.delay(0.55, function()
				pulse:Destroy()
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
				bgColor = rainbow and Color3.fromHSV(mainapi:Color((mainapi.GUIColor.Hue - (moduleapi.Index * 0.025)) % 1)) or Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
				txtColor = mainapi.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or mainapi:TextColor(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
				gradient.Enabled = rainbow and mainapi.RainbowMode.Value == 'Gradient'
				if gradient.Enabled then
					bgColor = Color3.new(1, 1, 1)
					gradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(mainapi:Color((mainapi.GUIColor.Hue - (moduleapi.Index * 0.025)) % 1))),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(mainapi:Color((mainapi.GUIColor.Hue - ((moduleapi.Index + 1) * 0.025)) % 1)))
					})
				end
				dots.ImageColor3 = txtColor
				bindicon.ImageColor3 = txtColor
				bindtext.TextColor3 = txtColor
			else
				txtColor = (hovered or modulechildren.Visible) and uipallet.Text or color.Dark(uipallet.Text, 0.16)
				bgColor = hardPatched and color.Dark(uipallet.Main, 0.04) or ((hovered or modulechildren.Visible) and color.Light(uipallet.Main, 0.02) or uipallet.Main)
				dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
				bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				bindtext.TextColor3 = color.Dark(uipallet.Text, 0.43)
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
			if hardPatched then
				if mainapi.Notifications and mainapi.Notifications.Enabled then
					pcall(function() mainapi:CreateNotification('Patched', moduleapi.Name..' is patched: '..tostring(patchedReason), 8, 'warning') end)
				else
					pcall(function() game:GetService('StarterGui'):SetCore('SendNotification', {Title = 'Patched', Text = moduleapi.Name..' is patched: '..tostring(patchedReason), Duration = 8}) end)
				end
				return
			end
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
			if self.Enabled and semiPatchedReason then
				pcall(function() mainapi:CreateNotification('Semi-patched', moduleapi.Name..' is semi-patched: '..tostring(semiPatchedReason)..'. It occasionally works but is buggy.', 8, 'warning') end)
			end
			task.spawn(modulesettings.Function, self.Enabled)
		end

		for i, v in components do
			moduleapi['Create'..i] = function(_, optionsettings)
				return v(optionsettings, modulechildren, moduleapi)
			end
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
			modulechildren.Visible = not modulechildren.Visible
		end)
		dotsbutton.MouseButton2Click:Connect(function()
			modulechildren.Visible = not modulechildren.Visible
		end)
		modulebutton.MouseEnter:Connect(function()
			hovered = true
			updateModuleButtonVisual()
			updateFavouriteVisual()
			bind.Visible = #moduleapi.Bind > 0 or hovered or modulechildren.Visible
		end)
		modulebutton.MouseLeave:Connect(function()
			hovered = false
			updateModuleButtonVisual()
			updateFavouriteVisual()
			bind.Visible = #moduleapi.Bind > 0 or hovered or modulechildren.Visible
		end)
		modulebutton.MouseButton1Click:Connect(function()
			moduleapi:Toggle()
		end)
		modulebutton.MouseButton2Click:Connect(function()
			modulechildren.Visible = not modulechildren.Visible
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
	categorysettings.Color = categorysettings.Color or Color3.fromRGB(5, 134, 105)

	local window = Instance.new('TextButton')
	window.Name = displayName..'CategoryList'
	window.Size = UDim2.fromOffset(220, 45)
	window.Position = UDim2.fromOffset(240, 46)
	window.BackgroundColor3 = uipallet.Main
	window.AutoButtonColor = false
	window.Visible = false
	window.Text = ''
	window.Parent = clickgui
	addBlur(window)
	addCorner(window)
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

	-- Configs only: a World-icon button to the LEFT of the cog that opens a minimal
	-- window for downloading preset configs from the repo's configs/ folder, with
	-- Download and View (credits + tags) actions.
	if categorysettings.Profiles then
		local function repoBase()
			local commit = isfile('aetherv2/profiles/commit.txt') and readfile('aetherv2/profiles/commit.txt') or 'main'
			return 'https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/configs/'
		end

		local downloadbtn = Instance.new('ImageButton')
		downloadbtn.Name = 'PresetDownload'
		downloadbtn.Size = UDim2.fromOffset(16, 16)
		downloadbtn.Position = UDim2.new(1, -74, 0, 13)
		downloadbtn.BackgroundTransparency = 1
		downloadbtn.AutoButtonColor = false
		downloadbtn.Image = getcustomasset('aetherv2/assets/new/worldicon.png')
		downloadbtn.ImageColor3 = color.Dark(uipallet.Text, 0.43)
		downloadbtn.Parent = window
		addTooltip(downloadbtn, 'Download preset configs')
		downloadbtn.MouseEnter:Connect(function() downloadbtn.ImageColor3 = uipallet.Text end)
		downloadbtn.MouseLeave:Connect(function() downloadbtn.ImageColor3 = color.Dark(uipallet.Text, 0.43) end)

		local dl = Instance.new('Frame')
		dl.Name = 'PresetDownloader'
		dl.Size = UDim2.fromOffset(340, 320)
		dl.Position = UDim2.new(0.5, -170, 0.5, -160)
		dl.BackgroundColor3 = uipallet.Main
		dl.Visible = false
		dl.Parent = scaledgui
		addBlur(dl)
		addCorner(dl)
		makeDraggable(dl)
		local dlmodal = Instance.new('TextButton')
		dlmodal.BackgroundTransparency = 1
		dlmodal.Text = ''
		dlmodal.Modal = true
		dlmodal.Parent = dl
		local dltitle = Instance.new('TextLabel')
		dltitle.Size = UDim2.new(1, -20, 0, 20)
		dltitle.Position = UDim2.fromOffset(16, 13)
		dltitle.BackgroundTransparency = 1
		dltitle.Text = 'Preset Configs'
		dltitle.TextXAlignment = Enum.TextXAlignment.Left
		dltitle.TextColor3 = uipallet.Text
		dltitle.TextSize = 14
		dltitle.FontFace = uipallet.Font
		dltitle.Parent = dl
		local dlclose = addCloseButton(dl)
		-- Live search over the preset list.
		local dlsearchbkg = Instance.new('Frame')
		dlsearchbkg.Name = 'SearchBkg'
		dlsearchbkg.Size = UDim2.new(1, -20, 0, 26)
		dlsearchbkg.Position = UDim2.fromOffset(10, 40)
		dlsearchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.03)
		dlsearchbkg.BorderSizePixel = 0
		dlsearchbkg.Parent = dl
		addGlass(dlsearchbkg)
		addCorner(dlsearchbkg)
		local dlsearch = Instance.new('TextBox')
		dlsearch.Size = UDim2.new(1, -16, 1, 0)
		dlsearch.Position = UDim2.fromOffset(8, 0)
		dlsearch.BackgroundTransparency = 1
		dlsearch.Text = ''
		dlsearch.PlaceholderText = 'Search presets (name or tag)'
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
		dlstatus.Position = UDim2.fromOffset(10, 76)
		dlstatus.BackgroundTransparency = 1
		dlstatus.Text = ''
		dlstatus.TextColor3 = color.Dark(uipallet.Text, 0.25)
		dlstatus.TextSize = 12
		dlstatus.FontFace = uipallet.Font
		dlstatus.Parent = dl
		local dllist = Instance.new('ScrollingFrame')
		dllist.Name = 'List'
		dllist.Size = UDim2.new(1, -20, 1, -86)
		dllist.Position = UDim2.fromOffset(10, 76)
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

		local downloading = {}
		local function download(preset)
			-- One request per preset at a time; double-clicking the button used
			-- to fire duplicate imports.
			if downloading[preset.file] then return end
			downloading[preset.file] = true
			mainapi:CreateNotification('Configs', 'Downloading '..tostring(preset.name)..'...', 2, 'info')
			task.spawn(function()
				local ok, res = pcall(function()
					return game:HttpGet(repoBase()..preset.file, true)
				end)
				if not ok or not res or res == '404: Not Found' then
					downloading[preset.file] = nil
					mainapi:CreateNotification('Configs', 'Failed to download '..tostring(preset.name)..'.', 7, 'alert')
					return
				end
				local suc, result = importJsonConfig(res, preset.name)
				downloading[preset.file] = nil
				if suc then
					refreshConfigProfiles()
					mainapi:CreateNotification('Configs', 'Downloaded preset '..tostring(result)..'.', 5, 'info')
				else
					mainapi:CreateNotification('Configs', tostring(result), 8, 'alert')
				end
			end)
		end

		local function view(preset)
			local tags = (preset.tags and #preset.tags > 0) and table.concat(preset.tags, ', ') or 'none'
			mainapi:CreateNotification(tostring(preset.name)..' preset', 'Credits: '..tostring(preset.credits or '?')..'\nTags: '..tags..(preset.description and ('\n'..preset.description) or ''), 9, 'info')
		end

		local function makeRow(preset)
			local row = Instance.new('Frame')
			row.Name = tostring(preset.name)
			row:SetAttribute('Tags', preset.tags and table.concat(preset.tags, ' ') or '')
			row.Size = UDim2.new(1, 0, 0, 46)
			row.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			row.Parent = dllist
			addGlass(row)
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
			tagline.TextColor3 = color.Dark(uipallet.Text, 0.25)
			tagline.TextSize = 11
			tagline.Parent = row
			local function mkbtn(text, xoff, colour, fn)
				local b = Instance.new('TextButton')
				b.Size = UDim2.fromOffset(58, 26)
				b.Position = UDim2.new(1, xoff, 0.5, -13)
				b.AnchorPoint = Vector2.new(1, 0)
				b.BackgroundColor3 = colour
				b.Text = text
				-- Contrast-aware: the Download button carries the accent colour,
				-- which can be bright enough to wash out light text.
				b.TextColor3 = mainapi:TextColor(colour:ToHSV())
				b.TextSize = 12
				b.FontFace = uipallet.Font
				b.AutoButtonColor = true
				b.Parent = row
				addCorner(b, UDim.new(0, 4))
				b.MouseButton1Click:Connect(fn)
			end
			mkbtn('View', -74, color.Light(uipallet.Main, 0.05), function() view(preset) end)
			mkbtn('Download', -10, Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value), function() download(preset) end)
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
			dlstatus.Text = 'Loading presets...'
			task.spawn(function()
				local ok, res = pcall(function()
					return game:HttpGet(repoBase()..'presets.json', true)
				end)
				refreshing = false
				if not ok or not res or res == '404: Not Found' then
					dlstatus.Text = 'Could not fetch the preset list. Check your connection and reopen.'
					mainapi:CreateNotification('Configs', 'Failed to fetch the preset list.', 7, 'alert')
					return
				end
				local decoded = select(2, pcall(function() return httpService:JSONDecode(res) end))
				if type(decoded) ~= 'table' or type(decoded.presets) ~= 'table' then
					dlstatus.Text = 'Preset list is malformed.'
					return
				end
				if #decoded.presets == 0 then
					dlstatus.Text = 'No presets available yet.'
					return
				end
				dlstatus.Text = ''
				for _, preset in decoded.presets do
					pcall(makeRow, preset)
				end
				applyFilter()
			end)
		end

		downloadbtn.MouseButton1Click:Connect(function()
			clickgui.Visible = false
			dl.Visible = true
			dl.Position = UDim2.new(0.5, -170, 0.5, -160)
			refresh()
		end)
		dlclose.MouseButton1Click:Connect(function()
			dl.Visible = false
			clickgui.Visible = true
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
	self.Categories[categorysettings.Name] = categoryapi

	return categoryapi
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
	local search = Instance.new('TextBox')
	search.Size = UDim2.new(1, -50, 0, 37)
	search.Position = UDim2.fromOffset(50, 0)
	search.BackgroundTransparency = 1
	search.Text = ''
	search.PlaceholderText = ''
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.TextColor3 = uipallet.Text
	search.TextSize = 12
	search.FontFace = uipallet.Font
	search.ClearTextOnFocus = false
	search.Parent = searchbkg
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

	children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
		divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
	end)
	legiticon.MouseButton1Click:Connect(function()
		clickgui.Visible = false
		self.Legit.Window.Visible = true
		self.Legit.Window.Position = UDim2.new(0.5, -350, 0.5, -194)
	end)
	search:GetPropertyChangedSignal('Text'):Connect(function()
		for _, v in children:GetChildren() do
			if v:IsA('TextButton') then
				v:Destroy()
			end
		end
		if search.Text == '' then return end

		for i, v in self.Modules do
			-- Plain find: the query is user text, not a Lua pattern (typing
			-- characters like '(' or '%' used to error here).
			if i:lower():find(search.Text:lower(), 1, true) then
				local button = v.Object:Clone()
				button.Bind:Destroy()
				button.MouseButton1Click:Connect(function()
					v:Toggle()
				end)

				button.MouseButton2Click:Connect(function()
					v.Object.Parent.Parent.Visible = true
					local frame = v.Object.Parent
					local highlight = Instance.new('Frame')
					highlight.Size = UDim2.fromScale(1, 1)
					highlight.BackgroundColor3 = Color3.new(1, 1, 1)
					highlight.BackgroundTransparency = 0.6
					highlight.BorderSizePixel = 0
					highlight.Parent = v.Object
					tween:Tween(highlight, TweenInfo.new(0.5), {
						BackgroundTransparency = 1
					})
					task.delay(0.5, highlight.Destroy, highlight)

					frame.CanvasPosition = Vector2.new(0, (v.Object.LayoutOrder * 40) - (math.min(frame.CanvasSize.Y.Offset, 600) / 2))
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
		mainapi:Remove(modulesettings.Name)
		local moduleapi = {
			Enabled = false,
			ApiCategory = modulesettings.Category or 'Game',
			Options = {},
			Name = modulesettings.Name,
			Legit = true
		}

		local patchedReason = modulesettings.Patched
		local module = Instance.new('TextButton')
		module.Name = modulesettings.Name
		module.BackgroundColor3 = patchedReason and color.Dark(uipallet.Main, 0.04) or color.Light(uipallet.Main, 0.02)
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
			objectstroke.Color = Color3.fromRGB(5, 134, 105)
			objectstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			objectstroke.Thickness = 0
			objectstroke.Parent = modulechildren
			moduleapi.Children = modulechildren
		end
		modulesettings.Function = modulesettings.Function or function() end
		addMaid(moduleapi)

		function moduleapi:Toggle()
			if patchedReason then
				if mainapi.Notifications and mainapi.Notifications.Enabled then
					pcall(function() mainapi:CreateNotification('Patched', moduleapi.Name..' is patched: '..tostring(patchedReason), 8, 'warning') end)
				else
					pcall(function() game:GetService('StarterGui'):SetCore('SendNotification', {Title = 'Patched', Text = moduleapi.Name..' is patched: '..tostring(patchedReason), Duration = 8}) end)
				end
				return
			end
			moduleapi.Enabled = not moduleapi.Enabled
			if moduleapi.Children then
				moduleapi.Children.Visible = moduleapi.Enabled
			end
			title.TextColor3 = moduleapi.Enabled and color.Light(uipallet.Text, 0.2) or color.Dark(uipallet.Text, 0.31)
			module.BackgroundColor3 = moduleapi.Enabled and color.Light(uipallet.Main, 0.05) or (patchedReason and color.Dark(uipallet.Main, 0.04) or color.Light(uipallet.Main, 0.02))
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
				module.BackgroundColor3 = patchedReason and color.Dark(uipallet.Main, 0.04) or color.Light(uipallet.Main, 0.05)
			end
		end)
		module.MouseLeave:Connect(function()
			if not moduleapi.Enabled then
				module.BackgroundColor3 = patchedReason and color.Dark(uipallet.Main, 0.04) or color.Light(uipallet.Main, 0.02)
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
						title = title or "Vape",
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
		self.GUIColor:SetValue(nil, nil, nil, 5)
	end
	local guidata = {}
	local savecheck = true

	if isfile('aetherv2/profiles/'..game.GameId..'.gui.txt') then
		guidata = loadJson('aetherv2/profiles/'..game.GameId..'.gui.txt')
		if not guidata then
			guidata = {Categories = {}}
			self:CreateNotification('Vape', 'Failed to load GUI settings, Try rejoining ur game', 10, 'alert')
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
					object.Button:Toggle()
				end
				if v.Pinned then
					object:Pin()
				end
				if v.Expanded and object.Expand then
					object:Expand()
				end
				if v.List and (#object.List > 0 or #v.List > 0) then
					object.List = v.List or {}
					object.ListEnabled = v.ListEnabled or {}
					object:ChangeValue()
				end
				if v.Position then
					object.Object.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
				end
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
			self:CreateNotification('Vape', 'Failed to load '..self.Profile..' profile.', 10, 'alert')
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
			if object.Button and (v.Enabled or false) ~= object.Button.Enabled then
				object.Button:Toggle()
			end
			if v.List and (#object.List > 0 or #v.List > 0) then
				object.List = v.List or {}
				object.ListEnabled = v.ListEnabled or {}
				object:ChangeValue()
			end
			object.Object.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
		end

		for i, object in self.Modules do
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
		for i, object in self.Legit.Modules do
			local v = savedata.Legit[i]
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

	for i, v in self.Categories do
		(v.Type ~= 'Category' and i ~= 'Main' and savedata or guidata).Categories[i] = {
			Enabled = i ~= 'Main' and v.Button.Enabled or nil,
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
	writefile(getConfigPath(newprofile or self.Profile), httpService:JSONEncode(savedata))
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

function mainapi:Uninject()
	mainapi:Save()
	mainapi.Loaded = nil
	for _, v in self.Modules do
		if v.Enabled then
			v:Toggle()
		end
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
end

gui = Instance.new('ScreenGui')
gui.Name = randomString()
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
mainapi:CreateCategory({
	Name = 'Render',
	Icon = getcustomasset('aetherv2/assets/new/rendericon.png'),
	Size = UDim2.fromOffset(15, 14)
})
mainapi:CreateCategory({
	Name = 'Visuals',
	Icon = getcustomasset('aetherv2/assets/new/rendertab.png'),
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
	Color = Color3.fromRGB(5, 134, 105),
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
	Tooltip = 'Paste a JSON export, then click Import JSON to create a new config.'
})
importNameBox = profiles:CreateTextBox({
	Name = 'Import Name',
	Placeholder = 'Optional config name',
	Tooltip = 'Optional name for the imported config. Invalid file characters are replaced automatically.'
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
	Tooltip = 'Imports a JSON config from the text box, or from your clipboard if the text box is empty.'
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
setmetatable(mainapi.Categories, {
	__index = function(_, key)
		if key == 'Legit' then
			return mainapi.Legit
		end
	end
})
mainapi:CreateSearch()
mainapi.Categories.Main:CreateOverlayBar()
mainapi.Categories.Main:CreateSettingsDivider()

local overhaul = {}
do
	--[[
		Aether Neo - full GUI redesign engine.

		This is not a category-border pass. When enabled it swaps the entire
		interface into a new visual language, the way a theme mode would: an
		animated multi-layer stage backdrop (gradient wash, drifting aurora
		orbs, parallax grid, rising particles, top glow and vignette), fully
		re-chromed windows (layered surface gradients, glass, accent header
		bars, side rails, outer glow and breathing strokes), redesigned module
		cards with live accent bars and hover elevation, restyled controls
		(sliders, toggles, inputs, dropdowns, buttons, scrollbars, dividers),
		restyled overlays / notifications / tooltip, a live command dock
		(brand, FPS, ping, active-module count, clock and a skin switcher),
		and a set of switchable skins.

		Everything is additive or reversible: original properties are recorded
		before they are touched and every generated instance is tracked, so
		Revert() restores Nexus byte-for-byte. Newly created descendants are
		styled on the fly, so windows opened after the toggle look native.
	]]

	local players = cloneref(game:GetService('Players'))
	local localPlayer = players.LocalPlayer

	local neo = {
		Active = false,
		SkinName = 'Nebula',
		Root = nil,
		Dock = nil,
		Fps = 60,
		Clock = 0,
		StatClock = 0,
		Connections = {},
		Hovered = setmetatable({}, {__mode = 'k'}),
		Original = setmetatable({}, {__mode = 'k'}),
		Styled = setmetatable({}, {__mode = 'k'}),
		Generated = setmetatable({}, {__mode = 'k'}),
		Windows = setmetatable({}, {__mode = 'k'}),
		Orbs = {},
		Particles = {},
		GridV = {},
		GridH = {},
		Chips = {},
		Motion = {}
	}

	------------------------------------------------------------------
	-- Skins
	------------------------------------------------------------------
	-- Each skin defines the neutral surface palette; the live accent is always
	-- taken from the GUI Theme colour so skins and accent compose.
	local skins = {
		Nebula = {
			Title = 'NEBULA',
			Stage = {Color3.fromRGB(6, 8, 18), Color3.fromRGB(14, 19, 40), Color3.fromRGB(3, 4, 11)},
			Window = Color3.fromRGB(12, 15, 28),
			WindowTop = Color3.fromRGB(30, 38, 66),
			WindowBottom = Color3.fromRGB(7, 9, 18),
			Card = Color3.fromRGB(22, 27, 46),
			CardTop = Color3.fromRGB(31, 39, 64),
			CardBottom = Color3.fromRGB(15, 19, 34),
			Input = Color3.fromRGB(8, 11, 21),
			Button = Color3.fromRGB(26, 32, 52),
			Dock = Color3.fromRGB(10, 13, 24),
			Text = Color3.fromRGB(236, 241, 253),
			SubText = Color3.fromRGB(150, 162, 197),
			Muted = Color3.fromRGB(118, 130, 166),
			Grid = Color3.fromRGB(64, 86, 158),
			AccentMix = 0.0
		},
		Obsidian = {
			Title = 'OBSIDIAN',
			Stage = {Color3.fromRGB(9, 9, 12), Color3.fromRGB(20, 20, 26), Color3.fromRGB(4, 4, 6)},
			Window = Color3.fromRGB(17, 17, 21),
			WindowTop = Color3.fromRGB(36, 36, 44),
			WindowBottom = Color3.fromRGB(10, 10, 13),
			Card = Color3.fromRGB(26, 26, 32),
			CardTop = Color3.fromRGB(35, 35, 43),
			CardBottom = Color3.fromRGB(18, 18, 23),
			Input = Color3.fromRGB(11, 11, 14),
			Button = Color3.fromRGB(30, 30, 37),
			Dock = Color3.fromRGB(14, 14, 18),
			Text = Color3.fromRGB(240, 240, 244),
			SubText = Color3.fromRGB(158, 158, 168),
			Muted = Color3.fromRGB(120, 120, 130),
			Grid = Color3.fromRGB(120, 120, 140),
			AccentMix = -0.05
		},
		Aurora = {
			Title = 'AURORA',
			Stage = {Color3.fromRGB(6, 16, 20), Color3.fromRGB(10, 30, 40), Color3.fromRGB(3, 8, 11)},
			Window = Color3.fromRGB(10, 20, 26),
			WindowTop = Color3.fromRGB(22, 48, 58),
			WindowBottom = Color3.fromRGB(6, 12, 16),
			Card = Color3.fromRGB(16, 32, 40),
			CardTop = Color3.fromRGB(24, 46, 56),
			CardBottom = Color3.fromRGB(12, 24, 30),
			Input = Color3.fromRGB(7, 15, 19),
			Button = Color3.fromRGB(20, 40, 50),
			Dock = Color3.fromRGB(9, 19, 24),
			Text = Color3.fromRGB(232, 248, 250),
			SubText = Color3.fromRGB(140, 186, 194),
			Muted = Color3.fromRGB(108, 150, 158),
			Grid = Color3.fromRGB(70, 160, 170),
			AccentMix = 0.06
		},
		Sunset = {
			Title = 'SUNSET',
			Stage = {Color3.fromRGB(20, 8, 16), Color3.fromRGB(40, 16, 30), Color3.fromRGB(9, 3, 7)},
			Window = Color3.fromRGB(24, 12, 20),
			WindowTop = Color3.fromRGB(52, 26, 42),
			WindowBottom = Color3.fromRGB(14, 7, 12),
			Card = Color3.fromRGB(36, 18, 30),
			CardTop = Color3.fromRGB(50, 26, 42),
			CardBottom = Color3.fromRGB(24, 12, 20),
			Input = Color3.fromRGB(16, 8, 13),
			Button = Color3.fromRGB(44, 22, 36),
			Dock = Color3.fromRGB(22, 11, 18),
			Text = Color3.fromRGB(252, 238, 244),
			SubText = Color3.fromRGB(200, 158, 178),
			Muted = Color3.fromRGB(168, 126, 146),
			Grid = Color3.fromRGB(190, 96, 130),
			AccentMix = 0.02
		}
	}
	local skinOrder = {'Nebula', 'Obsidian', 'Aurora', 'Sunset'}

	local function skin()
		return skins[neo.SkinName] or skins.Nebula
	end

	------------------------------------------------------------------
	-- Colour helpers
	------------------------------------------------------------------
	local WHITE = Color3.new(1, 1, 1)
	local BLACK = Color3.new(0, 0, 0)

	local function mix(a, b, t)
		return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end

	-- Positive amt lifts toward white, negative sinks toward black.
	local function shade(c, amt)
		if amt >= 0 then
			return mix(c, WHITE, amt)
		end
		return mix(c, BLACK, -amt)
	end

	local function accentColor(offset, satBoost, valBoost)
		local guiColor = mainapi.GUIColor
		local hue, sat, val = guiColor.Hue % 1, math.clamp(guiColor.Sat, 0, 1), math.clamp(guiColor.Value, 0, 1)
		if guiColor.Rainbow then
			hue, sat, val = mainapi:Color((hue + (offset or 0)) % 1)
		end
		return Color3.fromHSV((hue + (offset or 0)) % 1, math.clamp(sat + (satBoost or 0), 0, 1), math.clamp(val + (valBoost or 0), 0, 1))
	end

	-- Surface tinted slightly toward the live accent, so skins pick up the theme.
	local function surface(c)
		local m = skin().AccentMix
		if m and m ~= 0 then
			return mix(c, accentColor(0, -0.35, m < 0 and 0 or -0.1), math.abs(m))
		end
		return c
	end

	local function asset(path)
		local ok, res = pcall(getcustomasset, path)
		return ok and res or ''
	end
	local BLUR = asset('aetherv2/assets/new/blur.png')
	local BLUR_SLICE = Rect.new(52, 31, 261, 502)

	------------------------------------------------------------------
	-- Instance memory + generation
	------------------------------------------------------------------
	local function remember(inst, prop)
		if typeof(inst) ~= 'Instance' then return end
		local props = neo.Original[inst]
		if not props then
			props = {}
			neo.Original[inst] = props
		end
		if props[prop] == nil then
			pcall(function()
				props[prop] = inst[prop]
			end)
		end
	end

	local function setProp(inst, prop, value)
		remember(inst, prop)
		pcall(function()
			inst[prop] = value
		end)
	end

	local function make(className, props, parent)
		local obj = Instance.new(className)
		for prop, value in props or {} do
			obj[prop] = value
		end
		if parent then
			obj.Parent = parent
		end
		neo.Generated[obj] = true
		return obj
	end

	local function isOverhaulObject(inst)
		return neo.Generated[inst] or (typeof(inst) == 'Instance' and inst.Name:find('Neo') ~= nil)
	end

	------------------------------------------------------------------
	-- Reusable child primitives (idempotent: reused across restyles)
	------------------------------------------------------------------
	local function ensureCorner(parent, radius)
		local corner = parent:FindFirstChild('NeoCorner')
		if not corner then
			-- Reuse the object's own UICorner if it already has one, so we never
			-- leave two competing corners on a card/button/input (and Revert
			-- restores its remembered radius). Only generate one when needed.
			local existing = parent:FindFirstChildOfClass('UICorner')
			if existing then
				remember(existing, 'CornerRadius')
				existing.CornerRadius = UDim.new(0, radius)
				return existing
			end
			corner = make('UICorner', {Name = 'NeoCorner'}, parent)
		end
		corner.CornerRadius = UDim.new(0, radius)
		return corner
	end

	local function ensureStroke(parent, name, thickness, transparency, colour)
		local line = parent:FindFirstChild(name)
		if not line then
			line = make('UIStroke', {Name = name, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
		end
		line.Thickness = thickness
		line.Transparency = transparency
		line.Color = colour or accentColor()
		return line
	end

	local function ensureGradient(parent, name, rotation, colorSequence, transparency)
		local grad = parent:FindFirstChild(name)
		if not grad then
			grad = make('UIGradient', {Name = name}, parent)
		end
		grad.Rotation = rotation
		grad.Color = colorSequence
		grad.Transparency = transparency or NumberSequence.new(0)
		return grad
	end

	local function ensurePadding(parent, l, t, r, b)
		local pad = parent:FindFirstChild('NeoPadding')
		if not pad then
			pad = make('UIPadding', {Name = 'NeoPadding'}, parent)
		end
		pad.PaddingLeft = UDim.new(0, l)
		pad.PaddingTop = UDim.new(0, t or l)
		pad.PaddingRight = UDim.new(0, r or l)
		pad.PaddingBottom = UDim.new(0, b or t or l)
		return pad
	end

	-- Soft blurred glow behind a parent (uses the sliced blur asset).
	local function ensureGlow(parent, name, tint, transparency, spread, zoffset)
		local glow = parent:FindFirstChild(name)
		if not glow then
			glow = make('ImageLabel', {
				Name = name,
				BackgroundTransparency = 1,
				Image = BLUR,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = BLUR_SLICE
			}, parent)
		end
		spread = spread or 26
		glow.Size = UDim2.new(1, spread * 2, 1, spread * 2)
		glow.Position = UDim2.fromOffset(-spread, -spread)
		glow.ImageColor3 = tint
		glow.ImageTransparency = transparency
		glow.ZIndex = math.max((parent.ZIndex or 1) + (zoffset or -1), 0)
		return glow
	end

	------------------------------------------------------------------
	-- Classification
	------------------------------------------------------------------
	local function isWindow(inst)
		return inst
			and inst:IsA('GuiObject')
			and inst.Parent == clickgui
			and not isOverhaulObject(inst)
			and (inst:FindFirstChild('Blur') ~= nil or inst.Name:find('Category') or inst.Name:find('Overlay') or inst.Name == 'Search')
	end

	local function classify(inst)
		local name = inst.Name:lower()
		if isWindow(inst) then return 'Window' end
		if inst:IsA('TextBox') or name:find('textbox') or name:find('search') then return 'Input' end
		if name:find('dropdown') then return 'Dropdown' end
		if name:find('slider') or name:find('guislider') or name:find('range') then return 'Slider' end
		if name:find('toggle') or name:find('checkbox') or name:find('knob') then return 'Toggle' end
		if name:find('divider') then return 'Divider' end
		if name == 'scrollbar' or inst:IsA('ScrollingFrame') then return 'Scroll' end
		if inst:IsA('ImageButton') then return 'IconButton' end
		if inst:IsA('TextButton') then
			local parent = inst.Parent
			if name:find('module') or (parent and parent.Name:lower():find('children')) then
				return 'ModuleCard'
			end
			return 'Button'
		end
		if inst:IsA('TextLabel') then return 'Label' end
		if inst:IsA('Frame') then return 'Panel' end
		return 'Other'
	end

	------------------------------------------------------------------
	-- Typography
	------------------------------------------------------------------
	local function styleText(inst, class)
		if not (inst:IsA('TextLabel') or inst:IsA('TextButton') or inst:IsA('TextBox')) then return end
		local sk = skin()
		setProp(inst, 'FontFace', (class == 'WindowTitle' or class == 'ModuleCard') and uipallet.FontSemiBold or uipallet.Font)
		setProp(inst, 'TextColor3', class == 'Label' and sk.SubText or sk.Text)
		if inst.TextSize < 13 then
			setProp(inst, 'TextSize', 13)
		end
		if inst:IsA('TextBox') then
			setProp(inst, 'PlaceholderColor3', sk.Muted)
			setProp(inst, 'ClearTextOnFocus', false)
		end
	end

	------------------------------------------------------------------
	-- Hover interaction (elevation + glow), bound once per control
	------------------------------------------------------------------
	local function bindHover(inst, glowName)
		if neo.Hovered[inst] or not (inst:IsA('GuiButton')) then return end
		neo.Hovered[inst] = true
		local enter = inst.MouseEnter:Connect(function()
			if not neo.Active then return end
			local stroke = inst:FindFirstChild('NeoCardStroke') or inst:FindFirstChild('NeoButtonStroke')
			if stroke then
				tween:Tween(stroke, uipallet.Tween, {Transparency = 0.15})
			end
			local glow = glowName and inst:FindFirstChild(glowName)
			if glow then
				tween:Tween(glow, uipallet.Tween, {ImageTransparency = 0.55})
			end
		end)
		local leave = inst.MouseLeave:Connect(function()
			if not neo.Active then return end
			local stroke = inst:FindFirstChild('NeoCardStroke') or inst:FindFirstChild('NeoButtonStroke')
			if stroke then
				tween:Tween(stroke, uipallet.Tween, {Transparency = 0.62})
			end
			local glow = glowName and inst:FindFirstChild(glowName)
			if glow then
				tween:Tween(glow, uipallet.Tween, {ImageTransparency = 0.92})
			end
		end)
		table.insert(neo.Connections, enter)
		table.insert(neo.Connections, leave)
	end

	------------------------------------------------------------------
	-- Window chrome
	------------------------------------------------------------------
	local function raiseChild(window, childName, zindex)
		local child = window:FindFirstChild(childName)
		if child and child:IsA('GuiObject') then
			setProp(child, 'ZIndex', zindex)
		end
	end

	local function addWindowChrome(window)
		if neo.Windows[window] or isOverhaulObject(window) then return end
		neo.Windows[window] = true
		local sk = skin()

		setProp(window, 'ClipsDescendants', false)
		setProp(window, 'BackgroundColor3', surface(sk.Window))
		setProp(window, 'BorderSizePixel', 0)
		ensureCorner(window, 18)
		ensureStroke(window, 'NeoWindowStroke', 1.5, 0.34)
		ensureGradient(window, 'NeoWindowSurface', 90, ColorSequence.new({
			ColorSequenceKeypoint.new(0, surface(sk.WindowTop)),
			ColorSequenceKeypoint.new(0.5, surface(sk.Window)),
			ColorSequenceKeypoint.new(1, surface(sk.WindowBottom))
		}), NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(1, 0.22)
		}))
		ensureGlow(window, 'NeoWindowGlow', accentColor(), 0.72, 30, -2)

		-- Keep the window's own title/icon above the new header strip.
		raiseChild(window, 'Title', (window.ZIndex or 1) + 4)
		raiseChild(window, 'Icon', (window.ZIndex or 1) + 4)
		raiseChild(window, 'Arrow', (window.ZIndex or 1) + 4)

		-- Accent header strip, drawn behind the title (translucent so text is
		-- always legible even if global ZIndex behaviour changes).
		local header = window:FindFirstChild('NeoHeader')
		if not header then
			header = make('Frame', {
				Name = 'NeoHeader',
				BackgroundColor3 = accentColor(),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 0, 33),
				ZIndex = math.max((window.ZIndex or 1), 1)
			}, window)
			make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(0, 14)}, header)
			make('Frame', {
				Name = 'NeoHeaderLine',
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.72,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(12, 4),
				Size = UDim2.new(1, -24, 0, 1),
				ZIndex = header.ZIndex + 1
			}, header)
		end
		ensureGradient(header, 'NeoHeaderGradient', 0, ColorSequence.new({
			ColorSequenceKeypoint.new(0, accentColor(-0.05, 0.05, 0)),
			ColorSequenceKeypoint.new(0.5, accentColor(0.02, 0.02, 0)),
			ColorSequenceKeypoint.new(1, accentColor(0.1, 0.05, 0))
		}), NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.32),
			NumberSequenceKeypoint.new(1, 0.62)
		}))

		-- Left accent rail down the body.
		local rail = window:FindFirstChild('NeoRail')
		if not rail then
			rail = make('Frame', {
				Name = 'NeoRail',
				BackgroundColor3 = accentColor(),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 46),
				Size = UDim2.new(0, 3, 1, -58),
				ZIndex = (window.ZIndex or 1) + 2
			}, window)
			make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(1, 0)}, rail)
		end
		ensureGradient(rail, 'NeoRailGradient', 90, ColorSequence.new(accentColor(-0.05), accentColor(0.12)), NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0.5)
		}))
	end

	------------------------------------------------------------------
	-- Control styling
	------------------------------------------------------------------
	local function styleModuleCard(inst)
		local sk = skin()
		setProp(inst, 'AutoButtonColor', false)
		setProp(inst, 'BorderSizePixel', 0)
		setProp(inst, 'BackgroundColor3', surface(sk.Card))
		setProp(inst, 'BackgroundTransparency', 0.03)
		ensureCorner(inst, 13)
		ensureStroke(inst, 'NeoCardStroke', 1, 0.62)
		ensureGradient(inst, 'NeoCardGradient', 90, ColorSequence.new(surface(sk.CardTop), surface(sk.CardBottom)), NumberSequence.new(0.06))
		-- Left status pill.
		local pill = inst:FindFirstChild('NeoPill')
		if not pill then
			pill = make('Frame', {
				Name = 'NeoPill',
				BackgroundColor3 = accentColor(),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 4, 0.5, 0),
				Size = UDim2.fromOffset(3, 20),
				ZIndex = (inst.ZIndex or 1) + 1
			}, inst)
			make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(1, 0)}, pill)
		end
		ensureGlow(inst, 'NeoCardGlow', accentColor(), 0.92, 16, -1)
		bindHover(inst, 'NeoCardGlow')
	end

	local function styleButton(inst)
		local sk = skin()
		setProp(inst, 'AutoButtonColor', false)
		setProp(inst, 'BorderSizePixel', 0)
		-- Only skin buttons that actually have a visible surface. Invisible
		-- hit areas (the modal, arrow/close targets) stay untouched so we don't
		-- paint stray squares over the interface.
		if inst.BackgroundTransparency < 0.98 then
			setProp(inst, 'BackgroundColor3', surface(sk.Button))
			setProp(inst, 'BackgroundTransparency', math.min(inst.BackgroundTransparency, 0.16))
			ensureCorner(inst, 11)
			ensureStroke(inst, 'NeoButtonStroke', 1, 0.7)
			bindHover(inst, nil)
		end
	end

	local function styleInput(inst)
		local sk = skin()
		setProp(inst, 'BorderSizePixel', 0)
		setProp(inst, 'BackgroundColor3', surface(sk.Input))
		setProp(inst, 'BackgroundTransparency', 0.02)
		ensureCorner(inst, 12)
		ensureStroke(inst, 'NeoInputStroke', 1, 0.52)
	end

	local function styleControl(inst)
		if not inst:IsA('GuiObject') then return end
		setProp(inst, 'BorderSizePixel', 0)
		-- Paint/outline only the visible track & knob; leave image-based slider
		-- art (transparent background) alone apart from rounding.
		if inst.BackgroundTransparency < 0.98 then
			setProp(inst, 'BackgroundColor3', accentColor(0, -0.06, -0.04))
			ensureCorner(inst, 99)
			ensureStroke(inst, 'NeoControlStroke', 1, 0.6)
		end
	end

	local function stylePanel(inst)
		local sk = skin()
		setProp(inst, 'BorderSizePixel', 0)
		if inst.BackgroundTransparency < 1 then
			setProp(inst, 'BackgroundColor3', surface(sk.Card))
			setProp(inst, 'BackgroundTransparency', math.max(inst.BackgroundTransparency, 0.06))
			ensureCorner(inst, 12)
		end
	end

	local function styleScroll(inst)
		setProp(inst, 'BorderSizePixel', 0)
		if inst:IsA('ScrollingFrame') then
			setProp(inst, 'ScrollBarThickness', 3)
			setProp(inst, 'ScrollBarImageColor3', accentColor())
			setProp(inst, 'ScrollBarImageTransparency', 0.4)
		end
	end

	------------------------------------------------------------------
	-- Master styler
	------------------------------------------------------------------
	local function styleObject(inst)
		if not neo.Active or typeof(inst) ~= 'Instance' or not inst:IsA('GuiObject') or isOverhaulObject(inst) then return end
		local ok = pcall(function()
			local class = classify(inst)
			neo.Styled[inst] = class
			styleText(inst, class)

			if class == 'Window' then
				addWindowChrome(inst)
			elseif class == 'ModuleCard' then
				styleModuleCard(inst)
			elseif class == 'Button' or class == 'IconButton' then
				styleButton(inst)
			elseif class == 'Input' or class == 'Dropdown' then
				styleInput(inst)
			elseif class == 'Slider' or class == 'Toggle' then
				styleControl(inst)
			elseif class == 'Scroll' then
				styleScroll(inst)
			elseif class == 'Panel' then
				stylePanel(inst)
			end
		end)
		if not ok and shared.VapeDeveloper then
			warn('[AetherNeo] style failed on '..tostring(inst))
		end
	end

	local function styleTree(root)
		styleObject(root)
		for _, child in root:GetDescendants() do
			styleObject(child)
		end
	end

	------------------------------------------------------------------
	-- Backdrop stage
	------------------------------------------------------------------
	local function buildStage()
		if neo.Root then return end
		local sk = skin()
		neo.Root = make('Frame', {
			Name = 'NeoStage',
			BackgroundColor3 = sk.Stage[1],
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = -50,
			ClipsDescendants = true
		}, clickgui)
		ensureGradient(neo.Root, 'NeoStageGradient', 45, ColorSequence.new({
			ColorSequenceKeypoint.new(0, sk.Stage[1]),
			ColorSequenceKeypoint.new(0.5, sk.Stage[2]),
			ColorSequenceKeypoint.new(1, sk.Stage[3])
		}), NumberSequence.new(0))

		-- Parallax grid.
		local gridHolder = make('Frame', {
			Name = 'NeoGrid',
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = -49,
			ClipsDescendants = true
		}, neo.Root)
		for i = 1, 20 do
			neo.GridV[i] = make('Frame', {
				Name = 'NeoGridV'..i,
				BackgroundColor3 = sk.Grid,
				BackgroundTransparency = 0.9,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.fromScale(i / 20, 0),
				ZIndex = -49
			}, gridHolder)
		end
		for i = 1, 12 do
			neo.GridH[i] = make('Frame', {
				Name = 'NeoGridH'..i,
				BackgroundColor3 = sk.Grid,
				BackgroundTransparency = 0.92,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromScale(0, i / 12),
				ZIndex = -49
			}, gridHolder)
		end

		-- Aurora orbs.
		for i = 1, 10 do
			local orb = make('Frame', {
				Name = 'NeoAurora'..i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = accentColor(i / 30, 0.04, 0),
				BackgroundTransparency = 0.8,
				BorderSizePixel = 0,
				Position = UDim2.fromScale((i * 0.19) % 1, (i * 0.31) % 1),
				Size = UDim2.fromOffset(240 + i * 22, 240 + i * 16),
				ZIndex = -48
			}, neo.Root)
			make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(1, 0)}, orb)
			ensureGradient(orb, 'NeoAuroraGradient', i * 21, ColorSequence.new(WHITE, accentColor(i / 18)), NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.72, 0.82),
				NumberSequenceKeypoint.new(1, 1)
			}))
			neo.Orbs[i] = {Object = orb, Seed = i, Speed = 0.03 + i * 0.004}
		end

		-- Rising particles.
		for i = 1, 26 do
			local dot = make('Frame', {
				Name = 'NeoParticle'..i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = accentColor(0, 0.1, 0.1),
				BackgroundTransparency = 0.35 + (i % 5) * 0.1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale((i * 0.137) % 1, (i * 0.221) % 1),
				Size = UDim2.fromOffset(2 + (i % 3), 2 + (i % 3)),
				ZIndex = -47
			}, neo.Root)
			make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(1, 0)}, dot)
			neo.Particles[i] = {Object = dot, Seed = i * 0.61, Speed = 0.02 + (i % 6) * 0.006, Drift = (i % 2 == 0) and 1 or -1}
		end

		-- Top glow bar + vignette.
		local topGlow = make('Frame', {
			Name = 'NeoTopGlow',
			BackgroundColor3 = accentColor(),
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 160),
			ZIndex = -47
		}, neo.Root)
		ensureGradient(topGlow, 'NeoTopGlowGradient', 90, ColorSequence.new(accentColor(), sk.Stage[2]), NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1)
		}))
		neo.TopGlow = topGlow

		local vignette = make('Frame', {
			Name = 'NeoVignette',
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 220),
			ZIndex = -47
		}, neo.Root)
		ensureGradient(vignette, 'NeoVignetteGradient', 90, ColorSequence.new(BLACK, BLACK), NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.4)
		}))
	end

	------------------------------------------------------------------
	-- Command dock
	------------------------------------------------------------------
	local function makeChip(parent, key, label, order)
		local chip = make('Frame', {
			Name = 'NeoChip'..key,
			BackgroundColor3 = shade(skin().Dock, 0.05),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(96, 34),
			LayoutOrder = order,
			ZIndex = 82
		}, parent)
		make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(0, 10)}, chip)
		ensureStroke(chip, 'NeoChipStroke', 1, 0.7)
		make('TextLabel', {
			Name = 'Key',
			BackgroundTransparency = 1,
			FontFace = uipallet.Font,
			Text = label,
			TextColor3 = skin().Muted,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 12),
			ZIndex = 83
		}, chip)
		local value = make('TextLabel', {
			Name = 'Value',
			BackgroundTransparency = 1,
			FontFace = uipallet.FontSemiBold,
			Text = '--',
			TextColor3 = skin().Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 15),
			Size = UDim2.new(1, -20, 0, 16),
			ZIndex = 83
		}, chip)
		neo.Chips[key] = value
		return chip
	end

	local function buildDock()
		if neo.Dock then return end
		local sk = skin()
		neo.Dock = make('Frame', {
			Name = 'NeoDock',
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = surface(sk.Dock),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.fromOffset(640, 58),
			ZIndex = 80
		}, clickgui)
		make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(0, 18)}, neo.Dock)
		ensureStroke(neo.Dock, 'NeoDockStroke', 1.3, 0.35)
		ensureGradient(neo.Dock, 'NeoDockGradient', 90, ColorSequence.new(shade(sk.Dock, 0.06), sk.Dock), NumberSequence.new(0.05))
		ensureGlow(neo.Dock, 'NeoDockGlow', accentColor(), 0.72, 24, -1)

		-- Brand mark.
		local badge = make('Frame', {
			Name = 'NeoBadge',
			BackgroundColor3 = accentColor(),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.fromOffset(30, 30),
			ZIndex = 82
		}, neo.Dock)
		make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(0, 9)}, badge)
		ensureGradient(badge, 'NeoBadgeGradient', 45, ColorSequence.new(accentColor(-0.06, 0.05, 0.05), accentColor(0.08, 0, -0.05)), NumberSequence.new(0))
		make('TextLabel', {
			Name = 'Mark',
			BackgroundTransparency = 1,
			FontFace = uipallet.FontSemiBold,
			Text = 'A',
			TextColor3 = mainapi:TextColor(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value),
			TextSize = 18,
			ZIndex = 83,
			Size = UDim2.fromScale(1, 1)
		}, badge)
		neo.Badge = badge

		make('TextLabel', {
			Name = 'NeoBrand',
			BackgroundTransparency = 1,
			FontFace = uipallet.FontSemiBold,
			Text = 'AETHER NEO',
			TextColor3 = sk.Text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(52, 11),
			Size = UDim2.fromOffset(150, 16),
			ZIndex = 82
		}, neo.Dock)
		neo.DockSkin = make('TextLabel', {
			Name = 'NeoBrandSub',
			BackgroundTransparency = 1,
			FontFace = uipallet.Font,
			Text = sk.Title..' skin',
			TextColor3 = sk.Muted,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(52, 30),
			Size = UDim2.fromOffset(150, 14),
			ZIndex = 82
		}, neo.Dock)

		-- Stat chips.
		local chipHolder = make('Frame', {
			Name = 'NeoChips',
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -58, 0.5, 0),
			Size = UDim2.fromOffset(408, 34),
			ZIndex = 82
		}, neo.Dock)
		make('UIListLayout', {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder
		}, chipHolder)
		makeChip(chipHolder, 'Fps', 'FPS', 1)
		makeChip(chipHolder, 'Ping', 'PING', 2)
		makeChip(chipHolder, 'Modules', 'ACTIVE', 3)
		makeChip(chipHolder, 'Time', 'TIME', 4)

		-- Skin switcher button.
		local switch = make('TextButton', {
			Name = 'NeoSkinSwitch',
			BackgroundColor3 = shade(sk.Dock, 0.08),
			BackgroundTransparency = 0.15,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = '',
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			ZIndex = 82
		}, neo.Dock)
		make('UICorner', {Name = 'NeoCorner', CornerRadius = UDim.new(0, 10)}, switch)
		ensureStroke(switch, 'NeoButtonStroke', 1, 0.55)
		make('TextLabel', {
			Name = 'Glyph',
			BackgroundTransparency = 1,
			FontFace = uipallet.FontSemiBold,
			Text = '❖',
			TextColor3 = accentColor(),
			TextSize = 16,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 83
		}, switch)
		table.insert(neo.Connections, switch.MouseButton1Click:Connect(function()
			overhaul.CycleSkin()
		end))
		bindHover(switch, nil)
	end

	------------------------------------------------------------------
	-- Global surfaces (corner radius + glass live values)
	------------------------------------------------------------------
	local function applyGlobalSurfaces()
		neo.CornerRadius = cornerRadius
		neo.Glass = uipallet.Glass
		cornerRadius = 16
		for corner in cornerRegistry do
			if corner.Parent then
				corner.CornerRadius = UDim.new(0, cornerRadius)
			end
		end
		uipallet.Glass = 0.05
		for panel in glassPanels do
			if panel.Parent then
				panel.BackgroundTransparency = uipallet.Glass
			end
		end
	end

	local function restoreGlobalSurfaces()
		if neo.CornerRadius then
			cornerRadius = neo.CornerRadius
			for corner in cornerRegistry do
				if corner.Parent then
					corner.CornerRadius = UDim.new(0, cornerRadius)
				end
			end
		end
		if neo.Glass then
			uipallet.Glass = neo.Glass
			for panel in glassPanels do
				if panel.Parent then
					panel.BackgroundTransparency = uipallet.Glass
				end
			end
		end
		neo.CornerRadius = nil
		neo.Glass = nil
	end

	-- Recolour the whole stage/dock/styled tree to the current skin without a
	-- full teardown (used by the skin switcher).
	local function applySkinColors()
		local sk = skin()
		if neo.Root then
			neo.Root.BackgroundColor3 = sk.Stage[1]
			local grad = neo.Root:FindFirstChild('NeoStageGradient')
			if grad then
				grad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, sk.Stage[1]),
					ColorSequenceKeypoint.new(0.5, sk.Stage[2]),
					ColorSequenceKeypoint.new(1, sk.Stage[3])
				})
			end
		end
		for _, ln in neo.GridV do if ln.Parent then ln.BackgroundColor3 = sk.Grid end end
		for _, ln in neo.GridH do if ln.Parent then ln.BackgroundColor3 = sk.Grid end end
		if neo.Dock then
			neo.Dock.BackgroundColor3 = surface(sk.Dock)
			local brand = neo.Dock:FindFirstChild('NeoBrand')
			if brand then brand.TextColor3 = sk.Text end
			if neo.DockSkin then neo.DockSkin.Text = sk.Title..' skin' end
		end
		-- Window bodies are chromed once (guarded by neo.Windows), so recolour
		-- their surfaces here directly rather than through addWindowChrome.
		for w in neo.Windows do
			if w.Parent then
				w.BackgroundColor3 = surface(sk.Window)
				local surf = w:FindFirstChild('NeoWindowSurface')
				if surf then
					surf.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, surface(sk.WindowTop)),
						ColorSequenceKeypoint.new(0.5, surface(sk.Window)),
						ColorSequenceKeypoint.new(1, surface(sk.WindowBottom))
					})
				end
			end
		end
		styleTree(clickgui)
	end

	------------------------------------------------------------------
	-- Animation loop
	------------------------------------------------------------------
	local function step(dt)
		if not neo.Active then return end
		local now = os.clock()
		local accent = accentColor()

		-- Window chrome pulse.
		for inst in neo.Windows do
			if inst.Parent then
				local header = inst:FindFirstChild('NeoHeader')
				if header then header.BackgroundColor3 = accent end
				local stroke = inst:FindFirstChild('NeoWindowStroke')
				if stroke then
					stroke.Color = accent
					stroke.Transparency = 0.3 + 0.14 * (0.5 + 0.5 * math.sin(now * 1.7))
				end
				local glow = inst:FindFirstChild('NeoWindowGlow')
				if glow then glow.ImageColor3 = accent end
				local rail = inst:FindFirstChild('NeoRail')
				if rail then rail.BackgroundColor3 = accent end
			end
		end

		-- Styled control strokes + pills.
		for inst in neo.Styled do
			if inst.Parent then
				local stroke = inst:FindFirstChild('NeoControlStroke')
				if stroke then stroke.Color = accent end
				local pill = inst:FindFirstChild('NeoPill')
				if pill then pill.BackgroundColor3 = accent end
			end
		end

		-- Aurora orbs.
		for _, item in neo.Orbs do
			local orb = item.Object
			if orb and orb.Parent then
				orb.BackgroundColor3 = accentColor(item.Seed / 27, 0.04, 0)
				orb.Position = UDim2.fromScale(
					(0.5 + 0.38 * math.sin(now * item.Speed + item.Seed)) % 1,
					(0.5 + 0.32 * math.cos(now * item.Speed * 0.9 + item.Seed)) % 1
				)
			end
		end

		-- Rising particles.
		for _, item in neo.Particles do
			local dot = item.Object
			if dot and dot.Parent then
				local y = (item.Seed + now * item.Speed) % 1
				local x = (item.Seed * 0.7 + 0.03 * math.sin(now * 0.5 + item.Seed) * item.Drift) % 1
				dot.Position = UDim2.fromScale(x, 1 - y)
			end
		end

		-- Parallax grid drift.
		local vDrift = (now * 0.01) % 0.05
		for i, ln in neo.GridV do
			if ln.Parent then
				ln.Position = UDim2.fromScale(((i / 20) + vDrift) % 1, 0)
			end
		end
		local hDrift = (now * 0.008) % 0.083
		for i, ln in neo.GridH do
			if ln.Parent then
				ln.Position = UDim2.fromScale(0, ((i / 12) + hDrift) % 1)
			end
		end

		if neo.TopGlow then
			neo.TopGlow.BackgroundColor3 = accent
		end
		if neo.Badge then
			neo.Badge.BackgroundColor3 = accent
		end

		-- Dock stats (throttled).
		neo.Fps = neo.Fps * 0.9 + (1 / math.max(dt, 1 / 240)) * 0.1
		neo.StatClock = neo.StatClock + dt
		if neo.Dock then
			local dockStroke = neo.Dock:FindFirstChild('NeoDockStroke')
			if dockStroke then dockStroke.Color = accent end
			local dockGlow = neo.Dock:FindFirstChild('NeoDockGlow')
			if dockGlow then dockGlow.ImageColor3 = accent end
		end
		if neo.StatClock >= 0.25 then
			neo.StatClock = 0
			if neo.Chips.Fps then neo.Chips.Fps.Text = tostring(math.floor(neo.Fps + 0.5)) end
			if neo.Chips.Ping then
				local ping = 0
				pcall(function() ping = math.floor(localPlayer:GetNetworkPing() * 1000) end)
				neo.Chips.Ping.Text = ping..' ms'
			end
			if neo.Chips.Modules then
				local count = 0
				for _, m in mainapi.Modules do
					if m.Enabled then count += 1 end
				end
				neo.Chips.Modules.Text = tostring(count)
			end
			if neo.Chips.Time then
				neo.Chips.Time.Text = os.date('%H:%M:%S')
			end
		end
	end

	local function disconnectAll()
		for _, conn in neo.Connections do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(neo.Connections)
	end

	------------------------------------------------------------------
	-- Public API
	------------------------------------------------------------------
	function overhaul.Apply()
		if neo.Active then return end
		neo.Active = true
		applyGlobalSurfaces()
		buildStage()
		buildDock()
		styleTree(clickgui)
		table.insert(neo.Connections, clickgui.ChildAdded:Connect(function(child)
			task.defer(function()
				if neo.Active then styleTree(child) end
			end)
		end))
		table.insert(neo.Connections, clickgui.DescendantAdded:Connect(function(child)
			task.defer(function()
				if neo.Active then styleObject(child) end
			end)
		end))
		table.insert(neo.Connections, runService.RenderStepped:Connect(function(dt)
			local ok, err = pcall(step, dt)
			if not ok and shared.VapeDeveloper then
				warn('[AetherNeo] '..tostring(err))
			end
		end))
		pcall(function()
			mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value, true)
		end)
	end

	function overhaul.Revert()
		if not neo.Active then return end
		neo.Active = false
		disconnectAll()
		for inst in neo.Generated do
			if inst.Parent then
				pcall(function() inst:Destroy() end)
			end
			neo.Generated[inst] = nil
		end
		for inst, props in neo.Original do
			if inst.Parent then
				for prop, value in props do
					pcall(function()
						inst[prop] = value
					end)
				end
			end
			neo.Original[inst] = nil
		end
		for inst in neo.Styled do neo.Styled[inst] = nil end
		for inst in neo.Windows do neo.Windows[inst] = nil end
		for inst in neo.Hovered do neo.Hovered[inst] = nil end
		table.clear(neo.Orbs)
		table.clear(neo.Particles)
		table.clear(neo.GridV)
		table.clear(neo.GridH)
		table.clear(neo.Chips)
		table.clear(neo.Motion)
		neo.Root = nil
		neo.Dock = nil
		neo.TopGlow = nil
		neo.Badge = nil
		neo.DockSkin = nil
		restoreGlobalSurfaces()
	end

	function overhaul.IsActive()
		return neo.Active
	end

	function overhaul.SetSkin(name)
		if not skins[name] then return end
		neo.SkinName = name
		if neo.Active then
			pcall(applySkinColors)
		end
	end

	function overhaul.CycleSkin()
		local idx = table.find(skinOrder, neo.SkinName) or 1
		overhaul.SetSkin(skinOrder[(idx % #skinOrder) + 1])
	end

	mainapi:Clean(function()
		if neo.Active then
			overhaul.Revert()
		else
			disconnectAll()
		end
	end)
end
mainapi.Overhaul = overhaul

--[[
	General Settings
]]

local general = mainapi.Categories.Main:CreateSettingsPane({Name = 'General'})
mainapi.MultiKeybind = general:CreateToggle({
	Name = 'Enable Multi-Keybinding',
	Tooltip = 'Allows multiple keys to be bound to a module (eg. G + H)'
})
general:CreateToggle({
  Name = 'GUI Overhaul',
  Tooltip = 'Aether Neo: a complete new-theme redesign of the whole GUI - animated multi-layer stage backdrop, re-chromed windows, module cards, redesigned controls, overlays, glass and typography, a live command dock (FPS / ping / active-module count / clock) and switchable skins. Toggle off to restore Nexus.',
  Function = function(callback)
    if callback then
      overhaul.Apply()
      pcall(function()
        mainapi:CreateNotification('GUI Overhaul', 'Aether Neo is active: full GUI redesign with animated backdrop, re-chromed windows, cards, controls and a command dock. Click the ❖ on the dock to switch skins; toggle off in Settings > General to restore Nexus.', 6, 'info')
      end)
    else
      overhaul.Revert()
    end
  end
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
	Tooltip = 'Prevents AetherV2 from showing its startup loading screen.'
})
general:CreateButton({
	Name = 'Reset current profile',
	Function = function()
	mainapi.Save = function() end
		if isfile(getConfigPath(mainapi.Profile)) and delfile then
			delfile(getConfigPath(mainapi.Profile))
		end
		shared.vapereload = true
		if shared.VapeDeveloper then
			loadstring(readfile('aetherv2/main.lua'), 'main')(license)
		else
			loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/main.lua', true), 'main')(license)
		end
	end,
	Tooltip = 'This will set your profile to the default settings of Vape'
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
	Tooltip = 'Who made this config. Added to the JSON export as "credits".'
})
local exportTags = general:CreateTextBox({
	Name = 'Export Tags',
	Placeholder = 'pvp, rage, legit',
	Tooltip = 'Comma-separated tags for the export. At least one is required.'
})
local exportDescription = general:CreateTextBox({
	Name = 'Export Description',
	Placeholder = 'Short description',
	Tooltip = 'A short description added to the JSON export as "description".'
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
	Tooltip = 'Copies your config to the clipboard as JSON, including credits, tags and a description.'
})
general:CreateButton({
	Name = 'Self destruct',
	Function = function()
		mainapi:Uninject()
	end,
	Tooltip = 'Removes vape from the current game'
})
general:CreateButton({
	Name = 'Reinject',
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
	Tooltip = "Displays a message indicating your GUI upon injecting.\nI.E. 'Press RSHIFT to open GUI'"
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
			-- Flush the current profile (accent colour, module states, window
			-- positions, ...) to disk before we tear this GUI down and reload,
			-- so nothing changed since the last save is lost across the switch.
			pcall(function()
				mainapi:Save(mainapi.Profile)
			end)
			writefile('aetherv2/profiles/gui.txt', val)
			shared.vapereload = true
			if shared.VapeDeveloper then
				loadstring(readfile('aetherv2/main.lua'), 'main')(license)
			else
				loadstring(game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..readfile('aetherv2/profiles/commit.txt')..'/main.lua', true), 'main')(license)
			end
		end
	end,
	Tooltip = 'newer - AetherV2 Nexus (glass-morphism)\nnew - The newest vape theme since v4.05\nold - The vape theme pre v4.05\nrise - Rise 6.0'
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
			RenderCategory = 4,
			VisualsCategory = 5,
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
	Tooltip = 'Notifies you if a module is enabled/disabled.',
	Default = true,
	Darker = true
})

mainapi.GUIColor = mainapi.Categories.Main:CreateGUISlider({
	Name = 'GUI Theme',
	Function = function(h, s, v)
		mainapi:UpdateGUI(h, s, v, true)
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
	Tooltip = 'Renders shadowed text.',
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
	Tooltip = 'Allows you to blacklist certain modules from being shown.',
	Function = function(enabled)
		textguimoduleslist.Object.Visible = enabled
		mainapi:UpdateTextGUI()
	end
})
textguimoduleslist = textgui:CreateTextList({
	Name = 'Blacklist',
	Tooltip = 'Name of module to hide.',
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
			v.Object.VapeLogo.V4Logo.ImageColor3 = Color3.fromHSV(hue, sat, val)
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
	 Everything below this line is new in the Nexus (v5.0) redesign:
	  1. Theme Editor       (Settings -> Theme)
	  2. Stats Dashboard    (Overlays -> Stats Dashboard, mainapi.Stats)
	  3. Plugin system      (mainapi:RegisterPlugin + aetherv2/plugins/)
	 All features reuse the existing component/overlay/save systems, so they
	 persist through the same profile files as every other option.
	=========================================================================
]]

--[[
	Theme Editor
	Live adjustment of the glass intensity and font face, plus base-theme
	presets stored in aetherv2/profiles/color.txt (the same override file the
	GUI has always read its palette from, so presets survive updates).
]]
do
	local function readThemeOverrides()
		return (isfile('aetherv2/profiles/color.txt') and loadJson('aetherv2/profiles/color.txt')) or {}
	end

	local function writeThemeOverrides(overrides)
		pcall(writefile, 'aetherv2/profiles/color.txt', httpService:JSONEncode(overrides))
	end

	local themepane = mainapi.Categories.Main:CreateSettingsPane({Name = 'Theme'})

	themepane:CreateSlider({
		Name = 'Glass intensity',
		Min = 0,
		Max = 60,
		Default = math.floor(uipallet.Glass * 100 + 0.5),
		Suffix = '%',
		Tooltip = 'How translucent the frosted panels are.\nApplies instantly to every glass surface, and is saved to your theme file so it persists.',
		Function = function(val, mouse)
			uipallet.Glass = val / 100
			for panel in glassPanels do
				if panel.Parent then
					panel.BackgroundTransparency = uipallet.Glass
				end
			end
			if mouse then
				local overrides = readThemeOverrides()
				overrides.Glass = uipallet.Glass
				writeThemeOverrides(overrides)
			end
		end
	})

	local themeFonts = {
		['Gotham'] = 'GothamSSm',
		['Builder Sans'] = 'BuilderSans',
		['Arial'] = 'Arial',
		['Roboto'] = 'Roboto',
		['Ubuntu'] = 'Ubuntu',
		['Montserrat'] = 'Montserrat',
		['Source Sans'] = 'SourceSansPro'
	}
	themepane:CreateDropdown({
		Name = 'Font face',
		List = {'Gotham', 'Builder Sans', 'Arial', 'Roboto', 'Ubuntu', 'Montserrat', 'Source Sans'},
		Tooltip = 'Changes the interface font in real time.\nSaved to your theme file so it persists.',
		Function = function(val, mouse)
			local family = themeFonts[val]
			if not family then return end
			local suc = pcall(function()
				local newfont = Font.new(string.format('rbxasset://fonts/families/%s.json', family))
				uipallet.Font = newfont
				uipallet.FontSemiBold = Font.new(newfont.Family, Enum.FontWeight.SemiBold)
				fontsize.Font = newfont
				for _, obj in gui:GetDescendants() do
					if obj:IsA('TextLabel') or obj:IsA('TextButton') or obj:IsA('TextBox') then
						obj.FontFace = Font.new(newfont.Family, obj.FontFace.Weight, obj.FontFace.Style)
					end
				end
			end)
			if suc and mouse then
				local overrides = readThemeOverrides()
				overrides.Font = family
				writeThemeOverrides(overrides)
			end
		end
	})

	-- Base surface presets. Applying the base colour everywhere at runtime would
	-- require rebuilding every derived colour, so presets are written to the
	-- palette override file and picked up on the next inject.
	local baseThemes = {
		['Nexus Navy'] = {Main = {14, 17, 23}, Text = {214, 220, 232}},
		['Charcoal'] = {Main = {26, 31, 42}, Text = {220, 224, 232}},
		['Abyss'] = {Main = {9, 11, 16}, Text = {205, 212, 226}},
		['Classic Dark'] = {Main = {26, 25, 26}, Text = {200, 200, 200}}
	}
	themepane:CreateDropdown({
		Name = 'Base theme',
		List = {'Nexus Navy', 'Charcoal', 'Abyss', 'Classic Dark'},
		Tooltip = 'Base surface colours.\nSaved to your theme file - reinject to apply everywhere.',
		Function = function(val, mouse)
			if not mouse then return end
			local preset = baseThemes[val]
			if not preset then return end
			local overrides = readThemeOverrides()
			overrides.Main = preset.Main
			overrides.Text = preset.Text
			writeThemeOverrides(overrides)
			mainapi:CreateNotification('Theme', 'Base theme "'..val..'" saved. Reinject to apply it everywhere.', 6, 'info')
		end
	})

	themepane:CreateButton({
		Name = 'Reset theme overrides',
		Tooltip = 'Deletes aetherv2/profiles/color.txt so the default Nexus palette is used on the next inject.',
		Function = function()
			if isfile('aetherv2/profiles/color.txt') and delfile then
				pcall(delfile, 'aetherv2/profiles/color.txt')
			else
				writeThemeOverrides({})
			end
			mainapi:CreateNotification('Theme', 'Theme overrides cleared. Reinject to restore the default palette.', 6, 'info')
		end
	})
end

--[[
	Stats Dashboard
	mainapi.Stats tracks lifetime counters (persisted to
	aetherv2/profiles/stats.json) plus a history of the last 10 games. Deaths
	are tracked automatically; game modules and plugins feed the rest:
	  vape.Stats:Increment('Kills')          -- also 'Beds', 'Final Kills', ...
	  vape.Stats:RecordGame({Kills = 7, Won = true})
	  vape.Stats:RegisterStat('Arrows')      -- plugins can add new stat types
	The dashboard overlay renders everything live, including a mini bar graph
	of kills across the last 10 recorded games.
]]
do
	local statsPath = 'aetherv2/profiles/stats.json'
	local stats = {
		Data = {},
		Session = {},
		History = {},
		Order = {'Kills', 'Deaths', 'Final Kills', 'Beds', 'Wins', 'Games'}
	}
	mainapi.Stats = stats

	do
		local saved = isfile(statsPath) and loadJson(statsPath) or nil
		if type(saved) == 'table' then
			stats.Data = type(saved.Data) == 'table' and saved.Data or {}
			stats.History = type(saved.History) == 'table' and saved.History or {}
		end
	end
	for _, name in stats.Order do
		stats.Data[name] = tonumber(stats.Data[name]) or 0
		stats.Session[name] = 0
	end

	local refreshUI = function() end
	local saveQueued = false

	function stats:SaveNow()
		pcall(writefile, statsPath, httpService:JSONEncode({Data = self.Data, History = self.History}))
	end

	-- Debounced persistence so rapid increments (e.g. kill streaks) do not
	-- hammer the disk; the dashboard itself still updates instantly.
	function stats:Queue()
		if saveQueued then return end
		saveQueued = true
		task.delay(2, function()
			saveQueued = false
			stats:SaveNow()
		end)
	end

	function stats:Get(name)
		return self.Data[name] or 0
	end

	function stats:Set(name, value)
		self.Data[name] = tonumber(value) or 0
		self:Queue()
		refreshUI()
	end

	function stats:Increment(name, amount)
		amount = tonumber(amount) or 1
		self.Data[name] = (self.Data[name] or 0) + amount
		self.Session[name] = (self.Session[name] or 0) + amount
		self:Queue()
		refreshUI()
	end

	function stats:GetFKDR()
		return (self.Data['Final Kills'] or 0) / math.max(self.Data.Deaths or 0, 1)
	end

	-- Records a finished game into the history graph. Owns the Games/Wins
	-- counters so callers only describe what happened.
	function stats:RecordGame(entry)
		entry = type(entry) == 'table' and entry or {}
		table.insert(self.History, {
			Kills = tonumber(entry.Kills) or self.Session.Kills or 0,
			Won = entry.Won and true or false,
			Time = os.time()
		})
		while #self.History > 10 do
			table.remove(self.History, 1)
		end
		self.Data.Games = (self.Data.Games or 0) + 1
		if entry.Won then
			self.Data.Wins = (self.Data.Wins or 0) + 1
		end
		self.Session.Kills = 0
		self:Queue()
		refreshUI()
	end

	-- Automatic death tracking.
	do
		local lplr = cloneref(game:GetService('Players')).LocalPlayer
		local function hookCharacter(char)
			local hum = char:FindFirstChildOfClass('Humanoid') or char:WaitForChild('Humanoid', 10)
			if hum then
				hum.Died:Once(function()
					stats:Increment('Deaths')
				end)
			end
		end
		mainapi:Clean(lplr.CharacterAdded:Connect(function(char)
			task.spawn(hookCharacter, char)
		end))
		if lplr.Character then
			task.spawn(hookCharacter, lplr.Character)
		end
	end

	-- Dashboard overlay -----------------------------------------------------
	local overlay = mainapi:CreateOverlay({
		Name = 'Stats Dashboard',
		Icon = getcustomasset('aetherv2/assets/new/radaricon.png'),
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(12, 13),
		CategorySize = 220,
		Color = true,
		Function = function(callback)
			if callback then
				refreshUI()
			end
		end
	})
	local holder = overlay.Object.CustomChildren

	local bg = Instance.new('Frame')
	bg.Name = 'DashboardBkg'
	bg.Size = UDim2.new(1, 0, 0, 100)
	bg.BackgroundColor3 = uipallet.Main
	bg.BorderSizePixel = 0
	bg.Parent = holder
	addBlur(bg)
	addCorner(bg)

	local tiles = {}
	local graphTitle, graphFrame
	local bars = {}

	local function makeTile(name)
		local tile = Instance.new('Frame')
		tile.Name = name
		tile.Size = UDim2.fromOffset(96, 44)
		tile.BackgroundColor3 = color.Light(uipallet.Main, 0.03)
		tile.BorderSizePixel = 0
		tile.Parent = bg
		addGlass(tile)
		addCorner(tile)
		local label = Instance.new('TextLabel')
		label.Name = 'Label'
		label.Size = UDim2.new(1, -12, 0, 14)
		label.Position = UDim2.fromOffset(8, 5)
		label.BackgroundTransparency = 1
		label.Text = name:upper()
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextColor3 = color.Dark(uipallet.Text, 0.25)
		label.TextSize = 10
		label.FontFace = uipallet.Font
		label.Parent = tile
		local value = Instance.new('TextLabel')
		value.Name = 'Value'
		value.Size = UDim2.new(1, -12, 0, 18)
		value.Position = UDim2.fromOffset(8, 20)
		value.BackgroundTransparency = 1
		value.Text = '0'
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.TextColor3 = uipallet.Text
		value.TextSize = 16
		value.FontFace = uipallet.FontSemiBold
		value.Parent = tile
		return {Object = tile, Value = value}
	end

	-- Lays the tile grid (2 columns) and graph out again; called whenever a
	-- plugin registers a new stat type.
	local function relayout()
		local names = table.clone(stats.Order)
		table.insert(names, 'FKDR')
		table.insert(names, 'Win %')
		for i, name in names do
			local tile = tiles[name]
			if not tile then
				tile = makeTile(name)
				tiles[name] = tile
			end
			local col = (i - 1) % 2
			local row = math.floor((i - 1) / 2)
			tile.Object.Position = UDim2.fromOffset(10 + col * 100, 8 + row * 48)
		end
		local rows = math.ceil(#names / 2)
		local graphY = 8 + rows * 48 + 4
		graphTitle.Position = UDim2.fromOffset(10, graphY)
		graphFrame.Position = UDim2.fromOffset(10, graphY + 18)
		bg.Size = UDim2.new(1, 0, 0, graphY + 18 + 54 + 10)
	end

	graphTitle = Instance.new('TextLabel')
	graphTitle.Name = 'GraphTitle'
	graphTitle.Size = UDim2.new(1, -20, 0, 14)
	graphTitle.BackgroundTransparency = 1
	graphTitle.Text = 'LAST 10 GAMES - KILLS'
	graphTitle.TextXAlignment = Enum.TextXAlignment.Left
	graphTitle.TextColor3 = color.Dark(uipallet.Text, 0.25)
	graphTitle.TextSize = 10
	graphTitle.FontFace = uipallet.Font
	graphTitle.Parent = bg

	graphFrame = Instance.new('Frame')
	graphFrame.Name = 'Graph'
	graphFrame.Size = UDim2.fromOffset(200, 54)
	graphFrame.BackgroundColor3 = color.Light(uipallet.Main, 0.03)
	graphFrame.BorderSizePixel = 0
	graphFrame.Parent = bg
	addGlass(graphFrame)
	addCorner(graphFrame)

	for i = 1, 10 do
		local bar = Instance.new('Frame')
		bar.Name = 'Bar'..i
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 4 + (i - 1) * 20, 1, -4)
		bar.Size = UDim2.fromOffset(14, 2)
		bar.BackgroundColor3 = color.Light(uipallet.Main, 0.12)
		bar.BorderSizePixel = 0
		bar.Parent = graphFrame
		addCorner(bar, UDim.new(0, 3))
		bars[i] = bar
	end

	refreshUI = function()
		if mainapi.Loaded == nil then return end
		for name, tile in tiles do
			if name == 'FKDR' then
				tile.Value.Text = string.format('%.2f', stats:GetFKDR())
			elseif name == 'Win %' then
				local games = stats.Data.Games or 0
				tile.Value.Text = games > 0 and string.format('%d%%', math.floor((stats.Data.Wins or 0) / games * 100 + 0.5)) or '-'
			else
				tile.Value.Text = tostring(stats.Data[name] or 0)
			end
		end
		local accent = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		local maxKills = 1
		for _, entry in stats.History do
			maxKills = math.max(maxKills, entry.Kills or 0)
		end
		for i = 1, 10 do
			local entry = stats.History[#stats.History - 10 + i]
			local bar = bars[i]
			if entry then
				local height = math.max(math.floor((entry.Kills or 0) / maxKills * 42), 2)
				tween:Tween(bar, uipallet.Tween, {Size = UDim2.fromOffset(14, height)})
				bar.BackgroundColor3 = entry.Won and accent or color.Light(uipallet.Main, 0.12)
			else
				bar.Size = UDim2.fromOffset(14, 2)
				bar.BackgroundColor3 = color.Light(uipallet.Main, 0.08)
			end
		end
	end
	stats.Refresh = function()
		refreshUI()
	end

	-- Plugin API: adds a brand-new counter tile to the dashboard.
	function stats:RegisterStat(name)
		if type(name) ~= 'string' or name == '' or table.find(self.Order, name) then return end
		table.insert(self.Order, name)
		self.Data[name] = tonumber(self.Data[name]) or 0
		self.Session[name] = 0
		relayout()
		self:Queue()
		refreshUI()
	end

	--[[
		Session Info -> Stats Dashboard bridge (merge).
		Game modules feed the classic "session info" panel through
		vape.Libraries.sessioninfo:AddItem(name):Increment(). Rather than keep a
		second, separate panel, that API is merged into the Stats Dashboard here:
		every numeric session item becomes a dashboard stat, so the counters game
		modules report (Kills, Beds, Wins, Games, Arrests, ...) surface on the one
		unified dashboard. Computed/text items (a map name, a cheater list) don't
		fit the numeric tile grid, so they are accepted but simply not shown - the
		call never errors either way.
	]]
	do
		local sessioninfo = {Items = {}}

		function sessioninfo:AddItem(name, default, updateFunc, _show)
			if type(name) ~= 'string' or name == '' then
				-- Harmless stub so a malformed call can never break a module.
				return {
					Increment = function() end,
					Set = function() end,
					Get = function() return 0 end
				}
			end
			if self.Items[name] then
				return self.Items[name]
			end

			-- Plain counters (no provider function) become live dashboard tiles.
			local numeric = updateFunc == nil and (type(default) == 'number' or default == nil)
			if numeric then
				stats:RegisterStat(name)
			end

			local item = {Name = name, Numeric = numeric}
			function item:Increment(amount)
				if numeric then
					stats:Increment(name, tonumber(amount) or 1)
				end
			end
			function item:Set(value)
				if numeric then
					stats:Set(name, value)
				end
			end
			function item:Get()
				return stats:Get(name)
			end

			-- A computed item polls its provider; only numeric results can feed a
			-- tile, so text providers are polled harmlessly and ignored.
			if type(updateFunc) == 'function' then
				mainapi:Clean(task.spawn(function()
					while mainapi.Loaded ~= nil do
						local ok, value = pcall(updateFunc)
						if ok and type(value) == 'number' then
							stats:RegisterStat(name)
							stats:Set(name, value)
						end
						task.wait(1)
					end
				end))
			end

			self.Items[name] = item
			return item
		end

		-- Kept for API parity with the old session panel.
		function sessioninfo:Remove() end
		function sessioninfo:Clear() end

		mainapi.Libraries.sessioninfo = sessioninfo
	end

	relayout()
	refreshUI()
end

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
	UI sound engine, click pulses and snap alignment guides.
	Fills in the function slots stubbed on the nexus table now that the
	ScreenGui exists. All of it is opt-in from Settings -> Interface.
]]
do
	-- name -> {asset, playback speed, base volume}. Built-in rbxassets so no
	-- downloads are needed; a missing asset just plays silence.
	local soundDefs = {
		click = {'rbxasset://sounds/clickfast.wav', 1, 0.4},
		hover = {'rbxasset://sounds/clickfast.wav', 1.7, 0.1},
		notify = {'rbxasset://sounds/electronicpingshort.wav', 1, 0.35},
		snap = {'rbxasset://sounds/snap.mp3', 1.4, 0.2},
		open = {'rbxasset://sounds/swoosh.wav', 1.2, 0.25}
	}
	local sounds = {}
	local lastHover = 0

	-- Build every Sound up front and preload the assets. Doing this lazily on the
	-- first play was what made the first tick of each effect lag (the engine had
	-- to fetch the asset mid-play); pre-created + preloaded instances fire
	-- instantly and reliably from then on.
	for name, def in soundDefs do
		local sound = Instance.new('Sound')
		sound.Name = 'Nexus'..name
		sound.SoundId = def[1]
		sound.PlaybackSpeed = def[2]
		sound.Parent = gui
		sounds[name] = sound
	end
	pcall(function()
		local list = {}
		for _, sound in sounds do
			table.insert(list, sound)
		end
		cloneref(game:GetService('ContentProvider')):PreloadAsync(list)
	end)

	function nexus.PlaySound(name)
		if not nexus.SoundsEnabled or nexus.SoundVolume <= 0 then return end
		local def = soundDefs[name]
		local sound = sounds[name]
		if not def or not sound then return end
		-- Hover ticks can fire many times a second while the cursor skims a list;
		-- a short debounce stops them stacking into a buzzing, unreliable mush.
		if name == 'hover' then
			local now = os.clock()
			if now - lastHover < 0.045 then return end
			lastHover = now
		end
		sound.Volume = def[3] * nexus.SoundVolume * 2
		-- Rewind before replaying so a still-playing instance restarts cleanly
		-- instead of being ignored - the source of the "unreliable" drops.
		sound.TimePosition = 0
		pcall(sound.Play, sound)
	end

	local rippleLayer = Instance.new('Frame')
	rippleLayer.Name = 'RippleLayer'
	rippleLayer.Size = UDim2.fromScale(1, 1)
	rippleLayer.BackgroundTransparency = 1
	rippleLayer.ZIndex = 10
	rippleLayer.Parent = scaledgui

	-- Expanding accent circle at the cursor. Parented to a top-level layer so
	-- no control needs ClipsDescendants flipped on.
	function nexus.SpawnRipple()
		local mouse = inputService:GetMouseLocation() / scale.Scale
		local ripple = Instance.new('Frame')
		ripple.Name = 'Ripple'
		ripple.AnchorPoint = Vector2.new(0.5, 0.5)
		ripple.Position = UDim2.fromOffset(mouse.X, mouse.Y)
		ripple.Size = UDim2.fromOffset(6, 6)
		ripple.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		ripple.BackgroundTransparency = 0.4
		ripple.BorderSizePixel = 0
		ripple.ZIndex = 10
		ripple.Parent = rippleLayer
		addCorner(ripple, UDim.new(1, 0))
		tweenService:Create(ripple, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(56, 56),
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.4, function()
			ripple:Destroy()
		end)
	end

	local guideV = Instance.new('Frame')
	guideV.Name = 'SnapGuideV'
	guideV.Size = UDim2.new(0, 1, 1, 0)
	guideV.BackgroundTransparency = 0.25
	guideV.BorderSizePixel = 0
	guideV.ZIndex = 9
	guideV.Visible = false
	guideV.Parent = scaledgui
	local guideH = guideV:Clone()
	guideH.Name = 'SnapGuideH'
	guideH.Size = UDim2.new(1, 0, 0, 1)
	guideH.Parent = scaledgui

	function nexus.ShowGuides(x, y)
		if not nexus.Drag.Guides then
			x, y = nil, nil
		end
		local accent = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
		guideV.Visible = x ~= nil
		if x then
			guideV.Position = UDim2.fromOffset(x, 0)
			guideV.BackgroundColor3 = accent
		end
		guideH.Visible = y ~= nil
		if y then
			guideH.Position = UDim2.fromOffset(0, y)
			guideH.BackgroundColor3 = accent
		end
	end

	function nexus.HideGuides()
		guideV.Visible = false
		guideH.Visible = false
	end
end

--[[
	Interface pane (Settings -> Interface)
	Hover style/intensity/lift, click pulses, UI sounds, tooltip behaviour,
	live corner radius and animation speed/easing. Everything persists through
	the normal per-game GUI settings file like any other Main option.
]]
do
	local interfacepane = mainapi.Categories.Main:CreateSettingsPane({Name = 'Interface'})

	interfacepane:CreateDropdown({
		Name = 'Hover style',
		List = {'Underline', 'Outline', 'Brighten', 'None'},
		Tooltip = 'How controls react to the cursor:\nUnderline - accent line grows from the centre\nOutline - accent border around the control\nBrighten - soft white wash\nNone - no extra effect',
		Function = function(val)
			nexus.Hover.Style = val
		end
	})
	interfacepane:CreateSlider({
		Name = 'Hover intensity',
		Min = 10,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Tooltip = 'Strength of the selected hover effect',
		Function = function(val)
			nexus.Hover.Intensity = val / 100
		end
	})
	interfacepane:CreateToggle({
		Name = 'Hover lift',
		Tooltip = 'Pops hovered controls up a touch (2% scale)',
		Function = function(callback)
			nexus.Hover.Lift = callback
		end
	})
	interfacepane:CreateToggle({
		Name = 'Click pulses',
		Tooltip = 'Expanding accent pulse where you click',
		Function = function(callback)
			nexus.Hover.Pulse = callback
		end
	})
	interfacepane:CreateToggle({
		Name = 'UI sounds',
		Tooltip = 'Click / notification / window-snap sounds.\nHover ticks have their own toggle below.',
		Function = function(callback)
			nexus.SoundsEnabled = callback
		end
	})
	interfacepane:CreateSlider({
		Name = 'UI volume',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Darker = true,
		Function = function(val)
			nexus.SoundVolume = val / 100
		end
	})
	interfacepane:CreateToggle({
		Name = 'Hover sounds',
		Darker = true,
		Tooltip = 'Soft tick when the cursor enters a control (needs UI sounds)',
		Function = function(callback)
			nexus.Hover.Sounds = callback
		end
	})
	interfacepane:CreateSlider({
		Name = 'Tooltip delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0,
		Suffix = 's',
		Tooltip = 'How long the cursor must rest on a control before its tooltip opens',
		Function = function(val)
			nexus.Tooltip.Delay = val
		end
	})
	interfacepane:CreateToggle({
		Name = 'Tooltips follow cursor',
		Default = true,
		Darker = true,
		Tooltip = 'Off - tooltips stay anchored where they opened',
		Function = function(callback)
			nexus.Tooltip.Follow = callback
		end
	})
	interfacepane:CreateSlider({
		Name = 'Corner radius',
		Min = 0,
		Max = 16,
		Default = 8,
		Suffix = 'px',
		Tooltip = 'Roundness of windows and panels, applied live',
		Function = function(val)
			cornerRadius = val
			for corner in cornerRegistry do
				if corner.Parent then
					corner.CornerRadius = UDim.new(0, val)
				end
			end
		end
	})

	-- Animation speed / easing rebuild the shared TweenInfo every micro-
	-- interaction in the GUI already reads from.
	local animDuration, animEasing, animEnabled = 0.16, Enum.EasingStyle.Quad, true
	local function rebuildTween()
		uipallet.Tween = TweenInfo.new(animEnabled and animDuration or 0, animEasing, Enum.EasingDirection.Out)
	end

	interfacepane:CreateToggle({
		Name = 'Animations',
		Default = true,
		Tooltip = 'Master switch for interface animations',
		Function = function(callback)
			animEnabled = callback
			rebuildTween()
		end
	})
	interfacepane:CreateSlider({
		Name = 'Animation speed',
		Min = 0.04,
		Max = 0.4,
		Decimal = 100,
		Default = 0.16,
		Suffix = 's',
		Darker = true,
		Tooltip = 'Duration of interface micro-animations',
		Function = function(val)
			animDuration = val
			rebuildTween()
		end
	})
	interfacepane:CreateDropdown({
		Name = 'Easing style',
		List = {'Quad', 'Sine', 'Exponential', 'Back', 'Elastic', 'Linear'},
		Darker = true,
		Tooltip = 'Easing curve used by interface animations',
		Function = function(val)
			local suc, style = pcall(function()
				return Enum.EasingStyle[val]
			end)
			if suc and style then
				animEasing = style
				rebuildTween()
			end
		end
	})
end

--[[
	Windows pane (Settings -> Windows)
	Custom positioning: snapping, guides, clamping, locking, smoothing, window
	open animation, one-click arrangement and named layouts persisted to
	aetherv2/profiles/layouts.json.
]]
do
	local windowspane = mainapi.Categories.Main:CreateSettingsPane({Name = 'Windows'})

	windowspane:CreateToggle({
		Name = 'Edge snapping',
		Default = true,
		Tooltip = 'Dragged windows stick to the screen edges and to the same column/row slots the Sort GUI button uses',
		Function = function(callback)
			nexus.Drag.EdgeSnap = callback
		end
	})
	windowspane:CreateToggle({
		Name = 'Window snapping',
		Default = true,
		Tooltip = 'Dragged windows align to the edges of other windows',
		Function = function(callback)
			nexus.Drag.WindowSnap = callback
		end
	})
	windowspane:CreateSlider({
		Name = 'Snap distance',
		Min = 2,
		Max = 32,
		Default = 12,
		Suffix = 'px',
		Darker = true,
		Function = function(val)
			nexus.Drag.SnapDistance = val
		end
	})
	windowspane:CreateToggle({
		Name = 'Alignment guides',
		Default = true,
		Darker = true,
		Tooltip = 'Accent lines along matched edges while snapping',
		Function = function(callback)
			nexus.Drag.Guides = callback
		end
	})
	windowspane:CreateToggle({
		Name = 'Grid snapping',
		Tooltip = 'Dragged windows lock to a fixed grid\n(holding LeftShift still snaps to 3px, as always)',
		Function = function(callback)
			nexus.Drag.Grid = callback
		end
	})
	windowspane:CreateSlider({
		Name = 'Grid size',
		Min = 8,
		Max = 64,
		Default = 24,
		Suffix = 'px',
		Darker = true,
		Function = function(val)
			nexus.Drag.GridSize = val
		end
	})
	windowspane:CreateToggle({
		Name = 'Keep windows on screen',
		Default = true,
		Tooltip = 'Windows cannot be dragged off the screen',
		Function = function(callback)
			nexus.Drag.Clamp = callback
		end
	})
	windowspane:CreateToggle({
		Name = 'Lock windows',
		Tooltip = 'Freezes every window in place - dragging does nothing until unlocked',
		Function = function(callback)
			nexus.Drag.Lock = callback
		end
	})
	windowspane:CreateSlider({
		Name = 'Drag smoothing',
		Min = 0,
		Max = 0.3,
		Decimal = 100,
		Default = 0,
		Suffix = 's',
		Tooltip = 'Windows glide after the cursor instead of jumping.\n0 disables smoothing.',
		Function = function(val)
			nexus.Drag.Smoothing = val
		end
	})
	windowspane:CreateDropdown({
		Name = 'Open animation',
		List = {'Pop', 'Fade', 'None'},
		Tooltip = 'How windows enter when the GUI opens',
		Function = function(val)
			nexus.OpenAnim = val
		end
	})

	-- Auto-save positions + snap sound on drag release.
	local autosave, savequeued = false, false
	windowspane:CreateToggle({
		Name = 'Auto-save positions',
		Tooltip = 'Writes window positions to your profile a moment after you finish dragging',
		Function = function(callback)
			autosave = callback
		end
	})
	function nexus.OnWindowMoved()
		nexus.PlaySound('snap')
		if autosave and mainapi.Loaded and not savequeued then
			savequeued = true
			task.delay(2, function()
				savequeued = false
				pcall(function()
					mainapi:Save()
				end)
			end)
		end
	end

	-- Named layouts: snapshot every window position (categories AND overlays)
	-- under a name, apply or delete it later. Stored globally, not per game.
	local layoutsPath = 'aetherv2/profiles/layouts.json'
	local layouts = (isfile(layoutsPath) and loadJson(layoutsPath)) or {}
	local layoutdrop

	local function layoutNames()
		local names = {}
		for name in layouts do
			table.insert(names, name)
		end
		table.sort(names)
		return names
	end

	local namebox = windowspane:CreateTextBox({
		Name = 'Layout name',
		Placeholder = 'e.g. bedwars',
		Tooltip = 'Name used by the Save window layout button'
	})
	windowspane:CreateButton({
		Name = 'Save window layout',
		Tooltip = 'Snapshots every window position under the name above',
		Function = function()
			local name = tostring(namebox.Value or ''):gsub('^%s*(.-)%s*$', '%1')
			if name == '' then
				name = os.date('layout %H-%M-%S')
			end
			local snapshot = {}
			for i, v in mainapi.Categories do
				if typeof(v.Object) == 'Instance' then
					snapshot[i] = {X = v.Object.Position.X.Offset, Y = v.Object.Position.Y.Offset}
				end
			end
			layouts[name] = snapshot
			pcall(writefile, layoutsPath, httpService:JSONEncode(layouts))
			layoutdrop:Change(layoutNames())
			layoutdrop:SetValue(name)
			mainapi:CreateNotification('Layouts', 'Saved window layout "'..name..'".', 4, 'info')
		end
	})
	layoutdrop = windowspane:CreateDropdown({
		Name = 'Saved layouts',
		List = layoutNames(),
		Darker = true,
		Tooltip = 'Pick a layout for Apply / Delete below'
	})
	windowspane:CreateButton({
		Name = 'Apply layout',
		Darker = true,
		Function = function()
			local snapshot = layouts[layoutdrop.Value]
			if not snapshot then
				mainapi:CreateNotification('Layouts', 'No layout selected.', 4, 'warning')
				return
			end
			for i, pos in snapshot do
				local category = mainapi.Categories[i]
				if category and typeof(category.Object) == 'Instance' and type(pos) == 'table' then
					category.Object.Position = UDim2.fromOffset(tonumber(pos.X) or 6, tonumber(pos.Y) or 42)
				end
			end
			nexus.PlaySound('snap')
		end
	})
	windowspane:CreateButton({
		Name = 'Delete layout',
		Darker = true,
		Function = function()
			local name = layoutdrop.Value
			if not layouts[name] then return end
			layouts[name] = nil
			pcall(writefile, layoutsPath, httpService:JSONEncode(layouts))
			layoutdrop:Change(layoutNames())
			mainapi:CreateNotification('Layouts', 'Deleted window layout "'..name..'".', 4, 'info')
		end
	})

	-- Window open animation + whoosh when the GUI toggles.
	mainapi:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
		nexus.PlaySound('open')
		if not clickgui.Visible or nexus.OpenAnim == 'None' then return end
		for _, v in mainapi.Categories do
			local win = v.Object
			if v.Type == 'Overlay' or typeof(win) ~= 'Instance' or not win.Visible then continue end
			if nexus.OpenAnim == 'Pop' then
				local openscale = win:FindFirstChild('NexusOpenScale')
				if not openscale then
					openscale = Instance.new('UIScale')
					openscale.Name = 'NexusOpenScale'
					openscale.Parent = win
				end
				openscale.Scale = 0.92
				tweenService:Create(openscale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1
				}):Play()
			elseif nexus.OpenAnim == 'Fade' then
				win.BackgroundTransparency = 1
				tween:Tween(win, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = uipallet.Glass
				})
			end
		end
	end))
end

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

return mainapi
