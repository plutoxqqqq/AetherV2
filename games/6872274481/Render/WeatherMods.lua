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
	local parts = {}
	local cfg = {
		Spread = 35,
		Rate = 28,
		Height = 100,
		Wind = true,
		Color = Color3.new(1, 1, 1)
	}

	local function makeEmitter(parent, wind)
		local e = Instance.new("ParticleEmitter")
		e.RotSpeed = NumberRange.new(wind and 100 or 300)
		e.Rate = cfg.Rate
		e.Texture = "rbxassetid://8158344433"
		e.Rotation = NumberRange.new(110)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.17),
			NumberSequenceKeypoint.new(0.56, 0.39),
			NumberSequenceKeypoint.new(1, 1)
		})
		e.Lifetime = NumberRange.new(8, 14)
		e.Speed = NumberRange.new(8, 18)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(cfg.Spread, cfg.Spread)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.04, 1.3),
			NumberSequenceKeypoint.new(1, 0)
		})
		e.Color = ColorSequence.new(cfg.Color)
		if wind then
			e.Acceleration = Vector3.new(0, 0, 1)
		end
		e.Parent = parent
		return e
	end

	local function wipe()
		for _, o in ipairs(parts) do
			pcall(function() o:Destroy() end)
		end
		table.clear(parts)
	end

	local Weather = createModule("Render", {
		Name = "WeatherMods",
		Tooltip = "Local snow particles that follow you",
		Function = function(on)
			if not on then
				wipe()
				return
			end
			task.spawn(function()
				local base = Instance.new("Part")
				base.Size = Vector3.new(240, 0.5, 240)
				base.Name = "AetherWeatherBase"
				base.Transparency = 1
				base.CanCollide = false
				base.Anchored = true
				base.Parent = workspace
				table.insert(parts, base)
				local snow = makeEmitter(base, false)
				local wind = makeEmitter(base, true)
				wind.Enabled = cfg.Wind
				table.insert(parts, snow)
				table.insert(parts, wind)
				while Weather.Enabled do
					local root
					if entitylib and entitylib.isAlive and entitylib.character then
						root = entitylib.character.HumanoidRootPart or entitylib.character.RootPart
					elseif isAlive() then
						root = lplr.Character.HumanoidRootPart
					end
					if root then
						base.Position = root.Position + Vector3.new(0, cfg.Height, 0)
					end
					snow.Rate = cfg.Rate
					wind.Rate = cfg.Rate
					snow.SpreadAngle = Vector2.new(cfg.Spread, cfg.Spread)
					wind.SpreadAngle = Vector2.new(cfg.Spread, cfg.Spread)
					snow.Color = ColorSequence.new(cfg.Color)
					wind.Color = ColorSequence.new(cfg.Color)
					wind.Enabled = cfg.Wind
					task.wait(0.1)
				end
				wipe()
			end)
		end
	})

	Weather:CreateSlider({
		Name = "Spread", Min = 1, Max = 100, Default = 35,
		Function = function(v) cfg.Spread = v end
	})
	Weather:CreateSlider({
		Name = "Rate", Min = 1, Max = 100, Default = 28,
		Function = function(v) cfg.Rate = v end
	})
	Weather:CreateSlider({
		Name = "Height", Min = 1, Max = 200, Default = 100,
		Function = function(v) cfg.Height = v end
	})
	Weather:CreateToggle({
		Name = "Wind Effect", Default = true,
		Function = function(v) cfg.Wind = v end
	})
	if Weather.CreateColorSlider then
		Weather:CreateColorSlider({
			Name = "Particle Color",
			Function = function(h, s, v)
				cfg.Color = Color3.fromHSV(h, s, v)
			end
		})
	end
end)
