run(function()
    local KitESP
    local Background
    local Color = {}
    local Reference = {}
    local kitGeneration = 0
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local ESPKits = {
	alchemist = {'alchemist_ingedients', 'wild_flower'},
	beekeeper = {'bee', 'bee'},
	bigman = {'treeOrb', 'natures_essence_1'},
	ghost_catcher = {'ghost', 'ghost_orb'},
	metal_detector = {'hidden-metal', 'iron'},
	sheep_herder = {'SheepModel', 'purple_hay_bale'},
	sorcerer = {'alchemy_crystal', 'wild_flower'},
	star_collector = {'stars', 'crit_star'},
    }

    local function Added(v, icon)
	local billboard = Instance.new('BillboardGui')
	billboard.Parent = Folder
	billboard.Name = icon
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.Size = UDim2.fromOffset(36, 36)
	billboard.AlwaysOnTop = true
	billboard.ClipsDescendants = false
	billboard.Adornee = v
	local blur = addBlur(billboard)
	blur.Visible = Background.Enabled
	local image = Instance.new('ImageLabel')
	image.Size = UDim2.fromOffset(36, 36)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
	image.BorderSizePixel = 0
	image.Image = bedwars.getIcon({ itemType = icon }, true)
	image.Parent = billboard
	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0, 4)
	uicorner.Parent = image
	Reference[v] = billboard
    end

    local function addKit(kitName, tag, icon)
	KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
		if store.equippedKit == kitName and v.PrimaryPart then Added(v.PrimaryPart, icon) end
	end))
	KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
		if v.PrimaryPart and Reference[v.PrimaryPart] then
			Reference[v.PrimaryPart]:Destroy()
			Reference[v.PrimaryPart] = nil
		end
	end))
    end
	local function refreshKit()
		Folder:ClearAllChildren()
		table.clear(Reference)
		local kit = ESPKits[store.equippedKit]
		if not kit then return end
		for _, object in collectionService:GetTagged(kit[1]) do if object.PrimaryPart then Added(object.PrimaryPart, kit[2]) end end
	end

    KitESP = kits:CreateModule({
	Name = 'KitESP',
	Category = 'Visual',
	Function = function(callback)
		kitGeneration += 1
		if callback then
			local generation = kitGeneration
			for kitName, kit in ESPKits do addKit(kitName, kit[1], kit[2]) end
			local activeKit = store.equippedKit
			refreshKit()
			-- Kit changes are store-driven but this store wrapper has no change signal. Polling four
			-- times a second is indistinguishable to the user and avoids a comparison every frame.
			task.spawn(function()
				while KitESP.Enabled and kitGeneration == generation do
					task.wait(0.25)
					if kitGeneration ~= generation then break end
					if store.equippedKit ~= activeKit then activeKit = store.equippedKit; refreshKit() end
				end
			end)
		else
			Folder:ClearAllChildren()
			table.clear(Reference)
		end
	end,
	Tooltip = 'ESP for certain kit related objects'
    })
    Background = KitESP:CreateToggle({
	Name = 'Background',
	Function = function(callback)
		if Color.Object then
			Color.Object.Visible = callback
		end
		for _, v in Reference do
			v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
			v.Blur.Visible = callback
		end
	end,
	Default = true,
    })
    Color = KitESP:CreateColorSlider({
	Name = 'Background Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		for _, v in Reference do
			v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			v.ImageLabel.BackgroundTransparency = 1 - opacity
		end
	end,
	Darker = true,
    })
end)
