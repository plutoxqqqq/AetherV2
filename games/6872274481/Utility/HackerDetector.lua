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
	local cons = {}
	local flagged = {TP = {}, Speed = {}, Fly = {}, Invis = {}}
	local DetTP, DetSpeed, DetFly, DetInvis
	local TPDist, SpeedDist

	local function flag(kind, plr, reason)
		if flagged[kind][plr] then return end
		flagged[kind][plr] = true
		notify("HackerDetector", plr.DisplayName .. " — " .. reason, 8)
		pcall(function()
			if not isfolder then return end
			if not isfolder("aether") then makefolder("aether") end
			local cache = {}
			pcall(function()
				cache = httpService:JSONDecode(readfile("aether/exploiters.json"))
			end)
			cache[plr.Name] = cache[plr.Name] or {UserId = plr.UserId, Hits = {}}
			table.insert(cache[plr.Name].Hits, {kind = kind, t = os.time()})
			writefile("aether/exploiters.json", httpService:JSONEncode(cache))
		end)
	end

	local function watch(plr)
		if plr == lplr then return end
		local lastPos = Vector3.zero
		local lastTP = plr:GetAttribute("LastTeleported") or 0

		table.insert(cons, plr:GetAttributeChangedSignal("LastTeleported"):Connect(function()
			lastTP = plr:GetAttribute("LastTeleported") or lastTP
		end))

		table.insert(cons, plr.CharacterAdded:Connect(function()
			task.delay(0.4, function()
				if isAlive(plr) then
					lastPos = plr.Character.HumanoidRootPart.Position
				end
			end)
		end))

		task.spawn(function()
			while HackerDetector.Enabled and plr.Parent do
				if isAlive(plr) then
					local root = plr.Character.HumanoidRootPart
					local pos = root.Position
					local delta = (pos - lastPos).Magnitude
					local officialTP = (plr:GetAttribute("LastTeleported") or 0) ~= lastTP

					if DetTP and DetTP.Enabled and delta >= (TPDist and TPDist.Value or 400) and not officialTP then
						flag("TP", plr, "Teleport")
					end
					if DetSpeed and DetSpeed.Enabled and delta >= (SpeedDist and SpeedDist.Value or 25) and officialTP then
						flag("Speed", plr, "Speed")
					end
					if DetFly and DetFly.Enabled then
						local params = RaycastParams.new()
						params.FilterDescendantsInstances = {plr.Character}
						params.FilterType = Enum.RaycastFilterType.Exclude
						local hit = workspace:Raycast(pos, Vector3.new(0, -80, 0), params)
						if not hit and root.AssemblyLinearVelocity.Y > -2 and delta > 8 then
							flag("Fly", plr, "InfiniteFly")
						end
					end
					if DetInvis and DetInvis.Enabled then
						local head = plr.Character:FindFirstChild("Head")
						if head and head.Transparency >= 0.9 then
							flag("Invis", plr, "Invisibility")
						end
					end
					lastPos = pos
				end
				task.wait(2.5)
			end
		end)
	end

	HackerDetector = createModule("Utility", {
		Name = "HackerDetector",
		Tooltip = "Flags suspicious movement on other players",
		Function = function(on)
			if on then
				for _, plr in ipairs(players:GetPlayers()) do
					watch(plr)
				end
				table.insert(cons, players.PlayerAdded:Connect(watch))
			else
				for _, c in ipairs(cons) do
					pcall(function() c:Disconnect() end)
				end
				table.clear(cons)
			end
		end
	})

	DetTP = HackerDetector:CreateToggle({Name = "Teleport", Default = true})
	DetSpeed = HackerDetector:CreateToggle({Name = "Speed", Default = true})
	DetFly = HackerDetector:CreateToggle({Name = "InfiniteFly", Default = true})
	DetInvis = HackerDetector:CreateToggle({Name = "Invisibility", Default = true})
	TPDist = HackerDetector:CreateSlider({Name = "TP Distance", Min = 80, Max = 800, Default = 400})
	SpeedDist = HackerDetector:CreateSlider({Name = "Speed Distance", Min = 15, Max = 80, Default = 25})
end)
