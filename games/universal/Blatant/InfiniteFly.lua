run(function()
    local InfiniteFly
    local UpSpeed
    local DownSpeed
    local HorizontalSpeed
    local state
    local generation = 0

    local function cleanup(restorePosition)
        local current = state
        state = nil
        if not current then return end
        if current.Connection then current.Connection:Disconnect() end
        if current.DiedConnection then current.DiedConnection:Disconnect() end
        if current.CharacterConnection then current.CharacterConnection:Disconnect() end
        if current.Clone and current.Clone.Parent then current.Clone:Destroy() end
        if current.Character and current.Character.Parent then
            local humanoid = current.Character:FindFirstChildOfClass('Humanoid')
            local root = current.Character:FindFirstChild('HumanoidRootPart') or current.Character.PrimaryPart
            if humanoid then humanoid.PlatformStand = false; humanoid.AutoRotate = true end
            if root then
                root.Anchored = false
                root.AssemblyAngularVelocity = Vector3.zero
                if restorePosition and current.SafeCFrame then root.CFrame = current.SafeCFrame end
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
        if gameCamera and current.CameraSubject and current.CameraSubject.Parent then gameCamera.CameraSubject = current.CameraSubject end
    end

    local function disable()
        task.defer(function() if InfiniteFly.Enabled then InfiniteFly:Toggle() end end)
    end

    local function start()
        if not entitylib.isAlive or not entitylib.character then disable(); return end
        cleanup(false)
        generation += 1
        local myGeneration = generation
        local character = entitylib.character.Character
        local root = entitylib.character.RootPart
        local humanoid = entitylib.character.Humanoid
        if not character or not root or not humanoid then disable(); return end

        local safe = root.CFrame
        local clone
        local oldArchivable = character.Archivable
        character.Archivable = true
        local ok, result = pcall(character.Clone, character)
        character.Archivable = oldArchivable
        if ok then clone = result end
        if clone then
            clone.Name = 'AetherInfiniteFlyVisual'
            for _, object in clone:GetDescendants() do
                if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy()
                elseif object:IsA('BasePart') then object.CanCollide = false; object.CanTouch = false; object.CanQuery = false end
            end
            clone.Parent = workspace
            clone:PivotTo(character:GetPivot())
        end

        state = {Character = character, Root = root, Humanoid = humanoid, Clone = clone, SafeCFrame = safe, CameraSubject = gameCamera.CameraSubject}
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true

        state.DiedConnection = humanoid.Died:Connect(function()
            -- Never leave the render/fly loop holding destroyed character references.
            generation += 1
            cleanup(false)
        end)
        state.CharacterConnection = lplr.CharacterAdded:Connect(function()
            generation += 1
            cleanup(false)
            if InfiniteFly.Enabled then task.delay(0.35, function() if InfiniteFly.Enabled then start() end end) end
        end)

        state.Connection = runService.Heartbeat:Connect(function(dt)
            if myGeneration ~= generation or not InfiniteFly.Enabled then return end
            if not root.Parent or humanoid.Health <= 0 then generation += 1; cleanup(false); return end
            if not isnetworkowner(root) then return end

            local move = humanoid.MoveDirection
            local vertical = 0
            if inputService:IsKeyDown(Enum.KeyCode.Space) then vertical += UpSpeed.Value end
            if inputService:IsKeyDown(Enum.KeyCode.LeftShift) or inputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical -= DownSpeed.Value end
            local horizontal = move.Magnitude > 0 and move.Unit * HorizontalSpeed.Value or Vector3.zero

            -- Drive velocity once per physics heartbeat. The previous implementation fought
            -- several movement writers and decelerated itself, which caused immediate lagbacks.
            root.AssemblyLinearVelocity = Vector3.new(horizontal.X, vertical, horizontal.Z)
            root.AssemblyAngularVelocity = Vector3.zero

            -- Keep a recent grounded position. On disable/death this is the only position we may
            -- restore to; never teleport to stale clone coordinates.
            local floor = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), RaycastParams.new())
            if floor and floor.Instance and floor.Instance.CanCollide then state.SafeCFrame = root.CFrame end
            if clone and clone.Parent then clone:PivotTo(root.CFrame) end
        end)
    end

    InfiniteFly = vape.Categories.Blatant:CreateModule({
        Name = 'InfiniteFly',
        Tooltip = 'Sustained flight with death-safe cleanup and a single physics velocity writer.',
        Function = function(callback)
            generation += 1
            if callback then start() else cleanup(false) end
        end
    })
    HorizontalSpeed = InfiniteFly:CreateSlider({Name = 'Speed', Min = 10, Max = 100, Default = 28, Suffix = ' studs/s'})
    UpSpeed = InfiniteFly:CreateSlider({Name = 'Up speed', Min = 5, Max = 100, Default = 28, Suffix = ' studs/s'})
    DownSpeed = InfiniteFly:CreateSlider({Name = 'Down speed', Min = 5, Max = 100, Default = 28, Suffix = ' studs/s'})
    InfiniteFly:Clean(function() generation += 1; cleanup(false) end)
end)
