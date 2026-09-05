run(function()
    local AntiDeath
    local Targets
    local Melee
    local Projectiles
    local ProjectileStretch
    local Range

    -- oldchar is the character the parked root was taken OUT of. Reverting is only ever valid back
    -- into that same character: respawn while the root is parked and lplr.Character is a brand new
    -- model, and grafting the old root into it leaves the body being driven by a part nothing is
    -- welded to - which renders locally as a character frozen on the spot while you carry on moving
    -- normally everywhere else. See revertClone.
    local oldroot, oldchar, clone, hip = nil, nil, nil, 2.5
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Include
    rayParams.RespectCanCollide = true

    local function doClone()
        if store.rootpart then return end
        if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
            if oldroot and oldroot.Parent then
                return true
            end

            hip = entitylib.character.Humanoid.HipHeight
            oldroot = entitylib.character.HumanoidRootPart
            if not lplr.Character.Parent then return false end
            oldchar = lplr.Character
            lplr.Character.Parent = replicatedStorage
            clone = oldroot:Clone()
            clone.Parent = lplr.Character
            oldroot.Transparency = 1
            oldroot.Parent = workspace
            store.rootpart = oldroot
            lplr.Character.PrimaryPart = clone
            lplr.Character.Parent = workspace
            bedwars.QueryUtil:setQueryIgnored(clone, true)
            bedwars.QueryUtil:setQueryIgnored(oldroot, true)
            return true
        end
        return false
    end

    -- Nothing to give the root back to (died or respawned while it was parked). Bin the parts
    -- rather than leaving a stray root in workspace or a clone inside a dead character.
    local function dropClone()
        if oldroot then
            pcall(function() if oldroot.Parent == workspace then oldroot:Destroy() end end)
        end
        if clone then
            pcall(function() clone:Destroy() end)
        end
        if store.rootpart == oldroot then
            store.rootpart = nil
        end
        oldroot, oldchar, clone = nil, nil, nil
    end

    local projectileCache, projectileHistory = {}, {}

    -- BedWars projectiles replicate as Models parented directly to workspace, with the
    -- 'ProjectileShooter' attribute set on the model. Resolve the moving BasePart from either form.
    local function projectilePart(obj)
        return obj:IsA('BasePart') and obj or obj.PrimaryPart
    end

    local function isProjectile(obj)
        local shooter = obj:GetAttribute('ProjectileShooter')
        if shooter == nil or shooter == lplr.UserId then return false end
        return projectilePart(obj) ~= nil
    end

    -- Newly spawned projectiles often report a zero AssemblyLinearVelocity for a
    -- frame or two (they are server-simulated), which used to blind detection long
    -- enough to make the dodge fire late. We keep the last good velocity and fall
    -- back to a time-guarded finite difference so the estimate is stable from the
    -- first frame a projectile is in range.
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

    -- Returns the single soonest-to-hit threat (not merely the first found), so
    -- that when several projectiles are inbound we dodge the one about to land
    -- instead of an arbitrary one further away.
    --
    -- The closest-approach is evaluated along the projectile's *gravity-aware* arc
    -- rather than a straight line. A straight-line estimate reports a huge miss for
    -- an arcing arrow until it is almost on top of you, which is what made the dodge
    -- fire a frame or two after the hit already registered. Sampling the real
    -- parabola lets us see the threat while there is still time to move.
    -- Ballistic helpers ported from cv.lua's "Arrow Dodge" (AnticheatBypass).
    local function LaunchAngle(v, g, d, h, higherArc)
        local root = v * v * v * v - g * (g * d * d + 2 * h * v * v)
        if root < 0 then return nil end
        root = math.sqrt(root)
        local angle = higherArc and (v * v + root) or (v * v - root)
        return math.atan2(angle, g * d)
    end

    local function LaunchDirection(startPos, target, v, g, higherArc)
        local horizontal = Vector3.new(target.X - startPos.X, 0, target.Z - startPos.Z)
        local d = horizontal.Magnitude
        if d < 0.01 then return nil end
        local a = LaunchAngle(v, g, d, target.Y - startPos.Y, higherArc)
        if a == nil or a ~= a then return nil end
        local vec = horizontal.Unit * v
        local rotAxis = Vector3.new(-horizontal.Z, 0, horizontal.X)
        return CFrame.fromAxisAngle(rotAxis, a) * vec
    end

    local function FindLeadShot(targetPosition, targetVelocity, projectileSpeed, shooterPosition, shooterVelocity, gravity)
        local distance = (targetPosition - shooterPosition).Magnitude
        local vrel = targetVelocity - shooterVelocity
        local timeTaken = distance / projectileSpeed
        if gravity > 0 then
            timeTaken = projectileSpeed / gravity + math.sqrt(2 * distance / gravity + projectileSpeed ^ 2 / gravity ^ 2)
        end
        return Vector3.new(
            targetPosition.X + vrel.X * timeTaken,
            targetPosition.Y + vrel.Y * timeTaken,
            targetPosition.Z + vrel.Z * timeTaken
        )
    end

    -- Projectile detection replaced with Arrow Dodge logic: a projectile counts as a threat
    -- when its actual velocity matches the velocity that would be required to hit us from its
    -- position (i.e. it is genuinely aimed at us), rather than the old closest-approach arc
    -- heuristic. Returns the same {Object, Part, TimeToHit, Velocity} shape the dodge relies on.
    local function incomingProjectile(root)
        local best, bestTime = false, math.huge
        local rootPos = root.Position
        local aimPos = rootPos + Vector3.new(0, 0.8, 0)
        local range = math.max(Range.Value, 70)
        for obj in projectileCache do
            local part = obj.Parent and projectilePart(obj)
            if not part then
                projectileCache[obj] = nil
                projectileHistory[obj] = nil
                continue
            end
            local origin = part.Position
            local dist = (origin - rootPos).Magnitude
            if dist <= range then
                local velocity = getProjectileVelocity(obj, part)
                local speed = velocity.Magnitude
                if speed > 2 and velocity:Dot((rootPos - origin).Unit) > 0 then
                    local meta = bedwars.ProjectileMeta[obj.Name]
                    local grav = meta and meta.gravitationalAcceleration or workspace.Gravity
                    -- Velocity the projectile would need to land on us from where it is now.
                    local lead = FindLeadShot(aimPos, Vector3.zero, speed, origin, Vector3.zero, grav)
                    local arc = LaunchDirection(origin, aimPos, speed, grav, false)
                    local flat = (lead - origin)
                    if flat.Magnitude > 0 then
                        flat = flat.Unit * speed
                        local requiredVelo = Vector3.new(flat.X, arc and arc.Y or flat.Y, flat.Z)
                        if requiredVelo.Magnitude > 0 then
                            requiredVelo = requiredVelo.Unit * speed
                            -- Within Arrow Dodge's 20-stud tolerance -> it is aimed at us.
                            if (requiredVelo - velocity).Magnitude <= 20 then
                                local timeToHit = dist / speed
                                if timeToHit < bestTime then
                                    best = {Object = obj, Part = part, TimeToHit = timeToHit, Velocity = velocity}
                                    bestTime = timeToHit
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    -- Note: during a dodge the character's real RootPart is parked below the
    -- map, so callers must pass the *visible* body (the clone) here - measuring
    -- against the hidden root made this test see every falling projectile as
    -- "still approaching" and hold the dodge for the full timeout.
    local function hasProjectilePassed(threat, body)
        local obj = threat and threat.Object
        local part = threat and threat.Part
        if not obj or not part or not part.Parent or not body then return true end
        local velocity = getProjectileVelocity(obj, part)
        if velocity.Magnitude <= 2 then return true end
        local toLocal = body.Position - part.Position
        return velocity:Dot(toLocal) <= 0 or toLocal.Magnitude > math.max(Range.Value, 70)
    end

    local function revertClone()
        if not oldroot then return false end
        -- Only ever back into the character it came out of. A respawn during the dodge replaces
        -- lplr.Character wholesale; putting a stale root into the new one - and making it the
        -- PrimaryPart - is what leaves your body rendered frozen in place client-side while you
        -- keep moving around normally.
        if oldchar ~= lplr.Character or not oldchar or not oldchar.Parent or not oldroot.Parent or not entitylib.isAlive then
            dropClone()
            return false
        end
        lplr.Character.Parent = replicatedStorage
        oldroot.Parent = lplr.Character
        if clone then
            oldroot.CFrame = clone.CFrame
            oldroot.Velocity = clone.Velocity
            clone:Destroy()
            clone = nil
        end
        lplr.Character.PrimaryPart = oldroot
        lplr.Character.Parent = workspace
        oldroot.CanCollide = true
        entitylib.character.Humanoid.HipHeight = hip or 2.6
        oldroot.Transparency = 1
        oldroot, oldchar = nil, nil
        store.rootpart = nil
        return true
    end

    AntiDeath = vape.Categories.Blatant:CreateModule({
	Name = 'AntiDeath',
	Tooltip = 'Dodges melee and projectiles "blatantly"',
	Function = function(call)
		if call then
			repeat
				task.wait()
			until store.matchState ~= 0 and store.map or not AntiDeath.Enabled
			if not AntiDeath.Enabled then
				return
			end

			table.clear(projectileCache)
			table.clear(projectileHistory)
			for _, obj in workspace:GetChildren() do
				if isProjectile(obj) then projectileCache[obj] = true end
			end
			AntiDeath:Clean(workspace.ChildAdded:Connect(function(obj)
				task.delay(0, function()
					if obj.Parent and isProjectile(obj) then projectileCache[obj] = true end
				end)
			end))

			rayParams.FilterDescendantsInstances = {store.map}
			local lowestpoint = 9e9
			local Dodge = false
			for _, v in store.blocks do
				local point = (v.Position.Y - (v.Size.Y / 2)) - 50
				if point < lowestpoint then
					lowestpoint = point
				end
			end

                AntiDeath:Clean(runService.PostSimulation:Connect(function()
                    if oldroot and oldroot.Parent then
                        local newpoint, pos = lowestpoint, CFrame.new(clone.CFrame.X, lowestpoint - 6, clone.CFrame.Z)
                        if Dodge then
                            newpoint = workspace:Raycast(pos.Position, Vector3.new(0, 1000, 0), rayParams)
                            if newpoint then
                                newpoint = CFrame.new(clone.CFrame.X, newpoint.Position.Y - 6, clone.CFrame.Z) * CFrame.Angles(math.rad(90), 0, 0)
                            end
                        end
                        oldroot.Velocity = Vector3.zero
                        oldroot.CFrame = Dodge and (newpoint or pos) or (clone.CFrame + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(90), 0, 0)
                    end
                end))

                local last = true
                repeat
                    if entitylib.isAlive then
                        if oldroot then
                            local ownership = isnetworkowner(oldroot)
                            if not ownership and ownership ~= last then
                                notif('AntiDeath', 'Network ownership disowned', 7, 'alert')
                            end
                            last = ownership
                            if not ownership then
                                Dodge = false
                                revertClone()
                                task.wait()
                                continue
                            end
                        end

                        local projectileThreat = Projectiles.Enabled and incomingProjectile(entitylib.character.RootPart)
                        -- Fire earlier than the raw stretch window to cover reaction latency plus the
                        -- full network round-trip: the hitbox move has to replicate to the server before
                        -- it counts, so dodging only half a ping early still landed a touch late on fast
                        -- projectiles. Moving the hidden hitbox away early is harmless, so we bias early.
                        -- The hidden hitbox move has to replicate a full round trip to the
                        -- server before the projectile's hit is resolved there, so half a ping
                        -- of lead was not enough on fast arrows - the dodge played but the hit
                        -- still registered. Bias earlier by a fuller round trip (moving the
                        -- hidden hitbox early is harmless).
                        local reactionBuffer = math.min(lplr:GetNetworkPing() * 1.6 + 0.1, 0.6)
                        if projectileThreat and projectileThreat.TimeToHit > ProjectileStretch.Value + reactionBuffer then
                            projectileThreat = nil
                        end
                        local root = entitylib.character.RootPart
                        local grounded = root and workspace:Raycast(root.Position, Vector3.new(0, -(entitylib.character.HipHeight + 4), 0), store.blockRaycast)
                        local meleeThreat = Melee.Enabled and grounded and math.abs(root.AssemblyLinearVelocity.Y) < 35 and entitylib.EntityPosition({
                            Range = Range.Value,
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                            Wallcheck = Targets.Walls.Enabled or nil,
                            Sort = sortmethods.Distance,
                            Part = 'RootPart',
                        })
                        if (projectileThreat or meleeThreat) and doClone() then
                            if projectileThreat then
                                Dodge = true
                                local started = tick()
                                repeat
                                    task.wait()
                                until hasProjectilePassed(projectileThreat, clone or entitylib.character.RootPart) or tick() - started > 1.35 or not AntiDeath.Enabled
                            else
                                Dodge = false
                                task.wait(0.2)
                                local root = entitylib.character.RootPart
                                local grounded = root and workspace:Raycast(root.Position, Vector3.new(0, -(entitylib.character.HipHeight + 4), 0), store.blockRaycast)
                                Dodge = grounded and math.abs(root.AssemblyLinearVelocity.Y) < 35
                                task.wait(0.4)
                            end
                        else
                            Dodge = false
                            revertClone()
                        end
                    elseif oldroot then
                        -- Died with the hitbox parked. Nothing to hand it back to, so bin it here
                        -- rather than leaving it to be inherited by the character we respawn into.
                        Dodge = false
                        dropClone()
                    end
                    task.wait()
                until not AntiDeath.Enabled
		else
			revertClone()
		end
	end,
    })

    Targets = AntiDeath:CreateTargets({
	Players = true,
	NPCs = false,
    })
    Melee = AntiDeath:CreateToggle({
	Name = 'Melee',
	Tooltip = 'Dodges melee attacks',
	Default = true,
	Function = function(call)
		pcall(function()
			Range.Object.Visible = call
		end)
	end,
    })
    Range = AntiDeath:CreateSlider({
	Name = 'Melee Range',
	Min = 1,
	Max = 30,
	Default = 30,
	Decimal = 5,
	Darker = true,
    })
    Projectiles = AntiDeath:CreateToggle({
	Name = 'Projectiles',
	Tooltip = 'Triggers AntiDeath when an incoming projectile is detected',
	Default = true,
	Function = function(call)
		pcall(function()
			ProjectileStretch.Object.Visible = call
		end)
	end,
    })
    ProjectileStretch = AntiDeath:CreateSlider({
	Name = 'Projectile Stretch Time',
	Tooltip = 'How soon before impact projectile dodging can trigger',
	Min = 0.05,
	Max = 1.5,
	Default = 0.55,
	Decimal = 2,
	Darker = true,
    })
end)