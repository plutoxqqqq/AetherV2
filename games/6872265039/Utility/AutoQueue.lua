run(function()
    ----------------------------------------------------------------------------------------------
    -- AutoQueue - the lobby half of AutoWin.
    --
    -- BedWars plays matches in a different place to this one, so games/6872274481.lua (and the
    -- AutoWin module inside it) is not loaded here at all, and the two places do not even share a
    -- config file. Being teleported back to the lobby at the end of a match therefore used to end
    -- an unattended run outright: nothing on this side knew a run was in progress, so nothing
    -- queued the next game.
    --
    -- AutoWin leaves a note on disk saying it is running and which queue it wants. This reads that
    -- note, and with Resume from AutoWin on it switches itself on off the back of it - which is
    -- what actually closes the loop and lets the script keep playing for hours without anyone at
    -- the keyboard.
    ----------------------------------------------------------------------------------------------
    local AutoQueue
    local Mode
    local Resume
    local Delay
    local Notify

    local STATE_FILE = 'aetherv2/profiles/autowin.json'

    local function readState()
        if not isfile or not isfile(STATE_FILE) then return nil end
        local ok, data = pcall(function()
            return httpService:JSONDecode(readfile(STATE_FILE))
        end)
        if ok and type(data) == 'table' then return data end
        return nil
    end

    local function queueList()
        local list = {'From AutoWin', 'Random'}
        pcall(function()
            local ids = {}
            for id, meta in bedwars.QueueMeta do
                if not meta.disabled and not meta.voiceChatOnly then
                    table.insert(ids, id)
                end
            end
            table.sort(ids)
            for _, id in ipairs(ids) do
                table.insert(list, id)
            end
        end)
        return list
    end

    local function randomMode()
        local modes = {}
        pcall(function()
            for id, meta in bedwars.QueueMeta do
                if not meta.disabled and not meta.voiceChatOnly and not meta.rankCategory then
                    table.insert(modes, id)
                end
            end
        end)
        if #modes == 0 then return nil end
        return modes[math.random(1, #modes)]
    end

    -- Which queue to join. 'From AutoWin' follows whatever the match side asked for, including the
    -- queue it was last actually playing, so the mode only has to be set in one place.
    local function resolveMode()
        local wanted = Mode.Value
        if wanted == 'From AutoWin' then
            local state = readState()
            wanted = state and state.queue or 'Random'
            if wanted == 'Current' then
                wanted = (state and state.fallback) or 'Random'
            end
        end
        if wanted == 'Random' or wanted == nil then
            return randomMode()
        end
        return wanted
    end

    -- BedWars only accepts a queue request from the party leader, and only when the party is not
    -- already queued or in a custom match. Firing it blind does nothing but produce errors, so all
    -- three are checked and the loop simply waits when any of them says no.
    local function canQueue()
        local ok, allowed = pcall(function()
            local state = bedwars.Store:getState()
            if state.Game and state.Game.customMatch then return false end
            if not state.Party or not state.Party.leader then return false end
            if state.Party.leader.userId ~= lplr.UserId then return false end
            return state.Party.queueState == 0
        end)
        return ok and allowed
    end

    AutoQueue = vape.Categories.Utility:CreateModule({
        Name = 'AutoQueue',
        Function = function(callback)
            if callback then
                AutoQueue:Clean(task.spawn(function()
                    -- Settle first. Landing in the lobby straight off a match teleport means the
                    -- party and queue state are still arriving, and a request sent into that is
                    -- simply dropped.
                    task.wait(Delay.Value)
                    while AutoQueue.Enabled do
                        if canQueue() then
                            local mode = resolveMode()
                            if mode then
                                if Notify.Enabled then
                                    notif('AutoQueue', 'Queueing for '..tostring(mode), 4)
                                end
                                pcall(function()
                                    bedwars.QueueController:joinQueue(mode)
                                end)
                                -- Give the request time to be accepted before asking again;
                                -- canQueue goes false the moment it is, so this only ever retries
                                -- a request that genuinely did not land.
                                task.wait(8)
                            else
                                task.wait(2)
                            end
                        else
                            task.wait(2)
                        end
                    end
                end))
            end
        end,
        Tooltip = 'Queues a match from the lobby on its own, which is what lets AutoWin keep playing'
    })
    Mode = AutoQueue:CreateDropdown({
        Name = 'Gamemode',
        List = queueList(),
        Tooltip = 'Which queue to join. From AutoWin follows the gamemode set on the match side'
    })
    Delay = AutoQueue:CreateSlider({
        Name = 'Queue delay',
        Min = 1,
        Max = 30,
        Default = 5,
        Suffix = ' seconds',
        Tooltip = 'How long to settle in the lobby before queueing, so the party state has arrived'
    })
    Resume = AutoQueue:CreateToggle({
        Name = 'Resume from AutoWin',
        Default = true,
        Tooltip = 'Turns AutoQueue on by itself when AutoWin was running as you left the match'
    })
    Notify = AutoQueue:CreateToggle({
        Name = 'Notifications',
        Default = true,
        Tooltip = 'Say which mode is being queued'
    })

    -- Pick the run back up. Deferred because the config load runs after modules are registered and
    -- would otherwise toggle this straight back off; a re-check of the note afterwards means the
    -- user's own saved state still wins if they had explicitly turned AutoQueue off.
    task.delay(6, function()
        if not Resume.Enabled or AutoQueue.Enabled then return end
        local state = readState()
        if state and state.enabled and state.resume then
            if Notify.Enabled then
                notif('AutoQueue', 'AutoWin was running - queueing the next match', 6)
            end
            AutoQueue:Toggle()
        end
    end)
end)
