#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
INIT = ROOT / 'init.lua'
MAIN = ROOT / 'main.lua'
UNIVERSAL = ROOT / 'games' / 'universal.lua'
GUI = ROOT / 'guis' / 'new.lua'


def read(path): return path.read_text(encoding='utf-8')
def write(path, data): path.write_text(data, encoding='utf-8')


def clear_stale_premium():
    text = read(INIT)
    marker = "shared.AetherV2PremiumAuthorized = false\n"
    cleanup = """shared.AetherV2PremiumAuthorized = false
-- A premium session is valid for one execution only. A previous injection can leave
-- fetch closures/token state behind in shared, so clear every session-derived value
-- before attempting authorization for this execution.
shared.AetherV2PremiumToken = nil
shared.AetherV2PremiumRef = nil
shared.AetherV2PremiumFetchSource = nil
shared.AetherV2PremiumFetchTree = nil
"""
    if cleanup not in text:
        if marker not in text: raise RuntimeError('init.lua premium reset marker missing')
        text = text.replace(marker, cleanup, 1)
    write(INIT, text)

    text = read(MAIN)
    old = """local function loadPremiumModules()
\tlocal fetchSource = shared.AetherV2PremiumFetchSource
\tlocal fetchTree = shared.AetherV2PremiumFetchTree
\tif type(fetchSource) ~= 'function' or type(fetchTree) ~= 'function' then return end
"""
    new = """local function loadPremiumModules()
\t-- Never trust closures left by a previous injection. init.lua must have validated
\t-- this execution before private modules can be fetched.
\tif shared.AetherV2PremiumAuthorized ~= true then return end
\tlocal fetchSource = shared.AetherV2PremiumFetchSource
\tlocal fetchTree = shared.AetherV2PremiumFetchTree
\tif type(fetchSource) ~= 'function' or type(fetchTree) ~= 'function' then return end
"""
    if new not in text:
        if old not in text: raise RuntimeError('main.lua loadPremiumModules marker missing')
        text = text.replace(old, new, 1)
    write(MAIN, text)


def run_spans(source):
    starts = [m.start() for m in re.finditer(r'\brun\s*\(\s*function\s*\(\s*\)', source)]
    spans = []
    for start in starts:
        opening = source.find('(', start)
        depth = 0; quote = None; esc = False; i = opening
        while i < len(source):
            c = source[i]
            if quote:
                if esc: esc = False
                elif c == '\\': esc = True
                elif c == quote: quote = None
                i += 1; continue
            if c in ('\'', '"', '`'):
                quote = c; i += 1; continue
            if source.startswith('--', i):
                if source.startswith('--[[', i):
                    end = source.find(']]', i + 4); i = len(source) if end < 0 else end + 2; continue
                nl = source.find('\n', i + 2); i = len(source) if nl < 0 else nl + 1; continue
            if c == '(': depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    spans.append((start, i + 1)); break
            i += 1
    return spans


def replace_module(source, name, replacement):
    needle = "Name = '" + name + "'"
    pos = source.find(needle)
    if pos < 0: raise RuntimeError('module missing: ' + name)
    spans = [s for s in run_spans(source) if s[0] <= pos < s[1]]
    if not spans: raise RuntimeError('module run block missing: ' + name)
    start, end = min(spans, key=lambda s: s[1] - s[0])
    return source[:start] + replacement.rstrip() + source[end:]


def mouse_tp_module():
    return r'''run(function()
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
end)'''


def infinite_fly_module():
    return r'''run(function()
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
end)'''


def patch_universal():
    text = read(UNIVERSAL)
    text = replace_module(text, 'MouseTP', mouse_tp_module())
    text = replace_module(text, 'InfiniteFly', infinite_fly_module())
    write(UNIVERSAL, text)


def patch_gui():
    text = read(GUI)
    # Remove the deferred second sort/canvas pass that made category expansion visibly jitter.
    old = """\t\tmainapi:SortModules()\n\t\ttask.defer(function()\n\t\t\tif not moduleapi.Object or not moduleapi.Object.Parent then return end\n\t\t\tmoduleapi:RefreshHiddenState(mainapi.EditGUI == true)\n\t\t\tif categoryapi.UpdateHidden then categoryapi:UpdateHidden() end\n\t\t\tmainapi:SortModules()\n\t\t\tlocal parent = moduleapi.Object.Parent\n\t\t\tlocal layout = parent:FindFirstChildOfClass('UIListLayout')\n\t\t\tif parent:IsA('ScrollingFrame') and layout then\n\t\t\t\tparent.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / scale.Scale)\n\t\t\tend\n\t\tend)\n"""
    new = """\t\tmainapi:SortModules()\n"""
    if old in text: text = text.replace(old, new, 1)

    # World should not be the one category that always starts collapsed. Set its default
    # expanded state at category creation without overriding saved user collapse state later.
    marker = """\tlocal categoryapi = {\n\t\tType = 'Category',\n\t\tExpanded = false\n\t}\n\tlocal categoryHovered = false\n"""
    replacement = """\tlocal categoryapi = {\n\t\tType = 'Category',\n\t\tExpanded = categorysettings.Name == 'World'\n\t}\n\tlocal categoryHovered = false\n"""
    if replacement not in text:
        if marker not in text: raise RuntimeError('GUI category expanded patch marker missing')
        text = text.replace(marker, replacement, 1)
    write(GUI, text)


def validate():
    init = read(INIT); main = read(MAIN); universal = read(UNIVERSAL); gui = read(GUI)
    assert 'shared.AetherV2PremiumFetchSource = nil' in init
    assert 'if shared.AetherV2PremiumAuthorized ~= true then return end' in main
    assert "Name = 'MouseTP'" in universal and 'fastest viable path' in universal
    assert "Name = 'InfiniteFly'" in universal and 'single physics velocity writer' in universal
    assert "Expanded = categorysettings.Name == 'World'" in gui
    assert 'task.defer(function()\n\t\t\tif not moduleapi.Object or not moduleapi.Object.Parent then return end' not in gui
    print('Validated remaining original batch fixes')


if __name__ == '__main__':
    clear_stale_premium()
    patch_universal()
    patch_gui()
    validate()
