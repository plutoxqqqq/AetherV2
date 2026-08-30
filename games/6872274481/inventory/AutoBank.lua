run(function()
    local AutoBank
    local Whitelist
    local DisplayResources
    local Mode
    local ChestRange
    local Withdraw
    local BeforeDeath
    local HPThreshold
    local BeforeDeathWhitelist
    local UI

    -- Drops we made and are currently holding out of the world.
    local droppedItems = {}
    -- itemType -> when we may next try to drop it. A stack the server refuses would otherwise
    -- be re-dropped ten times a second for the rest of the match.
    local dropCooldowns = {}
    -- Tools with an in-flight DropItem request and drops with an in-flight pickup request.
    -- The main loop runs faster than either remote can respond, so these guards prevent the
    -- same stack being banked or restored more than once.
    local pendingDrops = {}
    local pendingReclaims = {}
    -- Drops being returned must no longer be held at BANK_ORIGIN. Without a separate release
    -- state, PreRender moved them back into the sky on the very next frame, racing the pickup
    -- remote and making retrieval depend on lucky timing.
    local releasingDrops = {}
    local displayEntries = {}
    -- A danger state is one trip below the configured health threshold.  It is deliberately
    -- separate from the normal banking loop: a low-health player can remain in danger for a
    -- while and must not re-send ChestGiveItem requests every update.
    local dangerTriggered = false
    local dangerCharacter
    local beforeDeathDepositing = false
    local chestDepositBusy = false
	local dangerConnections = {}
	local evaluateDanger

    -- Keep the stash inside the local character's simulation radius. Parking drops at a fixed
    -- Y=100000 eventually hands their network ownership back to the server; after that, changing
    -- CFrame only moves the client's copy and PickupItem rejects it as still being out of range.
    -- Following the player a few hundred studs overhead remains unreachable while preserving the
    -- ownership needed to bring the server-authoritative drop back down later.
    local BANK_HEIGHT = 120
    local BANK_SPACING = 4
    local BANK_COLUMNS = 8

    local function untrackDrop(drop)
        releasingDrops[drop] = nil
        pendingReclaims[drop] = nil
        local index = table.find(droppedItems, drop)
        if index then
            table.remove(droppedItems, index)
        end
    end

    -- Bring one drop back to the head and ask for it. PickupItem only transfers one item from a
    -- stacked drop per request, so keep requesting until the server removes the emptied drop.
    local function reclaim(drop)
        if not drop or not drop.Parent then
            untrackDrop(drop)
            return
        end
        if not entitylib.isAlive then return end

        releasingDrops[drop] = true
        -- Keep moving the drop to the player even while a previous pickup request is pending.
        -- This matters during disable cleanup, when the PreRender skybox holder is disconnected.
        drop.Velocity = Vector3.zero
        drop.CFrame = entitylib.character.Head.CFrame
        if pendingReclaims[drop] then return end
        pendingReclaims[drop] = true

		local ok = pcall(function()
			-- Use the same stable handler path as cv.  The generated Client remote
			-- changes shape between BedWars builds, which made reclaim silently stop.
			bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {itemDrop = drop}):andThen(function(success)
                pendingReclaims[drop] = nil
                if not drop.Parent then
                    untrackDrop(drop)
                elseif AutoBank.Enabled then
                    -- A false response can simply mean the server has not observed the move
                    -- from the sky yet. Keep the drop at the player and retry; stacked drops
                    -- also require more than one successful pickup request.
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

    -- True while standing at a shop NPC, which is the cue to hand the stash back.
    local function atShop()
        if not entitylib.isAlive then return false end
        local opened = false
        pcall(function()
            opened = bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')
        end)
        if opened then return true end
        local position = entitylib.character.RootPart.Position
        for _, npc in store.shop do
            local root = npc.RootPart
            if root and root.Parent and (root.Position - position).Magnitude <= 30 then
                return true
            end
        end
        return false
    end

    ------------------------------------------------------------------------------------------
    -- Chest mode
    ------------------------------------------------------------------------------------------

    local function inventoryRemotes()
        return bedwars.Client:GetNamespace('Inventory')
    end

    -- The folder our banked items actually live in. This is always the deposit target, whichever
    -- world object we happen to be stood at - so being next to somebody else's chest can never
    -- put our resources into theirs.
    local function ownPersonalFolder()
        local inventories = replicatedStorage:FindFirstChild('Inventories')
        return inventories and inventories:FindFirstChild(lplr.Name .. '_personal') or nil
    end

    local function chestPart(chest)
        return chest:IsA('Model') and chest.PrimaryPart or (chest:IsA('BasePart') and chest) or nil
    end

    -- Are we close enough to a personal chest for a deposit to look like one? The chest is only
    -- the proximity gate here, not the destination, which is what keeps this honest: no remote
    -- goes out until we are genuinely stood at one, exactly as a player has to be.
    local function atPersonalChest()
        if not entitylib.isAlive then return false end
        local opened = false
        pcall(function()
            opened = bedwars.AppController:isAppOpen('ChestApp')
        end)
        if opened then return true end
        local position = entitylib.character.RootPart.Position
        for _, chest in collectionService:GetTagged('personal-chest') do
            local part = chestPart(chest)
            if part and part.Parent and (part.Position - position).Magnitude <= ChestRange.Value then
                return true
            end
        end
        return false
    end

    -- What is sitting in the chest, by item type, for the hotbar display.
    local function chestTotals(folder)
        local totals = {}
        if not folder then return totals end
        for _, entry in folder:GetChildren() do
            totals[entry.Name] = (totals[entry.Name] or 0) + (entry:GetAttribute('Amount') or 1)
        end
        return totals
    end

    -- Put the whitelisted stacks in. SetObservedChest is what the client sends when the chest UI
    -- opens and what the server checks the deposit against, so it brackets the deposits rather
    -- than being sent per item.
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
        pcall(function()
            inventoryRemotes():Get('SetObservedChest'):SendToServer(folder)
        end)
        for _, entry in wanted do
            if not AutoBank.Enabled then break end
            local ok, given = pcall(function()
                return inventoryRemotes():Get('ChestGiveItem'):CallServer(folder, entry.Tool)
            end)
            if not ok or not given then
                -- Refused - a full chest, or a stack the server will not take. Back off rather
                -- than asking again ten times a second for the rest of the match.
                dropCooldowns[entry.Name] = os.clock() + 5
            end
        end
        pcall(function()
            inventoryRemotes():Get('SetObservedChest'):SendToServer(nil)
        end)
        chestDepositBusy = false
        return true
    end

    local function currentHealthPercent()
        local character = lplr.Character
        if not character then return nil end
        -- BedWars keeps the authoritative health values as character attributes. Fall back to
        -- Humanoid values for transitions while those attributes are being recreated on respawn.
        local health = character:GetAttribute('Health')
        local maximum = character:GetAttribute('MaxHealth')
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if type(health) ~= 'number' then health = humanoid and humanoid.Health end
        if type(maximum) ~= 'number' or maximum <= 0 then maximum = humanoid and humanoid.MaxHealth end
        if type(health) ~= 'number' or type(maximum) ~= 'number' or maximum <= 0 then return nil end
        return math.clamp((health / maximum) * 100, 0, 100)
    end

	local function queueEmergencyDrop(item, token, bankPosition, bankCharacter)
		local name, tool = item and (item.itemType or (item.tool and item.tool.Name)), item and item.tool
		if not name or not tool or pendingDrops[tool] or (dropCooldowns[name] or 0) >= os.clock() then return false end
		pendingDrops[tool] = true
		local amount = item.amount
		-- Do not task.cancel a coroutine blocked inside the remote call: the server may already
		-- have dropped the stack. The generation check owns the late reply and immediately
		-- reclaims it after a disable/respawn instead of abandoning it in the world.
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
		local deposited = false
		if Mode.Value == 'Chest' and not chestDepositBusy then
			local folder = entitylib.isAlive and ownPersonalFolder() or nil
			if folder and atPersonalChest() then
				deposited = depositToChest(folder, BeforeDeathWhitelist.ListEnabled)
			end
		end
		-- A lethal hit does not leave time to walk to a chest. If the legit chest path is not
		-- available, immediately use the module's existing drop-and-hold bank for the selected
		-- stacks. Every request is guarded by the current module generation so late replies cannot
		-- re-apply state after a toggle or respawn.
		if not deposited then
			local inventory = store.inventory and store.inventory.inventory
			for _, item in type(inventory) == 'table' and inventory.items or {} do
				local name = item.itemType or (item.tool and item.tool.Name)
				if name and table.find(BeforeDeathWhitelist.ListEnabled, name) then
					queueEmergencyDrop(item, token, bankPosition, bankCharacter)
				end
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

    -- Take matching stacks back out. ChestGetItem transfers one item per call rather than the
    -- Accessory's entire Amount, so issue one request for every item that was counted.
    local function withdrawFromChest(folder, itemType)
        local contents = folder:GetChildren()
        if #contents == 0 then return end

        pcall(function()
            inventoryRemotes():Get('SetObservedChest'):SendToServer(folder)
        end)
        local requestBudget = 8
        for _, entry in contents do
            if not AutoBank.Enabled then break end
            if entry:IsA('Accessory') and table.find(Whitelist.ListEnabled, entry.Name)
                and (not itemType or entry.Name == itemType) then
                local amount = math.max(entry:GetAttribute('Amount') or 1, 1)
                for _ = 1, amount do
                    if not AutoBank.Enabled or not entry.Parent or requestBudget <= 0 then break end
                    pcall(function()
                        inventoryRemotes():Get('ChestGetItem'):CallServer(folder, entry)
                    end)
                    requestBudget -= 1
                end
            end
            if requestBudget <= 0 then break end
        end
        pcall(function()
            inventoryRemotes():Get('SetObservedChest'):SendToServer(nil)
        end)
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
            -- cv storage is always a held item drop, so a resource icon returns
            -- that matching drop directly instead of branching into Chest mode.
            for _, drop in table.clone(droppedItems) do
                if drop.Name == itemType then reclaim(drop) end
            end
        end)
    end

    AutoBank = vape.Categories.Inventory:CreateModule({
        Name = 'AutoBank',
        Function = function(callback)
            if callback then
                -- cv's AutoBank loop.  Keep the current display helper and the
                -- Before death hook, but use cv's direct drop/hold/reclaim flow
                -- rather than the alternate chest/banking implementation below.
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
                -- Give everything back rather than leaving it stranded in the sky. Bounded:
                -- drain what we can and stop, instead of spinning until the module is switched
                -- back on (which is what the reference build did, and never returned).
                local deadline = tick() + 3
                while #droppedItems > 0 and tick() < deadline and entitylib.isAlive do
                    for _, drop in table.clone(droppedItems) do
                        reclaim(drop)
                    end
                    task.wait(0.1)
                end
                -- Never forget a live drop that the server has not returned yet. If cleanup
                -- times out (for example while respawning), the next enable can restore it.
                for _, drop in table.clone(droppedItems) do
                    if not drop or not drop.Parent then untrackDrop(drop) end
                end
                table.clear(pendingDrops)
                table.clear(pendingReclaims)
                table.clear(releasingDrops)
                table.clear(dropCooldowns)
                table.clear(displayEntries)
                dangerTriggered, dangerCharacter, beforeDeathDepositing, chestDepositBusy = false, nil, false, false
                return
            end

        end,
        Tooltip = 'Stores resources somewhere safe, in your personal chest or held above the map until a shop'
    })

    Mode = AutoBank:CreateDropdown({
        Name = 'Mode',
        List = {'Skybox', 'Chest'},
        Default = 'Skybox',
        Visible = false,
        Tooltip = 'Skybox - holds the drops above the map until a shop\nChest - walks up and banks them like you would',
        Function = function()
            -- Reload rather than switching under the running loop: leaving Skybox has to hand
            -- the sky stash back first, which the disable path already does properly.
            if AutoBank.Enabled then
                AutoBank:Toggle()
                AutoBank:Toggle()
            end
            pcall(function()
                ChestRange.Object.Visible = Mode.Value == 'Chest'
                Withdraw.Object.Visible = Mode.Value == 'Chest'
            end)
        end
    })
    ChestRange = AutoBank:CreateSlider({
        Name = 'Chest range',
        Min = 1,
        Max = 30,
        Default = 20,
        Darker = true,
        Visible = false,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end,
        Tooltip = 'How close to your personal chest you have to be before anything is banked'
    })
    Withdraw = AutoBank:CreateToggle({
        Name = 'Withdraw at shop',
        Default = true,
        Darker = true,
        Visible = false,
        Tooltip = 'Empties the chest back into your inventory at a shop, so AutoBuy can spend what you banked'
    })
    BeforeDeath = AutoBank:CreateToggle({
        Name = 'Before death',
        Function = function(enabled)
            dangerTriggered, dangerCharacter, beforeDeathDepositing = false, nil, false
            if HPThreshold and HPThreshold.Object then HPThreshold.Object.Visible = enabled end
            if BeforeDeathWhitelist and BeforeDeathWhitelist.Object then BeforeDeathWhitelist.Object.Visible = enabled end
			if enabled and AutoBank.Enabled then bindDangerCharacter(lplr.Character) end
        end,
        Tooltip = 'Banks selected inventory items at your personal chest once when your health becomes dangerous'
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
end)