run(function()
    local AntiLasso
    local Chance
    local Check
    local currentConnections = {}
    local currentCharacter
    local activeLasso
    local ignoredLasso
    local lassoVersion = 0
    local returnFilter = RaycastParams.new()
    local returnOverlap = OverlapParams.new()

    returnFilter.FilterType = Enum.RaycastFilterType.Exclude
    returnFilter.RespectCanCollide = true
    returnFilter.IgnoreWater = true
    returnOverlap.FilterType = Enum.RaycastFilterType.Exclude
    returnOverlap.RespectCanCollide = true

    local function disconnectCharacter()
        for _, connection in currentConnections do
            connection:Disconnect()
        end
        table.clear(currentConnections)
        currentCharacter = nil
    end

    local function isFinite(value)
        return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
    end

    local function isFiniteCFrame(value)
        if typeof(value) ~= 'CFrame' then return false end
        for _, component in {value:GetComponents()} do
            if not isFinite(component) then return false end
        end
        return true
    end

    
    
    
    
    local function isLassoPart(inst)
        if inst:IsA('RopeConstraint') then return true end
        local name = inst.Name:lower()
        return name:find('lasso', 1, true) ~= nil or name:find('rope', 1, true) ~= nil
    end

    local function getLassoObject(character)
        for _, descendant in character:GetDescendants() do
            if isLassoPart(descendant) then
                return descendant
            end
        end
    end

    local function hasClearance(character, root, position)
        returnOverlap.FilterDescendantsInstances = {character, gameCamera}
        for _, part in workspace:GetPartBoundsInBox(CFrame.new(position), root.Size * Vector3.new(0.9, 1, 0.9), returnOverlap) do
            local queryIgnored = bedwars.QueryUtil.isQueryIgnored
            if part.CanCollide and not (type(queryIgnored) == 'function' and queryIgnored(bedwars.QueryUtil, part)) then
                return false
            end
        end
        return true
    end

    local function getSafeReturnCFrame(event)
        local character, root, saved = event.character, event.root, event.cframe
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not isFiniteCFrame(saved) or not root.Parent or not humanoid or humanoid.Health <= 0 then return end
        local position = saved.Position
        if position.Y <= workspace.FallenPartsDestroyHeight + 12 then return end

        returnFilter.FilterDescendantsInstances = {character, gameCamera}
        local ground = workspace:Raycast(position + Vector3.yAxis * 3, -Vector3.yAxis * 99, returnFilter)
        if ground and position.Y - ground.Position.Y >= 1 and hasClearance(character, root, position) then
            return saved
        end

        local offsets = {Vector3.zero}
        for radius = 3, 12, 3 do
            for _, direction in {
                Vector3.xAxis,
                -Vector3.xAxis,
                Vector3.zAxis,
                -Vector3.zAxis,
                Vector3.new(1, 0, 1).Unit,
                Vector3.new(1, 0, -1).Unit,
                Vector3.new(-1, 0, 1).Unit,
                Vector3.new(-1, 0, -1).Unit
            } do
                table.insert(offsets, direction * radius)
            end
        end

        local best, bestDistance
        for _, offset in offsets do
            local origin = position + offset + Vector3.yAxis * 12
            local result = workspace:Raycast(origin, -Vector3.yAxis * 72, returnFilter)
            if result and result.Instance.CanCollide then
                local candidate = Vector3.new(origin.X, result.Position.Y + humanoid.HipHeight + root.Size.Y / 2, origin.Z)
                local distance = (candidate - position).Magnitude
                if candidate.Y > workspace.FallenPartsDestroyHeight + 12 and hasClearance(character, root, candidate)
                    and (not bestDistance or distance < bestDistance)
                then
                    best, bestDistance = candidate, distance
                end
            end
        end
        return best and CFrame.new(best) * saved.Rotation or nil
    end

    local function clearLasso(event)
        if activeLasso ~= event then return end
        activeLasso = nil
        if event.root.Parent then
            event.root.Anchored = false
        end
    end

    local function returnPlayer(event, visualReleased)
        if activeLasso ~= event or event.returned or not AntiLasso.Enabled then return false end
        if collectionService:HasTag(event.character, 'LassoHooked') then return false end
        if not visualReleased and getLassoObject(event.character) then return false end
        local root = event.root
        local returnCFrame = getSafeReturnCFrame(event)
        if not returnCFrame or lplr.Character ~= event.character or not entitylib.isAlive or entitylib.character.RootPart ~= root then
            clearLasso(event)
            return true
        end
        event.returned = true
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = returnCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if activeLasso == event then
            activeLasso = nil
        end
        return true
    end

    local function waitForRelease(event)
        task.spawn(function()
            local visualReleasedAt
            while activeLasso == event and AntiLasso.Enabled and lplr.Character == event.character and event.root.Parent do
                local tagged = collectionService:HasTag(event.character, 'LassoHooked')
                local visual = getLassoObject(event.character)
                if not tagged and not visual then
                    returnPlayer(event)
                    return
                end
                if not tagged then
                    visualReleasedAt = visualReleasedAt or tick()
                    if tick() - visualReleasedAt >= 1 then
                        returnPlayer(event, true)
                        return
                    end
                else
                    visualReleasedAt = nil
                end
                task.wait(0.05)
            end
        end)
    end

    local function startLasso(character, nativeEvent)
        if not AntiLasso.Enabled or character ~= lplr.Character or ignoredLasso == character then return end
        if activeLasso and activeLasso.character == character then
            if not nativeEvent or not activeLasso.releaseSeen then return end
            clearLasso(activeLasso)
        end
        if Random.new(os.clock()):NextNumber(1, 100) > Chance.Value or Check.Enabled and not entitylib.EntityPosition({
            Range = 50,
            Part = 'RootPart',
            Players = true
        }) then
            if nativeEvent then ignoredLasso = character end
            return
        end
        local root = character:FindFirstChild('HumanoidRootPart') or character.PrimaryPart
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not root or not humanoid or humanoid.Health <= 0 or not isFiniteCFrame(root.CFrame) then return end
        if activeLasso then clearLasso(activeLasso) end
        lassoVersion += 1
        local event = {
            cframe = root.CFrame,
            character = character,
            root = root,
            token = lassoVersion
        }
        activeLasso = event
        root.Anchored = true
        waitForRelease(event)
    end

    local function releaseLasso(character)
        if ignoredLasso == character then
            ignoredLasso = nil
            return
        end
        local event = activeLasso
        if not event or event.character ~= character then return end
        event.releaseSeen = true
        task.defer(function()
            local deadline = tick() + 1
            repeat
                if activeLasso ~= event or returnPlayer(event) then return end
                task.wait()
            until tick() >= deadline
            returnPlayer(event, true)
        end)
    end

    local function Added(character)
        local previousCharacter = currentCharacter
        disconnectCharacter()
        if previousCharacter ~= character then ignoredLasso = nil end
        if not AntiLasso.Enabled or not character or not character.Parent then return end
        if activeLasso then clearLasso(activeLasso) end
        currentCharacter = character
        
        
        
        
        table.insert(currentConnections, character.DescendantAdded:Connect(function(descendant)
            if isLassoPart(descendant) then
                startLasso(character)
            end
        end))
        table.insert(currentConnections, character.Destroying:Connect(function()
            if currentCharacter == character then
                disconnectCharacter()
            end
            if activeLasso and activeLasso.character == character then
                clearLasso(activeLasso)
            end
        end))
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if humanoid then
            table.insert(currentConnections, humanoid.Died:Connect(function()
                if activeLasso and activeLasso.character == character then
                    clearLasso(activeLasso)
                end
            end))
        end
        if collectionService:HasTag(character, 'LassoHooked') or getLassoObject(character) then
            startLasso(character, collectionService:HasTag(character, 'LassoHooked'))
        end
    end

    AntiLasso = vape.Categories.Utility:CreateModule({
        Name = 'AntiLasso',
        Function = function(callback)
            if callback then
                AntiLasso:Clean(collectionService:GetInstanceAddedSignal('LassoHooked'):Connect(function(character)
                    if character == lplr.Character then
                        startLasso(character, true)
                    end
                end))
                AntiLasso:Clean(collectionService:GetInstanceRemovedSignal('LassoHooked'):Connect(function(character)
                    if character == lplr.Character then
                        releaseLasso(character)
                    end
                end))
                AntiLasso:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
                    task.defer(function()
                        if AntiLasso.Enabled and ent and ent.Character then
                            Added(ent.Character)
                        end
                    end)
                end))
                AntiLasso:Clean(lplr.OnTeleport:Connect(function()
                    if activeLasso then clearLasso(activeLasso) end
                    ignoredLasso = nil
                    disconnectCharacter()
                end))
                if entitylib.isAlive then
                    Added(lplr.Character)
                end
            else
                lassoVersion += 1
                ignoredLasso = nil
                disconnectCharacter()
                if activeLasso then clearLasso(activeLasso) end
            end
        end,
        Tooltip = 'Prevents you from getting pulled by lasso projectile'
    })

    Chance = AntiLasso:CreateSlider({
        Name = 'Chance',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = '%'
    })
    Check = AntiLasso:CreateToggle({Name = 'Only when targeting'})
end)
