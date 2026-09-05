run(function()
    local AntiFall
    local Mode
    local Material
    local Color
    local FlyRelease
    local ClutchBlocks
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true

    local CELL = 3

    local function getLowGround()
        local mag = math.huge
        for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
            pos = pos * 3
            if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
                mag = pos.Y
            end
        end
        return mag
    end

    -- getLowGround walks every block on the map, so it is far too heavy to call from a per-frame
    -- check. The lowest block on a BedWars map barely moves, so cache it.
    local lowestValue, lowestAt = math.huge, 0
    local function lowestGround()
        if tick() - lowestAt > 5 then
            lowestValue = getLowGround()
            lowestAt = tick()
        end
        return lowestValue
    end

    -- Column results are cached for a few frames as well: the void check runs every frame while
    -- airborne, and that is exactly when the ray finds nothing and the store walk is reached.
    local columnKey, columnValue, columnAt = nil, nil, 0

    -- Is another module already flying/launching us? Nothing in here may fight those: they own the
    -- character's velocity while they run, and both the old clutch and the old Normal mode used to
    -- yank against them.
    local function beingCarried()
        local flyModule = Fly or vape.Modules.Fly
        local longJumpModule = LongJump or vape.Modules.LongJump
        if flyModule and flyModule.Enabled then return true end
        if longJumpModule and longJumpModule.Enabled then return true end
        return false
    end

    -- The one question both new modes hinge on: is there ANY land under us, or is this the void?
    --
    -- Answered two independent ways, because either one alone gives false answers that matter:
    --   * a long downward ray, which sees map geometry the block store knows nothing about, and
    --   * the block engine's own store walked down the column, which cannot be defeated by a
    --     collision group, a CanQuery flag or a filter.
    -- `drift` follows our horizontal velocity so the probe looks at the column we are actually
    -- heading for. That is the false-place fix: running off a ledge toward a lower platform used to
    -- read as "void" because the straight-down ray hit the ledge we were leaving.
    local function landBelow(root, lookahead)
        local pos = root.Position
        local horiz = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
        local drift = horiz * math.clamp(lookahead or 0, 0, 2)
        local from = Vector3.new(pos.X + drift.X, pos.Y, pos.Z + drift.Z)

        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
        rayCheck.CollisionGroup = root.CollisionGroup
        local ray = workspace:Raycast(from, Vector3.new(0, -600, 0), rayCheck)
        if ray then return ray.Position.Y end

        -- Nothing physical: ask the block store, walking the column down to the lowest block on
        -- the map. One lookup per 3 studs, stopping at the first hit.
        local lowest = lowestGround()
        if lowest == math.huge then return nil end
        local cell = bedwars.BlockController:getBlockPosition(from)
        local key = cell.X .. ',' .. cell.Z
        if columnKey == key and (tick() - columnAt) < 0.15 then
            return columnValue
        end
        local floor = math.max(math.floor(lowest / CELL), cell.Y - 400)
        local found = nil
        for y = cell.Y, floor, -1 do
            if getPlacedBlock(Vector3.new(cell.X, y, cell.Z) * CELL) then
                found = y * CELL
                break
            end
        end
        columnKey, columnValue, columnAt = key, found, tick()
        return found
    end

    ----------------------------------------------------------------------------
    -- Clutch
    --
    -- Rebuilt. The old version waited until the barrier and then bridged in from a wall at BARRIER
    -- height - hundreds of studs below where the fall started - firing a placement every 0.01s
    -- without ever checking whether one landed. Over the void there is usually no wall within
    -- range at that height either, so the common case was a burst of refused placements and a
    -- death. It also had no idea whether the fall was real, so a hop off a ledge toward lower
    -- ground threw down a bridge for nothing.
    --
    -- What it does now: the instant a genuine void fall starts - while the island we just left is
    -- still beside us - it finds a real support block, lays a short platform in under our feet at
    -- our CURRENT height, and confirms each block arrived before asking for the next.
    ----------------------------------------------------------------------------
    local clutchUntil, clutchBusy, clutchGeneration = 0, false, 0

    -- Wool first (it is what everything else buys), then any other sane block. Anything that
    -- explodes, sticks, traps or cannot be stood on is no use as a floor.
    local badBlocks = {'tnt', 'cannon', 'bed', 'trap', 'gumdrop', 'glue', 'ladder', 'sludge', 'bomb', 'beacon', 'spawner', 'chest', 'barrel'}
    local function clutchBlock()
        local wool, amount = getWool()
        if wool and (amount or 0) > 0 then return wool end
        for _, item in store.inventory.inventory.items do
            local meta = bedwars.ItemMeta[item.itemType]
            if meta and meta.block and (item.amount or 0) > 0 then
                local bad = false
                for _, name in badBlocks do
                    if item.itemType:find(name) then
                        bad = true
                        break
                    end
                end
                if not bad then return item.itemType end
            end
        end
        return nil
    end

    local faceOffsets = {
        Vector3.new(CELL, 0, 0), Vector3.new(-CELL, 0, 0),
        Vector3.new(0, CELL, 0), Vector3.new(0, -CELL, 0),
        Vector3.new(0, 0, CELL), Vector3.new(0, 0, -CELL)
    }

    -- A block needs something to lean on, so a cell is only worth asking for once one of its six
    -- faces is filled. Blindly requesting mid-air placements is most of what made the old clutch
    -- look broken.
    local function hasSupport(world)
        for _, offset in faceOffsets do
            if getPlacedBlock(world + offset) then return true end
        end
        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
        for _, offset in faceOffsets do
            local probe = world + offset
            if workspace:Raycast(probe + Vector3.new(0, 1.4, 0), Vector3.new(0, -2.8, 0), rayCheck) then return true end
        end
        return false
    end

    -- Nearest cell we could build off, searched outward from our own column at the height we want
    -- the floor. Right at the start of a fall that is the edge of the island we just walked off.
    local function findSupportCell(centre)
        local best, bestDist
        local reach = math.clamp(ClutchBlocks and ClutchBlocks.Value or 6, 1, 10)
        for radius = 1, reach do
            for x = -radius, radius do
                for z = -radius, radius do
                    if math.max(math.abs(x), math.abs(z)) ~= radius then continue end
                    for y = -1, 2 do
                        local world = centre + Vector3.new(x * CELL, y * CELL, z * CELL)
                        if getPlacedBlock(world) then
                            local d = (world - centre).Magnitude
                            if not bestDist or d < bestDist then
                                best, bestDist = world, d
                            end
                        end
                    end
                end
            end
            if best then return best end
        end
        return best
    end

    local function placeClutch(world, block)
        if getPlacedBlock(world) then return true end
        if not hasSupport(world) then return false end
        pcall(bedwars.placeBlock, world, block, false)
        -- Confirm it actually arrived instead of firing the next one blind. A placement the server
        -- refused has to be seen as refused, or the whole bridge is built on nothing.
        -- A direct placement normally reaches the block store on the next few simulation steps.
        -- Waiting a third of a second before trying another supported cell was enough to fall
        -- outside of placement reach, so only reserve a short confirmation window here.
        local deadline = tick() + 0.12
        repeat
            task.wait(0.03)
        until getPlacedBlock(world) or tick() > deadline or not AntiFall.Enabled or Mode.Value ~= 'Clutch'
        return getPlacedBlock(world) ~= nil
    end

    local function clutch(predicted, token)
        if clutchBusy or tick() < clutchUntil or not entitylib.isAlive or Mode.Value ~= 'Clutch' or token ~= clutchGeneration then return end
        local root = entitylib.character.RootPart
        if not root or not isnetworkowner(root) then return end
        local block = clutchBlock()
        if not block then return end

        clutchBusy = true
        clutchUntil = tick() + 0.12

        -- Floor height: one cell under our feet, right where we are now. Catching us here instead
        -- of at barrier level is the difference between losing a couple of studs and losing the
        -- whole drop.
        local hip = entitylib.character.HipHeight or 3
        local feet = root.Position.Y - hip - (root.Size.Y * 0.5)
        local barrierTop = AntiFallPart and (AntiFallPart.Position.Y + (AntiFallPart.Size.Y * 0.5)) or -math.huge
        -- The floor must be placed at the live foot height, and its horizontal lead must stay
        -- inside a one-block placement reach. The old long ballistic prediction could put the
        -- first request ten studs ahead of the player before the clutch had a supporting block.
        local targetPosition = predicted or root.Position
        local lead = (targetPosition - root.Position) * Vector3.new(1, 0, 1)
        if lead.Magnitude > CELL then
            targetPosition = root.Position + lead.Unit * CELL
        end
        local floorCell = bedwars.BlockController:getBlockPosition(Vector3.new(targetPosition.X, feet - 1.5, targetPosition.Z))
        local floorY = floorCell.Y * CELL
        -- Never build into the barrier itself.
        if floorY <= barrierTop + 1 then
            floorY = math.floor((barrierTop + CELL + 1) / CELL) * CELL
        end

        local under = Vector3.new(floorCell.X * CELL, floorY, floorCell.Z * CELL)

        -- Directly beneath us first: if the island edge is still within a block of us (the normal
        -- case at the start of a fall) this single placement is the whole clutch.
        if placeClutch(under, block) then
            clutchBusy = false
            return
        end

        -- Otherwise walk in from the nearest real support, one confirmed block at a time, so each
        -- new block leans on the previous one.
        local support = findSupportCell(under)
        if not support then
            clutchBusy = false
            return
        end

        local delta = under - support
        local steps = (math.abs(delta.X) + math.abs(delta.Z)) / CELL
        steps = math.clamp(math.floor(steps + 0.5), 0, math.clamp(ClutchBlocks and ClutchBlocks.Value or 6, 1, 10))
        local cursor = Vector3.new(support.X, floorY, support.Z)
        for _ = 1, steps do
            if not AntiFall.Enabled or Mode.Value ~= 'Clutch' or token ~= clutchGeneration then break end
            if landBelow(root, 0.35) then break end
            if math.abs(under.X - cursor.X) > 0.1 then
                cursor += Vector3.new(math.sign(under.X - cursor.X) * CELL, 0, 0)
            else
                cursor += Vector3.new(0, 0, math.sign(under.Z - cursor.Z) * CELL)
            end
            if not placeClutch(cursor, block) then break end
            -- Landed on it already: nothing more to build.
            if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then break end
        end

        -- Finish under our feet (we have drifted while building, so recompute).
        if entitylib.isAlive and AntiFall.Enabled and Mode.Value == 'Clutch' and token == clutchGeneration then
            local now = entitylib.character.RootPart
            if now then
                local cell = bedwars.BlockController:getBlockPosition(Vector3.new(now.Position.X, floorY, now.Position.Z))
                placeClutch(Vector3.new(cell.X * CELL, floorY, cell.Z * CELL), block)
            end
        end
        clutchBusy = false
    end

    ----------------------------------------------------------------------------
    -- Fly mode: hand the fall to the Fly module the instant there is no land under us.
    --
    -- Driven off Heartbeat and tested every single frame, with no barrier, no timer and no fall
    -- speed threshold in the way, so it engages on the first frame the ground is gone - that is
    -- what keeps the Y drop to a couple of studs. Fly is only switched back off if this mode is
    -- what switched it on, so it can never take control away from you.
    ----------------------------------------------------------------------------
    local flyOwned, landSince = false, 0

    local function flyModule()
        return Fly or vape.Modules.Fly
    end

    local function stopFly(force)
        local module = flyModule()
        if not module then
            flyOwned = false
            return
        end
        if flyOwned and (force or module.Enabled) then
            flyOwned = false
            if module.Enabled then
                task.spawn(function()
                    module:Toggle()
                end)
            end
        end
    end

    local function updateFlyMode()
        if Mode.Value ~= 'Fly' then
            stopFly(true)
            return
        end
        if not entitylib.isAlive then
            stopFly(true)
            return
        end
        local root = entitylib.character.RootPart
        local module = flyModule()
        if not root or not module then return end

        local grounded = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air
        -- Look a fraction of a second ahead so stepping off an edge counts as "no land" on the
        -- frame we leave it rather than a frame later.
        local land = grounded and root.Position.Y or landBelow(root, 0.25)

        if not land then
            landSince = 0
            if not module.Enabled then
                flyOwned = true
                -- Kill the drop we have already picked up before handing over, so Fly starts from
                -- a standstill instead of having to arrest a fall.
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
                task.spawn(function()
                    module:Toggle()
                end)
            elseif not flyOwned then
                -- Already flying by your own choice: leave it entirely alone.
                return
            end
            return
        end

        -- Land is back. Hold the release briefly so a one-frame reading over a gap does not drop
        -- us, and only release once we are genuinely above something we can stand on.
        if flyOwned then
            if landSince == 0 then
                landSince = tick()
            end
            local safeDrop = (FlyRelease and FlyRelease.Value or 12)
            if (tick() - landSince) >= 0.2 and (root.Position.Y - land) <= safeDrop then
                stopFly(false)
            end
        else
            landSince = 0
        end
    end

    AntiFall = vape.Categories.Blatant:CreateModule({
        Name = 'AntiVoid',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
                if not AntiFall.Enabled then return end

                clutchGeneration += 1
                flyOwned, landSince, clutchBusy = false, 0, false
                AntiFall:Clean(function()
                    stopFly(true)
                    clutchBusy = false
                    clutchGeneration += 1
                end)

                -- Fly mode owns the whole job itself, so it runs whether or not the map has a
                -- barrier height to work out.
                AntiFall:Clean(runService.Heartbeat:Connect(updateFlyMode))

                local pos, debounce = getLowGround(), tick()
                if pos ~= math.huge then
                    AntiFallPart = Instance.new('Part')
                    AntiFallPart.Size = Vector3.new(10000, 1, 10000)
                    AntiFallPart.Transparency = 1 - Color.Opacity
                    AntiFallPart.Material = Enum.Material[Material.Value]
                    AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                    AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
                    -- Clutch no longer collides with the barrier: the bridged blocks catch
                    -- the player, and a solid barrier would only stop them a moment before
                    -- (or on top of) the blocks and defeat the point of clutching.
                    AntiFallPart.CanCollide = Mode.Value == 'Collide'
                    AntiFallPart.Anchored = true
                    AntiFallPart.CanQuery = false
                    AntiFallPart.Parent = workspace
                    AntiFall:Clean(AntiFallPart)
                    AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
                        if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
                            debounce = tick() + 0.1
                            if Mode.Value == 'Normal' then
                                local top = getNearGround()
                                if top then
                                    local lastTeleport = lplr:GetAttribute('LastTeleported')
                                    local connection
                                    connection = runService.PreSimulation:Connect(function()
                                        if beingCarried() then
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                            return
                                        end

                                        if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
                                            local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
                                            local root = entitylib.character.RootPart
                                            AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
                                            root.Velocity *= Vector3.new(1, 0, 1)
                                            rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
                                            rayCheck.CollisionGroup = root.CollisionGroup

                                            local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
                                            if ray then
                                                for _ = 1, 10 do
                                                    local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
                                                    if not getPlacedBlock(dpos) then
                                                        top = dpos
                                                        break
                                                    end
                                                end
                                            end

                                            root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
                                            if not frictionTable.Speed then
                                                root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                            end

                                            if delta.Magnitude < 1 then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                            end
                                        else
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                        end
                                    end)
                                    AntiFall:Clean(connection)
                                end
                            elseif Mode.Value == 'Velocity' then
                                entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
                            elseif Mode.Value == 'Clutch' then
                                -- Last resort only. The predictive check below normally has us
                                -- caught long before the barrier is ever touched.
                                if not beingCarried() then
                                    task.spawn(clutch, nil, clutchGeneration)
                                end
                            end
                        end
                    end))
                end

                -- Clutch trigger. Fires on the first frame of a real void fall, while the island
                -- we just left is still next to us and its blocks can be built off, rather than
                -- waiting for the barrier by which time there is nothing in reach.
                AntiFall:Clean(runService.Heartbeat:Connect(function()
                    if Mode.Value ~= 'Clutch' or not entitylib.isAlive or clutchBusy then return end
                    if beingCarried() then return end
                    local root = entitylib.character.RootPart
                    if not root or not isnetworkowner(root) then return end
                    if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then return end
                    -- Start while the ledge is still nearby. A clutch is a placement problem,
                    -- not a barrier problem: once we are falling at -12, a normal sideways run
                    -- has already carried the player several cells beyond the island edge.
                    if root.AssemblyLinearVelocity.Y >= -2 then return end
                    -- And genuinely into the void: if there is anything at all to land on in the
                    -- column we are heading for, there is nothing to clutch. This single check is
                    -- what stops the false placing.
                    if landBelow(root, 0.45) then return end
                    local velocity = root.AssemblyLinearVelocity
                    -- Only a tiny horizontal lead is useful for a floor placed at our current
                    -- feet. It compensates for movement between the probe and request without
                    -- asking the server to place a block outside of clutch reach.
                    local time = math.clamp(0.08 + math.abs(velocity.Y) / workspace.Gravity * 0.12, 0.08, 0.18)
                    local predicted = root.Position + Vector3.new(velocity.X * time, 0, velocity.Z * time)
                    task.spawn(clutch, predicted, clutchGeneration)
                end))
            else
                AntiFallDirection = nil
                stopFly(true)
                clutchBusy = false
                clutchGeneration += 1
            end
        end,
        Tooltip = 'Helps prevent you from falling into the void'
    })
    Mode = AntiFall:CreateDropdown({
        Name = 'Move Mode',
        List = {'Normal', 'Collide', 'Velocity', 'Clutch', 'Fly'},
        Function = function(val)
            if AntiFallPart then
                -- Clutch stays non-colliding; only Collide mode walks on the barrier.
                AntiFallPart.CanCollide = val == 'Collide'
            end
            if val ~= 'Fly' then
                stopFly(true)
            end
            pcall(function()
                FlyRelease.Object.Visible = val == 'Fly'
                ClutchBlocks.Object.Visible = val == 'Clutch'
            end)
        end,
        Tooltip = 'Normal - slide to safety\nVelocity - launch up\nCollide - walk on it\nClutch - floor under you\nFly - fly over the void'
    })
    FlyRelease = AntiFall:CreateSlider({
        Name = 'Release height',
        Min = 3,
        Max = 60,
        Default = 12,
        Suffix = ' studs',
        Darker = true,
        Visible = false,
        Tooltip = 'How close above land Fly mode has to be before it hands control back'
    })
    ClutchBlocks = AntiFall:CreateSlider({
        Name = 'Clutch reach',
        Min = 1,
        Max = 10,
        Default = 6,
        Suffix = function(val)
            return val == 1 and ' block' or ' blocks'
        end,
        Darker = true,
        Visible = false,
        Tooltip = 'How far the clutch may build in from the nearest block it can lean on'
    })
    local materials = {'ForceField'}
    for _, v in Enum.Material:GetEnumItems() do
        if v.Name ~= 'ForceField' then
            table.insert(materials, v.Name)
        end
    end
    Material = AntiFall:CreateDropdown({
        Name = 'Material',
        List = materials,
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.Material = Enum.Material[val]
            end
        end
    })
    Color = AntiFall:CreateColorSlider({
        Name = 'Color',
        DefaultOpacity = 0.5,
        Function = function(h, s, v, o)
            if AntiFallPart then
                AntiFallPart.Color = Color3.fromHSV(h, s, v)
                AntiFallPart.Transparency = 1 - o
            end
        end
    })

end)