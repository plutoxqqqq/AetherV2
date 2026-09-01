run(function()
    local MouseTP
    local Mode
    local Target
    local TravelGaps
    local navigation
    local generation = 0
    local markers = {}
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.RespectCanCollide = true

    local function alive()
        return entitylib.isAlive and entitylib.character and entitylib.character.RootPart and entitylib.character.Humanoid
    end

    local function cleanupMarkers()
        for _, marker in markers do pcall(marker.Destroy, marker) end
        table.clear(markers)
    end

    local function stopNavigation()
        generation += 1
        navigation = nil
        cleanupMarkers()
        if entitylib.isAlive and entitylib.character.Humanoid then
            pcall(entitylib.character.Humanoid.MoveTo, entitylib.character.Humanoid, entitylib.character.RootPart.Position)
        end
    end

    local function disableSoon(message)
        if message then notif('MouseTP', message, 4, 'warning') end
        task.defer(function() if MouseTP.Enabled then MouseTP:Toggle() end end)
    end

    local function floorAt(position, root)
        ray.FilterDescendantsInstances = {lplr.Character, gameCamera}
        local result = workspace:Raycast(position + Vector3.new(0, 2.5, 0), Vector3.new(0, -9, 0), ray)
        return result and result.Instance.CanCollide and result or nil
    end

    local function standingSpace(position, root)
        ray.FilterDescendantsInstances = {lplr.Character, gameCamera}
        return workspace:Raycast(position + Vector3.new(0, 1.2, 0), Vector3.new(0, 4.3, 0), ray) == nil
    end

    local function segmentClear(a, b)
        ray.FilterDescendantsInstances = {lplr.Character, gameCamera}
        local delta = b - a
        if delta.Magnitude < 0.05 then return true end
        local chest = a + Vector3.new(0, 1.6, 0)
        local hit = workspace:Raycast(chest, Vector3.new(delta.X, math.min(delta.Y, 1.5), delta.Z), ray)
        return hit == nil
    end

    local function copyWaypoints(path)
        local out = {}
        for _, waypoint in path:GetWaypoints() do
            table.insert(out, {Position = waypoint.Position, Action = waypoint.Action})
        end
        return out
    end

    local function routeTime(points)
        local total = 0
        for i = 2, #points do
            local delta = points[i].Position - points[i - 1].Position
            total += Vector3.new(delta.X, 0, delta.Z).Magnitude / 16
            if delta.Y > 2.6 or points[i].Action == Enum.PathWaypointAction.Jump then total += 0.22 end
            if delta.Y < -4 then total += math.min(math.abs(delta.Y) / 45, 0.45) end
        end
        return total
    end

    local function normalizeRoute(points, allowGap)
        if not points or #points < 2 then return nil end
        local cleaned = {points[1]}
        for i = 2, #points do
            local previous = cleaned[#cleaned]
            local current = points[i]
            local delta = current.Position - previous.Position
            local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
            -- Reject only genuinely impossible vertical moves. Ordinary stairs, one/two-block
            -- jumps and natural drops are left to the Humanoid instead of being over-validated.
            if delta.Y > 7.4 and horizontal < 4.5 then return nil end
            local floor = floorAt(current.Position, entitylib.character.RootPart)
            if not floor and not allowGap and i < #points then return nil end
            if not standingSpace(current.Position, entitylib.character.RootPart) and i < #points then return nil end
            table.insert(cleaned, current)
        end
        return cleaned
    end

    local function computeCandidate(startPos, destination, params, allowGap)
        local path = pathfindingService:CreatePath(params)
        local ok = pcall(path.ComputeAsync, path, startPos, destination)
        if not ok or path.Status ~= Enum.PathStatus.Success then return nil end
        local points = normalizeRoute(copyWaypoints(path), allowGap)
        if not points then return nil end
        return {Waypoints = points, Time = routeTime(points)}
    end

    local function directCandidate(startPos, destination, allowGap)
        if not segmentClear(startPos, destination) then return nil end
        local points = normalizeRoute({
            {Position = startPos, Action = Enum.PathWaypointAction.Walk},
            {Position = destination, Action = Enum.PathWaypointAction.Walk}
        }, allowGap)
        return points and {Waypoints = points, Time = routeTime(points)} or nil
    end

    local function findRoute(startPos, destination)
        local candidates = {}
        local function add(candidate) if candidate then table.insert(candidates, candidate) end end
        -- Try direct movement first because it is frequently faster than Roblox's conservative path.
        add(directCandidate(startPos, destination, false))
        local profiles = {
            {AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 3},
            {AgentRadius = 1.6, AgentHeight = 4.5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 2},
            {AgentRadius = 1.2, AgentHeight = 4, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 2}
        }
        for _, profile in profiles do add(computeCandidate(startPos, destination, profile, false)) end
        if #candidates == 0 and TravelGaps.Enabled then
            add(directCandidate(startPos, destination, true))
            for _, profile in profiles do add(computeCandidate(startPos, destination, profile, true)) end
        end
        table.sort(candidates, function(a, b) return a.Time < b.Time end)
        return candidates[1]
    end

    local function drawRoute(points)
        cleanupMarkers()
        for index = 2, #points do
            local part = Instance.new('Part')
            part.Name = 'AetherMouseTPPath'
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Material = Enum.Material.Neon
            part.Transparency = 0.45
            part.Size = Vector3.new(1.8, 0.08, 1.8)
            part.CFrame = CFrame.new(points[index].Position - Vector3.new(0, 2.65, 0))
            part.Parent = workspace
            table.insert(markers, part)
        end
    end

    local function gapSupport(root, target)
        if floorAt(root.Position, root) then return end
        -- Built-in AirWalk style support: hold vertical velocity while keeping horizontal
        -- Humanoid movement intact. No permanent platform/part is created.
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, -0.5), velocity.Z)
        if target and target.Y > root.Position.Y + 1.5 then
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(root.AssemblyLinearVelocity.Y, 18), velocity.Z)
        end
    end

    local function travel(destination)
        if not alive() then disableSoon('You must be alive to use MouseTP.'); return end
        generation += 1
        local myGeneration = generation
        local root, humanoid = entitylib.character.RootPart, entitylib.character.Humanoid
        local route = findRoute(root.Position, destination)
        if not route then
            disableSoon(TravelGaps.Enabled and 'No viable route was found.' or 'No grounded route was found. Enable Travel over gaps if needed.')
            return
        end
        navigation = {Destination = destination, Waypoints = route.Waypoints, Index = 2, LastProgress = tick(), LastDistance = math.huge, LastRepath = 0}
        drawRoute(route.Waypoints)

        MouseTP:Clean(runService.Heartbeat:Connect(function()
            if myGeneration ~= generation or not MouseTP.Enabled or not alive() or not navigation then return end
            root, humanoid = entitylib.character.RootPart, entitylib.character.Humanoid
            local dest = navigation.Destination
            if (root.Position - dest).Magnitude <= 2.6 then
                root.CFrame = CFrame.new(dest) * root.CFrame.Rotation
                stopNavigation(); disableSoon(); return
            end
            local point = navigation.Waypoints[navigation.Index]
            if not point then
                if tick() - navigation.LastRepath > 0.25 then
                    navigation.LastRepath = tick()
                    local replanned = findRoute(root.Position, dest)
                    if replanned then navigation.Waypoints, navigation.Index = replanned.Waypoints, 2; drawRoute(replanned.Waypoints) end
                end
                return
            end
            local delta = point.Position - root.Position
            local distance = delta.Magnitude
            if distance <= 2.4 then
                navigation.Index += 1
                navigation.LastProgress, navigation.LastDistance = tick(), math.huge
                return
            end
            if distance < navigation.LastDistance - 0.08 then
                navigation.LastDistance, navigation.LastProgress = distance, tick()
            elseif tick() - navigation.LastProgress > 0.85 and tick() - navigation.LastRepath > 0.35 then
                navigation.LastRepath = tick()
                local replanned = findRoute(root.Position, dest)
                if replanned then navigation.Waypoints, navigation.Index = replanned.Waypoints, 2; navigation.LastProgress = tick(); drawRoute(replanned.Waypoints) end
            end
            if point.Action == Enum.PathWaypointAction.Jump or point.Position.Y > root.Position.Y + 2.2 then
                humanoid.Jump = true
            end
            if TravelGaps.Enabled then gapSupport(root, point.Position) end
            humanoid:MoveTo(Vector3.new(point.Position.X, root.Position.Y, point.Position.Z))
        end))
    end

    MouseTP = vape.Categories.Blatant:CreateModule({
        Name = 'MouseTP',
        Function = function(callback)
            if not callback then stopNavigation(); return end
            if not alive() then disableSoon('You must be alive to use MouseTP.'); return end
            local mouse = lplr:GetMouse()
            local hit = mouse and mouse.Hit
            if not hit then disableSoon('No target position found.'); return end
            local destination = hit.Position
            if Mode.Value == 'TP' then
                entitylib.character.RootPart.CFrame = CFrame.new(destination + Vector3.new(0, 3, 0)) * entitylib.character.RootPart.CFrame.Rotation
                disableSoon(); return
            end
            travel(destination + Vector3.new(0, 2.8, 0))
        end,
        Tooltip = 'Moves to the clicked point. Legit chooses the fastest viable path and only rejects genuinely impossible routes.'
    })
    Mode = MouseTP:CreateDropdown({Name = 'Mode', List = {'Legit', 'TP'}, Default = 'TP', Function = function(value)
        if TravelGaps and TravelGaps.Object then TravelGaps.Object.Visible = value == 'Legit' end
        if navigation and value ~= 'Legit' then stopNavigation() end
    end})
    TravelGaps = MouseTP:CreateToggle({Name = 'Travel over gaps', Darker = true, Visible = function() return Mode and Mode.Value == 'Legit' end, Tooltip = 'Uses temporary vertical support only when a grounded route is unavailable.'})
end)