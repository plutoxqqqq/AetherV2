run(function()
    -- Combined AutoSteal + ChestSteal: loots enemy team crates AND nearby chests, and can
    -- bank the loot into your personal chest. Crucially it never loots a personal chest,
    -- which is what caused it to instantly steal back whatever you (or AutoBank) had just
    -- deposited.
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

    -- Our own personal chest's inventory folder, when it can be resolved. Banking needs the real
    -- folder, and it is one of the tests below - but only one of them, because it is exactly the
    -- test that fails on the builds where this went wrong.
    local function ownPersonalFolder()
        local inventories = replicatedStorage:FindFirstChild('Inventories')
        return inventories and inventories:FindFirstChild(lplr.Name .. '_personal') or nil
    end

    -- Is this world object a personal chest - anybody's, not only ours?
    --
    -- The tag and name tests are not enough on their own, and that is the bug: what a personal
    -- chest is actually LOOTED through is its ChestFolderValue, and a base can expose that same
    -- folder through an object carrying only the generic 'chest' tag, or a renamed model. When
    -- that happened the loop pulled banked loot straight back out, so with 'Bank loot' on every
    -- deposit was immediately withdrawn and nothing ever stayed in the chest.
    --
    -- The decisive test is therefore the folder's own name. Personal inventories are named
    -- `<owner>_personal`, whoever the owner is spelled as - the player's name on some builds, the
    -- user id on others - so matching the `_personal` suffix catches ours no matter how the owner
    -- part is written. Comparing against ownPersonalFolder() alone did not: on a build that names
    -- the folder by user id, or where ReplicatedStorage.Inventories is not populated yet, that
    -- comparison silently found nothing and the chest was looted.
    --
    -- Matching every owner rather than only ours is deliberate. A personal chest is somebody's
    -- bank, the server does not let it be robbed anyway, and asking is a wasted round trip that
    -- draws attention for nothing.
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
        -- Last line of defence: never pull items out of a personal inventory, whichever caller
        -- got here and whatever the world object it came from looked like.
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
                        -- 1) Enemy team crates.
                        for _, v in crates do
                            if not isPersonal(v) and (localPosition - v.Position).Magnitude <= Range.Value then
                                lootFolder(getFolder(v), items)
                            end
                        end
                        -- 2) Nearby generic chests (former ChestSteal), never a personal chest.
                        if Chests.Enabled and ((not Skywars.Enabled) or (store.queueType and store.queueType:find('skywars'))) then
                            for _, v in chests do
                                if not isPersonal(v) and (localPosition - v.Position).Magnitude <= Range.Value then
                                    lootFolder(getFolder(v), items)
                                end
                            end
                        end
                        -- 3) Bank the stolen loot into our personal chest.
                        local own = Bank.Enabled and #items > 0 and ownPersonalFolder() or nil
                        if own then
                            for _, v in collectionService:GetTagged('personal-chest') do
                                if (localPosition - v.Position).Magnitude <= Range.Value then
                                    -- Snapshot the names first. Each deposit removes from `items`
                                    -- out of an async callback, and mutating the very table the
                                    -- loop is walking skipped entries; table.find returning nil
                                    -- also made table.remove drop the LAST item rather than the
                                    -- deposited one, which lost track of loot still in the bag.
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