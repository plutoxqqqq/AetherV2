run(function()
    local AutoHonor
    local Delay

    
    local MAX_HONORS = 2
    local Honored = {}
    local honoring = false

    local function teamOf(plr)
        local ok, team = pcall(function()
            return plr:GetAttribute('Team')
        end)
        return ok and team or nil
    end

    local function honor()
        
        
        if honoring or #Honored >= MAX_HONORS then return end
        honoring = true

        
        
        
        
        
        local team = teamOf(lplr)
        local list = {}
        for _, ent in entitylib.List do
            local plr = ent.Player
            if plr and plr ~= lplr and plr.Parent and not table.find(Honored, plr) then
                table.insert(list, plr)
            end
        end

        
        
        local mate = {}
        for _, plr in list do
            mate[plr] = team ~= nil and teamOf(plr) == team
        end
        table.sort(list, function(a, b)
            return mate[a] and not mate[b]
        end)

        
        
        task.wait(0.2)
        for _, plr in list do
            if #Honored >= MAX_HONORS then break end
            if Delay.Value > 0 then
                task.wait(Delay.Value)
            end
            if plr.Parent and bedwars.HonorController then
                local sent = false
                for _ = 1, 3 do
                    sent = pcall(function()
                        bedwars.HonorController:honorPlayer(plr.UserId)
                    end)
                    if sent then break end
                    task.wait(0.15)
                end
                if sent then
                    table.insert(Honored, plr)
                end
            end
        end

        honoring = false
    end

    AutoHonor = vape.Categories.Utility:CreateModule({
        Name = 'AutoHonor',
        Function = function(callback)
            if callback then
                table.clear(Honored)
                honoring = false
                AutoHonor:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
                    if deathTable.finalKill and deathTable.entityInstance == lplr.Character and #bedwars.Store:getState().Party.members <= 0 and store.matchState ~= 2 then
                        task.spawn(honor)
                    end
                end))
                
                
                AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
                    task.spawn(honor)
                end))
                
                
                
                task.spawn(function()
                    local lastState = store.matchState
                    while AutoHonor.Enabled do
                        if store.matchState ~= lastState then
                            if store.matchState ~= 2 and lastState == 2 then
                                table.clear(Honored)
                            end
                            lastState = store.matchState
                        end
                        task.wait(1)
                    end
                end)
            end
        end,
        Tooltip = 'Honors two players when you are finally killed or the match ends'
    })

    Delay = AutoHonor:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Decimal = 100,
        Suffix = 'seconds',
        Default = 0.1,
        Tooltip = 'Extra wait before each honor. Raise it if the server is still refusing them'
    })
end)
