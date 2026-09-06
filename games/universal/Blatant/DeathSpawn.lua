run(function()
    local DeathSpawn
    local generation = 0
    local deathConnection
    local characterConnection

    local function disconnect(connection)
        if connection then
            connection:Disconnect()
        end
    end

    local function clearConnections()
        disconnect(deathConnection)
        disconnect(characterConnection)
        deathConnection = nil
        characterConnection = nil
    end

    local function getHumanoid(character)
        return character and character:FindFirstChildOfClass('Humanoid')
    end

    local function getRoot(character)
        return character and character:FindFirstChild('HumanoidRootPart')
    end

    local function saveTransform(character)
        local root = getRoot(character)
        if not root then return nil end

        return root.Position, root.CFrame.Rotation
    end

    local function placeCharacter(character, position, rotation)
        local root = getRoot(character) or character:WaitForChild('HumanoidRootPart', 5)
        if not root or not position then return end

        -- Always attempt the placement as soon as the replacement character exists.
        root.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
        root.AssemblyLinearVelocity = Vector3.zero
    end

    local function hookCharacter(character, myGeneration)
        if myGeneration ~= generation or not DeathSpawn.Enabled then return end

        local humanoid = getHumanoid(character) or character:WaitForChild('Humanoid', 5)
        local root = getRoot(character) or character:WaitForChild('HumanoidRootPart', 5)
        if not humanoid or not root then return end

        disconnect(deathConnection)
        deathConnection = humanoid.Died:Connect(function()
            if myGeneration ~= generation or not DeathSpawn.Enabled then return end

            -- Capture the exact position and rotation at the moment of death.
            local position, rotation = saveTransform(character)
            if not position then return end

            disconnect(characterConnection)
            characterConnection = lplr.CharacterAdded:Connect(function(newCharacter)
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end

                task.defer(function()
                    if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                    placeCharacter(newCharacter, position, rotation)
                end)
            end)

            DeathSpawn:Clean(characterConnection)

            -- Roblox normally creates the replacement character automatically.
            -- If the current character remains present, keep attempting to restore
            -- the saved transform until CharacterAdded supplies the replacement.
        end)

        DeathSpawn:Clean(deathConnection)
    end

    DeathSpawn = vape.Categories.Blatant:CreateModule({
        Name = 'DeathSpawn',
        Function = function(callback)
            generation += 1
            local myGeneration = generation
            clearConnections()

            if not callback then return end

            if lplr.Character then
                hookCharacter(lplr.Character, myGeneration)
            end

            local connection = lplr.CharacterAdded:Connect(function(character)
                if myGeneration ~= generation or not DeathSpawn.Enabled then return end
                hookCharacter(character, myGeneration)
            end)
            DeathSpawn:Clean(connection)
        end,
        Tooltip = 'Respawn at the position and rotation where you died.'
    })
end)
-- blatant/FastClimb.lua
