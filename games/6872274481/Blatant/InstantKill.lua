run(function()
    local InstantKill
    local Mode
    local Range
    local Place

    local function getTurret(localPosition)
        for _, v in store.blocks do
            if v.Name == 'camera_turret' and v:GetAttribute('PlacedByUserId') == lplr.UserId and (localPosition - v.Position).Magnitude <= 30 then
                return v
            end
        end
        return nil
    end

    local function getPlacedPosition(pos)
        for _, v in {Vector3.new(3, 0, 0), Vector3.new(0, 0, 3)} do
            for i = 1, 10 do
                local ray = workspace:Blockcast(CFrame.new(pos + (v * i)), Vector3.new(3, 3, 3), Vector3.new(0, -30, 0), store.airRay)
                if ray and not getPlacedBlock(ray.Position) then
                    return roundPos(ray.Position)
                end
            end
        end
        return
    end

    InstantKill = vape.Categories.Blatant:CreateModule({
        Name = 'InstantKill',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or not InstantKill.Enabled
                if not InstantKill.Enabled then return end
                if store.equippedKit ~= 'vulcan' then
                    notif('InstantKill', 'You need vulcan equipped for this!', 8, 'warning')
                    return
                end

                local delay, pickups = 0, {}
                repeat
                    if entitylib.isAlive and tick() > delay then
                        local localPosition = entitylib.character.RootPart.Position
                        local ent = entitylib.EntityPosition({
                            Origin = localPosition,
                            Range = Range.Value,
                            Part = 'RootPart',
                            Players = true,
                            Wallcheck = true,
                            Sort = sortmethods.Health,
                        })
                        if ent then
                            local turret = getTurret(localPosition)
                            local tablet = getItem('tablet')
                            if not turret and Place.Enabled then
                                local pos = getPlacedPosition(localPosition)
                                local item = getItem('camera_turret')
                                if pos and item then
                                    bedwars.placeBlock(pos, 'camera_turret', false)
                                    turret = getPlacedPosition(pos)
                                    if turret then
                                        table.insert(pickups, turret)
                                    end
                                end
                            end
                            if turret and tablet then
                                switchItem(tablet.tool)
                                for i = 1, 12 do
                                    task.spawn(function()
                                        bedwars.Client:Get('VulcanArtilleryMark'):CallServer(ent.Player)
                                    end)
                                end
                                delay = tick() + 2
                            end
                        end
                    end
                    if Mode.Value == 'On bind' then
                        if #pickups > 0 then
                            task.wait(0.1)
                            for _, v in pickups do

                            end
                        end
                        InstantKill:Toggle()
                        break
                    end
                    task.wait(0.1)
                until not InstantKill.Enabled
            end
        end,
        Tooltip = 'Automatically uses turret to instant kill targets'
    })

    Mode = InstantKill:CreateDropdown({
        Name = 'Mode',
        List = {'Toggle', 'On bind'},
        Default = 'Toggle'
    })
    Range = InstantKill:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 100,
        Default = 50,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end
    })
    Place = InstantKill:CreateToggle({
        Name = 'Auto place',
        Tooltip = 'Automatically places turrets if can\'t find any on ground',
        Default = true
    })
end)
