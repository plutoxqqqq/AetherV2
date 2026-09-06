run(function()
    local NoFall
    local Mode
    local MinVelocity
    local BlockClutch
    local TelepearlClutch
    local DaoClutch
    local JadeHammerClutch
    local VoidAxeClutch
    local HealthCheck
    local CvDamage
    local Zephyr
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    
    local plainCheck = RaycastParams.new()
    plainCheck.RespectCanCollide = true
    plainCheck.FilterType = Enum.RaycastFilterType.Exclude
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
                    
                    return (bedwars.BlockController:getBlockPosition(below).Y * 3) + 1.5
                end
            end
            return nil
        end)
        return success and blockY or nil
    end

    
    
    
    local function standClearance(root, character)
        local humanoid = character.Humanoid
        return character.HipHeight or ((humanoid and humanoid.HipHeight or 2) + (root.Size.Y * 0.5))
    end

    
    
    
    
    local trackedFall = 0

    local function updateTrackedFall(root, humanoid)
        if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            trackedFall = 0
        else
            trackedFall = math.min(trackedFall, root.AssemblyLinearVelocity.Y)
        end
        return trackedFall
    end

    
    
    
    
    
    
    
    
    
	local clearRegisteredFall
	local function tpNoFall(root, character)
        local groundY = groundBelow(root, character)
        if not groundY then return false end

        local floorY = groundY + standClearance(root, character)
        local drop = root.Position.Y - floorY
        
        if drop <= 1 then return false end

        local velocity = root.AssemblyLinearVelocity
		local landed = root.CFrame - Vector3.new(0, drop, 0)
		
		
		character:PivotTo(landed)
        
        
        
        
        root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
        
        
        
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
        return estimatedDamage >= health
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

    
    
    
    local function hasZephyrKit()
        local success, result = pcall(function()
            local kit = store.equippedKit
            if kit == nil or kit == '' then
                kit = lplr:GetAttribute('PlayingAsKit')
            end
            if kit == nil then return nil end
            
            
            
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
        
        
        if zephyrFired or now - lastZephyrJump < 0.3 then return end
        if not ground or not isFallFatal(root, humanoid, ground) then return end

        
        
        if hasZephyrKit() == false then return end

        local groundDistance = root.Position.Y - ground.Position.Y
        local bodyClearance = (humanoid.HipHeight or 2) + (root.Size.Y * 0.5)
        local remainingDistance = math.max(0, groundDistance - bodyClearance)
        local verticalSpeed = math.abs(root.AssemblyLinearVelocity.Y)

        
        
        
        local totalFall = math.max(fallAnchorY - root.Position.Y, 0) + remainingDistance
        if totalFall < 20 then return end

        
        if remainingDistance <= 3.5 or (verticalSpeed > 0 and (remainingDistance / verticalSpeed) <= 0.09) then
            lastZephyrJump = now
            zephyrFired = true
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                humanoid.Jump = true
            end)
            
            
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
        if HealthCheck and HealthCheck.Object then HealthCheck.Object.Visible = legit end
        for _, option in {BlockClutch, TelepearlClutch, DaoClutch, JadeHammerClutch, VoidAxeClutch, Zephyr} do
            if option and option.Object then option.Object.Visible = legit end
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
                            local ground = getGround(root, character, HealthCheck and HealthCheck.Enabled and 300 or 30)
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
                lastLegitUse = 0
                clutchBusyUntil = 0
                lastBlockPlace = 0
                lastZephyrJump = 0
                zephyrFired = false
                fallAnchorY = nil
                trackedFall = 0
            end
        end,
        Tooltip = 'Prevents fall damage'
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
		Tooltip = 'Blatant - completely cancels/reduces fall damage\nLegit - clutches using semi-legit means'
    })
    CvDamage = NoFall:CreateSlider({
        Name = 'Damage',
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = '%',
        Tooltip = 'How much % of fall damage to take'
    })
    MinVelocity = NoFall:CreateSlider({
        Name = 'Minimum Velocity',
        Min = 35,
        Max = 120,
        Default = 60,
        Tooltip = 'How fast the drop has to be before Legit uses a clutch'
    })
    BlockClutch = NoFall:CreateToggle({
        Name = 'Blocks',
        Default = true,
        Tooltip = 'Places blocks directly beneath you while falling'
    })
    HealthCheck = NoFall:CreateToggle({
        Name = 'Health check',
        Tooltip = 'Only clutches when the estimated fall damage would be lethal'
    })
    Zephyr = NoFall:CreateToggle({
        Name = 'Zephyr',
        Tooltip = 'Jumps before landing with Zephyr'
    })
    TelepearlClutch = NoFall:CreateToggle({
        Name = 'Telepearl',
        Default = true,
        Tooltip = 'Throws a telepearl to nearby safe ground'
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
