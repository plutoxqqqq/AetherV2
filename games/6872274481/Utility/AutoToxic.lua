run(function()
    local AutoToxic
    local GG
    local Delay
    local TrollTriggers
    local trollCooldown = 0
    local Toggles, Lists, said, dead = {}, {}, {}

    
    
    
    
    local function doSend(text)
        if not text or text == '' then return end
        local wait = Delay and Delay.Value or 0
        local function push()
            if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(text)
            else
                replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, 'All')
            end
        end
        if wait > 0 then
            task.delay(wait, function() pcall(push) end)
        else
            push()
        end
    end

    local function sendMessage(name, obj, default)
        local tab = Lists[name].ListEnabled
        local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
        if not custommsg then return end
        if #tab > 1 and custommsg == said[name] then
            repeat
                task.wait()
                custommsg = tab[math.random(1, #tab)]
            until custommsg ~= said[name]
        end
        said[name] = custommsg

        custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
        doSend(custommsg)
    end

    AutoToxic = vape.Categories.Utility:CreateModule({
        Name = 'AutoToxic',
        Function = function(callback)
            if callback then
                AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
                    if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
                        sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
                    elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
                        local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
                        sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
                    end
                end))
                AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
                    if deathTable.finalKill then
                        local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
                        local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
                        if not killed or not killer then return end
                        if killed == lplr then
                            if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
                                dead = true
                                sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
                            end
                        elseif killer == lplr and Toggles.Kill.Enabled then
                            sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
                        end
                    end
                end))
                AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
                    if GG.Enabled then
                        doSend('gg')
                    end

                    local myTeam = bedwars.Store:getState().Game.myTeam
                    if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
                        if Toggles.Win.Enabled then
                            sendMessage('Win', nil, 'yall garbage')
                        end
                    end
                end))

                
                
                
                local function handleIncoming(speakerName, text, speakerUserId)
                    if not (Toggles.Troll and Toggles.Troll.Enabled) or not text or text == '' then return end
                    if speakerUserId and speakerUserId == lplr.UserId then return end
                    if speakerName and speakerName == lplr.Name then return end
                    if tick() < trollCooldown then return end
                    local lower = text:lower()
                    for _, phrase in TrollTriggers.ListEnabled do
                        if phrase ~= '' and lower:find(phrase:lower(), 1, true) then
                            trollCooldown = tick() + 6
                            task.spawn(sendMessage, 'Troll', speakerName, 'mad cause bad | <obj>')
                            break
                        end
                    end
                end

                if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                    AutoToxic:Clean(textChatService.MessageReceived:Connect(function(message)
                        local src = message.TextSource
                        handleIncoming(src and src.Name, message.Text, src and src.UserId)
                    end))
                else
                    AutoToxic:Clean(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent:Connect(function(data)
                        if type(data) == 'table' then
                            handleIncoming(data.FromSpeaker, data.Message, nil)
                        end
                    end))
                end
            end
        end,
        Tooltip = 'Says a message after a certain action'
    })
    GG = AutoToxic:CreateToggle({
        Name = 'AutoGG',
        Default = true
    })
    Delay = AutoToxic:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 10,
        Default = 0,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'How long to wait after the triggering action before sending, 0 for instant'
    })
    for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
        Toggles[v] = AutoToxic:CreateToggle({
            Name = v..' ',
            Function = function(callback)
                if Lists[v] then
                    Lists[v].Object.Visible = callback
                end
            end
        })
        Lists[v] = AutoToxic:CreateTextList({
            Name = v,
            Darker = true,
            Visible = false
        })
    end
    Toggles.Troll = AutoToxic:CreateToggle({
        Name = 'Troll ',
        Tooltip = 'Detects when someone calls you a hacker/cheater in chat and automatically replies',
        Function = function(callback)
            if TrollTriggers then TrollTriggers.Object.Visible = callback end
            if Lists.Troll then Lists.Troll.Object.Visible = callback end
        end
    })
    TrollTriggers = AutoToxic:CreateTextList({
        Name = 'Troll Triggers',
        Tooltip = 'Phrases said by others that trigger a reply (matched anywhere in their message)',
        Default = {'hacker', 'hacks', 'hacking', 'hax', 'cheater', 'cheating', 'cheat', 'exploiter', 'exploiting', 'aimbot'},
        Darker = true,
        Visible = false
    })
    Lists.Troll = AutoToxic:CreateTextList({
        Name = 'Troll Replies',
        Tooltip = 'Replies to send. <obj> is replaced with the accuser\'s name',
        Default = {'mad cause bad | <obj>', 'skill issue <obj>', 'cry about it <obj>', 'not my fault youre bad', 'imagine losing to a "hacker" lol'},
        Darker = true,
        Visible = false
    })
end)
