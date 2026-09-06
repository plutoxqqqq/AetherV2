run(function()
    local StaffDetector
    local Mode
    local Clans
    local Party
    local Profile
    local Users
    local NotifyLeave
    local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
    local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
    local joined = {}
    
    
    local flagged = {}

    local function getRole(plr, id)
        local suc, res = pcall(function()
            return plr:GetRankInGroup(id)
        end)
        if not suc then
            notif('StaffDetector', res, 30, 'alert')
        end
        return suc and res or 0
    end

    local function staffFunction(plr, checktype)
        if not vape.Loaded then
            repeat task.wait() until vape.Loaded
        end

        notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
        whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
        flagged[plr.UserId] = {Name = plr.Name, Check = checktype}

        if Party.Enabled and not checktype:find('clan') then
            bedwars.PartyController:leaveParty()
        end

        if Mode.Value == 'Uninject' then
            task.spawn(function()
                vape:Uninject()
            end)
            game:GetService('StarterGui'):SetCore('SendNotification', {
                Title = 'StaffDetector',
                Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
                Duration = 60,
            })
        elseif Mode.Value == 'Requeue' then
            bedwars.QueueController:joinQueue(store.queueType)
        elseif Mode.Value == 'Profile' then
            vape.Save = function() end
            if vape.Profile ~= Profile.Value then
                vape:Load(true, Profile.Value)
            end
        elseif Mode.Value == 'AutoConfig' then
            local safe = {'AutoClicker', 'Reach', 'Sprint', 'HitFix', 'StaffDetector'}
            vape.Save = function() end
            for i, v in vape.Modules do
                if not (table.find(safe, i) or v.Category == 'Render') then
                    if v.Enabled then
                        v:Toggle()
                    end
                    v:SetBind('')
                end
            end
        end
    end

    local function checkFriends(list)
        for _, v in list do
            if joined[v] then
                return joined[v]
            end
        end
        return nil
    end

    local function checkJoin(plr, connection)
        if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') and not bedwars.Store:getState().Game.customMatch then
            connection:Disconnect()
            local tab, pages = {}, playersService:GetFriendsAsync(plr.UserId)
            for _ = 1, 200 do
                for _, v in pages:GetCurrentPage() do
                    table.insert(tab, v.Id)
                end
                if pages.IsFinished then break end
                pages:AdvanceToNextPageAsync()
            end

            local friend = checkFriends(tab)
            if not friend then
                staffFunction(plr, 'impossible_join')
                return true
            else
                notif('StaffDetector', string.format('Spectator %s joined from %s', plr.Name, friend), 20, 'warning')
            end
        end
    end

    local function playerAdded(plr)
        joined[plr.UserId] = plr.Name
        if plr == lplr then return end

        if table.find(blacklisteduserids, plr.UserId) or table.find(Users.ListEnabled, tostring(plr.UserId)) then
            staffFunction(plr, 'blacklisted_user')
        elseif getRole(plr, 5774246) >= 100 then
            staffFunction(plr, 'staff_role')
        else
            local connection
            connection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
                checkJoin(plr, connection)
            end)
            StaffDetector:Clean(connection)
            if checkJoin(plr, connection) then
                return
            end

            if not plr:GetAttribute('ClanTag') then
                plr:GetAttributeChangedSignal('ClanTag'):Wait()
            end

            if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded and Clans.Enabled then
                connection:Disconnect()
                staffFunction(plr, 'blacklisted_clan_'..plr:GetAttribute('ClanTag'):lower())
            end
        end
    end

    StaffDetector = vape.Categories.Utility:CreateModule({
        Name = 'StaffDetector',
        Function = function(callback)
            if callback then
                table.clear(flagged)
                StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
                StaffDetector:Clean(playersService.PlayerRemoving:Connect(function(plr)
                    local info = flagged[plr.UserId]
                    if info and NotifyLeave.Enabled then
                        notif('StaffDetector', 'Flagged staff left ('..info.Check..'): '..info.Name..' ('..plr.UserId..')', 20, 'warning')
                    end
                    flagged[plr.UserId] = nil
                end))
                for _, v in playersService:GetPlayers() do
                    task.spawn(playerAdded, v)
                end
            else
                table.clear(joined)
                table.clear(flagged)
            end
        end,
        Tooltip = 'Detects people with a staff rank ingame'
    })
    Mode = StaffDetector:CreateDropdown({
        Name = 'Mode',
        List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
        Function = function(val)
            if Profile.Object then
                Profile.Object.Visible = val == 'Profile'
            end
        end
    })
    Clans = StaffDetector:CreateToggle({
        Name = 'Blacklist clans',
        Default = true
    })
    Party = StaffDetector:CreateToggle({
        Name = 'Leave party'
    })
    NotifyLeave = StaffDetector:CreateToggle({
        Name = 'Notify on leave',
        Tooltip = 'Notifies you when a flagged staff member leaves your game',
        Default = true
    })
    Profile = StaffDetector:CreateTextBox({
        Name = 'Profile',
        Default = 'default',
        Darker = true,
        Visible = false
    })
    Users = StaffDetector:CreateTextList({
        Name = 'Users',
        Placeholder = 'player (userid)'
    })
end)
