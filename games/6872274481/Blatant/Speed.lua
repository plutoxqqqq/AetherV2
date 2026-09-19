run(function()
	local Speed
    local Mode
    local Value
    local WallCheck
    local AlwaysJump
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
        local stacks = type(getWindStacks) == 'function' and getWindStacks() or 0
        if ZephyrKit.Enabled and has({'wind_walker', 'zephyr'}) and stacks >= 1 then return ZephyrSpeed.Value end
        return fallback
    end
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true

    Speed = vape.Categories.Blatant:CreateModule({
        Name = 'Speed',
        Function = function(callback)
            frictionTable.Speed = callback or nil
            updateVelocity()
            pcall(function()
                debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
            end)

            if callback then
                Speed:Clean(runService.PreSimulation:Connect(function(dt)
                    bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
                    if entitylib.isAlive then
                        if not (Fly and Fly.Enabled) and not (LongJump and LongJump.Enabled) then
                            local movementSpeed = kitMovementSpeed(Value.Value)
                            bedwars.SprintController:setSpeed(Mode.Value == 'CFrame' and 20 or movementSpeed)
                            if Mode.Value == 'CFrame' then
                                local state = entitylib.character.Humanoid:GetState()
                                if state == Enum.HumanoidStateType.Climbing then return end

                                local root, velo = entitylib.character.RootPart, getSpeed()
                                local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
                                local destination = (moveDirection * math.max(movementSpeed - velo, 0) * dt)

                                if WallCheck.Enabled and destination.Magnitude > 1e-4 then
                                    rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                                    rayCheck.CollisionGroup = root.CollisionGroup

                                    local skin = (math.max(root.Size.X, root.Size.Z) / 2) + 0.4
                                    local half = root.Size.Y / 2

                                    -- Casts start one skin behind the root because a ray that begins
                                    -- inside a part ignores that part: a step taken with the body
                                    -- already flush against a face saw no wall at all and walked
                                    -- straight into it. Travel is then clamped along the face normal
                                    -- rather than along the ray, so an angled face stops the body
                                    -- exactly one skin clear of it instead of skin * (1 - cos(angle))
                                    -- late. The engine used to resolve that leftover overlap by
                                    -- pinning the character to the face, which is the "clip into the
                                    -- wall and slide down slowly" report while falling.
                                    for _ = 1, 3 do
                                        local step = destination.Magnitude
                                        if step <= 1e-4 then break end
                                        local direction = destination.Unit
                                        local back = root.Position - direction * skin

                                        -- The cast reaches well past the step: a face crossed at a shallow
                                        -- angle is far along the step even when it is right next to the
                                        -- normal, so a step-length ray never sees the wall it is about to
                                        -- walk into. skin * 6 covers incidence down to about 80 degrees.
                                        local distance, normal
                                        for _, height in {0, half * 0.8, -half * 0.8} do
                                            local ray = workspace:Raycast(back + Vector3.new(0, height, 0), direction * (step + skin * 6), rayCheck)
                                            -- The nearest face across the three heights is the one the body meets first.
                                            if ray and (not distance or ray.Distance < distance) then
                                                distance, normal = ray.Distance, ray.Normal
                                            end
                                        end
                                        if not distance then break end

                                        local approach = -direction:Dot(normal)
                                        if approach <= 1e-4 then break end

                                        -- Studs of the step heading into the face, next to the most it
                                        -- may cover before the body's skin touches it. The cast started
                                        -- one skin behind the body, so that skin is inside the distance it
                                        -- reports and the body's own radius comes off on top of it. A
                                        -- negative allowance means the body is already past that line, so
                                        -- the step pushes it back out instead of deeper in.
                                        local into = -destination:Dot(normal)
                                        local allowed = (distance - skin) * approach - skin
                                        if into <= allowed then break end
                                        destination += normal * (into - allowed)
                                    end
                                end

                                root.CFrame += destination
								
								
								
				local current = root.AssemblyLinearVelocity
				local requested = moveDirection * velo
				local currentHorizontal = Vector3.new(current.X, 0, current.Z)
				if currentHorizontal.Magnitude < requested.Magnitude then
									root.AssemblyLinearVelocity = Vector3.new(requested.X, current.Y, requested.Z)
								end
                                if AlwaysJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero then
                                    entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                end
                            end
                        end
                    end
                end))
            else
                bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Increases your movement with various methods'
    })
    Mode = Speed:CreateDropdown({
        Name = 'Method',
        List = {'Bedwars', 'CFrame'},
        Default = 'CFrame'
    })
    Value = Speed:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    KrystalKit = Speed:CreateToggle({Name = 'Krystal', Function = function(callback) if KrystalSpeed and KrystalSpeed.Object then KrystalSpeed.Object.Visible = callback end end})
    KrystalSpeed = Speed:CreateSlider({Name = 'Krystal Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
    SigridKit = Speed:CreateToggle({Name = 'Sigrid', Function = function(callback) if SigridSpeed and SigridSpeed.Object then SigridSpeed.Object.Visible = callback end end})
    SigridSpeed = Speed:CreateSlider({Name = 'Sigrid Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
    GrimKit = Speed:CreateToggle({Name = 'Grim Reaper', Function = function(callback) if GrimSpeed and GrimSpeed.Object then GrimSpeed.Object.Visible = callback end end})
    GrimSpeed = Speed:CreateSlider({Name = 'Grim Reaper Speed', Min = 1, Max = 80, Default = 37, Suffix = ' studs/s', Darker = true, Visible = false})
    ZephyrKit = Speed:CreateToggle({Name = 'Zephyr', Function = function(callback) if ZephyrSpeed and ZephyrSpeed.Object then ZephyrSpeed.Object.Visible = callback end end})
    ZephyrSpeed = Speed:CreateSlider({Name = 'Zephyr Speed', Min = 1, Max = 80, Default = 30, Suffix = ' studs/s', Darker = true, Visible = false})
    WallCheck = Speed:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    AlwaysJump = Speed:CreateToggle({
        Name = 'Always jump',
        Tooltip = 'Jumps continuously while you are moving, instead of only on the ledge'
    })
end)
