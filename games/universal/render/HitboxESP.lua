run(function()
	local HitboxESP
	local Color
	local Transparency
	local Walls
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Name = 'AetherHitboxESP'
	Folder.Parent = vape.gui

	local function isValid(ent)
		return ent.Player and ent.Player ~= lplr and ent.Character and ent.Character.Parent
	end

	local function remove(ent)
		local refs = Reference[ent]
		if not refs then
			return
		end
		for _, adornment in refs do
			adornment:Destroy()
		end
		Reference[ent] = nil
	end

	local function add(ent)
		if not isValid(ent) then
			return
		end
		remove(ent)

		local refs = {}
		local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		for _, part in ent.Character:GetDescendants() do
			if part:IsA('BasePart') and part.Transparency < 1 and part.Name ~= 'HumanoidRootPart' then
				local box = Instance.new('BoxHandleAdornment')
				box.Name = 'Hitbox'
				box.Adornee = part
				box.Size = part.Size
				box.CFrame = CFrame.identity
				box.AlwaysOnTop = Walls.Enabled
				box.ZIndex = 0
				box.Color3 = color
				box.Transparency = Transparency.Value
				box.Parent = Folder
				table.insert(refs, box)
			end
		end
		Reference[ent] = refs
	end

	HitboxESP = vape.Categories.Render:CreateModule({
		Name = 'HitboxESP',
		Function = function(callback)
			if callback then
				HitboxESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					add(ent)
				end))
				HitboxESP:Clean(entitylib.Events.EntityRemoved:Connect(function(ent)
					remove(ent)
				end))
				HitboxESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for ent, refs in Reference do
						local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						for _, box in refs do
							box.Color3 = color
						end
					end
				end))
				for _, ent in entitylib.List do
					add(ent)
				end
			else
				for ent in Reference do
					remove(ent)
				end
			end
		end,
		Tooltip = 'Displays player hitboxes as transparent coloured boxes.'
	})

	Color = HitboxESP:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for ent, refs in Reference do
				local color = entitylib.getEntityColor(ent) or Color3.fromHSV(hue, sat, val)
				for _, box in refs do
					box.Color3 = color
				end
			end
		end
	})

	Transparency = HitboxESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.65,
		Decimal = 10,
		Function = function(value)
			for _, refs in Reference do
				for _, box in refs do
					box.Transparency = value
				end
			end
		end
	})

	Walls = HitboxESP:CreateToggle({
		Name = 'Render Walls',
		Default = true,
		Function = function(callback)
			for _, refs in Reference do
				for _, box in refs do
					box.AlwaysOnTop = callback
				end
			end
		end
	})
end)