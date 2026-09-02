run(function()
    local DeathSpawn
    local Mode
    local Target
    local Waypoint
    local GlideSpeed
    local HeightOffset
    local generation = 0
    local deathConnection
    local characterConnection
    local travelConnection

    local function rootOf(character)
        return character and (character:FindFirstChild('HumanoidRootPart') or character:WaitForChild('HumanoidRootPart', 5))
    end

    local function humanoidOf(character)
        return character and (character:FindFirstChildOfClass('Humanoid') or character:WaitForChild('Humanoid', 5))
    end

    local function alive()
        return entitylib.isAlive and entitylib.character and entitylib.character.RootPart and entitylib.character.Humanoid
    end

    local function parseWaypoint(value)
        if not value or value == '' then return nil end
        local x, y, z = value:match('^%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)')
        if not x then return nil end
        return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
    end

    local function getTarget()
        if Target.Value == 'Mouse' then
            local mouse = lplr:GetMouse()
            return mouse and mouse.Hit and mouse.Hit.Position or nil
        end
        return parseWaypoint(Waypoint.Value)
    end

    local function clearConnections()
        if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
        if characterConnection then characterConnection:Disconnect(); characterConnection = nil end
        if travelConnection then travelConnection:Disconnect(); travelConnection = nil end
    end

    local function killCharacter()
        local character = lplr.Character
        local humanoid = humanoidOf(character)
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        elseif character then
            pcall(function() character:BreakJoints() end)
        end
    end

    local function glide(position, rotation, myGeneration)
        if travelConnection then travelConnection:Disconnect() end

        local firstFrame = true
        travelConnection = runService.Heartbeat:Connect(function()
            if myGeneration ~= generation or not DeathSpawn.Enabled then
                travelConnection:Disconnect()
                travelConnection = nil
                return
            end

            local root = alive() and entitylib.character.RootPart or rootOf(lplr.Character)
            if not root then return end

            local destination = position + Vector3.new(0, HeightOffset.Value, 0)
            local delta = destination - root.Position
            local distance = delta.Magnitude
            if distance <= 2.5 then
                root.CFrame = CFrame.new(destination) * (rotation or CFrame.identity)
                root.AssemblyLinearVelocity = Vector3.zero
                travelConnection:Disconnect()
                travelConnection = nil
                if DeathSpawn.Enabled then DeathSpawn:Toggle() end
                return
            end

            local direction = delta.Unit
            local speed = math.max(GlideSpeed.Value, 1)
            root.AssemblyLinearVelocity = direction * speed

            if firstFrame then
                firstFrame = false
                root.CFrame = CFrame.new(root.Position + direction * math.min(distance, speed / 60)) * root.CFrame.Rotation
            end
        end)
        DeathSpawn:Clean(travelConnection)
    end

    local function respawnAndReturn(position, rotation, myGeneration)
        characterConnection = lplr.CharacterAdded:Connect(function(character)
            if myGeneration ~= generation or not DeathSpawn.Enabled then return end
            task.defer(function()
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                local root = rootOf(character)
                if not root then return end

                -- Begin on the first available frame after CharacterAdded.
                root.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
                root.AssemblyLinearVelocity = Vector3.zero
                glide(position, rotation, myGeneration)
            end)
        end)
        DeathSpawn:Clean(characterConnection)
        killCharacter()
    end

    local function hookRespawnMode(myGeneration)
        local function hook(character)
            local humanoid = humanoidOf(character)
            local root = rootOf(character)
            if not humanoid or not root then return end

            if deathConnection then deathConnection:Disconnect() end
            deathConnection = humanoid.Died:Connect(function()
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end

                -- Exact position at the death event, before the old character disappears.
                local position = root.Position
                local rotation = root.CFrame - root.Position

                if characterConnection then characterConnection:Disconnect() end
                characterConnection = lplr.CharacterAdded:Connect(function(newCharacter)
                    if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                    task.defer(function()
                        if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                        local newRoot = rootOf(newCharacter)
                        if not newRoot then return end
                        newRoot.CFrame = CFrame.new(position) * rotation
                        newRoot.AssemblyLinearVelocity = Vector3.zero
                    end)
                end)
                DeathSpawn:Clean(characterConnection)
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

            if not callback then return end

            if Mode.Value == 'Respawn' then
                -- Every death is handled automatically using that death's exact position.
                hookRespawnMode(myGeneration)
                return
            end

            local targetPosition = getTarget()
            if not targetPosition then
                notif('DeathSpawn', Target.Value == 'Mouse' and 'No mouse position found.' or 'Invalid waypoint. Use x, y, z.', 4, 'warning')
                task.defer(function() if DeathSpawn.Enabled then DeathSpawn:Toggle() end end)
                return
            end

            local root = alive() and entitylib.character.RootPart
            local rotation = root and (root.CFrame - root.Position) or CFrame.identity
            -- Save the destination before respawning, then immediately glide the new character there.
            respawnAndReturn(targetPosition, rotation, myGeneration)
        end,
        Tooltip = 'Respawn at a saved mouse/waypoint position or automatically respawn at your death position.'
    })

    Mode = DeathSpawn:CreateDropdown({
        Name = 'Mode',
        List = {'TP', 'Respawn'},
        Default = 'TP'
    })

    Target = DeathSpawn:CreateDropdown({
        Name = 'Target',
        List = {'Mouse', 'Waypoint'},
        Default = 'Mouse'
    })

    Waypoint = DeathSpawn:CreateTextBox({
        Name = 'Waypoint',
        Placeholder = 'x, y, z'
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
end)