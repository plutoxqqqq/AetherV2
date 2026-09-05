run(function()
    local AutoHonor
    local Delay

    -- BedWars lets you hand out two honors, so that cap stays - but it is a cap PER MATCH.
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
        -- Re-entrancy guard: a final kill and the match ending can land in the same moment, and two
        -- overlapping passes used to spend both honors on the same player.
        if honoring or #Honored >= MAX_HONORS then return end
        honoring = true

        -- Candidates are collected by hand rather than sorting entitylib.List directly. That list
        -- also holds NPCs, monsters and drones, which have no .Player - and the old comparator
        -- indexed .Player on both sides without checking, so a single NPC anywhere in the game threw
        -- inside table.sort and took the entire honor down. That is the "sometimes it just doesn't
        -- work": nothing was broken about honoring, the list walk never got to it.
        local team = teamOf(lplr)
        local list = {}
        for _, ent in entitylib.List do
            local plr = ent.Player
            if plr and plr ~= lplr and plr.Parent and not table.find(Honored, plr) then
                table.insert(list, plr)
            end
        end

        -- Teammates first, keyed off a precomputed flag so the comparator is total and cannot
        -- error on a player whose team attribute disappears mid-sort.
        local mate = {}
        for _, plr in list do
            mate[plr] = team ~= nil and teamOf(plr) == team
        end
        table.sort(list, function(a, b)
            return mate[a] and not mate[b]
        end)

        -- The server refuses an honor sent in the same frame as the death that unlocked it, so
        -- settle first and wait out the delay BEFORE each attempt rather than after it.
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
                -- honor() waits internally, so it must not run ON the event thread: a yield inside a
                -- BindableEvent handler is what stopped the match-end honor from finishing.
                AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
                    task.spawn(honor)
                end))
                -- The two-honor cap is per match, so clear the record whenever a new one starts.
                -- Without this the module honored twice and then sat dead for the rest of the
                -- session, which looked exactly like it had stopped working.
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