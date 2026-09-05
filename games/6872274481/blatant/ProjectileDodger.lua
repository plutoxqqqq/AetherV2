run(function()
    local ProjectileDodger
    local Range
    local Strength
    local Mode
    local TeleportDistance
    local EdgeCheck
    local projectiles = {}
    local projectileHistory = {}
    local dodgedProjectiles = {}
    local dodgeUntil, dodgeDirection = 0, Vector3.zero
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true

    -- Projectiles replicate as Models parented directly to workspace, tagged with 'ProjectileShooter'.
    local function projectilePart(obj)
        return obj:IsA('BasePart') and obj or obj.PrimaryPart
    end

    local function isProjectile(obj)
        local shooter = obj:GetAttribute('ProjectileShooter')
        if shooter == nil or shooter == lplr.UserId then return false end
        return projectilePart(obj) ~= nil
    end

    -- Keep the last good velocity so freshly spawned projectiles (which report a
    -- zero AssemblyLinearVelocity for a frame or two) are still dodged in time.
    local function getProjectileVelocity(obj, part)
        local now = os.clock()
        local history = projectileHistory[obj]
        local assembly = part.AssemblyLinearVelocity
        local velocity
        if assembly.Magnitude > 1 then
            velocity = assembly
        elseif history and (now - history.Time) > 1e-4 then
            velocity = (part.Position - history.Position) / (now - history.Time)
        end
        if (not velocity or velocity.Magnitude <= 2) and history and history.Velocity then
            velocity = history.Velocity
        end
        velocity = velocity or Vector3.zero
        projectileHistory[obj] = {Position = part.Position, Time = now, Velocity = velocity.Magnitude > 2 and velocity or (history and history.Velocity)}
        return velocity
    end

    local function safeDirection(root, dir)
        if dir ~= dir or dir.Magnitude <= 0 then
            dir = root.CFrame.RightVector
        end
        dir = Vector3.new(dir.X, 0, dir.Z)
        dir = dir.Magnitude > 0 and dir.Unit or root.CFrame.RightVector
        if not EdgeCheck.Enabled then return dir end
        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
        local rightSafe = workspace:Raycast(root.Position + (dir * 6), Vector3.new(0, -16, 0), rayCheck)
        if rightSafe then return dir end
        local left = -dir
        local leftSafe = workspace:Raycast(root.Position + (left * 6), Vector3.new(0, -16, 0), rayCheck)
        return leftSafe and left or dir
    end

    local function teleportDodge(root, side)
        local distance = TeleportDistance.Value * 3 -- slider is in blocks; BedWars blocks are 3 studs
        local options = {side, -side}
        for _, direction in options do
            local target = root.Position + (direction * distance)
            if not EdgeCheck.Enabled or workspace:Raycast(target + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), rayCheck) then
                root.CFrame = CFrame.new(target, target + root.CFrame.LookVector)
                root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                return true
            end
        end
        return false
    end

    -- Evaluates the threat along the projectile's real (gravity-aware) arc. A straight-line
    -- closest-approach reports a large miss for an arcing arrow until it is nearly on top of
    -- you, which is what made the sidestep fire too late; sampling the parabola catches it
    -- with time to spare.
    local function incomingDirection(obj, root, range)
        local part = obj.Parent and projectilePart(obj)
        if not part then return end
        local origin = part.Position
        local rootPos = root.Position
        if (origin - rootPos).Magnitude > math.max(range, 70) then return end
        local velocity = getProjectileVelocity(obj, part)
        if velocity.Magnitude < 2 then return end
        local toLocal = rootPos - origin
        if toLocal.Magnitude <= 0 then return end
        local closingSpeed = velocity:Dot(toLocal.Unit)
        if closingSpeed <= 0 then return end

        local meta = bedwars.ProjectileMeta[obj.Name]
        local grav = meta and meta.gravitationalAcceleration or workspace.Gravity
        local horizon = math.clamp((toLocal.Magnitude / closingSpeed) * 1.3, 0.05, 1.4)
        local miss, timeToHit = math.huge, horizon
        for i = 0, 16 do
            local t = horizon * i / 16
            local pos = origin + velocity * t - Vector3.new(0, 0.5 * grav * t * t, 0)
            local d = (pos - rootPos).Magnitude
            if d < miss then
                miss = d
                timeToHit = t
            end
        end
        if miss < 12 then
            return safeDirection(root, velocity.Unit:Cross(Vector3.yAxis)), timeToHit
        end
    end

    ProjectileDodger = vape.Categories.Blatant:CreateModule({
        Name = 'ProjectileDodger',
        Function = function(callback)
            if callback then
                table.clear(projectiles)
                table.clear(projectileHistory)
                table.clear(dodgedProjectiles)
                for _, obj in workspace:GetChildren() do
                    if isProjectile(obj) then projectiles[obj] = true end
                end
                ProjectileDodger:Clean(workspace.ChildAdded:Connect(function(obj)
                    task.delay(0, function()
                        if obj.Parent and isProjectile(obj) then projectiles[obj] = true end
                    end)
                end))

                -- Legit mode moves the real hitbox with a smooth, frame-rate-independent CFrame
                -- nudge every physics step. Setting AssemblyLinearVelocity alone does nothing here
                -- because the Humanoid movement controller overwrites it each step, which is why
                -- Legit mode previously appeared to do nothing at all.
                ProjectileDodger:Clean(runService.PostSimulation:Connect(function(dt)
                    if Mode.Value ~= 'Legit' or tick() >= dodgeUntil or dodgeDirection.Magnitude <= 0 then return end
                    if not entitylib.isAlive then return end
                    local root = entitylib.character.RootPart
                    if not root then return end
                    -- CFrame stepping only: also writing a full-strength velocity each
                    -- frame fought the humanoid controller and doubled the effective
                    -- speed, which is what made the sidestep overshoot and rubber-band.
                    local step = math.clamp(Strength.Value, 10, 80) * dt
                    local delta = Vector3.new(dodgeDirection.X * step, 0, dodgeDirection.Z * step)
                    -- Per-frame edge guard. The one-shot check at commit time only
                    -- probed 6 studs out, so a long Legit slide kept moving past the
                    -- last ground and walked the player off the edge even with Edge
                    -- Check on. Re-probe the ground directly beneath the *next*
                    -- position every frame and stop the slide the moment it would
                    -- leave a supported block.
                    if EdgeCheck.Enabled then
                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                        local nextPos = root.Position + delta
                        if not workspace:Raycast(nextPos + Vector3.new(0, 2, 0), Vector3.new(0, -(entitylib.character.HipHeight + 5), 0), rayCheck) then
                            dodgeUntil = 0
                            return
                        end
                    end
                    root.CFrame = root.CFrame + delta
                end))

                repeat
                    if entitylib.isAlive then
                        local root = entitylib.character.RootPart
                        -- While a dodge is in progress just wait it out; the PostSimulation stepper
                        -- above carries out the Legit movement, and Teleport already fired instantly.
                        if tick() >= dodgeUntil then
                            local best, bestTime, bestObj = nil, math.huge, nil
                            for obj in projectiles do
                                if not obj.Parent then
                                    projectiles[obj] = nil
                                    projectileHistory[obj] = nil
                                    continue
                                end
                                local side, timeToHit = incomingDirection(obj, root, Range.Value)
                                if side and (timeToHit or 1.25) < bestTime and (not dodgedProjectiles[obj] or tick() - dodgedProjectiles[obj] > 1.5) then
                                    best, bestTime, bestObj = side, timeToHit or 1.25, obj
                                end
                            end
                            -- Only commit once the hit is imminent. Dodging the moment a
                            -- threat appears (sometimes >1s early) let the player drift
                            -- back into the arc while the per-projectile lockout blocked a
                            -- second dodge - the main source of "dodged but still got hit".
                            local ping = 0
                            pcall(function() ping = lplr:GetNetworkPing() end)
                            -- Teleport is instant and can't overshoot back into the arc, so it
                            -- commits earlier and covers a fuller round-trip than the Legit slide.
                            -- Reacting too late here was what let fast arrows land in TP mode.
                            local reactionWindow = Mode.Value == 'Teleport'
                                and math.min(ping * 1.4 + 0.45, 0.9)
                                or math.min(ping + 0.45, 0.6)
                            if best and bestTime <= reactionWindow then
                                dodgeDirection = best
                                if Mode.Value == 'Teleport' then
                                    -- Only flag the projectile as handled once the teleport actually
                                    -- fires. Previously it was flagged unconditionally, so a blocked
                                    -- teleport (edge check) locked the arrow out for 1.5s and let it hit.
                                    if teleportDodge(root, best) then
                                        dodgedProjectiles[bestObj] = tick()
                                        -- brief lockout so a burst of arrows can't chain-teleport the player away
                                        dodgeUntil = tick() + math.clamp(bestTime, 0.12, 0.35)
                                    end
                                else
                                    dodgedProjectiles[bestObj] = tick()
                                    dodgeUntil = tick() + math.clamp(bestTime + 0.15, 0.25, 0.6)
                                end
                            end
                        end
                    end
                    task.wait()
                until not ProjectileDodger.Enabled
            else
                table.clear(projectiles)
                table.clear(projectileHistory)
                table.clear(dodgedProjectiles)
                dodgeUntil = 0
                dodgeDirection = Vector3.zero
            end
        end,
        Tooltip = 'Dodges incoming projectiles without stepping off edges'
    })
    Range = ProjectileDodger:CreateSlider({Name = 'Range', Min = 10, Max = 80, Default = 45, Suffix = 'studs'})
    Mode = ProjectileDodger:CreateDropdown({Name = 'Mode', List = {'Teleport', 'Legit'}, Default = 'Teleport', Function = function(val)
        pcall(function()
            TeleportDistance.Object.Visible = val == 'Teleport'
            Strength.Object.Visible = val == 'Legit'
        end)
    end})
    TeleportDistance = ProjectileDodger:CreateSlider({Name = 'Teleport Distance', Min = 1, Max = 2, Default = 2, Decimal = 1, Suffix = ' blocks'})
    Strength = ProjectileDodger:CreateSlider({Name = 'Dodge Strength', Min = 10, Max = 80, Default = 38, Suffix = 'studs', Visible = false})
    EdgeCheck = ProjectileDodger:CreateToggle({Name = 'Edge Check', Default = true})
end)