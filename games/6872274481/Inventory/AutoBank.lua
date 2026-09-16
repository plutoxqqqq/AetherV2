run(function()
    local AutoBank
    local Whitelist
    local DisplayResources
    local Mode
    local ChestRange
    local Withdraw
    local OnlyWhenLow
    local LowHealth
    local BeforeDeath
    local HPThreshold
    local BeforeDeathWhitelist
    local DepositKey
    local WithdrawKey
    local UI

    local util = vape.Libraries.bedwarsutil

    
    local droppedItems = {}
    
    
    local dropCooldowns = {}
    
    
    
    local chestCooldowns = {}
    
    
    
    local pendingDrops = {}
    local pendingReclaims = {}
    
    
    
    local releasingDrops = {}
    local displayEntries = {}
    
    
    
    local dangerTriggered = false
    local dangerCharacter
    local beforeDeathDepositing = false
    local chestDepositBusy = false
	local dangerConnections = {}
	local evaluateDanger

    
    
    
    
    
    local BANK_HEIGHT = 120
    local BANK_SPACING = 4
    local BANK_COLUMNS = 8

    
    
    local LEGIT_DEFAULT_HP = 30

    local function untrackDrop(drop)
        releasingDrops[drop] = nil
        pendingReclaims[drop] = nil
        local index = table.find(droppedItems, drop)
        if index then
            table.remove(droppedItems, index)
        end
    end

    
    
    local function reclaim(drop)
        if not drop or not drop.Parent then
            untrackDrop(drop)
            return
        end
        if not entitylib.isAlive then return end

        releasingDrops[drop] = true
        
        
        drop.Velocity = Vector3.zero
        drop.CFrame = entitylib.character.Head.CFrame
        if pendingReclaims[drop] then return end
        pendingReclaims[drop] = true

		local ok = pcall(function()
			
			
			bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {itemDrop = drop}):andThen(function(success)
                pendingReclaims[drop] = nil
                if not drop.Parent then
                    untrackDrop(drop)
                elseif AutoBank.Enabled then
                    
                    
                    
                    task.delay(success and 0.03 or 0.1, reclaim, drop)
                end
            end, function()
                pendingReclaims[drop] = nil
                if AutoBank.Enabled and drop.Parent then
                    task.delay(0.1, reclaim, drop)
                end
            end)
        end)
        if not ok then
            pendingReclaims[drop] = nil
            if AutoBank.Enabled and drop.Parent then
                task.delay(0.1, reclaim, drop)
            end
        end
    end

    
    -- At either shopkeeper, using the same in-range check (and the same 20 studs) the other
    -- shop modules use, or with a buying screen already open.
    local function atShop()
        return util.Shop.BuyScreenOpen() or util.Shop.Nearby() ~= nil
    end

    
    
    

    local inventoryRemotes = util.Chest.Remotes

    
    
    
    local ownPersonalFolder = util.Chest.OwnFolder

    
    
    
    
    local function chestRange()
        local range = ChestRange and tonumber(ChestRange.Value)
        return range and range > 0 and range or util.Chest.Range
    end

    
    
    
    -- The chest screen counts as being at the chest, so banking keeps working while it is
    -- open; otherwise the same tagged-chest scan AutoSteal uses, at the configured range.
    local function atPersonalChest()
        return util.Shop.ChestScreenOpen() or util.Chest.InRange(chestRange())
    end

    
    local chestTotals = util.Chest.Totals

    
    
    
    local function currentHealth()
        return util.Health.Current()
    end

    
    
    local shopScreenOpen = util.Shop.BuyScreenOpen

    
    
    
    
    
    local function bankable(item)
        local name = item and (item.itemType or (item.tool and item.tool.Name))
        if not name or not item.tool then return false end
        local meta = bedwars.ItemMeta and bedwars.ItemMeta[name]
        if meta and (meta.armor or meta.sword or meta.breakBlock) then return false end
        return true
    end

    
    
    local function depositAllToChest(folder)
        if chestDepositBusy then return false end
        local wanted = {}
        for _, item in store.inventory.inventory.items do
            local name = item.itemType or (item.tool and item.tool.Name)
            if name and bankable(item) and (chestCooldowns[name] or 0) < os.clock() then
                table.insert(wanted, {Name = name, Tool = item.tool})
            end
        end
        if #wanted == 0 then return false end

        chestDepositBusy = true
        pcall(function()
            inventoryRemotes():Get('SetObservedChest'):SendToServer(folder)
        end)
        for _, entry in wanted do
            if not AutoBank.Enabled then break end
            local ok, given = pcall(function()
                return inventoryRemotes():Get('ChestGiveItem'):CallServer(folder, entry.Tool)
            end)
            if not ok or not given then
                
                
                chestCooldowns[entry.Name] = os.clock() + 5
            end
        end
        pcall(function()
            inventoryRemotes():Get('SetObservedChest'):SendToServer(nil)
        end)
        chestDepositBusy = false
        return true
    end

    ---------------------------------------------------------------------------
    -- Skybox mode banks the whitelist only and keeps its own backoff timers, exactly as it
    -- always has; Legit mode below banks everything. Only the chest plumbing is shared.
    ---------------------------------------------------------------------------
    local function depositToChest(folder, allowedItems)
        if chestDepositBusy then return false end
        allowedItems = allowedItems or Whitelist.ListEnabled
        local wanted = {}
        for _, item in store.inventory.inventory.items do
            local name = item.itemType or (item.tool and item.tool.Name)
            if name and item.tool and table.find(allowedItems, name) and (dropCooldowns[name] or 0) < os.clock() then
                table.insert(wanted, {Name = name, Tool = item.tool})
            end
        end
        if #wanted == 0 then return false end

        chestDepositBusy = true
        local deposited = false
        util.Chest.Observe(folder, function()
            for _, entry in wanted do
                if not AutoBank.Enabled then break end
                if util.Chest.Give(folder, entry.Tool) then
                    deposited = true
                else
                    -- Back off that one item instead of hammering it.
                    dropCooldowns[entry.Name] = os.clock() + 5
                end
            end
        end)
        chestDepositBusy = false
        return deposited
    end

    local function withdrawFromChest(folder, itemType)
        local contents = util.Chest.Entries(folder)
        if #contents == 0 then return end

        local requestBudget = 8
        util.Chest.Observe(folder, function()
            for _, entry in contents do
                if not AutoBank.Enabled or requestBudget <= 0 then break end
                if table.find(Whitelist.ListEnabled, entry.Name) and (not itemType or entry.Name == itemType) then
                    local amount = math.max(entry:GetAttribute('Amount') or 1, 1)
                    for _ = 1, amount do
                        if not AutoBank.Enabled or not entry.Parent or requestBudget <= 0 then break end
                        util.Chest.Take(folder, entry)
                        requestBudget -= 1
                    end
                end
            end
        end)
    end

    local function parseHotkey(box)
        if not box then return nil end
        local text = tostring(box.Value or ''):gsub('%s+', ''):upper()
        if text == '' then return nil end
        local ok, key = pcall(function() return Enum.KeyCode[text] end)
        return ok and key or nil
    end

    local function atOwnChest()
        if not entitylib.isAlive then return nil end
        local folder = ownPersonalFolder()
        if folder and atPersonalChest() then return folder end
        return nil
    end

    local currentHealthPercent = util.Health.Percent

	local function queueEmergencyDrop(item, token, bankPosition, bankCharacter)
		local name, tool = item and (item.itemType or (item.tool and item.tool.Name)), item and item.tool
		if not name or not tool or pendingDrops[tool] or (dropCooldowns[name] or 0) >= os.clock() then return false end
		pendingDrops[tool] = true
		local amount = item.amount
		
		
		
		task.spawn(function()
			local ok, drop = pcall(function()
				local handler = bedwars.Handler and bedwars.Handler:Get('DropItem')
				if not handler then error('DropItem remote unavailable') end
				return handler:Fire('CallServer', {item = tool, amount = amount})
			end)
			pendingDrops[tool] = nil
			if not ok or not drop or not drop.Parent then
				dropCooldowns[name] = os.clock() + 1
				return
			end
			if not table.find(droppedItems, drop) then
				table.insert(droppedItems, drop)
				drop:ClearAllChildren()
				drop.AncestryChanged:Once(function() untrackDrop(drop) end)
			end
			if typeof(bankPosition) == 'Vector3' and drop.Parent then
				pcall(function()
					drop.Velocity = Vector3.zero
					drop.CFrame = CFrame.new(bankPosition + Vector3.new(0, BANK_HEIGHT, 0))
				end)
			end
			if not AutoBank.Enabled or AutoBank.Generation ~= token or lplr.Character ~= bankCharacter then reclaim(drop) end
		end)
		return true
	end

    local function bankBeforeDeath()
        if beforeDeathDepositing or not AutoBank.Enabled or not BeforeDeath.Enabled then return end
        beforeDeathDepositing = true
		local token = AutoBank.Generation
		local bankCharacter = lplr.Character
		local character = entitylib.character
		local root = character and character.RootPart
		local bankPosition = root and root.Position
		
		
		
		
		local inventory = store.inventory and store.inventory.inventory
		for _, item in type(inventory) == 'table' and inventory.items or {} do
			local name = item.itemType or (item.tool and item.tool.Name)
			if name and table.find(BeforeDeathWhitelist.ListEnabled, name) then
				queueEmergencyDrop(item, token, bankPosition, bankCharacter)
			end
		end
		beforeDeathDepositing = false
    end

	local function disconnectDangerConnections()
		for _, connection in dangerConnections do pcall(function() connection:Disconnect() end) end
		table.clear(dangerConnections)
	end

	local function bindDangerCharacter(character)
		disconnectDangerConnections()
		dangerCharacter, dangerTriggered = character, false
		if not character then return end
		evaluateDanger = function()
			if not AutoBank.Enabled or not BeforeDeath.Enabled or lplr.Character ~= character then return end
			local percent = currentHealthPercent()
			if not percent then return end
			if percent <= HPThreshold.Value then
				if not dangerTriggered then dangerTriggered = true; bankBeforeDeath() end
			elseif percent >= math.min(100, HPThreshold.Value + 5) then
				dangerTriggered = false
			end
		end
		for _, attribute in {'Health', 'MaxHealth'} do
			table.insert(dangerConnections, character:GetAttributeChangedSignal(attribute):Connect(evaluateDanger))
		end
		local humanoid = character:FindFirstChildOfClass('Humanoid')
		if humanoid then
			table.insert(dangerConnections, humanoid.HealthChanged:Connect(evaluateDanger))
			table.insert(dangerConnections, humanoid:GetPropertyChangedSignal('MaxHealth'):Connect(evaluateDanger))
		end
		evaluateDanger()
	end

    
    
    
    local function withdrawAllFromChest(folder)
        local contents = folder:GetChildren()
        if #contents == 0 then return false end

        pcall(function()
            inventoryRemotes():Get('SetObservedChest'):SendToServer(folder)
        end)
        local requestBudget = 8
        local took = false
        for _, entry in contents do
            if not AutoBank.Enabled or requestBudget <= 0 then break end
            if entry:IsA('Accessory') then
                local amount = math.max(entry:GetAttribute('Amount') or 1, 1)
                for _ = 1, amount do
                    if not AutoBank.Enabled or not entry.Parent or requestBudget <= 0 then break end
                    pcall(function()
                        inventoryRemotes():Get('ChestGetItem'):CallServer(folder, entry)
                    end)
                    requestBudget -= 1
                    took = true
                end
            end
        end
        pcall(function()
            inventoryRemotes():Get('SetObservedChest'):SendToServer(nil)
        end)
        return took
    end

    
    
    
    
    local function lowHealthReached()
        if not OnlyWhenLow.Enabled then return true end
        local health = currentHealth()
        if not health then return true end
        return health <= (tonumber(LowHealth.Value) or LEGIT_DEFAULT_HP)
    end

    
    
    
    local function runLegitMode()
        if not util.Queue.Await(AutoBank) then return end
        local pendingRedeposit = false

        AutoBank:Clean(inputService.InputBegan:Connect(function(input)
            if inputService:GetFocusedTextBox() then return end
            local deposit, withdraw = parseHotkey(DepositKey), parseHotkey(WithdrawKey)
            if not deposit and not withdraw then return end
            if deposit and input.KeyCode == deposit then
                local folder = atOwnChest()
                if folder and not chestDepositBusy then
                    depositAllToChest(folder)
                end
            elseif withdraw and input.KeyCode == withdraw then
                local folder = atOwnChest()
                if folder then
                    withdrawAllFromChest(folder)
                end
            end
        end))

        repeat
            if entitylib.isAlive and store.matchState ~= 2 then
                local folder = ownPersonalFolder()
                if folder and atPersonalChest() then
                    if shopScreenOpen() then
                        
                        
                        if Withdraw.Enabled and withdrawAllFromChest(folder) then
                            pendingRedeposit = true
                        end
                    elseif pendingRedeposit or lowHealthReached() then
                        
                        
                        depositAllToChest(folder)
                        pendingRedeposit = false
                    end
                end
            end
            task.wait(0.1)
        until not AutoBank.Enabled
    end

    
    
    local function applyModeOptions()
        local legit = Mode.Value == 'Legit'
        for _, option in {ChestRange, Withdraw, OnlyWhenLow, LowHealth, DepositKey, WithdrawKey} do
            if option and option.Object then option.Object.Visible = legit end
        end
        for _, option in {Whitelist, DisplayResources, BeforeDeath} do
            if option and option.Object then option.Object.Visible = not legit end
        end
        if not legit then
            local enabled = BeforeDeath.Enabled
            if HPThreshold and HPThreshold.Object then HPThreshold.Object.Visible = enabled end
            if BeforeDeathWhitelist and BeforeDeathWhitelist.Object then BeforeDeathWhitelist.Object.Visible = enabled end
        elseif LowHealth and LowHealth.Object then
            LowHealth.Object.Visible = OnlyWhenLow.Enabled
        end
    end

    local function addDisplayEntry(itemType)
        local icon = Instance.new('ImageButton')
        icon.Name = itemType
        icon.Image = bedwars.getIcon({itemType = itemType}, true)
        icon.Size = UDim2.fromOffset(32, 32)
        icon.BackgroundTransparency = 1
        icon.LayoutOrder = #UI:GetChildren()
        icon.Parent = UI
        local amount = Instance.new('TextLabel')
        amount.Name = 'Amount'
        amount.Size = UDim2.fromScale(1, 1)
        amount.BackgroundTransparency = 1
        amount.Text = ''
        amount.TextColor3 = Color3.new(1, 1, 1)
        amount.TextSize = 16
        amount.TextStrokeTransparency = 0.3
        amount.Font = Enum.Font.Arial
        amount.Parent = icon
        displayEntries[itemType] = amount
        icon.Activated:Connect(function()
            
            
            for _, drop in table.clone(droppedItems) do
                if drop.Name == itemType then reclaim(drop) end
            end
        end)
    end

    AutoBank = vape.Categories.Inventory:CreateModule({
        Name = 'AutoBank',
        Function = function(callback)
            if callback then
                
                
                if Mode.Value == 'Legit' then
                    runLegitMode()
                    return
                end
                
                UI = Instance.new('Frame')
                UI.Size = UDim2.new(1, 0, 0, 32)
                UI.AnchorPoint = Vector2.new(0.5, 0)
                UI.Position = UDim2.new(0.5, 0, 0, -240)
                UI.BackgroundTransparency = 1
                UI.Visible = DisplayResources.Enabled
                UI.Parent = vape.gui
                AutoBank:Clean(UI)
                local layout = Instance.new('UIListLayout')
                layout.FillDirection = Enum.FillDirection.Horizontal
                layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
                layout.SortOrder = Enum.SortOrder.LayoutOrder
                layout.Parent = UI

                table.clear(displayEntries)
                for _, itemType in Whitelist.ListEnabled do
                    addDisplayEntry(itemType)
                end

                local near = false
                local base = CFrame.new(1e3, 1e5, 1e3)
				local rows = Random.new():NextInteger(1, 20000)
				local holdAccumulator = 0
				AutoBank:Clean(runService.Heartbeat:Connect(function(delta)
					holdAccumulator += delta
					if holdAccumulator < 0.05 then return end
					holdAccumulator = 0
					local totals = {}
					for index, drop in droppedItems do
						if drop and drop.Parent then
							totals[drop.Name] = (totals[drop.Name] or 0) + (drop:GetAttribute('Amount') or 0)
							drop.Velocity = Vector3.zero
							if entitylib.isAlive then
								drop.CFrame = near and entitylib.character.Head.CFrame
									or base + Vector3.new((index % rows) * 1200, 0, math.floor(index / rows) * 1200)
							end
						else
							untrackDrop(drop)
						end
                    end
                    for itemType, label in displayEntries do
                        label.Text = tostring(totals[itemType] or 0)
                    end
                end))

				AutoBank:Clean(disconnectDangerConnections)
				AutoBank:Clean(lplr.CharacterAdded:Connect(bindDangerCharacter))
				bindDangerCharacter(lplr.Character)

				AutoBank:Clean(inputService.InputBegan:Connect(function(input)
					if inputService:GetFocusedTextBox() then return end
					local deposit, withdraw = parseHotkey(DepositKey), parseHotkey(WithdrawKey)
					if not deposit and not withdraw then return end
					if deposit and input.KeyCode == deposit then
						local folder = atOwnChest()
						if folder and not chestDepositBusy then
							depositToChest(folder, Whitelist.ListEnabled)
						end
					elseif withdraw and input.KeyCode == withdraw then
						local folder = atOwnChest()
						if folder then
							withdrawFromChest(folder, nil)
						end
					end
				end))

                repeat
                    local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
                    local hotbarFrame = hotbar and hotbar:FindFirstChild('1')
                    hotbar = hotbarFrame and hotbarFrame:FindFirstChild('HotbarHealthbarContainer')
                    if hotbar then
                        UI.Position = UDim2.new(0.5, 0, 0, (hotbar.AbsolutePosition.Y + guiService:GetGuiInset().Y) - 60)
                    end

					if entitylib.isAlive and not atShop() then
						near = false
						local inventory = store.inventory and store.inventory.inventory
						for _, item in type(inventory) == 'table' and inventory.items or {} do
							local name = item.tool and item.tool.Name or item.itemType
							if name and item.tool and table.find(Whitelist.ListEnabled, name)
								and not pendingDrops[item.tool] and (dropCooldowns[name] or 0) < os.clock() then
								local token = AutoBank.Generation
								local bankCharacter = lplr.Character
								pendingDrops[item.tool] = true
								task.spawn(function()
									local ok, drop = pcall(function()
										return bedwars.Handler:Get('DropItem'):Fire('CallServer', {
											item = item.tool,
											amount = item.amount
										})
									end)
									pendingDrops[item.tool] = nil
									if not ok or not drop or not drop.Parent then
										dropCooldowns[name] = os.clock() + 5
									elseif not AutoBank.Enabled or AutoBank.Generation ~= token or lplr.Character ~= bankCharacter then
										reclaim(drop)
									elseif not table.find(droppedItems, drop) then
										table.insert(droppedItems, drop)
										drop:ClearAllChildren()
										drop.AncestryChanged:Once(function()
											untrackDrop(drop)
										end)
									end
								end)
							end
                        end
					elseif entitylib.isAlive then
						near = true
						for _, drop in droppedItems do
							if drop and drop.Parent then reclaim(drop) end
						end
					end
                    task.wait(0.1)
                until not AutoBank.Enabled
                return
            end

            if not callback then
                
                
                
                local deadline = tick() + 3
                while #droppedItems > 0 and tick() < deadline and entitylib.isAlive do
                    for _, drop in table.clone(droppedItems) do
                        reclaim(drop)
                    end
                    task.wait(0.1)
                end
                
                
                for _, drop in table.clone(droppedItems) do
                    if not drop or not drop.Parent then untrackDrop(drop) end
                end
                table.clear(pendingDrops)
                table.clear(pendingReclaims)
                table.clear(releasingDrops)
                table.clear(dropCooldowns)
                table.clear(chestCooldowns)
                table.clear(displayEntries)
                dangerTriggered, dangerCharacter, beforeDeathDepositing, chestDepositBusy = false, nil, false, false
                return
            end

        end,
        Tooltip = 'Stores resources somewhere safe: held above the map until a shop, or banked in your personal chest'
    })

    Mode = AutoBank:CreateDropdown({
        Name = 'Mode',
        List = {'Skybox', 'Legit'},
        Default = 'Skybox',
        Tooltip = 'Skybox - holds the items above the map until a shop\nLegit - banks everything into your personal chest and pulls it back out at a shop',
        Function = function()
            applyModeOptions()
            
            
            if AutoBank.Enabled then
                AutoBank:Toggle()
                AutoBank:Toggle()
            end
        end
    })
    
    
    
    local modeLoad = Mode.Load
    function Mode:Load(tab)
        if type(tab) == 'table' and tab.Value == 'Chest' then
            tab = {Value = 'Legit'}
        end
        return modeLoad(self, tab)
    end
    ChestRange = AutoBank:CreateSlider({
        Name = 'Chest range',
        Min = 1,
        Max = 30,
        Default = util.Chest.Range,
        Darker = true,
        Visible = false,
        Suffix = util.Studs,
        Tooltip = 'How close to your personal chest you have to be before anything is banked'
    })
    Withdraw = AutoBank:CreateToggle({
        Name = 'Withdraw at shop',
        Default = true,
        Darker = true,
        Visible = false,
        Tooltip = 'Empties the chest back into your inventory while a shop screen is open, so AutoBuy can spend what you banked. Everything is banked again once you leave the shop'
    })
    OnlyWhenLow = AutoBank:CreateToggle({
        Name = 'Only when low',
        Default = false,
        Darker = true,
        Visible = false,
        Function = function(enabled)
            if LowHealth and LowHealth.Object then LowHealth.Object.Visible = enabled end
        end,
        Tooltip = 'Only banks while your health is low, so you can keep fighting with your loot on you'
    })
    LowHealth = AutoBank:CreateSlider({
        Name = 'Low HP',
        Min = 1,
        Max = 99,
        Default = LEGIT_DEFAULT_HP,
        Darker = true,
        Visible = false,
        Tooltip = 'Flat health, not a percentage - 30 means 30 HP'
    })
    BeforeDeath = AutoBank:CreateToggle({
        Name = 'Before death',
        Function = function(enabled)
            dangerTriggered, dangerCharacter, beforeDeathDepositing = false, nil, false
            if HPThreshold and HPThreshold.Object then HPThreshold.Object.Visible = enabled end
            if BeforeDeathWhitelist and BeforeDeathWhitelist.Object then BeforeDeathWhitelist.Object.Visible = enabled end
			if enabled and AutoBank.Enabled then bindDangerCharacter(lplr.Character) end
        end,
        Tooltip = 'Drops selected inventory items somewhere safe once when your health becomes dangerous'
    })
    HPThreshold = AutoBank:CreateSlider({
        Name = 'HP Threshold',
        Min = 1,
        Max = 99,
        Default = 25,
        Suffix = '%',
        Darker = true,
        Visible = false,
        Tooltip = 'Triggers the before-death deposit at or below this percentage of maximum health'
    })
    BeforeDeathWhitelist = AutoBank:CreateTextList({
        Name = 'Before death whitelist',
        Default = {'emerald', 'diamond', 'iron'},
        Darker = true,
        Visible = false,
        Tooltip = 'Only these item types are deposited by Before death'
    })
    Whitelist = AutoBank:CreateTextList({
        Name = 'Whitelist',
        Default = {'emerald', 'diamond', 'iron'},
        Function = function()
            if AutoBank.Enabled then
                AutoBank:Toggle()
                AutoBank:Toggle()
            end
        end
    })
    DisplayResources = AutoBank:CreateToggle({
        Name = 'Display resources',
        Default = true,
        Function = function(callback)
            if AutoBank.Enabled and UI then
                UI.Visible = callback
            end
        end
    })
    DepositKey = AutoBank:CreateTextBox({
        Name = 'Deposit key',
        Placeholder = 'None',
        Tooltip = 'Press while stood at your personal chest to instantly bank everything you are carrying'
    })
    WithdrawKey = AutoBank:CreateTextBox({
        Name = 'Withdraw key',
        Placeholder = 'None',
        Tooltip = 'Press while stood at your personal chest to instantly pull everything back out'
    })

    applyModeOptions()
end)
