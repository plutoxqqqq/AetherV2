run(function()
    local NoFall
    local Mode
    local MinVelocity
    local FallThreshold
    local SpoofState
    local GroundDistance
    local AnchorAttempts
    local BlockClutch
    local TelepearlClutch
    local DaoClutch
    local JadeHammerClutch
    local VoidAxeClutch
    local HealthCheck
    local DamagePercent
    local CvDamage
    local Zephyr
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    -- Deliberately left on the default collision group - see groundBelow.
    local plainCheck = RaycastParams.new()
    plainCheck.RespectCanCollide = true
    plainCheck.FilterType = Enum.RaycastFilterType.Exclude
    local lastAnchor = 0
    local usedPearl = false
    local lastLegitUse = 0
    local clutchBusyUntil = 0
    local lastBlockPlace = 0
    local lastZephyrJump = 0
    local fallAnchorY
    local projectileRemote = {InvokeServer = function() end}
    task.spawn(function()
        projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local daoItems = {'wood_dao', 'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'}

    local function validCharacter()
        if not entitylib.isAlive then return end
        local character = entitylib.character
        local root = character.RootPart or character.HumanoidRootPart
        local humanoid = character.Humanoid
        if root and humanoid and humanoid.Health > 0 then
            return character, root, humanoid
        end
    end

    local function updateRay(root)
        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
        rayCheck.CollisionGroup = root.CollisionGroup
    end

    local function getGround(root, character, distance)
        updateRay(root)
        local hipHeight = character.HipHeight or (character.Humanoid and character.Humanoid.HipHeight) or 2
        local castDistance = -(distance + hipHeight + (root.Size.Y * 0.5))
        return workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, castDistance, 0), rayCheck)
    end

    -- Height of the floor below us, by three independent methods.
    --
    -- A cast that comes back empty is the single failure that stops TP mode dead: with no floor
    -- to aim at it does nothing at all, which is exactly what "TP doesn't teleport" looks like
    -- from the outside. So an empty result is never taken at face value here.
    --
    --   1. The box cast, tolerant of thin blocks and of ledges a thin ray slips past. This is the
    --      shipped script's own method, on the character's collision group.
    --   2. A plain long ray on the DEFAULT collision group. If the character sits in a group that
    --      does not collide with the map, (1) passes straight through the world and finds nothing
    --      while this still sees it.
    --   3. The block engine's own store, walked cell by cell down the column we are over. On a
    --      BedWars map the floor is nearly always a placed block, and a data lookup cannot be
    --      defeated by a collision group, a CanQuery flag or a filter at all.
    local function groundBelow(root, character)
        local ground = getGround(root, character, 1500)
        if ground then return ground.Position.Y end

        plainCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
        local ray = workspace:Raycast(root.Position, Vector3.new(0, -3000, 0), plainCheck)
        if ray then return ray.Position.Y end

        local success, blockY = pcall(function()
            local origin = root.Position
            for step = 1, 200 do
                local below = Vector3.new(origin.X, origin.Y - (step * 3), origin.Z)
                if getPlacedBlock(below) then
                    -- Top face of the block we found, which is what we would stand on.
                    return (bedwars.BlockController:getBlockPosition(below).Y * 3) + 1.5
                end
            end
            return nil
        end)
        return success and blockY or nil
    end

    -- The distance from the root's centre down to the floor we stand on. entitylib already folds
    -- half the root part into HipHeight, so adding it again (as this used to) put every floor
    -- estimate a stud out.
    local function standClearance(root, character)
        local humanoid = character.Humanoid
        return character.HipHeight or ((humanoid and humanoid.HipHeight or 2) + (root.Size.Y * 0.5))
    end

    -- The fall that has built up: the fastest we have been moving downwards since we were last on
    -- the ground. This, not the speed at any one instant, is what a fall is worth - a drop that
    -- has already reached 200 studs a second is a lethal fall even on the frame it happens to be
    -- reading -3 because it clipped something. Every mode below decides off this one number.
    local trackedFall = 0

    local function updateTrackedFall(root, humanoid)
        if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            trackedFall = 0
        else
            trackedFall = math.min(trackedFall, root.AssemblyLinearVelocity.Y)
        end
        return trackedFall
    end

    -- TP mode. BedWars charges for the landing you report, so the way to clear a long drop is to
    -- end it early: cast straight down, put the character on the floor it was heading for anyway
    -- and take the touchdown there with no speed left on it.
    --
    -- The old version teleported down for a couple of frames and then teleported back UP to
    -- "resume" the fall from where it would have got to. Moving upwards that fast is exactly what
    -- the server's movement check rejects, so every touch was rubber-banded straight back to
    -- where it started and the mode looked like it never teleported at all. A drop to the ground
    -- is a move the server is already expecting, so this one lands.
	local clearRegisteredFall
	local function tpNoFall(root, character)
        local groundY = groundBelow(root, character)
        if not groundY then return false end

        local floorY = groundY + standClearance(root, character)
        local drop = root.Position.Y - floorY
        -- Below the floor we found (inside a block, or it read a ceiling): leave it alone.
        if drop <= 1 then return false end

        local velocity = root.AssemblyLinearVelocity
		local landed = root.CFrame - Vector3.new(0, drop, 0)
		-- Pivot the complete character, not only its root. Moving a single part can
		-- be overwritten by the humanoid assembly before replication sees it.
		character:PivotTo(landed)
        -- Keep the horizontal travel so the landing spot is the one the fall was heading for,
        -- and arrive with nothing vertical left for the game to charge for. Dropping to the
        -- floor is a move the server is already expecting from someone who is falling, which is
        -- why this replicates where the old build's teleport back UP was always rejected.
        root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
        -- The fall is over as far as we are concerned. Without this the next pass would still be
        -- holding the old speed and would fire again before the humanoid has registered the
        -- landing, which is what turns one teleport into a burst of them.
		trackedFall = 0
		clearRegisteredFall(-1)
		return true
    end

    local function restoreTool(oldTool)
        if oldTool and oldTool.tool then
            task.delay(0.18, function()
                switchItem(oldTool.tool)
                local oldHotbar = getHotbar(oldTool.tool)
                if oldHotbar then hotbarSwitch(oldHotbar) end
            end)
        end
    end

    local function firePearl(root, spot, pearl)
        if usedPearl or not pearl or not projectileRemote or not projectileRemote.InvokeServer then return end
        local meta = bedwars.ProjectileMeta.telepearl
        if not meta then return end

        local calc = prediction.SolveTrajectory(root.Position, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
        if not calc then return end

        local oldTool = store.hand
        local hotbar = getHotbar(pearl.tool)
        switchItem(pearl.tool, 0.1)
        if hotbar then hotbarSwitch(hotbar) end
        task.wait(0.03)

        local direction = CFrame.lookAt(root.Position, calc).LookVector * meta.launchVelocity
        local success = pcall(function()
            bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', root.Position, nil, direction, {drawDurationSeconds = 1})
            projectileRemote:InvokeServer(pearl.tool, 'telepearl', 'telepearl', root.Position, root.Position, direction, httpService:GenerateGUID(true), {
                drawDurationSeconds = 1,
                shotId = httpService:GenerateGUID(false)
            }, workspace:GetServerTimeNow() - 0.045)
        end)
        restoreTool(oldTool)
        if success then
            usedPearl = true
            return true
        end
    end

    local function blockClutch(root)
        if tick() - lastBlockPlace < 0.08 then return end
        local wool, amount = getWool()
        if not wool or (amount or 0) < 1 then return end

        lastBlockPlace = tick()
        local placePosition = bedwars.BlockController:getBlockPosition(root.Position - Vector3.new(0, 4, 0)) * 3
        fallAnchorY = root.Position.Y
        if not getPlacedBlock(placePosition) and bedwars.placeBlock(placePosition, wool) then
            return true
        end
    end

    local function isFallFatal(root, humanoid, ground)
        if not HealthCheck or not HealthCheck.Enabled then return true end
        if not ground then return true end

        local health = (lplr.Character and lplr.Character:GetAttribute('Health')) or humanoid.Health
        local fallBlocks = math.max(0, ((fallAnchorY or root.Position.Y) - ground.Position.Y) / 3)
        local estimatedDamage = math.max(0, fallBlocks - 6) * 5
        return estimatedDamage >= (health * ((DamagePercent and DamagePercent.Value or 100) / 100))
    end

    local function abilityClutch(item, ability, callback)
        if not item then return end
        local oldTool = store.hand
        local hotbar = getHotbar(item.tool)
        switchItem(item.tool, 0.1)
        if hotbar then hotbarSwitch(hotbar) end
        task.wait(0.05)
        callback(item, ability)
        restoreTool(oldTool)
        return true
    end

    local function useToolAbility(ability, data)
        local success, result = pcall(function()
            return bedwars.AbilityController:useAbility(ability, newproxy(true), data)
        end)
        if success and result ~= false then return true end

        success, result = pcall(function()
            return bedwars.AbilityController:useAbility(ability, data)
        end)
        if success and result ~= false then return true end

        pcall(function()
            bedwars.Client:Get(remotes.UseAbility).instance:FireServer(ability, data)
        end)
        return true
    end

    local function jadeClutch(root)
        local item
        for _, hammer in jadeHammerNames do
            item = getItem(hammer)
            if item then break end
        end
        if not item then return end
        local ability = item.itemType..'_jump'
        if bedwars.AbilityController:canUseAbility(ability) then
            return abilityClutch(item, ability, function(_, abilityId)
                useToolAbility(abilityId, {direction = Vector3.yAxis, origin = root.Position})
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, math.max(root.AssemblyLinearVelocity.Y, -3), root.AssemblyLinearVelocity.Z)
            end)
        end
    end

    local function voidClutch(root)
        local item = getItem('void_axe')
        if not item then return end
        local ability = item.itemType..'_jump'
        if bedwars.AbilityController:canUseAbility(ability) then
            return abilityClutch(item, ability, function(_, abilityId)
                useToolAbility(abilityId, {direction = Vector3.yAxis, origin = root.Position})
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, math.max(root.AssemblyLinearVelocity.Y, -3), root.AssemblyLinearVelocity.Z)
            end)
        end
    end

    local function daoClutch(root)
        for _, itemName in daoItems do
            local item = getItem(itemName)
            if item and (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') then
                return abilityClutch(item, 'dash', function(dao)
                    bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                    replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
                        direction = Vector3.new(root.CFrame.LookVector.X, -0.05, root.CFrame.LookVector.Z).Unit,
                        origin = root.Position,
                        weapon = dao.itemType
                    })
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, math.max(root.AssemblyLinearVelocity.Y, -3), root.AssemblyLinearVelocity.Z)
                end)
            end
        end
    end

    local function toolClutch(root)
        if DaoClutch and DaoClutch.Enabled and daoClutch(root) then return true end
        if JadeHammerClutch and JadeHammerClutch.Enabled and jadeClutch(root) then return true end
        if VoidAxeClutch and VoidAxeClutch.Enabled and voidClutch(root) then return true end
    end

    local function shouldToolClutch(root, humanoid, groundDistance)
        if not groundDistance or groundDistance == math.huge then return false end
        local verticalSpeed = math.abs(root.AssemblyLinearVelocity.Y)
        if verticalSpeed <= 0 then return false end

        local bodyClearance = (humanoid.HipHeight or 2) + (root.Size.Y * 0.5)
        local remainingDistance = math.max(0, groundDistance - bodyClearance)
        return remainingDistance <= 4.5 or (remainingDistance / verticalSpeed) <= 0.16
    end

    local function telepearlClutch(root, ground, groundDistance)
        if usedPearl or not TelepearlClutch or not TelepearlClutch.Enabled then return end
        local pearl = getItem('telepearl')
        return pearl and ground and firePearl(root, ground.Position + Vector3.new(0, 3, 0), pearl)
    end

    local function legitClutch(root, humanoid, ground)
        local now = tick()
        if now < clutchBusyUntil or now - lastLegitUse < 0.06 then return end
        if humanoid.FloorMaterial ~= Enum.Material.Air or root.AssemblyLinearVelocity.Y >= 0 then
            fallAnchorY = root.Position.Y
            return
        end

        local groundDistance = ground and (root.Position.Y - ground.Position.Y) or math.huge
        fallAnchorY = fallAnchorY or root.Position.Y
        lastLegitUse = now

        if not isFallFatal(root, humanoid, ground) then return end

        if BlockClutch and BlockClutch.Enabled and groundDistance > 21 and (fallAnchorY - root.Position.Y) >= 15 then
            if blockClutch(root) then
                clutchBusyUntil = tick() + 0.08
                return true
            end
        end

        if root.AssemblyLinearVelocity.Y > -(MinVelocity and MinVelocity.Value or 60) then return end

        if TelepearlClutch and TelepearlClutch.Enabled and telepearlClutch(root, ground, groundDistance) then
            clutchBusyUntil = tick() + 0.65
            return true
        end

        if ground and shouldToolClutch(root, humanoid, groundDistance) and toolClutch(root) then
            clutchBusyUntil = tick() + 0.65
            return true
        end
    end

    -- Best-effort Zephyr kit detection. This is never a hard requirement: it
    -- returns true/false when the kit can be read and nil when it cannot, so
    -- callers can treat "unknown" as "go ahead anyway" and never break.
    local function hasZephyrKit()
        local success, result = pcall(function()
            local kit = store.equippedKit
            if kit == nil or kit == '' then
                kit = lplr:GetAttribute('PlayingAsKit')
            end
            if kit == nil then return nil end
            -- The Zephyr kit is internally named "WindWalker" (bedwars.WindWalkerController),
            -- so matching only the string 'zephyr' failed for everyone actually using the kit
            -- and made this clutch never fire. Accept both names.
            local name = string.lower(tostring(kit))
            return name:find('zephyr') ~= nil or name:find('wind') ~= nil
        end)
        if not success then return nil end
        return result
    end

    local zephyrFired = false
    local function zephyrClutch(root, humanoid, ground)
        local now = tick()
        if humanoid.FloorMaterial ~= Enum.Material.Air or root.AssemblyLinearVelocity.Y >= 0 then
            fallAnchorY = root.Position.Y
            zephyrFired = false
            return
        end

        fallAnchorY = fallAnchorY or root.Position.Y
        -- Fire at most once per fall; retriggering while the Jump flag is still
        -- latched is what caused the extra, unwanted hops after landing.
        if zephyrFired or now - lastZephyrJump < 0.3 then return end
        if not ground or not isFallFatal(root, humanoid, ground) then return end

        -- Detection is a soft gate only: skip the jump when we positively know
        -- the wrong kit is equipped, but proceed on failure or an unknown kit.
        if hasZephyrKit() == false then return end

        local groundDistance = root.Position.Y - ground.Position.Y
        local bodyClearance = (humanoid.HipHeight or 2) + (root.Size.Y * 0.5)
        local remainingDistance = math.max(0, groundDistance - bodyClearance)
        local verticalSpeed = math.abs(root.AssemblyLinearVelocity.Y)

        -- Short falls never deal damage in BedWars (~6 blocks of grace), so a
        -- jump there is pure noise even though isFallFatal passes with the
        -- health check disabled. Require a fall that can actually hurt.
        local totalFall = math.max(fallAnchorY - root.Position.Y, 0) + remainingDistance
        if totalFall < 20 then return end

        -- Jump the instant before ground contact so the fall resets on landing.
        if remainingDistance <= 3.5 or (verticalSpeed > 0 and (remainingDistance / verticalSpeed) <= 0.09) then
            lastZephyrJump = now
            zephyrFired = true
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                humanoid.Jump = true
            end)
            -- Release the latched Jump flag so the humanoid does not queue a
            -- second, unwanted jump for the frame after it lands.
            task.delay(0.2, function()
                pcall(function()
                    if humanoid.Parent then
                        humanoid.Jump = false
                    end
                end)
            end)
            return true
        end
    end

    local function anchorClutch(root)
        local attempts = AnchorAttempts and AnchorAttempts.Value or 5
        if tick() - lastAnchor < (1 / math.max(attempts, 1)) then return end
        lastAnchor = tick()
        root.AssemblyLinearVelocity = Vector3.zero
        root.Velocity = Vector3.zero
    end

    -- Blatant. Nothing physical happens here at all: the character falls at full speed, lands
    -- where and when it would have, and no velocity, position or humanoid state is ever touched.
    -- The only thing that changes is what the server has on its books for the fall.
    --
    -- BedWars settles fall damage off the ground-hit event the client sends it. While descending,
    -- replay the same GroundHit payload used by the game exploit so the fall is continuously
    -- settled and cleared before the real landing arrives.
    --
    -- The cadence is the mechanism, not a detail. One packet and then silence leaves the fall
    -- free to build straight back up before touchdown, which is why this is deliberately NOT
    -- rate limited - it fires on every pass of the module's poll for as long as the fall is
    -- dangerous, so at the moment of landing the server has at most one tick of drop recorded.
    -- An earlier build here rate limited it to one send every 120ms and that is precisely the
    -- kind of "tidying" that stops it working.
    --
    -- Every physical variant of this has now been tried and none of them hold: cancelling the
    -- registered velocity, bleeding the impact off in the last frames, capping the fall speed
    -- and giving the distance back. They all lose the same race against the landing frame, or
    -- lean on a field the game does not have. This one does not race anything - it is simply
    -- keeping the server's record of the fall empty the whole way down.
    local groundHit
    local groundHitBlock

    local function resolveGroundHit()
        if groundHit and groundHitBlock then return groundHit end
        local success, remote, block = pcall(function()
            local managed = replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged
            return managed.GroundHit, workspace.Map.Worlds.tr_Range.Blocks:GetChildren()[222]
        end)
        groundHit = success and remote or nil
        groundHitBlock = success and block or nil
        return groundHit
    end
    task.spawn(resolveGroundHit)

	clearRegisteredFall = function()
        local remote = resolveGroundHit()
        if not remote or not groundHitBlock then return false end
		local success = pcall(function()
			remote:FireServer(
                groundHitBlock,
                Vector3.new(-10.598394393921, -35.038021087646, -16.960966110229),
                1785564031.154
            )
        end)
        return success
    end

    -- RakNet mode. The only one that works underneath the game entirely: it edits the physics
    -- packet on its way out of the client.
    --
    -- What a fall was worth is decided from what you replicate while you are in the air, and the
    -- humanoid state rides along in the standard 0x1b physics packet - the same packet and the
    -- same offset StateSpoofer writes to. So for as long as a dangerous fall is in progress this
    -- rewrites that one byte to a grounded state: the server is told about someone running, never
    -- about someone falling, and a fall that was never reported has nothing to settle on landing.
    --
    -- Nothing local changes. Not velocity, not position, not the state your own client is using -
    -- the fall looks and feels exactly as it always did on your screen, and the only difference
    -- is what leaves the machine.
    --
    -- A send hook runs on the network thread, where one error disconnects you, so there are two
    -- hard rules here: everything is inside a pcall with an explicit length check, and while the
    -- fall is not dangerous the hook returns immediately without touching the packet, so ordinary
    -- movement replicates byte for byte the way it normally would.
    local rakHook, spoofFall = nil, false

    local function addRakHook()
        if rakHook then return end
        rakHook = function(packet)
            if not spoofFall then return end
            pcall(function()
                local data = packet.AsBuffer
                local packetId = packet.AsArray and packet.AsArray[1]
                if not packetId and data and buffer.len(data) > 0 then
                    packetId = buffer.readu8(data, 0)
                end
                if packetId == 0x1b then
                    local state = SpoofState and Enum.HumanoidStateType[SpoofState.Value]
                    if data and state and buffer.len(data) >= 26 then
                        buffer.writeu8(data, 25, state.Value + 32)
                        packet:SetData(data)
                    end
                end
            end)
        end
        pcall(raknet.add_send_hook, rakHook)
    end

    local function removeRakHook()
        spoofFall = false
        if not rakHook then return end
        pcall(raknet.remove_send_hook, rakHook)
        rakHook = nil
    end

    local cvStateConnections = {}
    local modeGeneration = 0

    local function restoreCvStateConnections()
        for _, connection in cvStateConnections do
            pcall(function()
                if connection.Enable then connection:Enable() end
            end)
        end
        table.clear(cvStateConnections)
    end

    local function disableCvStateConnections(humanoid)
        restoreCvStateConnections()
        if not humanoid or type(getconnections) ~= 'function' then return end
        local ok, connections = pcall(getconnections, humanoid.StateChanged)
        if not ok or type(connections) ~= 'table' then return end
        for _, connection in connections do
            if connection and connection.Disable then
                local disabled = pcall(connection.Disable, connection)
                if disabled then table.insert(cvStateConnections, connection) end
            end
        end
    end

    local function startCvBlatant(generation)
        if entitylib.isAlive then
            disableCvStateConnections(entitylib.character.Humanoid)
        end

        local trackedVelocity = 0
        local groundHit
        pcall(function()
            groundHit = bedwars.Handler:Get('GroundHit')
        end)

        NoFall:Clean(runService.PostSimulation:Connect(function()
            if generation ~= modeGeneration or not NoFall.Enabled or Mode.Value ~= 'Blatant' then return end
            if not entitylib.isAlive or store.matchState ~= 1 or store.infinitefly then return end

            local root = entitylib.character.RootPart
            local humanoid = entitylib.character.Humanoid
            local velocity = root.Velocity
            if trackedVelocity < -(45 + ((CvDamage and CvDamage.Value or 0) * 0.75)) then
                -- cv behaviour: briefly report a landed state, preserve the fall's previous
                -- velocity, and settle the GroundHit record immediately.
                root.Velocity = Vector3.new(0, 2.5, 0)
                humanoid:ChangeState(Enum.HumanoidStateType.Landed)
                runService.PreRender:Wait()
                if generation == modeGeneration and NoFall.Enabled and Mode.Value == 'Blatant' and root.Parent then
                    root.Velocity = velocity
                    if groundHit then
                        pcall(groundHit.Fire, groundHit, 'SendToServer', nil, Vector3.new(0, trackedVelocity, 0), workspace:GetServerTimeNow())
                    end
                end
            end
            trackedVelocity = velocity.Y
        end))

        NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
            if generation ~= modeGeneration or not NoFall.Enabled or Mode.Value ~= 'Blatant' then return end
            task.defer(function()
                if generation == modeGeneration and NoFall.Enabled and Mode.Value == 'Blatant' then
                    disableCvStateConnections(ent.Humanoid)
                end
            end)
        end))
    end

    local function setSettingsVisible()
        local legit = Mode and Mode.Value == 'Legit'
        if CvDamage and CvDamage.Object then CvDamage.Object.Visible = not legit end
        if MinVelocity and MinVelocity.Object then MinVelocity.Object.Visible = legit end
        if GroundDistance and GroundDistance.Object then GroundDistance.Object.Visible = legit end
        if HealthCheck and HealthCheck.Object then HealthCheck.Object.Visible = legit end
        if DamagePercent and DamagePercent.Object then DamagePercent.Object.Visible = legit end
        for _, option in {BlockClutch, TelepearlClutch, DaoClutch, JadeHammerClutch, VoidAxeClutch, Zephyr} do
            if option and option.Object then option.Object.Visible = legit end
        end
        -- Legacy experimental controls are intentionally hidden after the merge.
        for _, option in {AnchorAttempts, FallThreshold, SpoofState} do
            if option and option.Object then option.Object.Visible = false end
        end
    end

    NoFall = vape.Categories.Blatant:CreateModule({
        Name = 'NoFallDamage',
        Function = function(callback)
            modeGeneration += 1
            local generation = modeGeneration

            if callback then
                restoreCvStateConnections()
                if Mode.Value == 'Blatant' then
                    startCvBlatant(generation)
                end

                repeat
                    local waitDelay = 0.1
                    local character, root, humanoid = validCharacter()
                    if character then
                        updateTrackedFall(root, humanoid)
                        if humanoid.FloorMaterial ~= Enum.Material.Air then
                            usedPearl = false
                        elseif Mode.Value == 'Legit' then
                            local ground = getGround(root, character, HealthCheck and HealthCheck.Enabled and 300 or (GroundDistance and GroundDistance.Value or 30))
                            local zephyred = false
                            if Zephyr and Zephyr.Enabled then
                                zephyred = zephyrClutch(root, humanoid, ground)
                                if zephyred then waitDelay = 0.05 end
                            end
                            if not zephyred then legitClutch(root, humanoid, ground) end
                        end
                    end
                    task.wait(waitDelay)
                until not NoFall.Enabled or generation ~= modeGeneration
            else
                restoreCvStateConnections()
                usedPearl = false
                lastAnchor = 0
                lastLegitUse = 0
                clutchBusyUntil = 0
                lastBlockPlace = 0
                lastZephyrJump = 0
                zephyrFired = false
                fallAnchorY = nil
                trackedFall = 0
                removeRakHook()
            end
        end,
        Tooltip = 'Prevents fall damage. Blatant uses cv NoFallDamage behavior; Legit keeps Aether clutch logic.'
    })
	Mode = NoFall:CreateDropdown({
		Name = 'Mode',
		List = {'Blatant', 'Legit'},
        Function = function()
            setSettingsVisible()
            if NoFall.Enabled then
                NoFall:Toggle()
                NoFall:Toggle()
            end
        end,
		Tooltip = 'Blatant - cv NoFallDamage behavior\nLegit - Aether clutch logic'
    })
    CvDamage = NoFall:CreateSlider({
        Name = 'Damage',
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = '%',
        Tooltip = 'Blatant only: matches cv NoFallDamage damage percentage behavior'
    })
    MinVelocity = NoFall:CreateSlider({
        Name = 'Minimum Velocity',
        Min = 35,
        Max = 120,
        Default = 60,
        Tooltip = 'How fast the drop has to be before Legit uses a clutch. Blatant ignores it'
    })
    FallThreshold = NoFall:CreateSlider({
        Name = 'Fall threshold',
        Min = 40,
        Max = 120,
        Default = 85,
        Suffix = ' studs/s',
        Visible = false,
        Tooltip = 'RakNet: how fast the fall must get before packet spoofing starts. Blatant always sends it'
    })
    SpoofState = NoFall:CreateDropdown({
        Name = 'Reported state',
        List = {'Running', 'Landed', 'RunningNoPhysics'},
        Visible = false,
        Tooltip = 'RakNet only: the humanoid state sent during a dangerous fall. Running is safest, try Landed if it fails'
    })
    GroundDistance = NoFall:CreateSlider({
        Name = 'Ground Check',
        Min = 8,
        Max = 80,
        Default = 30
    })
    AnchorAttempts = NoFall:CreateSlider({
        Name = 'Attempts per second',
        Min = 1,
        Max = 12,
        Default = 5,
        Visible = false
    })
    BlockClutch = NoFall:CreateToggle({
        Name = 'Blocks',
        Default = true,
        Tooltip = 'Places blocks directly beneath you shortly before fall damage would apply'
    })
    HealthCheck = NoFall:CreateToggle({
        Name = 'Health check',
        Tooltip = 'Only clutches when the estimated fall damage would be lethal'
    })
    DamagePercent = NoFall:CreateSlider({
        Name = 'Damage threshold',
        Min = 1,
        Max = 100,
        Default = 100,
        Suffix = '%',
        Tooltip = 'With Health check on, only clutches when estimated fall damage reaches this percentage of current health'
    })
    Zephyr = NoFall:CreateToggle({
        Name = 'Zephyr',
        Tooltip = 'Legit only: jumps just before landing so a Zephyr/WindWalker kit negates the fall'
    })
    TelepearlClutch = NoFall:CreateToggle({
        Name = 'Telepearl',
        Default = true,
        Tooltip = 'Throws a telepearl to nearby safe ground after block clutching is unavailable'
    })
    DaoClutch = NoFall:CreateToggle({
        Name = 'Dao',
        Default = true
    })
    JadeHammerClutch = NoFall:CreateToggle({
        Name = 'Jade Hammer',
        Default = true
    })
    VoidAxeClutch = NoFall:CreateToggle({
        Name = 'Void Axe',
        Default = true
    })

    setSettingsVisible()
end)