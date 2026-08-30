run(function()
    local Value
    local VerticalValue
    local WallCheck
    local PopBalloons
    local TP
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local up, down, old = 0, 0
    local KrystalKit, KrystalSpeed
    local SigridKit, SigridSpeed
    local GrimKit, GrimSpeed
    local ZephyrKit, ZephyrSpeed

    local function kitMovementSpeed(fallback)
        if not entitylib.isAlive then return fallback end
        local equipped = store.equippedKit
        if equipped == nil or equipped == '' then equipped = lplr:GetAttribute('PlayingAsKit') or lplr:GetAttribute('PlayingAsKits') end
        local kit = string.lower(tostring(equipped or ''))
        local char = lplr.Character
        local function has(words)
            for _, word in words do if kit:find(word, 1, true) then return true end end
            return false
        end
        if KrystalKit.Enabled and has({'glacial_skater', 'ice_skater', 'glacier', 'krystal'}) then return KrystalSpeed.Value end
        local riding = lplr:GetAttribute('ElkKitMounted') or lplr:GetAttribute('SigridMounted')
            or (char and (char:GetAttribute('ElkKitMounted') or char:GetAttribute('SigridMounted') or char:FindFirstChild('ElkMount', true)))
        if SigridKit.Enabled and has({'elk_master', 'elk', 'rider', 'sigrid'}) and riding then return SigridSpeed.Value end
        local soul = char and (char:GetAttribute('GrimReaperChannel') or char:GetAttribute('SoulForm') or char:GetAttribute('GrimReaperGhost') or char:FindFirstChild('GrimReaperChannel', true))
        if GrimKit.Enabled and has({'grim_reaper', 'grim', 'soul'}) and soul then return GrimSpeed.Value end
        local stacks = tonumber(lplr:GetAttribute('WindWalkerStacks') or lplr:GetAttribute('WindWalkerStack') or lplr:GetAttribute('WindStacks')
            or (char and (char:GetAttribute('WindWalkerStacks') or char:GetAttribute('WindWalkerStack') or char:GetAttribute('WindStacks'))) or 0) or 0
        if ZephyrKit.Enabled and has({'wind_walker', 'zephyr', 'wind'}) and stacks >= 1 then return ZephyrSpeed.Value end
        return fallback
    end

    Fly = vape.Categories.Blatant:CreateModule({
        Name = 'Fly',
        Function = function(callback)
            frictionTable.Fly = callback or nil
            updateVelocity()
            if callback then
                up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
                bedwars.BalloonController.deflateBalloon = function() end
                local tpTick, tpToggle, oldy = tick(), true

                if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                    bedwars.BalloonController:inflateBalloon()
                end
                Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
                    if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                        bedwars.BalloonController:inflateBalloon()
                    end
                end))
                Fly:Clean(runService.PreSimulation:Connect(function(dt)
                    if entitylib.isAlive and isnetworkowner(entitylib.character.RootPart) then
                        local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
                        local mass = (0.9 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
                        local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
                        local velo = getSpeed()
                        local movementSpeed = kitMovementSpeed(Value.Value)
                        local destination = (moveDirection * math.max(movementSpeed - velo, 0) * dt)
                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
                        rayCheck.CollisionGroup = root.CollisionGroup

                        if WallCheck.Enabled then
                            local ray = workspace:Raycast(root.Position, destination, rayCheck)
                            if ray then
                                destination = ((ray.Position + ray.Normal) - root.Position)
                            end
                        end

                        if not flyAllowed then
                            if tpToggle then
                                local airleft = (tick() - entitylib.character.AirTime)
                                if airleft > 2 then
                                    if not oldy then
                                        local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
                                        if ray and TP.Enabled then
                                            tpToggle = false
                                            oldy = root.Position.Y
                                            tpTick = tick() + 0.11
                                            root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
                                        end
                                    end
                                end
                            else
                                if oldy then
                                    if tpTick < tick() then
                                        local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
                                        root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
                                        tpToggle = true
                                        oldy = nil
                                    else
                                        mass = 0
                                    end
                                end
                            end
                        end

                        root.CFrame += destination
                        root.AssemblyLinearVelocity = (moveDirection * math.max(velo, movementSpeed)) + Vector3.new(0, mass, 0)
                    end
                end))
                Fly:Clean(inputService.InputBegan:Connect(function(input)
                    if not inputService:GetFocusedTextBox() then
                        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                            up = 1
                        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                            down = -1
                        end
                    end
                end))
                Fly:Clean(inputService.InputEnded:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                        up = 0
                    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                        down = 0
                    end
                end))
                if inputService.TouchEnabled then
                    pcall(function()
                        local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
                        Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
                            up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
                        end))
                    end)
                end
            else
                bedwars.BalloonController.deflateBalloon = old
                if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
                    for _ = 1, 3 do
                        bedwars.BalloonController:deflateBalloon()
                    end
                end
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Makes you go zoom'
    })
    Value = Fly:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    KrystalKit = Fly:CreateToggle({Name = 'Krystal', Function = function(callback) if KrystalSpeed and KrystalSpeed.Object then KrystalSpeed.Object.Visible = callback end end})
    KrystalSpeed = Fly:CreateSlider({Name = 'Krystal Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
    SigridKit = Fly:CreateToggle({Name = 'Sigrid', Function = function(callback) if SigridSpeed and SigridSpeed.Object then SigridSpeed.Object.Visible = callback end end})
    SigridSpeed = Fly:CreateSlider({Name = 'Sigrid Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
    GrimKit = Fly:CreateToggle({Name = 'Grim Reaper', Function = function(callback) if GrimSpeed and GrimSpeed.Object then GrimSpeed.Object.Visible = callback end end})
    GrimSpeed = Fly:CreateSlider({Name = 'Grim Reaper Speed', Min = 1, Max = 80, Default = 37, Suffix = ' studs/s', Darker = true, Visible = false})
    ZephyrKit = Fly:CreateToggle({Name = 'Zephyr', Function = function(callback) if ZephyrSpeed and ZephyrSpeed.Object then ZephyrSpeed.Object.Visible = callback end end})
    ZephyrSpeed = Fly:CreateSlider({Name = 'Zephyr Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
    VerticalValue = Fly:CreateSlider({
        Name = 'Vertical Speed',
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    WallCheck = Fly:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    PopBalloons = Fly:CreateToggle({
        Name = 'Pop Balloons',
        Default = true
    })
    TP = Fly:CreateToggle({
        Name = 'TP Down',
        Default = true
    })
end)