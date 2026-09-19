run(function()
	local SkinChanger
	local Options = {}
	local skins, families, groups, order = {}, {}, {}, {}
	local names, extras = {}, {}
	local sounds = {}
	local added = setmetatable({}, {__mode = 'k'})
	local watching, lasthand, queued
	local tiers = {leather = true, chainmail = true, wood = true, stone = true, gold = true, iron = true, diamond = true, emerald = true}
	
	-- Both of these come from the game rather than the pack, so stay tolerant of a build that lacks them
	local function getSkinMeta(skin)
		local getItemSkinMeta = bedwars.getItemSkinMeta
		return type(getItemSkinMeta) == 'function' and getItemSkinMeta(skin) or nil
	end

	for _, v in bedwars.ItemSkinType or {} do
		local meta = getSkinMeta(v)
		local item = meta and meta.itemType and bedwars.ItemMeta[meta.itemType]
		if item and not item.block then
			local label = `_{v}_`
			for i in meta.itemType:gmatch('[^_]+') do
				label = label:gsub(`_{i}_`, '_')
			end
			label = label:gsub('^_+', ''):gsub('_+$', '')
			label = (tostring(label ~= '' and label or v):gsub('_', ' '):gsub('%a+', function(word)
				return `{word:sub(1, 1):upper()}{word:sub(2)}`
			end))
	
			skins[meta.itemType] = skins[meta.itemType] or {}
			skins[meta.itemType][label] = v
		end
	end
	
	for i in skins do
		local family = i:gsub('_%d+$', '')
		local tier, base = family:match('^([^_]+)_(.+)$')
		family = tier and tiers[tier] and base or family
		if not groups[family] then
			groups[family] = {}
			table.insert(order, family)
		end
		families[i] = family
		table.insert(groups[family], i)
	end
	
	for i, v in groups do
		names[i] = (tostring(#v > 1 and i or v[1]):gsub('_', ' '):gsub('%a+', function(word)
			return `{word:sub(1, 1):upper()}{word:sub(2)}`
		end))
	end
	table.sort(order, function(a, b)
		return names[a] < names[b]
	end)
	
	for _, v in {'lobby_kaida_claw', 'bear_claws', 'summoner_claw_1', 'summoner_claw_2', 'summoner_claw_3', 'summoner_claw_4'} do
		if replicatedStorage.Items and replicatedStorage.Items:FindFirstChild(v) then
			local label = (tostring((v:gsub('^lobby_', ''))):gsub('_', ' '):gsub('%a+', function(word)
				return `{word:sub(1, 1):upper()}{word:sub(2)}`
			end))
			extras[label] = v
		end
	end
	
	local function applyModel(accessory)
		local family = SkinChanger.Enabled and families[accessory.Name]
		local option = family and Options[family]
		local label = option and option.Value
		local model = label and (extras[label] or skins[accessory.Name][label]) or nil
		local handle = accessory:FindFirstChild('Handle')
		local template = replicatedStorage.Items and replicatedStorage.Items:FindFirstChild(model or '')
		if not handle or not template then return end
		if added[accessory] then return end
	
		local grip = handle:FindFirstChild('RightGripAttachment')
		local templategrip = template.Handle:FindFirstChild('RightGripAttachment')
		local record = {
			Parts = {},
			Size = handle.Size,
			Grip = grip and grip.CFrame or nil
		}
		added[accessory] = record
	
		for _, v in handle:GetChildren() do
			if v:IsA('BasePart') and v:GetAttribute('SkinHidden') == nil then
				v:SetAttribute('SkinHidden', v.Transparency)
				v.Transparency = 1
			end
		end
	
		if handle:IsA('MeshPart') and template.Handle:IsA('MeshPart') then
			handle:ApplyMesh(template.Handle)
		end
		handle.Size = template.Handle.Size
		if grip and templategrip then
			grip.CFrame = templategrip.CFrame
		end
	
		for _, v in template.Handle:GetChildren() do
			if v:IsA('BasePart') then
				local part = v:Clone()
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.CFrame = handle.CFrame * (template.Handle.CFrame:Inverse() * v.CFrame)
				part.Parent = handle
	
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
				table.insert(record.Parts, part)
			end
		end
	end
	
	local function applySkins()
		for i in skins do
			local meta = bedwars.ItemMeta[i]
			if meta and meta.sword then
				local family = SkinChanger.Enabled and families[i]
				local option = family and Options[family]
				local label = option and option.Value
				local skin = label and not extras[label] and skins[i][label] or nil
				local skinmeta = skin and getSkinMeta(skin)
				local sword = skinmeta and skinmeta.sword
				if sword and (sword.swingSounds or sword.hitSounds) then
					if not sounds[i] then
						sounds[i] = {swing = meta.sword.swingSounds, hit = meta.sword.hitSounds}
					end
					meta.sword.swingSounds = sword.swingSounds or sounds[i].swing
					meta.sword.hitSounds = sword.hitSounds or sounds[i].hit
				elseif sounds[i] then
					meta.sword.swingSounds = sounds[i].swing
					meta.sword.hitSounds = sounds[i].hit
					sounds[i] = nil
				end
			end
		end
	
		local inventory = store.inventory.inventory
		local changed = false
		for _, v in inventory.items do
			local family = SkinChanger.Enabled and families[v.itemType]
			local option = family and Options[family]
			local label = option and option.Value
			local skin = label and not extras[label] and skins[v.itemType][label] or nil
			if v.itemSkin ~= skin then
				v.itemSkin = skin
				changed = true
			end
		end
		if inventory.hand then
			local family = SkinChanger.Enabled and families[inventory.hand.itemType]
			local option = family and Options[family]
			local label = option and option.Value
			local skin = label and not extras[label] and skins[inventory.hand.itemType][label] or nil
			if inventory.hand.itemSkin ~= skin then
				inventory.hand.itemSkin = skin
				changed = true
			end
		end
	
		local hand = inventory.hand and inventory.hand.itemType
		if not changed and hand == lasthand then return end
	
		lasthand = hand
		bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
		if not lplr.Character then return end
	
		for _, v in lplr.Character:GetChildren() do
			if not v:IsA('Accessory') then continue end
	
			local record = added[v]
			if record then
				local handle = v:FindFirstChild('Handle')
				local template = replicatedStorage.Items and replicatedStorage.Items:FindFirstChild(v.Name)
				for _, v2 in record.Parts do
					v2:Destroy()
				end
	
				for _, v2 in handle and handle:GetChildren() or {} do
					local transparency = v2:GetAttribute('SkinHidden')
					if transparency then
						v2.Transparency = transparency
						v2:SetAttribute('SkinHidden', nil)
					end
				end
				added[v] = nil
	
				if handle then
					if template and handle:IsA('MeshPart') and template.Handle:IsA('MeshPart') then
						handle:ApplyMesh(template.Handle)
					end
					handle.Size = record.Size
	
					local grip = handle:FindFirstChild('RightGripAttachment')
					if grip and record.Grip then
						grip.CFrame = record.Grip
					end
				end
			end
	
			applyModel(v)
		end
	end
	
	local function queueSkins()
		if queued then return end
	
		queued = true
		task.defer(function()
			queued = false
			applySkins()
		end)
	end
	
	SkinChanger = vape.Categories.Render:CreateModule({
		Name = 'SkinChanger',
		Function = function(callback)
			if callback then
				SkinChanger:Clean(vapeEvents.InventoryChanged.Event:Connect(queueSkins))
				SkinChanger:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(queueSkins))
				SkinChanger:Clean(lplr.CharacterAdded:Connect(function(char)
					lasthand = nil
					if watching then
						watching:Disconnect()
					end
					watching = char.ChildAdded:Connect(function(v)
						if v:IsA('Accessory') and v:WaitForChild('Handle', 3) and SkinChanger.Enabled then
							applyModel(v)
						end
					end)
	
					task.spawn(function()
						for _ = 1, 10 do
							task.wait(0.4)
							if not SkinChanger.Enabled then return end
							applySkins()
						end
					end)
				end))
	
				if lplr.Character then
					if watching then
						watching:Disconnect()
					end
					watching = lplr.Character.ChildAdded:Connect(function(v)
						if v:IsA('Accessory') and v:WaitForChild('Handle', 3) and SkinChanger.Enabled then
							applyModel(v)
						end
					end)
				end
			elseif watching then
				watching:Disconnect()
				watching = nil
			end
			applySkins()
		end,
		Tooltip = 'Reskins the items you hold with their sounds (client-sided)'
	})
	
	for _, v in order do
		local list, seen = {}, {}
		for _, v2 in groups[v] do
			for i2 in skins[v2] do
				if not seen[i2] then
					seen[i2] = true
					table.insert(list, i2)
				end
			end
		end
	
		local melee = false
		for _, v2 in groups[v] do
			local meta = bedwars.ItemMeta[v2]
			if meta and meta.sword then
				melee = true
				break
			end
		end
	
		if melee then
			for i2 in extras do
				table.insert(list, i2)
			end
		end
	
		table.sort(list)
		table.insert(list, 1, 'None')
		Options[v] = SkinChanger:CreateDropdown({
			Name = names[v],
			List = list,
			Function = function()
				if SkinChanger.Enabled then
					applySkins()
				end
			end
		})
	end
end)
