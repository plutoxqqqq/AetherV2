run(function()
    
    
    
    
    local AutoSteal
    local Range, Delay, GUI, Skywars, Chests, Bank
    local Start = 0

    local function inv()
        return bedwars.Client:GetNamespace('Inventory')
    end

    local function getFolder(chest)
        local fv = chest:FindFirstChild('ChestFolderValue')
        return fv and fv.Value or nil
    end

    
    
    
    local function ownPersonalFolder()
        local inventories = replicatedStorage:FindFirstChild('Inventories')
        return inventories and inventories:FindFirstChild(lplr.Name .. '_personal') or nil
    end

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    local function isPersonalFolder(folder)
        if not folder then return false end
        local name = tostring(folder.Name):lower()
        return name:sub(-9) == '_personal' or name == 'personal'
    end

    local function isPersonal(chest)
        if collectionService:HasTag(chest, 'personal-chest') then return true end
        if tostring(chest.Name):lower():find('personal') then return true end
        if chest:GetAttribute('PersonalChest') or chest:GetAttribute('IsPersonalChest') then return true end
        return isPersonalFolder(getFolder(chest))
    end

    local function lootFolder(folder, items)
        if not folder then return end
        
        
        if isPersonalFolder(folder) then return end
        local own = ownPersonalFolder()
        if own and folder == own then return end
        inv():Get('SetObservedChest'):SendToServer(folder)
        for _, v2 in folder:GetChildren() do
            if v2:IsA('Accessory') then
                task.spawn(function()
                    if inv():Get('ChestGetItem'):CallServer(folder, v2) and items then
                        table.insert(items, v2.Name)
                    end
                end)
            end
        end
        inv():Get('SetObservedChest'):SendToServer(nil)
    end

    AutoSteal = vape.Categories.Inventory:CreateModule({
        Name = 'AutoSteal',
        Function = function(call)
            if not call then return end
            repeat task.wait() until store.matchState ~= 0 or not AutoSteal.Enabled
            if not AutoSteal.Enabled then return end

            local crates = collection('team-crate', AutoSteal, function(tab, obj)
                task.delay(0, function()
                    if obj:GetAttribute('Team') ~= lplr:GetAttribute('Team') then
                        table.insert(tab, obj)
                    end
                end)
            end)
            local chests = collection('chest', AutoSteal)
            local items = {}

            repeat
                if entitylib.isAlive and store.matchState ~= 2 then
                    local localPosition = entitylib.character.RootPart.Position
                    if (tick() - Start) >= Delay.Value and (not GUI.Enabled or bedwars.AppController:isAppOpen('ChestApp')) then
                        
                        for _, v in crates do
                            if not isPersonal(v) and (localPosition - v.Position).Magnitude <= Range.Value then
                                lootFolder(getFolder(v), items)
                            end
                        end
                        
                        if Chests.Enabled and ((not Skywars.Enabled) or (store.queueType and store.queueType:find('skywars'))) then
                            for _, v in chests do
                                if not isPersonal(v) and (localPosition - v.Position).Magnitude <= Range.Value then
                                    lootFolder(getFolder(v), items)
                                end
                            end
                        end
                        
                        local own = Bank.Enabled and #items > 0 and ownPersonalFolder() or nil
                        if own then
                            for _, v in collectionService:GetTagged('personal-chest') do
                                if (localPosition - v.Position).Magnitude <= Range.Value then
                                    
                                    
                                    
                                    
                                    
                                    for _, name in table.clone(items) do
                                        local item = getItem(name)
                                        if item then
                                            task.spawn(function()
                                                if inv():Get('ChestGiveItem'):CallServer(own, item.tool) then
                                                    local index = table.find(items, name)
                                                    if index then
                                                        table.remove(items, index)
                                                    end
                                                end
                                            end)
                                        end
                                    end
                                    break
                                end
                            end
                        end
                        Start = tick()
                    end
                end
                task.wait(0.1)
            until not AutoSteal.Enabled
        end,
        Tooltip = 'Steals from enemy crates and nearby chests, never a personal one, and can auto-bank the loot'
    })

    Range = AutoSteal:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 18,
        Default = 18,
        Suffix = function(val) return val <= 1 and 'stud' or 'studs' end,
    })
    Delay = AutoSteal:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 1,
        Decimal = 100,
        Suffix = 'seconds',
        Default = 0,
    })
    Chests = AutoSteal:CreateToggle({Name = 'Nearby chests', Default = true, Tooltip = 'Also loot nearby non-personal chests (former ChestSteal)'})
    Skywars = AutoSteal:CreateToggle({Name = 'Only Skywars', Tooltip = 'Only loot nearby chests while in Skywars'})
    Bank = AutoSteal:CreateToggle({Name = 'Bank loot', Default = true, Tooltip = 'Deposit stolen loot into your personal chest'})
    GUI = AutoSteal:CreateToggle({Name = 'GUI Check'})
end)
