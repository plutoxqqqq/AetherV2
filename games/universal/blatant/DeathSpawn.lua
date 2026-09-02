run(function()
    local DeathSpawn
    local Target
    local Waypoint
    local GlideSpeed
    local HeightOffset
    local pendingPosition
    local pendingRotation
    local waitingForRespawn = false
    local deathConnection
    local characterConnection
    local generation = 0

    local function getRoot(character)
        return character and (character:FindFirstChild('HumanoidRootPart') or character:WaitForChild('HumanoidRootPart', 5))
    end

    local function getHumanoid(character)
        return character and (character:FindFirstChildOfClass('Humanoid') or character:WaitForChild('Humanoid', 5))
    end

    local function parseWaypoint(value)
        local coords = value and value:match('^%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)')
        if not coords then return nil end
        local x, y, z = value:match('^%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)')
        return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
    end

    local function getTargetPosition()
        if Target.Value == 'Mouse' then
            local mouse = lplr:GetMouse()
            return mouse and mouse.Hit and mouse.Hit.Position or nil
        end
        return parseWaypoint(Waypoint.Value)
    end

    local function clearConnections()
        if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
        if characterConnection then characterConnection:Disconnect(); characterConnection = nil end
    end

    local function glideTo(position, rotation, myGeneration)
        local start = os.clock()
        local root
        local connection

        connection = runService.Heartbeat:Connect(function()
            if myGeneration ~= generation or not DeathSpawn.Enabled then
                connection:Disconnect()
                return
            end

            root = entitylib.isAlive and entitylib.character.RootPart or getRoot(lplr.Character)
            if not root then return end

            local target = position + Vector3.new(0, HeightOffset.Value, 0)
            local delta = target - root.Position
            local distance = delta.Magnitude

            if distance <= 2.5 then
                root.CFrame = CFrame.new(target) * (rotation or CFrame.identity)
                root.AssemblyLinearVelocity = Vector3.zero
                connection:Disconnect()
                waitingForRespawn = false
                if DeathSpawn.Enabled then DeathSpawn:Toggle() end
                return
            end

            local direction = delta.Unit
            local speed = math.max(GlideSpeed.Value, 1)
            root.AssemblyLinearVelocity = direction * math.min(speed, math.max(distance * 60, speed))

            -- Give the newly spawned character an immediate first-frame displacement.
            if os.clock() - start < 0.05 then
                root.CFrame += direction * math.min(distance, speed / 60)
            end
        end)
        DeathSpawn:Clean(connection)
    end

    local function respawnAt(position, rotation, myGeneration)
        waitingForRespawn = true

        characterConnection = lplr.CharacterAdded:Connect(function(character)
            if myGeneration ~= generation or not DeathSpawn.Enabled then return end
            task.defer(function()
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                local root = getRoot(character)
                local humanoid = getHumanoid(character)
                if not root or not humanoid then return end

                -- Spawn directly at the saved position, then begin the fast glide immediately.
                root.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
                root.AssemblyLinearVelocity = Vector3.zero
                waitingForRespawn = false
                glideTo(position, rotation, myGeneration)
            end)
        end)
        DeathSpawn:Clean(characterConnection)

        local character = lplr.Character
        if character then
            local humanoid = getHumanoid(character)
            if humanoid and humanoid.Health > 0 then
                humanoid.Health = 0
            else
                pcall(function() character:BreakJoints() end)
            end
        end
    end

    local function setupRespawnMode(myGeneration)
        local function hook(character)
            local humanoid = getHumanoid(character)
            local root = getRoot(character)
            if not humanoid or not root then return end

            if deathConnection then deathConnection:Disconnect() end
            deathConnection = humanoid.Died:Connect(function()
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                local deathPosition = root.Position
                local rotation = root.CFrame - root.Position
                pendingPosition = deathPosition
                pendingRotation = rotation

                task.defer(function()
                    if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                    respawnAt(deathPosition, rotation, myGeneration)
                end)
            end)
            DeathSpawn:Clean(deathConnection)
        end

        if lplr.Character then hook(lplr.Character) end
        DeathSpawn:Clean(lplr.CharacterAdded:Connect(function(character)
            if myGeneration ~= generation or not DeathSpawn.Enabled then return end
            hook(character)
        end))
    end

    DeathSpawn = vape.Categories.Blatant:CreateModule({
        Name = 'DeathSpawn',
        Function = function(callback)
            generation += 1
            local myGeneration = generation
            clearConnections()

            if not callback then
                waitingForRespawn = false
                pendingPosition = nil
                pendingRotation = nil
                return
            end

            if Target.Value == 'Waypoint' then
                pendingPosition = parseWaypoint(Waypoint.Value)
                if not pendingPosition then
                    notif('DeathSpawn', 'Invalid waypoint. Use x, y, z.', 4, 'warning')
                    task.defer(function() if DeathSpawn.Enabled then DeathSpawn:Toggle() end end)
                    return
                end
            else
                pendingPosition = getTargetPosition()
                if not pendingPosition then
                    notif('DeathSpawn', 'No mouse position found.', 4, 'warning')
                    task.defer(function() if DeathSpawn.Enabled then DeathSpawn:Toggle() end end)
                    return
                end
            end

            local root = entitylib.isAlive and entitylib.character.RootPart
            pendingRotation = root and (root.CFrame - root.Position) or CFrame.identity

            if Target.Value == 'Mouse' then
                -- TP mode: capture the destination before killing the current character.
                respawnAt(pendingPosition, pendingRotation, myGeneration)
            else
                respawnAt(pendingPosition, pendingRotation, myGeneration)
            end
        end,
        Tooltip = 'Respawns your character and returns to a saved mouse or waypoint position.'
    })

    Target = DeathSpawn:CreateDropdown({
        Name = 'Target',
        List = {'Mouse', 'Waypoint'},
        Default = 'Mouse'
    })

    Waypoint = DeathSpawn:CreateTextBox({
        Name = 'Waypoint',
        Placeholder = 'x, y, z',
        Function = function() end
    })

    GlideSpeed = DeathSpawn:CreateSlider({
        Name = 'Glide speed',
        Min = 50,
        Max = 1000,
        Default = 500,
        Suffix = ' studs/s'
    })

    HeightOffset = DeathSpawn:CreateSlider({
        Name = 'Height offset',
        Min = -5,
        Max = 10,
        Default = 0,
        Decimal = 10,
        Suffix = ' studs'
    })

    setupRespawnMode = nil

    -- Respawn mode is always armed while the module is enabled: every subsequent death
    -- is captured and the new character is returned to the recorded death position.
    local originalFunction = DeathSpawn.Function
    DeathSpawn.Function = function(callback)
        if not callback then
            generation += 1
            clearConnections()
            waitingForRespawn = false
            pendingPosition = nil
            pendingRotation = nil
            return
        end

        generation += 1
        local myGeneration = generation
        clearConnections()

        if Target.Value == 'Waypoint' then
            pendingPosition = parseWaypoint(Waypoint.Value)
            if not pendingPosition then
                notif('DeathSpawn', 'Invalid waypoint. Use x, y, z.', 4, 'warning')
                task.defer(function() if DeathSpawn.Enabled then DeathSpawn:Toggle() end end)
                return
            end
        else
            pendingPosition = getTargetPosition()
            if not pendingPosition then
                notif('DeathSpawn', 'No mouse position found.', 4, 'warning')
                task.defer(function() if DeathSpawn.Enabled then DeathSpawn:Toggle() end end)
                return
            end
        end

        local root = entitylib.isAlive and entitylib.character.RootPart
        pendingRotation = root and (root.CFrame - root.Position) or CFrame.identity

        -- First activation performs the saved-destination respawn. After that, the same
        -- module stays armed and automatically returns to the latest death position.
        respawnAt(pendingPosition, pendingRotation, myGeneration)

        DeathSpawn:Clean(lplr.CharacterAdded:Connect(function(character)
            if myGeneration ~= generation or not DeathSpawn.Enabled then return end
            local humanoid = getHumanoid(character)
            local rootPart = getRoot(character)
            if not humanoid or not rootPart then return end

            task.defer(function()
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                if waitingForRespawn then return end

                local deathPosition = pendingPosition or rootPart.Position
                local rotation = pendingRotation or (rootPart.CFrame - rootPart.Position)
                rootPart.CFrame = CFrame.new(deathPosition) * rotation

                if deathConnection then deathConnection:Disconnect() end
                deathConnection = humanoid.Died:Connect(function()
                    if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                    local saved = rootPart.Position
                    local savedRotation = rootPart.CFrame - rootPart.Position
                    pendingPosition = saved
                    pendingRotation = savedRotation
                    respawnAt(saved, savedRotation, myGeneration)
                end)
                DeathSpawn:Clean(deathConnection)
            end)
        end))
    end
end)