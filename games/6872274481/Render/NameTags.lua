run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local Rank
	local Enchant
	local Equipment
	local Inventory
	local InventoryList
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference, Refreshes = {}, {}, {}, {}

	-- This pack's font helper wants an explicit bounds vector; the reference calls it without one
	local getfontbounds = function(text, size, font)
		return getfontsize(text, size, font, Vector2.new(100000, 100000))
	end
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	
	local function updateInventory(ent, nametag)
		local holder = ent.Player and nametag:FindFirstChild('Inventory')
		local inventory = holder and store.inventories[ent.Player]
		if not inventory then return end
	
		local shown = 0
		for _, v in inventory.items or {} do
			if #InventoryList.ListEnabled > 0 and not table.find(InventoryList.ListEnabled, v.itemType) then continue end
	
			shown += 1
			local icon = holder:FindFirstChild(tostring(shown))
			if not icon then
				icon = Instance.new('ImageLabel')
				icon.Name = tostring(shown)
				icon.Size = UDim2.fromOffset(24, 24)
				icon.BackgroundTransparency = 1
				icon.Parent = holder
				local amount = Instance.new('TextLabel')
				amount.Name = 'Amount'
				amount.Size = UDim2.fromOffset(23, 11)
				amount.Position = UDim2.fromOffset(0, 13)
				amount.BackgroundTransparency = 1
				amount.FontFace = nametag.FontFace
				amount.TextSize = 11
				amount.TextColor3 = Color3.new(1, 1, 1)
				amount.TextStrokeColor3 = Color3.new()
				amount.TextStrokeTransparency = 0.4
				amount.TextXAlignment = Enum.TextXAlignment.Right
				amount.Parent = icon
			end
	
			icon.LayoutOrder = shown
			icon.Visible = true
			icon.Image = bedwars.getIcon(v, true)
			icon.Amount.Text = (v.amount or 1) > 1 and tostring(v.amount) or ''
		end
	
		for _, v in holder:GetChildren() do
			if v:IsA('ImageLabel') and tonumber(v.Name) > shown then
				v.Visible = false
			end
		end
	end
	
	local Added = {
		Normal = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = Instance.new('TextLabel')
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			if Equipment.Enabled then
				for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
				end
			end
	
			if Inventory.Enabled and ent.Player then
				local holder = Instance.new('Frame')
				holder.Name = 'Inventory'
				holder.AnchorPoint = Vector2.new(0.5, 0)
				holder.AutomaticSize = Enum.AutomaticSize.X
				holder.BackgroundTransparency = 1
				holder.Position = UDim2.new(0.5, 0, 1, 2)
				holder.Size = UDim2.fromOffset(0, 24)
				holder.Parent = nametag
				local layout = Instance.new('UIListLayout')
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				layout.Padding = UDim.new(0, 2)
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = holder
			end
	
			nametag.TextSize = 14 * Scale.Value
			nametag.FontFace = FontOption.Value
			local size = getfontbounds(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace)
	
			task.spawn(function()
				if Rank.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'RankIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(size.X + 10, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = store.rank[ent.Player]:async() and bedwars.RankMeta[store.rank[ent.Player]:async()].image or ''
					Icon.Parent = nametag
				end
			end)
	
			task.spawn(function()
				if Enchant.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'EnchantIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-30, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = store.enchants[ent.Player]:async() or ''
					Icon.Parent = nametag
				end
			end)
	
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Distance.Enabled and entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
			nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
	
			nametag.Parent = Folder
			Reference[ent] = nametag
		end,
		Drawing = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = {}
			nametag.BG = Drawing.new('Square')
			nametag.BG.Filled = true
			nametag.BG.Transparency = 1 - Background.Value
			nametag.BG.Color = Color3.new()
			nametag.BG.ZIndex = 1
			nametag.Text = Drawing.new('Text')
			nametag.Text.Size = 15 * Scale.Value
			nametag.Text.Font = 0
			nametag.Text.ZIndex = 2
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
	
			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end
	
			nametag.Text.Text = Strings[ent]
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			Reference[ent] = nametag
		end
	}
	
	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				Refreshes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, v2 in v do
					pcall(function()
						v2.Visible = false
						v2:Remove()
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if nametag then
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				if Equipment.Enabled and store.inventories[ent.Player] then
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					local kitmeta = kit and kit ~= 'none' and bedwars.BedwarsKitMeta[kit]
					local inventory = store.inventories[ent.Player]
					local armor = {}
					for _, v in inventory.armor or {} do
						local itemmeta = typeof(v) == 'table' and bedwars.ItemMeta[v.itemType]
						if itemmeta and itemmeta.armor then
							armor[itemmeta.armor.slot] = v
						end
					end
	
					nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
					nametag.Helmet.Image = bedwars.getIcon(armor[0] or {itemType = ''}, true)
					nametag.Chestplate.Image = bedwars.getIcon(armor[1] or {itemType = ''}, true)
					nametag.Boots.Image = bedwars.getIcon(armor[2] or {itemType = ''}, true)
					nametag.Kit.Image = kitmeta and kitmeta.renderImage or ''
				end
	
				if Inventory.Enabled then
					updateInventory(ent, nametag)
				end
	
				if Enchant.Enabled and nametag:FindFirstChild('EnchantIcon') then
					nametag.EnchantIcon.Image = store.enchants[ent.Player]:async() or ''
				end
	
				local text = Distance.Enabled and entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				local size = getfontbounds(removeTags(text), nametag.TextSize, nametag.FontFace)
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				nametag.Text = text
			end
		end,
		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end
	
				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end
	
				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	}
	
	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = entitylib.getEntityColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Text.Color = entitylib.getEntityColor(i) or color
			end
		end
	}
	
	local Loop = {
		Normal = function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position
	
			for i, v in Reference do
				local rootPosition = i.RootPart.Position
	
				if DistanceCheck.Enabled then
					local distance = localPosition and (localPosition - rootPosition).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						v.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(rootPosition + Vector3.new(0, i.HipHeight + 1, 0))
				v.Visible = headVis
				if not headVis then
					continue
				end
	
				if Inventory.Enabled and i.Player and (Refreshes[i] or 0) < tick() then
					Refreshes[i] = tick() + 0.5
					store.inventories[i.Player] = bedwars.getInventory(i.Player)
					updateInventory(i, v)
				end
	
				if Distance.Enabled then
					local mag = localPosition and math.floor((localPosition - rootPosition).Magnitude) or 0
					if Sizes[i] ~= mag then
						v.Text = string.format(Strings[i], mag)
						local ize = getfontbounds(removeTags(v.Text), v.TextSize, v.FontFace)
						v.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
						Sizes[i] = mag
					end
				end
				v.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position
	
			for i, v in Reference do
				local rootPosition = i.RootPart.Position
	
				if DistanceCheck.Enabled then
					local distance = localPosition and (localPosition - rootPosition).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						v.Text.Visible = false
						v.BG.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(rootPosition + Vector3.new(0, i.HipHeight + 1, 0))
				v.Text.Visible = headVis
				v.BG.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = localPosition and math.floor((localPosition - rootPosition).Magnitude) or 0
					if Sizes[i] ~= mag then
						v.Text.Text = string.format(Strings[i], mag)
						v.BG.Size = Vector2.new(v.Text.TextBounds.X + 8, v.Text.TextBounds.Y + 7)
						Sizes[i] = mag
					end
				end
				v.BG.Position = Vector2.new(headPos.X - (v.BG.Size.X / 2), headPos.Y - v.BG.Size.Y)
				v.Text.Position = v.BG.Position + Vector2.new(4, 3)
			end
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							Removed[methodused](v)
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							Removed[methodused](ent)
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do
						Updated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
	})
	
	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Inventory = NameTags:CreateToggle({
		Name = 'Inventory',
		Function = function(callback)
			if InventoryList then
				InventoryList.Object.Visible = callback
			end
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Tooltip = 'Shows how many of each listed item they are carrying'
	})
	InventoryList = NameTags:CreateTextList({
		Name = 'Inventory Items',
		Default = {'fireball', 'glue_projectile', 'telepearl', 'tnt'},
		Darker = true,
		Visible = false,
		Tooltip = 'Item types to count, empty shows everything they hold'
	})
	Enchant = NameTags:CreateToggle({
		Name = 'Show Enchant',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Rank = NameTags:CreateToggle({
		Name = 'Show Rank',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
