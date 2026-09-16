run(function()
    
    
    
    
    local util = vape.Libraries.bedwarsutil

    local AutoSteal
    local Range, Delay, GUI, Skywars, Chests, Bank
    local Start = 0

    local inv = util.Chest.Remotes
    local getFolder = util.Chest.FolderOf

    
    
    
    local ownPersonalFolder = util.Chest.OwnFolder

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    local function isPersonalFolder(folder)
        if not folder then return false end
        local name = tostring(folder.Name):lower()
        return name:sub(-9) == '_personal' or name == 'personal'
    end

    local function isPersonal(chest)
        return util.Chest.IsPersonal(chest)
    end

    local function lootFolder(folder, items)
        if not folder or isPersonalFolder(folder) then return end
        local own = ownPersonalFolder()
        if own and folder == own then return end
        util.Chest.Observe(folder, function()
            for _, entry in util.Chest.Entries(folder) do
                task.spawn(function()
                    if util.Chest.Take(folder, entry) and items then
                        table.insert(items, entry.Name)
                    end
                end)
            end
        end)
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
                        if own and util.Chest.InRange(Range.Value, localPosition) then
                                    
                                    
                                    
                                    
                                    
                                    for _, name in table.clone(items) do
                                        local item = getItem(name)
                                        if item then
                                            task.spawn(function()
                                                if util.Chest.Give(own, item.tool) then
                                                    local index = table.find(items, name)
                                                    if index then
                                                        table.remove(items, index)
                                                    end
                                                end
                                            end)
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
        Suffix = util.Studs,
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
