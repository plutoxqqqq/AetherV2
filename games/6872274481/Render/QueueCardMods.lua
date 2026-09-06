local function category(name)
	if vape and vape.Categories and vape.Categories[name] then
		return vape.Categories[name]
	end
	if vape and vape.Categories then
		for _, cat in pairs(vape.Categories) do
			if type(cat) == "table" and cat.CreateModule then
				return cat
			end
		end
	end
	return nil
end

local function createModule(catName, def)
	local cat = category(catName) or category("Utility") or category("Render") or category("Blatant")
	assert(cat and cat.CreateModule, "Aether GUI not ready (no CreateModule)")
	return cat:CreateModule(def)
end

local function isAlive(plr)
	plr = plr or lplr
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and root ~= nil and hum.Health > 0
end

local function guiColor()
	local ok, color = pcall(function()
		if vape.GUIColor then
			return Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		end
	end)
	if ok and color then return color end
	return Color3.fromRGB(120, 200, 255)
end

local store = shared.store or getgenv().store
local bedwars = shared.bedwars or (store and store.bedwars)
local entitylib = (vape and vape.Libraries and (vape.Libraries.entity or vape.Libraries.entitylib))
	or shared.vapeentity
	or shared.entityLibrary
local whitelist = (vape and vape.Libraries and vape.Libraries.whitelist) or shared.vapewhitelist

run(function()
	local cfg = {
		speed = 0.5,
		c1 = {H = 0.6, S = 0.8, V = 1},
		c2 = {H = 0.8, S = 0.8, V = 0.8}
	}
	local conA, conB
	local Color1, Color2, Speed

	local function apply()
		pcall(function()
			if conA then conA:Disconnect() end
			local app = lplr.PlayerGui:FindFirstChild("QueueApp")
			if not app then return end
			local frame = app:FindFirstChild("1")
			if not frame then return end
			frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			local g = frame:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
			g.Rotation = 180
			g.Parent = frame
			conA = runService.RenderStepped:Connect(function()
				local t = (math.sin(tick() * cfg.speed) + 1) / 2
				local h = cfg.c1.H + (cfg.c2.H - cfg.c1.H) * t
				local s = cfg.c1.S + (cfg.c2.S - cfg.c1.S) * t
				local v = cfg.c1.V + (cfg.c2.V - cfg.c1.V) * t
				g.Color = ColorSequence.new(Color3.fromHSV(h, s, v))
			end)
		end)
	end

	local QueueCard = createModule("Render", {
		Name = "QueueCardMods",
		Tooltip = "Animated gradient on the queue card",
		Function = function(on)
			if on then
				apply()
				conB = lplr.PlayerGui.ChildAdded:Connect(function(c)
					if c.Name == "QueueApp" then
						task.wait(0.1)
						apply()
					end
				end)
			else
				if conA then conA:Disconnect() end
				if conB then conB:Disconnect() end
				conA, conB = nil, nil
			end
		end
	})

	Speed = QueueCard:CreateSlider({
		Name = "Animation Speed",
		Min = 1,
		Max = 5,
		Default = 3,
		Function = function(val)
			cfg.speed = math.clamp(val, 0.1, 5)
		end
	})

	if QueueCard.CreateColorSlider then
		QueueCard:CreateColorSlider({
			Name = "Color 1",
			Function = function(h, s, v)
				cfg.c1 = {H = h, S = s, V = v}
			end
		})
		QueueCard:CreateColorSlider({
			Name = "Color 2",
			Function = function(h, s, v)
				cfg.c2 = {H = h, S = s, V = v}
			end
		})
	end
end)
